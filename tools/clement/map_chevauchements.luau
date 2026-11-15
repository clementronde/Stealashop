--!nocheck
-- tools/clement/map_chevauchements.luau
-- Surfaces qui se chevauchent et clignotent (z-fighting) dans Workspace/Map.
-- Demande de Clément du 2026-11-15. Relançable : relancer après un script de zone ou du hub
-- (ils recréent leur décor) ; il ne trouve rien à faire sur une zone déjà corrigée.
--
-- Usage (execute_luau, mode Edit) : envoyer ce fichier une fois (il pose _G.MapZF), puis
--   _G.MapZF.detect({"Zone_1", "Zone_2"})                  -> rapport par zone, rien ne change
--   _G.MapZF.backup({"Zone_1"}, "2026-11-15_Chevauchements") -> copie dans ServerStorage/MapBackups/<nom>
--   _G.MapZF.fix({"Zone_1"})                               -> corrige, annulable (Ctrl+Z)
--   _G.MapZF.worst(5)                                      -> pires cas du dernier detect (pour les captures)
-- Les noms de la liste sont des enfants de Workspace/Map (Zone_1..6, Entry, Hub, Skyline).
--
-- Ce qui est cherché, seulement sur les Part en bloc visibles (Transparency < 0,99, sans mesh) :
--   * deux faces de même sens, dans le même plan à moins de 0,02 stud, qui se recouvrent
--     (aire commune > 0,01 stud²) ;
--   * les doublons exacts (même classe, même CFrame, même taille, même mesh), toutes classes.
-- Correction, sans changer l'aspect :
--   * doublon exact : on en retire un (jamais celui du contrat ni un PrimaryPart) ;
--   * faces coplanaires : la petite face passe devant. On pousse cette face à 0,025 stud devant
--     sa voisine (0,05 au plus quand trois faces s'empilent), en allongeant la pièce de ce côté
--     seulement. Au-delà de 0,05 la face est laissée et comptée à part.
--     Si la petite pièce porte le contrat, on recule de 0,025 la face de la grande à la place.
--     Une pièce du contrat (tag, enfant obligatoire, PrimaryPart) ne bouge jamais.

local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local PLANE_EPS = 0.02
local AREA_EPS = 0.01
local STEP = 0.025
local MAX_SHIFT = 0.05

local M = {}
M.last = nil

-- Noms du contrat : la pièce elle-même ne bouge pas.
local PROTECTED_NAMES = {}
for _, n in {
	"Window", "WindowFractured", "Shutter", "ShutterButton", "Door", "Bounds", "GuardSpawn", "SignPart",
	"Counter", "ShopPad", "Belt", "SpawnPoint", "UsePoint", "CashPad", "PlotDoor", "PlotBarrier",
	"StageUpgradePoint", "DisplayUpgradePoint", "NightWall", "NightWallSlot", "TruckSpawn",
	"FortuneVaultSpawn", "Spawn", "SafeZone", "NameSign", "StoreReqSign", "Leaderboard", "Board",
	"Lid", "Box", "Handle", "Root", "HumanoidRootPart", "DepositZone", "InviteZone", "RewardsZone",
	"OwnerName", "RarestDisplay", "Truck",
} do
	PROTECTED_NAMES[n] = true
end
local PROTECTED_PATTERNS = { "^Shard_%d+$", "^ShelfSlot_%d+$", "^CollectPad_%d+$", "Point$", "^Stage_%d+$" }
-- Dossiers ou modèles du contrat : tout ce qu'ils contiennent ne bouge pas.
local PROTECTED_CONTAINERS = {
	Window = true, WindowFractured = true, Shutter = true, Door = true, Bounds = true,
	Witnesses = true, WitnessPaths = true, TruckSpawn = true, NightWall = true, NightWallSlot = true,
	Belt = true, Leaderboard = true, PlotDoor = true, PlotBarrier = true, ShopPad = true,
	FortuneVaultSpawn = true, RarestDisplay = true,
}

local function nameProtected(n)
	if PROTECTED_NAMES[n] then
		return true
	end
	for _, p in PROTECTED_PATTERNS do
		if string.find(n, p) then
			return true
		end
	end
	return false
end

local function isProtected(part, mapRoot)
	if #CollectionService:GetTags(part) > 0 or nameProtected(part.Name) then
		return true
	end
	local a = part.Parent
	while a and a ~= mapRoot do
		if PROTECTED_CONTAINERS[a.Name] then
			return true
		end
		if a:IsA("Model") and a.PrimaryPart == part then
			return true
		end
		a = a.Parent
	end
	return false
end

-- Pièce d'un personnage (vigile, vendeur, témoin) : jamais analysée.
local function inRig(part, mapRoot)
	local a = part.Parent
	while a and a ~= mapRoot do
		if a:IsA("Model") and a:FindFirstChildOfClass("Humanoid") then
			return true
		end
		a = a.Parent
	end
	return false
end

local function topName(part, mapRoot)
	local a = part
	while a.Parent and a.Parent ~= mapRoot do
		a = a.Parent
	end
	return a.Name
end

local function fullName(inst)
	return (string.gsub(inst:GetFullName(), "^Workspace%.Map%.", ""))
end

local function analysable(p)
	return p:IsA("Part") and p.Shape == Enum.PartType.Block and p.Transparency < 0.99
		and not p:FindFirstChildWhichIsA("DataModelMesh")
end

local ids, nextId = setmetatable({}, { __mode = "k" }), 0
local function pid(p)
	local v = ids[p]
	if not v then
		nextId += 1
		v = string.format("%07d", nextId)
		ids[p] = v
	end
	return v
end

local function r(x, q)
	return math.floor(x / q + 0.5)
end

local function dupKey(p)
	local cf = p.CFrame
	local comps = { cf:GetComponents() }
	local t = { p.ClassName }
	for i, c in comps do
		t[#t + 1] = tostring(r(c, i <= 3 and 0.001 or 0.0001))
	end
	t[#t + 1] = string.format("%d,%d,%d", r(p.Size.X, 0.001), r(p.Size.Y, 0.001), r(p.Size.Z, 0.001))
	if p:IsA("MeshPart") then
		t[#t + 1] = p.MeshId
	elseif p:IsA("Part") then
		t[#t + 1] = p.Shape.Name
	end
	return table.concat(t, "|")
end

local function sameLook(a, b)
	return a.Color == b.Color and a.Material == b.Material and a.MaterialVariant == b.MaterialVariant
		and math.abs(a.Transparency - b.Transparency) < 1e-3
end

-- Géométrie 2D ----------------------------------------------------------------------------
local function polyArea(P)
	local s = 0
	for i = 1, #P do
		local a, b = P[i], P[i % #P + 1]
		s += a[1] * b[2] - b[1] * a[2]
	end
	return s / 2
end

local function clip(subject, clipPoly)
	local out = subject
	for i = 1, #clipPoly do
		if #out == 0 then
			break
		end
		local A, B = clipPoly[i], clipPoly[i % #clipPoly + 1]
		local inp = out
		out = {}
		local function side(P)
			return (B[1] - A[1]) * (P[2] - A[2]) - (B[2] - A[2]) * (P[1] - A[1])
		end
		for j = 1, #inp do
			local P, Q = inp[j], inp[j % #inp + 1]
			local sp, sq = side(P), side(Q)
			if sp >= 0 then
				out[#out + 1] = P
			end
			if (sp >= 0) ~= (sq >= 0) then
				local t = sp / (sp - sq)
				out[#out + 1] = { P[1] + (Q[1] - P[1]) * t, P[2] + (Q[2] - P[2]) * t }
			end
		end
	end
	return out
end

local function basis(n)
	local ref = math.abs(n.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
	local u = ref:Cross(n).Unit
	local v = n:Cross(u)
	return u, v
end

-- Collecte ----------------------------------------------------------------------------------
local AXES = { "X", "Y", "Z" }

local function collect(names)
	local mapRoot = workspace:FindFirstChild("Map")
	local parts = {}
	for _, nm in names do
		local f = mapRoot:FindFirstChild(nm)
		if f then
			for _, d in f:GetDescendants() do
				if d:IsA("BasePart") and not inRig(d, mapRoot) then
					parts[#parts + 1] = d
				end
			end
		end
	end
	return parts, mapRoot
end

-- Visibilité ------------------------------------------------------------------------------
-- Une paire ne compte que si un point juste devant la face commune (0,05 stud) est à l'air
-- libre : pas dans une autre pièce opaque, pas sous le sol (face tournée vers le bas sous y = 1).
local CELL = 16
function M.buildOccluders()
	local grid, big = {}, {}
	for _, d in workspace.Map:GetDescendants() do
		if d:IsA("Part") and d.Shape == Enum.PartType.Block and d.Transparency < 0.05
			and not d:FindFirstChildWhichIsA("DataModelMesh") then
			local cf, h = d.CFrame, d.Size / 2
			local rx, ry, rz = cf.RightVector, cf.UpVector, cf.LookVector
			local ex = math.abs(rx.X) * h.X + math.abs(ry.X) * h.Y + math.abs(rz.X) * h.Z
			local ey = math.abs(rx.Y) * h.X + math.abs(ry.Y) * h.Y + math.abs(rz.Y) * h.Z
			local ez = math.abs(rx.Z) * h.X + math.abs(ry.Z) * h.Y + math.abs(rz.Z) * h.Z
			local p = cf.Position
			local x0, x1 = math.floor((p.X - ex) / CELL), math.floor((p.X + ex) / CELL)
			local y0, y1 = math.floor((p.Y - ey) / CELL), math.floor((p.Y + ey) / CELL)
			local z0, z1 = math.floor((p.Z - ez) / CELL), math.floor((p.Z + ez) / CELL)
			local entry = { part = d, cf = cf, h = h }
			if (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1) > 64 then
				big[#big + 1] = entry
			else
				for x = x0, x1 do
					for y = y0, y1 do
						for z = z0, z1 do
							local k = x .. "," .. y .. "," .. z
							local L = grid[k]
							if not L then
								L = {}
								grid[k] = L
							end
							L[#L + 1] = entry
						end
					end
				end
			end
		end
	end
	M.occ = { grid = grid, big = big }
end

local function inside(e, q)
	local l = e.cf:PointToObjectSpace(q)
	local h = e.h
	return math.abs(l.X) < h.X - 0.005 and math.abs(l.Y) < h.Y - 0.005 and math.abs(l.Z) < h.Z - 0.005
end

local function occluded(q, ex1, ex2)
	local occ = M.occ
	local k = math.floor(q.X / CELL) .. "," .. math.floor(q.Y / CELL) .. "," .. math.floor(q.Z / CELL)
	for _, L in { occ.grid[k] or {}, occ.big } do
		for _, e in L do
			if e.part ~= ex1 and e.part ~= ex2 and inside(e, q) then
				return true
			end
		end
	end
	return false
end

function M.markVisible(prs)
	M.buildOccluders()
	for i, pr in prs do
		local n = pr.a.n
		local d = (pr.a.d + pr.b.d) / 2 + 0.05
		local P = pr.inter
		local cu, cv = 0, 0
		for _, q in P do
			cu += q[1]
			cv += q[2]
		end
		cu /= #P
		cv /= #P
		local samples = { { cu, cv } }
		for _, q in P do
			samples[#samples + 1] = { cu + (q[1] - cu) * 0.8, cv + (q[2] - cv) * 0.8 }
		end
		pr.visible = false
		for _, smp in samples do
			local q = pr.u * smp[1] + pr.v * smp[2] + n * d
			if not (n.Y < -0.7 and q.Y < 1) and not occluded(q, pr.a.part, pr.b.part) then
				pr.visible = true
				pr.sample = q
				break
			end
		end
		if i % 500 == 0 then
			task.wait()
		end
	end
end

function M.detect(names, quiet)
	local parts, mapRoot = collect(names)
	local info = {}
	local byZone = {}
	local function zoneStat(z)
		byZone[z] = byZone[z] or { dup = 0, coplanar = 0, sameLook = 0, locked = 0, parts = 0 }
		return byZone[z]
	end

	-- Doublons exacts
	local seen, dups = {}, {}
	for i, p in parts do
		local k = dupKey(p)
		if seen[k] then
			dups[#dups + 1] = { keep = seen[k], drop = p }
		else
			seen[k] = p
		end
		if i % 3000 == 0 then
			task.wait()
		end
	end
	local dropped = {}
	for _, d in dups do
		-- garder celui du contrat, le PrimaryPart ou celui qui a des enfants
		local a, b = d.keep, d.drop
		local function score(p)
			return (isProtected(p, mapRoot) and 100 or 0) + #p:GetChildren()
		end
		if score(b) > score(a) then
			d.keep, d.drop = b, a
		end
		d.locked = isProtected(d.drop, mapRoot)
		d.zone = topName(d.drop, mapRoot)
		d.sameLook = sameLook(d.keep, d.drop)
		dropped[d.drop] = true
		zoneStat(d.zone).dup += 1
	end

	-- Faces
	local bins = {}
	local nFaces = 0
	for i, p in parts do
		if analysable(p) and not dropped[p] then
			local cf, sz = p.CFrame, p.Size
			local prot = isProtected(p, mapRoot)
			local z = topName(p, mapRoot)
			zoneStat(z).parts += 1
			local vecs = { cf.RightVector, cf.UpVector, -cf.LookVector }
			local half = { sz.X / 2, sz.Y / 2, sz.Z / 2 }
			for ax = 1, 3 do
				local o1, o2 = ax % 3 + 1, (ax + 1) % 3 + 1
				local t1, t2 = vecs[o1] * half[o1], vecs[o2] * half[o2]
				for _, s in { 1, -1 } do
					local n = vecs[ax] * s
					local nk = string.format("%.3f,%.3f,%.3f", n.X, n.Y, n.Z)
					nk = string.gsub(nk, "%-0%.000", "0.000")
					local c = cf.Position + n * half[ax]
					local dd = n:Dot(c)
					local face = {
						part = p, ax = ax, s = s, n = n, d = dd, c = c, t1 = t1, t2 = t2,
						area = 4 * half[o1] * half[o2], prot = prot, zone = z, nk = nk,
					}
					local b = r(dd, 0.05)
					face.bin = b
					local key = nk .. "|" .. b
					local L = bins[key]
					if not L then
						L = {}
						bins[key] = L
					end
					L[#L + 1] = face
					nFaces += 1
				end
			end
		end
		if i % 2000 == 0 then
			task.wait()
		end
	end

	-- Paires
	local pairsFound = {}
	local work = 0
	local basisCache = {}
	for key, L in bins do
		local nk, b = string.match(key, "^(.*)|(%-?%d+)$")
		b = tonumber(b)
		local L2 = bins[nk .. "|" .. (b + 1)]
		local all = table.clone(L)
		local nBase = #L
		if L2 then
			for _, f in L2 do
				all[#all + 1] = f
			end
		end
		if #all >= 2 then
			local n = L[1].n
			local bs = basisCache[nk]
			if not bs then
				local u, v = basis(n)
				bs = { u, v }
				basisCache[nk] = bs
			end
			local u, v = bs[1], bs[2]
			for idx, f in all do
				f._base = idx <= nBase
				local pts = {}
				local cs = { f.c + f.t1 + f.t2, f.c - f.t1 + f.t2, f.c - f.t1 - f.t2, f.c + f.t1 - f.t2 }
				local umin, umax = math.huge, -math.huge
				for k, q in cs do
					local pu, pv = u:Dot(q), v:Dot(q)
					pts[k] = { pu, pv }
					umin = math.min(umin, pu)
					umax = math.max(umax, pu)
				end
				if polyArea(pts) < 0 then
					pts = { pts[4], pts[3], pts[2], pts[1] }
				end
				f.poly, f.umin, f.umax = pts, umin, umax
			end
			table.sort(all, function(x, y)
				return x.umin < y.umin
			end)
			for i = 1, #all do
				local a = all[i]
				for j = i + 1, #all do
					local c = all[j]
					if c.umin >= a.umax - 1e-4 then
						break
					end
					if (a._base or c._base) and a.part ~= c.part and math.abs(a.d - c.d) < PLANE_EPS
						and a.n:Dot(c.n) > 0.9999 then
						work += 1
						local inter = clip(a.poly, c.poly)
						if #inter >= 3 then
							local ar = polyArea(inter)
							if ar > AREA_EPS then
								pairsFound[#pairsFound + 1] = { a = a, b = c, area = ar, inter = inter, u = u, v = v }
							end
						end
					end
				end
				if work > 20000 then
					work = 0
					task.wait()
				end
			end
		end
	end

	-- Dédoublonnage (une paire vue depuis deux bacs voisins) et stats
	local uniq, list = {}, {}
	M.markVisible(pairsFound)
	local hidden = 0
	for _, pr in pairsFound do
		if not pr.visible then
			hidden += 1
			continue
		end
		local a, b = pr.a, pr.b
		local k1 = pid(a.part) .. a.ax .. a.s
		local k2 = pid(b.part) .. b.ax .. b.s
		local k = k1 < k2 and (k1 .. "/" .. k2) or (k2 .. "/" .. k1)
		if not uniq[k] then
			uniq[k] = true
			list[#list + 1] = pr
			local st = zoneStat(a.zone)
			st.coplanar += 1
			if sameLook(a.part, b.part) then
				st.sameLook += 1
			end
			if a.prot and b.prot then
				st.locked += 1
			end
		end
	end

	M.last = { names = names, dups = dups, pairs = list, byZone = byZone, nFaces = nFaces, hidden = hidden }
	if quiet then
		return M.last
	end
	local out = { string.format("Pièces : %d, faces analysées : %d, paires cachées ignorées : %d", #parts, nFaces, hidden) }
	for z, st in byZone do
		out[#out + 1] = string.format("%s : %d paires coplanaires (dont %d même aspect, %d contrat contre contrat), %d doublons exacts",
			z, st.coplanar, st.sameLook, st.locked, st.dup)
	end
	return table.concat(out, "\n")
end

-- Pires cas : grande aire commune, aspects différents.
function M.worst(k, zone)
	local L = {}
	for _, pr in M.last.pairs do
		if not sameLook(pr.a.part, pr.b.part) and (not zone or pr.a.zone == zone) then
			L[#L + 1] = pr
		end
	end
	table.sort(L, function(x, y)
		return x.area > y.area
	end)
	local out = {}
	for i = 1, math.min(k or 5, #L) do
		local pr = L[i]
		local c = pr.sample or pr.a.c
		out[#out + 1] = string.format("%.1f st² | %s <-> %s | (%.1f, %.1f, %.1f) n=%s",
			pr.area, fullName(pr.a.part), fullName(pr.b.part), c.X, c.Y, c.Z, pr.a.nk)
	end
	return table.concat(out, "\n")
end

-- Sauvegarde ------------------------------------------------------------------------------
function M.backup(names, label)
	local ss = game:GetService("ServerStorage")
	local root = ss:FindFirstChild("MapBackups") or Instance.new("Folder")
	root.Name = "MapBackups"
	root.Parent = ss
	local dest = root:FindFirstChild(label)
	if not dest then
		dest = Instance.new("Folder")
		dest.Name = label
		dest.Parent = root
	end
	local done = {}
	for _, nm in names do
		local src = workspace.Map:FindFirstChild(nm)
		if src and not dest:FindFirstChild(nm) then
			local copy = src:Clone()
			copy.Parent = dest
			done[#done + 1] = nm
			task.wait()
		end
	end
	return "Sauvegardé dans MapBackups/" .. label .. " : " .. table.concat(done, ", ")
end

-- Correction ------------------------------------------------------------------------------
local function moveFace(p, ax, s, delta)
	-- déplace la face (ax, s) de delta le long de sa normale ; seule cette face bouge
	local sz = p.Size
	local comp = { sz.X, sz.Y, sz.Z }
	if delta < 0 and comp[ax] + delta < 0.05 then -- ne jamais trop amincir une pièce
		return false
	end
	comp[ax] += delta
	local cf = p.CFrame
	local vecs = { cf.RightVector, cf.UpVector, -cf.LookVector }
	local newPos = cf.Position + vecs[ax] * (s * delta / 2)
	p.Size = Vector3.new(comp[1], comp[2], comp[3])
	p.Position = newPos -- Position (pas CFrame) : une pièce soudée bouge seule
	return true
end

function M.fix(names)
	-- Un autre plugin ou une autre session peut tenir un enregistrement ouvert : on attend, et
	-- sans enregistrement on ne change rien (tout doit rester annulable par Ctrl+Z).
	local rec
	for _ = 1, 40 do
		rec = ChangeHistoryService:TryBeginRecording("Chevauchements " .. table.concat(names, ","))
		if rec then
			break
		end
		task.wait(0.25)
	end
	if not rec then
		return "Rien changé : un autre enregistrement est ouvert dans Studio, relancer dans un moment"
	end
	local ok, res = pcall(function()
		local last = M.detect(names, true)
		local mapRoot = workspace.Map
		local stats = {}
		local function st(z)
			stats[z] = stats[z] or { dupRemoved = 0, faces = 0, skipped = 0 }
			return stats[z]
		end
		-- 1. doublons exacts
		for _, d in last.dups do
			if d.locked or d.drop.Parent == nil then
				st(d.zone).skipped += 1
			else
				local par = d.drop.Parent
				local isPrimary = par:IsA("Model") and par.PrimaryPart == d.drop
				if isPrimary then
					st(d.zone).skipped += 1
				else
					d.drop.Parent = nil -- annulable par ChangeHistoryService
					st(d.zone).dupRemoved += 1
				end
			end
		end
		-- 2. faces coplanaires : couches par groupe, la plus grande face reste à 0
		local faceKey = function(f)
			return pid(f.part) .. ":" .. f.ax .. ":" .. f.s
		end
		local neigh, faces = {}, {}
		for _, pr in last.pairs do
			if pr.a.part.Parent and pr.b.part.Parent then
				local ka, kb = faceKey(pr.a), faceKey(pr.b)
				faces[ka], faces[kb] = pr.a, pr.b
				neigh[ka] = neigh[ka] or {}
				neigh[kb] = neigh[kb] or {}
				table.insert(neigh[ka], kb)
				table.insert(neigh[kb], ka)
			end
		end
		local order = {}
		for k in faces do
			order[#order + 1] = k
		end
		table.sort(order, function(x, y)
			local fx, fy = faces[x], faces[y]
			if math.abs(fx.area - fy.area) > 1e-6 then
				return fx.area > fy.area
			end
			return x < y
		end)
		-- Plan visé par face (plus grande d'abord) : la grande reste, chaque plus petite passe
		-- STEP devant la plus avancée de ses voisines déjà placées. Une face du contrat ne bouge
		-- pas : ce sont les faces plus grandes qui la recouvrent qui reculent de STEP derrière elle.
		local target = {}
		for _, k in order do
			local f = faces[k]
			local t = f.d
			if not f.prot then
				for _, nb in neigh[k] do
					-- même couleur et même matière : les textures Roblox suivent le monde, rien ne
					-- clignote entre ces deux-là, inutile de les écarter l'une de l'autre
					if target[nb] and target[nb] > t - STEP and not sameLook(f.part, faces[nb].part) then
						t = target[nb] + STEP
					end
				end
			end
			target[k] = t
		end
		for _, k in order do
			local f = faces[k]
			if f.prot then
				for _, nb in neigh[k] do
					local g = faces[nb]
					if not g.prot and target[nb] > f.d - STEP and g.area >= f.area then
						target[nb] = f.d - STEP
					end
				end
			end
		end
		for _, k in order do
			local f = faces[k]
			local delta = target[k] - f.d
			if math.abs(delta) > 1e-4 then
				if f.prot then
					st(f.zone).skipped += 1
				elseif delta > MAX_SHIFT + 1e-4 then
					st(f.zone).skipped += 1 -- plus de 0,05 : laissé, à voir à la main
				elseif moveFace(f.part, f.ax, f.s, delta) then
					st(f.zone).faces += 1
				else
					st(f.zone).skipped += 1
				end
			end
		end
		local out = {}
		for z, s in stats do
			out[#out + 1] = string.format("%s : %d doublons retirés, %d faces décalées, %d laissés (contrat ou plus de 0,05)", z, s.dupRemoved, s.faces, s.skipped)
		end
		return table.concat(out, "\n")
	end)
	ChangeHistoryService:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	if not ok then
		error(res)
	end
	return res
end

_G.MapZF = M
return "MapZF prêt"
