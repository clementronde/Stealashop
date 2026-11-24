--!nocheck
-- Codes de test ajoutés à Config/Codes avant le chargement : un expiré, une potion.
do
	local key = "shared/Config/Codes.luau"
	local from = '{ Code = "LAUNCH", Reward = { Kind = "Boost", Minutes = 15 } },'
	local s = SOURCES[key]
	local a, b = string.find(s, from, 1, true)
	assert(a, "code LAUNCH introuvable")
	SOURCES[key] = string.sub(s, 1, b) .. '\n{ Code = "OldCode", EndsAt = 1000, Reward = { Kind = "Cash", Amount = 500 } },\n{ Code = "Potion2", Reward = { Kind = "Potion", PotionId = "Money", Count = 2 } },' .. string.sub(s, b + 1)
end
