--!strict
-- Ids des offres Robux en DEV et en PROD (a285, 21/11 ; liaison L-067). DEV et PROD sont deux jeux Roblox
-- distincts : un gamepass ou un produit développeur créé dans PROD ne s'achète pas depuis DEV. Les Ids écrits
-- dans Config/Monetization et Config/Boosts (champ Id) sont ceux de PROD ; ceux de DEV sont ici, par clé.
--
-- Choix du jeu d'Ids (Environment) :
--   "Auto"  le jeu DEV (game.GameId = Balance.Profiles.DevGameId, comme la DataStore des profils) prend
--           les Ids de Dev ; tout autre jeu (PROD, Studio hors ligne, bancs) garde ceux de PROD ;
--   "Dev"   toujours les Ids de Dev ;  "Prod"  toujours ceux de PROD.
-- 0 = offre pas encore créée dans ce jeu : rien n'est vendu.
-- a485 (25/11) : état au 25/11 : les Ids des offres prêtes sont posés dans les deux jeux depuis a444 (24/11, commit
-- f1555856) : ×2 Cash, ×2/×4 Training, ×2 Speed, Auto Collect, Quick Lock (FastOpen), +4 Displays, Starter Pack, les 6 packs
-- d'argent et les 4 paliers d'Open Now. À 0 (pas créés, ne pas créer avant leur code) : VIP, Hydraulic Gloves, Revenge,
-- Instant Shutter, ×3 Luck, Server Luck ×2/×4/×8, caisse exclusive ×1/×3/×10, Sleeping Guards. Règle : un Id posé ne se
-- supprime ni ne se réutilise jamais ; une offre retirée garde son Id, vente coupée sur le Creator Hub (Open Now 3 et 4).
--
-- Clés de Dev : la clé de l'offre (PassKey, ProductKey, clé d'un boost de Config/Boosts), OpenNow1 et OpenNow2
-- pour les paliers d'Ouvrir maintenant en vente (OpenNow3 et OpenNow4 : paliers coupés, Monetization RetiredTiers),
-- Crate1, Crate3 et Crate10 pour les lots de la caisse exclusive. Une clé absente vaut 0.
--
-- API : ProductIds.IsDev: boolean ; ProductIds.Pick(key, prodId) -> number (l'Id à utiliser dans ce jeu).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)

export type Environment = "Auto" | "Dev" | "Prod"

local ENVIRONMENT: Environment = "Auto" -- V0 proposé le 2026-11-21 (a285)

local Dev: { [string]: number } = {
	-- Gamepasses
	DoubleCash = 2099561059,
	DoubleTraining = 2098985017,
	DoubleSpeed = 2099495015, -- a319 (L-303) : x2 SPEED, gamepass permanent (a485 : 49 R$, Config/Monetization)
	VIP = 0,
	AutoCollect = 2101906271,
	FastOpen = 2098265079,
	ExtraStands = 2100029033,
	HydraulicGloves = 0,
	-- Produits développeur
	StarterPack = 3735786424,
	Cash10 = 3735787184,
	Cash30 = 3735787374,
	Cash60 = 3735787436,
	Cash180 = 3735787830,
	Cash300 = 3735787886,
	Cash720 = 3735788027,
	OpenNow1 = 3735788091,
	OpenNow2 = 3735788288,
	OpenNow3 = 3735788351, -- a485 : palier coupé, ne jamais réutiliser ni supprimer (reçus en attente encore livrés)
	OpenNow4 = 3735788532, -- a485 : palier coupé, ne jamais réutiliser ni supprimer (reçus en attente encore livrés)
	Revenge = 0,
	InstantShutter = 0,
	Luck3 = 0,
	-- a485 (L-351) : Shield30 retiré pour de bon (jamais créé) : plus de clé.
	ServerLuck2 = 0,
	ServerLuck4 = 0,
	ServerLuck8 = 0,
	-- Caisse exclusive
	Crate1 = 0,
	Crate3 = 0,
	Crate10 = 0,
	-- Boosts du HUD (Config/Boosts) ; a319 : SpeedBoost retiré (devenu le gamepass DoubleSpeed ; le produit SpeedBoost n'a
	-- jamais été créé)
	SleepGuards = 0,
}

local function currentGameId(): number?
	local ok, id = pcall(function(): any
		return (game :: any).GameId
	end)
	return if ok and type(id) == "number" then id else nil
end

local function isDev(environment: Environment, gameId: number?): boolean
	if environment == "Dev" then
		return true
	elseif environment == "Prod" then
		return false
	end
	local devGameId = Balance.Profiles.DevGameId
	return gameId ~= nil and gameId ~= 0 and gameId == devGameId
end

local IS_DEV = isDev(ENVIRONMENT, currentGameId())

local ProductIds = {
	Environment = ENVIRONMENT,
	IsDev = IS_DEV,
	Dev = Dev,
}

-- L'Id à utiliser dans ce jeu pour l'offre `key` dont l'Id PROD est `prodId`.
function ProductIds.Pick(key: string, prodId: number): number
	if not IS_DEV then
		return prodId
	end
	local id = Dev[key]
	return if type(id) == "number" then id else 0
end

-- Bancs : le même choix pour un réglage et un GameId donnés.
function ProductIds.IsDevFor(environment: Environment, gameId: number?): boolean
	return isDev(environment, gameId)
end

export type ProductIds = typeof(ProductIds)

return DeepFreeze(ProductIds)
