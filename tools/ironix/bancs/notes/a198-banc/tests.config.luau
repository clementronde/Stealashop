--!nocheck
-- Banc a198 (vague 61) : vitesse réelle × Balance.Stats.RealSpeedScale (k) et zone 1 à 15 PV, dans les vraies
-- tables de src/shared/Config (chargeur du simulateur). Lancé deux fois par run.sh : arbre tel quel (k = 2) et
-- copie à k = 1 (tout comme avant).
local checks, fails = 0, 0
local function ok(condition, label)
	checks += 1
	if not condition then
		fails += 1
		print("ÉCHEC : " .. label)
	end
end
local function near(value, expected, tolerance, label)
	ok(type(value) == "number" and math.abs(value - expected) <= tolerance, `{label} : {tostring(value)} au lieu de {expected}`)
end

local Balance, Formulas, Zones = Config.Balance, Config.Formulas, Config.Zones
local Chase, Night, Bot, TruckEvent, AntiCheat, Tutorial = Config.Chase, Config.Night, Config.Bot, Config.TruckEvent, Config.AntiCheat, Config.Tutorial
local K = Balance.Stats.RealSpeedScale
ok(K == EXPECTED_K, `K1 RealSpeedScale = {EXPECTED_K} (lu {tostring(K)})`)

-- 1. Marche réelle = k × la formule d'avant ; Speed affichée inchangée.
local function old(shown)
	return math.min(70, 16 + 4 * math.log10(1 + shown / 100))
end
for _, s in { 0, 100, 1000, 3000, 1e5, 3e6, 1e8, 3e9, 1e13, 1e20 } do
	near(Formulas.WalkSpeed(s), K * old(s), 1e-9, `W1 marche à Speed {s}`)
	near(Formulas.WalkSpeed(s / 2, 2), K * old(s), 1e-9, `W2 marche à Speed {s / 2} avec un trail ×2`)
	ok(Formulas.ShownSpeed(s, 1) == s, `W3 Speed affichée {s} inchangée`)
end
near(Formulas.WalkSpeed(0), 16 * K, 1e-9, "W4 base")
near(Formulas.WalkSpeed(1e30), 70 * K, 1e-9, "W5 plafond")
near(Formulas.MaxWalkSpeed(), 70 * K, 1e-9, "W6 Formulas.MaxWalkSpeed")
-- Cantin : « 1000 de speed » donne k × 20,2.
near(Formulas.WalkSpeed(1000), K * 20.17, 0.01 * K, "W7 Speed 1000")

-- 2. Zones : seuils de Speed inchangés, marche conseillée et vigiles × k, PV de la zone 1 à 15.
local required = { 0, 3000, 100000, 3000000, 100000000, 3000000000 }
local guards = { 13.4, 20.8, 26.2, 31.5, 37, 42.3 }
local hp = { 15, 272, 3264, 40795, 543933, 108786611 }
for z = 1, 6 do
	ok(Zones[z].SpeedRequired == required[z], `Z1 zone {z} : SpeedRequired {required[z]}`)
	near(Zones[z].AdvisedSpeed, K * old(required[z]), 1e-9, `Z2 zone {z} : AdvisedSpeed`)
	near(Zones[z].AdvisedSpeed, Formulas.WalkSpeed(required[z]), 1e-9, `Z3 zone {z} : AdvisedSpeed = Formulas.WalkSpeed`)
	near(Zones[z].GuardSpeed, K * guards[z], 1e-9, `Z4 zone {z} : GuardSpeed {K * guards[z]}`)
	ok(Zones[z].WindowHP == hp[z], `Z5 zone {z} : WindowHP {hp[z]} (lu {Zones[z].WindowHP})`)
end
-- Zone 1 : 15 coups avec les poings (1 dégât) ; 3,3 s au plafond, régénération comprise.
ok(Config.Tools.ById.Fists.Power == 1 and Zones[1].AdvisedDamage == 1, "Z6 zone 1 : poings à 1 dégât")
local regen = Balance.Window.RegenPerSecond * Zones[1].WindowHP
local seconds = Zones[1].WindowHP / (Balance.Hit.MaxHitsPerSecond - regen)
ok(seconds < Balance.Window.BreakTimer, `Z7 zone 1 cassée dans le chrono de police ({string.format("%.2f", seconds)} s)`)

-- 3. Poursuivants.
near(Chase.RushMinSpeed, 78 * K, 1e-9, "C1 RushMinSpeed")
near(Chase.ClosingSpeedMax, 8 * K, 1e-9, "C2 ClosingSpeedMax")
near(Chase.HoldMinSpeed, 12 * K, 1e-9, "C3 HoldMinSpeed")
near(Chase.RushBrake, 250 * K * K, 1e-9, "C4 RushBrake × k²")
near(Chase.HoldRecallMax, 4 * K, 1e-9, "C5 HoldRecallMax")
near(Chase.DriverGrowthPerSecond, 0.02 * K, 1e-12, "C6 DriverGrowthPerSecond")
ok(Chase.HoldDistance == 14 and Chase.LagMaxStuds == 8 and Chase.LagContactReach == 3 and Chase.HoldRecallGain == 2, "C7 distances et rappel inchangés")
ok(Chase.RushWalkFactor == 3.9 and Chase.NightGuardRequiredFactor == 2 and Chase.DriverMaxFactor == 2, "C8 rapports inchangés")
near(Night.ChaseSpeed, 80 * K, 1e-9, "N1 Night.ChaseSpeed")
near(Night.ChaseSpeedBonus, 4 * K, 1e-9, "N2 Night.ChaseSpeedBonus")
near(Night.GaitSpeedMax, 4 * K, 1e-9, "N3 Night.GaitSpeedMax")
ok(Night.PatrolSpeed == 10 and Night.DetectionRange == 40, "N4 ronde et portée inchangées")
near(Bot.Defense.RunSpeed, 13.4 * K, 1e-9, "B1 bot")
near(Bot.Defense.TutorialRunSpeed, Tutorial.GuardSpeed * K, 1e-9, "B2 bot pendant le tuto")
near(TruckEvent.DriverMinSpeed, 20 * K, 1e-9, "T1 conducteur, plancher")
near(Balance.Carry.StolenItemWalkSpeed, 16 * K, 1e-9, "P1 objet volé : vitesse fixe")
near(AntiCheat.MinSpeed, 10 * K, 1e-9, "A1 anti-triche, plancher")
ok(AntiCheat.SpeedTolerance == 1.25 and AntiCheat.TeleportDistance == 30 and AntiCheat.StaleSpeed == 2, "A2 tolérances inchangées")
-- Un porteur d'objet volé (vitesse fixe) reste au-dessus du plancher, et un joueur légal au plafond
-- (140 à × 2) est sous un ×1,25 de sa propre vitesse : le contrôle suit la Humanoid.WalkSpeed.
ok(AntiCheat.MinSpeed < Balance.Carry.StolenItemWalkSpeed, "A3 plancher sous la marche d'un porteur")

-- 4. Proportions gardées : au seuil du panneau, le vigile reprend k studs/s au porteur (colis −10 %).
for z = 2, 6 do
	local carry = Zones[z].AdvisedSpeed * Balance.Carry.NPCBoxSpeedMultiplier
	near(Zones[z].GuardSpeed - carry, K * 1, 0.06 * K, `R1 zone {z} : écart vigile − porteur = k`)
end
print(`banc a198 config (k = {K}) : {checks} vérification(s), {fails} échec(s)`)
