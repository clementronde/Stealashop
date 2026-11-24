--!nocheck
-- Banc a130 (vague 39) : faux Roblox minimal pour VendorService (vrais VendorService, Config/Vendors, DeepFreeze,
-- Contract/Animations et Anim/AnimPlayer). Horloge et task.wait simulés ; Start tourne dans une coroutine.
CHECKS, FAILS = 0, 0
function check(cond, label)
	CHECKS += 1
	if cond then
		if VERBOSE then
			print("  ok " .. label)
		end
	else
		FAILS += 1
		print("  ÉCHEC " .. label)
	end
end
function section(name)
	if VERBOSE then
		print("--- " .. name)
	end
end
LOGS = {}
function hasLog(pattern)
	for _, l in LOGS do
		if string.find(l, pattern, 1, true) then
			return true
		end
	end
	return false
end
function warnCount()
	local n = 0
	for _, l in LOGS do
		if string.sub(l, 1, 5) == "WARN " then
			n += 1
		end
	end
	return n
end
NOW = 1000
STUDIO = true

-- Vector3 ------------------------------------------------------------------------------------
local V = {}
V.__index = V
Vector3 = {}
function Vector3.new(x, y, z)
	local v = setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
	v.Magnitude = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	return v
end
V.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.zero = Vector3.new(0, 0, 0)

-- Signaux --------------------------------------------------------------------------------------
function newSignal()
	local s = { fns = {} }
	function s:Connect(fn)
		local c = { fn = fn }
		table.insert(s.fns, c)
		function c:Disconnect()
			c.fn = nil
		end
		return c
	end
	function s:Fire(...)
		for _, c in table.clone(s.fns) do
			if c.fn then
				c.fn(...)
			end
		end
	end
	return s
end

-- Instances ------------------------------------------------------------------------------------
local M = {}
local I = {}
I.__index = function(o, k)
	local m = M[k]
	if m ~= nil then
		return m
	end
	local kids = rawget(o, "_children")
	if kids then
		for _, c in kids do
			if c.Name == k then
				return c
			end
		end
	end
	return nil
end
local CLASSES = {
	Model = { "Model", "PVInstance" },
	Part = { "Part", "BasePart", "PVInstance" },
}
function new(class, name, parent, props)
	local o = setmetatable({ ClassName = class, Name = name, _children = {}, Destroying = newSignal() }, I)
	for k, v in props or {} do
		o[k] = v
	end
	if parent then
		setParent(o, parent)
	end
	return o
end
function M.IsA(o, c)
	return table.find(CLASSES[o.ClassName] or { o.ClassName }, c) ~= nil or c == "Instance"
end
function M.FindFirstChild(o, name)
	for _, c in o._children do
		if c.Name == name then
			return c
		end
	end
	return nil
end
M.WaitForChild = M.FindFirstChild
function M.FindFirstChildOfClass(o, class)
	for _, c in o._children do
		if c.ClassName == class then
			return c
		end
	end
	return nil
end
function M.GetChildren(o)
	return table.clone(o._children)
end
function M.GetDescendants(o)
	local out = {}
	local function walk(n)
		for _, c in n._children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(o)
	return out
end
function M.IsDescendantOf(o, other)
	local p = rawget(o, "Parent")
	while p do
		if p == other then
			return true
		end
		p = rawget(p, "Parent")
	end
	return false
end
function M.GetFullName(o)
	local parts = {}
	local n = o
	while n and n ~= game do
		table.insert(parts, 1, n.Name)
		n = rawget(n, "Parent")
	end
	return table.concat(parts, ".")
end
function M.GetPivot(o)
	return { Position = rawget(o, "_pivot") or Vector3.zero }
end
function M.Destroy(o)
	o.Destroying:Fire()
	for _, c in table.clone(o._children) do
		M.Destroy(c)
	end
	setParent(o, nil)
end
function M.GetAttribute()
	return nil
end
function setParent(o, p)
	local old = rawget(o, "Parent")
	if old then
		local i = table.find(old._children, o)
		if i then
			table.remove(old._children, i)
		end
	end
	rawset(o, "Parent", p)
	if p then
		table.insert(p._children, o)
		if p == Workspace or M.IsDescendantOf(p, Workspace) then
			Workspace.DescendantAdded:Fire(o)
			for _, d in M.GetDescendants(o) do
				Workspace.DescendantAdded:Fire(d)
			end
		end
	end
end

-- Animator et pistes ---------------------------------------------------------------------------
TRACKS = {}
function M.LoadAnimation(animator, animation)
	local t = {
		Animation = animation,
		Name = animation.Name,
		IsPlaying = false,
		Looped = animation.Looped == true,
		Length = animation.Length or 2,
		TimePosition = 0,
		plays = 0,
		animator = animator,
	}
	function t:Play()
		t.IsPlaying = true
		t.startedAt = NOW
		t.plays += 1
	end
	function t:Stop()
		t.IsPlaying = false
	end
	function t:AdjustWeight() end
	function t:AdjustSpeed() end
	function t:GetMarkerReachedSignal()
		return newSignal()
	end
	table.insert(TRACKS, t)
	return t
end
function playsOf(model, name)
	local n = 0
	for _, t in TRACKS do
		if t.Name == name and t.animator:IsDescendantOf(model) then
			n += t.plays
		end
	end
	return n
end
function playing(model, name)
	for _, t in TRACKS do
		if t.Name == name and t.IsPlaying and t.animator:IsDescendantOf(model) then
			return true
		end
	end
	return false
end

-- Services -------------------------------------------------------------------------------------
game = new("DataModel", "game")
Workspace = new("Workspace", "Workspace")
Workspace.DescendantAdded = newSignal()
setParent(Workspace, game)
Players = new("Players", "Players", game)
PLAYERS = {}
function Players.GetPlayers()
	local r = {}
	for _, p in PLAYERS do
		if rawget(p, "Parent") == Players then
			table.insert(r, p)
		end
	end
	return r
end
ReplicatedStorage = new("ReplicatedStorage", "ReplicatedStorage", game)
local SERVICES = {
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	Workspace = Workspace,
	RunService = {
		IsStudio = function()
			return STUDIO
		end,
	},
	ContentProvider = { PreloadAsync = function() end },
}
function game.GetService(_, name)
	return assert(SERVICES[name], name)
end

-- Modules --------------------------------------------------------------------------------------
local Shared = new("Folder", "Shared", ReplicatedStorage)
local Config = new("Folder", "Config", Shared)
local Contract = new("Folder", "Contract", Shared)
local Anim = new("Folder", "Anim", Shared)
local Services = new("Folder", "Services", game)
local function module(name, parent, key)
	return new("ModuleScript", name, parent, { _key = key })
end
module("DeepFreeze", Config, "shared/Config/DeepFreeze.luau")
local vendorsConfig = module("Vendors", Config, "shared/Config/Vendors.luau")
module("Animations", Contract, "shared/Contract/Animations.luau")
module("AnimPlayer", Anim, "shared/Anim/AnimPlayer.luau")
local vendorScript = module("VendorService", Services, "server/Services/VendorService.luau")

-- task.wait simulé : la coroutine de Start attend jusqu'à NOW + dt.
local sleeping = {}
local fakeTask = {
	wait = function(dt)
		local co = coroutine.running()
		table.insert(sleeping, { co = co, at = NOW + (dt or 0) })
		return coroutine.yield()
	end,
}
local fakeOs = setmetatable({
	clock = function()
		return NOW
	end,
}, { __index = os })

local cache = {}
local function requireModule(m)
	if cache[m] ~= nil then
		return cache[m]
	end
	local fn = assert(loadstring(assert(SOURCES[m._key], m._key), m._key))
	setfenv(
		fn,
		setmetatable({
			script = m,
			require = requireModule,
			game = game,
			workspace = Workspace,
			Vector3 = Vector3,
			task = fakeTask,
			os = fakeOs,
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
	)
	local v = fn()
	cache[m] = v
	return v
end
function vendorsConfigValue()
	return requireModule(vendorsConfig)
end

function startVendors()
	local service = requireModule(vendorScript)
	service.Init()
	local co = coroutine.create(service.Start)
	local ok, err = coroutine.resume(co)
	assert(ok, err)
	return service
end

-- Avance l'horloge par pas de 0,05 s ; fin des pistes sans boucle après leur Length.
function advance(dt)
	local target = NOW + dt
	while NOW < target - 1e-9 do
		NOW = math.min(target, NOW + 0.05)
		for _, t in TRACKS do
			if t.IsPlaying and not t.Looped and NOW - t.startedAt >= t.Length then
				t.IsPlaying = false
			end
		end
		local ready = {}
		for i = #sleeping, 1, -1 do
			if sleeping[i].at <= NOW + 1e-9 then
				table.insert(ready, sleeping[i].co)
				table.remove(sleeping, i)
			end
		end
		for _, co in ready do
			local ok, err = coroutine.resume(co)
			assert(ok, err)
		end
	end
end

-- Décor ----------------------------------------------------------------------------------------
function addFolder(model, skipWave)
	local folder = new("Folder", "Animations", nil)
	new("Animation", "Idle", folder, { AnimationId = "rbxassetid://111", Looped = true })
	if not skipWave then
		new("Animation", "Wave", folder, { AnimationId = "rbxassetid://222", Length = 2 })
	end
	setParent(folder, model)
	return folder
end
-- Un vendeur simplifié : Model <name> (Head, Humanoid + Animator), dossier Animations facultatif.
function newVendor(name, position, parent, withFolder, withAnimator)
	local model = new("Model", name, nil, { _pivot = position })
	new("Part", "Head", model, { Position = position + Vector3.new(0, 4.5, 0) })
	local hum = new("Humanoid", "Humanoid", model, { Health = 100 })
	if withAnimator ~= false then
		new("Animator", "Animator", hum)
	end
	if withFolder then
		addFolder(model)
	end
	setParent(model, parent or Workspace)
	return model
end
function newPlayer(name, position)
	local p = new("Player", name, Players)
	table.insert(PLAYERS, p)
	local character = new("Model", name, Workspace)
	new("Humanoid", "Humanoid", character, { Health = 100 })
	new("Part", "HumanoidRootPart", character, { Position = position })
	p.Character = character
	return p
end
function moveTo(p, position)
	p.Character.HumanoidRootPart.Position = position
end
