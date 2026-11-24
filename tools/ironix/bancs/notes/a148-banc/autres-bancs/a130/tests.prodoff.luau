--!nocheck
-- a130 : hors Studio, Features.FortuneTower = false (coupé à la main depuis a148) : Force refusé (rien n'est branché).
setFeature("FortuneTower", false) -- a148 : true livré, coupé ici à la main (avant le require)
local Fortune = serverModule("FortuneTowerService")
setFeature("TruckEvent", false)
startServer()
local ok, msg = Fortune.Force("Spawn")
flush()
check(ok == false and msg == "Fortune Tower is off (Features.FortuneTower).", `P1 Spawn refusé ({msg})`)
check(#vaults() == 0, "P2 aucune vitrine")
summary("scénario prodoff")
