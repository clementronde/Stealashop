--!nocheck
-- Scénario « studio » : le crochet de test de Studio (Ids encore à 0 : aucun achat réel possible).
-- workspace:SetAttribute("MonetizationTest", "<joueur> <Clé>") donne un gamepass pour la session ou
-- passe un produit par le même don qu'un reçu (faux PurchaseId STUDIO-n) ; l'attribut est remis à nil ;
-- une demande fausse avertit sans rien donner.

startServer()
local ada = join("Ada", newProfile())
advance(1.5)

local function test(value)
	clearLog()
	Workspace:SetAttribute("MonetizationTest", value)
	advance(0.5)
end

section("gamepass")
test("Ada DoubleCash")
check(Workspace:GetAttribute("MonetizationTest") == nil, "attribut remis à nil")
check(MonetizationService.HasPass(ada, "DoubleCash") and ada:GetAttribute("PassDoubleCash") == true, "×2 Argent donné pour la session")
check(#notifies(ada, "×2 Cash unlocked!") == 1, "Notify comme un achat")
check(logHas("test : gamepass DoubleCash donné à Ada", "PRINT", "server"), "une ligne dans la sortie")

section("produit")
local cash0 = cashOf(ada)
test("1 Cash10") -- le joueur par son UserId
check(cashOf(ada) == cash0 + Monetization.CashPackAmount(ada:GetAttribute("Income"), 10), "pack d'argent donné")
check(dataOf(ada).Purchases["STUDIO-1"] ~= nil, "faux PurchaseId STUDIO-1 noté")
check(logHas("test : Cash10 pour Ada (reçu STUDIO-1) → PurchaseGranted", "PRINT", "server"), "réponse écrite dans la sortie")
local box = placeBox(ada, 1, "Rare", "Z3_Smartphone", "Premium", 3)
test("Ada OpenNow1")
check(box.ReadyAt <= serverTime() + 1e-6, "Ouvrir maintenant (palier 1) : colis prêt")

section("demandes fausses : rien")
local cash1 = cashOf(ada)
for _, value in { "Ada OpenNow9", "Nobody DoubleCash", "Ada Revenge", "Ada Foo", "n'importe quoi" } do
	test(value)
	check(logHas("[MonetizationService] test :", "WARN", "server") and cashOf(ada) == cash1, `« {value} » : avertissement, rien de donné`)
end

summary("scénario studio")
