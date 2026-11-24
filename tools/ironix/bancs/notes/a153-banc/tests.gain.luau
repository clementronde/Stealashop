--!nocheck
-- a153 : minimum de 100K en zone 1, AboveRequired = "Gain" (pre.gain.luau).
startBanc()
check(ChaseCfg.AboveRequired == "Gain", "G0 AboveRequired patché à Gain")
section("G1 200 % en mode Gain : le voleur s'éloigne de 8 studs/s")
local P = thief(200000)
check(heistAndRun(P, STORE_A), "G1a le vigile poursuit")
local r = watch(P, 9)
report("200 % Gain", r)
check(r.caughtT == nil, "G1b pas attrapé")
if r.switchT then
	local d1, d2 = distanceAt(r, r.switchT + 1), distanceAt(r, r.switchT + 6)
	print("  mesure Gain : " .. fmt(d1) .. " → " .. fmt(d2) .. " studs en 5 s (attendu environ +40)")
	check(d1 and d2 and d2 - d1 > 30 and d2 - d1 < 50, "G1c il s'éloigne de 30 à 50 studs en 5 s (" .. fmt(d1 and d2 and d2 - d1) .. ")")
	local s = sampleAt(r, r.switchT + 3)
	check(s and near(s.ws, s.walk - 8, 0.06), "G1d vigile à la marche − 8 (" .. fmt(s and s.ws) .. " / " .. fmt(s and s.walk) .. ")")
else
	check(false, "G1c fin de ruée vue")
end
summary("scénario gain")
