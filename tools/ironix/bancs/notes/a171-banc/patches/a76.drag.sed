# a171, banc a76, scénario « drag » : objets donnés par objet-sans-colis.luau (plus de colis rapporté ni ouvert en base).
# a171-inclut: objet-sans-colis.sed
s/Slot_Box_/Slot_Item_/g
# L objet sous antivol a sa carte Item_<uid> dans l onglet Items (plus de carte Box_ dans l onglet Boxes).
s/Inventory\.SelectTab\("Boxes"\)/Inventory.SelectTab("Items")/g
s/cardOf\("Boxes", "Box_" \.\. box\)/cardOf("Items", "Item_" .. box)/g
s/INV\.sections\.Boxes\.frame/INV.sections.Items.frame/g
s/INV\.sections\.Boxes\.cards:FindFirstChild\("Box_" \.\. box\)/INV.sections.Items.cards:FindFirstChild("Item_" .. box)/g
