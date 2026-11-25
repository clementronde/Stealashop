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

-- a436 (lot101, check-up a417 I12) : « dans la map jouée », la règle commune à tout le code et au ContractChecker.
-- Vrai si `instance` est dans le Workspace et que ni lui ni aucun de ses ancêtres sous le Workspace n'a un nom qui
-- commence par « _ » : les dossiers de travail (_INBOX_CLEMENT, _SANDBOX_IRONIX, _SHOWROOM_CLEMENT, _PROTO_*,
-- _PREVIEW_*, _BENCH_*… ; CLAUDE.md, « Qui touche à quoi dans Studio ») ne sont jamais lus par le jeu.
-- Le Workspace est lu à l'appel (ce module ne demande aucun service quand on le charge).
function Find.inMap(instance: Instance): boolean
	local ws = game:GetService("Workspace")
	if not instance:IsDescendantOf(ws) then
		return false
	end
	local node: Instance? = instance
	while node ~= nil and node ~= ws do
		if string.sub(node.Name, 1, 1) == "_" then
			return false
		end
		node = node.Parent
	end
	return true
end

return Find
