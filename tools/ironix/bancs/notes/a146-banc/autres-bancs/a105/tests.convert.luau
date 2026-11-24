--!nocheck
-- Scénario « convert » (exigence 3 de la vague 31) : avec Features.ShelfOpen, les colis déjà dans un profil
-- (Boxes, posés ou non) deviennent des objets de l'inventaire, sans antivol, au chargement (DataService), sans
-- changer la version du profil ; idempotent (rechargement, objet déjà converti sous le même uid) ; un colis
-- illisible reste ; la mutation suit, jamais sur l'objet du tuto.

PV = 8
advance(1000)
startServer()
local Tutorial = sharedModule("Config/Tutorial")

section("profil v8 avec des colis")
local data = newProfile(6)
data.Version = PV
data.BoxQueue = nil
data.Rewards = { Daily = { Streak = 0, LastDay = 0 }, Playtime = { Day = 0, Seconds = 0, Claimed = {} } }
data.Boxes = {
	stored1 = { Tier = "Premium", Zone = 3, ItemId = "Z3_Smartphone", Rarity = "Rare", Mutation = { Size = "Big" }, At = 77 },
	placed1 = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = 4000, Spot = { X = 6, Y = 0.3, Z = 0 }, At = 88 },
	tuto1 = { Tier = "Standard", Zone = 1, ItemId = Tutorial.GuaranteedItemId, Rarity = "Rare", Mutation = { Effect = "Gold" } },
	broken1 = { Tier = "Standard", Zone = 1, ItemId = "Pas_Un_Objet", Rarity = "Common" },
	again1 = { Tier = "Standard", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common" },
}
data.Items.again1 = { Id = "Z1_Donut", Source = "NPC", At = 5, Zone = 1 } -- déjà converti (garde-fou)
data.Items.clash1 = { Id = "Z1_Donut", Source = "NPC", At = 5, Zone = 1 }
data.Boxes.clash1 = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common" } -- uid pris par un autre objet
data.Hotbar = { "Tool", "Bat", "stored1", "", "", "" }
local ada = join("Ada", data)
advance(1.5)
local d = dataOf(ada)
check(d.Version == PV, "version du profil inchangée (v8)")
check(countKeys(d.Boxes) == 1 and d.Boxes.broken1 ~= nil, "Boxes : seul le colis illisible reste")
local s = d.Items.stored1
check(s and s.Id == "Z3_Smartphone" and s.Source == "NPC" and s.Zone == 3 and s.At == 77 and s.Mutation and s.Mutation.Size == "Big", "colis de l'inventaire → objet sous le même uid (zone, At, mutation)")
check(s and s.AntiTheft == nil and s.Spot == nil and s.UnlockAt == nil, "sans antivol")
local p = d.Items.placed1
check(p and p.Id == "Z1_Banane" and p.AntiTheft == nil and p.Spot == nil, "colis posé → objet de l'inventaire, sans antivol ni Spot")
local t = d.Items.tuto1
check(t and t.Id == Tutorial.GuaranteedItemId and t.Mutation == nil, "objet du tuto : sans mutation")
local againCount = 0
for _, item in d.Items do
	if item.Id == "Z1_Donut" then
		againCount += 1
	end
end
check(d.Items.again1 ~= nil and againCount == 2, "déjà converti (même uid, même Id) : pas de doublon")
local bananas = 0
for uid, item in d.Items do
	if item.Id == "Z1_Banane" and uid ~= "placed1" then
		bananas += 1
	end
end
check(d.Items.clash1.Id == "Z1_Donut" and bananas == 1, "uid déjà pris par un autre objet : uid neuf")
check(logHas("colis devenu(s) objet(s)"), "sortie : la conversion")
check(floorBoxOf(ada, "placed1") == nil, "plus de colis au sol")
check(invItem(ada, "stored1") ~= nil and invItem(ada, "stored1").AntiTheft == nil, "dans l'état de l'inventaire, libre")
check(d.Hotbar ~= nil and d.Hotbar[3] == "stored1", "la case de la barre du bas garde l'uid (devenu l'objet)")
check(d.Index.Z3_Smartphone ~= nil, "Index : objets convertis découverts (filet du chargement)")
local ok = DisplayService.PlaceAuto(ada, "stored1")
check(ok ~= nil, "objet converti exposable tout de suite")

section("rechargement : idempotent")
local count = countKeys(d.Items)
local userId = ada.UserId
leave(ada)
advance(2)
local ada2 = join("Ada", nil, userId)
advance(1.5)
local d2 = dataOf(ada2)
check(countKeys(d2.Items) == count and countKeys(d2.Boxes) == 1, "même nombre d'objets, colis illisible toujours là")
check(d2.Version == PV, "version toujours v8")

summary("scénario convert")
