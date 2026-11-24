--!nocheck
-- Scénario « preview » : Config/Features tel qu'au dépôt (RobuxShop = false, RobuxShopPreview = true,
-- Index = true, RebirthPreview = true). Les trois boutons du HUD sont visibles ; la boutique Robux
-- s'ouvre en vitrine par le bouton du HUD et par l'invite du comptoir : onglets, cartes et prix de la
-- Config comme en vague 13, mais aucun appel à MarketplaceService (ni fenêtre d'achat, ni lecture de
-- prix) et « Soon » à la place du prix pendant 2 s après un clic sur BuyButton.

local HUD = buildHud(PLAYER_GUI)
local ROBUX = buildRobuxShopGui(PLAYER_GUI)
buildWeaponShop(PLAYER_GUI)
buildAuraShop(PLAYER_GUI)
buildRebirth(PLAYER_GUI)
local robuxStall, robuxCounter = makeStall("ENV_Hub_RobuxStall", "RobuxShop", ROBUX_PIVOT, false)
makeStall("ENV_Hub_WeaponStall", "WeaponShop", WEAPON_PIVOT, false)
makeStall("ENV_Hub_AuraStall", "AuraShop", AURA_PIVOT, false)
P1:SetAttribute("Cash", 6400)
P1:SetAttribute("Income", 120)
local hudSnap = snapshot(HUD)
startClient()

section("Config/Features : valeurs du dépôt")
check(Features.RobuxShop == false and Features.RobuxShopPreview == true, "RobuxShop = false, RobuxShopPreview = true")
check(Features.Index == true, "Index = true (L-071)")
check(Features.Rebirth == false and Features.RebirthPreview == true, "Rebirth = false, RebirthPreview = true")
check(not logHas("[Loader", "WARN", "client"), "aucun contrôleur en échec au chargement")
check(table.isfrozen(Features), "Features gelé (DeepFreeze)")

section("HUD : les trois boutons visibles")
for _, name in { "RobuxShopButton", "IndexButton", "RebirthButton" } do
	check(hudButton(HUD, name).Visible == true, `{name} visible`)
end
check(HUD.NightCountdown.Visible == true and HUD.ReturnBaseButton.Visible == true, "NightCountdown et ReturnBaseButton toujours affichés")
local changed = diffSnapshot(hudSnap, HUD, {
	[HUD.StatsPanel.Cash] = { Text = true },
	[HUD.StatsPanel.Income] = { Text = true },
	[HUD.StatsPanel.Speed] = { Text = true },
	[HUD.StatsPanel.Strength] = { Text = true },
	[HUD.StatsPanel.Damage] = { Text = true },
	[HUD.NightCountdown] = { Text = true },
	[HUD.ReturnBaseButton.Cooldown] = { Visible = true, Text = true },
})
check(#changed == 0, `HUD : aucun bouton caché ni retouché ({table.concat(changed, " ; ")})`)

section("Boutique Robux en vitrine : branchement")
local prompt = robuxCounter:FindFirstChild("RobuxShopPrompt")
check(prompt ~= nil and prompt.ActionText == "Shop" and prompt.ObjectText == "Robux Shop", "invite « Shop » / « Robux Shop » sur le comptoir RobuxShop")
check(ROBUX.Enabled == false, "écran fermé au départ")
check(ROBUX.Root.Window.List:FindFirstChild("Preview_1") == nil, "cartes d'exemple Preview_* retirées")

section("ouverture par le bouton du HUD : onglet Gamepasses")
click(hudButton(HUD, "RobuxShopButton"))
check(ROBUX.Enabled == true, "le bouton du HUD ouvre l'écran")
check(offerKeys(ROBUX) == "DoubleCash,DoubleTraining,AutoCollect,FastOpen,ExtraStands", `gamepasses codés, dans l'ordre : {offerKeys(ROBUX)}`)
local cash = cardNamed(ROBUX, "DoubleCash")
check(textOf(cash, "ItemName") == "×2 CASH" and textOf(cash, "Effect") == "Doubles all your income", "nom et ligne d'effet comme en vague 13")
check(textOf(cash, "Price") == "449", "prix de la Config")
check(cardNamed(ROBUX, "DoubleTraining").Icon.Image == "rbxassetid://106315635775683", "icône de la maquette (IconAsset)")
check(shown(cash, "BuyButton") and not shown(cash, "Owned"), "BuyButton visible, Owned caché")
advance(1.5)
check(textOf(cash, "Price") == "449", "toujours le prix de la Config (aucune lecture chez Roblox)")
check(#MARKET.infoCalls == 0, "aucun GetProductInfoAsync")

section("clic sur BuyButton : aucun achat, « Soon »")
clearLog()
click(cash:FindFirstChild("BuyButton", true))
check(#MARKET.prompts == 0, "aucune fenêtre d'achat (PromptGamePassPurchase)")
check(textOf(cash, "Price") == "Soon", `« Soon » à la place du prix : {textOf(cash, "Price")}`)
check(logHas("[RobuxShop] vitrine (Features.RobuxShop = false, RobuxShopPreview = true) : pas d'achat", "PRINT", "client"), "une ligne dans la sortie (Studio)")
advance(1)
check(textOf(cash, "Price") == "Soon", "encore « Soon » après 1 s (la mise à jour de chaque seconde le garde)")
advance(1.05)
check(textOf(cash, "Price") == "449", `le prix revient après 2 s : {textOf(cash, "Price")}`)
click(cash:FindFirstChild("BuyButton", true))
click(cash:FindFirstChild("BuyButton", true))
check(#MARKET.prompts == 0 and logCount("[RobuxShop] vitrine", "PRINT", "client") == 1, "clics répétés : toujours rien, une seule ligne dans la sortie")

section("onglet Argent")
click(ROBUX.Root.Tabs.CashTab)
check(offerKeys(ROBUX) == "Cash10,Cash60,Cash300", `packs d'argent : {offerKeys(ROBUX)}`)
local pack = cardNamed(ROBUX, "Cash10")
local amount = Format.money(Monetization.CashPackAmount(120, 10))
check(textOf(pack, "Effect") == `+{amount} · 10 min of income`, `montant d'après le revenu : {textOf(pack, "Effect")}`)
check(textOf(pack, "Price") == "49" and textOf(cardNamed(ROBUX, "Cash300"), "Price") == "799", "prix de la Config")
click(pack:FindFirstChild("BuyButton", true))
check(#MARKET.prompts == 0 and textOf(pack, "Price") == "Soon", "pack : aucun achat, « Soon »")
check(textOf(cardNamed(ROBUX, "Cash60"), "Price") == "199", "les autres cartes gardent leur prix")

section("onglets Boosts et Offers (serveur coupé)")
click(ROBUX.Root.Tabs.BoostsTab)
local openNow = cardNamed(ROBUX, "OpenNow")
check(offerKeys(ROBUX) == "OpenNow" and textOf(openNow, "Effect") == "No box is waiting" and not shown(openNow, "BuyButton"), "Ouvrir maintenant : « No box is waiting », pas de bouton")
click(ROBUX.Root.Tabs.OffersTab)
check(offerKeys(ROBUX) == "", "Offers vide : le pack de départ n'est proposé que par MonetizationService")

section("fermeture et réouverture")
click(ROBUX.Root.Window.CloseButton)
check(ROBUX.Enabled == false and offerKeys(ROBUX) == "", "CloseButton ferme l'écran (cartes retirées)")
prompt.Triggered:Fire(P1)
flush()
check(ROBUX.Enabled == true and offerKeys(ROBUX) == "", "l'invite du comptoir rouvre l'écran, sur le dernier onglet choisi (Offers)")
click(hudButton(HUD, "RobuxShopButton"))
check(ROBUX.Enabled == false, "un 2e appui sur le bouton du HUD le referme")
moveTo(FAR_SPOT + Vector3.new(500, 0, 0))
click(hudButton(HUD, "RobuxShopButton"))
check(ROBUX.Enabled == true, "il s'ouvre aussi loin du comptoir (partout, 5.9)")
check(#MARKET.prompts == 0 and #MARKET.infoCalls == 0, "en tout : aucun appel à MarketplaceService")

summary("scénario preview")
