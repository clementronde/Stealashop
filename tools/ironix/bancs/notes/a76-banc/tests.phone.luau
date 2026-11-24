--!nocheck
-- Scénario « phone » (vague 25) : téléphone = TouchSlotCount (4) cases montrées ; les cases 5 et 6 sont
-- gardées (disposition et profil) mais pas montrées ; une chose nouvelle ne va que dans une case vide
-- montrée.

advance(1000)
startServer()
local data = newProfile()
addItem(data, "a", "Z1_Banane", nil, 1, 1)
addItem(data, "b", "Z1_Donut", nil, 1, 2)
addItem(data, "c", "Z3_Smartphone", nil, 3, 3)
data.Hotbar = { "Tool", "Bat", "a", "b", "c", "" }
local ada = join("Ada", data)
advance(1.5)
UserInputServiceStub.TouchEnabled = true
UserInputServiceStub.KeyboardEnabled = false
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local Hotbar = clientModule("HotbarController")
local function L()
	return layoutText(Hotbar.GetState().Layout)
end

section("4 cases montrées, 6 gardées")
check(Hotbar.GetState().Count == 4 and slotOrder() == "Slot_Tool,Slot_Bat,Slot_Item_a,Slot_Item_b", `4 cases : {slotOrder()}`)
check(L() == "Tool,Bat,a,b,c,", `case 5 gardée : {L()}`)
local box = bringBox(ada, "Rare", "Z3_Smartphone", "Premium", 3)
advance(1)
check(L() == "Tool,Bat,a,b,c," and slotsOf()["Slot_Box_" .. box] == nil, "nouveau colis : pas de case vide montrée, il reste dans l'inventaire (pas en case 6 cachée)")
check(layoutText(dataOf(ada).Hotbar) == "Tool,Bat,a,b,c,", "profil inchangé")

section("case montrée vidée au doigt, puis remplie")
layoutBar()
touchDrag(slotAtRank(4), { slotCenter(4) + Vector2.new(0, -20), Vector2.new(500, 200) })
advance(0.1)
check(L() == "Tool,Bat,a,,c,", `case 4 vidée au doigt : {L()}`)
local other = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
advance(1)
check(L() == `Tool,Bat,a,{other},c,`, `nouveau colis en case 4 : {L()}`)
check(layoutText(dataOf(ada).Hotbar) == L(), "gardé, case 5 comprise")

summary("scénario phone")
