--!nocheck
-- a293 : copie de a286-banc/pre-complice.luau. Ouverture d'avant (Features.SingleBoxReveal = false, comme
-- a202-banc/pre.oldflow.luau) ; la prime au complice n'est PAS forcée : Config/Features doit déjà avoir
-- HeistPartnerBonus = true (a293). Doublure de HubService (amis pilotés par FRIENDS).
do
	local key = "shared/Config/Features.luau"
	local src = string.gsub(SOURCES[key], "SingleBoxReveal = true", "SingleBoxReveal = false")
	assert(string.find(src, "\n\tHeistPartnerBonus = true,", 1, true), "a293 : Features.HeistPartnerBonus n'est pas allumé")
	SOURCES[key] = src
end
FRIENDS = {}
SOURCES["stub/HubService"] = [==[
local HubService = {}
function HubService.AreFriends(a, b)
	return FRIENDS[a.Name .. "+" .. b.Name] == true or FRIENDS[b.Name .. "+" .. a.Name] == true
end
return HubService
]==]
