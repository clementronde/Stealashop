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
	-- Vague 31 (L-112 ; UnboxService) : objet sorti d'un colis ouvert sur le rayon, ou volé
	-- au sol d'une autre boutique pendant son antivol. Trois champs facultatifs, sans changement de version
	-- (absents = objet libre, comme avant) :
	AntiTheft: boolean?, -- true = sous antivol : il ne va sur un présentoir qu'une fois repris « UNLOCKED! »
	UnlockAt: number?, -- heure serveur (Workspace:GetServerTimeNow) de la fin de l'antivol, posée à la pose au sol
	Spot: Spot?, -- posé au sol de sa boutique (même repère que Box.Spot) ; nil = dans l'inventaire
	-- Vague 62 (a203, Cantin) : poids tiré avec l'objet, en kg (1 à 10 000 ; Config/Weight, Shared/ItemWeight) : taille du
	-- modèle et revenu. Facultatif, sans changement de version : absent = posé au chargement par DataService
	-- (ItemWeight.Migrate, selon l'ancienne mutation de taille ; au moins le revenu d'avant).
	Weight: number?,
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
	-- Vague 61 (a199) : dons du tuto déjà versés ([« Tool » | « Aura »] = true), une seule fois par profil.
	-- Facultatif (profil sans le champ : aucun don versé).
	Gifts: { [string]: boolean }?,
}

export type Lifetime = {
	Heists: number,
	Steals: number,
	Defenses: number,
	PlaySeconds: number,
	BestIncome: number?, -- vague 50 (a161) : meilleur revenu par seconde de tous les temps (LeaderboardService) ; absent = 0
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
	IncomeEconomy: number?, -- a486 : table de l'économie (Config/Economy) dans laquelle Income a été noté, posée par la
	-- conversion du profil (Shared/EconomyProfile) ; absent = la table du serveur. OfflineService convertit le gain d'une
	-- absence notée dans l'autre table, et l'efface en relevant un nouveau Income.
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

-- Coffre hebdomadaire (agent a166, MAJ 1 ; champ facultatif, sans nouvelle version : complété depuis
-- TEMPLATE). Semaine = numéro de Config/Rewards.Weekly (lundi 00:00 UTC).
export type WeeklyRewards = {
	Week: number, -- semaine comptée (0 = aucune) : une autre semaine remet Days et LastDay à zéro
	Days: number, -- jours de connexion différents comptés cette semaine
	LastDay: number, -- dernier jour UTC compté (0 = aucun)
	ClaimedWeek: number, -- semaine du dernier coffre réclamé (0 = jamais)
}

-- Récompenses (v8, DEV-101 ; Partie 2, 3.3). Écrit par RewardService seulement.
export type Rewards = {
	Daily: DailyRewards,
	Playtime: PlaytimeRewards,
	Weekly: WeeklyRewards?, -- a166, facultatif
}

-- Réglages du joueur (L-095 point 2, écran UI_Settings ; Config/Settings). Écrit par SettingsService
-- seulement, après contrôle de chaque valeur.
-- Une quête du jour (vague 80, a266 ; QuestService, Config/Quests).
export type QuestEntry = {
	Id: string, -- Id de Config/Quests
	Progress: number, -- progression comptée par le serveur (bornée à Goal)
	Goal: number, -- objectif fixé au tirage
	Claimed: number, -- os.time() de la réclamation (0 = pas réclamée)
}

-- Quêtes du jour (vague 80, a266). Écrit par QuestService seulement.
export type Quests = {
	Day: number, -- jour UTC du tirage (un autre jour tire de nouvelles quêtes)
	List: { QuestEntry }, -- dans l'ordre des places 1 à Config/Quests.PerDay
}

-- Roue de la fortune (vague 80, a266). Écrit par WheelService seulement.
export type Wheel = {
	FreeDay: number, -- jour UTC du dernier tour gratuit (0 = jamais)
	Extra: number, -- tours en plus gardés (Robux, pas encore en vente)
}

-- GC6 (a409, MAJ 6, DEV-140) : classements hebdomadaires. Écrit par WeeklyLeaderboardService seulement.
export type WeeklyBoard = {
	Week: number, -- semaine (lundi 00:00 UTC, Config/WeeklyLeaderboard.WeekOf) de ces compteurs ; 0 = jamais
	BestIncome: number, -- meilleur revenu par seconde de la semaine, sans les boosts du moment (comme Lifetime.BestIncome)
	HeistsAt: number?, -- a409 : Lifetime.Heists au début de la semaine ; plus lu depuis a430 (L-325 (1) : les braquages ne comptent plus)
	StealsAt: number, -- Lifetime.Steals au début de la semaine (vols de la semaine = écart)
	Rewarded: { [string]: number }, -- [classement] = dernière semaine réglée (récompense donnée, ou rien à donner)
	Pending: { number }, -- a430 (L-325 (3)) : semaines finies jouées dont la récompense attend encore d'être réglée
}

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
	-- IndexService au premier versement. Une zone complète sans entrée attend que le joueur réclame sa
	-- prime (L-127 point 2, vague 34 : remote ClaimIndexReward ; avant, elle était versée toute seule).
	IndexGifts: { [string]: number }?, -- vague 59 (a191, L-183) : [numéro de zone en texte] = os.time() du don de
	-- la Vitesse et de l'objet de la récompense de zone (IndexService). Champ facultatif, sans changement de
	-- version : absent = rien donné ; une zone dans IndexRewards sans entrée ici (réclamée avant la vague 59)
	-- reçoit la Vitesse et l'objet au chargement suivant, sans nouvelle prime.
	Settings: Settings?, -- réglages du joueur (L-095 point 2 ; SettingsService, Config/Settings). Champ
	-- facultatif, sans changement de version : absent = réglages par défaut ; un champ invalide reprend
	-- sa valeur par défaut au chargement (Settings.Sanitize).
	Hotbar: { string }?, -- vague 25 : disposition de la barre du bas UI_Hotbar choisie par le joueur
	-- (HotbarService, Shared/HotbarLayout) : 6 identifiants dans l'ordre des cases, "Tool", "Bat", uid
	-- d'un colis ou d'un objet, "" pour une case vide (jamais de trou). Champ facultatif, sans changement de
	-- version : absent = disposition de départ ; un uid qui n'est plus au joueur devient vide au chargement.
	SkillTree: { [string]: number }?, -- vague 27 : niveau acheté de chaque compétence de l'arbre
	-- (SkillTreeService, Config/SkillTree), [Id] = niveau ≥ 1 (une compétence pas achetée n'a pas d'entrée).
	-- Champ facultatif, sans changement de version : absent = rien d'acheté. Nettoyé au chargement : Id
	-- inconnu retiré, niveau entier borné à MaxLevel, niveau ≤ 0 retiré.
	PotionStock: { [string]: number }?, -- vague 33 (demande de Cantin du 2026-11-13) : potions ramassées
	-- dans l'inventaire (PotionService, Config/Potions), [Id] = nombre de 1 à MaxStock. Champ facultatif, sans
	-- changement de version : absent = aucune potion. Nettoyé au chargement : Id inconnu retiré, nombre entier
	-- borné à MaxStock, nombre ≤ 0 retiré.
	ZonesReached: { [string]: number }?, -- vague 41 (mesure ZoneReached de la bêta) : [numéro de zone en texte,
	-- « 3 »] = temps de jeu cumulé (s) à la 1re entrée dans cette zone (TelemetryService). Champ facultatif, sans
	-- changement de version : absent = aucune zone atteinte depuis la vague 41 ; créé à la 1re entrée.
	Codes: { [string]: number }?, -- a162 (MAJ 0) : codes cadeaux pris par ce profil (CodeService, Config/Codes),
	-- [code en majuscules] = os.time() du don. Champ facultatif, sans changement de version : absent = aucun.
	Rebirths: number?, -- vague 51 (a164, DEV-120) : renaissances faites (RebirthService, Config/Rebirths), entier ≥ 0.
	-- Champ facultatif, sans changement de version : 0 dans le gabarit de DataService (absent = 0). Écrit d'un seul
	-- tenant avec la remise à zéro ; ne compte qu'avec Features.Rebirth (coupé : sans effet).
	Diamonds: number?, -- vague 59 (a191, L-182 point 10) : diamants, 2e monnaie pour personnaliser sa boutique.
	-- Champ facultatif, sans changement de version : 0 dans le gabarit de DataService (absent = 0). Lu par
	-- DataService.GetDiamonds ; aucun gain ni achat encore (règles à venir), affiché seulement dans UI_DiamondShop.
	IndexMutations: { [string]: { [string]: number } }?, -- vague GC6 (a410, MAJ 7) : colonnes de mutations de l'index,
	-- [ItemId] = { [Id d'effet de Config/Mutations] = os.time() de la 1re obtention } (IndexService, Shared/IndexMutations).
	-- Champ facultatif, sans changement de version : {} dans le gabarit ; jamais retiré.
	Reserve: { string }?, -- vague 63 (a206, L-192 Q3) : uids des objets en réserve, dans l'ordre (DisplayService,
	-- Config/Displayed) : remplacés par « Exposer les meilleurs », ou retirés d'un présentoir sans main libre. Champ
	-- facultatif, sans changement de version, absent du gabarit : absent = profil d'avant la réserve, que
	-- DisplayService migre au chargement (ses objets ni exposés, ni au coffre-fort, ni sous antivol y vont, les plus
	-- rentables d'abord, au plus Config/Displayed.ReserveMax ; rien n'est retiré de Items). Nettoyé à chaque usage.
	Quests: Quests?, -- vague 80 (a266, DEV-132) : quêtes du jour (QuestService, Config/Quests). Champ facultatif, sans
	-- changement de version, absent du gabarit : créé et réparé par QuestService au premier passage du jour.
	Wheel: Wheel?, -- vague 80 (a266, DEV-141) : roue de la fortune (WheelService, Config/Wheel). Champ facultatif, sans
	-- changement de version, absent du gabarit : créé et réparé par WheelService.
	ShopLayout: number?, -- a280 (L-294, Cantin le 2026-11-23) : échelle de la boutique (Shared/ShopFloor) : 0 = 20 présentoirs
	-- au rez-de-chaussée (avant L-294), 1 = 8 en bas puis l'étage acheté et ses places. Champ facultatif, sans changement de
	-- version : 0 dans le gabarit de DataService (absent = 0) ; passé à 1 au chargement par ShopFloor.Migrate dès que le
	-- Floor_2 du gabarit est là, jamais dans l'autre sens.
	WeeklyBoard: WeeklyBoard?, -- GC6 (a409, DEV-140) : classements hebdomadaires (WeeklyLeaderboardService). Champ
	-- facultatif, sans changement de version ; dans le gabarit de DataService depuis a430 (Week = 0 : remis à zéro par ce
	-- service à la première lecture), réparé et remis à zéro chaque lundi par ce service.
	Funnels: { [string]: boolean }?, -- a414 (vague GC7) : entonnoirs une fois par profil (FunnelService, Config/Funnels) :
	-- [« New »] = true pour un profil nouveau à son 1er passage, [« <entonnoir>/<n° d'étape> »] = true pour une étape
	-- envoyée. Champ facultatif, sans changement de version, absent du gabarit : créé par FunnelService au chargement.
	ItemCatalog: number?, -- a429 (L-327) : catalogue des ItemId du profil, 2 ou 3 (Config/Items.Version) ; 2 dans le gabarit
	-- (absent = 2), passé au catalogue actif au chargement par DataService (switchCatalog). Sans changement de version.
	Economy: number?, -- a486 : table de l'économie des montants du profil, 1 ou 2 (Config/Economy.Version) ; absent = 1
	-- (hors du gabarit) ; passé à la table du serveur au chargement par DataService (switchEconomy, Shared/EconomyProfile).
	EconomyBackup: any?, -- a486 : { From, To, Before, After } : montants d'avant et d'après la dernière conversion, pour
	-- un retour exact (Shared/EconomyProfile). Sans changement de version.
	-- Partie 2 : Defenses, Rebirths, ajoutés par migration (Version = 9 et suivantes : la v2 est prise
	-- par le catalogue d'objets v2, la v3 par la boutique Robux, la v4 par l'index, la v5 par les colis
	-- sur les présentoirs, la v6 par les gains hors ligne, la v7 par les colis dans l'inventaire, la v8
	-- par les récompenses).
}

return {}
