--!nocheck
-- Mise en place commune des scénarios du banc a36 (vague 12, DEV-060 : AntiCheatService).
-- Vrais : AntiCheatService, CarryService, StatsService, StoreHeistService, WindowService, ToolService,
-- BatService, GuardService, PlotService, ReturnBaseService, TrainingService, PvPService,
-- DisplayService, NightCycleService, Loader, Net, Config, Contract, Anim, Format, Types. Bouchon :
-- DataService (profils, sauvegarde simulée, celui d'a29). Faux Roblox : celui d'a30 (stubs.luau),
-- les compléments d'a29 (ext29.luau) et les miens (ext36.luau).
-- Carte : le hub (zone safe, x < 25) avec 2 boutiques PLOT_Shop (gabarit d'a29) et, dans la 1re, un
-- tapis et un banc ; le couloir (route en x > 25) avec les 2 magasins de la zone 1 d'a30 face à face
-- et 2 points de ronde de nuit.
--
-- Client simulé : le client possède la physique de son personnage. CLIENT[player].pos est la position
-- « vraie » du centre de son HumanoidRootPart, côté client. À chaque image (BEFORE_FRAME) :
--   1. ce que le serveur a écrit lui-même dans le HumanoidRootPart (PivotTo d'un service, retour en
--      arrière de l'anti-triche, placement du banc) part vers le client, qui l'applique NET.oneWay s
--      plus tard ; d'ici là il envoie encore ses anciennes positions (le pire cas) ;
--   2. le client avance vers son but (walk) à sa vitesse : la WalkSpeed du serveur reçue NET.oneWay s
--      plus tôt (ou une vitesse imposée), × hack (la triche : vitesse modifiée côté client) ; une
--      LinearVelocity posée par le serveur dans son HumanoidRootPart le pousse, puis l'élan décroît
--      (GLIDE_DECAY) ;
--   3. le serveur reçoit la position (et la vitesse) que le client avait NET.oneWay + NET.extra(t) s
--      plus tôt, jamais en arrière, rien pendant un gel (NET.freezeUntil), seulement toutes les
--      NET.batch s si donné : c'est tout ce qu'il voit du personnage.
-- Un téléport de triche s'écrit côté client (cheatTeleport) ; un placement du banc côté serveur,
-- déclaré comme un déplacement du code (place).

---------------------------------------------------------------- bouchon
-- DataService (celui d'a29) : un profil actif par joueur ; au départ, OnProfileReleasing puis copie
-- figée dans STORE.
SOURCES["stub/DataService"] = [==[
local Players = game:GetService("Players")
local DataService = { Priority = 1, saves = {} }
local profiles, loadedListeners, releasingListeners = {}, {}, {}
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[k] = deepCopy(x) end
	return out
end
function DataService.Get(player) return profiles[player] end
function DataService.IsLoaded(player) return profiles[player] ~= nil end
function DataService.WaitFor(player) return profiles[player] end
function DataService.OnProfileLoaded(fn)
	table.insert(loadedListeners, fn)
	for p in profiles do task.spawn(fn, p) end
	return function() end
end
function DataService.OnProfileReleasing(fn)
	table.insert(releasingListeners, fn)
	return function() end
end
function DataService.OnCashChanged(fn) return function() end end
function DataService.AddCash(player, amount)
	local data = profiles[player]
	if data == nil then return nil end
	data.Cash += amount
	return data.Cash
end
function DataService.SpendCash(player, amount)
	local data = profiles[player]
	if data == nil or data.Cash < amount then return false end
	data.Cash -= amount
	return true
end
function DataService.Save(player)
	local data = profiles[player]
	if data == nil then return false end
	table.insert(DataService.saves, { player = player, t = os.clock() })
	return true
end
function DataService._load(player, data)
	profiles[player] = data
	STORE[player.UserId] = data
	for _, fn in loadedListeners do task.spawn(fn, player) end
end
function DataService.Init()
	Players.PlayerRemoving:Connect(function(player)
		local data = profiles[player]
		if data == nil then return end
		for _, fn in releasingListeners do pcall(fn, player) end
		profiles[player] = nil
		STORE[player.UserId] = deepCopy(data)
	end)
end
return DataService
]==]
STORE = {}

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
	"AntiCheatService",
	"CarryService",
	"StatsService",
	"StoreHeistService",
	"WindowService",
	"ToolService",
	"BatService",
	"GuardService",
	"PlotService",
	"ReturnBaseService",
	"TrainingService",
	"PvPService",
	"DisplayService",
	"NightCycleService",
} do
	moduleScript(SERVICES, name, `server/Services/{name}.luau`)
end
moduleScript(SERVICES, "DataService", "stub/DataService")

SERVER_SIDE = SERVER_SIDE or "server" -- « prod » (pre.prod.luau) : serveur hors Studio
function serverModule(name)
	return requireModule(SERVICES:FindFirstChild(name), SERVER_SIDE)
end
function sharedModule(path)
	local current = SHARED
	for segment in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(segment)
	end
	return requireModule(current, SERVER_SIDE)
end

---------------------------------------------------------------- carte
MAP = folder(Workspace, "Map")
make("Part", { Name = "HubFloor", Anchored = true, Size = Vector3.new(450, 1, 400), CFrame = CFrame.new(-200, -0.5, 0) }, MAP)
ROAD = make("Part", { Name = "Road", Anchored = true, Size = Vector3.new(800, 1, 60), CFrame = CFrame.new(330, -0.5, 0) }, MAP)
SAFE_ZONE = make("Part", {
	Name = "SafeZone",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	Transparency = 1,
	Size = Vector3.new(450, 170, 400),
	CFrame = CFrame.new(-200, 75, 0),
}, MAP)
addTag(SAFE_ZONE, "SafeZone") -- x de −425 à 25 : le couloir commence en x = 25

-- Magasin PNJ (celui d'a30) : sol, vitrine, Bounds, rideau, rayon du fond (ShelfSlot_01 à _10),
-- GuardSpawn. `side` = +1 (z > 0) ou −1.
STORES = {}
function buildStore(name, zone, x, side)
	local store = make("Model", { Name = name }, MAP)
	local base = make("Part", { Name = "Floor", Anchored = true, Size = Vector3.new(30, 1, 28), CFrame = CFrame.new(x, -0.5, side * 45) }, store)
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
	make("Attachment", { Name = "GuardSpawn", CFrame = CFrame.new(13, 0.5, side * 6) }, base)
	store:SetAttribute("Zone", zone)
	addTag(store, "NPCStore")
	table.insert(STORES, store)
	return store
end
STORE_A = buildStore("STORE_Z1_Superette", 1, 65, 1)
STORE_B = buildStore("STORE_Z1_Kiosque", 1, 65, -1)

-- Points de ronde de nuit de la zone 1 (5.12), sur la chaussée.
for i, x in { 150, 250 } do
	local point = make("Part", { Name = `Patrol_{i}`, Anchored = true, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(x, 1, 0) }, MAP)
	point:SetAttribute("Zone", 1)
	addTag(point, "NightPatrol")
end

-- Boutique au gabarit PLOT_Shop (celle d'a29) : sol 64 × 80, Bounds, DepositZone, porte PlotDoor/Window
-- (z local −39,5), PlotBarrier, 20 présentoirs, coffre-fort, SpawnPoint, CashPad, NameSign.
-- `origin` = pivot de la boutique, avant vers −Z.
SHOPS = {}
function makeShop(index, origin)
	local shop = make("Model", { Name = string.format("PLOT_Shop_%02d", index) })
	local floor = make("Part", { Name = "PlotFloor", Anchored = true, CFrame = origin * CFrame.new(0, 0.15, 0), Size = Vector3.new(64, 0.3, 80), PivotOffset = CFrame.new(0, -0.15, 0) }, shop)
	shop.PrimaryPart = floor
	local function att(name, lx, ly, lz)
		local a = make("Attachment", { Name = name }, floor)
		a.CFrame = CFrame.new(lx, ly - 0.15, lz)
		return origin * Vector3.new(lx, ly, lz)
	end
	local door = make("Model", { Name = "PlotDoor" }, shop)
	local window = make("Model", { Name = "Window" }, door)
	for _, side in { { "Leaf_L", -3 }, { "Leaf_R", 3 } } do
		local leaf = make("Model", { Name = side[1] }, window)
		make("Part", { Name = "Glass", Anchored = true, CFrame = origin * CFrame.new(side[2], 4.1, -39.5), Size = Vector3.new(6, 7, 0.4) }, leaf)
	end
	window.WorldPivot = origin * CFrame.new(0, 0.6, -39.5)
	door.WorldPivot = origin * CFrame.new(0, 8, -39.5)
	make("Model", { Name = "WindowFractured" }, door)
	local barrier = make("Model", { Name = "PlotBarrier" }, shop)
	for _, b in {
		{ "Barrier_L", CFrame.new(-31.8, 15, 0), Vector3.new(0.4, 30, 80) },
		{ "Barrier_R", CFrame.new(31.8, 15, 0), Vector3.new(0.4, 30, 80) },
		{ "Barrier_B", CFrame.new(0, 15, 39.8), Vector3.new(64, 30, 0.4) },
		{ "Barrier_FL", CFrame.new(-19, 15, -39.8), Vector3.new(26, 30, 0.4) },
		{ "Barrier_FR", CFrame.new(19, 15, -39.8), Vector3.new(26, 30, 0.4) },
	} do
		make("Part", { Name = b[1], Anchored = true, CFrame = origin * b[2], Size = b[3], Transparency = 1 }, barrier)
	end
	make("Part", { Name = "Bounds", Anchored = true, CFrame = origin * CFrame.new(0, 15.15, 0), Size = Vector3.new(64, 29.7, 80), Transparency = 1, CanCollide = false, CanQuery = false }, shop)
	make("Part", { Name = "DepositZone", Anchored = true, CFrame = origin * CFrame.new(0, 6, 0), Size = Vector3.new(63, 12, 79), Transparency = 1, CanCollide = false }, shop)
	local S = { origin = origin, slots = {} }
	for i = 1, 20 do
		local col, row = (i - 1) % 5, (i - 1) // 5
		S.slots[i] = att(string.format("DisplaySlot_%02d", i), -24 + 12 * col, 3.8, -30 + 8 * row)
	end
	for i = 1, 3 do
		att(string.format("VaultSlot_%02d", i), -20 + 4 * i, 2.9, 32)
	end
	for i = 1, 4 do
		att(string.format("UnboxBench_%02d", i), 10 + 4 * i, 3.1, 26)
	end
	S.spawn = att("SpawnPoint", 0, 0.3, 20)
	local pad = make("Part", { Name = "CashPad", Anchored = true, CFrame = origin * CFrame.new(26, 0.4, 32), Size = Vector3.new(6, 0.15, 6) }, shop)
	addTag(pad, "CashPad")
	local sign = make("Model", { Name = "NameSign" }, shop)
	local signPart = make("Part", { Name = "Board", Anchored = true, CFrame = origin * CFrame.new(0, 12, -40.5), Size = Vector3.new(20, 3, 0.4) }, sign)
	local gui = make("SurfaceGui", { Name = "SignGui" }, signPart)
	make("TextLabel", { Name = "OwnerName", Text = "" }, gui)
	S.door = origin * Vector3.new(0, 0.6, -39.5)
	S.front = (origin.Rotation * Vector3.new(0, 0, -1)) -- vers l'extérieur
	S.outside = origin * Vector3.new(0, 3, -46) -- 6,5 studs devant la porte, à hauteur de HumanoidRootPart
	S.center = origin * Vector3.new(0, 3, 0)
	S.back = origin * Vector3.new(0, 3, 36) -- au fond, loin de la porte
	shop:SetAttribute("PlotIndex", index)
	addTag(shop, "PlayerPlot")
	shop.Parent = MAP
	SHOPS[index] = { model = shop, S = S }
	return shop, S
end
makeShop(1, CFrame.new(-100, 0, 100))
makeShop(2, CFrame.new(-200, 0, 100))
HUB_CENTER = Vector3.new(-150, 3, 20) -- devant les deux boutiques, dans la zone safe

-- Tapis et banc de la boutique 1 (tags Treadmill et Bench, Attachment UsePoint, contrat 10.4).
for _, spec in { { "Treadmill", 20 }, { "Bench", -20 } } do
	local model = make("Model", { Name = spec[1] }, SHOPS[1].model)
	local base = make("Part", { Name = "Base", Anchored = true, Size = Vector3.new(4, 1, 6), CFrame = SHOPS[1].S.origin * CFrame.new(spec[2], 0.5, 10) }, model)
	make("Attachment", { Name = "UsePoint", CFrame = CFrame.new(0, 0.5, 0) }, base)
	model.PrimaryPart = base
	addTag(model, spec[1])
end
function machinePrompt(kind)
	local model = SHOPS[1].model:FindFirstChild(kind)
	local usePoint = model:FindFirstChild("UsePoint", true)
	return usePoint:FindFirstChild("TrainingPrompt"), usePoint.WorldPosition
end

-- Rig de remplacement des vigiles (Players:CreateHumanoidModelFromDescriptionAsync, faux d'a30).
RIG_FACTORY = function()
	local m = make("Model", { Name = "Player" })
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(500, 50, 500) }, m)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(500, 52, 500) }, m)
	local hum = make("Humanoid", { Name = "Humanoid", HipHeight = 2 }, m)
	make("Animator", { Name = "Animator" }, hum)
	m.PrimaryPart = root
	return m
end

---------------------------------------------------------------- joueurs
local userIds = 0
function newProfile()
	return {
		Version = 2,
		Cash = 1000,
		Stats = { Speed = 0, Strength = 0 },
		Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 },
		Tools = { Owned = { "Fists" }, Equipped = "Fists" },
		Cosmetics = { Auras = {}, Trails = {} },
		Items = {},
		Display = {},
		Vault = {},
		Boxes = {},
		Tutorial = { Step = 0, Done = true },
		Lifetime = { Heists = 0, Steals = 0, Defenses = 0, PlaySeconds = 3600 }, -- bouclier débutant fini
		Purchases = {},
	}
end
-- Ajoute un objet au profil, exposé sur le présentoir `slot` s'il est donné.
function addItem(data, uid, itemId, slot)
	data.Items[uid] = { Id = itemId, Source = "NPC", At = 0, Zone = 1 }
	if slot then
		data.Display[tostring(slot)] = uid
	end
	return uid
end
function newPlayer(name)
	userIds += 1
	local player = make("Player", { Name = name, DisplayName = name, UserId = userIds }, Players)
	make("Backpack", { Name = "Backpack" }, player)
	make("PlayerGui", { Name = "PlayerGui" }, player)
	Players.PlayerAdded:Fire(player)
	return player
end
-- Personnage R15 simplifié, HumanoidRootPart en `position` (le point d'apparition de Roblox).
function spawnCharacter(player, position, look)
	local old = player.Character
	if old then
		player.CharacterRemoving:Fire(old)
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
	local hum = make("Humanoid", { Name = "Humanoid", RootPart = root }, character)
	make("Animator", { Name = "Animator" }, hum)
	character.PrimaryPart = root
	character.Parent = Workspace
	CLIENT[player] = nil
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end
-- Arrivée : joueur, personnage au point d'apparition de l'allée, profil chargé (PlotService lui donne
-- la boutique libre de plus petit numéro et l'y pose).
function join(name, data, at)
	local player = newPlayer(name)
	spawnCharacter(player, at or Vector3.new(0, 3, 0))
	DataService._load(player, data or newProfile())
	advance(0.3)
	return player
end
function rootOf(player)
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") else nil
end
function humanoidOf(player)
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end
function kill(player)
	local humanoid = humanoidOf(player)
	humanoid.Health = 0
	humanoid.Died:Fire()
end
-- Appel client → serveur au nom de `player` (le vrai chemin : Net vérifie forme et débit).
function fireAs(player, remoteName, ...)
	local remote = ReplicatedStorage.Remotes:FindFirstChild(remoteName)
	table.insert(SERVER_CALLS, { t = now(), name = remoteName, args = table.pack(...), from = player })
	remote.OnServerEvent:Fire(player, ...)
end

---------------------------------------------------------------- client simulé et réseau (voir l'en-tête)
CLIENT = {}
NET = { oneWay = 0, extra = nil, freezeUntil = nil, batch = nil }
GLIDE = true -- l'élan après une poussée (LinearVelocity retirée) : il décroît en ~1 s
GLIDE_DECAY = 4
FRAMES = 0 -- images jouées depuis le début (une vérification de l'anti-triche toutes les 8 images)
local SPEED_LOG = {} -- [player] = { { t, speed } } : WalkSpeed du serveur, image par image

local function clientOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return nil, nil
	end
	local c = CLIENT[player]
	if c == nil or c.character ~= character then
		c = {
			character = character,
			pos = root.Position,
			vel = Vector3.zero,
			goal = nil,
			speed = nil, -- vitesse imposée (studs/s) ; nil = la WalkSpeed reçue du serveur
			hack = 1, -- triche : × la vitesse
			glide = Vector3.zero,
			history = {},
			pending = {},
			written = root.Position,
			lastTarget = -math.huge,
			lastBatch = nil,
		}
		CLIENT[player] = c
	end
	return c, root
end
function clientPos(player)
	local c = clientOf(player)
	return c and c.pos
end
-- WalkSpeed du serveur telle que le client la connaît : celle d'il y a NET.oneWay s.
local function receivedWalkSpeed(player, humanoid)
	local log = SPEED_LOG[player]
	local target = now() - NET.oneWay
	local best
	if log then
		for _, entry in log do
			if entry.t <= target + 1e-9 then
				best = entry.speed
			end
		end
	end
	return best or humanoid.WalkSpeed
end
local function moverOf(root)
	for _, child in root:GetChildren() do
		if child:IsA("Attachment") then
			local mover = child:FindFirstChildOfClass("LinearVelocity")
			if mover then
				return mover
			end
		end
	end
	return nil
end
local function stepClient(player, dt)
	local c, root = clientOf(player)
	local humanoid = humanoidOf(player)
	if c == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local t = now()
	SPEED_LOG[player] = SPEED_LOG[player] or {}
	table.insert(SPEED_LOG[player], { t = t, speed = humanoid.WalkSpeed })
	while #SPEED_LOG[player] > 0 and SPEED_LOG[player][1].t < t - 10 do
		table.remove(SPEED_LOG[player], 1)
	end
	-- 1. écritures du serveur (déplacements du code, retour en arrière)
	if (root.Position - c.written).Magnitude > 1e-4 then
		table.insert(c.pending, { at = t + NET.oneWay, pos = root.Position })
		c.written = root.Position
	end
	local i = 1
	while i <= #c.pending do
		local entry = c.pending[i]
		if entry.at <= t + 1e-9 then
			c.pos = entry.pos
			c.glide = Vector3.zero
			table.remove(c.pending, i)
		else
			i += 1
		end
	end
	-- 2. déplacement du client (but atteint : le point suivant de son trajet, s'il en a un)
	local v = Vector3.zero
	if c.goal and c.route and #c.route > 0 and Vector3.new(c.goal.X - c.pos.X, 0, c.goal.Z - c.pos.Z).Magnitude < 0.05 then
		c.goal = table.remove(c.route, 1)
	end
	if c.goal then
		local speed = (c.speed or receivedWalkSpeed(player, humanoid)) * c.hack
		local d = Vector3.new(c.goal.X - c.pos.X, 0, c.goal.Z - c.pos.Z)
		local m = d.Magnitude
		local len = speed * dt
		if m > 1e-3 and len > 0 then
			local move = if m <= len then d else d.Unit * len
			c.pos += move
			v = move / dt
		end
	end
	local mover = moverOf(root)
	if mover then
		local mv = mover.VectorVelocity
		local horizontal = Vector3.new(mv.X, 0, mv.Z)
		c.pos += horizontal * dt
		v += horizontal
		c.glide = horizontal
	elseif GLIDE and c.glide.Magnitude > 0.5 then
		c.pos += c.glide * dt
		v += c.glide
		c.glide *= math.exp(-dt * GLIDE_DECAY)
	else
		c.glide = Vector3.zero
	end
	c.vel = v
	table.insert(c.history, { t = t, pos = c.pos, vel = v })
	while #c.history > 0 and c.history[1].t < t - 12 do
		table.remove(c.history, 1)
	end
	-- 3. ce que le serveur reçoit
	if NET.freezeUntil and t < NET.freezeUntil then
		return
	end
	if NET.batch then
		local slot = math.floor(t / NET.batch)
		if slot == c.lastBatch then
			return
		end
		c.lastBatch = slot
	end
	local target = math.max(t - NET.oneWay - (if NET.extra then NET.extra(t) else 0), c.lastTarget)
	c.lastTarget = target
	local entry
	for _, h in c.history do
		if h.t <= target + 1e-9 then
			entry = h
		else
			break
		end
	end
	if entry == nil then
		return
	end
	if (entry.pos - root.Position).Magnitude > 1e-6 then
		c.character:PivotTo(CFrame.new(entry.pos) * root.CFrame.Rotation)
	end
	root.AssemblyLinearVelocity = entry.vel
	c.written = root.Position
end

BEFORE_FRAME = function(dt)
	FRAMES += 1
	for _, player in Players:GetPlayers() do
		stepClient(player, dt)
	end
	-- Vigiles : vers leur MoveTo, à leur WalkSpeed (le serveur possède leur physique).
	local active = Workspace:FindFirstChild("ActiveGuards")
	if active then
		for _, model in active:GetChildren() do
			local hum = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			local target = hum and rawget(hum, "_moveTarget")
			if root and target then
				local pos = root.Position
				local d = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
				local m = d.Magnitude
				local len = hum.WalkSpeed * dt
				if m > 1e-3 and len > 0 then
					local nextPos = pos + (if m <= len then d else d.Unit * len)
					root.CFrame = CFrame.lookAt(nextPos, nextPos + d.Unit)
				end
			end
		end
	end
end

-- Le client marche vers `goal` (à `speed` studs/s si donné, sinon à sa WalkSpeed).
function walk(player, goal, speed)
	local c = clientOf(player)
	c.goal = goal
	c.speed = speed
	c.route = nil
end
-- Le client suit les points de `points` dans l'ordre.
function route(player, points, speed)
	local c = clientOf(player)
	local list = table.clone(points)
	c.goal = table.remove(list, 1)
	c.route = list
	c.speed = speed
end
function stop(player)
	local c = clientOf(player)
	c.goal = nil
	c.speed = nil
	c.route = nil
end
-- Trajet d'une boutique à l'autre, par les portes (les murs des boutiques ne laissent pas passer).
function shopRoute(fromPlot, toPlot)
	local F, T = refsOfShop(fromPlot), refsOfShop(toPlot)
	return {
		Vector3.new(F.door.X, 3, F.door.Z) - F.front * 2,
		F.outside,
		T.outside,
		Vector3.new(T.door.X, 3, T.door.Z) - T.front * 6,
		T.center,
	}
end
function setHack(player, factor)
	clientOf(player).hack = factor
end
-- Avance jusqu'à l'arrivée du client à son but (à 0,05 stud près), `timeout` s au plus.
function arrive(player, timeout)
	local c = clientOf(player)
	local t = 0
	while c.goal and t < (timeout or 60) do
		local d = Vector3.new(c.goal.X - c.pos.X, 0, c.goal.Z - c.pos.Z).Magnitude
		if d < 0.05 then
			break
		end
		advance(FRAME)
		t += FRAME
	end
	advance(0.1)
end
-- Triche : le client se téléporte (le serveur le voit à la réplication suivante).
function cheatTeleport(player, position)
	local c = clientOf(player)
	c.pos = position
	c.goal = nil
end
-- Placement par le banc, côté serveur, déclaré comme un déplacement du code (pas une triche).
function place(player, position, look)
	local character = player.Character
	local frame = if look then CFrame.lookAt(position, position + look) else CFrame.new(position)
	AC.Allow(player, 0, "banc (placement)")
	character:PivotTo(frame)
	local c = clientOf(player)
	if c then
		c.goal = nil
	end
	advance(FRAME)
end
-- Attend la fin de l'autorisation d'un placement (AllowSettle) : le contrôle reprend.
function settle()
	advance(Config.AllowSettle + 0.3)
end
-- Le joueur regarde `target` (à l'horizontale), sans bouger.
function face(player, target)
	local root = rootOf(player)
	local p = root.Position
	local d = Vector3.new(target.X - p.X, 0, target.Z - p.Z)
	local frame = CFrame.lookAt(p, p + d)
	for _, part in player.Character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = frame * root.CFrame:ToObjectSpace(part.CFrame)
		end
	end
	clientOf(player).written = rootOf(player).Position
end

---------------------------------------------------------------- outils et batte (ToolService réel)
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
	for _, container in { player.Character, player:FindFirstChild("Backpack") } do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ToolId") ~= nil then
				humanoidOf(player):EquipTool(child)
				return child
			end
		end
	end
	return nil
end
function unequip(player)
	humanoidOf(player):UnequipTools()
end

---------------------------------------------------------------- magasins PNJ (aides d'a30, avec place)
function shelfBoxes(store)
	local f = store:FindFirstChild("ShelfBoxes")
	return if f then f:GetChildren() else {}
end
-- Colis posés (atterris) sur les rayons du magasin.
function landedCount(store)
	local n = 0
	for _, b in shelfBoxes(store) do
		if b:GetAttribute("Landed") ~= false then
			n += 1
		end
	end
	return n
end
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
-- Casse la vitrine (un coup de 101) : le magasin ouvre 10 s.
function breakStore(player, store)
	local window = store:FindFirstChild("Window")
	local p = window.Position
	local side = if p.Z > 0 then -1 else 1
	place(player, Vector3.new(p.X, 3, p.Z + side * 3), Vector3.new(0, 0, -side))
	equipCasse(player)
	fireAs(player, "HitWindow", window:GetAttribute("WindowId"))
	flush()
	unequip(player)
end
-- Le joueur entre et prend le colis du rayon `slotNumber` (maintien du type).
function grabShelf(player, store, slotNumber)
	local slotName = string.format("ShelfSlot_%02d", slotNumber)
	local attachment = store:FindFirstChild(slotName, true)
	local p = attachment.WorldPosition
	local side = if p.Z > 0 then -1 else 1
	place(player, Vector3.new(p.X, 3, p.Z + side * 3), Vector3.new(0, 0, -side))
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
	return Carry.IsCarrying(player)
end
-- Le magasin est ouvert (vitrine cassée, chrono en cours) ; sinon on la casse.
function ensureOpen(player, store)
	if store:GetAttribute("HeistOpen") == true then
		return
	end
	local w = store:FindFirstChild("Window")
	if w:GetAttribute("Broken") == true then
		Window.Rebuild(w:GetAttribute("WindowId"))
		flush()
	end
	breakStore(player, store)
	advance(1.1) -- avance du casseur passée
end
-- Braquage complet : `player` casse (si besoin), prend un colis et ressort sur la chaussée en `out`.
function heist(player, store, out)
	ensureOpen(player, store)
	local slot = fullSlot(store)
	assert(slot, "plus aucun colis sur les rayons")
	assert(grabShelf(player, store, slot), "prise refusée")
	if out then
		place(player, out)
	end
	return Carry.GetPayload(player)
end

---------------------------------------------------------------- boutiques des joueurs (aides d'a29, avec place)
function shopOf(player)
	return Plot.GetPlot(player)
end
function refsOfShop(plot)
	for _, entry in SHOPS do
		if entry.model == plot then
			return entry.S
		end
	end
	return nil
end
-- Casse la porte de `plot` (un coup de 101 contre 50 PV). Porte encore cassée par un essai précédent :
-- on attend qu'elle se refasse (le voleur resté dedans est alors sorti devant : PutOutside).
function breakDoor(hitter, plot)
	local S = refsOfShop(plot)
	local id = Window.GetWindowId(plot)
	local waited = 0
	while Window.IsBroken(id) and waited < 40 do
		advance(0.5)
		waited += 0.5
	end
	place(hitter, S.outside + S.front * -3)
	equipCasse(hitter)
	local hits = 0
	while not Window.IsBroken(id) and hits < 300 do
		fireAs(hitter, "HitWindow", id)
		hits += 1
		advance(0.11)
	end
	unequip(hitter)
	return Window.IsBroken(id)
end
-- Prise en deux appels (StealItem), à côté du présentoir `slot`. Le placement du banc est fini avant la
-- prise : le voleur est contrôlé normalement dès qu'il porte l'objet.
function steal(player, plot, slot)
	local S = refsOfShop(plot)
	local stand = S.slots[slot]
	local toward = S.center - stand
	toward = Vector3.new(toward.X, 0, toward.Z).Unit
	place(player, Vector3.new(stand.X, 3, stand.Z) + toward * 2)
	settle()
	local index = plot:GetAttribute("PlotIndex")
	fireAs(player, "StealItem", index, slot)
	advance(1.0)
	fireAs(player, "StealItem", index, slot)
	flush()
	return Carry.IsCarrying(player)
end

---------------------------------------------------------------- anti-triche : lecture
function strikes(player)
	return AC.GetStrikes(player)
end
function detections()
	return #AC.GetLog()
end
function lastDetection()
	local log = AC.GetLog()
	return log[#log]
end
function setStrict(on)
	Workspace:SetAttribute("AntiCheatStrict", if on then true else nil)
end
-- Lance `fn` avec Allow coupé (contrôle : le même déplacement sans sa déclaration).
function withoutAllow(fn)
	local real = AC.Allow
	AC.Allow = function() end
	local ok, err = pcall(fn)
	AC.Allow = real
	if not ok then
		error(err, 0)
	end
end
function horizontal(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

---------------------------------------------------------------- démarrage
function startServer()
	local Loader = sharedModule("Loader")
	Loader.start(SERVICES, "Serveur")
	flush()
	DataService = serverModule("DataService")
	AC = serverModule("AntiCheatService")
	Carry = serverModule("CarryService")
	Stats = serverModule("StatsService")
	Heist = serverModule("StoreHeistService")
	Window = serverModule("WindowService")
	Plot = serverModule("PlotService")
	PvP = serverModule("PvPService")
	Display = serverModule("DisplayService")
	Night = serverModule("NightCycleService")
	Guard = serverModule("GuardService")
	Training = serverModule("TrainingService")
	Config = sharedModule("Config/AntiCheat")
end
