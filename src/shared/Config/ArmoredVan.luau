--!strict
-- Casse du siècle (GC6, a409, MAJ 6, DEV-133 ; Partie 2 : « toutes les 30 min, un fourgon blindé géant traverse le
-- boulevard. Les 6 joueurs le frappent ensemble ; chacun reçoit un colis selon ses dégâts (Luxe pour le top 3) »).
-- Lu par ArmoredVanService ; interrupteur Config/Features.ArmoredVan. Plus de colis Standard / Premium / Luxe
-- (vague 76) : les récompenses sont des colis de zone (Shared/ZoneBoxOdds, UnboxService.GiveZoneBoxItem), le meilleur
-- rang pour le top 3. Toute valeur sans source est « V0 proposé (Cantin, 23/11) ». Unités : s, studs.

local DeepFreeze = require(script.Parent.DeepFreeze)

export type Rule = { ZoneStep: number, Exclude: { string }?, TopCount: number?, TopWeights: { number }?, TopBoost: number? }

-- Récompense d'un casseur : la première ligne qui convient (rang au plus MaxRank, ou part des dégâts au moins MinShare).
export type RewardTier = {
	MaxRank: number?,
	MinShare: number?,
	Label: string, -- nom du colis dans le message (anglais)
	Rule: Rule,
}

local ArmoredVan = {
	-- Horaire ------------------------------------------------------------------------------------------------------
	Period = 30 * 60, -- Partie 2 : toutes les 30 min
	Offset = 0, -- V0 proposé (Cantin, 23/11) : départs à l'heure pile et à la demie, heure UTC du serveur (os.time)
	WarnBefore = 60, -- V0 proposé (Cantin, 23/11) : annonce 60 s avant le départ
	-- Le fourgon ne part que de jour, avec au moins TravelTime s avant l'alerte de la nuit (sinon il traverserait le
	-- mur) ; un départ dû à un autre moment attend le jour suivant, DawnDelay s après l'aube, puis part (annoncé).
	-- Un départ en attente est remplacé par le suivant à l'heure (jamais deux d'affilée).
	DawnDelay = 20, -- V0 proposé (Cantin, 23/11)
	-- a425 (L-318 Q1) : jamais en même temps que le camion de l'événement (L-049). Pas de camion pendant un fourgon (en
	-- jeu ou en attente), ni TruckGap s après lui, ni dans les TruckLead s avant un départ à l'horaire ; un départ dû
	-- pendant un camion, ou moins de TruckGap s après lui, attend (annoncé) et part dès que la voie est libre.
	TruckGap = 60, -- V0 proposé (Cantin, 24/11) : 1 min de pause entre les deux véhicules
	TruckLead = 4 * 60, -- V0 proposé (Cantin, 24/11) : la vie d'un camion (TruckEvent.Lifetime, 3 min) + TruckGap

	-- Trajet -------------------------------------------------------------------------------------------------------
	-- De l'arche (ZoneGate) de la zone la plus basse à celle de la plus haute, à vitesse constante, au milieu de la
	-- chaussée ; ne s'arrête pas. Pas cassé à l'arrivée, ou à l'alerte de la nuit : il s'échappe, rien n'est donné.
	TravelTime = 150, -- V0 proposé (Cantin, 23/11) : 2 min 30 pour tout le couloir
	-- Le fourgon ne bloque personne (collisions coupées) : un fourgon qui roule ne pousse pas les joueurs.

	-- Vie ----------------------------------------------------------------------------------------------------------
	-- PV partagés = HPPerDamage × la somme des dégâts par coup des joueurs du serveur au départ (ToolService), au
	-- moins MinHP : tout le serveur à 5 coups/s le casse en HPPerDamage / 5 s, s'il frappe sans arrêt.
	HPPerDamage = 300, -- V0 proposé (Cantin, 23/11) : 60 s à 5 coups/s pour tout le serveur
	MinHP = 3000, -- V0 proposé (Cantin, 23/11)

	-- Récompenses à la casse ------------------------------------------------------------------------------------------
	-- Classement par dégâts. Il faut au moins MinShare des PV pour compter. Zone de référence = la meilleure zone du
	-- joueur (comme les paliers de temps de jeu).
	MinShare = 0.02, -- V0 proposé (Cantin, 23/11) : 2 % des PV au moins
	Rewards = {
		-- Top 3 : le meilleur colis (Partie 2 : « Luxe pour le top 3 ») : zone suivante, ses 3 meilleures raretés.
		{ MaxRank = 3, Label = "Top 3 Box", Rule = { ZoneStep = 1, TopCount = 3, TopWeights = { 60, 30, 10 }, Exclude = { "Secret" } } },
		-- 15 % des dégâts ou plus : colis de sa zone, meilleure rareté × 1,5 (comme le palier de 15 min).
		{ MinShare = 0.15, Label = "Big Box", Rule = { ZoneStep = 0, TopBoost = 1.5 } },
		-- Les autres : colis de sa zone, aux chances des rayons.
		{ MinShare = 0, Label = "Box", Rule = { ZoneStep = 0 } },
	} :: { RewardTier },

	-- Modèle -------------------------------------------------------------------------------------------------------
	-- ENV_Event_ArmoredVan de Clément (ReplicatedStorage/Assets, sinon ServerStorage/Assets ; facultatif) : pivot en bas
	-- au centre, avant vers −Z ; HealthBarPoint (Attachment) facultatif. Absent : un fourgon en blocs construit par le
	-- code (VanSize). a425 (L-324 Q3) : VanSize ne sert plus qu'à ce repli ; l'explosion part de BlastPoint (sans lui :
	-- du centre de la boîte englobante du modèle).
	Asset = "ENV_Event_ArmoredVan",
	VanSize = Vector3.new(14, 12, 30), -- V0 proposé (Cantin, 23/11) : repli « géant » (le camion fait 34 studs de long)
	BillboardAsset = "BB_ArmoredVanHP", -- barre de vie de Clément (Assets/UI), facultative : Fill (GuiObject), HPText (TextLabel)
	BillboardSize = Vector2.new(16, 3), -- V0 : repli, en studs
	BillboardMaxDistance = 400, -- V0 : repli
	-- a425 (L-324) : le fourgon cassé reste RemoveDelay s, porte et pièces envolées, le trésor (Cargo) à l'air, puis
	-- disparaît. Avant : 3 s ; garder ≥ TruckEvent.DebrisLifetime + DebrisFadeTime (4 s, les pièces s'effacent avant).
	RemoveDelay = 6, -- V0 proposé (Cantin, 24/11)

	-- Casse vue par les clients (a425, L-324 ; ArmoredVanController) : l'explosion du camion (TruckController) reprise :
	-- les pièces Pieces/Piece_xx volent depuis BlastPoint (vitesses, chute et effacement : Config/TruckEvent Debris*).
	ExplosionSound = "SFX_TruckExplosion", -- V0 proposé (Cantin, 24/11) : le son du camion, en attendant un son à lui
	ExplosionRadius = 16, -- V0 proposé (Cantin, 24/11) : explosion native, sans force ni dégât, à BlastPoint
	-- Gyrophares de Clément (Neon) : la gauche et la droite clignotent en alternance pendant le trajet (local).
	Beacons = {
		Left = { "Beacon_L", "LightBar_L" },
		Right = { "Beacon_R", "LightBar_R" },
		Period = 0.4, -- V0 proposé (Cantin, 24/11) : s par côté
		Dim = 0.75, -- V0 proposé (Cantin, 24/11) : LocalTransparencyModifier du côté éteint
	},
	-- Jet de billets à la casse : copies de FX_Collect_Bill (Assets, l'effet du ramassage) qui jaillissent de CashPoint
	-- vers l'arrière, retombent et s'effacent avec les pièces. Absent : pas de jet.
	CashJet = {
		Asset = "FX_Collect_Bill",
		Count = 16, -- V0 proposé (Cantin, 24/11)
		Speed = { 14, 26 }, -- V0 proposé (Cantin, 24/11) : studs/s vers l'arrière…
		Up = { 18, 30 }, -- V0 proposé (Cantin, 24/11) : … et vers le haut
		Spread = math.rad(40), -- V0 proposé (Cantin, 24/11) : écart au hasard autour de l'arrière
	},
	-- Inventaire plein à la casse (a425, L-325 réponse 2 de Clément) : le colis n'est pas perdu, il tombe par terre
	-- derrière le fourgon (rayon d'événement de StoreHeistService, comme les colis du camion) et n'importe qui peut
	-- l'ouvrir et prendre l'objet. Remplace l'ancien « box is lost ».
	DropLifetime = 60, -- V0 proposé (Cantin, 24/11) : comme TruckEvent.BoxLifetime, puis il disparaît
	DropBehind = 5, -- V0 proposé (Cantin, 24/11) : studs derrière l'arrière du fourgon
	DropSpacing = 4, -- V0 proposé (Cantin, 24/11) : studs entre deux colis côte à côte
	-- a509 (L-457, Clément : « les boîtes qui explosent et qui donnent la possibilité de les ouvrir », comme le camion) :
	-- à la casse, le colis de chaque casseur récompensé jaillit du fourgon (vol depuis BlastPoint) et retombe derrière lui
	-- (DropBehind, DropSpacing, DropLifetime), à ouvrir sur place comme les colis du camion ; n'importe qui peut l'ouvrir,
	-- comme le colis d'inventaire plein (L-325). Sans rayon d'événement : l'objet va dans l'inventaire comme avant.
	-- Réglage seulement : rien ne jaillit sans l'interrupteur Features.ArmoredVanBurst (partout) ou ArmoredVanBurstDev
	-- (jeu DEV). false, ou interrupteur coupé : l'objet va tout droit dans l'inventaire (avant a509).
	BurstBoxes = true, -- V0 proposé (Cantin, 27/11)

	-- Bannière d'événement (a425, L-318 Q2 ; UI_EventBanner de Clément, EventBannerController) : quand aucun événement
	-- live n'y est, le fourgon s'y montre avec un minuteur : StateAttribute du Workspace = "Soon" (départ annoncé,
	-- minuteur jusqu'au départ) ou "Road" (en route, minuteur jusqu'à sa fuite), EndsAtAttribute = heure serveur.
	StateAttribute = "ArmoredVanState",
	EndsAtAttribute = "ArmoredVanEndsAt",
	Banner = {
		Soon = { Title = "HEIST OF THE CENTURY", Effect = "An armored van is coming: break it together!" }, -- V0
		Road = { Title = "HEIST OF THE CENTURY", Effect = "Break the armored van before it escapes!" }, -- V0
	},

	-- Textes (anglais) -----------------------------------------------------------------------------------------------
	Messages = {
		Soon = "The armored van drives through the corridor in %d s!", -- annonce, %d = secondes
		SoonDetail = "Heist of the century · hit it together", -- petite ligne de l'annonce
		Delayed = "The armored van waits for daylight.", -- départ dû la nuit
		DelayedTruck = "The armored van waits for the truck to leave.", -- a425 : départ dû pendant le camion (V0)
		Started = "HEIST OF THE CENTURY! The armored van is in the corridor!",
		StartedDetail = "Break it together · top 3 get the best box",
		Broken = "The armored van is open! Top: %s", -- %s = noms du top 3
		BrokenDetail = "%d players get a box", -- %d = nombre de casseurs récompensés
		Escaped = "The armored van escaped!",
		Reward = "Heist of the century: #%d (%d%% of the damage), %s: %s %s!", -- rang, part, colis, rareté, objet
		TooLittle = "Heist of the century: hit harder next time to get a box!",
		-- a425 (L-325 réponse 2) : %s = nom du colis (Label). V0 proposé (Cantin, 24/11).
		Full = "Heist of the century: inventory full! Your %s fell behind the van, anyone can grab it!",
		Lost = "Heist of the century: inventory full, your box is lost!", -- a425 : seulement si le colis n'a pas pu tomber
		-- a509 (L-457) : colis jailli (BurstBoxes) ; rang, part, nom du colis (Label). V0 proposé (Cantin, 27/11).
		Burst = "Heist of the century: #%d (%d%% of the damage)! Your %s burst out of the van, open it!",
	},
	AnnounceIcon = "ICON_Event_ArmoredVan", -- V0 : icône de l'annonce (Decal de Clément), facultative

	-- V2 (a516, décision de Cantin du 27/11 ; Features.ArmoredVanV2 / ArmoredVanV2Dev, l'emporte sur ArmoredVanBurst) ----
	-- Plus de classement, de Top 3, de Big Box, de « meilleure zone du joueur » ni de PV selon les joueurs présents. Le
	-- trajet (TravelTime) est coupé en paliers de StepTime s : palier n = zone StepZones[n] (zone 6 au départ, zone 1 à la
	-- fin). Les dégâts reçus s'additionnent depuis le départ ; le fourgon casse dès que ce total atteint le seuil du palier
	-- en cours (un palier qui commence avec un total déjà assez haut casse tout de suite). Pas cassé au bout de TravelTime s :
	-- il s'échappe sans rien donner, comme avant.
	-- Seuil d'une zone, fixe (le même quel que soit le serveur) = ThresholdPlayers × ThresholdHitsPerSecond ×
	-- ThresholdSeconds × Zones[zone].AdvisedDamage (la table active, lue par ArmoredVanService) : trois joueurs de la
	-- puissance de la zone le cassent en 20 s s'ils frappent sans arrêt.
	-- À la casse : les colis de la zone du palier tombent au sol autour du fourgon (rayon d'événement de StoreHeistService,
	-- placement du camion, TruckEventService.LandingPoint ; même durée au sol que le camion), à ouvrir sur place par
	-- n'importe qui, sans plafond par joueur.
	V2 = {
		StepTime = 25, -- Cantin (27/11) : 6 paliers de 25 s sur les 150 s du trajet
		StepZones = { 6, 5, 4, 3, 2, 1 }, -- Cantin (27/11) : zone des colis de chaque palier, dans l'ordre du trajet
		ThresholdPlayers = 3, -- Cantin (27/11) : groupe de référence des seuils
		ThresholdHitsPerSecond = 5, -- Cantin (27/11) : Balance.Hit.MaxHitsPerSecond
		ThresholdSeconds = 20, -- Cantin (27/11)
		-- Cantin (27/11) : 12 colis, règles de Config/Rewards.ZoneBox comme les colis de zone du camion (TierZoneBox), zone de
		-- référence = celle du palier : NextZone (zone au-dessus, ses 3 meilleures raretés 60/30/10, jamais Secret ; zone 6 :
		-- les 3 meilleures de la zone 6), Zone (les chances des rayons), BestZone (meilleure rareté de la zone × 1,5).
		Boxes = {
			{ Rule = "NextZone", Count = 3 },
			{ Rule = "Zone", Count = 5 },
			{ Rule = "BestZone", Count = 4 },
		},
		MinLuck = 3, -- Cantin (27/11) : au moins ×3 de chance à l'ouverture de chaque colis
		-- L'objet sort toujours de la zone du palier, comme au camion (les 10 % de zone suivante sont retirés : Cantin, 27/11).
		-- Jauge au-dessus du fourgon : BB_VanGauge de Clément (Assets/UI, facultatif) ou repli construit par le code :
		-- Title (TextLabel, « ZONE 6 »), Bar/Fill (GuiObject, part du seuil du palier déjà atteinte), ProgressText (TextLabel,
		-- facultatif), Steps/Step_1 à Step_6 (GuiObject, palier n ; facultatifs), chacun avec Current (palier en cours) et Done
		-- (palier passé), GuiObject facultatifs que le code montre ou cache.
		GaugeAsset = "BB_VanGauge", -- V0 proposé (Cantin, 27/11) : nom à confirmer par Clément
		GaugeSize = Vector2.new(16, 4), -- V0 : repli, en studs
		ZoneText = "ZONE %d", -- V0 proposé (Cantin, 27/11)
		Messages = {
			StartedDetail = "Break it early for better boxes!", -- V0 proposé (Cantin, 27/11)
			Broken = "Armored van broken: Zone %d boxes!", -- Cantin (27/11) : %d = zone du palier
			BrokenDetail = "%d boxes on the ground, anyone can open them", -- V0 proposé (Cantin, 27/11) : %d = colis posés
		},
	},
}

return DeepFreeze(ArmoredVan)
