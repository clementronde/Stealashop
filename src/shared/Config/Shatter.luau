--!strict
-- Réglages de la casse de vitrine (DEV-016 ; Partie 1, sections 5.2, 5.3 et 5.4 ; liaison L-028
-- et L-081). Lus par ShatterController (creux des coups, casse, éclats, effets, sons),
-- WindowController (barre BB_WindowHP) et WindowService (diffusion de chaque coup). C'est le
-- fichier à ouvrir pendant la bêta : tout se règle ici, sans toucher au code.
--
-- Origine de chaque valeur, notée en commentaire :
--   doc        valeur de la Partie 1, reprise de Balance (une seule source : la changer là-bas) ;
--   prototype  valeur de départ du prototype de casse de Clément (L-028), à régler à deux ;
--   creux      valeur du prototype « vitre qui se creuse » validé par Clément en Play
--              (L-081, tools/clement/vitre_creuse_prototype.luau) ;
--   V0         V0 proposé, absent du doc, à régler à l'œil.
-- Unités : studs, secondes, studs/s, degrés ; fractions entre 0 et 1 (0.25 = 25 %).

local Balance = require(script.Parent.Balance)
local DeepFreeze = require(script.Parent.DeepFreeze)

local Shatter = {
	-- Assets de Clément, cherchés par leur nom depuis ReplicatedStorage (jamais d'ID d'asset ici).
	Assets = {
		FxFolder = { "Assets", "FX" }, -- objets Decal dont on lit la Texture (MOD-011)
		SparkleDecal = "FX_GlassSparkle", -- paillettes
		DustDecal = "FX_Dust", -- V0 : nom proposé ; tant qu'il manque, DustTexture ci-dessous
		WindowsFolder = { "Assets", "Windows" }, -- vitres fracturées (MOD-010)
		FracturedVariants = { "WIN_M_Fractured", "WIN_M_Fractured_Left", "WIN_M_Fractured_Right" },
		-- V0 : écran « SMASHED! » proposé à Clément (ScreenGui de StarterGui avec un TextLabel Label) ;
		-- tant qu'il n'existe pas, le code affiche son propre texte gris.
		BrokenScreen = "UI_Shatter",
		BrokenLabel = "Label",
	},
	-- V0 : texture de poussière livrée avec Roblox (fichier du client, pas un asset publié), en
	-- attendant un Decal FX_Dust de Clément.
	DustTexture = "rbxasset://textures/particles/smoke_main.dds",
	-- V0 : couleur des petits cubes de verre quand la vitre n'en donne pas (verre de Clément, L-028).
	GlassColor = Color3.fromRGB(191, 230, 255),

	-- Sons (DEV-051), cherchés par leur nom dans ReplicatedStorage/Assets/Sounds, comme ceux des
	-- marqueurs (Shared/Anim/MarkerSounds, sous-dossiers permis). Noms V0 proposés, absents du
	-- doc ; un son absent ne joue rien.
	Sounds = {
		Hit = "Glass_Hit", -- chaque coup ; sa hauteur monte quand les PV baissent
		BreakThud = "Glass_BreakThud", -- casse, couche 1 : impact sourd
		BreakShatter = "Glass_BreakShatter", -- casse, couche 2 : éclatement
		BreakDebris = "Glass_BreakDebris", -- casse, couche 3 : cliquetis des morceaux qui retombent
	},

	-- WindowService : WindowHit part au frappeur et aux joueurs à moins de ce rayon du point de
	-- frappe (6 joueurs au plus par serveur), pour chaque coup validé sur une vitrine, une porte de
	-- boutique ou le camion (creux, chiffre de dégâts, son du coup ; DEV-016, DEV-053, L-081).
	HitBroadcastRadius = 100, -- V0

	-- La vitre se creuse à chaque coup (L-081, remplace les étoiles de fissure) : des éclats sont
	-- arrachés de la face frappée (GeometryService:FragmentAsync sur une copie locale de la vitre),
	-- le creux s'élargit et s'enfonce avec les PV perdus, sans jamais percer la vitre.
	Carve = {
		-- Rayon du creux (studs) : R0 + RGrow × (PV perdus)^0,8, au moins PerHit de plus qu'au coup
		-- d'avant, RMax au plus.
		R0 = 0.6, -- creux
		RGrow = 1.6, -- creux
		RadiusCurve = 0.8, -- creux
		PerHit = 0.1, -- creux
		RMax = 2.6, -- creux
		-- Profondeur, en part de l'épaisseur : DepthMin + DepthGrow × (PV perdus)^0,9, au moins
		-- DepthPerHit de plus qu'au coup d'avant, DepthMax au plus (le fond reste dans le verre).
		DepthMin = 0.22, -- creux
		DepthGrow = 0.68, -- creux
		DepthCurve = 0.9, -- creux
		DepthPerHit = 0.04, -- creux
		DepthMax = 0.88, -- creux
		-- creux : garde-fou, aucun éclat ne descend plus bas que 93 % de l'épaisseur (le hasard de
		-- la cuvette peut dépasser DepthMax de 10 %).
		DepthCap = 0.93,
		Bowl = 0.65, -- creux : cuvette, le bord est à 35 % de la profondeur du centre
		-- Points de découpe : un par éclat arraché (SitesPerArea par stud² du creux, entre MinSites
		-- et MaxSites), plus un anneau de RingMin à RingMax points qui borde le creux.
		SitesPerArea = 5, -- creux
		MinSites = 8, -- creux
		MaxSites = 26, -- creux
		RingMin = 10, -- creux
		RingMax = 24, -- creux
		EdgeMargin = 0.3, -- creux : le centre du creux reste à 0,3 stud du bord de la vitre
		-- Éclats arrachés : OutShare d'entre eux partent vers celui qui frappe ; les autres tombent
		-- au pied de la vitre (V0 : dans le prototype, ils partaient vers l'intérieur, mais les éclats
		-- du jeu ne traversent pas le verre qui n'est pas percé).
		OutShare = 0.85, -- creux
		SpeedMin = 6, -- creux : studs/s, vers celui qui frappe
		SpeedMax = 13, -- creux
		UpMin = 3, -- creux : petit saut vers le haut
		UpMax = 7, -- creux
		SideMin = 1, -- creux : écartement depuis le centre du creux
		SideMax = 4, -- creux
		SpinMin = 8, -- creux : rotation, radians par seconde
		SpinMax = 22, -- creux
		SoftFactor = 0.25, -- creux : vitesse des éclats qui tombent (et des morceaux détachés du cadre)
		Life = 1.4, -- creux : un éclat vit 1,4 s…
		Fade = 0.5, -- creux : … puis s'efface en 0,5 s
		MaxDebris = 150, -- creux : éclats au sol ou en vol au plus ; au-delà, les plus anciens partent
		MaxQueued = 4, -- V0 : coups en attente du calcul en cours, par vitre ; au-delà, fusionnés
		-- creux : celui qui frappe creuse au marqueur Impact ; l'écho WindowHit de ce coup, arrivé
		-- moins de EchoWindow secondes après, est ignoré.
		EchoWindow = 1.5,
		-- creux : la vitre redevient pleine quand ses PV sont au maximum et qu'on ne l'a plus frappée
		-- depuis FullHealDelay ; HealFade = fondu du verre creusé vers la vitre intacte (V0).
		FullHealDelay = 2,
		HealFade = 0.4, -- V0
		-- Version mobile (V0) : appareil faible (LowEnd plus bas), ou appareil tactile sans clavier.
		LightOnTouch = true, -- V0
		Light = {
			MinSites = 5, -- V0
			MaxSites = 12, -- V0
			RingMin = 8, -- V0
			RingMax = 12, -- V0
			MaxDebris = 40, -- V0
		},
	},

	-- Casse (5.4).
	Break = {
		FreezeFrame = Balance.Shatter.FreezeFrame, -- doc : arrêt sur image de 0,06 s
		FlashDuration = Balance.Shatter.FlashDuration, -- doc : flash blanc de 0,08 s
		ShakeDuration = Balance.Shatter.CameraShakeDuration, -- doc : tremblement de 0,25 s
		Text = "SMASHED!", -- doc : « CASSÉ ! », en anglais (L-036)
		PitchVariation = Balance.Shatter.SoundPitchVariation, -- doc : ± 10 % sur chaque couche
		-- V0 : le joueur qui a frappé cette vitre il y a moins de 3 s participe : flash, tremblement,
		-- arrêt de son animation et « SMASHED! » en entier. Les autres : flash et tremblement de plus
		-- en plus faibles avec la distance, nuls à EffectRadius ; pas de texte.
		ParticipantWindow = 3,
		EffectRadius = 80, -- V0
		SimulationRadius = 250, -- V0 : plus loin de la caméra, pas d'éclats (seulement les sons)
		FlashBrightness = 0.45, -- V0 : ColorCorrection de la caméra au début du flash
		FlashSaturation = -0.25, -- V0
		LightBrightness = 8, -- V0 : éclair au point d'impact, vu de tous
		LightRange = 18, -- V0
		ShakeAmplitude = 0.35, -- V0 : studs
		ShakeAngle = 1.2, -- V0 : degrés
		TextPopTime = 0.18, -- V0 : « SMASHED! » apparaît en grossissant…
		TextHold = 0.7, -- V0 : … reste…
		TextHideTime = 0.15, -- V0 : … puis rétrécit et disparaît
		Sparkles = 30, -- V0 : paillettes
		SparklesLowEnd = 10, -- V0
		Dust = 10, -- V0 : bouffées de poussière
		DustLowEnd = 4, -- V0
		Cubes = 18, -- V0 : petits cubes de verre
		CubesLowEnd = 6, -- V0
		-- V0 : cliquetis quand ce quart des éclats a touché le sol (pas le premier : ceux du bas
		-- tombent tout de suite), au plus tard DebrisSoundFallback après la fin de l'arrêt sur image.
		DebrisLandedShare = 0.25,
		DebrisSoundFallback = 0.35, -- V0
	},

	-- Éclats de la vitre fracturée (5.4).
	Shards = {
		Gravity = 196.2, -- prototype (= Workspace.Gravity par défaut)
		Speed = 26, -- prototype : vitesse au point d'impact, en s'écartant de lui dans le plan de la vitre
		InwardPush = 16, -- prototype : poussée vers l'intérieur du magasin
		Bounce = 0.3, -- prototype : part de la vitesse gardée au rebond, perpendiculaire au sol
		FalloffDistance = 6, -- V0 : à cette distance de l'impact, la vitesse d'écartement est divisée par 2
		Jitter = 0.25, -- V0 : ± 25 % sur chaque vitesse
		UpBoost = 3, -- V0 : petit saut vers le haut, pour une belle courbe
		SpinMin = 230, -- V0 : rotation, degrés par seconde
		SpinMax = 800, -- V0
		Friction = 0.55, -- V0 : part de la vitesse gardée le long du sol à chaque rebond
		SettleSpeed = 4, -- V0 : sous cette vitesse après un rebond, l'éclat se couche à plat
		SettleTime = 0.15, -- V0 : durée pour se coucher
		FlatMinNormalY = 0.6, -- V0 : sol assez plat pour s'y coucher (pente de 53° au plus)
		FadeDelay = Balance.Shatter.ShardFadeDelay, -- doc : s'effacent après 1,5 s…
		FadeDuration = Balance.Shatter.ShardFadeDuration, -- doc : … en 1,2 s
		FallbackTransparency = 0.5, -- V0 : pour des éclats livrés invisibles (greybox : Transparency 1)
		SizeTolerance = 0.3, -- V0 : écart de taille admis entre une variante de Clément et la vitre
		AllowMirrored = true, -- V0 : une variante peut servir retournée (impact de l'autre côté)
	},

	-- Petits cubes de verre (mini-éclats des coups et de la casse).
	Cubes = {
		SizeMin = 0.12, -- V0 : côté d'un cube
		SizeMax = 0.3, -- V0
		Transparency = 0.35, -- V0
		Bounce = 0.3, -- V0 (comme les éclats)
		FadeTime = 0.25, -- V0 : effacement à la fin de leur vie
		BreakLifetime = 1.6, -- V0 : durée de vie des cubes de la casse
	},

	-- Version légère (5.4) : 10 éclats sur appareil faible ou au-delà de 2 casses en même temps.
	LowEnd = {
		Shards = Balance.Shatter.LowEndShards, -- doc : 10 éclats
		MaxFullAtOnce = Balance.Shatter.MaxFullShattersAtOnce, -- doc : version légère au-delà de 2 casses en cours
		Fps = 40, -- V0 : appareil faible = moins de 40 images par seconde…
		QualityLevel = 3, -- V0 : … ou qualité graphique réglée à la main à 3 ou moins
	},

	-- Pendant les coups (5.2 et 5.4).
	Hit = {
		Cubes = 5, -- V0 : mini-éclats au point d'impact
		CubesLowEnd = 2, -- V0
		Sparkles = 24, -- creux (4 en V0 avant L-081)
		SparklesLowEnd = 8, -- V0
		Puff = 5, -- creux : petit nuage de verre pilé
		PuffLowEnd = 2, -- V0
		FlashBrightness = 4, -- creux : éclair au point de frappe
		FlashRange = 10, -- creux
		FlashTime = 0.18, -- creux
		FlashColor = Color3.fromRGB(220, 240, 255), -- creux
		CubeSpeed = 11, -- V0
		CubeLifetime = 0.6, -- V0
		ShakeDuration = 0.1, -- V0 : léger tremblement, pour celui qui frappe seulement
		ShakeAmplitude = 0.08, -- V0 : studs
		ShakeAngle = 0.35, -- V0 : degrés
		PitchMin = 0.9, -- V0 : hauteur du son de verre à PV pleins…
		PitchMax = 1.35, -- V0 : … et à 0 PV
		PitchJitter = 0.03, -- V0 : ± 3 % à chaque coup
		-- V0 : le retour local part au marqueur Impact de l'animation du coup, au plus tard après ce
		-- délai (animation absente ou interrompue par le coup suivant).
		ImpactMaxWait = 0.3,
		FxRadius = 100, -- V0 : coups des autres joueurs : mini-éclats et son seulement plus près que ça
	},

	-- Tremblements de caméra.
	ShakeFrequency = 18, -- V0 : oscillations par seconde

	-- Particules créées par le code (texture de Clément : FX_GlassSparkle).
	Particles = {
		Sparkle = {
			Size = 0.35, -- V0 : studs au départ, jusqu'à 0
			LifetimeMin = 0.35, -- V0
			LifetimeMax = 0.8, -- V0
			SpeedMin = 6, -- V0
			SpeedMax = 16, -- V0
			Spread = 70, -- V0 : degrés autour de la direction d'envol
			GravityScale = 0.3, -- V0 : part de la gravité des éclats
			Color = Color3.fromRGB(235, 248, 255), -- V0
			LightEmission = 1, -- V0
		},
		Dust = {
			SizeMin = 1, -- V0 : studs au départ…
			SizeMax = 3, -- V0 : … et à la fin
			LifetimeMin = 0.8, -- V0
			LifetimeMax = 1.4, -- V0
			SpeedMin = 2, -- V0
			SpeedMax = 5, -- V0
			Spread = 80, -- V0
			Color = Color3.fromRGB(200, 200, 200), -- V0
			Transparency = 0.55, -- V0
			Drag = 3, -- V0
		},
		-- Nuage de chaque coup (texture DustTexture, ou FX_Dust s'il est livré).
		Puff = {
			SizeMin = 1, -- creux : studs au départ…
			SizeMax = 3.2, -- creux : … et à la fin
			LifetimeMin = 0.3, -- creux
			LifetimeMax = 0.5, -- creux
			SpeedMin = 2, -- creux
			SpeedMax = 6, -- creux
			Spread = 50, -- creux
			Color = Color3.fromRGB(235, 248, 255), -- creux
			Transparency = 0.45, -- creux
			LightEmission = 0.4, -- creux
		},
	},

	-- Barre de PV BB_WindowHP (WindowController, contrat 2.2) : taille et décalage du modèle de Clément.
	HPBar = {
		ShowDistance = 20, -- V0 : visible à moins de 20 studs de la vitre, ou dès qu'elle est entamée
		UpdateInterval = 0.2, -- V0 : contrôle de la distance
		TweenTime = 0.12, -- V0 : glissement de Fill
	},
}

export type Shatter = typeof(Shatter)

return DeepFreeze(Shatter)
