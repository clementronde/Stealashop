--!nocheck
-- a174 (2026-11-15, vague 54) : distance gardée Chase.HoldDistance (14) ± 0,5, ruée max(RushMinSpeed, RushWalkFactor × la marche), touché vers 2,5 s.
-- a173 (2026-11-15) : S1g et S1h : la marche du serveur ± Chase.HoldRecallMax (rappel vers la distance prévue).
-- a153 : zone 1 avec un minimum de 100K (pre.store.luau). r = Speed effective / 100K.
startBanc()
local stores = { STORE_A, STORE_B }
local turn = 0
local function nextStore()
	turn += 1
	if turn > 2 then
		advance(25) -- les vigiles d'avant sont rentrés
	end
	return stores[(turn - 1) % 2 + 1]
end
check(ChaseCfg.Zone1SpeedRequired == 100000, "S0 minimum de la zone 1 patché à 100K")

section("S1 100 % du minimum : ruée jusqu'à 14 studs, puis distance constante sur 10 s")
local P1 = thief(100000)
check(heistAndRun(P1, nextStore()), "S1a le vigile poursuit")
local r1 = watch(P1, 14)
report("100 %", r1)
local walk1 = humanoidOf(P1).WalkSpeed
check(r1.maxSpeed >= ChaseCfg.RushMinSpeed and near(r1.maxSpeed, math.max(ChaseCfg.RushMinSpeed, ChaseCfg.RushWalkFactor * walk1), 0.1), "S1b ruée à max(78, 3,9 × " .. fmt(walk1) .. ") (vu " .. fmt(r1.maxSpeed) .. ")")
check(r1.switchD ~= nil and near(r1.switchD, ChaseCfg.HoldDistance, 0.5), "S1c fin de la ruée vers 14 studs (" .. fmt(r1.switchD) .. ")")
check(r1.caughtT == nil, "S1d pas attrapé")
if r1.switchT then
	local s = spread(r1, r1.switchT + 1, r1.switchT + 11)
	print("  mesure 100 % : écart de distance " .. fmt(s) .. " studs sur 10 s, distance finale " .. fmt(distanceAt(r1, r1.switchT + 11)))
	check(s < 0.5, "S1e distance constante sur 10 s (écart " .. fmt(s) .. ")")
	local last = sampleAt(r1, r1.switchT + 10)
	check(last and near(last.ws, last.walk, 0.06), "S1f vigile à la marche du voleur (" .. fmt(last and last.ws) .. " / " .. fmt(last and last.walk) .. ")")
end
-- La vitesse vient du serveur : un modificateur de StatsService change la marche, le vigile suit aussitôt.
Stats.SetSpeedModifier(P1, "BancA153", 0.8)
advance(0.2)
local _, _, h1 = chaserOf(P1)
check(h1 and near(h1.WalkSpeed, humanoidOf(P1).WalkSpeed, ChaseCfg.HoldRecallMax + 0.06), "S1g modificateur serveur ×0,8 : le vigile suit (" .. fmt(h1 and h1.WalkSpeed) .. " / " .. fmt(humanoidOf(P1).WalkSpeed) .. ")")
Stats.SetSpeedModifier(P1, "BancA153", nil)
advance(0.2)
-- Client truqué (×1,3 côté client) : le vigile garde la marche du serveur, pas la vitesse mesurée.
setHack(P1, 1.3)
advance(0.5)
local _, _, h1b = chaserOf(P1)
local measured = rootOf(P1).AssemblyLinearVelocity.Magnitude
check(h1b and near(h1b.WalkSpeed, humanoidOf(P1).WalkSpeed, ChaseCfg.HoldRecallMax + 0.06) and measured > humanoidOf(P1).WalkSpeed + 3,
	"S1h client ×1,3 : vigile " .. fmt(h1b and h1b.WalkSpeed) .. ", marche du serveur " .. fmt(humanoidOf(P1).WalkSpeed) .. ", vitesse mesurée " .. fmt(measured))
setHack(P1, 1)
endChase(P1)

section("S2 99 % : la distance baisse très lentement")
local P2 = thief(99000)
check(heistAndRun(P2, nextStore()), "S2a le vigile poursuit")
local r2 = watch(P2, 14)
report("99 %", r2)
check(r2.caughtT == nil, "S2b pas attrapé en 10 s")
if r2.switchT then
	local d1, d2 = distanceAt(r2, r2.switchT + 1), distanceAt(r2, r2.switchT + 11)
	print("  mesure 99 % : " .. fmt(d1) .. " → " .. fmt(d2) .. " studs en 10 s (attendu environ −0,8)")
	check(d1 and d2 and d1 - d2 > 0.4 and d1 - d2 < 1.5, "S2c baisse de 0,4 à 1,5 stud en 10 s (" .. fmt(d1 and d2 and d1 - d2) .. ")")
end
endChase(P2)

section("S3 50 % : touché en moins de 2 s après la ruée")
local P3 = thief(50000)
check(heistAndRun(P3, nextStore()), "S3a le vigile poursuit")
local r3 = watch(P3, 8)
report("50 %", r3)
check(r3.switchT ~= nil and near(r3.switchD, ChaseCfg.HoldDistance, 0.5), "S3b ruée jusqu'à 14 studs")
check(r3.caughtT ~= nil and r3.switchT ~= nil and r3.caughtT - r3.switchT < (ChaseCfg.HoldDistance - 4) / 4 + 0.5, "S3c touché " .. fmt(r3.caughtT and r3.switchT and r3.caughtT - r3.switchT) .. " s après la ruée")
stop(P3)
advance(4)

section("S4 200 %, AboveRequired = Hold : distance constante")
local P4 = thief(200000)
check(heistAndRun(P4, nextStore()), "S4a le vigile poursuit")
local r4 = watch(P4, 9)
report("200 % Hold", r4)
check(r4.caughtT == nil, "S4b pas attrapé")
if r4.switchT then
	local s = spread(r4, r4.switchT + 1, r4.switchT + 6)
	check(s < 0.5, "S4c distance constante sur 5 s (écart " .. fmt(s) .. ")")
end
endChase(P4)

section("S5 Trail ×2 : 50K de Speed brute = 100K effectifs, distance constante")
local P5 = thief(50000)
local baseTrail = Stats.GetTrailMultiplier
Stats.GetTrailMultiplier = function(player)
	if player == P5 then
		return 2
	end
	return baseTrail(player)
end
Stats.Refresh(P5)
check(P5:GetAttribute("ShownSpeed") == 100000, "S5a Speed effective 100K (" .. tostring(P5:GetAttribute("ShownSpeed")) .. ")")
check(heistAndRun(P5, nextStore()), "S5b le vigile poursuit")
local r5 = watch(P5, 9)
report("trail ×2", r5)
check(r5.caughtT == nil, "S5c pas attrapé (sans trail, 50 % : touché)")
if r5.switchT then
	local s = spread(r5, r5.switchT + 1, r5.switchT + 6)
	check(s < 0.5, "S5d distance constante sur 5 s (écart " .. fmt(s) .. ")")
end
endChase(P5)
Stats.GetTrailMultiplier = baseTrail

summary("scénario store")
