--!strict
-- WitnessService (liaison L-111, idée de Clément du 2026-11-12) : les témoins et la police.
--
-- Les témoins sont les modèles de Clément posés dans la map, `NPC_Witness_Z<n>_0<k>` (Map/Zone_<n>/Witnesses,
-- deux par zone) : un Model avec un Humanoid R15, un HumanoidRootPart non ancré, un dossier Animations
-- (Contract/Animations.Witness : Idle, Walk, Look, CallPolice) et l'attribut WatchedStore = le nom du
-- magasin PNJ qu'il regarde. Aucun script dedans : tout se joue ici, serveur autoritaire. Le code les
-- retrouve par leur préfixe de nom, où qu'ils soient dans la map (hors _INBOX_CLEMENT).
--
-- Règle (Clément, L-111 ; valeurs : Config/Witness) :
--   1. Balade. Le reste du temps, le témoin marche (Walk, Witness.WalkSpeed) sur le circuit de sa zone :
--      les Attachments `WitnessPath_NN` du `WitnessPaths` le plus proche au-dessus de lui (Map/Zone_<n>/
--      WitnessPaths), dans l'ordre des numéros, en boucle ; le témoin de numéro pair tourne dans l'autre
--      sens. Il part du point le plus proche, s'arrête parfois à un point (Idle). Bloqué Witness.StuckTime s :
--      il vise le point suivant. Sans circuit : il reste sur place (Idle).
--   2. Premier coup validé sur une vitrine de SON magasin (WindowService.OnHit) : il s'arrête où qu'il
--      soit, se tourne vers la vitrine, joue Look, et son « ? » monte de 0 à 1 en Witness.FillTime s (8).
--      Le serveur ne fait qu'écrire la pente (Shared/WitnessGauge : attributs WitnessState, WitnessFill,
--      WitnessRate, WitnessAt sur le témoin) ; WitnessController affiche BB_Witness chez chaque joueur.
--   3. Vitrine cassée avant (WindowService.OnBroken ; Clément, L-118 point 10) : le « ? » disparaît, le
--      témoin a peur et court à l'opposé de la vitrine (Flee, sinon Walk accélérée ; Witness.FleeSpeed,
--      FleeDistance studs, FleeMaxTime s au plus, ou bloqué FleeStuckTime s), puis reprend sa balade depuis
--      le point du circuit le plus proche. Au téléphone (Call), il finit son appel.
--   4. « ? » plein : le témoin passe au « ! » (état Call) et joue CallPolice. Au PREMIER marqueur Call
--      (il revient à chaque boucle ; sans marqueur : Witness.CallMarkerMaxWait s), le son Witness.CallSound
--      part sur le témoin et la police est lancée. Witness.CallDuration s après le début de l'appel, il
--      reprend sa balade, « ? » vide. Les coups reçus pendant l'appel ne comptent pas.
--   5. Police : une copie de Assets/Guards/NPC_Police (Witness.Police) arrive en courant du bout de la
--      rue (le point du circuit le plus loin de la vitrine ; sans circuit, à côté du témoin) et poursuit
--      le dernier joueur à avoir frappé (le suivant si celui-ci est parti, mort, à l'abri en zone safe ou
--      déjà poursuivi par un policier ou un conducteur). C'est GuardService qui la pilote
--      (StartDriverChase : même chemin, même capture à Balance.Guard.CatchDistance, même coup au
--      marqueur Impact de Catch, même étourdissement, colis perdu s'il en porte un, ChaseState donc
--      UI_Chase et MUS_Chase). Vitesse : celle du vigile de jour de la zone (ou du tutoriel) ×
--      Police.SpeedFactor. Fin : capture, zone safe, ou Police.ChaseDuration s de poursuite, puis Tired et
--      fondu. Un seul policier à la fois par magasin. Attrapé (L-118 point 3) : renvoyé à la base
--      (NightCycleService.SendHome, Night.SendHomeDelay s après le coup), comme la nuit.
--   6. Nuit (Clément, L-117 point 2) : les témoins ne sont pas là. À la tombée de la nuit, ils sont
--      retirés du jeu (Parent = nil) ; à l'aube, remis où ils étaient, et la balade reprend.
--   La vitre se répare comme avant (chrono de police de WindowService, Balance.Window.BreakTimer, inchangé).
--
-- Un témoin sans WatchedStore, ou dont le magasin est introuvable parmi les modèles taggés NPCStore de la
-- map, se balade seulement (un avertissement). Rien n'est enregistré dans la place : tags, attributs,
-- Animator manquant, pièces désancrées et états du Humanoid coupés ne valent que pour la partie en cours.
--
-- API (serveur), pour L-112 (ouverture du colis dans le magasin : « plus on reste, plus le ? se remplit ») :
--   WitnessService.Raise(store, suspect?, fillTime?) -> boolean
--       Fait monter le « ? » des témoins du magasin `store` (le Model taggé NPCStore), de sa valeur
--       actuelle vers 1, à la pente d'un remplissage complet en `fillTime` s (défaut Witness.FillTime).
--       `suspect` : le joueur que la police poursuivra (le dernier donné gagne). Sans effet pendant un
--       appel. false si aucun témoin ne regarde ce magasin.
--   WitnessService.Pause(store) -> boolean
--       Fige le « ? » là où il est (le joueur relâche). Sans nouvelle montée au bout de
--       Witness.PauseTimeout s, il se vide.
--   WitnessService.Calm(store) -> boolean
--       Le « ? » se vide (Witness.EmptyTime), puis la balade reprend (le joueur est parti).
--   WitnessService.GetFill(store) -> number        le « ? » le plus rempli des témoins du magasin, 0 à 1 (1 pendant l'appel)
--   WitnessService.IsCalling(store) -> boolean     un témoin du magasin est au téléphone
--   WitnessService.OnCall(listener) -> déconnexion
--       listener(store, suspect, police) quand la police est appelée pour `store` : `suspect` = le joueur
--       poursuivi et `police` = sa copie en jeu, ou nil si personne n'est à poursuivre.
--   Exemple (L-112) : au début de l'ouverture `WitnessService.Raise(store, player)`, au relâché
--   `WitnessService.Pause(store)`, colis ouvert ou joueur sorti `WitnessService.Calm(store)`.
--   WitnessService.GetState(store) -> { State }    pour un test : état de chaque témoin du magasin

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Witness = require(Shared.Config.Witness)
local Zones = require(Shared.Config.Zones)
local Animations = require(Shared.Contract.Animations)
local Find = require(Shared.Contract.Find)
local AnimPlayer = require(Shared.Anim.AnimPlayer)
local MarkerSounds = require(Shared.Anim.MarkerSounds)
local Net = require(Shared.Net.Net)
local WitnessGauge = require(Shared.WitnessGauge)

local GuardService = require(script.Parent.GuardService)
local WindowService = require(script.Parent.WindowService)

type AnimPlayerT = AnimPlayer.AnimPlayer
type GaugeState = WitnessGauge.State

export type State = {
	Witness: Model,
	State: GaugeState,
	Fill: number,
	Rate: number,
	Suspects: number,
}

export type CallListener = (store: Model, suspect: Player?, police: Model?) -> ()

type WitnessNpc = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	anims: AnimPlayerT,
	label: string,
	store: Model?, -- le magasin regardé ; nil : il se balade seulement
	zone: number,
	gait: number, -- vitesse de lecture de Walk
	-- Balade
	path: { Vector3 }, -- points du circuit, dans l'ordre
	pathIndex: number, -- point visé
	pathStep: number, -- +1 ou −1 : sens du tour
	pauseUntil: number,
	nextMoveAt: number,
	progressPos: Vector3,
	progressAt: number,
	walking: boolean,
	-- Jauge (heures d'os.clock ; les attributs portent l'heure du serveur)
	state: GaugeState,
	fill: number,
	rate: number,
	at: number,
	pausedAt: number, -- début de la pause (Pause) ; 0 = pas en pause
	suspects: { [Player]: number }, -- joueurs vus, et quand pour la dernière fois
	-- Appel
	callStartedAt: number,
	dispatched: boolean, -- la police de cet appel est partie
	-- Fuite à la casse (L-118 point 10) : il court vers fleeGoal jusqu'à fleeUntil (os.clock), 0 = pas en fuite
	fleeUntil: number,
	fleeGoal: Vector3,
	fleeAnim: string?, -- "Flee", ou "Walk" accélérée tant que Flee n'est pas livrée
	-- Nuit (L-117 point 2) : retiré du jeu, remis ici à l'aube
	hiddenParent: Instance?,
}

-- Noms du contrat lus ici.
local WITNESS_PREFIX = "NPC_Witness" -- le même que dans ContractChecker
local WATCHED_ATTRIBUTE = "WatchedStore"
local PATHS_NAME = "WitnessPaths"
local PATH_POINT_PATTERN = "^WitnessPath_(%d+)$"
local STORE_TAG = "NPCStore"
local WINDOW = "Window"
local ZONE_ATTRIBUTE = "Zone"
local INBOX_NAME = "_INBOX_CLEMENT"
local ANIM_LABEL = "Témoin"
local POLICE_LABEL = "policier"

-- Le marqueur de CallPolice dans le contrat (Call).
local CALL_MARKER = "Call"
for _, spec in Animations.Witness do
	local marker = spec.Marker
	if spec.Name == "CallPolice" and marker then
		CALL_MARKER = marker
	end
end

-- États du Humanoid inutiles à un témoin (comme les vigiles, 9.7) : il ne tombe pas quand on le bouscule.
local DISABLED_STATES = {
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.GettingUp,
	Enum.HumanoidStateType.PlatformStanding,
}

local IS_STUDIO = RunService:IsStudio()

local WitnessService = {}

local witnesses: { WitnessNpc } = {}
local byStore: { [Model]: { WitnessNpc } } = {}
local policeByStore: { [Model]: Model } = {} -- le policier en jeu de chaque magasin
local callListeners: { CallListener } = {}
local warned: { [string]: boolean } = {}
local rng = Random.new()
local nextStepAt = 0
local sendHome: ((player: Player) -> boolean)? = nil -- NightCycleService.SendHome (Start), pour la police

local function log(message: string)
	if IS_STUDIO then
		print(`[WitnessService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[WitnessService] {message}`)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function isPositiveNumber(value: any): boolean
	return type(value) == "number" and value == value and value > 0 and value < math.huge
end

local function inMap(inst: Instance): boolean
	if not inst:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not inst:IsDescendantOf(inbox)
end

-- Jauge ------------------------------------------------------------------------------------------

local function valueNow(w: WitnessNpc, now: number): number
	return WitnessGauge.valueAt(w.fill, w.rate, w.at, now)
end

-- Écrit l'état et la pente du témoin, pour le serveur et pour les clients (attributs).
local function setGauge(w: WitnessNpc, state: GaugeState, fill: number, rate: number, now: number)
	w.state = state
	w.fill = fill
	w.rate = rate
	w.at = now
	local model = w.model
	model:SetAttribute(WitnessGauge.FillAttribute, fill)
	model:SetAttribute(WitnessGauge.RateAttribute, rate)
	model:SetAttribute(WitnessGauge.AtAttribute, Workspace:GetServerTimeNow())
	model:SetAttribute(WitnessGauge.StateAttribute, state) -- en dernier : le client lit les trois autres à ce signal
end

-- Balade -----------------------------------------------------------------------------------------

local function stopWalking(w: WitnessNpc)
	w.humanoid:MoveTo(w.root.Position)
	if w.walking then
		w.walking = false
		w.anims:Stop("Walk")
	end
end

local function nextIndex(w: WitnessNpc): number
	local count = #w.path
	return (w.pathIndex - 1 + w.pathStep) % count + 1
end

local function strollStep(w: WitnessNpc, now: number)
	local count = #w.path
	if count == 0 or now < w.pauseUntil then
		return
	end
	local position = w.root.Position
	local goal = w.path[w.pathIndex]
	if flat(goal - position).Magnitude <= Witness.PointReached then
		if count == 1 then
			stopWalking(w)
			return
		end
		w.pathIndex = nextIndex(w)
		w.nextMoveAt = now
		if rng:NextNumber() < Witness.PauseChance then
			w.pauseUntil = now + rng:NextNumber(Witness.PauseMin, Witness.PauseMax)
			w.progressAt = w.pauseUntil
			stopWalking(w)
			return
		end
		goal = w.path[w.pathIndex]
	end
	-- Bloqué (un joueur devant lui, un obstacle) : il vise le point suivant.
	if flat(position - w.progressPos).Magnitude >= 1 then
		w.progressPos = position
		w.progressAt = now
	elseif now - w.progressAt >= Witness.StuckTime and count > 1 then
		w.pathIndex = nextIndex(w)
		w.progressAt = now
		w.nextMoveAt = now
		goal = w.path[w.pathIndex]
	end
	if now >= w.nextMoveAt then
		w.nextMoveAt = now + Witness.MoveRefresh
		w.humanoid.WalkSpeed = Witness.WalkSpeed
		w.humanoid:MoveTo(goal)
		if not w.walking then
			w.walking = true
			w.anims:Play("Walk", nil, nil, w.gait)
		end
	end
end

local function toStroll(w: WitnessNpc, now: number)
	setGauge(w, "Stroll", 0, 0, now)
	w.pausedAt = 0
	w.dispatched = false
	table.clear(w.suspects)
	w.anims:Stop("Look")
	w.anims:Stop("CallPolice")
	w.pauseUntil = 0
	w.nextMoveAt = now
	w.progressPos = w.root.Position
	w.progressAt = now
end

-- Regard -----------------------------------------------------------------------------------------

-- Le centre de la vitrine du magasin (son pivot), sinon le pivot du magasin.
local function windowPosition(store: Model): Vector3
	local window = Find.path(store, WINDOW)
	if window and window:IsA("PVInstance") then
		return (window :: PVInstance):GetPivot().Position
	end
	return store:GetPivot().Position
end

-- Il s'arrête, se tourne vers la vitrine et regarde.
local function startWatch(w: WitnessNpc)
	stopWalking(w)
	local store = w.store
	if store then
		local position = w.root.Position
		local look = flat(windowPosition(store) - position)
		if look.Magnitude > 1e-3 then
			w.root.CFrame = CFrame.lookAt(position, position + look.Unit)
		end
	end
	w.anims:Play("Look")
end

local function raise(w: WitnessNpc, suspect: Player?, fillTime: number, now: number): boolean
	if w.hiddenParent or now < w.fleeUntil then
		return false -- caché la nuit, ou en fuite
	end
	if suspect and not w.dispatched then
		w.suspects[suspect] = now -- vu aussi pendant l'appel, tant que la police n'est pas partie
	end
	if w.state == "Call" then
		return false
	end
	local rate = 1 / fillTime
	if w.state == "Watch" and w.rate == rate then
		return true -- il monte déjà à cette pente : rien à réécrire (10 coups par seconde)
	end
	local value = valueNow(w, now)
	if w.state == "Stroll" then
		startWatch(w)
		log(`{w.label} regarde {if w.store then w.store.Name else "?"}`)
	end
	w.pausedAt = 0
	setGauge(w, "Watch", value, rate, now)
	return true
end

local function calm(w: WitnessNpc, now: number): boolean
	if w.state ~= "Watch" then
		return false
	end
	local value = valueNow(w, now)
	w.pausedAt = 0
	if value <= 0 then
		toStroll(w, now)
	elseif w.rate >= 0 then
		setGauge(w, "Watch", value, -1 / Witness.EmptyTime, now)
	end
	return true
end

local function pause(w: WitnessNpc, now: number): boolean
	if w.state ~= "Watch" or w.rate <= 0 then
		return false
	end
	setGauge(w, "Watch", valueNow(w, now), 0, now)
	w.pausedAt = now
	return true
end

-- Police -----------------------------------------------------------------------------------------

-- Joueur encore poursuivable : en jeu, vivant, hors zone safe. Renvoie son HumanoidRootPart.
local function suspectRoot(player: Player): BasePart?
	if player.Parent ~= Players then
		return nil
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	if GuardService.IsInSafeZone((root :: BasePart).Position) then
		return nil
	end
	return root :: BasePart
end

-- Les suspects du témoin, du plus récent au plus ancien.
local function suspectsOf(w: WitnessNpc): { Player }
	local list: { Player } = {}
	for player in w.suspects do
		table.insert(list, player)
	end
	table.sort(list, function(a: Player, b: Player): boolean
		local ta, tb = w.suspects[a], w.suspects[b]
		if ta == tb then
			return a.UserId < b.UserId
		end
		return ta > tb
	end)
	return list
end

-- Vitesse du policier pour ce joueur : celle du vigile de jour de la zone (GetSpeedOverride : tutoriel).
local function policeSpeed(player: Player, zone: number): number
	local base = Zones[zone].GuardSpeed
	local ok, value = pcall(GuardService.GetSpeedOverride, player, zone)
	if ok and isPositiveNumber(value) then
		base = value :: number
	end
	return base * Witness.Police.SpeedFactor
end

-- D'où il arrive, pieds au sol : le point du circuit le plus loin de la vitrine ; sans circuit, à côté
-- du témoin.
local function policeSpawn(w: WitnessNpc, store: Model): CFrame
	local from = windowPosition(store)
	local best: Vector3? = nil
	local bestDistance = -1
	for _, point in w.path do
		local distance = flat(point - from).Magnitude
		if distance > bestDistance and not GuardService.IsInSafeZone(point) then
			best = point
			bestDistance = distance
		end
	end
	if best then
		return CFrame.new(best)
	end
	local root = w.root
	local feet = root.Position - Vector3.new(0, w.humanoid.HipHeight + root.Size.Y / 2, 0)
	return CFrame.new(feet + root.CFrame.RightVector * 3)
end

-- Lance le policier du magasin sur le suspect le plus récent encore poursuivable. Renvoie le joueur
-- poursuivi et la copie du policier, ou nil.
local function launchPolice(w: WitnessNpc, store: Model, now: number): (Player?, Model?)
	local current = policeByStore[store]
	if current and current.Parent ~= nil then
		log(`{w.label} : un policier est déjà là pour {store.Name}`)
		return nil, nil
	end
	policeByStore[store] = nil
	local template = GuardService.FindGuardModel(Witness.Police.Template)
	if template == nil then
		warnOnce("template", `{Witness.Police.Template} absent de Assets/Guards : aucun policier (L-111)`)
		return nil, nil
	end
	local spawnAt = policeSpawn(w, store)
	local deadline = now + Witness.Police.ChaseDuration
	for _, player in suspectsOf(w) do
		if suspectRoot(player) then
			local speed = policeSpeed(player, w.zone)
			local model = GuardService.StartDriverChase({
				Template = template,
				Name = string.format(Witness.Police.CloneName, w.zone),
				Target = player,
				Spawn = spawnAt,
				Zone = w.zone,
				SpeedMultiplier = 0, -- vitesse fixe : MinSpeed
				MinSpeed = speed,
				Keeps = function(_target: Player): boolean
					return os.clock() < deadline
				end,
				CaughtMessage = Witness.Messages.Caught,
				Label = POLICE_LABEL,
				Tired = true,
				GiveUpReason = "poursuite trop longue",
				SendHome = sendHome, -- L-118 point 3 : attrapé, renvoyé à la base
			})
			if model then
				policeByStore[store] = model
				return player, model
			end
		end
	end
	return nil, nil
end

-- La police part : son du téléphone, policier, message aux joueurs vus. Une fois par appel.
local function dispatch(w: WitnessNpc, now: number)
	if w.state ~= "Call" or w.dispatched then
		return
	end
	w.dispatched = true
	MarkerSounds.play(Witness.CallSound, w.root)
	local store = w.store
	if store == nil then
		return
	end
	local suspect, police = launchPolice(w, store, now)
	for player in w.suspects do
		if player.Parent == Players then
			Net.Server.Notify:Fire(player, Witness.Messages.Called, "Alert")
		end
	end
	log(`{w.label} appelle la police pour {store.Name} : {if suspect then `policier lancé sur {suspect.Name}` else "personne à poursuivre"}`)
	for _, listener in table.clone(callListeners) do
		task.spawn(listener, store, suspect, police)
	end
end

local function startCall(w: WitnessNpc, now: number)
	setGauge(w, "Call", 1, 0, now)
	w.pausedAt = 0
	w.dispatched = false
	w.callStartedAt = now
	w.anims:Stop("Look")
	w.anims:Play("CallPolice") -- son marqueur Call lance dispatch (branché à la création du témoin)
end

-- Fuite à la casse (L-118 point 10) ----------------------------------------------------------------

-- La vitrine de son magasin vient de casser : le « ? » disparaît et il court à l'opposé de la vitrine.
local function flee(w: WitnessNpc, now: number)
	local store = w.store
	if store == nil or w.state == "Call" then
		return -- au téléphone : il finit son appel
	end
	toStroll(w, now)
	local position = w.root.Position
	local away = flat(position - windowPosition(store))
	if away.Magnitude < 1e-3 then
		away = -w.root.CFrame.LookVector
	end
	away = flat(away).Unit
	w.fleeGoal = position + away * Witness.FleeDistance
	w.fleeUntil = now + Witness.FleeMaxTime
	w.root.CFrame = CFrame.lookAt(position, position + away)
	w.humanoid.WalkSpeed = Witness.FleeSpeed
	w.humanoid:MoveTo(w.fleeGoal)
	w.anims:Stop("Walk")
	if w.anims:Play("Flee") then
		w.fleeAnim = "Flee"
	else
		w.fleeAnim = "Walk" -- Flee pas encore livrée : la marche, accélérée
		w.anims:Play("Walk", nil, nil, Witness.WalkAnimMax)
	end
	w.walking = false
	log(`{w.label} s'enfuit (vitrine de {store.Name} cassée)`)
end

-- Arrivé, bloqué ou à bout de temps : il reprend sa balade depuis le point du circuit le plus proche.
local function fleeStep(w: WitnessNpc, now: number)
	local position = w.root.Position
	local moved = flat(position - w.progressPos).Magnitude >= 1
	if moved then
		w.progressPos = position
		w.progressAt = now
	end
	local arrived = flat(w.fleeGoal - position).Magnitude <= Witness.PointReached
	if not arrived and now < w.fleeUntil and now - w.progressAt < Witness.FleeStuckTime then
		if now >= w.nextMoveAt then
			w.nextMoveAt = now + Witness.MoveRefresh
			w.humanoid:MoveTo(w.fleeGoal)
		end
		return
	end
	w.fleeUntil = 0
	if w.fleeAnim then
		w.anims:Stop(w.fleeAnim)
		w.fleeAnim = nil
	end
	local nearest = math.huge
	for index, point in w.path do
		local distance = flat(point - position).Magnitude
		if distance < nearest then
			nearest = distance
			w.pathIndex = index
		end
	end
	stopWalking(w)
	w.nextMoveAt = now
	w.progressAt = now
end

-- Nuit (L-117 point 2) --------------------------------------------------------------------------------

-- La nuit, les témoins ne sont pas là (Clément) : retirés du jeu, remis à leur place à l'aube.
local function setNight(night: boolean)
	local now = os.clock()
	for _, w in witnesses do
		if night and w.hiddenParent == nil and w.model.Parent ~= nil then
			if w.state ~= "Call" then
				toStroll(w, now)
			end
			w.fleeUntil = 0
			stopWalking(w)
			w.hiddenParent = w.model.Parent
			w.model.Parent = nil
		elseif not night and w.hiddenParent then
			w.model.Parent = w.hiddenParent
			w.hiddenParent = nil
			toStroll(w, now)
			pcall(function()
				w.root:SetNetworkOwner(nil)
			end)
		end
	end
	log(if night then `nuit : {#witnesses} témoin(s) retirés` else `jour : {#witnesses} témoin(s) remis`)
end

-- Boucle -----------------------------------------------------------------------------------------

local function update(w: WitnessNpc, now: number)
	if w.fleeUntil > 0 then
		fleeStep(w, now)
	elseif w.state == "Stroll" then
		strollStep(w, now)
	elseif w.state == "Watch" then
		local value = valueNow(w, now)
		if w.rate > 0 and value >= 1 then
			startCall(w, now)
		elseif w.rate < 0 and value <= 0 then
			toStroll(w, now)
		elseif w.rate == 0 and w.pausedAt > 0 and now - w.pausedAt >= Witness.PauseTimeout then
			calm(w, now)
		end
	elseif w.state == "Call" then
		if not w.dispatched and now - w.callStartedAt >= Witness.CallMarkerMaxWait then
			dispatch(w, now) -- pas de marqueur Call (animation pas livrée ou pas encore chargée)
		end
		if now - w.callStartedAt >= Witness.CallDuration then
			if not w.dispatched then
				dispatch(w, now)
			end
			toStroll(w, now)
		end
	end
end

local function remove(w: WitnessNpc, reason: string)
	local index = table.find(witnesses, w)
	if index then
		table.remove(witnesses, index)
	end
	local store = w.store
	local list = if store then byStore[store] else nil
	local at = if list then table.find(list, w) else nil
	if list and at then
		table.remove(list, at)
	end
	w.anims:Destroy()
	log(`{w.label} retiré ({reason})`)
end

local function step()
	local now = os.clock()
	if now < nextStepAt then
		return
	end
	nextStepAt = now + Witness.StepInterval
	for _, w in table.clone(witnesses) do
		if w.hiddenParent then
			continue -- la nuit
		end
		if not w.root:IsDescendantOf(Workspace) or w.humanoid.Health <= 0 then
			remove(w, "sorti du jeu")
			continue
		end
		local ok, err = pcall(update :: any, w, now)
		if not ok then
			warnOnce(`update:{w.label}`, `{w.label} : {err}`)
		end
	end
end

-- Mise en place ----------------------------------------------------------------------------------

-- Le magasin taggé NPCStore de la map qui porte ce nom.
local function findStore(name: string): Model?
	for _, inst in CollectionService:GetTagged(STORE_TAG) do
		if inst:IsA("Model") and inst.Name == name and inMap(inst) then
			return inst :: Model
		end
	end
	return nil
end

-- Les points du circuit du témoin : Attachments WitnessPath_NN du WitnessPaths le plus proche au-dessus
-- de lui, dans l'ordre des numéros.
local function pathOf(model: Model): { Vector3 }
	local parent = model.Parent
	local paths: Instance? = nil
	while parent and parent ~= Workspace and paths == nil do
		paths = parent:FindFirstChild(PATHS_NAME)
		parent = parent.Parent
	end
	type Point = { number: number, position: Vector3 }
	local points: { Point } = {}
	if paths then
		for _, descendant in paths:GetDescendants() do
			local digits = string.match(descendant.Name, PATH_POINT_PATTERN)
			local number = if digits then tonumber(digits) else nil
			if number and descendant:IsA("Attachment") then
				table.insert(points, { number = number, position = (descendant :: Attachment).WorldPosition })
			end
		end
	end
	table.sort(points, function(a: Point, b: Point): boolean
		return a.number < b.number
	end)
	local list: { Vector3 } = {}
	for _, point in points do
		table.insert(list, point.position)
	end
	return list
end

-- Zone du témoin : celle de son magasin, sinon celle de son nom (NPC_Witness_Z<n>_…), sinon 1.
local function zoneOf(model: Model, store: Model?): number
	local value: any = if store then store:GetAttribute(ZONE_ATTRIBUTE) else nil
	if type(value) ~= "number" then
		local digits = string.match(model.Name, "_Z(%d+)")
		value = if digits then tonumber(digits) else nil
	end
	if type(value) == "number" and value >= 1 and value <= #Zones and value % 1 == 0 then
		return value
	end
	return 1
end

local function add(model: Model)
	local label = model.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootInst = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or rootInst == nil or not rootInst:IsA("BasePart") then
		warnOnce(`rig:{label}`, `{model:GetFullName()} : Humanoid ou HumanoidRootPart manquant, témoin ignoré (L-111)`)
		return
	end
	local root = rootInst :: BasePart
	-- Pour la partie en cours seulement : le Humanoid doit pouvoir le déplacer, et le serveur possède sa physique.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			(descendant :: BasePart).Anchored = false
		end
	end
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	for _, state in DISABLED_STATES do
		humanoid:SetStateEnabled(state, false)
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end

	local store: Model? = nil
	local watched = model:GetAttribute(WATCHED_ATTRIBUTE)
	if type(watched) == "string" and watched ~= "" then
		store = findStore(watched)
		if store == nil then
			warnOnce(`store:{label}`, `{label} : {WATCHED_ATTRIBUTE} = « {watched} », aucun magasin taggé {STORE_TAG} de ce nom dans la map : il se balade seulement`)
		end
	else
		warnOnce(`store:{label}`, `{label} : attribut {WATCHED_ATTRIBUTE} manquant (le nom du magasin regardé) : il se balade seulement`)
	end

	local okScale, scale = pcall(function(): number
		return model:GetScale()
	end)
	local size = if okScale and isPositiveNumber(scale) then scale else 1
	local path = pathOf(model)
	local now = os.clock()
	local digits = string.match(label, "_(%d+)$")
	local number = (if digits then tonumber(digits) else nil) or 1
	local w: WitnessNpc = {
		model = model,
		humanoid = humanoid,
		root = root,
		anims = AnimPlayer.new(animator :: Animator, AnimPlayer.modelFolder(model), Animations.Witness, ANIM_LABEL),
		label = label,
		store = store,
		zone = zoneOf(model, store),
		gait = math.clamp(Witness.WalkSpeed / (Witness.WalkAnimSpeed * size), Witness.WalkAnimMin, Witness.WalkAnimMax),
		path = path,
		pathIndex = 1,
		pathStep = if number % 2 == 0 then -1 else 1,
		pauseUntil = 0,
		nextMoveAt = now,
		progressPos = root.Position,
		progressAt = now,
		walking = false,
		state = "Stroll",
		fill = 0,
		rate = 0,
		at = now,
		pausedAt = 0,
		suspects = {},
		callStartedAt = 0,
		dispatched = false,
		fleeUntil = 0,
		fleeGoal = root.Position,
		fleeAnim = nil,
		hiddenParent = nil,
	}
	-- Il part du point du circuit le plus proche de lui.
	local nearest = math.huge
	for index, point in path do
		local distance = flat(point - root.Position).Magnitude
		if distance < nearest then
			nearest = distance
			w.pathIndex = index
		end
	end
	if #path == 0 then
		warnOnce(`path:{w.zone}`, `{label} : aucun point {PATHS_NAME}/WitnessPath_NN au-dessus de lui : il reste sur place`)
	end
	w.anims:OnMarker("CallPolice", CALL_MARKER, function()
		dispatch(w, os.clock()) -- premier marqueur de l'appel seulement (dispatched)
	end)
	w.anims:Play("Idle")
	setGauge(w, "Stroll", 0, 0, now)
	model:AddTag(WitnessGauge.Tag)
	table.insert(witnesses, w)
	if store then
		local list = byStore[store]
		if list == nil then
			list = {}
			byStore[store] = list
		end
		table.insert(list, w)
	end
end

-- API --------------------------------------------------------------------------------------------

local NO_WITNESS: { WitnessNpc } = {}

-- Les témoins qui regardent ce magasin (liste vide s'il n'y en a pas).
local function witnessesOf(store: Model): { WitnessNpc }
	local list = byStore[store]
	return if list then list else NO_WITNESS
end

local function each(store: Model, action: (w: WitnessNpc, now: number) -> boolean): boolean
	local list = byStore[store]
	if list == nil then
		return false
	end
	local now = os.clock()
	local done = false
	for _, w in table.clone(list) do
		if action(w, now) then
			done = true
		end
	end
	return done
end

function WitnessService.Raise(store: Model, suspect: Player?, fillTime: number?): boolean
	local duration = if isPositiveNumber(fillTime) then fillTime :: number else Witness.FillTime
	return each(store, function(w: WitnessNpc, now: number): boolean
		return raise(w, suspect, duration, now)
	end)
end

function WitnessService.Pause(store: Model): boolean
	return each(store, pause)
end

function WitnessService.Calm(store: Model): boolean
	return each(store, calm)
end

function WitnessService.GetFill(store: Model): number
	local best = 0
	local now = os.clock()
	for _, w in witnessesOf(store) do
		best = math.max(best, if w.state == "Call" then 1 else valueNow(w, now))
	end
	return best
end

function WitnessService.IsCalling(store: Model): boolean
	for _, w in witnessesOf(store) do
		if w.state == "Call" then
			return true
		end
	end
	return false
end

function WitnessService.OnCall(listener: CallListener): () -> ()
	table.insert(callListeners, listener)
	return function()
		local index = table.find(callListeners, listener)
		if index then
			table.remove(callListeners, index)
		end
	end
end

function WitnessService.GetState(store: Model): { State }
	local list: { State } = {}
	local now = os.clock()
	for _, w in witnessesOf(store) do
		local count = 0
		for _ in w.suspects do
			count += 1
		end
		table.insert(list, { Witness = w.model, State = w.state, Fill = valueNow(w, now), Rate = w.rate, Suspects = count })
	end
	return list
end

function WitnessService.Start()
	for _, descendant in Workspace:GetDescendants() do
		if
			descendant:IsA("Model")
			and string.sub(descendant.Name, 1, #WITNESS_PREFIX) == WITNESS_PREFIX
			and descendant:FindFirstChildOfClass("Humanoid") ~= nil
			and inMap(descendant)
		then
			local ok, err = pcall(add :: any, descendant)
			if not ok then
				warn(`[WitnessService] {descendant:GetFullName()} : témoin non pris en charge : {err}`)
			end
		end
	end
	if #witnesses == 0 then
		log("aucun témoin NPC_Witness_* dans la map : rien à faire (L-111)")
		return
	end
	local watching = 0
	for _, w in witnesses do
		if w.store then
			watching += 1
		end
	end
	log(`{#witnesses} témoin(s), dont {watching} qui regardent un magasin`)

	WindowService.OnHit(function(player: Player, _windowId: string, kind: WindowService.WindowKind, model: Model, _damage: number)
		if kind == "NPC" then
			WitnessService.Raise(model, player)
		end
	end)
	WindowService.OnBroken(function(info: WindowService.BreakInfo)
		if info.Kind == "NPC" then
			each(info.Model, function(w: WitnessNpc, now: number): boolean
				flee(w, now)
				return true
			end)
		end
	end)
	-- Nuit (L-117 point 2) et renvoi à la base par la police (L-118 point 3) : NightCycleService, s'il
	-- existe (require protégé : les bancs n'en ont pas toujours).
	local okNight, night = pcall(function(): any
		return require(script.Parent:FindFirstChild("NightCycleService") :: any) :: any
	end)
	if okNight and type(night) == "table" then
		local api: any = night
		sendHome = api.SendHome
		local onPhase: any = api.OnPhaseChanged
		local isNight: any = api.IsNight
		if onPhase ~= nil and isNight ~= nil then
			(onPhase :: any)(function()
				setNight((isNight :: any)() == true)
			end)
			if (isNight :: any)() == true then
				setNight(true)
			end
		end
	else
		log("NightCycleService indisponible : témoins présents la nuit, la police ne renvoie pas à la base")
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, w in witnesses do
			w.suspects[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return WitnessService
