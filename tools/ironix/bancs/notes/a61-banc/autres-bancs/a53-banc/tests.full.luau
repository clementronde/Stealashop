--!nocheck
-- Scénario « full » (DEV-101) : colis offert avec l'inventaire de colis plein (Unbox.BoxInventoryMax) : rien
-- n'est donné ni noté, la récompense reste réclamable ; un colis posé au sol ne compte pas ; après une
-- place libérée, la même récompense passe.

advance(1000)
startServer()
days(10)
local data = newProfile8()
for n = 1, 50 do
	data.Boxes[string.format("full-%02d", n)] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", At = n }
end
data.Rewards.Daily = { Streak = 1, LastDay = 9 } -- J1 hier : J2 (colis Standard) aujourd'hui
local ada = join("Ada", data)
advance(1.5)
check(stateOf(ada).Day == 2 and storedBoxes(ada) == 50, "J2 à réclamer, 50 colis dans l'inventaire")

section("calendrier : inventaire plein")
claimDaily(ada)
check(storedBoxes(ada) == 50, "aucun colis de plus")
check(#notifies(ada, "Too many boxes in your inventory") == 1, "Notify « Too many boxes… »")
check(not stateOf(ada).DailyClaimed and dataOf(ada).Rewards.Daily.Streak == 1, "J2 pas noté : toujours réclamable")
check(#eventsOf(ada, "RewardClaim") == 0, "aucune télémétrie")
local uid, why = UnboxService.GiveBox(ada, "Standard", 1, nil)
check(uid == nil and why == "InventoryFull", "GiveBox : InventoryFull")

section("temps de jeu : inventaire plein")
addPlay(ada, 900)
claimPlay(ada, 15)
check(storedBoxes(ada) == 50 and dataOf(ada).Rewards.Playtime.Claimed["15"] == nil, "palier de 15 min pas noté")

section("une place libérée")
dataOf(ada).Boxes["full-01"] = nil
claimDaily(ada)
check(storedBoxes(ada) == 50 and stateOf(ada).DailyClaimed, "J2 réclamé : le colis prend la place")
claimPlay(ada, 15)
check(#notifies(ada, "Too many boxes") == 3, "palier de 15 min refusé de nouveau (plein)")
dataOf(ada).Boxes["full-02"].Spot = { X = 0, Y = 0, Z = 0 }
dataOf(ada).Boxes["full-02"].ReadyAt = 1
claimPlay(ada, 15)
check(dataOf(ada).Rewards.Playtime.Claimed["15"] ~= nil and storedBoxes(ada) == 50, "colis posé au sol : ne compte pas, palier 15 réclamé")
summary("scénario full")
