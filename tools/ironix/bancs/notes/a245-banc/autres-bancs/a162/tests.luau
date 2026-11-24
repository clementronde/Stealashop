--!nocheck
advance(1000)
startServer()
local Codes = sharedModule("Config/Codes")
local ada = join("Ada", newProfile8(), 61)
advance(1.5)

section("valid")
redeem(ada, "LAUNCH")
local s, m = lastResult(ada)
check(s == "Redeemed" and m == "Code redeemed!", `code valide : {s} {m}`)
check(near((ada:GetAttribute("CashBoostEndsAt") or 0) - serverTime(), 900, 2), "boost ×2 de 15 min")
check(dataOf(ada).Codes and dataOf(ada).Codes.LAUNCH ~= nil, "code noté dans le profil")

section("twice")
redeem(ada, "LAUNCH")
s, m = lastResult(ada)
check(s == "AlreadyUsed" and m == "Already used", `deux fois : {s}`)
check(near((ada:GetAttribute("CashBoostEndsAt") or 0) - serverTime(), 900, 5), "pas de 2e boost")

section("unknown")
redeem(ada, "NOPE")
s, m = lastResult(ada)
check(s == "Invalid" and m == "Invalid code", `inconnu : {s}`)
redeem(ada, string.rep("A", 21))
local _, _, n0 = lastResult(ada)
check(n0 == 3, `trop long : refusé par Net, pas de réponse ({n0})`)

section("expired")
local cash0 = dataOf(ada).Cash
redeem(ada, "oldcode")
s, m = lastResult(ada)
check(s == "Expired" and m == "Expired", `expiré : {s}`)
check(dataOf(ada).Cash == cash0, "rien donné")

section("case")
local bob = join("Bob", newProfile8(), 62)
advance(1.5)
redeem(bob, "  launch ")
s = lastResult(bob)
check(s == "Redeemed", `casse et espaces : {s}`)

section("rate")
advance(1.05)
local _, _, n1 = lastResult(bob)
fireAs(bob, "RedeemCode", "NOPE"); flush()
fireAs(bob, "RedeemCode", "NOPE"); flush()
local _, _, n2 = lastResult(bob)
check(n2 == n1 + 1, `débit : un seul des deux envois traité ({n2 - n1})`)

section("potion")
redeem(bob, "Potion2")
s = lastResult(bob)
check(s == "Redeemed" and #POTIONS == 1 and POTIONS[1].id == "Money" and POTIONS[1].count == 2, `potion : {s} {#POTIONS}`)

section("countdown")
check(Codes.FormatCountdown(2 * 86400 + 4 * 3600) == "2d 04h", tostring(Codes.FormatCountdown(2 * 86400 + 4 * 3600)))
check(Codes.FormatCountdown(3 * 3600 + 11 * 60 + 5) == "3h 12m", tostring(Codes.FormatCountdown(3 * 3600 + 11 * 60 + 5)))
check(Codes.FormatCountdown(45 * 60) == "45m", "45m")
check(Codes.FormatCountdown(0) == nil, "fini : nil")
check(string.format(Codes.CountdownFormat, "2d 04h") == "NEXT UPDATE IN 2d 04h", "texte")
-- a184 : la MAJ de chaque samedi 15:00 UTC (plus de date fixe). SAT = samedi 2026-12-19 15:00 UTC (date -u).
if type(Codes.NextUpdateAt) == "function" then
	local SAT, WEEK = 1797692400, 7 * 86400
	check((Codes.UpdateWeekday == 6 and Codes.UpdateHour == 15 and Codes.UpdateMinute == 0) or Codes.UpdateHour == nil, "V0 : samedi 15:00 UTC (a245 : heure lue dans LiveEvents)")
	check(Codes.NextUpdateAt(SAT - 60) == SAT, `une minute avant : ce samedi ({Codes.NextUpdateAt(SAT - 60)})`)
	check(Codes.NextUpdateAt(SAT - 5 * 86400) == SAT, "lundi d'avant : ce samedi")
	check(Codes.NextUpdateAt(SAT) == SAT + WEEK, "à l'heure : repart pour le samedi suivant")
	check(Codes.NextUpdateAt(SAT + 1) == SAT + WEEK, "une seconde après : samedi suivant")
	check(Codes.NextUpdateAt(SAT + WEEK - 1) == SAT + WEEK, "la veille de l'heure suivante")
	check(Codes.NextUpdateAt(SAT + 2 * WEEK + 3600) == SAT + 3 * WEEK, "deux semaines plus tard")
	check(Codes.FormatCountdown(Codes.NextUpdateAt(SAT + 1) - (SAT + 1)) ~= nil, "jamais caché après l'heure")
	check(Codes.FormatCountdown(Codes.NextUpdateAt(SAT - 3600) - (SAT - 3600)) == "1h 00m", "une heure avant : 1h 00m")
else
	check(type(Codes.NextUpdateAt) == "number", "ancien Config : NextUpdateAt nombre")
end
summary("scénario codes")
