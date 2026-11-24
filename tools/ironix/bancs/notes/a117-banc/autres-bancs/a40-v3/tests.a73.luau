--!nocheck
-- Scénario « a73 » (2026-11-11, vague 24, retours de Cantin) : dans UI_Index_v3, ZoneName = les magasins
-- PNJ de chaque zone (Config/Zones.Stores) ; Rewards.SpeedReward.Icon vide reçoit l'icône de vitesse du
-- HUD (StatsPanel.SpeedRow.SpeedIcon.IconImage), une icône posée par Clément n'est pas remplacée ;
-- UI_HUD.LeftRail.IndexButton (PC) et UI_HUD.LeftRailTouch.IndexButton (téléphone) ouvrent tous les deux
-- l'Index (relevé de wave24-studio.md : chaque bouton existe en deux exemplaires).

advance(1000)
startServer()
local Zones = sharedModule("Config/Zones")
local data = newProfile()
local ada = join("Ada", data)
local playerGui = ada:FindFirstChild("PlayerGui")
local gui = buildIndexV3Gui(playerGui)
local SPEED_ICON = "rbxassetid://80577187405028" -- relevé de Studio : SpeedRow.SpeedIcon.IconImage
local CASH_ICON = "rbxassetid://138179722277427" -- relevé de Studio : CashReward.Icon de Clément
gui.Root.Window.Rewards.CashReward.Icon.Image = CASH_ICON
gui.Root.Window.Rewards.SpeedReward.Icon.Image = "" -- relevé de Studio : vide (le faux Roblox ne pose pas la valeur par défaut)
local hud = buildHud(playerGui)
-- LeftRailTouch (téléphone) : mêmes boutons que LeftRail ; StatsPanel.SpeedRow comme dans Studio.
local touch = make("Frame", { Name = "LeftRailTouch" }, hud)
for _, spec in { { "RobuxShopButton", "SHOP" }, { "IndexButton", "INDEX" }, { "RebirthButton", "REBIRTH" }, { "InventoryButton", "INVENTORY" } } do
	local button = make("TextButton", { Name = spec[1], Text = "" }, touch)
	make("ImageLabel", { Name = "Icon" }, button)
	make("TextLabel", { Name = "Label", Text = spec[2] }, button)
end
local stats = make("Frame", { Name = "StatsPanel" }, hud)
local speedRow = make("Frame", { Name = "SpeedRow" }, stats)
local speedIcon = make("Frame", { Name = "SpeedIcon" }, speedRow)
make("ImageLabel", { Name = "IconImage", Image = SPEED_ICON }, speedIcon)
local badge = make("Frame", { Name = "PlusBadge" }, speedIcon)
make("ImageLabel", { Name = "PlusImage", Image = "rbxassetid://106853231416766" }, badge)
make("TextLabel", { Name = "Speed", Text = "16" }, speedRow)
advance(1.5)
startClient(ada)

local window = gui.Root.Window
local list = window.ListPanel.List
local rewards = window.Rewards

section("IndexButton des deux colonnes")
check(gui.Enabled == false, "Index fermé au départ")
click(touch.IndexButton)
check(gui.Enabled == true, "LeftRailTouch.IndexButton (téléphone) ouvre l'Index")
click(hud.LeftRail.IndexButton)
check(gui.Enabled == false, "LeftRail.IndexButton (PC) le referme (même bascule)")
click(hud.LeftRail.IndexButton)
check(gui.Enabled == true, "LeftRail.IndexButton le rouvre")
click(touch.IndexButton)
check(gui.Enabled == false, "LeftRailTouch.IndexButton le referme")
click(touch.IndexButton)

section("ZoneName : les magasins de la zone")
for zone = 1, 6 do
	local wanted = string.upper(table.concat(Zones[zone].Stores, "\n"))
	local got = textOf(list[`Zone{zone}Section`], "ZoneName")
	check(got == wanted, `zone {zone} : « {string.gsub(got or "nil", "\n", " / ")} »`)
end
check(textOf(list.Zone1Section, "ZoneName") == "MINI MART\nKIOSK", "zone 1 : « MINI MART » puis « KIOSK »")
check(textOf(list.SecretsSection, "ZoneName") == "SECRETS", "Secrets : texte de Clément gardé")

section("Rewards : icône du +3 %")
check(rewards.SpeedReward.Icon.Image == SPEED_ICON, `SpeedReward.Icon = l'icône de vitesse du HUD (« {rewards.SpeedReward.Icon.Image} »)`)
check(rewards.CashReward.Icon.Image == CASH_ICON, "CashReward.Icon de Clément pas touché")
check(textOf(rewards.SpeedReward, "Amount") == "+3%", "SpeedReward.Amount « +3% »")
rewards.SpeedReward.Icon.Image = "rbxassetid://1"
click(touch.IndexButton)
click(touch.IndexButton)
check(rewards.SpeedReward.Icon.Image == "rbxassetid://1", "icône de vitesse posée par Clément : gardée")

summary("scénario a73")
