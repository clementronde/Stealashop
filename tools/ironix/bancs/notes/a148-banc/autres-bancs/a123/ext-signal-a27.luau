-- Fusion 45 (2026-11-14) : GetPropertyChangedSignal(nom) au faux Roblox d'a27 (comme pc-steal-banc/ext-signal.luau
-- pour celui d'a104) ; HeistController s'en sert depuis pc-steal (portée de l'invite de l'objet sorti). Déclenché
-- quand la propriété change vraiment. Sans effet sur les tests.
local propSignalsA27 = setmetatable({}, { __mode = "k" })
function Methods.GetPropertyChangedSignal(self, k)
	local map = propSignalsA27[self]
	if map == nil then
		map = {}
		propSignalsA27[self] = map
	end
	map[k] = map[k] or newSignal()
	return map[k]
end
local baseNewindexA27 = InstanceMT.__newindex
InstanceMT.__newindex = function(self, k, v)
	local map = propSignalsA27[self]
	local old = if map and map[k] then self[k] else nil
	baseNewindexA27(self, k, v)
	if map and map[k] and old ~= v then
		map[k]:Fire()
	end
end
