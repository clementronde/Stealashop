--!nocheck
-- O. Interrupteur coupé (pre.off.luau : Features.AntiCheat = false) : aucun contrôle, Allow et Verify ne
-- font rien, aucune détection ni attribut ; les services qui appellent Allow marchent comme avant.

startServer()
setStrict(true)
local strong = newProfile()
strong.Stats.Strength = 10000
local A = join("Alice", strong)
advance(1)

section("O0 Démarrage")
check(sharedModule("Config/Features").AntiCheat == false, "O0a Features.AntiCheat = false")
check(logHas("[AntiCheatService] coupé (Features.AntiCheat = false)", "PRINT", "server"), "O0b ligne « coupé »")

section("O1 Téléport et speed hack en portant : rien")
local box = heist(A, STORE_A, Vector3.new(130, 3, 0))
settle()
cheatTeleport(A, Vector3.new(400, 3, 0))
advance(1)
walk(A, Vector3.new(700, 3, 0))
setHack(A, 3)
advance(5)
setHack(A, 1)
stop(A)
check(Carry.IsCarrying(A) and Carry.GetPayload(A) == box, "O1a colis gardé")
check(strikes(A) == 0 and #AC.GetLog() == 0 and A:GetAttribute("AntiCheatStrikes") == nil, "O1b aucune détection, aucun attribut")
check(AC.Verify(A) == true, "O1c Verify rend true")
Carry.Fail(A, "banc")
advance(2)

section("O2 Les déplacements du code marchent sans lui")
place(A, Vector3.new(300, 3, 0))
fireAs(A, "ReturnToBase")
advance(1)
check(horizontal(rootOf(A).Position, SHOPS[1].S.spawn) < 1, "O2a Retour base : chez elle")
check(not logHas("[AntiCheatService] Allow", "WARN"), "O2b Allow ne dit rien")

summary("scénario off")
