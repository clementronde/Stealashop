-- pc-steal (2026-11-14) : GetPropertyChangedSignal(nom) au faux Roblox du banc a104 (HeistController s'en sert
-- pour garder la portée de l'invite de l'objet sorti), déclenché quand la propriété change vraiment.
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
local baseNewindexSignal = Inst.__newindex
Inst.__newindex = function(self, k, v)
	local old = self[k]
	baseNewindexSignal(self, k, v)
	local map = propSignals[self]
	if map and map[k] and old ~= v then
		map[k]:Fire()
	end
end
