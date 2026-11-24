--!nocheck
-- E. Colis du camion au sol : ramassage par un autre joueur (GrabDropped, maintien du type),
-- refus (en vol, trop loin, maintien trop court, mains pleines, zone safe), pose sur l'établi
-- (vrai UnboxService), invite du client, disparition à 60 s, porteur mort.

local Tool = serverModule("ToolService")
local Carry = serverModule("CarryService")
local Data = serverModule("DataService")
local Plot = serverModule("PlotService")
local Anim = clientModule("AnimationController")
local TruckEvent = sharedModule("Config/TruckEvent")
local Balance = sharedModule("Config/Balance")
local Items = sharedModule("Config/Items")
startServer()
local A = newPlayer("Alice")
local B = newPlayer("Bob")
spawnCharacter(A, Vector3.new(140, 3, 10), Vector3.new(0, 0, -1))
giveTool(A, "Crowbar")
Tool.damage[A] = 1000
spawnCharacter(B, Vector3.new(140, 3, -14))
startClient(B)
local profile = { Boxes = {}, Upgrades = { UnboxBenches = 0 }, Lifetime = { Heists = 0 }, Items = {} }
Data._load(B, profile)
Plot._assign(B, PLOT)
flush()

Workspace:SetAttribute("TruckSpawnNow", 2)
flush()
local truck = currentTruck()
fireAs(A, "HitWindow", truck:GetAttribute("WindowId"))
flush()
local explodedAt = now()

local function info(model)
	local id = model:GetAttribute("DropId")
	local payload, position = Carry.GetDrop(id)
	return id, payload, position
end
-- Debout à `distance` studs (à l'horizontale) du point d'arrivée, le HumanoidRootPart à 3 studs du sol.
local function standNear(player, position, distance)
	moveTo(player, position + Vector3.new(distance, 3, 0))
end
local function byTier(tier)
	local out = {}
	for _, model in truckDrops() do
		if model:GetAttribute("Tier") == tier then
			table.insert(out, model)
		end
	end
	return out
end
-- Maintien complet : début, attente `hold` s, fin.
local function grab(player, id, hold)
	fireAs(player, "GrabDropped", id)
	advance(hold)
	fireAs(player, "GrabDropped", id)
	flush()
end

local luxe = byTier("Luxe")[1]
local luxeId, luxePayload, luxePosition = info(luxe)
local standards = byTier("Standard")

section("E. Refus")
standNear(B, luxePosition, 2)
clearLog()
fireAs(B, "GrabDropped", luxeId)
fireAs(B, "GrabDropped", luxeId)
flush()
check(not Carry.IsCarrying(B) and logHas("colis encore en vol"), "E1 colis encore en vol : refusé")
advance(1.6) -- tous atterris
standNear(B, luxePosition, 7.6) -- 8,2 studs du colis
advance(1.1)
clearLog()
grab(B, luxeId, 1.1)
check(not Carry.IsCarrying(B) and logHas("trop loin"), "E2 à 8,2 studs : refusé (8 au plus, Bat.DroppedGrabMaxDistance)")
standNear(B, luxePosition, 2)
advance(1.1)
clearLog()
grab(B, luxeId, 0.5)
check(not Carry.IsCarrying(B) and logHas("maintien trop court"), "E3 Luxe tenu 0,5 s : refusé (1 s)")
-- Maintien interrompu : il s'éloigne pendant le maintien, le serveur l'annule. (D'abord, le maintien
-- trop court d'E3 expire : 1 s après sa durée. Avant, un nouvel appui sans s'être éloigné conclurait
-- tout de suite, comme sur un rayon.)
advance(2.1)
fireAs(B, "GrabDropped", luxeId)
standNear(B, luxePosition, 20)
advance(0.3)
standNear(B, luxePosition, 2)
advance(0.8)
fireAs(B, "GrabDropped", luxeId)
flush()
check(not Carry.IsCarrying(B), "E4 parti à 20 studs pendant le maintien : maintien annulé, rien de pris")

section("E'. Un autre joueur ramasse le colis")
advance(2.1)
grab(B, luxeId, Balance.Heist.BoxTiers.Luxe.GrabTime)
check(Carry.IsCarrying(B), "E5 Luxe tenu 1 s, à 2 studs : Bob le porte")
check(Carry.GetPayload(B) == luxePayload, "E6 même colis : même payload (rareté et objet cachés inchangés)")
check(Carry.GetDrop(luxeId) == nil and isDestroyed(luxe), "E7 plus au sol")
check(B:GetAttribute("Carrying") == luxePayload.Rarity, "E8 porté au-dessus de la tête (attribut Carrying)")
check(luxePayload.Kind == "NPCBox" and luxePayload.StoreId == "Truck_1", "E9 un colis PNJ ordinaire, venu du camion n° 1")
local other = standards[1]
local otherId, _, otherPosition = info(other)
standNear(B, otherPosition, 2)
advance(1.1)
clearLog()
grab(B, otherId, 0.4)
check(Carry.GetPayload(B) == luxePayload and logHas("mains pleines"), "E10 mains pleines : refusé")
advance(0.3)
local anyEnabled = false
for _, model in truckDrops() do
	local prompt = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	anyEnabled = anyEnabled or (prompt ~= nil and prompt.Enabled)
end
check(not anyEnabled, "E11 tant qu'il porte, aucune invite active chez lui")

section("E''. Posé sur l'établi (UnboxService)")
local bench = PLOT:FindFirstChild("DisplaySlot_01", true) -- copie a46 : présentoir (L-086)
moveTo(B, bench.WorldPosition + Vector3.new(0, 1.5, 1))
fireAs(B, "PlaceBox", 1)
flush()
local placed = profile.Boxes["1"]
check(not Carry.IsCarrying(B), "E12 PlaceBox : le colis quitte sa tête")
check(placed ~= nil and placed.Tier == "Luxe" and placed.Zone == 2 and placed.ItemId == luxePayload.ItemId and placed.Rarity == luxePayload.Rarity, "E13 sur l'établi 1 : Luxe, zone 2, même objet")
check(profile.Lifetime.Heists == 1, "E14 compté comme un braquage réussi (Lifetime.Heists, UnboxService)")

section("E'''. Par l'invite du client (TruckController)")
standNear(B, otherPosition, 2)
advance(0.3)
local prompt = other.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
check(prompt ~= nil and prompt.Enabled == true, "E15 invite active sur un colis atterri, mains vides")
local played = #Anim.played
prompt.PromptButtonHoldBegan:Fire(B)
advance(Balance.Heist.BoxTiers.Standard.GrabTime)
prompt.Triggered:Fire(B)
flush()
check(Carry.IsCarrying(B), "E16 maintien de 0,3 s sur l'invite : Bob porte le Standard")
local calls = serverCalls("GrabDropped")
check(#calls >= 2 and calls[#calls].args[1] == otherId and calls[#calls - 1].args[1] == otherId, "E17 deux GrabDropped(dropId) : début et fin du maintien")
check(#Anim.played == played + 1 and Anim.played[#Anim.played].name == "Grab", "E18 animation Grab jouée")

section("E''''. Zone safe")
local third = standards[2]
local thirdId, _, thirdPosition = info(third)
local savedSafe = SAFE_ZONE.CFrame
SAFE_ZONE.CFrame = CFrame.new(thirdPosition + Vector3.new(0, 10, 0))
standNear(A, thirdPosition, 2)
advance(1.1)
clearLog()
grab(A, thirdId, 0.4)
check(not Carry.IsCarrying(A) and logHas("en zone safe"), "E19 depuis la zone safe : refusé (9.4)")
SAFE_ZONE.CFrame = savedSafe
advance(1.1)
grab(A, thirdId, 0.4)
check(Carry.IsCarrying(A), "E20 hors zone safe : pris")

section("E'''''. Un colis au sol qui n'est pas du camion")
local item = Items.ByZone[2].Common[1]
local foreign = { Kind = "NPCBox", Tier = "Standard", Zone = 2, Rarity = "Common", ItemId = item.Id, StoreId = "STORE_Z2_Left", SlotId = "STORE_Z2_Left/01" }
local foreignId = Carry.PlaceDrop(foreign, Vector3.new(170, 0, 15))
local C = newPlayer("Chloé")
spawnCharacter(C, Vector3.new(172, 3, 15))
clearLog()
grab(C, foreignId, 0.6)
check(foreignId ~= nil and not Carry.IsCarrying(C) and Carry.GetDrop(foreignId) == foreign, "E21 laissé au service qui l'a posé (batte, DEV-048) : rien de pris")
check(not logHas(foreignId), "E22 … et sans bruit")

section("E''''''. Porteur mort : le colis est perdu")
local dropsBefore = #truckDrops()
local bHumanoid = B.Character.Humanoid
bHumanoid.Health = 0
bHumanoid.Died:Fire()
flush()
check(not Carry.IsCarrying(B), "E23 Bob meurt : il ne porte plus rien")
check(#truckDrops() == dropsBefore, "E24 le colis ne revient nulle part (pas de rayon) et ne retombe pas")

section("E'''''''. Jamais ramassé : disparaît 60 s après l'atterrissage")
local remaining = truckDrops()
local remainingIds = {}
for _, model in remaining do
	table.insert(remainingIds, (info(model)))
end
-- Premier atterrissage à +1,1 s, dernier à +1,54 s.
advance(explodedAt + TruckEvent.FlightTime + TruckEvent.BoxLifetime - 0.1 - now())
local still = 0
for _, model in remaining do
	if not isDestroyed(model) then
		still += 1
	end
end
check(still == #remaining, `E25 encore là 59,9 s après l'atterrissage du premier ({still}/{#remaining})`)
clearLog()
advance(0.7)
local gone = 0
for i, model in remaining do
	if isDestroyed(model) and Carry.GetDrop(remainingIds[i]) == nil then
		gone += 1
	end
end
check(gone == #remaining and #remaining == 9, `E26 tous partis 60 s après leur atterrissage ({gone}/{#remaining})`)
check(logCount("jamais ramassé", "PRINT") == #remaining, "E27 TruckEventService les oublie (une ligne par colis en Studio)")

summary("scénario ramassage")
