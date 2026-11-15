--!strict
-- RarityFx (vague 59, a189, L-182 point 2 ; client) : les raretés qui bougent, sur le texte ou le fond d'une carte
-- (nom de l'objet, pastille de rareté, fond Clip de l'index v4, carte des objets exposés, carte « ITEM SECURED »…).
-- Module d'aide rangé dans Controllers/UI : le Loader ne le démarre pas ; les contrôleurs l'appellent.
--   - Static (jusqu'à Épique) : dégradé fixe, couleur de la rareté tirée vers le blanc en haut et vers le noir en bas ;
--   - Sheen (Légendaire) : le même dégradé, et un reflet qui le traverse toutes les SheenPeriod s ;
--   - Rainbow (Mythique, Secret et Divine, L-188) : l'arc-en-ciel du Secret (Config/Rarities.RainbowColors) qui défile, un cycle en
--     RainbowPeriod s (environ 3 s). Les couleurs tournent dans le dégradé : un Offset seul laisserait un bord de
--     couleur unie (un UIGradient ne se répète pas), le dessin est celui d'un Offset qui défile sans fin.
-- Le dégradé : le UIGradient de Clément nommé RarityFx.GradientName s'il est là (Clip.RarityGradient des maquettes),
-- sinon un UIGradient créé ici. Un UIGradient multiplie la couleur de l'élément : elle passe au blanc le temps de
-- l'effet (TextColor3 d'un texte, ImageColor3 d'une image, sinon BackgroundColor3) et revient à Clear, comme le
-- UIGradient de Clément (Color, Rotation, Offset, Enabled). Valeurs dans Config/UiMotion.RarityFx.
-- Les cartes des boutiques gardent Shared/ShopCardTier (a186) : leur fond vient des modèles de Clément par palier
-- (ShopCardBg), son rendu ne change pas.
--
-- Une seule connexion Heartbeat pour tous les dégradés qui bougent, branchée seulement tant que l'un d'eux est dans un
-- écran allumé ; sinon elle attend que l'un de ces écrans se rallume. Un élément retiré est oublié.
--
-- API (client) :
--   RarityFx.Apply(target, rarityId?) -> string?   pose l'effet de cette rareté ; renvoie "Static", "Sheen" ou
--                                                  "Rainbow" ; rareté inconnue ou nil : Clear, renvoie nil
--   RarityFx.Clear(target)                         retire l'effet, tout revient à l'état de Clément
--   RarityFx.KindOf(rarityId) -> string?           l'effet de cette rareté
--   RarityFx.GetKind(target) -> string?            l'effet posé sur cet élément (bancs)
--   RarityFx.IsRunning() -> boolean                la connexion Heartbeat est branchée (bancs)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local UiMotion = require(Config:WaitForChild("UiMotion"))
local Rarities = require(Config:WaitForChild("Rarities"))

local SPEC = UiMotion.RarityFx
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

export type Kind = "Static" | "Sheen" | "Rainbow"

type GradientBase = { color: ColorSequence, rotation: number, offset: Vector2, enabled: boolean }

type Painted = {
	gradient: UIGradient,
	created: boolean, -- créé ici (détruit à Clear), sinon celui de Clément (remis à Clear)
	gradientBase: GradientBase?,
	property: string, -- couleur de l'élément passée au blanc
	color: Color3, -- sa valeur posée par Clément
	kind: Kind,
	light: Color3,
	dark: Color3,
	colors: { Color3 },
	phase: number, -- décalage entre éléments, de 0 à 1
	sheening: boolean,
}

local RarityFx = {}

local painted: { [GuiObject]: Painted } = setmetatable({}, { __mode = "k" }) :: any
local animated: { GuiObject } = {}
local heartbeat: RBXScriptConnection? = nil
local wakes: { RBXScriptConnection } = {}
local clock = 0
local count = 0

local SECRET = Rarities.ById.Secret
local RAINBOW: { Color3 } = if SECRET and SECRET.RainbowColors then SECRET.RainbowColors else { WHITE }

local function frac(x: number): number
	return x - math.floor(x)
end

local function screenOf(target: Instance): LayerCollector?
	local current = target.Parent
	while current ~= nil do
		if current:IsA("LayerCollector") then
			return current :: LayerCollector
		end
		current = current.Parent
	end
	return nil
end

local function colorProperty(target: GuiObject): string
	if target:IsA("TextLabel") or target:IsA("TextButton") or target:IsA("TextBox") then
		return "TextColor3"
	elseif target:IsA("ImageLabel") or target:IsA("ImageButton") then
		return "ImageColor3"
	end
	return "BackgroundColor3"
end

-- Suite de couleurs : points { t, couleur } avec t = 0 et t = 1, les autres gardés s'ils sont entre les deux.
type Point = { t: number, c: Color3 }
local function sequence(points: { Point }): ColorSequence
	table.sort(points, function(a: Point, b: Point): boolean
		return a.t < b.t
	end)
	local keypoints: { ColorSequenceKeypoint } = {}
	local last = -1
	for _, point in points do
		local t = point.t
		local edge = t <= 0 or t >= 1
		if (edge or (t > 0.001 and t < 0.999)) and t - last > 0.001 then
			table.insert(keypoints, ColorSequenceKeypoint.new(math.clamp(t, 0, 1), point.c))
			last = t
		end
	end
	return ColorSequence.new(keypoints)
end

local function base(p: Painted, x: number): Color3
	return p.light:Lerp(p.dark, math.clamp(x, 0, 1))
end

local function staticSequence(p: Painted): ColorSequence
	return sequence({ { t = 0, c = p.light }, { t = 1, c = p.dark } })
end

-- Reflet centré en `center` (part de l'élément), de demi-largeur SheenWidth.
local function sheenSequence(p: Painted, center: number): ColorSequence
	local width = SPEC.SheenWidth
	local function at(x: number): Color3
		local weight = math.max(0, 1 - math.abs(x - center) / width) * SPEC.SheenStrength
		return base(p, x):Lerp(SPEC.SheenColor, weight)
	end
	local points: { Point } = { { t = 0, c = at(0) }, { t = 1, c = at(1) } }
	for _, x in { center - width, center, center + width } do
		if x > 0 and x < 1 then
			table.insert(points, { t = x, c = at(x) })
		end
	end
	return sequence(points)
end

-- L'arc-en-ciel décalé de `phase` (0 à 1 : un tour).
local function rainbowSequence(colors: { Color3 }, phase: number): ColorSequence
	local n = #colors
	local function at(u: number): Color3
		local scaled = frac(u) * n
		local index = math.floor(scaled)
		return colors[index % n + 1]:Lerp(colors[(index + 1) % n + 1], scaled - index)
	end
	local points: { Point } = { { t = 0, c = at(-phase) }, { t = 1, c = at(1 - phase) } }
	for k = 0, n - 1 do
		local x = frac(phase + k / n)
		if x > 0 and x < 1 then
			table.insert(points, { t = x, c = colors[k + 1] })
		end
	end
	return sequence(points)
end

local function animate(p: Painted)
	local gradient = p.gradient
	if p.kind == "Rainbow" then
		gradient.Color = rainbowSequence(p.colors, frac(clock / SPEC.RainbowPeriod + p.phase))
	elseif p.kind == "Sheen" then
		local t = frac(clock / SPEC.SheenPeriod + p.phase) * SPEC.SheenPeriod
		if t < SPEC.SheenPass then
			local width = SPEC.SheenWidth
			gradient.Color = sheenSequence(p, -width + (1 + 2 * width) * (t / SPEC.SheenPass))
			p.sheening = true
		elseif p.sheening then
			gradient.Color = staticSequence(p)
			p.sheening = false
		end
	end
end

local wake: () -> ()

-- Plus rien à animer dans un écran allumé : Heartbeat débranché, on attend qu'un de leurs écrans se rallume.
local function sleep()
	local running = heartbeat
	heartbeat = nil
	if running then
		running:Disconnect()
	end
	local seen: { [LayerCollector]: boolean } = {}
	for _, target in animated do
		local screen = screenOf(target)
		if screen and not seen[screen] then
			seen[screen] = true
			table.insert(wakes, screen:GetPropertyChangedSignal("Enabled"):Connect(function()
				wake()
			end))
		end
	end
end

local function step(dt: number)
	clock += dt
	local awake = false
	for i = #animated, 1, -1 do
		local target = animated[i]
		local p = painted[target]
		if p == nil or p.kind == "Static" or target.Parent == nil or p.gradient.Parent ~= target then
			table.remove(animated, i)
		else
			local screen = screenOf(target)
			if screen ~= nil and screen.Enabled then
				awake = true
				animate(p)
			end
		end
	end
	if not awake then
		sleep()
	end
end

wake = function()
	for _, connection in wakes do
		connection:Disconnect()
	end
	table.clear(wakes)
	if heartbeat == nil and #animated > 0 then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
end

local function unanimate(target: GuiObject)
	local index = table.find(animated, target)
	if index then
		table.remove(animated, index)
	end
end

function RarityFx.KindOf(rarityId: string?): Kind?
	local kind = if rarityId then SPEC.Kinds[rarityId] else nil
	if kind == "Static" or kind == "Sheen" or kind == "Rainbow" then
		return kind :: Kind
	end
	return nil
end

function RarityFx.Clear(target: GuiObject)
	local p = painted[target]
	if p == nil then
		return
	end
	painted[target] = nil
	unanimate(target);
	(target :: any)[p.property] = p.color
	local gradient = p.gradient
	if p.created then
		gradient:Destroy()
	else
		local saved = p.gradientBase
		if saved then
			gradient.Color = saved.color
			gradient.Rotation = saved.rotation
			gradient.Offset = saved.offset
			gradient.Enabled = saved.enabled
		end
	end
end

function RarityFx.Apply(target: GuiObject, rarityId: string?): Kind?
	local rarity = if rarityId then Rarities.ById[rarityId] else nil
	local found: Kind? = RarityFx.KindOf(rarityId)
	if rarity == nil or found == nil then
		RarityFx.Clear(target)
		return nil
	end
	local kind: Kind = found
	local p: Painted? = painted[target]
	if p ~= nil and (p :: Painted).gradient.Parent ~= target then
		RarityFx.Clear(target) -- dégradé retiré entre-temps : on repart de zéro
		p = nil
	end
	if p == nil then
		local child = target:FindFirstChild(SPEC.GradientName)
		local gradient: UIGradient
		local created = false
		local saved: GradientBase? = nil
		if child and child:IsA("UIGradient") then
			gradient = child :: UIGradient
			saved = { color = gradient.Color, rotation = gradient.Rotation, offset = gradient.Offset, enabled = gradient.Enabled }
		else
			gradient = Instance.new("UIGradient")
			gradient.Name = SPEC.GradientName
			created = true
		end
		local property = colorProperty(target)
		count += 1
		local fresh: Painted = {
			gradient = gradient,
			created = created,
			gradientBase = saved,
			property = property,
			color = (target :: any)[property],
			kind = kind,
			light = WHITE,
			dark = WHITE,
			colors = RAINBOW,
			phase = frac(count * 0.618),
			sheening = false,
		}
		painted[target] = fresh
		gradient.Parent = target
		p = fresh
	end
	local current = p :: Painted
	(target :: any)[current.property] = WHITE
	current.kind = kind
	current.light = rarity.Color:Lerp(WHITE, SPEC.Light)
	current.dark = rarity.Color:Lerp(BLACK, SPEC.Dark)
	current.colors = rarity.RainbowColors or RAINBOW
	current.sheening = false
	local gradient = current.gradient
	gradient.Enabled = true
	gradient.Offset = Vector2.new(0, 0)
	if kind == "Rainbow" then
		gradient.Rotation = SPEC.RainbowRotation
		animate(current)
	else
		gradient.Rotation = if kind == "Sheen" then SPEC.SheenRotation else SPEC.Rotation
		gradient.Color = staticSequence(current)
	end
	if kind == "Static" then
		unanimate(target)
	else
		if not table.find(animated, target) then
			table.insert(animated, target)
		end
		wake()
	end
	return kind
end

function RarityFx.GetKind(target: GuiObject): Kind?
	local p = painted[target]
	return if p then p.kind else nil
end

function RarityFx.IsRunning(): boolean
	return heartbeat ~= nil
end

return RarityFx
