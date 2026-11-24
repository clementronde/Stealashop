--!nocheck
---------------------------------------------------------------- a76 : compléments du faux Roblox (vague 25)
-- Collé après ext74.luau dans le même fichier (voit les variables locales de stubs.luau) ; ajouts purs :
--   - Vector2 : une seule métatable, avec +, -, ==, Magnitude (HotbarController mesure le glisser) ;
--   - AbsoluteSize des objets d'UI ((0, 0) si jamais posée, comme AbsolutePosition d'a75) ;
--   - CanvasGroup (copie qui suit le pointeur), un GuiObject ;
--   - UserInputService.InputChanged (mouvement de la souris ou du doigt).
do
	local V2MT = { __type = "Vector2" }
	V2MT.__index = function(v, key)
		if key == "Magnitude" then
			return math.sqrt(v.X * v.X + v.Y * v.Y)
		end
		return nil
	end
	V2MT.__add = function(a, b)
		return Vector2.new(a.X + b.X, a.Y + b.Y)
	end
	V2MT.__sub = function(a, b)
		return Vector2.new(a.X - b.X, a.Y - b.Y)
	end
	V2MT.__eq = function(a, b)
		return a.X == b.X and a.Y == b.Y
	end
	Vector2.new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, V2MT)
	end
	Vector2.zero = Vector2.new(0, 0)
end
do
	local indexBeforeA76 = InstanceMT.__index
	InstanceMT.__index = function(self, key)
		if key == "AbsoluteSize" and isA(self, "GuiObject") then
			local stored = rawget(self, "_props").AbsoluteSize
			return stored or Vector2.new(0, 0)
		end
		return indexBeforeA76(self, key)
	end
end
SUPER.CanvasGroup = { "GuiObject", "GuiBase2d" }
if UserInputServiceStub.InputChanged == nil then
	UserInputServiceStub.InputChanged = newSignal()
end
