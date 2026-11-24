--!nocheck
-- D. Détection (9.6), sanctions actives (Studio + AntiCheatStrict) : speed hack et téléport pendant un
-- portage → colis rendu (il revole vers son rayon), retour à la dernière position valide, récidive
-- comptée, journal, OnDetection, ligne dans la sortie ; sans portage : retour seul ; chutes et sauts
-- ignorés ; triche sous la tolérance de 1,25 jamais vue (V0 prudente).

startServer()
setStrict(true)
local events = {}
AC.OnDetection(function(player, detection)
	table.insert(events, { player = player, detection = detection })
end)
local strong = newProfile()
strong.Stats.Strength = 10000 -- 101 de dégâts : une vitrine de zone 1 en un coup
local A = join("Alice", strong)
advance(1)

section("D0 Arrivée")
check(Plot.GetPlot(A) ~= nil, "D0a Alice a une boutique")
check(horizontal(rootOf(A).Position, SHOPS[1].S.spawn) < 1, "D0b PlotService l'a posée sur sa parcelle")
check(strikes(A) == 0 and detections() == 0, "D0c aucune détection : apparition, puis placement sur sa parcelle")

section("D1 Speed hack (× 2) avec un colis")
local before = landedCount(STORE_A)
local box = heist(A, STORE_A, Vector3.new(65, 3, 10))
check(box ~= nil and box.Kind == "NPCBox", "D1a Alice porte un colis du magasin")
check(landedCount(STORE_A) == before - 1, "D1b le rayon a un colis de moins")
settle()
check(strikes(A) == 0, "D1c pas de détection en sortant du magasin à pied")
local walkSpeed = humanoidOf(A).WalkSpeed
check(near(walkSpeed, 16 * 0.9, 1e-3), `D1d WalkSpeed avec le colis : 14,4 (lu {walkSpeed})`)
walk(A, Vector3.new(600, 3, 10))
setHack(A, 2)
local t0 = now()
local caughtAt
for _ = 1, 300 do
	advance(FRAME)
	if strikes(A) > 0 then
		caughtAt = now()
		break
	end
end
check(caughtAt ~= nil and caughtAt - t0 < 4, `D1e détecté en {caughtAt and string.format("%.1f", caughtAt - t0) or "?"} s (moins de 4)`)
local d = lastDetection()
check(d and d.Kind == "Speed" and d.Carrying == true and d.Sanctioned == true, "D1f détection « Speed », en portant, sanctionnée")
check(not Carry.IsCarrying(A), "D1g le colis lui est retiré (CarryService.ReportAnomaly)")
check(logHas("[AntiCheatService] Alice : trop rapide", "WARN", "server"), "D1h ligne d'avertissement « trop rapide »")
check(logHas("anomalie anti-triche de Alice", "WARN", "server"), "D1i et celle de CarryService.ReportAnomaly")
check(A:GetAttribute("AntiCheatStrikes") == 1, "D1j attribut AntiCheatStrikes = 1")
check(#events == 1 and events[1].player == A and events[1].detection.Kind == "Speed", "D1k OnDetection appelé une fois")
local hacked = clientPos(A).X
advance(FRAME * 2)
local back = rootOf(A).Position.X
-- Ramenée là où l'excès a commencé : à la sortie du magasin (x = 65), pas seulement d'un contrôle.
check(back < 80 and back < hacked - 50, `D1l retour à 15 studs au plus de là où la triche a commencé : x {string.format("%.1f", back)} (détectée en x {string.format("%.1f", hacked)}, partie de 65)`)
-- Il continue de tricher : il est ramené au même point encore et encore.
local x0 = back
local farthest = 0
for _ = 1, 300 do -- 10 s
	advance(FRAME)
	farthest = math.max(farthest, rootOf(A).Position.X - x0)
end
check(farthest < 90, `D1m en 10 s de triche, jamais plus de 90 studs au-delà du point de retour ({string.format("%.0f", farthest)})`)
check(rootOf(A).Position.X < x0 + 90, `D1n et il y est encore ramené (x {string.format("%.0f", rootOf(A).Position.X)})`)
check(landedCount(STORE_A) == before, "D1k2 le colis a revolé sur son rayon (StoreHeistService)")
check(strikes(A) >= 3, `D1o chaque récidive est comptée ({strikes(A)})`)
check(humanoidOf(A).Health > 0 and A.Parent == Players, "D1p jamais d'expulsion ni de mort")
setHack(A, 1)
stop(A)
advance(2)

section("D2 Téléport avec un colis")
local s0 = strikes(A)
before = landedCount(STORE_A)
box = heist(A, STORE_A, Vector3.new(130, 3, 0))
settle()
local from = rootOf(A).Position
cheatTeleport(A, SHOPS[1].S.center) -- droit chez lui, 200 studs plus loin
advance(0.4)
d = lastDetection()
check(strikes(A) == s0 + 1 and d.Kind == "Teleport", "D2a détection « Teleport » tout de suite")
check(string.find(d.Detail, "téléport de", 1, true) ~= nil, `D2b détail : {d.Detail}`)
check(not Carry.IsCarrying(A), "D2c le colis est rendu")
check(horizontal(rootOf(A).Position, from) < 2, `D2d remise à sa dernière position valide ({string.format("%.1f", horizontal(rootOf(A).Position, from))} stud de là)`)
check(horizontal(clientPos(A), from) < 2, "D2e le client l'a reçue aussi")
advance(3)
check(landedCount(STORE_A) == before, "D2f le colis a revolé sur son rayon")
advance(2)
check(strikes(A) == s0 + 1, "D2g une seule détection pour ce téléport (rien ensuite)")

section("D3 Téléport sans rien porter : retour seul")
s0 = strikes(A)
place(A, Vector3.new(120, 3, 0))
settle()
cheatTeleport(A, Vector3.new(400, 3, 0))
advance(0.4)
d = lastDetection()
check(strikes(A) == s0 + 1 and d.Kind == "Teleport" and d.Carrying == false and d.Sanctioned, "D3a détecté, sans portage")
check(horizontal(rootOf(A).Position, Vector3.new(120, 3, 0)) < 2, "D3b ramenée à 120")
check(logHas("retour à la dernière position valide", "WARN", "server"), "D3c ligne « retour à la dernière position valide »")

section("D4 Chutes et sauts : jamais rien")
s0 = strikes(A)
place(A, Vector3.new(300, 3, 0))
settle()
local c = CLIENT[A]
c.pos = Vector3.new(300, 250, 0) -- 247 studs plus haut (vu d'un coup)
advance(0.5)
for y = 250, 3, -15 do -- chute verticale rapide
	c.pos = Vector3.new(300, y, 0)
	advance(FRAME)
end
for _ = 1, 10 do -- sauts sur place, en marchant
	walk(A, Vector3.new(330, 3, 0))
	c.pos = Vector3.new(c.pos.X, 10, c.pos.Z)
	advance(0.2)
	c.pos = Vector3.new(c.pos.X, 3, c.pos.Z)
	advance(0.2)
end
check(strikes(A) == s0, "D4a aucune détection (seul l'horizontal compte)")

section("D5 Sous la tolérance (× 1,2) : laissé passer")
s0 = strikes(A)
stop(A)
place(A, Vector3.new(120, 3, -10))
settle()
walk(A, Vector3.new(700, 3, -10))
setHack(A, 1.2)
advance(20)
check(strikes(A) == s0, "D5a 20 s à 1,2 × sa vitesse : rien (V0 : la tolérance de 9.6 est de 1,25)")
setHack(A, 1.6)
local found = false
for _ = 1, 400 do
	advance(FRAME)
	if strikes(A) > s0 then
		found = true
		break
	end
end
check(found, "D5b à 1,6 × : détecté")
setHack(A, 1)
stop(A)

section("D6 Journal")
local log = AC.GetLog()
check(#log == strikes(A), `D6a une entrée par détection ({#log})`)
local entry = log[1]
check(entry.UserId == A.UserId and entry.Name == "Alice" and type(entry.At) == "number" and entry.Strikes == 1, "D6b UserId, nom, heure, rang")
check(table.isfrozen(entry), "D6c entrée figée")
local copy = AC.GetLog()
table.remove(copy, 1)
check(#AC.GetLog() == #log, "D6d GetLog rend une copie")

summary("scénario detect")
