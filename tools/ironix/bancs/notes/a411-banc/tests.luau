-- Banc a411 : DisguiseService (faux Roblox minimal ; SOURCES[chemin] = texte des modules, posé par run.sh).

local CHECKS, FAILS = 0, 0
local function check(cond, label)
	CHECKS += 1
	if not cond then
		FAILS += 1
		REAL_PRINT("ÉCHEC : " .. label)
	elseif VERBOSE then
		REAL_PRINT("ok : " .. label)
	end
end

---------------------------------------------------------------- temps et tâches
local T = 0
local queue, seq = {}, 0
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		FAILS += 1
		REAL_PRINT("ERREUR dans une tâche : " .. tostring(err) .. "\n" .. debug.traceback(co))
	end
end
local taskLib = {}
function taskLib.spawn(f, ...)
	local co = coroutine.create(f)
	resume(co, ...)
	return co
end
local function schedule(at, f, ...)
	seq += 1
	table.insert(queue, { t = at, seq = seq, co = if type(f) == "thread" then f else coroutine.create(f), args = table.pack(...) })
end
function taskLib.defer(f, ...)
	schedule(T, f, ...)
end
function taskLib.delay(d, f, ...)
	schedule(T + d, f, ...)
end
function taskLib.wait(d)
	schedule(T + math.max(d or 0, 1 / 60), coroutine.running())
	coroutine.yield()
end
local function advance(dt)
	local target = T + dt
	while true do
		local best, bestIndex = nil, nil
		for i, e in queue do
			if e.t <= target + 1e-9 and (best == nil or e.t < best.t or (e.t == best.t and e.seq < best.seq)) then
				best, bestIndex = e, i
			end
		end
		if best == nil then
			break
		end
		table.remove(queue, bestIndex)
		T = math.max(T, best.t)
		resume(best.co, table.unpack(best.args, 1, best.args.n))
	end
	T = target
end

---------------------------------------------------------------- valeurs
local V3 = {}
local function v3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V3)
end
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = v.Magnitude
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	end
	return nil
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	return v3(a.X * b, a.Y * b, a.Z * b)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
local Vector3 = { new = v3, zero = v3(0, 0, 0) }

-- CFrame sans rotation de repère : une position et un regard (les boîtes du banc sont alignées sur les axes).
local CF = {}
CF.__index = CF
local function cf(position, look)
	return setmetatable({ Position = position, LookVector = look or v3(0, 0, -1) }, CF)
end
CF.__mul = function(a, b)
	return cf(a.Position + b.Position, b.LookVector)
end
function CF:PointToObjectSpace(p)
	return p - self.Position
end
CF.__index = function(c, k)
	if k == "Rotation" then
		return cf(v3(0, 0, 0), rawget(c, "LookVector"))
	end
	return CF[k]
end
local CFrame = {
	new = function(x, y, z)
		return cf(if type(x) == "number" then v3(x, y, z) else x)
	end,
}
local Color3 = {
	fromRGB = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
	new = function(r, g, b)
		return { R = r * 255, G = g * 255, B = b * 255 }
	end,
}
local enumItems = {}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				local key = enumName .. "." .. item
				enumItems[key] = enumItems[key] or { Name = item }
				return enumItems[key]
			end,
		})
	end,
})

---------------------------------------------------------------- signaux
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local c = { fn = fn, connected = true }
		function c:Disconnect()
			c.connected = false
		end
		table.insert(s.handlers, c)
		return c
	end
	function s:Fire(...)
		for _, c in table.clone(s.handlers) do
			if c.connected then
				c.fn(...)
			end
		end
	end
	return s
end

---------------------------------------------------------------- monde
local ISA = {
	Part = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	Tool = {},
	Accessory = {},
}

local function makeWorld(options)
	options = options or {}
	local W = { notes = {}, allows = {}, denounced = {}, chases = {}, applied = {}, unequips = 0, warns = {} }
	local all = {} -- toutes les instances du monde (CollectionService)

	local I = {}
	local function inst(class, name, parent, props)
		local o = setmetatable({ ClassName = class, Name = name or class, _children = {}, _attrs = {}, _tags = {} }, I)
		if class == "Model" then
			rawset(o, "ChildAdded", signal())
		end
		for k, v in props or {} do
			rawset(o, k, v)
		end
		table.insert(all, o)
		if parent then
			o.Parent = parent
		end
		return o
	end
	W.inst = inst
	local M = {}
	I.__index = function(o, k)
		if k == "Parent" then
			return rawget(o, "_parent")
		end
		if k == "Position" and rawget(o, "CFrame") then
			return rawget(o, "CFrame").Position -- BasePart.Position
		end
		if M[k] ~= nil then
			return M[k]
		end
		for _, c in rawget(o, "_children") do
			if rawget(c, "Name") == k then
				return c
			end
		end
		return nil
	end
	I.__newindex = function(o, k, v)
		if k ~= "Parent" then
			rawset(o, k, v)
			return
		end
		local old = rawget(o, "_parent")
		if old == v then
			return
		end
		if old then
			table.remove(rawget(old, "_children"), table.find(rawget(old, "_children"), o))
		end
		rawset(o, "_parent", v)
		if v then
			table.insert(rawget(v, "_children"), o)
			local added = rawget(v, "ChildAdded")
			if added then
				added:Fire(o)
			end
		end
	end
	function M.IsA(o, class)
		return o.ClassName == class or class == "Instance" or table.find(ISA[o.ClassName] or {}, class) ~= nil
	end
	function M.GetChildren(o)
		return table.clone(rawget(o, "_children"))
	end
	function M.GetDescendants(o)
		local out = {}
		local function walk(x)
			for _, c in rawget(x, "_children") do
				table.insert(out, c)
				walk(c)
			end
		end
		walk(o)
		return out
	end
	function M.FindFirstChild(o, name, recursive)
		for _, c in (if recursive then o:GetDescendants() else rawget(o, "_children")) do
			if rawget(c, "Name") == name then
				return c
			end
		end
		return nil
	end
	function M.FindFirstChildOfClass(o, class)
		for _, c in rawget(o, "_children") do
			if c.ClassName == class then
				return c
			end
		end
		return nil
	end
	function M.IsDescendantOf(o, ancestor)
		local x = rawget(o, "_parent")
		while x do
			if x == ancestor then
				return true
			end
			x = rawget(x, "_parent")
		end
		return false
	end
	function M.GetAttribute(o, name)
		return rawget(o, "_attrs")[name]
	end
	function M.SetAttribute(o, name, value)
		rawget(o, "_attrs")[name] = value
	end
	function M.AddTag(o, tag)
		rawget(o, "_tags")[tag] = true
	end
	function M.RemoveTag(o, tag)
		rawget(o, "_tags")[tag] = nil
	end
	function M.HasTag(o, tag)
		return rawget(o, "_tags")[tag] == true
	end
	function M.GetPivot(o)
		if o:IsA("BasePart") then
			return o.CFrame
		end
		local root = o:FindFirstChild("HumanoidRootPart") or o:FindFirstChild("Base")
		return if root then root.CFrame else (rawget(o, "_pivot") or CFrame.new(0, 0, 0))
	end
	function M.PivotTo(o, target)
		local root = o:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = target
		else
			rawset(o, "_pivot", target)
		end
	end
	function M.Clone(o)
		local copy = inst(o.ClassName, o.Name, nil)
		for k, v in o do
			if type(k) == "string" and string.sub(k, 1, 1) ~= "_" and k ~= "ChildAdded" then
				rawset(copy, k, v)
			end
		end
		for k, v in rawget(o, "_attrs") do
			rawget(copy, "_attrs")[k] = v
		end
		if rawget(o, "_accessories") then
			rawset(copy, "_accessories", table.clone(rawget(o, "_accessories")))
		end
		for _, c in rawget(o, "_children") do
			c:Clone().Parent = copy
		end
		return copy
	end
	function M.Destroy(o)
		o.Parent = nil
		rawset(o, "_destroyed", true)
	end
	-- Humanoid
	function M.UnequipTools(o)
		W.unequips += 1
		local character = o.Parent
		for _, c in character:GetChildren() do
			if c.ClassName == "Tool" then
				c.Parent = rawget(character, "_backpack")
			end
		end
	end
	function M.GetAppliedDescription(o)
		return rawget(o, "_description"):Clone()
	end
	function M.ApplyDescription(o, description)
		taskLib.wait(0.2) -- comme Roblox : attend le chargement
		rawset(o, "_description", description:Clone())
		table.insert(W.applied, { humanoid = o, description = description, at = T })
	end
	function M.AddAccessory(o, accessory)
		accessory.Parent = o.Parent
	end
	-- HumanoidDescription
	function M.SetAccessories(o, list, _rigid)
		rawset(o, "_accessories", table.clone(list))
	end
	function M.GetAccessories(o, _rigid)
		return table.clone(rawget(o, "_accessories") or {})
	end

	local workspace = inst("Workspace", "Workspace")
	function workspace.GetServerTimeNow(_self)
		return 1000 + T
	end
	local playersService = inst("Players", "Players")
	function playersService.GetPlayers(_self)
		return playersService:GetChildren()
	end
	playersService.PlayerRemoving = signal()
	W.workspace, W.players = workspace, playersService
	local services = {
		Workspace = workspace,
		Players = playersService,
		CollectionService = {
			GetTagged = function(_self, tag)
				local out = {}
				for _, o in all do
					if rawget(o, "_tags")[tag] and not rawget(o, "_destroyed") then
						table.insert(out, o)
					end
				end
				return out
			end,
		},
		RunService = {
			IsStudio = function()
				return false
			end,
		},
	}

	-- Modules : jetons de chemin (script.Parent.X, Shared.Config.X), vrais modules depuis SOURCES, bouchons sinon.
	local stubs, cache = {}, {}
	W.stubs = stubs
	local tokenMT = {}
	local function token(path)
		return setmetatable({ _path = path }, tokenMT)
	end
	tokenMT.__index = function(t, k)
		local path = rawget(t, "_path")
		if k == "Parent" then
			return token((string.gsub(path, "/[^/]+$", "")))
		elseif k == "WaitForChild" or k == "FindFirstChild" then
			return function(self, name)
				return token(rawget(self, "_path") .. "/" .. name)
			end
		end
		return token(path .. "/" .. k)
	end
	services.ReplicatedStorage = { Shared = token("shared") }
	local game = {
		GetService = function(_self, name)
			return services[name] or error("service inconnu : " .. name)
		end,
	}
	local env
	local function load(t)
		local path = rawget(t, "_path")
		if stubs[path] ~= nil then
			return stubs[path]
		end
		if cache[path] ~= nil then
			return cache[path]
		end
		local src = SOURCES[path]
		assert(src, "module introuvable : " .. path)
		local fn, err = loadstring(src, "=" .. path)
		assert(fn, err)
		setfenv(fn, setmetatable({ script = t, require = load }, { __index = env }))
		local m = fn()
		cache[path] = m
		return m
	end
	env = setmetatable({
		game = game,
		task = taskLib,
		os = { clock = function()
			return T
		end },
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = Enum,
		Random = { new = function()
			return { NextInteger = function(_self, a, _b)
				return a
			end }
		end },
		typeof = function(value)
			if type(value) == "table" and getmetatable(value) == I then
				return "Instance"
			end
			return type(value)
		end,
		print = function() end,
		warn = function(...)
			local parts = {}
			for _, p in { ... } do
				table.insert(parts, tostring(p))
			end
			table.insert(W.warns, table.concat(parts, " "))
		end,
	}, { __index = getfenv(0) })
	W.load, W.token = load, token

	-- Bouchons partagés
	local zones = {}
	for n = 1, 6 do
		zones[n] = { Index = n, Theme = "Zone " .. n }
	end
	stubs["shared/Config/Zones"] = zones
	stubs["shared/Config/Witness"] = { Colors = {} }
	if options.featureOff then
		stubs["shared/Config/Features"] = { FittingRoom = false, Traps = true }
	end
	local handlers = {}
	W.handlers = handlers
	local function remote(name)
		return {
			Connect = function(_self, fn)
				handlers[name] = fn
			end,
			Fire = function(_self, player, ...)
				table.insert(W.notes, { player = player, remote = name, args = { ... } })
			end,
		}
	end
	stubs["shared/Net/Net"] = { Server = setmetatable({}, { __index = function(_, name)
		return remote(name)
	end }) }

	-- Bouchons des services
	W.safe = nil -- boîte de la zone safe : { min = v3, max = v3 }
	W.night = false
	W.carry, W.chased, W.levels, W.plots = {}, {}, {}, {}
	W.hitGates, W.windowHit, W.batHit, W.carryStarted, W.catch = {}, {}, {}, {}, {}
	W.circuits, W.witnesses, W.police = {}, {}, {}
	local svc = "server/Services/"
	stubs[svc .. "AntiCheatService"] = { Allow = function(player, seconds, reason)
		table.insert(W.allows, { player = player, seconds = seconds, reason = reason })
	end }
	stubs[svc .. "BatService"] = {
		IsDisguised = function()
			return false
		end,
		IsStunned = function()
			return false
		end,
		OnHit = function(fn)
			table.insert(W.batHit, fn)
		end,
	}
	stubs[svc .. "CarryService"] = {
		IsCarrying = function(player)
			return W.carry[player] ~= nil
		end,
		GetPayload = function(player)
			return W.carry[player]
		end,
		OnCarryStarted = function(fn)
			table.insert(W.carryStarted, fn)
		end,
	}
	stubs[svc .. "GuardService"] = {
		IsInSafeZone = function(p)
			local s = W.safe
			return s ~= nil and p.X >= s.min.X and p.X <= s.max.X and p.Z >= s.min.Z and p.Z <= s.max.Z
		end,
		IsChased = function(player)
			return W.chased[player] == true
		end,
		IsStunned = function()
			return false
		end,
		OnCatch = function(fn)
			table.insert(W.catch, fn)
		end,
		ChaseIntruder = function(player, store)
			table.insert(W.chases, { player = player, store = store })
			return true
		end,
	}
	stubs[svc .. "NightCycleService"] = { IsNight = function()
		return W.night
	end }
	stubs[svc .. "PlotService"] = { GetPlot = function(player)
		return W.plots[player]
	end }
	stubs[svc .. "SkillTreeService"] = { GetLevel = function(player, id)
		return (W.levels[player] or {})[id] or 0
	end }
	stubs[svc .. "StoreHeistService"] = {
		GetStoreId = function(store)
			return store.Name
		end,
		GetStoreModel = function(id)
			return W.storesByName[id]
		end,
	}
	stubs[svc .. "WindowService"] = {
		AddHitGate = function(fn)
			table.insert(W.hitGates, fn)
		end,
		OnHit = function(fn)
			table.insert(W.windowHit, fn)
		end,
	}
	stubs[svc .. "WitnessService"] = {
		GetZone = function(zone)
			return W.witnesses[zone] or {}, W.circuits[zone] or {}
		end,
		Denounce = function(store, players)
			table.insert(W.denounced, { store = store, players = table.clone(players) })
			local launched = {}
			for _, player in players do
				if not W.police[player] then
					table.insert(launched, { Player = player, Police = {} })
				end
			end
			return launched
		end,
	}

	-- Carte : zones le long de X (zone n à x = 200 × n), deux magasins par zone (z = ±60), vitrine à z = ±40.
	W.storesByName = {}
	local map = inst("Folder", "Map", workspace)
	for zone = 1, 6 do
		for side, name in { [-1] = "A", [1] = "B" } do
			local store = inst("Model", `STORE_Z{zone}_{name}`, map)
			rawset(store, "_pivot", CFrame.new(200 * zone, 0, 60 * side))
			store:SetAttribute("Zone", zone)
			store:AddTag("NPCStore")
			inst("Part", "Bounds", store, { CFrame = CFrame.new(200 * zone, 10, 60 * side), Size = v3(40, 20, 30) })
			inst("Part", "Window", store, { CFrame = CFrame.new(200 * zone, 5, 40 * side), Size = v3(20, 10, 1) })
			W.storesByName[store.Name] = store
		end
		W.circuits[zone] = { v3(200 * zone, 0, 0), v3(200 * zone + 30, 0, 0) }
	end
	W.safe = { min = v3(-100, 0, -100), max = v3(60, 0, 100) } -- le hub, avant la zone 1

	-- Joueur : personnage R15 minimal, boutique avec Bounds dans le hub.
	local userId = 0
	function W.addPlayer(name, position)
		userId += 1
		local player = inst("Player", name, playersService, { UserId = userId, DisplayName = name })
		local character = inst("Model", name, workspace)
		local backpack = inst("Backpack", "Backpack", player)
		rawset(character, "_backpack", backpack)
		inst("Part", "HumanoidRootPart", character, { CFrame = CFrame.new(position), Size = v3(2, 2, 1), AssemblyLinearVelocity = v3(1, 1, 1), AssemblyAngularVelocity = v3(1, 1, 1) })
		inst("Part", "Head", character, { CFrame = CFrame.new(position), Size = v3(1, 1, 1) })
		local humanoid = inst("Humanoid", "Humanoid", character, { Health = 100, HipHeight = 2, DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer })
		local description = inst("HumanoidDescription", "HumanoidDescription", nil, { HatAccessory = "111", Shirt = 5, Pants = 6, GraphicTShirt = 7, Face = 8, HeadColor = "peau du joueur" })
		description:SetAccessories({ "veste" }, true)
		rawset(humanoid, "_description", description)
		player.Character = character
		local plot = inst("Model", "Plot_" .. name, workspace)
		inst("Part", "Bounds", plot, { CFrame = CFrame.new(position), Size = v3(30, 20, 30) })
		W.plots[player] = plot
		W.levels[player] = { FittingRoom = 1 }
		return player, character, humanoid
	end
	function W.root(player)
		return player.Character.HumanoidRootPart
	end
	function W.moveTo(player, position, look)
		W.root(player).CFrame = cf(position, look)
	end
	function W.lastNote(player)
		for i = #W.notes, 1, -1 do
			if W.notes[i].player == player then
				return W.notes[i].args[1], W.notes[i].args[2]
			end
		end
		return nil
	end
	function W.start()
		local service = load(token("server/Services/DisguiseService"))
		service.Init()
		service.Start()
		W.service = service
		W.config = load(token("shared/Config/Disguise"))
		return service
	end
	return W
end

local function witnessModel(W, zone, withDescription)
	local model = W.inst("Model", `NPC_Witness_Z{zone}_01`, W.workspace)
	local humanoid = W.inst("Humanoid", "Humanoid", model)
	if withDescription then
		local d = W.inst("HumanoidDescription", "HumanoidDescription", humanoid, { HatAccessory = "999", Shirt = 50, Pants = 60, GraphicTShirt = 0, Face = 80, HeadColor = "peau du témoin" })
		d:SetAccessories({ "écharpe" }, true)
	else
		W.inst("BodyColors", "BodyColors", model, { HeadColor3 = "tête", TorsoColor3 = "torse", LeftArmColor3 = "bras", RightArmColor3 = "bras", LeftLegColor3 = "jambe", RightLegColor3 = "jambe" })
		W.inst("Shirt", "Shirt", model)
		W.inst("Pants", "Pants", model)
		W.inst("Accessory", "Cap", model)
		W.inst("Folder", "Animations", model)
	end
	W.witnesses[zone] = { model }
	return model
end

---------------------------------------------------------------- A. configuration et remotes
do
	local W = makeWorld()
	local SkillTree = W.load(W.token("shared/Config/SkillTree"))
	local skill = SkillTree.ById.FittingRoom
	check(skill ~= nil and skill.Coded == 1 and skill.MaxLevel == 1, "A1 tuile FittingRoom achetable, un niveau")
	check(skill and skill.Prices[1] == 50000 and skill.RequiresRebirth == nil and skill.OpensWhen == nil, "A2 prix V0 50 000, sans renaissance ni voisine")
	check(skill and skill.Tile == "Tile_FittingRoom", "A3 tuile Tile_FittingRoom")
	check(SkillTree.List[#SkillTree.List] == skill, "A4 ajoutée en fin de liste")
	local Definitions = W.load(W.token("shared/Net/Definitions"))
	local byName = {}
	for _, def in Definitions.List do
		byName[def.Name] = def
	end
	local d, n = byName.Disguise, byName.Denounce
	check(d and d.Direction == "ClientToServer" and #d.Args == 1 and d.Args[1].Kind == "int" and d.Args[1].Min == 1 and d.Args[1].Max == 6, "A5 remote Disguise(zone 1 à 6)")
	check(n and n.Direction == "ClientToServer" and #n.Args == 2 and n.Args[1].Kind == "string" and n.Args[2].Name == "phase", "A6 remote Denounce(storeName, phase)")
	check(Definitions.List[#Definitions.List] == n, "A7 remotes ajoutés en fin de liste")
	local Off = makeWorld({ featureOff = true })
	local offTree = Off.load(Off.token("shared/Config/SkillTree"))
	check(offTree.ById.FittingRoom.Coded == 0, "A8 interrupteur coupé : tuile « Soon »")
	Off.start()
	check(Off.handlers.Disguise == nil and Off.handlers.Denounce == nil and #Off.hitGates == 0 and #Off.batHit == 0, "A9 interrupteur coupé : rien n'est branché")
end

---------------------------------------------------------------- B. refus
do
	local W = makeWorld()
	local service = W.start()
	local M = W.config.Messages
	local p = W.addPlayer("Ana", v3(0, 3, 0))
	check(W.handlers.Disguise ~= nil and W.handlers.Denounce ~= nil, "B0 remotes branchés")
	W.levels[p] = {}
	W.handlers.Disguise(p, 1)
	check(W.lastNote(p) == M.NeedSkill and not service.IsDisguised(p), "B1 sans la compétence : refus")
	W.levels[p] = { FittingRoom = 1 }
	W.handlers.Disguise(p, 2)
	check(W.lastNote(p) == string.format(M.ZoneLocked, 2, 1), "B2 zone 2 sans renaissance : refus « Rebirth 1 »")
	p:SetAttribute("Rebirths", 1)
	W.handlers.Disguise(p, 3)
	check(W.lastNote(p) == string.format(M.ZoneLocked, 3, 2), "B3 zone 3 avec 1 renaissance : refus")
	local before = #W.notes
	W.handlers.Disguise(p, 7)
	check(#W.notes == before and not service.IsDisguised(p), "B4 zone inconnue : ignorée")
	W.night = true
	W.handlers.Disguise(p, 1)
	check(W.lastNote(p) == M.Night, "B5 la nuit : refus")
	W.night = false
	W.carry[p] = { Kind = "NPCItem", StoreId = "x" }
	W.handlers.Disguise(p, 1)
	check(W.lastNote(p) == M.Busy, "B6 mains pleines : refus")
	W.carry[p] = nil
	W.chased[p] = true
	W.handlers.Disguise(p, 1)
	check(W.lastNote(p) == M.Busy, "B7 poursuivi : refus")
	W.chased[p] = nil
	W.moveTo(p, v3(40, 3, 40))
	W.handlers.Disguise(p, 1)
	check(W.lastNote(p) == M.NotAtCabin, "B8 hors de sa boutique : refus")
	W.moveTo(p, v3(20, 3, 0)) -- dans Bounds + marge (15 + 12)
	local cabin = W.inst("Model", "FittingRoom", W.plots[p])
	rawset(cabin, "_pivot", CFrame.new(-10, 0, 0))
	W.handlers.Disguise(p, 1)
	check(W.lastNote(p) == M.NotAtCabin, "B9 modèle de cabine livré : à plus de Cabin.Range studs, refus")
	W.moveTo(p, v3(-2, 3, 0))
	W.circuits[2] = {}
	for _, store in W.storesByName do
		if store:GetAttribute("Zone") == 2 then
			store.Bounds:Destroy()
		end
	end
	W.handlers.Disguise(p, 2)
	check(W.lastNote(p) == M.NoSpot, "B10 zone sans circuit ni Bounds : refus")
	check(#W.allows == 0 and p:GetAttribute("Disguised") == nil, "B11 aucun refus ne déplace ni ne déguise")
	W.handlers.Disguise(p, 1)
	check(service.IsDisguised(p) and service.GetZone(p) == 1, "B12 à la cabine : accepté")
end

---------------------------------------------------------------- C. début, apparence, fin par le chrono, recharge
do
	local W = makeWorld()
	local service = W.start()
	local C, M = W.config, W.config.Messages
	local witness = witnessModel(W, 1, false)
	local p, character, humanoid = W.addPlayer("Ana", v3(0, 3, 0))
	local tool = W.inst("Tool", "Bat", character)
	W.handlers.Disguise(p, 1)
	check(service.IsDisguised(p), "C1 déguisé")
	check(p:GetAttribute("Disguised") == 1 and p:GetAttribute("DisguiseUntil") == 1000 + C.Duration and p:GetAttribute("DisguiseCanCall") == true, "C2 attributs Disguised, DisguiseUntil, DisguiseCanCall")
	local root = W.root(p)
	check(root.CFrame.Position.X == 200 and root.CFrame.Position.Z == 0 and root.CFrame.Position.Y == 3.5, "C3 posé sur le premier point du circuit de la zone 1, pieds au sol")
	check(#W.allows == 1 and W.allows[1].player == p, "C4 AntiCheatService.Allow avant le déplacement")
	check(root.AssemblyLinearVelocity == v3(0, 0, 0), "C5 vitesse remise à zéro")
	check(humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None, "C6 nom caché")
	check(tool.Parent ~= character, "C7 outil rangé au début")
	check(W.lastNote(p) == string.format(M.Started, C.Duration), "C8 message de début")
	check(#W.applied == 0, "C9 ApplyDescription attend : rien d'appliqué tout de suite")
	advance(0.3)
	local look = W.applied[1] and W.applied[1].description
	check(look ~= nil and look.HatAccessory == "" and look.Shirt == 0 and look.Pants == 0 and look.GraphicTShirt == 0 and #look:GetAccessories(true) == 0, "C10 description sans accessoires ni vêtements du joueur")
	check(look and look.HeadColor == "tête" and look.TorsoColor == "torse" and look.LeftLegColor == "jambe", "C11 couleurs de peau du témoin (BodyColors)")
	check(look and look.Face == 8, "C12 le corps du joueur est gardé (Face inchangée sans description du témoin)")
	local extras = {}
	for _, child in character:GetChildren() do
		if child:GetAttribute(C.ExtraAttribute) == true then
			extras[child.ClassName] = (extras[child.ClassName] or 0) + 1
		end
	end
	check(extras.Shirt == 1 and extras.Pants == 1 and extras.Accessory == 1 and extras.Folder == nil, "C13 Shirt, Pants et Accessory du témoin copiés, rien d'autre")
	check(#witness:GetChildren() == 6, "C14 le témoin de Clément n'est pas modifié")
	-- (c) outil en main et vitrine
	tool.Parent = character
	advance(0.05)
	check(tool.Parent ~= character and W.lastNote(p) == M.NoTools, "C15 (c) outil repris en main : rangé aussitôt, message")
	local q = W.addPlayer("Bob", v3(0, 3, 0))
	check(W.hitGates[1](p, "w", "NPC", {}) == false and W.hitGates[1](q, "w", "NPC", {}) == true, "C16 (c) coup de vitrine refusé pour le déguisé seulement")
	check(W.stubs["server/Services/BatService"].IsDisguised(p) == true and W.stubs["server/Services/BatService"].IsDisguised(q) == false, "C17 BatService.IsDisguised remplacé")
	-- (b) un seul déguisé par zone
	W.handlers.Disguise(q, 1)
	check(W.lastNote(q) == M.ZoneTaken and not service.IsDisguised(q), "C18 (b) zone déjà prise : refus")
	q:SetAttribute("Rebirths", 1)
	W.handlers.Disguise(q, 2)
	check(service.IsDisguised(q) and W.root(q).CFrame.Position.X == 400, "C19 (b) une autre zone reste libre")
	-- chrono
	advance(C.Duration - 1)
	check(service.IsDisguised(p), "C20 encore déguisé avant la fin du chrono")
	advance(1.5)
	check(not service.IsDisguised(p) and W.lastNote(p) == M.Ended, "C21 fin au bout de Duration s")
	check(p:GetAttribute("Disguised") == nil and p:GetAttribute("DisguiseUntil") == nil and p:GetAttribute("DisguiseCanCall") == nil, "C22 attributs retirés")
	local ready = p:GetAttribute("DisguiseReadyAt")
	check(type(ready) == "number" and math.abs(ready - (1000 + T + C.Cooldown)) < 1, "C23 (a) attribut DisguiseReadyAt = fin + Cooldown")
	check(humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.Viewer, "C24 nom rendu")
	advance(0.3)
	local back = nil
	for _, entry in W.applied do
		if entry.humanoid == humanoid then
			back = entry -- la dernière description appliquée à ce joueur
		end
	end
	check(back ~= W.applied[1] and back.description.HatAccessory == "111" and back.description.Shirt == 5 and back.description.HeadColor == "peau du joueur" and back.description:GetAccessories(true)[1] == "veste", "C25 apparence du joueur réappliquée")
	local left = 0
	for _, child in character:GetChildren() do
		if child:GetAttribute(C.ExtraAttribute) == true then
			left += 1
		end
	end
	check(left == 0, "C26 vêtements du témoin retirés")
	check(W.root(p).CFrame.Position.X == 200, "C27 il reste où il est")
	-- recharge
	W.moveTo(p, v3(0, 3, 0))
	W.handlers.Disguise(p, 1)
	check(not service.IsDisguised(p) and string.find(W.lastNote(p), "Fitting room ready in", 1, true) ~= nil, "C28 (a) recharge : refus")
	check(service.GetCooldown(p) > C.Cooldown - 2, "C29 GetCooldown")
	advance(C.Cooldown)
	W.handlers.Disguise(p, 1)
	check(service.IsDisguised(p), "C30 (a) recharge finie : accepté")
	check(#W.warns == 0, "C31 aucun avertissement")
end

---------------------------------------------------------------- D. apparence : témoin avec HumanoidDescription, zone sans témoin
do
	local W = makeWorld()
	W.start()
	local C = W.config
	witnessModel(W, 1, true)
	local p, character = W.addPlayer("Ana", v3(0, 3, 0))
	W.handlers.Disguise(p, 1)
	advance(0.3)
	local look = W.applied[1].description
	check(look.HatAccessory == "999" and look.Shirt == 50 and look.Pants == 60 and look.Face == 80 and look.HeadColor == "peau du témoin" and look:GetAccessories(true)[1] == "écharpe", "D1 description du témoin appliquée")
	local extra = 0
	for _, child in character:GetChildren() do
		if child:GetAttribute(C.ExtraAttribute) then
			extra += 1
		end
	end
	check(extra == 0, "D2 avec une description, rien n'est copié à la main")
	local q = W.addPlayer("Bob", v3(0, 3, 0))
	q:SetAttribute("Rebirths", 1)
	W.handlers.Disguise(q, 2)
	advance(0.3)
	local fallback = W.applied[2].description
	check(fallback.HeadColor == C.FallbackSkin and fallback.TorsoColor == C.FallbackTorso and fallback.LeftLegColor == C.FallbackLegs and fallback.Shirt == 0, "D3 zone sans témoin : couleurs de repli")
	-- démasqué avant la fin d'ApplyDescription : la file garde l'ordre
	local r, _, rh = W.addPlayer("Cid", v3(0, 3, 0))
	r:SetAttribute("Rebirths", 2)
	W.handlers.Disguise(r, 3)
	W.service.Unmask(r, "Bat")
	advance(1)
	local last = W.applied[#W.applied]
	check(last.humanoid == rh and last.description.HatAccessory == "111", "D4 démasqué pendant l'habillage : l'apparence du joueur revient en dernier")
end

---------------------------------------------------------------- E. dénonciation
do
	local W = makeWorld()
	local service = W.start()
	local C, M = W.config, W.config.Messages
	local Gauge = W.load(W.token("shared/WitnessGauge"))
	local p, character = W.addPlayer("Ana", v3(0, 3, 0))
	local thiefIn = W.addPlayer("Bob", v3(200, 3, -60)) -- dans Bounds de STORE_Z1_A
	local thiefHit = W.addPlayer("Cid", v3(200, 3, -30)) -- devant la vitrine, vient de frapper
	local carrier = W.addPlayer("Dan", v3(230, 3, -20)) -- porte un objet du magasin, dehors
	local bystander = W.addPlayer("Eve", v3(200, 3, -20)) -- passant
	local farCarrier = W.addPlayer("Fay", v3(330, 3, -40)) -- porte un objet du magasin, trop loin
	local safeThief = W.addPlayer("Gus", v3(0, 3, 0)) -- a frappé, mais à l'abri
	local storeA, storeB = W.storesByName.STORE_Z1_A, W.storesByName.STORE_Z1_B
	W.carry[carrier] = { Kind = "NPCItem", StoreId = "STORE_Z1_A" }
	W.carry[farCarrier] = { Kind = "NPCItem", StoreId = "STORE_Z1_A" }
	W.windowHit[1](thiefHit, "w", "NPC", storeA, 1)
	W.windowHit[1](safeThief, "w", "NPC", storeA, 1)
	W.windowHit[1](bystander, "w", "Plot", storeA, 1)
	W.handlers.Disguise(p, 1)
	W.moveTo(p, v3(200, 3, 0), v3(0, 0, -1)) -- au milieu de la rue, tourné vers le magasin A (z < 0)
	local before = #W.notes
	W.handlers.Denounce(p, "STORE_Z1_A", "Start")
	W.handlers.Denounce(p, "STORE_Z2_A", "Begin")
	W.handlers.Denounce(p, "nimporte", "Begin")
	check(#W.notes == before and not character:HasTag(Gauge.Tag), "E1 étape inconnue, magasin d'une autre zone ou inconnu : ignorés")
	W.moveTo(p, v3(200, 3, 0), v3(0, 0, 1))
	W.handlers.Denounce(p, "STORE_Z1_A", "Begin")
	check(W.lastNote(p) == M.NotFacing and not character:HasTag(Gauge.Tag), "E2 dos au magasin : refus")
	W.moveTo(p, v3(200 + 30, 3, 10), v3(0, 0, -1))
	W.handlers.Denounce(p, "STORE_Z1_A", "Begin")
	check(W.lastNote(p) == M.TooFar, "E3 à plus de DenounceRange studs de la vitrine : refus")
	W.moveTo(p, v3(200, 3, 0), v3(0, 0, -1))
	W.handlers.Denounce(p, "STORE_Z1_A", "Begin")
	check(character:HasTag(Gauge.Tag) and character:GetAttribute(Gauge.StateAttribute) == "Watch" and character:GetAttribute(Gauge.FillAttribute) == 0 and character:GetAttribute(Gauge.RateAttribute) == 1 / C.DenounceTime, "E4 (d) le « ? » des témoins monte au-dessus de lui")
	advance(1)
	W.handlers.Denounce(p, "STORE_Z1_A", "End")
	check(#W.denounced == 0 and not character:HasTag(Gauge.Tag) and p:GetAttribute("DisguiseCanCall") == true, "E5 (d) maintien trop court : rien, la dénonciation reste")
	W.handlers.Denounce(p, "STORE_Z1_A", "End")
	check(#W.denounced == 0, "E6 « End » sans « Begin » : rien")
	W.handlers.Denounce(p, "STORE_Z1_A", "Begin")
	W.handlers.Denounce(p, "STORE_Z1_A", "Cancel")
	check(not character:HasTag(Gauge.Tag) and character:GetAttribute(Gauge.StateAttribute) == nil, "E7 « Cancel » : le « ? » disparaît")
	advance(C.DenounceTime)
	W.handlers.Denounce(p, "STORE_Z1_A", "End")
	check(#W.denounced == 0, "E8 « End » après « Cancel » : rien")
	W.handlers.Denounce(p, "STORE_Z1_A", "Begin")
	advance(C.DenounceTime)
	W.handlers.Denounce(p, "STORE_Z1_B", "End")
	check(#W.denounced == 0, "E9 « End » sur un autre magasin que le « Begin » : rien")
	W.handlers.Denounce(p, "STORE_Z1_A", "Begin")
	advance(C.DenounceTime + C.HoldExpiry + 1)
	check(not character:HasTag(Gauge.Tag), "E10 maintien oublié au bout de HoldExpiry s")
	W.handlers.Denounce(p, "STORE_Z1_A", "End")
	check(#W.denounced == 0, "E11 « End » d'un maintien oublié : rien")
	W.police[thiefHit] = true -- déjà poursuivi par un policier : la police le refuse
	W.handlers.Denounce(p, "STORE_Z1_A", "Begin")
	advance(C.DenounceTime - 0.1)
	W.windowHit[1](thiefHit, "w", "NPC", storeA, 1)
	W.handlers.Denounce(p, "STORE_Z1_A", "End")
	local call = W.denounced[1]
	check(call ~= nil and call.store == storeA, "E12 dénonciation acceptée (avance de HoldTolerance s) : WitnessService.Denounce")
	check(call and #call.players == 3 and call.players[1] == carrier and table.find(call.players, thiefIn) ~= nil and table.find(call.players, thiefHit) ~= nil, "E13 voleurs : le porteur d'abord, puis celui dans le magasin et celui qui a frappé")
	check(call and not table.find(call.players, bystander) and not table.find(call.players, farCarrier) and not table.find(call.players, safeThief) and not table.find(call.players, p), "E14 ni le passant, ni le porteur trop loin, ni celui à l'abri, ni le dénonciateur")
	check(W.lastNote(p) == string.format(M.Called, 2), "E15 message : 2 policiers lancés (le 3e voleur est déjà poursuivi)")
	check(W.lastNote(carrier) == M.Denounced and W.lastNote(thiefIn) == M.Denounced and W.lastNote(thiefHit) ~= M.Denounced, "E16 les voleurs poursuivis sont prévenus")
	check(p:GetAttribute("DisguiseCanCall") == false, "E17 (f) une seule dénonciation : DisguiseCanCall = false")
	check(character:HasTag(Gauge.Tag) and character:GetAttribute(Gauge.StateAttribute) == "Call", "E18 « ! » au-dessus de lui")
	advance(C.CallShowTime + 0.1)
	check(not character:HasTag(Gauge.Tag), "E19 « ! » retiré après CallShowTime s")
	check(service.IsDisguised(p), "E20 il reste déguisé après la dénonciation")
	W.handlers.Denounce(p, "STORE_Z1_B", "Begin")
	check(W.lastNote(p) == M.NoCall and not character:HasTag(Gauge.Tag), "E21 seconde dénonciation : refus")
	-- (f) personne ne braque le magasin
	local q, qc = W.addPlayer("Hal", v3(0, 3, 0))
	q:SetAttribute("Rebirths", 1)
	W.handlers.Disguise(q, 2)
	W.moveTo(q, v3(400, 3, 0), v3(0, 0, 1))
	W.handlers.Denounce(q, "STORE_Z2_B", "Begin")
	advance(C.DenounceTime)
	W.handlers.Denounce(q, "STORE_Z2_B", "End")
	check(#W.denounced == 1 and W.lastNote(q) == M.NobodyThere and q:GetAttribute("DisguiseCanCall") == false, "E22 (f) personne : rien ne se passe, la dénonciation est dépensée")
	check(qc:GetAttribute(Gauge.StateAttribute) == "Call", "E23 (f) le « ! » se montre quand même")
	-- un déguisé n'est pas un voleur
	local s = W.addPlayer("Ian", v3(0, 3, 0))
	s:SetAttribute("Rebirths", 2)
	W.handlers.Disguise(s, 3)
	W.moveTo(s, v3(600, 3, -60)) -- dans le magasin A de la zone 3
	local r = W.addPlayer("Jo", v3(0, 3, 0))
	advance(C.Cooldown) -- rien à voir : laisse finir les déguisements
	check(not service.IsDisguised(s) and not service.IsDisguised(p), "E24 déguisements finis")
	check(#W.warns == 0, "E25 aucun avertissement")
	local _ = r
end

---------------------------------------------------------------- F. fins : batte, objet pris, zone quittée, zone safe, nuit, capture, mort, départ
do
	local W = makeWorld()
	local service = W.start()
	local C, M = W.config, W.config.Messages
	local function disguised(name, zone)
		local p, character, humanoid = W.addPlayer(name, v3(0, 3, 0))
		p:SetAttribute("Rebirths", zone - 1)
		W.handlers.Disguise(p, zone)
		return p, character, humanoid
	end
	-- batte
	local p = disguised("Ana", 1)
	local hitter = W.addPlayer("Bob", v3(200, 3, 2))
	W.batHit[1](hitter, p, "Unmask", nil)
	check(not service.IsDisguised(p) and W.lastNote(p) == M.Unmasked, "F1 coup de batte : démasqué")
	check(W.lastNote(hitter) == string.format(M.UnmaskedBy, "Ana"), "F2 le frappeur est prévenu")
	check(p:GetAttribute("Disguised") == nil and type(p:GetAttribute("DisguiseReadyAt")) == "number", "F3 attributs de fin")
	local before = #W.notes
	W.batHit[1](hitter, p, "Box", nil)
	check(#W.notes == before, "F4 coup de batte sur un joueur pas déguisé : rien")
	-- objet pris, aucun vigile : un vigile du magasin sort
	local q = disguised("Cid", 2)
	local payload = { Kind = "NPCItem", StoreId = "STORE_Z2_B" }
	W.carry[q] = payload
	W.carryStarted[1](q, payload)
	check(not service.IsDisguised(q) and W.lastNote(q) == M.Took, "F5 objet pris : il redevient joueur")
	check(#W.chases == 0, "F6 le vigile n'est pas demandé tout de suite")
	advance(0.6)
	check(#W.chases == 1 and W.chases[1].player == q and W.chases[1].store == W.storesByName.STORE_Z2_B, "F7 sans vigile à ses trousses : un vigile du magasin de l'objet sort")
	-- objet pris, déjà poursuivi : rien de plus
	local r = disguised("Dan", 3)
	W.carry[r] = { Kind = "NPCItem", StoreId = "STORE_Z3_A" }
	W.chased[r] = true
	W.carryStarted[1](r, W.carry[r])
	advance(0.6)
	check(not service.IsDisguised(r) and #W.chases == 1, "F8 déjà poursuivi par le vigile du vol : aucun second vigile")
	-- objet volé à un joueur : démasqué, pas de vigile
	local s = disguised("Eve", 4)
	W.carry[s] = { Kind = "PlayerItem" }
	W.carryStarted[1](s, W.carry[s])
	advance(0.6)
	check(not service.IsDisguised(s) and #W.chases == 1, "F9 objet d'un joueur : démasqué, aucun vigile demandé")
	W.carryStarted[1](hitter, { Kind = "NPCItem", StoreId = "STORE_Z1_A" })
	advance(0.6)
	check(#W.chases == 1, "F10 prise d'un joueur pas déguisé : rien")
	-- zone quittée
	local t = disguised("Fay", 5)
	W.moveTo(t, v3(1000 + 105, 3, 0)) -- plus près des magasins de la zone 6
	advance(C.LeaveGrace - 0.6)
	check(service.IsDisguised(t), "F11 hors de la zone depuis moins de LeaveGrace s : encore déguisé")
	W.moveTo(t, v3(1000, 3, 0))
	advance(1)
	W.moveTo(t, v3(1000 + 105, 3, 0))
	advance(C.LeaveGrace - 0.6)
	check(service.IsDisguised(t), "F12 revenu dans sa zone : le délai repart de zéro")
	advance(1.2)
	check(not service.IsDisguised(t) and W.lastNote(t) == M.LeftZone, "F13 zone quittée : il redevient joueur")
	-- zone safe
	advance(C.Cooldown)
	local u = disguised("Gus", 1)
	W.moveTo(u, v3(50, 3, 0))
	advance(C.LeaveGrace + 0.6)
	check(not service.IsDisguised(u) and W.lastNote(u) == M.LeftZone, "F14 entré en zone safe : il redevient joueur")
	-- nuit
	local v = disguised("Hal", 2)
	W.night = true
	advance(0.5)
	check(not service.IsDisguised(v) and W.lastNote(v) == M.Night, "F15 tombée de la nuit : il redevient joueur")
	W.night = false
	-- capture
	local w = disguised("Ian", 3)
	W.catch[1](w, 3, false, false)
	check(not service.IsDisguised(w) and W.lastNote(w) == M.Unmasked, "F16 attrapé : démasqué")
	-- mort
	local x, _, xh = disguised("Jo", 4)
	xh.Health = 0
	advance(0.5)
	check(not service.IsDisguised(x) and x:GetAttribute("Disguised") == nil, "F17 mort : fin du déguisement")
	-- départ
	local y = disguised("Kim", 5)
	y.Parent = nil
	W.players.PlayerRemoving:Fire(y)
	check(not service.IsDisguised(y) and service.GetCooldown(y) == 0, "F18 départ : oublié")
	-- la zone est libérée pour un autre
	local z = disguised("Lou", 5)
	check(service.IsDisguised(z), "F19 la zone d'un joueur parti est libre")
	check(service.Unmask(z) == true and service.Unmask(z) == false, "F20 Unmask : vrai une fois")
	check(#W.warns == 0, "F21 aucun avertissement")
end

REAL_PRINT(`banc a411 : {CHECKS} vérification(s), {FAILS} échec(s)`)
