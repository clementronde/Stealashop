--!nocheck
-- Banc a318 (L-300, 2026-11-23) : faux Roblox côté client, fait pour le streaming.
--   - un modèle sort du streaming : streamOut(m) le met à Parent = nil (comme Roblox : pas détruit, le même objet
--     revient) ; CollectionService annonce alors la sortie de chaque instance taguée qui quitte le jeu ;
--   - il revient : streamIn(m, lose) le remet à sa place ; lose = true imite le cas « les changements locaux sont
--     perdus » de la doc (propriétés remises à celles du serveur, instances créées par le client retirées) ;
--   - chaque signal compte ses connexions vivantes (liveConnections) : une écoute qui fuit se voit.
-- Instances permissives : toute propriété s'écrit, une propriété jamais écrite se lit à sa valeur par défaut (table
-- DEFAULTS) ou nil. Temps simulé (advance), tâches comme task.*.

SOURCES = {}
local CHECKS, FAILS = 0, 0
LOG = {}
ERRORS = {}

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
		table.insert(ERRORS, tostring(err))
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
	local co = if type(f) == "thread" then f else coroutine.create(f)
	schedule(simTime, co, ...)
	return co
end
function taskLib.delay(d, f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
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
	for i = #queue, 1, -1 do
		if queue[i].co == co then
			table.remove(queue, i)
		end
	end
end
local function runQueue(target)
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
end

---------------------------------------------------------------- signaux
local SignalMT = {}
SignalMT.__index = SignalMT
function newSignal()
	return setmetatable({ _conns = {} }, SignalMT)
end
function SignalMT:Connect(fn)
	local conn = { Connected = true }
	local list = self._conns
	function conn.Disconnect(c)
		if c.Connected then
			c.Connected = false
			local i = table.find(list, c)
			if i then
				table.remove(list, i)
			end
		end
	end
	conn._fn = fn
	table.insert(list, conn)
	return conn
end
function SignalMT:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function SignalMT:Fire(...)
	for _, c in table.clone(self._conns) do
		if c.Connected then
			local ok, err = pcall(c._fn, ...)
			if not ok then
				table.insert(ERRORS, tostring(err))
				print("ERREUR dans une écoute : " .. tostring(err))
			end
		end
	end
end
function SignalMT:Wait()
	local co = coroutine.running()
	self:Once(function(...)
		resume(co, ...)
	end)
	return coroutine.yield()
end
function liveConnections(signal)
	return #signal._conns
end

---------------------------------------------------------------- valeurs
local function valueType(name, fields)
	return setmetatable(fields, { __type = name, __tostring = function()
		return name
	end })
end
local V3MT = { __type = "Vector3" }
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3MT)
end
V3MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return if m > 0 then v3(v.X / m, v.Y / m, v.Z / m) else v3()
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
		end
	end
	return nil
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
Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }

-- CFrame : translation seule (rotation identité), assez pour les vantaux, les rideaux et les pivots.
local CFMT = { __type = "CFrame" }
local function cf(p)
	return setmetatable({ Position = p }, CFMT)
end
CFMT.__index = function(c, k)
	if k == "X" or k == "Y" or k == "Z" then
		return c.Position[k]
	elseif k == "RightVector" then
		return v3(1, 0, 0)
	elseif k == "UpVector" then
		return v3(0, 1, 0)
	elseif k == "LookVector" then
		return v3(0, 0, -1)
	elseif k == "Rotation" then
		return cf(v3())
	elseif k == "Lerp" then
		return function(a, b, t)
			return cf(a.Position:Lerp(b.Position, t))
		end
	elseif k == "Inverse" then
		return function(a)
			return cf(-a.Position)
		end
	elseif k == "PointToObjectSpace" then
		return function(a, p)
			return p - a.Position
		end
	elseif k == "PointToWorldSpace" then
		return function(a, p)
			return p + a.Position
		end
	elseif k == "ToObjectSpace" then
		return function(a, b)
			return cf(b.Position - a.Position)
		end
	elseif k == "ToWorldSpace" then
		return function(a, b)
			return cf(b.Position + a.Position)
		end
	elseif k == "VectorToObjectSpace" or k == "VectorToWorldSpace" then
		return function(_a, v)
			return v
		end
	elseif k == "GetComponents" then
		return function(a)
			return a.Position.X, a.Position.Y, a.Position.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1
		end
	end
	return nil
end
CFMT.__mul = function(a, b)
	if getmetatable(b) == CFMT then
		return cf(a.Position + b.Position)
	end
	return a.Position + b
end
CFMT.__add = function(a, v)
	return cf(a.Position + v)
end
CFMT.__sub = function(a, v)
	return cf(a.Position - v)
end
CFMT.__eq = function(a, b)
	return a.Position == b.Position
end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then
			return cf(x)
		end
		return cf(v3(x, y, z))
	end,
	identity = cf(v3()),
	Angles = function()
		return cf(v3())
	end,
	fromEulerAnglesXYZ = function()
		return cf(v3())
	end,
	fromEulerAnglesYXZ = function()
		return cf(v3())
	end,
	fromAxisAngle = function()
		return cf(v3())
	end,
	fromOrientation = function()
		return cf(v3())
	end,
	lookAt = function(p)
		return cf(p)
	end,
	fromMatrix = function(p)
		return cf(p)
	end,
}

-- Types sans calcul (Color3, UDim2, ColorSequence…) : un constructeur pour toute clé, une valeur qui garde ses
-- arguments.
local function opaque(name)
	local mt = { __type = name }
	mt.__index = function(_, k)
		if k == "R" or k == "G" or k == "B" or k == "X" or k == "Y" or k == "Scale" or k == "Offset" then
			return 0
		end
		if k == "Lerp" then
			return function(a)
				return a
			end
		end
		if k == "ToHSV" then
			return function()
				return 0, 0, 0
			end
		end
		return nil
	end
	mt.__eq = function(a, b)
		return rawequal(a, b)
	end
	return setmetatable({}, {
		__index = function(_, _ctor)
			return function(...)
				return setmetatable({ _args = table.pack(...) }, mt)
			end
		end,
	})
end
Color3 = opaque("Color3")
UDim = opaque("UDim")
UDim2 = opaque("UDim2")
Vector2 = opaque("Vector2")
NumberRange = opaque("NumberRange")
NumberSequence = opaque("NumberSequence")
NumberSequenceKeypoint = opaque("NumberSequenceKeypoint")
ColorSequence = opaque("ColorSequence")
ColorSequenceKeypoint = opaque("ColorSequenceKeypoint")
TweenInfo = opaque("TweenInfo")
Font = opaque("Font")
Rect = opaque("Rect")
BrickColor = opaque("BrickColor")
PhysicalProperties = opaque("PhysicalProperties")
Region3 = opaque("Region3")
OverlapParams = opaque("OverlapParams")
RaycastParams = {
	new = function()
		return { FilterDescendantsInstances = {} }
	end,
}
Random = {
	new = function()
		return {
			NextNumber = function(_, a, b)
				a, b = a or 0, b or 1
				return (a + b) / 2
			end,
			NextInteger = function(_, a, _b)
				return a
			end,
		}
	end,
}

local enumItems = {}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		local e = enumItems[enumName]
		if e == nil then
			e = setmetatable({}, {
				__index = function(t, item)
					local v = setmetatable({ Name = item, EnumType = enumName, Value = 0 }, { __type = "EnumItem", __tostring = function()
						return "Enum." .. enumName .. "." .. item
					end })
					rawset(t, item, v)
					return v
				end,
			})
			e.GetEnumItems = function()
				return {}
			end
			enumItems[enumName] = e
		end
		return e
	end,
})

---------------------------------------------------------------- instances
local ISA = {
	Part = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	UnionOperation = { "BasePart", "PVInstance" },
	WedgePart = { "BasePart", "PVInstance" },
	BasePart = { "PVInstance" },
	Model = { "PVInstance" },
	Workspace = { "Model", "PVInstance" },
	PointLight = { "Light" },
	SpotLight = { "Light" },
	SurfaceLight = { "Light" },
	Texture = { "Decal" },
	ModuleScript = { "LuaSourceContainer" },
	Script = { "LuaSourceContainer" },
	LocalScript = { "LuaSourceContainer" },
	ScreenGui = { "LayerCollector", "GuiBase2d" },
	BillboardGui = { "LayerCollector", "GuiBase2d" },
	SurfaceGui = { "LayerCollector", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	TextLabel = { "GuiObject", "GuiBase2d" },
	ImageLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	ImageButton = { "GuiButton", "GuiObject", "GuiBase2d" },
}
local DEFAULTS = {
	BasePart = {
		Transparency = 0,
		LocalTransparencyModifier = 0,
		CanCollide = true,
		CanQuery = true,
		CanTouch = true,
		Anchored = true,
		CastShadow = true,
		Material = Enum.Material.Plastic,
		Size = v3(4, 4, 4),
		Position = v3(),
	},
	Light = { Enabled = true },
	ParticleEmitter = { Enabled = true },
	Beam = { Enabled = true },
	Decal = { Transparency = 0, LocalTransparencyModifier = 0 },
	ProximityPrompt = { Enabled = true, ActionText = "", ObjectText = "" },
	GuiObject = { Visible = true },
	LayerCollector = { Enabled = true },
	Camera = { FieldOfView = 70 },
}
local Methods = {}
local InstanceMT = { __type = "Instance" }
local tagsOf = setmetatable({}, { __mode = "k" })
ALL = {}

local function isA(self, class)
	local c = rawget(self, "_class")
	if c == class or class == "Instance" then
		return true
	end
	for _, parent in ISA[c] or {} do
		if parent == class then
			return true
		end
	end
	return false
end
local function signalOf(self, name)
	local signals = rawget(self, "_signals")
	signals[name] = signals[name] or newSignal()
	return signals[name]
end
local EVENTS = {
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	AncestryChanged = true,
	Destroying = true,
	Changed = true,
	Triggered = true,
	TriggerEnded = true,
	PromptButtonHoldBegan = true,
	PromptButtonHoldEnded = true,
	Activated = true,
	MouseButton1Click = true,
	MouseButton1Down = true,
	MouseEnter = true,
	MouseLeave = true,
	InputBegan = true,
	InputEnded = true,
	Touched = true,
	TouchEnded = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	Ended = true,
	Played = true,
	Stopped = true,
	DidLoop = true,
	Completed = true,
	StateChanged = true,
	Died = true,
	Running = true,
	OnClientEvent = true,
	Event = true,
}

InstanceMT.__index = function(self, key)
	local m = Methods[key]
	if m then
		return m
	end
	if EVENTS[key] then
		return signalOf(self, key)
	end
	local props = rawget(self, "_props")
	local v = props[key]
	if v ~= nil then
		return v
	end
	if key == "ClassName" then
		return rawget(self, "_class")
	elseif key == "Parent" then
		return rawget(self, "_parent")
	end
	for _, c in rawget(self, "_children") do
		if rawget(c, "_props").Name == key then
			return c
		end
	end
	local class = rawget(self, "_class")
	local d = DEFAULTS[class]
	if d and d[key] ~= nil then
		return d[key]
	end
	for _, parent in ISA[class] or {} do
		d = DEFAULTS[parent]
		if d and d[key] ~= nil then
			return d[key]
		end
	end
	if key == "CFrame" and isA(self, "BasePart") then
		return cf(self.Position)
	end
	return nil
end

local function inGame(inst)
	local p = inst
	while p do
		if rawget(p, "_class") == "DataModel" then
			return true
		end
		p = rawget(p, "_parent")
	end
	return false
end
local CS_added, CS_removed = {}, {}
local function csSignal(map, tag)
	map[tag] = map[tag] or newSignal()
	return map[tag]
end
local function announceTags(inst, entering)
	local list = { inst }
	for _, d in Methods.GetDescendants(inst) do
		table.insert(list, d)
	end
	for _, i in list do
		for tag in tagsOf[i] or {} do
			csSignal(if entering then CS_added else CS_removed, tag):Fire(i)
		end
	end
end

local function setParent(self, parent)
	local old = rawget(self, "_parent")
	if old == parent then
		return
	end
	local wasIn = inGame(self)
	if old then
		local anc = old
		while anc do
			local s = rawget(anc, "_signals").DescendantRemoving
			if s then
				s:Fire(self)
				for _, d in Methods.GetDescendants(self) do
					s:Fire(d)
				end
			end
			anc = rawget(anc, "_parent")
		end
		local siblings = rawget(old, "_children")
		local i = table.find(siblings, self)
		if i then
			table.remove(siblings, i)
		end
	end
	rawset(self, "_parent", parent)
	if old then
		local s = rawget(old, "_signals").ChildRemoved
		if s then
			s:Fire(self)
		end
	end
	if wasIn and not inGame(self) then
		announceTags(self, false)
	end
	if parent then
		table.insert(rawget(parent, "_children"), self)
		local s = rawget(parent, "_signals").ChildAdded
		if s then
			s:Fire(self)
		end
		local anc = parent
		while anc do
			local d = rawget(anc, "_signals").DescendantAdded
			if d then
				d:Fire(self)
				for _, x in Methods.GetDescendants(self) do
					d:Fire(x)
				end
			end
			anc = rawget(anc, "_parent")
		end
	end
	local a = rawget(self, "_signals").AncestryChanged
	if a then
		a:Fire(self, parent)
	end
	if not wasIn and inGame(self) then
		announceTags(self, true)
	end
end

InstanceMT.__newindex = function(self, key, value)
	if key == "Parent" then
		if rawget(self, "_destroyed") then
			error("Parent d'une instance détruite", 2)
		end
		setParent(self, value)
		return
	end
	local props = rawget(self, "_props")
	if props[key] == value then
		return
	end
	props[key] = value
	local ps = rawget(self, "_propSignals")[key]
	if ps then
		ps:Fire()
	end
	local ch = rawget(self, "_signals").Changed
	if ch then
		ch:Fire(key)
	end
end
InstanceMT.__tostring = function(self)
	return rawget(self, "_props").Name or rawget(self, "_class")
end

CREATED_BY_CLIENT = setmetatable({}, { __mode = "k" })
local clientPhase = false
function newInstance(class, props, parent)
	local self = setmetatable({
		_class = class,
		_props = { Name = class },
		_children = {},
		_attrs = {},
		_attrSignals = {},
		_propSignals = {},
		_signals = {},
		_parent = nil,
		_destroyed = false,
	}, InstanceMT)
	for k, v in props or {} do
		rawget(self, "_props")[k] = v
	end
	if clientPhase then
		CREATED_BY_CLIENT[self] = true
	end
	table.insert(ALL, self)
	if parent then
		self.Parent = parent
	end
	return self
end
function startClientPhase()
	clientPhase = true
end

function Methods.IsA(self, class)
	return isA(self, class)
end
function Methods.IsDescendantOf(self, ancestor)
	local p = rawget(self, "_parent")
	while p do
		if p == ancestor then
			return true
		end
		p = rawget(p, "_parent")
	end
	return false
end
function Methods.IsAncestorOf(self, other)
	return Methods.IsDescendantOf(other, self)
end
function Methods.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(i)
		for _, c in rawget(i, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Methods.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_props").Name == name then
			return c
		end
	end
	if recursive then
		for _, d in Methods.GetDescendants(self) do
			if rawget(d, "_props").Name == name then
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
function Methods.FindFirstChildWhichIsA(self, class, recursive)
	for _, c in (if recursive then Methods.GetDescendants(self) else rawget(self, "_children")) do
		if isA(c, class) then
			return c
		end
	end
	return nil
end
function Methods.FindFirstAncestorOfClass(self, class)
	local p = rawget(self, "_parent")
	while p do
		if rawget(p, "_class") == class then
			return p
		end
		p = rawget(p, "_parent")
	end
	return nil
end
function Methods.FindFirstAncestorWhichIsA(self, class)
	local p = rawget(self, "_parent")
	while p do
		if isA(p, class) then
			return p
		end
		p = rawget(p, "_parent")
	end
	return nil
end
function Methods.FindFirstAncestor(self, name)
	local p = rawget(self, "_parent")
	while p do
		if p.Name == name then
			return p
		end
		p = rawget(p, "_parent")
	end
	return nil
end
function Methods.WaitForChild(self, name, timeout)
	local c = Methods.FindFirstChild(self, name)
	if c then
		return c
	end
	if coroutine.isyieldable() then
		local deadline = simTime + (timeout or 5)
		while simTime < deadline do
			taskLib.wait(0.05)
			c = Methods.FindFirstChild(self, name)
			if c then
				return c
			end
		end
	end
	if timeout == nil then
		error(`WaitForChild sans délai, jamais trouvé : {Methods.GetFullName(self)}.{name}`, 2)
	end
	return nil
end
function Methods.GetAttribute(self, name)
	return rawget(self, "_attrs")[name]
end
function Methods.GetAttributes(self)
	return table.clone(rawget(self, "_attrs"))
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
	local a = rawget(self, "_signals").AttributeChanged
	if a then
		a:Fire(name)
	end
end
function Methods.GetAttributeChangedSignal(self, name)
	local s = rawget(self, "_attrSignals")
	s[name] = s[name] or newSignal()
	return s[name]
end
function Methods.GetPropertyChangedSignal(self, name)
	local s = rawget(self, "_propSignals")
	s[name] = s[name] or newSignal()
	return s[name]
end
function Methods.Destroy(self)
	if rawget(self, "_destroyed") then
		return
	end
	local d = rawget(self, "_signals").Destroying
	if d then
		d:Fire()
	end
	for _, c in Methods.GetChildren(self) do
		Methods.Destroy(c)
	end
	if rawget(self, "_parent") then
		setParent(self, nil)
	end
	rawset(self, "_destroyed", true)
end
function Methods.ClearAllChildren(self)
	for _, c in Methods.GetChildren(self) do
		Methods.Destroy(c)
	end
end
function Methods.Clone(self)
	if rawget(self, "_props").Archivable == false then
		return nil
	end
	local copy = newInstance(rawget(self, "_class"))
	for k, v in rawget(self, "_props") do
		rawget(copy, "_props")[k] = v
	end
	for k, v in rawget(self, "_attrs") do
		rawget(copy, "_attrs")[k] = v
	end
	for _, c in rawget(self, "_children") do
		local cc = Methods.Clone(c)
		if cc then
			cc.Parent = copy
		end
	end
	return copy
end
function Methods.GetFullName(self)
	local names = {}
	local p = self
	while p and rawget(p, "_class") ~= "DataModel" do
		table.insert(names, 1, p.Name)
		p = rawget(p, "_parent")
	end
	return table.concat(names, ".")
end
local function firstPart(self)
	local pp = rawget(self, "_props").PrimaryPart
	if pp then
		return pp
	end
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			return d
		end
	end
	return nil
end
function Methods.GetPivot(self)
	if isA(self, "BasePart") then
		return cf(self.Position)
	end
	local pivot = rawget(self, "_props").WorldPivot
	if pivot then
		return pivot
	end
	local part = firstPart(self)
	return if part then cf(part.Position) else cf(v3())
end
function Methods.PivotTo(self, target)
	local delta = target.Position - Methods.GetPivot(self).Position
	if isA(self, "BasePart") then
		self.Position = self.Position + delta
	else
		local pivot = rawget(self, "_props").WorldPivot
		if pivot then
			rawget(self, "_props").WorldPivot = cf(pivot.Position + delta)
		end
	end
	for _, d in Methods.GetDescendants(self) do
		if isA(d, "BasePart") then
			d.Position = d.Position + delta
		end
	end
end
function Methods.GetBoundingBox(self)
	return Methods.GetPivot(self), v3(8, 8, 8)
end
function Methods.GetExtentsSize()
	return v3(8, 8, 8)
end
function Methods.Emit() end
function Methods.Play() end
function Methods.Stop() end
function Methods.SetStateEnabled() end
function Methods.GetState()
	return Enum.HumanoidStateType.Running
end
function Methods.ChangeState() end
function Methods.GetPlayers(self)
	local out = {}
	for _, c in rawget(self, "_children") do
		if rawget(c, "_class") == "Player" then
			table.insert(out, c)
		end
	end
	return out
end
function Methods.GetServerTimeNow()
	return 1000 + simTime
end
function Methods.Raycast()
	return nil
end
function Methods.GetMouse()
	return { X = 0, Y = 0, Hit = cf(v3()), Target = nil }
end
function Methods.WorldToViewportPoint(_, p)
	return v3(0, 0, 1), true
end
function Methods.WorldToScreenPoint(_, p)
	return v3(0, 0, 1), true
end
function Methods.ScreenPointToRay()
	return { Origin = v3(), Direction = v3(0, 0, -1) }
end
function Methods.FireServer() end
function Methods.LoadAnimation()
	return { Play = function() end, Stop = function() end, IsPlaying = false, Length = 1, GetMarkerReachedSignal = function()
		return newSignal()
	end, Stopped = newSignal(), Ended = newSignal(), AdjustSpeed = function() end }
end

---------------------------------------------------------------- CollectionService
local CollectionService = {}
function CollectionService.AddTag(_, inst, tag)
	tagsOf[inst] = tagsOf[inst] or {}
	if tagsOf[inst][tag] then
		return
	end
	tagsOf[inst][tag] = true
	if inGame(inst) then
		csSignal(CS_added, tag):Fire(inst)
	end
end
function CollectionService.RemoveTag(_, inst, tag)
	if tagsOf[inst] and tagsOf[inst][tag] then
		tagsOf[inst][tag] = nil
		if inGame(inst) then
			csSignal(CS_removed, tag):Fire(inst)
		end
	end
end
function CollectionService.HasTag(_, inst, tag)
	return tagsOf[inst] ~= nil and tagsOf[inst][tag] == true
end
function CollectionService.GetTagged(_, tag)
	local out = {}
	for _, inst in ALL do
		if tagsOf[inst] and tagsOf[inst][tag] and not rawget(inst, "_destroyed") and inGame(inst) then
			table.insert(out, inst)
		end
	end
	return out
end
function CollectionService.GetInstanceAddedSignal(_, tag)
	return csSignal(CS_added, tag)
end
function CollectionService.GetInstanceRemovedSignal(_, tag)
	return csSignal(CS_removed, tag)
end
function CollectionService.GetTags(_, inst)
	local out = {}
	for t in tagsOf[inst] or {} do
		table.insert(out, t)
	end
	return out
end
function Methods.AddTag(self, tag)
	CollectionService:AddTag(self, tag)
end
function Methods.HasTag(self, tag)
	return CollectionService:HasTag(self, tag)
end
function Methods.RemoveTag(self, tag)
	CollectionService:RemoveTag(self, tag)
end

---------------------------------------------------------------- jeu
DataModel = newInstance("DataModel")
local function svc(class)
	return newInstance(class, { Name = class }, DataModel)
end
Workspace = svc("Workspace")
ReplicatedStorage = svc("ReplicatedStorage")
Players = svc("Players")
Lighting = svc("Lighting")
Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.Ambient = Color3.new(0, 0, 0)
Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
SoundService = svc("SoundService")
StarterGui = svc("StarterGui")
Workspace.CurrentCamera = newInstance("Camera", { CFrame = cf(v3()), ViewportSize = v3(1920, 1080, 0) }, Workspace)
Workspace.StreamingEnabled = true

LocalPlayer = newInstance("Player", { Name = "Moi", UserId = 1, DisplayName = "Moi" }, Players)
local playerGui = newInstance("PlayerGui", { Name = "PlayerGui" }, LocalPlayer)
local playerScripts = newInstance("PlayerScripts", { Name = "PlayerScripts" }, LocalPlayer)
rawget(Players, "_props").LocalPlayer = LocalPlayer
rawget(Players, "_props").PlayerAdded = newSignal() -- lot98 (petit chef 3) : RevealController écoute PlayerRemoving (vague 62)
rawget(Players, "_props").PlayerRemoving = newSignal()
local controllersFolder = newInstance("Folder", { Name = "Controllers" }, newInstance("Folder", { Name = "Client" }, playerScripts))

HEARTBEAT = newSignal()
RENDER = newSignal()
STEPPED = newSignal()
local RunService = {
	Heartbeat = HEARTBEAT,
	RenderStepped = RENDER,
	Stepped = STEPPED,
	PreRender = RENDER,
	PostSimulation = HEARTBEAT,
	PreSimulation = STEPPED,
	IsStudio = function()
		return true
	end,
	IsClient = function()
		return true
	end,
	IsServer = function()
		return false
	end,
	IsRunning = function()
		return true
	end,
	BindToRenderStep = function() end,
	UnbindFromRenderStep = function() end,
}
function advance(dt)
	local step = 1 / 30
	local target = simTime + dt
	while simTime < target - 1e-9 do
		local d = math.min(step, target - simTime)
		runQueue(simTime + d)
		simTime += d
		RENDER:Fire(d)
		STEPPED:Fire(simTime, d)
		HEARTBEAT:Fire(d)
		runQueue(simTime)
	end
	runQueue(simTime)
end
function now()
	return simTime
end

-- Service sans modèle : tout membre est une fonction muette (ou un signal pour un nom d'évènement).
local function quietService(name, extra)
	local t = extra or {}
	return setmetatable(t, {
		__index = function(self, k)
			if EVENTS[k] or string.find(k, "Changed$") or string.find(k, "Began$") or string.find(k, "Ended$") then
				local s = newSignal()
				rawset(self, k, s)
				return s
			end
			return function()
				return nil
			end
		end,
	})
end
local TweenService = quietService("TweenService", {
	GetValue = function(_, alpha)
		return alpha
	end,
	Create = function(_, inst, _info, goal)
		local tween = { Completed = newSignal(), PlaybackState = Enum.PlaybackState.Begin }
		function tween.Play()
			for k, v in goal do
				inst[k] = v
			end
			tween.Completed:Fire(Enum.PlaybackState.Completed)
		end
		function tween.Cancel() end
		function tween.Pause() end
		function tween.Destroy() end
		return tween
	end,
})
local Debris = {
	AddItem = function(_, inst, t)
		taskLib.delay(t or 10, function()
			inst:Destroy()
		end)
	end,
}
local services = {
	Workspace = Workspace,
	ReplicatedStorage = ReplicatedStorage,
	Players = Players,
	Lighting = Lighting,
	SoundService = SoundService,
	StarterGui = StarterGui,
	CollectionService = CollectionService,
	RunService = RunService,
	TweenService = TweenService,
	Debris = Debris,
}
local QUIET = {}
game = setmetatable({
	GetService = function(_, name)
		local s = services[name]
		if s then
			return s
		end
		QUIET[name] = QUIET[name] or quietService(name, { TouchEnabled = false, KeyboardEnabled = true })
		return QUIET[name]
	end,
	Workspace = Workspace,
}, { __index = function(_, k)
	return services[k]
end })

---------------------------------------------------------------- modules
local moduleKey = setmetatable({}, { __mode = "k" })
local cache = {}
local function folderAt(root, parts)
	local cur = root
	for _, p in parts do
		local nxt = Methods.FindFirstChild(cur, p)
		if nxt == nil then
			nxt = newInstance("Folder", { Name = p }, cur)
		end
		cur = nxt
	end
	return cur
end
-- Range chaque SOURCES[« shared/… » ou « client/Controllers/… »] dans l'arbre, comme Rojo.
function mountSources()
	local shared = folderAt(ReplicatedStorage, { "Shared" })
	local keys = {}
	for k in SOURCES do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, key in keys do
		local parts = string.split(key, "/")
		local root, skip
		if parts[1] == "shared" then
			root, skip = shared, 1
		elseif parts[1] == "client" and parts[2] == "Controllers" then
			root, skip = controllersFolder, 2
		end
		if root then
			local dirs = {}
			for i = skip + 1, #parts - 1 do
				table.insert(dirs, parts[i])
			end
			local parent = folderAt(root, dirs)
			local name = string.gsub(parts[#parts], "%.luau$", "")
			local m = newInstance("ModuleScript", { Name = name }, parent)
			moduleKey[m] = key
		end
	end
end
local function fakeTypeof(v)
	local mt = getmetatable(v)
	if type(v) == "table" and type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return type(v)
end
function requireModule(m)
	if cache[m] ~= nil then
		return cache[m]
	end
	local key = moduleKey[m]
	assert(key, "require d'un objet qui n'est pas un ModuleScript du banc : " .. tostring(m))
	local source = SOURCES[key]
	local fn, err = loadstring(source, "=" .. key)
	assert(fn, err)
	local env = setmetatable({
		game = game,
		workspace = Workspace,
		script = m,
		require = requireModule,
		task = taskLib,
		typeof = fakeTypeof,
		Instance = { new = function(class)
			return newInstance(class)
		end },
		os = {
			clock = function()
				return simTime
			end,
			time = function()
				return math.floor(1000 + simTime)
			end,
			date = os.date,
		},
		warn = function(...)
			local t = table.pack(...)
			for i = 1, t.n do
				t[i] = tostring(t[i])
			end
			table.insert(LOG, "WARN " .. table.concat(t, " "))
		end,
		print = function(...)
			local t = table.pack(...)
			for i = 1, t.n do
				t[i] = tostring(t[i])
			end
			table.insert(LOG, "PRINT " .. table.concat(t, " "))
		end,
		tick = function()
			return 1000 + simTime
		end,
		delay = taskLib.delay,
		spawn = taskLib.spawn,
		wait = taskLib.wait,
	}, { __index = getfenv(1) })
	setfenv(fn, env)
	local result = fn()
	cache[m] = result
	return result
end
function controller(name)
	return requireModule(Methods.FindFirstChild(controllersFolder, name))
end
function startController(name)
	local c = controller(name)
	taskLib.spawn(function()
		c.Start()
	end)
	advance(0.1)
	return c
end

---------------------------------------------------------------- streaming
local snapshots = setmetatable({}, { __mode = "k" })
-- État « serveur » d'un modèle (et de ses descendants), relevé avant que le client n'y touche.
function snapshot(model)
	local snap = {}
	for _, i in { model, table.unpack(Methods.GetDescendants(model)) } do
		snap[i] = { props = table.clone(rawget(i, "_props")), parent = rawget(i, "_parent") }
	end
	snapshots[model] = snap
end
local homes = setmetatable({}, { __mode = "k" })
function streamOut(model)
	homes[model] = rawget(model, "_parent")
	model.Parent = nil
end
function streamIn(model, lose)
	if lose then
		local snap = snapshots[model]
		assert(snap, "streamIn(lose) sans snapshot")
		for _, d in Methods.GetDescendants(model) do
			if snap[d] == nil and CREATED_BY_CLIENT[d] then
				d.Parent = nil -- créé par le client : ne revient pas
			end
		end
		for i, s in snap do
			rawset(i, "_props", table.clone(s.props))
		end
	end
	model.Parent = homes[model] or Workspace
end

---------------------------------------------------------------- vérifications
local section = "?"
function scenario(name)
	section = name
	print("— " .. name)
end
function check(cond, label)
	CHECKS += 1
	if cond then
		print("  ok   " .. label)
	else
		FAILS += 1
		print("  ÉCHEC " .. label)
	end
end
function noErrors(label)
	check(#ERRORS == 0, label .. " (aucune erreur" .. (if #ERRORS > 0 then " ; 1re : " .. ERRORS[1] else "") .. ")")
	table.clear(ERRORS)
end
function summary(name)
	print(string.format("scénario %s : %d vérification(s), %d échec(s)", name, CHECKS, FAILS))
end
function part(props, parent)
	return newInstance("Part", props, parent)
end
function model(props, parent)
	return newInstance("Model", props, parent)
end
