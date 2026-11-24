-- Faux Roblox minimal pour BenchBarController (banc a72, vague 24, 2026-11-11) : Vector3 et CFrame
-- avec rotations, pièces et modèles, Players, CollectionService, RunService.Heartbeat.

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

-- Vector3 -------------------------------------------------------------------------------------
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

-- CFrame : position p et rotation en colonnes (rx, ry, rz = axes locaux dans le monde) --------------
local C = {}
local function cfr(p, rx, ry, rz)
	return setmetatable({ _p = p, _x = rx, _y = ry, _z = rz }, C)
end
local function rot(c, v) -- R * v
	return c._x * v.X + c._y * v.Y + c._z * v.Z
end
local function invRot(c, v) -- Rᵀ * v
	return vec(c._x:Dot(v), c._y:Dot(v), c._z:Dot(v))
end
local function mul(a, b)
	return cfr(a._p + rot(a, b._p), rot(a, b._x), rot(a, b._y), rot(a, b._z))
end
local function inverse(c)
	local x, y, z = invRot(c, Vector3.xAxis), invRot(c, Vector3.yAxis), invRot(c, Vector3.zAxis)
	local inv = cfr(vec(0, 0, 0), x, y, z)
	return cfr(-rot(inv, c._p), x, y, z)
end
C.__index = function(c, k)
	if k == "Position" then return c._p
	elseif k == "Rotation" then return cfr(vec(0, 0, 0), c._x, c._y, c._z)
	elseif k == "RightVector" then return c._x
	elseif k == "UpVector" then return c._y
	elseif k == "ToObjectSpace" then return function(a, b) return mul(inverse(a), b) end
	elseif k == "VectorToWorldSpace" then return function(a, v) return rot(a, v) end
	elseif k == "PointToObjectSpace" then return function(a, v) return invRot(a, v - a._p) end
	elseif k == "Inverse" then return inverse
	end
	return nil
end
C.__mul = function(a, b)
	if getmetatable(b) == V then
		return a._p + rot(a, b)
	end
	return mul(a, b)
end
C.__eq = function(a, b) return a._p == b._p and a._x == b._x and a._y == b._y and a._z == b._z end
C.__tostring = function(c) return "CFrame" .. tostring(c._p) end
CFrame = {
	new = function(x, y, z)
		local p = if type(x) == "number" then vec(x, y, z) else (x or vec(0, 0, 0))
		return cfr(p, vec(1, 0, 0), vec(0, 1, 0), vec(0, 0, 1))
	end,
	fromAxisAngle = function(axis, angle)
		local u = axis.Unit
		local c, s = math.cos(angle), math.sin(angle)
		local function r(v) -- Rodrigues
			return v * c + u:Cross(v) * s + u * (u:Dot(v) * (1 - c))
		end
		return cfr(vec(0, 0, 0), r(Vector3.xAxis), r(Vector3.yAxis), r(Vector3.zAxis))
	end,
}
CFrame.identity = CFrame.new()

function nearV(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-3)
end

-- Signaux et instances --------------------------------------------------------------------------
function newSignal()
	local s = { _f = {} }
	function s:Connect(f)
		table.insert(self._f, f)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, f in self._f do f(...) end
	end
	return s
end

local I = {}
I.__index = function(self, k)
	if k == "Position" and rawget(self, "CFrame") then
		return rawget(self, "CFrame").Position
	end
	return I[k]
end
function newInst(class, name, parent)
	local o = setmetatable({ ClassName = class, Name = name, _children = {}, _attrs = {} }, I)
	if class == "Part" then
		o.CFrame = CFrame.new()
		o.Size = vec(1, 1, 1)
		o.CanCollide = true
		o.Anchored = true
	end
	if parent then o:SetParent(parent) end
	return o
end
function I.SetParent(self, parent)
	if rawget(self, "Parent") then
		local list = rawget(self, "Parent")._children
		for i, c in list do if c == self then table.remove(list, i) break end end
	end
	rawset(self, "Parent", parent)
	if parent then table.insert(parent._children, self) end
end
function I.IsA(self, c)
	if c == "BasePart" then return self.ClassName == "Part" end
	return self.ClassName == c
end
function I.FindFirstChild(self, name, recursive)
	for _, c in self._children do
		if c.Name == name then return c end
	end
	if recursive then
		for _, c in self._children do
			local f = c:FindFirstChild(name, true)
			if f then return f end
		end
	end
	return nil
end
function I.GetDescendants(self)
	local out = {}
	for _, c in self._children do
		table.insert(out, c)
		for _, d in c:GetDescendants() do table.insert(out, d) end
	end
	return out
end
function I.GetAttribute(self, k) return self._attrs[k] end
function I.SetAttribute(self, k, v) self._attrs[k] = v end
function I.GetBoundingBox(self)
	local lo, hi = vec(math.huge, math.huge, math.huge), vec(-math.huge, -math.huge, -math.huge)
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			local p, h = d.CFrame.Position, d.Size / 2
			lo = vec(math.min(lo.X, p.X - h.X), math.min(lo.Y, p.Y - h.Y), math.min(lo.Z, p.Z - h.Z))
			hi = vec(math.max(hi.X, p.X + h.X), math.max(hi.Y, p.Y + h.Y), math.max(hi.Z, p.Z + h.Z))
		end
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end

workspace = newInst("Workspace", "Workspace")
-- Ajout a77 (vague 25, 2026-11-11) : Workspace:BulkMoveTo et Enum.BulkMoveMode (BenchBarController
-- déplace toute l'haltère d'un coup). BULK_MOVES compte les appels.
BULK_MOVES = 0
function I.BulkMoveTo(self, parts, cframes, _mode)
	BULK_MOVES += 1
	for i, p in parts do p.CFrame = cframes[i] end
end
Enum = Enum or { BulkMoveMode = { FireCFrameChanged = "FireCFrameChanged", FireAllEvents = "FireAllEvents" } }

-- Services ------------------------------------------------------------------------------------
local PLAYERS = {}
Players = {
	GetPlayerByUserId = function(_, id) return PLAYERS[id] end,
}
local TAGS, ADDED, REMOVED = {}, {}, {}
local function tagSignal(t, tag)
	t[tag] = t[tag] or newSignal()
	return t[tag]
end
CollectionService = {
	GetTagged = function(_, tag)
		local out = {}
		for inst in TAGS[tag] or {} do table.insert(out, inst) end
		return out
	end,
	GetInstanceAddedSignal = function(_, tag) return tagSignal(ADDED, tag) end,
	GetInstanceRemovedSignal = function(_, tag) return tagSignal(REMOVED, tag) end,
	AddTag = function(_, inst, tag)
		TAGS[tag] = TAGS[tag] or {}
		TAGS[tag][inst] = true
		tagSignal(ADDED, tag):Fire(inst)
	end,
	RemoveTag = function(_, inst, tag)
		if TAGS[tag] then TAGS[tag][inst] = nil end
		tagSignal(REMOVED, tag):Fire(inst)
	end,
}
HEARTBEAT = newSignal()
RunService = { Heartbeat = HEARTBEAT }
local SERVICES = { Players = Players, CollectionService = CollectionService, RunService = RunService }
game = { GetService = function(_, name) return assert(SERVICES[name], name) end }

function newPlayer(userId, left, right)
	local character = newInst("Model", "Char" .. userId, workspace)
	local l, r
	if left then
		l = newInst("Part", "LeftHand", character)
		l.CFrame = CFrame.new(left)
	end
	if right then
		r = newInst("Part", "RightHand", character)
		r.CFrame = CFrame.new(right)
	end
	local player = { UserId = userId, Character = character }
	PLAYERS[userId] = player
	return player, l, r, character
end

function loadController(source)
	local fn = assert(loadstring(source, "BenchBarController"))
	setfenv(fn, setmetatable({ game = game, Vector3 = Vector3, CFrame = CFrame, workspace = workspace }, { __index = getfenv(1) }))
	return fn()
end
