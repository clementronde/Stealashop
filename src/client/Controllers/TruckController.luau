--!strict
-- TruckController (client) : ce que le joueur voit de l'événement camion (liaison L-049 ; serveur :
-- TruckEventService ; valeurs : Config/TruckEvent). Rien de ce qui compte ne se décide ici : PV,
-- colis, contenu et ramassage sont au serveur.
--
--   - Barre de vie : une copie de ReplicatedStorage/Assets/UI/BB_TruckHP, la barre du camion de
--     Clément (L-052, contrat 2.2 : `Label` et `Fill`, comme BB_WindowHP), telle qu'il l'a faite
--     (taille et portée), accrochée à l'Attachment HealthBarPoint du camion (modèle taggé
--     EventTruck). Repli tant qu'elle manque : une copie de BB_WindowHP (la barre des vitrines),
--     agrandie de HealthBarScale et visible jusqu'à HealthBarMaxDistance studs. `Label` écrit
--     « PV / PV max » (Format.hp), `Fill` prend la largeur des PV. Lue sur les attributs HP et MaxHP
--     du camion (WindowService) : juste aussi pour un joueur qui arrive en cours de route. Cachée à
--     l'explosion. Ni l'une ni l'autre : pas de barre (une ligne en Studio). Les deux modèles sont
--     cherchés dans Assets/UI et ses sous-dossiers, comme le fait le ContractChecker.
--   - Explosion (attribut ExplodedAt du camion, heure serveur) : chaque pièce Pieces/Piece_xx part
--     à l'horizontale à l'opposé de BlastPoint, avec une montée (vitesses et rotation tirées entre
--     les valeurs Debris*), retombe et rebondit sur le sol du camion, reste DebrisLifetime s, puis
--     s'efface en DebrisFadeTime s
--     (LocalTransparencyModifier, local). Le serveur a déjà coupé leurs collisions et retire le
--     camion RemoveDelay s après. Explosion native de Roblox, locale, sans force ni dégât, si
--     ExplosionFx (en attendant un effet de Clément). Explosion vue trop tard (camion arrivé par le
--     streaming après DebrisLifetime s) : pièces cachées tout de suite.
--   - Colis du camion : modèles de Workspace/CarryDrops portant l'attribut TruckBox, posés par
--     CarryService à leur point d'arrivée. Chacun vole localement depuis FlightFrom, de
--     FlightStartsAt pendant FlightDuration (heure serveur), en cloche (FlightHeight) en tournant sur
--     lui-même (FlightSpins), puis retrouve sa place serveur. Pendant le vol : la traînée de Clément,
--     copie du Trail et de ses Attachments TrailTop et TrailBottom de FX_BoxTrail
--     (ReplicatedStorage/Assets), posée sur la pièce principale du colis ; traînée V0 blanche si
--     FX_BoxTrail n'est pas livré.
--   - Invite sur chaque colis du camion atterri, mains vides (attribut Carrying du joueur) :
--     ProximityPrompt GrabActionText (« Grab ») / « Premium Box », maintien = temps de prise du type
--     (Balance.Heist.BoxTiers[Tier].GrabTime), portée Bat.DroppedGrabMaxDistance − 0,5. Début du
--     maintien : GrabDropped(dropId) ; invite déclenchée : GrabDropped(dropId) une seconde fois et
--     animation Grab (AnimationController s'il est là). Le serveur vérifie tout.
--
-- Coupé par Config/Features.TruckEvent = false. API (client) : aucune.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Bat = require(Config:WaitForChild("Bat"))
local Features = require(Config:WaitForChild("Features"))
local Shatter = require(Config:WaitForChild("Shatter"))
local TruckEvent = require(Config:WaitForChild("TruckEvent"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))
local Format = require(Shared:WaitForChild("Format"))

-- Ce que ce contrôleur utilise d'AnimationController (a09).
type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
}

type Debris = {
	Piece: PVInstance,
	Parts: { BasePart },
	Offset: CFrame, -- pivot de la pièce dans l'espace de son centre
	Position: Vector3, -- centre
	Rotation: CFrame,
	Velocity: Vector3,
	Axis: Vector3,
	Spin: number, -- rad/s
	HalfHeight: number,
	Resting: boolean,
}

type Blast = {
	Watch: TruckWatch,
	StartedAt: number, -- os.clock() local de l'explosion
	GroundY: number,
	Pieces: { Debris },
}

type TruckWatch = {
	Model: Model,
	Billboard: BillboardGui?,
	Fill: GuiObject?,
	Label: TextLabel?,
	FillHeight: UDim,
	Fraction: number?,
	Exploded: boolean,
	Connections: { RBXScriptConnection },
}

type BoxWatch = {
	Model: Model,
	DropId: string,
	Tier: string,
	LandsAt: number, -- heure serveur de l'atterrissage (0 : déjà au sol)
	Prompt: ProximityPrompt?,
}

type Flight = {
	Watch: BoxWatch,
	From: Vector3,
	To: CFrame, -- place serveur du colis
	StartsAt: number, -- heure serveur
	Duration: number,
	Axis: Vector3,
	Trail: { Instance }, -- traînée et ses Attachments : la traînée d'abord
}

-- Noms du contrat (2.2 ; L-049, L-052, Contract/Models).
local BILLBOARD_NAME = "BB_TruckHP" -- la barre du camion de Clément (L-052)
local FALLBACK_BILLBOARD = "BB_WindowHP" -- repli : la barre des vitrines, agrandie
local HEALTH_BAR_POINT = "HealthBarPoint"
local PIECES_NAME = "Pieces"
local BLAST_POINT = "BlastPoint"
local TRAIL_ASSET = "FX_BoxTrail"
local TRAIL_NAME = "Trail"
local TRAIL_TOP = "TrailTop"
local TRAIL_BOTTOM = "TrailBottom"
local ASSETS_NAME = "Assets"
local GRAB_ANIMATION = "Grab" -- contrat 2.4
-- Posés par le serveur (mêmes noms dans TruckEventService, WindowService et CarryService).
local TRUCK_TAG = "EventTruck"
local HP_ATTRIBUTE = "HP"
local MAX_HP_ATTRIBUTE = "MaxHP"
local EXPLODED_AT_ATTRIBUTE = "ExplodedAt"
local DROPS_FOLDER = "CarryDrops"
local DROP_ID_ATTRIBUTE = "DropId"
local TRUCK_BOX_ATTRIBUTE = "TruckBox"
local TIER_ATTRIBUTE = "Tier"
local FLIGHT_FROM_ATTRIBUTE = "FlightFrom"
local FLIGHT_STARTS_AT_ATTRIBUTE = "FlightStartsAt"
local FLIGHT_DURATION_ATTRIBUTE = "FlightDuration"
local CARRYING_ATTRIBUTE = "Carrying" -- posé par CarryService sur le Player tant qu'il porte
local PROMPT_NAME = "GrabPrompt"
local BOX_SUFFIX = "Box" -- « Premium Box » (L-036)

-- V0 proposé, absent du doc : invites revues 5 fois par seconde (atterrissage).
local REFRESH_INTERVAL = 0.2
-- V0 proposé, absent du doc : invite visible un demi-stud avant la portée du serveur (comme les rayons).
local PROMPT_DISTANCE_MARGIN = 0.5
-- V0 proposé, absent du doc : explosion jouée seulement si on la voit dans la demi-seconde.
local FX_MAX_AGE = 0.5
-- V0 proposé, absent du doc : une pièce qui retombe à moins de 4 studs/s se pose et ne tourne plus.
local REST_SPEED = 4
-- V0 proposé, absent du doc : traînée blanche de remplacement (FX_BoxTrail pas livré).
local V0_TRAIL_LIFETIME = 0.35
local V0_TRAIL_HALF_HEIGHT = 0.6

local IS_STUDIO = RunService:IsStudio()

local player = Players.LocalPlayer

local TruckController = {}

local Net: any = nil
local animation: AnimationApi? = nil
local playerGui: Instance? = nil
local trucks: { [Instance]: TruckWatch } = {}
local boxes: { [Instance]: BoxWatch } = {}
local blasts: { Blast } = {}
local flights: { Flight } = {}
local noticed: { [string]: boolean } = {}
local random = Random.new()

local function once(key: string, message: string)
	if noticed[key] or not IS_STUDIO then
		return
	end
	noticed[key] = true
	print(`[TruckController] {message}`)
end

-- Barre de vie ----------------------------------------------------------------------------------

-- Modèle de billboard `name` de Clément, dans Assets/UI ou un de ses sous-dossiers (2.2).
local function billboard(name: string): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(name, true) else nil
	if found and found:IsA("BillboardGui") then
		return found :: BillboardGui
	end
	return nil
end

-- Modèle de la barre du camion : BB_TruckHP, sinon BB_WindowHP ; et vrai pour ce repli (à agrandir).
local function billboardTemplate(): (BillboardGui?, boolean)
	local own = billboard(BILLBOARD_NAME)
	if own then
		return own, false
	end
	local folder = table.concat(UI.BillboardFolder, ".")
	local fallback = billboard(FALLBACK_BILLBOARD)
	if fallback then
		once(
			"billboard.fallback",
			`{BILLBOARD_NAME} absent de ReplicatedStorage.{folder} : barre de vie du camion = copie de {FALLBACK_BILLBOARD} agrandie (L-052)`
		)
		return fallback, true
	end
	once("billboard", `{BILLBOARD_NAME} et {FALLBACK_BILLBOARD} absents de ReplicatedStorage.{folder} : pas de barre de vie sur le camion`)
	return nil, false
end

local function refreshBar(watch: TruckWatch)
	local gui = watch.Billboard
	if gui == nil then
		return
	end
	local model = watch.Model
	local maxValue = model:GetAttribute(MAX_HP_ATTRIBUTE)
	local maxHp = if type(maxValue) == "number" then maxValue else 0
	if watch.Exploded or maxHp <= 0 then
		gui.Enabled = false
		return
	end
	local hpValue = model:GetAttribute(HP_ATTRIBUTE)
	local hp = math.clamp(if type(hpValue) == "number" then hpValue else maxHp, 0, maxHp)
	local fraction = hp / maxHp
	local wasVisible = gui.Enabled
	gui.Enabled = true
	local label = watch.Label
	if label then
		label.Text = `{Format.hp(hp)} / {Format.hp(maxHp)}`
	end
	local fill = watch.Fill
	if fill and watch.Fraction ~= fraction then
		local target = UDim2.new(fraction, 0, watch.FillHeight.Scale, watch.FillHeight.Offset)
		if wasVisible and watch.Fraction ~= nil then
			TweenService:Create(fill, TweenInfo.new(Shatter.HPBar.TweenTime), { Size = target }):Play()
		else
			fill.Size = target
		end
		watch.Fraction = fraction
	end
end

local function makeBillboard(watch: TruckWatch)
	if watch.Billboard or playerGui == nil then
		return
	end
	local template, fallback = billboardTemplate()
	local point = Find.path(watch.Model, HEALTH_BAR_POINT)
	if template == nil or point == nil then
		if template and point == nil then
			once("point", `{HEALTH_BAR_POINT} absent du camion : pas de barre de vie`)
		end
		return
	end
	local gui = template:Clone()
	gui.Name = `{template.Name}_{watch.Model.Name}`
	if fallback then
		-- La barre d'une vitrine, agrandie et visible de loin ; BB_TruckHP garde la taille et la portée de Clément.
		local scale = TruckEvent.HealthBarScale
		local size = gui.Size
		gui.Size = UDim2.new(size.X.Scale * scale, size.X.Offset * scale, size.Y.Scale * scale, size.Y.Offset * scale)
		gui.MaxDistance = TruckEvent.HealthBarMaxDistance
	end
	gui.Adornee = point
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local fill = Find.path(gui, "Fill")
	local label = Find.path(gui, "Label")
	if fill and fill:IsA("GuiObject") then
		watch.Fill = fill :: GuiObject
		watch.FillHeight = (fill :: GuiObject).Size.Y
	end
	if label and label:IsA("TextLabel") then
		watch.Label = label :: TextLabel
	end
	watch.Fraction = nil
	gui.Parent = playerGui
	watch.Billboard = gui
	refreshBar(watch)
end

-- Explosion -------------------------------------------------------------------------------------

-- Pièces BasePart d'une pièce du camion (la pièce elle-même, ou celles d'un Model).
local function partsOf(piece: PVInstance): { BasePart }
	local list: { BasePart } = {}
	if piece:IsA("BasePart") then
		table.insert(list, piece :: BasePart)
	end
	for _, descendant in piece:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(list, descendant :: BasePart)
		end
	end
	return list
end

local function boxOf(piece: PVInstance): (CFrame, Vector3)
	if piece:IsA("BasePart") then
		local part = piece :: BasePart
		return part.CFrame, part.Size
	end
	return (piece :: Model):GetBoundingBox()
end

local function setFade(parts: { BasePart }, fade: number)
	for _, part in parts do
		part.LocalTransparencyModifier = fade
	end
end

local function pieceList(model: Model): { PVInstance }
	local list: { PVInstance } = {}
	local folder = Find.path(model, PIECES_NAME)
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("PVInstance") then
				table.insert(list, child :: PVInstance)
			end
		end
	end
	return list
end

local function between(low: number, high: number): number
	return low + random:NextNumber() * math.max(high - low, 0)
end

local function startBlast(watch: TruckWatch, age: number)
	local model = watch.Model
	local pivot = model:GetPivot()
	local blastPoint = Find.path(model, BLAST_POINT)
	local origin: Vector3 = if blastPoint and blastPoint:IsA("Attachment")
		then (blastPoint :: Attachment).WorldPosition
		else pivot.Position + Vector3.new(0, 5, 0)
	local blast: Blast = { Watch = watch, StartedAt = os.clock() - age, GroundY = pivot.Position.Y, Pieces = {} }
	for _, piece in pieceList(model) do
		local cf, size = boxOf(piece)
		-- Vers l'extérieur à l'horizontale, plus la montée : les pièces du bas ne partent pas dans le sol.
		local out = cf.Position - origin
		local flatOut = Vector3.new(out.X, 0, out.Z)
		local angle = random:NextNumber() * 2 * math.pi
		local direction = if flatOut.Magnitude > 1e-3 then flatOut.Unit else Vector3.new(math.cos(angle), 0, math.sin(angle))
		local velocity = direction * between(TruckEvent.DebrisSpeedMin, TruckEvent.DebrisSpeedMax)
			+ Vector3.new(0, between(TruckEvent.DebrisUpMin, TruckEvent.DebrisUpMax), 0)
		table.insert(blast.Pieces, {
			Piece = piece,
			Parts = partsOf(piece),
			Offset = cf:ToObjectSpace(piece:GetPivot()),
			Position = cf.Position,
			Rotation = cf.Rotation,
			Velocity = velocity,
			Axis = random:NextUnitVector(),
			Spin = between(-TruckEvent.DebrisSpinMax, TruckEvent.DebrisSpinMax),
			HalfHeight = size.Y / 2,
			Resting = false,
		})
	end
	table.insert(blasts, blast)
	if TruckEvent.ExplosionFx and age <= FX_MAX_AGE then
		local fx = Instance.new("Explosion")
		fx.Position = origin
		fx.BlastRadius = TruckEvent.ExplosionRadius
		fx.BlastPressure = 0 -- effet seulement : aucune force…
		fx.DestroyJointRadiusPercent = 0 -- … et aucun dégât
		fx.ExplosionType = Enum.ExplosionType.NoCraters
		fx.Parent = Workspace
	end
end

-- Une image de l'explosion. Renvoie false quand elle est finie (pièces effacées).
local function stepBlast(blast: Blast, dt: number): boolean
	local age = os.clock() - blast.StartedAt
	local gravity = TruckEvent.DebrisGravity
	for _, debris in blast.Pieces do
		if debris.Resting or debris.Piece.Parent == nil then
			continue
		end
		debris.Velocity -= Vector3.new(0, gravity * dt, 0)
		local position = debris.Position + debris.Velocity * dt
		local floor = blast.GroundY + debris.HalfHeight
		if position.Y < floor then
			position = Vector3.new(position.X, floor, position.Z)
			local fall = -debris.Velocity.Y
			if fall < REST_SPEED then
				debris.Resting = true
				debris.Velocity = Vector3.zero
			else
				debris.Velocity = Vector3.new(debris.Velocity.X * 0.6, fall * TruckEvent.DebrisBounce, debris.Velocity.Z * 0.6)
				debris.Spin *= 0.5
			end
		end
		debris.Position = position
		debris.Rotation = CFrame.fromAxisAngle(debris.Axis, debris.Spin * dt) * debris.Rotation
		debris.Piece:PivotTo(CFrame.new(position) * debris.Rotation * debris.Offset)
	end
	if age > TruckEvent.DebrisLifetime then
		local fade = math.clamp((age - TruckEvent.DebrisLifetime) / math.max(TruckEvent.DebrisFadeTime, 1e-3), 0, 1)
		for _, debris in blast.Pieces do
			setFade(debris.Parts, fade)
		end
		if fade >= 1 then
			return false
		end
	end
	return true
end

local function maybeExplode(watch: TruckWatch)
	if watch.Exploded then
		return
	end
	local at = watch.Model:GetAttribute(EXPLODED_AT_ATTRIBUTE)
	if type(at) ~= "number" then
		return
	end
	watch.Exploded = true
	refreshBar(watch)
	local age = math.max(Workspace:GetServerTimeNow() - at, 0)
	if age >= TruckEvent.DebrisLifetime then
		for _, piece in pieceList(watch.Model) do
			setFade(partsOf(piece), 1) -- vue trop tard : déjà retombée et effacée chez les autres
		end
		return
	end
	startBlast(watch, age)
end

-- Camions ---------------------------------------------------------------------------------------

local function untrackTruck(model: Instance)
	local watch = trucks[model]
	if watch == nil then
		return
	end
	trucks[model] = nil
	for _, connection in watch.Connections do
		connection:Disconnect()
	end
	local gui = watch.Billboard
	watch.Billboard = nil
	if gui then
		gui:Destroy()
	end
	for index = #blasts, 1, -1 do
		if blasts[index].Watch == watch then
			table.remove(blasts, index)
		end
	end
end

local function trackTruck(instance: Instance)
	if not instance:IsA("Model") or trucks[instance] ~= nil then
		return
	end
	local model = instance :: Model
	local watch: TruckWatch = {
		Model = model,
		Billboard = nil,
		Fill = nil,
		Label = nil,
		FillHeight = UDim.new(1, 0),
		Fraction = nil,
		Exploded = false,
		Connections = {},
	}
	trucks[instance] = watch
	for _, name in { HP_ATTRIBUTE, MAX_HP_ATTRIBUTE } do
		table.insert(
			watch.Connections,
			model:GetAttributeChangedSignal(name):Connect(function()
				refreshBar(watch)
			end)
		)
	end
	table.insert(
		watch.Connections,
		model:GetAttributeChangedSignal(EXPLODED_AT_ATTRIBUTE):Connect(function()
			maybeExplode(watch)
		end)
	)
	table.insert(
		watch.Connections,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				untrackTruck(model)
			end
		end)
	)
	makeBillboard(watch)
	maybeExplode(watch)
end

-- Colis du camion -------------------------------------------------------------------------------

local function anchorOf(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return if part then part :: BasePart else nil
end

local function trailTemplate(): Instance?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_NAME)
	local found = if assets then assets:FindFirstChild(TRAIL_ASSET, true) else nil
	if found == nil then
		once("trail", `{TRAIL_ASSET} absent de ReplicatedStorage/{ASSETS_NAME} : traînée V0 blanche sur les colis du camion`)
	end
	return found
end

-- Pose la traînée de vol sur `part` ; renvoie la traînée puis ses Attachments.
local function attachTrail(part: BasePart): { Instance }
	local template = trailTemplate()
	if template then
		local trail = Find.path(template, TRAIL_NAME)
		local top = Find.path(template, TRAIL_TOP)
		local bottom = Find.path(template, TRAIL_BOTTOM)
		if trail and trail:IsA("Trail") and top and top:IsA("Attachment") and bottom and bottom:IsA("Attachment") then
			local source = trail :: Trail
			local a0 = top:Clone() :: Attachment
			local a1 = bottom:Clone() :: Attachment
			a0.Parent = part
			a1.Parent = part
			local copy = source:Clone()
			-- Même sens que chez Clément (TrailTop puis TrailBottom, sauf s'il les a inversés).
			if source.Attachment0 == bottom then
				copy.Attachment0, copy.Attachment1 = a1, a0
			else
				copy.Attachment0, copy.Attachment1 = a0, a1
			end
			copy.Enabled = true
			copy.Parent = part
			return { copy, a0, a1 }
		end
		once("trail.parts", `{TRAIL_ASSET} sans {TRAIL_NAME}, {TRAIL_TOP} ou {TRAIL_BOTTOM} : traînée V0 blanche`)
	end
	local a0 = Instance.new("Attachment")
	a0.Name = TRAIL_TOP
	a0.Position = Vector3.new(0, V0_TRAIL_HALF_HEIGHT, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = TRAIL_BOTTOM
	a1.Position = Vector3.new(0, -V0_TRAIL_HALF_HEIGHT, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = V0_TRAIL_LIFETIME
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = part
	return { trail, a0, a1 }
end

-- Coupe la traînée et la retire quand sa queue a disparu.
local function stopTrail(objects: { Instance })
	local trail = objects[1]
	local lifetime = V0_TRAIL_LIFETIME
	if trail and trail:IsA("Trail") then
		(trail :: Trail).Enabled = false
		lifetime = (trail :: Trail).Lifetime
	end
	task.delay(lifetime + 0.1, function()
		for _, object in objects do
			object:Destroy()
		end
	end)
end

-- Une image du vol. Renvoie false à l'atterrissage.
local function stepFlight(flight: Flight, serverNow: number): boolean
	local model = flight.Watch.Model
	if model.Parent == nil then
		return false
	end
	local alpha = math.clamp((serverNow - flight.StartsAt) / math.max(flight.Duration, 1e-3), 0, 1)
	if alpha >= 1 then
		model:PivotTo(flight.To)
		stopTrail(flight.Trail)
		return false
	end
	local position = flight.From:Lerp(flight.To.Position, alpha)
		+ Vector3.new(0, 4 * TruckEvent.FlightHeight * alpha * (1 - alpha), 0)
	local spin = CFrame.fromAxisAngle(flight.Axis, (1 - alpha) * TruckEvent.FlightSpins * 2 * math.pi)
	model:PivotTo(CFrame.new(position) * spin * flight.To.Rotation)
	return true
end

local function playGrab()
	local api = animation
	if api then
		pcall(api.PlayPlayer, GRAB_ANIMATION)
	end
end

local function refreshPrompt(watch: BoxWatch, serverNow: number)
	local prompt = watch.Prompt
	if prompt then
		prompt.Enabled = serverNow >= watch.LandsAt and player:GetAttribute(CARRYING_ATTRIBUTE) == nil
	end
end

local function addPrompt(watch: BoxWatch, part: BasePart)
	local info = Balance.Heist.BoxTiers[watch.Tier]
	if info == nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = TruckEvent.GrabActionText
	prompt.ObjectText = `{info.DisplayName} {BOX_SUFFIX}`
	prompt.HoldDuration = info.GrabTime
	prompt.MaxActivationDistance = math.max(Bat.DroppedGrabMaxDistance - PROMPT_DISTANCE_MARGIN, 1)
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.PromptButtonHoldBegan:Connect(function()
		Net.Client.GrabDropped:Fire(watch.DropId) -- début du maintien
	end)
	prompt.Triggered:Connect(function()
		Net.Client.GrabDropped:Fire(watch.DropId) -- fin du maintien
		playGrab()
	end)
	prompt.Parent = part
	watch.Prompt = prompt
	refreshPrompt(watch, Workspace:GetServerTimeNow())
end

local function untrackBox(model: Instance)
	local watch = boxes[model]
	if watch == nil then
		return
	end
	boxes[model] = nil
	local prompt = watch.Prompt
	watch.Prompt = nil
	if prompt then
		prompt:Destroy()
	end
	for index = #flights, 1, -1 do
		local flight = flights[index]
		if flight.Watch == watch then
			table.remove(flights, index)
			stopTrail(flight.Trail)
		end
	end
end

local function trackBox(instance: Instance)
	if not instance:IsA("Model") or boxes[instance] ~= nil or instance:GetAttribute(TRUCK_BOX_ATTRIBUTE) ~= true then
		return
	end
	local model = instance :: Model
	local dropId = model:GetAttribute(DROP_ID_ATTRIBUTE)
	local tier = model:GetAttribute(TIER_ATTRIBUTE)
	local part = anchorOf(model)
	if type(dropId) ~= "string" or type(tier) ~= "string" or part == nil then
		return
	end
	local fromValue = model:GetAttribute(FLIGHT_FROM_ATTRIBUTE)
	local startsValue = model:GetAttribute(FLIGHT_STARTS_AT_ATTRIBUTE)
	local durationValue = model:GetAttribute(FLIGHT_DURATION_ATTRIBUTE)
	local from: Vector3? = if typeof(fromValue) == "Vector3" then fromValue else nil
	local startsAt: number = if type(startsValue) == "number" then startsValue else 0
	local duration: number = if type(durationValue) == "number" then durationValue else 0
	local watch: BoxWatch = {
		Model = model,
		DropId = dropId,
		Tier = tier,
		LandsAt = if from then startsAt + duration else 0,
		Prompt = nil,
	}
	boxes[instance] = watch
	addPrompt(watch, part)
	local serverNow = Workspace:GetServerTimeNow()
	if from and serverNow < watch.LandsAt then
		local flight: Flight = {
			Watch = watch,
			From = from,
			To = model:GetPivot(),
			StartsAt = startsAt,
			Duration = duration,
			Axis = random:NextUnitVector(),
			Trail = attachTrail(part),
		}
		table.insert(flights, flight)
		stepFlight(flight, serverNow) -- pas une image à la place d'arrivée
	end
end

local function watchDrops(folder: Instance)
	folder.ChildAdded:Connect(function(child: Instance)
		-- Après l'arrivée de ses attributs, posés par le serveur avant le parentage.
		trackBox(child)
	end)
	folder.ChildRemoved:Connect(untrackBox)
	for _, child in folder:GetChildren() do
		trackBox(child)
	end
end

-- Démarrage ---------------------------------------------------------------------------------------

local function onFrame(dt: number)
	for index = #blasts, 1, -1 do
		if not stepBlast(blasts[index], dt) then
			table.remove(blasts, index)
		end
	end
	if #flights > 0 then
		local serverNow = Workspace:GetServerTimeNow()
		for index = #flights, 1, -1 do
			if not stepFlight(flights[index], serverNow) then
				table.remove(flights, index)
			end
		end
	end
end

local function refreshPrompts()
	local serverNow = Workspace:GetServerTimeNow()
	for _, watch in boxes do
		refreshPrompt(watch, serverNow)
	end
end

function TruckController.Start()
	if not Features.TruckEvent then
		return
	end
	Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	local module = script.Parent:FindFirstChild("AnimationController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any).PlayPlayer) == "function" then
			animation = result :: any
		end
	end

	RunService.Heartbeat:Connect(function(dt: number)
		xpcall(onFrame, function(err: any)
			warn(`[TruckController] {err}`)
		end, dt)
	end)

	local drops = Workspace:FindFirstChild(DROPS_FOLDER)
	if drops then
		watchDrops(drops)
	end
	Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == DROPS_FOLDER then
			watchDrops(child)
		end
	end)
	player:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(refreshPrompts)

	-- Barres de vie : il faut le PlayerGui du joueur.
	playerGui = player:WaitForChild("PlayerGui")
	for _, instance in CollectionService:GetTagged(TRUCK_TAG) do
		trackTruck(instance)
	end
	-- Avec StreamingEnabled, le camion arrive et repart avec la zone autour du joueur.
	CollectionService:GetInstanceAddedSignal(TRUCK_TAG):Connect(trackTruck)
	CollectionService:GetInstanceRemovedSignal(TRUCK_TAG):Connect(untrackTruck)

	while true do
		task.wait(REFRESH_INTERVAL)
		xpcall(refreshPrompts, function(err: any)
			warn(`[TruckController] {err}`)
		end)
	end
end

return TruckController
