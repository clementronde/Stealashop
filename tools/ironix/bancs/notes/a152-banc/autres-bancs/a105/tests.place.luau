--!nocheck
-- Scénario « place » (exigence 2 de la vague 31) : l'objet sous antivol se pose au sol de SA boutique
-- (PlaceBox avec son uid, règles de la pose d'un colis) ; l'antivol démarre (ShelfOpen.AntiTheft[rareté], heure
-- serveur) ; modèle FloorItem au sol (tag, attribut UnlockAt), plus dans l'état de l'inventaire ; refusé par les
-- présentoirs (PlaceItemAuto, PlaceItem, Equip Best) ; reprise refusée avant « UNLOCKED! » ; Notify à la fin ;
-- reprise (OpenBox) : sur un présentoir libre, sinon dans l'inventaire ; retour du joueur : remis au sol.

advance(1000)
startServer()

local ada = join("Ada", nil)
advance(1.5)
local uid = bringItem(ada, "Z3_TeleGeante", "Epic", 3)
check(uid ~= nil, "objet Épique rangé sous antivol")

section("présentoirs refusés tant qu'il est dans l'inventaire sous antivol")
fireAs(ada, "PlaceItemAuto", uid)
flush()
check(#notifies(ada, "Put this item down in your shop first") == 1, "PlaceItemAuto : Notify « Put this item down… »")
check(next(dataOf(ada).Display) == nil, "aucun présentoir pris")
local ok, why = DisplayService.PlaceItem(ada, uid, 1)
check(ok == false and why == "AntiTheft", "DisplayService.PlaceItem : refus « AntiTheft »")
check(DisplayService.PlaceAuto(ada, uid) == nil, "PlaceAuto : nil")
check(DisplayService.EquipBest(ada) == 0 and next(dataOf(ada).Display) == nil, "Equip Best : ne le pose pas")
dataOf(ada).Display["2"] = uid
advance(1.2)
check(dataOf(ada).Display["2"] == nil and logHas("sous antivol", "WARN"), "Display qui le montre : retiré (sanitize)")

section("pose : refus honnêtes")
local far = floorPoint(ada, 0, 0)
moveTo(ada, far + Vector3.new(0, 3, 30))
advance(0.3)
fireAs(ada, "PlaceBox", uid, far)
flush()
check(dataOf(ada).Items[uid].Spot == nil and #notifies(ada, "Get closer to put your item down") == 1, "trop loin : Notify « Get closer… »")
local other = refsOfShop(SHOPS[4].model) and SHOPS[4].S.origin * Vector3.new(0, 0.3, 0)
moveTo(ada, other + Vector3.new(1, 3, 1))
advance(0.3)
fireAs(ada, "PlaceBox", uid, other)
flush()
check(dataOf(ada).Items[uid].Spot == nil and #notifies(ada, "inside your own shop") == 1, "chez un autre : Notify « Put your item down inside your own shop. »")

section("pose acceptée : l'antivol démarre")
local placedEvents = {}
UnboxService.OnItemPlaced(function(player, itemUid, itemId)
	table.insert(placedEvents, { uid = itemUid, itemId = itemId })
end)
local t0 = serverTime()
local entry = placeItemAt(ada, uid, 6, 0)
check(entry.Spot ~= nil and entry.AntiTheft == true, "Spot posé, toujours sous antivol")
check(entry.UnlockAt ~= nil and math.abs(entry.UnlockAt - (t0 + 0.35 + antiTheftOf("Epic"))) < 0.5, `UnlockAt = maintenant + {antiTheftOf("Epic")} s (Épique)`)
local model = floorItemOf(ada, uid)
check(model ~= nil and hasTag(model, "FloorItem") and near(model:GetAttribute("UnlockAt"), entry.UnlockAt), "modèle FloorItem au sol, tag FloorItem, attribut UnlockAt")
check(model ~= nil and model:GetAttribute("ItemId") == "Z3_TeleGeante" and model:GetAttribute("OwnerUserId") == ada.UserId and model:GetAttribute("Rarity") == "Epic", "attributs ItemId, OwnerUserId, Rarity")
check(model ~= nil and model:FindFirstChild("BB_Item", true) == nil, "pas de BB_Item (BB_AntiTheft côté client)")
check(invItem(ada, uid) == nil, "plus dans l'état de l'inventaire")
flush()
check(#placedEvents == 1 and placedEvents[1].uid == uid, "OnItemPlaced(player, uid, itemId)")
check(UnboxService.IsStealable(ada, uid) and UnboxService.GetFloorItems(ada)[uid] ~= nil, "volable pendant l'antivol")

section("reprise refusée pendant l'antivol")
standNear(ada, floorPoint(ada, 6, 0))
fireAs(ada, "OpenBox", uid)
flush()
check(dataOf(ada).Items[uid].Spot ~= nil and #notifies(ada, "Anti-theft still on") == 1, "OpenBox : Notify « Anti-theft still on… », reste au sol")
fireAs(ada, "PlaceItemAuto", uid)
flush()
check(next(dataOf(ada).Display) == nil, "PlaceItemAuto : toujours refusé")

section("place prise au sol : un colis ne se pose pas dessus")
local boxUid = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
local box = placeAt(ada, boxUid, 6, 0)
check(box.Spot == nil and #notifies(ada, "No room here") >= 1, "colis au même point : refusé (Blocked)")

section("fin de l'antivol")
advance(antiTheftOf("Epic") + 0.5)
check(not UnboxService.IsStealable(ada, uid), "plus volable")
check(#notifies(ada, "is UNLOCKED!") == 1, "Notify « Giant TV is UNLOCKED! Put it on a display. »")
advance(1)
check(#notifies(ada, "is UNLOCKED!") == 1, "une seule fois")

section("reprise : dans l'inventaire, jamais posé tout seul (vague 44, a152 ; ce banc n'a pas HeldItemService : pas de main)")
standNear(ada, floorPoint(ada, 6, 0))
fireAs(ada, "OpenBox", uid)
flush()
local after = dataOf(ada).Items[uid]
check(after ~= nil and after.AntiTheft == nil and after.UnlockAt == nil and after.Spot == nil, "antivol retiré du profil")
local slot = nil
for key, value in dataOf(ada).Display do
	if value == uid then
		slot = key
	end
end
check(slot == nil and invItem(ada, uid) ~= nil and invItem(ada, uid).Slot == nil, "pas sur un présentoir : dans l'inventaire (a152)")
check(floorItemOf(ada, uid) == nil, "le modèle au sol est parti")
check(#notifies(ada, "is in your inventory") == 1 and #notifies(ada, "placed on a display") == 0, "Notify « Giant TV is in your inventory. » (a152)")

section("reprise avec les présentoirs pleins : dans l'inventaire")
local data = dataOf(ada)
for n = 1, 4 do
	if data.Display[tostring(n)] == nil then
		addItem(data, `stand{n}`, "Z1_Donut", n, 1, 1)
	end
end
advance(1.2)
local uid2 = bringItem(ada, "Z1_Banane", "Common", 1)
placeItemAt(ada, uid2, -6, 0)
advance(antiTheftOf("Common") + 0.5)
standNear(ada, floorPoint(ada, -6, 0))
fireAs(ada, "OpenBox", uid2)
flush()
check(data.Items[uid2].AntiTheft == nil and invItem(ada, uid2) ~= nil and invItem(ada, uid2).Slot == nil, "dans l'inventaire, libre")
check(#notifies(ada, "is in your inventory") == 2, "Notify « Banana is in your inventory. » (a152)")

section("retour du joueur : l'objet posé revient au sol")
local uid3 = bringItem(ada, "Z3_Smartphone", "Rare", 3)
local e3 = placeItemAt(ada, uid3, -20, 16)
check(e3.Spot ~= nil, "troisième objet posé")
local unlockAt = e3.UnlockAt
local saved = dataOf(ada)
leave(ada)
advance(1)
local ada2 = join("Ada", nil, ada.UserId)
advance(1.5)
local back = dataOf(ada2).Items[uid3]
check(back ~= nil and back.Spot ~= nil and near(back.UnlockAt, unlockAt), "profil relu : toujours posé, même UnlockAt")
check(floorItemOf(ada2, uid3) ~= nil, "modèle remis au sol")
check(saved ~= nil, "profil sauvegardé au départ")

summary("scénario place")
