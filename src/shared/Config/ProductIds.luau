--!strict
-- Ids des offres Robux en DEV et en PROD (a285, 21/11 ; liaison L-067). DEV et PROD sont deux jeux Roblox
-- distincts : un gamepass ou un produit développeur créé dans PROD ne s'achète pas depuis DEV. Les Ids écrits
-- dans Config/Monetization et Config/Boosts (champ Id) sont ceux de PROD ; ceux de DEV sont ici, par clé.
--
-- Choix du jeu d'Ids (Environment) :
--   "Auto"  le jeu DEV (game.GameId = Balance.Profiles.DevGameId, comme la DataStore des profils) prend
--           les Ids de Dev ; tout autre jeu (PROD, Studio hors ligne, bancs) garde ceux de PROD ;
--   "Dev"   toujours les Ids de Dev ;  "Prod"  toujours ceux de PROD.
-- 0 = offre pas encore créée dans ce jeu : rien n'est vendu (comme aujourd'hui, tous les Ids valent 0).
--
-- Clés de Dev : la clé de l'offre (PassKey, ProductKey, clé d'un boost de Config/Boosts), OpenNow1 à OpenNow4
-- pour les paliers d'Ouvrir maintenant, Crate1, Crate3 et Crate10 pour les lots de la caisse exclusive. Une clé
-- absente vaut 0.
--
-- API : ProductIds.IsDev: boolean ; ProductIds.Pick(key, prodId) -> number (l'Id à utiliser dans ce jeu).

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)

export type Environment = "Auto" | "Dev" | "Prod"

local ENVIRONMENT: Environment = "Auto" -- V0 proposé le 2026-11-21 (a285)

local Dev: { [string]: number } = {
	-- Gamepasses
	DoubleCash = 0,
	DoubleTraining = 0,
	VIP = 0,
	AutoCollect = 0,
	FastOpen = 0,
	ExtraStands = 0,
	HydraulicGloves = 0,
	-- Produits développeur
	StarterPack = 0,
	Cash10 = 0,
	Cash30 = 0,
	Cash60 = 0,
	Cash180 = 0,
	Cash300 = 0,
	Cash720 = 0,
	OpenNow1 = 0,
	OpenNow2 = 0,
	OpenNow3 = 0,
	OpenNow4 = 0,
	Revenge = 0,
	InstantShutter = 0,
	Luck3 = 0,
	Shield30 = 0,
	ServerLuck2 = 0,
	ServerLuck4 = 0,
	ServerLuck8 = 0,
	-- Caisse exclusive
	Crate1 = 0,
	Crate3 = 0,
	Crate10 = 0,
	-- Boosts du HUD (Config/Boosts)
	SpeedBoost = 0,
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
