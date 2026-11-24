-- a135 (vague 40, 2026-11-14) : dans le faux arbre seulement, Balance.Heist.Duration = 10 au lieu de 6. Les scénarios
-- des bancs copiés ici (ancien déroulé, ou faux WindowService sans chrono de casse) ont été écrits avec le chrono
-- de 10 s après la casse : ils gardent ce temps-là ; la durée elle-même est vérifiée par le banc a135 (heist).
-- Sans effet sur un arbre où Duration n'est pas 6 (avant la vague 40).
do
	local key = "shared/Config/Balance.luau"
	local src = SOURCES[key]
	if src then
		SOURCES[key] = string.gsub(src, "\n(%s*)Duration = 6,", "\n%1Duration = 10,", 1)
	end
end
