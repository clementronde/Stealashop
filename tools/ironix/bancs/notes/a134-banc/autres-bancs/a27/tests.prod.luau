--!nocheck
-- G. Hors de Studio : le crochet n'est pas écouté, l'horaire marche, pas de lignes d'aide.

local TruckEvent = sharedModule("Config/TruckEvent")
startServer()

section("G. Hors de Studio")
Workspace:SetAttribute("TruckSpawnNow", 3)
flush()
advance(1)
check(#trucks() == 0 and Workspace:GetAttribute("TruckSpawnNow") == 3, "G1 TruckSpawnNow pas écouté : rien, attribut laissé tel quel")
local seen = 0
ON_FRAME = function()
	if seen == 0 and #trucks() > 0 then
		seen = now()
	end
end
advance(TruckEvent.SpawnIntervalMax + 1, 0.25)
check(seen >= TruckEvent.SpawnIntervalMin and seen <= TruckEvent.SpawnIntervalMax + 1.5, `G2 l'horaire marche hors de Studio (camion à {seen} s)`)
check(not logHas("[TruckEventService] camion n°"), "G3 pas de lignes d'aide au test hors de Studio")
check(not logHas("[Contrat]"), "G4 (le ContractChecker ne tourne qu'en Studio)")

summary("scénario hors Studio")
