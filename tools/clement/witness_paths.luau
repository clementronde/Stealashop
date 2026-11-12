--!nocheck
-- Circuits des témoins (L-111), pour Clément. Mode Edit, relançable (à relancer si une rue change).
-- Un tour par zone : trottoir nord d'ouest en est, traversée, trottoir sud d'est en ouest, traversée.
-- Attachments WitnessPath_01, _02… dans Map/Zone_<n>/WitnessPaths/WitnessPathBase (pièce invisible, ancrée,
-- sans collision), au sol, dans l'ordre du tour (le dernier rejoint le premier).
-- Méthode : empreinte du corps sans orientation (octogone de 2,6 studs, 4,4 de haut) ; grille de 6 studs côté
-- chaussée à 6,4 studs côté magasins depuis la bordure (pas de 0,4 stud, une colonne par stud) ; chemin par
-- programmation dynamique, le trottoir d'abord, la chaussée seulement pour contourner (arbre, façade avancée,
-- bouche de métro) ; passages entre cases vérifiés ; lignes droites libres ; un point tous les 14 studs au plus.
-- Traversées : première ligne libre en partant de chaque bout de la zone, hors aire du camion (TruckSpawn).

local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local excl = {}
for zi = 1, 6 do
	local z = workspace.Map:FindFirstChild("Zone_" .. zi)
	for _, n in { "Witnesses", "WitnessPaths" } do
		local w = z and z:FindFirstChild(n)
		if w then
			table.insert(excl, w)
		end
	end
end
params.FilterDescendantsInstances = excl

local W, TALL, Y0 = 2.6, 4.4, 0.65
local R45 = CFrame.Angles(0, math.rad(45), 0)
local cache = {}
local function hits(cf)
	for _, p in workspace:GetPartBoundsInBox(cf, Vector3.new(W, TALL, W), params) do
		if p.Transparency < 0.9 and (p.Position.Y + p.Size.Y / 2) > 0.7 and p.Size.Magnitude < 200 then
			return p
		end
	end
	return nil
end
local function freeAt(pos)
	local key = string.format("%.2f,%.2f", pos.X, pos.Z)
	local v = cache[key]
	if v == nil then
		local cf = CFrame.new(pos.X, Y0 + TALL / 2, pos.Z)
		v = hits(cf) == nil and hits(cf * R45) == nil
		cache[key] = v
	end
	return v
end
local function segFree(a, b)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local L = d.Magnitude
	if L < 1e-3 then
		return freeAt(a)
	end
	local u = d / L
	for s = 0, L, 0.35 do
		if not freeAt(a + u * s) then
			return false
		end
	end
	return freeAt(b)
end

local D0, DSTEP, NL = -6.0, 0.4, 32
local function laneD(i)
	return D0 + DSTEP * (i - 1)
end
local ONWALK = 19 -- première voie sur le trottoir (1,2 stud de la bordure)

local function simplify(pts)
	local clean = { pts[1] }
	for k = 2, #pts do
		if (pts[k] - clean[#clean]).Magnitude > 0.3 then
			table.insert(clean, pts[k])
		end
	end
	local simp, i = { clean[1] }, 1
	while i < #clean do
		local j = #clean
		while j > i + 1 and not segFree(clean[i], clean[j]) do
			j -= 1
		end
		table.insert(simp, clean[j])
		i = j
	end
	return simp
end

local report = {}
for zi = 1, 6 do
	local zone = workspace.Map:FindFirstChild("Zone_" .. zi)
	if zone == nil then
		continue
	end
	local kerb, xr = 0, { math.huge, -math.huge }
	for _, d in zone:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name:match("Kerb_[NS]") and not d.Name:match("^Boulevard") and d.Size.Y < 2 then
				kerb = math.max(kerb, math.abs(d.Position.Z) + d.Size.Z / 2)
			elseif d.Name:match("^Pavement_[NS]") then
				xr[1] = math.min(xr[1], d.Position.X - d.Size.X / 2)
				xr[2] = math.max(xr[2], d.Position.X + d.Size.X / 2)
			end
		end
	end
	local ts = zone:FindFirstChild("TruckSpawn")
	local function crossingAt(x)
		for i = ONWALK, NL do
			if segFree(Vector3.new(x, 0, kerb + laneD(i)), Vector3.new(x, 0, -(kerb + laneD(i)))) then
				return i
			end
		end
		return nil
	end
	local cross = {}
	for e, spec in { { xr[1] + 5, 1 }, { xr[2] - 5, -1 } } do
		for k = 0, 40 do
			local x = spec[1] + spec[2] * k
			if not (ts and math.abs(x - ts.Position.X) < ts.Size.X / 2 + 4) then
				local i = crossingAt(x)
				if i then
					cross[e] = { x = x, i = i }
					break
				end
			end
		end
	end
	if not (cross[1] and cross[2]) then
		table.insert(report, `Z{zi} : pas de traversée libre`)
		continue
	end
	local xa, xb = cross[1].x, cross[2].x
	local roadCols = 0
	-- Sur la colonne d'une traversée, toute voie entre la chaussée et la voie de la traversée est sur la ligne libre.
	local function densePath(side)
		local cols = {}
		for x = xa, xb, 1 do
			table.insert(cols, x)
		end
		local function P(c, i)
			return Vector3.new(cols[c], 0, side * (kerb + laneD(i)))
		end
		local INF = math.huge
		local function pref(i)
			local d = laneD(i)
			return 0.02 * (d - 2.6) ^ 2 + (if d < 0.8 then 0.6 else 0) + (if d < -2.4 then 0.6 else 0)
		end
		local cost, back = { {} }, { {} }
		for i = 1, NL do
			cost[1][i] = if i <= cross[1].i then math.abs(i - cross[1].i) * 0.3 else INF
		end
		for c = 2, #cols do
			cost[c], back[c] = {}, {}
			for i = 1, NL do
				local bestV, bestJ = INF, nil
				if freeAt(P(c, i)) then
					for j = math.max(1, i - 3), math.min(NL, i + 3) do
						if cost[c - 1][j] < INF then
							local v = cost[c - 1][j] + math.abs(i - j) * 0.3
							if v < bestV and segFree(P(c - 1, j), P(c, i)) then
								bestV, bestJ = v, j
							end
						end
					end
					if bestJ then
						bestV += pref(i)
					end
				end
				cost[c][i], back[c][i] = bestV, bestJ
			end
		end
		local endI, best = nil, INF
		for i = 1, cross[2].i do
			local v = cost[#cols][i] + math.abs(i - cross[2].i) * 0.3
			if v < best then
				best, endI = v, i
			end
		end
		if endI == nil then
			return nil
		end
		local idx = { [#cols] = endI }
		for c = #cols, 2, -1 do
			idx[c - 1] = back[c][idx[c]]
		end
		local pts = {}
		for c = 1, #cols do
			table.insert(pts, P(c, idx[c]))
			if laneD(idx[c]) < 0.8 then
				roadCols += 1
			end
		end
		return pts
	end
	local north, south = densePath(1), densePath(-1)
	if not (north and south) then
		table.insert(report, `Z{zi} : trottoir bouché ({if north then "nord ok" else "nord bouché"}, {if south then "sud ok" else "sud bouché"})`)
		continue
	end
	local ns, ss = simplify(north), simplify(south)
	local loop = {}
	for _, p in ns do
		table.insert(loop, p)
	end
	for k = #ss, 1, -1 do
		table.insert(loop, ss[k])
	end
	-- un point tous les 14 studs au plus, en gardant des lignes libres
	local fine = {}
	for k = 1, #loop do
		local a, b = loop[k], loop[k % #loop + 1]
		table.insert(fine, a)
		local n = math.ceil((b - a).Magnitude / 14)
		while n > 1 do
			local ok = true
			for s = 0, n - 1 do
				if not segFree(a:Lerp(b, s / n), a:Lerp(b, (s + 1) / n)) then
					ok = false
					break
				end
			end
			if ok then
				break
			end
			n -= 1
		end
		for s = 1, n - 1 do
			table.insert(fine, a:Lerp(b, s / n))
		end
	end
	local bad = {}
	for k = 1, #fine do
		if not segFree(fine[k], fine[k % #fine + 1]) then
			table.insert(bad, string.format("%02d(%.0f,%.1f)", k, fine[k].X, fine[k].Z))
		end
	end
	local old = zone:FindFirstChild("WitnessPaths")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "WitnessPaths"
	local base = Instance.new("Part")
	base.Name = "WitnessPathBase"
	base.Anchored, base.CanCollide, base.CanQuery, base.CanTouch, base.CastShadow = true, false, false, false, false
	base.Transparency = 1
	base.Size = Vector3.new(1, 1, 1)
	base.CFrame = CFrame.new((xa + xb) / 2, -2, 0)
	base.Parent = folder
	folder.Parent = zone
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { zone:FindFirstChild("Witnesses"), folder }
	for k, p in fine do
		local hit = workspace:Raycast(Vector3.new(p.X, 10, p.Z), Vector3.new(0, -20, 0), rp)
		local a = Instance.new("Attachment")
		a.Name = string.format("WitnessPath_%02d", k)
		a.Parent = base -- d'abord le parent, puis la position monde
		a.WorldPosition = Vector3.new(p.X, if hit then hit.Position.Y else 0, p.Z)
	end
	local len = 0
	for k = 1, #fine do
		len += (fine[k % #fine + 1] - fine[k]).Magnitude
	end
	table.insert(report, string.format("Z%d : %d points, tour de %.0f studs, traversées x=%.0f et %.0f, %d studs sur la chaussée, lignes bouchées %d %s",
		zi, #fine, len, xa, xb, roadCols, #bad, table.concat(bad, " ")))
	task.wait()
end
return table.concat(report, "\n")
