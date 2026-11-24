--!nocheck
-- Scénario « previewids » (pre.previewids.luau) : la vitrine quand les offres ont déjà leurs Ids mais
-- que Features.RobuxShop est encore à false. Toujours aucun appel à MarketplaceService : ni lecture de
-- prix (ceux de la Config), ni fenêtre d'achat, même pour Ouvrir maintenant avec un colis en attente
-- ou le pack de départ ; « Soon » à chaque clic.

local HUD = buildHud(PLAYER_GUI)
local ROBUX = buildRobuxShopGui(PLAYER_GUI)
local _, robuxCounter = makeStall("ENV_Hub_RobuxStall", "RobuxShop", ROBUX_PIVOT, true)
P1:SetAttribute("Cash", 6400)
P1:SetAttribute("Income", 120)
MARKET.info[PASS_IDS.DoubleCash] = { PriceInRobux = 399 } -- Roblox répondrait 399 si on lui demandait
startClient()

section("vitrine avec des Ids")
check(Features.RobuxShop == false and Features.RobuxShopPreview == true, "RobuxShop = false, RobuxShopPreview = true")
check(Monetization.PassByKey.DoubleCash.Id == 9001 and Monetization.ProductByKey.Cash300.Id == 8004, "Ids posés dans Config/Monetization (banc)")
click(hudButton(HUD, "RobuxShopButton"))
local cash = cardNamed(ROBUX, "DoubleCash")
advance(1.5)
check(textOf(cash, "Price") == "449" and #MARKET.infoCalls == 0, "prix de la Config, aucun GetProductInfoAsync")

section("aucun achat, quel que soit l'onglet")
local function buyAll()
	for _, card in cardsOf(ROBUX) do
		local button = card:FindFirstChild("BuyButton", true)
		if button and button.Visible then
			click(button)
			check(textOf(card, "Price") == "Soon", `{card.Name} : « Soon »`)
		end
	end
end
buyAll()
click(ROBUX.Root.Tabs.CashTab)
buyAll()
P1:SetAttribute("OpenNowReadyAt", serverTime() + 100) -- un colis en attente (comme si le serveur l'avait posé)
click(ROBUX.Root.Tabs.BoostsTab)
check(shown(cardNamed(ROBUX, "OpenNow"), "BuyButton") and textOf(cardNamed(ROBUX, "OpenNow"), "Price") == "39", "Ouvrir maintenant proposé (palier à 39)")
buyAll()
P1:SetAttribute("StarterPackEndsAt", serverTime() + 600)
click(ROBUX.Root.Tabs.OffersTab)
check(offerKeys(ROBUX) == "StarterPack", "pack de départ proposé")
buyAll()
robuxCounter.RobuxShopPrompt.Triggered:Fire(P1)
flush()
check(#MARKET.prompts == 0, "aucune fenêtre d'achat (gamepass ou produit)")
check(#MARKET.infoCalls == 0, "aucune lecture de prix chez Roblox")
advance(2.1)
check(textOf(cardNamed(ROBUX, "StarterPack"), "Price") == "99", "le prix revient")

summary("scénario previewids")
