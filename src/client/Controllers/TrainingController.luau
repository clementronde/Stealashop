--!strict
-- TrainingController (DEV-012, client) : tapis et banc côté joueur (Partie 1, sections 5.1 et 9.4).
--
-- Rôle :
--   - au tapis (attribut TrainingMachine du Player = "Treadmill", posé par TrainingService), un tap
--     sur l'écran, un clic gauche ou la gâchette droite de la manette envoie TrainTap (bonus du
--     tapis). Les taps qui tombent sur l'UI (gameProcessed) ne comptent pas ;
--   - au banc (TrainingMachine = "Bench"), le joueur soulève tout seul, sans clic (L-091, point 2) :
--     BenchLift est rejoué en boucle tant qu'il y est, et chaque marqueur Top envoie TrainTap (une
--     répétition ; le serveur décide du gain). Sans BenchLift (ou sans son marqueur), rien n'est
--     envoyé : le serveur compte alors les répétitions à son propre rythme (TrainingService) ;
--   - n'envoie jamais plus de 6 TrainTap au tapis ni 3 au banc sur WINDOW secondes
--     (Config.Training) : au-delà, le serveur les ignorerait ;
--   - joue TreadmillRun en boucle sur le tapis, par AnimationController s'il est là (rien sinon,
--     sans erreur ; AnimationController joue aussi TreadmillRun et BenchIdle d'après l'attribut, et
--     ne relance pas un BenchLift déjà parti quand le serveur confirme la répétition).
-- Aucune UI et aucun gain ici, le serveur décide : le tapis n'a pas d'invite (on monte dessus et on
-- s'y arrête, L-071), l'invite du banc est créée par TrainingService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
	StopPlayer: (name: string) -> (),
	OnMarker: (animName: string, markerName: string, callback: () -> ()) -> () -> (),
}

type Limiter = {
	limit: number,
	times: { number }, -- heures (os.clock) des derniers taps envoyés
	cursor: number, -- case du plus ancien
}

-- V0 proposé, absent du doc : fenêtre (s) de la limite côté client, un peu plus longue que la
-- seconde du serveur pour que les écarts du réseau ne fassent pas dépasser la limite à l'arrivée.
local WINDOW = 1.1
-- Banc automatique (L-091, point 2) : animation rejouée en boucle et marqueur qui compte une
-- répétition (contrat 2.4, Shared/Contract/Animations).
local BENCH_LIFT = "BenchLift"
local BENCH_MARKER = "Top"
-- V0 proposé, absent du doc : attente (s) avant de réessayer BenchLift quand l'animation manque.
local BENCH_RETRY = 1
-- V0 proposé, absent du doc : au plus la durée de BenchLift + ce délai (s) avant de la relancer, si
-- sa fin n'est pas vue (piste pas encore chargée, Length à 0…).
local BENCH_MAX_EXTRA = 3

local TrainingController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local animation: AnimationApi? = nil
local machine: string? = nil -- "Treadmill", "Bench" ou nil
local limiters: { [string]: Limiter } = {}
local benchToken = 0 -- change à chaque changement de machine : périme l'ancienne boucle du banc

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

local function sendTap(kind: string)
	local limiter = limiters[kind]
	if limiter == nil or not allow(limiter, os.clock()) then
		return
	end
	net.Client.TrainTap:Fire()
end

-- Banc : BenchLift rejoué tant que le joueur y est (boucle n° `token`). Le marqueur Top envoie la
-- répétition (branché une fois dans Start).
local function benchLoop(token: number)
	while benchToken == token and machine == "Bench" do
		local anim = animation
		local track = if anim then anim.PlayPlayer(BENCH_LIFT) else nil
		if track == nil then
			task.wait(BENCH_RETRY)
			continue
		end
		local deadline = os.clock() + math.max(track.Length, 0) + BENCH_MAX_EXTRA
		task.wait()
		while benchToken == token and track.IsPlaying and os.clock() < deadline do
			task.wait()
		end
	end
end

local function onMachineChanged()
	local value = localPlayer:GetAttribute("TrainingMachine")
	local new: string? = if value == "Treadmill" or value == "Bench" then value else nil
	if new == machine then
		return
	end
	local previous = machine
	machine = new
	benchToken += 1
	if new == "Bench" then
		task.spawn(benchLoop, benchToken)
	end
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
	-- Au banc, plus de clic : les répétitions viennent du marqueur Top (L-091, point 2).
	if gameProcessed or current ~= "Treadmill" or not isTap(input) then
		return
	end
	sendTap(current)
end

function TrainingController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local training = require(shared:WaitForChild("Config"):WaitForChild("Training") :: ModuleScript) :: any
	limiters.Treadmill = newLimiter(training.Treadmill.MaxTapsPerSecond)
	limiters.Bench = newLimiter(training.Bench.MaxRepsPerSecond)
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	animation = loadAnimationController()
	local anim = animation
	if anim then
		-- Suit le joueur d'une vie à l'autre (AnimationController rebranche les marqueurs).
		anim.OnMarker(BENCH_LIFT, BENCH_MARKER, function()
			if machine == "Bench" then
				sendTap("Bench")
			end
		end)
	end

	localPlayer:GetAttributeChangedSignal("TrainingMachine"):Connect(onMachineChanged)
	onMachineChanged()
	UserInputService.InputBegan:Connect(onInputBegan)
end

return TrainingController
