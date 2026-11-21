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
--   5. Police : des copies de Assets/Guards/NPC_Police (Witness.Police) arrivent en courant du bout de la
--      rue (le point du circuit le plus loin de la vitrine, côte à côte à Police.SpawnSpacing studs ; sans
--      circuit, à côté du témoin). Vague 43 (Cantin, 2026-11-14) : UN POLICIER PAR JOUEUR qui a frappé la
--      vitrine pendant ce braquage (les suspects du témoin : chaque coup validé de WindowService.OnHit,
--      jusqu'au départ de la police ; vidés quand il reprend sa balade), du dernier à avoir frappé au
--      premier, au plus Police.MaxPerStore policiers en jeu pour ce magasin. Un suspect parti, mort, à
--      l'abri en zone safe, déjà poursuivi par un policier de ce magasin, ou refusé par GuardService (déjà
--      poursuivi par un policier ou un conducteur) n'en a pas. Avant : un seul policier, sur le dernier.
--      Chaque policier a sa propre poursuite. C'est GuardService qui la pilote
--      (StartDriverChase : même chemin, même capture à Balance.Guard.CatchDistance, même coup au
--      marqueur Impact de Catch, même étourdissement, colis perdu s'il en porte un, ChaseState donc
--      UI_Chase et MUS_Chase). Vitesse : celle du vigile de jour de la zone (ou du tutoriel) ×
--      Police.SpeedFactor. Fin : capture, zone safe, ou Police.ChaseDuration s de poursuite, puis Tired et
--      fondu (GuardService le retire du jeu ; oublié ici dès qu'il n'est plus en jeu). Attrapé (L-118 point 3) : renvoyé à la base
--      (NightCycleService.SendHome, Night.SendHomeDelay s après le coup), comme la nuit.
--   6. Nuit (Clément, L-117 point 2) : les témoins ne sont pas là. À la tombée de la nuit, ils sont
--      retirés du jeu (Parent = nil) ; à l'aube, remis où ils étaient, et la balade reprend.
--   7. Le témoin qui filme la casse (Clément, L-172 ; valeurs : Witness.Photo ; Photo.Enabled = false :
--      l'ancien déroulé ci-dessus) :
--      a. au premier coup (point 2), au lieu de regarder sur place, il marche (Walk, Photo.ApproachSpeed, plus vite s'il est loin : a196)
--         jusqu'à son poste : Photo.Distance studs devant la vitrine (du côté où il est ; normale de la vitre
--         Window, sinon la ligne vitrine → témoin), décalé de Photo.SideOffset studs sur le côté (témoin
--         impair à droite, pair à gauche). Arrivé ou bloqué Witness.StuckTime s : il se tourne et joue Look.
--         Le « ? » monte pendant ce temps comme avant ; plein en chemin, il s'arrête et appelle sur place ;
--      b. l'appel fini (CallDuration), au lieu de reprendre sa balade, il filme : le « ! » s'efface
--         (WitnessState = "Stroll"), il joue TakePhoto en boucle (sans elle, il garde sa pose CallPolice) et
--         à chaque marqueur Flash (sans marqueur, toutes les Photo.Interval s ; jamais deux à moins de
--         Photo.MinInterval s) le compteur WitnessFlash du témoin monte (chaque client joue alors le flash de
--         FX_Witness_Flash, WitnessController) et le son Photo.Sound part sur lui s'il existe ;
--      c. il arrête et reprend sa balade (depuis le point du circuit le plus proche) quand un policier du
--         magasin arrive à Photo.PoliceArrive studs de la vitrine, quand tous les policiers du magasin sont
--         repartis, quand aucun voleur n'est plus dehors, vivant et à Photo.LeaveDistance studs de la
--         vitrine (parti, mort, à l'abri en zone safe), ou au bout de Photo.MaxTime s ;
--      d. pendant qu'il filme : la casse ne le fait pas fuir, les coups ne relancent pas son « ? » (le
--         joueur qui frappe compte comme voleur), IsCalling est faux. Les autres témoins fuient toujours à
--         la casse (point 3) tant que leur « ? » n'est pas plein.
--   8. Vague 66 (a221, Clément, L-210 point 4 : « il fonce, arrive vite et photographie avec flash » ; Photo.Rush = false :
--      le point 7 tel quel) : au point 7a, il court à son poste à Photo.RushSpeed au moins (animation Photo.RushAnim, Flee de
--      Clément, sinon Walk accélérée) ; arrivé, au lieu de Look, il photographie déjà (TakePhoto, flash au marqueur Flash,
--      sinon tout de suite puis toutes les Photo.Interval s ; sans TakePhoto, Look) pendant que son « ? » monte. « ? »
--      plein : il range l'appareil et appelle (point 4), puis filme (7b). La casse le fait toujours fuir (point 3) tant
--      que son « ? » n'est pas plein. Avant, le premier flash venait 12 s après le premier coup (« ? » de 8 s, appel de
--      4 s) : un joueur seul casse en 6,5 s, le témoin fuyait avant d'avoir photographié (ce que Clément n'a jamais vu).
--   9. f70c2 (Cantin, 18/11 : passage course → pose pas fluide) : sur ses Photo.BrakeDistance derniers studs il freine (à chaque
--      image, sa course ralentit avec lui), il est arrivé à Photo.ArriveDistance studs ; la course s'efface en Photo.StopFade s
--      pendant que TakePhoto (ou Look) arrive en Photo.PoseFade s, et il se tourne vers la vitrine en Photo.TurnTime s.
--  10. a269 (Cantin, 20/11 ; Witness.Avoid) : ses pièces passent dans le groupe de collision Avoid.Group (aucun choc
--      avec un témoin ou un vigile ; joueurs inchangés), et les vigiles l'évitent (Npc/NpcAvoid). a269c (Play f81b,
--      22/11 : l'écart dynamique d'a269 et a269b ratait près des poteaux) : il n'a plus d'écart dynamique. Il marche sur
--      SA voie (Npc/WitnessLanes, Avoid.Lanes) : son circuit décalé de Avoid.Lane studs sur sa droite, dans son sens de
--      marche, corrigé une fois au départ segment par segment devant les poteaux et les bornes ; les deux témoins d'une
--      zone sont donc toujours à 2 × Lane studs l'un de l'autre, pauses comprises. Point de la voie atteint à
--      Avoid.LaneReach studs. Filet : sans avancer de Avoid.UnstickMove studs en Avoid.UnstickTime s, il va à un point
--      libre à côté de lui (Avoid.UnstickSide studs à droite, sinon à gauche ; au plus UnstickTime s), puis vise le point
--      suivant. Avoid.Players (V0 false) : s'il est vrai, il s'arrête devant un joueur qui vient sur sa ligne. a269d
--      (Play f81c, 22/11) : les voies voient aussi les poteaux sans collision et passent devant un mur collé au circuit ;
--      le filet choisit un point d'où il voit son point visé (sinon son point d'avant), puis reprend le même point (le
--      suivant au second échec de suite) ; à plus de Avoid.LaneMax + Avoid.LaneLeash studs de sa voie, il revient au
--      point le plus proche ; un passage étroit (voies à moins de 2 × Lane − LaneStep studs) ne prend qu'un témoin à
--      la fois : l'autre attend à l'entrée, arrêté, au plus Avoid.NarrowWait s ; pas de pause dedans. Une seule zone
--      calcule ses voies par pas.
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
--       listener(store, suspect, police) quand la police est appelée pour `store` : `suspect` = le premier
--       joueur poursuivi (le dernier à avoir frappé) et `police` = sa copie en jeu, ou nil si aucun
--       policier n'est parti à cet appel. Les autres : GetPolice.
--   WitnessService.GetPolice(store) -> { { Player: Player, Police: Model } }
--       Vague 43 : les policiers en jeu pour ce magasin et leur cible (une copie ; vide sans policier).
--   Exemple (L-112) : au début de l'ouverture `WitnessService.Raise(store, player)`, au relâché
--   `WitnessService.Pause(store)`, colis ouvert ou joueur sorti `WitnessService.Calm(store)`.
--   WitnessService.GetState(store) -> { State }    pour un test : état de chaque témoin du magasin (L-172 :
--       Approaching, Filming, Flashes ; a221 : Snapping)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Witness = require(Shared.Config.Witness)
local Zones = require(Shared.Config.Zones)
local Balance = require(Shared.Config.Balance)
local Animations = require(Shared.Contract.Animations)
local Find = require(Shared.Contract.Find)
local AnimPlayer = require(Shared.Anim.AnimPlayer)
local MarkerSounds = require(Shared.Anim.MarkerSounds)
local Net = require(Shared.Net.Net)
local WitnessGauge = require(Shared.WitnessGauge)

local GuardService = require(script.Parent.GuardService)
local WindowService = require(script.Parent.WindowService)
-- a269 (Cantin, 20/11 ; Witness.Avoid) : deux PNJ qui se croisent s'écartent chacun sur leur droite (Npc/NpcAvoid), et
-- les témoins ne se poussent plus (groupe de collision). Absent (faux arbres des bancs plus anciens) : la balade d'avant.
local NpcAvoid = (function(): any
	local ok, result = pcall(function(): any
		return require((script.Parent :: any).Npc.NpcAvoid)
	end)
	return if ok and type(result) == "table" then result else nil
end)() :: any
-- a269c (Witness.Avoid.Lanes) : chaque témoin marche sur sa voie, le circuit décalé sur sa droite. Absent : le circuit.
local WitnessLanes = (function(): any
	local ok, result = pcall(function(): any
		return require((script.Parent :: any).Npc.WitnessLanes)
	end)
	return if ok and type(result) == "table" then result else nil
end)() :: any

type AnimPlayerT = AnimPlayer.AnimPlayer
type GaugeState = WitnessGauge.State

export type State = {
	Witness: Model,
	State: GaugeState,
	Fill: number,
	Rate: number,
	Suspects: number,
	Approaching: boolean, -- L-172 : il marche vers son poste devant la vitrine
	Filming: boolean, -- L-172 : il prend des photos au flash
	Flashes: number, -- L-172 : flashs depuis le début de la partie (attribut WitnessFlash)
	Snapping: boolean, -- a221 (Photo.Rush) : il photographie à son poste, « ? » qui monte
}

export type CallListener = (store: Model, suspect: Player?, police: Model?) -> ()

-- Un policier en jeu et le joueur qu'il poursuit (vague 43).
export type PoliceChase = { Player: Player, Police: Model }

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
	-- L-172 : il s'approche de la vitrine (vers approachGoal), puis filme
	approaching: boolean,
	approachGoal: Vector3,
	filming: boolean,
	filmStartedAt: number,
	photoAnim: boolean, -- TakePhoto joue (sinon il garde la pose CallPolice)
	flashMarkerSeen: boolean, -- un marqueur Flash est venu pendant ces photos : plus de rythme de secours
	nextFlashAt: number,
	lastFlashAt: number,
	flashCount: number,
	policeSeen: boolean, -- un policier du magasin était en jeu pendant ces photos
	-- Vague 66 (a221, L-210 point 4, Photo.Rush) : la course de l'approche, et les photos dès l'arrivée (« ? » qui monte)
	rushAnim: string?, -- l'animation de course qui joue pendant l'approche ; nil : Walk
	snapping: boolean, -- il photographie à son poste pendant que son « ? » monte
	-- f70c2 : le pas de croisière de l'approche (setApproachSpeed), le freinage appliqué (1 = aucun), la rotation en cours
	approachSpeed: number,
	paceRatio: number,
	turning: boolean,
	turnAt: number,
	turnFrom: number, -- cap de départ (radians)
	turnBy: number, -- angle à tourner (radians, de −π à π)
	avoiding: boolean, -- a269 : en balade, il s'écarte d'un autre PNJ (NpcAvoid ; plus utilisé par la balade depuis a269c)
	-- a269c : sa voie (Npc/WitnessLanes), calculée à sa première balade ; nil : le circuit même
	pathsFolder: Instance?, -- le dossier WitnessPaths de son circuit (les deux témoins de la zone partagent les voies)
	lane: { Vector3 }?,
	laneReady: boolean,
	unstickUntil: number, -- a269c (filet) : il va à unstickGoal jusqu'à cette heure (os.clock) ; 0 : non
	unstickGoal: Vector3,
	fails: number, -- a269d : échecs du filet de suite sur le point visé (le suivant au second)
	narrowWaitUntil: number, -- a269d : il attend à l'entrée d'un passage étroit jusqu'à cette heure ; 0 : non
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
local POLICE_ARRIVE_SOUND = "Police_Arrive" -- vague 72 (a246, L-229 B)

-- Le marqueur de CallPolice dans le contrat (Call).
local CALL_MARKER = "Call"
local FLASH_MARKER = "Flash" -- L-172 : celui de TakePhoto
for _, spec in Animations.Witness do
	local marker = spec.Marker
	if spec.Name == "CallPolice" and marker then
		CALL_MARKER = marker
	elseif spec.Name == "TakePhoto" and marker then
		FLASH_MARKER = marker
	end
end
local PHOTO = Witness.Photo
local AVOID: any = (Witness :: any).Avoid -- a269

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
local policeByStore: { [Model]: { PoliceChase } } = {} -- les policiers en jeu de chaque magasin (vague 43)
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

-- `fade` (f70c2) : fondu de sortie de la marche et de la course (nil : celui de Roblox).
local function stopWalking(w: WitnessNpc, fade: number?)
	w.humanoid:MoveTo(w.root.Position)
	if w.avoiding then
		w.avoiding = false -- a269 : arrêté, il ne s'écarte plus
		if NpcAvoid then
			NpcAvoid.Clear(w.root)
		end
	end
	if w.walking then
		w.walking = false
		w.anims:Stop("Walk", fade)
	end
	local rush = w.rushAnim
	if rush then
		w.rushAnim = nil -- a221 : la course de l'approche
		w.anims:Stop(rush, fade)
	end
end

-- a221 (Photo.Rush) : il ne photographie plus à son poste.
local function stopSnapping(w: WitnessNpc)
	if w.snapping then
		w.snapping = false
		w.anims:Stop("TakePhoto")
	end
end

local function nextIndex(w: WitnessNpc): number
	local count = #w.path
	return (w.pathIndex - 1 + w.pathStep) % count + 1
end

-- a269c : un réglage numérique de Witness.Avoid, ou `default`.
local function avoidNumber(key: string, default: number): number
	local value = if type(AVOID) == "table" then AVOID[key] else nil
	return if type(value) == "number" and value == value then value else default
end

-- a269c : ce que les balayages des voies et du filet ignorent : les témoins (leurs dossiers), leurs circuits
-- (a269d : les points WitnessPaths) et les joueurs.
local function laneIgnore(): { Instance }
	local ignore: { Instance } = {}
	for _, w in witnesses do
		local parent = w.model.Parent
		table.insert(ignore, if parent and parent ~= Workspace then parent else w.model)
		local folder = w.pathsFolder
		if folder and not table.find(ignore, folder) then
			table.insert(ignore, folder)
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(ignore, character)
		end
	end
	return ignore
end

-- a269c : les voies d'un circuit (sens +1 et −1), calculées une fois pour ses deux témoins ; a269d : ses passages
-- étroits ([segment] = numéro) et le témoin engagé dans chacun.
type Lanes = {
	forward: { Vector3 },
	backward: { Vector3 },
	narrow: { [number]: number },
	claims: { [number]: WitnessNpc },
}
local laneCache: { [Instance]: Lanes } = {}
local lanesBuiltAt = -1 -- a269d : une seule zone calculée par pas (os.clock du pas)
local function laneOf(w: WitnessNpc, now: number): { Vector3 }?
	local folder = w.pathsFolder
	if WitnessLanes == nil or folder == nil or #w.path < 2 or WitnessLanes.Settings() == nil then
		return nil
	end
	local found = laneCache[folder]
	if found == nil then
		lanesBuiltAt = now
		local position = w.root.Position
		local nearest, height = math.huge, 0
		for _, point in w.path do
			local distance = flat(point - position).Magnitude
			if distance < nearest then
				nearest = distance
				height = position.Y - point.Y -- sa racine au-dessus des points du circuit
			end
		end
		local ok, forward, backward, fixes, narrow = pcall(WitnessLanes.Build, w.path, height, laneIgnore())
		if not ok or type(forward) ~= "table" or type(backward) ~= "table" then
			warnOnce(`lane:{w.zone}`, `{w.label} : voies des témoins incalculables ({forward}) : il marche sur le circuit`)
			return nil
		end
		found = {
			forward = forward,
			backward = backward,
			narrow = if type(narrow) == "table" then narrow else {},
			claims = {},
		}
		laneCache[folder] = found
		if type(fixes) == "table" and #fixes > 0 then
			print(`[WitnessService] voies des témoins de la zone {w.zone}, segments corrigés : {table.concat(fixes, " ; ")}`)
		end
	end
	local lanes = found :: Lanes
	return if w.pathStep < 0 then lanes.backward else lanes.forward
end

local function walkTo(w: WitnessNpc, goal: Vector3, now: number)
	w.nextMoveAt = now + Witness.MoveRefresh
	w.humanoid.WalkSpeed = Witness.WalkSpeed
	w.humanoid:MoveTo(goal)
	if not w.walking then
		w.walking = true
		w.anims:Play("Walk", nil, nil, w.gait)
	end
end

-- a269d : le point d'où il vient (celui d'avant pathIndex, dans son sens), et le segment où il marche (k : du point k
-- au suivant, dans l'ordre du circuit).
local function previousIndex(w: WitnessNpc): number
	return (w.pathIndex - 1 - w.pathStep) % #w.path + 1
end
local function segmentOf(w: WitnessNpc): number
	return if w.pathStep > 0 then previousIndex(w) else w.pathIndex
end

-- a269d (laisse) : le point de sa voie le plus proche de lui, à quelle distance, et le point visé ensuite.
local function nearestOnLane(w: WitnessNpc, lane: { Vector3 }, position: Vector3): (number, Vector3, number)
	local count = #lane
	local best, point, ahead = math.huge, lane[w.pathIndex], w.pathIndex
	for k = 1, count do
		local k2 = k % count + 1
		local a, b = lane[k], lane[k2]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local l2 = abx * abx + abz * abz
		local t = if l2 > 1e-9 then math.clamp(((position.X - a.X) * abx + (position.Z - a.Z) * abz) / l2, 0, 1) else 0
		local q = a + (b - a) * t
		local distance = flat(position - q).Magnitude
		if distance < best then
			best, point = distance, q
			ahead = if w.pathStep > 0 then k2 else k
		end
	end
	return best, point, ahead
end

-- a269d (passage étroit) : un seul témoin à la fois dans un passage étroit de sa voie ; le premier engagé passe.
-- L'autre attend à l'entrée, arrêté (Idle), au plus Avoid.NarrowWait s. true : il attend.
local function narrowWait(w: WitnessNpc, now: number, entrance: Vector3, reach: number): boolean
	local folder = w.pathsFolder
	local lanes = if folder then laneCache[folder] else nil
	if lanes == nil or next(lanes.narrow) == nil then
		return false
	end
	local id = lanes.narrow[segmentOf(w)]
	local claims = lanes.claims
	for passage, owner in claims do
		if owner == w and passage ~= id then
			claims[passage] = nil -- sorti du passage
		end
	end
	if id == nil then
		w.narrowWaitUntil = 0
		return false
	end
	local owner = claims[id]
	if owner == nil or owner == w or owner.state ~= "Stroll" or owner.hiddenParent ~= nil or owner.model.Parent == nil
		or lanes.narrow[segmentOf(owner)] ~= id
	then
		claims[id] = w
		w.narrowWaitUntil = 0
		return false
	end
	if flat(entrance - w.root.Position).Magnitude > reach + 1.5 then
		return false -- déjà dedans (reprise de balade) : il continue
	end
	if w.narrowWaitUntil == 0 then
		w.narrowWaitUntil = now + avoidNumber("NarrowWait", 8)
	end
	if now >= w.narrowWaitUntil then
		return false -- attendu assez : il passe
	end
	if w.walking then
		stopWalking(w)
	end
	w.progressPos = w.root.Position
	w.progressAt = now
	w.nextMoveAt = now
	return true
end

local function strollStep(w: WitnessNpc, now: number)
	local count = #w.path
	if count == 0 or now < w.pauseUntil then
		return
	end
	if not w.laneReady then
		local folder = w.pathsFolder
		if folder and laneCache[folder] == nil and lanesBuiltAt == now then
			return -- a269d : une autre zone vient d'être calculée à ce pas
		end
		w.laneReady = true
		w.lane = laneOf(w, now) -- a269c ; nil : le circuit même, comme avant a269
	end
	local lane = w.lane
	local points = lane or w.path
	local position = w.root.Position
	local reach = if lane then avoidNumber("LaneReach", Witness.PointReached) else Witness.PointReached
	-- a269c (filet) : il se dégage vers un point libre à côté de lui ; a269d : puis il reprend le même point visé.
	if w.unstickUntil > 0 then
		if now < w.unstickUntil and flat(w.unstickGoal - position).Magnitude > reach then
			if now >= w.nextMoveAt then
				walkTo(w, w.unstickGoal, now)
			end
			return
		end
		w.unstickUntil = 0
		w.progressPos = position
		w.progressAt = now
		w.nextMoveAt = now
	end
	-- a269d (laisse) : à plus de Avoid.LaneMax + Avoid.LaneLeash studs de sa voie, il revient au point le plus proche.
	if lane then
		local distance, point, ahead = nearestOnLane(w, lane, position)
		if distance > avoidNumber("LaneMax", 4) + avoidNumber("LaneLeash", 2) then
			w.pathIndex = ahead
			w.fails = 0
			w.unstickGoal = point
			w.unstickUntil = now + distance / math.max(Witness.WalkSpeed, 1) + 2 * avoidNumber("UnstickTime", 1)
			w.progressPos = position
			w.progressAt = now
			walkTo(w, point, now)
			return
		end
	end
	local goal = points[w.pathIndex]
	if flat(goal - position).Magnitude <= reach then
		if count == 1 then
			stopWalking(w)
			return
		end
		w.pathIndex = nextIndex(w)
		w.fails = 0
		w.nextMoveAt = now
		local folder = w.pathsFolder
		local lanes = if lane and folder then laneCache[folder] else nil
		local narrow = lanes ~= nil and lanes.narrow[segmentOf(w)] ~= nil -- a269d : jamais de pause dans un passage étroit
		if not narrow and rng:NextNumber() < Witness.PauseChance then
			w.pauseUntil = now + rng:NextNumber(Witness.PauseMin, Witness.PauseMax)
			w.progressAt = w.pauseUntil
			stopWalking(w)
			return
		end
		goal = points[w.pathIndex]
	end
	-- a269d : passage étroit occupé par l'autre témoin : il attend à l'entrée.
	if lane and count > 1 and narrowWait(w, now, points[previousIndex(w)], reach) then
		return
	end
	-- Bloqué (un joueur devant lui, un obstacle) : il vise le point suivant (a269c, sur sa voie : il se dégage d'abord à
	-- côté de lui, au bout de Avoid.UnstickTime s ; a269d : le point suivant seulement au second échec sur ce point).
	local moved = if lane then avoidNumber("UnstickMove", 1) else 1
	local unstickTime = if lane then avoidNumber("UnstickTime", 0) else 0
	if flat(position - w.progressPos).Magnitude >= moved then
		w.progressPos = position
		w.progressAt = now
	elseif unstickTime > 0 and now - w.progressAt >= unstickTime then
		w.progressPos = position
		w.progressAt = now
		w.fails += 1
		if w.fails >= 2 then
			w.fails = 0
			if count > 1 then
				w.pathIndex = nextIndex(w)
				goal = points[w.pathIndex]
			end
			w.nextMoveAt = now
		else
			local back = if count > 1 then points[previousIndex(w)] else nil
			local side = WitnessLanes.Sidestep(position, goal - position, goal, back, laneIgnore())
			if side then
				w.unstickGoal = side
				w.unstickUntil = now + unstickTime
				walkTo(w, side, now)
				return
			end
		end
	elseif now - w.progressAt >= Witness.StuckTime and count > 1 then
		w.pathIndex = nextIndex(w)
		w.progressAt = now
		w.nextMoveAt = now
		goal = points[w.pathIndex]
	end
	-- a269b (Avoid.Players, V0 false depuis a269c : un témoin attendait sans fin derrière un joueur immobile) : un
	-- joueur vient sur sa ligne, tout près : il s'arrête là.
	if NpcAvoid and NpcAvoid.PlayerAhead(w.root, goal, Witness.WalkSpeed) then
		if w.walking then
			stopWalking(w)
		end
		w.nextMoveAt = now -- il repart dès que la ligne est libre
		return
	end
	if now >= w.nextMoveAt then
		walkTo(w, goal, now)
	end
end

local function toStroll(w: WitnessNpc, now: number)
	setGauge(w, "Stroll", 0, 0, now)
	w.pausedAt = 0
	w.dispatched = false
	table.clear(w.suspects)
	w.anims:Stop("Look")
	w.anims:Stop("CallPolice")
	if w.approaching then
		w.approaching = false
		stopWalking(w) -- la balade relance Walk à son pas
	end
	if w.filming then
		w.filming = false
		w.anims:Stop("TakePhoto")
	end
	stopSnapping(w) -- a221
	w.turning = false -- f70c2 : la balade (ou la fuite) reprend la main sur son cap
	w.pauseUntil = 0
	w.unstickUntil = 0 -- a269c
	w.fails = 0 -- a269d
	w.narrowWaitUntil = 0
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

-- f70c2 : le cap (radians) d'une direction à plat, celui de CFrame.Angles(0, cap, 0), et l'inverse.
local function yawOf(v: Vector3): number
	return math.atan2(-v.X, -v.Z)
end
local function yawDirection(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

-- Il se tourne vers la vitrine de son magasin. f70c2 : avec la règle du témoin qui filme (Photo.Enabled), en douceur,
-- en Photo.TurnTime s (turnStep, à chaque image) ; sinon (ou TurnTime = 0) d'un coup, comme avant.
local function faceWindow(w: WitnessNpc)
	local store = w.store
	if store then
		local position = w.root.Position
		local look = flat(windowPosition(store) - position)
		if look.Magnitude > 1e-3 then
			if PHOTO.Enabled and PHOTO.TurnTime > 0 then
				local from = flat(w.root.CFrame.LookVector)
				local to = yawOf(look)
				w.turnFrom = if from.Magnitude > 1e-3 then yawOf(from) else to
				w.turnBy = (to - w.turnFrom + math.pi) % (2 * math.pi) - math.pi -- par le plus court
				w.turnAt = os.clock()
				w.turning = true
			else
				w.root.CFrame = CFrame.lookAt(position, position + look.Unit)
			end
		end
	end
end

-- f70c2 : une image de la rotation vers la vitrine (courbe douce, smoothstep). Il ne tourne plus dès qu'il repart.
local function turnStep(w: WitnessNpc, now: number)
	if w.walking or w.approaching or w.fleeUntil > 0 then
		w.turning = false
		return
	end
	local t = math.clamp((now - w.turnAt) / PHOTO.TurnTime, 0, 1)
	local yaw = w.turnFrom + w.turnBy * (t * t * (3 - 2 * t))
	local position = w.root.Position
	w.root.CFrame = CFrame.lookAt(position, position + yawDirection(yaw))
	if t >= 1 then
		w.turning = false
	end
end

-- L-172 : la normale horizontale de la vitre Window (son axe le plus mince entre X et Z), ou nil.
local function windowNormal(store: Model): Vector3?
	local ok, normal = pcall(function(): Vector3?
		local window = Find.path(store, WINDOW)
		local frame: CFrame, size: Vector3
		if window and window:IsA("BasePart") then
			frame, size = (window :: BasePart).CFrame, (window :: BasePart).Size
		elseif window and window:IsA("Model") then
			frame, size = (window :: Model):GetBoundingBox()
		else
			return nil
		end
		local axis = flat(if size.X <= size.Z then frame.RightVector else frame.LookVector)
		return if axis.Magnitude > 1e-3 then axis.Unit else nil
	end)
	return if ok then normal else nil
end

-- L-172 : son poste, Photo.Distance studs devant la vitrine, du côté où il est, décalé de Photo.SideOffset.
local function photoSpot(w: WitnessNpc, store: Model): Vector3
	local window = windowPosition(store)
	local position = w.root.Position
	local toward = flat(position - window)
	local out = windowNormal(store) or (if toward.Magnitude > 1e-3 then toward.Unit else nil)
	if out == nil then
		return position
	end
	if out.X * toward.X + out.Z * toward.Z < 0 then
		out = out * -1 -- la normale du côté du témoin (la rue)
	end
	local side = Vector3.new(-out.Z, 0, out.X) * (PHOTO.SideOffset * w.pathStep)
	local spot = window + out * PHOTO.Distance + side
	return Vector3.new(spot.X, position.Y, spot.Z)
end

-- f70c2 (Cantin, 18/11) : le pas de l'approche, à chaque image. Loin de son poste, le pas de croisière (setApproachSpeed) ;
-- à moins de Photo.BrakeDistance studs, il freine (vitesse proportionnelle à la distance restante, jamais sous
-- Photo.BrakeMinSpeed), et sa course (ou sa marche) ralentit avec lui, au plus bas Photo.BrakeAnimMin.
local function approachPace(w: WitnessNpc)
	local cruise = w.approachSpeed
	if cruise <= 0 then
		return
	end
	local distance = flat(w.approachGoal - w.root.Position).Magnitude
	local ratio = 1
	if distance < PHOTO.BrakeDistance then
		ratio = math.clamp(distance / PHOTO.BrakeDistance, math.min(PHOTO.BrakeMinSpeed / cruise, 1), 1)
	end
	local speed = cruise * ratio
	w.humanoid.WalkSpeed = speed
	if math.abs(ratio - w.paceRatio) < 0.05 and (ratio < 1) == (w.paceRatio < 1) then
		return -- la vitesse de lecture suit par crans
	end
	w.paceRatio = ratio
	local rush = w.rushAnim
	if rush then
		w.anims:Play(rush, nil, nil, math.max(ratio, PHOTO.BrakeAnimMin)) -- déjà jouée : seule sa vitesse change
	else
		local gait = math.clamp(w.gait * speed / Witness.WalkSpeed, Witness.WalkAnimMin, Witness.WalkAnimMax)
		w.anims:Play("Walk", nil, nil, gait) -- déjà jouée : seule sa vitesse change (AnimPlayer)
	end
end

-- a196 (Cantin, T-087) : vitesse de l'approche, pour être au poste Photo.ApproachLead s avant que le « ? » soit
-- plein (`timeLeft` s), entre Photo.ApproachSpeed et Photo.ApproachMaxSpeed ; la marche (Walk) suit ce pas.
local function setApproachSpeed(w: WitnessNpc, timeLeft: number)
	local distance = flat(w.approachGoal - w.root.Position).Magnitude
	local time = timeLeft - PHOTO.ApproachLead
	local wanted = if time > 0 then distance / time else math.huge
	-- a221 (Photo.Rush) : il fonce, à RushSpeed au moins.
	local low = if PHOTO.Rush then math.max(PHOTO.ApproachSpeed, PHOTO.RushSpeed) else PHOTO.ApproachSpeed
	local speed = math.clamp(wanted, low, math.max(PHOTO.ApproachMaxSpeed, low))
	w.approachSpeed = speed -- f70c2 : le pas de croisière ; approachPace freine près du poste
	if PHOTO.Rush and w.rushAnim == nil and w.anims:Play(PHOTO.RushAnim) ~= nil then
		w.rushAnim = PHOTO.RushAnim -- a221 : la course de Clément à la place de la marche
		w.anims:Stop("Walk")
	end
	w.paceRatio = -1 -- la vitesse de lecture est réécrite
	approachPace(w)
end

-- a221 (Photo.Rush, L-210 point 4) : à son poste, il photographie tout de suite (TakePhoto, flash à ses marqueurs Flash,
-- sinon au rythme de Photo.Interval) pendant que son « ? » monte ; sans Rush, il regarde (Look) comme avant.
local function lookOrSnap(w: WitnessNpc, now: number)
	if not (PHOTO.Enabled and PHOTO.Rush and w.store) then
		w.anims:Play("Look", PHOTO.PoseFade)
		return
	end
	w.snapping = true
	w.flashMarkerSeen = false
	w.photoAnim = w.anims:Play("TakePhoto", PHOTO.PoseFade) ~= nil -- f70c2 : la pose arrive en fondu
	if not w.photoAnim then
		w.anims:Play("Look", PHOTO.PoseFade) -- TakePhoto pas livrée : il regarde, le flash part quand même
	end
	-- Avec TakePhoto, son premier marqueur Flash donne le premier flash (grâce de deux intervalles) ; sans elle, tout de suite.
	w.nextFlashAt = if w.photoAnim then now + PHOTO.Interval * 2 else now
	log(`{w.label} photographie la casse ({if w.photoAnim then "TakePhoto" else "TakePhoto pas livrée : Look"})`)
end

-- Il s'arrête, se tourne vers la vitrine et regarde. L-172 : il marche d'abord jusqu'à son poste.
local function startWatch(w: WitnessNpc, now: number, timeLeft: number)
	stopWalking(w)
	local store = w.store
	if PHOTO.Enabled and store then
		local spot = photoSpot(w, store)
		if flat(spot - w.root.Position).Magnitude > Witness.PointReached then
			w.approaching = true
			w.approachGoal = spot
			w.progressPos = w.root.Position
			w.progressAt = now
			w.nextMoveAt = now + Witness.MoveRefresh
			w.humanoid:MoveTo(spot)
			w.walking = true
			setApproachSpeed(w, timeLeft) -- a196
			return
		end
	end
	faceWindow(w)
	lookOrSnap(w, now) -- a221
end

-- L-172 : arrivé à son poste (ou bloqué), il se tourne vers la vitrine.
local function endApproach(w: WitnessNpc)
	w.approaching = false
	stopWalking(w, PHOTO.StopFade) -- f70c2 : la course s'efface en fondu
	faceWindow(w)
end

local function approachStep(w: WitnessNpc, now: number)
	local position = w.root.Position
	if flat(position - w.progressPos).Magnitude >= 1 then
		w.progressPos = position
		w.progressAt = now
	end
	if flat(w.approachGoal - position).Magnitude <= PHOTO.ArriveDistance or now - w.progressAt >= Witness.StuckTime then
		endApproach(w)
		log(`{w.label} est à son poste devant la vitrine`)
		lookOrSnap(w, now) -- a221
		return
	end
	if now >= w.nextMoveAt then
		w.nextMoveAt = now + Witness.MoveRefresh
		w.humanoid:MoveTo(w.approachGoal)
		setApproachSpeed(w, WitnessGauge.timeLeft(valueNow(w, now), w.rate)) -- a196 : le pas suit le « ? »
	end
end

local function raise(w: WitnessNpc, suspect: Player?, fillTime: number, now: number): boolean
	if w.hiddenParent or now < w.fleeUntil then
		return false -- caché la nuit, ou en fuite
	end
	if w.filming then
		if suspect then
			w.suspects[suspect] = now -- L-172 : il filme ; celui qui frappe compte comme voleur
		end
		return false
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
		startWatch(w, now, WitnessGauge.timeLeft(value, rate))
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

-- a157 : son HumanoidRootPart est-il dans une zone safe (Shared/SafeZone, par GuardService) ?
local function sheltered(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil and root:IsA("BasePart") and GuardService.IsInSafeZone((root :: BasePart).Position)
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
	local base = Zones[zone].GuardSpeed -- déjà × RealSpeedScale (Config/Zones)
	local ok, value = pcall(GuardService.GetSpeedOverride, player, zone)
	if ok and isPositiveNumber(value) then
		base = (value :: number) * Balance.Stats.RealSpeedScale -- vague 61 : vitesse imposée à l'échelle 1
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

-- Les policiers encore en jeu du magasin (la liste gardée ; ceux que GuardService a retirés sont oubliés).
local function activePolice(store: Model): { PoliceChase }
	local list = policeByStore[store]
	if list == nil then
		list = {}
		policeByStore[store] = list
	end
	for index = #list, 1, -1 do
		if list[index].Police.Parent == nil then
			table.remove(list, index)
		end
	end
	return list
end

local function chasedHere(list: { PoliceChase }, player: Player): boolean
	for _, entry in list do
		if entry.Player == player then
			return true
		end
	end
	return false
end

-- Point d'apparition du policier numéro `index` (0 pour le premier) de cet appel : côte à côte, à
-- Police.SpawnSpacing studs, alternativement à droite et à gauche du premier.
local function spawnFor(spawnAt: CFrame, index: number): CFrame
	if index <= 0 then
		return spawnAt
	end
	local side = if index % 2 == 1 then 1 else -1
	local offset = math.ceil(index / 2) * Witness.Police.SpawnSpacing * side
	return CFrame.new(spawnAt.Position + spawnAt.RightVector * offset)
end

-- Vague 43 : lance un policier sur chaque suspect encore poursuivable, du plus récent au plus ancien,
-- tant que le magasin a moins de Police.MaxPerStore policiers en jeu. Renvoie les policiers lancés.
local function launchPolice(w: WitnessNpc, store: Model, now: number): { PoliceChase }
	local launched: { PoliceChase } = {}
	local active = activePolice(store)
	local cap = math.max(math.floor(Witness.Police.MaxPerStore), 1)
	if #active >= cap then
		log(`{w.label} : déjà {#active} policier(s) pour {store.Name} (plafond {cap})`)
		return launched
	end
	local template = GuardService.FindGuardModel(Witness.Police.Template)
	if template == nil then
		warnOnce("template", `{Witness.Police.Template} absent de Assets/Guards : aucun policier (L-111)`)
		return launched
	end
	local spawnAt = policeSpawn(w, store)
	local deadline = now + Witness.Police.ChaseDuration
	for _, player in suspectsOf(w) do
		if #active >= cap then
			log(`{w.label} : plafond de {cap} policier(s) atteint pour {store.Name}, {player.Name} n'en a pas`)
			break
		end
		if chasedHere(active, player) then
			log(`{w.label} : un policier est déjà là pour {store.Name} ({player.Name})`)
			continue
		end
		if suspectRoot(player) then
			local speed = policeSpeed(player, w.zone)
			local model = GuardService.StartDriverChase({
				Template = template,
				Name = string.format(Witness.Police.CloneName, w.zone),
				Target = player,
				Spawn = spawnFor(spawnAt, #launched),
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
				local entry: PoliceChase = { Player = player, Police = model }
				-- Vague 72 (a246, L-229 B) : Police_Arrive en 3D sur le policier qui part (son absent : muet).
				pcall(function()
					local police = model :: Model
					MarkerSounds.play(POLICE_ARRIVE_SOUND, police.PrimaryPart or police:FindFirstChildWhichIsA("BasePart", true))
				end)
				table.insert(active, entry)
				table.insert(launched, entry)
			end
		end
	end
	if #active == 0 then
		policeByStore[store] = nil
	end
	return launched
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
	local launched = launchPolice(w, store, now)
	local first = launched[1]
	local suspect: Player? = if first then first.Player else nil
	local police: Model? = if first then first.Police else nil
	for player in w.suspects do
		if player.Parent == Players and not sheltered(player) then -- a157 : pas à l'abri en zone safe
			Net.Server.Notify:Fire(player, Witness.Messages.Called, "Alert")
		end
	end
	local names: { string } = {}
	for _, entry in launched do
		table.insert(names, entry.Player.Name)
	end
	log(`{w.label} appelle la police pour {store.Name} : {if #names > 0 then `{#names} policier(s) lancé(s) sur {table.concat(names, ", ")}` else "personne à poursuivre"}`)
	for _, listener in table.clone(callListeners) do
		task.spawn(listener, store, suspect, police)
	end
end

local function startCall(w: WitnessNpc, now: number)
	setGauge(w, "Call", 1, 0, now)
	w.pausedAt = 0
	w.dispatched = false
	w.callStartedAt = now
	if w.approaching then
		endApproach(w) -- L-172 : « ? » plein en chemin, il appelle là où il est
	end
	stopSnapping(w) -- a221 : il range l'appareil pour appeler
	w.anims:Stop("Look")
	w.anims:Play("CallPolice") -- son marqueur Call lance dispatch (branché à la création du témoin)
end

-- Photos au flash (L-172) -------------------------------------------------------------------------

-- Un flash : le compteur WitnessFlash monte (chaque client joue FX_Witness_Flash) et le son part.
-- Jamais deux à moins de Photo.MinInterval s.
local function flash(w: WitnessNpc, now: number): boolean
	if now - w.lastFlashAt < PHOTO.MinInterval then
		return false
	end
	w.lastFlashAt = now
	w.flashCount += 1
	w.model:SetAttribute(WitnessGauge.FlashAttribute, w.flashCount)
	MarkerSounds.play(PHOTO.Sound, w.root)
	return true
end

-- Le rythme de secours des flashs (tant qu'aucun marqueur Flash n'est venu) : un flash toutes les Photo.Interval s.
local function flashRhythm(w: WitnessNpc, now: number)
	if not w.flashMarkerSeen and now >= w.nextFlashAt then
		w.nextFlashAt = now + PHOTO.Interval
		flash(w, now)
	end
end

-- L'appel fini : il filme, devant la vitrine.
local function startFilming(w: WitnessNpc, now: number)
	setGauge(w, "Stroll", 0, 0, now) -- le « ! » s'efface
	w.pausedAt = 0
	w.filming = true
	w.filmStartedAt = now
	w.flashMarkerSeen = false
	w.lastFlashAt = -math.huge
	w.policeSeen = false
	faceWindow(w)
	w.photoAnim = w.anims:Play("TakePhoto") ~= nil
	if w.photoAnim then
		w.anims:Stop("CallPolice")
	end
	-- Sans TakePhoto, il garde la pose CallPolice et le flash part au rythme de Photo.Interval ; avec elle, ce
	-- rythme ne sert que si aucun marqueur Flash ne vient (deux intervalles de grâce).
	w.nextFlashAt = now + PHOTO.Interval * (if w.photoAnim then 2 else 1)
	log(`{w.label} prend des photos ({if w.photoAnim then "TakePhoto" else "TakePhoto pas livrée : pose de l'appel"})`)
end

-- Le point du circuit le plus proche devient le prochain point de la balade.
local function nearestPoint(w: WitnessNpc)
	local position = w.root.Position
	local nearest = math.huge
	for index, point in w.path do
		local distance = flat(point - position).Magnitude
		if distance < nearest then
			nearest = distance
			w.pathIndex = index
		end
	end
end

local function stopFilming(w: WitnessNpc, now: number, reason: string)
	toStroll(w, now)
	nearestPoint(w)
	stopWalking(w)
	log(`{w.label} arrête les photos ({reason}) et reprend sa balade`)
end

-- La partie du modèle d'un policier qui dit où il est.
local function policePart(police: Model): BasePart?
	local part = police.PrimaryPart or police:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part :: BasePart else nil
end

local function filmStep(w: WitnessNpc, now: number)
	local store = w.store
	if store == nil then
		stopFilming(w, now, "pas de magasin")
		return
	end
	if now - w.filmStartedAt >= PHOTO.MaxTime then
		stopFilming(w, now, "temps écoulé")
		return
	end
	local window = windowPosition(store)
	local anyPolice = false
	local list: { PoliceChase } = policeByStore[store] or {}
	for _, entry in list do
		local police = entry.Police
		if police.Parent ~= nil then
			anyPolice = true
			local part = policePart(police)
			if part and flat(part.Position - window).Magnitude <= PHOTO.PoliceArrive then
				stopFilming(w, now, "le policier est arrivé")
				return
			end
		end
	end
	if anyPolice then
		w.policeSeen = true
	elseif w.policeSeen then
		stopFilming(w, now, "la police est repartie")
		return
	end
	local thief = false
	for player in w.suspects do
		local root = suspectRoot(player) -- en jeu, vivant, hors zone safe
		if root and flat(root.Position - window).Magnitude <= PHOTO.LeaveDistance then
			thief = true
			break
		end
	end
	if not thief then
		stopFilming(w, now, "le voleur est parti")
		return
	end
	flashRhythm(w, now)
end

-- Fuite à la casse (L-118 point 10) ----------------------------------------------------------------

-- La vitrine de son magasin vient de casser : le « ? » disparaît et il court à l'opposé de la vitrine.
local function flee(w: WitnessNpc, now: number)
	local store = w.store
	if store == nil or w.state == "Call" or w.filming then
		return -- au téléphone : il finit son appel ; L-172 : il filme la casse
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

-- a157 (Cantin, 2026-11-14) : un suspect à l'abri en zone safe n'en est plus un. S'il n'en reste aucun, le « ? »
-- se vide (Calm), ou l'appel pas encore passé s'arrête : ni son, ni police, ni Notify, ni OnCall.
local function shelter(w: WitnessNpc, now: number): boolean
	if w.state ~= "Watch" and (w.state ~= "Call" or w.dispatched) then
		return false
	end
	local removed = false
	for player in table.clone(w.suspects) do
		if player.Parent == Players and sheltered(player) then
			w.suspects[player] = nil
			removed = true
		end
	end
	if not removed or next(w.suspects) ~= nil then
		return false
	end
	if w.state == "Call" then
		log(`{w.label} : suspects à l'abri en zone safe, appel coupé`)
		toStroll(w, now)
		return true
	end
	log(`{w.label} : suspects à l'abri en zone safe, le « ? » se vide`)
	calm(w, now)
	return false
end

local function update(w: WitnessNpc, now: number)
	if shelter(w, now) then
		return
	end
	if w.fleeUntil > 0 then
		fleeStep(w, now)
	elseif w.filming then
		filmStep(w, now) -- L-172
	elseif w.state == "Stroll" then
		strollStep(w, now)
	elseif w.state == "Watch" then
		if w.approaching then
			approachStep(w, now) -- L-172
		elseif w.snapping then
			flashRhythm(w, now) -- a221
		end
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
			if PHOTO.Enabled and w.store and w.state == "Call" then
				startFilming(w, now) -- L-172 : il filme au lieu de reprendre sa balade
			else
				toStroll(w, now)
			end
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
	if NpcAvoid then
		NpcAvoid.Untrack(w.root) -- a269
	end
	log(`{w.label} retiré ({reason})`)
end

-- f70c2 : à chaque image (la boucle, elle, va au pas de Witness.StepInterval), le freinage de l'approche et la rotation
-- vers la vitrine, pour qu'ils soient fluides.
local function frameStep(now: number)
	for _, w in witnesses do
		if w.hiddenParent or not (w.approaching or w.turning) then
			continue
		end
		local ok, err = pcall(function()
			if w.approaching then
				approachPace(w)
			else
				turnStep(w, now)
			end
		end)
		if not ok then
			w.turning = false
			warnOnce(`frame:{w.label}`, `{w.label} : {err}`)
		end
	end
end

local function step()
	local now = os.clock()
	frameStep(now)
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
-- de lui, dans l'ordre des numéros (et ce dossier WitnessPaths, a269c).
local function pathOf(model: Model): ({ Vector3 }, Instance?)
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
	return list, paths
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
	local path, pathsFolder = pathOf(model)
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
		approaching = false,
		approachGoal = root.Position,
		filming = false,
		filmStartedAt = 0,
		photoAnim = false,
		flashMarkerSeen = false,
		nextFlashAt = 0,
		lastFlashAt = -math.huge,
		flashCount = 0,
		policeSeen = false,
		rushAnim = nil,
		snapping = false,
		approachSpeed = 0,
		paceRatio = 1,
		turning = false,
		turnAt = 0,
		turnFrom = 0,
		turnBy = 0,
		avoiding = false,
		pathsFolder = pathsFolder,
		lane = nil,
		laneReady = false,
		unstickUntil = 0,
		unstickGoal = root.Position,
		fails = 0,
		narrowWaitUntil = 0,
	}
	if NpcAvoid then
		NpcAvoid.Track(root) -- a269 : un obstacle pour les autres PNJ qui marchent
		NpcAvoid.Collide(model) -- a269 : ne pousse ni un autre témoin ni un vigile (Witness.Avoid.NoCollide)
	end
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
	w.anims:OnMarker("TakePhoto", FLASH_MARKER, function()
		if w.filming or w.snapping then -- a221 : aussi à son poste, « ? » qui monte
			w.flashMarkerSeen = true -- L-172 : les marqueurs donnent le rythme
			flash(w, os.clock())
		end
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

function WitnessService.GetPolice(store: Model): { PoliceChase }
	local list: { PoliceChase } = {}
	if policeByStore[store] == nil then
		return list
	end
	for _, entry in activePolice(store) do
		table.insert(list, { Player = entry.Player, Police = entry.Police })
	end
	if #list == 0 then
		policeByStore[store] = nil
	end
	return list
end

function WitnessService.GetState(store: Model): { State }
	local list: { State } = {}
	local now = os.clock()
	for _, w in witnessesOf(store) do
		local count = 0
		for _ in w.suspects do
			count += 1
		end
		table.insert(list, {
			Witness = w.model,
			State = w.state,
			Fill = valueNow(w, now),
			Rate = w.rate,
			Suspects = count,
			Approaching = w.approaching,
			Filming = w.filming,
			Flashes = w.flashCount,
			Snapping = w.snapping,
		})
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
