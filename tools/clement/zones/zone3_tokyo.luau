--!nocheck
-- Zone 3 — Tokyo (MOD-021) : magasin d'électronique, magasin de jeux vidéo et décor de rue.
-- À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS tools/clement/store_builder.luau.
-- Relançable : les modèles du même nom sont remplacés. Trois blocs, à envoyer ensemble ou un par un
-- (le bloc 1 pose _G.ClaudeTokyo, lu par le bloc 2) :
--   1) façade de temple et habillage intérieur ; 2) greybox et magasins ; 3) rue Map/Zone_3/Street_Tokyo.
-- Règles : aucun script laissé dans la map ; aucun nom du contrat 10.4 réutilisé pour le décor
-- (le code cherche « Shutter » en profondeur) ; aucune marque réelle sur les enseignes ni les produits.

------------------------------------------------------------------------------------------------
-- BLOC 1 : façade de temple (toits de tuiles incurvés, poutres rouges, lanternes, néons) et intérieur
------------------------------------------------------------------------------------------------
do
	local rgb = Color3.fromRGB
	local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

	-- Écran (décor) : image en dégradé, légende facultative, ou mur d'écrans (grid = { cols, rows, { {a, b}, ... } }).
	local function screenGui(part, face, sc)
		local g = Instance.new("SurfaceGui"); g.Name = "ScreenGui_" .. face.Name; g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 30; g.LightInfluence = 0
		local function picture(parent, a, b, size, pos)
			local f = Instance.new("Frame"); f.Name = "Picture"; f.BorderSizePixel = 0; f.BackgroundColor3 = Color3.new(1, 1, 1)
			f.Size = size; f.Position = pos
			local gr = Instance.new("UIGradient"); gr.Rotation = sc.rot or 90; gr.Color = ColorSequence.new(a, b); gr.Parent = f
			f.Parent = parent
			return f
		end
		if sc.grid then
			local cols, rows = sc.grid[1], sc.grid[2]
			for i, c in sc.grid[3] do
				local cx, cy = (i - 1) % cols, math.floor((i - 1) / cols)
				if cy < rows then
					picture(g, c[1], c[2], UDim2.new(1 / cols, -8, 1 / rows, -8), UDim2.new(cx / cols, 4, cy / rows, 4))
				end
			end
		else
			local f = picture(g, sc.a, sc.b, UDim2.new(1, -10, 1, -10), UDim2.fromOffset(5, 5))
			if sc.text then
				local t = Instance.new("TextLabel"); t.Name = "Caption"; t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(0.86, 0.66); t.Position = UDim2.fromScale(0.07, 0.17)
				t.Text = sc.text; t.TextScaled = true; t.TextColor3 = sc.textColor or Color3.new(1, 1, 1); t.FontFace = FONT
				local s = Instance.new("UIStroke"); s.Thickness = 3; s.Color = sc.stroke or Color3.new(0, 0, 0); s.Parent = t
				t.Parent = f
			end
		end
		g.Parent = part
		return g
	end

	-- Croisillons d'une fenêtre de papier (shoji) : barres dessinées dans une SurfaceGui, pas de pièces.
	local function lattice(part, face, color, cols, rows)
		local g = Instance.new("SurfaceGui"); g.Name = "LatticeGui"; g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 20
		for c = 1, cols - 1 do
			local f = Instance.new("Frame"); f.Name = "Bar"; f.BorderSizePixel = 0; f.BackgroundColor3 = color
			f.AnchorPoint = Vector2.new(0.5, 0); f.Position = UDim2.fromScale(c / cols, 0); f.Size = UDim2.new(0, 3, 1, 0); f.Parent = g
		end
		for r = 1, rows - 1 do
			local f = Instance.new("Frame"); f.Name = "Bar"; f.BorderSizePixel = 0; f.BackgroundColor3 = color
			f.AnchorPoint = Vector2.new(0, 0.5); f.Position = UDim2.fromScale(0, r / rows); f.Size = UDim2.new(1, 0, 0, 3); f.Parent = g
		end
		g.Parent = part
	end

	-- spec.tokyo = { beam, lacquer, gold, tile, tileDark, plaster, stone, wood, paper, latticeColor, barge, gable,
	--   bracketA, lantern, lanternLight, noren, norenText, board, ad, bigScreen, vsigns, neonA, neonB, screens,
	--   videoWall?, arcade? }
	local function tokyoFacade(ctx)
		local B, label, group, model = ctx.B, ctx.label, ctx.group, ctx.model
		local T = ctx.spec.tokyo
		local top = ctx.facadeTop
		local F, U, R, I = group("Facade"), group("UpperFloors"), group("TempleRoof"), group("Interior")
		local beam, lac, gold, tile = T.beam, T.lacquer, T.gold, T.tile
		local function d(parent, extra)
			local o = { parent = parent, studs = false, decor = true }
			if extra then for k, v in extra do o[k] = v end end
			return o
		end
		-- pièce entre deux points (repère local du magasin) : longueur sur a→b, largeur w, épaisseur h
		local function seg(name, a, b, w, h, color, o)
			local mid, len = (a + b) / 2, (b - a).Magnitude
			o.rot = CFrame.lookAt(Vector3.zero, b - a)
			return B(name, mid.X - w / 2, mid.Y - h / 2, mid.Z - len / 2, mid.X + w / 2, mid.Y + h / 2, mid.Z + len / 2, color, o)
		end
		local function vcyl(name, cx, y0, y1, cz, dia, color, o)
			o.shape = Enum.PartType.Cylinder; o.rot = CFrame.Angles(0, 0, math.rad(90))
			local h, yc = y1 - y0, (y0 + y1) / 2
			return B(name, cx - h / 2, yc - dia / 2, cz - dia / 2, cx + h / 2, yc + dia / 2, cz + dia / 2, color, o)
		end
		local metal = { mat = Enum.Material.Metal }
		local neon = { mat = Enum.Material.Neon, noShadow = true }

		-- L'auvent rayé du constructeur laisse la place à un auvent de tuiles (hisashi).
		local aw = model:FindFirstChild("Awning"); if aw then aw:Destroy() end

		-- Rez-de-chaussée : poteaux rouges, poutre noire, auvent de tuiles, lanternes, noren, écran, panneau
		for i, x in { -6.95, 6.95, 10.75, 15.25 } do
			B("Post_" .. i, x - 0.3, 0.3, -25.0, x + 0.3, 8.5, -24.4, beam, d(F))
			B("PostBase_" .. i, x - 0.4, 0.3, -25.1, x + 0.4, 0.75, -24.3, T.stone, d(F))
		end
		B("HisashiBeam", -20.4, 8.5, -25.05, 20.4, 8.95, -24.6, lac, d(F))
		local hp = { Vector3.new(0, 11.0, -24.55), Vector3.new(0, 10.05, -25.75), Vector3.new(0, 9.4, -26.9), Vector3.new(0, 9.0, -28.0) }
		for i = 1, 3 do
			local dir = (hp[i + 1] - hp[i]).Unit
			seg("Hisashi_" .. i, hp[i] - dir * 0.12, hp[i + 1] + dir * 0.12, 42, 0.35, tile, d(F, { studs = true }))
		end
		B("HisashiEave", -21.1, 8.72, -28.25, 21.1, 9.22, -27.75, T.tileDark, d(F, { shape = Enum.PartType.Cylinder }))
		for i, s in { -1, 1 } do
			seg("HisashiTip_" .. i, Vector3.new(s * 20.6, 9.0, -27.4), Vector3.new(s * 22.3, 9.8, -27.4), 1.4, 0.4, tile, d(F, { studs = true }))
		end
		for i, x in { -19.6, -6.95, 6.95, 10.75, 15.25, 19.6 } do
			B("HisashiArm_" .. i, x - 0.2, 8.5, -27.7, x + 0.2, 8.95, -24.6, beam, d(F))
		end
		for i, x in { -16, -10.5, 8.8, 17.4 } do
			local z = -27.0
			B("LanternCord_" .. i, x - 0.04, 7.75, z - 0.04, x + 0.04, 9.2, z + 0.04, lac, d(F, { noShadow = true }))
			vcyl("LanternCapTop_" .. i, x, 7.5, 7.75, z, 0.75, lac, d(F))
			local body = vcyl("Lantern_" .. i, x, 6.05, 7.5, z, 1.05, T.lantern, d(F, neon))
			vcyl("LanternCapBot_" .. i, x, 5.8, 6.05, z, 0.75, lac, d(F))
			if i % 2 == 1 then
				local pl = Instance.new("PointLight"); pl.Range = 10; pl.Brightness = 0.6; pl.Color = T.lanternLight; pl.Shadows = false; pl.Parent = body
			end
		end
		B("NorenRod", 11.1, 7.25, -24.45, 14.9, 7.4, -24.3, lac, d(F))
		for i, xr in { { 11.3, 12.95 }, { 13.05, 14.7 } } do
			local n = B("Noren_" .. i, xr[1], 5.75, -24.4, xr[2], 7.25, -24.35, T.noren, d(F, { noShadow = true }))
			label(n, Enum.NormalId.Front, T.norenText[i], rgb(255, 255, 255), 60, T.noren)
		end
		local ad = B("AdScreen", -16.4, 1.6, -24.2, -9.0, 5.6, -24.0, lac, d(F))
		screenGui(ad, Enum.NormalId.Front, T.ad)
		local kb = B("ShopBoard", 16.1, 3.6, -24.3, 18.3, 7.2, -24.05, T.wood, d(F))
		label(kb, Enum.NormalId.Front, T.board, rgb(255, 255, 255), 40, rgb(40, 24, 14))

		-- Étage : poutres, grand écran au centre, fenêtres de papier, enseignes verticales en néon
		B("UpperBeam", -20.4, 13.9, -24.95, 20.4, 14.35, -24.6, beam, d(F))
		B("TopBeam", -20.6, top - 0.95, -25.2, 20.6, top - 0.1, -24.6, beam, d(U))
		for i, x in { -6.75, 6.75 } do
			B("UpperPost_" .. i, x - 0.3, 14.35, -24.95, x + 0.3, top - 0.95, -24.6, beam, d(U))
		end
		local big = B("FacadeScreen", -6.0, 14.75, -24.85, 6.0, 19.65, -24.6, lac, d(U))
		screenGui(big, Enum.NormalId.Front, T.bigScreen)
		for i, s in { -1, 1 } do
			local x0, x1 = (s < 0) and -17.6 or 8.0, (s < 0) and -8.0 or 17.6
			local paper = B("Shoji_" .. i, x0, 14.9, -24.75, x1, 19.5, -24.6, T.paper, d(U))
			lattice(paper, Enum.NormalId.Front, T.latticeColor, 8, 3)
			B("ShojiTop_" .. i, x0 - 0.25, 19.5, -24.85, x1 + 0.25, 19.75, -24.6, lac, d(U))
			B("ShojiSill_" .. i, x0 - 0.25, 14.65, -24.85, x1 + 0.25, 14.9, -24.6, lac, d(U))
		end
		for i, s in { -1, 1 } do
			local x, vs = s * 17.9, T.vsigns[i]
			local board = B("VSign_" .. i, x - 0.15, 11.4, -27.55, x + 0.15, 19.8, -24.95, vs.bg, d(U))
			label(board, Enum.NormalId.Left, vs.text, vs.textColor, 30, vs.stroke)
			label(board, Enum.NormalId.Right, vs.text, vs.textColor, 30, vs.stroke)
			B("VSignTube_" .. i .. "F", x - 0.2, 11.2, -27.75, x + 0.2, 20.0, -27.55, vs.neon, d(U, neon))
			B("VSignTube_" .. i .. "T", x - 0.2, 19.8, -27.55, x + 0.2, 20.0, -24.95, vs.neon, d(U, neon))
			B("VSignTube_" .. i .. "B", x - 0.2, 11.2, -27.55, x + 0.2, 11.4, -24.95, vs.neon, d(U, neon))
			B("VSignArm_" .. i .. "T", x - 0.1, 18.6, -25.0, x + 0.1, 18.8, -24.6, lac, d(U))
			B("VSignArm_" .. i .. "B", x - 0.1, 12.4, -25.0, x + 0.1, 12.6, -24.6, lac, d(U))
		end

		-- Volume de l'étage (comme à Londres), fermé en haut ; le toit de temple le couvre
		B("UpperSide_L", -20.05, 10.8, -23, -19, top, -11, T.plaster, { parent = U })
		B("UpperSide_R", 19, 10.8, -23, 20.05, top, -11, T.plaster, { parent = U })
		B("UpperBack", -20.05, 10.8, -11, 20.05, top, -10, T.plaster, { parent = U })
		B("UpperCap", -20.05, top, -22.8, 20.05, top + 0.5, -10, lac, { parent = U })

		-- Toit de temple : pentes concaves en 4 rangs (plus raides vers le faîte), rives, pignons,
		-- coins relevés, faîtage blanc et noir, ornements dorés, consoles sous l'avant-toit
		local PZ = { 10.9, 9.1, 6.7, 3.9, 0 }   -- recul depuis le faîte (studs)
		local PY = { 0.6, 1.3, 2.7, 4.6, 7.4 }  -- hauteur au-dessus du haut de façade
		local rz = -17.3                          -- ligne du faîte (milieu du volume, z -24.6..-10)
		for _, side in { { "F", -1 }, { "B", 1 } } do
			for i = 1, 4 do
				local a = Vector3.new(0, top + PY[i], rz + side[2] * PZ[i])
				local b = Vector3.new(0, top + PY[i + 1], rz + side[2] * PZ[i + 1])
				local dir = (b - a).Unit
				seg("Roof" .. side[1] .. "_" .. i, a - dir * 0.15, b + dir * 0.15, 46, 0.5, tile, d(R, { studs = true }))
				for j, s in { -1, 1 } do
					local o = Vector3.new(s * 23.1, 0, 0)
					seg("Barge" .. side[1] .. i .. "_" .. j, a + o - dir * 0.15, b + o + dir * 0.15, 0.3, 0.75, T.barge, d(R))
				end
			end
			local ez = rz + side[2] * PZ[1]
			B("RoofEave_" .. side[1], -23.2, top + 0.35, ez - 0.25, 23.2, top + 0.85, ez + 0.25, T.tileDark, d(R, { shape = Enum.PartType.Cylinder }))
			for j, s in { -1, 1 } do
				seg("RoofTip_" .. side[1] .. j, Vector3.new(s * 22.4, top + 0.7, ez), Vector3.new(s * 24.4, top + 1.85, ez), 1.4, 0.5, tile, d(R, { studs = true }))
				B("RoofTipCap_" .. side[1] .. j, s * 24.4 - 0.3, top + 1.6, ez - 0.3, s * 24.4 + 0.3, top + 2.2, ez + 0.3, gold, d(R, metal))
			end
		end
		local function zAt(h)
			for i = 1, 4 do
				if h <= PY[i + 1] then return PZ[i] + (PZ[i + 1] - PZ[i]) * math.clamp((h - PY[i]) / (PY[i + 1] - PY[i]), 0, 1) end
			end
			return 0
		end
		local hs = { 0.5, 1.7, 2.9, 4.1, 5.3, 6.6 }
		for j, s in { -1, 1 } do
			for k = 1, #hs - 1 do
				local zz = zAt(hs[k + 1]) - 0.35
				B("Gable_" .. j .. "_" .. k, s * 19.75 - 0.3, top + hs[k], rz - zz, s * 19.75 + 0.3, top + hs[k + 1], rz + zz, T.gable, d(R))
			end
		end
		B("Ridge", -19.5, top + 7.0, rz - 0.75, 19.5, top + 8.1, rz + 0.75, T.tileDark, d(R, { studs = true }))
		B("RidgeStripe_F", -19.5, top + 7.35, rz - 0.8, 19.5, top + 7.6, rz - 0.75, T.plaster, d(R))
		B("RidgeStripe_B", -19.5, top + 7.35, rz + 0.75, 19.5, top + 7.6, rz + 0.8, T.plaster, d(R))
		for i, s in { -1, 1 } do
			B("RidgeEnd_" .. i, s * 19.5 - 0.9, top + 6.8, rz - 1.0, s * 19.5 + 0.9, top + 8.6, rz + 1.0, T.tileDark, d(R))
			B("RidgeOrnament_" .. i, s * 19.5 - 0.45, top + 8.6, rz - 0.45, s * 19.5 + 0.45, top + 9.6, rz + 0.45, gold, d(R, metal))
			seg("RidgeHorn_" .. i, Vector3.new(s * 19.6, top + 9.3, rz), Vector3.new(s * 18.7, top + 10.5, rz), 0.45, 0.45, gold, d(R, metal))
		end
		B("RoofFrieze", -20.05, top + 0.5, -24.7, 20.05, top + 2.05, -24.5, lac, d(R))
		B("RoofFriezeBack", -20.05, top + 0.5, -10.1, 20.05, top + 2.2, -9.9, lac, d(R))
		for i = 0, 9 do
			local x = -18 + i * 4
			B("Bracket_" .. (i + 1), x - 0.45, top + 0.5, -25.7, x + 0.45, top + 1.75, -24.7, (i % 2 == 0) and T.bracketA or gold, d(R))
		end

		-- Intérieur : néons colorés le long des murs, écrans au-dessus des rayons muraux (décor sans collision)
		local function neonStrip(name, x0, y0, z0, x1, y1, z1, color, light)
			local p = B(name, x0, y0, z0, x1, y1, z1, color, d(I, neon))
			if light then local pl = Instance.new("PointLight"); pl.Range = 16; pl.Brightness = 0.4; pl.Color = color; pl.Shadows = false; pl.Parent = p end
		end
		neonStrip("WallNeon_L", -18.9, 9.25, -22.9, -18.78, 9.45, 22.8, T.neonA, true)
		neonStrip("WallNeon_R", 18.78, 9.25, -22.9, 18.9, 9.45, 15.9, T.neonB, true)
		neonStrip("WallNeon_B", -18.9, 9.25, 22.78, 7.9, 9.45, 22.9, T.neonA, false)
		for i, zc in { -10.5, -3, 4.5 } do
			local sl = B("WallScreen_L" .. i, -18.9, 6.75, zc - 1.9, -18.72, 8.95, zc + 1.9, lac, d(I))
			screenGui(sl, Enum.NormalId.Right, T.screens[i])
			local sr = B("WallScreen_R" .. i, 18.72, 6.75, zc - 1.9, 18.9, 8.95, zc + 1.9, lac, d(I))
			screenGui(sr, Enum.NormalId.Left, T.screens[i + 3])
		end
		-- grand écran (ou mur d'écrans) sur le mur gauche, au fond, derrière le GuardSpawn
		local vw = B("VideoWall", -18.9, 1.6, 10.6, -18.7, 8.6, 20.4, lac, d(I))
		screenGui(vw, Enum.NormalId.Right, T.videoWall)
		-- bornes d'arcade contre le mur droit, entre le rayon mural et la réserve (avec collisions, hors des allées)
		for i, a in (T.arcade or {}) do
			local z0 = 9.7 + (i - 1) * 2.0
			local z1 = z0 + 1.8
			B("Arcade_" .. i, 17.2, 0.35, z0, 18.9, 5.6, z1, a.body, { parent = I })
			B("ArcadePanel_" .. i, 16.4, 2.9, z0 + 0.1, 17.2, 3.3, z1 - 0.1, lac, { parent = I, studs = false })
			local scr = B("ArcadeScreen_" .. i, 17.1, 3.5, z0 + 0.2, 17.2, 5.0, z1 - 0.2, lac, d(I))
			screenGui(scr, Enum.NormalId.Left, a.screen)
			B("ArcadeMarquee_" .. i, 17.0, 5.6, z0, 18.9, 6.3, z1, a.marquee, d(I, neon))
		end
		-- Réserve : ouverture élargie de 6 à 8 studs (x 9..17), socle du Luxe intact. À la position imposée
		-- de l'Électronique (pivot 240, 0, 44), le navmesh fermait la porte de 6 studs (décalé de 4 studs,
		-- elle passait) : le vigile n'atteignait plus le Luxe. 8 studs passent quel que soit l'alignement testé.
		local Rv = model:FindFirstChild("Reserve")
		if Rv then
			local function box(name, x0, y0, z0, x1, y1, z1)
				local p = Rv:FindFirstChild(name); if not p then return end
				p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0); p.CFrame = ctx.ORIGIN * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
			end
			box("ReserveWall_FL", 8, 0.3, 16, 9, 9.9, 17)
			box("ReserveWall_FR", 17, 0.3, 16, 19, 9.9, 17)
			box("ReserveWall_Top", 9, 8.1, 16, 17, 9.9, 17)
			box("ReserveFrame_L", 8.8, 0.35, 15.9, 9, 7.8, 17.1)
			box("ReserveFrame_R", 17, 0.35, 15.9, 17.2, 7.8, 17.1)
			box("ReserveFrame_T", 8.8, 7.8, 15.9, 17.2, 8.1, 17.1)
			box("ReserveSign", 11, 8.3, 15.8, 15, 9.3, 16.0)
			local rs = Rv:FindFirstChild("ReserveSign")
			local rl = rs and rs:FindFirstChild("Label", true)
			if rl and T.reserveText then rl.Text = T.reserveText end   -- textes de la zone en anglais (Clément)
			for i = 0, 7 do
				local nm = string.format("StripCurtain_%02d", i + 1)
				if not Rv:FindFirstChild(nm) and Rv:FindFirstChild("StripCurtain_01") then
					local c = Rv.StripCurtain_01:Clone(); c.Name = nm; c.Parent = Rv
				end
				local x0 = 9.05 + i * 0.99
				box(nm, x0, 1.2, 16.45, x0 + 0.9, 7.8, 16.5)
			end
		end
	end

	_G.ClaudeTokyo = { facade = tokyoFacade, screenGui = screenGui, lattice = lattice }
end

------------------------------------------------------------------------------------------------
-- BLOC 2 : greybox, puis les deux magasins dans Map/Zone_3
------------------------------------------------------------------------------------------------
do
	local rgb = Color3.fromRGB
	local Store, Tokyo = _G.ClaudeStore, _G.ClaudeTokyo
	assert(Store, "charger d'abord tools/clement/store_builder.luau")
	assert(Tokyo, "lancer d'abord le bloc 1 de ce fichier")

	-- Greybox : magasins gris rangés, murets calés sur les magasins (x 190..220 et 260..300), rue au thème.
	local SS = game:GetService("ServerStorage")
	local gz = workspace.Greybox.Corridor.Zone_3
	for _, nm in { "STORE_Z3_Electronique", "STORE_Z3_JeuxVideo" } do
		local m = gz:FindFirstChild(nm)
		if m then
			local keep = SS:FindFirstChild("_GREYBOX_REMPLACE") or Instance.new("Folder")
			keep.Name = "_GREYBOX_REMPLACE"; keep.Parent = SS
			m.Parent = keep
		end
	end
	local g = gz.Ground
	g.SideWall_N1.Size = Vector3.new(30, 12, 1); g.SideWall_N1.Position = Vector3.new(205, 6, 20.5)
	g.SideWall_S1.Size = Vector3.new(30, 12, 1); g.SideWall_S1.Position = Vector3.new(205, 6, -20.5)
	g.SideWall_N2.Size = Vector3.new(40, 12, 1); g.SideWall_N2.Position = Vector3.new(280, 6, 20.5)
	g.SideWall_S2.Size = Vector3.new(40, 12, 1); g.SideWall_S2.Position = Vector3.new(280, 6, -20.5)
	g.Street.Color = rgb(48, 52, 62); g.Street.Material = Enum.Material.Plastic; g.Street.MaterialVariant = "Studs"

	local zoneFolder = workspace.Map:FindFirstChild("Zone_3")
	if not zoneFolder then zoneFolder = Instance.new("Folder"); zoneFolder.Name = "Zone_3"; zoneFolder.Parent = workspace.Map end
	for _, nm in { "STORE_Z3_Electronique", "STORE_Z3_JeuxVideo" } do
		local old = zoneFolder:FindFirstChild(nm); if old then old:Destroy() end
	end

	local gold, lac, red = rgb(222, 178, 60), rgb(30, 28, 32), rgb(206, 52, 38)
	local cyan, pink, yellow, purple = rgb(80, 230, 255), rgb(255, 70, 180), rgb(255, 225, 60), rgb(150, 80, 240)
	local white = rgb(255, 255, 255)

	-- Électronique : plâtre blanc et poteaux vermillon, tuiles sombres, néons cyan ; intérieur clair
	local elec, elecN = Store.build({
		name = "STORE_Z3_Electronique", zone = 3,
		origin = CFrame.new(240, 0, 44), parent = zoneFolder,
		sign = "ELECTRONICS",
		signColors = { bg = rgb(18, 22, 34), text = cyan, border = gold },
		signRect = { -13, 13, 11.4, 13.55 }, facadeTop = 21,
		colors = {
			wall = rgb(236, 232, 222), front = rgb(46, 40, 38), upper = rgb(240, 236, 226), trim = red, cornice = lac, pilaster = red,
			frame = lac, plinth = rgb(96, 96, 100), roof = rgb(70, 74, 84),
			innerWall = rgb(244, 246, 250), ceiling = rgb(236, 238, 244), floor = rgb(200, 206, 216), tile = rgb(240, 242, 246),
			shelf = rgb(245, 245, 248), shelfBack = rgb(60, 66, 80), kick = rgb(40, 44, 54), price = yellow,
			counter = red, counterTop = white, mat = red, doorKick = gold, neon = rgb(200, 245, 255),
			pot = rgb(30, 30, 34), leaf = rgb(70, 150, 60), promo = yellow, promoText = red,
		},
		headers = {
			A_L = { "TVS", rgb(46, 120, 230) }, A_R = { "PHONES", rgb(232, 60, 80) },
			B_L = { "COMPUTERS", rgb(30, 170, 140) }, B_R = { "TABLETS", rgb(150, 90, 230) },
			WallL = { "AUDIO", rgb(255, 140, 30) }, WallR = { "CAMERAS", rgb(60, 170, 220) }, Back = { "NEW ARRIVALS", rgb(232, 65, 60) },
		},
		designs = {
			tv = { body = rgb(30, 70, 160), cap = rgb(22, 22, 26), w = 1.5, h = 1.0, ch = 0.12, d = 0.3 },
			tvV = { body = rgb(90, 50, 160), cap = rgb(22, 22, 26), w = 1.5, h = 1.0, ch = 0.12, d = 0.3 },
			tvBox = { body = rgb(235, 235, 240), cap = rgb(46, 120, 230), w = 1.4, h = 1.1, ch = 0.25, d = 0.45 },
			phone = { body = rgb(250, 250, 252), cap = rgb(30, 30, 34), w = 0.45, h = 0.75, ch = 0.12, d = 0.25 },
			phoneN = { body = rgb(30, 30, 34), cap = rgb(232, 60, 80), w = 0.45, h = 0.75, ch = 0.12, d = 0.25 },
			phoneR = { body = rgb(232, 60, 80), cap = rgb(250, 250, 252), w = 0.45, h = 0.75, ch = 0.12, d = 0.25 },
			laptop = { body = rgb(190, 196, 206), cap = rgb(40, 44, 54), w = 1.3, h = 0.9, ch = 0.15, d = 0.3 },
			laptopN = { body = rgb(40, 44, 54), cap = rgb(80, 230, 255), w = 1.3, h = 0.9, ch = 0.15, d = 0.3 },
			tower = { body = rgb(36, 38, 46), cap = rgb(80, 230, 255), w = 0.7, h = 1.3, ch = 0.1, d = 0.9 },
			tablet = { body = rgb(30, 30, 36), cap = rgb(200, 205, 215), w = 1.0, h = 1.2, ch = 0.1, d = 0.2 },
			tabletW = { body = rgb(245, 245, 248), cap = rgb(150, 90, 230), w = 1.0, h = 1.2, ch = 0.1, d = 0.2 },
			casque = { body = rgb(30, 30, 36), cap = rgb(255, 140, 30), w = 0.8, h = 0.85, ch = 0.3, d = 0.6 },
			casqueB = { body = rgb(245, 245, 248), cap = rgb(46, 120, 230), w = 0.8, h = 0.85, ch = 0.3, d = 0.6 },
			enceinte = { body = rgb(50, 54, 64), cap = rgb(255, 140, 30), w = 0.7, h = 1.1, ch = 0.1, d = 0.7 },
			photo = { body = rgb(26, 26, 30), cap = rgb(190, 196, 206), w = 0.8, h = 0.6, ch = 0.2, d = 0.6 },
			photoBox = { body = rgb(250, 250, 250), cap = rgb(232, 65, 60), w = 0.8, h = 0.8, ch = 0.2, d = 0.7 },
		},
		pools = {
			A_L = { "tv", "tvV", "tvBox" }, A_R = { "phone", "phoneN", "phoneR" },
			B_L = { "laptop", "tower", "laptopN" }, B_R = { "tablet", "tabletW" },
			WallL = { "casque", "casqueB", "enceinte" }, WallR = { "photo", "photoBox" },
			Back = { "phone", "tablet", "photo", "casque" },
		},
		seed = 3003, stockColor = rgb(236, 238, 242), promo = "SALE",
		tokyo = {
			beam = red, lacquer = lac, gold = gold, tile = rgb(58, 62, 74), tileDark = rgb(40, 43, 52),
			plaster = rgb(240, 236, 226), stone = rgb(120, 118, 112), wood = rgb(120, 78, 46), paper = rgb(250, 242, 222),
			latticeColor = rgb(60, 40, 28), barge = rgb(240, 236, 226), gable = rgb(240, 236, 226), bracketA = rgb(64, 150, 130),
			lantern = rgb(226, 64, 48), lanternLight = rgb(255, 150, 110),
			noren = rgb(28, 48, 110), norenText = { "TECH", "SHOP" }, board = "O\nP\nE\nN", reserveText = "STOCKROOM",
			ad = { a = rgb(20, 60, 160), b = rgb(60, 220, 255), text = "TV 4K\nULTRA HD" },
			bigScreen = { a = rgb(255, 120, 60), b = rgb(120, 40, 200), text = "HIGH-TECH" },
			vsigns = {
				{ text = "T\nE\nC\nH", bg = rgb(18, 22, 34), textColor = cyan, stroke = rgb(0, 40, 80), neon = cyan },
				{ text = "N\nE\nW", bg = rgb(200, 30, 40), textColor = white, stroke = rgb(90, 0, 0), neon = yellow },
			},
			neonA = cyan, neonB = cyan,
			screens = {
				{ a = rgb(255, 140, 60), b = rgb(160, 50, 160), text = "4K" }, { a = rgb(20, 120, 220), b = rgb(100, 230, 255), text = "HD" },
				{ a = rgb(30, 140, 70), b = rgb(190, 240, 120), text = "8K" }, { a = rgb(20, 20, 70), b = pink, text = "4K" },
				{ a = rgb(120, 180, 255), b = rgb(250, 250, 255), text = "HD", textColor = rgb(20, 60, 140), stroke = white },
				{ a = rgb(255, 170, 210), b = rgb(255, 240, 245), text = "4K", textColor = rgb(200, 40, 110), stroke = white },
			},
			videoWall = { grid = { 3, 3, {
				{ rgb(255, 140, 60), rgb(160, 50, 160) }, { rgb(20, 120, 220), rgb(100, 230, 255) }, { rgb(30, 140, 70), rgb(190, 240, 120) },
				{ rgb(20, 20, 70), pink }, { rgb(255, 170, 210), rgb(255, 240, 245) }, { rgb(255, 120, 60), rgb(255, 225, 60) },
				{ rgb(20, 60, 160), cyan }, { rgb(120, 40, 200), pink }, { rgb(255, 140, 60), rgb(160, 50, 160) },
			} } },
		},
		facade = Tokyo.facade,
	})
	task.wait()

	-- Jeux vidéo : murs vermillon, poutres laquées noires, ors, néons rose et cyan ; intérieur sombre et violet
	local maroon, black = rgb(176, 38, 36), rgb(30, 28, 34)
	local game_, gameN = Store.build({
		name = "STORE_Z3_JeuxVideo", zone = 3,
		origin = CFrame.new(240, 0, -44) * CFrame.Angles(0, math.pi, 0), parent = zoneFolder,
		sign = "VIDEO GAMES",
		signColors = { bg = rgb(40, 16, 60), text = yellow, border = pink },
		signRect = { -13, 13, 11.4, 13.55 }, facadeTop = 21,
		colors = {
			wall = rgb(150, 34, 34), front = rgb(70, 30, 34), upper = maroon, trim = gold, cornice = black, pilaster = black,
			frame = black, plinth = rgb(80, 80, 86), roof = rgb(60, 62, 72),
			innerWall = rgb(56, 48, 82), ceiling = rgb(40, 36, 58), floor = rgb(44, 40, 60), tile = rgb(86, 64, 128),
			shelf = rgb(52, 52, 64), shelfBack = rgb(28, 28, 36), kick = pink, price = cyan,
			counter = maroon, counterTop = black, mat = maroon, doorKick = gold, neon = rgb(255, 150, 230),
			pot = black, leaf = rgb(70, 150, 60), promo = pink, promoText = white,
		},
		headers = {
			A_L = { "CONSOLES", rgb(46, 120, 230) }, A_R = { "CONTROLLERS", rgb(232, 60, 80) },
			B_L = { "ADVENTURE", rgb(60, 180, 90) }, B_R = { "RACING", rgb(255, 140, 30) },
			WallL = { "RETRO", purple }, WallR = { "SPORTS", pink }, Back = { "COLLECTOR'S", gold },
		},
		designs = {
			console = { body = rgb(245, 245, 248), cap = rgb(46, 120, 230), w = 1.1, h = 0.55, ch = 0.12, d = 0.8 },
			consoleN = { body = rgb(30, 30, 36), cap = rgb(232, 60, 80), w = 1.1, h = 0.55, ch = 0.12, d = 0.8 },
			consoleBox = { body = rgb(46, 120, 230), cap = rgb(250, 250, 250), w = 1.2, h = 1.0, ch = 0.25, d = 0.5 },
			manette = { body = rgb(40, 40, 48), cap = cyan, w = 0.75, h = 0.45, ch = 0.1, d = 0.5 },
			manetteR = { body = rgb(232, 60, 80), cap = rgb(250, 250, 250), w = 0.75, h = 0.45, ch = 0.1, d = 0.5 },
			manetteBox = { body = rgb(250, 250, 250), cap = rgb(40, 40, 48), w = 0.8, h = 0.9, ch = 0.2, d = 0.35 },
			jeu = { body = rgb(46, 120, 230), cap = rgb(250, 250, 250), w = 0.4, h = 1.0, ch = 0.15, d = 0.7 },
			jeuR = { body = rgb(232, 60, 80), cap = rgb(250, 250, 250), w = 0.4, h = 1.0, ch = 0.15, d = 0.7 },
			jeuV = { body = rgb(60, 180, 90), cap = rgb(250, 250, 250), w = 0.4, h = 1.0, ch = 0.15, d = 0.7 },
			jeuJ = { body = rgb(255, 200, 40), cap = rgb(30, 30, 36), w = 0.4, h = 1.0, ch = 0.15, d = 0.7 },
			jeuP = { body = purple, cap = rgb(250, 250, 250), w = 0.4, h = 1.0, ch = 0.15, d = 0.7 },
			jeuO = { body = rgb(255, 140, 30), cap = rgb(30, 30, 36), w = 0.4, h = 1.0, ch = 0.15, d = 0.7 },
			portable = { body = pink, cap = rgb(30, 30, 36), w = 0.9, h = 0.5, ch = 0.12, d = 0.4 },
			cartouche = { body = rgb(110, 110, 120), cap = rgb(232, 65, 60), w = 0.5, h = 0.6, ch = 0.2, d = 0.15 },
			retro = { body = rgb(200, 200, 205), cap = maroon, w = 1.0, h = 0.6, ch = 0.15, d = 0.8 },
		},
		pools = {
			A_L = { "console", "consoleN", "consoleBox" }, A_R = { "manette", "manetteR", "manetteBox" },
			B_L = { "jeu", "jeuV", "jeuP" }, B_R = { "jeuR", "jeuJ", "jeuO" },
			WallL = { "cartouche", "retro", "portable" }, WallR = { "jeuJ", "jeuV", "manette" },
			Back = { "consoleBox", "portable", "manetteBox", "jeuP" },
		},
		seed = 3030, stockColor = rgb(46, 120, 230), promo = "NEW",
		tokyo = {
			beam = black, lacquer = black, gold = gold, tile = rgb(48, 50, 62), tileDark = rgb(32, 34, 42),
			plaster = rgb(236, 226, 210), stone = rgb(110, 106, 100), wood = rgb(70, 40, 30), paper = rgb(255, 236, 214),
			latticeColor = rgb(40, 20, 20), barge = gold, gable = maroon, bracketA = rgb(64, 150, 130),
			lantern = rgb(255, 120, 40), lanternLight = rgb(255, 170, 90),
			noren = rgb(160, 30, 40), norenText = { "GAME", "ZONE" }, board = "O\nP\nE\nN", reserveText = "STOCKROOM",
			ad = { a = rgb(120, 30, 200), b = pink, text = "NEW\nGAME!" },
			bigScreen = { a = rgb(30, 20, 80), b = pink, text = "PLAYER 1\nREADY?" },
			vsigns = {
				{ text = "G\nA\nM\nE", bg = rgb(40, 16, 60), textColor = yellow, stroke = rgb(80, 0, 60), neon = pink },
				{ text = "P\nL\nA\nY", bg = rgb(20, 20, 26), textColor = pink, stroke = rgb(60, 0, 40), neon = cyan },
			},
			neonA = pink, neonB = cyan,
			screens = {
				{ a = rgb(30, 20, 80), b = pink, text = "LEVEL 8" }, { a = rgb(20, 120, 60), b = rgb(140, 240, 90), text = "★ ★ ★" },
				{ a = rgb(255, 140, 30), b = yellow, text = "VICTORY!" }, { a = rgb(20, 40, 140), b = cyan, text = "PLAYER 2" },
				{ a = rgb(120, 30, 200), b = rgb(255, 120, 220), text = "READY?" }, { a = rgb(200, 30, 40), b = rgb(255, 160, 60), text = "BONUS" },
			},
			videoWall = { a = pink, b = cyan, rot = 0, text = "PLAYER 1\nVS\nPLAYER 2" },
			arcade = {
				{ body = purple, marquee = pink, screen = { a = rgb(20, 20, 60), b = rgb(60, 60, 200), text = "READY?" } },
				{ body = rgb(200, 30, 40), marquee = yellow, screen = { a = rgb(60, 10, 10), b = rgb(255, 120, 40), text = "VS" } },
				{ body = rgb(30, 110, 200), marquee = cyan, screen = { a = rgb(10, 40, 20), b = rgb(60, 200, 90), text = "LEVEL 1" } },
			},
		},
		facade = Tokyo.facade,
	})
	print(string.format("Zone 3 Tokyo : électronique %d produits (%d pièces), jeux vidéo %d produits (%d pièces)",
		elecN, #elec:GetDescendants(), gameN, #game_:GetDescendants()))
end

------------------------------------------------------------------------------------------------
-- BLOC 3 : décor de rue, Map/Zone_3/Street_Tokyo. Chaussée z -15..15 libre (marquages au sol et
-- guirlandes de lanternes à plus de 11 studs seulement) ; trottoirs à |z| 15..20, 0,3 stud de haut ;
-- façades plaquées sur les murets, sans collision ; pagode et tour d'antenne derrière les murets.
------------------------------------------------------------------------------------------------
do
	local rgb = Color3.fromRGB
	local Tokyo = _G.ClaudeTokyo
	assert(Tokyo, "lancer d'abord le bloc 1 de ce fichier")
	local Z = workspace.Map:FindFirstChild("Zone_3")
	assert(Z, "lancer d'abord le bloc 2 de ce fichier")
	local old = Z:FindFirstChild("Street_Tokyo"); if old then old:Destroy() end
	local S = Instance.new("Folder"); S.Name = "Street_Tokyo"
	local function folder(name) local f = Instance.new("Model"); f.Name = name; f.Parent = S; return f end
	local count = 0
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
		count += 1
		return p
	end
	local function Bx(parent, fr, name, x0, y0, z0, x1, y1, z1, color, opt)
		local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
		return P(parent, name, fr * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), size, color, opt)
	end
	local function vcyl(parent, name, x, y0, y1, z, dia, color, opt)
		opt = opt or {}; opt.shape = Enum.PartType.Cylinder
		return P(parent, name, CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(y1 - y0, dia, dia), color, opt)
	end
	local function seg(parent, name, a, b, w, h, color, opt)   -- pièce de a à b (jamais verticale)
		return P(parent, name, CFrame.lookAt((a + b) / 2, b), Vector3.new(w, h, (b - a).Magnitude), color, opt)
	end
	local function ball(parent, name, pos, dia, color, opt)
		opt = opt or {}; opt.shape = Enum.PartType.Ball
		return P(parent, name, CFrame.new(pos), Vector3.new(dia, dia, dia), color, opt)
	end
	local function flat(parent, name, a, b, w)   -- trait blanc peint sur la chaussée, de a à b
		local dx, dz = b.X - a.X, b.Z - a.Z
		return P(parent, name, CFrame.new((a.X + b.X) / 2, 0.02, (a.Z + b.Z) / 2) * CFrame.Angles(0, math.atan2(-dz, dx), 0),
			Vector3.new(math.sqrt(dx * dx + dz * dz), 0.04, w), rgb(245, 245, 240), { decor = true, noShadow = true })
	end
	local function label(part, face, text, color, ppS, stroke)
		local g = Instance.new("SurfaceGui"); g.Name = "LabelGui_" .. face.Name; g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppS or 40; g.LightInfluence = 0
		local t = Instance.new("TextLabel"); t.Name = "Label"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1)
		t.Text = text; t.TextScaled = true; t.TextColor3 = color
		t.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
		local s = Instance.new("UIStroke"); s.Color = stroke or Color3.new(0, 0, 0); s.Thickness = 3; s.LineJoinMode = Enum.LineJoinMode.Round; s.Parent = t
		local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0.1, 0); pad.PaddingBottom = UDim.new(0.1, 0); pad.Parent = t
		t.Parent = g; g.Parent = part
	end
	local W = CFrame.identity
	local red, black, gold = rgb(206, 52, 38), rgb(30, 28, 32), rgb(222, 178, 60)
	local tile, plaster, stone = rgb(58, 62, 74), rgb(238, 232, 218), rgb(150, 146, 138)
	local white = rgb(245, 245, 240)
	local pinks = { rgb(255, 183, 213), rgb(255, 208, 228), rgb(244, 150, 190) }
	local neonOpt = { decor = true, mat = Enum.Material.Neon, noShadow = true }
	local function neon() local o = {}; for k, v in neonOpt do o[k] = v end; return o end

	-- Sol : bordures, trottoirs, bande podotactile jaune, lignes de rive, pointillés, passage piéton,
	-- lignes d'arrêt et losanges d'annonce du passage (circulation à gauche, comme au Japon)
	local G = folder("Ground")
	for _, s in { 1, -1 } do
		local tag = (s > 0) and "N" or "S"
		Bx(G, W, "Kerb_" .. tag, 190, 0, s * 15, 300, 0.3, s * 15.5, rgb(206, 204, 198), { studs = true })
		Bx(G, W, "Pavement_" .. tag, 190, 0, s * 15.5, 300, 0.3, s * 20, rgb(178, 170, 160), { studs = true })
		Bx(G, W, "TactileStrip_" .. tag, 190, 0.3, s * 16.4, 300, 0.33, s * 17.0, rgb(250, 205, 30), { decor = true, noShadow = true })
		for _, sg in { { 190, 236.5 }, { 243.5, 300 } } do
			flat(G, "EdgeLine_" .. tag .. sg[1], Vector3.new(sg[1], 0, s * 14.3), Vector3.new(sg[2], 0, s * 14.3), 0.2)
		end
	end
	local nd = 0
	for x = 192, 294, 6 do
		local blocked = (x + 3 > 234 and x < 246) or math.abs(x + 1.5 - 217.5) < 4 or math.abs(x + 1.5 - 272.5) < 4
		if not blocked then nd += 1; flat(G, "CenterDash_" .. nd, Vector3.new(x, 0, 0), Vector3.new(x + 3, 0, 0), 0.25) end
	end
	for i = 0, 11 do
		local z0 = -13.8 + i * 2.4
		Bx(G, W, "Crosswalk_" .. (i + 1), 237, 0, z0, 243, 0.04, z0 + 1.2, white, { decor = true, noShadow = true })
	end
	flat(G, "StopLine_E", Vector3.new(235.4, 0, -14), Vector3.new(235.4, 0, -0.3), 0.45)
	flat(G, "StopLine_W", Vector3.new(244.6, 0, 0.3), Vector3.new(244.6, 0, 14), 0.45)
	for i, c in { { 226, -7 }, { 254, 7 } } do
		local v = { Vector3.new(c[1] - 3, 0, c[2]), Vector3.new(c[1], 0, c[2] - 1.6), Vector3.new(c[1] + 3, 0, c[2]), Vector3.new(c[1], 0, c[2] + 1.6) }
		for k = 1, 4 do flat(G, "Diamond_" .. i .. "_" .. k, v[k], v[k % 4 + 1], 0.25) end
	end

	-- Sanctuaire à l'entrée (arche x = 190) : torii au-dessus de la rue, lanternes de pierre, mur d'enceinte
	local Sh = folder("Shrine")
	local tx = 195.5
	for _, s in { 1, -1 } do
		local tag = (s > 0) and "N" or "S"
		vcyl(Sh, "ToriiPillar_" .. tag, tx, 0.3, 16.0, s * 19.1, 1.3, red)
		vcyl(Sh, "ToriiBase_" .. tag, tx, 0.3, 1.3, s * 19.1, 1.7, black)
		local lx, lz = 199.0, s * 18.4
		Bx(Sh, W, "StoneLantern_" .. tag .. "_Base", lx - 0.8, 0.3, lz - 0.8, lx + 0.8, 0.8, lz + 0.8, stone, { studs = true })
		vcyl(Sh, "StoneLantern_" .. tag .. "_Post", lx, 0.8, 2.8, lz, 0.7, stone)
		Bx(Sh, W, "StoneLantern_" .. tag .. "_Deck", lx - 0.75, 2.8, lz - 0.75, lx + 0.75, 3.1, lz + 0.75, stone, { decor = true })
		Bx(Sh, W, "StoneLantern_" .. tag .. "_Box", lx - 0.5, 3.1, lz - 0.5, lx + 0.5, 4.0, lz + 0.5, stone, { decor = true })
		local glow = Bx(Sh, W, "StoneLantern_" .. tag .. "_Glow", lx - 0.3, 3.3, lz - 0.52, lx + 0.3, 3.8, lz + 0.52, rgb(255, 214, 140), neon())
		local pl = Instance.new("PointLight"); pl.Color = rgb(255, 200, 130); pl.Range = 9; pl.Brightness = 0.7; pl.Shadows = false; pl.Parent = glow
		Bx(Sh, W, "StoneLantern_" .. tag .. "_Roof", lx - 0.95, 4.0, lz - 0.95, lx + 0.95, 4.3, lz + 0.95, stone, { decor = true })
		Bx(Sh, W, "StoneLantern_" .. tag .. "_Cap", lx - 0.55, 4.3, lz - 0.55, lx + 0.55, 4.6, lz + 0.55, stone, { decor = true })
		Bx(Sh, W, "ShrineWall_" .. tag, 191, 0, s * 19.85, 201, 12.4, s * 21.2, plaster, { studs = true, decor = true })
		Bx(Sh, W, "ShrineWallBase_" .. tag, 191, 0.3, s * 19.75, 201, 1.4, s * 19.85, stone, { decor = true })
		Bx(Sh, W, "ShrineWallBand_" .. tag, 191, 9.6, s * 19.75, 201, 10.2, s * 19.85, red, { decor = true })
		seg(Sh, "ShrineWallCoping_" .. tag, Vector3.new(196, 12.2, s * 19.2), Vector3.new(196, 13.4, s * 21.0), 10.4, 0.4, tile, { decor = true, studs = true })
	end
	Bx(Sh, W, "ToriiNuki", tx - 0.45, 12.2, -21.2, tx + 0.45, 13.0, 21.2, red, { decor = true })
	Bx(Sh, W, "ToriiShimaki", tx - 0.5, 15.5, -21.6, tx + 0.5, 16.3, 21.6, red, { decor = true })
	Bx(Sh, W, "ToriiKasagi", tx - 0.7, 16.3, -16, tx + 0.7, 17.3, 16, black, { decor = true })
	for i, s in { 1, -1 } do
		seg(Sh, "ToriiKasagiEnd_" .. i, Vector3.new(tx, 16.8, s * 15.9), Vector3.new(tx, 17.7, s * 22.8), 1.4, 1.0, black, { decor = true })
	end
	local plaque = Bx(Sh, W, "ToriiPlaque", tx - 0.4, 13.05, -0.9, tx + 0.4, 15.45, 0.9, black, { decor = true })
	label(plaque, Enum.NormalId.Left, "T\nO\nK\nY\nO", gold, 40)
	label(plaque, Enum.NormalId.Right, "T\nO\nK\nY\nO", gold, 40)

	-- Maisons de bois (machiya) plaquées sur les murets : treillis, noren, auvent, fenêtre à barreaux,
	-- toit de tuiles, enseigne verticale en néon ou panneau. Le muret reste le vrai mur (aucune collision).
	local H = folder("Houses")
	local function house(name, fr, w, st)
		local m = Instance.new("Model"); m.Name = name; m.Parent = H
		local dk = { decor = true }
		local h = st.h
		local function L(x, y, z) return fr:PointToWorldSpace(Vector3.new(x, y, z)) end
		Bx(m, fr, "Wall", 0, 0, 0, w, h, 1.35, st.body, { studs = true, decor = true })
		Bx(m, fr, "Plinth", 0, 0.3, -0.08, w, 0.9, 0, stone, dk)
		local koshi = Bx(m, fr, "Koshi", 0.5, 0.9, -0.12, w * 0.55 - 0.3, 6.2, 0, rgb(46, 34, 28), dk)
		Tokyo.lattice(koshi, Enum.NormalId.Front, st.wood, 12, 1)
		local dx0 = w * 0.55
		Bx(m, fr, "Entry", dx0, 0.3, -0.1, dx0 + 2.4, 6.0, 0, rgb(30, 26, 24), dk)
		local noren = Bx(m, fr, "Noren", dx0 - 0.1, 4.3, -0.3, dx0 + 2.5, 6.0, -0.25, st.noren, { decor = true, noShadow = true })
		label(noren, Enum.NormalId.Front, st.mark, white, 50, st.noren)
		seg(m, "Eave", L(w / 2, 7.4, 0.1), L(w / 2, 6.6, -1.7), w + 0.4, 0.3, tile, { decor = true, studs = true })
		local upper = Bx(m, fr, "UpperWindow", w * 0.15, 8.4, -0.12, w * 0.85, 10.9, 0, rgb(70, 50, 38), dk)
		Tokyo.lattice(upper, Enum.NormalId.Front, st.wood, 16, 2)
		seg(m, "Roof", L(w / 2, h - 0.2, -1.5), L(w / 2, h + 2.2, 1.5), w + 0.6, 0.45, tile, { decor = true, studs = true })
		if st.vsign then
			local top = math.min(13.0, h - 0.6)
			local vs = Bx(m, fr, "VSign", w - 0.85, 8.0, -2.3, w - 0.55, top, -0.3, st.vbg, dk)
			label(vs, Enum.NormalId.Left, st.vsign, st.vtext, 30)
			label(vs, Enum.NormalId.Right, st.vsign, st.vtext, 30)
			Bx(m, fr, "VSignNeon", w - 0.9, 7.9, -2.5, w - 0.5, top + 0.1, -2.3, st.vneon or white, neon())
		else
			local kb = Bx(m, fr, "Kanban", w * 0.18, 11.3, -0.2, w * 0.82, 12.5, 0, st.vbg, dk)
			label(kb, Enum.NormalId.Front, st.kanban, st.vtext, 40)
		end
		if st.lantern then
			for i, lx in { dx0 - 0.5, dx0 + 2.9 } do
				local p = L(lx, 0, -0.9)
				vcyl(m, "RedLantern_" .. i, p.X, 5.3, 6.4, p.Z, 0.8, rgb(220, 50, 40), neon())
				vcyl(m, "RedLanternCap_" .. i, p.X, 6.4, 6.65, p.Z, 0.5, black, { decor = true })
			end
		end
	end
	local houses = {
		N = {
			{ h = 13.5, body = rgb(74, 52, 40), wood = rgb(150, 108, 70), noren = rgb(170, 30, 36), mark = "RAMEN", vsign = "R\nA\nM\nE\nN", vbg = rgb(200, 30, 40), vtext = white, vneon = rgb(255, 225, 60), lantern = true },
			{ h = 12.8, body = rgb(236, 230, 216), wood = rgb(90, 62, 42), noren = rgb(40, 90, 60), mark = "TEA", kanban = "TEA HOUSE", vbg = rgb(60, 40, 28), vtext = white },
			{ h = 14.2, body = rgb(110, 76, 52), wood = rgb(60, 40, 28), noren = rgb(28, 48, 110), mark = "SUSHI", vsign = "S\nU\nS\nH\nI", vbg = rgb(250, 248, 240), vtext = rgb(30, 30, 30), vneon = rgb(80, 230, 255) },
			{ h = 13.0, body = rgb(236, 230, 216), wood = rgb(110, 76, 52), noren = rgb(200, 120, 160), mark = "SWEETS", kanban = "SWEET SHOP", vbg = rgb(240, 150, 190), vtext = white, lantern = true },
			{ h = 15.0, body = rgb(44, 40, 44), wood = rgb(120, 90, 160), noren = rgb(120, 40, 160), mark = "SING", vsign = "K\nA\nR\nA\nO\nK\nE", vbg = rgb(30, 20, 50), vtext = rgb(255, 120, 220), vneon = rgb(255, 70, 180) },
			{ h = 12.6, body = rgb(150, 110, 74), wood = rgb(70, 48, 36), noren = rgb(60, 140, 80), mark = "FLOWERS", kanban = "FLOWERS", vbg = rgb(250, 248, 240), vtext = rgb(60, 140, 80) },
		},
		S = {
			{ h = 13.2, body = rgb(110, 76, 52), wood = rgb(60, 40, 28), noren = rgb(240, 236, 226), mark = "NOODLES", vsign = "N\nO\nO\nD\nL\nE\nS", vbg = rgb(240, 236, 226), vtext = rgb(30, 30, 30), vneon = rgb(255, 160, 60), lantern = true },
			{ h = 14.0, body = rgb(236, 230, 216), wood = rgb(90, 62, 42), noren = rgb(130, 40, 60), mark = "CANDY", kanban = "CANDY SHOP", vbg = rgb(130, 40, 60), vtext = white },
			{ h = 12.8, body = rgb(74, 52, 40), wood = rgb(150, 108, 70), noren = rgb(28, 48, 110), mark = "PHARMACY", kanban = "PHARMACY", vbg = rgb(28, 90, 170), vtext = white },
			{ h = 14.6, body = rgb(236, 230, 216), wood = rgb(110, 76, 52), noren = rgb(170, 30, 36), mark = "GRILL", vsign = "G\nR\nI\nL\nL", vbg = rgb(170, 30, 36), vtext = white, vneon = rgb(255, 225, 60), lantern = true },
			{ h = 13.4, body = rgb(44, 40, 44), wood = rgb(80, 200, 230), noren = rgb(30, 110, 200), mark = "GAMES", vsign = "A\nR\nC\nA\nD\nE", vbg = rgb(20, 30, 60), vtext = rgb(80, 230, 255), vneon = rgb(80, 230, 255) },
			{ h = 12.6, body = rgb(150, 110, 74), wood = rgb(70, 48, 36), noren = rgb(240, 180, 40), mark = "COMICS", kanban = "COMICS", vbg = rgb(250, 210, 60), vtext = rgb(40, 30, 20) },
		},
	}
	for tag, list in houses do
		local s = (tag == "N") and 1 or -1
		local idx = 0
		for _, sgm in { { 201, 219.4, 2 }, { 260.6, 299, 4 } } do
			local w = (sgm[2] - sgm[1]) / sgm[3]
			for k = 0, sgm[3] - 1 do
				idx += 1
				local x0, x1 = sgm[1] + k * w, sgm[1] + (k + 1) * w
				local fr = (s > 0) and CFrame.new(x0, 0, 19.85) or (CFrame.new(x1, 0, -19.85) * CFrame.Angles(0, math.pi, 0))
				house("House_" .. tag .. idx, fr, w, list[idx])
			end
		end
	end

	-- Cerisiers en fleurs : sur les trottoirs (tronc solide, branches et fleurs sans collision) et,
	-- plus grands, derrière les murets
	local Tr = folder("Trees")
	local bark = rgb(92, 62, 52)
	local function sakura(name, x, z, big)
		local m = Instance.new("Model"); m.Name = name; m.Parent = Tr
		local k = big and 1.6 or 1
		local s = (z > 0) and 1 or -1
		local y0 = big and 0 or 0.3
		if not big then Bx(m, W, "Pit", x - 0.9, 0.3, z - 0.9, x + 0.9, 0.33, z + 0.9, rgb(70, 58, 50), { decor = true, noShadow = true }) end
		vcyl(m, "Trunk", x, y0, y0 + 6.2 * k, z, 0.9 * k, bark, big and { decor = true } or nil)
		local top = y0 + 6.2 * k
		seg(m, "Branch_1", Vector3.new(x, top - 1.0 * k, z), Vector3.new(x - 1.7 * k, top + 1.1 * k, z - s * 0.5 * k), 0.4 * k, 0.4 * k, bark, { decor = true })
		seg(m, "Branch_2", Vector3.new(x, top - 0.8 * k, z), Vector3.new(x + 1.7 * k, top + 1.0 * k, z + s * 0.4 * k), 0.4 * k, 0.4 * k, bark, { decor = true })
		for i, b in { { 0, 2.4, 0, 4.6, 1 }, { -1.9, 1.7, -0.5, 3.6, 2 }, { 1.9, 1.9, 0.3, 3.8, 3 }, { 0.4, 3.8, 0.5, 3.4, 2 }, { -0.7, 1.4, 1.1, 3.0, 1 } } do
			ball(m, "Blossom_" .. i, Vector3.new(x + b[1] * k, top + b[2] * k, z + s * b[3] * k), b[4] * k, pinks[b[5]], { decor = true })
		end
		if not big then
			for i, p in { { 1.3, -1.2, 20 }, { -1.5, -0.4, 55 }, { 0.6, -2.0, 80 } } do
				P(m, "Petal_" .. i, CFrame.new(x + p[1], 0.336, z + s * p[2]) * CFrame.Angles(0, math.rad(p[3]), 0), Vector3.new(0.5, 0.03, 0.5), pinks[i], { decor = true, noShadow = true })
			end
		end
	end
	for _, t in { { 210.2, 18.9 }, { 270.2, 18.9 }, { 279.8, 18.9 }, { 289.4, 18.9 }, { 210.2, -18.9 }, { 270.2, -18.9 }, { 279.8, -18.9 }, { 296.0, -18.9 } } do
		sakura(string.format("Sakura_%s%d", (t[2] > 0) and "N" or "S", math.floor(t[1])), t[1], t[2], false)
	end
	for _, t in { { 213, 27 }, { 292, 27 }, { 213, -26.5 }, { 266, -27 } } do
		sakura(string.format("SakuraBig_%s%d", (t[2] > 0) and "N" or "S", t[1]), t[1], t[2], true)
	end

	-- Distributeurs automatiques contre les maisons (solides), poteaux électriques avec lampes et fils,
	-- guirlandes de lanternes rouges et blanches au-dessus de la rue (à plus de 11 studs)
	local Pr = folder("Props")
	local function bottles(part, face)
		local g = Instance.new("SurfaceGui"); g.Name = "BottlesGui"; g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 40; g.LightInfluence = 0
		local cols = { rgb(232, 60, 60), rgb(60, 160, 230), rgb(250, 200, 40), rgb(80, 190, 90), rgb(240, 130, 40), rgb(160, 90, 220) }
		for r = 0, 2 do
			for c = 0, 5 do
				local f = Instance.new("Frame"); f.Name = "Bottle"; f.BorderSizePixel = 0
				f.BackgroundColor3 = cols[(r * 2 + c) % #cols + 1]
				f.Size = UDim2.new(1 / 6, -6, 1 / 3, -10); f.Position = UDim2.new(c / 6, 3, r / 3, 6)
				local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0.3, 0); cr.Parent = f
				f.Parent = g
			end
		end
		g.Parent = part
	end
	local function vending(name, x0, s, body)
		local m = Instance.new("Model"); m.Name = name; m.Parent = Pr
		local zf, zb = s * 18.2, s * 19.8
		local face = (s > 0) and Enum.NormalId.Front or Enum.NormalId.Back
		local function fz(d) return s * (18.2 - d) end
		Bx(m, W, "Body", x0, 0.3, zf, x0 + 2.2, 6.0, zb, body, { studs = true })
		local disp = Bx(m, W, "Display", x0 + 0.2, 3.2, fz(0.06), x0 + 2.0, 5.6, zf, rgb(240, 244, 250), { decor = true })
		bottles(disp, face)
		Bx(m, W, "Buttons", x0 + 0.2, 2.85, fz(0.07), x0 + 2.0, 3.05, zf, rgb(80, 230, 255), neon())
		Bx(m, W, "CoinPanel", x0 + 1.45, 1.7, fz(0.06), x0 + 2.0, 2.6, zf, rgb(180, 184, 192), { decor = true })
		Bx(m, W, "Tray", x0 + 0.3, 0.7, fz(0.08), x0 + 1.9, 1.4, zf, rgb(25, 25, 30), { decor = true })
	end
	vending("Vending_N1", 201.4, 1, rgb(220, 40, 50))
	vending("Vending_N2", 203.7, 1, rgb(245, 245, 248))
	vending("Vending_N3", 280.6, 1, rgb(40, 110, 200))
	vending("Vending_S1", 214.8, -1, rgb(40, 160, 90))
	vending("Vending_S2", 217.1, -1, rgb(220, 40, 50))
	vending("Vending_S3", 285.0, -1, rgb(245, 245, 248))
	local concrete, steel = rgb(170, 170, 164), rgb(120, 120, 116)
	for _, x in { 206, 217.5, 264.5, 276.5, 292.8 } do
		for _, s in { 1, -1 } do
			local tag = ((s > 0) and "N" or "S") .. math.floor(x)
			local z = s * 15.85
			vcyl(Pr, "Pole_" .. tag, x, 0.3, 15.5, z, 0.75, concrete)
			Bx(Pr, W, "PoleArm_" .. tag, x - 0.15, 13.55, s * 15.1, x + 0.15, 13.8, s * 17.6, steel, { decor = true })
			if x == 206 or x == 264.5 or x == 292.8 then vcyl(Pr, "Transformer_" .. tag, x, 10.3, 12.0, z + s * 0.8, 0.9, rgb(150, 154, 150), { decor = true }) end
			seg(Pr, "LampArm_" .. tag, Vector3.new(x, 9.0, z), Vector3.new(x, 9.4, z + s * 1.4), 0.15, 0.15, steel, { decor = true })
			local head = Bx(Pr, W, "LampHead_" .. tag, x - 0.3, 8.95, z + s * 1.15, x + 0.3, 9.25, z + s * 1.75, rgb(240, 250, 255), neon())
			local pl = Instance.new("PointLight"); pl.Color = rgb(235, 245, 255); pl.Range = 18; pl.Brightness = 0.9; pl.Shadows = false; pl.Parent = head
		end
	end
	for _, s in { 1, -1 } do
		local tag = (s > 0) and "N" or "S"
		for _, sgm in { { 206, 217.5 }, { 264.5, 292.8 } } do
			for k, y in { 13.2, 14.1 } do
				Bx(Pr, W, "Wire_" .. tag .. math.floor(sgm[1]) .. "_" .. k, sgm[1], y, s * 15.85 - 0.04, sgm[2], y + 0.08, s * 15.85 + 0.04, rgb(30, 30, 30), { decor = true, noShadow = true })
			end
		end
	end
	for _, x in { 206, 276.5 } do
		Bx(Pr, W, "FestivalWire_" .. math.floor(x), x - 0.04, 12.7, -15.85, x + 0.04, 12.78, 15.85, rgb(30, 30, 30), { decor = true, noShadow = true })
		for k = -3, 3 do
			local col = (k % 2 == 0) and rgb(226, 64, 48) or rgb(250, 244, 230)
			vcyl(Pr, "FestivalLantern_" .. math.floor(x) .. "_" .. (k + 4), x, 11.3, 12.4, k * 4, 0.85, col, neon())
			vcyl(Pr, "FestivalCap_" .. math.floor(x) .. "_" .. (k + 4), x, 12.4, 12.7, k * 4, 0.55, black, { decor = true })
		end
	end

	-- Repères derrière les murets : pagode à cinq toits (nord, près du torii), tour d'antenne (sud)
	local Lm = folder("Landmarks")
	do
		local m = Instance.new("Model"); m.Name = "Pagoda"; m.Parent = Lm
		local cx, cz = 198, 33
		local dk = { decor = true }
		Bx(m, W, "Platform", cx - 5.5, 0, cz - 5.5, cx + 5.5, 1.2, cz + 5.5, stone, { decor = true, studs = true })
		for i = 0, 4 do
			local y0, bw = 1.2 + i * 5.0, 3.6 - i * 0.45
			local rw = bw + 2.2
			Bx(m, W, "Body_" .. (i + 1), cx - bw, y0, cz - bw, cx + bw, y0 + 3.4, cz + bw, red, { decor = true, studs = true })
			Bx(m, W, "Bracket_" .. (i + 1), cx - bw - 0.35, y0 + 2.85, cz - bw - 0.35, cx + bw + 0.35, y0 + 3.4, cz + bw + 0.35, rgb(64, 150, 130), dk)
			Bx(m, W, "Eave_" .. (i + 1), cx - rw, y0 + 3.4, cz - rw, cx + rw, y0 + 3.85, cz + rw, tile, { decor = true, studs = true })
			Bx(m, W, "EaveTop_" .. (i + 1), cx - rw + 1.0, y0 + 3.85, cz - rw + 1.0, cx + rw - 1.0, y0 + 4.4, cz + rw - 1.0, tile, { decor = true, studs = true })
		end
		vcyl(m, "Spire", cx, 25.6, 33.6, cz, 0.35, gold, { decor = true, mat = Enum.Material.Metal })
		for k = 0, 4 do vcyl(m, "SpireRing_" .. (k + 1), cx, 27 + k, 27.25 + k, cz, 1.1 - k * 0.1, gold, { decor = true, mat = Enum.Material.Metal }) end
		ball(m, "SpireJewel", Vector3.new(cx, 33.9, cz), 0.8, gold, { decor = true, mat = Enum.Material.Metal })
	end
	do
		local m = Instance.new("Model"); m.Name = "RadioTower"; m.Parent = Lm
		local cx, cz = 284, -40
		local orange, wh = rgb(255, 90, 30), rgb(245, 245, 240)
		local dk = { decor = true }
		for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local p0 = Vector3.new(cx + c[1] * 6, 0, cz + c[2] * 6)
			local p1 = Vector3.new(cx + c[1] * 3.6, 19, cz + c[2] * 3.6)
			local p2 = Vector3.new(cx + c[1] * 1.4, 44, cz + c[2] * 1.4)
			seg(m, "LegLow_" .. i, p0, p1, 0.9, 0.9, orange, dk)
			seg(m, "LegHigh_" .. i, p1, p2, 0.7, 0.7, orange, dk)
		end
		for k, b in { { 9.5, 4.85 }, { 30, 2.7 } } do
			local y, hw = b[1], b[2]
			Bx(m, W, "Brace_" .. k .. "N", cx - hw, y, cz + hw - 0.2, cx + hw, y + 0.4, cz + hw + 0.2, wh, dk)
			Bx(m, W, "Brace_" .. k .. "S", cx - hw, y, cz - hw - 0.2, cx + hw, y + 0.4, cz - hw + 0.2, wh, dk)
			Bx(m, W, "Brace_" .. k .. "E", cx + hw - 0.2, y, cz - hw, cx + hw + 0.2, y + 0.4, cz + hw, wh, dk)
			Bx(m, W, "Brace_" .. k .. "W", cx - hw - 0.2, y, cz - hw, cx - hw + 0.2, y + 0.4, cz + hw, wh, dk)
		end
		Bx(m, W, "MainDeck", cx - 4.4, 18, cz - 4.4, cx + 4.4, 21, cz + 4.4, wh, { decor = true, studs = true })
		Bx(m, W, "MainDeckWindows", cx - 4.45, 19.0, cz - 4.45, cx + 4.45, 20.2, cz + 4.45, rgb(60, 90, 130), { decor = true, mat = Enum.Material.Glass })
		Bx(m, W, "TopDeck", cx - 2.4, 33, cz - 2.4, cx + 2.4, 34.6, cz + 2.4, wh, { decor = true, studs = true })
		Bx(m, W, "TopPlate", cx - 1.8, 44, cz - 1.8, cx + 1.8, 45, cz + 1.8, orange, dk)
		vcyl(m, "Antenna_1", cx, 45, 52, cz, 0.7, wh, dk)
		vcyl(m, "Antenna_2", cx, 52, 58, cz, 0.4, orange, dk)
		ball(m, "AntennaLight", Vector3.new(cx, 58.3, cz), 0.7, rgb(255, 40, 40), neon())
	end

	S.Parent = Z
	print(string.format("Zone 3 Tokyo : rue posée (Street_Tokyo), %d pièces", count))
end
