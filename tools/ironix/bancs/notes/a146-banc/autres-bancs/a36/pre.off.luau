-- Interrupteur coupé : Config/Features.AntiCheat = false (la source est réécrite avant le chargement).
do
	local key = "shared/Config/Features.luau"
	local patched, count = string.gsub(SOURCES[key], "AntiCheat = true", "AntiCheat = false")
	assert(count == 1, "Features.AntiCheat introuvable")
	SOURCES[key] = patched
end
