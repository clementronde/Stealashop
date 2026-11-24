--!nocheck
-- H. Interrupteur Features.TruckEvent = false : aucun camion, crochet inactif, contrôleur client inactif.

startServer()
local A = newPlayer("Alice")
spawnCharacter(A, Vector3.new(-40, 3, 0))
startClient(A)

section("H. Interrupteur coupé")
advance(15 * 60, 0.25)
check(#trucks() == 0, "H1 Features.TruckEvent = false : aucun camion en 15 min")
check(logHas("événement camion coupé"), "H2 une ligne au démarrage du service")
Workspace:SetAttribute("TruckSpawnNow", 2)
flush()
check(#trucks() == 0, "H3 le crochet de test ne fait rien non plus")
check(#serverCalls("GrabDropped") == 0 and A.PlayerGui:FindFirstChild("BB_WindowHP_EventTruck") == nil, "H4 côté client, rien")

summary("scénario coupé")
