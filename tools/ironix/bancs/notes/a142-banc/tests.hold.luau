--!nocheck
-- Scénario « hold » du banc a142 : objet de l'inventaire en main par la barre du bas (vrais HeldItemService,
-- InventoryController, HotbarController) : mise en main et rangement, refus du serveur, rangement au portage, à la
-- mort et au départ, aucune duplication, antivol (mode pose gardé).
advance(1000)
startServer()
local data = newProfile()
addItem(data, "small", "Z1_Banane", nil, 1, 3)
addItem(data, "phone", "Z3_Smartphone", nil, 3, 2)
data.Items.phone.Mutation = { Size = "Colossal" }
addItem(data, "shown", "Z1_Banane", 1, 1, 1)
addItem(data, "safe", "Z1_Banane", nil, 1, 0)
table.insert(data.Vault, "safe")
data.Items.locked = { Id = "Z3_TeleGeante", Source = "NPC", At = 4, Zone = 3, AntiTheft = true }
local ada = join("Ada", data)
local bobData = newProfile()
addItem(bobData, "bobs", "Z1_Banane", nil, 1, 0)
local bob = join("Bob", bobData)
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local Inventory = clientModule("InventoryController")
local Hotbar = clientModule("HotbarController")
local Held = serverModule("HeldItemService")

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
local function slotOf(uid)
	return slotsOf()["Slot_Item_" .. uid]
end
check(slotOf("small") and slotOf("phone") and slotOf("locked"), `cases des objets de l'inventaire : {slotOrder()}`)
local before = snapshot(ada)

section("mise en main par la case, rangement par la même case")
click(slotOf("small"))
flush()
advance(0.1)
local tool = heldTool(ada)
check(tool ~= nil and tool:GetAttribute("HeldItemUid") == "small", "le Tool de l'objet est en main")
check(ada:GetAttribute("HeldItem") == "small" and Held.GetHeld(ada) == "small", "attribut HeldItem et GetHeld")
check(tool and tool.CanBeDropped == false and tool.RequiresHandle == true and tool:FindFirstChild("Handle") ~= nil, "Tool : poignée, pas lâchable")
local model = tool and tool:FindFirstChild("HeldItem")
check(model ~= nil and hasTag(model, "CarriedItem"), "modèle HeldItem, tag CarriedItem (effet de mutation)")
local allLoose, welded = true, true
if model then
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			allLoose = allLoose and not d.Anchored and not d.CanCollide and d.Massless and not d.CanQuery and not d.CanTouch
			local weld = d:FindFirstChildOfClass("WeldConstraint")
			welded = welded and weld ~= nil and weld.Part0 == tool.Handle
		end
	end
	check(model:FindFirstChild("BB_Item", true) == nil, "pas de BB_Item sur l'objet tenu")
end
check(allLoose, "pièces désancrées, sans collision, requête, contact ni masse")
check(welded, "chaque pièce soudée à la poignée")
check(slotPart(slotOf("small"), "Equipped").Visible, "Equipped sur la case de l'objet tenu")
check(snapshot(ada) == before, "profil inchangé (Items, Display, argent)")
check(invItem(ada, "small") and invItem(ada, "small").Slot == nil, "l'objet reste dans l'inventaire")
click(slotOf("small"))
flush()
advance(0.1)
check(heldTool(ada) == nil and #itemTools(ada) == 0, "re-choisi : rangé, Tool détruit (rien dans le Backpack)")
check(ada:GetAttribute("HeldItem") == nil and Held.GetHeld(ada) == nil, "attribut retiré")
check(not slotPart(slotOf("small"), "Equipped").Visible, "Equipped caché")

section("touche, autre case, outil de casse, batte")
local key = nil
for i, slot in Hotbar.GetState().Slots do
	if slot.Uid == "small" then
		key = i
	end
end
pressKey(({ "One", "Two", "Three", "Four", "Five", "Six" })[key])
flush()
advance(0.1)
check(heldTool(ada) and heldTool(ada):GetAttribute("HeldItemUid") == "small", `touche {key} : en main`)
click(slotOf("phone"))
flush()
advance(0.1)
check(heldTool(ada) and heldTool(ada):GetAttribute("HeldItemUid") == "phone" and #itemTools(ada) == 1, "autre case : l'autre objet, un seul Tool")
check(not slotPart(slotOf("small"), "Equipped").Visible and slotPart(slotOf("phone"), "Equipped").Visible, "Equipped suit")
click(slotsOf().Slot_Tool)
flush()
advance(0.1)
local inHand = ada.Character:FindFirstChildWhichIsA("Tool")
check(inHand and inHand:GetAttribute("ToolId") ~= nil and #itemTools(ada) == 0, "outil de casse : l'objet est rangé")
click(slotOf("small"))
flush()
advance(0.1)
check(heldTool(ada) ~= nil and ada.Character:FindFirstChildWhichIsA("Tool") == heldTool(ada), "objet : l'outil de casse retourne au Backpack")
local inBackpack = true
for _, child in ada.Backpack:GetChildren() do
	if child:GetAttribute("HeldItemUid") ~= nil then
		inBackpack = false
	end
end
check(inBackpack, "rien de l'objet dans le Backpack")
click(slotsOf().Slot_Bat)
flush()
advance(0.1)
check(#itemTools(ada) == 0, "batte : l'objet est rangé")
click(slotsOf().Slot_Bat)
advance(0.1)

section("refus du serveur")
local function refused(uid, label, player)
	local who = player or ada
	advance(0.3) -- débit de HoldItem : 4 par seconde (Net)
	holdAs(who, uid)
	check(#itemTools(who) == 0 and who:GetAttribute("HeldItem") == nil, label)
end
refused("shown", "objet exposé : refusé")
refused("safe", "objet au coffre-fort : refusé")
refused("bobs", "objet d'un autre joueur : refusé")
refused("nothing", "uid inconnu : refusé")
local boxUid = bringBox(ada, "Rare", "Z3_Smartphone", "Premium", 3)
advance(0.3)
if boxUid then
	refused(boxUid, "colis : refusé")
else
	check(false, "colis rapporté pour le refus")
end
check(logHas("HoldItem(shown) refusé : exposé") and logHas("HoldItem(safe) refusé : au coffre-fort") and logHas("HoldItem(bobs) refusé : objet absent"), "une ligne en Studio par refus")
ada:SetAttribute("Carrying", "NPCBox")
refused("small", "portage en cours : refusé")
ada:SetAttribute("Carrying", nil)
check(snapshot(ada) ~= nil, "profil lisible")

section("rangé au portage, à la mort, au départ")
holdAs(ada, "small")
check(heldTool(ada) ~= nil, "en main")
CarryService.Give(ada, npcItem("Z1_Banane", "Common", 1))
advance(0.1)
check(#itemTools(ada) == 0 and ada:GetAttribute("HeldItem") == nil, "un objet porté : rangé")
CarryService.Consume(ada, "Test")
advance(0.1)
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.3)
holdAs(ada, "small")
check(heldTool(ada) ~= nil, "de nouveau en main")
local humanoid = ada.Character:FindFirstChildOfClass("Humanoid")
humanoid.Health = 0
humanoid.Died:Fire()
advance(0.1)
check(#itemTools(ada) == 0 and Held.GetHeld(ada) == nil, "mort : rangé")
spawnCharacter(ada, refsOfShop(shopOf(ada)).center)
advance(0.5)
check(#itemTools(ada) == 0, "réapparition : rien en main")
holdAs(ada, "small")
check(heldTool(ada) ~= nil, "nouveau personnage : en main")
spawnCharacter(ada, refsOfShop(shopOf(ada)).center)
advance(0.3)
check(#itemTools(ada) == 0 and Held.GetHeld(ada) == nil, "personnage retiré sans mourir : rangé")
holdAs(bob, "bobs")
check(heldTool(bob) ~= nil, "Bob tient son objet")
leave(bob)
check(Held.GetHeld(bob) == nil, "départ : rangé")

section("aucune duplication : exposé, vendu, posé une seule fois")
holdAs(ada, "small")
check(heldTool(ada) ~= nil, "en main")
fireAs(ada, "PlaceItemAuto", "small")
fireAs(ada, "PlaceItemAuto", "small")
flush()
advance(0.1)
local count = 0
for _, uid in dataOf(ada).Display do
	if uid == "small" then
		count += 1
	end
end
check(count == 1, "exposé sur un seul présentoir, même en double envoi")
check(#itemTools(ada) == 0 and ada:GetAttribute("HeldItem") == nil, "exposé : rangé tout de suite")
check(displayModelOf(ada, "small") ~= nil, "un seul modèle de l'objet : celui du présentoir")
refused("small", "exposé : plus tenable")
fireAs(ada, "UnplaceItem", "small")
flush()
advance(0.1)
holdAs(ada, "small")
check(heldTool(ada) ~= nil, "repris dans l'inventaire : de nouveau tenable")
dataOf(ada).Items.small = nil -- vendu au receleur (l'objet quitte le profil)
InventoryService.Refresh(ada)
advance(0.05)
check(#itemTools(ada) == 0, "vendu : rangé tout de suite")
advance(0.3)
check(#itemTools(ada) == 0, "et ne revient pas")

section("braquage : l'outil de casse remplace l'objet tenu près d'une vitrine")
local store = make("Model", { Name = "STORE_Test" }, Workspace)
local window = make("Part", { Name = "Window", Anchored = true, Size = Vector3.new(8, 6, 0.5), CFrame = CFrame.new(CORRIDOR + Vector3.new(0, 0, 4)) }, store)
window:SetAttribute("WindowId", "Test_W1")
window:SetAttribute("MaxHP", 10)
addTag(store, "NPCStore")
advance(0.5)
holdAs(ada, "phone")
check(heldTool(ada) ~= nil, "objet en main dans la boutique")
moveTo(ada, CORRIDOR + Vector3.new(0, 0, 1))
advance(0.6)
local hand = ada.Character:FindFirstChildWhichIsA("Tool")
check(hand and hand:GetAttribute("ToolId") ~= nil, "près de la vitrine : l'outil de casse en main")
check(#itemTools(ada) == 0 and ada:GetAttribute("HeldItem") == nil, "l'objet est rangé")
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.5)
store:Destroy()
advance(0.3)

section("antivol : en main et mode pose au sol")
local lockedSlot = slotOf("locked")
check(lockedSlot ~= nil, "case de l'objet sous antivol")
click(lockedSlot)
flush()
advance(0.1)
check(Inventory.GetState().Placing == "locked", "mode pose de l'objet sous antivol")
check(heldTool(ada) and heldTool(ada):GetAttribute("HeldItemUid") == "locked", "et l'objet en main, sans finir le mode pose")
check(slotPart(lockedSlot, "Equipped").Visible, "Equipped sur sa case")
click(lockedSlot)
flush()
advance(0.1)
check(Inventory.GetState().Placing == nil and #itemTools(ada) == 0, "re-choisi : fin du mode pose, rangé")
advance(0.5)
click(lockedSlot)
flush()
advance(0.1)
check(heldTool(ada) ~= nil, "repris en main")
local entry = placeItemAt(ada, "locked", 6, 0)
advance(0.3)
check(entry and entry.Spot ~= nil, "posé au sol")
check(#itemTools(ada) == 0 and Inventory.GetState().Placing == nil, "posé au sol : rangé, fin du mode pose")
refused("locked", "au sol : refusé")

summary("scénario hold")
