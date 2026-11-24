-- a426 : interrupteur coupé, Config/Features.SafeZoneSpeed = false (la source est réécrite avant le chargement).
do
	local key = "shared/Config/Features.luau"
	local patched, count = string.gsub(SOURCES[key], "SafeZoneSpeed = true", "SafeZoneSpeed = false")
	assert(count == 1, "Features.SafeZoneSpeed introuvable")
	SOURCES[key] = patched
end
