--!strict
-- ChaseController (DEV-018, client) : la poursuite vue par le joueur poursuivi (Partie 1, 5.5).
--
-- Écoute ChaseState(active, guard) de GuardService. Pendant la poursuite, mesure à chaque image
-- la distance entre son HumanoidRootPart et celui du vigile (la même mesure que la capture,
-- vérifiée par le serveur). Le vigile peut arriver à nil (pas encore répliqué) ou disparaître un
-- moment (streaming) : il est alors retrouvé dans Workspace/ActiveGuards par l'attribut de cible
-- que GuardService pose sur son modèle. HudController lit GetDistance et IsClose : jauge GuardMeter
-- de UI_HUD et battements de cœur (DEV-021). En Studio, la sortie note le début et la fin de la
-- poursuite, et un repère « ♥ » quand la distance passe sous Balance.Guard.HeartbeatDistance (puis
-- quand elle en ressort).
--
-- Coup du vigile : quand GuardService pousse le joueur rattrapé (Attachment GuardKnockback posé
-- dans son HumanoidRootPart), joue Knockback puis Stunned jusqu'à la fin de l'étourdissement
-- (Balance.Guard.CatchStunDuration), via AnimationController s'il est là (rien sinon).
--
-- Écran de poursuite (liaison L-071, point 6 ; contrat 2.2) : PlayerGui/UI_Chase de Clément (copié
-- depuis StarterGui) est allumé pendant la poursuite et éteint sinon, avec l'entrée et la sortie de
-- Controllers/UI/Motion (Open et Close ; sans Motion, Enabled tout court). Seul Enabled de l'écran
-- est touché (plus l'échelle passagère de Motion) : ses noms internes ne sont pas fixés. Une nouvelle
-- copie de l'écran (ResetOnSpawn) est reprise dans les SCREEN_REFRESH s ; arrivée allumée de
-- StarterGui hors poursuite, elle s'éteint d'un coup. Pas encore livré : rien à l'écran (une ligne
-- en Studio, une fois). La musique de poursuite est à MusicController (il lit IsChased).
-- Alerte en deux paliers (vague 59, a192, L-184 point 2) : avec l'élément facultatif UI_Chase.HeistHint (texte
-- jaune discret de Clément, Config/HeistFeel.Alert.Hint), l'écran est aussi allumé pendant un braquage que personne
-- ne poursuit encore (un chrono de HeistController.GetTimers en cours) : seul HeistHint s'y voit (les autres enfants
-- de l'écran sont cachés, Visible gardé puis remis). Dès que le joueur est poursuivi, à l'image suivante : HeistHint
-- caché, tout le reste revient (RUN!, bords rouges qui battent : UiFeelController). Sans HeistHint : comme avant.
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

-- Ce que ce contrôleur utilise de Controllers/UI/Motion (a37).
type MotionApi = {
	Open: (gui: ScreenGui) -> (),
	Close: (gui: ScreenGui, after: (() -> ())?) -> (),
}

-- Mêmes noms que dans GuardService (serveur) : les changer dans les deux fichiers.
local KNOCKBACK_NAME = "GuardKnockback"
local ARREST_NAME = "GuardArrest" -- même nom dans GuardService (arrestation de nuit, L-076)
local ACTIVE_FOLDER = "ActiveGuards"
local TARGET_ATTRIBUTE = "TargetUserId"
-- Écran de poursuite de Clément (contrat 2.2, L-071 point 6).
local SCREEN_NAME = "UI_Chase"

-- V0 proposé, absent du doc.
local GUARD_WAIT = 3 -- vigile toujours introuvable au bout de ce délai : avertissement, en Studio (s)
local GUARD_SEARCH_INTERVAL = 0.1 -- recherche du vigile par son attribut tant qu'il manque (s)
local SCREEN_REFRESH = 0.2 -- écran de poursuite repris (nouvelle copie, ResetOnSpawn) toutes les 0,2 s

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
local chaseStartedAt = 0
local nextGuardSearch = 0
local guardMissingWarned = false
local stunToken = 0
local rootConnection: RBXScriptConnection? = nil
local motion: MotionApi? = nil
local motionSearched = false
local screenDirty = false -- la poursuite a commencé ou fini : écran revu à la prochaine image
local sinceScreen = 0
local screenMissingSaid = false
-- Vague 59 (L-184 point 2) : palier « braquage, pas encore repéré ».
type HeistApi = { GetTimers: () -> { [string]: number } }
local heist: HeistApi? = nil
local heistSearched = false
local hintName = "HeistHint" -- remplacé au démarrage par Config/HeistFeel.Alert.Hint
local hintSaved: { [GuiObject]: boolean } = {} -- Visible d'origine de ce que le palier 1 a changé

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
	screenDirty = true
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
	guard = if model and model:IsA("Model") then model :: Model else nil
	chaseStartedAt = os.clock()
	nextGuardSearch = 0
	guardMissingWarned = false
	if IS_STUDIO then
		print("[Poursuite] un vigile te poursuit !")
	end
end

-- Vigile absent côté client (pas encore répliqué à l'arrivée de ChaseState, ou sorti puis revenu
-- avec le streaming) : retrouvé par son attribut, au plus toutes les GUARD_SEARCH_INTERVAL s.
local function searchGuard(): Model?
	local now = os.clock()
	if now < nextGuardSearch then
		return nil
	end
	nextGuardSearch = now + GUARD_SEARCH_INTERVAL
	local found = findGuard()
	guard = found
	if found == nil and IS_STUDIO and not guardMissingWarned and now - chaseStartedAt >= GUARD_WAIT then
		guardMissingWarned = true
		warn("[Poursuite] vigile introuvable côté client (streaming ?) : distance inconnue")
	end
	return found
end

local function update()
	if not active then
		return
	end
	local model = guard
	if model == nil or model.Parent == nil then
		model = searchGuard()
	end
	local mine = rootOf(localPlayer.Character)
	local theirs = rootOf(model)
	if mine == nil or theirs == nil then
		distance = nil
		close = false
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
end

-- Écran de poursuite (L-071, point 6) ---------------------------------------------------------

-- Controllers/UI/Motion, s'il est là ; sinon nil (l'écran s'allume et s'éteint d'un coup).
local function motionApi(): MotionApi?
	if motionSearched then
		return motion
	end
	motionSearched = true
	local folder = script.Parent:FindFirstChild("UI")
	local module = if folder then folder:FindFirstChild("Motion") else nil
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			motion = result :: any
		end
	end
	return motion
end

-- Vague 59 : HeistController, s'il est là (chronos du braquage).
local function heistApi(): HeistApi?
	if heistSearched then
		return heist
	end
	heistSearched = true
	local module = script.Parent:FindFirstChild("HeistController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any).GetTimers) == "function" then
			heist = result :: any
		end
	end
	return heist
end

-- Un chrono de braquage est en cours chez le joueur (heure serveur).
local function heistRunning(): boolean
	local api = heistApi()
	if api == nil then
		return false
	end
	local ok, timers = pcall(api.GetTimers)
	if not ok or type(timers) ~= "table" then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	for _, endsAt in timers do
		if type(endsAt) == "number" and endsAt > now then
			return true
		end
	end
	return false
end

local function setVisible(object: GuiObject, visible: boolean)
	if hintSaved[object] == nil then
		hintSaved[object] = object.Visible
	end
	object.Visible = visible
end

local function restoreHint()
	for object, visible in hintSaved do
		if object.Parent ~= nil then
			object.Visible = visible
		end
	end
	table.clear(hintSaved)
end

-- Palier 1 (L-184 point 2) : seul `hint` visible dans l'écran (ses ancêtres gardés, le reste caché). Palier 2 :
-- hint caché, le reste remis.
local function showHintOnly(screen: ScreenGui, hint: GuiObject)
	local ancestors: { [Instance]: boolean } = {}
	local parent = hint.Parent
	while parent and parent ~= screen do
		ancestors[parent] = true
		parent = parent.Parent
	end
	local function walk(container: Instance)
		for _, child in container:GetChildren() do
			if child == hint then
				continue
			end
			if ancestors[child] then
				walk(child)
			elseif child:IsA("GuiObject") then
				setVisible(child :: GuiObject, false)
			end
		end
	end
	walk(screen)
	setVisible(hint, true)
end

-- Allume UI_Chase pendant la poursuite (et, avec HeistHint, pendant un braquage pas encore repéré), l'éteint sinon.
local function applyScreen()
	local gui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local screen = if gui then gui:FindFirstChild(SCREEN_NAME) else nil
	if screen == nil or not screen:IsA("ScreenGui") then
		if active and IS_STUDIO and not screenMissingSaid then
			screenMissingSaid = true
			print(`[Poursuite] {SCREEN_NAME} pas encore livré : rien à l'écran pendant la poursuite (L-071)`)
		end
		return
	end
	local chaseScreen = screen :: ScreenGui
	local api = motionApi()
	local hintObject = chaseScreen:FindFirstChild(hintName, true)
	local hint: GuiObject? = if hintObject and hintObject:IsA("GuiObject") then hintObject :: GuiObject else nil
	local sneaking = not active and hint ~= nil and heistRunning()
	if sneaking and hint then
		showHintOnly(chaseScreen, hint)
	elseif active then
		restoreHint() -- bascule du palier 1 au palier 2 dans la même image
		if hint then
			setVisible(hint, false)
		end
	elseif not chaseScreen.Enabled then
		restoreHint()
	end
	if active or sneaking then
		if api then
			api.Open(chaseScreen) -- déjà ouvert : rien
		elseif not chaseScreen.Enabled then
			chaseScreen.Enabled = true
		end
	elseif chaseScreen.Enabled then
		if api then
			-- sortie animée (ce que le palier 1 a caché est remis une fois l'écran éteint) ; arrivé allumé au
			-- repos : éteint d'un coup
			api.Close(chaseScreen, restoreHint)
		else
			chaseScreen.Enabled = false
			restoreHint()
		end
	end
end

local function stepScreen(deltaTime: number)
	sinceScreen += deltaTime
	if screenDirty or sinceScreen >= SCREEN_REFRESH then
		screenDirty = false
		sinceScreen = 0
		applyScreen()
	end
end

-- Coup du vigile ----------------------------------------------------------------------------

-- Chute (L-076, Clément) : Knockdown, puis GetUp ; elles remplissent l'étourdissement (2,4 s). Sans
-- Knockdown livrée : Knockback, puis Stunned jusqu'à la fin de l'étourdissement, comme avant.
local function onKnockback()
	local anim = animation
	if anim == nil then
		return
	end
	stunToken += 1
	local token = stunToken
	local fall = anim.PlayPlayer("Knockdown")
	if fall then
		fall.Stopped:Once(function()
			if token == stunToken then
				anim.PlayPlayer("GetUp")
			end
		end)
		return
	end
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
		elseif child.Name == ARREST_NAME then
			-- Arrestation de nuit (L-076) : le vigile joue Arrest, le joueur Arrested, puis il est renvoyé chez lui.
			stunToken += 1
			local anim = animation
			if anim then
				anim.PlayPlayer("Arrested")
			end
		end
	end)
end

function ChaseController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local balance = require(shared:WaitForChild("Config"):WaitForChild("Balance") :: ModuleScript) :: any
	heartbeatDistance = balance.Guard.HeartbeatDistance
	stunDuration = balance.Guard.CatchStunDuration
	local feelModule = shared:WaitForChild("Config"):FindFirstChild("HeistFeel") -- vague 59 (bancs sans lui : défaut)
	if feelModule and feelModule:IsA("ModuleScript") then
		local ok, feel = pcall(require, feelModule)
		if ok and type(feel) == "table" and type((feel :: any).Alert) == "table" then
			hintName = (feel :: any).Alert.Hint
		end
	end
	animation = loadAnimationController()

	localPlayer.CharacterAdded:Connect(watchCharacter)
	local character = localPlayer.Character
	if character then
		task.spawn(watchCharacter, character)
	end
	RunService.Heartbeat:Connect(update)
	RunService.Heartbeat:Connect(stepScreen)

	-- Peut attendre que le serveur ait créé les remotes.
	local net = require(shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	net.Client.ChaseState:Connect(onChaseState)
end

return ChaseController
