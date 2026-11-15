--!strict
-- ShopCardTier (vague 58, a186, L-176 ; client) : le fond, la bordure, le texte de rareté, l'ombre et le décor du
-- visuel d'une carte des boutiques d'armes (UI_WeaponShop) et d'auras (UI_AuraShop), selon son palier, plus
-- l'animation de ce décor. Module commun aux deux contrôleurs (WeaponShopController, AuraShopController), requis
-- par le client seulement. Fonds validés par Clément le 2026-11-13 ; détail dans tools/clement/shop_tiers_apply.luau
-- et shop_tiers_proto.luau (le prototype animé, d'où viennent les valeurs d'animation plus bas).
--
-- Palier d'une carte : la rareté de même rang que l'objet dans sa boutique (Order 1 = Common, 2 = Uncommon…,
-- 8 = Divine, comme les cartes d'exemple Preview_<n> de Clément) : les premières cartes ont l'air faibles, les
-- dernières excellentes. V0 proposé, absent du doc : aucune rareté n'est écrite par objet de boutique.
--
-- Modèle du palier : ReplicatedStorage/Assets/UI/ShopCardBg/<Rareté> (Frame de Clément). Attributs : Rarity,
-- RarityColor, BorderColor, BorderThickness, IconScale (part de IconArea), IconGrey (0 à 1), StudsTransparency,
-- RaysSpin (degrés/s), GlowPulse (amplitude de transparence) ; Mythic, Secret, Divine : Motion (Sheen, Rainbow,
-- Sweep) et Period (s) ou Speed (tours/s). Enfants : Colors (UIGradient), Sheen ou Sweep (Frame avec un UIGradient
-- qui glisse), TextGradient et BorderGradient (Secret, désactivés), IconDecor (Folder : Rays, Glow, Star1 à Star5).
--
-- Ce que Apply fait à une carte clonée de List.Template (rien du tout si le modèle du palier manque : la carte garde
-- le fond du Template ; tout est facultatif au contrat) :
--   - Card.Fill : remplacé par une copie du modèle (sans IconDecor, TextGradient ni BorderGradient) ;
--   - Card.Studs.ImageTransparency = StudsTransparency ; UIStroke de Card : BorderColor, BorderThickness, et une copie
--     active de BorderGradient (Secret) à la place de ses anciens dégradés ;
--   - RarityLabel : le nom de la rareté (Config/Rarities, en anglais), en RarityColor, avec une copie active de
--     TextGradient (Secret) ;
--   - IconArea.Icon : taille IconScale (sa proportion d'origine gardée), rotation demandée (trails couchés :
--     TrailIconRotation du Template d'UI_AuraShop), teinte demandée tirée vers le gris de IconGrey ;
--     IconArea.IconShadow : même image et même rotation que Icon, taille suivie ;
--   - IconDecor : chaque enfant copié dans IconArea, autour de Icon.
-- Animations (client) : rayons qui tournent (RaysSpin), lueur qui bat (GlowPulse), étoiles qui scintillent, reflet
-- Sheen ou Sweep (Period), arc-en-ciel qui défile (Speed) et dégradé de bordure qui tourne (Secret). Une seule
-- connexion Heartbeat pour toutes les cartes, branchée seulement tant qu'un écran qui en a est allumé (Enabled) :
-- écran fermé, plus rien ne tourne. Une carte retirée est oubliée ; un écran retiré de l'arbre aussi (ses connexions
-- coupées).
--
-- API (client) :
--   ShopCardTier.Apply(row, order, options?) -> string?   habille la carte `row` (clone de List.Template, déjà rangée
--       dans l'écran) au palier de rang `order` ; renvoie l'Id de la rareté posée, ou nil (modèle absent : rien).
--       options.tint : Color3 du visuel (texture blanche à teinter), tirée vers le gris de IconGrey ; sans tint, la
--       couleur du visuel ne change pas. options.rotation : Rotation du visuel et de son ombre (degrés).
--   ShopCardTier.IconOf(row) -> ImageLabel?   le visuel IconArea.Icon de la carte (sinon Icon), ou nil
--   ShopCardTier.RarityAt(order) -> string?   l'Id de la rareté de ce rang (bancs)
--   ShopCardTier.IsRunning() -> boolean   la connexion Heartbeat des animations est branchée (bancs)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rarities = require(script.Parent:WaitForChild("Config"):WaitForChild("Rarities"))
local Find = require(script.Parent:WaitForChild("Contract"):WaitForChild("Find"))

local ASSETS = "Assets"
local UI_FOLDER = "UI"
local BG_FOLDER = "ShopCardBg"
local DECOR_FOLDER = "IconDecor"
local TEXT_GRADIENT = "TextGradient"
local BORDER_GRADIENT = "BorderGradient"
local FILL = "Fill"

-- Gris vers lequel IconGrey tire la teinte du visuel (Clément, shop_tiers_apply.luau).
local GREY = Color3.fromHex("8a8f99")

-- Animation : valeurs du prototype validé par Clément (shop_tiers_proto.luau, 2026-11-13), absentes des attributs.
local BORDER_SPIN = 90 -- degrés/s du dégradé de la bordure (Secret)
local PULSE_RATE = 2.4 -- rad/s de la lueur
local TWINKLE_RATE = 3 -- rad/s des étoiles
local TWINKLE_SPIN = 40 -- degrés/s des étoiles
local TWINKLE_FADE = 0.6 -- transparence d'une étoile au plus bas
local TWINKLE_SIZE_MIN = 0.6 -- taille d'une étoile au plus bas, en part de sa taille posée
local TWINKLE_SIZE_GAIN = 0.5
local SHEEN_FROM, SHEEN_SPAN = -0.9, 1.8 -- Offset.Y du reflet Sheen (de haut en bas)
local SWEEP_FROM, SWEEP_SPAN = -1.1, 2.2 -- Offset.X du reflet Sweep (de gauche à droite)

type Kind = "Rotate" | "Spin" | "Pulse" | "Twinkle" | "Rainbow" | "Sheen" | "Sweep"

type Anim = {
	kind: Kind,
	obj: Instance,
	speed: number, -- degrés/s (Rotate, Spin), tours/s (Rainbow, Sheen, Sweep)
	base: number, -- transparence (Pulse) ou taille (Twinkle) posée par Clément
	amp: number, -- amplitude (Pulse)
	phase: number, -- décalage entre cartes, de 0 à 1
}

type Screen = {
	anims: { Anim },
	connections: { RBXScriptConnection },
}

export type Options = {
	tint: Color3?,
	rotation: number?,
}

local ShopCardTier = {}

local screens: { [ScreenGui]: Screen } = {}
local heartbeat: RBXScriptConnection? = nil
local clock = 0

local function number(source: Instance, name: string): number?
	local value = source:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

local function color(source: Instance, name: string): Color3?
	local value = source:GetAttribute(name)
	return if typeof(value) == "Color3" then value :: Color3 else nil
end

local function rarityAt(order: number): Rarities.Rarity?
	local list = Rarities.List
	local rank = math.clamp(math.floor(order), 1, #list)
	for _, rarity in list do
		if rarity.Order == rank then
			return rarity
		end
	end
	return nil
end

local function modelOf(id: string): GuiObject?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS)
	local ui = assets and assets:FindFirstChild(UI_FOLDER)
	local folder = ui and ui:FindFirstChild(BG_FOLDER)
	local model = folder and folder:FindFirstChild(id)
	return if model and model:IsA("GuiObject") then model :: GuiObject else nil
end

local function screenOf(inst: Instance): ScreenGui?
	local current: Instance? = inst.Parent
	while current do
		if current:IsA("ScreenGui") then
			return current :: ScreenGui
		end
		current = current.Parent
	end
	return nil
end

local function frac(x: number): number
	return x - math.floor(x)
end

local function newAnim(kind: Kind, obj: Instance, speed: number, base: number, amp: number, phase: number): Anim
	return { kind = kind, obj = obj, speed = speed, base = base, amp = amp, phase = phase }
end

-- Animations ------------------------------------------------------------------------------------

local function alive(anim: Anim, gui: ScreenGui): boolean
	return anim.obj.Parent ~= nil and anim.obj:IsDescendantOf(gui)
end

local function prune(gui: ScreenGui, screen: Screen)
	for i = #screen.anims, 1, -1 do
		if not alive(screen.anims[i], gui) then
			table.remove(screen.anims, i)
		end
	end
end

local function play(anim: Anim)
	local o = anim.obj :: any
	local kind = anim.kind
	if kind == "Rotate" then
		o.Rotation = (anim.phase * 360 + clock * anim.speed) % 360
	elseif kind == "Spin" then
		o.Rotation = (clock * anim.speed) % 360
	elseif kind == "Pulse" then
		o.ImageTransparency = math.clamp(anim.base + anim.amp * math.sin(clock * PULSE_RATE + anim.phase * 2 * math.pi), 0, 1)
	elseif kind == "Twinkle" then
		local k = 0.5 + 0.5 * math.sin(clock * TWINKLE_RATE + anim.phase * 2 * math.pi)
		local size = anim.base * (TWINKLE_SIZE_MIN + TWINKLE_SIZE_GAIN * k)
		o.ImageTransparency = TWINKLE_FADE * (1 - k)
		o.Rotation = (clock * TWINKLE_SPIN + anim.phase * 360) % 360
		o.Size = UDim2.fromScale(size, size)
	elseif kind == "Rainbow" then
		o.Position = UDim2.fromScale(-frac(clock * anim.speed + anim.phase), 0)
	elseif kind == "Sheen" then
		o.Offset = Vector2.new(0, SHEEN_FROM + SHEEN_SPAN * frac(clock * anim.speed + anim.phase))
	elseif kind == "Sweep" then
		o.Offset = Vector2.new(SWEEP_FROM + SWEEP_SPAN * frac(clock * anim.speed + anim.phase), 0)
	end
end

local function step(dt: number)
	clock += dt
	for gui, screen in screens do
		if gui.Enabled then
			for i = #screen.anims, 1, -1 do
				local anim = screen.anims[i]
				if alive(anim, gui) then
					play(anim)
				else
					table.remove(screen.anims, i)
				end
			end
		end
	end
end

-- Heartbeat branché tant qu'un écran allumé a quelque chose à animer, débranché sinon.
local function update()
	local wanted = false
	for gui, screen in screens do
		if gui.Enabled and #screen.anims > 0 then
			wanted = true
			break
		end
	end
	local running = heartbeat
	if wanted and running == nil then
		heartbeat = RunService.Heartbeat:Connect(step)
	elseif not wanted and running then
		heartbeat = nil
		running:Disconnect()
	end
end

local function drop(gui: ScreenGui)
	local screen = screens[gui]
	if screen == nil then
		return
	end
	screens[gui] = nil
	for _, connection in screen.connections do
		connection:Disconnect()
	end
	update()
end

local function track(gui: ScreenGui): Screen
	local existing = screens[gui]
	if existing then
		return existing
	end
	local screen: Screen = { anims = {}, connections = {} }
	screens[gui] = screen
	table.insert(screen.connections, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		prune(gui, screen)
		update()
	end))
	table.insert(screen.connections, gui.AncestryChanged:Connect(function()
		if gui.Parent == nil then
			drop(gui)
		end
	end))
	return screen
end

-- Habillage --------------------------------------------------------------------------------------

local function clearGradients(target: Instance)
	for _, child in target:GetChildren() do
		if child:IsA("UIGradient") then
			child:Destroy()
		end
	end
end

-- Copie active du dégradé `name` du modèle dans `target` (après ses anciens dégradés), ou nil.
local function copyGradient(model: Instance, name: string, target: Instance): UIGradient?
	local source = model:FindFirstChild(name)
	if source == nil or not source:IsA("UIGradient") then
		return nil
	end
	local copy = source:Clone() :: UIGradient
	copy.Enabled = true
	copy.Parent = target
	return copy
end

local function styleCard(card: Instance, model: GuiObject, phase: number, anims: { Anim })
	local fill = model:Clone()
	fill.Name = FILL
	for _, name in { DECOR_FOLDER, TEXT_GRADIENT, BORDER_GRADIENT } do
		local extra = fill:FindFirstChild(name)
		if extra then
			extra:Destroy()
		end
	end
	local old = card:FindFirstChild(FILL)
	if old then
		old:Destroy()
	end
	fill.Parent = card

	local motion = model:GetAttribute("Motion")
	if motion == "Rainbow" then
		local speed = number(model, "Speed")
		if speed then
			table.insert(anims, newAnim("Rainbow", fill, speed, 0, 0, phase))
		end
	elseif motion == "Sheen" or motion == "Sweep" then
		local period = number(model, "Period")
		local shine = fill:FindFirstChild(motion)
		local gradient = shine and shine:FindFirstChildWhichIsA("UIGradient")
		if period and period > 0 and gradient then
			table.insert(anims, newAnim(if motion == "Sheen" then "Sheen" else "Sweep", gradient, 1 / period, 0, 0, phase))
		end
	end

	local studs = card:FindFirstChild("Studs")
	local studsTransparency = number(model, "StudsTransparency")
	if studs and studs:IsA("ImageLabel") and studsTransparency then
		(studs :: ImageLabel).ImageTransparency = studsTransparency
	end

	local stroke = card:FindFirstChildWhichIsA("UIStroke")
	if stroke then
		local edge = stroke :: UIStroke
		local borderColor = color(model, "BorderColor")
		local thickness = number(model, "BorderThickness")
		if borderColor then
			edge.Color = borderColor
		end
		if thickness then
			edge.Thickness = thickness
		end
		clearGradients(edge)
		local gradient = copyGradient(model, BORDER_GRADIENT, edge)
		if gradient then
			table.insert(anims, newAnim("Spin", gradient, BORDER_SPIN, 0, 0, 0))
		end
	end
end

local function styleLabel(label: Instance, model: GuiObject, rarity: Rarities.Rarity)
	if not label:IsA("TextLabel") then
		return
	end
	local text = label :: TextLabel
	text.Text = rarity.DisplayName
	text.TextColor3 = color(model, "RarityColor") or rarity.Color
	clearGradients(text)
	copyGradient(model, TEXT_GRADIENT, text)
end

local function styleIcon(area: Instance, icon: ImageLabel, model: GuiObject, phase: number, options: Options, anims: { Anim })
	local shadowFound = area:FindFirstChild("IconShadow")
	local shadow = if shadowFound and shadowFound:IsA("ImageLabel") then shadowFound :: ImageLabel else nil
	local scale = number(model, "IconScale")
	if scale then
		local size = icon.Size
		local ratio = if size.Y.Scale > 0 then size.X.Scale / size.Y.Scale else 1
		local shadowGrow = if shadow and size.Y.Scale > 0 then shadow.Size.Y.Scale / size.Y.Scale else 1
		icon.Size = UDim2.fromScale(ratio * scale, scale)
		if shadow then
			shadow.Size = UDim2.fromScale(ratio * scale * shadowGrow, scale * shadowGrow)
		end
	end
	local rotation = options.rotation
	if rotation then
		icon.Rotation = rotation
	end
	local tint = options.tint
	if tint then
		icon.ImageColor3 = tint:Lerp(GREY, math.clamp(number(model, "IconGrey") or 0, 0, 1))
	end
	if shadow then
		shadow.Image = icon.Image
		shadow.Rotation = icon.Rotation
	end

	local decor = model:FindFirstChild(DECOR_FOLDER)
	if decor == nil then
		return
	end
	local spin = number(model, "RaysSpin") or 0
	local pulse = number(model, "GlowPulse") or 0
	for _, piece in decor:GetChildren() do
		local copy = piece:Clone()
		local old = area:FindFirstChild(copy.Name)
		if old and old ~= icon and old ~= shadow then
			old:Destroy()
		end
		copy.Parent = area
		if copy:IsA("ImageLabel") then
			local image = copy :: ImageLabel
			local star = tonumber(string.match(copy.Name, "^Star(%d+)$"))
			if copy.Name == "Rays" and spin ~= 0 then
				table.insert(anims, newAnim("Rotate", copy, spin, 0, 0, phase))
			elseif copy.Name == "Glow" and pulse ~= 0 then
				table.insert(anims, newAnim("Pulse", copy, 0, image.ImageTransparency, pulse, phase))
			elseif star then
				table.insert(anims, newAnim("Twinkle", copy, 0, image.Size.X.Scale, 0, frac(phase + star * 0.21)))
			end
		end
	end
end

-- API ---------------------------------------------------------------------------------------------

function ShopCardTier.RarityAt(order: number): string?
	local rarity = rarityAt(order)
	return if rarity then rarity.Id else nil
end

function ShopCardTier.IconOf(row: Instance): ImageLabel?
	local area = Find.path(row, "IconArea")
	local icon = if area then area:FindFirstChild("Icon") else Find.path(row, "Icon")
	return if icon and icon:IsA("ImageLabel") then icon :: ImageLabel else nil
end

function ShopCardTier.Apply(row: Instance, order: number, options: Options?): string?
	local rarity = rarityAt(order)
	local model = if rarity then modelOf(rarity.Id) else nil
	if rarity == nil or model == nil then
		return nil
	end
	local opts: Options = options or {}
	local phase = frac(order * 0.618)
	local anims: { Anim } = {}

	local card = Find.path(row, "Card")
	if card then
		styleCard(card, model, phase, anims)
	end
	local label = Find.path(row, "RarityLabel")
	if label then
		styleLabel(label, model, rarity)
	end
	local area = Find.path(row, "IconArea")
	local icon = ShopCardTier.IconOf(row)
	if area and icon then
		styleIcon(area, icon, model, phase, opts, anims)
	end

	local gui = screenOf(row)
	if gui and #anims > 0 then
		local screen = track(gui)
		prune(gui, screen)
		for _, anim in anims do
			table.insert(screen.anims, anim)
		end
		update()
	end
	return rarity.Id
end

function ShopCardTier.IsRunning(): boolean
	return heartbeat ~= nil
end

return ShopCardTier
