--!nocheck
-- Scénario « client » : RobuxShopController sur une copie de l'écran UI_RobuxShop de Clément (arbre
-- relevé dans Studio : Template, 6 cartes d'exemple Preview_*, attribut IconAsset sur les Icon).
-- Ouverture par le bouton du HUD et par l'invite du comptoir, onglets, une carte par offre codée
-- (VIP et Gants cachés), textes, prix de Roblox quand l'Id existe (sinon ceux de la Config), icônes de
-- la maquette, possédé = Owned visible et BuyButton caché, fenêtres d'achat de Roblox, Id à 0 = aucun
-- achat, Ouvrir maintenant selon l'attente du colis, pack de départ seulement quand il est proposé.

startServer()
local data = newProfile()
addItem(data, "c-1", "Z3_Smartphone", 1, 3)
local ada = join("Ada", data)
MARKET.info[PASS_IDS.DoubleCash] = { PriceInRobux = 399 } -- prix changé sur le Creator Hub
MARKET.info[PRODUCT_IDS.Cash10] = { PriceInRobux = 45 }
local playerGui = ada:FindFirstChild("PlayerGui")
local gui = buildRobuxShopGui(playerGui)
local hud = buildHud(playerGui)
advance(1.5)
startClient(ada)

local function keys()
	local out = {}
	for _, card in cardsOf(gui) do
		table.insert(out, (string.gsub(card.Name, "^Offer_", "")))
	end
	return table.concat(out, ",")
end
local function visible(card, name)
	local found = card:FindFirstChild(name, true)
	return found ~= nil and found.Visible == true
end
local function clickBuy(key)
	local card = cardNamed(gui, key)
	click(card:FindFirstChild("BuyButton", true))
end

section("branchement")
local prompt = ROBUX_COUNTER:FindFirstChild("RobuxShopPrompt")
check(prompt ~= nil and prompt.ActionText == "Shop" and prompt.ObjectText == "Robux Shop", "invite « Shop » / « Robux Shop » sur le comptoir RobuxShop")
local list = gui.Root.Window.List
check(list:FindFirstChild("Preview_1") == nil and list:FindFirstChild("Preview_6") == nil, "cartes d'exemple Preview_* retirées")
check(list:FindFirstChild("Template") ~= nil and list.Template.Visible == false, "Template gardé, invisible")
check(gui.Enabled == false, "écran fermé au départ")

section("ouverture : onglet Gamepasses")
click(hud.LeftRail.RobuxShopButton)
check(gui.Enabled == true, "le bouton du HUD ouvre l'écran")
check(keys() == "DoubleCash,DoubleTraining,AutoCollect,FastOpen,ExtraStands", `gamepasses codés, dans l'ordre (VIP et Gants cachés) : {keys()}`)
local cash = cardNamed(gui, "DoubleCash")
check(textOf(cash, "ItemName") == "×2 CASH", `nom en capitales comme la maquette : {textOf(cash, "ItemName")}`)
check(textOf(cash, "Effect") == "Doubles all your income", "ligne d'effet")
check(textOf(cash, "Price") == "449", "prix de la Config en attendant Roblox")
advance(0.2)
check(textOf(cash, "Price") == "399", "puis le prix de Roblox (GetProductInfoAsync)")
check(textOf(cardNamed(gui, "DoubleTraining"), "Price") == "299", "sans réponse de Roblox : prix de la Config")
local infoTypes = {}
for _, call in MARKET.infoCalls do
	infoTypes[call.id] = call.infoType
end
check(infoTypes[PASS_IDS.DoubleCash] == Enum.InfoType.GamePass, "InfoType.GamePass pour un gamepass")
check(cardNamed(gui, "DoubleTraining").Icon.Image == "rbxassetid://106315635775683", "icône de la maquette (IconAsset UI_Icon_GP_x2Training)")
check(cardNamed(gui, "ExtraStands").Icon.Image == "rbxassetid://93766507411897", "icône UI_Icon_GP_Displays")
check(visible(cash, "BuyButton") and not visible(cash, "Owned"), "pas possédé : BuyButton visible, Owned caché")

section("achat d'un gamepass")
clickBuy("DoubleTraining")
local last = MARKET.prompts[#MARKET.prompts]
check(last ~= nil and last.kind == "GamePass" and last.id == PASS_IDS.DoubleTraining and last.player == ada, "PromptGamePassPurchase(joueur, 9002)")
finishPassPurchase(ada, PASS_IDS.DoubleCash, true) -- côté serveur : l'attribut PassDoubleCash suit
flush()
check(visible(cash, "Owned") and not visible(cash, "BuyButton"), "possédé : coche (Owned) et bouton caché")
local count = #MARKET.prompts
click(cash:FindFirstChild("BuyButton", true))
check(#MARKET.prompts == count, "possédé : un clic tardif n'ouvre plus de fenêtre d'achat")

section("onglet Argent")
click(gui.Root.Tabs.CashTab)
check(keys() == "Cash10,Cash60,Cash300", `packs d'argent : {keys()}`)
local income = ada:GetAttribute("Income")
local pack = cardNamed(gui, "Cash10")
check(textOf(pack, "Effect") == "+" .. sharedModule("Format", "client").money(Monetization.CashPackAmount(income, 10)) .. " · 10 min of income", `montant du pack : {textOf(pack, "Effect")}`)
advance(0.2)
check(textOf(pack, "Price") == "45", "prix de Roblox du pack")
clickBuy("Cash10")
last = MARKET.prompts[#MARKET.prompts]
check(last.kind == "Product" and last.id == PRODUCT_IDS.Cash10, "PromptProductPurchase(joueur, 8002)")
count = #MARKET.prompts
clearLog()
clickBuy("Cash300")
check(#MARKET.prompts == count, "Id à 0 (pack de 5 h) : aucune fenêtre d'achat")
check(logHas("Cash300 : Id à 0 dans Config/Monetization", "PRINT", "client"), "une ligne dans la sortie (Studio)")
check(textOf(cardNamed(gui, "Cash300"), "Price") == "799", "prix de la Config affiché")

section("onglet Boosts : Ouvrir maintenant")
click(gui.Root.Tabs.BoostsTab)
check(keys() == "OpenNow", `seulement Ouvrir maintenant (Vengeance, Rideau, Chance, Bouclier cachés) : {keys()}`)
local openNow = cardNamed(gui, "OpenNow")
check(textOf(openNow, "Effect") == "No box is waiting" and not visible(openNow, "BuyButton"), "sans colis : « No box is waiting », pas de bouton")
local box = placeBox(ada, 1, "Mythic", "Z3_CarteGraphiqueEnOr", "Luxe", 3)
advance(1.2)
local left = box.ReadyAt - serverTime()
check(string.find(textOf(openNow, "Effect"), "Opens your box right now (", 1, true) == 1, `attente affichée : {textOf(openNow, "Effect")}`)
check(textOf(openNow, "Price") == "59" and visible(openNow, "BuyButton"), `palier de {string.format("%.0f", left)} s : 59`)
clickBuy("OpenNow")
last = MARKET.prompts[#MARKET.prompts]
check(last.kind == "Product" and last.id == TIER_IDS[3], "PromptProductPurchase du palier 3 (8103)")

section("onglet Offres : pack de départ seulement quand il est proposé")
click(gui.Root.Tabs.OffersTab)
check(keys() == "", "pas proposé : onglet vide")
ada:SetAttribute("StarterPackEndsAt", serverTime() + 600)
flush()
check(keys() == "StarterPack", "proposé : la carte du pack de départ")
check(textOf(cardNamed(gui, "StarterPack"), "Effect") == "×2 Cash 1h + Hammer + $50K" and textOf(cardNamed(gui, "StarterPack"), "Price") == "99", "texte et prix")
ada:SetAttribute("StarterPackEndsAt", nil)
flush()
check(keys() == "", "plus proposé : la carte disparaît")

section("fermeture et réouverture")
click(gui.Root.Window.CloseButton)
check(gui.Enabled == false and keys() == "", "CloseButton ferme l'écran (cartes retirées)")
prompt.Triggered:Fire(ada)
flush()
check(gui.Enabled == true and keys() == "", "l'invite du comptoir ouvre l'écran, sur le dernier onglet choisi (Offres)")
click(hud.LeftRail.RobuxShopButton)
check(gui.Enabled == false, "le bouton du HUD le referme")

summary("scénario client")
