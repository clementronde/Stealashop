
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
	plot.Parent = greybox
	addTag(plot, "PlayerPlot")
	return plot
end
local plot1 = makePlot(1, 0)
local plot2 = makePlot(2, 200)
local plot3 = makePlot(3, 400)

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
local function prompt(plot, i)
	local b = bench(plot, i)
	return b and b:FindFirstChild("UnboxPrompt")
end
local function standAt(root, position)
	root.CFrame = CFrame.new(position.X, position.Y, position.Z)
end
local function nearBench(root, plot, i)
	standAt(root, bench(plot, i).WorldPosition + Vector3.new(0, 0, 3))
end
local function boxModel(plot, i)
	return plot:FindFirstChild(string.format("StandBox_%02d", i))
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
check(state(plot1, 1) == "Free", "A2 établi 1 libre (StartBenches = 1)")
check(state(plot1, 2) == "Locked" and state(plot1, 3) == "Locked" and state(plot1, 4) == "Locked", "A3 établis 2 à 4 verrouillés")
check(state(plot2, 1) == "Free", "A4 parcelle de Bob : établi 1 libre")
check(prompt(plot1, 1) ~= nil and prompt(plot1, 4) ~= nil, "A5 invites créées sur les 4 établis de sa parcelle")
check(prompt(plot2, 1) == nil, "A6 aucune invite sur la parcelle d'un autre")
check(prompt(plot1, 1).Enabled == false, "A7 invite cachée tant qu'on ne porte rien")
check(prompt(plot1, 1).RequiresLineOfSight == false and prompt(plot1, 1).MaxActivationDistance == 8, "A8 invite : portée 8, sans ligne de vue")
check(logHas("Alice : 0 colis remis sur les présentoirs"), "A9 sortie Studio de l'arrivée")

print("\n== B. Porter un colis")
Carry._carry(P1, payload("Premium", 3, "Rare", "Z3_Smartphone"))
step(0.05)
check(prompt(plot1, 1).Enabled and prompt(plot1, 1).ActionText == "Place Box", "B1 « Poser le colis » sur l'établi libre")
check(not prompt(plot1, 2).Enabled, "B2 rien sur un établi verrouillé")
check(exposed("Z3_Smartphone") == nil, "B3 l'objet porté n'est visible nulle part")

print("\n== C. Poser (par l'invite)")
nearBench(root1, plot1, 1)
local t0 = now()
prompt(plot1, 1).Triggered:Fire(P1)
step(0.05)
local box = d1.Boxes["1"]
check(box ~= nil and box.Tier == "Premium" and box.Zone == 3 and box.ItemId == "Z3_Smartphone" and box.Rarity == "Rare", "C1 Boxes[\"1\"] écrit dans le profil")
check(box ~= nil and near(box.ReadyAt, EPOCH + t0 + 45, 1e-6), "C2 ReadyAt = heure serveur + 45 s (Rare, 7.3)")
check(not Carry.IsCarrying(P1) and P1:GetAttribute("Carrying") == nil and #Carry.consumed == 1, "C3 colis retiré au porteur (Consume)")
check(state(plot1, 1) == "Waiting", "C4 établi en attente")
local m1 = boxModel(plot1, 1)
check(m1 ~= nil and m1.Parent == plot1 and m1:GetAttribute("Rarity") == "Rare", "C5 BenchBox_01 dans la parcelle, attribut Rarity")
check(m1 ~= nil and near(m1:GetAttribute("ReadyAt"), box.ReadyAt, 1e-6), "C6 attribut ReadyAt sur le modèle")
local block = m1 and m1:FindFirstChild("Block")
check(block ~= nil and sameColor(block.Color, Rarities.ById.Rare.Color), "C7 bloc V0 teint à la couleur Rare")
check(block ~= nil and (block.Position - (bench(plot1, 1).WorldPosition + Vector3.new(0, 1, 0))).Magnitude < 1e-6, "C8 bloc posé sur le dessus de l'établi")
check(block ~= nil and block.Anchored and not block.CanCollide and not block.CanTouch and not block.CanQuery, "C9 bloc ancré, sans collision")
check(timerLabel(plot1, 1) ~= nil and timerLabel(plot1, 1).Text == "0:45", "C10 minuteur V0 « 0:45 »")
check(not prompt(plot1, 1).Enabled, "C11 plus d'invite pendant l'attente")
check(played("Place") == 1, "C12 animation Place jouée")
check(#placed == 1 and placed[1].i == 1 and placed[1].box.ItemId == "Z3_Smartphone", "C13 OnBoxPlaced appelé")
placed[1].box.ReadyAt = 0
check(d1.Boxes["1"].ReadyAt ~= 0, "C14 OnBoxPlaced reçoit une copie")
check(exposed("Z3_Smartphone") == nil, "C15 objet toujours caché (ni nom, ni attribut, ni remote)")
check(logHas("colis Premium Rare posé sur le présentoir 1, prêt dans 45 s"), "C16 sortie Studio de la pose")

print("\n== D. Attente")
step(10)
local text = timerLabel(plot1, 1).Text
check(text == "0:35" or text == "0:36", "D1 minuteur qui descend (" .. text .. ")")
step(34.4) -- t0 + 44,55
check(#remotesTo("BoxReady", P1) == 0 and state(plot1, 1) == "Waiting", "D2 pas prêt à 44,5 s")
fire(P1, "OpenBox", 1)
step(0.05)
check(count(d1.Items) == 0 and d1.Boxes["1"] ~= nil, "D3 OpenBox avant la fin refusé")
check(notifies(P1, "isn't ready yet") == 1, "D4 Notify « pas encore prêt »")
step(0.75) -- t0 + 45,35
local readies = remotesTo("BoxReady", P1)
check(#readies == 1 and readies[1].args[1] == 1, "D5 BoxReady(1) envoyé une fois à l'heure")
print("   BoxReady à t0 + " .. tostring(readies[1] and (readies[1].t - t0)))
check(readies[1] ~= nil and readies[1].t - t0 >= 45 - 1e-6 and readies[1].t - t0 < 45.3, "D6 BoxReady entre 45 et 45,3 s (à 1 µs près : flottants à l’échelle de l’heure Unix)")
check(timerLabel(plot1, 1).Text == "Ready!", "D7 minuteur « Prêt ! »")
check(state(plot1, 1) == "Ready", "D8 établi prêt")
check(prompt(plot1, 1).Enabled and prompt(plot1, 1).ActionText == "Open", "D9 invite « Ouvrir »")
check(logHas("le colis du présentoir 1 est prêt"), "D10 le client écrit BoxReady dans la sortie")
step(3)
check(#remotesTo("BoxReady", P1) == 1, "D11 BoxReady pas répété")
check(exposed("Z3_Smartphone") == nil, "D12 objet toujours caché")

print("\n== E. Ouvrir (par l'invite)")
prompt(plot1, 1).Triggered:Fire(P1)
step(0.05)
local uid, item = next(d1.Items)
check(uid ~= nil and item.Id == "Z3_Smartphone" and item.Source == "NPC" and item.At == math.floor(EPOCH + now()), "E1 objet dans Items { Id, Source = NPC, At = os.time() }")
check(uid ~= nil and #uid == 36, "E2 uid de 36 caractères (GUID sans accolades)")
check(d1.Boxes["1"] == nil and boxModel(plot1, 1) == nil, "E3 établi libéré, colis retiré du monde")
check(state(plot1, 1) == "Free", "E4 établi libre")
local reveals = remotesTo("UnboxReveal", P1)
check(#reveals == 1 and reveals[1].args.n == 7 and reveals[1].args[1] == 1 and reveals[1].args[2] == uid and reveals[1].args[3] == "Z3_Smartphone" and reveals[1].args[4] == 3 and reveals[1].args[5] == "Premium" and reveals[1].args[6] == "Rare" and reveals[1].args[7] == 0, "E5 UnboxReveal(1, uid, itemId, zone 3, Premium, Rare, 0 cran) (forme v2, a23)")
check(#Display.calls == 1 and Display.calls[1].uid == uid and Display.calls[1].player == P1, "E6 DisplayService.PlaceAuto(player, uid)")
local revealIndex = table.find(REMOTE_LOG, reveals[1])
check(revealIndex ~= nil and Display.calls[1].remoteCount >= revealIndex, "E7 PlaceAuto appelé après UnboxReveal")
check(#opened == 1 and opened[1].uid == uid and opened[1].itemId == "Z3_Smartphone", "E8 OnBoxOpened appelé")
check(logHas("[Unbox] présentoir 1 : RARE · Smartphone · 300 $/s"), "E9 révélation écrite côté client (Rare zone 3 = 300 $/s)")
check(played("Unbox") == 1, "E10 animation Unbox jouée")
check(not prompt(plot1, 1).Enabled, "E11 invite cachée (rien en main, établi libre)")
check(logHas("exposé sur le présentoir 1"), "E12 sortie Studio de l'exposition")

print("\n== F. Refus de PlaceBox")
clearLog()
fire(P1, "PlaceBox", 1)
step(0.3)
check(d1.Boxes["1"] == nil and logHas("refusé : ne porte rien"), "F1 sans colis : refusé")
Carry._carry(P1, payload("Standard", 1, "Common", "Z1_CanetteDeSoda"))
nearBench(root1, plot1, 2)
fire(P1, "PlaceBox", 2)
step(0.3)
check(d1.Boxes["2"] == nil and Carry.IsCarrying(P1) and notifies(P1, "locked") == 1, "F2 établi verrouillé : refusé, Notify, colis gardé")
standAt(root1, bench(plot1, 1).WorldPosition + Vector3.new(0, 0, 13))
fire(P1, "PlaceBox", 1)
step(0.3)
check(d1.Boxes["1"] == nil and Carry.IsCarrying(P1) and logHas("trop loin"), "F3 à 13 studs : refusé")
standAt(root1, bench(plot1, 1).WorldPosition + Vector3.new(0, 0, 11.5))
fire(P1, "PlaceBox", 1)
step(0.3)
check(d1.Boxes["1"] ~= nil and not Carry.IsCarrying(P1), "F4 à 11,5 studs (portée 8 + marge 4) : accepté")
Carry._carry(P1, payload("Standard", 1, "Common", "Z1_CanetteDeSoda"))
nearBench(root1, plot1, 1)
fire(P1, "PlaceBox", 1)
step(0.3)
check(Carry.IsCarrying(P1) and notifies(P1, "All your stands are full") == 1, "F5 présentoir occupé, seul débloqué : refusé, « All your stands are full »")
Carry._carry(P1, { Kind = "PvPItem", Rarity = "Epic", ItemId = "Z4_DiamantBrut" })
d1.Upgrades.UnboxBenches = 1
Unbox.Refresh(P1)
nearBench(root1, plot1, 2)
fire(P1, "PlaceBox", 2)
step(0.3)
check(d1.Boxes["2"] == nil and logHas("ne porte pas un colis PNJ"), "F6 objet volé à un joueur : refusé")
Carry._carry(P1, payload("Premium", 9, "Rare", "Z3_Smartphone"))
fire(P1, "PlaceBox", 2)
step(0.3)
check(d1.Boxes["2"] == nil and Carry.IsCarrying(P1) and logHas("Zone inconnue", "WARN"), "F7 colis mal formé (zone 9) : refusé, avertissement")
Carry._carry(P1, payload("Premium", 3, "Rare", "Z3_Inconnu"))
fire(P1, "PlaceBox", 2)
step(0.3)
check(d1.Boxes["2"] == nil and logHas("ItemId inconnu", "WARN"), "F8 ItemId inconnu : refusé, avertissement")
-- Bob, debout devant l'établi 1 d'Alice, essaie de poser son colis : seul son propre établi compte.
Carry._carry(P2, payload("Standard", 1, "Common", "Z1_CanetteDeSoda"))
nearBench(root2, plot1, 1)
fire(P2, "PlaceBox", 1)
step(0.3)
check(d2.Boxes["1"] == nil and d1.Boxes["1"].ItemId == "Z1_CanetteDeSoda" and Carry.IsCarrying(P2), "F9 sur la parcelle d'un autre : refusé")
nearBench(root2, plot2, 1)
fire(P2, "PlaceBox", 1)
step(0.3)
check(d2.Boxes["1"] ~= nil and not Carry.IsCarrying(P2), "F10 Bob sur sa propre parcelle : accepté")
fire(P1, "PlaceBox", 0)
fire(P1, "PlaceBox", 5)
step(0.3)
check(logHas("pas de présentoir n° 5"), "F11 numéro 0 refusé par Net, 5 refusé par le service")

print("\n== G. Refus d'OpenBox et doublons")
clearLog()
nearBench(root1, plot1, 3)
fire(P1, "OpenBox", 3)
step(0.3)
check(logHas("aucun colis sur ce présentoir"), "G1 établi vide : refusé")
step(10) -- le Commun (10 s) de l'établi 1 est prêt
standAt(root1, bench(plot1, 1).WorldPosition + Vector3.new(0, 0, 15))
fire(P1, "OpenBox", 1)
step(0.3)
check(d1.Boxes["1"] ~= nil and logHas("trop loin"), "G2 trop loin : refusé")
fire(P2, "OpenBox", 1)
step(0.3)
check(d1.Boxes["1"] ~= nil, "G3 Bob ne peut pas ouvrir le colis d'Alice")
nearBench(root1, plot1, 1)
local before = count(d1.Items)
fire(P1, "OpenBox", 1)
fire(P1, "OpenBox", 1)
step(0.3)
check(count(d1.Items) == before + 1 and #remotesTo("UnboxReveal", P1) == 2, "G4 deux OpenBox d'affilée : un seul objet")

print("\n== H. Améliorations")
d1.Upgrades.UnboxBenches = 0
Unbox.Refresh(P1)
check(state(plot1, 2) == "Locked", "H1 niveau 0 : établi 2 verrouillé")
d1.Upgrades.UnboxBenches = 2
Unbox.Refresh(P1)
check(state(plot1, 2) == "Free" and state(plot1, 3) == "Free" and state(plot1, 4) == "Locked", "H2 niveau 2 : 3 établis")
d1.Upgrades.UnboxBenches = 99
Unbox.Refresh(P1)
check(state(plot1, 4) == "Free", "H3 niveau 99 : plafonné à 4 établis")
d1.Upgrades.UnboxBenches = 3
Unbox.Refresh(P1)

print("\n== N. Client : streaming et port")
-- Alice porte encore le colis mal formé de F8 : « Poser » est proposé sur l'établi libre.
check(prompt(plot1, 1).Enabled and prompt(plot1, 1).ActionText == "Place Box", "N1 « Poser » sur l'établi 1 libre")
local table1 = bench(plot1, 1).Parent
local oldPrompt = prompt(plot1, 1)
table1.Parent = nil
step(0.05)
check(oldPrompt.Parent == nil, "N2 établi sorti de la zone chargée : son invite est retirée")
table1.Parent = plot1
step(0.05)
check(prompt(plot1, 1) ~= nil and prompt(plot1, 1) ~= oldPrompt and prompt(plot1, 1).Enabled, "N3 établi revenu : nouvelle invite, à jour")
Carry.Consume(P1)
step(0.05)
check(not prompt(plot1, 1).Enabled and not prompt(plot1, 2).Enabled, "N4 plus de colis en main : invites « Poser » cachées")

print("\n== I. Attente raccourcie (GetOpenDelay remplacé)")
clearLog()
Unbox.GetOpenDelay = function(_player, b)
	return if b.Rarity == "Rare" then 5 else 0
end
Carry._carry(P1, payload("Premium", 1, "Rare", "Z1_PotDeNouilles"))
nearBench(root1, plot1, 2)
local tI = now()
fire(P1, "PlaceBox", 2)
step(0.05)
check(near(d1.Boxes["2"].ReadyAt, EPOCH + tI + 5, 1e-6), "I1 attente de 5 s (tutoriel)")
step(0.3)
Carry._carry(P1, payload("Standard", 1, "Common", "Z1_CanetteDeSoda"))
nearBench(root1, plot1, 3)
local readyBefore = #remotesTo("BoxReady", P1)
fire(P1, "PlaceBox", 3)
step(0.05)
check(#remotesTo("BoxReady", P1) == readyBefore + 1 and state(plot1, 3) == "Ready", "I2 attente 0 : prêt tout de suite")
step(0.3)
Unbox.GetOpenDelay = function()
	return -1
end
Carry._carry(P1, payload("Standard", 1, "Uncommon", "Z1_PaquetDeChips"))
nearBench(root1, plot1, 4)
local tI3 = now()
fire(P1, "PlaceBox", 4)
step(0.05)
check(near(d1.Boxes["4"].ReadyAt, EPOCH + tI3 + 20, 1e-6) and logHas("valeur invalide", "WARN"), "I3 valeur invalide : attente de la rareté (20 s)")
Unbox.GetOpenDelay = function()
	error("panne")
end
step(0.3)
nearBench(root1, plot1, 3)
fire(P1, "OpenBox", 3)
step(0.3)
Carry._carry(P1, payload("Standard", 1, "Epic", "Z1_BoissonEnergisante"))
local tI4 = now()
fire(P1, "PlaceBox", 3)
step(0.05)
check(d1.Boxes["3"] ~= nil and near(d1.Boxes["3"].ReadyAt, EPOCH + tI4 + 90, 1e-6), "I4 GetOpenDelay en erreur : attente de la rareté (90 s)")
Unbox.GetOpenDelay = function(_player, b)
	return Rarities.ById[b.Rarity].OpenDelay
end

print("\n== J. Hors ligne : départ, attente, retour")
-- État : établi 2 = Rare prêt depuis longtemps, 3 = Épique (90 s), 4 = Peu commun (20 s).
step(2)
local ready3At = d1.Boxes["3"].ReadyAt
Plots._release(P1)
Data._release(P1)
Players.PlayerRemoving:Fire(P1)
P1.Parent = nil
step(0.1)
check(boxModel(plot1, 2) == nil and boxModel(plot1, 3) == nil, "J1 départ : colis retirés du monde")
check(state(plot1, 1) == nil and state(plot1, 3) == nil, "J2 départ : attributs UnboxState retirés")
check(d1.Boxes["2"] ~= nil and d1.Boxes["3"] ~= nil and d1.Boxes["4"] ~= nil, "J3 colis gardés dans le profil")
local logCount = #REMOTE_LOG
step(60)
check(#REMOTE_LOG == logCount, "J4 rien n'est envoyé à un joueur parti")
-- Retour (nouvel objet Player, même profil) : 62 s après la pose de l'Épique, il reste environ 28 s.
local P1b, root1b = makePlayer("Alice", 101)
Data._load(P1b, d1)
Plots._assign(P1b, plot1)
step(0.05)
local readyNow = remotesTo("BoxReady", P1b)
local benchesReady = {}
for _, e in readyNow do
	benchesReady[e.args[1]] = true
end
check(benchesReady[2] and benchesReady[4] and not benchesReady[3], "J5 au retour : BoxReady pour les colis prêts (2 et 4), pas pour l'Épique")
check(boxModel(plot1, 2) ~= nil and boxModel(plot1, 3) ~= nil and boxModel(plot1, 4) ~= nil, "J6 colis remis sur leurs établis")
local remaining = ready3At - (EPOCH + now())
local expected = string.format("%d:%02d", math.floor(math.ceil(remaining) / 60), math.ceil(remaining) % 60)
check(timerLabel(plot1, 3).Text == expected, "J7 minuteur de l'Épique repris où il en est (" .. timerLabel(plot1, 3).Text .. ")")
check(state(plot1, 2) == "Ready" and state(plot1, 3) == "Waiting" and state(plot1, 1) == "Free", "J8 états remis")
step(remaining + 0.3)
check(remotesTo("BoxReady", P1b)[#remotesTo("BoxReady", P1b)].args[1] == 3, "J9 BoxReady de l'Épique à l'heure")

print("\n== K. Inventaire plein (copie a46, L-086 : l'objet reste sur le présentoir de son colis)")
clearLog()
-- 4 présentoirs débloqués (niveau 3), tous pris ; 30 objets en inventaire.
local function fill(n, prefix)
	for i = 1, n do
		d1.Items[prefix .. i] = { Id = "Z1_CanetteDeSoda", Source = "NPC", At = 0 }
	end
end
table.clear(d1.Items)
fill(34, "uid-")
nearBench(root1b, plot1, 2)
CLIENT_PLAYER = P1b
local calls0 = #Display.calls
fire(P1b, "OpenBox", 2)
step(0.3)
check(d1.Boxes["2"] == nil and count(d1.Items) == 35 and #Display.calls == calls0 + 1, "K1 inventaire plein : ouvert quand même, l'objet va sur le présentoir du colis (PlaceItem)")
-- Cas d'erreur : le présentoir ne peut plus garder l'objet (verrouillé), et rien n'a de place.
d1.Upgrades.UnboxBenches = 2 -- le faux DisplayService verrouille le présentoir 4
Display.HasRoom = function()
	return false
end
nearBench(root1b, plot1, 4)
fire(P1b, "OpenBox", 4)
step(0.3)
check(d1.Boxes["4"] ~= nil and notifies(P1b, "Inventory full") == 1, "K2 présentoir verrouillé et plus de place : refusé, colis gardé")
Display.HasRoom = function()
	return true
end
fire(P1b, "OpenBox", 4)
step(0.3)
check(d1.Boxes["4"] == nil, "K3 de la place : ouvert (objet posé ailleurs par PlaceAuto)")
d1.Upgrades.UnboxBenches = 3
table.clear(d1.Items)
table.clear(d1.Display)
table.clear(d1.Vault)

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
Carry._carry(P1b, payload("Luxe", 5, "Epic", "Z5_StatueDoree"))
nearBench(root1b, plot1, 2)
fire(P1b, "PlaceBox", 2)
step(0.05)
local lm = boxModel(plot1, 2)
check(lm ~= nil and lm:FindFirstChild("Lid") ~= nil and lm:FindFirstChild("CarryAttachment", true) ~= nil, "L1 copie de BOX_Luxe (Lid, CarryAttachment)")
check(lm ~= nil and string.sub(lm.Name, 1, 4) ~= "BOX_", "L2 copie renommée sans le préfixe BOX_")
check(lm ~= nil and sameColor(lm.Tint.Color, Rarities.ById.Epic.Color), "L3 pièce Tint teinte à la couleur Épique")
check(lm ~= nil and lm.Body.Anchored and not lm.Body.CanCollide and not lm.Lid.CanQuery, "L4 pièces ancrées, sans collision")
check(lm ~= nil and (lm.WorldPivot.Position - bench(plot1, 2).WorldPosition).Magnitude < 1e-6, "L5 pivot du modèle sur l'établi")
local lt = lm and lm:FindFirstChild("OpenTimer", true)
check(lt ~= nil and lt.StudsOffset == Vector3.new(0, 3, 0) and lt:FindFirstChild("Label").Text == "1:30", "L6 copie de BB_OpenTimer, réglages de Clément gardés, « 1:30 »")
check(luxe.Parent == boxes and bbLabel.Text == "Label", "L7 modèles d'origine intacts")
check(exposed("Z5_StatueDoree") == nil, "L8 objet caché avec les vrais modèles aussi")

print("\n== M. Colis sauvegardés illisibles")
clearLog()
local P3, root3 = makePlayer("Chloe", 103)
local d3 = newData()
d3.Boxes["1"] = { Tier = "Standard", Zone = 2, ItemId = "Z2_YoYo", Rarity = "Uncommon", ReadyAt = 0 }
d3.Boxes["2"] = { Tier = "Standard", Zone = 2, ItemId = "Z9_Disparu", Rarity = "Common", ReadyAt = 0 }
d3.Boxes["7"] = { Tier = "Standard", Zone = 2, ItemId = "Z2_YoYo", Rarity = "Uncommon", ReadyAt = 0 }
Data._load(P3, d3)
Plots._assign(P3, plot3)
step(0.05)
check(logHas("présentoir « 7 », absent", "WARN") and logHas("illisible (ItemId inconnu", "WARN"), "M1 avertissements pour l'établi 7 et l'objet inconnu")
check(d3.Boxes["2"] ~= nil and d3.Boxes["7"] ~= nil, "M2 colis illisibles gardés dans le profil")
check(state(plot3, 1) == "Ready" and state(plot3, 2) == "Waiting", "M3 établi 1 prêt, établi 2 occupé")
check(#remotesTo("BoxReady", P3) == 1, "M4 BoxReady seulement pour le colis lisible")
nearBench(root3, plot3, 2)
fire(P3, "OpenBox", 2)
step(0.3)
check(d3.Boxes["2"] ~= nil and count(d3.Items) == 0, "M5 colis illisible : ouverture refusée, rien de perdu")

print("\n== Q. Anti-triche à la pose (correctif DEV-060 du 2026-11-08)")
clearLog()
local plot4 = makePlot(4, 600)
local P4, root4 = makePlayer("Dan", 104)
local d4 = newData()
Data._load(P4, d4)
Plots._assign(P4, plot4)
step(0.05)
local grabAt = Vector3.new(640, 3, 80)
standAt(root4, grabAt)
local t4 = now()
Carry._carry(P4, payload("Standard", 1, "Common", "Z1_CanetteDeSoda"))
nearBench(root4, plot4, 1)
AC.verdict = false
local verifies, consumed4 = #AC.verifies, #Carry.consumed
fire(P4, "PlaceBox", 1)
step(0.3)
local v1 = AC.verifies[verifies + 1]
check(v1 ~= nil and v1.player == P4 and #AC.verifies == verifies + 1, "Q1 PlaceBox appelle AntiCheatService.Verify, une fois")
check(v1 ~= nil and v1.from ~= nil and (v1.from - grabAt).Magnitude < 1e-6, "Q2 Verify reçoit le point de la prise (début du portage)")
check(v1 ~= nil and type(v1.since) == "number" and near(v1.since, t4, 1e-6), "Q3 … et l'heure de la prise (os.clock())")
check(d4.Boxes["1"] == nil and #Carry.consumed == consumed4 and state(plot4, 1) == "Free", "Q4 Verify = false : rien n'est posé, colis pas consommé")
check(logHas("refusé : déplacement sanctionné par l'anti-triche"), "Q5 sortie Studio du refus")
AC.verdict = true
fire(P4, "PlaceBox", 1)
step(0.3)
local v2 = AC.verifies[#AC.verifies]
check(d4.Boxes["1"] ~= nil and not Carry.IsCarrying(P4) and #Carry.consumed == consumed4 + 1, "Q6 Verify = true : colis posé")
check(v2 ~= nil and v2 ~= v1 and (v2.from - grabAt).Magnitude < 1e-6, "Q7 même portage : même point de prise")
d4.Upgrades.UnboxBenches = 1
Unbox.Refresh(P4)
local grab2 = Vector3.new(700, 3, -40)
standAt(root4, grab2)
Carry._carry(P4, payload("Standard", 1, "Common", "Z1_Donut"))
nearBench(root4, plot4, 2)
fire(P4, "PlaceBox", 2)
step(0.3)
local v3 = AC.verifies[#AC.verifies]
check(d4.Boxes["2"] ~= nil and v3 ~= nil and v3 ~= v2 and (v3.from - grab2).Magnitude < 1e-6, "Q8 nouveau portage : nouveau point de prise")

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
