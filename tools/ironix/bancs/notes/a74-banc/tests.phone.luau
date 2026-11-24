--!nocheck
-- Scénario « phone » (L-095 point 6) : écran tactile sans clavier = téléphone : TouchSlotCount (4) cases,
-- KeyLabel caché ; un appui fait l'action de la case ; touches 1 à 4 seulement (clavier branché à un
-- téléphone) ; TouchSlotCount suivi.

advance(1000)
startServer()
local data = newProfile()
addItem(data, "a", "Z1_Banane", nil, 1, 1)
addItem(data, "b", "Z1_Donut", nil, 1, 2)
addItem(data, "c", "Z3_Smartphone", nil, 3, 3)
local ada = join("Ada", data)
advance(1.5)
UserInputServiceStub.TouchEnabled = true
UserInputServiceStub.KeyboardEnabled = false
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local Hotbar = clientModule("HotbarController")

section("4 cases, sans numéros")
local slots, n = slotsOf()
check(n == 4 and Hotbar.GetState().Phone and Hotbar.GetState().Count == 4, `TouchSlotCount : 4 cases ({n})`)
check(slotOrder() == "Slot_Tool,Slot_Bat,Slot_Item_c,Slot_Item_a", `ordre : {slotOrder()}`)
local hidden = true
for _, slot in slots do
	hidden = hidden and slotPart(slot, "KeyLabel").Visible == false
end
check(hidden, "KeyLabel caché sur chaque case")

section("appui")
click(slots.Slot_Tool)
advance(0.05)
check(ada.Character:FindFirstChildWhichIsA("Tool") and slotPart(slots.Slot_Tool, "Equipped").Visible, "appui : outil en main, Equipped")
click(slots.Slot_Tool)
advance(0.05)
local sent = #serverCalls("PlaceItemAuto")
pressKey("Five")
advance(0.3)
check(#serverCalls("PlaceItemAuto") == sent, "touche 5 : rien (4 cases)")
pressKey("Four")
advance(0.3)
check(#serverCalls("PlaceItemAuto") == sent + 1 and serverCalls("PlaceItemAuto")[sent + 1].args[1] == "a", "touche 4 : l'objet de la 4e case")

section("TouchSlotCount suivi")
HB.screen.Bar:SetAttribute("TouchSlotCount", 3)
advance(0.1)
check(select(2, slotsOf()) == 3, "TouchSlotCount = 3 : 3 cases")

summary("scénario phone")
