--!nocheck
-- Scénario « off » (exigence 7 de la vague 31) : Features.ShelfOpen = false → l'ancien déroulé exact. Un objet
-- porté NPCItem n'est pas rangé ; les colis d'un profil restent des colis (pas de conversion) ; un objet marqué
-- AntiTheft (profil écrit pendant un essai) est un objet libre : présentoirs permis, aucune pose au sol ;
-- StealFloorItem n'est pas branché ; aucun modèle FloorItem.

advance(1000)
startServer()

section("interrupteur coupé")
check(sharedModule("Config/Features").ShelfOpen == false, "Features.ShelfOpen = false")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")

local data = newProfile(6)
data.Version = 8
data.BoxQueue = nil
data.Rewards = { Daily = { Streak = 0, LastDay = 0 }, Playtime = { Day = 0, Seconds = 0, Claimed = {} } }
data.Boxes = { stored1 = { Tier = "Premium", Zone = 3, ItemId = "Z3_Smartphone", Rarity = "Rare", At = 1 } }
data.Items.locked1 = { Id = "Z3_TeleGeante", Source = "NPC", At = 1, Zone = 3, AntiTheft = true, UnlockAt = 99999999, Spot = { X = 6, Y = 0.3, Z = 0 } }
local ada = join("Ada", data)
advance(1.5)
check(dataOf(ada).Boxes.stored1 ~= nil and dataOf(ada).Items.stored1 == nil, "colis du profil : toujours un colis (pas de conversion)")
check(not logHas("colis devenu(s) objet(s)"), "aucune ligne de conversion")
check(floorItemOf(ada, "locked1") == nil, "aucun objet au sol")
local inv = invItem(ada, "locked1")
check(inv ~= nil and inv.AntiTheft == nil, "objet marqué AntiTheft : objet libre de l'inventaire")
check(not string.find(ada:GetAttribute("InventoryState") or "", ",A", 1, true), "texte de l'état : ancien format (7 champs)")
fireAs(ada, "PlaceItemAuto", "locked1")
flush()
local shown = false
for _, v in dataOf(ada).Display do
	if v == "locked1" then
		shown = true
	end
end
check(shown, "PlaceItemAuto : exposé comme avant")

section("objet porté NPCItem : pas rangé")
moveTo(ada, CORRIDOR)
advance(0.1)
local count = countKeys(dataOf(ada).Items)
CarryService.Give(ada, npcItem("Z1_Banane", "Common", 1))
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.6)
check(CarryService.IsCarrying(ada) and countKeys(dataOf(ada).Items) == count, "toujours porté, rien d'écrit")
CarryService.Fail(ada, "Test")

section("colis : ancien déroulé")
local boxUid = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
local box = placeAt(ada, boxUid, -6, 0)
check(box and box.Spot ~= nil and box.ReadyAt ~= nil, "colis rangé puis posé, attente de sa rareté")
local itemUid = openPlaced(ada, boxUid)
check(itemUid ~= nil and dataOf(ada).Items[itemUid] ~= nil and dataOf(ada).Items[itemUid].AntiTheft == nil, "ouvert en base : objet libre")
fireAs(ada, "PlaceBox", "locked1", floorPoint(ada, 12, 0))
flush()
check(dataOf(ada).Items.locked1.Spot ~= nil and floorItemOf(ada, "locked1") == nil, "PlaceBox d'un objet : ignoré (aucun objet au sol)")

section("vol au sol : pas branché")
local bob = join("Bob", nil)
advance(1.5)
breakDoor(ada, bob)
local ok = pcall(function()
	fireAs(bob, "StealFloorItem", shopOf(ada):GetAttribute("PlotIndex"), "locked1")
	flush()
end)
check(not CarryService.IsCarrying(bob), "StealFloorItem sans effet")
check(ok, "remote sans écouteur côté serveur : aucune erreur")

summary("scénario off")
