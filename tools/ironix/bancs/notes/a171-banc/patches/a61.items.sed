# a171, banc a61 (écran d inventaire), scénario « items » : l objet du 5e présentoir vient de objet-sans-colis.luau.
# a171-inclut: objet-sans-colis.sed
# Petit chef (2026-11-15, fusion49) : a170 a retiré l enregistrement Boxes d InventoryState ; l aide invOf le parcourait encore.
s/for _, box in state\.Boxes do/for _, box in state.Boxes or {} do/
s/for _, box in invState\(player\)\.Boxes do/for _, box in invState(player).Boxes or {} do/
