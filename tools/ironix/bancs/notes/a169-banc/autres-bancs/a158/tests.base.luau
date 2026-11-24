--!nocheck
-- Scénario « base » du banc a158 (vague 50, Cantin 2026-11-14 : le colis porté, rangé, posé et ouvert en base
-- n'existe plus) : UnboxService sans colis (GiveBox retiré, accroches OnBox* inertes, PlaceBox et OpenBox d'un uid de
-- Boxes refusés, ni BoxReady ni UnboxReveal ni BoxSecured) ; colis d'un ancien profil convertis au chargement
-- (DataService.convertBoxes, sans condition) ; un objet de rayon ramené = antivol au sol comme avant.

PV = 8
advance(1000)
startServer()

section("API d'UnboxService : le colis est retiré, les accroches du tuto sont inertes")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(UnboxService.GiveBox == nil, "GiveBox retiré")
check(type(UnboxService.GiveItem) == "function", "GiveItem gardé (récompenses)")
local called = 0
check(UnboxService.OnBoxStowed == nil and UnboxService.GetBoxPosition == nil, "a169 : OnBoxStowed et GetBoxPosition retirées (lues par le tuto seul)")
local off = UnboxService.OnBoxPlaced(function()
	called += 1
end)
UnboxService.OnBoxPlaced(function()
	called += 1
end)
UnboxService.OnBoxOpened(function()
	called += 1
end)
check(type(off) == "function", "OnBoxPlaced rend toujours une déconnexion")
check(type(UnboxService.GetOpenDelay) == "function" and type(UnboxService.GetLuck) == "function", "GetOpenDelay et GetLuck encore là (MonetizationService, GiveItem)")

section("ancien profil avec des colis : convertis au chargement")
local data = newProfile(6)
data.Version = PV
data.BoxQueue = nil
data.Rewards = { Daily = { Streak = 0, LastDay = 0 }, Playtime = { Day = 0, Seconds = 0, Claimed = {} } }
data.Boxes = {
	stored1 = { Tier = "Premium", Zone = 3, ItemId = "Z3_Smartphone", Rarity = "Rare", Mutation = { Size = "Big" }, At = 77 },
	placed1 = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", ReadyAt = 4000, Spot = { X = 6, Y = 0.3, Z = 0 }, At = 88 },
	broken1 = { Tier = "Standard", Zone = 1, ItemId = "Pas_Un_Objet", Rarity = "Common" },
}
local ada = join("Ada", data)
advance(1.5)
local d = dataOf(ada)
check(d.Version == PV, "version du profil inchangée")
check(countKeys(d.Boxes) == 1 and d.Boxes.broken1 ~= nil, "Boxes : seul le colis illisible reste (le champ reste dans le profil)")
local s = d.Items.stored1
check(s and s.Id == "Z3_Smartphone" and s.AntiTheft == nil and s.Mutation and s.Mutation.Size == "Big", "colis de l'inventaire → objet libre, mutation gardée")
local p = d.Items.placed1
check(p and p.Id == "Z1_Banane" and p.Spot == nil and p.AntiTheft == nil, "colis posé → objet de l'inventaire, sans Spot")
check(floorBoxOf(ada, "placed1") == nil, "aucun modèle FloorBox au sol")
check(UnboxService.GetBoxPosition == nil, "a169 : GetBoxPosition retirée")
check(#remotes("BoxReady") == 0, "aucun BoxReady")

section("PlaceBox et OpenBox d'un colis : refusés")
-- Un colis lisible écrit à la main dans le profil (comme l'aurait fait l'ancien code pendant la partie).
d.Boxes.late1 = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", At = 1 }
local point = floorPoint(ada, -6, 0)
standNear(ada, point)
advance(0.3)
fireAs(ada, "PlaceBox", "late1", point)
flush()
check(d.Boxes.late1.Spot == nil and d.Boxes.late1.ReadyAt == nil and floorBoxOf(ada, "late1") == nil, "PlaceBox(uid d'un colis) : rien n'est posé")
d.Boxes.late1.Spot = { X = -6, Y = 0.3, Z = 0 }
d.Boxes.late1.ReadyAt = 1
local items = countKeys(d.Items)
fireAs(ada, "OpenBox", "late1")
flush()
check(d.Boxes.late1 ~= nil and countKeys(d.Items) == items, "OpenBox(uid d'un colis) : rien n'est ouvert")
check(#remotes("UnboxReveal") == 0 and #remotes("BoxReady") == 0, "ni UnboxReveal ni BoxReady (les remotes restent définis, ils ne partent plus)")
check(next(UnboxService.GetWaiting(ada)) == nil and UnboxService.SkipWait(ada, "late1", 5) == nil, "GetWaiting et SkipWait : aucun colis en attente")
d.Boxes.late1 = nil

section("objet de rayon ramené : antivol au sol comme avant")
local heists = d.Lifetime.Heists
local uid = bringItem(ada, "Z3_TeleGeante", "Epic", 3)
check(uid ~= nil and d.Items[uid].AntiTheft == true and d.Items[uid].Spot == nil, "rangé sous antivol à l'entrée de la zone safe")
check(d.Lifetime.Heists == heists + 1, "braquage compté")
check(#remotes("ItemSecured", function(e) return e.to == ada and e.args[1] == "Z3_TeleGeante" end) == 1 and #remotes("BoxSecured") == 0, "ItemSecured(itemId), jamais BoxSecured")
check(countKeys(d.Boxes) == 1, "aucun colis créé")
local entry = placeItemAt(ada, uid, -6, 0)
check(entry.Spot ~= nil and entry.UnlockAt ~= nil and floorItemOf(ada, uid) ~= nil, "posé au sol (PlaceBox) : l'antivol démarre")
check(UnboxService.GetWaiting(ada)[uid] == entry.UnlockAt, "GetWaiting : l'objet sous antivol attend")
fireAs(ada, "OpenBox", uid)
flush()
check(d.Items[uid].AntiTheft == true and #notifies(ada, "Anti-theft still on") == 1, "reprise avant la fin : refusée")
advance(antiTheftOf("Epic") + 1)
check(#notifies(ada, "is UNLOCKED!") == 1, "Notify « … is UNLOCKED! »")
fireAs(ada, "OpenBox", uid)
flush()
check(d.Items[uid] ~= nil and d.Items[uid].AntiTheft == nil and d.Items[uid].Spot == nil and floorItemOf(ada, uid) == nil, "repris (OpenBox) : objet libre, plus au sol")
check(called == 0, "écouteurs OnBoxPlaced et OnBoxOpened : jamais appelés")

section("porteur d'un ancien colis (payload NPCBox) : rien n'est rangé")
moveTo(ada, CORRIDOR)
advance(0.1)
local before = countKeys(d.Items)
CarryService.Give(ada, { Kind = "NPCBox", Tier = "Standard", Zone = 1, Rarity = "Common", ItemId = "Z1_Banane", StoreId = "Store_1", SlotId = "Store_1/02" })
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.6)
check(countKeys(d.Boxes) == 1 and countKeys(d.Items) == before and #remotes("BoxSecured") == 0, "ni colis dans Boxes, ni objet, ni BoxSecured")
CarryService.Fail(ada, "Test")

summary("scénario base")
