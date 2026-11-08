--!strict
-- Type du profil sauvegardé d'un joueur (ReplicatedStorage/Shared/Types/Profile).
-- Schéma v3 : la forme de la v1 (section 9.5 de la Partie 1), avec les ItemId du catalogue
-- d'objets v2 (Config/Items, liaison L-045 ; DataService, MIGRATIONS[2], renomme ou remplace ceux
-- de la v1), et, en v3 (DEV-100, boutique Robux de la Partie 2), Monetization et Boosts, et la date
-- du don dans Purchases (MIGRATIONS[3]). Valeurs de départ dans DataService.
-- Ce module ne contient que des types : on l'utilise avec
--   local ProfileTypes = require(ReplicatedStorage.Shared.Types.Profile)
--   local data: ProfileTypes.Data = ...
--
-- Règles de stockage (ProfileStore et DataStore) :
--   - jamais de tableau numérique à trous : un emplacement (présentoir, coffre-fort,
--     établi) est donc indexé par son numéro écrit en texte : Display["3"] = uid ;
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
	UnboxBenches: number,
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
}

-- Un colis posé sur un établi, en attente d'ouverture (horodatée serveur).
export type Box = {
	Tier: BoxTier,
	Zone: number, -- 1 à 6
	ItemId: string, -- objet tiré par le serveur à la mise en rayon (Config/Items)
	Rarity: string, -- rareté tirée, ex. « Epic » : toujours celle de l'objet au catalogue
	ReadyAt: number, -- os.time() à partir duquel OpenBox est accepté
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
	Boxes: { [string]: Box }, -- [numéro d'établi en texte] = colis
	Tutorial: Tutorial,
	Lifetime: Lifetime,
	Purchases: { [string]: number }, -- [PurchaseId] = os.time() du don (achats Robux idempotents, 9.6 ;
	-- v1 et v2 : true, jamais écrit, devenu 0 en v3). Borné par MonetizationService (Config/Monetization)
	Monetization: Monetization, -- v3
	Boosts: Boosts, -- v3
	-- Partie 2 : Defenses, Rebirths, Index, Rewards, ajoutés par migration (Version = 4 : la v2 est
	-- prise par le catalogue d'objets v2, la v3 par la boutique Robux).
}

return {}
