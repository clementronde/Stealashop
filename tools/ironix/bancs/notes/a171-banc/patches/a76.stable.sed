# a171, banc a76, scénario « stable » : objets donnés par objet-sans-colis.luau (plus de colis rapporté ni ouvert en base).
# a171-inclut: objet-sans-colis.sed
s/Slot_Box_/Slot_Item_/g
# Objets sous antivol : dans Items (plus Boxes), carte Item_<uid> de l onglet Items.
s/dataOf\(ada\)\.Boxes\[/dataOf(ada).Items[/g
s/cardsOf\("Boxes"\)\["Box_" \.\. /cardsOf("Items")["Item_" .. /g
