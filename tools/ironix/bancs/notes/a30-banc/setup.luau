--!nocheck
-- Mise en place commune des scénarios du banc a30 (batte, vague 10) : bouchons des services voisins,
-- arbre du jeu (modules sous Shared, Server/Services et Client/Controllers, comme Script Sync),
-- carte (route, zone safe, deux magasins de la zone 1 face à face, rayons, rideau, GuardSpawn),
-- camion de Clément (pour l'événement), joueurs, déplacements simulés, inventaire des colis,
-- démarrage par le vrai Loader.
--
-- Vrais : BatService, CarryService, GuardService, StoreHeistService, WindowService, ToolService,
-- StatsService, TruckEventService (serveur) ; BatController, HitController, TruckController
-- (client) ; Loader, Net, Config, Contract, Anim, Format, Types. Bouchons : DataService,
-- NightCycleService (bouclier piloté par SHIELDED), AnimationController (pistes pilotées par
-- ANIM_DELIVERED), ShatterController.

---------------------------------------------------------------- bouchons
SOURCES["stub/DataService"] = [==[
local DataService = { Priority = 1 }
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

-- NightCycleService : phase pilotée (_set), bouclier débutant piloté par SHIELDED[player].
SOURCES["stub/NightCycleService"] = [==[
local NightCycleService = { Priority = 120, shieldCalls = 0 }
local phase, endsAt, listeners = "Day", math.huge, {}
function NightCycleService.GetPhase() return phase end
function NightCycleService.GetPhaseEndsAt() return endsAt end
function NightCycleService.IsNight() return phase == "Night" end
function NightCycleService.IsInCorridor(position) return position.X > 27 end
function NightCycleService.IsShielded(player)
	NightCycleService.shieldCalls += 1
	return SHIELDED[player] == true
end
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
SHIELDED = {}

-- AnimationController : PlayPlayer rend une piste si ANIM_DELIVERED[nom] (sinon nil, animation pas
-- livrée). Marqueur Impact de SwingBat SWING_IMPACT_AT s après Play ; une piste sans boucle s'arrête
-- (Stopped) ANIM_LENGTH[nom] s après (0,6 par défaut).
SOURCES["stub/AnimationController"] = [==[
local AnimationController = { played = {}, stopped = {} }
local LOOP = { Stunned = true, CarryIdle = true, CarryRun = true }
function AnimationController.PlayPlayer(name)
	table.insert(AnimationController.played, { name = name, t = os.clock() })
	if not ANIM_DELIVERED[name] then
		return nil
	end
	local markers = {}
	local track = { Name = name, Stopped = newSignal() }
	function track.GetMarkerReachedSignal(_, marker)
		markers[marker] = markers[marker] or newSignal()
		return markers[marker]
	end
	if name == "SwingBat" and SWING_IMPACT_AT then
		task.delay(SWING_IMPACT_AT, function()
			local signal = markers.Impact
			if signal then signal:Fire("") end
		end)
	end
	if not LOOP[name] then
		task.delay(ANIM_LENGTH[name] or 0.6, function()
			track.Stopped:Fire()
		end)
	end
	return track
end
function AnimationController.StopPlayer(name)
	table.insert(AnimationController.stopped, { name = name, t = os.clock() })
end
function AnimationController.SetCarrying() end
function AnimationController.OnMarker() return function() end end
return AnimationController
]==]
ANIM_DELIVERED = {}
ANIM_LENGTH = {}
SWING_IMPACT_AT = 0.2

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
for _, name in {
	"BatService",
	"CarryService",
	"GuardService",
	"StoreHeistService",
	"WindowService",
	"ToolService",
	"StatsService",
	"TruckEventService",
} do
	moduleScript(SERVICES, name, `server/Services/{name}.luau`)
end
for _, name in { "DataService", "NightCycleService" } do
	moduleScript(SERVICES, name, `stub/{name}`)
end
local sps = make("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, StarterPlayer)
local clientFolder = folder(sps, "Client")
CONTROLLERS = folder(clientFolder, "Controllers")
for _, name in { "BatController", "HitController", "TruckController" } do
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

---------------------------------------------------------------- carte
-- Route du couloir (dessus à y = 0), zone safe (le hub, x < 25), deux magasins de la zone 1 face à
-- face (x = 65, vitrines en z = ±30,75, comme le relevé), la seconde zone en x = 140.
MAP = folder(Workspace, "Map")
ROAD = make("Part", { Name = "Road", Anchored = true, Size = Vector3.new(800, 1, 60), CFrame = CFrame.new(330, -0.5, 0) }, MAP)
make("Part", { Name = "HubFloor", Anchored = true, Size = Vector3.new(130, 1, 120), CFrame = CFrame.new(-40, -0.5, 0) }, MAP)
SAFE_ZONE = make("Part", {
	Name = "SafeZone",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	Transparency = 1,
	Size = Vector3.new(130, 40, 120),
	CFrame = CFrame.new(-40, 10, 0),
}, MAP)
addTag(SAFE_ZONE, "SafeZone")

-- Magasin PNJ : sol, vitrine, volume Bounds, rideau ouvert (au-dessus de la vitrine), rayon du fond
-- avec ShelfSlot_01 à _10, GuardSpawn au fond. `side` = +1 (z > 0) ou −1.
STORES = {}
function buildStore(name, zone, x, side)
	local store = make("Model", { Name = name }, MAP)
	local base = make("Part", {
		Name = "Floor",
		Anchored = true,
		Size = Vector3.new(30, 1, 28),
		CFrame = CFrame.new(x, -0.5, side * 45),
	}, store)
	store.PrimaryPart = base
	make("Part", { Name = "Window", Anchored = true, Size = Vector3.new(20, 10, 0.5), CFrame = CFrame.new(x, 5, side * 30.75) }, store)
	make("Part", {
		Name = "Bounds",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(28, 12, 26),
		CFrame = CFrame.new(x, 6, side * 45),
	}, store)
	make("Part", { Name = "Shutter", Anchored = true, Size = Vector3.new(20, 10, 0.4), CFrame = CFrame.new(x, 15, side * 31.3) }, store)
	local shelf = make("Part", { Name = "Shelf", Anchored = true, Size = Vector3.new(22, 4, 1), CFrame = CFrame.new(x, 2, side * 56) }, store)
	for i = 1, 10 do
		make("Attachment", { Name = string.format("ShelfSlot_%02d", i), CFrame = CFrame.new(-9 + 2 * (i - 1), 2, 0) }, shelf)
	end
	-- Porte de la réserve, au fond à droite (22 studs du rayon 1).
	make("Attachment", { Name = "GuardSpawn", CFrame = CFrame.new(13, 0.5, side * 6) }, base)
	store:SetAttribute("Zone", zone)
	addTag(store, "NPCStore")
	table.insert(STORES, store)
	return store
end
STORE_A = buildStore("STORE_Z1_Superette", 1, 65, 1)
STORE_B = buildStore("STORE_Z1_Kiosque", 1, 65, -1)

---------------------------------------------------------------- camion de Clément (relevé wave9)
ASSETS = folder(ReplicatedStorage, "Assets")
local events = folder(ASSETS, "Events")
local BOX_SPAWNS = {
	Vector3.new(-4, 9, -3), Vector3.new(-4, 11, 1), Vector3.new(-4, 9, 6), Vector3.new(-4, 11, 11),
	Vector3.new(4, 9, -3), Vector3.new(4, 11, 1), Vector3.new(4, 9, 6), Vector3.new(4, 11, 11),
	Vector3.new(-2, 9, 14), Vector3.new(2, 9, 14), Vector3.new(-1, 13, -1), Vector3.new(1, 13, 8),
}
do
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
	local piece = make("Model", { Name = "Piece_01", WorldPivot = CFrame.new(0, 4, 0) }, pieces)
	make("Part", { Name = "Body", Anchored = true, Size = Vector3.new(12, 8, 30), CFrame = CFrame.new(0, 4, 0) }, piece)
	make("Attachment", { Name = "BlastPoint", CFrame = CFrame.new(0, 9.5, 5) }, root)
	make("Attachment", { Name = "HealthBarPoint", CFrame = CFrame.new(0, 18.5, 0) }, root)
	for i, p in BOX_SPAWNS do
		make("Attachment", { Name = string.format("BoxSpawn_%02d", i), CFrame = CFrame.new(p.X, p.Y - 0.5, p.Z) }, root)
	end
	make("Highlight", { Name = "OutlineHighlight", Enabled = true }, truck)
	truck.Parent = events
end

-- Batte de Clément (relevé wave10, section 3) : Handle, Body et Band soudées, HitPoint.
TOOLS_FOLDER = folder(ASSETS, "Tools")
if BAT_DELIVERED ~= false then
	BAT_ASSET = make("Model", { Name = "TOOL_Batte" }, TOOLS_FOLDER)
	local handle = make("MeshPart", { Name = "Handle", Size = Vector3.new(0.4, 0.4, 1.6) }, BAT_ASSET)
	for _, n in { "Body", "Band" } do
		local p = make("MeshPart", { Name = n, Size = Vector3.new(0.6, 0.6, 2) }, BAT_ASSET)
		make("WeldConstraint", { Name = "WeldToHandle", Part0 = handle, Part1 = p }, p)
	end
	make("Attachment", { Name = "HitPoint", CFrame = CFrame.new(0, 0, -2) }, handle)
end

-- Rig de remplacement du vigile (Players:CreateHumanoidModelFromDescriptionAsync).
RIG_FACTORY = function()
	local m = make("Model", { Name = "Player" })
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(500, 50, 500) }, m)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(500, 52, 500) }, m)
	local hum = make("Humanoid", { Name = "Humanoid", HipHeight = 2 }, m)
	make("Animator", { Name = "Animator" }, hum)
	make("LocalScript", { Name = "Animate" }, m)
	m.PrimaryPart = root
	return m
end

---------------------------------------------------------------- joueurs
local userIds = 0
PROFILES = {}
function newProfile()
	return {
		Tools = { Owned = { "Fists" }, Equipped = "Fists" },
		Stats = { Speed = 0, Strength = 10000 }, -- 101 de dégâts : une vitrine de zone 1 (35 PV) en un coup
		Lifetime = { PlaySeconds = 3600, Heists = 0, Steals = 0, Defenses = 0 },
		Items = {},
		Boxes = {},
		Upgrades = { UnboxBenches = 0 },
	}
end
function newPlayer(name, loadProfile)
	userIds += 1
	local player = make("Player", { Name = name, UserId = userIds }, Players)
	make("Backpack", { Name = "Backpack" }, player)
	make("PlayerGui", { Name = "PlayerGui" }, player)
	Players.PlayerAdded:Fire(player)
	if loadProfile ~= false then
		local data = newProfile()
		PROFILES[player] = data
		serverModule("DataService")._load(player, data)
	end
	return player
end
-- Personnage R15 simplifié, debout en `position` (centre du HumanoidRootPart), regard vers `look`.
function spawnCharacter(player, position, look)
	local old = player.Character
	if old then
		old:Destroy()
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		backpack:Destroy() -- Roblox refait le Backpack à chaque apparition
	end
	make("Backpack", { Name = "Backpack" }, player)
	local character = make("Model", { Name = player.Name })
	local frame = if look then CFrame.lookAt(position, position + look) else CFrame.new(position)
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = frame, CanCollide = false }, character)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = frame * CFrame.new(0, 1.6, 0), CanCollide = false }, character)
	local hum = make("Humanoid", { Name = "Humanoid" }, character)
	make("Animator", { Name = "Animator" }, hum)
	character.PrimaryPart = root
	character.Parent = Workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end
function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end
function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end
-- Déplace le personnage (position du HumanoidRootPart), regard vers `look`.
function moveTo(player, position, look)
	local character = player.Character
	local frame = if look then CFrame.lookAt(position, position + look) else CFrame.new(position)
	character:PivotTo(frame)
end
-- Tourne le joueur vers `target` (à l'horizontale), sans le déplacer.
function face(player, target)
	local p = rootOf(player).Position
	local d = Vector3.new(target.X - p.X, 0, target.Z - p.Z)
	moveTo(player, p, d)
end
-- Le joueur quitte le jeu (comme Roblox : PlayerRemoving, puis personnage et joueur retirés).
function leave(player)
	Players.PlayerRemoving:Fire(player)
	flush()
	local character = player.Character
	if character then
		character:Destroy()
	end
	player.Parent = nil
	flush()
end

-- Appel client → serveur au nom de `player` (le vrai chemin : Net vérifie forme et débit).
function fireAs(player, remoteName, ...)
	local remote = ReplicatedStorage.Remotes:FindFirstChild(remoteName)
	table.insert(SERVER_CALLS, { t = now(), name = remoteName, args = table.pack(...), from = player })
	remote.OnServerEvent:Fire(player, ...)
end

-- La batte du joueur (dans le Backpack ou en main), et l'outil de casse.
function batOf(player)
	for _, container in { player.Character, player:FindFirstChild("Backpack") } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("BatTool") == true then
					return child
				end
			end
		end
	end
	return nil
end
function equipBat(player)
	local bat = batOf(player)
	humanoidOf(player):EquipTool(bat)
	return bat
end
function equipCasse(player)
	local backpack = player:FindFirstChild("Backpack")
	for _, container in { player.Character, backpack } do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ToolId") ~= nil then
				humanoidOf(player):EquipTool(child)
				return child
			end
		end
	end
	return nil
end

---------------------------------------------------------------- déplacements simulés
-- GOALS[player] = Vector3 : le joueur avance vers ce point à son Humanoid.WalkSpeed (celui de
-- StatsService : 0 = étourdi). Les vigiles avancent vers leur MoveTo à leur WalkSpeed. Une
-- LinearVelocity (knockback) posée dans un HumanoidRootPart le pousse à l'horizontale.
GOALS = {}
PUSHED = {} -- [player] = distance horizontale parcourue sous une poussée
local function stepToward(root, target, speed, dt)
	local pos = root.Position
	local d = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	local m = d.Magnitude
	local len = speed * dt
	if m <= 1e-3 or len <= 0 then
		return nil
	end
	local nextPos = pos + (if m <= len then d else d.Unit * len)
	return CFrame.lookAt(nextPos, nextPos + d.Unit)
end
BEFORE_FRAME = function(dt)
	for player, goal in GOALS do
		local root, hum = rootOf(player), humanoidOf(player)
		if root and hum and player.Parent == Players then
			local frame = stepToward(root, goal, hum.WalkSpeed, dt)
			if frame then
				player.Character:PivotTo(frame)
			end
		end
	end
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			for _, child in root:GetChildren() do
				if child:IsA("Attachment") then
					local mover = child:FindFirstChildOfClass("LinearVelocity")
					if mover then
						local v = mover.VectorVelocity
						local delta = Vector3.new(v.X, 0, v.Z) * dt
						-- Translation pure de toutes les pièces (pas de PivotTo à chaque image).
						for _, d in player.Character:GetDescendants() do
							if d:IsA("BasePart") then
								d.CFrame = d.CFrame + delta
							end
						end
						PUSHED[player] = (PUSHED[player] or 0) + delta.Magnitude
					end
				end
			end
		end
	end
	local active = Workspace:FindFirstChild("ActiveGuards")
	if active then
		for _, model in active:GetChildren() do
			local hum = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			local target = hum and rawget(hum, "_moveTarget")
			if root and target then
				local frame = stepToward(root, target, hum.WalkSpeed, dt)
				if frame then
					root.CFrame = frame
				end
			end
		end
	end
end
function guards()
	local active = Workspace:FindFirstChild("ActiveGuards")
	return if active then active:GetChildren() else {}
end
function guardFor(player)
	for _, g in guards() do
		if g:GetAttribute("TargetUserId") == player.UserId then
			return g
		end
	end
	return nil
end

---------------------------------------------------------------- colis : inventaire et invariants
function shelfCount(store)
	local f = store:FindFirstChild("ShelfBoxes")
	return if f then #f:GetChildren() else 0
end
function shelfBoxes(store)
	local f = store:FindFirstChild("ShelfBoxes")
	return if f then f:GetChildren() else {}
end
function dropsFolder()
	return Workspace:FindFirstChild("CarryDrops")
end
function batDrops()
	local out = {}
	local f = dropsFolder()
	if f then
		for _, child in f:GetChildren() do
			if child:GetAttribute("BatDrop") == true then
				table.insert(out, child)
			end
		end
	end
	return out
end
-- Colis vus partout : portés, au sol (par payload) ; une liste de doublons s'il y en a. Le sol est
-- lu dans CarryService pour chaque dropId jamais vu (KNOWN_DROPS, rempli à chaque modèle posé dans
-- Workspace/CarryDrops), pas seulement par les modèles encore là : un colis « au sol » sans modèle
-- compte aussi.
CONSUMED = {} -- payloads posés sur un établi (simulé : CarryService.Consume)
KNOWN_DROPS = {}
local function watchDropsFolder(f)
	f.ChildAdded:Connect(function(child)
		local id = child:GetAttribute("DropId")
		if id then
			KNOWN_DROPS[id] = true
		end
	end)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "CarryDrops" then
		watchDropsFolder(child)
	end
end)
function census()
	local Carry = serverModule("CarryService")
	local seen, duplicates = {}, {}
	local carried, ground = {}, {}
	local function note(payload, where)
		if seen[payload] then
			table.insert(duplicates, `{where} et {seen[payload]}`)
		end
		seen[payload] = where
	end
	for _, player in Players:GetPlayers() do
		local payload = Carry.GetPayload(player)
		if payload then
			note(payload, `porté par {player.Name}`)
			table.insert(carried, payload)
		end
	end
	for id in KNOWN_DROPS do
		local payload = Carry.GetDrop(id)
		if payload then
			note(payload, `au sol ({id})`)
			table.insert(ground, payload)
		end
	end
	for payload in CONSUMED do
		if seen[payload] then
			table.insert(duplicates, `posé sur un établi et {seen[payload]}`)
		end
	end
	return { carried = carried, ground = ground, duplicates = duplicates }
end
-- Colis d'un magasin hors de ses rayons : portés ou au sol (StoreId = celui du magasin).
function outCount(store, list)
	local n = 0
	for _, payload in list do
		if payload.StoreId == store.Name then
			n += 1
		end
	end
	return n
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
function notifies(pattern, to)
	return remotes("Notify", function(e)
		return (to == nil or e.to == to) and (pattern == nil or string.find(e.args[1], pattern, 1, true) ~= nil)
	end)
end

-- Casse la vitrine du magasin (un coup, 101 de dégâts) : le magasin ouvre pour 10 s.
function breakStore(player, store)
	local window = store:FindFirstChild("Window")
	local tool = equipCasse(player)
	local p = window.Position
	local side = if p.Z > 0 then -1 else 1
	moveTo(player, Vector3.new(p.X, 3, p.Z + side * 3), Vector3.new(0, 0, -side))
	fireAs(player, "HitWindow", window:GetAttribute("WindowId"))
	flush()
	return tool
end
-- Le joueur entre dans le magasin et prend le colis du rayon `slotNumber` (maintien du type).
function grabShelf(player, store, slotNumber)
	local slotName = string.format("ShelfSlot_%02d", slotNumber)
	local attachment = store:FindFirstChild(slotName, true)
	local p = attachment.WorldPosition
	local side = if p.Z > 0 then -1 else 1
	moveTo(player, Vector3.new(p.X, 3, p.Z + side * 3), Vector3.new(0, 0, -side))
	local box
	for _, b in shelfBoxes(store) do
		if b:GetAttribute("Slot") == slotName then
			box = b
		end
	end
	if box == nil then
		return false
	end
	local tier = box:GetAttribute("Tier")
	local grabTime = sharedModule("Config/Balance").Heist.BoxTiers[tier].GrabTime
	local slotId = box:GetAttribute("SlotId")
	fireAs(player, "GrabItem", slotId)
	advance(grabTime + 0.05)
	fireAs(player, "GrabItem", slotId)
	flush()
	return serverModule("CarryService").IsCarrying(player)
end
-- Numéro d'un rayon encore plein du magasin (le premier), ou nil.
function fullSlot(store)
	local best
	for _, b in shelfBoxes(store) do
		if b:GetAttribute("Landed") ~= false then
			local n = tonumber(string.match(b:GetAttribute("Slot"), "%d+"))
			if best == nil or n < best then
				best = n
			end
		end
	end
	return best
end
