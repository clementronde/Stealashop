--!strict
-- Animation idle des objets exposés (liaison L-045 : proposition de Clément, validée par Ironix le
-- 2026-11-07 ; pièces Wave_ : L-055). Lu par ItemIdleController (client). Le contrat (attribut
-- Idle, pièces Spin_<Nom> et Wave_<Nom>) est dans Contract/Attributes et Contract/Models.
--
-- Toutes les valeurs sont des V0 proposés, absents du doc, à faire valider par Clément.
-- Unités : tours par seconde, studs, secondes, degrés.

local DeepFreeze = require(script.Parent.DeepFreeze)

local ItemIdle = {
	-- Idle = "Spin" ou "SpinBob" : le modèle tourne sur l'axe Y de son pivot.
	SpinTurnsPerSecond = 0.2, -- V0 : un tour en 5 s (« rotation lente »)
	-- Pièces Spin_<Nom> : elles tournent sans fin autour de l'axe Y de leur pivot.
	PieceTurnsPerSecond = 0.5, -- V0 : un tour en 2 s (anneau d'hologramme, ventilateurs)
	-- Pièces Wave_<Nom> : va-et-vient autour de l'axe Y de leur pivot (la patte du Chat
	-- porte-bonheur doré), de part et d'autre de la pose de départ, en sinus.
	WaveAmplitude = 25, -- V0 : degrés de chaque côté de la pose de départ
	WavePeriod = 1.2, -- V0 : secondes pour un aller-retour complet
	-- Idle = "Bob" ou "SpinBob" : le modèle monte puis redescend, sans jamais passer sous sa
	-- position de repos (il ne s'enfonce pas dans le présentoir).
	BobHeight = 0.25, -- V0 : studs au plus haut
	BobPeriod = 2.5, -- V0 : secondes pour une montée et une descente
	-- Plus loin de la caméra, l'objet reprend sa position de repos et n'est plus animé (9.7, pour le
	-- mobile), comme les halos de DisplayController (120 studs) et les auras (CosmeticController, 60).
	MaxDistance = 80, -- V0 : studs
	DistanceCheckInterval = 0.25, -- V0 : secondes entre deux tris par distance (et contrôles « à l'écran »)
	-- Vague 39 (optimisation téléphone, audit perf-telephone.md, correction 1) : de près, rien ne change.
	-- Entre NearDistance et MaxDistance, l'objet n'est replacé que toutes les FarInterval s (le mouvement
	-- reste calculé depuis l'instant : il saccade un peu, il ne ralentit pas). FarInterval = 0 : chaque
	-- image, comme avant.
	NearDistance = 30, -- V0 proposé, absent du doc : studs
	FarInterval = 1 / 15, -- V0 proposé, absent du doc : secondes (15 images par seconde au-delà de 30 studs)
	-- Un objet hors de l'écran (derrière la caméra, sur le côté) n'est pas animé : il garde sa dernière
	-- pose et repart au prochain contrôle où il est en vue. Son rayon (pièces animées) est agrandi de
	-- ScreenMargin studs pour qu'un objet au bord de l'écran reste animé. false : animé hors de l'écran,
	-- comme avant.
	OnScreenOnly = true, -- V0 proposé, absent du doc
	ScreenMargin = 2, -- V0 proposé, absent du doc : studs
}

export type ItemIdle = typeof(ItemIdle)

return DeepFreeze(ItemIdle)
