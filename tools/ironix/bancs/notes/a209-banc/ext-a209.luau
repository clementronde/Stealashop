---------------------------------------------------------------- ajouts a209 (vague 63, L-204 : animations des boutiques)
-- Collé après le faux Roblox du banc a189 (stubs, ext-motion, ext-a50, ext-a186, ext-a189) : il voit leurs locales.
-- Ajouts purs : AnchorPoint, ImageTransparency, TextTransparency, UIStroke.Transparency, et trois services du client
-- (UserInputService avec TouchEnabled et KeyboardEnabled réglables, GuiService, MarketplaceService et ses deux signaux).
for _, class in { "Frame", "ImageLabel", "TextLabel", "TextButton", "ImageButton", "ScrollingFrame" } do
	PROPS[class] = PROPS[class] or {}
	local p = PROPS[class]
	if p.AnchorPoint == nil then
		p.AnchorPoint = Vector2.new(0, 0)
	end
	if p.Position == nil then
		p.Position = UDim2.fromScale(0, 0)
	end
	if p.Rotation == nil then
		p.Rotation = 0
	end
	if p.ImageTransparency == nil and (class == "ImageLabel" or class == "ImageButton") then
		p.ImageTransparency = 0
	end
	if p.TextTransparency == nil and (class == "TextLabel" or class == "TextButton") then
		p.TextTransparency = 0
	end
end
PROPS.UIStroke.Transparency = PROPS.UIStroke.Transparency or 0

FAKE_UIS = { TouchEnabled = false, KeyboardEnabled = true, MouseIcon = "" }
FAKE_GUISERVICE = { ReducedMotionEnabled = false }
FAKE_MARKET = { PromptProductPurchaseFinished = newSignal(), PromptGamePassPurchaseFinished = newSignal() }
for side, old in table.clone(games) do
	local oldUis = nil
	pcall(function()
		oldUis = old:GetService("UserInputService")
	end)
	for k, v in oldUis or {} do
		if FAKE_UIS[k] == nil then
			FAKE_UIS[k] = v
		end
	end
	games[side] = {
		GetService = function(_, name)
			if name == "UserInputService" then
				return FAKE_UIS
			elseif name == "GuiService" then
				return FAKE_GUISERVICE
			elseif name == "MarketplaceService" then
				return FAKE_MARKET
			end
			return old:GetService(name)
		end,
	}
end
