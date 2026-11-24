--!nocheck
-- a319 : Id du banc pour le gamepass ×2 Speed (DoubleSpeed = 9007), après pre.on.luau (boutique ouverte).
do
	local key = "shared/Config/Monetization.luau"
	local from = '{ Key = "DoubleSpeed", Id = 0,'
	local first, last = string.find(SOURCES[key], from, 1, true)
	assert(first, "a319 : DoubleSpeed introuvable dans Config/Monetization")
	SOURCES[key] = string.sub(SOURCES[key], 1, first - 1) .. '{ Key = "DoubleSpeed", Id = 9007,' .. string.sub(SOURCES[key], last + 1)
end
