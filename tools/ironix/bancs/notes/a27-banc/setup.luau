--!nocheck
-- Mise en place commune des scénarios du banc a27 : bouchons des services voisins, arbre du jeu
-- (modules sous Shared, Server/Services et Client/Controllers, comme Script Sync), carte (route,
-- arches, magasins face à face, zone safe, parcelle), assets de Clément (ENV_Event_Truck,
-- FX_BoxTrail, BB_WindowHP), joueurs, démarrage par le vrai Loader.
--
-- Avant ce fichier, un scénario peut poser : SERVER_SIDE ("server" par défaut, "prod" = hors
-- Studio), NIGHT_ENABLED (true), TRUCK_DELIVERED (true), TRAIL_DELIVERED (true).

---------------------------------------------------------------- bouchons
SOURCES["stub/ToolService"] = [==[
-- Dégâts par coup : ToolService.damage[player] (10 par défaut) ; outil en main : un Tool avec ToolId.
local ToolService = { damage = {} }
function ToolService.GetHitDamage(player)
	return ToolService.damage[player] or 10
end
function ToolService.IsHoldingTool(player)
	local character = player.Character
	if character == nil then
		return false
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ToolId") ~= nil then
			return true
		end
	end
	return false
end
return ToolService
]==]

SOURCES["stub/StatsService"] = [==[
local StatsService = { modifiers = {} }
function StatsService.SetSpeedModifier(player, key, multiplier)
	StatsService.modifiers[player] = StatsService.modifiers[player] or {}
	StatsService.modifiers[player][key] = multiplier
end
return StatsService
]==]

-- NightCycleService : phase pilotée par les tests (_set), heure serveur de fin de phase, écouteurs.
SOURCES["stub/NightCycleService"] = [==[
local NightCycleService = { Priority = 120 }
local phase, endsAt, listeners = "Day", math.huge, {}
function NightCycleService.GetPhase() return phase end
function NightCycleService.GetPhaseEndsAt() return endsAt end
function NightCycleService.IsNight() return phase == "Night" end
function NightCycleService.OnPhaseChanged(fn)
	table.insert(listeners, fn)
	return function() end
end
function NightCycleService._set(newPhase, duration)
	local previous = phase
	phase = newPhase
	endsAt = workspace:GetServerTimeNow() + (duration or 1e6)
	if newPhase ~= previous then
		for _, fn in listeners do task.spawn(fn, newPhase, previous) end
	end
end
return NightCycleService
]==]

SOURCES["stub/DataService"] = [==[
local DataService = {}
local profiles, loaded = {}, {}
function DataService.Get(player) return profiles[player] end
function DataService.OnProfileLoaded(fn)
	table.insert(loaded, fn)
	for p in profiles do task.spawn(fn, p) end
	return function() end
end
function DataService.OnProfileReleasing(fn) return function() end end
function DataService._load(player, data)
	profiles[player] = data
	for _, fn in loaded do task.spawn(fn, player) end
end
return DataService
]==]

SOURCES["stub/PlotService"] = [==[
local PlotService = {}
local plotOf, assigned = {}, {}
function PlotService.GetPlot(player) return plotOf[player] end
function PlotService.OnPlotAssigned(fn)
	table.insert(assigned, fn)
	for p, plot in plotOf do task.spawn(fn, p, plot) end
	return function() end
end
function PlotService.OnPlotReleased(fn) return function() end end
function PlotService._assign(player, plot)
	plotOf[player] = plot
	plot:SetAttribute("OwnerUserId", player.UserId)
	for _, fn in assigned do task.spawn(fn, player, plot) end
end
return PlotService
]==]

SOURCES["stub/DisplayService"] = [==[
local DisplayService = { calls = {} }
function DisplayService.PlaceAuto(player, uid)
	table.insert(DisplayService.calls, { player = player, uid = uid })
	return 1
end
return DisplayService
]==]

-- AnimationController : PlayPlayer rend une piste ; son marqueur Impact passe MARKER_DELAY s après
-- (nil : animation pas livrée, PlayPlayer rend nil).
SOURCES["stub/AnimationController"] = [==[
local AnimationController = { played = {} }
function AnimationController.PlayPlayer(name)
	table.insert(AnimationController.played, { name = name, t = os.clock() })
	local delay = MARKER_DELAY
	if delay == nil then
		return nil
	end
	local markers = {}
	local track = { Name = name }
	function track.GetMarkerReachedSignal(_, marker)
		markers[marker] = markers[marker] or newSignal()
		return markers[marker]
	end
	task.delay(delay, function()
		local signal = markers.Impact
		if signal then signal:Fire("") end
	end)
	return track
end
return AnimationController
]==]

SOURCES["stub/ShatterController"] = [==[
local ShatterController = { localHits = {} }
function ShatterController.LocalHit(windowId, point, track)
	table.insert(ShatterController.localHits, { id = windowId, point = point })
end
return ShatterController
]==]

---------------------------------------------------------------- arbre du jeu
local sharedRoot = folder(ReplicatedStorage, "Shared")
local dirs = { [""] = sharedRoot }
local function dirFor(path)
	if dirs[path] then
		return dirs[path]
	end
	local parentPath, name = string.match(path, "^(.-)/?([^/]+)$")
	local f = folder(dirFor(parentPath), name)
	dirs[path] = f
	return f
end
for key in SOURCES do
	local rest = string.match(key, "^shared/(.+)%.luau$")
	if rest then
		local dir, name = string.match(rest, "^(.-)/?([^/]+)$")
		moduleScript(dirFor(dir), name, key)
	end
end
SHARED = sharedRoot

local server = folder(ServerScriptService, "Server")
SERVICES = folder(server, "Services")
for _, name in { "WindowService", "CarryService", "TruckEventService", "UnboxService", "ContractChecker" } do
	moduleScript(SERVICES, name, `server/Services/{name}.luau`)
end
for _, name in { "ToolService", "StatsService", "NightCycleService", "DataService", "PlotService", "DisplayService" } do
	moduleScript(SERVICES, name, `stub/{name}`)
end
local sps = make("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, StarterPlayer)
local clientFolder = folder(sps, "Client")
CONTROLLERS = folder(clientFolder, "Controllers")
for _, name in { "HitController", "TruckController" } do
	moduleScript(CONTROLLERS, name, `client/Controllers/{name}.luau`)
end
for _, name in { "AnimationController", "ShatterController" } do
	moduleScript(CONTROLLERS, name, `stub/{name}`)
end

SERVER_SIDE = SERVER_SIDE or "server"
function serverModule(name)
	return requireModule(SERVICES:FindFirstChild(name), SERVER_SIDE)
end
function clientModule(name)
	return requireModule(CONTROLLERS:FindFirstChild(name), "client")
end
function sharedModule(path)
	local current = SHARED
	for segment in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(segment)
	end
	return requireModule(current, SERVER_SIDE)
end

---------------------------------------------------------------- carte (relevé wave9-studio, section 2)
MAP = folder(Workspace, "Map")
ROAD = make("Part", { Name = "Road", Anchored = true, Size = Vector3.new(800, 1, 60), CFrame = CFrame.new(330, -0.5, 0) }, MAP)
GATE_X = { 30, 100, 190, 300, 430, 580 }
STORE_X = { 65, 140, 240, 360, 500, 660 }
for zone, x in GATE_X do
	local gate = make("Model", { Name = `ZoneGate_{zone}` }, MAP)
	local arch = make("Part", { Name = "Arch", Anchored = true, CanCollide = false, Size = Vector3.new(2, 24, 60), CFrame = CFrame.new(x, 12, 0) }, gate)
	gate.PrimaryPart = arch
	gate:SetAttribute("Zone", zone)
	addTag(gate, "ZoneGate")
end
STORES = {}
for zone, x in STORE_X do
	for _, side in { -1, 1 } do
		local store = make("Model", { Name = `STORE_Z{zone}_{if side < 0 then "Left" else "Right"}` }, MAP)
		local base = make("Part", {
			Name = "Base",
			Anchored = true,
			Size = Vector3.new(30, 1, 28),
			CFrame = CFrame.new(x, 0.5, side * 45),
			PivotOffset = CFrame.new(0, -0.5, 0),
		}, store)
		store.PrimaryPart = base
		make("Part", { Name = "Window", Anchored = true, Size = Vector3.new(20, 10, 0.5), CFrame = CFrame.new(x, 5, side * 30.75) }, store)
		store:SetAttribute("Zone", zone)
		addTag(store, "NPCStore")
		table.insert(STORES, store)
	end
end
SAFE_ZONE = make("Part", { Name = "SafeZone", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(130, 40, 120), CFrame = CFrame.new(-40, 10, 0) }, MAP)
addTag(SAFE_ZONE, "SafeZone")
-- Sol de la zone safe et parcelle (établis) pour UnboxService.
make("Part", { Name = "HubFloor", Anchored = true, Size = Vector3.new(130, 1, 120), CFrame = CFrame.new(-40, -0.5, 0) }, MAP)
PLOT = make("Model", { Name = "PLOT_1" }, MAP)
local plotBase = make("Part", { Name = "Base", Anchored = true, Size = Vector3.new(20, 1, 20), CFrame = CFrame.new(-40, 0.5, 30) }, PLOT)
PLOT.PrimaryPart = plotBase
for i = 1, 4 do
	make("Attachment", { Name = string.format("UnboxBench_%02d", i), CFrame = CFrame.new(-6 + i * 3, 1, 0) }, plotBase)
end
PLOT:SetAttribute("PlotIndex", 1)

---------------------------------------------------------------- assets de Clément (relevé wave9-studio, section 1)
ASSETS = folder(ReplicatedStorage, "Assets")
local events = folder(ASSETS, "Events")
local ui = folder(ASSETS, "UI")

-- Camion : 12,6 × 15,8 × 34 studs, pivot en bas au centre, long en Z ; 20 pièces (Models) qui font
-- le camion intact ; Attachments dans Root, positions dans le repère du pivot.
BOX_SPAWNS = {
	Vector3.new(-4, 9, -3), Vector3.new(-4, 11, 1), Vector3.new(-4, 9, 6), Vector3.new(-4, 11, 11),
	Vector3.new(4, 9, -3), Vector3.new(4, 11, 1), Vector3.new(4, 9, 6), Vector3.new(4, 11, 11),
	Vector3.new(-2, 9, 14), Vector3.new(2, 9, 14), Vector3.new(-1, 13, -1), Vector3.new(1, 13, 8),
}
function buildTruck(parent)
	local truck = make("Model", { Name = "ENV_Event_Truck" })
	local root = make("Part", {
		Name = "Root",
		Anchored = true,
		CanCollide = false,
		Transparency = 1,
		Size = Vector3.new(2, 1, 2),
		CFrame = CFrame.new(0, 0.5, 0),
		PivotOffset = CFrame.new(0, -0.5, 0),
	}, truck)
	truck.PrimaryPart = root
	local pieces = make("Model", { Name = "Pieces" }, truck)
	local n = 0
	for _, x in { -3.15, 3.15 } do
		for _, y in { 3.95, 11.85 } do
			for _, z in { -13.6, -6.8, 0, 6.8, 13.6 } do
				n += 1
				local piece = make("Model", { Name = string.format("Piece_%02d", n), WorldPivot = CFrame.new(x, y, z) }, pieces)
				make("Part", { Name = "Body", Anchored = true, CanCollide = y < 5, Size = Vector3.new(6.3, 7.9, 6.8), CFrame = CFrame.new(x, y, z) }, piece)
			end
		end
	end
	local function point(name, p)
		make("Attachment", { Name = name, CFrame = CFrame.new(p.X, p.Y - 0.5, p.Z) }, root)
	end
	point("BlastPoint", Vector3.new(0, 10, 5))
	point("HealthBarPoint", Vector3.new(0, 19, 0))
	for i, p in BOX_SPAWNS do
		point(string.format("BoxSpawn_%02d", i), p)
	end
	make("Highlight", { Name = "OutlineHighlight", Enabled = true }, truck)
	truck.Parent = parent
	return truck
end
function buildTrail(parent)
	local fx = make("Model", { Name = "FX_BoxTrail" })
	local carrier = make("Part", { Name = "Carrier", Anchored = true, CanCollide = false, Size = Vector3.new(2, 2, 2) }, fx)
	fx.PrimaryPart = carrier
	local top = make("Attachment", { Name = "TrailTop", CFrame = CFrame.new(0, 0.7, 0) }, carrier)
	local bottom = make("Attachment", { Name = "TrailBottom", CFrame = CFrame.new(0, -0.7, 0) }, carrier)
	make("Trail", { Name = "Trail", Attachment0 = top, Attachment1 = bottom, Lifetime = 0.5, Enabled = true }, carrier)
	fx.Parent = parent
	return fx
end
if TRUCK_DELIVERED ~= false then
	TRUCK_ASSET = buildTruck(events)
end
if TRAIL_DELIVERED ~= false then
	TRAIL_ASSET = buildTrail(events)
end
local bar = make("BillboardGui", { Name = "BB_WindowHP", Size = UDim2.new(4, 0, 0.6, 0), MaxDistance = 60 }, ui)
local barFrame = make("Frame", { Name = "Bar", Size = UDim2.fromScale(1, 0.6) }, bar)
make("Frame", { Name = "Fill", Size = UDim2.new(1, 0, 1, 0) }, barFrame)
make("TextLabel", { Name = "Label", Size = UDim2.fromScale(1, 0.4) }, bar)

---------------------------------------------------------------- joueurs
local userIds = 0
function newPlayer(name)
	userIds += 1
	local player = make("Player", { Name = name, UserId = userIds }, Players)
	make("Backpack", { Name = "Backpack" }, player)
	make("PlayerGui", { Name = "PlayerGui" }, player)
	Players.PlayerAdded:Fire(player)
	return player
end
-- Personnage R15 simplifié, debout en `position` (centre du HumanoidRootPart), regard vers `look`.
function spawnCharacter(player, position, look)
	local character = make("Model", { Name = player.Name })
	local frame = if look then CFrame.lookAt(position, position + look) else CFrame.new(position)
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = frame, CanCollide = false }, character)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = frame * CFrame.new(0, 1.6, 0), CanCollide = false }, character)
	make("Humanoid", { Name = "Humanoid" }, character)
	character.PrimaryPart = root
	character.Parent = Workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end
-- Déplace le personnage (position du HumanoidRootPart), regard vers `look`.
function moveTo(player, position, look)
	local character = player.Character
	local frame = if look then CFrame.lookAt(position, position + look) else CFrame.new(position)
	character:PivotTo(frame)
end
-- Outil de casse en main (attribut ToolId, comme ToolService).
function giveTool(player, toolId)
	local tool = make("Tool", { Name = toolId or "Fists" })
	tool:SetAttribute("ToolId", toolId or "Fists")
	tool.Parent = player.Character
	return tool
end

-- Appel client → serveur au nom de `player` (le vrai chemin : Net vérifie forme et débit).
function fireAs(player, remoteName, ...)
	local remote = ReplicatedStorage.Remotes:FindFirstChild(remoteName)
	table.insert(SERVER_CALLS, { t = now(), name = remoteName, args = table.pack(...), from = player })
	remote.OnServerEvent:Fire(player, ...)
end

---------------------------------------------------------------- démarrage
function startServer()
	local Loader = sharedModule("Loader")
	Loader.start(SERVICES, "Serveur")
	flush()
end
function startClient(player)
	CLIENT_PLAYER = player
	Players.LocalPlayer = player
	local Loader = requireModule(SHARED:FindFirstChild("Loader"), "client")
	Loader.start(CONTROLLERS, "Client")
	flush()
end

-- Le camion en jeu (copie taggée EventTruck), ou nil ; et leur nombre.
function trucks()
	local out = {}
	for _, inst in CollectionService:GetTagged("EventTruck") do
		table.insert(out, inst)
	end
	return out
end
function currentTruck()
	return trucks()[1]
end
-- Colis du camion au sol (modèles de Workspace/CarryDrops avec TruckBox).
function truckDrops()
	local out = {}
	local drops = Workspace:FindFirstChild("CarryDrops")
	if drops then
		for _, child in drops:GetChildren() do
			if child:GetAttribute("TruckBox") == true then
				table.insert(out, child)
			end
		end
	end
	return out
end
function notifies(pattern)
	return remotes("Notify", function(e)
		return pattern == nil or string.find(e.args[1], pattern, 1, true) ~= nil
	end)
end
