--!strict
-- SecuredCard (a521, 28/11 ; liaison L-405, carte « ITEM SECURED! » spectaculaire) : ce que la carte UI_Escape.Card
-- montre en plus le temps de l'arrivée en zone safe, derrière Features.SecuredCardV2 (ou SecuredCardV2Dev dans le jeu
-- DEV et TEST). Appelé par UiFeelController (escapeScreen : Play ; resetEscape : Stop) ; réglages Config/SecuredCard ;
-- palier : Shared/SecuredTier.TierOf (rareté, $/s du serveur, coup de chance du serveur).
--   - Card.Preview (ViewportFrame) : une copie de Assets/Items/<Asset> (ITM_<ItemId>), sans script, ancrée, et sa
--     caméra de face qui la montre en entier ; l'objet tourne doucement (Preview.Turn °/s). Card.ItemIcon est caché
--     tant que le modèle est là ; modèle absent : ItemIcon reste, comme avant.
--   - Sunburst, par palier (SecuredCard.Look) : Card.Rays (transparence, taille = multiple de Preview, un tour en
--     Period s ; avec FigmaSpin et Features.FramewispFx, c'est FramewispFx qui le tourne : son attribut SpinSpeed est
--     réglé, sinon il tourne ici), Card.RaysBack (en sens inverse), Card.Burst (une fois, à l'arrivée), et les copies
--     de UI_Escape.SecuredFx.Rain.Template qui tombent (SecuredFx montré). Tout est teint à la couleur de la rareté
--     (Config/Rarities, Color ; Secret : sa suite RainbowColors qui défile). Rotation continue (360 × temps / période).
--   - Grand palier : Card.TierScale.Scale = SecuredCard.TierScale ; Card.RarityTag montré (« LUCKY! », « MYTHIC! »,
--     « JACKPOT! ») et qui tremble autour de sa Rotation.
-- Stop remet tout comme Clément l'a posé (propriétés, attributs, CurrentCamera) et détruit ce qui a été créé (modèle,
-- caméra, copies de Rain). Chaque élément est facultatif : absent, rien pour lui.
--
-- API (client) :
--   SecuredCard.Play(screen, info) -> string?   info = { ItemId, Income?, Lucky? } ; le palier joué, nil si coupé
--   SecuredCard.Stop()
--   SecuredCard.GetState() -> { Plays, Active, Tier, Tag, Model, Drops }   (bancs)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features")) :: any
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Settings = require(Config:WaitForChild("SecuredCard")) :: any
local SecuredTier = require(Shared:WaitForChild("SecuredTier"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))

export type Info = { ItemId: string, Income: number?, Lucky: boolean? }

type Saved = { object: Instance, property: string, value: any }
type SavedAttr = { object: Instance, name: string, value: any }
type Spin = { object: GuiObject, rest: number, period: number, sign: number }
type Run = {
	saved: { Saved },
	attrs: { SavedAttr },
	created: { Instance },
	tweens: { Tween },
	tinted: { ImageLabel },
	spins: { Spin },
	loop: RBXScriptConnection?,
	startedAt: number,
	rarity: any,
	model: Model?,
	tag: TextLabel?,
	tagRest: number,
	drops: number,
}

local SecuredCard = {}

local current: Run? = nil
local plays = 0
local lastTier: string? = nil
local lastTag: string? = nil
local random = Random.new()

local function save(run: Run, object: Instance, property: string)
	for _, entry in run.saved do
		if entry.object == object and entry.property == property then
			return
		end
	end
	table.insert(run.saved, { object = object, property = property, value = (object :: any)[property] })
end

local function set(run: Run, object: Instance, property: string, value: any)
	save(run, object, property)
	local target: any = object
	target[property] = value
end

local function setAttribute(run: Run, object: Instance, name: string, value: any)
	local known = false
	for _, entry in run.attrs do
		if entry.object == object and entry.name == name then
			known = true
		end
	end
	if not known then
		table.insert(run.attrs, { object = object, name = name, value = object:GetAttribute(name) })
	end
	object:SetAttribute(name, value)
end

local function play(run: Run, object: Instance, info: TweenInfo, goal: { [string]: any })
	local tween = TweenService:Create(object, info, goal)
	table.insert(run.tweens, tween)
	tween:Play()
end

local function image(parent: Instance, name: string): ImageLabel?
	local found = Find.path(parent, name)
	return if found and found:IsA("ImageLabel") then found :: ImageLabel else nil
end

local function scaled(base: UDim2, factor: number): UDim2
	return UDim2.new(base.X.Scale * factor, base.X.Offset * factor, base.Y.Scale * factor, base.Y.Offset * factor)
end

-- Couleur de la rareté à l'instant `t` (s) : sa Color, ou sa suite RainbowColors qui défile (Secret).
local function colorAt(rarity: any, t: number): Color3
	local list = if rarity then rarity.RainbowColors else nil
	if type(list) == "table" and #list > 0 then
		local period = math.max(Settings.RainbowPeriod, 0.1)
		local position = (t / period % 1) * #list
		local index = math.floor(position)
		local a, b = list[index + 1], list[(index + 1) % #list + 1]
		return a:Lerp(b, position - index)
	end
	return if rarity and typeof(rarity.Color) == "Color3" then rarity.Color else Color3.new(1, 1, 1)
end

local function tint(run: Run, label: ImageLabel)
	set(run, label, "ImageColor3", colorAt(run.rarity, 0))
	table.insert(run.tinted, label)
end

-- L'objet en 3D dans Preview ; true s'il y est.
local function placeModel(run: Run, preview: ViewportFrame, asset: string): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("Items") else nil
	local template = if folder then folder:FindFirstChild(asset, true) else nil
	if template == nil or not (template:IsA("Model") or template:IsA("BasePart")) then
		return false
	end
	local ok, copy = pcall(function(): Instance
		return (template :: Instance):Clone()
	end)
	if not ok or typeof(copy) ~= "Instance" then
		return false
	end
	local model: Model
	if copy:IsA("Model") then
		model = copy
	else
		model = Instance.new("Model")
		copy.Parent = model
		model.PrimaryPart = copy :: BasePart
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	model.Name = "SecuredPreview"
	model:PivotTo(CFrame.new())
	local spec = Settings.Preview
	local center, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.Name = "SecuredPreviewCamera"
	camera.FieldOfView = spec.FieldOfView
	local radius = math.max(size.Magnitude / 2, 0.1)
	local distance = radius / math.tan(math.rad(spec.FieldOfView / 2)) * spec.Margin
	local focus = center.Position
	-- Face avant de l'objet (−Z de son pivot, « face avant vers la rue ») : la caméra se met devant et la regarde.
	local eye = focus + Vector3.new(0, 0, -1) * distance + Vector3.new(0, size.Y * spec.Lift, 0)
	camera.CFrame = CFrame.lookAt(eye, focus)
	camera.Parent = preview
	model.Parent = preview
	set(run, preview, "CurrentCamera", camera)
	table.insert(run.created, model)
	table.insert(run.created, camera)
	run.model = model
	return true
end

local function rain(run: Run, screen: ScreenGui)
	local fx = Find.path(screen, "SecuredFx")
	local template = image(screen, "SecuredFx.Rain.Template")
	if fx == nil or not fx:IsA("GuiObject") or template == nil then
		return
	end
	set(run, fx, "Visible", true)
	local spec = Settings.Rain
	local parent = template.Parent :: Instance
	for _ = 1, spec.Count do
		local drop = template:Clone()
		drop.Name = "RainDrop"
		drop.Visible = true
		drop.AnchorPoint = Vector2.new(0.5, 0.5)
		drop.Size = scaled(template.Size, 1 + (random:NextNumber() * 2 - 1) * spec.SizeJitter)
		local x = random:NextNumber()
		drop.Position = UDim2.fromScale(x, -0.1)
		drop.Rotation = random:NextNumber() * 360
		drop.ImageColor3 = colorAt(run.rarity, 0)
		drop.Parent = parent
		table.insert(run.created, drop)
		table.insert(run.tinted, drop)
		local time = spec.Time * (1 + (random:NextNumber() * 2 - 1) * spec.TimeJitter)
		local turn = spec.Spin * (if random:NextNumber() < 0.5 then -1 else 1)
		play(run, drop, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(x, 1.1),
			Rotation = drop.Rotation + turn,
		})
		run.drops += 1
	end
end

local function step(run: Run)
	if current ~= run then
		return
	end
	local t = os.clock() - run.startedAt
	for _, spin in run.spins do
		if spin.object.Parent ~= nil then
			spin.object.Rotation = spin.rest + spin.sign * (360 * t / spin.period) % 360
		end
	end
	if type(run.rarity) == "table" and type(run.rarity.RainbowColors) == "table" then
		local color = colorAt(run.rarity, t)
		for _, label in run.tinted do
			if label.Parent ~= nil then
				label.ImageColor3 = color
			end
		end
	end
	local model = run.model
	if model and model.Parent ~= nil then
		model:PivotTo(CFrame.Angles(0, math.rad(Settings.Preview.Turn * t), 0))
	end
	local tag = run.tag
	if tag and tag.Parent ~= nil then
		local spec = Settings.Tag
		tag.Rotation = run.tagRest + math.sin(2 * math.pi * spec.ShakeRate * t) * spec.ShakeAngle
	end
end

function SecuredCard.Stop()
	local run = current
	current = nil
	if run == nil then
		return
	end
	if run.loop then
		run.loop:Disconnect()
	end
	for _, tween in run.tweens do
		tween:Cancel()
	end
	for index = #run.saved, 1, -1 do
		local entry = run.saved[index]
		if entry.object.Parent ~= nil then
			pcall(function()
				(entry.object :: any)[entry.property] = entry.value
			end)
		end
	end
	for _, entry in run.attrs do
		entry.object:SetAttribute(entry.name, entry.value)
	end
	for _, object in run.created do
		object:Destroy()
	end
end

function SecuredCard.Play(screen: ScreenGui, info: Info): string?
	SecuredCard.Stop()
	if not SecuredTier.On("SecuredCardV2") then
		return nil
	end
	local card = Find.path(screen, "Card")
	local def = if type(info.ItemId) == "string" then Items.ById[info.ItemId] else nil
	if card == nil or def == nil then
		return nil
	end
	local tier, tag = SecuredTier.TierOf(def.Rarity, info.Income, info.Lucky)
	local look = Settings.Look[tier]
	local run: Run = {
		saved = {},
		attrs = {},
		created = {},
		tweens = {},
		tinted = {},
		spins = {},
		loop = nil,
		startedAt = os.clock(),
		rarity = Rarities.ById[def.Rarity],
		model = nil,
		tag = nil,
		tagRest = 0,
		drops = 0,
	}
	current = run
	plays += 1
	lastTier, lastTag = tier, tag

	-- L'objet en 3D.
	local foundPreview = Find.path(card, "Preview")
	local preview: ViewportFrame? = if foundPreview and foundPreview:IsA("ViewportFrame") then foundPreview :: ViewportFrame else nil
	if preview and type((def :: any).Asset) == "string" and placeModel(run, preview, (def :: any).Asset) then
		local icon = Find.path(card, "ItemIcon")
		if icon and icon:IsA("GuiObject") then
			set(run, icon, "Visible", false)
		end
	end
	local base = if preview then preview.Size else nil

	-- Le sunburst.
	local rays = image(card, "Rays")
	if rays and look.Rays then
		local spec = look.Rays
		set(run, rays, "ImageTransparency", spec.Transparency)
		if base then
			set(run, rays, "Size", scaled(base, spec.Size))
		end
		tint(run, rays)
		if rays:GetAttribute("FigmaSpin") ~= nil and Features.FramewispFx == true then
			setAttribute(run, rays, "SpinSpeed", 360 / spec.Period) -- FramewispFx le tourne (UI/FramewispFx)
		else
			save(run, rays, "Rotation")
			table.insert(run.spins, { object = rays :: GuiObject, rest = rays.Rotation, period = spec.Period, sign = 1 })
		end
	end
	local back = image(card, "RaysBack")
	if back then
		local spec = look.Back
		set(run, back, "Visible", spec ~= nil)
		if spec then
			set(run, back, "ImageTransparency", spec.Transparency)
			if base then
				set(run, back, "Size", scaled(base, spec.Size))
			end
			tint(run, back)
			save(run, back, "Rotation")
			table.insert(run.spins, { object = back :: GuiObject, rest = back.Rotation, period = spec.Period, sign = -1 })
		end
	end
	local burst = image(card, "Burst")
	if burst then
		set(run, burst, "Visible", look.Burst == true)
		if look.Burst == true then
			local spec = Settings.Burst
			set(run, burst, "ImageTransparency", 0)
			if base then
				set(run, burst, "Size", scaled(base, spec.From))
			end
			tint(run, burst)
			local goal: { [string]: any } = { ImageTransparency = 1 }
			if base then
				goal.Size = scaled(base, spec.To)
			end
			play(run, burst, TweenInfo.new(spec.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		end
	end
	if look.Rain == true then
		rain(run, screen)
	end

	-- Gros palier : TierScale et RarityTag.
	local tierScale = Find.path(card, "TierScale")
	if tier == "Grand" and tierScale and tierScale:IsA("UIScale") then
		set(run, tierScale, "Scale", Settings.TierScale)
	end
	local foundTag = Find.path(card, "RarityTag")
	if foundTag and foundTag:IsA("TextLabel") then
		local label = foundTag :: TextLabel
		set(run, label, "Visible", tag ~= nil)
		if tag then
			set(run, label, "Text", tag)
			save(run, label, "Rotation")
			run.tag = label
			run.tagRest = label.Rotation
		end
	end

	run.loop = RunService.Heartbeat:Connect(function()
		step(run)
	end)
	return tier
end

function SecuredCard.GetState(): { Plays: number, Active: boolean, Tier: string?, Tag: string?, Model: boolean, Drops: number }
	local run = current
	return {
		Plays = plays,
		Active = run ~= nil,
		Tier = lastTier,
		Tag = lastTag,
		Model = run ~= nil and run.model ~= nil,
		Drops = if run then run.drops else 0,
	}
end

return SecuredCard
