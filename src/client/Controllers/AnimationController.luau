--!strict
-- AnimationController (DEV-006) : les animations du personnage local, jouées par leur nom.
--
-- À chaque apparition du personnage, prépare les 13 animations du joueur
-- (ReplicatedStorage/Assets/Animations/Player, contrat 2.4) sur son Animator, rebranche les
-- marqueurs (sons de Shared/Anim/MarkerSounds et branchements des autres contrôleurs) et rejoue
-- l'état en cours. Préchargement une fois par session. Déjà branché, sans autre service :
--   - TreadmillRun en boucle tant que l'attribut TrainingMachine du Player vaut "Treadmill" ;
--   - BenchLift à chaque hausse de l'attribut BenchReps du Player (TrainingService) ;
--   - BenchIdle en boucle tant que TrainingMachine vaut "Bench" (L-020) ;
--   - portage prêt : SetCarrying(true) joue CarryIdle à l'arrêt et CarryRun en mouvement, à
--     appeler par le code du portage (DEV-017).
-- En Studio, mode test de DEV-006 : voir Shared/Anim/AnimTest.
--
-- API (les autres contrôleurs le requièrent avec pcall et continuent sans lui) :
--   AnimationController.PlayPlayer(name, fadeTime?) -> AnimationTrack?
--   AnimationController.StopPlayer(name, fadeTime?)
--   AnimationController.OnMarker(animName, markerName, callback) -> débrancher
--     (le branchement suit le joueur d'une vie à l'autre)
--   AnimationController.SetCarrying(carrying)
-- Une animation pas encore livrée ne fait rien, sans erreur (un avertissement en Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimFolder = Shared:WaitForChild("Anim")
local AnimPlayer = require(AnimFolder:WaitForChild("AnimPlayer"))
local MarkerSounds = require(AnimFolder:WaitForChild("MarkerSounds"))
local Animations = require(Shared:WaitForChild("Contract"):WaitForChild("Animations"))

type AnimPlayer = AnimPlayer.AnimPlayer

-- Branchement d'un autre contrôleur sur un marqueur, rebranché à chaque vie du personnage.
type Sub = { anim: string, marker: string, callback: () -> (), off: (() -> ())? }

local AnimationController = {}

-- Attributs du Player posés par TrainingService, lus ici sans require.
local TRAINING_MACHINE = "TrainingMachine"
local BENCH_REPS = "BenchReps"

-- V0 proposé, absent du doc : vitesse (studs/s) au-dessus de laquelle le porteur court
-- (CarryRun) ; en dessous, CarryIdle. Même seuil que le script Animate de Roblox.
local CARRY_RUN_SPEED = 0.75

local IS_STUDIO = RunService:IsStudio()

local player = Players.LocalPlayer
local playerFolder: Instance? = nil
local current: AnimPlayer? = nil
local currentCharacter: Model? = nil
local characterConnections: { RBXScriptConnection } = {}
local subs: { Sub } = {}
local carrying = false
local carryAnim: string? = nil
local benchReps = 0

local function bindSub(anims: AnimPlayer, sub: Sub)
	sub.off = anims:OnMarker(sub.anim, sub.marker, function(_param: string)
		sub.callback()
	end)
end

-- Joue une animation du joueur. Renvoie sa piste, ou nil si elle n'est pas encore livrée ou si le
-- personnage n'est pas là.
function AnimationController.PlayPlayer(name: string, fadeTime: number?): AnimationTrack?
	local anims = current
	if anims == nil then
		return nil
	end
	return anims:Play(name, fadeTime)
end

function AnimationController.StopPlayer(name: string, fadeTime: number?)
	local anims = current
	if anims then
		anims:Stop(name, fadeTime)
	end
end

-- Appelle `callback` à chaque passage du marqueur `markerName` de l'animation `animName` du
-- joueur, d'une vie à l'autre. Renvoie une fonction qui débranche.
function AnimationController.OnMarker(animName: string, markerName: string, callback: () -> ()): () -> ()
	local sub: Sub = { anim = animName, marker = markerName, callback = callback, off = nil }
	table.insert(subs, sub)
	local anims = current
	if anims then
		bindSub(anims, sub)
	end
	return function()
		local index = table.find(subs, sub)
		if index then
			table.remove(subs, index)
		end
		local off = sub.off
		if off then
			sub.off = nil
			off()
		end
	end
end

local function rootPart(): BasePart?
	local character = currentCharacter
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

local function horizontalSpeed(): number
	local root = rootPart()
	if root == nil then
		return 0
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

-- Portage ----------------------------------------------------------------------

local function setCarryAnim(name: string?)
	if name == carryAnim then
		return
	end
	local previous = carryAnim
	carryAnim = name
	if previous then
		AnimationController.StopPlayer(previous)
	end
	if name then
		AnimationController.PlayPlayer(name)
	end
end

local function updateCarry(speed: number)
	if carrying then
		setCarryAnim(if speed > CARRY_RUN_SPEED then "CarryRun" else "CarryIdle")
	else
		setCarryAnim(nil)
	end
end

-- Colis ou objet porté (DEV-017) : true joue CarryIdle ou CarryRun selon la vitesse, et suit les
-- changements de vitesse ; false les arrête.
function AnimationController.SetCarrying(on: boolean)
	carrying = on
	updateCarry(horizontalSpeed())
end

-- Entraînement (attributs du Player tenus par TrainingService) ------------------

local function applyTreadmill()
	local machine = player:GetAttribute(TRAINING_MACHINE)
	if machine == "Treadmill" then
		AnimationController.PlayPlayer("TreadmillRun")
	else
		AnimationController.StopPlayer("TreadmillRun")
	end
	-- BenchIdle en boucle tant qu'on est au banc (L-020) ; BenchLift, en Action, passe
	-- par-dessus à chaque répétition.
	if machine == "Bench" then
		AnimationController.PlayPlayer("BenchIdle")
	else
		AnimationController.StopPlayer("BenchIdle")
	end
end

local function readBenchReps(): number
	local value = player:GetAttribute(BENCH_REPS)
	return if type(value) == "number" then value else 0
end

local function onBenchReps()
	local reps = readBenchReps()
	if reps > benchReps then
		AnimationController.PlayPlayer("BenchLift")
	end
	benchReps = reps
end

-- Personnage -------------------------------------------------------------------

local function clearCharacter()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	for _, sub in subs do
		sub.off = nil
	end
	local anims = current
	current = nil
	if anims then
		anims:Destroy()
	end
	carryAnim = nil
end

local function onCharacter(character: Model)
	if currentCharacter == character then
		return -- déjà en cours pour ce personnage
	end
	clearCharacter()
	currentCharacter = character
	local animator = AnimPlayer.waitForAnimator(character)
	if currentCharacter ~= character then
		return -- un autre personnage est arrivé entre-temps
	end
	if animator == nil then
		if IS_STUDIO then
			warn("[Anim] Joueur : pas d'Animator dans le Humanoid du personnage, aucune animation jouée")
		end
		return
	end
	local anims = AnimPlayer.new(animator, playerFolder, Animations.Player, "Joueur")
	current = anims
	anims:LoadAll()
	for _, sub in subs do
		bindSub(anims, sub)
	end
	local humanoid = animator.Parent
	if humanoid and humanoid:IsA("Humanoid") then
		table.insert(
			characterConnections,
			(humanoid :: Humanoid).Running:Connect(function(speed: number)
				if carrying then
					updateCarry(speed)
				end
			end)
		)
	end
	applyTreadmill()
	updateCarry(horizontalSpeed())
end

local function onCharacterRemoving(character: Model)
	if currentCharacter == character then
		clearCharacter()
		currentCharacter = nil
	end
end

local function preloadOnce()
	local names: { string } = {}
	for _, spec in Animations.Player do
		table.insert(names, spec.Name)
	end
	local count = AnimPlayer.preload(playerFolder, names)
	if not IS_STUDIO then
		return
	end
	if playerFolder == nil then
		print(
			`[Anim] Joueur : ReplicatedStorage.{table.concat(Animations.PlayerFolder, ".")} absent, aucune des {#names} animations n'est encore livrée`
		)
	else
		print(`[Anim] Joueur : {count}/{#names} animation(s) préchargée(s)`)
	end
end

function AnimationController.Start()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	playerFolder = AnimPlayer.playerFolder()

	-- Sons des marqueurs (registre Shared/Anim/MarkerSounds), joués sur le personnage local.
	if IS_STUDIO then
		MarkerSounds.check(MarkerSounds.Player, Animations.Player, "Player")
	end
	for _, entry in MarkerSounds.Player do
		AnimationController.OnMarker(entry.Anim, entry.Marker, function()
			MarkerSounds.play(entry.Sound, rootPart())
		end)
	end

	benchReps = readBenchReps()
	player:GetAttributeChangedSignal(TRAINING_MACHINE):Connect(applyTreadmill)
	player:GetAttributeChangedSignal(BENCH_REPS):Connect(onBenchReps)

	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(onCharacterRemoving)
	local character = player.Character
	if character then
		task.spawn(onCharacter, character)
	end

	task.spawn(preloadOnce)

	-- Mode test de DEV-006, chargé en Studio seulement (Shared/Anim/AnimTest).
	if IS_STUDIO then
		local ok, err = pcall(function()
			require(AnimFolder:WaitForChild("AnimTest")).start()
		end)
		if not ok then
			warn(`[Anim] mode test indisponible : {err}`)
		end
	end
end

return AnimationController
