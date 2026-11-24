--!nocheck
-- F. Vol (a146, audit du 2026-11-14) : plus de FlyHeight studs au-dessus du sol pendant FlyTime s sans
-- tomber = détection « Fly » (ligne ; avec AntiCheatStrict : portage rendu, retour au dernier point au sol).
-- Saut haut, chute de très haut, réseau figé en l'air, tour haute : aucune détection.

startServer()
local strong = newProfile()
strong.Stats.Strength = 10000
local B = join("Bob", strong)
advance(1)
local FLY_TIME = Config.FlyTime
local STILL_TIME = Config.FlyTime + Config.StaleMax -- immobile : le compte attend StaleMax s (réseau figé ?)
local function setY(player, y)
	local c = CLIENT[player]
	c.pos = Vector3.new(c.pos.X, y, c.pos.Z)
end
-- Chute libre côté client (g = 196,2) jusqu'au sol (y = 3), au plus `limit` s ; renvoie la durée.
local function fall(player, limit)
	local c = CLIENT[player]
	local vy, t = 0, 0
	while c.pos.Y > 3 and t < (limit or 10) do
		vy -= 196.2 * FRAME
		setY(player, math.max(3, c.pos.Y + vy * FRAME))
		advance(FRAME)
		t += FRAME
	end
	return t
end
local GROUND = Vector3.new(150, 3, 0) -- sur la chaussée (dessus à y = 0)

section("F1 Immobile en l'air (AntiCheatStrict) : détection « Fly » après FlyTime + StaleMax s, retour au sol")
setStrict(true)
place(B, GROUND)
settle()
local s0 = strikes(B)
cheatTeleport(B, Vector3.new(150, 40, 0)) -- droit vers le haut : aucun déplacement à l'horizontale
local t0 = now()
local seen
for _ = 1, 240 do
	advance(FRAME)
	if strikes(B) > s0 then
		seen = now() - t0
		break
	end
end
local d = lastDetection()
check(seen ~= nil and d.Kind == "Fly" and d.Sanctioned, `F1a détection « Fly » sanctionnée ({d and d.Kind}, {d and d.Detail})`)
check(seen ~= nil and seen >= STILL_TIME - 0.05 and seen <= STILL_TIME + 0.6, `F1b vue après {STILL_TIME} s environ (vue après {seen})`)
advance(0.3)
check(math.abs(rootOf(B).Position.Y - 3) < 0.5 and horizontal(rootOf(B).Position, GROUND) < 1, `F1c revenu au dernier point au sol (y = {rootOf(B).Position.Y})`)
check(logHas("en l'air depuis", "WARN", "server"), "F1d ligne « en l'air » dans la sortie")
advance(3)
check(strikes(B) == s0 + 1, "F1e une seule détection (revenu au sol)")
place(B, GROUND)
settle()

section("F1' Vole en avançant (8 studs/s à 40 studs de haut) : détection après FlyTime s")
s0 = strikes(B)
cheatTeleport(B, Vector3.new(150, 40, 0))
walk(B, Vector3.new(250, 40, 0), 8)
t0 = now()
seen = nil
for _ = 1, 120 do
	advance(FRAME)
	if strikes(B) > s0 then
		seen = now() - t0
		break
	end
end
stop(B)
d = lastDetection()
check(seen ~= nil and d.Kind == "Fly" and seen >= FLY_TIME - 0.05 and seen <= FLY_TIME + 0.6, `F1'a « Fly » après {FLY_TIME} s environ (vue après {seen})`)
advance(0.3)
check(math.abs(rootOf(B).Position.Y - 3) < 0.5 and horizontal(rootOf(B).Position, GROUND) < 1, "F1'b revenu au dernier point au sol")
place(B, GROUND)
settle()

section("F2 Saut très haut (pieds à 14 studs) pendant 1 s : rien")
s0 = strikes(B)
setY(B, 3 + 14)
advance(1.0)
setY(B, 3)
advance(2)
check(strikes(B) == s0, "F2a aucune détection")

section("F3 Chute libre de 300 studs (1,7 s) : rien")
place(B, Vector3.new(150, 300, 0))
settle() -- l'autorisation du placement est finie : le compte « en l'air » démarre
s0 = strikes(B)
local took = fall(B)
advance(2)
check(took > FLY_TIME and strikes(B) == s0, `F3a chute de {took} s : aucune détection`)

section("F4 Réseau figé 2,5 s pendant une chute de 300 studs : rien")
place(B, Vector3.new(150, 300, 0))
settle()
s0 = strikes(B)
NET.freezeUntil = now() + 2.5
fall(B, 2.5)
advance(math.max(0, NET.freezeUntil - now()) + 0.2)
NET.freezeUntil = nil
advance(2)
check(strikes(B) == s0, "F4a aucune détection (le compte attend tant que rien ne bouge)")

section("F5 En haut d'une tour de 40 studs : rien")
make("Part", { Name = "Tower", Anchored = true, Size = Vector3.new(6, 40, 6), CFrame = CFrame.new(170, 20, 0) }, MAP)
place(B, Vector3.new(170, 43, 0))
settle()
s0 = strikes(B)
advance(4)
check(strikes(B) == s0, "F5a aucune détection")

section("F6 Descente lente (2 studs/s) de 60 studs, en Studio sans AntiCheatStrict : détection seule")
setStrict(false)
place(B, Vector3.new(150, 60, 0))
settle()
s0 = strikes(B)
for _ = 1, 90 do
	setY(B, CLIENT[B].pos.Y - 2 * FRAME)
	advance(FRAME)
	if strikes(B) > s0 then
		break
	end
end
d = lastDetection()
check(strikes(B) == s0 + 1 and d.Kind == "Fly" and d.Sanctioned == false, `F6a détection « Fly » non sanctionnée ({d and d.Kind})`)
check(rootOf(B).Position.Y > 40, "F6b pas de retour en arrière en Studio sans AntiCheatStrict")
place(B, GROUND)
settle()

section("F7 Porteur d'un colis en l'air (AntiCheatStrict) : colis rendu")
setStrict(true)
local box = heist(B, STORE_A, Vector3.new(150, 3, 10))
check(box ~= nil and Carry.IsCarrying(B), "F7a Bob porte un colis")
settle()
s0 = strikes(B)
cheatTeleport(B, Vector3.new(150, 30, 10))
for _ = 1, 200 do
	advance(FRAME)
	if strikes(B) > s0 then
		break
	end
end
d = lastDetection()
check(strikes(B) == s0 + 1 and d.Kind == "Fly" and d.Carrying, "F7b détection « Fly » en portant")
check(not Carry.IsCarrying(B), "F7c le colis lui est retiré")

summary("scénario fly")
