--!nocheck
-- Zone 3 — Tokyo (MOD-021) : magasin d'électronique, magasin de jeux vidéo et décor de rue.
-- À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS tools/clement/store_builder.luau.
-- Relançable : les modèles du même nom sont remplacés. Trois blocs, à envoyer ensemble ou un par un
-- (le bloc 1 pose _G.ClaudeTokyo, lu par le bloc 2) :
--   1) façade de temple et habillage intérieur ; 2) greybox et magasins ; 3) rue Map/Zone_3/Street_Tokyo.
-- Gabarit du 2026-11-07 (L-039) : magasins et décor ×1.5, pivots (240, 0, ±66), façades à z = ±30,
-- couloir de 60 studs (chaussée z -22.5..22.5), sol du quartier jusqu'à |z| 140.
-- Lampadaires et lanternes (rue et façades) : tag NightLight, livrés éteints ; le code les allume la nuit (L-043).
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
			-- lanterne livrée éteinte et taggée NightLight : le code l'allume la nuit (Neon et lumière, L-043)
			local body = vcyl("Lantern_" .. i, x, 6.05, 7.5, z, 1.05, T.lantern, d(F, { mat = Enum.Material.SmoothPlastic, noShadow = true }))
			vcyl("LanternCapBot_" .. i, x, 5.8, 6.05, z, 0.75, lac, d(F))
			if i % 2 == 1 then
				local pl = Instance.new("PointLight"); pl.Range = 10; pl.Brightness = 0.6; pl.Color = T.lanternLight; pl.Shadows = false; pl.Enabled = false; pl.Parent = body
			end
			game:GetService("CollectionService"):AddTag(body, "NightLight")
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
		-- Au gabarit ×1.5, l'ouverture fait 12 studs (testée aux pivots 240, 0, ±66 : 11 chemins sur 11).
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
-- BLOC 2 : greybox, puis les deux magasins dans Map/Zone_3 (gabarit du 2026-11-07 : ×1.5)
------------------------------------------------------------------------------------------------
do
	local rgb = Color3.fromRGB
	local Store, Tokyo = _G.ClaudeStore, _G.ClaudeTokyo
	assert(Store, "charger d'abord tools/clement/store_builder.luau")
	assert(Tokyo, "lancer d'abord le bloc 1 de ce fichier")
	local SCALE = 1.5   -- option scale du constructeur : magasin agrandi autour de son pivot, contrat compris

	-- Greybox de la zone 3 : magasins gris rangés ; chaussée z -22.5..22.5 ; côtés à |z| 22.5..62.5 ;
	-- murets à z ±(30..31.5), 18 de haut, hors de l'emprise des magasins (x 210..270) ; arche ×1.5,
	-- base au sol. Couleurs de la zone : chaussée indigo, sol de gravier clair (repris par le bloc 3).
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
	local function put(p, x0, y0, z0, x1, y1, z1)
		p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0); p.Position = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	end
	put(g.Street, 190, -2, -22.5, 300, 0, 22.5)
	put(g.Side_N, 190, -2, 22.5, 300, 0, 62.5)
	put(g.Side_S, 190, -2, -62.5, 300, 0, -22.5)
	put(g.SideWall_N1, 190, 0, 30, 210, 18, 31.5)
	put(g.SideWall_S1, 190, 0, -31.5, 210, 18, -30)
	put(g.SideWall_N2, 270, 0, 30, 300, 18, 31.5)
	put(g.SideWall_S2, 270, 0, -31.5, 300, 18, -30)
	for _, p in { g.Street, g.Side_N, g.Side_S } do p.Material = Enum.Material.Plastic; p.MaterialVariant = "Studs" end
	g.Street.Color = rgb(52, 48, 76); g.Side_N.Color = rgb(218, 206, 194); g.Side_S.Color = rgb(218, 206, 194)
	local gate = gz.ZoneGate_3   -- même nom, même tag, même structure ; ScaleTo fixe l'échelle absolue (relançable)
	gate:ScaleTo(SCALE)
	local gcf, gsize = gate:GetBoundingBox()
	gate:PivotTo(gate:GetPivot() + Vector3.new(190 - gcf.X, gsize.Y / 2 - gcf.Y, -gcf.Z))

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
		origin = CFrame.new(240, 0, 66), parent = zoneFolder, scale = SCALE,
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
		origin = CFrame.new(240, 0, -66) * CFrame.Angles(0, math.pi, 0), parent = zoneFolder, scale = SCALE,
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
	-- Constructeur chargé avant l'option scale : on agrandit ici, même résultat. ScaleTo ne touche pas
	-- la portée des lumières : on l'agrandit d'autant.
	for _, m in { elec, game_ } do
		if math.abs(m:GetScale() - SCALE) > 1e-3 then m:ScaleTo(SCALE) end
		for _, d in m:GetDescendants() do if d:IsA("Light") then d.Range = math.min(60, d.Range * SCALE) end end
	end
	print(string.format("Zone 3 Tokyo : électronique %d produits (%d pièces), jeux vidéo %d produits (%d pièces)",
		elecN, #elec:GetDescendants(), gameN, #game_:GetDescendants()))
end

------------------------------------------------------------------------------------------------
-- BLOC 3 : rue et quartier, Map/Zone_3/Street_Tokyo (gabarit du 2026-11-07, L-039 : tout ×1.5,
-- couloir de 60 studs). Chaussée z -22.5..22.5 libre : marquages au sol seulement, rien de suspendu
-- sous 16,5 studs. Trottoirs à |z| 22.5..30, 0,45 de haut. Façades plaquées sur les murets
-- (z ±30..31.5), sans collision. Sol du quartier jusqu'à |z| 140, haies en limite de zone.
-- Entrée (x 190..210) : dallage, grand torii et sa lanterne, enceinte du temple, bannières, pagode
-- (62 studs, visible de loin), sanctuaire, clocher, jardin sec. Sortie (x 270..300) : maisons,
-- immeubles à néons, tour d'antenne (87 studs). Derrière les magasins : cerisiers et immeubles.
-- Pétales qui tombent des cerisiers et au-dessus de l'entrée (ParticleEmitter, aucun script).
-- Chaque objet est dessiné à l'échelle 1 autour de son repère, puis agrandi ×1.5 (Model:ScaleTo :
-- pièces, SurfaceGui et particules suivent, pas la portée des lumières, donnée à sa valeur finale).
------------------------------------------------------------------------------------------------
do
	local rgb = Color3.fromRGB
	local Tokyo = _G.ClaudeTokyo
	assert(Tokyo, "lancer d'abord le bloc 1 de ce fichier")
	local Z = workspace.Map:FindFirstChild("Zone_3")
	assert(Z, "lancer d'abord le bloc 2 de ce fichier")
	local K = 1.5
	local old = Z:FindFirstChild("Street_Tokyo"); if old then old:Destroy() end
	local S = Instance.new("Folder"); S.Name = "Street_Tokyo"; S.Parent = Z
	local function group(name) local f = Instance.new("Model"); f.Name = name; return f end
	local function flush(f) f.Parent = S; task.wait() end   -- chaque section entre d'un bloc dans le Workspace
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
	local function with(opt, k, v) local o = {}; for a, b in (opt or {}) do o[a] = b end; o[k] = v; return o end
	local function Bx(parent, fr, name, x0, y0, z0, x1, y1, z1, color, opt)
		local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
		return P(parent, name, fr * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), size, color, opt)
	end
	local function vcyl(parent, name, x, y0, y1, z, dia, color, opt)
		return P(parent, name, CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(y1 - y0, dia, dia), color, with(opt, "shape", Enum.PartType.Cylinder))
	end
	local function disc(parent, name, x, y, z, dia, color)   -- disque posé à plat (mousse)
		return P(parent, name, CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.06, dia, dia), color, { decor = true, noShadow = true, shape = Enum.PartType.Cylinder })
	end
	local function seg(parent, name, a, b, w, h, color, opt)   -- pièce de a à b (jamais verticale)
		return P(parent, name, CFrame.lookAt((a + b) / 2, b), Vector3.new(w, h, (b - a).Magnitude), color, opt)
	end
	local function ball(parent, name, pos, dia, color, opt)
		return P(parent, name, CFrame.new(pos), Vector3.new(dia, dia, dia), color, with(opt, "shape", Enum.PartType.Ball))
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
	local function light(part, color, range, brightness)
		local pl = Instance.new("PointLight"); pl.Color = color; pl.Range = range; pl.Brightness = brightness; pl.Shadows = false; pl.Parent = part
	end
	-- lampadaires et lanternes : tag NightLight sur la partie lumineuse, livrée éteinte (pas de Neon,
	-- lumières coupées) ; le code l'allume la nuit (Neon et lumières, L-043). Ni enseignes ni néons décoratifs.
	local CS = game:GetService("CollectionService")
	local function nightLight(part)
		if part.Material == Enum.Material.Neon then part.Material = Enum.Material.SmoothPlastic end
		for _, l in part:GetDescendants() do if l:IsA("Light") then l.Enabled = false end end
		CS:AddTag(part, "NightLight")
		return part
	end
	-- objet de décor : modèle dessiné à l'échelle 1 autour du repère A, puis agrandi ×K autour de A
	local function item(parent, name) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end
	local function grow(m, A) m.WorldPivot = A; m:ScaleTo(K); return m end
	local function vc(m, A, name, x, y0, y1, z, dia, color, opt)   -- cylindre vertical au point (x, z) du repère A
		local p = A:PointToWorldSpace(Vector3.new(x, 0, z))
		return vcyl(m, name, p.X, y0, y1, p.Z, dia, color, opt)
	end
	local W = CFrame.identity
	local red, black, gold = rgb(206, 52, 38), rgb(30, 28, 32), rgb(222, 178, 60)
	local tile, tileDark, plaster, stone = rgb(58, 62, 74), rgb(40, 43, 52), rgb(238, 232, 218), rgb(150, 146, 138)
	local white, steel = rgb(245, 245, 240), rgb(120, 120, 116)
	local pinks = { rgb(255, 183, 213), rgb(255, 208, 228), rgb(244, 150, 190) }
	local GROUND, MOSS = rgb(218, 206, 194), rgb(104, 136, 74)   -- GROUND = teinte de Side_N et Side_S (bloc 2)
	local function neon() return { decor = true, mat = Enum.Material.Neon, noShadow = true } end
	local function metal() return { decor = true, mat = Enum.Material.Metal } end
	-- pétales de cerisier : petits carrés roses (texture livrée avec le client) qui tournoient en tombant
	local function petals(part, rate, box)
		local e = Instance.new("ParticleEmitter"); e.Name = "Petals"
		e.Texture = "rbxasset://textures/particles/SquareParticle.png"
		e.Color = ColorSequence.new(rgb(255, 200, 222), rgb(246, 150, 192))
		e.LightInfluence = 0.6
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3, 0.08), NumberSequenceKeypoint.new(1, 0.24, 0.06) })
		e.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, 0.7), NumberSequenceKeypoint.new(0.5, -0.5), NumberSequenceKeypoint.new(0.75, 0.7), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(6, 9)
		e.Rate = rate
		e.Speed = NumberRange.new(0.4, 1.2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0.5, -1.4, 0.3)
		e.Drag = 0.5
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-140, 140)
		e.Shape = box and Enum.ParticleEmitterShape.Box or Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Parent = part
		return e
	end

	-- 1) Sol du quartier (|z| 62.5..140), bordures, trottoirs, bande podotactile, dallage de pierre à
	-- l'entrée, lignes de rive, pointillés, passage piéton, lignes d'arrêt, losanges (circulation à gauche)
	local G = group("Ground")
	for _, s in { 1, -1 } do
		local tag = (s > 0) and "N" or "S"
		Bx(G, W, "Land_" .. tag, 190, -2, s * 62.5, 300, 0, s * 140, GROUND, { studs = true })
		Bx(G, W, "Kerb_" .. tag, 190, 0, s * 22.5, 300, 0.45, s * 23.25, rgb(226, 222, 216), { studs = true })
		Bx(G, W, "Pavement_" .. tag, 190, 0, s * 23.25, 300, 0.45, s * 30, rgb(200, 188, 186), { studs = true })
		Bx(G, W, "TactileStrip_" .. tag, 190, 0.45, s * 24.6, 300, 0.5, s * 25.5, rgb(250, 205, 30), { decor = true, noShadow = true })
		for _, sg in { { 209.5, 234.75 }, { 245.25, 300 } } do
			flat(G, "EdgeLine_" .. tag .. sg[1], Vector3.new(sg[1], 0, s * 21.45), Vector3.new(sg[2], 0, s * 21.45), 0.3)
		end
	end
	for c = 0, 2 do
		for r = 0, 4 do
			local x0, z0 = 191.2 + c * 6, -22.3 + r * 9
			Bx(G, W, "EntryPaving_" .. (c * 5 + r + 1), x0, 0, z0, x0 + 5.6, 0.05, z0 + 8.6,
				((c + r) % 2 == 0) and rgb(202, 196, 186) or rgb(184, 178, 170), { decor = true, noShadow = true })
		end
	end
	local nd = 0
	for x = 211, 292, 9 do   -- pointillés, sauf sur les repères de patrouille de nuit et au passage piéton
		local x1 = x + 4.5
		local blocked = (x1 > 215 and x < 220) or (x1 > 232 and x < 248) or (x1 > 270 and x < 275)
		if not blocked then nd += 1; flat(G, "CenterDash_" .. nd, Vector3.new(x, 0, 0), Vector3.new(x1, 0, 0), 0.375) end
	end
	for i = 0, 11 do
		local z0 = -20.7 + i * 3.6
		Bx(G, W, "Crosswalk_" .. (i + 1), 235.5, 0, z0, 244.5, 0.04, z0 + 1.8, white, { decor = true, noShadow = true })
	end
	flat(G, "StopLine_E", Vector3.new(233.1, 0, -21), Vector3.new(233.1, 0, -0.45), 0.675)
	flat(G, "StopLine_W", Vector3.new(246.9, 0, 0.45), Vector3.new(246.9, 0, 21), 0.675)
	for i, c in { { 219, -10.5 }, { 261, 10.5 } } do
		local v = { Vector3.new(c[1] - 4.5, 0, c[2]), Vector3.new(c[1], 0, c[2] - 2.4), Vector3.new(c[1] + 4.5, 0, c[2]), Vector3.new(c[1], 0, c[2] + 2.4) }
		for k = 1, 4 do flat(G, "Diamond_" .. i .. "_" .. k, v[k], v[k % 4 + 1], 0.375) end
	end
	flush(G)

	-- 2) Entrée (arche x = 190) : grand torii au-dessus de la rue et sa lanterne de papier, enceinte du
	-- temple plaquée sur les murets (jusqu'à x 209, avant l'angle du magasin), bannières, lanternes de
	-- pierre, pluie de pétales au-dessus de l'entrée
	local Sh = group("Entrance")
	local function toro(parent, name, A, y0)   -- lanterne de pierre ; base à y0 (0,3 sur un trottoir, 0 au sol)
		local m = item(parent, name)
		local function b(n, x0, ya, z0, x1, yb, z1, c, o) return Bx(m, A, n, x0, y0 + ya, z0, x1, y0 + yb, z1, c, o) end
		b("Base", -0.8, 0, -0.8, 0.8, 0.5, 0.8, stone, { studs = true })
		vc(m, A, "Post", 0, y0 + 0.5, y0 + 2.5, 0, 0.7, stone)
		b("Deck", -0.75, 2.5, -0.75, 0.75, 2.8, 0.75, stone, { decor = true })
		b("Box", -0.5, 2.8, -0.5, 0.5, 3.7, 0.5, stone, { decor = true })
		local glow = b("Glow", -0.52, 3.0, -0.52, 0.52, 3.5, 0.52, rgb(255, 214, 140), { decor = true, noShadow = true })
		light(glow, rgb(255, 200, 130), 14, 0.7)
		nightLight(glow)
		b("Roof", -0.95, 3.7, -0.95, 0.95, 4.0, 0.95, stone, { decor = true })
		b("Cap", -0.55, 4.0, -0.55, 0.55, 4.3, 0.55, stone, { decor = true })
		b("Finial", -0.2, 4.3, -0.2, 0.2, 4.6, 0.2, stone, { decor = true })
		return grow(m, A)
	end
	local function nobori(parent, name, A, text, bg, fg)   -- bannière verticale sur mât, tournée vers la rue (-z du repère)
		local m = item(parent, name)
		vc(m, A, "Pole", 0, 0.3, 10.6, 0, 0.25, black)
		vc(m, A, "PoleBase", 0, 0.3, 0.7, 0, 0.9, stone)
		Bx(m, A, "TopArm", -0.05, 9.95, -1.5, 0.05, 10.1, 0, black, { decor = true })
		local flag = Bx(m, A, "Banner", -0.05, 3.6, -1.45, 0.05, 9.9, -0.15, bg, { decor = true, noShadow = true })
		label(flag, Enum.NormalId.Left, text, fg, 40, bg)
		label(flag, Enum.NormalId.Right, text, fg, 40, bg)
		return grow(m, A)
	end
	do   -- torii : 43 studs de haut une fois agrandi, piliers sur les trottoirs (z ±27), lanterne à plus de 23 studs
		local A = CFrame.new(200, 0, 0)
		local m = item(Sh, "Torii")
		for _, s in { 1, -1 } do
			local tag = (s > 0) and "N" or "S"
			vcyl(m, "Pillar_" .. tag, 200, 0.3, 27, s * 18, 1.6, red)
			vcyl(m, "PillarBase_" .. tag, 200, 0.3, 1.4, s * 18, 2.0, black)
		end
		Bx(m, W, "Nuki", 199.5, 21.5, -21, 200.5, 22.4, 21, red, { decor = true })
		Bx(m, W, "Shimaki", 199.45, 26.0, -20.6, 200.55, 26.9, 20.6, red, { decor = true })
		Bx(m, W, "Kasagi", 199.25, 26.9, -16, 200.75, 28.0, 16, black, { decor = true })
		for i, s in { 1, -1 } do
			seg(m, "KasagiEnd_" .. i, Vector3.new(200, 27.45, s * 15.9), Vector3.new(200, 28.6, s * 22.8), 1.5, 1.1, black, { decor = true })
		end
		local plaque = Bx(m, W, "Plaque", 199.6, 22.4, -1.1, 200.4, 26.0, 1.1, black, { decor = true })
		label(plaque, Enum.NormalId.Left, "T\nO\nK\nY\nO", gold, 40)
		label(plaque, Enum.NormalId.Right, "T\nO\nK\nY\nO", gold, 40)
		Bx(m, W, "LanternCord", 199.95, 20.7, -0.05, 200.05, 21.5, 0.05, black, { decor = true, noShadow = true })
		vcyl(m, "LanternTop", 200, 20.1, 20.7, 0, 3.0, black, { decor = true })
		local body = vcyl(m, "Lantern", 200, 16.1, 20.1, 0, 4.0, rgb(214, 40, 36), { decor = true })
		for k, y in { 16.7, 19.3 } do vcyl(m, "LanternRib_" .. k, 200, y, y + 0.2, 0, 4.06, black, { decor = true }) end
		vcyl(m, "LanternBottom", 200, 15.7, 16.1, 0, 3.0, black, { decor = true })
		light(body, rgb(255, 170, 120), 30, 0.8)
		nightLight(body)
		grow(m, A)
	end
	for _, s in { 1, -1 } do
		local tag = (s > 0) and "N" or "S"
		local rot = (s > 0) and CFrame.identity or CFrame.Angles(0, math.pi, 0)
		Bx(Sh, W, "ShrineWall_" .. tag, 191.6, 0, s * 29.8, 209, 18.6, s * 31.8, plaster, { studs = true, decor = true })
		Bx(Sh, W, "ShrineWallBase_" .. tag, 191.6, 0.45, s * 29.65, 209, 2.4, s * 29.8, stone, { decor = true })
		Bx(Sh, W, "ShrineWallBand_" .. tag, 191.6, 14.2, s * 29.65, 209, 15.4, s * 29.8, red, { decor = true })
		seg(Sh, "ShrineWallCoping_" .. tag, Vector3.new(200.3, 18.2, s * 28.9), Vector3.new(200.3, 20.0, s * 32.0), 17.4, 0.6, tile, { decor = true, studs = true })
		nobori(Sh, "Nobori_" .. tag .. "1", CFrame.new(193.2, 0, s * 28.6) * rot, "S\nA\nK\nU\nR\nA", white, red)
		nobori(Sh, "Nobori_" .. tag .. "2", CFrame.new(196.6, 0, s * 28.6) * rot, "T\nO\nK\nY\nO", red, white)
		toro(Sh, "StoneLantern_" .. tag, CFrame.new(203.6, 0, s * 27.4), 0.3)
	end
	local shower = Bx(Sh, W, "PetalShower", 191, 20, -21, 209, 22, 21, pinks[1], { decor = true, noShadow = true })
	shower.Transparency = 1; shower.CanQuery = false
	petals(shower, 7, true)
	flush(Sh)

	-- 3) Maisons de bois (machiya) plaquées sur les murets de la sortie (x 271.2..298.4, entre l'angle du
	-- magasin et le pilier de l'arche 4) : treillis, noren, auvent, fenêtre à barreaux, toit de tuiles,
	-- enseigne verticale ou panneau. Le muret reste le vrai mur.
	local H = group("Houses")
	local function house(name, fr, w, st)
		local m = item(H, name)
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
		if st.vsign then   -- enseigne verticale au bout droit de la maison, ou au bout gauche (vsignLeft)
			local top = math.min(13.0, h - 0.6)
			local vx = st.vsignLeft and 0.55 or (w - 0.85)
			local vs = Bx(m, fr, "VSign", vx, 8.0, -2.3, vx + 0.3, top, -0.3, st.vbg, dk)
			label(vs, Enum.NormalId.Left, st.vsign, st.vtext, 30)
			label(vs, Enum.NormalId.Right, st.vsign, st.vtext, 30)
			Bx(m, fr, "VSignNeon", vx - 0.05, 7.9, -2.5, vx + 0.35, top + 0.1, -2.3, st.vneon or white, neon())
		else
			local kb = Bx(m, fr, "Kanban", w * 0.18, 11.3, -0.2, w * 0.82, 12.5, 0, st.vbg, dk)
			label(kb, Enum.NormalId.Front, st.kanban, st.vtext, 40)
		end
		grow(m, fr)
	end
	local houses = {
		N = {
			{ h = 12.8, body = rgb(236, 230, 216), wood = rgb(90, 62, 42), noren = rgb(40, 90, 60), mark = "TEA", kanban = "TEA HOUSE", vbg = rgb(60, 40, 28), vtext = white },
			{ h = 13.5, body = rgb(74, 52, 40), wood = rgb(150, 108, 70), noren = rgb(170, 30, 36), mark = "RAMEN", vsign = "R\nA\nM\nE\nN", vbg = rgb(200, 30, 40), vtext = white, vneon = rgb(255, 225, 60) },
		},
		S = {   -- au sud, l'enseigne du karaoké passe au bout est, loin de l'auvent de tuiles du magasin
			{ h = 15.0, body = rgb(44, 40, 44), wood = rgb(120, 90, 160), noren = rgb(120, 40, 160), mark = "SING", vsign = "K\nA\nR\nA\nO\nK\nE", vsignLeft = true, vbg = rgb(30, 20, 50), vtext = rgb(255, 120, 220), vneon = rgb(255, 70, 180) },
			{ h = 13.0, body = rgb(236, 230, 216), wood = rgb(110, 76, 52), noren = rgb(200, 120, 160), mark = "SWEETS", kanban = "SWEET SHOP", vbg = rgb(240, 150, 190), vtext = white },
		},
	}
	local hw = 13.6   -- largeur d'une maison une fois agrandie
	for tag, list in houses do
		local s = (tag == "N") and 1 or -1
		for k = 0, 1 do
			local x0, x1 = 271.2 + k * hw, 271.2 + (k + 1) * hw
			local fr = (s > 0) and CFrame.new(x0, 0, 29.85) or (CFrame.new(x1, 0, -29.85) * CFrame.Angles(0, math.pi, 0))
			house("House_" .. tag .. (k + 1), fr, hw / K, list[k + 1])
		end
	end
	flush(H)

	-- 4) Cerisiers : deux sur les trottoirs (tronc solide, couronne entre 12 et 20 studs, au-dessus du
	-- trottoir seulement), les grands dans l'enceinte du temple et derrière les magasins ; tous lâchent
	-- des pétales
	local Tr = group("Trees")
	local bark = rgb(92, 62, 52)
	local function sakura(name, x, z, big)
		local A = CFrame.new(x, 0, z)
		local m = item(Tr, name)
		local k = big and 1.6 or 1        -- branches
		local bk = big and 1.6 or 0.9     -- couronne
		local s = (z > 0) and 1 or -1
		local y0 = big and 0 or 0.3
		local function L(a, b, c) return Vector3.new(x + a, b, z + c) end
		if big then disc(m, "Moss", x, 0.03, z, 8, MOSS)
		else Bx(m, W, "Pit", x - 0.5, 0.3, z - 0.5, x + 0.5, 0.33, z + 0.5, rgb(70, 58, 50), { decor = true, noShadow = true }) end
		local top = y0 + (big and 6.2 * k or 8)
		vcyl(m, "Trunk", x, y0, top, z, 0.9 * k, bark, big and { decor = true } or nil)
		seg(m, "Branch_1", L(0, top - 1.0 * k, 0), L(-1.7 * k, top + 1.1 * k, -s * 0.5 * k), 0.4 * k, 0.4 * k, bark, { decor = true })
		seg(m, "Branch_2", L(0, top - 0.8 * k, 0), L(1.7 * k, top + 1.0 * k, s * 0.4 * k), 0.4 * k, 0.4 * k, bark, { decor = true })
		for i, b in { { 0, 2.4, 0, 4.6, 1 }, { -1.9, 1.7, -0.5, 3.6, 2 }, { 1.9, 1.9, 0.3, 3.8, 3 }, { 0.4, 3.8, 0.5, 3.4, 2 }, { -0.7, 1.4, 0.6, 3.0, 1 } } do
			ball(m, "Blossom_" .. i, L(b[1] * bk, top + b[2] * bk, s * b[3] * bk), b[4] * bk, pinks[b[5]], { decor = true })
		end
		for i = 1, (big and 5 or 3) do   -- pétales tombés au sol
			local a = i * 2.4
			local r = (big and 2.6 or 1.2) + (i % 2) * 0.8
			P(m, "Petal_" .. i, CFrame.new(x + math.cos(a) * r, y0 + 0.036, z + math.sin(a) * r) * CFrame.Angles(0, a, 0), Vector3.new(0.5, 0.03, 0.5), pinks[i % 3 + 1], { decor = true, noShadow = true })
		end
		grow(m, A)
		petals(m.Blossom_1, big and 3 or 2)
	end
	sakura("Sakura_N281", 281, 26.4, false)
	sakura("Sakura_S289", 289.8, -26.4, false)
	for _, t in { { 199.5, 63 }, { 199.5, 102 }, { 199.5, 126 }, { 220, 110 }, { 240, 110 }, { 260, 110 },
		{ 199.5, -41 }, { 199.5, -112 }, { 199.5, -132 }, { 220, -110 }, { 240, -110 }, { 260, -110 } } do
		sakura(string.format("SakuraBig_%s%d_%d", (t[2] > 0) and "N" or "S", math.floor(t[1]), math.abs(t[2])), t[1], t[2], true)
	end
	flush(Tr)

	-- 5) Distributeurs contre les maisons (à côté des portes), poteaux électriques (lampes côté trottoir),
	-- fils, guirlandes de lanternes au-dessus de la rue (bas des lanternes à 16,95 studs)
	local Pr = group("Props")
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
	local function vending(name, x0, s, body)   -- x0 = bord ouest une fois agrandi
		local A = (s > 0) and CFrame.new(x0, 0, 29.7) or (CFrame.new(x0 + 2.2 * K, 0, -29.7) * CFrame.Angles(0, math.pi, 0))
		local m = item(Pr, name)
		Bx(m, A, "Body", 0, 0.3, -1.6, 2.2, 6.0, 0, body, { studs = true })
		local disp = Bx(m, A, "Display", 0.2, 3.2, -1.66, 2.0, 5.6, -1.6, rgb(240, 244, 250), { decor = true })
		bottles(disp, Enum.NormalId.Front)
		Bx(m, A, "Buttons", 0.2, 2.85, -1.67, 2.0, 3.05, -1.6, rgb(80, 230, 255), neon())
		Bx(m, A, "CoinPanel", 1.45, 1.7, -1.66, 2.0, 2.6, -1.6, rgb(180, 184, 192), { decor = true })
		Bx(m, A, "Tray", 0.3, 0.7, -1.68, 1.9, 1.4, -1.6, rgb(25, 25, 30), { decor = true })
		grow(m, A)
	end
	vending("Vending_N1", 285.2, 1, rgb(220, 40, 50))
	vending("Vending_N2", 288.6, 1, rgb(245, 245, 248))
	vending("Vending_S1", 277.6, -1, rgb(40, 160, 90))
	vending("Vending_S2", 281.0, -1, rgb(40, 110, 200))
	local concrete = rgb(170, 170, 164)
	local function pole(name, x, s, transformer, lamp)
		local A = (s > 0) and CFrame.new(x, 0, 23.8) or (CFrame.new(x, 0, -23.8) * CFrame.Angles(0, math.pi, 0))
		local m = item(Pr, name)
		vc(m, A, "Pole", 0, 0.3, 15.5, 0, 0.75, concrete)
		Bx(m, A, "Arm", -0.15, 13.55, -0.5, 0.15, 13.8, 1.8, steel, { decor = true })
		if transformer then vc(m, A, "Transformer", 0, 10.3, 12.0, 0.8, 0.9, rgb(150, 154, 150), { decor = true }) end
		if lamp then
			seg(m, "LampArm", A:PointToWorldSpace(Vector3.new(0, 9.0, 0)), A:PointToWorldSpace(Vector3.new(0, 9.4, 1.4)), 0.15, 0.15, steel, { decor = true })
			local head = Bx(m, A, "LampHead", -0.3, 8.95, 1.15, 0.3, 9.25, 1.75, rgb(240, 250, 255), { decor = true, noShadow = true })
			light(head, rgb(235, 245, 255), 27, 0.9)
			nightLight(head)
		end
		grow(m, A)
	end
	for _, s in { 1, -1 } do
		local tag = (s > 0) and "N" or "S"
		pole("Pole_" .. tag .. "205", 205.6, s, true, true)
		pole("Pole_" .. tag .. "274", 274.5, s, false, true)
		pole("Pole_" .. tag .. "294", 294, s, true, s > 0)   -- au sud, pas de lampe : le cerisier est à côté
		for k, y in { 19.8, 21.15 } do
			Bx(Pr, W, "Wire_" .. tag .. k, 274.5, y, s * 23.8 - 0.06, 294, y + 0.1, s * 23.8 + 0.06, rgb(30, 30, 30), { decor = true, noShadow = true })
		end
	end
	for _, x in { 205.6, 274.5 } do
		local nm = tostring(math.floor(x))
		Bx(Pr, W, "FestivalWire_" .. nm, x - 0.06, 19.05, -23.8, x + 0.06, 19.17, 23.8, rgb(30, 30, 30), { decor = true, noShadow = true })
		for k = -3, 3 do
			local col = (k % 2 == 0) and rgb(226, 64, 48) or rgb(250, 244, 230)
			nightLight(vcyl(Pr, "FestivalLantern_" .. nm .. "_" .. (k + 4), x, 16.95, 18.6, k * 6, 1.275, col, { decor = true, noShadow = true }))
			vcyl(Pr, "FestivalCap_" .. nm .. "_" .. (k + 4), x, 18.6, 19.05, k * 6, 0.825, black, { decor = true })
		end
	end
	flush(Pr)

	-- 6) Enceinte du temple, entre l'arche et les magasins (x 190..210) : pagode à cinq toits au nord
	-- (62 studs, repère visible de loin), petit sanctuaire, clocher et jardin sec au sud, lanternes, haies
	local Tm = group("Temple")
	do   -- pagode : toits plus étroits en haut pour rester sous l'avant-toit du magasin voisin (x 205,35)
		local A = CFrame.new(198.9, 0, 47)
		local m = item(Tm, "Pagoda")
		local function L(x, y, z) return A:PointToWorldSpace(Vector3.new(x, y, z)) end
		local function b(n, x0, y0, z0, x1, y1, z1, c, o) return Bx(m, A, n, x0, y0, z0, x1, y1, z1, c, o) end
		b("Platform", -5.5, 0, -5.5, 5.5, 1.2, 5.5, stone, { studs = true })
		b("Steps", -2, 0, -6.6, 2, 0.6, -5.5, stone, { studs = true })
		for i = 0, 4 do
			local y0, bw = 1.2 + i * 6.2, 3.6 - i * 0.55
			local rw = bw + 1.8
			local n = tostring(i + 1)
			b("Body_" .. n, -bw, y0, -bw, bw, y0 + 4.4, bw, red, { studs = true, decor = true })
			b("Door_" .. n, -bw * 0.45, y0 + 0.6, -bw - 0.06, bw * 0.45, y0 + 3.4, -bw, rgb(46, 34, 28), { decor = true })
			b("Bracket_" .. n, -bw - 0.35, y0 + 3.85, -bw - 0.35, bw + 0.35, y0 + 4.4, bw + 0.35, rgb(64, 150, 130), { decor = true })
			b("Eave_" .. n, -rw, y0 + 4.4, -rw, rw, y0 + 4.9, rw, tile, { studs = true, decor = true })
			b("EaveTop_" .. n, -rw + 1, y0 + 4.9, -rw + 1, rw - 1, y0 + 5.5, rw - 1, tileDark, { studs = true, decor = true })
			for j, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
				seg(m, "EaveTip_" .. n .. "_" .. j, L(c[1] * (rw - 0.7), y0 + 4.65, c[2] * (rw - 0.7)), L(c[1] * (rw + 0.2), y0 + 5.6, c[2] * (rw + 0.2)), 0.6, 0.4, tileDark, { decor = true })
			end
		end
		vc(m, A, "Spire", 0, 31.5, 40.5, 0, 0.35, gold, metal())
		for k = 0, 5 do vc(m, A, "SpireRing_" .. (k + 1), 0, 33 + k * 1.1, 33.25 + k * 1.1, 0, 1.2 - k * 0.1, gold, metal()) end
		ball(m, "SpireJewel", L(0, 40.8, 0), 0.9, gold, metal())
		grow(m, A)
	end
	do   -- petit sanctuaire (hokora) et son torii, au nord derrière la pagode
		local A = CFrame.new(199.5, 0, 88)
		local m = item(Tm, "Shrine")
		local function L(x, y, z) return A:PointToWorldSpace(Vector3.new(x, y, z)) end
		local function b(n, x0, y0, z0, x1, y1, z1, c, o) return Bx(m, A, n, x0, y0, z0, x1, y1, z1, c, o) end
		b("Base", -3.5, 0, -3.5, 3.5, 0.8, 3.5, stone, { studs = true })
		b("Hall", -2.6, 0.8, -1.8, 2.6, 4.4, 2.6, rgb(120, 78, 46), { studs = true, decor = true })
		for i, x in { -2.45, 2.45 } do vc(m, A, "Post_" .. i, x, 0.8, 4.6, -2.0, 0.45, red, { decor = true }) end
		local door = b("Doors", -1.6, 0.9, -1.86, 1.6, 3.9, -1.8, rgb(250, 242, 222), { decor = true })
		Tokyo.lattice(door, Enum.NormalId.Front, rgb(60, 40, 28), 6, 4)
		b("Beam", -2.8, 4.4, -2.2, 2.8, 4.8, -1.8, red, { decor = true })
		seg(m, "Roof_F", L(0, 4.5, -3.6), L(0, 6.7, -0.1), 6.8, 0.4, tile, { decor = true, studs = true })
		seg(m, "Roof_B", L(0, 4.5, 4.3), L(0, 6.7, 0.1), 6.8, 0.4, tile, { decor = true, studs = true })
		b("Ridge", -3.4, 6.5, -0.35, 3.4, 7.1, 0.35, tileDark, { decor = true })
		b("OfferingBox", -1.2, 0.8, -3.3, 1.2, 1.8, -2.3, rgb(90, 58, 36), { decor = true })
		for i, x in { -1.7, 1.7 } do vc(m, A, "ToriiPost_" .. i, x, 0, 4.6, -6, 0.4, red, { decor = true }) end
		b("ToriiNuki", -2.1, 3.6, -6.15, 2.1, 3.9, -5.85, red, { decor = true })
		b("ToriiKasagi", -2.7, 4.6, -6.25, 2.7, 5.05, -5.75, black, { decor = true })
		grow(m, A)
	end
	do   -- clocher (shoro) au sud : quatre poteaux rouges, toit de tuiles à coins relevés, cloche de bronze
		local A = CFrame.new(200, 0, -64) * CFrame.Angles(0, math.pi, 0)
		local m = item(Tm, "BellTower")
		local function L(x, y, z) return A:PointToWorldSpace(Vector3.new(x, y, z)) end
		local function b(n, x0, y0, z0, x1, y1, z1, c, o) return Bx(m, A, n, x0, y0, z0, x1, y1, z1, c, o) end
		local bronze = rgb(122, 98, 62)
		b("Base", -4, 0, -4, 4, 1.2, 4, stone, { studs = true })
		for i, c in { { -2.9, -2.9 }, { 2.9, -2.9 }, { -2.9, 2.9 }, { 2.9, 2.9 } } do vc(m, A, "Post_" .. i, c[1], 1.2, 7.6, c[2], 0.55, red, { decor = true }) end
		b("Beam_F", -3.2, 7.2, -3.15, 3.2, 7.7, -2.65, red, { decor = true })
		b("Beam_B", -3.2, 7.2, 2.65, 3.2, 7.7, 3.15, red, { decor = true })
		b("Beam_L", -3.15, 7.2, -3.2, -2.65, 7.7, 3.2, red, { decor = true })
		b("Beam_R", 2.65, 7.2, -3.2, 3.15, 7.7, 3.2, red, { decor = true })
		b("Eave", -5, 7.7, -5, 5, 8.2, 5, tile, { decor = true, studs = true })
		b("RoofMid", -3.8, 8.2, -3.8, 3.8, 9.0, 3.8, tile, { decor = true, studs = true })
		b("RoofTop", -2.4, 9.0, -2.4, 2.4, 9.8, 2.4, tileDark, { decor = true, studs = true })
		b("RoofCap", -1.0, 9.8, -1.0, 1.0, 10.4, 1.0, tileDark, { decor = true })
		ball(m, "Finial", L(0, 10.8, 0), 0.8, gold, metal())
		for j, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			seg(m, "EaveTip_" .. j, L(c[1] * 4.3, 7.95, c[2] * 4.3), L(c[1] * 5.4, 8.8, c[2] * 5.4), 0.6, 0.4, tileDark, { decor = true })
		end
		b("BellHanger", -0.15, 6.6, -0.15, 0.15, 7.2, 0.15, black, { decor = true })
		ball(m, "BellCrown", L(0, 6.0, 0), 2.2, bronze, metal())
		vc(m, A, "Bell", 0, 3.6, 6.0, 0, 2.2, bronze, metal())
		vc(m, A, "BellLip", 0, 3.4, 3.7, 0, 2.4, bronze, metal())
		b("StrikerRope_1", -0.04, 4.9, -2.6, 0.04, 7.2, -2.52, rgb(200, 180, 140), { decor = true, noShadow = true })
		b("StrikerRope_2", -0.04, 4.9, -1.6, 0.04, 7.2, -1.52, rgb(200, 180, 140), { decor = true, noShadow = true })
		b("Striker", -0.25, 4.6, -3.2, 0.25, 5.0, -1.2, rgb(150, 110, 70), { decor = true })
		grow(m, A)
	end
	toro(Tm, "StoneLantern_N1", CFrame.new(193.5, 0, 60), 0)
	toro(Tm, "StoneLantern_N2", CFrame.new(204.5, 0, 60), 0)
	toro(Tm, "StoneLantern_N3", CFrame.new(194, 0, 77), 0)
	toro(Tm, "StoneLantern_N4", CFrame.new(205, 0, 77), 0)
	toro(Tm, "StoneLantern_S1", CFrame.new(193.5, 0, -76), 0)
	toro(Tm, "StoneLantern_S2", CFrame.new(206.5, 0, -76), 0)
	-- jardin sec : gravier ratissé, trois rochers sur de la mousse, bordure de pierre
	Bx(Tm, W, "ZenGravel", 192, 0, -100, 208, 0.12, -80, rgb(236, 232, 222), { decor = true, mat = Enum.Material.Sand, noShadow = true })
	for k = 0, 5 do
		local z = -97.6 + k * 3.2
		Bx(Tm, W, "ZenRake_" .. (k + 1), 192.6, 0.12, z, 207.4, 0.16, z + 0.3, rgb(214, 208, 196), { decor = true, noShadow = true })
	end
	for i, r in { { 196.5, -86, 3.4, 2.4, 2.8, rgb(118, 116, 110) }, { 203, -92, 2.6, 1.8, 2.2, rgb(134, 130, 122) }, { 199.5, -95.5, 1.8, 1.2, 1.6, rgb(104, 102, 98) } } do
		disc(Tm, "ZenMoss_" .. i, r[1], 0.15, r[2], r[3] + 2.2, MOSS)
		P(Tm, "ZenRock_" .. i, CFrame.new(r[1], r[4] * 0.35, r[2]) * CFrame.Angles(0.15 * i, i * 0.9, 0.2), Vector3.new(r[3], r[4], r[5]), r[6], { mat = Enum.Material.Slate })
	end
	for i, e in { { 191.6, -100.4, 208.4, -100 }, { 191.6, -80, 208.4, -79.6 }, { 191.6, -100, 192, -80 }, { 208, -100, 208.4, -80 } } do
		Bx(Tm, W, "ZenBorder_" .. i, e[1], 0, e[2], e[3], 0.35, e[4], rgb(120, 116, 108), { decor = true, studs = true })
	end
	local hedge = rgb(70, 112, 62)   -- haies : limite de la zone côté arche et au fond du quartier
	Bx(Tm, W, "Hedge_NW", 190.2, 0, 56, 191.4, 3.5, 139.5, hedge, { studs = true })
	Bx(Tm, W, "Hedge_SW", 190.2, 0, -139.5, 191.4, 3.5, -34.6, hedge, { studs = true })
	Bx(Tm, W, "Hedge_N", 190.2, 0, 139.5, 300, 3.5, 140, hedge, { studs = true })
	Bx(Tm, W, "Hedge_S", 190.2, 0, -140, 300, 3.5, -139.5, hedge, { studs = true })
	flush(Tm)

	-- 7) Ville, côté sortie (x 270..300) et derrière les magasins : immeubles à bandeaux de fenêtres
	-- (un étage sur deux à quatre éclairé en néon), enseignes de toit ou verticales tournées vers la rue,
	-- tour d'antenne rouge et blanche (87 studs, repère visible de loin)
	local Ci = group("City")
	local glass, warm, signDark = rgb(52, 70, 100), rgb(255, 214, 150), rgb(24, 20, 36)
	local function building(name, x0, z0, x1, z1, h, st)
		local m = Instance.new("Model"); m.Name = name; m.Parent = Ci
		local s = (z0 > 0) and 1 or -1             -- la rue est vers z = 0
		local zf = (s > 0) and z0 or z1            -- façade côté rue
		local face = (s > 0) and Enum.NormalId.Front or Enum.NormalId.Back
		Bx(m, W, "Body", x0, 0, z0, x1, h, z1, st.body, { studs = true })
		Bx(m, W, "ShopWindows", x0 - 0.2, 0.6, z0 - 0.2, x1 + 0.2, 3.8, z1 + 0.2, rgb(255, 236, 200), { decor = true })
		Bx(m, W, "Awning", x0 - 0.8, 4.0, z0 - 0.8, x1 + 0.8, 4.5, z1 + 0.8, st.shop, { decor = true, studs = true })
		local n = 0
		for y = 6, h - 4.5, 5 do
			n += 1
			local lit = (n % st.lit == 0)
			Bx(m, W, "Windows_" .. n, x0 - 0.15, y, z0 - 0.15, x1 + 0.15, y + 2.6, z1 + 0.15, lit and st.litColor or glass, lit and neon() or { decor = true })
		end
		Bx(m, W, "Parapet", x0 - 0.3, h, z0 - 0.3, x1 + 0.3, h + 1.2, z1 + 0.3, st.trim, { studs = true, decor = true })
		vcyl(m, "WaterTank", x1 - 4, h + 1.2, h + 5.2, (s > 0) and (z1 - 5) or (z0 + 5), 3.2, rgb(150, 150, 146), { decor = true })
		local ax, az, ah = x0 + 3, (s > 0) and (z1 - 3) or (z0 + 3), st.antenna or 8
		vcyl(m, "Antenna", ax, h + 1.2, h + 1.2 + ah, az, 0.35, steel, { decor = true })
		ball(m, "AntennaLight", Vector3.new(ax, h + 1.4 + ah, az), 0.7, rgb(255, 40, 40), neon())
		if st.roofSign then
			local w = math.min(18, x1 - x0 - 4)
			local cx, zs = (x0 + x1) / 2, zf + s * 2.5
			for i, dx in { -w / 2 + 1.2, w / 2 - 1.2 } do
				Bx(m, W, "SignPost_" .. i, cx + dx - 0.3, h + 1.2, zs - 0.3, cx + dx + 0.3, h + 3.2, zs + 0.3, steel, { decor = true })
			end
			local board = Bx(m, W, "RoofSign", cx - w / 2, h + 3.2, zs - 0.3, cx + w / 2, h + 3.2 + st.signH, zs + 0.3, st.signBg, { decor = true })
			label(board, face, st.roofSign, st.signText, 20, st.signStroke)
			Bx(m, W, "RoofSignNeon", cx - w / 2 - 0.25, h + 2.95, zs - 0.35, cx + w / 2 + 0.25, h + 3.2, zs + 0.35, st.signText, neon())
		end
		if st.blade then   -- enseigne verticale qui dépasse de la façade vers la rue, lisible depuis le couloir
			local bx, zo = x0 + 1.2, zf - s * 3.2
			local y0, y1 = h * 0.3, h * 0.82
			local za, zb = math.min(zf, zo), math.max(zf, zo)
			local board = Bx(m, W, "BladeSign", bx - 0.25, y0, za, bx + 0.25, y1, zb, st.bladeBg, { decor = true })
			label(board, Enum.NormalId.Left, st.blade, st.bladeText, 12, st.bladeStroke)
			label(board, Enum.NormalId.Right, st.blade, st.bladeText, 12, st.bladeStroke)
			Bx(m, W, "BladeNeon_F", bx - 0.3, y0 - 0.3, math.min(zo, zo - s * 0.3), bx + 0.3, y1 + 0.3, math.max(zo, zo - s * 0.3), st.bladeNeon, neon())
			Bx(m, W, "BladeNeon_T", bx - 0.3, y1, za, bx + 0.3, y1 + 0.3, zb, st.bladeNeon, neon())
			Bx(m, W, "BladeNeon_B", bx - 0.3, y0 - 0.3, za, bx + 0.3, y0, zb, st.bladeNeon, neon())
		end
	end
	building("Apartment_N", 277.5, 34, 298, 60, 33, { body = rgb(214, 198, 176), trim = rgb(150, 130, 110), shop = rgb(170, 40, 40), lit = 3, litColor = warm,
		roofSign = "SAKURA", signH = 5, signBg = signDark, signText = rgb(255, 150, 200), signStroke = rgb(90, 20, 60) })
	building("Tower_N1", 274, 66, 296, 96, 66, { body = rgb(58, 66, 84), trim = rgb(40, 44, 56), shop = rgb(30, 110, 200), lit = 4, litColor = rgb(120, 230, 255),
		blade = "H\nO\nT\nE\nL", bladeBg = signDark, bladeText = rgb(120, 230, 255), bladeStroke = rgb(0, 40, 80), bladeNeon = rgb(80, 230, 255) })
	building("Tower_N5", 272, 104, 298, 136, 84, { body = rgb(40, 44, 58), trim = rgb(30, 32, 40), shop = rgb(200, 40, 120), lit = 3, litColor = warm, antenna = 14,
		roofSign = "ANIME", signH = 6, signBg = rgb(255, 225, 60), signText = rgb(200, 30, 60), signStroke = rgb(255, 255, 255) })
	building("Hall_N", 214, 118, 266, 138, 40, { body = rgb(236, 230, 216), trim = red, shop = red, lit = 2, litColor = warm,
		roofSign = "HOTEL SAKURA", signH = 5, signBg = red, signText = white, signStroke = rgb(90, 0, 0) })
	building("Tower_S1", 274, -96, 296, -66, 60, { body = rgb(70, 60, 86), trim = rgb(46, 40, 58), shop = rgb(255, 120, 40), lit = 3, litColor = rgb(255, 120, 220),
		roofSign = "GAME", signH = 6, signBg = signDark, signText = rgb(255, 225, 60), signStroke = rgb(120, 0, 80) })
	building("Tower_S5", 272, -136, 298, -104, 78, { body = rgb(52, 58, 70), trim = rgb(36, 40, 50), shop = rgb(60, 200, 120), lit = 4, litColor = warm, antenna = 12,
		blade = "K\nA\nR\nA\nO\nK\nE", bladeBg = rgb(30, 20, 50), bladeText = rgb(255, 120, 220), bladeStroke = rgb(60, 0, 40), bladeNeon = rgb(255, 70, 180) })
	building("Hall_S", 214, -138, 266, -118, 40, { body = rgb(200, 60, 50), trim = black, shop = rgb(255, 225, 60), lit = 2, litColor = warm,
		roofSign = "ARCADE", signH = 5, signBg = signDark, signText = rgb(80, 230, 255), signStroke = rgb(0, 40, 80) })
	do
		local A = CFrame.new(285, 0, -47)
		local m = item(Ci, "RadioTower")
		local function L(x, y, z) return A:PointToWorldSpace(Vector3.new(x, y, z)) end
		local orange, wh = rgb(255, 90, 30), rgb(245, 245, 240)
		for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			seg(m, "LegLow_" .. i, L(c[1] * 6, 0, c[2] * 6), L(c[1] * 3.6, 19, c[2] * 3.6), 0.9, 0.9, orange, { decor = true })
			seg(m, "LegHigh_" .. i, L(c[1] * 3.6, 19, c[2] * 3.6), L(c[1] * 1.4, 44, c[2] * 1.4), 0.7, 0.7, orange, { decor = true })
		end
		for k, bb in { { 9.5, 4.85 }, { 30, 2.7 } } do
			local y, hw2 = bb[1], bb[2]
			Bx(m, A, "Brace_" .. k .. "N", -hw2, y, hw2 - 0.2, hw2, y + 0.4, hw2 + 0.2, wh, { decor = true })
			Bx(m, A, "Brace_" .. k .. "S", -hw2, y, -hw2 - 0.2, hw2, y + 0.4, -hw2 + 0.2, wh, { decor = true })
			Bx(m, A, "Brace_" .. k .. "E", hw2 - 0.2, y, -hw2, hw2 + 0.2, y + 0.4, hw2, wh, { decor = true })
			Bx(m, A, "Brace_" .. k .. "W", -hw2 - 0.2, y, -hw2, -hw2 + 0.2, y + 0.4, hw2, wh, { decor = true })
		end
		Bx(m, A, "MainDeck", -4.4, 18, -4.4, 4.4, 21, 4.4, wh, { decor = true, studs = true })
		Bx(m, A, "MainDeckWindows", -4.45, 19.0, -4.45, 4.45, 20.2, 4.45, rgb(60, 90, 130), { decor = true, mat = Enum.Material.Glass })
		Bx(m, A, "TopDeck", -2.4, 33, -2.4, 2.4, 34.6, 2.4, wh, { decor = true, studs = true })
		Bx(m, A, "TopPlate", -1.8, 44, -1.8, 1.8, 45, 1.8, orange, { decor = true })
		vc(m, A, "Antenna_1", 0, 45, 52, 0, 0.7, wh, { decor = true })
		vc(m, A, "Antenna_2", 0, 52, 58, 0, 0.4, orange, { decor = true })
		ball(m, "AntennaLight", L(0, 58.3, 0), 0.7, rgb(255, 40, 40), neon())
		grow(m, A)
	end
	flush(Ci)

	local nEmit = 0
	for _, d in S:GetDescendants() do if d:IsA("ParticleEmitter") then nEmit += 1 end end
	print(string.format("Zone 3 Tokyo : rue et quartier posés (Street_Tokyo), %d pièces, %d émetteurs de pétales", count, nEmit))
end
