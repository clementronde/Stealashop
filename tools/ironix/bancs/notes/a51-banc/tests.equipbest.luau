--!nocheck
-- Scénario « equipbest » (L-079, L-089 point 3 ; remote EquipBest, règle V0 de DisplayService) : les N
-- objets qui rapportent le plus vont sur les N présentoirs utilisables ; un exposé qui en fait partie ne
-- bouge pas ; un exposé moins bon retourne dans l'inventaire ; l'inventaire ne grossit jamais ; ni le
-- coffre-fort ni un objet tenu par un voleur ne bougent ; mutation comprise ; où que soit le joueur.

advance(1000)
startServer()

local function incomeOf(itemId, zone, mutation)
	local def = Items.ById[itemId]
	return Formulas.ItemIncome(def.Zone or zone or 1, def.Rarity) * sharedModule("Config/Mutations").IncomeMultiplier(mutation)
end
local function displayedSet(player)
	local out = {}
	for key, uid in dataOf(player).Display do
		out[uid] = tonumber(key)
	end
	return out
end
local function storedCount(player)
	local shown = displayedSet(player)
	local n = 0
	for uid in dataOf(player).Items do
		if shown[uid] == nil and dataOf(player).Vault["1"] ~= uid then
			n += 1
		end
	end
	return n
end

-- Un objet de chaque rareté connue (zones 1 à 3) pour avoir des revenus bien distincts.
local function pick(zone, rarity)
	for _, item in Items.List do
		if item.Zone == zone and item.Rarity == rarity and not item.TutorialOnly then
			return item.Id
		end
	end
	return nil
end
local C1, U1, R3, E3 = pick(1, "Common"), pick(2, "Uncommon"), pick(3, "Rare"), pick(3, "Epic")
check(C1 and U1 and R3 and E3, `objets de test trouvés ({C1}, {U1}, {R3}, {E3})`)

section("Equip Best : les meilleurs sur les présentoirs")
local data = newProfile()
addItem(data, "c1", C1, 1, 1, 1) -- exposé, le moins bon
addItem(data, "u1", U1, 2, 2, 2) -- exposé
addItem(data, "r3", R3, nil, 3, 3) -- inventaire
addItem(data, "e3", E3, nil, 3, 4) -- inventaire
addItem(data, "c1b", C1, nil, 1, 5) -- inventaire, le moins bon
addItem(data, "safe", E3, nil, 3, 6)
data.Vault["1"] = "safe"
local ada = join("Ada", data)
advance(1.5)
check(incomeOf(E3, 3) > incomeOf(R3, 3) and incomeOf(R3, 3) > incomeOf(U1, 2) and incomeOf(U1, 2) > incomeOf(C1, 1), "revenus : Épique > Rare > Peu commun > Commun")
local stored = storedCount(ada)
moveTo(ada, CORRIDOR) -- où que soit le joueur
advance(1.2)
fireAs(ada, "EquipBest")
flush()
local shown = displayedSet(ada)
check(shown.e3 ~= nil and shown.r3 ~= nil and shown.u1 == 2 and shown.c1 ~= nil, "4 présentoirs : Épique, Rare, Peu commun (pas bougé), Commun exposés")
check(shown.c1 == 1 and shown.u1 == 2 and shown.c1b == nil, "les exposés gardent leur présentoir ; le 2e Commun reste dans l'inventaire")
check(shown.safe == nil and dataOf(ada).Vault["1"] == "safe", "l'objet du coffre-fort ne bouge pas")
check(storedCount(ada) <= stored, "l'inventaire ne grossit pas")
check(#notifies(ada, "Your best items are now on display!") == 1, "Notify « Your best items are now on display! »")
advance(0.6)
check(toolsOf(ada)["Item:e3"] == nil and toolsOf(ada)["Item:r3"] == nil and toolsOf(ada)["Item:c1b"] ~= nil, "barre à jour : les exposés n'ont plus de Tool")

section("rien à changer")
advance(1.2)
fireAs(ada, "EquipBest")
flush()
check(#notifies(ada, "already on display") == 1, "Notify « Your best items are already on display. »")

section("un meilleur objet remplace le moins bon")
local data2 = dataOf(ada)
addItem(data2, "e3b", E3, nil, 3, 7)
advance(1.2)
fireAs(ada, "EquipBest")
flush()
shown = displayedSet(ada)
check(shown.e3b ~= nil and shown.c1 == nil and shown.e3 ~= nil and shown.r3 ~= nil and shown.u1 ~= nil, "le 2e Épique prend la place du Commun, qui retourne dans l'inventaire")
check(shown.e3b == 1, "sur le présentoir libéré (1)")

section("débit : 1 par seconde")
local before = #notifies(ada)
fireAs(ada, "EquipBest")
fireAs(ada, "EquipBest")
flush()
check(#notifies(ada) == before, "deux appels dans la seconde : ignorés par Net")

section("objet tenu par un voleur : ni lui ni son présentoir ne bougent")
moveTo(ada, refsOfShop(shopOf(ada)).center)
local heldSlot = DisplayService.Hold(ada, "u1")
check(heldSlot == 2, "Peu commun tenu (présentoir 2)")
addItem(data2, "r3b", R3, nil, 3, 8)
advance(1.2)
fireAs(ada, "EquipBest")
flush()
shown = displayedSet(ada)
check(shown.u1 == 2 and shown.e3 ~= nil and shown.e3b ~= nil and shown.r3 ~= nil and shown.r3b == nil, "tenu : reste sur le présentoir 2 ; à revenu égal (2e Rare), l'objet déjà exposé reste")
DisplayService.Release(ada, "u1")

section("mutation comprise")
local data3 = newProfile()
addItem(data3, "plain", U1, 1, 2, 1)
addItem(data3, "gold", C1, nil, 1, 2)
data3.Items.gold.Mutation = { Size = "Big", Effect = "Gold" }
addItem(data3, "x1", C1, 2, 1, 3)
addItem(data3, "x2", C1, 3, 1, 4)
addItem(data3, "x3", C1, 4, 1, 5)
local bob = join("Bob", data3)
advance(1.5)
local Mutations = sharedModule("Config/Mutations")
local goldIncome = incomeOf(C1, 1, data3.Items.gold.Mutation)
check(goldIncome > incomeOf(C1, 1), `Commun Big Gold : {goldIncome} $/s`)
advance(1.2)
fireAs(bob, "EquipBest")
flush()
local shownB = displayedSet(bob)
check(shownB.gold ~= nil, "le Commun muté passe devant un Commun simple")

section("sans boutique : rien")
for i = 1, 4 do
	join("P" .. i, nil)
end
advance(1.5)
local late = join("Late", nil)
advance(1.5)
addItem(dataOf(late), "l1", C1, nil, 1, 1)
fireAs(late, "EquipBest")
flush()
check(next(dataOf(late).Display) == nil and #notifies(late, "You don't have a shop yet") == 1, "sans boutique : rien, « You don't have a shop yet… »")
check(DisplayService.EquipBest(late) == 0, "EquipBest(player) = 0 sans boutique")

summary("scénario equipbest")
