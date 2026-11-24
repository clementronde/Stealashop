--!nocheck
-- Scénario « draw » (a294) : Config du dépôt (boutique et caisse coupées, ProductIds « Auto », faux Roblox sans GameId :
-- PROD). D1 chances validées par Cantin (total 100, raretés de chaque case, jamais sous Épique) ; D2 100 000 tirages du
-- serveur : aucun sous Épique, chaque case à ±0,5 point de sa chance ; D3 hors DEV la caisse est coupée (ni montrée, ni
-- vendue, aucun ProcessReceipt).
startServer()
local Crate = Monetization.Crate
local ProductIds = sharedModule("Config/ProductIds")
local EPIC = Rarities.ById.Epic.Order

section("D1 chances et raretés")
local expected = { 30, 30, 25, 10, 4, 1 }
local rarities = { "Epic", "Epic", "Legendary", "Mythic", "Secret", "Divine" }
local sum = 0
for index, chance in Crate.Odds do
	sum += chance
	check(chance == expected[index], `case {index} : {chance} % (attendu {expected[index]})`)
end
check(#Crate.Odds == 6 and #Crate.Items == 6, "6 chances pour 6 objets")
check(sum == 100, `somme des chances = 100 ({sum})`)
for index, id in Crate.Items do
	local def = Items.ById[id]
	check(def ~= nil and def.Rarity == rarities[index], `case {index} : {id} {def and def.Rarity} (attendu {rarities[index]})`)
	check(def ~= nil and Rarities.ById[def.Rarity].Order >= EPIC, `case {index} : jamais sous Épique`)
end
check(Items.ById.Exclusive_DiscoBall.Rarity == "Epic", "Disco Ball : Épique (L-276)")

section("D2 100 000 tirages du serveur")
local draw = MonetizationService.BancDrawCrate
check(type(draw) == "function", "tirage du serveur exposé au banc")
local N = 100000
local seen, below, unknown = {}, 0, 0
for _ = 1, N do
	local id = draw()
	local def = Items.ById[id]
	if def == nil or table.find(Crate.Items, id) == nil then
		unknown += 1
	elseif Rarities.ById[def.Rarity].Order < EPIC then
		below += 1
	end
	seen[id] = (seen[id] or 0) + 1
end
check(unknown == 0, `aucun objet hors de la caisse ({unknown})`)
check(below == 0, `aucun tirage sous Épique sur {N} ({below})`)
for index, id in Crate.Items do
	local share = (seen[id] or 0) / N * 100
	check(math.abs(share - expected[index]) <= 0.5, string.format("%s : %.2f %% (attendu %d %% ± 0,5)", id, share, expected[index]))
end

section("D3 hors DEV : caisse coupée")
check(ProductIds.Environment == "Auto" and ProductIds.IsDev == false, "Auto, faux Roblox sans GameId : PROD")
check(Features.RobuxCrate == false and Features.RobuxCrateDev == true and Features.RobuxShop == false, "dépôt : RobuxCrate false, RobuxCrateDev true, boutique coupée")
check(Crate.Live == false, "Crate.Live faux hors DEV")
check(MarketplaceStub.ProcessReceipt == nil, "aucun ProcessReceipt branché")
check(not logHas("caisse exclusive allumée", "PRINT", "server") and not logHas("caisse exclusive testable", "PRINT", "server"), "ni vente ni crochet de la caisse")
local ada = join("Ada", newProfile())
advance(1.5)
local r = receipt(ada, CRATE_IDS[1], "P-1")
check(r.decision == "pas de ProcessReceipt", "reçu d'un lot : personne ne le traite")
check(#remotes("RevealStarted") == 0, "aucune ouverture")
summary("scénario draw")
