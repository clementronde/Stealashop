--!nocheck
-- a142 (2026-11-14) : le clic qui termine un glisser ne met pas non plus l objet en main (aucun HoldItem).
-- Scénario « drag » (vague 25) : glisser-déposer à la souris et au doigt. Case → case (échange), case →
-- dehors (case vidée), carte de UI_Inventory → case (remplace ; l'ancienne chose retourne seulement dans
-- l'inventaire ; une chose déjà dans la barre change de case), outils (n'importe quel outil de casse =
-- "Tool", la batte = "Bat") ; copie semi-transparente qui suit le pointeur, détruite à la fin ;
-- HoverOutline de la case visée ; clic simple gardé, clic de fin de glisser ignoré ; carte d'un objet
-- exposé : pas de glisser ; au doigt : appui immobile (HOLD_TIME), défilement de la liste = pas de glisser,
-- liste figée pendant le glisser.

advance(1000)
startServer()
local data = newProfile()
addItem(data, "high", "Z3_Smartphone", nil, 3, 1)
addItem(data, "low", "Z1_Banane", nil, 1, 2)
addItem(data, "shown", "Z1_Donut", 1, 1, 3)
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local Hotbar = clientModule("HotbarController")
local Inventory = clientModule("InventoryController")
local box = bringBox(ada, "Rare", "Z3_Smartphone", "Premium", 3)
advance(1)
local function L()
	return layoutText(Hotbar.GetState().Layout)
end
local function held()
	return ada.Character:FindFirstChildWhichIsA("Tool")
end
check(L() == `Tool,Bat,high,low,{box},`, `départ : {L()}`)

section("case → case : échange, copie qui suit, case visée")
layoutBar()
local toolSlot = slotAtRank(1)
local ghostSeen, outlineSeen, transparency = false, false, nil
local sent = #hotbarSent()
mouseDrag(toolSlot, { slotCenter(1) + Vector2.new(4, 0), slotCenter(3) }, {
	activated = true,
	during = function(point)
		local ghost = dragGhost(ada)
		if point.X == slotCenter(3).X then
			ghostSeen = ghost ~= nil and ghost.Position == UDim2.fromOffset(point.X, point.Y) and ghost:FindFirstChild("Copy") ~= nil
			transparency = ghost and ghost.GroupTransparency
			outlineSeen = slotPart(slotAtRank(3), "HoverOutline").Visible
		elseif ghost ~= nil then
			ghostSeen = "trop tôt"
		end
	end,
})
check(ghostSeen == true, `une copie de la case suit le pointeur (DragGhost.Copy) après {8} px, pas avant ({ghostSeen})`)
check(transparency and transparency > 0 and transparency < 1, `copie semi-transparente (GroupTransparency {transparency})`)
check(outlineSeen, "case visée : HoverOutline visible")
advance(0.1)
check(L() == `high,Bat,Tool,low,{box},`, `outil et objet échangés : {L()}`)
check(dragGhost(ada) == nil, "copie détruite au lâcher")
check(not slotPart(slotsOf().Slot_Tool, "HoverOutline").Visible, "HoverOutline de la case visée caché ensuite")
check(held() == nil, "le clic qui termine le glisser est ignoré (pas d'outil en main)")
advance(0.6)
check(#hotbarSent() == sent + 1 and layoutText(dataOf(ada).Hotbar) == L(), "envoyé au serveur et gardé")
check(slotsOf().Slot_Tool.LayoutOrder == 3 and slotsOf().Slot_Item_high.LayoutOrder == 1, "cases redessinées à leur nouveau rang")

section("clic simple : effet gardé")
layoutBar()
local tool = slotAtRank(3)
mouseDrag(tool, { slotCenter(3) + Vector2.new(3, 2) }, { activated = true })
advance(0.1)
check(held() and held():GetAttribute("ToolId") == "Fists", "appui, 3 px, relâché : c'est un clic, l'outil en main")
check(L() == `high,Bat,Tool,low,{box},`, "rien ne bouge")
pressKey("Three")
advance(0.1)

section("case → dehors : case vidée")
layoutBar()
mouseDrag(slotAtRank(4), { Vector2.new(500, 200) })
advance(0.1)
check(L() == `high,Bat,Tool,,{box},`, `case 4 vidée : {L()}`)
check(invItem(ada, "low") and invItem(ada, "low").Slot == nil, "l'objet reste dans l'inventaire")
layoutBar()
mouseDrag(slotAtRank(5), { Vector2.new(BAR_ORIGIN.X + 50, BAR_ORIGIN.Y - 5), Vector2.new(BAR_ORIGIN.X + 599, BAR_ORIGIN.Y + 50) }, {})
advance(0.1)
check(L() == `high,Bat,Tool,,,{box}`, `case 5 lâchée sur la case 6 (vide) : déplacée : {L()}`)
layoutBar()
mouseDrag(slotAtRank(4), { Vector2.new(500, 200) })
advance(0.1)
check(L() == `high,Bat,Tool,,,{box}` and dragGhost(ada) == nil, "case vide : rien à glisser")

section("carte → case")
Inventory.Open()
Inventory.SelectTab("Items")
advance(0.5)
local low = cardOf("Items", "Item_low")
local sentPlace = #serverCalls("PlaceItemAuto")
layoutBar()
mouseDrag(low, { Vector2.new(300, 400), slotCenter(4) }, { activated = true })
advance(0.1)
check(L() == `high,Bat,Tool,low,,{box}`, `carte de l'objet lâchée sur la case vide 4 : {L()}`)
check(#serverCalls("PlaceItemAuto") == sentPlace and #serverCalls("HoldItem") == 0, "le clic qui termine le glisser n'expose pas l'objet (ni ne le met en main, a142)")
check(dragGhost(ada) == nil, "copie détruite")
local highCard = cardOf("Items", "Item_high")
layoutBar()
mouseDrag(highCard, { slotCenter(2) })
advance(0.1)
check(L() == `,high,Tool,low,,{box}`, `objet déjà en case 1 lâché sur la batte : il change de case, la batte retourne dans l'inventaire : {L()}`)
local shownCard = cardOf("Items", "Item_shown")
layoutBar()
mouseDrag(shownCard, { slotCenter(1) })
advance(0.1)
check(shownCard ~= nil and L() == `,high,Tool,low,,{box}` and dragGhost(ada) == nil, "carte d'un objet exposé : pas de glisser")
Inventory.SelectTab("Tools")
advance(0.2)
local batCard = cardOf("Tools", "Tool_Bat")
layoutBar()
mouseDrag(batCard, { slotCenter(1) })
advance(0.1)
check(L() == `Bat,high,Tool,low,,{box}`, `carte de la batte → case 1 : {L()}`)
local fistsCard = cardOf("Tools", "Tool_Fists")
layoutBar()
mouseDrag(fistsCard, { slotCenter(5) })
advance(0.1)
check(L() == `Bat,high,,low,Tool,{box}`, `carte d'un outil de casse → case 5 (« Tool » change de case) : {L()}`)
advance(0.3) -- passé SUPPRESS_TIME après le dernier lâcher
local fistsCard2 = cardOf("Tools", "Tool_Fists")
mouseDrag(fistsCard2, { Vector2.new(343, 242) }, { activated = true }) -- 3,6 px depuis le centre (340, 240)
advance(0.1)
check(held() and held():GetAttribute("ToolId") == "Fists", "clic simple sur une carte d'outil : effet gardé (en main)")

section("au doigt : appui immobile, liste figée")
Inventory.SelectTab("Boxes")
advance(0.2)
local boxCard = cardOf("Boxes", "Box_" .. box)
local list = INV.sections.Boxes.frame.Parent
check(list:IsA("ScrollingFrame"), "liste : un ScrollingFrame")
list.ScrollingEnabled = true
list.CanvasPosition = Vector2.new(0, 0)
local frozen = nil
layoutBar()
touchDrag(boxCard, {}, { hold = 0.4 })
-- appui de 0,4 s sans bouger puis relâché sur place : glisser commencé, lâché hors de la barre (carte)
check(L() == `Bat,high,,low,Tool,{box}` and dragGhost(ada) == nil, "appui immobile relâché sur la carte : rien ne change")
local input = { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown, Position = Vector3.new(340, 240, 0) }
boxCard.InputBegan:Fire(input)
flush()
advance(0.4)
check(Hotbar.GetState().Dragging and list.ScrollingEnabled == false, "doigt posé 0,4 s : glisser commencé, liste figée")
input.Position = Vector3.new(slotCenter(3).X, slotCenter(3).Y, 0)
UserInputServiceStub.InputChanged:Fire(input, false)
flush()
check(dragGhost(ada) ~= nil and slotPart(slotAtRank(3), "HoverOutline").Visible, "la copie suit le doigt, case 3 visée")
UserInputServiceStub.InputEnded:Fire(input, false)
flush()
advance(0.1)
check(L() == `Bat,high,{box},low,Tool,`, `colis lâché en case 3 (il quitte la case 6) : {L()}`)
check(list.ScrollingEnabled == true and not Hotbar.GetState().Dragging, "liste rendue à son défilement")

section("au doigt : un défilement n'est pas un glisser")
local lowCard = INV.sections.Boxes.cards:FindFirstChild("Box_" .. box)
input = { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown, Position = Vector3.new(340, 240, 0) }
lowCard.InputBegan:Fire(input)
flush()
list.CanvasPosition = Vector2.new(0, 30) -- la liste suit le doigt
input.Position = Vector3.new(340, 210, 0)
UserInputServiceStub.InputChanged:Fire(input, false)
flush()
advance(0.5)
check(not Hotbar.GetState().Dragging and dragGhost(ada) == nil, "liste qui défile : pas de glisser, même après HOLD_TIME")
UserInputServiceStub.InputEnded:Fire(input, false)
flush()
check(L() == `Bat,high,{box},low,Tool,` and list.ScrollingEnabled == true, "rien ne change")
Inventory.Close()

section("case → case au doigt")
layoutBar()
touchDrag(slotAtRank(1), { slotCenter(1) + Vector2.new(20, 0), slotCenter(6) })
advance(0.1)
check(L() == `,high,{box},low,Tool,Bat`, `batte glissée au doigt vers la case 6 : {L()}`)
advance(1)
check(layoutText(dataOf(ada).Hotbar) == L(), "gardé dans le profil")

summary("scénario drag")
