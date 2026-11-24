---------------------------------------------------------------- a293 : Traps = true ; NewTraps lu tel quel (allumé par a293) ou coupé
-- Copie de a286-banc/pre-pieges.luau : NEW_TRAPS = true vérifie que Config/Features a déjà NewTraps = true (rien
-- n'est forcé) ; NEW_TRAPS = false coupe NewTraps (ancienne disposition).
do
	local key = "shared/Config/Features.luau"
	local src, n = string.gsub(SOURCES[key], "\n\tTraps = %a+,", "\n\tTraps = true,")
	assert(n == 1, "a293 : ligne Traps = … introuvable dans Config/Features")
	if NEW_TRAPS then
		assert(string.find(src, "\n\tNewTraps = true,", 1, true), "a293 : Features.NewTraps n'est pas allumé")
	else
		local m
		src, m = string.gsub(src, "\n\tNewTraps = %a+,", "\n\tNewTraps = false,")
		assert(m == 1, "a293 : ligne NewTraps = … introuvable dans Config/Features")
	end
	SOURCES[key] = src
end
