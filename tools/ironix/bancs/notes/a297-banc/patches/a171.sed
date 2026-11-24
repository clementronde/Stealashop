# a297 (21/11) : faux PurchaseId du crochet de test « STUDIO-<GUID du Play>-n » (unique d'un Play à l'autre) au lieu de
# « STUDIO-n » : scénario a38/studio.
s#^check\(dataOf\(ada\)\.Purchases\["STUDIO-1"\] ~= nil, "faux PurchaseId STUDIO-1 noté"\)$#check((function() for id in dataOf(ada).Purchases do if string.match(id, "^STUDIO%-.+%-1$") then return true end end return false end)(), "a297 : faux PurchaseId STUDIO-<GUID du Play>-1 noté")#
s#^check\(logHas\("test : Cash10 pour Ada \(reçu STUDIO-1\) → PurchaseGranted", "PRINT", "server"\), "réponse écrite dans la sortie"\)$#check(logHas("test : Cash10 pour Ada (reçu STUDIO-", "PRINT", "server") and logHas("-1) → PurchaseGranted", "PRINT", "server"), "a297 : réponse écrite dans la sortie (reçu STUDIO-<GUID>-1)")#
