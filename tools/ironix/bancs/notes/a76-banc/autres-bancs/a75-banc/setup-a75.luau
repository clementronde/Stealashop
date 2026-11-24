---------------------------------------------------------------- montage a75 (après setup.luau et setup-a60.luau)
-- NotifyController (vrai), sons de l'arrivée en zone safe, icône ICON_BOX_Premium, écrans UI_Toast,
-- UI_Notify et UI_Escape tels que relevés dans Studio le 2026-11-11 (agents/wave24-studio.md).
NOTIFY_MODULE = moduleScript(CONTROLLERS, "NotifyController", "client/Controllers/NotifyController.luau")
for _, name in { "Heist_SafeFlash", "Heist_Escape" } do
	new("Sound", { Name = name }, SOUNDS)
end
ICONS_FOLDER = folder(ASSETS, "Icons")
BOX_PREMIUM_TEXTURE = "rbxassetid://box-premium"
new("Decal", { Name = "ICON_BOX_Premium", Texture = BOX_PREMIUM_TEXTURE }, ICONS_FOLDER)

GREEN = Color3.fromHex("5DFF3A")
function sameColor(a, b)
	return a ~= nil and b ~= nil and near(a.R, b.R, 1e-3) and near(a.G, b.G, 1e-3) and near(a.B, b.B, 1e-3)
end

-- UI_Toast : Stack (UIListLayout, Template TextLabel caché vert avec un UIStroke).
function makeToast()
	local gui = new("ScreenGui", { Name = "UI_Toast", Enabled = false, ResetOnSpawn = false })
	local stack = new("Frame", { Name = "Stack", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromScale(0.72, 0.2), BackgroundTransparency = 1 }, gui)
	new("UIListLayout", {}, stack)
	local template = new("TextLabel", { Name = "Template", Visible = false, Text = "Crown equipped!", TextColor3 = GREEN, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.24) }, stack)
	new("UIStroke", { Thickness = 2 }, template)
	gui.Parent = PLAYER_GUI
	return gui, stack, template
end
-- UI_Notify (repli) : Template avec Icon et Label.
function makeNotify()
	local gui = new("ScreenGui", { Name = "UI_Notify", Enabled = false, ResetOnSpawn = false })
	local stack = new("Frame", { Name = "Stack", Size = UDim2.fromScale(0.36, 0.62) }, gui)
	local template = new("Frame", { Name = "Template", Visible = false, Size = UDim2.fromScale(1, 0.1) }, stack)
	new("ImageLabel", { Name = "Icon" }, template)
	new("TextLabel", { Name = "Label", Text = "" }, template)
	gui.Parent = PLAYER_GUI
	return gui, stack, template
end
-- UI_Escape : Banner (Title −3°, Subtitle, BoxIcon), Flash plein écran transparent.
function makeEscape()
	local gui = new("ScreenGui", { Name = "UI_Escape", Enabled = false, ResetOnSpawn = false })
	local banner = new("Frame", { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0.42, 0.2), BackgroundTransparency = 1 }, gui)
	local title = new("TextLabel", { Name = "Title", Text = "ESCAPED!", Rotation = -3, Size = UDim2.fromScale(1, 0.55), BackgroundTransparency = 1 }, banner)
	new("UIStroke", { Thickness = 3 }, title)
	new("TextLabel", { Name = "Subtitle", Text = "Take the box to your shop!", Size = UDim2.fromScale(0.86, 0.2), BackgroundTransparency = 1 }, banner)
	new("UIAspectRatioConstraint", { AspectRatio = 3 }, banner)
	new("ImageLabel", { Name = "BoxIcon", Image = "rbxassetid://clement-default", Size = UDim2.fromScale(0.26, 0.26), BackgroundTransparency = 1 }, banner)
	new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 }, gui)
	gui.Parent = PLAYER_GUI
	return gui
end
function childrenStartingWith(parent, prefix)
	local out = {}
	for _, child in parent:GetChildren() do
		if string.sub(child.Name, 1, #prefix) == prefix then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end
