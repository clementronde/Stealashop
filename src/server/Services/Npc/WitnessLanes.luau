--!strict
-- Npc/WitnessLanes (serveur, a269c ; Play f81b, 22/11 : l'écart dynamique des témoins ratait près des poteaux et entre
-- deux témoins bouchés) : module d'aide de WitnessService (sous-dossier : le Loader ne le démarre pas). Valeurs :
-- Config/Witness.Avoid (Enabled, Lanes et suivants). Absent ou coupé : la balade d'avant a269, sur le circuit même.
--
-- 1. Voies fixes. Les deux témoins d'une zone font le même circuit WitnessPaths, l'un dans l'ordre des points (sens +1),
--    l'autre à l'envers (−1). Chacun marche sur SA voie : le circuit décalé sur sa droite, dans son sens de marche, de
--    Avoid.Lane studs. Les deux voies sont donc de part et d'autre du circuit, à 2 × Lane studs l'une de l'autre, en
--    marche comme en pause (la pause se fait sur la voie). Elles se calculent une seule fois, segment par segment : un
--    décalage par segment et par sens, les points de la voie au croisement des deux segments décalés voisins (segments
--    presque alignés : le décalage corrigé, le plus loin du normal ; demi-tour : le milieu des deux).
-- 2. Obstacles. Chaque segment décalé est balayé (Spherecast de Avoid.LaneClearance studs de rayon, à hauteur du corps
--    et Avoid.LaneLowDrop studs plus bas ; pièces qui heurtent seulement, PNJ et joueurs ignorés). Bouché : un autre
--    couple de décalages (sens +1 à droite, sens −1 de l'autre côté), le plus proche de (Lane, Lane) qui garde les deux
--    voies à 2 × Lane studs l'une de l'autre : décalage réduit (jusqu'à 0, puis de l'autre côté) avec l'autre voie qui
--    s'éloigne d'autant, ou décalage agrandi juste assez pour contourner (pas de Avoid.LaneStep, au plus Avoid.LaneMax
--    studs). Les segments finis (entre les points de la voie) sont rebalayés ; un segment encore bouché essaie le couple
--    suivant (3 tours au plus). Aucun couple libre : (Lane, Lane), signalé.
-- 3. Filet (Sidestep) : un point libre à côté du témoin (droite, puis gauche, Avoid.UnstickSide studs), balayé.
--
-- API :
--   WitnessLanes.Build(path, height, ignore) -> (forward: {Vector3}, backward: {Vector3}, fixes: {string})
--       voies des sens +1 et −1 (mêmes numéros que path) ; fixes : segments corrigés (« 13→14 StreetLamp_N4.Pole : 0.25 / 2.75 » : décalages des sens +1 et −1, chacun sur sa droite)
--   WitnessLanes.Sidestep(position, heading, ignore) -> Vector3?   point libre à côté, ou nil
--   WitnessLanes.Free(from, to, radius, ignore) -> (boolean, Instance?)   balayage (sans Spherecast : libre)
-- height : hauteur de la racine du témoin au-dessus des points du circuit ; ignore : modèles et dossiers ignorés.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Witness = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Witness")) :: any

local WitnessLanes = {}

local function number(value: any, default: number): number
	return if type(value) == "number" and value == value then value else default
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

-- Une sphère de `radius` studs balayée de `from` à `to` touche-t-elle une pièce qui heurte (poteau, borne, mur) ?
-- Témoins et vigiles (groupe Avoid.Group) et `ignore` ignorés ; sans Spherecast (faux Roblox des bancs) : libre.
function WitnessLanes.Free(from: Vector3, to: Vector3, radius: number, ignore: { Instance }): (boolean, Instance?)
	local direction = to - from
	if direction.Magnitude < 1e-3 then
		return true, nil
	end
	local ok, hit = pcall(function(): Instance?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.RespectCanCollide = true
		local cfg = Witness.Avoid
		if type(cfg) == "table" and cfg.NoCollide == true and type(cfg.Group) == "string" then
			params.CollisionGroup = cfg.Group -- les témoins et les vigiles ne heurtent pas ce groupe
		end
		local result = Workspace:Spherecast(from, radius, direction, params)
		if result and result.Instance.CanCollide then
			return result.Instance
		end
		return nil
	end)
	if ok and hit then
		return false, hit
	end
	return true, nil
end

-- Le corps passe-t-il de `a` à `b` (points du circuit, au sol) ? À hauteur du corps puis LaneLowDrop plus bas.
local function corridor(cfg: any, a: Vector3, b: Vector3, height: number, ignore: { Instance }): (boolean, Instance?)
	local radius = number(cfg.LaneClearance, 1.2)
	if radius <= 0 then
		return true, nil
	end
	for _, drop in { 0, number(cfg.LaneLowDrop, 0) } do
		local up = Vector3.new(0, height - drop, 0)
		local free, hit = WitnessLanes.Free(a + up, b + up, radius, ignore)
		if not free then
			return false, hit
		end
	end
	return true, nil
end

local function cross(ax: number, az: number, bx: number, bz: number): number
	return ax * bz - az * bx
end

type Seg = { a: Vector3, b: Vector3, dx: number, dz: number, nx: number, nz: number }

-- Point de la voie en P, entre le segment s1 décalé de o1 et le segment s2 décalé de o2 (sur leur droite, sens +1) ;
-- `usual` : le décalage normal de cette voie (Lane ou −Lane).
local function vertex(p: Vector3, s1: Seg, o1: number, s2: Seg, o2: number, usual: number): Vector3
	local ax, az = p.X + s1.nx * o1, p.Z + s1.nz * o1
	local bx, bz = p.X + s2.nx * o2, p.Z + s2.nz * o2
	local mid = Vector3.new((ax + bx) / 2, p.Y, (az + bz) / 2)
	local den = cross(s1.dx, s1.dz, s2.dx, s2.dz)
	if math.abs(den) < 0.2 then
		if s1.dx * s2.dx + s1.dz * s2.dz > 0 then
			-- Presque alignés : le décalage corrigé (le plus loin du normal) dès ce point, pour que tout le segment
			-- corrigé reste à son décalage (le milieu des deux le rapprochait de l'obstacle).
			if math.abs(o1 - usual) >= math.abs(o2 - usual) then
				return Vector3.new(ax, p.Y, az)
			end
			return Vector3.new(bx, p.Y, bz)
		end
		return mid -- demi-tour
	end
	local t = cross(bx - ax, bz - az, s2.dx, s2.dz) / den
	local x, z = ax + s1.dx * t, az + s1.dz * t
	local limit = 2 * math.max(math.abs(o1), math.abs(o2)) + 0.5
	if (x - p.X) ^ 2 + (z - p.Z) ^ 2 > limit * limit then
		return mid -- virage trop serré : pointe trop longue
	end
	return Vector3.new(x, p.Y, z)
end

local function label(index: number, count: number): string
	return `{index}→{index % count + 1}`
end

function WitnessLanes.Build(path: { Vector3 }, height: number, ignore: { Instance }): ({ Vector3 }, { Vector3 }, { string })
	local count = #path
	local cfg = WitnessLanes.Settings()
	if cfg == nil or count < 2 then
		return table.clone(path), table.clone(path), {}
	end
	local lane = cfg.Lane
	local step = math.max(number(cfg.LaneStep, 0.25), 0.05)
	local max = math.max(number(cfg.LaneMax, 4), lane)
	-- Segments du circuit fermé (le dernier point rejoint le premier).
	local segs: { Seg } = {}
	for k = 1, count do
		local a, b = path[k], path[k % count + 1]
		local dx, dz = b.X - a.X, b.Z - a.Z
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1e-3 then
			dx, dz, length = 1, 0, 1 -- deux points confondus : n'importe quel sens
		end
		dx, dz = dx / length, dz / length
		table.insert(segs, { a = a, b = b, dx = dx, dz = dz, nx = -dz, nz = dx }) -- sa droite (Y en haut) : (−uz, ux)
	end
	-- Couples (a, b) : sens +1 à +a sur la droite du segment, sens −1 à −b ; a + b ≥ 2 × Lane ; du plus proche de
	-- (Lane, Lane) au plus loin (puis le plus serré, puis a le plus petit : on réduit avant d'agrandir).
	local values: { number } = {}
	local n = math.floor(max / step + 1e-6)
	for i = -n, n do
		table.insert(values, i * step)
	end
	if not table.find(values, lane) then
		table.insert(values, lane)
	end
	type Pair = { a: number, b: number, score: number }
	local couples: { Pair } = {}
	for _, a in values do
		for _, b in values do
			if a + b >= 2 * lane - 1e-6 then
				table.insert(couples, { a = a, b = b, score = math.abs(a - lane) + math.abs(b - lane) })
			end
		end
	end
	table.sort(couples, function(p: Pair, q: Pair): boolean
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
	-- Place libre d'un segment décalé de `o` (sur sa droite, sens +1), mise en cache.
	local cache: { [number]: { [number]: { free: boolean, hit: Instance? } } } = {}
	local function room(k: number, o: number): (boolean, Instance?)
		local perSeg = cache[k]
		if perSeg == nil then
			perSeg = {}
			cache[k] = perSeg
		end
		local key = math.floor(o / step + 0.5)
		local found = perSeg[key]
		if found == nil then
			local s = segs[k]
			local shift = Vector3.new(s.nx * o, 0, s.nz * o)
			local free, hit = corridor(cfg, s.a + shift, s.b + shift, height, ignore)
			found = { free = free, hit = hit }
			perSeg[key] = found
		end
		return found.free, found.hit
	end
	local choice: { number } = {} -- indice dans couples, par segment
	local firstHit: { [number]: Instance? } = {}
	local function advance(k: number, from: number): number
		for i = from, #couples do
			local p = couples[i]
			local freeA, hitA = room(k, p.a)
			local freeB, hitB = room(k, -p.b)
			if i == 1 then
				firstHit[k] = hitA or hitB
			end
			if freeA and freeB then
				return i
			end
		end
		return 0 -- aucun couple libre
	end
	for k = 1, count do
		choice[k] = advance(k, 1)
	end
	local forward: { Vector3 } = {}
	local backward: { Vector3 } = {}
	local unresolved: { [number]: Instance? } = {}
	local function build()
		for k = 1, count do
			local prev = (k - 2) % count + 1 -- segment qui arrive en P_k
			local p1 = couples[if choice[prev] > 0 then choice[prev] else 1]
			local p2 = couples[if choice[k] > 0 then choice[k] else 1]
			forward[k] = vertex(path[k], segs[prev], p1.a, segs[k], p2.a, lane)
			backward[k] = vertex(path[k], segs[prev], -p1.b, segs[k], -p2.b, -lane)
		end
	end
	for _ = 1, 3 do
		build()
		local bad = false
		table.clear(unresolved)
		for k = 1, count do
			local nextK = k % count + 1
			local okF, hitF = corridor(cfg, forward[k], forward[nextK], height, ignore)
			local okB, hitB = corridor(cfg, backward[nextK], backward[k], height, ignore)
			if not (okF and okB) then
				bad = true
				unresolved[k] = hitF or hitB
				if choice[k] > 0 then
					choice[k] = advance(k, choice[k] + 1)
				end
			end
		end
		if not bad then
			break
		end
	end
	build()
	local fixes: { string } = {}
	local function round(v: number): string
		return (string.gsub(string.format("%.2f", v), "%.?0+$", ""))
	end
	for k = 1, count do
		local i = choice[k]
		local hit = firstHit[k] or unresolved[k]
		local parent = if hit then hit.Parent else nil
		local name = if hit then (if parent and parent ~= Workspace then `{parent.Name}.{hit.Name}` else hit.Name) else "?"
		if i == 0 then
			table.insert(fixes, `{label(k, count)} {name} : aucun décalage libre, Lane gardé`)
		elseif i > 1 then
			local p = couples[i]
			table.insert(fixes, `{label(k, count)} {name} : {round(p.a)} / {round(p.b)}`)
		end
		if unresolved[k] and i ~= 0 then
			table.insert(fixes, `{label(k, count)} {name} : segment fini encore bouché`)
		end
	end
	return forward, backward, fixes
end

-- a269c (filet) : un point libre à côté de lui, Avoid.UnstickSide studs sur sa droite puis sur sa gauche (par rapport
-- à `heading`), balayé à hauteur de sa racine (corps de 1 stud de rayon) ; nil si les deux côtés sont bouchés.
function WitnessLanes.Sidestep(position: Vector3, heading: Vector3, ignore: { Instance }): Vector3?
	local cfg = WitnessLanes.Settings()
	if cfg == nil then
		return nil
	end
	local h = Vector3.new(heading.X, 0, heading.Z)
	if h.Magnitude < 1e-3 then
		h = Vector3.new(0, 0, -1)
	end
	h = h.Unit
	local right = Vector3.new(-h.Z, 0, h.X)
	local side = number(cfg.UnstickSide, 2.5)
	for _, sign in { 1, -1 } do
		local target = position + right * (side * sign)
		local free = WitnessLanes.Free(position, target, 1, ignore)
		if free then
			local lowered = Vector3.new(0, -number(cfg.LaneLowDrop, 0), 0)
			if WitnessLanes.Free(position + lowered, target + lowered, 1, ignore) then
				return target
			end
		end
	end
	return nil
end

return WitnessLanes
