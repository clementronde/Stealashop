--!nocheck
-- Scénario « crate » (pre.live.luau, pre.crate.luau) : caisse allumée, chances posées, Roblox la permet
-- (PolicyService). Section Crate visible, chances, nombre de caisses, ancien prix (caché sans remise),
-- OffersTab jusqu'à la caisse ; Crate.Ready = false : « Soon », aucune fenêtre d'achat.

local HUD = buildHud(PLAYER_GUI)
local V2 = buildRobuxShopV2(PLAYER_GUI)
P1:SetAttribute("Income", 100)
addGlow()
startClient()

section("caisse permise")
check(Features.RobuxCrate == true and #Monetization.Crate.Odds == 6 and Monetization.Crate.Ready == false, "RobuxCrate = true, 6 chances, Ready = false")
check(POLICY.calls == 1, `PolicyService lu une fois ({POLICY.calls})`)
click(hudButton(HUD, "RobuxShopButton"))
advance(0.5)
check(v2El(V2, "Crate").Visible == true, "section Crate visible")
check(v2El(V2, "Featured").Visible == false, "sans pack de départ : Featured caché")
local oddsOk = true
for index, text in CRATE_ODDS_TEXT do
	oddsOk = oddsOk and textOf(v2El(V2, `Crate.Odd_{index}`), "Chance") == text
end
check(oddsOk, `chances : {textOf(v2El(V2, "Crate.Odd_1"), "Chance")} … {textOf(v2El(V2, "Crate.Odd_6"), "Chance")}`)
local b1, b2, b3 = v2El(V2, "Crate.BuyButton1"), v2El(V2, "Crate.BuyButton2"), v2El(V2, "Crate.BuyButton3")
check(textOf(b1, "Count") == "1 Crate" and textOf(b2, "Count") == "3 Crates" and textOf(b3, "Count") == "10 Crates", `Count : {textOf(b1, "Count")}, {textOf(b2, "Count")}, {textOf(b3, "Count")}`)
check(textOf(b1, "Price") == "99" and textOf(b2, "Price") == "249" and textOf(b3, "Price") == "799", "prix 99 / 249 / 799")
check(b1:FindFirstChild("OldPrice").Visible == false, "lot de 1 : pas de remise, OldPrice caché")
check(b2:FindFirstChild("OldPrice").Visible == true and textOf(b2, "OldPrice") == "297", `lot de 3 : OldPrice 297 ({textOf(b2, "OldPrice")})`)
check(b3:FindFirstChild("OldPrice").Visible == true and textOf(b3, "OldPrice") == "990", `lot de 10 : OldPrice 990 ({textOf(b3, "OldPrice")})`)

section("onglet Offers : la caisse")
clickTab(V2, "CashTab")
check(clickTab(V2, "OffersTab") == V2_OFFSETS.Crate, `OffersTab : List jusqu'à Crate ({v2El(V2, "List").CanvasPosition.Y})`)
P1:SetAttribute("StarterPackEndsAt", serverTime() + 600)
flush()
check(v2El(V2, "Featured").Visible == true and v2El(V2, "Crate").Visible == true, "pack de départ et caisse ensemble")
clickTab(V2, "BoostsTab")
check(clickTab(V2, "OffersTab") == V2_OFFSETS.Crate, "OffersTab : toujours la caisse d'abord")

section("lots pas codés : « Soon »")
click(b2)
check(textOf(b2, "Price") == "Soon", "lot de 3 : « Soon »")
check(#MARKET.prompts == 0 and GLOW.calls == 0, "aucune fenêtre d'achat, pas de lueur (Ready = false, même avec un Id)")
advance(2.5)
check(textOf(b2, "Price") == "249", "le prix revient")

check(not logHas("[RobuxShop]", "WARN", "client"), "aucun avertissement de RobuxShop")
summary("scénario crate")
