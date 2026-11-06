--!strict
-- ChaseController (DEV-018, client) : la poursuite vue par le joueur poursuivi (Partie 1, 5.5).
--
-- Écoute ChaseState(active, guard) de GuardService. Pendant la poursuite, mesure à chaque image
-- la distance entre son HumanoidRootPart et celui du vigile (la même mesure que la capture,
-- vérifiée par le serveur). En attendant la jauge GuardMeter de Clément (UI_HUD, contrat 2.2) et
-- le son des battements de cœur (DEV-051), la distance est écrite dans la sortie, en Studio
-- seulement : au début et à la fin, toutes les PRINT_INTERVAL s, et un repère « ♥ » quand elle
-- passe sous Balance.Guard.HeartbeatDistance (puis quand elle en ressort).
--
-- Coup du vigile : quand GuardService pousse le joueur rattrapé (Attachment GuardKnockback posé
-- dans son HumanoidRootPart), joue Knockback puis Stunned jusqu'à la fin de l'étourdissement
-- (Balance.Guard.CatchStunDuration), via AnimationController s'il est là (rien sinon).
--
-- API (client) :
--   ChaseController.IsChased() -> boolean
--   ChaseController.GetGuard() -> Model?       le vigile qui poursuit le joueur local
--   ChaseController.GetDistance() -> number?   distance au vigile (studs), nil hors poursuite
--   ChaseController.IsClose() -> boolean       sous HeartbeatDistance (battements de cœur)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Ce que ce contrôleur utilise d'AnimationController (a09).
type AnimationApi = {
	PlayPlayer: (name: string, fadeTime: number?) -> AnimationTrack?,
	StopPlayer: (name: string, fadeTime: number?) -> (),
}

-- Mêmes noms que dans GuardService (serveur) : les changer dans les deux fichiers.
local KNOCKBACK_NAME = "GuardKnockback"
local ACTIVE_FOLDER = "ActiveGuards"
local TARGET_ATTRIBUTE = "TargetUserId"

-- V0 proposé, absent du doc.
local PRINT_INTERVAL = 0.5 -- écriture de la distance dans la sortie, en Studio (s)
local GUARD_WAIT = 3 -- attente max du vigile s'il n'arrive pas avec ChaseState (streaming) (s)

local IS_STUDIO = RunService:IsStudio()

local ChaseController = {}

local localPlayer = Players.LocalPlayer
local heartbeatDistance = 10 -- remplacé au démarrage par Balance.Guard.HeartbeatDistance
local stunDuration = 1.5 -- remplacé au démarrage par Balance.Guard.CatchStunDuration
local animation: AnimationApi? = nil
local active = false
local guard: Model? = nil
local distance: number? = nil
local close = false
local lastPrint = -math.huge
local chaseToken = 0
local stunToken = 0
local rootConnection: RBXScriptConnection? = nil

-- 12.34 → « 12,3 ».
local function format(n: number): string
	return (string.gsub(string.format("%.1f", n), "%.", ","))
end

local function rootOf(model: Instance?): BasePart?
	if model == nil then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root :: BasePart
	end
	if model:IsA("Model") then
		return (model :: Model).PrimaryPart
	end
	return nil
end

local function loadAnimationController(): AnimationApi?
	local module = script.Parent:FindFirstChild("AnimationController")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" then
		return result :: any
	end
	return nil
end

function ChaseController.IsChased(): boolean
	return active
end

function ChaseController.GetGuard(): Model?
	return if active then guard else nil
end

function ChaseController.GetDistance(): number?
	return if active then distance else nil
end

function ChaseController.IsClose(): boolean
	return active and close
end

-- Poursuite ---------------------------------------------------------------------------------

-- Le vigile du joueur local, retrouvé par son attribut (s'il n'est pas arrivé avec ChaseState).
local function findGuard(): Model?
	local folder = Workspace:FindFirstChild(ACTIVE_FOLDER)
	if folder == nil then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute(TARGET_ATTRIBUTE) == localPlayer.UserId then
			return child :: Model
		end
	end
	return nil
end

local function onChaseState(isActive: boolean, model: Instance?)
	chaseToken += 1
	local token = chaseToken
	if not isActive then
		if active and IS_STUDIO then
			print("[Poursuite] fin de la poursuite")
		end
		active = false
		guard = nil
		distance = nil
		close = false
		return
	end
	active = true
	close = false
	distance = nil
	lastPrint = -math.huge
	guard = if model and model:IsA("Model") then model :: Model else nil
	if IS_STUDIO then
		print("[Poursuite] un vigile te poursuit !")
	end
	if guard ~= nil then
		return
	end
	task.spawn(function()
		local deadline = os.clock() + GUARD_WAIT
		while token == chaseToken and guard == nil and os.clock() < deadline do
			guard = findGuard()
			if guard == nil then
				task.wait(0.1)
			end
		end
		if token == chaseToken and guard == nil and IS_STUDIO then
			warn("[Poursuite] vigile introuvable côté client (streaming ?) : distance inconnue")
		end
	end)
end

local function update()
	if not active then
		return
	end
	local model = guard
	local mine = rootOf(localPlayer.Character)
	local theirs = if model and model.Parent then rootOf(model) else nil
	if mine == nil or theirs == nil then
		distance = nil
		return
	end
	local d = (theirs.Position - mine.Position).Magnitude
	distance = d
	local wasClose = close
	close = d < heartbeatDistance
	if not IS_STUDIO then
		return
	end
	if close and not wasClose then
		print(`[Poursuite] ♥ vigile à moins de {heartbeatDistance} studs ({format(d)}) : battements de cœur`)
	elseif wasClose and not close then
		print(`[Poursuite] vigile de nouveau à {heartbeatDistance} studs ou plus ({format(d)})`)
	end
	local now = os.clock()
	if now - lastPrint >= PRINT_INTERVAL then
		lastPrint = now
		print(`[Poursuite] vigile à {format(d)} studs{if close then " ♥" else ""}`)
	end
end

-- Coup du vigile ----------------------------------------------------------------------------

-- Knockback, puis Stunned jusqu'à la fin de l'étourdissement.
local function onKnockback()
	local anim = animation
	if anim == nil then
		return
	end
	stunToken += 1
	local token = stunToken
	local endsAt = os.clock() + stunDuration
	local function startStunned()
		if token == stunToken and os.clock() < endsAt then
			anim.PlayPlayer("Stunned")
		end
	end
	local track = anim.PlayPlayer("Knockback")
	if track then
		track.Stopped:Once(startStunned)
	else
		startStunned()
	end
	task.delay(stunDuration, function()
		if token == stunToken then
			anim.StopPlayer("Stunned")
		end
	end)
end

local function watchCharacter(character: Model)
	local previous = rootConnection
	if previous then
		previous:Disconnect()
		rootConnection = nil
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or localPlayer.Character ~= character then
		return
	end
	rootConnection = root.ChildAdded:Connect(function(child: Instance)
		if child.Name == KNOCKBACK_NAME then
			onKnockback()
		end
	end)
end

function ChaseController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local balance = require(shared:WaitForChild("Config"):WaitForChild("Balance") :: ModuleScript) :: any
	heartbeatDistance = balance.Guard.HeartbeatDistance
	stunDuration = balance.Guard.CatchStunDuration
	animation = loadAnimationController()

	localPlayer.CharacterAdded:Connect(watchCharacter)
	local character = localPlayer.Character
	if character then
		task.spawn(watchCharacter, character)
	end
	RunService.Heartbeat:Connect(update)

	-- Peut attendre que le serveur ait créé les remotes.
	local net = require(shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	net.Client.ChaseState:Connect(onChaseState)
end

return ChaseController
