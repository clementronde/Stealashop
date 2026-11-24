---------------------------------------------------------------- ajouts a45
-- Collé après stubs.luau et stubs.a24.luau (copies de ceux du banc a24, via a36), dans le même bloc :
-- leurs locales (Methods, PROPS, PathfindingService…) sont visibles ici.
--   - classe Decal (visage du vigile : le fondu le rend transparent aussi) ;
--   - PathfindingService:CreatePath remplacé par un vrai petit chercheur de chemin : graphe de
--     visibilité sur des points posés par les tests (NAV_NODES), départ et but compris ; deux points
--     sont reliés si le segment ne touche aucun mur de WALLS (marge NAV_MARGIN, sauf à moins de
--     2 studs des bouts) ; plus court chemin (Dijkstra), découpé tous les 4 studs. Pas de route :
--     NoPath (un rideau baissé ou une vitre intacte ferment le passage). PATH_FAILS = true : NoPath
--     toujours. PATH_GOALS garde le but de chaque calcul.

PROPS.Decal = { Transparency = 0, Texture = "", Face = "Enum.NormalId.Front" }

NAV_NODES = {}
NAV_MARGIN = 1.5
PATH_GOALS = {}

local function nearEnd(px, pz, a, b)
	local da = (px - a.X) ^ 2 + (pz - a.Z) ^ 2
	local db = (px - b.X) ^ 2 + (pz - b.Z) ^ 2
	return da <= 4 or db <= 4
end

function navSegmentClear(a, b)
	local dx, dz = b.X - a.X, b.Z - a.Z
	local len = math.sqrt(dx * dx + dz * dz)
	local steps = math.max(1, math.ceil(len / 0.5))
	for i = 0, steps do
		local px, pz = a.X + dx * i / steps, a.Z + dz * i / steps
		local margin = if nearEnd(px, pz, a, b) then 0 else NAV_MARGIN
		for _, wall in WALLS do
			local c, s = wall.cframe.Position, wall.size
			if math.abs(px - c.X) <= s.X / 2 + margin and math.abs(pz - c.Z) <= s.Z / 2 + margin then
				return false
			end
		end
	end
	return true
end

local function navRoute(a, b)
	local nodes = { a }
	for _, n in NAV_NODES do
		table.insert(nodes, n)
	end
	table.insert(nodes, b)
	local count = #nodes
	local dist, prev, done = {}, {}, {}
	for i = 1, count do
		dist[i] = math.huge
	end
	dist[1] = 0
	while true do
		local best, bestD = nil, math.huge
		for i = 1, count do
			if not done[i] and dist[i] < bestD then
				best, bestD = i, dist[i]
			end
		end
		if best == nil or best == count then
			break
		end
		done[best] = true
		for j = 1, count do
			if not done[j] and j ~= best then
				local u, v = nodes[best], nodes[j]
				local d = math.sqrt((u.X - v.X) ^ 2 + (u.Z - v.Z) ^ 2)
				if bestD + d < dist[j] and navSegmentClear(u, v) then
					dist[j] = bestD + d
					prev[j] = best
				end
			end
		end
	end
	if dist[count] == math.huge then
		return nil
	end
	local route = {}
	local i = count
	while i do
		table.insert(route, 1, nodes[i])
		i = prev[i]
	end
	return route
end

PathfindingService.CreatePath = function(_, params)
	table.insert(PATH_PARAMS, params)
	local path = { Status = "Enum.PathStatus.NoPath", _wps = {}, params = params }
	function path.ComputeAsync(p, a, b)
		taskLib.wait(1 / 60)
		PATHS_COMPUTED += 1
		table.insert(PATH_GOALS, { t = now(), goal = b })
		local route = if PATH_FAILS then nil else navRoute(a, b)
		if route == nil then
			p.Status = "Enum.PathStatus.NoPath"
			p._wps = {}
			return
		end
		local wps = { { Position = Vector3.new(a.X, b.Y, a.Z), Action = "Enum.PathWaypointAction.Walk" } }
		for k = 2, #route do
			local u, v = route[k - 1], route[k]
			local d = Vector3.new(v.X - u.X, 0, v.Z - u.Z)
			local n = math.max(1, math.ceil(d.Magnitude / 4))
			for s = 1, n do
				local q = Vector3.new(u.X, b.Y, u.Z) + d * (s / n)
				table.insert(wps, { Position = q, Action = "Enum.PathWaypointAction.Walk" })
			end
		end
		p.Status = "Enum.PathStatus.Success"
		p._wps = wps
	end
	function path.GetWaypoints(p)
		return table.clone(p._wps)
	end
	return path
end
