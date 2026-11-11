--!strict
-- Type du profil sauvegardé d'un joueur (ReplicatedStorage/Shared/Types/Profile).
-- Schéma v8 : la forme de la v1 (section 9.5 de la Partie 1), avec les ItemId du catalogue
-- d'objets v2 (Config/Items, liaison L-045 ; DataService, MIGRATIONS[2], renomme ou remplace ceux
-- de la v1), et, en v3 (DEV-100, boutique Robux de la Partie 2), Monetization et Boosts, et la date
-- du don dans Purchases (MIGRATIONS[3]) ; en v4 (DEV-111, index des objets de la Partie 2), Index
-- (MIGRATIONS[4]) ; en v5 (L-086, colis posés sur les présentoirs), Boxes rangé par numéro de
-- présentoir et une file de colis (MIGRATIONS[5]) ; en v6 (DEV-102, gains hors ligne), Offline
-- (MIGRATIONS[6]) ; en v7 (L-089, colis dans l'inventaire, ouverts au sol de la boutique), Boxes rangé
-- par uid de colis, avec Spot et At, et plus de file (MIGRATIONS[7]) ; en v8 (DEV-101, récompenses
-- quotidiennes et de temps de jeu), Rewards (MIGRATIONS[8]).
-- Valeurs de départ dans DataService.
-- Ce module ne contient que des types : on l'utilise avec
--   local ProfileTypes = require(ReplicatedStorage.Shared.Types.Profile)
--   local data: ProfileTypes.Data = ...
--
-- Règles de stockage (ProfileStore et DataStore) :
--   - jamais de tableau numérique à trous : un emplacement (présentoir, coffre-fort) est donc
--     indexé par son numéro écrit en texte : Display["3"] = uid ; une liste reste sans trou
--     (table.insert, table.remove) ;
--   - aucune Instance, aucun Vector3/CFrame/Color3, aucune fonction ;
--   - un champ ajouté passe par une nouvelle version et une migration (DataService).

-- Tiers de colis (attribut `Tier` du contrat de noms).
export type BoxTier = "Standard" | "Premium" | "Luxe"

-- Provenance d'un objet : volé à un magasin PNJ ou à un joueur.
export type ItemSource = "NPC" | "PvP"

export type Stats = {
	Speed: number,
	Strength: number,
}

-- Niveau acheté de chaque amélioration de base (section 7.5).
export type Upgrades = {
	Treadmill: number,
	Bench: number,
	DisplaySlots: number,
	UnboxBenches: number, -- ancien niveau des établis : gardé, sans effet depuis la v5 (L-086)
}

export type Tools = {
	Owned: { string }, -- identifiants d'outils, « Fists » toujours présent
	Equipped: string,
}

export type Cosmetics = {
	Auras: { string },
	Trails: { string },
	EquippedAura: string?,
	EquippedTrail: string?,
}

-- Un objet possédé, rangé par son uid unique (anti-duplication, section 9.6).
export type Item = {
	Id: string, -- identifiant du catalogue (Config/Items), ex. « Z3_Smartphone » ; sa rareté vient du catalogue
	Source: ItemSource,
	At: number, -- os.time() de l'obtention
	Zone: number?, -- zone du magasin d'origine : nécessaire au revenu d'un objet présent dans
	-- plusieurs zones (le Secret) ; absent des objets créés avant le 2026-11-06 (zone 1 par défaut)
	Mutation: Mutation?, -- DEV-131 (L-084) : mutation tirée avec le colis, gardée au vol ; absent =
	-- aucune mutation. Champ facultatif, sans changement de version (un objet sans champ = sans mutation)
}

-- Mutation d'un objet ou d'un colis (DEV-131, L-084 point 3 ; Config/Mutations) : une par famille au
-- plus, des Id en texte, ex. { Size = "Big", Effect = "Gold" } ; un champ absent = rien dans cette famille.
export type Mutation = {
	Size: string?,
	Effect: string?,
}

-- Point du sol de la boutique où un colis est posé (v7, L-089), dans le repère du pivot de la
-- parcelle (PlayerPlot:GetPivot(), en studs) : la même place dans n'importe quelle parcelle, toutes
-- copiées du même gabarit PLOT_Shop (le joueur n'a pas toujours la même d'une session à l'autre).
export type Spot = {
	X: number,
	Y: number,
	Z: number,
}

-- Un colis possédé (v7, L-089) : dans l'inventaire (Spot = nil : un Tool de la barre d'inventaire,
-- InventoryService), ou posé au sol de sa boutique, en attente d'ouverture (horodatée serveur).
-- Jusqu'à la v6 : posé sur un présentoir (v5, L-086), sur un établi avant, ou dans la file BoxQueue.
export type Box = {
	Tier: BoxTier,
	Zone: number, -- 1 à 6
	ItemId: string, -- objet tiré par le serveur à la mise en rayon (Config/Items), secret jusqu'à l'ouverture
	Rarity: string, -- rareté tirée, ex. « Epic » : toujours celle de l'objet au catalogue
	ReadyAt: number?, -- heure serveur (Workspace:GetServerTimeNow) à partir de laquelle OpenBox est
	-- accepté. Posé au sol : toujours là. Dans l'inventaire : nil, sauf pour un colis repris d'un
	-- présentoir ou de la file à la migration v7 (l'heure déjà promise, gardée à la pose si plus tôt)
	Mutation: Mutation?, -- DEV-131 : mutation tirée à la mise en rayon, donnée à l'objet à l'ouverture (facultatif)
	Spot: Spot?, -- v7 : posé au sol de sa boutique, à ce point ; nil = dans l'inventaire
	At: number?, -- v7 : os.time() de l'arrivée dans l'inventaire (ordre de la barre ; nil = le plus ancien)
}

export type Tutorial = {
	Step: number,
	Done: boolean,
}

export type Lifetime = {
	Heists: number,
	Steals: number,
	Defenses: number,
	PlaySeconds: number,
}

-- Boutique Robux (v3, DEV-100 ; MonetizationService).
export type Monetization = {
	Passes: { [string]: boolean }, -- [clé du gamepass] = true : vu possédé à la dernière lecture (cache
	-- de UserOwnsGamePassAsync, utilisé tant que Roblox n'a pas répondu à l'arrivée)
	StarterPack: boolean, -- pack de départ acheté (offre unique)
	OpenNowCredit: number, -- secondes d'« Ouvrir maintenant » payées sans colis à ouvrir, retirées des prochains colis posés
}

-- Boosts temporaires (v3) : secondes restantes, comptées seulement pendant le jeu.
export type Boosts = {
	Cash: number, -- boost ×2 argent (pack de départ ; récompenses plus tard)
}

-- Gains hors ligne (v6, DEV-102 ; OfflineService, Config/Offline). Écrit par le serveur seulement :
-- au départ du joueur et toutes les Offline.SnapshotInterval s de jeu (un serveur qui plante ne fait
-- pas perdre l'absence).
export type Offline = {
	LastSeenAt: number, -- os.time() de la dernière présence en jeu ; 0 = inconnue (profil d'avant la v6,
	-- profil neuf) : aucun gain hors ligne au retour
	Income: number, -- $/s de la boutique à ce moment : objets exposés × bonus permanents, sans les
	-- boosts temporaires (au retour : absence × Income × Offline.Rate)
	Pending: number?, -- vague 22 (L-092 3f) : dollars entiers gagnés hors ligne, en attente du Claim de
	-- l'écran UI_Offline (remote ClaimOffline). Champ facultatif, sans changement de version (comme
	-- IndexRewards) : absent = 0. Remis à 0 au Claim, dans la même exécution que le versement ; pas réclamé,
	-- il reste là et le gain du retour suivant s'y ajoute
}

-- Calendrier de 7 jours (v8, DEV-101 ; RewardService, Config/Rewards). Jour UTC = os.time() // 86400.
export type DailyRewards = {
	Streak: number, -- dernier jour du calendrier réclamé (0 = aucun, 1 à 7) ; 7 = cycle fini, le suivant repart à J1
	LastDay: number, -- jour UTC de cette réclamation (0 = jamais)
}

-- Temps de jeu de la journée UTC (v8, DEV-101), compté par le serveur.
export type PlaytimeRewards = {
	Day: number, -- jour UTC compté (0 = aucun) : un autre jour remet Seconds et Claimed à zéro
	Seconds: number, -- secondes de jeu ce jour-là
	Claimed: { [string]: number }, -- [minutes du palier en texte, « 15 »] = os.time() de la réclamation
}

-- Récompenses (v8, DEV-101 ; Partie 2, 3.3). Écrit par RewardService seulement.
export type Rewards = {
	Daily: DailyRewards,
	Playtime: PlaytimeRewards,
}

-- Réglages du joueur (L-095 point 2, écran UI_Settings ; Config/Settings). Écrit par SettingsService
-- seulement, après contrôle de chaque valeur.
export type Settings = {
	Music: number, -- volume de la musique, de 0 à 1
	Sfx: number, -- volume des effets sonores, de 0 à 1
	Vfx: boolean, -- effets visuels complets
	Click: string, -- Id du son de clic (Config/Settings.Clicks)
}

-- Profil complet, clé ProfileStore « Player_<UserId> ».
export type Data = {
	Version: number,
	Cash: number,
	Stats: Stats,
	Upgrades: Upgrades,
	Tools: Tools,
	Cosmetics: Cosmetics,
	Items: { [string]: Item }, -- [uid] = objet
	Display: { [string]: string }, -- [numéro de présentoir en texte] = uid
	Vault: { [string]: string }, -- [numéro de coffre-fort en texte] = uid (1 offert)
	Boxes: { [string]: Box }, -- v7 : [uid du colis] = colis possédé, dans l'inventaire ou posé au sol de
	-- sa boutique (UnboxService) ; v5 et v6 : [numéro de présentoir en texte], plus la file BoxQueue
	-- (retirée en v7) ; jusqu'à la v4 : [numéro d'établi]
	Tutorial: Tutorial,
	Lifetime: Lifetime,
	Purchases: { [string]: number }, -- [PurchaseId] = os.time() du don (achats Robux idempotents, 9.6 ;
	-- v1 et v2 : true, jamais écrit, devenu 0 en v3). Borné par MonetizationService (Config/Monetization)
	Monetization: Monetization, -- v3
	Boosts: Boosts, -- v3
	Index: { [string]: number }, -- v4 : [ItemId] = os.time() de sa découverte, la 1re fois que le
	-- joueur l'a possédé (IndexService ; Config/Index). Jamais retiré : un objet volé, remis ou perdu
	-- reste découvert. La migration v3 → v4 y met les objets déjà possédés (DataService, MIGRATIONS[4])
	Offline: Offline, -- v6 : heure et revenu de la dernière présence, pour les gains hors ligne (DEV-102)
	Rewards: Rewards, -- v8 : calendrier de 7 jours et temps de jeu du jour (DEV-101, RewardService)
	IndexRewards: { [string]: number }?, -- [numéro de zone en texte, « 3 »] = os.time() du versement de
	-- la prime de zone complète de l'Index (IndexService, Config/Index ; L-083 point 7). Champ facultatif,
	-- sans changement de version (comme Item.Mutation) : absent = aucune prime versée ; créé par
	-- IndexService au premier versement. Une zone complète sans entrée est payée au chargement suivant.
	Settings: Settings?, -- réglages du joueur (L-095 point 2 ; SettingsService, Config/Settings). Champ
	-- facultatif, sans changement de version : absent = réglages par défaut ; un champ invalide reprend
	-- sa valeur par défaut au chargement (Settings.Sanitize).
	-- Partie 2 : Defenses, Rebirths, ajoutés par migration (Version = 9 et suivantes : la v2 est prise
	-- par le catalogue d'objets v2, la v3 par la boutique Robux, la v4 par l'index, la v5 par les colis
	-- sur les présentoirs, la v6 par les gains hors ligne, la v7 par les colis dans l'inventaire, la v8
	-- par les récompenses).
}

return {}
