-- Faux Roblox minimal pour TrainingService (banc a58). Pas de physique : les soudures sont
-- vérifiées par leurs propriétés, le déplacement de la barre par la main est simulé à la main.

NOW = 100
LOGS = {}

-- Vector3 ------------------------------------------------------------------------
local V = {}
local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	end
	if k == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		return vec(self.X / m, self.Y / m, self.Z / m)
	end
	return nil
end
V.__add = function(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V.__sub = function(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V.__mul = function(a, b)
	if type(b) == "number" then
		return vec(a.X * b, a.Y * b, a.Z * b)
	end
	if type(a) == "number" then
		return vec(b.X * a, b.Y * a, b.Z * a)
	end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b)
	if type(b) == "number" then
		return vec(a.X / b, a.Y / b, a.Z / b)
	end
	return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V.__tostring = function(a)
	return "(" .. a.X .. ", " .. a.Y .. ", " .. a.Z .. ")"
end
Vector3 = { new = vec, zero = vec(0, 0, 0) }

-- CFrame (translations seulement, regard vers -Z) --------------------------------
local C = {}
local function cf(p)
	return setmetatable({ Position = p }, C)
end
C.__index = function(self, k)
	if k == "LookVector" then
		return vec(0, 0, -1)
	end
	if k == "PointToObjectSpace" then
		return function(s, p)
			return p - s.Position
		end
	end
	return nil
end
C.__mul = function(a, b)
	if getmetatable(b) == C then
		return cf(a.Position + b.Position)
	end
	return a.Position + b
end
C.__eq = function(a, b)
	return a.Position == b.Position
end
C.__tostring = function(a)
	return "CFrame" .. tostring(a.Position)
end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then
			return cf(x)
		end
		return cf(vec(x, y, z))
	end,
	lookAt = function(p, _target)
		return cf(p)
	end,
}

-- Enum ----------------------------------------------------------------------------
local function enumOf(names)
	local e = {}
	for _, n in names do
		e[n] = { Name = n }
	end
	return e
end
Enum = {
	HumanoidStateType = enumOf({
		"Jumping", "Freefall", "Seated", "Climbing", "Swimming", "FallingDown", "Ragdoll",
		"PlatformStanding", "Physics", "Flying", "Running", "Landed",
	}),
	HumanoidRigType = enumOf({ "R15", "R6" }),
}

-- Signaux -------------------------------------------------------------------------
function newSignal()
	local s = { _c = {} }
	function s:Connect(fn)
		local c = { fn = fn, on = true }
		table.insert(self._c, c)
		return {
			Disconnect = function()
				c.on = false
			end,
		}
	end
	function s:Fire(...)
		for _, c in table.clone(self._c) do
			if c.on then
				c.fn(...)
			end
		end
	end
	return s
end

-- Instances -----------------------------------------------------------------------
ALL = {}
local PARENTS = {
	Part = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	Weld = "JointInstance",
	Motor6D = "JointInstance",
	HingeConstraint = "Constraint",
}
local I = {}
local methods = {}
I.__index = function(self, k)
	local m = methods[k]
	if m then
		return m
	end
	if k == "Position" then
		local c = rawget(self, "CFrame")
		return c and c.Position
	end
	return nil
end
function newInst(class, name, parent)
	local o = setmetatable({ ClassName = class, Name = name or class, _attrs = {}, _tags = {} }, I)
	o.Parent = parent
	table.insert(ALL, o)
	if class == "Part" then
		o.CFrame = CFrame.new(0, 0, 0)
		o.Size = vec(1, 1, 1)
		o.Anchored = true
		o.CanCollide = true
		o.Massless = false
		o.AssemblyLinearVelocity = Vector3.zero
		o.AssemblyAngularVelocity = Vector3.zero
	elseif class == "WeldConstraint" or class == "Weld" then
		o.Enabled = true
	elseif class == "ProximityPrompt" then
		o.Triggered = newSignal()
		o.MaxActivationDistance = 10
		o.HoldDuration = 0
	end
	return o
end
function methods.IsA(self, c)
	local k = self.ClassName
	while k do
		if k == c then
			return true
		end
		k = PARENTS[k]
	end
	return c == "Instance"
end
function methods.GetChildren(self)
	local r = {}
	for _, o in ALL do
		if rawget(o, "Parent") == self then
			table.insert(r, o)
		end
	end
	return r
end
function methods.GetDescendants(self)
	local r = {}
	for _, c in self:GetChildren() do
		table.insert(r, c)
		for _, d in c:GetDescendants() do
			table.insert(r, d)
		end
	end
	return r
end
function methods.FindFirstChild(self, name, recursive)
	for _, c in self:GetChildren() do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, d in self:GetDescendants() do
			if d.Name == name then
				return d
			end
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, class)
	for _, c in self:GetChildren() do
		if c.ClassName == class then
			return c
		end
	end
	return nil
end
function methods.IsDescendantOf(self, a)
	local p = rawget(self, "Parent")
	while p do
		if p == a then
			return true
		end
		p = rawget(p, "Parent")
	end
	return false
end
function methods.GetFullName(self)
	local p = rawget(self, "Parent")
	if p == nil or p == game then
		return self.Name
	end
	return p:GetFullName() .. "." .. self.Name
end
function methods.GetAttribute(self, k)
	return self._attrs[k]
end
function methods.SetAttribute(self, k, v)
	self._attrs[k] = v
end
function methods.Destroy(self)
	self.Parent = nil
	self._destroyed = true
end
function methods.GetJoints(self)
	local r = {}
	for _, o in ALL do
		if
			(o.ClassName == "WeldConstraint" or o.ClassName == "Weld")
			and rawget(o, "Parent") ~= nil
			and (o.Part0 == self or o.Part1 == self)
		then
			table.insert(r, o)
		end
	end
	return r
end
-- a65 : boîte englobante (pièces alignées sur les axes), pour la zone d'entrée de TrainingService.
function methods.GetBoundingBox(self)
	local lo, hi
	for _, p in self:GetDescendants() do
		if p.ClassName == "Part" then
			local a, b = p.CFrame.Position - p.Size / 2, p.CFrame.Position + p.Size / 2
			lo = if lo then vec(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
			hi = if hi then vec(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
		end
	end
	return cf((lo + hi) / 2), hi - lo
end
function methods.PivotTo(self, c)
	local root = self:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = c
	end
end

Instance = {
	new = function(class)
		return newInst(class)
	end,
}

-- Services ------------------------------------------------------------------------
game = newInst("DataModel", "game")
workspace = newInst("Workspace", "Workspace", game)

local tagAdded, tagRemoved = {}, {}
local function tagSignal(t, tag)
	t[tag] = t[tag] or newSignal()
	return t[tag]
end
CollectionService = {
	GetInstanceAddedSignal = function(_, tag)
		return tagSignal(tagAdded, tag)
	end,
	GetInstanceRemovedSignal = function(_, tag)
		return tagSignal(tagRemoved, tag)
	end,
	GetTagged = function(_, tag)
		local r = {}
		for _, o in ALL do
			if o._tags[tag] then
				table.insert(r, o)
			end
		end
		return r
	end,
	HasTag = function(_, o, tag)
		return o._tags[tag] == true
	end,
	AddTag = function(_, o, tag)
		o._tags[tag] = true
		tagSignal(tagAdded, tag):Fire(o)
	end,
	RemoveTag = function(_, o, tag)
		o._tags[tag] = nil
		tagSignal(tagRemoved, tag):Fire(o)
	end,
}
PLAYERS = {}
Players = newInst("Players", "Players", game)
Players.PlayerRemoving = newSignal()
Players.GetPlayers = function(_)
	local r = {}
	for _, p in PLAYERS do
		if p.Parent == Players then
			table.insert(r, p)
		end
	end
	return r
end
HEARTBEAT = newSignal()
RunService = {
	Heartbeat = HEARTBEAT,
	IsStudio = function()
		return true
	end,
}
ReplicatedStorage = newInst("ReplicatedStorage", "ReplicatedStorage", game)
local SERVICES = {
	CollectionService = CollectionService,
	Players = Players,
	RunService = RunService,
	ReplicatedStorage = ReplicatedStorage,
}
game.GetService = function(_, n)
	return assert(SERVICES[n], n)
end

-- Bouchons des modules ------------------------------------------------------------
STRENGTH, SPEED, NOTIFIES, SPEEDMOD = {}, {}, {}, {}
BENCH_LEVEL = 0
TAP = newSignal()
local stubs = {
	Formulas = {
		MachineMultiplier = function(_kind, level)
			return 1 + 0.5 * level
		end,
	},
	Upgrades = { ById = { Bench = { DisplayName = "Bench" }, Treadmill = { DisplayName = "Treadmill" } } },
	Net = {
		Server = {
			TrainTap = TAP,
			TrainLeave = newSignal(), -- a115 (ajout)
			Notify = {
				Fire = function(_, p, msg)
					table.insert(NOTIFIES, { p, msg })
				end,
			},
		},
	},
	AntiCheatService = { Allow = function() end },
	DataService = {
		Get = function(_p)
			return { Upgrades = { Treadmill = 0, Bench = BENCH_LEVEL } }
		end,
		IsLoaded = function()
			return true
		end,
		OnProfileLoaded = function(_fn) end,
		OnProfileReleasing = function(_fn) end,
	},
	StatsService = {
		SetSpeedModifier = function(p, _key, v)
			SPEEDMOD[p] = v
		end,
		AddSpeed = function(p, n)
			SPEED[p] = (SPEED[p] or 0) + n
			return SPEED[p]
		end,
		AddStrength = function(p, n)
			STRENGTH[p] = (STRENGTH[p] or 0) + n
			return STRENGTH[p]
		end,
	},
}

-- Arbre des modules : vrais (SOURCES) ou bouchons.
local function module(name, parent, key, value)
	local m = newInst("ModuleScript", name, parent)
	m._key = key
	m._value = value
	return m
end
local shared = newInst("Folder", "Shared", ReplicatedStorage)
local config = newInst("Folder", "Config", shared)
local netFolder = newInst("Folder", "Net", shared)
module("TrainingZone", shared, "shared/TrainingZone.luau") -- a115 (ajout)
local server = newInst("Folder", "Services", game)
module("Training", config, "shared/Config/Training.luau")
module("DeepFreeze", config, "shared/Config/DeepFreeze.luau")
module("Formulas", config, nil, stubs.Formulas)
module("Upgrades", config, nil, stubs.Upgrades)
module("Net", netFolder, nil, stubs.Net)
module("RateLimiter", netFolder, "shared/Net/RateLimiter.luau")
module("AntiCheatService", server, nil, stubs.AntiCheatService)
module("DataService", server, nil, stubs.DataService)
module("StatsService", server, nil, stubs.StatsService)
local trainingScript = module("TrainingService", server, "server/Services/TrainingService.luau")

-- Accès par point aux enfants (ReplicatedStorage.Shared.Config.Training, script.Parent.X) :
-- __index des instances cherche aussi un enfant de ce nom.
local baseIndex = I.__index
I.__index = function(self, k)
	local v = baseIndex(self, k)
	if v ~= nil then
		return v
	end
	if type(k) == "string" and string.sub(k, 1, 1) ~= "_" then
		for _, o in ALL do
			if rawget(o, "Parent") == self and rawget(o, "Name") == k then
				return o
			end
		end
	end
	return nil
end

local cache = {}
function requireModule(m)
	if cache[m] ~= nil then
		return cache[m]
	end
	if m._value ~= nil then
		cache[m] = m._value
		return m._value
	end
	local fn = assert(loadstring(assert(SOURCES[m._key], m._key), m._key))
	local env = setmetatable({
		script = m,
		require = requireModule,
		game = game,
		workspace = workspace,
		Instance = Instance,
		Vector3 = Vector3,
		CFrame = CFrame,
		Enum = Enum,
		os = {
			clock = function()
				return NOW
			end,
		},
		print = function(...)
			local t = table.concat({ ... }, " ")
			table.insert(LOGS, t)
			if VERBOSE then
				print(t)
			end
		end,
		warn = function(...)
			local t = table.concat({ ... }, " ")
			table.insert(LOGS, "WARN " .. t)
			if VERBOSE then
				print("WARN", t)
			end
		end,
	}, { __index = getfenv(1) })
	setfenv(fn, env)
	local v = fn()
	cache[m] = v
	return v
end
TrainingService = requireModule(trainingScript)

-- Monde ---------------------------------------------------------------------------
NEXT_ID = 1
function newPlayer(name)
	local p = newInst("Player", name, Players)
	p.UserId = NEXT_ID
	NEXT_ID += 1
	p.CharacterRemoving = newSignal()
	local ch = newInst("Model", name, workspace)
	local hum = newInst("Humanoid", "Humanoid", ch)
	local root = newInst("Part", "HumanoidRootPart", ch)
	root.Size = vec(2, 2, 1)
	root.CFrame = CFrame.new(0, 3, 0)
	local hand = newInst("Part", "RightHand", ch)
	hand.Anchored = false
	hand.CFrame = CFrame.new(1, 3, 0)
	hum.Health = 100
	hum.RootPart = root
	hum.HipHeight = 2
	hum.RigType = Enum.HumanoidRigType.R15
	hum.AutoRotate = true
	hum.StateChanged = newSignal()
	hum.Died = newSignal()
	p.Character = ch
	table.insert(PLAYERS, p)
	return p, ch, hum, root, hand
end

-- Banc sur une parcelle possédée par `owner`. barKind : "part", "model" ou nil (sans barre).
function newBench(owner, barKind, origin)
	origin = origin or vec(20, 0, 0)
	local plot = newInst("Model", "Plot", workspace)
	plot._tags.PlayerPlot = true
	plot:SetAttribute("OwnerUserId", owner.UserId)
	local bench = newInst("Model", "PLOT_Bench", plot)
	local frame = newInst("Part", "Frame", bench)
	frame.CFrame = CFrame.new(origin)
	local up = newInst("Attachment", "UsePoint", frame)
	up.WorldCFrame = CFrame.new(origin)
	up.WorldPosition = origin
	local bar, parts = nil, {}
	if barKind == "part" then
		bar = newInst("Part", "Bar", bench)
		bar.CFrame = CFrame.new(origin + vec(0, 4, 0))
		bar.Size = vec(6, 0.3, 0.3)
		parts = { bar }
	elseif barKind == "model" then
		bar = newInst("Model", "Bar", bench)
		local rod = newInst("Part", "Rod", bar)
		rod.CFrame = CFrame.new(origin + vec(0, 4, 0))
		local plate = newInst("Part", "Plate", bar)
		plate.CFrame = CFrame.new(origin + vec(3, 4, 0))
		plate.CanCollide = false
		plate.Anchored = false
		local inner = newInst("WeldConstraint", "Inner", plate)
		inner.Part0 = rod
		inner.Part1 = plate
		local toBench = newInst("WeldConstraint", "ToBench", rod)
		toBench.Part0 = frame
		toBench.Part1 = rod
		parts = { rod, plate }
		bench._inner = inner
		bench._toBench = toBench
	end
	CollectionService:AddTag(bench, "Bench")
	return bench, up, bar, parts, plot
end

function step(seconds, dt)
	dt = dt or 0.25
	local n = math.floor(seconds / dt + 0.5)
	for _ = 1, n do
		NOW += dt
		HEARTBEAT:Fire(dt)
	end
end

function promptOf(up)
	return up:FindFirstChild("TrainingPrompt")
end

-- Vérifications -------------------------------------------------------------------
CHECKS, FAILS = 0, 0
function check(label, cond, detail)
	CHECKS += 1
	if cond then
		if VERBOSE then
			print("ok    " .. label)
		end
	else
		FAILS += 1
		print("ÉCHEC " .. label .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end
function near(a, b)
	return math.abs(a - b) < 1e-6
end
function hasLog(pattern)
	for _, l in LOGS do
		if string.find(l, pattern, 1, true) then
			return true
		end
	end
	return false
end
function barWelds(part)
	local r = {}
	for _, o in ALL do
		if o.ClassName == "WeldConstraint" and o.Name == "TrainingBarWeld" and o.Parent ~= nil and o.Part1 == part then
			table.insert(r, o)
		end
	end
	return r
end

TrainingService.Init()

-- a65 (L-093) : plus d'invite ; le joueur entre dans la zone du banc et y monte tout seul (START_DWELL).
function sit(p, up)
	p.Character:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(up.WorldPosition + Vector3.new(0, 3, 1))
	step(0.5)
end
-- a65 : descendre (l'invite « Stop » n'existe plus) : un service le fait descendre.
function getOff(p)
	TrainingService.Stop(p)
end
