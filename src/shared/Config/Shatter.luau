--!strict
-- Réglages de la casse de vitrine (DEV-016 ; Partie 1, sections 5.2, 5.3 et 5.4 ; liaison L-028).
-- Lus par ShatterController (fissures, casse, éclats, effets, sons), WindowController (barre
-- BB_WindowHP) et WindowService (diffusion de chaque coup). C'est le fichier à ouvrir pendant la
-- bêta : tout se règle ici, sans toucher au code.
--
-- Origine de chaque valeur, notée en commentaire :
--   doc        valeur de la Partie 1, reprise de Balance (une seule source : la changer là-bas) ;
--   prototype  valeur de départ du prototype de casse de Clément (L-028), à régler à deux ;
--   V0         V0 proposé, absent du doc, à régler à l'œil.
-- Unités : studs, secondes, studs/s, degrés ; fractions entre 0 et 1 (0.25 = 25 %).

local Balance = require(script.Parent.Balance)
local DeepFreeze = require(script.Parent.DeepFreeze)

local Shatter = {
	-- Assets de Clément, cherchés par leur nom depuis ReplicatedStorage (jamais d'ID d'asset ici).
	Assets = {
		FxFolder = { "Assets", "FX" }, -- objets Decal dont on lit la Texture (MOD-011)
		CrackDecals = { "WIN_Crack_75", "WIN_Crack_50", "WIN_Crack_25" }, -- étoile des niveaux 1, 2 et 3
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
	-- frappe (6 joueurs au plus par serveur).
	HitBroadcastRadius = 100, -- V0

	-- Fissures : une étoile au point de chaque coup (5.3, L-028).
	Cracks = {
		Thresholds = Balance.Window.CrackThresholds, -- doc : fissures à 75, 50 et 25 % des PV
		ReuseDistance = 1.5, -- prototype : un coup plus près d'une étoile la réutilise
		MaxStars = 6, -- prototype : au-delà, l'étoile touchée il y a le plus longtemps disparaît
		-- V0 : diamètre d'une étoile (studs) sur une vitre M (7 de haut) aux niveaux 0, 1, 2 et 3,
		-- dans cet ordre. Niveau 0 = PV au-dessus de 75 % (image WIN_Crack_75, plus petite). Vitres
		-- S et L : proportionnel à leur hauteur.
		Sizes = { 1.4, 2.4, 3.4, 4.6 },
		ReferenceHeight = 7, -- hauteur d'une vitre M (doc 10.1)
		Level0Transparency = 0.35, -- V0 : étoile du niveau 0 plus discrète
		-- V0 : PV qui remontent (régénération) : une étoile rapetisse d'un niveau quand les PV
		-- repassent 5 % au-dessus de son seuil, et toutes s'effacent quand la vitre est à nouveau
		-- pleine.
		HealHysteresis = 0.05,
		PopTime = 0.12, -- V0 : apparition et croissance d'une étoile
		ClearFade = 0.4, -- V0 : effacement quand la vitre est revenue à ses PV max
		SurfaceOffset = 0.03, -- V0 : décalage des étoiles devant chaque face du verre
		PixelsPerStud = 50, -- V0 : finesse de l'image sur la vitre
		MaxDistance = 150, -- V0 : distance d'affichage des étoiles
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
		Sparkles = 4, -- V0
		SparklesLowEnd = 2, -- V0
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
