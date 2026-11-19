--!nocheck
-- Zone 3 — Tokyo : le décor laisse la place aux magasins agrandis (décision de Clément du 2026-11-17,
-- tools/clement/store_stretch.luau). Nouvelle emprise : x 252,4..331,6 (façade 246..338), |z| 52,4..162,1.
-- À lancer dans Studio (MCP execute_luau, mode Edit) sur la rue en place ; ne touche à aucun STORE_*.
-- Relançable : chaque réglage donne la même position quel que soit l'état de départ.
-- Ensuite relancer zone3_tokyo_ambience.luau (pétales calés sur les cerisiers, FX_NeonFlicker).
do
	local rgb = Color3.fromRGB
	local Z = workspace.Map.Zone_3
	local S = Z.Street_Tokyo
	local g = workspace.Greybox.Corridor.Zone_3.Ground
	local X0, X1 = 230, 368
	local BX0, BX1, BZ1 = 252.4, 331.6, 162.1      -- corps des magasins agrandis
	local XE = (X0 + BX0) / 2                        -- milieu de l'enceinte du temple (241,2)
	local function span(p, x0, x1)                   -- pièce alignée sur les axes : nouvelle étendue en x
		p.Size = Vector3.new(x1 - x0, p.Size.Y, p.Size.Z); p.Position = Vector3.new((x0 + x1) / 2, p.Position.Y, p.Position.Z)
	end
	local function moveTo(m, x)                      -- modèle déplacé en x (pivot), y et z gardés
		local pv = m:GetPivot(); m:PivotTo(pv + Vector3.new(x - pv.Position.X, 0, 0))
	end

	-- 1) Murets du greybox de la zone : ils s'arrêtent au mur du magasin
	span(g.SideWall_N1, X0, BX0); span(g.SideWall_S1, X0, BX0)
	span(g.SideWall_N2, BX1, X1); span(g.SideWall_S2, BX1, X1)

	-- 2) Entrée : enceinte raccourcie, lanternes de rue avant l'angle du magasin
	local E = S.Entrance
	for _, s in { "N", "S" } do
		for _, n in { "ShrineWall_", "ShrineWallBase_", "ShrineWallBand_", "ShrineWallCoping_" } do span(E[n .. s], X0 + 1.6, BX0 - 1) end
		moveTo(E["StreetLantern_" .. s .. "1"], 245.0)
		moveTo(E["StreetLantern_" .. s .. "2"], 249.0)
	end

	-- 3) Enceinte du temple recentrée en x 241,2 (22 studs de large) ; jardin sec ramené à 20 studs
	local T = S.Temple
	for _, n in { "Pagoda", "Shrine", "BellTower" } do moveTo(T[n], XE) end
	for n, x in { StoneLantern_N1 = XE - 8, StoneLantern_N2 = XE + 8, StoneLantern_N3 = XE - 7.5, StoneLantern_N4 = XE + 7.5,
		StoneLantern_S5 = XE - 8.5, StoneLantern_S6 = XE + 8.5 } do
		if T:FindFirstChild(n) then moveTo(T[n], x) end
	end
	for _, p in T:GetChildren() do
		if p:IsA("BasePart") then
			if p.Name == "ZenGravel" then span(p, XE - 10, XE + 10)
			elseif p.Name:match("^ZenRake_") then span(p, XE - 9.4, XE + 9.4)
			elseif p.Name == "ZenBorder_1" or p.Name == "ZenBorder_2" then span(p, XE - 10.4, XE + 10.4)
			elseif p.Name == "ZenBorder_3" then span(p, XE - 10.4, XE - 10)
			elseif p.Name == "ZenBorder_4" then span(p, XE + 10, XE + 10.4)
			end
		end
	end
	local rocks = { ZenRock_1 = -4.5, ZenRock_2 = 3.8, ZenRock_3 = -0.6, ZenRock_4 = 7.0, ZenMoss_1 = -4.5, ZenMoss_2 = 3.8, ZenMoss_3 = -0.6, ZenMoss_4 = 7.0 }
	for n, dx in rocks do local p = T:FindFirstChild(n); if p then p.Position = Vector3.new(XE + dx, p.Position.Y, p.Position.Z) end end

	-- 4) Cerisiers : ceux de l'enceinte recentrés et réduits en entier (pack : jamais resserrés en largeur),
	-- ceux de derrière les magasins retirés (le magasin prend leur place), celui du trottoir nord décalé
	local Tr = S.Trees
	for _, t in Tr:GetChildren() do
		if t.Name:match("^SakuraBig_[NS]246_") then
			moveTo(t, XE)
			local _, size = t:GetBoundingBox()
			if size.X > 21 then t:ScaleTo(t:GetScale() * 21 / size.X) end
			local c, s2 = t:GetBoundingBox()   -- recentré après réduction
			moveTo(t, t:GetPivot().Position.X + (XE - c.X))
		elseif t.Name:match("^SakuraBig_[NS]%d+_110$") then
			t:Destroy()
		elseif t.Name == "Sakura_N333" then
			moveTo(t, 335.5)
		end
	end

	-- 5) Maisons : la première de chaque côté est sous le magasin ; un passage étroit la remplace (mur et
	-- petite enseigne BAR), les distributeurs du sud passent devant le karaoké
	local H = S.Houses
	for _, n in { "House_N1", "House_S1" } do local h = H:FindFirstChild(n); if h then h:Destroy() end end
	local Pr = S.Props
	if Pr:FindFirstChild("Vending_S1") then moveTo(Pr.Vending_S1, 344.3 + 3.3) end   -- pivot au bord est (modèle tourné)
	if Pr:FindFirstChild("Vending_S2") then moveTo(Pr.Vending_S2, 347.7 + 3.3) end
	local function part(parent, name, x0, y0, z0, x1, y1, z1, color, opt)
		opt = opt or {}
		local p = Instance.new("Part"); p.Name = name; p.Anchored = true
		p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
		p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if opt.mat then p.Material = opt.mat elseif opt.studs then p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs" else p.Material = Enum.Material.SmoothPlastic end
		if opt.decor then p.CanCollide = false; p.CanTouch = false end
		if opt.noShadow then p.CastShadow = false end
		p.Parent = parent
		return p
	end
	local function label(p, face, text, color, ppS, stroke)
		local gui = Instance.new("SurfaceGui"); gui.Name = "LabelGui_" .. face.Name; gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; gui.PixelsPerStud = ppS or 40; gui.LightInfluence = 0
		local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
		t.Text = text; t.TextScaled = true; t.TextColor3 = color
		t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
		local st = Instance.new("UIStroke"); st.Color = stroke or Color3.new(0, 0, 0); st.Thickness = 3; st.Parent = t
		t.Parent = gui; gui.Parent = p
	end
	for _, s in { 1, -1 } do
		local tag = (s > 0) and "N" or "S"
		local old = H:FindFirstChild("Alley_" .. tag); if old then old:Destroy() end
		local m = Instance.new("Model"); m.Name = "Alley_" .. tag; m.Parent = H
		local zf, zb = s * 59.85, s * 61.9                -- comme les maisons : mur plaqué sur le muret
		part(m, "Wall", BX1 + 0.2, 0, zf, 337.2, 20.5, zb, rgb(58, 50, 56), { studs = true, decor = true })
		part(m, "Door", BX1 + 1.4, 0.45, zf - s * 0.08, 336.0, 9.5, zf, rgb(24, 22, 26), { decor = true })
		local sign = part(m, "BarSign", 335.6, 11, zf - s * 2.6, 336.0, 18.5, zf - s * 0.2, rgb(30, 20, 50), { decor = true })
		label(sign, Enum.NormalId.Left, "B\nA\nR", rgb(255, 120, 220), 30)
		label(sign, Enum.NormalId.Right, "B\nA\nR", rgb(255, 120, 220), 30)
		part(m, "BarSignNeon", 335.55, 10.8, zf - s * 2.85, 336.05, 18.7, zf - s * 2.6, rgb(255, 70, 180), { decor = true, mat = Enum.Material.Neon, noShadow = true })
	end

	-- 6) Ville : les immeubles qui touchaient le flanc est du magasin repartent de x 333,1, les halls de
	-- derrière deviennent de minces façades au fond du quartier (z 163,6..169,2)
	local Ci = S.City
	local fxKeep = Ci:FindFirstChild("Tower_S5") and Ci.Tower_S5:FindFirstChild("FX_NeonFlicker")
	if fxKeep then fxKeep.Parent = nil end
	local glass, warm, signDark, steel, white, red, black, gold = rgb(52, 70, 100), rgb(255, 214, 150), rgb(24, 20, 36), rgb(120, 120, 116), rgb(245, 245, 240), rgb(206, 52, 38), rgb(30, 28, 32), rgb(222, 178, 60)
	local function neon() return { decor = true, mat = Enum.Material.Neon, noShadow = true } end
	local function cyl(parent, name, x, y0, y1, z, dia, color, opt)
		local p = part(parent, name, x - (y1 - y0) / 2, (y0 + y1) / 2 - dia / 2, z - dia / 2, x + (y1 - y0) / 2, (y0 + y1) / 2 + dia / 2, z + dia / 2, color, opt)
		p.Shape = Enum.PartType.Cylinder; p.CFrame = CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90))
		return p
	end
	local function building(name, x0, z0, x1, z1, h, st)   -- même immeuble que le bloc 3 de zone3_tokyo.luau
		local old = Ci:FindFirstChild(name); if old then old:Destroy() end
		local m = Instance.new("Model"); m.Name = name; m.Parent = Ci
		local s = (z0 > 0) and 1 or -1
		local zf = (s > 0) and z0 or z1
		local face = (s > 0) and Enum.NormalId.Front or Enum.NormalId.Back
		part(m, "Body", x0, 0, z0, x1, h, z1, st.body, { studs = true })
		part(m, "ShopWindows", x0 - 0.2, 0.6, z0 - 0.2, x1 + 0.2, 3.8, z1 + 0.2, rgb(255, 236, 200), { decor = true })
		part(m, "Awning", x0 - 0.8, 4.0, z0 - 0.8, x1 + 0.8, 4.5, z1 + 0.8, st.shop, { decor = true, studs = true })
		local n = 0
		for y = 6, h - 4.5, 5 do
			n += 1
			local lit = (n % st.lit == 0)
			part(m, "Windows_" .. n, x0 - 0.15, y, z0 - 0.15, x1 + 0.15, y + 2.6, z1 + 0.15, lit and st.litColor or glass, lit and neon() or { decor = true })
		end
		part(m, "Parapet", x0 - 0.3, h, z0 - 0.3, x1 + 0.3, h + 1.2, z1 + 0.3, st.trim, { studs = true, decor = true })
		if z1 - z0 > 12 then cyl(m, "WaterTank", x1 - 4, h + 1.2, h + 5.2, (s > 0) and (z1 - 5) or (z0 + 5), 3.2, rgb(150, 150, 146), { decor = true }) end
		local ax, az, ah = x0 + 3, (s > 0) and (z1 - 2.5) or (z0 + 2.5), st.antenna or 8
		cyl(m, "Antenna", ax, h + 1.2, h + 1.2 + ah, az, 0.35, steel, { decor = true })
		local bulb = part(m, "AntennaLight", ax - 0.35, h + 1.05 + ah, az - 0.35, ax + 0.35, h + 1.75 + ah, az + 0.35, rgb(255, 40, 40), neon())
		bulb.Shape = Enum.PartType.Ball
		if st.roofSign then
			local w = math.min(18, x1 - x0 - 4)
			local cx, zs = (x0 + x1) / 2, zf + s * math.min(2.5, (z1 - z0) / 2)
			for i, dx in { -w / 2 + 1.2, w / 2 - 1.2 } do
				part(m, "SignPost_" .. i, cx + dx - 0.3, h + 1.2, zs - 0.3, cx + dx + 0.3, h + 3.2, zs + 0.3, steel, { decor = true })
			end
			local board = part(m, "RoofSign", cx - w / 2, h + 3.2, zs - 0.3, cx + w / 2, h + 3.2 + st.signH, zs + 0.3, st.signBg, { decor = true })
			label(board, face, st.roofSign, st.signText, 20, st.signStroke)
			part(m, "RoofSignNeon", cx - w / 2 - 0.25, h + 2.95, zs - 0.35, cx + w / 2 + 0.25, h + 3.2, zs + 0.35, st.signText, neon())
		end
		if st.blade then
			local bx, zo = x0 + 1.2, zf - s * 3.2
			local y0, y1 = h * 0.3, h * 0.82
			local za, zb = math.min(zf, zo), math.max(zf, zo)
			local board = part(m, "BladeSign", bx - 0.25, y0, za, bx + 0.25, y1, zb, st.bladeBg, { decor = true })
			label(board, Enum.NormalId.Left, st.blade, st.bladeText, 12, st.bladeStroke)
			label(board, Enum.NormalId.Right, st.blade, st.bladeText, 12, st.bladeStroke)
			part(m, "BladeNeon_F", bx - 0.3, y0 - 0.3, math.min(zo, zo - s * 0.3), bx + 0.3, y1 + 0.3, math.max(zo, zo - s * 0.3), st.bladeNeon, neon())
			part(m, "BladeNeon_T", bx - 0.3, y1, za, bx + 0.3, y1 + 0.3, zb, st.bladeNeon, neon())
			part(m, "BladeNeon_B", bx - 0.3, y0 - 0.3, za, bx + 0.3, y0, zb, st.bladeNeon, neon())
		end
		return m
	end
	local CX = BX1 + 1.5   -- bord ouest des immeubles de l'est
	building("Apartment_N", CX, 64, 347, 90, 33, { body = rgb(214, 198, 176), trim = rgb(150, 130, 110), shop = rgb(170, 40, 40), lit = 3, litColor = warm,
		roofSign = "SAKURA", signH = 5, signBg = signDark, signText = rgb(255, 150, 200), signStroke = rgb(90, 20, 60) })
	building("Tower_N1", CX, 96, 347, 126, 66, { body = rgb(58, 66, 84), trim = rgb(40, 44, 56), shop = rgb(30, 110, 200), lit = 4, litColor = rgb(120, 230, 255),
		blade = "H\nO\nT\nE\nL", bladeBg = signDark, bladeText = rgb(120, 230, 255), bladeStroke = rgb(0, 40, 80), bladeNeon = rgb(80, 230, 255) })
	building("Tower_N5", CX, 134, 346, 166, 84, { body = rgb(40, 44, 58), trim = rgb(30, 32, 40), shop = rgb(200, 40, 120), lit = 3, litColor = warm, antenna = 14,
		roofSign = "ANIME", signH = 6, signBg = rgb(255, 225, 60), signText = rgb(200, 30, 60), signStroke = white })
	building("Tower_S1", CX, -126, 347, -96, 60, { body = rgb(70, 60, 86), trim = rgb(46, 40, 58), shop = rgb(255, 120, 40), lit = 3, litColor = rgb(255, 120, 220),
		roofSign = "GAME", signH = 6, signBg = signDark, signText = rgb(255, 225, 60), signStroke = rgb(120, 0, 80) })
	local s5 = building("Tower_S5", CX, -166, 346, -134, 78, { body = rgb(52, 58, 70), trim = rgb(36, 40, 50), shop = rgb(60, 200, 120), lit = 4, litColor = warm, antenna = 12,
		blade = "K\nA\nR\nA\nO\nK\nE", bladeBg = rgb(30, 20, 50), bladeText = rgb(255, 120, 220), bladeStroke = rgb(60, 0, 40), bladeNeon = rgb(255, 70, 180) })
	if fxKeep then fxKeep.Parent = s5 end
	building("Hall_N", 266, 163.6, 318, 169.2, 40, { body = rgb(236, 230, 216), trim = red, shop = red, lit = 2, litColor = warm,
		roofSign = "HOTEL SAKURA", signH = 5, signBg = red, signText = white, signStroke = rgb(90, 0, 0) })
	building("Hall_S", 266, -169.2, 318, -163.6, 40, { body = rgb(200, 60, 50), trim = black, shop = rgb(255, 225, 60), lit = 2, litColor = warm,
		roofSign = "ARCADE", signH = 5, signBg = signDark, signText = rgb(80, 230, 255), signStroke = rgb(0, 40, 80) })
	-- 7) Le vigile frottait contre les coins des façades et le torii (L-248 c, 2026-11-18) : pilastres,
	-- pots de fleurs de la façade et piliers du torii deviennent du décor sans collision. Les murs de
	-- façade et les murs latéraux restent solides : le magasin reste fermé.
	for _, m in { Z.STORE_Z3_Electronique, Z.STORE_Z3_JeuxVideo } do
		for _, p in m.Facade:GetChildren() do if p:IsA("BasePart") and p.Name:match("^Pilaster") then p.CanCollide = false; p.CanTouch = false end end
		for _, p in m.Decor:GetChildren() do if p:IsA("BasePart") and p.Name:match("^Pot_") then p.CanCollide = false; p.CanTouch = false end end
	end
	for _, n in { "Pillar_N", "Pillar_S", "PillarBase_N", "PillarBase_S" } do
		local p = E.Torii:FindFirstChild(n); if p then p.CanCollide = false; p.CanTouch = false end
	end
	print("Zone 3 Tokyo : décor écarté des magasins agrandis (x 252,4..331,6, |z| 52,4..162,1)")
end
