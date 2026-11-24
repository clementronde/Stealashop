--!nocheck
-- Mise en place commune des scénarios du banc a38 (DEV-100 : boutique Robux). Hub et boutiques
-- PLOT_Shop repris d'a35 (même gabarit : 20 présentoirs, 4 établis, CashPad, Bounds), plus un tapis et
-- un banc par boutique (UsePoint), les présentoirs bonus DisplaySlot_21 à _24 sur les boutiques 1 et 2
-- seulement, et le comptoir taggé RobuxShop.
-- Vrais services : MonetizationService, DataService (avec le faux ProfileStore d'ext38), DisplayService,
-- PlotService, TrainingService, UnboxService, StatsService, ToolService, ShopService ; vrais Loader, Net,
-- Config, Contract, Format, Types. Bouchons : TelemetryService (note chaque LogEconomy dans TELEMETRY),
-- CarryService (colis donnés par le banc), AntiCheatService (a36), TutorialService (seulement son
-- accroche de GetOpenDelay, copiée du vrai, Priority 200, pour le colis du tuto quand
-- TUTORIAL_ACTIVE[joueur]). Client : le vrai RobuxShopController.

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
for _, name in { "MonetizationService", "DataService", "DisplayService", "PlotService", "TrainingService", "UnboxService", "StatsService", "ToolService", "ShopService" } do
	moduleScript(SERVICES, name, `server/Services/{name}.luau`)
end
for _, name in { "TelemetryService", "CarryService", "AntiCheatService", "TutorialService" } do
	moduleScript(SERVICES, name, `stub/{name}`)
end
local clientRoot = folder(folder(StarterPlayer, "StarterPlayerScripts"), "Client")
CONTROLLERS = folder(clientRoot, "Controllers")
moduleScript(CONTROLLERS, "RobuxShopController", "client/Controllers/RobuxShopController.luau")
moduleScript(folder(CONTROLLERS, "UI"), "Motion", "client/Controllers/UI/Motion.luau") -- 2026-11-08 : RobuxShopController passe par UI/Motion (DEV-052)

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

---------------------------------------------------------------- carte : hub et boutiques (gabarit d'a35)
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
makeShop(1, CFrame.new(0, 0, 100), 4) -- présentoirs bonus 21 à 24 posés
makeShop(2, CFrame.new(110, 0, 100), 4)
makeShop(3, CFrame.new(-150, 0, 30), 0) -- sans présentoir bonus (modèle d'aujourd'hui)
makeShop(4, CFrame.new(0, 0, -100), 0)
makeShop(5, CFrame.new(110, 0, -100), 0)
makeShop(6, CFrame.new(-150, 0, -100), 0)

ROBUX_COUNTER = make("Part", { Name = "RobuxCounter", Anchored = true, CFrame = CFrame.new(-80, 2, -80), Size = Vector3.new(6, 4, 2) }, HUB)
addTag(ROBUX_COUNTER, "RobuxShop")

---------------------------------------------------------------- joueurs
local userIds = 0
-- Profil v3 complet préparé pour le faux ProfileStore (clé Player_<UserId>), à modifier par le
-- scénario avant join.
function newProfile()
	return {
		Version = 3,
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
end
function addItem(data, uid, itemId, slot, zone)
	data.Items[uid] = { Id = itemId, Source = "NPC", At = 0, Zone = zone or 1 }
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
function rootOf(player)
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") else nil
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
function cashOf(player)
	local data = DataService.Get(player)
	return if data then data.Cash else nil
end
-- Attend la réponse d'un reçu (au plus `limit` s) et la renvoie.
function settle(entry, limit)
	local waited = 0
	while not entry.done and waited < (limit or 5) do
		advance(0.1)
		waited += 0.1
	end
	return entry.decision
end
-- Pose un colis PNJ sur l'établi `bench` de sa boutique (vrai remote PlaceBox).
function placeBox(player, bench, rarity, itemId, tier, zone)
	local S = refsOfShop(shopOf(player))
	moveTo(player, S["bench" .. bench] + Vector3.new(0, 2, -2))
	advance(0.3)
	CarryService.Give(player, { Kind = "NPCBox", Tier = tier or "Standard", Zone = zone or 1, Rarity = rarity, ItemId = itemId, StoreId = "Store_1", SlotId = "Store_1/01" })
	fireAs(player, "PlaceBox", bench)
	flush()
	local box = dataOf(player).Boxes[tostring(bench)]
	return box
end
function serverTime()
	return Workspace:GetServerTimeNow()
end
-- Texte d'une ligne de journal qui contient `pattern`, ou nil.
function logLine(pattern)
	for _, line in LOG do
		if string.find(line.text, pattern, 1, true) then
			return line.text
		end
	end
	return nil
end

---------------------------------------------------------------- démarrage
function startServer()
	local Loader = sharedModule("Loader")
	Loader.start(SERVICES, "Serveur")
	flush()
	MonetizationService = serverModule("MonetizationService")
	DataService = serverModule("DataService")
	DisplayService = serverModule("DisplayService")
	PlotService = serverModule("PlotService")
	TrainingService = serverModule("TrainingService")
	UnboxService = serverModule("UnboxService")
	StatsService = serverModule("StatsService")
	ToolService = serverModule("ToolService")
	ShopService = serverModule("ShopService")
	CarryService = serverModule("CarryService")
	Monetization = sharedModule("Config/Monetization")
	Features = sharedModule("Config/Features")
	Rarities = sharedModule("Config/Rarities")
	Tutorial = sharedModule("Config/Tutorial")
	Formulas = sharedModule("Config/Formulas")
	Training = sharedModule("Config/Training")
	Items = sharedModule("Config/Items")
end
function startClient(player)
	CLIENT_PLAYER = player
	Players.LocalPlayer = player
	local Loader = requireModule(SHARED:FindFirstChild("Loader"), "client")
	Loader.start(CONTROLLERS, "Client")
	flush()
end

-- Ids du banc (pre.on.luau) : gamepasses 9001 à 9006, produits 8001 à 8008, paliers d'Ouvrir
-- maintenant 8101 à 8104 ; HydraulicGloves et Cash300 restent à 0 (offres désactivées).
PASS_IDS = { DoubleCash = 9001, DoubleTraining = 9002, VIP = 9003, AutoCollect = 9004, FastOpen = 9005, ExtraStands = 9006, HydraulicGloves = 0 }
PRODUCT_IDS = { StarterPack = 8001, Cash10 = 8002, Cash60 = 8003, Cash300 = 0, Revenge = 8005, InstantShutter = 8006, Luck3 = 8007, Shield30 = 8008 }
TIER_IDS = { 8101, 8102, 8103, 8104 }

---------------------------------------------------------------- écrans de Clément (relevé de Studio du 2026-11-08)
-- UI_RobuxShop : Root/Window/List (Template invisible, 6 cartes d'exemple Preview_1 à _6 avec
-- l'attribut IconAsset sur leur Icon), Root/Tabs (4 onglets), Root/Window/CloseButton. Owned caché et
-- BuyRow visible sur le Template ; la carte VIP (Preview_3) montre l'état possédé.
PREVIEW_ICONS = {
	{ "UI_Icon_GP_x2Cash", "rbxassetid://90748953656553", "×2 CASH", "Doubles all your income", "449" },
	{ "UI_Icon_GP_x2Training", "rbxassetid://106315635775683", "×2 TRAINING", "×2 treadmill and bench gains", "299" },
	{ "UI_Icon_GP_VIP", "rbxassetid://71854395817195", "VIP", "+10% income, aura, chat tag", "249" },
	{ "UI_Icon_GP_AutoCollect", "rbxassetid://140209894817694", "AUTO COLLECT", "Cash collects itself, anywhere", "199" },
	{ "UI_Icon_GP_FastOpen", "rbxassetid://95075762072413", "FAST OPEN", "Boxes open 2× faster", "299" },
	{ "UI_Icon_GP_Displays", "rbxassetid://93766507411897", "+4 DISPLAYS", "4 extra display stands", "349" },
}
function buildRobuxShopGui(playerGui)
	local gui = make("ScreenGui", { Name = "UI_RobuxShop", Enabled = false, ResetOnSpawn = false })
	local root = make("Frame", { Name = "Root" }, gui)
	local window = make("Frame", { Name = "Window" }, root)
	local close = make("TextButton", { Name = "CloseButton", Text = "" }, window)
	make("TextLabel", { Name = "XLabel", Text = "X" }, close)
	local list = make("ScrollingFrame", { Name = "List" }, window)
	make("UIGridLayout", { Name = "UIGridLayout" }, list)
	local function card(name, spec, visible, owned)
		local frame = make("Frame", { Name = name, Visible = visible }, list)
		make("Frame", { Name = "CardShadow" }, frame)
		local clip = make("Frame", { Name = "Clip" }, frame)
		make("ImageLabel", { Name = "Rays" }, clip)
		local icon = make("ImageLabel", { Name = "Icon", Image = spec[2] }, frame)
		icon:SetAttribute("IconAsset", spec[1])
		make("TextLabel", { Name = "ItemName", Text = spec[3] }, frame)
		make("TextLabel", { Name = "Effect", Text = spec[4] }, frame)
		local row = make("Frame", { Name = "BuyRow", Visible = not owned }, frame)
		local buy = make("TextButton", { Name = "BuyButton", Text = "" }, row)
		make("ImageLabel", { Name = "Studs" }, buy)
		local content = make("Frame", { Name = "Content" }, buy)
		make("ImageLabel", { Name = "RobuxIcon" }, content)
		make("TextLabel", { Name = "Price", Text = spec[5] }, content)
		local ownedFrame = make("Frame", { Name = "Owned", Visible = owned }, frame)
		local ownedContent = make("Frame", { Name = "Content" }, ownedFrame)
		make("ImageLabel", { Name = "CheckIcon" }, ownedContent)
		make("TextLabel", { Name = "OwnedLabel", Text = "OWNED" }, ownedContent)
		return frame
	end
	card("Template", PREVIEW_ICONS[1], false, false)
	for index, spec in PREVIEW_ICONS do
		card(`Preview_{index}`, spec, true, index == 3)
	end
	local tabs = make("Frame", { Name = "Tabs" }, root)
	for _, name in { "OffersTab", "GamepassesTab", "CashTab", "BoostsTab" } do
		local tab = make("TextButton", { Name = name, Text = "" }, tabs)
		make("ImageLabel", { Name = "TabIcon" }, tab)
		make("TextLabel", { Name = "TabLabel", Text = string.upper(string.gsub(name, "Tab$", "")) }, tab)
	end
	gui.Parent = playerGui
	return gui
end
-- UI_HUD : seulement LeftRail/RobuxShopButton (TextButton avec Icon et Label), relevé de Studio.
function buildHud(playerGui)
	local gui = make("ScreenGui", { Name = "UI_HUD", ResetOnSpawn = false })
	local rail = make("Frame", { Name = "LeftRail" }, gui)
	local button = make("TextButton", { Name = "RobuxShopButton", Text = "" }, rail)
	make("ImageLabel", { Name = "Icon" }, button)
	make("TextLabel", { Name = "Label", Text = "SHOP" }, button)
	gui.Parent = playerGui
	return gui
end
-- Cartes clonées de l'écran, dans l'ordre (LayoutOrder).
function cardsOf(gui)
	local list = gui.Root.Window.List
	local out = {}
	for _, child in list:GetChildren() do
		if string.sub(child.Name, 1, 6) == "Offer_" then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return out
end
function cardNamed(gui, key)
	return gui.Root.Window.List:FindFirstChild("Offer_" .. key)
end
function textOf(card, name)
	local found = card:FindFirstChild(name, true)
	return if found then found.Text else nil
end
function click(button)
	button.Activated:Fire()
	flush()
end
