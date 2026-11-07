--!strict
-- Vue de l'ouverture des colis v2 (DEV-050, DEV-052 ; spec ouverture-colis), module d'aide
-- d'UnboxController (client) : ce que le déroulé (Unbox/Sequence) montre, dans l'écran UI_Unbox v2
-- de Clément (contrat 2.2) et sur la copie locale du colis de l'établi.
--
--   Screen.new(screen, plan, box, hooks) -> view
--       screen : la copie de UI_Unbox dans PlayerGui ; box : copie locale du colis (BenchBox_<nn>,
--       prise par UnboxController à l'appui sur « Open »), ou nil ; la vue la détruit à la fin.
--   view:SetOpenNext(available)   montre ou cache OpenNextButton, une fois les boutons affichés
--   view:Close()                  remet l'écran dans l'état de Studio (DEV-052)
-- Les autres méthodes sont les événements du déroulé (voir Unbox/Sequence).
--
-- Ce que le code anime (liste de la spec) : Backdrop (transparence), SkipButton et Reel (Visible),
-- Upgrade (position au-dessus du colis, Visible, échelle), UpgradeRarity (texte, couleur ; Secret :
-- Rainbow), ReelGlow (couleur), ReelView (modèles, caméra, ImageColor3), Rays (rotation,
-- ImageColor3, taille), Rarity, ItemName et Income (textes, échelle), ItemPreview (le ViewportFrame
-- posé ici), boutons (Visible, échelle), Confetti (clones de Confetti.Template), Flash
-- (transparence). Le code ne change ni les tailles, ni les images, ni les couleurs de Clément, sauf
-- celles qui suivent la rareté ; les échelles passent par un UIScale ajouté ici (ou par celui de
-- Clément, multiplié). Toute propriété touchée est notée au premier changement et remise à la
-- fermeture ; tout ce qui est créé ici est détruit.
--
-- Cadres de la révélation : les cadres de premier niveau de l'écran qui contiennent Rarity, ItemName,
-- Income, ItemPreview, Rays ou les boutons (RevealPanel chez Clément), sauf s'ils contiennent aussi
-- un élément des étapes d'avant (Backdrop, SkipButton, Upgrade, Reel, Confetti, Flash), sont cachés
-- jusqu'à l'éclat : leurs décors (Glow…) n'apparaissent qu'avec l'objet.
--
-- Effets 3D V0 (absents de la spec, sur la copie locale du colis, côté client seulement) :
-- tremblement et lueur (PointLight) de la charge, teinte de la pièce Tint, colis qui grossit,
-- onde (disque néon), couvercle Lid qui saute, faisceau de lumière (pièce néon) à l'ouverture ;
-- le colis disparaît à l'éclat. Sons Unbox_* (spec) joués seulement s'ils existent dans
-- ReplicatedStorage/Assets/Sounds (une seule ligne en Studio s'il en manque).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Rarities = require(Config:WaitForChild("Rarities"))
local Unbox = require(Config:WaitForChild("Unbox"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
local Reel = require(script.Parent:WaitForChild("Reel"))
local Sequence = require(script.Parent:WaitForChild("Sequence"))

type Plan = Sequence.Plan
type FrameInfo = Sequence.FrameInfo
type Rarity = Rarities.Rarity

export type Hooks = {
	PlayPlayer: (name: string) -> boolean, -- joue une animation du joueur ; true si elle joue
	CanOpenNext: () -> boolean, -- un autre établi prêt et à portée (règle d'OpenBox)
}

type Saved = { [string]: { value: any } }
type ScaleRef = { scale: UIScale, base: number, own: boolean }
type Piece = {
	gui: GuiObject,
	x: number,
	y: number,
	vx: number,
	vy: number,
	spin: number,
	gravity: number,
	age: number,
	life: number,
}
type Wave = { part: BasePart, at: number, width: number, base: CFrame }
type Move = { fromPos: Vector2, fromSize: Vector2, toPos: Vector2, toSize: Vector2, settled: boolean }

type Fields = {
	screen: ScreenGui,
	plan: Plan,
	box: Model?,
	hooks: Hooks,
	saved: { [Instance]: Saved },
	made: { Instance },
	scales: { [Instance]: ScaleRef },
	-- éléments du contrat 2.2 (nil s'ils manquent : le ContractChecker le signale)
	backdrop: GuiObject?,
	skip: GuiObject?,
	upgrade: GuiObject?,
	upgradeRarity: TextLabel?,
	upgradeRainbow: UIGradient?,
	reel: GuiObject?,
	reelGlow: GuiObject?,
	reelView: ViewportFrame?,
	preview: GuiObject?,
	rays: ImageLabel?,
	raysRainbow: UIGradient?,
	rarity: TextLabel?,
	rarityRainbow: UIGradient?,
	itemName: TextLabel?,
	income: TextLabel?,
	confetti: GuiObject?,
	template: GuiObject?,
	flash: GuiObject?,
	continueButton: GuiObject?,
	openNextButton: GuiObject?,
	groups: { GuiObject },
	-- valeurs de Studio
	backdropValue: number,
	raysRotation: number,
	silhouette: Color3,
	-- colis local
	boxBase: CFrame?,
	light: PointLight?,
	beam: BasePart?,
	lid: PVInstance?,
	lidBase: CFrame?,
	waves: { Wave },
	pops: { number },
	lastPop: number?,
	-- rouleau et aperçu
	strip: Reel.Strip?,
	previewStrip: Reel.Strip?,
	viewport: ViewportFrame?,
	move: Move?,
	lastCenter: number?,
	lastTick: number,
	lastBeat: number,
	lastCountTick: number,
	riser: Sound?,
	music: Sound?,
	-- confettis
	pieces: { Piece },
	rainLeft: number,
	rainClock: number,
	-- état
	t: number,
	openNextShown: boolean,
	openNextAt: number?,
	closed: boolean,
}

local Screen = {}
Screen.__index = Screen

export type View = typeof(setmetatable({} :: Fields, Screen))

local IS_STUDIO = RunService:IsStudio()
local SCALE_NAME = "UnboxScale" -- UIScale ajouté par le code (retiré à la fermeture)
local PREVIEW_NAME = "ItemViewport" -- ViewportFrame posé par le code dans ItemPreview
local PIECE_NAME = "Piece" -- clone de Confetti.Template
local EFFECT_NAME = "UnboxEffect" -- pièces 3D V0 (onde, faisceau)
local WHITE = Color3.new(1, 1, 1)
local RARE_ORDER = Rarities.ById.Rare.Order
-- Éléments des étapes d'avant l'éclat : un cadre qui en contient un n'est pas caché avec la révélation.
local PHASE_ELEMENTS = { "Backdrop", "SkipButton", "Upgrade", "Reel", "Confetti", "Flash" }
local REVEAL_ELEMENTS = { "Rarity", "ItemName", "Income", "ItemPreview", "Rays", "ContinueButton", "OpenNextButton" }

local rng = Random.new()
local soundsWarned = false

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function find(root: Instance, path: string, class: string): Instance?
	local found = Find.path(root, path)
	if found ~= nil and found:IsA(class) then
		return found
	end
	return nil
end

local function lerp(a: number, b: number, u: number): number
	return a + (b - a) * u
end

-- Joue le son `name` de ReplicatedStorage/Assets/Sounds (2D), s'il existe ; `speed` multiplie sa
-- vitesse de lecture (plus aigu). Aucun son n'est encore livré (DEV-051) : une ligne en Studio, une
-- seule fois.
local function playSound(name: string, speed: number?): Sound?
	local template = MarkerSounds.find(name)
	if template == nil then
		if IS_STUDIO and not soundsWarned then
			soundsWarned = true
			print(`[Unbox] sons Unbox_* absents de ReplicatedStorage.Assets.Sounds (à venir avec DEV-051) : ouverture muette`)
		end
		return nil
	end
	local sound = MarkerSounds.playSound(template, nil)
	if speed ~= nil and speed ~= 1 then
		sound.PlaybackSpeed = template.PlaybackSpeed * speed
	end
	return sound
end

local function stopSound(sound: Sound?)
	if sound ~= nil then
		sound:Stop()
		sound:Destroy()
	end
end

-- Couleur d'une rareté pour un effet : celle de la planche de style (Secret : la première de son
-- arc-en-ciel).
local function colorOf(rarityId: string): Color3
	local rarity = Rarities.ById[rarityId]
	return if rarity then rarity.Color else WHITE
end

-- Petit décor 3D créé ici : ancré, sans collision ni contact, ignoré des rayons, sans ombre.
local function effectPart(color: Color3): Part
	local part = Instance.new("Part")
	part.Name = EFFECT_NAME
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

------------------------------------------------------------------------------
-- Propriétés notées et remises
------------------------------------------------------------------------------

-- Change `prop` de `inst` en notant sa valeur de Studio au premier changement.
local function set(self: View, inst: Instance?, prop: string, value: any)
	if inst == nil then
		return
	end
	local saved = self.saved[inst]
	if saved == nil then
		saved = {}
		self.saved[inst] = saved
	end
	if saved[prop] == nil then
		saved[prop] = { value = (inst :: any)[prop] }
	end
	(inst :: any)[prop] = value
end

-- Valeur de Studio de `prop` (celle d'avant le premier changement).
local function studio(self: View, inst: Instance, prop: string): any
	local saved = self.saved[inst]
	local entry = if saved then saved[prop] else nil
	if entry ~= nil then
		return entry.value
	end
	return (inst :: any)[prop]
end

-- Échelle d'animation de `inst` : `factor` × l'échelle de Studio.
local function setScale(self: View, inst: Instance?, factor: number)
	if inst == nil then
		return
	end
	local ref = self.scales[inst]
	if ref == nil then
		local existing = inst:FindFirstChildOfClass("UIScale")
		if existing ~= nil then
			ref = { scale = existing, base = existing.Scale, own = false }
		else
			local scale = Instance.new("UIScale")
			scale.Name = SCALE_NAME
			scale.Parent = inst
			table.insert(self.made, scale)
			ref = { scale = scale, base = 1, own = true }
		end
		self.scales[inst] = ref
	end
	local found = ref :: ScaleRef
	if found.own then
		found.scale.Scale = found.base * factor
	else
		set(self, found.scale, "Scale", found.base * factor)
	end
end

------------------------------------------------------------------------------
-- Colis local et positions à l'écran
------------------------------------------------------------------------------

local function boxAlive(self: View): Model?
	local box = self.box
	if box ~= nil and box.Parent ~= nil then
		return box
	end
	return nil
end

-- Haut du colis local (monde), ou nil.
local function boxTop(self: View): Vector3?
	local box = boxAlive(self)
	if box == nil then
		return nil
	end
	local cf, size = box:GetBoundingBox()
	return cf.Position + Vector3.new(0, size.Y / 2, 0)
end

-- Point du monde vu à l'écran, dans le repère des éléments de cet écran (encart du haut compris
-- ou non, selon IgnoreGuiInset).
local function toScreen(self: View, world: Vector3): Vector2?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local point: Vector3
	if self.screen.IgnoreGuiInset then
		point = (camera:WorldToViewportPoint(world))
	else
		point = (camera:WorldToScreenPoint(world))
	end
	if point.Z <= 0 then
		return nil -- derrière la caméra
	end
	return Vector2.new(point.X, point.Y)
end

-- Coin haut gauche du parent de `gui` (repère de son Position en pixels).
local function originOf(gui: GuiObject): Vector2
	local parent = gui.Parent
	if parent ~= nil and parent:IsA("GuiObject") then
		return (parent :: GuiObject).AbsolutePosition
	end
	return Vector2.zero
end

local function centerOf(gui: GuiObject?): Vector2?
	if gui == nil then
		return nil
	end
	return gui.AbsolutePosition + gui.AbsoluteSize / 2
end

-- Ancre de la lueur : la PrimaryPart du colis, sinon sa première pièce.
local function boxAnchor(box: Model): BasePart?
	local primary = box.PrimaryPart
	if primary then
		return primary
	end
	return box:FindFirstChildWhichIsA("BasePart", true)
end

-- Pièce teinte à la rareté : Tint (contrat 10.4), sinon le bloc V0 d'UnboxService.
local function tintPart(box: Model): BasePart?
	for _, name in { "Tint", "Block" } do
		local found = Find.path(box, name)
		if found ~= nil and found:IsA("BasePart") then
			return found :: BasePart
		end
	end
	return nil
end

------------------------------------------------------------------------------
-- Confettis (clones de Confetti.Template, en pixels dans le cadre Confetti)
------------------------------------------------------------------------------

local function confettiColor(rarityId: string): Color3
	local rarity = Rarities.ById[rarityId]
	if rarity ~= nil and rarity.RainbowColors ~= nil then
		local colors = rarity.RainbowColors
		return colors[rng:NextInteger(1, #colors)]
	end
	return colorOf(rarityId):Lerp(WHITE, rng:NextNumber() * 0.35)
end

local function spawnPiece(self: View, x: number, y: number, vx: number, vy: number, gravity: number, life: number, color: Color3)
	local template = self.template
	local holder = self.confetti
	if template == nil or holder == nil then
		return
	end
	local gui = template:Clone()
	gui.Name = PIECE_NAME
	gui.Visible = true
	gui.BackgroundColor3 = color
	gui.Position = UDim2.fromOffset(x, y)
	gui.Rotation = rng:NextNumber() * 360
	gui.Parent = holder
	table.insert(self.pieces, {
		gui = gui,
		x = x,
		y = y,
		vx = vx,
		vy = vy,
		spin = (rng:NextNumber() * 2 - 1) * 540,
		gravity = gravity,
		age = 0,
		life = life,
	})
end

-- Éclat de `count` confettis depuis le point `at` de l'écran (pixels absolus).
local function burst(self: View, at: Vector2?, count: number, rarityId: string)
	local holder = self.confetti
	if holder == nil or at == nil or count <= 0 then
		return
	end
	local height = math.max(holder.AbsoluteSize.Y, 1)
	local origin = at - holder.AbsolutePosition
	for _ = 1, count do
		local angle = math.rad(-90 + (rng:NextNumber() * 2 - 1) * 75)
		local speed = Unbox.ConfettiSpeed * height * (0.5 + rng:NextNumber() * 0.7)
		spawnPiece(
			self,
			origin.X,
			origin.Y,
			math.cos(angle) * speed,
			math.sin(angle) * speed,
			Unbox.ConfettiGravity * height,
			Unbox.ConfettiLife * (0.8 + rng:NextNumber() * 0.4),
			confettiColor(rarityId)
		)
	end
end

local function rainPiece(self: View)
	local holder = self.confetti
	if holder == nil then
		return
	end
	local size = holder.AbsoluteSize
	spawnPiece(
		self,
		rng:NextNumber() * size.X,
		-10,
		(rng:NextNumber() * 2 - 1) * 0.05 * size.Y,
		(0.25 + rng:NextNumber() * 0.2) * size.Y,
		0.1 * size.Y,
		3,
		confettiColor(self.plan.Rarity.Id)
	)
end

local function updatePieces(self: View, dt: number)
	local pieces = self.pieces
	for index = #pieces, 1, -1 do
		local piece = pieces[index]
		piece.age += dt
		if piece.age >= piece.life or piece.gui.Parent == nil then
			piece.gui:Destroy()
			table.remove(pieces, index)
		else
			piece.vy += piece.gravity * dt
			piece.x += piece.vx * dt
			piece.y += piece.vy * dt
			piece.gui.Position = UDim2.fromOffset(piece.x, piece.y)
			piece.gui.Rotation += piece.spin * dt
			local fade = (piece.age / piece.life - 0.7) / 0.3
			if fade > 0 then
				piece.gui.BackgroundTransparency = math.min(1, fade)
			end
		end
	end
	if self.rainLeft > 0 then
		self.rainClock += dt
		local every = Unbox.RainDuration / Unbox.RainCount
		while self.rainLeft > 0 and self.rainClock >= every do
			self.rainClock -= every
			self.rainLeft -= 1
			rainPiece(self)
		end
	end
end

------------------------------------------------------------------------------
-- Création
------------------------------------------------------------------------------

-- Cadres de premier niveau qui portent la révélation (voir l'en-tête).
local function revealGroups(screen: Instance): { GuiObject }
	local blocked: { [Instance]: boolean } = {}
	for _, name in PHASE_ELEMENTS do
		local found = Find.path(screen, name)
		local node: Instance? = found
		while node ~= nil and node ~= screen do
			blocked[node] = true
			node = node.Parent
		end
	end
	local groups: { GuiObject } = {}
	for _, name in REVEAL_ELEMENTS do
		local found = Find.path(screen, name)
		local top: Instance? = found
		while top ~= nil and top.Parent ~= screen do
			top = top.Parent
		end
		if top ~= nil and top ~= found and top:IsA("GuiObject") and not blocked[top] then
			if not table.find(groups, top :: GuiObject) then
				table.insert(groups, top :: GuiObject)
			end
		end
	end
	return groups
end

function Screen.new(screen: ScreenGui, plan: Plan, box: Model?, hooks: Hooks): View
	local fields: Fields = {
		screen = screen,
		plan = plan,
		box = box,
		hooks = hooks,
		saved = {},
		made = {},
		scales = {},
		backdrop = find(screen, "Backdrop", "GuiObject") :: GuiObject?,
		skip = find(screen, "SkipButton", "GuiButton") :: GuiObject?,
		upgrade = find(screen, "Upgrade", "GuiObject") :: GuiObject?,
		upgradeRarity = find(screen, "Upgrade.UpgradeRarity", "TextLabel") :: TextLabel?,
		upgradeRainbow = find(screen, "UpgradeRarity.Rainbow", "UIGradient") :: UIGradient?,
		reel = find(screen, "Reel", "GuiObject") :: GuiObject?,
		reelGlow = find(screen, "Reel.ReelGlow", "GuiObject") :: GuiObject?,
		reelView = find(screen, "Reel.ReelView", "ViewportFrame") :: ViewportFrame?,
		preview = find(screen, "ItemPreview", "GuiObject") :: GuiObject?,
		rays = find(screen, "Rays", "ImageLabel") :: ImageLabel?,
		raysRainbow = find(screen, "Rays.Rainbow", "UIGradient") :: UIGradient?,
		rarity = find(screen, "Rarity", "TextLabel") :: TextLabel?,
		rarityRainbow = find(screen, "Rarity.Rainbow", "UIGradient") :: UIGradient?,
		itemName = find(screen, "ItemName", "TextLabel") :: TextLabel?,
		income = find(screen, "Income", "TextLabel") :: TextLabel?,
		confetti = find(screen, "Confetti", "GuiObject") :: GuiObject?,
		template = find(screen, "Confetti.Template", "GuiObject") :: GuiObject?,
		flash = find(screen, "Flash", "GuiObject") :: GuiObject?,
		continueButton = find(screen, "ContinueButton", "GuiButton") :: GuiObject?,
		openNextButton = find(screen, "OpenNextButton", "GuiButton") :: GuiObject?,
		groups = revealGroups(screen),
		backdropValue = 1,
		raysRotation = 0,
		silhouette = Color3.new(0, 0, 0),
		boxBase = if box then box:GetPivot() else nil,
		light = nil,
		beam = nil,
		lid = nil,
		lidBase = nil,
		waves = {},
		pops = {},
		lastPop = nil,
		strip = nil,
		previewStrip = nil,
		viewport = nil,
		move = nil,
		lastCenter = nil,
		lastTick = -math.huge,
		lastBeat = -math.huge,
		lastCountTick = -math.huge,
		riser = nil,
		music = nil,
		pieces = {},
		rainLeft = 0,
		rainClock = 0,
		t = 0,
		openNextShown = false,
		openNextAt = nil,
		closed = false,
	}
	return setmetatable(fields, Screen)
end

------------------------------------------------------------------------------
-- Événements du déroulé
------------------------------------------------------------------------------

function Screen.Begin(self: View, _plan: Plan)
	set(self, self.screen, "Enabled", true)
	for _, group in self.groups do
		set(self, group, "Visible", false)
	end
	for _, gui in { self.rarity, self.itemName, self.income, self.preview, self.rays, self.continueButton, self.openNextButton } :: { GuiObject? } do
		set(self, gui, "Visible", false)
	end
	local backdrop = self.backdrop
	if backdrop then
		self.backdropValue = backdrop.BackgroundTransparency
		set(self, backdrop, "BackgroundTransparency", 1)
	end
	set(self, self.skip, "Visible", false)
	set(self, self.upgrade, "Visible", false)
	set(self, self.reel, "Visible", false)
	set(self, self.flash, "BackgroundTransparency", 1)
	for _, gradient in { self.rarityRainbow, self.raysRainbow, self.upgradeRainbow } :: { UIGradient? } do
		set(self, gradient, "Enabled", false)
	end
	local reelView = self.reelView
	if reelView then
		self.silhouette = reelView.ImageColor3 -- noir chez Clément : les silhouettes
	end
	local rays = self.rays
	if rays then
		self.raysRotation = rays.Rotation
	end
end

-- Lueur du colis local (PointLight sur son ancre), créée au premier besoin.
local function ensureLight(self: View, box: Model): PointLight?
	local existing = self.light
	if existing ~= nil then
		return existing
	end
	local anchor = boxAnchor(box)
	if anchor == nil then
		return nil
	end
	local light = Instance.new("PointLight")
	light.Brightness = 0
	light.Range = Unbox.UpgradeGlowRange
	light.Shadows = false
	light.Parent = anchor
	self.light = light
	return light
end

function Screen.Charge(self: View, _step: number, rarity: Rarity, _at: number)
	playSound("Unbox_UpgradeCharge")
	local box = boxAlive(self)
	local light = if box then ensureLight(self, box) else nil
	if light then
		light.Color = rarity.Color -- lueur de la rareté suivante
	end
end

-- Haut du perso : petit saut, s'il est au sol.
local function hop()
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	local part = root :: BasePart
	part.AssemblyLinearVelocity += Vector3.new(0, Unbox.UpgradeHop, 0)
end

local function setRainbowText(self: View, label: TextLabel?, gradient: UIGradient?, rarity: Rarity)
	if label == nil then
		return
	end
	set(self, label, "Text", rarity.DisplayNameUpper)
	if rarity.Rainbow then
		set(self, label, "TextColor3", WHITE) -- spec : texte blanc et dégradé Rainbow
		set(self, gradient, "Enabled", true)
	else
		set(self, label, "TextColor3", rarity.Color)
		set(self, gradient, "Enabled", false)
	end
end

function Screen.Pop(self: View, step: number, rarity: Rarity, at: number)
	self.pops[step] = at
	self.lastPop = at
	set(self, self.upgrade, "Visible", true)
	setScale(self, self.upgrade, 0)
	setRainbowText(self, self.upgradeRarity, self.upgradeRainbow, rarity)
	playSound("Unbox_UpgradePop", 1 + (step - 1) * Unbox.UpgradePitchStep)
	hop()
	local box = boxAlive(self)
	local base = self.boxBase
	if box ~= nil and base ~= nil then
		box:PivotTo(base)
		local tint = tintPart(box)
		if tint then
			tint.Color = rarity.Color -- copie locale : la teinte ne part jamais vers le serveur
		end
		pcall(function()
			box:ScaleTo(box:GetScale() * Unbox.UpgradeGrow)
		end)
		local cf, size = box:GetBoundingBox()
		local width = math.max(size.X, size.Z)
		local wave = effectPart(rarity.Color)
		wave.Shape = Enum.PartType.Cylinder
		wave.Transparency = 0.2
		local flat = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2 - 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		wave.Size = Vector3.new(0.15, width, width)
		wave.CFrame = flat
		wave.Parent = Workspace
		table.insert(self.made, wave)
		table.insert(self.waves, { part = wave :: BasePart, at = at, width = width, base = flat })
	end
	local point = boxTop(self)
	burst(self, if point then toScreen(self, point) else centerOf(self.upgrade), Unbox.UpgradeConfetti, rarity.Id)
end

function Screen.PlayUnbox(self: View): boolean
	return self.hooks.PlayPlayer("Unbox")
end

function Screen.Open(self: View, fromMarker: boolean, _at: number)
	if not fromMarker then
		playSound("Unbox_Open") -- sinon joué par AnimationController au marqueur (MarkerSounds)
	end
	set(self, self.upgrade, "Visible", false)
	local finalColor = self.plan.Rarity.Color
	local box = boxAlive(self)
	if box ~= nil then
		local base = self.boxBase
		if base then
			box:PivotTo(base)
		end
		local lid = Find.path(box, "Lid")
		if lid ~= nil and lid:IsA("PVInstance") then
			self.lid = lid :: PVInstance
			self.lidBase = (lid :: PVInstance):GetPivot()
		end
		local beam = effectPart(finalColor)
		beam.Transparency = 0.35
		beam.Size = Vector3.new(0.8, 0.05, 0.8)
		beam.Parent = Workspace
		table.insert(self.made, beam)
		self.beam = beam
		local light = ensureLight(self, box)
		if light then
			light.Color = finalColor
			light.Brightness = Unbox.UpgradeGlow
		end
	end
	set(self, self.reel, "Visible", true)
	set(self, self.skip, "Visible", true) -- spec : visible pendant le rouleau (et jusqu'aux boutons)
	local reelView = self.reelView
	if reelView then
		set(self, reelView, "CurrentCamera", reelView.CurrentCamera) -- noté pour la fermeture
		set(self, reelView, "ImageColor3", self.silhouette)
		self.strip = Reel.newStrip(reelView, self.plan.Reel.Items)
	end
	playSound("Unbox_Whoosh")
end

function Screen.ScrollStart(self: View, _at: number)
	if self.plan.Rarity.Order >= RARE_ORDER then
		self.riser = playSound("Unbox_Riser")
	end
end

function Screen.LastNotch(self: View, _at: number)
	stopSound(self.riser)
	self.riser = nil
	playSound("Unbox_Stop")
end

function Screen.ReelDone(self: View, _at: number)
	stopSound(self.riser)
	self.riser = nil
end

function Screen.ColorStart(self: View, _at: number)
	playSound("Unbox_Swell")
end

function Screen.Reveal(self: View, _at: number)
	local plan = self.plan
	local rarity = plan.Rarity
	-- Cadres de la révélation : de nouveau dans leur état de Studio (visibles).
	for _, group in self.groups do
		set(self, group, "Visible", studio(self, group, "Visible"))
	end
	local preview = self.preview
	if preview then
		set(self, preview, "Visible", studio(self, preview, "Visible"))
	end
	-- L'objet quitte le rouleau et vient vers ItemPreview (×1,3).
	local reelView = self.reelView
	if preview ~= nil then
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = PREVIEW_NAME
		viewport.BackgroundTransparency = 1
		viewport.ZIndex = preview.ZIndex
		local fromPos = Vector2.zero
		local fromSize = preview.AbsoluteSize
		if reelView ~= nil then
			fromPos = reelView.AbsolutePosition - preview.AbsolutePosition
			fromSize = reelView.AbsoluteSize
			viewport.Ambient = reelView.Ambient
			viewport.LightColor = reelView.LightColor
			viewport.LightDirection = reelView.LightDirection
		end
		local toSize = preview.AbsoluteSize * Unbox.ItemMoveScale
		local toPos = (preview.AbsoluteSize - toSize) / 2
		viewport.Position = UDim2.fromOffset(fromPos.X, fromPos.Y)
		viewport.Size = UDim2.fromOffset(fromSize.X, fromSize.Y)
		viewport.Parent = preview
		table.insert(self.made, viewport)
		self.viewport = viewport
		self.previewStrip = Reel.newStrip(viewport, { plan.Item })
		self.move = { fromPos = fromPos, fromSize = fromSize, toPos = toPos, toSize = toSize, settled = false }
	end
	set(self, self.reel, "Visible", false)
	local strip = self.strip
	if strip then
		strip:Destroy()
		self.strip = nil
	end
	-- Rayons à la couleur de la rareté (Secret : blancs, avec Rays.Rainbow).
	local rays = self.rays
	if rays then
		set(self, rays, "Visible", true)
		set(self, rays, "ImageColor3", if rarity.Rainbow then WHITE else rarity.Color)
		set(self, self.raysRainbow, "Enabled", rarity.Rainbow)
		setScale(self, rays, 0)
	end
	-- Confettis : éclat (Peu commun et plus), pluie plein écran (Épique et plus).
	local count = (Unbox.ConfettiBurst :: { [string]: number })[rarity.Id] or 0
	burst(self, centerOf(preview), count, rarity.Id)
	if count > 0 then
		playSound("Unbox_Confetti")
	end
	if rarity.Confetti then
		self.rainLeft = Unbox.RainCount
		self.rainClock = 0
	end
	if rarity.Announce then
		self.hooks.PlayPlayer("Celebrate") -- Légendaire et plus, si l'animation est livrée
	end
	local reveal = playSound(`Unbox_Reveal_{rarity.Id}`)
	if rarity.SlowMotion then
		self.music = reveal -- Secret : sa musique, coupée à la fermeture
	end
	-- Le colis a rendu son objet : il disparaît avec sa lueur et son faisceau.
	local box = self.box
	if box then
		box:Destroy()
		self.box = nil
	end
	for _, effect in { self.beam, self.light } :: { Instance? } do
		if effect then
			effect:Destroy()
		end
	end
	self.beam = nil
	self.light = nil
end

function Screen.RarityText(self: View, _at: number)
	local label = self.rarity
	if label == nil then
		return
	end
	setRainbowText(self, label, self.rarityRainbow, self.plan.Rarity)
	set(self, label, "Visible", true)
	setScale(self, label, Unbox.RaritySlamFrom)
	if self.plan.Rarity.Order >= RARE_ORDER then
		playSound("Unbox_Slam")
	end
end

function Screen.ItemNameText(self: View, _at: number)
	set(self, self.itemName, "Text", self.plan.Item.DisplayName)
	set(self, self.itemName, "Visible", true)
end

function Screen.IncomeStart(self: View, _at: number)
	if self.plan.Income == nil then
		return -- zone inconnue : pas de revenu affiché
	end
	set(self, self.income, "Text", Format.income(0))
	set(self, self.income, "Visible", true)
end

function Screen.IncomeDone(self: View, _at: number)
	local income = self.plan.Income
	if income == nil then
		return
	end
	set(self, self.income, "Text", Format.income(income))
	playSound("Unbox_Cash")
end

function Screen.Buttons(self: View, at: number)
	set(self, self.skip, "Visible", false)
	set(self, self.continueButton, "Visible", true)
	setScale(self, self.continueButton, 0)
	self:SetOpenNext(self.hooks.CanOpenNext(), at)
end

-- Montre ou cache OpenNextButton (une fois les boutons affichés).
function Screen.SetOpenNext(self: View, available: boolean, at: number?)
	if self.closed or self.openNextButton == nil or available == self.openNextShown then
		return
	end
	self.openNextShown = available
	set(self, self.openNextButton, "Visible", available)
	if available then
		self.openNextAt = at or self.t
		setScale(self, self.openNextButton, 0)
	end
end

------------------------------------------------------------------------------
-- Chaque image
------------------------------------------------------------------------------

local function frameUpgrade(self: View, info: FrameInfo)
	local t = info.T
	local box = boxAlive(self)
	local base = self.boxBase
	-- Charge : le colis tremble de plus en plus, la lueur monte.
	local charge = info.Charge
	if charge ~= nil then
		if box ~= nil and base ~= nil then
			local amplitude = Unbox.UpgradeShake * charge * charge
			local offset = Vector3.new(rng:NextNumber() * 2 - 1, 0, rng:NextNumber() * 2 - 1) * amplitude
			box:PivotTo(base * CFrame.new(offset) * CFrame.Angles(0, (rng:NextNumber() * 2 - 1) * amplitude * 0.5, 0))
		end
		local light = self.light
		if light then
			light.Brightness = Unbox.UpgradeGlow * charge
		end
	elseif self.lastPop ~= nil and info.At.Open == nil then
		local light = self.light
		if light then
			light.Brightness = Unbox.UpgradeGlow * math.max(0, 1 - (t - (self.lastPop :: number)) / 0.3)
		end
	end
	-- Upgrade : au-dessus du colis, échelle qui saute.
	local upgrade = self.upgrade
	if upgrade ~= nil and upgrade.Visible and self.lastPop ~= nil then
		setScale(self, upgrade, Sequence.backOut((t - (self.lastPop :: number)) / Unbox.UpgradePop))
		local top = boxTop(self)
		local point = if top then toScreen(self, top + Vector3.new(0, Unbox.UpgradeAbove, 0)) else nil
		if point ~= nil then
			local origin = originOf(upgrade)
			set(self, upgrade, "Position", UDim2.fromOffset(point.X - origin.X, point.Y - origin.Y))
		end
	end
	-- Ondes.
	local waves = self.waves
	for index = #waves, 1, -1 do
		local wave = waves[index]
		local u = (t - wave.at) / Unbox.UpgradeWave
		if u >= 1 or wave.part.Parent == nil then
			wave.part:Destroy()
			table.remove(waves, index)
		else
			local width = wave.width * lerp(1, Unbox.UpgradeWaveScale, Sequence.quadOut(u))
			wave.part.Size = Vector3.new(0.15, width, width)
			wave.part.CFrame = wave.base
			wave.part.Transparency = lerp(0.2, 1, u)
		end
	end
end

local function frameOpen(self: View, info: FrameInfo)
	local open = info.At.Open
	if open == nil or info.T < open then
		return
	end
	local since = info.T - open
	-- Backdrop : la scène s'assombrit, version complète seulement.
	local backdrop = self.backdrop
	if backdrop ~= nil and self.plan.Full then
		set(self, backdrop, "BackgroundTransparency", lerp(1, self.backdropValue, Sequence.clamp01(since / Unbox.BackdropFade)))
	end
	-- Couvercle (copie locale du colis : rien à remettre) et faisceau.
	local lid = self.lid
	local lidBase = self.lidBase
	if lid ~= nil and lidBase ~= nil and lid.Parent ~= nil then
		local u = Sequence.clamp01(since / Unbox.LidJump)
		lid:PivotTo(lidBase * CFrame.new(0, Unbox.LidHeight * Sequence.quadOut(u), 0) * CFrame.Angles(u * 1.2, 0, u * 0.5))
		if lid:IsA("BasePart") then
			(lid :: BasePart).Transparency = u
		end
		for _, part in lid:GetDescendants() do
			if part:IsA("BasePart") then
				(part :: BasePart).Transparency = u
			end
		end
	end
	local beam = self.beam
	local top = boxTop(self)
	if beam ~= nil and top ~= nil then
		local height = math.max(0.05, Unbox.BeamHeight * Sequence.quadOut(since / Unbox.BeamGrow))
		beam.Size = Vector3.new(0.8, height, 0.8)
		beam.CFrame = CFrame.new(top + Vector3.new(0, height / 2, 0))
	end
end

local function frameReel(self: View, info: FrameInfo)
	local pos = info.ReelPos
	local strip = self.strip
	local items = self.plan.Reel.Items
	local t = info.T
	if pos ~= nil and strip ~= nil then
		strip:Set(pos, t * Unbox.ReelSpin * 2 * math.pi, info.ReelDrop)
		-- ReelGlow : couleur de l'objet au centre, en fondu entre deux objets.
		local shown = pos + info.ReelDrop
		local below = math.floor(shown)
		local a = items[below]
		local b = items[below + 1]
		if a ~= nil then
			local color = colorOf(a.Rarity)
			if b ~= nil then
				color = color:Lerp(colorOf(b.Rarity), shown - below)
			end
			set(self, self.reelGlow, "BackgroundColor3", color)
		end
		local reelDone = info.At.ReelDone
		if reelDone == nil or t < reelDone then
			-- Tic à chaque objet au centre (plus aigu pour un objet rare ; 35 par seconde au plus).
			local center = math.floor(shown + 0.5)
			if center ~= self.lastCenter then
				self.lastCenter = center
				local now = os.clock()
				local item = items[center]
				if item ~= nil and now - self.lastTick >= 1 / Unbox.TickMaxRate then
					self.lastTick = now
					local order = (Rarities.ById[item.Rarity] or Rarities.List[1]).Order
					playSound("Unbox_Tick", 1 + (order - 1) * Unbox.TickPitchStep)
				end
			end
			-- Battement de cœur, Rare et plus, quand le rouleau ralentit.
			local scroll = info.At.ScrollStart
			if
				self.plan.Rarity.Order >= RARE_ORDER
				and scroll ~= nil
				and t >= scroll + Unbox.ReelAccel
				and info.ReelSpeed < Unbox.HeartbeatBelow
				and t - self.lastBeat >= Unbox.HeartbeatEvery
			then
				self.lastBeat = t
				playSound("Unbox_Heartbeat")
			end
		end
	end
	-- L'objet prend ses couleurs (ReelView.ImageColor3 du noir au blanc).
	local colorStart = info.At.ColorStart
	if colorStart ~= nil and t >= colorStart then
		set(self, self.reelView, "ImageColor3", self.silhouette:Lerp(WHITE, Sequence.clamp01((t - colorStart) / Unbox.ColorIn)))
	end
end

local function frameReveal(self: View, info: FrameInfo)
	local reveal = info.At.Reveal
	local t = info.T
	if reveal == nil or t < reveal then
		return
	end
	local since = t - reveal
	local rarity = self.plan.Rarity
	-- Flash de 100 ms.
	set(self, self.flash, "BackgroundTransparency", lerp(Unbox.FlashPeak, 1, Sequence.clamp01(since / Unbox.FlashTime)))
	-- L'objet vers ItemPreview, puis il tourne sur lui-même.
	local move = self.move
	local viewport = self.viewport
	if move ~= nil and viewport ~= nil and not move.settled then
		local u = Sequence.inOutCubic(since / Unbox.ItemMove)
		local pos = move.fromPos:Lerp(move.toPos, u)
		local size = move.fromSize:Lerp(move.toSize, u)
		viewport.Position = UDim2.fromOffset(pos.X, pos.Y)
		viewport.Size = UDim2.fromOffset(size.X, size.Y)
		if u >= 1 then
			-- Arrivé : en proportions d'ItemPreview, pour suivre un changement de taille d'écran.
			local scale = Unbox.ItemMoveScale
			viewport.Size = UDim2.fromScale(scale, scale)
			viewport.Position = UDim2.fromScale((1 - scale) / 2, (1 - scale) / 2)
			move.settled = true
		end
	end
	local previewStrip = self.previewStrip
	if previewStrip then
		previewStrip:Set(1, t * Unbox.ReelSpin * 2 * math.pi)
	end
	-- Rayons : ils grandissent puis tournent.
	local rays = self.rays
	if rays then
		setScale(self, rays, Sequence.backOut(since / Unbox.RaysGrow))
		set(self, rays, "Rotation", self.raysRotation + since * Unbox.RaysSpin * 360)
	end
	-- Arc-en-ciel du Secret.
	if rarity.Rainbow then
		for _, gradient in { self.raysRainbow, self.rarityRainbow } :: { UIGradient? } do
			if gradient then
				set(self, gradient, "Rotation", studio(self, gradient, "Rotation") + t * Unbox.RainbowSpin * 360)
			end
		end
	end
	-- Rarity claque (2,3 → 1, Back Out).
	local rarityAt = info.At.Rarity
	if rarityAt ~= nil and t >= rarityAt then
		local u = Sequence.backOut((t - rarityAt) / Unbox.RaritySlam)
		setScale(self, self.rarity, lerp(Unbox.RaritySlamFrom, 1, u))
	end
	-- Le revenu défile (1 − (1 − u)³).
	local incomeAt = info.At.Income
	local income = self.plan.Income
	if incomeAt ~= nil and income ~= nil and t >= incomeAt and t < info.At.CountEnd then
		local u = (t - incomeAt) / (info.At.CountEnd - incomeAt)
		set(self, self.income, "Text", Format.income(income * Sequence.countCurve(u)))
		if t - self.lastCountTick >= Unbox.CountTickEvery then
			self.lastCountTick = t
			playSound("Unbox_CountTick")
		end
	end
	-- Boutons.
	local buttons = info.At.Buttons
	if buttons ~= nil and t >= buttons then
		setScale(self, self.continueButton, Sequence.backOut((t - buttons) / Unbox.ButtonsPop))
		local openNextAt = self.openNextAt
		if self.openNextShown and openNextAt ~= nil then
			setScale(self, self.openNextButton, Sequence.backOut((t - openNextAt) / Unbox.ButtonsPop))
		end
	end
end

function Screen.Frame(self: View, info: FrameInfo)
	if self.closed then
		return
	end
	self.t = info.T
	frameUpgrade(self, info)
	frameOpen(self, info)
	frameReel(self, info)
	frameReveal(self, info)
	updatePieces(self, info.Dt)
end

------------------------------------------------------------------------------
-- Fermeture
------------------------------------------------------------------------------

function Screen.Close(self: View)
	if self.closed then
		return
	end
	self.closed = true
	stopSound(self.riser)
	stopSound(self.music)
	self.riser = nil
	self.music = nil
	for _, strip in { self.strip, self.previewStrip } :: { Reel.Strip? } do
		if strip then
			strip:Destroy()
		end
	end
	self.strip = nil
	self.previewStrip = nil
	for _, piece in self.pieces do
		piece.gui:Destroy()
	end
	table.clear(self.pieces)
	self.rainLeft = 0
	for _, made in self.made do
		made:Destroy()
	end
	table.clear(self.made)
	local box = self.box
	if box then
		box:Destroy()
		self.box = nil
	end
	-- Toutes les propriétés touchées reprennent leur valeur de Studio.
	for inst, props in self.saved do
		for prop, entry in props do
			pcall(function()
				(inst :: any)[prop] = entry.value
			end)
		end
	end
	table.clear(self.saved)
	table.clear(self.scales)
end

return Screen
