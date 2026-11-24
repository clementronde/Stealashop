# a201 : tests.v4 d'a191 adapté à L-192 (l'objet seul) ; commun aux scénarios v4 et v4old.
1,4c\
--!nocheck\
-- Scénario « v4 » / « v4old » (a201, copie générée du scénario v4 d'a191 par patches/v4-*.sed) : UI_Index_v4,\
-- la récompense de zone n'est qu'un objet (L-192). v4 : Footer.ItemReward (RewardIcon, RewardCaption) écrit,\
-- CashReward et SpeedReward d'avant cachés. v4old : écran sans ItemReward, sans erreur.
150s/.*/check(dataOf(ada).Cash == cash0 and dataOf(ada).Stats.Speed == 0 and countOf(dataOf(ada).Tools.Owned, "Wrench") == 1, "le serveur donne l'objet seul (ni argent, ni Vitesse)")/
114a\
check(caption.Text == "+WRENCH", `ClaimButton.RewardCaption « {caption.Text} »`)
