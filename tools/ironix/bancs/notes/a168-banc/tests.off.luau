--!nocheck
-- a153 : Features.GuardChaseV2 = false (pre.off.luau) : l'ancienne vitesse.
startBanc()
check(sharedModule("Config/Features").GuardChaseV2 == false, "O0 règle coupée")
local P = thief(100000)
check(heistAndRun(P, STORE_A), "O1a le vigile poursuit")
local r = watch(P, 4)
check(near(r.maxSpeed, ZonesCfg[1].GuardSpeed, 0.01), "O1b vigile à Zones[1].GuardSpeed = " .. ZonesCfg[1].GuardSpeed .. ", sans ruée (" .. fmt(r.maxSpeed) .. ")")
endChase(P)
summary("scénario off")
