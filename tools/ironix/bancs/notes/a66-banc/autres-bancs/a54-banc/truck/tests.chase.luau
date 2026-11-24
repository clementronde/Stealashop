--!nocheck
-- C. Fin du chrono du camion (L-083 point 3, a54), côté TruckEventService : quand et sur qui les
-- conducteurs sont lancés (GuardService.StartDriverChase, bouchon qui note les appels). La poursuite
-- elle-même est testée dans a54-banc/guard avec le vrai GuardService.

local TruckEvent = sharedModule("Config/TruckEvent")
local Carry = serverModule("CarryService")
local Night = serverModule("NightCycleService")
local Guard = serverModule("GuardService")
startServer()

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function spawnTruck(zone)
	Workspace:SetAttribute("TruckSpawnNow", zone)
	flush()
	local truck = trucks()[1]
	return truck, truck:GetPivot(), truck:GetAttribute("TruckNumber")
end
local function explode()
	Workspace:SetAttribute("TruckSpawnNow", "Explode")
	flush()
end
-- Le joueur ramasse un colis au sol du camion n° `number` (sans le maintien : CarryService direct).
local function grab(player, number)
	for _, model in truckDrops() do
		local payload = Carry.GetDrop(model:GetAttribute("DropId"))
		if payload and payload.StoreId == `Truck_{number}` then
			if Carry.PickUpDrop(player, model:GetAttribute("DropId")) then
				return payload
			end
		end
	end
	return nil
end
local function chases()
	return Guard.chases
end
local function notifies(player, text)
	return remotes("Notify", function(e)
		return e.to == player and e.args[1] == text
	end)
end

section("C. Valeurs (V0 proposées, absentes du doc)")
check(TruckEvent.DriverChaseMax == 2 and TruckEvent.DriverSpeedMultiplier == 1.2 and TruckEvent.DriverMinSpeed == 20, "C1 2 conducteurs au plus, × 1,2 la vitesse du porteur, 20 au moins")
-- a66 (2026-11-11, poursuite sans fin) : plus de DriverGiveUpAfter ; avant a66, l'ancien contrôle.
if TruckEvent.DriverGiveUpAfter == nil then
	check(TruckEvent.DriverSpawnSpacing == 4, "C2 a66 : plus d'abandon au bout d'un temps (DriverGiveUpAfter retiré), 4 studs entre les deux à l'apparition")
else
	check(TruckEvent.DriverGiveUpAfter == 30 and TruckEvent.DriverSpawnSpacing == 4, "C2 abandon après 30 s, 4 studs entre les deux à l'apparition")
end
check(type(TruckEvent.Messages.DriversChase) == "string" and type(TruckEvent.Messages.DriverCaught) == "string", "C3 messages en anglais (poursuite, capture)")

-- Joueurs : Bob portera un colis d'un AUTRE camion ; Alice, Dave et Eve ceux du camion suivi ;
-- Carol aussi, mais en zone safe.
local alice, bob, carol, dave, eve, fred = newPlayer("Alice"), newPlayer("Bob"), newPlayer("Carol"), newPlayer("Dave"), newPlayer("Eve"), newPlayer("Fred")
for _, p in { alice, bob, carol, dave, eve, fred } do
	spawnCharacter(p, Vector3.new(240, 3, 20))
end

section("C'. Camion cassé : rien avant la fin du chrono, puis les 2 porteurs les plus proches")
local _, _, first = spawnTruck(3)
explode()
advance(2)
check(grab(bob, first) ~= nil, "C4 Bob ramasse un colis du premier camion")
advance(5) -- le premier camion est retiré (RemoveDelay)
local truck, pivot, number = spawnTruck(3)
local spawnedAt = now()
check(number == first + 1, "C5 second camion en zone 3")
explode()
advance(2)
for _, p in { alice, carol, dave, eve } do
	check(grab(p, number) ~= nil, `C6 {p.Name} ramasse un colis du camion suivi`)
end
-- Distances au pivot du camion : Eve 30, Alice 60, Dave 150 ; Carol dans la zone safe ; Fred sans colis.
moveTo(eve, pivot.Position + Vector3.new(30, 3, 0))
moveTo(alice, pivot.Position + Vector3.new(-60, 3, 0))
moveTo(dave, pivot.Position + Vector3.new(150, 3, 0))
moveTo(carol, Vector3.new(-100, 3, 0))
moveTo(bob, pivot.Position + Vector3.new(5, 3, 0))
moveTo(fred, pivot.Position + Vector3.new(3, 3, 0))
advance(TruckEvent.Lifetime - (now() - spawnedAt) - 1)
check(#chases() == 0, `C7 1 s avant la fin du chrono : aucun conducteur ({#chases()})`)
advance(1.2)
local list = chases()
check(#list == 2, `C8 fin du chrono ({TruckEvent.Lifetime} s) : 2 conducteurs ({#list})`)
local a, b = list[1] and list[1].chase, list[2] and list[2].chase
check(a and b and a.Target == eve and b.Target == alice, "C9 sur les deux porteurs les plus proches : Eve (30) puis Alice (60) ; ni Dave (le 3e), ni Carol (zone safe), ni Bob (autre camion), ni Fred")
check(a and b and a.Template.Name == "CoDriver" and b.Template.Name == "Driver" and a.Template:IsDescendantOf(TRUCK_ASSET), "C10 modèles de Clément du camion, par ordre de nom (pas les copies en jeu)")
check(a and a.Name == `CoDriver_T{number}` and b.Name == `Driver_T{number}`, "C11 nom des copies : <conducteur>_T<n>")
local right = pivot.RightVector
local okSpots = a and b
	and near(flat(a.Spawn.Position - pivot.Position):Dot(right), -2, 1e-3)
	and near(flat(b.Spawn.Position - pivot.Position):Dot(right), 2, 1e-3)
	and near(flat(a.Spawn.Position - pivot.Position):Dot(pivot.LookVector), 0, 1e-3)
	and near(a.Spawn.Position.Y, 0, 1e-3)
check(okSpots, "C12 apparition au pivot du camion, à 4 studs l'un de l'autre (± 2 sur le côté), au sol")
check(a and a.Zone == 3 and a.SpeedMultiplier == 1.2 and a.MinSpeed == 20 and a.GiveUpAfter == TruckEvent.DriverGiveUpAfter and a.CaughtMessage == TruckEvent.Messages.DriverCaught, "C13 réglages passés à GuardService (zone, vitesse, abandon, message)")
check(a and a.Keeps(eve) == true and a.Keeps(bob) == false and a.Keeps(fred) == false, "C14 Keeps : vrai pour un porteur d'un colis de ce camion, faux pour un autre camion ou les mains vides")
check(#notifies(eve, TruckEvent.Messages.DriversChase) == 1 and #notifies(alice, TruckEvent.Messages.DriversChase) == 1, "C15 Notify aux deux porteurs poursuivis")
check(#notifies(dave, TruckEvent.Messages.DriversChase) == 0 and #notifies(bob, TruckEvent.Messages.DriversChase) == 0, "C16 personne d'autre n'est prévenu")
Carry.Fail(eve, "Caught")
flush()
check(a and a.Keeps(eve) == false, "C17 colis perdu (Fail) : Keeps devient faux, le conducteur abandonnera")
check(truck.Parent == nil, "C18 le camion explosé est déjà retiré")
advance(TruckEvent.Lifetime)
check(#chases() == 2, "C19 un seul lancement par camion")

section("C''. Camion pas cassé : il part à la fin du chrono, aucun conducteur sans porteur")
for _, p in { alice, carol, dave } do
	Carry.Fail(p, "Died")
end
flush()
local before = #chases()
local still = spawnTruck(4)
clearLog()
advance(TruckEvent.Lifetime + 0.2)
check(still.Parent == nil, "C20 pas cassé : parti à la fin du chrono")
check(#remotes("Notify", function(e) return e.args[1] == TruckEvent.Messages.Left end) >= 1, "C21 message « drove away »")
check(#chases() == before, "C22 aucun porteur : aucun conducteur")
check(logHas("aucun porteur", "PRINT", "server"), "C23 ligne de la sortie (Studio)")

section("C'''. Crochet Studio « Chase » : fin du chrono tout de suite, même après l'explosion")
local _, _, n3 = spawnTruck(2)
explode()
advance(2)
grab(dave, n3)
before = #chases()
Workspace:SetAttribute("TruckSpawnNow", "Chase")
flush()
check(#chases() == before + 1 and chases()[#chases()].chase.Target == dave, "C24 Chase : un conducteur sur Dave tout de suite")
clearLog()
Workspace:SetAttribute("TruckSpawnNow", "Chase")
flush()
check(#chases() == before + 1 and logHas("aucun chrono", "WARN", "server"), "C25 second Chase : plus de chrono, un avertissement, rien de lancé")
advance(TruckEvent.Lifetime)
check(#chases() == before + 1, "C26 et rien à la fin normale du chrono")
Carry.Fail(dave, "Died")
flush()

section("C''''. Alerte de la nuit : fin du chrono")
local _, _, n4 = spawnTruck(5)
explode()
advance(2)
grab(alice, n4)
before = #chases()
Night._set("Warning", 30)
flush()
check(#chases() == before + 1 and chases()[#chases()].chase.Target == alice, "C27 alerte de la nuit : le conducteur part tout de suite")
Night._set("Night", 120)
flush()
check(#chases() == before + 1, "C28 la nuit ensuite : rien de plus")
Night._set("Day", 1e6)
flush()
Carry.Fail(alice, "Died")
flush()

section("C'''''. Camion remplacé (crochet de zone) : pas de poursuite pour l'ancien")
local _, _, n5 = spawnTruck(1)
explode()
advance(2)
grab(eve, n5)
spawnTruck(6) -- l'ancien est remplacé sans message
before = #chases()
advance(TruckEvent.Lifetime - 2)
check(#chases() == before, "C29 aucun conducteur pour le camion remplacé")
advance(3)
check(#chases() == before, "C30 ni à la fin du chrono du nouveau (Eve porte un colis de l'ancien)")
Carry.Fail(eve, "Died")
flush()

section("C''''''. Pas de conducteur dans le modèle : avertissement, rien de lancé")
local saved = {}
for _, rig in TRUCK_ASSET.Drivers:GetChildren() do
	table.insert(saved, rig)
	rig.Parent = nil
end
Carry.Fail(bob, "Died")
flush()
local _, _, n6 = spawnTruck(3)
explode()
advance(2)
grab(bob, n6)
before = #chases()
clearLog()
Workspace:SetAttribute("TruckSpawnNow", "Chase")
flush()
check(#chases() == before and logHas("aucun conducteur", "WARN", "server"), "C31 aucun conducteur dans ENV_Event_Truck : avertissement, aucune poursuite")
for _, rig in saved do
	rig.Parent = TRUCK_ASSET.Drivers
end

summary("scénario chrono des conducteurs")
