--!strict
-- Tapis de course animés (liaison L-093 question 3, L-097 point 2) : ce que TreadmillFxController
-- (client, visuel seulement) fait bouger sur chaque PLOT_Treadmill_<Variante> pendant qu'un joueur y
-- court. Valeurs de Clément : docs/claude/notes/boutique-joueur-MOD-015-016.md (sections « Tapis … »,
-- valeurs « en course ») ; celles marquées V0 sont des propositions, absentes du doc.
-- Unités : studs, secondes, radians par seconde.

local DeepFreeze = require(script.Parent.DeepFreeze)

local TreadmillFX = {
	-- Défilement de Belt.BeltTexture.OffsetStudsV pendant la course (note Ice, reprise pour tous :
	-- « 3 studs/s à vide, 9 avec un joueur dessus »).
	BeltSpeed = 9,
	-- Tapis au repos (L-106 point 7, accord de Clément) : la bande défile lentement, à 3 studs/s, sur les
	-- tapis sans coureur à moins de ActiveDistance de la caméra. 0 = bande immobile au repos.
	IdleBeltSpeed = 3,
	-- V0 : seuls les tapis à moins de cette distance de la caméra sont animés (performance).
	ActiveDistance = 150,
	-- V0 : période (s) du contrôle « qui court, sur quel tapis, assez près ? ».
	CheckInterval = 0.5,

	-- Pulsation commune : p = 0,5 + 0,5·sin(ω t) (V0 : forme du « sinus » des notes). Les couleurs qui
	-- « pulsent » partent de la couleur posée par Clément (7CFF2E pour ToxicGoo, FFD6EA pour les flèches
	-- Candy, FF4FA3 pour CandyGlow) et vont vers To de Amount·p.
	Gold = {
		HaloSpeed = 1.1, -- rotation de GoldFX.Halo1 à 4 autour de Y (impairs −, pairs +)
		WingLight = { Min = 1.2, Max = 2.2, Omega = 3 },
		GlowTint = 0.3, -- V0 : GoldGlow va de sa couleur vers le blanc de 0,3·p (« faire pulser »)
		GlowOmega = 3, -- V0
	},
	CashRegister = {
		BillsRate = 9, -- CashFX.DrawerFX.Bills.Rate en course (3 au repos)
		StreamSpeed = 0.9, -- CashFX.PillarFXn.Stream.TextureSpeed en course (0,35 au repos)
		RegisterLight = { Min = 1.3, Max = 1.9, Omega = 3 },
		GlowTint = 0.3, -- V0 : GlowMint vers le blanc de 0,3·p
		GlowOmega = 3, -- V0
	},
	Police = {
		Cycle = 0.9, -- rouge-rouge puis bleu-bleu
		FlashStarts = { 0, 0.2 }, -- débuts des deux flashs dans le cycle
		FlashTime = 0.12,
		BlueOffset = 0.45,
		DimFactor = 0.65, -- SirenRed / SirenBlue assombries à 65 % hors flash
		LightOn = 6, -- PoliceFX.Light_*.Light pendant un flash (0 sinon)
		SweepSpeed = 4.5, -- Sweep_red et Sweep_blue autour de Y, sens opposés
		TrailOffset = Vector3.new(0.9, -0.5, 0.4), -- attaches du RunTrail sur le HumanoidRootPart (±X)
	},
	LaserVault = {
		AlarmRate = 9, -- a = max(0, sin(rate·t))², 9 en course
		AlarmLow = Color3.fromHex("3A0A10"),
		AlarmHigh = Color3.fromHex("FF3B5C"),
		AlarmLight = 3, -- Alarm*.Light = 3a
		FlashAbove = 0.9, -- Emit(1) des Alarm*.Flash quand a > 0,9…
		FlashGap = 0.3, -- … au plus une fois toutes les 0,3 s
		BeamFlicker = { Min = 0.05, Max = 0.13 }, -- transparence des Beam
		LaserBeamsFlicker = { Min = 0, Max = 0.05 }, -- transparence de LaserBeams
		ScanGate = { Center = 3.5, Amplitude = 2.5, Omega = 0.8 }, -- hauteur dans le repère du tapis
		CamScan = { Amplitude = 0.45, Omega = 0.9, Phase = 1.7 }, -- lacet ± A·sin(ω t + phase·i)
	},
	Ice = {
		ArrowsTransparency = { Min = 0, Max = 0.25 },
		CrownLight = { Min = 1.6, Max = 2.6, Omega = 3 },
		FrostRingSpeed = 0.12,
		GlowTint = 0.3, -- V0 : CrystalGlow vers le blanc de 0,3·p
		GlowOmega = 3, -- V0
	},
	Toxic = {
		Goo = { To = Color3.fromHex("EAFFC8"), Amount = 0.18, Omega = 2.2 },
		GooLight = { Min = 1.5, Max = 2.1, Omega = 2.2 },
		Arrows = { To = Color3.fromHex("1F4A12"), Omega = 12 },
		Lantern = { Base = 1.3, Amplitude = 0.4, Omega = 13, Noise = 0.15 }, -- Noise : V0
		TrailOffset = Vector3.new(0.6, -2.7, 0.3),
	},
	Candy = {
		PeppermintSpeed = 2.5, -- autour de l'axe avant-arrière, sens horaire vu de l'avant
		PeppermintCenter = Vector3.new(0, 2.45, -3.1), -- dans le repère du tapis
		Glow = { To = Color3.new(1, 1, 1), Amount = 0.3, Omega = 2.6 },
		SprinkleLight = { Min = 1.2, Max = 1.8, Omega = 2.6 },
		Arrows = { To = Color3.fromHex("FF4FA3"), Omega = 12 },
		PopCount = 30,
		PopGap = { Min = 0.4, Max = 1 },
		TrailOffset = Vector3.new(0.8, -1.5, 0.4),
	},
	Fire = {
		Brazier = { Base = 2, Amplitude = 0.7 }, -- f = 0,5·sin 11t + 0,3·sin 23t + 0,2·sin 5t
		EmberFrom = Color3.fromHex("FF5A17"),
		EmberTo = Color3.fromHex("FFA040"),
		EmberBase = 0.2,
		EmberAmount = 0.15,
	},
}

export type TreadmillFX = typeof(TreadmillFX)

return DeepFreeze(TreadmillFX)
