--!strict
-- TrainingController (DEV-012, client) : tapis et banc côté joueur (Partie 1, sections 5.1 et 9.4).
--
-- Rôle :
--   - pendant que le joueur est sur une machine (attribut TrainingMachine du Player, posé par
--     TrainingService), un tap sur l'écran, un clic gauche ou la gâchette droite de la manette
--     envoie TrainTap. Les taps qui tombent sur l'UI (gameProcessed) ne comptent pas ;
--   - n'envoie jamais plus de 6 taps au tapis ni 3 au banc sur WINDOW secondes
--     (Config.Training) : au-delà, le serveur les ignorerait ;
--   - joue TreadmillRun en boucle sur le tapis et BenchLift à chaque répétition envoyée, par
--     AnimationController s'il est là (rien sinon, sans erreur).
-- Aucune UI et aucun gain ici : l'invite est créée par TrainingService, le serveur décide.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
	StopPlayer: (name: string) -> (),
}

type Limiter = {
	limit: number,
	times: { number }, -- heures (os.clock) des derniers taps envoyés
	cursor: number, -- case du plus ancien
}

-- V0 proposé, absent du doc : fenêtre (s) de la limite côté client, un peu plus longue que la
-- seconde du serveur pour que les écarts du réseau ne fassent pas dépasser la limite à l'arrivée.
local WINDOW = 1.1

local TrainingController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local animation: AnimationApi? = nil
local machine: string? = nil -- "Treadmill", "Bench" ou nil
local limiters: { [string]: Limiter } = {}

local function newLimiter(limit: number): Limiter
	return { limit = limit, times = table.create(limit, -math.huge), cursor = 1 }
end

-- true (et le tap est compté) si le tap respecte la limite.
local function allow(limiter: Limiter, now: number): boolean
	local cursor = limiter.cursor
	if now - limiter.times[cursor] < WINDOW then
		return false
	end
	limiter.times[cursor] = now
	limiter.cursor = cursor % limiter.limit + 1
	return true
end

local function loadAnimationController(): AnimationApi?
	local folder = script.Parent
	local module = if folder then folder:FindFirstChild("AnimationController") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" then
		return result :: any
	end
	return nil
end

local function onMachineChanged()
	local value = localPlayer:GetAttribute("TrainingMachine")
	local new: string? = if value == "Treadmill" or value == "Bench" then value else nil
	if new == machine then
		return
	end
	local previous = machine
	machine = new
	local anim = animation
	if anim == nil then
		return
	end
	if previous == "Treadmill" then
		anim.StopPlayer("TreadmillRun")
	elseif previous == "Bench" then
		anim.StopPlayer("BenchLift")
	end
	if new == "Treadmill" then
		anim.PlayPlayer("TreadmillRun")
	end
end

local function isTap(input: InputObject): boolean
	local inputType = input.UserInputType
	return inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.ButtonR2
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	local current = machine
	if gameProcessed or current == nil or not isTap(input) then
		return
	end
	local limiter = limiters[current]
	if limiter == nil or not allow(limiter, os.clock()) then
		return
	end
	net.Client.TrainTap:Fire()
	local anim = animation
	if current == "Bench" and anim then
		anim.PlayPlayer("BenchLift")
	end
end

function TrainingController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local training = require(shared:WaitForChild("Config"):WaitForChild("Training") :: ModuleScript) :: any
	limiters.Treadmill = newLimiter(training.Treadmill.MaxTapsPerSecond)
	limiters.Bench = newLimiter(training.Bench.MaxRepsPerSecond)
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	animation = loadAnimationController()

	localPlayer:GetAttributeChangedSignal("TrainingMachine"):Connect(onMachineChanged)
	onMachineChanged()
	UserInputService.InputBegan:Connect(onInputBegan)
end

return TrainingController
