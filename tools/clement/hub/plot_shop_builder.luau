--!nocheck
--[[
	Constructeur de la boutique du joueur (MOD-015) et de son tapis et de son banc (MOD-016).
	Outil du Claude de Clément, exécuté dans Studio par le MCP (execute_luau, mode Edit).
	Ce n'est pas du code de jeu : il ne laisse aucun script dans les modèles.

	Chargement : envoyer tout ce fichier à execute_luau. Il pose _G.ClaudePlotShop :
		_G.ClaudePlotShop.build()                    -- (re)construit le gabarit PLOT_Shop
		_G.ClaudePlotShop.install({ cframe = CFrame.new(x, 0, z) * CFrame.Angles(0, a, 0),
			index = 1, parent = workspace.Map.Hub, stage = 1, accent = Color3 })
		_G.ClaudePlotShop.preview(model, stage)      -- montre un niveau (1 à 5), en Edit seulement
		_G.ClaudePlotShop.check(model)               -- triangles, noms du contrat, scripts

	Gabarit : ReplicatedStorage/Assets/Plots/PLOT_Shop, tags PlayerPlot (boutique), CashPad,
	Treadmill et Bench déjà posés, pas de PlotIndex (posé par install). Bâtiment 64 x 80 studs, plus le devant
	(x -32..32, z -40..40), pivot en bas au centre, avant vers -Z.

	Contrat 10.4 (cœur, présent à tous les niveaux) : Window (porte vitrée à 2 vantaux Leaf_L et
	Leaf_R, 18 x 10,5 x 0,6 = WIN_M x 1,5), WindowFractured (WIN_M_Fractured x 1,5, cachée),
	Shutter (caché dans le linteau, descend de 10,84), ShutterButton, DisplaySlot_01 à _20,
	VaultSlot_01 à _03, UnboxBench_01 à _04, TrapSlot_01 à _04, CashPad, DepositZone,
	Treadmill (copie de Assets/Plots/PLOT_Treadmill_Base : UsePoint, Belt, UpgradePoint), Bench (UsePoint, UpgradePoint), NameSign/OwnerName,
	SpawnPoint, Bounds.

	Noms proposés (à valider par Ironix) :
	- Stage_1 à Stage_5 : Models, enfants directs de la boutique, pivot = pivot de la boutique.
	  Décor ajouté à chaque niveau, cumulatif : au niveau n, Stage_1 à Stage_n sont là. Les 5 niveaux
	  du doc (Partie 2, section 2) : Stand, Boutique, Magasin, Concept store, Flagship.
	- Attribut HideFromStage (nombre) : la pièce ou le groupe disparaît à partir de ce niveau
	  (remplacé par un niveau plus haut). Plus d'attribut FromStage (2026-11-11) : ce qui n'existe qu'à
	  partir du niveau 2 (grands murs invisibles Barriers, contours RayonSpots) est rangé dans Stage_2.
	- Niveau de la boutique = nombre de rayons débloqués (Clément, 2026-11-11 : la boutique grandit avec
	  les rayons). Les boutiques du hub sont posées au niveau 1 ; quand le rayon k arrive, le code copie
	  Stage_2 à Stage_k depuis ce gabarit (même calcul de pivot que les RayonVisuals), recolore leurs
	  pièces Accent = true avec l'attribut AccentColor de la boutique, puis cache tout ce qui porte
	  HideFromStage <= k. Le rayon k est dans le bâtiment du niveau k (niveau 1 : rayon 1, z -40..-16 ;
	  dès le niveau 2 : sol, murs invisibles et volume jusqu'à z 40, les 5 rayons).
	- Niveau 1 = petite boutique d'une seule rangée (z -40..-16) ; Stage_2 pose la suite du sol
	  (PlotFloorExt, z -16..40) et les niveaux suivants l'habillent. Plus de coffre visible ni d'établis
	  (L-086) : VaultSlot_01 à _03 sur VaultAnchor (invisible), UnboxBench_01 à _04 sur les présentoirs
	  de Rayon_01, au même point que DisplaySlot_01 à _04.
	- PlotDoor : Model de l'entrée (portique, Window, WindowFractured, Shutter, ShutterButton,
	  NameSign). Window/Leaf_L et Window/Leaf_R : les vantaux que le code peut faire coulisser
	  pour le propriétaire.
	- PlotBarrier : Model de murs invisibles (côtés, fond, avant hors porte, couvercle) ; le code
	  les rend franchissables pour le propriétaire seul. Les autres entrent en cassant Window.
	- StageUpgradePoint : Attachment au sol sur PlotFloor (y 0,3, face à -Z, vers la porte) où le code plante le panneau d'achat du niveau suivant, en (0, -18,6) au niveau 1. StageUpgradePoint_2 : même chose au fond de la boutique, en (0, 37,6), pour les niveaux 2 à 5.
	- Rayon_01 à Rayon_05 : Models, 4 présentoirs chacun (DisplaySlot_01 à _04 dans Rayon_01, etc.).
	  Seul Rayon_01 a ses visuels. Rayon_02 à _05 n'ont qu'une pièce invisible RayonAnchor qui porte
	  leurs DisplaySlot ; leurs visuels (présentoirs, CollectPad, produits) sont rangés dans
	  ReplicatedStorage/Assets/Plots/PLOT_Shop_Rayons/Rayon_0n, même repère que la boutique : le code
	  les copie dans Rayon_0n au pivot de la boutique (showRayon) quand la rangée est débloquée.
	  RayonSpot_02 à _05 (dans Stage_2/RayonSpots) : contour au sol de l'emplacement, retiré quand la rangée vient.
	- CollectPad_01 à _20 : plaque carrée au sol (3,2 x 3,2) au pied de chaque présentoir, dans le même
	  rayon ; le propriétaire y marche pour ramasser l'argent de cet objet. Plaque couchée (face Front vers
	  le ciel, haut vers la porte) : SurfaceGui AmountGui (Face Front) > TextLabel Amount (« $0 ») où le code écrit le montant de l'objet. Plus de caisse ni de
	  caisse globale (2026-11-10) : CashPad n'est plus qu'une pièce invisible enfouie, pour le contrat.
	- DisplayUpgradePoint : Attachment sur PlotFloor (les bornes noires près de la porte sont retirées).
	- Plus de terrasse (2026-11-11) : devant la façade (z -52..-40), tapis, banc et socle sont posés
	  sur le sol du hub (y 0). Emprise totale : 64 x 92 studs (z -52..40), pivot au centre du bâtiment (z 0).
	- Treadmill et Bench : identiques dans les 6 boutiques (pas de couleur d'accent). Chacun a une
	  UseZone : Part invisible, sans collision, CanTouch, autour de la machine (+3 studs, 8 de haut) ;
	  le code fait monter le joueur dès qu'il y entre.
	- RarestPedestal : Model du socle de l'objet le plus rare, devant la façade, entre la porte et le
	  banc (x 7,5, z -48,5), à tous les niveaux. RarestSlot : Attachment sur le plateau, où le code pose
	  l'objet (face à la rue). RarestLabelPoint : Attachment 6 studs au-dessus, pour l'étiquette.
	Aucun élément du contrat n'est dans un Stage_n.
]]

local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local C = {
	accent = rgb(46, 166, 242), accentDark = rgb(28, 120, 186),
	slab = rgb(196, 203, 212), tile = rgb(236, 239, 243), entry = rgb(170, 178, 190),
	frame = rgb(58, 64, 75), dark = rgb(27, 27, 36), metal = rgb(167, 176, 188), metal2 = rgb(149, 158, 170),
	chrome = rgb(205, 210, 218), glass = rgb(191, 230, 255), white = rgb(245, 246, 248),
	wall = rgb(242, 236, 224), innerWall = rgb(232, 235, 240), ceiling = rgb(236, 238, 242),
	shelf = rgb(232, 236, 242), shelfBack = rgb(210, 216, 224), kick = rgb(200, 206, 214),
	price = rgb(255, 230, 0), wood = rgb(150, 105, 60), woodDark = rgb(94, 59, 33), carton = rgb(181, 130, 76),
	green = rgb(53, 201, 59), red = rgb(232, 65, 60), yellow = rgb(255, 210, 40), orange = rgb(255, 140, 40),
	purple = rgb(155, 92, 246), pink = rgb(255, 125, 160), rubber = rgb(36, 36, 42), pad = rgb(40, 44, 54),
	neon = rgb(205, 205, 198), gold = rgb(255, 194, 26), marble = rgb(244, 241, 235), velvet = rgb(170, 20, 40),
	steel = rgb(120, 128, 140), hazard = rgb(255, 200, 0), leaf = rgb(63, 191, 58), pot = rgb(200, 100, 60),
}

-- Une couleur d'accent par boutique (PlotIndex 1 à 6), pour reconnaître la sienne de loin.
-- La 2 passe du vert au rouge le 2026-11-08 : le hub est en pelouse, une boutique verte ne s'y voyait pas.
local ACCENTS = {
	rgb(46, 166, 242), rgb(232, 65, 60), rgb(155, 92, 246),
	rgb(255, 140, 40), rgb(255, 90, 170), rgb(0, 190, 200),
}

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

local ctx -- { model, parts, tris }

-- Boîte de (x0, y0, z0) à (x1, y1, z1) en coordonnées locales de la boutique.
local function B(parent, name, x0, y0, z0, x1, y1, z1, color, opt)
	opt = opt or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) * (opt.rot or CFrame.identity)
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opt.shape then p.Shape = opt.shape end
	if opt.mat then
		p.Material = opt.mat
	elseif opt.studs == false then
		p.Material = Enum.Material.SmoothPlastic
	else
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = "Studs"
	end
	if opt.decor then p.CanCollide = false; p.CanTouch = false; p.CanQuery = false end
	if opt.T then p.Transparency = opt.T end
	if opt.noShadow then p.CastShadow = false end
	if opt.accent then p:SetAttribute("Accent", true) end
	p.Parent = parent
	return p
end

-- Cylindre couché le long de X (forme Roblox), centré en (x, y, z), longueur len, diamètre d.
local function CYL(parent, name, x, y, z, len, d, color, opt)
	opt = opt or {}
	local p = B(parent, name, 0, 0, 0, len, d, d, color, { studs = false, mat = opt.mat, decor = opt.decor,
		shape = Enum.PartType.Cylinder, noShadow = opt.noShadow, accent = opt.accent, T = opt.T })
	p.CFrame = CFrame.new(x, y, z) * (opt.rot or CFrame.identity)
	return p
end

local function group(parent, name, attrs)
	local m = Instance.new("Model")
	m.Name = name
	for k, v in attrs or {} do m:SetAttribute(k, v) end
	m.Parent = parent
	return m
end

-- Attachment placé dans `part`, à la position locale (x, y, z), axe -Z (LookVector) vers `look`.
local function att(name, part, x, y, z, look)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = part
	local pos = Vector3.new(x, y, z)
	a.WorldCFrame = CFrame.lookAt(pos, pos + (look or Vector3.new(0, 0, -1)))
	return a
end

local function label(part, face, text, color, ppS, stroke, name)
	local g = Instance.new("SurfaceGui")
	g.Name = "LabelGui_" .. face.Name
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS or 40
	g.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = name or "Label"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color
	t.FontFace = FONT
	local s = Instance.new("UIStroke")
	s.Color = stroke or Color3.new(0, 0, 0)
	s.Thickness = 4
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0); pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.04, 0); pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = t
	t.Parent = g
	g.Parent = part
	return t
end

local function light(part, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range; l.Brightness = brightness; l.Color = color or rgb(255, 246, 230); l.Shadows = false
	l.Parent = part
	return l
end

-- Produits de décor sur une planche qui court le long de Z (x fixe), face vers sx (+1 ou -1).
local seed = 4242
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
local PRODUCT_COLORS = {
	{ C.red, C.white }, { C.accent, C.yellow }, { C.green, C.white }, { C.yellow, C.red },
	{ C.purple, C.yellow }, { C.orange, C.green }, { C.pink, C.white }, { C.white, C.accent },
}
local function products(parent, prefix, fx, sx, z0, z1, y, maxH)
	local z, n = z0 + 0.25, 0
	while z < z1 - 0.6 do
		local pair = PRODUCT_COLORS[math.floor(rnd() * #PRODUCT_COLORS) + 1]
		local w = 0.55 + math.floor(rnd() * 3) * 0.2
		local h = math.min(maxH, 0.7 + math.floor(rnd() * 4) * 0.15)
		local run = 2 + math.floor(rnd() * 3)
		for _ = 1, run do
			if z + w > z1 - 0.25 then z = z1; break end
			n += 1
			local x0, x1 = fx - sx * 0.85, fx - sx * 0.05
			local capH = (rnd() < 0.5) and 0.2 or 0
			B(parent, prefix .. "_P" .. n, math.min(x0, x1), y, z, math.max(x0, x1), y + h - capH, z + w, pair[1], { studs = false, decor = true, noShadow = true })
			if capH > 0 then
				n += 1
				B(parent, prefix .. "_P" .. n, math.min(x0, x1), y + h - capH, z, math.max(x0, x1), y + h, z + w, pair[2], { studs = false, decor = true, noShadow = true })
			end
			z += w + 0.08
		end
		z += 0.2
	end
	return n
end

-- Même chose le long de X (z fixe, face vers sz = +1 ou -1).
local function productsX(parent, prefix, x0, x1, fz, sz, y, maxH)
	local x, n = x0 + 0.25, 0
	while x < x1 - 0.6 do
		local pair = PRODUCT_COLORS[math.floor(rnd() * #PRODUCT_COLORS) + 1]
		local w = 0.55 + math.floor(rnd() * 3) * 0.2
		local h = math.min(maxH, 0.7 + math.floor(rnd() * 4) * 0.15)
		local run = 2 + math.floor(rnd() * 3)
		for _ = 1, run do
			if x + w > x1 - 0.25 then x = x1; break end
			n += 1
			local z0, z1 = fz - sz * 0.85, fz - sz * 0.05
			local capH = (rnd() < 0.5) and 0.2 or 0
			B(parent, prefix .. "_P" .. n, x, y, math.min(z0, z1), x + w, y + h - capH, math.max(z0, z1), pair[1], { studs = false, decor = true, noShadow = true })
			if capH > 0 then
				n += 1
				B(parent, prefix .. "_P" .. n, x, y + h - capH, math.min(z0, z1), x + w, y + h, math.max(z0, z1), pair[2], { studs = false, decor = true, noShadow = true })
			end
			x += w + 0.08
		end
		x += 0.2
	end
	return n
end

-- 20 présentoirs en 5 rayons de 4 (Rayon_01 devant, près de l'entrée ; 7.5 : 4 au départ, +1 par
-- achat). Chaque rayon court le long de la façade, en deux moitiés (x -25..-7 et 7..25) autour de
-- l'allée centrale. Présentoirs d'un rayon, dans l'ordre : x -11, 11, -21, 21.
local RAYON_Z = { -22, -13, -4, 5, 14 }
local STAND_X = { -11, 11, -21, 21 }
-- Fond de la boutique de niveau 1 (une seule rangée, Rayon_01) : z -40..SMALL_Z. Le niveau 2 l'agrandit à z 40.
local SMALL_Z = -16

_G.ClaudePlotShopParts = {
	CS = CS, RS = RS, rgb = rgb, C = C, ACCENTS = ACCENTS, B = B, CYL = CYL, group = group, att = att,
	label = label, light = light, rnd = rnd, products = products, productsX = productsX, PRODUCT_COLORS = PRODUCT_COLORS,
	RAYON_Z = RAYON_Z, STAND_X = STAND_X, SMALL_Z = SMALL_Z,
	setSeed = function(v) seed = v end,
}

-- ===== Morceau 2 : cœur (sol, entrée, barrière, volumes, rayons, ancrage du coffre, caisse) =====
-- Le fichier peut s'envoyer d'un bloc, ou morceau par morceau (chaque morceau relit _G.ClaudePlotShopParts).
local P = _G.ClaudePlotShopParts
local CS, RS, C, B, CYL, group, att, label, light = P.CS, P.RS, P.C, P.B, P.CYL, P.group, P.att, P.label, P.light
local RAYON_Z, STAND_X, SMALL_Z, productsX, PRODUCT_COLORS = P.RAYON_Z, P.STAND_X, P.SMALL_Z, P.productsX, P.PRODUCT_COLORS

-- Damier de 4 studs, rangées de carreaux iz0 à iz1 (z = -40 + 4 * iz).
local function floorTiles(parent, name, iz0, iz1)
	local tiles = group(parent, name)
	local nt = 0
	for ix = 0, 15 do
		for iz = iz0, iz1 do
			if (ix + iz) % 2 == 0 then
				nt += 1
				local x0, z0 = -32 + 4 * ix, -40 + 4 * iz
				B(tiles, "Tile_" .. nt, x0, 0.3, z0, x0 + 4, 0.32, z0 + 4, C.tile, { decor = true, noShadow = true })
			end
		end
	end
	return tiles
end
P.floorTiles = floorTiles

local function buildCore(M)
	-- sol à la couleur de la boutique (Clément, 2026-11-08 : chaque boutique a sa couleur, personnalisable plus tard) :
	-- damier couleur et blanc. Niveau 1 : une seule rangée (z -40..SMALL_Z) ; le niveau 2 pose la suite du sol.
	local floor = B(M, "PlotFloor", -32, -0.6, -40, 32, 0.3, SMALL_Z, C.accent, { accent = true })
	floorTiles(M, "FloorTiles", 0, (SMALL_Z + 40) / 4 - 1)

	-- entrée : portique, porte vitrée (Window), éclats, rideau, bouton, enseigne
	-- Grande vitre (Clément, 2026-11-08 : plus belle et plus facile à toucher) : 18 x 10,5 x 0,6, soit
	-- WIN_M (12 x 7 x 0,4) x DOOR_SCALE. Le ShatterController ne trouve pas de variante WIN_M à cette
	-- taille : il lance les éclats du WindowFractured de la boutique, posé ici à l'échelle.
	local DOOR_SCALE = 1.5
	local D = group(M, "PlotDoor")
	B(D, "Post_L", -10, 0.3, -40.5, -9, 11.1, -38.5, C.frame)
	B(D, "Post_R", 9, 0.3, -40.5, 10, 11.1, -38.5, C.frame)
	-- linteau haut (au-dessus du toit) : il cache le rideau de 10,6 et porte l'enseigne
	B(D, "Header", -10, 11.1, -40.5, 10, 22.6, -38.5, C.accent, { accent = true })
	B(D, "HeaderTrim_B", -10.1, 11.1, -40.6, 10.1, 11.8, -38.4, C.frame)
	B(D, "HeaderTrim_T", -10.1, 21.9, -40.6, 10.1, 22.7, -38.4, C.frame)
	B(D, "Threshold", -9, 0.3, -40, 9, 0.6, -39, C.metal, { studs = false })
	local W = group(D, "Window")
	for _, leafSpec in { { "Leaf_L", -9 }, { "Leaf_R", 0 } } do
		local leaf = group(W, leafSpec[1])
		local x0 = leafSpec[2]
		local x1 = x0 + 9
		B(leaf, "Glass", x0 + 0.3, 0.9, -39.8, x1 - 0.3, 10.8, -39.2, C.glass, { mat = Enum.Material.Glass, T = 0.55 })
		B(leaf, "Stile_A", x0, 0.6, -39.8, x0 + 0.3, 11.1, -39.2, C.chrome, { studs = false })
		B(leaf, "Stile_B", x1 - 0.3, 0.6, -39.8, x1, 11.1, -39.2, C.chrome, { studs = false })
		B(leaf, "Rail_Top", x0 + 0.3, 10.8, -39.8, x1 - 0.3, 11.1, -39.2, C.chrome, { studs = false })
		B(leaf, "Rail_Bottom", x0 + 0.3, 0.6, -39.8, x1 - 0.3, 0.9, -39.2, C.chrome, { studs = false })
	end
	W.WorldPivot = CFrame.new(0, 0.6, -39.5)
	local wf = RS.Assets.Windows.WIN_M_Fractured:Clone()
	wf.Name = "WindowFractured"
	wf:ScaleTo(wf:GetScale() * DOOR_SCALE)
	wf:PivotTo(CFrame.new(0, 0.6, -39.5))
	for _, s in wf:GetDescendants() do
		if s:IsA("BasePart") then
			s.Transparency = 1; s.CanCollide = false; s.CanQuery = false; s.CanTouch = false; s.Anchored = true
		end
	end
	wf.Parent = D
	local sh = group(D, "Shutter")
	-- rideau caché dans le linteau : 10,84 de haut, il descend de sa propre hauteur jusqu'au seuil
	B(sh, "BottomBar", -9.8, 11.3, -40.35, 9.8, 11.5, -40.05, C.frame, { studs = false })
	for i = 0, 13 do
		local y0 = 11.5 + i * 0.76
		B(sh, string.format("Slat_%02d", i + 1), -9.8, y0, -40.3, 9.8, y0 + 0.76, -40.1, (i % 2 == 0) and C.metal or C.metal2,
			{ studs = false, mat = Enum.Material.DiamondPlate })
	end
	sh.WorldPivot = CFrame.new(0, 11.3, -40.2)
	B(D, "ShutterButtonBox", 9.1, 3.3, -38.5, 9.9, 4.7, -38.3, C.yellow, { studs = false })
	B(D, "ShutterButton", 9.25, 3.6, -38.3, 9.75, 4.1, -38.1, C.red, { studs = false })
	local sign = B(D, "NameSign", -8, 16.6, -40.9, 8, 21.2, -40.5, C.dark, { studs = false })
	label(sign, Enum.NormalId.Front, "YOUR SHOP", C.white, 40, Color3.new(0, 0, 0), "OwnerName")
	for i, b in { { -8.15, 21.2, 8.15, 21.35 }, { -8.15, 16.45, 8.15, 16.6 }, { -8.15, 16.45, -8, 21.35 }, { 8, 16.45, 8.15, 21.35 } } do
		B(D, "SignBorder_" .. i, b[1], b[2], -40.95, b[3], b[4], -40.5, C.white, { studs = false, decor = true })
	end
	local badge = B(D, "NumberBadge", -3.2, 13.4, -40.85, 3.2, 15.2, -40.5, C.white, { studs = false })
	label(badge, Enum.NormalId.Front, "SHOP 1", C.dark, 40, C.white, "PlotNumberLabel")

	-- barrière invisible : seul le propriétaire la franchit (code) ; les autres cassent Window.
	-- Côtés, fond et couvercle en deux versions : la petite (niveau 1, HideFromStage 2) et la grande
	-- (FromStage 2 : la pièce n'existe qu'à partir du niveau 2).
	local PB = group(M, "PlotBarrier")
	local H = 30
	local S = SMALL_Z
	for _, w in {
		{ "Barrier_L1", -32, 0.3, -40, -31.6, H, S, 1 }, { "Barrier_R1", 31.6, 0.3, -40, 32, H, S, 1 },
		{ "Barrier_B1", -32, 0.3, S - 0.4, 32, H, S, 1 }, { "Barrier_Lid1", -32, H, -40, 32, H + 0.5, S, 1 },
		{ "Barrier_L", -32, 0.3, -40, -31.6, H, 40, 2 }, { "Barrier_R", 31.6, 0.3, -40, 32, H, 40, 2 },
		{ "Barrier_B", -32, 0.3, 39.6, 32, H, 40, 2 }, { "Barrier_Lid", -32, H, -40, 32, H + 0.5, 40, 2 },
		{ "Barrier_FL", -32, 0.3, -40, -9, H, -39.6 }, { "Barrier_FR", 9, 0.3, -40, 32, H, -39.6 },
		{ "Barrier_FTop", -9, 11.1, -40, 9, H, -39.6 },
	} do
		local p = B(PB, w[1], w[2], w[3], w[4], w[5], w[6], w[7], C.white, { studs = false, T = 1, noShadow = true })
		p.CanTouch = false
		if w[8] == 1 then p:SetAttribute("HideFromStage", 2) elseif w[8] == 2 then p:SetAttribute("FromStage", 2) end
	end

	-- volumes
	-- plus de terrasse colorée devant la boutique (Clément, 2026-11-11) : tapis, banc et socle sont posés
	-- sur le sol vert du hub (y 0). Bounds = le bâtiment seul : PvPService en sort les non-propriétaires
	-- tant que la porte est intacte ; le devant (tapis, banc, socle, vitre à casser) reste libre d'accès
	local bounds = B(M, "Bounds", -32, 0.3, -40, 32, H, 40, C.white, { studs = false, decor = true, T = 1, noShadow = true })
	bounds.CanQuery = false
	local dep = B(M, "DepositZone", -31.5, 0.3, -39.5, 31.5, 12.3, 39.5, C.white, { studs = false, T = 1, noShadow = true })
	dep.CanCollide = false; dep.CanQuery = false; dep.CanTouch = true

	-- points au sol : apparition (vers la rue), pièges derrière la porte (Partie 2)
	att("SpawnPoint", floor, 0, 0.3, -27)
	att("StageUpgradePoint", floor, 0, 0.3, -18.6) -- panneau au sol, face à la porte (Clément, 2026-11-08)
	-- fond de la boutique aux niveaux 2 à 5 : le panneau suit le fond quand la boutique monte de niveau
	att("StageUpgradePoint_2", floor, 0, 0.3, 37.6)
	for i, p in { { -3, -35.5 }, { 3, -35.5 }, { -3, -31.5 }, { 3, -31.5 } } do
		att(string.format("TrapSlot_%02d", i), floor, p[1], 0.3, p[2])
	end
	return floor, D
end

local function buildInterior(M, store)
	-- 5 rayons de 4 présentoirs (Rayon_01 à _05). Chaque présentoir a sa case CollectPad_xx au sol,
	-- devant lui : le joueur y marche pour ramasser l'argent de cet objet. RayonSpot_xx = contour au
	-- sol de l'emplacement d'un rayon pas encore là (à partir du niveau 2, quand le sol s'agrandit).
	-- Rayon_01 est complet dans la boutique. Rayon_02 à _05 (L-082) : dans la boutique, seulement une
	-- pièce d'ancrage invisible RayonAnchor qui porte les DisplaySlot (contrat) ; leurs visuels
	-- (présentoirs, CollectPad, produits) sont rangés dans `store` (PLOT_Shop_Rayons), même repère.
	local HEADERS = { "SNACKS", "DRINKS", "TOYS", "TECH", "GIFTS" }
	local HEADER_COLORS = { C.orange, C.purple, C.green, C.red, C.pink }
	local spots = group(M, "RayonSpots", { FromStage = 2 })
	for r, zr in RAYON_Z do
		local inPlot = group(M, string.format("Rayon_%02d", r))
		local R = (r == 1) and inPlot or group(store, string.format("Rayon_%02d", r))
		local anchor
		if r > 1 then
			anchor = B(inPlot, "RayonAnchor", -0.5, 3.5, zr - 0.5, 0.5, 4.0, zr + 0.5, C.white, { studs = false, decor = true, T = 1, noShadow = true })
		end
		local spot = (r > 1) and group(spots, string.format("RayonSpot_%02d", r)) or nil
		for _, half in { { "L", -25, -7, -1 }, { "R", 7, 25, 1 } } do
			local h, x0, x1, sx = half[1], half[2], half[3], half[4]
			B(R, "Kick_" .. h, x0, 0.3, zr - 1.7, x1, 0.6, zr + 1.7, C.kick, { studs = false })
			B(R, "Spine_" .. h, x0 + 0.2, 0.6, zr - 0.9, x1 - 0.2, 3.0, zr + 0.9, C.shelfBack, { studs = false })
			B(R, "Top_" .. h, x0, 3.0, zr - 1.7, x1, 3.25, zr + 1.7, C.white, { studs = false })
			B(R, "Band_F" .. h, x0, 2.75, zr - 1.72, x1, 3.25, zr - 1.68, C.accent, { studs = false, decor = true, accent = true })
			B(R, "Band_B" .. h, x0, 2.75, zr + 1.68, x1, 3.25, zr + 1.72, C.accent, { studs = false, decor = true, accent = true })
			-- plus de produits factices, de planche ni d'étiquettes de prix (Clément, 2026-11-10 : le plus simple possible)
			local ex = (sx < 0) and x0 or x1
			local hdr = B(R, "Header_" .. h, math.min(ex, ex + sx * 0.25), 0.9, zr - 1.5, math.max(ex, ex + sx * 0.25), 2.75, zr + 1.5, HEADER_COLORS[r], { studs = false, decor = true })
			label(hdr, (sx < 0) and Enum.NormalId.Left or Enum.NormalId.Right, HEADERS[r], C.white, 40)
			if spot then
				for i, b in { { x0, zr - 1.7, x1, zr - 1.4 }, { x0, zr + 1.4, x1, zr + 1.7 }, { x0, zr - 1.4, x0 + 0.3, zr + 1.4 }, { x1 - 0.3, zr - 1.4, x1, zr + 1.4 } } do
					B(spot, "Outline_" .. h .. i, b[1], 0.32, b[2], b[3], 0.36, b[4], C.white, { studs = false, decor = true, noShadow = true })
				end
			end
		end
		for i, sxp in STAND_X do
			local n = (r - 1) * 4 + i
			local stand = B(R, string.format("DisplayStand_%02d", n), sxp - 1.3, 3.25, zr - 1.3, sxp + 1.3, 3.75, zr + 1.3, C.accent, { accent = true })
			att(string.format("DisplaySlot_%02d", n), anchor or stand, sxp, 3.75, zr)
			if r == 1 then
				-- L-086 : on pose et on ouvre le colis sur le présentoir, plus d'établi
				att(string.format("UnboxBench_%02d", i), stand, sxp, 3.75, zr)
			end
			-- une seule plaque carrée au sol par présentoir (3,2 x 3,2, Clément, 2026-11-11), avec le montant de
			-- l'objet : SurfaceGui AmountGui > TextLabel Amount, que le code remplit (« $1.2K »). La plaque est
			-- couchée : sa face Front (-Z local) regarde le ciel et son haut (+Y local) pointe vers la porte,
			-- donc le texte se lit à l'endroit en marchant vers la sortie.
			local cp = B(R, string.format("CollectPad_%02d", n), -1.6, -1.6, -0.06, 1.6, 1.6, 0.06, C.green, { studs = false, mat = Enum.Material.Neon })
			cp.CFrame = CFrame.fromMatrix(Vector3.new(sxp, 0.36, zr - 3.5), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0))
			cp.CanCollide = false; cp.CanTouch = true; cp.CanQuery = false
			label(cp, Enum.NormalId.Front, "$0", C.white, 40, nil, "Amount")
			cp.LabelGui_Front.Name = "AmountGui"
		end
	end
	-- plus de bornes noires à côté de la porte (Clément, 2026-11-10) : le point reste, posé sur le sol
	att("DisplayUpgradePoint", M.PlotFloor, -15.1, 0.3, -36.5) -- panneau au sol (session UI, 2026-11-08)

	-- coffre (Partie 2) : plus de coffre visible (L-086). VaultSlot_01 à _03 restent pour le contrat, en
	-- Attachments sur une pièce d'ancrage invisible et sans collision, au fond au centre.
	local va = B(M, "VaultAnchor", -5, 2.6, 33, 5, 2.85, 34, C.white, { studs = false, decor = true, T = 1, noShadow = true })
	for i, x in { -4.5, 0, 4.5 } do
		att(string.format("VaultSlot_%02d", i), va, x, 2.85, 33.5)
	end

	-- plus de caisse ni de caisse globale (Clément, 2026-11-10) : on encaisse sur la case de chaque objet.
	-- CashPad reste en pièce d'ancrage invisible, intouchable et enfouie dans le sol, tant que le contrat
	-- (Models.luau, Tags.luau) l'exige ; Ironix le retire du contrat, puis on le supprime.
	local pad = B(M, "CashPad", -25, -0.5, -32.5, -19, -0.4, -27.5, C.green, { studs = false, decor = true, T = 1, noShadow = true })
	pad.CanCollide = false; pad.CanTouch = false; pad.CanQuery = false
end

P.buildCore, P.buildInterior = buildCore, buildInterior

-- ===== Morceau 3 : tapis, banc, niveaux 1 à 3 =====
local P = _G.ClaudePlotShopParts
local CS, RS, rgb, C, B, CYL, group, att, label, light = P.CS, P.RS, P.rgb, P.C, P.B, P.CYL, P.group, P.att, P.label, P.light
local products, PRODUCT_COLORS = P.products, P.PRODUCT_COLORS

-- Tapis de course (MOD-016) : le modèle de Clément, PLOT_Treadmill_Base (Assets/Plots, rangé par
-- treadmill_assets.luau), copié sous le nom Treadmill avec le tag. Coureur tourné vers -Z, console
-- devant lui. Origine (ox, sol, oz) = pivot du modèle, en bas au centre. La variante argent
-- PLOT_Treadmill_Silver a le même repère : le code l'échange au pivot de Treadmill.
local function buildTreadmill(M, ox, oz)
	local src = RS.Assets.Plots:FindFirstChild("PLOT_Treadmill_Base")
	assert(src, "PLOT_Treadmill_Base introuvable dans Assets/Plots : lancer treadmill_assets.luau")
	local T = src:Clone()
	T.Name = "Treadmill"
	T:PivotTo(CFrame.new(ox, 0, oz)) -- sur le sol du hub (plus de terrasse)
	T.Parent = M
	CS:AddTag(T, "Treadmill")
	return T
end

-- Banc de musculation (MOD-016) : le joueur se tient au sol devant le banc, tourné vers -Z,
-- s'y assoit (BenchIdle), s'allonge, la tête sous la barre posée sur le rack (BenchLift).
local function buildBench(M, ox, oz)
	local K = group(M, "Bench")
	local y = 0 -- sur le sol du hub (plus de terrasse)
	local function P(name, x0, y0, z0, x1, y1, z1, color, opt)
		return B(K, name, ox + x0, y + y0, oz + z0, ox + x1, y + y1, oz + z1, color, opt)
	end
	local mat = P("GymMat", -2.4, 0, -4.2, 2.4, 0.06, 3.2, C.rubber, { studs = false, decor = true, noShadow = true })
	P("Pad", -0.9, 1.45, -2.3, 0.9, 1.85, 2.6, C.accent, { studs = false }) -- même banc dans les 6 boutiques (Clément, 2026-11-11)
	P("PadBase", -0.6, 1.15, -2.2, 0.6, 1.45, 2.5, C.frame, { studs = false })
	P("Leg_F", -0.75, 0, -2.2, 0.75, 1.15, -1.9, C.frame, { studs = false })
	P("Leg_B", -0.75, 0, 2.2, 0.75, 1.15, 2.5, C.frame, { studs = false })
	P("FootBar_F", -1.2, 0, -2.35, 1.2, 0.25, -1.75, C.metal, { studs = false })
	P("FootBar_B", -1.2, 0, 2.05, 1.2, 0.25, 2.65, C.metal, { studs = false })
	P("RackBase_L", -2.1, 0, 0.6, -1.2, 0.3, 2.1, C.frame, { studs = false })
	P("RackBase_R", 1.2, 0, 0.6, 2.1, 0.3, 2.1, C.frame, { studs = false })
	P("Upright_L", -1.75, 0.3, 1.2, -1.45, 4.4, 1.5, C.metal, { studs = false })
	P("Upright_R", 1.45, 0.3, 1.2, 1.75, 4.4, 1.5, C.metal, { studs = false })
	P("Hook_L", -1.85, 3.75, 0.85, -1.35, 3.95, 1.2, C.frame, { studs = false })
	P("Hook_R", 1.35, 3.75, 0.85, 1.85, 3.95, 1.2, C.frame, { studs = false })
	local top = P("RackTop", -1.75, 4.4, 1.2, 1.75, 4.6, 1.5, C.metal, { studs = false })
	local bar = group(K, "Barbell")
	local by, bz = y + 4.07, oz + 1.02
	CYL(bar, "Bar", ox, by, bz, 6.2, 0.22, C.chrome)
	for _, s in { -1, 1 } do
		local tag = s < 0 and "L" or "R"
		CYL(bar, "Collar_" .. tag, ox + s * 2.2, by, bz, 0.15, 0.45, C.metal)
		CYL(bar, "Plate_" .. tag .. "1", ox + s * 2.45, by, bz, 0.3, 1.8, C.dark)
		CYL(bar, "Plate_" .. tag .. "2", ox + s * 2.78, by, bz, 0.3, 1.25, C.accent)
	end
	att("UsePoint", mat, ox, y + 0.06, oz - 3.0) -- 0,7 stud devant le coussin : le corps ne le touche pas
	att("UpgradePoint", top, ox - 8.4, y, oz - 4, Vector3.new(0, 0, 1)) -- panneau au sol en (15,6, -50), tourné vers la boutique (Clément, 2026-11-08)
	-- zone d'entrée (Clément, 2026-11-11) : invisible, sans collision ; le code fait asseoir le joueur dès
	-- qu'il y entre. Le banc + 3 studs autour, 8 de haut, arrêtée à 0,2 stud de la façade (z -40).
	local zone = P("UseZone", -6.1, 0, -7.2, 6.1, 8, 5.8, C.white, { studs = false, T = 1, noShadow = true })
	zone.CanCollide = false; zone.CanTouch = true; zone.CanQuery = false
	K.WorldPivot = CFrame.new(ox, y, oz)
	CS:AddTag(K, "Bench")
	return K
end

local function stage(M, n)
	local s = group(M, "Stage_" .. n)
	s.WorldPivot = CFrame.identity
	return s
end

-- Pourtour (côtés, fond, avant hors portique) : { x0, z0, x1, z1 } le long duquel on pose barrières et murets.
local SEGMENTS = {
	{ "L", -31.6, -39.6, -31.6, 39.6 }, { "R", 31.6, -39.6, 31.6, 39.6 }, { "B", -31.6, 39.6, 31.6, 39.6 },
	{ "FL", -31.6, -39.6, -10, -39.6 }, { "FR", 10, -39.6, 31.6, -39.6 },
}

-- Pourtour de la petite boutique du niveau 1 : une seule rangée, z -40..SMALL_Z.
local SZ = P.SMALL_Z - 0.4
local SEGMENTS_SMALL = {
	{ "L", -31.6, -39.6, -31.6, SZ }, { "R", 31.6, -39.6, 31.6, SZ }, { "B", -31.6, SZ, 31.6, SZ },
	{ "FL", -31.6, -39.6, -10, -39.6 }, { "FR", 10, -39.6, 31.6, -39.6 },
}

-- Champ de force léger (matériau ForceField) au-dessus d'un pourtour.
local function forceField(parent, segments, hideFrom)
	local field = group(parent, "ForceField", { HideFromStage = hideFrom })
	for _, sg in segments do
		local name, x0, z0, x1, z1 = sg[1], sg[2], sg[3], sg[4], sg[5]
		local f = B(field, "Field_" .. name, math.min(x0, x1) - 0.05, 3.3, math.min(z0, z1) - 0.05, math.max(x0, x1) + 0.05, 8.5, math.max(z0, z1) + 0.05, C.accent,
			{ mat = Enum.Material.ForceField, decor = true, noShadow = true, T = 0.35, accent = true })
		f.CastShadow = false
	end
	return field
end

-- Niveau 1 : petit stand ouvert d'une seule rangée. Barrière basse, champ de force léger, tapis d'entrée.
-- Les niveaux suivants agrandissent la boutique (le niveau 2 pose la suite du sol jusqu'au fond).
local function buildStage1(M)
	local S = stage(M, 1)
	local rails = group(S, "Railings", { HideFromStage = 2 })
	forceField(S, SEGMENTS_SMALL, 2)
	for _, sg in SEGMENTS_SMALL do
		local name, x0, z0, x1, z1 = sg[1], sg[2], sg[3], sg[4], sg[5]
		local len = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
		local steps = math.max(1, math.floor(len / 5 + 0.5))
		for i = 0, steps do
			local t = i / steps
			local x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
			B(rails, "Post_" .. name .. "_" .. i, x - 0.2, 0.3, z - 0.2, x + 0.2, 3.25, z + 0.2, C.accent, { studs = false, accent = true })
		end
		for k, ry in { 1.6, 3.0 } do
			B(rails, "Rail_" .. name .. "_" .. k, math.min(x0, x1) - 0.12, ry, math.min(z0, z1) - 0.12, math.max(x0, x1) + 0.12, ry + 0.25, math.max(z0, z1) + 0.12, C.chrome, { studs = false })
		end
	end
	local mat = B(S, "EntryMat", -5, 0.32, -38.9, 5, 0.36, -36.4, C.accent, { studs = false, decor = true, noShadow = true, accent = true })
	mat:SetAttribute("HideFromStage", 5)
	label(mat, Enum.NormalId.Top, "WELCOME", C.white, 40)
	return S
end

-- Niveau 2, la boutique s'agrandit : suite du sol jusqu'au fond (z SMALL_Z..40), champ de force sur tout
-- le pourtour, cartons au fond.
local function buildStage2Ext(S)
	B(S, "PlotFloorExt", -32, -0.6, P.SMALL_Z, 32, 0.3, 40, C.accent, { accent = true })
	P.floorTiles(S, "FloorTilesExt", (P.SMALL_Z + 40) / 4, 19)
	forceField(S, SEGMENTS, 3)
	local st = group(S, "Stock")
	B(st, "Pallet_1", -31, 0.32, 19.5, -27, 0.6, 23.5, C.wood, { studs = false })
	for i, c in { { -30.8, 19.7, -28.9, 21.5, 1.6 }, { -28.8, 19.7, -27.2, 21.4, 1.2 }, { -30.6, 21.7, -28.6, 23.3, 1.4 }, { -30.5, 19.9, -29.1, 21.3, 1.0 } } do
		local y0 = (i == 4) and 2.2 or 0.6
		B(st, "Carton_" .. i, c[1], y0, c[2], c[3], y0 + c[5], c[4], C.carton, { studs = false })
	end
	B(st, "Pallet_2", -13, 0.32, 36, -9.5, 0.6, 39, C.wood, { studs = false })
	B(st, "Carton_5", -12.8, 0.6, 36.2, -10.8, 2.0, 38.0, C.carton, { studs = false })
	B(st, "Carton_6", -10.6, 0.6, 36.4, -9.7, 1.5, 38.6, C.carton, { studs = false })
	return S
end

-- Muret le long d'un bord : boîte { x0, z0, x1, z1 } dans l'emprise, plinthe sombre qui dépasse de 0,05.
local MURET_BOXES = { L = { -32, -39, -31, 40 }, R = { 31, -39, 32, 40 }, B = { -31, 39, 31, 40 } }
local function muret(parent, name)
	local m = MURET_BOXES[name]
	B(parent, "Muret_" .. name, m[1], 0.3, m[2], m[3], 3.3, m[4], C.wall)
	B(parent, "MuretCap_" .. name, m[1], 3.3, m[2], m[3], 3.6, m[4], C.accent, { accent = true })
	B(parent, "MuretBase_" .. name, m[1] - 0.05, 0.3, m[2], m[3] + 0.05, 0.9, m[4], C.frame)
end

-- Niveau 2 : murets et rayons garnis (produits sous les présentoirs, têtes de gondole, promo, haltères).
local function buildStage2(M)
	local S = stage(M, 2)
	buildStage2Ext(S)
	local front = group(S, "Murets_Front")
	local sides = group(S, "Murets_Sides", { HideFromStage = 3 })
	for _, sg in SEGMENTS do
		local isFront = sg[1] == "FL" or sg[1] == "FR"
		if isFront then
			-- murets de façade sur z -40..-39, ils restent sous les vitrines du niveau 3
			local a, b
			if sg[1] == "FL" then a, b = -32, -10 else a, b = 10, 32 end
			B(front, "Muret_" .. sg[1], a, 0.3, -40, b, 3.3, -39, C.wall)
			B(front, "MuretCap_" .. sg[1], a, 3.3, -40.1, b, 3.6, -38.9, C.accent, { accent = true })
			B(front, "MuretBase_" .. sg[1], a, 0.3, -40.05, b, 0.9, -38.95, C.frame)
		else
			muret(sides, sg[1])
		end
	end
	local Pr = group(S, "Promo")
	B(Pr, "PromoBin", -14, 0.3, -31, -10, 1.8, -28, C.yellow, { studs = false })
	for k = 0, 2 do
		B(Pr, "PromoPack_" .. k, -13.7 + k * 1.2, 1.8, -30.6, -12.8 + k * 1.2, 2.7, -28.4, ({ C.red, C.accent, C.green })[k + 1], { studs = false, decor = true })
	end
	B(Pr, "PromoPole", -12.05, 2.7, -29.6, -11.95, 4.2, -29.4, C.frame, { studs = false, decor = true })
	local ps = B(Pr, "PromoSign", -13.4, 4.2, -29.6, -10.6, 5.4, -29.4, C.yellow, { studs = false, decor = true })
	label(ps, Enum.NormalId.Front, "SALE", C.red, 60, C.white)
	-- plus de support d'haltères devant la boutique (2026-11-11 : plus de terrasse, le plus simple possible)
	return S
end

-- Niveau 3 : murs pleins, vitrines de façade, rayons muraux.
local function buildStage3(M)
	local S = stage(M, 3)
	local Wl = group(S, "Walls")
	B(Wl, "Wall_L", -32, 0.3, -39, -31, 16.2, 40, C.wall)
	B(Wl, "Wall_R", 31, 0.3, -39, 32, 16.2, 40, C.wall)
	B(Wl, "Wall_B", -31, 0.3, 39, 31, 16.2, 40, C.wall)
	B(Wl, "InnerSkin_L", -31, 0.3, -39, -30.9, 16.1, 39, C.innerWall, { studs = false })
	B(Wl, "InnerSkin_R", 30.9, 0.3, -39, 31, 16.1, 39, C.innerWall, { studs = false })
	B(Wl, "InnerSkin_B", -30.9, 0.3, 38.9, 30.9, 16.1, 39, C.innerWall, { studs = false })
	for _, side in { { "L", -1 }, { "R", 1 } } do
		local s = side[2]
		local a, b = (s < 0) and -32 or 10, (s < 0) and -10 or 32
		B(Wl, "FrontUpper_" .. side[1], a, 12.8, -40, b, 16.2, -39, C.wall)
		B(Wl, "FrontPier_Out_" .. side[1], (s < 0) and -32 or 30, 3.6, -40, (s < 0) and -30 or 32, 12.8, -39, C.wall)
		B(Wl, "FrontPier_In_" .. side[1], (s < 0) and -11 or 10, 3.6, -40, (s < 0) and -10 or 11, 12.8, -39, C.wall)
		local v0, v1 = (s < 0) and -30 or 11, (s < 0) and -11 or 30
		B(Wl, "Vitrine_" .. side[1], v0, 3.6, -39.7, v1, 12.3, -39.3, C.glass, { mat = Enum.Material.Glass, T = 0.55 })
		B(Wl, "VitrineTransom_" .. side[1], v0, 12.3, -39.8, v1, 12.8, -39.2, C.frame, { studs = false })
		B(Wl, "VitrineSill_" .. side[1], v0, 3.6, -39.85, v1, 3.8, -39.15, C.frame, { studs = false })
		for k = 1, 3 do
			local x = v0 + (v1 - v0) * k / 4
			B(Wl, "Mullion_" .. side[1] .. k, x - 0.2, 3.8, -39.8, x + 0.2, 12.3, -39.2, C.frame, { studs = false })
		end
	end
	B(Wl, "InnerBand_L", -30.9, 9.5, -39, -30.8, 10.1, 39, C.accent, { studs = false, decor = true, accent = true })
	B(Wl, "InnerBand_R", 30.8, 9.5, -39, 30.9, 10.1, 39, C.accent, { studs = false, decor = true, accent = true })
	B(Wl, "InnerBand_B", -30.9, 9.5, 38.8, 30.9, 10.1, 38.9, C.accent, { studs = false, decor = true, accent = true })
	local pil = group(S, "Pilasters", { HideFromStage = 5 })
	B(pil, "Pilaster_L", -32.05, 0.3, -40.4, -30.8, 16.5, -39.3, C.accent, { accent = true })
	B(pil, "Pilaster_R", 30.8, 0.3, -40.4, 32.05, 16.5, -39.3, C.accent, { accent = true })
	-- rayons muraux (3 étages, 5 studs de haut, comme les magasins PNJ)
	local WS = group(S, "WallShelves")
	local WALL_HEADERS = { L = { "PERSONAL CARE", C.accent }, R = { "GROCERY", C.green } }
	for _, side in { { "L", -30.9, 1 }, { "R", 30.9, -1 } } do
		local wx, s = side[2], side[3]
		local fx = wx + s * 2
		local name = side[1]
		local function X(a, b) return math.min(wx + s * a, wx + s * b), math.max(wx + s * a, wx + s * b) end
		local bx0, bx1 = X(0, 0.15)
		B(WS, "Back_" .. name, bx0, 0.3, -24, bx1, 5.0, 18, C.shelfBack, { studs = false })
		local kx0, kx1 = X(0, 2)
		B(WS, "Kick_" .. name, kx0, 0.3, -24, kx1, 0.6, 18, C.kick, { studs = false })
		for li, ly in { 1.85, 3.6 } do
			B(WS, "Board_" .. name .. li, kx0, ly - 0.15, -24, kx1, ly, 18, C.shelf, { studs = false })
			local px0, px1 = X(2, 2.06)
			B(WS, "Price_" .. name .. li, px0, ly - 0.15, -24, px1, ly, 18, C.price, { studs = false, decor = true })
			products(WS, "Prod_" .. name .. li, fx, s, -23.8, 17.8, ly, (li == 1) and 1.45 or 1.15)
		end
		local z = -23.8
		local k = 0
		while z < 17 do
			k += 1
			local pair = PRODUCT_COLORS[(k * 5) % #PRODUCT_COLORS + 1]
			local qx0, qx1 = X(0.2, 1.9)
			B(WS, "Bulk_" .. name .. "_" .. k, qx0, 0.6, z, qx1, 1.5, z + 1.6, pair[1], { studs = false, decor = true, noShadow = true })
			z += 1.75
		end
		B(WS, "Top_" .. name, kx0, 4.85, -24, kx1, 5.0, 18, C.shelf, { studs = false })
		B(WS, "EndA_" .. name, kx0, 0.3, -24.2, kx1, 5.0, -24, C.shelf, { studs = false })
		B(WS, "EndB_" .. name, kx0, 0.3, 18, kx1, 5.0, 18.2, C.shelf, { studs = false })
		local hx0, hx1 = X(0.05, 0.3)
		local hdr = B(WS, "Header_" .. name, hx0, 5.4, -20, hx1, 6.6, 14, WALL_HEADERS[name][2], { studs = false, decor = true })
		label(hdr, (s > 0) and Enum.NormalId.Right or Enum.NormalId.Left, WALL_HEADERS[name][1], C.white, 40)
	end
	return S
end

P.buildTreadmill, P.buildBench, P.stage = buildTreadmill, buildBench, stage
P.buildStage1, P.buildStage2, P.buildStage3 = buildStage1, buildStage2, buildStage3

-- ===== Morceau 4 : niveaux 4 à 6 =====
local P = _G.ClaudePlotShopParts
local rgb, C, B, CYL, group, label, light, stage = P.rgb, P.C, P.B, P.CYL, P.group, P.label, P.light, P.stage
local NEON = Enum.Material.Neon

-- Niveau 4 : toit et plafond éclairé, enseigne lumineuse, rideau de fer apparent, auvents.
local function buildStage4(M)
	local S = stage(M, 4)
	local R = group(S, "Roof")
	B(R, "RoofSlab", -32, 16.2, -40, 32, 17.0, 40, C.metal)
	B(R, "Ceiling", -30.9, 16.1, -39, 30.9, 16.2, 38.9, C.ceiling, { studs = false, decor = true, noShadow = true })
	for _, p in { { "Parapet_F", -32, -40.3, 32, -39.7 }, { "Parapet_B", -32, 39.4, 32, 40 }, { "Parapet_L", -32, -39.7, -31.4, 39.4 }, { "Parapet_R", 31.4, -39.7, 32, 39.4 } } do
		B(R, p[1], p[2], 17.0, p[3], p[4], 18.0, p[5], C.wall)
	end
	for i, ac in { { -18, 10 }, { 0, 22 }, { 18, 4 } } do
		B(R, "AC_" .. i, ac[1] - 2, 17.0, ac[2] - 1.6, ac[1] + 2, 19.2, ac[2] + 1.6, C.metal2)
		B(R, "AC_" .. i .. "_Fan", ac[1] - 1.1, 19.2, ac[2] - 0.9, ac[1] + 1.1, 19.35, ac[2] + 0.9, C.frame, { studs = false })
	end
	local L = group(S, "CeilingLights")
	for i, x in { -14.5, 0, 14.5 } do
		light(B(L, "Neon_" .. i, x - 0.4, 15.7, -30, x + 0.4, 16.0, 30, C.neon, { mat = NEON, decor = true, noShadow = true }), 26, 0.45)
	end
	light(B(L, "Neon_Front", -26, 15.7, -35, 26, 16.0, -34.2, C.neon, { mat = NEON, decor = true, noShadow = true }), 24, 0.4)
	light(B(L, "Neon_Back", -26, 15.7, 32, 26, 16.0, 32.8, C.neon, { mat = NEON, decor = true, noShadow = true }), 24, 0.4)
	local SN = group(S, "SignNeon", { HideFromStage = 5 })
	for i, b in { { -8.4, 21.35, 8.4, 21.65 }, { -8.4, 16.15, 8.4, 16.45 }, { -8.4, 16.15, -8.15, 21.65 }, { 8.15, 16.15, 8.4, 21.65 } } do
		B(SN, "SignTube_" .. i, b[1], b[2], -41.05, b[3], b[4], -40.75, C.accent, { mat = NEON, studs = false, decor = true, accent = true })
	end
	local SLi = group(S, "SignLights")
	for i, x in { -5.5, 5.5 } do
		B(SLi, "LampArm_" .. i, x - 0.1, 22.1, -41.9, x + 0.1, 22.3, -40.5, C.frame, { studs = false, decor = true })
		local lamp = B(SLi, "Lamp_" .. i, -0.3, -0.3, -0.4, 0.3, 0.3, 0.4, C.frame, { studs = false, decor = true })
		lamp.CFrame = CFrame.lookAt(Vector3.new(x, 22.1, -42.0), Vector3.new(x * 0.6, 18.3, -40.6))
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front; spot.Range = 10; spot.Angle = 70; spot.Brightness = 1.5; spot.Shadows = false
		spot.Color = rgb(255, 244, 220)
		spot.Parent = lamp
	end
	local open = B(S, "OpenSign", -21, 8.6, -38.95, -15, 10.4, -38.8, C.dark, { studs = false, decor = true })
	label(open, Enum.NormalId.Front, "OPEN", C.red, 40, C.white)
	local SR = group(S, "ShutterRails") -- restent au Flagship depuis le retrait du cadre de coffre (L-086)
	B(SR, "ShutterRail_L", -9.9, 0, -40.8, -9.5, 11.1, -40.5, C.metal2, { studs = false })
	B(SR, "ShutterRail_R", 9.5, 0, -40.8, 9.9, 11.1, -40.5, C.metal2, { studs = false })
	B(SR, "ShutterHousing", -10.1, 11.1, -40.85, 10.1, 12.0, -40.6, C.metal, { studs = false, mat = Enum.Material.DiamondPlate })
	local A = group(S, "Awnings")
	local run, drop = 2.4, 1.0
	local len = math.sqrt(run * run + drop * drop)
	for _, aw in { { "L", -30, -11 }, { "R", 11, 30 } } do
		local n = 8
		local w = (aw[3] - aw[2]) / n
		for i = 0, n - 1 do
			local striped = i % 2 == 0
			local col = striped and C.accent or C.white
			local cx = aw[2] + w * (i + 0.5)
			local p = B(A, string.format("Stripe_%s%02d", aw[1], i + 1), -w / 2, -0.075, -len / 2, w / 2, 0.075, len / 2, col, { studs = false, decor = true, accent = striped })
			p.CFrame = CFrame.new(cx, 13.4 - drop / 2, -40 - run / 2) * CFrame.Angles(-math.atan2(drop, run), 0, 0)
			B(A, string.format("Valance_%s%02d", aw[1], i + 1), cx - w / 2, 11.75, -42.48, cx + w / 2, 12.4, -42.36, col, { studs = false, decor = true, accent = striped })
		end
	end
	return S
end

-- Caméra de surveillance (décor) : support au mur en `wall`, boîtier en `pos`, objectif vers `target`.
local function camera(parent, name, wall, pos, target)
	local plate = B(parent, name .. "_Plate", -0.35, -0.35, -0.1, 0.35, 0.35, 0.1, C.frame, { studs = false, decor = true })
	plate.CFrame = CFrame.lookAt(wall, pos)
	local arm = B(parent, name .. "_Arm", -0.08, -0.08, 0, 0.08, 0.08, (pos - wall).Magnitude, C.frame, { studs = false, decor = true })
	arm.CFrame = CFrame.lookAt(wall, pos) * CFrame.new(0, 0, -(pos - wall).Magnitude / 2)
	local body = B(parent, name .. "_Body", -0.35, -0.35, -0.8, 0.35, 0.35, 0.8, C.white, { studs = false, decor = true })
	body.CFrame = CFrame.lookAt(pos, target)
	local lens = B(parent, name .. "_Lens", -0.24, -0.24, -0.08, 0.24, 0.24, 0.08, C.dark, { studs = false, decor = true })
	lens.CFrame = body.CFrame * CFrame.new(0, 0, -0.86)
	local led = B(parent, name .. "_LED", -0.07, -0.07, -0.07, 0.07, 0.07, 0.07, C.red, { studs = false, decor = true, mat = NEON })
	led.CFrame = body.CFrame * CFrame.new(0.2, 0.36, -0.55)
end

-- Sécurité du Flagship (niveau 5) : clavier sur la colonne droite de la porte, caméras (décor), alarme.
local function buildSecurity(S)
	local SEC = group(S, "Security")
	B(SEC, "Keypad", 10.2, 3.6, -41.1, 11.1, 4.9, -40.9, C.dark, { studs = false, decor = true })
	B(SEC, "KeypadScreen", 10.35, 4.3, -41.15, 10.95, 4.7, -41.1, C.green, { studs = false, decor = true, mat = NEON })
	local CAM = group(S, "Cameras")
	camera(CAM, "Cam_FrontL", Vector3.new(-27, 15.2, -40.0), Vector3.new(-27, 14.8, -40.9), Vector3.new(-20, 0, -54))
	camera(CAM, "Cam_FrontR", Vector3.new(27, 15.2, -40.0), Vector3.new(27, 14.8, -40.9), Vector3.new(20, 0, -54))
	camera(CAM, "Cam_BackL", Vector3.new(-30.9, 15.0, 38.0), Vector3.new(-30.1, 14.6, 37.3), Vector3.new(0, 2, 0))
	camera(CAM, "Cam_BackR", Vector3.new(30.9, 15.0, 38.0), Vector3.new(30.1, 14.6, 37.3), Vector3.new(0, 2, 0))
	camera(CAM, "Cam_Door", Vector3.new(4.5, 14.8, -38.5), Vector3.new(4.5, 14.4, -37.7), Vector3.new(0, 2, -14))
	local AL = group(S, "Alarm")
	B(AL, "AlarmBase", 26.8, 18.0, -40.3, 28.2, 18.4, -39.7, C.frame, { studs = false, decor = true })
	local dome = B(AL, "AlarmDome", 27.0, 18.4, -40.2, 28.0, 19.2, -39.8, C.red, { studs = false, decor = true, mat = NEON })
	light(dome, 10, 0.6, rgb(255, 60, 60))
end

-- Niveau 5, Flagship : façade de luxe (marbre et or),
-- sécurité (clavier, caméras, alarme), tapis rouge, lustres, palmiers.
local function buildStage5(M)
	local S = stage(M, 5)
	local marble = Enum.Material.Marble
	local F = group(S, "LuxFacade")
	for _, side in { { "L", -31, -11.3 }, { "R", 11.3, 31 } } do
		B(F, "MarbleBand_" .. side[1], side[2], 12.8, -40.3, side[3], 16.2, -40.0, C.marble, { mat = marble })
		B(F, "GoldLine_Low_" .. side[1], side[2], 12.8, -40.4, side[3], 13.05, -40.3, C.gold, { studs = false })
		B(F, "GoldLine_High_" .. side[1], side[2], 15.9, -40.4, side[3], 16.15, -40.3, C.gold, { studs = false })
	end
	for i, cx in { -31.25, -10.65, 10.65, 31.25 } do
		local w = (math.abs(cx) > 20) and 0.75 or 0.65
		B(F, "Column_" .. i, cx - w, 0.3, -40.9, cx + w, 16.2, -40.0, C.marble, { mat = marble })
		B(F, "ColumnBase_" .. i, cx - w - 0.2, 0.3, -41.1, cx + w + 0.2, 1.2, -39.95, C.gold, { studs = false })
		B(F, "ColumnCap_" .. i, cx - w - 0.2, 15.3, -41.1, cx + w + 0.2, 16.2, -39.95, C.gold, { studs = false })
	end
	-- corniche de part et d'autre du grand linteau ; couronne de marbre et diamant posés sur le linteau
	for _, side in { { "L", -32.3, -10.1 }, { "R", 10.1, 32.3 } } do
		B(F, "Cornice_" .. side[1], side[2], 16.2, -41.0, side[3], 17.4, -39.6, C.marble, { mat = marble })
		B(F, "CorniceGold_" .. side[1], side[2] + (side[2] < 0 and -0.05 or 0), 17.4, -41.05, side[3] + (side[3] > 0 and 0.05 or 0), 17.7, -39.55, C.gold, { studs = false })
	end
	B(F, "Crown", -10.3, 22.7, -40.9, 10.3, 23.3, -38.2, C.marble, { mat = marble })
	B(F, "CrownGold", -10.4, 23.3, -40.95, 10.4, 23.55, -38.15, C.gold, { studs = false })
	local dia = B(F, "Diamond", -1.1, -1.1, -0.15, 1.1, 1.1, 0.15, C.gold, { studs = false, decor = true, mat = NEON })
	dia.CFrame = CFrame.new(0, 25.15, -39.5) * CFrame.Angles(0, 0, math.rad(45))
	local SG = group(S, "SignGold")
	for i, b in { { -8.6, 21.4, 8.6, 21.85 }, { -8.6, 15.95, 8.6, 16.4 }, { -8.6, 15.95, -8.15, 21.85 }, { 8.15, 15.95, 8.6, 21.85 } } do
		B(SG, "GoldFrame_" .. i, b[1], b[2], -41.1, b[3], b[4], -40.75, C.gold, { studs = false })
	end
	for k = 0, 9 do
		local x = -7.65 + k * 1.7
		B(SG, "Bulb_T" .. k, x - 0.13, 21.5, -41.22, x + 0.13, 21.75, -41.1, C.yellow, { studs = false, decor = true, mat = NEON })
		B(SG, "Bulb_B" .. k, x - 0.13, 16.05, -41.22, x + 0.13, 16.3, -41.1, C.yellow, { studs = false, decor = true, mat = NEON })
	end
	-- plus de coffre-fort autour de la porte (L-086, 2026-11-08) : VaultFrame et VaultDoor retirés
	-- tapis rouge et poteaux à corde
	local RC = group(S, "RedCarpet")
	B(RC, "Carpet", -3, 0.32, -39, 3, 0.36, -24, C.velvet, { studs = false, decor = true, noShadow = true, mat = Enum.Material.Fabric })
	B(RC, "CarpetEdge_L", -3.2, 0.32, -39, -3, 0.37, -24, C.gold, { studs = false, decor = true, noShadow = true })
	B(RC, "CarpetEdge_R", 3, 0.32, -39, 3.2, 0.37, -24, C.gold, { studs = false, decor = true, noShadow = true })
	for k, z in { -36, -31, -26 } do
		for _, s in { -1, 1 } do
			local tag = (s < 0 and "L" or "R") .. k
			B(RC, "Stanchion_" .. tag, s * 3.9 - 0.15, 0.3, z - 0.15, s * 3.9 + 0.15, 3.0, z + 0.15, C.gold, { studs = false })
			B(RC, "StanchionTop_" .. tag, s * 3.9 - 0.25, 3.0, z - 0.25, s * 3.9 + 0.25, 3.25, z + 0.25, C.gold, { studs = false, decor = true })
			if k < 3 then
				B(RC, "Rope_" .. tag, s * 3.9 - 0.08, 2.5, z, s * 3.9 + 0.08, 2.66, z + 5, C.velvet, { studs = false, decor = true })
			end
		end
	end
	-- lustres au-dessus de l'allée centrale
	local CH = group(S, "Chandeliers")
	for i, z in { -12, 4 } do
		B(CH, "ChainRod_" .. i, -0.08, 13.6, z - 0.08, 0.08, 16.1, z + 0.08, C.gold, { studs = false, decor = true })
		local ring = CYL(CH, "Ring_" .. i, 0, 13.4, z, 0.3, 3.2, C.gold, { decor = true })
		ring.CFrame = CFrame.new(0, 13.4, z) * CFrame.Angles(0, 0, math.rad(90))
		for k = 0, 3 do
			local a = math.rad(k * 90 + 45)
			local cx, cz = 1.3 * math.cos(a), z + 1.3 * math.sin(a)
			B(CH, "Crystal_" .. i .. k, cx - 0.18, 12.5, cz - 0.18, cx + 0.18, 13.25, cz + 0.18, rgb(220, 240, 255), { studs = false, decor = true, mat = NEON })
		end
		light(B(CH, "Bulb_" .. i, -0.3, 12.8, z - 0.3, 0.3, 13.3, z + 0.3, rgb(255, 236, 190), { studs = false, decor = true, mat = NEON }), 22, 0.6, rgb(255, 230, 190))
	end
	-- palmiers en pot de part et d'autre de l'entrée
	local PL = group(S, "Palms")
	for _, x in { -12.5, 12.5 } do
		local tag = x < 0 and "L" or "R"
		B(PL, "Pot_" .. tag, x - 0.8, 0.3, -34.3, x + 0.8, 1.9, -32.7, C.gold, { studs = false })
		B(PL, "Trunk_" .. tag, x - 0.25, 1.9, -33.75, x + 0.25, 6.2, -33.25, C.woodDark, { studs = false, decor = true })
		for k = 0, 3 do
			local leaf = B(PL, "Frond_" .. tag .. k, -0.25, -0.08, 0, 0.25, 0.08, 2.4, C.leaf, { studs = false, decor = true })
			leaf.CFrame = CFrame.new(x, 6.2, -33.5) * CFrame.Angles(0, math.rad(k * 90 + 45), 0) * CFrame.Angles(math.rad(25), 0, 0) * CFrame.new(0, 0, 1.2)
		end
	end
	buildSecurity(S)
	return S
end

P.buildStage4, P.buildStage5 = buildStage4, buildStage5

------------------------------------------------------------------------------------------------
-- ===== Morceau 5 : construction du gabarit, installation, aperçu, vérification =====
------------------------------------------------------------------------------------------------
local P = _G.ClaudePlotShopParts
local CS, RS, ACCENTS = P.CS, P.RS, P.ACCENTS
local buildCore, buildInterior, buildTreadmill, buildBench = P.buildCore, P.buildInterior, P.buildTreadmill, P.buildBench
local buildStage1, buildStage2, buildStage3 = P.buildStage1, P.buildStage2, P.buildStage3
local buildStage4, buildStage5 = P.buildStage4, P.buildStage5

local function plotsFolder()
	local assets = RS:FindFirstChild("Assets")
	assert(assets, "ReplicatedStorage/Assets introuvable")
	local f = assets:FindFirstChild("Plots")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Plots"
		f.Parent = assets
	end
	return f
end

-- Socle de l'objet le plus rare, devant la façade, entre la porte et le banc, bien en vue de l'allée.
-- Socle sombre, tambour blanc, colonne, plateau ; anneaux néon et lumière à la couleur de la boutique.
local function buildRarest(M)
	local B, CYL, C, att, light = P.B, P.CYL, P.C, P.att, P.light
	local NEON = Enum.Material.Neon
	local X, Z = 7.5, -48.5 -- à gauche de la porte vu de l'allée, côté banc (Clément : dégage la vue sur le panneau du banc)
	local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylindre debout
	local R = P.group(M, "RarestPedestal")
	local function drum(name, y0, y1, d, color, opt)
		opt = opt or {}
		opt.rot = UP
		return CYL(R, name, X, (y0 + y1) / 2, Z, y1 - y0, d, color, opt)
	end
	B(R, "Plinth", X - 2.8, 0.3, Z - 2.8, X + 2.8, 0.9, Z + 2.8, C.dark, { studs = false })
	for _, e in { { "F", -2.8, -2.8, 2.8, -2.55 }, { "B", -2.8, 2.55, 2.8, 2.8 }, { "L", -2.8, -2.55, -2.55, 2.55 }, { "R", 2.55, -2.55, 2.8, 2.55 } } do
		B(R, "PlinthNeon_" .. e[1], X + e[2], 0.9, Z + e[3], X + e[4], 1.02, Z + e[5], C.accent,
			{ studs = false, decor = true, noShadow = true, mat = NEON, accent = true })
	end
	for _, c in { { "FL", -1, -1 }, { "FR", 1, -1 }, { "BL", -1, 1 }, { "BR", 1, 1 } } do
		local cx, cz = X + c[2] * 2.35, Z + c[3] * 2.35
		B(R, "CornerGem_" .. c[1], cx - 0.2, 0.9, cz - 0.2, cx + 0.2, 1.4, cz + 0.2, C.gold, { studs = false, decor = true })
	end
	drum("Drum", 0.9, 1.6, 4.4, C.white)
	drum("DrumNeon", 1.6, 1.75, 4.6, C.accent, { mat = NEON, decor = true, noShadow = true, accent = true })
	drum("Column", 1.75, 2.95, 3.4, C.dark)
	drum("TopNeon", 2.95, 3.15, 4.2, C.accent, { mat = NEON, decor = true, noShadow = true, accent = true })
	local top = drum("TopPlate", 3.15, 3.35, 3.9, C.white)
	att("RarestSlot", top, X, 3.35, Z) -- l'objet, posé debout, face à la rue (-Z)
	att("RarestLabelPoint", top, X, 9.35, Z)
	local l = light(top, 12, 1.6, C.accent)
	l:SetAttribute("Accent", true) -- recoloré par install, comme les pièces
	R:PivotTo(R:GetPivot() - Vector3.new(0, 0.3, 0)) -- posé sur le sol du hub (plus de terrasse)
	return R
end

-- (Re)construit ReplicatedStorage/Assets/Plots/PLOT_Shop, morceau par morceau (task.wait entre deux).
local function build()
	P.setSeed(4242)
	local folder = plotsFolder()
	for _, n in { "PLOT_Shop", "PLOT_Shop_Rayons" } do
		local old = folder:FindFirstChild(n)
		if old then old:Destroy() end
	end
	local M = Instance.new("Model")
	M.Name = "PLOT_Shop"
	M.Parent = folder
	-- visuels des rangées 2 à 5, rangés à côté du gabarit, même repère (L-082)
	local store = Instance.new("Model")
	store.Name = "PLOT_Shop_Rayons"
	local steps = {
		buildCore, function(t) buildInterior(t, store) end,
		function(t) buildTreadmill(t, -24, -46); buildBench(t, 24, -46) end, -- devant la façade, hors des murs
		buildRarest,
		buildStage1, buildStage2, buildStage3, buildStage4, buildStage5,
	}
	for _, step in steps do
		local tmp = Instance.new("Model")
		step(tmp)
		for _, c in tmp:GetChildren() do c.Parent = M end
		tmp:Destroy()
		task.wait()
	end
	-- Tout ce qui n'existe qu'à partir du niveau 2 (FromStage 2) passe dans Stage_2 (2026-11-11) : le code
	-- n'a ainsi qu'à copier Stage_2 à Stage_k depuis ce gabarit quand le rayon k arrive (voir install).
	local s2 = M:FindFirstChild("Stage_2")
	local barriers = Instance.new("Model")
	barriers.Name = "Barriers"
	barriers.Parent = s2
	for _, d in M:GetDescendants() do
		if d:GetAttribute("FromStage") == 2 and not d:IsDescendantOf(s2) then
			d:SetAttribute("FromStage", nil)
			d.Parent = d:IsA("BasePart") and barriers or s2
		end
	end
	local pad = M:FindFirstChild("CashPad")
	CS:AddTag(pad, "CashPad")
	M.WorldPivot = CFrame.identity
	CS:AddTag(M, "PlayerPlot")
	store.WorldPivot = CFrame.identity
	store.Parent = folder
	return M, store
end

-- Garde les niveaux 1 à s d'une boutique installée (jamais du gabarit) : retire les Stage_k au-dessus
-- et les pièces dont HideFromStage <= s (FromStage : anciennes versions du gabarit).
local function preview(m, s)
	assert(not m:IsDescendantOf(plotsFolder()), "preview ne touche pas au gabarit : installe d'abord une copie")
	s = math.clamp(math.floor(s or 1), 1, 5)
	for k = s + 1, 5 do
		local st = m:FindFirstChild("Stage_" .. k)
		if st then st:Destroy() end
	end
	for _, d in m:GetDescendants() do
		local h, f = d:GetAttribute("HideFromStage"), d:GetAttribute("FromStage")
		if (type(h) == "number" and h <= s) or (type(f) == "number" and f > s) then d:Destroy() end
	end
	return m
end

-- Montre la rangée k (2 à 5) d'une boutique : copie ses visuels depuis PLOT_Shop_Rayons dans Rayon_k
-- et retire le contour RayonSpot_k. La boutique doit être encore au pivot du gabarit, ou on suit son pivot.
local function showRayon(m, k)
	local store = plotsFolder():FindFirstChild("PLOT_Shop_Rayons")
	local src = store and store:FindFirstChild(string.format("Rayon_%02d", k))
	local dst = m:FindFirstChild(string.format("Rayon_%02d", k))
	if not (src and dst) then return end
	local copy = src:Clone()
	copy:PivotTo(m:GetPivot())
	for _, c in copy:GetChildren() do c.Parent = dst end
	copy:Destroy()
	local spot = m:FindFirstChild(string.format("RayonSpot_%02d", k), true)
	if spot then spot:Destroy() end
end

-- Pose une boutique : copie du gabarit, PlotIndex, numéro SHOP n, couleur d'accent, niveau d'aperçu.
-- opts = { index = 1..6, cframe = CFrame (pivot au sol, avant vers -Z local), parent = Instance,
--          stage = 1..5 (défaut 1), accent = Color3 (défaut : une couleur par numéro), name = texte }
local function install(opts)
	opts = opts or {}
	local index = opts.index
	assert(type(index) == "number" and index >= 1 and index <= 6 and index % 1 == 0, "index = PlotIndex de 1 à 6")
	local tpl = plotsFolder():FindFirstChild("PLOT_Shop") or build()
	local m = tpl:Clone()
	m.Name = opts.name or string.format("PLOT_Shop_%02d", index)
	m:SetAttribute("PlotIndex", index)
	local accent = opts.accent or ACCENTS[index]
	m:SetAttribute("AccentColor", accent) -- le code recolore les Stage_k qu'il copie (pièces Accent = true)
	local num = m:FindFirstChild("PlotNumberLabel", true)
	if num then num.Text = "SHOP " .. index end
	local stage = math.clamp(math.floor(opts.stage or 1), 1, 5)
	preview(m, stage)
	-- rayons = n (défaut 1, comme en jeu au départ) : montre les visuels des rangées 2 à n, pour un
	-- aperçu. Les DisplaySlot_05 à _20 restent toujours dans la boutique (contrat).
	local rayons = math.clamp(math.floor(opts.rayons or 1), 1, 5)
	for k = 2, rayons do showRayon(m, k) end
	for _, d in m:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Light")) and d:GetAttribute("Accent") then d.Color = accent end
	end
	m:PivotTo(opts.cframe or CFrame.identity)
	local parent = opts.parent or workspace
	local old = parent:FindFirstChild(m.Name)
	if old and old:IsA("Model") and old:FindFirstChild("PlotBarrier") then old:Destroy() end -- ancienne pose de ce script
	m.Parent = parent
	return m
end

-- Triangles estimés des primitives Roblox (bloc 12, coin 8, cylindre 96, boule 400) ; maillages comptés à part.
local SHAPE_TRIS = { Block = 12, Wedge = 8, CornerWedge = 8, Cylinder = 96, Ball = 400 }
local function partTris(p)
	if p:IsA("Part") then return SHAPE_TRIS[p.Shape.Name] or 12 end
	if p:IsA("WedgePart") or p:IsA("CornerWedgePart") then return 8 end
	if p:IsA("MeshPart") then return 18 end -- éclats de WIN_M_Fractured : 656 triangles pour 36
	return 12
end

-- Vérifie une boutique (gabarit ou copie) : contrat 10.4 (Contract/Models), scripts, triangles visibles.
local function check(m)
	local Models = require(RS.Shared.Contract.Models)
	local out, problems = {}, {}
	local function findAll(root, name)
		local found = {}
		for _, d in root:GetDescendants() do if d.Name == name then table.insert(found, d) end end
		return found
	end
	local function checkSpec(root, spec)
		for _, part in spec.Parts do
			local names = {}
			if part.From then
				for i = part.From, part.To do table.insert(names, string.format(part.Name, i)) end
			else
				names = { part.Name }
			end
			for _, n in names do
				local found = findAll(root, n)
				if #found == 0 then table.insert(problems, root.Name .. " : manque " .. n)
				elseif #found > 1 then table.insert(problems, root.Name .. " : " .. n .. " en " .. #found .. " exemplaires")
				else
					local f = found[1]
					if part.Class and not f:IsA(part.Class) then table.insert(problems, n .. " n'est pas un " .. part.Class) end
					if part.Tag and not (CS:HasTag(f, part.Tag) or #(function() local t = {}; for _, d in f:GetDescendants() do if CS:HasTag(d, part.Tag) then table.insert(t, d) end end; return t end)() > 0) then
						table.insert(problems, n .. " sans le tag " .. part.Tag)
					end
				end
			end
		end
	end
	checkSpec(m, Models.Plot)
	if not CS:HasTag(m, "PlayerPlot") then table.insert(problems, "boutique sans le tag PlayerPlot") end
	for _, key in { "Treadmill", "Bench" } do
		local machine = m:FindFirstChild(key)
		if machine then checkSpec(machine, Models[key]) end
		if not (machine and CS:HasTag(machine, key)) then table.insert(problems, key .. " sans son tag") end
	end
	for n = 1, 20 do
		-- une case par présentoir montré (les rangées 2 à 5 n'ont leurs visuels qu'une fois montrées)
		local stand = m:FindFirstChild(string.format("DisplayStand_%02d", n), true)
		local pad = m:FindFirstChild(string.format("CollectPad_%02d", n), true)
		if stand and not pad then table.insert(problems, "manque CollectPad_" .. n) end
		if stand and pad and pad.Parent ~= stand.Parent then table.insert(problems, "CollectPad_" .. n .. " hors de son rayon") end
	end
	for _, n in { "Safe", "Workbenches", "VaultFrame", "VaultDoor" } do
		if m:FindFirstChild(n, true) then table.insert(problems, n .. " encore là (L-086)") end
	end
	local shards = 0
	for _, d in m.PlotDoor.WindowFractured:GetDescendants() do if d.Name:match("^Shard_%d+$") then shards += 1 end end
	if shards < 30 or shards > 40 then table.insert(problems, "WindowFractured : " .. shards .. " éclats") end
	local scripts, parts, visible, tris, hiddenTris = 0, 0, 0, 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then scripts += 1 end
		if d:IsA("BasePart") then
			parts += 1
			if d.Transparency < 1 then visible += 1; tris += partTris(d) else hiddenTris += partTris(d) end
		end
	end
	if scripts > 0 then table.insert(problems, scripts .. " script(s) dans le modèle") end
	local machineTris = {}
	for _, key in { "Treadmill", "Bench" } do
		local n = 0
		local machine = m:FindFirstChild(key)
		if machine then for _, d in machine:GetDescendants() do if d:IsA("BasePart") then n += partTris(d) end end end
		machineTris[key] = n
	end
	local stages = {}
	for k = 1, 5 do
		local st = m:FindFirstChild("Stage_" .. k)
		local n = 0
		if st then for _, d in st:GetDescendants() do if d:IsA("BasePart") and d.Transparency < 1 then n += partTris(d) end end end
		stages[k] = n
	end
	table.insert(out, string.format("%s : %d pièces (%d visibles), ~%d triangles visibles (+%d cachés), %d script(s)", m.Name, parts, visible, tris, hiddenTris, scripts))
	table.insert(out, string.format("tapis ~%d, banc ~%d triangles ; Stage_1..5 : %s", machineTris.Treadmill, machineTris.Bench, table.concat(stages, ", ")))
	table.insert(out, #problems == 0 and "contrat 10.4 : OK" or ("PROBLÈMES : " .. table.concat(problems, " | ")))
	return table.concat(out, "\n"), problems
end

_G.ClaudePlotShop = { build = build, install = install, preview = preview, showRayon = showRayon, check = check, accents = ACCENTS }
return "ClaudePlotShop chargé : build, install, preview, check"
