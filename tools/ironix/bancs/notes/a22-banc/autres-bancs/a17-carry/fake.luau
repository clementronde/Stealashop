--!nocheck
-- Faux Roblox minimal pour exécuter CarryService et CarryController hors de Studio (DEV-017).
-- Un seul VM, un seul arbre d'instances partagé par le « serveur » et le « client » (réplication
-- parfaite et instantanée), temps simulé. Propriétés permissives : la justesse des noms de
-- propriétés est vérifiée à part, par luau-lsp avec les définitions Roblox.

SOURCES = {}
LOG = {}
FAILS = 0
CHECKS = 0

---------------------------------------------------------------- temps et tâches
local simTime = 0
local queue = {}
local seq = 0
local cancelled = {}
local function schedule(t, co, ...)
	seq += 1
	table.insert(queue, { t = t, seq = seq, co = co, args = table.pack(...) })
end
EXPECTED_ERRORS = 0
QUIET_ERRORS = false -- true : une erreur de tâche est attendue (comptée à part, pas un échec)
local function resume(co, ...)
	if cancelled[co] then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok and QUIET_ERRORS then
		EXPECTED_ERRORS += 1
	elseif not ok then
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
function taskLib.cancel(co)
	cancelled[co] = true
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
function flush()
	advance(0)
end
function now()
	return simTime
end

---------------------------------------------------------------- types de valeurs
local function typed(name)
	return { __type = name }
end

Vector3 = {}
local V3MT = typed("Vector3")
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3MT)
end
V3MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
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
	return v3(a.X / b, a.Y / b, a.Z / b)
end
V3MT.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3MT.__tostring = function(a)
	return string.format("(%.3f, %.3f, %.3f)", a.X, a.Y, a.Z)
end
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)

-- CFrame complet : position + matrice de rotation 3×3 (lignes).
CFrame = {}
local CFMT = typed("CFrame")
local function cf(p, r)
	return setmetatable({ p = p, r = r }, CFMT)
end
local ID = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mulRV(r, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
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
local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
local function inverse(c)
	local rt = transpose(c.r)
	return cf(-mulRV(rt, c.p), rt)
end
CFMT.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "Rotation" then
		return cf(v3(0, 0, 0), c.r)
	elseif k == "LookVector" then
		return v3(-c.r[3], -c.r[6], -c.r[9])
	elseif k == "UpVector" then
		return v3(c.r[2], c.r[5], c.r[8])
	elseif k == "Inverse" then
		return inverse
	elseif k == "ToObjectSpace" then
		return function(self, other)
			return inverse(self) * other
		end
	elseif k == "ToWorldSpace" then
		return function(self, other)
			return self * other
		end
	elseif k == "PointToObjectSpace" then
		return function(self, v)
			return mulRV(transpose(self.r), v - self.p)
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
CFMT.__tostring = function(c)
	return "CFrame" .. tostring(c.p)
end
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return cf(x, ID)
	end
	return cf(v3(x or 0, y or 0, z or 0), ID)
end
function CFrame.Angles(rx, ry, rz)
	local function rotX(a)
		local c, s = math.cos(a), math.sin(a)
		return { 1, 0, 0, 0, c, -s, 0, s, c }
	end
	local function rotY(a)
		local c, s = math.cos(a), math.sin(a)
		return { c, 0, s, 0, 1, 0, -s, 0, c }
	end
	local function rotZ(a)
		local c, s = math.cos(a), math.sin(a)
		return { c, -s, 0, s, c, 0, 0, 0, 1 }
	end
	return cf(v3(0, 0, 0), mulRR(mulRR(rotX(rx or 0), rotY(ry or 0)), rotZ(rz or 0)))
end
CFrame.identity = CFrame.new(0, 0, 0)
function cfClose(a, b, eps)
	eps = eps or 1e-6
	if (a.p - b.p).Magnitude > eps then
		return false
	end
	for i = 1, 9 do
		if math.abs(a.r[i] - b.r[i]) > eps then
			return false
		end
	end
	return true
end

local C3MT = typed("Color3")
C3MT.__index = {
	Lerp = function(a, b, t)
		return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3MT)
	end,
}
C3MT.__eq = function(a, b)
	return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end
C3MT.__tostring = function(c)
	return string.format("RGB(%d, %d, %d)", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end
local function c3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3MT)
end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b)
		return c3(r / 255, g / 255, b / 255)
	end,
	fromHex = function(hex)
		hex = string.gsub(hex, "#", "")
		return c3(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
	end,
}

ColorSequenceKeypoint = {
	new = function(t, color)
		return setmetatable({ Time = t, Value = color }, typed("ColorSequenceKeypoint"))
	end,
}
ColorSequence = {
	new = function(a, b)
		local keypoints
		if type(a) == "table" and getmetatable(a) == C3MT then
			keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) }
		else
			keypoints = a
			assert(#keypoints >= 2, "ColorSequence : au moins 2 points")
			assert(keypoints[1].Time == 0 and keypoints[#keypoints].Time == 1, "ColorSequence : doit aller de 0 à 1")
		end
		return setmetatable({ Keypoints = keypoints }, typed("ColorSequence"))
	end,
}
NumberSequence = {
	new = function(a, b)
		return setmetatable({ Start = a, End = if b == nil then a else b }, typed("NumberSequence"))
	end,
}
NumberRange = {
	new = function(a, b)
		return setmetatable({ Min = a, Max = b or a }, typed("NumberRange"))
	end,
}
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x, Y = y }, typed("Vector2"))
	end,
}
UDim2 = {
	fromScale = function(x, y)
		return setmetatable({ X = x, Y = y }, typed("UDim2"))
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
local SignalMT = typed("RBXScriptSignal")
SignalMT.__index = SignalMT
function newSignal()
	return setmetatable({ handlers = {} }, SignalMT)
end
function SignalMT:Connect(fn)
	local handlers = self.handlers
	local conn = { Connected = true, fn = fn }
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
end
function SignalMT:ConnectionCount()
	return #self.handlers
end

---------------------------------------------------------------- instances
local SUPER = {
	Part = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	Workspace = { "Model", "PVInstance" },
	Script = { "BaseScript", "LuaSourceContainer" },
	LocalScript = { "Script", "BaseScript", "LuaSourceContainer" },
	ModuleScript = { "LuaSourceContainer" },
	PointLight = { "Light" },
	SpotLight = { "Light" },
	TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	BillboardGui = { "LayerCollector", "GuiBase2d" },
	Tool = { "BackpackItem" },
	Weld = { "JointInstance" },
	Folder = {},
}
local DEFAULTS = {
	BasePart = function()
		return {
			Anchored = false,
			CanCollide = true,
			CanQuery = true,
			CanTouch = true,
			Massless = false,
			Transparency = 0,
			Size = v3(4, 1, 2),
			CFrame = CFrame.identity,
			PivotOffset = CFrame.identity,
			Color = c3(0.64, 0.64, 0.64),
		}
	end,
	Attachment = function()
		return { CFrame = CFrame.identity }
	end,
	Model = function()
		return { WorldPivot = CFrame.identity }
	end,
	Humanoid = function()
		return { Health = 100 }
	end,
	GuiObject = function()
		return { Visible = true, Text = "Label", TextColor3 = c3(0, 0, 0) }
	end,
}
local CLASS_EVENTS = {
	ChildAdded = true,
	ChildRemoved = true,
	AncestryChanged = true,
	Died = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	Destroying = true,
}

local Methods = {}
local InstanceMT = { __type = "Instance" }
local tagsOf = {} -- [instance] = { [tag] = true }
DataModel = nil

local function isA(self, class)
	local own = rawget(self, "_class")
	if own == class or class == "Instance" then
		return true
	end
	for _, c in SUPER[own] or {} do
		if c == class then
			return true
		end
	end
	return false
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
	elseif key == "WorldCFrame" and isA(self, "Attachment") then
		local parent = rawget(self, "_parent")
		return parent.CFrame * rawget(self, "_props").CFrame
	end
	local props = rawget(self, "_props")
	local v = props[key]
	if v ~= nil then
		return v
	end
	if CLASS_EVENTS[key] then
		local signals = rawget(self, "_signals")
		signals[key] = signals[key] or newSignal()
		return signals[key]
	end
	for _, child in rawget(self, "_children") do
		if rawget(child, "_props").Name == key then
			return child
		end
	end
	return nil -- permissif : propriété jamais écrite
end

local function inGame(inst)
	local current = inst
	while current do
		if current == DataModel then
			return true
		end
		current = rawget(current, "_parent")
	end
	return false
end

local tagged, addedSignals, removedSignals = {}, {}, {}
local function tagSignal(map, tag)
	map[tag] = map[tag] or newSignal()
	return map[tag]
end

local function subtree(inst)
	local out = { inst }
	for _, d in Methods.GetDescendants(inst) do
		table.insert(out, d)
	end
	return out
end

local function setParent(self, parent)
	if rawget(self, "_destroyed") then
		error(`Parent verrouillé : {rawget(self, "_props").Name} est détruit`, 3)
	end
	if parent and rawget(parent, "_destroyed") then
		error(`Parent verrouillé : {rawget(parent, "_props").Name} est détruit`, 3)
	end
	local old = rawget(self, "_parent")
	if old == parent then
		return
	end
	local wasInGame = inGame(self)
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
	local isInGame = inGame(self)
	for _, d in subtree(self) do
		d.AncestryChanged:Fire(self, parent)
	end
	if old then
		old.ChildRemoved:Fire(self)
	end
	if parent then
		parent.ChildAdded:Fire(self)
	end
	if wasInGame ~= isInGame then
		for _, d in subtree(self) do
			for tag in tagsOf[d] or {} do
				tagSignal(if isInGame then addedSignals else removedSignals, tag):Fire(d)
			end
		end
	end
end

InstanceMT.__newindex = function(self, key, value)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	if rawget(self, "_destroyed") and key ~= "Name" then
		-- Roblox accepte d'écrire une propriété d'un objet détruit ; on le note pour les tests.
		rawset(self, "_writtenAfterDestroy", true)
	end
	if key == "Position" and isA(self, "Attachment") then
		local props = rawget(self, "_props")
		props.CFrame = CFrame.new(value)
		return
	end
	rawget(self, "_props")[key] = value
end
InstanceMT.__tostring = function(self)
	return rawget(self, "_props").Name
end

function newInstance(class)
	local props = { Name = class }
	for base, make in DEFAULTS do
		if class == base or isA({ _class = class }, base) then
			for k, v in make() do
				props[k] = v
			end
		end
	end
	return setmetatable({
		_class = class,
		_props = props,
		_children = {},
		_attrs = {},
		_attrSignals = {},
		_signals = {},
		_parent = nil,
		_destroyed = false,
	}, InstanceMT)
end

function Methods.IsA(self, class)
	return isA(self, class)
end
function Methods.HasTag(self, tag)
	return (tagsOf[self] or {})[tag] == true
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
	local list = if recursive then Methods.GetDescendants(self) else rawget(self, "_children")
	for _, c in list do
		if rawget(c, "_props").Name == name then
			return c
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
function Methods.FindFirstChildWhichIsA(self, class, recursive)
	local list = if recursive then Methods.GetDescendants(self) else rawget(self, "_children")
	for _, c in list do
		if isA(c, class) then
			return c
		end
	end
	return nil
end
function Methods.WaitForChild(self, name)
	local c = Methods.FindFirstChild(self, name)
	assert(c, "WaitForChild : " .. name .. " absent de " .. tostring(self))
	return c
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
	self.Destroying:Fire()
	for _, c in Methods.GetChildren(self) do
		Methods.Destroy(c)
	end
	setParent(self, nil)
	rawset(self, "_destroyed", true)
end
function Methods.Clone(self)
	if rawget(self, "_props").Archivable == false then
		return nil
	end
	local copy = newInstance(rawget(self, "_class"))
	local map = {}
	local function deep(src, dst)
		map[src] = dst
		for k, v in rawget(src, "_props") do
			rawget(dst, "_props")[k] = v
		end
		for k, v in rawget(src, "_attrs") do
			rawget(dst, "_attrs")[k] = v
		end
		for tag in tagsOf[src] or {} do
			tagsOf[dst] = tagsOf[dst] or {}
			tagsOf[dst][tag] = true
		end
		for _, c in rawget(src, "_children") do
			local cc = newInstance(rawget(c, "_class"))
			deep(c, cc)
			rawset(cc, "_parent", dst)
			table.insert(rawget(dst, "_children"), cc)
		end
	end
	deep(self, copy)
	-- Références internes (PrimaryPart, Part0…) : vers les copies, comme Roblox.
	for src, dst in map do
		for k, v in rawget(dst, "_props") do
			if type(v) == "table" and getmetatable(v) == InstanceMT and map[v] then
				rawget(dst, "_props")[k] = map[v]
			end
		end
	end
	return copy
end
function Methods.GetFullName(self)
	local names = {}
	local inst = self
	while inst and inst ~= DataModel do
		table.insert(names, 1, inst.Name)
		inst = rawget(inst, "_parent")
	end
	return table.concat(names, ".")
end
-- Model
local function parts(model)
	local out = {}
	for _, d in Methods.GetDescendants(model) do
		if isA(d, "BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
function Methods.GetPivot(self)
	if isA(self, "BasePart") then
		return self.CFrame * self.PivotOffset
	end
	local primary = self.PrimaryPart
	if primary then
		return primary.CFrame * primary.PivotOffset
	end
	return self.WorldPivot
end
function Methods.PivotTo(self, target)
	local delta = target * Methods.GetPivot(self):Inverse()
	if isA(self, "BasePart") then
		self.CFrame = delta * self.CFrame
		return
	end
	for _, p in parts(self) do
		p.CFrame = delta * p.CFrame
	end
	if self.PrimaryPart == nil then
		self.WorldPivot = target
	end
end
function Methods.GetExtentsSize(self)
	local pivot = Methods.GetPivot(self)
	local lo, hi
	for _, p in parts(self) do
		local h = p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local world = p.CFrame * v3(sx * h.X, sy * h.Y, sz * h.Z)
					local q = pivot:PointToObjectSpace(world)
					lo = if lo then v3(math.min(lo.X, q.X), math.min(lo.Y, q.Y), math.min(lo.Z, q.Z)) else q
					hi = if hi then v3(math.max(hi.X, q.X), math.max(hi.Y, q.Y), math.max(hi.Z, q.Z)) else q
				end
			end
		end
	end
	return hi - lo
end
-- Humanoid
function Methods.UnequipTools(self)
	local character = rawget(self, "_parent")
	for _, player in Methods.GetChildren(Players) do
		if player.Character == character then
			local backpack = Methods.FindFirstChild(player, "Backpack")
			for _, c in Methods.GetChildren(character) do
				if rawget(c, "_class") == "Tool" then
					c.Parent = backpack
				end
			end
		end
	end
	rawset(self, "_unequipCalls", (rawget(self, "_unequipCalls") or 0) + 1)
end
function Methods.SetStateEnabled(self, state, enabled)
	local states = rawget(self, "_states") or {}
	rawset(self, "_states", states)
	states[state] = enabled
end

InstanceAPI = { new = newInstance }

---------------------------------------------------------------- services
CollectionService = {
	AddTag = function(_, inst, tag)
		tagsOf[inst] = tagsOf[inst] or {}
		if tagsOf[inst][tag] then
			return
		end
		tagsOf[inst][tag] = true
		if inGame(inst) then
			tagSignal(addedSignals, tag):Fire(inst)
		end
	end,
	HasTag = function(_, inst, tag)
		return (tagsOf[inst] or {})[tag] == true
	end,
	GetTagged = function(_, tag)
		local out = {}
		for inst, tags in tagsOf do
			if tags[tag] and inGame(inst) then
				table.insert(out, inst)
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function(_, tag)
		return tagSignal(addedSignals, tag)
	end,
	GetInstanceRemovedSignal = function(_, tag)
		return tagSignal(removedSignals, tag)
	end,
}

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
StarterPlayer = service("StarterPlayer")
Players = service("Players")

function Methods.GetPlayers(self)
	local out = {}
	for _, c in rawget(self, "_children") do
		if rawget(c, "_class") == "Player" then
			table.insert(out, c)
		end
	end
	return out
end

function make(class, props, parent)
	local inst = newInstance(class)
	for k, v in props or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

RENDER_STEPPED = newSignal()

---------------------------------------------------------------- modules
local moduleSource = {}
function moduleScript(parent, name, key)
	local m = make("ModuleScript", { Name = name }, parent)
	moduleSource[m] = key
	return m
end

local caches = { server = {}, client = {} }
local function makeGame(side)
	local runService = {
		IsStudio = function()
			return true
		end,
		IsServer = function()
			return side == "server"
		end,
		IsClient = function()
			return side == "client"
		end,
		RenderStepped = RENDER_STEPPED,
	}
	local services = {
		Players = Players,
		ReplicatedStorage = ReplicatedStorage,
		RunService = runService,
		CollectionService = CollectionService,
		Workspace = Workspace,
	}
	return {
		GetService = function(_, name)
			return services[name] or error("service absent du faux Roblox : " .. name)
		end,
	}
end
local games = { server = makeGame("server"), client = makeGame("client") }

local function typeofStub(v)
	local mt = getmetatable(v)
	if type(v) == "table" and type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return type(v)
end

local function logger(side, kind)
	return function(...)
		local parts = table.pack(...)
		for i = 1, parts.n do
			parts[i] = tostring(parts[i])
		end
		table.insert(LOG, { side = side, kind = kind, text = table.concat(parts, " ") })
	end
end

function requireModule(m, side)
	local cache = caches[side]
	if cache[m] ~= nil then
		return cache[m]
	end
	local key = moduleSource[m]
	assert(key, "require d'un objet qui n'est pas un ModuleScript du banc : " .. tostring(m))
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
		Vector2 = Vector2,
		CFrame = CFrame,
		Color3 = Color3,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		NumberSequence = NumberSequence,
		NumberRange = NumberRange,
		UDim2 = UDim2,
		Enum = Enum,
		Instance = InstanceAPI,
		typeof = typeofStub,
		warn = logger(side, "WARN"),
		print = logger(side, "PRINT"),
	}, { __index = getfenv(1) })
	setfenv(fn, env)
	local result = fn()
	cache[m] = result
	return result
end

---------------------------------------------------------------- vérifications
function check(cond, label)
	CHECKS += 1
	if not cond then
		FAILS += 1
		print("ÉCHEC : " .. label)
	end
end
function logCount(kind, pattern)
	local n = 0
	for _, line in LOG do
		if line.kind == kind and string.find(line.text, pattern, 1, true) then
			n += 1
		end
	end
	return n
end
function clearLog()
	table.clear(LOG)
end
function dumpLog()
	for _, line in LOG do
		print(`  [{line.side} {line.kind}] {line.text}`)
	end
end
function isDestroyed(inst)
	return rawget(inst, "_destroyed") == true
end
function unequipCalls(humanoid)
	return rawget(humanoid, "_unequipCalls") or 0
end
function jumpState(humanoid)
	local states = rawget(humanoid, "_states")
	return states and states["Enum.HumanoidStateType.Jumping"]
end
function hasTag(inst, tag)
	return (tagsOf[inst] or {})[tag] == true
end
