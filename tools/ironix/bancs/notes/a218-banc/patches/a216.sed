# a218 (vague 66) : Ouvrir maintenant sans palier créé (Ids à 0) : bouton visible, « Soon ».
s/check\(openNow:FindFirstChild\("BuyButton"\).Visible == false, "sans objet qui attend : BuyButton caché"\)/check(openNow:FindFirstChild("BuyButton").Visible == true and textOf(openNow, "Price") == "Soon", "a218 : aucun palier créé : bouton « Soon » même sans objet")/
s/check\(tier ~= nil and textOf\(openNow, "Price"\) == tostring\(math.floor\(tier.Price\)\), `prix du palier/check(tier ~= nil and textOf(openNow, "Price") == "Soon", `a218 : aucun palier créé : « Soon »/
