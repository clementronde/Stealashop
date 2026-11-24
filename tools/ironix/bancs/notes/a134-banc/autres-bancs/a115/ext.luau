-- Ajouts du banc a115 au faux Roblox de la copie a115 du banc a65 : côté client (TrainingController).
-- Réseau sans délai : client et serveur voient les mêmes instances ; le serveur tourne avant le client à
-- chaque Heartbeat (branché d'abord).

-- WaitForChild (le client l'utilise) : comme FindFirstChild, sans attente.
do
	local mt = getmetatable(workspace)
	local oldIndex = mt.__index
	mt.__index = function(self, k)
		if k == "WaitForChild" then
			return function(s, n)
				return assert(s:FindFirstChild(n), n)
			end
		end
		return oldIndex(self, k)
	end
end

-- UserInputService (taps du tapis).
INPUT_BEGAN = newSignal()
local UserInputService = { InputBegan = INPUT_BEGAN }
do
	local getService = rawget(game, "GetService")
	rawset(game, "GetService", function(g, n)
		if n == "UserInputService" then
			return UserInputService
		end
		return getService(g, n)
	end)
end

-- StatsService : la vitesse 0 du modificateur « Training » arrive au Humanoid (réplication simulée).
do
	local stats = requireModule(game.Services.StatsService)
	stats.SetSpeedModifier = function(p, _key, v)
		SPEEDMOD[p] = v
		local hum = p.Character and p.Character:FindFirstChild("Humanoid")
		if hum then
			hum.WalkSpeed = if v == 0 then 0 else 16
		end
	end
end

-- Net côté client : TrainTap et TrainLeave arrivent tout de suite au serveur.
CLIENT_PLAYER = nil
SENT = { TrainTap = 0, TrainLeave = 0 }
do
	local netStub = requireModule(ReplicatedStorage.Shared.Net.Net)
	netStub.Client = {
		TrainTap = {
			Fire = function()
				SENT.TrainTap += 1
				TAP:Fire(CLIENT_PLAYER)
			end,
		},
		TrainLeave = {
			Fire = function()
				SENT.TrainLeave += 1
				LEAVE:Fire(CLIENT_PLAYER)
			end,
		},
	}
end

-- Faux AnimationController : pistes « en cours » par nom.
ANIM = { playing = {}, plays = {} }
local controllers = newInst("Folder", "Controllers", game)
do
	local anim = newInst("ModuleScript", "AnimationController", controllers)
	anim._value = {
		PlayPlayer = function(name)
			ANIM.plays[name] = (ANIM.plays[name] or 0) + 1
			ANIM.playing[name] = true
			return { Length = 1, IsPlaying = true }
		end,
		StopPlayer = function(name)
			ANIM.playing[name] = nil
		end,
		OnMarker = function()
			return function() end
		end,
	}
end
SPAWNED = 0

-- Charge et démarre le vrai TrainingController pour `p` (joueur local).
function startClient(p)
	CLIENT_PLAYER = p
	Players.LocalPlayer = p
	local hum = p.Character:FindFirstChild("Humanoid")
	hum.WalkSpeed = 16
	hum.MoveDirection = Vector3.zero
	p.CharacterAdded = newSignal()
	local m = newInst("ModuleScript", "TrainingController", controllers)
	local key = "client/Controllers/TrainingController.luau"
	local fn = assert(loadstring(assert(SOURCES[key], key), key))
	setfenv(
		fn,
		setmetatable({
			script = m,
			require = requireModule,
			game = game,
			workspace = workspace,
			Instance = Instance,
			Vector3 = Vector3,
			CFrame = CFrame,
			Enum = Enum,
			task = {
				spawn = function()
					SPAWNED += 1
				end,
				wait = function() end,
			},
			os = {
				clock = function()
					return NOW
				end,
			},
			print = function() end,
			warn = function(...)
				table.insert(LOGS, "WARN " .. table.concat({ ... }, " "))
			end,
		}, { __index = getfenv(1) })
	)
	local ctl = fn()
	ctl.Start()
	return ctl
end

function setMove(p, x, z)
	p.Character:FindFirstChild("Humanoid").MoveDirection = Vector3.new(x, 0, z)
end
function humOf(p)
	return p.Character:FindFirstChild("Humanoid")
end
