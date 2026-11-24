# a171, banc a51, scénario « inventory » : objets sous antivol rapportés (objet-sans-colis.luau) au lieu des colis.
# a171-inclut: objet-sans-colis.sed
# Mort : l objet sous antivol rapporté est dans Items (plus Boxes). « Départ et retour » et « point hors de Bounds » (colis
# posé au sol) retirés : l objet posé sous antivol au départ et au retour est vérifié par le banc a105 (scénario place).
s/check\(invOf\(ada\)\["Box:" \.\. uid\] ~= nil and #invState\(ada\)\.Boxes == #before\.Boxes \+ 1, "un colis de plus dans l'état"\)/check(invOf(ada)["Item:" .. uid] ~= nil and #invState(ada).Items == #before.Items + 1, "a171 : un objet sous antivol de plus dans l'état")/
s/countKeys\(dataOf\(ada\)\.Boxes\) == 1 and countKeys\(dataOf\(ada\)\.Items\) == 5/countKeys(dataOf(ada).Boxes) == 0 and countKeys(dataOf(ada).Items) == 6/
/^section\("départ et retour : colis posés/,/^summary\("scénario inventory"\)/{/^summary/!d}
# Petit chef (2026-11-15, fusion49) : a170 a retiré l enregistrement Boxes d InventoryState ; l aide invOf le parcourait encore.
s/for _, box in state\.Boxes do/for _, box in state.Boxes or {} do/
s/for _, box in invState\(player\)\.Boxes do/for _, box in invState(player).Boxes or {} do/
