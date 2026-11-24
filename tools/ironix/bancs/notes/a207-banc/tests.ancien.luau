--!nocheck
-- Scénario « ancien » (a207, vague 63) : le faux UI_Index_v3 d'avant la refonte (lib67, sans ZoneTheme, RewardIcon,
-- ItemReward, ReadyGradient ni LimitedButton) marche sans erreur : magasins dans ZoneName comme avant, ZoneItem
-- peint, compteur et « CLAIMED » nouveaux.
advance(1000)
startServer()
local AlertBadge = sharedModule("AlertBadge", "client")
make("Decal", { Name = "ICON_TOOL_Wrench", Texture = "rbxassetid://9101" }, ICONS)
local data = newProfile()
local n = 0
for _, item in Index.ByZone[2] do
	n += 1
	addItem(data, `a-{n}`, item.Id, nil, 2, 500)
end
local ada = join("Ada", data)
local playerGui = ada:FindFirstChild("PlayerGui")
local gui = buildIndexV3Gui(playerGui)
local hud = make("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
local rail = make("Frame", { Name = "LeftRail" }, hud)
make("TextButton", { Name = "IndexButton", Text = "" }, rail)
hud.Parent = playerGui
watchPops()
advance(1.5)
startClient(ada)
advance(0.5)
local window = gui.Root.Window
local list = window.ListPanel.List
local claim = window.Rewards.ClaimButton

click(hud.LeftRail.IndexButton) -- l'en-tête se peint à l'ouverture
advance(0.5)

section("démarrage sans les nouveaux éléments")
check(gui.Enabled == true, "Index ouvert")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(not logHas("IndexController", "WARN", "client"), "IndexController : aucun avertissement")
local zoneName = list.Zone2Section.ZoneArt.ZoneName.Text
check(zoneName ~= "" and zoneName ~= "LONDON", `sans ZoneTheme : ZoneName comme avant (« {zoneName} »)`)
check(list.Zone1Section.ZoneArt.ZoneName.Text ~= "", "zone 1 : un nom")
check(string.match(window.UnlockedBar.Counter.Text, "^%d+ / %d+ discovered$") ~= nil, `compteur « {window.UnlockedBar.Counter.Text} »`)
check(gui.Root.Categories.SecretsButton ~= nil, "arbre d'avant intact")

section("zone 2 prête puis réclamée")
voirZone(gui, 2)
check(textOf(claim, "ClaimLabel") == "Claim!" and AlertBadge.IsOn(claim.ClaimAlert), "zone 2 : « Claim! », ClaimAlert allumée")
advance(1.1)
claim.Activated:Fire()
flush()
advance(0.5)
check(ada:GetAttribute("IndexClaimed") == "2" and textOf(claim, "ClaimLabel") == "CLAIMED", `réclamée : « {textOf(claim, "ClaimLabel")} »`)
voirZone(gui, 1)
check(textOf(claim, "ClaimLabel") == "Claim!", "zone 1 : « Claim! » revient")
check(not logHas("IndexController", "WARN", "client"), "IndexController : toujours aucun avertissement")
summary("scénario ancien")
