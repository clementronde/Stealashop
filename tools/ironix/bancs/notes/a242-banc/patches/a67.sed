# a242 (vague 72, L-213) : UnlockedBar.ClaimAllButton est sorti du contrat (UI.Retired) ; la copie du banc l a encore : le
# ContractChecker en fait une NOTE « peut être retiré », jamais un problème. Passe après a207-banc/patches/a67.sed
# (logHasHard207) : cette note est tolérée en plus des lignes « (facultatif) », aucune autre.
s/^section\("ContractChecker : copies conformes"\)/function logHasHard242(p) for _, l in LOG do if l.side == "server" and string.find(l.text, p, 1, true) and not string.find(l.text, "(facultatif)", 1, true) and not (string.find(l.text, "UnlockedBar.ClaimAllButton", 1, true) and string.find(l.text, "peut être retiré", 1, true)) then return true end end return false end\nsection("ContractChecker : copies conformes")/
s/not logHasHard207\("UI_Index_v3"\)/not logHasHard242("UI_Index_v3")/g
s/not logHas\("UI_Index_v3", nil, "server"\)/not logHasHard242("UI_Index_v3")/g
