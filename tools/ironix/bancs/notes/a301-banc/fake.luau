-- Banc a301 : petit faux Roblox, juste ce que lit ShopSpyController (CollectionService, Players, RunService,
-- Workspace, ReplicatedStorage/Shared/Config, Vector3, CFrame tourné autour de Y, instances en tables).

CHECKS, FAILS = 0, 0
function check(name: string, cond: any, detail: any?)
	CHECKS += 1
	if cond then
		if VERBOSE then
			print("ok " .. name)
		end
	else
		FAILS += 1
		print("ÉCHEC " .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end

-- Vector3 ----------------------------------------------------------------------------------------------------------
local V = {}
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	end
	return nil
end
local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V)
end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__div = function(a, n) return vec(a.X / n, a.Y / n, a.Z / n) end
V.__mul = function(a, n) return vec(a.X * n, a.Y * n, a.Z * n) end
Vector3 = { new = vec }
local function dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end

-- CFrame : position + rotation autour de Y (angle en radians) -------------------------------------------------------
local C = {}
C.__index = C
function C:PointToObjectSpace(p)
	local d = p - self.Position
	local c, s = math.cos(self.Yaw), math.sin(self.Yaw)
	local right = vec(c, 0, -s)
	local back = vec(s, 0, c)
	return vec(dot(d, right), d.Y, dot(d, back))
end
CFrame = {
	new = function(x, y, z, yaw)
		return setmetatable({ Position = vec(x, y, z), Yaw = yaw or 0 }, C)
	end,
}

-- Instances --------------------------------------------------------------------------------------------------------
local I = {}
I.__index = function(t, k)
	if I[k] ~= nil then
		return I[k]
	end
	local children = rawget(t, "_children")
	if children then
		for _, c in children do
			if c.Name == k then
				return c
			end
		end
	end
	return nil
end
local BASE_PARTS = { Part = true, MeshPart = true }
function new(class: string, name: string, parent: any?)
	local inst = setmetatable({ ClassName = class, Name = name, Parent = nil, _children = {}, _attrs = {} }, I)
	if parent then
		inst.Parent = parent
		table.insert(parent._children, inst)
	end
	return inst
end
function I:IsA(class)
	return self.ClassName == class or (class == "BasePart" and BASE_PARTS[self.ClassName] == true) or class == "Instance"
end
function I:FindFirstChild(name)
	for _, c in self._children do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function I:WaitForChild(name)
	local c = self:FindFirstChild(name)
	assert(c, "WaitForChild sans réponse : " .. name)
	return c
end
function I:GetChildren()
	return table.clone(self._children)
end
function I:IsDescendantOf(other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function I:GetAttribute(k) return self._attrs[k] end
function I:SetAttribute(k, v) self._attrs[k] = v end
function I:Remove()
	if self.Parent then
		local list = self.Parent._children
		for i, c in list do
			if c == self then
				table.remove(list, i)
				break
			end
		end
	end
	self.Parent = nil
end

-- Services ---------------------------------------------------------------------------------------------------------
local tags: { [any]: { [string]: boolean } } = {}
CollectionService = {
	GetTagged = function(_, tag)
		local list = {}
		for inst, set in tags do
			if set[tag] and inst.Parent ~= nil then
				table.insert(list, inst)
			end
		end
		return list
	end,
	HasTag = function(_, inst, tag) return tags[inst] ~= nil and tags[inst][tag] == true end,
}
function addTag(inst, tag)
	tags[inst] = tags[inst] or {}
	tags[inst][tag] = true
end
function removeTag(inst, tag)
	if tags[inst] then
		tags[inst][tag] = nil
	end
end

local beats = {}
RunService = { Heartbeat = { Connect = function(_, fn) table.insert(beats, fn) end } }
function step(dt: number)
	for _, fn in beats do
		fn(dt)
	end
end

local root = new("DataModel", "game")
Workspace = new("Workspace", "Workspace", root)
ReplicatedStorage = new("ReplicatedStorage", "ReplicatedStorage", root)
local shared = new("Folder", "Shared", ReplicatedStorage)
local config = new("Folder", "Config", shared)
for _, n in { "DeepFreeze", "Features", "ShopSpy" } do
	new("ModuleScript", n, config)._key = "Config/" .. n
end
LocalPlayer = { UserId = 1, Character = nil, Name = "Moi" }
Players = { LocalPlayer = LocalPlayer }

local services = {
	CollectionService = CollectionService,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	Workspace = Workspace,
}
game = { GetService = function(_, n) return assert(services[n], "service " .. n) end }

-- require : sources du dépôt (SOURCES[clé]) ; OVERRIDES[clé] remplace un module (interrupteur coupé).
OVERRIDES = {}
local cache = {}
function requireModule(m)
	local key = m._key
	if OVERRIDES[key] ~= nil then
		return OVERRIDES[key]
	end
	if cache[key] ~= nil then
		return cache[key]
	end
	local fn, err = loadstring(assert(SOURCES[key], "source absente " .. tostring(key)), key)
	assert(fn, err)
	setfenv(fn, setmetatable({ script = m, game = game, require = requireModule }, { __index = getfenv(1) }))
	local result = fn()
	cache[key] = result
	return result
end

-- Charge le contrôleur neuf (état neuf) et appelle Start.
function loadController()
	beats = {}
	local m = new("ModuleScript", "ShopSpyController")
	m._key = "Client/ShopSpyController"
	local fn, err = loadstring(SOURCES[m._key], m._key)
	assert(fn, err)
	setfenv(fn, setmetatable({ script = m, game = game, require = requireModule }, { __index = getfenv(1) }))
	local ctrl = fn()
	ctrl.Start()
	return ctrl
end

-- Boutique comme dans Studio (PLOT_Shop_03, 21/11) : Bounds 48 × 30 × 80 de centre (-106, 15, 29.5), la face
-- avant (la façade) à x = -66, tournée vers +X (la rue). DisplayItems avec des objets taggés DisplayItem et BB_Item.
function makePlot(name: string, owner: number?, zCenter: number)
	local plot = new("Model", name, Workspace)
	addTag(plot, "PlayerPlot")
	plot:SetAttribute("OwnerUserId", owner)
	local bounds = new("Part", "Bounds", plot)
	bounds.CFrame = CFrame.new(-106, 15, zCenter, -math.pi / 2) -- LookVector (1, 0, 0) : la taille X (48) suit Z, la taille Z (80) suit X
	bounds.Size = vec(48, 30, 80)
	new("Folder", "DisplayItems", plot)
	return plot
end
function addItem(plot, name: string, withBoard: boolean?)
	local model = new("Model", name, plot:FindFirstChild("DisplayItems"))
	addTag(model, "DisplayItem")
	if withBoard ~= false then
		local gui = new("BillboardGui", "BB_Item", model)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 160
	end
	return model
end
function board(model)
	return model:FindFirstChild("BB_Item")
end
function placeMe(x: number, y: number, z: number)
	local character = new("Model", "Moi", Workspace)
	local hrp = new("Part", "HumanoidRootPart", character)
	hrp.Position = vec(x, y, z)
	LocalPlayer.Character = character
end
function beatCount(): number
	return #beats
end
