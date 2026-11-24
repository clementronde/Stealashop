--!nocheck
-- Scénario « off » (a285) : boutique Robux ouverte, caisse éteinte (Features.RobuxCrate = false, comme en jeu
-- aujourd'hui) : un reçu d'un lot n'est pas traité (aucun objet), le crochet refuse Crate1, les autres offres
-- restent en vente.
REPLACE("shared/Config/Features.luau", "RobuxCrate = true", "RobuxCrate = false")
startServer()
check(Features.RobuxCrate == false, "caisse éteinte")
check(not logHas("caisse exclusive testable", "PRINT", "server"), "pas de ligne de test de la caisse")
local ada = join("Ada", newProfile())
advance(1.5)
local function exclusives()
	local n = 0
	for _, entry in dataOf(ada).Items do
		if string.find(entry.Id, "^Exclusive_") then
			n += 1
		end
	end
	return n
end
local r = receipt(ada, CRATE_IDS[1], "OFF-1")
check(settle(r) == Enum.ProductPurchaseDecision.NotProcessedYet, "reçu d'un lot : NotProcessedYet")
check(exclusives() == 0 and dataOf(ada).Purchases["OFF-1"] == nil, "aucun objet, aucun PurchaseId")
check(logHas("Crate pas encore codé, pas traité", "WARN", "server"), "une alerte dans la sortie")
clearLog()
Workspace:SetAttribute("MonetizationTest", "Ada Crate1")
advance(0.5)
check(logHas("[MonetizationService] test :", "WARN", "server") and exclusives() == 0, "crochet : Crate1 refusé")
local cash = cashOf(ada)
check(settle(receipt(ada, 8002, "OFF-2")) == GRANTED and cashOf(ada) > cash, "les autres offres restent en vente (Cash10)")
summary("scénario off")
