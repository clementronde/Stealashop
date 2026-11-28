--!nocheck
-- Écart minimum de 0,03 stud entre deux faces superposées dans Workspace/Map (Clément, 27/11 : « revoir les z index de
-- toutes les zones » ; suite de tools/clement/zones/zfighting_map.luau, qui ne traitait que les faces à moins de 0,01,
-- et de tools/clement/hub/zfighting_boutique.luau, où le vrai sol buggé était des carreaux à 0,02 du sol).
-- Paire : deux faces de blocs (Part Block visibles) tournées du même côté, à moins de MIN_GAP l'une de l'autre (et à plus
-- de 0,004 : le même plan exact est l'affaire de zfighting_map.luau), qui se recouvrent, de couleur, matière ou
-- transparence différentes, et dont la face de devant n'est pas recouverte par une troisième pièce opaque.
-- Correction : la pièce de devant s'éloigne de (MIN_GAP − écart) vers l'extérieur ; si elle est protégée, c'est la
-- pièce de derrière qui recule d'autant. L'ordre voulu par le modèle (qui passe devant) est donc gardé.
-- Jamais touché : pièces du contrat (Window, Shutter, Door, Bounds, ShelfSlot, GuardSpawn, SignPart, DisplayStand,
-- CollectPad, PlotFloor, RayonSpot…, et tout ce qui est dans Window, WindowFractured, Shutter ou Door), pièces taguées,
-- dossiers « _ », modèles à Humanoid ; « Base » seulement dans un STORE_, PLOT_, ITM_, BOX_, TOOL_ ou ENV_Event_.
-- Plusieurs passes (une pièce éloignée peut se rapprocher d'une troisième), mais chaque pièce ne bouge qu'une fois :
-- sans cela, des couches empilées se repoussent de passe en passe (essai du 27/11 : jusqu'à 0,24 stud, annulé).
-- Passe du 27/11 (place DEV v1494) : 702 + 301 + 1 pièces éloignées (au plus 0,025 stud), puis, pour les paires où les
-- deux pièces avaient déjà bougé (pièce fine prise dans une plus épaisse : anneaux et rayons de la grande roue, cœurs et
-- pétales des fleurs, piliers et vitrages de Paris), la pièce de devant épaissie de 2 × (0,03 − écart) sur l'axe en
-- cause (265 pièces, au plus 0,04 ; copie avec l'attribut Grow). Restaient 7 paires (Zone_3 4, Zone_4 1, Zone_6 2).
-- Sauvegarde : ServerStorage/MapBackups/<date>_ZFighting_Ecart, copie de chaque pièce avant changement (Path, Shift).
-- MODE = "detect" : rapport seul ; "fix" : correction. À lancer dans Studio (MCP execute_luau, Edit, hors Play).

local MODE = "detect"
local MIN_GAP, MIN_OVERLAP, PASSES = 0.03, 0.05, 3

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
	"^CashPad$", "^VaultAnchor$", "^RayonAnchor$",
}
local ANCESTORS = { "^Window$", "^WindowFractured$", "^Shutter$", "^Door$" }
local CONTRACT_MODEL = { "^STORE_", "^PLOT_", "^ITM_", "^BOX_", "^TOOL_", "^ENV_Event_" }
local function match(n, list) for _, p in list do if n:match(p) then return true end end return false end
local exCache = {}
local function excluded(part)
	local v = exCache[part]
	if v ~= nil then return v end
	v = #CS:GetTags(part) > 0 or match(part.Name, PROTECTED)
	local a = part.Parent
	while not v and a and a ~= MAP do
		if a.Name:sub(1, 1) == "_" or match(a.Name, ANCESTORS) then v = true end
		if part.Name == "Base" and match(a.Name, CONTRACT_MODEL) then v = true end
		if a:IsA("Model") and a:FindFirstChildOfClass("Humanoid") then v = true end
		a = a.Parent
	end
	exCache[part] = v
	return v
end
local function zoneOf(part) local a = part while a.Parent and a.Parent ~= MAP do a = a.Parent end return a.Name end
local function look(p) return table.concat({ p.Color:ToHex(), p.Material.Name, p.MaterialVariant, ("%.2f"):format(p.Transparency) }, "|") end
local function imageOn(part, faceId)
	for _, c in part:GetChildren() do
		if (c:IsA("Decal") and c.Face == faceId and c.Transparency < 1) or (c:IsA("SurfaceGui") and c.Face == faceId and c.Enabled) then return true end
	end
	return false
end
local FACES = {
	{ "X", 1, Enum.NormalId.Right }, { "X", -1, Enum.NormalId.Left }, { "Y", 1, Enum.NormalId.Top },
	{ "Y", -1, Enum.NormalId.Bottom }, { "Z", 1, Enum.NormalId.Back }, { "Z", -1, Enum.NormalId.Front },
}
local function overlap(f1, f2)
	local dc = f2.c - f1.c
	dc = dc - f1.n * dc:Dot(f1.n)
	for _, a in { f1.u, f1.v, f2.u, f2.v } do
		local r1 = f1.hu * math.abs(f1.u:Dot(a)) + f1.hv * math.abs(f1.v:Dot(a))
		local r2 = f2.hu * math.abs(f2.u:Dot(a)) + f2.hv * math.abs(f2.v:Dot(a))
		if r1 + r2 - math.abs(dc:Dot(a)) <= MIN_OVERLAP then return false end
	end
	return true
end
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

local backup, copies, movedOnce = nil, {}, {}
local function pass()
	local faces, buckets, count = {}, {}, 0
	for _, part in MAP:GetDescendants() do
		if part.ClassName == "Part" and part.Shape == Enum.PartType.Block and part.Transparency < 0.95 and part.Anchored then
			local cf, sz = part.CFrame, part.Size
			local ax = { X = cf.RightVector, Y = cf.UpVector, Z = -cf.LookVector }
			local half = { X = sz.X / 2, Y = sz.Y / 2, Z = sz.Z / 2 }
			for _, f in FACES do
				local n = ax[f[1]] * f[2]
				local o = {}
				for _, k in { "X", "Y", "Z" } do if k ~= f[1] then table.insert(o, k) end end
				local c = cf.Position + n * half[f[1]]
				local face = { part = part, n = n, c = c, d = n:Dot(c), faceId = f[3], u = ax[o[1]], hu = half[o[1]], v = ax[o[2]], hv = half[o[2]] }
				face.nk = ("%d,%d,%d"):format(math.round(n.X * 100) + 0, math.round(n.Y * 100) + 0, math.round(n.Z * 100) + 0)
				face.b = math.floor(face.d / MIN_GAP)
				local key = face.nk .. "|" .. face.b
				buckets[key] = buckets[key] or {}
				table.insert(buckets[key], face)
				table.insert(faces, face)
			end
			count += 1
			if count % 4000 == 0 then task.wait() end
		end
	end
	local plan, stats, notTouched, steps = {}, {}, {}, 0
	for _, f in faces do
		for _, kb in { f.b - 1, f.b } do -- g derrière f : g.d dans [f.d − MIN_GAP, f.d)
			for _, g in buckets[f.nk .. "|" .. kb] or {} do
				local gap = f.d - g.d
				if g.part ~= f.part and gap > 0.004 and gap < MIN_GAP - 0.001 and math.abs(f.n:Dot(g.n)) > 0.9999 then
					steps += 1
					if steps % 20000 == 0 then task.wait() end
					local pa, pb = f.part, g.part
					if (look(pa) ~= look(pb) or imageOn(pa, f.faceId) or imageOn(pb, g.faceId)) and overlap(f, g) and not hidden(f, pa, pb) then
						local z = zoneOf(pa)
						stats[z] = stats[z] or { pairs = 0, moved = 0, skipped = 0, kinds = {} }
						local s = stats[z]
						s.pairs += 1
						local need = MIN_GAP - gap
						local mover, dir
						if not excluded(pa) and not movedOnce[pa] then mover, dir = pa, f.n
						elseif not excluded(pb) and not movedOnce[pb] then mover, dir = pb, -f.n
						end
						if not mover then
							s.skipped += 1
							table.insert(notTouched, z .. " : " .. pa.Name .. " / " .. pb.Name)
						else
							local p = plan[mover]
							-- une seule demande par pièce et par passe : la plus grande
							if not p or p.need < need then
								if not p then s.moved += 1 end
								plan[mover] = { dir = dir, need = need, zone = z }
								local kind = (mover.Name:gsub("_?%-?%d+[A-Z]?$", "")) .. " / " .. ((mover == pa and pb or pa).Name:gsub("_?%-?%d+[A-Z]?$", ""))
								s.kinds[kind] = (s.kinds[kind] or 0) + 1
							end
						end
					end
				end
			end
		end
	end
	local n = 0
	if MODE == "fix" then
		for part, p in plan do
			-- une copie par pièce (plusieurs pièces ont souvent le même chemin : les fleurs d'un même buisson)
			local c = part:Clone()
			for _, t in CS:GetTags(c) do CS:RemoveTag(c, t) end
			c:SetAttribute("Path", part:GetFullName())
			c:SetAttribute("Shift", p.dir * p.need)
			c.Parent = backup
			copies[part] = c
			movedOnce[part] = true
			part.CFrame = part.CFrame + p.dir * p.need
			n += 1
			if n % 500 == 0 then task.wait() end
		end
	else
		for _ in plan do n += 1 end
	end
	return n, stats, notTouched, count
end

local rec
if MODE == "fix" then
	rec = CHS:TryBeginRecording("Écart minimum 0,03 dans la map", { allowNoUndo = true })
	local mb = game.ServerStorage.MapBackups
	local bname = os.date("%Y-%m-%d") .. "_ZFighting_Ecart"
	backup = mb:FindFirstChild(bname)
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = bname
		backup:SetAttribute("Note", "Pièces de Workspace/Map avant l'écart minimum de 0,03 entre faces superposées (27/11, tools/clement/zones/zfighting_ecart_map.luau). Path = chemin d'origine, Shift = déplacement total. Pour revenir : reculer chaque pièce de son Shift.")
		backup.Parent = mb
	end
end

local lines = {}
local first
for i = 1, (MODE == "fix") and PASSES or 1 do
	local n, stats, notTouched, count = pass()
	if i == 1 then first = { stats = stats, notTouched = notTouched, count = count } end
	table.insert(lines, ("passe %d : %d pièces éloignées"):format(i, n))
	if n == 0 then break end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
table.insert(lines, ("MODE %s, 1re passe sur %d blocs, par zone :"):format(MODE, first.count))
local zones = {}
for z in first.stats do table.insert(zones, z) end
table.sort(zones)
for _, z in zones do
	local s = first.stats[z]
	local kl = {}
	for k, v in s.kinds do table.insert(kl, { k, v }) end
	table.sort(kl, function(a, b) return a[2] > b[2] end)
	local top = {}
	for j = 1, math.min(6, #kl) do table.insert(top, kl[j][2] .. "× " .. kl[j][1]) end
	table.insert(lines, ("  %s : %d paires, %d pièces à éloigner, %d non touchées ; %s"):format(z, s.pairs, s.moved, s.skipped, table.concat(top, ", ")))
end
table.insert(lines, ("non touchées (%d) : %s"):format(#first.notTouched, table.concat(first.notTouched, " | "):sub(1, 1200)))
return table.concat(lines, "\n")
