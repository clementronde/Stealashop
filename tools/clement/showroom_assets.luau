--!nocheck
-- Vitrine des assets (_SHOWROOM_CLEMENT, L-032) : la complète avec tous les assets livrés (demande de Clément du
-- 2026-11-07), rangés par catégorie, une étiquette par objet, dans le style de la vitrine (socle Ped_, panneau Sign_).
--  - BASE ET BOUTIQUES (rangée des vigiles) : les 7 silhouettes « À VENIR » sont retirées ; le tapis et le banc
--    prennent leur place, sur un socle à leur taille comme les vigiles ;
--  - au nord, sur un sol prolongé (x -200..175, z 482..662), trois rangées, visiteurs au sud :
--      COMPTOIRS DU HUB (4 food trucks) et BILLBOARDS (BB_*) ;
--      ÉVÉNEMENT ET NUIT (camion intact, camion en vue éclatée, FX_BoxTrail, mur de nuit levé) et DÉCALS FX ;
--      BOUTIQUE DU JOUEUR (5 NIVEAUX) côte à côte, avec le tapis et le banc dedans.
-- Les silhouettes « À VENIR » des objets pas encore livrés restent.
-- Règle (Clément) : uniquement des copies nommées Show_…, sans aucun tag ni attribut, sans Humanoid, ProximityPrompt,
-- Highlight ni script : sinon le code et le ContractChecker (qui parcourt tout Workspace) les verraient en double.
-- Les originaux (ReplicatedStorage, map) ne bougent pas : le script ne fait que les copier.
-- À lancer dans Studio (MCP execute_luau, mode Edit). Relançable : il refait ses dossiers, son sol et ses socles.
-- Renvoie le compte rendu (ajouts, vérification de la vitrine, tags de Workspace avant et après).

local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local sr = workspace:FindFirstChild("_SHOWROOM_CLEMENT")
assert(sr, "_SHOWROOM_CLEMENT introuvable")
local A = RS:FindFirstChild("Assets")
assert(A, "ReplicatedStorage/Assets introuvable")
local COLIS = sr:FindFirstChild("COLIS")
local SIGN_T = COLIS and COLIS:FindFirstChild("Sign_COLIS")
local PED_T = COLIS and COLIS:FindFirstChild("Ped_BOX_Luxe")
assert(SIGN_T and PED_T and sr:FindFirstChild("Floor"), "modèles de la vitrine introuvables (Floor, COLIS/Sign_COLIS, COLIS/Ped_BOX_Luxe)")
local Y0 = sr.Floor.Position.Y + sr.Floor.Size.Y / 2 -- dessus du sol de la vitrine
local PED_Y = PED_T.Position.Y
local PED_TOP = PED_Y + PED_T.Size.Y / 2
local out, added = {}, {}

local TAGS = { "PlayerPlot", "Treadmill", "Bench", "CashPad", "WeaponShop", "AuraShop", "RobuxShop", "PawnShop",
	"NightWall", "NightPatrol", "NightLight", "SafeZone", "ZoneGate", "NPCStore" }
local function tagCounts()
	local t = {}
	for _, tag in TAGS do
		local n = 0
		for _, i in CS:GetTagged(tag) do
			if i:IsDescendantOf(workspace) then n += 1 end
		end
		t[tag] = n
	end
	return t
end
local before = tagCounts()

-- Copie de vitrine inerte : ni tag ni attribut, ni Humanoid, ProximityPrompt, détecteur, Highlight ni script ; tout ancré.
-- Les attributs RBX_… (RBX_ReimportId de l'importeur 3D) sont réservés au moteur : Studio refuse de les effacer, et le
-- contrat ne les lit pas.
local BANNED = { "Humanoid", "AnimationController", "ProximityPrompt", "ClickDetector", "DragDetector", "Highlight", "LuaSourceContainer" }
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

-- Boîte alignée sur les axes du monde (min, max) d'un modèle ou d'une pièce
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
-- Pose : orientation absolue yaw en degrés (nil = garde la sienne), centré en x, avant (côté visiteurs, -Z) sur
-- zFront, dessous sur bottom (défaut : le sol de la vitrine)
local function place(m, x, zFront, yaw, bottom)
	if yaw then m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, math.rad(yaw), 0)) end
	local mn, mx = aabb(m)
	moveBy(m, Vector3.new(x - (mn.X + mx.X) / 2, (bottom or Y0) - mn.Y, zFront - mn.Z))
	return m
end

-- Socle étiqueté (copie d'un socle de la vitrine) ; labelY = hauteur de l'étiquette au-dessus du centre du socle
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
-- Hauteur d'étiquette juste au-dessus d'un objet posé sur son socle (même écart que les vigiles)
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

-- Sol prolongé au nord (x -200..175, z 482..662), copie du sol de la vitrine
do
	local old = sr:FindFirstChild("Floor_Extension")
	if old then old:Destroy() end
	local f = sr.Floor:Clone()
	f.Name = "Floor_Extension"
	f:ClearAllChildren()
	f.Size = Vector3.new(375, sr.Floor.Size.Y, 180)
	f.CFrame = (sr.Floor.CFrame - sr.Floor.Position) + Vector3.new(-12.5, sr.Floor.Position.Y, 572)
	clean(f).Parent = sr
end

-- BASE ET BOUTIQUES : silhouettes « À VENIR » retirées, tapis et banc à leur place
do
	local base = sr:FindFirstChild("BASE ET BOUTIQUES")
	local removed = 0
	if base then
		for i = 1, 7 do
			local s = base:FindFirstChild("Show_" .. i)
			if s then s:Destroy(); removed += 1 end
		end
		for _, n in { "Ped_Tapis de course", "Ped_Banc de muscu", "Ped_Boutique d'armes", "Ped_Boutique d'auras",
			"Ped_Comptoir Robux", "Ped_Receleur", "Ped_Boutique du joueur", "Show_Treadmill", "Show_Bench" } do
			local o = base:FindFirstChild(n)
			if o then o:Destroy() end
		end
		local tpl = A:FindFirstChild("Plots") and A.Plots:FindFirstChild("PLOT_Shop")
		for _, it in { { "Treadmill", "Tapis de course", -180 }, { "Bench", "Banc de muscu", -170 } } do
			local src = tpl and tpl:FindFirstChild(it[1])
			if src then
				local c = copy(src, "Show_" .. it[1])
				local mn, mx = aabb(c)
				place(c, it[3], 430 - (mx.Z - mn.Z) / 2, nil, PED_TOP)
				c.Parent = base
				ped(base, it[2], it[3], 430, it[2], "LIVRÉ · MOD-016", labelOver(c), Vector3.new(mx.X - mn.X + 0.8, 0, mx.Z - mn.Z + 0.8))
				table.insert(added, c.Name)
			end
		end
	end
	table.insert(out, string.format("BASE ET BOUTIQUES : %d silhouettes « À VENIR » retirées avec leurs socles", removed))
end
task.wait()

-- COMPTOIRS DU HUB : les 4 food trucks, guichet vers les visiteurs
do
	local f = folder("COMPTOIRS DU HUB")
	sign(f, "COMPTOIRS DU HUB", -190, 486)
	local hub = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Hub")
	local trucks = hub and hub:FindFirstChild("Trucks")
	for i, t in { { "ENV_Hub_WeaponTruck", "Boutique d'armes" }, { "ENV_Hub_AuraTruck", "Boutique d'auras" },
		{ "ENV_Hub_RobuxTruck", "Comptoir Robux" }, { "ENV_Hub_PawnTruck", "Receleur" } } do
		local orig = trucks and trucks:FindFirstChild(t[1])
		if orig then
			local x = -160 + (i - 1) * 35
			local c = place(copy(orig, "Show_" .. t[1]), x, 498, 0) -- pivot = Counter, guichet vers -Z
			c.Parent = f
			ped(f, t[2], x, 494, t[2], "LIVRÉ · MOD-029")
			table.insert(added, c.Name)
		end
	end
end
task.wait()

-- BILLBOARDS (BB_*) : chacun sur un point d'accroche invisible, au-dessus de son socle
do
	local f = folder("BILLBOARDS (BB_*)")
	sign(f, "BILLBOARDS (BB_*)", -25, 486)
	local STATUS = { BB_WindowHP = "UI-001", BB_OpenTimer = "UI-001", BB_Item = "UI-001", BB_Carry = "UI-001",
		BB_Box = "L-031", BB_Upgrade = "L-041", BB_StoreInfo = "L-044" }
	local ui = A:FindFirstChild("UI")
	local list = {}
	for _, g in (ui and ui:GetChildren() or {}) do
		if g:IsA("BillboardGui") and g.Name:sub(1, 3) == "BB_" then table.insert(list, g) end
	end
	table.sort(list, function(a, b) return a.Name < b.Name end)
	for i, g in list do
		local x = -8 + (i - 1) * 17
		local anchor = Instance.new("Part")
		anchor.Name = "Show_" .. g.Name
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		-- le billboard garde son StudsOffset : l'accroche est placée pour qu'il flotte à 2,6 au-dessus du socle
		anchor.CFrame = CFrame.new(x, PED_TOP + 2.6 - g.StudsOffset.Y, 494)
		local c = g:Clone()
		c.Adornee = nil
		c.Enabled = true
		c.Parent = anchor
		clean(anchor).Parent = f
		ped(f, g.Name, x, 494, g.Name, "LIVRÉ · " .. (STATUS[g.Name] or "UI"), 6.6)
		table.insert(added, anchor.Name)
	end
end

-- ÉVÉNEMENT ET NUIT : camion intact et en vue éclatée, traînée des colis, mur de nuit levé
local wallFace = ""
do
	local f = folder("ÉVÉNEMENT ET NUIT")
	sign(f, "ÉVÉNEMENT ET NUIT", -190, 522)
	local ev = A:FindFirstChild("Events")
	local truck = ev and ev:FindFirstChild("ENV_Event_Truck")
	if truck then
		local a = place(copy(truck, "Show_ENV_Event_Truck"), -163, 534, 90) -- de profil
		a.Parent = f
		ped(f, "ENV_Event_Truck", -163, 530, "ENV_Event_Truck", "LIVRÉ · L-049")
		table.insert(added, a.Name)
		-- vue éclatée : chaque pièce de Pieces écartée du centre (+50 % à l'horizontale), boîte Root invisible retirée
		local b = copy(truck, "Show_ENV_Event_Truck_Pieces")
		local root = b:FindFirstChild("Root")
		if root and root:IsA("BasePart") and root.Transparency >= 0.99 then root:Destroy() end
		place(b, -112, 534, 90)
		local mn, mx = aabb(b)
		local c0 = (mn + mx) / 2
		local pieces = b:FindFirstChild("Pieces")
		for _, pc in (pieces and pieces:GetChildren() or {}) do
			if pc:IsA("PVInstance") then
				local ok, pmn, pmx = pcall(aabb, pc)
				if ok then
					local off = (pmn + pmx) / 2 - c0
					moveBy(pc, Vector3.new(off.X, 0, off.Z) * 0.5)
				end
			end
		end
		place(b, -112, 534, nil)
		b.Parent = f
		ped(f, "ENV_Event_Truck en pièces", -112, 530, "ENV_Event_Truck (en pièces)", "LIVRÉ · L-049")
		table.insert(added, b.Name)
	end
	local trail = ev and ev:FindFirstChild("FX_BoxTrail")
	if trail then
		local t = copy(trail, "Show_FX_BoxTrail")
		local mn, mx = aabb(t)
		place(t, -76, 530 - (mx.Z - mn.Z) / 2, nil, PED_TOP + 1)
		t.Parent = f
		ped(f, "FX_BoxTrail", -76, 530, "FX_BoxTrail", "LIVRÉ · L-049 (se voit en mouvement)", 3.6)
		table.insert(added, t.Name)
	end
	local entry = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Entry")
	local wall = entry and entry:FindFirstChild("NightWall")
	if wall then
		local w = place(copy(wall, "Show_NightWall"), -28, 534, -90) -- levé, face côté hub (-X) vers les visiteurs
		w.Parent = f
		ped(f, "NightWall", -28, 530, "NightWall (levé)", "LIVRÉ · MOD-032")
		table.insert(added, w.Name)
		for _, g in w:GetDescendants() do
			local part = g:IsA("SurfaceGui") and (g.Adornee or g.Parent)
			if part and part:IsA("BasePart") and part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(g.Face)).Z < -0.9 then
				local l = g:FindFirstChildWhichIsA("TextLabel", true)
				if l then wallFace = l.Text end
			end
		end
	end
end
task.wait()

-- DÉCALS FX : fissures de la vitre et paillette, chacune sur un panneau
do
	local f = folder("DÉCALS FX")
	sign(f, "DÉCALS FX", 25, 522)
	local fx = A:FindFirstChild("FX")
	for j, it in { { "WIN_Crack_75", "MOD-011" }, { "WIN_Crack_50", "MOD-011" }, { "WIN_Crack_25", "MOD-011" }, { "FX_GlassSparkle", "L-028" } } do
		local d = fx and fx:FindFirstChild(it[1])
		if d and d:IsA("Decal") then
			local x = 45 + (j - 1) * 14
			local panel = Instance.new("Part")
			panel.Name = "Show_" .. it[1]
			panel.Size = Vector3.new(6, 6, 0.4)
			panel.Material = Enum.Material.SmoothPlastic
			panel.Color = if it[1] == "FX_GlassSparkle" then Color3.fromRGB(30, 34, 44) else Color3.fromRGB(45, 70, 90)
			panel.CFrame = CFrame.new(x, PED_TOP + 3, 530)
			local dc = d:Clone()
			dc.Face = Enum.NormalId.Front -- vers les visiteurs
			dc.Parent = panel
			clean(panel).Parent = f
			ped(f, it[1], x, 530, it[1], "LIVRÉ · " .. it[2], labelOver(panel))
			table.insert(added, panel.Name)
		end
	end
end

-- BOUTIQUE DU JOUEUR (5 NIVEAUX) : le gabarit à chaque niveau, avant vers les visiteurs
do
	local f = folder("BOUTIQUE DU JOUEUR (5 NIVEAUX)")
	sign(f, "BOUTIQUE DU JOUEUR (5 NIVEAUX)", -190, 559)
	local tpl = A:FindFirstChild("Plots") and A.Plots:FindFirstChild("PLOT_Shop")
	-- noms des niveaux : doc, Partie 2, section 2 (repris par plot_shop_builder.luau)
	local LEVELS = { "Stand", "Boutique", "Magasin", "Concept store", "Flagship" }
	if tpl then
		-- toutes au même pivot en z (avant du gabarit complet sur z 572), comme les boutiques du hub
		local tcf, tsz = tpl:GetBoundingBox()
		local front = tpl:GetPivot():PointToObjectSpace(tcf.Position).Z - tsz.Z / 2
		for s = 1, 5 do
			local m = tpl:Clone()
			m.Name = "Show_PLOT_Shop_Niveau" .. s
			-- même règle que preview() de plot_shop_builder.luau : garde Stage_1..s, retire ce qui disparaît au niveau s
			for k = s + 1, 5 do
				local st = m:FindFirstChild("Stage_" .. k)
				if st then st:Destroy() end
			end
			for _, d in m:GetDescendants() do
				local h = d:GetAttribute("HideFromStage")
				if type(h) == "number" and h <= s and d.Parent then d:Destroy() end
			end
			clean(m)
			local x = -150 + (s - 1) * 72
			m:PivotTo(CFrame.new(x, Y0, 572 - front))
			m.Parent = f
			ped(f, "Boutique niveau " .. s, x, 567, "Boutique niveau " .. s .. " · " .. LEVELS[s], if s == 1 then "LIVRÉ · MOD-015" else "LIVRÉ · L-050")
			table.insert(added, m.Name)
			task.wait()
		end
	end
end

-- Les Highlight « OutlineHighlight » des copies déjà exposées (colis) partent aussi : ShelfBoxController suit tout
-- Highlight de ce nom dans Workspace (Config/ShelfBoxes, OutlineName), il les verrait en double.
do
	local n = 0
	for _, d in sr:GetDescendants() do
		if d:IsA("Highlight") and d.Name == "OutlineHighlight" then d:Destroy(); n += 1 end
	end
	if n > 0 then table.insert(out, string.format("Highlight OutlineHighlight retirés des copies déjà exposées : %d", n)) end
end

-- Vérification : rien dans la vitrine que le code ou le ContractChecker pourrait compter
do
	local NEW = { "COMPTOIRS DU HUB", "BILLBOARDS (BB_*)", "ÉVÉNEMENT ET NUIT", "DÉCALS FX", "BOUTIQUE DU JOUEUR (5 NIVEAUX)" }
	local tags, attrs, bad, scripts, hl = 0, 0, 0, 0, 0
	for _, d in sr:GetDescendants() do
		if #d:GetTags() > 0 then tags += 1 end
		for _, k in { "PlotIndex", "ItemId", "Zone", "Tier" } do
			if d:GetAttribute(k) ~= nil then attrs += 1 end
		end
		if d:IsA("Humanoid") or d:IsA("AnimationController") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector")
			or (d:IsA("SpawnLocation") and d.Enabled) then bad += 1 end
		if d:IsA("Highlight") then hl += 1 end
		if d:IsA("LuaSourceContainer") then scripts += 1 end
	end
	-- préfixes que le ContractChecker cherche partout (Contract/Models) : aucun dans les ajouts
	local prefixed, parts, anyAttr = {}, 0, 0
	local roots = {}
	for _, n in NEW do
		local f = sr:FindFirstChild(n)
		if f then table.insert(roots, f) end
	end
	local base = sr:FindFirstChild("BASE ET BOUTIQUES")
	for _, n in { "Show_Treadmill", "Show_Bench" } do
		local o = base and base:FindFirstChild(n)
		if o then table.insert(roots, o) end
	end
	for _, r in roots do
		for _, d in r:GetDescendants() do
			if d:IsA("BasePart") then parts += 1 end
			for k in d:GetAttributes() do
				if k:sub(1, 4) ~= "RBX_" then anyAttr += 1 end
			end
			if d:IsA("PVInstance") then
				for _, p in { "STORE_", "ITM_", "BOX_", "TOOL_", "ACC_" } do
					if d.Name:sub(1, #p) == p then table.insert(prefixed, d.Name) end
				end
			end
		end
	end
	local avenir = 0
	for _, d in sr:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "Status" and d.Text:find("VENIR") then avenir += 1 end
	end
	table.insert(out, string.format("Vitrine : tags %d, attributs du contrat %d, Humanoid/Prompt/Spawn actifs %d, Highlight %d, scripts %d ; ajouts : %d pièces, %d attributs, préfixes du contrat %s ; « À VENIR » restants %d",
		tags, attrs, bad, hl, scripts, parts, anyAttr, #prefixed > 0 and table.concat(prefixed, ", ") or "aucun", avenir))
	local after = tagCounts()
	local diff = {}
	for _, tag in TAGS do
		if before[tag] ~= after[tag] then table.insert(diff, string.format("%s %d -> %d", tag, before[tag], after[tag])) end
	end
	table.insert(out, "Tags de Workspace : " .. (#diff == 0 and "inchangés" or table.concat(diff, ", ")))
	if wallFace ~= "" then table.insert(out, "Mur de nuit, face vers les visiteurs : « " .. wallFace .. " »") end
end
table.insert(out, 1, "Ajouté (" .. #added .. ") : " .. table.concat(added, ", "))
return table.concat(out, "\n")
