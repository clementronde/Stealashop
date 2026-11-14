--!strict
-- TrainingService (DEV-012) : tapis de course (Vitesse)
-- (Partie 1, sections 5.1, 7.5 et 9.4 ; tapis sans invite : liaison L-071, point 3 ; par zone : L-093, point 1).
-- Rééquilibrage v2 (Cantin, 2026-11-14) : PLUS DE BANC. Un banc resté dans une parcelle est du décor (on n'y
-- monte pas, il ne rapporte rien, sa barre ne bouge pas) ; son tag Bench ne sert plus qu'à couper l'invite
-- « Lift » que son modèle porterait. La Force n'existe
-- plus : les dégâts d'un coup sont arme × aura (Formulas.HitDamage).
--
-- Rôle :
--   - entrée par zone, sans invite ni clic (L-093, point 1). Zone du tapis, bande et place du joueur :
--     Shared/TrainingZone (mêmes calculs chez le client, qui se met en place sans attendre :
--     TrainingController). Le serveur seul décide : à chaque Heartbeat (CHECK_INTERVAL = 0), il regarde où
--     est le HumanoidRootPart de chaque joueur. Dans la zone (même en marchant, sans attente :
--     START_DWELL = 0, a115), le joueur monte sur le tapis : placé sur le UsePoint (debout, tourné vers son
--     axe −Z). Zones qui se recouvrent : la machine au UsePoint le plus proche ;
--   - le tapis garde le joueur en place : vitesse 0 par le modificateur « Training » de StatsService, sans
--     rotation (a115 : il ne glisse plus hors de la bande en bougeant un peu) ;
--   - tapis (tag Treadmill d'une parcelle PlayerPlot de Workspace) : il descend dès qu'il bouge (touche
--     de déplacement ou joystick) : le client envoie TrainLeave (a115). Fin de la séance aussi :
--     HumanoidRootPart hors de la bande élargie de LEAVE_MARGIN, jusqu'à STAY_ABOVE au-dessus (un saut
--     sur place ne coupe rien, poussé hors du tapis si), mort, état Seated, Swimming, Ragdoll…,
--     parcelle perdue, départ, machine retirée (variante posée par MachineVariantService : il est remis
--     sur la nouvelle), ou TrainingService.Stop ;
--   - pas de remontée en boucle : une séance finie (descendu, Stop, état…) ou un refus bloque ce tapis
--     pour ce joueur. Débloqué s'il sort de la zone (son emprise au sol, à n'importe quelle hauteur :
--     sauter sur place ne débloque rien), ou (a115, la zone de Clément couvre tout le modèle) s'il quitte
--     le cœur de la machine (TrainingZone.inCore : la bande du tapis) puis y revient : il remonte aussitôt ;
--   - seul le propriétaire de la parcelle qui contient le tapis s'y entraîne (attribut OwnerUserId de la
--     parcelle, posé par PlotService) ; un autre joueur est refusé et reçoit NOT_OWNER_MESSAGE, au plus
--     une fois toutes les NOT_OWNER_COOLDOWN s (on passe souvent à côté des machines des autres). Porter
--     un colis n'empêche pas de s'entraîner (règle inchangée) ;
--   - crédite les gains par StatsService, qui les écrit dans le profil (sauvegardé).
--
-- Gains (v2) : chaque seconde passée sur le tapis rapporte Formulas.TreadmillGain(niveau) en Vitesse, soit
--   2^(niveau affiché − 1) : 1 par seconde au niveau 1 (profil neuf, Upgrades.Treadmill = 0), ×2 à chaque
--   niveau, jusqu'à 524 288 au niveau 20 ; × GetGainMultiplier (gamepass ×2 Entraînement), même sans rien
--   faire (AFK autorisé, aucune limite de durée).
--   Interprétation V0 du « +50 % au tap » : une seconde rapporte × (1 + TapBonus) = × 1,5
--   si un TrainTap a été accepté dans la TapBonusWindow (1 s) qui précède son crédit.
--   Il suffit donc de taper au moins une fois par seconde ; taper plus vite ne donne rien
--   de plus, et au-delà de 6 taps/s Net refuse l'appel (Definitions, TrainTap).
--
-- Attributs du Player :
--   TrainingMachine  "Treadmill" ou nil (pas sur le tapis) : AnimationController joue TreadmillRun tant
--                    qu'il est posé, TutorialService compte le temps d'entraînement
--
-- Remotes (client → serveur, sans argument ; débit déjà limité par Net) : TrainTap ; TrainLeave (a115 :
-- le joueur a bougé au tapis, il en descend ; sans effet hors séance).
--
-- API (côté serveur) :
--   TrainingService.Stop(player)
--       Fait descendre le joueur de sa machine (sans effet s'il n'y est pas), pour un service
--       qui a besoin de lui libre (alerte de vol et batte automatique, 6.2 ; tutoriel…). Même pas
--       encore monté (dans la zone, avant START_DWELL) : il doit sortir de la zone puis y revenir.
--   TrainingService.GetGainMultiplier(player, kind) -> number
--       Point d'accroche (DEV-100) : multiplie chaque gain du tapis (kind = "Treadmill", la seule machine
--       depuis le rééquilibrage v2), en plus du gain du niveau ; 1 par défaut. MonetizationService le remplace en
--       gardant celui d'avant (gamepass ×2 Entraînement). Ne doit pas yield ; une erreur ou une
--       valeur qui n'est pas un nombre fini > 0 compte pour 1.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Config.Formulas)
local Training = require(ReplicatedStorage.Shared.Config.Training)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local TrainingZone = require(ReplicatedStorage.Shared.TrainingZone)
local AntiCheatService = require(script.Parent.AntiCheatService)
local DataService = require(script.Parent.DataService)
local StatsService = require(script.Parent.StatsService)

type MachineKind = "Treadmill"

type Machine = {
	kind: MachineKind,
	model: Instance, -- modèle taggé (clé de `machines`)
	plot: Instance, -- parcelle PlayerPlot qui contient la machine
	zone: TrainingZone.Zone, -- UsePoint, zone d'entrée, bande (Shared/TrainingZone)
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
	autoRotate: boolean, -- Humanoid.AutoRotate avant la séance (remis à la fin)
	connections: { RBXScriptConnection },
}

-- Joueur dans la zone d'une machine, pas encore en séance (START_DWELL).
type Standing = { machine: Machine, since: number }
-- Machine bloquée pour un joueur (pas de remontée en boucle) ; armed : il a quitté le cœur de la
-- machine depuis, y revenir le fait remonter.
type Block = { machine: Machine, armed: boolean }

local IS_STUDIO = RunService:IsStudio()

-- Contrat (sections 2.1 et 10.4) : tags des machines et de la parcelle (UsePoint, Belt et UseZone :
-- Shared/TrainingZone).
local TREADMILL_TAG = "Treadmill"
-- Ancien tag du banc (retiré du jeu le 2026-11-14) : lu seulement pour couper l'invite de son modèle.
local RETIRED_BENCH_TAG = "Bench"
local PLOT_TAG = "PlayerPlot"
-- Attribut de la parcelle posé par PlotService : UserId du propriétaire, 0 = libre.
local OWNER_ATTRIBUTE = "OwnerUserId"
-- Clé du modificateur de StatsService qui immobilise le joueur sur le tapis.
local SPEED_MODIFIER = "Training"
-- 5.1 : « +1 par seconde » : le tapis crédite seconde par seconde.
local TREADMILL_TICK = 1

-- V0 proposé, absent du doc : délai (s) après la mise en place pendant lequel ni l'état du
-- Humanoid ni la position ne libèrent le joueur (la téléportation met un instant à arriver
-- chez le client, qui possède la physique de son perso).
local SETTLE_TIME = 0.5
-- V0 proposé, absent du doc : message au joueur qui essaie la machine d'un autre.
local NOT_OWNER_MESSAGE = "You can only train in your own shop."
-- V0 proposé, absent du doc : au plus un message de refus (s) par joueur, qui passe souvent à côté
-- des machines des autres.
local NOT_OWNER_COOLDOWN = 10

-- Entrée par zone (L-071 point 3, L-093 point 1). V0 proposés, absents du doc :
-- cadence du contrôle des zones (s) ; a115 : 0 = à chaque Heartbeat (au plus 6 joueurs × 12 machines,
-- quelques produits de matrices), au lieu de 0,1 ;
local CHECK_INTERVAL = 0
-- temps (s) dans la zone avant de monter ; a115 : 0 au lieu de 0,25 (Cantin, 2026-11-13 : la montée
-- doit être instantanée ; le client se met déjà en place à l'entrée dans la zone) ;
local START_DWELL = 0
-- tapis : marge (studs) autour de l'emprise de la bande pour rester en séance (poussé d'un pas ne
-- coupe pas la séance), hauteur du HumanoidRootPart au-dessus du dessus de la bande (un saut monte
-- d'environ 7 studs : sauter sur place ne coupe pas la séance).
local LEAVE_MARGIN = 1
local STAY_ABOVE = 12

-- États du Humanoid qui font descendre du tapis : siège, nage… Sauter sur place ne fait pas descendre :
-- seule la position compte pour le saut.
local LEAVE_STATES: { [Enum.HumanoidStateType]: boolean } = {
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
-- Joueurs dans la zone d'une machine (avant START_DWELL), et la machine dont chaque joueur doit
-- sortir de la zone avant de remonter (séance finie, refus) ; dernier message de refus.
local standing: { [Player]: Standing } = {}
local blocked: { [Player]: Block } = {}
local refusedAt: { [Player]: number } = {}
local checkClock = 0
local gainHookWarned = false

local function log(message: string)
	if IS_STUDIO then
		print(`[TrainingService] {message}`)
	end
end

local function isOwner(player: Player, machine: Machine): boolean
	return machine.plot:GetAttribute(OWNER_ATTRIBUTE) == player.UserId
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

-- Gain de Vitesse du tapis par seconde (v2 : 2^(niveau affiché − 1), bonus de GetGainMultiplier compris) et
-- niveau enregistré de son amélioration.
local function treadmillGain(player: Player): (number, number)
	local data = DataService.Get(player)
	local level = if data == nil then 0 else data.Upgrades.Treadmill
	return Formulas.TreadmillGain(level) * gainMultiplier(player, "Treadmill"), level
end

-- Géométrie (Shared/TrainingZone, commune avec le client).
local function inZone(machine: Machine, position: Vector3): boolean
	return TrainingZone.inZone(machine.zone, position)
end

local function overZone(machine: Machine, position: Vector3): boolean
	return TrainingZone.overZone(machine.zone, position)
end

-- Machine dont la zone contient `position` (celle au UsePoint le plus proche), ou nil.
local function machineAt(position: Vector3): Machine?
	local best: Machine? = nil
	local bestDistance = math.huge
	for _, machine in machines do
		if inZone(machine, position) then
			local distance = (machine.zone.usePoint.WorldPosition - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = machine, distance
			end
		end
	end
	return best
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
	end
	-- Pas de remontée en boucle : il sort de la zone, ou quitte le cœur de la machine et y revient,
	-- avant une nouvelle séance (déjà sorti, ou machine retirée : levé au contrôle suivant).
	if player.Parent == Players then
		blocked[player] = { machine = machine, armed = false }
	end
	StatsService.SetSpeedModifier(player, SPEED_MODIFIER, nil)
	if session.humanoid.Parent ~= nil then
		session.humanoid.AutoRotate = session.autoRotate
	end
	if player.Parent == Players then
		player:SetAttribute("TrainingMachine", nil)
	end
	log(
		`{player.Name} quitte le tapis ({reason}) : +{string.format("%.2f", session.gained)} Vitesse en {string.format("%.1f", os.clock() - session.startedAt)} s`
	)
end

-- Commence la séance. Renvoie false (rien ne change) si le personnage ne peut pas s'y mettre.
local function start(player: Player, machine: Machine): boolean
	local root, humanoid = bodyOf(player)
	if root == nil or humanoid == nil or humanoid.SeatPart ~= nil or player.Character == nil then
		return false
	end
	local character = player.Character :: Model
	-- Le contrôle des zones vient de vérifier qu'il est dans la zone de la machine (serveur seul).

	local now = os.clock()
	local session: Session = {
		machine = machine,
		humanoid = humanoid,
		root = root,
		target = TrainingZone.standingCFrame(machine.zone.usePoint, humanoid, root),
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
	-- Gardé en place, sans rotation (a115) : il descend dès qu'il bouge (TrainLeave du client).
	StatsService.SetSpeedModifier(player, SPEED_MODIFIER, 0)
	humanoid.AutoRotate = false
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

	local gain, level = treadmillGain(player)
	log(`{player.Name} monte sur le tapis (niveau affiché {Formulas.TreadmillShownLevel(level)}, +{gain} Vitesse par seconde)`)
	return true
end

-- Un joueur vient de rester START_DWELL s dans la zone de `machine`. Une seule tentative par entrée :
-- refusé (pas propriétaire, machine prise…) ou parti en séance, il doit sortir de la zone (ou quitter
-- le cœur de la machine et y revenir) avant la suivante. Profil pas encore chargé : on réessaie au
-- contrôle suivant.
local function tryStart(player: Player, machine: Machine, now: number)
	if not isOwner(player, machine) then
		blocked[player] = { machine = machine, armed = false }
		log(
			`{player.Name} ne peut pas s'entraîner sur {machine.plot:GetFullName()} : OwnerUserId = {machine.plot:GetAttribute(OWNER_ATTRIBUTE)}, son UserId = {player.UserId}`
		)
		local last = refusedAt[player]
		if last == nil or now - last >= NOT_OWNER_COOLDOWN then
			refusedAt[player] = now
			Net.Server.Notify:Fire(player, NOT_OWNER_MESSAGE, "Warning")
		end
		return
	end
	if not DataService.IsLoaded(player) then
		return
	end
	if (machine.occupant ~= nil and machine.occupant ~= player) or not start(player, machine) then
		blocked[player] = { machine = machine, armed = false }
	end
end

-- Machine encore bloquée pour ce joueur à `position`, ou nil (voir l'en-tête : sorti de la zone, ou
-- revenu au cœur de la machine après l'avoir quitté).
local function blockedMachine(player: Player, position: Vector3?): Machine?
	local block = blocked[player]
	if block == nil then
		return nil
	end
	local machine = block.machine
	if position == nil or machines[machine.model] ~= machine or not overZone(machine, position) then
		-- Sorti de la zone (ou plus de personnage, ou machine retirée) : la prochaine entrée compte.
		blocked[player] = nil
		return nil
	end
	local inCore = TrainingZone.inCore(machine.zone, position)
	if not inCore then
		block.armed = true
	elseif block.armed then
		-- Il avait quitté le cœur de la machine et y revient : il veut remonter.
		blocked[player] = nil
		return nil
	end
	return machine
end

-- Contrôle des zones (CHECK_INTERVAL) : qui reste START_DWELL s dans la zone d'une machine y monte.
local function checkZones(now: number)
	for _, player in Players:GetPlayers() do
		if sessions[player] then
			standing[player] = nil
			continue -- déjà en séance (leaveReason la surveille)
		end
		local root, humanoid = bodyOf(player)
		local position = if root then root.Position else nil
		local block = blockedMachine(player, position)
		local machine = if position then machineAt(position) else nil
		if root == nil or humanoid == nil or machine == nil or machine == block or humanoid.SeatPart ~= nil then
			standing[player] = nil
			continue
		end
		local stand = standing[player]
		if stand == nil or stand.machine ~= machine then
			stand = { machine = machine, since = now }
			standing[player] = stand
		end
		if now - stand.since >= START_DWELL then
			standing[player] = nil
			tryStart(player, machine, now)
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
		local gain = TREADMILL_TICK * treadmillGain(player) * bonus
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
	if not TrainingZone.overBelt(session.machine.zone, position, LEAVE_MARGIN, STAY_ABOVE) then
		return "descendu du tapis"
	end
	return nil
end

local function update(dt: number)
	local now = os.clock()
	for player, session in sessions do
		local reason = leaveReason(player, session, now)
		if reason then
			stop(player, reason)
		else
			creditTreadmill(player, session, now)
		end
	end
	checkClock += dt
	if checkClock >= CHECK_INTERVAL then
		-- Le reste est gardé (cadence juste en moyenne), sans rafale après un ralentissement.
		checkClock = math.min(checkClock - CHECK_INTERVAL, CHECK_INTERVAL)
		checkZones(now)
	end
end

local function onTap(player: Player)
	local session = sessions[player]
	if session == nil then
		return -- pas sur une machine : tap ignoré
	end
	session.lastTap = os.clock() -- bonus de +50 % sur la seconde qui suit (Training.Treadmill.TapBonus)
end

-- TrainLeave (a115) : le joueur a bougé (touche de déplacement ou joystick) au tapis, il en descend.
-- Sans risque : il ne fait que finir sa propre séance.
-- Pas encore en séance (sa montée, prédite par le client, n'est pas encore vue ici) : le tapis où il
-- est se bloque, comme après une séance, pour qu'il n'y soit pas remis.
local function onLeave(player: Player)
	local session = sessions[player]
	if session then
		stop(player, "a bougé")
		return
	end
	local root = bodyOf(player)
	local under = if root then machineAt(root.Position) else nil
	if under then
		blocked[player] = { machine = under, armed = false }
		standing[player] = nil
	end
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
	-- Zone d'entrée (L-093) : la pièce UseZone de Clément, sinon la boîte du modèle, calculée une fois
	-- Shared/TrainingZone.
	local zone = TrainingZone.describe(model, kind)
	if zone == nil then
		warn(
			`[TrainingService] {model:GetFullName()} : pas d'Attachment {TrainingZone.USE_POINT} (contrat 10.4), machine inutilisable`
		)
		return
	end

	local machine: Machine = {
		kind = kind,
		model = model,
		plot = plot,
		zone = zone,
		occupant = nil,
	}
	-- Plus d'invite sur les machines (L-071, L-093) : celle que le modèle porterait est désactivée.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Enabled then
			descendant.Enabled = false
			log(`{descendant:GetFullName()} : invite désactivée, on monte en entrant dans la zone (L-093)`)
		end
	end
	-- La bande sert à rester en séance (la zone sert à monter).
	if zone.belt == nil then
		local size = TrainingZone.FALLBACK_BELT_SIZE
		warn(
			`[TrainingService] {model:GetFullName()} : pas de pièce {TrainingZone.BELT} (contrat 10.4) : on s'entraîne sur une zone de {size.X} × {size.Z} studs autour du {TrainingZone.USE_POINT}`
		)
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

-- Banc resté dans une parcelle (du décor depuis le rééquilibrage v2) : l'invite que son modèle porte
-- (« Lift » de Clément) est coupée, pour ne pas proposer une machine qui ne fait plus rien.
local function muteRetiredBench(model: Instance)
	if not model:IsDescendantOf(workspace) then
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Enabled then
			descendant.Enabled = false
			log(`{descendant:GetFullName()} : invite désactivée (plus de banc depuis le rééquilibrage v2)`)
		end
	end
end

function TrainingService.Stop(player: Player)
	-- Même pas encore monté (dans une zone, avant START_DWELL) : il en sort avant la prochaine fois.
	local root = bodyOf(player)
	local under = if root and player.Parent == Players then machineAt(root.Position) else nil
	if under then
		blocked[player] = { machine = under, armed = false }
	end
	standing[player] = nil
	stop(player, "demandé par un service")
end

function TrainingService.GetGainMultiplier(_player: Player, _kind: MachineKind): number
	return 1
end

function TrainingService.Init()
	watchTag(TREADMILL_TAG, "Treadmill")
	-- v2 : plus de banc. Son tag ne sert plus qu'à couper l'invite du modèle resté en place.
	CollectionService:GetInstanceAddedSignal(RETIRED_BENCH_TAG):Connect(muteRetiredBench)
	for _, model in CollectionService:GetTagged(RETIRED_BENCH_TAG) do
		muteRetiredBench(model)
	end

	Net.Server.TrainTap:Connect(onTap)
	Net.Server.TrainLeave:Connect(onLeave)
	RunService.Heartbeat:Connect(update)

	-- Avant la libération du profil : la séance se termine pendant que l'écriture compte encore.
	DataService.OnProfileReleasing(function(player: Player)
		stop(player, "départ")
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		stop(player, "départ")
		standing[player] = nil
		blocked[player] = nil
		refusedAt[player] = nil
	end)
end

return TrainingService
