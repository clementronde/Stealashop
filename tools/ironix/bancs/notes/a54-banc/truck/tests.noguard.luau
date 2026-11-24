--!nocheck
-- N. Sans GuardService dans l'arbre (anciens bancs) : la fin du chrono avertit une fois, sans erreur,
-- et le camion vit comme avant.

local TruckEvent = sharedModule("Config/TruckEvent")
local Carry = serverModule("CarryService")
startServer()

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(240, 3, 20))

section("N. Fin du chrono sans GuardService")
Workspace:SetAttribute("TruckSpawnNow", 3)
flush()
local number = trucks()[1]:GetAttribute("TruckNumber")
Workspace:SetAttribute("TruckSpawnNow", "Explode")
flush()
advance(2)
local grabbed = false
for _, model in truckDrops() do
	if not grabbed and Carry.PickUpDrop(alice, model:GetAttribute("DropId")) then
		grabbed = true
	end
end
check(grabbed and Carry.GetPayload(alice).StoreId == `Truck_{number}`, "N1 Alice porte un colis du camion")
clearLog()
advance(TruckEvent.Lifetime)
check(logCount("GuardService indisponible", "WARN", "server") == 1, "N2 un avertissement : pas de poursuite des conducteurs")
check(not logHas("tick :", "WARN", "server"), "N3 aucune erreur dans la boucle du service")
check(Carry.IsCarrying(alice), "N4 Alice garde son colis")
Workspace:SetAttribute("TruckSpawnNow", 2)
flush()
check(#trucks() == 1, "N5 un nouveau camion apparaît toujours")

summary("scénario sans GuardService")
