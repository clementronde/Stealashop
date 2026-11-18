--!strict
-- Guard/Sidestep (serveur, f70c3b ; T-217, Play de rejeu de fusion71, Kiosque) : module d'aide de GuardService
-- (sous-dossier : le Loader ne le démarre pas). Valeurs : Config/Chase.Sidestep (interrupteur Enabled).
--
-- En poursuite directe (le vigile voit sa cible, GuardService chaseInSight), il courait tout droit vers le point visé :
-- les rayons de sa ligne de vue partent de son centre, et un poteau fin à côté de cette ligne (Lamp_S1, 1,35 stud de
-- large, à 0,8 stud de sa ligne) ne les coupait pas. Il le percutait (93 → 49 studs/s en une image).
-- Avant chaque MoveTo vers le point visé : rayons parallèles à sa ligne, de chaque côté, tous les 0,5 stud jusqu'à
-- `side` studs, à hauteur du centre et des genoux. Le plus proche qui touche une pièce fine (CanCollide, au plus Chase.Sidestep.ThinMax studs en
-- X et en Z) : il vise d'abord un point Beyond studs après elle, sur sa ligne, décalé vers son côté libre (puis l'autre)
-- du plus petit multiple de ShiftStep (au plus ShiftMax) tel que son couloir (centre, genoux, flancs) jusqu'à ce point
-- est libre, hors zone safe, et que ce point voit le point visé (centre et genoux). Aucun : le point visé (la règle
-- d'avant). Mur, rayon de magasin, gros obstacle : rien ne change. Le point est recalculé à chaque visée (0,1 s) :
-- passé le poteau, il revise droit.
--
-- API :
--   Sidestep.Aim(from, aim, side, knee, params, inSafe) -> Vector3   from : son HumanoidRootPart ; knee : distance de son
--                                                                     centre à la hauteur des genoux ; params : ses
--                                                                     RaycastParams ; inSafe(point) : zone safe ?

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Chase = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Chase")) :: any

local LANE_SPACING = 0.5 -- écart des rayons de flanc (studs) : voit un poteau d'au moins 0,5 stud de large

local Sidestep = {}

local function positive(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge
end

local function clear(from: Vector3, to: Vector3, params: RaycastParams): boolean
	local direction = to - from
	if direction.Magnitude < 1e-3 then
		return true
	end
	return Workspace:Raycast(from, direction, params) == nil
end

-- Pièce fine : collisionne, au plus `thin` studs en X et en Z (taille de la pièce).
local function isThin(instance: Instance, thin: number): boolean
	if not instance:IsA("BasePart") then
		return false
	end
	local part = instance :: BasePart
	return part.CanCollide and part.Size.X <= thin and part.Size.Z <= thin
end

function Sidestep.Aim(from: Vector3, aim: Vector3, side: number, knee: number, params: RaycastParams, inSafe: (Vector3) -> boolean): Vector3
	local cfg = Chase.Sidestep
	if type(cfg) ~= "table" or cfg.Enabled ~= true or not positive(cfg.ThinMax) or not positive(cfg.ShiftStep)
		or not positive(cfg.ShiftMax) or not positive(side)
	then
		return aim
	end
	local to = Vector3.new(aim.X, from.Y, aim.Z)
	local offset = to - from
	local length = offset.Magnitude
	if length < 1e-3 then
		return aim
	end
	local dir = offset / length
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local drop = Vector3.new(0, math.max(knee, 0), 0)
	-- Couloirs de chaque côté de sa ligne, tous les LANE_SPACING studs jusqu'à `side` (un poteau plus large qu'eux en
	-- touche au moins un).
	local lanes: { number } = {}
	local count = math.max(1, math.ceil(side / LANE_SPACING - 1e-6))
	for i = 1, count do
		table.insert(lanes, side * i / count)
	end
	-- Le plus proche obstacle fin sur un flanc.
	local nearest: number? = nil
	local hitSign = 0
	for _, sign in { 1, -1 } do
		for _, lane in lanes do
			for _, low in { Vector3.zero, drop } do
				local origin = from + across * (lane * sign) - low
				local hit = Workspace:Raycast(origin, offset, params)
				if hit and isThin(hit.Instance, cfg.ThinMax) then
					local along = (hit.Position - origin):Dot(dir)
					if nearest == nil or along < nearest then
						nearest = along
						hitSign = sign
					end
				end
			end
		end
	end
	if nearest == nil then
		return aim
	end
	local beyond = if positive(cfg.Beyond) then cfg.Beyond else 0
	local base = from + dir * math.min(nearest + beyond, length)
	-- Couloir libre de `a` à `b` : centre et chaque couloir de flanc, à hauteur du centre et des genoux.
	local function corridor(a: Vector3, b: Vector3): boolean
		local unit = (b - a).Unit
		local normal = Vector3.new(-unit.Z, 0, unit.X)
		for _, low in { Vector3.zero, drop } do
			if not clear(a - low, b - low, params) then
				return false
			end
			for _, lane in lanes do
				local shift = normal * lane
				if not clear(a + shift - low, b + shift - low, params) or not clear(a - shift - low, b - shift - low, params) then
					return false
				end
			end
		end
		return true
	end
	local steps = math.floor(cfg.ShiftMax / cfg.ShiftStep + 1e-6)
	for step = 1, steps do
		local k = step * cfg.ShiftStep
		for _, sign in { -hitSign, hitSign } do
			local point = base + across * (k * sign)
			if (point - from).Magnitude > 1e-3 and not inSafe(point) and corridor(from, point)
				and clear(point, to, params) and clear(point - drop, to - drop, params)
			then
				return Vector3.new(point.X, aim.Y, point.Z)
			end
		end
	end
	return aim
end

return Sidestep
