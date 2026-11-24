--!nocheck
---------------------------------------------------------------- a207 (vague 63, L-201) : UI_Index_v3 refait
-- refaireIndexV3(gui) passe le faux UI_Index_v3 de lib67 (a117) à l'écran refait par le script de Clément
-- tools/clement/refonte_ui_index_v4.luau (relevé du 2026-11-16) : ZoneName sous ZoneArt.NameShade avec ZoneTheme,
-- ZoneBar.RewardIcon (+ Unknown), Rewards.ItemReward (RewardIcon + Unknown, RewardCaption « ??? »), SpeedReward et
-- CashReward dans Rewards.Unused, ClaimButton avec UIGradient (gris) et ReadyGradient (vert, Enabled = false),
-- ClaimLabel « CLAIM! », Categories.LimitedButton (copie de NormalButton, pastille LimitedAlert), SecretsButton dans
-- Categories.Unused, MutationTabs et MutationCaption dans Root.Unused, ClaimAllButton caché, Counter
-- « 23 / 83 discovered », attribut RefonteV4.
REFONTE_GREY = ColorSequence.new(Color3.fromHex("9a9a9a"), Color3.fromHex("6e6e6e"))
REFONTE_GREEN = ColorSequence.new(Color3.fromHex("6be35b"), Color3.fromHex("2f9e2a"))
REFONTE_ZONE1 = { "MINI MART", "KIOSK" }

local function unknownIn(parent)
	return make("ImageLabel", { Name = "Unknown", Image = "rbxassetid://7001", Visible = true }, parent)
end

function refaireIndexV3(gui)
	local root = gui.Root
	local window = root.Window
	local list = window.ListPanel.List
	for index, name in V3_SECTIONS do
		local section = list[name]
		local art = section.ZoneArt
		local shade = make("Frame", { Name = "NameShade" }, art)
		art.ZoneName.Parent = shade
		local theme = make("TextLabel", { Name = "ZoneTheme", Text = "" }, shade)
		if index == 1 then
			shade.ZoneName.Text = REFONTE_ZONE1[1]
			theme.Text = REFONTE_ZONE1[2]
		end
		local bar = section.Content.ZoneBar
		bar.ZoneItem.ImageTransparency = 1
		local icon = make("ImageLabel", { Name = "RewardIcon", Image = "" }, bar)
		unknownIn(icon)
	end
	local rewards = window.Rewards
	local unusedRewards = make("Frame", { Name = "Unused", Visible = false }, rewards)
	rewards.SpeedReward.Parent = unusedRewards
	rewards.CashReward.Parent = unusedRewards
	local itemReward = make("Frame", { Name = "ItemReward" }, rewards)
	local rewardIcon = make("ImageLabel", { Name = "RewardIcon", Image = "" }, itemReward)
	unknownIn(rewardIcon)
	make("TextLabel", { Name = "RewardCaption", Text = "???" }, itemReward)
	local claim = rewards.ClaimButton
	make("UIGradient", { Name = "UIGradient", Color = REFONTE_GREY, Enabled = true }, claim)
	make("UIGradient", { Name = "ReadyGradient", Color = REFONTE_GREEN, Enabled = false }, claim)
	claim.ClaimLabel.Text = "CLAIM!"
	local categories = root.Categories
	local limited = make("TextButton", { Name = "LimitedButton", Text = "", LayoutOrder = 4, Visible = true }, categories)
	make("Frame", { Name = "Shade", BackgroundTransparency = 1 }, limited)
	make("TextLabel", { Name = "Label", Text = "LIMITED" }, limited)
	make("Frame", { Name = "Selected", Visible = false }, limited)
	v3Alert("LimitedAlert", limited)
	local unusedCategories = make("Frame", { Name = "Unused", Visible = false }, categories)
	categories.SecretsButton.Parent = unusedCategories
	local unusedRoot = make("Frame", { Name = "Unused", Visible = false }, root)
	root.MutationTabs.Parent = unusedRoot
	root.MutationCaption.Parent = unusedRoot
	window.UnlockedBar.ClaimAllButton.Visible = false
	window.UnlockedBar.Counter.Text = "23 / 83 discovered"
	gui:SetAttribute("RefonteV4", true)
	return gui
end

-- Section de la zone `zone` (Zone<n>Section) et ses éléments refaits.
function refonteSection(gui, zone)
	return gui.Root.Window.ListPanel.List[`Zone{zone}Section`]
end
function refonteName(gui, zone)
	return refonteSection(gui, zone).ZoneArt.NameShade.ZoneName.Text
end
function refonteTheme(gui, zone)
	return refonteSection(gui, zone).ZoneArt.NameShade.ZoneTheme.Text
end
-- Fait voir la zone `zone` en haut de la liste (même méthode que tests.a117index d'a117).
function voirZone(gui, zone)
	local list = gui.Root.Window.ListPanel.List
	for index, name in V3_SECTIONS do
		list[name].AbsolutePosition = Vector2.new(0, 100 + (index - zone) * 400)
	end
	list.CanvasPosition = Vector2.new(0, 400 * zone)
	advance(0.1)
end
