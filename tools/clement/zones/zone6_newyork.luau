--!nocheck
-- Zone 6 — New York (MOD-024) : banque, salle des coffres et rue du quartier d'affaires.
-- À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS tools/clement/store_builder.luau (avec l'option scale).
-- Relançable : les deux magasins et chaque sous-dossier du décor de rue sont remplacés à l'identique.
-- Six blocs « do ... end » qui ne partagent que _G.ClaudeNY. On peut envoyer tout le fichier d'un coup,
-- ou bloc par bloc dans l'ordre (A1 d'abord) si Studio peine : A1 fonctions communes et façade de la banque,
-- A2 façade de la salle des coffres et intérieur, B greybox, arche et magasins, C rue et mobilier,
-- D1 immeubles de la rue et parking des taxis, D2 terrain, gratte-ciel et fond de ville.
-- Gabarit du 2026-11-07, le même pour toutes les zones : magasins et décor ×1.5, couloir de 60 studs entre les façades.
-- Où : zone x 580..700 ; arche ZoneGate_6 à x = 580 ; EndWall à x = 700. Chaussée z -22.5..22.5 libre de tout obstacle,
-- trottoirs à |z| 22.5..30 (0,45 de haut), façades et murets à |z| = 30, terrain ajouté jusqu'à |z| = 140 et derrière x = 700.
-- Banque : pivot (660, 0, 66), façade vers -Z. Salle des coffres : pivot (660, 0, -66), tournée de 180°.
-- Les fonctions de façade des blocs A travaillent à l'échelle 1 : le constructeur agrandit ensuite tout le magasin (scale).
-- Règles : aucun script laissé dans la map ; noms du contrat 10.4 (Window, WindowFractured, Shutter, Door,
-- Bounds, GuardSpawn, SignPart, ShelfSlot_xx) jamais réutilisés pour le décor ; aucune marque réelle ;
-- tous les textes visibles en anglais.

-- Bloc A1 : fonctions communes et façade de la banque.
do
	local NY = {}
	_G.ClaudeNY = NY
	local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
	local UP = CFrame.Angles(0, 0, math.rad(90))     -- cylindre debout (son axe X passe à la verticale)
	local FACE = CFrame.Angles(0, math.rad(90), 0)   -- cylindre couché vers -Z : sa face Right regarde la rue

	-- Options de pièce pour ctx.B : "solid" = collisions + studs ; nil = décor à studs ; "smooth" = décor lisse.
	local function opts(parent, kind, extra)
		local o = { parent = parent }
		if kind ~= "solid" then o.decor = true end
		if kind == "smooth" then o.studs = false end
		if extra then for k, v in extra do o[k] = v end end
		return o
	end
	-- Cylindre debout, disque tourné vers -Z, boule : en coordonnées du magasin, via ctx.B.
	local function vcyl(B, name, cx, y0, y1, cz, dia, color, o)
		o.shape = CYL; o.rot = UP
		local h, yc = y1 - y0, (y0 + y1) / 2
		return B(name, cx - h / 2, yc - dia / 2, cz - dia / 2, cx + h / 2, yc + dia / 2, cz + dia / 2, color, o)
	end
	local function disc(B, name, cx, cy, dia, z0, z1, color, o)
		o.shape = CYL; o.rot = FACE
		local t, zc = z1 - z0, (z0 + z1) / 2
		return B(name, cx - t / 2, cy - dia / 2, zc - dia / 2, cx + t / 2, cy + dia / 2, zc + dia / 2, color, o)
	end
	local function ball(B, name, cx, cy, cz, dia, color, o)
		o.shape = BALL
		local r = dia / 2
		return B(name, cx - r, cy - r, cz - r, cx + r, cy + r, cz + r, color, o)
	end
	-- WedgePart (le haut de la pente est côté +Z local), décor à studs.
	local function wedge(ctx, parent, name, cf, size, color)
		local w = Instance.new("WedgePart")
		w.Name = name; w.Size = size; w.CFrame = ctx.ORIGIN * cf; w.Color = color; w.Anchored = true
		w.TopSurface = Enum.SurfaceType.Smooth; w.BottomSurface = Enum.SurfaceType.Smooth
		w.Material = Enum.Material.Plastic; w.MaterialVariant = "Studs"
		w.CanCollide = false; w.CanTouch = false
		w.Parent = parent
		return w
	end
	NY.opts, NY.vcyl, NY.disc, NY.ball, NY.wedge = opts, vcyl, disc, ball, wedge

	-- Façade de banque du quartier d'affaires : 4 colonnes de pierre, entablement à frise gravée,
	-- fronton à pièce d'or, toit de cuivre vert. Les pots du constructeur gêneraient les colonnes : retirés.
	-- spec.ny = { stone, stoneDark, gold, goldLight, bronze, bronzeDark, copper, glassDark, awning, frieze, letters, letterStroke }
	function NY.bankFacade(ctx)
		local B, label, N = ctx.B, ctx.label, ctx.spec.ny
		local F = ctx.group("FacadeNY")
		local dec = ctx.model:FindFirstChild("Decor"); if dec then dec:Destroy() end
		local stone, stoneDk, gold, bronze = N.stone, N.stoneDark, N.gold, N.bronze
		-- Colonnes : base et fût solides, chapiteau en décor ; elles encadrent vitrine et porte sans les gêner
		for i, x in { -17, -8.8, 8.8, 17 } do
			local n = "Column_" .. i
			B(n .. "_Plinth", x - 1.4, 0.3, -27.1, x + 1.4, 0.8, -24.3, stoneDk, opts(F, "solid"))
			vcyl(B, n .. "_Torus", x, 0.8, 1.2, -25.7, 2.4, stone, opts(F, "smooth"))
			vcyl(B, n .. "_Shaft", x, 1.2, 12.6, -25.7, 2.0, stone, opts(F, "solid", { studs = false }))
			vcyl(B, n .. "_Echinus", x, 12.6, 13.0, -25.7, 2.4, stone, opts(F, "smooth"))
			B(n .. "_Abacus", x - 1.4, 13.0, -27.1, x + 1.4, 13.4, -24.3, stoneDk, opts(F, "smooth"))
		end
		-- Entablement : architrave, frise gravée, denticules, corniche
		B("Architrave", -20.6, 13.4, -27.1, 20.6, 14.2, -23, stone, opts(F))
		local frieze = B("Frieze", -20.6, 14.2, -26.8, 20.6, 16.2, -23, stone, opts(F))
		label(frieze, Enum.NormalId.Front, N.frieze, N.letters, 40, N.letterStroke)
		B("DentilBand", -20.6, 16.2, -26.8, 20.6, 16.6, -23, stoneDk, opts(F))
		for k = 0, 20 do
			local x = -20 + k * 2
			B("Dentil_" .. (k + 1), x - 0.3, 16.2, -27.25, x + 0.3, 16.6, -26.8, stone, opts(F, "smooth"))
		end
		B("BankCornice", -21, 16.6, -27.7, 21, 17.4, -23, stone, opts(F))
		-- Fronton : tympan de pierre et toit de cuivre (deux demi-triangles chacun), corniches rampantes
		local pw, ph, y0 = 20.6, 6, 17.4
		local L, R = CFrame.Angles(0, math.rad(90), 0), CFrame.Angles(0, math.rad(-90), 0)
		wedge(ctx, F, "Tympanum_L", CFrame.new(-pw / 2, y0 + ph / 2, -25.9) * L, Vector3.new(1, ph, pw), stone)
		wedge(ctx, F, "Tympanum_R", CFrame.new(pw / 2, y0 + ph / 2, -25.9) * R, Vector3.new(1, ph, pw), stone)
		wedge(ctx, F, "CopperRoof_L", CFrame.new(-pw / 2, y0 + ph / 2, -17.85) * L, Vector3.new(15.1, ph, pw), N.copper)
		wedge(ctx, F, "CopperRoof_R", CFrame.new(pw / 2, y0 + ph / 2, -17.85) * R, Vector3.new(15.1, ph, pw), N.copper)
		local slope = math.atan2(ph, pw)
		local len = math.sqrt(pw * pw + ph * ph) + 0.6
		for _, sd in { { "L", -1 }, { "R", 1 } } do
			local s = sd[2]
			local cx, cy = s * (pw / 2 + 0.11), y0 + ph / 2 + 0.38
			B("RakingCornice_" .. sd[1], cx - len / 2, cy - 0.4, -27.7, cx + len / 2, cy + 0.4, -25.4, stone, opts(F, nil, { rot = CFrame.Angles(0, 0, -s * slope) }))
		end
		disc(B, "CoinRim", 0, 19.9, 3.6, -26.7, -26.4, gold, opts(F, "smooth"))
		local coin = disc(B, "CoinFace", 0, 19.9, 3.1, -26.85, -26.65, N.goldLight, opts(F, "smooth"))
		label(coin, Enum.NormalId.Right, "$", N.bronzeDark, 60, N.gold)
		B("Acroterion_Top", -0.5, 23.6, -27.2, 0.5, 24.8, -25.6, gold, opts(F, "smooth"))
		B("Acroterion_L", -21, 17.4, -27.2, -20, 18.4, -25.6, gold, opts(F, "smooth"))
		B("Acroterion_R", 20, 17.4, -27.2, 21, 18.4, -25.6, gold, opts(F, "smooth"))
		B("Attic", -20.3, 10.8, -23, 20.3, 17.4, -10.3, stoneDk, opts(F))   -- comble fermé sous le cuivre
		-- Fenêtre à grille de bronze à gauche, en pendant de la porte (x 11..15), avec le même auvent
		B("BankWindow_Frame", -15.1, 1.6, -24.12, -10.9, 7.3, -24.0, bronze, opts(F, "smooth"))
		B("BankWindow_Glass", -14.7, 2.0, -24.18, -11.3, 6.9, -24.12, N.glassDark, opts(F, "smooth", { mat = Enum.Material.Glass }))
		B("BankWindow_BarV", -13.1, 2.0, -24.24, -12.9, 6.9, -24.18, bronze, opts(F, "smooth"))
		for k, y in { 3.6, 5.3 } do
			B("BankWindow_BarH" .. k, -14.7, y, -24.24, -11.3, y + 0.15, -24.18, bronze, opts(F, "smooth"))
		end
		local run, drop = 2.4, 1.05
		local alen = math.sqrt(run * run + drop * drop)
		B("BankWindow_Canopy", -15.4, 8.9 - drop / 2 - 0.075, -24.6 - run / 2 - alen / 2, -10.6, 8.9 - drop / 2 + 0.075, -24.6 - run / 2 + alen / 2, N.awning, opts(F, "smooth", { rot = CFrame.Angles(-math.atan2(drop, run), 0, 0) }))
		B("BankWindow_Valance", -15.4, 7.25, -27.08, -10.6, 7.9, -26.96, N.awning, opts(F, "smooth"))
	end
end

-- Bloc A2 : façade de la salle des coffres et intérieur commun aux deux magasins.
do
	local NY = _G.ClaudeNY
	assert(NY, "envoyer d'abord le bloc A1")
	local opts, vcyl, disc, ball = NY.opts, NY.vcyl, NY.disc, NY.ball

	-- Façade blindée : la devanture est un coffre-fort géant (porte ronde à volant, boulons, tôles rivetées),
	-- bandes de danger, caméras, bornes anti-bélier. Les pots du constructeur sont retirés.
	-- spec.ny = { steel, steelDark, steelLight, brass, hazard, black, red, green }
	function NY.vaultFacade(ctx)
		local B, N, top = ctx.B, ctx.spec.ny, ctx.facadeTop
		local F = ctx.group("FacadeNY")
		local dec = ctx.model:FindFirstChild("Decor"); if dec then dec:Destroy() end
		local steel, dark, light, brass = N.steel, N.steelDark, N.steelLight, N.brass
		-- Volume derrière la haute façade (comme à Londres)
		B("UpperSide_L", -20.05, 10.8, -23, -19, top, -12, dark, opts(F))
		B("UpperSide_R", 19, 10.8, -23, 20.05, top, -12, dark, opts(F))
		B("UpperBack", -20.05, 10.8, -12, 20.05, top, -11, dark, opts(F))
		B("UpperRoof", -20.05, top, -22.8, 20.05, top + 0.4, -11, ctx.colors.roof, opts(F))
		-- Porte ronde de coffre au-dessus de la vitrine : anneau, battant, volant à 3 rayons, boulons, gonds
		local cy = 13.7
		disc(B, "VaultRing", 0, cy, 9.0, -25.1, -24.6, dark, opts(F, "smooth"))
		disc(B, "VaultDisc", 0, cy, 7.8, -25.5, -25.1, light, opts(F, "smooth"))
		disc(B, "VaultInner", 0, cy, 5.6, -25.65, -25.5, steel, opts(F, "smooth"))
		disc(B, "VaultHub", 0, cy, 1.4, -26.1, -25.65, brass, opts(F, "smooth"))
		for k, a in { 0, 60, 120 } do
			B("VaultSpoke_" .. k, -2.7, cy - 0.175, -25.95, 2.7, cy + 0.175, -25.75, brass, opts(F, "smooth", { rot = CFrame.Angles(0, 0, math.rad(a)) }))
		end
		for k = 0, 5 do
			local a = math.rad(k * 60)
			ball(B, "VaultKnob_" .. k, 2.7 * math.cos(a), cy + 2.7 * math.sin(a), -25.85, 0.6, brass, opts(F, "smooth"))
		end
		for k = 0, 7 do
			local a = math.rad(22.5 + k * 45)
			disc(B, "VaultBolt_" .. k, 4.15 * math.cos(a), cy + 4.15 * math.sin(a), 0.55, -25.3, -25.1, brass, opts(F, "smooth"))
		end
		for k, dy in { 1.6, -2.6 } do
			B("VaultHinge_" .. k, 4.2, cy + dy, -25.5, 5.0, cy + dy + 1.0, -24.6, dark, opts(F, "smooth"))
		end
		-- Tôles rivetées : joints verticaux, rivets des pilastres et du bandeau du haut
		for k, x in { -15.5, -9.5, 9.5, 15.5 } do
			B("PlateSeam_" .. k, x - 0.12, 8.6, -24.7, x + 0.12, 18.3, -24.6, dark, opts(F, "smooth"))
		end
		for _, sx in { -19.6, 19.6 } do
			for k = 0, 7 do
				disc(B, string.format("Rivet_%s%d", sx < 0 and "L" or "R", k), sx, 1.6 + k * 2.5, 0.45, -25.0, -24.85, light, opts(F, "smooth"))
			end
		end
		for k = 0, 8 do
			disc(B, "RivetTop_" .. k, -16 + k * 4, top - 0.6, 0.45, -24.75, -24.6, light, opts(F, "smooth"))
		end
		-- Bandes de danger au pied de la façade, montants blindés autour de la vitrine
		local n = 0
		for _, seg in { { -18.8, -8.0 }, { 8.0, 10.8 }, { 15.2, 18.8 } } do
			local x = seg[1]
			while x < seg[2] - 0.05 do
				local x1 = math.min(x + 1.2, seg[2])
				n += 1
				B("Hazard_" .. n, x, 0.3, -24.4, x1, 1.3, -24.25, (n % 2 == 0) and N.black or N.hazard, opts(F, "smooth"))
				x = x1
			end
		end
		B("ArmorJamb_L", -7.8, 0.3, -24.7, -6.85, 8.6, -24.1, dark, opts(F))
		B("ArmorJamb_R", 6.85, 0.3, -24.7, 7.8, 8.6, -24.1, dark, opts(F))
		-- Clavier à code, gyrophare, caméras, bornes anti-bélier
		B("Keypad", 15.4, 3.4, -24.3, 16.2, 4.6, -24.0, dark, opts(F, "smooth"))
		B("KeypadLight", 15.6, 4.25, -24.36, 16.0, 4.45, -24.3, N.green, opts(F, "smooth", { mat = Enum.Material.Neon }))
		B("BeaconBase", 12.6, 9.1, -25.0, 13.4, 9.3, -24.6, dark, opts(F, "smooth"))
		vcyl(B, "Beacon", 13, 9.3, 9.9, -24.8, 0.6, N.red, opts(F, "smooth", { mat = Enum.Material.Neon }))
		for k, sx in { -16.5, 16.5 } do
			B("CamArm_" .. k, sx - 0.15, 19.4, -25.6, sx + 0.15, 19.7, -24.6, dark, opts(F, "smooth"))
			B("CamBody_" .. k, sx - 0.35, 18.9, -26.7, sx + 0.35, 19.5, -25.4, light, opts(F, "smooth"))
			disc(B, "CamLens_" .. k, sx, 19.2, 0.4, -26.85, -26.7, N.black, opts(F, "smooth"))
		end
		for k, x in { -17, -9.5, 9.5, 17 } do
			vcyl(B, "Bollard_" .. k, x, 0.3, 2.6, -26.4, 0.8, steel, opts(F, "solid", { studs = false }))
			vcyl(B, "BollardBand_" .. k, x, 2.0, 2.3, -26.4, 0.86, N.hazard, opts(F, "smooth"))
		end
	end

	-- Intérieur commun : sol en marbre, caisse changée en 2 guichets (vitres, cordons de velours, lampes
	-- de banquier), porte de coffre ronde au fond (décor, entre le présentoir et la réserve, sans la boucher),
	-- présentoir du fond recoloré. La palette de stock laisse la place à la porte du coffre.
	-- spec.ny (en plus) = { display, pad, glass, velvet, lampShade, signBg, signText, plaqueText, promoPacks }
	function NY.interior(ctx)
		local B, label, N, model = ctx.B, ctx.label, ctx.spec.ny, ctx.model
		local I = model:FindFirstChild("Interior")
		local G = ctx.group("InteriorNY")
		local br = N.brass
		-- 1) sol en marbre, dalles du damier comprises
		local fs = I:FindFirstChild("FloorShop")
		if fs then fs.Material = Enum.Material.Marble; fs.MaterialVariant = "" end
		local tiles = model:FindFirstChild("FloorTiles")
		if tiles then
			for _, t in tiles:GetChildren() do
				if t:IsA("BasePart") then t.Material = Enum.Material.Marble; t.MaterialVariant = "" end
			end
		end
		-- 2) palette retirée ; présentoir, tapis de caisse et têtes de gondole recolorés
		for _, nm in { "Pallet", "Stock_0", "Stock_1", "Stock_2", "Stock_3" } do
			local p = I:FindFirstChild(nm); if p then p:Destroy() end
		end
		for _, p in I:GetChildren() do
			if p:IsA("BasePart") then
				if (p.Name:match("^Fridge_") and p.Name ~= "Fridge_Header") or p.Name:match("^FridgeShelf_") then p.Color = N.display
				elseif p.Name == "CounterBelt" then p.Color = N.pad
				else
					local g, k = p.Name:match("^PromoPack_(%a)(%d)$")
					if g then p.Color = N.promoPacks[tonumber(k) + 1] end
				end
			end
		end
		-- Textes du jeu en anglais (consigne du 2026-11-07) : le constructeur écrit encore « RÉSERVE »
		local rs = model:FindFirstChild("ReserveSign", true)
		local rg = rs and rs:FindFirstChild("LabelGui_Front")
		if rg and rg:FindFirstChild("Label") then rg.Label.Text = "STOCKROOM" end
		-- 3) guichets sur la caisse, côté clients (+Z)
		B("Guichet_Rail", -18.0, 2.8, -21.3, -11.0, 3.0, -21.1, br, opts(G, "smooth"))
		for k, x in { -18.0, -14.6, -11.2 } do
			B("Guichet_Post_" .. k, x, 3.0, -21.3, x + 0.2, 6.4, -21.1, br, opts(G, "smooth"))
		end
		B("Guichet_TopRail", -18.0, 6.2, -21.3, -11.0, 6.4, -21.1, br, opts(G, "smooth"))
		for k, xr in { { -17.8, -14.6 }, { -14.4, -11.2 } } do
			B("Guichet_Glass_" .. k, xr[1], 3.5, -21.24, xr[2], 6.2, -21.16, N.glass, opts(G, "smooth", { mat = Enum.Material.Glass, T = 0.55 }))
			local sg = B("Guichet_Sign_" .. k, xr[1] + 0.4, 6.4, -21.25, xr[2] - 0.4, 7.1, -21.15, N.signBg, opts(G, "smooth"))
			label(sg, Enum.NormalId.Back, "TELLER " .. k, N.signText, 60)
		end
		for k, x in { -16.2, -11.9 } do
			B("BankerLamp_Base_" .. k, x - 0.25, 2.8, -22.6, x + 0.25, 2.95, -22.1, br, opts(G, "smooth"))
			B("BankerLamp_Stem_" .. k, x - 0.05, 2.95, -22.4, x + 0.05, 3.5, -22.3, br, opts(G, "smooth"))
			B("BankerLamp_Shade_" .. k, x - 0.45, 3.5, -22.55, x + 0.45, 3.75, -22.15, N.lampShade, opts(G, "smooth"))
		end
		for k, x in { -17.4, -14.5, -11.6 } do
			vcyl(B, "StanchionBase_" .. k, x, 0.37, 0.47, -19.4, 0.8, br, opts(G, "smooth"))
			vcyl(B, "Stanchion_" .. k, x, 0.47, 2.6, -19.4, 0.22, br, opts(G, "smooth"))
			ball(B, "StanchionTop_" .. k, x, 2.7, -19.4, 0.36, br, opts(G, "smooth"))
		end
		for k, xr in { { -17.4, -14.5 }, { -14.5, -11.6 } } do
			B("VelvetRope_" .. k, xr[1], 2.25, -19.46, xr[2], 2.4, -19.34, N.velvet, opts(G, "smooth"))
		end
		-- 4) porte de coffre ronde contre le mur du fond (x -0.6..7.6), décor sans collision
		local vx, vy = 3.5, 4.6
		local function d(name, dia, z0, z1, color) return disc(B, name, vx, vy, dia, z0, z1, color, opts(G, "smooth")) end
		d("VaultDoor_Frame", 8.2, 22.4, 22.9, N.steelDark)
		d("VaultDoor_Disc", 7.0, 21.8, 22.4, N.steelLight)
		d("VaultDoor_Inner", 4.8, 21.6, 21.8, N.steel)
		d("VaultDoor_Hub", 1.0, 21.1, 21.6, br)
		for k, a in { 0, 60, 120 } do
			B("VaultDoor_Spoke_" .. k, vx - 2.2, vy - 0.15, 21.25, vx + 2.2, vy + 0.15, 21.45, br, opts(G, "smooth", { rot = CFrame.Angles(0, 0, math.rad(a)) }))
		end
		for k = 0, 5 do
			local a = math.rad(k * 60)
			ball(B, "VaultDoor_Knob_" .. k, vx + 2.2 * math.cos(a), vy + 2.2 * math.sin(a), 21.35, 0.5, br, opts(G, "smooth"))
		end
		for k = 0, 7 do
			local a = math.rad(22.5 + k * 45)
			ball(B, "VaultDoor_Bolt_" .. k, vx + 3.75 * math.cos(a), vy + 3.75 * math.sin(a), 22.3, 0.44, br, opts(G, "smooth"))
		end
		for k, dy in { 1.4, -2.4 } do
			B("VaultDoor_Hinge_" .. k, vx + 3.4, vy + dy, 21.9, vx + 4.0, vy + dy + 1.0, 22.4, N.steelDark, opts(G, "smooth"))
		end
		local plq = B("VaultDoor_Plaque", vx - 1.8, 8.85, 22.75, vx + 1.8, 9.55, 22.9, br, opts(G, "smooth"))
		label(plq, Enum.NormalId.Front, N.plaqueText, N.steelDark, 60, br)
	end
end

-- Bloc B : greybox de la zone (gabarit ×1.5 : chaussée de 45 studs, côtés, murets de 18), arche agrandie, les deux magasins.
do
	local NY = _G.ClaudeNY
	local Store = _G.ClaudeStore
	assert(NY and NY.interior, "envoyer d'abord les blocs A1 et A2")
	assert(Store, "charger d'abord tools/clement/store_builder.luau")
	local rgb = Color3.fromRGB
	local K = 1.5   -- gabarit du 2026-11-07, le même pour toutes les zones
	NY.K = K

	-- 1) Greybox de la zone 6 : magasins gris rangés ; chaussée z -22.5..22.5 ; côtés |z| 22.5..62.5 sans chevauchement ;
	--    murets z ±(30..31.5), hauts de 18, hors de l'emprise des magasins (x 630..690) ;
	--    couleurs du quartier : asphalte presque noir (lignes jaunes et voies de bus rouges posées par le bloc C), béton gris
	local SS = game:GetService("ServerStorage")
	local gz6 = workspace.Greybox.Corridor.Zone_6
	for _, nm in { "STORE_Z6_Banque", "STORE_Z6_SalleDesCoffres" } do
		local m = gz6:FindFirstChild(nm)
		if m then
			local keep = SS:FindFirstChild("_GREYBOX_REMPLACE") or Instance.new("Folder")
			keep.Name = "_GREYBOX_REMPLACE"; keep.Parent = SS
			m.Parent = keep
		end
	end
	local g = gz6.Ground
	g.Street.Size = Vector3.new(120, 2, 45); g.Street.Position = Vector3.new(640, -1, 0)
	g.Street.Color = rgb(40, 40, 44); g.Street.Material = Enum.Material.Plastic; g.Street.MaterialVariant = "Studs"
	for _, s in { 1, -1 } do
		local t = s > 0 and "N" or "S"
		local side = g["Side_" .. t]
		side.Size = Vector3.new(120, 2, 40); side.Position = Vector3.new(640, -1, s * 42.5)
		side.Color = rgb(128, 128, 132); side.Material = Enum.Material.Plastic; side.MaterialVariant = "Studs"
		local w1, w2 = g["SideWall_" .. t .. "1"], g["SideWall_" .. t .. "2"]
		w1.Size = Vector3.new(50, 18, 1.5); w1.Position = Vector3.new(605, 9, s * 30.75)
		w2.Size = Vector3.new(10, 18, 1.5); w2.Position = Vector3.new(695, 9, s * 30.75)
	end

	-- 2) Arche ZoneGate_6 : ×1.5 autour de son pivot, puis base à y = 0, centrée sur z = 0, même x (nom, tag et structure inchangés)
	local gate = gz6.ZoneGate_6
	gate:ScaleTo(K)
	local gcf, gsz = gate:GetBoundingBox()
	gate:PivotTo(gate:GetPivot() + Vector3.new(580 - gcf.Position.X, gsz.Y / 2 - gcf.Position.Y, -gcf.Position.Z))

	-- 3) Dossier de la zone
	local zoneFolder = workspace.Map:FindFirstChild("Zone_6")
	if not zoneFolder then zoneFolder = Instance.new("Folder"); zoneFolder.Name = "Zone_6"; zoneFolder.Parent = workspace.Map end
	for _, nm in { "STORE_Z6_Banque", "STORE_Z6_SalleDesCoffres" } do
		local old = zoneFolder:FindFirstChild(nm); if old then old:Destroy() end
	end

	local stone, stoneDark = rgb(228, 220, 200), rgb(198, 188, 164)
	local gold, goldLight, bronze = rgb(212, 172, 60), rgb(250, 214, 100), rgb(104, 74, 40)
	local green, green2 = rgb(28, 76, 60), rgb(38, 96, 76)
	local steel, steelDark, steelLight = rgb(118, 126, 136), rgb(72, 78, 88), rgb(170, 177, 186)
	local brass, hazard, black = rgb(206, 166, 64), rgb(245, 196, 20), rgb(30, 30, 34)

	-- Produits des rayons : liasses de billets, pièces, lingots, petits coffres, tirelires, mallettes
	local designs = {
		liasse = { body = rgb(96, 168, 88), cap = rgb(236, 226, 186), w = 1.0, h = 0.5, ch = 0.12, d = 0.55 },
		liasseV = { body = rgb(70, 140, 110), cap = rgb(236, 226, 186), w = 1.0, h = 0.5, ch = 0.12, d = 0.55 },
		pile = { body = rgb(120, 190, 100), w = 1.0, h = 0.9, d = 0.55 },
		rouleau = { body = rgb(214, 160, 40), cap = rgb(250, 214, 90), w = 0.4, h = 0.95, ch = 0.12, d = 0.4 },
		rouleauA = { body = rgb(180, 186, 196), cap = rgb(228, 232, 238), w = 0.4, h = 0.95, ch = 0.12, d = 0.4 },
		sac = { body = rgb(186, 150, 96), cap = rgb(120, 88, 50), w = 0.8, h = 1.0, ch = 0.25, d = 0.7 },
		sacV = { body = rgb(110, 140, 90), cap = rgb(70, 90, 56), w = 0.8, h = 1.0, ch = 0.25, d = 0.7 },
		lingot = { body = rgb(236, 186, 40), cap = rgb(255, 222, 100), w = 0.9, h = 0.4, ch = 0.1, d = 0.5 },
		lingotA = { body = rgb(196, 202, 210), cap = rgb(236, 240, 245), w = 0.9, h = 0.4, ch = 0.1, d = 0.5 },
		lingotR = { body = rgb(226, 150, 110), cap = rgb(246, 190, 160), w = 0.9, h = 0.4, ch = 0.1, d = 0.5 },
		tirelire = { body = rgb(245, 150, 185), w = 0.8, h = 0.8, ball = true },
		tirelireJ = { body = rgb(255, 205, 60), w = 0.8, h = 0.8, ball = true },
		tirelireB = { body = rgb(120, 190, 240), w = 0.8, h = 0.8, ball = true },
		chequier = { body = rgb(60, 110, 180), cap = rgb(235, 235, 230), w = 0.35, h = 1.0, ch = 0.15, d = 0.8 },
		chequierR = { body = rgb(150, 50, 60), cap = rgb(235, 235, 230), w = 0.35, h = 1.0, ch = 0.15, d = 0.8 },
		coffret = { body = rgb(84, 92, 104), cap = rgb(212, 172, 60), w = 0.8, h = 0.8, ch = 0.12, d = 0.8 },
		coffretR = { body = rgb(150, 40, 44), cap = rgb(212, 172, 60), w = 0.8, h = 0.8, ch = 0.12, d = 0.8 },
		coffretN = { body = rgb(40, 42, 48), cap = rgb(190, 196, 204), w = 0.8, h = 0.8, ch = 0.12, d = 0.8 },
		coffretV = { body = rgb(50, 110, 80), cap = rgb(212, 172, 60), w = 0.8, h = 0.8, ch = 0.12, d = 0.8 },
		mallette = { body = rgb(30, 30, 34), cap = rgb(190, 196, 204), w = 1.1, h = 0.8, ch = 0.1, d = 0.4 },
		malletteA = { body = rgb(180, 186, 196), cap = rgb(60, 64, 70), w = 1.1, h = 0.8, ch = 0.1, d = 0.4 },
		malletteM = { body = rgb(120, 76, 40), cap = rgb(212, 172, 60), w = 1.1, h = 0.8, ch = 0.1, d = 0.4 },
	}

	-- 4) Banque : pierre calcaire, colonnes, fronton, toit de cuivre ; intérieur crème, marbre blanc et vert
	local bank, bankN = Store.build({
		name = "STORE_Z6_Banque", zone = 6, scale = K,
		origin = CFrame.new(660, 0, 66), parent = zoneFolder,
		sign = "BANK",
		signColors = { bg = green, text = goldLight, border = gold },
		signRect = { -6.4, 6.4, 9.4, 12.2 }, facadeTop = 16.4,
		awning = { a = green, b = green2 },
		promo = "SAVINGS",
		colors = {
			wall = rgb(206, 198, 178), front = stone, upper = stone, trim = stoneDark, cornice = stone, pilaster = stone,
			frame = bronze, plinth = rgb(120, 116, 110), roof = rgb(84, 92, 100),
			innerWall = rgb(240, 232, 214), ceiling = rgb(248, 244, 232), floor = rgb(236, 232, 224), tile = rgb(52, 70, 62),
			reserve = steel, shelf = rgb(122, 74, 46), shelfBack = rgb(92, 56, 36), kick = rgb(70, 44, 30), price = gold,
			counter = rgb(110, 66, 40), counterTop = rgb(240, 236, 228), mat = rgb(150, 30, 40), doorKick = gold,
			glass = rgb(200, 225, 240), neon = rgb(255, 240, 205), wood = rgb(122, 74, 46), gold = gold,
			promo = green, promoText = goldLight,
		},
		headers = {
			A_L = { "CASH", rgb(60, 150, 80) }, A_R = { "COINS", rgb(200, 150, 40) },
			B_L = { "GOLD BARS", rgb(214, 172, 60) }, B_R = { "PIGGY BANKS", rgb(232, 110, 150) },
			WallL = { "CHECKBOOKS", rgb(60, 110, 180) }, WallR = { "MINI SAFES", rgb(90, 98, 112) }, Back = { "GOLD DISPLAY", rgb(180, 140, 40) },
		},
		designs = designs,
		pools = {
			A_L = { "liasse", "liasseV", "pile" }, A_R = { "rouleau", "rouleauA", "sac" },
			B_L = { "lingot", "lingotA" }, B_R = { "tirelire", "tirelireJ", "tirelireB" },
			WallL = { "chequier", "chequierR" }, WallR = { "coffret", "coffretR", "coffretN" },
			Back = { "lingot", "rouleau", "lingot", "sac" },
		},
		seed = 6006,
		ny = {
			stone = stone, stoneDark = stoneDark, gold = gold, goldLight = goldLight, bronze = bronze, bronzeDark = rgb(70, 50, 28),
			copper = rgb(98, 166, 146), glassDark = rgb(46, 58, 72), awning = green,
			frieze = "SAVINGS  ·  LOANS  ·  VAULTS", letters = rgb(74, 56, 34), letterStroke = rgb(244, 238, 222),
			steel = steel, steelDark = steelDark, steelLight = steelLight, brass = brass,
			display = rgb(110, 66, 40), pad = rgb(30, 80, 56), glass = rgb(200, 225, 240), velvet = rgb(160, 24, 40),
			lampShade = rgb(30, 120, 70), signBg = green, signText = goldLight, plaqueText = "VAULT",
			promoPacks = { gold, rgb(96, 168, 88), steelLight },
		},
		facade = function(ctx) NY.bankFacade(ctx); NY.interior(ctx) end,
	})

	-- 5) Salle des coffres : façade d'acier blindée, auvent jaune et noir ; intérieur acier, marbre gris et noir
	local vault, vaultN = Store.build({
		name = "STORE_Z6_SalleDesCoffres", zone = 6, scale = K,
		origin = CFrame.new(660, 0, -66) * CFrame.Angles(0, math.pi, 0), parent = zoneFolder,
		sign = "VAULT",
		signColors = { bg = rgb(40, 44, 52), text = hazard, border = hazard },
		signRect = { -11, 11, 18.7, 20.7 }, facadeTop = 22,
		awning = { a = hazard, b = black },
		promo = "SECURITY",
		colors = {
			wall = steelDark, front = steel, upper = steel, trim = steelLight, cornice = steelDark, pilaster = steelDark,
			frame = rgb(50, 54, 62), plinth = rgb(40, 42, 48), roof = rgb(60, 64, 70),
			innerWall = rgb(150, 158, 168), ceiling = rgb(176, 182, 190), floor = rgb(200, 204, 210), tile = rgb(40, 44, 52),
			reserve = rgb(84, 90, 100), shelf = rgb(120, 128, 138), shelfBack = rgb(86, 92, 102), kick = rgb(60, 64, 72), price = hazard,
			counter = rgb(70, 76, 86), counterTop = rgb(200, 204, 210), mat = black, doorKick = hazard,
			glass = rgb(190, 215, 235), neon = rgb(220, 235, 255), wood = rgb(96, 104, 114), gold = gold,
			promo = hazard, promoText = black,
		},
		headers = {
			A_L = { "GOLD", rgb(200, 150, 30) }, A_R = { "SILVER", rgb(130, 138, 150) },
			B_L = { "DEPOSIT BOXES", rgb(84, 92, 104) }, B_R = { "COIN BAGS", rgb(170, 120, 60) },
			WallL = { "BANKNOTES", rgb(60, 150, 80) }, WallR = { "BRIEFCASES", rgb(50, 52, 60) }, Back = { "DEPOSITS", rgb(200, 60, 50) },
		},
		designs = designs,
		pools = {
			A_L = { "lingot", "lingotR" }, A_R = { "lingotA", "rouleauA" },
			B_L = { "coffret", "coffretN", "coffretV" }, B_R = { "sac", "sacV" },
			WallL = { "liasse", "liasseV", "pile" }, WallR = { "mallette", "malletteA", "malletteM" },
			Back = { "coffret", "lingot", "coffretN", "sac" },
		},
		seed = 6060,
		ny = {
			steel = steel, steelDark = steelDark, steelLight = steelLight, brass = brass, hazard = hazard, black = black,
			red = rgb(235, 50, 45), green = rgb(70, 230, 120),
			display = rgb(96, 104, 114), pad = rgb(50, 54, 62), glass = rgb(190, 215, 235), velvet = rgb(160, 24, 40),
			lampShade = rgb(30, 120, 70), signBg = rgb(40, 44, 52), signText = hazard, plaqueText = "VAULT #6",
			promoPacks = { gold, steelLight, rgb(96, 168, 88) },
		},
		facade = function(ctx) NY.vaultFacade(ctx); NY.interior(ctx) end,
	})
	NY.zoneFolder = zoneFolder
	NY.counts = { bank = bankN, vault = vaultN }
end

-- Bloc C : rue, trottoirs, marquages et mobilier (Map/Zone_6/Street_NewYork, sous-dossiers Ground et Props).
-- Chaussée z -22.5..22.5 libre : seulement des marquages plats et des plaques d'égout fumantes, sans collision.
-- Trottoirs à |z| 22.5..30, hauts de 0,45 stud (au niveau du sol des magasins). Le mobilier est construit
-- à l'échelle 1 puis agrandi ×1.5 autour de son ancrage.
do
	local NY = _G.ClaudeNY
	assert(NY, "envoyer d'abord le bloc A1")
	local rgb = Color3.fromRGB
	local K = NY.K or 1.5
	local zoneFolder = workspace.Map:FindFirstChild("Zone_6")
	if not zoneFolder then zoneFolder = Instance.new("Folder"); zoneFolder.Name = "Zone_6"; zoneFolder.Parent = workspace.Map end
	local S = zoneFolder:FindFirstChild("Street_NewYork")
	if not S then S = Instance.new("Folder"); S.Name = "Street_NewYork"; S.Parent = zoneFolder end

	-- Outils du décor de rue (coordonnées du monde ou d'un repère), partagés avec les blocs D
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
	-- Sous-dossier remplacé à chaque lancement (construit hors du jeu, posé à la fin du bloc)
	local function fresh(name)
		local old = S:FindFirstChild(name); if old then old:Destroy() end
		local f = Instance.new("Model"); f.Name = name
		return f
	end
	-- Vapeur des bouches d'égout (objet natif, aucun script) ; k agrandit la vapeur d'une pièce qui ne sera pas mise à l'échelle
	local function steam(part, dir, rate, k)
		k = k or 1
		local e = Instance.new("ParticleEmitter")
		e.Name = "Steam"; e.Texture = "rbxasset://textures/particles/smoke_main.dds"; e.EmissionDirection = dir
		e.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240)); e.LightEmission = 0.1
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * k), NumberSequenceKeypoint.new(1, 5.5 * k) })
		e.Lifetime = NumberRange.new(2.5, 4); e.Rate = rate or 5; e.Speed = NumberRange.new(2.5 * k, 4.5 * k)
		e.SpreadAngle = Vector2.new(12, 12); e.RotSpeed = NumberRange.new(-25, 25); e.Rotation = NumberRange.new(0, 360); e.Drag = 0.6
		e.Parent = part
		return e
	end
	-- Élément construit à l'échelle 1 dans le repère « anchor » (-Z local vers la chaussée), puis agrandi ×K autour de lui.
	-- ScaleTo agrandit pièces, textes et vapeur, pas la portée des lumières : elle est donnée directement en ×K.
	local function scaled(parent, name, anchor, build)
		local m = Instance.new("Model"); m.Name = name
		build(m, anchor)
		m.WorldPivot = anchor
		m:ScaleTo(K)
		m.Parent = parent
		return m
	end
	-- Ancrage d'un côté de la rue : N tel quel (-Z local = chaussée), S tourné de 180°
	local function side(s, x, z)
		if s > 0 then return CFrame.new(x, 0, z) end
		return CFrame.new(x, 0, -z) * CFrame.Angles(0, math.pi, 0)
	end
	NY.street, NY.P, NY.Bx, NY.vcylW, NY.labelW, NY.fresh, NY.steam, NY.scaled, NY.side = S, P, Bx, vcyl, label, fresh, steam, scaled, side

	local W = CFrame.identity
	local yellow, white, iron, busRed = rgb(255, 196, 0), rgb(242, 242, 236), rgb(28, 28, 32), rgb(166, 46, 42)
	local flat = function() return { decor = true, noShadow = true } end

	-- 1) Sol : bordures et trottoirs, doubles lignes jaunes, voies de bus rouges, tirets, passage piéton, plaques d'égout fumantes
	local G = fresh("Ground")
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		Bx(G, W, "Kerb_" .. tag, 580, 0, s * 22.5, 700, 0.45, s * 23.25, rgb(140, 140, 144), { studs = true })
		Bx(G, W, "Pavement_" .. tag, 580, 0, s * 23.25, 700, 0.45, s * 30, rgb(186, 184, 178), { studs = true })
	end
	local cw0, cw1 = 589, 598   -- passage piéton de l'entrée
	for _, seg in { { 580, cw0 - 1.4 }, { cw1 + 1.4, 700 } } do
		for _, zz in { { 0.3, 0.54 }, { -0.54, -0.3 } } do
			Bx(G, W, string.format("YellowLine_%d_%s", seg[1], zz[1] > 0 and "N" or "S"), seg[1], 0, zz[1], seg[2], 0.04, zz[2], yellow, flat())
		end
		for _, s in { 1, -1 } do
			local tag = s > 0 and "N" or "S"
			Bx(G, W, string.format("BusLane_%s%d", tag, seg[1]), seg[1], 0, s * 16.6, seg[2], 0.03, s * 22.4, busRed, flat())
			Bx(G, W, string.format("BusLaneEdge_%s%d", tag, seg[1]), seg[1], 0, s * 16.25, seg[2], 0.04, s * 16.6, white, flat())
		end
	end
	for _, s in { 1, -1 } do
		for _, x0 in { 580.5, 601.5, 616.5, 631.5, 646.5, 661.5, 676.5, 691.5 } do
			Bx(G, W, string.format("LaneDash_%s%d", s > 0 and "N" or "S", x0), x0, 0, s * 8.3, x0 + 6, 0.04, s * 8.6, white, flat())
		end
	end
	for i = 0, 11 do
		local z0 = -20.7 + i * 3.6
		Bx(G, W, "Crosswalk_" .. (i + 1), cw0, 0, z0, cw1, 0.04, z0 + 1.8, white, flat())
	end
	Bx(G, W, "StopLine_N", cw0 - 1.4, 0, 0.9, cw0 - 0.5, 0.04, 21.9, white, flat())
	Bx(G, W, "StopLine_S", cw1 + 0.5, 0, -21.9, cw1 + 1.4, 0.04, -0.9, white, flat())
	for i, pos in { { 607, -10.5 }, { 641, 5 }, { 664, -12.5 }, { 690, 11 } } do
		local mh = vcyl(G, W, "SteamVent_" .. i, pos[1], 0, 0.07, pos[2], 3.6, rgb(64, 62, 60), flat())
		vcyl(G, W, "SteamVentRing_" .. i, pos[1], 0, 0.05, pos[2], 4.2, rgb(40, 40, 42), flat())
		steam(mh, Enum.NormalId.Right, 5, K)
	end
	G.Parent = S

	-- 2) Mobilier des trottoirs, construit à l'échelle 1 puis agrandi (hors des devantures des magasins, x 630..690)
	local D = fresh("Props")
	local poleC = rgb(64, 68, 72)
	-- Lampadaire à crosse : bras et tête au-dessus de la chaussée, sans collision
	local function lamp(m, a)
		Bx(m, a, "Base", -0.5, 0.3, -0.5, 0.5, 1.4, 0.5, poleC, {})
		vcyl(m, a, "Pole", 0, 1.4, 12.3, 0, 0.4, poleC, {})
		Bx(m, a, "Arm", -0.15, 12.0, 0, 0.15, 12.3, -3.2, poleC, { decor = true })
		Bx(m, a, "Head", -0.45, 11.75, -2.6, 0.45, 12.35, -4.0, rgb(150, 156, 162), { decor = true })
		local glow = Bx(m, a, "Glow", -0.35, 11.62, -2.75, 0.35, 11.75, -3.85, rgb(255, 226, 170), { mat = Enum.Material.Neon, decor = true, noShadow = true })
		local pl = Instance.new("PointLight"); pl.Color = rgb(255, 214, 160); pl.Range = 24 * K; pl.Brightness = 1.1; pl.Shadows = false; pl.Parent = glow
	end
	for tag, xs in { N = { 605.5, 627, 694.5 }, S = { 587, 628.5, 696.5 } } do
		local s = tag == "N" and 1 or -1
		for i, x in xs do scaled(D, "StreetLamp_" .. tag .. i, side(s, x, 24.45), lamp) end
	end
	-- Bornes d'incendie
	local hydRed, hydCap = rgb(214, 48, 40), rgb(242, 196, 40)
	local function hydrant(m, a)
		vcyl(m, a, "Flange", 0, 0.3, 0.5, 0, 1.05, hydRed, {})
		vcyl(m, a, "Body", 0, 0.5, 1.9, 0, 0.75, hydRed, {})
		vcyl(m, a, "Bonnet", 0, 1.9, 2.15, 0, 0.95, hydCap, { decor = true })
		vcyl(m, a, "Nut", 0, 2.15, 2.45, 0, 0.32, hydCap, { decor = true })
		P(m, "Outlets", a * CFrame.new(0, 1.35, 0), Vector3.new(1.35, 0.34, 0.34), hydCap, { shape = Enum.PartType.Cylinder, decor = true })
		P(m, "Nozzle", a * CFrame.new(0, 1.15, -0.45) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.6, 0.48, 0.48), hydCap, { shape = Enum.PartType.Cylinder, decor = true })
	end
	for i, pos in { { 1, 611 }, { -1, 626 }, { -1, 584.5 } } do scaled(D, "Hydrant_" .. i, side(pos[1], pos[2], 24.3), hydrant) end
	-- Cheminée de vapeur rayée orange et blanc, à l'entrée de la zone (trottoir sud)
	local orange = rgb(250, 120, 30)
	scaled(D, "SteamStack", side(-1, 603.5, 24.75), function(m, a)
		for k = 0, 3 do vcyl(m, a, "Ring_" .. k, 0, 0.3 + k * 1.2, 1.5 + k * 1.2, 0, 1.5, (k % 2 == 0) and orange or white, {}) end
		steam(vcyl(m, a, "Rim", 0, 5.1, 5.4, 0, 1.7, orange, { decor = true }), Enum.NormalId.Right, 6)
	end)
	-- Kiosque à journaux et ses distributeurs (trottoir sud, guichet face à la chaussée, contre la boutique fermée)
	scaled(D, "NewsKiosk", side(-1, 615, 30), function(m, a)
		local kg, kd = rgb(38, 104, 70), rgb(24, 70, 48)
		Bx(m, a, "Body", -3, 0.3, -3.6, 3, 6.0, -0.4, kg, { studs = true })
		Bx(m, a, "Roof", -3.4, 6.0, -4.3, 3.4, 6.45, -0.1, kd, { decor = true })
		label(Bx(m, a, "SignBand", -3, 6.45, -3.6, 3, 7.65, -2.8, kd, { decor = true }), Enum.NormalId.Front, "NEWS", rgb(255, 214, 90), 40)
		Bx(m, a, "ServiceWindow", -2, 2.9, -3.62, 2, 5.4, -3.55, rgb(40, 48, 56), { decor = true, mat = Enum.Material.Glass })
		Bx(m, a, "Counter", -2.2, 2.6, -4.2, 2.2, 2.85, -3.6, rgb(122, 84, 50), { decor = true })
		for k, c in { { -1.8, rgb(245, 245, 240) }, { -0.4, rgb(250, 214, 220) }, { 1.0, rgb(255, 240, 180) } } do
			Bx(m, a, "Papers_" .. k, c[1], 2.85, -4.1, c[1] + 1.1, 3.25, -3.7, c[2], { decor = true })
		end
		for k, c in { { -2.4, rgb(232, 65, 60) }, { -1.1, rgb(255, 210, 40) }, { 0.2, rgb(46, 134, 222) }, { 1.5, rgb(240, 120, 180) } } do
			Bx(m, a, "Magazines_" .. k, c[1], 0.8, -3.62, c[1] + 1.1, 2.3, -3.52, c[2], { decor = true })
		end
		for k, c in { { 4.0, rgb(40, 90, 170) }, { 5.1, rgb(200, 40, 40) } } do
			Bx(m, a, "NewsBox_" .. k, c[1], 0.3, -3.6, c[1] + 0.9, 2.1, -2.8, c[2], {})
			Bx(m, a, "NewsBoxWindow_" .. k, c[1] + 0.12, 1.2, -3.64, c[1] + 0.78, 1.9, -3.58, rgb(200, 220, 235), { decor = true, mat = Enum.Material.Glass })
		end
	end)
	-- Corbeilles
	for i, pos in { { 1, 616.5 }, { -1, 692 } } do
		scaled(D, "TrashCan_" .. i, side(pos[1], pos[2], 24.6), function(m, a)
			vcyl(m, a, "Can", 0, 0.3, 2.4, 0, 1.3, rgb(56, 104, 64), {})
			vcyl(m, a, "Rim", 0, 2.4, 2.55, 0, 1.4, iron, { decor = true })
		end)
	end
	-- Feux à potence de l'entrée (bras au-dessus de la chaussée, sans collision en hauteur), feu piéton côté passage, plaques de rue
	local function trafficPole(m, a)
		Bx(m, a, "Base", -0.5, 0.3, -0.5, 0.5, 1.3, 0.5, poleC, {})
		vcyl(m, a, "Pole", 0, 1.3, 13.2, 0, 0.45, poleC, {})
		Bx(m, a, "Arm", -0.15, 12.4, 0, 0.15, 12.75, -7.7, poleC, { decor = true })
		local hz = -7.25
		Bx(m, a, "Head", -0.45, 9.6, hz - 0.45, 0.45, 12.4, hz + 0.45, rgb(250, 200, 30), { decor = true })
		for k, c in { { 11.9, rgb(120, 30, 28), false }, { 11.0, rgb(130, 90, 20), false }, { 10.1, rgb(70, 235, 120), true } } do
			Bx(m, a, "Light" .. k, -0.55, c[1] - 0.32, hz - 0.3, 0.55, c[1] + 0.32, hz + 0.3, c[2], { decor = true, mat = c[3] and Enum.Material.Neon or nil })
		end
		Bx(m, a, "Walk", 0.25, 7.6, -0.35, 0.85, 8.6, 0.35, iron, { decor = true })
		Bx(m, a, "WalkHand", 0.85, 7.8, -0.25, 0.9, 8.4, 0.25, rgb(255, 140, 40), { decor = true, mat = Enum.Material.Neon })
		local green = rgb(0, 110, 60)
		local sa = Bx(m, a, "StreetSignA", -2.3, 13.25, -0.05, 2.3, 14.05, 0.05, green, { decor = true })
		label(sa, Enum.NormalId.Front, "WALL ST", rgb(255, 255, 255), 40, green)
		label(sa, Enum.NormalId.Back, "WALL ST", rgb(255, 255, 255), 40, green)
		local sb = Bx(m, a, "StreetSignB", -0.05, 14.15, -2.3, 0.05, 14.95, 2.3, green, { decor = true })
		label(sb, Enum.NormalId.Left, "BROADWAY", rgb(255, 255, 255), 40, green)
		label(sb, Enum.NormalId.Right, "BROADWAY", rgb(255, 255, 255), 40, green)
	end
	scaled(D, "TrafficPole_N", side(1, 586.5, 24.45), trafficPole)    -- avant le passage, côté nord
	scaled(D, "TrafficPole_S", side(-1, 600.5, 24.45), trafficPole)   -- après le passage, côté sud
	-- Bouche de métro au coin de l'entrée (trottoir nord, côté bordure : le passage reste libre devant la tour) :
	-- garde-corps verts, globes verts allumés, enseigne
	scaled(D, "SubwayEntrance", side(1, 597.5, 28), function(m, a)
		local rail, globe = rgb(28, 92, 58), rgb(120, 255, 150)
		Bx(m, a, "Stairwell", -3, 0.3, -3.2, 3, 0.33, -0.8, rgb(18, 18, 22), { decor = true, noShadow = true })
		for k = 0, 2 do
			local x0, c = -3 + k * 0.7, 150 - k * 40
			Bx(m, a, "StepEdge_" .. k, x0, 0.33, -3.2, x0 + 0.12, 0.34, -0.8, rgb(c, c, c), { decor = true, noShadow = true })
		end
		Bx(m, a, "RailFront", -3, 0.3, -3.35, 3.1, 2.4, -3.2, rail, {})
		Bx(m, a, "RailBack", -3, 0.3, -0.8, 3.1, 2.4, -0.65, rail, {})
		Bx(m, a, "RailEnd", 2.95, 0.3, -3.35, 3.1, 2.4, -0.65, rail, {})
		Bx(m, a, "TopRailFront", -3.05, 2.4, -3.4, 3.15, 2.55, -3.15, rail, { decor = true })
		Bx(m, a, "TopRailBack", -3.05, 2.4, -0.85, 3.15, 2.55, -0.6, rail, { decor = true })
		Bx(m, a, "TopRailEnd", 2.9, 2.4, -3.4, 3.15, 2.55, -0.6, rail, { decor = true })
		for k, z in { -3.28, -0.72 } do
			vcyl(m, a, "GlobePost_" .. k, -3.05, 0.3, 3.2, z, 0.22, rail, { decor = true })
			P(m, "Globe_" .. k, a * CFrame.new(-3.05, 3.5, z), Vector3.new(0.7, 0.7, 0.7), globe, { shape = Enum.PartType.Ball, mat = Enum.Material.Neon, decor = true, noShadow = true })
		end
		local sg = Bx(m, a, "Sign", -2.8, 2.6, -3.33, 0.6, 3.3, -3.22, rgb(20, 20, 24), { decor = true })
		label(sg, Enum.NormalId.Front, "SUBWAY", rgb(255, 255, 255), 40)
		label(sg, Enum.NormalId.Back, "SUBWAY", rgb(255, 255, 255), 40)
	end)
	D.Parent = S
end

-- Bloc D1 : immeubles plaqués sur les murets. À l'entrée, deux tours Art déco à panneaux lumineux (esprit Times Square,
-- marquise de théâtre, pomme géante) ; puis des immeubles de brique brune (escaliers de secours, châteaux d'eau, boutiques
-- fermées par un rideau de fer) et, au bout de la rue, un immeuble étroit et le parking à étages des taxis jaunes.
-- Le muret reste le vrai mur : les façades n'ont pas de collision, sauf les marches des perrons.
do
	local NY = _G.ClaudeNY
	assert(NY and NY.scaled, "envoyer d'abord le bloc C")
	local rgb = Color3.fromRGB
	local K = NY.K or 1.5
	local P, Bx, vcyl, label, fresh, scaled, S = NY.P, NY.Bx, NY.vcylW, NY.labelW, NY.fresh, NY.scaled, NY.street
	local iron, stoneT, glassD, lit = rgb(30, 30, 34), rgb(222, 214, 196), rgb(46, 58, 72), rgb(255, 214, 140)
	local gold, bronze = rgb(212, 172, 60), rgb(104, 74, 40)
	local function dk() return { decor = true } end
	-- Repère d'une façade de la rue : origine au pied de la façade (|z| = 29.775, devant le muret), x local le long
	-- de la rue depuis x0 (nord) ou x1 (sud), -Z local vers la chaussée, +Z local derrière le muret.
	local FZ = 29.775
	local function frameFor(side, x0, x1)
		if side == "N" then return CFrame.new(x0, 0, FZ) end
		return CFrame.new(x1, 0, -FZ) * CFrame.Angles(0, math.pi, 0)
	end
	NY.frameFor = frameFor
	local seed = 7
	local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end

	local H = fresh("Buildings")

	-- 1) Tours de l'entrée (nouvelle échelle, construites directement) : socle à panneaux lumineux, fût à bandes de
	-- fenêtres sur les 4 faces, gradins, couronne et flèche visibles de loin.
	-- t = { name, side, x0, x1, stone, dark, crown, ring, h, boards = { { texte, x0, x1, y0, y1, fond, lettres, néon } }, blade, apple }
	local glassC = rgb(52, 64, 80)
	local function gatewayTower(t)
		local m = Instance.new("Model"); m.Name = t.name; m.Parent = H
		local fr = frameFor(t.side, t.x0, t.x1)
		local w = t.x1 - t.x0
		local st, dkC, cr = t.stone, t.dark, t.crown
		local glass = { decor = true, mat = Enum.Material.Glass }
		Bx(m, fr, "Podium", 0, 0, 0, w, 30, 20, st, { studs = true, decor = true })
		Bx(m, fr, "Plinth", 0, 0.45, -0.15, w, 1.8, 0, dkC, dk())
		Bx(m, fr, "LobbyGlass", 2, 1.8, -0.1, w - 2, 9, 0, glassC, glass)
		for k, x in { w / 4, 3 * w / 4 } do Bx(m, fr, "Mullion_" .. k, x - 0.2, 1.8, -0.22, x + 0.2, 9, -0.1, bronze, dk()) end
		Bx(m, fr, "LobbyDoorFrame", w / 2 - 2.4, 0.45, -0.25, w / 2 + 2.4, 8.2, -0.1, gold, dk())
		Bx(m, fr, "LobbyDoor", w / 2 - 2, 0.45, -0.32, w / 2 + 2, 7.8, -0.25, rgb(40, 48, 56), glass)
		Bx(m, fr, "Canopy", w / 2 - 5, 9.2, -3.2, w / 2 + 5, 9.8, 0, bronze, dk())
		Bx(m, fr, "CanopyTrim", w / 2 - 5.1, 9.0, -3.35, w / 2 + 5.1, 9.25, -3.05, gold, dk())
		Bx(m, fr, "Lintel", 0, 9, -0.2, w, 10.2, 0, dkC, dk())
		for k, b in t.boards do
			Bx(m, fr, "BoardGlow_" .. k, b[2] - 0.35, b[4] - 0.35, -0.25, b[3] + 0.35, b[5] + 0.35, -0.05, b[8], { decor = true, mat = Enum.Material.Neon, noShadow = true })
			label(Bx(m, fr, "Board_" .. k, b[2], b[4], -0.4, b[3], b[5], -0.25, b[6], dk()), Enum.NormalId.Front, b[1], b[7], 40)
		end
		-- Enseigne verticale (« blade ») côté arche, au-dessus du trottoir
		local bx = (t.side == "N") and 1.5 or (w - 2.1)
		local blade = Bx(m, fr, "Blade", bx, 10, -4.6, bx + 0.6, 28, -0.4, t.bladeBg, dk())
		local letters = (t.blade:gsub("(.)", "%1\n")):sub(1, -2)
		label(blade, Enum.NormalId.Left, letters, t.bladeText, 40)
		label(blade, Enum.NormalId.Right, letters, t.bladeText, 40)
		Bx(m, fr, "BladeEdge", bx - 0.05, 10, -4.75, bx + 0.65, 28, -4.6, t.bladeText, { decor = true, mat = Enum.Material.Neon, noShadow = true })
		if t.apple then   -- pomme géante sur un socle doré, au bord du toit du socle, au-dessus de son panneau
			local ax = t.apple
			Bx(m, fr, "ApplePedestal", ax - 2.2, 30, -2.4, ax + 2.2, 30.8, 1.6, gold, dk())
			P(m, "Apple", fr * CFrame.new(ax, 34.2, -0.9), Vector3.new(7, 7, 7), rgb(214, 34, 40), { shape = Enum.PartType.Ball, decor = true })
			vcyl(m, fr, "AppleStem", ax, 37.4, 39.2, -0.9, 0.6, rgb(92, 60, 34), dk())
			P(m, "AppleLeaf", fr * CFrame.new(ax + 1.2, 38.6, -0.9) * CFrame.Angles(0, 0, math.rad(-30)), Vector3.new(2.2, 0.3, 1.2), rgb(70, 160, 60), dk())
		end
		-- Fût et gradins : bandes de fenêtres traversantes (une pièce marque deux faces opposées)
		local function tier(i, x0, x1, z0, z1, y0, y1, color, nx, nz, ring)
			Bx(m, fr, "Tier_" .. i, x0, y0, z0, x1, y1, z1, color, { studs = true, decor = true })
			for k = 1, nx do
				local x = x0 + 1 + (x1 - x0 - 2) * (k - 0.5) / nx
				Bx(m, fr, string.format("WinZ_%d_%d", i, k), x - 0.6, y0 + 2, z0 - 0.15, x + 0.6, y1 - 2, z1 + 0.15, glassC, glass)
			end
			for k = 1, nz do
				local z = z0 + 1 + (z1 - z0 - 2) * (k - 0.5) / nz
				Bx(m, fr, string.format("WinX_%d_%d", i, k), x0 - 0.15, y0 + 2, z - 0.6, x1 + 0.15, y1 - 2, z + 0.6, glassC, glass)
			end
			if ring then Bx(m, fr, "Ring_" .. i, x0 - 0.2, y1 - 0.5, z0 - 0.2, x1 + 0.2, y1, z1 + 0.2, ring, { decor = true, mat = Enum.Material.Neon, noShadow = true }) end
		end
		tier(1, 1.5, w - 1.5, 2, 18, 30, 84, st, 5, 3)
		tier(2, 4, w - 4, 4.5, 15.5, 84, 100, st, 3, 2, t.ring)
		tier(3, 7, w - 7, 6.5, 13.5, 100, 110, cr, 0, 0, t.ring)
		tier(4, 9, w - 9, 8, 12, 110, 116, cr, 0, 0)
		vcyl(m, fr, "Spire", w / 2, 116, t.h, 10, 1.0, cr, dk())
		P(m, "SpireTip", fr * CFrame.new(w / 2, t.h + 0.6, 10), Vector3.new(1.4, 1.4, 1.4), rgb(255, 70, 60), { shape = Enum.PartType.Ball, mat = Enum.Material.Neon, decor = true })
	end
	gatewayTower({ name = "GatewayTower_N", side = "N", x0 = 582, x1 = 606, h = 138,
		stone = rgb(214, 198, 166), dark = rgb(150, 132, 104), crown = gold, ring = rgb(255, 204, 110),
		boards = {
			{ "NEW YORK", 1.5, 22.5, 11, 19, rgb(18, 22, 40), rgb(255, 214, 60), rgb(70, 160, 255) },
			{ "OPEN 24/7", 1.5, 10.5, 20.5, 27, rgb(200, 30, 40), rgb(255, 255, 255), rgb(255, 120, 60) },
			{ "BIG APPLE", 12, 22.5, 20.5, 27, rgb(30, 120, 60), rgb(255, 240, 200), rgb(140, 255, 120) },
		},
		blade = "THEATER", bladeBg = rgb(150, 20, 30), bladeText = rgb(255, 230, 120), apple = 17.25 })
	gatewayTower({ name = "GatewayTower_S", side = "S", x0 = 582, x1 = 606, h = 124,
		stone = rgb(176, 178, 186), dark = rgb(118, 120, 128), crown = rgb(200, 206, 214), ring = rgb(120, 220, 255),
		boards = {
			{ "SALE", 1.5, 9, 11, 19, rgb(255, 214, 40), rgb(210, 30, 40), rgb(255, 90, 60) },
			{ "LIVE SHOW", 10.5, 22.5, 11, 19, rgb(84, 30, 130), rgb(255, 255, 255), rgb(255, 80, 220) },
			{ "HOT DOGS $1", 1.5, 22.5, 20.5, 27, rgb(240, 120, 30), rgb(255, 255, 255), rgb(255, 214, 60) },
		},
		blade = "HOTEL", bladeBg = rgb(20, 40, 90), bladeText = rgb(120, 220, 255) })

	-- 2) Immeubles de brique, construits à l'échelle 1 puis agrandis ×K autour du pied de leur façade
	-- b = { name, side, x0, x1 (monde), h, brick, trim, door, shop, shopColor, fe, wt, wtx, entry = "L"/"R", narrow }
	local function tenement(b)
		local w = (b.x1 - b.x0) / K
		scaled(H, b.name, frameFor(b.side, b.x0, b.x1), function(m, fr)
			local h, D = b.h, 8
			Bx(m, fr, "Wall", 0, 0, 0, w, h, D, b.brick, { studs = true, decor = true })
			Bx(m, fr, "Base", 0, 0.3, -0.1, w, 1.2, 0, rgb(86, 84, 82), dk())
			-- Rez-de-chaussée : entrée à perron, boutique fermée par un rideau de fer (ou petite enseigne si étroit)
			local ex0 = b.narrow and (w / 2 - 1.25) or ((b.entry == "L") and 1.5 or (w - 4.0))
			local ex1 = ex0 + 2.5
			Bx(m, fr, "EntryDoor", ex0, 0.9, -0.14, ex1, 6.6, 0, b.door, dk())
			Bx(m, fr, "EntryCanopy", ex0 - 0.4, 6.8, -1.4, ex1 + 0.4, 7.2, 0, iron, dk())
			Bx(m, fr, "EntryLamp", ex1 + 0.3, 5.0, -0.35, ex1 + 0.7, 5.6, 0, lit, { decor = true, mat = Enum.Material.Neon })
			Bx(m, fr, "Step1", ex0 - 0.3, 0.3, -1.3, ex1 + 0.3, 0.6, 0, stoneT, { studs = true })
			Bx(m, fr, "Step2", ex0 - 0.3, 0.6, -0.7, ex1 + 0.3, 0.9, 0, stoneT, { studs = true })
			if b.narrow then
				label(Bx(m, fr, "ShopSign", 0.4, 7.4, -0.3, w - 0.4, 8.6, 0, b.shopColor, dk()), Enum.NormalId.Front, b.shop, rgb(255, 255, 255), 40)
			else
				local gx0, gx1 = (b.entry == "L") and 7 or 2, (b.entry == "L") and (w - 1.5) or (w - 7)
				Bx(m, fr, "ShopGate", gx0, 0.3, -0.12, gx1, 6.4, 0, rgb(150, 154, 160), { decor = true, mat = Enum.Material.DiamondPlate })
				Bx(m, fr, "GateBox", gx0 - 0.2, 6.4, -0.4, gx1 + 0.2, 7.0, 0, rgb(110, 114, 120), dk())
				label(Bx(m, fr, "ShopSign", gx0, 7.0, -0.3, gx1, 8.4, 0, b.shopColor, dk()), Enum.NormalId.Front, b.shop, rgb(255, 255, 255), 40)
			end
			-- Étages : fenêtres à encadrement clair sur un bandeau d'appui ; une sur cinq environ est allumée
			local floors = math.floor((h - 10.2) / 4.4)
			local cols = b.narrow and { w / 4, 3 * w / 4 } or { w / 6, w / 2, 5 * w / 6 }
			for f = 0, floors - 1 do
				local yb = 8.6 + f * 4.4
				Bx(m, fr, "Sill_" .. f, 0, yb + 0.35, -0.3, w, yb + 0.6, 0, b.trim, dk())
				for k, cx in cols do
					Bx(m, fr, string.format("WinFrame_%d_%d", f, k), cx - 1.45, yb + 0.6, -0.08, cx + 1.45, yb + 3.75, 0, b.trim, dk())
					local on = rnd() < 0.22
					Bx(m, fr, string.format("WinGlass_%d_%d", f, k), cx - 1.2, yb + 0.75, -0.14, cx + 1.2, yb + 3.5, -0.08, on and lit or glassD, { decor = true, mat = on and Enum.Material.Neon or Enum.Material.Glass })
				end
			end
			-- Escalier de secours en fer noir devant les deux premières colonnes de fenêtres
			if b.fe then
				local px0, px1 = math.max(0.2, cols[1] - 2.0), math.min(w - 0.2, cols[2] + 2.0)
				local ylast = 8.6 + (floors - 1) * 4.4
				for f = 0, floors - 1 do
					local yb = 8.6 + f * 4.4
					Bx(m, fr, "FE_Platform_" .. f, px0, yb + 0.2, -1.8, px1, yb + 0.35, -0.05, iron, dk())
					Bx(m, fr, "FE_Rail_" .. f, px0, yb + 1.9, -1.85, px1, yb + 2.05, -1.7, iron, dk())
					if f < floors - 1 then
						local run, rise = math.min(4.0, px1 - px0 - 0.8), 4.4
						local len = math.sqrt(run * run + rise * rise)
						local cx = (f % 2 == 0) and (px1 - 0.4 - run / 2) or (px0 + 0.4 + run / 2)
						local ang = math.atan2(rise, run) * ((f % 2 == 0) and -1 or 1)
						P(m, "FE_Stair_" .. f, fr * CFrame.new(cx, yb + 0.35 + rise / 2, -1.1) * CFrame.Angles(0, 0, ang), Vector3.new(len, 0.15, 1.0), iron, dk())
					end
				end
				for k, x in { px0, px1 - 0.15 } do
					Bx(m, fr, "FE_Post_" .. k, x, 8.8, -1.85, x + 0.15, ylast + 2.05, -1.7, iron, dk())
				end
				for k, dx in { 1.2, 0.5 } do
					Bx(m, fr, "FE_Ladder_" .. k, px1 - dx - 0.08, 5.6, -1.75, px1 - dx, 8.8, -1.65, iron, dk())
				end
			end
			-- Corniche à consoles
			Bx(m, fr, "Frieze", 0, h - 2.2, -0.35, w, h - 0.9, 0, b.trim, dk())
			Bx(m, fr, "Cornice", -0.2, h - 0.9, -1.1, w + 0.2, h, D, iron, dk())
			for k = 0, 3 do
				local cx = 1 + k * (w - 2) / 3
				Bx(m, fr, "Corbel_" .. k, cx - 0.35, h - 1.7, -0.9, cx + 0.35, h - 0.9, -0.35, iron, dk())
			end
			-- Château d'eau en bois sur le toit
			if b.wt then
				local wx, wz = b.wtx or w / 2, 4
				for k, c in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
					Bx(m, fr, "WT_Leg_" .. k, wx + c[1] - 0.15, h, wz + c[2] - 0.15, wx + c[1] + 0.15, h + 3.5, wz + c[2] + 0.15, iron, dk())
				end
				Bx(m, fr, "WT_Deck", wx - 2.3, h + 3.5, wz - 2.3, wx + 2.3, h + 3.8, wz + 2.3, iron, dk())
				vcyl(m, fr, "WT_Tank", wx, h + 3.8, h + 8.3, wz, 4.0, rgb(132, 92, 60), { studs = true, decor = true })
				vcyl(m, fr, "WT_Hoop", wx, h + 6.0, h + 6.25, wz, 4.12, iron, dk())
				vcyl(m, fr, "WT_Roof1", wx, h + 8.3, h + 8.75, wz, 4.4, rgb(88, 62, 44), dk())
				vcyl(m, fr, "WT_Roof2", wx, h + 8.75, h + 9.35, wz, 3.0, rgb(88, 62, 44), dk())
				vcyl(m, fr, "WT_Roof3", wx, h + 9.35, h + 9.95, wz, 1.5, rgb(88, 62, 44), dk())
			end
		end)
	end
	local trimA, trimB = rgb(226, 218, 200), rgb(196, 190, 176)
	for _, b in {
		{ name = "Tenement_N", side = "N", x0 = 606, x1 = 630, h = 28, brick = rgb(150, 68, 52), trim = trimA, door = rgb(30, 45, 95), shop = "PIZZA", shopColor = rgb(40, 120, 60), fe = true, wt = true, wtx = 12, entry = "R" },
		{ name = "Tenement_S", side = "S", x0 = 606, x1 = 630, h = 26, brick = rgb(124, 72, 52), trim = trimB, door = rgb(120, 30, 34), shop = "DELI", shopColor = rgb(170, 40, 40), fe = true, wt = true, wtx = 4, entry = "L" },
		{ name = "Tenement_End", side = "N", x0 = 690, x1 = 700, h = 30, brick = rgb(134, 82, 60), trim = trimA, door = rgb(25, 25, 30), shop = "COFFEE", shopColor = rgb(110, 70, 40), fe = true, wt = true, narrow = true },
	} do tenement(b) end
	H.Parent = S

	-- 3) Parking à étages (sud, x 690..700), à l'échelle 1 puis agrandi : façade fermée sur le muret, deux niveaux ouverts
	-- et le toit, un taxi jaune garé sur chacun, nez vers la rue, derrière le muret (hors de la chaussée)
	local Pk = fresh("Parking")
	local fr = frameFor("S", 690, 700)
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
	for k, x in { 0, w - 0.6 } do
		Bx(Pk, fr, "GaragePillar_" .. k, x, 13.0, 0, x + 0.6, 24.8, 0.6, concD, dk())
	end
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
		Bx(m, cf, "BumperF", -1.95, 0.6, -4.25, 1.95, 1.0, -4.0, rgb(150, 154, 160), dk())
		Bx(m, cf, "BumperB", -1.95, 0.6, 4.0, 1.95, 1.0, 4.25, rgb(150, 154, 160), dk())
	end
	taxi("Taxi_1", fr * CFrame.new(w / 2, 13.0, 6.5))
	taxi("Taxi_2", fr * CFrame.new(w / 2, 19.2, 6.8) * CFrame.Angles(0, math.rad(-5), 0))
	taxi("Taxi_3", fr * CFrame.new(w / 2, 25.4, 6.6) * CFrame.Angles(0, math.rad(6), 0))
	Pk.WorldPivot = fr
	Pk:ScaleTo(K)
	Pk.Parent = S
end

-- Bloc D2 : terrain ajouté (|z| 62.5..140 et derrière x = 700), deuxième rang d'immeubles, gratte-ciel derrière et à côté
-- des magasins, et fond de ville au bout du couloir : façade Art déco plaquée à x = 700 (son cœur ferme le couloir sur
-- toute sa largeur, |z| <= 31.5, plus large que l'EndWall), grande tour et tours voisines visibles de loin.
do
	local NY = _G.ClaudeNY
	assert(NY and NY.Bx, "envoyer d'abord le bloc C")
	local rgb = Color3.fromRGB
	local P, Bx, vcyl, label, fresh, S = NY.P, NY.Bx, NY.vcylW, NY.labelW, NY.fresh, NY.street
	local W = CFrame.identity
	local gold, iron, bronze = rgb(212, 172, 60), rgb(30, 30, 34), rgb(104, 74, 40)
	local glassC, tipC = rgb(52, 64, 80), rgb(255, 70, 60)
	local neonW, neonG = rgb(255, 204, 110), rgb(120, 220, 255)
	local beige, grey, brick, sand, brown = rgb(214, 198, 166), rgb(176, 176, 184), rgb(150, 84, 64), rgb(196, 170, 130), rgb(112, 70, 54)
	local capC = rgb(150, 156, 164)

	-- 1) Terrain : béton gris au-delà du greybox (|z| 62.5..140) et derrière le bout du couloir (x 700..770)
	local L = fresh("Land")
	local concrete = rgb(128, 128, 132)
	Bx(L, W, "Land_N", 580, -2, 62.5, 700, 0, 140, concrete, { studs = true })
	Bx(L, W, "Land_S", 580, -2, -140, 700, 0, -62.5, concrete, { studs = true })
	Bx(L, W, "Land_E", 700, -2, -140, 770, 0, 140, concrete, { studs = true })
	L.Parent = S

	-- Château d'eau en bois (à l'échelle 1.5)
	local function waterTower(m, x, z, y)
		for k, c in { { -2.4, -2.4 }, { 2.4, -2.4 }, { -2.4, 2.4 }, { 2.4, 2.4 } } do
			Bx(m, W, "WT_Leg_" .. k, x + c[1] - 0.22, y, z + c[2] - 0.22, x + c[1] + 0.22, y + 5.25, z + c[2] + 0.22, iron, { decor = true })
		end
		Bx(m, W, "WT_Deck", x - 3.45, y + 5.25, z - 3.45, x + 3.45, y + 5.7, z + 3.45, iron, { decor = true })
		vcyl(m, W, "WT_Tank", x, y + 5.7, y + 12.45, z, 6.0, rgb(132, 92, 60), { studs = true, decor = true })
		vcyl(m, W, "WT_Roof1", x, y + 12.45, y + 13.1, z, 6.6, rgb(88, 62, 44), { decor = true })
		vcyl(m, W, "WT_Roof2", x, y + 13.1, y + 14.0, z, 4.5, rgb(88, 62, 44), { decor = true })
		vcyl(m, W, "WT_Roof3", x, y + 14.0, y + 14.9, z, 2.25, rgb(88, 62, 44), { decor = true })
	end
	-- Tour à gradins (monde) : tiers = { { x0, x1, z0, z1, y0, y1, color, mat?, nx?, nz?, from?, ring?, bands?, bandColor? } } ;
	-- bandes de fenêtres traversantes (une pièce marque deux faces opposées), liseré de néon, bandeaux des tours de verre
	local function tower(parent, name, tiers, spire)
		local m = Instance.new("Model"); m.Name = name; m.Parent = parent
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
			if t.ring then
				Bx(m, W, "Ring_" .. i, t.x0 - 0.2, t.y1 - 0.6, t.z0 - 0.2, t.x1 + 0.2, t.y1, t.z1 + 0.2, t.ring, { decor = true, mat = Enum.Material.Neon, noShadow = true })
			end
		end
		if spire then   -- { x, z, y0, y1, diamètre, couleur }
			vcyl(m, W, "Spire", spire[1], spire[3], spire[4], spire[2], spire[5], spire[6] or rgb(190, 196, 204), { decor = true })
			P(m, "SpireTip", CFrame.new(spire[1], spire[4] + 0.7, spire[2]), Vector3.new(1.4, 1.4, 1.4), tipC, { shape = Enum.PartType.Ball, mat = Enum.Material.Neon, decor = true })
		end
		return m
	end
	NY.tower, NY.waterTower = tower, waterTower

	local Sk = fresh("Skyline")
	-- 2) Deuxième rang derrière les immeubles de brique, visible au-dessus d'eux depuis la rue
	local mN = tower(Sk, "Midrise_N", { { x0 = 607, x1 = 629, z0 = 44, z1 = 60, y0 = 0, y1 = 64, color = brown, nx = 4, nz = 3, from = 20 } })
	Bx(mN, W, "Cornice", 606.6, 64, 43.6, 629.4, 65.2, 60.4, iron, { decor = true })
	waterTower(mN, 614, 52, 65.2)
	local mS = tower(Sk, "Midrise_S", { { x0 = 607, x1 = 629, z0 = -60, z1 = -44, y0 = 0, y1 = 56, color = rgb(132, 96, 80), nx = 4, nz = 3, from = 20 } })
	Bx(mS, W, "Cornice", 606.6, 56, -60.4, 629.4, 57.2, -43.6, iron, { decor = true })
	waterTower(mS, 621, -52, 57.2)

	-- 3) Gratte-ciel du côté nord : à côté de la banque (x 584..628) et derrière elle (z 104..140)
	tower(Sk, "Tower_N1", {   -- Art déco beige
		{ x0 = 584, x1 = 606, z0 = 68, z1 = 90, y0 = 0, y1 = 70, color = beige, nx = 5, nz = 5, from = 20 },
		{ x0 = 587, x1 = 603, z0 = 71, z1 = 87, y0 = 70, y1 = 100, color = beige, nx = 4, nz = 4, ring = neonW },
		{ x0 = 590, x1 = 600, z0 = 74, z1 = 84, y0 = 100, y1 = 118, color = beige, nx = 2, nz = 2, ring = neonW },
		{ x0 = 592.5, x1 = 597.5, z0 = 76.5, z1 = 81.5, y0 = 118, y1 = 126, color = gold },
	}, { 595, 79, 126, 150, 1.0, gold })
	tower(Sk, "Tower_N2", {   -- verre bleu à bandeaux blancs
		{ x0 = 608, x1 = 628, z0 = 64, z1 = 86, y0 = 0, y1 = 120, color = rgb(86, 128, 170), mat = Enum.Material.Glass, bands = 9 },
		{ x0 = 610, x1 = 626, z0 = 66, z1 = 84, y0 = 120, y1 = 124, color = capC },
	}, { 618, 75, 124, 140, 0.6 })
	tower(Sk, "Tower_N3", {   -- grande tour de pierre grise, la plus haute du côté nord
		{ x0 = 586, x1 = 614, z0 = 100, z1 = 130, y0 = 0, y1 = 90, color = grey, nx = 6, nz = 6, from = 20 },
		{ x0 = 590, x1 = 610, z0 = 104, z1 = 126, y0 = 90, y1 = 140, color = grey, nx = 4, nz = 4, ring = neonG },
		{ x0 = 594, x1 = 606, z0 = 108, z1 = 122, y0 = 140, y1 = 170, color = grey, nx = 2, nz = 2, ring = neonG },
		{ x0 = 597, x1 = 603, z0 = 112, z1 = 118, y0 = 170, y1 = 182, color = rgb(200, 206, 214) },
	}, { 600, 115, 182, 214, 1.2, rgb(200, 206, 214) })
	tower(Sk, "Tower_N4", {   -- verre vert d'eau derrière la banque
		{ x0 = 640, x1 = 678, z0 = 108, z1 = 136, y0 = 0, y1 = 150, color = rgb(96, 150, 150), mat = Enum.Material.Glass, bands = 11 },
		{ x0 = 644, x1 = 674, z0 = 112, z1 = 132, y0 = 150, y1 = 156, color = capC },
	})
	local n5 = tower(Sk, "Tower_N5", {   -- brique, château d'eau sur le toit
		{ x0 = 682, x1 = 700, z0 = 106, z1 = 132, y0 = 0, y1 = 80, color = brick, nx = 3, nz = 4, from = 20 },
	})
	Bx(n5, W, "Cornice", 681.6, 80, 105.6, 700, 81.2, 132.4, iron, { decor = true })
	waterTower(n5, 691, 120, 81.2)

	-- 4) Gratte-ciel du côté sud (variantes)
	tower(Sk, "Tower_S1", {   -- Art déco grise
		{ x0 = 584, x1 = 606, z0 = -90, z1 = -68, y0 = 0, y1 = 64, color = grey, nx = 5, nz = 5, from = 20 },
		{ x0 = 587.5, x1 = 602.5, z0 = -86.5, z1 = -71.5, y0 = 64, y1 = 94, color = grey, nx = 3, nz = 3, ring = neonG },
		{ x0 = 591, x1 = 599, z0 = -83, z1 = -75, y0 = 94, y1 = 108, color = rgb(200, 206, 214), ring = neonG },
	}, { 595, -79, 108, 130, 0.8 })
	tower(Sk, "Tower_S2", {   -- verre sombre
		{ x0 = 608, x1 = 628, z0 = -88, z1 = -64, y0 = 0, y1 = 140, color = rgb(40, 48, 60), mat = Enum.Material.Glass, bands = 10, bandColor = capC },
		{ x0 = 611, x1 = 625, z0 = -85, z1 = -67, y0 = 140, y1 = 146, color = capC, ring = neonW },
	}, { 618, -76, 146, 164, 0.6 })
	tower(Sk, "Tower_S3", {   -- grande tour beige à couronne dorée, la plus haute du côté sud
		{ x0 = 586, x1 = 614, z0 = -132, z1 = -102, y0 = 0, y1 = 100, color = beige, nx = 6, nz = 6, from = 20 },
		{ x0 = 590, x1 = 610, z0 = -128, z1 = -106, y0 = 100, y1 = 150, color = beige, nx = 4, nz = 4, ring = neonW },
		{ x0 = 594, x1 = 606, z0 = -124, z1 = -110, y0 = 150, y1 = 176, color = gold, ring = neonW },
		{ x0 = 597, x1 = 603, z0 = -120, z1 = -114, y0 = 176, y1 = 186, color = gold },
	}, { 600, -117, 186, 226, 1.2, gold })
	tower(Sk, "Tower_S4", {   -- verre bleu derrière la salle des coffres
		{ x0 = 640, x1 = 676, z0 = -136, z1 = -108, y0 = 0, y1 = 124, color = rgb(70, 110, 160), mat = Enum.Material.Glass, bands = 9 },
		{ x0 = 643, x1 = 673, z0 = -133, z1 = -111, y0 = 124, y1 = 130, color = capC },
	}, { 658, -122, 130, 146, 0.6 })
	local s5 = tower(Sk, "Tower_S5", {   -- pierre ocre, château d'eau sur le toit
		{ x0 = 682, x1 = 700, z0 = -132, z1 = -106, y0 = 0, y1 = 70, color = sand, nx = 3, nz = 4, from = 20 },
	})
	Bx(s5, W, "Cornice", 681.6, 70, -132.4, 700, 71.2, -105.6, iron, { decor = true })
	waterTower(s5, 691, -118, 71.2)
	Sk.Parent = S

	-- 5) Fond du couloir : façade plaquée à x = 700 (cœur solide, décor devant sans collision), grande tour et tours voisines
	local E = fresh("Backdrop")
	local dark = rgb(206, 190, 158)
	Bx(E, W, "EndFacade", 700, 0, -31.5, 703.2, 36, 31.5, beige, { studs = true })
	for k, z in { -29.7, -21, -7.5, 7.5, 21, 29.7 } do
		Bx(E, W, "EndPier_" .. k, 699.475, 0.45, z - 1.2, 700, 39, z + 1.2, dark, { studs = true, decor = true })
	end
	for k, zr in { { -28.3, -22.4 }, { -19.6, -9 }, { 9, 19.6 }, { 22.4, 28.3 } } do
		Bx(E, W, "EndWindow_" .. k, 699.85, 3, zr[1], 700, (math.abs(zr[1]) > 21) and 33 or 27, zr[2], glassC, { decor = true, mat = Enum.Material.Glass })
	end
	Bx(E, W, "EndDoorFrame", 699.7, 0.45, -6.9, 700, 13.95, 6.9, bronze, { decor = true })
	Bx(E, W, "EndDoors", 699.55, 0.45, -6.0, 699.7, 12.9, 6.0, gold, { decor = true })
	for k = 1, 5 do
		local a = math.rad(k * 30)
		P(E, "Sunburst_" .. k, CFrame.new(699.625, 13.95 + 3.6 * math.sin(a), 3.6 * math.cos(a)) * CFrame.Angles(-a, 0, 0), Vector3.new(0.15, 0.45, 6.0), gold, { decor = true })
	end
	P(E, "ClockRim", CFrame.new(699.7, 24.75, 0), Vector3.new(0.45, 7.5, 7.5), gold, { shape = Enum.PartType.Cylinder, decor = true })
	P(E, "ClockFace", CFrame.new(699.4, 24.75, 0), Vector3.new(0.22, 6.6, 6.6), rgb(250, 246, 232), { shape = Enum.PartType.Cylinder, decor = true })
	P(E, "MinuteHand", CFrame.new(699.22, 26.1, 0), Vector3.new(0.09, 2.7, 0.24), iron, { decor = true })
	P(E, "HourHand", CFrame.new(699.22, 24.75, 0.9), Vector3.new(0.09, 0.27, 1.8), iron, { decor = true })
	P(E, "ClockPin", CFrame.new(699.18, 24.75, 0), Vector3.new(0.5, 0.5, 0.5), gold, { shape = Enum.PartType.Ball, decor = true })
	label(Bx(E, W, "EndSign", 699.625, 30, -15, 700, 33, 15, rgb(36, 40, 48), { decor = true }), Enum.NormalId.Left, "FORTUNE TOWER", gold, 40)
	Bx(E, W, "EndBand", 699.775, 33.6, -31.5, 700, 34.2, 31.5, gold, { decor = true })
	Bx(E, W, "EndCornice", 699.325, 36, -31.8, 703.2, 36.9, 31.8, dark, { decor = true })
	tower(E, "EndTower", {
		{ x0 = 703.2, x1 = 743.5, z0 = -19.5, z1 = 19.5, y0 = 0, y1 = 108, color = beige, nx = 7, nz = 7, from = 39 },
		{ x0 = 709, x1 = 739, z0 = -15, z1 = 15, y0 = 108, y1 = 144, color = beige, nx = 5, nz = 5, ring = neonW },
		{ x0 = 713.5, x1 = 734.5, z0 = -10.5, z1 = 10.5, y0 = 144, y1 = 168, color = beige, nx = 3, nz = 3, ring = neonW },
		{ x0 = 716.5, x1 = 731.5, z0 = -7.5, z1 = 7.5, y0 = 168, y1 = 180, color = gold, ring = neonW },
		{ x0 = 719.5, x1 = 728.5, z0 = -4.5, z1 = 4.5, y0 = 180, y1 = 189, color = gold },
	}, { 724, 0, 189, 228, 1.5, gold })
	tower(E, "Tower_E1", {   -- verre sombre, côté nord
		{ x0 = 708, x1 = 738, z0 = 36, z1 = 64, y0 = 0, y1 = 140, color = rgb(40, 48, 60), mat = Enum.Material.Glass, bands = 10, bandColor = capC },
		{ x0 = 711, x1 = 735, z0 = 39, z1 = 61, y0 = 140, y1 = 146, color = capC, ring = neonG },
	}, { 723, 50, 146, 168, 0.8 })
	tower(E, "Tower_E2", {   -- Art déco grise, la plus haute du fond nord
		{ x0 = 716, x1 = 756, z0 = 74, z1 = 112, y0 = 0, y1 = 110, color = grey, nx = 7, nz = 7, from = 20 },
		{ x0 = 721, x1 = 751, z0 = 79, z1 = 107, y0 = 110, y1 = 150, color = grey, nx = 5, nz = 5, ring = neonG },
		{ x0 = 727, x1 = 745, z0 = 85, z1 = 101, y0 = 150, y1 = 175, color = rgb(200, 206, 214), ring = neonG },
	}, { 736, 93, 175, 205, 1.2 })
	local e3 = tower(E, "Tower_E3", {   -- brique
		{ x0 = 704, x1 = 730, z0 = 118, z1 = 140, y0 = 0, y1 = 95, color = brick, nx = 4, nz = 3, from = 20 },
	})
	Bx(e3, W, "Cornice", 703.6, 95, 117.6, 730.4, 96.2, 140, iron, { decor = true })
	waterTower(e3, 716, 129, 96.2)
	tower(E, "Tower_E4", {   -- pierre ocre, côté sud
		{ x0 = 708, x1 = 736, z0 = -64, z1 = -36, y0 = 0, y1 = 96, color = sand, nx = 5, nz = 5, from = 20 },
		{ x0 = 712, x1 = 732, z0 = -60, z1 = -40, y0 = 96, y1 = 125, color = sand, nx = 3, nz = 3, ring = neonW },
	}, { 722, -50, 125, 145, 0.8 })
	tower(E, "Tower_E5", {   -- verre bleu
		{ x0 = 714, x1 = 752, z0 = -112, z1 = -74, y0 = 0, y1 = 160, color = rgb(86, 128, 170), mat = Enum.Material.Glass, bands = 12 },
		{ x0 = 717, x1 = 749, z0 = -109, z1 = -77, y0 = 160, y1 = 166, color = capC },
	}, { 733, -93, 166, 186, 0.8 })
	local e6 = tower(E, "Tower_E6", {   -- brique claire
		{ x0 = 704, x1 = 728, z0 = -140, z1 = -118, y0 = 0, y1 = 85, color = rgb(170, 110, 84), nx = 4, nz = 3, from = 20 },
	})
	Bx(e6, W, "Cornice", 703.6, 85, -140, 728.4, 86.2, -117.6, iron, { decor = true })
	waterTower(e6, 716, -129, 86.2)
	E.Parent = S
end

-- Bilan
do
	local NY = _G.ClaudeNY
	local S = workspace.Map.Zone_6.Street_NewYork
	local n, parts = 0, {}
	for _, sub in S:GetChildren() do
		local k = 0
		for _, d in sub:GetDescendants() do if d:IsA("BasePart") then k += 1 end end
		n += k
		table.insert(parts, sub.Name .. " " .. k)
	end
	table.sort(parts)
	local c = NY.counts or {}
	return string.format("Zone 6 New York (×1.5) : banque %d produits, salle des coffres %d produits, décor %d pièces (%s)",
		c.bank or 0, c.vault or 0, n, table.concat(parts, ", "))
end
