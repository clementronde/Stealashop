---------------------------------------------------------------- a243 : interrupteur et services ajoutés
-- a268 : copie de a267-banc/autres-bancs/a243/pre.luau ; SCENARIO = "on" : Traps = true.
do
	local key = "shared/Config/Features.luau"
	local wanted = if SCENARIO == "on" then "true" else "false"
	local src, n = string.gsub(SOURCES[key], "\n\tTraps = %a+,", "\n\tTraps = " .. wanted .. ",")
	assert(n == 1, "a267 : ligne Traps = … introuvable dans Config/Features")
	SOURCES[key] = src
end
