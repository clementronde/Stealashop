--!strict
-- Npc/WitnessLanes (serveur, a269c, refait a269d ; Plays f81b et f81c, 22/11) : module d'aide de WitnessService
-- (sous-dossier : le Loader ne le démarre pas). Valeurs : Config/Witness.Avoid (Enabled, Lanes et suivants). Absent ou
-- coupé : la balade d'avant a269, sur le circuit même.
--
-- 1. Voies fixes. Les deux témoins d'une zone font le même circuit WitnessPaths, l'un dans l'ordre des points (sens +1),
--    l'autre à l'envers (−1). Chacun marche sur SA voie : le circuit décalé sur sa droite, dans son sens de marche, de
--    Avoid.Lane studs, calculée une seule fois. Un point de voie par point du circuit (mêmes numéros), décalé le long
--    de la bissectrice des deux segments voisins (en onglet, au plus 2 fois le décalage) : chaque segment de voie est
--    donc exactement ce qui est balayé.
-- 2. Obstacles (a269d). Chaque point de voie est testé (GetPartBoundsInRadius) et chaque segment de voie balayé
--    (Spherecast), de Avoid.LaneClearance studs de rayon, à hauteur du corps et Avoid.LaneLowDrop studs plus bas. Les
--    requêtes ignorent CanCollide (les poteaux minces du décor n'ont souvent pas de collision) mais ne voient que la
--    map : tout ce qui est hors de Workspace/Map (joueurs, vigiles, foule) est exclu, ainsi que les dossiers des
--    témoins et des circuits ; une pièce sans collision ne compte que si on la voit (Transparency au plus
--    Avoid.LaneVisibleMax : les volumes et déclencheurs invisibles sont sautés). Bouché : un autre couple de décalages
--    (a sens +1 sur sa droite, b sens −1 sur la sienne), aux deux bouts du segment, puis à un seul bout ; d'abord ceux
--    qui gardent les deux voies à 2 × Lane studs l'une de l'autre, du plus proche de (Lane, Lane) au plus loin (pas de
--    Avoid.LaneStep, au plus Avoid.LaneMax studs), puis ceux qui les rapprochent (le plus large d'abord : une seule
--    ligne libre pour les deux). Un point de voie doit aussi se voir depuis son point du circuit : un point collé à
--    un mur passe devant le mur, jamais derrière ni dans un renfoncement.
-- 3. Lissage (a269d) : un segment de voie qui revient en arrière (bosse serrée du circuit, voie intérieure) : son
--    point est remplacé par le milieu de ses deux voisins, si c'est libre.
-- 4. Passages étroits (a269d) : un segment où les deux voies sont à moins de 2 × Lane − LaneStep studs l'une de
--    l'autre (à un pas de décalage près), ou encore bouché. Les segments étroits qui se suivent forment un passage ;
--    WitnessService n'y laisse qu'un témoin à la fois.
-- 5. Filet (Sidestep) : un point libre à côté du témoin (droite, puis gauche, Avoid.UnstickSide studs) d'où il voit le
--    point qu'il vise (pas un renfoncement), sinon son point de voie d'avant.
--
-- API :
--   WitnessLanes.Build(path, height, ignore) -> (forward, backward, fixes, narrow)
--       voies des sens +1 et −1 (mêmes numéros que path) ; fixes : corrections lisibles ; narrow : [segment k (du
--       point k au suivant)] = numéro de passage étroit
--   WitnessLanes.Sidestep(position, heading, goal, back, ignore) -> Vector3?   point libre à côté, ou nil
--   WitnessLanes.Free(from, to, radius, ignore) -> (boolean, Instance?)   balayage (sans Spherecast : libre)
-- height : hauteur de la racine du témoin au-dessus des points du circuit ; ignore : modèles et dossiers ignorés.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Witness = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Witness")) :: any

local WitnessLanes = {}

local MAP_NAME = "Map"

local function number(value: any, default: number): number
	return if type(value) == "number" and value == value then value else default
end

local function avoid(): any
	local cfg = Witness.Avoid
	return if type(cfg) == "table" then cfg else {}
end

-- Les réglages des voies, ou nil si elles sont coupées.
function WitnessLanes.Settings(): any
	local cfg = Witness.Avoid
	if type(cfg) ~= "table" or cfg.Enabled ~= true or cfg.Lanes ~= true then
		return nil
	end
	if not (type(cfg.Lane) == "number" and cfg.Lane >= 0) then
		return nil
	end
	return cfg
end

-- Une pièce touchée compte-t-elle ? Une pièce qui heurte, ou une pièce visible même sans collision.
local function counts(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	local p = part :: any
	if p.CanCollide == true then
		return true
	end
	local transparency = p.Transparency
	return type(transparency) == "number" and transparency <= number(avoid().LaneVisibleMax, 0.5)
end

type Probe = { ray: RaycastParams?, over: OverlapParams?, exclude: { Instance } }

-- Les filtres des requêtes : hors de Workspace/Map (s'il existe), `ignore`, et les pièces sautées en chemin.
local function newProbe(ignore: { Instance }): Probe
	local exclude = table.clone(ignore)
	local map = Workspace:FindFirstChild(MAP_NAME)
	if map then
		for _, child in Workspace:GetChildren() do
			if child ~= map then
				table.insert(exclude, child)
			end
		end
	end
	local probe: Probe = { ray = nil, over = nil, exclude = exclude }
	local cfg = avoid()
	local group = if cfg.NoCollide == true and type(cfg.Group) == "string" then cfg.Group else nil
	pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		params.RespectCanCollide = false -- a269d : les poteaux sans collision comptent aussi
		if group then
			params.CollisionGroup = group -- les témoins et les vigiles ne heurtent pas ce groupe
		end
		probe.ray = params
	end)
	pcall(function()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		params.RespectCanCollide = false
		if group then
			params.CollisionGroup = group
		end
		probe.over = params
	end)
	return probe
end

-- Une sphère de `radius` studs balayée de `from` à `to` touche-t-elle un obstacle ? Une pièce qui ne compte pas
-- (volume invisible sans collision) est sautée et la requête reprise (Spherecast ne rend que la première).
local function sweep(probe: Probe, from: Vector3, to: Vector3, radius: number): (boolean, Instance?)
	local direction = to - from
	local params = probe.ray
	if params == nil or direction.Magnitude < 1e-3 then
		return true, nil
	end
	for _ = 1, 8 do
		local ok, result = pcall(function(): RaycastResult?
			return Workspace:Spherecast(from, radius, direction, params)
		end)
		if not ok or result == nil then
			return true, nil
		end
		local hit = (result :: RaycastResult).Instance
		if counts(hit) then
			return false, hit
		end
		table.insert(probe.exclude, hit)
		params.FilterDescendantsInstances = probe.exclude
		local over = probe.over
		if over then
			over.FilterDescendantsInstances = probe.exclude
		end
	end
	return true, nil
end

-- Un corps de `radius` studs tient-il en `point` (boîtes des pièces : Spherecast ne voit pas ce qu'il touche déjà) ?
local function overlap(probe: Probe, point: Vector3, radius: number): (boolean, Instance?)
	local params = probe.over
	if params == nil then
		return true, nil
	end
	local ok, parts = pcall(function(): { BasePart }
		return Workspace:GetPartBoundsInRadius(point, radius, params)
	end)
	if not ok or type(parts) ~= "table" then
		return true, nil
	end
	for _, part in parts do
		if counts(part) then
			return false, part
		end
	end
	return true, nil
end

function WitnessLanes.Free(from: Vector3, to: Vector3, radius: number, ignore: { Instance }): (boolean, Instance?)
	return sweep(newProbe(ignore), from, to, radius)
end


local function lerp(a: Vector3, b: Vector3, t: number): Vector3
	return a + (b - a) * t
end

-- Plus courte distance (à plat) du point (px, pz) au segment a→b.
local function segDistance(px: number, pz: number, a: Vector3, b: Vector3): number
	local abx, abz = b.X - a.X, b.Z - a.Z
	local l2 = abx * abx + abz * abz
	local t = if l2 > 1e-9 then math.clamp(((px - a.X) * abx + (pz - a.Z) * abz) / l2, 0, 1) else 0
	local dx, dz = px - a.X - abx * t, pz - a.Z - abz * t
	return math.sqrt(dx * dx + dz * dz)
end

-- Écart (à plat) entre deux segments : le plus petit, sur 9 points de chacun.
local function gap(a1: Vector3, a2: Vector3, b1: Vector3, b2: Vector3): number
	local best = math.huge
	for i = 0, 8 do
		local t = i / 8
		local pa = lerp(a1, a2, t)
		local pb = lerp(b1, b2, t)
		best = math.min(best, segDistance(pa.X, pa.Z, b1, b2), segDistance(pb.X, pb.Z, a1, a2))
	end
	return best
end

local function round(v: number): string
	return (string.gsub(string.format("%.2f", v), "%.?0+$", ""))
end

local function nameOf(hit: Instance?): string
	if hit == nil then
		return "?"
	end
	local parent = hit.Parent
	return if parent and parent ~= Workspace then `{parent.Name}.{hit.Name}` else hit.Name
end

type Pair = { a: number, b: number, score: number, wide: boolean }

function WitnessLanes.Build(
	path: { Vector3 },
	height: number,
	ignore: { Instance }
): ({ Vector3 }, { Vector3 }, { string }, { [number]: number })
	local count = #path
	local cfg = WitnessLanes.Settings()
	if cfg == nil or count < 2 then
		return table.clone(path), table.clone(path), {}, {}
	end
	local lane = cfg.Lane
	local step = math.max(number(cfg.LaneStep, 0.25), 0.05)
	local max = math.max(number(cfg.LaneMax, 4), lane)
	local radius = number(cfg.LaneClearance, 1.2)
	local drops = { 0, number(cfg.LaneLowDrop, 0) }
	local probe = newProbe(ignore)
	local function nextOf(k: number): number
		return k % count + 1
	end
	local function prevOf(k: number): number
		return (k - 2) % count + 1
	end
	-- Normales (sur la droite, sens +1) des segments du circuit fermé, puis des points (bissectrice, onglet).
	local snx: { number }, snz: { number } = {}, {}
	for k = 1, count do
		local a, b = path[k], path[nextOf(k)]
		local dx, dz = b.X - a.X, b.Z - a.Z
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1e-3 then
			dx, dz, length = 1, 0, 1 -- deux points confondus : n'importe quel sens
		end
		snx[k], snz[k] = -dz / length, dx / length -- sa droite (Y en haut) : (−uz, ux)
	end
	local vnx: { number }, vnz: { number } = {}, {}
	for k = 1, count do
		local p = prevOf(k)
		local x, z = snx[p] + snx[k], snz[p] + snz[k]
		local length = math.sqrt(x * x + z * z)
		if length < 0.3 then
			vnx[k], vnz[k] = snx[k], snz[k] -- demi-tour : la normale du segment qui part
		else
			x, z = x / length, z / length
			local miter = math.min(1 / math.max(x * snx[k] + z * snz[k], 1e-3), 2)
			vnx[k], vnz[k] = x * miter, z * miter
		end
	end
	local function spotOf(k: number, o: number): Vector3
		local p = path[k]
		return Vector3.new(p.X + vnx[k] * o, p.Y, p.Z + vnz[k] * o)
	end
	local function clearPoint(p: Vector3): (boolean, Instance?)
		if radius <= 0 then
			return true, nil
		end
		for _, drop in drops do
			local free, hit = overlap(probe, p + Vector3.new(0, height - drop, 0), radius)
			if not free then
				return false, hit
			end
		end
		return true, nil
	end
	local function clearLine(a: Vector3, b: Vector3): (boolean, Instance?)
		if radius <= 0 then
			return true, nil
		end
		for _, drop in drops do
			local up = Vector3.new(0, height - drop, 0)
			local free, hit = sweep(probe, a + up, b + up, radius)
			if not free then
				return false, hit
			end
		end
		return true, nil
	end
	-- Décalages essayés, et couples (a, b) : larges (a + b ≥ 2 × Lane) d'abord, du plus proche de (Lane, Lane) au
	-- plus loin (puis le plus serré, puis a le plus petit : on réduit avant d'agrandir) ; puis les serrés (a + b ≥ 0),
	-- le plus large d'abord.
	local n = math.floor(max / step + 1e-6)
	local values: { number } = {}
	for i = -n, n do
		table.insert(values, i * step)
	end
	local couples: { Pair } = {}
	for _, a in values do
		for _, b in values do
			if a + b >= -1e-6 then
				local wide = a + b >= 2 * lane - 1e-6
				table.insert(couples, { a = a, b = b, score = math.abs(a - lane) + math.abs(b - lane), wide = wide })
			end
		end
	end
	table.sort(couples, function(p: Pair, q: Pair): boolean
		if p.wide ~= q.wide then
			return p.wide
		end
		if not p.wide and math.abs((p.a + p.b) - (q.a + q.b)) > 1e-6 then
			return p.a + p.b > q.a + q.b
		end
		if math.abs(p.score - q.score) > 1e-6 then
			return p.score < q.score
		end
		if math.abs((p.a + p.b) - (q.a + q.b)) > 1e-6 then
			return p.a + p.b < q.a + q.b
		end
		if math.abs(p.a - q.a) > 1e-6 then
			return p.a < q.a
		end
		return p.b < q.b
	end)
	local base = 1 -- (Lane, Lane)
	for i, p in couples do
		if math.abs(p.a - lane) < 1e-6 and math.abs(p.b - lane) < 1e-6 then
			base = i
			break
		end
	end
	local function key(o: number): number
		return math.floor(o / step + 0.5) + n
	end
	local span = 2 * n + 1
	-- Caches : un point (k, décalage), un segment (k, décalage au départ, décalage à l'arrivée).
	local pointCache: { [number]: { free: boolean, hit: Instance? } } = {}
	local function pointFree(k: number, o: number): (boolean, Instance?)
		local id = (k - 1) * span + key(o)
		local found = pointCache[id]
		if found == nil then
			local free, hit = clearPoint(spotOf(k, o))
			if free and math.abs(o) > 1e-6 then
				-- a269d : il se voit depuis son point du circuit (jamais derrière un mur ou dans un renfoncement)
				local up = Vector3.new(0, height, 0)
				local seen, wall = sweep(probe, path[k] + up, spotOf(k, o) + up, 0.25)
				if not seen then
					free, hit = false, wall
				end
			end
			found = { free = free, hit = hit }
			pointCache[id] = found
		end
		return found.free, found.hit
	end
	local segCache: { [number]: { free: boolean, hit: Instance? } } = {}
	local function segFree(k: number, o1: number, o2: number): (boolean, Instance?)
		local id = ((k - 1) * span + key(o1)) * span + key(o2)
		local found = segCache[id]
		if found == nil then
			local free, hit = clearLine(spotOf(k, o1), spotOf(nextOf(k), o2))
			found = { free = free, hit = hit }
			segCache[id] = found
		end
		return found.free, found.hit
	end
	local function vertexFree(k: number, c: number): boolean
		local p = couples[c]
		return (pointFree(k, p.a)) and (pointFree(k, -p.b))
	end
	local function segmentFree(k: number, c1: number, c2: number): boolean
		local p1, p2 = couples[c1], couples[c2]
		return (segFree(k, p1.a, p2.a)) and (segFree(k, -p1.b, -p2.b))
	end
	-- L'obstacle qui a fait corriger un point ou un segment (pour la sortie).
	local pointHit: { [number]: Instance? } = {}
	local segHit: { [number]: Instance? } = {}
	for k = 1, count do
		local _, h1 = pointFree(k, lane)
		local _, h2 = pointFree(k, -lane)
		pointHit[k] = h1 or h2
	end
	for k = 1, count do
		local _, h1 = segFree(k, lane, lane)
		local _, h2 = segFree(k, -lane, -lane)
		segHit[k] = h1 or h2
	end
	-- Chaque point : le premier couple libre (sinon (Lane, Lane)).
	local choice: { number } = {}
	for k = 1, count do
		choice[k] = base
		if not vertexFree(k, base) then
			for c = 1, #couples do
				if vertexFree(k, c) then
					choice[k] = c
					break
				end
			end
		end
	end
	-- Réparation des segments bouchés, sans boucher un segment voisin qui était libre.
	local function repair(k: number): boolean
		local k2 = nextOf(k)
		local k0 = prevOf(k)
		local k3 = nextOf(k2)
		local keepBefore = segmentFree(k0, choice[k0], choice[k])
		local keepAfter = segmentFree(k2, choice[k2], choice[k3])
		for c = 1, #couples do -- le même couple aux deux bouts
			if vertexFree(k, c) and vertexFree(k2, c) and segmentFree(k, c, c)
				and (not keepBefore or segmentFree(k0, choice[k0], c)) and (not keepAfter or segmentFree(k2, c, choice[k3]))
			then
				choice[k], choice[k2] = c, c
				return true
			end
		end
		for c = 1, #couples do -- un seul bout
			if vertexFree(k, c) and segmentFree(k, c, choice[k2]) and (not keepBefore or segmentFree(k0, choice[k0], c)) then
				choice[k] = c
				return true
			end
			if vertexFree(k2, c) and segmentFree(k, choice[k], c) and (not keepAfter or segmentFree(k2, c, choice[k3])) then
				choice[k2] = c
				return true
			end
		end
		return false
	end
	for _ = 1, 4 do
		local changed = false
		for k = 1, count do
			if not segmentFree(k, choice[k], choice[nextOf(k)]) and repair(k) then
				changed = true
			end
		end
		if not changed then
			break
		end
	end
	local forward: { Vector3 } = {}
	local backward: { Vector3 } = {}
	for k = 1, count do
		local p = couples[choice[k]]
		forward[k] = spotOf(k, p.a)
		backward[k] = spotOf(k, -p.b)
	end
	local blocked: { [number]: boolean } = {}
	for k = 1, count do
		if not segmentFree(k, choice[k], choice[nextOf(k)]) then
			blocked[k] = true
		end
	end
	-- Lissage : un segment de voie qui revient en arrière par rapport au circuit.
	local smoothed: { [number]: boolean } = {}
	local function backwards(points: { Vector3 }, k: number): boolean
		local a, b = points[k], points[nextOf(k)]
		local pa, pb = path[k], path[nextOf(k)]
		return (b.X - a.X) * (pb.X - pa.X) + (b.Z - a.Z) * (pb.Z - pa.Z) <= 0
	end
	for _ = 1, 3 do
		local changed = false
		for _, points in { forward, backward } do
			for k = 1, count do
				local k0 = prevOf(k)
				if count >= 3 and (backwards(points, k0) or backwards(points, k)) then
					local before, after = points[k0], points[nextOf(k)]
					local mid = lerp(before, after, 0.5)
					local swap = points[k]
					points[k] = mid
					if not backwards(points, k0) and not backwards(points, k) and (clearPoint(mid)) and (clearLine(before, mid))
						and (clearLine(mid, after))
					then
						smoothed[k] = true
						changed = true
					else
						points[k] = swap
					end
				end
			end
		end
		if not changed then
			break
		end
	end
	-- Passages étroits : segments où les deux voies sont à moins de 2 × Lane − LaneStep l'une de l'autre, ou encore
	-- bouchés.
	local tight: { [number]: number } = {}
	local narrowCount = 0
	for k = 1, count do
		local k2 = nextOf(k)
		local width = gap(forward[k], forward[k2], backward[k], backward[k2])
		if width < 2 * lane - step or blocked[k] then
			tight[k] = width
			narrowCount += 1
		end
	end
	local narrow: { [number]: number } = {}
	if narrowCount > 0 and narrowCount < count then
		local start = 1
		while tight[prevOf(start)] ~= nil or tight[start] == nil do
			start = nextOf(start) -- le début d'un passage
		end
		local id = 0
		local k = start
		for _ = 1, count do
			if tight[k] ~= nil then
				if narrow[prevOf(k)] == nil then
					id += 1
				end
				narrow[k] = id
			end
			k = nextOf(k)
		end
	end
	-- Ce qui a été corrigé, pour la sortie.
	local fixes: { string } = {}
	for k = 1, count do
		if choice[k] ~= base then
			local p = couples[choice[k]]
			local hit = pointHit[k] or segHit[prevOf(k)] or segHit[k]
			table.insert(fixes, `P{k} {nameOf(hit)} : {round(p.a)} / {round(p.b)}`)
		end
		if smoothed[k] then
			table.insert(fixes, `P{k} lissé`)
		end
	end
	for k = 1, count do
		local k2 = nextOf(k)
		if blocked[k] then
			local _, h1 = segFree(k, couples[choice[k]].a, couples[choice[k2]].a)
			local _, h2 = segFree(k, -couples[choice[k]].b, -couples[choice[k2]].b)
			table.insert(fixes, `{k}→{k2} {nameOf(h1 or h2)} : encore bouché`)
		end
		if narrow[k] then
			table.insert(fixes, `{k}→{k2} {nameOf(segHit[k])} : passage étroit {narrow[k]} ({round(tight[k])})`)
		end
	end
	return forward, backward, fixes, narrow
end

-- a269c (filet), a269d : un point libre à côté de lui, Avoid.UnstickSide studs sur sa droite puis sur sa gauche (par
-- rapport à `heading`), d'où il peut aller à `goal` (pas un renfoncement derrière une façade) ; sinon `back` (son
-- point de voie d'avant) s'il y va ; balayés à hauteur de sa racine (corps de 1 stud de rayon) ; nil sinon.
function WitnessLanes.Sidestep(
	position: Vector3,
	heading: Vector3,
	goal: Vector3,
	back: Vector3?,
	ignore: { Instance }
): Vector3?
	local cfg = WitnessLanes.Settings()
	if cfg == nil then
		return nil
	end
	local probe = newProbe(ignore)
	local drop = number(cfg.LaneLowDrop, 0)
	local function reach(a: Vector3, b: Vector3): boolean
		for _, d in { 0, drop } do
			local down = Vector3.new(0, -d, 0)
			if not (sweep(probe, a + down, b + down, 1)) then
				return false
			end
		end
		return true
	end
	local h = Vector3.new(heading.X, 0, heading.Z)
	if h.Magnitude < 1e-3 then
		h = Vector3.new(0, 0, -1)
	end
	h = h.Unit
	local right = Vector3.new(-h.Z, 0, h.X)
	local side = number(cfg.UnstickSide, 2.5)
	local aim = Vector3.new(goal.X, position.Y, goal.Z)
	for _, sign in { 1, -1 } do
		local target = position + right * (side * sign)
		if reach(position, target) and (overlap(probe, target, 1)) and reach(target, aim) then
			return target
		end
	end
	if back then
		local target = Vector3.new(back.X, position.Y, back.Z)
		if reach(position, target) then
			return target
		end
	end
	return nil
end

return WitnessLanes
