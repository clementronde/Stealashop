--!nocheck
---------------------------------------------------------------- a85 : compléments du faux Roblox (vague 27, arbre)
-- Collé après stubs.luau, ext-motion.luau et ext-a60.luau du banc a60 (copie a62), dans le même fichier (voit
-- leurs variables locales). Ajouts purs, pour SkillTreeController, SkillTree/Nav et SkillTree/Fx :
--   - UserInputService (TouchEnabled, KeyboardEnabled, InputChanged, InputEnded, GetMouseLocation) et
--     GuiService:GetGuiInset() (haut de l'écran : INSET_Y px) dans game:GetService ;
--   - signal InputChanged des objets d'UI ; propriétés Active, BorderSizePixel (objets d'UI), CornerRadius
--     (UICorner), ApplyStrokeMode (UIStroke), DisplayOrder (ScreenGui), UDim.new ;
--   - Position et Size par défaut des objets d'UI refaites avec l'UDim2 d'ext-a60 (+, −, ×), pour que les
--     tweens et les décalages marchent aussi sur un objet jamais placé ;
--   - courbe Elastic (Roblox : Out = 2^(−10u)·sin((u − p/4)·2π/p) + 1, p = 0,3) ;
--   - AbsoluteSize et AbsolutePosition qui suivent les UIScale (comme Roblox : un UIScale agrandit l'objet et
--     tout ce qu'il contient, autour de son AnchorPoint). Sans UIScale, mêmes valeurs qu'avant.
INSET_Y = 36
MOUSE_AT = Vector2.new(0, 0)
UserInputServiceStub = {
	TouchEnabled = false,
	KeyboardEnabled = true,
	MouseEnabled = true,
	InputBegan = newSignal(),
	InputChanged = newSignal(),
	InputEnded = newSignal(),
	GetMouseLocation = function()
		return MOUSE_AT
	end,
}
GuiServiceStub = {
	GetGuiInset = function()
		return Vector2.new(0, INSET_Y), Vector2.new(0, 0)
	end,
}
for side, old in table.clone(games) do
	games[side] = {
		GetService = function(_, name)
			if name == "UserInputService" then
				return UserInputServiceStub
			elseif name == "GuiService" then
				return GuiServiceStub
			end
			return old:GetService(name)
		end,
	}
end

EVENTS.InputChanged = true
for _, class in { "Frame", "TextLabel", "TextButton", "ImageLabel", "ImageButton", "ViewportFrame" } do
	local props = PROPS[class]
	if props then
		if props.Active == nil then
			props.Active = false
		end
		if props.BorderSizePixel == nil then
			props.BorderSizePixel = 1
		end
		props.Position = UDim2.new(props.Position.X.Scale, props.Position.X.Offset, props.Position.Y.Scale, props.Position.Y.Offset)
		props.Size = UDim2.new(props.Size.X.Scale, props.Size.X.Offset, props.Size.Y.Scale, props.Size.Y.Offset)
	end
end
PROPS.UICorner.CornerRadius = PROPS.UICorner.CornerRadius or { Scale = 0, Offset = 8 }
PROPS.UIStroke.ApplyStrokeMode = PROPS.UIStroke.ApplyStrokeMode or "Enum.ApplyStrokeMode.Contextual"
PROPS.ScreenGui.DisplayOrder = PROPS.ScreenGui.DisplayOrder or 0
if UDim == nil then
	UDim = {
		new = function(scale, offset)
			return { Scale = scale or 0, Offset = offset or 0 }
		end,
	}
end

do
	local easeBeforeA85 = EASE
	local P = 0.3
	local function elasticIn(u)
		if u <= 0 then
			return 0
		elseif u >= 1 then
			return 1
		end
		return -(2 ^ (10 * (u - 1))) * math.sin((u - 1 - P / 4) * 2 * math.pi / P)
	end
	function EASE(style, direction, u)
		if style ~= "Enum.EasingStyle.Elastic" then
			return easeBeforeA85(style, direction, u)
		end
		if direction == "Enum.EasingDirection.In" then
			return elasticIn(u)
		elseif direction == "Enum.EasingDirection.Out" then
			return 1 - elasticIn(1 - u)
		end
		if u < 0.5 then
			return elasticIn(2 * u) / 2
		end
		return 1 - elasticIn(2 * (1 - u)) / 2
	end
end

do
	local function ownScale(inst)
		for _, child in rawget(inst, "_children") do
			if rawget(child, "_class") == "UIScale" then
				return rawget(child, "_props").Scale
			end
		end
		return 1
	end
	-- Rectangle à l'écran (position, taille) et échelle cumulée des UIScale (pour les Offset des enfants).
	local function rect(inst)
		if rawget(inst, "_class") == "ScreenGui" then
			return v2(0, 0), SCREEN_SIZE, 1
		end
		local parent = rawget(inst, "_parent")
		local origin, base, k = v2(0, 0), SCREEN_SIZE, 1
		if parent and isA(parent, "GuiBase2d") then
			origin, base, k = rect(parent)
		end
		local props = rawget(inst, "_props")
		local own = ownScale(inst)
		local size, position = props.Size, props.Position
		local w = (base.X * size.X.Scale + size.X.Offset * k) * own
		local h = (base.Y * size.Y.Scale + size.Y.Offset * k) * own
		local x = origin.X + base.X * position.X.Scale + position.X.Offset * k
		local y = origin.Y + base.Y * position.Y.Scale + position.Y.Offset * k
		local anchor = props.AnchorPoint or v2(0, 0)
		return v2(x - w * anchor.X, y - h * anchor.Y), v2(w, h), k * own
	end
	local indexBeforeA85 = InstanceMT.__index
	InstanceMT.__index = function(self, key)
		if (key == "AbsoluteSize" or key == "AbsolutePosition") and isA(self, "GuiBase2d") then
			local position, size = rect(self)
			return if key == "AbsoluteSize" then size else position
		end
		return indexBeforeA85(self, key)
	end
end
