--!nocheck
-- Zone 2 — Londres (MOD-020), gabarit commun du 2026-11-07 : magasins et décor à l'échelle ×1.5, couloir de 60 studs
-- entre les façades, quartier rempli (immeubles, bus à impériale, grande roue) et reconnaissable dès l'arche
-- (tours d'horloge, bruine, brume, pavés sombres et mouillés, fanions rouges, blancs et bleus).
-- À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS tools/clement/store_builder.luau (option scale).
-- Relançable : magasins et Street_Londres refaits à l'identique ; l'arche n'est agrandie qu'une fois (ScaleTo est absolu).
-- Se termine par sa propre vérification : contrat 10.4, chaussée, emprise, chevauchements, chemins du vigile.
-- Plan, x 100..190 :
--   chaussée z −22,5..22,5 libre ; trottoirs |z| 22,5..30, 0,45 de haut (le sol des magasins) ; façades à |z| = 30 ;
--   murets |z| 30..31,5, 18 de haut, à x 100..110 et 170..190 ; magasins x 110..170, |z| 30..102 ;
--   greybox jusqu'à |z| 62,5, sol ajouté de 62,5 à 140 dans Map/Zone_2 (au sud, la Tamise de 130 à 140).
-- Règles : aucun script laissé dans la map ; noms du contrat (10.4) jamais réutilisés pour le décor ; rien hors de x 100..190.

local rgb = Color3.fromRGB
local Store = _G.ClaudeStore
assert(Store, "charger d'abord tools/clement/store_builder.luau")

local K = 1.5                      -- échelle du gabarit : magasins, arche, décor
local ROAD, FACADE = 22.5, 30      -- demi-largeur de la chaussée, ligne des façades
local PAVE = 0.45                  -- dessus des trottoirs = sol des magasins
local GROUND = rgb(84, 86, 92)     -- dallage sombre des sols latéraux et arrière
local Neon, Glass = Enum.Material.Neon, Enum.Material.Glass
local Ball, Cyl = Enum.PartType.Ball, Enum.PartType.Cylinder

-- Model:ScaleTo agrandit pièces, SurfaceGui et particules, mais pas la portée des lumières : on la reprend ici.
local function growLights(root, k)
	for _, l in root:GetDescendants() do
		if l:IsA("PointLight") or l:IsA("SpotLight") or l:IsA("SurfaceLight") then l.Range = math.min(60, l.Range * k) end
	end
end

-- Façade londonienne : devanture peinte, enseigne en bandeau, deux étages de fenêtres à guillotine,
-- plaque bleue, enseigne suspendue, et un vrai volume derrière la façade (pas un simple décor plat).
-- Dessinée à la taille d'origine du constructeur, puis agrandie avec tout le magasin (spec.scale).
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

-- 1) Greybox de la zone 2 : magasins gris mis de côté, chaussée élargie en pavés sombres et mouillés, sols latéraux
--    jusqu'à |z| 62,5, murets de 18 calés sur les façades, arche agrandie (nom, tag et structure inchangés).
local gateInfo
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
	local function put(p, x0, y0, z0, x1, y1, z1)
		p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
		p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	end
	put(g.Street, 100, -2, -ROAD, 190, 0, ROAD)
	put(g.Side_N, 100, -2, ROAD, 190, 0, 62.5)
	put(g.Side_S, 100, -2, -62.5, 190, 0, -ROAD)
	put(g.SideWall_N1, 100, 0, FACADE, 110, 18, FACADE + 1.5)
	put(g.SideWall_S1, 100, 0, -FACADE - 1.5, 110, 18, -FACADE)
	put(g.SideWall_N2, 170, 0, FACADE, 190, 18, FACADE + 1.5)
	put(g.SideWall_S2, 170, 0, -FACADE - 1.5, 190, 18, -FACADE)
	g.Street.Material = Enum.Material.Cobblestone; g.Street.MaterialVariant = ""
	g.Street.Color = rgb(58, 60, 70); g.Street.Reflectance = 0.12
	for _, p in { g.Side_N, g.Side_S } do p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"; p.Color = GROUND end
	local gate = gz2.ZoneGate_2
	if math.abs(gate:GetScale() - K) > 1e-4 then gate:ScaleTo(K) end
	local cf, sz = gate:GetBoundingBox()
	gate:PivotTo(gate:GetPivot() + Vector3.new(100 - cf.X, sz.Y / 2 - cf.Y, -cf.Z))
	cf, sz = gate:GetBoundingBox()
	gateInfo = string.format("Arche ZoneGate_2 : échelle %.2f, x %.1f, base y %.2f, centre z %.2f, %.0f × %.0f studs",
		gate:GetScale(), cf.X, cf.Y - sz.Y / 2, cf.Z, sz.Z, sz.Y)
end

-- 2) Magasins : mêmes specs, pivots du gabarit (façades à z = ±30) et scale = 1.5 ; le contrat s'agrandit avec eux.
local zoneFolder = workspace.Map:FindFirstChild("Zone_2")
if not zoneFolder then zoneFolder = Instance.new("Folder"); zoneFolder.Name = "Zone_2"; zoneFolder.Parent = workspace.Map end
for _, nm in { "STORE_Z2_MagasinDeJouets", "STORE_Z2_Confiserie" } do
	local old = zoneFolder:FindFirstChild(nm); if old then old:Destroy() end
end

local brick, stucco, gold = rgb(176, 70, 52), rgb(240, 236, 224), rgb(212, 175, 55)
local navy = rgb(35, 55, 110)

-- Magasin de jouets : brique rouge, devanture bleu marine et or, auvent vert et blanc
local toy, toyN = Store.build({
	name = "STORE_Z2_MagasinDeJouets", zone = 2,
	origin = CFrame.new(140, 0, 66), parent = zoneFolder, scale = K,
	sign = "TOY SHOP",
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
		A_L = { "PLUSHIES", rgb(232, 90, 140) }, A_R = { "BOARD GAMES", rgb(46, 134, 222) },
		B_L = { "BUILDING SETS", rgb(255, 150, 30) }, B_R = { "DOLLS", rgb(186, 92, 220) },
		WallL = { "ROBOTS", rgb(60, 160, 200) }, WallR = { "SPORTS", rgb(53, 170, 70) }, Back = { "NEW IN", rgb(232, 65, 60) },
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
		plaque = "THE FIRST\nTEDDY BEAR\nWAS BORN HERE\n1887", hanging = "TOYS",
		panel = "TOYS\n& GAMES", panelColor = rgb(28, 44, 92),
	},
	facade = londonFacade,
})
task.wait()

-- Confiserie : façade peinte en rose (style Notting Hill), devanture menthe, auvent rose et blanc
local pink, mint, white = rgb(240, 172, 192), rgb(98, 192, 160), rgb(250, 248, 242)
local candy, candyN = Store.build({
	name = "STORE_Z2_Confiserie", zone = 2,
	origin = CFrame.new(140, 0, -66) * CFrame.Angles(0, math.pi, 0), parent = zoneFolder, scale = K,
	sign = "SWEET SHOP",
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
		A_L = { "SWEETS", rgb(240, 100, 160) }, A_R = { "CHOCOLATE", rgb(130, 80, 50) },
		B_L = { "LOLLIPOPS", rgb(255, 150, 40) }, B_R = { "MARSHMALLOWS", rgb(170, 120, 220) },
		WallL = { "TOFFEE", rgb(220, 150, 60) }, WallR = { "CAKES", rgb(232, 80, 110) }, Back = { "ICE CREAM", rgb(60, 180, 220) },
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
		plaque = "THE FIRST\nMARSHMALLOW\nWAS MADE HERE\n1887", hanging = "SWEETS",
		panel = "SWEETS\n& TREATS", panelColor = rgb(70, 160, 130), panelText = rgb(255, 255, 255),
	},
	facade = londonFacade,
})
-- portée des lumières des magasins ×1.5 (sautée si le constructeur s'en charge un jour)
for _, m in { toy, candy } do
	local probe = m:FindFirstChild("CeilingLight_1", true)
	local pl = probe and probe:FindFirstChildWhichIsA("PointLight")
	if pl and pl.Range < 20 * K - 0.01 then growLights(m, K) end
end
task.wait()

-- 3) Décor : Map/Zone_2/Street_Londres. Le mobilier de rue, les maisons et les tours d'horloge sont dessinés à leur
--    ancienne taille autour de l'origine, puis agrandis ×1.5 et posés (settle) ; les grands éléments (immeubles, bus,
--    grande roue, météo) sont dessinés à la taille finale. Chaque groupe est rangé puis Studio respire (task.wait).
local Z = zoneFolder
do local old = Z:FindFirstChild("Street_Londres"); if old then old:Destroy() end end
local S = Instance.new("Folder"); S.Name = "Street_Londres"; S.Parent = Z

local function with(opt, extra)
	local o = {}
	if opt then for k, v in opt do o[k] = v end end
	if extra then for k, v in extra do o[k] = v end end
	return o
end
local function P(parent, name, cf, size, color, opt)
	opt = opt or {}
	local p = Instance.new(opt.wedge and "WedgePart" or "Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if opt.shape then p.Shape = opt.shape end
	if opt.mat then p.Material = opt.mat
	elseif opt.studs then p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
	else p.Material = Enum.Material.SmoothPlastic end
	if opt.decor or opt.flat then p.CanCollide = false; p.CanTouch = false end
	if opt.flat then p.CanQuery = false; p.CastShadow = false end
	if opt.T then p.Transparency = opt.T end
	if opt.refl then p.Reflectance = opt.refl end
	if opt.noShadow then p.CastShadow = false end
	p.Parent = parent
	return p
end
local function Bx(parent, frame, name, x0, y0, z0, x1, y1, z1, color, opt)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	return P(parent, name, frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), size, color, opt)
end
local function vcyl(parent, name, x, y0, y1, z, dia, color, opt)
	return P(parent, name, CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(y1 - y0, dia, dia), color, with(opt, { shape = Cyl }))
end
local function disc(parent, name, x, y0, z, dia, h, color, opt)
	return P(parent, name, CFrame.new(x, y0 + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(h, dia, dia), color, with(opt, { shape = Cyl }))
end
local function bar(parent, name, a, b, thick, color, opt)   -- poutre droite de a à b
	local d = b - a
	local up = (math.abs(d.Unit.Y) > 0.99) and Vector3.xAxis or Vector3.yAxis
	return P(parent, name, CFrame.lookAt((a + b) / 2, b, up), Vector3.new(thick, thick, d.Magnitude), color, opt)
end
local function label(part, face, text, color, ppS, stroke)
	local g = Instance.new("SurfaceGui"); g.Name = "LabelGui_" .. face.Name; g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppS or 40; g.LightInfluence = 0
	local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
	t.Text = text; t.TextScaled = true; t.TextWrapped = true; t.TextColor3 = color
	t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	if stroke ~= false then
		local s = Instance.new("UIStroke"); s.Color = stroke or Color3.new(0, 0, 0); s.Thickness = 3; s.LineJoinMode = Enum.LineJoinMode.Round; s.Parent = t
	end
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0.14, 0); pad.PaddingBottom = UDim.new(0.14, 0); pad.Parent = t
	t.Parent = g; g.Parent = part
	return t
end
local function faceFor(nx, nz)
	if nz < 0 then return Enum.NormalId.Front elseif nz > 0 then return Enum.NormalId.Back elseif nx < 0 then return Enum.NormalId.Left end
	return Enum.NormalId.Right
end
local function settle(m, target)   -- modèle dessiné à l'ancienne taille autour de l'origine : ×1.5, lumières comprises, puis posé
	m.WorldPivot = CFrame.identity
	m:ScaleTo(K)
	growLights(m, K)
	m:PivotTo(target)
	return m
end
local function group(name) local f = Instance.new("Model"); f.Name = name; return f end
local function flush(f) f.Parent = S; task.wait() end

local W, O = CFrame.identity, CFrame.identity
local iron, red = rgb(25, 25, 30), rgb(200, 30, 35)
local whiteL = rgb(245, 245, 240)
local FLAT = { flat = true }

-- 3a) Sol : sol ajouté derrière les magasins, trottoirs, marquages anglais, flaques, Tamise, square
do
	local G = group("Ground")
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		Bx(G, W, "BackGround_" .. tag, 100, -2, s * 62.5, 190, 0, s * ((s > 0) and 140 or 130), GROUND, { studs = true })
		Bx(G, W, "Kerb_" .. tag, 100, 0, s * ROAD, 190, PAVE, s * 23.25, rgb(196, 196, 192), { studs = true })
		Bx(G, W, "Pavement_" .. tag, 100, 0, s * 23.25, 190, PAVE, s * FACADE, rgb(146, 147, 150), { studs = true, refl = 0.04 })
		for _, seg in { { 100.5, 122.5 }, { 157.5, 189.5 } } do
			Bx(G, W, "YellowLine_" .. tag .. "_A" .. seg[1], seg[1], 0, s * 21.67, seg[2], 0.04, s * 21.9, rgb(255, 200, 0), FLAT)
			Bx(G, W, "YellowLine_" .. tag .. "_B" .. seg[1], seg[1], 0, s * 21.22, seg[2], 0.04, s * 21.45, rgb(255, 200, 0), FLAT)
		end
		for _, seg in { { 123, 134.5 }, { 145.5, 157 } } do
			local nSeg = 6
			local dx = (seg[2] - seg[1]) / nSeg
			for k = 0, nSeg - 1 do
				local xa, xb = seg[1] + k * dx, seg[1] + (k + 1) * dx
				local za = s * (21.55 + ((k % 2 == 0) and 0.45 or -0.45))
				local zb = s * (21.55 + ((k % 2 == 0) and -0.45 or 0.45))
				local len = math.sqrt((xb - xa) ^ 2 + (zb - za) ^ 2)
				P(G, "ZigZag_" .. tag .. seg[1] .. "_" .. k, CFrame.new((xa + xb) / 2, 0.02, (za + zb) / 2) * CFrame.Angles(0, math.atan2(-(zb - za), xb - xa), 0), Vector3.new(len + 0.15, 0.04, 0.22), whiteL, FLAT)
			end
		end
	end
	for i = 0, 11 do
		local z0 = -20.7 + i * 3.6
		Bx(G, W, "Zebra_" .. (i + 1), 135.5, 0, z0, 144.5, 0.04, z0 + 1.8, whiteL, FLAT)
	end
	for i, x in { 101.5, 109.5, 157.5, 173.5, 181.5 } do   -- tirets centraux, coupés au passage piéton et aux NightPatrol
		Bx(G, W, "CentreDash_" .. i, x, 0, -0.15, x + 4, 0.04, 0.15, whiteL, FLAT)
	end
	local wet = { refl = 0.35, T = 0.25, flat = true }
	for i, p in { { 112, -12, 2.6 }, { 127, 14, 3.2 }, { 151, -8, 2.4 }, { 163, 12, 3.0 }, { 178, -15, 2.8 }, { 186, 6, 2.2 }, { 121, 26, 1.8, PAVE }, { 172, -26, 2.0, PAVE } } do
		local y0 = p[4] or 0
		disc(G, "Puddle_" .. i .. "_A", p[1], y0, p[2], p[3] * 2, 0.025, rgb(60, 70, 86), wet)
		disc(G, "Puddle_" .. i .. "_B", p[1] + p[3] * 0.6, y0, p[2] - p[3] * 0.35, p[3] * 1.3, 0.035, rgb(60, 70, 86), wet)
	end
	Bx(G, W, "River", 100, -2, -130, 190, -0.9, -140, rgb(46, 70, 88), { refl = 0.3, decor = true })
	Bx(G, W, "Embankment", 100, -0.9, -130, 190, 1.4, -129.2, rgb(176, 170, 156), { studs = true })
	Bx(G, W, "GardenSquare", 104, 0, 127, 186, 0.3, 138, rgb(78, 128, 64), { studs = true })
	flush(G)
end

-- 3b) Mobilier de rue (ancienne taille, puis ×1.5) : réverbères à paniers de fleurs, cabines, boîte aux lettres,
--     balises du passage piéton, arrêt de bus ; guirlandes de fanions rouges, blancs et bleus le long des trottoirs.
do
	local D = group("Props")
	local function lamp(name, x, z)
		local m = Instance.new("Model"); m.Name = name; m.Parent = D
		Bx(m, O, "Base", -0.45, 0, -0.45, 0.45, 1.0, 0.45, iron)
		vcyl(m, "Pole", 0, 1.0, 8.5, 0, 0.34, iron)
		vcyl(m, "Collar", 0, 3.7, 3.95, 0, 0.5, gold, { decor = true })
		Bx(m, O, "Arm", -0.7, 7.3, -0.08, 0.7, 7.45, 0.08, iron, { decor = true })
		Bx(m, O, "LampPlate", -0.4, 8.5, -0.4, 0.4, 8.65, 0.4, iron, { decor = true })
		local glow = Bx(m, O, "Glow", -0.31, 8.65, -0.31, 0.31, 9.75, 0.31, rgb(255, 222, 160), { mat = Neon, decor = true, noShadow = true })
		Bx(m, O, "Cap", -0.45, 9.75, -0.45, 0.45, 10.0, 0.45, iron, { decor = true })
		Bx(m, O, "Finial", -0.12, 10.0, -0.12, 0.12, 10.35, 0.12, iron, { decor = true })
		local pl = Instance.new("PointLight"); pl.Color = rgb(255, 214, 150); pl.Range = 22; pl.Brightness = 1.1; pl.Shadows = false; pl.Parent = glow
		for i, sx in { -0.62, 0.62 } do
			Bx(m, O, "BasketChain_" .. i, sx - 0.02, 6.4, -0.02, sx + 0.02, 7.3, 0.02, iron, { decor = true, noShadow = true })
			P(m, "Basket_" .. i, CFrame.new(sx, 6.1, 0), Vector3.new(0.7, 0.7, 0.7), rgb(46, 110, 56), { shape = Ball, decor = true })
			P(m, "BasketFlowers_" .. i, CFrame.new(sx, 6.35, 0), Vector3.new(0.55, 0.55, 0.55), (i == 1) and rgb(230, 60, 120) or rgb(250, 150, 40), { shape = Ball, decor = true, noShadow = true })
		end
		return settle(m, CFrame.new(x, PAVE, z))
	end
	-- guirlande d'un réverbère à l'autre : corde en chaînette, fanions en triangle (deux demi-coins)
	local function bunting(name, xa, xb, z, y, sag)
		local m = Instance.new("Model"); m.Name = name; m.Parent = D
		local function cy(x) local t = (x - xa) / (xb - xa); return y - sag * 4 * t * (1 - t) end
		for k = 0, 5 do
			local x0, x1 = xa + (xb - xa) * k / 6, xa + (xb - xa) * (k + 1) / 6
			bar(m, "Cord_" .. k, Vector3.new(x0, cy(x0), z), Vector3.new(x1, cy(x1), z), 0.07, rgb(235, 235, 230), { decor = true, noShadow = true })
		end
		local cols = { rgb(200, 30, 40), rgb(245, 245, 245), rgb(30, 60, 150) }
		local w, h, pitch = 1.5, 1.8, 2.3
		local count = math.floor((xb - xa - 1.2) / pitch)
		local first = xa + ((xb - xa) - (count - 1) * pitch) / 2
		for i = 0, count - 1 do
			local c = first + i * pitch
			local topY = cy(c) - 0.04
			local col = cols[i % 3 + 1]
			local o = { wedge = true, decor = true, noShadow = true }
			P(m, "Pennant_" .. i .. "_R", CFrame.fromMatrix(Vector3.new(c + w / 4, topY - h / 2, z), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0), Vector3.new(-1, 0, 0)), Vector3.new(0.06, h, w / 2), col, o)
			P(m, "Pennant_" .. i .. "_L", CFrame.fromMatrix(Vector3.new(c - w / 4, topY - h / 2, z), Vector3.new(0, 0, 1), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0)), Vector3.new(0.06, h, w / 2), col, o)
		end
	end
	-- cabine rouge : porte vers −z avant rotation, téléphone au fond
	local function phoneBox(name, x, z, rot)
		local m = Instance.new("Model"); m.Name = name; m.Parent = D
		Bx(m, O, "Base", -1.4, 0, -1.4, 1.4, 0.3, 1.4, red)
		for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			Bx(m, O, "Post_" .. i, c[1] * 1.2 - 0.18, 0.3, c[2] * 1.2 - 0.18, c[1] * 1.2 + 0.18, 6.4, c[2] * 1.2 + 0.18, red)
		end
		for _, sd in { { "Front", 0, -1 }, { "Back", 0, 1 }, { "Left", -1, 0 }, { "Right", 1, 0 } } do
			local nx, nz = sd[2], sd[3]
			local function sideBox(nm, t0, y0, t1, y1, d0, d1, color, opt)
				if nx == 0 then return Bx(m, O, nm, t0, y0, nz * d0, t1, y1, nz * d1, color, opt) end
				return Bx(m, O, nm, nx * d0, y0, t0, nx * d1, y1, t1, color, opt)
			end
			sideBox("Panel_" .. sd[1], -1.02, 0.3, 1.02, 1.3, 1.1, 1.26, red)
			sideBox("Glass_" .. sd[1], -1.02, 1.3, 1.02, 5.7, 1.14, 1.2, rgb(150, 190, 210), { mat = Glass, T = 0.45 })
			for k = 1, 3 do
				local y = 1.3 + k * 1.1
				sideBox("Bar_" .. sd[1] .. k, -1.02, y - 0.06, 1.02, y + 0.06, 1.12, 1.24, red, { decor = true })
			end
			sideBox("VBar_" .. sd[1], -0.06, 1.3, 0.06, 5.7, 1.12, 1.24, red, { decor = true })
			local hdr = sideBox("Header_" .. sd[1], -1.02, 5.7, 1.02, 6.4, 1.1, 1.26, rgb(20, 20, 24), { decor = true })
			label(hdr, faceFor(nx, nz), "TELEPHONE", rgb(255, 255, 255), 50)
		end
		Bx(m, O, "Roof1", -1.5, 6.4, -1.5, 1.5, 6.8, 1.5, red)
		Bx(m, O, "Roof2", -1.25, 6.8, -1.25, 1.25, 7.15, 1.25, red, { decor = true })
		Bx(m, O, "Roof3", -0.8, 7.15, -0.8, 0.8, 7.4, 0.8, red, { decor = true })
		Bx(m, O, "Phone", -0.35, 3.0, 0.85, 0.35, 3.9, 1.1, iron, { decor = true })
		return settle(m, CFrame.new(x, PAVE, z) * CFrame.Angles(0, rot, 0))
	end
	local function postBox(name, x, z, rot)
		local m = Instance.new("Model"); m.Name = name; m.Parent = D
		vcyl(m, "Body", 0, 0, 3.1, 0, 1.3, red)
		vcyl(m, "Band", 0, 0, 0.25, 0, 1.4, iron, { decor = true })
		vcyl(m, "Cap", 0, 3.1, 3.35, 0, 1.5, red, { decor = true })
		P(m, "Dome", CFrame.new(0, 3.35, 0), Vector3.new(1.3, 1.3, 1.3), red, { shape = Ball, decor = true })
		Bx(m, O, "Slot", -0.35, 2.45, -0.69, 0.35, 2.57, -0.52, rgb(20, 20, 24), { decor = true })
		local plate = Bx(m, O, "LetterPlate", -0.3, 1.6, -0.7, 0.3, 2.15, -0.55, rgb(250, 250, 245), { decor = true })
		label(plate, Enum.NormalId.Front, "LETTERS", red, 80, rgb(250, 250, 245))
		return settle(m, CFrame.new(x, PAVE, z) * CFrame.Angles(0, rot, 0))
	end
	local function beacon(name, x, z)
		local m = Instance.new("Model"); m.Name = name; m.Parent = D
		vcyl(m, "BeaconBase", 0, 0, 0.3, 0, 0.65, iron)
		for k = 0, 7 do vcyl(m, "BeaconPole" .. k, 0, 0.3 + k * 0.6, 0.9 + k * 0.6, 0, 0.34, (k % 2 == 0) and iron or whiteL) end
		local globe = P(m, "BeaconGlobe", CFrame.new(0, 5.65, 0), Vector3.new(1.1, 1.1, 1.1), rgb(255, 150, 30), { shape = Ball, mat = Neon, decor = true, noShadow = true })
		local pl = Instance.new("PointLight"); pl.Color = rgb(255, 160, 60); pl.Range = 9; pl.Brightness = 0.8; pl.Shadows = false; pl.Parent = globe
		return settle(m, CFrame.new(x, PAVE, z))
	end
	local function busStop(name, x, z)
		local m = Instance.new("Model"); m.Name = name; m.Parent = D
		vcyl(m, "StopPole", 0, 0, 7.6, 0, 0.22, iron)
		local flag = Bx(m, O, "StopFlag", -0.06, 5.9, -0.9, 0.06, 7.4, 0.9, red, { decor = true })
		label(flag, Enum.NormalId.Left, "BUS\nSTOP", whiteL, 60, rgb(120, 10, 15))
		label(flag, Enum.NormalId.Right, "BUS\nSTOP", whiteL, 60, rgb(120, 10, 15))
		return settle(m, CFrame.new(x, PAVE, z))
	end
	-- réverbères côté chaussée (z ±24), hors vitrines, portes et pots des magasins ; guirlandes entre eux
	for tag, xs in { N = { 109, 125, 153, 168, 184 }, S = { 110, 127, 153, 168, 184 } } do
		local s = (tag == "N") and 1 or -1
		for i, x in xs do lamp("Lamp_" .. tag .. i, x, s * 24) end
		for i = 1, #xs - 1 do
			bunting("Bunting_" .. tag .. i, xs[i], xs[i + 1], s * 24, PAVE + 12, ((xs[i + 1] - xs[i]) > 20) and 1.8 or 1.1)
		end
	end
	-- à l'entrée, au pied des tours : une cabine de chaque côté, la boîte aux lettres au nord
	phoneBox("PhoneBox_N", 103.3, 27.55, 0)
	phoneBox("PhoneBox_S", 103.3, -27.55, math.pi)
	postBox("PostBox", 107.6, 27.7, 0)
	beacon("Beacon_N", 134.2, 24.2)
	beacon("Beacon_S", 134.2, -24.2)
	busStop("BusStop", 176, 27.9)
	flush(D)
end

-- 3c) Maisons mitoyennes plaquées sur les murets, avec leur volume derrière (le muret reste le vrai mur ; seules les
--     marches ont des collisions). Au nord, x 170..180,5 : le mur de brique du dépôt où le bus est garé.
do
	local H = group("Houses")
	local stuccoH, stone, glassD, slate = rgb(236, 230, 215), rgb(200, 198, 190), rgb(52, 66, 92), rgb(78, 84, 96)
	local function house(name, wNew, depthNew, body, door, target)
		local w, depth = wNew / K, depthNew / K       -- dessinée à l'ancienne taille, agrandie par settle
		local m = Instance.new("Model"); m.Name = name; m.Parent = H
		local f = O
		local dk = { decor = true }
		Bx(m, f, "Wall", 0, 0, 0, w, 17.5, depth, body, { studs = true, decor = true })
		Bx(m, f, "Plinth", 0, 0.3, -0.08, w, 1.1, 0, rgb(70, 70, 76), dk)
		Bx(m, f, "Divider", w - 0.2, 0.3, -0.1, w, 17.5, 0, stuccoH, dk)
		Bx(m, f, "StringCourse", 0, 7.7, -0.15, w, 8.0, 0, stuccoH, dk)
		Bx(m, f, "Cornice", 0, 17.5, -0.45, w, 18.0, depth, stuccoH, dk)
		Bx(m, f, "Roof", 0.25, 18.0, 0.4, w - 0.25, 18.3, depth - 0.25, slate, dk)
		Bx(m, f, "DoorSurround", 0.6, 0.9, -0.1, 3.0, 7.4, 0, stuccoH, dk)
		Bx(m, f, "FrontDoor", 0.9, 0.9, -0.16, 2.7, 6.35, -0.1, door, dk)
		Bx(m, f, "Fanlight", 0.9, 6.5, -0.16, 2.7, 7.15, -0.1, glassD, { decor = true, mat = Glass })
		P(m, "Knob", f * CFrame.new(2.3, 3.5, -0.16), Vector3.new(0.22, 0.22, 0.22), gold, { decor = true, shape = Ball })
		Bx(m, f, "Step1", 0.4, 0.3, -1.3, 3.2, 0.6, 0, stone, { studs = true })
		Bx(m, f, "Step2", 0.4, 0.6, -0.7, 3.2, 0.9, 0, stone, { studs = true })
		local function window(nm, a, b, c, d)
			Bx(m, f, nm .. "Frame", a - 0.2, c - 0.05, -0.08, b + 0.2, d + 0.2, 0, stuccoH, dk)
			Bx(m, f, nm .. "Glass", a, c, -0.12, b, d, -0.08, glassD, { decor = true, mat = Glass })
			Bx(m, f, nm .. "Rail", a, (c + d) / 2 - 0.07, -0.16, b, (c + d) / 2 + 0.07, -0.12, stuccoH, dk)
			Bx(m, f, nm .. "Sill", a - 0.35, c - 0.4, -0.4, b + 0.35, c - 0.05, 0, stuccoH, dk)
		end
		if w - 0.8 - 3.6 >= 1.2 then window("Ground", 3.6, w - 0.8, 2.2, 6.4) end
		local nCols = math.max(1, math.floor((w - 0.4) / 2.9))
		for fl, ys in { { 9.0, 12.3 }, { 13.5, 16.3 } } do
			for k = 1, nCols do
				local cx = w * (k - 0.5) / nCols
				window("W" .. fl .. k, cx - 0.85, cx + 0.85, ys[1], ys[2])
			end
		end
		local cxm, cz = w * 0.5, depth * 0.45
		Bx(m, f, "Chimney", cxm - 0.9, 18.0, cz - 0.55, cxm + 0.9, 20.6, cz + 0.55, rgb(150, 62, 48), { studs = true, decor = true })
		Bx(m, f, "ChimneyCap", cxm - 1.05, 20.6, cz - 0.65, cxm + 1.05, 20.85, cz + 0.65, stuccoH, dk)
		for k, dx in { -0.45, 0.45 } do
			P(m, "ChimneyPot" .. k, f * CFrame.new(cxm + dx, 21.225, cz) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.75, 0.5, 0.5), rgb(190, 95, 60), { shape = Cyl, decor = true })
		end
		return settle(m, target)
	end
	local flip = CFrame.Angles(0, math.pi, 0)
	house("House_N1", 9.5, 14, rgb(176, 70, 52), rgb(190, 30, 40), CFrame.new(180.5, 0, FACADE - 0.15))
	house("House_S1", 10, 14, rgb(242, 222, 150), rgb(40, 90, 170), CFrame.new(180, 0, -FACADE + 0.15) * flip)
	house("House_S2", 9.9, 14, rgb(170, 220, 195), rgb(25, 25, 30), CFrame.new(189.9, 0, -FACADE + 0.15) * flip)
	-- dépôt de bus : brique sur le muret (qui reste le vrai mur), chaperon, piliers, enseigne
	Bx(H, W, "DepotWall", 170.45, 0, 29.85, 180.5, 18, 31.65, rgb(150, 62, 48), { studs = true, decor = true })
	Bx(H, W, "DepotCoping", 170.45, 18, 29.7, 180.5, 18.6, 31.8, stone, { studs = true, decor = true })
	for i, x in { 172.4, 178.6 } do
		Bx(H, W, "DepotPier_" .. i, x - 0.9, PAVE, 29.55, x + 0.9, 18.3, 29.85, rgb(176, 70, 52), { studs = true, decor = true })
	end
	local depot = Bx(H, W, "DepotSign", 171.8, 12.5, 29.4, 179.2, 15.2, 29.55, rgb(28, 44, 92), { decor = true })
	label(depot, Enum.NormalId.Front, "BUS DEPOT", whiteL, 40, rgb(10, 20, 50))
	flush(H)
end

-- 3d) Tours d'horloge (ancienne taille, puis ×1.5, 62 studs) : elles encadrent l'arche, façade alignée sur les magasins,
--     sans collision (le muret et les piliers de l'arche restent les vrais murs) ; plaque de rue au-dessus des cabines.
do
	local T = group("ClockTowers")
	local function streetSign(part)
		local g = Instance.new("SurfaceGui"); g.Name = "LabelGui_Front"; g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 60; g.LightInfluence = 0
		local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
		t.RichText = true; t.TextScaled = true; t.TextWrapped = true
		t.Text = 'PICKPOCKET LANE <font color="#C8102E">SW1</font>'
		t.TextColor3 = rgb(20, 20, 24)
		t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
		local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0.18, 0); pad.PaddingBottom = UDim.new(0.18, 0)
		pad.PaddingLeft = UDim.new(0.04, 0); pad.PaddingRight = UDim.new(0.04, 0); pad.Parent = t
		t.Parent = g; g.Parent = part
	end
	local function clockTower(name, target)
		local m = Instance.new("Model"); m.Name = name; m.Parent = T
		local stone, trim, dark, slate = rgb(214, 196, 152), rgb(184, 164, 122), rgb(40, 44, 54), rgb(70, 78, 92)
		local d, ds = { decor = true }, { studs = true, decor = true }
		Bx(m, O, "Plinth", -2.8, 0, -2.8, 2.8, 2, 2.8, trim, ds)
		Bx(m, O, "Shaft", -2.5, 2, -2.5, 2.5, 24, 2.5, stone, ds)
		for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			Bx(m, O, "Buttress_" .. i, c[1] * 2.5 - 0.35, 2, c[2] * 2.5 - 0.35, c[1] * 2.5 + 0.35, 24, c[2] * 2.5 + 0.35, trim, ds)
		end
		Bx(m, O, "ClockStage", -2.9, 24, -2.9, 2.9, 29, 2.9, stone, ds)
		Bx(m, O, "Cornice", -3.2, 29, -3.2, 3.2, 29.5, 3.2, trim, d)
		Bx(m, O, "Belfry", -2.5, 29.5, -2.5, 2.5, 32, 2.5, stone, ds)
		for i, t in { { 2.3, 32, 33.2 }, { 1.8, 33.2, 34.6 }, { 1.3, 34.6, 36.2 }, { 0.8, 36.2, 38 }, { 0.4, 38, 39.6 } } do
			Bx(m, O, "Spire_" .. i, -t[1], t[2], -t[1], t[1], t[3], t[1], slate, ds)
		end
		Bx(m, O, "Finial", -0.15, 39.6, -0.15, 0.15, 41.1, 0.15, gold, d)
		P(m, "FinialBall", CFrame.new(0, 41.3, 0), Vector3.new(0.6, 0.6, 0.6), gold, { shape = Ball, decor = true })
		local up = Vector3.yAxis
		for _, dd in { { "N", 0, -1 }, { "S", 0, 1 }, { "W", -1, 0 }, { "E", 1, 0 } } do
			local nx, nz = dd[2], dd[3]
			local function onFace(nm, t0, y0, t1, y1, d0, d1, color, opt)
				if nx == 0 then return Bx(m, O, nm, t0, y0, nz * d0, t1, y1, nz * d1, color, opt) end
				return Bx(m, O, nm, nx * d0, y0, t0, nx * d1, y1, t1, color, opt)
			end
			onFace("Slit_" .. dd[1], -0.35, 15, 0.35, 19.5, 2.45, 2.56, dark, d)
			if dd[1] ~= "N" then onFace("Slit2_" .. dd[1], -0.35, 8, 0.35, 11.5, 2.45, 2.56, dark, d) end
			onFace("Arch_" .. dd[1], -0.8, 30.0, 0.8, 31.6, 2.45, 2.56, dark, d)
			local nrm = Vector3.new(nx, 0, nz)
			local right = (-nrm):Cross(up)
			local c = Vector3.new(0, 26.5, 0)
			P(m, "ClockRim_" .. dd[1], CFrame.fromMatrix(c + nrm * 2.93, nrm, up), Vector3.new(0.15, 4.4, 4.4), gold, { shape = Cyl, decor = true })
			P(m, "ClockFace_" .. dd[1], CFrame.fromMatrix(c + nrm * 2.95, nrm, up), Vector3.new(0.2, 4.0, 4.0), rgb(250, 248, 240), { shape = Cyl, decor = true })
			P(m, "MinuteHand_" .. dd[1], CFrame.fromMatrix(c + nrm * 3.1 + up * 0.8, nrm, up), Vector3.new(0.06, 1.6, 0.14), iron, d)
			P(m, "HourHand_" .. dd[1], CFrame.fromMatrix(c + nrm * 3.1 + right * 0.55, nrm, up), Vector3.new(0.06, 0.2, 1.1), iron, d)
			P(m, "ClockPin_" .. dd[1], CFrame.new(c + nrm * 3.12), Vector3.new(0.35, 0.35, 0.35), gold, { shape = Ball, decor = true })
		end
		Bx(m, O, "StreetSignRim", -1.85, 7.9, -2.6, 1.85, 9.3, -2.5, iron, d)
		streetSign(Bx(m, O, "StreetSign", -1.75, 8.0, -2.66, 1.75, 9.2, -2.6, rgb(250, 250, 248), d))
		return settle(m, target)
	end
	clockTower("ClockTower_N", CFrame.new(105.3, 0, 34.1))
	clockTower("ClockTower_S", CFrame.new(105.3, 0, -34.1) * CFrame.Angles(0, math.pi, 0))
	flush(T)
end

-- 3e) Bus rouge à impériale garé derrière le muret nord (dépôt x 170..180,5), l'avant tourné vers la rue (sans collision)
do
	local Bm = group("DoubleDecker")
	local f = CFrame.new(175.4, 0, 34.6)          -- avant du bus en bas au centre ; +z local vers l'arrière
	local busRed, cream, glassB, black, chrome = rgb(196, 18, 30), rgb(236, 226, 196), rgb(40, 50, 66), rgb(24, 24, 28), rgb(190, 194, 200)
	local d = { decor = true }
	local L = 36
	Bx(Bm, f, "LowerBody", -4.8, 1.6, 0.4, 4.8, 10.2, L, busRed, { decor = true, refl = 0.05 })
	Bx(Bm, f, "DeckBand", -4.85, 10.2, 0.6, 4.85, 11.0, L - 0.2, cream, d)
	Bx(Bm, f, "UpperBody", -4.8, 11.0, 0.8, 4.8, 19.4, L - 0.2, busRed, { decor = true, refl = 0.05 })
	Bx(Bm, f, "RoofLow", -4.5, 19.4, 1.2, 4.5, 20.2, L - 0.6, busRed, d)
	Bx(Bm, f, "RoofTop", -3.6, 20.2, 2.0, 3.6, 20.7, L - 1.4, busRed, d)
	Bx(Bm, f, "Skirt", -4.7, 0.9, 0.6, 4.7, 1.6, L - 0.2, black, d)
	Bx(Bm, f, "Windscreen", -4.2, 5.4, 0.3, 4.2, 9.4, 0.4, glassB, { decor = true, mat = Glass })
	Bx(Bm, f, "UpperFront_L", -4.3, 12.4, 0.7, -0.3, 17.8, 0.8, glassB, { decor = true, mat = Glass })
	Bx(Bm, f, "UpperFront_R", 0.3, 12.4, 0.7, 4.3, 17.8, 0.8, glassB, { decor = true, mat = Glass })
	local blind = Bx(Bm, f, "Destination", -3.2, 10.25, 0.45, 3.2, 11.9, 0.55, black, d)
	label(blind, Enum.NormalId.Front, "LONDON", rgb(255, 210, 60), 30, false)
	Bx(Bm, f, "Grille", -1.6, 2.0, 0.3, 1.6, 4.6, 0.4, chrome, d)
	Bx(Bm, f, "Bumper", -4.9, 1.2, 0.0, 4.9, 2.0, 0.6, black, d)
	for i, x in { -3.4, 3.4 } do
		P(Bm, "Headlight_" .. i, f * CFrame.new(x, 3.4, 0.33) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.2, 1.3, 1.3), rgb(255, 250, 220), { shape = Cyl, mat = Neon, decor = true, noShadow = true })
	end
	for _, sx in { -1, 1 } do
		local tag = (sx < 0) and "L" or "R"
		for k = 0, 4 do
			local z0 = 6 + k * 5.6
			Bx(Bm, f, "LowerGlass_" .. tag .. k, sx * 4.8, 5.8, z0, sx * 4.9, 9.4, z0 + 4.8, glassB, { decor = true, mat = Glass })
		end
		for k = 0, 5 do
			local z0 = 2 + k * 5.4
			Bx(Bm, f, "UpperGlass_" .. tag .. k, sx * 4.8, 12.6, z0, sx * 4.9, 17.6, z0 + 4.8, glassB, { decor = true, mat = Glass })
		end
		local ad = Bx(Bm, f, "Advert_" .. tag, sx * 4.8, 11.1, 8, sx * 4.88, 12.4, 28, whiteL, d)
		label(ad, (sx < 0) and Enum.NormalId.Left or Enum.NormalId.Right, "SEE LONDON", busRed, 30, false)
		for j, zw in { 6.2, 28.5 } do
			P(Bm, "Wheel_" .. tag .. j, f * CFrame.new(sx * 4.45, 1.9, zw), Vector3.new(0.9, 3.8, 3.8), black, { shape = Cyl, decor = true })
			P(Bm, "HubCap_" .. tag .. j, f * CFrame.new(sx * 4.93, 1.9, zw), Vector3.new(0.1, 1.8, 1.8), chrome, { shape = Cyl, decor = true, noShadow = true })
		end
	end
	flush(Bm)
end

-- 3f) Grande roue derrière la confiserie, sur le quai de la Tamise : le repère qu'on voit de loin (94 studs, sans collision)
do
	local M = group("ObservationWheel")
	local C = Vector3.new(145, 50, -124)
	local R, R2 = 40, 36.5
	local whiteW, steel, glassC = rgb(240, 242, 246), rgb(196, 202, 210), rgb(196, 226, 244)
	local function ring(prefix, r, thick, depth, color, opt)
		for i = 0, 35 do
			local a0, a1 = i * math.pi / 18, (i + 1) * math.pi / 18
			local p0 = C + Vector3.new(math.cos(a0) * r, math.sin(a0) * r, 0)
			local p1 = C + Vector3.new(math.cos(a1) * r, math.sin(a1) * r, 0)
			P(M, prefix .. "_" .. i, CFrame.new((p0 + p1) / 2) * CFrame.Angles(0, 0, math.atan2(p1.Y - p0.Y, p1.X - p0.X)), Vector3.new((p1 - p0).Magnitude + thick * 0.6, thick, depth), color, opt)
		end
	end
	ring("Rim", R, 1.2, 1.6, whiteW, { decor = true })
	ring("LightRing", R2, 0.45, 0.45, rgb(150, 205, 255), { decor = true, mat = Neon, noShadow = true })
	for i = 0, 17 do
		local a = i * math.pi / 9
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		bar(M, "Brace_" .. i, C + dir * R2, C + dir * R, 0.4, whiteW, { decor = true, noShadow = true })
	end
	for i = 0, 23 do
		local a = (i + 0.5) * math.pi / 12
		bar(M, "Spoke_" .. i, C + Vector3.new(0, 0, (i % 2 == 0) and 3.4 or -3.4), C + Vector3.new(math.cos(a) * R2, math.sin(a) * R2, 0), 0.22, steel, { decor = true, noShadow = true })
	end
	P(M, "Hub", CFrame.new(C) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(7.4, 4.4, 4.4), whiteW, { shape = Cyl, decor = true })
	P(M, "HubRing", CFrame.new(C) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(2, 5.6, 5.6), steel, { shape = Cyl, decor = true })
	for i = 0, 31 do
		local a = i * math.pi / 16
		local pos = C + Vector3.new(math.cos(a), math.sin(a), 0) * (R + 2.3)
		P(M, "Capsule_" .. i, CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(5.6, 3.2, 3.2), glassC, { shape = Cyl, mat = Glass, T = 0.2, decor = true })
		P(M, "CapsuleBand_" .. i, CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(1.0, 3.35, 3.35), whiteW, { shape = Cyl, decor = true, noShadow = true })
	end
	-- chevalet en A côté rue jusqu'au bout avant de l'axe, haubans à l'arrière, quai d'embarquement sous la roue
	local axleFront = C + Vector3.new(0, 0, 4.2)
	local feet = { Vector3.new(124, 0, -106), Vector3.new(166, 0, -106) }
	for k, ft in feet do
		bar(M, "Leg_" .. k, ft, axleFront, 2.2, whiteW, { decor = true })
		Bx(M, W, "LegFoot_" .. k, ft.X - 2, 0, ft.Z - 2, ft.X + 2, 1.2, ft.Z + 2, rgb(176, 170, 156), { studs = true, decor = true })
	end
	bar(M, "LegTie", feet[1]:Lerp(axleFront, 0.45), feet[2]:Lerp(axleFront, 0.45), 1.0, whiteW, { decor = true })
	for k, sx in { -1, 1 } do
		bar(M, "Stay_" .. k, Vector3.new(145 + sx * 12, 0.5, -129), C + Vector3.new(0, 0, -3.8), 0.3, steel, { decor = true, noShadow = true })
	end
	Bx(M, W, "BoardingDeck", 136, 0, -129.2, 154, 3.4, -118.5, rgb(200, 204, 210), { studs = true, decor = true })
	Bx(M, W, "BoardingRoof", 137, 4.9, -128.5, 153, 5.3, -119.5, whiteW, { decor = true })
	flush(M)
end

-- 3g) Immeubles derrière et à côté des magasins (taille finale, sans collision) : rangée d'immeubles victoriens derrière
--     les jouets (ils dépassent des toits), maisons de ville serrées le long des magasins, arbres du quai et du square.
do
	local Bk = group("Buildings")
	local stoneW, slate, glassD = rgb(238, 232, 218), rgb(70, 76, 88), rgb(46, 58, 80)
	local function block(name, x0, x1, z0, z1, h, body, windows)
		local m = Instance.new("Model"); m.Name = name; m.Parent = Bk
		local roofTop = h + 3.5
		Bx(m, W, "Body", x0, 0, z0, x1, h, z1, body, { studs = true, decor = true })
		Bx(m, W, "Cornice", x0 - 0.4, h, z0 - 0.4, x1 + 0.4, h + 0.9, z1 + 0.4, stoneW, { decor = true })
		Bx(m, W, "Roof", x0 + 0.6, h + 0.9, z0 + 0.6, x1 - 0.6, roofTop, z1 - 0.6, slate, { studs = true, decor = true })
		local nCh = math.max(1, math.floor((x1 - x0) / 8))
		for k = 1, nCh do
			local cx, cz = x0 + (x1 - x0) * (k - 0.5) / nCh, (z0 + z1) / 2
			Bx(m, W, "Chimney_" .. k, cx - 1.4, h + 0.9, cz - 0.9, cx + 1.4, roofTop + 3.2, cz + 0.9, rgb(150, 62, 48), { studs = true, decor = true })
			for j, dx in { -0.7, 0.7 } do
				P(m, "ChimneyPot_" .. k .. "_" .. j, CFrame.new(cx + dx, roofTop + 3.75, cz) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.1, 0.75, 0.75), rgb(190, 95, 60), { shape = Cyl, decor = true, noShadow = true })
			end
		end
		if windows then   -- façade côté rue (face z0) : rez-de-chaussée en pierre, fenêtres et bandeaux à chaque étage
			Bx(m, W, "GroundBand", x0, 0, z0 - 0.15, x1, 7, z0, stoneW, { decor = true })
			local cols = math.max(1, math.floor((x1 - x0 - 1) / 4.4))
			local y, fl = 8, 0
			while y + 4 <= h - 1 do
				fl += 1
				for c = 1, cols do
					local cx = x0 + (x1 - x0) * (c - 0.5) / cols
					Bx(m, W, "Win_" .. fl .. "_" .. c, cx - 1.1, y, z0 - 0.12, cx + 1.1, y + 3.8, z0, glassD, { decor = true, noShadow = true })
				end
				Bx(m, W, "Band_" .. fl, x0, y - 0.9, z0 - 0.1, x1, y - 0.5, z0, stoneW, { decor = true, noShadow = true })
				y += 6.5
			end
		end
		return m
	end
	-- derrière le magasin de jouets : immeubles de 44 à 52 studs, façade tournée vers la rue
	block("Mansion_1", 101, 123, 106, 124, 46, rgb(165, 72, 55), true)
	block("Mansion_2", 123, 145, 106, 124, 52, rgb(196, 170, 120), true)
	block("Mansion_3", 145, 167, 106, 124, 48, rgb(140, 58, 46), true)
	block("Mansion_4", 167, 189, 106, 124, 44, rgb(226, 218, 196), true)
	-- le long des magasins, derrière les tours, le bus et les maisons plaquées
	local terraces = {
		{ "Terrace_NW1", 100.5, 109.5, 40, 60, 28, rgb(176, 70, 52) }, { "Terrace_NW2", 100.5, 109.5, 61, 81, 25, rgb(236, 228, 210) },
		{ "Terrace_NW3", 100.5, 109.5, 82, 101, 30, rgb(140, 58, 46) },
		{ "Terrace_SW1", 100.5, 109.5, -60, -40, 27, rgb(242, 222, 150) }, { "Terrace_SW2", 100.5, 109.5, -81, -61, 30, rgb(160, 66, 50) },
		{ "Terrace_SW3", 100.5, 109.5, -101, -82, 26, rgb(170, 220, 195) },
		{ "Terrace_NE1", 180.8, 189.5, 45, 72, 28, rgb(176, 70, 52) }, { "Terrace_NE2", 171, 189.5, 74, 87, 30, rgb(236, 228, 210) },
		{ "Terrace_NE3", 171, 189.5, 88, 101, 26, rgb(140, 58, 46) },
		{ "Terrace_SE1", 170.5, 189.5, -66, -45, 30, rgb(160, 66, 50) }, { "Terrace_SE2", 170.5, 189.5, -84, -67, 27, rgb(240, 236, 226) },
		{ "Terrace_SE3", 170.5, 189.5, -101, -85, 32, rgb(176, 70, 52) },
	}
	for _, t in terraces do block(t[1], t[2], t[3], t[4], t[5], t[6], t[7], false) end
	local function tree(name, x, z, hgt)
		local m = Instance.new("Model"); m.Name = name; m.Parent = Bk
		vcyl(m, "Trunk", x, 0, hgt * 0.62, z, 1.3, rgb(118, 104, 88), { decor = true })
		P(m, "Crown_1", CFrame.new(x, hgt * 0.7, z), Vector3.one * (hgt * 0.55), rgb(70, 120, 58), { shape = Ball, decor = true })
		P(m, "Crown_2", CFrame.new(x + hgt * 0.16, hgt * 0.82, z - hgt * 0.1), Vector3.one * (hgt * 0.42), rgb(84, 136, 66), { shape = Ball, decor = true })
		P(m, "Crown_3", CFrame.new(x - hgt * 0.15, hgt * 0.8, z + hgt * 0.12), Vector3.one * (hgt * 0.4), rgb(62, 110, 52), { shape = Ball, decor = true })
	end
	for i, x in { 106, 116, 174, 184 } do tree("Tree_S" .. i, x, -113, 16) end
	for i, x in { 110, 128, 146, 164, 180 } do tree("Tree_N" .. i, x, 132, 18) end
	flush(Bk)
end

-- 3h) Météo de Londres : bruine fine sur la chaussée et brume au ras des pavés, ParticleEmitter seuls (aucun script).
--     Les émetteurs de brume sont enfouis sous la chaussée : rien ne dépasse du sol ; la bruine tombe de y = 46.
do
	local Wx = group("Weather")
	local function emitterPart(name, x0, y0, z0, x1, y1, z1)
		local p = Bx(Wx, W, name, x0, y0, z0, x1, y1, z1, whiteL, { decor = true, T = 1, noShadow = true })
		p.CanQuery = false
		return p
	end
	local rain = Instance.new("ParticleEmitter"); rain.Name = "Drizzle"
	rain.Texture = "rbxasset://textures/particles/smoke_main.dds"
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Rate = 220
	rain.Lifetime = NumberRange.new(0.9, 0.95)
	rain.Speed = NumberRange.new(48, 52)
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.Acceleration = Vector3.new(1.5, 0, 0)
	rain.Size = NumberSequence.new(0.32)
	rain.Squash = NumberSequence.new(2.6)
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.45), NumberSequenceKeypoint.new(1, 0.55) })
	rain.Color = ColorSequence.new(rgb(206, 216, 230))
	rain.LightEmission = 0.15
	rain.LightInfluence = 0.7
	rain.Parent = emitterPart("DrizzleCloud", 102, 45.5, -24, 189, 46.5, 24)
	local mist = Instance.new("ParticleEmitter"); mist.Name = "Mist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Rate = 5
	mist.Lifetime = NumberRange.new(10, 14)
	mist.Speed = NumberRange.new(0.3, 0.8)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Acceleration = Vector3.new(0.12, -0.02, 0)
	mist.Drag = 0.4
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 20) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.87), NumberSequenceKeypoint.new(0.75, 0.88), NumberSequenceKeypoint.new(1, 1) })
	mist.Color = ColorSequence.new(rgb(212, 218, 228))
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-6, 6)
	mist.LightEmission = 0
	mist.LightInfluence = 1
	mist.Parent = emitterPart("MistBank", 102, -1.2, -27, 189, -0.2, 27)
	local gateMist = mist:Clone(); gateMist.Name = "GateMist"; gateMist.Rate = 3
	gateMist.Parent = emitterPart("GateMistBank", 101, -1.2, -20, 112, -0.2, 20)
	flush(Wx)
end

-- 4) Vérification (mode Edit) : contrat, chaussée, emprise, chevauchements solides, chemins du vigile ---------------------
local report = { string.format("Zone 2 Londres : jouets %d produits, confiserie %d produits", toyN, candyN), gateInfo }
local function add(s) table.insert(report, s) end
local CS = game:GetService("CollectionService")
local function aabb(p)
	local cf, s = p.CFrame, p.Size
	local e = cf:VectorToWorldSpace(Vector3.new(s.X, 0, 0)):Abs() + cf:VectorToWorldSpace(Vector3.new(0, s.Y, 0)):Abs() + cf:VectorToWorldSpace(Vector3.new(0, 0, s.Z)):Abs()
	return cf.Position - e / 2, cf.Position + e / 2
end
do
	local CONTRACT = { "Window", "WindowFractured", "Shutter", "Door", "Bounds", "GuardSpawn", "SignPart" }
	for i = 1, 10 do table.insert(CONTRACT, string.format("ShelfSlot_%02d", i)) end
	for _, m in { toy, candy } do
		local counts, nParts, bad = {}, 0, {}
		for _, d in m:GetDescendants() do
			counts[d.Name] = (counts[d.Name] or 0) + 1
			if d:IsA("BasePart") then nParts += 1 end
		end
		for _, nm in CONTRACT do if counts[nm] ~= 1 then table.insert(bad, nm .. "×" .. tostring(counts[nm] or 0)) end end
		local shards = 0
		local wf = m:FindFirstChild("WindowFractured")
		if wf then for _, d in wf:GetDescendants() do if d:IsA("BasePart") then shards += 1 end end end
		local tiers = { Standard = 0, Premium = 0, Luxe = 0 }
		for i = 1, 10 do
			local a = m:FindFirstChild(string.format("ShelfSlot_%02d", i), true)
			local t = a and a:GetAttribute("Tier")
			if t and tiers[t] then tiers[t] += 1 end
		end
		add(string.format("%s : contrat %s, %d éclats, NPCStore %s, Zone %s, Tier %d/%d/%d, échelle %.2f, %d pièces",
			m.Name, (#bad == 0) and "OK" or table.concat(bad, " "), shards, tostring(CS:HasTag(m, "NPCStore")),
			tostring(m:GetAttribute("Zone")), tiers.Standard, tiers.Premium, tiers.Luxe, m:GetScale(), nParts))
	end
end
do
	local onRoad, outside, nScripts, nDecor = {}, {}, 0, 0
	for _, d in Z:GetDescendants() do
		if d:IsA("LuaSourceContainer") then nScripts += 1 end
		if d:IsA("BasePart") then
			local lo, hi = aabb(d)
			if lo.X < 99.99 or hi.X > 190.01 or lo.Z < -140.01 or hi.Z > 140.01 then table.insert(outside, d:GetFullName()) end
			if hi.X > 100 and lo.X < 190 and hi.Z > -ROAD + 0.01 and lo.Z < ROAD - 0.01 and hi.Y > 0.05 and d.Name ~= "DrizzleCloud" then
				table.insert(onRoad, d.Name)
			end
			if d:IsDescendantOf(S) then nDecor += 1 end
		end
	end
	add(string.format("Street_Londres : %d pièces ; scripts dans Map/Zone_2 : %d ; hors emprise : %d%s ; sur la chaussée : %d%s",
		nDecor, nScripts, #outside, (#outside > 0) and (" (" .. table.concat(outside, ", ", 1, math.min(#outside, 5)) .. ")") or "",
		#onRoad, (#onRoad > 0) and (" (" .. table.concat(onRoad, ", ", 1, math.min(#onRoad, 8)) .. ")") or ""))
end
do
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ground = { Street = true, Side_N = true, Side_S = true, GardenSquare = true, Embankment = true }
	local clashes, nSolid = {}, 0
	local G = S:FindFirstChild("Ground")
	for _, p in S:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide and not p:IsDescendantOf(G) then
			nSolid += 1
			local root = p
			while root.Parent and root.Parent.Parent ~= S do root = root.Parent end
			params.FilterDescendantsInstances = { root }
			for _, q in workspace:GetPartsInPart(p, params) do
				local nm = q.Name
				if q.CanCollide and not ground[nm] and not nm:match("^Pavement_") and not nm:match("^Kerb_") and not nm:match("^BackGround_") then
					clashes[root.Name .. "/" .. p.Name .. " ~ " .. q.Parent.Name .. "/" .. nm] = true
				end
			end
		end
	end
	local list = {}
	for k in clashes do table.insert(list, k) end
	table.sort(list)
	add(string.format("Décor solide : %d pièces, %d chevauchement(s)%s", nSolid, #list, (#list > 0) and (" : " .. table.concat(list, " | ", 1, math.min(#list, 8))) or ""))
end
do
	local PFS = game:GetService("PathfindingService")
	local AGENT = { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 }
	local function route(a, b)
		local path = PFS:CreatePath(AGENT)
		local ok = pcall(function() path:ComputeAsync(a, b) end)
		if not ok or path.Status ~= Enum.PathStatus.Success then return nil end
		local wps = path:GetWaypoints()
		local len, jumps = 0, 0
		for i = 2, #wps do
			len += (wps[i].Position - wps[i - 1].Position).Magnitude
			if wps[i].Action == Enum.PathWaypointAction.Jump then jumps += 1 end
		end
		return len, jumps, wps
	end
	for _, m in { toy, candy } do
		local pv = m.WorldPivot
		local gs = m:FindFirstChild("GuardSpawn", true)
		local floorY = gs.WorldPosition.Y
		local from = gs.WorldPosition + Vector3.new(0, 1, 0)
		local okN, jumpsN, fails = 0, 0, {}
		for i = 1, 10 do
			local a = m:FindFirstChild(string.format("ShelfSlot_%02d", i), true)
			local g = a.WorldPosition + a.WorldCFrame.LookVector * (2.5 * K)
			local len, jumps = route(from, Vector3.new(g.X, floorY + 1, g.Z))
			if len then okN += 1; jumpsN += jumps else table.insert(fails, i) end
		end
		local sill = route(from, pv:PointToWorldSpace(Vector3.new(13.5 * K, 1, 17.5 * K)))
		local win = m:FindFirstChild("Window")
		local was = win.CanCollide
		local street = pv:PointToWorldSpace(Vector3.new(0, 1, -24 * K - 12))
		win.CanCollide = false
		local lenOpen, jumpsOpen, wps = route(from, street)
		win.CanCollide = was
		local lenShut = route(from, street)
		local exitX = "?"
		if wps then
			for _, w in wps do
				local lp = pv:PointToObjectSpace(w.Position)
				if lp.Z < -24 * K then exitX = string.format("%.1f", lp.X); break end
			end
		end
		add(string.format("%s : vigile %d/10 rayons, %d saut(s)%s ; seuil de réserve %s ; rue vitre cassée %s ; vitre fermée %s",
			m.Name, okN, jumpsN, (#fails > 0) and (" (échecs " .. table.concat(fails, ",") .. ")") or "",
			sill and "OK" or "NoPath",
			lenOpen and string.format("OK, %.0f studs, %d saut(s), sortie x local %s", lenOpen, jumpsOpen, exitX) or "NoPath",
			lenShut and string.format("chemin de %.0f studs (!)", lenShut) or "NoPath"))
	end
end
return table.concat(report, "\n")
