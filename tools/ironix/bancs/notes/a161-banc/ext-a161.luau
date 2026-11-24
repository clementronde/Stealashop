-- a161 : ajouts purs au faux Roblox (copie d'a62 du banc a60) : Instance:GetTags et Instance:RemoveTag (la copie de
-- l'objet le plus rare retire les tags de l'objet exposé). Les copies du faux arbre n'ont jamais de tag.
if Methods.GetTags == nil then
	function Methods.GetTags(_self)
		return {}
	end
end
-- CFrame.Rotation (la copie de l'objet est tournée comme ItemPoint ou comme son présentoir).
do
	local previous = CFMT.__index
	CFMT.__index = function(c, k)
		if k == "Rotation" then
			return cf(v3(0, 0, 0), c.r)
		end
		return previous(c, k)
	end
end
if Methods.RemoveTag == nil then
	function Methods.RemoveTag(_self, _tag) end
end
-- a178 (2026-11-15, ajout pur) : Instance:AddTag (la copie du socle prend le tag RarestItem).
if Methods.AddTag == nil then
	function Methods.AddTag(_self, _tag) end
end
