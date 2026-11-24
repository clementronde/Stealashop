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
-- a51 : fin du portage sans réussite (UnboxService : inventaire de colis plein, colis illisible).
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
-- Copie a46 (L-086) : les colis se posent sur les présentoirs. GetSlots trouve les DisplaySlot_xx de la
-- parcelle, GetSlotStates les dit "Locked" au-delà de `unlocked` (4), "Boxed" sous un colis, sinon
-- "Free" (jamais "Taken" : le faux PlaceItem ne garde rien, comme le PlaceAuto d avant, et le même
-- présentoir peut reprendre un colis). PlaceItem passe par PlaceAuto (les scénarios le remplacent).
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local DisplayService = { calls = {}, unlocked = 4 }
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
-- a51 (L-089) : l'objet ouvert va dans l'inventaire tant qu'il y a de la place.
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
	for i in DisplayService.GetSlots(player) do
		out[i] = if i > DisplayService.unlocked then "Locked" elseif data and data.Boxes[tostring(i)] ~= nil then "Boxed" else "Free"
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

print("\n== A. Config/Unbox et ShelfBoxes.OddsFor")
do
	check(Unbox.UpgradeMax == 2 and Unbox.UpgradeChance == 0.10 and Unbox.UpgradeStep == 0.9 and Unbox.UpgradeCharge == 0.5, "A1 amélioration : 2 crans, 10 %, 0,9 s, charge 0,5 s (spec)")
	check(Unbox.UpgradeConfetti == 22 and Unbox.OpenFallback == 0.45 and Unbox.ReelExit == 0.4, "A2 22 confettis, secours 0,45 s, sortie 0,4 s (spec)")
	check(Unbox.ReelDuration.Full == 3.2 and Unbox.ReelDuration.Short == 1.3 and Unbox.ReelCount.Full == 24 and Unbox.ReelCount.Short == 10, "A3 rouleau 3,2 s / 1,3 s, 24 / 10 objets (spec)")
	check(Unbox.ReelAccel == 0.25 and Unbox.ReelBrake == 4 and Unbox.ReelSpin == 0.15 and Unbox.ReelLead == 3, "A4 Ta 0,25, p 4, 0,15 tour/s, W = 3 + L (spec)")
	check(Unbox.NearMissChance == 0.40 and Unbox.NearMissStop == 0.45 and Unbox.LastNotch == 0.3 and Unbox.StopPause == 0.25 and Unbox.ColorIn == 0.3, "A5 frôlement 40 %, 45 %, dernier cran 0,3, pause 0,25, couleurs 0,3 (spec)")
	check(Unbox.FlashTime == 0.1 and Unbox.ItemMove == 0.45 and Unbox.ItemMoveScale == 1.3 and Unbox.RaysSpin == 0.06, "A6 flash 100 ms, objet 0,45 s ×1,3, rayons 0,06 tour/s (spec)")
	local burst = Unbox.ConfettiBurst
	check(burst.Uncommon == 16 and burst.Rare == 30 and burst.Epic == 46 and burst.Legendary == 70 and burst.Mythic == 90 and burst.Secret == 120 and burst.Common == nil, "A7 confettis 16/30/46/70/90/120 (spec), aucun pour un Commun")
	check(Unbox.SlowMotionScale == 0.3 and Unbox.SlowMotionTime == 0.5 and Unbox.RaritySlamFrom == 2.3 and Unbox.RaritySlam == 0.3, "A8 ralenti ×0,3 pendant 0,5 s ; Rarity 2,3 → 1 en 0,3 s (spec)")
	check(Unbox.ItemNameAfter == 0.18 and Unbox.IncomeAfter == 0.12 and Unbox.IncomeCount.Full == 0.9 and Unbox.IncomeCount.Short == 0.45 and Unbox.ButtonsAfter == 0.35, "A9 textes +0,18 / +0,12, comptage 0,9 / 0,45, boutons +0,35 (spec)")
	check(Unbox.SkipGlide == 0.4 and Unbox.TickMaxRate == 35 and Unbox.HeartbeatBelow == 3.5 and Unbox.HeartbeatEvery == 0.55, "A10 passer 0,4 s, tic ≤ 35/s, cœur < 3,5 objets/s toutes les 0,55 s (spec)")
	check(Unbox.PromptDistance == 8 and Unbox.ReachTolerance == 4, "A11 portée inchangée : 8 + 4 studs")
	check(not pcall(function() (Unbox :: any).UpgradeChance = 1 end) and not pcall(function() (Unbox.ReelDuration :: any).Full = 1 end), "A12 Config/Unbox gelé (DeepFreeze)")
	local z1 = ShelfBoxes.OddsFor(1, "Premium")
	check(z1 ~= nil and z1.Common == 100 and (z1.Rare or 0) == 0, "A13 OddsFor(1, Premium) : Communs seulement (ZoneOdds, L-033)")
	check(ShelfBoxes.OddsFor(3, "Luxe") == Rarities.BoxOdds.Luxe and ShelfBoxes.OddsFor(6, "Standard") == Rarities.BoxOdds.Standard, "A14 OddsFor hors zone 1 : Rarities.BoxOdds[tier]")
	check(ShelfBoxes.OddsFor(3, "Inconnu") == nil and ShelfBoxes.OddsFor(1, "Inconnu") == nil, "A15 OddsFor d'un type inconnu : nil")
end

print("\n== B. Règle d'amélioration (UnboxService.RollUpgrades)")
do
	local function box(tier, zone, rarity)
		local item = Items.ByZone[zone] and Items.ByZone[zone][rarity] and Items.ByZone[zone][rarity][1]
		return { Tier = tier, Zone = zone, Rarity = rarity, ItemId = item and item.Id or "Z1_Banana", ReadyAt = 0 }
	end
	local function same(list, expected)
		if #list ~= #expected then
			return false
		end
		for i, v in expected do
			if list[i] ~= v then
				return false
			end
		end
		return true
	end
	-- Probabilités : 200 000 tirages d'un Commun Standard de zone 2 (Peu commun et Rare possibles).
	local rng = Random.new(2026)
	local n, one, two, more = 200000, 0, 0, 0
	for _ = 1, n do
		local steps = UnboxService.RollUpgrades(box("Standard", 2, "Common"), 1, rng)
		if #steps >= 1 then
			one += 1
		end
		if #steps == 2 then
			two += 1
		end
		if #steps > 2 then
			more += 1
		end
	end
	print(string.format("    au moins un cran : %.4f ; deux crans : %.4f", one / n, two / n))
	check(math.abs(one / n - 0.10) < 0.004, "B1 au moins un cran dans 10 % des cas (chance 1)")
	check(math.abs(two / n - 0.01) < 0.0015, "B2 deux crans dans 1 % des cas (10 % × 10 %)")
	check(more == 0, "B3 jamais plus de UpgradeMax = 2 crans")
	check(same(UnboxService.RollUpgrades(box("Standard", 2, "Common"), 1, fakeRng({ 0.05, 0.05 })), { "Uncommon", "Rare" }), "B4 deux réussites : Commun → Peu commun → Rare")
	check(same(UnboxService.RollUpgrades(box("Standard", 2, "Common"), 1, fakeRng({ 0.05, 0.5 })), { "Uncommon" }), "B5 réussite puis échec : un cran, puis l'amélioration s'arrête")
	check(same(UnboxService.RollUpgrades(box("Standard", 2, "Common"), 1, fakeRng({ 0.5, 0.05 })), {}), "B6 premier échec : aucun cran (pas de second essai)")
	check(same(UnboxService.RollUpgrades(box("Standard", 2, "Common"), 1, fakeRng({ 0.0999 })), { "Uncommon" }) and #UnboxService.RollUpgrades(box("Standard", 2, "Common"), 1, fakeRng({ 0.1 })) == 0, "B7 seuil exact : tirage < 10 % réussit, 10 % échoue")
	check(same(UnboxService.RollUpgrades(box("Luxe", 4, "Legendary"), 1000, fakeRng({}, 0)), { "Mythic" }), "B8 Légendaire Luxe : un seul cran (Mythique), jamais Secret")
	check(#UnboxService.RollUpgrades(box("Luxe", 4, "Mythic"), 1000, fakeRng({}, 0)) == 0, "B9 Mythique : aucun cran (Secret exclu)")
	local zone1 = 0
	for _, tier in { "Standard", "Premium", "Luxe" } do
		zone1 += #UnboxService.RollUpgrades(box(tier, 1, "Common"), 1000, fakeRng({}, 0))
	end
	check(zone1 == 0, "B10 zone 1 (Communs seulement) : jamais de cran, même à chance maximale")
	local tutoBox = { Tier = "Premium", Zone = 1, Rarity = "Rare", ItemId = "Z1_InstantNoodles", ReadyAt = 0 }
	check(#UnboxService.RollUpgrades(tutoBox, 1000, fakeRng({}, 0)) == 0, "B11 colis garanti du tuto (Rare imposé en zone 1) : jamais amélioré")
	check(same(UnboxService.RollUpgrades(box("Standard", 3, "Rare"), 1000, fakeRng({}, 0)), { "Epic" }), "B12 Standard : Rare → Épique (1 %), puis arrêt (Légendaire à 0 % en Standard)")
	check(#UnboxService.RollUpgrades(box("Standard", 3, "Epic"), 1000, fakeRng({}, 0)) == 0, "B13 Épique Standard : aucun cran (Légendaire impossible dans ce colis)")
	check(#UnboxService.RollUpgrades(box("Premium", 3, "Epic"), 1000, fakeRng({}, 0)) == 0, "B14 Épique Premium zone 3 : Légendaire possible mais aucun objet Légendaire en zone 3 → aucun cran")
	check(same(UnboxService.RollUpgrades(box("Premium", 2, "Epic"), 1000, fakeRng({}, 0)), { "Legendary", "Mythic" }), "B15 Épique Premium zone 2 : Légendaire puis Mythique (0,2 %)")
	check(#UnboxService.RollUpgrades(box("Standard", 2, "Common"), 0, fakeRng({}, 0)) == 0, "B16 chance 0 : règle coupée")
	check(#UnboxService.RollUpgrades(box("Standard", 2, "Common"), 0 / 0, fakeRng({}, 0)) == 0 and #UnboxService.RollUpgrades(box("Standard", 2, "Common"), -3, fakeRng({}, 0)) == 0, "B17 chance NaN ou négative : aucun cran")
	check(#UnboxService.RollUpgrades(box("Standard", 2, "Common"), 10, fakeRng({}, 0.999)) == 2, "B18 chance ×10 : probabilité bornée à 1, deux crans à coup sûr")
	check(#UnboxService.RollUpgrades({ Tier = "Standard", Zone = 2, Rarity = "Nope", ItemId = "x", ReadyAt = 0 }, 1000, fakeRng({}, 0)) == 0, "B19 rareté inconnue : aucun cran, sans erreur")
	-- UpgradeChance = 0 dans Config/Unbox : source modifiée, service rechargé à part.
	local original = SOURCES["shared/Config/Unbox.luau"]
	local patched, hits = string.gsub(original, "UpgradeChance = 0%.10,", "UpgradeChance = 0,")
	check(hits == 1, "B20 (banc) Config/Unbox modifié : UpgradeChance = 0")
	SOURCES["shared/Config/Unbox.luau"] = patched
	resetCache("server")
	local zeroService = requireModule(unboxModule, "server")
	local zeroSteps = 0
	for _ = 1, 2000 do
		zeroSteps += #zeroService.RollUpgrades(box("Standard", 2, "Common"), 1000, fakeRng({}, 0))
	end
	check(zeroSteps == 0, "B21 UpgradeChance = 0 : aucun cran, même avec une chance de 1000")
	SOURCES["shared/Config/Unbox.luau"] = original
	resetCache("server")
end

print("\n== C. OpenBox de bout en bout (serveur, vrai Net)")
-- Le service a été rechargé en B : on reprend les modules du serveur.
UnboxService = requireModule(unboxModule, "server")
Data = requireModule(dataModule, "server")
Plots = requireModule(plotModule, "server")
Carry = requireModule(carryModule, "server")
NetS = requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Display = requireModule(services.DisplayService, "server")
Items = requireModule(Config.Items, "server")
Rarities = requireModule(Config.Rarities, "server")

local greybox = folder(Workspace, "Greybox")
local function makePlot(index, x)
	local plot = InstanceAPI.new("Model")
	plot.Name = string.format("PLOT_Greybox_%02d", index)
	plot:SetAttribute("PlotIndex", index)
	plot:SetAttribute("OwnerUserId", 0)
	for k = 1, 4 do
		local t = new("Part", { Name = string.format("UnboxTable_%02d", k), Size = Vector3.new(3.5, 3, 3), CFrame = CFrame.new(x + (k - 1) * 6, 1.5, 0) }, plot)
		new("Attachment", { Name = string.format("DisplaySlot_%02d", k), CFrame = CFrame.new(0, 1.5, 0) }, t)
	end
	-- a51 (L-089) : sol et volume de la boutique, où se posent les colis (8 studs devant chaque établi).
	local floor = new("Part", { Name = "PlotFloor", Size = Vector3.new(60, 0.2, 30), CFrame = CFrame.new(x + 9, -0.1, 4) }, plot)
	new("Part", { Name = "Bounds", Size = Vector3.new(60, 20, 30), CFrame = CFrame.new(x + 9, 10, 4), CanCollide = false, CanQuery = false }, plot)
	plot.PrimaryPart = floor
	plot.Parent = greybox
	addTag(plot, "PlayerPlot")
	return plot
end
local plot1 = makePlot(1, 0)
local plot2 = makePlot(2, 200)
-- a51 (L-089) : la zone safe couvre les deux boutiques ; le couloir est au-delà (x = 1000).
local safeZone = new("Part", { Name = "SafeZone", Size = Vector3.new(600, 60, 200), CFrame = CFrame.new(100, 20, 0), CanCollide = false, CanQuery = false }, greybox)
addTag(safeZone, "SafeZone")

local function makePlayer(name, userId)
	local p = InstanceAPI.new("Player")
	p.Name = name
	p.UserId = userId
	p.DisplayName = name
	local character = InstanceAPI.new("Model")
	character.Name = name
	local root = new("Part", { Name = "HumanoidRootPart" }, character)
	new("Humanoid", { Name = "Humanoid" }, character)
	character.Parent = Workspace
	p.Character = character
	p.Parent = Players
	return p, root
end
local P1, root1 = makePlayer("Alice", 101)
local P2, root2 = makePlayer("Bob", 102)
local playerGui = folder(P1, "PlayerGui")
rawset(playerGui, "_class", "PlayerGui")

local function bench(plot, i)
	return plot:FindFirstChild(string.format("DisplaySlot_%02d", i), true)
end
local function standAt(root, position)
	root.CFrame = CFrame.new(position.X, position.Y, position.Z)
end
-- a51 (L-089) : le colis n° i se pose au sol, 8 studs devant l'établi i ; le joueur se tient à côté.
local function floorSpot(plot, i)
	local b = bench(plot, i).WorldPosition
	return Vector3.new(b.X, 0, b.Z + 8)
end
local function nearBench(root, plot, i)
	standAt(root, floorSpot(plot, i) + Vector3.new(0, 3, 3))
end
-- Uid du colis posé n° i, par joueur.
SLOT_UIDS = {}
local function slotUid(player, i)
	return (SLOT_UIDS[player] or {})[i]
end
local function fire(player, name, ...)
	ReplicatedStorage.Remotes[name].OnServerEvent:Fire(player, ...)
end
-- a51 (L-089) : le colis porté rentre dans l'inventaire (zone safe), puis se pose au sol devant l'établi i.
-- Renvoie son uid (nil : pas rangé).
local function placeAtBench(player, root, plot, i, payload)
	nearBench(root, plot, i)
	local data = Data.Get(player)
	local before = {}
	for key in data.Boxes do
		before[key] = true
	end
	Carry._carry(player, payload)
	step(0.3)
	local uid = nil
	for key in data.Boxes do
		if not before[key] then
			uid = key
		end
	end
	if uid == nil then
		return nil
	end
	SLOT_UIDS[player] = SLOT_UIDS[player] or {}
	SLOT_UIDS[player][i] = uid
	fire(player, "PlaceBox", uid, floorSpot(plot, i))
	return uid
end

UnboxService.Init()
local opened = {}
UnboxService.OnBoxOpened(function(p, i, uid, itemId)
	table.insert(opened, { p = p, i = i, uid = uid, itemId = itemId })
end)
UnboxService.GetOpenDelay = function()
	return 2
end
local d1, d2 = newData(), newData()
Data._load(P1, d1)
Plots._assign(P1, plot1)
Data._load(P2, d2)
Plots._assign(P2, plot2)
step(0.1)

-- Pose un colis sur l'établi `i` de Alice et l'ouvre (côté serveur seulement), attente de 2 s.
local function placeAndOpen(i, tier, zone, rarity, itemId)
	placeAtBench(P1, root1, plot1, i, { Kind = "NPCBox", Tier = tier, Zone = zone, Rarity = rarity, ItemId = itemId, StoreId = "STORE_Test", SlotId = "S/01" })
	step(2.1)
	local before = #REMOTE_LOG
	fire(P1, "OpenBox", slotUid(P1, i))
	step(0.05)
	for k = #REMOTE_LOG, before + 1, -1 do
		local e = REMOTE_LOG[k]
		if e.name == "UnboxReveal" and e.to == P1 then
			return e
		end
	end
	return nil
end

do
	clearLog()
	local lucks = {}
	UnboxService.GetLuck = function(player, b)
		table.insert(lucks, { player = player, box = b })
		return 1000 -- chance maximale : chaque cran possible réussit
	end
	table.clear(ITEMS_PICKS)
	local e = placeAndOpen(1, "Standard", 2, "Common", "Z2_RubberDuck")
	check(e ~= nil and e.args.n == 7, "C1 UnboxReveal envoyé avec 7 arguments")
	if e then
		local a = e.args
		local item = Items.ById[a[3]]
		check(a[1] == slotUid(P1, 1) and type(a[2]) == "string", "C2 uid du colis posé (L-089) et uid de l'objet")
		check(item ~= nil and item.Rarity == "Rare" and item.Zone == 2, "C3 objet final : un Rare de la zone 2 (deux crans)")
		check(a[4] == 2 and a[5] == "Standard" and a[6] == "Common" and a[7] == 2, "C4 zone 2, type Standard, rareté de départ Common, 2 crans")
		check(d1.Items[a[2]] ~= nil and d1.Items[a[2]].Id == a[3] and d1.Items[a[2]].Zone == 2, "C5 l'objet sauvegardé est l'objet amélioré (avec sa zone)")
		check(#ITEMS_PICKS == 1 and ITEMS_PICKS[1].zone == 2 and ITEMS_PICKS[1].rarity == "Rare" and ITEMS_PICKS[1].rng ~= nil, "C6 objet tiré par Items.Pick(2, \"Rare\", rng du service)")
		check(#opened >= 1 and opened[#opened].itemId == a[3], "C7 OnBoxOpened reçoit l'objet final")
		check(logHas("2 cran(s) : Common → Uncommon → Rare", "PRINT"), "C8 sortie Studio : les crans")
	end
	check(#lucks == 1 and lucks[1].player == P1 and lucks[1].box.Rarity == "Common" and lucks[1].box ~= d1.Boxes["1"], "C9 GetLuck(player, copie du colis)")
	-- Sans cran : l'objet tiré au remplissage reste, Items.Pick n'est pas appelé.
	UnboxService.GetLuck = function()
		return 0
	end
	table.clear(ITEMS_PICKS)
	local e2 = placeAndOpen(1, "Premium", 3, "Rare", "Z3_Tablet")
	check(e2 ~= nil and e2.args[3] == "Z3_Tablet" and e2.args[6] == "Rare" and e2.args[7] == 0 and #ITEMS_PICKS == 0, "C10 chance 0 : même objet, 0 cran, Items.Pick pas appelé")
	-- GetLuck invalide : chance 1, avertissement.
	for _, bad in { function() return -1 end, function() return "x" end, function() return 0 / 0 end, function() error("panne") end } do
		clearLog()
		UnboxService.GetLuck = bad
		local e3 = placeAndOpen(1, "Standard", 4, "Common", "Z4_Ring")
		check(e3 ~= nil and logHas("GetLuck (Alice)", "WARN"), "C11 GetLuck invalide : avertissement, ouverture quand même")
	end
	UnboxService.GetLuck = function()
		return 1
	end
	-- Annonce : Légendaire et plus, aux autres joueurs, au moment de la révélation chez Alice.
	clearLog()
	UnboxService.GetLuck = function()
		return 0
	end
	local before = #REMOTE_LOG
	local e4 = placeAndOpen(1, "Luxe", 2, "Legendary", "Z2_GiantPlush")
	local t0 = e4 and e4.t
	local delay = 0.45 + 0.4 + 3.2 + 0.3 + 0.25 + 0.3
	step(delay - 0.2)
	local early = 0
	for k = before + 1, #REMOTE_LOG do
		if REMOTE_LOG[k].name == "Notify" and REMOTE_LOG[k].args[2] == "Announce" then
			early += 1
		end
	end
	check(early == 0, "C12 pas d'annonce avant la révélation")
	step(0.4)
	local announces = {}
	for k = before + 1, #REMOTE_LOG do
		local r = REMOTE_LOG[k]
		if r.name == "Notify" and r.args[2] == "Announce" then
			table.insert(announces, r)
		end
	end
	check(#announces == 1 and announces[1].to == P2, "C13 annonce envoyée à Bob seulement (pas à celle qui ouvre)")
	check(announces[1] and announces[1].args[1] == "Alice unboxed a LEGENDARY Giant Plush!", "C14 texte : « Alice unboxed a LEGENDARY Giant Plush! »")
	check(announces[1] and t0 and math.abs(announces[1].t - t0 - delay) < 0.05, "C15 annonce 4,9 s après UnboxReveal (moment de la révélation)")
	local before2 = #REMOTE_LOG
	placeAndOpen(1, "Luxe", 2, "Epic", "Z2_TeddyBear")
	step(6)
	local epicAnnounce = 0
	for k = before2 + 1, #REMOTE_LOG do
		if REMOTE_LOG[k].name == "Notify" and REMOTE_LOG[k].args[2] == "Announce" then
			epicAnnounce += 1
		end
	end
	check(epicAnnounce == 0, "C16 Épique : pas d'annonce")
	local malformed = 0
	for _, line in FULL_LOG do
		if line.kind == "WARN" and string.find(line.text, "mal formé", 1, true) then
			malformed += 1
		end
	end
	check(malformed == 0, "C17 aucun envoi mal formé signalé par Net (UnboxReveal v2, Notify)")
	UnboxService.GetLuck = function()
		return 1
	end
end

print("\n== D. Composition du rouleau (Reel.compose)")
do
	local function item(id)
		return ItemsC.ById[id]
	end
	local function orderOf(id)
		return RaritiesC.ById[ItemsC.ById[id].Rarity].Order
	end
	local OddsFor = requireModule(Config.ShelfBoxes, "client").OddsFor
	local rng = Random.new(77)
	local full = Reel.compose(3, "Premium", item("Z3_Smartphone"), true, rng)
	check(full.Winner == 27 and full.Items[27] == item("Z3_Smartphone") and #full.Items == 29 and full.Start == 3, "D1 version complète : gagnant en W = 3 + 24 = 27, 29 cases, départ en 3")
	local short = Reel.compose(3, "Premium", item("Z3_Smartphone"), false, rng)
	check(short.Winner == 13 and short.Items[13] == item("Z3_Smartphone") and #short.Items == 15, "D2 version courte : gagnant en W = 3 + 10 = 13")
	-- 10 000 rouleaux d'un Rare Premium de zone 3 : frôlement dans 40 % des cas, vers une rareté possible.
	local n, misses, badMiss, badSlot, badStop = 10000, 0, 0, 0, 0
	local odds = OddsFor(3, "Premium")
	for _ = 1, n do
		local comp = Reel.compose(3, "Premium", item("Z3_Smartphone"), true, rng)
		if comp.NearMiss then
			misses += 1
			local near = comp.Items[comp.Winner - 1]
			local r = near.Rarity
			if not (orderOf(near.Id) > orderOf("Z3_Smartphone") and (odds[r] or 0) > 0 and (near.Zone == 3 or r == "Secret")) then
				badMiss += 1
			end
			if math.abs(comp.Stop - (comp.Winner - 0.45)) > 1e-9 then
				badStop += 1
			end
		elseif math.abs(comp.Stop - (comp.Winner - Unbox.StopShort)) > 1e-9 then
			badStop += 1
		end
		for index, it in comp.Items do
			if index ~= comp.Winner and not ((odds[it.Rarity] or 0) > 0 and (it.Zone == 3 or it.Rarity == "Secret")) then
				badSlot += 1
			end
		end
	end
	print(string.format("    frôlements : %.3f", misses / n))
	check(math.abs(misses / n - 0.40) < 0.02, "D3 frôlement dans 40 % des cas")
	check(badMiss == 0, "D4 frôlement : toujours une rareté plus haute que le colis peut donner, de la zone")
	check(badStop == 0, "D5 arrêt à W − 0,45 (frôlement) ou W − 0,15 (sinon)")
	check(badSlot == 0, "D6 chaque case : rareté possible pour ce colis (probabilité > 0), objet de la zone")
	local function neverMiss(zone, tier, id, label)
		local any = false
		for _ = 1, 500 do
			if Reel.compose(zone, tier, item(id), true, rng).NearMiss then
				any = true
			end
		end
		check(not any, label)
	end
	neverMiss(1, "Premium", "Z1_InstantNoodles", "D7 zone 1 (colis du tuto, Rare) : jamais de frôlement (rien de plus haut possible)")
	neverMiss(4, "Premium", "Z4_DiamondEgg", "D8 Mythique Premium : jamais de frôlement (Secret à 0 % en Premium)")
	neverMiss(3, "Standard", "Z3_HandheldConsole", "D9 Épique Standard : jamais de frôlement (Légendaire à 0 % en Standard)")
	local secret = ItemsC.Secrets[1]
	local anySecret = false
	for _ = 1, 200 do
		if Reel.compose(5, "Luxe", secret, true, rng).NearMiss then
			anySecret = true
		end
	end
	check(not anySecret, "D10 Secret : jamais de frôlement")
	local tuto = Reel.compose(1, "Premium", item("Z1_InstantNoodles"), true, rng)
	local allCommon = true
	for index, it in tuto.Items do
		if index ~= tuto.Winner and it.Rarity ~= "Common" then
			allCommon = false
		end
	end
	check(allCommon and tuto.Items[tuto.Winner].Id == "Z1_InstantNoodles", "D11 zone 1 : rouleau de Communs, le Rare du tuto au centre")
	-- Variété : plusieurs objets différents par (zone, rareté).
	local seen = {}
	for _, it in full.Items do
		seen[it.Id] = true
	end
	check(count(seen) >= 4, "D12 rouleau varié (catalogue v2 : plusieurs objets par case)")
	-- Luxe zone 3 : jamais de Commun (0 %).
	local luxe = Reel.compose(3, "Luxe", item("Z3_Smartphone"), true, rng)
	local common = false
	for _, it in luxe.Items do
		if it.Rarity == "Common" then
			common = true
		end
	end
	check(not common, "D13 Luxe : aucun Commun dans le rouleau")
end

print("\n== E. rollPos (formule de la spec)")
do
	local T, Ta, p = 3.2, 0.25, 4
	for _, L in { 24, 24 - 0.45, 24 - 0.15 } do
		check(Reel.rollPos(0, T, Ta, p, L) == 0 and Reel.rollPos(-1, T, Ta, p, L) == 0, `E1 L = {L} : position 0 au départ et avant`)
		check(Reel.rollPos(T, T, Ta, p, L) == L and Reel.rollPos(T + 5, T, Ta, p, L) == L, `E2 L = {L} : position L à la fin et après`)
		local last, increasing, peak, slowFrom = -1, true, 0, nil
		local dt = 1 / 1000
		for i = 0, math.floor(T / dt) do
			local t = i * dt
			local pos = Reel.rollPos(t, T, Ta, p, L)
			if pos < last - 1e-12 then
				increasing = false
			end
			if i > 0 then
				local speed = (pos - last) / dt
				peak = math.max(peak, speed)
				if speed < 3 and t > Ta and slowFrom == nil then
					slowFrom = t
				end
			end
			last = pos
		end
		check(increasing, `E3 L = {L} : toujours croissante`)
		print(string.format("    L = %.2f : pic %.1f objets/s, sous 3 objets/s pendant les %.2f dernières s", L, peak, T - (slowFrom or T)))
		check(peak > 26 and peak < 29, `E4 L = {L} : pic d'environ 28 objets/s`)
		check(slowFrom ~= nil and T - slowFrom >= 1.39, `E5 L = {L} : moins de 3 objets/s pendant les 1,4 dernières secondes`)
		local before = Reel.rollPos(Ta - 1e-6, T, Ta, p, L)
		local after = Reel.rollPos(Ta + 1e-6, T, Ta, p, L)
		check(math.abs(after - before) < 1e-4, `E6 L = {L} : continue à la fin de l'accélération`)
	end
	-- Version courte : bornes et croissance.
	local ok = true
	local last = -1
	for i = 0, 1300 do
		local pos = Reel.rollPos(i / 1000, 1.3, Ta, p, 10)
		if pos < last - 1e-12 then
			ok = false
		end
		last = pos
	end
	check(ok and Reel.rollPos(1.3, 1.3, Ta, p, 10) == 10, "E7 version courte (1,3 s, 10 objets) : croissante, finit à L")
	check(Reel.rollPos(0.5, 1, 2, 4, 10) > 0 and Reel.rollPos(1, 1, 2, 4, 10) == 10, "E8 Ta plus long que T/2 : borné, sans erreur")
end

print("\n== F. Déroulé dans le temps (Sequence, horloge simulée, vue enregistreuse)")
local function revealFor(itemId, zone, tier, startRarity, upgrades)
	return { SlotIndex = 1, ItemUid = "uid-test", ItemId = itemId, Zone = zone, Tier = tier, StartRarity = startRarity, Upgrades = upgrades }
end
local function recordingView(opts)
	opts = opts or {}
	local view = { events = {}, frames = {}, runner = nil }
	local function rec(name)
		return function(self, ...)
			table.insert(self.events, { name = name, T = self.runner and self.runner.T, args = table.pack(...) })
		end
	end
	for _, name in { "Begin", "Charge", "Pop", "Open", "ScrollStart", "LastNotch", "ReelDone", "ColorStart", "Reveal", "RarityText", "ItemNameText", "IncomeStart", "IncomeDone", "Buttons" } do
		view[name] = rec(name)
	end
	view.PlayUnbox = function(self)
		table.insert(self.events, { name = "PlayUnbox", T = self.runner and self.runner.T, args = table.pack() })
		return opts.track == true
	end
	view.Frame = function(self, info)
		table.insert(self.frames, { T = info.T, pos = info.ReelPos, drop = info.ReelDrop, speed = info.ReelSpeed, charge = info.Charge })
	end
	return view
end
local function eventT(view, name, nth)
	local k = 0
	for _, e in view.events do
		if e.name == name then
			k += 1
			if k == (nth or 1) then
				return e.T, e
			end
		end
	end
	return nil
end
local function runFor(runner, seconds, frame)
	frame = frame or 1 / 60
	local n = math.floor(seconds / frame + 0.5)
	for _ = 1, n do
		runner:Update(frame)
	end
end
local function makeRun(reveal, opts, seed)
	local plan = assert(Sequence.plan(reveal, Random.new(seed or 5)))
	local view = recordingView(opts)
	local runner = Sequence.new(plan, view)
	view.runner = runner
	return plan, view, runner
end
local TOL = 0.05 -- tableau de la spec : durées arrondies au dixième
do
	-- Moments prévus (Sequence.times).
	local cases = {
		{ "complète, Rare, 0 cran", revealFor("Z3_Smartphone", 3, "Premium", "Rare", 0), 4.9, 6.7 },
		{ "courte, Commun, 0 cran", revealFor("Z3_Earbuds", 3, "Standard", "Common", 0), 3.0, 4.4 },
		{ "complète, Rare, 1 cran", revealFor("Z3_Smartphone", 3, "Premium", "Uncommon", 1), 4.9 + 0.9, 6.7 + 0.9 },
		{ "complète, Rare, 2 crans", revealFor("Z3_Smartphone", 3, "Premium", "Common", 2), 4.9 + 1.8, 6.7 + 1.8 },
		{ "courte, Peu commun, 1 cran", revealFor("Z3_Gamepad", 3, "Standard", "Common", 1), 3.0 + 0.9, 4.4 + 0.9 },
	}
	for i, case in cases do
		local plan = assert(Sequence.plan(case[2], Random.new(i)))
		local times = Sequence.times(plan)
		print(string.format("    %s : objet révélé à %.3f s, boutons à %.3f s", case[1], times.Reveal, times.Buttons))
		check(math.abs(times.Reveal - case[3]) < 1e-9, `F{i}a {case[1]} : objet révélé à {case[3]} s`)
		check(math.abs(times.Buttons - case[4]) <= TOL, `F{i}b {case[1]} : boutons à {case[4]} s (à 0,05 s près)`)
	end
	-- Le déroulé suit exactement ces moments (pas de 1/60 s, ouverture au secours).
	local plan, view, runner = makeRun(revealFor("Z3_Smartphone", 3, "Premium", "Common", 2))
	local times = Sequence.times(plan)
	runFor(runner, 9)
	local names = {}
	for _, e in view.events do
		table.insert(names, e.name)
	end
	local expected = "Begin Charge Pop Charge Pop PlayUnbox Open ScrollStart LastNotch ReelDone ColorStart Reveal RarityText ItemNameText IncomeStart IncomeDone Buttons"
	check(table.concat(names, " ") == expected, "F6 ordre des événements : crans, Unbox, ouverture, rouleau, éclat, textes, boutons")
	check(math.abs(runner:FiredAt("Reveal") - times.Reveal) < 1e-9 and math.abs(runner:FiredAt("Buttons") - times.Buttons) < 1e-9, "F7 moments du déroulé = Sequence.times")
	local revealT = eventT(view, "Reveal")
	check(revealT >= times.Reveal and revealT < times.Reveal + 1 / 60 + 1e-9, "F8 l'éclat tombe dans l'image où l'horloge passe 6,7 s")
	check(math.abs(eventT(view, "Pop", 1) - 0.5) < 1 / 60 + 1e-9 and math.abs(eventT(view, "Pop", 2) - 1.4) < 1 / 60 + 1e-9, "F9 crans à 0,5 s et 1,4 s (charge de 0,5 s, cran de 0,9 s)")
	local _, pop1 = eventT(view, "Pop", 1)
	local _, pop2 = eventT(view, "Pop", 2)
	check(pop1.args[2].Id == "Uncommon" and pop2.args[2].Id == "Rare", "F10 raretés des crans : Peu commun puis Rare")
	check(math.abs(eventT(view, "PlayUnbox") - 1.8) < 1 / 60 + 1e-9 and math.abs(runner:FiredAt("Open") - 2.25) < 1e-9, "F11 Unbox à 1,8 s, ouverture 0,45 s après le dernier cran")
	local _, open = eventT(view, "Open")
	check(open.args[1] == false, "F12 ouverture au secours : fromMarker = false (la vue joue Unbox_Open)")
	-- Position du rouleau : croissante, du départ au gagnant, sortie du colis puis défilement.
	local increasing, lastPos, maxPos, minPos = true, -math.huge, -math.huge, math.huge
	for _, f in view.frames do
		if f.pos then
			if f.T < runner.At.ScrollEnd and f.pos < lastPos - 1e-9 then
				increasing = false
			end
			lastPos = f.pos
			maxPos = math.max(maxPos, f.pos)
			minPos = math.min(minPos, f.pos)
		end
	end
	check(increasing and minPos == plan.Reel.Start and math.abs(lastPos - plan.Reel.Winner) < 1e-9, "F13 rouleau : du départ (3) au gagnant (W), croissant pendant le défilement")
	check(maxPos <= plan.Reel.Winner + 0.2, "F14 dernier cran Back Out : dépasse le gagnant de moins de 0,2 case")
	local drops = 0
	for _, f in view.frames do
		if f.drop > 0 then
			drops += 1
		end
	end
	check(drops > 0 and drops <= math.ceil(0.4 * 60) + 1, "F15 sortie du colis (décalage) pendant 0,4 s seulement")
	local charges = 0
	for _, f in view.frames do
		if f.charge then
			charges += 1
		end
	end
	check(math.abs(charges - 2 * 0.5 * 60) <= 2, "F16 charge visible pendant 2 × 0,5 s")
	check(runner:SinceButtons() ~= nil and math.abs(runner:SinceButtons() - (runner.T - times.Buttons)) < 1e-9, "F17 SinceButtons")

	-- Marqueur Open de l'animation Unbox : l'ouverture suit le marqueur.
	local planM, viewM, runnerM = makeRun(revealFor("Z3_Smartphone", 3, "Premium", "Rare", 0), { track = true })
	runFor(runnerM, 0.3)
	check(runnerM:IsFired("Unbox") and not runnerM:IsFired("Open"), "F18 Unbox jouée : on attend le marqueur Open")
	runnerM:OpenMarker()
	check(runnerM:IsFired("Open") and math.abs(runnerM:FiredAt("Open") - 0.3) < 1e-6, "F19 marqueur à 0,3 s : ouverture à 0,3 s")
	local _, openM = eventT(viewM, "Open")
	check(openM.args[1] == true, "F20 fromMarker = true (son joué par AnimationController)")
	runFor(runnerM, 6)
	check(math.abs(runnerM:FiredAt("Reveal") - (0.3 + 4.45)) < 1e-6, "F21 tout le reste se décale avec le marqueur (éclat à 4,75 s)")
	local _, viewT, runnerT = makeRun(revealFor("Z3_Smartphone", 3, "Premium", "Rare", 0), { track = true })
	runFor(runnerT, 2)
	check(runnerT:IsFired("Open") and math.abs(runnerT:FiredAt("Open") - Unbox.OpenMarkerTimeout) < 1e-9, "F22 marqueur jamais venu : ouverture à OpenMarkerTimeout (1,5 s)")
	local _, openT = eventT(viewT, "Open")
	check(openT.args[1] == false, "F23 … au secours (fromMarker = false)")

	-- SkipButton pendant le rouleau : le gagnant arrive en 0,4 s, puis pause, couleurs, éclat.
	local planS, viewS, runnerS = makeRun(revealFor("Z3_Smartphone", 3, "Premium", "Rare", 0))
	runFor(runnerS, 2)
	local skipAt = runnerS.T
	runnerS:Skip()
	check(runnerS:IsFired("LastNotch") and math.abs(runnerS.At.ReelDone - (skipAt + 0.4)) < 1e-9, "F24 passer pendant le rouleau : gagnant au centre 0,4 s plus tard")
	runnerS:Skip()
	check(math.abs(runnerS.At.ReelDone - (skipAt + 0.4)) < 1e-9, "F25 deuxième toucher pendant le glissement : sans effet")
	runFor(runnerS, 0.45)
	local lastS
	for _, f in viewS.frames do
		lastS = f.pos or lastS
	end
	check(runnerS:IsFired("ReelDone") and math.abs(lastS - planS.Reel.Winner) < 1e-9, "F26 gagnant exactement au centre")
	check(math.abs(runnerS.At.Reveal - (skipAt + 0.4 + 0.25 + 0.3)) < 1e-9, "F27 éclat après la pause (0,25 s) et les couleurs (0,3 s)")
	-- SkipButton pendant les textes : tout d'un coup.
	runFor(runnerS, 0.6)
	check(runnerS:IsFired("Reveal") and not runnerS:IsFired("Buttons"), "F28 (éclat passé, boutons pas encore)")
	runnerS:Skip()
	check(runnerS:IsFired("Rarity") and runnerS:IsFired("ItemName") and runnerS:IsFired("CountEnd") and runnerS:IsFired("Buttons"), "F29 passer pendant les textes : rareté, nom, revenu et boutons d'un coup")
	check(math.abs(runnerS.T - runnerS.At.Buttons) < 1e-9, "F30 l'horloge saute aux boutons")
	-- Passer pendant les crans : rien.
	local _, _, runnerU = makeRun(revealFor("Z3_Smartphone", 3, "Premium", "Common", 2))
	runFor(runnerU, 0.7)
	runnerU:Skip()
	check(not runnerU:IsFired("Open") and runnerU.glide == nil, "F31 passer pendant les crans : sans effet")

	-- Secret : ralenti ×0,3 pendant 0,5 s à l'éclat.
	local planX, viewX, runnerX = makeRun(revealFor(ItemsC.Secrets[1].Id, 5, "Luxe", "Secret", 0))
	local timesX = Sequence.times(planX)
	local real, frame = 0, 1 / 60
	local realReveal, realRarity
	while real < 9 do
		runnerX:Update(frame)
		real += frame
		if realReveal == nil and runnerX:IsFired("Reveal") then
			realReveal = real
		end
		if realRarity == nil and runnerX:IsFired("Rarity") then
			realRarity = real
		end
	end
	local expectedGap = 0.5 + (Unbox.TextsAt - 0.5 * 0.3) -- 0,5 s réelles couvrent 0,15 s de séquence
	print(string.format("    Secret : rareté %.3f s réelles après l'éclat (sans ralenti : %.2f s)", realRarity - realReveal, Unbox.TextsAt))
	check(math.abs((realRarity - realReveal) - expectedGap) < 2 / 60, "F32 Secret : textes retardés par le ralenti (×0,3 pendant 0,5 s)")
	check(math.abs(timesX.Reveal - 4.9) < 1e-9 and math.abs(realReveal - 4.9) < 2 / 60, "F33 Secret : éclat à 4,9 s (le ralenti ne commence qu'à l'éclat)")
	-- Grands pas d'horloge (gel du client) : rien n'est sauté, l'ordre est gardé.
	local _, viewL, runnerL = makeRun(revealFor("Z3_Smartphone", 3, "Premium", "Common", 2))
	runnerL:Update(20)
	check(runnerL:IsFired("Buttons") and #viewL.events == 17, "F34 un seul pas de 20 s : tous les événements, dans l'ordre")
	-- Plan : objet inconnu, crans incohérents.
	local bad, why = Sequence.plan(revealFor("Z9_Nope", 3, "Premium", "Rare", 0), Random.new(1))
	check(bad == nil and string.find(why, "Z9_Nope", 1, true) ~= nil, "F35 objet inconnu du catalogue client : pas de séquence, raison donnée")
	local mis = Sequence.plan(revealFor("Z3_Smartphone", 3, "Premium", "Common", 1), Random.new(1))
	check(mis and mis.Mismatch and #mis.Steps == 1 and mis.Steps[1].Id == "Rare", "F36 rareté de départ incohérente : signalée, le dernier cran reste la rareté de l'objet")
	local capped = Sequence.plan(revealFor("Z3_Earbuds", 3, "Standard", "Common", 5), Random.new(1))
	check(capped and #capped.Steps == 0, "F37 crans impossibles (Commun + 5) : bornés, aucun cran montré")
	local secretPlan = Sequence.plan(revealFor(ItemsC.Secrets[1].Id, 5, "Luxe", "Secret", 0), Random.new(1))
	check(secretPlan and secretPlan.Income == Formulas.ItemIncome(5, "Secret"), "F38 Secret : revenu calculé avec la zone du colis (comme DisplayService)")
end

print("\n== G. Écran UI_Unbox v2 (vrai UnboxController, vraie vue, vrai serveur)")
local ANIM = requireModule(animModule, "client")
local unboxGui = buildUnbox(playerGui)
local studioState = snapshot(unboxGui)
CLIENT_PLAYER = P1
Players.LocalPlayer = P1
local Controller = requireModule(controllerModule, "client")
taskLib.spawn(Controller.Start)
step(0.1)
UnboxService.GetLuck = function()
	return 0
end

-- a51 (L-089) : le colis n° i est un FloorBox au sol (attribut BoxUid), son invite est sur lui.
local function boxModel(i)
	local uid = slotUid(P1, i)
	for _, child in plot1:GetChildren() do
		if uid and child.Name == "FloorBox" and child:GetAttribute("BoxUid") == uid then
			return child
		end
	end
	return nil
end
local function prompt(i)
	local model = boxModel(i)
	return if model then model:FindFirstChild("UnboxPrompt", true) else nil
end
-- Pose un colis et attend qu'il soit prêt (2 s), sans l'ouvrir.
local function placeReady(i, tier, zone, rarity, itemId)
	placeAtBench(P1, root1, plot1, i, { Kind = "NPCBox", Tier = tier, Zone = zone, Rarity = rarity, ItemId = itemId, StoreId = "STORE_Test", SlotId = "S/01" })
	step(2.2)
end
local function openByPrompt(i)
	nearBench(root1, plot1, i)
	step(0.05)
	local p = prompt(i)
	check(p ~= nil and p.Enabled and p.ActionText == "Open", `invite « Open » sur l'établi {i}`)
	p.Triggered:Fire()
end
local function localBox()
	return Workspace:FindFirstChild("UnboxLocalBox")
end
local function reelModels()
	local n = 0
	for _, c in el(unboxGui, "ReelView"):GetChildren() do
		if c:IsA("Model") then
			n += 1
		end
	end
	return n
end

do
	-- Un Rare (version complète), sans cran : par l'invite, de bout en bout.
	local tint = new("Part", { Name = "Tint", Size = Vector3.new(2, 2, 2) })
	local boxTemplate = new("Model", { Name = "BOX_Premium" }, assets)
	local base = new("Part", { Name = "Base", Size = Vector3.new(2, 1, 2) }, boxTemplate)
	tint.Parent = boxTemplate
	new("Part", { Name = "Lid", Size = Vector3.new(2, 0.2, 2), CFrame = CFrame.new(0, 2, 0) }, boxTemplate)
	boxTemplate.PrimaryPart = base
	placeReady(1, "Premium", 3, "Rare", "Z3_Smartphone")
	check(boxModel(1) ~= nil, "G1 colis FloorBox posé au sol (BOX_Premium de Clément)")
	clearLog()
	table.clear(SOUNDS_PLAYED)
	table.clear(ANIM.played)
	openByPrompt(1)
	local t0 = now()
	step(1 / 30)
	check(unboxGui.Enabled, "G2 UnboxReveal : écran ouvert tout de suite")
	check(boxModel(1) == nil and localBox() ~= nil, "G3 le colis du serveur est parti, sa copie locale reste sur l'établi")
	check(localBox() and localBox():FindFirstChild("OpenTimer", true) == nil, "G4 copie locale sans minuteur (billboard retiré)")
	check(el(unboxGui, "RevealPanel").Visible == false, "G5 cadre de révélation (RevealPanel) caché avant l'éclat")
	check(el(unboxGui, "Backdrop").BackgroundTransparency == 1, "G6 Backdrop à 1 au départ")
	check(el(unboxGui, "Upgrade").Visible == false, "G7 pas de cran : Upgrade caché")
	step(0.45)
	check(#ANIM.played >= 1 and ANIM.played[1].name == "Unbox", "G8 animation Unbox jouée à l'ouverture")
	check(el(unboxGui, "Reel").Visible and el(unboxGui, "SkipButton").Visible, "G9 ouverture (0,45 s) : Reel et SkipButton visibles")
	check(soundCount("Unbox_Open") == 0, "G10 (aucun son livré : rien n'est joué)")
	check(logHas("sons Unbox_* absents", "PRINT"), "G11 une ligne en Studio : sons pas encore livrés")
	step(0.4)
	check(math.abs(el(unboxGui, "Backdrop").BackgroundTransparency - 0.65) < 1e-9, "G12 version complète : Backdrop à sa valeur de Studio (0,65)")
	check(reelModels() >= 1 and reelModels() <= 3, "G13 ReelView : trois clones au plus")
	local maxModels = 0
	for _ = 1, 60 do
		step(1 / 30)
		maxModels = math.max(maxModels, reelModels())
	end
	check(maxModels <= 3 and maxModels >= 2, "G14 pendant le défilement : jamais plus de 3 clones")
	check(sameColor(el(unboxGui, "ReelView").ImageColor3, Color3.new(0, 0, 0)), "G15 silhouettes noires (ReelView.ImageColor3 de Studio)")
	local glow = el(unboxGui, "ReelGlow").BackgroundColor3
	check(not sameColor(glow, Color3.new(1, 1, 1)), "G16 ReelGlow à la couleur de l'objet au centre")
	local block = el(unboxGui, "ReelView"):FindFirstChild("V0Block", true)
	check(block ~= nil, "G17 ITM_* pas livrés : cubes V0 dans le rouleau")
	-- Jusqu'à l'éclat (4,9 s).
	step(4.9 - (now() - t0) - 0.05)
	check(el(unboxGui, "RevealPanel").Visible == false, "G18 juste avant 4,9 s : pas encore d'éclat")
	step(0.1)
	check(el(unboxGui, "RevealPanel").Visible and el(unboxGui, "Reel").Visible == false, "G19 éclat à 4,9 s : RevealPanel visible, rouleau caché")
	local viewport = el(unboxGui, "ItemPreview"):FindFirstChild("ItemViewport")
	check(viewport ~= nil and viewport:FindFirstChildWhichIsA("Camera") ~= nil, "G20 ItemPreview : ViewportFrame de l'objet, avec sa caméra")
	check(el(unboxGui, "Rays").Visible and sameColor(el(unboxGui, "Rays").ImageColor3, Rarities.ById.Rare.Color), "G21 Rays visibles, à la couleur du Rare")
	local pieces = 0
	for _, c in el(unboxGui, "Confetti"):GetChildren() do
		if c.Name == "Piece" then
			pieces += 1
		end
	end
	check(pieces == 30, "G22 éclat Rare : 30 confettis (clones de Confetti.Template)")
	check(localBox() == nil, "G23 la copie du colis disparaît à l'éclat")
	step(0.15)
	check(el(unboxGui, "Flash").BackgroundTransparency == 1, "G24 Flash revenu à 1 après 100 ms")
	step(0.4)
	check(el(unboxGui, "Rarity").Visible and el(unboxGui, "Rarity").Text == "RARE" and sameColor(el(unboxGui, "Rarity").TextColor3, Rarities.ById.Rare.Color), "G25 Rarity « RARE » en bleu")
	check(el(unboxGui, "ItemName").Text == "Smartphone", "G26 ItemName : nom anglais du catalogue")
	local income = Formulas.ItemIncome(3, "Rare")
	step(0.3)
	local midText = el(unboxGui, "Income").Text
	step(1)
	check(el(unboxGui, "Income").Text == `+$300/s` and income == 300, "G27 Income « +$300/s » à la fin du comptage")
	check(midText ~= "+$300/s" and string.sub(midText, 1, 2) == "+$", "G28 le revenu défile pendant le comptage")
	step(6.75 - (now() - t0))
	check(el(unboxGui, "ContinueButton").Visible and el(unboxGui, "SkipButton").Visible == false, "G29 boutons à 6,7 s : CONTINUE, plus de SkipButton")
	check(el(unboxGui, "OpenNextButton").Visible == false, "G30 aucun autre établi prêt : pas d'OPEN NEXT")
	check(logHas("[Unbox] colis " .. tostring(slotUid(P1, 1)) .. " : RARE · Smartphone · 300 $/s (Z3_Smartphone", "PRINT") and logHas("colis Premium de la zone 3", "PRINT"), "G31 sortie Studio : l'objet révélé (même début de ligne qu'en v1), colis et zone")
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(0.05)
	check(unboxGui.Enabled == false, "G32 CONTINUE : écran fermé")
	local diffs = diffSnapshot(studioState, unboxGui)
	check(#diffs == 0, "G33 fermeture : tout l'écran revient à l'état de Studio, rien d'ajouté")
	for i = 1, math.min(#diffs, 8) do
		print("      " .. diffs[i])
	end
	local effects = 0
	for _, d in Workspace:GetDescendants() do
		if d.Name == "UnboxEffect" or d.Name == "UnboxLocalBox" then
			effects += 1
		end
	end
	check(effects == 0, "G35 aucun effet 3D ni copie de colis laissés dans le Workspace")
end

do
	-- Deux crans (Commun → Peu commun → Rare), version complète : Upgrade, teinte, saut, confettis.
	UnboxService.GetLuck = function()
		return 1000
	end
	placeReady(1, "Premium", 2, "Common", "Z2_RubberDuck")
	local hrp = root1
	rawget(hrp, "_props").AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	openByPrompt(1)
	local t0 = now()
	step(0.4)
	check(el(unboxGui, "Upgrade").Visible == false, "G36 charge du 1er cran : Upgrade pas encore là")
	local lb = localBox()
	local light = lb and lb:FindFirstChildWhichIsA("PointLight", true)
	check(light ~= nil and light.Brightness > 0 and sameColor(light.Color, Rarities.ById.Uncommon.Color), "G37 lueur de la rareté suivante (Peu commun) pendant la charge")
	step(0.15)
	check(el(unboxGui, "Upgrade").Visible and el(unboxGui, "UpgradeRarity").Text == "UNCOMMON" and sameColor(el(unboxGui, "UpgradeRarity").TextColor3, Rarities.ById.Uncommon.Color), "G38 1er cran (0,5 s) : UPGRADE! UNCOMMON en vert")
	local tint = lb and lb:FindFirstChild("Tint", true)
	check(tint and sameColor(tint.Color, Rarities.ById.Uncommon.Color), "G39 Tint du colis local teinté Peu commun")
	check(lb and math.abs(lb:GetScale() - Unbox.UpgradeGrow) < 1e-9, "G40 le colis grossit d'un coup (×1,12)")
	check(hrp.AssemblyLinearVelocity.Y == Unbox.UpgradeHop, "G41 petit saut du perso")
	local pieces = 0
	for _, c in el(unboxGui, "Confetti"):GetChildren() do
		if c.Name == "Piece" then
			pieces += 1
		end
	end
	check(pieces == 22, "G42 22 confettis au cran")
	local pos = el(unboxGui, "Upgrade").Position
	check(pos.X.Scale == 0 and pos.Y.Scale == 0, "G43 Upgrade placé au-dessus du colis (en pixels, WorldToScreenPoint)")
	step(0.9)
	check(el(unboxGui, "UpgradeRarity").Text == "RARE" and tint and sameColor(tint.Color, Rarities.ById.Rare.Color), "G44 2e cran (1,4 s) : RARE, colis teinté Rare")
	step(2.3 - (now() - t0))
	check(el(unboxGui, "Upgrade").Visible == false and el(unboxGui, "Reel").Visible, "G45 ouverture à 2,25 s (1,8 + 0,45) : Upgrade caché, rouleau visible")
	step(6.7 - (now() - t0) + 0.05)
	check(el(unboxGui, "RevealPanel").Visible and el(unboxGui, "Rarity").Visible == false, "G46 éclat à 6,7 s (4,9 + 2 × 0,9)")
	step(8.6 - (now() - t0) + 0.05)
	check(el(unboxGui, "ContinueButton").Visible, "G47 boutons à 8,5 s (6,7 + 1,8)")
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(0.05)
	check(#diffSnapshot(studioState, unboxGui) == 0, "G48 fermeture après des crans : écran remis à l'état de Studio")
	UnboxService.GetLuck = function()
		return 0
	end
end

do
	-- Version courte (Commun) : pas d'assombrissement, éclat à 3,0 s, boutons à 4,4 s, pas de confettis.
	placeReady(1, "Standard", 3, "Common", "Z3_Earbuds")
	openByPrompt(1)
	local t0 = now()
	step(1.5)
	check(el(unboxGui, "Backdrop").BackgroundTransparency == 1, "G49 version courte : pas d'assombrissement")
	step(3.0 - (now() - t0) + 0.05)
	check(el(unboxGui, "RevealPanel").Visible, "G50 version courte : éclat à 3,0 s")
	local pieces = 0
	for _, c in el(unboxGui, "Confetti"):GetChildren() do
		if c.Name == "Piece" then
			pieces += 1
		end
	end
	check(pieces == 0, "G51 Commun : aucun confetti")
	step(4.4 - (now() - t0) - 0.1)
	check(el(unboxGui, "ContinueButton").Visible == false, "G52 boutons pas encore à 4,3 s")
	step(0.15)
	check(el(unboxGui, "ContinueButton").Visible, "G53 boutons à 4,4 s")
	-- Fermeture toute seule 6 s après les boutons.
	step(5.8)
	check(unboxGui.Enabled, "G54 encore ouvert 5,8 s après les boutons")
	step(0.3)
	check(unboxGui.Enabled == false and #diffSnapshot(studioState, unboxGui) == 0, "G55 fermé tout seul 6 s après les boutons, écran remis")
end

do
	-- SkipButton : pendant le rouleau, puis pendant les textes.
	placeReady(1, "Premium", 3, "Rare", "Z3_Tablet")
	openByPrompt(1)
	local t0 = now()
	step(1.5)
	tapSkip() -- 2026-11-08 : appui n'importe où, plus le bouton
	local skipAt = now() - t0
	step(0.4 + 0.25 + 0.3 + 0.05)
	check(el(unboxGui, "RevealPanel").Visible, "G56 passer pendant le rouleau : éclat 0,95 s plus tard (0,4 + 0,25 + 0,3)")
	tapSkip() -- 2026-11-08 : appui n'importe où, plus le bouton
	step(1 / 30)
	check(el(unboxGui, "Rarity").Visible and el(unboxGui, "ItemName").Visible and el(unboxGui, "Income").Text == "+$300/s" and el(unboxGui, "ContinueButton").Visible, "G57 passer pendant les textes : tout d'un coup")
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(0.05)
	check(unboxGui.Enabled == false and #diffSnapshot(studioState, unboxGui) == 0, "G58 fermé et remis après un passage")
end

do
	-- OpenNextButton : un autre établi prêt et à portée (règle d'OpenBox : 12 studs).
	placeReady(2, "Standard", 3, "Common", "Z3_UsbCable")
	placeReady(1, "Standard", 3, "Common", "Z3_Earbuds")
	openByPrompt(1)
	step(4.5)
	local dist = (bench(plot1, 2).WorldPosition - root1.Position).Magnitude
	print(string.format("    joueur devant l'établi 1, établi 2 à %.2f studs (écart de 6 studs entre établis)", dist))
	check(el(unboxGui, "OpenNextButton").Visible, "G59 établi 2 prêt à 6,7 studs : OPEN NEXT visible")
	local sent = FIRE_SERVER.OpenBox or 0
	el(unboxGui, "OpenNextButton").Activated:Fire()
	step(0.1)
	check((FIRE_SERVER.OpenBox or 0) == sent + 1, "G60 OPEN NEXT : OpenBox de l'établi 2 envoyé")
	check(unboxGui.Enabled and el(unboxGui, "RevealPanel").Visible == false and #d1.Boxes == 0 and d1.Boxes["2"] == nil, "G61 le serveur ouvre l'établi 2 à distance : nouvelle séquence")
	step(4.5)
	check(el(unboxGui, "ItemName").Text == "Usb Cable", "G62 objet de l'établi 2 révélé")
	check(el(unboxGui, "OpenNextButton").Visible == false, "G63 plus aucun autre établi prêt : pas d'OPEN NEXT")
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(0.05)
	-- Établi prêt mais trop loin : pas de bouton.
	placeReady(4, "Standard", 3, "Common", "Z3_UsbCable")
	placeReady(1, "Standard", 3, "Common", "Z3_Earbuds")
	openByPrompt(1)
	step(4.5)
	local far = (bench(plot1, 4).WorldPosition - root1.Position).Magnitude
	check(far > 12 and el(unboxGui, "OpenNextButton").Visible == false, `G64 établi 4 à {math.floor(far * 10) / 10} studs (> 12) : pas d'OPEN NEXT`)
	-- Le joueur s'approche pendant que les boutons sont là : le bouton apparaît.
	nearBench(root1, plot1, 3)
	step(0.4)
	check(el(unboxGui, "OpenNextButton").Visible, "G65 il s'approche de l'établi 4 : OPEN NEXT apparaît")
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(0.05)
	nearBench(root1, plot1, 4)
	step(0.05)
	prompt(4).Triggered:Fire()
	step(8)
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(0.05)
	check(unboxGui.Enabled == false and #diffSnapshot(studioState, unboxGui) == 0, "G66 écran remis après OPEN NEXT")
end

do
	-- Légendaire : Celebrate ; Secret : arc-en-ciel, texte blanc ; modèles livrés sans leurs scripts.
	local itemsFolder = folder(assets, "Items")
	local zoneFolder = folder(itemsFolder, "Zone2")
	local plush = new("Model", { Name = "ITM_Z2_GiantPlush" }, zoneFolder)
	local plushRoot = new("Part", { Name = "Root", Size = Vector3.new(1, 2.3, 1.6) }, plush)
	new("Script", { Name = "Spin" }, plushRoot)
	plush.PrimaryPart = plushRoot
	table.clear(ANIM.played)
	placeReady(1, "Luxe", 2, "Legendary", "Z2_GiantPlush")
	openByPrompt(1)
	step(4.6) -- gagnant au centre (dernier cran fini à 4,35 s), avant l'éclat
	local clone = el(unboxGui, "ReelView"):FindFirstChild("ITM_Z2_GiantPlush", true)
	local scripts = 0
	for _, m in el(unboxGui, "ReelView"):GetDescendants() do
		if m:IsA("LuaSourceContainer") then
			scripts += 1
		end
	end
	check(clone ~= nil and scripts == 0, "G67 le vrai modèle du gagnant dans ReelView, clones sans leurs scripts")
	step(0.6)
	local celebrate = false
	for _, a in ANIM.played do
		if a.name == "Celebrate" then
			celebrate = true
		end
	end
	check(celebrate, "G68 Légendaire : animation Celebrate demandée à l'éclat")
	local previewModel = el(unboxGui, "ItemPreview"):FindFirstChild("ITM_Z2_GiantPlush", true)
	check(previewModel ~= nil and previewModel:FindFirstChild("Spin", true) == nil, "G69 ItemPreview : le vrai modèle, sans script")
	step(4)
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(0.05)
	local secret = ItemsC.Secrets[1]
	placeReady(1, "Luxe", 5, "Secret", secret.Id)
	openByPrompt(1)
	step(5.0)
	check(el(unboxGui, "Rays.Rainbow").Enabled and sameColor(el(unboxGui, "Rays").ImageColor3, Color3.new(1, 1, 1)), "G70 Secret : Rays.Rainbow, rayons blancs")
	step(1.5)
	check(el(unboxGui, "Rarity").Text == "SECRET" and sameColor(el(unboxGui, "Rarity").TextColor3, Color3.new(1, 1, 1)) and el(unboxGui, "Rarity.Rainbow").Enabled, "G71 Secret : texte blanc et Rarity.Rainbow")
	step(3)
	local Format = requireModule(ReplicatedStorage.Shared.Format, "server")
	check(el(unboxGui, "Income").Text == Format.income(Formulas.ItemIncome(5, "Secret")), "G72 Secret : revenu affiché avec la zone du colis (" .. el(unboxGui, "Income").Text .. ")")
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(0.05)
	check(el(unboxGui, "Rays.Rainbow").Enabled == false and el(unboxGui, "Rarity.Rainbow").Enabled == false and #diffSnapshot(studioState, unboxGui) == 0, "G73 fermeture : arcs-en-ciel désactivés, écran remis")
	itemsFolder:Destroy()
end

do
	-- Animation Unbox livrée : ouverture au marqueur Open ; sons livrés : joués.
	local sounds = folder(assets, "Sounds")
	for _, name in { "Unbox_Tick", "Unbox_Open", "Unbox_Whoosh", "Unbox_Cash", "Unbox_Heartbeat", "Unbox_Riser" } do
		new("Sound", { Name = name }, sounds)
	end
	ANIM.delivered.Unbox = true
	table.clear(SOUNDS_PLAYED)
	placeReady(1, "Premium", 3, "Rare", "Z3_Smartphone")
	openByPrompt(1)
	step(0.6)
	check(el(unboxGui, "Reel").Visible == false, "G74 Unbox livrée : on attend le marqueur Open (pas d'ouverture à 0,45 s)")
	ANIM.fire("Unbox", "Open")
	step(1 / 30)
	check(el(unboxGui, "Reel").Visible, "G75 marqueur Open : ouverture")
	check(soundCount("Unbox_Open") == 0, "G76 au marqueur, Unbox_Open n'est pas rejoué ici (AnimationController le joue)")
	step(4.5)
	local ticks = soundCount("Unbox_Tick")
	print(string.format("    tics : %d ; battements : %d", ticks, soundCount("Unbox_Heartbeat")))
	check(ticks >= 15 and ticks <= 27, "G77 un tic par objet qui passe au centre (24 objets ; un par image au plus)")
	local maxRate = 0
	local times = {}
	for _, s in SOUNDS_PLAYED do
		if s.name == "Unbox_Tick" then
			table.insert(times, s.t)
		end
	end
	for i = 2, #times do
		if times[i] - times[i - 1] < 1 / 35 - 1e-9 then
			maxRate += 1
		end
	end
	check(maxRate == 0, "G78 tics : 35 par seconde au plus")
	check(soundCount("Unbox_Heartbeat") >= 1 and soundCount("Unbox_Riser") == 1 and soundCount("Unbox_Whoosh") == 1, "G79 Rare : battement de cœur, montée (riser) et whoosh")
	step(3)
	check(soundCount("Unbox_Cash") == 1, "G80 cha-ching à la fin du comptage")
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(0.05)
	ANIM.delivered.Unbox = nil
	sounds:Destroy()
end

do
	-- File : deux ouvertures d'affilée, la seconde après CONTINUE ; écran absent : la sortie seulement.
	placeReady(2, "Standard", 3, "Common", "Z3_UsbCable")
	placeReady(1, "Standard", 3, "Common", "Z3_Earbuds")
	openByPrompt(1)
	step(0.1)
	nearBench(root1, plot1, 2)
	step(0.05)
	prompt(2).Triggered:Fire()
	step(4.4)
	check(el(unboxGui, "ItemName").Text == "Earbuds", "G81 deux ouvertures d'affilée : la première d'abord")
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(4.5)
	check(unboxGui.Enabled and el(unboxGui, "ItemName").Text == "Usb Cable", "G82 puis la seconde")
	el(unboxGui, "ContinueButton").Activated:Fire()
	step(0.05)
	check(unboxGui.Enabled == false, "G83 file vide : écran fermé")
	unboxGui.Parent = nil
	clearLog()
	placeReady(1, "Standard", 3, "Common", "Z3_Earbuds")
	openByPrompt(1)
	step(0.2)
	check(logHas("écran UI_Unbox absent de PlayerGui", "WARN") and logHas(" : COMMON · Earbuds", "PRINT") and localBox() == nil, "G84 sans UI_Unbox : la sortie seulement, sans erreur, copie du colis jetée")
	unboxGui.Parent = playerGui
	-- Écran recréé (réapparition) pendant la séquence : la séquence s'arrête sans erreur.
	placeReady(1, "Standard", 3, "Common", "Z3_Earbuds")
	openByPrompt(1)
	step(1)
	unboxGui.Parent = nil
	step(0.2)
	unboxGui.Parent = playerGui
	unboxGui.Enabled = false
	check(true, "G85 écran retiré pendant la séquence : arrêt sans erreur")
	local errors = 0
	for _, line in FULL_LOG do
		if line.kind == "WARN" and string.find(line.text, "séquence d'ouverture interrompue", 1, true) then
			errors += 1
		end
	end
	check(errors == 0, "G86 aucune erreur dans la séquence pendant tout le banc")
end

print("\n== H. Contrat 2.2 : UI_Unbox v2 (Contract/UI)")
do
	local UI = requireModule(ReplicatedStorage.Shared.Contract.UI, "server")
	local Find = requireModule(ReplicatedStorage.Shared.Contract.Find, "server")
	local screen
	for _, s in UI.Screens do
		if s.Name == "UI_Unbox" then
			screen = s
		end
	end
	local paths = {}
	for _, e in screen.Elements do
		paths[e.Path] = e
	end
	for _, p in { "Rarity", "ItemName", "Income", "ContinueButton", "Backdrop", "SkipButton", "Upgrade", "Upgrade.UpgradeLabel", "Upgrade.UpgradeRarity", "Reel", "Reel.ReelGlow", "Reel.ReelView", "ItemPreview", "Rays", "Rarity.Rainbow", "Rays.Rainbow", "UpgradeRarity.Rainbow", "Confetti", "Confetti.Template", "Flash", "OpenNextButton" } do
		check(paths[p] ~= nil, `H1 contrat : {p}`)
	end
	local fresh = buildUnbox(nil)
	local bad = {}
	for _, e in screen.Elements do
		local found = Find.path(fresh, e.Path)
		if found == nil or (e.Class and not found:IsA(e.Class)) or (e.Template and found.Visible) then
			table.insert(bad, e.Path)
		end
		-- Comme le ContractChecker : un seul élément de ce nom à chaque étape du chemin.
		local current = fresh
		for segment in string.gmatch(e.Path, "[^%.]+") do
			if #Find.all(current, segment) ~= 1 then
				table.insert(bad, e.Path .. " (nom en double : " .. segment .. ")")
			end
			current = current and Find.path(current, segment)
		end
	end
	check(#bad == 0, "H2 l'écran v2 relevé dans Studio respecte tout le contrat (classes, Template caché, noms uniques)")
	for _, b in bad do
		print("      " .. b)
	end
	check(paths["Confetti.Template"].Template == true and paths["Reel.ReelView"].Class == "ViewportFrame" and paths["Rays"].Class == "ImageLabel" and paths["Rarity.Rainbow"].Class == "UIGradient", "H3 classes de la spec (ViewportFrame, ImageLabel, UIGradient, Template)")
end

print("\n== J. Vrai Config/Items (si déjà en v2)")
do
	local ok, real = pcall(function()
		local fn = assert(loadstring(REAL_ITEMS_SOURCE, "vrai Config/Items"))
		setfenv(fn, setmetatable({ script = Config.Items, require = function(target) return requireModule(target, "server") end, Random = Random }, { __index = getfenv(1) }))
		return fn()
	end)
	if not ok or type(real) ~= "table" or real.Pick == nil then
		print("    vrai catalogue encore en v1 (pas de Items.Pick) : section passée, à relancer après la fusion avec a22")
	else
		local zones, shapes = 0, true
		for zone = 1, 6 do
			for _, r in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
				local list = real.ByZone[zone] and real.ByZone[zone][r]
				if type(list) ~= "table" then
					shapes = false
				else
					for _, it in list do
						if it.Zone ~= zone or it.Rarity ~= r then
							shapes = false
						end
					end
				end
			end
			zones += 1
		end
		check(shapes, "J1 Items.ByZone[zone][rareté] : une liste par case, objets de cette zone et rareté")
		local picked = real.Pick(2, "Common", Random.new(3))
		check(picked ~= nil and picked.Zone == 2 and picked.Rarity == "Common", "J2 Items.Pick(2, \"Common\", rng)")
		check(type(real.Secrets) == "table" and #real.Secrets >= 1, "J3 Items.Secrets")
		local z1 = 0
		for _, r in { "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
			z1 += #(real.ByZone[1][r] or {})
		end
		print(string.format("    zone 1 : %d objet(s) hors Communs (le Pot de nouilles du tuto, s'il y est)", z1))
	end
end

print("\n== K. Copie a51 (L-089) : inventaire plein (Notify à la révélation), braquages réussis au rangement (Lifetime.Heists)")
do
	UnboxService.GetLuck = function()
		return 0
	end
	step(8) -- la file de révélations du client se vide (sans effet sur le serveur)
	local function placedCount(data)
		local n = 0
		for _, box in data.Boxes do
			if type(box) == "table" and box.Spot ~= nil then
				n += 1
			end
		end
		return n
	end
	check(placedCount(d1) == 0 and placedCount(d2) == 0, "K0 aucun colis posé chez Alice ni chez Bob")
	local function notifiesTo(player, kind, from)
		local out = {}
		for k = from + 1, #REMOTE_LOG do
			local r = REMOTE_LOG[k]
			-- Le message du rangement (« Box saved… », à l'entrée de la zone safe) n'est pas celui de l'ouverture.
			if r.name == "Notify" and r.to == player and (kind == nil or r.args[2] == kind) and string.sub(r.args[1], 1, 9) ~= "Box saved" then
				table.insert(out, r)
			end
		end
		return out
	end
	-- Inventaire plein : l'objet va sur un présentoir libre (PlaceAuto rend 1), message à la révélation.
	Display.inventoryRoom = false
	local calls = #Display.calls
	-- Version courte (Commun) : l'objet se révèle 3,0 s après UnboxReveal.
	local short = Unbox.OpenFallback + Unbox.ReelExit + Unbox.ReelDuration.Short + Unbox.LastNotch + Unbox.StopPause + Unbox.ColorIn
	check(near(short, 3.0, 1e-9), `révélation courte à 3,0 s (Config/Unbox : {short})`)
	clearLog()
	local before = #REMOTE_LOG
	local e = placeAndOpen(1, "Standard", 3, "Common", "Z3_Earbuds")
	check(e ~= nil and e.args[3] == "Z3_Earbuds" and #Display.calls == calls + 1, "K1 colis ouvert, inventaire plein : PlaceAuto appelé (présentoir libre)")
	check(#notifiesTo(P1, nil, before) == 0, "K2 aucun message à l'ouverture (l'objet n'est pas encore révélé)")
	step(short - 0.15)
	check(#notifiesTo(P1, nil, before) == 0, "K3 toujours rien juste avant la révélation")
	step(0.2)
	local n = notifiesTo(P1, nil, before)
	check(#n == 1 and n[1].args[2] == "Info", "K4 un seul message, catégorie « Info », au moment de la révélation")
	check(n[1] and n[1].args[1] == "Your inventory is full: Earbuds went on a display stand.", `K5 texte en anglais : « {n[1] and n[1].args[1]} »`)
	check(n[1] and e and math.abs(n[1].t - e.t - short) < 0.05, "K6 3,0 s après UnboxReveal, comme l'annonce")
	check(logHas("inventaire plein, Z3_Earbuds exposé sur le présentoir 1", "PRINT"), "K7 sortie Studio")
	check(#notifiesTo(P2, nil, before) == 0, "K8 rien pour les autres joueurs")

	-- Colis amélioré (2 crans, Commun → Rare, version complète) : 2 × 0,9 + 4,9 = 6,7 s, objet final.
	UnboxService.GetLuck = function()
		return 1000
	end
	local full = 2 * Unbox.UpgradeStep + Unbox.OpenFallback + Unbox.ReelExit + Unbox.ReelDuration.Full + Unbox.LastNotch + Unbox.StopPause + Unbox.ColorIn
	local before2 = #REMOTE_LOG
	local e2 = placeAndOpen(1, "Standard", 2, "Common", "Z2_RubberDuck")
	local final = e2 and Items.ById[e2.args[3]]
	check(final ~= nil and final.Rarity == "Rare" and e2.args[7] == 2, "K9 colis amélioré de 2 crans (Rare)")
	step(full - 0.15)
	check(#notifiesTo(P1, "Info", before2) == 0, "K10 pas de message avant la révélation (crans compris)")
	step(0.2)
	local n2 = notifiesTo(P1, "Info", before2)
	check(#n2 == 1 and final ~= nil and n2[1].args[1] == `Your inventory is full: {final.DisplayName} went on a display stand.`, "K11 message avec le nom de l'objet amélioré")
	check(n2[1] and e2 and math.abs(n2[1].t - e2.t - full) < 0.05, `K12 au moment de sa révélation ({full} s)`)
	UnboxService.GetLuck = function()
		return 0
	end

	-- Bob ouvre, puis quitte le serveur avant la révélation : pas de message.
	local bobUid = placeAtBench(P2, root2, plot2, 1, { Kind = "NPCBox", Tier = "Standard", Zone = 3, Rarity = "Common", ItemId = "Z3_Earbuds", StoreId = "STORE_Test", SlotId = "S/02" })
	step(2.1)
	local before3 = #REMOTE_LOG
	fire(P2, "OpenBox", bobUid)
	step(0.05)
	P2.Parent = nil
	step(short + 0.2)
	check(bobUid ~= nil and #notifiesTo(P2, nil, before3) == 0, "K13 joueur parti avant la révélation : pas de message")
	P2.Parent = Players

	-- Place dans l'inventaire (L-089 point 3) : l'objet y va, sans message ni présentoir.
	Display.inventoryRoom = true
	local before4 = #REMOTE_LOG
	local calls4 = #Display.calls
	placeAndOpen(1, "Standard", 3, "Common", "Z3_Earbuds")
	step(short + 0.2)
	check(#notifiesTo(P1, nil, before4) == 0 and #Display.calls == calls4, "K14 objet dans l'inventaire : aucun message, PlaceAuto pas appelé")
	-- Inventaire plein et PlaceAuto en erreur : avertissement seulement.
	Display.inventoryRoom = false
	local realPlaceAuto = Display.PlaceAuto
	Display.PlaceAuto = function()
		error("panne")
	end
	clearLog()
	local before5 = #REMOTE_LOG
	placeAndOpen(1, "Standard", 3, "Common", "Z3_Earbuds")
	step(short + 0.2)
	check(#notifiesTo(P1, nil, before5) == 0 and logHas("DisplayService.PlaceAuto (Alice", "WARN"), "K15 PlaceAuto en erreur : avertissement, pas de message")
	Display.PlaceAuto = realPlaceAuto
	Display.inventoryRoom = true

	-- Braquages réussis : Lifetime.Heists + 1 quand le colis volé entre dans l'inventaire (zone safe).
	local function payload(slot)
		return { Kind = "NPCBox", Tier = "Standard", Zone = 3, Rarity = "Common", ItemId = "Z3_Earbuds", StoreId = "STORE_Test", SlotId = slot }
	end
	local function countBoxes(data)
		local n = 0
		for _ in data.Boxes do
			n += 1
		end
		return n
	end
	step(1.1)
	local hA, hB = d1.Lifetime.Heists, d2.Lifetime.Heists
	check(hA >= 5 and hB == 1, `K16 chaque colis déjà rangé dans ce banc a compté (Alice : {hA}, Bob : {hB})`)
	clearLog()
	local bA = countBoxes(d1)
	nearBench(root1, plot1, 2)
	Carry._carry(P1, payload("S/10"))
	step(0.3)
	check(countBoxes(d1) == bA + 1 and d1.Lifetime.Heists == hA + 1 and not Carry.IsCarrying(P1), "K17 colis rangé à l'entrée de la zone safe : Lifetime.Heists + 1")
	check(logHas(`braquages réussis : {hA + 1})`, "PRINT"), "K18 sortie Studio : le nouveau compte")
	step(1)
	check(d1.Lifetime.Heists == hA + 1 and countBoxes(d1) == bA + 1, "K19 rien de rangé deux fois")
	-- Dans le couloir (hors zone safe) : rien n'est rangé ni compté, le colis reste porté.
	standAt(root1, Vector3.new(1000, 3, 0))
	Carry._carry(P1, payload("S/11"))
	step(1)
	check(d1.Lifetime.Heists == hA + 1 and Carry.IsCarrying(P1) and countBoxes(d1) == bA + 1, "K20 couloir : pas rangé, pas compté, toujours porté")
	-- Anti-triche sanctionné à l'entrée : pas compté.
	local AntiCheat = requireModule(services.AntiCheatService, "server")
	AntiCheat.verdict = false
	nearBench(root1, plot1, 2)
	step(0.3)
	check(d1.Lifetime.Heists == hA + 1 and countBoxes(d1) == bA + 1, "K21 déplacement sanctionné par l'anti-triche : pas rangé, pas compté")
	AntiCheat.verdict = true
	Carry._lose(P1)
	-- Rattrapé par le vigile dans le couloir (CarryService.Fail « Caught ») : plus rien à ranger.
	standAt(root1, Vector3.new(1000, 3, 0))
	Carry._carry(P1, payload("S/12"))
	step(0.3)
	Carry._lose(P1)
	nearBench(root1, plot1, 2)
	step(0.6)
	check(d1.Lifetime.Heists == hA + 1 and countBoxes(d1) == bA + 1, "K23 colis rattrapé : plus rien à ranger, pas compté")
	-- Lâché au coup de batte (Drop), ramassé par Bob et rentré : compté une fois, pour Bob.
	standAt(root1, Vector3.new(1000, 3, 0))
	Carry._carry(P1, payload("S/13"))
	step(0.3)
	local dropped = Carry._lose(P1)
	nearBench(root1, plot1, 2)
	step(0.6)
	check(d1.Lifetime.Heists == hA + 1 and countBoxes(d1) == bA + 1, "K24 colis lâché : Alice n'a plus rien à ranger")
	local bB = countBoxes(d2)
	standAt(root2, Vector3.new(1000, 3, 0))
	Carry._carry(P2, dropped)
	step(0.3)
	nearBench(root2, plot2, 2)
	step(0.6)
	check(d1.Lifetime.Heists == hA + 1 and d2.Lifetime.Heists == hB + 1 and countBoxes(d2) == bB + 1, "K25 ramassé et rentré par Bob : un braquage, pour Bob seulement")
	-- Profil abîmé : le colis est rangé quand même.
	d1.Lifetime.Heists = "x"
	nearBench(root1, plot1, 3)
	Carry._carry(P1, payload("S/14"))
	step(0.3)
	check(countBoxes(d1) == bA + 2 and d1.Lifetime.Heists == 1 and logHas("Lifetime.Heists illisible", "WARN"), "K26 Heists illisible : avertissement, repart de 0")
	local lifetime = d1.Lifetime
	d1.Lifetime = nil
	Carry._carry(P1, payload("S/15"))
	step(0.3)
	check(countBoxes(d1) == bA + 3 and logHas("Lifetime absent du profil", "WARN"), "K27 profil sans Lifetime : colis rangé quand même, avertissement")
	d1.Lifetime = lifetime
end

summary()
