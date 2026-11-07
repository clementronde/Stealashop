--!strict
-- TrainingService (DEV-012) : tapis de course (Vitesse) et banc de musculation (Force)
-- (Partie 1, sections 5.1, 7.5 et 9.4).
--
-- Rôle :
--   - pose une invite (ProximityPrompt) sur le UsePoint de chaque machine taggée Treadmill ou
--     Bench d'une parcelle (PlayerPlot) de Workspace : « Run » ou « Lift »
--     (Config.Training), « Stop » pendant l'entraînement (textes en anglais, L-036) ;
--   - n'accepte que le propriétaire de la parcelle qui contient la machine (attribut
--     OwnerUserId de la parcelle, posé par PlotService) ;
--   - place le perso sur le UsePoint (debout, pieds sur le point, tourné vers son axe −Z)
--     et l'y garde : vitesse 0 par le modificateur « Training » de StatsService, sans
--     rotation. Le libère s'il saute (ou tombe, s'assoit…), s'il s'éloigne de plus de
--     LEAVE_DISTANCE, s'il réutilise l'invite ou passe sur l'autre machine, s'il meurt,
--     s'il n'est plus propriétaire de la parcelle ou s'il part ;
--   - crédite les gains par StatsService, qui les écrit dans le profil (sauvegardé).
--
-- Gains :
--   Tapis : chaque seconde passée sur le tapis rapporte GainPerSecond × M tapis en Vitesse
--     (M tapis = Formulas.MachineMultiplier avec le niveau Upgrades.Treadmill), même sans
--     rien faire (AFK autorisé, aucune limite de durée).
--     Interprétation V0 du « +50 % au tap » : une seconde rapporte × (1 + TapBonus) = × 1,5
--     si un TrainTap a été accepté dans la TapBonusWindow (1 s) qui précède son crédit.
--     Il suffit donc de taper au moins une fois par seconde ; taper plus vite ne donne rien
--     de plus, et au-delà de 6 taps/s Net refuse l'appel (Definitions, TrainTap).
--   Banc : chaque TrainTap est une répétition, au plus MaxRepsPerSecond (3) sur toute seconde
--     glissante (les autres sont ignorées). Une répétition rapporte GainPerRep × M banc en
--     Force (niveau Upgrades.Bench) et incrémente l'attribut BenchReps du Player.
--
-- Attributs du Player :
--   TrainingMachine  "Treadmill", "Bench" ou nil (pas sur une machine)
--   BenchReps        répétitions validées depuis l'arrivée sur le serveur (part de 0)
--
-- Remote : TrainTap (client → serveur, sans argument ; débit déjà limité par Net).
--
-- API (côté serveur) :
--   TrainingService.Stop(player)
--       Fait descendre le joueur de sa machine (sans effet s'il n'y est pas), pour un service
--       qui a besoin de lui libre (alerte de vol et batte automatique, 6.2 ; tutoriel…).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Config.Formulas)
local Training = require(ReplicatedStorage.Shared.Config.Training)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Net.RateLimiter)
local DataService = require(script.Parent.DataService)
local StatsService = require(script.Parent.StatsService)

type MachineKind = "Treadmill" | "Bench"
type Window = RateLimiter.Window

type Machine = {
	kind: MachineKind,
	plot: Instance, -- parcelle PlayerPlot qui contient la machine
	usePoint: Attachment,
	prompt: ProximityPrompt,
	occupant: Player?,
}

type Session = {
	machine: Machine,
	humanoid: Humanoid,
	root: BasePart,
	target: CFrame, -- place du HumanoidRootPart sur la machine
	startedAt: number,
	nextTick: number, -- prochain crédit du tapis
	lastTap: number, -- dernier TrainTap accepté
	gained: number, -- gagné pendant cette séance (pour la sortie de Studio)
	autoRotate: boolean, -- Humanoid.AutoRotate avant la séance
	connections: { RBXScriptConnection },
}

local IS_STUDIO = RunService:IsStudio()

-- Contrat (sections 2.1 et 10.4) : tags des machines et de la parcelle, point d'usage.
local TREADMILL_TAG = "Treadmill"
local BENCH_TAG = "Bench"
local PLOT_TAG = "PlayerPlot"
local USE_POINT = "UsePoint"
-- Attribut de la parcelle posé par PlotService : UserId du propriétaire, 0 = libre.
local OWNER_ATTRIBUTE = "OwnerUserId"
-- Clé du modificateur de StatsService qui immobilise le joueur pendant l'entraînement.
local SPEED_MODIFIER = "Training"
-- 5.1 : « +1 par seconde » : le tapis crédite seconde par seconde.
local TREADMILL_TICK = 1

-- V0 proposé, absent du doc : texte de l'invite pendant l'entraînement.
local STOP_TEXT = "Stop"
-- V0 proposé, absent du doc : maintien (s) pour arrêter, pour qu'un tap d'entraînement qui
-- tombe sur l'invite ne fasse pas descendre de la machine.
local STOP_HOLD_DURATION = 0.5
-- V0 proposé, absent du doc : distance (studs) entre le HumanoidRootPart et sa place sur la
-- machine au-delà de laquelle le joueur est libéré (poussé, téléporté, ou saut que l'état du
-- Humanoid n'a pas signalé : un saut monte d'environ 7 studs).
local LEAVE_DISTANCE = 3
-- V0 proposé, absent du doc : délai (s) après la mise en place pendant lequel ni l'état du
-- Humanoid ni la distance ne libèrent le joueur (la téléportation met un instant à arriver
-- chez le client, qui possède la physique de son perso).
local SETTLE_TIME = 0.5
-- V0 proposé, absent du doc : marge (studs) ajoutée à la portée de l'invite pour accepter le
-- démarrage. Empêche de déclencher l'invite de loin pour se téléporter chez soi.
local START_TOLERANCE = 4
-- V0 proposé, absent du doc : message au joueur qui essaie la machine d'un autre.
local NOT_OWNER_MESSAGE = "You can only train in your own shop."

-- États du Humanoid qui font descendre de la machine : saut, chute, siège, nage…
local LEAVE_STATES: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.Flying] = true,
}

local TrainingService = {}

local machines: { [Instance]: Machine } = {}
local sessions: { [Player]: Session } = {}
local benchWindows: { [Player]: Window } = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[TrainingService] {message}`)
	end
end

local function promptText(kind: MachineKind): string
	return if kind == "Treadmill" then Training.Treadmill.Prompt else Training.Bench.Prompt
end

local function isOwner(player: Player, machine: Machine): boolean
	return machine.plot:GetAttribute(OWNER_ATTRIBUTE) == player.UserId
end

-- Multiplicateur de gain de la machine (5.1, 7.5) et niveau de son amélioration.
local function machineMultiplier(player: Player, kind: MachineKind): (number, number)
	local data = DataService.Get(player)
	local level = if data == nil then 0 elseif kind == "Treadmill" then data.Upgrades.Treadmill else data.Upgrades.Bench
	return Formulas.MachineMultiplier(kind, level), level
end

-- Place du HumanoidRootPart : debout, pieds sur le UsePoint, tourné vers l'avant du UsePoint
-- (son axe −Z, LookVector) ramené à l'horizontale.
local function standingCFrame(usePoint: Attachment, humanoid: Humanoid, root: BasePart): CFrame
	local point = usePoint.WorldCFrame
	local look = point.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	-- R15 : le centre du HumanoidRootPart est à HipHeight + la moitié de sa hauteur au-dessus
	-- du sol. R6 : HipHeight vaut 0 et les jambes font 2 studs.
	local height = humanoid.HipHeight + root.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		height += 2
	end
	local position = point.Position + Vector3.new(0, height, 0)
	return CFrame.lookAt(position, position + look.Unit)
end

local function stop(player: Player, reason: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	for _, connection in session.connections do
		connection:Disconnect()
	end
	local machine = session.machine
	if machine.occupant == player then
		machine.occupant = nil
		machine.prompt.ActionText = promptText(machine.kind)
		machine.prompt.HoldDuration = 0
	end
	StatsService.SetSpeedModifier(player, SPEED_MODIFIER, nil)
	if session.humanoid.Parent ~= nil then
		session.humanoid.AutoRotate = session.autoRotate
	end
	if player.Parent == Players then
		player:SetAttribute("TrainingMachine", nil)
	end
	local what = if machine.kind == "Treadmill" then "le tapis" else "le banc"
	local stat = if machine.kind == "Treadmill" then "Vitesse" else "Force"
	log(
		`{player.Name} quitte {what} ({reason}) : +{string.format("%.2f", session.gained)} {stat} en {string.format("%.1f", os.clock() - session.startedAt)} s`
	)
end

local function start(player: Player, machine: Machine)
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 or humanoid.SeatPart ~= nil then
		return
	end
	local root = humanoid.RootPart
	if root == nil then
		return
	end
	local reach = machine.prompt.MaxActivationDistance + START_TOLERANCE
	if (root.Position - machine.usePoint.WorldPosition).Magnitude > reach then
		return
	end

	local now = os.clock()
	local session: Session = {
		machine = machine,
		humanoid = humanoid,
		root = root,
		target = standingCFrame(machine.usePoint, humanoid, root),
		startedAt = now,
		nextTick = now + TREADMILL_TICK,
		lastTap = -math.huge,
		gained = 0,
		autoRotate = humanoid.AutoRotate,
		connections = {},
	}
	sessions[player] = session
	machine.occupant = player

	character:PivotTo(session.target)
	StatsService.SetSpeedModifier(player, SPEED_MODIFIER, 0)
	humanoid.AutoRotate = false
	machine.prompt.ActionText = STOP_TEXT
	machine.prompt.HoldDuration = STOP_HOLD_DURATION
	player:SetAttribute("TrainingMachine", machine.kind)

	-- Les événements arrivent en différé : ils ne doivent arrêter que cette séance-ci.
	local function leave(reason: string)
		if sessions[player] == session then
			stop(player, reason)
		end
	end
	table.insert(
		session.connections,
		humanoid.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
			if LEAVE_STATES[new] and os.clock() - session.startedAt >= SETTLE_TIME then
				leave(`état {new.Name}`)
			end
		end)
	)
	table.insert(
		session.connections,
		humanoid.Died:Connect(function()
			leave("mort")
		end)
	)
	table.insert(
		session.connections,
		player.CharacterRemoving:Connect(function()
			leave("perso retiré")
		end)
	)

	local multiplier, level = machineMultiplier(player, machine.kind)
	log(
		`{player.Name} monte sur {if machine.kind == "Treadmill" then "le tapis" else "le banc"} (niveau {level}, × {multiplier})`
	)
end

local function onTriggered(player: Player, machine: Machine)
	local current = sessions[player]
	if current and current.machine == machine then
		stop(player, "invite")
		return
	end
	if not isOwner(player, machine) then
		log(
			`{player.Name} ne peut pas s'entraîner sur {machine.plot:GetFullName()} : OwnerUserId = {machine.plot:GetAttribute(OWNER_ATTRIBUTE)}, son UserId = {player.UserId}`
		)
		Net.Server.Notify:Fire(player, NOT_OWNER_MESSAGE, "Warning")
		return
	end
	if not DataService.IsLoaded(player) then
		return
	end
	if machine.occupant ~= nil and machine.occupant ~= player then
		return -- ne devrait pas arriver : seul le propriétaire s'entraîne sur sa parcelle
	end
	if current then
		stop(player, "autre machine")
	end
	start(player, machine)
end

-- Tapis : crédite chaque seconde écoulée (plusieurs d'un coup si le serveur a ralenti).
local function creditTreadmill(player: Player, session: Session, now: number)
	local settings = Training.Treadmill
	while now >= session.nextTick do
		local tickAt = session.nextTick
		session.nextTick += TREADMILL_TICK
		local bonus = if tickAt - session.lastTap <= settings.TapBonusWindow then 1 + settings.TapBonus else 1
		local gain = settings.GainPerSecond * TREADMILL_TICK * machineMultiplier(player, "Treadmill") * bonus
		-- nil : profil plus chargé, rien n'est crédité
		if StatsService.AddSpeed(player, gain) ~= nil then
			session.gained += gain
		end
	end
end

-- Raison de libérer le joueur, ou nil s'il reste sur la machine.
local function leaveReason(player: Player, session: Session, now: number): string?
	if player.Parent ~= Players or session.humanoid.Health <= 0 or session.root.Parent == nil then
		return "perso absent"
	end
	if not isOwner(player, session.machine) then
		return "parcelle perdue"
	end
	if now - session.startedAt >= SETTLE_TIME and (session.root.Position - session.target.Position).Magnitude > LEAVE_DISTANCE then
		return "éloigné de la machine"
	end
	return nil
end

local function update()
	local now = os.clock()
	for player, session in sessions do
		local reason = leaveReason(player, session, now)
		if reason then
			stop(player, reason)
		elseif session.machine.kind == "Treadmill" then
			creditTreadmill(player, session, now)
		end
	end
end

local function onTap(player: Player)
	local session = sessions[player]
	if session == nil then
		return -- pas sur une machine : tap ignoré
	end
	local now = os.clock()
	if session.machine.kind == "Treadmill" then
		session.lastTap = now
		return
	end

	-- Banc : 1 tap = 1 répétition, au plus MaxRepsPerSecond sur toute seconde glissante.
	local window = benchWindows[player] or RateLimiter.new(Training.Bench.MaxRepsPerSecond)
	benchWindows[player] = window
	if not RateLimiter.allow(window, now) then
		return
	end
	local gain = Training.Bench.GainPerRep * machineMultiplier(player, "Bench")
	if StatsService.AddStrength(player, gain) == nil then
		return
	end
	session.gained += gain
	local reps = player:GetAttribute("BenchReps")
	player:SetAttribute("BenchReps", (if type(reps) == "number" then reps else 0) + 1)
end

-- Première parcelle (tag PlayerPlot) parmi les ancêtres de la machine, dans Workspace.
local function findPlot(model: Instance): Instance?
	local current = model.Parent
	while current ~= nil and current ~= workspace do
		if CollectionService:HasTag(current, PLOT_TAG) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function register(model: Instance, kind: MachineKind)
	if machines[model] or not model:IsDescendantOf(workspace) then
		return
	end
	local plot = findPlot(model)
	if plot == nil then
		return -- hors parcelle (_INBOX_CLEMENT, modèle de référence…) : pas d'invite
	end
	local usePoint = model:FindFirstChild(USE_POINT, true)
	if usePoint == nil or not usePoint:IsA("Attachment") then
		warn(`[TrainingService] {model:GetFullName()} : pas d'Attachment {USE_POINT} (contrat 10.4), pas d'invite`)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainingPrompt"
	prompt.ActionText = promptText(kind)
	prompt.ObjectText = Upgrades.ById[kind].DisplayName
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false

	local machine: Machine = {
		kind = kind,
		plot = plot,
		usePoint = usePoint,
		prompt = prompt,
		occupant = nil,
	}
	-- Connexion coupée par prompt:Destroy().
	prompt.Triggered:Connect(function(player: Player)
		onTriggered(player, machine)
	end)
	prompt.Parent = usePoint
	machines[model] = machine
end

local function unregister(model: Instance)
	local machine = machines[model]
	if machine == nil then
		return
	end
	machines[model] = nil
	local occupant = machine.occupant
	if occupant then
		stop(occupant, "machine retirée")
	end
	machine.prompt:Destroy()
end

local function watchTag(tag: string, kind: MachineKind)
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(model: Instance)
		register(model, kind)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(unregister)
	for _, model in CollectionService:GetTagged(tag) do
		register(model, kind)
	end
end

function TrainingService.Stop(player: Player)
	stop(player, "demandé par un service")
end

function TrainingService.Init()
	watchTag(TREADMILL_TAG, "Treadmill")
	watchTag(BENCH_TAG, "Bench")

	Net.Server.TrainTap:Connect(onTap)
	RunService.Heartbeat:Connect(update)

	DataService.OnProfileLoaded(function(player: Player)
		if player:GetAttribute("BenchReps") == nil then
			player:SetAttribute("BenchReps", 0)
		end
	end)
	-- Avant la libération du profil : la séance se termine pendant que l'écriture compte encore.
	DataService.OnProfileReleasing(function(player: Player)
		stop(player, "départ")
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		stop(player, "départ")
		benchWindows[player] = nil
	end)
end

return TrainingService
