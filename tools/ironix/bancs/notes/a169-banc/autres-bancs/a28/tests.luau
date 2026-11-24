--!nocheck
-- Banc a28 (vague 9, DEV-046) : tutoriel de départ. Vrais : Config, Contract, Net, Format, Types,
-- TutorialService et TutorialController. Faux (tables pilotées par les scénarios, rangées dans le
-- cache des modules à la place des vrais) : DataService, PlotService, StoreHeistService (accroche
-- SetContentOverride appliquée comme le vrai à la prise), GuardService (vitesse du vigile lue comme
-- chaseSpeed), UnboxService (pose et ouverture qui appellent GetOpenDelay et GetLuck comme le vrai),
-- WindowService, CarryService, DisplayService, NightCycleService, ToolService.
-- Fausse carte : relevé Studio du 2026-11-07 (wave9-studio.md) : vitrines de la zone 1 en
-- (65, 6.15, ±30.75), arches ZoneGate à x = 30 (zone 1), 100 (zone 2), 190 (zone 3), mur de nuit
-- à x ≈ 27 (couloir = x > 27), zone safe avant x = 25.

---------------------------------------------------------------- arbre et modules
SharedFolder = folder(ReplicatedStorage, "Shared")
for key in SOURCES do
	local rel = string.match(key, "^shared/(.+)%.luau$")
	if rel then
		local parent = SharedFolder
		local segments = string.split(rel, "/")
		for i = 1, #segments - 1 do
			parent = parent:FindFirstChild(segments[i]) or folder(parent, segments[i])
		end
		moduleScript(parent, segments[#segments], key)
	end
end
ServicesFolder = folder(folder(ServerScriptService, "Server"), "Services")
TutorialModule = moduleScript(ServicesFolder, "TutorialService", "server/Services/TutorialService.luau")
ControllerModule = moduleScript(folder(folder(StarterPlayerScripts, "Client"), "Controllers"), "TutorialController", "client/Controllers/TutorialController.luau")

Tutorial = requireModule(SharedFolder.Config.Tutorial, "server")
Items = requireModule(SharedFolder.Config.Items, "server")
Tools = requireModule(SharedFolder.Config.Tools, "server")
Zones = requireModule(SharedFolder.Config.Zones, "server")
Rarities = requireModule(SharedFolder.Config.Rarities, "server")
Cosmetics = requireModule(SharedFolder.Config.Cosmetics, "server")

---------------------------------------------------------------- faux services
PROFILES = {}
function DEEPCOPY(t)
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in t do
		copy[k] = DEEPCOPY(v)
	end
	return copy
end
-- Profil neuf (modèle v2 de DataService, forme 9.5).
function newProfile()
	return {
		Version = 2,
		Cash = 0,
		Stats = { Speed = 0, Strength = 0 },
		Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 },
		Tools = { Owned = { "Fists" }, Equipped = "Fists" },
		Cosmetics = { Auras = {}, Trails = {} },
		Items = {},
		Display = {},
		Vault = {},
		Boxes = {},
		Tutorial = { Step = 0, Done = false },
		Lifetime = { Heists = 0, Steals = 0, Defenses = 0, PlaySeconds = 0 },
		Purchases = {},
	}
end
FakeData = {
	Get = function(player)
		return PROFILES[player]
	end,
}

PLOT_OF = {}
PLOT_LISTENERS = {}
FakePlot = {
	GetPlot = function(player)
		return PLOT_OF[player]
	end,
	OnPlotAssigned = function(listener)
		table.insert(PLOT_LISTENERS, listener)
		for player, plot in PLOT_OF do
			taskLib.spawn(listener, player, plot)
		end
		return function() end
	end,
}
function assignPlot(player, plot)
	PLOT_OF[player] = plot
	for _, listener in table.clone(PLOT_LISTENERS) do
		taskLib.spawn(listener, player, plot)
	end
end

OPEN_STORES = {}
STORES = {}
CONTENT_OVERRIDE = nil
FakeHeist = {
	SetContentOverride = function(fn)
		CONTENT_OVERRIDE = fn
	end,
	GetStoreModel = function(id)
		return STORES[id]
	end,
	GetStoreId = function(model)
		if STORES[model.Name] == model then
			return model.Name
		end
		return nil
	end,
	IsOpen = function(id)
		return OPEN_STORES[id] == true
	end,
}
CARRY = {}
CARRY_STARTED, CARRY_ENDED = {}, {}
FakeCarry = {
	GetPayload = function(player)
		return CARRY[player]
	end,
	OnCarryStarted = function(listener)
		table.insert(CARRY_STARTED, listener)
		return function() end
	end,
	OnCarryEnded = function(listener)
		table.insert(CARRY_ENDED, listener)
		return function() end
	end,
}
function carryStart(player, payload)
	CARRY[player] = payload
	for _, listener in table.clone(CARRY_STARTED) do
		taskLib.spawn(listener, player, payload)
	end
end
function carryEnd(player, result, reason)
	local payload = CARRY[player]
	CARRY[player] = nil
	for _, listener in table.clone(CARRY_ENDED) do
		taskLib.spawn(listener, player, payload, result, reason)
	end
end
-- Prise d'un colis du rayon, comme StoreHeistService.grant : accroche du tuto, puis StartCarry.
function grab(player, storeName, tier, itemId)
	local store = STORES[storeName]
	local zone = store:GetAttribute("Zone")
	local drawn = { StoreId = storeName, SlotId = storeName .. "/01", Zone = zone, Tier = tier, Rarity = Items.ById[itemId].Rarity, ItemId = itemId }
	local outTier, outItem = tier, itemId
	if CONTENT_OVERRIDE then
		local ok, result = pcall(CONTENT_OVERRIDE, player, table.freeze(table.clone(drawn)))
		if ok and type(result) == "table" then
			outTier = result.Tier or tier
			outItem = result.ItemId or itemId
		end
	end
	-- a169 (vague 52) : l'objet sorti du colis du rayon, porté (NPCItem), plus de colis porté.
	local payload = { Kind = "NPCItem", Tier = outTier, Zone = zone, Rarity = Items.ById[outItem].Rarity, ItemId = outItem, StoreId = storeName, SlotId = drawn.SlotId }
	carryStart(player, payload)
	return payload
end

FakeGuard = {}
function FakeGuard.GetSpeedOverride(_player, _zone)
	return nil
end
-- Vitesse du vigile qui apparaît pour ce joueur (règle de GuardService.chaseSpeed).
function guardSpeed(player, zone)
	local ok, value = pcall(FakeGuard.GetSpeedOverride, player, zone)
	if ok and type(value) == "number" and value > 0 then
		return value
	end
	return Zones[zone].GuardSpeed
end

FakeUnbox = {}
BOX_PLACED, BOX_OPENED, BOX_STOWED = {}, {}, {}
-- a51 (L-089) : point du monde de chaque colis posé (GetBoxPosition) et uid du colis posé « n° n » (le
-- présentoir n sert de point au sol dans ce faux), par joueur.
BOX_POS = {}
BENCH_UID = {}
function FakeUnbox.GetOpenDelay(_player, box)
	return Rarities.ById[box.Rarity].OpenDelay
end
function FakeUnbox.GetLuck(_player, _box)
	return 1
end
function FakeUnbox.OnBoxPlaced(listener)
	table.insert(BOX_PLACED, listener)
	return function() end
end
function FakeUnbox.OnBoxOpened(listener)
	table.insert(BOX_OPENED, listener)
	return function() end
end
function FakeUnbox.OnBoxStowed(listener)
	table.insert(BOX_STOWED, listener)
	return function() end
end
function FakeUnbox.GetBoxPosition(_player, uid)
	return BOX_POS[uid]
end
-- a169 (vague 52, lot C) : plus de colis rangé, posé ni ouvert en base. Les mêmes fonctions des scénarios
-- jouent l'OBJET : stowBox = UnboxService.stowItem (objet sous antivol dans Items, OnItemStowed),
-- placeBox = placeFloorItem (Spot, UnlockAt par GetAntiTheftDelay, OnItemPlaced), openBox = takeFloorItem
-- (« Take » : l'objet redevient libre, ici dans l'inventaire, mains prises). GetFloorItem rend le pied de
-- l'objet posé (BOX_POS). Les écouteurs ITEM_STOWED et ITEM_PLACED sont déclarés plus bas (ajout a107).
function FakeUnbox.GetFloorItem(_player, uid)
	local at = BOX_POS[uid]
	return if at then { Position = at } else nil
end
BOX_UID = 0
function stowBox(player)
	local payload = CARRY[player]
	assert(payload, "stowBox : rien sur la tête")
	local data = PROFILES[player]
	carryEnd(player, "Consumed", "Consumed")
	BOX_UID += 1
	local uid = "item-" .. BOX_UID
	data.Items[uid] = { Id = payload.ItemId, Source = "NPC", At = 0, Zone = payload.Zone, AntiTheft = true }
	data.Lifetime.Heists += 1
	for _, listener in table.clone(ITEM_STOWED) do
		taskLib.spawn(listener, player, uid, payload.ItemId)
	end
	return uid
end
function placeBox(player, bench)
	local uid = nil
	if CARRY[player] then
		uid = stowBox(player)
	else
		for key, entry in PROFILES[player].Items do
			if entry.AntiTheft and entry.Spot == nil then
				uid = key
			end
		end
	end
	assert(uid, "placeBox : aucun objet sous antivol dans l'inventaire")
	local data = PROFILES[player]
	local entry = data.Items[uid]
	local ok, delay = pcall(FakeUnbox.GetAntiTheftDelay, player, entry.Id)
	if not ok or type(delay) ~= "number" then
		delay = 20
	end
	entry.UnlockAt = Workspace:GetServerTimeNow() + delay
	entry.Spot = { X = bench, Y = 0, Z = 0 }
	local plot = PLOT_OF[player]
	local slot = plot and plot:FindFirstChild(string.format("DisplaySlot_%02d", bench), true)
	BOX_POS[uid] = if slot then slot.WorldPosition else nil
	BENCH_UID[player] = BENCH_UID[player] or {}
	BENCH_UID[player][bench] = uid
	for _, listener in table.clone(ITEM_PLACED) do
		taskLib.spawn(listener, player, uid, entry.Id)
	end
	return delay
end
UID = 0
-- Reprise « Take » : renvoie (1, uid de l'objet) ; le 1 tient la place de l'ancienne chance d'ouverture.
function openBox(player, bench)
	local data = PROFILES[player]
	local uid = (BENCH_UID[player] or {})[bench]
	local entry = uid and data.Items[uid]
	assert(entry and entry.AntiTheft, "openBox : aucun objet sous antivol posé n° " .. tostring(bench))
	entry.AntiTheft = nil
	entry.UnlockAt = nil
	entry.Spot = nil
	BOX_POS[uid] = nil
	return 1, uid
end
-- Ouverture, puis l'objet posé depuis l'inventaire sur le présentoir n (PlaceItem).
function openAndDisplay(player, bench)
	local luck, uid = openBox(player, bench)
	PROFILES[player].Display[tostring(bench)] = uid
	step(0.6)
	return luck, uid
end

BROKEN = {}
WINDOW_BROKEN = {}
FakeWindow = {
	OnBroken = function(listener)
		table.insert(WINDOW_BROKEN, listener)
		return function() end
	end,
	IsBroken = function(id)
		return BROKEN[id] == true
	end,
}
-- Casse : l'écouteur de StoreHeistService (abonné avant celui du tuto) ouvre le magasin.
function breakWindow(storeName, breaker)
	BROKEN[storeName] = true
	OPEN_STORES[storeName] = true
	local info = table.freeze({ WindowId = storeName, Kind = "NPC", Model = STORES[storeName], Breaker = breaker, ImpactPoint = Vector3.zero })
	for _, listener in table.clone(WINDOW_BROKEN) do
		taskLib.spawn(listener, info)
	end
end
function closeStore(storeName)
	OPEN_STORES[storeName] = nil
end
function rebuildWindow(storeName)
	BROKEN[storeName] = nil
end

CASH_OUT = {}
FakeDisplay = {
	-- a59 (L-091) : plaque à montrer, ici la CollectPad_01 de sa parcelle (le vrai DisplayService choisit
	-- celle qui porte le plus d'argent).
	GetCollectTarget = function(player)
		local plot = FakePlot.GetPlot(player)
		local pad = plot and plot:FindFirstChild("CollectPad_01", true)
		return pad and pad.Position
	end,
	OnCashOut = function(listener)
		table.insert(CASH_OUT, listener)
		return function() end
	end,
}
function cashOut(player, amount, source)
	PROFILES[player].Cash += amount
	for _, listener in table.clone(CASH_OUT) do
		taskLib.spawn(listener, player, amount, source)
	end
end

NIGHT_PHASE = "Day"
SHIELD = {}
PHASE_LISTENERS = {}
FakeNight = {
	GetPhase = function()
		return NIGHT_PHASE
	end,
	IsShielded = function(player)
		local value = SHIELD[player]
		if value == nil then
			return true
		end
		return value
	end,
	IsInCorridor = function(position)
		return position.X > 27 -- mur de nuit à x ≈ 27 (relevé Studio)
	end,
	OnPhaseChanged = function(listener)
		table.insert(PHASE_LISTENERS, listener)
		return function() end
	end,
}
function setPhase(phase)
	local previous = NIGHT_PHASE
	NIGHT_PHASE = phase
	for _, listener in table.clone(PHASE_LISTENERS) do
		taskLib.spawn(listener, phase, previous)
	end
end

FakeTool = {
	-- Comme ToolService : le Tool de casse (attribut ToolId) est dans le personnage.
	IsHoldingTool = function(player)
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
	end,
}

-- a107 (2026-11-12, vague 31, L-112) : accroches que TutorialService pose quand Features.ShelfOpen = true
-- (ajout pur ; ce banc teste l'ancien déroulé, un colis porté, qui reste le même avec l'interrupteur).
LUCK_OVERRIDE = nil
function FakeHeist.SetLuckOverride(fn)
	LUCK_OVERRIDE = fn
end
ITEM_STOWED, ITEM_PLACED = {}, {}
function FakeUnbox.GetAntiTheftDelay(_player, itemId)
	return 20
end
function FakeUnbox.OnItemStowed(listener)
	table.insert(ITEM_STOWED, listener)
	return function() end
end
function FakeUnbox.OnItemPlaced(listener)
	table.insert(ITEM_PLACED, listener)
	return function() end
end

for name, impl in {
	DataService = FakeData,
	PlotService = FakePlot,
	StoreHeistService = FakeHeist,
	GuardService = FakeGuard,
	UnboxService = FakeUnbox,
	WindowService = FakeWindow,
	CarryService = FakeCarry,
	DisplayService = FakeDisplay,
	NightCycleService = FakeNight,
	ToolService = FakeTool,
} do
	local m = moduleScript(ServicesFolder, name, "fake/" .. name)
	CACHES.server[m] = impl
end

---------------------------------------------------------------- fausse carte
MAP = folder(Workspace, "Map")
function part(name, position, size, parent, extra)
	local p = new("Part", { Name = name, CFrame = CFrame.new(position), Size = size, Anchored = true })
	for k, v in extra or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end
function makeStore(name, zone, x, side)
	local model = new("Model", { Name = name })
	part("Window", Vector3.new(x, 6.15, side * 30.75), Vector3.new(18, 10.5, 0.3), model)
	part("Bounds", Vector3.new(x, 7.65, side * 66), Vector3.new(57, 14.4, 69), model)
	model.WorldPivot = CFrame.new(x, 0, side * 50)
	model:SetAttribute("Zone", zone)
	addTag(model, "NPCStore")
	model.Parent = MAP
	STORES[name] = model
	return model
end
makeStore("STORE_Z1_Superette", 1, 65, 1)
makeStore("STORE_Z1_Kiosque", 1, 65, -1)
makeStore("STORE_Z2_MagasinDeJouets", 2, 140, 1)
SUPERETTE_WINDOW = Vector3.new(65, 6.15, 30.75)
KIOSQUE_WINDOW = Vector3.new(65, 6.15, -30.75)
for _, gate in { { 1, 30 }, { 2, 100 }, { 3, 190 } } do
	local model = new("Model", { Name = `ZoneGate_{gate[1]}` })
	part("Arch", Vector3.new(gate[2], 18, 0), Vector3.new(2, 36, 69), model)
	model.WorldPivot = CFrame.new(gate[2], 0, 0)
	model:SetAttribute("Zone", gate[1])
	addTag(model, "ZoneGate")
	model.Parent = MAP
end
GATE_2 = Vector3.new(100, 0, 0)
addTag(part("SafeZone", Vector3.new(-90, 20, 0), Vector3.new(230, 40, 240), MAP, { CanCollide = false, Transparency = 1 }), "SafeZone")
-- Un comptoir livré mais pas posé (inbox) : taggé en premier, il ne doit jamais servir de cible.
INBOX = folder(Workspace, "_INBOX_CLEMENT")
addTag(part("WeaponCounter_V2", Vector3.new(500, 2, 500), Vector3.new(8, 4, 2), INBOX), "WeaponShop")
WEAPON_SHOP = Vector3.new(-20, 2, -40)
AURA_SHOP = Vector3.new(-20, 2, 40)
addTag(part("WeaponCounter", WEAPON_SHOP, Vector3.new(8, 4, 2), MAP), "WeaponShop")
addTag(part("AuraCounter", AURA_SHOP, Vector3.new(8, 4, 2), MAP), "AuraShop")

-- Parcelle au contrat 10.4 (ce que lit le tuto) ; renvoie aussi ses points attendus.
function makePlot(index, x, z)
	local plot = new("Model", { Name = `PLOT_{index}` })
	local floor = part("Floor", Vector3.new(x, 0.5, z), Vector3.new(64, 1, 80), plot)
	for i = 1, 4 do
		local bench = new("Attachment", { Name = string.format("UnboxBench_%02d", i) }, floor)
		bench.Position = Vector3.new(-24 + 4 * i, 3, -20)
		local slot = new("Attachment", { Name = string.format("DisplaySlot_%02d", i) }, floor)
		slot.Position = Vector3.new(-24 + 4 * i, 3, 20)
	end
	part("CollectPad_01", Vector3.new(x + 20, 1.1, z), Vector3.new(4.4, 0.12, 2.6), plot) -- a59 (L-091) : plus de CashPad
	local treadmill = new("Model", { Name = "Treadmill" }, plot)
	new("Attachment", { Name = "UsePoint" }, part("Belt", Vector3.new(x - 20, 1.5, z + 30), Vector3.new(3, 1, 6), treadmill)).Position = Vector3.new(0, 1, 0)
	local bench = new("Model", { Name = "Bench" }, plot)
	new("Attachment", { Name = "UsePoint" }, part("Seat", Vector3.new(x - 10, 1.5, z + 30), Vector3.new(3, 1, 6), bench)).Position = Vector3.new(0, 1, 0)
	new("Attachment", { Name = "SpawnPoint" }, floor).Position = Vector3.new(0, 3, 0)
	addTag(plot, "PlayerPlot")
	plot.Parent = MAP
	return plot, {
		bench1 = Vector3.new(x - 20, 3.5, z - 20),
		bench2 = Vector3.new(x - 16, 3.5, z - 20),
		slot1 = Vector3.new(x - 20, 3.5, z + 20),
		cashPad = Vector3.new(x + 20, 1.1, z),
		treadmill = Vector3.new(x - 20, 2.5, z + 30),
		bench = Vector3.new(x - 10, 2.5, z + 30),
		spawn = Vector3.new(x, 3.5, z),
	}
end

function makePlayer(name, userId, position)
	local player = new("Player", { Name = name, UserId = userId }, Players)
	local character = new("Model", { Name = name })
	part("HumanoidRootPart", position, Vector3.new(2, 2, 1), character)
	new("Humanoid", {}, character)
	character.Parent = Workspace
	player.Character = character
	return player
end
function moveTo(player, position)
	player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
end
function holdTool(player, on)
	local character = player.Character
	local tool = character:FindFirstChild("Fists")
	if on and tool == nil then
		local t = new("Tool", { Name = "Fists" })
		t:SetAttribute("ToolId", "Fists")
		t.Parent = character
	elseif not on and tool then
		tool:Destroy()
	end
end
-- Départ d'un joueur : personnage retiré, portage raté, profil libéré, PlayerRemoving.
function leave(player, releaseFirst)
	local saved = PROFILES[player]
	if releaseFirst then
		PROFILES[player] = nil
	end
	local character = player.Character
	player.Character = nil
	if character then
		character:Destroy()
	end
	if CARRY[player] then
		carryEnd(player, "Failed", "Left")
	end
	PROFILES[player] = nil
	Players.PlayerRemoving:Fire(player)
	player.Parent = nil
	return DEEPCOPY(saved)
end

---------------------------------------------------------------- remotes et relevés
function fireAsClient(player, remoteName, ...)
	REMOTES[remoteName].OnServerEvent:Fire(player, ...)
end
function stepsTo(player)
	local out = {}
	for _, e in REMOTE_LOG do
		if e.name == "TutorialStep" and e.to == player then
			table.insert(out, e.args)
		end
	end
	return out
end
function lastStep(player)
	local list = stepsTo(player)
	return list[#list]
end
-- Envois du funnel pour ce joueur, comptés par UserId : un joueur qui revient est un nouvel objet
-- Player, mais pour Roblox c'est le même joueur.
function funnelOf(player)
	local out = {}
	for _, e in FUNNEL_LOG do
		if e.player.UserId == player.UserId then
			table.insert(out, e.step)
		end
	end
	return out
end
function funnelCount(player, index)
	local n = 0
	for _, s in funnelOf(player) do
		if s == index then
			n += 1
		end
	end
	return n
end
function sameVec(a, b)
	return a ~= nil and b ~= nil and (a - b).Magnitude < 0.01
end
-- Le dernier TutorialStep envoyé au joueur est (étape, indice, cible).
function stateOk(player, stepIndex, hint, target)
	local last = lastStep(player)
	if last == nil or last[1] ~= stepIndex or last[2] ~= hint then
		return false
	end
	if target == nil then
		return last[3] == nil
	end
	return sameVec(last[3], target)
end
function describe(player)
	local last = lastStep(player)
	if last == nil then
		return "(rien reçu)"
	end
	return `(reçu : {tostring(last[1])}, {tostring(last[2])}, {tostring(last[3])})`
end
function words(text)
	local n = 0
	for _ in string.gmatch(text, "%S+") do
		n += 1
	end
	return n
end

---------------------------------------------------------------- démarrage
local TutorialService = requireModule(TutorialModule, "server")
REMOTES = ReplicatedStorage:FindFirstChild("Remotes")
TutorialService.Init()

ALICE = makePlayer("Alice", 1, Vector3.new(-60, 3, -60))
PLAYER_GUI = new("PlayerGui", { Name = "PlayerGui" }, ALICE)
Players.LocalPlayer = ALICE
CLIENT_PLAYER = ALICE
Workspace.CurrentCamera = new("Camera", { Name = "Camera" }, Workspace)
Controller = requireModule(ControllerModule, "client")
taskLib.spawn(Controller.Start)

print("== A. Config/Tutorial")
do
	check(Tutorial.Enabled == true, "Enabled = true")
	local stepsOk = true
	for _, s in Tutorial.Steps do
		if s.Bubble and words(s.Bubble) > Tutorial.BubbleMaxWords then
			stepsOk = false
		end
	end
	check(stepsOk, "bulles des étapes : 8 mots au plus")
	local hintsOk = true
	-- a169 (vague 52) : WaitBox et OpenBox retirés ; WaitUnlock, TakeUnlocked, DisplayUnlocked à leur place.
	for _, key in { "EquipFists", "WindowRebuilding", "WaitUnlock", "TakeUnlocked", "DisplayUnlocked", "CollectCash", "NightClosed", "Night", "ShieldEnd" } do
		local text = Tutorial.Hints[key]
		if text == nil or (key ~= "ShieldEnd" and words(text) > Tutorial.BubbleMaxWords) then
			hintsOk = false
		end
	end
	check(hintsOk, "les 9 indices existent, 8 mots au plus (sauf ShieldEnd, texte du doc)")
	check(Tutorial.Hints.PlaceBox == nil and Tutorial.Hints.WaitBox == nil and Tutorial.Hints.OpenBox == nil and Tutorial.OpenDelay == nil and Tutorial.GuaranteedRarity == nil, "a169 : indices PlaceBox, WaitBox, OpenBox, OpenDelay et GuaranteedRarity retirés")
	check(Tutorial.Hints.Night == Tutorial.NightBubble and Tutorial.Hints.ShieldEnd == Tutorial.ShieldEndMessage, "indices Night et ShieldEnd = textes du doc")
	check(Tutorial.TrainDuration == 30 and Tutorial.GoalZone == 2 and Tutorial.SkipFromStep == 5 and Tutorial.AntiTheftDelay == 5 and Tutorial.GuardSpeed == 12, "valeurs du doc : 30 s, zone 2, Passer dès l'étape 5, 5 s (antivol), vigile à 12")
	local wrench = Tools.ById[Tutorial.ToolToBuy]
	check(wrench ~= nil and wrench.Price == 300, "ToolToBuy = Wrench, 300 $ (7.2)")
	local cheapest = math.huge
	for _, aura in Cosmetics.Auras do
		cheapest = math.min(cheapest, aura.Price)
	end
	check(cheapest == 500, "première aura à 500 $ (7.4)")
	local item = Items.ById[Tutorial.GuaranteedItemId]
	check(item ~= nil and item.TutorialOnly and item.Zone == 1 and item.Rarity == "Rare" and Tutorial.FirstBoxTier == "Premium", "Pot de nouilles : TutorialOnly, zone 1, Rare ; colis Premium")
	check(Zones[1].StoreIds[1] == Tutorial.TargetStoreId and Tutorial.TutorialZone == 1, "TargetStoreId = Superette (Zones[1].StoreIds[1]), zone 1")
	-- a121 (vague 36) : 3 étapes de plus à la fin (vol sur la boutique du bot) ; les 10 premières ne changent pas.
	-- a126 (vague 38) : étape 14 EscapeBot ajoutée à la fin.
	check(#Tutorial.FunnelSteps == 14 and #Tutorial.Steps == 14 and Tutorial.Steps[10].Id == "ShieldEnd" and Tutorial.Steps[11].Id == "GoToBotShop" and Tutorial.Steps[13].Id == "BringStolenHome" and Tutorial.Steps[14].Id == "EscapeBot", "14 étapes et 14 étapes de funnel (les 13 d'avant inchangées)")
	local badNames = {}
	for i, name in Tutorial.FunnelSteps do
		if string.find(name, "[,\"']") then
			table.insert(badNames, i .. " « " .. name .. " »")
		end
	end
	check(#badNames == 0, "noms du funnel sans virgule, guillemet ni apostrophe (refusés par Roblox) " .. table.concat(badNames, ", "))
	check(Tutorial.ArrowAsset == "FX_Tutorial_Arrow" and Tutorial.MarkerAsset == "FX_Tutorial_Marker", "noms proposés de la flèche : FX_Tutorial_Arrow, FX_Tutorial_Marker")
end

print("== B. Déroulé complet des 10 étapes (Alice, nouvelle joueuse)")
PLOT_A, A = makePlot(1, -60, -60)
PROFILES[ALICE] = newProfile()
SHIELD[ALICE] = true
do
	local data = PROFILES[ALICE]
	assignPlot(ALICE, PLOT_A)
	check(data.Tutorial.Step == 1 and data.Tutorial.Done == false, "arrivée sur la parcelle : étape 1 sauvegardée")
	check(stateOk(ALICE, 1, nil, SUPERETTE_WINDOW), "TutorialStep(1) avec la flèche vers la vitrine de la Supérette " .. describe(ALICE))
	check(ALICE:GetAttribute("TutorialStep") == 1 and ALICE:GetAttribute("TutorialHint") == nil, "attributs du Player pour Studio : TutorialStep = 1, pas de TutorialHint")
	check(funnelCount(ALICE, 1) == 1 and #funnelOf(ALICE) == 1, "funnel 1 « Arrivée sur sa parcelle »")
	check(logHas("funnel Alice : étape 1", "PRINT", "server"), "sortie de Studio : ligne du funnel")
	step(0.3)
	local st = Controller.GetState()
	check(st.Shown and st.Text == "Smash the Mini Mart window!" and st.Fallback, "client : bulle V0 « Smash the Mini Mart window! »")
	local fallbackGui = PLAYER_GUI:FindFirstChild("TutorialV0")
	local label = fallbackGui and fallbackGui:FindFirstChild("Label", true)
	local skip = fallbackGui and fallbackGui:FindFirstChild("NextButton", true)
	check(fallbackGui ~= nil and fallbackGui.Enabled and fallbackGui:FindFirstChild("Bubble") ~= nil and label ~= nil and label.Text == st.Text, "repli V0 : TutorialV0 avec Bubble, Label et NextButton")
	check(skip ~= nil and skip.Visible == false and skip.Text == "Skip", "bouton Passer (« Skip ») caché avant l'étape 5")
	local minSize = skip and skip:FindFirstChildOfClass("UISizeConstraint")
	check(minSize ~= nil and minSize.MinSize.Y >= 44, "bouton Passer : 44 px de haut au moins")
	local arrowFolder = Workspace.CurrentCamera:FindFirstChild("TutorialArrow")
	local beam = arrowFolder and arrowFolder:FindFirstChild("Beam", true)
	check(st.Arrow and beam ~= nil and beam.Enabled and sameVec(beam.Attachment1.Position, SUPERETTE_WINDOW), "flèche V0 (Beam) vers la vitrine, dans la caméra")
	check(sameVec(beam.Attachment0.Position, Vector3.new(-60, 3 - (2 + 1 - 0.2), -60)), "le Beam part des pieds du joueur")
	local marker = arrowFolder and arrowFolder:FindFirstChild("Marker", true)
	check(marker ~= nil and marker.CanCollide == false and marker.CanQuery == false, "repère V0 sans collision ni requête")

	moveTo(ALICE, Vector3.new(65, 3, 26))
	fireAsClient(ALICE, "HitWindow", "STORE_Z1_Superette")
	check(data.Tutorial.Step == 1, "coup sans outil en main : pas compté")
	step(0.3)
	check(Controller.GetState().Text == Tutorial.Hints.EquipFists, "client : « Equip your Fists, then hit! » près de la vitrine sans outil")
	check(Controller.GetState().Arrow == false, "flèche cachée à moins de 6 studs de la cible")
	holdTool(ALICE, true)
	moveTo(ALICE, Vector3.new(65, 3, 10))
	fireAsClient(ALICE, "HitWindow", "STORE_Z1_Superette")
	check(data.Tutorial.Step == 1, "coup à 20 studs de la vitre : pas compté")
	moveTo(ALICE, Vector3.new(65, 3, 26))
	step(0.3) -- a134 : 5 coups par seconde en débit régulier (Net) : deux coups au même instant, un seul passe
	fireAsClient(ALICE, "HitWindow", "STORE_Z2_MagasinDeJouets")
	check(data.Tutorial.Step == 1, "coup visé sur la vitrine de la zone 2 (loin) : pas compté")
	step(0.3)
	fireAsClient(ALICE, "HitWindow", "STORE_Z1_Superette")
	check(data.Tutorial.Step == 2, "premier coup sur la vitrine : étape 2")
	check(stateOk(ALICE, 2, nil, SUPERETTE_WINDOW), "TutorialStep(2) " .. describe(ALICE))
	check(funnelCount(ALICE, 2) == 1, "funnel 2 « Premier coup sur une vitrine »")
	step(0.3)
	check(Controller.GetState().Text == "Hit the glass again and again!", "client : bulle de l'étape 2")

	breakWindow("STORE_Z1_Superette", ALICE)
	check(data.Tutorial.Step == 3 and stateOk(ALICE, 3, nil, SUPERETTE_WINDOW), "vitrine cassée : étape 3 " .. describe(ALICE))
	check(funnelCount(ALICE, 3) == 1, "funnel 3 « Première vitrine cassée »")

	holdTool(ALICE, false)
	moveTo(ALICE, Vector3.new(65, 3, 40))
	local payload = grab(ALICE, "STORE_Z1_Superette", "Standard", "Z1_Banane")
	check(payload.Tier == "Premium" and payload.ItemId == "Z1_PotDeNouilles" and payload.Rarity == "Rare", "1er colis garanti : Premium, Pot de nouilles (Rare)")
	check(data.Tutorial.Step == 4 and stateOk(ALICE, 4, nil, A.spawn), "colis sur la tête : étape 4, flèche vers sa boutique (SpawnPoint, L-089) " .. describe(ALICE))
	check(guardSpeed(ALICE, 1) == 12, "vigile lent du tuto : 12")
	check(funnelCount(ALICE, 4) == 1, "funnel 4 « Premier colis volé »")

	moveTo(ALICE, Vector3.new(40, 3, 0))
	step(0.6)
	check(funnelCount(ALICE, 5) == 0, "encore dans le couloir : pas de funnel 5")
	moveTo(ALICE, Vector3.new(0, 3, 0))
	step(0.6)
	check(funnelCount(ALICE, 5) == 1, "funnel 5 « Arrivée en zone safe avec le colis »")
	-- a51 (L-089) : le colis rentre dans l'inventaire (UnboxService.stow) : toujours l'étape 4, indice PlaceBox.
	stowBox(ALICE)
	step(0.6)
	check(data.Tutorial.Step == 4 and stateOk(ALICE, 4, "PlaceFloorItem", A.spawn), "objet sous antivol dans l'inventaire : étape 4, indice PlaceFloorItem, flèche vers sa boutique " .. describe(ALICE))
	check(funnelCount(ALICE, 5) == 1, "funnel 5 pas renvoyé au rangement")
	-- Audit 2026-11-10 : colis du tuto rangé, pas posé : un 2e colis de zone 1 n'est plus garanti.
	check(CONTENT_OVERRIDE(ALICE, { Zone = 1, Tier = "Standard", ItemId = "Z1_Banane" }) == nil, "étape 4, colis du tuto rangé : le colis suivant de zone 1 n'est plus garanti (plus de Pot de nouilles à volonté)")
	check(#string.split(Tutorial.Hints.PlaceFloorItem, " ") <= Tutorial.BubbleMaxWords and #string.split(Tutorial.Hints.PlaceItem, " ") <= Tutorial.BubbleMaxWords and #string.split(Tutorial.Steps[4].Bubble, " ") <= Tutorial.BubbleMaxWords, "indices PlaceFloorItem, PlaceItem et bulle de l'étape 4 : 8 mots au plus")

	moveTo(ALICE, A.slot1 + Vector3.new(0, 0, 3))
	local delay = placeBox(ALICE, 1)
	check(delay == 5, "antivol de l'objet du tuto : 5 s (au lieu de celui de sa rareté)")
	check(data.Tutorial.Step == 5 and stateOk(ALICE, 5, "WaitUnlock", A.slot1), "objet posé au sol : étape 5, indice WaitUnlock, flèche vers l'objet " .. describe(ALICE))
	check(funnelCount(ALICE, 6) == 1 and funnelCount(ALICE, 5) == 1, "funnel 6 « Colis posé sur l'établi » (5 pas renvoyé)")
	step(5.6)
	check(stateOk(ALICE, 5, "TakeUnlocked", A.slot1), "5 s plus tard : indice TakeUnlocked " .. describe(ALICE))
	check(ALICE:GetAttribute("TutorialHint") == "TakeUnlocked", "attribut TutorialHint = TakeUnlocked")
	step(0.3)
	local fb = PLAYER_GUI:FindFirstChild("TutorialV0")
	local skipButton = fb and fb:FindFirstChild("NextButton", true)
	check(Controller.GetState().Text == Tutorial.Hints.TakeUnlocked and skipButton ~= nil and skipButton.Visible, "client : « " .. Tutorial.Hints.TakeUnlocked .. " », bouton Passer visible dès l'étape 5")

	local _, openedUid = openBox(ALICE, 1)
	check(data.Items[openedUid].AntiTheft == nil, "objet repris : libre dans l'inventaire (mains prises)")
	step(0.6)
	-- a51 (L-089) : l'objet va dans l'inventaire ; on le pose ensuite sur un présentoir libre.
	check(stateOk(ALICE, 5, "PlaceItem", A.slot1), "objet dans l'inventaire : indice PlaceItem vers le présentoir libre 1 " .. describe(ALICE))
	check(funnelCount(ALICE, 7) == 1 and funnelCount(ALICE, 8) == 0, "funnel 7 « Premier objet révélé », pas encore 8")
	data.Display["1"] = openedUid
	step(0.6)
	check(stateOk(ALICE, 5, "CollectCash", A.cashPad), "objet exposé : indice CollectCash vers la plaque de ramassage " .. describe(ALICE))
	check(funnelCount(ALICE, 8) == 1, "funnel 8 « Premier objet exposé »")

	cashOut(ALICE, 12, "Leave")
	check(data.Tutorial.Step == 5 and funnelCount(ALICE, 9) == 0, "encaissement automatique au départ : pas compté")
	cashOut(ALICE, 500, "Offline")
	check(data.Tutorial.Step == 5 and funnelCount(ALICE, 9) == 0, "a59 : gains hors ligne versés (source Offline) : pas compté comme un ramassage")
	cashOut(ALICE, 0, "Pad")
	check(data.Tutorial.Step == 5, "encaissement de 0 $ : pas compté")
	cashOut(ALICE, 10, "Pad")
	check(data.Tutorial.Step == 6, "premier encaissement : étape 6")
	check(funnelCount(ALICE, 9) == 1, "funnel 9 « Premier encaissement »")
	check(stateOk(ALICE, 6, "StandOnTreadmill", A.treadmill), "étape 6 : flèche vers le tapis, indice StandOnTreadmill (a41, L-071) " .. describe(ALICE))
	-- a41 (L-071) : le tapis n'a plus d'invite, la bulle dit de s'arrêter dessus (8 mots au plus, anglais).
	check(Controller.GetState().Text == "Stand on the treadmill to train!", `client : « Stand on the treadmill to train! » ({Controller.GetState().Text})`)
	check(#string.split(Tutorial.Hints.StandOnTreadmill, " ") <= Tutorial.BubbleMaxWords, "indice StandOnTreadmill : 8 mots au plus")

	ALICE:SetAttribute("TrainingMachine", "Treadmill")
	step(0.6)
	check(stateOk(ALICE, 6, nil, nil), "sur le tapis : pas de flèche " .. describe(ALICE))
	step(15)
	ALICE:SetAttribute("TrainingMachine", nil)
	step(0.6)
	check(data.Tutorial.Step == 6 and stateOk(ALICE, 6, "StandOnTreadmill", A.treadmill), "a134 : 15 s de tapis : encore l'étape 6, la flèche revient au tapis (plus de banc) " .. describe(ALICE))
	ALICE:SetAttribute("TrainingMachine", "Bench")
	step(15.5)
	check(data.Tutorial.Step == 6, "a134 : 15 s « au banc » : rien ne compte, encore l'étape 6")
	ALICE:SetAttribute("TrainingMachine", "Treadmill")
	step(15.5)
	check(data.Tutorial.Step == 7, "30 s d'entraînement au tapis : étape 7")
	ALICE:SetAttribute("TrainingMachine", nil)

	data.Cash = 100
	step(0.6)
	check(stateOk(ALICE, 7, "CollectCash", A.cashPad), "étape 7 sans 300 $ : CollectCash vers la plaque de ramassage " .. describe(ALICE))
	data.Cash = 300
	step(0.6)
	check(stateOk(ALICE, 7, nil, WEAPON_SHOP), "300 $ : flèche vers la boutique d'armes de la map (pas celle de l'inbox) " .. describe(ALICE))
	table.insert(data.Tools.Owned, "Wrench")
	data.Cash = 0
	step(0.6)
	check(data.Tutorial.Step == 8, "clé à molette achetée : étape 8")
	check(funnelCount(ALICE, 10) == 1, "funnel 10 « Premier outil acheté »")
	check(stateOk(ALICE, 8, "CollectCash", A.cashPad), "étape 8 sans 500 $ : CollectCash " .. describe(ALICE))
	data.Cash = 500
	step(0.6)
	check(stateOk(ALICE, 8, nil, AURA_SHOP), "500 $ : flèche vers la boutique d'auras " .. describe(ALICE))
	table.insert(data.Cosmetics.Auras, "Spark")
	step(0.6)
	check(data.Tutorial.Step == 9 and stateOk(ALICE, 9, nil, GATE_2), "aura achetée : étape 9, flèche vers l'arche de la zone 2 " .. describe(ALICE))
	step(0.3)
	check(Controller.GetState().Text == "Next goal: Zone 2!", "client : « Next goal: Zone 2! »")

	moveTo(ALICE, Vector3.new(99, 3, 0))
	step(0.6)
	check(data.Tutorial.Step == 9, "x = 99 : pas encore passé l'arche")
	moveTo(ALICE, Vector3.new(101, 3, 5))
	step(0.6)
	check(data.Tutorial.Step == 10 and stateOk(ALICE, 10, nil, nil), "arche de la zone 2 passée : étape 10, rien à montrer " .. describe(ALICE))
	step(0.3)
	check(Controller.GetState().Shown == false, "client : pas de bulle à l'étape 10")

	SHIELD[ALICE] = false
	step(0.6)
	check(stateOk(ALICE, 10, "ShieldEnd", nil), "fin du bouclier débutant : indice ShieldEnd " .. describe(ALICE))
	step(0.3)
	check(Controller.GetState().Text == Tutorial.ShieldEndMessage, "client : « Your shop can now be robbed: keep your bat close! »")
	check(data.Tutorial.Done == false, "le message reste affiché avant la fin du tuto")
	step(8.2)
	check(data.Tutorial.Done == true and data.Tutorial.Step == 10, "tuto fini : Step = 10, Done = true")
	-- a169 (vague 52, L-163) : puis l'indice ProtectShop MessageDuration s, puis tout est caché.
	check(stateOk(ALICE, 10, "ProtectShop", nil), "fin du tuto : indice ProtectShop, sans flèche " .. describe(ALICE))
	step(0.3)
	check(Controller.GetState().Text == Tutorial.Hints.ProtectShop, "client : « " .. Tutorial.Hints.ProtectShop .. " »")
	step(8.2)
	check(stateOk(ALICE, 0, nil, nil), "TutorialStep(0) : tout est caché " .. describe(ALICE))
	check(ALICE:GetAttribute("TutorialStep") == 0 and ALICE:GetAttribute("TutorialHint") == nil, "attributs à la fin : TutorialStep = 0, TutorialHint retiré")
	step(0.3)
	local final = Controller.GetState()
	check(final.Step == 0 and final.Shown == false and final.Arrow == false, "client : bulle et flèche cachées")
	check(PLAYER_GUI:FindFirstChild("TutorialV0").Enabled == false, "client : repli V0 désactivé")
	local all = true
	for i = 1, 10 do
		if funnelCount(ALICE, i) ~= 1 then
			all = false
		end
	end
	check(all and #funnelOf(ALICE) == 10, "funnel : les 10 étapes, une seule fois chacune")
	check(TutorialService.GetStep(ALICE) == 0 and TutorialService.IsActive(ALICE) == false, "API : GetStep = 0, IsActive = false")
	local count = #stepsTo(ALICE)
	step(2)
	check(#stepsTo(ALICE) == count, "plus aucun envoi après la fin")
end
closeStore("STORE_Z1_Superette")
rebuildWindow("STORE_Z1_Superette")

print("== C. Résultats garantis seulement pendant le tuto")
PLOT_I, I = makePlot(4, -140, 60)
IRONIX = makePlayer("Ironix", 3, Vector3.new(65, 3, -40))
do
	local data = newProfile()
	data.Items["old-1"] = { Id = "Z1_Donut", Source = "NPC", At = 0, Zone = 1 }
	data.Display["1"] = "old-1"
	table.insert(data.Tools.Owned, "Wrench")
	table.insert(data.Cosmetics.Auras, "Spark")
	data.Lifetime.Heists = 4
	PROFILES[IRONIX] = data
	assignPlot(IRONIX, PLOT_I)
	local p = grab(IRONIX, "STORE_Z1_Kiosque", "Standard", "Z1_Banane")
	check(p.Tier == "Standard" and p.ItemId == "Z1_Banane", "ancien joueur : colis du rayon gardé")
	check(guardSpeed(IRONIX, 1) == Zones[1].GuardSpeed, "ancien joueur : vigile de la zone (13,4)")
	local delay = placeBox(IRONIX, 1)
	check(delay == 20, "ancien joueur : antivol d'avant l'accroche (20 s dans ce faux)")
	local p2 = grab(ALICE, "STORE_Z1_Superette", "Premium", "Z1_Donut")
	check(p2.Tier == "Premium" and p2.ItemId == "Z1_Donut", "tuto fini : colis du rayon gardé")
	check(guardSpeed(ALICE, 1) == Zones[1].GuardSpeed, "tuto fini : vigile de la zone")
	carryEnd(ALICE, "Failed", "Caught")
	check(FakeUnbox.GetLuck(IRONIX, { Tier = "Premium", Zone = 1, ItemId = "Z1_PotDeNouilles", Rarity = "Rare", ReadyAt = 0 }) == 1, "a169 : GetLuck plus remplacée par le tuto (1)")
	check(FakeUnbox.GetAntiTheftDelay(ALICE, "Z1_PotDeNouilles") == 20, "Pot de nouilles hors du tuto : antivol d'avant (20 s dans ce faux)")
	check(FakeUnbox.GetOpenDelay(ALICE, { Tier = "Premium", Zone = 1, ItemId = "Z1_PotDeNouilles", Rarity = "Rare", ReadyAt = 0 }) == Rarities.ById.Rare.OpenDelay, "a169 : GetOpenDelay plus remplacée par le tuto")
end
-- Un nouveau joueur en plein tuto qui braque la zone 2 : rien de garanti là-bas.
PLOT_G, G = makePlot(5, -140, -140)
GUS = makePlayer("Gus", 7, Vector3.new(140, 3, 26))
PROFILES[GUS] = newProfile()
assignPlot(GUS, PLOT_G)
do
	check(PROFILES[GUS].Tutorial.Step == 1, "Gus : tuto lancé")
	local p = grab(GUS, "STORE_Z2_MagasinDeJouets", "Standard", "Z2_CanardEnPlastique")
	check(p.Tier == "Standard" and p.ItemId == "Z2_CanardEnPlastique", "tuto, magasin de la zone 2 : colis du rayon gardé")
	check(guardSpeed(GUS, 2) == Zones[2].GuardSpeed, "tuto, zone 2 : vigile de la zone 2 (18,8)")
	check(PROFILES[GUS].Tutorial.Step == 4, "colis de la zone 2 sur la tête : étape 4 quand même")
	moveTo(GUS, G.slot1)
	local delay = placeBox(GUS, 1)
	check(delay == 20, "objet qui n'est pas le Pot de nouilles : antivol d'avant (20 s dans ce faux)")
	check(PROFILES[GUS].Tutorial.Step == 5, "colis posé : étape 5")
end

print("== D. Reprise après une déconnexion")
PLOT_C, C = makePlot(3, -140, -60)
CAROL = makePlayer("Carol", 4, Vector3.new(65, 3, -26))
PROFILES[CAROL] = newProfile()
SHIELD[CAROL] = true
do
	assignPlot(CAROL, PLOT_C)
	holdTool(CAROL, true)
	fireAsClient(CAROL, "HitWindow", "STORE_Z1_Kiosque")
	check(PROFILES[CAROL].Tutorial.Step == 2, "Carol : premier coup sur le Kiosque (tout magasin de la zone 1 compte)")
	breakWindow("STORE_Z1_Kiosque", CAROL)
	check(PROFILES[CAROL].Tutorial.Step == 3 and stateOk(CAROL, 3, nil, KIOSQUE_WINDOW), "Kiosque cassé : étape 3, flèche vers le Kiosque " .. describe(CAROL))
	holdTool(CAROL, false)
	local p = grab(CAROL, "STORE_Z1_Kiosque", "Luxe", "Z1_Pasteque")
	check(p.Tier == "Premium" and p.ItemId == "Z1_PotDeNouilles", "Kiosque : colis garanti aussi")
	check(PROFILES[CAROL].Tutorial.Step == 4, "Carol : étape 4")
	local saved = leave(CAROL, false)
	check(saved.Tutorial.Step == 4 and saved.Tutorial.Done == false, "départ avec le colis : le profil garde l'étape la plus avancée (4)")
	check(logHas("Carol : étape 4 → 2 (objet perdu)", "PRINT", "server"), "sur le moment : retour à l'étape 2 (objet perdu, plus de personnage)")
	closeStore("STORE_Z1_Kiosque")
	rebuildWindow("STORE_Z1_Kiosque")
	CAROL = makePlayer("Carol", 4, C.spawn)
	PROFILES[CAROL] = saved
	assignPlot(CAROL, PLOT_C)
	check(TutorialService.GetStep(CAROL) == 2 and stateOk(CAROL, 2, nil, SUPERETTE_WINDOW), "retour : reprise à l'étape 2 (colis revenu sur son rayon), flèche vers la Supérette " .. describe(CAROL))
	check(logHas("Carol : tuto repris à l'étape 4", "PRINT", "server") and saved.Tutorial.Step == 4, "sortie : « tuto repris à l'étape 4 », profil toujours à 4")
	-- Indice WindowRebuilding : magasin fermé, vitrine pas encore reconstruite.
	moveTo(CAROL, Vector3.new(65, 3, 26))
	holdTool(CAROL, true)
	fireAsClient(CAROL, "HitWindow", "STORE_Z1_Superette")
	breakWindow("STORE_Z1_Superette", CAROL)
	check(TutorialService.GetStep(CAROL) == 3, "Carol : Supérette cassée, étape 3")
	closeStore("STORE_Z1_Superette")
	step(0.6)
	check(TutorialService.GetStep(CAROL) == 2 and stateOk(CAROL, 2, "WindowRebuilding", SUPERETTE_WINDOW), "rideau tombé sans colis : étape 2, indice WindowRebuilding " .. describe(CAROL))
	rebuildWindow("STORE_Z1_Superette")
	step(0.6)
	check(stateOk(CAROL, 2, nil, SUPERETTE_WINDOW), "vitrine reconstruite : bulle de l'étape 2 " .. describe(CAROL))
	holdTool(CAROL, false)
end
-- Départ quand le profil est libéré avant la fin du portage : l'étape 4 est sauvegardée telle quelle.
PLOT_D, D = makePlot(6, -220, -60)
DAN = makePlayer("Dan", 5, Vector3.new(65, 3, 26))
PROFILES[DAN] = newProfile()
do
	assignPlot(DAN, PLOT_D)
	breakWindow("STORE_Z1_Superette", IRONIX)
	check(PROFILES[DAN].Tutorial.Step == 3, "Dan : vitrine cassée par un autre joueur juste devant lui → étape 3 dès l'étape 1")
	check(funnelCount(DAN, 2) == 0 and funnelCount(DAN, 3) == 0, "funnel 2 et 3 pas envoyés pour Dan (ce n'est pas lui)")
	grab(DAN, "STORE_Z1_Superette", "Standard", "Z1_Banane")
	check(PROFILES[DAN].Tutorial.Step == 4, "Dan : étape 4")
	local saved = leave(DAN, true)
	check(saved.Tutorial.Step == 4, "profil libéré d'abord : étape 4 sauvegardée")
	closeStore("STORE_Z1_Superette")
	rebuildWindow("STORE_Z1_Superette")
	DAN = makePlayer("Dan", 5, D.spawn)
	PROFILES[DAN] = saved
	assignPlot(DAN, PLOT_D)
	check(TutorialService.GetStep(DAN) == 2 and stateOk(DAN, 2, nil, SUPERETTE_WINDOW), "retour sans colis : étape 2 " .. describe(DAN))
	check(guardSpeed(DAN, 1) == 12, "Dan : vigile lent toujours garanti au braquage suivant")
	local p = grab(DAN, "STORE_Z1_Superette", "Standard", "Z1_HotDog")
	check(p.ItemId == "Z1_PotDeNouilles", "Dan : colis garanti au braquage suivant")
	check(TutorialService.GetStep(DAN) == 4, "Dan : colis sur la tête, étape 4")
	carryEnd(DAN, "Failed", "Caught")
	step(0.6)
	check(TutorialService.GetStep(DAN) == 2 and PROFILES[DAN].Tutorial.Step == 4, "rattrapé (magasin fermé) : étape 2, le profil garde 4")
end
-- Reprises plus loin dans le tuto.
PLOT_E, E = makePlot(7, -220, 60)
do
	local hal = makePlayer("Hal", 8, E.spawn)
	local data = newProfile()
	data.Tutorial.Step = 6
	data.Items["h1"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
	data.Display["1"] = "h1"
	data.Lifetime.Heists = 1
	PROFILES[hal] = data
	HAL = hal
	assignPlot(hal, PLOT_E)
	check(data.Tutorial.Step == 6 and data.Tutorial.Done == false and stateOk(hal, 6, "StandOnTreadmill", E.treadmill), "reprise à l'étape 6 (objets déjà là : pas pris pour un ancien joueur) " .. describe(hal))
	check(#funnelOf(hal) == 0, "reprise à l'étape 6 : aucun funnel renvoyé")

	local erin = makePlayer("Erin", 9, E.spawn)
	local dataE = newProfile()
	dataE.Tutorial.Step = 5
	-- a51 (L-089) : colis posé au sol (Spot), rangé sous son uid ; son point du monde : le présentoir 1.
	dataE.Items["e1"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1, AntiTheft = true, UnlockAt = Workspace:GetServerTimeNow() + 3, Spot = { X = 1, Y = 0, Z = 0 } } -- a169 : objet sous antivol posé
	BOX_POS["e1"] = E.slot1
	dataE.Lifetime.Heists = 1
	PROFILES[erin] = dataE
	ERIN = erin
	assignPlot(erin, PLOT_E)
	check(stateOk(erin, 5, "WaitUnlock", E.slot1), "reprise à l'étape 5, objet sous antivol : WaitUnlock " .. describe(erin))
	step(3.6)
	check(stateOk(erin, 5, "TakeUnlocked", E.slot1), "antivol écoulé hors ligne ou pas : TakeUnlocked " .. describe(erin))

	local fay = makePlayer("Fay", 10, E.spawn)
	local dataF = newProfile()
	dataF.Tutorial.Step = 3
	PROFILES[fay] = dataF
	assignPlot(fay, PLOT_E)
	check(TutorialService.GetStep(fay) == 2 and dataF.Tutorial.Step == 3 and stateOk(fay, 2, nil, SUPERETTE_WINDOW), "étape 3 sauvegardée, magasin fermé : reprise à l'étape 2 (profil à 3) " .. describe(fay))

	local ivy = makePlayer("Ivy", 11, E.spawn)
	local dataI = newProfile()
	dataI.Tutorial.Step = 10
	dataI.Lifetime.PlaySeconds = 900
	dataI.Items["i1"] = { Id = "Z1_PotDeNouilles", Source = "NPC", At = 0, Zone = 1 }
	PROFILES[ivy] = dataI
	SHIELD[ivy] = false
	assignPlot(ivy, PLOT_E)
	check(stateOk(ivy, 10, "ShieldEnd", nil) and dataI.Tutorial.Done == false, "reprise à l'étape 10, bouclier déjà fini : ShieldEndMessage d'abord " .. describe(ivy))
	step(8.6) -- a51 : 8 s de message + un contrôle (0,5 s) ; les pas ajoutés plus haut décalent la cadence
	check(dataI.Tutorial.Done == true and stateOk(ivy, 10, "ProtectShop", nil), "puis le tuto finit : ProtectShop (a169) " .. describe(ivy))	step(8.6)	check(stateOk(ivy, 0, nil, nil), "puis tout est caché " .. describe(ivy))

	-- Colis venu d'ailleurs que d'un magasin (comme ceux du camion d'a27, ramassés au sol).
	local lou = makePlayer("Lou", 14, Vector3.new(50, 3, 0))
	PROFILES[lou] = newProfile()
	assignPlot(lou, PLOT_E)
	carryStart(lou, { Kind = "NPCItem", Tier = "Standard", Zone = 1, Rarity = "Common", ItemId = "Z1_Donut", StoreId = "TRUCK_Event", SlotId = "TRUCK_Event/03" })
	check(TutorialService.GetStep(lou) == 4, "colis PNJ ramassé ailleurs (camion) : étape 4 quand même")
	carryEnd(lou, "Failed", "Caught")
	check(TutorialService.GetStep(lou) == 2 and stateOk(lou, 2, nil, SUPERETTE_WINDOW), "perdu : étape 2, flèche vers la Supérette (pas vers le camion) " .. describe(lou))

	local jay = makePlayer("Jay", 12, E.spawn)
	local dataJ = newProfile()
	dataJ.Tutorial.Step = 42
	PROFILES[jay] = dataJ
	assignPlot(jay, PLOT_E)
	-- a121 (vague 36) : ramenée à la dernière étape (13) ; ce banc n'a pas de bot : le tuto finira après BotWait s.
	check(dataJ.Tutorial.Step == 14, "étape hors bornes (42) : ramenée à 14 (a126 : plus grand numéro)")
end

print("== E. Passer")
do
	local before = #stepsTo(CAROL)
	fireAsClient(CAROL, "TutorialSkip")
	check(PROFILES[CAROL].Tutorial.Done == false and TutorialService.GetStep(CAROL) == 2, "Passer à l'étape 2 : refusé")
	check(logHas("TutorialSkip refusé à l'étape 2", "PRINT", "server"), "sortie : refus expliqué")
	check(#stepsTo(CAROL) == before, "refus : rien envoyé")
	step(1.1)
	fireAsClient(ERIN, "TutorialSkip")
	check(PROFILES[ERIN].Tutorial.Done == true and PROFILES[ERIN].Tutorial.Step == 5, "Passer à l'étape 5 : accepté, Step garde 5")
	check(stateOk(ERIN, 0, nil, nil), "Passer : TutorialStep(0) " .. describe(ERIN))
	moveTo(ERIN, Vector3.new(65, 3, 26))
	local p = grab(ERIN, "STORE_Z1_Superette", "Standard", "Z1_Banane")
	check(p.ItemId == "Z1_Banane" and guardSpeed(ERIN, 1) == Zones[1].GuardSpeed, "après Passer : plus rien de garanti")
	carryEnd(ERIN, "Failed", "Caught")
	check(FakeUnbox.GetAntiTheftDelay(ERIN, "Z1_PotDeNouilles") == 20, "après Passer : antivol d'avant pour le Pot de nouilles")
	step(1.1) -- Net : TutorialSkip, 1 appel par seconde au plus
	fireAsClient(ERIN, "TutorialSkip")
	check(logHas("TutorialSkip refusé : pas de tuto en cours", "PRINT", "server"), "Passer une 2e fois : refusé")
	fireAsClient(IRONIX, "TutorialSkip")
	check(PROFILES[IRONIX].Tutorial.Step == 0, "ancien joueur qui envoie Passer : rien ne change")
end

print("== F. Joueurs qui ont déjà joué")
do
	local dataI = PROFILES[IRONIX]
	check(dataI.Tutorial.Done == true and dataI.Tutorial.Step == 0, "Ironix (objets, outil, aura) : Done = true, Step = 0")
	check(#stepsTo(IRONIX) == 0, "Ironix : aucun TutorialStep envoyé")
	check(IRONIX:GetAttribute("TutorialStep") == nil, "Ironix : aucun attribut TutorialStep")
	check(#funnelOf(IRONIX) == 0, "Ironix : aucun funnel")
	check(logHas("Ironix : ancien joueur (objets)", "PRINT", "server"), "sortie : « ancien joueur (objets) »")
	local saved = leave(IRONIX, false)
	IRONIX = makePlayer("Ironix", 3, I.spawn)
	PROFILES[IRONIX] = saved
	assignPlot(IRONIX, PLOT_I)
	check(#stepsTo(IRONIX) == 0 and saved.Tutorial.Done == true, "Ironix revient : toujours rien")

	local cases = {
		{ "objets", function(d) d.Items["x"] = { Id = "Z1_Donut", Source = "NPC", At = 0 } end },
		{ "colis dans l'inventaire ou posé", function(d) d.Boxes["b1"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Donut", Rarity = "Common", ReadyAt = 0 } end },
		{ "braquages ou vols réussis", function(d) d.Lifetime.Heists = 1 end },
		{ "braquages ou vols réussis", function(d) d.Lifetime.Steals = 2 end },
		{ "outil acheté", function(d) table.insert(d.Tools.Owned, "Crowbar") end },
		{ "aura ou trail", function(d) table.insert(d.Cosmetics.Auras, "Spark") end },
		{ "aura ou trail", function(d) table.insert(d.Cosmetics.Trails, "Dust") end },
		{ "améliorations", function(d) d.Upgrades.Bench = 1 end },
		{ "améliorations", function(d) d.Upgrades.UnboxBenches = 1 end },
	}
	local allOk = true
	for i, case in cases do
		local player = makePlayer(`Old{i}`, 100 + i, I.spawn)
		local data = newProfile()
		case[2](data)
		PROFILES[player] = data
		assignPlot(player, PLOT_I)
		if not (data.Tutorial.Done == true and data.Tutorial.Step == 0 and #stepsTo(player) == 0 and #funnelOf(player) == 0) then
			allOk = false
			print(`    cas {i} ({case[1]}) : Done {tostring(data.Tutorial.Done)}, Step {data.Tutorial.Step}`)
		end
		if not logHas(`Old{i} : ancien joueur ({case[1]})`, "PRINT", "server") then
			allOk = false
			print(`    cas {i} : raison « {case[1]} » absente de la sortie`)
		end
	end
	check(allOk, "chaque critère seul (objet, colis, braquage, vol, outil, aura, trail, amélioration) : ancien joueur")

	local trainee = makePlayer("Trainee", 200, I.spawn)
	local data = newProfile()
	data.Cash = 500
	data.Stats.Speed = 120
	data.Stats.Strength = 40
	data.Lifetime.PlaySeconds = 400
	PROFILES[trainee] = data
	assignPlot(trainee, PLOT_I)
	check(data.Tutorial.Step == 1 and data.Tutorial.Done == false, "argent, stats et temps de jeu seuls : le tuto se lance")
end

print("== G. Funnel envoyé une seule fois")
do
	-- Carol a déjà les étapes 1 à 4 (avant sa déconnexion) : rien n'est renvoyé.
	local counts = {}
	for i = 1, 4 do
		counts[i] = funnelCount(CAROL, i)
	end
	check(counts[1] == 1 and counts[2] == 1 and counts[3] == 1 and counts[4] == 1, "Carol : étapes 1 à 4 une fois, même après la reprise " .. table.concat(funnelOf(CAROL), ","))
	moveTo(CAROL, Vector3.new(65, 3, 26))
	holdTool(CAROL, true)
	for _ = 1, 3 do
		fireAsClient(CAROL, "HitWindow", "STORE_Z1_Superette")
		step(0.2)
	end
	breakWindow("STORE_Z1_Superette", CAROL)
	holdTool(CAROL, false)
	grab(CAROL, "STORE_Z1_Superette", "Standard", "Z1_Banane")
	check(funnelCount(CAROL, 2) == 1 and funnelCount(CAROL, 3) == 1 and funnelCount(CAROL, 4) == 1, "nouveaux coups, casse et prise : funnel 2, 3 et 4 pas renvoyés")
	check(funnelCount(ALICE, 9) == 1, "Alice : un seul « Premier encaissement » malgré 3 encaissements")
	cashOut(ALICE, 50, "Pad")
	check(funnelCount(ALICE, 9) == 1, "encaissement après la fin du tuto : pas renvoyé")
	local total = #FUNNEL_LOG
	FUNNEL_FAILS = true
	local kim = makePlayer("Kim", 13, E.spawn)
	PROFILES[kim] = newProfile()
	assignPlot(kim, PLOT_E)
	FUNNEL_FAILS = false
	check(PROFILES[kim].Tutorial.Step == 1 and #FUNNEL_LOG == total, "AnalyticsService qui refuse (Studio) : le tuto se lance quand même")
	check(logHas("funnel Kim : étape 1 « Arrivée sur sa parcelle » (refusé par Roblox en Studio", "PRINT", "server"), "sortie : envoi refusé écrit, sans erreur")
	check(funnelOf(kim)[1] == nil, "rien d'enregistré pour Kim")
	local hits = 0
	for _, e in FUNNEL_LOG do
		if e.player == ALICE and e.step == 1 and e.name == "Arrivée sur sa parcelle" then
			hits += 1
		end
	end
	check(hits == 1, "nom de l'étape envoyé avec son numéro (Config/Tutorial.FunnelSteps)")
	carryEnd(CAROL, "Failed", "Caught")
	closeStore("STORE_Z1_Superette")
	rebuildWindow("STORE_Z1_Superette")
	step(0.6)
end

print("== I. Bulle de nuit")
PLOT_B, B = makePlot(2, -60, 60)
BOB = makePlayer("Bob", 2, B.spawn)
PROFILES[BOB] = newProfile()
do
	assignPlot(BOB, PLOT_B)
	check(stateOk(BOB, 1, nil, SUPERETTE_WINDOW), "Bob : étape 1 " .. describe(BOB))
	setPhase("Warning")
	step(0.1)
	check(stateOk(BOB, 1, nil, SUPERETTE_WINDOW), "alerte, Bob en zone safe : bulle de l'étape " .. describe(BOB))
	moveTo(BOB, Vector3.new(45, 3, 0))
	step(0.6)
	check(stateOk(BOB, 1, "Night", B.spawn), "alerte, Bob dans le couloir : NightBubble, flèche vers sa parcelle " .. describe(BOB))
	moveTo(BOB, Vector3.new(10, 3, 0))
	step(0.6)
	check(stateOk(BOB, 1, nil, SUPERETTE_WINDOW), "rentré : bulle de l'étape " .. describe(BOB))
	setPhase("Night")
	step(0.1)
	check(stateOk(BOB, 1, "NightClosed", nil), "nuit, côté zone safe, étape 1 : NightClosed sans flèche " .. describe(BOB))
	check(stateOk(HAL, 6, "StandOnTreadmill", E.treadmill), "nuit, étape 6 (dans sa parcelle) : rien ne change " .. describe(HAL))
	moveTo(BOB, Vector3.new(60, 3, 0))
	step(0.6)
	check(stateOk(BOB, 1, "Night", B.spawn), "nuit, dans le couloir : NightBubble " .. describe(BOB))
	setPhase("Day")
	step(0.1)
	check(stateOk(BOB, 1, nil, SUPERETTE_WINDOW), "aube : bulle de l'étape " .. describe(BOB))
	check(#stepsTo(IRONIX) == 0, "ancien joueur : aucune bulle de nuit")
end

print("== H. Crochet de test (Studio)")
do
	Workspace:SetAttribute("TutorialReset", ALICE.UserId)
	local data = PROFILES[ALICE]
	check(data.Tutorial.Step == 1 and data.Tutorial.Done == false, "TutorialReset = UserId d'Alice : étape 1, Done = false")
	check(Workspace:GetAttribute("TutorialReset") == nil, "l'attribut est effacé")
	check(stateOk(ALICE, 1, nil, SUPERETTE_WINDOW), "TutorialStep(1) renvoyé " .. describe(ALICE))
	check(funnelCount(ALICE, 1) == 2, "funnel relancé (Studio : rien n'est envoyé à Roblox)")
	check(logHas("Alice : tuto relancé depuis l'étape 1 (crochet de test)", "PRINT", "server"), "sortie : « tuto relancé »")
	Workspace:SetAttribute("TutorialReset", "Ironix")
	check(PROFILES[IRONIX].Tutorial.Step == 1 and PROFILES[IRONIX].Tutorial.Done == false, "TutorialReset = « Ironix » (nom) : l'ancien joueur aussi")
	Workspace:SetAttribute("TutorialReset", 999)
	check(logHas("aucun joueur « 999 »", "WARN", "server"), "joueur inconnu : avertissement")
	check(TutorialService.Reset(IRONIX) == true, "API Reset en Studio")
end

print("== J. Client : écran de Clément, écrans qui couvrent, flèche de Clément, bouton Passer")
do
	step(0.3)
	check(Controller.GetState().Text == "Smash the Mini Mart window!" and Controller.GetState().Fallback, "Alice relancée : bulle V0 de l'étape 1")
	-- Flèche qui passe d'abord par la porte de sa boutique (L-050) : près de la porte, sans outil en
	-- main, la bulle reste celle de l'étape (EquipFists seulement près d'une vitrine de magasin PNJ).
	local savedAt = ALICE.Character.HumanoidRootPart.CFrame
	local hadTool = ALICE.Character:FindFirstChild("Fists") ~= nil
	local doorPoint = Vector3.new(-60, 0.6, -45)
	REMOTES.TutorialStep:FireClient(ALICE, 1, nil, doorPoint)
	moveTo(ALICE, doorPoint + Vector3.new(0, 3, 8))
	holdTool(ALICE, false)
	step(0.3)
	check(Controller.GetState().Text == "Smash the Mini Mart window!", "client : pas d'« Equip your Fists » près de la porte de sa boutique (cible qui n'est pas une vitrine) " .. tostring(Controller.GetState().Text))
	REMOTES.TutorialStep:FireClient(ALICE, 1, nil, SUPERETTE_WINDOW)
	ALICE.Character.HumanoidRootPart.CFrame = savedAt
	holdTool(ALICE, hadTool)
	step(0.3)
	local screen = new("ScreenGui", { Name = "UI_Tutorial", Enabled = false })
	local bubble = new("Frame", { Name = "Bubble" }, screen)
	local frame = new("Frame", { Name = "Inner" }, bubble)
	local label = new("TextLabel", { Name = "Label", Text = "" }, frame)
	local nextButton = new("TextButton", { Name = "NextButton", Visible = true, Text = "Next" }, screen)
	local skipButton = new("TextButton", { Name = "SkipButton", Visible = true, Text = "Skip!" }, screen)
	screen.Parent = PLAYER_GUI
	step(0.3)
	check(PLAYER_GUI:FindFirstChild("TutorialV0") == nil, "UI_Tutorial arrive : le repli V0 disparaît")
	check(screen.Enabled and label.Text == "Smash the Mini Mart window!", "texte dans Bubble.Label de Clément (cadre en plus autour : trouvé)")
	check(skipButton.Visible == false and nextButton.Visible == true and nextButton.Text == "Next" and skipButton.Text == "Skip!", "SkipButton de Clément caché avant l'étape 5, NextButton et textes de Clément intacts")
	check(Controller.GetState().Fallback == false, "GetState : plus de repli")

	local unbox = new("ScreenGui", { Name = "UI_Unbox", Enabled = true }, PLAYER_GUI)
	step(0.3)
	check(screen.Enabled == false and Controller.GetState().Arrow == false, "UI_Unbox ouvert : bulle et flèche cachées")
	unbox.Enabled = false
	step(0.3)
	check(screen.Enabled == true and Controller.GetState().Arrow == true, "UI_Unbox fermé : tout revient")
	local shop = new("ScreenGui", { Name = "UI_WeaponShop", Enabled = true }, PLAYER_GUI)
	step(0.3)
	check(screen.Enabled == false, "UI_WeaponShop ouvert : bulle cachée")
	shop.Enabled = false
	step(0.3)

	local assets = folder(ReplicatedStorage, "Assets")
	local fx = folder(assets, "FX")
	new("Beam", { Name = "FX_Tutorial_Arrow", Width0 = 3, Width1 = 2 }, fx)
	local markerModel = new("Model", { Name = "FX_Tutorial_Marker" })
	part("Chevron", Vector3.new(0, 1, 0), Vector3.new(2, 2, 2), markerModel, { CanCollide = true })
	markerModel.WorldPivot = CFrame.new(0, 0, 0)
	markerModel.Parent = fx
	Workspace.CurrentCamera:FindFirstChild("TutorialArrow"):Destroy()
	step(0.3)
	local arrowFolder = Workspace.CurrentCamera:FindFirstChild("TutorialArrow")
	local beam = arrowFolder and arrowFolder:FindFirstChild("Beam", true)
	local marker = arrowFolder and arrowFolder:FindFirstChild("Marker", true)
	check(beam ~= nil and beam.Width0 == 3 and beam.Width1 == 2 and beam.Enabled, "flèche : copie du Beam FX_Tutorial_Arrow de Clément")
	check(marker ~= nil and marker:IsA("Model") and sameVec(marker:GetPivot().Position, SUPERETTE_WINDOW), "repère : copie de FX_Tutorial_Marker, pivot sur la cible")
	check(marker:FindFirstChild("Chevron").CanCollide == false, "repère copié : collisions coupées sur la copie")
	check(markerModel:FindFirstChild("Chevron").CanCollide == true, "modèle de Clément intact")

	-- Alice refait le braquage (résultats garantis de nouveau) jusqu'à l'étape 5, puis tape Passer.
	local data = PROFILES[ALICE]
	moveTo(ALICE, Vector3.new(65, 3, 26))
	holdTool(ALICE, true)
	fireAsClient(ALICE, "HitWindow", "STORE_Z1_Superette")
	breakWindow("STORE_Z1_Superette", ALICE)
	holdTool(ALICE, false)
	local p = grab(ALICE, "STORE_Z1_Superette", "Standard", "Z1_Banane")
	check(p.ItemId == "Z1_PotDeNouilles" and guardSpeed(ALICE, 1) == 12, "après TutorialReset : résultats garantis de nouveau")
	moveTo(ALICE, A.slot1)
	check(placeBox(ALICE, 1) == 5 and data.Tutorial.Step == 5, "objet posé, antivol de 5 s : étape 5")
	step(0.3)
	check(skipButton.Visible == true and label.Text == Tutorial.Hints.CollectCash, "étape 5 : SkipButton visible ; un objet déjà exposé (avant TutorialReset) : CollectCash (a169 : comme la passe ShelfOpen d a107)")
	skipButton.Activated:Fire()
	check(data.Tutorial.Done == true and data.Tutorial.Step == 5, "SkipButton tapé : TutorialSkip accepté par le serveur")
	step(0.3)
	check(screen.Enabled == false and Controller.GetState().Step == 0 and Controller.GetState().Arrow == false, "client : tout est caché après Passer")
	check(nextButton.Visible == true, "NextButton de Clément jamais touché quand SkipButton existe")
	closeStore("STORE_Z1_Superette")
	rebuildWindow("STORE_Z1_Superette")
end

print("== K. Hors de Studio : crochet de test inactif")
do
	for m, value in CACHES.server do
		if m ~= TutorialModule then
			CACHES.prod[m] = value
		end
	end
	local signal = Workspace:GetAttributeChangedSignal("TutorialReset")
	local before = #signal.handlers
	local Prod = requireModule(TutorialModule, "prod")
	Prod.Init()
	check(#signal.handlers == before, "hors Studio : l'attribut TutorialReset n'est pas écouté")
	check(Prod.Reset(BOB) == false, "hors Studio : Reset refusé")
	check(logHas("Reset : Studio seulement", "WARN", "prod"), "hors Studio : avertissement « Studio seulement »")
	check(not logHas("[TutorialService]", "PRINT", "prod"), "hors Studio : aucune ligne de journal du tuto")
end

print("== M. Boutique du hub (PLOT_Shop, L-050) : la flèche passe par la porte, machines par leur tag")
-- Boutique au gabarit du constructeur de Clément (tools/clement/hub/plot_shop_builder.luau), tournée de
-- 90° et posée n'importe où : Bounds = l'intérieur (64 × 80), PlotDoor/Window pivot au sol au milieu
-- de l'entrée (z local −39,5), PlotBarrier, SpawnPoint dedans, machines et tapis de caisse taggés. Un
-- décor sans tag nommé « Bench » est posé avant le vrai banc : il ne doit jamais servir de cible.
function makeShop(index, origin)
	local shop = new("Model", { Name = string.format("PLOT_Shop_%02d", index) })
	local floor = new("Part", { Name = "Floor", CFrame = origin * CFrame.new(0, 0.15, 0), Size = Vector3.new(64, 0.3, 80), Anchored = true }, shop)
	local function att(name, lx, ly, lz)
		new("Attachment", { Name = name }, floor).Position = Vector3.new(lx, ly - 0.15, lz)
		return origin * Vector3.new(lx, ly, lz)
	end
	local decoy = new("Model", { Name = "Bench" }, shop)
	new("Attachment", { Name = "UsePoint" }, new("Part", { Name = "Seat", CFrame = origin * CFrame.new(25, 1, 35), Size = Vector3.new(4, 1, 2), Anchored = true }, decoy))
	local door = new("Model", { Name = "PlotDoor" }, shop)
	local window = new("Model", { Name = "Window" }, door)
	new("Part", { Name = "Glass", CFrame = origin * CFrame.new(-3, 4, -39.5), Size = Vector3.new(5.4, 6.4, 0.4), Anchored = true }, new("Model", { Name = "Leaf_L" }, window))
	window.WorldPivot = origin * CFrame.new(0, 0.6, -39.5)
	door.WorldPivot = origin * CFrame.new(0, 8, -39.5)
	new("Part", { Name = "Barrier_L", CFrame = origin * CFrame.new(-31.8, 15, 0), Size = Vector3.new(0.4, 30, 80), Anchored = true, Transparency = 1 }, new("Model", { Name = "PlotBarrier" }, shop))
	new("Part", { Name = "Bounds", CFrame = origin * CFrame.new(0, 15.15, 0), Size = Vector3.new(64, 29.7, 80), Anchored = true, Transparency = 1, CanCollide = false }, shop)
	local S = { door = origin * Vector3.new(0, 0.6, -39.5) }
	for i = 1, 4 do
		local bench = att(string.format("UnboxBench_%02d", i), -14 - 2 * i, 3.1, 26)
		local slot = att(string.format("DisplaySlot_%02d", i), 10 + 2 * i, 3.75, 0)
		if i == 1 then
			S.bench1, S.slot1 = bench, slot
		end
	end
	new("Part", { Name = "CollectPad_01", CFrame = origin * CFrame.new(-22, 0.4, -28), Size = Vector3.new(4.4, 0.12, 2.6), Anchored = true }, shop) -- a59 (L-091) : plus de CashPad
	S.cashPad = origin * Vector3.new(-22, 0.4, -28)
	local treadmill = new("Model", { Name = "Treadmill" }, shop)
	new("Attachment", { Name = "UsePoint" }, new("Part", { Name = "Belt", CFrame = origin * CFrame.new(20, 1, 30), Size = Vector3.new(3, 1, 6), Anchored = true }, treadmill)).Position = Vector3.new(0, 1, 0)
	addTag(treadmill, "Treadmill")
	S.treadmill = origin * Vector3.new(20, 2, 30)
	local bench = new("Model", { Name = "Bench" }, shop)
	new("Attachment", { Name = "UsePoint" }, new("Part", { Name = "Seat", CFrame = origin * CFrame.new(10, 1, 30), Size = Vector3.new(3, 1, 6), Anchored = true }, bench)).Position = Vector3.new(0, 1, 0)
	addTag(bench, "Bench")
	S.bench = origin * Vector3.new(10, 2, 30)
	S.spawn = att("SpawnPoint", 0, 0.3, -27)
	addTag(shop, "PlayerPlot")
	shop.Parent = MAP
	return shop, S
end
do
	local origin = CFrame.new(-150, 0, 160) * CFrame.Angles(0, math.rad(90), 0)
	local shop, S = makeShop(9, origin)
	local mia = makePlayer("Mia", 15, S.spawn + Vector3.new(0, 3, 0))
	PROFILES[mia] = newProfile()
	assignPlot(mia, shop)
	check(stateOk(mia, 1, nil, S.door), "apparition dans sa boutique : la 1re flèche va à sa porte " .. describe(mia))
	moveTo(mia, origin * Vector3.new(0, 3, -46))
	step(0.6)
	check(stateOk(mia, 1, nil, SUPERETTE_WINDOW), "sortie par la porte : flèche vers la Supérette " .. describe(mia))
	moveTo(mia, Vector3.new(65, 3, 26))
	holdTool(mia, true)
	fireAsClient(mia, "HitWindow", "STORE_Z1_Superette")
	breakWindow("STORE_Z1_Superette", mia)
	holdTool(mia, false)
	local p = grab(mia, "STORE_Z1_Superette", "Standard", "Z1_Banane")
	check(p.ItemId == "Z1_PotDeNouilles" and stateOk(mia, 4, nil, S.door), "colis sur la tête, dehors : flèche vers sa porte " .. describe(mia))
	setPhase("Warning")
	moveTo(mia, Vector3.new(45, 3, 0))
	step(0.6)
	check(stateOk(mia, 4, "Night", S.door), "alerte dans le couloir : NightBubble, flèche vers sa porte (sa parcelle est dedans) " .. describe(mia))
	setPhase("Day")
	moveTo(mia, origin * Vector3.new(0, 3, -30))
	step(0.6)
	check(stateOk(mia, 4, nil, S.spawn), "entrée dans la boutique : flèche vers son SpawnPoint (on y pose le colis au sol, L-089) " .. describe(mia))
	check(placeBox(mia, 1) == 5, "colis posé : 5 s")
	openAndDisplay(mia, 1)
	check(stateOk(mia, 5, "CollectCash", S.cashPad), "plaque CollectPad_01 donnée par DisplayService.GetCollectTarget (a59) " .. describe(mia))
	cashOut(mia, 10, "Pad")
	check(stateOk(mia, 6, "StandOnTreadmill", S.treadmill), "tapis de course trouvé par son tag " .. describe(mia))
	mia:SetAttribute("TrainingMachine", "Treadmill")
	step(1.1)
	mia:SetAttribute("TrainingMachine", nil)
	step(0.6)
	check(stateOk(mia, 6, "StandOnTreadmill", S.treadmill), "a134 : descendu du tapis : la flèche revient au tapis, jamais au banc " .. describe(mia))
	PROFILES[mia].Cash = 300
	mia:SetAttribute("TrainingMachine", "Treadmill")
	step(30)
	mia:SetAttribute("TrainingMachine", nil)
	step(0.6)
	check(stateOk(mia, 7, nil, S.door), "étape 7 dans la boutique, 300 $ : flèche vers la porte d'abord " .. describe(mia))
	moveTo(mia, origin * Vector3.new(0, 3, -50))
	step(0.6)
	check(stateOk(mia, 7, nil, WEAPON_SHOP), "dehors : flèche vers la boutique d'armes " .. describe(mia))
	closeStore("STORE_Z1_Superette")
	rebuildWindow("STORE_Z1_Superette")
end

print("== L. Sortie")
	check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
	check(not logHas("contrôle :", "WARN", "server"), "aucune erreur dans le contrôle régulier")
	check(not logHas("accroche", "WARN"), "aucune accroche refusée")
if VERBOSE then
	dumpLog()
end
summary()
