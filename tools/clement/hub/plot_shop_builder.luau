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
	Treadmill et Bench déjà posés, pas de PlotIndex (posé par install). 64 x 80 studs
	(x -32..32, z -40..40), pivot en bas au centre, avant vers -Z.

	Contrat 10.4 (cœur, présent à tous les niveaux) : Window (porte vitrée à 2 vantaux Leaf_L et
	Leaf_R, 12 x 7 x 0,4 comme WIN_M), WindowFractured (copie de WIN_M_Fractured, cachée),
	Shutter (caché dans le linteau, descend de 7,8), ShutterButton, DisplaySlot_01 à _20,
	VaultSlot_01 à _03, UnboxBench_01 à _04, TrapSlot_01 à _04, CashPad, DepositZone,
	Treadmill (UsePoint, Belt, UpgradePoint), Bench (UsePoint, UpgradePoint), NameSign/OwnerName,
	SpawnPoint, Bounds.

	Noms proposés (à valider par Ironix) :
	- Stage_1 à Stage_5 : Models, enfants directs de la boutique, pivot = pivot de la boutique.
	  Décor ajouté à chaque niveau, cumulatif : au niveau n, Stage_1 à Stage_n sont là. Les 5 niveaux
	  du doc (Partie 2, section 2) : Stand, Boutique, Magasin, Concept store, Flagship.
	- Attribut HideFromStage (nombre) : la pièce ou le groupe disparaît à partir de ce niveau
	  (remplacé par un niveau plus haut).
	- PlotDoor : Model de l'entrée (portique, Window, WindowFractured, Shutter, ShutterButton,
	  NameSign). Window/Leaf_L et Window/Leaf_R : les vantaux que le code peut faire coulisser
	  pour le propriétaire.
	- PlotBarrier : Model de murs invisibles (côtés, fond, avant hors porte, couvercle) ; le code
	  les rend franchissables pour le propriétaire seul. Les autres entrent en cassant Window.
	- StageUpgradePoint : Attachment où flotte l'achat du niveau suivant.
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
local ACCENTS = {
	rgb(46, 166, 242), rgb(53, 201, 59), rgb(155, 92, 246),
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

-- Les 20 présentoirs, dans l'ordre de déblocage (les 4 premiers près de l'entrée, 7.5) :
-- îlots A (x -21,5), B (-7,5), C (7,5), D (21,5) ; rangées z -20, -13, -6, 1, 8.
local ISLANDS = { -21.5, -7.5, 7.5, 21.5 }
local ROWS = { -20, -13, -6, 1, 8 }
local SLOT_ORDER = {
	{ 2, 1 }, { 3, 1 }, { 2, 2 }, { 3, 2 }, { 1, 1 }, { 4, 1 }, { 1, 2 }, { 4, 2 }, { 2, 3 }, { 3, 3 },
	{ 1, 3 }, { 4, 3 }, { 2, 4 }, { 3, 4 }, { 1, 4 }, { 4, 4 }, { 2, 5 }, { 3, 5 }, { 1, 5 }, { 4, 5 },
}
local BENCHES = { { -16, 26 }, { -26, 26 }, { -16, 34 }, { -26, 34 } } -- établis UnboxBench_01 à _04

_G.ClaudePlotShopParts = {
	CS = CS, RS = RS, rgb = rgb, C = C, ACCENTS = ACCENTS, B = B, CYL = CYL, group = group, att = att,
	label = label, light = light, rnd = rnd, products = products, PRODUCT_COLORS = PRODUCT_COLORS,
	ISLANDS = ISLANDS, ROWS = ROWS, SLOT_ORDER = SLOT_ORDER, BENCHES = BENCHES,
	setSeed = function(v) seed = v end,
}

-- ===== Morceau 2 : cœur (sol, entrée, barrière, volumes, présentoirs, établis, coffre, caisse) =====
-- Le fichier peut s'envoyer d'un bloc, ou morceau par morceau (chaque morceau relit _G.ClaudePlotShopParts).
local P = _G.ClaudePlotShopParts
local CS, RS, C, B, CYL, group, att, label, light = P.CS, P.RS, P.C, P.B, P.CYL, P.group, P.att, P.label, P.light
local ISLANDS, ROWS, SLOT_ORDER, BENCHES = P.ISLANDS, P.ROWS, P.SLOT_ORDER, P.BENCHES

local function buildCore(M)
	-- sol : dalle et damier de 4 studs
	local floor = B(M, "PlotFloor", -32, -0.6, -40, 32, 0.3, 40, C.slab)
	local tiles = group(M, "FloorTiles")
	local nt = 0
	for ix = 0, 15 do
		for iz = 0, 19 do
			if (ix + iz) % 2 == 0 then
				nt += 1
				local x0, z0 = -32 + 4 * ix, -40 + 4 * iz
				B(tiles, "Tile_" .. nt, x0, 0.3, z0, x0 + 4, 0.32, z0 + 4, C.tile, { decor = true, noShadow = true })
			end
		end
	end

	-- entrée : portique, porte vitrée (Window), éclats, rideau, bouton, enseigne
	local D = group(M, "PlotDoor")
	B(D, "Post_L", -7, 0.3, -40.5, -6, 7.6, -38.5, C.frame)
	B(D, "Post_R", 6, 0.3, -40.5, 7, 7.6, -38.5, C.frame)
	B(D, "Header", -7, 7.6, -40.5, 7, 16.2, -38.5, C.accent, { accent = true })
	B(D, "HeaderTrim_B", -7.1, 7.6, -40.6, 7.1, 8.3, -38.4, C.frame)
	B(D, "HeaderTrim_T", -7.1, 15.6, -40.6, 7.1, 16.3, -38.4, C.frame)
	B(D, "Threshold", -6, 0.3, -40, 6, 0.6, -39, C.metal, { studs = false })
	local W = group(D, "Window")
	for _, leafSpec in { { "Leaf_L", -6 }, { "Leaf_R", 0 } } do
		local leaf = group(W, leafSpec[1])
		local x0 = leafSpec[2]
		local x1 = x0 + 6
		B(leaf, "Glass", x0 + 0.3, 0.9, -39.7, x1 - 0.3, 7.3, -39.3, C.glass, { mat = Enum.Material.Glass, T = 0.55 })
		B(leaf, "Stile_A", x0, 0.6, -39.7, x0 + 0.3, 7.6, -39.3, C.chrome, { studs = false })
		B(leaf, "Stile_B", x1 - 0.3, 0.6, -39.7, x1, 7.6, -39.3, C.chrome, { studs = false })
		B(leaf, "Rail_Top", x0 + 0.3, 7.3, -39.7, x1 - 0.3, 7.6, -39.3, C.chrome, { studs = false })
		B(leaf, "Rail_Bottom", x0 + 0.3, 0.6, -39.7, x1 - 0.3, 0.9, -39.3, C.chrome, { studs = false })
	end
	W.WorldPivot = CFrame.new(0, 0.6, -39.5)
	local wf = RS.Assets.Windows.WIN_M_Fractured:Clone()
	wf.Name = "WindowFractured"
	wf:PivotTo(CFrame.new(0, 0.6, -39.5))
	for _, s in wf:GetDescendants() do
		if s:IsA("BasePart") then
			s.Transparency = 1; s.CanCollide = false; s.CanQuery = false; s.CanTouch = false; s.Anchored = true
		end
	end
	wf.Parent = D
	local sh = group(D, "Shutter")
	B(sh, "BottomBar", -6.8, 8.0, -40.35, 6.8, 8.2, -40.05, C.frame, { studs = false })
	for i = 0, 9 do
		local y0 = 8.2 + i * 0.76
		B(sh, string.format("Slat_%02d", i + 1), -6.8, y0, -40.3, 6.8, y0 + 0.76, -40.1, (i % 2 == 0) and C.metal or C.metal2,
			{ studs = false, mat = Enum.Material.DiamondPlate })
	end
	sh.WorldPivot = CFrame.new(0, 8.0, -40.2)
	B(D, "ShutterButtonBox", 6.1, 3.3, -38.5, 6.9, 4.7, -38.3, C.yellow, { studs = false })
	B(D, "ShutterButton", 6.25, 3.6, -38.3, 6.75, 4.1, -38.1, C.red, { studs = false })
	local sign = B(D, "NameSign", -6.6, 11.0, -40.9, 6.6, 15.3, -40.5, C.dark, { studs = false })
	label(sign, Enum.NormalId.Front, "YOUR SHOP", C.white, 40, Color3.new(0, 0, 0), "OwnerName")
	for i, b in { { -6.75, 15.3, 6.75, 15.45 }, { -6.75, 10.85, 6.75, 11.0 }, { -6.75, 10.85, -6.6, 15.45 }, { 6.6, 10.85, 6.75, 15.45 } } do
		B(D, "SignBorder_" .. i, b[1], b[2], -40.95, b[3], b[4], -40.5, C.white, { studs = false, decor = true })
	end
	local badge = B(D, "NumberBadge", -3.2, 8.7, -40.85, 3.2, 10.5, -40.5, C.white, { studs = false })
	label(badge, Enum.NormalId.Front, "SHOP 1", C.dark, 40, C.white, "PlotNumberLabel")

	-- barrière invisible : seul le propriétaire la franchit (code) ; les autres cassent Window
	local PB = group(M, "PlotBarrier")
	local H = 30
	for _, w in {
		{ "Barrier_L", -32, 0.3, -40, -31.6, H, 40 }, { "Barrier_R", 31.6, 0.3, -40, 32, H, 40 },
		{ "Barrier_B", -32, 0.3, 39.6, 32, H, 40 }, { "Barrier_FL", -32, 0.3, -40, -6, H, -39.6 },
		{ "Barrier_FR", 6, 0.3, -40, 32, H, -39.6 }, { "Barrier_FTop", -6, 7.6, -40, 6, H, -39.6 },
		{ "Barrier_Lid", -32, H, -40, 32, H + 0.5, 40 },
	} do
		local p = B(PB, w[1], w[2], w[3], w[4], w[5], w[6], w[7], C.white, { studs = false, T = 1, noShadow = true })
		p.CanTouch = false
	end

	-- volumes
	local bounds = B(M, "Bounds", -32, 0.3, -40, 32, H, 40, C.white, { studs = false, decor = true, T = 1, noShadow = true })
	bounds.CanQuery = false
	local dep = B(M, "DepositZone", -31.5, 0.3, -39.5, 31.5, 12.3, 39.5, C.white, { studs = false, T = 1, noShadow = true })
	dep.CanCollide = false; dep.CanQuery = false; dep.CanTouch = true

	-- points au sol : apparition (vers la rue), pièges derrière la porte (Partie 2)
	att("SpawnPoint", floor, 0, 0.3, -27)
	for i, p in { { -3, -35.5 }, { 3, -35.5 }, { -3, -31.5 }, { 3, -31.5 } } do
		att(string.format("TrapSlot_%02d", i), floor, p[1], 0.3, p[2])
	end
	return floor, D
end

local function buildInterior(M)
	-- îlots de présentoirs (style gondole) et les 20 DisplaySlot
	local DS = group(M, "DisplayStands")
	for i, cx in ISLANDS do
		B(DS, "Island_" .. i .. "_Spine", cx - 1.2, 0.6, -23, cx + 1.2, 3.0, 11, C.shelfBack, { studs = false })
		B(DS, "Island_" .. i .. "_Kick", cx - 2, 0.3, -23.2, cx + 2, 0.6, 11.2, C.kick, { studs = false })
		B(DS, "Island_" .. i .. "_Top", cx - 2, 3.0, -23.2, cx + 2, 3.25, 11.2, C.white, { studs = false })
		B(DS, "Island_" .. i .. "_Band_L", cx - 2.02, 2.75, -23.2, cx - 1.98, 3.25, 11.2, C.accent, { studs = false, decor = true, accent = true })
		B(DS, "Island_" .. i .. "_Band_R", cx + 1.98, 2.75, -23.2, cx + 2.02, 3.25, 11.2, C.accent, { studs = false, decor = true, accent = true })
	end
	for n, s in SLOT_ORDER do
		local cx, z = ISLANDS[s[1]], ROWS[s[2]]
		local stand = B(DS, string.format("DisplayStand_%02d", n), cx - 1.3, 3.25, z - 1.3, cx + 1.3, 3.75, z + 1.3, C.accent, { accent = true })
		att(string.format("DisplaySlot_%02d", n), stand, cx, 3.75, z)
		B(DS, string.format("PriceTag_%02d", n), cx - 0.7, 3.3, z - 1.42, cx + 0.7, 3.7, z - 1.3, C.price, { studs = false, decor = true })
	end

	-- établis d'ouverture (atelier au fond à gauche)
	local WB = group(M, "Workbenches")
	for n, p in BENCHES do
		local cx, cz = p[1], p[2]
		local top = B(WB, string.format("UnboxTable_%02d", n), cx - 1.9, 2.8, cz - 1.5, cx + 1.9, 3.1, cz + 1.5, C.wood, { studs = false, mat = Enum.Material.WoodPlanks })
		att(string.format("UnboxBench_%02d", n), top, cx, 3.1, cz)
		for k, l in { { -1.7, -1.3 }, { 1.7, -1.3 }, { -1.7, 1.3 }, { 1.7, 1.3 } } do
			B(WB, string.format("TableLeg_%02d_%d", n, k), cx + l[1] - 0.15, 0.3, cz + l[2] - 0.15, cx + l[1] + 0.15, 2.8, cz + l[2] + 0.15, C.frame, { studs = false })
		end
		B(WB, string.format("TableShelf_%02d", n), cx - 1.75, 1.0, cz - 1.35, cx + 1.75, 1.15, cz + 1.35, C.woodDark, { studs = false })
		B(WB, string.format("TableVise_%02d", n), cx + 1.1, 3.1, cz + 0.8, cx + 1.7, 3.6, cz + 1.4, C.accent, { studs = false, decor = true, accent = true })
	end

	-- coffre-fort (fond au centre) : cage d'acier, 3 socles VaultSlot_01 à _03
	local V = group(M, "Safe")
	local plate = Enum.Material.DiamondPlate
	B(V, "SafeFloor", -8, 0.3, 27, 8, 0.4, 38.5, C.steel, { mat = plate })
	B(V, "SafeWall_L", -8.4, 0.3, 27, -8, 9.4, 38.5, C.steel, { mat = plate })
	B(V, "SafeWall_R", 8, 0.3, 27, 8.4, 9.4, 38.5, C.steel, { mat = plate })
	B(V, "SafeWall_B", -8.4, 0.3, 38.5, 8.4, 9.4, 38.9, C.steel, { mat = plate })
	B(V, "SafeTop", -8.4, 9.4, 26.6, 8.4, 9.8, 38.9, C.frame, { studs = false })
	B(V, "SafeLintel", -8.4, 8.6, 26.6, 8.4, 9.4, 27.0, C.frame, { studs = false })
	for i = 0, 10 do
		local x = -8 + i * 1.6
		if math.abs(x) > 1.8 and math.abs(x) < 7.9 then
			B(V, "SafeBar_" .. (i + 1), x - 0.12, 0.4, 26.7, x + 0.12, 8.6, 26.95, C.chrome, { studs = false })
		end
	end
	B(V, "SafeGate", -1.75, 0.4, 24.4, -1.55, 8.4, 26.7, C.chrome, { studs = false }) -- grille ouverte
	local safeSign = B(V, "SafeSign", -3, 8.65, 26.5, 3, 9.35, 26.6, C.frame, { studs = false, decor = true })
	label(safeSign, Enum.NormalId.Front, "SAFE", C.gold, 60)
	for i, x in { -4.5, 0, 4.5 } do
		local ped = B(V, string.format("SafePedestal_%02d", i), x - 1.2, 0.4, 32.3, x + 1.2, 2.6, 34.7, C.frame, { studs = false })
		B(V, string.format("SafePedestalTop_%02d", i), x - 1.35, 2.6, 32.15, x + 1.35, 2.85, 34.85, C.gold, { studs = false })
		att(string.format("VaultSlot_%02d", i), ped, x, 2.85, 33.5)
	end

	-- caisse (devant à gauche) et CashPad
	local K = group(M, "Checkout")
	B(K, "Counter", -27, 0.3, -35.5, -17, 2.9, -33.5, C.accent, { accent = true })
	B(K, "CounterTop", -27.1, 2.9, -35.6, -16.9, 3.1, -33.4, C.white, { studs = false })
	B(K, "CounterBelt", -26.6, 3.1, -35.1, -21.5, 3.15, -33.9, C.rubber, { studs = false, decor = true })
	B(K, "Register", -20.2, 3.1, -35.1, -18.2, 3.7, -33.9, C.frame, { studs = false, decor = true })
	B(K, "RegisterScreen", -20.0, 3.7, -34.2, -18.4, 4.6, -34.0, C.dark, { studs = false, decor = true })
	local pad = B(M, "CashPad", -25, 0.3, -31, -19, 0.45, -25, C.green, { studs = false })
	pad.CanCollide = false; pad.CanTouch = true
	label(pad, Enum.NormalId.Top, "$ CASH", C.white, 40)
	B(K, "CashSignPost", -22.15, 0.45, -24.4, -21.85, 7.5, -24.1, C.frame, { studs = false })
	local cs = B(K, "CashSign", -24, 7.5, -24.4, -20, 9.3, -24.1, C.green, { studs = false, decor = true })
	label(cs, Enum.NormalId.Front, "CASH", C.white, 40)

	-- point d'achat du niveau suivant : borne à droite de la porte
	local kiosk = B(M, "UpgradeKiosk", 9, 0.3, -37, 11, 4.2, -35, C.frame)
	B(M, "UpgradeKioskScreen", 9.2, 2.8, -37.05, 10.8, 3.9, -37.0, C.accent, { studs = false, decor = true, mat = Enum.Material.Neon, accent = true })
	att("StageUpgradePoint", kiosk, 10, 6.2, -36)
end

P.buildCore, P.buildInterior = buildCore, buildInterior

-- ===== Morceau 3 : tapis, banc, niveaux 1 à 3 =====
local P = _G.ClaudePlotShopParts
local CS, RS, rgb, C, B, CYL, group, att, label, light = P.CS, P.RS, P.rgb, P.C, P.B, P.CYL, P.group, P.att, P.label, P.light
local products, PRODUCT_COLORS, ISLANDS = P.products, P.PRODUCT_COLORS, P.ISLANDS

-- Tapis de course (MOD-016) : coureur tourné vers -Z, console devant lui. Origine (ox, sol, oz).
local function buildTreadmill(M, ox, oz)
	local T = group(M, "Treadmill")
	local y = 0.3
	local function P(name, x0, y0, z0, x1, y1, z1, color, opt)
		return B(T, name, ox + x0, y + y0, oz + z0, ox + x1, y + y1, oz + z1, color, opt)
	end
	P("Deck", -1.9, 0, -3.0, 1.9, 0.85, 4.0, C.frame)
	P("DeckStripe_L", -1.95, 0.35, -3.0, -1.9, 0.6, 4.0, C.accent, { studs = false, decor = true, accent = true })
	P("DeckStripe_R", 1.9, 0.35, -3.0, 1.95, 0.6, 4.0, C.accent, { studs = false, decor = true, accent = true })
	local belt = P("Belt", -1.5, 0.85, -2.7, 1.5, 1.0, 3.8, C.rubber, { studs = false })
	local tex = Instance.new("Texture")
	tex.Name = "BeltTexture"; tex.Face = Enum.NormalId.Top
	tex.Texture = "rbxassetid://95120777733359" -- ENV_Texture_Stud (L-030) : le code peut faire défiler OffsetStudsV
	tex.StudsPerTileU = 1; tex.StudsPerTileV = 1; tex.Color3 = rgb(70, 70, 80); tex.Transparency = 0.3
	tex.Parent = belt
	P("Rail_L", -1.9, 0.85, -3.0, -1.5, 1.1, 4.0, C.metal, { studs = false })
	P("Rail_R", 1.5, 0.85, -3.0, 1.9, 1.1, 4.0, C.metal, { studs = false })
	P("RearCap", -1.9, 0, 4.0, 1.9, 0.95, 4.3, C.metal2, { studs = false })
	P("MotorHood", -1.9, 0, -3.8, 1.9, 1.5, -3.0, C.accent, { accent = true })
	P("Upright_L", -1.85, 1.5, -3.6, -1.55, 4.5, -3.3, C.metal, { studs = false })
	P("Upright_R", 1.55, 1.5, -3.6, 1.85, 4.5, -3.3, C.metal, { studs = false })
	local console = P("Console", -1.95, 4.4, -3.9, 1.95, 5.3, -3.1, C.frame, { studs = false })
	P("ConsoleScreen", -1.2, 4.55, -3.1, 1.2, 5.15, -3.05, rgb(60, 200, 255), { studs = false, decor = true, mat = Enum.Material.Neon })
	P("Handle_L", -1.9, 3.4, -3.3, -1.65, 3.65, -0.9, C.chrome, { studs = false })
	P("Handle_R", 1.65, 3.4, -3.3, 1.9, 3.65, -0.9, C.chrome, { studs = false })
	P("Grip_L", -1.95, 3.35, -1.7, -1.6, 3.7, -0.9, C.rubber, { studs = false, decor = true })
	P("Grip_R", 1.6, 3.35, -1.7, 1.95, 3.7, -0.9, C.rubber, { studs = false, decor = true })
	att("UsePoint", belt, ox, y + 1.0, oz + 0.6)
	att("UpgradePoint", console, ox, y + 6.8, oz - 3.5)
	T.WorldPivot = CFrame.new(ox, y, oz)
	CS:AddTag(T, "Treadmill")
	return T
end

-- Banc de musculation (MOD-016) : le joueur se tient au sol devant le banc, tourné vers -Z,
-- s'y assoit (BenchIdle), s'allonge, la tête sous la barre posée sur le rack (BenchLift).
local function buildBench(M, ox, oz)
	local K = group(M, "Bench")
	local y = 0.3
	local function P(name, x0, y0, z0, x1, y1, z1, color, opt)
		return B(K, name, ox + x0, y + y0, oz + z0, ox + x1, y + y1, oz + z1, color, opt)
	end
	local mat = P("GymMat", -2.4, 0, -4.2, 2.4, 0.06, 3.2, C.rubber, { studs = false, decor = true, noShadow = true })
	P("Pad", -0.9, 1.45, -2.3, 0.9, 1.85, 2.6, C.accent, { studs = false, accent = true })
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
		CYL(bar, "Plate_" .. tag .. "2", ox + s * 2.78, by, bz, 0.3, 1.25, C.accent, { accent = true })
	end
	att("UsePoint", mat, ox, y + 0.06, oz - 3.0) -- 0,7 stud devant le coussin : le corps ne le touche pas
	att("UpgradePoint", top, ox, y + 6.2, oz + 1.35)
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
	{ "FL", -31.6, -39.6, -7, -39.6 }, { "FR", 7, -39.6, 31.6, -39.6 },
}

-- Niveau 1 : stand ouvert. Barrière basse, champ de force léger au-dessus, tapis d'entrée, cartons.
local function buildStage1(M)
	local S = stage(M, 1)
	local rails = group(S, "Railings", { HideFromStage = 2 })
	local field = group(S, "ForceField", { HideFromStage = 3 })
	for _, sg in SEGMENTS do
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
		local f = B(field, "Field_" .. name, math.min(x0, x1) - 0.05, 3.3, math.min(z0, z1) - 0.05, math.max(x0, x1) + 0.05, 8.5, math.max(z0, z1) + 0.05, C.accent,
			{ mat = Enum.Material.ForceField, decor = true, noShadow = true, T = 0.35, accent = true })
		f.CastShadow = false
	end
	local mat = B(S, "EntryMat", -5, 0.32, -38.9, 5, 0.36, -36.4, C.accent, { studs = false, decor = true, noShadow = true, accent = true })
	mat:SetAttribute("HideFromStage", 5)
	label(mat, Enum.NormalId.Top, "WELCOME", C.white, 40)
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
	local front = group(S, "Murets_Front")
	local sides = group(S, "Murets_Sides", { HideFromStage = 3 })
	for _, sg in SEGMENTS do
		local isFront = sg[1] == "FL" or sg[1] == "FR"
		if isFront then
			-- murets de façade sur z -40..-39, ils restent sous les vitrines du niveau 3
			local a, b
			if sg[1] == "FL" then a, b = -32, -7 else a, b = 7, 32 end
			B(front, "Muret_" .. sg[1], a, 0.3, -40, b, 3.3, -39, C.wall)
			B(front, "MuretCap_" .. sg[1], a, 3.3, -40.1, b, 3.6, -38.9, C.accent, { accent = true })
			B(front, "MuretBase_" .. sg[1], a, 0.3, -40.05, b, 0.9, -38.95, C.frame)
		else
			muret(sides, sg[1])
		end
	end
	local G = group(S, "Gondolas")
	local HEADERS = { { "SNACKS", C.orange }, { "DRINKS", C.purple }, { "TOYS", C.green }, { "TECH", C.red } }
	for i, cx in ISLANDS do
		for _, sx in { -1, 1 } do
			local tag = i .. (sx < 0 and "L" or "R")
			B(G, "Board_" .. tag, math.min(cx + sx * 1.2, cx + sx * 2), 1.7, -23, math.max(cx + sx * 1.2, cx + sx * 2), 1.85, 11, C.shelf, { studs = false })
			B(G, "PriceStrip_" .. tag, math.min(cx + sx * 2, cx + sx * 2.06), 1.7, -23, math.max(cx + sx * 2, cx + sx * 2.06), 1.85, 11, C.price, { studs = false, decor = true })
			products(G, "Prod_" .. tag, cx + sx * 2, sx, -23, 11, 1.85, 1.1)
			-- bas : gros paquets
			local z = -22.8
			local k = 0
			while z < 10.4 do
				k += 1
				local pair = PRODUCT_COLORS[(i * 3 + k) % #PRODUCT_COLORS + 1]
				B(G, "Bulk_" .. tag .. "_" .. k, math.min(cx + sx * 1.25, cx + sx * 1.95), 0.6, z, math.max(cx + sx * 1.25, cx + sx * 1.95), 1.55, z + 1.5, pair[1], { studs = false, decor = true, noShadow = true })
				z += 1.65
			end
		end
		-- enseigne sur la tête de l'îlot, sous le plateau : elle ne cache pas le premier objet
		local h = B(G, "Header_" .. i, cx - 1.9, 0.9, -23.45, cx + 1.9, 2.75, -23.2, HEADERS[i][2], { studs = false, decor = true })
		label(h, Enum.NormalId.Front, HEADERS[i][1], C.white, 40)
	end
	local Pr = group(S, "Promo")
	B(Pr, "PromoBin", -14, 0.3, -31, -10, 1.8, -28, C.yellow, { studs = false })
	for k = 0, 2 do
		B(Pr, "PromoPack_" .. k, -13.7 + k * 1.2, 1.8, -30.6, -12.8 + k * 1.2, 2.7, -28.4, ({ C.red, C.accent, C.green })[k + 1], { studs = false, decor = true })
	end
	B(Pr, "PromoPole", -12.05, 2.7, -29.6, -11.95, 4.2, -29.4, C.frame, { studs = false, decor = true })
	local ps = B(Pr, "PromoSign", -13.4, 4.2, -29.6, -10.6, 5.4, -29.4, C.yellow, { studs = false, decor = true })
	label(ps, Enum.NormalId.Front, "SALE", C.red, 60, C.white)
	local GY = group(S, "GymRack")
	B(GY, "DumbbellRack", 28.6, 0.3, -37, 31, 2.2, -27.5, C.frame, { studs = false })
	for k = 0, 5 do
		local z = -36.2 + k * 1.5
		B(GY, "Dumbbell_" .. k, 28.9, 2.2, z, 30.7, 2.6, z + 0.5, (k % 2 == 0) and C.dark or C.accent, { studs = false, decor = true, accent = k % 2 == 1 })
	end
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
		local a, b = (s < 0) and -32 or 7, (s < 0) and -7 or 32
		B(Wl, "FrontUpper_" .. side[1], a, 12.8, -40, b, 16.2, -39, C.wall)
		B(Wl, "FrontPier_Out_" .. side[1], (s < 0) and -32 or 30, 3.6, -40, (s < 0) and -30 or 32, 12.8, -39, C.wall)
		B(Wl, "FrontPier_In_" .. side[1], (s < 0) and -8 or 7, 3.6, -40, (s < 0) and -7 or 8, 12.8, -39, C.wall)
		local v0, v1 = (s < 0) and -30 or 8, (s < 0) and -8 or 30
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
local ISLANDS, ROWS, SLOT_ORDER = P.ISLANDS, P.ROWS, P.SLOT_ORDER
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
	for i, b in { { -7.0, 15.45, 7.0, 15.75 }, { -7.0, 10.55, 7.0, 10.85 }, { -7.0, 10.55, -6.75, 15.75 }, { 6.75, 10.55, 7.0, 15.75 } } do
		B(SN, "SignTube_" .. i, b[1], b[2], -41.05, b[3], b[4], -40.75, C.accent, { mat = NEON, studs = false, decor = true, accent = true })
	end
	local SLi = group(S, "SignLights")
	for i, x in { -4.5, 4.5 } do
		B(SLi, "LampArm_" .. i, x - 0.1, 16.3, -41.9, x + 0.1, 16.5, -40.5, C.frame, { studs = false, decor = true })
		local lamp = B(SLi, "Lamp_" .. i, -0.3, -0.3, -0.4, 0.3, 0.3, 0.4, C.frame, { studs = false, decor = true })
		lamp.CFrame = CFrame.lookAt(Vector3.new(x, 16.3, -42.0), Vector3.new(x * 0.6, 12.5, -40.6))
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front; spot.Range = 10; spot.Angle = 70; spot.Brightness = 1.5; spot.Shadows = false
		spot.Color = rgb(255, 244, 220)
		spot.Parent = lamp
	end
	local open = B(S, "OpenSign", -21, 8.6, -38.95, -15, 10.4, -38.8, C.dark, { studs = false, decor = true })
	label(open, Enum.NormalId.Front, "OPEN", C.red, 40, C.white)
	local SR = group(S, "ShutterRails", { HideFromStage = 5 })
	B(SR, "ShutterRail_L", -6.9, 0.3, -40.8, -6.5, 7.6, -40.5, C.metal2, { studs = false })
	B(SR, "ShutterRail_R", 6.5, 0.3, -40.8, 6.9, 7.6, -40.5, C.metal2, { studs = false })
	B(SR, "ShutterHousing", -7.1, 7.6, -40.85, 7.1, 8.5, -40.6, C.metal, { studs = false, mat = Enum.Material.DiamondPlate })
	local A = group(S, "Awnings")
	local run, drop = 2.4, 1.0
	local len = math.sqrt(run * run + drop * drop)
	for _, aw in { { "L", -30, -8 }, { "R", 8, 30 } } do
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

-- Sécurité du Flagship (niveau 5) : clavier sur le cadre du coffre, caméras (décor), alarme.
local function buildSecurity(S)
	local SEC = group(S, "Security")
	B(SEC, "Keypad", 6.5, 3.6, -41.5, 7.4, 4.9, -41.3, C.dark, { studs = false, decor = true })
	B(SEC, "KeypadScreen", 6.65, 4.3, -41.55, 7.25, 4.7, -41.5, C.green, { studs = false, decor = true, mat = NEON })
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

-- Niveau 5, Flagship : façade de luxe (marbre et or), porte de coffre-fort (la porte blindée),
-- sécurité (clavier, caméras, alarme), tapis rouge, lustres, palmiers.
local function buildStage5(M)
	local S = stage(M, 5)
	local marble = Enum.Material.Marble
	local F = group(S, "LuxFacade")
	for _, side in { { "L", -31, -9 }, { "R", 9, 31 } } do
		B(F, "MarbleBand_" .. side[1], side[2], 12.8, -40.3, side[3], 16.2, -40.0, C.marble, { mat = marble })
		B(F, "GoldLine_Low_" .. side[1], side[2], 12.8, -40.4, side[3], 13.05, -40.3, C.gold, { studs = false })
		B(F, "GoldLine_High_" .. side[1], side[2], 15.9, -40.4, side[3], 16.15, -40.3, C.gold, { studs = false })
	end
	for i, cx in { -31.25, -8.55, 8.55, 31.25 } do
		local w = (math.abs(cx) > 20) and 0.75 or 0.65
		B(F, "Column_" .. i, cx - w, 0.3, -40.9, cx + w, 16.2, -40.0, C.marble, { mat = marble })
		B(F, "ColumnBase_" .. i, cx - w - 0.2, 0.3, -41.1, cx + w + 0.2, 1.2, -39.95, C.gold, { studs = false })
		B(F, "ColumnCap_" .. i, cx - w - 0.2, 15.3, -41.1, cx + w + 0.2, 16.2, -39.95, C.gold, { studs = false })
	end
	B(F, "Cornice", -32.3, 16.2, -41.0, 32.3, 17.4, -39.6, C.marble, { mat = marble })
	B(F, "CorniceGold", -32.35, 17.4, -41.05, 32.35, 17.7, -39.55, C.gold, { studs = false })
	B(F, "Pediment", -9.2, 17.7, -40.9, 9.2, 21.0, -40.1, C.marble, { mat = marble })
	B(F, "PedimentGold", -9.3, 21.0, -40.95, 9.3, 21.3, -40.05, C.gold, { studs = false })
	local dia = B(F, "Diamond", -1.1, -1.1, -0.15, 1.1, 1.1, 0.15, C.gold, { studs = false, decor = true, mat = NEON })
	dia.CFrame = CFrame.new(0, 19.35, -41.0) * CFrame.Angles(0, 0, math.rad(45))
	local SG = group(S, "SignGold")
	for i, b in { { -7.2, 15.45, 7.2, 15.9 }, { -7.2, 10.4, 7.2, 10.85 }, { -7.2, 10.4, -6.75, 15.9 }, { 6.75, 10.4, 7.2, 15.9 } } do
		B(SG, "GoldFrame_" .. i, b[1], b[2], -41.1, b[3], b[4], -40.75, C.gold, { studs = false })
	end
	for k = 0, 9 do
		local x = -6.3 + k * 1.4
		B(SG, "Bulb_T" .. k, x - 0.13, 15.55, -41.22, x + 0.13, 15.8, -41.1, C.yellow, { studs = false, decor = true, mat = NEON })
		B(SG, "Bulb_B" .. k, x - 0.13, 10.5, -41.22, x + 0.13, 10.75, -41.1, C.yellow, { studs = false, decor = true, mat = NEON })
	end
	-- cadre de coffre-fort autour de la porte : la porte blindée du Flagship
	local VF = group(S, "VaultFrame")
	local metal = Enum.Material.Metal
	B(VF, "Collar_L", -7.85, 0.3, -41.3, -6.05, 6.6, -40.5, C.steel, { mat = metal })
	B(VF, "Collar_R", 6.05, 0.3, -41.3, 7.85, 6.6, -40.5, C.steel, { mat = metal })
	B(VF, "Collar_T", -4.9, 7.6, -41.3, 4.9, 8.6, -40.5, C.steel, { mat = metal })
	for _, s in { -1, 1 } do
		local c = B(VF, "Collar_Corner_" .. (s < 0 and "L" or "R"), -1.6, -0.6, -0.4, 1.6, 0.6, 0.4, C.steel, { mat = metal })
		c.CFrame = CFrame.new(s * 6.8, 7.8, -40.9) * CFrame.Angles(0, 0, s * math.rad(-45)) -- hors de l'ouverture
	end
	for k, p in { { -6.95, 1.2 }, { -6.95, 3.4 }, { -6.95, 5.6 }, { 6.95, 1.2 }, { 6.95, 3.4 }, { 6.95, 5.6 }, { -3, 8.1 }, { 3, 8.1 } } do
		B(VF, "Bolt_" .. k, p[1] - 0.2, p[2] - 0.2, -41.45, p[1] + 0.2, p[2] + 0.2, -41.3, C.gold, { studs = false, decor = true })
	end
	B(VF, "VaultThreshold", -7.85, 0.3, -41.6, 7.85, 0.5, -40.0, C.steel, { mat = metal })
	-- porte ronde du coffre, ouverte, rangée contre le mur de façade (vue à travers la vitrine)
	local VD = group(S, "VaultDoor")
	local disc = CYL(VD, "Disc", -12.5, 4.7, -38.2, 1.2, 8.6, C.steel, { mat = metal })
	disc.CFrame = CFrame.new(-12.5, 4.7, -38.2) * CFrame.Angles(0, math.rad(90), 0)
	local rim = CYL(VD, "Rim", -12.5, 4.7, -38.2, 1.3, 7.2, C.metal2, { mat = metal })
	rim.CFrame = disc.CFrame
	for k = 0, 9 do
		local a = math.rad(k * 36 + 18)
		local x, yy = -12.5 + 3.75 * math.cos(a), 4.7 + 3.75 * math.sin(a)
		B(VD, "DiscBolt_" .. k, x - 0.22, yy - 0.22, -38.95, x + 0.22, yy + 0.22, -38.8, C.gold, { studs = false, decor = true })
	end
	local hub = CYL(VD, "WheelHub", -12.5, 4.7, -37.4, 0.4, 0.9, C.gold, { decor = true })
	hub.CFrame = CFrame.new(-12.5, 4.7, -37.4) * CFrame.Angles(0, math.rad(90), 0)
	for k = 0, 2 do
		local sp = B(VD, "WheelSpoke_" .. k, -1.6, -0.1, -0.1, 1.6, 0.1, 0.1, C.gold, { studs = false, decor = true })
		sp.CFrame = CFrame.new(-12.5, 4.7, -37.45) * CFrame.Angles(0, 0, math.rad(k * 60))
	end
	B(VD, "Hinge_1", -8.3, 1.8, -38.9, -7.7, 2.8, -38.3, C.frame, { studs = false })
	B(VD, "Hinge_2", -8.3, 6.6, -38.9, -7.7, 7.6, -38.3, C.frame, { studs = false })
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
	-- anneaux d'or sous les 20 présentoirs
	local GT = group(S, "GoldTrims")
	for n, s in SLOT_ORDER do
		local cx, z = ISLANDS[s[1]], ROWS[s[2]]
		B(GT, string.format("GoldRing_%02d", n), cx - 1.4, 3.25, z - 1.4, cx + 1.4, 3.42, z + 1.4, C.gold, { studs = false, decor = true })
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

-- (Re)construit ReplicatedStorage/Assets/Plots/PLOT_Shop, morceau par morceau (task.wait entre deux).
local function build()
	P.setSeed(4242)
	local folder = plotsFolder()
	local old = folder:FindFirstChild("PLOT_Shop")
	if old then old:Destroy() end
	local M = Instance.new("Model")
	M.Name = "PLOT_Shop"
	M.Parent = folder
	local steps = {
		buildCore, buildInterior,
		function(t) buildTreadmill(t, 18, -30); buildBench(t, 25.5, -30) end,
		buildStage1, buildStage2, buildStage3, buildStage4, buildStage5,
	}
	for _, step in steps do
		local tmp = Instance.new("Model")
		step(tmp)
		for _, c in tmp:GetChildren() do c.Parent = M end
		tmp:Destroy()
		task.wait()
	end
	local pad = M:FindFirstChild("CashPad")
	CS:AddTag(pad, "CashPad")
	M.WorldPivot = CFrame.identity
	CS:AddTag(M, "PlayerPlot")
	return M
end

-- Garde les niveaux 1 à s d'une boutique installée (jamais du gabarit) : retire les Stage_k au-dessus
-- et les pièces dont HideFromStage <= s.
local function preview(m, s)
	assert(not m:IsDescendantOf(plotsFolder()), "preview ne touche pas au gabarit : installe d'abord une copie")
	s = math.clamp(math.floor(s or 1), 1, 5)
	for k = s + 1, 5 do
		local st = m:FindFirstChild("Stage_" .. k)
		if st then st:Destroy() end
	end
	for _, d in m:GetDescendants() do
		local h = d:GetAttribute("HideFromStage")
		if type(h) == "number" and h <= s then d:Destroy() end
	end
	return m
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
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Accent") then d.Color = accent end
	end
	local num = m:FindFirstChild("PlotNumberLabel", true)
	if num then num.Text = "SHOP " .. index end
	preview(m, opts.stage or 1)
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

_G.ClaudePlotShop = { build = build, install = install, preview = preview, check = check, accents = ACCENTS }
return "ClaudePlotShop chargé : build, install, preview, check"
