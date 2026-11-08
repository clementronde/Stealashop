--!strict
-- Type du profil sauvegardé d'un joueur (ReplicatedStorage/Shared/Types/Profile).
-- Schéma v6 : la forme de la v1 (section 9.5 de la Partie 1), avec les ItemId du catalogue
-- d'objets v2 (Config/Items, liaison L-045 ; DataService, MIGRATIONS[2], renomme ou remplace ceux
-- de la v1), et, en v3 (DEV-100, boutique Robux de la Partie 2), Monetization et Boosts, et la date
-- du don dans Purchases (MIGRATIONS[3]) ; en v4 (DEV-111, index des objets de la Partie 2), Index
-- (MIGRATIONS[4]) ; en v5 (L-086, colis posés sur les présentoirs), Boxes rangé par numéro de
-- présentoir et BoxQueue (MIGRATIONS[5]) ; en v6 (DEV-102, gains hors ligne), Offline (MIGRATIONS[6]).
-- Valeurs de départ dans DataService.
-- Ce module ne contient que des types : on l'utilise avec
--   local ProfileTypes = require(ReplicatedStorage.Shared.Types.Profile)
--   local data: ProfileTypes.Data = ...
--
-- Règles de stockage (ProfileStore et DataStore) :
--   - jamais de tableau numérique à trous : un emplacement (présentoir, coffre-fort) est donc
--     indexé par son numéro écrit en texte : Display["3"] = uid ; une liste (BoxQueue) reste sans
--     trou (table.insert, table.remove) ;
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

-- Un colis posé sur un présentoir (v5, L-086 ; sur un établi avant), en attente d'ouverture
-- (horodatée serveur), ou dans la file des colis à poser.
export type Box = {
	Tier: BoxTier,
	Zone: number, -- 1 à 6
	ItemId: string, -- objet tiré par le serveur à la mise en rayon (Config/Items)
	Rarity: string, -- rareté tirée, ex. « Epic » : toujours celle de l'objet au catalogue
	ReadyAt: number, -- os.time() à partir duquel OpenBox est accepté
	Mutation: Mutation?, -- DEV-131 : mutation tirée à la mise en rayon, donnée à l'objet à l'ouverture (facultatif)
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
	Boxes: { [string]: Box }, -- v5 : [numéro de présentoir en texte] = colis en attente (ce présentoir
	-- compte comme occupé : DisplayService n'y pose aucun objet) ; jusqu'à la v4 : [numéro d'établi]
	BoxQueue: { Box }, -- v5 : colis sans présentoir (migration sans place libre, présentoir absent de la
	-- parcelle), du plus ancien au plus récent ; UnboxService les pose dès qu'un présentoir se libère
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
	-- Partie 2 : Defenses, Rebirths, Rewards, ajoutés par migration (Version = 7 et suivantes : la v2
	-- est prise par le catalogue d'objets v2, la v3 par la boutique Robux, la v4 par l'index, la v5 par
	-- les colis sur les présentoirs, la v6 par les gains hors ligne).
}

return {}
