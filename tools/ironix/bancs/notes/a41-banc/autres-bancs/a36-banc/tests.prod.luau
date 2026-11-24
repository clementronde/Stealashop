--!nocheck
-- R. Serveur hors Studio (pre.prod.luau) : les sanctions sont actives sans aucun attribut ; aucune
-- ligne de mode Studio ; l'attribut AntiCheatStrict n'y change rien.

startServer()
local strong = newProfile()
strong.Stats.Strength = 10000
local A = join("Alice", strong)
advance(1)

section("R0 Démarrage")
check(not logHas("[AntiCheatService] contrôle des déplacements", "PRINT"), "R0a pas de ligne de mode Studio")
check(Workspace:GetAttribute("AntiCheatStrict") == nil, "R0b aucun attribut posé")

section("R1 Téléport en portant : sanction")
local before = landedCount(STORE_A)
heist(A, STORE_A, Vector3.new(130, 3, 0))
settle()
local from = rootOf(A).Position
cheatTeleport(A, SHOPS[1].S.center)
advance(0.4)
local d = lastDetection()
check(d and d.Kind == "Teleport" and d.Sanctioned == true, "R1a détection sanctionnée")
check(not Carry.IsCarrying(A), "R1b colis rendu")
check(horizontal(rootOf(A).Position, from) < 2, "R1c retour en arrière")
advance(3)
check(landedCount(STORE_A) == before, "R1d le colis a revolé sur son rayon")

section("R2 AntiCheatStrict = false n'arrête rien hors de Studio")
Workspace:SetAttribute("AntiCheatStrict", false)
place(A, Vector3.new(100, 3, 0))
settle()
cheatTeleport(A, Vector3.new(400, 3, 0))
advance(0.4)
d = lastDetection()
check(d.Sanctioned == true and horizontal(rootOf(A).Position, Vector3.new(100, 3, 0)) < 2, "R2a toujours sanctionné")

section("R3 Speed hack : sanction")
place(A, Vector3.new(100, 3, 0))
settle()
local s0 = strikes(A)
walk(A, Vector3.new(700, 3, 0))
setHack(A, 2)
for _ = 1, 300 do
	advance(FRAME)
	if strikes(A) > s0 then
		break
	end
end
setHack(A, 1)
stop(A)
d = lastDetection()
check(strikes(A) == s0 + 1 and d.Kind == "Speed" and d.Sanctioned, "R3a « Speed », sanctionné")
check(rootOf(A).Position.X < 130, `R3b ramenée près du départ (x {string.format("%.0f", rootOf(A).Position.X)})`)

summary("scénario prod")
