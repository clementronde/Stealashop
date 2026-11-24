--!nocheck
-- Mise en place commune des scénarios du banc a29 (vague 10 : vol entre joueurs, DEV-041, DEV-044,
-- fin de DEV-040) : bouchons des services voisins, arbre du jeu (modules sous Shared, Server/Services
-- et Client/Controllers, comme Script Sync), hub avec 3 boutiques PLOT_Shop (la 3e tournée de 90°,
-- relevé wave10-studio section 1), joueurs, démarrage par le vrai Loader.
-- Vrais : PvPService, DisplayService, PlotService, WindowService, CarryService, PvPController, Net,
-- Config, Contract, Format, Types, Loader. Bouchons : DataService (profils et sauvegarde simulée),
-- NightCycleService (bouclier débutant piloté), ToolService, StatsService ; côté client :
-- WindowController (PV reçus par WindowHP) et AnimationController.

---------------------------------------------------------------- bouchons
-- DataService : un profil actif par joueur (la même table que STORE[UserId] tant qu'il est là) ;
-- au départ, OnProfileReleasing puis copie figée dans STORE (ce que ProfileStore aurait écrit) et
-- RELEASED[UserId] garde l'ancienne table vivante, pour vérifier que plus personne n'y écrit.
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
DataService.deepCopy = deepCopy
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
	table.insert(DataService.saves, { player = player, userId = player.UserId, t = os.clock(), snapshot = deepCopy(data) })
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
		for _, fn in releasingListeners do
			local ok, err = pcall(fn, player)
			if not ok then warn("OnProfileReleasing : " .. tostring(err)) end
		end
		profiles[player] = nil
		STORE[player.UserId] = deepCopy(data)
		RELEASED[player.UserId] = { live = data, saved = STORE[player.UserId] }
	end)
end
return DataService
]==]
STORE = {}
RELEASED = {}

-- NightCycleService : seul le bouclier débutant sert ici (SHIELDED[player] = true).
SOURCES["stub/NightCycleService"] = [==[
local NightCycleService = { Priority = 115 }
function NightCycleService.IsShielded(player)
	if SHIELD_ERROR then error("panne simulée de IsShielded") end
	return SHIELDED[player] == true
end
return NightCycleService
]==]
SHIELDED = {}

-- ToolService : dégâts par coup DAMAGE[player] (10 par défaut) ; outil en main = un Tool avec ToolId.
SOURCES["stub/ToolService"] = [==[
local ToolService = {}
function ToolService.GetHitDamage(player)
	return DAMAGE[player] or 10
end
function ToolService.IsHoldingTool(player)
	local character = player.Character
	if character == nil then return false end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ToolId") ~= nil then return true end
	end
	return false
end
return ToolService
]==]
DAMAGE = {}

SOURCES["stub/StatsService"] = [==[
local StatsService = {}
function StatsService.SetSpeedModifier(player, key, multiplier)
	SPEED_MODIFIERS[player] = SPEED_MODIFIERS[player] or {}
	SPEED_MODIFIERS[player][key] = multiplier
end
function StatsService.SetFixedSpeed(player, walkSpeed) -- vitesse fixe (objet volé, Cantin 2026-11-13)
	SPEED_MODIFIERS[player] = SPEED_MODIFIERS[player] or {}
	SPEED_MODIFIERS[player].Fixed = walkSpeed
end
return StatsService
]==]
SPEED_MODIFIERS = {}

-- Client : WindowController garde les PV reçus par WindowHP ; AnimationController note les animations.
SOURCES["stub/WindowController"] = [==[
local WindowController = { hp = {} }
function WindowController.GetHP(windowId)
	local entry = WindowController.hp[windowId]
	if entry then return entry.hp, entry.max end
	return nil, nil
end
function WindowController.Start()
	local Net = require(game:GetService("ReplicatedStorage").Shared.Net.Net)
	Net.Client.WindowHP:Connect(function(windowId, hp, maxHp)
		WindowController.hp[windowId] = { hp = hp, max = maxHp }
	end)
end
return WindowController
]==]
SOURCES["stub/AnimationController"] = [==[
local AnimationController = { played = {} }
function AnimationController.PlayPlayer(name)
	table.insert(AnimationController.played, name)
	return nil
end
return AnimationController
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
moduleScript(SERVICES, "AntiCheatService", "stub/AntiCheatService") -- a36 (DEV-060) : les services qui déplacent un joueur le déclarent (Allow), PvPService contrôle le dépôt (Verify)
for _, name in { "PvPService", "DisplayService", "PlotService", "WindowService", "CarryService" } do
	moduleScript(SERVICES, name, `server/Services/{name}.luau`)
end
for _, name in { "DataService", "NightCycleService", "ToolService", "StatsService" } do
	moduleScript(SERVICES, name, `stub/{name}`)
end
local sps = make("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, StarterPlayer)
local clientFolder = folder(sps, "Client")
CONTROLLERS = folder(clientFolder, "Controllers")
moduleScript(CONTROLLERS, "PvPController", "client/Controllers/PvPController.luau")
for _, name in { "WindowController", "AnimationController" } do
	moduleScript(CONTROLLERS, name, `stub/{name}`)
end

function serverModule(name)
	return requireModule(SERVICES:FindFirstChild(name), "server")
end
function clientModule(name)
	return requireModule(CONTROLLERS:FindFirstChild(name), "client")
end
function sharedModule(path)
	local current = SHARED
	for segment in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(segment)
	end
	return requireModule(current, "server")
end

---------------------------------------------------------------- carte : hub et boutiques (relevé wave10-studio, section 1)
MAP = folder(Workspace, "Map")
HUB = folder(MAP, "Hub")
make("Part", { Name = "HubFloor", Anchored = true, Size = Vector3.new(600, 1, 600), CFrame = CFrame.new(0, -0.5, 0) }, HUB)
SAFE_ZONE = make("Part", { Name = "SafeZone", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(600, 170, 600), CFrame = CFrame.new(0, 75, 0) }, HUB)
addTag(SAFE_ZONE, "SafeZone")

-- Boutique au gabarit PLOT_Shop de Clément (tools/clement/hub/plot_shop_builder.luau) : sol 64 × 80,
-- Bounds = l'intérieur, DepositZone sur tout le sol, porte PlotDoor/Window (pivot au sol au milieu de
-- l'entrée, z local −39,5, vantaux Leaf_L et Leaf_R), PlotBarrier, 20 présentoirs devant, coffre-fort
-- au fond, SpawnPoint dedans, CashPad, NameSign. `origin` = pivot de la boutique, avant vers −Z.
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
	local S = { origin = origin, slots = {}, vault = {} }
	for i = 1, 20 do
		local col, row = (i - 1) % 5, (i - 1) // 5
		S.slots[i] = att(string.format("DisplaySlot_%02d", i), -24 + 12 * col, 3.8, -30 + 8 * row)
	end
	for i = 1, 3 do
		S.vault[i] = att(string.format("VaultSlot_%02d", i), -20 + 4 * i, 2.9, 32)
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
	shop:SetAttribute("PlotIndex", index)
	addTag(shop, "PlayerPlot")
	shop.Parent = HUB
	SHOPS[index] = { model = shop, S = S }
	return shop, S
end
makeShop(1, CFrame.new(0, 0, 100))
makeShop(2, CFrame.new(110, 0, 100))
makeShop(3, CFrame.new(-150, 0, 30) * CFrame.Angles(0, math.rad(-90), 0)) -- tournée de 90° : avant vers +X (le hub)
-- Milieu du hub : passage entre deux boutiques sans traverser les autres.
HUB_CENTER = Vector3.new(-40, 3, 0)

---------------------------------------------------------------- joueurs
local userIds = 0
function newPlayer(name)
	userIds += 1
	local player = make("Player", { Name = name, DisplayName = name, UserId = userIds }, Players)
	make("Backpack", { Name = "Backpack" }, player)
	make("PlayerGui", { Name = "PlayerGui" }, player)
	Players.PlayerAdded:Fire(player)
	return player
end
-- Personnage R15 simplifié, HumanoidRootPart en `position`.
function spawnCharacter(player, position)
	local character = make("Model", { Name = player.Name })
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position), CanCollide = false }, character)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0)), CanCollide = false }, character)
	make("Humanoid", { Name = "Humanoid" }, character)
	character.PrimaryPart = root
	character.Parent = Workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end
function rootOf(player)
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") else nil
end
function moveTo(player, position)
	player.Character:PivotTo(CFrame.new(position))
end
function giveTool(player)
	local tool = make("Tool", { Name = "Fists" })
	tool:SetAttribute("ToolId", "Fists")
	tool.Parent = player.Character
	return tool
end
function dropTools(player)
	for _, child in player.Character:GetChildren() do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end
end

-- Profil complet au schéma v2 (DataService, TEMPLATE).
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
		Lifetime = { Heists = 0, Steals = 0, Defenses = 0, PlaySeconds = 3600 },
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

-- Arrivée d'un joueur : profil chargé (la boutique libre de plus petit numéro lui est donnée par
-- PlotService), personnage posé chez lui par PlotService au tour suivant.
function join(name, data)
	local player = newPlayer(name)
	spawnCharacter(player, Vector3.new(0, 3, 0))
	DataService._load(player, data)
	advance(0.2)
	return player
end
-- Départ : PlayerRemoving (le joueur est encore dans Players, comme Roblox), puis personnage retiré.
function leave(player)
	Players.PlayerRemoving:Fire(player)
	local character = player.Character
	if character then
		character:Destroy()
	end
	player.Parent = nil
end
function kill(player)
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	humanoid.Health = 0
	humanoid.Died:Fire()
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
	DataService = serverModule("DataService")
	PvPService = serverModule("PvPService")
	DisplayService = serverModule("DisplayService")
	PlotService = serverModule("PlotService")
	WindowService = serverModule("WindowService")
	CarryService = serverModule("CarryService")
end
function startClient(player)
	CLIENT_PLAYER = player
	Players.LocalPlayer = player
	local Loader = requireModule(SHARED:FindFirstChild("Loader"), "client")
	Loader.start(CONTROLLERS, "Client")
	flush()
	PvPController = clientModule("PvPController")
	ClientWindow = clientModule("WindowController")
	ClientAnimation = clientModule("AnimationController")
end

---------------------------------------------------------------- aides des scénarios
function shopOf(player)
	return PlotService.GetPlot(player)
end
function refsOfShop(plot)
	for _, entry in SHOPS do
		if entry.model == plot then
			return entry.S
		end
	end
	return nil
end
function windowIdOf(plot)
	return WindowService.GetWindowId(plot)
end
-- Casse la porte de `plot` : le frappeur se met devant, outil en main, et frappe 9 fois par seconde.
function breakDoor(hitter, plot, maxHits)
	local S = refsOfShop(plot)
	local id = windowIdOf(plot)
	-- Porte encore cassée par un essai précédent (fenêtre de vol fermée) : on attend qu'elle se refasse.
	local waited = 0
	while WindowService.IsBroken(id) and waited < 31 do
		advance(0.5, 0.1)
		waited += 0.5
	end
	moveTo(hitter, S.outside + S.front * -3) -- 3,5 studs devant la porte
	local tool = giveTool(hitter)
	local hits = 0
	while not WindowService.IsBroken(id) and hits < (maxHits or 300) do
		fireAs(hitter, "HitWindow", id)
		hits += 1
		advance(0.11)
	end
	tool:Destroy()
	return WindowService.IsBroken(id), hits
end
-- Se place à côté du présentoir `slot` de `plot` (à l'intérieur, 2 studs vers le centre).
function standBy(player, plot, slot)
	local S = refsOfShop(plot)
	local stand = S.slots[slot]
	local toward = (S.center - stand)
	toward = Vector3.new(toward.X, 0, toward.Z).Unit
	moveTo(player, Vector3.new(stand.X, 3, stand.Z) + toward * 2)
end
-- Prise en deux appels (StealItem), `hold` secondes entre les deux (PvP.StealGrabTime par défaut).
function steal(player, plot, slot, hold)
	standBy(player, plot, slot)
	local index = plot:GetAttribute("PlotIndex")
	fireAs(player, "StealItem", index, slot)
	advance(hold or 1.0)
	fireAs(player, "StealItem", index, slot)
	flush()
	return CarryService.IsCarrying(player)
end
-- Marche en ligne droite jusqu'à `target` à `speed` studs/s (pas de 0,1 s).
function walkTo(player, target, speed)
	speed = speed or 14
	while true do
		local root = rootOf(player)
		if root == nil or root.Parent == nil then
			return
		end
		local from = root.Position
		local delta = target - from
		local distance = delta.Magnitude
		if distance < 0.05 then
			return
		end
		local stepLength = math.min(distance, speed * 0.1)
		moveTo(player, from + delta.Unit * stepLength)
		advance(0.1)
	end
end
-- Fuite : sort par la porte de la boutique volée, rejoint sa porte, entre jusqu'au centre de sa boutique.
function runHome(thief, victimPlot, speed)
	local V = refsOfShop(victimPlot)
	local H = refsOfShop(shopOf(thief))
	walkTo(thief, Vector3.new(V.door.X, 3, V.door.Z) + V.front * 1, speed)
	walkTo(thief, V.outside, speed)
	walkTo(thief, HUB_CENTER, speed)
	walkTo(thief, H.outside, speed)
	walkTo(thief, Vector3.new(H.door.X, 3, H.door.Z) - H.front * 3, speed)
	walkTo(thief, H.center, speed)
	advance(0.3)
end

-- Tous les objets connus (profils actifs et sauvegardés) : uid → { userId… } ; et leur nombre.
function itemOwners()
	local owners, count = {}, 0
	for userId, data in STORE do
		for uid in data.Items do
			owners[uid] = owners[uid] or {}
			table.insert(owners[uid], userId)
			count += 1
		end
	end
	return owners, count
end
-- Invariants du transfert sûr : chaque uid dans un seul profil, `expected` objets en tout, chaque
-- présentoir pointe vers un objet du même profil, et aucun profil libéré n'a été modifié après coup.
function invariants(label, expected)
	local owners, count = itemOwners()
	local duplicated = 0
	for _, list in owners do
		if #list > 1 then
			duplicated += 1
		end
	end
	check(duplicated == 0, `{label} : aucun objet en double ({duplicated} doublon(s))`)
	if expected then
		check(count == expected, `{label} : {expected} objet(s) en tout (trouvé {count})`)
	end
	local dangling = 0
	for _, data in STORE do
		for _, uid in data.Display do
			if data.Items[uid] == nil then
				dangling += 1
			end
		end
	end
	check(dangling == 0, `{label} : chaque présentoir pointe vers un objet du profil ({dangling} entrée(s) orpheline(s))`)
	local touched = 0
	for _, entry in RELEASED do
		local live, saved = entry.live, entry.saved
		local a, b = 0, 0
		for _ in live.Items do a += 1 end
		for _ in saved.Items do b += 1 end
		if a ~= b then
			touched += 1
		end
	end
	check(touched == 0, `{label} : aucun profil libéré modifié après son départ`)
end
function notifies(player, pattern)
	return remotes("Notify", function(e)
		return e.to == player and (pattern == nil or string.find(e.args[1], pattern, 1, true) ~= nil)
	end)
end
function theftAlerts(player)
	return remotes("TheftAlert", function(e)
		return e.to == player
	end)
end
function visualsOn(plot)
	local folder = plot:FindFirstChild("DisplayItems")
	return if folder then folder:GetChildren() else {}
end
function displayModel(plot, slot)
	for _, model in visualsOn(plot) do
		if model:GetAttribute("DisplaySlot") == slot then
			return model
		end
	end
	return nil
end
function insideBox(part, point)
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end
function boundsOf(plot)
	return plot:FindFirstChild("Bounds")
end
