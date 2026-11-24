--!nocheck
-- Faux Roblox minimal d'a276 : de quoi charger Net côté serveur (Players, ReplicatedStorage, RunService,
-- Instance.new de dossier et de RemoteEvent, task.spawn immédiat, os.clock simulé par NOW).
SOURCES = {}
NOW = 100
WARNS = {}

local function Signal()
	local s = { handlers = {} }
	function s:Connect(f)
		table.insert(self.handlers, f)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, f in self.handlers do
			f(...)
		end
	end
	return s
end

FakePlayers = { PlayerRemoving = Signal() }
local ReplicatedStorage = {
	FindFirstChild = function()
		return nil
	end,
}
local RunService = {
	IsStudio = function()
		return false
	end,
	IsServer = function()
		return true
	end,
	IsRunning = function()
		return true
	end,
}
local fakeGame = {
	GetService = function(_, name)
		return ({ Players = FakePlayers, ReplicatedStorage = ReplicatedStorage, RunService = RunService })[name]
	end,
}
INSTANCES = {}
local fakeInstance = {
	new = function(class)
		local inst = { ClassName = class, OnServerEvent = Signal() }
		table.insert(INSTANCES, inst)
		return inst
	end,
}

local loaded = {}
local folderScript = {}
for _, m in { "Net", "Definitions", "RateLimiter", "Validate" } do
	folderScript[m] = { __module = m }
end

function loadModule(name)
	if loaded[name] ~= nil then
		return loaded[name]
	end
	local fn, err = loadstring(SOURCES[name], name)
	assert(fn, err)
	local env = setmetatable({
		script = { Parent = folderScript, Name = name },
		game = fakeGame,
		Instance = fakeInstance,
		require = function(x)
			return loadModule(x.__module)
		end,
		warn = function(...)
			table.insert(WARNS, table.concat({ ... }, " "))
		end,
		task = {
			spawn = function(f, ...)
				f(...)
			end,
		},
		os = {
			clock = function()
				return NOW
			end,
			time = os.time,
		},
	}, { __index = getfenv(1) })
	setfenv(fn, env)
	local result = fn()
	loaded[name] = result
	return result
end
