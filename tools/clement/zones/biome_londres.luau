--!nocheck
-- Biome Londres sous la pluie, 3e zone (fiche du chef DA : da-fiche-z2-londres.md, planche
-- StealAShop-Art/Captures/2026-11-28_biomes/Z2.jpg ; même méthode que biome_tokyo.luau et biome_losangeles.luau).
-- Tout en pièces, dans Studio, en Edit. Ne touche jamais : STORE_Z2_* (façades, intérieurs, contrat), Greybox/…/ZoneGate_2,
-- NightPatrol_Z2_*, TruckSpawn, points de ronde, témoins. Couloir |z| < 46,5 : rien que du plat sans collision sous
-- 17 studs (marquages, flaques) ; l'arche d'entrée commence à 26 studs.
-- Relançable : recolorations absolues, hauteurs des maisons rejouées depuis leurs attributs BaseY / BaseSizeY,
-- dossier Street_Londres/Biome refait ; les pièces rangées le sont une fois. Attention : zone2_londres.luau refait
-- Street_Londres entier ; le relancer efface ce biome (le relancer ensuite).
--   1. sol : chaussée Greybox #3b3f48 Reflectance 0,15, trottoirs et dalles #6e6a64, bordures de granit #8a8f96,
--      passages et tirets #e8e6e0, zigzags jaunes #f2c14e, flaques en Glass #2b3038 (les 11 anciennes et 10 de plus,
--      plus grandes), murets en brique #8a3a2e (chaperon de pierre #c9c2b0 et grilles noires seulement là où rien ne
--      les cache : le 28/11, les 4 murets sont pris dans les tours d'horloge et les maisons, donc aucun),
--      liseré de granit à x = 118,9 (coupure nette, pas de marche de 0,4 : décision prise à Tokyo) ;
--   2. grande tour d'horloge de 170 studs en x 175, z 203 (derrière Mansion_3, ×1,6 pour se voir de la rue) : pierre miel #c9a86a, 4 cadrans
--      éclairés (Neon faible + PointLight), flèche d'ardoise #5b6470 et pointe dorée ; la grande roue reçoit des
--      lumières blanches sur ses 32 nacelles ;
--   3. les 16 maisons Terrace : brique rouge, jaune ou stuc blanc, porte de couleur, baie au premier étage, grille
--      noire, 3e cheminée, hauteurs de −4 à +4 ; toits en ardoise #5b6470 ; les 5 maisons de maître en brique et stuc
--      #ece6d7 avec une cheminée de plus ; House_N3, S3, S4 dans la palette ;
--   4. 10 lampes à gaz (les 6 en place et 4 copies en x 155 et 180), flamme Neon #f2c14e, PointLight chaude de
--      portée 14 ; abribus (toit de verre, banc, panneau rouge) à la place de Props/BusStop ; Props/PostBox rangée
--      (boîtes aux lettres voxel du chef 3D) ; arbres en vert mouillé #3d6b45 ; pluie plus franche (gouttes plus
--      longues, +20 %) ; brouillard bas gris-vert (≈ 20 particules) ;
--   5. arche de briques en 3 tons sur mortier entre les deux petites tours d'horloge (dessous de 26 à 34 studs),
--      claveaux et clé de voûte en pierre miel, 4 lanternes à gaz ;
--   6. places marquées pour le chef 3D (Biome/Places_Chef3D) : 4 boîtes aux lettres, 2 taxis, 6 parapluies ;
--   7. enseignes sans « slop » (da-enseignes-sans-slop.md) : SWEETS et TOYS dans la police du chef DA (SignLetters sous les SignPart), pictos sucette, ours et
--      tour d'horloge, faux textes retirés. Charger d'abord tools/clement/zones/lettres_voxel.luau.
-- Avant : sauvegarde ServerStorage/MapBackups/<date>_Biome_Londres (Street_Londres, sol du Greybox).
-- À lancer dans Studio (MCP execute_luau, Edit, hors Play).

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local rgb = Color3.fromHex
local Z2 = workspace.Map.Zone_2
local SL = Z2.Street_Londres
local GB = workspace.Greybox.Corridor.Zone_2.Ground
local backup
for _, f in game.ServerStorage.MapBackups:GetChildren() do
	if f.Name:match("_Biome_Londres$") and (not backup or f.Name > backup.Name) then backup = f end
end
assert(backup, "faire la sauvegarde avant (MapBackups/<date>_Biome_Londres)")

local C = {
	cobble = rgb("3b3f48"), slab = rgb("6e6a64"), granite = rgb("8a8f96"), mark = rgb("e8e6e0"), zigzag = rgb("f2c14e"),
	puddle = rgb("2b3038"), wallBrick = rgb("8a3a2e"), coping = rgb("c9c2b0"), iron = rgb("19191e"),
	brick = rgb("a4372d"), yellowBrick = rgb("c9a86a"), stucco = rgb("ece6d7"), slate = rgb("5b6470"), gold = rgb("d4af37"),
	dial = rgb("f7ecc8"), dialLight = rgb("ffe8a8"), stoneLight = rgb("dcc48e"), stoneDark = rgb("b8975a"),
	glassDark = rgb("2e3a50"), chimney = rgb("963e30"), pot = rgb("be5f3c"), flame = rgb("f2c14e"), warm = rgb("ffc46b"),
	leaf = rgb("3d6b45"), red = rgb("d62828"), fog = rgb("aab4b0"), white = rgb("f5f5f0"), roofGlass = rgb("a9c4cc"),
}
local DOORS = { rgb("1f4d3a"), rgb("d62828"), rgb("2e3a50"), rgb("f2c14e") }
local BRICKS = { C.brick, C.yellowBrick, C.stucco }

local rec = CHS:TryBeginRecording("Biome Londres", { allowNoUndo = true })
local old = SL:FindFirstChild("Biome")
if old then old:Destroy() end
local B = Instance.new("Folder")
B.Name = "Biome"
B.Parent = SL
local function folder(name, parent) local f = Instance.new("Folder") f.Name = name f.Parent = parent or B return f end
local function part(parent, name, size, cf, color, mat, opts)
	opts = opts or {}
	local p = Instance.new(opts.wedge and "WedgePart" or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.cyl then p.Shape = Enum.PartType.Cylinder end
	if opts.ball then p.Shape = Enum.PartType.Ball end
	p.CanCollide = opts.collide == true
	p.CanTouch = false
	p.CanQuery = opts.collide == true
	p.CastShadow = opts.shadow ~= false and mat ~= Enum.Material.Neon
	if opts.transp then p.Transparency = opts.transp end
	if opts.refl then p.Reflectance = opts.refl end
	p.Parent = parent
	return p
end
local function light(p, range, color, bright)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Color = color
	l.Brightness = bright or 1
	l.Shadows = false
	l.Parent = p
	return l
end
local function stash(inst)
	for _, d in inst:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
	for _, t in CS:GetTags(inst) do CS:RemoveTag(inst, t) end
	inst.Parent = backup
end
local nPaint = 0
local function paint(p, color, mat, refl)
	if not p:IsA("BasePart") or CS:HasTag(p, "NightLight") then return end
	p.Color = color
	if mat then p.Material = mat end
	if refl then p.Reflectance = refl end
	nPaint += 1
end
local function gui(p, face, text, color, font)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.TextWrapped = true
	t.Font = font or Enum.Font.GothamBold
	t.TextColor3 = color
	t.Parent = g
	return g
end
-- rien de la rue (hors biome) dans cette boîte ? (pour les chaperons cachés dans les tours d'horloge)
local function boxFree(cf, size, ignore)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { B, ignore }
	for _, h in workspace:GetPartBoundsInBox(cf, size, op) do
		if h.Transparency < 1 and (h:IsDescendantOf(SL) or h:IsDescendantOf(Z2)) then return false end
	end
	return true
end

---------------------------------------------------------------- 1. sol
local street = GB:FindFirstChild("Street")
if street then street.Color = C.cobble street.Material = Enum.Material.Plastic street.Reflectance = 0.15 end
for _, n in { "Side_N", "Side_S" } do local p = GB:FindFirstChild(n) if p then p.Color = C.slab p.Material = Enum.Material.Plastic end end
for _, p in SL.Ground:GetChildren() do
	if p:IsA("BasePart") then
		local n = p.Name
		if n:match("^Pavement") then paint(p, C.slab, Enum.Material.Plastic)
		elseif n:match("^Kerb") then paint(p, C.granite, Enum.Material.Plastic)
		elseif n:match("^Zebra") or n:match("^CentreDash") then paint(p, C.mark)
		elseif n:match("^ZigZag") then paint(p, C.zigzag)
		end -- Puddle_* : rangées par sol_passe.luau
	end
end
local F = folder("Sol")
part(F, "Seuil_Granit", Vector3.new(0.8, 0.05, 91), CFrame.new(118.9, 0.055, 0), C.granite, Enum.Material.Plastic)
-- les flaques sont posées par sol_passe.luau (fiche sol du chef DA, 28/11) : plus de disques ici
-- murets : brique, chaperon de pierre, grilles noires (sauf là où une tour d'horloge les cache)
local nWalls = 0
for _, n in { "SideWall_N1", "SideWall_N2", "SideWall_S1", "SideWall_S2" } do
	local w = GB:FindFirstChild(n)
	if w then
		w.Color = C.wallBrick
		w.Material = Enum.Material.Plastic
		local top = w.Position.Y + w.Size.Y / 2
		local ccf = CFrame.new(w.Position.X, top + 0.3, w.Position.Z)
		local csz = Vector3.new(w.Size.X + 0.3, 0.6, w.Size.Z + 0.3)
		if boxFree(ccf, csz + Vector3.new(0, 2, 0), w) then
			nWalls += 1
			local M = folder("Muret_" .. n)
			part(M, "Chaperon", csz, ccf, C.coping, Enum.Material.Plastic)
			local L = w.Size.X
			for k = 0, math.floor(L) - 1 do
				part(M, "Barreau", Vector3.new(0.15, 1.1, 0.15), CFrame.new(w.Position.X - L / 2 + 0.5 + k, top + 0.6 + 0.55, w.Position.Z), C.iron, Enum.Material.Plastic)
			end
			part(M, "Lisse", Vector3.new(L - 0.4, 0.15, 0.2), CFrame.new(w.Position.X, top + 0.6 + 1.1, w.Position.Z), C.iron, Enum.Material.Plastic)
		end
	end
end

---------------------------------------------------------------- 2. grande tour d'horloge, grande roue
local T = Instance.new("Model")
T.Name = "GrandeTourHorloge"
T.Parent = B
do
	local X, Zc = 175, 215
	part(T, "Parvis", Vector3.new(44, 1, 34), CFrame.new(X, -0.5, 220), C.slab, Enum.Material.Plastic, { collide = true })
	part(T, "Socle", Vector3.new(22, 4, 22), CFrame.new(X, 2, Zc), C.stoneDark, Enum.Material.Plastic, { collide = true })
	part(T, "Fut", Vector3.new(18, 62, 18), CFrame.new(X, 35, Zc), C.yellowBrick, Enum.Material.Plastic, { collide = true })
	for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
		part(T, "Pilastre", Vector3.new(2.4, 62, 2.4), CFrame.new(X + sx * 8.1, 35, Zc + sz * 8.1), C.stoneLight, Enum.Material.Plastic)
	end end
	for _, y in { 19, 34, 49 } do part(T, "Bandeau", Vector3.new(18.4, 0.6, 18.4), CFrame.new(X, y, Zc), C.stoneLight, Enum.Material.Plastic) end
	local faces = { { Vector3.new(0, 0, -1), 0 }, { Vector3.new(0, 0, 1), math.pi }, { Vector3.new(-1, 0, 0), -math.pi / 2 }, { Vector3.new(1, 0, 0), math.pi / 2 } }
	for _, f in faces do
		local nrm, yaw = f[1], f[2]
		for _, y in { 26, 41, 56 } do for _, o in { -2.5, 2.5 } do
			local side = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(o, 0, 0))
			part(T, "Meurtriere", Vector3.new(1.4, 7, 0.2), CFrame.new(Vector3.new(X, y, Zc) + nrm * 9.05 + side) * CFrame.Angles(0, yaw, 0), C.glassDark, Enum.Material.SmoothPlastic)
		end end
	end
	part(T, "EtageHorloge", Vector3.new(20, 16, 20), CFrame.new(X, 74, Zc), C.yellowBrick, Enum.Material.Plastic, { collide = true })
	for _, f in faces do
		local nrm, yaw = f[1], f[2]
		local c = Vector3.new(X, 74, Zc)
		local rot = CFrame.lookAt(c, c + nrm) -- LookVector vers l'extérieur
		local axis = CFrame.lookAt(Vector3.zero, nrm) * CFrame.Angles(0, math.pi / 2, 0) -- axe du cylindre (X) le long de nrm
		part(T, "Anneau", Vector3.new(0.3, 13.2, 13.2), CFrame.new(c + nrm * 10.15) * axis, C.gold, Enum.Material.Plastic, { cyl = true })
		local dial = part(T, "Cadran", Vector3.new(0.4, 12, 12), CFrame.new(c + nrm * 10.2) * axis, C.dial, Enum.Material.Neon, { cyl = true })
		light(dial, 20, C.dialLight, 1.2)
		for h = 0, 11 do
			local a = h * math.pi / 6
			local p = rot * CFrame.new(math.sin(a) * 5.3, math.cos(a) * 5.3, -10.45) * CFrame.Angles(0, 0, -a)
			part(T, "Graduation", Vector3.new(0.35, h % 3 == 0 and 1.4 or 0.8, 0.1), p, C.iron, Enum.Material.SmoothPlastic)
		end
		-- 10 h 10
		local ah, am = -math.rad(300), -math.rad(60)
		part(T, "PetiteAiguille", Vector3.new(0.55, 3.4, 0.1), rot * CFrame.new(0, 0, -10.5) * CFrame.Angles(0, 0, ah) * CFrame.new(0, 1.5, 0), C.iron, Enum.Material.SmoothPlastic)
		part(T, "GrandeAiguille", Vector3.new(0.4, 4.4, 0.1), rot * CFrame.new(0, 0, -10.55) * CFrame.Angles(0, 0, am) * CFrame.new(0, 2.0, 0), C.iron, Enum.Material.SmoothPlastic)
		part(T, "Axe", Vector3.new(0.2, 0.9, 0.9), CFrame.new(c + nrm * 10.6) * axis, C.gold, Enum.Material.SmoothPlastic, { cyl = true })
	end
	part(T, "Corniche", Vector3.new(22, 1.5, 22), CFrame.new(X, 82.75, Zc), C.stoneLight, Enum.Material.Plastic)
	part(T, "Beffroi", Vector3.new(14, 6, 14), CFrame.new(X, 86.5, Zc), C.yellowBrick, Enum.Material.Plastic)
	for _, f in faces do
		for _, o in { -3, 0, 3 } do
			local side = CFrame.Angles(0, f[2], 0):VectorToWorldSpace(Vector3.new(o, 0, 0))
			part(T, "Baie", Vector3.new(1.6, 3.6, 0.2), CFrame.new(Vector3.new(X, 86.8, Zc) + f[1] * 7.05 + side) * CFrame.Angles(0, f[2], 0), C.iron, Enum.Material.SmoothPlastic)
		end
	end
	part(T, "BaseFleche", Vector3.new(15, 1, 15), CFrame.new(X, 90, Zc), C.slate, Enum.Material.Plastic)
	local y = 90.5
	for _, w in { 12, 10, 8, 6, 4, 2.5 } do
		part(T, "Fleche", Vector3.new(w, 2.1, w), CFrame.new(X, y + 1.05, Zc), C.slate, Enum.Material.Plastic)
		y += 2.1
	end
	part(T, "Pointe", Vector3.new(0.8, 3, 0.8), CFrame.new(X, y + 1.5, Zc), C.gold, Enum.Material.Plastic)
	part(T, "Boule", Vector3.new(1.3, 1.3, 1.3), CFrame.new(X, y + 0.4, Zc), C.gold, Enum.Material.Plastic, { ball = true })
	for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
		part(T, "Clocheton", Vector3.new(2, 5, 2), CFrame.new(X + sx * 10, 86, Zc + sz * 10), C.slate, Enum.Material.Plastic)
		part(T, "ClochetonPointe", Vector3.new(0.5, 1.2, 0.5), CFrame.new(X + sx * 10, 89.1, Zc + sz * 10), C.gold, Enum.Material.Plastic)
	end end
end
-- 28/11 (Chef de projet : « un monument qu'on ne voit pas ne sert à rien ») : la tour de 106 était cachée par la façade
-- haute du Magasin de jouets (36,6 à |z| 53). Mesuré par rayons depuis 8 points du milieu de la rue (x 128 à 226, z 0,
-- à 6 de haut) : à ×1,6 (170 studs, base de 35) en z 203, cadrans et flèche se voient des 8 points (à ×1,27, 135 studs,
-- seule la flèche, d'un point). Proportions gardées (ScaleTo), parvis refait, portée des cadrans reprise (ScaleTo ne
-- l'agrandit pas) ; Tree_N3 et Tree_N4, sous la base, rangés dans la sauvegarde.
do
	local parvis = T.Parvis
	parvis.Parent = B
	T.WorldPivot = CFrame.new(175, 0, 215)
	T:ScaleTo(1.6)
	T:PivotTo(CFrame.new(175, 0, 203))
	parvis.Size = Vector3.new(56, 1, 35)
	parvis.CFrame = CFrame.new(175, -0.5, 217.5)
	parvis.Parent = T
	for _, l in T:GetDescendants() do if l:IsA("PointLight") then l.Range = 32 end end
	for _, n in { "Tree_N3", "Tree_N4" } do local t = SL.Buildings:FindFirstChild(n) if t then stash(t) end end
end
do
	local WF = folder("GrandeRoue_Lumieres")
	for _, cap in SL.ObservationWheel:GetDescendants() do
		if cap:IsA("BasePart") and cap.Name:match("^Capsule_?%d*$") then
			part(WF, "Lumiere", Vector3.new(0.6, 0.6, 0.6), CFrame.new(cap.Position + Vector3.new(0, cap.Size.Y / 2 + 0.35, 0)), C.white, Enum.Material.Neon)
		end
	end
end

---------------------------------------------------------------- 3. maisons
local function regrow(m, dh)
	local body = m:FindFirstChild("Body")
	if not body then return end
	if not body:GetAttribute("BaseSizeY") then
		body:SetAttribute("BaseSizeY", body.Size.Y)
		for _, p in m:GetDescendants() do if p:IsA("BasePart") then p:SetAttribute("BaseY", p.Position.Y) end end
	end
	local h0 = body:GetAttribute("BaseSizeY")
	local top0 = body:GetAttribute("BaseY") + h0 / 2
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local y0 = p:GetAttribute("BaseY") or p.Position.Y
			if p == body then
				p.Size = Vector3.new(p.Size.X, h0 + dh, p.Size.Z)
				p.CFrame = p.CFrame - p.Position + Vector3.new(p.Position.X, y0 + dh / 2, p.Position.Z)
			elseif y0 > top0 - 1.5 then
				p.CFrame = p.CFrame - p.Position + Vector3.new(p.Position.X, y0 + dh, p.Position.Z)
			else
				p.CFrame = p.CFrame - p.Position + Vector3.new(p.Position.X, y0, p.Position.Z)
			end
		end
	end
end
local HF = folder("Maisons")
-- place de la cheminée ajoutée : le point du toit le plus loin des cheminées existantes (Chimney_*)
local function chimneyOffset(m, body)
	local ex = {}
	for _, p in m:GetChildren() do if p:IsA("BasePart") and p.Name:match("^Chimney_") then table.insert(ex, p.Position) end end
	local cands = { Vector3.zero, Vector3.new(0, 0, body.Size.Z / 4), Vector3.new(0, 0, -body.Size.Z / 4), Vector3.new(body.Size.X / 4, 0, 0), Vector3.new(-body.Size.X / 4, 0, 0) }
	local best, bd = Vector3.zero, -1
	for _, c in cands do
		local d = math.huge
		for _, e in ex do d = math.min(d, (Vector3.new(e.X - body.Position.X, 0, e.Z - body.Position.Z) - c).Magnitude) end
		if d > bd then bd, best = d, c end
	end
	return best
end
local terr = {}
for _, m in SL.Buildings:GetChildren() do if m.Name:match("^Terrace_") then table.insert(terr, m) end end
table.sort(terr, function(a, b) return a.Name < b.Name end)
local DH = { 4, -2, 2, -4, 0, 3, -3, 1 }
for i, m in ipairs(terr) do
	regrow(m, DH[(i - 1) % #DH + 1])
	local body = m.Body
	local bc = BRICKS[(i - 1) % 3 + 1]
	paint(body, bc, Enum.Material.Plastic)
	for _, p in m:GetChildren() do
		if p.Name == "Roof" then paint(p, C.slate, Enum.Material.Plastic)
		elseif p.Name == "Cornice" then paint(p, bc == C.stucco and C.coping or C.stucco) end
	end
	-- façade : côté extérieur de la rangée (ouest pour NW/SW, est pour NE/SE)
	local sx = m.Name:match("_[NS]W") and -1 or 1
	local fx = body.Position.X + sx * (body.Size.X / 2)
	local cz, w = body.Position.Z, body.Size.Z
	local yb = body.Position.Y - body.Size.Y / 2
	local M = folder(m.Name, HF)
	local yaw = sx > 0 and math.pi / 2 or -math.pi / 2
	local function onFace(dz, y, out) return CFrame.new(fx + sx * out, y, cz + dz) * CFrame.Angles(0, yaw, 0) end
	local door = DOORS[(i - 1) % #DOORS + 1]
	part(M, "Porte", Vector3.new(2.4, 4.6, 0.2), onFace(-w / 4, yb + 2.3, 0.1), door, Enum.Material.Plastic)
	part(M, "Imposte", Vector3.new(2.4, 0.8, 0.2), onFace(-w / 4, yb + 5.1, 0.1), C.glassDark, Enum.Material.SmoothPlastic)
	part(M, "Encadrement", Vector3.new(3.2, 0.5, 0.3), onFace(-w / 4, yb + 5.75, 0.15), C.stucco, Enum.Material.Plastic)
	local bw = math.min(6, w * 0.4)
	part(M, "Baie", Vector3.new(bw, 4.2, 1.2), onFace(w / 6, yb + 9.5, 0.6), bc == C.stucco and C.coping or C.stucco, Enum.Material.Plastic)
	part(M, "BaieVitre", Vector3.new(bw - 0.8, 3.2, 0.2), onFace(w / 6, yb + 9.5, 1.25), C.glassDark, Enum.Material.SmoothPlastic)
	part(M, "BaieToit", Vector3.new(bw + 0.4, 0.4, 1.6), onFace(w / 6, yb + 11.8, 0.8), C.slate, Enum.Material.Plastic)
	-- barreaux de grille retirés le 28/11 (budget de 4 500 pièces ; presque invisibles depuis la rue) : la lisse reste
	part(M, "GrilleLisse", Vector3.new(w - 1.6, 0.15, 0.2), onFace(0, yb + 2.6, 1.4), C.iron, Enum.Material.Plastic)
	-- 3e cheminée au milieu du toit, avec ses pots
	local roof = m:FindFirstChild("Roof")
	if roof then
		local rt = roof.Position.Y + roof.Size.Y / 2
		local off = chimneyOffset(m, body)
		part(M, "Cheminee", Vector3.new(1.8, 4.6, 2.8), CFrame.new(body.Position.X, rt + 2.3, cz) + off, C.chimney, Enum.Material.Plastic)
		for _, o in { -0.8, 0.8 } do part(M, "PotCheminee", Vector3.new(0.8, 0.9, 0.8), CFrame.new(body.Position.X, rt + 5.05, cz + o) + off, C.pot, Enum.Material.Plastic) end
	end
end
local mans = {}
for _, m in SL.Buildings:GetChildren() do if m.Name:match("^Mansion_") then table.insert(mans, m) end end
table.sort(mans, function(a, b) return a.Name < b.Name end)
for i, m in ipairs(mans) do
	local bc = ({ C.brick, C.yellowBrick, C.brick, C.yellowBrick, C.brick })[i]
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "Body" then paint(p, bc, Enum.Material.Plastic)
			elseif p.Name == "Roof" then paint(p, C.slate, Enum.Material.Plastic)
			elseif p.Name == "GroundBand" or p.Name:match("^Band_") or p.Name == "Cornice" then paint(p, C.stucco) end
		end
	end
	local roof = m:FindFirstChild("Roof", true)
	local body = m:FindFirstChild("Body", true)
	if roof and body then
		local rt = roof.Position.Y + roof.Size.Y / 2
		local M = folder(m.Name, HF)
		local off = chimneyOffset(m, body)
		part(M, "Cheminee", Vector3.new(2.8, 6.2, 1.8), CFrame.new(roof.Position.X, rt + 3.1, roof.Position.Z) + off, C.chimney, Enum.Material.Plastic)
		for _, o in { -0.7, 0.7 } do part(M, "PotCheminee", Vector3.new(0.8, 0.9, 0.8), CFrame.new(roof.Position.X + o, rt + 6.65, roof.Position.Z) + off, C.pot, Enum.Material.Plastic) end
	end
end
for i, h in ipairs({ SL.Houses:FindFirstChild("House_N3"), SL.Houses:FindFirstChild("House_S3"), SL.Houses:FindFirstChild("House_S4") }) do
	if h then
		local bc = ({ C.yellowBrick, C.stucco, C.brick })[i]
		for _, p in h:GetDescendants() do
			if p:IsA("BasePart") then
				if p.Name == "Wall" or p.Name:match("^WallSkin") then paint(p, bc, Enum.Material.Plastic)
				elseif p.Name == "FrontDoor" then paint(p, DOORS[i])
				elseif p.Name == "Roof" then paint(p, C.slate) end
			end
		end
	end
end

---------------------------------------------------------------- 4. lampes à gaz, abribus, boîte aux lettres, arbres, pluie, brouillard
local LF = folder("LampesAGaz")
for _, sp in { { "Lamp_N1", 155 }, { "Lamp_N1", 180 }, { "Lamp_S1", 155 }, { "Lamp_S1", 180 } } do
	local src = SL.Props:FindFirstChild(sp[1])
	if src then
		local c = src:Clone()
		c.Name = sp[1]:sub(1, 6) .. "_x" .. sp[2]
		c:PivotTo(src:GetPivot() + Vector3.new(sp[2] - src:GetPivot().X, 0, 0))
		c.Parent = LF
	end
end
local nLamps = 0
local lampList = {}
for _, m in SL.Props:GetChildren() do if m.Name:match("^Lamp_") then table.insert(lampList, m) end end
for _, m in LF:GetChildren() do table.insert(lampList, m) end
for _, m in lampList do
	local glow = m:FindFirstChild("Glow", true)
	if glow then
		nLamps += 1
		part(LF, "Flamme_" .. m.Name, Vector3.new(0.45, 1.0, 0.45), glow.CFrame, C.flame, Enum.Material.Neon)
		for _, l in glow:GetChildren() do if l:IsA("PointLight") then l.Range = 14 l.Color = C.warm end end
	end
end
do
	local bs = SL.Props:FindFirstChild("BusStop")
	if bs then stash(bs) end
	local pb = SL.Props:FindFirstChild("PostBox")
	if pb then stash(pb) end
	local A = folder("Abribus")
	local x0, zc, y0 = 213, 58, 0.45
	for _, dx in { -3, 3 } do part(A, "Poteau", Vector3.new(0.3, 7.6, 0.3), CFrame.new(x0 + dx, y0 + 3.8, zc + 1.1), C.iron, Enum.Material.Plastic, { collide = true }) end
	for _, dx in { -3, 3 } do part(A, "PoteauAvant", Vector3.new(0.3, 7.6, 0.3), CFrame.new(x0 + dx, y0 + 3.8, zc - 1.1), C.iron, Enum.Material.Plastic, { collide = true }) end
	part(A, "Fond", Vector3.new(5.7, 5.6, 0.15), CFrame.new(x0, y0 + 3.6, zc + 1.1), C.roofGlass, Enum.Material.Glass, { transp = 0.5 })
	part(A, "Toit", Vector3.new(6.8, 0.25, 2.9), CFrame.new(x0, y0 + 7.7, zc - 0.05), C.roofGlass, Enum.Material.Glass, { transp = 0.4 })
	part(A, "ToitCadre", Vector3.new(6.8, 0.35, 0.2), CFrame.new(x0, y0 + 7.6, zc - 1.5), C.iron, Enum.Material.Plastic)
	part(A, "Banc", Vector3.new(4.4, 0.35, 0.9), CFrame.new(x0, y0 + 1.6, zc + 0.5), C.iron, Enum.Material.Plastic, { collide = true })
	for _, dx in { -1.8, 1.8 } do part(A, "PiedBanc", Vector3.new(0.25, 1.4, 0.7), CFrame.new(x0 + dx, y0 + 0.7, zc + 0.5), C.iron, Enum.Material.Plastic) end
	local panel = part(A, "Panneau", Vector3.new(0.25, 2.4, 2.4), CFrame.new(x0 + 3.45, y0 + 9.4, zc - 0.3), C.red, Enum.Material.Plastic)
	gui(panel, Enum.NormalId.Right, "BUS STOP", C.white, Enum.Font.FredokaOne)
	gui(panel, Enum.NormalId.Left, "BUS STOP", C.white, Enum.Font.FredokaOne)
	part(A, "PanneauMat", Vector3.new(0.3, 2.3, 0.3), CFrame.new(x0 + 3.45, y0 + 8.95 - 1.15 + 0.1, zc - 1.1), C.iron, Enum.Material.Plastic)
end
for _, m in SL.Buildings:GetChildren() do
	if m.Name:match("^Tree_") then
		local can = m:FindFirstChild("Canopy")
		local sa = can and can:FindFirstChildOfClass("SurfaceAppearance")
		if sa then sa.Color = C.leaf nPaint += 1 end
	end
end
do
	local rain = SL.Weather:FindFirstChild("RainCloud")
	local e = rain and rain:FindFirstChild("Rain")
	if e then
		e.Rate = 360
		e.Squash = NumberSequence.new(-4)
		e.Size = NumberSequence.new(0.5)
	end
	-- brouillard bas (chef DA, 28/11) : au ras du sol (3 studs au plus), arrêté à x 205 (25 avant Tokyo), petites
	-- particules à Transparency 0,9, débit et vie réduits, gris-vert #aab4b0 qui ne prend jamais le rose des néons
	local mist = SL.Weather:FindFirstChild("MistBank")
	local src = mist and mist:FindFirstChildOfClass("ParticleEmitter")
	local p = part(folder("Ambiance"), "BrouillardBas", Vector3.new(77, 1, 88), CFrame.new(166.5, 0.5, 0), C.fog, Enum.Material.Plastic, { transp = 1, shadow = false })
	local f = src and src:Clone() or Instance.new("ParticleEmitter")
	f.Name = "BrouillardBas"
	f.Rate = 1
	f.Lifetime = NumberRange.new(5.4, 6.6)
	f.Parent = p
	local fogs = { p }
	if mist then mist.Size = Vector3.new(77, 1, mist.Size.Z) mist.CFrame = CFrame.new(166.5, 0.5, mist.Position.Z) table.insert(fogs, mist) end
	local gate = SL.Weather:FindFirstChild("GateMistBank")
	if gate then gate.CFrame = CFrame.new(gate.Position.X, 0.5, gate.Position.Z) table.insert(fogs, gate) end
	for _, fp in fogs do
		for _, e in fp:GetChildren() do
			if e:IsA("ParticleEmitter") then
				if fp ~= p then e.Rate = math.max(0.5, (e:GetAttribute("BaseRate") or e.Rate) / 2) e:SetAttribute("BaseRate", e:GetAttribute("BaseRate") or e.Rate * 2) end
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 6) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(0.7, 0.9), NumberSequenceKeypoint.new(1, 1) })
				e.Speed = NumberRange.new(0, 0.3)
				e.Acceleration = Vector3.zero
				e.LightEmission = 0
				e.LightInfluence = 1
				e.Color = ColorSequence.new(C.fog)
				e.Enabled = true
			end
		end
	end
end

---------------------------------------------------------------- 5. arche d'entrée
-- v3 du 28/11 (proposition du chef DA, puis budget du Chef de projet : moins de 200 pièces ; v1 et v2 rangées dans la
-- sauvegarde) : masse en mortier #c9c2b0 en tranches de 4 ; sur les deux faces, un rang de briques = une bande
-- continue de 0,5 de haut, en relief de 0,1, joints horizontaux de 0,1 (le mortier se voit entre les rangs) ; tons par
-- rang : rang du bas foncé #6e2c24, puis #8a3a2e et #9a4636 en alternance (2 rangs sur 3 au ton moyen), 3 rangs du haut
-- clairs ; sous la clé, les rangs s'arrêtent sur les claveaux ; claveaux (23) et clé de voûte en pierre miel
-- #c9a86a / #b8955a (0,2 de relief), cordon et couronnement en pierre ; 4 lanternes à gaz.
do
	local A = Instance.new("Model")
	A.Name = "ArcheEntree"
	A.Parent = B
	local AC = { light = rgb("9a4636"), mid = rgb("8a3a2e"), dark = rgb("6e2c24"), mortar = C.coping, stoneA = rgb("c9a86a"), stoneB = rgb("b8955a") }
	local S = Enum.Material.SmoothPlastic
	local X, TH = 124.5, 4
	local HALF, YS, RISE, YD, YTOP = 58.9, 26, 8, 36, 42
	local function yb(z) return YS + RISE * (1 - (z / 59) ^ 2) end
	local RING = 1.6
	local z = -HALF
	while z < HALF - 0.01 do
		local z1 = math.min(z + 4, HALF)
		local y0 = math.min(yb(z), yb(z1))
		part(A, "Mortier", Vector3.new(TH, YD - y0, z1 - z), CFrame.new(X, (y0 + YD) / 2, (z + z1) / 2), AC.mortar, S)
		z = z1
	end
	part(A, "MortierTablier", Vector3.new(TH, YTOP - YD, HALF * 2), CFrame.new(X, (YD + YTOP) / 2, 0), AC.mortar, S)
	local nseg, k = 24, 0
	for i = 0, nseg - 1 do
		local za, zb = -HALF + i * (2 * HALF / nseg), -HALF + (i + 1) * (2 * HALF / nseg)
		local zc = (za + zb) / 2
		if math.abs(zc) > 1.6 then
			local ya, ybb = yb(za), yb(zb)
			local len = math.sqrt((zb - za) ^ 2 + (ybb - ya) ^ 2)
			local cf = CFrame.new(X, (ya + ybb) / 2, zc) * CFrame.Angles(math.atan2(ybb - ya, zb - za), 0, 0) * CFrame.new(0, RING / 2, 0)
			k += 1
			part(A, "Claveau", Vector3.new(TH + 0.4, RING, len - 0.1), cf, (k % 2 == 0) and AC.stoneA or AC.stoneB, S)
		end
	end
	part(A, "CleDeVoute", Vector3.new(TH + 0.6, 4.2, 3.2), CFrame.new(X, yb(0) + 1.5, 0), AC.stoneA, S)
	part(A, "Cordon", Vector3.new(TH + 0.4, 0.5, HALF * 2), CFrame.new(X, YD + 0.25, 0), AC.stoneB, S)
	part(A, "Couronnement", Vector3.new(TH + 0.4, 0.8, HALF * 2), CFrame.new(X, YTOP + 0.4, 0), AC.stoneA, S)
	-- rangs de briques : bande continue par rang et par côté de l'arche (deux bandes sous le sommet des claveaux)
	local BH, J = 0.5, 0.1
	local rows = {}
	local y0 = YS + 0.05
	while y0 + BH <= YTOP - 0.05 do table.insert(rows, y0) y0 += BH + J end
	local crown = yb(0) + RING + 0.05 -- au-dessus, les rangs passent d'un bout à l'autre
	for _, side in { -1, 1 } do
		local fx = X + side * (TH / 2)
		local first = true
		for ri, ya in rows do
			local yz = ya + BH
			if not (ya < YD + 0.55 and yz > YD - 0.05) then
				-- z où le rang quitte les claveaux : yb(z) + RING + 0,05 = ya
				local spans = {}
				if ya >= crown then
					spans = { { -HALF + 0.05, HALF - 0.05 } }
				else
					local t = 1 - (ya - RING - 0.05 - YS) / RISE
					if t > 0 then
						local zc = 59 * math.sqrt(math.min(t, 1))
						if zc < HALF - 0.6 then spans = { { -HALF + 0.05, -zc - 0.05 }, { zc + 0.05, HALF - 0.05 } } end
					end
				end
				if #spans > 0 then
					local tone = (ri > #rows - 3) and "light" or (first and "dark" or ((ri % 3 == 0) and "light" or "mid"))
					first = false
					for _, sp in spans do
						if sp[2] - sp[1] > 0.3 then
							part(A, "RangBriques", Vector3.new(0.2, BH, sp[2] - sp[1]), CFrame.new(fx, ya + BH / 2, (sp[1] + sp[2]) / 2), AC[tone], S)
						end
					end
				end
			end
		end
	end
	for _, lz in { -30, -12, 12, 30 } do
		local y = yb(lz)
		part(A, "Chaine", Vector3.new(0.12, 1.2, 0.12), CFrame.new(X, y - 0.6, lz), C.iron, Enum.Material.Plastic)
		part(A, "LanterneChapeau", Vector3.new(1.1, 0.35, 1.1), CFrame.new(X, y - 1.35, lz), C.iron, Enum.Material.Plastic)
		local g = part(A, "Lanterne", Vector3.new(0.8, 1.3, 0.8), CFrame.new(X, y - 2.2, lz), C.flame, Enum.Material.Neon)
		light(g, 14, C.warm, 1)
		part(A, "LanterneFond", Vector3.new(1.0, 0.25, 1.0), CFrame.new(X, y - 2.97, lz), C.iron, Enum.Material.Plastic)
	end
end

---------------------------------------------------------------- 6. places du chef 3D
local SF = folder("Places_Chef3D")
local function spot(name, size, pos, pour)
	local p = part(SF, name, size, CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)), C.red, Enum.Material.Plastic, { transp = 1, shadow = false })
	p:SetAttribute("Pour", pour)
end
local Y0 = 0.6 -- au-dessus du sol avancé des magasins (FloorTiles jusqu'à |z| 52, dessus 0,57)
for i, pz in ipairs({ { 125.6, 57.7 }, { 161, 50.5 }, { 175, -50.5 }, { 125.6, -57.7 } }) do
	spot(("Spot_BoiteAuxLettres_%02d"):format(i), Vector3.new(2, 6, 2), Vector3.new(pz[1], Y0, pz[2]), "chef 3D : boîte aux lettres rouge en colonne, en voxel, fente vers la rue (" .. (pz[2] > 0 and "−z" or "+z") .. ")")
end
spot("Spot_Taxi_N", Vector3.new(10, 5.5, 4.5), Vector3.new(220.5, Y0, 52), "chef 3D : taxi noir londonien en voxel, garé le long du trottoir (x), sans gêner la chaussée")
spot("Spot_Taxi_S", Vector3.new(10, 5.5, 4.5), Vector3.new(219, Y0, -52), "chef 3D : taxi noir londonien en voxel, garé le long du trottoir (x), sans gêner la chaussée")
for i, pz in ipairs({ { 141, 50.5 }, { 151, 50.5 }, { 196.5, 50.5 }, { 140, -50.5 }, { 186, -50.5 }, { 195.5, -50.5 } }) do
	spot(("Spot_Parapluie_%02d"):format(i), Vector3.new(3.6, 7, 3.6), Vector3.new(pz[1], Y0, pz[2]), "chef 3D : parapluie ouvert de terrasse en voxel (noir, rouge ou vert anglais), devant " .. (pz[2] > 0 and "le Magasin de jouets" or "la Confiserie"))
end

---------------------------------------------------------------- 7. enseignes sans « slop » (da-enseignes-sans-slop.md)
-- Un seul mot court par magasin PNJ, en lettres voxel de la police maison (lettres_voxel.luau, à charger avant), sur la
-- SignPart (gardée : le code s'en sert pour placer le panneau d'infos ; seul son texte part) ; ailleurs des pictos voxel.
-- Retirés (rangés dans la sauvegarde, dossier Enseignes, attribut Path) : textes SignPart, PanelBoard et PanelFrame
-- (SWEETS & TREATS, TOYS & GAMES), BluePlaque et BluePlaqueRim (fausses dates), StreetSign des tours (faux nom de rue),
-- DepotSign (BUS DEPOT), textes des HangingSign et des Advert du bus. Gardés en FredokaOne : TELEPHONE, LONDON, BUS STOP.
-- Les intérieurs (en-têtes de rayons, promos, réserve) ne sont pas touchés : consigne du Chef de projet du 28/11.
do
	local LV = _G.LettresVoxel
	assert(LV, "charger d'abord tools/clement/zones/lettres_voxel.luau")
	local E = folder("Enseignes")
	local bk = backup:FindFirstChild("Enseignes")
	if not bk then bk = Instance.new("Folder") bk.Name = "Enseignes" bk.Parent = backup end
	local function keep(inst)
		inst:SetAttribute("Path", inst:GetFullName())
		for _, d in inst:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
		inst.Parent = bk
	end
	local function stripGuis(p) for _, g in p:GetChildren() do if g:IsA("SurfaceGui") then g.Name = p.Name .. "_" .. g.Face.Name keep(g) end end end
	local FRED = Font.fromEnum(Enum.Font.FredokaOne)
	local function fredoka(p) for _, t in p:GetDescendants() do if t:IsA("TextLabel") then t.FontFace = FRED end end end
	-- enseignes des deux magasins
	for _, sw in { { Z2.STORE_Z2_Confiserie, "SWEETS", rgb("ff5d8f") }, { Z2.STORE_Z2_MagasinDeJouets, "TOYS", rgb("ffd23f") } } do
		local store, word, col = sw[1], sw[2], sw[3]
		local sp = store:FindFirstChild("SignPart")
		if sp then
			stripGuis(sp)
			-- police du chef DA (da-police-voxel.md) : p = 0,4, modèle SignLetters sous la SignPart
			LV.motMagasin(store, word, col, { px = 0.5 }) -- p 0,5 sur les SignPart larges (chef DA, 28/11)
		end
		for _, nm in { "PanelBoard", "PanelFrame", "BluePlaque", "BluePlaqueRim" } do
			local p = store:FindFirstChild(nm, true)
			if p then keep(p) end
		end
	end
	-- enseignes suspendues : sucette (Confiserie) et ours (Jouets), sur les deux faces (pictos de lettres_voxel.luau)
	for _, hs in { { Z2.STORE_Z2_Confiserie, "sucette" }, { Z2.STORE_Z2_MagasinDeJouets, "ours" } } do
		local h = hs[1]:FindFirstChild("HangingSign", true)
		if h then
			stripGuis(h)
			for _, f in { Enum.NormalId.Left, Enum.NormalId.Right } do LV.surFace(E, h, f, hs[2], { marge = 0.9 }) end
		end
	end
	-- rue : faux nom de rue et dépôt retirés
	for _, t in { SL.ClockTowers:FindFirstChild("ClockTower_N"), SL.ClockTowers:FindFirstChild("ClockTower_S") } do
		local p = t and t:FindFirstChild("StreetSign", true)
		if p then keep(p) end
	end
	local dep = SL.Houses:FindFirstChild("DepotSign", true)
	if dep then keep(dep) end
	-- bus : les deux affiches deviennent des silhouettes de tour d'horloge ; LONDON reste (FredokaOne)
	local bus = SL:FindFirstChild("DoubleDecker")
	for _, ad in { { "Advert_L", Enum.NormalId.Left }, { "Advert_R", Enum.NormalId.Right } } do
		local a = bus and bus:FindFirstChild(ad[1], true)
		if a then
			stripGuis(a)
			LV.surFace(E, a, ad[2], "tour", { contour = false, marge = 0.95, nom = "Picto_Bus_Tour" })
		end
	end
	if bus then fredoka(bus) end
	for _, pb in { SL.Props:FindFirstChild("PhoneBox_N"), SL.Props:FindFirstChild("PhoneBox_S") } do if pb then fredoka(pb) end end
	local panel = B:FindFirstChild("Abribus") and B.Abribus:FindFirstChild("Panneau")
	if panel then for _, t in panel:GetDescendants() do if t:IsA("TextLabel") then t.Text = "BUS STOP" t.FontFace = FRED end end end
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local np = 0 for _, d in B:GetDescendants() do if d:IsA("BasePart") then np += 1 end end
return ("Biome Londres : %d pièces neuves, %d recolorées, %d murets habillés, %d lampes à gaz, %d maisons Terrace"):format(np, nPaint, nWalls, nLamps, #terr)
