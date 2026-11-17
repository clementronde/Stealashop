--!nocheck
-- Zone 6 — New York : voisins des magasins agrandis (décision de Clément du 2026-11-17, outil store_stretch.luau).
-- Les deux magasins passent de 60 x 72 à 78 x 108 studs : emprise x 778,4..857,6 ; Banque z 52,4..162,1 ; SalleDesCoffres
-- z -162,1..-52,4. Ce script range le décor de la zone 6 autour, sans toucher aux STORE_* (Edit, relançable).
-- Ordre : zone6_newyork.luau, corridor_widen.luau, store_stretch.luau, puis ce script, puis zone6_ambience.luau.
--  1) Murets du greybox raccourcis aux côtés des magasins : x 718..778,4 et 857,6..868.
--  2) Immeubles de la rue : ceux d'avant les magasins (x 768..778) et du bout (x 858..868) refaits en version étroite,
--     parking des taxis du bout refait sur 10 studs.
--  3) Deuxième rang et tours qui touchaient l'emprise : refaits plus étroits (x jusqu'à 777) ou reculés derrière le
--     fond des magasins (|z| >= 167) ; terrain prolongé jusqu'à |z| = 200.
local rgb = Color3.fromRGB
local K = 1.5
local Z = workspace.Map.Zone_6
local S = Z.Street_NewYork
local H, Sk, Land = S.Buildings, S.Skyline, S.Land
local W = CFrame.identity
local FZ = 59.775   -- pied des façades de la rue (couloir de 120)

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
	if opt.noShadow then p.CastShadow = false end
	p.Parent = parent
	return p
end
local function Bx(parent, frame, name, x0, y0, z0, x1, y1, z1, color, opt)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	return P(parent, name, frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), size, color, opt)
end
local function vcyl(parent, frame, name, x, y0, y1, z, dia, color, opt)
	opt = opt or {}; opt.shape = Enum.PartType.Cylinder
	return P(parent, name, frame * CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(y1 - y0, dia, dia), color, opt)
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
local function frameFor(side, x0, x1)
	if side == "N" then return CFrame.new(x0, 0, FZ) end
	return CFrame.new(x1, 0, -FZ) * CFrame.Angles(0, math.pi, 0)
end
local function replace(parent, name) local o = parent:FindFirstChild(name); if o then o:Destroy() end end

-- 1) Murets du greybox
local g = workspace.Greybox.Corridor.Zone_6.Ground
for _, s in { 1, -1 } do
	local t = s > 0 and "N" or "S"
	local w1, w2 = g["SideWall_" .. t .. "1"], g["SideWall_" .. t .. "2"]
	w1.Size = Vector3.new(778.4 - 718, 18, 1.5); w1.Position = Vector3.new((718 + 778.4) / 2, 9, s * 60.75)
	w2.Size = Vector3.new(868 - 857.6, 18, 1.5); w2.Position = Vector3.new((857.6 + 868) / 2, 9, s * 60.75)
end

-- 2) Immeubles étroits (10 studs) : même dessin que le bloc D1 de zone6_newyork.luau, version « narrow »
local iron, stoneT, glassD, lit = rgb(30, 30, 34), rgb(222, 214, 196), rgb(46, 58, 72), rgb(255, 214, 140)
local function dk() return { decor = true } end
local seed = 61
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
local function narrowTenement(b)
	replace(H, b.name)
	local w = (b.x1 - b.x0) / K
	local m = Instance.new("Model"); m.Name = b.name
	local fr = frameFor(b.side, b.x0, b.x1)
	local h, D = b.h, 8
	Bx(m, fr, "Wall", 0, 0, 0, w, h, D, b.brick, { studs = true, decor = true })
	Bx(m, fr, "Base", 0, 0.3, -0.1, w, 1.2, 0, rgb(86, 84, 82), dk())
	local ex0 = w / 2 - 1.25
	local ex1 = ex0 + 2.5
	Bx(m, fr, "EntryDoor", ex0, 0.9, -0.14, ex1, 6.6, 0, b.door, dk())
	Bx(m, fr, "EntryCanopy", ex0 - 0.4, 6.8, -1.4, ex1 + 0.4, 7.2, 0, iron, dk())
	Bx(m, fr, "EntryLamp", ex1 + 0.3, 5.0, -0.35, ex1 + 0.7, 5.6, 0, lit, { decor = true, mat = Enum.Material.Neon })
	Bx(m, fr, "Step1", ex0 - 0.3, 0.3, -1.3, ex1 + 0.3, 0.6, 0, stoneT, { studs = true })
	Bx(m, fr, "Step2", ex0 - 0.3, 0.6, -0.7, ex1 + 0.3, 0.9, 0, stoneT, { studs = true })
	label(Bx(m, fr, "ShopSign", 0.4, 7.4, -0.3, w - 0.4, 8.6, 0, b.shopColor, dk()), Enum.NormalId.Front, b.shop, rgb(255, 255, 255), 40)
	local floors = math.floor((h - 10.2) / 4.4)
	local cols = { w / 4, 3 * w / 4 }
	for f = 0, floors - 1 do
		local yb = 8.6 + f * 4.4
		Bx(m, fr, "Sill_" .. f, 0, yb + 0.35, -0.3, w, yb + 0.6, 0, b.trim, dk())
		for k, cx in cols do
			Bx(m, fr, string.format("WinFrame_%d_%d", f, k), cx - 1.45, yb + 0.6, -0.08, cx + 1.45, yb + 3.75, 0, b.trim, dk())
			local on = rnd() < 0.22
			Bx(m, fr, string.format("WinGlass_%d_%d", f, k), cx - 1.2, yb + 0.75, -0.14, cx + 1.2, yb + 3.5, -0.08, on and lit or glassD, { decor = true, mat = on and Enum.Material.Neon or Enum.Material.Glass })
		end
	end
	if b.fe then
		local px0, px1 = 0.2, w - 0.2
		local ylast = 8.6 + (floors - 1) * 4.4
		for f = 0, floors - 1 do
			local yb = 8.6 + f * 4.4
			Bx(m, fr, "FE_Platform_" .. f, px0, yb + 0.2, -1.8, px1, yb + 0.35, -0.05, iron, dk())
			Bx(m, fr, "FE_Rail_" .. f, px0, yb + 1.9, -1.85, px1, yb + 2.05, -1.7, iron, dk())
			if f < floors - 1 then
				local run, rise = 4.0, 4.4
				local len = math.sqrt(run * run + rise * rise)
				local cx = (f % 2 == 0) and (px1 - 0.4 - run / 2) or (px0 + 0.4 + run / 2)
				local ang = math.atan2(rise, run) * ((f % 2 == 0) and -1 or 1)
				P(m, "FE_Stair_" .. f, fr * CFrame.new(cx, yb + 0.35 + rise / 2, -1.1) * CFrame.Angles(0, 0, ang), Vector3.new(len, 0.15, 1.0), iron, dk())
			end
		end
		for k, x in { px0, px1 - 0.15 } do Bx(m, fr, "FE_Post_" .. k, x, 8.8, -1.85, x + 0.15, ylast + 2.05, -1.7, iron, dk()) end
	end
	Bx(m, fr, "Frieze", 0, h - 2.2, -0.35, w, h - 0.9, 0, b.trim, dk())
	Bx(m, fr, "Cornice", -0.2, h - 0.9, -1.1, w + 0.2, h, D, iron, dk())
	if b.wt then
		local wx, wz = w / 2, 4
		for k, c in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
			Bx(m, fr, "WT_Leg_" .. k, wx + c[1] - 0.15, h, wz + c[2] - 0.15, wx + c[1] + 0.15, h + 3.5, wz + c[2] + 0.15, iron, dk())
		end
		Bx(m, fr, "WT_Deck", wx - 2.3, h + 3.5, wz - 2.3, wx + 2.3, h + 3.8, wz + 2.3, iron, dk())
		vcyl(m, fr, "WT_Tank", wx, h + 3.8, h + 8.3, wz, 4.0, rgb(132, 92, 60), { studs = true, decor = true })
		vcyl(m, fr, "WT_Roof1", wx, h + 8.3, h + 8.75, wz, 4.4, rgb(88, 62, 44), dk())
		vcyl(m, fr, "WT_Roof2", wx, h + 8.75, h + 9.35, wz, 3.0, rgb(88, 62, 44), dk())
	end
	m.WorldPivot = fr
	m:ScaleTo(K)
	m.Parent = H
	return m
end
local trimA, trimB = rgb(226, 218, 200), rgb(196, 190, 176)
narrowTenement({ name = "Tenement_N2", side = "N", x0 = 768, x1 = 778, h = 24, brick = rgb(102, 62, 46), trim = trimB, door = rgb(120, 30, 34), shop = "LAUNDROMAT", shopColor = rgb(40, 110, 180), fe = true })
narrowTenement({ name = "Tenement_S2", side = "S", x0 = 768, x1 = 778, h = 30, brick = rgb(190, 152, 104), trim = trimB, door = rgb(30, 70, 50), shop = "FLOWERS", shopColor = rgb(200, 80, 140), wt = true })
narrowTenement({ name = "Tenement_End", side = "N", x0 = 858, x1 = 868, h = 30, brick = rgb(134, 82, 60), trim = trimA, door = rgb(25, 25, 30), shop = "COFFEE", shopColor = rgb(110, 70, 40), fe = true, wt = true })

-- Parking des taxis du bout (sud, x 858..868), étroit : un taxi par niveau, nez vers la rue, derrière le muret
replace(S, "Parking")
do
	local Pk = Instance.new("Model"); Pk.Name = "Parking"
	local fr = frameFor("S", 858, 868)
	local w = 10 / K
	local conc, concD, railC = rgb(176, 174, 168), rgb(140, 138, 134), rgb(200, 200, 196)
	local D = 13
	Bx(Pk, fr, "GroundWall", 0, 0, 0, w, 12.4, 1.4, conc, { studs = true, decor = true })
	Bx(Pk, fr, "Base", 0, 0.3, -0.1, w, 1.2, 0, rgb(86, 84, 82), dk())
	Bx(Pk, fr, "Gate", 1.0, 0.3, -0.12, w - 1.0, 7.0, 0, rgb(150, 154, 160), { decor = true, mat = Enum.Material.DiamondPlate })
	Bx(Pk, fr, "GateBox", 0.8, 7.0, -0.4, w - 0.8, 7.6, 0, rgb(110, 114, 120), dk())
	for k, y in { 12.4, 18.6 } do
		Bx(Pk, fr, "Deck_" .. k, 0, y, 0, w, y + 0.6, D, conc, { studs = true, decor = true })
		Bx(Pk, fr, "Rail_" .. k .. "A", 0, y + 1.6, -0.1, w, y + 1.75, 0.05, railC, dk())
		Bx(Pk, fr, "Rail_" .. k .. "B", 0, y + 1.0, -0.1, w, y + 1.15, 0.05, railC, dk())
	end
	Bx(Pk, fr, "RoofDeck", 0, 24.8, 0, w, 25.4, D, concD, { studs = true, decor = true })
	Bx(Pk, fr, "RoofParapet", 0, 25.4, -0.1, w, 26.4, 0.5, conc, dk())
	for k, x in { 0, w - 0.6 } do Bx(Pk, fr, "GaragePillar_" .. k, x, 13.0, 0, x + 0.6, 24.8, 0.6, concD, dk()) end
	Bx(Pk, fr, "GarageSide_L", -0.05, 12.4, 0.6, 0.35, 24.8, D, concD, dk())
	Bx(Pk, fr, "GarageSide_R", w - 0.35, 12.4, 0.6, w + 0.05, 24.8, D, concD, dk())
	Bx(Pk, fr, "GarageBack", 0, 12.4, D - 0.4, w, 24.8, D, concD, dk())
	local blue, taxiY = rgb(30, 80, 170), rgb(250, 196, 20)
	label(Bx(Pk, fr, "ParkingBand", 0.3, 8.0, -0.3, w - 0.3, 9.6, 0, taxiY, dk()), Enum.NormalId.Front, "TAXI · PARKING", iron, 40, taxiY)
	label(Bx(Pk, fr, "ParkingSign", w / 2 - 1.0, 9.9, -0.3, w / 2 + 1.0, 11.9, 0, blue, dk()), Enum.NormalId.Front, "P", rgb(255, 255, 255), 40, blue)
	local blackT, cream = rgb(24, 24, 28), rgb(255, 240, 200)
	local function taxi(name, cf)
		local m = Instance.new("Model"); m.Name = name; m.Parent = Pk
		Bx(m, cf, "Body", -1.9, 0.6, -4, 1.9, 2.2, 4, taxiY, dk())
		Bx(m, cf, "Cabin", -1.7, 2.2, -1.8, 1.7, 3.4, 2.2, rgb(40, 50, 62), { decor = true, mat = Enum.Material.Glass })
		Bx(m, cf, "Roof", -1.8, 3.4, -1.9, 1.8, 3.7, 2.3, taxiY, dk())
		local sign = Bx(m, cf, "TaxiSign", -0.6, 3.7, -0.3, 0.6, 4.3, 0.5, cream, dk())
		label(sign, Enum.NormalId.Front, "TAXI", blackT, 60, cream)
		label(sign, Enum.NormalId.Back, "TAXI", blackT, 60, cream)
		Bx(m, cf, "Checker", -1.95, 1.5, -3.6, 1.95, 1.8, 3.6, blackT, dk())
		for k, c in { { -1.75, -2.6 }, { 1.75, -2.6 }, { -1.75, 2.6 }, { 1.75, 2.6 } } do
			P(m, "Wheel_" .. k, cf * CFrame.new(c[1], 0.7, c[2]), Vector3.new(0.5, 1.4, 1.4), blackT, { shape = Enum.PartType.Cylinder, decor = true })
		end
		Bx(m, cf, "Headlights", -1.5, 1.4, -4.06, 1.5, 1.8, -4.0, rgb(255, 250, 220), { decor = true, mat = Enum.Material.Neon })
		Bx(m, cf, "Taillights", -1.5, 1.4, 4.0, 1.5, 1.8, 4.06, rgb(230, 40, 40), { decor = true, mat = Enum.Material.Neon })
	end
	taxi("Taxi_1", fr * CFrame.new(w / 2, 13.0, 6.5))
	taxi("Taxi_2", fr * CFrame.new(w / 2, 19.2, 6.8) * CFrame.Angles(0, math.rad(-5), 0))
	taxi("Taxi_3", fr * CFrame.new(w / 2, 25.4, 6.6) * CFrame.Angles(0, math.rad(6), 0))
	Pk.WorldPivot = fr
	Pk:ScaleTo(K)
	Pk.Parent = S
end

-- 3) Deuxième rang et tours
local glassC, tipC = rgb(52, 64, 80), rgb(255, 70, 60)
local neonW, neonG = rgb(255, 204, 110), rgb(120, 220, 255)
local gold, sand, capC = rgb(212, 172, 60), rgb(196, 170, 130), rgb(150, 156, 164)
local function waterTower(m, x, z, y)
	for k, c in { { -2.4, -2.4 }, { 2.4, -2.4 }, { -2.4, 2.4 }, { 2.4, 2.4 } } do
		Bx(m, W, "WT_Leg_" .. k, x + c[1] - 0.22, y, z + c[2] - 0.22, x + c[1] + 0.22, y + 5.25, z + c[2] + 0.22, iron, { decor = true })
	end
	Bx(m, W, "WT_Deck", x - 3.45, y + 5.25, z - 3.45, x + 3.45, y + 5.7, z + 3.45, iron, { decor = true })
	vcyl(m, W, "WT_Tank", x, y + 5.7, y + 12.45, z, 6.0, rgb(132, 92, 60), { studs = true, decor = true })
	vcyl(m, W, "WT_Roof1", x, y + 12.45, y + 13.1, z, 6.6, rgb(88, 62, 44), { decor = true })
	vcyl(m, W, "WT_Roof2", x, y + 13.1, y + 14.0, z, 4.5, rgb(88, 62, 44), { decor = true })
end
local function tower(name, tiers, spire)
	replace(Sk, name)
	local m = Instance.new("Model"); m.Name = name
	for i, t in tiers do
		Bx(m, W, "Tier_" .. i, t.x0, t.y0, t.z0, t.x1, t.y1, t.z1, t.color, { studs = (t.mat == nil), decor = true, mat = t.mat })
		local ya, yb = t.y0 + (t.from or 2), t.y1 - 2
		for k = 1, (t.nx or 0) do
			local x = t.x0 + 1 + (t.x1 - t.x0 - 2) * (k - 0.5) / t.nx
			Bx(m, W, string.format("WinZ_%d_%d", i, k), x - 0.6, ya, t.z0 - 0.15, x + 0.6, yb, t.z1 + 0.15, glassC, { decor = true, mat = Enum.Material.Glass })
		end
		for k = 1, (t.nz or 0) do
			local z = t.z0 + 1 + (t.z1 - t.z0 - 2) * (k - 0.5) / t.nz
			Bx(m, W, string.format("WinX_%d_%d", i, k), t.x0 - 0.15, ya, z - 0.6, t.x1 + 0.15, yb, z + 0.6, glassC, { decor = true, mat = Enum.Material.Glass })
		end
		for k = 1, (t.bands or 0) do
			local y = t.y0 + (t.y1 - t.y0) * k / (t.bands + 1)
			Bx(m, W, string.format("Band_%d_%d", i, k), t.x0 - 0.12, y, t.z0 - 0.12, t.x1 + 0.12, y + 1.2, t.z1 + 0.12, t.bandColor or rgb(226, 230, 236), { decor = true })
		end
		if t.ring then Bx(m, W, "Ring_" .. i, t.x0 - 0.2, t.y1 - 0.6, t.z0 - 0.2, t.x1 + 0.2, t.y1, t.z1 + 0.2, t.ring, { decor = true, mat = Enum.Material.Neon, noShadow = true }) end
	end
	if spire then
		vcyl(m, W, "Spire", spire[1], spire[3], spire[4], spire[2], spire[5], spire[6] or rgb(190, 196, 204), { decor = true })
		P(m, "SpireTip", CFrame.new(spire[1], spire[4] + 0.7, spire[2]), Vector3.new(1.4, 1.4, 1.4), tipC, { shape = Enum.PartType.Ball, mat = Enum.Material.Neon, decor = true })
	end
	m.Parent = Sk
	return m
end
-- Côté ouest des magasins : jusqu'à x = 777 (l'emprise commence à 778,4)
local mN2 = tower("Midrise_N2", { { x0 = 769, x1 = 777, z0 = 74, z1 = 90, y0 = 0, y1 = 72, color = rgb(150, 120, 96), nx = 2, nz = 3, from = 20 } })
Bx(mN2, W, "Cornice", 768.6, 72, 73.6, 777.4, 73.2, 90.4, iron, { decor = true })
local mS2 = tower("Midrise_S2", { { x0 = 769, x1 = 777, z0 = -90, z1 = -74, y0 = 0, y1 = 66, color = rgb(120, 112, 104), nx = 2, nz = 3, from = 20 } })
Bx(mS2, W, "Cornice", 768.6, 66, -90.4, 777.4, 67.2, -73.6, iron, { decor = true })
waterTower(mS2, 773, -82, 67.2)
tower("Tower_N6", {
	{ x0 = 768, x1 = 777, z0 = 96, z1 = 126, y0 = 0, y1 = 110, color = rgb(120, 156, 190), mat = Enum.Material.Glass, bands = 8 },
	{ x0 = 769, x1 = 776, z0 = 98, z1 = 124, y0 = 110, y1 = 114, color = capC },
}, { 772.5, 111, 114, 128, 0.6 })
tower("Tower_N7", {
	{ x0 = 756, x1 = 777, z0 = 134, z1 = 166, y0 = 0, y1 = 80, color = rgb(168, 156, 140), nx = 4, nz = 5, from = 20 },
	{ x0 = 760, x1 = 773, z0 = 138, z1 = 162, y0 = 80, y1 = 125, color = rgb(168, 156, 140), nx = 3, nz = 4, ring = neonW },
	{ x0 = 763.5, x1 = 769.5, z0 = 143, z1 = 157, y0 = 125, y1 = 150, color = gold, ring = neonW },
}, { 766.5, 150, 150, 175, 1.0, gold })
tower("Tower_S6", {
	{ x0 = 768, x1 = 777, z0 = -126, z1 = -96, y0 = 0, y1 = 70, color = sand, nx = 2, nz = 5, from = 20 },
	{ x0 = 770, x1 = 775, z0 = -123, z1 = -99, y0 = 70, y1 = 95, color = sand, nx = 1, nz = 3, ring = neonG },
}, { 772.5, -111, 95, 112, 0.8 })
tower("Tower_S7", {
	{ x0 = 756, x1 = 777, z0 = -166, z1 = -134, y0 = 0, y1 = 150, color = rgb(46, 54, 68), mat = Enum.Material.Glass, bands = 10, bandColor = capC },
	{ x0 = 759, x1 = 774, z0 = -163, z1 = -137, y0 = 150, y1 = 156, color = capC, ring = neonW },
}, { 766.5, -150, 156, 176, 0.8 })
-- Derrière les magasins : tours reculées au-delà de leur fond (|z| >= 167), terrain prolongé jusqu'à |z| = 200
local function zSpan(m)
	local mn, mx = math.huge, -math.huge
	for _, p in m:GetDescendants() do if p:IsA("BasePart") then mn = math.min(mn, p.Position.Z - p.Size.Z / 2); mx = math.max(mx, p.Position.Z + p.Size.Z / 2) end end
	return mn, mx
end
for _, it in { { "Tower_N4", 1 }, { "Tower_N5", 1 }, { "Tower_S4", -1 }, { "Tower_S5", -1 } } do
	local m = Sk:FindFirstChild(it[1])
	if m then
		local mn, mx = zSpan(m)
		local dz = (it[2] > 0) and (167 - mn) or (-167 - mx)
		m:PivotTo(m:GetPivot() + Vector3.new(0, 0, dz))
	end
end
for _, s in { 1, -1 } do
	local nm = s > 0 and "Land_N" or "Land_S"
	local l = Land:FindFirstChild(nm)
	if l then
		local zin = s * 92.5
		l.Size = Vector3.new(l.Size.X, l.Size.Y, 200 - 92.5); l.Position = Vector3.new(l.Position.X, l.Position.Y, zin + s * (200 - 92.5) / 2)
	end
end
local le = Land:FindFirstChild("Land_E"); if le then le.Size = Vector3.new(le.Size.X, le.Size.Y, 400); le.Position = Vector3.new(le.Position.X, le.Position.Y, 0) end
return "voisins des magasins rangés"
