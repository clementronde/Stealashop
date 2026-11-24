--!nocheck
-- Index ouvert (Features.Index = true) et boutique Robux branchée (Features.RobuxShop = true : bonus
-- Premium et boost ×2 argent, pour la règle « les % s'additionnent, les ×2 se multiplient »). Seul le
-- pack d'argent de 10 min a un Id (8002, comme a38) : son montant doit compter le bonus de l'index.
setFeature("Index", true)
setFeature("RobuxShop", true)
do
	local key = "shared/Config/Monetization.luau"
	local source = SOURCES[key]
	local from = '{ Key = "Cash10", Id = 0,'
	local first, last = string.find(source, from, 1, true)
	assert(first, `remplacement introuvable dans {key} : {from}`)
	SOURCES[key] = string.sub(source, 1, first - 1) .. '{ Key = "Cash10", Id = 8002,' .. string.sub(source, last + 1)
end
