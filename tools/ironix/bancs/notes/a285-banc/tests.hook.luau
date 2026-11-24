--!nocheck
-- Scénario « hook » (a285) : boutique Robux coupée (Features.RobuxShop = false), caisse allumée (RobuxCrate = true) :
-- en Studio, MonetizationTest « <joueur> Crate1|Crate3|Crate10 » passe le lot par le même don qu'un reçu ; toute autre
-- clé avertit sans rien donner ; aucun reçu traité.
REPLACE("shared/Config/Features.luau", "RobuxShop = true", "RobuxShop = false")
startServer()
check(Features.RobuxShop == false and Features.RobuxCrate == true, "boutique coupée, caisse allumée")
check(logHas("caisse exclusive testable", "PRINT", "server"), "une ligne dit que la caisse se teste en Studio")
check(MarketplaceStub.ProcessReceipt == nil, "aucun ProcessReceipt branché")
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
local function test(value)
	clearLog()
	Workspace:SetAttribute("MonetizationTest", value)
	advance(0.5)
end
test("Ada Crate3")
check(Workspace:GetAttribute("MonetizationTest") == nil, "attribut remis à nil")
check(exclusives() == 3 and #notifies(ada, "Exclusive Crate: you got a") == 3, "Crate3 : 3 objets, 3 messages")
check(dataOf(ada).Purchases["STUDIO-1"] ~= nil, "faux PurchaseId STUDIO-1 noté")
check(logHas("test : Crate3 pour Ada (reçu STUDIO-1) → PurchaseGranted", "PRINT", "server"), "réponse écrite dans la sortie")
test("Ada Crate10")
check(exclusives() == 13, "Crate10 : 10 de plus")
for _, value in { "Ada Crate2", "Ada Cash10", "Ada DoubleCash", "Nobody Crate1" } do
	test(value)
	check(logHas("[MonetizationService] test :", "WARN", "server") and exclusives() == 13, `« {value} » : avertissement, rien de donné`)
end
summary("scénario hook")
