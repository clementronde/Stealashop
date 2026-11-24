--!nocheck
-- pc-reach : Player:GetNetworkPing() dans le faux Roblox (absent du faux d'a30) : PING[player] en secondes, 0 par défaut.
PING = {}
Methods.GetNetworkPing = function(self)
	return PING[self] or 0
end
-- Scénario zero : les trois types de colis à GrabTime 0 dans le faux arbre (prise et ouverture en un seul appel).
do
	local key = "shared/Config/Balance.luau"
	local patched, count = string.gsub(SOURCES[key], "GrabTime = [%d%.]+", "GrabTime = 0")
	assert(count == 3, "GrabTime des trois types introuvable dans Config/Balance")
	SOURCES[key] = patched
end
