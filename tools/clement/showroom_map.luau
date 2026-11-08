--!nocheck
-- Vitrine (_SHOWROOM_CLEMENT, L-032) : le décor de la map et les 12 magasins PNJ (demande de Clément du 2026-11-07 :
-- « ranger tous les assets de la map » = les exposer dans la vitrine). La map ne bouge pas.
-- Au nord des rangées de showroom_assets.luau, sur un sol à part (Floor_Map, à partir de z 662) :
--  - DÉCOR · <ZONE> : un exemplaire de chaque objet de décor de la zone (arbres, lampadaires, bancs, mobilier de rue,
--    véhicules, fontaines…), étiqueté avec son nombre dans la map. Deux objets identiques (mêmes pièces, même taille)
--    ne comptent qu'une fois. Les bâtiments (maisons, immeubles, terrasses, petites boutiques de façade) ne sont pas
--    repris, ni les comptoirs et boutiques du hub (déjà exposés plus au sud) ;
--  - MAGASINS PNJ : les 12 STORE_*, vitrine (Window) tournée vers les visiteurs, deux rangées de 6.
-- Même règle que showroom_assets.luau : copies Show_…, sans tag, attribut, Humanoid, ProximityPrompt, Highlight ni
-- script, noms à préfixe du contrat (STORE_, ITM_, BOX_, TOOL_, ACC_) renommés Show_… : ni le code ni le
-- ContractChecker ne les voient. Relançable (refait ses dossiers et son sol). Lancer après showroom_assets.luau.

local CS = game:GetService("CollectionService")
local sr = workspace:FindFirstChild("_SHOWROOM_CLEMENT")
assert(sr, "_SHOWROOM_CLEMENT introuvable")
local map = workspace:FindFirstChild("Map")
assert(map, "Workspace/Map introuvable")
local COLIS = sr:FindFirstChild("COLIS")
local SIGN_T = COLIS and COLIS:FindFirstChild("Sign_COLIS")
local PED_T = COLIS and COLIS:FindFirstChild("Ped_BOX_Luxe")
assert(SIGN_T and PED_T and sr:FindFirstChild("Floor"), "modèles de la vitrine introuvables (Floor, COLIS/Sign_COLIS, COLIS/Ped_BOX_Luxe)")
local Y0 = sr.Floor.Position.Y + sr.Floor.Size.Y / 2
local PED_Y = PED_T.Position.Y
local PED_TOP = PED_Y + PED_T.Size.Y / 2
local out, added = {}, {}

local Z_START, X_START, X_GAP, MAX_PROP = 672, -180, 6, 45
local ZONES = { { "Hub", "HUB" }, { "Zone_1", "ZONE 1" }, { "Zone_2", "ZONE 2 · LONDRES" }, { "Zone_3", "ZONE 3 · TOKYO" },
	{ "Zone_4", "ZONE 4 · LOS ANGELES" }, { "Zone_5", "ZONE 5 · PARIS" }, { "Zone_6", "ZONE 6 · NEW YORK" } }
-- bâtiments et ensembles qu'on n'ouvre pas ; dossiers ou grands modèles (> MAX_PROP) qu'on parcourt
local NO_DESCEND = { "STORE_", "PLOT_", "ENV_Hub_", "House", "Building_", "Facade", "Tenement", "Tower", "Shop_", "Terrace_",
	"Boutique", "Bungalow", "Apartment", "Parking", "BackRow", "Mansion", "Hotel", "SoundStage", "Shops", "Stalls", "Walls",
	"Ground", "SafeZone", "Spawn", "PlotSites", "RoofTree" }
local STORE_MOD = { STORE_Z1_Superette = "MOD-012", STORE_Z1_Kiosque = "MOD-018", Z2 = "MOD-020", Z3 = "MOD-021",
	Z4 = "MOD-022", Z5 = "MOD-023", Z6 = "MOD-024" }

-- Copie de vitrine inerte (même règle que showroom_assets.luau)
local BANNED = { "Humanoid", "AnimationController", "ProximityPrompt", "ClickDetector", "DragDetector", "Highlight", "LuaSourceContainer" }
local PREFIXES = { "STORE_", "ITM_", "BOX_", "TOOL_", "ACC_" }
local function clean(root)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in list do
		for _, t in d:GetTags() do d:RemoveTag(t) end
		for k in d:GetAttributes() do
			if k:sub(1, 4) ~= "RBX_" then d:SetAttribute(k, nil) end
		end
	end
	for _, d in list do
		if d ~= root and d.Parent then
			for _, c in BANNED do
				if d:IsA(c) then d:Destroy(); break end
			end
		end
	end
	for _, d in list do
		if d ~= root and d.Parent then
			for _, p in PREFIXES do
				if d.Name:sub(1, #p) == p then d.Name = "Show_" .. d.Name; break end
			end
		end
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = true end
		if d:IsA("SpawnLocation") then d.Enabled = false end
		if d:IsA("Sound") then d.Playing = false end
	end
	if root:IsA("BasePart") then root.Anchored = true end
	return root
end
local function copy(src, name)
	local c = src:Clone()
	c.Name = name
	return clean(c)
end
local function aabb(m)
	local cf, s
	if m:IsA("BasePart") then cf, s = m.CFrame, m.Size else cf, s = m:GetBoundingBox() end
	local h = Vector3.new(
		(math.abs(cf.XVector.X) * s.X + math.abs(cf.YVector.X) * s.Y + math.abs(cf.ZVector.X) * s.Z) / 2,
		(math.abs(cf.XVector.Y) * s.X + math.abs(cf.YVector.Y) * s.Y + math.abs(cf.ZVector.Y) * s.Z) / 2,
		(math.abs(cf.XVector.Z) * s.X + math.abs(cf.YVector.Z) * s.Y + math.abs(cf.ZVector.Z) * s.Z) / 2
	)
	return cf.Position - h, cf.Position + h
end
local function moveBy(m, d) m:PivotTo(m:GetPivot() + d) end
local function rotateBy(m, a)
	local pv = m:GetPivot()
	m:PivotTo(CFrame.new(pv.Position) * CFrame.Angles(0, a, 0) * (pv - pv.Position))
end
-- Pose : centré en x, avant (côté visiteurs, -Z) sur zFront, dessous sur bottom (défaut : le sol)
local function place(m, x, zFront, bottom)
	local mn, mx = aabb(m)
	moveBy(m, Vector3.new(x - (mn.X + mx.X) / 2, (bottom or Y0) - mn.Y, zFront - mn.Z))
	return m
end
local function ped(folder, name, x, z, title, status, labelY, size)
	local p = PED_T:Clone()
	p.Name = "Ped_" .. name
	if size then p.Size = Vector3.new(size.X, PED_T.Size.Y, size.Z) end
	p.CFrame = (PED_T.CFrame - PED_T.Position) + Vector3.new(x, PED_Y, z)
	local g = p:FindFirstChildWhichIsA("BillboardGui", true)
	if g then
		if labelY then g.StudsOffset = Vector3.new(0, labelY, 0) end
		local t = g:FindFirstChild("Title", true)
		if t then t.Text = title end
		local s = g:FindFirstChild("Status", true)
		if s then s.Text = status end
	end
	clean(p).Parent = folder
	return p
end
local function labelOver(m)
	local _, mx = aabb(m)
	return mx.Y - PED_Y + 0.9
end
local function sign(folder, text, x, z)
	local s = SIGN_T:Clone()
	s.Name = "Sign_" .. text
	s.CFrame = (SIGN_T.CFrame - SIGN_T.Position) + Vector3.new(x, SIGN_T.Position.Y, z)
	local l = s:FindFirstChildWhichIsA("TextLabel", true)
	if l then l.Text = text end
	clean(s).Parent = folder
end
local function folder(name)
	local old = sr:FindFirstChild(name)
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = sr
	return f
end
local function startsWithAny(n, list)
	for _, p in list do if n:find(p, 1, true) then return true end end
	return false
end

-- Inventaire d'une zone : modèles « objets » (<= MAX_PROP studs), un par famille : même nom de base (palmiers de
-- hauteurs différentes…) ou même forme exacte quel que soit le nom ou l'orientation (bancs de la fontaine…)
local function norm(n)
	return (n:gsub("_%d+$", ""):gsub("_%u%d+$", ""):gsub("%d+$", ""):gsub("_[NSEWLR]$", ""))
end
local function shapeSig(c)
	local list = {}
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			local s = { math.floor(d.Size.X * 2 + 0.5), math.floor(d.Size.Y * 2 + 0.5), math.floor(d.Size.Z * 2 + 0.5) }
			table.sort(s)
			table.insert(list, table.concat(s, ","))
		end
	end
	table.sort(list)
	return #list, table.concat(list, ";")
end
local function inventory(zone)
	local byName, byShape, order = {}, {}, {}
	local function walk(inst)
		for _, c in inst:GetChildren() do
			-- les noms de bâtiment ne valent que pour des modèles (le dossier « Buildings » de Londres contient des arbres)
			if c:IsA("Folder") or (c:IsA("Model") and not startsWithAny(c.Name, NO_DESCEND)) then
				local size
				if c:IsA("Model") then
					local ok, _, s = pcall(function() return c:GetBoundingBox() end)
					size = ok and s or nil
				end
				if c:IsA("Model") and size and math.max(size.X, size.Y, size.Z) <= MAX_PROP then
					local n, shape = shapeSig(c)
					local name = norm(c.Name)
					local e = byName[name] or byShape[shape]
					if e then
						e.count += 1
						byName[name] = e
						byShape[shape] = e
					elseif n > 0 then
						e = { name = name, inst = c, count = 1 }
						byName[name] = e
						byShape[shape] = e
						table.insert(order, e)
					end
				else
					walk(c)
				end
			end
		end
	end
	walk(zone)
	table.sort(order, function(a, b) return a.name < b.name end)
	return order
end

-- Place libre au nord ? (rien d'autre que la vitrine)
do
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { sr, workspace.Terrain }
	local hits = workspace:GetPartBoundsInBox(CFrame.new(70, 30, 920), Vector3.new(560, 70, 500), op)
	if #hits > 0 then
		local a = hits[1]
		while a.Parent ~= workspace do a = a.Parent end
		error("place occupée au nord de la vitrine (x -210..350, z 670..1170) : " .. #hits .. " pièces, dont " .. a.Name)
	end
end

-- Rangées du décor, zone par zone
local z = Z_START
local maxX = 0
for _, zinfo in ZONES do
	local zone = map:FindFirstChild(zinfo[1])
	local fname = "DÉCOR · " .. zinfo[2]
	if not zone then
		local old = sr:FindFirstChild(fname)
		if old then old:Destroy() end
		continue
	end
	local f = folder(fname)
	sign(f, fname, -190, z)
	local pedZ = z + 8
	local x = X_START
	local back = pedZ + 2
	for _, e in inventory(zone) do
		local c = copy(e.inst, "Show_" .. zinfo[1] .. "_" .. e.name)
		local mn, mx = aabb(c)
		if (mx.Z - mn.Z) > (mx.X - mn.X) * 1.25 then rotateBy(c, math.rad(90)); mn, mx = aabb(c) end
		local w, d, h = mx.X - mn.X, mx.Z - mn.Z, mx.Y - mn.Y
		local small = h <= 6 and math.max(w, d) <= 4
		local slot = math.max(w, 3.4)
		local cx = x + slot / 2
		local status = "DANS LA MAP · ×" .. e.count
		if small then
			place(c, cx, pedZ - d / 2, PED_TOP)
			c.Parent = f
			ped(f, zinfo[1] .. "_" .. e.name, cx, pedZ, e.name, status, labelOver(c))
		else
			place(c, cx, pedZ + 3)
			c.Parent = f
			ped(f, zinfo[1] .. "_" .. e.name, cx, pedZ, e.name, status)
			back = math.max(back, pedZ + 3 + d)
		end
		table.insert(added, c.Name)
		x += slot + X_GAP
		maxX = math.max(maxX, x)
	end
	z = back + 10
	task.wait()
end

-- Magasins PNJ : vitrine vers les visiteurs, deux rangées de 6
do
	local f = folder("MAGASINS PNJ")
	sign(f, "MAGASINS PNJ", -190, z)
	local stores = {}
	for _, d in map:GetDescendants() do
		if d:IsA("Model") and d.Name:match("^STORE_Z%d_") then table.insert(stores, d) end
	end
	table.sort(stores, function(a, b) return a.Name < b.Name end)
	local pedZ = z + 8
	local x = X_START
	local back = pedZ
	for i, s in stores do
		if i == 7 then
			z = back + 12
			pedZ = z + 4
			x = X_START
		end
		local c = copy(s, "Show_" .. s.Name)
		local win = s:FindFirstChild("Window", true)
		if win and win:IsA("BasePart") then
			local cf = s:GetBoundingBox()
			local dir = win.Position - cf.Position
			rotateBy(c, math.pi - math.atan2(dir.X, dir.Z)) -- vitrine vers -Z
		end
		local mn, mx = aabb(c)
		local w, d = mx.X - mn.X, mx.Z - mn.Z
		local cx = x + w / 2
		place(c, cx, pedZ + 3)
		c.Parent = f
		local zoneKey = s.Name:match("^STORE_(Z%d)_")
		ped(f, s.Name, cx, pedZ, s.Name, "LIVRÉ · " .. (STORE_MOD[s.Name] or STORE_MOD[zoneKey] or "MOD-0xx"))
		table.insert(added, c.Name)
		back = math.max(back, pedZ + 3 + d)
		x += w + 10
		maxX = math.max(maxX, x)
		task.wait()
	end
	z = back + 10
end

-- Sol sous tout ça, copie du sol de la vitrine
do
	local old = sr:FindFirstChild("Floor_Map")
	if old then old:Destroy() end
	local f = sr.Floor:Clone()
	f.Name = "Floor_Map"
	f:ClearAllChildren()
	local x0, x1, z0 = -200, math.max(maxX + 8, 175), 662
	f.Size = Vector3.new(x1 - x0, sr.Floor.Size.Y, z - z0)
	f.CFrame = (sr.Floor.CFrame - sr.Floor.Position) + Vector3.new((x0 + x1) / 2, sr.Floor.Position.Y, (z0 + z) / 2)
	clean(f).Parent = sr
	table.insert(out, string.format("Sol Floor_Map : x %d..%d, z %d..%d", x0, math.floor(x1), z0, math.floor(z)))
end

-- Vérification : rien dans la vitrine que le code ou le ContractChecker pourrait compter
do
	local tags, attrs, bad, scripts, prefixed, parts = 0, 0, 0, 0, 0, 0
	for _, d in sr:GetDescendants() do
		if #d:GetTags() > 0 then tags += 1 end
		for _, k in { "PlotIndex", "ItemId", "Zone", "Tier" } do
			if d:GetAttribute(k) ~= nil then attrs += 1 end
		end
		if d:IsA("Humanoid") or d:IsA("AnimationController") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector")
			or d:IsA("Highlight") or (d:IsA("SpawnLocation") and d.Enabled) then bad += 1 end
		if d:IsA("LuaSourceContainer") then scripts += 1 end
		if (d:IsA("PVInstance") or d:IsA("Accessory")) and startsWithAny(d.Name:sub(1, 6), PREFIXES) and d.Name:sub(1, 5) ~= "Show_" then prefixed += 1 end
		if d:IsA("BasePart") then parts += 1 end
	end
	table.insert(out, string.format("Vitrine : %d pièces ; tags %d, attributs du contrat %d, Humanoid/Prompt/Highlight %d, scripts %d, préfixes du contrat %d",
		parts, tags, attrs, bad, scripts, prefixed))
end
table.insert(out, 1, "Ajouté (" .. #added .. ") : " .. table.concat(added, ", "))
return table.concat(out, "\n")
