# lot97 (a410) : MutationRow et DetailMutations, facultatifs, ajoutés à UI_Index_v3 ; le faux écran du banc ne les a pas :
# leurs lignes « (facultatif) » sont tolérées dans « UI_Index_v3 refait : aucune ligne », aucune autre.
undef $/; $_ = <>;
s/(\tif entry\.side == "server" and string\.find\(entry\.text, "UI_Index_v3", 1, true\))/$1 and not ((string.find(entry.text, "MutationRow", 1, true) or string.find(entry.text, "DetailMutations", 1, true)) and string.find(entry.text, "(facultatif)", 1, true))/;
print;
