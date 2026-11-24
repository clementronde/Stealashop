--!nocheck
-- Scénario « live » (pre.live.luau) : boutique ouverte, Ids posés. Fenêtres d'achat de Roblox depuis la v2,
-- lueur d'achat (PurchaseGlow d'a209) seulement avec une vraie fenêtre ; boosts du HUD et lots de la caisse
-- pas codés : « Soon », rien de vendu ; Id à 0 : « Soon ».

local HUD = buildHud(PLAYER_GUI)
local V2 = buildRobuxShopV2(PLAYER_GUI)
P1:SetAttribute("Income", 100)
P1:SetAttribute("StarterPackEndsAt", 1e9)
addGlow()
startClient()

section("boutique ouverte, v2")
check(Features.RobuxShop == true and Features.RobuxCrate == false, "RobuxShop = true, RobuxCrate = false")
click(hudButton(HUD, "RobuxShopButton"))
advance(0.5)
check(V2.Enabled == true and v2El(V2, "Featured").Visible == true and v2El(V2, "Crate").Visible == false, "v2 ouverte : Featured visible, Crate caché")
check(POLICY.calls == 0, "caisse coupée : PolicyService jamais appelé")

section("boosts du HUD : pas codés")
click(v2Card(V2, "SpeedBoost"):FindFirstChild("BuyButton"))
click(v2Card(V2, "SleepGuards"):FindFirstChild("BuyButton"))
check(textOf(v2Card(V2, "SpeedBoost"), "Price") == "Soon" and textOf(v2Card(V2, "SleepGuards"), "Price") == "Soon", "×2 Speed et zZz : « Soon »")
check(#MARKET.prompts == 0 and GLOW.calls == 0, "aucune fenêtre d'achat, pas de lueur")

section("Id à 0 : « Soon »")
click(v2Card(V2, "Cash30"):FindFirstChild("BuyButton"))
check(textOf(v2Card(V2, "Cash30"), "Price") == "Soon" and #MARKET.prompts == 0 and GLOW.calls == 0, "pack 30 min (Id 0) : « Soon », rien d'ouvert, pas de lueur")

section("vraies fenêtres d'achat")
click(v2Card(V2, "DoubleCash"):FindFirstChild("BuyButton"))
local last = MARKET.prompts[#MARKET.prompts]
check(#MARKET.prompts == 1 and last.kind == "GamePass" and last.id == 9001, "×2 Cash : fenêtre du gamepass 9001")
check(GLOW.calls == 1, `lueur d'achat montrée ({GLOW.calls})`)
click(v2Card(V2, "Cash720"):FindFirstChild("BuyButton"))
last = MARKET.prompts[#MARKET.prompts]
check(#MARKET.prompts == 2 and last.kind == "Product" and last.id == 8010 and GLOW.calls == 2, "pack 12 h : produit 8010, lueur")
click(v2El(V2, "Featured.BuyButton"))
last = MARKET.prompts[#MARKET.prompts]
check(#MARKET.prompts == 3 and last.kind == "Product" and last.id == 8001 and GLOW.calls == 3, "pack de départ (Featured) : produit 8001, lueur")

section("gamepass possédé")
P1:SetAttribute("PassDoubleCash", true)
flush()
check(v2Card(V2, "DoubleCash"):FindFirstChild("Owned").Visible == true and v2Card(V2, "DoubleCash"):FindFirstChild("BuyButton").Visible == false, "×2 Cash possédé : Owned, plus de bouton")

section("sans module PurchaseGlow")
CONTROLLERS.UI.PurchaseGlow:Destroy()
click(v2Card(V2, "DoubleTraining"):FindFirstChild("BuyButton"))
check(#MARKET.prompts == 4 and MARKET.prompts[4].id == 9002 and GLOW.calls == 3, "fenêtre d'achat ouverte quand même, sans lueur ni erreur")

check(not logHas("[RobuxShop]", "WARN", "client"), "aucun avertissement de RobuxShop")
summary("scénario live")
