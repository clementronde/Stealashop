-- Faux Roblox minimal et autonome du banc a98 (vague 29, panel admin) : vrais AdminService, Config/Admin,
-- AdminLists, configs lues, Format, Net/Definitions et Net/Validate ; tous les autres services sont des bouchons
-- qui notent leurs appels. Variables globales lues par les tests : CALLS, REPLIES, DATA, LOGS.

LOGS = {}
CALLS = {}
REPLIES = {}
DATA = {}
STUDIO = true
DEFERRED = {}

local function note(name, ...)
	table.insert(CALLS, { name = name, args = { ... } })
end
function called(name)
	local list = {}
	for _, c in CALLS do
		if c.name == name then
			table.insert(list, c)
		end
	end
	return list
end

-- Valeurs Roblox -------------------------------------------------------------------
local V = {}
local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__index = function(_, k)
	return nil
end
V.__add = function(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V.__sub = function(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V.__div = function(a, b)
	return vec(a.X / b, a.Y / b, a.Z / b)
end
V.__mul = function(a, b)
	return vec(a.X * b, a.Y * b, a.Z * b)
end
Vector3 = { new = vec, zero = vec(0, 0, 0) }
CFrame = {
	new = function(p)
		return { Position = p }
	end,
}
Color3 = {
	fromRGB = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
	fromHex = function(h)
		return { Hex = h }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
local function enumOf(names)
	local e = {}
	for _, n in names do
		e[n] = { Name = n }
	end
	return e
end
Enum = {
	RaycastFilterType = enumOf({ "Exclude", "Include" }),
	CreatorType = enumOf({ "User", "Group" }),
	AnalyticsEconomyFlowType = enumOf({ "Source", "Sink" }),
	AnalyticsEconomyTransactionType = setmetatable({}, {
		__index = function(_, k)
			return { Name = k }
		end,
	}),
}
RaycastParams = {
	new = function()
		return {}
	end,
}
FakeRandom = {
	new = function()
		return {
			NextInteger = function(_, a, b)
				return math.random(a, b)
			end,
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return a + math.random() * (b - a)
			end,
		}
	end,
}
fakeTask = {
	spawn = function(fn, ...)
		fn(...)
	end,
	defer = function(fn, ...)
		table.insert(DEFERRED, { fn = fn, args = { ... } })
	end,
	delay = function() end,
}
function flush()
	while #DEFERRED > 0 do
		local item = table.remove(DEFERRED, 1)
		item.fn(table.unpack(item.args))
	end
end

-- Signaux ----------------------------------------------------------------------------
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

-- Instances ----------------------------------------------------------------------------
local I = {}
local methods = {}
local CLASSES = { Model = "PVInstance", Part = "PVInstance" }
I.__index = function(self, k)
	local m = methods[k]
	if m then
		return m
	end
	local children = rawget(self, "_children")
	if children and type(k) == "string" then
		return children[k]
	end
	return nil
end
function node(class, name, parent)
	local o = setmetatable({ ClassName = class, Name = name, _children = {}, _attrs = {}, _tags = {} }, I)
	if parent then
		o.Parent = parent
		parent._children[name] = o
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
function methods.GetAttribute(self, k)
	return self._attrs[k]
end
function methods.SetAttribute(self, k, v)
	self._attrs[k] = v
end
function methods.FindFirstChild(self, name)
	return self._children[name]
end
function methods.IsDescendantOf(self, other)
	local p = rawget(self, "Parent")
	while p do
		if p == other then
			return true
		end
		p = rawget(p, "Parent")
	end
	return false
end
function methods.GetPivot(self)
	return { Position = self._pivot }
end
function methods.PivotTo(self, cf)
	self._pivotTo = cf.Position
end
function methods.Kick(self, message)
	self._kicked = message
end
function methods.GetRankInGroup(self, group)
	note("GetRankInGroup", self, group)
	return RANKS[self.Name] or 0
end
function realTypeof(v)
	if type(v) == "table" and getmetatable(v) == I then
		return "Instance"
	end
	return typeof(v)
end

-- Services -----------------------------------------------------------------------------
game = node("DataModel", "game")
game.CreatorType = Enum.CreatorType.Group
game.CreatorId = 777
RANKS = {}
Workspace = node("Workspace", "Workspace", game)
function Workspace.Raycast()
	return nil
end
Players = node("Players", "Players", game)
Players.PlayerAdded = newSignal()
Players.PlayerRemoving = newSignal()
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
ReplicatedStorage = node("ReplicatedStorage", "ReplicatedStorage", game)
local TAGGED = {}
CollectionService = {
	GetTagged = function(_, tag)
		return TAGGED[tag] or {}
	end,
}
function tag(o, t)
	TAGGED[t] = TAGGED[t] or {}
	table.insert(TAGGED[t], o)
end
local guid = 0
HttpService = {
	GenerateGUID = function()
		guid += 1
		return "uid-" .. guid
	end,
}
RunService = {
	IsStudio = function()
		return STUDIO
	end,
}
local SERVICES = {
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	Workspace = Workspace,
	CollectionService = CollectionService,
	HttpService = HttpService,
}
function game.GetService(_, name)
	return assert(SERVICES[name], name)
end

-- Arbre des modules ---------------------------------------------------------------------
local function module(name, parent, key, value)
	local m = node("ModuleScript", name, parent)
	m._key = key
	m._value = value
	return m
end
local Shared = node("Folder", "Shared", ReplicatedStorage)
local Config = node("Folder", "Config", Shared)
local NetFolder = node("Folder", "Net", Shared)
local Types = node("Folder", "Types", Shared)
local Services = node("Folder", "Services", game)
for _, m in { "Admin", "Balance", "Cosmetics", "DeepFreeze", "Features", "Items", "Monetization", "Mutations", "Potions", "Rarities", "SkillTree", "Unbox", "Upgrades", "Zones" } do
	module(m, Config, "shared/Config/" .. m .. ".luau")
end
module("AdminLists", Shared, "shared/AdminLists.luau")
module("Format", Shared, "shared/Format.luau")
module("Profile", Types, "shared/Types/Profile.luau")
module("Definitions", NetFolder, "shared/Net/Definitions.luau")
module("Validate", NetFolder, "shared/Net/Validate.luau")

-- Faux Net : les arguments passent par le vrai Validate avec la vraie définition.
HANDLERS = {}
local fakeNet = {
	Server = setmetatable({}, {
		__index = function(_, name)
			return {
				Connect = function(_, fn)
					HANDLERS[name] = fn
				end,
				Fire = function(_, player, ...)
					if name == "AdminResult" then
						table.insert(REPLIES, { player = player, args = { ... } })
					end
				end,
			}
		end,
	}),
}
module("Net", NetFolder, nil, fakeNet)

FEATURE_ROBUX = false
local stubs = {
	AntiCheatService = {
		Allow = function(p, s, r)
			note("Allow", p, s, r)
		end,
	},
	CosmeticService = {
		Grant = function(p, id)
			note("Grant", p, id)
			return DATA[p] ~= nil
		end,
		Equip = function(p, id)
			note("Equip", p, id)
			return true
		end,
	},
	DataService = {
		Get = function(p)
			return DATA[p]
		end,
		AddCash = function(p, n)
			local d = DATA[p]
			if d == nil then
				return nil
			end
			d.Cash += n
			return d.Cash
		end,
		NewData = function()
			return { Version = 8, Cash = 0, Stats = { Speed = 0, Strength = 0 }, Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 }, Items = {}, Boxes = {}, Purchases = {}, Monetization = { Passes = {}, StarterPack = false, OpenNowCredit = 0 } }
		end,
		OnProfileReleasing = function(fn)
			RELEASING = fn
		end,
	},
	DisplayService = {
		HasInventoryRoom = function(p)
			return not FULL[p]
		end,
	},
	IndexService = {
		Discover = function(p, id)
			note("Discover", p, id)
			return true
		end,
	},
	InventoryService = {
		Refresh = function(p)
			note("InventoryRefresh", p)
		end,
	},
	MachineVariantService = {
		Refresh = function(plot)
			note("VariantRefresh", plot)
		end,
	},
	MonetizationService = {
		IsEnabled = function()
			return FEATURE_ROBUX
		end,
	},
	NightCycleService = {
		SkipTo = function(t, d)
			note("SkipTo", t, d)
			return STUDIO
		end,
	},
	PlotService = {
		GetPlot = function(p)
			return PLOTS[p]
		end,
		TeleportHome = function(p)
			note("TeleportHome", p)
			return true
		end,
	},
	RayonService = {
		Refresh = function(plot)
			note("RayonRefresh", plot)
		end,
	},
	ShopService = {
		RefreshPlayer = function(p)
			note("ShopRefresh", p)
		end,
	},
	StatsService = {
		AddSpeed = function(p, n)
			local d = DATA[p]
			if d == nil then
				return nil
			end
			d.Stats.Speed += n
			return d.Stats.Speed
		end,
		AddStrength = function(p, n)
			local d = DATA[p]
			if d == nil then
				return nil
			end
			d.Stats.Strength += n
			return d.Stats.Strength
		end,
	},
	TelemetryService = {
		LogEvent = function(p, key, fields)
			note("Telemetry", p, key, fields)
			return true
		end,
	},
	UnboxService = {
		Refresh = function(p)
			note("UnboxRefresh", p)
		end,
	},
	-- Ajout pur d'a130 (2026-11-14, vague 39) : AdminService requiert FortuneTowerService (StartEvent Fortune…).
	FortuneTowerService = {
		Force = function(action)
			note("FortuneForce", action)
			return FORTUNE_OK ~= false, "Fortune " .. tostring(action)
		end,
	},
}
for name, value in stubs do
	module(name, Services, nil, value)
end
local adminScript = module("AdminService", Services, "server/Services/AdminService.luau")
FULL = {}
PLOTS = {}

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
		RaycastParams = RaycastParams,
		Random = FakeRandom,
		task = fakeTask,
		typeof = realTypeof,
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
function loadAdmin()
	cache[adminScript] = nil
	HANDLERS = {}
	local service = requireModule(adminScript)
	service.Init()
	service.Start()
	return service
end
function requireShared(path)
	local current = ReplicatedStorage
	for segment in string.gmatch(path, "[^%.]+") do
		current = current[segment]
	end
	return requireModule(current)
end

-- Monde ------------------------------------------------------------------------------------
NEXT_ID = 1
function newPlayer(name)
	local p = node("Player", name, Players)
	p.UserId = NEXT_ID
	NEXT_ID += 1
	local ch = node("Model", name, Workspace)
	node("Part", "HumanoidRootPart", ch)
	p.Character = ch
	table.insert(PLAYERS, p)
	DATA[p] = {
		Version = 8,
		Cash = 0,
		Stats = { Speed = 0, Strength = 0 },
		Upgrades = { Treadmill = 0, Bench = 0, DisplaySlots = 0, UnboxBenches = 0 },
		Items = {},
		Boxes = {},
		Purchases = { ["p-1"] = 123 },
		Monetization = { Passes = { VIP = true }, StarterPack = true, OpenNowCredit = 0 },
		Index = { X = 1 },
	}
	Players.PlayerAdded:Fire(p)
	return p
end
function removePlayer(p)
	p.Parent = nil
	Players.PlayerRemoving:Fire(p)
end
local map = node("Folder", "Map", Workspace)
local inbox = node("Folder", "_INBOX_CLEMENT", Workspace)
function newStore(zone, x, z, inInbox)
	local s = node("Model", "STORE_" .. zone .. "_" .. x, if inInbox then inbox else map)
	s:SetAttribute("Zone", zone)
	s._pivot = vec(x, 10, z)
	tag(s, "NPCStore")
	return s
end

-- Appel par la remote : forme contrôlée par le vrai Validate, puis le service.
local Definitions = requireShared("Shared.Net.Definitions")
local Validate = requireShared("Shared.Net.Validate")
function defOf(name)
	for _, def in Definitions.List do
		if def.Name == name then
			return def
		end
	end
	return nil
end
function fire(player, ...)
	local reason = Validate.check(defOf("AdminCommand").Args, ...)
	if reason then
		return reason
	end
	HANDLERS.AdminCommand(player, ...)
	flush()
	return nil
end
function lastReply()
	local r = REPLIES[#REPLIES]
	return if r then r.args else nil
end

-- Vérifications -------------------------------------------------------------------------------
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
function hasLog(pattern)
	for _, l in LOGS do
		if string.find(l, pattern, 1, true) then
			return true
		end
	end
	return false
end
