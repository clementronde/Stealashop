--!nocheck
-- Zone 1 — quartier de la Supérette (MOD-028, partie zone 1) : la zone tuto, la première que voient les joueurs.
-- Petit centre-ville moderne et coloré aux couleurs des deux magasins : rouge et crème au nord (Supérette),
-- bleu et menthe au sud (Kiosque). Trottoirs clairs, passage piéton entre les deux vitrines, arbres, bancs,
-- réverbères, arrêt de bus, panneaux, petites boutiques plaquées sur les murets, immeubles et château d'eau derrière.
-- À lancer dans Studio (MCP execute_luau, mode Edit). Pas besoin de store_builder.luau : les deux magasins, validés
-- par Clément, ne sont pas reconstruits. Le script leur ajoute seulement de l'extérieur : UpperFloors (volume derrière
-- la fausse façade) et BladeSign (enseigne verticale qui reprend le texte de leur SignPart). Il passe aussi leurs textes
-- en anglais (L-036 : enseignes MINI MART et KIOSK, bandeaux de rayon, SALE, STOCKROOM), sans rien toucher d'autre.
-- Il ne touche ni à la géométrie de l'intérieur, ni aux noms du contrat 10.4, ni aux arches ZoneGate, ni aux NightPatrol.
-- Relancer ce script reconstruit le décor à l'identique : les modèles du même nom sont remplacés.
-- Règles : aucun script laissé dans la map ; noms du contrat et tags jamais réutilisés pour le décor ; textes visibles
-- en jeu en anglais (L-036) ; chaussée z -15..15 libre ; façades sans collision (le muret reste le vrai mur).
-- La fin du script vérifie la zone en mode Edit et renvoie le compte rendu : chaussée, emprise, chevauchements,
-- chemins du vigile (réglages de GuardService, vitre sans collision le temps du test).

local rgb = Color3.fromRGB
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local NEON, GLASS, SMOOTH = Enum.Material.Neon, Enum.Material.Glass, Enum.Material.SmoothPlastic
local FRONT, BACK, LEFT, RIGHT = Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right
local MONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local FRED = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)

-- Couleurs des deux magasins (relevées sur les modèles validés) et du quartier
local RED, RED_D, CREAM = rgb(232, 65, 60), rgb(185, 47, 42), rgb(242, 217, 166)
local BLUE, BLUE_D, MINT = rgb(46, 134, 222), rgb(27, 79, 140), rgb(190, 232, 210)
local YELLOW, GOLDY = rgb(255, 194, 26), rgb(255, 230, 0)
local DARK, STEEL, WHITE = rgb(58, 64, 75), rgb(167, 176, 188), rgb(250, 250, 248)
local LEAF, LEAF_L, TRUNK = rgb(63, 191, 58), rgb(120, 214, 84), rgb(124, 92, 62)
local WOOD, BROWN, GREEN, COFFEE = rgb(196, 146, 96), rgb(124, 82, 52), rgb(52, 140, 64), rgb(98, 62, 44)
local PINK, PINK_D = rgb(255, 150, 190), rgb(255, 120, 170)
local GLASS_C, GLASS_D, LIT, WARM = rgb(191, 230, 255), rgb(52, 66, 92), rgb(255, 226, 150), rgb(255, 236, 200)
local ROOF = rgb(154, 163, 174)

local W = CFrame.identity
local ROT_UP = CFrame.Angles(0, 0, math.rad(90))

-- Pièces -----------------------------------------------------------------------------------------------
-- opt : shape, mat, studs (Plastic + MaterialVariant « Studs »), decor (ni collision, ni toucher, ni requête),
-- T (transparence), noShadow.
local function P(parent, name, cf, size, color, opt)
	opt = opt or {}
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if opt.shape then p.Shape = opt.shape end
	if opt.mat then p.Material = opt.mat
	elseif opt.studs then p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
	else p.Material = SMOOTH end
	if opt.decor then p.CanCollide = false; p.CanTouch = false; p.CanQuery = false end
	if opt.T then p.Transparency = opt.T end
	if opt.noShadow then p.CastShadow = false end
	p.Parent = parent
	return p
end
local function with(opt, k, v) local o = opt and table.clone(opt) or {}; o[k] = v; return o end
-- Pavé donné par deux coins, dans le repère `frame`
local function Bx(parent, frame, name, x0, y0, z0, x1, y1, z1, color, opt)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	return P(parent, name, frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), size, color, opt)
end
-- Cylindre debout (axe vertical) dans le repère `frame`
local function Vc(parent, frame, name, x, y0, y1, z, dia, color, opt)
	return P(parent, name, frame * CFrame.new(x, (y0 + y1) / 2, z) * ROT_UP, Vector3.new(y1 - y0, dia, dia), color, with(opt, "shape", CYL))
end
local function Ball(parent, frame, name, x, y, z, dia, color, opt)
	return P(parent, name, frame * CFrame.new(x, y, z), Vector3.new(dia, dia, dia), color, with(opt, "shape", BALL))
end

-- Textes (SurfaceGui, sans script) -------------------------------------------------------------------
local function surface(part, face, ppS)
	local g = Instance.new("SurfaceGui"); g.Name = "Gui_" .. face.Name; g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppS or 50; g.LightInfluence = 0
	g.Parent = part
	return g
end
local function txt(parent, text, color, x, y, w, h, opt)
	opt = opt or {}
	local t = Instance.new("TextLabel"); t.Name = opt.name or "Label"; t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(x, y); t.Size = UDim2.fromScale(w, h)
	t.Text = text; t.TextScaled = true; t.TextColor3 = color; t.FontFace = opt.font or MONT
	if opt.alignX then t.TextXAlignment = opt.alignX end
	if opt.lineHeight then t.LineHeight = opt.lineHeight end
	if opt.stroke ~= false then
		local s = Instance.new("UIStroke"); s.Color = opt.stroke or rgb(20, 22, 28); s.Thickness = opt.strokeT or 3
		s.LineJoinMode = Enum.LineJoinMode.Round; s.Parent = t
	end
	local pad = Instance.new("UIPadding"); local pv, ph = opt.pad or 0.12, opt.padX or 0.03
	pad.PaddingTop = UDim.new(pv, 0); pad.PaddingBottom = UDim.new(pv, 0)
	pad.PaddingLeft = UDim.new(ph, 0); pad.PaddingRight = UDim.new(ph, 0); pad.Parent = t
	t.Parent = parent
	return t
end
local function label(part, face, text, color, opt)
	opt = opt or {}
	return txt(surface(part, face, opt.ppS), text, color, 0, 0, 1, 1, opt)
end
local function shape2d(parent, color, x, y, w, h, opt)
	local f = Instance.new("Frame"); f.Name = (opt and opt.name) or "Shape"; f.BorderSizePixel = 0
	f.BackgroundColor3 = color; f.Position = UDim2.fromScale(x, y); f.Size = UDim2.fromScale(w, h)
	if opt and opt.round then local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(opt.round, 0); c.Parent = f end
	f.Parent = parent
	return f
end

-- Texte de l'enseigne d'un magasin (pour l'enseigne verticale et le plan : même nom que la façade)
local function storeName(store)
	local sp = store:FindFirstChild("SignPart")
	local t = sp and sp:FindFirstChildWhichIsA("TextLabel", true)
	return (t and t.Text ~= "") and t.Text or store.Name
end

-- 1) Greybox : la rue de la zone 1 passe en asphalte à studs (à garder si le greybox est régénéré) --------
local gz1 = workspace.Greybox.Corridor.Zone_1
do
	local st = gz1.Ground.Street
	st.Color = rgb(70, 73, 82); st.Material = Enum.Material.Plastic; st.MaterialVariant = "Studs"
end

-- 2) Dossier du décor --------------------------------------------------------------------------------------
local zoneFolder = workspace.Map.Zone_1
local superette = zoneFolder.STORE_Z1_Superette
local kiosque = zoneFolder.STORE_Z1_Kiosque
-- Textes des deux magasins en anglais (L-036, consigne de Clément du 2026-11-07) : seulement le texte des SurfaceGui
-- (enseigne, bandeaux de rayon, panneaux SALE et STOCKROOM), jamais les noms des modèles ni ceux du contrat.
local STORE_TEXT_EN = {
	["SUPÉRETTE"] = "MINI MART", ["KIOSQUE"] = "KIOSK",
	["PÂTES ET RIZ"] = "PASTA & RICE", ["CONSERVES"] = "CANNED FOOD", ["PETIT-DÉJEUNER"] = "BREAKFAST",
	["BOISSONS"] = "DRINKS", ["HYGIÈNE"] = "PERSONAL CARE", ["FRAIS"] = "CHILLED",
	["PROMO"] = "SALE", ["RÉSERVE"] = "STOCKROOM",
}
local translated = 0
for _, st in { superette, kiosque } do
	for _, d in st:GetDescendants() do
		if d:IsA("TextLabel") and d:FindFirstAncestorWhichIsA("SurfaceGui") then
			local en = STORE_TEXT_EN[d.Text]
			if en then d.Text = en; translated += 1 end
		end
	end
end
local NAME_N, NAME_S = storeName(superette), storeName(kiosque)
do local old = zoneFolder:FindFirstChild("Street_Zone1"); if old then old:Destroy() end end
local S = Instance.new("Folder"); S.Name = "Street_Zone1"; S.Parent = zoneFolder
local function group(name) local m = Instance.new("Model"); m.Name = name; return m end
local function flush(m) m.Parent = S; task.wait() end
local function sub(parent, name) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end

-- 3) Sol : bordures, trottoirs en dalles claires (0,3 de haut, au niveau du sol des magasins), marquages --------
--    Chaussée z -15..15 : seuls des marquages plats (0,03), sans collision. Les repères NightPatrol (x 46..49 et
--    81..84, au milieu) et le passage piéton gardent leur place : la ligne centrale s'interrompt devant eux.
local G = group("Ground")
do
	local KERB_C, TILE_A, TILE_B = rgb(246, 246, 242), rgb(234, 228, 214), rgb(218, 220, 224)
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		local segs = (s > 0) and { { 30, 100, KERB_C } } or { { 30, 87, KERB_C }, { 87, 98, rgb(255, 204, 40) }, { 98, 100, KERB_C } }
		for i, sg in segs do
			Bx(G, W, "Kerb_" .. tag .. i, sg[1], 0, s * 15, sg[2], 0.3, s * 15.5, sg[3], { studs = true })
		end
		for i = 0, 13 do
			local x0 = 30 + i * 5
			Bx(G, W, "Pavement_" .. tag .. (i + 1), x0, 0, s * 15.5, x0 + 5, 0.3, s * 20, (i % 2 == 0) and TILE_A or TILE_B, { studs = true })
		end
	end
	local function paint(name, x0, z0, x1, z1, color)
		return Bx(G, W, name, x0, 0, z0, x1, 0.03, z1, color, { decor = true, noShadow = true })
	end
	local n = 0
	for x0 = 31, 96, 5 do
		local x1 = x0 + 2.5
		local clash = (x1 > 45 and x0 < 50.5) or (x1 > 55.5 and x0 < 64.5) or (x1 > 80 and x0 < 85.5)
		if not clash then n += 1; paint("CenterDash_" .. n, x0, -0.15, x1, 0.15, rgb(245, 245, 240)) end
	end
	-- Passage piéton entre les deux vitrines (x 57..63)
	for i = 0, 11 do
		local z0 = -13.8 + i * 2.4
		paint("Zebra_" .. (i + 1), 57, z0, 63, z0 + 1.2, WHITE)
	end
	-- Zigzag jaune de l'arrêt de bus (côté sud)
	local xa0, xb0, nSeg = 87.5, 97.5, 8
	local dx = (xb0 - xa0) / nSeg
	for k = 0, nSeg - 1 do
		local xa, xb = xa0 + k * dx, xa0 + (k + 1) * dx
		local za = -14.35 + ((k % 2 == 0) and 0.35 or -0.35)
		local zb = -14.35 + ((k % 2 == 0) and -0.35 or 0.35)
		local len = math.sqrt((xb - xa) ^ 2 + (zb - za) ^ 2)
		P(G, "BusZigZag_" .. (k + 1), CFrame.new((xa + xb) / 2, 0.015, (za + zb) / 2) * CFrame.Angles(0, math.atan2(-(zb - za), xb - xa), 0),
			Vector3.new(len + 0.12, 0.03, 0.15), rgb(255, 200, 0), { decor = true, noShadow = true })
	end
end
flush(G)

-- 4) Mobilier : réverbères, arbres, bancs, poubelles, bornes, arrêt de bus, terrasse, étal du fleuriste ------
--    Rien devant les vitrines (x 53..67) ni devant les portes : le vigile sort par la vitrine cassée.
local D = group("Props")
do
	local function lamp(name, x, z, accent)
		local m = sub(D, name)
		Bx(m, W, "Base", x - 0.4, 0.3, z - 0.4, x + 0.4, 0.9, z + 0.4, DARK)
		Vc(m, W, "Pole", x, 0.9, 10.2, z, 0.36, DARK)
		Vc(m, W, "Ring", x, 2.6, 3.0, z, 0.5, accent, { decor = true })
		local arm = Bx(m, W, "Arm", x - 1.35, 9.95, z - 0.11, x + 1.35, 10.2, z + 0.11, DARK, { decor = true })
		for i, dx in { -1.25, 1.25 } do
			Bx(m, W, "Head_" .. i, x + dx - 0.5, 9.75, z - 0.35, x + dx + 0.5, 10.05, z + 0.35, accent, { decor = true })
			Bx(m, W, "Glow_" .. i, x + dx - 0.4, 9.69, z - 0.28, x + dx + 0.4, 9.75, z + 0.28, rgb(255, 240, 210), { decor = true, mat = NEON, noShadow = true })
		end
		local pl = Instance.new("PointLight"); pl.Name = "LampLight"; pl.Range = 20; pl.Brightness = 1.1
		pl.Color = rgb(255, 224, 176); pl.Shadows = false; pl.Parent = arm
	end
	for i, x in { 37.6, 45.5, 68.6, 85.0, 97.6 } do lamp("Lamp_N" .. i, x, 16.0, RED) end
	for i, x in { 37.6, 51.4, 74.5, 83.0, 98.0 } do lamp("Lamp_S" .. i, x, -16.0, BLUE) end

	-- Arbres « style Roblox » sur grille, tronc avec collision, feuillage sans collision (au-dessus de 5 studs)
	local flowerCols = { rgb(255, 120, 170), rgb(255, 214, 60), RED, rgb(170, 110, 220), WHITE }
	local function tree(name, x, z, seed)
		local m = sub(D, name)
		local s = (z > 0) and 1 or -1
		Bx(m, W, "Grate", x - 0.9, 0.3, z - 0.9, x + 0.9, 0.34, z + 0.9, rgb(70, 74, 82), { decor = true, noShadow = true })
		Vc(m, W, "Trunk", x, 0.3, 5.6, z, 0.55, TRUNK)
		Ball(m, W, "Crown", x, 7.0, z, 3.6, LEAF, { decor = true })
		Ball(m, W, "CrownTop", x, 8.6, z - s * 0.15, 2.6, LEAF_L, { decor = true })
		for k, o in { { -0.55, 0.45 }, { 0.5, -0.5 } } do
			Ball(m, W, "Blossom_" .. k, x + o[1], 0.5, z + o[2], 0.45, flowerCols[(seed + k) % #flowerCols + 1], { decor = true, noShadow = true })
		end
	end
	tree("Tree_N1", 34.7, 17.2, 1); tree("Tree_N2", 51.2, 17.2, 2); tree("Tree_N3", 81.8, 17.2, 3)
	tree("Tree_S1", 68.8, -17.2, 4); tree("Tree_S2", 86.6, -17.2, 5)

	-- Bancs face à la rue, dos aux façades (s = 1 nord, -1 sud)
	local function parkBench(name, x0, x1, s)
		local m = sub(D, name)
		Bx(m, W, "Seat", x0, 1.45, s * 18.15, x1, 1.7, s * 19.15, WOOD)
		Bx(m, W, "Backrest", x0, 1.95, s * 19.15, x1, 2.95, s * 19.35, WOOD)
		for i, x in { x0 + 0.3, x1 - 0.3 } do
			Bx(m, W, "Leg_" .. i, x - 0.12, 0.3, s * 18.25, x + 0.12, 1.45, s * 19.25, DARK)
			Bx(m, W, "BackPost_" .. i, x - 0.1, 1.7, s * 19.15, x + 0.1, 2.95, s * 19.3, DARK, { decor = true })
		end
	end
	parkBench("ParkBench_N1", 47.3, 50.3, 1); parkBench("ParkBench_N2", 83.3, 86.3, 1); parkBench("ParkBench_S1", 69.7, 72.7, -1)

	local function trashBin(name, x, z, color)
		local m = sub(D, name)
		Vc(m, W, "BinBody", x, 0.3, 2.1, z, 0.9, color)
		Vc(m, W, "BinLid", x, 2.1, 2.3, z, 1.0, DARK, { decor = true })
	end
	trashBin("TrashBin_N", 78.9, 16.6, RED); trashBin("TrashBin_S", 41.1, -16.6, BLUE)

	local function hydrant(name, x, z)
		local m = sub(D, name)
		Vc(m, W, "HydrantBody", x, 0.3, 1.5, z, 0.5, rgb(220, 40, 40))
		Ball(m, W, "HydrantTop", x, 1.5, z, 0.5, rgb(220, 40, 40), { decor = true })
		Bx(m, W, "HydrantNozzles", x - 0.42, 0.95, z - 0.12, x + 0.42, 1.2, z + 0.12, rgb(200, 30, 30), { decor = true })
	end
	hydrant("Hydrant_N", 40.6, 16.3); hydrant("Hydrant_S", 79.4, -16.3)

	-- Arrêt de bus (sud, devant l'immeuble) : abri bleu, banc, affiche éclairée, poteau « BUS »
	do
		local m = sub(D, "BusStop")
		local x0, x1 = 89.8, 96.2
		for i, p in { { x0 + 0.2, -19.25 }, { x1 - 0.2, -19.25 }, { x0 + 0.2, -16.9 }, { x1 - 0.2, -16.9 } } do
			Bx(m, W, "ShelterPost_" .. i, p[1] - 0.12, 0.3, p[2] - 0.12, p[1] + 0.12, 7.2, p[2] + 0.12, DARK)
		end
		Bx(m, W, "ShelterGlass", x0 + 0.32, 0.8, -19.32, x1 - 0.32, 6.8, -19.18, GLASS_C, { mat = GLASS, T = 0.5 })
		Bx(m, W, "ShelterRoof", x0 - 0.2, 7.2, -19.6, x1 + 0.2, 7.5, -16.5, BLUE)
		local band = Bx(m, W, "ShelterBand", x0 - 0.2, 6.95, -16.6, x1 + 0.2, 7.55, -16.45, WHITE, { decor = true })
		label(band, BACK, "BUS STOP", BLUE_D, { ppS = 60, stroke = false, pad = 0.1 })
		Bx(m, W, "ShelterSeat", 91.0, 1.4, -19.1, 95.0, 1.65, -18.3, WOOD)
		for i, x in { 91.4, 94.6 } do Bx(m, W, "ShelterSeatLeg_" .. i, x - 0.12, 0.3, -19.0, x + 0.12, 1.4, -18.4, DARK) end
		Bx(m, W, "AdFrame", x1 - 0.34, 0.6, -19.15, x1 - 0.06, 6.4, -17.05, DARK)
		local ad = Bx(m, W, "AdPoster", x1 - 0.38, 1.0, -19.0, x1 - 0.02, 6.0, -17.2, rgb(255, 214, 60), { decor = true })
		for _, face in { LEFT, RIGHT } do
			local g = surface(ad, face, 60)
			txt(g, "SALE!", RED, 0.05, 0.1, 0.9, 0.36, { strokeT = 3, stroke = RED_D })
			txt(g, "EVERYTHING\nMUST GO", DARK, 0.05, 0.5, 0.9, 0.38, { stroke = false })
		end
		local adl = Instance.new("PointLight"); adl.Range = 6; adl.Brightness = 0.6; adl.Color = rgb(255, 240, 200); adl.Shadows = false; adl.Parent = ad
		local px, pz = 88.8, -16.0
		Bx(m, W, "BusPoleBase", px - 0.3, 0.3, pz - 0.3, px + 0.3, 0.6, pz + 0.3, DARK)
		Vc(m, W, "BusPole", px, 0.6, 8.4, pz, 0.22, STEEL)
		local plate = Bx(m, W, "BusPlate", px - 0.08, 6.4, pz - 0.85, px + 0.08, 8.2, pz + 0.85, BLUE, { decor = true })
		for _, face in { LEFT, RIGHT } do
			local g = surface(plate, face, 60)
			txt(g, "BUS", WHITE, 0, 0.04, 1, 0.56, { strokeT = 2, stroke = BLUE_D })
			txt(g, "LINE 1 · LONDON", GOLDY, 0, 0.6, 1, 0.34, { stroke = false })
		end
		Bx(m, W, "Timetable", px - 0.1, 3.2, pz - 0.35, px + 0.1, 4.6, pz + 0.35, WHITE, { decor = true })
	end

	-- Terrasse du café (nord, sous le store), sans collision
	do
		local m = sub(D, "CafeTerrace")
		for t, tx in { 94.0, 97.0 } do
			local tz = 18.1
			Vc(m, W, "TableTop_" .. t, tx, 2.35, 2.47, tz, 1.2, WHITE, { decor = true })
			Vc(m, W, "TableLeg_" .. t, tx, 0.3, 2.35, tz, 0.14, DARK, { decor = true })
			Vc(m, W, "TableFoot_" .. t, tx, 0.3, 0.38, tz, 0.6, DARK, { decor = true })
			for c, sgn in { -1, 1 } do
				local cx, col = tx + sgn * 1.0, (c == 1) and RED or CREAM
				Bx(m, W, "ChairSeat_" .. t .. c, cx - 0.38, 1.4, tz - 0.38, cx + 0.38, 1.52, tz + 0.38, col, { decor = true })
				Bx(m, W, "ChairBack_" .. t .. c, cx + sgn * 0.3 - 0.06, 1.52, tz - 0.38, cx + sgn * 0.3 + 0.06, 2.5, tz + 0.38, col, { decor = true })
				Vc(m, W, "ChairLeg_" .. t .. c, cx, 0.3, 1.4, tz, 0.12, DARK, { decor = true })
			end
		end
	end

	-- Étal du fleuriste (sud, devant sa vitrine)
	do
		local m = sub(D, "FlowerStand")
		Bx(m, W, "StandLow", 33.9, 0.3, -19.6, 36.4, 0.85, -18.35, rgb(166, 120, 80))
		Bx(m, W, "StandHigh", 33.9, 0.85, -19.6, 36.4, 1.45, -19.0, rgb(166, 120, 80))
		local spots = { { 34.4, 0.85, -18.67 }, { 35.15, 0.85, -18.67 }, { 35.9, 0.85, -18.67 }, { 34.75, 1.45, -19.3 }, { 35.55, 1.45, -19.3 } }
		for i, sp in spots do
			Vc(m, W, "Bucket_" .. i, sp[1], sp[2], sp[2] + 0.5, sp[3], 0.5, STEEL, { decor = true })
			Ball(m, W, "Bouquet_" .. i, sp[1], sp[2] + 0.75, sp[3], 0.72, flowerCols[i], { decor = true })
		end
	end

	-- Plantes en pot de chaque côté des portes du café et de la boulangerie
	for i, p in { { 89.95, 19.3 }, { 92.35, 19.3 }, { 36.95, 19.3 }, { 39.45, 19.3 } } do
		local m = sub(D, "DoorPlant_" .. i)
		Vc(m, W, "PlantPot", p[1], 0.3, 1.0, p[2], 0.5, (i <= 2) and COFFEE or BROWN)
		Ball(m, W, "PlantLeaves", p[1], 1.35, p[2], 0.8, LEAF, { decor = true })
	end
end
flush(D)

-- 5) Panneaux : « WELCOME » près de l'arche (nord), plan du quartier (sud), plaques de rue sur les réverbères ---
--    Les deux panneaux font face aux joueurs qui arrivent de l'arche (tournés de 20° vers la rue).
local SG = group("Signs")
do
	local function standSign(name, cx, cz, nrm, border)
		local m = sub(SG, name)
		local c = Vector3.new(cx, 7.8, cz)
		local cf = CFrame.lookAt(c, c + nrm)
		P(m, "BoardFrame", cf, Vector3.new(4.5, 3.1, 0.24), border, { decor = true })
		local board = P(m, "Board", cf, Vector3.new(4.2, 2.8, 0.3), WHITE, { decor = true })
		for i, sgn in { -1, 1 } do
			local pp = c + cf.RightVector * (sgn * 1.7) - nrm * 0.32
			Vc(m, W, "BoardPost_" .. i, pp.X, 0.3, 9.55, pp.Z, 0.32, border)
			Ball(m, W, "BoardPostCap_" .. i, pp.X, 9.72, pp.Z, 0.5, YELLOW, { decor = true })
		end
		txt(surface(board, BACK, 60), "SEE YOU SOON!", border, 0.15, 0.25, 0.7, 0.5, { strokeT = 2, stroke = DARK })
		return board
	end
	local a = math.rad(20)
	local welcome = standSign("WelcomeSign", 32.2, 17.5, Vector3.new(-math.cos(a), 0, -math.sin(a)), RED)
	local g = surface(welcome, FRONT, 60)
	txt(g, "WELCOME!", RED, 0.04, 0.06, 0.92, 0.56, { strokeT = 3, stroke = RED_D })
	txt(g, "FIRST HEIST STREET", BLUE_D, 0.06, 0.62, 0.88, 0.28, { stroke = false })

	-- Plan : la rue monte vers Londres ; nord (Supérette) à droite, sud (Kiosque) à gauche, vu depuis le panneau
	local board = standSign("TownMap", 32.2, -17.5, Vector3.new(-math.cos(a), 0, math.sin(a)), BLUE)
	local mg = surface(board, FRONT, 100)
	shape2d(mg, rgb(250, 246, 236), 0, 0, 1, 1, { name = "Paper" })
	txt(mg, "TOWN MAP", DARK, 0.03, 0.015, 0.5, 0.16, { stroke = false, pad = 0.06, alignX = Enum.TextXAlignment.Left })
	local function X(z) return 0.04 + 0.92 * (z + 68) / 136 end
	local function Y(x) return 0.19 + 0.77 * (100 - x) / 70 end
	shape2d(mg, rgb(70, 73, 82), X(-15), Y(100), X(15) - X(-15), Y(30) - Y(100), { name = "Road" })
	for i = 0, 3 do
		local z0 = -12 + i * 7
		shape2d(mg, WHITE, X(z0), Y(63), X(z0 + 3.5) - X(z0), Y(57) - Y(63), { name = "Zebra" })
	end
	local north = shape2d(mg, RED, X(20), Y(80), X(68) - X(20), Y(40) - Y(80), { name = "StoreNorth", round = 0.1 })
	txt(north, NAME_N, WHITE, 0, 0, 1, 1, { pad = 0.32, padX = 0.06, strokeT = 2 })
	local south = shape2d(mg, BLUE, X(-68), Y(80), X(-20) - X(-68), Y(40) - Y(80), { name = "StoreSouth", round = 0.1 })
	txt(south, NAME_S, GOLDY, 0, 0, 1, 1, { pad = 0.32, padX = 0.06, strokeT = 2 })
	shape2d(mg, rgb(232, 40, 40), X(-17.5) - 0.02, Y(32.2) - 0.03, 0.04, 0.06, { name = "HereDot", round = 0.5 })
	txt(mg, "YOU ARE HERE", rgb(200, 30, 30), 0.03, 0.87, 0.33, 0.1, { stroke = false, pad = 0.05, alignX = Enum.TextXAlignment.Right })
	txt(mg, "TO LONDON", DARK, 0.64, 0.2, 0.33, 0.1, { stroke = false, pad = 0.05, alignX = Enum.TextXAlignment.Left })

	-- Plaques de rue sur les deux réverbères de l'entrée (x 37,6)
	for _, s in { 1, -1 } do
		local z = s * 16
		local m = sub(SG, "StreetNamePlate_" .. (s > 0 and "N" or "S"))
		Bx(m, W, "PlateRim", 37.8, 7.3, z - 0.06, 41.2, 8.3, z + 0.06, WHITE, { decor = true })
		local p = Bx(m, W, "Plate", 37.9, 7.4, z - 0.08, 41.1, 8.2, z + 0.08, BLUE_D, { decor = true })
		for _, face in { FRONT, BACK } do label(p, face, "FIRST HEIST ST", WHITE, { ppS = 80, stroke = false, pad = 0.12 }) end
	end
end
flush(SG)

-- 6) Façades plaquées sur les murets, sans collision (le muret reste le vrai mur) ------------------------------
--    Repère d'une façade : origine au pied de la façade, côté rue, à l'extrémité droite vue de la rue ;
--    x local le long de la façade, y vers le haut, z local négatif vers la rue. Le mur (z 0..1,35) enveloppe le muret.
local H = group("Facades")
local function northFrame(x0) return CFrame.new(x0, 0, 19.85) end
local function southFrame(x1) return CFrame.new(x1, 0, -19.85) * CFrame.Angles(0, math.pi, 0) end
local function slope(m, frame, name, x0, x1, ytop, depth, drop, color)
	local ang = math.atan2(drop, depth)
	local len = math.sqrt(depth * depth + drop * drop)
	return P(m, name, frame * CFrame.new((x0 + x1) / 2, ytop - drop / 2, -depth / 2) * CFrame.Angles(-ang, 0, 0),
		Vector3.new(x1 - x0, 0.12, len), color, { decor = true })
end
local function awning(m, frame, x0, x1, ytop, aw)
	local depth, drop = aw.depth or 1.7, aw.drop or 0.75
	local n = aw.b and math.max(2, math.floor((x1 - x0) / (aw.stripe or 0.75) + 0.5)) or 1
	local sw = (x1 - x0) / n
	for i = 0, n - 1 do
		slope(m, frame, "AwningStripe_" .. (i + 1), x0 + i * sw, x0 + (i + 1) * sw, ytop, depth, drop, (i % 2 == 0) and aw.a or (aw.b or aw.a))
	end
	Bx(m, frame, "AwningValance", x0, ytop - drop - 0.45, -depth - 0.07, x1, ytop - drop + 0.03, -depth + 0.03, aw.a, { decor = true })
end
-- sp : h, body, trim, coping, plinth, shop { win, door, band, frame, inside, doorColor, signBg, signFg, sign, awning },
--      floors { {y0, y1}, ... }, winX, winW, volets, flowers { box, a, b }, balcony { slab, rail }, ground(m, frame, w), extra(m, frame, w)
local function facade(name, frame, w, sp)
	local m = sub(H, name)
	local dk = { decor = true }
	local h = sp.h
	Bx(m, frame, "Wall", 0, 0, 0, w, h, 1.35, sp.body, { studs = true, decor = true })
	Bx(m, frame, "Cornice", -0.05, h - 0.6, -0.35, w + 0.05, h, 1.4, sp.trim, dk)
	Bx(m, frame, "Coping", 0.1, h, 0.05, w - 0.1, h + 0.3, 1.35, sp.coping or sp.trim, dk)
	local sh = sp.shop
	if sh then
		local a, b = sh.win[1], sh.win[2]
		Bx(m, frame, "ShopBase", a - 0.2, 0.3, -0.12, b + 0.2, 0.9, 0, sp.plinth or DARK, dk)
		Bx(m, frame, "ShopFrame", a - 0.2, 0.9, -0.05, b + 0.2, 5.85, 0, sh.frame, dk)
		Bx(m, frame, "ShopInside", a, 1.05, -0.09, b, 5.65, -0.05, sh.inside or WARM, dk)
		Bx(m, frame, "ShopGlass", a, 1.05, -0.15, b, 5.65, -0.09, GLASS_C, { decor = true, mat = GLASS, T = 0.45 })
		local mid = (a + b) / 2
		Bx(m, frame, "ShopMullion", mid - 0.08, 1.05, -0.19, mid + 0.08, 5.65, -0.15, sh.frame, dk)
		local d0, d1 = sh.door[1], sh.door[2]
		Bx(m, frame, "EntryFrame", d0 - 0.2, 0.3, -0.05, d1 + 0.2, 6.0, 0, sh.frame, dk)
		Bx(m, frame, "EntryPanel", d0, 0.3, -0.12, d1, 5.75, -0.05, sh.doorColor or sh.frame, dk)
		Bx(m, frame, "EntryWindow", d0 + 0.3, 3.2, -0.16, d1 - 0.3, 5.35, -0.12, GLASS_D, { decor = true, mat = GLASS })
		Ball(m, frame, "EntryKnob", d1 - 0.3, 2.9, -0.2, 0.22, STEEL, dk)
		local band = Bx(m, frame, "SignBand", sh.band[1], 6.2, -0.3, sh.band[2], 7.7, 0, sh.signBg, dk)
		label(band, FRONT, sh.sign, sh.signFg, { font = FRED, stroke = false, ppS = 60, pad = 0.12 })
		if sh.awning then awning(m, frame, a - 0.3, b + 0.3, 6.1, sh.awning) end
	end
	if sp.ground then sp.ground(m, frame, w) end
	local n = 0
	for f, ys in sp.floors do
		local y0, y1 = ys[1], ys[2]
		for _, cx in sp.winX do
			n += 1
			local a, b = cx - sp.winW / 2, cx + sp.winW / 2
			local lit = (n + f) % 3 == 0
			Bx(m, frame, "WinFrame_" .. n, a - 0.22, y0 - 0.22, -0.08, b + 0.22, y1 + 0.22, 0, sp.trim, dk)
			Bx(m, frame, "WinGlass_" .. n, a, y0, -0.14, b, y1, -0.08, lit and LIT or GLASS_D, { decor = true, mat = (not lit) and GLASS or nil })
			if sp.balcony then
				Bx(m, frame, "BalconySlab_" .. n, a - 0.45, y0 - 0.45, -1.0, b + 0.45, y0 - 0.22, 0, sp.balcony.slab, dk)
				Bx(m, frame, "BalconyRail_" .. n, a - 0.45, y0 - 0.22, -1.05, b + 0.45, y0 + 0.65, -0.95, sp.balcony.rail, { decor = true, T = 0.1 })
			else
				Bx(m, frame, "WinSill_" .. n, a - 0.35, y0 - 0.5, -0.38, b + 0.35, y0 - 0.22, 0, sp.trim, dk)
			end
			if sp.volets then
				Bx(m, frame, "Volet_A" .. n, a - 1.07, y0 - 0.1, -0.16, a - 0.27, y1 + 0.1, 0, sp.volets, dk)
				Bx(m, frame, "Volet_B" .. n, b + 0.27, y0 - 0.1, -0.16, b + 1.07, y1 + 0.1, 0, sp.volets, dk)
			end
			if sp.flowers and f == 1 then
				Bx(m, frame, "FlowerBox_" .. n, a - 0.1, y0 - 1.0, -0.95, b + 0.1, y0 - 0.5, -0.4, sp.flowers.box, dk)
				for q = 0, 2 do
					local fx = a + (b - a) * (q + 0.5) / 3
					Ball(m, frame, "Flower_" .. n .. "_" .. q, fx, y0 - 0.45, -0.68, 0.55, (q % 2 == 0) and sp.flowers.a or sp.flowers.b, { decor = true, noShadow = true })
				end
			end
		end
	end
	if sp.extra then sp.extra(m, frame, w) end
	return m
end

do
	-- Nord, près de l'arche : boulangerie jaune, volets bleus, store brun et crème (porte à l'est, le panneau WELCOME devant l'ouest)
	facade("Shop_N1_Bakery", northFrame(31.05), 8.6, {
		h = 16.6, body = rgb(255, 214, 120), trim = WHITE, coping = BROWN, plinth = BROWN,
		shop = { win = { 2.6, 5.6 }, door = { 6.3, 8.1 }, band = { 2.2, 8.45 }, frame = BROWN, inside = rgb(255, 232, 190),
			doorColor = RED, signBg = BROWN, signFg = WARM, sign = "BAKERY",
			awning = { a = BROWN, b = WARM, stripe = 0.72 } },
		floors = { { 8.9, 11.5 }, { 12.6, 15.2 } }, winX = { 2.15, 6.45 }, winW = 1.8, volets = BLUE,
	})
	-- Nord, après la Supérette : pharmacie blanche et verte, croix verte lumineuse en drapeau
	local PH = rgb(0, 166, 90)
	facade("Shop_N2_Pharmacy", northFrame(80.35), 9.3, {
		h = 18.0, body = rgb(240, 247, 243), trim = PH, coping = rgb(0, 120, 70), plinth = DARK,
		shop = { win = { 0.6, 6.4 }, door = { 7.1, 8.8 }, band = { 0.3, 9.0 }, frame = rgb(0, 130, 75), inside = rgb(232, 250, 240),
			doorColor = WHITE, signBg = WHITE, signFg = PH, sign = "PHARMACY" },
		floors = { { 9.0, 11.8 }, { 13.0, 15.8 } }, winX = { 2.3, 6.9 }, winW = 2.2,
		extra = function(m, frame, w)
			local x0, x1 = w - 0.75, w - 0.45
			local v = Bx(m, frame, "CrossV", x0, 9.3, -1.85, x1, 12.1, -0.95, rgb(40, 230, 110), { decor = true, mat = NEON, noShadow = true })
			Bx(m, frame, "CrossH", x0, 10.25, -2.8, x1, 11.15, 0, rgb(40, 230, 110), { decor = true, mat = NEON, noShadow = true })
			local pl = Instance.new("PointLight"); pl.Color = rgb(60, 255, 120); pl.Range = 10; pl.Brightness = 0.8; pl.Shadows = false; pl.Parent = v
		end,
	})
	-- Nord, au bout : café corail, store rouge et blanc (terrasse dessous), jardinières
	facade("Shop_N3_Cafe", northFrame(89.65), 9.25, {
		h = 16.2, body = rgb(250, 150, 120), trim = CREAM, coping = RED_D, plinth = COFFEE,
		shop = { win = { 3.1, 8.65 }, door = { 0.6, 2.4 }, band = { 0.3, 8.95 }, frame = COFFEE, inside = rgb(255, 222, 170),
			doorColor = COFFEE, signBg = COFFEE, signFg = CREAM, sign = "CAFÉ",
			awning = { a = RED, b = WHITE, stripe = 0.7, depth = 2.0 } },
		floors = { { 8.9, 11.4 }, { 12.5, 15.0 } }, winX = { 2.3, 6.9 }, winW = 1.8,
		flowers = { box = COFFEE, a = RED, b = WHITE },
	})
	-- Sud, près de l'arche : fleuriste rose, volets menthe, store vert et blanc, jardinières (porte à l'est)
	facade("Shop_S1_Florist", southFrame(39.65), 8.6, {
		h = 17.2, body = rgb(250, 190, 205), trim = WHITE, coping = GREEN, plinth = GREEN,
		shop = { win = { 3.0, 6.0 }, door = { 0.5, 2.3 }, band = { 0.2, 6.35 }, frame = GREEN, inside = rgb(245, 255, 240),
			doorColor = MINT, signBg = GREEN, signFg = WHITE, sign = "FLOWERS",
			awning = { a = GREEN, b = WHITE, stripe = 0.72 } },
		floors = { { 9.0, 11.6 }, { 12.7, 15.3 } }, winX = { 2.15, 6.45 }, winW = 1.8, volets = MINT,
		flowers = { box = GREEN, a = PINK_D, b = rgb(255, 214, 60) },
	})
	-- Sud, après le Kiosque : glacier bleu pastel et rose, cornet géant au milieu de la façade (porte à l'ouest)
	facade("Shop_S2_IceCream", southFrame(89.65), 9.3, {
		h = 15.8, body = rgb(160, 215, 245), trim = PINK, coping = WHITE, plinth = PINK_D,
		shop = { win = { 0.6, 6.2 }, door = { 6.9, 8.7 }, band = { 0.3, 9.0 }, frame = WHITE, inside = rgb(255, 245, 250),
			doorColor = PINK, signBg = PINK_D, signFg = WHITE, sign = "ICE CREAM",
			awning = { a = PINK_D, b = WHITE, stripe = 0.7 } },
		floors = { { 8.9, 11.4 }, { 12.3, 14.6 } }, winX = { 1.8, 7.5 }, winW = 1.8,
		extra = function(m, frame, w)
			local cx, cz = w / 2, -0.95
			for i, t in { { 8.3, 8.9, 0.35 }, { 8.9, 9.5, 0.7 }, { 9.5, 10.1, 1.05 }, { 10.1, 10.7, 1.4 } } do
				Vc(m, frame, "Cone_" .. i, cx, t[1], t[2], cz, t[3], rgb(222, 170, 100), { decor = true })
			end
			Ball(m, frame, "Scoop_1", cx, 11.35, cz, 1.55, PINK, { decor = true })
			Ball(m, frame, "Scoop_2", cx, 12.35, cz, 1.3, rgb(150, 230, 190), { decor = true })
			Ball(m, frame, "Cherry", cx, 13.1, cz, 0.42, RED, { decor = true })
		end,
	})
	-- Sud, au bout : petit immeuble jaune à balcons bleus, derrière l'arrêt de bus
	facade("House_S3_Flats", southFrame(98.9), 9.25, {
		h = 19.8, body = rgb(255, 205, 90), trim = WHITE, coping = BLUE_D, plinth = BLUE_D,
		floors = { { 8.9, 11.3 }, { 12.4, 14.8 }, { 15.9, 18.3 } }, winX = { 2.3, 6.95 }, winW = 2.0,
		balcony = { slab = BLUE, rail = WHITE },
		ground = function(m, frame, w)
			local dk = { decor = true }
			local d0, d1 = 3.75, 5.5
			Bx(m, frame, "EntryFrame", d0 - 0.25, 0.3, -0.05, d1 + 0.25, 6.3, 0, WHITE, dk)
			Bx(m, frame, "EntryPanel", d0, 0.3, -0.12, d1, 6.0, -0.05, BLUE_D, dk)
			Bx(m, frame, "EntryWindow", d0 + 0.3, 3.4, -0.16, d1 - 0.3, 5.6, -0.12, GLASS_D, { decor = true, mat = GLASS })
			Ball(m, frame, "EntryKnob", d1 - 0.3, 2.9, -0.2, 0.22, STEEL, dk)
			Bx(m, frame, "EntryCanopy", d0 - 0.6, 6.4, -0.4, d1 + 0.6, 6.65, 0, BLUE, dk)
			local num = Bx(m, frame, "HouseNumber", d1 + 0.5, 4.6, -0.08, d1 + 1.3, 5.4, 0, WHITE, dk)
			label(num, FRONT, "12", BLUE_D, { ppS = 80, stroke = false, pad = 0.1 })
			for i, r in { { 0.7, 2.7 }, { 6.6, 8.6 } } do
				Bx(m, frame, "GroundWinFrame_" .. i, r[1] - 0.2, 1.4, -0.08, r[2] + 0.2, 5.4, 0, WHITE, dk)
				Bx(m, frame, "GroundWin_" .. i, r[1], 1.6, -0.14, r[2], 5.2, -0.08, GLASS_D, { decor = true, mat = GLASS })
			end
		end,
	})
end
flush(H)

-- 7) Repères derrière les murets : immeubles colorés à balcons, panneau sur le toit, château d'eau ----------------
--    Hors d'atteinte des joueurs (murets de 12 studs). Façade vitrée côté rue et côté arche ou côté magasin.
local L = group("Landmarks")
do
	local function tower(name, frame, w, d, h, body, accent, sideX)
		local m = sub(L, name)
		local dk = { decor = true }
		Bx(m, frame, "Body", 0, 0, 0, w, h, d, body, { studs = true })
		Bx(m, frame, "RoofCap", -0.25, h, -0.25, w + 0.25, h + 0.6, d + 0.25, accent, { studs = true })
		local n = 0
		for y = 14, h - 3, 3.6 do
			n += 1
			Bx(m, frame, "Ribbon_" .. n, 0.6, y, -0.06, w - 0.6, y + 1.9, 0, GLASS_D, { decor = true, mat = GLASS })
			Bx(m, frame, "Balcony_" .. n, 0.4, y - 0.4, -0.9, w - 0.4, y - 0.15, 0, accent, dk)
			Bx(m, frame, "BalconyRail_" .. n, 0.4, y - 0.15, -0.95, w - 0.4, y + 0.7, -0.85, WHITE, { decor = true, T = 0.15 })
			if sideX then
				local x0 = (sideX == 0) and -0.06 or w
				Bx(m, frame, "SideRibbon_" .. n, x0, y, 0.7, x0 + 0.06, y + 1.9, d - 0.7, GLASS_D, { decor = true, mat = GLASS })
			end
		end
		Vc(m, frame, "RoofTank", w * 0.3, h + 0.6, h + 2.6, d * 0.6, 2.0, STEEL, dk)
		Vc(m, frame, "Antenna", w * 0.72, h + 0.6, h + 5.6, d * 0.45, 0.16, DARK, dk)
		return m
	end
	tower("Tower_N1", CFrame.new(31.6, 0, 23), 7.4, 8, 30, rgb(250, 236, 205), RED, 0)
	tower("Tower_S1", CFrame.new(39.0, 0, -23) * CFrame.Angles(0, math.pi, 0), 7.4, 8, 26, rgb(200, 238, 220), BLUE, 7.4)
	local nb = tower("Block_N2", CFrame.new(82, 0, 24), 16, 12, 25, rgb(250, 160, 130), CREAM, 0)
	tower("Block_S2", CFrame.new(98, 0, -24) * CFrame.Angles(0, math.pi, 0), 16, 12, 22, rgb(150, 200, 240), WHITE, 16)

	-- Panneau sur le toit du Block_N2, tourné vers la rue
	do
		local fr = CFrame.new(82, 0, 24)
		local m = sub(nb, "RoofBillboard")
		for i, x in { 4.5, 11.5 } do Bx(m, fr, "BillboardLeg_" .. i, x - 0.2, 25.6, 1.6, x + 0.2, 27.0, 2.0, DARK) end
		Bx(m, fr, "BillboardFrame", 1.8, 26.8, 1.4, 14.2, 31.2, 1.6, DARK, { decor = true })
		local face = Bx(m, fr, "BillboardFace", 2.0, 27.0, 1.3, 14.0, 31.0, 1.45, rgb(255, 214, 60), { decor = true })
		local g = surface(face, FRONT, 40)
		txt(g, "SMILE!", RED, 0, 0.04, 1, 0.58, { strokeT = 4, stroke = RED_D })
		txt(g, "YOU'RE ON CAMERA", DARK, 0, 0.6, 1, 0.34, { stroke = false })
	end

	-- Château d'eau aux couleurs des deux magasins, derrière le Block_S2 : se voit de tout le couloir
	do
		local m = sub(L, "WaterTower")
		local cx, cz = 90, -47
		local CONC = rgb(214, 214, 220)
		Vc(m, W, "Shaft", cx, 0, 26.5, cz, 3.6, CONC, { studs = true })
		Vc(m, W, "Neck", cx, 26.0, 27.6, cz, 7.0, CONC)
		Vc(m, W, "Tank", cx, 27.6, 34.2, cz, 11.0, CREAM, { studs = true })
		Vc(m, W, "TankBandRed", cx, 29.8, 31.0, cz, 11.2, RED)
		Vc(m, W, "TankBandBlue", cx, 31.0, 32.2, cz, 11.2, BLUE)
		Vc(m, W, "TankLid", cx, 34.2, 34.8, cz, 11.6, BLUE_D)
		Ball(m, W, "TankDome", cx, 34.8, cz, 4.5, BLUE_D)
		Vc(m, W, "Beacon", cx, 36.9, 37.5, cz, 0.6, RED, { decor = true, mat = NEON, noShadow = true })
	end
end
flush(L)

-- 8) Extérieur des deux magasins (dans leur modèle, hors contrat) ----------------------------------------------
--    UpperFloors : volume derrière la fausse façade (y 10,8..16,75, z local -23..-13,5), posé sur le toit et les
--    parapets, avec bandeau de couleur et fenêtres en bande. BladeSign : enseigne verticale perpendiculaire à la
--    façade, au bout ouest (x 41,5) des deux magasins, lisible depuis l'arche ; même texte que leur SignPart.
local function upperFloors(store, wall, band)
	local old = store:FindFirstChild("UpperFloors"); if old then old:Destroy() end
	local U = Instance.new("Model"); U.Name = "UpperFloors"
	local fr = store:GetPivot()
	Bx(U, fr, "UpperSide_L", -20, 11.6, -23, -19.5, 15.6, -13.5, wall, { studs = true })
	Bx(U, fr, "UpperSide_R", 19.5, 11.6, -23, 20, 15.6, -13.5, wall, { studs = true })
	Bx(U, fr, "UpperBack", -19.5, 10.8, -14, 19.5, 15.6, -13.5, wall, { studs = true })
	Bx(U, fr, "UpperBand_L", -20, 15.6, -23, -19.5, 16.4, -13.5, band, { studs = true })
	Bx(U, fr, "UpperBand_R", 19.5, 15.6, -23, 20, 16.4, -13.5, band, { studs = true })
	Bx(U, fr, "UpperBand_B", -19.5, 15.6, -14, 19.5, 16.4, -13.5, band, { studs = true })
	Bx(U, fr, "UpperRoof", -20, 16.4, -22.8, 20, 16.75, -13.5, ROOF, { studs = true })
	Bx(U, fr, "UpperGlass_B", -17, 12.4, -13.5, 17, 14.6, -13.42, GLASS_D, { decor = true, mat = GLASS })
	Bx(U, fr, "UpperGlass_L", -20.08, 12.4, -21.5, -20, 14.6, -15, GLASS_D, { decor = true, mat = GLASS })
	Bx(U, fr, "UpperGlass_R", 20, 12.4, -21.5, 20.08, 14.6, -15, GLASS_D, { decor = true, mat = GLASS })
	U.Parent = store
end
local function bladeSign(store, s, text, bg, fg)
	local old = store:FindFirstChild("BladeSign"); if old then old:Destroy() end
	local m = Instance.new("Model"); m.Name = "BladeSign"
	local x = 41.5
	Bx(m, W, "BladeRim", x - 0.2, 9.4, s * 15.9, x + 0.2, 15.8, s * 19.15, WHITE, { decor = true })
	local board = Bx(m, W, "BladeBoard", x - 0.25, 9.55, s * 16.05, x + 0.25, 15.65, s * 19.0, bg, { decor = true })
	for i, y in { 10.2, 15.0 } do
		Bx(m, W, "BladeArm_" .. i, x - 0.1, y - 0.1, s * 19.1, x + 0.1, y + 0.1, s * 19.45, DARK, { decor = true })
	end
	local letters = {}
	for _, c in utf8.codes(text) do table.insert(letters, utf8.char(c)) end
	for _, face in { LEFT, RIGHT } do
		label(board, face, table.concat(letters, "\n"), fg, { ppS = 60, pad = 0.03, lineHeight = 0.9, strokeT = 3 })
	end
	m.Parent = store
end
upperFloors(superette, CREAM, RED); upperFloors(kiosque, MINT, BLUE)
bladeSign(superette, 1, NAME_N, RED, WHITE); bladeSign(kiosque, -1, NAME_S, BLUE, GOLDY)
task.wait()

-- 9) Vérification (mode Edit) ----------------------------------------------------------------------------------
local report = {}
local function add(s) table.insert(report, s) end
local function aabb(p)
	local h = p.Size / 2
	local mn, mx = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
		local v = p.CFrame:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
		mn = mn:Min(v); mx = mx:Max(v)
	end end end
	return mn, mx
end
local function partsOf(root) local t = {}; for _, d in root:GetDescendants() do if d:IsA("BasePart") then table.insert(t, d) end end; return t end
local mine = partsOf(S)
local extras = {}
for _, st in { superette, kiosque } do
	for _, nm in { "UpperFloors", "BladeSign" } do for _, p in partsOf(st[nm]) do table.insert(extras, p) end end
end
local counts = {}
for _, g in S:GetChildren() do table.insert(counts, g.Name .. " " .. #partsOf(g)) end
local solid = 0
for _, p in mine do if p.CanCollide then solid += 1 end end
add(string.format("Street_Zone1 : %d pièces (%s), dont %d avec collision ; extérieur des magasins : %d pièces", #mine, table.concat(counts, ", "), solid, #extras))
local all = table.clone(mine); for _, p in extras do table.insert(all, p) end
local onRoad, outZone = {}, {}
for _, p in all do
	local mn, mx = aabb(p)
	if mx.Z > -15 + 1e-3 and mn.Z < 15 - 1e-3 and mx.Y > 0.05 then table.insert(onRoad, p:GetFullName()) end
	if mn.X < 30 - 1e-3 or mx.X > 100 + 1e-3 then table.insert(outZone, p:GetFullName()) end
end
add(#onRoad == 0 and "Chaussée z -15..15 : libre (seulement des marquages plats de 0,03, sans collision)"
	or ("Chaussée : " .. #onRoad .. " pièce(s) au-dessus du sol : " .. table.concat(onRoad, ", ", 1, math.min(#onRoad, 8))))
add(#outZone == 0 and "Emprise : tout est entre x 30 et 100" or ("Hors de la zone 1 : " .. table.concat(outZone, ", ", 1, math.min(#outZone, 8))))
-- Chevauchements des pièces solides avec le reste de la place (hors sol du couloir et décor de la zone)
do
	local ov = OverlapParams.new()
	ov.FilterType = Enum.RaycastFilterType.Exclude
	ov.FilterDescendantsInstances = { S, gz1.Ground.Street, gz1.Ground.Side_N, gz1.Ground.Side_S }
	local hits, seen = {}, {}
	for _, p in all do
		if p.CanCollide then
			for _, o in workspace:GetPartsInPart(p, ov) do
				if o.CanCollide and not o:IsDescendantOf(p.Parent) then
					local k = p:GetFullName() .. " ↔ " .. o:GetFullName()
					if not seen[k] then seen[k] = true; table.insert(hits, (k:gsub("Workspace%.Map%.Zone_1%.", ""))) end
				end
			end
		end
	end
	add(#hits == 0 and "Chevauchements solides : aucun" or ("Chevauchements solides (" .. #hits .. ") : " .. table.concat(hits, " ; ", 1, math.min(#hits, 12))))
end
-- Chemins du vigile (réglages de GuardService), vitre sans collision le temps du test
do
	local PFS = game:GetService("PathfindingService")
	local AGENT = { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 4 }
	local function tryPath(a, b)
		local path = PFS:CreatePath(AGENT)
		local ok, err = pcall(function() path:ComputeAsync(a, b) end)
		if not ok then return "erreur " .. tostring(err) end
		if path.Status ~= Enum.PathStatus.Success then return path.Status.Name end
		local wps = path:GetWaypoints()
		local jumps, len = 0, 0
		for i, wp in wps do
			if wp.Action == Enum.PathWaypointAction.Jump then jumps += 1 end
			if i > 1 then len += (wp.Position - wps[i - 1].Position).Magnitude end
		end
		return string.format("OK (%.0f studs, %d saut, arrivée à %.1f)", len, jumps, (wps[#wps].Position - b).Magnitude)
	end
	for _, st in { superette, kiosque } do
		local s = (st == superette) and 1 or -1
		local win = st.Window
		local spawnAtt = st:FindFirstChild("GuardSpawn", true)
		assert(spawnAtt, st.Name .. " : GuardSpawn introuvable")
		local from = spawnAtt.WorldPosition
		local closed = tryPath(from, Vector3.new(60, 0.5, s * 6))
		local was = win.CanCollide
		win.CanCollide = false
		local res = {}
		local ok, err = pcall(function()
			for _, t in { { "rue", Vector3.new(60, 0.5, s * 6) }, { "arche", Vector3.new(34, 0.5, 0) }, { "Londres", Vector3.new(96, 0.5, 0) }, { "trottoir d'en face", Vector3.new(60, 0.8, -s * 17.5) } } do
				table.insert(res, t[1] .. " " .. tryPath(from, t[2]))
			end
		end)
		win.CanCollide = was
		if not ok then table.insert(res, "erreur " .. tostring(err)) end
		add(st.Name .. " : vitre fermée → " .. closed .. " ; vitre ouverte → " .. table.concat(res, " ; "))
	end
end
do
	local scripts = 0
	for _, d in zoneFolder:GetDescendants() do if d:IsA("LuaSourceContainer") then scripts += 1 end end
	add("Scripts dans Map/Zone_1 : " .. scripts .. " ; enseignes : « " .. NAME_N .. " » et « " .. NAME_S .. " »")
	-- Textes restants dans les deux magasins (hors enseigne verticale, qui reprend l'enseigne lettre par lettre)
	local seen, list = {}, {}
	for _, st in { superette, kiosque } do
		for _, d in st:GetDescendants() do
			if d:IsA("TextLabel") and not d:IsDescendantOf(st.BladeSign) and not seen[d.Text] then
				seen[d.Text] = true; table.insert(list, d.Text)
			end
		end
	end
	table.sort(list)
	add("Textes des magasins (" .. translated .. " traduits ce passage) : " .. table.concat(list, ", "))
end
return table.concat(report, "\n")
