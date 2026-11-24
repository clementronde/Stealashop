---------------------------------------------------------------- a296 : Traps = true ; NewTraps et NewTrapsDev lus tels quels ; jeu selon MODE
-- Copie adaptée de a293-banc/pre-pieges.luau. Rien n'est forcé dans Features hors Traps : Config doit avoir
-- NewTraps = false (PROD) et NewTrapsDev = true (DEV). MODE : "dev" et "prod" fixent Config/ProductIds.Environment
-- ("Dev", "Prod") ; "absent" retire le module ; "studio" = "prod" (l'attribut NewTrapsTest est posé par les tests).
do
	local key = "shared/Config/Features.luau"
	local src, n = string.gsub(SOURCES[key], "\n\tTraps = %a+,", "\n\tTraps = true,")
	assert(n == 1, "a296 : ligne Traps = … introuvable dans Config/Features")
	assert(string.find(src, "\n\tNewTraps = false,", 1, true), "a296 : Features.NewTraps n'est pas coupé")
	assert(string.find(src, "\n\tNewTrapsDev = true,", 1, true), "a296 : Features.NewTrapsDev n'est pas allumé")
	SOURCES[key] = src
	local pk = "shared/Config/ProductIds.luau"
	assert(SOURCES[pk], "a296 : Config/ProductIds absent de l'arbre")
	if MODE == "absent" then
		SOURCES[pk] = nil
	else
		local env = if MODE == "dev" then "Dev" else "Prod"
		local ps, pn = string.gsub(SOURCES[pk], 'ENVIRONMENT: Environment = "Auto"', `ENVIRONMENT: Environment = "{env}"`)
		assert(pn == 1, "a296 : ENVIRONMENT de Config/ProductIds introuvable")
		SOURCES[pk] = ps
	end
end
