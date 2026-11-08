--!strict
-- AnimationController (DEV-006) : les animations du personnage local, jouées par leur nom.
--
-- À chaque apparition du personnage, prépare les 14 animations du joueur
-- (ReplicatedStorage/Assets/Animations/Player, contrat 2.4) sur son Animator, rebranche les
-- marqueurs (sons de Shared/Anim/MarkerSounds et branchements des autres contrôleurs) et rejoue
-- l'état en cours. Préchargement une fois par session. Déjà branché, sans autre service :
--   - TreadmillRun en boucle tant que l'attribut TrainingMachine du Player vaut "Treadmill" (posé
--     par TrainingService quand le joueur s'arrête sur la bande du tapis, L-071) ;
--   - BenchLift à chaque hausse de l'attribut BenchReps du Player (TrainingService), sauf s'il joue
--     déjà : TrainingController le lance au tap, la hausse confirmée par le serveur ne le relance pas ;
--   - BenchIdle en boucle tant que TrainingMachine vaut "Bench" (L-020) ;
--   - portage : SetCarrying(true), appelé par CarryController quand l'attribut Carrying du joueur
--     arrive (CarryService), joue CarryIdle à l'arrêt et CarryRun en mouvement ; SetCarrying(false)
--     les arrête. Grab pose le colis sur la tête, puis CarryIdle et CarryRun le tiennent (L-071,
--     point 4) : si Grab joue encore (lancé au ramassage par HeistController, PvPController,
--     TruckController ou BatController), la boucle attend que Grab ait posé le colis (AfterGrab),
--     puis prend sa suite en fondu (GRAB_BLEND) : les deux pistes, en Action, ne se mélangent pas.
-- En Studio, mode test de DEV-006 : voir Shared/Anim/AnimTest.
--
-- « Grab a posé le colis » (AfterGrab) : au marqueur Grab de l'animation Grab (Clément le pose sur
-- l'image où le colis arrive sur la tête), sinon à la fin de Grab, au plus tard GRAB_MAX_WAIT s
-- (ou la durée de Grab, si elle est plus longue) après son lancement. Côté client seulement, pour le
-- joueur local : le serveur a déjà décidé la prise, rien ne l'attend.
--
-- API (les autres contrôleurs le requièrent avec pcall et continuent sans lui) :
--   AnimationController.PlayPlayer(name, fadeTime?) -> AnimationTrack?
--   AnimationController.StopPlayer(name, fadeTime?)
--   AnimationController.OnMarker(animName, markerName, callback) -> débrancher
--     (le branchement suit le joueur d'une vie à l'autre)
--   AnimationController.SetCarrying(carrying)
--   AnimationController.AfterGrab(callback) -> boolean
--     callback(fromGrab) quand le Grab en cours a posé le colis (voir plus haut) : fromGrab = true.
--     Sans Grab en cours, tout de suite, avant le retour : callback(false), et AfterGrab renvoie
--     false. Renvoie true si l'appel est différé (CarryController cache le colis en attendant).
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

-- Prise d'un colis (contrat 2.4) : animation Grab et son marqueur.
local GRAB_ANIMATION = "Grab"
local GRAB_MARKER = "Grab"
for _, spec in Animations.Player do
	local marker = spec.Marker
	if spec.Name == GRAB_ANIMATION and marker then
		GRAB_MARKER = marker
	end
end
-- V0 proposé, absent du doc : au plus tard ce délai (s) après le lancement de Grab, le colis est
-- tenu pour posé (Grab sans marqueur dont la fin ne vient pas : piste pas encore chargée…).
local GRAB_MAX_WAIT = 1.5
-- V0 proposé, absent du doc : fondu (s) entre Grab et la boucle de portage (CarryIdle ou CarryRun).
local GRAB_BLEND = 0.2

local IS_STUDIO = RunService:IsStudio()

local player = Players.LocalPlayer
local playerFolder: Instance? = nil
local current: AnimPlayer? = nil
local currentCharacter: Model? = nil
local characterConnections: { RBXScriptConnection } = {}
local subs: { Sub } = {}
local carrying = false
local carryReady = false -- la boucle de portage peut jouer (Grab a posé le colis, ou pas de Grab)
local carryToken = 0 -- change à chaque SetCarrying : périme une attente de Grab d'avant
local carryAnim: string? = nil
local benchReps = 0
-- Grab lancés (PlayPlayer) et dernier Grab qui a posé son colis ; appels d'AfterGrab en attente.
local grabPlays = 0
local grabDone = 0
local grabWaiters: { (fromGrab: boolean) -> () } = {}

local function bindSub(anims: AnimPlayer, sub: Sub)
	sub.off = anims:OnMarker(sub.anim, sub.marker, function(_param: string)
		sub.callback()
	end)
end

-- Prise d'un colis -----------------------------------------------------------------

-- Le Grab n° `id` a posé son colis (marqueur, fin ou délai) : les attentes d'AfterGrab partent.
-- Sans effet pour un Grab dépassé par un plus récent, ou déjà compté.
local function grabReached(id: number)
	if id ~= grabPlays or grabDone >= id then
		return
	end
	grabDone = id
	local waiters = grabWaiters
	grabWaiters = {}
	for _, waiter in waiters do
		task.spawn(waiter, true)
	end
end

-- Un Grab vient d'être lancé (piste rendue par PlayPlayer) : sa fin, ou au plus tard GRAB_MAX_WAIT
-- (sa durée, si elle est plus longue : un marqueur tardif n'est jamais devancé), tiendra lieu de
-- marqueur s'il n'en a pas.
local function onGrabStarted(track: AnimationTrack)
	grabPlays += 1
	local id = grabPlays
	track.Stopped:Once(function()
		grabReached(id)
	end)
	task.delay(math.max(GRAB_MAX_WAIT, track.Length), grabReached, id)
end

-- Un Grab joue et n'a pas encore posé son colis.
local function grabPending(): boolean
	local anims = current
	return grabDone < grabPlays and anims ~= nil and anims:IsPlaying(GRAB_ANIMATION)
end

-- Joue une animation du joueur. Renvoie sa piste, ou nil si elle n'est pas encore livrée ou si le
-- personnage n'est pas là.
function AnimationController.PlayPlayer(name: string, fadeTime: number?): AnimationTrack?
	local anims = current
	if anims == nil then
		return nil
	end
	local track = anims:Play(name, fadeTime)
	if track and name == GRAB_ANIMATION then
		onGrabStarted(track)
	end
	return track
end

-- Voir l'en-tête.
function AnimationController.AfterGrab(callback: (fromGrab: boolean) -> ()): boolean
	if not grabPending() then
		callback(false)
		return false
	end
	table.insert(grabWaiters, callback)
	return true
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

local function setCarryAnim(name: string?, fadeTime: number?)
	if name == carryAnim then
		return
	end
	local previous = carryAnim
	carryAnim = name
	if previous then
		AnimationController.StopPlayer(previous, fadeTime)
	end
	if name then
		AnimationController.PlayPlayer(name, fadeTime)
	end
end

local function updateCarry(speed: number, fadeTime: number?)
	if carrying and carryReady then
		setCarryAnim(if speed > CARRY_RUN_SPEED then "CarryRun" else "CarryIdle", fadeTime)
	else
		setCarryAnim(nil)
	end
end

-- Colis ou objet porté (DEV-017) : true joue CarryIdle ou CarryRun selon la vitesse, et suit les
-- changements de vitesse ; false les arrête. Pendant un Grab, la boucle attend qu'il ait posé le
-- colis, puis prend sa suite en fondu (voir l'en-tête).
function AnimationController.SetCarrying(on: boolean)
	carrying = on
	carryToken += 1
	carryReady = false
	if not on then
		updateCarry(0)
		return
	end
	local token = carryToken
	AnimationController.AfterGrab(function(fromGrab: boolean)
		if token ~= carryToken or not carrying then
			return -- portage fini ou recommencé entre-temps
		end
		carryReady = true
		if fromGrab then
			AnimationController.StopPlayer(GRAB_ANIMATION, GRAB_BLEND)
		end
		updateCarry(horizontalSpeed(), if fromGrab then GRAB_BLEND else nil)
	end)
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

-- Répétition confirmée par le serveur. TrainingController a déjà lancé BenchLift au tap : on ne le
-- relance pas en pleine répétition (il repartirait du début, son marqueur Top deux fois).
local function onBenchReps()
	local reps = readBenchReps()
	local anims = current
	if reps > benchReps and not (anims and anims:IsPlaying("BenchLift")) then
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
	-- Grab a posé le colis sur la tête : la boucle de portage et le colis du porteur suivent (L-071).
	AnimationController.OnMarker(GRAB_ANIMATION, GRAB_MARKER, function()
		grabReached(grabPlays)
	end)

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
