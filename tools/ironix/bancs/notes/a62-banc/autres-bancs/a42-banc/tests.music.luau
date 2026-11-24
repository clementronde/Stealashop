--!nocheck
-- M. Musique du camion (L-071, point 7) et musiques d'événement absentes : MUS_Truck près du camion ou
-- de ses colis au sol (TruckRadius, marge de sortie), livraison en cours de partie, MUS_Chase et
-- MUS_Truck pas livrées = la musique de la zone continue, sans erreur.

local Music = sharedModule("Config/Music", "client")

local alice = newPlayer("Alice")
local X = zoneMiddle(3)
spawnCharacter(alice, Vector3.new(X, 3, 0))
startClient(alice)
local Controller = clientModule("MusicController")
local function state()
	return Controller.GetState()
end
local function level(name)
	return state().Levels[name] or 0
end
local function go(x, z, wait)
	moveTo(alice, Vector3.new(x, 3, z or 0))
	advance(wait or 0.3)
end

local guards = folder(Workspace, "ActiveGuards")
local guard = make("Model", { Name = "Guard_Z3" }, guards)
local guardRoot = make("Part", { Name = "HumanoidRootPart", Anchored = true, CFrame = CFrame.new(X + 20, 3, 0) }, guard)
guard.PrimaryPart = guardRoot
guard:SetAttribute("TargetUserId", alice.UserId)

local function spawnTruck(x)
	local truck = make("Model", { Name = "EventTruck" })
	local root = make("Part", { Name = "Root", Anchored = true, Size = Vector3.new(2, 1, 2), CFrame = CFrame.new(x, 0.5, 0), PivotOffset = CFrame.new(0, -0.5, 0) }, truck)
	truck.PrimaryPart = root
	truck.Parent = Workspace
	addTag(truck, "EventTruck")
	return truck
end
local drops = folder(Workspace, "CarryDrops")
local function dropBox(x, z, truckBox)
	local model = make("Model", { Name = "Drop" })
	local part = make("Part", { Name = "Body", Anchored = true, Size = Vector3.new(2, 1.6, 2), CFrame = CFrame.new(x, 0.8, z) }, model)
	model.PrimaryPart = part
	model:SetAttribute("DropId", "Drop_" .. tostring(math.random(1, 1e6)))
	if truckBox then
		model:SetAttribute("TruckBox", true)
	else
		model:SetAttribute("BatDrop", true)
	end
	model.Parent = drops
	return model
end

section("M. Valeurs")
check(Music.ChaseTrack == "MUS_Chase" and Music.TruckTrack == "MUS_Truck", "M1 noms de Clément : MUS_Chase, MUS_Truck")
check(Music.TruckRadius == 100 and Music.TruckExitMargin == 10 and Music.RestartEventTracks == true, "M2 V0 : 100 studs, marge 10, reprise du début")

section("M'. Musiques d'événement pas livrées : la zone continue")
advance(2.6)
check(state().Track == "MUS_Z3" and level("MUS_Z3") == 1, `M3 zone 3 : MUS_Z3 ({state().Track})`)
serverFire("ChaseState", alice, true, guard)
advance(1)
check(state().Track == "MUS_Z3" and state().Event == nil and level("MUS_Z3") == 1, `M4 poursuite sans MUS_Chase : MUS_Z3 continue ({state().Track})`)
check(logCount("MUS_Chase absent de ReplicatedStorage.Assets.Music (ou pas un Sound) : la musique de la zone continue pendant les poursuites (L-071)", "PRINT", "client") == 1, "M5 une ligne en Studio, une fois")
advance(1)
check(logCount("MUS_Chase absent", nil, "client") == 1, "M6 pas répétée")
serverFire("ChaseState", alice, false)
local truck = spawnTruck(X + 40)
advance(1)
check(state().Track == "MUS_Z3" and level("MUS_Z3") == 1, "M7 près du camion sans MUS_Truck : MUS_Z3 continue")
check(logCount("MUS_Truck absent de ReplicatedStorage.Assets.Music (ou pas un Sound) : la musique de la zone continue près du camion (L-071)", "PRINT", "client") == 1, "M8 une ligne en Studio, une fois")
check(logCount("", "WARN", "client") == 0, "M9 aucun avertissement côté client")

section("M''. MUS_Truck livrée en cours de partie")
local truckSound = addMusic("MUS_Truck", 0.45)
advance(0.3)
check(state().Track == "MUS_Truck" and state().Event == "Truck", `M10 prise dans les 0,25 s ({state().Track})`)
advance(2.2)
local truckCopy = musicCopy("MUS_Truck")
check(level("MUS_Truck") == 1 and level("MUS_Z3") == 0 and near(truckCopy.Volume, 0.45, 1e-9), "M11 fondu fini : MUS_Truck pleine, au volume de Clément")
alice:SetAttribute("MusicVolume", 0.5)
advance(0.1)
check(near(truckCopy.Volume, 0.225, 1e-9), "M12 le réglage MusicVolume vaut aussi pour elle")
alice:SetAttribute("MusicVolume", nil)
advance(0.1)

section("M'''. Cercle du camion et marge de sortie")
go(X + 40 + 99, 0)
check(state().Track == "MUS_Truck", "M13 à 99 studs : MUS_Truck")
go(X + 40 + 105, 0)
check(state().Track == "MUS_Truck", "M14 à 105 studs, déjà dedans : toujours MUS_Truck (marge de 10)")
go(X + 40 + 112, 0)
check(state().Track ~= "MUS_Truck" and state().Event == nil, `M15 à 112 studs : la musique de la zone ({state().Track})`)
go(X + 40 + 105, 0)
check(state().Track ~= "MUS_Truck", "M16 à 105 studs en revenant : pas encore (il faut 100)")
go(X + 40 + 60, 0)
check(state().Track == "MUS_Truck", "M17 à 60 studs : MUS_Truck")
advance(2.2)

section("M''''. Après l'explosion : les colis au sol gardent la musique")
truck:SetAttribute("ExplodedAt", Workspace:GetServerTimeNow())
local box1 = dropBox(X + 40 + 12, 8, true)
local box2 = dropBox(X + 40 - 10, -9, true)
truck:Destroy()
go(X + 40 + 70, 0)
check(state().Track == "MUS_Truck", "M18 camion retiré, à 58 studs de ses colis : MUS_Truck")
box1:Destroy()
box2:Destroy()
local batBox = dropBox(X + 40 + 50, 0, false)
go(X + 40 + 70, 0)
check(state().Track ~= "MUS_Truck", `M19 colis ramassés (un colis de batte ne compte pas) : la zone ({state().Track})`)
batBox:Destroy()
advance(2.3)
check(level("MUS_Truck") == 0 and truckCopy.Playing == false, "M20 MUS_Truck éteinte, en pause")

section("M'''''. Nouveau camion : MUS_Truck repart du début")
truckCopy.TimePosition = 37
local second = spawnTruck(X + 70 + 30)
advance(0.3)
check(state().Track == "MUS_Truck" and truckCopy.TimePosition == 0 and truckCopy.Playing, `M21 repart de 0 s ({truckCopy.TimePosition})`)
second:Destroy()

section("M''''''. Camion près du hub : MUS_Truck aussi dans la zone safe (choix V0)")
local hubTruck = spawnTruck(60)
go(-20, 0, 0.3)
check(state().Zone == 0 and state().Track == "MUS_Truck", `M22 dans la zone safe à 80 studs du camion de la zone 1 : MUS_Truck ({state().Track})`)
go(-150, 0, 0.3)
check(state().Track == "MUS_Hub", `M23 loin dans le hub : MUS_Hub ({state().Track})`)
hubTruck:Destroy()

section("M'''''''. MUS_Chase livrée ensuite")
addMusic("MUS_Chase", 0.5)
go(X, 0, 0.3)
serverFire("ChaseState", alice, true, guard)
advance(0.3)
check(state().Track == "MUS_Chase" and state().Event == "Chase", `M24 prise à la poursuite suivante ({state().Track})`)
serverFire("ChaseState", alice, false)
advance(0.3)
check(state().Track == "MUS_Z3", "M25 fin : MUS_Z3")
check(not logHas("[MusicController]", "WARN", "client"), "M26 aucun avertissement du contrôleur")

summary("scénario musique")
