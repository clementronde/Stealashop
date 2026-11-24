--!nocheck
-- Banc a165 (vague 51), scénario « steal » sur la mise en place du banc a29 (copie a146) : StealItem tolère le retard
-- du réseau comme les rayons (StoreHeistService.ReachPad, ici un bouchon qui rend 4 studs) au début du maintien et aux
-- revérifications ; fin du maintien stricte (PvP.StealMaxDistance).
local PAD = 4
local padCalls = {}
SOURCES["stub/StoreHeistService"] = [==[
local S = {}
function S.ReachPad(player, humanoid)
	table.insert(A165_PAD_CALLS, { player = player, humanoid = humanoid })
	return A165_PAD
end
return S
]==]
A165_PAD = PAD
A165_PAD_CALLS = padCalls
moduleScript(SERVICES, "StoreHeistService", "stub/StoreHeistService")

startServer()
local PvPC = requireModule(ReplicatedStorage.Shared.Config.PvP, "server")
local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3)
addItem(adaData, "ada-donut", "Z1_Donut", 4)
-- Le plus cher est à l'abri (coffre-fort) dans ce banc ; les essais se font sur 2 et 3.
local ada = join("Ada", adaData)
local bobData = newProfile()
local bob = join("Bob", bobData)
startClient(bob)
advance(1.2)
local adaShop = shopOf(ada)
DAMAGE[bob] = 1000
check(breakDoor(bob, adaShop), "porte cassée")
advance(0.2)
local index = adaShop:GetAttribute("PlotIndex")
local S = refsOfShop(adaShop)
local function at(slot, distance)
	local stand = S.slots[slot]
	local toward = (S.center - stand)
	toward = Vector3.new(toward.X, 0, toward.Z).Unit
	moveTo(bob, Vector3.new(stand.X, 3, stand.Z) + toward * distance)
end
local limit = PvPC.StealMaxDistance + PAD

section("fin du maintien toujours loin : stricte")
at(2, 10.8)
fireAs(bob, "StealItem", index, 2)
advance(1.1)
fireAs(bob, "StealItem", index, 2)
flush()
check(not CarryService.IsCarrying(bob) and logHas("trop loin", "WARN", "server"), "fin du maintien à 10,8 studs : refusée (trop loin)")
advance(1)

section("au-delà de la tolérance")
at(2, 13)
fireAs(bob, "StealItem", index, 2)
advance(0.5)
at(2, 2)
advance(0.6)
fireAs(bob, "StealItem", index, 2)
flush()
check(not CarryService.IsCarrying(bob), "départ à 13 studs (> 8 + 4) : pas de maintien, le 2e appel ne fait que le commencer")
advance(3) -- le maintien commencé sur place expire (StealGrabTime + HOLD_EXPIRY)

section("début du maintien en retard (10,8 studs), arrivée au présentoir à la fin")
at(2, 10.8)
fireAs(bob, "StealItem", index, 2)
advance(0.5)
check(#padCalls >= 1 and padCalls[1].player == bob and padCalls[1].humanoid ~= nil, "ReachPad demandé avec le joueur et son Humanoid")
at(2, 2)
advance(0.6)
fireAs(bob, "StealItem", index, 2)
flush()
check(CarryService.IsCarrying(bob), `pris : départ à 10,8 studs toléré (limite {limit})`)
CarryService.Fail(bob, "Bat")
flush()
advance(1)

summary("scénario steal")
