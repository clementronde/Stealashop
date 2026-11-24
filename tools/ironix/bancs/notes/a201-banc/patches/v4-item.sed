# a201 : scénario v4, Footer.ItemReward livré, avec les CashReward et SpeedReward d'avant (à cacher).
58a\
	local item = make("Frame", { Name = "ItemReward" }, footer)\
	make("ImageLabel", { Name = "RewardIcon", Image = "rbxassetid://3" }, item)\
	make("TextLabel", { Name = "RewardCaption", Text = "ITEM" }, item)\
	local oldCash = make("Frame", { Name = "CashReward" }, footer)\
	make("TextLabel", { Name = "Amount", Text = "+$0" }, oldCash)\
	local oldSpeed = make("Frame", { Name = "SpeedReward" }, footer)\
	make("TextLabel", { Name = "Amount", Text = "+0" }, oldSpeed)
114a\
local footerV4 = gui.Window.Footer\
check(footerV4.ItemReward.RewardCaption.Text == "Wrench" and footerV4.ItemReward.RewardIcon.Image == "rbxassetid://9101", `ItemReward : « {footerV4.ItemReward.RewardCaption.Text} », icône ICON_TOOL_Wrench`)\
check(footerV4.CashReward.Visible == false and footerV4.SpeedReward.Visible == false and footerV4.CashReward.Amount.Text == "+$0" and footerV4.SpeedReward.Amount.Text == "+0", "CashReward et SpeedReward cachés, plus écrits")
160a\
check(gui.Window.Footer.ItemReward.RewardCaption.Text == "Flame" and gui.Window.Footer.ItemReward.RewardIcon.Image == "rbxassetid://9101", "zone 2 : ItemReward « Flame », icône d'avant gardée")
