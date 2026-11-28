--!strict
-- Guard/DayPatrol (serveur, a518, 27/11 ; liaison L-438) : module d'aide de GuardService (sous-dossier : le Loader ne le
-- démarre pas). Interrupteur Features.GuardDayPatrol (PROD) / GuardDayPatrolDev (DEV et TEST) ; valeurs :
-- Config/Guards.DayPatrol. Calculs seulement : GuardService pose, fait marcher et réveille les vigiles.
--
-- Clément (27/11) : « les vigiles doivent tourner dans le magasin au lieu qu'ils apparaissent de nulle part quand on prend
-- un objet ; c'est quand on prend un objet que le vigile nous course, mais il est toujours dans le magasin en train de
-- marcher ». Un vigile de jour par magasin PNJ fait sa ronde (état Patrol, comme la ronde de nuit) entre les points
-- d'ici, en boucle, Walk à DayPatrol.Speed, une pause Idle tournée vers la vitrine à chaque point. Il ne repère personne :
-- seul un vol (ou la fin du chrono pour un intrus, L-118) le fait partir, comme le vigile qui sortait du GuardSpawn.
--
-- Points (Points) : ceux que Clément pose (facultatifs) : DayPatrol.PointName (« GuardPatrol_01 »…, Attachment ou pièce)
-- dans le magasin, dans l'ordre des numéros. Sinon : le GuardSpawn, puis un point devant chaque ShelfSlot_01 à _10 (sa
-- position, poussée de ShelfOffset studs vers le centre du volume Bounds, gardée à BoundsInset studs de ses bords), à
-- MinSpacing studs au moins l'un de l'autre, rangés dans l'ordre du tour du magasin (angle autour du centre de Bounds,
-- en partant du GuardSpawn). Tous à la hauteur des pieds au GuardSpawn (un magasin = un seul étage).
--
-- API :
--   DayPatrol.On() -> boolean
--   DayPatrol.Points(store, spawn) -> { Vector3 }   spawn : les pieds au GuardSpawn
--   DayPatrol.Pause() -> number                      durée d'une pause (s)
--   DayPatrol.LookPoint(store, from) -> Vector3?     le petit pas vers la vitrine, à la pause
--   DayPatrol.Speed() -> number ; DayPatrol.CheckInterval() -> number

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = (ReplicatedStorage :: any).Shared
local Guards = require(Shared.Config.Guards) :: any
local Find = require(Shared.Contract.Find) :: any
local Switch = require(script.Parent.Switch) :: any

local SWITCH = "GuardDayPatrol"
local SHELF_SLOT = "ShelfSlot_%02d" -- contrat 10.4 (Contract/Models)
local SHELF_SLOTS = 10
local BOUNDS = "Bounds"
local WINDOW = "Window"

local random = Random.new()

local DayPatrol = {}

local function cfg(): any
	return Guards.DayPatrol
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function positionOf(inst: Instance?): Vector3?
	if inst == nil then
		return nil
	elseif inst:IsA("Attachment") then
		return (inst :: Attachment).WorldPosition
	elseif inst:IsA("BasePart") then
		return (inst :: BasePart).Position
	end
	return nil
end

function DayPatrol.On(): boolean
	return Switch.On(SWITCH)
end

function DayPatrol.Speed(): number
	return cfg().Speed
end

function DayPatrol.CheckInterval(): number
	return cfg().CheckInterval
end

function DayPatrol.Pause(): number
	local c = cfg()
	local low, high = c.PauseMin, c.PauseMax
	if high <= low then
		return low
	end
	return low + (high - low) * random:NextNumber()
end

-- Garde `point` dans le pavé `box` (à plat), à `inset` studs de ses bords (au centre si le pavé est trop petit).
local function clampInside(box: BasePart, point: Vector3, inset: number): Vector3
	local localPoint = box.CFrame:Inverse() * point
	local hx = math.max(box.Size.X / 2 - inset, 0)
	local hz = math.max(box.Size.Z / 2 - inset, 0)
	local clamped = Vector3.new(math.clamp(localPoint.X, -hx, hx), localPoint.Y, math.clamp(localPoint.Z, -hz, hz))
	return box.CFrame * clamped
end

function DayPatrol.Points(store: Model, spawn: Vector3): { Vector3 }
	local c = cfg()
	local floorY = spawn.Y
	local function onFloor(p: Vector3): Vector3
		return Vector3.new(p.X, floorY, p.Z)
	end
	-- Points posés par Clément.
	local placed: { Vector3 } = {}
	for index = 1, c.PointMax do
		local at = positionOf(Find.path(store, string.format(c.PointName, index)))
		if at then
			table.insert(placed, onFloor(at))
		end
	end
	if #placed > 0 then
		return placed
	end
	-- Sinon : le GuardSpawn et un point devant chaque rayon.
	local bounds = Find.path(store, BOUNDS)
	local box = if bounds and bounds:IsA("BasePart") then bounds :: BasePart else nil
	local center = if box then box.Position else spawn
	local points: { Vector3 } = { onFloor(spawn) }
	for index = 1, SHELF_SLOTS do
		local at = positionOf(Find.path(store, string.format(SHELF_SLOT, index)))
		if at then
			local inward = flat(center - at)
			local p = if inward.Magnitude > 1e-3 then at + inward.Unit * math.min(c.ShelfOffset, inward.Magnitude) else at
			if box then
				p = clampInside(box, p, c.BoundsInset)
			end
			p = onFloor(p)
			local tooClose = false
			for _, other in points do
				if flat(other - p).Magnitude < c.MinSpacing then
					tooClose = true
					break
				end
			end
			if not tooClose then
				table.insert(points, p)
			end
		end
	end
	-- Ordre du tour : angle autour du centre, en partant du GuardSpawn (premier point).
	local function angle(p: Vector3): number
		local d = flat(p - center)
		return math.atan2(d.Z, d.X)
	end
	local start = angle(points[1])
	local function turn(p: Vector3): number
		return (angle(p) - start) % (2 * math.pi)
	end
	local first = points[1]
	table.remove(points, 1)
	table.sort(points, function(a: Vector3, b: Vector3): boolean
		return turn(a) < turn(b)
	end)
	table.insert(points, 1, first)
	return points
end

function DayPatrol.LookPoint(store: Model, from: Vector3): Vector3?
	local window = Find.path(store, WINDOW)
	local target: Vector3? = positionOf(window)
	if target == nil and window and window:IsA("Model") then
		local ok, frame = pcall(function(): CFrame
			local cframe = (window :: Model):GetBoundingBox()
			return cframe
		end)
		target = if ok then frame.Position else nil
	end
	if target == nil then
		return nil
	end
	local d = flat(target - from)
	if d.Magnitude < 1e-3 then
		return nil
	end
	return from + d.Unit * cfg().LookStep
end

return DayPatrol
