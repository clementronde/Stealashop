--!strict
-- ArmoredVanController (client ; a425, 24/11, L-324) : ce que le joueur voit du fourgon blindé de la casse du siècle
-- (serveur : ArmoredVanService ; valeurs : Config/ArmoredVan). Effets seulement : PV, coups, récompenses et colis sont au
-- serveur. Le fourgon en jeu : copie de ENV_Event_ArmoredVan de Clément, tag ArmoredVan (posé par le serveur).
--
--   - Gyrophares (L-324 Q2) : les pièces nommées dans Beacons.Left (Beacon_L, LightBar_L) et Beacons.Right (Beacon_R,
--     LightBar_R) clignotent en alternance, Period s par côté, tant que le fourgon roule (LocalTransparencyModifier du
--     côté éteint = Dim). Absents : rien.
--   - Casse (attribut ExplodedAt du fourgon, heure serveur ; L-324 Q1) : l'explosion du camion (TruckController)
--     reprise : chaque Pieces/Piece_xx (dont la porte ronde du coffre) part à l'horizontale à l'opposé de BlastPoint,
--     avec une montée (vitesses, rotation, chute et rebond : Config/TruckEvent Debris*, les mêmes que le camion),
--     retombe, reste DebrisLifetime s, puis s'efface en DebrisFadeTime s. Cargo (le trésor), hors de Pieces, reste
--     visible jusqu'au retrait du fourgon par le serveur (ArmoredVan.RemoveDelay). Explosion native locale (sans force
--     ni dégât) et son ExplosionSound (MarkerSounds.find ; absent : muet) à BlastPoint, si la casse est vue dans la
--     demi-seconde. Jet de billets (facultatif) : CashJet.Count copies de FX_Collect_Bill (Assets, l'effet du
--     ramassage) lancées de CashPoint vers l'arrière, qui retombent et s'effacent avec les pièces. Casse reçue trop
--     tard (streaming) : pièces cachées tout de suite. Sans BlastPoint : centre de la boîte englobante du modèle.
--   - Roues : pas tournées ici. Le serveur déplace tout le fourgon à chaque image (PivotTo répliqué) : une rotation
--     locale des roues serait écrasée.
--
-- Coupé par Config/Features.ArmoredVan = false. API : aucune.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ArmoredVan = require(Config:WaitForChild("ArmoredVan"))
local Features = require(Config:WaitForChild("Features"))
local TruckEvent = require(Config:WaitForChild("TruckEvent"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))

-- Une pièce qui vole (pièce du fourgon, ou copie locale d'un billet).
type Flyer = {
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
	Copy: boolean, -- copie locale (billet) : détruite à la fin
}

type Blast = {
	StartedAt: number, -- os.clock() local de la casse
	GroundY: number,
	Flyers: { Flyer },
}

type Watch = {
	Model: Model,
	Left: { BasePart },
	Right: { BasePart },
	Blinking: boolean,
	Exploded: boolean,
	Connection: RBXScriptConnection?,
}

-- Noms posés par ArmoredVanService et noms du modèle de Clément (L-324, Contract/Models).
local TAG = "ArmoredVan"
local EXPLODED_AT_ATTRIBUTE = "ExplodedAt"
local PIECES_NAME = "Pieces"
local BLAST_POINT = "BlastPoint"
local CASH_POINT = "CashPoint"
local ASSETS_NAME = "Assets"
local SOUND_HOLDER = "ArmoredVanExplosionSound" -- Attachment local du Terrain qui porte le son
-- Comme TruckController : effets seulement si la casse est vue dans la demi-seconde ; une pièce qui retombe à moins de
-- 4 studs/s s'arrête ; un son joué disparaît au plus tard 10 s après.
local FX_MAX_AGE = 0.5
local REST_SPEED = 4
local SOUND_MAX_LIFETIME = 10

local ArmoredVanController = {}

local watches: { [Model]: Watch } = {}
local blasts: { Blast } = {}
local random = Random.new()
local blinkSide = -1

-- Outils -----------------------------------------------------------------------------------------------------------

local function partsOf(root: Instance): { BasePart }
	local list: { BasePart } = {}
	if root:IsA("BasePart") then
		table.insert(list, root :: BasePart)
	end
	for _, descendant in root:GetDescendants() do
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

local function between(low: number, high: number): number
	return low + random:NextNumber() * math.max(high - low, 0)
end

-- Demi-hauteur, dans le monde, d'une boîte `size` orientée par `frame`.
local function verticalHalf(frame: CFrame, size: Vector3): number
	return (math.abs(frame.XVector.Y) * size.X + math.abs(frame.YVector.Y) * size.Y + math.abs(frame.ZVector.Y) * size.Z) / 2
end

-- Direction horizontale de `from` vers `to` (au hasard si elles se confondent).
local function outward(from: Vector3, to: Vector3): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude > 1e-3 then
		return flat.Unit
	end
	local angle = random:NextNumber() * 2 * math.pi
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local function flyer(piece: PVInstance, velocity: Vector3, copy: boolean): Flyer
	local cf, size = boxOf(piece)
	return {
		Piece = piece,
		Parts = partsOf(piece),
		Offset = cf:ToObjectSpace(piece:GetPivot()),
		Position = cf.Position,
		Rotation = cf.Rotation,
		Velocity = velocity,
		Axis = random:NextUnitVector(),
		Spin = between(-TruckEvent.DebrisSpinMax, TruckEvent.DebrisSpinMax),
		HalfHeight = verticalHalf(cf, size),
		Resting = false,
		Copy = copy,
	}
end

-- Gyrophares -------------------------------------------------------------------------------------------------------

local function beaconParts(model: Model, names: { string }): { BasePart }
	local list: { BasePart } = {}
	for _, name in names do
		local found = Find.path(model, name)
		if found then
			for _, part in partsOf(found) do
				table.insert(list, part)
			end
		end
	end
	return list
end

local function setBlink(watch: Watch, side: number)
	local dim = ArmoredVan.Beacons.Dim
	setFade(watch.Left, if side == 0 then 0 else dim)
	setFade(watch.Right, if side == 1 then 0 else dim)
end

local function stopBlink(watch: Watch)
	watch.Blinking = false
	setFade(watch.Left, 0)
	setFade(watch.Right, 0)
end

-- Casse ------------------------------------------------------------------------------------------------------------

-- Billets de FX_Collect_Bill lancés de CashPoint vers l'arrière du fourgon (facultatif).
local function cashJet(model: Model, blast: Blast)
	local spec = ArmoredVan.CashJet
	local point = Find.path(model, CASH_POINT)
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_NAME)
	local template = if assets then assets:FindFirstChild(spec.Asset, true) else nil
	if point == nil or not point:IsA("Attachment") or template == nil or not template:IsA("PVInstance") then
		return
	end
	local origin = (point :: Attachment).WorldPosition
	local back = outward(model:GetPivot().Position, origin)
	for _ = 1, spec.Count do
		local copy = (template :: PVInstance):Clone() :: PVInstance?
		if copy == nil then
			return -- pas Archivable
		end
		for _, descendant in copy:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		for _, part in partsOf(copy) do
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		end
		copy:PivotTo(CFrame.new(origin) * CFrame.Angles(0, random:NextNumber() * 2 * math.pi, 0))
		copy.Parent = Workspace
		local yaw = between(-spec.Spread, spec.Spread)
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(back)
		local velocity = direction * between(spec.Speed[1], spec.Speed[2]) + Vector3.new(0, between(spec.Up[1], spec.Up[2]), 0)
		table.insert(blast.Flyers, flyer(copy, velocity, true))
	end
end

local function startBlast(watch: Watch, age: number)
	stopBlink(watch)
	local model = watch.Model
	local pivot = model:GetPivot()
	local blastPoint = Find.path(model, BLAST_POINT)
	local origin: Vector3 = if blastPoint and blastPoint:IsA("Attachment")
		then (blastPoint :: Attachment).WorldPosition
		else (model:GetBoundingBox()).Position
	local blast: Blast = { StartedAt = os.clock() - age, GroundY = pivot.Position.Y, Flyers = {} }
	local folder = Find.path(model, PIECES_NAME)
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("PVInstance") then
				local cf = boxOf(child :: PVInstance)
				local velocity = outward(origin, cf.Position) * between(TruckEvent.DebrisSpeedMin, TruckEvent.DebrisSpeedMax)
					+ Vector3.new(0, between(TruckEvent.DebrisUpMin, TruckEvent.DebrisUpMax), 0)
				table.insert(blast.Flyers, flyer(child :: PVInstance, velocity, false))
			end
		end
	end
	if age <= TruckEvent.DebrisLifetime then
		cashJet(model, blast)
	end
	table.insert(blasts, blast)
	if age > FX_MAX_AGE then
		return
	end
	local template = MarkerSounds.find(ArmoredVan.ExplosionSound)
	if template then
		local holder = Instance.new("Attachment")
		holder.Name = SOUND_HOLDER
		holder.Position = origin
		holder.Parent = Workspace.Terrain
		MarkerSounds.playSound(template, holder)
		task.delay(SOUND_MAX_LIFETIME, function()
			holder:Destroy()
		end)
	end
	local fx = Instance.new("Explosion")
	fx.Position = origin
	fx.BlastRadius = ArmoredVan.ExplosionRadius
	fx.BlastPressure = 0 -- effet seulement : aucune force…
	fx.DestroyJointRadiusPercent = 0 -- … et aucun dégât
	fx.ExplosionType = Enum.ExplosionType.NoCraters
	fx.Parent = Workspace
end

-- Une image de la casse. Renvoie false quand elle est finie (pièces effacées, billets retirés).
local function stepBlast(blast: Blast, dt: number): boolean
	local age = os.clock() - blast.StartedAt
	local gravity = TruckEvent.DebrisGravity
	for _, debris in blast.Flyers do
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
		for _, debris in blast.Flyers do
			setFade(debris.Parts, fade)
		end
		if fade >= 1 then
			for _, debris in blast.Flyers do
				if debris.Copy then
					debris.Piece:Destroy()
				end
			end
			return false
		end
	end
	return true
end

-- Suivi des fourgons -----------------------------------------------------------------------------------------------

local function maybeExplode(watch: Watch)
	if watch.Exploded then
		return
	end
	local at = watch.Model:GetAttribute(EXPLODED_AT_ATTRIBUTE)
	if type(at) ~= "number" then
		return
	end
	watch.Exploded = true
	startBlast(watch, math.max(0, Workspace:GetServerTimeNow() - at))
end

local function track(instance: Instance)
	if not instance:IsA("Model") or watches[instance :: Model] ~= nil then
		return
	end
	local model = instance :: Model
	local watch: Watch = {
		Model = model,
		Left = beaconParts(model, ArmoredVan.Beacons.Left),
		Right = beaconParts(model, ArmoredVan.Beacons.Right),
		Blinking = true,
		Exploded = false,
		Connection = nil,
	}
	watches[model] = watch
	watch.Connection = model:GetAttributeChangedSignal(EXPLODED_AT_ATTRIBUTE):Connect(function()
		maybeExplode(watch)
	end)
	if blinkSide >= 0 then
		setBlink(watch, blinkSide)
	end
	maybeExplode(watch)
end

local function untrack(instance: Instance)
	local watch = if instance:IsA("Model") then watches[instance :: Model] else nil
	if watch == nil then
		return
	end
	watches[watch.Model] = nil
	if watch.Connection then
		watch.Connection:Disconnect()
	end
end

local function onFrame(dt: number)
	local side = math.floor(os.clock() / math.max(ArmoredVan.Beacons.Period, 0.05)) % 2
	if side ~= blinkSide then
		blinkSide = side
		for _, watch in watches do
			if watch.Blinking then
				setBlink(watch, side)
			end
		end
	end
	for index = #blasts, 1, -1 do
		if not stepBlast(blasts[index], dt) then
			table.remove(blasts, index)
		end
	end
end

function ArmoredVanController.Start()
	if (Features :: any).ArmoredVan ~= true then
		return
	end
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
	RunService.RenderStepped:Connect(onFrame)
end

return ArmoredVanController
