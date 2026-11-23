--!strict
-- Événement de la Fortune Tower (liaison L-108 point 8, idée de Clément du 2026-11-12 ; pas encore une
-- tâche du backlog). Très rarement, une énorme vitrine apparaît en zone 6 (la Fortune Tower), pleine
-- d'objets énormes et très rares ; il faut s'y mettre à plusieurs pour la casser. Lu par
-- FortuneTowerService (serveur) et FortuneTowerController (client) ; interrupteur :
-- Config/Features.FortuneTower (true depuis la validation de Clément, L-145 réponse (a), 2026-11-14).
--
-- Le doc ne fixe aucune valeur : TOUTES sont des « V0 proposé, absent du doc », tirées des valeurs
-- existantes (camion : Config/TruckEvent ; zones : Config/Zones ; chances : Config/Rarities ; tailles :
-- Config/Mutations), avec le calcul en commentaire. Elles suivent toutes seules une retouche de ces
-- valeurs-là. Unités : secondes, studs, pour cent (0 à 100).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)
local Mutations = require(script.Parent.Mutations)
local Rarities = require(script.Parent.Rarities)
local TruckEvent = require(script.Parent.TruckEvent)
local Zones = require(script.Parent.Zones)

-- V0 proposé, absent du doc : la Fortune Tower est la zone 6 (la dernière, « Bank », NEW YORK).
local ZONE = 6

-- Fréquence -------------------------------------------------------------------------------------------
-- V0 proposé, absent du doc : 5 fois plus rare que le camion (8 à 12 min) : une vitrine toutes les
-- 40 à 60 min, soit une à deux par heure de jeu (« très rarement », L-108).
local RARER_THAN_TRUCK = 5

-- PV --------------------------------------------------------------------------------------------------
-- V0 proposé, absent du doc : elle vit autant que le camion (TruckEvent.Lifetime, 3 min)…
local LIFETIME = TruckEvent.Lifetime
-- … et BREAKERS joueurs au niveau conseillé de la zone 6 la cassent en la moitié de ce temps, au rythme
-- du plafond de coups (Balance.Hit.MaxHitsPerSecond : 5 coups/s depuis le rééquilibrage v2 ; avant : 7).
local BREAKERS = 3 -- validé par Cantin, 21/11 (a286 ; L-228 c, proposition « 3 et 6 » de L-232) : la moitié d'un serveur de 6 joueurs (4 du temps des serveurs de 8)
local HITS_PER_SECOND = Balance.Hit.MaxHitsPerSecond
local BREAK_TIME = LIFETIME / 2 -- V0 proposé, absent du doc : 90 s
-- MaxHP = 3 × 2 000 000 × 5 × 90 = 2 700 000 000 PV (2.7B), soit environ 25 vitrines de la zone 6 (108.8M) (a286 ; 3.6B à 4).
-- Seul au niveau conseillé : 270 s, une fois et demie sa vie (impossible) ; à 2 : 135 s ; à 3 : 90 s.
local MAX_HP = BREAKERS * Zones[ZONE].AdvisedDamage * HITS_PER_SECOND * BREAK_TIME

-- Butin -----------------------------------------------------------------------------------------------
-- Raretés : Mythique et au-dessus seulement (L-108 : « Mythique, Secret, Divine »), dans les mêmes
-- proportions que le colis Luxe (Rarities.BoxOdds.Luxe), ramenées à 100 :
--   Mythic 1,8 / (1,8 + 0,2 + 0) = 90 %, Secret 0,2 / 2 = 10 %, Divine 0 / 2 = 0 %.
-- Divine reste à 0 tant que le catalogue n'a aucun objet Divine (BoxOdds.Luxe.Divine = 0, comme le reste
-- du jeu) ; quand Clément posera BoxOdds.Luxe.Divine = 0,02 (V0 de Config/Rarities), elle passera
-- d'elle-même à 0,02 / 2,02 ≈ 1 %.
local LOOT_MIN_RARITY = "Mythic" -- V0 proposé, absent du doc
local function lootOdds(): { [string]: number }
	local minOrder = Rarities.ById[LOOT_MIN_RARITY].Order
	local luxe = Rarities.BoxOdds.Luxe
	local total = 0
	for _, rarity in Rarities.List do
		if rarity.Order >= minOrder then
			total += luxe[rarity.Id] or 0
		end
	end
	local odds: { [string]: number } = {}
	for _, rarity in Rarities.List do
		if rarity.Order >= minOrder then
			odds[rarity.Id] = if total > 0 then (luxe[rarity.Id] or 0) / total * 100 else 0
		end
	end
	return odds
end

-- Tailles : toujours Huge ou Colossal (L-108 : « en taille Huge ou Colossal »), dans les proportions de
-- Config/Mutations ramenées à 100 : Huge 4 / (4 + 1) = 80 %, Colossal 1 / 5 = 20 %. L'effet (Gold,
-- Neon…) est tiré comme partout ailleurs (Mutations.Roll).
local LOOT_SIZES = { "Huge", "Colossal" } -- V0 proposé, absent du doc
local function sizeOdds(): { [string]: number }
	local total = 0
	for _, id in LOOT_SIZES do
		total += Mutations.SizeById[id].Chance
	end
	local odds: { [string]: number } = {}
	for _, id in LOOT_SIZES do
		odds[id] = Mutations.SizeById[id].Chance / total * 100
	end
	return odds
end

local FortuneTower = {
	Zone = ZONE,

	-- Apparition --------------------------------------------------------------------------------------
	SpawnIntervalMin = RARER_THAN_TRUCK * TruckEvent.SpawnIntervalMin, -- 5 × 8 min = 40 min
	SpawnIntervalMax = RARER_THAN_TRUCK * TruckEvent.SpawnIntervalMax, -- 5 × 12 min = 60 min
	-- Seulement de jour, comme le camion, et assez tôt pour durer toute sa vie avant l'alerte de la nuit :
	-- 180 s de vie + la marge du camion (60 s) = 240 s ; et pas dans la ruée de l'aube (30 s, camion).
	MinDayLeft = LIFETIME + TruckEvent.MinDayLeft,
	DawnDelay = TruckEvent.DawnDelay,
	-- V0 proposé, absent du doc : « il faut s'y mettre à plusieurs » : pas d'apparition automatique avec
	-- moins de 2 joueurs sur le serveur. Une vitrine due attend (ni camion présent, ni nuit, ni joueur seul).
	MinPlayers = 2,

	-- Vie ---------------------------------------------------------------------------------------------
	MaxHP = MAX_HP, -- 2.7B PV partagés (a286 ; 3.6B avant), sans régénération (calcul plus haut)
	Lifetime = LIFETIME, -- 180 s : pas cassée à temps, elle se referme sans rien lâcher

	-- Butin -------------------------------------------------------------------------------------------
	-- Un colis Luxe (la caisse cerclée d'or, temps de prise 1 s de Balance.Heist.BoxTiers) par joueur d'un
	-- serveur plein (6 depuis L-228 ; 8 avant), posé à la casse sur les points LootSpawn_NN à l'intérieur du coffre
	-- (L-145 réponse (c) de Clément, 2026-11-14 : on entre dans le coffre), ramassable par tous.
	LootCount = 6, -- validé par Cantin, 21/11 (a286 ; L-228 c, L-232) : un par joueur d'un serveur de 6 (8, validé par Clément en L-145 réponse (a), pour des serveurs de 8)
	LootTier = "Luxe", -- V0 validé par Clément (L-145 réponse (a))
	-- Zones dont les objets Mythiques (et toute rareté rangée par zone) peuvent sortir d'un colis : 2 à 6
	-- (L-145 réponse (b) de Clément, 2026-11-14 : la zone 6 n'a qu'un Mythique). Lu dans le catalogue
	-- (Items.ByZone) : un objet ajouté à Config/Items en zone 2 à 6 sort de lui-même. Le Secret et le Divine
	-- sont toutes zones (Items.AllZones). Un colis porte la zone de son objet (règle de CarryService).
	LootZones = { 2, 3, 4, 5, ZONE },
	RarityOdds = lootOdds(), -- { Mythic = 90, Secret = 10, Divine = 0 }
	-- Vague 42 : les colis s'ouvrent sur place comme sur un rayon (Cantin) : RarityOdds y tire la rareté de la
	-- CAISSE, minimum de l'objet (la chance ne fait que monter) ; SizeOdds y remplace le tirage de taille du
	-- rayon (L-145 (a), valeurs validées par Clément). Vague 62 (a203) : le poids de l'objet est ensuite tiré dans le
	-- palier de la taille gagnée (Shared/ItemWeight.RollForSize : Huge 250 à 2 500 kg, Colossal 2 500 à 10 000 kg).
	SizeOdds = sizeOdds(), -- { Huge = 80, Colossal = 20 }
	BoxLifetime = TruckEvent.BoxLifetime, -- 60 s au sol, comme les colis du camion, puis il disparaît
	-- Point LootSpawn_NN : le colis est posé sur la première surface sous lui (le sol du coffre), cherchée
	-- par un rayon parti LootRayUp studs au-dessus du point (V0 proposé, absent du doc : un point posé
	-- au ras du sol, ou un peu dedans, trouve quand même ce sol).
	LootRayUp = 1,
	-- Sans points LootSpawn_NN dans le modèle de Clément (ou bloc V0) : une rangée devant la face avant, à
	-- LootDistance studs d'elle, un colis tous les LootSpacing studs.
	LootDistance = TruckEvent.ScatterMinRadius, -- 6 studs, l'écart minimal des colis du camion
	LootSpacing = TruckEvent.BoxFallbackWidth + 2 * TruckEvent.BoxGap, -- 2 + 2 × 1 = 4 studs, centre à centre
	-- La vitrine ouverte reste aussi longtemps que son butin peut rester au sol, puis elle est retirée (un
	-- joueur encore dedans est d'abord posé PushMargin studs devant elle).
	RemoveDelay = TruckEvent.BoxLifetime,

	-- Place -------------------------------------------------------------------------------------------
	-- Sans point tagué FortuneVaultSpawn : au milieu de la chaussée de la zone 6, entre ses deux magasins,
	-- ComputedOffset studs plus loin dans le couloir, là où le camion ne se pose pas (le camion se pose au
	-- milieu, 34 studs de long : demi-longueur 17 + 13 de marge = 30), face aux joueurs qui arrivent.
	ComputedOffset = 30,
	-- V0 proposé, absent du doc : joueur pris dans la vitrine à l'apparition, ou encore dedans quand elle se
	-- referme ou est retirée, posé à 3 studs devant elle (jamais enfermé).
	PushMargin = 3,

	-- Bloc V0 (Studio seulement, tant qu'ENV_Event_FortuneVault n'est pas livré) : vitre de 18 × 16 studs
	-- (6 joueurs de front, 3 studs d'épaule chacun ; a286 : 24 et 8 joueurs avant L-228) dans un cadre doré de 8 studs de profondeur.
	V0Width = 18,
	V0Height = 16,
	V0Depth = 8,

	-- Barre de PV (client) : BB_FortuneHP de Clément si elle est livrée, sinon BB_TruckHP (la barre du
	-- camion, telle quelle), sinon BB_WindowHP agrandie comme pour le camion (repli seulement).
	HealthBarScale = TruckEvent.HealthBarScale, -- 2
	HealthBarMaxDistance = TruckEvent.HealthBarMaxDistance, -- 250 studs

	-- Annonces à tout le serveur (Notify, UI_Toast), en anglais (L-036) ---------------------------------
	NotifyKind = "Announce", -- comme l'annonce d'un objet Légendaire et plus (Config/Unbox.AnnounceKind)
	Messages = {
		Spawned = "A giant vault appeared at the Fortune Tower! Break it together!",
		Opened = "The Fortune vault is open: grab the loot!",
		Sealed = "The Fortune vault sealed itself. Too slow!",
		SealedNight = "Night is coming: the Fortune vault sealed itself.",
	},
	GrabActionText = "Grab", -- invite d'un colis de la vitrine au sol (comme le camion et la batte)
}

export type FortuneTower = typeof(FortuneTower)

return DeepFreeze(FortuneTower)
