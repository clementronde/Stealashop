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

-- Prototype de Clément (TruckBrakeAt 0,78 × TruckTime 3 s) : freins, et fin du roulage à vitesse constante.
local DRIVE_TIME = 0.78 * 3

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
	-- Colis qui ne se chevauchent pas au sol (demande d'Ironix du 2026-11-08, a42) : entre deux colis,
	-- au moins BoxGap studs bord à bord, d'après la largeur du modèle BOX_<Tier> de Clément. Sans place
	-- dans le cône de ScatterSpread, le point s'écarte de son côté, puis tout autour, puis plus loin.
	BoxGap = 1, -- V0 : 1 stud entre deux colis (la largeur d'un colis + 1 stud, centre à centre)
	BoxFallbackWidth = 2, -- V0 : largeur d'un colis dont le modèle BOX_<Tier> n'est pas livré (bloc gris de CarryService)
	-- Invite des colis au sol (côté client) : quand plusieurs sont à portée, une seule s'allume, celle du
	-- colis le plus proche, un colis hors de l'axe de la caméra comptant plus loin : distance ×
	-- (1 + GrabCameraWeight × (1 − cos de l'angle)), donc × 1 devant, × 1,5 de côté, × 2 derrière.
	GrabCameraWeight = 0.5, -- V0

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
	RemoveDelay = 4.5, -- V0 : le serveur retire la copie du camion 4,5 s après l'explosion (garder ≥ DebrisLifetime + DebrisFadeTime)
	ExplosionFx = true, -- V0 : explosion native de Roblox (feu et son) en attendant un effet de Clément
	ExplosionRadius = 14, -- V0 : taille de cette explosion (aucune force, aucun dégât)

	-- Sons de Clément (liaison L-071, point 7), des Sound cherchés par leur nom dans
	-- ReplicatedStorage/Assets/Sounds (sous-dossiers permis), joués côté client avec le volume et la
	-- portée de Clément. Absents : muets (une ligne en Studio). Le son de chaque coup reçu, SFX_TruckHit,
	-- est dans Config/HitFeedback.Truck.
	ExplosionSound = "SFX_TruckExplosion", -- à l'explosion, au point BlastPoint
	AlarmSound = "SFX_TruckAlarm", -- V0, choix d'Ironix : l'alarme se déclenche quand le camion est frappé…
	AlarmHold = 4, -- V0 : … et se tait 4 s après le dernier coup, ou à l'explosion (une boucle si Looped)
	-- Arrivée (vague 26, L-097 point 8 ; ui-feel-sons-victoire-camion.md : « SFX_TruckArrive au départ,
	-- SFX_TruckBrake à 78 % du trajet », trajet de 3 s dans le prototype de Clément) : sons 3D sur le camion,
	-- joués à son apparition (attribut SpawnedAt) chez ceux qui le voient arriver. Vague 29 (a97) : ils
	-- suivent le camion qui roule (copie locale de TruckController, voir plus bas).
	ArriveSound = "SFX_TruckArrive", -- klaxon, à l'apparition
	BrakeSound = "SFX_TruckBrake", -- freins à air…
	BrakeDelay = DRIVE_TIME, -- … 0,78 × 3 s après (valeurs du prototype de Clément, TruckBrakeAt × TruckTime) : début du dérapage
	ArriveMaxAge = 1, -- V0 proposé, absent du doc : camion reçu plus de 1 s après son apparition : pas de son d'arrivée

	-- Arrivée en roulant (vague 29, a97 ; L-105 point 2, vidéo docs/claude/references/camion/ENV_Event_Truck_Arrivee.mp4).
	-- Le serveur pose le camion à sa place finale dès l'apparition (PV, coups, colis : rien ne change) ;
	-- chaque client qui le voit arriver joue une copie locale, sans collision : le camion debout roule
	-- vers sa place, cabine devant, freine et dérape, se couche sur le côté (les deux conducteurs sont
	-- éjectés), retombe dans sa pose finale (FX_TruckDust), puis la copie laisse place au vrai camion.
	-- Pendant l'arrivée, le vrai camion (caché chez les clients) ne bloque personne : collisions et contacts
	-- coupés par le serveur, remis à la fin ; un joueur resté dedans en est sorti par le côté le plus proche.
	-- Un joueur qui arrive après voit le camion à sa place finale. ArriveDistance = 0 : plus d'arrivée.
	ArriveDistance = 90, -- prototype de Clément (TruckDistance) : point de départ, en studs derrière la place finale, dans l'axe du camion debout
	ArriveDriveTime = DRIVE_TIME, -- V0 proposé, absent du doc : roule à vitesse constante jusqu'aux freins (BrakeDelay)…
	ArriveSkidTime = 0.7, -- V0 proposé, absent du doc : … puis freine et dérape jusqu'à sa place (vitesse qui tombe à 0) ;
	-- vitesse de roulage = ArriveDistance / (ArriveDriveTime + ArriveSkidTime / 2), soit ~33 studs/s
	ArriveSwerveAngle = math.rad(20), -- V0 proposé, absent du doc : l'arrière chasse de 20° pendant le dérapage, puis revient
	ArriveTipTime = 0.55, -- V0 proposé, absent du doc : il se couche sur le côté (chute qui accélère) ; poussière à l'impact
	ArriveSettleTime = 0.3, -- V0 proposé, absent du doc : petit rebond après l'impact…
	ArriveSettleAngle = math.rad(5), -- V0 proposé, absent du doc : … de 5°
	-- Pose livrée par Clément : "Auto" (couché si ses conducteurs le sont, sinon si Pieces est plus large que
	-- haut ; sinon debout), "Lying" ou "Upright". Debout : le serveur le couche à sa place (ArriveTipSide).
	ArriveDeliveredPose = "Auto", -- V0 proposé, absent du doc
	ArriveTipSide = 1, -- V0 proposé, absent du doc : +1 = le toit part vers +X du pivot du camion, −1 vers −X (camion sans conducteur)
	ArrivePushMargin = 2, -- V0 proposé, absent du doc : joueur resté dans le camion à la fin : posé à 2 studs de son flanc
	-- Conducteurs éjectés (copie locale) : vol plané, chute, puis ils s'effacent (V0). Le vrai camion ne les
	-- montre plus (ils reviennent pour la poursuite à la fin du chrono, comme avant).
	DriverEjectAt = 0.35, -- V0 proposé, absent du doc : part de la chute où ils sont éjectés
	DriverEjectUp = 38, -- V0 proposé, absent du doc : vitesse vers le haut (studs/s)
	DriverEjectOut = 16, -- V0 proposé, absent du doc : vitesse vers l'extérieur du camion (studs/s)
	DriverEjectSpin = 6, -- V0 proposé, absent du doc : rotation en vol (rad/s)
	DriverGravity = 90, -- V0 proposé, absent du doc : chute (studs/s²)
	DriverLinger = 0.5, -- V0 proposé, absent du doc : au sol, puis…
	DriverFadeTime = 0.6, -- V0 proposé, absent du doc : … ils s'effacent

	-- Conducteurs (L-071, point 7) : les modèles avec un Humanoid que Clément range dans ENV_Event_Truck.
	-- Avec une animation Idle dans leur dossier Animations (Contract/Animations.Driver), le serveur la
	-- joue en boucle tant que le camion est là ; sans elle, ils restent immobiles.
	-- Poursuite (demande de Clément du 2026-11-10, liaison L-083 point 3) : à la fin du chrono du camion
	-- (Lifetime s après son apparition, ou plus tôt à l'alerte de la nuit), cassé ou non, les conducteurs
	-- réapparaissent d'un coup au point du camion et poursuivent les joueurs qui portent un colis de ce
	-- camion (GuardService.StartDriverChase : chemin, capture et coup du vigile de jour). Attrapé : le
	-- colis est perdu (il n'a pas de rayon où revenir), le joueur tombe comme avec un vigile.
	DriverChaseMax = 2, -- V0 proposé, absent du doc : un conducteur par porteur, 2 au plus (les 2 modèles de Clément), les porteurs les plus proches du camion d'abord
	-- Vitesse : la WalkSpeed actuelle du porteur poursuivi × ce multiplicateur, relue en continu. Un
	-- multiplicateur plutôt qu'une marge fixe : il rattrape au même rythme à 16 qu'à 70 studs/s (+3
	-- studs/s ferait +19 % à 16 mais +4 % à 70), et chaque conducteur suit son porteur, pas le plus rapide.
	DriverSpeedMultiplier = 1.2, -- V0 proposé, absent du doc : 20 % plus vite que son porteur
	DriverMinSpeed = 20, -- V0 proposé, absent du doc : jamais moins vite (porteur ralenti ou immobilisé)
	DriverSpawnSpacing = 4, -- V0 proposé, absent du doc : écart entre les deux conducteurs à l'apparition (studs), de part et d'autre du pivot du camion

	-- Barre de vie au point HealthBarPoint (côté client) : BB_TruckHP de Clément (L-052), telle qu'il
	-- l'a faite. Ces deux valeurs ne servent qu'au repli, une copie de BB_WindowHP, tant qu'elle manque.
	HealthBarScale = 2, -- V0 : repli, deux fois la taille de la barre d'une vitrine (le camion fait 34 studs)
	HealthBarMaxDistance = 250, -- V0 : repli, visible de loin (la barre d'une vitrine garde la portée de Clément)

	-- Messages lus par le joueur (Notify à tous), en anglais (L-036) ----------------------------------
	Messages = {
		Spawned = "A truck appeared in Zone %d! Break it together!", -- V0 : %d = zone
		Exploded = "The truck exploded: grab the boxes!", -- V0
		Left = "The truck drove away.", -- V0 : pas cassé à temps
		LeftNight = "Night is coming: the truck drove away.", -- V0 : parti à l'alerte de la nuit
		DriversChase = "The truck drivers are after your box! Run to the safe zone!", -- V0 proposé, absent du doc : au porteur poursuivi
		DriverCaught = "Caught by a truck driver! The box is lost.", -- V0 proposé, absent du doc : au porteur attrapé
	},
	GrabActionText = "Grab", -- V0 : invite d'un colis du camion au sol, au-dessus de « Premium Box »
}

export type TruckEvent = typeof(TruckEvent)

return DeepFreeze(TruckEvent)
