--!nocheck
-- Scénario « steal » (exigence 2, vol pendant l'antivol ; vrai PvPService) : Bob vole l'objet sous antivol posé
-- au sol de la boutique d'Ada (StealFloorItem en deux appels, mêmes règles que StealItem) ; échec (coup de batte) :
-- l'objet revient à sa place ; réussite (dépôt chez Bob) : il quitte le profil d'Ada et arrive dans l'inventaire de
-- Bob, de nouveau sous antivol (sans UnlockAt ni Spot), jamais sur un présentoir. Fini, il n'est plus volable.

advance(1000)
startServer()
PvPService = serverModule("PvPService")
local PvP = sharedModule("Config/PvP")

local ada = join("Ada", nil)
local bob = join("Bob", nil)
advance(1.5)
check(shopOf(ada) ~= nil and shopOf(bob) ~= nil and shopOf(ada) ~= shopOf(bob), "deux boutiques")
local uid = bringItem(ada, "Z3_TeleGeante", "Epic", 3, { Effect = "Gold" })
local entry = placeItemAt(ada, uid, 6, 0)
check(entry and entry.Spot ~= nil, "objet Épique d'Ada posé au sol, antivol en cours")
moveTo(ada, refsOfShop(shopOf(ada)).center + Vector3.new(-20, 0, 20))
local itemPos = floorItemOf(ada, uid):GetPivot().Position
local plotIndex = shopOf(ada):GetAttribute("PlotIndex")

local function standByItem(player)
	moveTo(player, itemPos + Vector3.new(2, 3, 0))
	advance(0.05)
end
local function steal(player, id)
	fireAs(player, "StealFloorItem", plotIndex, id or uid)
	flush()
	advance(PvP.StealGrabTime + 0.05)
	fireAs(player, "StealFloorItem", plotIndex, id or uid)
	flush()
end

section("porte intacte : refusé")
standByItem(bob)
steal(bob)
check(not CarryService.IsCarrying(bob) and floorItemOf(ada, uid) ~= nil, "boutique fermée : rien")

section("porte cassée : prise en deux appels")
breakDoor(ada, bob)
check(shopOf(ada):GetAttribute("StealOpen") == true, "boutique ouverte au vol (StealOpen)")
standByItem(bob)
fireAs(bob, "StealFloorItem", plotIndex, uid)
flush()
fireAs(bob, "StealFloorItem", plotIndex, uid)
flush()
check(not CarryService.IsCarrying(bob), "maintien trop court : refusé")
advance(PvP.StealGrabTime + 0.05)
fireAs(bob, "StealFloorItem", plotIndex, uid)
flush()
check(CarryService.IsCarrying(bob), "maintien assez long : Bob porte l'objet")
local payload = CarryService.GetPayload(bob)
check(payload and payload.Kind == "PlayerItem" and payload.ItemUid == uid and payload.SlotIndex == 0 and payload.VictimUserId == ada.UserId, "payload PlayerItem, SlotIndex 0, victime Ada")
check(payload and payload.Mutation and payload.Mutation.Effect == "Gold", "mutation sur BB_Carry")
check(floorItemOf(ada, uid) == nil and UnboxService.IsFloorHeld(ada, uid), "modèle sorti du monde, objet tenu")
check(dataOf(ada).Items[uid] ~= nil, "profil d'Ada inchangé pendant la fuite")
check(#notifies(ada, "is stealing your") == 1, "Notify à Ada")
local theft = PvPService.GetTheft(bob)
check(theft and theft.Victim == ada and theft.ItemUid == uid and theft.SlotIndex == 0, "GetTheft : vol au sol (SlotIndex 0)")
fireAs(ada, "OpenBox", uid)
flush()
check(dataOf(ada).Items[uid].Spot ~= nil, "Ada ne peut pas le reprendre pendant le vol")

section("coup de batte : l'objet revient à sa place")
CarryService.Fail(bob, "Bat")
flush()
check(not CarryService.IsCarrying(bob) and floorItemOf(ada, uid) ~= nil and not UnboxService.IsFloorHeld(ada, uid), "revenu au sol")
check(#notifies(ada, "is back in your shop") == 1, "Notify « Your Giant TV is back in your shop! »")
check(dataOf(ada).Items[uid].AntiTheft == true and dataOf(ada).Items[uid].Spot ~= nil, "toujours chez Ada, sous antivol")

section("second vol : dépôt chez Bob")
standByItem(bob)
steal(bob)
check(CarryService.IsCarrying(bob), "Bob porte l'objet")
advance(4)
moveTo(bob, refsOfShop(shopOf(bob)).deposit)
advance(0.5)
check(not CarryService.IsCarrying(bob), "déposé")
check(dataOf(ada).Items[uid] == nil, "l'objet a quitté le profil d'Ada")
local got = dataOf(bob).Items[uid]
check(got ~= nil and got.Id == "Z3_TeleGeante" and got.Source == "PvP" and got.Mutation and got.Mutation.Effect == "Gold", "chez Bob (même uid, Source PvP, mutation)")
check(got ~= nil and got.AntiTheft == true and got.UnlockAt == nil and got.Spot == nil, "de nouveau sous antivol, dans l'inventaire (attente complète à la pose)")
local displayed = false
for _, v in dataOf(bob).Display do
	if v == uid then
		displayed = true
	end
end
check(not displayed and invItem(bob, uid) ~= nil and invItem(bob, uid).AntiTheft == true, "pas sur un présentoir : dans l'inventaire, marqué")
check(#notifies(bob, "its anti-theft starts there") == 1, "Notify « You stole the Gold Giant TV! Put it down… »")
check(dataOf(bob).Lifetime.Steals == 1, "vol compté")
check(floorItemOf(ada, uid) == nil, "plus de modèle chez Ada")

section("chez Bob : il le pose, l'antivol repart de zéro")
local t0 = serverTime()
local mine = placeItemAt(bob, uid, -6, 0)
check(mine.Spot ~= nil and math.abs(mine.UnlockAt - (t0 + 0.35 + antiTheftOf("Epic"))) < 0.5, "posé chez Bob : antivol complet")

section("antivol fini : plus volable")
local uid2 = bringItem(ada, "Z1_Banane", "Common", 1)
placeItemAt(ada, uid2, -6, 0)
advance(antiTheftOf("Common") + 0.5)
breakDoor(ada, bob)
moveTo(bob, floorItemOf(ada, uid2):GetPivot().Position + Vector3.new(2, 3, 0))
advance(0.05)
steal(bob, uid2)
check(not CarryService.IsCarrying(bob) and dataOf(ada).Items[uid2] ~= nil, "débloqué : refusé")

summary("scénario steal")
