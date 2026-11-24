---------------------------------------------------------------- ajouts a290 (L-270, clic sur la taille réelle du bouton)
-- Collé après ext-a222.luau. Ajouts purs : un UserInputService avec InputChanged et InputEnded (UIS290), un GuiService
-- (GetGuiInset = GUI_INSET), des InputObject (pointeur, état, GetPropertyChangedSignal) et render290 qui recalcule
-- AbsolutePosition et AbsoluteSize d'un bouton d'après son UIScale, autour de son AnchorPoint (le faux Roblox ne le fait
-- pas seul).
USE_UIS290 = false -- allumé par tests.luau après setup (UpgradeController de setup garde son UserInputService)
UIS290 = {
	MouseIcon = "",
	InputBegan = newSignal(),
	InputChanged = newSignal(),
	InputEnded = newSignal(),
	WindowFocusReleased = newSignal(),
}
GUI_INSET = Vector2.new(0, 36)
local guiService290 = {
	GetGuiInset = function(_self)
		return GUI_INSET, Vector2.new(0, 0)
	end,
}
for side, old in table.clone(games) do
	games[side] = {
		GetService = function(_, name)
			if name == "UserInputService" and side == "client" and USE_UIS290 then
				return UIS290
			elseif name == "GuiService" then
				return guiService290
			end
			return old:GetService(name)
		end,
	}
end

-- InputObject : kind = "MouseButton1", "Touch", "MouseMovement"… ; x, y dans le repère de l'InputObject.
function input290(kind, x, y)
	local signals = {}
	local obj = {
		UserInputType = Enum.UserInputType[kind],
		UserInputState = Enum.UserInputState.Begin,
		Position = { X = x, Y = y, Z = 0 },
	}
	function obj.GetPropertyChangedSignal(_self, key)
		signals[key] = signals[key] or newSignal()
		return signals[key]
	end
	function obj.set290(_self, key, value)
		obj[key] = value
		local s = signals[key]
		if s then
			s:Fire()
		end
	end
	return obj
end

-- Taille de Studio (sans UIScale) d'un objet : posée une fois par base290.
local bases290 = {}
function base290(object, x, y, w, h)
	bases290[object] = { x = x, y = y, w = w, h = h }
	object.AbsolutePosition = Vector2.new(x, y)
	object.AbsoluteSize = Vector2.new(w, h)
end
function render290(object)
	local b = bases290[object]
	if b == nil then
		return
	end
	local s = 1
	for _, child in object:GetChildren() do
		if child:IsA("UIScale") then
			s = child.Scale
			break
		end
	end
	local a = object.AnchorPoint
	local px, py = b.x + b.w * a.X, b.y + b.h * a.Y
	local w, h = b.w * s, b.h * s
	object.AbsoluteSize = Vector2.new(w, h)
	object.AbsolutePosition = Vector2.new(px - w * a.X, py - h * a.Y)
end
