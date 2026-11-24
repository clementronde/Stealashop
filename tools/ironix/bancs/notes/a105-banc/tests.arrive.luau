--!nocheck
-- Scénario « arrive » (L-112, point 6 du déroulé ; exigence 1 de la vague 31) : l'objet porté (payload NPCItem)
-- entre dans l'inventaire à l'entrée de la zone safe, comme le colis : anti-triche juste avant, Consume, profil
-- écrit d'un seul tenant (Items[uid] avec AntiTheft = true, sans UnlockAt ni Spot), braquage compté, Notify,
-- BoxSecured, Index ; état de l'inventaire marqué « A » ; pas dans le couloir ; inventaire plein et payload mal
-- formé : portage rendu ; le colis NPCBox garde l'ancien déroulé.

advance(1000)
startServer()

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(sharedModule("Config/Features").ShelfOpen == true, "Features.ShelfOpen = true (main)")

local ada = join("Ada", nil)
advance(1.5)

section("couloir : l'objet reste sur la tête")
moveTo(ada, CORRIDOR)
advance(0.1)
CarryService.Give(ada, npcItem("Z3_Smartphone", "Rare", 3, { Size = "Big", Effect = "Gold" }))
advance(1)
check(CarryService.IsCarrying(ada) and next(dataOf(ada).Items) == nil, "dans le couloir : toujours porté, rien dans le profil")

section("entrée dans la zone safe : l'objet entre dans l'inventaire sous antivol")
local heists = dataOf(ada).Lifetime.Heists
local verifies = #VERIFY_CALLS
local stowed = {}
UnboxService.OnItemStowed(function(player, uid, itemId)
	table.insert(stowed, { player = player, uid = uid, itemId = itemId })
end)
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.6)
check(not CarryService.IsCarrying(ada), "l'objet a quitté la tête")
local uid, entry = next(dataOf(ada).Items)
check(type(uid) == "string" and entry ~= nil and entry.Id == "Z3_Smartphone" and entry.Source == "NPC" and entry.Zone == 3, "Items[uid] = l'objet porté (Id, Source NPC, zone)")
check(entry ~= nil and entry.AntiTheft == true and entry.UnlockAt == nil and entry.Spot == nil, "sous antivol, pas encore posé (ni UnlockAt ni Spot)")
check(entry ~= nil and entry.Mutation ~= nil and entry.Mutation.Size == "Big" and entry.Mutation.Effect == "Gold", "mutation gardée")
check(countKeys(dataOf(ada).Boxes) == 0, "aucun colis créé")
check(dataOf(ada).Lifetime.Heists == heists + 1, "braquage compté une fois")
check(#VERIFY_CALLS == verifies + 1 and VERIFY_CALLS[#VERIFY_CALLS].from ~= nil, "AntiCheatService.Verify juste avant, avec le point de départ du portage")
local ends = CARRY_ENDS[#CARRY_ENDS]
check(ends ~= nil and ends.result == "Consumed" and ends.player == ada, "portage fini en « Consumed »")
check(#notifies(ada, "Item secured!") == 1, "Notify « Item secured! Put it down in your shop… »")
check(#remotes("BoxSecured", function(e) return e.to == ada and e.args[2] == "Rare" end) == 1, "BoxSecured (arrivée en zone safe, rareté)")
check(dataOf(ada).Index.Z3_Smartphone ~= nil, "objet découvert dans l'Index")
flush()
check(#stowed == 1 and stowed[1].uid == uid and stowed[1].itemId == "Z3_Smartphone", "OnItemStowed(player, uid, itemId)")
advance(0.6)
check(dataOf(ada).Lifetime.Heists == heists + 1 and countKeys(dataOf(ada).Items) == 1, "rien de rangé deux fois")

section("état de l'inventaire : objet marqué sous antivol")
local inv = invItem(ada, uid)
check(inv ~= nil and inv.AntiTheft == true and inv.Slot == nil, "état : objet de l'inventaire, AntiTheft")
check(string.find(ada:GetAttribute("InventoryState") or "", ",A", 1, true) ~= nil, "8e champ « A » dans le texte")

section("payload mal formé : rendu")
moveTo(ada, CORRIDOR)
advance(0.1)
CarryService.Give(ada, npcItem("Pas_Un_Objet", "Rare", 3))
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.6)
local last = CARRY_ENDS[#CARRY_ENDS]
check(last.result == "Failed" and last.reason == "Invalid" and countKeys(dataOf(ada).Items) == 1, "ItemId inconnu : Fail « Invalid », rien d'écrit")

section("inventaire plein : rendu")
local data = dataOf(ada)
for n = 1, sharedModule("Config/Balance").Display.InventoryMax do
	addItem(data, `fill{n}`, "Z1_Donut", nil, 1, 1)
end
moveTo(ada, CORRIDOR)
advance(0.1)
local count = countKeys(data.Items)
CarryService.Give(ada, npcItem("Z1_Banane", "Common", 1))
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.6)
last = CARRY_ENDS[#CARRY_ENDS]
check(last.result == "Failed" and last.reason == "InventoryFull" and countKeys(data.Items) == count, "plein : Fail « InventoryFull », rien d'écrit")
check(#notifies(ada, "Your inventory is full") >= 1, "Notify « Your inventory is full… »")
for n = 1, sharedModule("Config/Balance").Display.InventoryMax do
	data.Items[`fill{n}`] = nil
end

section("colis NPCBox : l'ancien déroulé reste (récompenses, camion, tuto)")
local boxUid = bringBox(ada, "Rare", "Z3_Smartphone", "Premium", 3)
check(boxUid ~= nil and dataOf(ada).Boxes[boxUid] ~= nil and dataOf(ada).Boxes[boxUid].Spot == nil, "colis rangé dans Boxes, comme avant")

summary("scénario arrive")
