--!nocheck
-- Scénario « v4 » / « v4old » (a201, copie générée du scénario v4 d'a191 par patches/v4-*.sed) : UI_Index_v4,
-- la récompense de zone n'est qu'un objet (L-192). v4 : Footer.ItemReward (RewardIcon, RewardCaption) écrit,
-- CashReward et SpeedReward d'avant cachés. v4old : écran sans ItemReward, sans erreur.
advance(1000)
startServer()
local Zones = sharedModule("Config/Zones")
local Format = sharedModule("Format")

-- Icône de boutique de la Wrench et façade de la zone 1 livrées ; celle de la zone 2 pas encore.
make("Decal", { Name = "ICON_TOOL_Wrench", Texture = "rbxassetid://9101" }, ICONS)
make("Decal", { Name = "UI_ZoneArt_Z1", Texture = "rbxassetid://9201" }, ICONS)

local function buildV4(playerGui)
	local gui = make("ScreenGui", { Name = "UI_Index_v4", Enabled = false, ResetOnSpawn = false })
	local window = make("Frame", { Name = "Window" }, gui)
	local header = make("Frame", { Name = "Header" }, window)
	make("TextLabel", { Name = "Title", Text = "INDEX" }, header)
	local close = make("TextButton", { Name = "CloseButton", Text = "" }, window)
	make("TextLabel", { Name = "XLabel", Text = "X" }, close)
	local bar = make("Frame", { Name = "UnlockedBar" }, window)
	make("ImageLabel", { Name = "BookIcon" }, bar)
	make("TextLabel", { Name = "Counter", Text = "Unlocked: 0/0" }, bar)
	local art = make("ImageLabel", { Name = "ZoneArt", Image = "rbxassetid://1" }, window)
	make("TextLabel", { Name = "ZoneName", Text = "ZONE" }, art)
	make("TextLabel", { Name = "ZoneTheme", Text = "Theme" }, art)
	local zoneBar = make("Frame", { Name = "ZoneBar" }, window)
	make("Frame", { Name = "Fill", Size = UDim2.new(0.3, 0, 1, -4) }, zoneBar)
	make("TextLabel", { Name = "ZoneCount", Text = "0/0" }, zoneBar)
	local tabs = make("Frame", { Name = "Tabs" }, window)
	for _, name in { "Zone1Tab", "Zone2Tab", "Zone3Tab", "Zone4Tab", "Zone5Tab", "Zone6Tab", "SecretsTab" } do
		local tab = make("TextButton", { Name = name, Text = "" }, tabs)
		make("ImageLabel", { Name = "TabIcon" }, tab)
		make("TextLabel", { Name = "TabLabel", Text = name }, tab)
		make("Frame", { Name = "Selected", Visible = name == "Zone1Tab" }, tab)
		local alert = make("Frame", { Name = "ZoneAlert", Visible = false }, tab)
		make("UIScale", { Name = "Pulse" }, alert)
	end
	local cards = make("Frame", { Name = "Cards" }, window)
	make("UIGridLayout", { Name = "UIGridLayout" }, cards)
	local card = make("TextButton", { Name = "Template", Visible = false, Text = "" }, cards)
	local clip = make("Frame", { Name = "Clip" }, card)
	make("ImageLabel", { Name = "Rays", ImageColor3 = Color3.new(1, 1, 1) }, clip)
	make("UIGradient", { Name = "RarityGradient" }, clip)
	make("ImageLabel", { Name = "Shine" }, clip)
	make("ImageLabel", { Name = "Icon", Image = "" }, card)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, card)
	make("Frame", { Name = "HoverOutline", Visible = false }, card)
	local footer = make("Frame", { Name = "Footer" }, window)
	local pager = make("Frame", { Name = "Pager" }, footer)
	make("TextButton", { Name = "PrevButton", Text = "<" }, pager)
	make("TextButton", { Name = "NextButton", Text = ">" }, pager)
	make("TextLabel", { Name = "PageLabel", Text = "1/1" }, pager)
	local claim = make("TextButton", { Name = "ClaimButton", Text = "" }, footer)
	make("ImageLabel", { Name = "RewardIcon", Image = "rbxassetid://2" }, claim)
	make("TextLabel", { Name = "RewardCaption", Text = "REWARD" }, claim)
	local alert = make("Frame", { Name = "ClaimAlert", Visible = false }, claim)
	make("UIScale", { Name = "Pulse" }, alert)
	local item = make("Frame", { Name = "ItemReward" }, footer)
	make("ImageLabel", { Name = "RewardIcon", Image = "rbxassetid://3" }, item)
	make("TextLabel", { Name = "RewardCaption", Text = "ITEM" }, item)
	local oldCash = make("Frame", { Name = "CashReward" }, footer)
	make("TextLabel", { Name = "Amount", Text = "+$0" }, oldCash)
	local oldSpeed = make("Frame", { Name = "SpeedReward" }, footer)
	make("TextLabel", { Name = "Amount", Text = "+0" }, oldSpeed)
	-- Place et position absolue (lues par le tremblement du refus et l'entrée des cadres de UI/Motion).
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") then
			d.Position = UDim2.new(0, 0, 0, 0)
			d.AbsolutePosition = Vector2.new(0, 0)
		end
	end
	gui.Parent = playerGui
	flush()
	return gui
end
local function v4Cards(gui)
	local out = {}
	for _, child in gui.Window.Cards:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Item_" then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end

local ada = join("Ada", profileWith({ 1 }, "Z1_Carotte"))
advance(1.5)
local playerGui = ada:FindFirstChildOfClass("PlayerGui")
local hud = buildHud(playerGui)
local legacy = buildIndexGui(playerGui)
local gui = buildV4(playerGui)
startClient(ada)
advance(0.5)

section("v4 branchée avant l'ancien écran")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(gui.Enabled == false and legacy.Enabled == false, "les deux écrans éteints")
click(hud.LeftRail.IndexButton)
advance(0.5)
check(gui.Enabled == true and legacy.Enabled == false, "IndexButton : la v4 s'ouvre, pas l'ancien")

section("zone 1 : page 1 de 2")
local zone1 = Index.ByZone[1]
local cards = v4Cards(gui)
check(#zone1 == 13 and #cards == 8, `8 cartes sur la page 1 (trouvé {#cards})`)
check(gui.Window.Footer.Pager.PageLabel.Text == "1/2", `PageLabel « {gui.Window.Footer.Pager.PageLabel.Text} »`)
local first = zone1[1]
check(cards[1].Name == string.format("Item_%02d_%s", 1, first.Id) and cards[1].Visible == true, "1re carte : le 1er objet de la zone")
check(cards[1].ItemName.Text == first.DisplayName and cards[1].Icon.Image == (ICON_TEXTURE[first.Id] or ""), "trouvé : son nom et son icône")
check(sameColor(cards[1].Clip.BackgroundColor3, Rarities.ById[first.Rarity].Color) and cards[1]:GetAttribute("Rarity") == first.Rarity, "fond Clip à la couleur de la rareté, attribut Rarity")
check(gui.Window.UnlockedBar.Counter.Text == string.format("Unlocked: %d/%d", 12, Index.Total), `Counter « {gui.Window.UnlockedBar.Counter.Text} »`)
check(gui.Window.ZoneBar.ZoneCount.Text == "12/13" and near(gui.Window.ZoneBar.Fill.Size.X.Scale, 12 / 13, 1e-6), "ZoneBar : « 12/13 », Fill à 12/13")
check(gui.Window.ZoneArt.ZoneName.Text == string.upper(Zones[1].City or Zones[1].Theme), `ZoneName « {gui.Window.ZoneArt.ZoneName.Text} »`)
check(gui.Window.ZoneArt.ZoneTheme.Text == "MINI MART · KIOSK", `ZoneTheme « {gui.Window.ZoneArt.ZoneTheme.Text} »`)
check(gui.Window.ZoneArt.Image == "rbxassetid://9201", "façade UI_ZoneArt_Z1 posée")
local caption = gui.Window.Footer.ClaimButton.RewardCaption
check(caption.Text == Index.ZoneRewardText(1) and gui.Window.Footer.ClaimButton.RewardIcon.Image == "rbxassetid://9101", `récompense : « {caption.Text} », icône ICON_TOOL_Wrench`)
check(caption.Text == "+WRENCH", `ClaimButton.RewardCaption « {caption.Text} »`)
local footerV4 = gui.Window.Footer
check(footerV4.ItemReward.RewardCaption.Text == "Wrench" and footerV4.ItemReward.RewardIcon.Image == "rbxassetid://9101", `ItemReward : « {footerV4.ItemReward.RewardCaption.Text} », icône ICON_TOOL_Wrench`)
check(footerV4.CashReward.Visible == false and footerV4.SpeedReward.Visible == false and footerV4.CashReward.Amount.Text == "+$0" and footerV4.SpeedReward.Amount.Text == "+0", "CashReward et SpeedReward cachés, plus écrits")
check(gui.Window.Footer.ClaimButton.ClaimAlert.Visible == false and gui.Window.Tabs.Zone1Tab.ZoneAlert.Visible == false, "zone pas complète : pastilles éteintes")

section("pages : suivante, en boucle")
click(gui.Window.Footer.Pager.NextButton)
cards = v4Cards(gui)
check(#cards == 5 and gui.Window.Footer.Pager.PageLabel.Text == "2/2", `page 2 : 5 cartes ({#cards})`)
local carrot
for _, card in cards do
	if string.find(card.Name, "Z1_Carotte", 1, true) then
		carrot = card
	end
end
check(carrot ~= nil and carrot.ItemName.Text == "???", "la Carotte pas trouvée : « ??? »")
check(carrot ~= nil and not sameColor(carrot.Icon.ImageColor3, Color3.new(1, 1, 1)), "silhouette")
click(gui.Window.Footer.Pager.NextButton)
check(#v4Cards(gui) == 8 and gui.Window.Footer.Pager.PageLabel.Text == "1/2", "suivante sur la dernière : retour à la page 1")
click(gui.Window.Footer.Pager.PrevButton)
check(gui.Window.Footer.Pager.PageLabel.Text == "2/2", "précédente sur la 1re : la dernière")

section("réclamer une zone pas complète : refus, rien d'envoyé")
local sent = #serverCalls("ClaimIndexReward")
click(gui.Window.Footer.ClaimButton)
check(#serverCalls("ClaimIndexReward") == sent, "rien d'envoyé")

section("zone complétée : pastilles, puis réclamée")
IndexService.Discover(ada, "Z1_Carotte")
flush()
advance(0.2)
check(gui.Window.Tabs.Zone1Tab.ZoneAlert.Visible == true and gui.Window.Footer.ClaimButton.ClaimAlert.Visible == true, "ZoneAlert de Zone1Tab et ClaimAlert allumées")
check(carrot == nil or isDestroyed(carrot) or v4Cards(gui)[1] ~= nil, "cartes toujours là")
check(gui.Window.ZoneBar.ZoneCount.Text == "13/13", "« 13/13 »")
local cash0 = dataOf(ada).Cash
click(gui.Window.Footer.ClaimButton)
check(#serverCalls("ClaimIndexReward") == sent + 1 and serverCalls("ClaimIndexReward")[sent + 1].args[1] == 1, "ClaimIndexReward(1) envoyé")
advance(0.5)
check(dataOf(ada).Cash == cash0 and dataOf(ada).Stats.Speed == 0 and countOf(dataOf(ada).Tools.Owned, "Wrench") == 1, "le serveur donne l'objet seul (ni argent, ni Vitesse)")
check(caption.Text == "Claimed!" and gui.Window.Footer.ClaimButton.ClaimAlert.Visible == false and gui.Window.Tabs.Zone1Tab.ZoneAlert.Visible == false, "« Claimed! », pastilles éteintes")

section("onglets : zone 2, puis Secrets")
click(gui.Window.Tabs.Zone2Tab)
cards = v4Cards(gui)
check(#cards == 8 and string.find(cards[1].Name, Index.ByZone[2][1].Id, 1, true) ~= nil, "zone 2 : ses 8 premières cartes")
check(gui.Window.Tabs.Zone2Tab.Selected.Visible == true and gui.Window.Tabs.Zone1Tab.Selected.Visible == false, "Selected sur Zone2Tab")
check(gui.Window.ZoneArt.ZoneName.Text == "LONDON" and gui.Window.ZoneArt.Image == "rbxassetid://1", "ZoneName « LONDON » ; façade pas livrée : l'image de l'écran")
check(gui.Window.Footer.Pager.PageLabel.Text == string.format("1/%d", math.ceil(#Index.ByZone[2] / 8)), "page 1 de la zone 2")
check(caption.Text == Index.ZoneRewardText(2) and gui.Window.Footer.ClaimButton.RewardIcon.Image == "rbxassetid://9101", "zone 2 : sa récompense, icône d'avant gardée (Flamme pas livrée)")
check(gui.Window.Footer.ItemReward.RewardCaption.Text == "Flame" and gui.Window.Footer.ItemReward.RewardIcon.Image == "rbxassetid://9101", "zone 2 : ItemReward « Flame », icône d'avant gardée")
check(cards[1].ItemName.Text == "???", "zone 2 : rien de trouvé")
click(gui.Window.Tabs.SecretsTab)
check(gui.Window.Footer.ClaimButton.Visible == false and gui.Window.ZoneArt.ZoneName.Text == "SECRETS", "Secrets : pas de récompense, « SECRETS »")
check(#v4Cards(gui) == math.min(8, #Index.Secrets), "les Secrets en cartes")
click(gui.Window.Tabs.Zone1Tab)
check(gui.Window.Footer.ClaimButton.Visible == true, "retour en zone : ClaimButton remontré")

section("fermeture")
click(gui.Window.CloseButton)
advance(1)
check(gui.Enabled == false and #v4Cards(gui) == 0, "CloseButton : éteint, cartes retirées")

section("sans la v4 : l'ancien UI_Index")
gui:Destroy()
flush()
click(hud.LeftRail.IndexButton)
advance(0.5)
check(legacy.Enabled == true and #cardsOf(legacy) > 0, `l'ancien écran s'ouvre, ses cartes ({#cardsOf(legacy)})`)
check(textOf(legacy, "RewardLabel") == Index.ZoneRewardText(1) .. " EARNED", `RewardLabel « {textOf(legacy, "RewardLabel")} »`)

summary("scénario v4")
