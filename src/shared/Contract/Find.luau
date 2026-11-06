--!strict
-- Règle de recherche des noms du contrat, commune au code et au ContractChecker.
-- Le code retrouve les choses par nom, jamais par chemin (doc, section 2.1) :
-- dans un chemin "List.Template.Price", chaque segment est cherché parmi les
-- descendants du précédent, pas seulement ses enfants directs. Clément peut donc
-- ajouter des cadres ou des dossiers autour d'un élément sans casser le code.

local Find = {}

-- Tous les descendants de `root` nommés `name`.
function Find.all(root: Instance, name: string): { Instance }
	local found = {}
	for _, descendant in root:GetDescendants() do
		if descendant.Name == name then
			table.insert(found, descendant)
		end
	end
	return found
end

-- Le premier élément trouvé au bout de `path` (segments séparés par des points), ou nil.
function Find.path(root: Instance, path: string): Instance?
	local current: Instance? = root
	for segment in string.gmatch(path, "[^%.]+") do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(segment, true)
	end
	return current
end

return Find
