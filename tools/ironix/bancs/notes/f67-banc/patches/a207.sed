# fusion67 (vague 72, a242, L-213) : UnlockedBar.ClaimAllButton est sorti du contrat (UI.Retired) ; les faux UI_Index_v3 du banc
# l ont encore (caché) : le ContractChecker en fait une NOTE « … plus lu par le code ; peut être retiré », jamais un problème.
# Seule cette note est tolérée (comme a242-banc/patches/a67.sed pour a67), dans les deux vérifications ; aucune autre ligne.
s/^(\tif entry\.side == "server" and string\.find\(entry\.text, "UI_Index_v3", 1, true\)) then$/\1 and not (string.find(entry.text, "UnlockedBar.ClaimAllButton", 1, true) and string.find(entry.text, "peut être retiré", 1, true)) then/
s/^(\t\tif entry\.side == "server" and string\.find\(entry\.text, p, 1, true\) and not string\.find\(entry\.text, "\(facultatif\)", 1, true\)) then$/\1 and not (string.find(entry.text, "UnlockedBar.ClaimAllButton", 1, true) and string.find(entry.text, "peut être retiré", 1, true)) then/
