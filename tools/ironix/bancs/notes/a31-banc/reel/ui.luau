-- Repris tel quel du banc d'a23 (a26-banc/a23-banc/tests.luau, lignes 137 à 207) par a31 : new, S, CENTER
-- et buildUnbox, l'écran UI_Unbox v2 relevé dans Studio le 2026-11-07.
function new(class, props, parent)
	local inst = InstanceAPI.new(class)
	for k, v in props or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local function S(x, y)
	return UDim2.fromScale(x, y)
end
local CENTER = Vector2.new(0.5, 0.5)

-- Écran UI_Unbox v2, tel que relevé dans Studio le 2026-11-07 (wave7-studio.md, section 1).
function buildUnbox(parent)
	local gui = new("ScreenGui", { Name = "UI_Unbox", Enabled = false, IgnoreGuiInset = false }, parent)
	local panel = new("Frame", { Name = "RevealPanel", Size = S(0.75, 0.92), Position = S(0.5, 0.52), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 4 }, gui)
	local rarity = new("TextLabel", { Name = "Rarity", Size = S(0.9, 0.13), Position = S(0.5, 0.607), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 5, Text = "LEGENDARY", TextColor3 = Color3.new(1, 0.8, 0.1) }, panel)
	new("UIStroke", { Name = "UIStroke" }, rarity)
	new("UIGradient", { Name = "Rainbow", Enabled = false }, rarity)
	local preview = new("Frame", { Name = "ItemPreview", Size = S(0.225, 0.225), Position = S(0.5, 0.327), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 3 }, panel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, preview)
	local itemName = new("TextLabel", { Name = "ItemName", Size = S(0.85, 0.068), Position = S(0.5, 0.705), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 5, Text = "Winning Scratch Card" }, panel)
	new("UIStroke", { Name = "UIStroke" }, itemName)
	local income = new("TextLabel", { Name = "Income", Size = S(0.5, 0.078), Position = S(0.5, 0.785), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 5, Text = "+$50/s" }, panel)
	new("UIStroke", { Name = "UIStroke" }, income)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, panel)
	local rays = new("ImageLabel", { Name = "Rays", Size = S(0.633, 0.633), Position = S(0.5, 0.327), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 1, Image = "", Rotation = 10 }, panel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, rays)
	new("UIGradient", { Name = "Rainbow", Enabled = false, Rotation = 45 }, rays)
	for i = 1, 8 do
		new("Frame", { Name = string.format("Beam_%02d", i), Rotation = i * 45, BackgroundColor3 = Color3.new(1, 1, 0.8) }, rays)
	end
	local glow = new("Frame", { Name = "Glow", Size = S(0.36, 0.36), Position = S(0.5, 0.327), AnchorPoint = CENTER, BackgroundTransparency = 0.8, ZIndex = 2 }, panel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, glow)
	new("UICorner", { Name = "UICorner" }, glow)
	new("Frame", { Name = "GlowCore", Size = S(0.7, 0.7), Position = S(0.5, 0.5), AnchorPoint = CENTER, BackgroundTransparency = 0.7 }, glow)
	local buttons = new("Frame", { Name = "Buttons", Size = S(0.7, 0.122), Position = S(0.5, 0.917), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 6 }, panel)
	new("UIListLayout", { Name = "UIListLayout" }, buttons)
	for _, spec in { { "ContinueButton", true, "CONTINUE" }, { "OpenNextButton", false, "OPEN NEXT" } } do
		local button = new("TextButton", { Name = spec[1], Size = S(0.45, 1), Visible = spec[2], BackgroundTransparency = 0, Text = "" }, buttons)
		for _, deco in { "UISizeConstraint", "UICorner", "UIStroke", "UIGradient" } do
			new(deco, { Name = deco }, button)
		end
		new("ImageLabel", { Name = "Studs", Image = "rbxassetid://3014551673" }, button)
		new("TextLabel", { Name = "Label", Text = spec[3] }, button)
	end
	new("Frame", { Name = "Backdrop", Size = S(1, 1), BackgroundTransparency = 0.65, BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 1 }, gui)
	local skip = new("TextButton", { Name = "SkipButton", Size = S(1, 1), Visible = false, BackgroundTransparency = 1, ZIndex = 2, Text = "" }, gui)
	new("TextLabel", { Name = "Label", Size = S(0.3, 0.045), Position = S(0.98, 0.96), Text = "TAP TO SKIP" }, skip)
	local upgrade = new("Frame", { Name = "Upgrade", Size = S(0.42, 0.17), Position = S(0.5, 0.5), AnchorPoint = CENTER, Visible = false, BackgroundTransparency = 1, ZIndex = 3 }, gui)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, upgrade)
	new("TextLabel", { Name = "UpgradeLabel", Size = S(1, 0.55), Position = S(0.5, 0), Text = "UPGRADE!" }, upgrade)
	local upgradeRarity = new("TextLabel", { Name = "UpgradeRarity", Size = S(0.8, 0.42), Position = S(0.5, 1), Text = "UNCOMMON" }, upgrade)
	new("UIStroke", { Name = "UIStroke" }, upgradeRarity)
	new("UIGradient", { Name = "Rainbow", Enabled = false }, upgradeRarity)
	local reel = new("Frame", { Name = "Reel", Size = S(0.2, 0.35), Position = S(0.5, 0.445), AnchorPoint = CENTER, Visible = false, BackgroundTransparency = 1, ZIndex = 3 }, gui)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, reel)
	local reelGlow = new("Frame", { Name = "ReelGlow", Size = S(1.15, 1.15), Position = S(0.5, 0.5), AnchorPoint = CENTER, BackgroundTransparency = 0.55, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1 }, reel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, reelGlow)
	new("UICorner", { Name = "UICorner" }, reelGlow)
	new("Frame", { Name = "GlowCore", Size = S(0.6, 0.6), BackgroundTransparency = 0.6 }, reelGlow)
	new("ViewportFrame", { Name = "ReelView", Size = S(1, 1), BackgroundTransparency = 1, ZIndex = 2, ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0 }, reel)
	local confetti = new("Frame", { Name = "Confetti", Size = S(1, 1), BackgroundTransparency = 1, ZIndex = 6 }, gui)
	local template = new("Frame", { Name = "Template", Size = S(0.011, 0.018), Position = S(0.5, 0.3), Visible = false, BackgroundTransparency = 0 }, confetti)
	new("UIStroke", { Name = "UIStroke" }, template)
	new("Frame", { Name = "Flash", Size = S(1, 1), BackgroundTransparency = 1, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 7 }, gui)
	return gui
end
