---------------------------------------------------------------- montage a60 (après setup.luau d'a37)
-- Voisins bouchonnés et pilotables (HeistController, ChaseController, RewardsController), modèles de
-- Clément tels que relevés dans Studio (vague 21) : BB_Gain, UI_HUD avec CashFly, sons d'UI.

SOURCES["stub/HeistController"] = [==[
local H = { listeners = {}, timers = {} }
function H.OnTimer(fn)
	table.insert(H.listeners, fn)
	return function() end
end
function H.GetTimers()
	return H.timers
end
function H.Emit(storeId, endsAt)
	for _, fn in H.listeners do
		fn(storeId, endsAt)
	end
end
return H
]==]
SOURCES["stub/ChaseController"] = [==[
local C = { chased = false, distance = nil }
function C.IsChased()
	return C.chased
end
function C.GetDistance()
	return C.distance
end
function C.IsClose()
	return false
end
return C
]==]
SOURCES["stub/RewardsController"] = [==[
local R = { open = false }
function R.GetState()
	return { Open = R.open, Tab = "Daily", Day = 1, DailyClaimed = false, PlaySeconds = 0, Pending = false }
end
return R
]==]
HUD_MODULE = moduleScript(CONTROLLERS, "HudController", "client/Controllers/HudController.luau")
GAIN_MODULE = moduleScript(CONTROLLERS, "GainController", "client/Controllers/GainController.luau")
FEEL_MODULE = moduleScript(CONTROLLERS, "UiFeelController", "client/Controllers/UiFeelController.luau")
HEIST_MODULE = moduleScript(CONTROLLERS, "HeistController", "stub/HeistController")
CHASE_MODULE = moduleScript(CONTROLLERS, "ChaseController", "stub/ChaseController")
REWARDS_MODULE = moduleScript(CONTROLLERS, "RewardsController", "stub/RewardsController")

-- ReplicatedStorage/Assets : UI/BB_Gain (Row : Amount avec son UIStroke, Icon), Sounds.
ASSETS = folder(ReplicatedStorage, "Assets")
local uiAssets = folder(ASSETS, "UI")
BB_GAIN = new("BillboardGui", { Name = "BB_Gain", StudsOffset = Vector3.new(0, 3, 0), AlwaysOnTop = true }, uiAssets)
do
	local row = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, BB_GAIN)
	local amount = new("TextLabel", { Name = "Amount", Text = "+2 Speed/s", TextTransparency = 0 }, row)
	new("UIStroke", { Thickness = 2 }, amount)
	new("ImageLabel", { Name = "Icon", Image = "rbxassetid://template-icon", ImageTransparency = 0 }, row)
	new("UIListLayout", {}, row)
end
SOUNDS = folder(ASSETS, "Sounds")
for _, name in { "UI_Hover", "UI_Success", "Cash_Collect", "UI_Click_Tick" } do
	new("Sound", { Name = name }, SOUNDS)
end

-- UI_HUD comme celui de Clément (StatsPanel : SpeedRow, StrengthRow, CashRow avec leurs icônes ;
-- CashFly avec CounterPop et Template cachés ; LeftRail avec des boutons à calque Shade ; HeistTimer
-- avec son enfant Box).
function makeHud()
	local hud = new("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false, IgnoreGuiInset = true })
	local rail = new("Frame", { Name = "LeftRail", Position = UDim2.fromScale(0.02, 0.3), Size = UDim2.fromScale(0.15, 0.25) }, hud)
	for _, name in { "RobuxShopButton", "IndexButton", "RebirthButton" } do
		local button = new("TextButton", { Name = name, Text = "", Size = UDim2.fromScale(1, 0.3) }, rail)
		new("Frame", { Name = "Shade", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, button)
	end
	local panel = new("Frame", { Name = "StatsPanel", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.02, 0.97), Size = UDim2.fromScale(0.32, 0.23) }, hud)
	for _, spec in { { "SpeedRow", "SpeedIcon", "Speed", "rbxassetid://speed-icon" }, { "StrengthRow", "StrengthIcon", "Strength", "rbxassetid://strength-icon" } } do
		local row = new("Frame", { Name = spec[1], Size = UDim2.fromScale(1, 0.2) }, panel)
		local icon = new("ImageLabel", { Name = spec[2], Image = spec[4] }, row)
		new("Frame", { Name = "PlusBadge" }, icon)
		new("TextLabel", { Name = spec[3], Text = "16" }, row)
	end
	new("TextLabel", { Name = "Damage", Text = "1" }, panel)
	local cashRow = new("Frame", { Name = "CashRow", Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4) }, panel)
	new("ImageLabel", { Name = "CashIcon", Image = "rbxassetid://cash-icon" }, cashRow)
	local cash = new("TextLabel", { Name = "Cash", Text = "$0", Position = UDim2.fromScale(0.15, 0), Size = UDim2.fromScale(0.5, 1) }, cashRow)
	new("UIStroke", { Thickness = 3 }, cash)
	new("TextLabel", { Name = "Income", Text = "+$0/s", Size = UDim2.fromScale(0.3, 1) }, cashRow)
	local fly = new("Frame", { Name = "CashFly", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, hud)
	local pop = new("TextLabel", { Name = "CounterPop", Text = "+$0", Visible = false, TextTransparency = 0, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(80, 24) }, fly)
	new("UIStroke", { Thickness = 2 }, pop)
	local template = new("Frame", { Name = "Template", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(90, 36) }, fly)
	new("ImageLabel", { Name = "Icon", Image = "rbxassetid://cash-icon" }, template)
	new("TextLabel", { Name = "FlyerAmount", Text = "$0" }, template)
	local timer = new("TextLabel", { Name = "HeistTimer", Text = "HEIST: 7s", Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), Size = UDim2.fromScale(0.24, 0.066) }, hud)
	new("Frame", { Name = "Box", Size = UDim2.fromScale(1, 1) }, timer)
	local meter = new("Frame", { Name = "GuardMeter", Visible = false, Size = UDim2.fromScale(0.267, 0.026) }, hud)
	new("Frame", { Name = "Fill", Size = UDim2.new(0.6, 0, 1, 0) }, meter)
	hud.Parent = PLAYER_GUI
	return hud
end

-- Le UIScale nommé `name` posé sur `object`, ou nil.
function scaleNamed(object, name)
	for _, child in object:GetChildren() do
		if child.ClassName == "UIScale" and child.Name == name then
			return child
		end
	end
	return nil
end
function anyUIScale(root)
	for _, d in root:GetDescendants() do
		if d.ClassName == "UIScale" then
			return d
		end
	end
	return nil
end
function childrenNamed(parent, name)
	local out = {}
	for _, child in parent:GetChildren() do
		if child.Name == name then
			table.insert(out, child)
		end
	end
	return out
end
-- Noms des sons joués depuis l'indice `from` de SOUNDS_PLAYED.
function soundsSince(from)
	local out = {}
	for i = from + 1, #SOUNDS_PLAYED do
		table.insert(out, SOUNDS_PLAYED[i].name)
	end
	return out
end
