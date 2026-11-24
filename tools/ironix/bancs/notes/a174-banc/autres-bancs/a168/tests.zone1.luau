--!nocheck
-- a174 (2026-11-15, vague 54) : distance gardée Chase.HoldDistance (14) ± 0,5, ruée max(RushMinSpeed, RushWalkFactor × la marche), touché vers 2,5 s.
-- a153 : zone 1 sans minimum (V0) ; puis le tutoriel (GetSpeedOverride) garde l'ancienne règle.
startBanc()
check(ChaseCfg.Zone1SpeedRequired == 0 and ZonesCfg[1].SpeedRequired == 0, "Z0 zone 1 sans minimum")
section("Z1 Joueur neuf (Speed 0) en zone 1 : ruée, puis distance constante")
local P = thief(0)
check(heistAndRun(P, STORE_A), "Z1a le vigile poursuit")
local r = watch(P, 13)
report("zone 1", r)
check(r.maxSpeed >= ChaseCfg.RushMinSpeed - 0.01, "Z1b ruée à 78 studs/s au moins (" .. fmt(r.maxSpeed) .. ")")
check(r.switchD ~= nil and near(r.switchD, ChaseCfg.HoldDistance, 0.5), "Z1c fin de la ruée vers 14 studs (" .. fmt(r.switchD) .. ")")
check(r.caughtT == nil, "Z1d pas attrapé en courant tout droit")
if r.switchT then
	local s = spread(r, r.switchT + 1, r.switchT + 10)
	check(s < 0.5, "Z1e distance constante sur 9 s (écart " .. fmt(s) .. ")")
end
-- Il s'arrête : le vigile gagne du terrain et l'attrape.
local n = #CATCHES
stop(P)
advance(3)
check(#CATCHES > n, "Z1f arrêté, il est attrapé")
advance(4)

section("Z2 Tutoriel : vitesse imposée (GetSpeedOverride = 12), ni ruée ni nouvelle règle")
Guard.GetSpeedOverride = function(_player, _zone)
	return 12
end
local T = thief(0)
check(heistAndRun(T, STORE_B), "Z2a le vigile poursuit")
local rt = watch(T, 3)
check(near(rt.maxSpeed, 12, 0.01), "Z2b vigile à 12 studs/s, sans ruée (" .. fmt(rt.maxSpeed) .. ")")
endChase(T)
summary("scénario zone1")
