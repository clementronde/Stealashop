# a294 (21/11, L-276, Cantin) : Disco Ball Épique et chances { 30, 30, 25, 10, 4, 1 } ; boutique coupée et caisse allumée :
# ProcessReceipt branché pour les seuls lots de la caisse (scénario hook).
s/^local rarities = \{ "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" \}$/local rarities = { "Epic", "Epic", "Legendary", "Mythic", "Secret", "Divine" } -- a294 : Disco Ball Épique/
s/check\(disco \/ total > 0\.35 and disco \/ total < 0\.55, `\{Crate\.Items\[1\]\} \(45 %\)/check(disco \/ total > 0.2 and disco \/ total < 0.4, `a294 : {Crate.Items[1]} (30 %)/
s/check\(MarketplaceStub\.ProcessReceipt == nil, "aucun ProcessReceipt branché"\)/check(MarketplaceStub.ProcessReceipt ~= nil and logHas("caisse exclusive allumée sans la boutique : 3 lot(s) en vente", "PRINT", "server"), "a294 : ProcessReceipt branché pour les 3 lots de la caisse seuls")/
