--!nocheck
-- Zone 2 — Londres : recalage du décor autour des magasins agrandis (décision de Clément du 2026-11-17 : magasins PNJ de
-- 78 × 108, emprise x 128,4..207,6, jouets z 52,4..162,1, confiserie z −162,1..−52,4 ; outil tools/clement/store_stretch.luau).
-- Ne touche à aucun STORE_*. Travaille sur la carte telle qu'elle est (après corridor_widen.luau) avec des places
-- absolues : relançable, résultat identique. Tout ce qu'il pose porte CorridorWiden = 30 (corridor_widen n'y touche plus).
-- Ordre des scripts de la zone 2 : zone2_londres → corridor_widen → store_stretch → zone2_londres_recalage →
-- zone2_londres_ambiance → env/trees_replace.
-- Ce qu'il fait :
--  • murets du greybox raccourcis aux bandes x 118..128,4 et 207,6..230 ;
--  • maisons plaquées : retire celles qui tombent dans l'emprise (N1, N2, S1, S2), dépôt du bus et bus décalés à
--    x 207,7..218,6, arrêt de bus devant le dépôt, brique sur le bout de muret sud laissé nu ;
--  • rangées de maisons refaites dans les bandes étroites, avec une de plus le long des magasins allongés ;
--  • immeubles victoriens reculés derrière les jouets (z 166..184), square et arbres derrière eux ; sol prolongé ;
--  • grande roue refaite derrière la confiserie (elle avait été étirée par corridor_widen), quai et Tamise reculés ;
--  • arbres du pack déplacés avec leur copie dans ServerStorage/_ARBRES_REMPLACES (une relance de trees_replace les garde).

local rgb = Color3.fromRGB
local Z = workspace.Map.Zone_2
local S = Z.Street_Londres
local gz = workspace.Greybox.Corridor.Zone_2
local CW = 30
local W = CFrame.identity
local SX0, SX1, SZ0, SZ1 = 128.4, 207.6, 52.4, 162.1   -- emprise des magasins agrandis (nord ; le sud en miroir)
local Ball, Cyl, Glass, Neon = Enum.PartType.Ball, Enum.PartType.Cylinder, Enum.Material.Glass, Enum.Material.Neon

local function mark(root)
	root:SetAttribute("CorridorWiden", CW)
	for _, d in root:GetDescendants() do if d:IsA("BasePart") or d:IsA("Model") then d:SetAttribute("CorridorWiden", CW) end end
end
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
	if opt.refl then p.Reflectance = opt.refl end
	if opt.noShadow then p.CastShadow = false end
	p:SetAttribute("CorridorWiden", CW)
	p.Parent = parent
	return p
end
local function Bx(parent, name, x0, y0, z0, x1, y1, z1, color, opt)
	return P(parent, name, CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), color, opt)
end
local function bar(parent, name, a, b, thick, color, opt)
	local d = b - a
	local up = (math.abs(d.Unit.Y) > 0.99) and Vector3.xAxis or Vector3.yAxis
	return P(parent, name, CFrame.lookAt((a + b) / 2, b, up), Vector3.new(thick, thick, d.Magnitude), color, opt)
end
local function put(p, x0, y0, z0, x1, y1, z1)
	p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
end
local function shiftX(model, x)   -- place le centre de la boîte du modèle en x (relançable)
	local cf = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(x - cf.X, 0, 0))
end
local log = {}

-- 1) Greybox : murets dans les bandes libres
do
	local g = gz.Ground
	put(g.SideWall_N1, 118, 0, 60, SX0, 18, 61.5)
	put(g.SideWall_S1, 118, 0, -61.5, SX0, 18, -60)
	put(g.SideWall_N2, SX1, 0, 60, 230, 18, 61.5)
	put(g.SideWall_S2, SX1, 0, -61.5, 230, 18, -60)
end

-- 2) Maisons plaquées, dépôt, bus, arrêt de bus
do
	local H = S.Houses
	for _, nm in { "House_N1", "House_N2", "House_S1", "House_S2" } do local h = H:FindFirstChild(nm); if h then h:Destroy() end end
	for _, nm in { "DepotWall", "DepotCoping", "DepotPier_1", "DepotPier_2", "DepotSign", "WallSkin_S" } do local p = H:FindFirstChild(nm); if p then p:Destroy() end end
	local stone = rgb(200, 198, 190)
	local d0, d1 = SX1 + 0.1, 218.6
	Bx(H, "DepotWall", d0, 0, 59.85, d1, 18, 61.65, rgb(150, 62, 48), { studs = true, decor = true })
	Bx(H, "DepotCoping", d0, 18, 59.7, d1, 18.6, 61.8, stone, { studs = true, decor = true })
	for i, x in { d0 + 1.95, d0 + 8.15 } do
		Bx(H, "DepotPier_" .. i, x - 0.9, 0.45, 59.55, x + 0.9, 18.3, 59.85, rgb(176, 70, 52), { studs = true, decor = true })
	end
	local sign = Bx(H, "DepotSign", d0 + 1.35, 12.5, 59.4, d0 + 8.75, 15.2, 59.55, rgb(28, 44, 92), { decor = true })
	local g = Instance.new("SurfaceGui"); g.Name = "LabelGui_Front"; g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 40; g.LightInfluence = 0
	local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
	t.Text = "BUS DEPOT"; t.TextScaled = true; t.TextWrapped = true; t.TextColor3 = rgb(245, 245, 240)
	t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	local st = Instance.new("UIStroke"); st.Color = rgb(10, 20, 50); st.Thickness = 3; st.Parent = t
	t.Parent = g; g.Parent = sign
	-- bout de muret sud laissé nu entre l'emprise et la maison S3
	Bx(H, "WallSkin_S", SX1 + 0.1, 0, -61.65, 209, 18, -59.85, rgb(150, 62, 48), { studs = true, decor = true })
	local busX = (d0 + d1) / 2
	if S:FindFirstChild("DoubleDecker") then shiftX(S.DoubleDecker, busX) end
	local spk = S:FindFirstChild("Sounds") and S.Sounds:FindFirstChild("Speaker_BusIdle")
	if spk then spk.Position = Vector3.new(busX, spk.Position.Y, spk.Position.Z) end
	local stop = S.Props:FindFirstChild("BusStop")
	if stop then shiftX(stop, busX) end
	table.insert(log, string.format("dépôt et bus à x %.1f..%.1f", d0, d1))
end

-- 3) Rangées de maisons et immeubles (blocs simples, sans collision)
local Bk = S.Buildings
local stoneW, slate, glassD = rgb(238, 232, 218), rgb(70, 76, 88), rgb(46, 58, 80)
local function block(name, x0, x1, z0, z1, h, body, windows)
	local old = Bk:FindFirstChild(name); if old then old:Destroy() end
	local m = Instance.new("Model"); m.Name = name
	local roofTop = h + 3.5
	Bx(m, "Body", x0, 0, z0, x1, h, z1, body, { studs = true, decor = true })
	Bx(m, "Cornice", x0 - 0.4, h, z0 - 0.4, x1 + 0.4, h + 0.9, z1 + 0.4, stoneW, { decor = true })
	Bx(m, "Roof", x0 + 0.6, h + 0.9, z0 + 0.6, x1 - 0.6, roofTop, z1 - 0.6, slate, { studs = true, decor = true })
	local nCh = math.max(1, math.floor((x1 - x0) / 8))
	for k = 1, nCh do
		local cx, cz = x0 + (x1 - x0) * (k - 0.5) / nCh, (z0 + z1) / 2
		Bx(m, "Chimney_" .. k, cx - 1.4, h + 0.9, cz - 0.9, cx + 1.4, roofTop + 3.2, cz + 0.9, rgb(150, 62, 48), { studs = true, decor = true })
		for j, dx in { -0.7, 0.7 } do
			P(m, "ChimneyPot_" .. k .. "_" .. j, CFrame.new(cx + dx, roofTop + 3.75, cz) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.1, 0.75, 0.75), rgb(190, 95, 60), { shape = Cyl, decor = true, noShadow = true })
		end
	end
	if windows then
		Bx(m, "GroundBand", x0, 0, z0 - 0.15, x1, 7, z0, stoneW, { decor = true })
		local cols = math.max(1, math.floor((x1 - x0 - 1) / 4.4))
		local y, fl = 8, 0
		while y + 4 <= h - 1 do
			fl += 1
			for c = 1, cols do
				local cx = x0 + (x1 - x0) * (c - 0.5) / cols
				Bx(m, "Win_" .. fl .. "_" .. c, cx - 1.1, y, z0 - 0.12, cx + 1.1, y + 3.8, z0, glassD, { decor = true, noShadow = true })
			end
			Bx(m, "Band_" .. fl, x0, y - 0.9, z0 - 0.1, x1, y - 0.5, z0, stoneW, { decor = true, noShadow = true })
			y += 6.5
		end
	end
	mark(m)
	m.Parent = Bk
end
local WX0, WX1 = 118.5, SX0 - 0.5           -- bande ouest (derrière la tour d'horloge)
local EX0, EX1 = SX1 + 0.4, 229.5           -- bande est
local BUS1 = 218.6                          -- le bus occupe x 207,7..218,6, z 64,6..100,6 au nord
for _, t in {
	{ "Terrace_NW1", WX0, WX1, 75, 92, 28, rgb(176, 70, 52) }, { "Terrace_NW2", WX0, WX1, 93, 111, 25, rgb(236, 228, 210) },
	{ "Terrace_NW3", WX0, WX1, 112, 131, 30, rgb(140, 58, 46) }, { "Terrace_NW4", WX0, WX1, 132, 160, 27, rgb(168, 200, 230) },
	{ "Terrace_SW1", WX0, WX1, -92, -75, 27, rgb(242, 222, 150) }, { "Terrace_SW2", WX0, WX1, -111, -93, 30, rgb(160, 66, 50) },
	{ "Terrace_SW3", WX0, WX1, -131, -112, 26, rgb(170, 220, 195) }, { "Terrace_SW4", WX0, WX1, -160, -132, 29, rgb(236, 228, 210) },
	{ "Terrace_NE1", BUS1 + 0.2, EX1, 75, 102, 28, rgb(176, 70, 52) }, { "Terrace_NE2", EX0, EX1, 104, 117, 30, rgb(236, 228, 210) },
	{ "Terrace_NE3", EX0, EX1, 118, 131, 26, rgb(140, 58, 46) }, { "Terrace_NE4", EX0, EX1, 132, 160, 29, rgb(242, 222, 150) },
	{ "Terrace_SE1", EX0, EX1, -96, -75, 30, rgb(160, 66, 50) }, { "Terrace_SE2", EX0, EX1, -114, -97, 27, rgb(240, 236, 226) },
	{ "Terrace_SE3", EX0, EX1, -131, -115, 32, rgb(176, 70, 52) }, { "Terrace_SE4", EX0, EX1, -160, -132, 28, rgb(168, 200, 230) },
} do block(t[1], t[2], t[3], t[4], t[5], t[6], t[7], false) end
-- immeubles victoriens derrière les jouets agrandis (façade vers la rue, au-dessus des toits)
for i, t in { { 119, 141, 46, rgb(165, 72, 55) }, { 141, 163, 52, rgb(196, 170, 120) }, { 163, 185, 48, rgb(140, 58, 46) },
	{ 185, 207, 44, rgb(226, 218, 196) }, { 207, 229, 50, rgb(176, 82, 60) } } do
	block("Mansion_" .. i, t[1], t[2], 166, 184, t[3], t[4], true)
end

-- 4) Sol : prolongé derrière les magasins ; square et Tamise reculés
local G = S.Ground
local NB, SB = 202, -200.1                   -- fin du sol au nord, fond de la Tamise au sud
put(G.BackGround_N, 118, -2, 92.5, 230, 0, NB)
put(G.BackGround_S, 118, -2, -190.1, 230, 0, -92.5)
put(G.Embankment, 118, -0.9, -190.1, 230, 1.4, -189.3)
put(G.River, 118, -2, SB, 230, -0.9, -190.1)
put(G.GardenSquare, 122, 0, 188, 226, 0.3, 199)
for _, p in { G.BackGround_N, G.BackGround_S, G.Embankment, G.River, G.GardenSquare } do p:SetAttribute("CorridorWiden", CW) end

-- 5) Grande roue refaite derrière la confiserie agrandie
do
	local old = S:FindFirstChild("ObservationWheel"); if old then old:Destroy() end
	local M = Instance.new("Model"); M.Name = "ObservationWheel"
	local XC, back = 168, -SZ1
	local C = Vector3.new(XC, 50, back - 22)            -- axe à 22 studs derrière le magasin, pieds à 4
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
	local axleFront = C + Vector3.new(0, 0, 4.2)
	local feet = { Vector3.new(XC - 21, 0, back - 4), Vector3.new(XC + 21, 0, back - 4) }
	for k, ft in feet do
		bar(M, "Leg_" .. k, ft, axleFront, 2.2, whiteW, { decor = true })
		Bx(M, "LegFoot_" .. k, ft.X - 2, 0, ft.Z - 2, ft.X + 2, 1.2, ft.Z + 2, rgb(176, 170, 156), { studs = true, decor = true })
	end
	bar(M, "LegTie", feet[1]:Lerp(axleFront, 0.45), feet[2]:Lerp(axleFront, 0.45), 1.0, whiteW, { decor = true })
	for k, sx in { -1, 1 } do
		bar(M, "Stay_" .. k, Vector3.new(XC + sx * 12, 0.5, C.Z - 5), C + Vector3.new(0, 0, -3.8), 0.3, steel, { decor = true, noShadow = true })
	end
	Bx(M, "BoardingDeck", XC - 9, 0, C.Z - 5.2, XC + 9, 3.4, C.Z + 5.5, rgb(200, 204, 210), { studs = true, decor = true })
	Bx(M, "BoardingRoof", XC - 8, 4.9, C.Z - 4.5, XC + 8, 5.3, C.Z + 4.5, whiteW, { decor = true })
	mark(M)
	M.Parent = S
	table.insert(log, string.format("roue : axe z %.1f", C.Z))
end

-- 6) Arbres (du pack) : places absolues, copie de la réserve déplacée d'autant
do
	local stash = game:GetService("ServerStorage"):FindFirstChild("_ARBRES_REMPLACES")
	local byPath = {}
	if stash then for _, s in stash:GetDescendants() do local p = s:GetAttribute("Path"); if p then byPath[p] = s end end end
	local TARGET = {
		Tree_N1 = Vector2.new(128, 193.5), Tree_N2 = Vector2.new(147, 193.5), Tree_N3 = Vector2.new(166, 193.5),
		Tree_N4 = Vector2.new(185, 193.5), Tree_N5 = Vector2.new(204, 193.5), Tree_N6 = Vector2.new(221, 193.5),
		Tree_S1 = Vector2.new(127, -173.1), Tree_S2 = Vector2.new(138, -173.1), Tree_S3 = Vector2.new(201, -173.1), Tree_S4 = Vector2.new(218, -173.1),
	}
	local moved = 0
	for nm, tg in TARGET do
		local m = Bk:FindFirstChild(nm)
		local trunk = m and m:FindFirstChild("Trunk")
		if trunk then
			local delta = Vector3.new(tg.X - trunk.Position.X, 0, tg.Y - trunk.Position.Z)
			if delta.Magnitude > 0.01 then
				for _, p in m:GetDescendants() do if p:IsA("BasePart") then p.CFrame = p.CFrame + delta end end
				local s = byPath[m:GetFullName()]
				if s then for _, p in s:GetDescendants() do if p:IsA("BasePart") then p.CFrame = p.CFrame + delta end end end
				moved += 1
			end
			mark(m)
		end
	end
	table.insert(log, "arbres déplacés : " .. moved)
end

-- 7) Vérification : plus rien de la zone dans l'emprise des magasins agrandis (hors sol et marquages), chaussée libre
local function aabb(p)
	local cf, s = p.CFrame, p.Size
	local e = cf:VectorToWorldSpace(Vector3.new(s.X, 0, 0)):Abs() + cf:VectorToWorldSpace(Vector3.new(0, s.Y, 0)):Abs() + cf:VectorToWorldSpace(Vector3.new(0, 0, s.Z)):Abs()
	return cf.Position - e / 2, cf.Position + e / 2
end
local FLOOR = { "^Pavement_", "^Kerb_", "^BackGround_", "^Puddle_", "^ZigZag_", "^YellowLine_", "^Zebra_", "^CentreDash_" }
local inFoot, outside, onRoad = {}, 0, 0
for _, d in S:GetDescendants() do   -- décor de la zone 2 (les magasins, témoins et camion n'y sont pas)
	if d:IsA("BasePart") then
		local floor = false
		for _, f in FLOOR do if d.Name:match(f) then floor = true end end
		local lo, hi = aabb(d)
		if not floor and hi.X > SX0 + 0.05 and lo.X < SX1 - 0.05 and ((hi.Z > SZ0 + 0.05 and lo.Z < SZ1 - 0.05) or (hi.Z > -SZ1 + 0.05 and lo.Z < -SZ0 - 0.05)) then
			table.insert(inFoot, d.Parent.Name .. "/" .. d.Name)
		end
		if lo.X < 117.99 or hi.X > 230.01 then outside += 1 end
		if hi.X > 118 and lo.X < 230 and hi.Z > -46.49 and lo.Z < 46.49 and hi.Y > 0.05 and d.Transparency < 1 then onRoad += 1 end
	end
end
for _, nm in { "SideWall_N1", "SideWall_N2", "SideWall_S1", "SideWall_S2" } do
	local lo, hi = aabb(gz.Ground[nm])
	if hi.X > SX0 + 0.05 and lo.X < SX1 - 0.05 then table.insert(inFoot, nm) end
end
table.insert(log, string.format("dans l'emprise : %d%s ; hors x 118..230 : %d ; sur la chaussée : %d", #inFoot,
	#inFoot > 0 and (" (" .. table.concat(inFoot, ", ", 1, math.min(#inFoot, 8)) .. ")") or "", outside, onRoad))
return "Zone 2, recalage : " .. table.concat(log, " ; ")
