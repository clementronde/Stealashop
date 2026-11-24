--!nocheck
-- Faux Roblox minimal du banc pc-cantin (ShelfCapService) : Vector3, CFrame (rotations quelconques), arbre
-- d'Instances (Model, Folder, Part, Attachment, Humanoid, ModuleScript), CollectionService, Workspace,
-- ReplicatedStorage. SOURCES[chemin relatif à src] = texte des modules, ajouté par run.sh avant ce fichier.

LOG = {}
local function logLine(kind, ...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	table.insert(LOG, { kind = kind, text = table.concat(parts, " ") })
end

-- Vector3 ---------------------------------------------------------------------------------------------
local V = {}
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	end
	return V[k]
end
local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b)
	if type(b) == "number" then return vec(a.X / b, a.Y / b, a.Z / b) end
	return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V.__tostring = function(v) return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z) end
function V.Min(a, b) return vec(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function V.Max(a, b) return vec(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
local function dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
Vector3 = { new = vec }
IS_VEC = function(v) return getmetatable(v) == V end

-- CFrame : position p, colonnes r (X), u (Y), b (Z) ; LookVector = -b ------------------------------------
local C = {}
local function cf(p, r, u, b)
	return setmetatable({ p = p, r = r, u = u, b = b }, C)
end
C.__index = function(c, k)
	if k == "Position" then return c.p end
	if k == "RightVector" then return c.r end
	if k == "UpVector" then return c.u end
	if k == "LookVector" then return -c.b end
	return C[k]
end
local function rot(c, v) return c.r * v.X + c.u * v.Y + c.b * v.Z end
C.__mul = function(a, b)
	if getmetatable(b) == V then return a.p + rot(a, b) end
	return cf(a.p + rot(a, b.p), rot(a, b.r), rot(a, b.u), rot(a, b.b))
end
function C.Inverse(c)
	local r = vec(c.r.X, c.u.X, c.b.X)
	local u = vec(c.r.Y, c.u.Y, c.b.Y)
	local b = vec(c.r.Z, c.u.Z, c.b.Z)
	local p = vec(dot(c.r, c.p), dot(c.u, c.p), dot(c.b, c.p))
	return cf(-p, r, u, b)
end
function C.ToObjectSpace(a, b) return a:Inverse() * b end
function C.PointToObjectSpace(c, v)
	local d = v - c.p
	return vec(dot(c.r, d), dot(c.u, d), dot(c.b, d))
end
CFrame = {
	new = function(x, y, z)
		local p = if type(x) == "table" then x else vec(x, y, z)
		return cf(p, vec(1, 0, 0), vec(0, 1, 0), vec(0, 0, 1))
	end,
	-- Rotation autour de Y seulement (les magasins tournés du banc).
	AnglesY = function(a)
		local c, s = math.cos(a), math.sin(a)
		return cf(vec(), vec(c, 0, -s), vec(0, 1, 0), vec(s, 0, c))
	end,
}

-- Instances -------------------------------------------------------------------------------------------
local I = {}
local CLASSES = {
	Part = { BasePart = true, PVInstance = true },
	Model = { PVInstance = true },
	Folder = {},
	Attachment = {},
	Humanoid = {},
	ModuleScript = { LuaSourceContainer = true },
}
TAGS = {} -- [tag] = { [instance] = true }
local added = {} -- [tag] = { listeners }
I.__index = function(inst, k)
	local props = rawget(inst, "_props")
	if k == "WorldPosition" and props.ClassName == "Attachment" then
		return props.Parent.CFrame * props.Position
	end
	if props[k] ~= nil then return props[k] end
	if I[k] then return I[k] end
	for _, child in rawget(inst, "_children") do
		if child.Name == k then return child end
	end
	return nil
end
I.__newindex = function(inst, k, v)
	local props = rawget(inst, "_props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local list = rawget(old, "_children")
			for i, c in list do if c == inst then table.remove(list, i); break end end
		end
		props.Parent = v
		if v then table.insert(rawget(v, "_children"), inst) end
		return
	end
	props[k] = v
end
function I.IsA(inst, class)
	local cn = rawget(inst, "_props").ClassName
	return cn == class or (CLASSES[cn] ~= nil and CLASSES[cn][class] == true) or class == "Instance"
end
-- Attributs (pc-l140 : NoShelfCap, comptage OnShelves / OnFurniture).
function I.GetAttribute(inst, name)
	local attrs = rawget(inst, "_attrs")
	return if attrs then attrs[name] else nil
end
function I.SetAttribute(inst, name, value)
	local attrs = rawget(inst, "_attrs")
	if not attrs then attrs = {}; rawset(inst, "_attrs", attrs) end
	attrs[name] = value
end
function I.GetChildren(inst) return table.clone(rawget(inst, "_children")) end
function I.GetDescendants(inst)
	local out = {}
	local function walk(n)
		for _, c in rawget(n, "_children") do table.insert(out, c); walk(c) end
	end
	walk(inst)
	return out
end
function I.FindFirstChild(inst, name, recursive)
	local list = if recursive then inst:GetDescendants() else inst:GetChildren()
	for _, c in list do if c.Name == name then return c end end
	return nil
end
function I.FindFirstChildOfClass(inst, class)
	for _, c in rawget(inst, "_children") do if c.ClassName == class then return c end end
	return nil
end
function I.IsDescendantOf(inst, anc)
	local n = rawget(inst, "_props").Parent
	while n do
		if n == anc then return true end
		n = rawget(n, "_props").Parent
	end
	return false
end
function I.Destroy(inst)
	for _, c in inst:GetChildren() do c:Destroy() end
	inst.Parent = nil
	for _, set in TAGS do set[inst] = nil end
end
function I.GetFullName(inst)
	local names = {}
	local n = inst
	while n and n.ClassName ~= "DataModel" do table.insert(names, 1, n.Name); n = rawget(n, "_props").Parent end
	return table.concat(names, ".")
end
local function new(class, name)
	local props = { ClassName = class, Name = name or class }
	if CLASSES[class] and CLASSES[class].BasePart then
		props.CFrame = CFrame.new(0, 0, 0); props.Size = vec(4, 1, 2)
		props.Anchored = false; props.CanCollide = true; props.CanTouch = true; props.CanQuery = true
		props.CastShadow = true; props.Transparency = 0
	elseif class == "Attachment" then
		props.Position = vec()
	end
	return setmetatable({ _props = props, _children = {} }, I)
end
Instance = { new = function(class) return new(class) end }
NEW = new

local DataModel = new("DataModel", "game")
WORKSPACE = new("Workspace", "Workspace"); WORKSPACE.Parent = DataModel
local RS = new("ReplicatedStorage", "ReplicatedStorage"); RS.Parent = DataModel
local Shared = new("Folder", "Shared"); Shared.Parent = RS
local Config = new("Folder", "Config"); Config.Parent = Shared
local ServerFolder = new("Folder", "Services")

local CollectionService = {}
function CollectionService.GetTagged(_, tag)
	local out = {}
	for inst in TAGS[tag] or {} do table.insert(out, inst) end
	table.sort(out, function(a, b) return a.Name < b.Name end)
	return out
end
function CollectionService.HasTag(_, inst, tag) return (TAGS[tag] or {})[inst] == true end
function CollectionService.AddTag(_, inst, tag)
	TAGS[tag] = TAGS[tag] or {}
	TAGS[tag][inst] = true
	for _, fn in added[tag] or {} do fn(inst) end
end
function CollectionService.GetInstanceAddedSignal(_, tag)
	return {
		Connect = function(_, fn)
			added[tag] = added[tag] or {}
			table.insert(added[tag], fn)
			return { Disconnect = function() end }
		end,
	}
end
CS = CollectionService

local services = { CollectionService = CollectionService, Workspace = WORKSPACE, ReplicatedStorage = RS }
function DataModel.GetService(_, name)
	return services[name] or error("service absent du faux : " .. name)
end
game = DataModel

-- Modules : ModuleScript fictifs remplis depuis SOURCES ----------------------------------------------
local cache = {}
function REQUIRE(m)
	if cache[m] ~= nil then return cache[m] end
	local src = rawget(m, "_props").Source
	assert(src, "module sans source : " .. tostring(m.Name))
	local fn, err = loadstring(src, "=" .. m.Name)
	assert(fn, err)
	setfenv(fn, setmetatable({
		game = game, script = m, Vector3 = Vector3, CFrame = CFrame, Instance = Instance,
		require = REQUIRE,
		print = function(...) logLine("PRINT", ...) end,
		warn = function(...) logLine("WARN", ...) end,
	}, { __index = _G }))
	local result = fn()
	cache[m] = result
	return result
end
local function module(parent, name, key)
	local m = new("ModuleScript", name)
	m.Source = assert(SOURCES[key], "source absente : " .. key)
	m.Parent = parent
	return m
end
module(Config, "DeepFreeze", "shared/Config/DeepFreeze.luau")
module(Config, "Balance", "shared/Config/Balance.luau")
module(Config, "ShelfCaps", "shared/Config/ShelfCaps.luau")
SERVICE_MODULE = module(ServerFolder, "ShelfCapService", "server/Services/ShelfCapService.luau")

-- Contrôles ---------------------------------------------------------------------------------------------
local total, failed = 0, 0
function check(ok, label)
	total += 1
	if ok then
		if VERBOSE then print("  ok   " .. label) end
	else
		failed += 1
		print("  ÉCHEC " .. label)
	end
end
function section(name) if VERBOSE then print("--- " .. name) end end
function summary(label)
	print(string.format("  %s : %d contrôles, %d raté(s)", label, total, failed))
	if VERBOSE then for _, l in LOG do print("    [" .. l.kind .. "] " .. l.text) end end
	RESULT_TOTAL, RESULT_FAILED = total, failed
end
