--!nocheck
-- a285 : avant la mise en place d'a38. Ids du banc pour la caisse exclusive (lots 8301, 8302, 8303), écrits en texte
-- dans les vraies sources ; RobuxCrate allumé (les scénarios qui le veulent éteint le remettent) ; petits manques
-- du faux Roblox pour UiAttrFx (Vector2.zero, UDim2 + UDim2, FindFirstAncestorOfClass).
local function replace(key, from, to)
	local source = SOURCES[key]
	local first, last = string.find(source, from, 1, true)
	assert(first, `remplacement introuvable dans {key} : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. to .. string.sub(source, last + 1)
end
REPLACE = replace
CRATE_IDS = { [1] = 8301, [3] = 8302, [10] = 8303 }
local M = "shared/Config/Monetization.luau"
for count, id in CRATE_IDS do
	local from = string.match(SOURCES[M], "{ Count = " .. count .. ", Price = %d+, Id = 0 }")
	assert(from, `lot de {count} introuvable`)
	replace(M, from, (string.gsub(from, "Id = 0", `Id = {id}`)))
end
replace("shared/Config/Features.luau", "RobuxCrate = false", "RobuxCrate = true")

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
