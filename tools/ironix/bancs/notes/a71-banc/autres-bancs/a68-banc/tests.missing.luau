--!nocheck
-- M. Rien de livré (ni sons ni BB_GuardShout ni écrans) : rien ne joue, une ligne par manque, pas d'erreur.
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(zoneMiddle(1), 3, 0))
startClient(alice)
local guard = buildGuard(alice, zoneMiddle(1) + 20)

section("M. Deux poursuites sans assets")
for _ = 1, 2 do
	serverFire("ChaseState", alice, true, guard)
	advance(3)
	serverFire("ChaseState", alice, false)
	advance(1)
end
check(#sfx("Chase_Siren") == 0, "M1 pas de sirène")
check(bubbleOf(alice) == nil, "M2 pas de bulle")
for _, name in { "Heist_Grab", "Chase_Whistle" } do -- Chase_Siren retirée (L-117 point 5)
	check(logCount(`« {name} » absent`, "PRINT", "client") == 1, `M3 {name} absent : une ligne, une seule fois`)
end
check(logCount("BB_GuardShout absent", "PRINT", "client") == 1, "M4 BB_GuardShout absent : une ligne, une seule fois")
check(not logHas("[ChaseFeel]", "WARN", "client"), "M5 aucun avertissement")
check(logCount("[ChaseFeel] [", "PRINT", "client") == 0, "M6 aucune erreur rattrapée")
summary("scénario missing")
