
---------------------------------------------------------------- bouchons des services voisins
SOURCES["stub/DataService"] = [==[
local DataService = {}
local profiles, loaded, releasing = {}, {}, {}
function DataService.Get(player) return profiles[player] end
function DataService.OnProfileLoaded(fn)
	table.insert(loaded, fn)
	for p in profiles do task.spawn(fn, p) end
	return function() end
end
function DataService.OnProfileReleasing(fn) table.insert(releasing, fn) return function() end end
function DataService._load(player, data)
	profiles[player] = data
	for _, fn in loaded do task.spawn(fn, player) end
end
function DataService._release(player)
	for _, fn in releasing do fn(player) end
	profiles[player] = nil
end
return DataService
]==]

SOURCES["stub/PlotService"] = [==[
local PlotService = {}
local plotOf, assigned, released = {}, {}, {}
function PlotService.GetPlot(player) return plotOf[player] end
function PlotService.OnPlotAssigned(fn)
	table.insert(assigned, fn)
	for p, plot in plotOf do task.spawn(fn, p, plot) end
	return function() end
end
function PlotService.OnPlotReleased(fn) table.insert(released, fn) return function() end end
function PlotService._assign(player, plot)
	plotOf[player] = plot
	plot:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotIndex", plot:GetAttribute("PlotIndex"))
	for _, fn in assigned do task.spawn(fn, player, plot) end
end
function PlotService._release(player)
	local plot = plotOf[player]
	if plot == nil then return end
	plotOf[player] = nil
	plot:SetAttribute("OwnerUserId", 0)
	player:SetAttribute("PlotIndex", nil)
	for _, fn in released do fn(player, plot) end
end
return PlotService
]==]

SOURCES["stub/CarryService"] = [==[
local CarryService = { consumed = {} }
local carried = {}
local started, ended = {}, {}
-- Correctif du 2026-11-08 (DEV-060) : UnboxService suit le début du portage (contrôle du trajet).
function CarryService.OnCarryStarted(fn) table.insert(started, fn) return function() end end
function CarryService.OnCarryEnded(fn) table.insert(ended, fn) return function() end end
function CarryService.IsCarrying(player) return carried[player] ~= nil end
function CarryService.GetPayload(player) return carried[player] end
function CarryService.Consume(player)
	local p = carried[player]
	if p == nil then return nil end
	carried[player] = nil
	player:SetAttribute("Carrying", nil)
	table.insert(CarryService.consumed, p)
	for _, fn in ended do fn(player, p, "Consumed", "Consumed") end
	return p
end
-- a51 (L-089) : fin du portage sans réussite (UnboxService : inventaire de colis plein, colis illisible).
function CarryService.Fail(player, reason)
	local p = carried[player]
	if p == nil then return false end
	carried[player] = nil
	player:SetAttribute("Carrying", nil)
	for _, fn in ended do fn(player, p, "Failed", reason) end
	return true
end
function CarryService._carry(player, payload)
	carried[player] = payload
	player:SetAttribute("Carrying", payload.Rarity)
	for _, fn in started do fn(player, payload) end
end
return CarryService
]==]

-- Correctif du 2026-11-08 (DEV-060) : UnboxService appelle AntiCheatService.Verify juste avant la
-- pose. Bouchon : chaque appel est noté ; verdict = false simule une détection sanctionnée.
SOURCES["stub/AntiCheatService"] = [==[
local AntiCheatService = { verifies = {}, verdict = true }
function AntiCheatService.Verify(player, from, since)
	table.insert(AntiCheatService.verifies, { player = player, from = from, since = since })
	return AntiCheatService.verdict
end
function AntiCheatService.Allow() end
return AntiCheatService
]==]

SOURCES["stub/DisplayService"] = [==[
-- Copie a46 (L-086) : les colis se posent sur les présentoirs (DisplaySlot_xx du faux plot). GetSlots les
-- trouve ; GetSlotStates les dit "Locked" au-delà de 1 + Upgrades.UnboxBenches (au plus 4 : la règle des
-- anciens établis, gardée pour les scénarios de a13), "Boxed" sous un colis, sinon "Free". PlaceItem
-- passe par PlaceAuto (jamais "Taken" : le faux ne garde rien). HasRoom : toujours de la place.
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local DisplayService = { calls = {}, nextSlot = 1 }
function DisplayService.PlaceItem(player, uid, _slot)
	return DisplayService.PlaceAuto(player, uid) ~= nil
end
function DisplayService.HasRoom(_player)
	return true
end
-- a51 (L-089) : l'objet ouvert va dans l'inventaire tant qu'il y a de la place (inventoryRoom = false : plein).
function DisplayService.HasInventoryRoom(_player)
	return DisplayService.inventoryRoom ~= false
end
function DisplayService.GetSlots(player)
	local out = {}
	local plot = PlotService.GetPlot(player)
	if plot then
		for i = 1, 30 do
			local a = plot:FindFirstChild(string.format("DisplaySlot_%02d", i), true)
			if a then out[i] = a end
		end
	end
	return out
end
function DisplayService.GetSlotStates(player)
	local out = {}
	local data = DataService.Get(player)
	local level = if data and type(data.Upgrades.UnboxBenches) == "number" then data.Upgrades.UnboxBenches else 0
	local unlocked = math.min(1 + level, 4)
	for i in DisplayService.GetSlots(player) do
		out[i] = if i > unlocked then "Locked" elseif data and data.Boxes[tostring(i)] ~= nil then "Boxed" else "Free"
	end
	return out
end
function DisplayService.PlaceAuto(player, uid)
	table.insert(DisplayService.calls, { player = player, uid = uid, remoteCount = #REMOTE_LOG })
	if DisplayService.fail then error("panne simulée") end
	return DisplayService.nextSlot
end
function DisplayService.GetIncome() return 0 end
return DisplayService
]==]

SOURCES["stub/AnimationController"] = [==[
local AnimationController = { played = {} }
function AnimationController.PlayPlayer(name) table.insert(AnimationController.played, name) return nil end
function AnimationController.StopPlayer() end
return AnimationController
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
local unboxModule = moduleScript(services, "UnboxService", "server/Services/UnboxService.luau")
local dataModule = moduleScript(services, "DataService", "stub/DataService")
local plotModule = moduleScript(services, "PlotService", "stub/PlotService")
local carryModule = moduleScript(services, "CarryService", "stub/CarryService")
local acModule = moduleScript(services, "AntiCheatService", "stub/AntiCheatService")
local displayModule = moduleScript(services, "DisplayService", "stub/DisplayService")

local client = folder(StarterPlayerScripts, "Client")
local controllers = folder(client, "Controllers")
local controllerModule = moduleScript(controllers, "UnboxController", "client/Controllers/UnboxController.luau")
local animModule = moduleScript(controllers, "AnimationController", "stub/AnimationController")
-- Copie a23 : modules d'aide d'UnboxController (ouverture v2, DEV-050).
local unboxHelpers = folder(controllers, "Unbox")
for _, name in { "Reel", "Sequence", "Screen" } do
	moduleScript(unboxHelpers, name, `client/Controllers/Unbox/{name}.luau`)
end

local greybox = folder(Workspace, "Greybox")
local function makePlot(index, x)
	local plot = InstanceAPI.new("Model")
	plot.Name = string.format("PLOT_Greybox_%02d", index)
	plot:SetAttribute("PlotIndex", index)
	plot:SetAttribute("OwnerUserId", 0)
	for k = 1, 4 do
		local t = InstanceAPI.new("Part")
		t.Name = string.format("UnboxTable_%02d", k)
		t.Size = Vector3.new(3.5, 3, 3)
		t.CFrame = CFrame.new(x + (k - 1) * 6, 1.5, 0)
		t.Parent = plot
		local a = InstanceAPI.new("Attachment")
		a.Name = string.format("DisplaySlot_%02d", k)
		a.CFrame = CFrame.new(0, 1.5, 0)
		a.Parent = t
	end
	-- a51 (L-089) : sol et volume de la boutique ; le colis n° i se pose au sol, 8 studs devant l'établi i.
	local floor = InstanceAPI.new("Part")
	floor.Name = "PlotFloor"
	floor.Size = Vector3.new(60, 0.2, 30)
	floor.CFrame = CFrame.new(x + 9, -0.1, 4)
	floor.Parent = plot
	plot.PrimaryPart = floor
	local bounds = InstanceAPI.new("Part")
	bounds.Name = "Bounds"
	bounds.Size = Vector3.new(60, 20, 30)
	bounds.CFrame = CFrame.new(x + 9, 10, 4)
	bounds.CanCollide = false
	bounds.CanQuery = false
	bounds.Parent = plot
	plot.Parent = greybox
	addTag(plot, "PlayerPlot")
	return plot
end
local plot1 = makePlot(1, 0)
local plot2 = makePlot(2, 200)
local plot3 = makePlot(3, 400)
-- a51 (L-089) : la zone safe couvre les parcelles (x jusqu'à 700) ; le couloir est au-delà.
CORRIDOR = Vector3.new(1000, 3, 0)
do
	local zone = InstanceAPI.new("Part")
	zone.Name = "SafeZone"
	zone.Size = Vector3.new(800, 60, 200)
	zone.CFrame = CFrame.new(300, 20, 0)
	zone.CanCollide = false
	zone.CanQuery = false
	zone.Parent = greybox
	addTag(zone, "SafeZone")
end

local function makePlayer(name, userId)
	local p = InstanceAPI.new("Player")
	p.Name = name
	p.UserId = userId
	p.DisplayName = name
	local character = InstanceAPI.new("Model")
	character.Name = name
	local root = InstanceAPI.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = character
	character.Parent = Workspace
	p.Character = character
	p.Parent = Players
	return p, root
end

---------------------------------------------------------------- aides
local function bench(plot, i)
	return plot:FindFirstChild(string.format("DisplaySlot_%02d", i), true)
end
local function state(plot, i)
	return bench(plot, i):GetAttribute("UnboxState")
end
-- a51 (L-089) : point du sol n° i (8 studs devant l'établi i, à la suite au-delà de 4) et colis posé n° i
-- (uid noté dans SLOT_UIDS[joueur][i]) : son modèle FloorBox et son invite.
SLOT_UIDS = {}
local function spot(plot, i)
	local x = plot.PrimaryPart.Position.X - 9
	return Vector3.new(x + (i - 1) * 6, 0, 8)
end
local function boxModel(plot, i)
	local wanted = {}
	for _, byPlayer in SLOT_UIDS do
		if byPlayer[i] then
			wanted[byPlayer[i]] = true
		end
	end
	for _, child in plot:GetChildren() do
		if child.Name == "FloorBox" and wanted[child:GetAttribute("BoxUid")] then
			return child
		end
	end
	return nil
end
local function prompt(plot, i)
	local m = boxModel(plot, i)
	return m and m:FindFirstChild("UnboxPrompt", true)
end
local function standAt(root, position)
	root.CFrame = CFrame.new(position.X, position.Y, position.Z)
end
local function nearBench(root, plot, i)
	standAt(root, spot(plot, i) + Vector3.new(0, 3, 3))
end
local function timerLabel(plot, i)
	local m = boxModel(plot, i)
	local gui = m and m:FindFirstChild("OpenTimer", true)
	return gui and gui:FindFirstChild("Label", true)
end
local function fire(player, name, ...)
	ReplicatedStorage.Remotes[name].OnServerEvent:Fire(player, ...)
end
local function payload(tier, zone, rarity, itemId)
	return { Kind = "NPCBox", Tier = tier, Zone = zone, Rarity = rarity, ItemId = itemId, StoreId = "STORE_Test", SlotId = "ShelfSlot_01" }
end
local function newData()
	return {
		Version = 1,
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
local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end
local function notifies(player, text)
	local n = 0
	for _, e in REMOTE_LOG do
		if e.name == "Notify" and e.to == player and (text == nil or string.find(e.args[1], text, 1, true)) then
			n += 1
		end
	end
	return n
end
local function remotesTo(name, player)
	local out = {}
	for _, e in REMOTE_LOG do
		if e.name == name and e.to == player then
			table.insert(out, e)
		end
	end
	return out
end
-- L'objet est-il visible avant l'ouverture : nom, attribut du Workspace, ou argument d'un remote
-- autre que UnboxReveal ?
local function exposed(itemId)
	for _, d in Workspace:GetDescendants() do
		if string.find(d.Name, itemId, 1, true) then
			return "nom " .. d:GetFullName()
		end
		for k, v in rawget(d, "_attrs") do
			if v == itemId then
				return "attribut " .. k .. " de " .. d:GetFullName()
			end
		end
	end
	for _, p in Players:GetPlayers() do
		for k, v in rawget(p, "_attrs") do
			if v == itemId then
				return "attribut " .. k .. " du Player"
			end
		end
	end
	for _, e in REMOTE_LOG do
		if e.name ~= "UnboxReveal" then
			for i = 1, e.args.n do
				if e.args[i] == itemId then
					return "remote " .. e.name
				end
			end
		end
	end
	return nil
end
local function played(name)
	local n = 0
	for _, x in ANIM.played do
		if x == name then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- démarrage
local P1, root1 = makePlayer("Alice", 101)
local P2, root2 = makePlayer("Bob", 102)

local Unbox = requireModule(unboxModule, "server")
local Data = requireModule(dataModule, "server")
local Plots = requireModule(plotModule, "server")
local Carry = requireModule(carryModule, "server")
local AC = requireModule(acModule, "server")
local Display = requireModule(displayModule, "server")
local Rarities = requireModule(ReplicatedStorage.Shared.Config.Rarities, "server")
ANIM = requireModule(animModule, "client")

Unbox.Init()
-- Copie a23 : pas d'amélioration du colis dans ces scénarios (DEV-019) ; elle est testée par a23-banc.
Unbox.GetLuck = function()
	return 0
end
local placed, opened = {}, {}
Unbox.OnBoxPlaced(function(p, i, box)
	table.insert(placed, { p = p, i = i, box = box })
end)
Unbox.OnBoxOpened(function(p, i, uid, itemId)
	table.insert(opened, { p = p, i = i, uid = uid, itemId = itemId })
end)

CLIENT_PLAYER = P1
Players.LocalPlayer = P1
local Controller = requireModule(controllerModule, "client")
taskLib.spawn(Controller.Start)
step(0.1)

print("\n== A. Arrivée : profil puis parcelle")
local d1 = newData()
Data._load(P1, d1)
step(0.1)
check(state(plot1, 1) == nil, "A1 profil chargé sans parcelle : aucun état posé")
Plots._assign(P1, plot1)
local d2 = newData()
Data._load(P2, d2)
Plots._assign(P2, plot2)
step(0.1)
check(state(plot1, 1) == "Free", "A2 présentoir 1 libre (UnboxState pour la pose d'un objet)")
check(state(plot1, 2) == "Locked" and state(plot1, 3) == "Locked" and state(plot1, 4) == "Locked", "A3 présentoirs 2 à 4 verrouillés")
check(state(plot2, 1) == "Free", "A4 parcelle de Bob : présentoir 1 libre")
check(bench(plot1, 1):FindFirstChild("UnboxPrompt") == nil, "A5 L-089 : plus d'invite de colis sur les présentoirs")
check(logHas("Alice : 0 colis remis au sol"), "A9 sortie Studio de l'arrivée")

print("\n== B. Porter un colis dans le couloir")
standAt(root1, CORRIDOR)
Carry._carry(P1, payload("Premium", 3, "Rare", "Z3_Smartphone"))
step(1)
check(Carry.IsCarrying(P1) and next(d1.Boxes) == nil, "B1 dans le couloir : le colis reste sur la tête")
check(exposed("Z3_Smartphone") == nil, "B3 l'objet porté n'est visible nulle part")

print("\n== C. Rangé à l'entrée de la zone safe, puis posé au sol")
nearBench(root1, plot1, 1)
step(0.3)
local uid1, stored = next(d1.Boxes)
check(uid1 ~= nil and stored.Spot == nil and stored.ReadyAt == nil and stored.ItemId == "Z3_Smartphone", "C0 rangé dans l'inventaire (Boxes[uid], sans Spot ni ReadyAt)")
check(not Carry.IsCarrying(P1) and P1:GetAttribute("Carrying") == nil and #Carry.consumed == 1, "C3 colis retiré au porteur (Consume)")
check(d1.Lifetime.Heists == 1 and notifies(P1, "Box saved to your inventory") == 1, "C3b braquage compté, Notify « Box saved… »")
SLOT_UIDS[P1] = { [1] = uid1 }
local t0 = now()
fire(P1, "PlaceBox", uid1, spot(plot1, 1))
step(0.05)
local box = d1.Boxes[uid1]
check(box ~= nil and box.Spot ~= nil and box.Tier == "Premium" and box.Zone == 3 and box.ItemId == "Z3_Smartphone" and box.Rarity == "Rare", "C1 posé : Spot dans le profil, contenu gardé")
check(box ~= nil and near(box.ReadyAt, EPOCH + t0 + 45, 1e-6), "C2 ReadyAt = heure serveur + 45 s (Rare, 7.3)")
local m1 = boxModel(plot1, 1)
check(m1 ~= nil and m1.Parent == plot1 and m1:GetAttribute("Rarity") == "Rare" and m1:GetAttribute("BoxUid") == uid1 and m1:GetAttribute("OwnerUserId") == 101, "C5 FloorBox dans la parcelle (Rarity, BoxUid, OwnerUserId)")
check(m1 ~= nil and near(m1:GetAttribute("ReadyAt"), box.ReadyAt, 1e-6) and m1:GetAttribute("UnboxState") == "Waiting", "C6 attributs ReadyAt et UnboxState « Waiting »")
local block = m1 and m1:FindFirstChild("Block")
check(block ~= nil and sameColor(block.Color, Rarities.ById.Rare.Color), "C7 bloc V0 teint à la couleur Rare")
check(block ~= nil and (block.Position - (spot(plot1, 1) + Vector3.new(0, 1, 0))).Magnitude < 1e-6, "C8 bloc posé sur le sol, au point visé")
check(block ~= nil and block.Anchored and not block.CanCollide and not block.CanTouch and not block.CanQuery, "C9 bloc ancré, sans collision")
check(timerLabel(plot1, 1) ~= nil and timerLabel(plot1, 1).Text == "0:45", "C10 minuteur V0 « 0:45 »")
step(0.05)
check(prompt(plot1, 1) ~= nil and not prompt(plot1, 1).Enabled and prompt(plot1, 1).ActionText == "Open", "C11 invite « Open » sur le colis, cachée pendant l'attente")
check(prompt(plot1, 1).RequiresLineOfSight == false and prompt(plot1, 1).MaxActivationDistance == 8, "C11b invite : portée 8, sans ligne de vue")
check(#placed == 1 and placed[1].i == uid1 and placed[1].box.ItemId == "Z3_Smartphone", "C13 OnBoxPlaced(player, uid, colis)")
placed[1].box.ReadyAt = 0
check(d1.Boxes[uid1].ReadyAt ~= 0, "C14 OnBoxPlaced reçoit une copie")
check(exposed("Z3_Smartphone") == nil, "C15 objet toujours caché (ni nom, ni attribut, ni remote)")
check(logHas("colis Premium Rare posé au sol"), "C16 sortie Studio de la pose")

print("\n== D. Attente")
step(10)
local text = timerLabel(plot1, 1).Text
check(text == "0:35" or text == "0:36", "D1 minuteur qui descend (" .. text .. ")")
step(34.4) -- t0 + 44,55
check(#remotesTo("BoxReady", P1) == 0 and boxModel(plot1, 1):GetAttribute("UnboxState") == "Waiting", "D2 pas prêt à 44,5 s")
fire(P1, "OpenBox", uid1)
step(0.05)
check(count(d1.Items) == 0 and d1.Boxes[uid1] ~= nil, "D3 OpenBox avant la fin refusé")
check(notifies(P1, "isn't ready yet") == 1, "D4 Notify « pas encore prêt »")
step(0.75) -- t0 + 45,35
local readies = remotesTo("BoxReady", P1)
check(#readies == 1 and readies[1].args[1] == uid1, "D5 BoxReady(boxUid) envoyé une fois à l'heure")
print("   BoxReady à t0 + " .. tostring(readies[1] and (readies[1].t - t0)))
check(readies[1] ~= nil and readies[1].t - t0 >= 45 - 1e-6 and readies[1].t - t0 < 45.3, "D6 BoxReady entre 45 et 45,3 s (à 1 µs près : flottants à l’échelle de l’heure Unix)")
check(timerLabel(plot1, 1).Text == "Ready!", "D7 minuteur « Ready! »")
check(boxModel(plot1, 1):GetAttribute("UnboxState") == "Ready", "D8 colis prêt (UnboxState « Ready »)")
check(prompt(plot1, 1).Enabled and prompt(plot1, 1).ActionText == "Open", "D9 invite « Open » montrée")
check(logHas("le colis " .. uid1 .. " est prêt"), "D10 le client écrit BoxReady dans la sortie")
step(3)
check(#remotesTo("BoxReady", P1) == 1, "D11 BoxReady pas répété")
check(exposed("Z3_Smartphone") == nil, "D12 objet toujours caché")

print("\n== E. Ouvrir (par l'invite)")
prompt(plot1, 1).Triggered:Fire(P1)
step(0.05)
local uid, item = next(d1.Items)
check(uid ~= nil and item.Id == "Z3_Smartphone" and item.Source == "NPC" and item.At == math.floor(EPOCH + now()), "E1 objet dans Items { Id, Source = NPC, At = os.time() }")
check(uid ~= nil and #uid == 36, "E2 uid de 36 caractères (GUID sans accolades)")
check(d1.Boxes[uid1] == nil and boxModel(plot1, 1) == nil, "E3 colis retiré du profil et du sol")
local reveals = remotesTo("UnboxReveal", P1)
check(#reveals == 1 and reveals[1].args.n == 7 and reveals[1].args[1] == uid1 and reveals[1].args[2] == uid and reveals[1].args[3] == "Z3_Smartphone" and reveals[1].args[4] == 3 and reveals[1].args[5] == "Premium" and reveals[1].args[6] == "Rare" and reveals[1].args[7] == 0, "E5 UnboxReveal(boxUid, uid, itemId, zone 3, Premium, Rare, 0 cran)")
check(#Display.calls == 0, "E6 L-089 : l'objet va dans l'inventaire (pas de PlaceAuto)")
check(#opened == 1 and opened[1].uid == uid and opened[1].i == uid1 and opened[1].itemId == "Z3_Smartphone", "E8 OnBoxOpened(player, boxUid, uid, itemId)")
check(logHas("[Unbox] colis " .. uid1 .. " : RARE · Smartphone · 300 $/s"), "E9 révélation écrite côté client (Rare zone 3 = 300 $/s)")
check(played("Unbox") == 1, "E10 animation Unbox jouée (sans écran UI_Unbox)")
check(logHas("Z3_Smartphone dans l'inventaire"), "E12 sortie Studio : l'objet va dans l'inventaire")

print("\n== F. Refus de PlaceBox")
nearBench(root1, plot1, 1)
Carry._carry(P1, payload("Standard", 1, "Common", "Z1_CanetteDeSoda"))
step(0.3)
local u2 = nil
for key, b in d1.Boxes do
	if b.Spot == nil then
		u2 = key
	end
end
check(u2 ~= nil, "F0 un colis Commun dans l'inventaire")
local function refused(label, point, pattern, at)
	step(0.3)
	local before = notifies(P1, pattern)
	if at then
		standAt(root1, at)
	end
	fire(P1, "PlaceBox", u2, point)
	step(0.05)
	check(d1.Boxes[u2].Spot == nil and notifies(P1, pattern) == before + 1, label)
end
refused("F1 hors de Bounds : refusé", Vector3.new(0, 0, 25), "inside your own shop")
refused("F2 dans la boutique de Bob : refusé", spot(plot2, 1), "inside your own shop", spot(plot2, 1) + Vector3.new(0, 3, 3))
nearBench(root1, plot1, 1)
refused("F3 trop loin du personnage : refusé", spot(plot1, 4) + Vector3.new(0, 0, 6), "Get closer")
refused("F4 sur un établi (son dessus n'est pas le sol) : refusé", bench(plot1, 2).WorldPosition, "on the floor")
refused("F5 contre un présentoir : refusé", Vector3.new(6, 0, 2), "No room here")
step(0.3)
fire(P1, "PlaceBox", "pas-un-colis", spot(plot1, 2))
step(0.05)
check(logHas("PlaceBox(pas-un-colis) refusé : aucun colis de ce nom"), "F6 colis inconnu : refusé")
Carry._carry(P1, payload("Standard", 1, "Common", "Z1_CanetteDeSoda"))
step(0.3)
-- Le colis porté vient d'être rangé : il en faut un qui reste porté (couloir).
standAt(root1, CORRIDOR)
Carry._carry(P1, payload("Standard", 1, "Common", "Z1_Donut"))
fire(P1, "PlaceBox", u2, spot(plot1, 2))
step(0.05)
check(d1.Boxes[u2].Spot == nil and logHas("refusé : porte déjà quelque chose"), "F7 porte un colis : refusé")
nearBench(root1, plot1, 2)
step(0.3)
fire(P1, "PlaceBox", u2, spot(plot1, 2))
step(0.05)
check(d1.Boxes[u2].Spot ~= nil, "F8 au sol, à portée : accepté")
SLOT_UIDS[P1][2] = u2
step(0.3)
fire(P1, "PlaceBox", u2, spot(plot1, 3))
step(0.05)
check(near(d1.Boxes[u2].Spot.X, (spot(plot1, 2) - plot1:GetPivot().Position).X, 0.02) and logHas("refusé : colis déjà posé"), "F9 déjà posé : refusé, il ne bouge pas")

print("\n== G. Refus d'OpenBox et doublons")
fire(P1, "OpenBox", "pas-un-colis")
step(0.3)
check(logHas("OpenBox(pas-un-colis) refusé : aucun colis posé de ce nom"), "G1 colis inconnu : refusé")
step(Rarities.ById.Common.OpenDelay + 0.5)
standAt(root1, spot(plot1, 2) + Vector3.new(0, 3, 20))
fire(P1, "OpenBox", u2)
step(0.3)
check(d1.Boxes[u2] ~= nil and logHas("trop loin du colis"), "G2 trop loin : refusé")
standAt(root2, spot(plot1, 2) + Vector3.new(0, 3, 2))
fire(P2, "OpenBox", u2)
step(0.3)
check(d1.Boxes[u2] ~= nil and count(d2.Items) == 0, "G3 Bob ne peut pas ouvrir le colis d'Alice")
nearBench(root1, plot1, 2)
local before = count(d1.Items)
fire(P1, "OpenBox", u2)
fire(P1, "OpenBox", u2)
step(0.3)
check(count(d1.Items) == before + 1 and #remotesTo("UnboxReveal", P1) == 2, "G4 deux OpenBox d'affilée : un seul objet")

print("\n== H. Présentoirs (UnboxState, pour la pose d'un objet)")
d1.Upgrades.UnboxBenches = 2
Unbox.Refresh(P1)
check(state(plot1, 2) == "Free" and state(plot1, 3) == "Free" and state(plot1, 4) == "Locked", "H2 niveau 2 : 3 présentoirs libres")
d1.Upgrades.UnboxBenches = 99
Unbox.Refresh(P1)
check(state(plot1, 4) == "Free", "H3 niveau 99 : plafonné à 4")
d1.Upgrades.UnboxBenches = 3
Unbox.Refresh(P1)

print("\n== N. Client : streaming")
-- Un colis posé qui attend : son invite suit son modèle.
local function stowAndPlace(i, p)
	nearBench(root1, plot1, i)
	local known = {}
	for key in d1.Boxes do
		known[key] = true
	end
	Carry._carry(P1, p)
	step(0.3)
	local u = nil
	for key in d1.Boxes do
		if not known[key] then
			u = key
		end
	end
	SLOT_UIDS[P1][i] = u
	fire(P1, "PlaceBox", u, spot(plot1, i))
	step(0.05)
	return u
end
local u3 = stowAndPlace(3, payload("Standard", 2, "Uncommon", "Z2_YoYo"))
step(0.05)
local m3 = boxModel(plot1, 3)
local oldPrompt = prompt(plot1, 3)
check(m3 ~= nil and oldPrompt ~= nil, "N1 invite sur le colis posé n° 3")
m3.Parent = nil
step(0.05)
check(oldPrompt.Parent == nil, "N2 colis sorti de la zone chargée : son invite est retirée")
m3.Parent = plot1
step(0.05)
check(prompt(plot1, 3) ~= nil and prompt(plot1, 3) ~= oldPrompt, "N3 colis revenu : nouvelle invite")

print("\n== I. Attente raccourcie (GetOpenDelay remplacé)")
clearLog()
Unbox.GetOpenDelay = function(_player, b)
	return if b.Rarity == "Rare" then 5 else 0
end
local tI = now()
local uI1 = stowAndPlace(4, payload("Premium", 1, "Rare", "Z1_PotDeNouilles"))
check(near(d1.Boxes[uI1].ReadyAt, EPOCH + tI + 0.3 + 5, 1e-6), "I1 attente de 5 s (tutoriel)")
local readyBefore = #remotesTo("BoxReady", P1)
local uI2 = stowAndPlace(5, payload("Standard", 1, "Common", "Z1_CanetteDeSoda"))
check(#remotesTo("BoxReady", P1) == readyBefore + 1 and boxModel(plot1, 5):GetAttribute("UnboxState") == "Ready", "I2 attente 0 : prêt tout de suite")
Unbox.GetOpenDelay = function()
	return -1
end
local tI3 = now()
local uI3 = stowAndPlace(6, payload("Standard", 2, "Uncommon", "Z2_YoYo"))
check(near(d1.Boxes[uI3].ReadyAt, EPOCH + tI3 + 0.3 + 20, 1e-6) and logHas("valeur invalide", "WARN"), "I3 valeur invalide : attente de la rareté (20 s)")
Unbox.GetOpenDelay = function()
	error("panne")
end
local tI4 = now()
local uI4 = stowAndPlace(7, payload("Standard", 1, "Epic", "Z1_BoissonEnergisante"))
check(d1.Boxes[uI4] ~= nil and near(d1.Boxes[uI4].ReadyAt, EPOCH + tI4 + 0.3 + 90, 1e-6), "I4 GetOpenDelay en erreur : attente de la rareté (90 s)")
Unbox.GetOpenDelay = function(_player, b)
	return Rarities.ById[b.Rarity].OpenDelay
end

print("\n== J. Hors ligne : départ, attente, retour")
step(6)
local readyEpicAt = d1.Boxes[uI4].ReadyAt
Plots._release(P1)
Data._release(P1)
Players.PlayerRemoving:Fire(P1)
P1.Parent = nil
step(0.1)
check(boxModel(plot1, 4) == nil and boxModel(plot1, 7) == nil, "J1 départ : colis retirés du monde")
check(state(plot1, 1) == nil, "J2 départ : attributs UnboxState retirés")
check(d1.Boxes[uI1] ~= nil and d1.Boxes[uI4] ~= nil and d1.Boxes[uI1].Spot ~= nil, "J3 colis posés gardés dans le profil")
local logCount = #REMOTE_LOG
step(60)
check(#REMOTE_LOG == logCount, "J4 rien n'est envoyé à un joueur parti")
local P1b, root1b = makePlayer("Alice", 101)
SLOT_UIDS[P1b] = SLOT_UIDS[P1]
Data._load(P1b, d1)
Plots._assign(P1b, plot1)
step(0.05)
local readyNow = {}
for _, e in remotesTo("BoxReady", P1b) do
	readyNow[e.args[1]] = true
end
check(readyNow[uI1] and readyNow[uI2] and not readyNow[uI4], "J5 au retour : BoxReady pour les colis prêts, pas pour l'Épique")
check(boxModel(plot1, 4) ~= nil and boxModel(plot1, 7) ~= nil, "J6 colis remis au sol, à leur place")
local remaining = readyEpicAt - (EPOCH + now())
local expected = string.format("%d:%02d", math.floor(math.ceil(remaining) / 60), math.ceil(remaining) % 60)
check(timerLabel(plot1, 7).Text == expected, "J7 minuteur de l'Épique repris où il en est (" .. timerLabel(plot1, 7).Text .. ")")
step(remaining + 0.3)
local last = remotesTo("BoxReady", P1b)
check(last[#last].args[1] == uI4, "J9 BoxReady de l'Épique à l'heure")
CLIENT_PLAYER = P1b

print("\n== K. Inventaire plein")
clearLog()
Display.inventoryRoom = false
nearBench(root1b, plot1, 4)
local calls0 = #Display.calls
fire(P1b, "OpenBox", uI1)
step(0.3)
check(d1.Boxes[uI1] == nil and #Display.calls == calls0 + 1, "K1 inventaire plein, présentoir libre : ouvert, l'objet va sur un présentoir (PlaceAuto)")
Display.HasRoom = function()
	return false
end
nearBench(root1b, plot1, 5)
fire(P1b, "OpenBox", uI2)
step(0.3)
check(d1.Boxes[uI2] ~= nil and notifies(P1b, "Inventory full") == 1, "K2 inventaire et présentoirs pleins : refusé, colis gardé")
Display.HasRoom = function()
	return true
end
Display.inventoryRoom = true
fire(P1b, "OpenBox", uI2)
step(0.3)
check(d1.Boxes[uI2] == nil, "K3 de la place : ouvert")

print("\n== L. Modèles livrés par Clément")
local assets = folder(ReplicatedStorage, "Assets")
local boxes = folder(assets, "Boxes")
local luxe = InstanceAPI.new("Model")
luxe.Name = "BOX_Luxe"
luxe.WorldPivot = CFrame.new(0, 0, 0)
for _, spec in { { "Body", 0.9 }, { "Lid", 1.9 }, { "Tint", 1 } } do
	local p = InstanceAPI.new("Part")
	p.Name = spec[1]
	p.Size = Vector3.new(2, 1.8, 2)
	p.CFrame = CFrame.new(0, spec[2], 0)
	p.Parent = luxe
end
local carryAttachment = InstanceAPI.new("Attachment")
carryAttachment.Name = "CarryAttachment"
carryAttachment.Parent = luxe.Body
luxe.Parent = boxes
local ui = folder(assets, "UI")
local bb = InstanceAPI.new("BillboardGui")
bb.Name = "BB_OpenTimer"
bb.StudsOffset = Vector3.new(0, 3, 0)
local bbLabel = InstanceAPI.new("TextLabel")
bbLabel.Name = "Label"
bbLabel.Parent = bb
bb.Parent = ui
-- Le n° 4 est libre depuis K : on y pose le colis Luxe.
P1 = P1b
root1 = root1b
local uL = stowAndPlace(4, payload("Luxe", 5, "Epic", "Z5_StatueDoree"))
local lm = boxModel(plot1, 4)
check(lm ~= nil and lm:FindFirstChild("Lid") ~= nil and lm:FindFirstChild("CarryAttachment", true) ~= nil, "L1 copie de BOX_Luxe (Lid, CarryAttachment)")
check(lm ~= nil and string.sub(lm.Name, 1, 4) ~= "BOX_", "L2 copie renommée sans le préfixe BOX_ (FloorBox)")
check(lm ~= nil and sameColor(lm.Tint.Color, Rarities.ById.Epic.Color), "L3 pièce Tint teinte à la couleur Épique")
check(lm ~= nil and lm.Body.Anchored and not lm.Body.CanCollide and not lm.Lid.CanQuery, "L4 pièces ancrées, sans collision")
check(lm ~= nil and (lm.WorldPivot.Position - spot(plot1, 4)).Magnitude < 1e-6, "L5 pivot du modèle sur le point du sol")
local lt = lm and lm:FindFirstChild("OpenTimer", true)
check(lt ~= nil and lt.StudsOffset == Vector3.new(0, 3, 0) and lt:FindFirstChild("Label").Text == "1:30", "L6 copie de BB_OpenTimer, réglages de Clément gardés, « 1:30 »")
check(luxe.Parent == boxes and bbLabel.Text == "Label", "L7 modèles d'origine intacts")
check(exposed("Z5_StatueDoree") == nil, "L8 objet caché avec les vrais modèles aussi")
check(uL ~= nil, "L9 colis Luxe posé")

print("\n== M. Colis sauvegardés illisibles")
clearLog()
local P3, root3 = makePlayer("Chloe", 103)
local d3 = newData()
local origin3 = plot3:GetPivot()
local function spotOf(world)
	local p = origin3:PointToObjectSpace(world)
	return { X = p.X, Y = p.Y, Z = p.Z }
end
d3.Boxes.ok = { Tier = "Standard", Zone = 2, ItemId = "Z2_YoYo", Rarity = "Uncommon", ReadyAt = 0, Spot = spotOf(spot(plot3, 1)) }
d3.Boxes.unknown = { Tier = "Standard", Zone = 2, ItemId = "Z9_Disparu", Rarity = "Common", ReadyAt = 0, Spot = spotOf(spot(plot3, 2)) }
d3.Boxes.away = { Tier = "Standard", Zone = 2, ItemId = "Z2_YoYo", Rarity = "Uncommon", ReadyAt = 0, Spot = spotOf(Vector3.new(400, 0, 80)) }
d3.Boxes.stored = { Tier = "Standard", Zone = 2, ItemId = "Z2_YoYo", Rarity = "Uncommon" }
Data._load(P3, d3)
Plots._assign(P3, plot3)
step(0.05)
check(logHas("colis posé unknown (ItemId inconnu", "WARN") and logHas("colis posé away (hors du volume Bounds", "WARN"), "M1 avertissements : objet inconnu, point hors de Bounds")
check(d3.Boxes.unknown ~= nil and d3.Boxes.unknown.Spot == nil and d3.Boxes.away ~= nil and d3.Boxes.away.Spot == nil, "M2 colis illisibles revenus dans l'inventaire, gardés dans le profil")
check(d3.Boxes.ok.Spot ~= nil and d3.Boxes.stored.Spot == nil and #remotesTo("BoxReady", P3) == 1 and remotesTo("BoxReady", P3)[1].args[1] == "ok", "M3 BoxReady seulement pour le colis posé lisible")
check(notifies(P3, "didn't fit in this shop") == 1, "M4 Notify « A box of yours didn't fit in this shop… »")
nearBench(root3, plot3, 2)
fire(P3, "OpenBox", "unknown")
step(0.3)
check(d3.Boxes.unknown ~= nil and count(d3.Items) == 0, "M5 colis illisible : ouverture refusée, rien de perdu")

print("\n== Q. Anti-triche au rangement (correctif DEV-060 du 2026-11-08)")
clearLog()
local plot4 = makePlot(4, 600)
local P4, root4 = makePlayer("Dan", 104)
local d4 = newData()
Data._load(P4, d4)
Plots._assign(P4, plot4)
step(0.05)
local grabAt = CORRIDOR + Vector3.new(0, 0, 40)
standAt(root4, grabAt)
local t4 = now()
Carry._carry(P4, payload("Standard", 1, "Common", "Z1_CanetteDeSoda"))
AC.verdict = false
local verifies, consumed4 = #AC.verifies, #Carry.consumed
nearBench(root4, plot4, 1)
step(0.3)
local v1 = AC.verifies[verifies + 1]
check(v1 ~= nil and v1.player == P4, "Q1 l'entrée dans la zone safe appelle AntiCheatService.Verify")
check(v1 ~= nil and v1.from ~= nil and (v1.from - grabAt).Magnitude < 1e-6, "Q2 Verify reçoit le point de la prise (début du portage)")
check(v1 ~= nil and type(v1.since) == "number" and near(v1.since, t4, 1e-6), "Q3 … et l'heure de la prise (os.clock())")
check(next(d4.Boxes) == nil and #Carry.consumed == consumed4, "Q4 Verify = false : rien n'est rangé, colis pas consommé")
check(logHas("colis pas rangé, déplacement sanctionné par l'anti-triche"), "Q5 sortie Studio du refus")
AC.verdict = true
step(0.3)
local v2 = AC.verifies[#AC.verifies]
check(next(d4.Boxes) ~= nil and not Carry.IsCarrying(P4) and #Carry.consumed == consumed4 + 1, "Q6 Verify = true : colis rangé")
check(v2 ~= nil and v2 ~= v1 and (v2.from - grabAt).Magnitude < 1e-6, "Q7 même portage : même point de prise")
local grab2 = CORRIDOR + Vector3.new(0, 0, -40)
standAt(root4, grab2)
Carry._carry(P4, payload("Standard", 1, "Common", "Z1_Donut"))
nearBench(root4, plot4, 2)
step(0.3)
local v3 = AC.verifies[#AC.verifies]
check(count(d4.Boxes) == 2 and v3 ~= nil and v3 ~= v2 and (v3.from - grab2).Magnitude < 1e-6, "Q8 nouveau portage : nouveau point de prise")

print("\n== O. Sortie")
local warns = 0
for _, line in FULL_LOG do
	if line.kind == "WARN" and string.find(line.text, "[Net] envoi", 1, true) then
		warns += 1
		print("   " .. line.text)
	end
end
check(warns == 0, "O1 aucun envoi mal formé signalé par Net (BoxReady, UnboxReveal, Notify)")

summary()
