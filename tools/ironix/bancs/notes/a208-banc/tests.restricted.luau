--!nocheck
-- Scénarios « restricted » et « policyfail » (pre.live, pre.crate, puis pre.restricted ou pre.policyfail) :
-- caisse allumée et chances posées, mais Roblox interdit les objets payants au hasard pour ce joueur
-- (ArePaidRandomItemsRestricted) ou PolicyService ne répond pas : la section Crate reste cachée.

local HUD = buildHud(PLAYER_GUI)
local V2 = buildRobuxShopV2(PLAYER_GUI)
P1:SetAttribute("Income", 100)
startClient()

section(`caisse cachée ({POLICY_CASE})`)
check(Features.RobuxCrate == true and #Monetization.Crate.Odds == 6, "RobuxCrate = true, chances posées")
check(POLICY.calls == 1, `PolicyService appelé une fois ({POLICY.calls})`)
click(hudButton(HUD, "RobuxShopButton"))
advance(0.5)
check(V2.Enabled == true and v2El(V2, "Crate").Visible == false, "section Crate cachée")
check(clickTab(V2, "OffersTab") == V2_OFFSETS.GamepassesSection, "OffersTab sans pack de départ : les gamepasses")
P1:SetAttribute("StarterPackEndsAt", serverTime() + 600)
flush()
check(v2El(V2, "Featured").Visible == true and v2El(V2, "Crate").Visible == false, "pack de départ : Featured visible, Crate toujours caché")
clickTab(V2, "CashTab")
check(clickTab(V2, "OffersTab") == V2_OFFSETS.Featured, "OffersTab : Featured")
advance(5)
check(v2El(V2, "Crate").Visible == false and POLICY.calls == 1, "toujours cachée, PolicyService pas relu")
check(#MARKET.prompts == 0, "aucune fenêtre d'achat")
check(not logHas("[RobuxShop]", "WARN", "client"), "aucun avertissement de RobuxShop")
summary(`scénario {POLICY_CASE}`)
