# a171, banc a76, scénario « dblclick » : objets sous antivol rapportés (objet-sans-colis.luau) au lieu des colis.
# a171-inclut: objet-sans-colis.sed
s/Inventory\.SelectTab\("Boxes"\)/Inventory.SelectTab("Items")/g
s/cardOf\("Boxes", "Box_" \.\. box\)/cardOf("Items", "Item_" .. box)/g
s/INV\.sections\.Boxes\.frame/INV.sections.Items.frame/g
s/INV\.sections\.Boxes\.cards:FindFirstChild\("Box_" \.\. box\)/INV.sections.Items.cards:FindFirstChild("Item_" .. box)/g
s/dataOf\(ada\)\.Boxes\[/dataOf(ada).Items[/g
s/cardsOf\("Boxes"\)\["Box_" \.\. /cardsOf("Items")["Item_" .. /g
s/Slot_Box_/Slot_Item_/g
