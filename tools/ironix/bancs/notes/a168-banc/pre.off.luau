-- a153 : Features.GuardChaseV2 = false.
do
	local key = "shared/Config/Features.luau"
	local patched, count = string.gsub(SOURCES[key], "GuardChaseV2 = true", "GuardChaseV2 = false")
	assert(count == 1, "Features.GuardChaseV2 introuvable")
	SOURCES[key] = patched
end
