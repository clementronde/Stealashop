--!strict
-- Intrus frappé dans une boutique, projeté en ragdoll à travers une vitre (a315, L-291 ; règle de Cantin du 23/11).
-- Lu par GlassThrowService (serveur : vitre, vol, ragdoll, trou, réparation), Shared/ShopGlass (choix de la vitre)
-- et GlassThrowController (client : trou dans la vitre, givre, éclats, effets, sons, secousse). Sous
-- Features.ShopGlassThrow (PROD) et Features.ShopGlassThrowDev (jeu DEV seulement).
--
-- Valeurs V0 proposées (a315, 2026-11-23), absentes du doc, sauf le givre (proposition de Clément, L-291).
-- Unités : studs, secondes, degrés.

local DeepFreeze = require(script.Parent.DeepFreeze)

local GlassThrow = {
	-- Vol ----------------------------------------------------------------------------------------------------------
	-- Vitesse horizontale du corps projeté (LinearVelocity en plan, poussée du serveur). 70 : environ 4 fois la
	-- marche (16), la vitre est passée en moins d'un tiers de seconde depuis le milieu de la boutique.
	Speed = 70, -- V0 proposé (2026-11-23)
	-- Vitesse verticale de départ : calculée pour que le corps passe la vitre à la hauteur du trou, bornée ici.
	MinLift = 4, -- V0 proposé (2026-11-23)
	MaxLift = 30, -- V0 proposé (2026-11-23)
	-- La poussée s'arrête quand le corps est sorti de Bounds d'au moins ClearMargin, au plus tard après MaxPushTime
	-- (bloqué par un présentoir : le trou s'ouvre quand même, et la sortie devant la porte prend le relais).
	ClearMargin = 3, -- V0 proposé (2026-11-23)
	MaxPushTime = 0.9, -- V0 proposé (2026-11-23)
	-- Temps en ragdoll, du coup au relevé (animation Knockback, marqueur Land).
	RagdollTime = 1.4, -- V0 proposé (2026-11-23)
	-- Ragdoll : articulations libres (BallSocketConstraint) à la place des Motor6D, sauf Root et Neck (le Neck
	-- coupé tue le Humanoid). false = le corps vole raide, sans ragdoll.
	Ragdoll = true, -- V0 proposé (2026-11-23)
	RagdollUpperAngle = 50, -- V0 proposé (2026-11-23), angle maximal des épaules, hanches, genoux…
	RagdollTwist = 35, -- V0 proposé (2026-11-23), torsion maximale de chaque côté

	-- Choix de la vitre (Shared/ShopGlass, repère de la boutique) -------------------------------------------------
	-- Marge de côté pour « la vitre dans le sens du coup » : le rayon du coup peut passer jusqu'à RayTolerance au-delà
	-- du bord d'une vitre (le corps est large).
	RayTolerance = 1, -- V0 proposé (2026-11-23)
	-- Vitre retenue seulement si, de l'autre côté, le bord de Bounds est à MaxExitDistance au plus : la vitre du fond
	-- du niveau 1 (Back_L1/Pane_B, z −16,4) donne sur l'intérieur de Bounds, on n'y passe pas.
	MaxExitDistance = 12, -- V0 proposé (2026-11-23)

	-- Trou (FragmentAsync sur une copie locale de la vitre) -------------------------------------------------------
	-- Demi-largeur et demi-hauteur de l'ellipse du trou : un corps R15 (environ 2 × 5 studs) avec de la marge.
	HoleHalfWidth = 1.6, -- V0 proposé (2026-11-23)
	HoleHalfHeight = 2.6, -- V0 proposé (2026-11-23)
	-- Centre du trou : hauteur du HumanoidRootPart au moment du coup, plus HoleLift ; au moins EdgeMargin du bord.
	HoleLift = 0.3, -- V0 proposé (2026-11-23)
	EdgeMargin = 0.4, -- V0 proposé (2026-11-23)
	-- Points de FragmentAsync (essai de Clément : une vingtaine dans l'ellipse, un anneau, quelques points loin).
	InnerPoints = 20, -- V0 proposé (2026-11-23), éclats
	RingPoints = 14, -- V0 proposé (2026-11-23), bord net du trou, juste hors de l'ellipse
	RingScaleMin = 1.15, -- V0 proposé (2026-11-23)
	RingScaleMax = 1.35, -- V0 proposé (2026-11-23)
	FarPoints = 6, -- V0 proposé (2026-11-23), loin dehors : le reste de la vitre reste d'un seul morceau
	-- Le trou reste ouvert HoleDuration, puis se répare (éclats retirés, vitre d'origine rendue, FX_ShopGlass_Reform).
	-- Une projection par un trou déjà ouvert le garde ouvert HoleDuration de plus.
	HoleDuration = 6, -- V0 proposé (2026-11-23)
	-- Givre du reste de la vitre le temps du trou (proposition de Clément, L-291).
	FrostColor = Color3.fromHex("#D6EEFA"),
	FrostMaterial = Enum.Material.SmoothPlastic,
	FrostTransparency = 0.55,
	-- Éclats (les morceaux de l'ellipse) : partent dans le sens du vol, retombent dehors, s'effacent.
	ShardSpeedMin = 18, -- V0 proposé (2026-11-23)
	ShardSpeedMax = 32, -- V0 proposé (2026-11-23)
	ShardUpMin = 2, -- V0 proposé (2026-11-23)
	ShardUpMax = 9, -- V0 proposé (2026-11-23)
	ShardSpin = 12, -- V0 proposé (2026-11-23), rad/s au plus sur chaque axe
	ShardLife = 2.4, -- V0 proposé (2026-11-23)
	ShardFade = 0.5, -- V0 proposé (2026-11-23), à la fin de ShardLife

	-- Secousse de caméra (victime et frappeur), coupée par « réduire les mouvements » et VISUAL EFFECTS sur OFF ---
	ShakeVictimDuration = 0.35, -- V0 proposé (2026-11-23)
	ShakeVictimAmplitude = 0.45, -- V0 proposé (2026-11-23), studs
	ShakeVictimAngle = 1.6, -- V0 proposé (2026-11-23), degrés
	ShakeHitterDuration = 0.2, -- V0 proposé (2026-11-23)
	ShakeHitterAmplitude = 0.22, -- V0 proposé (2026-11-23)
	ShakeHitterAngle = 0.8, -- V0 proposé (2026-11-23)
	ShakeFrequency = 22, -- V0 proposé (2026-11-23), oscillations par seconde

	-- Pas de délai entre deux projections d'un même joueur : un joueur en vol n'est pas reprojeté, et
	-- Bat.HitImmunity (3 s) empêche déjà un second coup juste après.

	-- Noms -----------------------------------------------------------------------------------------------------------
	-- Murs invisibles traversés le temps du vol (plot_shop_builder : PlotBarrier ; Stage_j/Barriers des niveaux).
	BarrierContainers = { "PlotBarrier", "Barriers" },
	-- Groupes de collision : le corps projeté (GroupThrown) ne heurte pas les murs de sa boutique pendant le vol
	-- (GroupBarrier) ; ces deux groupes reprennent les règles de « Default » avec tous les autres groupes.
	GroupThrown = "GlassThrown",
	GroupBarrier = "GlassThrowBarrier",
	-- Effets de Clément (ReplicatedStorage/Assets/FX) et sons (ReplicatedStorage/Assets/Sounds/Throw).
	BurstFx = "FX_ShopGlass_Burst",
	ReformFx = "FX_ShopGlass_Reform",
	TrailFx = "FX_ThrownTrail",
	SoundsFolder = { "Assets", "Sounds", "Throw" },
	SoundHit = "Throw_Hit",
	SoundWhoosh = "Throw_Whoosh",
	SoundGlassBurst = "Throw_GlassBurst",
	SoundGlassDebris = "Throw_GlassDebris",
	SoundGlassReform = "Throw_GlassReform",
	-- Relevé de la victime (contrat 2.4 ; marqueur Land, son Knockback_Land de MarkerSounds).
	LandAnimation = "Knockback",
}

export type GlassThrow = typeof(GlassThrow)

return DeepFreeze(GlassThrow)
