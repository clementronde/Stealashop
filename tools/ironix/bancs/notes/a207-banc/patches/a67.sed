# a207 (L-201 point 5) : compteur de la v3 « 10 / 83 discovered ».
s/"Unlocked: ([0-9]+)\/83"/"\1 \/ 83 discovered"/g
# a207 (L-201 point 3) : ClaimLabel « CLAIMED » une fois la zone réclamée.
s/textOf\(rewards\.ClaimButton, "ClaimLabel"\) == "Claimed!"/textOf(rewards.ClaimButton, "ClaimLabel") == "CLAIMED"/g
# a207 : MutationTabs, MutationCaption, Categories.SecretsButton et ZoneBar.ZoneItem sortis du contrat (L-201) ; seule
# la liste « wanted » du scénario v3contract est touchée (pas les sources assemblées).
/^local wanted = \{/ s/, "Categories\.SecretsButton"//g
/^local wanted = \{/ s/, "MutationCaption"//g
/^local wanted = \{/ s/, "Zone1Section\.ZoneBar\.ZoneItem"//g
s/^(\t)table\.insert\(wanted, `MutationTabs\./\1local _ = (`MutationTabs./
s/^(\tlocal _ = \(`MutationTabs\.\{effect\.Id\}Tab\.Selected`)\)$/\1)/
# a207 : les éléments facultatifs du nouvel écran (ZoneTheme, RewardIcon, ItemReward, ReadyGradient, LimitedButton)
# manquent à la copie du banc : lignes orange « (facultatif) » tolérées, aucune autre.
s/^section\("ContractChecker : copies conformes"\)/function logHasHard207(p) for _, l in LOG do if l.side == "server" and string.find(l.text, p, 1, true) and not string.find(l.text, "(facultatif)", 1, true) then return true end end return false end\nsection("ContractChecker : copies conformes")/
s/not logHas\("UI_Index_v3", nil, "server"\)/not logHasHard207("UI_Index_v3")/g
