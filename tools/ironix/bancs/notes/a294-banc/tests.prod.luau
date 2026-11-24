--!nocheck
-- Scénario « prod » (a294) : jeu PROD (ProductIds « Prod », comme Auto sur le GameId PROD), RobuxCrateDev true mais
-- RobuxCrate false : caisse coupée (ni montrée, ni vendue), aucun ProcessReceipt, le crochet de Studio pas branché.
SET_ENVIRONMENT("Prod")
startServer()
local Crate = Monetization.Crate
local ProductIds = sharedModule("Config/ProductIds")
section("P1 PROD : caisse coupée")
check(ProductIds.IsDev == false and Features.RobuxCrateDev == true and Features.RobuxCrate == false, "jeu PROD, RobuxCrateDev true, RobuxCrate false")
check(Crate.Live == false, "Crate.Live faux en PROD")
check(Crate.Packs[1].Id == 8301, "Ids PROD (8301)")
check(MarketplaceStub.ProcessReceipt == nil, "aucun ProcessReceipt branché")
check(not logHas("caisse exclusive allumée", "PRINT", "server") and not logHas("caisse exclusive testable", "PRINT", "server"), "ni vente ni crochet de la caisse")
local ada = join("Ada", newProfile())
advance(1.5)
check(receipt(ada, 8301, "PR-1").decision == "pas de ProcessReceipt", "reçu d'un lot : personne ne le traite")
Workspace:SetAttribute("MonetizationTest", "Ada Crate1")
advance(0.5)
local n = 0
for _, entry in dataOf(ada).Items do
	if string.find(entry.Id, "^Exclusive_") then
		n += 1
	end
end
check(n == 0 and #remotes("RevealStarted") == 0, "crochet de Studio pas branché : rien donné, aucune ouverture")
summary("scénario prod")
