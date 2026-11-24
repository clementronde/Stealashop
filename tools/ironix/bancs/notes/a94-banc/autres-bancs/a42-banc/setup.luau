--!nocheck
-- Mise en place commune des scénarios du banc a42 : bouchons des services voisins (repris d'a27),
-- arbre du jeu (modules sous Shared, Server/Services et Client/Controllers, comme Script Sync), carte
-- (route, arches du greybox avec SignPart et ses SurfaceGui SignLeft et SignRight, magasins face à
-- face, zone safe), assets de Clément (Music, Sounds, UI, camion), joueurs, Net réel (les remotes du
-- serveur sont créés avant le client), démarrage par le vrai Loader.
--
-- Avant ce fichier, un scénario peut poser :
--   SERVER_LIST, CLIENT_LIST : noms des modules à charger (défaut : aucun service, aucun contrôleur) ;
--   MOTION (true) : Controllers/UI/Motion présent ;
--   ZONE_MUSIC (true), EVENT_MUSIC (true) : MUS_Hub à MUS_Z6, MUS_Chase et MUS_Truck livrés ;
--   SFX_ENABLED (true) : SFX_TruckHit, SFX_TruckExplosion, SFX_TruckAlarm livrés (Assets/Sounds/Truck) ;
--   CHASE_UI (false), NOTIFY_UI (false), ZONE_GATE_UI (false), STORE_INFO_UI (true) ;
--   TRUCK_DELIVERED (true), DRIVERS ("none", "idle", "static") ;
--   BOXES_DELIVERED (false) : BOX_Standard, BOX_Premium, BOX_Luxe de tailles différentes.

SERVER_LIST = SERVER_LIST or {}
CLIENT_LIST = CLIENT_LIST or {}

---------------------------------------------------------------- bouchons (repris d'a27)
SOURCES["stub/ToolService"] = [==[
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

SOURCES["stub/AnimationController"] = [==[
local AnimationController = { played = {} }
function AnimationController.PlayPlayer(name)
	table.insert(AnimationController.played, { name = name, t = os.clock() })
	return nil
end
function AnimationController.StopPlayer(name) end
return AnimationController
]==]

local STUBS = {
	ToolService = true,
	StatsService = true,
	NightCycleService = true,
	AnimationController = true,
}

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
for _, name in SERVER_LIST do
	moduleScript(SERVICES, name, if STUBS[name] then `stub/{name}` else `server/Services/{name}.luau`)
end
local sps = make("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, StarterPlayer)
local clientFolder = folder(sps, "Client")
CONTROLLERS = folder(clientFolder, "Controllers")
for _, name in CLIENT_LIST do
	moduleScript(CONTROLLERS, name, if STUBS[name] then `stub/{name}` else `client/Controllers/{name}.luau`)
end
if MOTION ~= false and SOURCES["client/Controllers/UI/Motion.luau"] then
	moduleScript(folder(CONTROLLERS, "UI"), "Motion", "client/Controllers/UI/Motion.luau")
end

function serverModule(name)
	return requireModule(SERVICES:FindFirstChild(name), "server")
end
function clientModule(name)
	return requireModule(CONTROLLERS:FindFirstChild(name), "client")
end
function sharedModule(path, side)
	local current = SHARED
	for segment in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(segment)
	end
	return requireModule(current, side or "server")
end

---------------------------------------------------------------- carte
MAP = folder(Workspace, "Map")
ROAD = make("Part", { Name = "Road", Anchored = true, Size = Vector3.new(800, 1, 60), CFrame = CFrame.new(330, -0.5, 0) }, MAP)
TERRAIN = make("Terrain", { Name = "Terrain", Anchored = true, CanCollide = false, CanQuery = false, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = CFrame.identity }, Workspace)
CAMERA = make("Camera", { Name = "Camera", CFrame = CFrame.new(0, 10, 0) }, Workspace)
Workspace.CurrentCamera = CAMERA

GATE_X = { 30, 100, 190, 300, 430, 580 }
END_X = 700
GATES = {}
-- Arches du greybox (tools/greybox.luau, ×1,5) : piliers, bandeau SignPart 3 × 9 × 69 en haut
-- (y 27 à 36) avec ses deux SurfaceGui SignLeft et SignRight.
function buildSignGui(sign, face, text)
	local gui = make("SurfaceGui", { Name = "Sign" .. face, Face = `Enum.NormalId.{face}`, Enabled = true }, sign)
	make("TextLabel", { Name = "Label", Text = text }, gui)
	return gui
end
for zone, x in GATE_X do
	local gate = make("Model", { Name = `ZoneGate_{zone}` }, MAP)
	local arch = make("Part", {
		Name = "Pillar_N",
		Anchored = true,
		Size = Vector3.new(3, 27, 4.5),
		CFrame = CFrame.new(x, 13.5, 32.25),
		PivotOffset = CFrame.new(0, -13.5, -32.25),
	}, gate)
	make("Part", { Name = "Pillar_S", Anchored = true, Size = Vector3.new(3, 27, 4.5), CFrame = CFrame.new(x, 13.5, -32.25) }, gate)
	local sign = make("Part", { Name = "SignPart", Anchored = true, Size = Vector3.new(3, 9, 69), CFrame = CFrame.new(x, 31.5, 0) }, gate)
	local text = `ZONE {zone}\nRecommended speed …`
	buildSignGui(sign, "Left", text)
	buildSignGui(sign, "Right", text)
	gate.PrimaryPart = arch
	gate:SetAttribute("Zone", zone)
	addTag(gate, "ZoneGate")
	GATES[zone] = gate
end
STORE_X = { 65, 140, 240, 360, 500, 660 }
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
-- Zone safe : une pièce 274 × 170 × 500 centrée en (−113, 75, 0) (relevé wave11) ; sol du hub.
SAFE_ZONE = make("Part", { Name = "SafeZoneVolume", Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.new(274, 170, 500), CFrame = CFrame.new(-113, 75, 0) }, MAP)
addTag(SAFE_ZONE, "SafeZone")
make("Part", { Name = "HubFloor", Anchored = true, Size = Vector3.new(274, 1, 500), CFrame = CFrame.new(-113, -0.5, 0) }, MAP)

function zoneMiddle(zone)
	local from = GATE_X[zone]
	local to = GATE_X[zone + 1] or END_X
	return (from + to) / 2
end

---------------------------------------------------------------- assets de Clément
ASSETS = folder(ReplicatedStorage, "Assets")
UI_FOLDER = folder(ASSETS, "UI")
EVENTS = folder(ASSETS, "Events")

MUSIC_NAMES = { "MUS_Ambient", "MUS_Hub", "MUS_Z1", "MUS_Z2", "MUS_Z3", "MUS_Z4", "MUS_Z5", "MUS_Z6" }
-- a87 : playlist de fond (Config/Music.AmbientTracks) ; AMB = le premier morceau, ou MUS_Ambient avant a87.
for _, name in { "MUS_Ambient_MorningMood", "MUS_Ambient_Spring", "MUS_Ambient_TurkishMarch", "MUS_Ambient_Gymnopedie", "MUS_Ambient_ClairDeLune", "MUS_Ambient_ClassicEaster" } do
	table.insert(MUSIC_NAMES, name)
end
AMB = if string.find(SOURCES["shared/Config/Music.luau"] or "", "AmbientTracks", 1, true) then "MUS_Ambient_MorningMood" else "MUS_Ambient"
MUSIC = {}
MUSIC_FOLDER = folder(ASSETS, "Music")
function addMusic(name, volume)
	MUSIC[name] = make("Sound", { Name = name, SoundId = `rbxassetid://{#name * 1000 + 7}`, Looped = true, Volume = volume or 0.4 }, MUSIC_FOLDER)
	return MUSIC[name]
end
if ZONE_MUSIC ~= false then
	for _, name in MUSIC_NAMES do
		addMusic(name)
	end
end
if EVENT_MUSIC ~= false then
	addMusic("MUS_Chase", 0.5)
	addMusic("MUS_Truck", 0.45)
end

SOUNDS_FOLDER = folder(ASSETS, "Sounds")
SFX = {}
function addSfx(name, props)
	local p = props or {}
	p.Name = name
	p.SoundId = p.SoundId or `rbxassetid://{#name * 77}`
	SFX[name] = make("Sound", p, folder(SOUNDS_FOLDER, "Truck"))
	return SFX[name]
end
if SFX_ENABLED ~= false then
	addSfx("SFX_TruckHit", { Volume = 0.6, PlaybackSpeed = 1 })
	addSfx("SFX_TruckExplosion", { Volume = 0.9, PlaybackSpeed = 1 })
	addSfx("SFX_TruckAlarm", { Volume = 0.7, PlaybackSpeed = 1, Looped = true })
end

-- BB_WindowHP et BB_TruckHP (comme les bancs a27 et a33).
local bar = make("BillboardGui", { Name = "BB_WindowHP", Size = UDim2.new(4, 0, 0.6, 0), MaxDistance = 60, StudsOffset = Vector3.new(0, 4.5, 0), SizeOffset = Vector2.new(0, 0) }, UI_FOLDER)
local barFrame = make("Frame", { Name = "Bar", Size = UDim2.fromScale(1, 0.6) }, bar)
make("Frame", { Name = "Fill", Size = UDim2.new(1, 0, 1, 0) }, barFrame)
make("TextLabel", { Name = "Label", Size = UDim2.fromScale(1, 0.4) }, bar)

-- BB_StoreInfo (relevé wave8) : 8 studs + 220 px de large.
function buildStoreInfo(parent)
	local gui = make("BillboardGui", { Name = "BB_StoreInfo", Size = UDim2.new(8, 220, 3, 90), StudsOffset = Vector3.new(0, 1, 0), SizeOffset = Vector2.new(0, 0), MaxDistance = 80 }, parent or UI_FOLDER)
	local lines = make("Frame", { Name = "Lines" }, gui)
	for _, name in { "StoreName", "HP", "Damage", "Speed" } do
		make("TextLabel", { Name = name, Text = name .. " ex.", TextColor3 = Color3.new(1, 1, 1) }, lines)
	end
	return gui
end
if STORE_INFO_UI ~= false then
	STORE_INFO = buildStoreInfo()
end
-- BB_ZoneGate (L-071, point 9 : ZoneName, Speed, Damage), dans un sous-dossier, avec un décor.
function buildZoneGate(parent)
	local gui = make("BillboardGui", {
		Name = "BB_ZoneGate",
		Size = UDim2.new(12, 0, 4, 0),
		StudsOffset = Vector3.new(0, 0.5, 0),
		SizeOffset = Vector2.new(0, 0),
		MaxDistance = 200,
		AlwaysOnTop = false,
	}, parent or folder(UI_FOLDER, "Gates"))
	local card = make("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1) }, gui)
	make("ImageLabel", { Name = "Studs" }, card)
	make("TextLabel", { Name = "ZoneName", Text = "TOKYO", TextColor3 = Color3.new(1, 1, 1) }, card)
	local stats = make("Frame", { Name = "Stats" }, card)
	make("TextLabel", { Name = "Speed", Text = "Speed 28", TextColor3 = Color3.new(1, 1, 1) }, stats)
	make("TextLabel", { Name = "Damage", Text = "Damage 80", TextColor3 = Color3.new(1, 1, 1) }, stats)
	return gui
end
if ZONE_GATE_UI then
	ZONE_GATE = buildZoneGate()
end

-- UI_Chase (L-071, point 6) : noms internes inconnus ; un cadre plein écran (liseré) et un
-- avertissement au centre. Livré allumé (Enabled = true) : c'est au code de l'éteindre au repos.
function buildChaseUi(enabled)
	local gui = make("ScreenGui", { Name = "UI_Chase", ResetOnSpawn = true, Enabled = enabled ~= false }, StarterGui)
	make("Frame", { Name = "RedEdge", Size = UDim2.fromScale(1, 1) }, gui)
	local warning = make("Frame", { Name = "Warning", Size = UDim2.fromScale(0.4, 0.1) }, gui)
	make("TextLabel", { Name = "WarningLabel", Text = "THE GUARD IS CHASING YOU!" }, warning)
	return gui
end
if CHASE_UI then
	STARTER_CHASE = buildChaseUi(CHASE_UI_ENABLED)
end
-- UI_Notify (contrat 2.2) : Template caché avec Icon et Label, dans une liste.
function buildNotifyUi(parent, withTemplate)
	local gui = make("ScreenGui", { Name = "UI_Notify", ResetOnSpawn = false, Enabled = false }, parent or StarterGui)
	local list = make("Frame", { Name = "List", Size = UDim2.fromScale(0.5, 0.4) }, gui)
	make("UIListLayout", { Name = "UIListLayout" }, list)
	if withTemplate ~= false then
		local template = make("Frame", { Name = "Template", Visible = false, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 50) }, list)
		make("ImageLabel", { Name = "Icon", Image = "rbxassetid://123" }, template)
		make("TextLabel", { Name = "Label", Text = "Example" }, template)
	end
	return gui
end
if NOTIFY_UI then
	STARTER_NOTIFY = buildNotifyUi()
end

-- Camion (comme le banc a27) : Root, 20 pièces, BoxSpawn_01 à _12, BlastPoint, HealthBarPoint,
-- OutlineHighlight ; conducteurs selon DRIVERS.
BOX_SPAWNS = {
	Vector3.new(-4, 9, -3), Vector3.new(-4, 11, 1), Vector3.new(-4, 9, 6), Vector3.new(-4, 11, 11),
	Vector3.new(4, 9, -3), Vector3.new(4, 11, 1), Vector3.new(4, 9, 6), Vector3.new(4, 11, 11),
	Vector3.new(-2, 9, 14), Vector3.new(2, 9, 14), Vector3.new(-1, 13, -1), Vector3.new(1, 13, 8),
}
-- Conducteur R15 simplifié en `position` : racine, torse et tête reliés par des Motor6D, tous
-- ancrés à la livraison ; dossier Animations avec Idle si `withIdle`.
function buildDriver(parent, name, position, withIdle)
	local rig = make("Model", { Name = name }, parent)
	local root = make("Part", { Name = "HumanoidRootPart", Anchored = true, Transparency = 1, Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position) }, rig)
	local torso = make("Part", { Name = "UpperTorso", Anchored = true, Size = Vector3.new(2, 1.6, 1), CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) }, rig)
	local head = make("Part", { Name = "Head", Anchored = true, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0)) }, rig)
	local lost = make("Part", { Name = "Hat", Anchored = true, Size = Vector3.new(1, 0.4, 1), CFrame = CFrame.new(position + Vector3.new(0, 2.4, 0)) }, rig)
	make("Motor6D", { Name = "Root", Part0 = root, Part1 = torso }, torso)
	make("Motor6D", { Name = "Neck", Part0 = torso, Part1 = head }, head)
	local humanoid = make("Humanoid", { Name = "Humanoid", RootPart = root }, rig)
	make("Animator", { Name = "Animator" }, humanoid)
	rig.PrimaryPart = root
	if withIdle then
		local anims = folder(rig, "Animations")
		make("Animation", { Name = "Idle", AnimationId = "rbxassetid://555001" }, anims)
	end
	return rig, lost
end
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
	if DRIVERS == "idle" or DRIVERS == "static" then
		local cab = folder(truck, "Drivers")
		buildDriver(cab, "Driver", Vector3.new(-1.6, 6, -13), DRIVERS == "idle")
		buildDriver(cab, "CoDriver", Vector3.new(1.6, 6, -13), DRIVERS == "idle")
	end
	truck.Parent = parent
	return truck
end
if TRUCK_DELIVERED ~= false then
	TRUCK_ASSET = buildTruck(EVENTS)
end

-- Colis de Clément de tailles différentes (le Luxe est le plus grand) : pour l'écart entre colis.
BOX_SIZES = { Standard = Vector3.new(2, 1.6, 2), Premium = Vector3.new(2.4, 2, 2.4), Luxe = Vector3.new(3.2, 2.4, 3.2) }
if BOXES_DELIVERED then
	local boxes = folder(ASSETS, "Boxes")
	for tier, size in BOX_SIZES do
		local model = make("Model", { Name = `BOX_{tier}` }, boxes)
		local body = make("Part", { Name = "Body", Anchored = true, Size = size, CFrame = CFrame.new(0, size.Y / 2, 0) }, model)
		make("Part", { Name = "Tint", Anchored = true, Size = Vector3.new(size.X * 0.3, size.Y, size.Z * 1.02), CFrame = CFrame.new(0, size.Y / 2, 0) }, model)
		make("Attachment", { Name = "CarryAttachment", CFrame = CFrame.new(0, -size.Y / 2, 0) }, body)
		model.PrimaryPart = body
	end
end

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
function spawnCharacter(player, position, look)
	local old = player.Character
	if old then
		old:Destroy()
	end
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
function moveTo(player, position, look)
	local frame = if look then CFrame.lookAt(position, position + look) else CFrame.new(position)
	player.Character:PivotTo(frame)
end
-- Caméra du joueur local : en `position`, regard vers `look` (horizontal).
function aimCamera(position, look)
	CAMERA.CFrame = CFrame.lookAt(position, position + look)
end
-- Copie d'un écran de StarterGui dans le PlayerGui, comme Roblox au démarrage et à chaque
-- réapparition (ResetOnSpawn).
function copyScreen(player, starter)
	local gui = player.PlayerGui
	local old = gui:FindFirstChild(starter.Name)
	if old then
		old:Destroy()
	end
	local copy = starter:Clone()
	copy.Parent = gui
	return copy
end

---------------------------------------------------------------- démarrage
-- Le Net réel côté serveur crée ReplicatedStorage/Remotes avant que le client ne l'attende.
NET = sharedModule("Net/Net", "server")
function startServer()
	local Loader = sharedModule("Loader", "server")
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
-- Envoi serveur → client par le vrai Net (ChaseState, Notify…).
function serverFire(remote, player, ...)
	NET.Server[remote]:Fire(player, ...)
	flush()
end
function fireAs(player, remoteName, ...)
	local remote = ReplicatedStorage.Remotes:FindFirstChild(remoteName)
	table.insert(SERVER_CALLS, { t = now(), name = remoteName, args = table.pack(...), from = player })
	remote.OnServerEvent:Fire(player, ...)
end

-- Copies de musique jouées par MusicController (dans SoundService).
function musicCopy(name)
	local found, count = nil, 0
	for _, child in SoundService:GetChildren() do
		if child.Name == name and child:IsA("Sound") then
			found = child
			count += 1
		end
	end
	return found, count
end
-- Sons joués (copies) dont le nom est `name`, n'importe où dans le Workspace.
function soundsNamed(name)
	local out = {}
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Sound") and d.Name == name then
			table.insert(out, d)
		end
	end
	return out
end
function trucks()
	local out = {}
	for _, inst in CollectionService:GetTagged("EventTruck") do
		table.insert(out, inst)
	end
	return out
end
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
