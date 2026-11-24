-- Faux Roblox autonome du banc a65 (vague 22, L-093) : TrainingService (entrée par zone) et
-- MachineVariantService (variantes du tapis). Repris du faux d'a58, avec en plus : Parent qui
-- déclenche les signaux de tags (entrée et sortie du DataModel), Clone, GetPivot / PivotTo des
-- modèles, GetBoundingBox, attachements qui suivent leur pièce, attributs avec signal.
-- Pas de physique : les déplacements du joueur sont posés à la main.

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
V.__unm = function(a)
	return vec(-a.X, -a.Y, -a.Z)
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
	if k == "Inverse" then
		return function(s)
			return cf(-s.Position)
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
		return cf(vec(x or 0, y or 0, z or 0))
	end,
	lookAt = function(p, _target)
		return cf(p)
	end,
}
CFrame.identity = CFrame.new(0, 0, 0)

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

-- Tags ----------------------------------------------------------------------------
local tagAdded, tagRemoved = {}, {}
local function tagSignal(t, tag)
	t[tag] = t[tag] or newSignal()
	return t[tag]
end

-- Instances -----------------------------------------------------------------------
ALL = {}
local PARENTS = {
	Part = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	Weld = "JointInstance",
	Motor6D = "JointInstance",
}
local I = {}
local methods = {}
game = nil

local function inGame(o)
	local p = o
	while p do
		if p == game then
			return true
		end
		p = rawget(p, "_p")
	end
	return false
end

local function subtree(o)
	local r = { o }
	for _, d in o:GetDescendants() do
		table.insert(r, d)
	end
	return r
end

I.__index = function(self, k)
	local m = methods[k]
	if m then
		return m
	end
	if k == "Parent" then
		return rawget(self, "_p")
	end
	if k == "Position" then
		local c = rawget(self, "CFrame")
		return c and c.Position
	end
	if rawget(self, "ClassName") == "Attachment" and (k == "WorldPosition" or k == "WorldCFrame") then
		local part = rawget(self, "_p")
		local base = if part and rawget(part, "CFrame") then part.CFrame.Position else vec(0, 0, 0)
		local pos = base + rawget(self, "CFrame").Position
		return if k == "WorldPosition" then pos else cf(pos)
	end
	if type(k) == "string" and string.sub(k, 1, 1) ~= "_" then
		for _, o in ALL do
			if rawget(o, "_p") == self and rawget(o, "Name") == k then
				return o
			end
		end
	end
	return nil
end
I.__newindex = function(self, k, v)
	if k == "Parent" then
		local was = inGame(self)
		rawset(self, "_p", v)
		local now = inGame(self)
		if was ~= now then
			for _, o in subtree(self) do
				for tag in o._tags do
					tagSignal(if now then tagAdded else tagRemoved, tag):Fire(o)
				end
			end
		end
		return
	end
	rawset(self, k, v)
end

function newInst(class, name, parent)
	local o = setmetatable({ ClassName = class, Name = name or class, _attrs = {}, _tags = {}, _attrSignals = {} }, I)
	table.insert(ALL, o)
	if class == "Part" then
		o.CFrame = CFrame.new(0, 0, 0)
		o.Size = vec(1, 1, 1)
		o.Anchored = true
		o.CanCollide = true
		o.Massless = false
		o.AssemblyLinearVelocity = Vector3.zero
		o.AssemblyAngularVelocity = Vector3.zero
	elseif class == "Attachment" then
		o.CFrame = CFrame.new(0, 0, 0)
	elseif class == "WeldConstraint" or class == "Weld" then
		o.Enabled = true
	elseif class == "ProximityPrompt" then
		o.Triggered = newSignal()
		o.MaxActivationDistance = 10
		o.HoldDuration = 0
		o.Enabled = true
	end
	o.Parent = parent
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
		if rawget(o, "_p") == self then
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
	local p = rawget(self, "_p")
	while p do
		if p == a then
			return true
		end
		p = rawget(p, "_p")
	end
	return false
end
function methods.GetFullName(self)
	local p = rawget(self, "_p")
	if p == nil or p == game then
		return self.Name
	end
	return p:GetFullName() .. "." .. self.Name
end
function methods.GetAttribute(self, k)
	return self._attrs[k]
end
function methods.GetAttributes(self)
	return table.clone(self._attrs)
end
function methods.SetAttribute(self, k, v)
	local old = self._attrs[k]
	self._attrs[k] = v
	local s = self._attrSignals[k]
	if s and old ~= v then
		s:Fire()
	end
end
function methods.GetAttributeChangedSignal(self, k)
	self._attrSignals[k] = self._attrSignals[k] or newSignal()
	return self._attrSignals[k]
end
function methods.Destroy(self)
	for _, d in self:GetDescendants() do
		rawset(d, "_destroyed", true)
	end
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function methods.GetJoints(self)
	local r = {}
	for _, o in ALL do
		if
			(o.ClassName == "WeldConstraint" or o.ClassName == "Weld")
			and rawget(o, "_p") ~= nil
			and (o.Part0 == self or o.Part1 == self)
		then
			table.insert(r, o)
		end
	end
	return r
end
local function partsOf(self)
	local r = {}
	if self.ClassName == "Part" then
		table.insert(r, self)
	end
	for _, d in self:GetDescendants() do
		if d.ClassName == "Part" then
			table.insert(r, d)
		end
	end
	return r
end
function methods.GetBoundingBox(self)
	local lo, hi
	for _, p in partsOf(self) do
		local a, b = p.CFrame.Position - p.Size / 2, p.CFrame.Position + p.Size / 2
		lo = if lo then vec(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
		hi = if hi then vec(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
	end
	if lo == nil then
		return CFrame.new(0, 0, 0), vec(0, 0, 0)
	end
	return cf((lo + hi) / 2), hi - lo
end
function methods.GetPivot(self)
	local primary = rawget(self, "PrimaryPart")
	if primary then
		return primary.CFrame
	end
	if self.ClassName == "Part" then
		return self.CFrame
	end
	local stored = rawget(self, "_pivot")
	if stored then
		return stored
	end
	return (self:GetBoundingBox())
end
function methods.PivotTo(self, c)
	local delta = c.Position - self:GetPivot().Position
	for _, p in partsOf(self) do
		p.CFrame = cf(p.CFrame.Position + delta)
	end
	if rawget(self, "_pivot") then
		rawset(self, "_pivot", c)
	end
end
local function copyValue(v)
	if type(v) == "table" and getmetatable(v) == V then
		return vec(v.X, v.Y, v.Z)
	elseif type(v) == "table" and getmetatable(v) == C then
		return cf(v.Position)
	end
	return v
end
function methods.Clone(self)
	local o = setmetatable({ _attrs = table.clone(self._attrs), _tags = table.clone(self._tags), _attrSignals = {} }, I)
	for k, v in self do
		if k ~= "_p" and k ~= "_attrs" and k ~= "_tags" and k ~= "_attrSignals" and k ~= "_destroyed" then
			if type(v) == "table" and getmetatable(v) == nil then
				-- signaux et tables internes : neufs
				rawset(o, k, if v.Connect then newSignal() else v)
			else
				rawset(o, k, copyValue(v))
			end
		end
	end
	table.insert(ALL, o)
	for _, child in self:GetChildren() do
		local c = child:Clone()
		rawset(c, "_p", o)
	end
	o._cloneOf = self
	return o
end

Instance = {
	new = function(class)
		return newInst(class)
	end,
}

-- Services ------------------------------------------------------------------------
game = setmetatable({ ClassName = "DataModel", Name = "game", _attrs = {}, _tags = {}, _attrSignals = {} }, I)
table.insert(ALL, game)
workspace = newInst("Workspace", "Workspace", game)

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
			if o._tags[tag] and inGame(o) then
				table.insert(r, o)
			end
		end
		return r
	end,
	HasTag = function(_, o, tag)
		return o._tags[tag] == true
	end,
	AddTag = function(_, o, tag)
		if o._tags[tag] then
			return
		end
		o._tags[tag] = true
		if inGame(o) then
			tagSignal(tagAdded, tag):Fire(o)
		end
	end,
	RemoveTag = function(_, o, tag)
		o._tags[tag] = nil
		if inGame(o) then
			tagSignal(tagRemoved, tag):Fire(o)
		end
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
	Workspace = workspace,
}
rawset(game, "GetService", function(_, n)
	return assert(SERVICES[n], n)
end)

-- Bouchons des modules ------------------------------------------------------------
STRENGTH, SPEED, NOTIFIES, SPEEDMOD = {}, {}, {}, {}
DATA, NOT_LOADED = {}, {}
TAP = newSignal()
LEAVE = newSignal()
PLOTS, OWNER, ASSIGNED, RELEASED = {}, {}, {}, {}
local stubs = {
	Formulas = {
		MachineMultiplier = function(_kind, level)
			return 1 + 0.5 * level
		end,
		-- Copie a134 (ajout pur, rééquilibrage v2) : niveau affiché et gain du tapis, comme Config/Formulas.
		TreadmillShownLevel = function(level)
			return math.clamp(math.floor(level), 0, 19) + 1
		end,
		TreadmillGain = function(level)
			return 2 ^ math.clamp(math.floor(level), 0, 19)
		end,
	},
	Net = {
		Server = {
			TrainTap = TAP,
			TrainLeave = LEAVE,
			Notify = {
				Fire = function(_, p, msg)
					table.insert(NOTIFIES, { p, msg, NOW })
				end,
			},
		},
	},
	AntiCheatService = { Allow = function() end },
	DataService = {
		Get = function(p)
			if NOT_LOADED[p] then
				return nil
			end
			return DATA[p]
		end,
		IsLoaded = function(p)
			return not NOT_LOADED[p]
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
	PlotService = {
		GetPlots = function()
			return table.clone(PLOTS)
		end,
		GetOwner = function(plot)
			return OWNER[plot]
		end,
		GetPlot = function(p)
			for plot, o in OWNER do
				if o == p then
					return plot
				end
			end
			return nil
		end,
		OnPlotAssigned = function(fn)
			table.insert(ASSIGNED, fn)
			for plot, o in OWNER do
				fn(o, plot)
			end
			return function() end
		end,
		OnPlotReleased = function(fn)
			table.insert(RELEASED, fn)
			return function() end
		end,
	},
}

local function module(name, parent, key, value)
	local m = newInst("ModuleScript", name, parent)
	m._key = key
	m._value = value
	return m
end
local shared = newInst("Folder", "Shared", ReplicatedStorage)
local config = newInst("Folder", "Config", shared)
local netFolder = newInst("Folder", "Net", shared)
local server = newInst("Folder", "Services", game)
module("Training", config, "shared/Config/Training.luau")
module("Upgrades", config, "shared/Config/Upgrades.luau")
module("DeepFreeze", config, "shared/Config/DeepFreeze.luau")
module("Formulas", config, nil, stubs.Formulas)
module("Net", netFolder, nil, stubs.Net)
module("TrainingZone", shared, "shared/TrainingZone.luau")
module("RateLimiter", netFolder, "shared/Net/RateLimiter.luau")
module("AntiCheatService", server, nil, stubs.AntiCheatService)
module("DataService", server, nil, stubs.DataService)
module("StatsService", server, nil, stubs.StatsService)
module("PlotService", server, nil, stubs.PlotService)
local trainingScript = module("TrainingService", server, "server/Services/TrainingService.luau")
local variantScript = module("MachineVariantService", server, "server/Services/MachineVariantService.luau")

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
		task = {
			wait = function(t)
				return coroutine.yield(t)
			end,
		},
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
MachineVariantService = requireModule(variantScript)

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
	root.CFrame = CFrame.new(0, 3, -500)
	local hand = newInst("Part", "RightHand", ch)
	hand.Anchored = false
	hand.CFrame = CFrame.new(1, 3, -500)
	ch.PrimaryPart = root
	hum.Health = 100
	hum.RootPart = root
	hum.HipHeight = 2
	hum.RigType = Enum.HumanoidRigType.R15
	hum.AutoRotate = true
	hum.StateChanged = newSignal()
	hum.Died = newSignal()
	p.Character = ch
	DATA[p] = { Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0 } }
	table.insert(PLAYERS, p)
	return p, ch, hum, root, hand
end

local function part(name, parent, size, position)
	local o = newInst("Part", name, parent)
	o.Size = size
	o.CFrame = CFrame.new(position)
	return o
end
local function attach(name, parent, offset)
	local a = newInst("Attachment", name, parent)
	a.CFrame = CFrame.new(offset)
	return a
end

-- Tapis : Frame 4 × 1 × 8 (bas au sol), Belt 3 × 0,2 × 6,5 dessus (UsePoint sur son dessus), console
-- 4 × 4 × 1 à l'avant (−Z). Pivot en bas au centre. beltShift : décalage de la bande (variantes).
-- Boîte : X ±2, Y 0 à 4, Z −5 à 4 autour de l'origine.
function buildTreadmill(parent, origin, opts)
	opts = opts or {}
	local m = newInst("Model", opts.name or "Treadmill", nil)
	m._pivot = CFrame.new(origin)
	local frame = part("Frame", m, vec(4, 1, 8), origin + vec(0, 0.5, 0))
	if not opts.noUpgradePoint then
		attach("UpgradePoint", frame, vec(3, -0.5, 0))
	end
	local shift = opts.beltShift or vec(0, 0, 0)
	local holder = frame
	if not opts.noBelt then
		holder = part("Belt", m, vec(3, 0.2, 6.5), origin + vec(0, 1.1, 0) + shift)
	end
	if not opts.noUsePoint then
		attach("UsePoint", holder, vec(0, holder.Size.Y / 2, 0))
	end
	part("Console", m, vec(4, 4, 1), origin + vec(0, 2, -4.5))
	if opts.useZone then
		local z = part("UseZone", m, opts.useZone.size, origin + opts.useZone.offset)
		z.CanCollide = false
	end
	if opts.prompt then
		local pr = newInst("ProximityPrompt", "OldPrompt", frame)
		pr.ActionText = "Run"
	end
	for k, v in opts.attrs or {} do
		m:SetAttribute(k, v)
	end
	if opts.tag ~= false then
		CollectionService:AddTag(m, "Treadmill")
	end
	m.Parent = parent
	return m
end

-- Banc : GymMat 4 × 0,2 × 6 au sol (UsePoint dessus, invite « Lift » de Clément), Pad, Bar, RackTop.
-- Boîte : X −3 à 3 (la barre fait 6), Y 0 à 5, Z −3 à 3 autour de l'origine.
function buildBench(parent, origin, opts)
	opts = opts or {}
	local m = newInst("Model", "Bench", nil)
	m._pivot = CFrame.new(origin)
	local mat = part("GymMat", m, vec(4, 0.2, 6), origin + vec(0, 0.1, 0))
	attach("UsePoint", mat, vec(0, 0.1, 0))
	if opts.prompt ~= false then
		local pr = newInst("ProximityPrompt", "ProximityPrompt", mat)
		pr.ActionText = "Lift"
		pr.MaxActivationDistance = 10
	end
	part("Pad", m, vec(2, 1, 5), origin + vec(0, 1, 0))
	part("Bar", m, vec(6, 0.3, 0.3), origin + vec(0, 4, 0))
	local rack = part("RackTop", m, vec(1, 1, 1), origin + vec(0, 4.5, -2.5))
	attach("UpgradePoint", rack, vec(0, -4.5, -1))
	CollectionService:AddTag(m, "Bench")
	m.Parent = parent
	return m
end

function newPlot(name, owner, origin)
	local plot = newInst("Model", name, nil)
	plot._tags.PlayerPlot = true
	plot:SetAttribute("OwnerUserId", if owner then owner.UserId else 0)
	plot.Parent = workspace
	table.insert(PLOTS, plot)
	if owner then
		OWNER[plot] = owner
	end
	local t = buildTreadmill(plot, origin, { attrs = { Theme = name } })
	local b = buildBench(plot, origin + vec(20, 0, 0))
	return plot, t, b
end

function assignPlot(p, plot)
	OWNER[plot] = p
	plot:SetAttribute("OwnerUserId", p.UserId)
	for _, fn in table.clone(ASSIGNED) do
		fn(p, plot)
	end
end
function releasePlot(p, plot)
	OWNER[plot] = nil
	plot:SetAttribute("OwnerUserId", 0)
	for _, fn in table.clone(RELEASED) do
		fn(p, plot)
	end
end

function step(seconds, dt)
	dt = dt or 0.05
	local n = math.floor(seconds / dt + 0.5)
	for _ = 1, n do
		NOW += dt
		HEARTBEAT:Fire(dt)
	end
end

function moveTo(p, position, velocity)
	local root = p.Character:FindFirstChild("HumanoidRootPart")
	root.CFrame = CFrame.new(position)
	root.AssemblyLinearVelocity = velocity or Vector3.zero
end
function rootPos(p)
	return p.Character:FindFirstChild("HumanoidRootPart").CFrame.Position
end
function machineOf(p)
	return p:GetAttribute("TrainingMachine")
end
function setState(p, name)
	local hum = p.Character:FindFirstChild("Humanoid")
	hum.StateChanged:Fire(Enum.HumanoidStateType.Running, Enum.HumanoidStateType[name])
end
function notifyCount(p)
	local n = 0
	for _, e in NOTIFIES do
		if e[1] == p then
			n += 1
		end
	end
	return n
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
function logCount(pattern)
	local n = 0
	for _, l in LOGS do
		if string.find(l, pattern, 1, true) then
			n += 1
		end
	end
	return n
end
function hasLog(pattern)
	return logCount(pattern) > 0
end
