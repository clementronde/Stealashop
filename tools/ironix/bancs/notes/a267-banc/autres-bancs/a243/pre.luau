---------------------------------------------------------------- a243 : interrupteur et services ajoutés
-- a267 (vague 80) : le dépôt a Traps = true ; « off » le remet à false, « on » à true, dans le source assemblé.
do
	local key = "shared/Config/Features.luau"
	local wanted = if SCENARIO == "on" then "true" else "false"
	local src, n = string.gsub(SOURCES[key], "\n\tTraps = %a+,", "\n\tTraps = " .. wanted .. ",")
	assert(n == 1, "a267 : ligne Traps = … introuvable dans Config/Features")
	SOURCES[key] = src
end
