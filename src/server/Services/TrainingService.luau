--!strict
-- TrainingService (DEV-012) : tapis de course (Vitesse) et banc de musculation (Force)
-- (Partie 1, sections 5.1, 7.5 et 9.4 ; tapis sans invite : liaison L-071, point 3).
--
-- Rôle :
--   - tapis (tag Treadmill d'une parcelle PlayerPlot de Workspace) : marcher dessus fait
--     s'entraîner, sans invite (L-071). Le serveur seul décide : TREADMILL_CHECK_INTERVAL s (comme
--     le tapis de caisse de DisplayService), il regarde où est le HumanoidRootPart de chaque joueur.
--     Debout sur la bande (pièce ou modèle Belt du tapis, contrat 10.4 ; sans elle, une zone de
--     FALLBACK_BELT_SIZE posée sur le UsePoint), presque immobile (vitesse ≤ STILL_SPEED) pendant
--     START_DWELL s, il commence la séance : placé sur le UsePoint (debout, tourné vers son axe −Z),
--     sans être immobilisé (ni vitesse 0, ni rotation coupée) : il descend en marchant. Traverser
--     la bande sans s'y arrêter ne déclenche rien. Fin de la séance : HumanoidRootPart hors de la
--     bande (son emprise élargie de LEAVE_MARGIN, jusqu'à STAY_ABOVE au-dessus : un saut sur place
--     ne coupe rien, un saut hors du tapis si), mort, état Seated, Swimming, Ragdoll…, parcelle
--     perdue, départ, ou TrainingService.Stop. Une séance coupée alors qu'il est encore sur la bande
--     (Stop, état…) ne reprend qu'après être descendu puis remonté ;
--   - banc (tag Bench) : invite (ProximityPrompt) « Lift » (Config.Training) sur son UsePoint,
--     « Stop » pendant l'entraînement (textes en anglais, L-036), comme avant L-071. Le joueur est
--     placé sur le UsePoint et y est gardé : vitesse 0 par le modificateur « Training » de
--     StatsService, sans rotation. Libéré s'il saute (ou tombe, s'assoit…), s'il s'éloigne de plus de
--     LEAVE_DISTANCE, s'il réutilise l'invite, meurt, perd sa parcelle ou part ;
--   - les deux : seul le propriétaire de la parcelle qui contient la machine s'y entraîne (attribut
--     OwnerUserId de la parcelle, posé par PlotService) ; un autre joueur reçoit NOT_OWNER_MESSAGE
--     (au tapis : une fois par arrêt sur la bande) ;
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
--   TrainingMachine  "Treadmill", "Bench" ou nil (pas sur une machine) : AnimationController
--                    joue TreadmillRun ou BenchIdle tant qu'il est posé, TutorialService compte
--                    le temps d'entraînement
--   BenchReps        répétitions validées depuis l'arrivée sur le serveur (part de 0)
--
-- Remote : TrainTap (client → serveur, sans argument ; débit déjà limité par Net).
--
-- API (côté serveur) :
--   TrainingService.Stop(player)
--       Fait descendre le joueur de sa machine (sans effet s'il n'y est pas), pour un service
--       qui a besoin de lui libre (alerte de vol et batte automatique, 6.2 ; tutoriel…). Au tapis,
--       la séance ne reprend qu'une fois descendu puis remonté.
--   TrainingService.GetGainMultiplier(player, kind) -> number
--       Point d'accroche (DEV-100) : multiplie chaque gain du tapis (kind = "Treadmill") et du banc
--       ("Bench"), en plus de M tapis et M banc ; 1 par défaut. MonetizationService le remplace en
--       gardant celui d'avant (gamepass ×2 Entraînement). Ne doit pas yield ; une erreur ou une
--       valeur qui n'est pas un nombre fini > 0 compte pour 1.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Config.Formulas)
local Training = require(ReplicatedStorage.Shared.Config.Training)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Net.RateLimiter)
local AntiCheatService = require(script.Parent.AntiCheatService)
local DataService = require(script.Parent.DataService)
local StatsService = require(script.Parent.StatsService)

type MachineKind = "Treadmill" | "Bench"
type Window = RateLimiter.Window

type Machine = {
	kind: MachineKind,
	plot: Instance, -- parcelle PlayerPlot qui contient la machine
	usePoint: Attachment,
	belt: Instance?, -- tapis : sa bande (pièce ou modèle Belt) ; nil : zone posée sur le UsePoint
	prompt: ProximityPrompt?, -- banc seulement : le tapis n'a plus d'invite (L-071)
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
	autoRotate: boolean, -- Humanoid.AutoRotate avant la séance (remis à la fin, au banc)
	connections: { RBXScriptConnection },
}

-- Joueur arrêté sur la bande d'un tapis, pas encore en séance (START_DWELL).
type Standing = { machine: Machine, since: number }

local IS_STUDIO = RunService:IsStudio()

-- Contrat (sections 2.1 et 10.4) : tags des machines et de la parcelle, point d'usage, bande.
local TREADMILL_TAG = "Treadmill"
local BENCH_TAG = "Bench"
local PLOT_TAG = "PlayerPlot"
local USE_POINT = "UsePoint"
local BELT = "Belt"
-- Attribut de la parcelle posé par PlotService : UserId du propriétaire, 0 = libre.
local OWNER_ATTRIBUTE = "OwnerUserId"
-- Clé du modificateur de StatsService qui immobilise le joueur au banc.
local SPEED_MODIFIER = "Training"
-- 5.1 : « +1 par seconde » : le tapis crédite seconde par seconde.
local TREADMILL_TICK = 1

-- V0 proposé, absent du doc : texte de l'invite du banc pendant l'entraînement.
local STOP_TEXT = "Stop"
-- V0 proposé, absent du doc : maintien (s) pour arrêter, pour qu'un tap d'entraînement qui
-- tombe sur l'invite ne fasse pas descendre de la machine.
local STOP_HOLD_DURATION = 0.5
-- V0 proposé, absent du doc : distance (studs) entre le HumanoidRootPart et sa place sur le banc
-- au-delà de laquelle le joueur est libéré (poussé, téléporté, ou saut que l'état du Humanoid n'a
-- pas signalé : un saut monte d'environ 7 studs).
local LEAVE_DISTANCE = 3
-- V0 proposé, absent du doc : délai (s) après la mise en place pendant lequel ni l'état du
-- Humanoid ni la position ne libèrent le joueur (la téléportation met un instant à arriver
-- chez le client, qui possède la physique de son perso).
local SETTLE_TIME = 0.5
-- V0 proposé, absent du doc : marge (studs) ajoutée à la portée de l'invite du banc pour accepter
-- le démarrage. Empêche de déclencher l'invite de loin pour se téléporter chez soi.
local START_TOLERANCE = 4
-- V0 proposé, absent du doc : message au joueur qui essaie la machine d'un autre.
local NOT_OWNER_MESSAGE = "You can only train in your own shop."

-- Tapis sans invite (L-071, point 3). V0 proposés, absents du doc :
-- cadence du contrôle « debout sur la bande » (s), comme le tapis de caisse de DisplayService ;
local TREADMILL_CHECK_INTERVAL = 0.1
-- temps (s) debout et presque immobile sur la bande avant le début de la séance : traverser la
-- bande en courant ne déclenche rien ;
local START_DWELL = 0.25
-- vitesse (studs/s, HumanoidRootPart) au-dessous de laquelle le joueur est « arrêté » sur la bande ;
local STILL_SPEED = 2
-- marges (studs) autour de l'emprise de la bande : pour commencer (le HumanoidRootPart au-dessus
-- de la bande), et pour rester (plus large : un pas de côté ne coupe pas la séance) ;
local START_MARGIN = 0.25
local LEAVE_MARGIN = 1
-- hauteur (studs) du HumanoidRootPart au-dessus du dessus de la bande : debout pour commencer
-- (celui d'un R15 debout est à environ 3 studs du sol), et pour rester (un saut monte d'environ
-- 7 studs : sauter sur place ne coupe pas la séance) ; et tolérance sous le dessus ;
local STAND_ABOVE = 6
local STAY_ABOVE = 12
local BELT_BELOW = 1
-- zone posée sur le UsePoint (centre du dessus) pour un tapis sans Belt (avertissement au démarrage).
local FALLBACK_BELT_SIZE = Vector3.new(3, 0.2, 3)

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
-- Au tapis, sauter sur place ne fait pas descendre : seule la position compte pour le saut.
local TREADMILL_LEAVE_STATES: { [Enum.HumanoidStateType]: boolean } = {}
for state in LEAVE_STATES do
	if state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall then
		TREADMILL_LEAVE_STATES[state] = true
	end
end

local TrainingService = {}

local machines: { [Instance]: Machine } = {}
local sessions: { [Player]: Session } = {}
local benchWindows: { [Player]: Window } = {}
-- Tapis : joueurs arrêtés sur une bande (avant START_DWELL), et le tapis dont chaque joueur doit
-- descendre avant une nouvelle séance (séance coupée sur sa bande, refus).
local standing: { [Player]: Standing } = {}
local blocked: { [Player]: Machine } = {}
local treadmillClock = 0
local gainHookWarned = false

local function log(message: string)
	if IS_STUDIO then
		print(`[TrainingService] {message}`)
	end
end

local function isOwner(player: Player, machine: Machine): boolean
	return machine.plot:GetAttribute(OWNER_ATTRIBUTE) == player.UserId
end

local function machineName(kind: MachineKind): string
	return if kind == "Treadmill" then "le tapis" else "le banc"
end

-- Multiplicateur de l'accroche GetGainMultiplier (1 si elle échoue ou renvoie une valeur invalide).
local function gainMultiplier(player: Player, kind: MachineKind): number
	local ok, value = pcall(TrainingService.GetGainMultiplier, player, kind)
	if ok and type(value) == "number" and value == value and value > 0 and value < math.huge then
		return value
	end
	if not gainHookWarned then
		gainHookWarned = true
		warn(`[TrainingService] GetGainMultiplier : erreur ou valeur invalide ({value}), multiplicateur 1 utilisé`)
	end
	return 1
end

-- Multiplicateur de gain de la machine (5.1, 7.5 ; bonus de GetGainMultiplier compris) et niveau de
-- son amélioration.
local function machineMultiplier(player: Player, kind: MachineKind): (number, number)
	local data = DataService.Get(player)
	local level = if data == nil then 0 elseif kind == "Treadmill" then data.Upgrades.Treadmill else data.Upgrades.Bench
	return Formulas.MachineMultiplier(kind, level) * gainMultiplier(player, kind), level
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

-- Boîte de la bande d'un tapis (CFrame du centre, taille) : la pièce Belt, la boîte du modèle Belt,
-- sinon FALLBACK_BELT_SIZE posée sur le UsePoint (le dessus de la zone au niveau du point).
local function beltBox(machine: Machine): (CFrame, Vector3)
	local belt = machine.belt
	if belt and belt.Parent ~= nil then
		if belt:IsA("BasePart") then
			return belt.CFrame, belt.Size
		elseif belt:IsA("Model") then
			return belt:GetBoundingBox()
		end
	end
	return machine.usePoint.WorldCFrame * CFrame.new(0, -FALLBACK_BELT_SIZE.Y / 2, 0), FALLBACK_BELT_SIZE
end

-- `position` (celle d'un HumanoidRootPart) est-elle au-dessus de la bande : dans son emprise élargie
-- de `margin`, de BELT_BELOW sous son dessus à `above` au-dessus ?
local function overBelt(machine: Machine, position: Vector3, margin: number, above: number): boolean
	local cframe, size = beltBox(machine)
	local p = cframe:PointToObjectSpace(position)
	local half = size / 2
	return math.abs(p.X) <= half.X + margin
		and math.abs(p.Z) <= half.Z + margin
		and p.Y >= half.Y - BELT_BELOW
		and p.Y <= half.Y + above
end

-- HumanoidRootPart et Humanoid vivant du joueur, sinon nil.
local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end
	local root = humanoid.RootPart
	if root == nil then
		return nil, nil
	end
	return root, humanoid
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
		local prompt = machine.prompt
		if prompt then
			prompt.ActionText = Training.Bench.Prompt
			prompt.HoldDuration = 0
		end
	end
	if machine.kind == "Treadmill" then
		-- Encore sur la bande (Stop, état…) : il en descend avant une nouvelle séance. Déjà descendu :
		-- levé au contrôle suivant.
		if player.Parent == Players then
			blocked[player] = machine
		end
	else
		StatsService.SetSpeedModifier(player, SPEED_MODIFIER, nil)
		if session.humanoid.Parent ~= nil then
			session.humanoid.AutoRotate = session.autoRotate
		end
	end
	if player.Parent == Players then
		player:SetAttribute("TrainingMachine", nil)
	end
	local stat = if machine.kind == "Treadmill" then "Vitesse" else "Force"
	log(
		`{player.Name} quitte {machineName(machine.kind)} ({reason}) : +{string.format("%.2f", session.gained)} {stat} en {string.format("%.1f", os.clock() - session.startedAt)} s`
	)
end

-- Commence la séance. Renvoie false (rien ne change) si le personnage ne peut pas s'y mettre.
local function start(player: Player, machine: Machine): boolean
	local root, humanoid = bodyOf(player)
	if root == nil or humanoid == nil or humanoid.SeatPart ~= nil or player.Character == nil then
		return false
	end
	local character = player.Character :: Model
	local prompt = machine.prompt
	if prompt then
		-- Banc : l'invite a été déclenchée près de la machine (le tapis, lui, vient de vérifier la bande).
		local reach = prompt.MaxActivationDistance + START_TOLERANCE
		if (root.Position - machine.usePoint.WorldPosition).Magnitude > reach then
			return false
		end
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
	standing[player] = nil

	AntiCheatService.Allow(player, 0, "TrainingService (placement sur la machine)") -- déplacement du code (DEV-060)
	character:PivotTo(session.target)
	if prompt then
		-- Banc : gardé en place, sans rotation ; l'invite sert à descendre. Au tapis, rien de tout
		-- cela : il reste tourné comme on l'a posé tant qu'il ne bouge pas, et se tourne en descendant.
		StatsService.SetSpeedModifier(player, SPEED_MODIFIER, 0)
		humanoid.AutoRotate = false
		prompt.ActionText = STOP_TEXT
		prompt.HoldDuration = STOP_HOLD_DURATION
	end
	player:SetAttribute("TrainingMachine", machine.kind)

	-- Les événements arrivent en différé : ils ne doivent arrêter que cette séance-ci.
	local function leave(reason: string)
		if sessions[player] == session then
			stop(player, reason)
		end
	end
	local leaveStates = if machine.kind == "Treadmill" then TREADMILL_LEAVE_STATES else LEAVE_STATES
	table.insert(
		session.connections,
		humanoid.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
			if leaveStates[new] and os.clock() - session.startedAt >= SETTLE_TIME then
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
	log(`{player.Name} monte sur {machineName(machine.kind)} (niveau {level}, × {multiplier})`)
	return true
end

-- Invite du banc.
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

-- Tapis : un joueur vient de rester START_DWELL s arrêté sur la bande de `machine`. Une seule
-- tentative par arrêt : refusé (pas propriétaire, machine prise…) ou parti en séance, il doit
-- descendre de ce tapis avant la suivante. Profil pas encore chargé : on réessaie au contrôle suivant.
local function tryTreadmill(player: Player, machine: Machine)
	if not isOwner(player, machine) then
		blocked[player] = machine
		log(
			`{player.Name} ne peut pas s'entraîner sur {machine.plot:GetFullName()} : OwnerUserId = {machine.plot:GetAttribute(OWNER_ATTRIBUTE)}, son UserId = {player.UserId}`
		)
		Net.Server.Notify:Fire(player, NOT_OWNER_MESSAGE, "Warning")
		return
	end
	if not DataService.IsLoaded(player) then
		return
	end
	if (machine.occupant ~= nil and machine.occupant ~= player) or not start(player, machine) then
		blocked[player] = machine
	end
end

-- Le tapis dont la bande porte `position` (celle d'un HumanoidRootPart debout : START_MARGIN,
-- STAND_ABOVE), ou nil.
local function treadmillUnder(position: Vector3): Machine?
	for _, machine in machines do
		if machine.kind == "Treadmill" and overBelt(machine, position, START_MARGIN, STAND_ABOVE) then
			return machine
		end
	end
	return nil
end

-- Contrôle des tapis (TREADMILL_CHECK_INTERVAL) : qui s'arrête sur une bande commence sa séance.
local function checkTreadmills(now: number)
	for _, player in Players:GetPlayers() do
		if sessions[player] then
			standing[player] = nil
			continue -- déjà en séance (tapis : leaveReason la surveille ; banc : il y reste)
		end
		local root, humanoid = bodyOf(player)
		local machine = if root then treadmillUnder(root.Position) else nil
		if blocked[player] ~= machine then
			blocked[player] = nil -- descendu de ce tapis (ou plus de personnage) : la prochaine montée compte
		end
		if root == nil or humanoid == nil or machine == nil then
			standing[player] = nil
			continue
		end
		if blocked[player] or humanoid.SeatPart ~= nil or root.AssemblyLinearVelocity.Magnitude > STILL_SPEED then
			standing[player] = nil
			continue
		end
		local stand = standing[player]
		if stand == nil or stand.machine ~= machine then
			standing[player] = { machine = machine, since = now }
		elseif now - stand.since >= START_DWELL then
			standing[player] = nil
			tryTreadmill(player, machine)
		end
	end
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
	if now - session.startedAt < SETTLE_TIME then
		return nil
	end
	local position = session.root.Position
	if session.machine.kind == "Treadmill" then
		if not overBelt(session.machine, position, LEAVE_MARGIN, STAY_ABOVE) then
			return "descendu du tapis"
		end
	elseif (position - session.target.Position).Magnitude > LEAVE_DISTANCE then
		return "éloigné de la machine"
	end
	return nil
end

local function update(dt: number)
	local now = os.clock()
	for player, session in sessions do
		local reason = leaveReason(player, session, now)
		if reason then
			stop(player, reason)
		elseif session.machine.kind == "Treadmill" then
			creditTreadmill(player, session, now)
		end
	end
	treadmillClock += dt
	if treadmillClock >= TREADMILL_CHECK_INTERVAL then
		-- Le reste est gardé (cadence juste en moyenne), sans rafale après un ralentissement.
		treadmillClock = math.min(treadmillClock - TREADMILL_CHECK_INTERVAL, TREADMILL_CHECK_INTERVAL)
		checkTreadmills(now)
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
		return -- hors parcelle (_INBOX_CLEMENT, modèle de référence…) : rien
	end
	local usePoint = model:FindFirstChild(USE_POINT, true)
	if usePoint == nil or not usePoint:IsA("Attachment") then
		warn(`[TrainingService] {model:GetFullName()} : pas d'Attachment {USE_POINT} (contrat 10.4), machine inutilisable`)
		return
	end

	local machine: Machine = {
		kind = kind,
		plot = plot,
		usePoint = usePoint,
		belt = nil,
		prompt = nil,
		occupant = nil,
	}
	if kind == "Treadmill" then
		-- Pas d'invite (L-071) : la bande suffit.
		local belt = model:FindFirstChild(BELT, true)
		if belt and (belt:IsA("BasePart") or belt:IsA("Model")) then
			machine.belt = belt
		else
			warn(
				`[TrainingService] {model:GetFullName()} : pas de pièce {BELT} (contrat 10.4) : on s'entraîne sur une zone de {FALLBACK_BELT_SIZE.X} × {FALLBACK_BELT_SIZE.Z} studs autour du {USE_POINT}`
			)
		end
	else
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TrainingPrompt"
		prompt.ActionText = Training.Bench.Prompt
		prompt.ObjectText = Upgrades.ById[kind].DisplayName
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		-- Connexion coupée par prompt:Destroy().
		prompt.Triggered:Connect(function(player: Player)
			onTriggered(player, machine)
		end)
		prompt.Parent = usePoint
		machine.prompt = prompt
	end
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
	for player, stand in standing do
		if stand.machine == machine then
			standing[player] = nil
		end
	end
	local prompt = machine.prompt
	if prompt then
		prompt:Destroy()
	end
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
	-- Au tapis, même pas encore en séance (arrêté sur la bande) : il en descend avant la prochaine.
	local root = bodyOf(player)
	local under = if root and player.Parent == Players then treadmillUnder(root.Position) else nil
	if under then
		blocked[player] = under
	end
	standing[player] = nil
	stop(player, "demandé par un service")
end

function TrainingService.GetGainMultiplier(_player: Player, _kind: MachineKind): number
	return 1
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
		standing[player] = nil
		blocked[player] = nil
	end)
end

return TrainingService
