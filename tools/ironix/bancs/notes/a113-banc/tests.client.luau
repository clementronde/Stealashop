--!nocheck
-- a113 C. DropController (client) : touche G et bouton tactile de repli (ContextActionService) seulement
-- pendant le portage ; UI_HUD.DropButton de Clément s'il existe (montré pendant le portage, caché sinon,
-- sans bouton tactile de repli) ; un appui envoie DropCarried et l'objet tombe.

moduleScript(SERVICES, "DropService", "server/Services/DropService.luau")
moduleScript(CONTROLLERS, "DropController", "client/Controllers/DropController.luau")
local Carry = serverModule("CarryService")
startServer()
local A = newPlayer("Alice") -- joueuse locale
spawnCharacter(A, Vector3.new(120, 3, 0), Vector3.new(1, 0, 0))
flush()
startClient(A)

local uid = 0
local function npcItem()
	uid += 1
	return { Kind = "NPCItem", ItemId = "Z1_Donut", Rarity = "Common", Zone = 1, StoreId = "STORE_TEST", SlotId = `STORE_TEST/{uid}`, Luck = 1 }
end
local function sends()
	return #serverCalls("DropCarried")
end

section("C1 Sans portage : rien de lié")
check(CAS_BOUND.DropCarried == nil, "C1a action DropCarried pas liée")

section("C2 Portage, sans bouton de Clément : touche G et bouton tactile « Drop »")
check(Carry.StartCarry(A, npcItem()), "C2a Alice porte un objet")
flush()
local bound = CAS_BOUND.DropCarried
check(bound ~= nil and bound.touch == true, "C2b action liée avec bouton tactile")
check(bound and table.find(bound.keys, Enum.KeyCode.G) ~= nil, "C2c touche G")
check(bound and bound.title == "Drop", "C2d titre « Drop »")
local size = bound and bound.button and bound.button.Size
check(size ~= nil and size.Y.Offset >= 44 and size.X.Offset >= 44, "C2e bouton tactile d'au moins 44 px")
local before = sends()
bound.fn("DropCarried", Enum.UserInputState.End, {})
flush()
check(sends() == before and Carry.IsCarrying(A), "C2f relâchement seul : rien n'est envoyé")
bound.fn("DropCarried", Enum.UserInputState.Begin, {})
flush()
check(sends() == before + 1 and not Carry.IsCarrying(A), "C2g appui : DropCarried envoyé, l'objet tombe")
check(#batDrops() == 1, "C2h l'objet est au sol")
check(CAS_BOUND.DropCarried == nil, "C2i plus de portage : action déliée (bouton tactile retiré)")

section("C3 Bouton UI_HUD.DropButton de Clément")
local hud = make("ScreenGui", { Name = "UI_HUD" })
local rail = make("Frame", { Name = "RightRail" }, hud)
local button = make("TextButton", { Name = "DropButton", Visible = false }, rail)
hud.Parent = A:FindFirstChild("PlayerGui")
flush()
check(button.Visible == false and CAS_BOUND.DropCarried == nil, "C3a sans portage : bouton caché, rien de lié")
advance(0.6)
check(Carry.StartCarry(A, npcItem()), "C3b Alice porte un objet")
flush()
check(button.Visible == true, "C3c bouton de Clément montré pendant le portage")
bound = CAS_BOUND.DropCarried
check(bound ~= nil and bound.touch == false and table.find(bound.keys, Enum.KeyCode.G) ~= nil, "C3d touche G sans bouton tactile de repli")
before = sends()
button.Activated:Fire()
flush()
check(sends() == before + 1 and not Carry.IsCarrying(A), "C3e clic sur DropButton : l'objet tombe")
check(button.Visible == false and CAS_BOUND.DropCarried == nil, "C3f bouton caché, touche déliée")

section("C4 Le bouton de Clément disparaît : retour au bouton tactile de repli")
hud:Destroy()
flush()
advance(0.6)
check(Carry.StartCarry(A, npcItem()), "C4a Alice porte un objet")
flush()
bound = CAS_BOUND.DropCarried
check(bound ~= nil and bound.touch == true, "C4b bouton tactile de repli")

summary("scénario client")
