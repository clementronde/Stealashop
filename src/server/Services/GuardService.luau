--!strict
-- GuardService (DEV-018) : vigile de jour des magasins PNJ, de l'apparition à l'abandon
-- (Partie 1, sections 4, 5.5 et 9.7 ; animations : 2.4 et liaison 3.2).
--
-- Déroulé d'un vigile :
--   1. Apparition. Quand CarryService commence le portage d'un colis PNJ (OnCarryStarted,
--      payload.Kind = "NPCBox"), un vigile apparaît au GuardSpawn du magasin du colis
--      (payload.StoreId). Un vigile par voleur ; au plus Balance.Guard.MaxPerStore en poursuite
--      par magasin et Balance.Guard.MaxActivePerServer en jeu sur le serveur (9.7) : au
--      plafond, un vigile qui rentre s'efface (fondu, point 5) pour laisser sa place ; sans vigile
--      qui rentre, pas de vigile. Un vigile en fondu ne compte plus dans ces plafonds. Le serveur
--      possède sa physique ; nage, escalade et autres états inutiles sont coupés (9.7).
--   2. Poursuite, après REACTION_DELAY s : WalkSpeed = Zones[zone].GuardSpeed (section 4).
--      Course directe s'il voit le joueur, sinon PathfindingService recalculé toutes les
--      Balance.Guard.PathRecomputeInterval s.
--   3. Capture : distance ≤ Balance.Guard.CatchDistance entre les deux HumanoidRootPart, sans
--      mur entre eux, mesurée ici, côté serveur. Alors, tout de suite : CarryService.Fail(player,
--      "Caught") (le colis revole vers son rayon), joueur immobilisé (StatsService, modificateur
--      STUN_KEY = 0), Notify « Caught! Recommended speed: X » (anglais, L-036), et le vigile joue
--      Catch. Puis le coup, en un seul geste avec Catch (L-071, point 5) : au marqueur Impact de
--      Catch, le joueur est projeté (poussée ci-dessous ; son client joue Knockback, puis Stunned,
--      ChaseController) et reste étourdi Balance.Guard.CatchStunDuration s à partir de là. Délai de
--      secours : sans marqueur, la poussée part à la fin de Catch (Catch pas encore chargée :
--      KNOCKBACK_MAX_WAIT s) ; Catch pas livrée : tout de suite, étourdi CatchStunDuration s depuis
--      la capture.
--      Le marqueur est écouté ici, côté serveur (AnimPlayer:OnMarker sur la piste Catch du vigile),
--      parce que c'est le serveur qui joue les animations des vigiles (il possède le vigile et son
--      Animator), qu'il pose lui-même la poussée et l'étourdissement (StatsService, AntiCheatService
--      .Allow juste avant la poussée) et que tous les joueurs doivent voir le même coup. Le client
--      du joueur reçoit la Catch du vigile et la poussée avec le même délai réseau : elles restent
--      ensemble à l'écran.
--   4. Abandon : le joueur entre en zone safe (tag SafeZone), GiveUpChaseDuration s de
--      poursuite, GiveUpLead studs d'avance, ou le portage finit autrement (OnCarryEnded :
--      colis posé, mort, départ…). Le vigile s'arrête essoufflé (Tired, 5.5), puis rentre en
--      marchant (Walk, RETURN_WALK_SPEED) ; après une capture, il rentre dès la fin de Catch. Il
--      ne vise jamais un point de la zone safe : il ne la franchit pas.
--   5. Retour (liaison L-077, point 1). Comme la poursuite : tout droit s'il voit son but (les deux
--      rayons de la ligne de vue, plus deux à ses flancs : seesGoal), sinon par PathfindingService
--      (son agent, recalcul toutes les Balance.Guard.PathRecomputeInterval s). Jamais droit dans un
--      mur : sans ligne de vue ni chemin (pas encore calculé, ou raté), il attend sur place (Idle)
--      le calcul suivant. Son but (Balance.Guard.ReturnEnd, V0 « Reserve », question à Clément) :
--        - "Reserve" (b) : son GuardSpawn, à travers le magasin. Le chemin n'y passe pas (rideau
--          baissé, vitrine reconstruite) ou il reste bloqué en route : la porte, comme a) ;
--        - "Door" (a) : un point au sol devant la porte du magasin (`Door`, sinon `Window`), côté
--          rue, à DOOR_STOP_DISTANCE studs plus son rayon d'agent ;
--        - déjà dans le volume Bounds du magasin (capture dedans, abandon avant le départ) : son
--          GuardSpawn, dans les deux cas (il ne ressort pas pour rentrer).
--      Arrivé, il s'efface en fondu (Balance.Guard.ReturnFadeTime s, état Fade), jamais d'un coup :
--      à la porte en faisant un dernier pas vers elle, au GuardSpawn sur place. Disparition propre,
--      toujours en fondu et là où il est, sans chemin ni ligne de vue pendant
--      RETURN_NO_PATH_TIMEOUT s, bloqué devant la porte, ou au bout de RETURN_MAX_DURATION s de
--      retour. Seuls la mort, la sortie du jeu et une erreur le retirent d'un coup.
--      Rideau (StoreHeistService, L-064) : un vigile dans Bounds retient sa baisse. Celui qui rentre
--      n'y reste qu'au plus le temps de son retour et de son fondu, puis le libère ; il n'est jamais
--      enfermé (le rideau l'attend, et dedans il va au GuardSpawn).
--      Magasin rouvert (nouvelle casse) ou vitrine reconstruite pendant son retour : il continue,
--      change de but si le passage se ferme, et s'efface à l'arrivée. Le nouveau vol a son propre
--      vigile tout de suite (un par voleur) ; celui qui rentre ne poursuit plus personne et ne
--      compte pas dans MaxPerStore : pas de doublon de poursuite.
--   6. Le joueur poursuivi reçoit ChaseState(true, vigile) à l'apparition et ChaseState(false)
--      à la fin (capture ou abandon). Pour lui, le vigile reste chargé (streaming) tant que
--      dure la poursuite.
--
-- Le vigile suit le colis (6.2, DEV-048) : quand un coup de batte fait tomber le colis de la cible
-- (OnCarryEnded, résultat « Dropped »), le vigile de jour qui la poursuivait (Wait ou Chase) ne
-- l'abandonne pas : la poursuite de cette cible finit (ChaseState(false) pour elle) et il court vers
-- l'endroit du coup (état Follow, là où était la cible quand le colis est tombé), s'arrête à
-- FOLLOW_STOP_DISTANCE studs, sans jamais entrer en zone safe. Il ne capture personne en Follow.
--   - Quelqu'un ramasse le colis (OnCarryStarted, même payload) : le vigile change de cible et
--     poursuit le nouveau porteur, comme un vigile qui vient d'apparaître : REACTION_DELAY s
--     d'attente sans capture, puis poursuite neuve (vitesse de la zone pour ce joueur, 20 s
--     comptées de là) avec les mêmes règles d'abandon (5.5 : zone safe, GiveUpChaseDuration,
--     GiveUpLead) et la même capture. Ramassé par un joueur déjà poursuivi par un autre vigile :
--     cet autre vigile abandonne.
--   - Personne ne le ramasse (OnDropExpired, 6.2 : 15 s, le colis revole vers son rayon), ou rien
--     au bout de Bat.DroppedLifetime + FOLLOW_MARGIN s : le vigile abandonne (Tired, puis retour).
--   - Un colis ramassé au sol alors qu'aucun vigile ne le suivait (vigile déjà reparti, ou aucun
--     vigile à l'origine) ne fait apparaître aucun vigile : il n'apparaît qu'à la prise sur le rayon.
--   - Les vigiles de nuit ne suivent pas les colis : ils poursuivent toute personne dans le couloir.
--
-- Vigiles de nuit (DEV-047, section 5.12), lancés par NightCycleService à la tombée de la nuit
-- (StartNightPatrol) et retirés à l'aube (StopNightPatrol). Même poursuite, même capture, mêmes
-- animations que le vigile de jour ; ce qui change :
--   - Night.GuardsPerZone (2) par zone, posés sur les points taggés `NightPatrol` de leur zone
--     (attribut Zone), triés par nom : le 1er vigile part du 1er point, le 2e du point du milieu
--     de la liste (avec 2 points : chacun le sien). Ronde à Night.PatrolSpeed, en aller-retour
--     d'un point au suivant, pause de Night.PatrolPause s à chaque point (Walk, puis Idle). Une
--     zone sans point n'a pas de vigile de nuit (avertissement) ; un seul point : ils y restent.
--   - Repérage, pendant la ronde et le retour à la ronde : un joueur vivant, dans le couloir
--     (règle de NightCycleService), pas ignoré (bouclier débutant), pas déjà poursuivi par un
--     autre vigile de nuit, à Night.DetectionRange (40) studs au plus, dans le cône de la lampe
--     torche (Night.DetectionConeAngle autour de l'avant du vigile, à l'horizontale) et sans mur
--     entre eux (même ligne de vue que la poursuite). Le plus proche. Puis délai de réaction et
--     poursuite à Zones[zone].AdvisedSpeed + Night.ChaseSpeedBonus, avec ou sans colis.
--   - Abandon : comme le jour (zone safe, Night.GiveUpChaseDuration s depuis le repérage,
--     Night.GiveUpLead studs), et aussi quand la cible quitte le couloir (passée à travers le mur
--     de nuit), devient ignorée ou n'a plus de personnage. Puis essoufflé, il retourne au point de
--     ronde le plus proche et reprend sa ronde. Il ne disparaît qu'à l'aube.
--   - Attrapé la nuit (5.12) : joueur immobilisé tout de suite ; CarryService.Fail(player,
--     "Caught") s'il porte (le colis revole vers son rayon, s'il n'a pas été rempli depuis) ; au
--     marqueur Impact de Catch, le même coup que le jour, puis Night.SendHomeDelay s plus tard,
--     renvoi chez lui (SendHome de NightCycleService), étourdi Night.CaughtStunDuration (2) s à
--     partir de là, et Notify. Aucune autre perte.
--   - Modèle : Assets/Guards/NightGuard_Z<zone>, sinon NightGuard (look de Clément, MOD-032),
--     sinon le modèle de jour (Guard_Z<zone>, Guard), sinon le même rig de remplacement que le
--     jour, auquel le code ajoute une SpotLight (lampe torche de remplacement, portée et angle du
--     cône de détection). Rien n'est ajouté aux modèles de Clément. Clone nommé NightGuard_Z<n>_<k>.
--   - Ils ne comptent pas dans le plafond de 9.7 (Balance.Guard.MaxActivePerServer, vigiles de
--     jour) : 2 × 6 zones = 12 au plus, seulement la nuit.
--   - ChaseState : le joueur reçoit le vigile de jour qui le poursuit s'il y en a un, sinon le
--     vigile de nuit ; ChaseState(false) quand plus aucun ne le poursuit.
--
-- Animations (contrat 2.4, Shared/Contract/Animations), jouées par AnimPlayer depuis le dossier
-- Animations du modèle : Idle (toujours, en fond), Run (poursuite), Catch (capture), Tired
-- (abandon), Walk (retour, ronde). Une animation pas encore livrée ne joue rien : un seul
-- avertissement par nom, en Studio, pour tous les vigiles de jour et de nuit. Sons des marqueurs :
-- MarkerSounds.Guard. Run et Walk suivent le pas du vigile (L-048) : Clément les a faites pour
-- ~20 et ~10 studs/s à l'échelle 1, donc vitesse de lecture = WalkSpeed / (20 ou 10 × échelle du
-- modèle), bornée de 0,6 à 1,6, et remise à jour à chaque changement de WalkSpeed (setWalkSpeed).
--
-- Modèle du vigile (liaison L-048) : un Model avec Humanoid R15 et HumanoidRootPart, dans un
-- dossier Guards de ReplicatedStorage/Assets (ou de ServerStorage/Assets), nommé Guard_Z<zone>
-- (un look par zone, 5.5 ; ceux de Clément vont de 1 à 1,4 fois un R15, par Model:ScaleTo),
-- sinon Guard (look commun). Sans lui, un rig R15 de remplacement créé par le code. Tout se règle
-- sur le clone en jeu, jamais sur le modèle de Clément : scripts retirés, pièces désancrées et
-- dans le groupe de collision GUARD_GROUP, accessoires sans collision ni masse, WalkSpeed imposé
-- par le code ; la HipHeight de Clément est gardée telle quelle. Chaque vigile calcule ses chemins
-- avec un agent à sa taille (agentFor, L-040). Capture et abandon se mesurent toujours entre les
-- deux HumanoidRootPart.
--
-- Posé par le code :
--   - vigiles en jeu dans Workspace/ActiveGuards, avec l'attribut TargetUserId (UserId du
--     joueur poursuivi, 0 hors poursuite) ;
--   - sur le joueur rattrapé, pendant la poussée : un Attachment KNOCKBACK_NAME (avec sa
--     LinearVelocity) dans son HumanoidRootPart. ChaseController le reconnaît à ce nom pour
--     jouer Knockback et Stunned.
--
-- API (serveur) :
--   GuardService.IsChased(player) -> boolean
--   GuardService.GetGuard(player) -> Model?    le vigile qui poursuit ce joueur
--   GuardService.OnCatch(listener) -> déconnexion
--       listener(player, zone, night, carrying) à chaque capture, de jour ou de nuit, juste avant
--       que le portage soit perdu : carrying = il portait quelque chose. TelemetryService s'en sert
--       pour les captures de nuit sans colis (celles avec colis passent par OnCarryEnded).
--   GuardService.GetSpeedOverride(player, zone) -> number?
--       Point d'accroche du tutoriel (5.11, vigile lent : Config.Tutorial.GuardSpeed). Renvoie
--       nil ici : la vitesse de la zone s'applique. TutorialService le remplace
--       (GuardService.GetSpeedOverride = function(player, zone) ... end). Une valeur qui n'est
--       pas un nombre fini > 0, ou une erreur, compte pour nil.
--   GuardService.StartNightPatrol(hooks) -> number
--       Lance les vigiles de nuit (voir plus haut), sans attendre ; renvoie le nombre prévu. hooks
--       (NightCycleService) : InCorridor(position) -> boolean, Ignores(player) -> boolean,
--       SendHome(player) -> boolean (peut attendre). Déjà lancés : les anciens partent d'abord.
--   GuardService.StopNightPatrol() -> number    retire les vigiles de nuit, renvoie leur nombre
--   GuardService.IsNightChased(player) -> boolean   poursuivi par un vigile de nuit

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Bat = require(Shared.Config.Bat)
local Night = require(Shared.Config.Night)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local Animations = require(Shared.Contract.Animations)
local Find = require(Shared.Contract.Find)
local AnimPlayer = require(Shared.Anim.AnimPlayer)
local MarkerSounds = require(Shared.Anim.MarkerSounds)
local Net = require(Shared.Net.Net)

local AntiCheatService = require(script.Parent.AntiCheatService)
local StatsService = require(script.Parent.StatsService)

-- Ce que ce service utilise de CarryService (DEV-017), qui ne requiert jamais GuardService.
type CarryApi = {
	IsCarrying: (player: Player) -> boolean,
	Fail: (player: Player, reason: string) -> (),
	OnCarryStarted: (listener: (player: Player, payload: any) -> ()) -> any,
	OnCarryEnded: (listener: (player: Player, payload: any, result: string, reason: string) -> ()) -> any,
	OnDropExpired: (listener: (dropId: string, payload: any, position: Vector3) -> ()) -> any,
}
local CarryService: CarryApi = require(script.Parent.CarryService) :: any

type AnimPlayerT = AnimPlayer.AnimPlayer

-- Wait : vient d'apparaître (ou, la nuit, vient de repérer un joueur ; ou vient de changer de cible
-- pour le nouveau porteur d'un colis tombé) ; Chase : poursuit ; Catch : vient de rattraper ;
-- Tired : essoufflé après un abandon ; Return : rentre en marchant (la nuit : vers sa ronde) ;
-- Patrol : ronde de nuit ; Follow : va vers le colis tombé au sol de sa cible (6.2) ; Fade :
-- s'efface en fondu avant de disparaître (vigile de jour, L-077).
type GuardState = "Wait" | "Chase" | "Catch" | "Tired" | "Return" | "Patrol" | "Follow" | "Fade"

-- But du retour d'un vigile de jour (L-077) : son GuardSpawn, ou devant la porte du magasin.
type ReturnTarget = "Reserve" | "Door"

-- Day : vigile de jour d'un magasin (5.5) ; Night : vigile de nuit (5.12).
type GuardKind = "Day" | "Night"

-- Règles de la nuit, données par NightCycleService à StartNightPatrol.
export type NightHooks = {
	InCorridor: (position: Vector3) -> boolean,
	Ignores: (player: Player) -> boolean,
	SendHome: (player: Player) -> boolean,
}

type Guard = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	rootHeight: number, -- hauteur du centre du HumanoidRootPart au-dessus des pieds
	scale: number, -- Model:GetScale() du modèle (1 pour les rigs du code) : rythme de Run et de Walk
	anims: AnimPlayerT,
	kind: GuardKind,
	label: string, -- pour la sortie : « vigile de STORE_Z1_Superette », « vigile de nuit NightGuard_Z1_1 »
	store: Model?, -- magasin du vigile de jour ; nil la nuit
	home: Vector3, -- GuardSpawn, but du retour ; la nuit : point de ronde visé
	zone: number,
	speed: number, -- WalkSpeed de poursuite
	target: Player?, -- joueur poursuivi, nil hors poursuite
	state: GuardState,
	spawnedAt: number,
	chaseStartedAt: number, -- début de la poursuite (le jour : l'apparition)
	patrol: { Vector3 }, -- points de ronde de sa zone, dans l'ordre (vide le jour)
	patrolIndex: number, -- point visé
	patrolStep: number, -- +1 ou −1 : sens de l'aller-retour
	pauseUntil: number, -- fin de la pause au point de ronde ; 0 = en marche
	onKnock: ((player: Player) -> ())?, -- après le coup (la nuit : renvoi chez lui)
	nextScanAt: number, -- prochain repérage (vigile de nuit)
	stateEndsAt: number, -- fin de Wait, Catch ou Tired
	returnedAt: number,
	nextSteerAt: number,
	nextPathAt: number,
	path: Path,
	pathToken: number, -- change à chaque changement d'état : périme les calculs en cours
	computing: boolean,
	waypoints: { PathWaypoint }?,
	waypointIndex: number,
	progressPos: Vector3,
	progressAt: number,
	knockTarget: Player?, -- joueur à projeter au marqueur Impact de Catch
	followPayload: any?, -- Follow : le payload du colis tombé au sol que le vigile suit
	followPosition: Vector3, -- Follow : où il est tombé (là où était la cible au coup)
	agentRadius: number, -- rayon de son agent du PathfindingService (agentFor)
	pathFailures: number, -- calculs de chemin ratés de suite, depuis le dernier changement d'état ou de but
	returnTo: ReturnTarget, -- retour d'un vigile de jour : son but
	returnGoal: Vector3, -- le point visé, au sol (GuardSpawn ou devant la porte)
	doorSpot: Vector3?, -- devant la porte du magasin, côté rue, au sol ; nil sans Door ni Window
	doorStep: Vector3?, -- le dernier pas vers la porte, pendant le fondu
	noPathSince: number, -- retour : début de l'attente sans chemin ni ligne de vue (0 = il avance)
	fadeStartedAt: number,
	fadeReason: string, -- pour la sortie, à la disparition : « rentré », « retour trop long »…
	fadeParts: { [BasePart]: number }, -- Transparency d'origine, pendant le fondu
	fadeDecals: { [Decal]: number },
	connections: { RBXScriptConnection },
	alive: boolean,
}

-- Noms du contrat (2.1, 10.4) lus ici.
local STORE_TAG = "NPCStore"
local SAFE_ZONE_TAG = "SafeZone"
local GUARD_SPAWN = "GuardSpawn"
local BOUNDS = "Bounds"
local WINDOW = "Window"
local DOOR = "Door"
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons de Clément : pas encore dans la map
local WINDOW_ID_ATTRIBUTE = "WindowId" -- posé par WindowService sur la vitrine

-- V0 proposé, absent du doc : où le code cherche le modèle de vigile de Clément.
local GUARD_FOLDER = "Guards" -- dans ReplicatedStorage/Assets, puis ServerStorage/Assets
local GUARD_ZONE_NAME = "Guard_Z%d" -- un look par zone (5.5)
local GUARD_COMMON_NAME = "Guard" -- look des zones sans modèle propre

-- Noms posés par le code. KNOCKBACK_NAME, ACTIVE_FOLDER et TARGET_ATTRIBUTE sont aussi écrits
-- dans ChaseController : les changer dans les deux fichiers.
local ACTIVE_FOLDER = "ActiveGuards"
local TARGET_ATTRIBUTE = "TargetUserId"
local KNOCKBACK_NAME = "GuardKnockback"
-- Arrestation de nuit (L-076) : objet posé dans le HumanoidRootPart du joueur pour que son client joue
-- Arrested (même nom dans ChaseController). V0 proposés : durée de vie du signal, durée de la scène si
-- la longueur de l'animation n'est pas encore connue (Arrest de Clément : 2,4 s).
local ARREST_NAME = "GuardArrest"
local ARREST_SIGNAL_LIFE = 3
local ARREST_FALLBACK_LENGTH = 2.4
local STUN_KEY = "GuardStun" -- modificateur de vitesse de StatsService
local FALLBACK_NAME = "Guard_Fallback"

-- Vigiles de nuit (5.12). Tag et attribut du contrat (2.1, 10.4) ; noms des modèles : V0 proposé,
-- absent du doc, comme ceux du jour (à écrire dans la liaison pour Clément).
local NIGHT_PATROL_TAG = "NightPatrol"
local ZONE_ATTRIBUTE = "Zone"
local NIGHT_ZONE_NAME = "NightGuard_Z%d" -- un look par zone, s'il le faut
local NIGHT_COMMON_NAME = "NightGuard" -- look commun des vigiles de nuit (MOD-032)
local NIGHT_CLONE_NAME = "NightGuard_Z%d_%d" -- nom du clone en jeu : zone, numéro
-- V0 proposé, absent du doc : lampe torche du rig de remplacement seulement (le look de Clément
-- apporte la sienne) : une SpotLight dans la tête, portée et angle du cône de détection.
local FLASHLIGHT_NAME = "NightFlashlight"
local FLASHLIGHT_COLOR = Color3.fromRGB(255, 244, 214)
local FLASHLIGHT_BRIGHTNESS = 2
-- V0 proposé, absent du doc : sans animation Catch livrée, le renvoi part tout de suite après le coup.
local NIGHT_FREEZE_MAX = 8 -- immobilisé au plus ce temps entre la capture et le renvoi (s)

-- Messages lus par le joueur (Notify), en anglais (L-036).
local MESSAGES = {
	NightCaught = "Caught by a night guard! Back to your shop.",
}

-- V0 proposé, absent du doc : le coup du vigile qui projette le joueur rattrapé (5.5, comme
-- dans le jeu de référence). Réglable ici.
local KNOCKBACK_SPEED = 40 -- vitesse horizontale donnée au joueur, à l'opposé du vigile (studs/s)
local KNOCKBACK_UP = 25 -- vitesse verticale (studs/s)
local KNOCKBACK_DURATION = 0.15 -- durée de la poussée (s)
-- Catch lancée mais pas encore chargée (durée inconnue) : sans marqueur Impact après ce délai, la
-- poussée part quand même (s). Une Catch chargée attend son marqueur jusqu'à sa fin (impactMaxWait).
local KNOCKBACK_MAX_WAIT = 0.6

-- V0 proposé, absent du doc : comportement du vigile.
local REACTION_DELAY = 0.5 -- il apparaît, puis s'élance après ce délai, sans capture avant (s)
local STEER_INTERVAL = 0.1 -- cadence du pilotage : ligne de vue, MoveTo (s)
local WAYPOINT_REACHED = 2 -- distance horizontale à laquelle un point du chemin est atteint (studs)
local KNEE_HEIGHT = 1.5 -- second rayon de la ligne de vue, au-dessus des pieds : voit les obstacles bas (studs)
local SPAWN_SPACING = 3 -- écart entre vigiles apparus au même GuardSpawn, vers la vitrine (studs)
-- Groupe de collision des vigiles, qui ne se heurte pas lui-même : deux vigiles qui se croisent
-- (les 2 vigiles de nuit d'une zone font la même ronde en ligne droite) passent l'un à travers
-- l'autre au lieu de se bloquer et de faire demi-tour au milieu de la ronde (vu en Play le
-- 2026-11-07). Ils restent arrêtés par la map, les joueurs et le mur de nuit.
local GUARD_GROUP = "Guards"
local RETURN_WALK_SPEED = 10 -- retour en marchant (WalkSpeed)
local RETURN_PATH_INTERVAL = 1 -- vigile de nuit : recalcul du chemin du retour à la ronde et de la ronde (s)
local RETURN_MAX_DURATION = 20 -- au-delà, il s'efface là où il est (la nuit : reprend sa ronde) (s)
local RETURN_STUCK_TIME = 2 -- sans avancer d'un stud pendant ce temps, il est bloqué (s)
local ARRIVE_DISTANCE = 3 -- à cette distance du GuardSpawn, il est rentré et s'efface (studs)
-- V0 proposé, absent du doc : retour du vigile de jour (L-077, point 1).
local RETURN_NO_PATH_TIMEOUT = 3 -- sans chemin ni ligne de vue pendant ce temps, il s'efface sur place (s)
local DOOR_STOP_DISTANCE = 2 -- arrêt devant la porte : à cette distance, plus son rayon d'agent (studs)
local DOOR_ARRIVE_DISTANCE = 1.5 -- à cette distance du point devant la porte, il y est (studs)
local GROUND_RAY_DOWN = 20 -- recherche du sol sous le point devant la porte (studs)
local RETURN_SIDE_INSET = 0.5 -- rayons des flancs de sa ligne de vue : rayon d'agent moins ceci (studs)
local TIRED_PAUSE = 1.5 -- pause essoufflée si Tired n'est pas livrée (s)
local TIRED_MAX = 4 -- pause essoufflée maximale, même si Tired est plus longue (s)
local CATCH_PAUSE = 1 -- pause après la capture si Catch n'est pas livrée (s)
local CATCH_MAX = 3 -- pause maximale après la capture (s)
-- V0 proposé, absent du doc : le vigile qui suit un colis tombé (6.2) s'arrête à 3 studs de
-- l'endroit du coup, et abandonne de lui-même 2 s après la durée au sol (si OnDropExpired manque).
local FOLLOW_STOP_DISTANCE = 3
local FOLLOW_MARGIN = 2

-- V0 proposé, absent du doc : couleurs du rig de remplacement (gilet orange).
local FALLBACK_VEST = Color3.fromRGB(255, 160, 20)
local FALLBACK_SKIN = Color3.fromRGB(234, 184, 146)
local FALLBACK_PANTS = Color3.fromRGB(45, 50, 65)

-- Agent du PathfindingService, calculé pour chaque vigile d'après sa boîte (agentFor, L-040) :
-- les valeurs par défaut de Roblox pour un rig R15 standard (rayon 2, hauteur 5) sont un plancher.
-- Saut permis, escalade coupée. Le dictionnaire que PathfindingService:CreatePath attend.
type AgentParams = { [string]: any }
local AGENT_RADIUS_MIN = 2
local AGENT_HEIGHT_MIN = 5
local WAYPOINT_SPACING = 4

-- Rythme des boucles de marche et de course de Clément (L-048) : la vitesse au sol (studs/s) pour
-- laquelle chacune est faite, à l'échelle 1 (Run : 0,4 s pour ~20 ; Walk : 0,8 s pour ~10), et
-- les bornes de la vitesse de lecture, pour que les pieds ne glissent pas de la zone 1 à la zone 6.
local GAIT_REFERENCE: { [string]: number } = { Run = 20, Walk = 10 }
local GAIT_SPEED_MIN = 0.6
local GAIT_SPEED_MAX = 1.6

-- Nom des vigiles dans les avertissements d'AnimPlayer, le même de jour et de nuit (mêmes modèles,
-- mêmes noms d'animations) : une animation pas encore livrée n'est signalée qu'une fois.
local ANIM_LABEL = "Vigile"

-- États du Humanoid jamais utiles à un vigile (9.7 : nage, escalade ; le reste en V0).
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

local GuardService = {}

local guards: { Guard } = {} -- vigiles de jour
-- Heure (os.clock) où le dernier vigile de jour d'un magasin est parti (rentré, effacé…) : la vitrine
-- ne se reconstruit, et le magasin ne se rouvre, que Balance.Guard.ReopenAfterReturn s plus tard.
local lastGoneAt: { [Model]: number } = {}
local chasedBy: { [Player]: Guard } = {} -- par un vigile de jour
local nightGuards: { Guard } = {}
local nightChasedBy: { [Player]: Guard } = {}
local nightHooks: NightHooks? = nil -- règles de la nuit en cours ; nil le jour
local nightToken = 0 -- change à chaque StartNightPatrol et StopNightPatrol : périme les lancements en cours
local chaseSent: { [Player]: Model } = {} -- vigile annoncé au joueur par ChaseState(true, …)
local caughtAtNight: { [Player]: boolean } = {} -- attrapé la nuit, pas encore renvoyé : plus visé
local stunTokens: { [Player]: number } = {}
export type CatchListener = (player: Player, zone: number, night: boolean, carrying: boolean) -> ()
local catchListeners: { CatchListener } = {}
-- Colis tombés au sol après un coup de batte (6.2), par payload (la table que CarryService garde) :
-- le vigile qui le suit, et tous les colis au sol (suivis ou non) jusqu'à leur prise ou leur fin.
local following: { [any]: Guard } = {}
local droppedPayloads: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local activeFolder: Folder? = nil
local fallbackTemplate: Model? = nil
local fallbackBuilding = false
local warned: { [string]: boolean } = {}
-- Boîte englobante des zones safe sans Bounds, calculée une fois.
local boxCache: { [Instance]: { cframe: CFrame, size: Vector3 } } = setmetatable({}, { __mode = "k" }) :: any

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true -- volumes Bounds, vitre cassée, colis porté : ne cachent rien
rayParams.IgnoreWater = true

-- Le marqueur de Catch dans le contrat 2.4 (Impact).
local CATCH_MARKER = "Impact"
for _, spec in Animations.Guard do
	local marker = spec.Marker
	if spec.Name == "Catch" and marker then
		CATCH_MARKER = marker
	end
end

-- Outils ----------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[GuardService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[GuardService] {message}`)
end

local function isPositiveNumber(value: any): boolean
	return type(value) == "number" and value == value and value > 0 and value < math.huge
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Dans la map : Workspace, hors du dépôt des livraisons de Clément.
local function inMap(inst: Instance): boolean
	if not inst:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not inst:IsDescendantOf(inbox)
end

-- HumanoidRootPart et Humanoid vivant d'un joueur, sinon nil.
local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return root :: BasePart, humanoid
end

-- Zone safe ---------------------------------------------------------------------------------

local function insideBox(cframe: CFrame, size: Vector3, position: Vector3): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

-- Le volume d'un objet taggé SafeZone : la pièce elle-même, sinon son enfant direct Bounds
-- (pas ceux des parcelles qu'il contient peut-être), sinon la boîte englobante du modèle.
local function insideSafeZone(inst: Instance, position: Vector3): boolean
	local part: Instance? = if inst:IsA("BasePart") then inst else inst:FindFirstChild(BOUNDS)
	if part and part:IsA("BasePart") then
		local box = part :: BasePart
		return insideBox(box.CFrame, box.Size, position)
	end
	if inst:IsA("Model") then
		local cached = boxCache[inst]
		if cached == nil then
			local cframe, size = (inst :: Model):GetBoundingBox()
			cached = { cframe = cframe, size = size }
			boxCache[inst] = cached
		end
		return insideBox(cached.cframe, cached.size, position)
	end
	return false
end

local function isInSafeZone(position: Vector3): boolean
	for _, inst in CollectionService:GetTagged(SAFE_ZONE_TAG) do
		if inMap(inst) and insideSafeZone(inst, position) then
			return true
		end
	end
	return false
end

-- Magasin et modèle -------------------------------------------------------------------------

-- Le magasin d'un colis : payload.StoreId = nom du modèle, ou WindowId de sa vitrine
-- (WindowService : nom du modèle, suffixe _2… en cas de doublon).
local function findStore(storeId: string): Model?
	for _, inst in CollectionService:GetTagged(STORE_TAG) do
		if inst:IsA("Model") and inMap(inst) then
			if inst.Name == storeId then
				return inst :: Model
			end
			local window = Find.path(inst, WINDOW)
			if window and window:GetAttribute(WINDOW_ID_ATTRIBUTE) == storeId then
				return inst :: Model
			end
		end
	end
	return nil
end

-- Le point d'apparition, à plat, tourné comme le GuardSpawn (vers la vitrine).
local function spawnFrame(store: Model): CFrame
	local spawn = Find.path(store, GUARD_SPAWN)
	local frame: CFrame
	if spawn and spawn:IsA("Attachment") then
		frame = (spawn :: Attachment).WorldCFrame
	else
		warnOnce(`spawn:{store.Name}`, `{store.Name} : GuardSpawn absent (10.4), vigile posé au pivot du magasin`)
		frame = store:GetPivot()
	end
	local look = flat(frame.LookVector)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(frame.Position, frame.Position + look.Unit)
end

-- Le modèle de Clément pour cette zone, s'il est livré.
local function findTemplate(zone: number): Model?
	for _, name in { string.format(GUARD_ZONE_NAME, zone), GUARD_COMMON_NAME } do
		for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
			local assets = service:FindFirstChild("Assets")
			local folder = if assets then assets:FindFirstChild(GUARD_FOLDER) else nil
			local model = if folder then folder:FindFirstChild(name) else nil
			if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
				return model :: Model
			end
		end
	end
	return nil
end

-- Dernier recours si Roblox ne crée pas de rig : des blocs soudés et un Humanoid R15 sans jambes,
-- porté par sa HipHeight.
local function buildBlockRig(): Model
	local model = Instance.new("Model")
	local function block(name: string, size: Vector3, y: number, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.new(0, y, 0)
		part.Color = color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end
	local root = block("HumanoidRootPart", Vector3.new(2, 2, 1), 3, FALLBACK_VEST)
	root.Transparency = 1
	local torso = block("UpperTorso", Vector3.new(2, 2.5, 1), 3.25, FALLBACK_VEST)
	local head = block("Head", Vector3.new(1.2, 1.2, 1.2), 5.1, FALLBACK_SKIN)
	for _, part in { torso, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = root
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

-- Rig R15 de remplacement, tant que Clément n'a pas livré de vigile. Construit une seule fois
-- (attend : Players:CreateHumanoidModelFromDescriptionAsync).
local function buildFallback(): Model
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = FALLBACK_SKIN
	description.LeftArmColor = FALLBACK_SKIN
	description.RightArmColor = FALLBACK_SKIN
	description.TorsoColor = FALLBACK_VEST
	description.LeftLegColor = FALLBACK_PANTS
	description.RightLegColor = FALLBACK_PANTS
	local ok, result = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()
	local model: Model
	if ok then
		model = result :: Model
	else
		warnOnce("fallback", `rig R15 de remplacement impossible ({result}) : vigile en blocs`)
		model = buildBlockRig()
	end
	model.Name = FALLBACK_NAME
	-- Le rig de Roblox arrive avec son script Animate : aucun script dans un vigile (10.4).
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	return model
end

local function getFallback(): Model?
	if fallbackTemplate == nil and not fallbackBuilding then
		fallbackBuilding = true
		local ok, result = pcall(buildFallback)
		fallbackBuilding = false
		if ok then
			fallbackTemplate = result
		else
			warn(`[GuardService] rig de remplacement : {result}`)
		end
	end
	local deadline = os.clock() + 10
	while fallbackTemplate == nil and fallbackBuilding and os.clock() < deadline do
		task.wait(0.1) -- un autre appel le construit déjà
	end
	return fallbackTemplate
end

-- Un modèle de Clément utilisable : un Humanoid et un HumanoidRootPart (10.4).
local function isUsable(template: Model): boolean
	local root = template:FindFirstChild("HumanoidRootPart")
	return template:FindFirstChildOfClass("Humanoid") ~= nil and root ~= nil and root:IsA("BasePart")
end

-- Le groupe de collision des vigiles, enregistré au premier besoin ; nil s'il est indisponible.
local function guardGroup(): string?
	local ok = pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered(GUARD_GROUP) then
			PhysicsService:RegisterCollisionGroup(GUARD_GROUP)
		end
		PhysicsService:CollisionGroupSetCollidable(GUARD_GROUP, GUARD_GROUP, false)
	end)
	if not ok then
		warnOnce("group", `groupe de collision {GUARD_GROUP} indisponible : les vigiles peuvent se bloquer entre eux`)
		return nil
	end
	return GUARD_GROUP
end

-- Pièce d'un accessoire porté (Accessory, Hat), à n'importe quelle profondeur sous le modèle.
local function inAccessory(part: Instance, model: Model): boolean
	local parent = part.Parent
	while parent ~= nil and parent ~= model do
		if parent:IsA("Accoutrement") then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- Prépare un clone, jamais le modèle de Clément : scripts retirés (aucun script dans un modèle
-- animé, 10.4) ; pièces désancrées (le Humanoid doit pouvoir le déplacer) et dans le groupe des
-- vigiles, accessoires compris ; accessoires comme sur un personnage, sans collision (ils ne
-- bloquent pas le vigile dans une allée) et sans masse (ils ne le déséquilibrent pas). La
-- HipHeight n'est pas touchée. Renvoie le Humanoid et le HumanoidRootPart du clone, ou nil s'il
-- lui en manque un.
local function prepare(model: Model, label: string): (Humanoid?, BasePart?)
	local group = guardGroup()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			warnOnce(`script:{label}`, `{label} : script « {descendant.Name} » retiré du vigile en jeu (aucun script dans un modèle animé, 10.4)`)
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = false
			if group then
				part.CollisionGroup = group
			end
			if inAccessory(part, model) then
				part.CanCollide = false
				part.Massless = true
			end
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warnOnce(`rig:{label}`, `{label} : rig {humanoid.RigType.Name}, attendu R15 (2.4)`)
	end
	return humanoid, root :: BasePart
end

-- Échelle du modèle (Model:ScaleTo de Clément ; 1 pour les rigs du code), 1 si elle est illisible.
local function scaleOf(model: Model): number
	local ok, scale = pcall(function(): number
		return model:GetScale()
	end)
	return if ok and isPositiveNumber(scale) then scale else 1
end

-- Au dixième au-dessus ; la marge évite qu'une erreur d'arrondi (2,0000001) ajoute un dixième.
local function tenthAbove(value: number): number
	return math.ceil(value * 10 - 1e-6) / 10
end

-- L'agent du PathfindingService de ce vigile, à sa taille (L-040, L-048) : rayon = moitié de la
-- plus grande largeur de sa boîte, hauteur = celle de sa boîte, au dixième au-dessus, jamais moins
-- qu'un R15 standard. Boîte accessoires compris, pour qu'une casquette ou un bâton ne passent ni
-- dans un mur ni dans un plafond ; elle suit l'orientation du HumanoidRootPart (PrimaryPart).
local function agentFor(model: Model): AgentParams
	local _, size = model:GetBoundingBox()
	return {
		AgentRadius = math.max(AGENT_RADIUS_MIN, tenthAbove(math.max(size.X, size.Z) / 2)),
		AgentHeight = math.max(AGENT_HEIGHT_MIN, tenthAbove(size.Y)),
		AgentCanJump = true,
		AgentCanClimb = false,
		WaypointSpacing = WAYPOINT_SPACING,
	}
end

-- Pour la sortie : « échelle 1.40, agent 2.8 × 7.7 ».
local function sizeText(scale: number, agent: AgentParams): string
	return `échelle {string.format("%.2f", scale)}, agent {Format.short(agent.AgentRadius)} × {Format.short(agent.AgentHeight)}`
end

local function getActiveFolder(): Folder
	local folder = activeFolder
	if folder == nil or folder.Parent ~= Workspace then
		local created = Instance.new("Folder")
		created.Name = ACTIVE_FOLDER
		created.Parent = Workspace
		activeFolder = created
		return created
	end
	return folder
end

-- Vue et déplacements -----------------------------------------------------------------------

-- Les rayons ignorent les vigiles et tous les personnages : seuls les murs et le décor cachent.
local function refreshRayFilter()
	local list: { Instance } = {}
	if activeFolder then
		table.insert(list, activeFolder)
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(list, character)
		end
	end
	rayParams.FilterDescendantsInstances = list
end

local function clearLine(from: Vector3, to: Vector3): boolean
	local direction = to - from
	if direction.Magnitude < 1e-3 then
		return true
	end
	return Workspace:Raycast(from, direction, rayParams) == nil
end

-- Le vigile voit-il le joueur ? Un rayon à hauteur du HumanoidRootPart, un autre à KNEE_HEIGHT
-- au-dessus des pieds (rayons, comptoirs : il ne court pas droit dedans).
local function canSee(guard: Guard, targetRoot: BasePart, targetHumanoid: Humanoid): boolean
	local from = guard.root.Position
	local to = targetRoot.Position
	if not clearLine(from, to) then
		return false
	end
	local targetHeight = targetHumanoid.HipHeight + targetRoot.Size.Y / 2
	local fromKnee = from - Vector3.new(0, guard.rootHeight - KNEE_HEIGHT, 0)
	local toKnee = to - Vector3.new(0, targetHeight - KNEE_HEIGHT, 0)
	return clearLine(fromKnee, toKnee)
end

local function stop(guard: Guard)
	guard.humanoid:MoveTo(guard.root.Position)
end

-- Avance vers `position`, sauf si elle est en zone safe : alors il s'arrête. Pas de marge : un
-- joueur juste avant la ligne reste attrapable.
local function moveTo(guard: Guard, position: Vector3)
	if isInSafeZone(position) then
		stop(guard)
	else
		guard.humanoid:MoveTo(position)
	end
end

-- Lance le calcul d'un chemin vers `goal`, dans sa propre tâche (ComputeAsync attend).
local function computePath(guard: Guard, goal: Vector3)
	guard.computing = true
	local token = guard.pathToken
	local start = guard.root.Position
	task.spawn(function()
		local ok = pcall(function()
			guard.path:ComputeAsync(start, goal)
		end)
		guard.computing = false
		if not guard.alive or guard.pathToken ~= token then
			return
		end
		if ok and guard.path.Status == Enum.PathStatus.Success then
			guard.waypoints = guard.path:GetWaypoints()
			guard.waypointIndex = 2 -- le premier point est le départ
			guard.pathFailures = 0
		else
			guard.waypoints = nil
			guard.pathFailures += 1
		end
	end)
end

-- Suit le dernier chemin calculé ; sans chemin, ou au bout, va droit vers `goal`.
local function followPath(guard: Guard, goal: Vector3)
	local waypoints = guard.waypoints
	if waypoints == nil then
		moveTo(guard, goal)
		return
	end
	local position = guard.root.Position
	local index = guard.waypointIndex
	while index <= #waypoints and flat(waypoints[index].Position - position).Magnitude <= WAYPOINT_REACHED do
		index += 1
	end
	guard.waypointIndex = index
	if index > #waypoints then
		moveTo(guard, goal)
		return
	end
	local waypoint = waypoints[index]
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		guard.humanoid.Jump = true
	end
	moveTo(guard, waypoint.Position) -- jamais par la zone safe
end

-- Vitesse de lecture de Run ou de Walk pour le WalkSpeed actuel du vigile (L-048) :
-- WalkSpeed / (référence × échelle), bornée. 1 pour un autre nom.
local function gaitSpeed(guard: Guard, name: string): number
	local reference = GAIT_REFERENCE[name]
	if reference == nil then
		return 1
	end
	return math.clamp(guard.humanoid.WalkSpeed / (reference * guard.scale), GAIT_SPEED_MIN, GAIT_SPEED_MAX)
end

-- Joue Run ou Walk au pas du vigile ; déjà en cours, seule sa vitesse change.
local function playGait(guard: Guard, name: string)
	guard.anims:Play(name, nil, nil, gaitSpeed(guard, name))
end

-- Toute écriture du WalkSpeed d'un vigile en jeu passe par ici : Run et Walk, s'ils jouent,
-- prennent aussitôt le nouveau pas (jour : vitesse de la zone ; nuit : vitesse conseillée + 4 ;
-- retour essoufflé ou ronde : la marche).
local function setWalkSpeed(guard: Guard, value: number)
	guard.humanoid.WalkSpeed = value
	for name in GAIT_REFERENCE do
		guard.anims:AdjustSpeed(name, gaitSpeed(guard, name))
	end
end

-- Changements d'état ----------------------------------------------------------------------

-- Le calcul de chemin en cours continue (un seul à la fois par Path) ; son résultat sera jeté.
local function setState(guard: Guard, state: GuardState)
	guard.state = state
	guard.pathToken += 1
	guard.waypoints = nil
	guard.pathFailures = 0
end

-- ChaseState du joueur : le vigile de jour qui le poursuit, sinon celui de nuit ; ChaseState(false)
-- quand plus aucun ne le poursuit. N'envoie rien si rien n'a changé.
local function refreshChaseState(player: Player)
	if player.Parent ~= Players then
		chaseSent[player] = nil
		return
	end
	local guard = chasedBy[player] or nightChasedBy[player]
	local model = if guard then guard.model else nil
	if model == chaseSent[player] then
		return
	end
	if model then
		chaseSent[player] = model
		Net.Server.ChaseState:Fire(player, true, model)
	else
		chaseSent[player] = nil
		Net.Server.ChaseState:Fire(player, false)
	end
end

-- Fin de la poursuite pour le joueur (capture, abandon ou disparition du vigile).
local function endChase(guard: Guard)
	local player = guard.target
	if player == nil then
		return
	end
	guard.target = nil
	if chasedBy[player] == guard then
		chasedBy[player] = nil
	end
	if nightChasedBy[player] == guard then
		nightChasedBy[player] = nil
	end
	guard.model:SetAttribute(TARGET_ATTRIBUTE, 0)
	pcall(function()
		guard.model:RemovePersistentPlayer(player)
	end)
	refreshChaseState(player)
end

-- Le vigile ne suit plus de colis tombé au sol (6.2).
local function releaseFollow(guard: Guard)
	local payload = guard.followPayload
	if payload == nil then
		return
	end
	guard.followPayload = nil
	if following[payload] == guard then
		following[payload] = nil
	end
end

local function despawn(guard: Guard, reason: string)
	if not guard.alive then
		return
	end
	guard.alive = false
	endChase(guard)
	releaseFollow(guard)
	local list = if guard.kind == "Night" then nightGuards else guards
	local index = table.find(list, guard)
	if index then
		table.remove(list, index)
	end
	for _, connection in guard.connections do
		connection:Disconnect()
	end
	guard.pathToken += 1
	guard.anims:Destroy()
	guard.model:Destroy()
	if guard.kind ~= "Night" and guard.store then
		lastGoneAt[guard.store] = os.clock() -- rouverture du magasin : voir StoreReadyToReopen
	end
	log(`{guard.label} parti ({reason})`)
end

-- Durée du fondu (Balance.Guard.ReturnFadeTime) ; 0 si elle n'est pas un nombre fini ≥ 0.
local function fadeDuration(): number
	local value = Balance.Guard.ReturnFadeTime
	return if type(value) == "number" and value >= 0 and value < math.huge then value else 0
end

-- Le vigile de jour s'efface (L-077, point 3) : toutes ses pièces et ses décalcomanies (visage)
-- vont à Transparency 1 en Balance.Guard.ReturnFadeTime s (fadeStep), puis il disparaît.
-- `stepTo` : un dernier pas vers ce point pendant le fondu (à la porte : il « passe la porte ») ;
-- sinon il s'arrête sur place. Il ne poursuit plus personne et ne compte plus dans les plafonds.
local function startFade(guard: Guard, now: number, reason: string, stepTo: Vector3?)
	endChase(guard)
	releaseFollow(guard)
	setState(guard, "Fade")
	guard.fadeStartedAt = now
	guard.fadeReason = reason
	table.clear(guard.fadeParts)
	table.clear(guard.fadeDecals)
	for _, descendant in guard.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			guard.fadeParts[part] = part.Transparency
		elseif descendant:IsA("Decal") then
			local decal = descendant :: Decal
			guard.fadeDecals[decal] = decal.Transparency
		end
	end
	local duration = fadeDuration()
	local distance = if stepTo then flat(stepTo - guard.root.Position).Magnitude else 0
	if stepTo and duration > 0 and distance > 0.5 then
		guard.anims:Stop("Run")
		setWalkSpeed(guard, math.min(distance / duration, RETURN_WALK_SPEED))
		moveTo(guard, stepTo)
		playGait(guard, "Walk")
	else
		stop(guard)
		guard.anims:Stop("Run")
		guard.anims:Stop("Walk")
	end
	log(`{guard.label} : s'efface en {Format.short(duration)} s ({reason})`)
	if duration <= 0 then
		despawn(guard, reason)
	end
end

-- Pendant le fondu : transparence de chaque pièce entre la sienne et 1 ; à la fin, il disparaît.
local function fadeStep(guard: Guard, now: number)
	local duration = fadeDuration()
	local alpha = if duration > 0 then math.clamp((now - guard.fadeStartedAt) / duration, 0, 1) else 1
	for part, base in guard.fadeParts do
		part.Transparency = base + (1 - base) * alpha
	end
	for decal, base in guard.fadeDecals do
		decal.Transparency = base + (1 - base) * alpha
	end
	if alpha >= 1 then
		despawn(guard, guard.fadeReason)
	end
end

local function startChase(guard: Guard, now: number)
	setState(guard, "Chase")
	guard.nextSteerAt = now
	guard.nextPathAt = now
	guard.anims:Stop("Walk") -- vigile de nuit : il marchait sur sa ronde
	setWalkSpeed(guard, guard.speed)
	playGait(guard, "Run")
end

-- Ronde de nuit : point le plus proche, à l'horizontale.
local function nearestPatrolIndex(guard: Guard): number
	local best, bestDistance = 1, math.huge
	local position = guard.root.Position
	for index, point in guard.patrol do
		local distance = flat(point - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

-- Retour du vigile de jour (L-077) ------------------------------------------------------------

-- Le choix de Balance.Guard.ReturnEnd ; une autre valeur compte pour "Reserve" (V0), avec un
-- avertissement.
local function returnEnd(): ReturnTarget
	local value = Balance.Guard.ReturnEnd
	if value == "Door" then
		return "Door"
	elseif value ~= "Reserve" then
		warnOnce("returnEnd", `Balance.Guard.ReturnEnd = {value} : "Reserve" ou "Door" attendu, "Reserve" utilisé`)
	end
	return "Reserve"
end

-- Centre d'une pièce ou d'un modèle du contrat, nil sinon.
local function centerOf(inst: Instance?): Vector3?
	if inst == nil then
		return nil
	elseif inst:IsA("BasePart") then
		return (inst :: BasePart).Position
	elseif inst:IsA("Model") then
		local model = inst :: Model
		local ok, frame = pcall(function(): CFrame
			local cframe = model:GetBoundingBox()
			return cframe
		end)
		return if ok then frame.Position else nil
	end
	return nil
end

-- Hauteur du sol sous `position` (décor sans collision, vigiles et personnages ignorés), sinon
-- `fallbackY`.
local function groundBelow(position: Vector3, fallbackY: number): number
	local result = Workspace:Raycast(position, Vector3.new(0, -GROUND_RAY_DOWN, 0), rayParams)
	return if result then result.Position.Y else fallbackY
end

-- Devant la porte du magasin, côté rue (L-077, a) : la porte `Door` (10.4), sinon la vitrine
-- `Window`. La rue, comme pour la sortie des joueurs (StoreHeistService) : du centre du volume
-- Bounds (sinon du pivot du magasin) vers sa vitrine ; sans vitrine, l'avant du pivot (10.1 : face
-- avant vers la rue). Renvoie le point d'arrêt (DOOR_STOP_DISTANCE studs plus son rayon d'agent
-- devant la porte) et celui du dernier pas pendant le fondu (son rayon d'agent devant elle), au
-- sol ; nil, nil sans porte ni vitrine.
local function doorSpots(guard: Guard): (Vector3?, Vector3?)
	local store = guard.store
	if store == nil then
		return nil, nil
	end
	local window = centerOf(Find.path(store, WINDOW))
	local door = centerOf(Find.path(store, DOOR)) or window
	if door == nil then
		return nil, nil
	end
	local pivot = store:GetPivot()
	local bounds = Find.path(store, BOUNDS)
	local inner = if bounds and bounds:IsA("BasePart") then (bounds :: BasePart).Position else pivot.Position
	local out = flat(pivot.LookVector)
	if window then
		local toWindow = flat(window - inner)
		if toWindow.Magnitude > 1e-3 then
			out = toWindow
		end
	end
	if out.Magnitude < 1e-3 then
		return nil, nil
	end
	out = out.Unit
	local spot = door + out * (DOOR_STOP_DISTANCE + guard.agentRadius)
	local stepPoint = door + out * guard.agentRadius
	local ground = groundBelow(spot, guard.home.Y)
	return Vector3.new(spot.X, ground, spot.Z), Vector3.new(stepPoint.X, ground, stepPoint.Z)
end

-- Le vigile est-il dans le volume Bounds de son magasin ?
local function insideStore(guard: Guard): boolean
	local store = guard.store
	local bounds = if store then Find.path(store, BOUNDS) else nil
	if bounds and bounds:IsA("BasePart") then
		local box = bounds :: BasePart
		return insideBox(box.CFrame, box.Size, guard.root.Position)
	end
	return false
end

-- Nouveau but du retour : le calcul de chemin en cours est périmé, l'attente repart de zéro.
local function setReturnGoal(guard: Guard, target: ReturnTarget, now: number)
	local spot = guard.doorSpot
	if target == "Door" and spot then
		guard.returnTo = "Door"
		guard.returnGoal = spot
	else
		guard.returnTo = "Reserve"
		guard.returnGoal = guard.home
	end
	guard.pathToken += 1
	guard.waypoints = nil
	guard.pathFailures = 0
	guard.noPathSince = 0
	guard.nextPathAt = now
	guard.nextSteerAt = now
	guard.progressPos = guard.root.Position
	guard.progressAt = now
end

-- Passage fermé ou bloqué en route vers la réserve : il s'arrête devant la porte (L-077, b).
-- false s'il n'y a ni porte ni vitrine (il garde son but).
local function fallBackToDoor(guard: Guard, now: number, reason: string): boolean
	if guard.doorSpot == nil then
		return false
	end
	setReturnGoal(guard, "Door", now)
	log(`{guard.label} : {reason}, il s'arrête devant la porte`)
	return true
end

-- Le but du retour d'un vigile de jour (voir l'en-tête, point 5).
local function beginDayReturn(guard: Guard, now: number)
	guard.doorSpot, guard.doorStep = doorSpots(guard)
	local target: ReturnTarget = "Reserve"
	local why = "la réserve (GuardSpawn)"
	if insideStore(guard) then
		why = "la réserve (GuardSpawn), déjà dans le magasin"
	elseif returnEnd() == "Door" then
		if guard.doorSpot then
			target = "Door"
			why = "la porte du magasin"
		else
			why = "la réserve (GuardSpawn), le magasin n'a ni Door ni Window"
		end
	end
	setReturnGoal(guard, target, now)
	log(`{guard.label} : rentre en marchant vers {why}`)
end

local function startReturn(guard: Guard, now: number)
	setState(guard, "Return")
	if guard.kind == "Night" and #guard.patrol > 0 then
		-- La nuit, il rentre au point de ronde le plus proche, à l'allure de la ronde.
		guard.patrolIndex = nearestPatrolIndex(guard)
		guard.home = guard.patrol[guard.patrolIndex]
		setWalkSpeed(guard, Night.PatrolSpeed)
	else
		setWalkSpeed(guard, RETURN_WALK_SPEED)
	end
	guard.returnedAt = now
	guard.progressPos = guard.root.Position
	guard.progressAt = now
	guard.nextSteerAt = now
	guard.nextPathAt = now
	guard.anims:Stop("Run")
	guard.anims:Stop("Tired")
	if guard.kind == "Night" then
		playGait(guard, "Walk")
	else
		beginDayReturn(guard, now) -- Walk joue dès qu'il avance (dayReturnStep)
	end
end

-- Durée d'une animation sans boucle qui vient d'être lancée, bornée ; `default` si elle n'est
-- pas livrée ou pas encore chargée.
local function pauseFor(track: AnimationTrack?, default: number, max: number): number
	if track and track.Length > 0 then
		return math.min(track.Length, max)
	end
	return default
end

-- Abandon : le vigile s'arrête, essoufflé, puis rentre. Aussi depuis Follow (colis au sol, 6.2).
local function giveUp(guard: Guard, reason: string)
	local state = guard.state
	if state ~= "Wait" and state ~= "Chase" and state ~= "Follow" then
		return
	end
	local player = guard.target
	endChase(guard)
	releaseFollow(guard)
	if state == "Follow" then
		log(`{guard.label} : abandonne le colis tombé au sol ({reason})`)
	else
		log(`{guard.label} : abandonne {if player then player.Name else "?"} ({reason})`)
	end
	local now = os.clock()
	stop(guard)
	if state == "Wait" then
		startReturn(guard, now) -- il ne s'est pas encore élancé : pas d'essoufflement
		return
	end
	setState(guard, "Tired")
	guard.anims:Stop("Run")
	guard.stateEndsAt = now + pauseFor(guard.anims:Play("Tired"), TIRED_PAUSE, TIRED_MAX)
end

-- Capture ---------------------------------------------------------------------------------

-- Immobilise le joueur `duration` s ; un nouvel appel remplace le précédent.
local function stun(player: Player, duration: number)
	local token = (stunTokens[player] or 0) + 1
	stunTokens[player] = token
	StatsService.SetSpeedModifier(player, STUN_KEY, 0)
	task.delay(duration, function()
		if stunTokens[player] == token then
			stunTokens[player] = nil
			StatsService.SetSpeedModifier(player, STUN_KEY, nil)
		end
	end)
end

-- Projette le joueur à l'opposé de `from` : une LinearVelocity posée par le serveur dans son
-- HumanoidRootPart, que son client simule (il possède son personnage), retirée après
-- KNOCKBACK_DURATION s.
local function knockback(player: Player, from: Vector3)
	if player.Parent ~= Players then
		return
	end
	local root = bodyOf(player)
	if root == nil then
		return
	end
	local away = flat(root.Position - from)
	if away.Magnitude < 1e-3 then
		away = flat(root.CFrame.LookVector)
	end
	local direction = if away.Magnitude > 1e-3 then away.Unit else Vector3.new(0, 0, 1)
	AntiCheatService.Allow(player, KNOCKBACK_DURATION, "GuardService (coup du vigile)") -- poussée du code (DEV-060)
	local attachment = Instance.new("Attachment")
	attachment.Name = KNOCKBACK_NAME
	local mover = Instance.new("LinearVelocity")
	mover.Name = KNOCKBACK_NAME
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.MaxForce = math.huge
	mover.VectorVelocity = direction * KNOCKBACK_SPEED + Vector3.new(0, KNOCKBACK_UP, 0)
	mover.Parent = attachment
	attachment.Parent = root
	Debris:AddItem(attachment, KNOCKBACK_DURATION)
end

-- Délai de secours de la poussée, Catch lancée (L-071, point 5) : le marqueur Impact est posé dans
-- Catch, donc une Catch chargée l'attend jusqu'à sa fin (bornée à CATCH_MAX, la pause du vigile) :
-- un Impact plus tardif dans la Catch refaite par Clément ne se fait jamais devancer. Pas encore
-- chargée (durée inconnue) : KNOCKBACK_MAX_WAIT.
local function impactMaxWait(track: AnimationTrack): number
	if track.Length > 0 then
		return math.min(track.Length, CATCH_MAX)
	end
	return KNOCKBACK_MAX_WAIT
end

-- La poussée en attente part (marqueur Impact de Catch, ou délai écoulé), suivie de ce qui doit
-- venir après le coup (le jour : l'étourdissement compté du coup ; la nuit : le renvoi chez lui).
local function releaseKnockback(guard: Guard)
	local player = guard.knockTarget
	if player then
		guard.knockTarget = nil
		knockback(player, guard.root.Position)
		local after = guard.onKnock
		if after then
			guard.onKnock = nil
			task.spawn(after, player)
		end
	end
end

-- Prévient les écouteurs d'OnCatch, avant que le portage soit perdu (carrying = l'état à la capture).
local function emitCatch(player: Player, zone: number, night: boolean)
	local ok, result = pcall(CarryService.IsCarrying, player)
	local carrying = ok and result == true
	for _, listener in table.clone(catchListeners) do
		task.spawn(listener, player, zone, night, carrying)
	end
end

local function catch(guard: Guard, player: Player)
	local now = os.clock()
	endChase(guard)
	setState(guard, "Catch")
	stop(guard)
	guard.anims:Stop("Run")
	local track = guard.anims:Play("Catch")
	guard.stateEndsAt = now + pauseFor(track, CATCH_PAUSE, CATCH_MAX)
	log(`{guard.label} : {player.Name} rattrapé`)

	-- Le coup : au marqueur Impact de Catch (délai de secours : impactMaxWait), ou tout de suite si
	-- Catch n'est pas livrée (pas de geste à attendre). Immobilisé dès la capture (plus bas), le
	-- joueur reste étourdi CatchStunDuration s à partir du coup, comme son client le montre avec
	-- Knockback puis Stunned (ChaseController), et non à partir de la capture.
	if track then
		guard.knockTarget = player
		guard.onKnock = function(caught: Player)
			stun(caught, Balance.Guard.CatchStunDuration)
		end
		task.delay(impactMaxWait(track), function()
			if guard.knockTarget == player then
				releaseKnockback(guard)
			end
		end)
	else
		knockback(player, guard.root.Position)
	end

	-- Colis, étourdissement, message : décidés ici, au moment de la capture, dans leur propre tâche
	-- pour qu'un appel qui attend ne bloque pas les autres vigiles.
	local zone = guard.zone
	emitCatch(player, zone, false)
	task.spawn(function()
		local ok, err = pcall(CarryService.Fail :: any, player, "Caught")
		if not ok then
			warn(`[GuardService] CarryService.Fail({player.Name}, "Caught") : {err}`)
		end
		stun(player, Balance.Guard.CatchStunDuration)
		if player.Parent == Players then
			Net.Server.Notify:Fire(
				player,
				`Caught! Recommended speed: {Format.short(Zones[zone].AdvisedSpeed)}`,
				"Warning"
			)
		end
	end)
end

-- Attrapé la nuit (5.12) : immobilisé tout de suite, colis rendu, le même coup que le jour, puis
-- renvoyé chez lui et étourdi Night.CaughtStunDuration s. Aucune autre perte.
local function nightCatch(guard: Guard, player: Player)
	local now = os.clock()
	local hooks = nightHooks
	endChase(guard)
	setState(guard, "Catch")
	stop(guard)
	guard.anims:Stop("Run")
	local track = guard.anims:Play("Catch")
	guard.stateEndsAt = now + pauseFor(track, CATCH_PAUSE, CATCH_MAX)
	log(`{guard.label} : {player.Name} attrapé, renvoyé chez lui`)

	stun(player, NIGHT_FREEZE_MAX) -- jusqu'au renvoi ; l'étourdissement de 2 s part de là
	caughtAtNight[player] = true
	emitCatch(player, guard.zone, true)
	task.spawn(function()
		local ok, err = pcall(CarryService.Fail :: any, player, "Caught")
		if not ok then
			warn(`[GuardService] CarryService.Fail({player.Name}, "Caught") : {err}`)
		end
	end)

	local function sendHome(caught: Player)
		task.wait(Night.SendHomeDelay)
		if caught.Parent ~= Players then
			caughtAtNight[caught] = nil
			return
		end
		if hooks then
			local ok, err = pcall(hooks.SendHome, caught)
			if not ok then
				warn(`[GuardService] SendHome({caught.Name}) : {err}`)
			end
		end
		caughtAtNight[caught] = nil
		stun(caught, Night.CaughtStunDuration)
		if caught.Parent == Players then
			Net.Server.Notify:Fire(caught, MESSAGES.NightCaught, "Warning")
		end
	end

	-- Arrestation (L-076, Clément) : si le vigile de nuit a Arrest, il la joue au lieu du coup ; le
	-- joueur, prévenu par un objet ARREST_NAME dans son HumanoidRootPart, joue Arrested (ChaseController),
	-- puis il est renvoyé chez lui à la fin de la scène. Sans Arrest : le coup de Catch, comme avant.
	local arrest = guard.anims:Play("Arrest")
	if arrest then
		if track then
			track:Stop(0)
		end
		local body = bodyOf(player)
		if body then
			local look = flat(body.Position - guard.root.Position)
			if look.Magnitude > 1e-3 then
				guard.root.CFrame = CFrame.lookAt(guard.root.Position, guard.root.Position + look)
			end
			local signal = Instance.new("BoolValue")
			signal.Name = ARREST_NAME
			signal.Parent = body
			Debris:AddItem(signal, ARREST_SIGNAL_LIFE)
		end
		local length = if arrest.Length > 0 then arrest.Length else ARREST_FALLBACK_LENGTH
		guard.stateEndsAt = now + length
		task.delay(math.max(length - Night.SendHomeDelay, 0), sendHome, player)
		return
	end

	-- Le coup : au marqueur Impact de Catch (délai de secours : impactMaxWait), ou tout de suite si
	-- Catch n'est pas livrée.
	if track then
		guard.knockTarget = player
		guard.onKnock = sendHome
		task.delay(impactMaxWait(track), function()
			if guard.knockTarget == player then
				releaseKnockback(guard)
			end
		end)
	else
		knockback(player, guard.root.Position)
		task.spawn(sendHome, player)
	end
end

-- Pourquoi un vigile de nuit lâche (ou ne vise pas) ce joueur, nil s'il peut le poursuivre.
local function nightRefusal(player: Player, position: Vector3): string?
	local hooks = nightHooks
	if hooks == nil then
		return "fin de la nuit"
	end
	local okInside, inside = pcall(hooks.InCorridor, position)
	if not okInside then
		warnOnce("hook:InCorridor", `InCorridor : {inside}`)
		return "couloir inconnu"
	elseif inside ~= true then
		return "sorti du couloir"
	end
	local okIgnored, ignored = pcall(hooks.Ignores, player)
	if not okIgnored then
		warnOnce("hook:Ignores", `Ignores : {ignored} (joueur ignoré)`)
		return "joueur ignoré"
	elseif ignored == true then
		return "joueur ignoré (bouclier débutant)"
	end
	return nil
end

-- Boucle ----------------------------------------------------------------------------------

local function chaseStep(guard: Guard, now: number)
	local player = guard.target
	if player == nil then
		giveUp(guard, "plus de cible")
		return
	end
	local targetRoot, targetHumanoid = bodyOf(player)
	if targetRoot == nil or targetHumanoid == nil then
		giveUp(guard, "plus de personnage")
		return
	end
	local night = guard.kind == "Night"
	if night then
		local reason = nightRefusal(player, targetRoot.Position)
		if reason then
			giveUp(guard, reason)
			return
		end
	elseif not CarryService.IsCarrying(player) then
		giveUp(guard, "ne porte plus de colis")
		return
	end
	if isInSafeZone(targetRoot.Position) then
		giveUp(guard, "zone safe")
		return
	end
	if isInSafeZone(guard.root.Position) then
		giveUp(guard, "vigile poussé en zone safe")
		return
	end
	local distance = (targetRoot.Position - guard.root.Position).Magnitude
	local catchDistance = if night then Night.CatchDistance else Balance.Guard.CatchDistance
	if distance <= catchDistance and clearLine(guard.root.Position, targetRoot.Position) then
		if night then
			nightCatch(guard, player)
		else
			catch(guard, player)
		end
		return
	end
	local giveUpAfter = if night then Night.GiveUpChaseDuration else Balance.Guard.GiveUpChaseDuration
	if now - guard.chaseStartedAt >= giveUpAfter then
		giveUp(guard, `{giveUpAfter} s de poursuite`)
		return
	end
	local giveUpLead = if night then Night.GiveUpLead else Balance.Guard.GiveUpLead
	if distance >= giveUpLead then
		giveUp(guard, `{giveUpLead} studs d'avance`)
		return
	end
	if now < guard.nextSteerAt then
		return
	end
	guard.nextSteerAt = now + STEER_INTERVAL
	if canSee(guard, targetRoot, targetHumanoid) then
		guard.waypoints = nil
		moveTo(guard, targetRoot.Position)
		return
	end
	if now >= guard.nextPathAt and not guard.computing then
		guard.nextPathAt = now + Balance.Guard.PathRecomputeInterval
		computePath(guard, targetRoot.Position)
	end
	followPath(guard, targetRoot.Position)
end

-- Colis tombé au sol (6.2) : le vigile court vers l'endroit du coup et attend à côté qu'on le
-- ramasse (retarget) ou qu'il reparte vers son rayon (giveUp). Aucune capture ici.
local function followStep(guard: Guard, now: number)
	if now >= guard.stateEndsAt then
		giveUp(guard, `{Bat.DroppedLifetime + FOLLOW_MARGIN} s sans nouvelles du colis au sol`)
		return
	end
	if isInSafeZone(guard.root.Position) then
		giveUp(guard, "vigile poussé en zone safe")
		return
	end
	if now < guard.nextSteerAt then
		return
	end
	guard.nextSteerAt = now + STEER_INTERVAL
	local goal = guard.followPosition
	if flat(goal - guard.root.Position).Magnitude <= FOLLOW_STOP_DISTANCE then
		stop(guard)
		guard.anims:Stop("Run") -- Idle joue toujours en fond
		guard.waypoints = nil
		return
	end
	playGait(guard, "Run")
	if clearLine(guard.root.Position, goal) then
		guard.waypoints = nil
		moveTo(guard, goal)
		return
	end
	if now >= guard.nextPathAt and not guard.computing then
		guard.nextPathAt = now + Balance.Guard.PathRecomputeInterval
		computePath(guard, goal)
	end
	followPath(guard, goal)
end

-- Ronde de nuit ----------------------------------------------------------------------------

local function startPatrol(guard: Guard, now: number)
	setState(guard, "Patrol")
	setWalkSpeed(guard, Night.PatrolSpeed)
	guard.pauseUntil = 0
	guard.progressPos = guard.root.Position
	guard.progressAt = now
	guard.nextSteerAt = now
	guard.nextPathAt = now
	guard.anims:Stop("Run")
	guard.anims:Stop("Tired")
	if #guard.patrol > 1 then
		playGait(guard, "Walk")
	else
		guard.anims:Stop("Walk")
	end
end

-- Point suivant de l'aller-retour ; le calcul de chemin en cours est périmé.
local function nextPatrolPoint(guard: Guard, now: number)
	local count = #guard.patrol
	if count > 1 then
		local index = guard.patrolIndex + guard.patrolStep
		if index < 1 or index > count then
			guard.patrolStep = -guard.patrolStep
			index = guard.patrolIndex + guard.patrolStep
		end
		guard.patrolIndex = index
	end
	guard.pathToken += 1
	guard.waypoints = nil
	guard.progressPos = guard.root.Position
	guard.progressAt = now
	guard.nextPathAt = now
end

local function patrolStep(guard: Guard, now: number)
	local count = #guard.patrol
	if count == 0 then
		return
	end
	local position = guard.root.Position
	if guard.pauseUntil > 0 then
		if now >= guard.pauseUntil then
			guard.pauseUntil = 0
			nextPatrolPoint(guard, now)
			playGait(guard, "Walk")
		end
		return
	end
	local goal = guard.patrol[guard.patrolIndex]
	if flat(goal - position).Magnitude <= ARRIVE_DISTANCE then
		stop(guard)
		if count > 1 then
			guard.pauseUntil = now + Night.PatrolPause
			guard.anims:Stop("Walk")
		end
		return
	end
	if (position - guard.progressPos).Magnitude >= 1 then
		guard.progressPos = position
		guard.progressAt = now
	elseif now - guard.progressAt >= RETURN_STUCK_TIME then
		log(`{guard.label} : bloqué sur sa ronde, point suivant`)
		nextPatrolPoint(guard, now)
		return
	end
	if now < guard.nextSteerAt then
		return
	end
	guard.nextSteerAt = now + STEER_INTERVAL
	-- Rue dégagée (presque toujours) : tout droit, sans calcul de chemin ; sinon PathfindingService.
	local from = guard.root.Position
	local to = goal + Vector3.new(0, guard.rootHeight, 0)
	local knee = Vector3.new(0, guard.rootHeight - KNEE_HEIGHT, 0)
	if clearLine(from, to) and clearLine(from - knee, to - knee) then
		guard.waypoints = nil
		moveTo(guard, goal)
		return
	end
	if now >= guard.nextPathAt and not guard.computing then
		guard.nextPathAt = now + RETURN_PATH_INTERVAL
		computePath(guard, goal)
	end
	followPath(guard, goal)
end

-- Le cône de la lampe torche, à l'horizontale (Night.DetectionConeAngle autour de l'avant).
local COS_CONE = math.cos(math.rad(math.clamp(Night.DetectionConeAngle, 0, 180)))

local function inCone(guard: Guard, offset: Vector3): boolean
	local look = flat(guard.root.CFrame.LookVector)
	local direction = flat(offset)
	if look.Magnitude < 1e-3 or direction.Magnitude < 1e-3 then
		return true -- juste au-dessus ou en dessous de lui
	end
	return look.Unit:Dot(direction.Unit) >= COS_CONE
end

-- Le joueur le plus proche que ce vigile de nuit repère (voir l'en-tête), ou nil.
local function scan(guard: Guard): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		if nightChasedBy[player] == nil and not caughtAtNight[player] then
			local root, humanoid = bodyOf(player)
			if root and humanoid then
				local offset = root.Position - guard.root.Position
				local distance = offset.Magnitude
				if
					distance <= Night.DetectionRange
					and distance < bestDistance
					and inCone(guard, offset)
					and nightRefusal(player, root.Position) == nil
					and canSee(guard, root, humanoid)
				then
					best, bestDistance = player, distance
				end
			end
		end
	end
	return best
end

-- Repéré : délai de réaction, puis poursuite.
local function spot(guard: Guard, player: Player, now: number)
	setState(guard, "Wait")
	stop(guard)
	guard.anims:Stop("Walk")
	guard.pauseUntil = 0
	guard.target = player
	guard.chaseStartedAt = now
	guard.stateEndsAt = now + REACTION_DELAY
	nightChasedBy[player] = guard
	guard.model:SetAttribute(TARGET_ATTRIBUTE, player.UserId)
	pcall(function()
		guard.model:AddPersistentPlayer(player)
	end)
	refreshChaseState(player)
	local root = bodyOf(player)
	local distance = if root then (root.Position - guard.root.Position).Magnitude else 0
	log(`{guard.label} : repère {player.Name} à {Format.short(distance)} studs, poursuite à {Format.short(guard.speed)}`)
end

-- Vigile de nuit : retour au point de ronde le plus proche, puis la ronde reprend (inchangé par L-077).
local function nightReturnStep(guard: Guard, now: number)
	local position = guard.root.Position
	if flat(guard.home - position).Magnitude <= ARRIVE_DISTANCE then
		startPatrol(guard, now)
		return
	end
	if now - guard.returnedAt >= RETURN_MAX_DURATION then
		startPatrol(guard, now) -- reprend la ronde d'où il est
		return
	end
	if (position - guard.progressPos).Magnitude >= 1 then
		guard.progressPos = position
		guard.progressAt = now
	elseif now - guard.progressAt >= RETURN_STUCK_TIME then
		startPatrol(guard, now)
		return
	end
	if now < guard.nextSteerAt then
		return
	end
	guard.nextSteerAt = now + STEER_INTERVAL
	if now >= guard.nextPathAt and not guard.computing then
		guard.nextPathAt = now + RETURN_PATH_INTERVAL
		computePath(guard, guard.home)
	end
	followPath(guard, guard.home)
end

-- Le vigile qui rentre voit-il son but (au sol) ? Les deux rayons de canSee (HumanoidRootPart,
-- genoux), plus deux à ses flancs (son rayon d'agent moins RETURN_SIDE_INSET, de chaque côté) :
-- tout son corps passe, pas seulement son centre (montant de vitrine, bout de rayon).
local function seesGoal(guard: Guard, goal: Vector3): boolean
	local from = guard.root.Position
	local to = Vector3.new(goal.X, goal.Y + guard.rootHeight, goal.Z)
	local knee = Vector3.new(0, guard.rootHeight - KNEE_HEIGHT, 0)
	if not (clearLine(from, to) and clearLine(from - knee, to - knee)) then
		return false
	end
	local along = flat(to - from)
	if along.Magnitude < 1e-3 then
		return true
	end
	local side = Vector3.new(-along.Z, 0, along.X).Unit * math.max(guard.agentRadius - RETURN_SIDE_INSET, 0)
	return clearLine(from + side, to + side) and clearLine(from - side, to - side)
end

-- Un pas du retour d'un vigile de jour vers `goal` (au sol), sans jamais marcher droit dans un
-- mur : tout droit s'il voit son but (seesGoal) ; sinon le dernier chemin calculé (recalculé
-- toutes les Balance.Guard.PathRecomputeInterval s) ; sans chemin, ou au bout du chemin sans voir
-- le but, il s'arrête et attend le calcul suivant. Renvoie true s'il avance.
local function walkHome(guard: Guard, goal: Vector3, now: number): boolean
	local from = guard.root.Position
	if seesGoal(guard, goal) then
		guard.waypoints = nil
		moveTo(guard, goal)
		return true
	end
	if now >= guard.nextPathAt and not guard.computing then
		guard.nextPathAt = now + Balance.Guard.PathRecomputeInterval
		computePath(guard, goal)
	end
	local waypoints = guard.waypoints
	if waypoints == nil then
		stop(guard)
		return false
	end
	local index = guard.waypointIndex
	while index <= #waypoints and flat(waypoints[index].Position - from).Magnitude <= WAYPOINT_REACHED do
		index += 1
	end
	guard.waypointIndex = index
	if index > #waypoints then
		stop(guard)
		return false
	end
	local waypoint = waypoints[index]
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		guard.humanoid.Jump = true
	end
	moveTo(guard, waypoint.Position) -- jamais par la zone safe
	return true
end

-- Retour d'un vigile de jour (voir l'en-tête, point 5) : il s'efface en fondu à l'arrivée, ou
-- plus tôt là où il est (retour trop long, aucun chemin, bloqué devant la porte).
local function dayReturnStep(guard: Guard, now: number)
	local position = guard.root.Position
	local atDoor = guard.returnTo == "Door"
	local arrive = if atDoor then DOOR_ARRIVE_DISTANCE else ARRIVE_DISTANCE
	if flat(guard.returnGoal - position).Magnitude <= arrive then
		startFade(guard, now, "rentré", if atDoor then guard.doorStep else nil)
		return
	end
	if now - guard.returnedAt >= RETURN_MAX_DURATION then
		startFade(guard, now, "retour trop long", nil)
		return
	end
	if now < guard.nextSteerAt then
		return
	end
	guard.nextSteerAt = now + STEER_INTERVAL
	if walkHome(guard, guard.returnGoal, now) then
		guard.noPathSince = 0
		playGait(guard, "Walk")
		if (position - guard.progressPos).Magnitude >= 1 then
			guard.progressPos = position
			guard.progressAt = now
		elseif now - guard.progressAt >= RETURN_STUCK_TIME then
			if atDoor or not fallBackToDoor(guard, now, "bloqué en route vers la réserve") then
				startFade(guard, now, "bloqué sur le retour", nil)
			end
		end
		return
	end
	-- Ni ligne de vue ni chemin : il attend sur place (Idle), sans pousser contre un mur.
	guard.anims:Stop("Walk")
	guard.progressPos = position
	guard.progressAt = now
	if guard.noPathSince == 0 then
		guard.noPathSince = now
	end
	if not atDoor and guard.pathFailures > 0 and fallBackToDoor(guard, now, "pas de chemin jusqu'à la réserve (passage fermé)") then
		return
	end
	if now - guard.noPathSince >= RETURN_NO_PATH_TIMEOUT then
		startFade(guard, now, "aucun chemin pour rentrer", nil)
	end
end

local function update(guard: Guard, now: number)
	if not guard.root:IsDescendantOf(Workspace) or guard.humanoid.Health <= 0 then
		despawn(guard, "sorti du jeu")
		return
	end
	local state = guard.state
	local night = guard.kind == "Night"
	-- Vigile de nuit : il cherche une cible pendant sa ronde et sur le chemin du retour.
	if night and (state == "Patrol" or state == "Return") and now >= guard.nextScanAt then
		guard.nextScanAt = now + STEER_INTERVAL
		local found = scan(guard)
		if found then
			spot(guard, found, now)
			return
		end
	end
	if state == "Wait" then
		local player = guard.target
		local root = if player then bodyOf(player) else nil
		if night then
			local reason = if player == nil or root == nil then "plus de cible" else nightRefusal(player, root.Position)
			if reason then
				giveUp(guard, `{reason}, avant le départ`)
			elseif now >= guard.stateEndsAt then
				startChase(guard, now)
			end
		elseif player == nil or root == nil or not CarryService.IsCarrying(player) then
			giveUp(guard, "portage fini avant le départ")
		elseif now >= guard.stateEndsAt then
			startChase(guard, now)
		end
	elseif state == "Chase" then
		chaseStep(guard, now)
	elseif state == "Follow" then
		followStep(guard, now)
	elseif state == "Catch" or state == "Tired" then
		if now >= guard.stateEndsAt then
			startReturn(guard, now)
		end
	elseif state == "Return" then
		if night then
			nightReturnStep(guard, now)
		else
			dayReturnStep(guard, now)
		end
	elseif state == "Patrol" then
		patrolStep(guard, now)
	elseif state == "Fade" then
		fadeStep(guard, now)
	end
end

local function step()
	if #guards == 0 and #nightGuards == 0 then
		return
	end
	refreshRayFilter()
	local now = os.clock()
	for _, list in { guards, nightGuards } do
		for _, guard in table.clone(list) do
			if guard.alive then
				local ok, err = pcall(update :: any, guard, now)
				if not ok then
					warn(`[GuardService] {guard.label} : {err}`)
					despawn(guard, "erreur")
				end
			end
		end
	end
end

-- Apparition ------------------------------------------------------------------------------

local function chaseSpeed(player: Player, zone: number): number
	local ok, value = pcall(GuardService.GetSpeedOverride, player, zone)
	if not ok then
		warn(`[GuardService] GetSpeedOverride({player.Name}) : {value}`)
	elseif value ~= nil then
		if isPositiveNumber(value) then
			return value :: number
		end
		warn(`[GuardService] GetSpeedOverride({player.Name}) invalide ({value}) : vitesse de la zone`)
	end
	return Zones[zone].GuardSpeed
end

-- Vigiles qui poursuivent pour ce magasin, ou suivent un de ses colis tombé au sol (ceux qui
-- rentrent ne comptent pas).
local function countChasing(store: Model): number
	local count = 0
	for _, guard in guards do
		local state = guard.state
		if guard.store == store and (state == "Wait" or state == "Chase" or state == "Catch" or state == "Follow") then
			count += 1
		end
	end
	return count
end

-- Vigiles de jour en jeu pour le plafond du serveur (9.7) : ceux qui s'effacent ne comptent plus.
local function countActive(): number
	local count = 0
	for _, guard in guards do
		if guard.state ~= "Fade" then
			count += 1
		end
	end
	return count
end

-- Au plafond du serveur : le vigile qui rentre depuis le plus longtemps s'efface (fondu).
-- Renvoie false s'il n'y en a aucun.
local function freeSlot(): boolean
	local oldest: Guard? = nil
	for _, guard in guards do
		if guard.state == "Tired" or guard.state == "Return" then
			if oldest == nil or guard.spawnedAt < oldest.spawnedAt then
				oldest = guard
			end
		end
	end
	if oldest == nil then
		return false
	end
	startFade(oldest, os.clock(), "place libérée pour un nouveau vigile", nil)
	return true
end

-- Le point d'apparition : le GuardSpawn, ou la première place libre devant lui (vers la
-- vitrine), de SPAWN_SPACING en SPAWN_SPACING, si des vigiles y sont déjà.
local function spawnSpot(store: Model): CFrame
	local base = spawnFrame(store)
	local spot = base
	for slot = 0, Balance.Guard.MaxActivePerServer do
		spot = base + base.LookVector * (SPAWN_SPACING * slot)
		local taken = false
		for _, other in guards do
			if flat(other.root.Position - spot.Position).Magnitude < SPAWN_SPACING * 0.9 then
				taken = true
				break
			end
		end
		if not taken then
			break
		end
	end
	return spot
end

-- Crée le vigile du voleur `player` dans le magasin `store`. N'attend pas.
local function spawnGuard(player: Player, store: Model, zone: number, template: Model, label: string)
	if chasedBy[player] ~= nil then
		return -- un vigile par voleur (Balance.Guard.PerThief)
	end
	if countChasing(store) >= Balance.Guard.MaxPerStore then
		log(`{store.Name} : déjà {Balance.Guard.MaxPerStore} vigiles en poursuite, pas de vigile pour {player.Name}`)
		return
	end
	if countActive() >= Balance.Guard.MaxActivePerServer and not freeSlot() then
		log(`déjà {Balance.Guard.MaxActivePerServer} vigiles en poursuite sur le serveur (9.7), pas de vigile pour {player.Name}`)
		return
	end

	local model = template:Clone()
	local humanoid, root = prepare(model, label)
	if humanoid == nil or root == nil then
		warnOnce(`bad:{label}`, `{label} : Humanoid ou HumanoidRootPart manquant, vigile non créé`)
		model:Destroy()
		return
	end
	local scale = scaleOf(model)
	local agent = agentFor(model)

	-- Placement : pieds sur le point d'apparition.
	local frame = spawnSpot(store)
	local rootHeight = humanoid.HipHeight + root.Size.Y / 2
	local offset = model:GetPivot():ToObjectSpace(root.CFrame)
	model:PivotTo(frame * CFrame.new(0, rootHeight, 0) * offset:Inverse())

	model:SetAttribute(TARGET_ATTRIBUTE, player.UserId)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
		model:AddPersistentPlayer(player)
	end)
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = 0
	model.Parent = getActiveFolder()
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
	local now = os.clock()
	local guard: Guard = {
		model = model,
		humanoid = humanoid,
		root = root,
		rootHeight = rootHeight,
		scale = scale,
		anims = AnimPlayer.new(animator :: Animator, AnimPlayer.modelFolder(model), Animations.Guard, ANIM_LABEL),
		kind = "Day",
		label = `vigile de {store.Name}`,
		store = store,
		home = frame.Position,
		zone = zone,
		speed = chaseSpeed(player, zone),
		target = player,
		state = "Wait",
		spawnedAt = now,
		chaseStartedAt = now,
		patrol = {},
		patrolIndex = 1,
		patrolStep = 1,
		pauseUntil = 0,
		onKnock = nil,
		nextScanAt = 0,
		stateEndsAt = now + REACTION_DELAY,
		returnedAt = now,
		nextSteerAt = now,
		nextPathAt = now,
		path = PathfindingService:CreatePath(agent),
		pathToken = 0,
		computing = false,
		waypoints = nil,
		waypointIndex = 2,
		progressPos = root.Position,
		progressAt = now,
		knockTarget = nil,
		followPayload = nil,
		followPosition = Vector3.zero,
		agentRadius = agent.AgentRadius,
		pathFailures = 0,
		returnTo = "Reserve",
		returnGoal = frame.Position,
		doorSpot = nil,
		doorStep = nil,
		noPathSince = 0,
		fadeStartedAt = 0,
		fadeReason = "",
		fadeParts = {},
		fadeDecals = {},
		connections = {},
		alive = true,
	}
	table.insert(guard.connections, humanoid.Died:Connect(function()
		despawn(guard, "mort")
	end))
	for _, entry in MarkerSounds.Guard do
		guard.anims:OnMarker(entry.Anim, entry.Marker, function()
			MarkerSounds.play(entry.Sound, guard.root)
		end)
	end
	guard.anims:OnMarker("Catch", CATCH_MARKER, function()
		releaseKnockback(guard)
	end)
	guard.anims:Play("Idle")

	table.insert(guards, guard)
	chasedBy[player] = guard
	refreshChaseState(player)
	log(
		`vigile ({label}) lancé sur {player.Name} depuis {store.Name}, zone {zone}, vitesse {Format.short(guard.speed)}, {sizeText(scale, agent)} ({#guards} en jeu)`
	)
end

-- Vigiles de nuit : apparition ---------------------------------------------------------------

-- Position d'un point de ronde : une pièce, un Attachment ou un modèle.
local function pointPosition(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return (instance :: BasePart).Position
	elseif instance:IsA("Attachment") then
		return (instance :: Attachment).WorldPosition
	elseif instance:IsA("PVInstance") then
		return (instance :: PVInstance):GetPivot().Position
	end
	return nil
end

-- Points de ronde de la map, par zone, triés par nom (puis le long de la rue, pour départager).
local function patrolPoints(): { [number]: { Vector3 } }
	type Entry = { name: string, position: Vector3 }
	local byZone: { [number]: { Entry } } = {}
	for _, instance in CollectionService:GetTagged(NIGHT_PATROL_TAG) do
		if inMap(instance) then
			local zone = instance:GetAttribute(ZONE_ATTRIBUTE)
			local position = pointPosition(instance)
			if type(zone) == "number" and Zones[zone] ~= nil and position then
				local list = byZone[zone] or {}
				byZone[zone] = list
				table.insert(list, { name = instance.Name, position = position })
			else
				warnOnce(
					`patrol:{instance:GetFullName()}`,
					`{instance:GetFullName()} : point de ronde sans attribut Zone de 1 à 6 (ou sans position), ignoré`
				)
			end
		end
	end
	local result: { [number]: { Vector3 } } = {}
	for zone, list in byZone do
		table.sort(list, function(a: Entry, b: Entry): boolean
			if a.name ~= b.name then
				return a.name < b.name
			end
			return a.position.X < b.position.X
		end)
		local points: { Vector3 } = {}
		for _, entry in list do
			table.insert(points, entry.position)
		end
		result[zone] = points
	end
	return result
end

-- Le modèle d'un vigile de nuit de cette zone, et s'il faut lui ajouter la lampe torche de
-- remplacement (rig du code seulement).
local function nightTemplate(zone: number): (Model?, string, boolean)
	local template: Model? = nil
	for _, name in { string.format(NIGHT_ZONE_NAME, zone), NIGHT_COMMON_NAME } do
		for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
			local assets = service:FindFirstChild("Assets")
			local folder = if assets then assets:FindFirstChild(GUARD_FOLDER) else nil
			local model = if folder then folder:FindFirstChild(name) else nil
			if template == nil and model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
				template = model :: Model
			end
		end
	end
	if template == nil then
		template = findTemplate(zone) -- look de jour de Clément, s'il est livré
	end
	if template and not isUsable(template) then
		warnOnce(
			`bad:{template:GetFullName()}`,
			`{template:GetFullName()} : Humanoid ou HumanoidRootPart manquant (10.4), rig de remplacement utilisé`
		)
		template = nil
	end
	if template then
		return template, template:GetFullName(), false
	end
	return getFallback(), FALLBACK_NAME, true
end

-- Lampe torche du rig de remplacement : une SpotLight vers l'avant, aux dimensions du cône.
local function addFlashlight(model: Model, root: BasePart)
	local head = model:FindFirstChild("Head")
	local holder: BasePart = if head and head:IsA("BasePart") then head :: BasePart else root
	local light = Instance.new("SpotLight")
	light.Name = FLASHLIGHT_NAME
	light.Face = Enum.NormalId.Front
	light.Range = math.clamp(Night.DetectionRange, 0, 60)
	light.Angle = math.clamp(Night.DetectionConeAngle * 2, 0, 180)
	light.Brightness = FLASHLIGHT_BRIGHTNESS
	light.Color = FLASHLIGHT_COLOR
	light.Shadows = false
	light.Parent = holder
end

-- Pose le vigile de nuit n° `number` de la zone sur le point `startIndex` de sa ronde. N'attend pas.
local function spawnNightGuard(zone: number, number: number, points: { Vector3 }, startIndex: number, template: Model, label: string, fallback: boolean)
	local model = template:Clone()
	model.Name = string.format(NIGHT_CLONE_NAME, zone, number)
	local humanoid, root = prepare(model, label)
	if humanoid == nil or root == nil then
		warnOnce(`bad:{label}`, `{label} : Humanoid ou HumanoidRootPart manquant, vigile de nuit non créé`)
		model:Destroy()
		return
	end
	local scale = scaleOf(model)
	local agent = agentFor(model)

	-- Sur son point, tourné vers le suivant ; à côté si un autre vigile de nuit y est déjà.
	local start = points[startIndex]
	local direction = if startIndex < #points then 1 else -1
	local towards = points[startIndex + direction] or start
	local look = flat(towards - start)
	local frame = if look.Magnitude > 1e-3 then CFrame.lookAt(start, start + look.Unit) else CFrame.new(start)
	for _, other in nightGuards do
		if flat(other.root.Position - frame.Position).Magnitude < SPAWN_SPACING * 0.9 then
			frame += frame.RightVector * SPAWN_SPACING
		end
	end
	local rootHeight = humanoid.HipHeight + root.Size.Y / 2
	local offset = model:GetPivot():ToObjectSpace(root.CFrame)
	model:PivotTo(frame * CFrame.new(0, rootHeight, 0) * offset:Inverse())

	model:SetAttribute(TARGET_ATTRIBUTE, 0)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer -- Atomic pour les autres
	end)
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = Night.PatrolSpeed
	if fallback then
		addFlashlight(model, root)
	end
	model.Parent = getActiveFolder()
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
	local now = os.clock()
	local guard: Guard = {
		model = model,
		humanoid = humanoid,
		root = root,
		rootHeight = rootHeight,
		scale = scale,
		anims = AnimPlayer.new(animator :: Animator, AnimPlayer.modelFolder(model), Animations.NightGuard, ANIM_LABEL),
		kind = "Night",
		label = `vigile de nuit {model.Name}`,
		store = nil,
		home = start,
		zone = zone,
		speed = Zones[zone].AdvisedSpeed + Night.ChaseSpeedBonus,
		target = nil,
		state = "Patrol",
		spawnedAt = now,
		chaseStartedAt = now,
		patrol = points,
		patrolIndex = startIndex,
		patrolStep = direction,
		pauseUntil = 0,
		onKnock = nil,
		nextScanAt = now,
		stateEndsAt = now,
		returnedAt = now,
		nextSteerAt = now,
		nextPathAt = now,
		path = PathfindingService:CreatePath(agent),
		pathToken = 0,
		computing = false,
		waypoints = nil,
		waypointIndex = 2,
		progressPos = root.Position,
		progressAt = now,
		knockTarget = nil,
		followPayload = nil,
		followPosition = Vector3.zero,
		agentRadius = agent.AgentRadius,
		pathFailures = 0,
		returnTo = "Reserve",
		returnGoal = start,
		doorSpot = nil,
		doorStep = nil,
		noPathSince = 0,
		fadeStartedAt = 0,
		fadeReason = "",
		fadeParts = {},
		fadeDecals = {},
		connections = {},
		alive = true,
	}
	table.insert(guard.connections, humanoid.Died:Connect(function()
		despawn(guard, "mort")
	end))
	for _, entry in MarkerSounds.Guard do
		guard.anims:OnMarker(entry.Anim, entry.Marker, function()
			MarkerSounds.play(entry.Sound, guard.root)
		end)
	end
	guard.anims:OnMarker("Catch", CATCH_MARKER, function()
		releaseKnockback(guard)
	end)
	guard.anims:Play("Idle")
	table.insert(nightGuards, guard)
	startPatrol(guard, now)
	log(`{guard.label} ({label}) en ronde, zone {zone}, {#points} point(s), poursuite à {Format.short(guard.speed)}, {sizeText(scale, agent)}`)
end

-- Colis tombé au sol (6.2) ----------------------------------------------------------------------

-- Le colis de la cible du vigile vient de tomber à `position` (coup de batte) : il le suit.
local function followDrop(guard: Guard, payload: any, position: Vector3)
	local player = guard.target
	endChase(guard)
	local now = os.clock()
	setState(guard, "Follow")
	guard.followPayload = payload
	guard.followPosition = position
	following[payload] = guard
	guard.stateEndsAt = now + Bat.DroppedLifetime + FOLLOW_MARGIN
	guard.nextSteerAt = now
	guard.nextPathAt = now
	guard.anims:Stop("Walk")
	setWalkSpeed(guard, guard.speed) -- encore à 0 s'il ne s'était pas élancé (Wait)
	log(`{guard.label} : le colis de {if player then player.Name else "?"} est tombé au sol, il va vers lui`)
end

-- Le colis que suit le vigile vient d'être ramassé par `player` : nouvelle poursuite, comme un
-- vigile qui vient d'apparaître (Wait : REACTION_DELAY s sans capture, puis Chase).
local function retarget(guard: Guard, player: Player)
	local other = chasedBy[player]
	if other and other ~= guard then
		giveUp(other, "cible reprise par le vigile du colis ramassé")
	end
	releaseFollow(guard)
	local now = os.clock()
	guard.target = player
	chasedBy[player] = guard
	guard.model:SetAttribute(TARGET_ATTRIBUTE, player.UserId)
	pcall(function()
		guard.model:AddPersistentPlayer(player)
	end)
	setState(guard, "Wait")
	stop(guard)
	guard.anims:Stop("Run")
	guard.speed = chaseSpeed(player, guard.zone)
	guard.chaseStartedAt = now
	guard.stateEndsAt = now + REACTION_DELAY
	refreshChaseState(player)
	log(`{guard.label} : change de cible, poursuit {player.Name} qui a ramassé le colis (vitesse {Format.short(guard.speed)})`)
end

local function onCarryStarted(player: Player, payload: any)
	if type(payload) ~= "table" or payload.Kind ~= "NPCBox" then
		return -- seuls les colis PNJ ont un vigile (5.5)
	end
	if droppedPayloads[payload] then
		-- Ramassé au sol (6.2) : le vigile qui suivait ce colis change de cible ; sans lui, aucun
		-- vigile (il n'apparaît qu'à la prise sur le rayon).
		droppedPayloads[payload] = nil
		local guard = following[payload]
		if guard and guard.alive and guard.state == "Follow" then
			retarget(guard, player)
		else
			log(`{player.Name} ramasse un colis tombé au sol : aucun vigile ne le suivait`)
		end
		return
	end
	if type(payload.StoreId) == "string" and string.sub(payload.StoreId, 1, 6) == "Truck_" then
		return -- colis du camion (TruckEventService, StoreId « Truck_<n> ») : pas de magasin, pas de vigile
	end
	-- Hors de l'appel de CarryService : le rig de remplacement peut demander d'attendre.
	task.spawn(function()
		local storeId = payload.StoreId
		local store = if type(storeId) == "string" then findStore(storeId) else nil
		if store == nil then
			warn(`[GuardService] magasin « {storeId} » du colis de {player.Name} introuvable : pas de vigile`)
			return
		end
		local zone = payload.Zone
		if type(zone) ~= "number" or Zones[zone] == nil then
			zone = store:GetAttribute("Zone")
		end
		if type(zone) ~= "number" or Zones[zone] == nil then
			warn(`[GuardService] zone du colis de {player.Name} inconnue ({payload.Zone}) : pas de vigile`)
			return
		end
		local template = findTemplate(zone)
		if template and not isUsable(template) then
			warnOnce(
				`bad:{template:GetFullName()}`,
				`{template:GetFullName()} : Humanoid ou HumanoidRootPart manquant (10.4), rig de remplacement utilisé`
			)
			template = nil
		end
		local label = if template then template:GetFullName() else FALLBACK_NAME
		if template == nil then
			template = getFallback()
		end
		-- Revérifié après une éventuelle attente.
		if template == nil or player.Parent ~= Players or not CarryService.IsCarrying(player) then
			return
		end
		local ok, err = pcall(spawnGuard :: any, player, store, zone, template, label)
		if not ok then
			warn(`[GuardService] vigile de {player.Name} non créé : {err}`)
		end
	end)
end

local function onCarryEnded(player: Player, payload: any, result: string, reason: string)
	local dropped = result == "Dropped" and type(payload) == "table"
	if dropped then
		droppedPayloads[payload] = true -- au sol jusqu'à sa prise (onCarryStarted) ou sa fin
	end
	local guard = chasedBy[player]
	if guard == nil then
		return
	end
	if dropped and (guard.state == "Wait" or guard.state == "Chase") then
		-- Appelé pendant CarryService.Drop : la cible est encore à l'endroit du coup.
		local root = bodyOf(player)
		followDrop(guard, payload, if root then root.Position else guard.root.Position)
		return
	end
	giveUp(guard, `portage fini : {result} ({reason})`)
end

-- Colis resté au sol sans preneur (6.2) : il revole vers son rayon, le vigile qui le suivait abandonne.
local function onDropExpired(_dropId: string, payload: any, _position: Vector3)
	if type(payload) ~= "table" then
		return
	end
	droppedPayloads[payload] = nil
	local guard = following[payload]
	if guard then
		giveUp(guard, "colis resté au sol, reparti vers son rayon")
	end
end

-- API ---------------------------------------------------------------------------------------

-- Le magasin peut se rouvrir (vu en Play par Ironix le 2026-11-08 : la vitrine se reconstruisait et
-- le rideau remontait pendant que le vigile rentrait de loin ; un nouveau vol faisait apparaître un
-- 2e vigile) : aucun vigile de jour de ce magasin encore en jeu (poursuite, retour ou fondu), et le
-- dernier parti depuis au moins Balance.Guard.ReopenAfterReturn s.
function GuardService.StoreReadyToReopen(store: Model): boolean
	for _, guard in guards do
		if guard.alive and guard.store == store then
			return false
		end
	end
	local gone = lastGoneAt[store]
	local delay = Balance.Guard.ReopenAfterReturn
	if gone and type(delay) == "number" and os.clock() - gone < delay then
		return false
	end
	return true
end

function GuardService.IsChased(player: Player): boolean
	return chasedBy[player] ~= nil
end

function GuardService.GetGuard(player: Player): Model?
	local guard = chasedBy[player]
	return if guard then guard.model else nil
end

function GuardService.OnCatch(listener: CatchListener): () -> ()
	table.insert(catchListeners, listener)
	return function()
		local index = table.find(catchListeners, listener)
		if index then
			table.remove(catchListeners, index)
		end
	end
end

function GuardService.GetSpeedOverride(_player: Player, _zone: number): number?
	return nil
end

function GuardService.IsNightChased(player: Player): boolean
	return nightChasedBy[player] ~= nil
end

function GuardService.StopNightPatrol(): number
	nightToken += 1
	nightHooks = nil
	local count = #nightGuards
	for _, guard in table.clone(nightGuards) do
		despawn(guard, "aube")
	end
	return count
end

function GuardService.StartNightPatrol(hooks: NightHooks): number
	GuardService.StopNightPatrol()
	nightHooks = hooks
	local token = nightToken
	local points = patrolPoints()
	type Plan = { zone: number, number: number, start: number }
	local plans: { Plan } = {}
	local perZone = math.max(math.floor(Night.GuardsPerZone), 0)
	for zone = 1, #Zones do
		local list = points[zone]
		if list == nil or #list == 0 then
			warnOnce(`nopatrol:{zone}`, `zone {zone} : aucun point de ronde (tag {NIGHT_PATROL_TAG}, attribut Zone), pas de vigile de nuit`)
		else
			for number = 1, perZone do
				-- Le 1er au 1er point, les suivants répartis le long de la liste.
				table.insert(plans, { zone = zone, number = number, start = 1 + ((number - 1) * #list) // perZone })
			end
		end
	end
	-- Hors de l'appel : le rig de remplacement peut demander d'attendre.
	task.spawn(function()
		for _, plan in plans do
			if nightToken ~= token then
				return -- l'aube est passée entre-temps
			end
			local template, label, fallback = nightTemplate(plan.zone)
			if nightToken ~= token then
				return
			end
			if template == nil then
				warnOnce("nighttemplate", "aucun modèle de vigile de nuit ni rig de remplacement : pas de vigile de nuit")
				return
			end
			local list = points[plan.zone]
			local ok, err = pcall(spawnNightGuard :: any, plan.zone, plan.number, list, plan.start, template, label, fallback)
			if not ok then
				warn(`[GuardService] vigile de nuit {plan.number} de la zone {plan.zone} non créé : {err}`)
			end
		end
	end)
	return #plans
end

function GuardService.Start()
	-- La reconstruction d'une vitrine de magasin attend le retour de ses vigiles (StoreReadyToReopen).
	-- require au démarrage et protégé : sans WindowService (bancs), le vigile marche comme avant.
	local okWindow, windowApi = pcall(function(): any
		return require(script.Parent.WindowService) :: any
	end)
	local WindowService: any = if okWindow then windowApi else nil
	if WindowService then
		pcall(WindowService.AddRebuildGate, function(_windowId: string, model: Model?): boolean
			if model == nil or not model:HasTag("NPCStore") then
				return true
			end
			return GuardService.StoreReadyToReopen(model)
		end)
	end
	CarryService.OnCarryStarted(onCarryStarted)
	CarryService.OnCarryEnded(onCarryEnded)
	CarryService.OnDropExpired(onDropExpired)
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player: Player)
		local guard = chasedBy[player]
		if guard then
			giveUp(guard, "départ du joueur")
		end
		local nightGuard = nightChasedBy[player]
		if nightGuard then
			giveUp(nightGuard, "départ du joueur")
		end
		stunTokens[player] = nil
		chaseSent[player] = nil
		caughtAtNight[player] = nil
	end)
	-- Prépare le rig de remplacement dès le démarrage : le premier vigile apparaît sans attendre.
	task.spawn(getFallback)
end

return GuardService
