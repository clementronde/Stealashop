--!nocheck
-- Scénario « refonte » (a207, vague 63, L-201 points 1 à 6) : vrais IndexService (serveur) et IndexController
-- (client) sur le faux UI_Index_v3 de lib67 refait par lib207 (script refonte_ui_index_v4 de Clément).
advance(1000)
startServer()
local Zones = sharedModule("Config/Zones")
local AlertBadge = sharedModule("AlertBadge", "client")
make("Decal", { Name = "ICON_TOOL_Wrench", Texture = "rbxassetid://9101" }, ICONS)

-- Zone 1 complète sauf la Carotte, zone 2 complète.
local data = newProfile()
local n = 0
for _, zone in { 1, 2 } do
	for _, item in Index.ByZone[zone] do
		if item.Id ~= "Z1_Carotte" then
			n += 1
			addItem(data, `a-{n}`, item.Id, nil, zone, 500)
		end
	end
end
local ada = join("Ada", data)
local playerGui = ada:FindFirstChild("PlayerGui")
local gui = refaireIndexV3(buildIndexV3Gui(playerGui))
local hud = make("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
local rail = make("Frame", { Name = "LeftRail" }, hud)
make("TextButton", { Name = "IndexButton", Text = "" }, rail)
hud.Parent = playerGui
watchPops()
advance(1.5)
startClient(ada)
advance(0.5)

local window = gui.Root.Window
local rewards = window.Rewards
local claim = rewards.ClaimButton
local grey, ready = claim.UIGradient, claim.ReadyGradient
local item = rewards.ItemReward
local function lit(alert)
	return alert.Visible == true and AlertBadge.IsOn(alert)
end

click(hud.LeftRail.IndexButton) -- l'en-tête se peint à l'ouverture
advance(0.5)

section("démarrage")
check(gui.Enabled == true, "Index ouvert")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(not logHas("IndexController", "WARN", "client"), "IndexController : aucun avertissement")

section("point 1 : ZoneName = la ville, ZoneTheme = le thème (Config/Zones)")
local wrong = {}
for zone = 2, 6 do
	local info = Zones[zone]
	local name, theme = refonteName(gui, zone), refonteTheme(gui, zone)
	if name ~= string.upper(info.City) or theme ~= string.upper(info.Theme) then
		table.insert(wrong, `{zone} : {name} / {theme}`)
	end
end
check(#wrong == 0, `zones 2 à 6 : ville et thème ({table.concat(wrong, " ; ")})`)
check(refonteName(gui, 2) == "LONDON" and refonteTheme(gui, 2) == "TOYS", `zone 2 : « {refonteName(gui, 2)} » / « {refonteTheme(gui, 2)} »`)
check(refonteName(gui, 4) == "LOS ANGELES" and refonteName(gui, 6) == "NEW YORK" and refonteTheme(gui, 6) == "BANK", "zones 4 et 6 : LOS ANGELES, NEW YORK / BANK")
check(Zones[1].City == nil and refonteName(gui, 1) == "MINI MART" and refonteTheme(gui, 1) == "KIOSK", `zone 1 sans ville : textes de Clément gardés (« {refonteName(gui, 1)} » / « {refonteTheme(gui, 1)} »)`)
check(gui.Root.Window.ListPanel.List.SecretsSection.ZoneArt.NameShade.ZoneName.Text == "SECRETS", "Secrets : nom de Clément gardé")

section("point 2 : ZoneBar.RewardIcon = l'objet de la zone, Unknown caché")
local bar1 = refonteSection(gui, 1).Content.ZoneBar
check(Index.ZoneRewardIcon(1) == "TOOL_Wrench" and bar1.RewardIcon.Image == "rbxassetid://9101", `zone 1 : icône ICON_TOOL_Wrench ({bar1.RewardIcon.Image})`)
check(bar1.RewardIcon.Unknown.Visible == false, "zone 1 : « ? » caché")
local missing = nil
for zone = 2, 6 do
	local iconName = Index.ZoneRewardIcon(zone)
	if missing == nil and (iconName == nil or ICONS:FindFirstChild("ICON_" .. iconName) == nil) then
		missing = zone
	end
end
if missing then
	local bar = refonteSection(gui, missing).Content.ZoneBar
	check(bar.RewardIcon.Image == "" and bar.RewardIcon.Unknown.Visible == true, `zone {missing} : icône pas livrée, le « ? » reste`)
end
local painted = {}
for zone = 1, 6 do
	if refonteSection(gui, zone).Content.ZoneBar.ZoneItem.Image ~= "" then
		table.insert(painted, zone)
	end
end
check(#painted == 0, `ZoneItem plus peint (zones peintes : {table.concat(painted, ", ")})`)

section("point 5 : compteur « N / 83 discovered »")
local counter = window.UnlockedBar.Counter.Text
local found, total = string.match(counter, "^(%d+) / (%d+) discovered$")
check(found ~= nil and tonumber(total) == Index.Total and tonumber(found) == n, `« {counter} » ({n} trouvés, total {Index.Total})`)

section("point 6 : LimitedButton caché")
check(gui.Root.Categories.LimitedButton.Visible == false, "LIMITED : caché tant que la catégorie n'existe pas")
check(gui.Root.Categories.NormalButton.Visible ~= false, "NORMAL : visible")

section("points 3 et 4 : zone 1 visible, en cours")
check(textOf(claim, "ClaimLabel") == "CLAIM!", `ClaimLabel de Clément (« {textOf(claim, "ClaimLabel")} »)`)
check(grey.Enabled == true and ready.Enabled == false and not lit(claim.ClaimAlert), "en cours : UIGradient, pas de ReadyGradient, ClaimAlert éteinte")
check(item.RewardCaption.Text == "WRENCH" and item.RewardIcon.Image == "rbxassetid://9101" and item.RewardIcon.Unknown.Visible == false, `ItemReward : « {item.RewardCaption.Text} », icône ICON_TOOL_Wrench, « ? » caché`)
check(rewards.Unused.SpeedReward.Visible == false and rewards.Unused.CashReward.Visible == false, "SpeedReward et CashReward cachés")

section("point 3 : zone 2 visible, prête")
voirZone(gui, 2)
check(ready.Enabled == true and grey.Enabled == false, "prête : ReadyGradient à la place de UIGradient")
check(lit(claim.ClaimAlert), "prête : ClaimAlert allumée")
check(item.RewardCaption.Text == string.upper(Index.ZoneRewardName(2)), `ItemReward : « {item.RewardCaption.Text} »`)

section("point 3 : zone 2 réclamée, « CLAIMED »")
advance(1.1)
claim.Activated:Fire()
flush()
advance(0.5)
check(ada:GetAttribute("IndexClaimed") == "2", "IndexClaimed « 2 »")
check(textOf(claim, "ClaimLabel") == "CLAIMED", `ClaimLabel « {textOf(claim, "ClaimLabel")} »`)
check(grey.Enabled == true and ready.Enabled == false and not lit(claim.ClaimAlert), "réclamée : UIGradient revient, ReadyGradient et ClaimAlert éteints")

section("retour sur la zone 1, puis complétée")
voirZone(gui, 1)
check(textOf(claim, "ClaimLabel") == "CLAIM!" and grey.Enabled == true and ready.Enabled == false, "zone 1 : « CLAIM! », gris")
IndexService.Discover(ada, "Z1_Carotte")
flush()
advance(0.2)
check(ready.Enabled == true and grey.Enabled == false and lit(claim.ClaimAlert), "zone 1 complète : prête")
local after = window.UnlockedBar.Counter.Text
check(after == string.format("%d / %d discovered", n + 1, Index.Total), `compteur « {after} »`)

check(not logHas("IndexController", "WARN", "client"), "IndexController : toujours aucun avertissement")
summary("scénario refonte")
