-- pc-steal : ajouts au faux Roblox du banc a104 (collé juste après harness.luau, ses locales sont visibles).
-- 1. Comme le moteur, Model:ScaleTo multiplie aussi MaxActivationDistance des ProximityPrompt du modèle.
-- 2. GetPropertyChangedSignal(nom), déclenché quand la propriété change vraiment.
local baseScaleTo = Methods.ScaleTo
function Methods.ScaleTo(self, s)
	local factor = s / (rawget(self, "_props").Scale or 1)
	baseScaleTo(self, s)
	for _, d in Methods.GetDescendants(self) do
		if rawget(d, "_class") == "ProximityPrompt" then
			d.MaxActivationDistance = d.MaxActivationDistance * factor
		end
	end
end
local propSignals = setmetatable({}, { __mode = "k" })
function Methods.GetPropertyChangedSignal(self, k)
	local map = propSignals[self]
	if map == nil then
		map = {}
		propSignals[self] = map
	end
	map[k] = map[k] or newSignal()
	return map[k]
end
local baseNewindex = Inst.__newindex
Inst.__newindex = function(self, k, v)
	local old = self[k]
	baseNewindex(self, k, v)
	local map = propSignals[self]
	if map and map[k] and old ~= v then
		map[k]:Fire()
	end
end
