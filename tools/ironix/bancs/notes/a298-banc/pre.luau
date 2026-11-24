--!nocheck
-- a298 : avant la mise en place d'a38. REPLACE (remplacement de texte dans une vraie source), et les petits manques du
-- faux Roblox déjà ajoutés par le banc a285 (Vector2.zero, UDim2 + UDim2, FindFirstAncestorOfClass).
local function replace(key, from, to)
	local source = SOURCES[key]
	local first, last = string.find(source, from, 1, true)
	assert(first, `remplacement introuvable dans {key} : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. to .. string.sub(source, last + 1)
end
REPLACE = replace

Vector2.zero = Vector2.new(0, 0)
local ud2 = getmetatable(UDim2.new(0, 0, 0, 0))
ud2.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
function Methods.FindFirstAncestorOfClass(self, class)
	local current = self.Parent
	while current ~= nil do
		if current.ClassName == class then
			return current
		end
		current = current.Parent
	end
	return nil
end
