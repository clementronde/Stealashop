--!nocheck
-- Zone 1 — quartier de la Supérette (MOD-028, partie zone 1), au gabarit du 2026-11-07 (L-040) : tout ×1,5, couloir de 60.
-- La zone tuto, la première que voient les joueurs : petit centre-ville vert et coloré, aux couleurs des deux magasins
-- (rouge et crème au nord, bleu et menthe au sud), chaussée bleu ardoise, gazon tout autour, feuilles vertes qui volent.
-- À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS tools/clement/store_builder.luau (option scale), puis
-- relancer tools/clement/env/trees_replace.luau (arbres du pack Yasu : ce script recrée ses anciens arbres en pièces).
-- Relancer ce script reconstruit la zone à l'identique : les modèles du même nom sont remplacés.
-- Zones rallongées ×1,25 (L-071, 2026-11-08) : zone 1 = x 30..118, magasins en X = 74, arche ZoneGate_1 à x = 30.
-- Ce qu'il fait :
--  1) greybox de la zone 1 seulement : Street à x 30..118, z -22,5..22,5 (bleu ardoise), Side_N et Side_S à
--     |z| 22,5..62,5 (gazon), murets à z ±(30..31,5), 18 de haut, hors des magasins et entre les arches (x 31,5..44 et
--     104..116,5 ; les piliers des arches occupent 28,5..31,5 et 116,5..119,5), NightPatrol à x 51,9 et 95,6, arche
--     ZoneGate_1 ×1,5, base à y = 0, centrée sur z = 0, même x, même nom, même tag, même structure ; Map/Zone_1/TruckSpawn
--     à x 73,75 (même formule) ;
--  2) les deux magasins reconstruits par le constructeur à ×1,5 (le contrat grandit avec eux) : MINI MART (Supérette)
--     en (74, 0, 66), façade vers -Z, et KIOSK (Kiosque) en (74, 0, -66), tourné de 180°, couleurs et textes d'avant,
--     portée de leurs lumières ×1,5 (ScaleTo ne la change pas) ; plus UpperFloors (volume derrière la fausse façade) et
--     BladeSign (enseigne verticale sur le toit, côté arche) ;
--  3) Map/Zone_1/Street_Zone1 : trottoirs de 0,45 à |z| 22,5..30, marquages plats, mobilier ×1,5, panneaux, décor
--     d'entrée (colonnes, mâts à drapeaux visibles de loin, tapis peint), feuilles vertes en ParticleEmitter (aucun
--     script, débit modéré). Le hub (zone safe) touche la zone 1 à x = 30 : plus de couloir d'entrée à raccorder ;
--  4) Map/Zone_1/Neighborhood_Zone1 : gazon de |z| 62,5 à 140 (sans toucher le greybox), ruelles, petites boutiques
--     (BAKERY, PHARMACY, CAFÉ, FLOWERS, ICE CREAM) et maisons, parcs, peupliers le long des magasins, château d'eau ;
--  5) nuit (L-043) : le tag NightLight sur la partie lumineuse des réverbères et des lanternes, livrée éteinte (pas en
--     Neon, lumières à Enabled = false ; le code l'allume la nuit), et le vrai mur de nuit Map/Entry/NightWall (tag
--     NightWall, livré baissé, RiseHeight 24) à l'entrée de la zone 1, côté hub, juste avant l'arche (x 27, z ±34,5) ;
--     l'ancien mur gris du greybox est rangé dans ServerStorage/_GREYBOX_REMPLACE ;
--  6) vérification en mode Edit : contrat 10.4, arche, chaussée libre, emprise, chevauchements, chemins du vigile
--     (vitre sans collision le temps du test), mur de nuit, lumières de nuit, aucun script. Le script renvoie le compte rendu.
-- Règles : aucun script dans la map ; noms du contrat et tags jamais réutilisés pour le décor ; textes en anglais (L-036).

local Store = _G.ClaudeStore
assert(Store and Store.build, "charger d'abord tools/clement/store_builder.luau (avec l'option scale)")

local K = 1.5 -- gabarit de la carte (L-040)
local CS = game:GetService("CollectionService")
local NIGHT_LIGHT = "NightLight" -- partie lumineuse d'un lampadaire, livrée éteinte ; le code l'allume la nuit (L-043)
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
local ROOF, TILE_RED = rgb(154, 163, 174), rgb(196, 86, 64)
-- Signature de la zone 1 : chaussée bleu ardoise, gazon vif, dalles crème
local ROAD_C, GRASS, PAVER, HEDGE = rgb(60, 70, 94), rgb(106, 186, 88), rgb(214, 208, 196), rgb(46, 140, 60)
local FLOWERS = { rgb(255, 120, 170), rgb(255, 214, 60), RED, rgb(170, 110, 220), WHITE }

local W = CFrame.identity
local ROT_UP = CFrame.Angles(0, 0, math.rad(90))

-- Pièces -----------------------------------------------------------------------------------------------
-- opt : shape, wedge, mat, studs (Plastic + MaterialVariant « Studs »), decor (ni collision, ni toucher, ni requête),
-- T (transparence), noShadow.
local function P(parent, name, cf, size, color, opt)
	opt = opt or {}
	local p = Instance.new(opt.wedge and "WedgePart" or "Part")
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
-- Pavé donné par deux coins, dans le repère `frame` (en studs)
local function Bx(parent, frame, name, x0, y0, z0, x1, y1, z1, color, opt)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	return P(parent, name, frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), size, color, opt)
end
-- Cylindre debout (axe vertical)
local function Vc(parent, frame, name, x, y0, y1, z, dia, color, opt)
	return P(parent, name, frame * CFrame.new(x, (y0 + y1) / 2, z) * ROT_UP, Vector3.new(y1 - y0, dia, dia), color, with(opt, "shape", CYL))
end
local function Ball(parent, frame, name, x, y, z, dia, color, opt)
	return P(parent, name, frame * CFrame.new(x, y, z), Vector3.new(dia, dia, dia), color, with(opt, "shape", BALL))
end
-- Planche entre deux points (ya, za) et (yb, zb) du plan y-z du repère, de x0 à x1 (toits, stores)
local function plank(parent, frame, name, x0, x1, ya, za, yb, zb, th, color, opt)
	local a, b = Vector3.new((x0 + x1) / 2, ya, za), Vector3.new((x0 + x1) / 2, yb, zb)
	local c = (a + b) / 2
	return P(parent, name, frame * CFrame.lookAt(c, c + (b - a).Unit), Vector3.new(math.abs(x1 - x0), th, (b - a).Magnitude), color, opt)
end
-- Mêmes outils, cotes en unités du gabarit (×K) : façades et bâtiments gardent les proportions d'avant
local function BK(parent, frame, name, x0, y0, z0, x1, y1, z1, color, opt)
	return Bx(parent, frame, name, x0 * K, y0 * K, z0 * K, x1 * K, y1 * K, z1 * K, color, opt)
end
local function VcK(parent, frame, name, x, y0, y1, z, dia, color, opt) return Vc(parent, frame, name, x * K, y0 * K, y1 * K, z * K, dia * K, color, opt) end
local function BallK(parent, frame, name, x, y, z, dia, color, opt) return Ball(parent, frame, name, x * K, y * K, z * K, dia * K, color, opt) end
local function plankK(parent, frame, name, x0, x1, ya, za, yb, zb, th, color, opt)
	return plank(parent, frame, name, x0 * K, x1 * K, ya * K, za * K, yb * K, zb * K, th * K, color, opt)
end
-- Coin (WedgePart) : son grand côté est à +z local, ou à -z avec flip
local function wedgeK(parent, frame, name, x0, y0, z0, x1, y1, z1, color, flip, opt)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)) * K
	local c = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) * K
	return P(parent, name, frame * CFrame.new(c) * (flip and CFrame.Angles(0, math.pi, 0) or CFrame.identity), size, color, with(opt, "wedge", true))
end

-- Textes (SurfaceGui, sans script) -------------------------------------------------------------------
local function surface(part, face, ppS)
	local g = Instance.new("SurfaceGui"); g.Name = "Gui_" .. face.Name; g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppS or 40; g.LightInfluence = 0
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
local function sub(parent, name) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end
-- Texte de l'enseigne d'un magasin (repris par l'enseigne du toit et par le plan)
local function storeName(store)
	local sp = store:FindFirstChild("SignPart")
	local t = sp and sp:FindFirstChildWhichIsA("TextLabel", true)
	return (t and t.Text ~= "") and t.Text or store.Name
end

-- 1) Greybox de la zone 1 (à garder si le greybox est régénéré, ou à reporter dans tools/greybox.luau) -------------
local gz1 = workspace.Greybox.Corridor.Zone_1
local GB = gz1.Ground
do
	local function slab(p, x0, x1, z0, z1, color)
		p.Size = Vector3.new(x1 - x0, 2, z1 - z0); p.CFrame = CFrame.new((x0 + x1) / 2, -1, (z0 + z1) / 2)
		p.Color = color; p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs"
	end
	slab(GB.Street, 30, 118, -22.5, 22.5, ROAD_C)
	slab(GB.Side_N, 30, 118, 22.5, 62.5, GRASS)
	slab(GB.Side_S, 30, 118, -62.5, -22.5, GRASS)
	-- murets entre les arches et les magasins (les arches ×1,5 occupent x 28,5..31,5 et 116,5..119,5 ; magasins x 44..104)
	local function wall(p, x0, x1, z0, z1)
		p.Size = Vector3.new(x1 - x0, 18, z1 - z0); p.CFrame = CFrame.new((x0 + x1) / 2, 9, (z0 + z1) / 2)
	end
	wall(GB.SideWall_N1, 31.5, 44, 30, 31.5); wall(GB.SideWall_N2, 104, 116.5, 30, 31.5)
	wall(GB.SideWall_S1, 31.5, 44, -31.5, -30); wall(GB.SideWall_S2, 104, 116.5, -31.5, -30)
	-- repères de patrouille de nuit : x' = 30 + (x - 30) × 1,25 (47,5 → 51,875 ; 82,5 → 95,625), posés en absolu
	for nm, x in { NightPatrol_Z1_A = 51.875, NightPatrol_Z1_B = 95.625 } do
		local p = gz1:FindFirstChild(nm)
		assert(p and p:IsA("BasePart"), nm .. " introuvable dans le greybox de la zone 1")
		p.Position = Vector3.new(x, p.Position.Y, 0)
	end
	-- arche : ×1,5 autour de son pivot (bas, au centre), puis base à y = 0, centrée sur z = 0, même x
	local gate = gz1.ZoneGate_1
	if math.abs(gate:GetScale() - K) > 1e-3 then gate:ScaleTo(K) end
	local cf, size = gate:GetBoundingBox()
	gate:PivotTo(gate:GetPivot() + Vector3.new(30 - cf.Position.X, size.Y / 2 - cf.Position.Y, -cf.Position.Z))
end

-- 2) Les deux magasins, reconstruits à ×1,5 par le constructeur (couleurs et textes d'avant) -----------------------
local zoneFolder = workspace.Map.Zone_1
-- point d'arrivée du camion de la zone : même formule (65 → 73,75), posé en absolu, même hauteur, même z
do
	local ts = zoneFolder:FindFirstChild("TruckSpawn")
	assert(ts and ts:IsA("BasePart"), "Map/Zone_1/TruckSpawn introuvable")
	ts.Position = Vector3.new(73.75, ts.Position.Y, ts.Position.Z)
end
for _, nm in { "STORE_Z1_Superette", "STORE_Z1_Kiosque" } do
	local old = zoneFolder:FindFirstChild(nm); if old then old:Destroy() end
end
-- ScaleTo ne change pas la portée des lumières : on la remet à l'échelle du magasin (comme les zones 2 à 5)
local function growLights(root, k)
	for _, l in root:GetDescendants() do
		if l:IsA("PointLight") or l:IsA("SpotLight") or l:IsA("SurfaceLight") then l.Range = math.min(60, l.Range * k) end
	end
end
local superette = Store.build({ name = "STORE_Z1_Superette", zone = 1, origin = CFrame.new(74, 0, 66), parent = zoneFolder, scale = K })
growLights(superette, K)
task.wait()
local kiosque = Store.build({
	name = "STORE_Z1_Kiosque", zone = 1, origin = CFrame.new(74, 0, -66) * CFrame.Angles(0, math.pi, 0), parent = zoneFolder, scale = K,
	sign = "KIOSK", signColors = { bg = BLUE, text = GOLDY }, awning = { a = BLUE, b = rgb(255, 255, 255) },
	colors = { wall = MINT, front = MINT, upper = MINT, trim = BLUE, pilaster = BLUE, cornice = BLUE_D, counter = BLUE, mat = BLUE, doorKick = YELLOW },
})
growLights(kiosque, K)
task.wait()
local NAME_N, NAME_S = storeName(superette), storeName(kiosque)

-- 3) Rue : Map/Zone_1/Street_Zone1 -------------------------------------------------------------------------------
--    Trottoirs à |z| 22,5..30 (0,45 de haut), chaussée z -22,5..22,5 libre (marquages plats de 0,03, sans collision).
--    Devant les magasins (x 44..104) : vitrine x 65..83 et portes (Supérette x 90,5..96,5, Kiosque x 51,5..57,5) dégagées.
--    Zone ×1,25 : le décor de l'entrée reste près de l'arche, celui des magasins suit les magasins (+9), celui de la
--    sortie suit l'arche de Londres (+18) ; les murets plus longs portent de petites façades (Facades).
do local old = zoneFolder:FindFirstChild("Street_Zone1"); if old then old:Destroy() end end
local S = Instance.new("Folder"); S.Name = "Street_Zone1"; S.Parent = zoneFolder
local function group(name) local m = Instance.new("Model"); m.Name = name; return m end
local function flush(m, parent) m.Parent = parent or S; task.wait() end

local G = group("Ground")
do
	local KERB_C, TILE_A, TILE_B = rgb(246, 246, 242), rgb(240, 232, 214), rgb(222, 224, 228)
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		local segs = (s > 0) and { { 30, 118, KERB_C } } or { { 30, 84, KERB_C }, { 84, 97, rgb(255, 204, 40) }, { 97, 118, KERB_C } }
		for i, sg in segs do Bx(G, W, "Kerb_" .. tag .. i, sg[1], 0, s * 22.5, sg[2], 0.45, s * 23.25, sg[3], { studs = true }) end
		for i = 0, 10 do
			local x0 = 30 + i * 8
			Bx(G, W, "Pavement_" .. tag .. (i + 1), x0, 0, s * 23.25, x0 + 8, 0.45, s * 30, (i % 2 == 0) and TILE_A or TILE_B, { studs = true })
		end
	end
	local function paint(name, x0, z0, x1, z1, color) return Bx(G, W, name, x0, 0, z0, x1, 0.03, z1, color, { decor = true, noShadow = true }) end
	-- Lignes de rive, coupées au passage piéton et à l'arrêt de bus (le milieu garde les repères NightPatrol)
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		local segs = (s > 0) and { { 40.5, 68.5 }, { 79.5, 112 } } or { { 40.5, 68.5 }, { 79.5, 83.5 }, { 97.5, 112 } }
		for i, sg in segs do paint("EdgeLine_" .. tag .. i, sg[1], s * 21.45, sg[2], s * 21.75, rgb(245, 245, 240)) end
	end
	-- Passage piéton entre les deux vitrines (x 69,5..78,5)
	for i = 0, 11 do local z0 = -20.7 + i * 3.6; paint("Zebra_" .. (i + 1), 69.5, z0, 78.5, z0 + 1.8, WHITE) end
	-- Zigzag jaune de l'arrêt de bus (sud)
	local xa0, xb0, nSeg = 84.5, 96.5, 8
	local dx = (xb0 - xa0) / nSeg
	for k = 0, nSeg - 1 do
		local xa, xb = xa0 + k * dx, xa0 + (k + 1) * dx
		local za = -21.3 + ((k % 2 == 0) and 0.45 or -0.45)
		local zb = -21.3 + ((k % 2 == 0) and -0.45 or 0.45)
		local len = math.sqrt((xb - xa) ^ 2 + (zb - za) ^ 2)
		P(G, "BusZigZag_" .. (k + 1), CFrame.new((xa + xb) / 2, 0.015, (za + zb) / 2) * CFrame.Angles(0, math.atan2(-(zb - za), xb - xa), 0),
			Vector3.new(len + 0.18, 0.03, 0.22), rgb(255, 200, 0), { decor = true, noShadow = true })
	end
	-- Tapis peint aux quatre couleurs de la zone, juste après l'arche (et une bande à la sortie, vers Londres)
	local cols = { RED, CREAM, BLUE, MINT }
	for row = 0, 1 do
		for i = 0, 9 do
			local z0 = -22.5 + i * 4.5
			paint("EntryMat_" .. (row * 10 + i + 1), 32.5 + row * 3.5, z0, 36 + row * 3.5, z0 + 4.5, cols[(i + row * 2) % 4 + 1])
		end
	end
	for i = 0, 9 do local z0 = -22.5 + i * 4.5; paint("ExitMat_" .. (i + 1), 113, z0, 116, z0 + 4.5, cols[(i + 1) % 4 + 1]) end
end
flush(G)

local D = group("Props")
do
	-- Réverbères à deux têtes (×1,5), couleur du magasin d'en face. Chaque tête a sa partie lumineuse (Glow), taguée
	-- NightLight et livrée éteinte : SmoothPlastic, lumière à Enabled = false ; la nuit, le code la passe en Neon.
	local function lamp(name, x, z, accent)
		local m = sub(D, name)
		Bx(m, W, "Base", x - 0.6, 0.45, z - 0.6, x + 0.6, 1.35, z + 0.6, DARK)
		Vc(m, W, "Pole", x, 1.35, 15.3, z, 0.54, DARK)
		Vc(m, W, "Ring", x, 3.9, 4.5, z, 0.75, accent, { decor = true })
		Bx(m, W, "Arm", x - 2.03, 14.93, z - 0.17, x + 2.03, 15.3, z + 0.17, DARK, { decor = true })
		for i, dx in { -1.875, 1.875 } do
			Bx(m, W, "Head_" .. i, x + dx - 0.75, 14.63, z - 0.53, x + dx + 0.75, 15.08, z + 0.53, accent, { decor = true })
			local glow = Bx(m, W, "Glow_" .. i, x + dx - 0.6, 14.54, z - 0.42, x + dx + 0.6, 14.63, z + 0.42, rgb(255, 240, 210), { decor = true, noShadow = true })
			CS:AddTag(glow, NIGHT_LIGHT)
			local pl = Instance.new("PointLight"); pl.Name = "LampLight"; pl.Range = 22; pl.Brightness = 0.9
			pl.Color = rgb(255, 224, 176); pl.Shadows = false; pl.Enabled = false; pl.Parent = glow
		end
	end
	for i, x in { 61.6, 87.6, 115.2, 40.0 } do lamp("Lamp_N" .. i, x, 24, RED) end
	for i, x in { 34.2, 60.4, 98.0 } do lamp("Lamp_S" .. i, x, -24, BLUE) end

	-- Arbres « style Roblox » sur grille (×1,5) : tronc avec collision, feuillage au-dessus de 7,8 studs, sans collision
	local function tree(name, x, z, seed)
		local m = sub(D, name)
		local s = (z > 0) and 1 or -1
		Bx(m, W, "Grate", x - 1.05, 0.45, z - 1.05, x + 1.05, 0.51, z + 1.05, rgb(70, 74, 82), { decor = true, noShadow = true })
		Vc(m, W, "Trunk", x, 0.45, 8.4, z, 0.83, TRUNK)
		Ball(m, W, "Crown", x, 10.5, z, 5.4, LEAF, { decor = true })
		Ball(m, W, "CrownTop", x, 12.9, z - s * 0.22, 3.9, LEAF_L, { decor = true })
		for k, o in { { -0.83, 0.68 }, { 0.75, -0.75 } } do
			Ball(m, W, "Blossom_" .. k, x + o[1], 0.75, z + o[2], 0.68, FLOWERS[(seed + k) % #FLOWERS + 1], { decor = true, noShadow = true })
		end
	end
	tree("Tree_N1", 57.6, 25.8, 1); tree("Tree_N2", 101.8, 25.8, 2); tree("Tree_S1", 102.0, -25.8, 3); tree("Tree_S2", 46.2, -25.8, 4)

	-- Bancs face à la rue, dos au magasin (N1) ou à une petite façade de muret (S2, avancé de 0,6 pour dégager la vitrine)
	local function bench(name, x0, x1, s, dz)
		local m = sub(D, name)
		local function z(v) return s * (v - dz) end
		Bx(m, W, "Seat", x0, 2.18, z(27.23), x1, 2.55, z(28.73), WOOD)
		Bx(m, W, "Backrest", x0, 2.93, z(28.73), x1, 4.43, z(29.03), WOOD)
		for i, x in { x0 + 0.45, x1 - 0.45 } do
			Bx(m, W, "Leg_" .. i, x - 0.18, 0.45, z(27.38), x + 0.18, 2.18, z(28.88), DARK)
			Bx(m, W, "BackPost_" .. i, x - 0.15, 2.55, z(28.73), x + 0.15, 4.43, z(28.95), DARK, { decor = true })
		end
	end
	bench("ParkBench_N1", 51.0, 55.5, 1, 0)
	bench("ParkBench_S2", 108.3, 112.8, -1, 0.6)
	-- Jardinières fleuries devant deux petites façades de muret (bac en bois, terre, touffes et fleurs)
	local function flowerBed(name, x0, x1, s, seed)
		local m = sub(D, name)
		Bx(m, W, "Planter", x0, 0.45, s * 26.4, x1, 1.65, s * 28.2, WOOD, { studs = true })
		Bx(m, W, "Soil", x0 + 0.15, 1.65, s * 26.55, x1 - 0.15, 1.71, s * 28.05, COFFEE, { decor = true, noShadow = true })
		local n = math.floor((x1 - x0) / 1.1)
		for k = 0, n - 1 do
			local fx = x0 + (x1 - x0) * (k + 0.5) / n
			Ball(m, W, "Leafy_" .. (k + 1), fx, 1.95, s * 27.3, 1.0, GREEN, { decor = true, noShadow = true })
			for r, dz in { -0.38, 0.38 } do
				Ball(m, W, "Flower_" .. (k + 1) .. "_" .. r, fx + (r == 1 and -0.2 or 0.2), 2.4, s * (27.3 + dz), 0.5,
					FLOWERS[(seed + k * 2 + r) % #FLOWERS + 1], { decor = true, noShadow = true })
			end
		end
	end
	flowerBed("FlowerBed_N2", 108.55, 112.55, 1, 1)
	flowerBed("FlowerBed_S1", 38.4, 42.4, -1, 3)
	local function trashBin(name, x, z, color)
		local m = sub(D, name)
		Vc(m, W, "BinBody", x, 0.45, 3.15, z, 1.35, color)
		Vc(m, W, "BinLid", x, 3.15, 3.45, z, 1.5, DARK, { decor = true })
	end
	trashBin("TrashBin_N", 85.2, 24.9, RED); trashBin("TrashBin_S", 62.6, -24.9, BLUE)
	local function hydrant(name, x, z)
		local m = sub(D, name)
		Vc(m, W, "HydrantBody", x, 0.45, 2.25, z, 0.75, rgb(220, 40, 40))
		Ball(m, W, "HydrantTop", x, 2.25, z, 0.75, rgb(220, 40, 40), { decor = true })
		Bx(m, W, "HydrantNozzles", x - 0.63, 1.43, z - 0.18, x + 0.63, 1.8, z + 0.18, rgb(200, 30, 30), { decor = true })
	end
	hydrant("Hydrant_N", 46.2, 24.45); hydrant("Hydrant_S", 58.6, -24.45)

	-- Arrêt de bus (sud, devant le Kiosque, à l'est de sa vitrine) : abri bleu, banc, affiche éclairée, poteau
	do
		local m = sub(D, "BusStop")
		local x0, x1 = 85.0, 94.6
		for i, p in { { x0 + 0.3, -28.88 }, { x1 - 0.3, -28.88 }, { x0 + 0.3, -25.35 }, { x1 - 0.3, -25.35 } } do
			Bx(m, W, "ShelterPost_" .. i, p[1] - 0.18, 0.45, p[2] - 0.18, p[1] + 0.18, 10.8, p[2] + 0.18, DARK)
		end
		Bx(m, W, "ShelterGlass", x0 + 0.48, 1.2, -28.98, x1 - 0.48, 10.2, -28.77, GLASS_C, { mat = GLASS, T = 0.5 })
		Bx(m, W, "ShelterRoof", x0 - 0.3, 10.8, -29.4, x1 + 0.3, 11.25, -24.75, BLUE)
		local band = Bx(m, W, "ShelterBand", x0 - 0.3, 10.43, -24.9, x1 + 0.3, 11.33, -24.68, WHITE, { decor = true })
		label(band, BACK, "BUS STOP", BLUE_D, { ppS = 50, stroke = false, pad = 0.1 })
		Bx(m, W, "ShelterSeat", x0 + 2.0, 2.1, -28.65, x0 + 8.0, 2.48, -27.45, WOOD)
		for i, x in { x0 + 2.6, x0 + 7.4 } do Bx(m, W, "ShelterSeatLeg_" .. i, x - 0.18, 0.45, -28.5, x + 0.18, 2.1, -27.6, DARK) end
		Bx(m, W, "AdFrame", x1 - 0.51, 0.9, -28.73, x1 - 0.09, 9.6, -25.58, DARK)
		local ad = Bx(m, W, "AdPoster", x1 - 0.57, 1.5, -28.5, x1 - 0.03, 9.0, -25.8, rgb(255, 214, 60), { decor = true })
		for _, face in { LEFT, RIGHT } do
			local g = surface(ad, face, 40)
			txt(g, "SALE!", RED, 0.05, 0.1, 0.9, 0.36, { strokeT = 3, stroke = RED_D })
			txt(g, "EVERYTHING\nMUST GO", DARK, 0.05, 0.5, 0.9, 0.38, { stroke = false })
		end
		local adl = Instance.new("PointLight"); adl.Range = 9; adl.Brightness = 0.6; adl.Color = rgb(255, 240, 200); adl.Shadows = false; adl.Parent = ad
		local px, pz = 96.6, -24.0
		Bx(m, W, "BusPoleBase", px - 0.45, 0.45, pz - 0.45, px + 0.45, 0.9, pz + 0.45, DARK)
		Vc(m, W, "BusPole", px, 0.9, 12.6, pz, 0.33, STEEL)
		local plate = Bx(m, W, "BusPlate", px - 0.12, 9.6, pz - 1.28, px + 0.12, 12.3, pz + 1.28, BLUE, { decor = true })
		for _, face in { LEFT, RIGHT } do
			local g = surface(plate, face, 40)
			txt(g, "BUS", WHITE, 0, 0.04, 1, 0.56, { strokeT = 2, stroke = BLUE_D })
			txt(g, "LINE 1 · LONDON", GOLDY, 0, 0.6, 1, 0.34, { stroke = false })
		end
		Bx(m, W, "Timetable", px - 0.15, 4.8, pz - 0.53, px + 0.15, 6.9, pz + 0.53, WHITE, { decor = true })
	end
end
flush(D)

-- Panneaux : WELCOME en hauteur au nord près de l'arche (visible depuis l'entrée, au-dessus de ses murs), plan du
-- quartier à hauteur des yeux au sud, plaques de rue sur deux réverbères. Les deux panneaux regardent l'arche (35°).
local SG = group("Signs")
do
	local function standSign(name, cx, cy, cz, nrm, border, postTop)
		local m = sub(SG, name)
		local c = Vector3.new(cx, cy, cz)
		local cf = CFrame.lookAt(c, c + nrm)
		P(m, "BoardFrame", cf, Vector3.new(6.75, 4.65, 0.36), border, { decor = true })
		local board = P(m, "Board", cf, Vector3.new(6.3, 4.2, 0.45), WHITE, { decor = true })
		for i, sgn in { -1, 1 } do
			local pp = c + cf.RightVector * (sgn * 2.55) - nrm * 0.48
			Vc(m, W, "BoardPost_" .. i, pp.X, 0.45, postTop, pp.Z, 0.48, border)
			Ball(m, W, "BoardPostCap_" .. i, pp.X, postTop + 0.25, pp.Z, 0.75, YELLOW, { decor = true })
		end
		txt(surface(board, BACK, 40), "SEE YOU SOON!", border, 0.15, 0.25, 0.7, 0.5, { strokeT = 2, stroke = DARK })
		return board
	end
	local a = math.rad(35)
	local welcome = standSign("WelcomeSign", 34.0, 16.1, 26.1, Vector3.new(-math.cos(a), 0, -math.sin(a)), RED, 18.6)
	local g = surface(welcome, FRONT, 40)
	txt(g, "WELCOME!", RED, 0.04, 0.06, 0.92, 0.56, { strokeT = 3, stroke = RED_D })
	txt(g, "FIRST HEIST STREET", BLUE_D, 0.06, 0.62, 0.88, 0.28, { stroke = false })
	local wl = Instance.new("PointLight"); wl.Range = 16; wl.Brightness = 0.9; wl.Color = rgb(255, 236, 200); wl.Shadows = false; wl.Parent = welcome

	-- Plan : la rue monte vers Londres ; nord (Supérette) à droite, sud (Kiosque) à gauche, vu depuis le panneau
	local board = standSign("TownMap", 34.0, 6.0, -26.4, Vector3.new(-math.cos(a), 0, math.sin(a)), BLUE, 8.5)
	local mg = surface(board, FRONT, 70)
	shape2d(mg, rgb(250, 246, 236), 0, 0, 1, 1, { name = "Paper" })
	txt(mg, "TOWN MAP", DARK, 0.03, 0.02, 0.5, 0.13, { stroke = false, pad = 0.06, alignX = Enum.TextXAlignment.Left })
	txt(mg, "TO LONDON", DARK, 0.5, 0.03, 0.47, 0.11, { stroke = false, pad = 0.08, alignX = Enum.TextXAlignment.Right })
	local function X(z) return 0.04 + 0.92 * (z + 102) / 204 end
	local function Y(x) return 0.17 + 0.66 * (118 - x) / 88 end
	shape2d(mg, ROAD_C, X(-22.5), Y(118), X(22.5) - X(-22.5), Y(30) - Y(118), { name = "Road" })
	for i = 0, 3 do
		local z0 = -19 + i * 10
		shape2d(mg, WHITE, X(z0), Y(78.5), X(z0 + 5) - X(z0), Y(69.5) - Y(78.5), { name = "Zebra" })
	end
	local north = shape2d(mg, RED, X(30), Y(104), X(102) - X(30), Y(44) - Y(104), { name = "StoreNorth", round = 0.08 })
	txt(north, NAME_N, WHITE, 0, 0, 1, 1, { pad = 0.3, padX = 0.06, strokeT = 2 })
	local south = shape2d(mg, BLUE, X(-102), Y(104), X(-30) - X(-102), Y(44) - Y(104), { name = "StoreSouth", round = 0.08 })
	txt(south, NAME_S, GOLDY, 0, 0, 1, 1, { pad = 0.3, padX = 0.06, strokeT = 2 })
	shape2d(mg, rgb(232, 40, 40), X(-26.4) - 0.018, Y(34) - 0.027, 0.036, 0.054, { name = "HereDot", round = 0.5 })
	shape2d(mg, rgb(232, 40, 40), 0.05, 0.885, 0.036, 0.054, { name = "LegendDot", round = 0.5 })
	txt(mg, "YOU ARE HERE", rgb(200, 30, 30), 0.1, 0.86, 0.6, 0.11, { stroke = false, pad = 0.08, alignX = Enum.TextXAlignment.Left })

	-- Plaques de rue sur les réverbères au coin des magasins (en hauteur, vers l'est)
	for _, p in { { 61.6, 24 }, { 60.4, -24 } } do
		local x, z = p[1], p[2]
		local m = sub(SG, "StreetNamePlate_" .. (z > 0 and "N" or "S"))
		Bx(m, W, "PlateRim", x + 0.3, 10.95, z - 0.09, x + 5.4, 12.45, z + 0.09, WHITE, { decor = true })
		local pl = Bx(m, W, "Plate", x + 0.45, 11.1, z - 0.12, x + 5.25, 12.3, z + 0.12, BLUE_D, { decor = true })
		for _, face in { FRONT, BACK } do label(pl, face, "FIRST HEIST ST", WHITE, { ppS = 60, stroke = false, pad = 0.12 }) end
	end
end
flush(SG)

-- Entrée et sortie de la zone : colonnes aux couleurs de la zone sur les murets (décor, le muret reste le mur),
-- mâts à drapeaux de 45 studs à l'entrée (visibles de loin, au-dessus de l'arche), lanternes à la sortie.
-- Le hub touche la zone 1 à x = 30 : toute la largeur de l'arche reste ouverte (le mur de nuit la ferme la nuit).
local GT = group("Gate")
do
	local function column(name, x0, x1, s, body, band, flagA, flagB, withLantern)
		local m = sub(GT, name)
		local dk = { decor = true }
		Bx(m, W, "ColumnBody", x0, 0, s * 29.6, x1, 21, s * 31.6, body, { studs = true, decor = true })
		Bx(m, W, "ColumnBandLow", x0 - 0.05, 0.45, s * 29.5, x1 + 0.05, 1.8, s * 31.65, band, dk)
		Bx(m, W, "ColumnBandTop", x0 - 0.05, 19.5, s * 29.45, x1 + 0.05, 21, s * 31.7, band, dk)
		Bx(m, W, "ColumnCap", x0 - 0.1, 21, s * 29.35, x1 + 0.1, 21.6, s * 31.8, WHITE, dk)
		Bx(m, W, "BannerRod", x0 + 0.2, 17.6, s * 29.2, x1 - 0.2, 17.85, s * 29.45, DARK, dk)
		Bx(m, W, "Banner", x0 + 0.35, 7.5, s * 29.3, x1 - 0.35, 17.6, s * 29.42, flagA, dk)
		Bx(m, W, "BannerStripe", x0 + 0.35, 11.5, s * 29.25, x1 - 0.35, 13.6, s * 29.3, flagB, dk)
		if withLantern then
			-- lanterne : partie lumineuse taguée NightLight, livrée éteinte comme les réverbères
			local cx = (x0 + x1) / 2
			local lan = Bx(m, W, "Lantern", cx - 0.45, 21.6, s * 30.15, cx + 0.45, 22.8, s * 31.05, rgb(255, 230, 170), { decor = true, noShadow = true })
			CS:AddTag(lan, NIGHT_LIGHT)
			local pl = Instance.new("PointLight"); pl.Range = 14; pl.Brightness = 0.9; pl.Color = rgb(255, 220, 160); pl.Shadows = false; pl.Enabled = false; pl.Parent = lan
		end
	end
	column("Column_N1", 31.6, 34.3, 1, CREAM, RED, RED, CREAM, false)
	column("Column_N2", 113.7, 116.4, 1, CREAM, RED, RED, CREAM, true)
	column("Column_S1", 31.6, 34.3, -1, MINT, BLUE, BLUE, MINT, false)
	column("Column_S2", 113.7, 116.4, -1, MINT, BLUE, BLUE, MINT, true)
	local function flagMast(name, x, s, colA, colB)
		local m = sub(GT, name)
		Vc(m, W, "Mast", x, 21.6, 45, s * 30.6, 0.45, STEEL, { decor = true })
		Ball(m, W, "MastTop", x, 45.3, s * 30.6, 0.75, YELLOW, { decor = true })
		for k = 0, 3 do
			Bx(m, W, "Flag_" .. (k + 1), x - 0.06, 44.4 - (k + 1) * 1.0, s * 25.4, x + 0.06, 44.4 - k * 1.0, s * 30.4, (k % 2 == 0) and colA or colB, { decor = true })
		end
	end
	flagMast("FlagMast_N", 32.95, 1, RED, CREAM); flagMast("FlagMast_S", 32.95, -1, BLUE, MINT)
end
flush(GT)

-- Ambiance : feuilles vertes qui volent (ParticleEmitter, aucun script), dans deux volumes invisibles au-dessus de la
-- rue, plus denses à l'entrée. Texture intégrée de Roblox, teintée et aplatie (à remplacer par une feuille du groupe).
local AM = group("Ambience")
do
	local function leafEmitter(name, x0, x1, y0, y1, z0, z1, rate)
		local box = Bx(AM, W, name, x0, y0, z0, x1, y1, z1, WHITE, { decor = true, noShadow = true, T = 1 })
		local e = Instance.new("ParticleEmitter"); e.Name = "Leaves"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Rate = rate
		e.Lifetime = NumberRange.new(8, 11)
		e.Speed = NumberRange.new(1.0, 2.2)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Acceleration = Vector3.new(1.4, -0.7, 0.25)
		e.Drag = 0.3
		e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-140, 140)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55, 0.15), NumberSequenceKeypoint.new(1, 0.55, 0.15) })
		e.Squash = NumberSequence.new(0.7)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.05), NumberSequenceKeypoint.new(0.85, 0.05), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(120, 200, 70)), ColorSequenceKeypoint.new(0.5, rgb(70, 170, 60)), ColorSequenceKeypoint.new(1, rgb(170, 210, 80)) })
		e.LightEmission = 0; e.LightInfluence = 1
		e.Parent = box
	end
	leafEmitter("LeafDrift", 32, 116, 24, 30, -26, 26, 12)
	leafEmitter("LeafDrift_Entrance", 31.6, 44, 16, 24, -27, 27, 6)
end
flush(AM)

-- 4) Quartier autour des magasins : Map/Zone_1/Neighborhood_Zone1 ------------------------------------------------
--    Gazon de |z| 62,5 à 140 (le greybox s'arrête à 62,5), ruelle derrière les magasins, rangée de petites boutiques
--    et de maisons (façades vers la ruelle), parcs, haies, peupliers le long des magasins, château d'eau au sud.
do local old = zoneFolder:FindFirstChild("Neighborhood_Zone1"); if old then old:Destroy() end end
local NB = Instance.new("Folder"); NB.Name = "Neighborhood_Zone1"; NB.Parent = zoneFolder

local NG = group("Ground")
for _, s in { 1, -1 } do
	local tag = s > 0 and "N" or "S"
	Bx(NG, W, "Lawn_" .. tag, 30, -2, s * 62.5, 118, 0, s * 140, GRASS, { studs = true })
	Bx(NG, W, "BackLane_" .. tag, 30, 0, s * 102.6, 118, 0.2, s * 108.6, PAVER, { studs = true })
	Bx(NG, W, "Hedge_" .. tag, 30.5, 0, s * 138.6, 117.5, 1.8, s * 139.8, HEDGE, { studs = true })
end
flush(NG, NB)

-- Bâtiment : volume, façade (boutique ou entrée), étages, toit plat ou à deux pans. Repère : origine au pied de la
-- façade, côté ruelle, à son extrémité droite vue de la ruelle ; x le long de la façade, z local négatif vers la ruelle.
-- Cotes en unités du gabarit (×K). Façade plaquée sur un muret (onWall) : pas de marche (le trottoir de 0,45 en tient
-- lieu), ni clim ni réservoir, corniche arrêtée au dos du corps (elle n'entre pas dans le muret).
local function awningK(m, frame, x0, x1, ytop, aw)
	local depth, drop = aw.depth or 1.7, aw.drop or 0.75
	local n = aw.b and math.max(2, math.floor((x1 - x0) / (aw.stripe or 0.75) + 0.5)) or 1
	local sw = (x1 - x0) / n
	for i = 0, n - 1 do
		plankK(m, frame, "AwningStripe_" .. (i + 1), x0 + i * sw, x0 + (i + 1) * sw, ytop, 0, ytop - drop, -depth, 0.12, (i % 2 == 0) and aw.a or (aw.b or aw.a), { decor = true })
	end
	BK(m, frame, "AwningValance", x0, ytop - drop - 0.45, -depth - 0.07, x1, ytop - drop + 0.03, -depth + 0.03, aw.a, { decor = true })
end
local function entranceFloor(m, frame, w, doorColor, canopy, number)
	local dk = { decor = true }
	local d0, d1 = w / 2 - 0.9, w / 2 + 0.9
	BK(m, frame, "EntryFrame", d0 - 0.25, 0.3, -0.05, d1 + 0.25, 6.3, 0, WHITE, dk)
	BK(m, frame, "EntryPanel", d0, 0.3, -0.12, d1, 6.0, -0.05, doorColor, dk)
	BK(m, frame, "EntryWindow", d0 + 0.3, 3.4, -0.16, d1 - 0.3, 5.6, -0.12, GLASS_D, { decor = true, mat = GLASS })
	BallK(m, frame, "EntryKnob", d1 - 0.3, 2.9, -0.2, 0.22, STEEL, dk)
	BK(m, frame, "EntryCanopy", d0 - 0.6, 6.4, -1.0, d1 + 0.6, 6.65, 0, canopy, dk)
	if number then
		local num = BK(m, frame, "HouseNumber", w / 2 - 0.4, 6.75, -0.08, w / 2 + 0.4, 7.45, 0, WHITE, dk)
		label(num, FRONT, number, BLUE_D, { ppS = 60, stroke = false, pad = 0.1 })
	end
	for i, r in { { 0.7, d0 - 0.9 }, { d1 + 0.9, w - 0.7 } } do
		if r[2] - r[1] >= 1.2 then
			BK(m, frame, "GroundWinFrame_" .. i, r[1] - 0.2, 1.4, -0.08, r[2] + 0.2, 5.4, 0, WHITE, dk)
			BK(m, frame, "GroundWin_" .. i, r[1], 1.6, -0.14, r[2], 5.2, -0.08, GLASS_D, { decor = true, mat = GLASS })
		end
	end
end
local function building(parent, name, frame, w, sp)
	local m = sub(parent, name)
	local dk = { decor = true }
	local h, d = sp.h, sp.depth or 8
	BK(m, frame, "Body", 0, 0, 0, w, h, d, sp.body, { studs = true })
	if not sp.onWall then BK(m, frame, "FrontStep", 0, 0, -0.6, w, 0.3, 0, sp.plinth or DARK, { studs = true }) end
	if sp.roof == "gable" then
		local r, rc = sp.ridge or 3, sp.roofColor or TILE_RED
		plankK(m, frame, "RoofFront", -0.3, w + 0.3, h - 0.3, -0.6, h + r, d / 2, 0.3, rc, dk)
		plankK(m, frame, "RoofBack", -0.3, w + 0.3, h + r, d / 2, h - 0.3, d + 0.6, 0.3, rc, dk)
		for i, xs in { { 0, 0.2 }, { w - 0.2, w } } do
			wedgeK(m, frame, "GableA_" .. i, xs[1], h, 0, xs[2], h + r, d / 2, sp.body, false, dk)
			wedgeK(m, frame, "GableB_" .. i, xs[1], h, d / 2, xs[2], h + r, d, sp.body, true, dk)
		end
	else
		BK(m, frame, "Cornice", -0.05, h - 0.6, -0.35, w + 0.05, h, sp.onWall and d or d + 0.05, sp.trim, dk)
		BK(m, frame, "Coping", 0.1, h, 0.05, w - 0.1, h + 0.3, d - 0.05, sp.coping or sp.trim, dk)
		if not sp.onWall then
			BK(m, frame, "RoofAC", w * 0.2, h + 0.3, d * 0.45, w * 0.2 + 1.8, h + 1.5, d * 0.45 + 1.4, STEEL, dk)
			VcK(m, frame, "RoofTank", w * 0.72, h + 0.3, h + 2.0, d * 0.6, 1.6, STEEL, dk)
		end
	end
	local sh = sp.shop
	if sh then
		local a, b = sh.win[1], sh.win[2]
		BK(m, frame, "ShopBase", a - 0.2, 0.3, -0.12, b + 0.2, 0.9, 0, sp.plinth or DARK, dk)
		BK(m, frame, "ShopFrame", a - 0.2, 0.9, -0.05, b + 0.2, 5.85, 0, sh.frame, dk)
		BK(m, frame, "ShopInside", a, 1.05, -0.09, b, 5.65, -0.05, sh.inside or WARM, dk)
		BK(m, frame, "ShopGlass", a, 1.05, -0.15, b, 5.65, -0.09, GLASS_C, { decor = true, mat = GLASS, T = 0.45 })
		local mid = (a + b) / 2
		BK(m, frame, "ShopMullion", mid - 0.08, 1.05, -0.19, mid + 0.08, 5.65, -0.15, sh.frame, dk)
		local d0, d1 = sh.door[1], sh.door[2]
		BK(m, frame, "EntryFrame", d0 - 0.2, 0.3, -0.05, d1 + 0.2, 6.0, 0, sh.frame, dk)
		BK(m, frame, "EntryPanel", d0, 0.3, -0.12, d1, 5.75, -0.05, sh.doorColor or sh.frame, dk)
		BK(m, frame, "EntryWindow", d0 + 0.3, 3.2, -0.16, d1 - 0.3, 5.35, -0.12, GLASS_D, { decor = true, mat = GLASS })
		BallK(m, frame, "EntryKnob", d1 - 0.3, 2.9, -0.2, 0.22, STEEL, dk)
		local band = BK(m, frame, "SignBand", sh.band[1], 6.2, -0.3, sh.band[2], 7.7, 0, sh.signBg, dk)
		label(band, FRONT, sh.sign, sh.signFg, { font = FRED, stroke = false, ppS = 40, pad = 0.12 })
		if sh.awning then awningK(m, frame, a - 0.3, b + 0.3, 6.1, sh.awning) end
	end
	if sp.ground then sp.ground(m, frame, w) end
	local n = 0
	for f, ys in sp.floors do
		local y0, y1 = ys[1], ys[2]
		for _, cx in sp.winX do
			n += 1
			local a, b = cx - sp.winW / 2, cx + sp.winW / 2
			local lit = (n + f) % 3 == 0
			BK(m, frame, "WinFrame_" .. n, a - 0.22, y0 - 0.22, -0.08, b + 0.22, y1 + 0.22, 0, sp.trim, dk)
			BK(m, frame, "WinGlass_" .. n, a, y0, -0.14, b, y1, -0.08, lit and LIT or GLASS_D, { decor = true, mat = (not lit) and GLASS or nil })
			if sp.balcony then
				BK(m, frame, "BalconySlab_" .. n, a - 0.45, y0 - 0.45, -1.0, b + 0.45, y0 - 0.22, 0, sp.balcony.slab, dk)
				BK(m, frame, "BalconyRail_" .. n, a - 0.45, y0 - 0.22, -1.05, b + 0.45, y0 + 0.65, -0.95, sp.balcony.rail, { decor = true, T = 0.1 })
			else
				BK(m, frame, "WinSill_" .. n, a - 0.35, y0 - 0.5, -0.38, b + 0.35, y0 - 0.22, 0, sp.trim, dk)
			end
			if sp.volets then
				BK(m, frame, "Volet_A" .. n, a - 1.07, y0 - 0.1, -0.16, a - 0.27, y1 + 0.1, 0, sp.volets, dk)
				BK(m, frame, "Volet_B" .. n, b + 0.27, y0 - 0.1, -0.16, b + 1.07, y1 + 0.1, 0, sp.volets, dk)
			end
			if sp.flowers and f == 1 then
				BK(m, frame, "FlowerBox_" .. n, a - 0.1, y0 - 1.0, -0.95, b + 0.1, y0 - 0.5, -0.4, sp.flowers.box, dk)
				for q = 0, 2 do
					local fx = a + (b - a) * (q + 0.5) / 3
					BallK(m, frame, "Flower_" .. n .. "_" .. q, fx, y0 - 0.45, -0.68, 0.55, (q % 2 == 0) and sp.flowers.a or sp.flowers.b, { decor = true, noShadow = true })
				end
			end
		end
	end
	if sp.extra then sp.extra(m, frame, w, h, d) end
	return m
end

local BL = group("Buildings")
do
	local function northFrame(x0) return CFrame.new(x0, 0, 112) end
	local function southFrame(x1) return CFrame.new(x1, 0, -112) * CFrame.Angles(0, math.pi, 0) end
	local PH = rgb(0, 166, 90)
	-- Rangée nord, derrière la Supérette (bords ouest posés par la formule ×1,25 : des ruelles de 5 studs entre eux)
	building(BL, "Shop_N1_Bakery", northFrame(31.25), 9, {
		h = 13.2, body = rgb(255, 214, 120), trim = WHITE, plinth = BROWN, roof = "gable", ridge = 3.2, roofColor = rgb(190, 80, 60),
		shop = { win = { 2.4, 5.8 }, door = { 6.6, 8.4 }, band = { 0.3, 8.7 }, frame = BROWN, inside = rgb(255, 232, 190),
			doorColor = RED, signBg = BROWN, signFg = WARM, sign = "BAKERY", awning = { a = BROWN, b = WARM, stripe = 0.72 } },
		floors = { { 8.9, 11.5 } }, winX = { 2.25, 6.75 }, winW = 1.8, volets = BLUE,
	})
	building(BL, "Shop_N2_Pharmacy", northFrame(50.0), 9, {
		h = 16.8, body = rgb(240, 247, 243), trim = PH, coping = rgb(0, 120, 70), plinth = DARK,
		shop = { win = { 0.6, 6.4 }, door = { 7.1, 8.6 }, band = { 0.3, 8.7 }, frame = rgb(0, 130, 75), inside = rgb(232, 250, 240),
			doorColor = WHITE, signBg = WHITE, signFg = PH, sign = "PHARMACY" },
		floors = { { 9.0, 11.6 }, { 12.8, 15.4 } }, winX = { 2.3, 6.7 }, winW = 2.0,
		extra = function(m, frame, w)
			local x0, x1 = w - 0.75, w - 0.45
			local v = BK(m, frame, "CrossV", x0, 9.3, -1.85, x1, 12.1, -0.95, rgb(40, 230, 110), { decor = true, mat = NEON, noShadow = true })
			BK(m, frame, "CrossH", x0, 10.25, -2.8, x1, 11.15, 0, rgb(40, 230, 110), { decor = true, mat = NEON, noShadow = true })
			local pl = Instance.new("PointLight"); pl.Color = rgb(60, 255, 120); pl.Range = 14; pl.Brightness = 0.8; pl.Shadows = false; pl.Parent = v
		end,
	})
	building(BL, "Shop_N3_Cafe", northFrame(68.75), 9, {
		h = 12.4, body = rgb(250, 150, 120), trim = CREAM, plinth = COFFEE, roof = "gable", ridge = 2.8, roofColor = rgb(120, 72, 50),
		shop = { win = { 3.1, 8.4 }, door = { 0.6, 2.4 }, band = { 0.3, 8.7 }, frame = COFFEE, inside = rgb(255, 222, 170),
			doorColor = COFFEE, signBg = COFFEE, signFg = CREAM, sign = "CAFÉ", awning = { a = RED, b = WHITE, stripe = 0.7, depth = 2.0 } },
		floors = { { 8.9, 11.2 } }, winX = { 2.3, 6.7 }, winW = 1.8, flowers = { box = COFFEE, a = RED, b = WHITE },
	})
	building(BL, "House_N4_Flats", northFrame(87.5), 9, {
		h = 19.8, body = rgb(250, 236, 205), trim = WHITE, coping = RED_D, plinth = RED_D,
		ground = function(m, frame, w) entranceFloor(m, frame, w, RED_D, RED, "7") end,
		floors = { { 8.9, 11.3 }, { 12.4, 14.8 }, { 15.9, 18.3 } }, winX = { 2.3, 6.7 }, winW = 2.0, balcony = { slab = RED, rail = WHITE },
		extra = function(m, frame, w, h)
			for i, x in { 2.0, 7.0 } do BK(m, frame, "BillboardLeg_" .. i, x - 0.15, h + 0.3, 1.4, x + 0.15, h + 1.4, 1.7, DARK) end
			BK(m, frame, "BillboardFrame", 0.8, h + 1.2, 1.2, 8.2, h + 4.2, 1.35, DARK, { decor = true })
			local face = BK(m, frame, "BillboardFace", 0.95, h + 1.35, 1.1, 8.05, h + 4.05, 1.22, rgb(255, 214, 60), { decor = true })
			local g = surface(face, FRONT, 30)
			txt(g, "SMILE!", RED, 0, 0.04, 1, 0.58, { strokeT = 4, stroke = RED_D })
			txt(g, "YOU'RE ON CAMERA", DARK, 0, 0.6, 1, 0.34, { stroke = false })
		end,
	})
	building(BL, "House_N5", northFrame(106.25), 5.2, {
		h = 11.0, body = MINT, trim = WHITE, plinth = BLUE_D, roof = "gable", ridge = 2.4, roofColor = rgb(70, 110, 170),
		ground = function(m, frame, w) entranceFloor(m, frame, w, BLUE, BLUE_D, nil) end,
		floors = { { 8.6, 10.4 } }, winX = { 2.6 }, winW = 2.0, volets = BLUE,
	})
	-- Rangée sud, derrière le Kiosque (bords est par la même formule)
	building(BL, "Shop_S1_Florist", southFrame(48.125), 9, {
		h = 13.0, body = rgb(250, 190, 205), trim = WHITE, plinth = GREEN, roof = "gable", ridge = 3.0, roofColor = rgb(190, 80, 60),
		shop = { win = { 3.0, 8.4 }, door = { 0.5, 2.3 }, band = { 0.3, 8.7 }, frame = GREEN, inside = rgb(245, 255, 240),
			doorColor = MINT, signBg = GREEN, signFg = WHITE, sign = "FLOWERS", awning = { a = GREEN, b = WHITE, stripe = 0.72 } },
		floors = { { 9.0, 11.4 } }, winX = { 2.25, 6.75 }, winW = 1.8, volets = MINT,
		flowers = { box = GREEN, a = PINK_D, b = rgb(255, 214, 60) },
	})
	building(BL, "Shop_S2_IceCream", southFrame(66.875), 9, {
		h = 14.6, body = rgb(160, 215, 245), trim = PINK, coping = WHITE, plinth = PINK_D,
		shop = { win = { 0.6, 6.2 }, door = { 6.9, 8.6 }, band = { 0.3, 8.7 }, frame = WHITE, inside = rgb(255, 245, 250),
			doorColor = PINK, signBg = PINK_D, signFg = WHITE, sign = "ICE CREAM", awning = { a = PINK_D, b = WHITE, stripe = 0.7 } },
		floors = { { 8.9, 11.4 } }, winX = { 1.8, 7.3 }, winW = 1.8,
		extra = function(m, frame, w)
			local cx, cz = w / 2, -0.95
			for i, t in { { 8.3, 8.9, 0.35 }, { 8.9, 9.5, 0.7 }, { 9.5, 10.1, 1.05 }, { 10.1, 10.7, 1.4 } } do
				VcK(m, frame, "Cone_" .. i, cx, t[1], t[2], cz, t[3], rgb(222, 170, 100), { decor = true })
			end
			BallK(m, frame, "Scoop_1", cx, 11.35, cz, 1.55, PINK, { decor = true })
			BallK(m, frame, "Scoop_2", cx, 12.35, cz, 1.3, rgb(150, 230, 190), { decor = true })
			BallK(m, frame, "Cherry", cx, 13.1, cz, 0.42, RED, { decor = true })
		end,
	})
	building(BL, "House_S3", southFrame(85.625), 9, {
		h = 11.8, body = rgb(255, 214, 120), trim = WHITE, plinth = BROWN, roof = "gable", ridge = 3.0, roofColor = rgb(120, 72, 50),
		ground = function(m, frame, w) entranceFloor(m, frame, w, RED, RED_D, "3") end,
		floors = { { 8.9, 11.0 } }, winX = { 2.3, 6.7 }, winW = 1.8, volets = RED,
	})
	building(BL, "House_S4_Flats", southFrame(104.375), 9, {
		h = 17.6, body = rgb(150, 200, 240), trim = WHITE, coping = BLUE_D, plinth = BLUE_D,
		ground = function(m, frame, w) entranceFloor(m, frame, w, BLUE_D, BLUE, "12") end,
		floors = { { 8.9, 11.3 }, { 12.4, 14.8 } }, winX = { 2.3, 6.7 }, winW = 2.0, balcony = { slab = BLUE, rail = WHITE },
	})
	building(BL, "House_S5", southFrame(116.0), 5.2, {
		h = 10.8, body = rgb(250, 236, 205), trim = WHITE, plinth = RED_D, roof = "gable", ridge = 2.4, roofColor = TILE_RED,
		ground = function(m, frame, w) entranceFloor(m, frame, w, RED, RED_D, nil) end,
		floors = { { 8.6, 10.2 } }, winX = { 2.6 }, winW = 1.8, volets = RED,
	})
end
flush(BL, NB)

-- Petites façades plaquées sur les murets, entre les colonnes de l'arche et les pilastres des magasins (x 34,45..43,4
-- et 104,6..113,55 ; pilastres à x 43,55 et 104,45) : corps de 0,675 à 0,02 du muret (le muret reste le mur), un peu
-- plus haut que lui (18,45 avec la corniche), vitrine, porte, enseigne, store ou jardinières, un étage. Dans
-- Street_Zone1/Facades. Textes en anglais. La pizzeria a sa porte côté magasin (mirror) : son store dégage Tree_N2.
local FC = group("Facades")
do
	local FW, FD, FH = 8.95 / K, 0.45, 12.3 -- largeur, profondeur, hauteur (unités ×K)
	local function north(x0) return CFrame.new(x0, 0, 29.98 - FD * K) end
	local function south(x1) return CFrame.new(x1, 0, -(29.98 - FD * K)) * CFrame.Angles(0, math.pi, 0) end
	local function facade(name, frame, sp)
		sp.h = FH; sp.depth = FD; sp.onWall = true
		sp.floors = { { 8.9, 11.3 } }; sp.winX = { 1.65, FW - 1.65 }; sp.winW = 1.6
		local win, door = { 0.6, 3.4 }, { 4.0, 5.5 }
		if sp.mirror then win, door = { FW - 3.4, FW - 0.6 }, { FW - 5.5, FW - 4.0 } end
		sp.shop.win = win; sp.shop.door = door; sp.shop.band = { 0.3, FW - 0.3 }
		return building(FC, name, frame, FW, sp)
	end
	local PIZZA_G = rgb(46, 125, 60)
	facade("Facade_N1_Barber", north(34.45), {
		body = rgb(236, 238, 242), trim = RED, coping = RED_D, plinth = DARK,
		shop = { frame = RED_D, inside = rgb(250, 240, 230), doorColor = WHITE, signBg = RED, signFg = WHITE, sign = "BARBER",
			awning = { a = RED, b = WHITE, stripe = 0.7 } },
		extra = function(m, frame) -- enseigne de barbier entre la vitrine et la porte
			local dk = { decor = true }
			VcK(m, frame, "BarberPoleBase", 3.7, 2.6, 2.8, -0.4, 0.42, DARK, dk)
			VcK(m, frame, "BarberPole", 3.7, 2.8, 5.4, -0.4, 0.34, WHITE, dk)
			for i = 0, 3 do
				VcK(m, frame, "BarberStripe_" .. (i + 1), 3.7, 3.0 + i * 0.6, 3.25 + i * 0.6, -0.4, 0.36, (i % 2 == 0) and RED or BLUE, dk)
			end
			VcK(m, frame, "BarberPoleCap", 3.7, 5.4, 5.6, -0.4, 0.42, DARK, dk)
			BK(m, frame, "BarberBracket", 3.67, 4.2, -0.23, 3.73, 4.4, 0, DARK, dk)
		end,
	})
	facade("Facade_N2_Pizza", north(104.6), {
		body = rgb(246, 170, 100), trim = CREAM, coping = rgb(190, 110, 60), plinth = BROWN, mirror = true,
		shop = { frame = PIZZA_G, inside = rgb(255, 226, 170), doorColor = PIZZA_G, signBg = PIZZA_G, signFg = WHITE, sign = "PIZZA",
			awning = { a = RED, b = WHITE, stripe = 0.7 } },
	})
	facade("Facade_S1_Books", south(43.4), {
		body = rgb(130, 180, 220), trim = WHITE, coping = BLUE_D, plinth = BLUE_D,
		shop = { frame = BLUE_D, inside = rgb(255, 238, 200), doorColor = YELLOW, signBg = BLUE_D, signFg = GOLDY, sign = "BOOKS",
			awning = { a = BLUE_D, b = WHITE, stripe = 0.7 } },
	})
	facade("Facade_S2_Laundry", south(113.55), {
		body = MINT, trim = BLUE, coping = BLUE_D, plinth = BLUE_D, flowers = { box = BLUE, a = PINK_D, b = WHITE },
		shop = { frame = BLUE, inside = rgb(235, 248, 255), doorColor = WHITE, signBg = BLUE, signFg = WHITE, sign = "LAUNDRY" },
	})
end
flush(FC, S)

local PK = group("Parks")
do
	-- Grands arbres des parcs (derrière les rangées) et fontaine au nord
	local function bigTree(name, x, z, seed)
		local m = sub(PK, name)
		Vc(m, W, "Trunk", x, 0, 9, z, 1.2, TRUNK)
		Ball(m, W, "Crown", x, 12, z, 8, LEAF, { decor = true })
		Ball(m, W, "CrownTop", x + 0.6, 15.4, z - 0.4, 5.6, LEAF_L, { decor = true })
		Ball(m, W, "Blossom", x - 1.2, 0.4, z + 1.0, 0.9, FLOWERS[seed % #FLOWERS + 1], { decor = true, noShadow = true })
	end
	for i, p in { { 38.75, 131 }, { 53.75, 134.5 }, { 93.75, 134.5 }, { 108.75, 131 }, { 38.75, -131 }, { 53.75, -134.5 }, { 93.75, -134.5 }, { 108.75, -131 } } do
		bigTree("BigTree_" .. i, p[1], p[2], i)
	end
	local m = sub(PK, "Fountain")
	Vc(m, W, "Basin", 74, 0, 1.35, 132, 7.5, rgb(214, 214, 220), { studs = true })
	Vc(m, W, "Water", 74, 1.2, 1.32, 132, 6.6, rgb(120, 190, 240), { decor = true, T = 0.2 })
	Vc(m, W, "Column", 74, 1.3, 4.8, 132, 1.2, rgb(214, 214, 220))
	Vc(m, W, "Bowl", 74, 4.8, 5.4, 132, 3.0, rgb(214, 214, 220), { decor = true })
	Ball(m, W, "TopBall", 74, 5.75, 132, 0.9, BLUE, { decor = true })

	-- Peupliers dans les bandes de 14 studs à côté des magasins (x 30..44 et 104..118), en deux rangs décalés,
	-- visibles au-dessus des murets
	local function poplar(name, x, z)
		local m2 = sub(PK, name)
		Vc(m2, W, "Trunk", x, 0, 10, z, 0.75, TRUNK)
		for k, b in { { 12, 4.4 }, { 16.5, 3.8 }, { 20.6, 2.8 }, { 23.2, 1.8 } } do
			Ball(m2, W, "Crown_" .. k, x, b[1], z, b[2], (k % 2 == 0) and LEAF_L or rgb(52, 160, 64), { decor = true })
		end
	end
	local n = 0
	for _, band in { { 34.5, 39.5 }, { 113.5, 108.5 } } do
		for _, s in { 1, -1 } do
			for _, z in { 37, 52, 67, 82, 97 } do n += 1; poplar("Poplar_" .. n, band[1], s * z) end
			for _, z in { 44.5, 59.5, 74.5, 89.5 } do n += 1; poplar("Poplar_" .. n, band[2], s * z) end
		end
	end
end
flush(PK, NB)

-- Château d'eau aux couleurs des deux magasins, derrière la rangée sud : repère visible de loin (70 studs)
local WT = group("WaterTower")
do
	local cx, cz = 74, -131
	local CONC = rgb(214, 214, 220)
	Vc(WT, W, "Shaft", cx, 0, 54, cz, 5.4, CONC, { studs = true })
	Vc(WT, W, "Neck", cx, 53.2, 55.6, cz, 10.5, CONC)
	Vc(WT, W, "Tank", cx, 55.6, 65.5, cz, 16.5, CREAM, { studs = true })
	Vc(WT, W, "TankBandRed", cx, 58.6, 60.4, cz, 16.8, RED)
	Vc(WT, W, "TankBandBlue", cx, 60.4, 62.2, cz, 16.8, BLUE)
	Vc(WT, W, "TankLid", cx, 65.5, 66.4, cz, 17.4, BLUE_D)
	Ball(WT, W, "TankDome", cx, 66.4, cz, 6.75, BLUE_D)
	Vc(WT, W, "Beacon", cx, 69.4, 70.3, cz, 0.9, RED, { decor = true, mat = NEON, noShadow = true })
end
flush(WT, NB)

-- 5) Extérieur des deux magasins (dans leur modèle, hors contrat) -------------------------------------------------
--    UpperFloors : volume derrière la fausse façade, posé sur le toit et les parapets (cotes d'avant ×K).
--    BladeSign : enseigne verticale debout sur la corniche, au bout ouest (x 46,25), lisible de loin depuis l'arche.
local function upperFloors(store, wall, band)
	local U = Instance.new("Model"); U.Name = "UpperFloors"
	local fr = store:GetPivot()
	BK(U, fr, "UpperSide_L", -20, 11.6, -23, -19.5, 15.6, -13.5, wall, { studs = true })
	BK(U, fr, "UpperSide_R", 19.5, 11.6, -23, 20, 15.6, -13.5, wall, { studs = true })
	BK(U, fr, "UpperBack", -19.5, 10.8, -14, 19.5, 15.6, -13.5, wall, { studs = true })
	BK(U, fr, "UpperBand_L", -20, 15.6, -23, -19.5, 16.4, -13.5, band, { studs = true })
	BK(U, fr, "UpperBand_R", 19.5, 15.6, -23, 20, 16.4, -13.5, band, { studs = true })
	BK(U, fr, "UpperBand_B", -19.5, 15.6, -14, 19.5, 16.4, -13.5, band, { studs = true })
	BK(U, fr, "UpperRoof", -20, 16.4, -22.8, 20, 16.75, -13.5, ROOF, { studs = true })
	BK(U, fr, "UpperGlass_B", -17, 12.4, -13.5, 17, 14.6, -13.42, GLASS_D, { decor = true, mat = GLASS })
	BK(U, fr, "UpperGlass_L", -20.08, 12.4, -21.5, -20, 14.6, -15, GLASS_D, { decor = true, mat = GLASS })
	BK(U, fr, "UpperGlass_R", 20, 12.4, -21.5, 20.08, 14.6, -15, GLASS_D, { decor = true, mat = GLASS })
	U.Parent = store
end
local function roofBlade(store, lx, text, bg, fg)
	local m = Instance.new("Model"); m.Name = "BladeSign"
	local fr = store:GetPivot()
	Bx(m, fr, "BladeBase", lx - 0.6, 25.35, -38.1, lx + 0.6, 25.85, -34.5, DARK)
	Bx(m, fr, "BladeRim", lx - 0.3, 25.85, -39.6, lx + 0.3, 37.2, -34.6, WHITE, { decor = true })
	local board = Bx(m, fr, "BladeBoard", lx - 0.38, 26.1, -39.35, lx + 0.38, 36.95, -34.85, bg, { decor = true })
	Bx(m, fr, "BladeMast", lx - 0.22, 25.15, -34.0, lx + 0.22, 36.4, -33.56, DARK)
	for i, y in { 29.5, 35.5 } do
		Bx(m, fr, "BladeArm_" .. i, lx - 0.15, y - 0.15, -34.6, lx + 0.15, y + 0.15, -33.56, DARK, { decor = true })
	end
	local letters = {}
	for _, c in utf8.codes(text) do table.insert(letters, utf8.char(c)) end
	for _, face in { LEFT, RIGHT } do
		label(board, face, table.concat(letters, "\n"), fg, { ppS = 40, pad = 0.03, lineHeight = 0.9, strokeT = 3 })
	end
	m.Parent = store
end
upperFloors(superette, CREAM, RED); upperFloors(kiosque, MINT, BLUE)
roofBlade(superette, -27.75, NAME_N, RED, WHITE); roofBlade(kiosque, 27.75, NAME_S, BLUE, GOLDY)
task.wait()

-- 6) Mur de nuit (L-043) : Map/Entry/NightWall, à l'entrée de la zone 1, côté hub, juste avant l'arche ZoneGate_1 ----
--    Le hub (zone safe) touche la zone 1 à x = 30 (plus de couloir d'entrée) : le mur est à x 27 (x 25,45..28,55 avec
--    ses feux, l'arche commence à 28,5) et ferme toute la largeur de l'arche (z -34,5..34,5). Rideau de fer à lames
--    entre deux montants, bandeau jaune et noir, feux orange, panneau de chaque côté. Livré baissé : le haut à y -0,2,
--    juste sous le sol (le sol du hub doit le couvrir) ; la nuit, NightCycleService le monte de RiseHeight (24).
--    L'ancien mur gris du greybox est rangé, avec son trait au sol, dans ServerStorage/_GREYBOX_REMPLACE. Une fente au
--    sol, à fleur, montre d'où il sort. Un seul tag NightWall reste dans le Workspace.
do
	local SS = game:GetService("ServerStorage")
	local keep = SS:FindFirstChild("_GREYBOX_REMPLACE")
	if not keep then keep = Instance.new("Folder"); keep.Name = "_GREYBOX_REMPLACE"; keep.Parent = SS end
	local entryG = workspace.Greybox.Corridor:FindFirstChild("Entry")
	if entryG then
		for _, nm in { "NightWall", "NightWallLine" } do
			local o = entryG:FindFirstChild(nm)
			if o then
				local prev = keep:FindFirstChild(nm); if prev then prev:Destroy() end
				o.Parent = keep
			end
		end
	end
	local mapEntry = workspace.Map:FindFirstChild("Entry")
	if not mapEntry then mapEntry = Instance.new("Folder"); mapEntry.Name = "Entry"; mapEntry.Parent = workspace.Map end
	for _, nm in { "NightWall", "NightWallSlot" } do local o = mapEntry:FindFirstChild(nm); if o then o:Destroy() end end
	local X, TOP, H, HW = 27, -0.2, 24, 34.5
	local B0 = TOP - H
	local STEEL_L, STEEL_M, HAZ_Y, HAZ_K = rgb(167, 176, 188), rgb(140, 149, 162), rgb(255, 204, 40), rgb(30, 30, 34)
	local m = Instance.new("Model"); m.Name = "NightWall"
	for i, z in { -HW, HW - 1.4 } do
		Bx(m, W, "Post_" .. i, X - 1.4, B0, z, X + 1.4, TOP - 2, z + 1.4, DARK, { studs = true })
	end
	local nSlat = 11
	local sh = (H - 2) / nSlat
	for i = 0, nSlat - 1 do
		Bx(m, W, string.format("Slat_%02d", i + 1), X - 0.9, B0 + i * sh, -HW + 1.4, X + 0.9, B0 + (i + 1) * sh, HW - 1.4,
			(i % 2 == 0) and STEEL_L or STEEL_M, { mat = Enum.Material.DiamondPlate })
	end
	for i = 0, math.floor(2 * HW / 3 + 0.5) - 1 do
		local z0 = -HW + i * 3
		Bx(m, W, "Hazard_" .. (i + 1), X - 1.4, TOP - 2, z0, X + 1.4, TOP, z0 + 3, (i % 2 == 0) and HAZ_Y or HAZ_K, { studs = true })
	end
	for _, side in { -1, 1 } do
		local tag = side < 0 and "Lobby" or "Corridor"
		local xf = X + side * 0.9
		Bx(m, W, "SignBorder_" .. tag, xf, B0 + 8.6, -12.3, xf + side * 0.2, B0 + 16.9, 12.3, HAZ_Y, { decor = true })
		local panel = Bx(m, W, "SignPanel_" .. tag, xf, B0 + 8.9, -12, xf + side * 0.3, B0 + 16.6, 12, rgb(24, 30, 48), { decor = true })
		local g = surface(panel, (side < 0) and LEFT or RIGHT, 30)
		if side < 0 then
			txt(g, "CLOSED AT NIGHT", HAZ_Y, 0.04, 0.08, 0.92, 0.55, { strokeT = 3 })
			txt(g, "OPENS AT DAWN", WHITE, 0.1, 0.62, 0.8, 0.3, { stroke = false })
		else
			txt(g, "NIGHT GUARDS ARE OUT!", HAZ_Y, 0.04, 0.08, 0.92, 0.55, { strokeT = 3 })
			txt(g, "BACK TO THE SAFE ZONE", WHITE, 0.1, 0.62, 0.8, 0.3, { stroke = false })
		end
		for k, z in { -24, -8, 8, 24 } do
			Bx(m, W, "WarningLight_" .. tag .. k, X + side * 1.4, TOP - 1.7, z - 0.6, X + side * 1.55, TOP - 0.5, z + 0.6, rgb(255, 160, 40), { decor = true, mat = NEON, noShadow = true })
		end
	end
	m.WorldPivot = CFrame.new(X, B0, 0)
	m:SetAttribute("RiseHeight", H)
	CS:AddTag(m, "NightWall")
	m.Parent = mapEntry
	local slot = Instance.new("Model"); slot.Name = "NightWallSlot"
	Bx(slot, W, "SlotPlate", X - 1.4, 0, -HW, X + 1.4, 0.03, HW, DARK, { decor = true, noShadow = true })
	for i, dx in { -1.5, 1.5 } do
		Bx(slot, W, "SlotEdge_" .. i, X + dx - 0.1, 0, -HW, X + dx + 0.1, 0.03, HW, HAZ_Y, { decor = true, noShadow = true })
	end
	slot.Parent = mapEntry
end

-- 7) Vérification (mode Edit) ----------------------------------------------------------------------------------
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
-- Contrat 10.4 de chaque magasin, tag, Zone, arche
do
	local REQUIRED = { "Window", "WindowFractured", "Shutter", "Door", "Bounds", "GuardSpawn", "SignPart" }
	for i = 1, 10 do table.insert(REQUIRED, string.format("ShelfSlot_%02d", i)) end
	for _, st in { superette, kiosque } do
		local idx = {}
		for _, d in st:GetDescendants() do idx[d.Name] = (idx[d.Name] or 0) + 1 end
		local bad = {}
		for _, nm in REQUIRED do if idx[nm] ~= 1 then table.insert(bad, nm .. " ×" .. (idx[nm] or 0)) end end
		local shards = 0
		for _, d in st.WindowFractured:GetDescendants() do if d.Name:match("^Shard_%d%d$") then shards += 1 end end
		if shards < 30 or shards > 40 then table.insert(bad, "éclats " .. shards) end
		if not st:HasTag("NPCStore") then table.insert(bad, "tag NPCStore") end
		if st:GetAttribute("Zone") ~= 1 then table.insert(bad, "Zone") end
		if st.Bounds.Transparency < 1 then table.insert(bad, "Bounds visible") end
		local w, cf = st.Window.Size, st:GetPivot()
		add(string.format("%s : contrat %s ; vitre %.1f × %.1f ; %d éclats ; pivot (%.0f, %.0f, %.0f) ; enseigne « %s »",
			st.Name, (#bad == 0) and "OK" or table.concat(bad, ", "), w.X, w.Y, shards, cf.X, cf.Y, cf.Z, storeName(st)))
	end
	local gate = gz1.ZoneGate_1
	local cf, size = gate:GetBoundingBox()
	add(string.format("ZoneGate_1 : tag %s, Zone %s, ×%.2f, boîte %.1f × %.1f × %.1f, bas à y %.2f, centre (%.1f, %.1f)",
		tostring(gate:HasTag("ZoneGate")), tostring(gate:GetAttribute("Zone")), gate:GetScale(), size.X, size.Y, size.Z, cf.Y - size.Y / 2, cf.X, cf.Z))
	-- greybox et repères de la zone ×1,25
	local function xr(p) return string.format("x %.2f..%.2f", p.Position.X - p.Size.X / 2, p.Position.X + p.Size.X / 2) end
	local pa, pb, ts = gz1.NightPatrol_Z1_A.Position, gz1.NightPatrol_Z1_B.Position, zoneFolder.TruckSpawn.Position
	add(string.format("Greybox : Street %s, Side_N %s, Side_S %s ; murets N1 %s, N2 %s, S1 %s, S2 %s ; NightPatrol_Z1_A (%.3f, %.2f, %.0f), _B (%.3f, %.2f, %.0f) ; TruckSpawn (%.2f, %.2f, %.2f)",
		xr(GB.Street), xr(GB.Side_N), xr(GB.Side_S), xr(GB.SideWall_N1), xr(GB.SideWall_N2), xr(GB.SideWall_S1), xr(GB.SideWall_S2),
		pa.X, pa.Y, pa.Z, pb.X, pb.Y, pb.Z, ts.X, ts.Y, ts.Z))
	for _, st in { superette, kiosque } do
		local bc, bs = st:GetBoundingBox()
		add(string.format("%s : boîte x %.2f..%.2f, z %.2f..%.2f", st.Name, bc.X - bs.X / 2, bc.X + bs.X / 2, bc.Z - bs.Z / 2, bc.Z + bs.Z / 2))
	end
end
local NBp = partsOf(NB)
local mine = partsOf(S)
local extras = {}
for _, st in { superette, kiosque } do
	for _, nm in { "UpperFloors", "BladeSign" } do for _, p in partsOf(st[nm]) do table.insert(extras, p) end end
end
do
	local counts = {}
	for _, g in S:GetChildren() do table.insert(counts, g.Name .. " " .. #partsOf(g)) end
	local emit = 0
	for _, d in S:GetDescendants() do if d:IsA("ParticleEmitter") then emit += 1 end end
	add(string.format("Street_Zone1 : %d pièces (%s), %d ParticleEmitter ; Neighborhood_Zone1 : %d pièces ; extérieur des magasins : %d pièces",
		#mine, table.concat(counts, ", "), emit, #NBp, #extras))
end
-- Chaussée (entre les arches) et emprise de la zone
local all = table.clone(mine)
for _, p in NBp do table.insert(all, p) end
for _, p in extras do table.insert(all, p) end
do
	local onRoad, outZone = {}, {}
	local check = table.clone(all)
	for _, st in { superette, kiosque } do for _, p in partsOf(st) do table.insert(check, p) end end
	for _, p in check do
		local mn, mx = aabb(p)
		local ghost = p.Transparency >= 1 and not p.CanCollide and not p.CanQuery
		if not ghost and mx.X > 31.5 + 1e-3 and mn.X < 116.5 - 1e-3 and mx.Z > -22.5 + 1e-3 and mn.Z < 22.5 - 1e-3 and mx.Y > 0.05 then
			table.insert(onRoad, p:GetFullName())
		end
		if p:IsDescendantOf(S) or p:IsDescendantOf(NB) then
			if mn.X < 30 - 1e-3 or mx.X > 118 + 1e-3 or math.abs(mn.Z) > 140 + 1e-3 or math.abs(mx.Z) > 140 + 1e-3 then table.insert(outZone, p:GetFullName()) end
		end
	end
	add(#onRoad == 0 and "Chaussée z -22,5..22,5 (x 31,5..116,5, entre les arches) : libre ; seuls des marquages plats de 0,03 et les volumes invisibles des feuilles"
		or ("Chaussée : " .. #onRoad .. " pièce(s) au-dessus du sol : " .. table.concat(onRoad, ", ", 1, math.min(#onRoad, 8))))
	add(#outZone == 0 and "Emprise : tout le décor est entre x 30 et 118 et |z| ≤ 140" or ("Hors de la zone 1 : " .. table.concat(outZone, ", ", 1, math.min(#outZone, 8))))
end
-- Chevauchements des pièces solides avec le reste de la place (hors sol du couloir, gazon sous les magasins)
do
	local ov = OverlapParams.new()
	ov.FilterType = Enum.RaycastFilterType.Exclude
	ov.FilterDescendantsInstances = { S, NB, GB.Street, GB.Side_N, GB.Side_S }
	-- la zone 2 est déplacée en même temps (×1,25) : ses contacts avec la zone 1 sont comptés à part
	local z2 = { workspace.Map:FindFirstChild("Zone_2"), workspace.Greybox.Corridor:FindFirstChild("Zone_2") }
	local function inZone2(o) for _, f in z2 do if f and o:IsDescendantOf(f) then return true end end return false end
	local hits, seen, z2hits = {}, {}, {}
	for _, p in all do
		if p.CanCollide and not p.Name:match("^Lawn_") and not p.Name:match("^BackLane_") then
			for _, o in workspace:GetPartsInPart(p, ov) do
				if o.CanCollide and not o:IsDescendantOf(p.Parent) then
					local k = p:GetFullName() .. " ↔ " .. o:GetFullName()
					if not seen[k] then
						seen[k] = true
						if inZone2(o) then z2hits[o:GetFullName()] = true else table.insert(hits, (k:gsub("Workspace%.", ""))) end
					end
				end
			end
		end
	end
	local nz2 = 0
	for _ in z2hits do nz2 += 1 end
	add((#hits == 0 and "Chevauchements solides : aucun" or ("Chevauchements solides (" .. #hits .. ") : " .. table.concat(hits, " ; ", 1, math.min(#hits, 12))))
		.. (nz2 > 0 and string.format(" ; plus %d pièce(s) de la zone 2 encore à son ancienne place (x 100..)", nz2) or ""))
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
		local closed = tryPath(from, Vector3.new(74, 0.5, s * 10))
		local was = win.CanCollide
		win.CanCollide = false
		local res = {}
		local ok, err = pcall(function()
			for _, t in { { "rue", Vector3.new(74, 0.5, s * 10) }, { "arche", Vector3.new(36, 0.5, 0) }, { "Londres", Vector3.new(112, 0.5, 0) }, { "trottoir d'en face", Vector3.new(74, 0.95, -s * 26.5) } } do
				table.insert(res, t[1] .. " " .. tryPath(from, t[2]))
			end
		end)
		win.CanCollide = was
		if not ok then table.insert(res, "erreur " .. tostring(err)) end
		add(st.Name .. " : vitre fermée → " .. closed .. " ; vitre ouverte → " .. table.concat(res, " ; "))
	end
end
-- Nuit : un seul mur taggé dans le Workspace, livré baissé ; lumières de nuit de la zone 1 livrées éteintes
do
	local walls = {}
	for _, w in CS:GetTagged("NightWall") do if w:IsDescendantOf(workspace) then table.insert(walls, w) end end
	local s = "Mur de nuit : " .. #walls .. " tag NightWall dans le Workspace"
	local w = walls[1]
	if w and w:IsA("Model") then
		local cf, size = w:GetBoundingBox()
		s ..= string.format(" (%s, %.1f × %.1f × %.1f, haut à y %.2f, RiseHeight %s)", w:GetFullName(), size.X, size.Y, size.Z, cf.Y + size.Y / 2, tostring(w:GetAttribute("RiseHeight")))
	end
	add(s)
	local nl, bad = 0, {}
	for _, p in CS:GetTagged(NIGHT_LIGHT) do
		if p:IsDescendantOf(zoneFolder) then
			nl += 1
			if not p:IsA("BasePart") or p.Material == NEON then table.insert(bad, p:GetFullName() .. " en Neon") end
			local lights = 0
			for _, d in p:GetDescendants() do
				if d:IsA("Light") then lights += 1; if d.Enabled then table.insert(bad, p:GetFullName() .. " allumée") end end
			end
			if lights == 0 then table.insert(bad, p:GetFullName() .. " sans lumière") end
		end
	end
	add("NightLight dans la zone 1 : " .. nl .. " parties lumineuses, livrées éteintes" .. ((#bad > 0) and (" ; à revoir : " .. table.concat(bad, ", ")) or ""))
end
do
	local scripts = 0
	for _, d in zoneFolder:GetDescendants() do if d:IsA("LuaSourceContainer") then scripts += 1 end end
	for _, d in gz1:GetDescendants() do if d:IsA("LuaSourceContainer") then scripts += 1 end end
	local me = workspace.Map:FindFirstChild("Entry")
	if me then for _, d in me:GetDescendants() do if d:IsA("LuaSourceContainer") then scripts += 1 end end end
	add("Scripts dans Map/Zone_1, Map/Entry et le greybox de la zone 1 : " .. scripts)
end
return table.concat(report, "\n")
