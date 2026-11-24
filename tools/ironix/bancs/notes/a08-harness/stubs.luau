--!nocheck
-- Bouchons Roblox minimalistes pour exécuter ToolService, WindowService, HitController
-- et le vrai module Net hors de Studio. Temps simulé, un seul VM, arbre d'instances partagé
-- entre « serveur » et « client » (réplication parfaite et instantanée).

SOURCES = {}
local FAILS = 0
local CHECKS = 0
LOG = {} -- lignes de sortie des modules (PRINT / WARN)
FULL_LOG = {}
REMOTE_LOG = {} -- envois serveur → client

---------------------------------------------------------------- temps et tâches
local simTime = 0
local queue = {}
local seq = 0
local function schedule(t, co, ...)
	seq += 1
	table.insert(queue, { t = t, seq = seq, co = co, args = table.pack(...) })
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		FAILS += 1
		print("ERREUR dans une tâche : " .. tostring(err))
		print(debug.traceback(co))
	end
end
taskLib = {}
function taskLib.spawn(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	resume(co, ...)
	return co
end
function taskLib.defer(f, ...)
	local co = coroutine.create(f)
	schedule(simTime, co, ...)
	return co
end
function taskLib.delay(d, f, ...)
	local co = coroutine.create(f)
	schedule(simTime + (d or 0), co, ...)
	return co
end
function taskLib.wait(d)
	local co = coroutine.running()
	local start = simTime
	schedule(simTime + math.max(d or 0, 1 / 60), co)
	coroutine.yield()
	return simTime - start
end
function advance(dt)
	local target = simTime + dt
	while true do
		local best, bestIndex = nil, nil
		for i, e in queue do
			if e.t <= target and (best == nil or e.t < best.t or (e.t == best.t and e.seq < best.seq)) then
				best, bestIndex = e, i
			end
		end
		if best == nil then
			break
		end
		table.remove(queue, bestIndex)
		simTime = math.max(simTime, best.t)
		resume(best.co, table.unpack(best.args, 1, best.args.n))
	end
	simTime = target
end
function now()
	return simTime
end

---------------------------------------------------------------- types de valeurs
Vector3 = {}
local V3MT = { __type = "Vector3" }
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3MT)
end
V3MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	end
	error("Vector3 : membre inconnu " .. tostring(k), 2)
end
V3MT.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3MT.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3MT.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3MT.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3MT.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3MT.__tostring = function(a)
	return string.format("(%.2f, %.2f, %.2f)", a.X, a.Y, a.Z)
end
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)

CFrame = {}
local CFMT = { __type = "CFrame" }
-- r = matrice 3×3 par lignes : r[1..3] ligne 1, etc.
local function cf(p, r)
	return setmetatable({ p = p, r = r }, CFMT)
end
local IDENTITY_R = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mulRV(r, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function mulRtV(r, v)
	return v3(r[1] * v.X + r[4] * v.Y + r[7] * v.Z, r[2] * v.X + r[5] * v.Y + r[8] * v.Z, r[3] * v.X + r[6] * v.Y + r[9] * v.Z)
end
local function mulRR(a, b)
	local out = {}
	for i = 0, 2 do
		for j = 0, 2 do
			out[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return out
end
CFMT.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "LookVector" then
		return v3(-c.r[3], -c.r[6], -c.r[9])
	elseif k == "PointToObjectSpace" then
		return function(self, v)
			return mulRtV(self.r, v - self.p)
		end
	elseif k == "PointToWorldSpace" then
		return function(self, v)
			return self.p + mulRV(self.r, v)
		end
	end
	error("CFrame : membre inconnu " .. tostring(k), 2)
end
CFMT.__mul = function(a, b)
	if getmetatable(b) == V3MT then
		return a.p + mulRV(a.r, b)
	end
	return cf(a.p + mulRV(a.r, b.p), mulRR(a.r, b.r))
end
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return cf(x, IDENTITY_R)
	end
	return cf(v3(x or 0, y or 0, z or 0), IDENTITY_R)
end
function CFrame.Angles(_rx, ry, _rz)
	local c, s = math.cos(ry), math.sin(ry)
	return cf(v3(0, 0, 0), { c, 0, s, 0, 1, 0, -s, 0, c })
end
CFrame.identity = CFrame.new(0, 0, 0)

Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
	-- ajout du Claude principal (2026-11-07) : Rarities lit ses couleurs en hexadécimal depuis la planche de style
	fromHex = function(hex)
		local h = string.gsub(hex, "#", "")
		return { R = tonumber(string.sub(h, 1, 2), 16) / 255, G = tonumber(string.sub(h, 3, 4), 16) / 255, B = tonumber(string.sub(h, 5, 6), 16) / 255 }
	end,
}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				return `Enum.{enumName}.{item}`
			end,
		})
	end,
})

---------------------------------------------------------------- signaux
local SignalMT = { __type = "RBXScriptSignal" }
SignalMT.__index = SignalMT
function newSignal()
	return setmetatable({ handlers = {}, waiting = {} }, SignalMT)
end
function SignalMT:Connect(fn)
	local handlers = self.handlers
	local conn = { Connected = true }
	conn.fn = fn
	function conn.Disconnect(c)
		c.Connected = false
		local i = table.find(handlers, c)
		if i then
			table.remove(handlers, i)
		end
	end
	table.insert(handlers, conn)
	return conn
end
function SignalMT:Fire(...)
	for _, c in table.clone(self.handlers) do
		if c.Connected then
			taskLib.spawn(c.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, co in waiting do
		resume(co, ...)
	end
end
function SignalMT:Wait()
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end

---------------------------------------------------------------- instances
local ISA = {
	Part = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	Workspace = { "Model", "PVInstance" },
	Tool = { "BackpackItem" },
	Script = { "BaseScript", "LuaSourceContainer" },
	LocalScript = { "Script", "BaseScript", "LuaSourceContainer" },
	ModuleScript = { "LuaSourceContainer" },
	RemoteEvent = { "BaseRemoteEvent" },
	UnreliableRemoteEvent = { "BaseRemoteEvent" },
}
local BASEPART_PROPS = {
	Anchored = false,
	CanCollide = true,
	CanQuery = true,
	CanTouch = true,
	Massless = false,
	Transparency = 0,
	Size = v3(4, 1, 2),
	CFrame = CFrame.identity,
	Color = Color3.new(0.6, 0.6, 0.6),
	Material = "Enum.Material.Plastic",
}
local NONE = setmetatable({}, { __tostring = function() return "nil" end }) -- propriété Instance? vide
local PROPS = {
	Part = BASEPART_PROPS,
	MeshPart = BASEPART_PROPS,
	Tool = { RequiresHandle = true, CanBeDropped = true, ToolTip = "", Enabled = true, ManualActivationOnly = false },
	WeldConstraint = { Part0 = NONE, Part1 = NONE },
	Model = { PrimaryPart = NONE, WorldPivot = CFrame.identity },
	Humanoid = { Health = 100 },
	Player = { UserId = 0, Character = NONE },
	Players = { LocalPlayer = NONE },
}
local EVENTS = {
	ChildAdded = true,
	ChildRemoved = true,
	AncestryChanged = true,
	Activated = true,
	CharacterAdded = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	OnServerEvent = true,
	OnClientEvent = true,
}

local Methods = {}
local InstanceMT = { __type = "Instance" }
local ALL = {} -- toutes les instances créées (pour GetJoints)
local tagsOf = {} -- [instance] = { [tag] = true }

local function isA(self, class)
	if rawget(self, "_class") == class or class == "Instance" then
		return true
	end
	for _, c in ISA[rawget(self, "_class")] or {} do
		if c == class then
			return true
		end
	end
	return false
end

local function defaultsFor(class)
	local props = { Name = class }
	for k, v in PROPS[class] or {} do
		props[k] = v
	end
	return props
end

InstanceMT.__index = function(self, key)
	local m = Methods[key]
	if m ~= nil then
		return m
	end
	if key == "ClassName" then
		return rawget(self, "_class")
	elseif key == "Parent" then
		return rawget(self, "_parent")
	elseif key == "Position" and isA(self, "BasePart") then
		return rawget(self, "_props").CFrame.Position
	end
	local props = rawget(self, "_props")
	local v = props[key]
	if v ~= nil then
		if v == NONE then
			return nil
		end
		return v
	end
	if EVENTS[key] then
		local signals = rawget(self, "_signals")
		signals[key] = signals[key] or newSignal()
		return signals[key]
	end
	for _, child in rawget(self, "_children") do
		if child.Name == key then
			return child
		end
	end
	error(`{rawget(self, "_class")} « {props.Name} » : membre inconnu « {key} »`, 2)
end

local function setParent(self, parent)
	if rawget(self, "_destroyed") then
		error("Parent verrouillé : instance détruite", 3)
	end
	local old = rawget(self, "_parent")
	if old == parent then
		return
	end
	if old then
		local list = rawget(old, "_children")
		local i = table.find(list, self)
		if i then
			table.remove(list, i)
		end
	end
	rawset(self, "_parent", parent)
	if parent then
		table.insert(rawget(parent, "_children"), self)
	end
	if old then
		old.ChildRemoved:Fire(self)
	end
	if parent then
		parent.ChildAdded:Fire(self)
	end
end

InstanceMT.__newindex = function(self, key, value)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	local props = rawget(self, "_props")
	local class = rawget(self, "_class")
	local known = key == "Name" or (PROPS[class] and PROPS[class][key] ~= nil)
	if not known then
		error(`{class} : propriété inconnue « {key} » (écriture)`, 2)
	end
	if value == nil then
		value = NONE
	end
	props[key] = value
end
InstanceMT.__tostring = function(self)
	return rawget(self, "_props").Name
end

local function newInstance(class)
	local self = setmetatable({
		_class = class,
		_props = defaultsFor(class),
		_children = {},
		_attrs = {},
		_attrSignals = {},
		_signals = {},
		_parent = nil,
		_destroyed = false,
	}, InstanceMT)
	table.insert(ALL, self)
	return self
end

function Methods.IsA(self, class)
	return isA(self, class)
end
function Methods.IsDescendantOf(self, ancestor)
	local inst = rawget(self, "_parent")
	while inst do
		if inst == ancestor then
			return true
		end
		inst = rawget(inst, "_parent")
	end
	return false
end
function Methods.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(inst)
		for _, c in rawget(inst, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Methods.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "_children") do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, d in Methods.GetDescendants(self) do
			if d.Name == name then
				return d
			end
		end
	end
	return nil
end
function Methods.FindFirstChildOfClass(self, class)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_class") == class then
			return c
		end
	end
	return nil
end
function Methods.WaitForChild(self, name, timeout)
	local deadline = simTime + (timeout or 5)
	while true do
		local c = Methods.FindFirstChild(self, name)
		if c then
			return c
		end
		if simTime >= deadline then
			return nil
		end
		taskLib.wait(0.03)
	end
end
function Methods.SetAttribute(self, name, value)
	local attrs = rawget(self, "_attrs")
	if attrs[name] == value then
		return
	end
	attrs[name] = value
	local s = rawget(self, "_attrSignals")[name]
	if s then
		s:Fire()
	end
end
function Methods.GetAttribute(self, name)
	return rawget(self, "_attrs")[name]
end
function Methods.GetAttributeChangedSignal(self, name)
	local signals = rawget(self, "_attrSignals")
	signals[name] = signals[name] or newSignal()
	return signals[name]
end
function Methods.Destroy(self)
	if rawget(self, "_destroyed") then
		return
	end
	for _, c in Methods.GetChildren(self) do
		Methods.Destroy(c)
	end
	setParent(self, nil)
	rawset(self, "_destroyed", true)
	for tag in tagsOf[self] or {} do
		CollectionServiceRemoved(self, tag)
	end
end
function Methods.Clone(self)
	local copy = newInstance(rawget(self, "_class"))
	for k, v in rawget(self, "_props") do
		rawget(copy, "_props")[k] = v
	end
	for k, v in rawget(self, "_attrs") do
		rawget(copy, "_attrs")[k] = v
	end
	for _, c in rawget(self, "_children") do
		Methods.Clone(c).Parent = copy
	end
	return copy
end
function Methods.GetFullName(self)
	local names = {}
	local inst = self
	while inst and rawget(inst, "_class") ~= "DataModel" do
		table.insert(names, 1, inst.Name)
		inst = rawget(inst, "_parent")
	end
	return table.concat(names, ".")
end
function Methods.GetJoints(self)
	local out = {}
	for _, inst in ALL do
		if rawget(inst, "_class") == "WeldConstraint" and not rawget(inst, "_destroyed") then
			if inst.Part0 == self or inst.Part1 == self then
				table.insert(out, inst)
			end
		end
	end
	return out
end
function Methods.GetBoundingBox(self)
	local lo, hi
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			local p, h = d.CFrame.Position, d.Size / 2
			local a, b = p - h, p + h
			lo = if lo then v3(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
			hi = if hi then v3(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
		end
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end
function Methods.EquipTool(self, tool)
	tool.Parent = rawget(self, "_parent")
end
-- Players
function Methods.GetPlayers(self)
	local out = {}
	for _, c in rawget(self, "_children") do
		if rawget(c, "_class") == "Player" then
			table.insert(out, c)
		end
	end
	return out
end
function Methods.GetPlayerByUserId(self, id)
	for _, p in Methods.GetPlayers(self) do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
-- Remotes (réseau simulé : un seul client, CLIENT_PLAYER)
CLIENT_PLAYER = nil
FIRE_SERVER = {} -- [nom du remote] = nombre d'envois du client
function Methods.FireServer(self, ...)
	FIRE_SERVER[self.Name] = (FIRE_SERVER[self.Name] or 0) + 1
	self.OnServerEvent:Fire(CLIENT_PLAYER, ...)
end
function Methods.FireAllClients(self, ...)
	table.insert(REMOTE_LOG, { t = simTime, name = self.Name, args = table.pack(...) })
	self.OnClientEvent:Fire(...)
end
function Methods.FireClient(self, player, ...)
	table.insert(REMOTE_LOG, { t = simTime, name = self.Name, to = player, args = table.pack(...) })
	if player == CLIENT_PLAYER then
		self.OnClientEvent:Fire(...)
	end
end

InstanceAPI = {
	new = function(class)
		return newInstance(class)
	end,
}

---------------------------------------------------------------- CollectionService
local tagged = {} -- [tag] = { instances }
local addedSignals, removedSignals = {}, {}
local function sig(map, tag)
	map[tag] = map[tag] or newSignal()
	return map[tag]
end
function addTag(inst, tag)
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], inst)
	tagsOf[inst] = tagsOf[inst] or {}
	tagsOf[inst][tag] = true
	sig(addedSignals, tag):Fire(inst)
end
function CollectionServiceRemoved(inst, tag)
	local list = tagged[tag]
	local i = list and table.find(list, inst)
	if i then
		table.remove(list, i)
	end
	sig(removedSignals, tag):Fire(inst)
end
local CollectionService = {
	GetTagged = function(_, tag)
		return table.clone(tagged[tag] or {})
	end,
	GetInstanceAddedSignal = function(_, tag)
		return sig(addedSignals, tag)
	end,
	GetInstanceRemovedSignal = function(_, tag)
		return sig(removedSignals, tag)
	end,
	AddTag = function(_, inst, tag)
		addTag(inst, tag)
	end,
}

---------------------------------------------------------------- arbre du jeu
DataModel = newInstance("DataModel")
local function service(class)
	local s = newInstance(class)
	s.Name = class
	s.Parent = DataModel
	return s
end
Workspace = service("Workspace")
ReplicatedStorage = service("ReplicatedStorage")
ServerScriptService = service("ServerScriptService")
StarterPlayerScripts = service("StarterPlayerScripts")
Players = service("Players")

function folder(parent, name)
	local f = newInstance("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- ModuleScript factice relié à une source
local moduleSource = {} -- [ModuleScript] = clé de SOURCES
function moduleScript(parent, name, key)
	local m = newInstance("ModuleScript")
	m.Name = name
	m.Parent = parent
	moduleSource[m] = key
	return m
end

---------------------------------------------------------------- require par côté
local function makeRunService(side)
	return {
		IsStudio = function()
			return true
		end,
		IsServer = function()
			return side == "server"
		end,
		IsClient = function()
			return side == "client"
		end,
		IsRunning = function()
			return true
		end,
	}
end
local games = {}
local caches = { server = {}, client = {} }
local function makeGame(side)
	local runService = makeRunService(side)
	local services = {
		Players = Players,
		ReplicatedStorage = ReplicatedStorage,
		RunService = runService,
		CollectionService = CollectionService,
		Workspace = Workspace,
	}
	return {
		GetService = function(_, name)
			return services[name] or error("service bouchonné absent : " .. name)
		end,
	}
end
games.server = makeGame("server")
games.client = makeGame("client")

local function typeofStub(v)
	local mt = getmetatable(v)
	if type(v) == "table" and type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return type(v)
end

function requireModule(m, side)
	local cache = caches[side]
	if cache[m] ~= nil then
		return cache[m]
	end
	local key = moduleSource[m]
	assert(key, "require d'un objet qui n'est pas un ModuleScript bouchonné : " .. tostring(m))
	local source = SOURCES[key]
	assert(source, "source absente : " .. key)
	local fn, err = loadstring(source, key)
	assert(fn, err)
	local env = setmetatable({
		game = games[side],
		workspace = Workspace,
		script = m,
		require = function(target)
			return requireModule(target, side)
		end,
		task = taskLib,
		os = {
			clock = function()
				return simTime
			end,
			time = function()
				return math.floor(simTime)
			end,
		},
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = Enum,
		Instance = InstanceAPI,
		typeof = typeofStub,
		warn = function(...)
			local parts = table.pack(...)
			for i = 1, parts.n do
				parts[i] = tostring(parts[i])
			end
			table.insert(LOG, { side = side, kind = "WARN", text = table.concat(parts, " ") })
			table.insert(FULL_LOG, { side = side, kind = "WARN", text = table.concat(parts, " ") })
		end,
		print = function(...)
			local parts = table.pack(...)
			for i = 1, parts.n do
				parts[i] = tostring(parts[i])
			end
			table.insert(LOG, { side = side, kind = "PRINT", text = table.concat(parts, " ") })
			table.insert(FULL_LOG, { side = side, kind = "PRINT", text = table.concat(parts, " ") })
		end,
	}, { __index = getfenv(1) })
	setfenv(fn, env)
	local result = fn()
	cache[m] = result
	return result
end

---------------------------------------------------------------- vérifications
function check(cond, label)
	CHECKS += 1
	if cond then
		print("  ok   " .. label)
	else
		FAILS += 1
		print("  ÉCHEC " .. label)
	end
end
function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end
function logHas(pattern, kind)
	for _, line in LOG do
		if (kind == nil or line.kind == kind) and string.find(line.text, pattern, 1, true) then
			return true
		end
	end
	return false
end
function clearLog()
	table.clear(LOG)
end
function remotes(name, id)
	local out = {}
	for _, e in REMOTE_LOG do
		if e.name == name and (id == nil or e.args[1] == id) then
			table.insert(out, e)
		end
	end
	return out
end
function summary()
	print(string.format("\n%d vérification(s), %d échec(s)", CHECKS, FAILS))
end
