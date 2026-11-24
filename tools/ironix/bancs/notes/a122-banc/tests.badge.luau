--!nocheck
-- Scénario « badge » du banc a122 (vague 37), sur la mise en place du banc a118 (lue sur place) : CardAlert et
-- SlotAlert passent par Shared/AlertBadge (AlertBadge.IsOn), s'allument, battent sur la même horloge (la
-- pastille d'une carte et celle d'une case ont le même Scale au même instant), s'éteignent (Scale 1) quand
-- l'action est faite ; la règle de NeedsAction ne change pas.
advance(1000)
startServer()
local data = newProfile()
data.Items.locked = { Id = "Z3_TeleGeante", Source = "NPC", At = 0, Zone = 3, AntiTheft = true }
addItem(data, "free", "Z1_Banane", nil, 1, 1)
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
addAlertParts()
startClient(ada)
advance(0.5)
local Inventory = clientModule("InventoryController")
local AlertBadge = sharedModule("AlertBadge", "client") -- le module du client, celui des contrôleurs

section("sources")
check(not string.find(SOURCES["client/Controllers/InventoryController.luau"], "stepPulses", 1, true), "InventoryController : plus d'horloge de battement à lui")
check(not string.find(SOURCES["client/Controllers/HotbarController.luau"], "stepPulses", 1, true), "HotbarController : plus d'horloge de battement à lui")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")

section("règle NeedsAction inchangée")
check(Inventory.NeedsAction("locked") == true, "objet sous antivol : à poser")
check(Inventory.NeedsAction("free") == true, "objet libre, présentoir libre : à exposer")

section("allumées par AlertBadge")
Inventory.Open()
advance(0.2)
local card = cardsOf("Items").Item_free
local slot = slotsOf().Slot_Item_free
check(card ~= nil and slot ~= nil, "carte et case de l'objet libre")
check(AlertBadge.IsOn(cardPart(card, "CardAlert")), "CardAlert allumée par AlertBadge")
check(AlertBadge.IsOn(slotPart(slot, "SlotAlert")), "SlotAlert allumée par AlertBadge")
check(not AlertBadge.IsOn(slotPart(slotsOf().Slot_Tool, "SlotAlert")), "pas de pastille sur l'outil")

section("battent, une seule horloge")
local cardPulse = cardPart(card, "CardAlert.Pulse")
local slotPulse = slotPart(slot, "SlotAlert.Pulse")
local same, lo, hi = true, math.huge, -math.huge
for _ = 1, 30 do
	advance(1 / 30)
	if math.abs(cardPulse.Scale - slotPulse.Scale) > 1e-6 then
		same = false
	end
	lo = math.min(lo, cardPulse.Scale)
	hi = math.max(hi, cardPulse.Scale)
end
check(hi > 1.14 and hi <= 1.15 + 1e-6 and lo < 1.02 and lo >= 1 - 1e-6, `Pulse entre 1 et 1,15 ({lo} à {hi})`)
check(same, "carte et case battent ensemble (horloge d'AlertBadge)")

section("éteintes quand l'action est faite")
local unlocked = ada:GetAttribute("DisplaySlotsUnlocked")
ada:SetAttribute("DisplaySlotsUnlocked", 0)
advance(0.2)
local freeSlot = slotsOf().Slot_Item_free
check(not AlertBadge.IsOn(slotPart(freeSlot, "SlotAlert")) and slotPart(freeSlot, "SlotAlert.Pulse").Scale == 1, "plus de présentoir libre : SlotAlert éteinte, Scale 1")
check(Inventory.NeedsAction("free") == false and Inventory.NeedsAction("locked") == true, "NeedsAction : l'objet sous antivol reste à poser")
ada:SetAttribute("DisplaySlotsUnlocked", unlocked)
advance(0.2)
check(AlertBadge.IsOn(slotPart(slotsOf().Slot_Item_free, "SlotAlert")), "présentoir libre de nouveau : rallumée")
click(cardPart(cardsOf("Items").Item_free, "PlaceButton"))
advance(0.6)
local displayed = cardsOf("Items").Item_free
check(displayed ~= nil and not AlertBadge.IsOn(cardPart(displayed, "CardAlert")) and cardPart(displayed, "CardAlert.Pulse").Scale == 1, "objet exposé : CardAlert éteinte, Scale 1")
Inventory.Close()
advance(0.5)

summary("scénario badge")
