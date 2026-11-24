--!nocheck
-- T. Camion côté client (L-071, point 7, et colis qui se chevauchaient) : SFX_TruckHit à chaque coup,
-- SFX_TruckAlarm quand il est frappé (puis silence AlarmHold s après le dernier coup, ou à
-- l'explosion), SFX_TruckExplosion à l'explosion, conducteurs qui partent avec les pièces, sons
-- absents sans erreur ; une seule invite allumée quand plusieurs colis sont à portée.

local TruckEvent = sharedModule("Config/TruckEvent", "client")
local HitFeedback = sharedModule("Config/HitFeedback", "client")

local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(200, 3, 30))
aimCamera(Vector3.new(200, 8, 40), Vector3.new(0, 0, -1))
startClient(alice)
local Controller = clientModule("TruckController")

-- Camion posé comme TruckEventService : copie nommée EventTruck, tag, attributs de WindowService.
local function placeTruck(x)
	local model = TRUCK_ASSET:Clone()
	model.Name = "EventTruck"
	model:SetAttribute("Zone", 3)
	model:SetAttribute("WindowId", "Truck_1")
	model:SetAttribute("MaxHP", 1000)
	model:SetAttribute("HP", 1000)
	model:PivotTo(CFrame.new(x, 0, 0))
	model.Parent = Workspace
	addTag(model, "EventTruck")
	flush()
	return model
end
local function alarms()
	return soundsNamed("TruckAlarm")
end

section("T. Noms et valeurs")
check(HitFeedback.Truck.HitSound == "SFX_TruckHit", "T1 son du coup : SFX_TruckHit (nom de Clément, L-071)")
check(TruckEvent.ExplosionSound == "SFX_TruckExplosion" and TruckEvent.AlarmSound == "SFX_TruckAlarm" and TruckEvent.AlarmHold == 4, "T2 SFX_TruckExplosion, SFX_TruckAlarm, alarme 4 s après le dernier coup (V0)")

local truck = placeTruck(200)

section("T'. Son du coup")
Controller.LocalHit("Truck_1", Vector3.new(203, 6, 0))
local hits = soundsNamed("SFX_TruckHit")
check(#hits == 1 and hits[1].Playing and hits[1].Parent.Parent == TERRAIN, "T3 LocalHit : SFX_TruckHit joué au point de frappe (Attachment du Terrain)")

section("T''. Alarme quand le camion est frappé")
check(#alarms() == 0, "T4 au repos : pas d'alarme")
truck:SetAttribute("HP", 990)
flush()
local list = alarms()
check(#list == 1 and list[1].Playing and list[1].Parent == truck.Root, "T5 premier coup (baisse de HP) : l'alarme sonne sur Root (son 3D)")
check(list[1].SoundId == SFX.SFX_TruckAlarm.SoundId and list[1].Looped == true and list[1].Volume == 0.7, "T6 copie du Sound de Clément (boucle et volume gardés)")
check(SFX.SFX_TruckAlarm.Playing == false and SFX.SFX_TruckAlarm.Parent ~= nil, "T7 le Sound de Clément n'est pas joué ni déplacé")
local alarm = list[1]
advance(3)
truck:SetAttribute("HP", 980)
flush()
check(#alarms() == 1 and alarms()[1] == alarm, "T8 nouveau coup pendant l'alarme : la même, pas une deuxième")
advance(3.5)
check(alarm.Parent ~= nil and alarm.Playing, "T9 3,5 s après le dernier coup : elle sonne encore")
advance(0.6)
check(#alarms() == 0 and isDestroyed(alarm), "T10 4 s après le dernier coup : elle se tait (retirée)")
truck:SetAttribute("HP", 1000)
flush()
check(#alarms() == 0, "T11 PV qui remontent : pas d'alarme")
SFX.SFX_TruckAlarm.Looped = false
truck:SetAttribute("HP", 970)
flush()
local once = alarms()[1]
check(once ~= nil and once.Looped == false, "T12 alarme sans boucle (choix de Clément) : jouée une fois")
once.Ended:Fire()
flush()
check(#alarms() == 0, "T13 finie : retirée")
truck:SetAttribute("HP", 960)
flush()
check(#alarms() == 1, "T14 coup suivant : elle repart")
SFX.SFX_TruckAlarm.Looped = true

section("T'''. Explosion : son, alarme coupée, conducteurs éjectés")
local driver = truck.Drivers.Driver
local coDriver = truck.Drivers.CoDriver
local driverStart = driver:GetPivot().Position
local blastPoint = truck.Root.BlastPoint.WorldPosition
truck:SetAttribute("HP", 0)
truck:SetAttribute("ExplodedAt", Workspace:GetServerTimeNow())
flush()
check(#alarms() == 0, "T15 explosion : l'alarme se tait")
local booms = soundsNamed("SFX_TruckExplosion")
check(#booms == 1 and booms[1].Playing, "T16 SFX_TruckExplosion joué")
check(#booms == 1 and (booms[1].Parent.WorldPosition - blastPoint).Magnitude < 1e-6, "T17 … au point BlastPoint")
advance(0.5)
local moved = (driver:GetPivot().Position - driverStart).Magnitude
check(moved > 3, `T18 le conducteur part avec les pièces ({math.floor(moved * 10) / 10} studs en 0,5 s)`)
check((coDriver:GetPivot().Position - driverStart).Magnitude > 3, "T19 le passager aussi")
advance(TruckEvent.DebrisLifetime + TruckEvent.DebrisFadeTime)
local faded = true
for _, part in driver:GetDescendants() do
	if part:IsA("BasePart") and part.LocalTransparencyModifier < 1 then
		faded = false
	end
end
check(faded, "T20 puis il s'efface avec elles")
truck:SetAttribute("HP", 0)
flush()
check(#alarms() == 0, "T21 explosé : plus d'alarme")
truck:Destroy()
flush()

section("T''''. Explosion vue trop tard : ni son, conducteurs cachés")
local boomsBefore = #soundsNamed("SFX_TruckExplosion")
local lateTruck = TRUCK_ASSET:Clone()
lateTruck.Name = "EventTruck"
lateTruck:SetAttribute("WindowId", "Truck_2")
lateTruck:SetAttribute("MaxHP", 1000)
lateTruck:SetAttribute("HP", 0)
lateTruck:SetAttribute("ExplodedAt", Workspace:GetServerTimeNow() - 10)
lateTruck:PivotTo(CFrame.new(200, 0, 0))
lateTruck.Parent = Workspace
addTag(lateTruck, "EventTruck")
flush()
local hidden = true
for _, part in lateTruck.Drivers:GetDescendants() do
	if part:IsA("BasePart") and part.LocalTransparencyModifier < 1 then
		hidden = false
	end
end
check(hidden and #soundsNamed("SFX_TruckExplosion") == boomsBefore, "T22 arrivé par le streaming après l'explosion : conducteurs cachés, aucun son")
lateTruck:Destroy()
flush()

section("T'''''. Sons pas livrés : muets, sans erreur")
local explosionsBefore = #soundsNamed("SFX_TruckExplosion")
SOUNDS_FOLDER:Destroy()
local quiet = placeTruck(200)
Controller.LocalHit("Truck_1", Vector3.new(203, 6, 0))
quiet:SetAttribute("HP", 900)
flush()
quiet:SetAttribute("HP", 890)
quiet:SetAttribute("ExplodedAt", Workspace:GetServerTimeNow())
flush()
advance(0.2)
check(#alarms() == 0 and #soundsNamed("SFX_TruckExplosion") == explosionsBefore, "T23 ni alarme ni explosion entendues")
check(logCount("SFX_TruckHit absent de ReplicatedStorage.Assets.Sounds : coups sur le camion muets", "PRINT", "client") == 1, "T24 SFX_TruckHit : une ligne en Studio")
check(logCount("SFX_TruckAlarm absent de ReplicatedStorage.Assets.Sounds : camion frappé sans alarme (L-071)", "PRINT", "client") == 1, "T25 SFX_TruckAlarm : une ligne, une seule fois (deux coups)")
check(logCount("SFX_TruckExplosion absent de ReplicatedStorage.Assets.Sounds : explosion du camion sans son de Clément (L-071)", "PRINT", "client") == 1, "T26 SFX_TruckExplosion : une ligne")
check(logCount("", "WARN", "client") == 0, "T27 aucun avertissement (une erreur de tâche compterait aussi un échec)")
quiet:Destroy()
flush()

section("T''''''. Invites des colis : une seule allumée, celle du colis visé")
local drops = folder(Workspace, "CarryDrops")
local nextId = 0
local function dropBox(position, tier)
	nextId += 1
	local model = make("Model", { Name = `Drop_{nextId}` })
	local part = make("Part", { Name = "Body", Anchored = true, Size = Vector3.new(2, 1.6, 2), CFrame = CFrame.new(position) }, model)
	model.PrimaryPart = part
	model:SetAttribute("DropId", `Drop_{nextId}`)
	model:SetAttribute("Tier", tier or "Standard")
	model:SetAttribute("TruckBox", true)
	model.Parent = drops
	flush()
	return model
end
local function prompt(box)
	return box.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
end
local function enabledBoxes(boxes)
	local out = {}
	for _, box in boxes do
		local p = prompt(box)
		if p and p.Enabled then
			table.insert(out, box)
		end
	end
	return out
end
moveTo(alice, Vector3.new(0, 3, 300))
local A = dropBox(Vector3.new(0, 0.8, 0))
local B = dropBox(Vector3.new(3, 0.8, 0), "Premium")
local C = dropBox(Vector3.new(-3, 0.8, 0), "Luxe")
local all = { A, B, C }
advance(0.3)
check(#enabledBoxes(all) == 3, "T28 personne à portée : les trois invites allumées (Roblox ne montre rien de loin)")
-- Alice à 1 stud de A, caméra vers +X : B (à 2 studs devant) et A (1 stud, de côté).
moveTo(alice, Vector3.new(0, 3, 1))
aimCamera(Vector3.new(-6, 8, 1), Vector3.new(1, 0, 0))
advance(0.3)
local on = enabledBoxes(all)
check(#on == 1 and on[1] == A, `T29 trois colis à portée : une seule invite, celle du plus proche ({#on} allumée(s))`)
moveTo(alice, Vector3.new(1.5, 3, 0.2))
advance(0.3)
on = enabledBoxes(all)
check(#on == 1 and on[1] == B, "T30 à mi-chemin entre A et B, caméra vers B : B (dans l'axe de la caméra)")
aimCamera(Vector3.new(8, 8, 0.2), Vector3.new(-1, 0, 0))
advance(0.3)
on = enabledBoxes(all)
check(#on == 1 and on[1] == A, "T31 même place, caméra vers A : A")
-- Maintien en cours : l'invite tenue garde la main même si un autre colis devient meilleur.
prompt(A).PromptButtonHoldBegan:Fire()
aimCamera(Vector3.new(-6, 8, 0.2), Vector3.new(1, 0, 0))
advance(0.3)
on = enabledBoxes(all)
check(#on == 1 and on[1] == A, "T32 maintien sur A : A reste la seule invite pendant le maintien")
local calls = serverCalls("GrabDropped")
check(#calls >= 1 and calls[#calls].args[1] == A:GetAttribute("DropId"), "T33 GrabDropped part pour A, le colis visé")
prompt(A).PromptButtonHoldEnded:Fire()
advance(0.3)
on = enabledBoxes(all)
check(#on == 1 and on[1] == B, "T34 maintien lâché : retour au meilleur (B, dans l'axe)")
alice:SetAttribute("Carrying", "NPCBox")
flush()
check(#enabledBoxes(all) == 0, "T35 mains pleines : aucune invite")
alice:SetAttribute("Carrying", nil)
flush()
check(#enabledBoxes(all) == 1, "T36 mains vides : une invite")
B:Destroy()
advance(0.3)
on = enabledBoxes({ A, C })
check(#on == 1 and on[1] == A, "T37 B ramassé : A (le plus proche des restants)")
alice.Character:Destroy()
alice.Character = nil
advance(0.3)
check(#enabledBoxes({ A, C }) == 2, "T38 pas de personnage : toutes les invites allumées")
check(logCount("", "WARN", "client") == 0, "T39 aucun avertissement")

summary("scénario camion (client)")
