--!nocheck
-- a294 : avant la mise en place d'a38 (copie du pre.luau d'a285 : REPLACE, petits manques du faux Roblox), sans allumer
-- Features.RobuxCrate (false comme dans le dépôt) et avec la boutique remise coupée (pre.on d'a38 l'allume) :
--   - Ids de banc des lots de la caisse : PROD 8301, 8302, 8303 (Config/Monetization), DEV 8401, 8402, 8403
--     (Config/ProductIds.Dev) ;
--   - SET_ENVIRONMENT(env) : Config/ProductIds.ENVIRONMENT (« Auto » dans le dépôt ; faux Roblox sans GameId = PROD) ;
--   - MonetizationService.BancDrawCrate (le tirage du serveur) et BancStartCrateReveal (l'ouverture) exposés au banc.
local function replace(key, from, to)
	local source = SOURCES[key]
	local first, last = string.find(source, from, 1, true)
	assert(first, `remplacement introuvable dans {key} : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. to .. string.sub(source, last + 1)
end
REPLACE = replace
CRATE_IDS = { [1] = 8301, [3] = 8302, [10] = 8303 }
DEV_CRATE_IDS = { [1] = 8401, [3] = 8402, [10] = 8403 }
local M = "shared/Config/Monetization.luau"
for count, id in CRATE_IDS do
	local from = string.match(SOURCES[M], "{ Count = " .. count .. ", Price = %d+, Id = 0 }")
	assert(from, `lot de {count} introuvable`)
	replace(M, from, (string.gsub(from, "Id = 0", `Id = {id}`)))
end
local P = "shared/Config/ProductIds.luau"
for count, id in DEV_CRATE_IDS do
	replace(P, `\tCrate{count} = 0,`, `\tCrate{count} = {id},`)
end
replace("shared/Config/Features.luau", "RobuxShop = true", "RobuxShop = false")
local S = "server/Services/MonetizationService.luau"
replace(S, "local function newItemUid(", "MonetizationService.BancDrawCrate = drawCrate -- banc a294\nMonetizationService.BancStartCrateReveal = startCrateReveal -- banc a294\nlocal function newItemUid(")
function SET_ENVIRONMENT(env)
	replace(P, `local ENVIRONMENT: Environment = "Auto"`, `local ENVIRONMENT: Environment = "{env}"`)
end

Vector2.zero = Vector2.new(0, 0)
local ud2 = getmetatable(UDim2.new(0, 0, 0, 0))
ud2.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
function Methods.FindFirstAncestorOfClass(self, class)
	local current = self.Parent
	while current ~= nil do
		if current.ClassName == class then
			return current
		end
		current = current.Parent
	end
	return nil
end
