--!nocheck
-- Scénario « client » (L-089) : les vrais InventoryController et UnboxController, avec le vrai serveur.
-- Colis en main : aperçu fantôme (vert dans sa boutique, rouge ailleurs), clic → PlaceBox(boxUid, point).
-- Colis posé : invite « Open » (le propriétaire seulement) quand il est prêt → OpenBox(boxUid) ; révélation
-- dans la sortie (sans UI_Unbox). Objet en main : invite « Place Item » sur les présentoirs libres →
-- PlaceItem(itemUid, slot). Rien en main : aucune invite, aucun aperçu. EquipBest pour l'écran de Clément.

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
local humanoid = ada.Character:FindFirstChildOfClass("Humanoid")
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
check(standPrompt(1) ~= nil and standPrompt(1).ActionText == "Place Item" and standPrompt(21) ~= nil, "une invite « Place Item » sur chaque présentoir (bonus compris)")
check(not standPrompt(1).Enabled and ghost() == nil, "rien en main : invites cachées, pas d'aperçu")

section("colis en main : aperçu et pose")
local uid = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
local tool = toolsOf(ada)["Box:" .. uid]
check(tool ~= nil, "Tool du colis dans la barre")
humanoid:EquipTool(tool)
flush()
check(Inventory.GetState().Kind == "Box" and Inventory.GetState().Uid == uid, "InventoryController : colis en main")
local target = floorPoint(ada, 6, 20)
standNear(ada, target)
aimAt(target)
advance(0.1)
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
tool.Activated:Fire()
flush()
check(#serverCalls("PlaceBox") == calls + 1, "clic : PlaceBox envoyé")
local call = serverCalls("PlaceBox")[calls + 1]
check(call and call.args[1] == uid and (call.args[2] - target).Magnitude < 0.05, "PlaceBox(boxUid, point visé)")
advance(0.6)
check(dataOf(ada).Boxes[uid].Spot ~= nil, "le serveur a posé le colis")
check(Inventory.GetState().Kind == nil and ghost() == nil, "le Tool est parti : plus rien en main, plus d'aperçu")

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

section("objet en main : « Place Item » sur les présentoirs libres")
advance(revealDelay("Common") + 0.6)
local itemTool = toolsOf(ada)["Item:" .. itemUid]
check(itemTool ~= nil, "Tool de l'objet après la révélation")
moveTo(ada, refsOfShop(plot).center)
humanoid:EquipTool(itemTool)
flush()
check(Inventory.GetState().Kind == "Item" and Inventory.GetState().Uid == itemUid and ghost() == nil, "objet en main, pas d'aperçu")
check(standPrompt(1).Enabled and standPrompt(3).Enabled and standPrompt(4).Enabled, "présentoirs libres 1, 3, 4 : invite montrée")
check(not standPrompt(2).Enabled and not standPrompt(5).Enabled and not standPrompt(21).Enabled, "pris (2), verrouillés (5, 21) : cachée")
local places = #serverCalls("PlaceItem")
standPrompt(3).Triggered:Fire()
flush()
check(#serverCalls("PlaceItem") == places + 1 and serverCalls("PlaceItem")[places + 1].args[1] == itemUid and serverCalls("PlaceItem")[places + 1].args[2] == 3, "déclenchée : PlaceItem(itemUid, 3)")
advance(0.6)
check(dataOf(ada).Display["3"] == itemUid, "le serveur a exposé l'objet sur le présentoir 3")
check(Inventory.GetState().Kind == nil and not standPrompt(1).Enabled, "le Tool est parti : invites cachées")

section("Equip Best (bouton de Clément, à venir)")
local eb = #serverCalls("EquipBest")
Inventory.EquipBest()
flush()
check(#serverCalls("EquipBest") == eb + 1, "InventoryController.EquipBest() envoie EquipBest")

summary("scénario client")
