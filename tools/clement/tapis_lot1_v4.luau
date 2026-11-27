--!nocheck
-- Lot 1 refait (v4, 27/11) d'apres le tableau des 25 tapis valide par Clement le 26/11 (« Oui, validé ») :
-- Base, Cardboard, Bronze, Silver, Supermarket. A lancer en Edit APRES tools/clement/tapis_socle.luau (colle en tete).
-- Chaque tapis : sa silhouette, son element qui bouge (Model dans Moving avec les attributs FxMotion, joue par le code),
-- ses points Fx_<Element> pour le chef VFX, sa touche unique. Face visible = +Z (vue 3/4 arriere, derriere le coureur).
local made = {}
local F = Enum.NormalId

-- ===== 1. BASE : tapis de salle de sport tout simple, sans arche =====
do
	local DARK, STEEL, STEEL2, BLUE = "#3D3F45", "#C9CED6", "#B7BBC3", "#3FA9FF"
	local m, a = socle("Base", { deck = { -3.0, 3.0, -2.7, 4.5, DARK, "Tapis_MetalBrosse" }, belt = "#FFFFFF" })
	a.box("Decor", "FloorMat", -3.8, 3.8, 0, 0.04, -4.3, 5.2, "#2B2F36", { var = "Tapis_BandeCaoutchouc" })
	a.cyl("Body", "RearRoller", 6.0, 0.62, CFrame.new(0, 0.31, 4.5), "#2B2F36")
	for side = -1, 1, 2 do
		local x0, x1 = math.min(side * 2.62, side * 3.05), math.max(side * 2.62, side * 3.05)
		a.box("Body", "Rail" .. side, x0, x1, 0.62, 1.0, -2.7, 4.5, STEEL, { var = "Tapis_MetalBrosse" })
		a.glow("Glow", "RailGlow" .. side, side * 2.84 - 0.05, side * 2.84 + 0.05, 1.0, 1.04, -2.4, 4.2, BLUE)
		for _, z in { -2.4, 4.1 } do a.box("Body", "Foot", side * 2.9 - 0.25, side * 2.9 + 0.25, 0, 0.12, z - 0.25, z + 0.25, "#2B2F36") end
		-- montants inclines, poignees
		a.p("Body", "Upright" .. side, Vector3.new(0.28, 3.7, 0.28), CFrame.new(side * 2.75, 2.85, -3.15) * CFrame.Angles(math.rad(-8), 0, 0), STEEL2, { var = "Tapis_MetalBrosse" })
		a.cyl("Body", "Handle" .. side, 1.7, 0.24, CFrame.new(side * 2.75, 4.05, -2.3) * FACE, "#2B2F36", { mat = Enum.Material.Rubber })
		a.ball("Body", "HandleEnd" .. side, 0.3, CFrame.new(side * 2.75, 4.05, -1.45), "#2B2F36")
	end
	-- capot moteur
	a.box("Body", "Hood", -3.05, 3.05, 0, 1.1, -3.75, -2.7, STEEL, { var = "Tapis_MetalBrosse" })
	a.p("Body", "HoodCover", Vector3.new(6.1, 0.15, 1.15), CFrame.new(0, 1.15, -3.2) * CFrame.Angles(math.rad(12), 0, 0), DARK)
	a.glow("Glow", "HoodGlow", -2.6, 2.6, 0.75, 0.82, -2.69, -2.66, BLUE)
	-- console inclinee vers le coureur, ecran, post-it « DAY 1 »
	local ccf = CFrame.new(0, 4.95, -3.2) * CFrame.Angles(math.rad(25), 0, 0)
	a.p("Body", "Console", Vector3.new(4.3, 0.95, 0.6), ccf, STEEL, { var = "Tapis_MetalBrosse" })
	a.p("Body", "ConsoleBezel", Vector3.new(4.45, 1.05, 0.5), ccf * CFrame.new(0, 0, -0.1), DARK)
	local screen = a.p(m, "ConsoleScreen", Vector3.new(2.3, 0.6, 0.04), ccf * CFrame.new(-0.25, 0.02, 0.31), "#14202E")
	a.label(screen, F.Back, "SPEED  6.0", "#7FE3FF", { light = 0, pps = 80, font = Enum.Font.Code })
	local postit = a.p("Decor", "PostIt", Vector3.new(0.62, 0.62, 0.02), ccf * CFrame.new(1.55, 0.04, 0.32) * CFrame.Angles(0, 0, math.rad(-8)), "#FFE45C")
	a.label(postit, F.Back, "DAY 1", "#2B2118", { font = Enum.Font.PermanentMarker, pps = 120 })
	for i, x in { -1.75, -1.45 } do
		a.cyl("Glow", "Button_" .. i, 0.06, 0.22, ccf * CFrame.new(x, 0.12, 0.32) * FACE, BLUE, { mat = Enum.Material.Neon })
	end
	-- ventilateur sous la console, souffle vers le coureur : tourne en course
	a.box("Body", "FanBox", -0.7, 0.7, 3.05, 4.45, -3.5, -3.1, DARK)
	a.cyl("Body", "FanGrille", 0.05, 1.15, CFrame.new(0, 3.75, -3.08) * FACE, "#8D96A3", { transp = 0.35 })
	local piv = Vector3.new(0, 3.75, -2.98)
	local fan = a.moving("Fan", piv, { FxMotion = "Spin", FxAxis = Vector3.zAxis, FxSpeed = 720, FxOnRun = true })
	local hub = a.cyl(fan, "FanHub", 0.12, 0.26, CFrame.new(piv) * FACE, "#2B2F36")
	for k = 0, 2 do
		a.p(fan, "FanBlade" .. k, Vector3.new(0.2, 0.42, 0.04), CFrame.new(piv) * CFrame.Angles(0, 0, math.rad(k * 120)) * CFrame.new(0, 0.27, 0) * CFrame.Angles(0, math.rad(22), 0), BLUE)
	end
	a.attach(hub, "Fx_Fan", piv)
	-- serviette sur la poignee droite, gourde a gauche
	a.p("Decor", "Towel", Vector3.new(0.12, 0.75, 0.55), CFrame.new(3.0, 3.75, -2.1), BLUE)
	a.p("Decor", "TowelStripe", Vector3.new(0.13, 0.1, 0.56), CFrame.new(3.0, 3.55, -2.1), "#FFFFFF")
	a.p("Decor", "TowelTop", Vector3.new(0.55, 0.12, 0.55), CFrame.new(2.75, 4.2, -2.1), BLUE)
	a.cyl("Decor", "BottleRing", 0.12, 0.45, CFrame.new(-2.75, 4.05, -1.75) * UP, "#2B2F36")
	a.cyl("Decor", "Bottle", 0.85, 0.36, CFrame.new(-2.75, 4.35, -1.75) * UP, BLUE, { transp = 0.15 })
	a.cyl("Decor", "BottleCap", 0.16, 0.26, CFrame.new(-2.75, 4.85, -1.75) * UP, "#F4F4F0")
	a.collider("Collision_Front", -3.1, 3.1, 0, 5.4, -3.8, -2.7)
	table.insert(made, m)
end

-- ===== 2. CARDBOARD : cage a hamster en carton (tunnel arrondi, fenetres, roue) =====
do
	local KRAFT, KRAFT2, LIGHT, TAPE, MARK = "#C8955A", "#B98549", "#E2B97E", "#8E5B2B", "#2B2118"
	local m, a = socle("Cardboard", { deck = { -3.4, 3.4, -3.0, 4.6, KRAFT }, belt = "#F3E2B8" })
	a.label(a.frame, F.Back, "THIS SIDE UP  ↑", MARK, { font = Enum.Font.PermanentMarker, rot = 180, pps = 70 })
	for side = -1, 1, 2 do
		a.box("Body", "Lip" .. side, math.min(side * 2.6, side * 3.4), math.max(side * 2.6, side * 3.4), 0.62, 0.95, -3.0, 4.6, KRAFT2)
	end
	a.box("Decor", "DeckTape", -3.42, 3.42, 0.25, 0.42, 4.58, 4.63, TAPE, { reflect = 0.12 })
	-- tunnel : arche elliptique de 12 panneaux (demi-largeur 3,35, hauteur 5,7 au-dessus du socle), de z -2,8 a 1,7
	-- tunnel arrete devant le coureur (z -0,6) : plus long, son bord coupait le coureur vu de l'arriere (captures du 27/11)
	local N, RX, RY, Y0, Z0, Z1 = 12, 3.35, 5.7, 0.62, -3.0, -0.6
	local function pt(i) local t = (i / N) * math.pi return Vector2.new(RX * math.cos(t), Y0 + RY * math.sin(t)) end
	local drawPanel
	for i = 1, N do
		local pa, pb = pt(i - 1), pt(i)
		local mid, dv = (pa + pb) / 2, pb - pa
		local ang = math.atan2(dv.Y, dv.X)
		local len = dv.Magnitude + 0.06
		local function panel(name, z0, z1, col)
			return a.p("Body", name, Vector3.new(len, 0.18, z1 - z0), CFrame.new(mid.X, mid.Y, (z0 + z1) / 2) * CFrame.Angles(0, 0, ang), col)
		end
		local col = if i % 2 == 0 then KRAFT else KRAFT2
		if i == 3 or i == 10 then
			-- fenetre decoupee : deux bouts de panneau et des bords plus clairs
			panel("Tunnel" .. i .. "_A", Z0, Z0 + 0.6, col)
			panel("Tunnel" .. i .. "_B", Z1 - 0.6, Z1, col)
			for _, z in { Z0 + 0.6, Z1 - 0.6 } do panel("WindowEdge" .. i, z - 0.03, z + 0.03, LIGHT) end
		else
			local pnl = panel("Tunnel" .. i, Z0, Z1, col)
			if i == 4 then drawPanel = { mid = mid, dv = dv, part = pnl } end
		end
		-- bord ondule a l'arriere : bande claire et cannelures
		a.p("Decor", "Rim" .. i, Vector3.new(len, 0.22, 0.05), CFrame.new(mid.X, mid.Y, Z1 + 0.02) * CFrame.Angles(0, 0, ang), LIGHT)
		for k = -1, 1, 2 do
			a.p("Decor", "Flute" .. i .. k, Vector3.new(0.04, 0.2, 0.06), CFrame.new(mid.X, mid.Y, Z1 + 0.03) * CFrame.Angles(0, 0, ang) * CFrame.new(k * len / 4, 0, 0), "#A87A44")
		end
		-- scotch sur le dessus
		if i == 6 or i == 7 then
			a.p("Decor", "TopTape" .. i, Vector3.new(len * 0.4, 0.2, Z1 - Z0 + 0.04), CFrame.new(mid.X, mid.Y, (Z0 + Z1) / 2) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 0.01, 0), TAPE, { reflect = 0.12 })
		end
	end
	a.attach(a.frame, "Fx_Tunnel", Vector3.new(0, 6.15, -1.8))
	-- hamster dessine au feutre sur le 4e panneau (cote droit, vu de l'arriere)
	do
		local n = Vector3.new(drawPanel.dv.Y, -drawPanel.dv.X, 0).Unit
		local upv = Vector3.new(drawPanel.dv.X, drawPanel.dv.Y, 0).Unit
		local pos = Vector3.new(drawPanel.mid.X, drawPanel.mid.Y, -1.8) + n * 0.1
		local board = a.p("Decor", "HamsterDrawing", Vector3.new(2.2, 1.15, 0.02), CFrame.lookAt(pos, pos + n, upv), KRAFT, { transp = 1 })
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Drawing"
		sg.Face = F.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 120
		sg.LightInfluence = 1
		local function blob(nm, x, y, w, h, filled, col)
			local f = Instance.new("Frame")
			f.Name = nm
			f.Position = UDim2.fromScale(x, y)
			f.Size = UDim2.fromScale(w, h)
			f.BackgroundColor3 = Color3.fromHex(col or MARK)
			f.BackgroundTransparency = if filled then 0 else 1
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
			if not filled then
				local s = Instance.new("UIStroke")
				s.Color = Color3.fromHex(MARK)
				s.Thickness = 11
				s.Parent = f
			end
			f.Parent = sg
		end
		blob("Body", 0.22, 0.32, 0.42, 0.58, true, "#F1DDB8")
		blob("BodyLine", 0.22, 0.32, 0.42, 0.58)
		blob("Head", 0.55, 0.2, 0.22, 0.48, true, "#F1DDB8")
		blob("HeadLine", 0.55, 0.2, 0.22, 0.48)
		blob("EarL", 0.57, 0.1, 0.06, 0.16)
		blob("EarR", 0.68, 0.08, 0.06, 0.16)
		blob("Eye", 0.69, 0.34, 0.03, 0.07, true)
		blob("Nose", 0.765, 0.42, 0.025, 0.05, true, "#E26D8E")
		blob("Cheek", 0.62, 0.48, 0.05, 0.08, true, "#F0A3B5")
		blob("FootL", 0.3, 0.86, 0.07, 0.1)
		blob("FootR", 0.5, 0.86, 0.07, 0.1)
		blob("Tail", 0.2, 0.55, 0.04, 0.07)
		local t = Instance.new("TextLabel")
		t.Name = "Name"
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.0, 0.0)
		t.Size = UDim2.fromScale(0.34, 0.26)
		t.Font = Enum.Font.PermanentMarker
		t.Text = "HAMMY"
		t.TextScaled = true
		t.TextColor3 = Color3.fromHex(MARK)
		t.Rotation = -8
		t.Parent = sg
		sg.Parent = board
	end
	-- console en carton au bout du tunnel, ecran dessine au feutre
	a.cyl("Body", "ConsoleTube", 2.6, 0.55, CFrame.new(0, 1.95, -2.55) * UP, KRAFT2)
	local cons = a.box("Body", "Console", -1.35, 1.35, 3.25, 4.25, -2.85, -2.3, KRAFT)
	a.label(cons, F.Back, "SPEED: FAST!!", MARK, { font = Enum.Font.PermanentMarker, pps = 70 })
	a.box("Decor", "ConsoleTape", -0.15, 0.15, 3.23, 4.27, -2.87, -2.28, TAPE, { reflect = 0.12 })
	-- roue de hamster en carton a droite : tourne en course
	local C, R = Vector3.new(5.0, 2.75, -0.3), 2.25
	local wheel = a.moving("HamsterWheel", C, { FxMotion = "Spin", FxAxis = Vector3.xAxis, FxSpeed = 120, FxOnRun = true })
	for _, x in { 4.5, 5.5 } do
		local S = 14
		for k = 0, S - 1 do
			local t0, t1 = k / S * 2 * math.pi, (k + 1) / S * 2 * math.pi
			local pa = Vector3.new(x, C.Y + R * math.sin(t0), C.Z + R * math.cos(t0))
			local pb = Vector3.new(x, C.Y + R * math.sin(t1), C.Z + R * math.cos(t1))
			a.seg(wheel, "Rim" .. k, pa, pb + (pb - pa).Unit * 0.05, 0.22, 0.12, if k % 2 == 0 then KRAFT else KRAFT2, Vector3.xAxis)
		end
		for k = 0, 3 do
			a.p(wheel, "Spoke", Vector3.new(0.1, R, 0.16), CFrame.new(x, C.Y, C.Z) * CFrame.Angles(math.rad(k * 90 + 45), 0, 0) * CFrame.new(0, R / 2, 0), LIGHT)
		end
	end
	for k = 0, 9 do
		local t = k / 10 * 2 * math.pi
		a.cyl(wheel, "Rung" .. k, 1.0, 0.13, CFrame.new(5.0, C.Y + (R - 0.05) * math.sin(t), C.Z + (R - 0.05) * math.cos(t)), "#A87A44")
	end
	local whub = a.cyl(wheel, "WheelHub", 1.3, 0.45, CFrame.new(C), TAPE)
	a.attach(whub, "Fx_Wheel", C)
	-- pied en A et axe (fixes)
	a.cyl("Body", "Axle", 0.45, 0.25, CFrame.new(5.75, C.Y, C.Z), KRAFT2)
	for _, z in { -1.7, 1.1 } do a.seg("Body", "WheelLeg", Vector3.new(5.95, 0, z), Vector3.new(5.95, C.Y + 0.1, C.Z), 0.3, 0.18, KRAFT2, Vector3.xAxis) end
	a.box("Body", "WheelFoot", 5.75, 6.15, 0, 0.12, -1.9, 1.3, KRAFT2)
	-- deux cartons scotches aux coins avant, dont un FRAGILE
	for side = -1, 1, 2 do
		local cf = CFrame.new(side * 4.6, 0.6, -3.6) * CFrame.Angles(0, math.rad(side * 8), 0)
		a.p("Decor", "Box" .. side, Vector3.new(1.3, 1.2, 1.2), cf, KRAFT)
		a.p("Decor", "BoxTape" .. side, Vector3.new(0.25, 1.24, 1.24), cf, TAPE, { reflect = 0.12 })
		if side < 0 then
			local lab = a.p("Decor", "FragileLabel", Vector3.new(0.85, 0.4, 0.02), cf * CFrame.new(0.3, 0.1, 0.61), "#F4F1EA")
			a.label(lab, F.Back, "FRAGILE", "#D8343C", { pps = 90 })
		end
	end
	a.collider("Collision_Wheel", 4.4, 6.2, 0, 5.1, -2.7, 2.1)
	table.insert(made, m)
end

-- ===== 3. BRONZE : podium de medailles, on court sur la marche n° 3 =====
do
	local WHITE, BRZ, BRZ_L, DARK, BOARD = "#F4F1EA", "#A85E26", "#C98444", "#5A3418", "#23262D"
	local m, a = socle("Bronze", { deck = { -3.1, 3.1, -3.4, 4.6, WHITE }, belt = "#FFD2A6" })
	a.label(a.frame, F.Back, "3RD", BRZ, { pps = 70 })
	for side = -1, 1, 2 do
		a.box("Body", "Edge" .. side, math.min(side * 2.6, side * 3.1), math.max(side * 2.6, side * 3.1), 0.62, 1.0, -3.4, 4.6, BRZ)
	end
	-- marches 1 (gauche, la plus haute) et 2 (droite)
	local function step(name, x0, x1, h, num)
		local s = a.box("Body", name, x0, x1, 0, h, -3.4, 1.6, WHITE)
		a.box("Body", name .. "Top", x0 - 0.05, x1 + 0.05, h - 0.12, h, -3.45, 1.65, BRZ_L)
		local plate = a.box("Decor", name .. "Number", (x0 + x1) / 2 - 0.8, (x0 + x1) / 2 + 0.8, h / 2 - 0.8, h / 2 + 0.8, 1.6, 1.63, WHITE)
		a.label(plate, F.Back, num, BRZ, { pps = 60 })
		return s
	end
	step("Step1", -6.2, -3.1, 3.0, "1")
	step("Step2", 3.1, 6.2, 2.0, "2")
	-- tableau des scores devant le coureur
	for side = -1, 1, 2 do a.box("Body", "BoardPost" .. side, side * 2.85 - 0.15, side * 2.85 + 0.15, 0, 8.6, -4.35, -4.05, BRZ) end
	local board = a.box("Body", "ScoreBoard", -2.7, 2.7, 3.3, 6.0, -4.3, -4.1, BOARD)
	a.box("Body", "BoardFrame", -2.8, 2.8, 3.2, 6.1, -4.32, -4.28, BRZ_L)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Scores"
	sg.Face = F.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0.3
	for i, row in { { "1.  ???", "#E8E6E1" }, { "2.  ???", "#E8E6E1" }, { "3.  YOU!", "#FF9A3C" } } do
		local t = Instance.new("TextLabel")
		t.Name = "Row" .. i
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.08, 0.06 + (i - 1) * 0.3)
		t.Size = UDim2.fromScale(0.84, 0.27)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = row[1]
		t.TextColor3 = Color3.fromHex(row[2])
		t.Parent = sg
	end
	sg.Parent = board
	a.box("Body", "TopBar", -3.0, 3.0, 8.35, 8.65, -4.35, -4.05, BRZ)
	a.box("Body", "Hook", -0.08, 0.08, 7.95, 8.35, -3.68, -3.52, DARK)
	-- grosse medaille de bronze suspendue : tourne sur elle-meme
	local MC = Vector3.new(0, 7.0, -3.6)
	local medal = a.moving("Medal", MC, { FxMotion = "Spin", FxAxis = Vector3.yAxis, FxSpeed = 90, FxOnRun = false })
	a.cyl(medal, "MedalRim", 0.16, 1.65, CFrame.new(MC) * FACE, DARK)
	local disc = a.cyl(medal, "MedalDisc", 0.22, 1.45, CFrame.new(MC) * FACE, BRZ)
	a.cyl(medal, "MedalCore", 0.26, 0.95, CFrame.new(MC) * FACE, BRZ_L)
	for _, face in { F.Back, F.Front } do
		local sq = a.p(medal, "MedalNumber", Vector3.new(0.7, 0.7, 0.28), CFrame.new(MC), BRZ, { transp = 1 })
		a.label(sq, face, "3", DARK, { pps = 100 })
	end
	for side = -1, 1, 2 do
		a.seg(medal, "Ribbon" .. side, MC + Vector3.new(side * 0.25, 0.72, 0), Vector3.new(side * 0.05, 7.98, -3.6), 0.3, 0.05,
			if side < 0 then "#D8343C" else "#F4F1EA", Vector3.zAxis)
	end
	a.attach(disc, "Fx_Medal", MC)
	-- touche unique : petit trophee « 3rd » cabosse sur la marche 2
	local T = CFrame.new(4.65, 2.0, -0.6) * CFrame.Angles(0, math.rad(-20), math.rad(9))
	local tb = a.p("Decor", "TrophyBase", Vector3.new(0.8, 0.32, 0.8), T * CFrame.new(0, 0.16, 0), DARK)
	a.label(tb, F.Back, "3rd", BRZ_L, { pps = 120 })
	a.cyl("Decor", "TrophyStem", 0.45, 0.18, T * CFrame.new(0, 0.55, 0) * UP, BRZ_L)
	a.cyl("Decor", "TrophyCupLow", 0.25, 0.4, T * CFrame.new(0, 0.85, 0) * UP, BRZ_L)
	a.cyl("Decor", "TrophyCup", 0.45, 0.62, T * CFrame.new(0, 1.18, 0) * UP, BRZ_L)
	for side = -1, 1, 2 do a.p("Decor", "TrophyHandle" .. side, Vector3.new(0.08, 0.32, 0.08), T * CFrame.new(side * 0.38, 1.18, 0), BRZ) end
	a.ball("Decor", "TrophyDent", 0.22, T * CFrame.new(0.18, 1.28, 0.24), "#7A4A22")
	-- couronnes de laurier autour des numeros 1 et 2, fanions sur mats, guirlande sous la barre du haut
	for _, s in { { -4.65, 1.5 }, { 4.65, 1.0 } } do
		for k = 1, 11 do -- ouverte en bas
			local t = math.rad(-90 + k * 30)
			a.p("Decor", "Laurel" .. k, Vector3.new(0.18, 0.42, 0.04), CFrame.new(s[1] + math.cos(t), s[2] + math.sin(t), 1.66) * CFrame.Angles(0, 0, t + math.rad(if k <= 6 then -35 else 35)), if k % 2 == 0 then "#4E8A3A" else "#6BAA4A")
		end
	end
	for _, s in { { -4.65, 3.0, "#D8343C" }, { 4.65, 2.0, "#F4F1EA" } } do
		local x, h = s[1], s[2]
		local dir = if x < 0 then 1 else -1
		a.p("Decor", "FlagPole", Vector3.new(0.12, 2.6, 0.12), CFrame.new(x + 1.1, h + 1.3, -2.9), DARK)
		a.p("Decor", "FlagTop", Vector3.new(0.22, 0.22, 0.22), CFrame.new(x + 1.1, h + 2.65, -2.9), BRZ_L)
		a.p("Decor", "Flag", Vector3.new(0.05, 0.8, 1.1), CFrame.new(x + 1.1 + dir * 0.55, h + 2.1, -2.9) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, if dir > 0 then 0 else math.rad(180), 0), s[3], { wedge = true })
	end
	for side = -1, 1, 2 do
		for k = 0, 3 do
			local sag = 8.25 - 0.08 * math.sin((k + 0.5) / 4 * math.pi)
			a.p("Decor", "Bunting" .. side .. k, Vector3.new(0.05, 0.45, 0.4), CFrame.new(side * (0.75 + k * 0.55), sag - 0.22, -4.0) * CFrame.Angles(0, math.rad(90), math.rad(180)), ({ "#D8343C", BRZ_L, WHITE, "#2D5BD7" })[k + 1], { wedge = true })
		end
		a.p("Decor", "BuntingRope" .. side, Vector3.new(2.3, 0.04, 0.04), CFrame.new(side * 1.85, 8.25, -4.0), DARK)
	end
	a.collider("Collision_Step1", -6.2, -3.1, 0, 3.0, -3.4, 1.6)
	a.collider("Collision_Step2", 3.1, 6.2, 0, 2.0, -3.4, 1.6)
	a.collider("Collision_Board", -3.0, 3.0, 0, 8.65, -4.4, -4.0)
	table.insert(made, m)
end

-- ===== 4. SILVER : grande coupe d'argent, ses anses encadrent le coureur =====
do
	local MARBLE, AG, AGD, CYAN = "#F2F2F4", "#D9DEE6", "#9AA3AF", "#9BE8FF"
	local m, a = socle("Silver", { deck = { -3.1, 3.1, -2.6, 4.6, MARBLE, "Tapis_MarbreVeine" }, belt = "#E6FBFF" })
	for side = -1, 1, 2 do
		a.box("Body", "Rail" .. side, math.min(side * 2.6, side * 3.1), math.max(side * 2.6, side * 3.1), 0.62, 1.0, -2.6, 4.6, AG, { reflect = 0.05 })
		a.glow("Glow", "RailGlow" .. side, side * 2.85 - 0.05, side * 2.85 + 0.05, 1.0, 1.04, -2.3, 4.3, CYAN)
	end
	-- socle de marbre et plaque
	a.box("Body", "Pedestal", -2.6, 2.6, 0, 1.3, -6.9, -2.7, MARBLE, { var = "Tapis_MarbreVeine" })
	a.box("Body", "PedestalTop", -2.75, 2.75, 1.3, 1.5, -7.05, -2.55, AG, { reflect = 0.05 })
	local plaque = a.box("Decor", "Plaque", -1.3, 1.3, 0.4, 1.0, -2.7, -2.66, AGD)
	a.label(plaque, F.Back, "SILVER CUP", "#F4F6FA", { pps = 80 })
	-- la coupe
	local CX, CZ = 0, -4.8
	local function disc(name, y, dia, len, col, o) return a.cyl("Body", name, len, dia, CFrame.new(CX, y, CZ) * UP, col, o) end
	disc("CupFoot", 1.675, 3.0, 0.35, AG, { reflect = 0.06 })
	disc("CupFoot2", 1.98, 2.2, 0.3, AGD)
	disc("CupStem", 2.8, 0.8, 1.4, AG, { reflect = 0.06 })
	a.ball("Body", "CupKnot", 1.1, CFrame.new(CX, 2.9, CZ), AG, { reflect = 0.06 })
	for i, r in { { 3.65, 1.6 }, { 4.2, 2.6 }, { 4.8, 3.4 }, { 5.45, 4.0 }, { 6.15, 4.4 }, { 6.85, 4.6 } } do
		disc("CupBowl" .. i, r[1], r[2], 0.72, AG, { reflect = 0.06 })
	end
	disc("CupBand", 5.45, 4.08, 0.18, AGD)
	disc("CupRim", 7.3, 4.8, 0.2, AGD)
	disc("CupInside", 7.41, 4.4, 0.04, "#7E8794")
	-- anses : deux grands arcs (plan x = +-2,9) qui viennent vers le coureur
	for side = -1, 1, 2 do
		local x = side * 2.9
		local S = 10
		local prev
		for k = 0, S do
			local phi = math.rad(90 - k * 180 / S)
			local pnt = Vector3.new(x, 4.6 + 2.5 * math.sin(phi), -3.2 + 2.4 * math.cos(phi))
			if prev then a.seg("Body", "Handle" .. side .. "_" .. k, prev, pnt + (pnt - prev).Unit * 0.08, 0.36, 0.36, AG, Vector3.xAxis, { reflect = 0.06 }) end
			prev = pnt
		end
		a.seg("Body", "HandleTop" .. side, Vector3.new(side * 2.25, 6.9, -4.2), Vector3.new(x, 7.1, -3.2), 0.32, 0.32, AG, Vector3.yAxis)
		a.seg("Body", "HandleLow" .. side, Vector3.new(side * 0.7, 3.65, -4.4), Vector3.new(x, 2.1, -3.2), 0.32, 0.32, AG, Vector3.yAxis)
		a.ball("Glow", "HandleGem" .. side, 0.35, CFrame.new(x, 4.6, -0.8), CYAN, { mat = Enum.Material.Neon })
	end
	-- l'etoile d'argent au-dessus de la coupe : tourne et flotte
	local SC = Vector3.new(CX, 8.75, CZ)
	local star = a.moving("Star", SC, { FxMotion = "Spin,Bob", FxAxis = Vector3.yAxis, FxSpeed = 60, FxAmplitude = 0.25, FxPeriod = 2.2, FxOnRun = false })
	local core = a.cyl(star, "StarCore", 0.28, 0.72, CFrame.new(SC) * FACE, AG, { reflect = 0.1 })
	for k = 0, 4 do
		local r = CFrame.new(SC) * CFrame.Angles(0, 0, math.rad(k * 72))
		a.p(star, "StarArm" .. k, Vector3.new(0.4, 0.62, 0.22), r * CFrame.new(0, 0.55, 0), AG, { reflect = 0.1 })
		a.p(star, "StarTip" .. k, Vector3.new(0.28, 0.28, 0.2), r * CFrame.new(0, 0.86, 0) * CFrame.Angles(0, 0, math.rad(45)), "#F4F6FA", { reflect = 0.1 })
	end
	a.cyl(star, "StarRing", 0.06, 0.95, CFrame.new(SC) * CFrame.new(0, 0, 0.16) * FACE, CYAN, { mat = Enum.Material.Neon })
	a.attach(core, "Fx_Star", SC)
	-- touche unique : chiffon et flacon de POLISH au pied de la coupe
	a.p("Decor", "ClothTop", Vector3.new(0.9, 0.06, 0.7), CFrame.new(2.25, 1.53, -2.85) * CFrame.Angles(0, math.rad(12), 0), "#6FA8DC")
	a.p("Decor", "ClothHang", Vector3.new(0.85, 0.55, 0.06), CFrame.new(2.3, 1.27, -2.5) * CFrame.Angles(math.rad(-8), math.rad(12), 0), "#6FA8DC")
	local B = CFrame.new(3.75, 0, -2.0) * CFrame.Angles(0, math.rad(-25), 0)
	a.cyl("Decor", "PolishBottle", 1.0, 0.48, B * CFrame.new(0, 0.5, 0) * UP, "#F4F6FA")
	local pl = a.p("Decor", "PolishLabel", Vector3.new(0.4, 0.4, 0.02), B * CFrame.new(0, 0.5, 0.245), "#3E7BD6")
	a.label(pl, F.Back, "POLISH", "#FFFFFF", { pps = 150 })
	a.p("Decor", "PolishHead", Vector3.new(0.3, 0.3, 0.45), B * CFrame.new(0, 1.12, 0.05), "#3E7BD6")
	a.p("Decor", "PolishNozzle", Vector3.new(0.12, 0.12, 0.2), B * CFrame.new(0, 1.18, 0.35), "#3E7BD6")
	a.p("Decor", "PolishTrigger", Vector3.new(0.08, 0.28, 0.08), B * CFrame.new(0, 0.9, 0.2), "#2B2F36")
	a.collider("Collision_Cup", -2.8, 2.8, 0, 7.5, -7.1, -2.5)
	table.insert(made, m)
end

-- ===== 5. SUPERMARKET : caisse de supermarche, la bande est le tapis de caisse =====
do
	local W, RED, STEEL, DARKG, YEL, GREEN = "#EDEBE6", "#D8343C", "#C9CED6", "#3D3F45", "#F3D35A", "#3FD46A"
	local m, a = socle("Supermarket", { deck = { -3.1, 3.1, -3.6, 4.6, DARKG }, belt = "#F2F2F2" })
	for side = -1, 1, 2 do
		a.box("Body", "Lip" .. side, math.min(side * 2.6, side * 3.2), math.max(side * 2.6, side * 3.2), 0.62, 1.2, -3.6, 4.6, STEEL, { var = "Tapis_MetalBrosse" })
		a.box("Body", "Skirt" .. side, math.min(side * 3.1, side * 3.25), math.max(side * 3.1, side * 3.25), 0.05, 0.62, -3.6, 4.6, W)
		a.box("Decor", "SkirtStripe" .. side, math.min(side * 3.24, side * 3.27), math.max(side * 3.24, side * 3.27), 0.22, 0.42, -3.6, 4.6, RED)
	end
	local rear = a.box("Decor", "RearSign", -2.4, 2.4, 0.08, 0.55, 4.6, 4.63, RED)
	a.label(rear, F.Back, "THANK YOU!", "#FFFFFF", { pps = 70 })
	-- poste de la caissiere a gauche
	a.box("Body", "CashierDesk", -6.2, -3.25, 0, 2.4, -3.6, 0.6, W)
	a.box("Decor", "DeskStripe", -6.21, -3.24, 1.55, 1.85, -3.61, 0.61, RED)
	a.box("Body", "DeskTop", -6.3, -3.15, 2.4, 2.55, -3.7, 0.7, STEEL, { var = "Tapis_MetalBrosse" })
	a.cyl("Body", "ScreenPole", 1.0, 0.16, CFrame.new(-5.3, 3.05, -2.6) * UP, DARKG)
	local scr = a.p("Body", "RegisterScreen", Vector3.new(1.5, 0.95, 0.12), CFrame.new(-5.3, 3.95, -2.6) * CFrame.Angles(0, math.rad(35), 0), "#1B2027")
	a.label(scr, F.Back, "TOTAL\n$12.99", GREEN, { light = 0, font = Enum.Font.Code, pps = 80 })
	a.box("Body", "Keypad", -5.1, -4.3, 2.55, 2.68, -1.3, -0.7, DARKG)
	a.box("Body", "CashDrawer", -5.9, -3.9, 1.95, 2.35, 0.55, 0.62, "#2B2F36")
	-- scanner : vitre et laser rouge
	a.box("Body", "ScannerGlass", -4.4, -3.4, 2.55, 2.58, -1.95, -1.25, "#2B3440", { mat = Enum.Material.Glass, transp = 0.2 })
	a.glow("Glow", "ScannerLaser", -4.35, -3.45, 2.585, 2.6, -1.62, -1.58, "#FF2A2A")
	a.box("Body", "ScannerTower", -4.4, -3.4, 2.55, 3.3, -2.15, -1.95, DARKG)
	a.attach(a.frame, "Fx_Scanner", Vector3.new(-3.9, 2.65, -1.6))
	-- petit tapis des produits le long du comptoir : les produits defilent (Beam natif, sans code)
	a.box("Body", "ProductsBelt", -4.3, -3.5, 2.55, 2.6, -3.5, 0.55, "#1B1C20", { mat = Enum.Material.Rubber })
	local strip = a.box("Moving", "ProductsStrip", -4.3, -3.5, 2.6, 2.61, -3.5, 0.55, "#1B1C20", { transp = 1 })
	local a0 = a.attach(strip, "Fx_Products", Vector3.new(-3.9, 2.95, 0.5))
	local a1 = a.attach(strip, "ProductsEnd", Vector3.new(-3.9, 2.95, -3.4))
	local beam = Instance.new("Beam")
	beam.Name = "ProductsBeam"
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = 0.7, 0.7
	beam.Texture = "rbxassetid://111084901059855" -- provisoire : etiquettes de prix ; texture des produits a faire (chef VFX)
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = 1.4
	beam.TextureSpeed = 0.6
	beam.LightInfluence = 1
	beam:SetAttribute("TextureAttendue", "FX_Treadmill_Products (planche de produits, chef VFX)")
	beam.Parent = strip
	strip:SetAttribute("FxNative", "Beam") -- mouvement natif : pas de FxMotion, le code n'a rien a faire
	-- quelques produits poses apres le scanner
	a.box("Decor", "Cereal", -4.25, -3.75, 2.55, 3.3, -3.25, -2.95, "#E8A33A")
	a.box("Decor", "CerealFace", -4.2, -3.8, 2.75, 3.15, -2.95, -2.93, "#D8343C")
	a.box("Decor", "Milk", -3.75, -3.4, 2.55, 3.15, -2.75, -2.4, "#F4F6FA")
	a.box("Decor", "MilkCap", -3.65, -3.5, 3.15, 3.25, -2.65, -2.5, "#2D5BD7")
	a.cyl("Decor", "Can", 0.4, 0.3, CFrame.new(-4.05, 2.75, -2.45) * UP, GREEN)
	-- numero de caisse lumineux
	a.cyl("Body", "LanePole", 6.4, 0.18, CFrame.new(-3.45, 3.2, -3.95) * UP, STEEL)
	local lane = a.box("Body", "LaneBox", -3.9, -3.0, 6.4, 7.3, -4.2, -3.7, W)
	for _, face in { F.Back, F.Front } do a.label(lane, face, "3", GREEN, { light = 0, pps = 60 }) end
	a.glow("Glow", "LaneTop", -3.9, -3.0, 7.3, 7.38, -4.2, -3.7, GREEN)
	-- presentoir a bonbons a droite, devant
	a.box("Body", "CandyRack", 3.4, 4.9, 0, 2.3, -3.5, -3.3, RED)
	for k = 0, 2 do
		local y = 0.4 + k * 0.7
		a.box("Body", "CandyShelf" .. k, 3.4, 4.9, y, y + 0.05, -3.3, -2.8, STEEL)
		local cols = { "#2D5BD7", YEL, "#7B4FC9", GREEN }
		for j = 0, 3 do
			a.box("Decor", "Candy" .. k .. j, 3.5 + j * 0.35, 3.78 + j * 0.35, y + 0.05, y + 0.5, -3.25, -2.9, cols[(k + j) % 4 + 1])
		end
	end
	-- touche unique : le caddie, avec un poireau qui depasse
	local cart = CFrame.new(4.9, 0, 3.5) * CFrame.Angles(0, math.rad(-20), 0)
	local function cp(n, s, off, col, o) return a.p("Decor", n, s, cart * off, col, o) end
	cp("CartBottom", Vector3.new(1.1, 0.06, 1.6), CFrame.new(0, 0.6, 0), STEEL, { var = "Tapis_MetalBrosse" })
	for side = -1, 1, 2 do
		cp("CartSide" .. side, Vector3.new(0.05, 0.8, 1.6), CFrame.new(side * 0.55, 1.0, 0), STEEL, { var = "Tapis_MetalBrosse" })
	end
	cp("CartFront", Vector3.new(1.1, 0.8, 0.05), CFrame.new(0, 1.0, -0.8), STEEL, { var = "Tapis_MetalBrosse" })
	cp("CartBack", Vector3.new(1.1, 0.8, 0.05), CFrame.new(0, 1.0, 0.8), STEEL, { var = "Tapis_MetalBrosse" })
	cp("CartHandle", Vector3.new(1.2, 0.12, 0.12), CFrame.new(0, 1.55, 1.0), RED)
	for k, q in { { -0.42, -0.65 }, { 0.42, -0.65 }, { -0.42, 0.65 }, { 0.42, 0.65 } } do
		a.cyl("Decor", "Wheel" .. k, 0.08, 0.22, cart * CFrame.new(q[1], 0.11, q[2]), "#3D3F45")
		cp("Leg" .. k, Vector3.new(0.05, 0.45, 0.05), CFrame.new(q[1], 0.38, q[2]), "#8D96A3")
	end
	cp("Bag", Vector3.new(0.55, 0.55, 0.45), CFrame.new(-0.15, 0.9, 0.25), "#C9A36B")
	cp("BoxBlue", Vector3.new(0.38, 0.5, 0.28), CFrame.new(0.25, 0.88, -0.35), "#2D5BD7")
	local leek = cart * CFrame.new(0.2, 1.35, 0.1) * CFrame.Angles(math.rad(-25), 0, math.rad(-20))
	a.cyl("Decor", "LeekStalk", 1.5, 0.24, leek * UP, "#F4F4E8")
	a.cyl("Decor", "LeekRoots", 0.08, 0.26, leek * CFrame.new(0, -0.76, 0) * UP, "#D9CBA0")
	for k = -1, 1 do
		a.p("Decor", "LeekLeaf" .. k, Vector3.new(0.22, 0.85, 0.05), leek * CFrame.new(k * 0.06, 1.15, 0) * CFrame.Angles(0, math.rad(k * 35), math.rad(k * 18)), "#3E9E3A")
	end
	a.collider("Collision_Desk", -6.3, -3.15, 0, 2.6, -3.7, 0.7)
	a.collider("Collision_Cart", 4.2, 5.6, 0, 1.6, 2.6, 4.4)
	table.insert(made, m)
end

return summary(made)
