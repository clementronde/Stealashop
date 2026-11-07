--!nocheck
-- Zone 2 — Londres (MOD-020) : magasin de jouets, confiserie et décor de rue.
-- À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS tools/clement/store_builder.luau.
-- Relancer ce script reconstruit la zone 2 à l'identique : les modèles du même nom sont remplacés.
-- Sert aussi d'exemple pour les autres quartiers (zones 3 à 6) : une fonction « facade » par style,
-- une spec par magasin (couleurs, enseigne, rayons, produits), puis le décor de rue dans Map/Zone_N.
-- Règles : aucun script laissé dans la map ; noms du contrat (10.4) jamais réutilisés pour le décor.

local rgb = Color3.fromRGB
local Store = _G.ClaudeStore
assert(Store, "charger d'abord tools/clement/store_builder.luau")

-- Façade londonienne : devanture peinte, enseigne en bandeau, deux étages de fenêtres à guillotine,
-- plaque bleue, enseigne suspendue, et un vrai volume derrière la façade (pas un simple décor plat).
-- spec.london = { brick, stucco, shop, gold, glass?, box, flowerA, flowerB, pot, plaque, hanging, panel, panelColor?, panelText? }
local function londonFacade(ctx)
	local B, label, group = ctx.B, ctx.label, ctx.group
	local L = ctx.spec.london
	local top = ctx.facadeTop
	local F = group("Facade")
	local U = group("UpperFloors")
	local brick, stucco, shop, gold = L.brick, L.stucco, L.shop, L.gold
	local glassDark = L.glass or rgb(52, 66, 92)
	local iron = rgb(25, 25, 30)
	local function deco(parent, extra)
		local o = { parent = parent or U, studs = false, decor = true }
		if extra then for k, v in extra do o[k] = v end end
		return o
	end
	-- Devanture
	B("FasciaBack", -18.9, 8.5, -24.75, 18.9, 11.0, -24.6, shop, deco(F))
	B("ShopCornice", -19.0, 11.0, -25.4, 19.0, 11.5, -24.6, shop, deco(F))
	B("ShopCorniceGold", -19.1, 11.5, -25.5, 19.1, 11.65, -24.6, gold, deco(F))
	for i, x in { -17.6, 17.6 } do
		B("Console_" .. i, x - 0.55, 8.4, -25.35, x + 0.55, 11.0, -24.6, stucco, deco(F))
		B("ConsoleCap_" .. i, x - 0.7, 10.55, -25.45, x + 0.7, 11.0, -24.6, gold, deco(F))
	end
	B("PanelFrame", -16.2, 2.0, -24.12, -7.8, 6.8, -24.0, gold, deco(F))
	local panel = B("PanelBoard", -16.0, 2.2, -24.2, -8.0, 6.6, -24.0, L.panelColor or shop, deco(F))
	label(panel, Enum.NormalId.Front, L.panel, L.panelText or gold, 40)
	for i, x in { 10.3, 15.7 } do
		B("LanternArm_" .. i, x - 0.05, 6.25, -24.4, x + 0.05, 6.35, -24.0, iron, deco(F))
		B("LanternTop_" .. i, x - 0.35, 6.5, -24.95, x + 0.35, 6.7, -24.25, iron, deco(F))
		B("LanternBase_" .. i, x - 0.3, 5.55, -24.9, x + 0.3, 5.65, -24.3, iron, deco(F))
		local glow = B("LanternGlow_" .. i, x - 0.25, 5.65, -24.85, x + 0.25, 6.5, -24.35, rgb(255, 214, 140), deco(F, { mat = Enum.Material.Neon, noShadow = true }))
		local pl = Instance.new("PointLight"); pl.Range = 12; pl.Brightness = 0.7; pl.Color = rgb(255, 210, 150); pl.Shadows = false; pl.Parent = glow
	end
	-- Étages
	B("StringCourse", -18.9, 16.55, -24.85, 18.9, 16.9, -24.6, stucco, deco())
	local n = 0
	for r, row in { { 12.4, 15.6 }, { 17.8, 20.9 } } do
		for _, cx in { -13.5, -4.5, 4.5, 13.5 } do
			n += 1
			local x0, x1, y0, y1 = cx - 1.5, cx + 1.5, row[1], row[2]
			local ym = (y0 + y1) / 2
			B("SashFrame_" .. n, x0 - 0.22, y0 - 0.05, -24.7, x1 + 0.22, y1 + 0.22, -24.6, stucco, deco())
			B("SashGlass_" .. n, x0, y0, -24.76, x1, y1, -24.7, glassDark, deco(nil, { mat = Enum.Material.Glass }))
			B("SashRail_" .. n, x0, ym - 0.09, -24.82, x1, ym + 0.09, -24.76, stucco, deco())
			B("SashBar_" .. n, cx - 0.07, y0, -24.8, cx + 0.07, y1, -24.76, stucco, deco())
			B("SashLintel_" .. n, x0 - 0.5, y1 + 0.22, -24.9, x1 + 0.5, y1 + 0.7, -24.6, stucco, deco())
			B("SashSill_" .. n, x0 - 0.4, y0 - 0.32, -25.0, x1 + 0.4, y0 - 0.05, -24.6, stucco, deco())
			if r == 1 then
				B("WindowBox_" .. n, x0 - 0.1, y0 - 1.0, -25.5, x1 + 0.1, y0 - 0.32, -24.62, L.box, deco())
				for k = 0, 4 do
					local fx = x0 + 0.3 + k * 0.6
					B("Flower_" .. n .. "_" .. k, fx - 0.26, y0 - 0.58, -25.32, fx + 0.26, y0 - 0.06, -24.8, (k % 2 == 0) and L.flowerA or L.flowerB, deco(nil, { shape = Enum.PartType.Ball, noShadow = true }))
				end
			end
		end
	end
	-- Plaque bleue
	B("BluePlaqueRim", -0.075, 12.8, -24.66 - 1.2, 0.075, 15.2, -24.66 + 1.2, rgb(250, 250, 250), deco(nil, { shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, math.rad(90), 0) }))
	local plaque = B("BluePlaque", -0.1, 12.9, -24.68 - 1.1, 0.1, 15.1, -24.68 + 1.1, rgb(28, 88, 168), deco(nil, { shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, math.rad(90), 0) }))
	label(plaque, Enum.NormalId.Right, L.plaque, rgb(255, 255, 255), 60, rgb(28, 88, 168))
	-- Enseigne suspendue
	B("HangingBracket", -17.3, 15.0, -27.6, -17.1, 15.2, -24.6, iron, deco())
	B("HangingFrame", -17.25, 12.15, -27.45, -17.15, 14.95, -24.95, gold, deco())
	local hs = B("HangingSign", -17.3, 12.3, -27.3, -17.1, 14.8, -25.1, shop, deco())
	label(hs, Enum.NormalId.Left, L.hanging, gold, 40)
	label(hs, Enum.NormalId.Right, L.hanging, gold, 40)
	-- Volume des étages et cheminées
	B("UpperSide_L", -20.05, 10.8, -23, -19, top, -12, brick, { parent = U })
	B("UpperSide_R", 19, 10.8, -23, 20.05, top, -12, brick, { parent = U })
	B("UpperBack", -20.05, 10.8, -12, 20.05, top, -11, brick, { parent = U })
	B("UpperRoof", -20.05, top, -22.8, 20.05, top + 0.4, -11, ctx.colors.roof, { parent = U })
	for i, cx in { -14.5, 14.5 } do
		B("Chimney_" .. i, cx - 1.4, top + 0.4, -17.5, cx + 1.4, top + 3.6, -14.5, brick, { parent = U })
		B("ChimneyCap_" .. i, cx - 1.6, top + 3.6, -17.7, cx + 1.6, top + 3.95, -14.3, stucco, { parent = U, studs = false })
		for k = -1, 1 do
			local px, yc = cx + k * 0.85, top + 4.4
			B("ChimneyPot_" .. i .. "_" .. (k + 2), px - 0.45, yc - 0.3, -16.3, px + 0.45, yc + 0.3, -15.7, L.pot, { parent = U, studs = false, shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, 0, math.rad(90)) })
		end
	end
end
_G.ClaudeLondon = { facade = londonFacade }

-- 1) Greybox : magasins gris de la zone 2 mis de côté (le générateur d'Ironix les saute déjà quand le vrai
--    est dans Map), murets calés sur les magasins (x 120..160), rue en asphalte.
do
	local SS = game:GetService("ServerStorage")
	local gz2 = workspace.Greybox.Corridor.Zone_2
	for _, nm in { "STORE_Z2_MagasinDeJouets", "STORE_Z2_Confiserie" } do
		local m = gz2:FindFirstChild(nm)
		if m then
			local keep = SS:FindFirstChild("_GREYBOX_REMPLACE") or Instance.new("Folder")
			keep.Name = "_GREYBOX_REMPLACE"; keep.Parent = SS
			m.Parent = keep
		end
	end
	local g = gz2.Ground
	g.SideWall_N1.Size = Vector3.new(20, 12, 1); g.SideWall_N1.Position = Vector3.new(110, 6, 20.5)
	g.SideWall_S1.Size = Vector3.new(20, 12, 1); g.SideWall_S1.Position = Vector3.new(110, 6, -20.5)
	g.SideWall_N2.Size = Vector3.new(30, 12, 1); g.SideWall_N2.Position = Vector3.new(175, 6, 20.5)
	g.SideWall_S2.Size = Vector3.new(30, 12, 1); g.SideWall_S2.Position = Vector3.new(175, 6, -20.5)
	g.Street.Color = rgb(58, 60, 66); g.Street.Material = Enum.Material.Plastic; g.Street.MaterialVariant = "Studs"
end

-- 2) Dossier de la zone
local zoneFolder = workspace.Map:FindFirstChild("Zone_2")
if not zoneFolder then zoneFolder = Instance.new("Folder"); zoneFolder.Name = "Zone_2"; zoneFolder.Parent = workspace.Map end
for _, nm in { "STORE_Z2_MagasinDeJouets", "STORE_Z2_Confiserie" } do
	local old = zoneFolder:FindFirstChild(nm); if old then old:Destroy() end
end

local brick, stucco, gold = rgb(176, 70, 52), rgb(240, 236, 224), rgb(212, 175, 55)
local navy = rgb(35, 55, 110)

-- 3) Magasin de jouets : brique rouge, devanture bleu marine et or, auvent vert et blanc
local toy, toyN = Store.build({
	name = "STORE_Z2_MagasinDeJouets", zone = 2,
	origin = CFrame.new(140, 0, 44), parent = zoneFolder,
	sign = "MAGASIN DE JOUETS",
	signColors = { bg = rgb(24, 38, 84), text = rgb(255, 204, 72), border = gold },
	signRect = { -16, 16, 8.95, 10.75 }, facadeTop = 22,
	awning = { a = rgb(35, 150, 90), b = rgb(250, 248, 240) },
	colors = {
		wall = brick, front = navy, upper = brick, trim = stucco, cornice = stucco, pilaster = rgb(236, 228, 210),
		frame = rgb(28, 32, 42), plinth = rgb(40, 44, 54), roof = rgb(88, 94, 108),
		innerWall = rgb(250, 240, 220), ceiling = rgb(250, 246, 236), floor = rgb(62, 62, 72), tile = rgb(238, 232, 218),
		shelf = rgb(196, 146, 96), shelfBack = rgb(160, 112, 72), kick = rgb(120, 82, 52), price = rgb(255, 204, 72),
		counter = navy, counterTop = rgb(196, 146, 96), mat = navy, doorKick = gold,
		pot = rgb(36, 38, 44), leaf = rgb(52, 140, 64), promo = rgb(255, 204, 72), promoText = navy,
	},
	headers = {
		A_L = { "PELUCHES", rgb(232, 90, 140) }, A_R = { "JEUX DE SOCIÉTÉ", rgb(46, 134, 222) },
		B_L = { "CONSTRUCTION", rgb(255, 150, 30) }, B_R = { "POUPÉES", rgb(186, 92, 220) },
		WallL = { "ROBOTS", rgb(60, 160, 200) }, WallR = { "SPORT", rgb(53, 170, 70) }, Back = { "NOUVEAUTÉS", rgb(232, 65, 60) },
	},
	designs = {
		peluche = { body = rgb(170, 118, 72), cap = rgb(222, 178, 128), w = 0.85, h = 0.95, ch = 0.35, d = 0.7 },
		pelucheR = { body = rgb(232, 90, 140), cap = rgb(255, 190, 215), w = 0.85, h = 0.95, ch = 0.35, d = 0.7 },
		pelucheB = { body = rgb(110, 165, 230), cap = rgb(200, 225, 255), w = 0.85, h = 0.95, ch = 0.35, d = 0.7 },
		jeu = { body = rgb(46, 134, 222), cap = rgb(255, 255, 255), w = 0.35, h = 1.1, ch = 0.2, d = 0.95 },
		jeuR = { body = rgb(232, 65, 60), cap = rgb(255, 210, 40), w = 0.35, h = 1.1, ch = 0.2, d = 0.95 },
		puzzle = { body = rgb(53, 170, 70), cap = rgb(255, 255, 255), w = 0.9, h = 0.8, ch = 0.15, d = 0.4 },
		cubes = { body = rgb(255, 210, 40), cap = rgb(232, 65, 60), w = 0.75, h = 0.75, ch = 0.25, d = 0.75 },
		cubesB = { body = rgb(46, 134, 222), cap = rgb(255, 210, 40), w = 0.75, h = 0.75, ch = 0.25, d = 0.75 },
		briques = { body = rgb(232, 65, 60), cap = rgb(255, 255, 255), w = 1.1, h = 0.6, ch = 0.12, d = 0.8 },
		poupee = { body = rgb(245, 150, 195), cap = rgb(255, 255, 255), w = 0.6, h = 1.3, ch = 0.25, d = 0.5 },
		poupeeV = { body = rgb(186, 92, 220), cap = rgb(255, 220, 240), w = 0.6, h = 1.3, ch = 0.25, d = 0.5 },
		robot = { body = rgb(150, 160, 175), cap = rgb(46, 166, 242), w = 0.7, h = 1.05, ch = 0.35, d = 0.6 },
		robotR = { body = rgb(90, 98, 112), cap = rgb(232, 65, 60), w = 0.7, h = 1.05, ch = 0.35, d = 0.6 },
		ballon = { body = rgb(232, 65, 60), w = 0.8, h = 0.8, ball = true },
		ballonB = { body = rgb(250, 250, 250), w = 0.8, h = 0.8, ball = true },
		ballonO = { body = rgb(255, 140, 40), w = 0.85, h = 0.85, ball = true },
		raquette = { body = rgb(53, 170, 70), cap = rgb(240, 240, 240), w = 0.3, h = 1.3, ch = 0.5, d = 0.8 },
	},
	pools = {
		A_L = { "peluche", "pelucheR", "pelucheB" }, A_R = { "jeu", "jeuR", "puzzle" },
		B_L = { "cubes", "cubesB", "briques" }, B_R = { "poupee", "poupeeV" },
		WallL = { "robot", "robotR" }, WallR = { "ballon", "ballonB", "ballonO", "raquette" },
		Back = { "robot", "poupee", "peluche", "jeu" },
	},
	seed = 2002, stockColor = rgb(255, 204, 72),
	london = {
		brick = brick, stucco = stucco, shop = navy, gold = gold,
		box = rgb(30, 70, 45), flowerA = rgb(220, 40, 50), flowerB = rgb(250, 250, 250), pot = rgb(190, 95, 60),
		plaque = "ICI EST NÉ\nLE PREMIER\nOURS EN PELUCHE\n1887", hanging = "JOUETS",
		panel = "JOUETS\n& JEUX", panelColor = rgb(28, 44, 92),
	},
	facade = londonFacade,
})

-- 4) Confiserie : façade peinte en rose (style Notting Hill), devanture menthe, auvent rose et blanc
local pink, mint, white = rgb(240, 172, 192), rgb(98, 192, 160), rgb(250, 248, 242)
local candy, candyN = Store.build({
	name = "STORE_Z2_Confiserie", zone = 2,
	origin = CFrame.new(140, 0, -44) * CFrame.Angles(0, math.pi, 0), parent = zoneFolder,
	sign = "CONFISERIE",
	signColors = { bg = rgb(255, 246, 240), text = rgb(226, 72, 130), border = gold },
	signRect = { -16, 16, 8.95, 10.75 }, facadeTop = 22,
	awning = { a = rgb(240, 120, 165), b = rgb(255, 250, 250) },
	colors = {
		wall = brick, front = mint, upper = pink, trim = white, cornice = white, pilaster = white,
		frame = rgb(40, 90, 80), plinth = rgb(60, 110, 100), roof = rgb(88, 94, 108),
		innerWall = rgb(255, 236, 242), ceiling = rgb(255, 248, 250), floor = rgb(250, 200, 218), tile = rgb(255, 255, 255),
		shelf = rgb(255, 255, 255), shelfBack = rgb(255, 222, 234), kick = rgb(230, 150, 180), price = mint,
		counter = mint, counterTop = rgb(255, 255, 255), mat = rgb(240, 120, 165), doorKick = gold,
		pot = rgb(255, 255, 255), leaf = rgb(52, 160, 90), promo = rgb(255, 120, 170), promoText = rgb(255, 255, 255),
	},
	headers = {
		A_L = { "BONBONS", rgb(240, 100, 160) }, A_R = { "CHOCOLATS", rgb(130, 80, 50) },
		B_L = { "SUCETTES", rgb(255, 150, 40) }, B_R = { "GUIMAUVES", rgb(170, 120, 220) },
		WallL = { "CARAMELS", rgb(220, 150, 60) }, WallR = { "GÂTEAUX", rgb(232, 80, 110) }, Back = { "GLACES", rgb(60, 180, 220) },
	},
	designs = {
		bocal = { body = rgb(255, 150, 190), cap = rgb(245, 245, 245), w = 0.6, h = 0.85, ch = 0.18, d = 0.6 },
		bocalV = { body = rgb(130, 220, 170), cap = rgb(245, 245, 245), w = 0.6, h = 0.85, ch = 0.18, d = 0.6 },
		bocalJ = { body = rgb(255, 214, 90), cap = rgb(245, 245, 245), w = 0.6, h = 0.85, ch = 0.18, d = 0.6 },
		chocolat = { body = rgb(110, 64, 40), cap = rgb(212, 175, 55), w = 0.9, h = 0.55, ch = 0.12, d = 0.7 },
		chocolatN = { body = rgb(70, 40, 28), cap = rgb(232, 65, 60), w = 0.9, h = 0.55, ch = 0.12, d = 0.7 },
		sucette = { body = rgb(255, 90, 150), w = 0.7, h = 0.7, ball = true },
		sucetteB = { body = rgb(110, 190, 255), w = 0.7, h = 0.7, ball = true },
		sucetteJ = { body = rgb(255, 200, 60), w = 0.7, h = 0.7, ball = true },
		guimauve = { body = rgb(255, 240, 245), cap = rgb(255, 180, 210), w = 0.7, h = 0.7, ch = 0.3, d = 0.6 },
		guimauveV = { body = rgb(235, 225, 255), cap = rgb(190, 160, 240), w = 0.7, h = 0.7, ch = 0.3, d = 0.6 },
		caramel = { body = rgb(220, 150, 60), cap = rgb(120, 70, 30), w = 0.6, h = 0.75, ch = 0.2, d = 0.6 },
		caramelB = { body = rgb(250, 230, 190), cap = rgb(200, 120, 50), w = 0.6, h = 0.75, ch = 0.2, d = 0.6 },
		gateau = { body = rgb(250, 225, 190), cap = rgb(255, 120, 160), w = 0.9, h = 0.65, ch = 0.25, d = 0.8 },
		gateauC = { body = rgb(120, 70, 40), cap = rgb(255, 255, 255), w = 0.9, h = 0.65, ch = 0.25, d = 0.8 },
		glace = { body = rgb(255, 210, 225), w = 0.6, h = 0.7 },
		glaceV = { body = rgb(200, 240, 220), w = 0.6, h = 0.7 },
		glaceC = { body = rgb(150, 100, 70), w = 0.6, h = 0.7 },
	},
	pools = {
		A_L = { "bocal", "bocalV", "bocalJ" }, A_R = { "chocolat", "chocolatN" },
		B_L = { "sucette", "sucetteB", "sucetteJ" }, B_R = { "guimauve", "guimauveV" },
		WallL = { "caramel", "caramelB" }, WallR = { "gateau", "gateauC" },
		Back = { "glace", "glaceV", "glaceC" },
	},
	seed = 2020, stockColor = rgb(255, 150, 190),
	london = {
		brick = brick, stucco = white, shop = mint, gold = gold,
		box = mint, flowerA = rgb(240, 100, 160), flowerB = rgb(255, 255, 255), pot = rgb(190, 95, 60),
		plaque = "ICI EST NÉE\nLA PREMIÈRE\nGUIMAUVE\n1887", hanging = "BONBONS",
		panel = "BONBONS\n& DOUCEURS", panelColor = rgb(70, 160, 130), panelText = rgb(255, 255, 255),
	},
	facade = londonFacade,
})

-- 5) Décor de rue : Map/Zone_2/Street_Londres. Chaussée libre de z -15 à 15 ; trottoirs à |z| 15..20,
--    surélevés de 0,3 stud (au niveau du sol des magasins) ; maisons plaquées sur les murets, sans collision.
do
	local Z = zoneFolder
	local old = Z:FindFirstChild("Street_Londres"); if old then old:Destroy() end
	local S = Instance.new("Folder"); S.Name = "Street_Londres"; S.Parent = Z
	local function folder(name) local f = Instance.new("Model"); f.Name = name; f.Parent = S; return f end
	local function P(parent, name, cf, size, color, opt)
		opt = opt or {}
		local p = Instance.new("Part")
		p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if opt.shape then p.Shape = opt.shape end
		if opt.mat then p.Material = opt.mat
		elseif opt.studs then p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
		else p.Material = Enum.Material.SmoothPlastic end
		if opt.decor then p.CanCollide = false; p.CanTouch = false end
		if opt.T then p.Transparency = opt.T end
		if opt.noShadow then p.CastShadow = false end
		p.Parent = parent
		return p
	end
	local function Bx(parent, frame, name, x0, y0, z0, x1, y1, z1, color, opt)
		local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
		return P(parent, name, frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), size, color, opt)
	end
	local function vcyl(parent, name, x, y0, y1, z, dia, color, opt)
		opt = opt or {}; opt.shape = Enum.PartType.Cylinder
		return P(parent, name, CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(y1 - y0, dia, dia), color, opt)
	end
	local function label(part, face, text, color, ppS, stroke)
		local g = Instance.new("SurfaceGui"); g.Name = "LabelGui_" .. face.Name; g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppS or 40; g.LightInfluence = 0
		local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
		t.Text = text; t.TextScaled = true; t.TextColor3 = color
		t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
		local s = Instance.new("UIStroke"); s.Color = stroke or Color3.new(0, 0, 0); s.Thickness = 3; s.LineJoinMode = Enum.LineJoinMode.Round; s.Parent = t
		local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0.14, 0); pad.PaddingBottom = UDim.new(0.14, 0); pad.Parent = t
		t.Parent = g; g.Parent = part
	end
	local function faceFor(nx, nz)
		if nz < 0 then return Enum.NormalId.Front elseif nz > 0 then return Enum.NormalId.Back elseif nx < 0 then return Enum.NormalId.Left end
		return Enum.NormalId.Right
	end
	local W = CFrame.identity
	local iron, red = rgb(25, 25, 30), rgb(200, 30, 35)
	local whiteL = rgb(245, 245, 240)

	-- Trottoirs, bordures, doubles lignes jaunes, zigzags et passage piéton
	local G = folder("Ground")
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		Bx(G, W, "Kerb_" .. tag, 100, 0, s * 15, 190, 0.3, s * 15.5, rgb(205, 205, 200), { studs = true })
		Bx(G, W, "Pavement_" .. tag, 100, 0, s * 15.5, 190, 0.3, s * 20, rgb(172, 172, 168), { studs = true })
		for _, seg in { { 100, 128 }, { 152, 190 } } do
			Bx(G, W, "YellowLine_" .. tag .. "_A" .. seg[1], seg[1], 0, s * 14.45, seg[2], 0.04, s * 14.6, rgb(255, 200, 0), { decor = true, noShadow = true })
			Bx(G, W, "YellowLine_" .. tag .. "_B" .. seg[1], seg[1], 0, s * 14.15, seg[2], 0.04, s * 14.3, rgb(255, 200, 0), { decor = true, noShadow = true })
		end
		for _, seg in { { 128.5, 136.5 }, { 143.5, 151.5 } } do
			local nSeg = 6
			local dx = (seg[2] - seg[1]) / nSeg
			for k = 0, nSeg - 1 do
				local xa, xb = seg[1] + k * dx, seg[1] + (k + 1) * dx
				local za = s * (14.35 + ((k % 2 == 0) and 0.3 or -0.3))
				local zb = s * (14.35 + ((k % 2 == 0) and -0.3 or 0.3))
				local len = math.sqrt((xb - xa) ^ 2 + (zb - za) ^ 2)
				P(G, "ZigZag_" .. tag .. seg[1] .. "_" .. k, CFrame.new((xa + xb) / 2, 0.02, (za + zb) / 2) * CFrame.Angles(0, math.atan2(-(zb - za), xb - xa), 0), Vector3.new(len + 0.1, 0.04, 0.15), whiteL, { decor = true, noShadow = true })
			end
		end
	end
	for i = 0, 11 do
		local z0 = -13.8 + i * 2.4
		Bx(G, W, "Zebra_" .. (i + 1), 137, 0, z0, 143, 0.04, z0 + 1.2, whiteL, { decor = true, noShadow = true })
	end

	-- Balises orange du passage piéton
	local D = folder("Props")
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		local x, z = 136.2, s * 16.3
		vcyl(D, "Beacon_" .. tag .. "_Base", x, 0.3, 0.6, z, 0.65, iron)
		for k = 0, 7 do
			vcyl(D, "Beacon_" .. tag .. "_Pole" .. k, x, 0.6 + k * 0.6, 1.2 + k * 0.6, z, 0.34, (k % 2 == 0) and iron or whiteL)
		end
		local globe = P(D, "Beacon_" .. tag .. "_Globe", CFrame.new(x, 5.95, z), Vector3.new(1.1, 1.1, 1.1), rgb(255, 150, 30), { shape = Enum.PartType.Ball, mat = Enum.Material.Neon, decor = true, noShadow = true })
		local pl = Instance.new("PointLight"); pl.Color = rgb(255, 160, 60); pl.Range = 9; pl.Brightness = 0.8; pl.Shadows = false; pl.Parent = globe
	end

	-- Réverbères victoriens (évitent portes, marches et pots des magasins)
	for tag, xs in { N = { 106, 124, 158.5, 176.5, 186 }, S = { 106, 121, 156, 172, 182.5 } } do
		local s = (tag == "N") and 1 or -1
		for i, x in xs do
			local z, nm = s * 16.3, "Lamp_" .. tag .. i
			Bx(D, W, nm .. "_Base", x - 0.45, 0.3, z - 0.45, x + 0.45, 1.3, z + 0.45, iron)
			vcyl(D, nm .. "_Pole", x, 1.3, 8.8, z, 0.34, iron)
			vcyl(D, nm .. "_Collar", x, 4.0, 4.25, z, 0.5, gold, { decor = true })
			Bx(D, W, nm .. "_Bar", x - 0.7, 7.6, z - 0.08, x + 0.7, 7.75, z + 0.08, iron, { decor = true })
			Bx(D, W, nm .. "_Plate", x - 0.4, 8.8, z - 0.4, x + 0.4, 8.95, z + 0.4, iron, { decor = true })
			local glow = Bx(D, W, nm .. "_Glow", x - 0.31, 8.95, z - 0.31, x + 0.31, 10.05, z + 0.31, rgb(255, 222, 160), { mat = Enum.Material.Neon, decor = true, noShadow = true })
			Bx(D, W, nm .. "_Cap", x - 0.45, 10.05, z - 0.45, x + 0.45, 10.3, z + 0.45, iron, { decor = true })
			Bx(D, W, nm .. "_Finial", x - 0.12, 10.3, z - 0.12, x + 0.12, 10.65, z + 0.12, iron, { decor = true })
			local pl = Instance.new("PointLight"); pl.Color = rgb(255, 214, 150); pl.Range = 22; pl.Brightness = 1.1; pl.Shadows = false; pl.Parent = glow
		end
	end

	-- Cabines téléphoniques rouges (facing -1 : porte vers -Z, côté nord)
	local function phoneBox(name, cx, cz, facing)
		local m = Instance.new("Model"); m.Name = name; m.Parent = D
		local fr = CFrame.new(cx, 0.3, cz) * ((facing > 0) and CFrame.Angles(0, math.pi, 0) or CFrame.identity)
		Bx(m, fr, "Base", -1.4, 0, -1.4, 1.4, 0.3, 1.4, red)
		for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			Bx(m, fr, "Post_" .. i, c[1] * 1.2 - 0.18, 0.3, c[2] * 1.2 - 0.18, c[1] * 1.2 + 0.18, 6.4, c[2] * 1.2 + 0.18, red)
		end
		for _, sd in { { "Front", 0, -1 }, { "Back", 0, 1 }, { "Left", -1, 0 }, { "Right", 1, 0 } } do
			local nx, nz = sd[2], sd[3]
			local function sideBox(nm, t0, y0, t1, y1, d0, d1, color, opt)
				if nx == 0 then return Bx(m, fr, nm, t0, y0, nz * d0, t1, y1, nz * d1, color, opt) end
				return Bx(m, fr, nm, nx * d0, y0, t0, nx * d1, y1, t1, color, opt)
			end
			sideBox("Panel_" .. sd[1], -1.02, 0.3, 1.02, 1.3, 1.1, 1.26, red)
			sideBox("Glass_" .. sd[1], -1.02, 1.3, 1.02, 5.7, 1.14, 1.2, rgb(150, 190, 210), { mat = Enum.Material.Glass, T = 0.45 })
			for k = 1, 3 do
				local y = 1.3 + k * 1.1
				sideBox("Bar_" .. sd[1] .. k, -1.02, y - 0.06, 1.02, y + 0.06, 1.12, 1.24, red, { decor = true })
			end
			sideBox("VBar_" .. sd[1], -0.06, 1.3, 0.06, 5.7, 1.12, 1.24, red, { decor = true })
			local hdr = sideBox("Header_" .. sd[1], -1.02, 5.7, 1.02, 6.4, 1.1, 1.26, rgb(20, 20, 24), { decor = true })
			label(hdr, faceFor(nx, nz), "TÉLÉPHONE", rgb(255, 255, 255), 50)
		end
		Bx(m, fr, "Roof1", -1.5, 6.4, -1.5, 1.5, 6.8, 1.5, red)
		Bx(m, fr, "Roof2", -1.25, 6.8, -1.25, 1.25, 7.15, 1.25, red, { decor = true })
		Bx(m, fr, "Roof3", -0.8, 7.15, -0.8, 0.8, 7.4, 0.8, red, { decor = true })
		Bx(m, fr, "Phone", -0.35, 3.0, 0.85, 0.35, 3.9, 1.1, iron, { decor = true })
	end
	phoneBox("PhoneBox_N", 116.5, 16.95, -1)
	phoneBox("PhoneBox_S", 113.0, -16.95, 1)

	-- Boîte aux lettres
	do
		local cx, cz, facing = 109.0, 16.6, -1
		local m = Instance.new("Model"); m.Name = "PostBox"; m.Parent = D
		vcyl(m, "Body", cx, 0.3, 3.4, cz, 1.3, red)
		vcyl(m, "Band", cx, 0.3, 0.55, cz, 1.4, iron, { decor = true })
		vcyl(m, "Cap", cx, 3.4, 3.65, cz, 1.5, red, { decor = true })
		P(m, "Dome", CFrame.new(cx, 3.65, cz), Vector3.new(1.3, 1.3, 1.3), red, { shape = Enum.PartType.Ball, decor = true })
		Bx(m, W, "Slot", cx - 0.35, 2.75, cz + facing * 0.52, cx + 0.35, 2.87, cz + facing * 0.69, rgb(20, 20, 24), { decor = true })
		local plate = Bx(m, W, "Plate", cx - 0.3, 1.9, cz + facing * 0.55, cx + 0.3, 2.45, cz + facing * 0.7, rgb(250, 250, 245), { decor = true })
		label(plate, Enum.NormalId.Front, "LETTRES", red, 80, rgb(250, 250, 245))
	end

	-- Maisons mitoyennes plaquées sur les murets (le muret reste le vrai mur, la maison n'a pas de collision)
	local H = folder("Houses")
	local function house(name, frame, w, body, door)
		local m = Instance.new("Model"); m.Name = name; m.Parent = H
		local stuccoH, stone, glassD = rgb(236, 230, 215), rgb(200, 198, 190), rgb(52, 66, 92)
		local dk = { decor = true }
		Bx(m, frame, "Wall", 0, 0, 0, w, 17.5, 1.35, body, { studs = true, decor = true })
		Bx(m, frame, "Plinth", 0, 0.3, -0.08, w, 1.1, 0, rgb(70, 70, 76), dk)
		Bx(m, frame, "Divider", w - 0.2, 0.3, -0.1, w, 17.5, 0, stuccoH, dk)
		Bx(m, frame, "StringCourse", 0, 7.7, -0.15, w, 8.0, 0, stuccoH, dk)
		Bx(m, frame, "Cornice", -0.05, 17.5, -0.45, w + 0.05, 18.0, 1.35, stuccoH, dk)
		Bx(m, frame, "DoorSurround", 0.9, 0.9, -0.1, 3.3, 7.4, 0, stuccoH, dk)
		Bx(m, frame, "FrontDoor", 1.2, 0.9, -0.16, 3.0, 6.35, -0.1, door, dk)
		Bx(m, frame, "Fanlight", 1.2, 6.5, -0.16, 3.0, 7.15, -0.1, glassD, { decor = true, mat = Enum.Material.Glass })
		P(m, "Knob", frame * CFrame.new(2.6, 3.5, -0.16), Vector3.new(0.22, 0.22, 0.22), gold, { decor = true, shape = Enum.PartType.Ball })
		Bx(m, frame, "Step1", 0.7, 0.3, -1.3, 3.5, 0.6, 0, stone, { studs = true })
		Bx(m, frame, "Step2", 0.7, 0.6, -0.7, 3.5, 0.9, 0, stone, { studs = true })
		local function window(nm, a, b, c, d)
			Bx(m, frame, nm .. "Frame", a - 0.2, c - 0.05, -0.08, b + 0.2, d + 0.2, 0, stuccoH, dk)
			Bx(m, frame, nm .. "Glass", a, c, -0.12, b, d, -0.08, glassD, { decor = true, mat = Enum.Material.Glass })
			Bx(m, frame, nm .. "Rail", a, (c + d) / 2 - 0.07, -0.16, b, (c + d) / 2 + 0.07, -0.12, stuccoH, dk)
			Bx(m, frame, nm .. "Sill", a - 0.35, c - 0.4, -0.4, b + 0.35, c - 0.05, 0, stuccoH, dk)
		end
		window("Bay", 4.3, w - 1.0, 2.2, 6.4)
		for f, ys in { { 9.0, 12.3 }, { 13.5, 16.3 } } do
			for k, fx in { 0.2, 0.5, 0.8 } do
				local cx = w * fx
				window("W" .. f .. k, cx - 0.85, cx + 0.85, ys[1], ys[2])
			end
		end
		local cxm = w * 0.5
		Bx(m, frame, "Chimney", cxm - 0.9, 18.0, 0.15, cxm + 0.9, 20.6, 1.25, rgb(150, 62, 48), { studs = true, decor = true })
		Bx(m, frame, "ChimneyCap", cxm - 1.05, 20.6, 0.05, cxm + 1.05, 20.85, 1.35, stuccoH, dk)
		for k, dx in { -0.45, 0.45 } do
			P(m, "ChimneyPot" .. k, frame * CFrame.new(cxm + dx, 21.225, 0.7) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.75, 0.5, 0.5), rgb(190, 95, 60), { shape = Enum.PartType.Cylinder, decor = true })
		end
	end
	local styles = {
		N = { { rgb(176, 70, 52), rgb(190, 30, 40) }, { rgb(236, 228, 210), rgb(30, 45, 95) }, { rgb(140, 58, 46), rgb(30, 100, 60) }, { rgb(168, 200, 230), rgb(240, 190, 40) }, { rgb(176, 70, 52), rgb(25, 25, 30) } },
		S = { { rgb(242, 222, 150), rgb(40, 90, 170) }, { rgb(160, 66, 50), rgb(190, 30, 40) }, { rgb(170, 220, 195), rgb(25, 25, 30) }, { rgb(240, 236, 226), rgb(190, 30, 40) }, { rgb(140, 58, 46), rgb(30, 45, 95) } },
	}
	for tag, st in styles do
		local s = (tag == "N") and 1 or -1
		local idx = 0
		for _, seg in { { 101, 120, 2 }, { 160, 189, 3 } } do
			local w = (seg[2] - seg[1]) / seg[3]
			for k = 0, seg[3] - 1 do
				idx += 1
				local x0, x1 = seg[1] + k * w, seg[1] + (k + 1) * w
				local frame = (s > 0) and CFrame.new(x0, 0, 19.85) or (CFrame.new(x1, 0, -19.85) * CFrame.Angles(0, math.pi, 0))
				house("House_" .. tag .. idx, frame, w, st[idx][1], st[idx][2])
			end
		end
	end

	-- Tours d'horloge derrière les murets, près de l'arche x = 100
	local T = folder("ClockTowers")
	local function clockTower(name, cx, cz)
		local m = Instance.new("Model"); m.Name = name; m.Parent = T
		local stone, trim, dark = rgb(214, 196, 152), rgb(184, 164, 122), rgb(40, 44, 54)
		local slate = rgb(70, 78, 92)
		local fr = CFrame.new(cx, 0, cz)
		Bx(m, fr, "Plinth", -2.8, 0, -2.8, 2.8, 2, 2.8, trim, { studs = true })
		Bx(m, fr, "Shaft", -2.5, 2, -2.5, 2.5, 24, 2.5, stone, { studs = true })
		for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			Bx(m, fr, "Buttress_" .. i, c[1] * 2.5 - 0.35, 2, c[2] * 2.5 - 0.35, c[1] * 2.5 + 0.35, 24, c[2] * 2.5 + 0.35, trim, { studs = true })
		end
		Bx(m, fr, "ClockStage", -2.9, 24, -2.9, 2.9, 29, 2.9, stone, { studs = true })
		Bx(m, fr, "Cornice", -3.2, 29, -3.2, 3.2, 29.5, 3.2, trim)
		Bx(m, fr, "Belfry", -2.5, 29.5, -2.5, 2.5, 32, 2.5, stone, { studs = true })
		for i, t in { { 2.3, 32, 33.2 }, { 1.8, 33.2, 34.6 }, { 1.3, 34.6, 36.2 }, { 0.8, 36.2, 38 }, { 0.4, 38, 39.6 } } do
			Bx(m, fr, "Spire_" .. i, -t[1], t[2], -t[1], t[1], t[3], t[1], slate, { studs = true, decor = i > 1 })
		end
		Bx(m, fr, "Finial", -0.15, 39.6, -0.15, 0.15, 41.1, 0.15, gold, { decor = true })
		P(m, "FinialBall", fr * CFrame.new(0, 41.3, 0), Vector3.new(0.6, 0.6, 0.6), gold, { shape = Enum.PartType.Ball, decor = true })
		local up = Vector3.yAxis
		for _, dd in { { "N", 0, -1 }, { "S", 0, 1 }, { "W", -1, 0 }, { "E", 1, 0 } } do
			local nx, nz = dd[2], dd[3]
			local function onFace(nm, t0, y0, t1, y1, d0, d1, color, opt)
				if nx == 0 then return Bx(m, fr, nm, t0, y0, nz * d0, t1, y1, nz * d1, color, opt) end
				return Bx(m, fr, nm, nx * d0, y0, t0, nx * d1, y1, t1, color, opt)
			end
			onFace("Slit_" .. dd[1], -0.35, 15, 0.35, 19.5, 2.45, 2.56, dark, { decor = true })
			onFace("Slit2_" .. dd[1], -0.35, 8, 0.35, 11.5, 2.45, 2.56, dark, { decor = true })
			onFace("Arch_" .. dd[1], -0.8, 30.0, 0.8, 31.6, 2.45, 2.56, dark, { decor = true })
			local nrm = Vector3.new(nx, 0, nz)
			local right = (-nrm):Cross(up)
			local c = Vector3.new(cx, 26.5, cz)
			P(m, "ClockRim_" .. dd[1], CFrame.fromMatrix(c + nrm * 2.93, nrm, up), Vector3.new(0.15, 4.4, 4.4), gold, { shape = Enum.PartType.Cylinder, decor = true })
			P(m, "ClockFace_" .. dd[1], CFrame.fromMatrix(c + nrm * 2.95, nrm, up), Vector3.new(0.2, 4.0, 4.0), rgb(250, 248, 240), { shape = Enum.PartType.Cylinder, decor = true })
			P(m, "MinuteHand_" .. dd[1], CFrame.fromMatrix(c + nrm * 3.1 + up * 0.8, nrm, up), Vector3.new(0.06, 1.6, 0.14), iron, { decor = true })
			P(m, "HourHand_" .. dd[1], CFrame.fromMatrix(c + nrm * 3.1 + right * 0.55, nrm, up), Vector3.new(0.06, 0.2, 1.1), iron, { decor = true })
			P(m, "ClockPin_" .. dd[1], CFrame.new(c + nrm * 3.12), Vector3.new(0.35, 0.35, 0.35), gold, { shape = Enum.PartType.Ball, decor = true })
		end
	end
	clockTower("ClockTower_N", 105, 25)
	clockTower("ClockTower_S", 105, -25)
end

return string.format("Zone 2 Londres : jouets %d produits, confiserie %d produits, rue posée", toyN, candyN)
