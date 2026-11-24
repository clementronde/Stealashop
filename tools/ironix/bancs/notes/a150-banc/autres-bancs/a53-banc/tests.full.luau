--!nocheck
-- Copie d'a150 (2026-11-14, vague 43) : la récompense « Box » donne un objet ; inventaire d'objets plein
-- (Balance.Display.InventoryMax objets non exposés, DisplayService.HasInventoryRoom) : rien n'est donné ni
-- noté, la récompense reste réclamable (Notify ItemsFull) ; un objet exposé ne compte pas ; 50 colis dans
-- l'inventaire ne bloquent plus rien (on ne donne plus de colis) ; après une place libérée, la même
-- récompense passe.

advance(1000)
startServer()
days(10)
local MAX = sharedModule("Config/Balance").Display.InventoryMax
local data = newProfile8()
for n = 1, MAX do
	addItem(data, string.format("full-%02d", n), "Z1_Banane", nil, 1, n)
end
data.Rewards.Daily = { Streak = 1, LastDay = 9 } -- J1 hier : J2 (colis Standard) aujourd'hui
local ada = join("Ada", data)
advance(1.5)
local function itemCount()
	local n = 0
	for _ in dataOf(ada).Items do
		n += 1
	end
	return n
end
check(stateOf(ada).Day == 2 and itemCount() == MAX, `J2 à réclamer, {MAX} objets dans l'inventaire`)

section("calendrier : inventaire plein")
claimDaily(ada)
check(itemCount() == MAX and storedBoxes(ada) == 0, "aucun objet ni colis de plus")
check(#notifies(ada, "Your inventory is full") == 1, "Notify « Your inventory is full… »")
check(not stateOf(ada).DailyClaimed and dataOf(ada).Rewards.Daily.Streak == 1, "J2 pas noté : toujours réclamable")
check(#eventsOf(ada, "RewardClaim") == 0, "aucune télémétrie")
local uid, why = UnboxService.GiveItem(ada, "Standard", 1, nil)
check(uid == nil and why == "InventoryFull", "GiveItem : InventoryFull")

section("temps de jeu : inventaire plein")
addPlay(ada, 900)
claimPlay(ada, 15)
check(itemCount() == MAX and dataOf(ada).Rewards.Playtime.Claimed["15"] == nil, "palier de 15 min pas noté")

section("une place libérée")
dataOf(ada).Items["full-01"] = nil
claimDaily(ada)
check(itemCount() == MAX and stateOf(ada).DailyClaimed, "J2 réclamé : l'objet prend la place")
claimPlay(ada, 15)
check(#notifies(ada, "Your inventory is full") == 3, "palier de 15 min refusé de nouveau (plein)")
dataOf(ada).Display["1"] = "full-02"
claimPlay(ada, 15)
check(dataOf(ada).Rewards.Playtime.Claimed["15"] ~= nil and itemCount() == MAX + 1, "objet exposé : ne compte pas, palier 15 réclamé")

section("50 colis dans l'inventaire : plus de blocage")
local bob = newProfile8()
for n = 1, 50 do
	bob.Boxes[string.format("box-%02d", n)] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", At = n }
end
bob.Rewards.Daily = { Streak = 1, LastDay = 9 }
local bobPlayer = join("Bob", bob)
advance(1.5)
local keys = itemKeys(bobPlayer)
claimDaily(bobPlayer)
check(#giftsSince(bobPlayer, keys) == 1 and storedBoxes(bobPlayer) == 50, "J2 donne un objet ; les 50 colis restent")
check(#notifies(bobPlayer, "Too many boxes") == 0, "plus de Notify « Too many boxes… »")
summary("scénario full")
