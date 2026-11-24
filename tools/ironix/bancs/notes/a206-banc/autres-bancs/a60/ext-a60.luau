---------------------------------------------------------------- extensions a60 (vague 21, L-091)
-- Collé après stubs.luau et ext-motion.luau (voit leurs variables locales) :
--   - signaux MouseButton1Down et MouseButton1Up (Motion.Button) ;
--   - TextBounds des TextLabel (60 × 20 px), pour la place de « +$X » à droite du nombre ;
--   - UDim2 avec +, − et × nombre (Roblox les a ; Motion.HoverCard et la case qui vole s'en servent) et
--     tweens de UDim2 : TweenService:Create accepte une valeur UDim2, que l'avance des tweens
--     interpole par ces opérations.
EVENTS.MouseButton1Down = true
EVENTS.MouseButton1Up = true
PROPS.TextLabel.TextBounds = Vector2.new(60, 20)
PROPS.UIStroke.Transparency = 0 -- Roblox l’a ; le faux d’a23 ne l’avait pas

do
	local UDim2MT = { __type = "UDim2" }
	local function make(xs, xo, ys, yo)
		return setmetatable({ X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 } }, UDim2MT)
	end
	UDim2MT.__add = function(a, b)
		return make(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
	end
	UDim2MT.__sub = function(a, b)
		return make(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
	end
	UDim2MT.__mul = function(a, k)
		return make(a.X.Scale * k, a.X.Offset * k, a.Y.Scale * k, a.Y.Offset * k)
	end
	UDim2MT.__eq = function(a, b)
		return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
	end
	UDim2.new = make
	UDim2.fromScale = function(x, y)
		return make(x, 0, y, 0)
	end
	UDim2.fromOffset = function(x, y)
		return make(0, x, 0, y)
	end
	function sameUDim2(a, b)
		return math.abs(a.X.Scale - b.X.Scale) < 1e-6 and math.abs(a.X.Offset - b.X.Offset) < 1e-6
			and math.abs(a.Y.Scale - b.Y.Scale) < 1e-6 and math.abs(a.Y.Offset - b.Y.Offset) < 1e-6
	end

	local numericCreate = TweenServiceStub.Create
	TweenServiceStub.Create = function(self, inst, info, goals)
		local numbers, others = {}, {}
		for k, v in goals do
			if type(v) == "number" then
				numbers[k] = v
			else
				others[k] = v
			end
		end
		local tween = numericCreate(self, inst, info, numbers)
		for k, v in others do
			tween._goals[k] = v
		end
		return tween
	end
end
-- Instance:FindFirstAncestor(name) (Roblox) : le premier ancêtre de ce nom, ou nil.
if Methods.FindFirstAncestor == nil then
	function Methods.FindFirstAncestor(self, name)
		local current = self.Parent
		while current ~= nil do
			if current.Name == name then
				return current
			end
			current = current.Parent
		end
		return nil
	end
end
-- Copie d'a62 (2026-11-11, vague 22, L-092 3g) : Motion.Button suit aussi la fin d'un toucher.
EVENTS.InputBegan = true
EVENTS.InputEnded = true
