-- Prélude du banc a43 : copie telle quelle des lignes 1 à 378 du tests.luau d'a23 (version a26 :
-- a26-banc/a23-banc/tests.luau, 2026-11-08) : bouchons des services voisins, montage de la place,
-- aides (buildUnbox, snapshot, el…) et chargement des modules.
---------------------------------------------------------------- bouchons des services voisins (repris de a13)
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
	for _, fn in assigned do task.spawn(fn, player, plot) end
end
return PlotService
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

SOURCES["stub/CarryService"] = [==[
local CarryService = {}
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
	for _, fn in ended do fn(player, p, "Consumed", "Consumed") end
	return p
end
function CarryService._carry(player, payload)
	carried[player] = payload
	player:SetAttribute("Carrying", payload.Rarity)
	for _, fn in started do fn(player, payload) end
end
-- Ajout a26 : fin du portage sans pose, comme le vrai CarryService.Fail (rattrapé par le vigile,
-- mort, anomalie : le colis retourne sur son rayon) ou Drop (coup de batte : il tombe au sol).
-- Rend le payload, que le test peut redonner à un autre joueur (ramassage, PickUpDrop).
-- a51 (L-089) : fin du portage sans réussite (UnboxService : inventaire de colis plein, colis illisible).
function CarryService.Fail(player, reason)
	local p = carried[player]
	if p == nil then return false end
	carried[player] = nil
	player:SetAttribute("Carrying", nil)
	for _, fn in ended do fn(player, p, "Failed", reason) end
	return true
end
function CarryService._lose(player)
	local p = carried[player]
	carried[player] = nil
	player:SetAttribute("Carrying", nil)
	return p
end
return CarryService
]==]

SOURCES["stub/DisplayService"] = [==[
-- Copie a46 (L-086) : colis posés sur les présentoirs : GetSlots (DisplaySlot_xx de la parcelle),
-- GetSlotStates (4 débloqués, "Boxed" sous un colis), PlaceItem (par PlaceAuto), HasRoom.
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local DisplayService = { calls = {} }
function DisplayService.PlaceAuto(player, uid)
	table.insert(DisplayService.calls, { player = player, uid = uid })
	return 1
end
function DisplayService.PlaceItem(player, uid, _slot)
	return DisplayService.PlaceAuto(player, uid) ~= nil
end
function DisplayService.HasRoom(_player)
	return true
end
-- a51 (L-089) : l'objet ouvert va dans l'inventaire.
function DisplayService.HasInventoryRoom(_player)
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
	for i in DisplayService.GetSlots(player) do
		out[i] = if i > 4 then "Locked" elseif data and data.Boxes[tostring(i)] ~= nil then "Boxed" else "Free"
	end
	return out
end
return DisplayService
]==]

-- AnimationController : `delivered[name]` = l'animation est livrée (PlayPlayer rend une piste) ;
-- fire(anim, marker) simule le passage d'un marqueur.
SOURCES["stub/AnimationController"] = [==[
local AnimationController = { played = {}, delivered = {}, markers = {} }
function AnimationController.PlayPlayer(name)
	table.insert(AnimationController.played, { name = name, t = os.clock() })
	if AnimationController.delivered[name] then return { Name = name } end
	return nil
end
function AnimationController.StopPlayer() end
function AnimationController.OnMarker(anim, marker, cb)
	table.insert(AnimationController.markers, { anim = anim, marker = marker, cb = cb })
	return function() end
end
function AnimationController.fire(anim, marker)
	for _, m in AnimationController.markers do
		if m.anim == anim and m.marker == marker then m.cb() end
	end
end
return AnimationController
]==]

ITEMS_PICKS = {}

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
moduleScript(services, "AntiCheatService", "stub/AntiCheatService")
moduleScript(services, "DisplayService", "stub/DisplayService")

local client = folder(StarterPlayerScripts, "Client")
local controllers = folder(client, "Controllers")
local controllerModule = moduleScript(controllers, "UnboxController", "client/Controllers/UnboxController.luau")
local animModule = moduleScript(controllers, "AnimationController", "stub/AnimationController")
local unboxFolder = folder(controllers, "Unbox")
for _, name in { "Reel", "Sequence", "Screen" } do
	moduleScript(unboxFolder, name, `client/Controllers/Unbox/{name}.luau`)
end
local assets = folder(ReplicatedStorage, "Assets")

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
local function S(x, y)
	return UDim2.fromScale(x, y)
end
local CENTER = Vector2.new(0.5, 0.5)

-- Écran UI_Unbox v2, tel que relevé dans Studio le 2026-11-07 (wave7-studio.md, section 1).
function buildUnbox(parent)
	local gui = new("ScreenGui", { Name = "UI_Unbox", Enabled = false, IgnoreGuiInset = false }, parent)
	local panel = new("Frame", { Name = "RevealPanel", Size = S(0.75, 0.92), Position = S(0.5, 0.52), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 4 }, gui)
	local rarity = new("TextLabel", { Name = "Rarity", Size = S(0.9, 0.13), Position = S(0.5, 0.607), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 5, Text = "LEGENDARY", TextColor3 = Color3.new(1, 0.8, 0.1) }, panel)
	new("UIStroke", { Name = "UIStroke" }, rarity)
	new("UIGradient", { Name = "Rainbow", Enabled = false }, rarity)
	local preview = new("Frame", { Name = "ItemPreview", Size = S(0.225, 0.225), Position = S(0.5, 0.327), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 3 }, panel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, preview)
	local itemName = new("TextLabel", { Name = "ItemName", Size = S(0.85, 0.068), Position = S(0.5, 0.705), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 5, Text = "Winning Scratch Card" }, panel)
	new("UIStroke", { Name = "UIStroke" }, itemName)
	local income = new("TextLabel", { Name = "Income", Size = S(0.5, 0.078), Position = S(0.5, 0.785), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 5, Text = "+$50/s" }, panel)
	new("UIStroke", { Name = "UIStroke" }, income)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, panel)
	local rays = new("ImageLabel", { Name = "Rays", Size = S(0.633, 0.633), Position = S(0.5, 0.327), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 1, Image = "", Rotation = 10 }, panel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, rays)
	new("UIGradient", { Name = "Rainbow", Enabled = false, Rotation = 45 }, rays)
	for i = 1, 8 do
		new("Frame", { Name = string.format("Beam_%02d", i), Rotation = i * 45, BackgroundColor3 = Color3.new(1, 1, 0.8) }, rays)
	end
	local glow = new("Frame", { Name = "Glow", Size = S(0.36, 0.36), Position = S(0.5, 0.327), AnchorPoint = CENTER, BackgroundTransparency = 0.8, ZIndex = 2 }, panel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, glow)
	new("UICorner", { Name = "UICorner" }, glow)
	new("Frame", { Name = "GlowCore", Size = S(0.7, 0.7), Position = S(0.5, 0.5), AnchorPoint = CENTER, BackgroundTransparency = 0.7 }, glow)
	local buttons = new("Frame", { Name = "Buttons", Size = S(0.7, 0.122), Position = S(0.5, 0.917), AnchorPoint = CENTER, BackgroundTransparency = 1, ZIndex = 6 }, panel)
	new("UIListLayout", { Name = "UIListLayout" }, buttons)
	for _, spec in { { "ContinueButton", true, "CONTINUE" }, { "OpenNextButton", false, "OPEN NEXT" } } do
		local button = new("TextButton", { Name = spec[1], Size = S(0.45, 1), Visible = spec[2], BackgroundTransparency = 0, Text = "" }, buttons)
		for _, deco in { "UISizeConstraint", "UICorner", "UIStroke", "UIGradient" } do
			new(deco, { Name = deco }, button)
		end
		new("ImageLabel", { Name = "Studs", Image = "rbxassetid://3014551673" }, button)
		new("TextLabel", { Name = "Label", Text = spec[3] }, button)
	end
	new("Frame", { Name = "Backdrop", Size = S(1, 1), BackgroundTransparency = 0.65, BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 1 }, gui)
	local skip = new("TextButton", { Name = "SkipButton", Size = S(1, 1), Visible = false, BackgroundTransparency = 1, ZIndex = 2, Text = "" }, gui)
	new("TextLabel", { Name = "Label", Size = S(0.3, 0.045), Position = S(0.98, 0.96), Text = "TAP TO SKIP" }, skip)
	local upgrade = new("Frame", { Name = "Upgrade", Size = S(0.42, 0.17), Position = S(0.5, 0.5), AnchorPoint = CENTER, Visible = false, BackgroundTransparency = 1, ZIndex = 3 }, gui)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, upgrade)
	new("TextLabel", { Name = "UpgradeLabel", Size = S(1, 0.55), Position = S(0.5, 0), Text = "UPGRADE!" }, upgrade)
	local upgradeRarity = new("TextLabel", { Name = "UpgradeRarity", Size = S(0.8, 0.42), Position = S(0.5, 1), Text = "UNCOMMON" }, upgrade)
	new("UIStroke", { Name = "UIStroke" }, upgradeRarity)
	new("UIGradient", { Name = "Rainbow", Enabled = false }, upgradeRarity)
	local reel = new("Frame", { Name = "Reel", Size = S(0.2, 0.35), Position = S(0.5, 0.445), AnchorPoint = CENTER, Visible = false, BackgroundTransparency = 1, ZIndex = 3 }, gui)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, reel)
	local reelGlow = new("Frame", { Name = "ReelGlow", Size = S(1.15, 1.15), Position = S(0.5, 0.5), AnchorPoint = CENTER, BackgroundTransparency = 0.55, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1 }, reel)
	new("UIAspectRatioConstraint", { Name = "UIAspectRatioConstraint" }, reelGlow)
	new("UICorner", { Name = "UICorner" }, reelGlow)
	new("Frame", { Name = "GlowCore", Size = S(0.6, 0.6), BackgroundTransparency = 0.6 }, reelGlow)
	new("ViewportFrame", { Name = "ReelView", Size = S(1, 1), BackgroundTransparency = 1, ZIndex = 2, ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0 }, reel)
	local confetti = new("Frame", { Name = "Confetti", Size = S(1, 1), BackgroundTransparency = 1, ZIndex = 6 }, gui)
	local template = new("Frame", { Name = "Template", Size = S(0.011, 0.018), Position = S(0.5, 0.3), Visible = false, BackgroundTransparency = 0 }, confetti)
	new("UIStroke", { Name = "UIStroke" }, template)
	new("Frame", { Name = "Flash", Size = S(1, 1), BackgroundTransparency = 1, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 7 }, gui)
	return gui
end

-- Toutes les propriétés de `root` et de ses descendants (pour vérifier la remise en état).
local function snapshot(root)
	local out = {}
	local list = root:GetDescendants()
	table.insert(list, 1, root)
	for _, inst in list do
		local props = {}
		for k, v in rawget(inst, "_props") do
			props[k] = v
		end
		out[inst] = { props = props, parent = rawget(inst, "_parent") }
	end
	return out
end
local function sameValue(a, b)
	if a == b then
		return true
	end
	if type(a) == "table" and type(b) == "table" then
		for k, v in a do
			if not sameValue(v, rawget(b, k)) then
				return false
			end
		end
		for k in b do
			if rawget(a, k) == nil then
				return false
			end
		end
		return true
	end
	return false
end
-- Différences entre `before` et l'état actuel de `root` : liste de textes.
local function diffSnapshot(before, root)
	local diffs = {}
	local now = snapshot(root)
	for inst, entry in before do
		local current = now[inst]
		if current == nil then
			table.insert(diffs, "disparu : " .. inst.Name)
		else
			if current.parent ~= entry.parent then
				table.insert(diffs, "déplacé : " .. inst.Name)
			end
			for k, v in entry.props do
				if not sameValue(v, current.props[k]) then
					table.insert(diffs, `{inst.Name}.{k} : {tostring(v)} → {tostring(current.props[k])}`)
				end
			end
			for k, v in current.props do
				if entry.props[k] == nil then
					table.insert(diffs, `{inst.Name}.{k} ajouté ({tostring(v)})`)
				end
			end
		end
	end
	for inst in now do
		if before[inst] == nil then
			table.insert(diffs, `ajouté : {inst.ClassName} {inst.Name} dans {inst.Parent and inst.Parent.Name}`)
		end
	end
	return diffs
end

local function el(root, path)
	local current = root
	for segment in string.gmatch(path, "[^%.]+") do
		current = current and current:FindFirstChild(segment, true)
	end
	return current
end

local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function remotesTo(name, player)
	local out = {}
	for _, e in REMOTE_LOG do
		if e.name == name and (player == nil or e.to == player) then
			table.insert(out, e)
		end
	end
	return out
end

-- Random truqué : rend les nombres de `values` dans l'ordre, puis `rest` (défaut 0,99).
local function fakeRng(values, rest)
	local i = 0
	return {
		NextNumber = function(_self)
			i += 1
			local v = values[i]
			return if v ~= nil then v else (rest or 0.99)
		end,
		NextInteger = function(_self, a, _b)
			return a
		end,
	}
end

local function newData()
	return {
		Version = 1,
		Cash = 0,
		Stats = { Speed = 0, Strength = 0 },
		Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 3 },
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

local function soundCount(name)
	local n = 0
	for _, s in SOUNDS_PLAYED do
		if s.name == name then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- chargement
local Config = ReplicatedStorage.Shared.Config
local Unbox = requireModule(Config.Unbox, "server")
local ShelfBoxes = requireModule(Config.ShelfBoxes, "server")
local Rarities = requireModule(Config.Rarities, "server")
local Items = requireModule(Config.Items, "server")
local Formulas = requireModule(Config.Formulas, "server")
local UnboxService = requireModule(unboxModule, "server")
local Data = requireModule(dataModule, "server")
local Plots = requireModule(plotModule, "server")
local Carry = requireModule(carryModule, "server")
local NetS = requireModule(ReplicatedStorage.Shared.Net.Net, "server")

local Reel = requireModule(unboxFolder.Reel, "client")
local Sequence = requireModule(unboxFolder.Sequence, "client")
local ItemsC = requireModule(Config.Items, "client")
local RaritiesC = requireModule(Config.Rarities, "client")
