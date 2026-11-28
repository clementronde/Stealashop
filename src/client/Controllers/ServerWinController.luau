--!strict
-- ServerWinController (a522, liaison L-455, Clément 26/11 : « mettre son dans le serveur de victoire ») : un autre joueur
-- vient de ramener un objet en zone safe (remote ServerWin de CelebrationService, Features.ServerWinSound ou
-- ServerWinSoundDev, au plus un toutes les Config/Announce.ServerWin.Gap s) : le son Heist_ServerWin de Clément est joué
-- en 3D à l'endroit où il a passé la ligne safe. Celui qui ramène l'objet ne reçoit pas le remote (il garde Heist_Escape,
-- en 2D). La copie jouée prend la portée de Config/Announce.ServerWin (RollOffMode, RollOffMinDistance,
-- RollOffMaxDistance) ; SoundId et Volume restent ceux de Clément. Son absent : muet (Shared/Anim/MarkerSounds).
--
-- API (client) :
--   ServerWinController.Play(position) -> Sound?   joue le son à `position` (nil : son absent) ; bancs, barre de commande
--   ServerWinController.GetState() -> { Played: number, Missing: number }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Settings = require(Shared:WaitForChild("Config"):WaitForChild("Announce")) :: any
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))

local ServerWinController = {}

local played = 0
local missing = 0

local function spec(): any
	return if type(Settings.ServerWin) == "table" then Settings.ServerWin else {}
end

function ServerWinController.Play(position: Vector3): Sound?
	local s = spec()
	local name = if type(s.Sound) == "string" then s.Sound else "Heist_ServerWin"
	local template = MarkerSounds.find(name)
	if template == nil then
		missing += 1
		return nil
	end
	local anchor = Instance.new("Attachment")
	anchor.Name = "ServerWin_Sound"
	anchor.WorldPosition = position
	anchor.Parent = Workspace.Terrain
	local sound = template:Clone()
	pcall(function()
		local mode = (Enum.RollOffMode :: any)[s.RollOffMode or ""]
		if mode then
			sound.RollOffMode = mode
		end
		if type(s.RollOffMinDistance) == "number" then
			sound.RollOffMinDistance = s.RollOffMinDistance
		end
		if type(s.RollOffMaxDistance) == "number" then
			sound.RollOffMaxDistance = s.RollOffMaxDistance
		end
	end)
	sound.Parent = anchor
	sound.Ended:Once(function()
		anchor:Destroy()
	end)
	task.delay(if type(s.Lifetime) == "number" then s.Lifetime else 10, function()
		if anchor.Parent ~= nil then
			anchor:Destroy()
		end
	end)
	sound:Play()
	played += 1
	return sound
end

function ServerWinController.GetState(): { Played: number, Missing: number }
	return { Played = played, Missing = missing }
end

function ServerWinController.Start()
	local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	Net.Client.ServerWin:Connect(function(position: any)
		if typeof(position) == "Vector3" then
			ServerWinController.Play(position)
		end
	end)
end

return ServerWinController
