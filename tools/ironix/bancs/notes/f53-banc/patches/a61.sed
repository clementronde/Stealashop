# fusion53 (a190, vague 59) : InventoryButton est sorti du contrat de UI_HUD (inventaire archivé, L-183) : le banc
# vérifie maintenant qu'il n'y est plus.
s/^check\(hasButton and Find\.path\(survey\.hud, "InventoryButton"\) ~= nil, "UI_HUD\.InventoryButton au contrat \(bouton\)"\)(\r?)$/check(not hasButton, "UI_HUD.InventoryButton hors contrat (a190)")\1/
