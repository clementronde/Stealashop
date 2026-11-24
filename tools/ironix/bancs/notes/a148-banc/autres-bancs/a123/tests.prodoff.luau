--!nocheck
-- D. Hors Studio, Features.FortuneTower = false (coupé à la main depuis a148, true livré) : rien du tout, crochet ignoré.

setFeature("FortuneTower", false)
setFeature("TruckEvent", false)
startServer()
local A = newPlayer("Alice")
local B = newPlayer("Bob")
spawnCharacter(A, Vector3.new(680, 3, 0))
spawnCharacter(B, Vector3.new(680, 3, 4))

section("D. Coupé hors Studio")
check(logHas("événement Fortune Tower coupé", "PRINT", "prod"), "D1 une ligne au démarrage")
check(not logHas("FortuneTest", nil, "prod"), "D2 pas de crochet de test annoncé hors Studio")
advance(65 * 60, 1)
check(#vaults() == 0, "D3 aucune vitrine en 65 min à 2 joueurs")
Workspace:SetAttribute("FortuneTest", true)
advance(1, 0.1)
check(#vaults() == 0 and Workspace:GetAttribute("FortuneTest") == true, "D4 crochet FortuneTest ignoré (pas lu, pas effacé)")
summary("scénario hors Studio coupé")
