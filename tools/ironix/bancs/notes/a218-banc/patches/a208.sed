# a218 (vague 66, L-210) : chances V0 de la caisse posées dans Config ; une offre à l'Id 0 ou pas codée dit « Soon » en permanence.
s/replaceSource\(M, "Odds = \{\} :: \{ number \},", /replaceSource(M, "Odds = { 45, 28, 15, 7, 4, 1 } :: { number },", /
s/textOf\(speed, "Price"\) == "29", `×2 Speed : nom et prix/textOf(speed, "Price") == "Soon", `a218 : ×2 Speed pas codé : nom et « Soon »/
s/check\(textOf\(v2Card\(V2, "SleepGuards"\), "Price"\) == "79", "zZz : 79"\)/check(textOf(v2Card(V2, "SleepGuards"), "Price") == "Soon", "a218 : zZz pas codé : « Soon »")/
s/check\(textOf\(v2Card\(V2, "Cash720"\), "Price"\) == "1599" and/check(textOf(v2Card(V2, "Cash720"), "Price") == "Soon" and/
s/check\(textOf\(v2El\(V2, "Featured.BuyButton"\), "Price"\) == "99", "prix du pack de départ : 99"\)/check(textOf(v2El(V2, "Featured.BuyButton"), "Price") == "Soon", "a218 : pack de départ à l'Id 0 : « Soon »")/
s/check\(textOf\(v2Card\(V2, "SpeedBoost"\), "Price"\) == "29", "le prix revient"\)/check(textOf(v2Card(V2, "SpeedBoost"), "Price") == "Soon", "a218 : pas codé, « Soon » reste")/
s/check\(textOf\(b1, "Price"\) == "99" and textOf\(b2, "Price"\) == "249" and textOf\(b3, "Price"\) == "799", "prix 99 \/ 249 \/ 799"\)/check(textOf(b1, "Price") == "Soon" and textOf(b2, "Price") == "Soon" and textOf(b3, "Price") == "Soon", "a218 : caisse pas codée (Ready = false) : « Soon » sur les 3 lots")/
s/check\(textOf\(b2, "Price"\) == "249", "le prix revient"\)/check(textOf(b2, "Price") == "Soon", "a218 : caisse pas codée : « Soon » reste")/
