---------------------------------------------------------------- bouchons des voisins (a19)
-- ProfileStore : session ouverte tout de suite (sauf clé de SLOW_PROFILES, retenue tant qu'elle y
-- est), données = copie du modèle, rien n'est sauvegardé.
SLOW_PROFILES = {}
SOURCES["stub/ProfileStore"] = [==[
local ProfileStore = { DataStoreState = "NoInternet", IsClosing = false }
local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in t do c[k] = deepCopy(v) end
	return c
end
function ProfileStore.New(_name, template)
	local store = {}
	function store.StartSessionAsync(_self, key, _params)
		while SLOW_PROFILES[key] do task.wait(0.1) end
		local profile = { Data = deepCopy(template), Key = key, active = true }
		function profile.IsActive(self) return self.active end
		function profile.Reconcile(_self) end
		function profile.EndSession(self) self.active = false end
		function profile.AddUserId(_self, _id) end
		profile.OnSessionEnd = { Connect = function() return { Disconnect = function() end } end }
		return profile
	end
	return store
end
return ProfileStore
]==]

-- PlotService : la parcelle de chaque joueur est celle de PLOTS (posée par le banc).
PLOTS = {}
SOURCES["stub/PlotService"] = [==[
local PlotService = {}
function PlotService.GetPlot(player) return PLOTS[player] end
return PlotService
]==]

-- UnboxService : Refresh compté (et en panne si UNBOX_REFRESH_ERROR).
UNBOX_REFRESH = {}
UNBOX_REFRESH_ERROR = false
SOURCES["stub/UnboxService"] = [==[
local UnboxService = {}
function UnboxService.Refresh(player)
	UNBOX_REFRESH[player] = (UNBOX_REFRESH[player] or 0) + 1
	if UNBOX_REFRESH_ERROR then error("panne simulée de Refresh") end
end
return UnboxService
]==]

-- CosmeticService (a20) : l'interface attendue par ShopService, Owns et Grant.
-- GRANT_MODE : "ok", "fail" (Grant renvoie false) ou "error" (Grant lève une erreur).
COSMETIC_OWNED = {}
GRANT_CALLS = {}
GRANT_MODE = "ok"
SOURCES["stub/CosmeticService"] = [==[
local CosmeticService = {}
function CosmeticService.Owns(player, id)
	return COSMETIC_OWNED[player] ~= nil and COSMETIC_OWNED[player][id] == true
end
function CosmeticService.Grant(player, id)
	table.insert(GRANT_CALLS, { player = player, id = id })
	if GRANT_MODE == "fail" then return false end
	if GRANT_MODE == "error" then error("panne simulée de Grant") end
	COSMETIC_OWNED[player] = COSMETIC_OWNED[player] or {}
	COSMETIC_OWNED[player][id] = true
	return true
end
return CosmeticService
]==]

---------------------------------------------------------------- montage de la place
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

local server = folder(ServerScriptService, "Server")
local services = folder(server, "Services")
local packages = folder(server, "Packages")
moduleScript(packages, "ProfileStore", "stub/ProfileStore")
local dataModule = moduleScript(services, "DataService", "server/Services/DataService.luau")
local toolModule = moduleScript(services, "ToolService", "server/Services/ToolService.luau")
local shopModule = moduleScript(services, "ShopService", "server/Services/ShopService.luau")
moduleScript(services, "PlotService", "stub/PlotService")
moduleScript(services, "UnboxService", "stub/UnboxService")
if WITH_COSMETIC then
	moduleScript(services, "CosmeticService", "stub/CosmeticService")
end

local client = folder(StarterPlayerScripts, "Client")
local controllers = folder(client, "Controllers")
local weaponModule = moduleScript(controllers, "WeaponShopController", "client/Controllers/WeaponShopController.luau")
local upgradeModule = moduleScript(controllers, "UpgradeController", "client/Controllers/UpgradeController.luau")

---------------------------------------------------------------- aides
function new(class, props, parent)
	local inst = InstanceAPI.new(class)
	for k, v in props or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function part(name, pos, size, parent)
	return new("Part", { Name = name, CFrame = CFrame.new(pos.X, pos.Y, pos.Z), Size = size }, parent)
end

-- Attachment posé à la position monde `pos` dans `carrier`.
function attachment(name, carrier, pos)
	local a = new("Attachment", { Name = name })
	a.CFrame = CFrame.new(carrier.CFrame:PointToObjectSpace(pos))
	a.Parent = carrier
	return a
end

function logCount(pattern, kind, side)
	local n = 0
	for _, line in LOG do
		if (kind == nil or line.kind == kind) and (side == nil or line.side == side) and string.find(line.text, pattern, 1, true) then
			n += 1
		end
	end
	return n
end

-- Messages Notify envoyés à `player` depuis la position `mark` du journal des envois.
function notifies(player, mark)
	local out = {}
	for i = mark + 1, #REMOTE_LOG do
		local e = REMOTE_LOG[i]
		if e.name == "Notify" and e.to == player then
			table.insert(out, { text = e.args[1], kind = e.args[2] })
		end
	end
	return out
end
function mark()
	return #REMOTE_LOG
end
-- Le seul Notify envoyé à `player` depuis `m`, ou nil s'il y en a 0 ou plusieurs.
function onlyNotify(player, m)
	local list = notifies(player, m)
	return if #list == 1 then list[1] else nil
end

---------------------------------------------------------------- le monde
SHOP_SPOT = Vector3.new(-14, 3, 18) -- à 6 studs du comptoir d'armes
AURA_SPOT = Vector3.new(-14, 3, -18) -- à 6 studs du comptoir d'auras
FAR_SPOT = Vector3.new(-14, 3, 50) -- à 26 studs du comptoir d'armes
PLOT1_SPOT = Vector3.new(100, 3, 0)
PLOT2_SPOT = Vector3.new(300, 3, 0)

local function makeShop(name, tag, pos, parent)
	local model = new("Model", { Name = name })
	local counter = part("Counter", pos, Vector3.new(12, 4, 3), model)
	part("SignPart", pos + Vector3.new(0, 7, 4), Vector3.new(12, 4, 1), model)
	model.PrimaryPart = counter
	model.Parent = parent
	CollectionService_AddTag(model, tag)
	return model, counter
end

-- Parcelle de la greybox, réduite : Bounds, 20 présentoirs, 4 établis, tapis et banc avec leur
-- UsePoint et l'invite TrainingPrompt de TrainingService.
local function makePlot(index, x, owner)
	local model = new("Model", { Name = "PLOT_" .. index })
	local floor = part("Floor", Vector3.new(x, 0, 0), Vector3.new(60, 1, 80), model)
	part("Bounds", Vector3.new(x, 12, 0), Vector3.new(60, 24, 80), model)
	for i = 1, 20 do
		attachment(string.format("DisplaySlot_%02d", i), floor, Vector3.new(x - 25 + (i - 1) * 2.5, 1, -30))
	end
	for i = 1, 4 do
		attachment(string.format("UnboxBench_%02d", i), floor, Vector3.new(x - 9 + (i - 1) * 6, 3, -5))
	end
	local treadmill = new("Model", { Name = "Treadmill" })
	part("Base", Vector3.new(x - 22, 0.5, 6), Vector3.new(4, 1, 8), treadmill)
	local belt = part("Belt", Vector3.new(x - 22, 1.1, 6), Vector3.new(3, 0.2, 7), treadmill)
	part("Console", Vector3.new(x - 22, 2.75, 1.75), Vector3.new(4, 3.5, 0.5), treadmill)
	local use1 = attachment("UsePoint", belt, Vector3.new(x - 22, 1.2, 6))
	new("ProximityPrompt", { Name = "TrainingPrompt", ActionText = "Run", ObjectText = "Treadmill" }, use1)
	treadmill.Parent = model
	local bench = new("Model", { Name = "Bench" })
	local seat = part("Base", Vector3.new(x + 22, 0.75, 6), Vector3.new(2, 1.5, 6), bench)
	part("Bar", Vector3.new(x + 22, 4.15, 3.25), Vector3.new(7, 0.3, 0.3), bench)
	local use2 = attachment("UsePoint", seat, Vector3.new(x + 22, 1.5, 6))
	new("ProximityPrompt", { Name = "TrainingPrompt", ActionText = "Lift", ObjectText = "Weight Bench" }, use2)
	bench.Parent = model
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", owner)
	model.Parent = Workspace
	CollectionService_AddTag(model, "PlayerPlot")
	CollectionService_AddTag(treadmill, "Treadmill")
	CollectionService_AddTag(bench, "Bench")
	return model, treadmill, bench
end

function CollectionService_AddTag(inst, tag)
	addTag(inst, tag)
end

WEAPON_SHOP, WEAPON_COUNTER = makeShop("WeaponShop", "WeaponShop", Vector3.new(-14, 2, 24), Workspace)
AURA_SHOP, AURA_COUNTER = makeShop("AuraShop", "AuraShop", Vector3.new(-14, 2, -24), Workspace)
INBOX = folder(Workspace, "_INBOX_CLEMENT")
INBOX_SHOP, INBOX_COUNTER = makeShop("WeaponShop", "WeaponShop", Vector3.new(500, 2, 500), INBOX)
PLOT1, TREADMILL1, BENCH1 = makePlot(1, 100, 101)
PLOT2, TREADMILL2, BENCH2 = makePlot(2, 300, 202)

local function makePlayer(name, userId, pos)
	local p = new("Player", { Name = name, UserId = userId, DisplayName = name })
	local character = new("Model", { Name = name })
	local root = part("HumanoidRootPart", pos, Vector3.new(2, 2, 1), character)
	new("Humanoid", { Name = "Humanoid" }, character)
	character.Parent = Workspace
	p.Character = character
	new("Backpack", { Name = "Backpack" }, p)
	new("PlayerGui", { Name = "PlayerGui" }, p)
	p.Parent = Players
	if Players.PlayerAdded then
		Players.PlayerAdded:Fire(p) -- le faux Roblox n'émet pas PlayerAdded tout seul
	end
	return p, root
end
-- Joueur arrivé après le démarrage des services (à appeler depuis les scénarios).
function joinLater(name, userId, pos)
	return makePlayer(name, userId, pos)
end
P1, ROOT1 = makePlayer("Alice", 101, SHOP_SPOT)
P2, ROOT2 = makePlayer("Bob", 202, SHOP_SPOT)
PLOTS[P1] = PLOT1
PLOTS[P2] = PLOT2

function at(root, pos)
	root.CFrame = CFrame.new(pos.X, pos.Y, pos.Z)
end

---------------------------------------------------------------- démarrage (ordre du Loader)
NetS = requireModule(ReplicatedStorage.Shared.Net.Net, "server")
Tools = requireModule(ReplicatedStorage.Shared.Config.Tools, "server")
Upgrades = requireModule(ReplicatedStorage.Shared.Config.Upgrades, "server")
Cosmetics = requireModule(ReplicatedStorage.Shared.Config.Cosmetics, "server")
Formulas = requireModule(ReplicatedStorage.Shared.Config.Formulas, "server")
Balance = requireModule(ReplicatedStorage.Shared.Config.Balance, "server")
Format = requireModule(ReplicatedStorage.Shared.Format, "server")
DataService = requireModule(dataModule, "server")
ToolService = requireModule(toolModule, "server")
ShopService = requireModule(shopModule, "server")
DataService.Init() -- Priority 1
ShopService.Init() -- puis par nom : ShopService, ToolService
ToolService.Init()
step(0.1)

CLIENT_PLAYER = P1
Players.LocalPlayer = P1
NetC = requireModule(ReplicatedStorage.Shared.Net.Net, "client")
WeaponShopController = requireModule(weaponModule, "client")
UpgradeController = requireModule(upgradeModule, "client")
taskLib.spawn(WeaponShopController.Start)
taskLib.spawn(UpgradeController.Start)
step(0.1)

function setCash(player, amount)
	DataService.Get(player).Cash = amount
	player:SetAttribute("Cash", amount)
end
function cash(player)
	return DataService.Get(player).Cash
end
-- Envoi d'un remote au serveur par `player`, comme un vrai client (passe par Net), puis une image.
-- Chaque envoi attend 0,4 s avant : le débit de 4 par seconde n'est jamais atteint sans le vouloir.
function send(player, remote, ...)
	step(0.4)
	-- FindFirstChild : « EquipTool » est aussi le nom d'une méthode du faux Roblox (Humanoid:EquipTool).
	ReplicatedStorage.Remotes:FindFirstChild(remote).OnServerEvent:Fire(player, ...)
	step(1 / 30)
end
function owned(player, id)
	return table.find(DataService.Get(player).Tools.Owned, id) ~= nil
end
function heldToolId(player)
	local tool = player.Backpack:FindFirstChildOfClass("Tool") or player.Character:FindFirstChildOfClass("Tool")
	return if tool then tool:GetAttribute("ToolId") else nil
end
