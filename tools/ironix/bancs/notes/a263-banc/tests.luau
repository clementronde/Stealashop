-- Scénarios du banc a263 (vague 77) : cote qui défile en entiers lisibles (UnboxPlan.oddsText, même arrondi que la
-- cote finale, Formulas.UnboxOdds).
CHECKS, FAILS = 0, 0
local function check(ok, label)
	CHECKS += 1
	if not ok then
		FAILS += 1
		print("ÉCHEC : " .. label)
	elseif VERBOSE then
		print("ok : " .. label)
	end
end
local Formulas = shared("Config/Formulas")
local UnboxPlan = shared("UnboxPlan")
check(UnboxPlan.oddsText(8.4) == "1 IN 8", "O1 cote qui défile 8.4 : « 1 IN 8 » (" .. UnboxPlan.oddsText(8.4) .. ")")
check(UnboxPlan.oddsText(2.42) == "1 IN 2" and UnboxPlan.oddsText(2.6) == "1 IN 3", "O2 2.42 et 2.6 : « 1 IN 2 », « 1 IN 3 »")
check(UnboxPlan.oddsText(37) == "1 IN 37" and UnboxPlan.oddsText(37.4) == "1 IN 37", "O3 37 et 37.4 : « 1 IN 37 »")
check(UnboxPlan.oddsText(1234) == "1 IN 1.2K" and UnboxPlan.oddsText(12345) == "1 IN 12K", "O4 1234 et 12345 : 1.2K, 12K (2 chiffres significatifs)")
check(UnboxPlan.oddsText(1) == "1 IN 1" and UnboxPlan.oddsText(0.5) == "1 IN 0.5", "O5 bornes : 1, et sous 1 laissé tel quel")
local same = true
for _, chance in { 1 / 2, 1 / 9.7, 1 / 37, 1 / 99.4, 1 / 640, 1 / 12000, 1 / 4.8e6, 1 / 2.3e7, 1 / 5.3e9 } do
	local final = Formulas.UnboxOdds(chance)
	if UnboxPlan.oddsText(final) ~= string.format("1 IN %s", UnboxPlan.formatOdds(final)) then
		same = false
		print("    cote finale " .. tostring(final) .. " : " .. UnboxPlan.oddsText(final))
	end
end
check(same, "O6 cote finale (déjà arrondie) inchangée par le nouvel arrondi")
local integer = true
for value = 1, 99.9, 0.1 do
	local text = UnboxPlan.oddsText(value)
	if string.find(text, ".", 1, true) then
		integer = false
		print("    " .. value .. " : " .. text)
		break
	end
end
check(integer, "O7 de 1 à 99,9 : jamais de décimale")
check(UnboxPlan.formatOdds(2.42) == "2.4", "O8 formatOdds inchangé (2.4)")
print(string.format("banc a263 cote : %d vérification(s), %d échec(s)", CHECKS, FAILS))
