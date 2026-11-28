--!nocheck
-- Superpositions qui scintillent (z-fighting) dans Workspace/Map (demande de Clément, 27/11 : « Il faut revoir les z
-- index de toutes les zones, je vois des éléments buggés de superposition »).
-- Détection : pour chaque bloc (Part de forme Block, visible), ses 6 faces ; deux faces tournées du même côté, dans le
-- même plan (écart < PLANE_TOL) et qui se recouvrent (recouvrement > MIN_OVERLAP dans les deux sens) forment une paire.
-- Classement de chaque paire :
--   - doublon exact (même taille, même place, même couleur, matière et transparence) : on retire celui qui n'a ni
--     enfant ni tag ;
--   - « sans effet » : même couleur, matière, variante, transparence et aucune image (Decal, Texture, SurfaceGui) sur
--     ces faces : rien ne scintille, on n'y touche pas ;
--   - conflit visible : la pièce qui doit passer devant (celle qui porte l'image sur cette face, sinon la plus petite
--     face, et à taille égale la plus claire) avance de SHIFT stud vers l'extérieur de la face ; même taille et même
--     teinte : pas touché, listé.
-- Jamais touché : les pièces du contrat (Window, Shutter, Door, Bounds, ShelfSlot, GuardSpawn, SignPart…, et tout ce
-- qui est dans un modèle de ce nom), les pièces taguées, les dossiers dont le nom commence par « _ », les MeshPart,
-- Union, Wedge, cylindres et boules (formes non mesurables ici). Une image n'est jamais bougée : c'est sa pièce.
-- MODE = "detect" : rapport seul. MODE = "fix" : sauvegarde des pièces touchées puis correction.
-- Sauvegarde : ServerStorage/MapBackups/<date>_ZFighting (copie de chaque pièce avant changement, attribut Path = chemin
-- d'origine, Shift = déplacement total ; les doublons retirés y sont déplacés, pas détruits). Relançable : une pièce
-- avancée peut retomber dans le plan d'une voisine (feuilles empilées) ; relancer jusqu'à ce qu'une passe n'avance
-- presque plus rien (27/11 : 1 200 puis 43, 18, puis 3 à 7 par passe ; au plus 0,06 stud cumulé par pièce).
-- À lancer dans Studio (MCP execute_luau, Edit, hors Play).

local MODE = "fix"
local PLANE_TOL = 0.01
local MIN_OVERLAP = 0.05
local SHIFT = 0.03
local EQUAL_AREA = 0.01 -- écart relatif sous lequel deux faces sont « de même taille »

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local MAP = workspace.Map

local PROTECTED = {
	"^Window$", "^WindowFractured$", "^Shard_%d+$", "^Shutter$", "^ShutterButton$", "^Door$", "^Bounds$", "^ShelfSlot_%d+$",
	"^GuardSpawn$", "^SignPart$", "^DisplayStand_%d+$", "^DisplaySlot_%d+$", "^CollectPad_%d+$", "^UnboxBench_%d+$",
	"^BoxSpawn_%d+$", "^LootSpawn_%d+$", "^TrapSlot_%d+$", "^VaultSlot_%d+$", "^Piece_%d+$", "^Pane_", "^Look_%d+$",
	"^Ceiling$", "^CeilingFractured$", "^Lid$", "^DepositZone$", "^PlotFloor$", "^RayonSpot_%d+$", "^TriggerZone$",
	"^InviteZone$", "^RewardsZone$", "^WheelZone$", "^SpawnPoint$", "^UsePoint$", "^HitPoint$", "^ShopPad$",
	"^Board$", "^Root$", "^HumanoidRootPart$", "^Handle$", "^ReqSignPoint$", "^StoreReqSign$", "^NameSign$",
}
local function protectedName(n)
	for _, p in PROTECTED do if n:match(p) then return true end end
	return false
end
-- « Base » n'est au contrat que dans un magasin, une boutique, un objet, un colis, un outil ou un événement
local CONTRACT_MODEL = { "^STORE_", "^PLOT_", "^ITM_", "^BOX_", "^TOOL_", "^ENV_Event_" }
local function excluded(part)
	if #CS:GetTags(part) > 0 or protectedName(part.Name) then return true end
	local a = part.Parent
	while a and a ~= MAP do
		if a.Name:sub(1, 1) == "_" or protectedName(a.Name) then return true end
		if part.Name == "Base" then for _, pat in CONTRACT_MODEL do if a.Name:match(pat) then return true end end end
		if a:IsA("Model") and a:FindFirstChildOfClass("Humanoid") then return true end
		a = a.Parent
	end
	return false
end
local function zoneOf(part)
	local a = part
	while a.Parent and a.Parent ~= MAP do a = a.Parent end
	return a.Name
end

-- Images posées sur une face de la pièce
local FACES = {
	{ axis = "X", s = 1, id = Enum.NormalId.Right }, { axis = "X", s = -1, id = Enum.NormalId.Left },
	{ axis = "Y", s = 1, id = Enum.NormalId.Top }, { axis = "Y", s = -1, id = Enum.NormalId.Bottom },
	{ axis = "Z", s = 1, id = Enum.NormalId.Back }, { axis = "Z", s = -1, id = Enum.NormalId.Front },
}
local function imageOn(part, faceId)
	for _, c in part:GetChildren() do
		if (c:IsA("Decal") and c.Face == faceId and c.Transparency < 1) or (c:IsA("SurfaceGui") and c.Face == faceId and c.Enabled) then return true end
	end
	return false
end
-- Face cachée : un point juste devant elle (au centre de la plus petite des deux faces) est dans une autre pièce opaque
local function hidden(face, pa, pb)
	local pt = face.c + face.n * 0.06
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { pa, pb }
	for _, h in workspace:GetPartBoundsInBox(CFrame.new(pt), Vector3.new(0.02, 0.02, 0.02), op) do
		if h.Transparency < 0.5 then
			if h.ClassName == "Part" and h.Shape == Enum.PartType.Block then
				local l = h.CFrame:PointToObjectSpace(pt)
				if math.abs(l.X) <= h.Size.X / 2 and math.abs(l.Y) <= h.Size.Y / 2 and math.abs(l.Z) <= h.Size.Z / 2 then return true end
			else
				return true
			end
		end
	end
	return false
end
local function look(p) return table.concat({ p.Color:ToHex(), p.Material.Name, p.MaterialVariant, ("%.2f"):format(p.Transparency), ("%.2f"):format(p.Reflectance) }, "|") end

-- 1) Faces
local faces, buckets = {}, {}
local count = 0
local ids = {}
for _, part in MAP:GetDescendants() do
	if part.ClassName == "Part" and part.Shape == Enum.PartType.Block and part.Transparency < 0.95 and part.Anchored then
		local cf, sz = part.CFrame, part.Size
		local ax = { X = cf.RightVector, Y = cf.UpVector, Z = -cf.LookVector } -- axes locaux X, Y, Z
		local half = { X = sz.X / 2, Y = sz.Y / 2, Z = sz.Z / 2 }
		for _, f in FACES do
			local n = ax[f.axis] * f.s
			local others = {}
			for _, k in { "X", "Y", "Z" } do if k ~= f.axis then table.insert(others, k) end end
			local c = cf.Position + n * half[f.axis]
			local face = {
				part = part, n = n, c = c, d = n:Dot(c), faceId = f.id,
				u = ax[others[1]], hu = half[others[1]], v = ax[others[2]], hv = half[others[2]],
				area = 4 * half[others[1]] * half[others[2]],
			}
			local key = ("%d,%d,%d"):format(math.round(n.X * 100) + 0, math.round(n.Y * 100) + 0, math.round(n.Z * 100) + 0)
			face.nkey = key
			local b = math.floor(face.d / PLANE_TOL)
			local bk = key .. "|" .. b
			buckets[bk] = buckets[bk] or { nkey = key, b = b, list = {} }
			table.insert(buckets[bk].list, face)
		end
		count += 1
		ids[part] = count
		if count % 4000 == 0 then task.wait() end
	end
end

-- 2) Paires
local function overlap(f1, f2)
	if math.abs(f1.d - f2.d) >= PLANE_TOL then return false end
	local dc = f2.c - f1.c
	for _, a in { f1.u, f1.v, f2.u, f2.v } do
		local r1 = f1.hu * math.abs(f1.u:Dot(a)) + f1.hv * math.abs(f1.v:Dot(a))
		local r2 = f2.hu * math.abs(f2.u:Dot(a)) + f2.hv * math.abs(f2.v:Dot(a))
		if r1 + r2 - math.abs(dc:Dot(a)) <= MIN_OVERLAP then return false end
	end
	return true
end
local pairsFound = {}
local seen = {}
local steps = 0
for _, bk in buckets do
	local list = table.clone(bk.list)
	local nextB = buckets[bk.nkey .. "|" .. (bk.b + 1)]
	local nFirst = #list
	if nextB then for _, f in nextB.list do table.insert(list, f) end end
	if #list > 1 then
		local n = list[1].n
		local e1 = (math.abs(n.Y) < 0.9) and n:Cross(Vector3.yAxis).Unit or n:Cross(Vector3.xAxis).Unit
		for i, f in list do
			local r = f.hu * math.abs(f.u:Dot(e1)) + f.hv * math.abs(f.v:Dot(e1))
			local m = f.c:Dot(e1)
			f.lo, f.hi, f.idx = m - r, m + r, i
		end
		table.sort(list, function(a, b) return a.lo < b.lo end)
		for i = 1, #list do
			local a = list[i]
			for j = i + 1, #list do
				local b = list[j]
				if b.lo > a.hi then break end
				if a.part ~= b.part and not (a.idx > nFirst and b.idx > nFirst) and overlap(a, b) then
					local k1, k2 = ids[a.part], ids[b.part]
					local pk = (k1 < k2) and (k1 .. ":" .. k2 .. ":" .. a.nkey) or (k2 .. ":" .. k1 .. ":" .. a.nkey)
					if not seen[pk] then
						seen[pk] = true
						table.insert(pairsFound, { a, b })
					end
				end
				steps += 1
				if steps % 50000 == 0 then task.wait() end
			end
		end
	end
end

-- 3) Classement (avant de bouger quoi que ce soit : la détection des faces cachées voit la map d'origine)
local stats, notTouched = {}, {}
local function st(z) stats[z] = stats[z] or { pairs = 0, harmless = 0, dup = 0, moved = 0, skipped = 0, hidden = 0 } return stats[z] end
local function short(p) return (p:GetFullName():gsub("^Workspace%.Map%.", "")) end
-- Faces vers le haut d'abord, puis les côtés, puis vers le bas : une pièce n'avance qu'une fois par axe (une bande noyée
-- dans une route partage son dessus et son dessous : on l'avance vers le haut, jamais aussi vers le bas)
table.sort(pairsFound, function(x, y) return x[1].n.Y > y[1].n.Y end)
local plan, moved, removed = {}, {}, {}
local function movedAlong(part, n) for _, m in moved[part] or {} do if math.abs(m:Dot(n)) > 0.99 then return true end end return false end
for idx, pr in pairsFound do
	if idx % 2000 == 0 then task.wait() end
	local a, b = pr[1], pr[2]
	local pa, pb = a.part, b.part
	if not (removed[pa] or removed[pb]) then
		local z = zoneOf(pa)
		local s = st(z)
		local exA, exB = excluded(pa), excluded(pb)
		local imgA, imgB = imageOn(pa, a.faceId), imageOn(pb, b.faceId)
		local same = look(pa) == look(pb)
		local dup = same and (pa.Size - pb.Size).Magnitude < 0.001 and (pa.Position - pb.Position).Magnitude < 0.001
			and pa.CFrame.LookVector:Dot(pb.CFrame.LookVector) > 0.9999 and pa.CFrame.UpVector:Dot(pb.CFrame.UpVector) > 0.9999
		if exA and exB then
			-- deux pièces protégées : hors champ
		elseif dup then
			local victim = nil
			for _, cand in { pb, pa } do if not excluded(cand) and #cand:GetChildren() == 0 then victim = cand break end end
			if victim then s.dup += 1 removed[victim] = true table.insert(plan, { dup = victim })
			else s.skipped += 1 table.insert(notTouched, z .. " : doublon protégé ou avec enfants : " .. short(pa)) end
		elseif same and not imgA and not imgB then
			s.harmless += 1
		elseif hidden((a.area <= b.area) and a or b, pa, pb) then
			s.hidden += 1
		else
			s.pairs += 1
			local mover, face
			if imgA ~= imgB then mover, face = (imgA and pa or pb), (imgA and a or b)
			elseif math.abs(a.area - b.area) <= EQUAL_AREA * math.max(a.area, b.area) then
				-- même taille (palmes de deux verts qui se croisent) : la plus claire passe devant ; même teinte : pas touché
				local la = pa.Color.R + pa.Color.G + pa.Color.B
				local lb = pb.Color.R + pb.Color.G + pb.Color.B
				if math.abs(la - lb) < 0.01 then mover = nil
				else mover, face = (la > lb) and pa or pb, (la > lb) and a or b end
			else mover, face = (a.area < b.area) and pa or pb, (a.area < b.area) and a or b end
			if mover and excluded(mover) then
				-- la pièce à avancer est protégée : on n'avance pas l'autre (elle passerait devant), on liste
				s.skipped += 1
				table.insert(notTouched, z .. " : à avancer mais protégée : " .. short(mover) .. " / " .. short(mover == pa and pb or pa))
			elseif not mover then
				s.skipped += 1
				table.insert(notTouched, z .. " : même taille, couleurs différentes : " .. short(pa) .. " / " .. short(pb))
			elseif not movedAlong(mover, face.n) then
				s.moved += 1
				moved[mover] = moved[mover] or {}
				table.insert(moved[mover], face.n)
				table.insert(plan, { mover = mover, n = face.n })
			end
		end
	end
end

-- 4) Correction (MODE = "fix")
local nm, nd, np = 0, 0, 0
if MODE == "fix" then
	local rec = CHS:TryBeginRecording("Z-fighting de la map", { allowNoUndo = true })
	local mb = game.ServerStorage.MapBackups
	local bname = os.date("%Y-%m-%d") .. "_ZFighting"
	local backup = mb:FindFirstChild(bname)
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = bname
		backup:SetAttribute("Note", "Pièces de Workspace/Map avant la correction des superpositions (27/11, tools/clement/zones/zfighting_map.luau). Chaque copie porte Path (chemin d'origine) et Shift (vecteur total dont la pièce a avancé). Doublons retirés : déplacés ici tels quels, avec Path. Pour revenir : reculer chaque pièce de son Shift.")
		backup.Parent = mb
	end
	local copies = {}
	for _, c in backup:GetChildren() do if c:GetAttribute("Shift") then copies[c:GetAttribute("Path")] = c end end
	for i, step in plan do
		if i % 500 == 0 then task.wait() end
		if step.dup then
			step.dup:SetAttribute("Path", step.dup:GetFullName())
			for _, t in CS:GetTags(step.dup) do CS:RemoveTag(step.dup, t) end
			step.dup.Parent = backup
			nd += 1
		else
			local p = step.mover
			local path = p:GetFullName()
			local c = copies[path]
			if not c then
				c = p:Clone()
				for _, t in CS:GetTags(c) do CS:RemoveTag(c, t) end
				c:SetAttribute("Path", path)
				c:SetAttribute("Shift", Vector3.zero)
				c.Parent = backup
				copies[path] = c
				np += 1
			end
			local shift = step.n * SHIFT
			p.CFrame = p.CFrame + shift
			c:SetAttribute("Shift", c:GetAttribute("Shift") + shift)
			nm += 1
		end
	end
	if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
end

local lines = { ("MODE %s : %d blocs, %d paires coplanaires ; %d déplacements (%d pièces neuves sauvegardées), %d doublons retirés"):format(MODE, count, #pairsFound, nm, np, nd) }
local zones = {}
for z in stats do table.insert(zones, z) end
table.sort(zones)
for _, z in zones do
	local s = stats[z]
	table.insert(lines, ("%s : %d visibles (%d à avancer, %d non touchés), %d doublons, %d sans effet, %d cachés"):format(z, s.pairs, s.moved, s.skipped, s.dup, s.harmless, s.hidden))
end
local nt = {}
for _, t in notTouched do local k = t:gsub("%.[%w_]+_%d+[A-Z]?", ".*"):sub(1, 140) nt[k] = (nt[k] or 0) + 1 end
local ntl = {}
for k, v in nt do table.insert(ntl, { k, v }) end
table.sort(ntl, function(x, y) return x[2] > y[2] end)
table.insert(lines, "Non touchés (" .. #notTouched .. ") :")
for i = 1, math.min(20, #ntl) do table.insert(lines, "   " .. ntl[i][2] .. " × " .. ntl[i][1]) end
return table.concat(lines, "\n")
