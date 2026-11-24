--!nocheck
-- Codes de test ajoutés à la liste du serveur (a274 : server/Services/Code/GiftCodes.luau) avant le chargement : un
-- expiré, une potion, un pas encore commencé (StartsAt loin devant), un déjà commencé (StartsAt passé).
do
	local key = "server/Services/Code/GiftCodes.luau"
	local from = '{ Code = "LAUNCH", Reward = { Kind = "Boost", Minutes = 15 } },'
	local s = SOURCES[key]
	assert(s, "GiftCodes.luau pas monté")
	local a, b = string.find(s, from, 1, true)
	assert(a, "code LAUNCH introuvable")
	SOURCES[key] = string.sub(s, 1, b)
		.. '\n{ Code = "OldCode", EndsAt = 1000, Reward = { Kind = "Cash", Amount = 500 } },'
		.. '\n{ Code = "Potion2", Reward = { Kind = "Potion", PotionId = "Money", Count = 2 } },'
		.. '\n{ Code = "SoonCode", StartsAt = 4000000000, Reward = { Kind = "Cash", Amount = 700 } },'
		.. '\n{ Code = "StartedCode", StartsAt = 1, Reward = { Kind = "Cash", Amount = 300 } },'
		.. string.sub(s, b + 1)
end
