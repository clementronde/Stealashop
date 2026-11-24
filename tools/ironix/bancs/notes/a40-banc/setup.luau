--!nocheck
-- Mise en place commune des scénarios du banc a40 (DEV-111 : index des objets). Repris de la mise en
-- place d'a38 (hub, 6 boutiques PLOT_Shop à 20 présentoirs et 4 établis, CashPad, Bounds, tapis et banc,
-- présentoirs bonus 21 à 24 sur les boutiques 1 et 2, comptoir RobuxShop).
-- Vrais services : IndexService, DataService (faux ProfileStore d'ext38), DisplayService, PlotService,
-- UnboxService, MonetizationService, TrainingService, StatsService, ToolService, ShopService ; vrais
-- Loader, Net, Config, Contract, Format, Types. Bouchons : TelemetryService, CarryService (colis donnés
-- par le banc), AntiCheatService (a36), TutorialService (seulement son accroche de GetOpenDelay, comme
-- a38), PvPService (seulement OnTheftEnded, et Steal / Fail qui font ce que fait le vrai au dépôt et à
-- l'échec). Client : le vrai IndexController et UI/Motion, sur une copie de UI_Index et de UI_HUD
-- d'après le relevé de Studio du 2026-11-08 (agents/wave14-studio.md).

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
function CarryService.IsCarrying(player) return carrying[player] ~= nil end
function CarryService.GetPayload(player) return carrying[player] end
function CarryService.Consume(player)
	local payload = carrying[player]
	carrying[player] = nil
	return payload
end
function CarryService.OnCarryStarted(_fn) return function() end end
function CarryService.OnCarryEnded(_fn) return function() end end
function CarryService.Give(player, payload) carrying[player] = payload end
return CarryService
]==]

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
-- Bouchon de PvPService pour IndexService : OnTheftEnded, et le dépôt d'un objet volé tel que le fait le
-- vrai (transfert sûr, même exécution : l'objet quitte Items de la victime et entre dans Items du
-- voleur, même uid, Source « PvP », puis OnTheftEnded(voleur, victime, ItemId, "Stolen", "Deposited")).
-- Fail : l'échec d'un vol (rien ne change de propriétaire), OnTheftEnded(…, "Returned", raison).
local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local PvPService = {}
local ended = {}
function PvPService.OnTheftStarted(_fn) return function() end end
function PvPService.OnTheftEnded(fn)
	table.insert(ended, fn)
	return function() end
end
function PvPService.Steal(thief, victim, uid)
	local victimData, thiefData = DataService.Get(victim), DataService.Get(thief)
	local entry = victimData.Items[uid]
	assert(entry, "objet à voler absent")
	DisplayService.Unplace(victim, uid)
	victimData.Items[uid] = nil
	thiefData.Items[uid] = { Id = entry.Id, Source = "PvP", At = os.time(), Zone = entry.Zone }
	DisplayService.PlaceAuto(thief, uid)
	for _, fn in table.clone(ended) do
		task.spawn(fn, thief, victim, entry.Id, "Stolen", "Deposited")
	end
	return entry.Id
end
function PvPService.Fail(thief, victim, itemId, reason)
	for _, fn in table.clone(ended) do
		task.spawn(fn, thief, victim, itemId, "Returned", reason or "Bat")
	end
end
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
for _, name in { "IndexService", "MonetizationService", "DataService", "DisplayService", "PlotService", "TrainingService", "UnboxService", "StatsService", "ToolService", "ShopService" } do
	moduleScript(SERVICES, name, `server/Services/{name}.luau`)
end
for _, name in { "TelemetryService", "CarryService", "AntiCheatService", "TutorialService", "PvPService" } do
	moduleScript(SERVICES, name, `stub/{name}`)
end
local clientRoot = folder(folder(StarterPlayer, "StarterPlayerScripts"), "Client")
CONTROLLERS = folder(clientRoot, "Controllers")
moduleScript(CONTROLLERS, "IndexController", "client/Controllers/IndexController.luau")
moduleScript(folder(CONTROLLERS, "UI"), "Motion", "client/Controllers/UI/Motion.luau")

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

---------------------------------------------------------------- carte : hub et boutiques (gabarit d'a35, comme a38)
MAP = folder(Workspace, "Map")
HUB = folder(MAP, "Hub")
make("Part", { Name = "HubFloor", Anchored = true, Size = Vector3.new(600, 1, 600), CFrame = CFrame.new(0, -0.5, 0) }, HUB)

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
	for i = 1, 4 do
		S["bench" .. i] = att(string.format("UnboxBench_%02d", i), 10 + 4 * i, 3.1, 26)
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
makeShop(2, CFrame.new(110, 0, 100), 4)
makeShop(3, CFrame.new(-150, 0, 30), 0)
makeShop(4, CFrame.new(0, 0, -100), 0)
makeShop(5, CFrame.new(110, 0, -100), 0)
makeShop(6, CFrame.new(-150, 0, -100), 0)

ROBUX_COUNTER = make("Part", { Name = "RobuxCounter", Anchored = true, CFrame = CFrame.new(-80, 2, -80), Size = Vector3.new(6, 4, 2) }, HUB)
addTag(ROBUX_COUNTER, "RobuxShop")

---------------------------------------------------------------- joueurs
local userIds = 0
-- Profil complet préparé pour le faux ProfileStore (clé Player_<UserId>), en v3 par défaut (le schéma
-- d'avant l'index : la migration v3 → v4 passe à chaque arrivée) ; version = 4 : avec un Index vide.
function newProfile(version)
	local data = {
		Version = version or 3,
		Cash = 1000,
		Stats = { Speed = 0, Strength = 0 },
		Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 3 }, -- 4 présentoirs, 4 établis
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
	}
	if (version or 3) >= 4 then
		data.Index = {}
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
-- Arrivée : le vrai DataService ouvre la session (faux ProfileStore), PlotService donne la boutique
-- libre de plus petit numéro et y pose le personnage. `userId` : pour revenir avec le même compte.
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
-- Pose un colis PNJ sur l'établi `bench` de sa boutique (vrai remote PlaceBox), comme a38.
function placeBox(player, bench, rarity, itemId, tier, zone)
	local S = refsOfShop(shopOf(player))
	moveTo(player, S["bench" .. bench] + Vector3.new(0, 2, -2))
	advance(0.3)
	CarryService.Give(player, { Kind = "NPCBox", Tier = tier or "Standard", Zone = zone or 1, Rarity = rarity, ItemId = itemId, StoreId = "Store_1", SlotId = "Store_1/01" })
	fireAs(player, "PlaceBox", bench)
	flush()
	return dataOf(player).Boxes[tostring(bench)]
end
-- Pose puis ouvre un colis (vrai remote OpenBox, attente écoulée) ; renvoie l'uid de l'objet révélé.
function openBox(player, bench, rarity, itemId, tier, zone)
	local box = placeBox(player, bench, rarity, itemId, tier, zone)
	assert(box, `colis {itemId} pas posé sur l'établi {bench}`)
	advance(math.max(0, box.ReadyAt - serverTime()) + 0.3)
	local before = #remotes("UnboxReveal")
	fireAs(player, "OpenBox", bench)
	flush()
	local reveals = remotes("UnboxReveal")
	if #reveals == before then
		return nil
	end
	return reveals[#reveals].args[2]
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
	IndexService = serverModule("IndexService")
	MonetizationService = serverModule("MonetizationService")
	DataService = serverModule("DataService")
	DisplayService = serverModule("DisplayService")
	PlotService = serverModule("PlotService")
	UnboxService = serverModule("UnboxService")
	CarryService = serverModule("CarryService")
	PvPService = serverModule("PvPService")
	Features = sharedModule("Config/Features")
	Index = sharedModule("Config/Index")
	Items = sharedModule("Config/Items")
	Rarities = sharedModule("Config/Rarities")
	Tutorial = sharedModule("Config/Tutorial")
	Formulas = sharedModule("Config/Formulas")
	Monetization = sharedModule("Config/Monetization")
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

---------------------------------------------------------------- écrans de Clément (relevé de Studio du 2026-11-08)
-- UI_Index (agents/wave14-studio.md) : Root/WindowShadow, Root/Window (Header/Title, CloseButton/XLabel,
-- CounterPill : BookIcon, Counter ; ZoneReward : ZoneName, ZoneBar/Fill + ZoneCount, Reward/Studs,
-- CashIcon, RewardLabel ; List (ScrollingFrame, UIGridLayout) : Template invisible et Preview_1 à _13 ;
-- ScrollTrack), Root/Tabs (Zone1Tab à Zone6Tab, SecretsTab : TabIcon et TabLabel). Cartes : CardShadow,
-- Clip (Rays et Glow), Icon, Lock (caché), ItemName, RarityBar. Exemples : Preview_1 découverte (Icon
-- blanc, Lock caché, « SODA CAN »), Preview_3 pas découverte (Icon (0,067 ; 0,075 ; 0,094), Lock
-- visible, « ??? ») ; Rays et Glow (0,64 ; 0,64 ; 0,65), RarityBar (0,106 ; 0,122 ; 0,153).
RAYS_SAMPLE = Color3.new(0.64, 0.64, 0.65)
BAR_SAMPLE = Color3.new(0.106, 0.122, 0.153)
FOUND_SAMPLE = Color3.new(1, 1, 1)
SILHOUETTE_SAMPLE = Color3.new(0.067, 0.075, 0.094)
FILL_SAMPLE = UDim2.new(0.69, 0, 1, -4)
TAB_LABELS = { "Mini Mart", "London", "Tokyo", "L.A.", "Paris", "New York" }
function buildIndexGui(playerGui, silhouette)
	local gui = make("ScreenGui", { Name = "UI_Index", Enabled = false, ResetOnSpawn = false })
	local root = make("Frame", { Name = "Root", Size = UDim2.new(1, 0, 1, 0) }, gui)
	make("Frame", { Name = "WindowShadow" }, root)
	local window = make("Frame", { Name = "Window" }, root)
	local header = make("Frame", { Name = "Header" }, window)
	make("TextLabel", { Name = "Title", Text = "Index" }, header)
	local close = make("TextButton", { Name = "CloseButton", Text = "" }, window)
	make("TextLabel", { Name = "XLabel", Text = "X" }, close)
	local pill = make("Frame", { Name = "CounterPill" }, window)
	make("ImageLabel", { Name = "BookIcon" }, pill)
	make("TextLabel", { Name = "Counter", Text = "23 / 74 discovered" }, pill)
	local zoneReward = make("Frame", { Name = "ZoneReward" }, window)
	make("TextLabel", { Name = "ZoneName", Text = "MINI MART" }, zoneReward)
	local bar = make("Frame", { Name = "ZoneBar" }, zoneReward)
	make("Frame", { Name = "Fill", Size = FILL_SAMPLE }, bar)
	make("TextLabel", { Name = "ZoneCount", Text = "9 / 13" }, bar)
	local reward = make("Frame", { Name = "Reward" }, zoneReward)
	make("ImageLabel", { Name = "Studs" }, reward)
	make("ImageLabel", { Name = "CashIcon" }, reward)
	make("TextLabel", { Name = "RewardLabel", Text = "+5% INCOME" }, reward)
	local list = make("ScrollingFrame", { Name = "List", CanvasPosition = Vector2.new(0, 250) }, window)
	make("UIGridLayout", { Name = "UIGridLayout" }, list)
	local function card(name, visible, found, label)
		local frame = make("Frame", { Name = name, Visible = visible }, list)
		make("Frame", { Name = "CardShadow" }, frame)
		local clip = make("Frame", { Name = "Clip" }, frame)
		make("ImageLabel", { Name = "Rays", Image = "rbxassetid://500", ImageColor3 = RAYS_SAMPLE }, clip)
		make("ImageLabel", { Name = "Glow", Image = "rbxassetid://501", ImageColor3 = RAYS_SAMPLE }, clip)
		make("ImageLabel", { Name = "Icon", Image = "rbxassetid://600", ImageColor3 = if found then FOUND_SAMPLE else (silhouette or SILHOUETTE_SAMPLE) }, frame)
		make("ImageLabel", { Name = "Lock", Visible = not found }, frame)
		make("TextLabel", { Name = "ItemName", Text = label }, frame)
		local bar = make("Frame", { Name = "RarityBar", BackgroundColor3 = BAR_SAMPLE }, frame)
		make("TextLabel", { Name = "Rarity", Text = "COMMON" }, bar) -- vu dans Studio le 2026-11-08 (texte de Clément)
		return frame
	end
	card("Template", false, true, "SODA CAN")
	for index = 1, 13 do
		local found = index ~= 3 and index <= 9
		card(`Preview_{index}`, true, found, if found then "SODA CAN" else "???")
	end
	make("Frame", { Name = "ScrollTrack" }, window)
	local tabs = make("Frame", { Name = "Tabs" }, root)
	for index, label in TAB_LABELS do
		local tab = make("TextButton", { Name = `Zone{index}Tab`, Text = "" }, tabs)
		make("ImageLabel", { Name = "TabIcon" }, tab)
		make("TextLabel", { Name = "TabLabel", Text = label }, tab)
	end
	local secrets = make("TextButton", { Name = "SecretsTab", Text = "" }, tabs)
	make("ImageLabel", { Name = "TabIcon" }, secrets)
	make("TextLabel", { Name = "TabLabel", Text = "Secrets" }, secrets)
	gui.Parent = playerGui
	return gui
end
-- UI_HUD : LeftRail avec RobuxShopButton, IndexButton et RebirthButton (TextButtons avec Icon et Label).
function buildHud(playerGui)
	local gui = make("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
	local rail = make("Frame", { Name = "LeftRail" }, gui)
	for _, spec in { { "RobuxShopButton", "SHOP" }, { "IndexButton", "INDEX" }, { "RebirthButton", "REBIRTH" } } do
		local button = make("TextButton", { Name = spec[1], Text = "" }, rail)
		make("ImageLabel", { Name = "Icon" }, button)
		make("TextLabel", { Name = "Label", Text = spec[2] }, button)
	end
	gui.Parent = playerGui
	return gui
end
-- Cartes clonées de l'écran, dans l'ordre (LayoutOrder).
function cardsOf(gui)
	local out = {}
	for _, child in gui.Root.Window.List:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Item_" then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end
function cardOf(gui, itemId)
	for _, card in cardsOf(gui) do
		if string.match(card.Name, "^Item_%d+_(.+)$") == itemId then
			return card
		end
	end
	return nil
end
function textOf(root, name)
	local found = root:FindFirstChild(name, true)
	return if found then found.Text else nil
end
function click(button)
	button.Activated:Fire()
	flush()
end
function sameColor(a, b)
	return a ~= nil and b ~= nil and near(a.R, b.R, 1e-3) and near(a.G, b.G, 1e-3) and near(a.B, b.B, 1e-3)
end
