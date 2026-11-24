--!nocheck
-- Scénario « prod » : hors de Studio (RunService:IsStudio() = false), le crochet de test n'est pas
-- écouté ; la boutique marche comme en Studio.

PROD_SERVER = true
startServer()
local ada = join("Ada", newProfile())
advance(1.5)
Workspace:SetAttribute("MonetizationTest", "Ada DoubleCash")
advance(0.5)
check(not MonetizationService.HasPass(ada, "DoubleCash") and ada:GetAttribute("PassDoubleCash") == nil, "crochet de test ignoré hors de Studio")
check(Workspace:GetAttribute("MonetizationTest") == "Ada DoubleCash", "l'attribut n'est même pas lu")
check(MarketplaceStub.ProcessReceipt ~= nil, "ProcessReceipt posé")
check(settle(receipt(ada, PRODUCT_IDS.Cash10, "PR-1")) == GRANTED, "un reçu est traité")
check(not logHas("[MonetizationService] Ada : Cash10 donné", "PRINT", "server"), "pas de ligne de Studio dans la sortie")
summary("scénario prod")
