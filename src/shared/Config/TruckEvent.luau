--!strict
-- Événement camion (liaison L-049, décision de Clément du 2026-11-07 ; pas encore une tâche du
-- backlog). Un camion apparaît dans le couloir, les joueurs le cassent ensemble (PV partagés), il
-- explose et lâche ses colis, que tout le monde peut ramasser. Lu par TruckEventService (serveur) et
-- TruckController (client) ; interrupteur : Config/Features.TruckEvent.
--
-- Le doc ne fixe encore aucune valeur. Origine de chaque valeur, notée en commentaire :
--   « V0 provisoire, décision d'Ironix du 2026-11-07 » : décidé par Ironix, à reporter au journal du doc ;
--   « V0 »  V0 proposé, absent du doc, à régler en jeu.
-- Unités : secondes, studs, studs/s, radians/s.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Colis du camion, par type (clé de Balance.Heist.BoxTiers). Le temps de prise de chaque type est
-- celui des rayons (Balance.Heist.BoxTiers[Tier].GrabTime).
export type BoxCount = { Tier: string, Count: number }

local TruckEvent = {
	-- Apparition ---------------------------------------------------------------------------------
	SpawnIntervalMin = 8 * 60, -- V0 provisoire, décision d'Ironix du 2026-11-07 : un camion toutes les 8…
	SpawnIntervalMax = 12 * 60, -- V0 provisoire, décision d'Ironix du 2026-11-07 : … à 12 min, tiré au hasard
	SpawnZones = { 1, 2, 3, 4, 5, 6 }, -- V0 provisoire, décision d'Ironix du 2026-11-07 : zone tirée au hasard
	-- Seulement de jour : jamais pendant l'alerte ni la nuit. Un camion dû à ce moment-là attend le jour.
	MinDayLeft = 60, -- V0 : pas d'apparition si l'alerte de la nuit commence dans moins de 60 s
	DawnDelay = 30, -- V0 : pas d'apparition dans les 30 premières secondes du jour (ruée de l'aube)

	-- Vie du camion ------------------------------------------------------------------------------
	MaxHP = 1000, -- V0 provisoire, décision d'Ironix du 2026-11-07 : PV partagés, sans régénération
	Lifetime = 3 * 60, -- V0 provisoire, décision d'Ironix du 2026-11-07 : pas cassé en 3 min, il part sans rien lâcher

	-- Colis --------------------------------------------------------------------------------------
	-- 12 colis, un par BoxSpawn_01 à _12, répartis au hasard sur les points.
	Boxes = {
		{ Tier = "Standard", Count = 6 }, -- V0 provisoire, décision d'Ironix du 2026-11-07
		{ Tier = "Premium", Count = 4 }, -- V0 provisoire, décision d'Ironix du 2026-11-07
		{ Tier = "Luxe", Count = 2 }, -- V0 provisoire, décision d'Ironix du 2026-11-07
	} :: { BoxCount },
	BoxLifetime = 60, -- V0 provisoire, décision d'Ironix du 2026-11-07 : jamais ramassé, il disparaît (compté depuis l'atterrissage)
	ScatterRadius = 15, -- V0 provisoire, décision d'Ironix du 2026-11-07 : retombent dans ~15 studs autour du camion
	ScatterMinRadius = 6, -- V0 : pas plus près que 6 studs du centre du camion
	ScatterSpread = math.rad(50), -- V0 : écart au hasard autour de la direction centre du camion → point de sortie
	FlightTime = 1.1, -- V0 : durée du vol d'un colis
	FlightHeight = 9, -- V0 : hauteur de la cloche du vol, au-dessus de la ligne droite
	FlightSpins = 1.5, -- V0 : tours sur lui-même pendant le vol
	LaunchStagger = 0.04, -- V0 : écart entre deux départs de colis (12 colis : 0,44 s en tout)

	-- Explosion (effet seulement, côté client : rien de ce qui compte n'en dépend) ------------------
	DebrisSpeedMin = 22, -- V0 : vitesse des pièces depuis BlastPoint…
	DebrisSpeedMax = 48, -- V0 : … tirée entre ces deux valeurs
	DebrisUpMin = 14, -- V0 : vitesse vers le haut, en plus…
	DebrisUpMax = 32, -- V0 : … tirée entre ces deux valeurs
	DebrisSpinMax = 7, -- V0 : rotation des pièces au plus (rad/s)
	DebrisGravity = 120, -- V0 : chute des pièces (studs/s²), un peu moins que la gravité du jeu
	DebrisBounce = 0.3, -- V0 : rebond au sol (part de la vitesse verticale gardée)
	DebrisLifetime = 3, -- V0 : les pièces restent 3 s…
	DebrisFadeTime = 1, -- V0 : … puis s'effacent en 1 s
	RemoveDelay = 4.5, -- V0 : le serveur retire la copie du camion 4,5 s après l'explosion
	ExplosionFx = true, -- V0 : explosion native de Roblox (feu et son) en attendant un effet de Clément
	ExplosionRadius = 14, -- V0 : taille de cette explosion (aucune force, aucun dégât)

	-- Barre de vie : copie de BB_WindowHP au point HealthBarPoint (côté client) ------------------------
	HealthBarScale = 2, -- V0 : deux fois la taille de la barre d'une vitrine (le camion fait 34 studs)
	HealthBarMaxDistance = 250, -- V0 : visible de loin (la barre d'une vitrine garde la portée de Clément)

	-- Messages lus par le joueur (Notify à tous), en anglais (L-036) ----------------------------------
	Messages = {
		Spawned = "A truck appeared in Zone %d! Break it together!", -- V0 : %d = zone
		Exploded = "The truck exploded: grab the boxes!", -- V0
		Left = "The truck drove away.", -- V0 : pas cassé à temps
		LeftNight = "Night is coming: the truck drove away.", -- V0 : parti à l'alerte de la nuit
	},
	GrabActionText = "Grab", -- V0 : invite d'un colis du camion au sol, au-dessus de « Premium Box »
}

export type TruckEvent = typeof(TruckEvent)

return DeepFreeze(TruckEvent)
