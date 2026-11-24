--!nocheck
-- Banc a164 : faux Roblox minimal, chargeur des vrais modules de Shared/Config, faux services voisins de
-- RebirthService. Lu après SOURCES et SCENARIO (run.sh), avant server.luau.

checks, fails = 0, 0
function check(ok, label)
	checks += 1
	if not ok then
		fails += 1
		print("ÉCHEC " .. label)
	elseif VERBOSE then
		print("ok " .. label)
	end
end

Color3 = {
	fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
	fromHex = function(hex) return { Hex = hex } end,
	new = function(r, g, b) return { R = r, G = g, B = b } end,
}
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }

---------------------------------------------------------------- outils
function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[deepCopy(k)] = deepCopy(v)
	end
	return out
end
function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b or (a ~= a and b ~= b)
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() table.remove(handlers, table.find(handlers, fn) or 0) end }
		end,
		Fire = function(_, ...)
			for _, fn in table.clone(handlers) do
				fn(...)
			end
		end,
	}
end

---------------------------------------------------------------- faux Roblox
IS_STUDIO = false
WARNS = {}
local function makeAttributes(obj)
	local attrs, signals = {}, {}
	obj.SetAttribute = function(_, k, v)
		local old = attrs[k]
		attrs[k] = v
		if old ~= v and signals[k] then
			signals[k]:Fire()
		end
	end
	obj.GetAttribute = function(_, k) return attrs[k] end
	obj.GetAttributeChangedSignal = function(_, k)
		signals[k] = signals[k] or signal()
		return signals[k]
	end
	return obj
end
function newPlayer(name, userId)
	return makeAttributes({ Name = name, DisplayName = name, UserId = userId, Parent = "Players" })
end
P1 = newPlayer("Ada", 101)
P2 = newPlayer("Bob", 102)
PLAYERS = { P1, P2 }
Workspace = makeAttributes({ Name = "Workspace" })
local guid = 0
local services = {
	Players = { GetPlayers = function() return table.clone(PLAYERS) end, PlayerRemoving = signal(), PlayerAdded = signal() },
	RunService = { IsStudio = function() return IS_STUDIO end },
	Workspace = Workspace,
	HttpService = { GenerateGUID = function() guid += 1; return `guid-{guid}` end },
}

---------------------------------------------------------------- chargeur de Shared
PATCHES = {} -- [chemin] = function(source) -> source modifiée
local RefMT = {}
local function ref(path)
	return setmetatable({ __path = path }, RefMT)
end
RefMT.__index = function(self, key)
	local path = rawget(self, "__path")
	if key == "Parent" then
		return ref((string.gsub(path, "/?[^/]*$", "")))
	end
	return ref(if path == "" then key else path .. "/" .. key)
end
local loaded = {}
NET = {}
function charge(path)
	if path == "Net/Net" then
		return NET
	end
	if loaded[path] ~= nil then
		return loaded[path]
	end
	local source = SOURCES[path]
	assert(source, `module absent : {path}`)
	if PATCHES[path] then
		source = PATCHES[path](source)
	end
	local chunk, problem = loadstring(source, "=" .. path)
	assert(chunk, `{path} ne compile pas : {problem}`)
	setfenv(chunk, setmetatable({
		script = ref(path),
		require = function(target) return charge(rawget(target, "__path")) end,
	}, { __index = getfenv(0) }))
	local result = chunk()
	loaded[path] = result
	return result
end
function patchFeatures(rebirthOn)
	loaded["Config/Features"] = nil -- a210 (vague 63) : Config/Cosmetics requiert Features, parfois chargé avant ce correctif
	PATCHES["Config/Features"] = function(source)
		if rebirthOn then
			local out, n = string.gsub(source, "\tRebirth = false,", "\tRebirth = true,")
			assert(n == 1, "Features : ligne Rebirth = false introuvable")
			return out
		end
		return source
	end
end

---------------------------------------------------------------- faux services
DATA = {}
SAVES = {}
REGISTER = {}
HELD = {}
CARRYING = {}
NOTES = {}
CALLS = {}
TELEMETRY = {}
DISCOVERED = {}
SPEND_SNAPSHOT = nil
local function call(name)
	CALLS[name] = (CALLS[name] or 0) + 1
end
local loadedListeners = {}
FAKES = {}
FAKES.DataService = {
	Get = function(p) return DATA[p] end,
	SpendCash = function(p, amount)
		local d = DATA[p]
		if d == nil or amount < 0 or d.Cash < amount then
			return false
		end
		SPEND_SNAPSHOT = { Rebirths = d.Rebirths, Items = count(d.Items), Equipped = d.Tools.Equipped, Speed = d.Stats.Speed }
		d.Cash -= amount
		p:SetAttribute("Cash", d.Cash)
		return true
	end,
	OnProfileLoaded = function(fn)
		table.insert(loadedListeners, fn)
		for p in DATA do
			fn(p)
		end
	end,
	Save = function(p)
		SAVES[p] = (SAVES[p] or 0) + 1
		return true
	end,
}
FAKES.DisplayService = {
	GetIncomeMultiplier = function() return 1 end,
	IsHeld = function(_, uid) return HELD[uid] == true end,
	GetRegister = function(p) return REGISTER[p] or 0 end,
	CashOut = function(p)
		call("CashOut")
		local amount = REGISTER[p] or 0
		REGISTER[p] = 0
		DATA[p].Cash += amount
		return amount
	end,
	PlaceAuto = function(p, uid)
		call("PlaceAuto")
		local d = DATA[p]
		for n = 1, 4 do
			if d.Display[tostring(n)] == nil then
				d.Display[tostring(n)] = uid
				return n
			end
		end
		return nil
	end,
}
FAKES.TrainingService = { GetGainMultiplier = function() return 1 end, Stop = function() call("Train.Stop") end }
FAKES.PvPService = { GetVaultSlots = function() return 1 end }
FAKES.CarryService = { IsCarrying = function(p) return CARRYING[p] == true end }
FAKES.CosmeticService = { Refresh = function() call("Cosmetic.Refresh") end }
FAKES.StatsService = { Refresh = function() call("Stats.Refresh") end }
FAKES.ToolService = {
	Equip = function(p, id)
		call("Tool.Equip:" .. id)
		DATA[p].Tools.Equipped = id
		return true
	end,
	RefreshDamage = function() call("Tool.RefreshDamage") end,
}
FAKES.ShopService = { RefreshPlayer = function() call("Shop.Refresh") end }
FAKES.UnboxService = { Refresh = function() call("Unbox.Refresh") end }
PLOT = { Name = "Plot1" }
FAKES.PlotService = { GetPlot = function() return PLOT end }
FAKES.MachineVariantService = { Refresh = function() call("Machine.Refresh") end }
FAKES.RayonService = { Refresh = function() call("Rayon.Refresh") end }
FAKES.InventoryService = { Refresh = function() call("Inventory.Refresh") end }
FAKES.IndexService = { Discover = function(_, id) table.insert(DISCOVERED, id); return true end }
FAKES.HeldItemService = { Stow = function() call("Held.Stow") end }
FAKES.TelemetryService = {
	LogEconomy = function(_, kind, amount, sku) table.insert(TELEMETRY, { "Economy", kind, amount, sku }); return true end,
	LogEvent = function(_, key, fields, value) table.insert(TELEMETRY, { "Event", key, fields, value }); return true end,
}
REBIRTH_HANDLER = nil
NET.Server = {
	Rebirth = { Connect = function(_, fn) REBIRTH_HANDLER = fn; return { Disconnect = function() end } end },
	Notify = { Fire = function(_, p, message, kind) table.insert(NOTES, { p, message, kind }) end },
}
function notesFor(p)
	local list = {}
	for _, n in NOTES do
		if n[1] == p then
			table.insert(list, n)
		end
	end
	return list
end
function lastNote(p)
	local list = notesFor(p)
	return list[#list]
end

-- Charge le vrai RebirthService (après les PATCHES et les accroches de base voulues).
function loadRebirthService()
	local fakeScript = { Name = "RebirthService", Parent = FAKES }
	local env = setmetatable({
		game = { GetService = function(_, n) return services[n] end },
		script = fakeScript,
		require = function(target)
			local path = rawget(target, "__path")
			if path ~= nil then
				return charge(path)
			end
			return target
		end,
		warn = function(...) table.insert(WARNS, table.concat({ ... }, " ")) end,
		print = function(...) if VERBOSE then print(...) end end,
	}, { __index = getfenv(0) })
	services.ReplicatedStorage = { Shared = ref("") }
	local fn = assert(loadstring(SOURCES.RebirthService, "=RebirthService"))
	setfenv(fn, env)
	return fn()
end

Config = setmetatable({}, { __index = function(_, name) return charge("Config/" .. name) end })

-- Un profil complet de joueur riche (forme de DataService.TEMPLATE).
function newData()
	return {
		Version = 8,
		Cash = 0,
		Stats = { Speed = 5e6, Strength = 7 },
		Upgrades = { Treadmill = 12, Bench = 3, DisplaySlots = 16, UnboxBenches = 2 },
		Tools = { Owned = { "Fists", "Wrench", "AngleGrinder" }, Equipped = "AngleGrinder" },
		Cosmetics = { Auras = { "Spark", "Royal" }, Trails = { "Dust" }, EquippedAura = "Royal", EquippedTrail = "Dust" },
		Items = {},
		Display = {},
		Vault = {},
		Boxes = {},
		Tutorial = { Step = 9, Done = true },
		Lifetime = { Heists = 40, Steals = 3, Defenses = 2, PlaySeconds = 30000 },
		Purchases = { ["p-1"] = 5 },
		Monetization = { Passes = { DoubleCash = true }, StarterPack = true, OpenNowCredit = 0 },
		Boosts = { Cash = 300 },
		Index = { Z6_DiamantGeant = 10, Z1_PotDeNouilles = 5 },
		Offline = { LastSeenAt = 1000, Income = 5e6, Pending = 5e9 },
		Rewards = { Daily = { Streak = 3, LastDay = 20000 }, Playtime = { Day = 20000, Seconds = 600, Claimed = { ["15"] = 7 } } },
		SkillTree = { Safe = 2 },
		PotionStock = { Money = 2 },
		ZonesReached = { ["6"] = 100 },
		Rebirths = 0,
	}
end
function item(id, zone, extra)
	local entry = { Id = id, Source = "NPC", At = 50, Zone = zone }
	for k, v in extra or {} do
		entry[k] = v
	end
	return entry
end
function incomeOf(id, zone, mutation)
	local def = Config.Items.ById[id]
	return Config.Formulas.ItemIncome(zone or def.Zone, def.Rarity) * Config.Mutations.IncomeMultiplier(mutation)
end
