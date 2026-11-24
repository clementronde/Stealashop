# a208 (vague 63, L-196 et L-204) : 6 packs d'argent ; les boosts du HUD (×2 Speed, zZz) dans l'onglet Boosts, avant Ouvrir maintenant.
s/^check\(offerKeys\(ROBUX\) == "Cash10,Cash60,Cash300", `packs d'argent : /check(offerKeys(ROBUX) == "Cash10,Cash30,Cash60,Cash180,Cash300,Cash720", `(a208) 6 packs d'argent : /
s/^check\(offerKeys\(ROBUX\) == "OpenNow" and /check(offerKeys(ROBUX) == "SpeedBoost,SleepGuards,OpenNow" and /
