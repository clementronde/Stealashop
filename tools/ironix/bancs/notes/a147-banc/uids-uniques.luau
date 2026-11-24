-- a147 (vague 41, 2026-11-14) : faux arbre des bancs copiés. TelemetryService signale maintenant un même uid d'objet
-- chez deux joueurs du serveur (DuplicateItem, avertissement). Les profils de test (richProfile, victimProfile…)
-- donnent les mêmes uid à chaque joueur : à l'arrivée (join), un uid déjà chez un joueur présent devient
-- « <uid>#<n> » (présentoirs et coffres suivent). Le premier joueur arrivé garde les siens : les tests ne lisent que
-- ceux-là (la victime).
do
	local copies = {}
	local original = join
	join = function(name, data)
		if data ~= nil and type(data.Items) == "table" then
			local taken = {}
			for _, other in Players:GetPlayers() do
				local otherData = DataService and DataService.Get(other)
				if otherData then
					for uid in otherData.Items do
						taken[uid] = true
					end
				end
			end
			local renamed = {}
			for uid in table.clone(data.Items) do
				if taken[uid] then
					copies[uid] = (copies[uid] or 1) + 1
					local fresh = `{uid}#{copies[uid]}`
					data.Items[fresh] = data.Items[uid]
					data.Items[uid] = nil
					renamed[uid] = fresh
				end
			end
			for _, map in { data.Display, data.Vault } do
				if type(map) == "table" then
					for key, uid in map do
						if renamed[uid] then
							map[key] = renamed[uid]
						end
					end
				end
			end
		end
		return original(name, data)
	end
end
