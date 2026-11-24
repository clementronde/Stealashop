# fusion57 (a208, L-196 et L-204), dans le scénario a38 client d'a171 : 6 packs d'argent ; les boosts du HUD (×2 Speed, zZz) dans l'onglet Boosts, avant Ouvrir maintenant (comme a208-banc/patches/a39.sed).
s/^check\(keys\(\) == "Cash10,Cash60,Cash300", `packs d'argent : /check(keys() == "Cash10,Cash30,Cash60,Cash180,Cash300,Cash720", `(fusion57, a208) 6 packs d'argent : /
s/^check\(keys\(\) == "OpenNow", `seulement Ouvrir maintenant /check(keys() == "SpeedBoost,SleepGuards,OpenNow", `(fusion57, a208) boosts du HUD puis Ouvrir maintenant /
