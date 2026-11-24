-- Faux Roblox minimal pour TreadmillFxController (banc a82, vague 26, 2026-11-11). Vector3 et CFrame
-- repris du banc a72 (bar/harness.luau), plus : Color3, NumberSequence, Random, task.defer, instances à
-- propriétés comptées (WRITES), Clone/Destroy, DescendantAdded, attributs et leurs signaux, Players
-- (LocalPlayer, PlayerAdded…), CollectionService (retrait du tag à la sortie de Workspace), caméra,
-- require de vrais ModuleScripts de Shared/Config (SOURCES).

CHECKS, FAILS = 0, 0
function check(label, cond, detail)
	CHECKS += 1
	if cond then
		if VERBOSE then print("ok    " .. label) end
	else
		FAILS += 1
		print("ÉCHEC " .. label .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end

-- Vector3 ---------------------------------------------------------------------------------------
local V = {}
local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V)
end
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Dot" then
		return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
	elseif k == "Cross" then
		return function(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	end
	return nil
end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	return vec(a.X * b, a.Y * b, a.Z * b)
end
V.__div = function(a, b) return vec(a.X / b, a.Y / b, a.Z / b) end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V.__tostring = function(v) return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z) end
Vector3 = { new = function(x, y, z) return vec(x or 0, y or 0, z or 0) end, zero = vec(0, 0, 0), xAxis = vec(1, 0, 0), yAxis = vec(0, 1, 0), zAxis = vec(0, 0, 1) }

-- CFrame ----------------------------------------------------------------------------------------
local C = {}
local function cfr(p, rx, ry, rz)
	return setmetatable({ _p = p, _x = rx, _y = ry, _z = rz }, C)
end
local function rot(c, v) return c._x * v.X + c._y * v.Y + c._z * v.Z end
local function invRot(c, v) return vec(c._x:Dot(v), c._y:Dot(v), c._z:Dot(v)) end
local function mul(a, b) return cfr(a._p + rot(a, b._p), rot(a, b._x), rot(a, b._y), rot(a, b._z)) end
local function inverse(c)
	local x, y, z = invRot(c, Vector3.xAxis), invRot(c, Vector3.yAxis), invRot(c, Vector3.zAxis)
	local inv = cfr(vec(0, 0, 0), x, y, z)
	return cfr(-rot(inv, c._p), x, y, z)
end
C.__index = function(c, k)
	if k == "Position" then return c._p
	elseif k == "Rotation" then return cfr(vec(0, 0, 0), c._x, c._y, c._z)
	elseif k == "LookVector" then return -c._z
	elseif k == "ToObjectSpace" then return function(a, b) return mul(inverse(a), b) end
	elseif k == "Inverse" then return inverse
	end
	return nil
end
C.__mul = function(a, b)
	if getmetatable(b) == V then return a._p + rot(a, b) end
	return mul(a, b)
end
C.__eq = function(a, b) return a._p == b._p and a._x == b._x and a._y == b._y and a._z == b._z end
C.__tostring = function(c) return "CFrame" .. tostring(c._p) end
local function axisAngle(axis, angle)
	local u = axis.Unit
	local co, s = math.cos(angle), math.sin(angle)
	local function r(v) return v * co + u:Cross(v) * s + u * (u:Dot(v) * (1 - co)) end
	return cfr(vec(0, 0, 0), r(Vector3.xAxis), r(Vector3.yAxis), r(Vector3.zAxis))
end
CFrame = {
	new = function(x, y, z)
		local p = if type(x) == "number" then vec(x, y, z) else (x or vec(0, 0, 0))
		return cfr(p, vec(1, 0, 0), vec(0, 1, 0), vec(0, 0, 1))
	end,
	fromAxisAngle = axisAngle,
	Angles = function(x, y, z) -- Roblox : Rx * Ry * Rz
		return mul(mul(axisAngle(Vector3.xAxis, x), axisAngle(Vector3.yAxis, y)), axisAngle(Vector3.zAxis, z))
	end,
}
function nearV(a, b, eps) return (a - b).Magnitude <= (eps or 1e-3) end
function nearCF(a, b, eps)
	eps = eps or 1e-3
	return nearV(a._p, b._p, eps) and nearV(a._x, b._x, eps) and nearV(a._y, b._y, eps) and nearV(a._z, b._z, eps)
end

-- Color3, NumberSequence, Random --------------------------------------------------------------------
local K = {}
local function col(r, g, b) return setmetatable({ R = r, G = g, B = b }, K) end
K.__index = { Lerp = function(a, b, t) return col(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end }
K.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
K.__tostring = function(c) return string.format("rgb(%.3f, %.3f, %.3f)", c.R, c.G, c.B) end
Color3 = {
	new = function(r, g, b) return col(r or 0, g or 0, b or 0) end,
	fromHex = function(h)
		return col(tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255)
	end,
}
function nearC(a, b, eps)
	eps = eps or 1e-3
	return math.abs(a.R - b.R) <= eps and math.abs(a.G - b.G) <= eps and math.abs(a.B - b.B) <= eps
end
NumberSequence = { new = function(v) return { Value = v } end }
Random = {
	new = function()
		return {
			NextNumber = function(_, a, b) return a + (b - a) * math.random() end,
			NextInteger = function(_, a, b) return math.random(a, b) end,
		}
	end,
}

-- task.defer : file vidée par flush() -----------------------------------------------------------------
local DEFERRED = {}
task = { defer = function(f, ...) table.insert(DEFERRED, { f, { ... } }) end }
function flush()
	while #DEFERRED > 0 do
		local item = table.remove(DEFERRED, 1)
		item[1](table.unpack(item[2]))
	end
end

-- Signaux ---------------------------------------------------------------------------------------
function newSignal()
	local s = { _f = {} }
	function s:Connect(f)
		local entry = { f = f }
		table.insert(self._f, entry)
		return { Disconnect = function() entry.f = nil end }
	end
	function s:Fire(...)
		for _, e in table.clone(self._f) do
			if e.f then e.f(...) end
		end
	end
	return s
end

-- Instances : propriétés dans _p, chaque écriture comptée dans WRITES ---------------------------------
WRITES = 0
local CLASS_PARENTS = {
	Part = "BasePart", MeshPart = "BasePart", PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light",
}
local DEFAULTS = {
	Part = function() return { CFrame = CFrame.new(), Color = col(0.6, 0.6, 0.6), Transparency = 0 } end,
	MeshPart = function() return { CFrame = CFrame.new(), Color = col(0.6, 0.6, 0.6), Transparency = 0 } end,
	Texture = function() return { OffsetStudsV = 0, StudsPerTileV = 1.7 } end,
	ParticleEmitter = function() return { Enabled = true, Rate = 0 } end,
	PointLight = function() return { Brightness = 1, Enabled = true } end,
	SpotLight = function() return { Brightness = 1, Enabled = true } end,
	Beam = function() return { Transparency = { Value = 0.3 }, TextureSpeed = 1 } end,
	Trail = function() return { Enabled = false } end,
	Attachment = function() return { Position = vec(0, 0, 0) } end,
}
local I = {}
local function isDescendantOf(self, other)
	local p = rawget(self, "_parent")
	while p do
		if p == other then return true end
		p = rawget(p, "_parent")
	end
	return false
end
function I.IsA(self, c)
	return self.ClassName == c or CLASS_PARENTS[self.ClassName] == c or c == "Instance"
end
function I.FindFirstChild(self, name)
	for _, c in self._children do
		if c.Name == name then return c end
	end
	return nil
end
I.WaitForChild = function(self, name) return assert(I.FindFirstChild(self, name), "WaitForChild " .. name) end
function I.FindFirstChildWhichIsA(self, class)
	for _, c in self._children do
		if c:IsA(class) then return c end
	end
	return nil
end
function I.GetChildren(self) return table.clone(self._children) end
I.IsDescendantOf = isDescendantOf
function I.GetAttribute(self, k) return self._attrs[k] end
function I.SetAttribute(self, k, v)
	if self._attrs[k] == v then return end
	self._attrs[k] = v
	local s = self._attrSignals[k]
	if s then s:Fire() end
end
function I.GetAttributeChangedSignal(self, k)
	self._attrSignals[k] = self._attrSignals[k] or newSignal()
	return self._attrSignals[k]
end
function I.GetPivot(self) return self._p.Pivot or CFrame.new() end
function I.Emit(self, n) self._emits += n end
function I.Destroy(self)
	self.Parent = nil
	self._destroyed = true
end
function I.Clone(self)
	local o = newInst(self.ClassName, self.Name)
	for k, v in self._p do rawset(o._p, k, v) end
	for k, v in self._attrs do o._attrs[k] = v end
	for _, c in self._children do
		local cc = c:Clone()
		cc.Parent = o
	end
	return o
end

local TAGGED = {} -- inst -> { tag = true }
local onLeaveWorkspace -- défini avec CollectionService

local function setParent(self, parent)
	local old = rawget(self, "_parent")
	if old == parent then return end
	local wasIn = old ~= nil and (old == workspace or isDescendantOf(old, workspace))
	if old then
		local list = old._children
		for i, c in list do if c == self then table.remove(list, i) break end end
	end
	rawset(self, "_parent", parent)
	if parent then
		table.insert(parent._children, self)
		local a = parent
		while a do
			if a._descAdded then a._descAdded:Fire(self) end
			a = rawget(a, "_parent")
		end
	end
	local isIn = parent ~= nil and (parent == workspace or isDescendantOf(parent, workspace))
	if wasIn and not isIn then onLeaveWorkspace(self) end
end

local META = {
	__index = function(self, k)
		if k == "Parent" then return rawget(self, "_parent") end
		if k == "DescendantAdded" then
			local s = rawget(self, "_descAdded")
			if not s then
				s = newSignal()
				rawset(self, "_descAdded", s)
			end
			return s
		end
		if k == "Position" and self._p.CFrame then return self._p.CFrame.Position end
		local v = self._p[k]
		if v ~= nil then return v end
		if I[k] ~= nil then return I[k] end
		return I.FindFirstChild(self, k)
	end,
	__newindex = function(self, k, v)
		if k == "Parent" then return setParent(self, v) end
		WRITES += 1
		self._p[k] = v
	end,
}
function newInst(class, name, parent)
	local o = setmetatable({
		ClassName = class, Name = name, _children = {}, _attrs = {}, _attrSignals = {}, _emits = 0,
		_p = if DEFAULTS[class] then DEFAULTS[class]() else {},
	}, META)
	if parent then o.Parent = parent end
	return o
end
-- Pose une propriété sans la compter (mise en place des scènes).
function setp(inst, k, v) inst._p[k] = v end

workspace = newInst("Workspace", "Workspace")
workspace._p.CurrentCamera = { CFrame = CFrame.new(0, 10, 0) }

-- Services ------------------------------------------------------------------------------------
local PLAYERS = {}
Players = {
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
	GetPlayers = function()
		local out = {}
		for _, p in PLAYERS do table.insert(out, p) end
		return out
	end,
}
function newPlayer(userId)
	local player = newInst("Player", "Player" .. userId)
	player._p.UserId = userId
	local character = newInst("Model", "Char" .. userId, workspace)
	newInst("Part", "HumanoidRootPart", character)
	player._p.Character = character
	table.insert(PLAYERS, player)
	Players.PlayerAdded:Fire(player)
	return player
end
Players.LocalPlayer = newPlayer(1)

local ADDED, REMOVED = {}, {}
local function tagSignal(t, tag)
	t[tag] = t[tag] or newSignal()
	return t[tag]
end
CollectionService = {
	GetTagged = function(_, tag)
		local out = {}
		for inst, tags in TAGGED do
			if tags[tag] and (inst == workspace or isDescendantOf(inst, workspace)) then table.insert(out, inst) end
		end
		return out
	end,
	GetInstanceAddedSignal = function(_, tag) return tagSignal(ADDED, tag) end,
	GetInstanceRemovedSignal = function(_, tag) return tagSignal(REMOVED, tag) end,
	AddTag = function(_, inst, tag)
		TAGGED[inst] = TAGGED[inst] or {}
		TAGGED[inst][tag] = true
		tagSignal(ADDED, tag):Fire(inst)
	end,
}
onLeaveWorkspace = function(inst)
	local tags = TAGGED[inst]
	if tags then
		for tag in tags do tagSignal(REMOVED, tag):Fire(inst) end
	end
end
HEARTBEAT = newSignal()
RunService = { Heartbeat = HEARTBEAT }

-- ReplicatedStorage/Shared/Config : vrais modules (SOURCES[chemin] = source), require par loadstring.
ReplicatedStorage = newInst("ReplicatedStorage", "ReplicatedStorage")
local shared = newInst("Folder", "Shared", ReplicatedStorage)
local config = newInst("Folder", "Config", shared)
local LOADED = {}
function require(module)
	if LOADED[module] == nil then
		local fn = assert(loadstring(assert(module._source, "pas de source : " .. module.Name), module.Name))
		setfenv(fn, setmetatable({ script = module }, { __index = getfenv(1) }))
		LOADED[module] = fn()
	end
	return LOADED[module]
end
for _, name in { "DeepFreeze", "Music", "Settings", "TreadmillFX" } do
	local m = newInst("ModuleScript", name, config)
	m._source = SOURCES["shared/Config/" .. name .. ".luau"]
end

local SERVICES = {
	Players = Players, CollectionService = CollectionService, RunService = RunService,
	ReplicatedStorage = ReplicatedStorage, Workspace = workspace,
}
game = { GetService = function(_, name) return assert(SERVICES[name], name) end }

function loadController(source)
	local fn = assert(loadstring(source, "TreadmillFxController"))
	setfenv(fn, setmetatable({}, { __index = getfenv(1) }))
	return fn()
end

-- Avance de dt secondes en n images (tâches différées vidées avant chaque image).
function tick(dt, n)
	n = n or 1
	for _ = 1, n do
		flush()
		HEARTBEAT:Fire(dt)
	end
	flush()
end
Instance = { new = function(class) return newInst(class, class) end }
-- Enum : seulement ce que lisent les modules de Config chargés (Settings.Motion).
Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
