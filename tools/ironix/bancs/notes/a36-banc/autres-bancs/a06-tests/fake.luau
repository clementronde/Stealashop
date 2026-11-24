-- Faux Roblox minimal pour tester PlotService hors Studio (luau CLI).
-- Les sources testées arrivent en chaînes : SRC_PLOT, SRC_FIND, SRC_MODELS (préfixe généré).

------------------------------------------------------------------------------
-- Journal
------------------------------------------------------------------------------
local LOG = { prints = {}, warns = {}, errors = {} }
local function fprint(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local line = table.concat(parts, " ")
	table.insert(LOG.prints, line)
	print("  | " .. line)
end
local function fwarn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local line = table.concat(parts, " ")
	table.insert(LOG.warns, line)
	print("  W " .. line)
end

------------------------------------------------------------------------------
-- Vector3
------------------------------------------------------------------------------
local Vector3 = {}
local V3 = {}
local function v3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V3)
end
V3.__index = function(v, k)
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
	error("Vector3." .. tostring(k) .. " inconnu")
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__tostring = function(v)
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end
Vector3.new = function(x, y, z)
	return v3(x or 0, y or 0, z or 0)
end
Vector3.zero = v3(0, 0, 0)

------------------------------------------------------------------------------
-- CFrame (rotation autour de Y seulement : assez pour la greybox)
------------------------------------------------------------------------------
local CFrame = {}
local CF = {}
local function cf(pos, yaw)
	return setmetatable({ _p = pos, _yaw = yaw }, CF)
end
local function rot(yaw, v)
	local c, s = math.cos(yaw), math.sin(yaw)
	return v3(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end
CF.__index = function(c, k)
	if k == "Position" then
		return c._p
	elseif k == "X" then
		return c._p.X
	elseif k == "Y" then
		return c._p.Y
	elseif k == "Z" then
		return c._p.Z
	elseif k == "LookVector" then
		return rot(c._yaw, v3(0, 0, -1))
	elseif k == "VectorToWorldSpace" then
		return function(self, v)
			return rot(self._yaw, v)
		end
	elseif k == "Inverse" then
		return function(self)
			return cf(rot(-self._yaw, -self._p), -self._yaw)
		end
	elseif k == "ToObjectSpace" then
		return function(self, other)
			return self:Inverse() * other
		end
	end
	error("CFrame." .. tostring(k) .. " inconnu")
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		return a._p + rot(a._yaw, b)
	end
	return cf(a._p + rot(a._yaw, b._p), a._yaw + b._yaw)
end
CF.__tostring = function(c)
	return tostring(c._p) .. string.format(" yaw %.3f", c._yaw)
end
CFrame.new = function(x, y, z)
	return cf(v3(x or 0, y or 0, z or 0), 0)
end
CFrame.Angles = function(_, yaw, _)
	return cf(v3(0, 0, 0), yaw)
end
CFrame.identity = cf(v3(0, 0, 0), 0)
CFrame.lookAt = function(pos, target)
	local d = target - pos
	return cf(pos, math.atan2(-d.X, -d.Z))
end

------------------------------------------------------------------------------
-- Enum et petits types
------------------------------------------------------------------------------
local function enumItem(t, n)
	return { Name = n, EnumType = t }
end
local Enum = {
	NormalId = {},
	SurfaceGuiSizingMode = { PixelsPerStud = enumItem("SurfaceGuiSizingMode", "PixelsPerStud") },
	Font = { GothamBold = enumItem("Font", "GothamBold") },
	HumanoidRigType = { R15 = enumItem("HumanoidRigType", "R15"), R6 = enumItem("HumanoidRigType", "R6") },
	RaycastFilterType = { Exclude = enumItem("RaycastFilterType", "Exclude") },
}
local NORMALS = {
	Front = v3(0, 0, -1),
	Back = v3(0, 0, 1),
	Left = v3(-1, 0, 0),
	Right = v3(1, 0, 0),
	Top = v3(0, 1, 0),
	Bottom = v3(0, -1, 0),
}
for name in NORMALS do
	Enum.NormalId[name] = enumItem("NormalId", name)
end
Vector3.FromNormalId = function(face)
	return NORMALS[face.Name]
end

local RaycastParams = {
	new = function()
		return {}
	end,
}
local Font = {
	fromEnum = function(e)
		return { font = e }
	end,
}
local UDim2 = {
	fromScale = function(x, y)
		return { sx = x, sy = y }
	end,
}
local Color3 = {
	new = function(r, g, b)
		return { r = r, g = g, b = b }
	end,
}

------------------------------------------------------------------------------
-- Ordonnanceur (task.spawn, task.wait)
------------------------------------------------------------------------------
local pending = {}
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(LOG.errors, tostring(err))
		print("  E erreur dans une tâche : " .. tostring(err))
	end
end
local task = {
	spawn = function(f, ...)
		local co = coroutine.create(f)
		resume(co, ...)
		return co
	end,
	wait = function(_)
		table.insert(pending, coroutine.running())
		return coroutine.yield()
	end,
}
local function step(n)
	for _ = 1, n or 1 do
		local list = pending
		pending = {}
		for _, co in list do
			resume(co, 1 / 60)
		end
	end
end

------------------------------------------------------------------------------
-- Signal
------------------------------------------------------------------------------
local function newSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(fn)
		local entry = { fn = fn, connected = true }
		table.insert(handlers, entry)
		return {
			Disconnect = function()
				entry.connected = false
				local i = table.find(handlers, entry)
				if i then
					table.remove(handlers, i)
				end
			end,
		}
	end
	function signal:Fire(...)
		for _, entry in table.clone(handlers) do
			if entry.connected then
				task.spawn(entry.fn, ...)
			end
		end
	end
	function signal:Count()
		return #handlers
	end
	return signal
end

------------------------------------------------------------------------------
-- Instances
------------------------------------------------------------------------------
local HIER = {
	Part = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	Folder = {},
	Attachment = {},
	SurfaceGui = { "LayerCollector", "GuiBase" },
	TextLabel = { "GuiObject" },
	Frame = { "GuiObject" },
	Player = {},
	Humanoid = {},
	ModuleScript = { "LuaSourceContainer" },
	Workspace = { "WorldRoot", "Model", "PVInstance" },
	Players = {},
	ReplicatedStorage = {},
	CollectionService = {},
	DataModel = {},
	ServerScriptService = {},
}
local data = {}
local methods = {}
local InstMeta = {}
local tagged = {}

local function D(obj)
	return data[obj]
end

local function newInst(className, name, parent)
	local obj = setmetatable({}, InstMeta)
	data[obj] = { ClassName = className, Name = name or className, Parent = nil, children = {}, attributes = {}, props = {} }
	if parent then
		obj.Parent = parent
	end
	return obj
end

InstMeta.__index = function(obj, key)
	local d = data[obj]
	if methods[key] then
		return methods[key]
	end
	if key == "Name" or key == "ClassName" or key == "Parent" then
		return d[key]
	end
	local v = d.props[key]
	if v ~= nil then
		return v
	end
	for _, child in d.children do
		if data[child].Name == key then
			return child
		end
	end
	return nil
end
InstMeta.__newindex = function(obj, key, value)
	local d = data[obj]
	if key == "Parent" then
		if d.Parent then
			local siblings = data[d.Parent].children
			local i = table.find(siblings, obj)
			if i then
				table.remove(siblings, i)
			end
		end
		d.Parent = value
		if value then
			table.insert(data[value].children, obj)
		end
	elseif key == "Name" then
		d.Name = value
	else
		d.props[key] = value
	end
end
InstMeta.__tostring = function(obj)
	return data[obj].Name
end

function methods.IsA(self, className)
	local d = data[self]
	if className == "Instance" or d.ClassName == className then
		return true
	end
	for _, c in HIER[d.ClassName] or {} do
		if c == className then
			return true
		end
	end
	return false
end
function methods.IsDescendantOf(self, other)
	local p = data[self].Parent
	while p do
		if p == other then
			return true
		end
		p = data[p].Parent
	end
	return false
end
function methods.GetChildren(self)
	return table.clone(data[self].children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(o)
		for _, c in data[o].children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	for _, c in data[self].children do
		if data[c].Name == name then
			return c
		end
	end
	if recursive then
		for _, c in data[self].children do
			local found = methods.FindFirstChild(c, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(self, className, recursive)
	for _, c in data[self].children do
		if methods.IsA(c, className) then
			return c
		end
	end
	if recursive then
		for _, c in data[self].children do
			local found = methods.FindFirstChildWhichIsA(c, className, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, className)
	for _, c in data[self].children do
		if data[c].ClassName == className then
			return c
		end
	end
	return nil
end
function methods.WaitForChild(self, name, _timeout)
	return methods.FindFirstChild(self, name, false)
end
function methods.GetFullName(self)
	local names = {}
	local o = self
	while o and data[o].ClassName ~= "DataModel" do
		table.insert(names, 1, data[o].Name)
		o = data[o].Parent
	end
	return table.concat(names, ".")
end
function methods.GetAttribute(self, k)
	return data[self].attributes[k]
end
function methods.SetAttribute(self, k, v)
	data[self].attributes[k] = v
end
function methods.GetPivot(self)
	local d = data[self]
	if methods.IsA(self, "BasePart") then
		return d.props.CFrame
	end
	local primary = d.props.PrimaryPart
	if primary then
		return data[primary].props.CFrame
	end
	return d.props.WorldPivot or CFrame.identity
end
function methods.PivotTo(self, target)
	local d = data[self]
	if methods.IsA(self, "BasePart") then
		d.props.CFrame = target
		return
	end
	local old = methods.GetPivot(self)
	local delta = target * old:Inverse()
	for _, desc in methods.GetDescendants(self) do
		if methods.IsA(desc, "BasePart") then
			data[desc].props.CFrame = delta * data[desc].props.CFrame
		end
	end
	if d.props.PrimaryPart == nil then
		d.props.WorldPivot = target
	end
end

local function addTag(obj, tag)
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], obj)
end

------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------
local game = newInst("DataModel", "game")
local Workspace = newInst("Workspace", "Workspace", game)
local Players = newInst("Players", "Players", game)
local ReplicatedStorage = newInst("ReplicatedStorage", "ReplicatedStorage", game)
local CollectionService = newInst("CollectionService", "CollectionService", game)
local ServerScriptService = newInst("ServerScriptService", "ServerScriptService", game)

Workspace.StreamingEnabled = false
Workspace.GroundY = 0 -- hauteur du sol renvoyée par le faux Raycast
Workspace.RaycastCalls = 0
function methods.Raycast(self, origin, direction, params)
	local d = data[self]
	d.props.RaycastCalls = (d.props.RaycastCalls or 0) + 1
	d.props.LastRaycast = { origin = origin, direction = direction, params = params }
	local groundY = d.props.GroundY
	if groundY ~= nil and origin.Y >= groundY and origin.Y + direction.Y <= groundY then
		return { Position = v3(origin.X, groundY, origin.Z) }
	end
	return nil
end

Players.PlayerRemoving = newSignal()
function methods.GetPlayers(self)
	local out = {}
	for _, c in data[self].children do
		if data[c].ClassName == "Player" then
			table.insert(out, c)
		end
	end
	return out
end

function methods.GetTagged(_self, tag)
	local out = {}
	for _, obj in tagged[tag] or {} do
		if methods.IsDescendantOf(obj, game) then
			table.insert(out, obj)
		end
	end
	return out
end

function methods.GetService(_self, name)
	local s = methods.FindFirstChild(game, name, false)
	assert(s, "service inconnu " .. name)
	return s
end

-- Joueurs
function methods.RequestStreamAroundAsync(self, position, timeout)
	local d = data[self]
	d.props.StreamRequests = (d.props.StreamRequests or 0) + 1
	if d.props.StreamYield then
		task.wait()
	end
end

------------------------------------------------------------------------------
-- Modules et require
------------------------------------------------------------------------------
local moduleCache = {}
local makeEnv
local function fakeRequire(mod)
	if moduleCache[mod] ~= nil then
		return moduleCache[mod]
	end
	local d = data[mod]
	assert(d and d.ClassName == "ModuleScript", "require d'autre chose qu'un ModuleScript : " .. tostring(mod))
	local value
	if d.props.__value ~= nil then
		value = d.props.__value
	else
		local fn, err = loadstring(d.props.__source, d.Name)
		assert(fn, err)
		setfenv(fn, makeEnv(mod))
		value = fn()
	end
	moduleCache[mod] = value
	return value
end

local Instance = {
	new = function(className)
		return newInst(className, className, nil)
	end,
}

local baseEnv = getfenv()
makeEnv = function(scriptObj)
	return setmetatable({
		game = game,
		script = scriptObj,
		require = fakeRequire,
		Instance = Instance,
		Vector3 = Vector3,
		CFrame = CFrame,
		Enum = Enum,
		RaycastParams = RaycastParams,
		Font = Font,
		UDim2 = UDim2,
		Color3 = Color3,
		task = task,
		print = fprint,
		warn = fwarn,
	}, { __index = baseEnv })
end

local Shared = newInst("Folder", "Shared", ReplicatedStorage)
local Contract = newInst("Folder", "Contract", Shared)
local FindModule = newInst("ModuleScript", "Find", Contract)
FindModule.__source = SRC_FIND
local ModelsModule = newInst("ModuleScript", "Models", Contract)
ModelsModule.__source = SRC_MODELS
-- a22 : Contract/Models lit Config/Items (catalogue v2) ; PlotService n'en lit rien : catalogue simulé.
local ConfigFolder = newInst("Folder", "Config", Shared)
local ItemsModule = newInst("ModuleScript", "Items", ConfigFolder)
ItemsModule.__value = { List = {}, RenamedV1 = {}, RetiredV1 = {} }
local NetFolder = newInst("Folder", "Net", Shared)
local NetModule = newInst("ModuleScript", "Net", NetFolder)
local NOTIFY = {}
NetModule.__value = {
	Server = {
		Notify = {
			Fire = function(_self, player, message, kind)
				table.insert(NOTIFY, { player = player, message = message, kind = kind })
			end,
		},
	},
}

local Server = newInst("Folder", "Server", ServerScriptService)
local Services = newInst("Folder", "Services", Server)

-- Faux DataService : même contrat que le vrai pour OnProfileLoaded et IsLoaded.
local DS = { loaded = {}, listeners = {} }
function DS.IsLoaded(player)
	return DS.loaded[player] == true
end
function DS.OnProfileLoaded(listener)
	table.insert(DS.listeners, listener)
	for player in DS.loaded do
		task.spawn(listener, player)
	end
	return function() end
end
local DataServiceModule = newInst("ModuleScript", "DataService", Services)
DataServiceModule.__value = DS

-- a36 (vague 12, DEV-060) : PlotService déclare ses déplacements à AntiCheatService (Allow). Bouchon :
-- chaque appel est noté dans ANTICHEAT_ALLOWS.
local ANTICHEAT_ALLOWS = {}
local AntiCheatModule = newInst("ModuleScript", "AntiCheatService", Services)
AntiCheatModule.__value = {
	Allow = function(player, seconds, reason)
		table.insert(ANTICHEAT_ALLOWS, { player = player, seconds = seconds, reason = reason })
	end,
	Verify = function()
		return true
	end,
}

local PlotModule = newInst("ModuleScript", "PlotService", Services)
PlotModule.__source = SRC_PLOT

return {
	LOG = LOG,
	ANTICHEAT_ALLOWS = ANTICHEAT_ALLOWS,
	NOTIFY = NOTIFY,
	DS = DS,
	game = game,
	Workspace = Workspace,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	Services = Services,
	PlotModule = PlotModule,
	newInst = newInst,
	newSignal = newSignal,
	addTag = addTag,
	require = fakeRequire,
	step = step,
	task = task,
	Vector3 = Vector3,
	CFrame = CFrame,
	Enum = Enum,
	Color3 = Color3,
	data = data,
}
