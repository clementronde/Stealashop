--!strict
-- Gel en profondeur d'une table de configuration (DEV-002, Config).
-- Chaque module de Config renvoie sa table passée par cette fonction : toute
-- écriture, même dans une sous-table, lève une erreur au lieu de changer une
-- valeur de jeu en douce.

local function deepFreeze<T>(value: T): T
	local t = value :: any
	if type(t) == "table" and not table.isfrozen(t) then
		for _, child in t do
			deepFreeze(child)
		end
		table.freeze(t)
	end
	return value
end

return deepFreeze
