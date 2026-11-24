--!nocheck
-- pc-reach : Player:GetNetworkPing() dans le faux Roblox (absent du faux d'a30) : PING[player] en secondes, 0 par défaut.
PING = {}
Methods.GetNetworkPing = function(self)
	return PING[self] or 0
end
-- pc-cantin : les essais R4 et R7 (plafond qui suit la vitesse) allongent le scénario ; le chrono du vigile
-- (Balance.Heist.Duration) est porté à 40 s dans le faux arbre pour que R8 se joue avant la sortie du vigile.
do
	local key = "shared/Config/Balance.luau"
	local patched, count = string.gsub(SOURCES[key], "\n\t\tDuration = [%d%.]+,", "\n\t\tDuration = 40,")
	assert(count == 1, "Balance.Heist.Duration introuvable dans Config/Balance")
	SOURCES[key] = patched
end
