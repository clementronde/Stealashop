--!nocheck
-- Mise en place commune des scénarios du banc a32 (vague 11 : alerte de la victime et Adrénaline,
-- DEV-042). Reprise de celle d'a29 (vol entre joueurs) : bouchons des services voisins, arbre du jeu
-- (modules sous Shared, Server/Services et Client/Controllers, comme Script Sync), hub avec 5
-- boutiques PLOT_Shop (les 3 d'a29, plus 2 tournées de 180° en face), joueurs, démarrage par le vrai
-- Loader. Ajouts : vrais StatsService (WalkSpeed appliqué), BatService et TheftAlertService côté
-- serveur ; TheftAlertController, BatController et ShelfBoxController côté client ; batte dans le
-- Backpack ; faux écran UI_TheftAlert de Clément ; comptes de Highlight.

---------------------------------------------------------------- bouchons
-- DataService : un profil actif par joueur (la même table que STORE[UserId] tant qu'il est là) ;
-- au départ, OnProfileReleasing puis copie figée dans STORE (ce que ProfileStore aurait écrit).
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
	end)
end
return DataService
]==]
STORE = {}

-- NightCycleService : seul le bouclier débutant sert ici (SHIELDED[player] = true).
SOURCES["stub/NightCycleService"] = [==[
local NightCycleService = { Priority = 115 }
function NightCycleService.IsShielded(player)
	return SHIELDED[player] == true
end
return NightCycleService
]==]
SHIELDED = {}

-- ToolService : dégâts par coup DAMAGE[player] (10 par défaut) ; outil de casse en main = un Tool
-- avec ToolId ; batte en main = un Tool avec BatTool (posé par le vrai ToolService).
SOURCES["stub/ToolService"] = [==[
local ToolService = {}
local function holding(player, attribute)
	local character = player.Character
	if character == nil then return false end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(attribute) ~= nil then return true end
	end
	return false
end
function ToolService.GetHitDamage(player)
	return DAMAGE[player] or 10
end
function ToolService.IsHoldingTool(player)
	return holding(player, "ToolId")
end
function ToolService.IsHoldingBat(player)
	return holding(player, "BatTool")
end
return ToolService
]==]
DAMAGE = {}

-- Client : AnimationController note les animations demandées (aucune n'est livrée).
SOURCES["stub/AnimationController"] = [==[
local AnimationController = { played = {}, stopped = {} }
function AnimationController.PlayPlayer(name)
	table.insert(AnimationController.played, name)
	return nil
end
function AnimationController.StopPlayer(name)
	table.insert(AnimationController.stopped, name)
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
for _, name in {
	"TheftAlertService",
	"PvPService",
	"BatService",
	"StatsService",
	"DisplayService",
	"PlotService",
	"WindowService",
	"CarryService",
} do
	moduleScript(SERVICES, name, `server/Services/{name}.luau`)
end
for _, name in { "DataService", "NightCycleService", "ToolService" } do
	moduleScript(SERVICES, name, `stub/{name}`)
end
local sps = make("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, StarterPlayer)
local clientFolder = folder(sps, "Client")
CONTROLLERS = folder(clientFolder, "Controllers")
for _, name in { "TheftAlertController", "BatController", "ShelfBoxController" } do
	moduleScript(CONTROLLERS, name, `client/Controllers/{name}.luau`)
end
moduleScript(CONTROLLERS, "AnimationController", "stub/AnimationController")

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

ASSETS = folder(ReplicatedStorage, "Assets")

---------------------------------------------------------------- carte : hub et boutiques (relevé wave10-studio, section 1)
MAP = folder(Workspace, "Map")
HUB = folder(MAP, "Hub")
make("Part", { Name = "HubFloor", Anchored = true, Size = Vector3.new(600, 1, 600), CFrame = CFrame.new(0, -0.5, 0) }, HUB)
SAFE_ZONE = make("Part", { Name = "SafeZone", Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(600, 170, 600), CFrame = CFrame.new(0, 75, 0) }, HUB)
addTag(SAFE_ZONE, "SafeZone")

-- Boutique au gabarit PLOT_Shop de Clément (comme a29) : sol 64 × 80, Bounds = l'intérieur,
-- DepositZone sur tout le sol, porte PlotDoor/Window (z local −39,5), 20 présentoirs devant,
-- SpawnPoint dedans, CashPad. `origin` = pivot de la boutique, avant vers −Z.
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
	shop:SetAttribute("PlotIndex", index)
	addTag(shop, "PlayerPlot")
	shop.Parent = HUB
	SHOPS[index] = { model = shop, S = S }
	return shop, S
end
makeShop(1, CFrame.new(0, 0, 100))
makeShop(2, CFrame.new(110, 0, 100))
makeShop(3, CFrame.new(-150, 0, 30) * CFrame.Angles(0, math.rad(-90), 0)) -- avant vers +X (le hub)
makeShop(4, CFrame.new(0, 0, -100) * CFrame.Angles(0, math.rad(180), 0)) -- en face de la 1, avant vers +Z
makeShop(5, CFrame.new(110, 0, -100) * CFrame.Angles(0, math.rad(180), 0)) -- en face de la 2
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
-- Personnage R15 simplifié, HumanoidRootPart en `position`, regard vers `look` s'il est donné.
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
function rootOf(player)
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") else nil
end
function humanoidOf(player)
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end
function walkSpeed(player)
	local humanoid = humanoidOf(player)
	return if humanoid then humanoid.WalkSpeed else nil
end
function moveTo(player, position, look)
	local frame = if look then CFrame.lookAt(position, position + look) else CFrame.new(position)
	player.Character:PivotTo(frame)
end
function giveTool(player)
	local tool = make("Tool", { Name = "Fists" })
	tool:SetAttribute("ToolId", "Fists")
	tool.Parent = player.Character
	return tool
end
-- La batte en slot 2, comme le vrai ToolService la donne à chaque apparition (attribut BatTool).
function giveBat(player)
	local bat = make("Tool", { Name = "Bat" })
	bat:SetAttribute("BatTool", true)
	bat.Parent = player:FindFirstChild("Backpack")
	return bat
end
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
function holdsBat(player)
	local bat = batOf(player)
	return bat ~= nil and bat.Parent == player.Character
end

-- Profil complet au schéma v2 (DataService, TEMPLATE).
function newProfile()
	return {
		Version = 2,
		Cash = 1000,
		Stats = { Speed = 0, Strength = 0 },
		Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 2, UnboxBenches = 0 }, -- 6 présentoirs
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
-- La victime type : 5 objets exposés (le Pot de nouilles, Rare, est à l'abri).
function victimProfile()
	local data = newProfile()
	addItem(data, "v-soda", "Z1_CanetteDeSoda", 1)
	addItem(data, "v-chips", "Z1_PaquetDeChips", 2)
	addItem(data, "v-noodles", "Z1_PotDeNouilles", 3)
	addItem(data, "v-donut", "Z1_Donut", 4)
	addItem(data, "v-banana", "Z1_Banane", 5)
	return data
end

-- Arrivée d'un joueur : profil chargé (la boutique libre de plus petit numéro lui est donnée par
-- PlotService), personnage posé chez lui par PlotService au tour suivant.
function join(name, data)
	local player = newPlayer(name)
	spawnCharacter(player, Vector3.new(0, 3, 0))
	DataService._load(player, data or newProfile())
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
	BatService = serverModule("BatService")
	TheftAlertService = serverModule("TheftAlertService")
	NetServer = sharedModule("Net/Net")
end
function startClient(player)
	CLIENT_PLAYER = player
	Players.LocalPlayer = player
	local Loader = requireModule(SHARED:FindFirstChild("Loader"), "client")
	Loader.start(CONTROLLERS, "Client")
	flush()
	Alert = clientModule("TheftAlertController")
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
	local waited = 0
	while WindowService.IsBroken(id) and waited < 31 do
		advance(0.5, 0.1)
		waited += 0.5
	end
	moveTo(hitter, S.outside + S.front * -3)
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
-- Une image de plus : le client applique les messages reçus (TheftAlertController).
function frame()
	advance(FRAME)
end
function state()
	return Alert.GetState()
end
-- Highlight du Workspace, par nom : { total, enabled } ; allumés = ceux que Roblox compterait.
function highlightCounts()
	local counts = { total = 0, enabled = 0, byName = {} }
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Highlight") then
			counts.total += 1
			local entry = counts.byName[d.Name] or { total = 0, enabled = 0 }
			counts.byName[d.Name] = entry
			entry.total += 1
			if d.Enabled then
				counts.enabled += 1
				entry.enabled += 1
			end
		end
	end
	return counts
end
function named(counts, name)
	return counts.byName[name] or { total = 0, enabled = 0 }
end
function stolenOutlineOf(player)
	local character = player.Character
	return if character then character:FindFirstChild("StolenOutline", true) else nil
end
function alertHighlightOf(player)
	local character = player.Character
	return if character then character:FindFirstChild("TheftAlertHighlight") else nil
end
-- Faux écran UI_TheftAlert de Clément, version grise (contrat 2.2) : les 4 éléments dans des cadres
-- décoratifs, Enabled comme dans StarterGui. `arrowRotation` : Rotation posée par Clément.
function fakeScreen(parent, enabled, arrowRotation)
	local screen = make("ScreenGui", { Name = "UI_TheftAlert", Enabled = enabled ~= false, ResetOnSpawn = true })
	local banner = make("Frame", { Name = "Banner", Visible = true }, screen)
	local row = make("Frame", { Name = "TextRow" }, banner)
	make("TextLabel", { Name = "ThiefName", Text = "PLAYER" }, row)
	make("TextLabel", { Name = "Static", Text = "IS STEALING YOUR" }, row)
	make("TextLabel", { Name = "ItemName", Text = "ITEM" }, row)
	make("ImageLabel", { Name = "Arrow", Rotation = arrowRotation or 0, Visible = true }, screen)
	screen.Parent = parent
	return screen
end
-- Caméra posée en `position`, regard vers `target`.
function lookFrom(position, target)
	CAMERA.CFrame = CFrame.lookAt(position, target)
end
function near(a, b, eps)
	return a ~= nil and b ~= nil and math.abs(a - b) <= (eps or 1e-6)
end
