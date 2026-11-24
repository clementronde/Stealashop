--!nocheck
-- a286 : ouverture d'avant (Features.SingleBoxReveal = false, comme a202-banc/pre.oldflow.luau) et prime au complice
-- allumée (Features.HeistPartnerBonus = true) ; doublure de HubService (amis pilotés par FRIENDS).
do
	local key = "shared/Config/Features.luau"
	local src, n = string.gsub(SOURCES[key], "SingleBoxReveal = true", "SingleBoxReveal = false")
	local m
	src, m = string.gsub(src, "\n\tHeistPartnerBonus = %a+,", "\n\tHeistPartnerBonus = true,")
	assert(m == 1, "a286 : ligne HeistPartnerBonus = … introuvable dans Config/Features")
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
