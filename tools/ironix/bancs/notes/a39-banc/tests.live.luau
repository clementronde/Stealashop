--!nocheck
-- Scénario « live » : la boutique ouverte (pre.live.luau : Features.RobuxShop = true et des Ids). Tout
-- marche comme en vague 13 : prix lus chez Roblox, fenêtres d'achat de Roblox, gamepass possédé,
-- Ouvrir maintenant selon l'attente du colis. Seul ajout de L-071 : une offre dont l'Id vaut encore 0
-- n'ouvre rien et montre « Soon » 2 s à la place de son prix. Les attributs du serveur (Pass…,
-- OpenNowReadyAt) sont posés à la main : le serveur n'est pas lancé.

local HUD = buildHud(PLAYER_GUI)
local ROBUX = buildRobuxShopGui(PLAYER_GUI)
local _, robuxCounter, robuxPad = makeStall("ENV_Hub_RobuxStall", "RobuxShop", ROBUX_PIVOT, true)
P1:SetAttribute("Cash", 6400)
P1:SetAttribute("Income", 120)
MARKET.info[PASS_IDS.DoubleCash] = { PriceInRobux = 399 } -- prix changé sur le Creator Hub
MARKET.info[PRODUCT_IDS.Cash10] = { PriceInRobux = 45 }
startClient()

section("boutique ouverte")
check(Features.RobuxShop == true and Features.RobuxShopPreview == true, "RobuxShop = true (RobuxShopPreview reste à true : sans effet)")
check(hudButton(HUD, "RobuxShopButton").Visible == true, "bouton Shop du HUD visible")
check(robuxCounter:FindFirstChild("RobuxShopPrompt") ~= nil, "invite du comptoir posée")

section("gamepasses : prix de Roblox, fenêtres d'achat")
click(hudButton(HUD, "RobuxShopButton"))
check(ROBUX.Enabled == true and offerKeys(ROBUX) == "DoubleCash,DoubleTraining,AutoCollect,FastOpen,ExtraStands", `écran ouvert, gamepasses : {offerKeys(ROBUX)}`)
local cash = cardNamed(ROBUX, "DoubleCash")
check(textOf(cash, "Price") == "449", "prix de la Config en attendant Roblox")
advance(0.2)
check(textOf(cash, "Price") == "399", "puis celui de Roblox (GetProductInfoAsync)")
check(#MARKET.infoCalls > 0, `prix demandés à Roblox ({#MARKET.infoCalls} appels)`)
click(cardNamed(ROBUX, "DoubleTraining"):FindFirstChild("BuyButton", true))
local last = MARKET.prompts[#MARKET.prompts]
check(last ~= nil and last.kind == "GamePass" and last.id == PASS_IDS.DoubleTraining and last.player == P1, "PromptGamePassPurchase(joueur, 9002)")
check(textOf(cardNamed(ROBUX, "DoubleTraining"), "Price") == "299", "pas de « Soon » sur une offre achetable")
P1:SetAttribute("PassDoubleCash", true)
flush()
check(shown(cash, "Owned") and not shown(cash, "BuyButton"), "possédé : Owned visible, BuyButton caché")
local count = #MARKET.prompts
click(cash:FindFirstChild("BuyButton", true))
check(#MARKET.prompts == count and textOf(cash, "Price") == "399", "possédé : un clic tardif n'ouvre rien et ne change pas le prix")

section("onglet Argent : Id à 0 = « Soon »")
click(ROBUX.Root.Tabs.CashTab)
advance(0.2)
check(textOf(cardNamed(ROBUX, "Cash10"), "Price") == "45", "prix de Roblox du pack de 10 min")
click(cardNamed(ROBUX, "Cash10"):FindFirstChild("BuyButton", true))
last = MARKET.prompts[#MARKET.prompts]
check(last.kind == "Product" and last.id == PRODUCT_IDS.Cash10, "PromptProductPurchase(joueur, 8002)")
count = #MARKET.prompts
clearLog()
local big = cardNamed(ROBUX, "Cash300")
click(big:FindFirstChild("BuyButton", true))
check(#MARKET.prompts == count, "Id à 0 (pack de 5 h) : aucune fenêtre d'achat")
check(logHas("Cash300 : Id à 0 dans Config/Monetization", "PRINT", "client"), "une ligne dans la sortie (Studio), comme en vague 13")
check(textOf(big, "Price") == "Soon", `retour visible : « Soon » ({textOf(big, "Price")})`)
advance(2.05)
check(textOf(big, "Price") == "799", "puis le prix de la Config")

section("onglet Boosts : Ouvrir maintenant")
click(ROBUX.Root.Tabs.BoostsTab)
local openNow = cardNamed(ROBUX, "OpenNow")
check(textOf(openNow, "Effect") == "No box is waiting" and not shown(openNow, "BuyButton"), "sans colis : « No box is waiting », pas de bouton")
P1:SetAttribute("OpenNowReadyAt", serverTime() + 100)
flush()
advance(1.1)
check(textOf(openNow, "Price") == "39" and shown(openNow, "BuyButton"), `attente d'environ 100 s : palier à 39 ({textOf(openNow, "Price")})`)
click(openNow:FindFirstChild("BuyButton", true))
last = MARKET.prompts[#MARKET.prompts]
check(last.kind == "Product" and last.id == TIER_IDS[2], "PromptProductPurchase du palier 2 (8102)")

section("onglet Offres : pack de départ quand il est proposé")
click(ROBUX.Root.Tabs.OffersTab)
check(offerKeys(ROBUX) == "", "pas proposé : onglet vide")
P1:SetAttribute("StarterPackEndsAt", serverTime() + 600)
flush()
check(offerKeys(ROBUX) == "StarterPack" and textOf(cardNamed(ROBUX, "StarterPack"), "Price") == "99", "proposé : la carte du pack de départ")
click(cardNamed(ROBUX, "StarterPack"):FindFirstChild("BuyButton", true))
last = MARKET.prompts[#MARKET.prompts]
check(last.kind == "Product" and last.id == PRODUCT_IDS.StarterPack, "PromptProductPurchase(joueur, 8001)")

section("plaque ShopPad du comptoir Robux")
click(ROBUX.Root.Window.CloseButton)
check(ROBUX.Enabled == false, "écran fermé")
moveTo(onPadSpot(ROBUX_PIVOT))
advance(0.1)
check(ROBUX.Enabled == true, "monter sur la plaque ouvre la boutique")
moveTo(FAR_SPOT)
advance(1)
check(ROBUX.Enabled == true, "elle ne se ferme pas quand on s'éloigne (partout, 5.9)")
check(robuxPad.Parent ~= nil, "plaque toujours là")

summary("scénario live")
