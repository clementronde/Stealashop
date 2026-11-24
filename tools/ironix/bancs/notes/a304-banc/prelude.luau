---------------------------------------------------------------- a304 : propriétés de plus pour le faux Roblox d'a50
-- (AnchorPoint des GuiObject, police et couleur de texte des boutons, épaisseur et transparence des UIStroke, UICorner,
-- UIPadding), ajoutées seulement si elles manquent.
local function more304(class, extra)
	PROPS[class] = PROPS[class] or {}
	for k, v in extra do
		if PROPS[class][k] == nil then
			PROPS[class][k] = v
		end
	end
end
for _, class in { "Frame", "ImageLabel", "TextLabel", "TextButton", "ImageButton", "ScrollingFrame" } do
	more304(class, { AnchorPoint = Vector2.new(0, 0) })
end
more304("TextButton", { FontFace = Font.fromEnum("Enum.Font.Legacy"), TextColor3 = Color3.new(0, 0, 0), TextScaled = false })
more304("UIStroke", { Thickness = 1, Transparency = 0 })
more304("UICorner", {})
more304("UIPadding", {})
