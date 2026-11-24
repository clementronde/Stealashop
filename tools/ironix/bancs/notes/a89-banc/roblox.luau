-- Banc a89 : suite du faux Roblox (après harness.luau : check, Vector3, CFrame).

-- typeof de Roblox : Vector3 reconnu.
local luauTypeof = typeof
function typeof(v)
	if type(v) == "table" and getmetatable(v) == getmetatable(Vector3.zero) then return "Vector3" end
	return luauTypeof(v)
end

-- Color3, Vector2, UDim2, Enum -------------------------------------------------------------------
local K = {}
local function col(r, g, b) return setmetatable({ R = r, G = g, B = b }, K) end
K.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
Color3 = {
	new = function(r, g, b) return col(r or 0, g or 0, b or 0) end,
	fromHex = function(h)
		h = h:gsub("#", "")
		return col(tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255)
	end,
}
Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
UDim2 = {
	new = function(sx, ox, sy, oy) return { X = { Scale = sx, Offset = ox }, Y = { Scale = sy, Offset = oy } } end,
	fromOffset = function(x, y) return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } } end,
	fromScale = function(x, y) return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } } end,
}
Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })

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

-- Instances -------------------------------------------------------------------------------------
local CLASS_PARENTS = {
	Part = { "BasePart" }, MeshPart = { "BasePart" }, PointLight = { "Light" }, SpotLight = { "Light" },
	Texture = { "Decal" }, BillboardGui = { "LayerCollector" }, ScreenGui = { "LayerCollector" },
	SurfaceGui = { "LayerCollector" }, Frame = { "GuiObject" }, TextLabel = { "GuiObject" },
	ImageLabel = { "GuiObject" }, TextButton = { "GuiObject", "GuiButton" },
}
local function partDefaults()
	return {
		CFrame = CFrame.new(), Transparency = 0, LocalTransparencyModifier = 0, Anchored = false,
		CanCollide = true, CanTouch = true, CanQuery = true,
	}
end
local DEFAULTS = {
	Part = partDefaults,
	MeshPart = partDefaults,
	Decal = function() return { LocalTransparencyModifier = 0 } end,
	Texture = function() return { LocalTransparencyModifier = 0 } end,
	ParticleEmitter = function() return { Enabled = true } end,
	PointLight = function() return { Enabled = true } end,
	Trail = function() return { Enabled = true } end,
	Beam = function() return { Enabled = true } end,
	BillboardGui = function() return { Enabled = true } end,
	Highlight = function() return { Enabled = true } end,
	ScreenGui = function() return { Enabled = true, IgnoreGuiInset = false } end,
	Humanoid = function() return { DisplayDistanceType = "HumanoidDisplayDistanceType.Viewer" } end,
	Frame = function() return { Visible = true, AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(0, 0) } end,
	TextLabel = function()
		return { Visible = true, Text = "", AbsolutePosition = Vector2.new(0, 0), AbsoluteSize = Vector2.new(0, 0) }
	end,
	ImageLabel = function() return { Visible = true, Image = "" } end,
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
	if self.ClassName == c or c == "Instance" then return true end
	for _, parent in CLASS_PARENTS[self.ClassName] or {} do
		if parent == c then return true end
	end
	return false
end
function I.FindFirstChild(self, name, recursive)
	for _, c in self._children do
		if c.Name == name then return c end
	end
	if recursive then
		for _, c in self._children do
			local found = I.FindFirstChild(c, name, true)
			if found then return found end
		end
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
function I.GetDescendants(self)
	local out = {}
	local function walk(inst)
		for _, c in inst._children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
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
function I.PivotTo(self, cf) self._p.Pivot = cf end
function I.GetBoundingBox(self) return self._p.BoxCF or I.GetPivot(self), self._p.BoxSize or Vector3.new(1, 1, 1) end
function I.GetScale(self) return self._p.Scale or 1 end
function I.ScaleTo(self, s) self._p.Scale = s end
function I.GetServerTimeNow() return SERVER_NOW end
function I.Destroy(self)
	self.Parent = nil
	rawset(self, "_destroyed", true)
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

local function setParent(self, parent)
	local old = rawget(self, "_parent")
	if old == parent then return end
	if old then
		local list = old._children
		for i, c in list do if c == self then table.remove(list, i) break end end
	end
	rawset(self, "_parent", parent)
	if parent then
		table.insert(parent._children, self)
		local a = parent
		while a do
			local s = rawget(a, "_descAdded")
			if s then s:Fire(self) end
			a = rawget(a, "_parent")
		end
	end
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
		self._p[k] = v
	end,
}
function newInst(class, name, parent)
	local o = setmetatable({
		ClassName = class, Name = name, _children = {}, _attrs = {}, _attrSignals = {},
		_p = if DEFAULTS[class] then DEFAULTS[class]() else {},
	}, META)
	if parent then o.Parent = parent end
	return o
end
function setp(inst, k, v) inst._p[k] = v end
Instance = { new = function(class) return newInst(class, class) end }

SERVER_NOW = 1000
workspace = newInst("Workspace", "Workspace")
workspace._p.CurrentCamera = { CFrame = CFrame.new(0, 10, 0), ViewportSize = Vector2.new(1200, 800) }

-- Players ---------------------------------------------------------------------------------------
local PLAYERS = {}
Players = { GetPlayers = function() return table.clone(PLAYERS) end }
function newCharacter(player, at)
	local character = newInst("Model", "Char" .. player.UserId, workspace)
	local root = newInst("Part", "HumanoidRootPart", character)
	setp(root, "CFrame", CFrame.new(at or Vector3.new(0, 3, 0)))
	setp(root, "Transparency", 1)
	player._p.Character = character
	return character
end
function newPlayer(userId)
	local player = newInst("Player", "Player" .. userId)
	player._p.UserId = userId
	newInst("PlayerGui", "PlayerGui", player)
	newCharacter(player)
	table.insert(PLAYERS, player)
	return player
end
function removePlayer(player)
	for i, p in PLAYERS do if p == player then table.remove(PLAYERS, i) break end end
end
Players.LocalPlayer = newPlayer(1)

HEARTBEAT = newSignal()
RunService = { Heartbeat = HEARTBEAT, IsStudio = function() return true end }

-- ReplicatedStorage : Shared (vrais modules Config et Contract/Find, faux Net), Assets/Potions --------
ReplicatedStorage = newInst("ReplicatedStorage", "ReplicatedStorage")
local shared = newInst("Folder", "Shared", ReplicatedStorage)
local config = newInst("Folder", "Config", shared)
local contract = newInst("Folder", "Contract", shared)
local netFolder = newInst("Folder", "Net", shared)
local LOADED = {}
function require(module)
	local value = rawget(module, "_value")
	if value ~= nil then return value end
	if LOADED[module] == nil then
		local fn = assert(loadstring(assert(rawget(module, "_source"), "pas de source : " .. module.Name), module.Name))
		setfenv(fn, setmetatable({ script = module }, { __index = getfenv(1) }))
		LOADED[module] = fn()
	end
	return LOADED[module]
end
local function moduleWith(name, parent, key, value)
	local m = newInst("ModuleScript", name, parent)
	rawset(m, key, value)
	return m
end
for _, name in { "DeepFreeze", "Music", "Settings", "Potions" } do
	moduleWith(name, config, "_source", SOURCES["shared/Config/" .. name .. ".luau"])
end
moduleWith("Find", contract, "_source", SOURCES["shared/Contract/Find.luau"])

-- Faux Net : le serveur est simulé par les tests (NET.Client.PotionSpawned:Fire…), PickPotion noté dans PICKS.
PICKS = {}
NET = {
	Client = {
		PotionSpawned = newSignal(),
		PotionRemoved = newSignal(),
		PickPotion = { Fire = function(_, uid) table.insert(PICKS, uid) end },
	},
}
moduleWith("Net", netFolder, "_value", NET)

local assets = newInst("Folder", "Assets", ReplicatedStorage)
POTION_FOLDER = newInst("Folder", "Potions", assets)

-- Contrôleurs voisins simulés : ItemIdleController.ModelMotion et UI/Motion.PlaySound.
SOUNDS = {}
CONTROLLERS = newInst("Folder", "Controllers")
IDLE_STUB = {
	ModelMotion = function(mode, t)
		if mode == "SpinBob" then return 0.5, 0.1 end
		return 0, 0
	end,
}
moduleWith("ItemIdleController", CONTROLLERS, "_value", IDLE_STUB)
local ui = newInst("Folder", "UI", CONTROLLERS)
moduleWith("Motion", ui, "_value", { PlaySound = function(name) table.insert(SOUNDS, name) end })

local SERVICES = {
	Players = Players, RunService = RunService, ReplicatedStorage = ReplicatedStorage, Workspace = workspace,
}
game = { GetService = function(_, name) return assert(SERVICES[name], name) end }

PRINTS = {}
function warn(...)
	print("ERREUR warn :", ...)
end
function loadController(source)
	local fn = assert(loadstring(source, "PotionController"))
	local scriptInst = newInst("ModuleScript", "PotionController", CONTROLLERS)
	setfenv(fn, setmetatable({
		script = scriptInst,
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
			table.insert(PRINTS, table.concat(parts, " "))
		end,
	}, { __index = getfenv(1) }))
	return fn()
end

-- Avance de dt secondes en n images (heure serveur comprise).
function tick(dt, n)
	for _ = 1, (n or 1) do
		SERVER_NOW += dt
		HEARTBEAT:Fire(dt)
	end
end
