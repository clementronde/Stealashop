-- a134 (vague 40, 2026-11-14, rééquilibrage v2) : dans le faux arbre seulement, le remote HitWindow reprend son
-- ancien débit (10 appels sur une seconde glissante, sans débit régulier). Dans le jeu : 5 coups par seconde en
-- débit régulier (vérifié par le banc a134 et par les copies a134 d'a08 et d'a27). Les scénarios des bancs copiés
-- ici cassent une vitrine par une rafale de coups envoyés au même instant, pour arriver à ce qu'ils vérifient
-- (braquage, portage, vigile…) : ils gardent cette rafale.
-- Sans effet sur un arbre d'avant le rééquilibrage (le texte cherché n'y est pas).
do
	for key, src in SOURCES do
		if string.find(key, "Net/Definitions.luau", 1, true) then
			local a = string.find(src, "\t\tRatePerSecond = 5,\n", 1, true)
			local j1, j2 = string.find(src, "\t\tJitter = 0.5,\n", 1, true)
			if a and j1 then
				src = string.sub(src, 1, j1 - 1) .. string.sub(src, j2 + 1)
				SOURCES[key] = (string.gsub(src, "\t\tRatePerSecond = 5,\n", "\t\tRatePerSecond = 10,\n", 1))
			end
		end
	end
end
