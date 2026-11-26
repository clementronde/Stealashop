--!strict
-- a500 (26/11, Cantin) : le seul endroit qui dit dans quel jeu Roblox tourne ce serveur (ou ce client) : DEV, TEST ou
-- PROD. Module feuille, sans aucun require (Economy, Balance, ProductIds et DataService le lisent sans boucle).
--
--   DEV   « Steal a Shop [DEV] »   GameId 10774974820 (liaison, L-001)
--   TEST  « Steal a shop [TEST] »  GameId 10778712931, copie du DEV pour les testeurs : traité comme le DEV
--         (Config/ProductIds.IsDev, Config/Economy.IsDev, store des profils DevStoreName, variantes …Dev), mais achats
--         Robux et badges coupés (ProductIds.IsTest, ProductIds.PurchasesDisabled : les Ids du DEV n'y existent pas)
--   PROD  tout autre jeu : la PROD (GameId 10774998269), Studio hors ligne (GameId 0), les bancs
--
-- Le réglage « Auto / Dev / Prod » reste Config/ProductIds.Environment.
--
-- API :
--   GameEnv.DevGameId, GameEnv.TestGameId, GameEnv.ProdGameId: number
--   GameEnv.IsDevFor(gameId) -> boolean        le jeu DEV seulement
--   GameEnv.IsTestFor(gameId) -> boolean       le jeu TEST seulement
--   GameEnv.IsDevLikeFor(gameId) -> boolean    DEV ou TEST (tout ce qui se comporte comme le DEV)
--   GameEnv.GameId: number?                    game.GameId de ce serveur (nil s'il est illisible)
--   GameEnv.IsDev, GameEnv.IsTest, GameEnv.IsDevLike: boolean    les mêmes règles pour ce serveur

local DEV_GAME_ID = 10774974820
local TEST_GAME_ID = 10778712931
local PROD_GAME_ID = 10774998269

local function known(gameId: number?): boolean
	return type(gameId) == "number" and gameId ~= 0
end

local function isDevFor(gameId: number?): boolean
	return known(gameId) and gameId == DEV_GAME_ID
end

local function isTestFor(gameId: number?): boolean
	return known(gameId) and gameId == TEST_GAME_ID
end

local function isDevLikeFor(gameId: number?): boolean
	return isDevFor(gameId) or isTestFor(gameId)
end

local function currentGameId(): number?
	local ok, id = pcall(function(): any
		return (game :: any).GameId
	end)
	return if ok and type(id) == "number" then id else nil
end

local GAME_ID = currentGameId()

local GameEnv = {
	DevGameId = DEV_GAME_ID,
	TestGameId = TEST_GAME_ID,
	ProdGameId = PROD_GAME_ID,
	IsDevFor = isDevFor,
	IsTestFor = isTestFor,
	IsDevLikeFor = isDevLikeFor,
	GameId = GAME_ID,
	IsDev = isDevFor(GAME_ID),
	IsTest = isTestFor(GAME_ID),
	IsDevLike = isDevLikeFor(GAME_ID),
}

export type GameEnv = typeof(GameEnv)

return table.freeze(GameEnv)
