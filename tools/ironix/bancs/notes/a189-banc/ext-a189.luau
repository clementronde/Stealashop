---------------------------------------------------------------- ajouts a189 (vague 59, L-182 : animations d'UI, raretés, flou)
-- Collé après stubs.luau, ext-motion.luau, ext-a50.luau (banc a50) et ext-a186.luau (banc a186), lus sur place : il voit
-- leurs locales (ISA, PROPS, EVENTS, Methods, games, DataModel). Ajouts purs : courbe Quint, Lighting et BlurEffect,
-- ColorSequence, propriétés et signaux d'UI que lisent Controllers/UI/Appear, RarityFx, Motion et UiMotionController.
TIMED_TWEENS = true

local oldEase = EASE
function EASE(style, direction, u)
	local f
	if style == "Enum.EasingStyle.Quint" then
		f = function(x)
			return x * x * x * x * x
		end
	elseif style == "Enum.EasingStyle.Sine" then
		f = function(x)
			return 1 - math.cos(x * math.pi / 2)
		end
	else
		return oldEase(style, direction, u)
	end
	if direction == "Enum.EasingDirection.In" then
		return f(u)
	elseif direction == "Enum.EasingDirection.Out" then
		return 1 - f(1 - u)
	end
	if u < 0.5 then
		return f(2 * u) / 2
	end
	return 1 - f(2 * (1 - u)) / 2
end

local CSMT = { __type = "ColorSequence" }
ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and getmetatable(a) == nil then
			return setmetatable({ Keypoints = a }, CSMT)
		end
		return setmetatable({ Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } }, CSMT)
	end,
}
ColorSequenceKeypoint = {
	new = function(t, c)
		assert(t >= 0 and t <= 1, "ColorSequenceKeypoint : temps hors de 0..1")
		return { Time = t, Value = c }
	end,
}
Vector2.zero = Vector2.new(0, 0)

ISA.BlurEffect = ISA.BlurEffect or { "PostEffect" }
PROPS.BlurEffect = PROPS.BlurEffect or { Size = 24, Enabled = true }
PROPS.Lighting = PROPS.Lighting or {}
PROPS.PlayerGui = PROPS.PlayerGui or {}
PROPS.UIGradient.Color = PROPS.UIGradient.Color or ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
PROPS.TextBox = PROPS.TextBox or {}
for _, class in { "Frame", "ImageLabel", "TextLabel", "TextButton", "ImageButton", "ScrollingFrame" } do
	PROPS[class] = PROPS[class] or {}
	local p = PROPS[class]
	if p.AbsolutePosition == nil then
		p.AbsolutePosition = Vector2.new(0, 0)
	end
	if p.AbsoluteSize == nil then
		p.AbsoluteSize = Vector2.new(0, 0)
	end
	if p.TextColor3 == nil and (class == "TextLabel" or class == "TextButton") then
		p.TextColor3 = Color3.new(0, 0, 0)
	end
	if p.ImageColor3 == nil and (class == "ImageLabel" or class == "ImageButton") then
		p.ImageColor3 = Color3.new(1, 1, 1)
	end
	if p.Active == nil then
		p.Active = false
	end
end
PROPS.ScreenGui.AbsoluteSize = PROPS.ScreenGui.AbsoluteSize or Vector2.new(1000, 600)
for _, name in { "MouseEnter", "MouseLeave", "MouseButton1Down", "MouseButton1Up", "InputBegan", "InputEnded" } do
	EVENTS[name] = true
end

if Methods.FindFirstAncestor == nil then
	function Methods.FindFirstAncestor(self, name)
		local current = rawget(self, "_parent")
		while current do
			if current.Name == name then
				return current
			end
			current = rawget(current, "_parent")
		end
		return nil
	end
end
if Methods.FindFirstAncestorWhichIsA == nil then
	function Methods.FindFirstAncestorWhichIsA(self, class)
		local current = rawget(self, "_parent")
		while current do
			if current:IsA(class) then
				return current
			end
			current = rawget(current, "_parent")
		end
		return nil
	end
end

-- Lighting (service), pour le flou.
LightingService = InstanceAPI.new("Lighting")
LightingService.Name = "Lighting"
LightingService.Parent = DataModel
for side, old in table.clone(games) do
	games[side] = {
		GetService = function(_, name)
			if name == "Lighting" then
				return LightingService
			end
			return old:GetService(name)
		end,
	}
end

-- Connexions encore branchées sur les signaux d'une instance (événements, propriétés, attributs).
function handlerCount(inst)
	local n = 0
	for _, field in { "_signals", "_propSignals", "_attrSignals" } do
		for _, signal in rawget(inst, field) or {} do
			n += #signal.handlers
		end
	end
	return n
end
