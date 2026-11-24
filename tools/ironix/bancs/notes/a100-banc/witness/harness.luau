-- Faux Roblox minimal et autonome du banc a100 (vague 30, L-111 : témoins et police). Vrais : WitnessService,
-- Shared/WitnessGauge, Config/Witness, Config/Zones, Contract (Animations, Find, Models, UI). Bouchons qui notent
-- leurs appels : AnimPlayer, MarkerSounds, Net, GuardService, WindowService. Le temps (os.clock) est NOW ; les
-- Humanoid avancent vers leur MoveTo à leur WalkSpeed dans advance().

NOW = 100
LOGS = {}
NOTIFIES = {}
SOUNDS = {}
CHASES = {}
ANIMS = {}
RNG_VALUE = 0.99 -- Random:NextNumber() : 0.99 = jamais de pause au point
SAFE_X = -100 -- zone safe : X < SAFE_X
POLICE_TEMPLATE = nil
OVERRIDE = {}
REFUSE = {}

-- Valeurs Roblox -------------------------------------------------------------------------------
local V = {}
local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
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
	if type(a) == "number" then
		return vec(a * b.X, a * b.Y, a * b.Z)
	end
	return vec(a.X * b, a.Y * b, a.Z * b)
end
V.__div = function(a, b)
	return vec(a.X / b, a.Y / b, a.Z / b)
end
V.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3 = { new = vec, zero = vec(0, 0, 0) }
local function frame(position, look)
	look = look or vec(0, 0, -1)
	return { Position = position, LookVector = look, RightVector = vec(-look.Z, 0, look.X) }
end
CFrame = {
	new = function(x, y, z)
		if type(x) == "number" then
			return frame(vec(x, y, z))
		end
		return frame(x)
	end,
	lookAt = function(from, to)
		return frame(from, (to - from).Unit)
	end,
}
Color3 = {
	fromHex = function(h)
		return { Hex = string.upper(h) }
	end,
	fromRGB = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				return enumName .. "." .. item
			end,
		})
	end,
})
FakeRandom = {
	new = function()
		return {
			NextNumber = function(_, a, b)
				if a == nil then
					return RNG_VALUE
				end
				return a + RNG_VALUE * (b - a)
			end,
			NextInteger = function(_, a, _b)
				return a
			end,
		}
	end,
}
fakeTask = {
	spawn = function(fn, ...)
		fn(...)
	end,
	defer = function(fn, ...)
		fn(...)
	end,
	delay = function() end,
}

-- Signaux --------------------------------------------------------------------------------------
function newSignal()
	local s = { _c = {} }
	function s:Connect(fn)
		table.insert(self._c, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in table.clone(self._c) do
			fn(...)
		end
	end
	return s
end

-- Instances ------------------------------------------------------------------------------------
local I = {}
local methods = {}
local CLASSES = { Model = "PVInstance", Part = "BasePart", MeshPart = "BasePart", BasePart = "PVInstance" }
local TAGGED = {}
I.__index = function(self, k)
	if k == "Parent" then
		return rawget(self, "_parent")
	end
	local m = methods[k]
	if m then
		return m
	end
	if type(k) == "string" then
		for _, child in rawget(self, "_children") do
			if child.Name == k then
				return child
			end
		end
	end
	return nil
end
I.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			local at = table.find(old._children, self)
			if at then
				table.remove(old._children, at)
			end
		end
		rawset(self, "_parent", v)
		if v then
			table.insert(v._children, self)
		end
		return
	end
	rawset(self, k, v)
end
function node(class, name, parent)
	local o = setmetatable({ ClassName = class, Name = name, _children = {}, _attrs = {}, _tags = {}, _writes = 0 }, I)
	if parent then
		o.Parent = parent
	end
	return o
end
function methods.IsA(self, c)
	local k = self.ClassName
	while k do
		if k == c then
			return true
		end
		k = CLASSES[k]
	end
	return c == "Instance"
end
function methods.GetChildren(self)
	return table.clone(self._children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(o)
		for _, child in o._children do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	for _, child in self._children do
		if child.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in self._children do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods.WaitForChild(self, name)
	return self:FindFirstChild(name)
end
function methods.FindFirstChildOfClass(self, class)
	for _, child in self._children do
		if child.ClassName == class then
			return child
		end
	end
	return nil
end
function methods.IsDescendantOf(self, other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods.GetFullName(self)
	local names = { self.Name }
	local p = self.Parent
	while p and p ~= game do
		table.insert(names, 1, p.Name)
		p = p.Parent
	end
	return table.concat(names, ".")
end
function methods.GetAttribute(self, k)
	return self._attrs[k]
end
function methods.SetAttribute(self, k, v)
	self._attrs[k] = v
	self._writes += 1
end
function methods.AddTag(self, t)
	self._tags[t] = true
	TAGGED[t] = TAGGED[t] or {}
	table.insert(TAGGED[t], self)
end
function methods.HasTag(self, t)
	return self._tags[t] == true
end
function methods.GetPivot(self)
	return frame(rawget(self, "_pivot") or rawget(self, "Position") or vec(0, 0, 0))
end
function methods.GetScale(self)
	return rawget(self, "_scale") or 1
end
function methods.SetNetworkOwner(self, owner)
	self._owner = if owner == nil then "server" else owner
end
function methods.SetStateEnabled(self, state, enabled)
	local states = rawget(self, "_states") or {}
	states[state] = enabled
	self._states = states
end
function methods.MoveTo(self, goal)
	self._goal = goal
	self._moves = (rawget(self, "_moves") or 0) + 1
end
function methods.Destroy(self)
	self.Parent = nil
end
InstanceAPI = {
	new = function(class)
		return node(class, class)
	end,
}
function tagged(t)
	return table.clone(TAGGED[t] or {})
end

-- Services -------------------------------------------------------------------------------------
game = node("DataModel", "game")
Workspace = node("Workspace", "Workspace", game)
function Workspace.GetServerTimeNow()
	return NOW + 1000
end
Players = node("Players", "Players", game)
Players.PlayerRemoving = newSignal()
ReplicatedStorage = node("ReplicatedStorage", "ReplicatedStorage", game)
CollectionService = {
	GetTagged = function(_, t)
		return table.clone(TAGGED[t] or {})
	end,
}
RunService = {
	Heartbeat = newSignal(),
	IsStudio = function()
		return true
	end,
}
local SERVICES = {
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	Workspace = Workspace,
	CollectionService = CollectionService,
}
function game.GetService(_, name)
	return assert(SERVICES[name], name)
end

-- Bouchons -------------------------------------------------------------------------------------
ANIM_PLAYERS = {} -- [modèle] = son faux AnimPlayer
local fakeAnimPlayer = {
	modelFolder = function(model)
		return model:FindFirstChild("Animations")
	end,
	new = function(animator, folder, specs, label)
		local model = animator.Parent.Parent
		local p = { model = model, folder = folder, specs = specs, label = label, playing = {}, speeds = {}, markers = {}, destroyed = false }
		local function note(name, action, speed)
			table.insert(ANIMS, { model = model, name = name, action = action, speed = speed, t = NOW })
		end
		function p:Play(name, _fade, _weight, speed)
			if not self.playing[name] then
				note(name, "Play", speed)
			end
			self.playing[name] = true
			self.speeds[name] = speed
			return nil
		end
		function p:Stop(name)
			if self.playing[name] then
				note(name, "Stop")
			end
			self.playing[name] = nil
		end
		function p:OnMarker(name, marker, fn)
			table.insert(self.markers, { name = name, marker = marker, fn = fn })
			return function() end
		end
		function p:Destroy()
			self.destroyed = true
		end
		ANIM_PLAYERS[model] = p
		return p
	end,
}
function fireMarker(model, name, marker)
	local count = 0
	for _, m in ANIM_PLAYERS[model].markers do
		if m.name == name and m.marker == marker then
			m.fn("")
			count += 1
		end
	end
	return count
end
function playing(model, name)
	return ANIM_PLAYERS[model].playing[name] == true
end
local fakeMarkerSounds = {
	play = function(name, at)
		table.insert(SOUNDS, { name = name, at = at, t = NOW })
		return nil
	end,
}
local fakeNet = {
	Server = setmetatable({}, {
		__index = function(_, name)
			return {
				Fire = function(_, player, ...)
					table.insert(NOTIFIES, { remote = name, player = player, args = { ... }, t = NOW })
				end,
			}
		end,
	}),
}
local fakeGuard = {
	FindGuardModel = function(name)
		if POLICE_TEMPLATE and POLICE_TEMPLATE.Name == name then
			return POLICE_TEMPLATE
		end
		return nil
	end,
	IsInSafeZone = function(position)
		return position.X < SAFE_X
	end,
	GetSpeedOverride = function(player, _zone)
		return OVERRIDE[player]
	end,
	StartDriverChase = function(chase)
		local model = nil
		if REFUSE[chase.Target] ~= true then
			model = node("Model", chase.Name, Workspace)
		end
		table.insert(CHASES, { chase = chase, model = model, t = NOW })
		return model
	end,
}
HIT, BROKEN = nil, nil
local fakeWindow = {
	OnHit = function(fn)
		HIT = fn
		return function() end
	end,
	OnBroken = function(fn)
		BROKEN = fn
		return function() end
	end,
}

-- Arbre des modules ----------------------------------------------------------------------------
local function module(name, parent, key, value)
	local m = node("ModuleScript", name, parent)
	m._key = key
	m._value = value
	return m
end
local Shared = node("Folder", "Shared", ReplicatedStorage)
local Config = node("Folder", "Config", Shared)
local Contract = node("Folder", "Contract", Shared)
local Anim = node("Folder", "Anim", Shared)
local NetFolder = node("Folder", "Net", Shared)
local Services = node("Folder", "Services", game)
for _, m in { "DeepFreeze", "Items", "Rarities", "Witness", "Zones" } do
	module(m, Config, "shared/Config/" .. m .. ".luau")
end
for _, m in { "Animations", "Find", "Models", "UI" } do
	module(m, Contract, "shared/Contract/" .. m .. ".luau")
end
module("WitnessGauge", Shared, "shared/WitnessGauge.luau")
module("AnimPlayer", Anim, nil, fakeAnimPlayer)
module("MarkerSounds", Anim, nil, fakeMarkerSounds)
module("Net", NetFolder, nil, fakeNet)
module("GuardService", Services, nil, fakeGuard)
module("WindowService", Services, nil, fakeWindow)
local witnessScript = module("WitnessService", Services, "server/Services/WitnessService.luau")

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
		workspace = Workspace,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = Enum,
		Instance = InstanceAPI,
		Random = FakeRandom,
		task = fakeTask,
		os = setmetatable({
			clock = function()
				return NOW
			end,
		}, { __index = os }),
		print = function(...)
			table.insert(LOGS, table.concat({ ... }, " "))
			if VERBOSE then
				print(...)
			end
		end,
		warn = function(...)
			table.insert(LOGS, "WARN " .. table.concat({ ... }, " "))
			if VERBOSE then
				print("WARN", ...)
			end
		end,
	}, { __index = getfenv(1) })
	setfenv(fn, env)
	local v = fn()
	cache[m] = v
	return v
end
function requireShared(path)
	local current = ReplicatedStorage
	for segment in string.gmatch(path, "[^%.]+") do
		current = current[segment]
	end
	return requireModule(current)
end
function loadWitness()
	local service = requireModule(witnessScript)
	service.Start()
	return service
end

-- Monde ----------------------------------------------------------------------------------------
HUMANOIDS = {}
function newWitness(name, parent, position, watched, options)
	options = options or {}
	local m = node("Model", name, parent)
	local hum = node("Humanoid", "Humanoid", m)
	hum.Health = 100
	hum.WalkSpeed = 16
	hum.HipHeight = 2
	if not options.noAnimator then
		node("Animator", "Animator", hum)
	end
	if not options.noRoot then
		local root = node("Part", "HumanoidRootPart", m)
		root.Position = position
		root.CFrame = CFrame.new(position)
		root.Size = vec(2, 2, 1)
		root.Anchored = false
		table.insert(HUMANOIDS, { humanoid = hum, root = root })
	end
	local head = node("Part", "Head", m)
	head.Anchored = true
	node("Folder", "Animations", m)
	if watched then
		m:SetAttribute("WatchedStore", watched)
	end
	m._writes = 0
	return m
end
function newStore(name, parent, zone, position)
	local s = node("Model", name, parent)
	s:SetAttribute("Zone", zone)
	s._pivot = position
	local window = node("Part", "Window", s)
	window.Position = position
	s:AddTag("NPCStore")
	return s
end
function newPaths(parent, points)
	local folder = node("Folder", "WitnessPaths", parent)
	local base = node("Part", "WitnessPathBase", folder)
	-- Posés dans le désordre : le code les trie par numéro.
	for index = #points, 1, -1 do
		local a = node("Attachment", string.format("WitnessPath_%02d", index), base)
		a.WorldPosition = points[index]
	end
	node("Attachment", "Autre", base).WorldPosition = vec(999, 0, 999)
	return folder
end
NEXT_ID = 1
function newPlayer(name, position)
	local p = node("Player", name, Players)
	p.UserId = NEXT_ID
	NEXT_ID += 1
	local ch = node("Model", name, Workspace)
	local hum = node("Humanoid", "Humanoid", ch)
	hum.Health = 100
	local root = node("Part", "HumanoidRootPart", ch)
	root.Position = position
	p.Character = ch
	return p
end
function removePlayer(p)
	p.Parent = nil
	Players.PlayerRemoving:Fire(p)
end
function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart")
end

-- Fait passer `seconds` s par pas de `dt` : les Humanoid avancent vers leur MoveTo, puis Heartbeat.
function advance(seconds, dt)
	dt = dt or 0.05
	local steps = math.floor(seconds / dt + 0.5)
	for _ = 1, steps do
		NOW += dt
		for _, h in HUMANOIDS do
			local goal = rawget(h.humanoid, "_goal")
			if goal and not rawget(h.humanoid, "_blocked") then
				local offset = vec(goal.X - h.root.Position.X, 0, goal.Z - h.root.Position.Z)
				local distance = offset.Magnitude
				local move = math.min(h.humanoid.WalkSpeed * dt, distance)
				if distance > 1e-6 then
					h.root.Position = h.root.Position + offset.Unit * move
				end
			end
		end
		RunService.Heartbeat:Fire(dt)
	end
end
function hit(player, store)
	HIT(player, store.Name, "NPC", store, 1)
end
function breakWindow(player, store)
	BROKEN({ WindowId = store.Name, Kind = "NPC", Model = store, Breaker = player, ImpactPoint = vec(0, 0, 0) })
end

-- Vérifications --------------------------------------------------------------------------------
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
function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end
function hasLog(pattern)
	for _, l in LOGS do
		if string.find(l, pattern, 1, true) then
			return true
		end
	end
	return false
end
function animEvents(model, name, action, since)
	local list = {}
	for _, e in ANIMS do
		if e.model == model and e.name == name and e.action == action and e.t >= (since or 0) then
			table.insert(list, e)
		end
	end
	return list
end
