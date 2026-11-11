--!strict
-- TrainingService (DEV-012) : tapis de course (Vitesse) et banc de musculation (Force)
-- (Partie 1, sections 5.1, 7.5 et 9.4 ; tapis sans invite : liaison L-071, point 3 ; tapis et banc
-- par zone : L-093, point 1).
--
-- Rôle :
--   - entrée par zone, sans invite ni clic, pour les deux machines (L-093, point 1). Zone d'une
--     machine : la pièce UseZone de son modèle si Clément en pose une (BasePart facultative, à garder
--     invisible et sans collision), sinon la boîte englobante du modèle (GetBoundingBox, qui contient
--     le UsePoint) élargie de ZONE_MARGIN de chaque côté ; en hauteur, de ZONE_BELOW sous son bas à
--     ZONE_ABOVE au-dessus de son haut. Le serveur seul décide : toutes les CHECK_INTERVAL s, il
--     regarde où est le HumanoidRootPart de chaque joueur. Resté START_DWELL s dans la zone (même en
--     marchant), le joueur monte sur la machine : placé sur le UsePoint (debout, tourné vers son axe
--     −Z). Zones qui se recouvrent : la machine au UsePoint le plus proche ;
--   - tapis (tag Treadmill d'une parcelle PlayerPlot de Workspace) : pas immobilisé (ni vitesse 0, ni
--     rotation coupée) : il descend en marchant. Fin de la séance : HumanoidRootPart hors de la bande
--     (pièce ou modèle Belt du tapis, contrat 10.4 ; sans elle, FALLBACK_BELT_SIZE posée sur le
--     UsePoint) élargie de LEAVE_MARGIN, jusqu'à STAY_ABOVE au-dessus (un saut sur place ne coupe
--     rien, un saut hors du tapis si), mort, état Seated, Swimming, Ragdoll…, parcelle perdue, départ,
--     machine retirée (variante posée par MachineVariantService : il est remis sur la nouvelle), ou
--     TrainingService.Stop ;
--   - banc (tag Bench) : plus d'invite (L-093) ; une ProximityPrompt trouvée dans le modèle (l'invite
--     « Lift » de Clément sur GymMat) est désactivée par le code. Le joueur est placé sur le UsePoint
--     et y est gardé : vitesse 0 par le modificateur « Training » de StatsService, sans rotation.
--     Libéré s'il saute (ou tombe, s'assoit…), s'il s'éloigne de plus de LEAVE_DISTANCE, meurt, perd
--     sa parcelle, part, ou si le banc est retiré ;
--   - pas de remontée en boucle, même logique pour les deux machines : une séance finie (descendu,
--     saut, Stop, état…) ou un refus bloque cette machine pour ce joueur tant que son HumanoidRootPart
--     reste au-dessus de l'emprise au sol de la zone, à n'importe quelle hauteur (sauter sur place ne
--     débloque rien). Il faut sortir de la zone, puis y revenir ;
--   - les deux : seul le propriétaire de la parcelle qui contient la machine s'y entraîne (attribut
--     OwnerUserId de la parcelle, posé par PlotService) ; un autre joueur est refusé et reçoit
--     NOT_OWNER_MESSAGE, au plus une fois toutes les NOT_OWNER_COOLDOWN s (on passe souvent à côté
--     des machines des autres). Porter un colis n'empêche pas de s'entraîner (règle inchangée) ;
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
--   Banc (automatique depuis L-091, point 2 : plus de clic) : le client rejoue BenchLift en boucle et
--     envoie un TrainTap à chaque marqueur Top ; chaque TrainTap est une répétition. Sans TrainTap
--     (animation ou marqueur manquant), le serveur compte lui-même une répétition toutes les
--     BENCH_AUTO_INTERVAL s ; dès qu'un TrainTap est arrivé pendant la séance, il n'en compte plus
--     qu'après BENCH_CLIENT_SILENCE s sans répétition (animation bloquée). Dans tous les cas, au plus
--     MaxRepsPerSecond (3) sur toute seconde glissante (les autres sont ignorées). Une répétition
--     rapporte GainPerRep × M banc en Force (niveau Upgrades.Bench, formule inchangée) et incrémente
--     l'attribut BenchReps du Player. Le bonus de +50 % au tap ne concerne que le tapis.
--   Barre du banc (L-091, point 2 ; vague 24 : elle suit les deux mains) : SETTLE_TIME s après la
--     mise en place (pose BenchIdle prise), le serveur prépare la pièce ou le modèle Bar du banc :
--     ancrée, collisions coupées, liaisons au reste du banc coupées, et pose l'attribut BenchUserId
--     (UserId du joueur) sur le modèle taggé Bench. Il ne la soude plus à RightHand : c'est
--     BenchBarController, chez chaque client, qui la place à chaque image au milieu de LeftHand et
--     RightHand, dans l'axe d'une main à l'autre, pour tous les joueurs visibles (l'animation est
--     calculée chez chaque client, ses mains y sont exactes ; la barre est du décor, sans effet de
--     jeu : rien à protéger côté serveur). À la fin de la séance (départ, mort, perso retiré, banc
--     retiré…), l'attribut est retiré, chaque client remet la barre à sa place exacte et le serveur
--     rend ses réglages d'avant. Sans Bar : rien (une ligne dans la sortie en Studio).
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
--       qui a besoin de lui libre (alerte de vol et batte automatique, 6.2 ; tutoriel…). Même pas
--       encore monté (dans la zone, avant START_DWELL) : il doit sortir de la zone puis y revenir.
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
local Net = require(ReplicatedStorage.Shared.Net.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Net.RateLimiter)
local AntiCheatService = require(script.Parent.AntiCheatService)
local DataService = require(script.Parent.DataService)
local StatsService = require(script.Parent.StatsService)

type MachineKind = "Treadmill" | "Bench"
type Window = RateLimiter.Window

type Machine = {
	kind: MachineKind,
	model: Instance, -- modèle taggé (clé de `machines`)
	plot: Instance, -- parcelle PlayerPlot qui contient la machine
	usePoint: Attachment,
	belt: Instance?, -- tapis : sa bande (pièce ou modèle Belt) ; nil : zone posée sur le UsePoint
	useZone: BasePart?, -- pièce UseZone de Clément (facultative), lue telle quelle
	zoneCFrame: CFrame, -- zone calculée à l'enregistrement (sans UseZone) : centre…
	zoneSize: Vector3, -- … et taille, ZONE_MARGIN comprise
	bar: Instance?, -- banc : sa barre (pièce ou modèle Bar), nil si absente
	occupant: Player?,
}

-- Une pièce de la barre tenue en main, et ses réglages d'avant.
type BarPart = { part: BasePart, cframe: CFrame, anchored: boolean, canCollide: boolean }
-- Barre prise en main (placée par les clients) : banc qui porte l'attribut, pièces, liaisons au
-- banc coupées.
type BarHold = { model: Instance, parts: { BarPart }, disabled: { Instance } }

type Session = {
	machine: Machine,
	humanoid: Humanoid,
	root: BasePart,
	target: CFrame, -- place du HumanoidRootPart sur la machine
	startedAt: number,
	nextTick: number, -- prochain crédit du tapis
	lastTap: number, -- dernier TrainTap accepté
	lastRep: number, -- banc : dernière répétition comptée (ou début de la séance)
	clientReps: boolean, -- banc : un TrainTap (marqueur Top) est arrivé pendant la séance
	barTried: boolean, -- banc : la barre a déjà été prise en main (ou manque)
	bar: BarHold?, -- banc : barre tenue en main
	gained: number, -- gagné pendant cette séance (pour la sortie de Studio)
	autoRotate: boolean, -- Humanoid.AutoRotate avant la séance (remis à la fin, au banc)
	connections: { RBXScriptConnection },
}

-- Joueur dans la zone d'une machine, pas encore en séance (START_DWELL).
type Standing = { machine: Machine, since: number }

local IS_STUDIO = RunService:IsStudio()

-- Contrat (sections 2.1 et 10.4) : tags des machines et de la parcelle, point d'usage, bande.
local TREADMILL_TAG = "Treadmill"
local BENCH_TAG = "Bench"
local PLOT_TAG = "PlayerPlot"
local USE_POINT = "UsePoint"
local BELT = "Belt"
-- Zone d'entrée posée par Clément, facultative (L-093 : nom proposé ici, à valider dans la liaison).
local USE_ZONE = "UseZone"
-- Attribut de la parcelle posé par PlotService : UserId du propriétaire, 0 = libre.
local OWNER_ATTRIBUTE = "OwnerUserId"
-- Clé du modificateur de StatsService qui immobilise le joueur au banc.
local SPEED_MODIFIER = "Training"
-- 5.1 : « +1 par seconde » : le tapis crédite seconde par seconde.
local TREADMILL_TICK = 1

-- V0 proposé, absent du doc : distance (studs) entre le HumanoidRootPart et sa place sur le banc
-- au-delà de laquelle le joueur est libéré (poussé, téléporté, ou saut que l'état du Humanoid n'a
-- pas signalé : un saut monte d'environ 7 studs).
local LEAVE_DISTANCE = 3
-- V0 proposé, absent du doc : délai (s) après la mise en place pendant lequel ni l'état du
-- Humanoid ni la position ne libèrent le joueur (la téléportation met un instant à arriver
-- chez le client, qui possède la physique de son perso).
local SETTLE_TIME = 0.5
-- Banc automatique (L-091, point 2). V0 proposés, absents du doc :
-- rythme (s) des répétitions comptées par le serveur quand le client n'en envoie pas (BenchLift
-- ou son marqueur Top manquant) ;
local BENCH_AUTO_INTERVAL = 1.5
-- après un premier TrainTap de la séance : silence (s) au-delà duquel le serveur reprend le rythme
-- (BenchLift plus longue que ce délai : le serveur ajouterait des répétitions, à monter).
local BENCH_CLIENT_SILENCE = 4
-- Barre du banc (contrat 10.4) et attribut du banc lu par BenchBarController (UserId de celui qui
-- la tient, absent sinon).
local BAR = "Bar"
local BENCH_USER_ATTRIBUTE = "BenchUserId"
-- V0 proposé, absent du doc : message au joueur qui essaie la machine d'un autre.
local NOT_OWNER_MESSAGE = "You can only train in your own shop."
-- V0 proposé, absent du doc : au plus un message de refus (s) par joueur, qui passe souvent à côté
-- des machines des autres.
local NOT_OWNER_COOLDOWN = 10

-- Entrée par zone (L-071 point 3, L-093 point 1). V0 proposés, absents du doc :
-- cadence du contrôle des zones (s), comme les plaques CollectPad de DisplayService ;
local CHECK_INTERVAL = 0.1
-- temps (s) dans la zone avant de monter (même en marchant) : effleurer un coin ne fait pas monter ;
local START_DWELL = 0.25
-- zone calculée : marge (studs) autour de la boîte du modèle, sur les côtés ; hauteur sous son bas
-- et au-dessus de son haut (le HumanoidRootPart d'un R15 debout est à environ 3 studs du sol) ;
local ZONE_MARGIN = 1
local ZONE_BELOW = 1
local ZONE_ABOVE = 4
-- zone d'un modèle sans boîte (ni Model ni BasePart) : posée sur le UsePoint ;
local FALLBACK_ZONE_SIZE = Vector3.new(6, 4, 6)
-- tapis : marge (studs) autour de l'emprise de la bande pour rester en séance (un pas de côté ne
-- coupe pas la séance), hauteur du HumanoidRootPart au-dessus du dessus de la bande (un saut monte
-- d'environ 7 studs : sauter sur place ne coupe pas la séance), et tolérance sous le dessus ;
local LEAVE_MARGIN = 1
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
-- Joueurs dans la zone d'une machine (avant START_DWELL), et la machine dont chaque joueur doit
-- sortir de la zone avant de remonter (séance finie, refus) ; dernier message de refus.
local standing: { [Player]: Standing } = {}
local blocked: { [Player]: Machine } = {}
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

-- Boîte de la zone d'entrée (CFrame du centre, taille) : la pièce UseZone, sinon la zone calculée.
local function zoneBox(machine: Machine): (CFrame, Vector3)
	local given = machine.useZone
	if given and given.Parent ~= nil then
		return given.CFrame, given.Size
	end
	return machine.zoneCFrame, machine.zoneSize
end

-- `position` (celle d'un HumanoidRootPart) est-elle dans la zone d'entrée de la machine ?
local function inZone(machine: Machine, position: Vector3): boolean
	local cframe, size = zoneBox(machine)
	local p = cframe:PointToObjectSpace(position)
	local half = size / 2
	return math.abs(p.X) <= half.X
		and math.abs(p.Z) <= half.Z
		and p.Y >= -half.Y - ZONE_BELOW
		and p.Y <= half.Y + ZONE_ABOVE
end

-- `position` est-elle au-dessus de l'emprise au sol de la zone, à n'importe quelle hauteur ? (Pour
-- débloquer : un saut sur place ne fait pas sortir de la zone.)
local function overZone(machine: Machine, position: Vector3): boolean
	local cframe, size = zoneBox(machine)
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Z) <= size.Z / 2
end

-- Machine dont la zone contient `position` (celle au UsePoint le plus proche), ou nil.
local function machineAt(position: Vector3): Machine?
	local best: Machine? = nil
	local bestDistance = math.huge
	for _, machine in machines do
		if inZone(machine, position) then
			local distance = (machine.usePoint.WorldPosition - position).Magnitude
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

-- Barre du banc -------------------------------------------------------------------

-- Pièces reliées par une liaison (soudure, joint ou contrainte à deux attachements).
local function jointParts(joint: Instance): (Instance?, Instance?)
	if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") or joint:IsA("NoCollisionConstraint") then
		local j = joint :: any
		return j.Part0, j.Part1
	elseif joint:IsA("Constraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1
		return if a0 then a0.Parent else nil, if a1 then a1.Parent else nil
	end
	return nil, nil
end

local function setJointEnabled(joint: Instance, enabled: boolean)
	if joint:IsA("JointInstance") then
		joint.Enabled = enabled
	elseif joint:IsA("WeldConstraint") then
		joint.Enabled = enabled
	elseif joint:IsA("Constraint") then
		joint.Enabled = enabled
	end
end

-- Prépare la barre du banc pour les clients (voir l'en-tête) : ancrée, sans collision, détachée du
-- reste du banc, attribut BenchUserId posé. Renvoie nil (rien ne change) sans barre.
local function holdBar(machine: Machine, player: Player): BarHold?
	local bar = machine.bar
	if bar == nil or bar.Parent == nil then
		return nil
	end
	local list: { BasePart } = {}
	if bar:IsA("BasePart") then
		table.insert(list, bar)
	end
	for _, descendant in bar:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(list, descendant)
		end
	end
	if #list == 0 then
		return nil
	end
	local inBar: { [Instance]: boolean } = {}
	for _, part in list do
		inBar[part] = true
	end
	local hold: BarHold = { model = machine.model, parts = {}, disabled = {} }
	-- Liaisons vers le reste du banc : coupées pendant l'usage (la barre bouge seule chez les clients).
	local seen: { [Instance]: boolean } = {}
	for _, part in list do
		for _, joint in part:GetJoints() do
			if seen[joint] then
				continue
			end
			seen[joint] = true
			local p0, p1 = jointParts(joint)
			local inside = (p0 == nil or inBar[p0] == true) and (p1 == nil or inBar[p1] == true)
			if not inside and (joint :: any).Enabled == true then
				setJointEnabled(joint, false)
				table.insert(hold.disabled, joint)
			end
		end
	end
	for _, part in list do
		table.insert(hold.parts, {
			part = part,
			cframe = part.CFrame,
			anchored = part.Anchored,
			canCollide = part.CanCollide,
		})
		-- Ancrée : aucune physique ne la déplace, les clients la placent eux-mêmes.
		part.Anchored = true
		part.CanCollide = false
	end
	machine.model:SetAttribute(BENCH_USER_ATTRIBUTE, player.UserId)
	return hold
end

-- Rend la barre au banc : attribut retiré (chaque client la remet en place), place exacte et
-- réglages d'avant, liaisons au banc rétablies.
local function releaseBar(hold: BarHold)
	hold.model:SetAttribute(BENCH_USER_ATTRIBUTE, nil)
	for _, saved in hold.parts do
		local part = saved.part
		if part.Parent == nil then
			continue -- barre retirée entre-temps
		end
		part.CFrame = saved.cframe
		part.Anchored = saved.anchored
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		part.CanCollide = saved.canCollide
	end
	for _, joint in hold.disabled do
		if joint.Parent ~= nil then
			setJointEnabled(joint, true)
		end
	end
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
	local bar = session.bar
	if bar then
		session.bar = nil
		releaseBar(bar)
	end
	if machine.occupant == player then
		machine.occupant = nil
	end
	-- Pas de remontée en boucle : il sort de la zone avant une nouvelle séance (déjà sorti, ou
	-- machine retirée : levé au contrôle suivant).
	if player.Parent == Players then
		blocked[player] = machine
	end
	if machine.kind == "Bench" then
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
	-- Le contrôle des zones vient de vérifier qu'il est dans la zone de la machine (serveur seul).

	local now = os.clock()
	local session: Session = {
		machine = machine,
		humanoid = humanoid,
		root = root,
		target = standingCFrame(machine.usePoint, humanoid, root),
		startedAt = now,
		nextTick = now + TREADMILL_TICK,
		lastTap = -math.huge,
		lastRep = now,
		clientReps = false,
		barTried = false,
		bar = nil,
		gained = 0,
		autoRotate = humanoid.AutoRotate,
		connections = {},
	}
	sessions[player] = session
	machine.occupant = player
	standing[player] = nil

	AntiCheatService.Allow(player, 0, "TrainingService (placement sur la machine)") -- déplacement du code (DEV-060)
	character:PivotTo(session.target)
	if machine.kind == "Bench" then
		-- Banc : gardé en place, sans rotation ; il descend en sautant. Au tapis, rien de tout cela :
		-- il reste tourné comme on l'a posé tant qu'il ne bouge pas, et se tourne en descendant.
		StatsService.SetSpeedModifier(player, SPEED_MODIFIER, 0)
		humanoid.AutoRotate = false
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

-- Un joueur vient de rester START_DWELL s dans la zone de `machine`. Une seule tentative par entrée :
-- refusé (pas propriétaire, machine prise…) ou parti en séance, il doit sortir de la zone avant la
-- suivante. Profil pas encore chargé : on réessaie au contrôle suivant.
local function tryStart(player: Player, machine: Machine, now: number)
	if not isOwner(player, machine) then
		blocked[player] = machine
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
		blocked[player] = machine
	end
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
		local block: Machine? = blocked[player] -- typé : l'ancien solveur refuse block = nil sinon
		if block and (position == nil or machines[block.model] ~= block or not overZone(block, position)) then
			-- Sorti de la zone (ou plus de personnage, ou machine retirée) : la prochaine entrée compte.
			blocked[player] = nil
			block = nil
		end
		local machine = if position then machineAt(position) else nil
		if root == nil or humanoid == nil or machine == nil or machine == block or humanoid.SeatPart ~= nil then
			standing[player] = nil
			continue
		end
		local stand = standing[player]
		if stand == nil or stand.machine ~= machine then
			standing[player] = { machine = machine, since = now }
		elseif now - stand.since >= START_DWELL then
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

-- Banc : une répétition, au plus MaxRepsPerSecond sur toute seconde glissante. true si comptée.
local function benchRep(player: Player, session: Session, now: number): boolean
	local window = benchWindows[player] or RateLimiter.new(Training.Bench.MaxRepsPerSecond)
	benchWindows[player] = window
	if not RateLimiter.allow(window, now) then
		return false
	end
	session.lastRep = now
	local gain = Training.Bench.GainPerRep * machineMultiplier(player, "Bench")
	if StatsService.AddStrength(player, gain) == nil then
		return false
	end
	session.gained += gain
	local reps = player:GetAttribute("BenchReps")
	player:SetAttribute("BenchReps", (if type(reps) == "number" then reps else 0) + 1)
	return true
end

-- Banc : barre prise en main une fois la pose prise, et répétitions au rythme du serveur si le
-- client n'en envoie pas (voir l'en-tête).
local function updateBench(player: Player, session: Session, now: number)
	if not session.barTried and now - session.startedAt >= SETTLE_TIME then
		session.barTried = true
		session.bar = holdBar(session.machine, player)
	end
	local interval = if session.clientReps then BENCH_CLIENT_SILENCE else BENCH_AUTO_INTERVAL
	if now - session.lastRep >= interval then
		session.lastRep = now -- même refusée (limite, profil), on attend l'intervalle suivant
		benchRep(player, session, now)
	end
end

local function update(dt: number)
	local now = os.clock()
	for player, session in sessions do
		local reason = leaveReason(player, session, now)
		if reason then
			stop(player, reason)
		elseif session.machine.kind == "Treadmill" then
			creditTreadmill(player, session, now)
		else
			updateBench(player, session, now)
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
	local now = os.clock()
	if session.machine.kind == "Treadmill" then
		session.lastTap = now
		return
	end

	-- Banc : 1 TrainTap (marqueur Top de BenchLift) = 1 répétition ; le rythme du serveur se met
	-- en retrait (BENCH_CLIENT_SILENCE).
	session.clientReps = true
	benchRep(player, session, now)
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

	-- Zone d'entrée (L-093) : la pièce UseZone de Clément, sinon la boîte du modèle, calculée une fois
	-- (la barre du banc bouge pendant l'usage : la boîte ne doit pas la suivre).
	local found = model:FindFirstChild(USE_ZONE, true)
	local useZone: BasePart? = if found and found:IsA("BasePart") then found :: BasePart else nil
	local zoneCFrame: CFrame, zoneSize: Vector3
	if model:IsA("Model") then
		zoneCFrame, zoneSize = model:GetBoundingBox()
		zoneSize += Vector3.new(2 * ZONE_MARGIN, 0, 2 * ZONE_MARGIN)
	elseif model:IsA("BasePart") then
		zoneCFrame, zoneSize = model.CFrame, model.Size + Vector3.new(2 * ZONE_MARGIN, 0, 2 * ZONE_MARGIN)
	else
		zoneCFrame, zoneSize = usePoint.WorldCFrame, FALLBACK_ZONE_SIZE
	end

	local machine: Machine = {
		kind = kind,
		model = model,
		plot = plot,
		usePoint = usePoint,
		belt = nil,
		useZone = useZone,
		zoneCFrame = zoneCFrame,
		zoneSize = zoneSize,
		bar = nil,
		occupant = nil,
	}
	-- Plus d'invite sur les machines (L-071, L-093) : celle que le modèle porterait est désactivée.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Enabled then
			descendant.Enabled = false
			log(`{descendant:GetFullName()} : invite désactivée, on monte en entrant dans la zone (L-093)`)
		end
	end
	if kind == "Treadmill" then
		-- La bande sert à rester en séance (la zone sert à monter).
		local belt = model:FindFirstChild(BELT, true)
		if belt and (belt:IsA("BasePart") or belt:IsA("Model")) then
			machine.belt = belt
		else
			warn(
				`[TrainingService] {model:GetFullName()} : pas de pièce {BELT} (contrat 10.4) : on s'entraîne sur une zone de {FALLBACK_BELT_SIZE.X} × {FALLBACK_BELT_SIZE.Z} studs autour du {USE_POINT}`
			)
		end
	else
		-- Barre qui suit les mains (L-091, point 2) : pièce ou modèle Bar.
		local bar = model:FindFirstChild(BAR, true)
		if bar and (bar:IsA("BasePart") or bar:IsA("Model")) then
			machine.bar = bar
		else
			log(`{model:GetFullName()} : pas de pièce ni de modèle {BAR}, la barre ne suivra pas les mains`)
		end
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

function TrainingService.Stop(player: Player)
	-- Même pas encore monté (dans une zone, avant START_DWELL) : il en sort avant la prochaine fois.
	local root = bodyOf(player)
	local under = if root and player.Parent == Players then machineAt(root.Position) else nil
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
		refusedAt[player] = nil
	end)
end

return TrainingService
