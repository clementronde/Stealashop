-- Faux monde Roblox minimal pour exécuter AnimPlayer, MarkerSounds, AnimTest et
-- AnimationController hors Studio (banc d'essai de l'agent a09, pas livré).
-- SRC est défini avant ce fichier par run.sh (sources des modules).

local realOs = os
local now = 0
os = { clock = function() return now end, time = realOs.time, date = realOs.date }

LOG = {}
local realPrint = print
local VERBOSE = false
local function log(kind, ...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local line = table.concat(parts, " ")
	table.insert(LOG, { kind = kind, text = line })
	if VERBOSE then
		realPrint(`  [{kind}] {line}`)
	end
end
print = function(...) log("print", ...) end
warn = function(...) log("warn", ...) end

function setVerbose(v) VERBOSE = v end
function clearLog() LOG = {} end
function countLog(pattern, kind)
	local n = 0
	for _, e in LOG do
		if (kind == nil or e.kind == kind) and string.find(e.text, pattern, 1, true) then
			n += 1
		end
	end
	return n
end
function dumpLog()
	for _, e in LOG do
		realPrint(`    [{e.kind}] {e.text}`)
	end
end

-- Planificateur -----------------------------------------------------------------
local sleepers = {}
local tickers = {} -- objets mis à jour à chaque pas (pistes, sons)
local DT = 0.05

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		log("error", "ERREUR : " .. tostring(err))
		realPrint("ERREUR dans une tâche : " .. tostring(err))
	end
end

task = {}
function task.spawn(fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.wait(dt)
	local co = coroutine.running()
	table.insert(sleepers, { t = now + (dt or 0), co = co })
	coroutine.yield()
	return dt or 0
end
function task.defer(fn, ...)
	local co = coroutine.create(fn)
	local args = table.pack(...)
	table.insert(sleepers, { t = now, co = co, args = args })
end

local function tick()
	now += DT
	local snapshot = {}
	for obj in tickers do
		table.insert(snapshot, obj)
	end
	for _, obj in snapshot do
		if tickers[obj] then
			obj:_tick(DT)
		end
	end
	local ready = {}
	local keep = {}
	for _, s in sleepers do
		if s.t <= now then
			table.insert(ready, s)
		else
			table.insert(keep, s)
		end
	end
	sleepers = keep
	for _, s in ready do
		if coroutine.status(s.co) == "suspended" then
			if s.args then
				resume(s.co, table.unpack(s.args, 1, s.args.n))
			else
				resume(s.co)
			end
		end
	end
end

function runFor(seconds)
	local stop = now + seconds
	while now < stop - 1e-9 do
		tick()
	end
end

-- Lance `fn` dans une tâche et fait avancer le temps jusqu'à sa fin (ou `limit` s).
function runTask(fn, limit)
	local co = coroutine.create(fn)
	resume(co)
	local stop = now + (limit or 60)
	while coroutine.status(co) ~= "dead" and now < stop do
		tick()
	end
	return coroutine.status(co) == "dead"
end

-- Signaux -----------------------------------------------------------------------
Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ _conns = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { Connected = true, _fn = fn }
	function conn.Disconnect(c)
		c.Connected = false
	end
	table.insert(self._conns, conn)
	return conn
end
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function Signal:Fire(...)
	local list = table.clone(self._conns)
	for _, conn in list do
		if conn.Connected then
			task.spawn(conn._fn, ...)
		end
	end
	local alive = {}
	for _, conn in self._conns do
		if conn.Connected then
			table.insert(alive, conn)
		end
	end
	self._conns = alive
end
function Signal:Wait()
	local co = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		resume(co, ...)
	end)
	return coroutine.yield()
end
function Signal:count()
	local n = 0
	for _, c in self._conns do
		if c.Connected then
			n += 1
		end
	end
	return n
end

-- Enum, CFrame, Vector3 ---------------------------------------------------------
Enum = {
	AnimationPriority = { Idle = { Name = "Idle" }, Movement = { Name = "Movement" }, Action = { Name = "Action" }, Core = { Name = "Core" } },
	AssetFetchStatus = { Success = { Name = "Success" }, Failure = { Name = "Failure" } },
}
CFrame = { Angles = function(x, y, z) return { kind = "CFrame", x = x, y = y, z = z } end }
Vector3 = {}
function Vector3.new(x, y, z)
	x, y, z = x or 0, y or 0, z or 0
	return { X = x, Y = y, Z = z, Magnitude = math.sqrt(x * x + y * y + z * z) }
end

-- Instances ---------------------------------------------------------------------
local ISA = {
	Part = { BasePart = true, PVInstance = true },
	Model = { PVInstance = true },
	Folder = {},
	ModuleScript = { LuaSourceContainer = true },
	Animation = {},
	Animator = {},
	Humanoid = {},
	Sound = {},
	KeyframeSequence = { AnimationClip = true },
	Keyframe = {},
	Pose = { PoseBase = true },
	KeyframeMarker = {},
	AnimationTrack = {},
	DataModel = { ServiceProvider = true },
	Service = {},
	Player = {},
}

local Inst = {}
local methods = {}

local function rawNew(className, name)
	local data = {
		ClassName = className,
		Name = name or className,
		_children = {},
		_parent = nil,
		_attrs = {},
		_attrSignals = {},
		_destroyed = false,
		Destroying = Signal.new(),
		AncestryChanged = Signal.new(),
		ChildAdded = Signal.new(),
		Archivable = true,
	}
	return setmetatable(data, Inst)
end

Inst.__index = function(self, key)
	if key == "Parent" then
		return rawget(self, "_parent")
	end
	local m = methods[key]
	if m then
		return m
	end
	local getter = rawget(self, "_get_" .. key)
	if getter then
		return getter(self)
	end
	return nil
end
Inst.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "_parent")
		if old == value then
			return
		end
		if rawget(self, "_destroyed") and value ~= nil then
			error("The Parent property of " .. self.Name .. " is locked")
		end
		if old then
			local i = table.find(old._children, self)
			if i then
				table.remove(old._children, i)
			end
		end
		rawset(self, "_parent", value)
		if value then
			table.insert(value._children, self)
			value.ChildAdded:Fire(self)
		end
		self.AncestryChanged:Fire(self, value)
		return
	end
	rawset(self, key, value)
end
Inst.__tostring = function(self)
	return self.Name
end

function methods.GetChildren(self)
	return table.clone(self._children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(i)
		for _, c in i._children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	for _, c in self._children do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in self._children do
			local f = c:FindFirstChild(name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, class)
	for _, c in self._children do
		if c.ClassName == class then
			return c
		end
	end
	return nil
end
function methods.WaitForChild(self, name, timeout)
	local found = self:FindFirstChild(name)
	if found then
		return found
	end
	if timeout == nil then
		error(`WaitForChild infini sur {self:GetFullName()}.{name}`)
	end
	local stop = now + timeout
	while now < stop do
		task.wait(DT)
		found = self:FindFirstChild(name)
		if found then
			return found
		end
	end
	return nil
end
function methods.IsA(self, class)
	return self.ClassName == class or class == "Instance" or (ISA[self.ClassName] or {})[class] == true
end
function methods.IsDescendantOf(self, ancestor)
	local p = self.Parent
	while p do
		if p == ancestor then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods.GetFullName(self)
	local names = {}
	local i = self
	while i and i.ClassName ~= "DataModel" do
		table.insert(names, 1, i.Name)
		i = i.Parent
	end
	return table.concat(names, ".")
end
function methods.Destroy(self)
	if rawget(self, "_destroyed") then
		return
	end
	self.Destroying:Fire()
	for _, c in table.clone(self._children) do
		c:Destroy()
	end
	self.Parent = nil
	rawset(self, "_destroyed", true)
	tickers[self] = nil
end
function methods.Clone(self)
	local copy = rawNew(self.ClassName, self.Name)
	for k, v in pairs(self) do
		if type(k) == "string" and not string.match(k, "^_") and k ~= "Destroying" and k ~= "AncestryChanged" and k ~= "ChildAdded" then
			rawset(copy, k, v)
		end
	end
	for k, v in pairs(self) do
		if type(k) == "string" and string.match(k, "^_get_") then
			rawset(copy, k, v)
		end
	end
	local init = rawget(self, "_onClone")
	if init then
		init(copy)
	end
	for _, c in self._children do
		c:Clone().Parent = copy
	end
	return copy
end
function methods.GetAttribute(self, name)
	return self._attrs[name]
end
function methods.SetAttribute(self, name, value)
	self._attrs[name] = value
	local s = self._attrSignals[name]
	if s then
		s:Fire()
	end
end
function methods.GetAttributeChangedSignal(self, name)
	local s = self._attrSignals[name]
	if not s then
		s = Signal.new()
		self._attrSignals[name] = s
	end
	return s
end

-- Pistes d'animation ------------------------------------------------------------
ASSETS = {} -- [AnimationId] = { length, loop, markers = { { name, time, value } } }
local tempSequences = {}
local tempCount = 0

local function newTrack(animator, animation)
	local asset = ASSETS[animation.AnimationId] or tempSequences[animation.AnimationId]
	local track = rawNew("AnimationTrack", animation.Name)
	track.Animation = animation
	track.IsPlaying = false
	track.TimePosition = 0
	track.Length = if asset then asset.length else 0
	track.Looped = if asset then asset.loop else false
	track.Speed = 1
	track.WeightTarget = 1
	track.Stopped = Signal.new()
	track._asset = asset
	track._markerSignals = {}
	track._plays = 0
	function track.Play(t, fade, weight, speed)
		if t._asset == nil then
			return -- animation illisible : ne se joue pas
		end
		t._plays += 1
		t.IsPlaying = true
		t.TimePosition = 0
		if weight then
			t.WeightTarget = weight
		end
		if speed then
			t.Speed = speed
		end
		tickers[t] = true
	end
	function track.Stop(t, fade)
		if t.IsPlaying then
			t.IsPlaying = false
			tickers[t] = nil
			t.Stopped:Fire()
		end
	end
	function track.AdjustWeight(t, w)
		t.WeightTarget = w
	end
	function track.AdjustSpeed(t, s)
		t.Speed = s
	end
	function track.GetMarkerReachedSignal(t, name)
		local s = t._markerSignals[name]
		if not s then
			s = Signal.new()
			t._markerSignals[name] = s
		end
		return s
	end
	function track._tick(t, dt)
		if not t.IsPlaying then
			return
		end
		local before = t.TimePosition
		local after = before + dt * t.Speed
		for _, m in t._asset.markers do
			if (m.time > before or (before == 0 and m.time == 0)) and m.time <= after then
				local s = t._markerSignals[m.name]
				if s then
					s:Fire(m.value or "")
				end
			end
		end
		if after >= t.Length then
			if t.Looped then
				t.TimePosition = after - t.Length
			else
				t.TimePosition = t.Length
				t.IsPlaying = false
				tickers[t] = nil
				t.Stopped:Fire()
			end
		else
			t.TimePosition = after
		end
	end
	return track
end

-- Sons --------------------------------------------------------------------------
SOUND_LENGTH = { ["rbxasset://sounds/volume_slider.ogg"] = 0.2 }
SOUND_LOG = {}
local function soundTick(s, dt)
	s._age += dt
	local len = SOUND_LENGTH[s.SoundId or ""]
	if not s.IsLoaded and len and s._age >= 0.1 then
		s.IsLoaded = true
		s.TimeLength = len
	end
	if s.IsPlaying and s.IsLoaded then
		s._playAge = (s._playAge or 0) + dt
		if s._playAge >= s.TimeLength then
			s.IsPlaying = false
			s.Playing = false
			s.Ended:Fire()
		end
	end
end
local function setupSound(s)
	rawset(s, "_age", 0)
	rawset(s, "_tick", soundTick)
	rawset(s, "_played", 0)
	s.IsLoaded = false
	s.TimeLength = 0
	s.Playing = false
	s.IsPlaying = false
	s.Ended = Signal.new()
	tickers[s] = true
end
function methods.Play(self)
	if self.ClassName ~= "Sound" then
		error("Play sur " .. self.ClassName)
	end
	self.Playing = true
	self.IsPlaying = true
	rawset(self, "_played", self._played + 1)
	rawset(self, "_playAge", 0)
	table.insert(SOUND_LOG, { name = self.Name, parent = self.Parent and self.Parent.Name or "nil", sound = self })
end

-- Instance.new ------------------------------------------------------------------
Instance = {}
function Instance.new(className)
	local i = rawNew(className)
	if className == "Sound" then
		setupSound(i)
		rawset(i, "_onClone", setupSound)
		rawset(i, "SoundId", "")
	elseif className == "Animation" then
		rawset(i, "AnimationId", "")
	elseif className == "Keyframe" then
		rawset(i, "Time", 0)
		rawset(i, "AddMarker", function(k, marker)
			marker.Parent = k
		end)
	elseif className == "Pose" then
		rawset(i, "CFrame", nil)
	elseif className == "KeyframeSequence" then
		rawset(i, "Loop", true)
	elseif className == "Animator" then
		rawset(i, "_loads", 0)
		rawset(i, "LoadAnimation", function(a, animation)
			if not a:IsDescendantOf(game) then
				error("LoadAnimation requires the Animator object to be a descendant of the game object")
			end
			a._loads += 1
			return newTrack(a, animation)
		end)
	elseif className == "Humanoid" then
		rawset(i, "Running", Signal.new())
	elseif className == "Part" then
		rawset(i, "AssemblyLinearVelocity", Vector3.new(0, 0, 0))
	end
	return i
end

-- Monde -------------------------------------------------------------------------
local moduleCache = {}
local realRequire = require
require = function(inst)
	if type(inst) ~= "table" or inst.ClassName ~= "ModuleScript" then
		error("require : pas un ModuleScript")
	end
	local cached = moduleCache[inst]
	if cached ~= nil then
		return cached
	end
	local fn, err = loadstring(inst._source, "=" .. inst.Name)
	if not fn then
		error(err)
	end
	local previous = script
	script = inst
	local result = fn()
	script = previous
	moduleCache[inst] = result
	return result
end

local function module(parent, name, source)
	local m = rawNew("ModuleScript", name)
	rawset(m, "_source", source)
	m.Parent = parent
	return m
end

function newFolder(parent, name)
	local f = rawNew("Folder", name)
	f.Parent = parent
	return f
end

function addAnimation(folder, name, id, asset)
	local a = Instance.new("Animation")
	a.Name = name
	a.AnimationId = id
	a.Parent = folder
	if asset then
		ASSETS[id] = asset
	end
	return a
end

function addSound(folder, name, soundId)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = soundId
	s.Parent = folder
	return s
end

-- Personnage R15 minimal : Humanoid + Animator + HumanoidRootPart.
function newCharacter(name)
	local character = rawNew("Model", name or "Ironix")
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.Parent = character
	local animator = Instance.new("Animator")
	animator.Name = "Animator"
	animator.Parent = humanoid
	return character, humanoid, animator, hrp
end

-- Construit un DataModel neuf avec les modules ; `isClient` pour RunService:IsClient().
function newWorld(isClient)
	moduleCache = {}
	tickers = {}
	sleepers = {}
	ASSETS = {}
	tempSequences = {}
	SOUND_LOG = {}
	local dm = rawNew("DataModel", "Game")
	game = dm
	local services = {}
	local function service(name)
		local s = rawNew("Service", name)
		s.Parent = dm
		services[name] = s
		return s
	end
	local RS = service("ReplicatedStorage")
	local WS = service("Workspace")
	local Players = service("Players")
	local RunService = service("RunService")
	rawset(RunService, "IsStudio", function() return true end)
	rawset(RunService, "IsClient", function() return isClient end)
	local ContentProvider = service("ContentProvider")
	PRELOADED = {}
	rawset(ContentProvider, "PreloadAsync", function(_, list, cb)
		for _, inst in list do
			table.insert(PRELOADED, inst.Name)
			local status = if ASSETS[inst.AnimationId] then Enum.AssetFetchStatus.Success else Enum.AssetFetchStatus.Failure
			if cb then
				cb(inst.AnimationId, status)
			end
		end
	end)
	local Debris = service("Debris")
	rawset(Debris, "AddItem", function(_, inst, t)
		local co = coroutine.create(function()
			task.wait(t)
			inst:Destroy()
		end)
		resume(co)
	end)
	service("SoundService")
	local KSP = service("KeyframeSequenceProvider")
	rawset(KSP, "RegisterKeyframeSequence", function(_, seq)
		if KSP_REFUSE then
			error("RegisterKeyframeSequence refusé (bouchon)")
		end
		tempCount += 1
		local id = "rbxtemp://" .. tempCount
		local length, markers = 0, {}
		for _, frame in seq:GetChildren() do
			if frame.ClassName == "Keyframe" then
				length = math.max(length, frame.Time)
				for _, m in frame:GetChildren() do
					if m.ClassName == "KeyframeMarker" then
						table.insert(markers, { name = m.Name, time = frame.Time, value = m.Value })
					end
				end
			end
		end
		tempSequences[id] = { length = length, loop = seq.Loop, markers = markers }
		return id
	end)
	rawset(dm, "GetService", function(_, name)
		local s = services[name]
		if not s then
			error("service inconnu " .. name)
		end
		return s
	end)
	rawset(dm, "IsLoaded", function() return true end)
	rawset(dm, "Loaded", Signal.new())

	local player = rawNew("Player", "Ironix")
	player.Parent = Players
	rawset(player, "CharacterAdded", Signal.new())
	rawset(player, "CharacterRemoving", Signal.new())
	rawset(Players, "LocalPlayer", player)

	local shared = newFolder(RS, "Shared")
	local contract = newFolder(shared, "Contract")
	module(contract, "Animations", SRC["Contract/Animations"])
	local anim = newFolder(shared, "Anim")
	module(anim, "AnimPlayer", SRC["Anim/AnimPlayer"])
	module(anim, "MarkerSounds", SRC["Anim/MarkerSounds"])
	module(anim, "AnimTest", SRC["Anim/AnimTest"])
	local controller = rawNew("ModuleScript", "AnimationController")
	rawset(controller, "_source", SRC["AnimationController"])

	return {
		dm = dm,
		RS = RS,
		WS = WS,
		player = player,
		shared = shared,
		anim = anim,
		controllerModule = controller,
		require = function(path)
			return require(shared:FindFirstChild(path, true))
		end,
	}
end

-- Pose un personnage dans le Workspace et prévient comme Roblox.
function spawnCharacter(world, name)
	local old = world.player.Character
	if old then
		world.player.CharacterRemoving:Fire(old)
		old:Destroy()
	end
	local character, humanoid, animator, hrp = newCharacter(name)
	rawset(world.player, "Character", character)
	character.Parent = world.WS
	world.player.CharacterAdded:Fire(character)
	return character, humanoid, animator, hrp
end

-- Assertions --------------------------------------------------------------------
PASS, FAIL = 0, 0
function check(cond, label)
	if cond then
		PASS += 1
	else
		FAIL += 1
		realPrint("  ÉCHEC : " .. label)
	end
end
function section(name)
	realPrint("== " .. name)
end
function report()
	realPrint(`Résultat : {PASS} vérification(s) OK, {FAIL} échec(s)`)
end
realPrintFn = realPrint
