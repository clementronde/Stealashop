--!strict
-- CrateLoop (vague 63, a209 ; liaison L-204 point 1, L-203 a, c, d ; client) : la boucle de la caisse exclusive
-- (`Crate` de UI_RobuxShop_v2). Module d'aide rangé dans Controllers/UI : le Loader
-- ne le démarre pas, ShopFxController appelle CrateLoop.Start(). Il trouve l'écran par son nom (Config/ShopFx.Crate),
-- jamais par RobuxShopController.
--
-- Tant que l'écran est allumé et la caisse à l'écran (visible, et dans la partie montrée de sa liste qui défile),
-- une boucle de Period s (4 s), calculée à chaque image depuis l'ouverture (CrateLoop.Sample, sans tween) :
--   Backdrop.Rays tourne de RaysTurn par boucle, son UIGradient Fade à l'inverse ; Backdrop.Glow respire ;
--   Icon monte et descend, puis se secoue et grossit vers ShakeAt ; Backdrop.Shadow se serre et s'élargit avec elle ;
--   Odds.Odd_n bougent en Y en décalage (jamais leur Size) ; RarityGlow pulse et Star clignotent l'une après
--   l'autre, en suivant la case qu'ils entourent ; BuyRow.BuyButton3 grossit deux fois ; NewBadge saute une fois.
--   a299 (Cantin, 21/11 : « objets de la caisse fixes ») : ShopFx.Crate.OddBob = 0, les cases, leurs RarityGlow et
--   leurs Star ne bougent plus en Y (pulse et clignotement gardés, autour de leur centre) ; Bob = 0 figerait de même
--   la caisse (Icon) et son ombre (Shadow), la secousse restant.
-- À l'ouverture, les cases de Odds (Appear = Cascade de Clément) entrent une à une toutes les CellGap s, de Odd_1
-- (la plus commune) à la plus rare, avec leur RarityGlow et leurs Star (règle donnée à Appear.SetCascade).
-- Decor (Hang1 à Hang4) est caché sur téléphone (tactile sans clavier) ; sur PC, Appear le fait tomber une fois par
-- ouverture (l'écran rallumé = une nouvelle ouverture).
-- Réglage « animations réduites » (Settings.VfxReduced, ou ReducedMotionEnabled de Roblox) : pas de boucle.
--
-- Ce qui est touché, le temps de la boucle seulement : Rotation (Rays, Fade, Icon), ImageTransparency (Glow,
-- RarityGlow), Position (Icon, Shadow, Odd_n, RarityGlow, Star, BuyButton3, NewBadge) et Size (Icon, Shadow,
-- RarityGlow, Star, BuyButton3 ; grossis autour de leur centre). Tout revient exactement à la valeur de Clément à
-- l'extinction de l'écran, quand la caisse quitte l'écran, ou au réglage « animations réduites ». Aucun UIScale (le
-- survol de Motion et la Cascade d'Appear gardent les leurs). Une connexion Heartbeat seulement tant qu'un de ces
-- écrans est allumé.
--
-- API (client) :
--   CrateLoop.Start()                       suit les écrans de Config/ShopFx.Crate.Screens du PlayerGui
--   CrateLoop.Sample(t) -> Pose             la pose de la boucle au temps t (s, ramené dans la boucle) : bancs
--   CrateLoop.GetTime(gui) -> number?       temps dans la boucle de cet écran (nil : pas de boucle en cours)
--   CrateLoop.IsMoving(gui) -> boolean      la boucle écrit sur la caisse en ce moment

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ShopFx = require(Config:WaitForChild("ShopFx"))
local Settings = require(Config:WaitForChild("Settings"))
local Appear = require(script.Parent:WaitForChild("Appear"))

local SPEC = ShopFx.Crate
local TAU = 2 * math.pi
local MAX_CELLS = 12
local REDUCED_CHECK = 0.5 -- s entre deux lectures du réglage « animations réduites »

local SCREENS: { [string]: boolean } = {}
for _, name in SPEC.Screens do
	SCREENS[name] = true
end

export type Pose = {
	Rays: number, -- degrés ajoutés à la Rotation de Rays (Fade : retirés)
	Glow: number, -- ImageTransparency de Glow
	IconY: number, -- px (maquette) ajoutés en Y à Icon (négatif = vers le haut)
	IconRotation: number, -- degrés ajoutés à la Rotation de Icon
	IconScale: number, -- taille de Icon (1 = celle de Clément)
	ShadowWidth: number, -- largeur de Shadow (1 = celle de Clément)
	OddY: { number }, -- px ajoutés en Y à Odd_n (index n)
	Stars: { number }, -- taille de la k-ième étoile (de la plus commune à la plus rare)
	RarityScale: number, -- taille de RarityGlow
	RarityFade: number, -- transparence ajoutée à RarityGlow
	Button: number, -- taille de BuyButton3
	BadgeY: number, -- px ajoutés en Y à NewBadge
}

-- Un élément animé et ses valeurs de Clément (lues au départ de la boucle, remises à l'arrêt).
type Item = {
	object: GuiObject,
	position: UDim2,
	size: UDim2,
	rotation: number,
	anchor: Vector2,
	transparency: number?, -- ImageTransparency (Glow, RarityGlow)
	resize: boolean, -- sa Size est écrite par la boucle
}

type Decoration = { item: Item, cell: number, x: number }

type Rig = {
	crate: GuiObject,
	rays: Item?,
	fade: UIGradient?,
	fadeRotation: number,
	glow: Item?,
	shadow: Item?,
	icon: Item?,
	cells: { [number]: Item },
	stars: { Decoration },
	rarity: { Decoration },
	button: Item?,
	badge: Item?,
}

type Screen = {
	gui: ScreenGui,
	connections: { RBXScriptConnection },
	openedAt: number?, -- os.clock() de l'allumage ; nil : écran éteint
	rig: Rig?, -- boucle en train d'écrire sur la caisse
}

local CrateLoop = {}

local localPlayer = Players.LocalPlayer
local screens: { [ScreenGui]: Screen } = {}
local heartbeat: RBXScriptConnection? = nil
local reduced = false
local reducedCheckedAt = -math.huge

------------------------------------------------------------------------------
-- La pose (pure)
------------------------------------------------------------------------------

-- 0 → 1 → 0 (demi-sinus) pendant `time` s à partir de `start`, 0 en dehors.
local function bump(t: number, start: number, time: number): number
	if time <= 0 then
		return 0
	end
	local u = (t - start) / time
	if u < 0 or u > 1 then
		return 0
	end
	return math.sin(math.pi * u)
end

function CrateLoop.Sample(time: number): Pose
	local period = SPEC.Period
	local t = time % period
	local bob = -math.sin(TAU * t / SPEC.BobPeriod) -- monte d'abord
	local iconRotation, iconScale = 0, 1
	local shakeStart = SPEC.ShakeAt - SPEC.ShakeTime / 2
	local u = (t - shakeStart) / SPEC.ShakeTime
	if u >= 0 and u <= 1 then
		iconRotation = SPEC.ShakeAngle * math.sin(TAU * SPEC.ShakeTurns * u) * (1 - u)
		iconScale = 1 + (SPEC.ShakePop - 1) * math.sin(math.pi * u)
	end
	local odd: { number } = {}
	local stars: { number } = {}
	for n = 1, MAX_CELLS do
		odd[n] = -SPEC.OddBob * math.sin(TAU * t / SPEC.OddPeriod - (n - 1) * SPEC.OddPhase)
		stars[n] = SPEC.StarMin
			+ (SPEC.StarMax - SPEC.StarMin) * bump(t, SPEC.StarStart + (n - 1) * SPEC.StarGap, SPEC.StarTime)
	end
	local pulse = 0.5 - 0.5 * math.cos(TAU * t / SPEC.GlowPulsePeriod)
	local button = 0
	for _, at in SPEC.ButtonAt do
		button = math.max(button, bump(t, at - SPEC.ButtonTime / 2, SPEC.ButtonTime))
	end
	return {
		Rays = SPEC.RaysTurn * t / period,
		Glow = SPEC.GlowTo + (SPEC.GlowFrom - SPEC.GlowTo) * (0.5 + 0.5 * math.cos(TAU * t / period)),
		IconY = SPEC.Bob * bob,
		IconRotation = iconRotation,
		IconScale = iconScale,
		ShadowWidth = if SPEC.Bob == 0 then 1 else 1 + SPEC.ShadowSpread * bob, -- a299 : caisse figée, ombre aussi
		OddY = odd,
		Stars = stars,
		RarityScale = 1 + (SPEC.GlowPulseScale - 1) * pulse,
		RarityFade = SPEC.GlowPulseFade * (1 - pulse),
		Button = 1 + (SPEC.ButtonPop - 1) * button,
		BadgeY = -SPEC.BadgeJump * bump(t, SPEC.BadgeAt, SPEC.BadgeTime),
	}
end

------------------------------------------------------------------------------
-- La caisse
------------------------------------------------------------------------------

local function item(object: Instance?, resize: boolean): Item?
	if object == nil or not object:IsA("GuiObject") then
		return nil
	end
	local gui = object :: GuiObject
	return {
		object = gui,
		position = gui.Position,
		size = gui.Size,
		rotation = gui.Rotation,
		anchor = gui.AnchorPoint,
		transparency = if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then (gui :: any).ImageTransparency else nil,
		resize = resize,
	}
end

-- Enfant direct de Crate, ou de Crate.Backdrop (Clément peut ranger Glow et Shadow d'un côté ou de l'autre).
local function pick(crate: Instance, name: string): Instance?
	local direct = crate:FindFirstChild(name)
	if direct then
		return direct
	end
	local backdrop = crate:FindFirstChild("Backdrop")
	return if backdrop then backdrop:FindFirstChild(name) else nil
end

local function cellNumber(object: Instance): number?
	local n = tonumber(string.match(object.Name, "^Odd_(%d+)$"))
	return if n and n >= 1 and n <= MAX_CELLS then n else nil
end

-- Milieu horizontal (en part du parent) d'un élément à sa place.
local function middle(object: GuiObject): number
	return object.Position.X.Scale + object.Size.X.Scale * (0.5 - object.AnchorPoint.X)
end

-- La case la plus proche (milieu horizontal) de `object` parmi les Odd_n de `odds`.
local function nearestCell(odds: Instance, object: GuiObject): number?
	local own = cellNumber(object)
	if own then
		return own
	end
	local x = middle(object)
	local best: number? = nil
	local distance = math.huge
	for _, child in odds:GetChildren() do
		local n = cellNumber(child)
		if n and child:IsA("GuiObject") then
			local d = math.abs(middle(child :: GuiObject) - x)
			if d < distance then
				best, distance = n, d
			end
		end
	end
	return best
end

local function findCrate(gui: ScreenGui): GuiObject?
	local found = gui:FindFirstChild(SPEC.Element, true)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function oddsOf(crate: Instance): Instance?
	return crate:FindFirstChild("Odds", true)
end

-- Ordre d'entrée des cases à l'ouverture (Cascade de Clément sur Odds), donné à Appear.
local function setCascade(gui: ScreenGui)
	local crate = findCrate(gui)
	local odds = if crate then oddsOf(crate) else nil
	if odds == nil or not odds:IsA("GuiObject") then
		return
	end
	local container = odds :: GuiObject
	local hasCells = false
	for _, child in container:GetChildren() do
		if cellNumber(child) then
			hasCells = true
			break
		end
	end
	if not hasCells then
		return -- pas de Odd_n : la règle commune d'Appear
	end
	Appear.SetCascade(container, function(child: GuiObject): number
		return (nearestCell(container, child) or 1) - 1
	end, SPEC.CellGap)
end

local function buildRig(crate: GuiObject): Rig
	local rays = item(pick(crate, "Rays"), false)
	local fadeFound = if rays then rays.object:FindFirstChild(SPEC.FadeName) else nil
	local fade: UIGradient? = if fadeFound and fadeFound:IsA("UIGradient") then fadeFound :: UIGradient else nil
	local rig: Rig = {
		crate = crate,
		rays = rays,
		fade = fade,
		fadeRotation = if fade then fade.Rotation else 0,
		glow = item(pick(crate, "Glow"), false),
		shadow = item(pick(crate, "Shadow"), true),
		icon = item(crate:FindFirstChild("Icon"), true),
		cells = {},
		stars = {},
		rarity = {},
		button = item(crate:FindFirstChild(SPEC.Button, true), true),
		badge = item(crate:FindFirstChild("NewBadge", true), false),
	}
	local odds = oddsOf(crate)
	if odds then
		for _, child in odds:GetChildren() do
			local n = cellNumber(child)
			if n then
				local cell = item(child, false) -- jamais sa Size (L-203 c)
				if cell then
					rig.cells[n] = cell
				end
			end
		end
		for _, child in odds:GetChildren() do
			if (child.Name == "Star" or child.Name == "RarityGlow") and child:IsA("GuiObject") then
				local deco = item(child, true)
				if deco then
					local entry: Decoration = { item = deco, cell = nearestCell(odds, child :: GuiObject) or 0, x = middle(child :: GuiObject) }
					table.insert(if child.Name == "Star" then rig.stars else rig.rarity, entry)
				end
			end
		end
		table.sort(rig.stars, function(a: Decoration, b: Decoration): boolean
			if a.cell ~= b.cell then
				return a.cell < b.cell
			end
			return a.x < b.x
		end)
	end
	return rig
end

-- Écrit `entry` : décalé de dy px (écran) en Y, grossi de sx × sy autour de son centre, tourné de `turn`.
local function place(entry: Item, dy: number, sx: number, sy: number, turn: number?)
	local object = entry.object
	local p, s, a = entry.position, entry.size, entry.anchor
	local size = s
	if entry.resize then
		size = UDim2.new(s.X.Scale * sx, s.X.Offset * sx, s.Y.Scale * sy, s.Y.Offset * sy)
		object.Size = size
	end
	object.Position = UDim2.new(
		p.X.Scale + (0.5 - a.X) * (s.X.Scale - size.X.Scale),
		p.X.Offset + (0.5 - a.X) * (s.X.Offset - size.X.Offset),
		p.Y.Scale + (0.5 - a.Y) * (s.Y.Scale - size.Y.Scale),
		p.Y.Offset + (0.5 - a.Y) * (s.Y.Offset - size.Y.Offset) + dy
	)
	if turn then
		object.Rotation = entry.rotation + turn
	end
end

local function restoreItem(entry: Item?)
	if entry == nil then
		return
	end
	local object = entry.object
	object.Position = entry.position
	if entry.resize then
		object.Size = entry.size
	end
	object.Rotation = entry.rotation
	local transparency = entry.transparency
	if transparency ~= nil then
		(object :: any).ImageTransparency = transparency
	end
end

local function restoreRig(rig: Rig)
	restoreItem(rig.rays)
	local fade = rig.fade
	if fade then
		fade.Rotation = rig.fadeRotation
	end
	restoreItem(rig.glow)
	restoreItem(rig.shadow)
	restoreItem(rig.icon)
	for _, cell in rig.cells do
		restoreItem(cell)
	end
	for _, deco in rig.stars do
		restoreItem(deco.item)
	end
	for _, deco in rig.rarity do
		restoreItem(deco.item)
	end
	restoreItem(rig.button)
	restoreItem(rig.badge)
end

local function applyRig(rig: Rig, pose: Pose)
	local size = rig.crate.AbsoluteSize.Y
	local px = if size > 0 then size / SPEC.DesignHeight else 1 -- px de la maquette → px de l'écran
	local rays = rig.rays
	if rays then
		rays.object.Rotation = rays.rotation + pose.Rays
		local fade = rig.fade
		if fade then
			fade.Rotation = rig.fadeRotation - pose.Rays -- Fade.Rotation = −Rays.Rotation (L-203 a)
		end
	end
	local glow = rig.glow
	if glow and glow.transparency ~= nil then
		(glow.object :: any).ImageTransparency = pose.Glow
	end
	local icon = rig.icon
	if icon then
		place(icon, pose.IconY * px, pose.IconScale, pose.IconScale, pose.IconRotation)
	end
	local shadow = rig.shadow
	if shadow then
		place(shadow, 0, pose.ShadowWidth, 1)
	end
	if SPEC.OddBob ~= 0 then -- a299 : OddBob = 0, les cases restent à la place de Clément (rien d'écrit)
		for n, cell in rig.cells do
			place(cell, pose.OddY[n] * px, 1, 1)
		end
	end
	for k, deco in rig.stars do
		local scale = pose.Stars[math.min(k, MAX_CELLS)]
		place(deco.item, (pose.OddY[deco.cell] or 0) * px, scale, scale)
	end
	for _, deco in rig.rarity do
		place(deco.item, (pose.OddY[deco.cell] or 0) * px, pose.RarityScale, pose.RarityScale)
		local base = deco.item.transparency
		if base ~= nil then
			(deco.item.object :: any).ImageTransparency = math.min(base + pose.RarityFade, 1)
		end
	end
	local button = rig.button
	if button then
		place(button, 0, pose.Button, pose.Button)
	end
	local badge = rig.badge
	if badge then
		place(badge, pose.BadgeY * px, 1, 1)
	end
end

------------------------------------------------------------------------------
-- Quand la boucle tourne
------------------------------------------------------------------------------

local function readReduced(): boolean
	if Settings.VfxReduced(localPlayer) then
		return true
	end
	local ok, value = pcall(function(): any
		return (game:GetService("GuiService") :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

-- La caisse et ses parents sont visibles, l'écran allumé, et elle est dans la partie montrée de sa liste.
local function crateShown(crate: GuiObject): boolean
	local current: Instance? = crate
	while current ~= nil do
		if current:IsA("GuiObject") and not (current :: GuiObject).Visible then
			return false
		end
		if current:IsA("LayerCollector") then
			if not (current :: LayerCollector).Enabled then
				return false
			end
			break
		end
		current = current.Parent
	end
	if current == nil then
		return false
	end
	local list = crate:FindFirstAncestorWhichIsA("ScrollingFrame")
	if list == nil then
		return true
	end
	local a, as = crate.AbsolutePosition, crate.AbsoluteSize
	local b, bs = list.AbsolutePosition, list.AbsoluteSize
	if as.X <= 0 or as.Y <= 0 or bs.X <= 0 or bs.Y <= 0 then
		return true -- tailles pas encore calculées : on la croit visible
	end
	return a.Y < b.Y + bs.Y and a.Y + as.Y > b.Y and a.X < b.X + bs.X and a.X + as.X > b.X
end

local function stopRig(screen: Screen)
	local rig = screen.rig
	screen.rig = nil
	if rig then
		restoreRig(rig)
	end
end

local function stopHeartbeat()
	local connection = heartbeat
	heartbeat = nil
	if connection then
		connection:Disconnect()
	end
end

local function step()
	local now = os.clock()
	if now - reducedCheckedAt >= REDUCED_CHECK then
		reducedCheckedAt = now
		reduced = readReduced()
	end
	local anyOpen = false
	for _, screen in screens do
		local openedAt = screen.openedAt
		if openedAt ~= nil then
			anyOpen = true
			local rig = screen.rig
			if rig and (rig.crate.Parent == nil or not rig.crate:IsDescendantOf(screen.gui)) then
				screen.rig = nil -- caisse retirée : rien à remettre
				rig = nil
			end
			local crate = if rig then rig.crate else findCrate(screen.gui)
			if reduced or crate == nil or not crateShown(crate) then
				stopRig(screen) -- à sa place tant qu'on ne la voit pas
			else
				if rig == nil then
					rig = buildRig(crate)
					screen.rig = rig
				end
				applyRig(rig :: Rig, CrateLoop.Sample(now - openedAt))
			end
		end
	end
	if not anyOpen then
		stopHeartbeat()
	end
end

local function opened(screen: Screen)
	if screen.gui.Enabled then
		if screen.openedAt == nil then
			screen.openedAt = os.clock()
		end
		reducedCheckedAt = -math.huge -- relu à l'ouverture
		if heartbeat == nil then
			heartbeat = RunService.Heartbeat:Connect(step)
		end
	else
		screen.openedAt = nil
		stopRig(screen)
	end
end

local function isPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function forget(gui: ScreenGui)
	local screen = screens[gui]
	if screen == nil then
		return
	end
	screens[gui] = nil
	for _, connection in screen.connections do
		connection:Disconnect()
	end
	stopRig(screen)
end

local function watch(child: Instance)
	if screens[child :: any] or not child:IsA("ScreenGui") or not SCREENS[child.Name] then
		return
	end
	local gui = child :: ScreenGui
	local screen: Screen = { gui = gui, connections = {}, openedAt = nil, rig = nil }
	screens[gui] = screen
	setCascade(gui)
	if isPhone() then
		local decor = gui:FindFirstChild(SPEC.Decor)
		if decor and decor:IsA("GuiObject") then
			(decor :: GuiObject).Visible = false -- L-203 d : décor du PC seulement
		end
	end
	table.insert(screen.connections, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		opened(screen)
	end))
	table.insert(screen.connections, gui.AncestryChanged:Connect(function()
		if gui.Parent == nil or not gui.Parent:IsA("PlayerGui") then
			forget(gui)
		end
	end))
	opened(screen)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function CrateLoop.GetTime(gui: ScreenGui): number?
	local screen = screens[gui]
	local openedAt = if screen then screen.openedAt else nil
	if screen == nil or openedAt == nil or screen.rig == nil then
		return nil
	end
	return (os.clock() - openedAt) % SPEC.Period
end

function CrateLoop.IsMoving(gui: ScreenGui): boolean
	local screen = screens[gui]
	return screen ~= nil and screen.rig ~= nil
end

function CrateLoop.Start()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(watch)
	for _, child in playerGui:GetChildren() do
		watch(child)
	end
end

return CrateLoop
