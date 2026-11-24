--!nocheck
-- Scénarios du banc d'essai de DisplayService et DisplayController (DEV-020, agent a14).
-- DataService et PlotService sont des bouchons qui suivent leur API (attribution, libération,
-- chargement et libération du profil) ; Config, Contract et Net sont les vrais modules.

---------------------------------------------------------------- bouchons des services voisins
SOURCES["stub/DataService"] = [==[
local DataService = {}
local profiles = {}
local loaded, releasing = {}, {}
local function subscribe(list, fn)
	table.insert(list, fn)
	return function()
		local i = table.find(list, fn)
		if i then table.remove(list, i) end
	end
end
function DataService.Get(player) return profiles[player] end
function DataService.IsLoaded(player) return profiles[player] ~= nil end
function DataService.OnProfileLoaded(fn)
	local off = subscribe(loaded, fn)
	for p in profiles do task.spawn(fn, p) end
	return off
end
function DataService.OnProfileReleasing(fn) return subscribe(releasing, fn) end
function DataService.AddCash(player, amount)
	local d = profiles[player]
	if d == nil or type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then return nil end
	d.Cash += amount
	return d.Cash
end
function DataService._load(player, data)
	profiles[player] = data
	for _, fn in table.clone(loaded) do task.spawn(fn, player) end
end
-- Comme DataService : écouteurs appelés avant la libération, profil encore actif.
function DataService._release(player)
	if profiles[player] == nil then return end
	for _, fn in table.clone(releasing) do
		local ok, err = pcall(fn, player)
		if not ok then warn("OnProfileReleasing : " .. tostring(err)) end
	end
	profiles[player] = nil
end
return DataService
]==]

SOURCES["stub/PlotService"] = [==[
local PlotService = {}
local plotOf, ownerOf = {}, {}
local assigned, released = {}, {}
local function subscribe(list, fn)
	table.insert(list, fn)
	return function()
		local i = table.find(list, fn)
		if i then table.remove(list, i) end
	end
end
function PlotService.GetPlot(player) return plotOf[player] end
function PlotService.GetOwner(plot) return ownerOf[plot] end
function PlotService.OnPlotAssigned(fn)
	local off = subscribe(assigned, fn)
	for p, plot in table.clone(plotOf) do task.spawn(fn, p, plot) end
	return off
end
function PlotService.OnPlotReleased(fn) return subscribe(released, fn) end
function PlotService._assign(player, plot)
	plotOf[player] = plot
	ownerOf[plot] = player
	plot:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotIndex", plot:GetAttribute("PlotIndex"))
	for _, fn in table.clone(assigned) do task.spawn(fn, player, plot) end
end
-- Comme PlotService : écouteurs appelés après OwnerUserId = 0, sans yield.
function PlotService._release(player)
	local plot = plotOf[player]
	if plot == nil then return end
	plotOf[player] = nil
	ownerOf[plot] = nil
	plot:SetAttribute("OwnerUserId", 0)
	player:SetAttribute("PlotIndex", nil)
	for _, fn in table.clone(released) do
		local ok, err = pcall(fn, player, plot)
		if not ok then warn("OnPlotReleased : " .. tostring(err)) end
	end
end
return PlotService
]==]

---------------------------------------------------------------- montage de l'arbre
local function mount(rootFolder, prefix)
	local keys = {}
	for key in SOURCES do
		if string.sub(key, 1, #prefix) == prefix then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	for _, key in keys do
		local rel = string.sub(key, #prefix + 1)
		local parts = string.split(rel, "/")
		local parent = rootFolder
		for i = 1, #parts - 1 do
			parent = parent:FindFirstChild(parts[i]) or folder(parent, parts[i])
		end
		local name = string.gsub(parts[#parts], "%.luau$", "")
		moduleScript(parent, name, key)
	end
end

local Shared = folder(ReplicatedStorage, "Shared")
mount(Shared, "shared/")
local Server = folder(ServerScriptService, "Server")
local Services = folder(Server, "Services")
moduleScript(Services, "DataService", "stub/DataService")
moduleScript(Services, "PlotService", "stub/PlotService")
local displayModule = moduleScript(Services, "DisplayService", "server/Services/DisplayService.luau")
local Client = folder(StarterPlayerScripts, "Client")
local Controllers = folder(Client, "Controllers")
local controllerModule = moduleScript(Controllers, "DisplayController", "client/Controllers/DisplayController.luau")

---------------------------------------------------------------- décor de test
local SLOT_X = { -10, -5, 0, 5, 10 }
local SLOT_Z = { -8, -4, 0, 4 }
local PAD_X = { -18, -6, 6, 18 } -- a59 : plaques CollectPad_01 à _04
-- a59 : montant écrit sur la plaque n (« $2.9K » → 2900), nil sans texte lisible.
local function padText(plot, n)
	local pad = plot:FindFirstChild(string.format("CollectPad_%02d", n), true)
	local amount = pad and pad:FindFirstChild("Amount", true)
	return amount and amount.Text
end
local function padValue(plot, n)
	local text = padText(plot, n)
	local digits, suffix = string.match(text or "", "^%$([%d%.]+)(%a?)$")
	if digits == nil then
		return nil
	end
	local mult = ({ [""] = 1, K = 1e3, M = 1e6, B = 1e9 })[suffix] or 1
	return tonumber(digits) * mult
end
local function padPos(n, dx)
	return CFrame.new(PAD_X[n] + (dx or 0), 3.1, -30)
end
local function buildPlot(index)
	local plot = new("Model", { Name = string.format("PLOT_Test_%02d", index) })
	plot:SetAttribute("PlotIndex", index)
	local i = 0
	for _, z in SLOT_Z do
		for _, x in SLOT_X do
			i += 1
			local stand = new("Part", {
				Name = string.format("DisplayStand_%02d", i),
				Anchored = true,
				Size = Vector3.new(2, 2.5, 2),
				CFrame = CFrame.new(x, 1.25, z),
			}, plot)
			local slot = new("Attachment", { Name = string.format("DisplaySlot_%02d", i) }, stand)
			slot.WorldPosition = Vector3.new(x, 2.5, z)
		end
	end
	-- a59 (L-091) : plus de CashPad ; une plaque CollectPad_0n par présentoir de Rayon_01 (1 à 4), à
	-- z = −30, comme celles de Clément (Plate, AmountGui/Amount, BurstPoint et ses 3 ParticleEmitter, Glow).
	for n, x in PAD_X do
		local cf = CFrame.new(x, 0.36, -30)
		local pad = new("Part", { Name = string.format("CollectPad_%02d", n), Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.new(4.4, 0.12, 2.6), CFrame = cf }, plot)
		local plate = new("Part", { Name = "Plate", Anchored = true, CanCollide = false, Size = Vector3.new(4.4, 0.12, 2.6), CFrame = cf }, pad)
		plate:SetAttribute("SinkDepth", 0.1)
		local gui = new("SurfaceGui", { Name = "AmountGui" }, plate)
		new("TextLabel", { Name = "Amount", Text = "$0" }, gui)
		local burstPoint = new("Attachment", { Name = "BurstPoint" }, plate)
		for i, name in { "Sparkles", "Ring", "Coins" } do
			local emitter = new("ParticleEmitter", { Name = name, Enabled = false }, burstPoint)
			emitter:SetAttribute("EmitCount", ({ 22, 1, 10 })[i])
		end
		new("PointLight", { Name = "Glow", Enabled = false }, plate)
	end
	new("Part", { Name = "Bounds", Anchored = true, Transparency = 1, CanCollide = false, Size = Vector3.new(64, 24, 80), CFrame = CFrame.new(0, 12.1, 0) }, plot)
	plot.Parent = Workspace
	addTag(plot, "PlayerPlot")
	return plot
end

local function newPlayer(name, userId)
	local player = new("Player", { Name = name, UserId = userId, DisplayName = name }, Players)
	local character = new("Model", { Name = name }, Workspace)
	local root = new("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 3, 20) }, character)
	new("Humanoid", {}, character)
	player.Character = character
	return player, root, character
end

local function newProfile()
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

local nextUid = 1
local function give(data, id, extra)
	local uid = string.format("uid-%03d", nextUid)
	nextUid += 1
	data.Items[uid] = { Id = id, Source = "NPC", At = 0 }
	for k, v in extra or {} do
		data.Items[uid][k] = v
	end
	return uid
end

local function slotOf(data, uid)
	for key, stored in data.Display do
		if stored == uid then
			return tonumber(key)
		end
	end
	return nil
end

local function displayCount(data)
	local n = 0
	for _ in data.Display do
		n += 1
	end
	return n
end

local function item(plot, slot)
	local f = plot:FindFirstChild("DisplayItems")
	return f and f:FindFirstChild(string.format("DisplayItem_%02d", slot))
end

local function label(model, name)
	local bb = model:FindFirstChild("BB_Item")
	return bb and bb:FindFirstChild(name, true)
end

local function lastNotify(player)
	local list = notifies(player)
	return list[#list]
end

local function rarityColor(id)
	local hexes = { Common = "B0B7C3", Uncommon = "2FE08F", Rare = "2F9BFF", Epic = "A855F7", Legendary = "FFC21A", Mythic = "FF3B5C" }
	return Color3.fromHex("#" .. hexes[id])
end

