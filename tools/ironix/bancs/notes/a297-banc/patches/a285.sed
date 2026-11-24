# a297 (21/11) : faux PurchaseId « STUDIO-<GUID du Play>-n » (scénario hook) ; scénarios crate et hook sans ouverture
# (Crate.Reveal.Enabled = false : les messages de tous les objets partent tout de suite, le cas du banc a285 ; avec
# ouverture, les messages attendent sa fin : banc a297) ; messages envoyés au tour suivant (task.defer) : crateNotes vide
# d'abord la file des tâches (flush).
s#^check\(dataOf\(ada\)\.Purchases\["STUDIO-1"\] ~= nil, "faux PurchaseId STUDIO-1 noté"\)$#check((function() for id in dataOf(ada).Purchases do if string.match(id, "^STUDIO%-.+%-1$") then return true end end return false end)(), "a297 : faux PurchaseId STUDIO-<GUID du Play>-1 noté")#
s#^check\(logHas\("test : Crate3 pour Ada \(reçu STUDIO-1\) → PurchaseGranted", "PRINT", "server"\), "réponse écrite dans la sortie"\)$#check(logHas("test : Crate3 pour Ada (reçu STUDIO-", "PRINT", "server") and logHas("-1) → PurchaseGranted", "PRINT", "server"), "a297 : réponse écrite dans la sortie (reçu STUDIO-<GUID>-1)")#
s#^startServer\(\)$#REPLACE("shared/Config/Monetization.luau", "Enabled = true, -- V0 de Cantin, 21/11 ; false", "Enabled = false, -- a297 : sans ouverture ; false") startServer()#
s#^(\treturn notifies\(player, "Exclusive Crate: you got a"\))$#\tflush() -- a297 : messages au tour suivant (task.defer)\n\1#
