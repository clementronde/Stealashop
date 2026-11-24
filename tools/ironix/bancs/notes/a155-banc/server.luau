-- Scénario server (a155) : StatsService.Refresh pose l'attribut TrailMultiplier du Player.
local checks, fails = 0, 0
local function check(ok, label) checks += 1; if not ok then fails += 1; print("ÉCHEC " .. label) end end
local function signal() return { Connect = function() return { Disconnect = function() end } end } end
local attrs = {}
local P = { Name = "Alice", Character = nil, CharacterAdded = signal(),
	SetAttribute = function(_, k, v) attrs[k] = v end, GetAttribute = function(_, k) return attrs[k] end }
local Players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return { P } end }
local services = { Players = Players, RunService = { IsStudio = function() return false end },
	ReplicatedStorage = { Shared = { Config = {
		Balance = { Stats = { MaxWalkSpeed = 70 } },
		Formulas = { WalkSpeed = function(s, t) return 16 * (t or 1) end, ShownSpeed = function(s, t) return s * (t or 1) end },
	} } } }
local data = { Stats = { Speed = 10 } }
local env = setmetatable({
	game = { GetService = function(_, n) return services[n] end },
	script = { Parent = { DataService = { Get = function() return data end, OnProfileLoaded = function() end } } },
	require = function(m) return m end,
	warn = function() end,
}, { __index = _G })
local fn = assert(loadstring(SOURCE, "StatsService"))
setfenv(fn, env)
local Stats = fn()
Stats.Init()
Stats.Refresh(P)
check(attrs.TrailMultiplier == 1, `S1 sans trail : TrailMultiplier = 1 ({attrs.TrailMultiplier})`)
Stats.GetTrailMultiplier = function() return 2 end
Stats.Refresh(P)
check(attrs.TrailMultiplier == 2, `S2 trail ×2 : TrailMultiplier = 2 ({attrs.TrailMultiplier})`)
Stats.GetTrailMultiplier = function() return 12 end
Stats.Refresh(P)
check(attrs.TrailMultiplier == 12 and attrs.Speed == 10, `S3 trail ×12 : 12, Speed brute inchangée ({attrs.TrailMultiplier}, {attrs.Speed})`)
Stats.GetTrailMultiplier = function() return 0 / 0 end
Stats.Refresh(P)
check(attrs.TrailMultiplier == 1, `S4 multiplicateur invalide : 1 ({attrs.TrailMultiplier})`)
print(`{checks} vérification(s), {fails} échec(s)`)
