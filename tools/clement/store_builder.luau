--!nocheck
--[[
	Constructeur de magasins PNJ du Claude de Clément.
	Ce n'est pas du code de jeu : c'est un outil de construction, exécuté dans Studio par le MCP
	(execute_luau, contexte Edit). Il ne laisse aucun script dans les modèles.

	Chargement (une fois par ouverture de Studio) : envoyer tout ce fichier à execute_luau.
	Il pose _G.ClaudeStore = { build = buildStore, variant = makeVariant, defaults = DEFAULTS }.

	Construction :
		local m = _G.ClaudeStore.build({ name = "STORE_Z2_MagasinDeJouets", zone = 2, ... })
	Variante (2e magasin d'une zone, doc : « variante du 1er ») :
		local v = _G.ClaudeStore.variant(m, { name = "STORE_Z2_Confiserie", colors = {...}, sign = "CONFISERIE", ... })

	Ce que tient le modèle (vérifié sur la zone 1, liaison L-029) :
	- contrat 10.4 : Window (vitre WIN_M), WindowFractured (36 éclats cachés), Shutter (rideau ouvert caché dans la
	  façade, il descend de 7,8 studs), Door, Bounds (invisible), ShelfSlot_01 à _10 (Attachments, attribut Tier :
	  6 Standard, 3 Premium, 1 Luxe), GuardSpawn (au fond à gauche), SignPart ; tag NPCStore, attribut Zone ;
	- pivot en bas au centre, façade vers -Z ; emprise 40 x 48 studs (x -20..20, z -24..24) ;
	- 3 allées de 8, 10 et 8 studs, allée du fond de 7 : le vigile (rayon 2) passe sans sauter ;
	- colis dans des casiers de 1,6 stud de haut sur 2 de profondeur (BOX_* de 1,9 x 1,55 x 1,9 maximum) ;
	- pièces de structure en MaterialVariant « Studs », produits en SmoothPlastic sans collision.

	Personnalisation (toutes les clés sont facultatives, valeurs par défaut = Supérette de la zone 1) :
	- colors   : couleurs de la façade et de l'intérieur (voir DEFAULTS.colors) ;
	- sign     : texte de l'enseigne ; signColors = { bg, text } ; signRect = { x0, x1, y0, y1 } ;
	- facadeTop: hauteur du haut de façade (16,4 par défaut ; au moins 16,4 pour cacher le rideau) ;
	- headers  : { A_L, A_R, B_L, B_R, WallL, WallR, Back } = { texte, Color3 } (bandeaux des rayons) ;
	- designs  : produits { nom = { body, cap?, w, h, ch?, d?, ball? } } ; pools : produits par face de rayon ;
	- awning   : { a = Color3, b = Color3 } (rayures) ; promo = texte des têtes de gondole ;
	- facade   : function(ctx) pour ajouter le style de la zone (étages, toits, décor) ; ctx = { B, label,
	  ORIGIN, model, group, colors, spec }.
]]

local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local DEFAULTS = {
	colors = {
		wall = rgb(242, 217, 166), front = rgb(242, 217, 166), upper = rgb(242, 217, 166),
		trim = rgb(232, 65, 60), cornice = rgb(185, 47, 42), pilaster = rgb(232, 65, 60),
		frame = rgb(58, 64, 75), plinth = rgb(89, 97, 109), roof = rgb(154, 163, 174),
		innerWall = rgb(232, 235, 240), ceiling = rgb(236, 238, 242), floor = rgb(196, 203, 212), tile = rgb(236, 239, 243),
		reserve = rgb(169, 177, 188), shelf = rgb(232, 236, 242), shelfBack = rgb(210, 216, 224), kick = rgb(200, 206, 214),
		shelfTop = rgb(46, 166, 242), price = rgb(255, 230, 0),
		counter = rgb(232, 65, 60), counterTop = rgb(255, 255, 255), mat = rgb(232, 65, 60),
		doorKick = rgb(53, 201, 59), glass = rgb(191, 230, 255), metal = rgb(167, 176, 188), metal2 = rgb(149, 158, 170),
		neon = rgb(205, 205, 198), wood = rgb(94, 59, 33), gold = rgb(255, 194, 26), carton = rgb(181, 130, 76),
		pot = rgb(200, 100, 60), leaf = rgb(63, 191, 58), promo = rgb(255, 230, 0), promoText = rgb(232, 65, 60),
	},
	sign = "MINI MART",
	signColors = { bg = rgb(232, 65, 60), text = rgb(255, 255, 255) },
	signRect = { -10, 10, 10, 13.4 },
	facadeTop = 16.4,
	awning = { a = rgb(232, 65, 60), b = rgb(255, 255, 255) },
	promo = "SALE",
	headers = {
		A_L = { "PASTA & RICE", rgb(53, 201, 59) }, A_R = { "CANNED FOOD", rgb(53, 201, 59) },
		B_L = { "BREAKFAST", rgb(155, 92, 246) }, B_R = { "DRINKS", rgb(155, 92, 246) },
		WallL = { "PERSONAL CARE", rgb(46, 166, 242) }, WallR = { "SNACKS", rgb(255, 140, 40) }, Back = { "CHILLED", rgb(0, 190, 220) },
	},
	designs = {
		pates = { body = rgb(40, 100, 210), cap = rgb(255, 210, 40), w = 1.0, h = 0.8, ch = 0.24, d = 0.5 },
		riz = { body = rgb(255, 255, 255), cap = rgb(232, 65, 60), w = 0.9, h = 0.9, ch = 0.2, d = 0.5 },
		tomate = { body = rgb(255, 255, 255), cap = rgb(232, 65, 60), w = 0.6, h = 0.85, ch = 0.22 },
		conserve = { body = rgb(232, 65, 60), cap = rgb(190, 196, 204), w = 0.6, h = 0.7, ch = 0.1 },
		conserveV = { body = rgb(80, 180, 90), cap = rgb(190, 196, 204), w = 0.6, h = 0.7, ch = 0.1 },
		cereales = { body = rgb(255, 210, 40), cap = rgb(40, 100, 210), w = 0.95, h = 1.25, ch = 0.3, d = 0.55 },
		lait = { body = rgb(255, 255, 255), cap = rgb(46, 166, 242), w = 0.6, h = 1.05, ch = 0.26 },
		yaourt = { body = rgb(245, 150, 195), cap = rgb(255, 255, 255), w = 0.7, h = 0.6, ch = 0.14 },
		jus = { body = rgb(255, 140, 40), cap = rgb(53, 201, 59), w = 0.6, h = 1.0, ch = 0.18 },
		soda = { body = rgb(232, 65, 60), w = 0.5, h = 0.9 },
		eau = { body = rgb(150, 210, 255), cap = rgb(255, 255, 255), w = 0.5, h = 1.15, ch = 0.14 },
		bouteilleV = { body = rgb(60, 170, 80), cap = rgb(255, 210, 40), w = 0.45, h = 1.1, ch = 0.15 },
		savon = { body = rgb(80, 200, 120), w = 0.7, h = 0.6 },
		shampooing = { body = rgb(240, 120, 180), cap = rgb(255, 255, 255), w = 0.5, h = 1.1, ch = 0.2 },
		dentifrice = { body = rgb(255, 255, 255), cap = rgb(46, 166, 242), w = 1.0, h = 0.45, ch = 0.12, d = 0.5 },
		chips = { body = rgb(155, 92, 246), cap = rgb(255, 210, 40), w = 0.8, h = 0.95, ch = 0.2 },
		chipsO = { body = rgb(255, 140, 40), cap = rgb(232, 65, 60), w = 0.8, h = 0.95, ch = 0.2 },
		biscuits = { body = rgb(255, 125, 160), cap = rgb(255, 194, 26), w = 0.9, h = 0.6, ch = 0.15, d = 0.55 },
	},
	pools = {
		A_L = { "pates", "riz", "tomate" }, A_R = { "tomate", "conserve", "conserveV" },
		B_L = { "cereales", "lait", "yaourt", "jus" }, B_R = { "soda", "eau", "jus", "bouteilleV" },
		WallL = { "savon", "shampooing", "dentifrice" }, WallR = { "chips", "chipsO", "biscuits" },
		Back = { "lait", "yaourt", "jus", "eau" },
	},
}

local function merge(base, over)
	local out = {}
	for k, v in base do out[k] = v end
	if over then for k, v in over do out[k] = v end end
	return out
end

local function findTemplate(name)
	local inbox = workspace:FindFirstChild("_INBOX_CLEMENT")
	local found = inbox and inbox:FindFirstChild(name)
	if not found then
		local assets = RS:FindFirstChild("Assets")
		found = assets and assets:FindFirstChild(name, true)
	end
	assert(found, "modèle " .. name .. " introuvable (_INBOX_CLEMENT ou ReplicatedStorage/Assets)")
	return found
end

local function buildStore(spec)
	spec = spec or {}
	local C = merge(DEFAULTS.colors, spec.colors)
	local designs = merge(DEFAULTS.designs, spec.designs)
	local pools = merge(DEFAULTS.pools, spec.pools)
	local headers = merge(DEFAULTS.headers, spec.headers)
	local signColors = merge(DEFAULTS.signColors, spec.signColors)
	local signRect = spec.signRect or DEFAULTS.signRect
	local awn = merge(DEFAULTS.awning, spec.awning)
	local facadeTop = math.max(16.4, spec.facadeTop or DEFAULTS.facadeTop)
	local ORIGIN = spec.origin or CFrame.new(100, 0, 185)
	local model = Instance.new("Model"); model.Name = spec.name or "STORE_Z0_Nouveau"
	local groups = {}
	local function group(name)
		if not groups[name] then local g = Instance.new("Model"); g.Name = name; g.Parent = model; groups[name] = g end
		return groups[name]
	end
	local function B(name, x0, y0, z0, x1, y1, z1, color, opt)
		opt = opt or {}
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
		p.CFrame = ORIGIN * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) * (opt.rot or CFrame.identity)
		p.Color = color; p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if opt.shape then p.Shape = opt.shape end
		if opt.mat then p.Material = opt.mat
		elseif opt.studs == false then p.Material = Enum.Material.SmoothPlastic
		else p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs" end
		if opt.decor then p.CanCollide = false; p.CanTouch = false end
		if opt.T then p.Transparency = opt.T end
		if opt.noShadow then p.CastShadow = false end
		p.Parent = opt.parent or model
		return p
	end
	local function att(name, part, x, y, z, look, tier)
		local a = Instance.new("Attachment"); a.Name = name; a.Parent = part   -- d'abord accroché, puis placé
		local pos = Vector3.new(x, y, z)
		a.WorldCFrame = ORIGIN * CFrame.lookAt(pos, pos + look)
		if tier then a:SetAttribute("Tier", tier) end
		return a
	end
	local function label(part, face, text, color, ppS, stroke)
		local g = Instance.new("SurfaceGui"); g.Name = "LabelGui_" .. face.Name; g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppS or 40; g.LightInfluence = 0
		local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
		t.Text = text; t.TextScaled = true; t.TextColor3 = color
		t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
		local s = Instance.new("UIStroke"); s.Color = stroke or Color3.new(0, 0, 0); s.Thickness = 4; s.LineJoinMode = Enum.LineJoinMode.Round; s.Parent = t
		local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0.14, 0); pad.PaddingBottom = UDim.new(0.14, 0); pad.Parent = t
		t.Parent = g; g.Parent = part
		return t
	end

	-- 1) structure
	local floor = B("Floor", -20, -0.6, -24, 20, 0.3, 24, rgb(201, 209, 218))
	local F = group("Facade")
	B("SideWall_L", -20, 0.3, -23, -19, 10, 23, C.wall, { parent = F })
	B("SideWall_R", 19, 0.3, -23, 20, 10, 23, C.wall, { parent = F })
	B("BackWall", -20, 0.3, 23, 20, 10, 24, C.wall, { parent = F })
	B("FrontWall_L", -20, 0.3, -24, -6.6, 8, -23, C.front, { parent = F })
	B("FrontWall_Mid", 6.6, 0.3, -24, 11, 8, -23, C.front, { parent = F })
	B("FrontWall_R", 15, 0.3, -24, 20, 8, -23, C.front, { parent = F })
	B("UpperFacade", -20, 8, -24.6, 20, facadeTop, -23, C.upper, { parent = F })
	B("Cornice", -20.4, facadeTop, -24.9, 20.4, facadeTop + 0.5, -22.8, C.cornice, { parent = F })
	B("Lintel", -20.1, 7.9, -24.75, 20.1, 8.5, -24.55, C.trim, { parent = F })
	B("Pilaster_L", -20.3, 0.3, -24.85, -18.9, facadeTop, -23, C.pilaster, { parent = F })
	B("Pilaster_R", 18.9, 0.3, -24.85, 20.3, facadeTop, -23, C.pilaster, { parent = F })
	B("TopBand_L", -20.08, 9.2, -23, -19.96, 10, 24, C.trim, { parent = F })
	B("TopBand_R", 19.96, 9.2, -23, 20.08, 10, 24, C.trim, { parent = F })
	B("TopBand_B", -20, 9.2, 23.96, 20, 10, 24.08, C.trim, { parent = F })
	for i, seg in { { -18.9, -6.6 }, { 6.6, 11 }, { 15, 18.9 } } do
		B("Plinth_" .. i, seg[1], 0.3, -24.25, seg[2], 1.1, -23.95, C.plinth, { parent = F })
	end
	B("Frame_L", -6.6, 0.3, -24.1, -6, 8, -22.9, C.frame, { parent = F })
	B("Frame_R", 6, 0.3, -24.1, 6.6, 8, -22.9, C.frame, { parent = F })
	B("Frame_T", -6.6, 7.6, -24.1, 6.6, 8, -22.9, C.frame, { parent = F })
	B("Frame_B", -6.6, 0.3, -24.1, 6.6, 0.6, -22.9, C.frame, { parent = F })
	local R = group("Roof")
	B("RoofSlab", -20, 10, -23, 20, 10.8, 24, C.roof, { parent = R })
	B("Parapet_L", -20, 10.8, -23, -19.5, 11.6, 24, C.wall, { parent = R })
	B("Parapet_R", 19.5, 10.8, -23, 20, 11.6, 24, C.wall, { parent = R })
	B("Parapet_B", -20, 10.8, 23.5, 20, 11.6, 24, C.wall, { parent = R })
	for i, ac in { { -12, 4 }, { 4, 12 }, { 10, -6 } } do
		B("AC_" .. i, ac[1] - 1.5, 10.8, ac[2] - 1.2, ac[1] + 1.5, 12.6, ac[2] + 1.2, C.metal, { parent = R })
		B("AC_" .. i .. "_Fan", ac[1] - 0.8, 12.6, ac[2] - 0.6, ac[1] + 0.8, 12.75, ac[2] + 0.6, C.frame, { parent = R, studs = false })
	end

	-- 2) vitrine, rideau, porte, auvents, enseigne
	local glass = findTemplate("WIN_M"):FindFirstChildWhichIsA("MeshPart")
	assert(glass, "WIN_M sans MeshPart de vitre")
	local win = glass:Clone()
	win.Name = "Window"; win.CFrame = ORIGIN * CFrame.new(0, 0.6 + 3.5, -23.5); win.Anchored = true; win.Parent = model
	local wf = findTemplate("WIN_M_Fractured"):Clone(); wf.Name = "WindowFractured"
	wf:PivotTo(ORIGIN * CFrame.new(0, 0.6, -23.5))
	for _, s in wf:GetDescendants() do
		if s:IsA("BasePart") then s.Transparency = 1; s.CanCollide = false; s.CanQuery = false; s.CanTouch = false; s.Anchored = true end
	end
	wf.Parent = model
	local sh = Instance.new("Model"); sh.Name = "Shutter"; sh.Parent = model
	for i = 0, 9 do
		local y0 = 8.25 + i * 0.76
		B(string.format("Slat_%02d", i + 1), -6.8, y0, -24.35, 6.8, y0 + 0.76, -24.15, (i % 2 == 0) and C.metal or C.metal2, { parent = sh, studs = false, mat = Enum.Material.DiamondPlate })
	end
	B("BottomBar", -6.8, 8.05, -24.4, 6.8, 8.25, -24.1, C.plinth, { parent = sh, studs = false })
	sh.WorldPivot = ORIGIN * CFrame.new(0, 8.05, -24.25)
	local door = Instance.new("Model"); door.Name = "Door"; door.Parent = model
	B("DoorFrame_L", 11, 0.3, -24.1, 11.3, 7.7, -22.9, C.frame, { parent = door })
	B("DoorFrame_R", 14.7, 0.3, -24.1, 15, 7.7, -22.9, C.frame, { parent = door })
	B("DoorFrame_T", 11, 7.4, -24.1, 15, 7.7, -22.9, C.frame, { parent = door })
	B("DoorFrame_Mid", 12.9, 0.3, -23.65, 13.1, 7.4, -23.35, C.frame, { parent = door })
	B("DoorGlass_L", 11.3, 0.3, -23.6, 12.9, 7.4, -23.4, C.glass, { parent = door, mat = Enum.Material.Glass, T = 0.5 })
	B("DoorGlass_R", 13.1, 0.3, -23.6, 14.7, 7.4, -23.4, C.glass, { parent = door, mat = Enum.Material.Glass, T = 0.5 })
	B("DoorKick_L", 11.3, 0.3, -23.7, 12.9, 1.0, -23.3, C.doorKick, { parent = door })
	B("DoorKick_R", 13.1, 0.3, -23.7, 14.7, 1.0, -23.3, C.doorKick, { parent = door })
	B("DoorHandle_L", 12.4, 3.2, -23.85, 12.65, 4.6, -23.65, C.metal, { parent = door, studs = false, decor = true })
	B("DoorHandle_R", 13.35, 3.2, -23.85, 13.6, 4.6, -23.65, C.metal, { parent = door, studs = false, decor = true })
	local A = group("Awning")
	local function awning(x0, x1, n, prefix)
		local w = (x1 - x0) / n
		local run, drop = 2.4, 1.05
		local len = math.sqrt(run * run + drop * drop)
		local ang = -math.atan2(drop, run)
		for i = 0, n - 1 do
			local col = (i % 2 == 0) and awn.a or awn.b
			local cx = x0 + w * (i + 0.5)
			local p = B(string.format("%sStripe_%02d", prefix, i + 1), cx - w / 2, 0, -len / 2, cx + w / 2, 0.15, len / 2, col, { parent = A, studs = false, decor = true })
			p.CFrame = ORIGIN * CFrame.new(cx, 8.9 - drop / 2, -24.6 - run / 2) * CFrame.Angles(ang, 0, 0)
			B(string.format("%sValance_%02d", prefix, i + 1), cx - w / 2, 7.25, -27.08, cx + w / 2, 7.9, -26.96, col, { parent = A, studs = false, decor = true })
		end
	end
	awning(-6.8, 6.8, 10, "Win")
	awning(10.6, 15.4, 3, "Door")
	local sx0, sx1, sy0, sy1 = signRect[1], signRect[2], signRect[3], signRect[4]
	local sign = B("SignPart", sx0, sy0, -25.0, sx1, sy1, -24.6, signColors.bg, { parent = model })
	label(sign, Enum.NormalId.Front, spec.sign or DEFAULTS.sign, signColors.text, 40)
	for i, b in { { sx0 - 0.25, sy1, sx1 + 0.25, sy1 + 0.25 }, { sx0 - 0.25, sy0 - 0.25, sx1 + 0.25, sy0 }, { sx0 - 0.25, sy0 - 0.25, sx0, sy1 + 0.25 }, { sx1, sy0 - 0.25, sx1 + 0.25, sy1 + 0.25 } } do
		B("SignBorder_" .. i, b[1], b[2], -25.05, b[3], b[4], -24.6, signColors.border or rgb(255, 255, 255), { parent = F, studs = false, decor = true })
	end
	local D = group("Decor")
	for i, x in { -17, 17 } do
		B("Pot_" .. i, x - 0.6, 0.3, -26.2, x + 0.6, 1.4, -25.0, C.pot, { parent = D })
		B("PotLeaves_" .. i, x - 0.75, 1.4, -26.35, x + 0.75, 2.7, -24.85, C.leaf, { parent = D, decor = true })
		B("PotLeavesTop_" .. i, x - 0.45, 2.7, -26.05, x + 0.45, 3.3, -25.15, C.leaf, { parent = D, decor = true })
	end

	-- 3) intérieur : murs, plafond, sol à damier, néons
	local I = group("Interior")
	B("InnerWall_L", -19, 0.35, -23, -18.9, 9.9, 23, C.innerWall, { parent = I })
	B("InnerWall_R", 18.9, 0.35, -23, 19, 9.9, 23, C.innerWall, { parent = I })
	B("InnerWall_B", -19, 0.35, 22.9, 19, 9.9, 23, C.innerWall, { parent = I })
	B("Ceiling", -19, 9.9, -23, 19, 10, 23, C.ceiling, { parent = I })
	B("FloorShop", -19, 0.3, -23, 19, 0.35, 23, C.floor, { parent = I })
	local T = group("FloorTiles")
	local nt = 0
	for ix = 0, 9 do
		for iz = 0, 11 do
			if (ix + iz) % 2 == 0 then
				local x0, z0 = -19 + 4 * ix, -23 + 4 * iz
				nt += 1
				B("Tile_" .. nt, x0, 0.35, z0, math.min(x0 + 4, 19), 0.37, math.min(z0 + 4, 23), C.tile, { parent = T, decor = true, noShadow = true })
			end
		end
	end
	for i, x in { -13, 0, 13 } do
		local l = B("CeilingLight_" .. i, x - 0.4, 9.6, -21, x + 0.4, 9.85, 14, C.neon, { parent = I, mat = Enum.Material.Neon, decor = true, noShadow = true })
		local pl = Instance.new("PointLight"); pl.Range = 20; pl.Brightness = 0.35; pl.Color = rgb(255, 246, 230); pl.Shadows = false; pl.Parent = l
	end
	local lf = B("CeilingLight_Front", -17, 9.6, -19.4, 17, 9.85, -18.6, C.neon, { parent = I, mat = Enum.Material.Neon, decor = true, noShadow = true })
	local plf = Instance.new("PointLight"); plf.Range = 20; plf.Brightness = 0.35; plf.Shadows = false; plf.Parent = lf
	B("CeilingLight_Back", -18, 9.6, 18.1, 7, 9.85, 18.9, C.neon, { parent = I, mat = Enum.Material.Neon, decor = true, noShadow = true })

	-- 4) rayons : 3 étages, 5 studs de haut, produits par familles
	local LEVELS = { { top = 0.6, maxH = 1.0 }, { top = 1.85, maxH = 1.45 }, { top = 3.6, maxH = 1.15 } }
	local seed = spec.seed or 12345
	local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
	local count = 0
	local function product(prefix, d, fx, s, y0, z, w, h, withCap)
		local depth = d.d or 0.9
		local hasCap = withCap and d.cap ~= nil
		local bodyTop = y0 + h - (hasCap and (d.ch or 0.2) or 0)
		count += 1
		if d.ball then
			local r = math.min(w, h)
			B(prefix .. "_P" .. count, fx - s * (r + 0.05), y0, z, fx - s * 0.05, y0 + r, z + r, d.body, { parent = I, studs = false, decor = true, noShadow = true, shape = Enum.PartType.Ball })
			return
		end
		B(prefix .. "_P" .. count, fx - s * (depth + 0.05), y0, z, fx - s * 0.05, bodyTop, z + w, d.body, { parent = I, studs = false, decor = true, noShadow = true })
		if hasCap then
			B(prefix .. "_C" .. count, fx - s * (depth + 0.05), bodyTop, z, fx - s * 0.05, y0 + h, z + w, d.cap, { parent = I, studs = false, decor = true, noShadow = true })
		end
	end
	local function shelfSide(prefix, fx, s, z0, z1, pool, gaps)
		local boards = {}
		boards[1] = B(prefix .. "_Kick", fx - s * 2, 0.35, z0, fx, 0.6, z1, C.kick, { parent = I, studs = false })
		for li = 2, 3 do
			boards[li] = B(prefix .. "_Board" .. li, fx - s * 2, LEVELS[li].top - 0.15, z0, fx, LEVELS[li].top, z1, C.shelf, { parent = I, studs = false })
		end
		for li, L in LEVELS do
			B(prefix .. "_Price" .. li, fx, L.top - 0.16, z0, fx + s * 0.06, L.top - 0.01, z1, C.price, { parent = I, studs = false, decor = true, noShadow = true })
			local z = z0 + 0.3
			while z < z1 - 0.4 do
				local d = designs[pool[math.floor(rnd() * #pool) + 1]]
				local runN = 3 + math.floor(rnd() * 3)
				for _ = 1, runN do
					local w, h = d.w, math.min(d.h, L.maxH)
					if z + w > z1 - 0.3 then z = z1; break end
					local inGap = false
					if li == 2 then for _, g in gaps do if z + w > g - 1.3 and z < g + 1.3 then inGap = true; z = g + 1.35 end end end
					if inGap then break end
					product(prefix, d, fx, s, L.top, z, w, h, li < 3)
					z += w + 0.1
				end
				z += 0.15
			end
		end
		return boards
	end
	local function headerText(key) local h = headers[key]; return h[1], h[2] end
	local function gondola(name, x0, x1, z0, z1, keyL, keyR, gapsL, gapsR)
		B(name .. "_Spine", (x0 + x1) / 2 - 0.15, 0.35, z0, (x0 + x1) / 2 + 0.15, 4.85, z1, C.shelfBack, { parent = I, studs = false })
		local bl = shelfSide(name .. "_L", x0, -1, z0 + 0.2, z1 - 0.2, pools[keyL], gapsL)
		local br = shelfSide(name .. "_R", x1, 1, z0 + 0.2, z1 - 0.2, pools[keyR], gapsR)
		B(name .. "_Top", x0, 4.85, z0, x1, 5.0, z1, C.shelf, { parent = I, studs = false })
		B(name .. "_EndA", x0, 0.35, z0, x1, 5.0, z0 + 0.2, C.shelf, { parent = I, studs = false })
		B(name .. "_EndB", x0, 0.35, z1 - 0.2, x1, 5.0, z1, C.shelf, { parent = I, studs = false })
		local tL, cL = headerText(keyL)
		local tR = headerText(keyR)
		local hdr = B(name .. "_Header", x0 + 0.5, 5.0, z0, x1 - 0.5, 6.2, z1, cL, { parent = I, studs = false, decor = true })
		label(hdr, Enum.NormalId.Left, tL, rgb(255, 255, 255), 40)
		label(hdr, Enum.NormalId.Right, tR, rgb(255, 255, 255), 40)
		return bl, br
	end
	local function wallShelf(name, fx, s, z0, z1, key, gaps)
		local boards = shelfSide(name, fx, s, z0 + 0.2, z1 - 0.2, pools[key], gaps)
		B(name .. "_Top", fx - s * 2, 4.85, z0, fx, 5.0, z1, C.shelf, { parent = I, studs = false })
		B(name .. "_Back", fx - s * 2, 0.35, z0, fx - s * 1.85, 4.85, z1, C.shelfBack, { parent = I, studs = false })
		B(name .. "_EndA", fx - s * 2, 0.35, z0, fx, 5.0, z0 + 0.2, C.shelf, { parent = I, studs = false })
		B(name .. "_EndB", fx - s * 2, 0.35, z1 - 0.2, fx, 5.0, z1, C.shelf, { parent = I, studs = false })
		local t, c = headerText(key)
		local hdr = B(name .. "_Header", fx - s * 2, 5.3, z0, fx - s * 1.75, 6.5, z1, c, { parent = I, studs = false, decor = true })
		label(hdr, s > 0 and Enum.NormalId.Right or Enum.NormalId.Left, t, rgb(255, 255, 255), 40)
		return boards
	end
	-- allées : 1 (x -17..-9), centrale (x -5..5, dans l'axe de la vitrine), 3 (x 9..17) ; rayons de z -15 à 9
	local aL, aR = gondola("Shelf_A", -9, -5, -15, 9, "A_L", "A_R", { -3 }, { -11, 6 })
	local bL, bR = gondola("Shelf_B", 5, 9, -15, 9, "B_L", "B_R", { -11, 6 }, { -3 })
	local wL = wallShelf("Shelf_WallL", -17, 1, -15, 9, "WallL", { -9 })
	local wR = wallShelf("Shelf_WallR", 17, -1, -15, 9, "WallR", { -9, 5 })
	-- 10 colis (le code les répartit ; le contrat garde 6 Standard, 3 Premium, 1 Luxe)
	att("ShelfSlot_01", aR[2], -5.95, 1.85, -11, Vector3.new(1, 0, 0), "Standard")
	att("ShelfSlot_02", bL[2], 5.95, 1.85, -11, Vector3.new(-1, 0, 0), "Standard")
	att("ShelfSlot_03", wL[2], -17.95, 1.85, -9, Vector3.new(1, 0, 0), "Standard")
	att("ShelfSlot_04", wR[2], 17.95, 1.85, -9, Vector3.new(-1, 0, 0), "Standard")
	att("ShelfSlot_05", aL[2], -8.05, 1.85, -3, Vector3.new(-1, 0, 0), "Standard")
	att("ShelfSlot_06", bR[2], 8.05, 1.85, -3, Vector3.new(1, 0, 0), "Standard")
	att("ShelfSlot_07", aR[2], -5.95, 1.85, 6, Vector3.new(1, 0, 0), "Premium")
	att("ShelfSlot_08", bL[2], 5.95, 1.85, 6, Vector3.new(-1, 0, 0), "Premium")
	att("ShelfSlot_09", wR[2], 17.95, 1.85, 5, Vector3.new(-1, 0, 0), "Premium")

	-- 5) avant du magasin : caisse, tapis, têtes de gondole
	B("Counter", -18, 0.35, -23, -11, 2.6, -21, C.counter, { parent = I })
	B("CounterTop", -18.1, 2.6, -23, -10.9, 2.8, -20.9, C.counterTop, { parent = I, studs = false })
	B("CounterBelt", -17.8, 2.8, -22.6, -14.8, 2.85, -21.3, rgb(40, 40, 46), { parent = I, studs = false, decor = true })
	B("Register", -13.9, 2.8, -22.6, -12.7, 3.3, -21.6, C.frame, { parent = I, studs = false, decor = true })
	B("RegisterScreen", -13.8, 3.3, -21.95, -12.8, 3.9, -21.85, rgb(30, 30, 30), { parent = I, studs = false, decor = true })
	B("EntranceMat", -5, 0.37, -22.8, 5, 0.42, -21.2, C.mat, { parent = I, studs = false, decor = true })
	for _, g in { { "A", -9, -5 }, { "B", 5, 9 } } do
		B("Promo_" .. g[1], g[2] + 0.2, 0.35, -16.5, g[3] - 0.2, 1.6, -15.05, C.promo, { parent = I, studs = false })
		for k = 0, 2 do
			B("PromoPack_" .. g[1] .. k, g[2] + 0.4 + k * 1.15, 1.6, -16.3, g[2] + 1.4 + k * 1.15, 2.5, -15.25, ({ rgb(232, 65, 60), rgb(46, 166, 242), rgb(53, 201, 59) })[k + 1], { parent = I, studs = false, decor = true })
		end
		B("PromoPole_" .. g[1], (g[2] + g[3]) / 2 - 0.05, 2.5, -15.8, (g[2] + g[3]) / 2 + 0.05, 3.4, -15.7, C.frame, { parent = I, studs = false, decor = true })
		local ps = B("PromoSign_" .. g[1], g[2] + 0.8, 3.4, -15.85, g[3] - 0.8, 4.4, -15.65, C.promo, { parent = I, studs = false, decor = true })
		label(ps, Enum.NormalId.Front, spec.promo or DEFAULTS.promo, C.promoText, 60, rgb(255, 255, 255))
	end

	-- 6) fond : présentoir vitré contre le mur du fond (frigos à la supérette)
	local fr0, fr1 = -19, -1
	B("Fridge_Back", fr0, 0.35, 22.4, fr1, 5.2, 22.9, rgb(255, 255, 255), { parent = I })
	B("Fridge_Base", fr0, 0.35, 21, fr1, 0.7, 22.9, rgb(255, 255, 255), { parent = I })
	B("Fridge_Top", fr0, 4.9, 21, fr1, 5.2, 22.9, rgb(255, 255, 255), { parent = I })
	B("Fridge_SideA", fr0, 0.35, 21, fr0 + 0.2, 5.2, 22.9, rgb(255, 255, 255), { parent = I })
	B("Fridge_SideB", fr1 - 0.2, 0.35, 21, fr1, 5.2, 22.9, rgb(255, 255, 255), { parent = I })
	B("FridgeGlass", fr0 + 0.2, 0.7, 21, fr1 - 0.2, 4.9, 21.1, C.glass, { parent = I, mat = Enum.Material.Glass, T = 0.6 })
	local bt, bc = headerText("Back")
	local fh = B("Fridge_Header", fr0, 5.3, 22.7, fr1, 6.5, 22.9, bc, { parent = I, studs = false, decor = true })
	label(fh, Enum.NormalId.Front, bt, rgb(255, 255, 255), 40)
	local k = 0
	for row = 0, 1 do
		B("FridgeShelf_" .. row, fr0 + 0.2, 0.7 + row * 2.0, 21.1, fr1 - 0.2, 0.8 + row * 2.0, 22.4, rgb(255, 255, 255), { parent = I, studs = false, decor = true })
		local x = fr0 + 0.5
		while x + 0.6 <= fr1 - 0.4 do
			k += 1
			local d = designs[pools.Back[(k + row) % #pools.Back + 1]]
			B("FridgeItem_" .. k, x, 0.8 + row * 2.0, 21.4, x + 0.6, 0.8 + row * 2.0 + math.min(d.h, 1.6), 22.0, d.body, { parent = I, studs = false, decor = true, noShadow = true })
			x += 0.85
		end
	end
	B("Pallet", 1.5, 0.37, 19.6, 6.5, 0.6, 22.6, C.wood, { parent = I, studs = false })
	for k2 = 0, 3 do
		local px = 1.7 + (k2 % 2) * 2.4
		local py = 0.6 + math.floor(k2 / 2) * 1.1
		B("Stock_" .. k2, px, py, 19.8, px + 2.2, py + 1.0, 22.4, spec.stockColor or rgb(150, 210, 255), { parent = I, studs = false })
	end

	-- 7) réserve (fond à droite) avec le Luxe
	local RSv = group("Reserve")
	B("FloorReserve", 9, 0.37, 17, 19, 0.39, 23, C.reserve, { parent = RSv, decor = true, noShadow = true })
	B("ReserveWall_FL", 8, 0.3, 16, 10.5, 9.9, 17, C.reserve, { parent = RSv })
	B("ReserveWall_FR", 16.5, 0.3, 16, 19, 9.9, 17, C.reserve, { parent = RSv })
	B("ReserveWall_Top", 10.5, 8.1, 16, 16.5, 9.9, 17, C.reserve, { parent = RSv })
	B("ReserveWall_Side", 8, 0.3, 17, 9, 9.9, 23, C.reserve, { parent = RSv })
	B("ReserveFrame_L", 10.3, 0.35, 15.9, 10.5, 7.8, 17.1, C.frame, { parent = RSv })
	B("ReserveFrame_R", 16.5, 0.35, 15.9, 16.7, 7.8, 17.1, C.frame, { parent = RSv })
	B("ReserveFrame_T", 10.3, 7.8, 15.9, 16.7, 8.1, 17.1, C.frame, { parent = RSv })
	local rsg = B("ReserveSign", 11.5, 8.3, 15.8, 15.5, 9.3, 16.0, C.frame, { parent = RSv, studs = false, decor = true })
	label(rsg, Enum.NormalId.Front, "STOCKROOM", rgb(255, 230, 0), 60)
	for i = 0, 6 do
		B(string.format("StripCurtain_%02d", i + 1), 10.55 + i * 0.84, 1.2, 16.45, 10.55 + i * 0.84 + 0.72, 7.8, 16.5, rgb(220, 235, 245), { parent = RSv, studs = false, decor = true, T = 0.55 })
	end
	B("Shelf_Reserve", 15, 0.37, 20.5, 17, 2.75, 22.5, C.wood, { parent = RSv })
	local luxTop = B("Shelf_Reserve_Top", 14.9, 2.75, 20.4, 17.1, 3.0, 22.6, C.gold, { parent = RSv, studs = false })
	B("Shelf_Reserve_Trim", 14.95, 0.37, 20.45, 17.05, 0.6, 22.55, C.gold, { parent = RSv, studs = false, decor = true })
	att("ShelfSlot_10", luxTop, 16, 3.0, 21.5, Vector3.new(0, 0, -1), "Luxe")
	for i, c in { { 9.5, 19.6, 11.5, 21.6, 2 }, { 11.7, 20.8, 13.5, 22.8, 1.8 }, { 9.6, 21.8, 11.4, 22.9, 1.4 }, { 10, 19.8, 11.4, 21.2, 1.3 } } do
		local y0 = (i == 4) and 2.37 or 0.37
		B("Carton_" .. i, c[1], y0, c[2], c[3], y0 + c[5], c[4], C.carton, { parent = RSv, studs = false })
	end
	local rl = B("ReserveLight", 13.6, 9.6, 17.5, 14.4, 9.85, 22.5, C.neon, { parent = RSv, mat = Enum.Material.Neon, decor = true, noShadow = true })
	local rpl = Instance.new("PointLight"); rpl.Range = 16; rpl.Brightness = 0.35; rpl.Shadows = false; rpl.Parent = rl
	att("GuardSpawn", floor, -15, 0.35, 18, Vector3.new(0, 0, -1))   -- au fond à gauche, loin du Luxe et de la vitrine (L-020)

	-- 8) volume intérieur
	local bounds = B("Bounds", -19, 0.3, -23, 19, 9.9, 23, rgb(255, 255, 255), { studs = false, decor = true, T = 1, noShadow = true })
	bounds.CanQuery = false
	-- InfoPoint (L-044) : où flotte le panneau BB_StoreInfo, au-dessus de l'enseigne, devant la façade
	att("InfoPoint", bounds, 0, sy1 + 0.8, -25.5, Vector3.new(0, 0, -1))

	-- 9) style de la zone
	if spec.facade then
		spec.facade({ B = B, label = label, ORIGIN = ORIGIN, model = model, group = group, colors = C, spec = spec, facadeTop = facadeTop })
	end

	model.WorldPivot = ORIGIN
	model:SetAttribute("Zone", spec.zone or 1)
	CS:AddTag(model, "NPCStore")
	model.Parent = spec.parent or workspace:FindFirstChild("_INBOX_CLEMENT") or workspace
	-- spec.scale : agrandit tout le magasin autour de son pivot (allées, ShelfSlot, vitre, Bounds) ; gabarit 2026-11-07 : 1.5
	if spec.scale and spec.scale ~= 1 then model:ScaleTo(spec.scale) end
	return model, count
end

-- Variante : copie d'un magasin, recolorée (façade et quelques pièces choisies), autre enseigne, autres bandeaux.
local function key(c) return string.format("%d,%d,%d", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)) end
local function makeVariant(source, opt)
	local v = source:Clone()
	v.Name = opt.name
	local swap = {}
	for from, to in (opt.colorMap or {}) do swap[key(from)] = to end
	local insideOk = {}
	for _, n in (opt.insideNames or { "Counter", "EntranceMat" }) do insideOk[n] = true end
	for _, d in v:GetDescendants() do
		if d:IsA("BasePart") then
			local inside = d:FindFirstAncestor("Interior") or d:FindFirstAncestor("Reserve") or d:FindFirstAncestor("FloorTiles")
			if (not inside or insideOk[d.Name] or opt.recolorInterior) and swap[key(d.Color)] then d.Color = swap[key(d.Color)] end
			-- produits : nouvelle palette (ex. confiserie pastel), par ordre de couleur rencontrée
			if opt.productPalette and inside and (d.Name:match("_P%d+$") or d.Name:match("_C%d+$") or d.Name:match("^FridgeItem_")) then
				local idx = (tonumber(d.Name:match("(%d+)$")) or 1) % #opt.productPalette + 1
				d.Color = opt.productPalette[idx]
			end
		end
	end
	if opt.sign then
		local gui = v.SignPart:FindFirstChildWhichIsA("SurfaceGui")
		local lbl = gui and gui:FindFirstChild("Label")
		if lbl then
			lbl.Text = opt.sign
			if opt.signText then lbl.TextColor3 = opt.signText end
		end
	end
	if opt.headers then
		for partName, texts in opt.headers do
			local p = v:FindFirstChild(partName, true)
			if p then
				for face, text in texts do
					local g = p:FindFirstChild("LabelGui_" .. face)
					if g then g.Label.Text = text end
				end
			end
		end
	end
	v.Parent = source.Parent
	return v
end

_G.ClaudeStore = { build = buildStore, variant = makeVariant, defaults = DEFAULTS }
return "ClaudeStore chargé : build, variant, defaults"
