--!nocheck
-- a135 D. Remise à zéro des profils DEV (vague 40, Cantin 2026-11-14) : DataService ouvre la DataStore
-- Balance.Profiles.DevStoreName dans le jeu DEV (GameId 10774974820) seulement ; le jeu PROD (10774998269), un
-- jeu inconnu, une place pas publiée (GameId 0) ou un GameId illisible gardent « PlayerData ». Aucune DataStore
-- n'est effacée (le faux ProfileStore note tout appel autre que New). Faux Roblox : celui du banc a21-hud.

local DEV, PROD = 10774974820, 10774998269

SOURCES["stub/ProfileStore"] = [==[
local P = { DataStoreState = "Access", IsClosing = false }
function P.New(name, template)
	table.insert(PS_CALLS, { kind = "New", name = name })
	return {
		StartSessionAsync = function() return nil end,
		RemoveAsync = function(_, key) table.insert(PS_CALLS, { kind = "RemoveAsync", name = name, key = key }) end,
		MessageAsync = function() end,
		GetAsync = function() return nil end,
	}
end
return P
]==]
PS_CALLS = {}

local sharedRoot = folder(ReplicatedStorage, "Shared")
local dirs = { [""] = sharedRoot }
local function dirFor(path)
	if dirs[path] then
		return dirs[path]
	end
	local parentPath, name = string.match(path, "^(.-)/?([^/]+)$")
	local f = folder(dirFor(parentPath), name)
	dirs[path] = f
	return f
end
for key in SOURCES do
	local rest = string.match(key, "^shared/(.+)%.luau$")
	if rest then
		local dir, name = string.match(rest, "^(.-)/?([^/]+)$")
		moduleScript(dirFor(dir), name, key)
	end
end
local Balance = requireModule(ReplicatedStorage.Shared.Config.Balance, "server")

-- Un serveur neuf par GameId : un Server/Services/DataService neuf (cache de require par module).
local n = 0
local function boot(gameId)
	n += 1
	games.server.GameId = gameId
	local server = folder(ServerScriptService, "Server" .. n)
	moduleScript(folder(server, "Packages"), "ProfileStore", "stub/ProfileStore")
	local module = moduleScript(folder(server, "Services"), "DataService", "server/Services/DataService.luau")
	table.clear(PS_CALLS)
	clearLog()
	local DS = requireModule(module, "server")
	DS.Init()
	return DS
end
local function opened()
	local names = {}
	for _, c in PS_CALLS do
		if c.kind == "New" then
			table.insert(names, c.name)
		end
	end
	return names
end
local function onlyNew()
	for _, c in PS_CALLS do
		if c.kind ~= "New" then
			return false
		end
	end
	return true
end

print("\n== D0. Réglage")
local P = Balance.Profiles
check(P ~= nil and P.StoreName == "PlayerData", "D0a StoreName = « PlayerData » (PROD, inchangé)")
check(P ~= nil and P.DevGameId == DEV, "D0b DevGameId = jeu DEV (L-001)")
check(P ~= nil and type(P.DevStoreName) == "string" and P.DevStoreName ~= "PlayerData" and #P.DevStoreName <= 50, "D0c DevStoreName : un autre nom (≤ 50 caractères)")
check(P ~= nil and P.DevGameId ~= PROD, "D0d le jeu PROD n'est pas le jeu DEV")

print("\n== D1. Jeu DEV : nouvelle DataStore, vide")
local DS = boot(DEV)
local names = opened()
check(#names == 1 and names[1] == P.DevStoreName, "D1a ProfileStore.New(DevStoreName) : " .. tostring(names[1]))
check(DS.GetStoreName() == P.DevStoreName, "D1b GetStoreName = DevStoreName")
check(onlyNew(), "D1c rien d'effacé (aucun appel autre que New)")
taskLib.spawn(DS.Start)
step(0.1)
check(logHas("jeu DEV : profils lus dans", "PRINT") and logHas(P.DevStoreName, "PRINT"), "D1d la sortie dit quelle DataStore est lue")

print("\n== D2. Jeu PROD : « PlayerData », comme avant")
DS = boot(PROD)
names = opened()
check(#names == 1 and names[1] == "PlayerData", "D2a ProfileStore.New(« PlayerData ») : " .. tostring(names[1]))
check(DS.GetStoreName() == "PlayerData" and onlyNew(), "D2b GetStoreName = PlayerData, rien d'effacé")
taskLib.spawn(DS.Start)
step(0.1)
check(not logHas("jeu DEV", "PRINT"), "D2c pas de ligne « jeu DEV » en PROD")

print("\n== D3. Autres cas : « PlayerData »")
for _, id in { 0, 123456, "absent" } do
	if id == "absent" then id = nil end
	DS = boot(id)
	names = opened()
	check(#names == 1 and names[1] == "PlayerData", `D3 GameId {tostring(id)} : PlayerData ({tostring(names[1])})`)
end
check(DS.StoreNameFor(DEV) == P.DevStoreName and DS.StoreNameFor(PROD) == "PlayerData" and DS.StoreNameFor(nil) == "PlayerData", "D3d StoreNameFor")

summary()
