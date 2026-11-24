--!nocheck
-- Mise en place du banc a51 (L-089 : colis dans l'inventaire, posés et ouverts au sol de sa boutique,
-- objet gagné dans l'inventaire, Equip Best, profil v7). Reprise de la mise en place d'a46 (hub, 6
-- boutiques PLOT_Shop, CashPad, Bounds, tapis et banc, présentoirs bonus 21 à 24 sur les boutiques 1 et 2,
-- comptoir RobuxShop), avec :
--   - une zone safe (Part taggée SafeZone) qui couvre le hub ; le couloir est au-delà (x = 1000) ;
--   - la boutique 2 tournée de 90° (le point Spot d'un colis est dans le repère de la parcelle) ;
--   - les vrais InventoryService (serveur), InventoryController et UnboxController (client) ;
--   - CarryService du banc : Give (soulève, OnCarryStarted), Consume, Fail (OnCarryEnded, noté dans
--     CARRY_ENDS) ;
--   - AntiCheatService du banc : Verify noté (VERIFY_CALLS), verdict VERIFY_VERDICT (true par défaut).
-- Vrais services : InventoryService, IndexService, DataService (faux ProfileStore d'ext38),
-- DisplayService, PlotService, UnboxService, MonetizationService, TrainingService, StatsService,
-- ToolService, ShopService ; vrais Loader, Net, Config, Contract, Format, Types.

---------------------------------------------------------------- bouchons
SOURCES["stub/TelemetryService"] = [==[
local TelemetryService = { Priority = 210 }
function TelemetryService.LogEconomy(player, kind, amount, sku, fields)
	table.insert(TELEMETRY, { player = player, kind = kind, amount = amount, sku = sku, t = os.clock() })
	return true
end
function TelemetryService.LogEvent(_player, _key, _fields, _value)
	return true
end
return TelemetryService
]==]
TELEMETRY = {}

SOURCES["stub/CarryService"] = [==[
local CarryService = {}
local carrying = {}
local started, ended = {}, {}
function CarryService.IsCarrying(player) return carrying[player] ~= nil end
function CarryService.GetPayload(player) return carrying[player] end
local function finish(player, result, reason)
	local payload = carrying[player]
	if payload == nil then
		return nil
	end
	carrying[player] = nil
	player:SetAttribute("Carrying", nil)
	table.insert(CARRY_ENDS, { player = player, payload = payload, result = result, reason = reason })
	for _, fn in table.clone(ended) do
		task.spawn(fn, player, payload, result, reason)
	end
	return payload
end
function CarryService.Consume(player, reason)
	return finish(player, "Consumed", reason or "Consumed")
end
function CarryService.Fail(player, reason)
	return finish(player, "Failed", reason) ~= nil
end
function CarryService.OnCarryStarted(fn)
	table.insert(started, fn)
	return function() end
end
function CarryService.OnCarryEnded(fn)
	table.insert(ended, fn)
	return function() end
end
function CarryService.Give(player, payload)
	carrying[player] = payload
	player:SetAttribute("Carrying", if payload then payload.Rarity else nil)
	if payload then
		for _, fn in table.clone(started) do
			task.spawn(fn, player, payload)
		end
	end
end
return CarryService
]==]
CARRY_ENDS = {}

SOURCES["stub/AntiCheatService"] = [==[
local AntiCheatService = { allows = {} }
function AntiCheatService.Allow(player, seconds, reason)
	table.insert(AntiCheatService.allows, { player = player, seconds = seconds, reason = reason })
end
function AntiCheatService.Verify(player, from, since)
	table.insert(VERIFY_CALLS, { player = player, from = from, since = since })
	if VERIFY_VERDICT == false then
		-- Comme le vrai : sanctionné, le portage échoue (le colis revole vers son rayon).
		local CarryService = require(script.Parent.CarryService)
		CarryService.Fail(player, "Anomaly")
		return false
	end
	return true
end
function AntiCheatService.GetStrikes(_player)
	return 0
end
function AntiCheatService.GetLog()
	return {}
end
function AntiCheatService.OnDetection(_listener)
	return function() end
end
return AntiCheatService
]==]
VERIFY_CALLS = {}
VERIFY_VERDICT = true

SOURCES["stub/TutorialService"] = [==[
-- Accroche du colis garanti du tuto, comme le vrai TutorialService (Priority 200, posée dans Init).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local UnboxService = require(script.Parent.UnboxService)
local TutorialService = { Priority = 200 }
function TutorialService.Init()
	local baseDelay = UnboxService.GetOpenDelay
	UnboxService.GetOpenDelay = function(player, box)
		if box.ItemId == Tutorial.GuaranteedItemId and TUTORIAL_ACTIVE[player] then
			return Tutorial.OpenDelay
		end
		return baseDelay(player, box)
	end
end
return TutorialService
]==]
TUTORIAL_ACTIVE = {}

SOURCES["stub/PvPService"] = [==[
local PvPService = {}
function PvPService.OnTheftStarted(_fn) return function() end end
function PvPService.OnTheftEnded(_fn) return function() end end
return PvPService
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
moduleScript(folder(server, "Packages"), "ProfileStore", "stub/ProfileStore")
SERVICES = folder(server, "Services")
for _, name in { "InventoryService", "IndexService", "MonetizationService", "DataService", "DisplayService", "PlotService", "TrainingService", "UnboxService", "StatsService", "ToolService", "ShopService" } do
	moduleScript(SERVICES, name, `server/Services/{name}.luau`)
end
for _, name in { "TelemetryService", "CarryService", "AntiCheatService", "TutorialService", "PvPService" } do
	moduleScript(SERVICES, name, `stub/{name}`)
end
local clientRoot = folder(folder(StarterPlayer, "StarterPlayerScripts"), "Client")
CONTROLLERS = folder(clientRoot, "Controllers")
moduleScript(CONTROLLERS, "UnboxController", "client/Controllers/UnboxController.luau")
moduleScript(CONTROLLERS, "InventoryController", "client/Controllers/InventoryController.luau")
-- Copie d'a61 : InventoryController requiert Controllers/UI/Motion (écran UI_Inventory).
if SOURCES["client/Controllers/UI/Motion.luau"] and CONTROLLERS:FindFirstChild("UI") == nil then
	moduleScript(folder(CONTROLLERS, "UI"), "Motion", "client/Controllers/UI/Motion.luau")
end
do
	local unboxFolder = folder(CONTROLLERS, "Unbox")
	for _, name in { "Reel", "Sequence", "Screen" } do
		moduleScript(unboxFolder, name, `client/Controllers/Unbox/{name}.luau`)
	end
end

function serverModule(name)
	return requireModule(SERVICES:FindFirstChild(name), "server")
end
function sharedModule(path, side)
	local current = SHARED
	for segment in string.gmatch(path, "[^/]+") do
		current = current:FindFirstChild(segment)
	end
	return requireModule(current, side or "server")
end
function clientModule(name)
	return requireModule(CONTROLLERS:FindFirstChild(name), "client")
end

ASSETS = folder(ReplicatedStorage, "Assets")
ICONS = folder(ASSETS, "Icons")
-- Icônes ICON_<ItemId> (MOD-040) : une par objet du catalogue, sauf ICON_MISSING (pas livrée).
ICON_MISSING = "Z1_Brocoli"
ICON_TEXTURE = {} -- [ItemId] = texture posée
for n, item in sharedModule("Config/Items").List do
	if item.Id ~= ICON_MISSING then
		local texture = `rbxassetid://{7000 + n}`
		make("Decal", { Name = `ICON_{item.Id}`, Texture = texture }, ICONS)
		ICON_TEXTURE[item.Id] = texture
	end
end
-- Icône d'un type de colis (nom proposé à Clément : ICON_BOX_<Tier>) : seulement Premium.
make("Decal", { Name = "ICON_BOX_Premium", Texture = "rbxassetid://9100" }, ICONS)

---------------------------------------------------------------- carte : hub, zone safe, boutiques
Workspace.CurrentCamera = CAMERA
MAP = folder(Workspace, "Map")
HUB = folder(MAP, "Hub")
make("Part", { Name = "HubFloor", Anchored = true, Size = Vector3.new(600, 1, 600), CFrame = CFrame.new(0, -0.5, 0) }, HUB)
SAFE_ZONE = make("Part", { Name = "SafeZone", Anchored = true, Size = Vector3.new(500, 60, 440), CFrame = CFrame.new(0, 20, 0), Transparency = 1, CanCollide = false, CanQuery = false }, HUB)
addTag(SAFE_ZONE, "SafeZone")
CORRIDOR = Vector3.new(1000, 3, 0)

SHOPS = {}
function makeShop(index, origin, bonus)
	local shop = make("Model", { Name = string.format("PLOT_Shop_%02d", index) })
	local floor = make("Part", { Name = "PlotFloor", Anchored = true, CFrame = origin * CFrame.new(0, 0.15, 0), Size = Vector3.new(64, 0.3, 80), PivotOffset = CFrame.new(0, -0.15, 0) }, shop)
	shop.PrimaryPart = floor
	local function att(name, lx, ly, lz)
		local a = make("Attachment", { Name = name }, floor)
		a.CFrame = CFrame.new(lx, ly - 0.15, lz)
		return origin * Vector3.new(lx, ly, lz)
	end
	make("Part", { Name = "Bounds", Anchored = true, CFrame = origin * CFrame.new(0, 15.15, 0), Size = Vector3.new(64, 29.7, 80), Transparency = 1, CanCollide = false, CanQuery = false }, shop)
	local S = { origin = origin, slots = {} }
	for i = 1, 20 + (bonus or 0) do
		local col, row = (i - 1) % 5, (i - 1) // 5
		S.slots[i] = att(string.format("DisplaySlot_%02d", i), -24 + 12 * col, 3.8, -30 + 8 * row)
	end
	S.spawn = att("SpawnPoint", 0, 0.3, 20)
	local pad = make("Part", { Name = "CashPad", Anchored = true, CFrame = origin * CFrame.new(26, 0.4, 32), Size = Vector3.new(6, 0.15, 6) }, shop)
	addTag(pad, "CashPad")
	local function machine(name, tag, lx, lz)
		local model = make("Model", { Name = name }, shop)
		local base = make("Part", { Name = "Base", Anchored = true, CFrame = origin * CFrame.new(lx, 0.5, lz), Size = Vector3.new(4, 1, 6) }, model)
		local point = make("Attachment", { Name = "UsePoint" }, base)
		point.CFrame = CFrame.new(0, 0.5, 0)
		addTag(model, tag)
		return origin * Vector3.new(lx, 1, lz)
	end
	S.treadmill = machine("Treadmill", "Treadmill", -20, 30)
	S.bench = machine("Bench", "Bench", -10, 30)
	-- Un comptoir (meuble solide) et une étagère haute (son dessus n'est pas le sol), pour les refus.
	S.counter = origin * Vector3.new(10, 0.3, 10)
	make("Part", { Name = "Counter", Anchored = true, CFrame = origin * CFrame.new(10, 2.3, 10), Size = Vector3.new(4, 4, 2) }, shop)
	S.shelfTop = origin * Vector3.new(-10, 2.3, 10)
	make("Part", { Name = "LowShelf", Anchored = true, CFrame = origin * CFrame.new(-10, 1.3, 10), Size = Vector3.new(4, 2, 4) }, shop)
	local sign = make("Model", { Name = "NameSign" }, shop)
	local signPart = make("Part", { Name = "Board", Anchored = true, CFrame = origin * CFrame.new(0, 12, -40.5), Size = Vector3.new(20, 3, 0.4) }, sign)
	local gui = make("SurfaceGui", { Name = "SignGui" }, signPart)
	make("TextLabel", { Name = "OwnerName", Text = "" }, gui)
	S.center = origin * Vector3.new(0, 3, 0)
	shop:SetAttribute("PlotIndex", index)
	addTag(shop, "PlayerPlot")
	shop.Parent = HUB
	SHOPS[index] = { model = shop, S = S }
	return shop, S
end
makeShop(1, CFrame.new(0, 0, 100), 4)
makeShop(2, CFrame.new(110, 0, 100) * CFrame.Angles(0, math.pi / 2, 0), 4)
makeShop(3, CFrame.new(-150, 0, 30), 0)
makeShop(4, CFrame.new(0, 0, -100), 0)
makeShop(5, CFrame.new(110, 0, -100), 0)
makeShop(6, CFrame.new(-150, 0, -100), 0)

ROBUX_COUNTER = make("Part", { Name = "RobuxCounter", Anchored = true, CFrame = CFrame.new(-80, 2, -80), Size = Vector3.new(6, 4, 2) }, HUB)
addTag(ROBUX_COUNTER, "RobuxShop")

---------------------------------------------------------------- joueurs
local userIds = 0
-- Profil complet préparé pour le faux ProfileStore (clé Player_<UserId>), en v6 par défaut (la
-- migration v6 → v7 passe à chaque arrivée).
function newProfile(version)
	local v = version or 6
	local data = {
		Version = v,
		Cash = 1000,
		Stats = { Speed = 0, Strength = 0 },
		Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 }, -- 4 présentoirs
		Tools = { Owned = { "Fists" }, Equipped = "Fists" },
		Cosmetics = { Auras = {}, Trails = {} },
		Items = {},
		Display = {},
		Vault = {},
		Boxes = {},
		Tutorial = { Step = 10, Done = true },
		Lifetime = { Heists = 0, Steals = 0, Defenses = 0, PlaySeconds = 7200 },
		Purchases = {},
		Monetization = { Passes = {}, StarterPack = false, OpenNowCredit = 0 },
		Boosts = { Cash = 0 },
		Index = {},
	}
	if v >= 5 then
		data.BoxQueue = {}
	end
	if v >= 6 then
		data.Offline = { LastSeenAt = 0, Income = 0 }
	end
	return data
end
function addItem(data, uid, itemId, slot, zone, at)
	data.Items[uid] = { Id = itemId, Source = "NPC", At = at or 0, Zone = zone or 1 }
	if slot then
		data.Display[tostring(slot)] = uid
	end
	return uid
end
function join(name, data, userId)
	local id = userId
	if id == nil then
		userIds += 1
		id = userIds
	end
	if data ~= nil then
		PRESET_PROFILES[`Player_{id}`] = data
	end
	local player = make("Player", { Name = name, DisplayName = name, UserId = id }, nil)
	make("Backpack", { Name = "Backpack" }, player)
	make("PlayerGui", { Name = "PlayerGui" }, player)
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	spawnCharacter(player, Vector3.new(0, 3, 0))
	advance(0.3)
	return player
end
function spawnCharacter(player, position)
	local old = player.Character
	if old then
		old:Destroy()
	end
	-- Roblox refait le Backpack à chaque apparition.
	local oldBackpack = player:FindFirstChild("Backpack")
	if oldBackpack then
		oldBackpack:Destroy()
		make("Backpack", { Name = "Backpack" }, player)
	end
	local character = make("Model", { Name = player.Name })
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position), CanCollide = false }, character)
	make("Part", { Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0)), CanCollide = false }, character)
	local humanoid = make("Humanoid", { Name = "Humanoid" }, character)
	humanoid.RootPart = root
	character.PrimaryPart = root
	character.Parent = Workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end
function leave(player)
	Players.PlayerRemoving:Fire(player)
	flush()
	local character = player.Character
	if character then
		character:Destroy()
	end
	player.Parent = nil
	advance(0.1)
end
function moveTo(player, position)
	player.Character:PivotTo(CFrame.new(position))
end
function fireAs(player, remoteName, ...)
	local remote = ReplicatedStorage.Remotes:FindFirstChild(remoteName)
	table.insert(SERVER_CALLS, { t = now(), name = remoteName, args = table.pack(...), from = player })
	remote.OnServerEvent:Fire(player, ...)
end
function notifies(player, pattern)
	return remotes("Notify", function(e)
		return e.to == player and (pattern == nil or string.find(e.args[1], pattern, 1, true) ~= nil)
	end)
end
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
function dataOf(player)
	return DataService.Get(player)
end
function serverTime()
	return Workspace:GetServerTimeNow()
end
function countKeys(t)
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end
function npcBox(rarity, itemId, tier, zone, mutation)
	return { Kind = "NPCBox", Tier = tier or "Standard", Zone = zone or 1, Rarity = rarity, ItemId = itemId, StoreId = "Store_1", SlotId = "Store_1/01", Mutation = mutation }
end
-- Point du sol de sa boutique, en coordonnées locales de la parcelle (x, z), et le point de pied juste
-- à côté (2 studs vers -Z local) où se tient le joueur.
function floorPoint(player, lx, lz)
	return refsOfShop(shopOf(player)).origin * Vector3.new(lx, 0.3, lz)
end
function standNear(player, point)
	moveTo(player, point + Vector3.new(0, 3, 0) + Vector3.new(1.5, 0, 1.5))
	advance(0.05)
end
-- Le joueur soulève un colis PNJ dans le couloir, puis rentre dans la zone safe (devant sa boutique) :
-- renvoie l'uid du colis rangé dans l'inventaire (nil : pas rangé).
function bringBox(player, rarity, itemId, tier, zone, mutation)
	moveTo(player, CORRIDOR)
	advance(0.05)
	local before = {}
	for uid in dataOf(player).Boxes do
		before[uid] = true
	end
	CarryService.Give(player, npcBox(rarity, itemId, tier, zone, mutation))
	advance(0.3)
	moveTo(player, refsOfShop(shopOf(player)).center)
	advance(0.6)
	for uid in dataOf(player).Boxes do
		if not before[uid] then
			return uid
		end
	end
	return nil
end
-- Pose le colis `uid` de l'inventaire au sol de sa boutique, au point local (lx, lz), le joueur juste à
-- côté (sauf `from` : sa position). Renvoie le colis sauvegardé (Spot posé : accepté).
function placeAt(player, uid, lx, lz, from)
	local point = floorPoint(player, lx, lz)
	if from then
		moveTo(player, from)
	else
		standNear(player, point)
	end
	advance(0.3) -- PlaceBox : 4 appels par seconde au plus (Net)
	fireAs(player, "PlaceBox", uid, point)
	flush()
	return dataOf(player).Boxes[uid]
end
-- Ouvre le colis posé `uid` (attente écoulée, joueur à côté) ; renvoie l'uid de l'objet révélé.
function openPlaced(player, uid)
	local box = dataOf(player).Boxes[uid]
	assert(box and box.Spot, `colis {uid} pas posé`)
	advance(math.max(0, box.ReadyAt - serverTime()) + 0.3)
	standNear(player, UnboxService.GetBoxPosition(player, uid))
	local before = #remotes("UnboxReveal")
	fireAs(player, "OpenBox", uid)
	flush()
	local reveals = remotes("UnboxReveal")
	if #reveals == before then
		return nil
	end
	return reveals[#reveals].args[2]
end
-- Colis rapporté, posé (au point local donné, sinon (0, 0)), puis ouvert ; renvoie l'uid de l'objet.
function fullOpen(player, rarity, itemId, tier, zone, lx, lz)
	local uid = bringBox(player, rarity, itemId, tier, zone)
	assert(uid, `colis {itemId} pas rangé`)
	local box = placeAt(player, uid, lx or 0, lz or 0)
	assert(box and box.Spot, `colis {itemId} pas posé`)
	return openPlaced(player, uid)
end
-- Tools d'inventaire du joueur (Backpack et main), par clé « Box:<uid> » / « Item:<uid> ».
function toolsOf(player)
	local out = {}
	for _, container in { player:FindFirstChild("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					local kind = child:GetAttribute("InventoryKind")
					if kind == "Box" then
						out["Box:" .. child:GetAttribute("BoxUid")] = child
					elseif kind == "Item" then
						out["Item:" .. child:GetAttribute("ItemUid")] = child
					end
				end
			end
		end
	end
	return out
end
-- Copie d'a61 (vague 21, L-079) : plus de Tool de colis ni d'objet ; l'inventaire est dans l'attribut
-- InventoryState du Player (InventoryService, texte de Shared/InventoryState). invOf = ce que la barre
-- montrait : colis de l'inventaire (pas posés) et objets non exposés, par clé « Box:<uid> » / « Item:<uid> ».
function invState(player)
	return sharedModule("InventoryState").Decode(player:GetAttribute("InventoryState"))
end
function invOf(player)
	local out = {}
	local state = invState(player)
	for _, box in state.Boxes do
		if not box.Placed then
			out["Box:" .. box.Uid] = box
		end
	end
	for _, item in state.Items do
		if item.Slot == nil then
			out["Item:" .. item.Uid] = item
		end
	end
	return out
end
-- Entrée de l'état (colis posé ou objet exposé compris) par uid.
function invBox(player, uid)
	for _, box in invState(player).Boxes do
		if box.Uid == uid then
			return box
		end
	end
	return nil
end
function invItem(player, uid)
	for _, item in invState(player).Items do
		if item.Uid == uid then
			return item
		end
	end
	return nil
end
-- Tools du Backpack dans l'ordre (la barre de Roblox les range dans l'ordre d'arrivée).
function backpackOrder(player)
	local out = {}
	for _, child in player:FindFirstChild("Backpack"):GetChildren() do
		if child:IsA("Tool") then
			table.insert(out, child)
		end
	end
	return out
end
function floorBoxOf(player, uid)
	for _, child in shopOf(player):GetChildren() do
		if child.Name == "FloorBox" and child:GetAttribute("BoxUid") == uid then
			return child
		end
	end
	return nil
end
-- Délai de révélation chez celui qui ouvre (UnboxService : revealDelay), sans cran d'amélioration.
function revealDelay(rarityId)
	local Unbox = sharedModule("Config/Unbox")
	local full = Rarities.ById[rarityId].FullReveal
	local reel = if full then Unbox.ReelDuration.Full else Unbox.ReelDuration.Short
	return Unbox.OpenFallback + Unbox.ReelExit + reel + Unbox.LastNotch + Unbox.StopPause + Unbox.ColorIn
end

---------------------------------------------------------------- démarrage
function startServer()
	local Loader = sharedModule("Loader")
	Loader.start(SERVICES, "Serveur")
	flush()
	InventoryService = serverModule("InventoryService")
	IndexService = serverModule("IndexService")
	MonetizationService = serverModule("MonetizationService")
	DataService = serverModule("DataService")
	DisplayService = serverModule("DisplayService")
	PlotService = serverModule("PlotService")
	UnboxService = serverModule("UnboxService")
	CarryService = serverModule("CarryService")
	Items = sharedModule("Config/Items")
	Rarities = sharedModule("Config/Rarities")
	Tutorial = sharedModule("Config/Tutorial")
	Formulas = sharedModule("Config/Formulas")
	Unbox = sharedModule("Config/Unbox")
	Balance = sharedModule("Config/Balance")
	-- Banc déterministe : aucun cran d'amélioration à l'ouverture (l'objet est celui de la mise en rayon).
	UnboxService.GetLuck = function()
		return 0
	end
end
function startClient(player)
	CLIENT_PLAYER = player
	Players.LocalPlayer = player
	local Loader = requireModule(SHARED:FindFirstChild("Loader"), "client")
	Loader.start(CONTROLLERS, "Client")
	flush()
end

-- Attend la réponse d'un reçu (au plus `limit` s) et la renvoie (comme a38).
function settle(entry, limit)
	local waited = 0
	while not entry.done and waited < (limit or 5) do
		advance(0.1)
		waited += 0.1
	end
	return entry.decision
end
