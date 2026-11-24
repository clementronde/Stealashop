--!nocheck
-- Scénario « client » (L-089 ; copie d'a61, vague 21, L-079) : les vrais InventoryController et
-- UnboxController, avec le vrai serveur, sans écran UI_Inventory (l'écran est au banc a61). Barre Roblox
-- coupée au démarrage. Mode pose d'un colis sans Tool (InventoryController.StartPlacing, comme le bouton
-- PlaceButton) : aperçu fantôme (vert dans sa boutique, rouge ailleurs), clic sur le monde →
-- PlaceBox(boxUid, point) ; fin du mode quand le colis est posé. Colis posé : invite « Open » (le
-- propriétaire seulement) quand il est prêt → OpenBox(boxUid) ; révélation dans la sortie (sans UI_Unbox).
-- Plus d'invite « Place Item » sur les présentoirs : l'objet se pose depuis l'écran (PlaceItemAuto).
-- EquipBest pour l'écran de Clément.

advance(1000)
startServer()
local data = newProfile()
addItem(data, "shown", "Z1_Donut", 2, 1, 1)
local ada = join("Ada", data)
advance(1.5)
startClient(ada)
advance(0.5)
local Inventory = clientModule("InventoryController")
local plot = shopOf(ada)
local function ghost()
	local g = Workspace:FindFirstChild("BoxGhost")
	return if g and g.Parent == Workspace then g else nil
end
local function standPrompt(i)
	local att = plot:FindFirstChild(string.format("DisplaySlot_%02d", i), true)
	return if att then att:FindFirstChild("PlaceItemPrompt") else nil
end

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(#COREGUI_CALLS >= 1 and COREGUI_CALLS[1].kind == "Enum.CoreGuiType.Backpack" and COREGUI_CALLS[1].enabled == false, "barre d'outils de Roblox coupée (SetCoreGuiEnabled(Backpack, false))")
check(standPrompt(1) == nil and standPrompt(21) == nil, "plus d'invite « Place Item » sur les présentoirs")
check(Inventory.GetState().Placing == nil and ghost() == nil, "pas de mode pose, pas d'aperçu")

section("mode pose : aperçu et pose, sans Tool")
local uid = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
check(uid ~= nil and countKeys(toolsOf(ada)) == 0, "colis dans l'inventaire, aucun Tool")
local target = floorPoint(ada, 6, 20)
standNear(ada, target)
aimAt(target)
Inventory.StartPlacing(uid)
advance(0.1)
check(Inventory.GetState().Placing == uid, "InventoryController : mode pose de ce colis")
local g = ghost()
check(g ~= nil and (g.Position - (target + Vector3.new(0, g.Size.Y / 2, 0))).Magnitude < 0.05, "aperçu posé sur le point visé")
check(g ~= nil and g.Color == Color3.fromHex("#35C93B") and Inventory.GetState().AimValid, "aperçu vert dans sa boutique, à portée")
check(g ~= nil and g.CanQuery == false and g.CanCollide == false, "aperçu sans collision, ignoré des rayons")
aimAt(floorPoint(ada, 6, 60))
advance(0.1)
check(ghost() ~= nil and ghost().Color == Color3.fromHex("#E8413C") and not Inventory.GetState().AimValid, "hors de sa boutique : aperçu rouge")
aimAt(target)
advance(0.1)
local calls = #serverCalls("PlaceBox")
UserInputServiceStub.InputBegan:Fire({ UserInputType = "Enum.UserInputType.MouseButton1", KeyCode = "Enum.KeyCode.Unknown", Position = Vector3.new(400, 300, 0) }, true)
flush()
check(#serverCalls("PlaceBox") == calls, "clic sur l'UI (processed) : rien n'est envoyé")
worldClick()
flush()
check(#serverCalls("PlaceBox") == calls + 1, "clic sur le monde : PlaceBox envoyé")
local call = serverCalls("PlaceBox")[calls + 1]
check(call and call.args[1] == uid and (call.args[2] - target).Magnitude < 0.05, "PlaceBox(boxUid, point visé)")
advance(0.6)
check(dataOf(ada).Boxes[uid].Spot ~= nil, "le serveur a posé le colis")
check(Inventory.GetState().Placing == nil and ghost() == nil, "colis posé : fin du mode pose, plus d'aperçu")

section("mode pose : touche Q pour sortir, colis inconnu refusé")
local uidQ = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
Inventory.StartPlacing(uidQ)
advance(0.1)
check(Inventory.GetState().Placing == uidQ, "mode pose du 2e colis")
pressKey("Q")
advance(0.1)
check(Inventory.GetState().Placing == nil and ghost() == nil, "Q : sorti du mode pose")
Inventory.StartPlacing("pas-un-colis")
check(Inventory.GetState().Placing == nil, "colis absent de l'état : pas de mode pose")

section("colis posé : « Open » quand il est prêt")
local model = floorBoxOf(ada, uid)
local prompt = model and model:FindFirstChild("UnboxPrompt", true)
check(prompt ~= nil and prompt.ActionText == "Open" and not prompt.Enabled, "invite « Open » sur le colis, cachée pendant l'attente")
advance(Rarities.ById.Common.OpenDelay + 0.3)
check(prompt ~= nil and prompt.Enabled, "colis prêt (BoxReady) : invite montrée")
check(logHas("le colis " .. uid .. " est prêt"), "BoxReady(boxUid) écrit dans la sortie (Studio)")
local opens = #serverCalls("OpenBox")
standNear(ada, model:GetPivot().Position)
advance(0.1)
prompt.Triggered:Fire()
flush()
check(#serverCalls("OpenBox") == opens + 1 and serverCalls("OpenBox")[opens + 1].args[1] == uid, "déclenchée : OpenBox(boxUid)")
local itemUid = remotes("UnboxReveal")[1] and remotes("UnboxReveal")[1].args[2]
check(itemUid ~= nil and dataOf(ada).Items[itemUid] ~= nil, "le serveur a ouvert le colis")
check(logHas(`[Unbox] colis {uid} : COMMON`), "révélation dans la sortie (sans UI_Unbox)")

section("colis d'un autre : pas d'invite")
local bob = join("Bob", nil)
advance(1.5)
local ub = bringBox(bob, "Common", "Z1_Banane", "Standard", 1)
placeAt(bob, ub, 6, 20)
local bobBox = floorBoxOf(bob, ub)
check(bobBox ~= nil and bobBox:FindFirstChild("UnboxPrompt", true) == nil, "aucune invite sur le colis de Bob chez Ada")

section("objet de l'inventaire : PlaceItemAuto le pose sur le présentoir libre le plus proche")
advance(revealDelay("Common") + 0.6)
check(invOf(ada)["Item:" .. itemUid] ~= nil, "l'objet dans l'état après la révélation")
moveTo(ada, refsOfShop(plot).slots[4] + Vector3.new(0, 1, 2))
advance(0.3)
fireAs(ada, "PlaceItemAuto", itemUid)
flush()
advance(0.6)
check(dataOf(ada).Display["4"] == itemUid, "exposé sur le présentoir libre le plus proche (4)")
check(invItem(ada, itemUid) ~= nil and invItem(ada, itemUid).Slot == 4, "état : exposé, présentoir 4")

section("Equip Best (bouton de Clément)")
local eb = #serverCalls("EquipBest")
Inventory.EquipBest()
flush()
check(#serverCalls("EquipBest") == eb + 1, "InventoryController.EquipBest() envoie EquipBest")

summary("scénario client")
