--!nocheck
--[[
	Range les tapis de course importés par Clément (MOD-016, 2026-11-08). Les FBX viennent de
	StealAShop-Art/Training/Treadmill (scripts Blender build_treadmill.py pour Base et Silver,
	build_treadmill_variant.py pour les variantes texturées Void et Fire) et arrivent dans
	Workspace par l'Importateur 3D, sous le nom du fichier.

	À envoyer d'un bloc à execute_luau, en mode Edit. Relançable : une variante sans import dans
	Workspace garde sa version déjà rangée.

	Résultat : ReplicatedStorage/Assets/Plots/PLOT_Treadmill_<Variante>, pivot en bas au centre à
	l'origine, avant (console ou portique) vers -Z, sans tag. Même repère pour toutes les
	variantes : le code en copie une au pivot de Treadmill, la nomme Treadmill et lui donne le tag.
	Chaque variante contient :
	  - ses maillages, aux couleurs du modèle (Neon pour les lueurs), sans collision ;
	  - Belt, la bande, avec la Texture BeltTexture que le code fait défiler (OffsetStudsV) et
	    l'Attachment UsePoint (place du coureur, tourné vers -Z). Pour Void et Fire, Belt est une
	    Part plate qui reprend l'image de la bande (importée sur le maillage) en BeltTexture ;
	  - UpgradePoint (Attachment au sol en (8,4, 0, -4) depuis le pivot, tourné vers +Z (la boutique), même point pour toutes les variantes) ;
	  - UseZone (Part invisible, sans collision, CanTouch) : la machine + 3 studs autour (1,5 côté boutique, +Z), 8 studs de haut ; le code fait monter le joueur dès qu'il y entre ;
	  - des boîtes invisibles Collision_* qui portent les collisions.
	La boutique (plot_shop_builder.luau) copie PLOT_Treadmill_Base sous le nom Treadmill.
]]

local RS = game:GetService("ReplicatedStorage")
local rgb = Color3.fromRGB

-- Données des JSON (couleurs sRGB, lueurs, repères) ; colliders : { nom, min, max } en studs.
local VARIANTS = {
	PLOT_Treadmill_Base = {
		parts = {
			Belt = { rgb(35, 36, 39) }, BeltArrows = { rgb(243, 242, 235) }, BeltEnds = { rgb(35, 36, 39) },
			Frame = { rgb(183, 187, 195) }, Trim = { rgb(61, 63, 69) }, ConsoleScreen = { rgb(61, 63, 69) },
			ConsoleButtons = { rgb(162, 168, 177), reflect = 0.15 },
		},
		beltTexture = "rbxassetid://95120777733359", -- ENV_Texture_Stud (L-030), comme l'ancien tapis
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.26, 0, -4.307), Vector3.new(2.26, 0.834, 4.307) },
			{ "Collision_Hood", Vector3.new(-2.26, 0.834, -4.06), Vector3.new(2.26, 1.24, -2.7) },
			{ "Collision_Console", Vector3.new(-2.26, 1.24, -4.31), Vector3.new(2.26, 4.57, -3.2) },
		},
	},
	PLOT_Treadmill_Silver = {
		parts = {
			Belt = { rgb(35, 36, 39) }, BeltArrows = { rgb(243, 242, 235) }, BeltEnds = { rgb(35, 36, 39) },
			Frame = { rgb(227, 230, 235), reflect = 0.12 }, Trim = { rgb(121, 126, 135) }, ConsoleScreen = { rgb(121, 126, 135) },
			ConsoleButtons = { rgb(246, 247, 249), reflect = 0.3 },
		},
		beltTexture = "rbxassetid://95120777733359",
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.26, 0, -4.307), Vector3.new(2.26, 0.834, 4.307) },
			{ "Collision_Hood", Vector3.new(-2.26, 0.834, -4.06), Vector3.new(2.26, 1.24, -2.7) },
			{ "Collision_Console", Vector3.new(-2.26, 1.24, -4.31), Vector3.new(2.26, 4.57, -3.2) },
		},
	},
	PLOT_Treadmill_Void = {
		parts = {
			Belt = { rgb(20, 16, 28) }, BeltEnds = { rgb(153, 81, 255) }, VoidCrystal = { rgb(61, 32, 102), reflect = 0.2 },
			VoidCore = { rgb(21, 18, 25) }, VoidGlow = { rgb(196, 139, 255), neon = true }, VoidSteel = { rgb(75, 65, 94), reflect = 0.1 },
			Obsidian = { rgb(40, 33, 51), reflect = 0.15 }, VoidGlowPink = { rgb(255, 139, 223), neon = true },
		},
		flatBelt = true, -- l'image de la bande est sur le maillage importé
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.52, 0, -2.86), Vector3.new(2.52, 1.014, 4.1) },
			{ "Collision_Front", Vector3.new(-2.8, 1.014, -4.02), Vector3.new(2.817, 7.8, -2.56) },
			{ "Collision_Rear", Vector3.new(-2.48, 1.014, 3.84), Vector3.new(2.48, 2.94, 4.06) },
		},
	},
	-- Ice : fichier déjà en studs (build_treadmill_variant.py --studs --keep-names), matériaux repris de
	-- IceTreadmill.lua (référence de Clément) ; l'image de la bande est importée à part (PLOT_Treadmill_Ice_Belt).
	PLOT_Treadmill_Ice = {
		parts = {
			Belt = { rgb(40, 41, 43) }, BeltArrows = { rgb(92, 242, 255), neon = true }, BeltEnds = { rgb(40, 41, 43) },
			ConsoleButtons = { rgb(229, 247, 255) }, ConsoleScreen = { rgb(22, 46, 75), mat = Enum.Material.Glass },
			CrystalGlow = { rgb(92, 242, 255), neon = true },
			Crystals = { rgb(143, 216, 255), mat = Enum.Material.Glass, transparency = 0.25, reflect = 0.15 },
			Frame = { rgb(63, 138, 255) }, Trim = { rgb(35, 61, 137) },
		},
		flatBelt = true,
		beltImage = "rbxassetid://77242952343811", -- PLOT_Treadmill_Ice_Belt
		beltTile = Vector2.new(3.4, 1.7), -- tuile du script de Clément (3,4 x 1,7 studs)
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.25, 0, -3.25), Vector3.new(2.25, 0.83, 4.3) },
			{ "Collision_Front", Vector3.new(-2.25, 0.83, -4.3), Vector3.new(2.25, 7.498, -2.96) },
			{ "Collision_Rear", Vector3.new(-2.25, 0.83, 3.484), Vector3.new(2.25, 2.224, 4.3) },
		},
	},
	-- Gold (palier 1) : fichier déjà en studs, matériaux repris de GoldTreadmill.lua (référence de Clément).
	PLOT_Treadmill_Gold = {
		parts = {
			Belt = { rgb(40, 41, 46) }, BeltEnds = { rgb(40, 41, 46) },
			Columns = { rgb(245, 241, 229) }, Wings = { rgb(245, 241, 229) },
			ConsoleButtons = { rgb(255, 228, 92), neon = true }, ConsoleScreen = { rgb(40, 41, 46) },
			Frame = { rgb(255, 193, 32), mat = Enum.Material.Metal }, Trim = { rgb(200, 137, 19), mat = Enum.Material.Metal },
			GoldGlow = { rgb(255, 228, 92), neon = true },
		},
		flatBelt = true,
		beltImage = "rbxassetid://136595680115418", -- FX_Treadmill_Gold_Belt
		beltTile = Vector2.new(3.44, 1.72),
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.25, 0, -2.55), Vector3.new(2.25, 0.83, 4.3) },
			{ "Collision_Front", Vector3.new(-2.25, 0.83, -4.3), Vector3.new(2.25, 6.44, -2.287) },
			{ "Collision_Rear", Vector3.new(-2.25, 0.83, 4.26), Vector3.new(2.25, 1.25, 4.3) },
		},
	},
	-- Cash Register (CashRegisterTreadmill.glb de Clément) : fichier déjà en studs, 2 900 triangles gardés en
	-- entier (alléger abîmait pièces et billets) ; pièces à deux couleurs séparées (BillsBandGreen, RegisterGold).
	PLOT_Treadmill_CashRegister = {
		parts = {
			Belt = { rgb(47, 51, 57) }, BeltEnds = { rgb(47, 51, 57) }, ConsoleScreen = { rgb(47, 51, 57) },
			Bills = { rgb(216, 242, 195) }, BillsBandGreen = { rgb(61, 169, 92) },
			Coins = { rgb(255, 194, 26), mat = Enum.Material.Foil }, Frame = { rgb(61, 169, 92) },
			GlowMint = { rgb(47, 224, 143), neon = true }, Register = { rgb(61, 169, 92) }, RegisterGold = { rgb(255, 193, 32) },
		},
		flatBelt = true,
		beltImage = "rbxassetid://90862200051580", -- PLOT_Treadmill_CashRegister_Belt
		beltTile = Vector2.new(3.44, 1.72),
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.24, 0, -3.2), Vector3.new(2.24, 0.87, 4.3) },
			{ "Collision_Front", Vector3.new(-2.22, 0.87, -4.3), Vector3.new(2.22, 6.4, -2.42) },
		},
	},
	-- Police (PoliceTreadmill.glb de Clément) : fichier déjà en studs, 1 899 triangles (rubans et menottes
	-- allégés, --budget 1900), pièces multicolores séparées (FramePanelWhite, LightBarChrome, PoliceCap...).
	PLOT_Treadmill_Police = {
		parts = {
			Belt = { rgb(40, 41, 43) }, BeltEnds = { rgb(40, 41, 43) }, Trim = { rgb(63, 65, 71) },
			Frame = { rgb(33, 46, 75) }, FramePanelWhite = { rgb(242, 244, 247) },
			Barriers = { rgb(33, 46, 75) }, BarriersPanelWhite = { rgb(242, 244, 247) },
			Badge = { rgb(255, 193, 32), mat = Enum.Material.Foil },
			ConsoleButtons = { rgb(242, 244, 247) }, ConsoleScreen = { rgb(23, 30, 41), mat = Enum.Material.Glass },
			Handcuffs = { rgb(182, 189, 199), mat = Enum.Material.Metal, reflect = 0.25 },
			LightBar = { rgb(35, 36, 41) }, LightBarChrome = { rgb(182, 189, 199), mat = Enum.Material.Metal, reflect = 0.25 },
			PoliceCap = { rgb(35, 36, 41) }, PoliceCapBadgeGold = { rgb(255, 193, 32), mat = Enum.Material.Foil },
			PoliceCapPoliceNavy = { rgb(33, 46, 75) },
			SirenBlue = { rgb(47, 155, 255), neon = true }, SirenRed = { rgb(255, 42, 58), neon = true },
			TapeBlack = { rgb(35, 36, 41) }, TapeYellow = { rgb(255, 209, 32) },
			TrafficCones = { rgb(255, 121, 32) }, TrafficConesPanelWhite = { rgb(242, 244, 247) },
		},
		flatBelt = true,
		beltImage = "rbxassetid://92650377809201", -- PLOT_Treadmill_Police_Belt
		beltTile = Vector2.new(3.4, 1.7),
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.25, 0, -2.55), Vector3.new(2.25, 0.87, 4.3) },
			{ "Collision_Front", Vector3.new(-2.2, 0.87, -4.25), Vector3.new(2.2, 5.52, -2.417) },
			{ "Collision_Rear", Vector3.new(-2.25, 0.87, 4.05), Vector3.new(2.25, 2.91, 4.3) },
		},
	},
	-- Laser Vault, palier 4 (LaserVaultTreadmill.glb de Clément) : fichier déjà en studs, 1 899 triangles (châssis
	-- et liserés dorés allégés, --budget 1900), pièces bicolores séparées. L'arrière est un portique : deux poteaux
	-- et une traverse en collision, pas un mur, pour monter sur la bande par l'arrière.
	PLOT_Treadmill_LaserVault = {
		parts = {
			Belt = { rgb(40, 41, 43) }, BeltEnds = { rgb(40, 41, 43) }, ConsoleScreen = { rgb(33, 35, 39), mat = Enum.Material.Glass },
			AlarmGlow = { rgb(255, 59, 92), neon = true }, LaserBeams = { rgb(255, 42, 61), neon = true },
			Frame = { rgb(77, 80, 88), mat = Enum.Material.DiamondPlate }, FrameSteelPlate = { rgb(153, 159, 169), mat = Enum.Material.DiamondPlate },
			GoldBars = { rgb(255, 193, 32), mat = Enum.Material.Foil }, GoldTrim = { rgb(255, 193, 32), mat = Enum.Material.Foil },
			LaserEmitters = { rgb(46, 48, 52) }, SecurityCamera = { rgb(153, 159, 169) }, SecurityCameraCameraLens = { rgb(46, 48, 52) },
			VaultDoor = { rgb(77, 80, 88), mat = Enum.Material.DiamondPlate }, VaultDoorVaultSteel = { rgb(182, 189, 199), mat = Enum.Material.DiamondPlate },
		},
		flatBelt = true,
		beltImage = "rbxassetid://88509301607993", -- PLOT_Treadmill_LaserVault_Belt
		beltTile = Vector2.new(3.4, 1.7),
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.25, 0, -2.77), Vector3.new(2.25, 0.87, 4.3) },
			{ "Collision_Front", Vector3.new(-2.24, 0.87, -4.3), Vector3.new(2.24, 6.169, -2.3) },
			{ "Collision_RearL", Vector3.new(-2.25, 0.87, 4.0), Vector3.new(-1.6, 6.9, 4.3) },
			{ "Collision_RearR", Vector3.new(1.6, 0.87, 4.0), Vector3.new(2.25, 6.9, 4.3) },
			{ "Collision_RearTop", Vector3.new(-2.25, 6.2, 4.0), Vector3.new(2.25, 6.9, 4.3) },
		},
	},
	-- Toxic Gothic, palier 6 (ToxicGothicTreadmill.glb de Clément) : fichier déjà en studs, 2 098 triangles
	-- (slime, barils et grille allégés, --budget 2100). Pas d'image de bande dans le pack : flèches en relief
	-- (BeltArrows) et texture à studs qui défile, comme le tapis de base.
	PLOT_Treadmill_Toxic = {
		parts = {
			Belt = { rgb(44, 45, 47) }, BeltEnds = { rgb(44, 45, 47) }, BeltArrows = { rgb(124, 255, 46), neon = true },
			Bats = { rgb(39, 35, 45) }, ConsoleButtons = { rgb(167, 86, 247) }, ConsoleScreen = { rgb(27, 42, 32) },
			Frame = { rgb(61, 65, 75), mat = Enum.Material.Slate }, GothicGate = { rgb(61, 65, 75), mat = Enum.Material.Slate },
			Gravestone = { rgb(86, 91, 103), mat = Enum.Material.Slate }, IronFence = { rgb(39, 35, 45), mat = Enum.Material.Metal },
			LanternGlow = { rgb(182, 255, 59), neon = true }, ToxicBarrels = { rgb(65, 173, 46), reflect = 0.12 },
			ToxicGoo = { rgb(124, 255, 46), neon = true }, Trim = { rgb(39, 35, 45), mat = Enum.Material.Metal },
		},
		beltTexture = "rbxassetid://95120777733359", -- ENV_Texture_Stud (L-030), comme le tapis de base
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.25, 0, -3.72), Vector3.new(2.25, 0.83, 4.3) },
			{ "Collision_Front", Vector3.new(-2.25, 0.83, -4.3), Vector3.new(2.25, 7.95, -3.11) },
			{ "Collision_Rear", Vector3.new(-2.17, 0.83, 3.463), Vector3.new(2.17, 3.753, 4.3) },
		},
	},
	-- Candy, palier 7 (CandyTreadmill.glb de Clément) : fichier déjà en studs, 2 499 triangles (bordures, glaçage et
	-- bonbons allégés, --budget 2500 ; sucres d'orge et sucettes intacts). Plastique brillant (Reflectance 0,08).
	-- L'arrière est l'arche des sucres d'orge : deux poteaux et une traverse en collision, pas un mur.
	PLOT_Treadmill_Candy = {
		parts = {
			Belt = { rgb(44, 45, 47) }, BeltEnds = { rgb(44, 45, 47) }, BeltArrows = { rgb(255, 214, 234), neon = true },
			CandyCanes = { rgb(255, 246, 242), reflect = 0.08 }, CandyCaneStripes = { rgb(231, 42, 61), reflect = 0.08 },
			CandyGlow = { rgb(255, 79, 163), neon = true }, ConsoleButtons = { rgb(255, 121, 183), reflect = 0.08 },
			ConsoleScreen = { rgb(61, 27, 41), reflect = 0.08 }, Frame = { rgb(255, 246, 242), reflect = 0.08 },
			Frosting = { rgb(255, 121, 183), reflect = 0.08 }, HardCandies = { rgb(231, 42, 61), reflect = 0.08 },
			Lollipops = { rgb(255, 121, 183), reflect = 0.08 }, LollipopSticks = { rgb(255, 246, 242), reflect = 0.08 },
			Peppermint = { rgb(255, 246, 242), reflect = 0.08 }, PeppermintSwirl = { rgb(231, 42, 61), reflect = 0.08 },
			Sprinkles = { rgb(255, 246, 242), reflect = 0.08 }, Trim = { rgb(231, 42, 61), reflect = 0.08 },
			WrappedCandies = { rgb(255, 121, 183), reflect = 0.08 },
		},
		flatBelt = true,
		beltImage = "rbxassetid://96315500224842", -- PLOT_Treadmill_Candy_Belt
		beltTile = Vector2.new(3.4, 1.7),
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.21, 0, -4.1), Vector3.new(2.21, 0.83, 4.3) },
			{ "Collision_Front", Vector3.new(-2.2, 0.83, -4.3), Vector3.new(2.2, 5.9, -2.96) },
			{ "Collision_RearL", Vector3.new(-2.21, 0.83, 3.52), Vector3.new(-1.15, 7.625, 4.3) },
			{ "Collision_RearR", Vector3.new(1.15, 0.83, 3.52), Vector3.new(2.21, 7.625, 4.3) },
			{ "Collision_RearTop", Vector3.new(-2.21, 6.8, 3.52), Vector3.new(2.21, 7.625, 4.3) },
		},
	},
	-- Fire (version 2, FireTreadmill.glb de Clément, 2026-11-08) : fichier déjà en studs, matériaux repris
	-- de FireTreadmill.lua. La version 1 (treadmill_feu.glb) est gardée dans StealAShop-Art en _v1.
	PLOT_Treadmill_Fire = {
		parts = {
			Belt = { rgb(35, 22, 17) }, BeltEnds = { rgb(255, 121, 27), neon = true }, ConsoleScreen = { rgb(35, 22, 17) },
			DarkCore = { rgb(39, 38, 40) }, EmberGlow = { rgb(255, 90, 23), neon = true }, GlowAmber = { rgb(255, 193, 61), neon = true },
			Gunmetal = { rgb(77, 80, 88), mat = Enum.Material.Metal }, Steel = { rgb(152, 156, 166), mat = Enum.Material.Metal },
		},
		flatBelt = true,
		beltImage = "rbxassetid://119393306641836", -- FX_Treadmill_Fire_Belt
		beltTile = Vector2.new(3.44, 1.72),
		upgrade = Vector3.new(8.4, 0, -4), -- panneau au sol, (-15,6, -50) dans la boutique, tourné vers elle (Clément, 2026-11-08)
		colliders = {
			{ "Collision_Base", Vector3.new(-2.25, 0, -3.35), Vector3.new(2.25, 0.83, 4.3) },
			{ "Collision_Front", Vector3.new(-2.25, 0.83, -4.3), Vector3.new(2.25, 4.7, -2.36) },
			{ "Collision_Rear", Vector3.new(-2.25, 0.83, 4.054), Vector3.new(2.25, 1.335, 4.3) },
		},
	},
}

local function box(parent, name, lo, hi)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = hi - lo
	p.CFrame = CFrame.new((lo + hi) / 2)
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = true
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function attachment(name, part, pos, look)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = part
	a.WorldCFrame = CFrame.lookAt(pos, pos + (look or Vector3.new(0, 0, -1)))
	return a
end

-- Zone d'entrée (Clément, 2026-11-11) : pièce invisible UseZone autour de la machine, sans collision.
-- Le code fait monter le joueur dès qu'il y entre. Marge de 3 studs autour du tapis, 8 studs de haut.
-- Côté boutique (+Z, l'arrière du tapis), marge réduite : la zone s'arrête avant le mur de façade.
local USE_MARGIN, USE_REAR, USE_HEIGHT = 3, 1.5, 8
local function useZone(m)
	local old = m:FindFirstChild("UseZone")
	if old then old:Destroy() end
	local pivot = m:GetPivot()
	local cf, size = m:GetBoundingBox()
	local c = pivot:PointToObjectSpace(cf.Position)
	local x0, x1 = c.X - size.X / 2 - USE_MARGIN, c.X + size.X / 2 + USE_MARGIN
	local z0, z1 = c.Z - size.Z / 2 - USE_MARGIN, c.Z + size.Z / 2 + USE_REAR
	local z = Instance.new("Part")
	z.Name = "UseZone"
	z.Size = Vector3.new(x1 - x0, USE_HEIGHT, z1 - z0)
	z.CFrame = pivot * CFrame.new((x0 + x1) / 2, USE_HEIGHT / 2, (z0 + z1) / 2)
	z.Anchored = true
	z.Transparency = 1
	z.CanCollide = false
	z.CanTouch = true
	z.CanQuery = false
	z.CastShadow = false
	z.Parent = m
	return z
end

local function prepare(import, name)
	local spec = VARIANTS[name]
	-- l'Importateur range les maillages dans un sous-modèle du même nom : on les remonte
	local m = Instance.new("Model")
	m.Name = name
	local pivot = import:GetPivot()
	for _, d in import:GetDescendants() do
		if d:IsA("MeshPart") then
			d.Parent = m
		end
	end
	m.WorldPivot = pivot
	m:PivotTo(CFrame.identity)
	m.WorldPivot = CFrame.identity
	for _, p in m:GetChildren() do
		local look = spec.parts[p.Name]
		assert(look, name .. " : pièce inattendue " .. p.Name)
		p.Anchored = true
		p.Color = look[1]
		p.Material = look.mat or (look.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		p.Transparency = look.transparency or 0
		p.Reflectance = look.reflect or 0
		p.CollisionFidelity = Enum.CollisionFidelity.Box
		p.CanCollide = p.Name == "Belt"
		p.CanTouch = false
		p.CanQuery = p.Name == "Belt"
		p.CastShadow = not look.neon and p.Name ~= "BeltArrows"
	end
	local belt = m.Belt
	local image = spec.beltTexture
	if spec.flatBelt then
		-- la bande devient une Part plate qui porte l'image en Texture (le code la fait défiler)
		-- l'Importateur 3D pose l'image dans un SurfaceAppearance (ColorMap), sinon dans TextureID
		local sa = belt:FindFirstChildOfClass("SurfaceAppearance")
		image = spec.beltImage or ((sa and sa.ColorMap ~= "") and sa.ColorMap or belt.TextureID)
		assert(image ~= "", name .. " : la bande importée n'a pas d'image")
		local flat = Instance.new("Part")
		flat.Name = "Belt"
		flat.Size = Vector3.new(belt.Size.X, 0.05, belt.Size.Z)
		flat.CFrame = CFrame.new(belt.Position.X, belt.Position.Y + belt.Size.Y / 2 - 0.025, belt.Position.Z)
		flat.Anchored = true
		flat.Color = spec.parts.Belt[1]
		flat.Material = Enum.Material.SmoothPlastic
		flat.TopSurface = Enum.SurfaceType.Smooth
		flat.BottomSurface = Enum.SurfaceType.Smooth
		flat.CanCollide = true
		flat.CanTouch = false
		flat.CanQuery = true
		flat.Parent = m
		belt:Destroy()
		belt = flat
	end
	local beltTop = belt.Position.Y + belt.Size.Y / 2
	local tex = Instance.new("Texture")
	tex.Name = "BeltTexture"
	tex.Face = Enum.NormalId.Top
	tex.Texture = image
	if spec.flatBelt then
		-- l'image (2:1) revient 4 fois dans la longueur de la bande, sans étirement (Clément, 2026-11-08)
		tex.StudsPerTileU = spec.beltTile and spec.beltTile.X or belt.Size.X
		tex.StudsPerTileV = spec.beltTile and spec.beltTile.Y or belt.Size.Z / 4
	else
		tex.StudsPerTileU = 1
		tex.StudsPerTileV = 1
		tex.Color3 = rgb(70, 70, 80)
		tex.Transparency = 0.3
	end
	tex.Parent = belt
	-- coureur au milieu de la bande, un peu vers l'avant, tourné vers la console
	attachment("UsePoint", belt, Vector3.new(0, beltTop, belt.Position.Z - 0.5))
	local front = m:FindFirstChild("Frame") or belt
	attachment("UpgradePoint", front, spec.upgrade, Vector3.new(0, 0, 1)) -- tourné vers la boutique (Clément, 2026-11-08)
	for _, c in spec.colliders do
		box(m, c[1], c[2], c[3])
	end
	useZone(m)
	import:Destroy()
	return m
end

local plots = RS.Assets.Plots
local report = {}
for name in VARIANTS do
	local import = workspace:FindFirstChild(name)
	if import then
		local old = plots:FindFirstChild(name)
		if old then old:Destroy() end
		local m = prepare(import, name)
		m.Parent = plots
		local b = m.Belt
		local up = b.UsePoint.WorldPosition
		table.insert(report, string.format("%s rangé : bande y %.3f, z %.2f..%.2f, UsePoint (%.2f, %.3f, %.2f), image %s",
			name, b.Position.Y + b.Size.Y / 2, b.Position.Z - b.Size.Z / 2, b.Position.Z + b.Size.Z / 2, up.X, up.Y, up.Z, b.BeltTexture.Texture))
	else
		local kept = plots:FindFirstChild(name)
		if kept and not kept:FindFirstChild("UseZone") then useZone(kept) end
		table.insert(report, name .. " : pas d'import dans Workspace, " .. (kept and "version rangée gardée" or "ABSENT"))
	end
end
table.sort(report)
return table.concat(report, "\n")
