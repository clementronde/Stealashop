-- a134 (vague 40, 2026-11-14, rééquilibrage v2) : dans le faux arbre seulement, la Force du profil (Stats.Strength)
-- multiplie encore les dégâts d'un coup : arme × aura × (1 + Force / 100). Dans le jeu, la Force ne compte plus
-- (dégâts = arme × aura : vérifié par le banc a134 et par les copies a134 d'a08, a15 et a20). Les scénarios des
-- bancs copiés ici se servaient de la Force comme d'un levier pour régler les dégâts (« Strength = 10000 : la
-- vitrine casse en un coup ») : ils gardent ce levier, sans rapport avec ce qu'ils vérifient.
-- Sans effet sur un arbre d'avant le rééquilibrage (la ligne cherchée n'y est pas).
do
	for key, src in SOURCES do
		if string.find(key, "ToolService.luau", 1, true) then
			local needle = "Formulas.HitDamage(equippedDef(data).Power, auraMultiplier(player))"
			local a, b = string.find(src, needle, 1, true)
			if a then
				SOURCES[key] = string.sub(src, 1, b) .. " * (1 + data.Stats.Strength / 100)" .. string.sub(src, b + 1)
			end
		end
	end
end
