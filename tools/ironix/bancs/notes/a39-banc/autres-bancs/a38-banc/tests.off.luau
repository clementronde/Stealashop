--!nocheck
-- Scénario « off » : Features.RobuxShop = false, la vraie valeur jusqu'à la MAJ 1 (pas de pre.on). La
-- boutique ne branche rien : ni ProcessReceipt, ni lecture des gamepasses, ni accroche, ni attribut,
-- ni bonus Premium, même pour un joueur qui possède tout (et un cache de gamepasses dans son profil) ;
-- le jeu se comporte comme le MVP ; l'écran reste fermé et le comptoir sans invite.

startServer()
section("démarrage")
check(Features.RobuxShop == false, "Features.RobuxShop = false (fichier du dépôt)")
check(logHas("[MonetizationService] Features.RobuxShop = false", "PRINT", "server"), "une ligne dans la sortie")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(MarketplaceStub.ProcessReceipt == nil, "ProcessReceipt pas posé")
check(MarketplaceStub.PromptGamePassPurchaseFinished:ConnectionCount() == 0, "fin d'achat de gamepass pas écoutée")
check(MonetizationService.IsEnabled() == false, "IsEnabled() = false")

local data = newProfile()
data.Lifetime.PlaySeconds = 0 -- nouveau joueur : le pack de départ serait proposé
data.Boosts.Cash = 600
data.Monetization.Passes = { DoubleCash = true, ExtraStands = true, AutoCollect = true, FastOpen = true, DoubleTraining = true }
addItem(data, "o-1", "Z1_CanetteDeSoda", 1)
addItem(data, "o-21", "Z1_Donut", 21) -- sur un présentoir bonus
local ada = join("Ada", data)
ada.MembershipType = Enum.MembershipType.Premium
MARKET.owns[ada.UserId] = { [9001] = true, [9004] = true, [9006] = true }
advance(3)

section("aucun effet")
check(#MARKET.ownsCalls == 0, "aucune lecture de gamepass (UserOwnsGamePassAsync)")
local attrs = ada:GetAttributes()
local found = {}
for name in attrs do
	if string.sub(name, 1, 4) == "Pass" or name == "StarterPackEndsAt" or name == "CashBoostEndsAt" or name == "OpenNowReadyAt" then
		table.insert(found, name)
	end
end
check(#found == 0, `aucun attribut de la boutique sur le Player ({table.concat(found, ", ")})`)
local exposed = ada:GetAttribute("ExposedIncome")
check(exposed ~= nil and exposed > 0 and ada:GetAttribute("Income") == exposed, `revenus sans bonus, même Premium : Income = ExposedIncome = {exposed}`)
check(ada:GetAttribute("DisplaySlotsUnlocked") == 4, "4 présentoirs : aucun présentoir bonus")
check(dataOf(ada).Display["21"] == nil and dataOf(ada).Items["o-21"] ~= nil, "l'objet du présentoir bonus retourne dans l'inventaire (gardé dans Items)")
local cash0 = cashOf(ada)
advance(3)
check(cashOf(ada) == cash0 and (shopOf(ada):GetAttribute("CashRegister") or 0) > 0, "pas d'encaissement automatique : l'argent reste en caisse")
check(MonetizationService.HasPass(ada, "DoubleCash") == false, "HasPass = false")
check(MonetizationService.GetIncomeMultiplier(ada) == 1, "GetIncomeMultiplier = 1")
check(MonetizationService.AddCashBoost(ada, 60) == false, "AddCashBoost refusé")
local box = placeBox(ada, 1, "Rare", "Z1_PotDeNouilles")
check(box ~= nil and near(box.ReadyAt - serverTime(), Rarities.ById.Rare.OpenDelay, 0.05), "attente d'ouverture normale (Rare : 45 s)")

section("reçus")
local entry = receipt(ada, 8002)
check(entry.decision == "pas de ProcessReceipt", "un reçu n'est pas traité (Roblox le garde)")
check(next(dataOf(ada).Purchases) == nil, "Purchases vide")

section("écran")
local playerGui = ada:FindFirstChild("PlayerGui")
local gui = buildRobuxShopGui(playerGui)
local hud = buildHud(playerGui)
startClient(ada)
-- Copie d'a39 (L-071) : avec Features.RobuxShopPreview (fichier du dépôt après L-071), l'écran s'ouvre en
-- vitrine, sans aucun achat ; sans lui (arbre d'avant L-071), rien ne s'ouvre, comme avant.
if Features.RobuxShopPreview == true then
	local prompt = ROBUX_COUNTER:FindFirstChild("RobuxShopPrompt")
	check(prompt ~= nil, "vitrine (RobuxShopPreview) : invite sur le comptoir")
	click(hud.LeftRail.RobuxShopButton)
	check(gui.Enabled == true and #cardsOf(gui) == 5, "vitrine : le bouton du HUD ouvre l'écran (5 gamepasses)")
	check(gui.Root.Window.List:FindFirstChild("Preview_1") == nil, "vitrine : cartes d'exemple retirées")
	local card = cardNamed(gui, "DoubleCash")
	click(card:FindFirstChild("BuyButton", true))
	check(#MARKET.prompts == 0 and #MARKET.infoCalls == 0, "vitrine : aucun appel à MarketplaceService")
	check(textOf(card, "Price") == "Soon", "vitrine : « Soon » à la place du prix")
	check(not card.Owned.Visible, "vitrine : aucun gamepass possédé (serveur coupé), même pour un joueur qui les a")
else
	check(ROBUX_COUNTER:FindFirstChild("RobuxShopPrompt") == nil, "pas d'invite sur le comptoir")
	click(hud.LeftRail.RobuxShopButton)
	check(gui.Enabled == false and #cardsOf(gui) == 0, "le bouton du HUD n'ouvre rien")
	check(gui.Root.Window.List:FindFirstChild("Preview_1") ~= nil, "écran pas touché (cartes d'exemple encore là)")
end

summary("scénario off")
