--!nocheck
-- Superpositions qui scintillent dans la boutique du joueur (Clément, 27/11 : « dans les vidéos, on voit le sol un peu
-- buggé des boutiques »). Même règle que tools/clement/zones/zfighting_map.luau, appliquée à la boutique telle que le
-- code la monte en jeu : ShopStageService copie Stage_2 à Stage_5 et Floor_2 du gabarit, RayonService copie
-- PLOT_Shop_Rayons/Rayon_0k (RayonVisuals), tous posés par plot:GetPivot() × gabarit:GetPivot():Inverse().
-- Assemblages contrôlés, un à la fois, dans Workspace/_ZF_TEST (retiré à la fin) :
--   - le gabarit ReplicatedStorage/Assets/Plots/PLOT_Shop entier, avec les rayons de PLOT_Shop_Rayons ;
--   - chacune des 6 boutiques Map/Hub/Shops/PLOT_Shop_0n, avec les étages, Floor_2 et les rayons du gabarit.
-- Boutique entière (niveau 5, sans coupe) : c'est l'assemblage qui contient toutes les pièces ; une boutique coupée
-- au fond n'en est qu'une partie (pièces fines du fond avancées : non simulées ici).
-- Une paire visible (faces tournées du même côté, dans le même plan à moins de 0,01, qui se recouvrent, couleurs ou
-- matières différentes ou image sur la face, et face non recouverte) : la pièce de devant (celle qui porte l'image,
-- sinon la plus petite face, à taille égale la plus claire) avance de 0,03 stud. Le déplacement est reporté sur la
-- pièce d'origine : gabarit (et donc toutes les boutiques en jeu), PLOT_Shop_Rayons, ou la boutique du hub.
-- Jamais touché : pièces du contrat (PlotFloor, CollectPad, DisplayStand, Bounds, DepositZone, RayonSpot…), pièces
-- taguées. Plusieurs passes, jusqu'à ce qu'aucune pièce n'avance.
-- Sauvegarde : ServerStorage/MapBackups/<date>_ZFighting_Boutique (copie de chaque pièce d'origine avant changement,
-- attributs Path et Shift dans le repère de sa boutique). MODE = "detect" : rapport seul ; "fix" : correction.
-- Passe du 27/11 (place DEV v1491), en trois temps :
--   1. ce script (MODE fix) : 45 pièces avancées de 0,03 (gabarit 41, PLOT_Shop_Rayons 4) ;
--   2. pièces prises dans le même plan des deux côtés (baguettes de la cabine aussi épaisses que le mur, sol de
--      l'étage Floor2_B/C dans le volume du toit Stage_4/Roof/RoofSlab, corniches de Stage_5, linteau PlotDoor/Header
--      autour de la vitre de l'étage) : épaissies de 0,06 sur l'axe en cause (gabarit, et Header des 6 boutiques) ;
--   3. écarts trop fins, sous 0,03 stud (le vrai « sol buggé » : les carreaux FloorTiles/Tile_* et
--      Stage_2/FloorTilesExt/Tile_* n'étaient qu'à 0,02 au-dessus de PlotFloor et PlotFloorExt, ce qui scintille de
--      loin ; aussi GoldLip, SignTube, cadres d'enseigne, PadBase) : la pièce de devant remontée juste assez pour un
--      écart de 0,03 (carreaux +0,01).
-- Contrôle final : aucune paire dans le même plan dans le gabarit et les 6 boutiques assemblées.
-- À lancer dans Studio (MCP execute_luau, Edit, hors Play).

local MODE = "detect"
local PASSES = 4
local PLANE_TOL, MIN_OVERLAP, SHIFT, EQUAL_AREA = 0.01, 0.05, 0.03, 0.01

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local PLOTS = game.ReplicatedStorage.Assets.Plots
local TEMPLATE = PLOTS.PLOT_Shop
local RAYONS = PLOTS:FindFirstChild("PLOT_Shop_Rayons")
local HUBS = {}
for i = 1, 6 do table.insert(HUBS, workspace.Map.Hub.Shops:FindFirstChild(("PLOT_Shop_%02d"):format(i))) end
local COPIED = { "Stage_2", "Stage_3", "Stage_4", "Stage_5", "Floor_2" }

local PROTECTED = {
	"^Window$", "^WindowFractured$", "^Shard_%d+$", "^Shutter$", "^ShutterButton$", "^Door$", "^Bounds$", "^ShelfSlot_%d+$",
	"^GuardSpawn$", "^SignPart$", "^DisplayStand_%d+$", "^DisplaySlot_%d+$", "^CollectPad_%d+$", "^UnboxBench_%d+$",
	"^BoxSpawn_%d+$", "^LootSpawn_%d+$", "^TrapSlot_%d+$", "^VaultSlot_%d+$", "^Piece_%d+$", "^Pane_", "^Look_%d+$",
	"^Ceiling$", "^CeilingFractured$", "^Lid$", "^DepositZone$", "^PlotFloor$", "^RayonSpot_%d+$", "^TriggerZone$",
	"^InviteZone$", "^RewardsZone$", "^WheelZone$", "^SpawnPoint$", "^UsePoint$", "^HitPoint$", "^ShopPad$",
	"^Board$", "^Root$", "^HumanoidRootPart$", "^Handle$", "^ReqSignPoint$", "^StoreReqSign$", "^NameSign$", "^Base$",
	"^CashPad$", "^VaultAnchor$", "^RayonAnchor$",
}
local function protectedName(n) for _, p in PROTECTED do if n:match(p) then return true end end return false end
-- Modèles dont les enfants sont eux-mêmes au contrat ; le décor d'un DisplayStand (SocleDecor) n'en fait pas partie
local ANCESTORS = { "^Window$", "^WindowFractured$", "^Shutter$", "^Door$" }
local function protectedAncestor(n) for _, p in ANCESTORS do if n:match(p) then return true end end return false end

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
local function look(p) return table.concat({ p.Color:ToHex(), p.Material.Name, p.MaterialVariant, ("%.2f"):format(p.Transparency), ("%.2f"):format(p.Reflectance) }, "|") end
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

-- Copie d'une source dans l'assemblage, avec le lien copie → pièce d'origine et le repère de la boutique d'origine
local srcOf, ownerOf = {}, {}
local function cloneInto(src, parent, rel, owner)
	local map, k = {}, 0
	local list = src:IsA("BasePart") and { src } or {}
	for _, d in src:GetDescendants() do if d:IsA("BasePart") then table.insert(list, d) end end
	for _, d in list do k += 1 d:SetAttribute("_zf", k) map[k] = d end
	local c = src:Clone()
	for _, d in list do d:SetAttribute("_zf", nil) end
	local clist = c:IsA("BasePart") and { c } or {}
	for _, d in c:GetDescendants() do if d:IsA("BasePart") then table.insert(clist, d) end end
	for _, d in clist do
		local id = d:GetAttribute("_zf")
		if id then srcOf[d] = map[id] ownerOf[d] = owner d:SetAttribute("_zf", nil) end
	end
	for _, d in c:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end
	if rel then
		if c:IsA("BasePart") then c.CFrame = rel * c.CFrame else c:PivotTo(rel * c:GetPivot()) end
	end
	c.Parent = parent
	return c
end

local function build(kind, hub)
	local test = workspace:FindFirstChild("_ZF_TEST") or Instance.new("Folder")
	test.Name = "_ZF_TEST"
	test.Parent = workspace
	test:ClearAllChildren()
	local root = Instance.new("Model")
	root.Name = kind
	root.Parent = test
	if kind == "PLOT_Shop" then
		cloneInto(TEMPLATE, root, nil, TEMPLATE)
		if RAYONS then for _, r in RAYONS:GetChildren() do cloneInto(r, root, nil, TEMPLATE) end end
	else
		local rel = hub:GetPivot() * TEMPLATE:GetPivot():Inverse()
		cloneInto(hub, root, nil, hub)
		for _, n in COPIED do local s = TEMPLATE:FindFirstChild(n) if s then cloneInto(s, root, rel, TEMPLATE) end end
		if RAYONS then for _, r in RAYONS:GetChildren() do cloneInto(r, root, rel, TEMPLATE) end end
	end
	return root
end

local function excludedIn(root, part)
	local src = srcOf[part]
	if #CS:GetTags(part) > 0 or (src and #CS:GetTags(src) > 0) or protectedName(part.Name) then return true end
	local a = part.Parent
	while a and a ~= root do
		if protectedAncestor(a.Name) then return true end
		a = a.Parent
	end
	return false
end

-- Une passe sur un assemblage : liste des { copie, normale (repère du monde) } à avancer
local function detect(root)
	local buckets, ids, count = {}, {}, 0
	for _, part in root:GetDescendants() do
		if part.ClassName == "Part" and part.Shape == Enum.PartType.Block and part.Transparency < 0.95 then
			local cf, sz = part.CFrame, part.Size
			local ax = { X = cf.RightVector, Y = cf.UpVector, Z = -cf.LookVector }
			local half = { X = sz.X / 2, Y = sz.Y / 2, Z = sz.Z / 2 }
			for _, f in FACES do
				local n = ax[f.axis] * f.s
				local others = {}
				for _, k in { "X", "Y", "Z" } do if k ~= f.axis then table.insert(others, k) end end
				local c = cf.Position + n * half[f.axis]
				local face = { part = part, n = n, c = c, d = n:Dot(c), faceId = f.id, u = ax[others[1]], hu = half[others[1]], v = ax[others[2]], hv = half[others[2]], area = 4 * half[others[1]] * half[others[2]] }
				face.nkey = ("%d,%d,%d"):format(math.round(n.X * 100) + 0, math.round(n.Y * 100) + 0, math.round(n.Z * 100) + 0)
				local b = math.floor(face.d / PLANE_TOL)
				local bk = face.nkey .. "|" .. b
				buckets[bk] = buckets[bk] or { nkey = face.nkey, b = b, list = {} }
				table.insert(buckets[bk].list, face)
			end
			count += 1
			ids[part] = count
		end
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { root }
	local function hidden(face, pa, pb)
		local pt = face.c + face.n * 0.06
		for _, h in workspace:GetPartBoundsInBox(CFrame.new(pt), Vector3.new(0.02, 0.02, 0.02), op) do
			if h ~= pa and h ~= pb and h.Transparency < 0.5 then
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
	local pairsFound, seen = {}, {}
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
						if not seen[pk] then seen[pk] = true table.insert(pairsFound, { a, b }) end
					end
				end
			end
		end
	end
	table.sort(pairsFound, function(x, y) return x[1].n.Y > y[1].n.Y end)
	local plan, moved, visible, skipped, examples = {}, {}, 0, {}, {}
	local function movedAlong(part, n) for _, m in moved[part] or {} do if math.abs(m:Dot(n)) > 0.99 then return true end end return false end
	local function rel(p) return (p:GetFullName():gsub("^Workspace%._ZF_TEST%.[%w_]+%.", "")) end
	for _, pr in pairsFound do
		local a, b = pr[1], pr[2]
		local pa, pb = a.part, b.part
		local exA, exB = excludedIn(root, pa), excludedIn(root, pb)
		local imgA, imgB = imageOn(pa, a.faceId), imageOn(pb, b.faceId)
		if not (exA and exB) and not (look(pa) == look(pb) and not imgA and not imgB) and not hidden((a.area <= b.area) and a or b, pa, pb) then
			visible += 1
			local mover, face
			if imgA ~= imgB then mover, face = (imgA and pa or pb), (imgA and a or b)
			elseif math.abs(a.area - b.area) <= EQUAL_AREA * math.max(a.area, b.area) then
				local la, lb = pa.Color.R + pa.Color.G + pa.Color.B, pb.Color.R + pb.Color.G + pb.Color.B
				if math.abs(la - lb) >= 0.01 then mover, face = (la > lb) and pa or pb, (la > lb) and a or b end
			else mover, face = (a.area < b.area) and pa or pb, (a.area < b.area) and a or b end
			local other = (mover == pa) and pb or pa
			if not mover then
				table.insert(skipped, "même taille et teinte : " .. rel(pa) .. " / " .. rel(pb))
			elseif excludedIn(root, mover) then
				table.insert(skipped, "à avancer mais protégée : " .. rel(mover) .. " sur " .. rel(other))
			elseif not srcOf[mover] then
				table.insert(skipped, "sans pièce d'origine : " .. rel(mover))
			elseif not movedAlong(mover, face.n) then
				moved[mover] = moved[mover] or {}
				table.insert(moved[mover], face.n)
				table.insert(plan, { copy = mover, n = face.n })
				if #examples < 8 then table.insert(examples, rel(mover) .. " sur " .. rel(other)) end
			end
		end
	end
	return plan, visible, skipped, examples
end

-- Report sur les pièces d'origine (une normale par pièce d'origine et par axe, toutes boutiques confondues)
local applied, copies, backup = {}, {}, nil
local function applyPlan(plan, ownerFrame)
	local n = 0
	for _, step in plan do
		local src = srcOf[step.copy]
		local owner = ownerOf[step.copy]
		-- normale dans le repère de la boutique d'origine (le gabarit est posé dans le repère de la boutique du hub)
		local localN = ownerFrame:VectorToObjectSpace(step.n)
		local srcN = owner:GetPivot():VectorToWorldSpace(localN)
		local done = false
		for _, m in applied[src] or {} do if math.abs(m:Dot(srcN)) > 0.99 then done = true end end
		if not done then
			applied[src] = applied[src] or {}
			table.insert(applied[src], srcN)
			if MODE == "fix" then
				local c = copies[src]
				if not c then
					c = src:Clone()
					for _, t in CS:GetTags(c) do CS:RemoveTag(c, t) end
					c:SetAttribute("Path", src:GetFullName())
					c:SetAttribute("Shift", Vector3.zero)
					c.Parent = backup
					copies[src] = c
				end
				src.CFrame = src.CFrame + srcN * SHIFT
				c:SetAttribute("Shift", c:GetAttribute("Shift") + localN * SHIFT)
			end
			n += 1
		end
	end
	return n
end

local rec
if MODE == "fix" then
	rec = CHS:TryBeginRecording("Z-fighting de la boutique", { allowNoUndo = true })
	local mb = game.ServerStorage.MapBackups
	local bname = os.date("%Y-%m-%d") .. "_ZFighting_Boutique"
	backup = mb:FindFirstChild(bname)
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = bname
		backup:SetAttribute("Note", "Pièces du gabarit PLOT_Shop, de PLOT_Shop_Rayons et des 6 boutiques du hub avant la correction des superpositions (27/11, tools/clement/hub/zfighting_boutique.luau). Path = chemin d'origine, Shift = déplacement total dans le repère de la boutique (gabarit : repère du monde, pivot à l'origine). Pour revenir : reculer chaque pièce de son Shift.")
		backup.Parent = mb
	end
end

local lines = {}
for pass = 1, (MODE == "fix") and PASSES or 1 do
	local total = 0
	for _, kind in { "PLOT_Shop", 1, 2, 3, 4, 5, 6 } do
		local hub = (kind ~= "PLOT_Shop") and HUBS[kind] or nil
		local root = build(hub and hub.Name or "PLOT_Shop", hub)
		local frame = hub and hub:GetPivot() or TEMPLATE:GetPivot()
		local plan, visible, skipped, examples = detect(root)
		local n = applyPlan(plan, frame)
		total += n
		table.insert(lines, ("passe %d, %s : %d paires visibles, %d avancées, %d non touchées"):format(pass, root.Name, visible, n, #skipped))
		if pass == 1 then
			for _, e in examples do table.insert(lines, "    " .. e) end
			for i, s in skipped do if i <= 6 then table.insert(lines, "    non touché : " .. s) end end
		end
		srcOf, ownerOf = {}, {}
		task.wait()
	end
	if total == 0 then break end
end
local test = workspace:FindFirstChild("_ZF_TEST")
if test then test:Destroy() end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local np = 0 for _ in copies do np += 1 end
table.insert(lines, ("MODE %s : %d pièces d'origine avancées ; _ZF_TEST retiré"):format(MODE, np))
return table.concat(lines, "\n")
