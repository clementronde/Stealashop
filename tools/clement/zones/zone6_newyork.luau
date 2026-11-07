--!nocheck
-- Zone 6 — New York (MOD-024) : banque, salle des coffres et rue du quartier d'affaires.
-- À lancer dans Studio (MCP execute_luau, mode Edit), APRÈS tools/clement/store_builder.luau.
-- Relançable : les deux magasins et chaque sous-dossier du décor de rue sont remplacés à l'identique.
-- Six blocs « do ... end » qui ne partagent que _G.ClaudeNY. On peut envoyer tout le fichier d'un coup,
-- ou bloc par bloc dans l'ordre (A1 d'abord) si Studio peine : A1 fonctions communes et façade de la banque,
-- A2 façade de la salle des coffres et intérieur, B greybox et magasins, C rue et mobilier,
-- D1 immeubles et parking des taxis, D2 gratte-ciel et fond du couloir.
-- Où (greybox du 2026-11-07) : rue x 580..700, z -20..20 ; arche ZoneGate_6 à x = 580 ; EndWall à x = 700.
-- Banque : pivot (660, 0, 44), façade vers -Z. Salle des coffres : pivot (660, 0, -44), tournée de 180°.
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

-- Bloc B : greybox (magasins gris rangés, murets calés sur les magasins, rue recolorée) et les deux magasins.
do
	local NY = _G.ClaudeNY
	local Store = _G.ClaudeStore
	assert(NY and NY.interior, "envoyer d'abord les blocs A1 et A2")
	assert(Store, "charger d'abord tools/clement/store_builder.luau")
	local rgb = Color3.fromRGB

	-- 1) Greybox : magasins gris de la zone 6 rangés, murets calés (x 580..640 et 680..700), rue en asphalte
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
	g.SideWall_N1.Size = Vector3.new(60, 12, 1); g.SideWall_N1.Position = Vector3.new(610, 6, 20.5)
	g.SideWall_S1.Size = Vector3.new(60, 12, 1); g.SideWall_S1.Position = Vector3.new(610, 6, -20.5)
	g.SideWall_N2.Size = Vector3.new(20, 12, 1); g.SideWall_N2.Position = Vector3.new(690, 6, 20.5)
	g.SideWall_S2.Size = Vector3.new(20, 12, 1); g.SideWall_S2.Position = Vector3.new(690, 6, -20.5)
	g.Street.Color = rgb(50, 51, 57); g.Street.Material = Enum.Material.Plastic; g.Street.MaterialVariant = "Studs"

	-- 2) Dossier de la zone
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

	-- 3) Banque : pierre calcaire, colonnes, fronton, toit de cuivre ; intérieur crème, marbre blanc et vert
	local bank, bankN = Store.build({
		name = "STORE_Z6_Banque", zone = 6,
		origin = CFrame.new(660, 0, 44), parent = zoneFolder,
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

	-- 4) Salle des coffres : façade d'acier blindée, auvent jaune et noir ; intérieur acier, marbre gris et noir
	local vault, vaultN = Store.build({
		name = "STORE_Z6_SalleDesCoffres", zone = 6,
		origin = CFrame.new(660, 0, -44) * CFrame.Angles(0, math.pi, 0), parent = zoneFolder,
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
-- Chaussée z -15..15 libre : seulement des marquages plats et des plaques d'égout fumantes, sans collision.
-- Trottoirs à |z| 15..20, hauts de 0,3 stud (au niveau du sol des magasins).
do
	local NY = _G.ClaudeNY
	assert(NY, "envoyer d'abord le bloc A1")
	local rgb = Color3.fromRGB
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
	-- Vapeur des bouches d'égout (objet natif, aucun script)
	local function steam(part, dir, rate)
		local e = Instance.new("ParticleEmitter")
		e.Name = "Steam"; e.Texture = "rbxasset://textures/particles/smoke_main.dds"; e.EmissionDirection = dir
		e.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240)); e.LightEmission = 0.1
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5.5) })
		e.Lifetime = NumberRange.new(2.5, 4); e.Rate = rate or 7; e.Speed = NumberRange.new(2.5, 4.5)
		e.SpreadAngle = Vector2.new(12, 12); e.RotSpeed = NumberRange.new(-25, 25); e.Rotation = NumberRange.new(0, 360); e.Drag = 0.6
		e.Parent = part
		return e
	end
	NY.street, NY.P, NY.Bx, NY.vcylW, NY.labelW, NY.fresh, NY.steam = S, P, Bx, vcyl, label, fresh, steam

	local W = CFrame.identity
	local yellow, white, iron = rgb(255, 196, 0), rgb(242, 242, 236), rgb(28, 28, 32)
	local flat = function() return { decor = true, noShadow = true } end

	-- 1) Sol : bordures et trottoirs, doubles lignes jaunes, tirets, passage piéton, plaques d'égout fumantes
	local G = fresh("Ground")
	for _, s in { 1, -1 } do
		local tag = s > 0 and "N" or "S"
		Bx(G, W, "Kerb_" .. tag, 580, 0, s * 15, 700, 0.3, s * 15.5, rgb(152, 152, 154), { studs = true })
		Bx(G, W, "Pavement_" .. tag, 580, 0, s * 15.5, 700, 0.3, s * 20, rgb(188, 186, 180), { studs = true })
	end
	for _, seg in { { 580, 594.4 }, { 603.6, 700 } } do
		for _, zz in { { 0.2, 0.36 }, { -0.36, -0.2 } } do
			Bx(G, W, string.format("YellowLine_%d_%s", seg[1], zz[1] > 0 and "N" or "S"), seg[1], 0, zz[1], seg[2], 0.04, zz[2], yellow, flat())
		end
	end
	for _, s in { 1, -1 } do
		for _, x0 in { 582, 612, 622, 632, 642, 652, 662, 672, 682, 692 } do
			Bx(G, W, string.format("LaneDash_%s%d", s > 0 and "N" or "S", x0), x0, 0, s * 7.4, x0 + 4, 0.04, s * 7.6, white, flat())
		end
	end
	for i = 0, 11 do
		local z0 = -13.8 + i * 2.4
		Bx(G, W, "Crosswalk_" .. (i + 1), 596, 0, z0, 602, 0.04, z0 + 1.2, white, flat())
	end
	Bx(G, W, "StopLine_S", 594.4, 0, -14.6, 595.0, 0.04, -0.6, white, flat())
	Bx(G, W, "StopLine_N", 603.0, 0, 0.6, 603.6, 0.04, 14.6, white, flat())
	for i, pos in { { 617, 9 }, { 647, -6 }, { 689, 4 } } do
		local mh = vcyl(G, W, "SteamVent_" .. i, pos[1], 0, 0.07, pos[2], 2.4, rgb(64, 62, 60), flat())
		vcyl(G, W, "SteamVentRing_" .. i, pos[1], 0, 0.05, pos[2], 2.8, rgb(40, 40, 42), flat())
		steam(mh, Enum.NormalId.Right, 6)
	end
	G.Parent = S

	-- 2) Mobilier des trottoirs (hors des devantures des magasins, x 640..680)
	local D = fresh("Props")
	local poleC = rgb(64, 68, 72)
	-- Lampadaires à crosse : bras et tête au-dessus de la chaussée, sans collision
	for tag, xs in { N = { 586, 626, 690 }, S = { 592, 617, 684 } } do
		local s = tag == "N" and 1 or -1
		for i, x in xs do
			local z, nm = s * 16.3, "StreetLamp_" .. tag .. i
			Bx(D, W, nm .. "_Base", x - 0.5, 0.3, z - 0.5, x + 0.5, 1.4, z + 0.5, poleC, {})
			vcyl(D, W, nm .. "_Pole", x, 1.4, 12.3, z, 0.4, poleC, {})
			Bx(D, W, nm .. "_Arm", x - 0.15, 12.0, z, x + 0.15, 12.3, z - s * 3.2, poleC, { decor = true })
			Bx(D, W, nm .. "_Head", x - 0.45, 11.75, z - s * 2.6, x + 0.45, 12.35, z - s * 4.0, rgb(150, 156, 162), { decor = true })
			local glow = Bx(D, W, nm .. "_Glow", x - 0.35, 11.62, z - s * 2.75, x + 0.35, 11.75, z - s * 3.85, rgb(255, 226, 170), { mat = Enum.Material.Neon, decor = true, noShadow = true })
			local pl = Instance.new("PointLight"); pl.Color = rgb(255, 214, 160); pl.Range = 24; pl.Brightness = 1.1; pl.Shadows = false; pl.Parent = glow
		end
	end
	-- Bornes d'incendie
	local hydRed, hydCap = rgb(214, 48, 40), rgb(242, 196, 40)
	for i, pos in { { 607, 16.2 }, { 686, 16.2 }, { 589, -16.2 }, { 634, -16.2 } } do
		local x, z = pos[1], pos[2]
		local s = z > 0 and 1 or -1
		local nm = "Hydrant_" .. i
		vcyl(D, W, nm .. "_Flange", x, 0.3, 0.5, z, 1.05, hydRed, {})
		vcyl(D, W, nm .. "_Body", x, 0.5, 1.9, z, 0.75, hydRed, {})
		vcyl(D, W, nm .. "_Bonnet", x, 1.9, 2.15, z, 0.95, hydCap, { decor = true })
		vcyl(D, W, nm .. "_Nut", x, 2.15, 2.45, z, 0.32, hydCap, { decor = true })
		P(D, nm .. "_Outlets", CFrame.new(x, 1.35, z), Vector3.new(1.35, 0.34, 0.34), hydCap, { shape = Enum.PartType.Cylinder, decor = true })
		P(D, nm .. "_Nozzle", CFrame.new(x, 1.15, z - s * 0.45) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.6, 0.48, 0.48), hydCap, { shape = Enum.PartType.Cylinder, decor = true })
	end
	-- Cheminée de vapeur rayée orange et blanc, au bord du trottoir sud
	local orange = rgb(250, 120, 30)
	for k = 0, 3 do
		vcyl(D, W, "SteamStack_" .. k, 628, 0.3 + k * 1.2, 1.5 + k * 1.2, -16.5, 1.5, (k % 2 == 0) and orange or white, {})
	end
	steam(vcyl(D, W, "SteamStack_Rim", 628, 5.1, 5.4, -16.5, 1.7, orange, { decor = true }), Enum.NormalId.Right, 9)
	-- Kiosque à journaux (trottoir sud, guichet face à la chaussée)
	local K = Instance.new("Model"); K.Name = "NewsKiosk"; K.Parent = D
	local kg, kd = rgb(38, 104, 70), rgb(24, 70, 48)
	Bx(K, W, "Body", 607, 0.3, -19.6, 613, 6.0, -16.4, kg, { studs = true })
	Bx(K, W, "Roof", 606.6, 6.0, -19.9, 613.4, 6.45, -15.7, kd, { decor = true })
	label(Bx(K, W, "SignBand", 607, 6.45, -17.2, 613, 7.65, -16.4, kd, { decor = true }), Enum.NormalId.Back, "NEWS", rgb(255, 214, 90), 40)
	Bx(K, W, "ServiceWindow", 608, 2.9, -16.45, 612, 5.4, -16.38, rgb(40, 48, 56), { decor = true, mat = Enum.Material.Glass })
	Bx(K, W, "Counter", 607.8, 2.6, -16.4, 612.2, 2.85, -15.8, rgb(122, 84, 50), { decor = true })
	for k, c in { { 608.2, rgb(245, 245, 240) }, { 609.6, rgb(250, 214, 220) }, { 611.0, rgb(255, 240, 180) } } do
		Bx(K, W, "Papers_" .. k, c[1], 2.85, -16.3, c[1] + 1.1, 3.25, -15.9, c[2], { decor = true })
	end
	for k, c in { { 607.6, rgb(232, 65, 60) }, { 608.9, rgb(255, 210, 40) }, { 610.2, rgb(46, 134, 222) }, { 611.5, rgb(240, 120, 180) } } do
		Bx(K, W, "Magazines_" .. k, c[1], 0.8, -16.48, c[1] + 1.1, 2.3, -16.38, c[2], { decor = true })
	end
	-- Distributeurs de journaux et corbeilles
	for k, c in { { 614.0, rgb(40, 90, 170) }, { 615.1, rgb(200, 40, 40) } } do
		Bx(D, W, "NewsBox_" .. k, c[1], 0.3, -17.2, c[1] + 0.9, 2.1, -16.4, c[2], {})
		Bx(D, W, "NewsBoxWindow_" .. k, c[1] + 0.12, 1.2, -16.42, c[1] + 0.78, 1.9, -16.36, rgb(200, 220, 235), { decor = true, mat = Enum.Material.Glass })
	end
	for i, pos in { { 597, 16.4 }, { 624, -16.4 }, { 683, 16.4 } } do
		vcyl(D, W, "TrashCan_" .. i, pos[1], 0.3, 2.4, pos[2], 1.3, rgb(56, 104, 64), {})
		vcyl(D, W, "TrashCanRim_" .. i, pos[1], 2.4, 2.55, pos[2], 1.4, iron, { decor = true })
	end
	-- Feux à potence (bras au-dessus de la chaussée, sans collision en hauteur), feu piéton, plaques de rue
	local function trafficPole(nm, x, s)
		local z = s * 16.3
		local px = (x < 599) and 1 or -1   -- côté du passage piéton (x 596..602)
		Bx(D, W, nm .. "_Base", x - 0.5, 0.3, z - 0.5, x + 0.5, 1.3, z + 0.5, poleC, {})
		vcyl(D, W, nm .. "_Pole", x, 1.3, 13.2, z, 0.45, poleC, {})
		Bx(D, W, nm .. "_Arm", x - 0.15, 12.4, z, x + 0.15, 12.75, z - s * 7.7, poleC, { decor = true })
		local hz = z - s * 7.25
		Bx(D, W, nm .. "_Head", x - 0.45, 9.6, hz - 0.45, x + 0.45, 12.4, hz + 0.45, rgb(250, 200, 30), { decor = true })
		for k, c in { { 11.9, rgb(120, 30, 28), false }, { 11.0, rgb(130, 90, 20), false }, { 10.1, rgb(70, 235, 120), true } } do
			Bx(D, W, nm .. "_Light" .. k, x - 0.55, c[1] - 0.32, hz - 0.3, x + 0.55, c[1] + 0.32, hz + 0.3, c[2], { decor = true, mat = c[3] and Enum.Material.Neon or nil })
		end
		Bx(D, W, nm .. "_Walk", x + px * 0.25, 7.6, z - 0.35, x + px * 0.85, 8.6, z + 0.35, iron, { decor = true })
		Bx(D, W, nm .. "_WalkHand", x + px * 0.85, 7.8, z - 0.25, x + px * 0.9, 8.4, z + 0.25, rgb(255, 140, 40), { decor = true, mat = Enum.Material.Neon })
		local green = rgb(0, 110, 60)
		local a = Bx(D, W, nm .. "_StreetSignA", x - 2.3, 13.25, z - 0.05, x + 2.3, 14.05, z + 0.05, green, { decor = true })
		label(a, Enum.NormalId.Front, "WALL ST", rgb(255, 255, 255), 40, green)
		label(a, Enum.NormalId.Back, "WALL ST", rgb(255, 255, 255), 40, green)
		local b = Bx(D, W, nm .. "_StreetSignB", x - 0.05, 14.15, z - 2.3, x + 0.05, 14.95, z + 2.3, green, { decor = true })
		label(b, Enum.NormalId.Left, "BROADWAY", rgb(255, 255, 255), 40, green)
		label(b, Enum.NormalId.Right, "BROADWAY", rgb(255, 255, 255), 40, green)
	end
	trafficPole("TrafficPole_N", 593.5, 1)
	trafficPole("TrafficPole_S", 604.5, -1)
	D.Parent = S
end

-- Bloc D1 : immeubles de brique brune plaqués sur les murets (escaliers de secours, châteaux d'eau, boutiques
-- fermées par un rideau de fer) et parking à étages où les taxis jaunes sont garés derrière le muret.
-- Le muret reste le vrai mur : les façades n'ont pas de collision, sauf les marches des perrons.
do
	local NY = _G.ClaudeNY
	assert(NY and NY.Bx, "envoyer d'abord le bloc C")
	local rgb = Color3.fromRGB
	local P, Bx, vcyl, label, fresh, S = NY.P, NY.Bx, NY.vcylW, NY.labelW, NY.fresh, NY.street
	local iron, stoneT, glassD, lit = rgb(30, 30, 34), rgb(222, 214, 196), rgb(46, 58, 72), rgb(255, 214, 140)
	local function dk() return { decor = true } end
	-- Repère d'une façade : origine au pied de la façade (|z| = 19,85, devant le muret), x local le long
	-- de la rue, -Z local vers la chaussée, +Z local derrière le muret.
	local function frameFor(side, x0, x1)
		if side == "N" then return CFrame.new(x0, 0, 19.85) end
		return CFrame.new(x1, 0, -19.85) * CFrame.Angles(0, math.pi, 0)
	end
	NY.frameFor = frameFor
	local seed = 7
	local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end

	local H = fresh("Buildings")
	-- b = { name, side, x0, x1, h, brick, trim, door, shop, shopColor, fe (escalier de secours), wt (château d'eau), wtx, entry = "L"/"R" }
	local function tenement(b)
		local m = Instance.new("Model"); m.Name = b.name; m.Parent = H
		local fr = frameFor(b.side, b.x0, b.x1)
		local w, h, D = b.x1 - b.x0, b.h, 8
		Bx(m, fr, "Wall", 0, 0, 0, w, h, D, b.brick, { studs = true, decor = true })
		Bx(m, fr, "Base", 0, 0.3, -0.1, w, 1.2, 0, rgb(86, 84, 82), dk())
		-- Rez-de-chaussée : entrée à perron d'un côté, boutique fermée par un rideau de fer de l'autre
		local ex0 = (b.entry == "L") and 1.5 or (w - 4.0)
		local ex1 = ex0 + 2.5
		local gx0, gx1 = (b.entry == "L") and 7 or 2, (b.entry == "L") and (w - 1.5) or (w - 7)
		Bx(m, fr, "EntryDoor", ex0, 0.9, -0.14, ex1, 6.6, 0, b.door, dk())
		Bx(m, fr, "EntryCanopy", ex0 - 0.4, 6.8, -1.4, ex1 + 0.4, 7.2, 0, iron, dk())
		Bx(m, fr, "EntryLamp", ex1 + 0.3, 5.0, -0.35, ex1 + 0.7, 5.6, 0, lit, { decor = true, mat = Enum.Material.Neon })
		Bx(m, fr, "Step1", ex0 - 0.3, 0.3, -1.3, ex1 + 0.3, 0.6, 0, stoneT, { studs = true })
		Bx(m, fr, "Step2", ex0 - 0.3, 0.6, -0.7, ex1 + 0.3, 0.9, 0, stoneT, { studs = true })
		Bx(m, fr, "ShopGate", gx0, 0.3, -0.12, gx1, 6.4, 0, rgb(150, 154, 160), { decor = true, mat = Enum.Material.DiamondPlate })
		Bx(m, fr, "GateBox", gx0 - 0.2, 6.4, -0.4, gx1 + 0.2, 7.0, 0, rgb(110, 114, 120), dk())
		label(Bx(m, fr, "ShopSign", gx0, 7.0, -0.3, gx1, 8.4, 0, b.shopColor, dk()), Enum.NormalId.Front, b.shop, rgb(255, 255, 255), 40)
		-- Étages : fenêtres à encadrement clair sur un bandeau d'appui ; une sur cinq environ est allumée
		local floors = math.floor((h - 10.2) / 4.4)
		local cols = { w / 6, w / 2, 5 * w / 6 }
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
			local px0, px1 = cols[1] - 2.0, cols[2] + 2.0
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
			local wx, wz = b.wtx, 4
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
	end
	local trimA, trimB = rgb(226, 218, 200), rgb(196, 190, 176)
	for _, b in {
		{ name = "Tenement_N1", side = "N", x0 = 581, x1 = 600, h = 26, brick = rgb(124, 72, 52), trim = trimA, door = rgb(30, 70, 50), shop = "DELI", shopColor = rgb(170, 40, 40), fe = true, entry = "L" },
		{ name = "Tenement_N2", side = "N", x0 = 600, x1 = 620, h = 31, brick = rgb(150, 68, 52), trim = trimA, door = rgb(30, 45, 95), shop = "PIZZA", shopColor = rgb(40, 120, 60), wt = true, wtx = 6, entry = "R" },
		{ name = "Tenement_N3", side = "N", x0 = 620, x1 = 640, h = 24, brick = rgb(102, 62, 46), trim = trimB, door = rgb(120, 30, 34), shop = "LAUNDROMAT", shopColor = rgb(40, 110, 180), fe = true, entry = "L" },
		{ name = "Tenement_N4", side = "N", x0 = 680, x1 = 700, h = 28, brick = rgb(134, 82, 60), trim = trimA, door = rgb(25, 25, 30), shop = "COFFEE", shopColor = rgb(110, 70, 40), fe = true, wt = true, wtx = 15, entry = "R" },
		{ name = "Tenement_S1", side = "S", x0 = 581, x1 = 600, h = 28, brick = rgb(140, 76, 56), trim = trimA, door = rgb(120, 30, 34), shop = "BAGELS", shopColor = rgb(200, 140, 40), fe = true, wt = true, wtx = 14, entry = "L" },
		{ name = "Tenement_S2", side = "S", x0 = 600, x1 = 620, h = 24, brick = rgb(190, 152, 104), trim = trimB, door = rgb(30, 70, 50), shop = "FLOWERS", shopColor = rgb(200, 80, 140), wt = true, wtx = 6, entry = "R" },
		{ name = "Tenement_S3", side = "S", x0 = 620, x1 = 640, h = 30, brick = rgb(114, 66, 48), trim = trimA, door = rgb(30, 45, 95), shop = "DRY CLEANING", shopColor = rgb(60, 60, 140), fe = true, entry = "L" },
	} do tenement(b) end
	H.Parent = S

	-- Parking à étages (sud, x 680..700) : façade fermée sur le muret, deux niveaux ouverts au-dessus,
	-- trois taxis jaunes garés derrière le muret, nez vers la rue (hors de la chaussée)
	local Pk = fresh("Parking")
	local fr = frameFor("S", 680, 700)
	local conc, concD, railC = rgb(176, 174, 168), rgb(140, 138, 134), rgb(200, 200, 196)
	local D = 13
	Bx(Pk, fr, "GroundWall", 0, 0, 0, 20, 12.4, 1.4, conc, { studs = true, decor = true })
	Bx(Pk, fr, "Base", 0, 0.3, -0.1, 20, 1.2, 0, rgb(86, 84, 82), dk())
	Bx(Pk, fr, "Gate", 6, 0.3, -0.12, 14, 7.0, 0, rgb(150, 154, 160), { decor = true, mat = Enum.Material.DiamondPlate })
	Bx(Pk, fr, "GateBox", 5.8, 7.0, -0.4, 14.2, 7.6, 0, rgb(110, 114, 120), dk())
	for k, y in { 12.4, 18.6 } do
		Bx(Pk, fr, "Deck_" .. k, 0, y, 0, 20, y + 0.6, D, conc, { studs = true, decor = true })
		Bx(Pk, fr, "Rail_" .. k .. "A", 0, y + 1.6, -0.1, 20, y + 1.75, 0.05, railC, dk())
		Bx(Pk, fr, "Rail_" .. k .. "B", 0, y + 1.0, -0.1, 20, y + 1.15, 0.05, railC, dk())
	end
	Bx(Pk, fr, "RoofDeck", 0, 24.8, 0, 20, 25.4, D, concD, { studs = true, decor = true })
	Bx(Pk, fr, "RoofParapet", 0, 25.4, -0.1, 20, 26.4, 0.5, conc, dk())
	for k, x in { 0, 9.7, 19.4 } do
		Bx(Pk, fr, "GaragePillar_" .. k, x, 13.0, 0, x + 0.6, 24.8, 0.6, concD, dk())
	end
	Bx(Pk, fr, "GarageSide_L", -0.05, 12.4, 0.6, 0.35, 24.8, D, concD, dk())
	Bx(Pk, fr, "GarageSide_R", 19.65, 12.4, 0.6, 20.05, 24.8, D, concD, dk())
	Bx(Pk, fr, "GarageBack", 0, 12.4, D - 0.4, 20, 24.8, D, concD, dk())
	local blue, taxiY = rgb(30, 80, 170), rgb(250, 196, 20)
	label(Bx(Pk, fr, "ParkingSign", 1.0, 7.8, -0.3, 5.2, 11.6, 0, blue, dk()), Enum.NormalId.Front, "P", rgb(255, 255, 255), 40, blue)
	label(Bx(Pk, fr, "ParkingBand", 6, 8.0, -0.3, 19, 9.6, 0, taxiY, dk()), Enum.NormalId.Front, "TAXI · PARKING", iron, 40, taxiY)
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
	taxi("Taxi_1", fr * CFrame.new(4.5, 13.0, 6.5))
	taxi("Taxi_2", fr * CFrame.new(15.5, 13.0, 7.0) * CFrame.Angles(0, math.rad(-6), 0))
	taxi("Taxi_3", fr * CFrame.new(10, 19.2, 6.5) * CFrame.Angles(0, math.rad(8), 0))
	Pk.Parent = S
end

-- Bloc D2 : repères du quartier derrière les murets (gratte-ciel Art déco, tour de verre) et fond du couloir :
-- façade plaquée sur l'EndWall (x = 700) et grande tour derrière lui, visible depuis tout le couloir.
do
	local NY = _G.ClaudeNY
	assert(NY and NY.Bx, "envoyer d'abord le bloc C")
	local rgb = Color3.fromRGB
	local P, Bx, vcyl, label, fresh, S = NY.P, NY.Bx, NY.vcylW, NY.labelW, NY.fresh, NY.street
	local W = CFrame.identity
	local gold, iron, bronze = rgb(212, 172, 60), rgb(30, 30, 34), rgb(104, 74, 40)
	local glassC, neonC, tipC = rgb(52, 64, 80), rgb(255, 204, 110), rgb(255, 70, 60)
	local Sk = fresh("Skyline")

	-- Tour à gradins : tiers = { hw, hd, y0, y1, color, mat?, strips?, stripFrom?, neon? } ;
	-- face = côté de la rue ("-z", "+z" ou "-x") où sont posées les bandes de fenêtres
	local function tower(name, cx, cz, face, tiers, spire, spireColor)
		local m = Instance.new("Model"); m.Name = name; m.Parent = Sk
		for i, t in tiers do
			Bx(m, W, "Tier_" .. i, cx - t.hw, t.y0, cz - t.hd, cx + t.hw, t.y1, cz + t.hd, t.color, { studs = true, decor = true, mat = t.mat })
			local n = t.strips or 0
			local ya, yb = t.stripFrom or (t.y0 + 1.5), t.y1 - 1.5
			for k = 1, n do
				local nm = string.format("Glass_%d_%d", i, k)
				if face == "-x" then
					local sz = cz - t.hd + 1 + (2 * t.hd - 2) * (k - 0.5) / n
					Bx(m, W, nm, cx - t.hw - 0.12, ya, sz - 0.45, cx - t.hw, yb, sz + 0.45, glassC, { decor = true, mat = Enum.Material.Glass })
				else
					local s = (face == "-z") and -1 or 1
					local sx = cx - t.hw + 1 + (2 * t.hw - 2) * (k - 0.5) / n
					Bx(m, W, nm, sx - 0.45, ya, cz + s * t.hd, sx + 0.45, yb, cz + s * (t.hd + 0.12), glassC, { decor = true, mat = Enum.Material.Glass })
				end
			end
			if t.neon then
				Bx(m, W, "Neon_" .. i, cx - t.hw - 0.15, t.y1 - 0.3, cz - t.hd - 0.15, cx + t.hw + 0.15, t.y1 + 0.05, cz + t.hd + 0.15, neonC, { decor = true, mat = Enum.Material.Neon, noShadow = true })
			end
		end
		if spire then
			vcyl(m, W, "Spire", cx, spire[1], spire[2], cz, spire[3], spireColor or rgb(190, 196, 204), { decor = true })
			P(m, "SpireTip", CFrame.new(cx, spire[2] + 0.4, cz), Vector3.new(0.8, 0.8, 0.8), tipC, { shape = Enum.PartType.Ball, mat = Enum.Material.Neon, decor = true })
		end
		return m
	end
	local beige, grey, brick, sand = rgb(214, 198, 166), rgb(176, 176, 184), rgb(150, 84, 64), rgb(196, 170, 130)
	-- Nord : tour Art déco beige et tour de verre bleue ; sud : tour Art déco grise et immeuble de brique
	tower("Skyscraper_N1", 601, 44, "-z", {
		{ hw = 8, hd = 7, y0 = 0, y1 = 62, color = beige, strips = 4 },
		{ hw = 6, hd = 5, y0 = 62, y1 = 78, color = beige, strips = 3, neon = true },
		{ hw = 4, hd = 3.5, y0 = 78, y1 = 88, color = beige, strips = 2, neon = true },
		{ hw = 2, hd = 2, y0 = 88, y1 = 92, color = gold },
	}, { 92, 106, 0.6 })
	local glassTower = tower("Skyscraper_N2", 628, 44, "-z", {
		{ hw = 7, hd = 6, y0 = 0, y1 = 74, color = rgb(86, 128, 170), mat = Enum.Material.Glass },
		{ hw = 6, hd = 5, y0 = 74, y1 = 76, color = rgb(150, 156, 164) },
	}, { 76, 88, 0.4 })
	for k, y in { 12, 24, 36, 48, 60 } do
		Bx(glassTower, W, "Band_" .. k, 628 - 7.1, y, 44 - 6.1, 628 + 7.1, y + 0.8, 44 + 6.1, rgb(232, 236, 240), { decor = true })
	end
	tower("Skyscraper_S1", 603, -44, "+z", {
		{ hw = 8, hd = 7, y0 = 0, y1 = 70, color = grey, strips = 4 },
		{ hw = 6, hd = 5.5, y0 = 70, y1 = 84, color = grey, strips = 3, neon = true },
		{ hw = 4.5, hd = 4, y0 = 84, y1 = 92, color = grey, strips = 2, neon = true },
		{ hw = 3, hd = 2.5, y0 = 92, y1 = 98, color = rgb(200, 204, 210), neon = true },
	}, { 98, 114, 0.7 })
	tower("Skyscraper_S2", 629, -42, "+z", {
		{ hw = 7, hd = 6, y0 = 0, y1 = 48, color = brick, strips = 3 },
		{ hw = 5, hd = 4.5, y0 = 48, y1 = 58, color = brick, strips = 2 },
		{ hw = 2.5, hd = 2.5, y0 = 58, y1 = 61, color = rgb(90, 60, 50) },
	})
	-- Derrière les murets du bout de la rue (x 680..700)
	tower("Skyscraper_E1", 691, 42, "-z", {
		{ hw = 7, hd = 7, y0 = 0, y1 = 96, color = rgb(40, 48, 60), mat = Enum.Material.Glass, neon = true },
		{ hw = 5, hd = 5, y0 = 96, y1 = 100, color = rgb(150, 156, 164) },
	}, { 100, 116, 0.5 })
	tower("Skyscraper_E2", 691, -44, "+z", {
		{ hw = 7, hd = 7, y0 = 0, y1 = 52, color = sand, strips = 3 },
		{ hw = 5, hd = 5, y0 = 52, y1 = 60, color = sand, neon = true },
	})

	-- Fond du couloir : façade Art déco plaquée sur l'EndWall (sans collision ; l'EndWall reste le vrai mur)
	local E = tower("EndTower", 716, 0, "-x", {
		{ hw = 13, hd = 13, y0 = 0, y1 = 72, color = beige, strips = 5, stripFrom = 26 },
		{ hw = 10, hd = 10, y0 = 72, y1 = 96, color = beige, strips = 4, neon = true },
		{ hw = 7, hd = 7, y0 = 96, y1 = 112, color = beige, strips = 3, neon = true },
		{ hw = 5, hd = 5, y0 = 112, y1 = 120, color = gold, neon = true },
		{ hw = 3, hd = 3, y0 = 120, y1 = 126, color = gold },
	}, { 126, 152, 1.0 }, gold)
	local dark = rgb(206, 190, 158)
	Bx(E, W, "EndGround", 700, -2, -32, 734, 0, 32, rgb(70, 72, 76), { studs = true, decor = true })
	Bx(E, W, "EndFacade", 699.85, 0, -19.85, 703.2, 24, 19.85, beige, { studs = true, decor = true })
	for k, z in { -14, -5, 5, 14 } do
		Bx(E, W, "EndPier_" .. k, 699.5, 0.3, z - 0.8, 699.85, 26, z + 0.8, dark, { studs = true, decor = true })
	end
	for k, zr in { { -19.2, -15 }, { -13, -6 }, { 6, 13 }, { 15, 19.2 } } do
		Bx(E, W, "EndWindow_" .. k, 699.75, 2, zr[1], 699.85, (math.abs(zr[1]) > 14) and 22 or 18, zr[2], glassC, { decor = true, mat = Enum.Material.Glass })
	end
	Bx(E, W, "EndDoorFrame", 699.65, 0.3, -4.6, 699.85, 9.3, 4.6, bronze, { decor = true })
	Bx(E, W, "EndDoors", 699.55, 0.3, -4.0, 699.65, 8.6, 4.0, gold, { decor = true })
	for k = 1, 5 do
		local a = math.rad(k * 30)
		P(E, "Sunburst_" .. k, CFrame.new(699.6, 9.3 + 2.4 * math.sin(a), 2.4 * math.cos(a)) * CFrame.Angles(-a, 0, 0), Vector3.new(0.1, 0.3, 4.0), gold, { decor = true })
	end
	P(E, "ClockRim", CFrame.new(699.65, 16.5, 0), Vector3.new(0.3, 5.0, 5.0), gold, { shape = Enum.PartType.Cylinder, decor = true })
	P(E, "ClockFace", CFrame.new(699.45, 16.5, 0), Vector3.new(0.15, 4.4, 4.4), rgb(250, 246, 232), { shape = Enum.PartType.Cylinder, decor = true })
	P(E, "MinuteHand", CFrame.new(699.33, 17.4, 0), Vector3.new(0.06, 1.8, 0.16), iron, { decor = true })
	P(E, "HourHand", CFrame.new(699.33, 16.5, 0.6), Vector3.new(0.06, 0.18, 1.2), iron, { decor = true })
	P(E, "ClockPin", CFrame.new(699.3, 16.5, 0), Vector3.new(0.35, 0.35, 0.35), gold, { shape = Enum.PartType.Ball, decor = true })
	label(Bx(E, W, "EndSign", 699.6, 20.0, -10, 699.85, 22.0, 10, rgb(36, 40, 48), { decor = true }), Enum.NormalId.Left, "FORTUNE TOWER", gold, 40)
	Bx(E, W, "EndBand", 699.7, 22.4, -19.85, 699.85, 22.8, 19.85, gold, { decor = true })
	Bx(E, W, "EndCornice", 699.4, 24, -19.85, 703.2, 24.6, 19.85, dark, { decor = true })
	Sk.Parent = S
end

-- Bilan
do
	local NY = _G.ClaudeNY
	local n = 0
	for _, d in workspace.Map.Zone_6.Street_NewYork:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	local c = NY.counts or {}
	return string.format("Zone 6 New York : banque %d produits, salle des coffres %d produits, rue %d pièces", c.bank or 0, c.vault or 0, n)
end
