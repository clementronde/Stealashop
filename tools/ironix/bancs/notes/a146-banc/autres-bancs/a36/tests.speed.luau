--!nocheck
-- S. Jeu normal, sanctions actives : aucun faux positif à vitesse maximale (70), avec trail et
-- Adrénaline, en portant, étourdi puis relancé, en zigzag, en sautant, quand la vitesse baisse
-- (le client garde l'ancienne un moment : latence de 250 ms aller). Le client marche toujours à la
-- WalkSpeed qu'il a reçue du serveur (StatsService : formule 7.1, trail, modificateurs, plafond 70).

startServer()
setStrict(true)
local fast = newProfile()
fast.Stats.Speed = 1e30 -- 16 + 0,05 × 2000 = 116 : plafonné à 70
fast.Stats.Strength = 10000
local A = join("Alice", fast)
advance(1)

local function lap(player, seconds, points)
	local t = 0
	local i = 0
	while t < seconds do
		i += 1
		walk(player, points[(i - 1) % #points + 1])
		local start = now()
		arrive(player, seconds - t)
		t += now() - start
	end
	stop(player)
end
local corridor = { Vector3.new(60, 3, -15), Vector3.new(640, 3, -15), Vector3.new(640, 3, 15), Vector3.new(60, 3, 15) }

section("S1 Vitesse maximale (70)")
check(near(humanoidOf(A).WalkSpeed, 70, 1e-3), `S1a WalkSpeed 70 (lu {humanoidOf(A).WalkSpeed})`)
place(A, Vector3.new(60, 3, -15))
settle()
lap(A, 40, corridor)
check(strikes(A) == 0, "S1b 40 s de course à 70 dans le couloir : aucune détection")

section("S2 Trail × 1,8 et Adrénaline × 1,25")
fast.Stats.Speed = (1e9 - 1) * 100 / 1.8 -- a134 : marche en log : 16 + 4 × log10(1 + Vitesse × 1,8 / 100) = 52
Stats.GetTrailMultiplier = function()
	return 1.8
end
Stats.Refresh(A)
check(near(humanoidOf(A).WalkSpeed, 52, 1e-3), `S2a trail × 1,8 : marche 52 (lu {humanoidOf(A).WalkSpeed})`)
lap(A, 15, corridor)
Stats.SetSpeedModifier(A, "Adrenaline", 1.25)
check(near(humanoidOf(A).WalkSpeed, 65, 1e-3), `S2b Adrénaline : 65 (lu {humanoidOf(A).WalkSpeed})`)
lap(A, 15, corridor)
check(strikes(A) == 0, "S2c 30 s avec trail, puis trail + Adrénaline : aucune détection")

section("S3 Baisses de vitesse avec 250 ms de latence aller (le client garde l'ancienne)")
NET.oneWay = 0.25
PING[A] = 0.5
walk(A, Vector3.new(640, 3, 0))
advance(3)
Stats.SetSpeedModifier(A, "Adrenaline", nil) -- 65 → 52 en pleine course
advance(3)
Stats.SetSpeedModifier(A, "GuardStun", 0) -- étourdi : 0
advance(1.5)
Stats.SetSpeedModifier(A, "GuardStun", nil)
advance(3)
Stats.SetSpeedModifier(A, "Carry", 0.75) -- objet volé : 52 → 39
advance(3)
Stats.SetSpeedModifier(A, "Carry", nil)
fast.Stats.Speed = 1e30
Stats.Refresh(A) -- 70
advance(2)
Stats.GetTrailMultiplier = function()
	return 1
end
Stats.Refresh(A)
fast.Stats.Speed = 9999900 -- a134 : marche 36 sans trail
Stats.Refresh(A) -- 70 → 36 d'un coup (trail retiré, Vitesse baissée)
advance(3)
stop(A)
check(strikes(A) == 0, "S3a fin de l'Adrénaline, étourdissement, malus de portage, trail retiré : aucune détection")
-- Mauvais réseau mobile : 600 ms aller, la baisse 70 → 16 arrive 1,2 s après chez le serveur.
NET.oneWay = 0.6
PING[A] = 1.2
for _ = 1, 3 do
	fast.Stats.Speed = 1e30
	Stats.Refresh(A)
	walk(A, Vector3.new(640, 3, 0))
	advance(2)
	fast.Stats.Speed = 0
	Stats.Refresh(A) -- 70 → 16
	advance(2)
	walk(A, Vector3.new(60, 3, 0))
	advance(2)
end
stop(A)
check(strikes(A) == 0, "S3b 600 ms aller, trois chutes de 70 à 16 en pleine course : aucune détection")
NET.oneWay = 0
PING[A] = nil
advance(1)

section("S4 En portant un colis, à vitesse maximale")
fast.Stats.Speed = 1e30
Stats.Refresh(A)
local box = heist(A, STORE_A, Vector3.new(65, 3, 10))
check(box ~= nil and near(humanoidOf(A).WalkSpeed, 63, 1e-3), `S4a colis : 70 × 0,9 = 63 (lu {humanoidOf(A).WalkSpeed})`)
settle()
lap(A, 12, { Vector3.new(640, 3, 10), Vector3.new(100, 3, 10) })
check(Carry.IsCarrying(A) and strikes(A) == 0, "S4b 12 s de fuite à 63 : aucune détection, colis gardé")
Carry.Fail(A, "banc")
advance(2)

section("S5 Zigzag et sauts à 70")
place(A, Vector3.new(100, 3, 0))
settle()
local c = CLIENT[A]
for i = 1, 40 do
	walk(A, Vector3.new(100 + i * 12, 3, if i % 2 == 0 then 20 else -20))
	advance(0.35)
	c.pos = Vector3.new(c.pos.X, if i % 3 == 0 then 9 else 3, c.pos.Z) -- saut
end
stop(A)
check(strikes(A) == 0, "S5a 40 virages et des sauts : aucune détection")

section("S6 Marche lente (16) et arrêts")
fast.Stats.Speed = 0
Stats.Refresh(A)
check(near(humanoidOf(A).WalkSpeed, 16, 1e-3), "S6a WalkSpeed 16")
for i = 1, 10 do
	walk(A, Vector3.new(100 + i * 15, 3, 0))
	advance(1.2)
	stop(A)
	advance(0.5)
end
check(strikes(A) == 0, "S6b marches et arrêts à 16 : aucune détection")

summary("scénario speed")
