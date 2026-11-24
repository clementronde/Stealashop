--!nocheck
-- Scénario « dev » (a294) : jeu DEV (ProductIds « Dev », comme Auto sur le GameId DEV), boutique coupée, RobuxCrate
-- false, RobuxCrateDev true : la caisse est allumée et vendue (Ids DEV 8401 à 8403), ProcessReceipt branché pour ses
-- seuls lots, reçus idempotents ; les autres offres ne sont pas vendues.
SET_ENVIRONMENT("Dev")
startServer()
local Crate = Monetization.Crate
local ProductIds = sharedModule("Config/ProductIds")
local Balance = sharedModule("Config/Balance")

section("V1 DEV : caisse allumée")
check(ProductIds.IsDev == true and Features.RobuxCrate == false and Features.RobuxShop == false, "jeu DEV, RobuxCrate false, boutique coupée")
check(Crate.Live == true and Crate.Ready == true, "Crate.Live vrai en DEV (RobuxCrateDev), don codé")
check(ProductIds.IsDevFor("Auto", Balance.Profiles.DevGameId) == true and ProductIds.IsDevFor("Auto", 10774998269) == false, "Auto : DEV sur le GameId DEV, PROD sur le GameId PROD")
check(Crate.Packs[1].Id == 8401 and Crate.Packs[2].Id == 8402 and Crate.Packs[3].Id == 8403, "Ids DEV des 3 lots")
check(MarketplaceStub.ProcessReceipt ~= nil, "ProcessReceipt branché")
check(logHas("caisse exclusive allumée sans la boutique : 3 lot(s) en vente", "PRINT", "server"), "la sortie dit : 3 lots en vente")
check(logHas("Features.RobuxShop = false : boutique Robux coupée", "PRINT", "server"), "la boutique reste coupée")

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

section("V2 reçus des lots")
check(settle(receipt(ada, 8401, "DV-1")) == GRANTED and exclusives() == 1, "x1 : PurchaseGranted, 1 objet")
check(type(dataOf(ada).Purchases["DV-1"]) == "number", "PurchaseId noté")
check(settle(receipt(ada, 8401, "DV-1")) == GRANTED and exclusives() == 1, "x1 rejoué : rien de plus")
check(settle(receipt(ada, 8402, "DV-3")) == GRANTED and exclusives() == 4, "x3 : 3 de plus")
check(settle(receipt(ada, 8403, "DV-10")) == GRANTED and exclusives() == 14, "x10 : 10 de plus")
check(settle(receipt(ada, 8301, "DV-PROD")) == NOT_YET and exclusives() == 14, "Id PROD d'un lot en DEV : pas traité")

section("V3 le reste de la boutique n'est pas vendu")
local cash = cashOf(ada)
check(settle(receipt(ada, 8002, "DV-CASH")) == NOT_YET and cashOf(ada) == cash, "Cash10 (8002) : NotProcessedYet, rien donné")
check(dataOf(ada).Purchases["DV-CASH"] == nil, "aucun PurchaseId pour lui")
check(MonetizationService.HasPass(ada, "DoubleCash") == false, "aucun gamepass")
summary("scénario dev")
