---------------------------------------------------------------- a243 : interrupteur et services ajoutés
-- Scénario « on » : Features.Traps = true dans le source assemblé (le dépôt garde false).
if SCENARIO == "on" then
	local key = "shared/Config/Features.luau"
	local src, n = string.gsub(SOURCES[key], "\n\tTraps = false,", "\n\tTraps = true,")
	assert(n == 1, "a243 : ligne Traps = false introuvable dans Config/Features")
	SOURCES[key] = src
end
