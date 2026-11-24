--!nocheck
-- L. Latence simulée, sanctions actives : positions en retard, en rafale, livrées par paquets, réseau
-- gelé plusieurs secondes puis rattrapé, serveur qui rame (une image de 2 s), positions périmées après
-- un déplacement fait par le serveur (le client les envoie encore) : aucun faux positif à 70. Et la
-- triche reste vue malgré la latence.

startServer()
setStrict(true)
local fast = newProfile()
fast.Stats.Speed = 2000 -- WalkSpeed 70
fast.Stats.Strength = 10000
local A = join("Alice", fast)
local slow = join("Bob", newProfile()) -- WalkSpeed 16
advance(1)
local function run(player, seconds)
	local points = { Vector3.new(640, 3, 0), Vector3.new(60, 3, 0) }
	local i = 0
	local t0 = now()
	while now() - t0 < seconds do
		i += 1
		walk(player, points[(i - 1) % 2 + 1])
		arrive(player, seconds - (now() - t0))
	end
	stop(player)
end
place(A, Vector3.new(60, 3, 0))
place(slow, Vector3.new(60, 3, 20))
settle()

section("L1 Latence constante : 150 ms aller (300 ms de ping)")
NET.oneWay = 0.15
PING[A] = 0.3
run(A, 20)
check(strikes(A) == 0, "L1a 20 s à 70 : rien")

section("L2 Gigue : 400 ms de retard en plus une demi-seconde sur deux (rafales)")
NET.extra = function(t)
	return if math.floor(t / 0.5) % 2 == 0 then 0.4 else 0
end
run(A, 20)
check(strikes(A) == 0, "L2a 20 s à 70 : rien")
NET.extra = function(t)
	-- retard qui varie de 0 à 0,9 s, irrégulier
	return 0.45 + 0.45 * math.sin(t * 7.3) * math.cos(t * 2.1)
end
run(A, 20)
check(strikes(A) == 0, "L2b 20 s à 70, retard de 0 à 0,9 s : rien")
NET.extra = nil

section("L3 Positions livrées par paquets (toutes les 0,5 s, puis toutes les 1,2 s)")
NET.batch = 0.5
run(A, 15)
check(strikes(A) == 0, "L3a toutes les 0,5 s : rien")
NET.batch = 1.2
run(A, 15)
check(strikes(A) == 0, "L3b toutes les 1,2 s (84 studs d'un coup) : rien")
NET.batch = nil

section("L4 Réseau gelé puis rattrapé (positions figées, vitesse répliquée intacte)")
for _, freeze in { 1.5, 2.5, 4 } do
	walk(A, Vector3.new(if rootOf(A).Position.X < 300 then 640 else 60, 3, 0))
	advance(1)
	NET.freezeUntil = now() + freeze
	advance(freeze + 1)
	NET.freezeUntil = nil
	advance(1)
	check(strikes(A) == 0, `L4a gel de {freeze} s à 70 (jusqu'à {math.floor(70 * freeze)} studs d'un coup) : rien`)
end
stop(A)
walk(slow, Vector3.new(400, 3, 20))
advance(1)
NET.freezeUntil = now() + 3
advance(4)
NET.freezeUntil = nil
advance(1)
stop(slow)
check(strikes(slow) == 0, "L4b gel de 3 s à 16 : rien")

section("L5 Le serveur rame : une image de 2 s")
walk(A, Vector3.new(640, 3, 0))
advance(1)
advance(2, 2)
advance(1)
stop(A)
check(strikes(A) == 0, "L5a 140 studs en une image de 2 s : rien")

section("L6 Positions périmées après un déplacement du serveur (Retour base, 300 ms aller)")
NET.oneWay = 0.3
PING[A] = 0.6
place(A, Vector3.new(300, 3, 0))
settle()
walk(A, Vector3.new(640, 3, 0))
advance(1)
fireAs(A, "ReturnToBase") -- le serveur le pose chez lui ; le client court encore vers x = 640
local closest = math.huge
for _ = 1, 120 do
	advance(FRAME)
	closest = math.min(closest, horizontal(rootOf(A).Position, SHOPS[1].S.spawn))
end
stop(A)
check(closest < 5, `L6a il a bien été posé chez lui (à une image près, puis il repart en courant de là ; {string.format("%.1f", closest)} stud)`)
check(strikes(A) == 0, "L6b les positions d'avant (encore en route 600 ms) ne comptent pas : rien")
PING[A] = 0 -- ping inconnu : la marge de base suffit
place(A, Vector3.new(300, 3, 0))
settle()
walk(A, Vector3.new(640, 3, 0))
advance(1)
Plot.TeleportHome(A)
advance(4)
stop(A)
check(strikes(A) == 0, "L6c même sans ping connu (AllowSettle seul) : rien")
NET.oneWay = 0

section("L7 La triche reste vue malgré la latence (150 ms aller, gigue)")
NET.oneWay = 0.15
NET.extra = function(t)
	return if math.floor(t / 0.5) % 2 == 0 then 0.3 else 0
end
place(slow, Vector3.new(100, 3, 20))
settle()
local s0 = strikes(slow)
cheatTeleport(slow, Vector3.new(400, 3, 20))
advance(1.5)
check(strikes(slow) == s0 + 1 and lastDetection().Kind == "Teleport", "L7a téléport de 300 studs : détecté")
check(horizontal(clientPos(slow), Vector3.new(100, 3, 20)) < 2, "L7a2 le client a reçu le retour en arrière")
advance(3)
check(strikes(slow) == s0 + 1, "L7a3 une seule détection : les positions d'avant, encore en route après le retour, ne comptent pas")
-- Un tricheur qui refuse le retour (il remet sa position téléportée) est de nouveau détecté.
cheatTeleport(slow, Vector3.new(400, 3, 20))
advance(0.5)
CLIENT[slow].pos = Vector3.new(400, 3, 20) -- refuse le retour
advance(FRAME)
for _ = 1, 20 do
	CLIENT[slow].pos = Vector3.new(400, 3, 20)
	advance(0.1)
end
check(strikes(slow) >= s0 + 3, `L7a4 il refuse le retour : détecté encore à la fin de la retenue ({strikes(slow) - s0} détections)`)
place(slow, Vector3.new(100, 3, 20))
settle()
advance(2)
s0 = strikes(slow)
walk(slow, Vector3.new(700, 3, 20))
setHack(slow, 2.5)
local found = false
for _ = 1, 300 do
	advance(FRAME)
	if strikes(slow) > s0 then
		found = true
		break
	end
end
setHack(slow, 1)
stop(slow)
check(found and lastDetection().Kind == "Speed", "L7b speed hack × 2,5 : détecté en moins de 10 s")
NET.oneWay = 0
NET.extra = nil

section("L8 Déplacement du serveur reçu très en retard (arrivée en jeu, Play du 2026-11-09 : 201 studs)")
-- 2,5 s aller sans ping connu : l'Allow (1,5 s) finit bien avant que le client reçoive le placement ;
-- le serveur voit encore ses positions d'avant, puis d'un coup sa parcelle.
place(A, Vector3.new(300, 3, 0))
settle()
advance(2)
local l8 = strikes(A)
NET.oneWay = 2.5
PING[A] = 0
walk(A, Vector3.new(640, 3, 0))
advance(1)
Plot.TeleportHome(A)
local l8home = math.huge
for _ = 1, math.floor(8 / FRAME) do
	advance(FRAME)
	l8home = math.min(l8home, horizontal(rootOf(A).Position, SHOPS[1].S.spawn))
end
check(strikes(A) == l8, `L8a le placement arrive 5 s après chez le serveur : rien ({strikes(A) - l8} détection(s))`)
check(l8home < 5, `L8b le serveur l'a bien vu chez lui ({string.format("%.1f", l8home)} stud)`)
-- L'exception ne sert qu'une fois : un vrai téléport juste après (latence toujours de 2,5 s) est vu.
local l8c = strikes(A)
cheatTeleport(A, Vector3.new(500, 3, 0))
advance(5.5)
check(strikes(A) > l8c and lastDetection().Kind == "Teleport", "L8c un téléport du tricheur juste après : détecté")
stop(A)
NET.oneWay = 0

section("L9 Fenêtre Allow ouverte AVANT la prise : le trajet depuis la prise est contrôlé (audit 2026-11-10)")
place(A, Vector3.new(100, 3, 0)) -- Allow (comme monter sur son tapis)
local l9from, l9since = rootOf(A).Position, now() -- « prise » d'un colis, fenêtre encore ouverte
cheatTeleport(A, Vector3.new(600, 3, 0)) -- puis téléport en zone safe, toujours dans la fenêtre
advance(0.3)
check(AC.Verify(A, l9from, l9since) == false, "L9a 500 studs en 0,3 s depuis la prise : refusé malgré la fenêtre Allow")
settle()

summary("scénario lag")
