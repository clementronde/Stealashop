---------------------------------------------------------------- a286 : Traps = true, NewTraps selon NEW_TRAPS
-- Copie de a268-banc/pre-pieges.luau, plus Features.NewTraps (disposition Traps.SlotLayoutNew).
do
	local key = "shared/Config/Features.luau"
	local src, n = string.gsub(SOURCES[key], "\n\tTraps = %a+,", "\n\tTraps = true,")
	assert(n == 1, "a286 : ligne Traps = … introuvable dans Config/Features")
	local wanted = if NEW_TRAPS then "true" else "false"
	local m
	src, m = string.gsub(src, "\n\tNewTraps = %a+,", "\n\tNewTraps = " .. wanted .. ",")
	assert(m == 1, "a286 : ligne NewTraps = … introuvable dans Config/Features")
	SOURCES[key] = src
end
