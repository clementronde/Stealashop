--!strict
-- TrainingController (DEV-012, client) : le tapis côté joueur (Partie 1, sections 5.1 et 9.4).
-- Rééquilibrage v2 (Cantin, 2026-11-14) : plus de banc. Le tag Bench n'est plus lu ici non plus (ni montée,
-- ni BenchLift, ni TrainTap de répétition).
--
-- Rôle :
--   - montée instantanée (a115, Cantin 2026-11-13 : 1 à 2 s de décalage avant) : à chaque image, le
--     client regarde si son HumanoidRootPart entre dans la zone d'une machine de SA parcelle (mêmes
--     calculs que le serveur : Shared/TrainingZone, même blocage « pas de remontée en boucle »). Si oui,
--     sans attendre le serveur, il se place lui-même sur le UsePoint (le client possède la physique de
--     son perso), se fige (WalkSpeed 0 et AutoRotate coupé, en local) et joue l'animation. Le serveur,
--     qui voit la même position, confirme en posant l'attribut TrainingMachine du Player (le même
--     placement, la même vitesse 0) ; sans confirmation au bout de PREDICT_TIMEOUT s (refus, profil pas
--     chargé…), le client annule : animation arrêtée, vitesse et rotation rendues, machine bloquée
--     comme au serveur. Le serveur reste seul à créditer les gains (rien n'est crédité avant sa
--     confirmation) ;
--   - au tapis, le joueur descend dès qu'il bouge (touche de déplacement ou joystick :
--     Humanoid.MoveDirection) : le client envoie TrainLeave, rend sa vitesse et arrête TreadmillRun tout
--     de suite. Une entrée de déplacement tenue depuis la montée (il arrivait en marchant) ne compte
--     pas : il faut la relâcher, puis bouger. ;
--   - TreadmillRun est rejoué s'il s'arrête pendant la séance (boucle garantie, même si une autre
--     animation l'a coupé) ;
--   - au tapis (TrainingMachine = "Treadmill"), un tap sur l'écran, un clic gauche ou la gâchette
--     droite de la manette envoie TrainTap (bonus du tapis). Les taps qui tombent sur l'UI
--     (gameProcessed) ne comptent pas ;
--   - n'envoie jamais plus de 6 TrainTap au tapis sur WINDOW secondes (Config.Training) : au-delà, le
--     serveur les ignorerait ;
--   - joue TreadmillRun par AnimationController s'il est là (rien sinon, sans erreur ;
--     AnimationController le joue aussi d'après l'attribut).
-- Aucune UI et aucun gain ici, le serveur décide : ni le tapis ni le banc n'ont d'invite, on y monte en
-- entrant dans leur zone (L-071, L-093 ; TrainingService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

-- Machine vue par le client : son modèle taggé, sa zone (Shared/TrainingZone) et sa parcelle.
type Machine = { model: Instance, zone: any, plot: Instance? }
-- Machine bloquée (pas de remontée en boucle) ; armed : le cœur de la machine a été quitté depuis.
type Block = { machine: Machine, armed: boolean }
-- Vitesse d'avant la mise en place (rendue, avec la rotation, si le client descend ou annule lui-même).
type Frozen = { humanoid: Humanoid, walkSpeed: number }

-- V0 proposé, absent du doc : fenêtre (s) de la limite côté client, un peu plus longue que la
-- seconde du serveur pour que les écarts du réseau ne fassent pas dépasser la limite à l'arrivée.
local WINDOW = 1.1
-- Montée prédite (a115). V0 proposés, absents du doc :
-- attente (s) de la confirmation du serveur (aller-retour du réseau, avec de la marge) avant d'annuler ;
local PREDICT_TIMEOUT = 1.5
-- après une descente du tapis (TrainLeave), une confirmation de séance qui arrive encore dans ce délai
-- (s) vient d'une montée croisée sur le réseau : TrainLeave est renvoyé ;
local RESEND_WINDOW = 1.5
-- en dessous de cette norme, Humanoid.MoveDirection compte pour « ne bouge pas ».
local MOVE_EPSILON = 0.05

local TREADMILL_TAG = "Treadmill"
local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId"

local TrainingController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local TrainingZone: any = nil
local animation: AnimationApi? = nil
local machine: string? = nil -- machine jouée ici : "Treadmill" ou nil
local limiters: { [string]: Limiter } = {}

local serverMachine: string? = nil -- attribut TrainingMachine (posé par le serveur)
local current: Machine? = nil -- machine où le joueur est (prédite ou confirmée)
local pendingAt: number? = nil -- montée prédite, pas encore confirmée par le serveur (heure)
local leftAt: number? = nil -- descendu du tapis ici, fin de séance du serveur pas encore reçue
local crossedLeaveAt: number? = nil -- descendu avant la confirmation d'une montée prédite (heure)
local block: Block? = nil
local frozen: Frozen? = nil
local moveReleased = false -- au tapis : l'entrée de déplacement a été relâchée depuis la montée
local known: { [Instance]: Machine | false } = {} -- machines taggées (false : sans UsePoint)

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

-- Machine jouée ici : rien après une descente locale, sinon celle du serveur, sinon celle prédite.
local function effectiveMachine(): string?
	if leftAt then
		return nil
	end
	if serverMachine then
		return serverMachine
	end
	local m = current
	if pendingAt and m then
		return m.zone.kind
	end
	return nil
end

-- Animation du tapis quand la machine jouée change.
local function refresh()
	local new = effectiveMachine()
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
	end
	if new == "Treadmill" then
		anim.PlayPlayer("TreadmillRun")
	end
end

-- Corps du joueur local : Humanoid vivant et HumanoidRootPart, sinon nil.
local function body(): (Humanoid?, BasePart?)
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end
	return humanoid, humanoid.RootPart
end

local function isMoving(humanoid: Humanoid): boolean
	return humanoid.MoveDirection.Magnitude > MOVE_EPSILON
end

-- Fige le joueur en local (le serveur fera de même) en gardant de quoi le rendre.
local function freeze(humanoid: Humanoid)
	if frozen == nil then
		frozen = { humanoid = humanoid, walkSpeed = humanoid.WalkSpeed }
	end
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
end

-- Rend la vitesse et la rotation d'avant (descente ou annulation décidée ici ; une fin de séance du
-- serveur, elle, les rend par la réplication).
local function unfreeze()
	local saved = frozen
	frozen = nil
	if saved and saved.humanoid.Parent ~= nil then
		saved.humanoid.WalkSpeed = saved.walkSpeed
		-- Rien d'autre dans le jeu ne coupe AutoRotate : il revient à true (valeur de Roblox).
		saved.humanoid.AutoRotate = true
	end
end

local function blockCurrent()
	local m = current
	if m then
		block = { machine = m, armed = false }
	end
end

-- Parcelle (tag PlayerPlot) parmi les ancêtres de la machine.
local function findPlot(model: Instance): Instance?
	local node = model.Parent
	while node ~= nil and node ~= workspace do
		if CollectionService:HasTag(node, PLOT_TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- La machine `model` (zone calculée une fois, comme au serveur), ou nil.
local function machineOf(model: Instance, kind: string): Machine?
	local entry = known[model]
	if entry == false then
		return nil
	end
	if type(entry) == "table" then
		return entry
	end
	do
		if not model:IsDescendantOf(workspace) then
			return nil
		end
		local zone = TrainingZone.describe(model, kind)
		if zone == nil then
			known[model] = false
			return nil
		end
		local made: Machine = { model = model, zone = zone, plot = findPlot(model) }
		known[model] = made
		return made
	end
end

-- Machine de SA parcelle dont la zone contient `position` (celle au UsePoint le plus proche), ou nil.
local function ownMachineAt(position: Vector3): Machine?
	local best: Machine? = nil
	local bestDistance = math.huge
	for _, tag in { TREADMILL_TAG } do
		for _, model in CollectionService:GetTagged(tag) do
			local m = machineOf(model, tag)
			local plot = if m then m.plot else nil
			if m and plot and plot:GetAttribute(OWNER_ATTRIBUTE) == localPlayer.UserId and TrainingZone.inZone(m.zone, position) then
				local distance = (m.zone.usePoint.WorldPosition - position).Magnitude
				if distance < bestDistance then
					best, bestDistance = m, distance
				end
			end
		end
	end
	return best
end

-- Machine encore bloquée à `position` (même règle que TrainingService.blockedMachine), ou nil.
local function blockedMachine(position: Vector3): Machine?
	local b = block
	if b == nil then
		return nil
	end
	local m = b.machine
	if m.model.Parent == nil or not TrainingZone.overZone(m.zone, position) then
		block = nil
		return nil
	end
	if not TrainingZone.inCore(m.zone, position) then
		b.armed = true
	elseif b.armed then
		block = nil
		return nil
	end
	return m
end

-- Montée prédite : en place, figé, animation tout de suite ; le serveur confirmera.
local function predict(m: Machine, humanoid: Humanoid, root: BasePart)
	current = m
	pendingAt = os.clock()
	freeze(humanoid)
	local character = localPlayer.Character
	if character then
		character:PivotTo(TrainingZone.standingCFrame(m.zone.usePoint, humanoid, root))
	end
	root.AssemblyLinearVelocity = Vector3.zero
	moveReleased = not isMoving(humanoid)
	refresh()
end

-- Descente du tapis décidée ici (le joueur bouge) : le serveur est prévenu, tout est rendu tout de suite.
local function leaveTreadmill(now: number)
	if serverMachine ~= nil then
		leftAt = now -- jusqu'à la fin de séance du serveur
	else
		crossedLeaveAt = now -- montée prédite pas encore vue du serveur : elle peut encore arriver
	end
	pendingAt = nil
	blockCurrent()
	current = nil
	unfreeze()
	refresh()
	-- En dernier : tout l'état local est déjà à jour quand la fin de séance du serveur revient.
	net.Client.TrainLeave:Fire()
end

local function onHeartbeat()
	local now = os.clock()
	local humanoid, root = body()
	-- Montée prédite sans réponse : refusée (ou perdue), on annule et on bloque comme le serveur.
	local since = pendingAt
	if since and serverMachine == nil and (humanoid == nil or now - since > PREDICT_TIMEOUT) then
		pendingAt = nil
		blockCurrent()
		current = nil
		unfreeze()
		refresh()
	end
	if humanoid == nil or root == nil then
		return
	end
	local kind = machine
	if kind == "Treadmill" then
		if not isMoving(humanoid) then
			moveReleased = true
		elseif moveReleased then
			leaveTreadmill(now)
			return
		end
		-- Boucle garantie : TreadmillRun rejoué s'il s'est arrêté (rien s'il joue déjà).
		local anim = animation
		if anim then
			anim.PlayPlayer("TreadmillRun")
		end
		return
	elseif kind ~= nil or leftAt ~= nil or serverMachine ~= nil then
		return
	end
	if humanoid.SeatPart ~= nil then
		return
	end
	local position = root.Position
	local blockedOne = blockedMachine(position)
	local m = ownMachineAt(position)
	if m and m ~= blockedOne then
		predict(m, humanoid, root)
	end
end

local function onMachineChanged()
	local value = localPlayer:GetAttribute("TrainingMachine")
	local new: string? = if value == "Treadmill" then value else nil
	if new == serverMachine then
		return
	end
	serverMachine = new
	local now = os.clock()
	if new ~= nil then
		pendingAt = nil
		local humanoid, root = body()
		if current == nil and root then
			current = ownMachineAt(root.Position)
		end
		local crossed = crossedLeaveAt
		crossedLeaveAt = nil
		if new == "Treadmill" and crossed and now - crossed <= RESEND_WINDOW then
			-- Montée croisée avec une descente : il a déjà bougé, on redescend.
			leftAt = now
			net.Client.TrainLeave:Fire()
		elseif humanoid and frozen == nil then
			-- Mis en place par le serveur seul (variante du tapis…) : de quoi rendre la vitesse ensuite.
			local base = localPlayer:GetAttribute("WalkSpeed")
			frozen = {
				humanoid = humanoid,
				walkSpeed = if humanoid.WalkSpeed > 0 then humanoid.WalkSpeed elseif type(base) == "number" then base else 16,
			}
			moveReleased = not isMoving(humanoid)
		end
	else
		-- Fin de séance du serveur : il rend lui-même vitesse et rotation (répliquées).
		if leftAt == nil then
			blockCurrent()
		end
		leftAt = nil
		current = nil
		frozen = nil
	end
	refresh()
end

local function isTap(input: InputObject): boolean
	local inputType = input.UserInputType
	return inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.ButtonR2
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	local kind = machine
	if gameProcessed or kind ~= "Treadmill" or not isTap(input) then
		return
	end
	sendTap(kind)
end

-- Nouveau personnage : plus rien de prédit ni de figé (le serveur finit la séance de l'ancien).
local function onCharacterAdded()
	pendingAt = nil
	current = nil
	frozen = nil
	block = nil
	refresh()
end

function TrainingController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local training = require(shared:WaitForChild("Config"):WaitForChild("Training") :: ModuleScript) :: any
	TrainingZone = require(shared:WaitForChild("TrainingZone") :: ModuleScript) :: any
	limiters.Treadmill = newLimiter(training.Treadmill.MaxTapsPerSecond)
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	animation = loadAnimationController()

	-- Machines retirées (variante du tapis remplacée…) : leur zone est oubliée.
	for _, tag in { TREADMILL_TAG } do
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(model: Instance)
			known[model] = nil
		end)
	end
	localPlayer:GetAttributeChangedSignal("TrainingMachine"):Connect(onMachineChanged)
	localPlayer.CharacterAdded:Connect(onCharacterAdded)
	onMachineChanged()
	UserInputService.InputBegan:Connect(onInputBegan)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return TrainingController
