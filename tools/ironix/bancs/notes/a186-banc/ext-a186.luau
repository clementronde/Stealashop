---------------------------------------------------------------- ajouts a186 (L-176 : fonds des cartes par palier)
-- Collé après stubs.luau, ext-motion.luau et ext-a50.luau du banc a50 (lus sur place) : il voit leurs locales.
-- Color3 avec Lerp et typeof = "Color3" (attributs RarityColor, BorderColor), Vector2, UIGradient, et les propriétés
-- d'UI que Shared/ShopCardTier lit ou écrit.
local C3MT = { __type = "Color3" }
C3MT.__index = {
	Lerp = function(a, b, t)
		return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3MT)
	end,
}
local function c3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3MT)
end
Color3.new = function(r, g, b)
	return c3(r or 0, g or 0, b or 0)
end
Color3.fromRGB = function(r, g, b)
	return c3(r / 255, g / 255, b / 255)
end
Color3.fromHex = function(hex)
	local h = string.gsub(hex, "#", "")
	return c3(tonumber(string.sub(h, 1, 2), 16) / 255, tonumber(string.sub(h, 3, 4), 16) / 255, tonumber(string.sub(h, 5, 6), 16) / 255)
end
Vector2 = Vector2 or {
	new = function(x, y)
		return { X = x or 0, Y = y or 0 }
	end,
}
ISA.UIGradient = ISA.UIGradient or { "UIComponent" }
PROPS.UIGradient = PROPS.UIGradient or { Enabled = true, Rotation = 0, Offset = Vector2.new(0, 0) }
PROPS.Folder = PROPS.Folder or {}
local WHITE = Color3.new(1, 1, 1)
local function addProps(class, extra)
	PROPS[class] = PROPS[class] or {}
	for k, v in extra do
		if PROPS[class][k] == nil then
			PROPS[class][k] = v
		end
	end
end
local GUI = { Position = UDim2.fromScale(0, 0), Rotation = 0, ZIndex = 1, BackgroundColor3 = WHITE, ClipsDescendants = false, BorderSizePixel = 0 }
for _, class in { "Frame", "ImageLabel", "TextLabel", "TextButton", "ImageButton", "ScrollingFrame" } do
	addProps(class, GUI)
end
addProps("ImageLabel", { ImageTransparency = 0, ImageColor3 = WHITE })
addProps("UIStroke", { Color = Color3.new(0, 0, 0) })
