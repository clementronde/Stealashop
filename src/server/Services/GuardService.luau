--!strict
-- GuardService (DEV-018) : vigile de jour des magasins PNJ, de l'apparition à l'abandon
-- (Partie 1, sections 4, 5.5 et 9.7 ; animations : 2.4 et liaison 3.2).
--
-- Déroulé d'un vigile :
--   1. Apparition. Règle de Clément (L-118) : à la fin du chrono du magasin,
--      StoreHeistService appelle ChaseIntruder pour chaque intrus ; le vigile sort du GuardSpawn et le
--      poursuit, qu'il porte un objet ou non (a241, Config/Chase.ChaseOnEmptyExit : aussi dès qu'un intrus ressort
--      sans objet avant la fin du chrono, même poursuite d'intrus) (pas d'abandon parce qu'il ne porte rien). Et (Cantin,
--      2026-11-13, a114, revient en partie sur L-118) : la PRISE d'un objet sorti sur le rayon (NPCItem)
--      fait sortir tout de suite un vigile pour le preneur, comme un colis (mêmes plafonds), lié à cet
--      objet (voir « Objet lié » plus bas). Ouvrir un colis ne déclenche rien. Ancien déroulé (colis porté fermé) :
--      quand CarryService commence le portage d'un colis PNJ (OnCarryStarted,
--      payload.Kind = "NPCBox"), un vigile apparaît au GuardSpawn du magasin du colis
--      (payload.StoreId). Un vigile par voleur ; au plus Balance.Guard.MaxPerStore en poursuite
--      par magasin et Balance.Guard.MaxActivePerServer en jeu sur le serveur (9.7) : au
--      plafond, un vigile qui rentre s'efface (fondu, point 5) pour laisser sa place ; sans vigile
--      qui rentre, pas de vigile. Un vigile en fondu ne compte plus dans ces plafonds. Le serveur
--      possède sa physique ; nage, escalade et autres états inutiles sont coupés (9.7).
--   2. Poursuite, après REACTION_DELAY s. Nouvelle règle (Cantin, 2026-11-14, vague 45 ; Features.GuardChaseV2,
--      Config/Chase ; vigile de nuit, policier et conducteur aussi, avec leur propre minimum, voir
--      Config/Chase) : ruée droit sur le voleur à
--      Chase.RushWalkFactor × sa marche (au moins Chase.RushMinSpeed) jusqu'à Chase.HoldDistance studs à
--      l'horizontale, puis la marche que le serveur lui donne (Humanoid.WalkSpeed, colis compris) + un
--      rapprochement Chase.ClosingSpeedMax × (1 − Speed effective (Speed × trail) / SpeedRequired de la zone), borné ; à 100 %
--      du minimum, la distance ne bouge pas tant qu'il court tout droit (Chase.AboveRequired au-dessus).
--      Recalculée à chaque image (distanceRuleStep). Tutoriel (GetSpeedOverride) ou règle coupée : l'ancienne,
--      WalkSpeed = Zones[zone].GuardSpeed (section 4), fixe. Le reste (interception, chemins) est commun,
--      sauf pendant la ruée, qui vise le voleur lui-même et non un point devant lui.
--      a249 (Cantin, 2026-11-17, L-235) : le vigile du magasin part Chase.StartDelay s après la prise (apparition,
--      objet ramassé) et après la cinématique d'ouverture (Chase.WaitAfterReveal) ; Chase.SpringReturn : plus de
--      ruée pour lui, un retour doux, au plus Chase.SpringMaxFactor × la marche du voleur (springSpeed) ;
--      Chase.OneCatchAtATime : un joueur déjà attrapé n'est plus poursuivi par les autres.
--      Il coupe la route du joueur (Cantin, 2026-11-11, vague 24) : il vise le point d'interception,
--      là où, en ligne droite à sa WalkSpeed, il retrouve le joueur qui garde sa vitesse au sol lissée
--      (VELOCITY_SMOOTHING : un zigzag ne le fait presque pas zigzaguer), au plus INTERCEPT_MAX_TIME s
--      devant lui ; jamais derrière un mur ni en zone safe ; sans solution, le joueur lui-même. Ligne
--      de vue testée toutes les CHASE_STEER_INTERVAL s (L-091 point 1). S'il voit le joueur : MoveTo
--      droit sur ce point, recalculé toutes les CHASE_REAIM_INTERVAL s (0,1), redonné seulement s'il
--      bouge d'AIM_MIN_CHANGE studs, et tout chemin en cours est jeté. Derrière un obstacle seulement :
--      PathfindingService vers ce point, recalculé dès qu'il s'éloigne du but du chemin
--      (PATH_GOAL_DRIFT), au plus toutes les Balance.Guard.PathRecomputeInterval s ; un chemin qui
--      arrive reprend au point le plus proche du vigile, jamais derrière lui. Même poursuite de jour,
--      de nuit et pour les conducteurs. Les 1 à 2 s de retard vus en Play (Cantin, 2026-11-11) : le
--      point visé était la position du joueur, gardée jusqu'à 0,25 s ; près du vigile, un joueur qui
--      passe derrière lui avait déjà bougé de 4 à 6 studs, le vigile courait à un point vide puis le
--      suivait de dos (plus lent que lui, il ne rattrapait jamais son retard).
--      a193 (Cantin, 2026-11-15, T-069) : distance gardée, point visé et capture se mesurent sur la position
--      estimée du voleur (position reçue + vitesse × retard du réseau, estimatedPosition, Config/Chase
--      LagCompensation), plus sur la position que le serveur reçoit en retard.
--   3. Capture : distance ≤ Balance.Guard.CatchDistance entre les deux HumanoidRootPart, sans
--      mur entre eux, mesurée ici, côté serveur (a146, audit du 2026-11-14, shared/CatchReach : à
--      l'horizontale, avec AntiCheat.CatchVerticalReach studs d'écart en hauteur au plus ; sans mur, ou
--      perché sur un meuble bas, ou le HumanoidRootPart dans une pièce). Alors, tout de suite :
--      CarryService.Fail(player, "Caught") (le colis revole vers son rayon), joueur immobilisé (StatsService, modificateur
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
--   4. Abandon : seulement quand le joueur entre en zone safe (tag SafeZone), ou quand le portage
--      finit autrement (OnCarryEnded : colis posé, mort, départ…). Poursuite sans fin (Cantin,
--      2026-11-11) : plus d'abandon au bout d'un temps de poursuite ni pour l'avance prise, de jour,
--      de nuit et pour les conducteurs du camion. Seule exception (Cantin, 2026-11-13) : l'intrus resté
--      sans objet à la fin du chrono (ChaseIntruder) n'est poursuivi que Balance.Guard.IntruderChaseTime s
--      (10) ; s'il prend un objet pendant ce temps, la poursuite redevient sans fin. Le vigile s'arrête essoufflé (Tired, 5.5), puis rentre en
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
--     d'attente sans capture, puis poursuite neuve (vitesse de la zone pour ce joueur) avec les
--     mêmes règles d'abandon (point 4) et la même capture. Ramassé par un joueur déjà poursuivi par un autre vigile :
--     cet autre vigile abandonne.
--   - Personne ne le ramasse (OnDropExpired, 6.2 : 15 s, le colis revole vers son rayon), ou rien
--     au bout de Bat.DroppedLifetime + FOLLOW_MARGIN s : le vigile abandonne (Tired, puis retour).
--   - Un colis ramassé au sol alors qu'aucun vigile ne le suivait (vigile déjà reparti, ou aucun
--     vigile à l'origine) ne fait apparaître aucun vigile : il n'apparaît qu'à la prise sur le rayon.
--     Sauf un objet lié (a114, plus bas) : son vigile fait demi-tour, ou un autre ressort.
--   - Les vigiles de nuit ne suivent pas les colis : ils poursuivent toute personne dans le couloir.
--
-- Objet lié (Cantin, 2026-11-13, a114) : un objet sorti d'un colis d'un magasin PNJ
-- (payload NPCItem ; jamais le camion, un objet volé à un joueur, un colis de l'ancien déroulé) est lié au
-- vigile de jour sorti à sa prise sur le rayon (ou, si le preneur était déjà poursuivi par un vigile de
-- jour, à celui-là), puis au vigile de jour qui poursuit son porteur. Ce vigile s'en occupe jusqu'à ce que
-- l'objet revole vers son rayon (OnDropExpired, ou échec sans chute) ou soit rangé en base (Consumed) :
--   - lâché (touche G) ou tombé (batte) : Follow, comme plus haut ;
--   - porteur attrapé (l'objet tombe, CarryService.Fail « Caught ») : à la fin de Catch, le vigile garde
--     l'objet tombé comme après un lâcher (Follow, à l'endroit de la capture ; Cantin, 2026-11-13 : « à chaque
--     fois qu'un objet est posé au sol, le vigile doit être à côté de lui pour le garder » jusqu'à ce qu'il
--     revole vers son rayon, puis il rentre). Repris pendant qu'il est au sol, par n'importe qui (celui qu'il
--     vient d'attraper compris, une fois son étourdissement fini) : ce vigile repart (retarget :
--     REACTION_DELAY s, puis vitesse de la zone pour le nouveau porteur). Repris pendant Catch : il part à
--     la fin de Catch. Rentré ou en fondu quand on le reprend (cas d'un objet qui revole puis…) : demi-tour,
--     dans la limite de Balance.Guard.MaxPerStore (il recompte dans les poursuites) ;
--   - porteur attrapé dans le magasin d'où vient l'objet (son HumanoidRootPart dans le volume Bounds de ce
--     magasin ; Cantin, 2026-11-13 : sinon le vigile le garderait dedans et le magasin resterait ouvert) :
--     l'objet ne tombe pas, il revole tout de suite vers son rayon (CarryService.FailNoDrop « Caught » :
--     échec sans chute) ; le lien finit, le vigile rentre au GuardSpawn à la fin de Catch et le
--     magasin se referme comme d'habitude ;
--   - objet lâché ou tombé dans ce même volume (touche G, coup de batte, capture par un autre ; Clément,
--     2026-11-14, L-135 point 5) : pareil, il revole tout de suite vers son rayon (CarryService
--     .SetBackToShelfCheck, posé au Start avec la même règle) ; le vigile abandonne (portage « Failed »).
--     Dans la rue, rien ne change : l'objet tombe et le vigile le garde ;
--   - vigile déjà parti (rentré, en fondu, mort) ou occupé à poursuivre un autre joueur : un vigile du même
--     magasin ressort du GuardSpawn pour le nouveau porteur (mêmes plafonds) ; nouveau porteur déjà
--     poursuivi par un vigile de jour : c'est lui qui devient lié (jamais deux vigiles pour un joueur).
-- Les vigiles de nuit, les policiers et les conducteurs du camion ne se lient jamais.
-- Troisième capture (Cantin, 2026-11-15, a174) : chaque capture d'un porteur d'objet NPCItem (vigile de jour,
-- vigile de nuit, policier, conducteur du camion) compte pour CET objet (son payload, la même table d'un porteur
-- à l'autre, CarryService.PickUpDrop). À la Chase.ReturnToShelfAfterCatches-ième, l'objet ne tombe pas : il
-- revole tel quel sur son rayon (CarryService.FailNoDrop « Caught », comme une capture dans son magasin ;
-- StoreHeistService le pose sur un autre rayon libre du magasin si le sien est pris). Le compteur s'efface quand
-- le portage finit sans chute (rangé en zone safe, revenu au rayon) ou quand l'objet resté au sol revole.
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
--     poursuite à Night.ChaseSpeed (80, plus vite qu'un joueur sans potion, L-108), au moins
--     Zones[zone].AdvisedSpeed + Night.ChaseSpeedBonus, avec ou sans colis. Avec Features.GuardChaseV2 et
--     Chase.Apply.NightGuard (vague 45) : ruée, puis rapprochement sur un minimum de 2 × sa Speed (Config/Chase).
--   - Abandon : comme le jour (zone safe ; ni temps ni avance), et aussi quand la cible quitte le
--     couloir (passée à travers le mur de nuit), devient ignorée ou n'a plus de personnage. Puis essoufflé, il retourne au point de
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
-- modèle), bornée de 0,6 à 1,6 (nuit : Night.GaitSpeedMax), et remise à jour à chaque
-- changement de WalkSpeed (setWalkSpeed).
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
-- Envoyé au joueur attrapé (vague 59, a192, L-184 point 1) : remote CatchScene(night, outcome, homeIn, itemId?) au
-- coup (en même temps que la poussée ; arrestation de nuit : à son début), pour la mise en scène côté client
-- (CatchSceneController). outcome = "Shelf" (l'objet revole sur son rayon), "Drop" (il tombe, ou est perdu) ou
-- "None" ; homeIn = secondes avant le renvoi à la base (nuit, policier), 0 sinon. Aucune règle de jeu ne change.
-- a252 (L-244, L-245) : 6e argument `by`, le modèle de celui qui attrape (plan large de la caméra). Capture par le vigile
-- d'un magasin dont l'objet revole : il passe d'abord par la main du vigile (Guard/CatchPickUp, Chase.CatchPickUp) ; la
-- nuit, dans le couloir, ce joueur est renvoyé à sa boutique (Chase.DayCatchAtNightSendsHome).
--
-- API (serveur) :
--   GuardService.ChaseIntruder(player, store) -> boolean
--       L-118 : un vigile de jour de `store` (le Model du magasin) sort et poursuit `player`, avec ou sans
--       portage (mêmes plafonds, même capture, même retour). false : hors jeu, en zone safe, déjà poursuivi
--       par un vigile de jour (celui sorti à la prise d'un objet, par exemple : pas de second vigile),
--       plafond atteint ou magasin sans Zone.
--   GuardService.GetLinkedGuard(payload) -> Model?   a114 : le vigile lié à cet objet (NPCItem), s'il est en jeu
--   GuardService.IsChased(player) -> boolean
--   GuardService.IsStunned(player) -> boolean   étourdi par une capture (vigile, police, conducteur, nuit) ; a113
--   GuardService.GetGuard(player) -> Model?    le vigile qui poursuit ce joueur
--   GuardService.GetReturningGuards(store) -> { BasePart }
--       HumanoidRootPart des vigiles de jour de ce magasin (Model) qui rentrent vers sa réserve, à
--       travers le magasin (Return, but « Reserve »). Pour le rideau local de StoreHeistService.
--   GuardService.OnCatch(listener) -> déconnexion
--       listener(player, zone, night, carrying) à chaque capture, de jour ou de nuit, juste avant
--       que le portage soit perdu : carrying = il portait quelque chose. TelemetryService s'en sert
--       pour les captures de nuit sans colis (celles avec colis passent par OnCarryEnded).
--   GuardService.OnGuardGone(listener) -> déconnexion
--       listener(thief, store) quand le vigile de jour apparu pour le vol de `thief` dans `store`
--       (le Model du magasin) a quitté le jeu : rentré et effacé, ou retiré (mort, erreur). Même s'il
--       poursuivait quelqu'un d'autre entre-temps (colis tombé, ramassé). StoreHeistService s'en sert
--       pour rouvrir le magasin au voleur (fermeture locale, Cantin 2026-11-11).
--   GuardService.GetSpeedOverride(player, zone) -> number?
--       Point d'accroche du tutoriel (5.11, vigile lent : Config.Tutorial.GuardSpeed). Renvoie
--       nil ici : la vitesse de la zone s'applique. TutorialService le remplace
--       (GuardService.GetSpeedOverride = function(player, zone) ... end). Une valeur qui n'est
--       pas un nombre fini > 0, ou une erreur, compte pour nil. Vague 61 (a198) : la valeur rendue est à
--       l'échelle 1, multipliée ici (et par WitnessService pour le policier) par Balance.Stats.RealSpeedScale.
--   GuardService.IsHiddenFromNight(player) -> boolean
--       Point d'accroche des potions (vague 28, L-085 : Invisibility) : renvoie false ici. PotionService le
--       remplace en gardant celui d'avant. true = les vigiles de nuit ne repèrent pas ce joueur (scan) ; un
--       vigile de nuit qui le poursuit déjà continue. Une erreur compte pour false.
--   GuardService.StartNightPatrol(hooks) -> number
--       Lance les vigiles de nuit (voir plus haut), sans attendre, un par image (a229) ; renvoie le nombre prévu. hooks
--       (NightCycleService) : InCorridor(position) -> boolean, Ignores(player) -> boolean,
--       SendHome(player) -> boolean (peut attendre). Déjà lancés : les anciens partent d'abord.
--   GuardService.StopNightPatrol() -> number    retire les vigiles de nuit, renvoie leur nombre
--   GuardService.IsNightChased(player) -> boolean   poursuivi par un vigile de nuit
--   GuardService.StartDriverChase(chase) -> Model?
--       Conducteur du camion (liaison L-083 point 3, TruckEventService) : lance tout de suite une
--       poursuite avec une copie de chase.Template (jamais le modèle de Clément), pieds sur
--       chase.Spawn, sur chase.Target. Renvoie la copie, ou nil (cible déjà poursuivie par un
--       conducteur, sans personnage, modèle sans Humanoid ou HumanoidRootPart). Voir plus bas.
--   GuardService.IsInSafeZone(position) -> boolean        dans une zone safe (tag SafeZone)
--   GuardService.FindGuardModel(name) -> Model?           un modèle du dossier Guards de Clément
--
-- Conducteurs du camion (kind « Driver », L-083 point 3) : même poursuite, même capture et même coup
-- que le vigile de jour (chemin, ligne de vue, Balance.Guard.CatchDistance, poussée au marqueur Impact
-- de Catch, étourdi Balance.Guard.CatchStunDuration s, CarryService.Fail(…, "Caught") : le colis du
-- camion est perdu, il n'a pas de rayon où revenir). Ce qui change :
--   - vitesse : la WalkSpeed actuelle de sa cible × chase.SpeedMultiplier, au moins chase.MinSpeed,
--     relue à chaque pas de pilotage : il court toujours un peu plus vite qu'elle. Avec Features.GuardChaseV2
--     (vague 45, Config/Chase) : ruée, puis la marche de sa cible × 1 + 2 %/s (conducteur, Apply.TruckDriver)
--     ou rapprochement sur un minimum de 2 × sa Speed (policier, Apply.Police) ;
--   - abandon : la cible ne vaut plus la poursuite (chase.Keeps(player) faux : elle ne porte plus le
--     colis du camion, par exemple rangé dans l'inventaire à l'entrée de la zone safe), la zone safe,
--     ou plus de personnage. Ni au bout d'un temps, ni pour l'avance prise (point 4) ;
--   - après la capture ou l'abandon, il ne rentre nulle part : il s'efface en fondu là où il est
--     (Balance.Guard.ReturnFadeTime), sans Tired (pas à son contrat) ;
--   - animations Animations.Driver (Idle, Walk, Run, Catch) ; hors des plafonds des vigiles de jour (9.7) ;
--   - le joueur reçoit ChaseState comme pour un vigile (UI_Chase, MUS_Chase), et chase.CaughtMessage
--     à la capture.
--
-- Policier appelé par un témoin (L-111, WitnessService) : la même poursuite que les conducteurs, lancée
-- par StartDriverChase avec les champs facultatifs de DriverChase : Label (« policier », pour la sortie),
-- Tired (true : il s'essouffle comme un vigile, animations du contrat des vigiles, avant de s'effacer) et
-- GiveUpReason (pour la sortie). Un seul poursuivant de cette famille par joueur (conducteur ou policier).

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
local Chase = require(Shared.Config.Chase)
local Features = require(Shared.Config.Features)
local Night = require(Shared.Config.Night)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local CatchReach = require(Shared.CatchReach)
local SafeZone = require(Shared.SafeZone)
-- Vague 62 (Features.SingleBoxReveal) : ouvreur protégé pendant sa cinématique, attribut RevealProtected du Player
-- posé par StoreHeistService (contrat : Shared/ShelfOpenState.ProtectedAttribute). Lu ici sans require : les faux
-- arbres de bancs plus anciens n'ont pas les modules partagés de la vague 62.
local RevealState = {}
function RevealState.IsProtected(player: any): boolean
	local ok, value = pcall(function(): any
		return player:GetAttribute("RevealProtected")
	end)
	return ok and value == true
end
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
	FailNoDrop: (player: Player, reason: string) -> boolean,
	OnCarryStarted: (listener: (player: Player, payload: any) -> ()) -> any,
	OnCarryEnded: (listener: (player: Player, payload: any, result: string, reason: string) -> ()) -> any,
	OnDropExpired: (listener: (dropId: string, payload: any, position: Vector3) -> ()) -> any,
	GetPayload: (player: Player) -> any,
	SetBackToShelfCheck: ((check: ((player: Player) -> boolean)?) -> ())?,
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

-- Day : vigile de jour d'un magasin (5.5) ; Night : vigile de nuit (5.12) ; Driver : conducteur du
-- camion (L-083 point 3).
type GuardKind = "Day" | "Night" | "Driver"

-- Poursuite d'un conducteur du camion, donnée par TruckEventService à StartDriverChase.
export type DriverChase = {
	Template: Model, -- le conducteur de Clément (copié ici, jamais modifié)
	Name: string, -- nom de la copie en jeu
	Target: Player,
	Spawn: CFrame, -- ses pieds à l'apparition, tourné comme ce repère
	Zone: number, -- zone du camion (OnCatch)
	SpeedMultiplier: number, -- × la WalkSpeed actuelle de la cible
	MinSpeed: number,
	Keeps: (player: Player) -> boolean, -- la cible vaut encore la poursuite
	CaughtMessage: string?, -- Notify au joueur attrapé
	-- Policier appelé par un témoin (L-111, WitnessService), facultatifs : sans eux, un conducteur du camion.
	Label: string?, -- nom dans la sortie et les avertissements d'animation (« policier ») ; défaut « conducteur »
	Tired: boolean?, -- true : essoufflé (Tired, contrat des vigiles) avant de s'effacer quand il abandonne
	GiveUpReason: string?, -- pour la sortie, quand Keeps devient faux
	-- Policier (L-118 point 3) : renvoie le joueur attrapé à la base, Night.SendHomeDelay s après le coup.
	SendHome: ((player: Player) -> boolean)?,
}

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
	speed: number, -- WalkSpeed de poursuite (ancienne règle ; et Follow)
	-- Nouvelle poursuite (Features.GuardChaseV2, Config/Chase) : "Rush" (ruée), puis "Hold" (distance gardée) ;
	-- nil : ancienne règle, ou hors poursuite. Décidé à chaque départ de poursuite (startChase).
	chasePhase: ("Rush" | "Hold")?,
	holdSince: number?, -- fin de la ruée (conducteur du camion : sa vitesse grandit depuis)
	rushStepAt: number?, -- a168 : dernier pas de la ruée (durée d'image, pour anticiper sa fin)
	holdTarget: number?, -- a173 : distance prévue de la poursuite à distance (studs), rappel vers elle
	holdStepAt: number?, -- a173 : dernier pas de la poursuite à distance
	stuckFrom: Vector3?, -- a249 (Chase.StuckCatch) : position de la cible sur le serveur quand elle a bougé pour la dernière fois
	stuckSince: number?, -- a249 : depuis quand elle n'a pas bougé de Chase.StuckMoveMax studs à l'horizontale
	standingStill: boolean?, -- a249 : elle n'avance plus depuis Chase.StuckCatchTime s (stuckCatchable) : approachCap la traite comme arrêtée
	seenStill: boolean?, -- a250b : vu arrêté depuis son dernier mouvement (chaseInSight) : approachCap ne prend plus ApproachBrakeHidden
	stillCap: number?, -- a250b : plafond d'arrivée sur un voleur arrêté (approachCap) : il ne remonte pas tant qu'il reste arrêté
	blockedFrom: Vector3?, -- a249b : position du vigile quand il a bougé pour la dernière fois (même règle, pour lui)
	blockedSince: number?, -- a249b : depuis quand il n'a pas bougé de Chase.StuckMoveMax studs à l'horizontale
	blockedTrail: { { at: number, position: Vector3 } }?, -- a250 (Chase.StuckProgressShare) : ses positions des dernières StuckCatchTime s
	target: Player?, -- joueur poursuivi, nil hors poursuite
	state: GuardState,
	spawnedAt: number,
	owner: Player?, -- vigile de jour : le voleur pour qui il est apparu (OnGuardGone) ; nil sinon
	intruder: boolean?, -- vigile de jour sorti à la fin du chrono (L-118, ChaseIntruder) : poursuit même sans portage
	intruderUntil: number?, -- intrus sans objet : fin de sa poursuite (Balance.Guard.IntruderChaseTime), posée au 1er pas
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
	pathGoal: Vector3?, -- but du dernier calcul de chemin lancé (L-091 point 1)
	lastSeen: Vector3?, -- poursuite : où il a vu sa cible pour la dernière fois (L-091 point 1)
	chaseAim: Vector3?, -- poursuite en vue : le dernier point donné à MoveTo (interception), nil hors de vue
	chaseAimAt: number?, -- poursuite en vue : quand ce MoveTo a été donné
	nextAimAt: number, -- poursuite en vue : prochain calcul du point d'interception
	chaseVelocity: Vector3?, -- poursuite : vitesse au sol de la cible, lissée (sampleVelocity)
	chaseVelocityAt: number?, -- poursuite : instant de la dernière mesure de cette vitesse
	progressPos: Vector3,
	progressAt: number,
	patrolStepAt: number?, -- a173 : dernier pas de la ronde de nuit (image trop longue : progressAt décalé)
	knockTarget: Player?, -- joueur à projeter au marqueur Impact de Catch
	followPayload: any?, -- Follow : le payload du colis tombé au sol que le vigile suit
	followPosition: Vector3, -- Follow : où il est tombé (là où était la cible au coup)
	followOwner: Player?, -- a231 : porteur attrapé, gardé pour le journal (la cible est déjà vide après Catch)
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
	driver: DriverChase?, -- conducteur du camion : sa poursuite ; nil pour un vigile
	revealFrozenAt: number?, -- vague 62 : figé depuis (os.clock()) : sa cible est dans sa cinématique d'ouverture
}

-- Noms du contrat (2.1, 10.4) lus ici.
local STORE_TAG = "NPCStore"
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
-- V0 proposé, absent du doc : une poursuite qui réagit tout de suite (L-091 point 1).
local CHASE_STEER_INTERVAL = 0.05 -- poursuite : ligne de vue à ce rythme (s)
-- V0 proposé, absent du doc (Cantin, 2026-11-11 : il doit nous COUPER la route, tout de suite et sans
-- à-coups, sans recopier nos zigzags) : interception en ligne de vue (chaseInSight).
local CHASE_REAIM_INTERVAL = 0.1 -- en vue : point d'interception recalculé à ce rythme (s)
local INTERCEPT_MAX_TIME = 1.5 -- interception : au plus ce temps d'avance sur la course du joueur (s)
local VELOCITY_SMOOTHING = 0.3 -- vitesse du joueur lissée sur environ ce temps (moyenne exponentielle, s)
local AIM_MIN_CHANGE = 1 -- nouveau MoveTo seulement si le point visé bouge d'au moins ceci (studs)
local AIM_REFRESH = 2 -- MoveTo redonné au moins à ce rythme, même point (Humanoid.MoveTo lâche au bout de 8 s) (s)
local PATH_GOAL_DRIFT = 4 -- derrière un obstacle : chemin recalculé dès que le joueur s'éloigne de ceci de son but (studs)
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
local PATROL_LONG_FRAME = 0.5 -- a173 : image plus longue (s) = gel du serveur, pas compté dans la ronde
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
-- Vague 61 (a198) : vitesse réelle × Balance.Stats.RealSpeedScale, la borne haute suit (1,6 à l'échelle 1).
local REAL_SPEED_SCALE = Balance.Stats.RealSpeedScale
local GAIT_SPEED_MAX = 1.6 * REAL_SPEED_SCALE

-- Nom des vigiles dans les avertissements d'AnimPlayer, le même de jour et de nuit (mêmes modèles,
-- mêmes noms d'animations) : une animation pas encore livrée n'est signalée qu'une fois.
local ANIM_LABEL = "Vigile"
local DRIVER_ANIM_LABEL = "Conducteur"

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
-- Diagnostic Studio du retard en poursuite (workspace:SetAttribute("ChaseDebug", true)) : compteurs par vigile.
type ChaseTrace = { sight: number, path: number, last: number, hits: { [string]: number } }
local guardDebug: { [any]: ChaseTrace } = setmetatable({}, { __mode = "k" }) :: any

local GuardService = {}
-- a252 (L-244, L-245) : la capture qui se voit (l'objet passe par la main du vigile) et le renvoi de nuit, dans un
-- module d'aide (Guard/CatchPickUp). Absent (faux arbres des bancs plus anciens) : la capture d'avant. Champ et non
-- locale : ce fichier est à la limite de 200 locales de haut niveau (registres).
GuardService._CatchShow = (function(): any
	local ok, result = pcall(function(): any
		return require((script.Parent :: any).Guard.CatchPickUp)
	end)
	return if ok and type(result) == "table" then result else nil
end)() :: any
-- f70c3 (Chase.PathAvoid) : présentoirs bas (Promo_*) contournés par le chemin, saut à la hauteur de la marche
-- (Guard/PathAvoid). Absent : la règle d'avant. Champ et non locale, comme _CatchShow.
GuardService._PathAvoid = (function(): any
	local ok, result = pcall(function(): any
		return require((script.Parent :: any).Guard.PathAvoid)
	end)
	return if ok and type(result) == "table" then result else nil
end)() :: any

local guards: { Guard } = {} -- vigiles de jour
-- Heure (os.clock) où le dernier vigile de jour d'un magasin est parti (rentré, effacé…) : la vitrine
-- ne se reconstruit, et le magasin ne se rouvre, que Balance.Guard.ReopenAfterReturn s plus tard.
local lastGoneAt: { [Model]: number } = {}
local chasedBy: { [Player]: Guard } = {} -- par un vigile de jour
local nightGuards: { Guard } = {}
local nightChasedBy: { [Player]: Guard } = {}
local driverGuards: { Guard } = {} -- conducteurs du camion (L-083 point 3)
local driverChasedBy: { [Player]: Guard } = {}
local nightHooks: NightHooks? = nil -- règles de la nuit en cours ; nil le jour
local nightToken = 0 -- change à chaque StartNightPatrol et StopNightPatrol : périme les lancements en cours
local chaseSent: { [Player]: Model } = {} -- vigile annoncé au joueur par ChaseState(true, …)
local caughtAtNight: { [Player]: boolean } = {} -- attrapé la nuit, pas encore renvoyé : plus visé
local stunTokens: { [Player]: number } = {}
export type CatchListener = (player: Player, zone: number, night: boolean, carrying: boolean) -> ()
local catchListeners: { CatchListener } = {}
export type GoneListener = (thief: Player, store: Model) -> ()
local goneListeners: { GoneListener } = {}
-- Colis tombés au sol après un coup de batte (6.2), par payload (la table que CarryService garde) :
-- le vigile qui le suit, et tous les colis au sol (suivis ou non) jusqu'à leur prise ou leur fin.
local following: { [any]: Guard } = {}
local droppedPayloads: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- a114 : objets liés (voir l'en-tête, « Objet lié »), par payload NPCItem : le magasin, le vigile lié (nil :
-- aucun pour l'instant, un vigile de ce magasin ressortira à la prochaine prise) et le porteur actuel.
type Link = { store: Model, guard: Guard?, carrier: Player? }
local links: { [any]: Link } = {}
-- a174 : captures par objet porté (payload NPCItem), voir l'en-tête (« Troisième capture »).
local itemCatches: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any
local activeFolder: Folder? = nil
local fallbackTemplate: Model? = nil
local fallbackBuilding = false
local warned: { [string]: boolean } = {}

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

-- Tag SafeZone, dans la map : Shared/SafeZone, seul point de vérité depuis a157 (même règle qu'avant).
local function isInSafeZone(position: Vector3): boolean
	return SafeZone.Contains(position)
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

-- Le modèle `name` du dossier Guards de Clément (ReplicatedStorage/Assets, puis ServerStorage/Assets),
-- avec un Humanoid ; nil s'il n'est pas livré.
local function findGuardModel(name: string): Model?
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild("Assets")
		local folder = if assets then assets:FindFirstChild(GUARD_FOLDER) else nil
		local model = if folder then folder:FindFirstChild(name) else nil
		if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
			return model :: Model
		end
	end
	return nil
end

-- Le modèle de Clément pour cette zone, s'il est livré.
local function findTemplate(zone: number): Model?
	return findGuardModel(string.format(GUARD_ZONE_NAME, zone)) or findGuardModel(GUARD_COMMON_NAME)
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
		Costs = if GuardService._PathAvoid then GuardService._PathAvoid.Costs() else nil, -- f70c3
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
	-- a250 (Play de fusion68, Confiserie) : l'aperçu des panneaux de Clément (_PREVIEW_StoreReqSigns, retiré chez le
	-- client par StoreReqSignController) est CanCollide = false mais CanQuery = true : il coupait la vue du vigile.
	local preview = Workspace:FindFirstChild("_PREVIEW_StoreReqSigns")
	if preview then
		table.insert(list, preview)
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

-- Premier point à suivre d'un chemin qui vient d'arriver (L-091 point 1). Le vigile a avancé pendant
-- le calcul : il reprend au point du début du chemin le plus proche de lui, ou au suivant s'il l'a déjà
-- dépassé ; jamais un point resté derrière lui (avant : toujours le 2ᵉ, d'où des demi-tours).
local function firstWaypoint(waypoints: { PathWaypoint }, position: Vector3): number
	local count = #waypoints
	if count < 2 then
		return 2 -- au bout tout de suite : droit vers le but
	end
	-- Depuis le départ, tant que le point suivant est plus près de lui : le plus proche près du départ,
	-- jamais un point plus loin sur un chemin qui revient vers lui de l'autre côté d'un mur.
	local function distanceTo(i: number): number
		return flat(waypoints[i].Position - position).Magnitude
	end
	local best = 1
	while best < count and distanceTo(best + 1) <= distanceTo(best) do
		best += 1
	end
	if best < count then
		local here = waypoints[best].Position
		if flat(waypoints[best + 1].Position - here):Dot(flat(position - here)) > 0 then
			best += 1 -- déjà passé : le suivant
		end
	end
	return math.max(best, 2) -- le premier point est le départ
end

-- Lance le calcul d'un chemin vers `goal`, dans sa propre tâche (ComputeAsync attend).
local function computePath(guard: Guard, goal: Vector3)
	guard.computing = true
	guard.pathGoal = goal
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
			local waypoints = guard.path:GetWaypoints()
			guard.waypoints = waypoints
			guard.waypointIndex = firstWaypoint(waypoints, guard.root.Position)
			guard.pathFailures = 0
		else
			guard.waypoints = nil
			guard.pathFailures += 1
		end
	end)
end

-- a249 (Chase.PathLookahead ; Plays du 18/11 : à 114 studs/s, le vigile dépassait le point visé entre deux pas
-- de pilotage, revenait en arrière et ne sortait du magasin qu'en ≈ 3,3 à 4 s, à ≈ 40 studs/s réels) : le plus loin
-- des Chase.PathLookahead points du chemin depuis `index` qu'il peut joindre tout droit. Rayons à hauteur de son
-- centre, de ses genoux et de ses flancs (0,75 × son rayon d'agent), à plat ; chaque point au niveau de ses pieds
-- (à KNEE_HEIGHT près) ; jamais un point de saut ni au-delà ; aucun bout du trajet en zone safe. Sinon : `index`.
local function farthestReachable(guard: Guard, waypoints: { PathWaypoint }, index: number): number
	local lookahead = Chase.PathLookahead
	if not isPositiveNumber(lookahead) or index >= #waypoints then
		return index
	end
	local from = guard.root.Position
	local feet = from.Y - guard.rootHeight
	local knee = Vector3.new(0, guard.rootHeight - KNEE_HEIGHT, 0)
	local side = 0.75 * guard.agentRadius
	-- f70c3 (Chase.PathAvoid) : flancs aussi à hauteur des genoux, pour ne pas couper le coin d'une table basse.
	local kneeSides = GuardService._PathAvoid ~= nil and GuardService._PathAvoid.Enabled()
	local best = index
	for i = index + 1, math.min(#waypoints, index + math.floor(lookahead) - 1) do
		local waypoint = waypoints[i]
		local point = waypoint.Position
		if waypoint.Action == Enum.PathWaypointAction.Jump or math.abs(point.Y - feet) > KNEE_HEIGHT then
			break
		end
		local to = Vector3.new(point.X, from.Y, point.Z)
		local offset = to - from
		local length = offset.Magnitude
		if length > 1e-3 then
			local across = Vector3.new(-offset.Z, 0, offset.X) / length * side
			if not (clearLine(from, to) and clearLine(from - knee, to - knee)
				and clearLine(from + across, to + across) and clearLine(from - across, to - across)
				and (not kneeSides or (clearLine(from + across - knee, to + across - knee)
					and clearLine(from - across - knee, to - across - knee))))
			then
				break
			end
			local inSafe = false
			for step = WAYPOINT_SPACING, length, WAYPOINT_SPACING do
				if isInSafeZone(from + offset * (step / length)) then
					inSafe = true
					break
				end
			end
			if inSafe then
				break
			end
		end
		best = i
	end
	return best
end

-- Suit le dernier chemin calculé ; sans chemin, ou au bout, va droit vers `goal`. `lookahead` (poursuite derrière
-- un obstacle) : vise le plus loin des points suivants qu'il joint tout droit (farthestReachable).
local function followPath(guard: Guard, goal: Vector3, lookahead: boolean?)
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
	if lookahead and index <= #waypoints then
		index = farthestReachable(guard, waypoints, index)
	end
	guard.waypointIndex = index
	if index > #waypoints then
		moveTo(guard, goal)
		return
	end
	local waypoint = waypoints[index]
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		-- a250b (Play de fusion69, Supérette : sauté 4,5 studs avant Promo_A, retombé au pied de la table, 0,7 s à s'y
		-- hisser) : avec Chase.PathJumpLead, il saute quand ce qui le bloque à hauteur de genou est à moins de
		-- WalkSpeed × PathJumpLead + 1 stud devant lui sur la ligne du point, ou à WAYPOINT_REACHED du point ;
		-- sinon (0 ou absent), dès qu'il vise le point (la règle d'avant).
		local lead = Chase.PathJumpLead
		local offset = flat(waypoint.Position - position)
		local length = offset.Magnitude
		local jump = not isPositiveNumber(lead) or length <= WAYPOINT_REACHED
		if not jump then
			local knee = position - Vector3.new(0, guard.rootHeight - KNEE_HEIGHT, 0)
			-- a252 : avance plafonnée à Chase.PathJumpLeadMax studs (+ 1), quelle que soit la vitesse.
			local cap = Chase.PathJumpLeadMax
			local ahead = guard.humanoid.WalkSpeed * lead
			if isPositiveNumber(cap) then
				ahead = math.min(ahead, cap)
			end
			jump = not clearLine(knee, knee + offset * (math.min(length, ahead + 1) / length))
		end
		if jump then
			if GuardService._PathAvoid then
				GuardService._PathAvoid.BeforeJump(guard.humanoid, waypoints, index, guard.root.Position.Y - guard.rootHeight) -- f70c3 : à la hauteur de la marche
			end
			guard.humanoid.Jump = true
		end
	end
	moveTo(guard, waypoint.Position) -- jamais par la zone safe
end

-- Vitesse de poursuite d'un vigile de nuit (L-108 point 2) : Night.ChaseSpeed, au moins la vitesse
-- conseillée de la zone + Night.ChaseSpeedBonus (règle d'avant, gardée comme plancher).
local function nightChaseSpeed(zone: number): number
	return math.max(Night.ChaseSpeed, Zones[zone].AdvisedSpeed + Night.ChaseSpeedBonus)
end

-- Vitesse de lecture de Run ou de Walk pour le WalkSpeed actuel du vigile (L-048) :
-- WalkSpeed / (référence × échelle), bornée (vigile de nuit : jusqu'à Night.GaitSpeedMax, L-108).
-- 1 pour un autre nom.
local function gaitSpeed(guard: Guard, name: string): number
	local reference = GAIT_REFERENCE[name]
	if reference == nil then
		return 1
	end
	local maximum = if guard.kind == "Night" then math.max(Night.GaitSpeedMax, GAIT_SPEED_MIN) else GAIT_SPEED_MAX
	return math.clamp(guard.humanoid.WalkSpeed / (reference * guard.scale), GAIT_SPEED_MIN, maximum)
end

-- Joue Run ou Walk au pas du vigile ; déjà en cours, seule sa vitesse change.
local function playGait(guard: Guard, name: string)
	guard.anims:Play(name, nil, nil, gaitSpeed(guard, name))
end

-- Toute écriture du WalkSpeed d'un vigile en jeu passe par ici : Run et Walk, s'ils jouent,
-- prennent aussitôt le nouveau pas (jour : vitesse de la zone ; nuit : Night.ChaseSpeed ;
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
	guard.pathGoal = nil
	guard.lastSeen = nil
	guard.chaseAim = nil
	guard.chaseAimAt = nil
	guard.chaseVelocity = nil
	guard.chaseVelocityAt = nil
	guard.chasePhase = nil
	guard.holdSince = nil
	guard.holdTarget = nil
	guard.holdStepAt = nil
	guard.pathFailures = 0
end

-- ChaseState du joueur : le vigile de jour qui le poursuit, sinon celui de nuit ; ChaseState(false)
-- quand plus aucun ne le poursuit. N'envoie rien si rien n'a changé.
local function refreshChaseState(player: Player)
	if player.Parent ~= Players then
		chaseSent[player] = nil
		return
	end
	local guard = chasedBy[player] or driverChasedBy[player] or nightChasedBy[player]
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
	if driverChasedBy[player] == guard then
		driverChasedBy[player] = nil
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
	guard.followOwner = nil
	if following[payload] == guard then
		following[payload] = nil
	end
end

-- a114 (objet lié) : un objet sorti d'un colis d'un magasin PNJ, hors camion (l'ancien déroulé, qui ne portait que des
-- colis NPCBox, est parti avec Features.ShelfOpen, vague 53).
local function linkable(payload: any): boolean
	return type(payload) == "table"
		and payload.Kind == "NPCItem"
		and type(payload.StoreId) == "string"
		and string.sub(payload.StoreId, 1, 6) ~= "Truck_"
end

-- Cantin, 2026-11-13 : `player` porte-t-il un objet lié, dans le volume Bounds du magasin d'où il vient ?
-- Attrapé là, l'objet ne tombe pas : il revole sur son rayon (voir l'en-tête, « Objet lié »).
local function inItsStore(player: Player): boolean
	local ok, payload = pcall(CarryService.GetPayload, player)
	if not ok or not linkable(payload) then
		return false
	end
	local store = findStore(payload.StoreId)
	local bounds = if store then Find.path(store, BOUNDS) else nil
	local root = bodyOf(player)
	if root == nil or bounds == nil or not bounds:IsA("BasePart") then
		return false
	end
	local box = bounds :: BasePart
	return insideBox(box.CFrame, box.Size, root.Position)
end

-- Lie `payload` au vigile de jour `guard` (nil : à aucun pour l'instant), dans le magasin `store`. Un vigile
-- n'est lié qu'à un objet à la fois : ses autres liens perdent leur vigile (un autre ressortira pour eux).
local function bindLink(payload: any, store: Model, guard: Guard?)
	if not linkable(payload) then
		return
	end
	if guard and (guard.kind ~= "Day" or guard.driver ~= nil) then
		return -- vigiles de nuit, policiers, conducteurs : jamais liés
	end
	local link = links[payload]
	if link == nil then
		local fresh: Link = { store = store, guard = guard, carrier = nil }
		links[payload] = fresh
		link = fresh
	end
	local current = link :: Link
	current.guard = guard
	if guard then
		current.store = guard.store or store
		for other, otherLink in links do
			if other ~= payload and otherLink.guard == guard then
				otherLink.guard = nil
			end
		end
	end
end

-- Le porteur de l'objet lié à ce vigile, s'il y en a un (repris pendant que le vigile jouait Catch).
local function linkedCarrier(guard: Guard): Player?
	for _, link in links do
		if link.guard == guard and link.carrier and link.carrier.Parent == Players then
			return link.carrier
		end
	end
	return nil
end

-- Défini plus bas (retarget) : le vigile lié repart vers le porteur de son objet.
local retargetLinked: (guard: Guard, player: Player) -> ()
-- Défini plus bas (followDrop) : à la fin de Catch, le vigile va garder l'objet tombé à la capture.
local followAfterCatch: (guard: Guard) -> boolean

local function despawn(guard: Guard, reason: string)
	if not guard.alive then
		return
	end
	guard.alive = false
	endChase(guard)
	releaseFollow(guard)
	local list = if guard.kind == "Night" then nightGuards elseif guard.kind == "Driver" then driverGuards else guards
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
	local store = guard.store
	if guard.kind == "Day" and store then
		lastGoneAt[store] = os.clock() -- rouverture du magasin : voir StoreReadyToReopen
	end
	log(`{guard.label} parti ({reason})`)
	-- Le magasin se rouvre pour son voleur (OnGuardGone).
	local owner = guard.owner
	if guard.kind == "Day" and store and owner then
		for _, listener in table.clone(goneListeners) do
			task.spawn(listener, owner, store)
		end
	end
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

-- Nouvelle poursuite (Cantin, 2026-11-14, vague 45 ; Features.GuardChaseV2, Config/Chase) ---------
-- Ruée jusqu'à Chase.HoldDistance studs, puis la marche du voleur (donnée par le serveur) + un
-- rapprochement qui dépend de sa Speed effective par rapport à un minimum (conducteur : sa marche, qui
-- grandit avec le temps). Voir l'en-tête de Config/Chase.

-- Les quatre poursuivants de la règle : vigile de magasin, vigile de nuit, policier (DriverChase avec
-- Label : WitnessService), conducteur du camion (DriverChase sans Label).
type RuleKind = "Store" | "Night" | "Police" | "Truck"

local function ruleKindOf(guard: Guard): RuleKind
	if guard.kind == "Day" then
		return "Store"
	elseif guard.kind == "Night" then
		return "Night"
	end
	local driver = guard.driver
	return if driver ~= nil and driver.Label ~= nil then "Police" else "Truck"
end

-- Ce poursuivant suit-il la nouvelle règle (Features.GuardChaseV2, Chase.Apply) ? Vitesse imposée par le
-- tutoriel (GetSpeedOverride) : non, l'ancienne règle.
local function followsDistanceRule(guard: Guard, player: Player): boolean
	if not Features.GuardChaseV2 or Zones[guard.zone] == nil then
		return false
	end
	local kind = ruleKindOf(guard)
	local applies = if kind == "Store"
		then Chase.Apply.StoreGuard
		elseif kind == "Night" then Chase.Apply.NightGuard
		elseif kind == "Police" then Chase.Apply.Police
		else Chase.Apply.TruckDriver
	if not applies then
		return false
	end
	local ok, value = pcall(GuardService.GetSpeedOverride, player, guard.zone)
	return not (ok and isPositiveNumber(value))
end

-- a168 : vitesse de poursuite écrite dans les journaux. Nouvelle poursuite : la règle (les vraies vitesses
-- s'écrivent à la ruée et à sa fin) ; sinon `old`, le texte d'avant (inchangé : les bancs le lisent).
-- Sans joueur (vigile de nuit en ronde) : Features.GuardChaseV2 et Chase.Apply.NightGuard seulement.
local function chaseSpeedText(guard: Guard, player: Player?, old: string): string
	local rule = if player then followsDistanceRule(guard, player) else Features.GuardChaseV2 and Chase.Apply.NightGuard
	if not rule then
		return old
	end
	if ruleKindOf(guard) == "Truck" then
		return `ruée, puis sa marche × (1 + {Chase.DriverGrowthPerSecond} × s), au plus × {Chase.DriverMaxFactor}`
	end
	return `ruée, puis marche du voleur + rapprochement (distance {Chase.HoldDistance} studs)`
end

-- Speed effective du voleur = Speed du profil × multiplicateur du trail (le calcul de Formulas.ShownSpeed, comme
-- le HUD et Formulas.WalkSpeed), lue ici côté serveur (StatsService) ; jamais une valeur du client.
local function effectiveSpeed(player: Player): number
	local ok, trail = pcall(StatsService.GetTrailMultiplier, player)
	if not ok or not isPositiveNumber(trail) then
		trail = 1
	end
	local speed = StatsService.GetSpeed(player) * (trail :: number)
	return if speed == speed and speed >= 0 and speed < math.huge then speed else 0
end

-- a193 (Cantin, 2026-11-15, T-069) : position estimée du voleur, pour la distance gardée, le point visé et la
-- capture (Config/Chase, LagCompensation). Le serveur reçoit la position du personnage (au client) en retard,
-- et le client voit le vigile en retard : position reçue + vitesse au sol × retard, retard =
-- min(GetNetworkPing × LagPingFactor, LagMaxSeconds), avance au plus LagMaxStuds studs. La vitesse est celle
-- que le serveur reçoit, bornée à la WalkSpeed qu'il donne (une poussée, un téléport ne comptent pas) ; le
-- ping est mesuré par Roblox : rien ne vient d'un remote. Une avance qui traverse un mur : la position reçue.
-- Compensation coupée, ping inconnu ou voleur immobile : la position reçue (la règle d'avant).
local function lagSeconds(player: Player): number
	if not Chase.LagCompensation then
		return 0
	end
	local ok, ping = pcall(function(): number
		return player:GetNetworkPing()
	end)
	if not ok or not isPositiveNumber(ping) or not isPositiveNumber(Chase.LagPingFactor) then
		return 0
	end
	return math.min(ping * Chase.LagPingFactor, Chase.LagMaxSeconds)
end

local function estimatedPosition(player: Player, targetRoot: BasePart, targetHumanoid: Humanoid): Vector3
	local position = targetRoot.Position
	local lag = lagSeconds(player)
	if lag <= 0 then
		return position
	end
	local velocity = flat(targetRoot.AssemblyLinearVelocity)
	local speed = velocity.Magnitude
	local cap = targetHumanoid.WalkSpeed
	if not isPositiveNumber(speed) or not isPositiveNumber(cap) then
		return position
	end
	local ahead = math.min(speed, cap) * lag
	if isPositiveNumber(Chase.LagMaxStuds) then
		ahead = math.min(ahead, Chase.LagMaxStuds)
	end
	local estimate = position + velocity.Unit * ahead
	return if clearLine(position, estimate) then estimate else position
end

-- Rapprochement (studs/s, négatif : le voleur s'éloigne) pour r = Speed effective / minimum.
local function closingFor(r: number): number
	if r <= 1 then
		return Chase.ClosingSpeedMax * (1 - math.max(r, 0))
	elseif Chase.AboveRequired == "Gain" then
		return -Chase.ClosingSpeedMax * math.min(r - 1, 1)
	end
	return 0
end

-- Rapprochement de ce poursuivant sur `player`. Vigile de magasin : minimum = SpeedRequired de sa zone
-- (zone 1 : Chase.Zone1SpeedRequired ; 0 = sans minimum, la distance ne bouge pas). Vigile de nuit et
-- policier : minimum = Speed effective actuelle × leur facteur, donc r = 1 / facteur.
local function closingSpeed(guard: Guard, player: Player): number
	local kind = ruleKindOf(guard)
	if kind == "Night" or kind == "Police" then
		local factor = if kind == "Night" then Chase.NightGuardRequiredFactor else Chase.PoliceRequiredFactor
		return closingFor(if isPositiveNumber(factor) then 1 / factor else 1)
	end
	local required = if guard.zone == 1 then Chase.Zone1SpeedRequired else Zones[guard.zone].SpeedRequired
	if not isPositiveNumber(required) then
		return 0
	end
	return closingFor(effectiveSpeed(player) / required)
end

-- WalkSpeed du poursuivant selon la phase : la ruée ; puis la marche du voleur + le rapprochement
-- (conducteur : sa marche × 1 + Chase.DriverGrowthPerSecond par seconde depuis la fin de la ruée, au plus
-- × Chase.DriverMaxFactor), jamais moins de Chase.HoldMinSpeed. La marche du voleur est son
-- Humanoid.WalkSpeed lu ici, côté serveur (posée par StatsService, colis compris) : jamais une vitesse
-- mesurée ni envoyée par le client.
local function distanceRuleSpeed(guard: Guard, player: Player, targetHumanoid: Humanoid, now: number): number
	local walk = targetHumanoid.WalkSpeed
	if not isPositiveNumber(walk) then
		walk = 0
	end
	if guard.chasePhase == "Rush" then
		return math.max(Chase.RushMinSpeed, Chase.RushWalkFactor * walk)
	end
	if ruleKindOf(guard) == "Truck" then
		local elapsed = math.max(now - (guard.holdSince or now), 0)
		local factor = math.min(1 + Chase.DriverGrowthPerSecond * elapsed, Chase.DriverMaxFactor)
		return math.max(walk * factor, Chase.HoldMinSpeed)
	end
	return math.max(walk + closingSpeed(guard, player), Chase.HoldMinSpeed)
end

-- a168 : durée d'image la plus longue prise en compte pour anticiper la fin de la ruée (s).
local MAX_RUSH_STEP = 0.2

-- a249 (Cantin, 2026-11-17, L-235 décision 2) : délai avant le départ du vigile du magasin (apparition, objet
-- ramassé, reprise après la cinématique d'ouverture). Chase.StartDelay absent ou nul : REACTION_DELAY.
local function startDelay(): number
	local value = Chase.StartDelay
	return if isPositiveNumber(value) then value else REACTION_DELAY
end

-- a249 (L-235 décision 1) : le vigile du magasin suit-il le retour doux (Chase.SpringReturn) au lieu de la ruée ?
local function springReturn(guard: Guard): boolean
	return Chase.SpringReturn == true and ruleKindOf(guard) == "Store"
end

-- a249 : diagnostic de la poursuite (Chase.Debug, ou l'attribut ChaseDebug du Workspace en Studio).
local function chaseDebugOn(): boolean
	return Chase.Debug == true or (IS_STUDIO and Workspace:GetAttribute("ChaseDebug") == true)
end

-- a249 : écart (studs) sous lequel le premier retour est fini (« fin de la ruée » dans la sortie) ; ensuite la
-- distance prévue suit le rapprochement, comme la poursuite à distance d'avant (holdRecall).
local SPRING_ARRIVE = 1

-- a249 : profil du surplus du retour doux pour une marche du voleur `walk` (springSurplus).
--   linear = HoldRecallMax / HoldRecallGain (4 studs) ; capNear = max((SpringMaxFactor − 1) × marche, HoldRecallMax) ;
--   joinGap = écart où le freinage SpringBrake atteint capNear ;
--   capFar (Chase.SpringFar) = max((SpringFarFactor − 1) × marche, capNear), atteint à l'écart SpringFarDistance −
--   HoldDistance avec le freinage qui y suffit, au plus SpringFarBrake (farBrake ; 0 : sans la part de loin).
type SpringProfile = {
	gain: number,
	recallMax: number,
	linear: number,
	brake: number,
	capNear: number,
	joinGap: number,
	capFar: number,
	farBrake: number,
}

local function springProfile(walk: number): SpringProfile
	local gain = if isPositiveNumber(Chase.HoldRecallGain) then Chase.HoldRecallGain else 0
	local recallMax = if isPositiveNumber(Chase.HoldRecallMax) then Chase.HoldRecallMax else 0
	local linear = if gain > 0 then recallMax / gain else 0
	local brake = if isPositiveNumber(Chase.SpringBrake) then Chase.SpringBrake else 0
	local capNear = math.max(math.max(Chase.SpringMaxFactor - 1, 0) * walk, recallMax)
	local joinGap = if brake > 0 then linear + (capNear * capNear - recallMax * recallMax) / (2 * brake) else math.huge
	local capFar = capNear
	local farBrake = 0
	if Chase.SpringFar == true and isPositiveNumber(Chase.SpringFarFactor) and joinGap < math.huge then
		capFar = math.max((Chase.SpringFarFactor - 1) * walk, capNear)
		if capFar > capNear then
			local span = Chase.SpringFarDistance - Chase.HoldDistance - joinGap
			local needed = if span > 0 then (capFar * capFar - capNear * capNear) / (2 * span) else math.huge
			farBrake = math.min(needed, if isPositiveNumber(Chase.SpringFarBrake) then Chase.SpringFarBrake else brake)
		end
	end
	return {
		gain = gain,
		recallMax = recallMax,
		linear = linear,
		brake = brake,
		capNear = capNear,
		joinGap = joinGap,
		capFar = if farBrake > 0 then capFar else capNear,
		farBrake = farBrake,
	}
end

-- a249 : surplus du retour doux (studs/s) pour un écart `gap` = distance − prévue.
--   écart ≤ 0 : HoldRecallGain × écart, au plus −HoldRecallMax ; jusqu'à linear : HoldRecallGain × écart ;
--   jusqu'à joinGap : √(HoldRecallMax² + 2 × SpringBrake × (écart − linear)), au plus capNear ;
--   au-delà (Chase.SpringFar) : √(capNear² + 2 × farBrake × (écart − joinGap)), au plus capFar.
-- Continu en tout point : sa vitesse ne retombe jamais d'un coup, il freine au plus à farBrake puis à SpringBrake.
local function springSurplus(profile: SpringProfile, gap: number): number
	if gap <= 0 then
		return math.max(profile.gain * gap, -profile.recallMax)
	end
	local surplus = math.min(profile.gain * gap, profile.recallMax)
	if gap > profile.linear then
		surplus = math.sqrt(profile.recallMax * profile.recallMax + 2 * profile.brake * (gap - profile.linear))
	end
	if profile.farBrake <= 0 or gap <= profile.joinGap then
		return math.min(surplus, profile.capNear)
	end
	return math.min(math.sqrt(profile.capNear * profile.capNear + 2 * profile.farBrake * (gap - profile.joinGap)), profile.capFar)
end

-- a249 (Cantin, 2026-11-17, L-235 décision 1 ; Play du 17/11 : la ruée à 3,9 × la marche finissait à 8 à 9 studs
-- au lieu de 14, le Humanoid ne freinant qu'à ≈ 700 studs/s² ; ensuite, à la marche du voleur, il paraissait
-- « très lent ») : vitesse du vigile du magasin en retour doux (Chase.SpringReturn), à chaque image :
--   marche du voleur + rapprochement + surplus, jamais moins de HoldMinSpeed ; écart = distance − prévue ;
--   surplus = HoldRecallGain × écart pour un écart ≤ HoldRecallMax / HoldRecallGain (4 studs ; au plus −HoldRecallMax
--   derrière), au-delà √(HoldRecallMax² + 2 × SpringBrake × (écart − 4)), au plus max((SpringMaxFactor − 1) × marche,
--   HoldRecallMax).
-- Loin, il court au plus à SpringMaxFactor × la marche ; en arrivant, il freine à SpringBrake (80 studs/s²), bien sous
-- ce que freine un Humanoid (≈ 700), puis le rappel des 4 derniers studs : ni dépassement, ni à-coup, ni longue
-- approche au ralenti ; le rappel linéaire près de la distance prévue ne fait pas trembler sa vitesse quand la
-- position du voleur bouge d'un stud d'une image à l'autre. a249 (Cantin, 2026-11-18 : « plus vite de loin ») : avec
-- Chase.SpringFar, au-delà de ce freinage, il court plus vite encore, jusqu'à SpringFarFactor × la marche à
-- SpringFarDistance studs et au-delà (springProfile, springSurplus). Distance prévue : Chase.HoldDistance jusqu'à
-- l'arrivée (écart ≤ SPRING_ARRIVE), puis elle baisse au rythme du rapprochement, jamais sous la capture. Le voleur
-- qui s'éloigne de nouveau est rattrapé de la même façon : le vigile ne lâche jamais prise.
local function springSpeed(guard: Guard, player: Player, targetAt: Vector3, targetHumanoid: Humanoid, now: number): number
	local walk = targetHumanoid.WalkSpeed
	if not isPositiveNumber(walk) then
		walk = 0
	end
	local closing = closingSpeed(guard, player)
	local target = guard.holdTarget or Chase.HoldDistance
	if guard.chasePhase == "Hold" then
		local last = guard.holdStepAt or guard.holdSince or now
		target = math.max(target - closing * math.max(now - last, 0), Balance.Guard.CatchDistance)
		guard.holdTarget = target
		guard.holdStepAt = now
	end
	local distance = flat(targetAt - guard.root.Position).Magnitude
	local gap = distance - target
	if guard.chasePhase == "Rush" and gap <= SPRING_ARRIVE then
		guard.chasePhase = "Hold"
		guard.holdSince = now
		guard.holdStepAt = now
		guard.holdTarget = target
		log(string.format("%s : à %.1f studs de %s, fin de la ruée, poursuite à distance (marche %.2f + rapprochement %.2f, retour doux)",
			guard.label, distance, player.Name, walk, closing))
	end
	return math.max(walk + closing + springSurplus(springProfile(walk), gap), Chase.HoldMinSpeed)
end

-- a173 (2026-11-15, Play de fusion48) : la fin de ruée tombait vers 7,5 studs au lieu de 10 (image plus
-- longue que la précédente, élan du Humanoid à ≈ 42 studs/s une image de plus), d'où une capture de nuit et
-- de police en 0,7 à 1,3 s au lieu de 1,5 s. En poursuite à distance, le vigile est rappelé vers sa distance
-- prévue : + clamp(Chase.HoldRecallGain × (distance − prévue), ±Chase.HoldRecallMax). La distance prévue part
-- de Chase.HoldDistance et suit le rapprochement (closingSpeed, image par image : 0 pour le vigile de magasin
-- au minimum, 4 studs/s la nuit et pour le policier), jamais sous la distance de capture.
local function holdRecall(guard: Guard, player: Player, targetAt: Vector3, now: number): number
	local last = guard.holdStepAt or guard.holdSince or now
	guard.holdStepAt = now
	local catchDistance = if guard.kind == "Night" then Night.CatchDistance else Balance.Guard.CatchDistance
	local previous = guard.holdTarget or Chase.HoldDistance
	local target = math.max(previous - closingSpeed(guard, player) * math.max(now - last, 0), catchDistance)
	guard.holdTarget = target
	local distance = flat(targetAt - guard.root.Position).Magnitude
	return math.clamp(Chase.HoldRecallGain * (distance - target), -Chase.HoldRecallMax, Chase.HoldRecallMax)
end

-- À chaque pas de poursuite : fin de la ruée à Chase.HoldDistance studs (à l'horizontale), puis la
-- vitesse de la phase, redonnée seulement si elle change.
-- a168 (2026-11-15, Play de a153) : la fin de ruée n'était testée qu'une fois par image, le vigile finissait
-- 1 à 5 studs trop près. Elle est anticipée : finie dès que distance − (vitesse du vigile − marche du
-- voleur) × dt ≤ HoldDistance (dt = durée de l'image précédente) ; pour cette dernière image, le vigile
-- court juste assez vite (entre sa vitesse à distance et la ruée) pour arriver à HoldDistance.
-- a193 : distances mesurées jusqu'à `targetAt`, la position estimée du voleur (estimatedPosition).
-- Vague 67 (a224, Cantin : « la vitesse doit être décroissante quand il commence à arriver ») : plafond de la vitesse
-- de tout poursuivant de cette règle, ruée comprise, pour qu'il ralentisse en continu jusqu'à la capture :
--   part de la vitesse du voleur qui l'éloigne du poursuivant (AssemblyLinearVelocity à plat, bornée à sa WalkSpeed
--   donnée par le serveur, comme estimatedPosition) + max(√(2 × RushBrake × (d − HoldDistance)⁺
--   + 2 × ApproachBrake × (d − capture)⁺), ApproachMinClosing), d mesurée jusqu'à `targetAt`.
-- Un voleur immobile le voit arriver à ≈ √(20 × ApproachBrake) studs/s à 10 studs, puis ralentir jusqu'à
-- ApproachMinClosing (il est toujours attrapé) ; un voleur qui court tout droit garde la règle d'avant, sauf sur les
-- derniers studs d'un rapprochement. Chase.ApproachBrake = 0 : sans plafond (la règle d'avant).
local function approachCap(guard: Guard, targetAt: Vector3, targetRoot: BasePart, targetHumanoid: Humanoid): number
	local brake = Chase.ApproachBrake
	if not isPositiveNumber(brake) then
		return math.huge
	end
	local stopped = guard.standingStill == true or flat(targetRoot.AssemblyLinearVelocity).Magnitude < 0.5
	if guard.kind == "Day" and stopped and guard.chaseAim == nil and guard.seenStill ~= true and isPositiveNumber(Chase.ApproachBrakeHidden) then
		-- a250b (Play de fusion69, Supérette : voleur coincé derrière Shelf_A_EndA attrapé 4,2 s après les 14 studs, le
		-- vigile freinant à ApproachBrake tout le détour) : voleur arrêté (ou dont la vitesse lue est nulle) et hors de
		-- vue (dernier pas de pilotage derrière un obstacle, chaseBehindObstacle) : il ne voit pas arriver le vigile,
		-- freinage plus fort. Jamais si le vigile l'a vu arrêté depuis son dernier mouvement (seenStill) : sa vitesse ne
		-- remonte pas quand il le perd de vue en arrivant.
		brake = math.max(brake, Chase.ApproachBrakeHidden)
	end
	local offset = flat(targetAt - guard.root.Position)
	local distance = offset.Magnitude
	local away = 0
	local walk = targetHumanoid.WalkSpeed
	local waypoints = guard.waypoints
	if Chase.ApproachAlongPath == true and waypoints ~= nil and guard.waypointIndex <= #waypoints then
		-- a250 (Play de fusion68, Supérette : un voleur coincé derrière Shelf_A_EndA attrapé 3,4 s après les 14 studs,
		-- le vigile rampant à 3-10 studs/s dans le détour) : derrière un obstacle, d est la longueur du chemin qui
		-- reste (jusqu'au point suivi, puis de point en point jusqu'au bout) moins l'écart entre le bout du chemin (le
		-- point d'interception, parfois devant la cible) et `targetAt` : jamais plus que le trajet jusqu'à la cible
		-- (il n'arrive pas plus vite qu'en ligne droite), jamais moins que la ligne droite.
		local along = 0
		local from = guard.root.Position
		for i = guard.waypointIndex, #waypoints do
			local point = waypoints[i].Position
			along += flat(point - from).Magnitude
			from = point
		end
		distance = math.max(distance, along - flat(targetAt - from).Magnitude)
	end
	if offset.Magnitude > 1e-3 and isPositiveNumber(walk) then
		away = math.clamp(flat(targetRoot.AssemblyLinearVelocity):Dot(offset.Unit), 0, walk)
		if away ~= away then
			away = 0
		end
	end
	if guard.standingStill == true then
		away = 0 -- a249 (Chase.StuckCatch) : il pousse contre un obstacle sans avancer, comme un voleur arrêté
	end
	local catchDistance = if guard.kind == "Night" then Night.CatchDistance else Balance.Guard.CatchDistance
	-- a249 : en retour doux, freinage à Chase.SpringBrake (RushBrake, 1 000 studs/s², dépasse ce que freine un Humanoid).
	local spring = springReturn(guard)
	local brakeValue = if spring then Chase.SpringBrake else Chase.RushBrake
	local rushBrake = if isPositiveNumber(brakeValue) then brakeValue else 0
	local room = 2 * rushBrake * math.max(distance - Chase.HoldDistance, 0) + 2 * brake * math.max(distance - catchDistance, 0)
	if spring then
		-- a249 (Chase.SpringFar) : loin, freinage farBrake au lieu de SpringBrake (springProfile) ; le plafond reste
		-- au-dessus du retour doux pour un voleur qui court tout droit, et freine de même sur un voleur arrêté.
		local profile = springProfile(if isPositiveNumber(walk) then walk else 0)
		if profile.farBrake > rushBrake then
			local hold = guard.holdTarget or Chase.HoldDistance
			room += 2 * (profile.farBrake - rushBrake) * math.max(distance - hold - profile.joinGap, 0)
		end
	end
	local cap = away + math.max(math.sqrt(room), Chase.ApproachMinClosing)
	if guard.kind == "Day" and stopped and isPositiveNumber(Chase.ApproachBrakeHidden) then
		-- a250b : sur un voleur arrêté, le plafond ne remonte jamais (un chemin recalculé allonge parfois d d'un coup,
		-- et ApproachBrakeHidden double l'à-coup) ; retenu seulement avec un d sûr (en vue, ou un chemin), jamais sur la
		-- ligne droite d'une vue périmée (le voleur vient de se cacher) avant le premier chemin. Remis à zéro quand il repart.
		local last = guard.stillCap
		if last ~= nil and last < cap then
			cap = last
		end
		if guard.waypoints ~= nil or (guard.chaseAim ~= nil and guard.seenStill == true) then
			guard.stillCap = cap
		end
	else
		guard.stillCap = nil
	end
	return cap
end

local function distanceRuleStep(
	guard: Guard,
	player: Player,
	targetAt: Vector3,
	targetRoot: BasePart,
	targetHumanoid: Humanoid,
	now: number
)
	if springReturn(guard) then
		-- a249 : retour doux (springSpeed), sous le plafond d'arrivée.
		local speed = math.min(springSpeed(guard, player, targetAt, targetHumanoid, now), approachCap(guard, targetAt, targetRoot, targetHumanoid))
		if math.abs(speed - guard.humanoid.WalkSpeed) > 0.05 then
			setWalkSpeed(guard, speed)
		end
		return
	end
	local approach: number? = nil
	if guard.chasePhase == "Rush" then
		local distance = flat(targetAt - guard.root.Position).Magnitude
		local last = guard.rushStepAt
		local dt = if last then math.clamp(now - last, 0, MAX_RUSH_STEP) else 0
		guard.rushStepAt = now
		local walk = targetHumanoid.WalkSpeed
		if not isPositiveNumber(walk) then
			walk = 0
		end
		local rush = guard.humanoid.WalkSpeed
		if distance - math.max(rush - walk, 0) * dt <= Chase.HoldDistance then
			guard.chasePhase = "Hold"
			guard.holdSince = now
			guard.rushStepAt = nil
			guard.holdTarget = nil
			guard.holdStepAt = nil
			local hold = distanceRuleSpeed(guard, player, targetHumanoid, now)
			if dt > 0 and distance > Chase.HoldDistance then
				approach = math.clamp(walk + (distance - Chase.HoldDistance) / dt, hold, math.max(rush, hold))
			end
			local how = if ruleKindOf(guard) == "Truck"
				then string.format("sa marche %.2f × (1 + %g × s), au plus × %g", walk, Chase.DriverGrowthPerSecond, Chase.DriverMaxFactor)
				else string.format("marche %.2f + rapprochement %.2f", walk, closingSpeed(guard, player))
			log(string.format("%s : à %.1f studs de %s, fin de la ruée, poursuite à distance à %.2f studs/s (%s)",
				guard.label, distance, player.Name, hold, how))
		elseif Chase.RushBrake > 0 then
			-- a174 : freinage de fin de ruée, au plus Chase.RushBrake studs/s² (ruée à +30 % : l'élan du Humanoid
			-- l'aurait porté jusqu'à 4 à 10 studs de plus que HoldDistance, assez pour attraper tout de suite).
			local cap = walk + math.sqrt(2 * Chase.RushBrake * (distance - Chase.HoldDistance))
			if cap < distanceRuleSpeed(guard, player, targetHumanoid, now) then
				approach = math.max(cap, Chase.HoldMinSpeed)
			end
		end
	end
	local speed = approach or distanceRuleSpeed(guard, player, targetHumanoid, now)
	if approach == nil and guard.chasePhase == "Hold" and ruleKindOf(guard) ~= "Truck" then
		speed = math.max(speed + holdRecall(guard, player, targetAt, now), Chase.HoldMinSpeed)
	end
	speed = math.min(speed, approachCap(guard, targetAt, targetRoot, targetHumanoid))
	if math.abs(speed - guard.humanoid.WalkSpeed) > 0.05 then
		setWalkSpeed(guard, speed)
	end
end

local function startChase(guard: Guard, now: number)
	setState(guard, "Chase")
	guard.nextSteerAt = now
	guard.nextPathAt = now
	guard.anims:Stop("Walk") -- vigile de nuit : il marchait sur sa ronde
	local player = guard.target
	local targetRoot: BasePart? = nil
	local targetHumanoid: Humanoid? = nil
	if player then
		targetRoot, targetHumanoid = bodyOf(player)
	end
	guard.stuckFrom = nil
	guard.stuckSince = nil
	guard.standingStill = nil
	guard.seenStill = nil
	guard.stillCap = nil
	guard.blockedFrom = nil
	guard.blockedSince = nil
	guard.blockedTrail = nil
	if player and targetHumanoid and followsDistanceRule(guard, player) then
		guard.chasePhase = "Rush"
		guard.rushStepAt = nil
		if targetRoot and springReturn(guard) then
			-- a249 : retour doux, au plus Chase.SpringMaxFactor × sa marche près de lui (Chase.SpringFar : SpringFarFactor de loin).
			local targetAt = estimatedPosition(player, targetRoot, targetHumanoid)
			local speed = math.min(springSpeed(guard, player, targetAt, targetHumanoid, now), approachCap(guard, targetAt, targetRoot, targetHumanoid))
			setWalkSpeed(guard, speed)
			local most = if Chase.SpringFar == true
				then `au plus {Chase.SpringFarFactor} × sa marche de loin, {Chase.SpringMaxFactor} × près`
				else `au plus {Chase.SpringMaxFactor} × sa marche`
			log(`{guard.label} : ruée sur {player.Name} à {Format.short(guard.humanoid.WalkSpeed)} studs/s (retour doux, {most})`)
		else
			setWalkSpeed(guard, distanceRuleSpeed(guard, player, targetHumanoid, now))
			log(`{guard.label} : ruée sur {player.Name} à {Format.short(guard.humanoid.WalkSpeed)} studs/s`)
		end
	else
		setWalkSpeed(guard, guard.speed)
	end
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
	if guard.kind == "Driver" then
		startFade(guard, now, "fin de sa poursuite", nil) -- il ne rentre nulle part (L-083 point 3)
		return
	end
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
		log(`{guard.label} : abandonne l'objet tombé au sol ({reason})`)
	else
		log(`{guard.label} : abandonne {if player then player.Name else "?"} ({reason})`)
	end
	local now = os.clock()
	stop(guard)
	local driver = guard.driver
	if state == "Wait" or (driver ~= nil and driver.Tired ~= true) then
		-- Pas encore élancé, ou conducteur du camion (sans Tired au contrat) : pas d'essoufflement.
		-- Le policier (driver.Tired, L-111) s'essouffle comme un vigile, puis s'efface (startReturn).
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
		if RevealState.IsProtected(player) then
			guard.onKnock = nil -- vague 62 : protégé par sa cinématique, ni poussée ni suite du coup
			return
		end
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

-- a174 : compte une capture de `player` pour l'objet NPCItem qu'il porte ; true quand c'est la
-- Chase.ReturnToShelfAfterCatches-ième (l'objet revole alors tel quel sur son rayon, sans chute).
local function catchSendsBack(player: Player): boolean
	local ok, payload = pcall(CarryService.GetPayload, player)
	if not ok or type(payload) ~= "table" or payload.Kind ~= "NPCItem" then
		return false
	end
	local count = (itemCatches[payload] or 0) + 1
	itemCatches[payload] = count
	local limit = Chase.ReturnToShelfAfterCatches
	local back = limit > 0 and count >= limit
	log(`{player.Name} attrapé avec {payload.ItemId} : capture {count} de cet objet{if back then ", il revole sur son rayon" else ""}`)
	return back
end

-- Vague 59 (a192, L-184 point 1) : la capture mise en scène chez le joueur attrapé (CatchSceneController). Ce que
-- devient ce qu'il porte, lu au moment de la capture, avant que le portage soit perdu : "Shelf" (revole sur son
-- rayon), "Drop" (tombe au sol, ou perdu : camion) ou "None" (il ne portait rien), et l'objet (ItemId) s'il y en a un.
local function sceneOutcome(player: Player, backToShelf: boolean): (string, string?)
	local okCarry, carrying = pcall(CarryService.IsCarrying, player)
	if not (okCarry and carrying == true) then
		return "None", nil
	end
	local okPayload, payload = pcall(CarryService.GetPayload, player)
	local itemId = if okPayload and type(payload) == "table" and type(payload.ItemId) == "string" then payload.ItemId else nil
	return (if backToShelf then "Shelf" else "Drop"), itemId
end

-- Remote CatchScene, au coup (marqueur Impact de Catch, ou délai de secours) : rien de sensible, la capture est déjà
-- décidée ; `homeIn` = secondes avant le renvoi à la base (nuit, policier), 0 sinon. Aucune règle de jeu ne change.
-- a252 (L-244) : `by` = le modèle de celui qui attrape, pour le plan large de côté de la caméra.
local function sendCatchScene(player: Player, night: boolean, outcome: string, homeIn: number, itemId: string?, by: Model?)
	if player.Parent ~= Players then
		return
	end
	local ok, err = pcall(function()
		Net.Server.CatchScene:Fire(player, night, outcome, homeIn, itemId, by)
	end)
	if not ok then
		warn(`[GuardService] CatchScene vers {player.Name} : {err}`)
	end
end

-- a249 (Chase.Debug) : chaque capture dans la sortie : distance, temps depuis l'apparition du vigile, joueur dans le
-- volume Bounds du magasin du vigile ou dehors, phase de la poursuite. À appeler avant endChase (qui efface la phase).
local function debugCatch(guard: Guard, player: Player, now: number)
	if not chaseDebugOn() then
		return
	end
	local body = bodyOf(player)
	if body == nil then
		return
	end
	local store = guard.store
	local bounds = if store then Find.path(store, BOUNDS) else nil
	local inside = bounds ~= nil and bounds:IsA("BasePart") and insideBox((bounds :: BasePart).CFrame, (bounds :: BasePart).Size, body.Position)
	print(string.format("[ChaseDebug] %s : capture de %s à %.1f studs, %.2f s après l'apparition, %s, phase %s",
		guard.model.Name, player.Name, flat(body.Position - guard.root.Position).Magnitude, now - guard.spawnedAt,
		if inside then "dans son magasin" else "hors de son magasin", tostring(guard.chasePhase)))
end

local function catch(guard: Guard, player: Player)
	local now = os.clock()
	debugCatch(guard, player, now)
	endChase(guard)
	setState(guard, "Catch")
	stop(guard)
	guard.anims:Stop("Run")
	local track = guard.anims:Play("Catch")
	guard.stateEndsAt = now + pauseFor(track, CATCH_PAUSE, CATCH_MAX)
	log(`{guard.label} : {player.Name} rattrapé`)

	-- Colis, étourdissement, message : décidés ici, au moment de la capture, dans leur propre tâche
	-- pour qu'un appel qui attend ne bloque pas les autres vigiles.
	local zone = guard.zone
	local driver = guard.driver
	local message = if driver
		then driver.CaughtMessage
		elseif Zones[zone].SpeedRequired > 0 then `Caught! Recommended speed: {Format.short(Zones[zone].SpeedRequired)}`
		else "Caught!" -- vague 51 (a165) : zone 1, aucune vitesse demandée
	emitCatch(player, zone, false)
	-- Cantin, 2026-11-13 : attrapé dans le magasin d'où vient l'objet, il revole sur son rayon (pas de chute).
	local backToShelf = inItsStore(player)
	if backToShelf then
		log(`{guard.label} : {player.Name} attrapé dans le magasin de son objet, l'objet revole sur son rayon`)
	elseif catchSendsBack(player) then
		backToShelf = true -- a174 : 3e capture de cet objet, même retour qu'une capture dans son magasin
	end
	-- a252 (L-244) : l'objet qui revole passe d'abord par la main du vigile du magasin (Guard/CatchPickUp ; avec
	-- Chase.CatchPickUp.Always, à chaque capture d'un objet de magasin PNJ, qui revole alors toujours).
	local pickUp = GuardService._CatchShow ~= nil and guard.kind == "Day" and driver == nil and GuardService._CatchShow.Wants(player, backToShelf, CarryService)
	if pickUp then
		backToShelf = true
		GuardService._CatchShow.Begin(player, {
			model = guard.model,
			root = guard.root,
			play = function(name: string): AnimationTrack?
				return guard.anims:Play(name)
			end,
			extend = function(untilClock: number)
				if guard.state == "Catch" then
					guard.stateEndsAt = math.max(guard.stateEndsAt, untilClock)
				end
			end,
		}, CarryService)
	end
	-- a114 : l'objet lié qui va tomber reste lié à ce vigile (demi-tour s'il est repris).
	local store = guard.store
	if guard.kind == "Day" and driver == nil and store and not backToShelf then
		local okPayload, carried = pcall(CarryService.GetPayload, player)
		if okPayload and linkable(carried) then
			bindLink(carried, store, guard)
		end
	end

	-- Le coup : au marqueur Impact de Catch (délai de secours : impactMaxWait), ou tout de suite si
	-- Catch n'est pas livrée (pas de geste à attendre). Immobilisé dès la capture (plus bas), le
	-- joueur reste étourdi CatchStunDuration s à partir du coup, comme son client le montre avec
	-- Knockback puis Stunned (ChaseController), et non à partir de la capture.
	-- Policier (L-118 point 3) : Night.SendHomeDelay s après le coup, renvoyé à la base, comme la nuit.
	-- Vague 59 (a192) : au coup, la mise en scène (remote CatchScene) ; placé après le choix du retour au rayon
	-- (même image) pour dire au joueur ce que devient son objet.
	local sendHome = if driver then driver.SendHome else nil
	local outcome, sceneItem = sceneOutcome(player, backToShelf)
	local homeIn = if sendHome then Night.SendHomeDelay else 0
	-- a252 (L-245) : vigile d'un magasin, la nuit, joueur dans le couloir : renvoyé à sa boutique (Chase.DayCatchAtNight*).
	if GuardService._CatchShow ~= nil and sendHome == nil and driver == nil and guard.kind == "Day" then
		local body = bodyOf(player)
		sendHome = GuardService._CatchShow.NightSendHome(player, nightHooks, if body then body.Position else nil)
		homeIn = if sendHome then GuardService._CatchShow.NightSendHomeDelay() else 0
	end
	local function sendHomeLater(caught: Player)
		if sendHome == nil then
			return
		end
		local send: (player: Player) -> boolean = sendHome
		task.delay(homeIn, function()
			if caught.Parent == Players then
				local ok, err = pcall(send, caught)
				if not ok then
					warn(`[GuardService] SendHome({caught.Name}) après la police : {err}`)
				end
			end
		end)
	end
	if track then
		guard.knockTarget = player
		guard.onKnock = function(caught: Player)
			stun(caught, Balance.Guard.CatchStunDuration)
			if pickUp then
				GuardService._CatchShow.Impact(caught) -- a252
			end
			sendCatchScene(caught, false, outcome, homeIn, sceneItem, guard.model)
			sendHomeLater(caught)
		end
		task.delay(impactMaxWait(track), function()
			if guard.knockTarget == player then
				releaseKnockback(guard)
			end
		end)
	else
		knockback(player, guard.root.Position)
		if pickUp then
			GuardService._CatchShow.Impact(player) -- a252
		end
		sendCatchScene(player, false, outcome, homeIn, sceneItem, guard.model)
		sendHomeLater(player)
	end

	task.spawn(function()
		-- a252 : objet en route vers la main du vigile : CatchPickUp le rend lui-même (FailNoDrop) à la fin.
		if not pickUp then
			local fail = if backToShelf then CarryService.FailNoDrop else CarryService.Fail
			local ok, err = pcall(fail :: any, player, "Caught")
			if not ok then
				warn(`[GuardService] CarryService.Fail({player.Name}, "Caught") : {err}`)
			end
		end
		stun(player, Balance.Guard.CatchStunDuration)
		if message and player.Parent == Players then
			Net.Server.Notify:Fire(player, message, "Alert")
		end
	end)
end

-- Attrapé la nuit (5.12) : immobilisé tout de suite, colis rendu, le même coup que le jour, puis
-- renvoyé chez lui et étourdi Night.CaughtStunDuration s. Aucune autre perte.
local function nightCatch(guard: Guard, player: Player)
	local now = os.clock()
	local hooks = nightHooks
	debugCatch(guard, player, now)
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
	local sendsBack = catchSendsBack(player) -- a174
	local outcome, sceneItem = sceneOutcome(player, sendsBack) -- vague 59 : remote CatchScene, plus bas
	local fail = if sendsBack then CarryService.FailNoDrop else CarryService.Fail
	task.spawn(function()
		local ok, err = pcall(fail :: any, player, "Caught")
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
			Net.Server.Notify:Fire(caught, MESSAGES.NightCaught, "Alert")
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
		local wait = math.max(length - Night.SendHomeDelay, 0)
		sendCatchScene(player, true, outcome, wait + Night.SendHomeDelay, sceneItem, guard.model) -- vague 59 : pas de coup, tout de suite
		task.delay(wait, sendHome, player)
		return
	end

	-- Le coup : au marqueur Impact de Catch (délai de secours : impactMaxWait), ou tout de suite si
	-- Catch n'est pas livrée. Vague 59 : la mise en scène part au coup (renvoi Night.SendHomeDelay s après).
	if track then
		guard.knockTarget = player
		guard.onKnock = function(caught: Player)
			sendCatchScene(caught, true, outcome, Night.SendHomeDelay, sceneItem, guard.model)
			sendHome(caught)
		end
		task.delay(impactMaxWait(track), function()
			if guard.knockTarget == player then
				releaseKnockback(guard)
			end
		end)
	else
		knockback(player, guard.root.Position)
		sendCatchScene(player, true, outcome, Night.SendHomeDelay, sceneItem, guard.model)
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

-- Conducteur du camion : la cible vaut-elle encore la poursuite ? Une erreur du crochet compte pour non.
local function driverKeeps(driver: DriverChase, player: Player): boolean
	local ok, result = pcall(driver.Keeps, player)
	if not ok then
		warnOnce("hook:Keeps", `conducteur : Keeps({player.Name}) : {result}`)
		return false
	end
	return result == true
end

-- Vitesse du conducteur : la WalkSpeed actuelle de sa cible × SpeedMultiplier, au moins MinSpeed.
local function driverSpeed(driver: DriverChase, targetHumanoid: Humanoid): number
	local speed = targetHumanoid.WalkSpeed * driver.SpeedMultiplier
	return math.max(if isPositiveNumber(speed) then speed else 0, driver.MinSpeed)
end

-- Boucle ----------------------------------------------------------------------------------

-- Vitesse au sol de la cible (AssemblyLinearVelocity, à plat), lissée par une moyenne exponentielle sur
-- environ VELOCITY_SMOOTHING s : un écart d'un instant (zigzag, petit pas de côté) ne déplace presque
-- pas le point d'interception, une vraie course dans une direction, si. Mesurée à chaque pas de poursuite,
-- en vue ou non. Bornée à la WalkSpeed de la cible (une poussée, un téléport ne comptent pas) : 0 si
-- elle est immobilisée.
local function sampleVelocity(guard: Guard, targetRoot: BasePart, targetHumanoid: Humanoid, now: number): Vector3
	local raw = flat(targetRoot.AssemblyLinearVelocity)
	local cap = targetHumanoid.WalkSpeed
	local magnitude = raw.Magnitude
	if not isPositiveNumber(cap) or not isPositiveNumber(magnitude) then
		raw = Vector3.zero
	elseif magnitude > cap then
		raw = raw * (cap / magnitude)
	end
	local previous = guard.chaseVelocity
	local at = guard.chaseVelocityAt
	local smoothed = raw
	if previous ~= nil and at ~= nil then
		local alpha = 1 - math.exp(-math.max(now - at, 0) / VELOCITY_SMOOTHING)
		smoothed = previous + (raw - previous) * alpha
	end
	guard.chaseVelocity = smoothed
	guard.chaseVelocityAt = now
	return smoothed
end

-- Rattrapage en ligne droite : le plus petit t > 0 tel que |offset + velocity·t| = speed·t, où offset va
-- du vigile à la cible (à plat), velocity est celle de la cible et speed celle du vigile. Le vigile qui
-- court droit vers offset + velocity·t y arrive en même temps qu'elle. nil sans solution (cible plus
-- rapide qui s'éloigne).
local function interceptTime(offset: Vector3, velocity: Vector3, speed: number): number?
	local a = velocity:Dot(velocity) - speed * speed
	local b = 2 * offset:Dot(velocity)
	local c = offset:Dot(offset)
	if math.abs(a) < 1e-6 then
		return if b < 0 then -c / b else nil
	end
	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then
		return nil
	end
	local root = math.sqrt(discriminant)
	local t1 = (-b - root) / (2 * a)
	local t2 = (-b + root) / (2 * a)
	local low, high = math.min(t1, t2), math.max(t1, t2)
	if low > 0 then
		return low
	elseif high > 0 then
		return high
	end
	return nil
end

-- Le point d'interception (Cantin, 2026-11-11 : il nous coupe la route) : là où le vigile, en ligne droite
-- à sa WalkSpeed, retrouve la cible qui garde sa vitesse lissée ; au plus INTERCEPT_MAX_TIME s devant
-- elle. Jamais en zone safe, jamais derrière un mur vu de la cible et, si `kneeDrop` est donné (en vue),
-- toujours en vue du vigile (les deux rayons de canSee) : sinon il essaie la moitié du chemin, puis vise
-- la cible elle-même. Sans solution (cible plus rapide qui s'éloigne) : la cible.
local function interceptPoint(guard: Guard, targetRoot: BasePart, velocity: Vector3, kneeDrop: number?, at: Vector3?): Vector3
	local position = at or targetRoot.Position -- a193 : la position estimée du voleur, si donnée
	local from = guard.root.Position
	local found = interceptTime(flat(position - from), velocity, guard.humanoid.WalkSpeed)
	if found == nil then
		return position
	end
	local t = math.min(found, INTERCEPT_MAX_TIME)
	for _ = 1, 2 do
		local aim = position + velocity * t
		if not isInSafeZone(aim) and clearLine(position, aim) then
			if kneeDrop == nil then
				return aim
			end
			local fromKnee = from - Vector3.new(0, guard.rootHeight - KNEE_HEIGHT, 0)
			if clearLine(from, aim) and clearLine(fromKnee, aim - Vector3.new(0, kneeDrop, 0)) then
				return aim
			end
		end
		t /= 2
	end
	return position
end

-- En vue (Cantin, 2026-11-11) : droit sur le point d'interception, recalculé toutes les
-- CHASE_REAIM_INTERVAL s, tout de suite quand la vue revient (pas de point visé) ou quand il atteint le
-- point visé. Un nouveau MoveTo seulement si le point a bougé d'au moins AIM_MIN_CHANGE studs (pas
-- d'à-coups), ou au bout d'AIM_REFRESH s. Un joueur qui passe derrière lui : le point bascule de son
-- côté au calcul suivant (≤ 0,1 s), et le vigile coupe vers où il va au lieu de refaire son trajet.
local function chaseInSight(guard: Guard, targetRoot: BasePart, targetHumanoid: Humanoid, velocity: Vector3, now: number, targetAt: Vector3?)
	guard.waypoints = nil -- jamais un point de chemin périmé quand il voit sa cible
	guard.lastSeen = targetRoot.Position
	if guard.standingStill == true or flat(targetRoot.AssemblyLinearVelocity).Magnitude < 0.5 then
		guard.seenStill = true -- a250b : approachCap
	end
	local aim = guard.chaseAim
	local reached = aim ~= nil and flat(aim - guard.root.Position).Magnitude <= WAYPOINT_REACHED
	if aim ~= nil and now < guard.nextAimAt and not reached then
		return -- le MoveTo en cours suit son cours
	end
	guard.nextAimAt = now + CHASE_REAIM_INTERVAL
	local kneeDrop = targetHumanoid.HipHeight + targetRoot.Size.Y / 2 - KNEE_HEIGHT
	local fresh = interceptPoint(guard, targetRoot, velocity, kneeDrop, targetAt)
	if aim == nil or reached or flat(fresh - aim).Magnitude >= AIM_MIN_CHANGE or now >= (guard.chaseAimAt or 0) + AIM_REFRESH then
		guard.chaseAim = fresh
		guard.chaseAimAt = now
		moveTo(guard, fresh)
	end
end

-- Derrière un obstacle (L-091 point 1) : un chemin vers `goal` (le point d'interception vu de la cible,
-- sinon la cible), calculé seulement s'il n'en a pas, s'il est au bout, ou si `goal` s'est éloigné de
-- PATH_GOAL_DRIFT studs du but du chemin ; au plus un
-- calcul toutes les Balance.Guard.PathRecomputeInterval s. En attendant le premier, il court au
-- dernier endroit où il l'a vue (il le voyait : en ligne droite), jamais droit dans le mur.
local function chaseBehindObstacle(guard: Guard, goal: Vector3, now: number)
	local waypoints = guard.waypoints
	local pathGoal = guard.pathGoal
	local stale = waypoints == nil
		or pathGoal == nil
		or guard.waypointIndex > #waypoints
		or flat(goal - pathGoal).Magnitude > PATH_GOAL_DRIFT
	if stale and now >= guard.nextPathAt and not guard.computing then
		guard.nextPathAt = now + Balance.Guard.PathRecomputeInterval
		computePath(guard, goal)
	end
	local lastSeen = guard.lastSeen
	if guard.waypoints == nil and lastSeen then
		local from = guard.root.Position
		if flat(lastSeen - from).Magnitude > WAYPOINT_REACHED and clearLine(from, lastSeen) then
			moveTo(guard, lastSeen)
			return
		end
		guard.lastSeen = nil -- atteint ou caché : le chemin prend le relais
	end
	followPath(guard, goal, true)
end

-- a249 (Chase.StuckCatch ; Play de fusion68, Supérette : voleur coincé contre un rayon jamais attrapé, le vigile à
-- 2,2 studs, Shelf_A_EndA coupant chaque rayon de CatchReach.CanTouch) : la cible n'a pas bougé de Chase.StuckMoveMax
-- studs à l'horizontale (sa position sur le serveur, jamais une vitesse voulue) depuis Chase.StuckCatchTime s.
-- Suivi à chaque pas de poursuite ; remis à zéro au départ de chaque poursuite (startChase). Une cible qui n'avance plus
-- est aussi approchée comme une cible arrêtée (approachCap), même si sa vitesse se lit encore non nulle.
-- a249b (banc a146 : « jamais à travers un mur ni un plancher ») : attrapable sans ligne de vue seulement si le vigile
-- non plus n'a pas bougé de Chase.StuckMoveMax studs depuis Chase.StuckCatchTime s (un vigile qui passe derrière le
-- mur ou en fait le tour bouge), à portée (CatchReach.InRange), au même étage (Chase.StuckHeightMax) et si la ligne
-- entre eux ne traverse pas plus de Chase.StuckWallMax studs de pièces qui bloquent (du premier obstacle vu du vigile
-- au premier vu de la cible : un panneau de rayon, son épaisseur ; un mur double, tout l'écart). Une seule fonction :
-- GuardService est à la limite des 200 variables locales d'un bloc Luau.
local function stuckCatchable(guard: Guard, targetRoot: BasePart, catchDistance: number, now: number): boolean
	local moveMax = if isPositiveNumber(Chase.StuckMoveMax) then Chase.StuckMoveMax else 0
	local wait = math.max(Chase.StuckCatchTime, 0)
	local to = targetRoot.Position
	local from = guard.root.Position
	local still = false
	local anchor, since = guard.stuckFrom, guard.stuckSince
	if anchor == nil or since == nil or flat(to - anchor).Magnitude > moveMax then
		guard.stuckFrom, guard.stuckSince = to, now
	else
		still = now - since >= wait
	end
	guard.standingStill = still
	if not still and flat(targetRoot.AssemblyLinearVelocity).Magnitude >= 0.5 then
		guard.seenStill = nil -- il repart
	end
	-- Le vigile est-il bloqué ? `moved` : ce qu'il a parcouru sur les `elapsed` dernières s (au moins StuckCatchTime).
	local moved, elapsed = math.huge, 0
	anchor, since = guard.blockedFrom, guard.blockedSince
	local share = Chase.StuckProgressShare
	if isPositiveNumber(share) then
		-- a250 (Play de fusion68 : un vigile qui marchait encore à 3 studs/s passait pour bloqué) : fenêtre glissante
		-- sur les dernières Chase.StuckCatchTime s, une position par pas.
		local trail = guard.blockedTrail or {}
		guard.blockedTrail = trail
		table.insert(trail, { at = now, position = from })
		while #trail >= 2 and trail[2].at <= now - wait do
			table.remove(trail, 1)
		end
		local oldest = trail[1]
		if now - oldest.at >= wait then
			moved, elapsed = flat(from - oldest.position).Magnitude, now - oldest.at
		end
	elseif anchor == nil or since == nil or flat(from - anchor).Magnitude > moveMax then
		guard.blockedFrom, guard.blockedSince = from, now
	elseif now - since >= wait then
		moved = 0
	end
	if not (still and moved <= moveMax and CatchReach.InRange(from, to, catchDistance) and math.abs(to.Y - from.Y) <= Chase.StuckHeightMax) then
		return false
	end
	local direction = to - from
	local length = direction.Magnitude
	local forward = if length >= 1e-3 then Workspace:Raycast(from, direction, rayParams) else nil
	if forward == nil then
		-- a250b (Play de fusion69 : les cas 2 et 3 tirent en sens contraire) : en terrain ouvert, bloqué seulement s'il a
		-- parcouru au plus Chase.StuckProgressShare de ce que sa marche (au moins ApproachMinClosing) lui ferait
		-- parcourir (il avance encore librement vers le voleur : pas de capture « coincé ») ; derrière un panneau de
		-- rayon (plus bas), StuckMoveMax studs en StuckCatchTime s suffisent : il longe le rayon, la règle de fusion68
		-- (capture 0,02 s après les 4 studs).
		return not isPositiveNumber(share) or moved <= share * math.max(guard.humanoid.WalkSpeed, Chase.ApproachMinClosing) * elapsed
	end
	local backward = Workspace:Raycast(to, -direction, rayParams)
	if backward == nil or (backward.Position - forward.Position):Dot(direction / length) > Chase.StuckWallMax then
		return false
	end
	-- a250 (Play de fusion68, Confiserie : attrapé à travers la porte vitrée DoorGlass_L, 0,3 stud) : le panneau mince
	-- doit être un rayon des deux côtés (la pièce touchée ou un de ses parents a un nom qui commence par
	-- Chase.StuckThinPrefix) ; une porte, une vitrine, un mur, un frigo ou un comptoir reste un mur, quelle que soit
	-- son épaisseur.
	-- Chase.StuckThinPrefix = "" : tout panneau mince, la règle d'avant.
	local prefix = Chase.StuckThinPrefix
	if #prefix == 0 then
		return true
	end
	for _, hit in { forward.Instance, backward.Instance } do
		local node: Instance? = hit
		while node ~= nil and node ~= Workspace and string.sub(node.Name, 1, #prefix) ~= prefix do
			node = node.Parent
		end
		if node == nil or node == Workspace then
			return false
		end
	end
	return true
end

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
	-- a249 (Play de fusion67 : le vigile de nuit attrape, le vigile de jour « rattrape » 1,3 s après) : un joueur
	-- immobilisé par une capture (stun), ou attrapé la nuit et pas encore renvoyé, n'est plus poursuivi.
	if Chase.OneCatchAtATime and (stunTokens[player] ~= nil or caughtAtNight[player] == true) then
		giveUp(guard, "déjà attrapé")
		return
	end
	local night = guard.kind == "Night"
	local driver = guard.driver
	if night then
		local reason = nightRefusal(player, targetRoot.Position)
		if reason then
			giveUp(guard, reason)
			return
		end
	elseif driver then
		if not driverKeeps(driver, player) then
			giveUp(guard, driver.GiveUpReason or "ne porte plus le colis du camion")
			return
		end
	elseif guard.intruder then
		-- Cantin, 2026-11-13 : l'intrus resté sans objet à la fin du chrono n'est poursuivi que
		-- Balance.Guard.IntruderChaseTime s ; s'il prend un objet, la course passe avant tout : poursuite de
		-- porteur, sans fin (il n'est plus traité en intrus).
		if CarryService.IsCarrying(player) then
			guard.intruder = false
			guard.intruderUntil = nil
			log(`{guard.label} : l'intrus {player.Name} a pris un objet, poursuite sans fin`)
		else
			local untilAt = guard.intruderUntil
			if untilAt == nil then
				guard.intruderUntil = now + Balance.Guard.IntruderChaseTime
			elseif now >= untilAt then
				giveUp(guard, `intrus sans objet, {Balance.Guard.IntruderChaseTime} s de poursuite`)
				return
			end
		end
	elseif not CarryService.IsCarrying(player) then
		giveUp(guard, "ne porte plus d'objet")
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
	-- Audit du 2026-11-14 (a146) : distance à l'horizontale avec un écart en hauteur toléré, et la ligne de
	-- vue, ou perché sur un meuble bas, ou dans un mur (shared/CatchReach) : voler ou traverser les murs
	-- ne protège plus.
	local catchDistance = if night then Night.CatchDistance else Balance.Guard.CatchDistance
	-- a193 (T-069) : portée mesurée jusqu'à la position estimée du voleur (Chase.LagCompensation), ou au contact
	-- de sa copie sur le serveur (Chase.LagContactReach : un vigile qui bute contre elle).
	local targetAt = estimatedPosition(player, targetRoot, targetHumanoid)
	local touch, how = false, ""
	if CatchReach.InRange(guard.root.Position, targetAt, catchDistance)
		or (targetAt ~= targetRoot.Position and CatchReach.InRange(guard.root.Position, targetRoot.Position, Chase.LagContactReach))
	then
		touch, how = CatchReach.CanTouch(guard.root.Position, targetRoot, rayParams)
	end
	-- a249 (Chase.StuckCatch) : un voleur qui pousse contre un obstacle sans avancer est attrapé comme un voleur
	-- arrêté, même sans ligne de vue (le vigile de nuit garde la règle d'avant) ; a249b : seulement le vigile bloqué
	-- lui aussi, au même étage, derrière un panneau mince (jamais à travers un mur ni un plancher).
	if Chase.StuckCatch == true and not night and stuckCatchable(guard, targetRoot, catchDistance, now) and not touch then
		touch, how = true, "coincé, il n'avance plus"
	end
	if touch then
		if how ~= "vue" then
			log(`{guard.label} : {player.Name} attrapé ({how})`)
		end
		if night then
			nightCatch(guard, player)
		else
			catch(guard, player)
		end
		return
	end
	-- Nouvelle poursuite (vague 45) : la fin de la ruée se teste à chaque image, pas au rythme du pilotage.
	local distanceRule = guard.chasePhase ~= nil
	if distanceRule then
		distanceRuleStep(guard, player, targetAt, targetRoot, targetHumanoid, now)
	end
	-- Poursuite sans fin (Cantin, 2026-11-11) : ni temps de poursuite ni avance ne la font abandonner.
	if now < guard.nextSteerAt then
		return
	end
	guard.nextSteerAt = now + CHASE_STEER_INTERVAL
	if driver and not distanceRule then
		-- Toujours un peu plus vite que sa cible, même si elle accélère en route.
		local speed = driverSpeed(driver, targetHumanoid)
		if math.abs(speed - guard.speed) > 0.05 then
			guard.speed = speed
			setWalkSpeed(guard, speed)
		end
	end
	-- Ligne de vue à chaque pas : en vue, droit sur le point d'interception (chaseInSight) ; sinon un
	-- chemin vers ce point (vu de la cible : jamais derrière un mur ni en zone safe).
	local velocity = sampleVelocity(guard, targetRoot, targetHumanoid, now)
	if guard.chasePhase == "Rush" then
		-- Ruée : droit sur le voleur (vitesse visée nulle), pas sur un point devant lui, pour arriver
		-- derrière lui et non lui couper la route à 3 fois sa vitesse.
		velocity = Vector3.zero
	end
	local sees = canSee(guard, targetRoot, targetHumanoid)
	if chaseDebugOn() then
		-- Diagnostic Studio (retard du vigile, 2026-11-11) : une ligne par seconde et par vigile.
		local found: ChaseTrace? = guardDebug[guard]
		if found == nil then
			local fresh: ChaseTrace = { sight = 0, path = 0, last = now, hits = {} }
			guardDebug[guard] = fresh
			found = fresh
		end
		local trace = found :: ChaseTrace
		if sees then
			trace.sight += 1
		else
			trace.path += 1
			local hit = Workspace:Raycast(guard.root.Position, targetRoot.Position - guard.root.Position, rayParams)
			if hit then
				local name = hit.Instance:GetFullName()
				trace.hits[name] = (trace.hits[name] or 0) + 1
			end
		end
		if now - trace.last >= 1 then
			trace.last = now
			local hits = {}
			for name, count in trace.hits do
				table.insert(hits, `{name} ×{count}`)
			end
			print(string.format("[ChaseDebug] %s : distance %.1f, joueur %.1f studs/s (WalkSpeed %.0f), vigile WalkSpeed %.0f, estimée à %.1f (retard %.0f ms), en vue %d, au chemin %d%s",
				guard.model.Name, (targetRoot.Position - guard.root.Position).Magnitude, flat(targetRoot.AssemblyLinearVelocity).Magnitude,
				targetHumanoid.WalkSpeed, guard.humanoid.WalkSpeed, flat(targetAt - guard.root.Position).Magnitude, lagSeconds(player) * 1000,
				trace.sight, trace.path,
				if #hits > 0 then " ; vue bloquée par " .. table.concat(hits, ", ") else ""))
			if guard.chasePhase ~= nil then
				-- a249 : phase, distance prévue et parts de la vitesse (règle de distance).
				print(string.format("[ChaseDebug] %s : phase %s%s, prévue %.1f, marche %.1f, rapprochement %.2f, depuis l'apparition %.1f s",
					guard.model.Name, guard.chasePhase, if springReturn(guard) then " (retour doux)" else "",
					guard.holdTarget or Chase.HoldDistance, targetHumanoid.WalkSpeed, closingSpeed(guard, player), now - guard.spawnedAt))
			end
			trace.sight, trace.path, trace.hits = 0, 0, {}
		end
	end
	if sees then
		chaseInSight(guard, targetRoot, targetHumanoid, velocity, now, targetAt)
		return
	end
	guard.chaseAim = nil
	chaseBehindObstacle(guard, interceptPoint(guard, targetRoot, velocity, nil, targetAt), now)
end

-- Colis tombé au sol (6.2) : le vigile court vers l'endroit du coup et attend à côté qu'on le
-- ramasse (retarget) ou qu'il reparte vers son rayon (giveUp). Aucune capture ici.
local function followStep(guard: Guard, now: number)
	if now >= guard.stateEndsAt then
		giveUp(guard, `{Bat.DroppedLifetime + FOLLOW_MARGIN} s sans nouvelles de l'objet au sol`)
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
	guard.patrolStepAt = now
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
	-- a173 (2026-11-15, Play de fusion48) : le serveur gèle 1 à 8 s à la tombée de la nuit ; ce temps sans
	-- image ne compte pas comme une ronde sans progrès (sinon les 12 vigiles se disent « bloqués » ensemble).
	local lastStep = guard.patrolStepAt
	guard.patrolStepAt = now
	if lastStep and now - lastStep > PATROL_LONG_FRAME then
		guard.progressAt += now - lastStep
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

-- Potion d'invisibilité (GuardService.IsHiddenFromNight, voir l'en-tête) : une erreur compte pour false.
local function hiddenFromNight(player: Player): boolean
	local ok, hidden = pcall(GuardService.IsHiddenFromNight, player)
	if not ok then
		warnOnce("hook:IsHiddenFromNight", `IsHiddenFromNight : {hidden} (joueur visible)`)
		return false
	end
	return hidden == true
end

-- Le joueur le plus proche que ce vigile de nuit repère (voir l'en-tête), ou nil.
local function scan(guard: Guard): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		if nightChasedBy[player] == nil and not caughtAtNight[player] and not RevealState.IsProtected(player) then
			local root, humanoid = bodyOf(player)
			if root and humanoid then
				local offset = root.Position - guard.root.Position
				local distance = offset.Magnitude
				if
					distance <= Night.DetectionRange
					and distance < bestDistance
					and inCone(guard, offset)
					and nightRefusal(player, root.Position) == nil
					and not hiddenFromNight(player)
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
	guard.stateEndsAt = now + REACTION_DELAY
	nightChasedBy[player] = guard
	guard.model:SetAttribute(TARGET_ATTRIBUTE, player.UserId)
	pcall(function()
		guard.model:AddPersistentPlayer(player)
	end)
	refreshChaseState(player)
	local root = bodyOf(player)
	local distance = if root then (root.Position - guard.root.Position).Magnitude else 0
	log(`{guard.label} : repère {player.Name} à {Format.short(distance)} studs, {chaseSpeedText(guard, player, `poursuite à {Format.short(guard.speed)}`)}`)
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
		if GuardService._PathAvoid then
			GuardService._PathAvoid.BeforeJump(guard.humanoid, waypoints, index, guard.root.Position.Y - guard.rootHeight) -- f70c3
		end
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
	-- Vague 62 (Features.SingleBoxReveal) : cible protégée par sa cinématique d'ouverture (attribut RevealProtected) :
	-- figé pour elle avant le départ et en poursuite (ni départ, ni pas, ni capture) ; ensuite il reprend, le temps
	-- de la pause rendu (départ, fin de poursuite de l'intrus), sa poursuite relancée.
	local frozenFor = guard.target
	if (state == "Wait" or state == "Chase") and frozenFor and RevealState.IsProtected(frozenFor) then
		if guard.revealFrozenAt == nil then
			guard.revealFrozenAt = now
			-- a250 (Play de fusion68 : il glissait encore de 4 à 5 studs sur son élan, puis revenait au point du
			-- MoveTo) : son élan à l'horizontale est coupé avant l'arrêt, il s'arrête net.
			local velocity = guard.root.AssemblyLinearVelocity
			guard.root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
			stop(guard)
			guard.anims:Stop("Run")
			guard.anims:Stop("Walk")
			log(`{guard.label} : figé, {frozenFor.Name} est dans sa cinématique d'ouverture`)
		end
		return
	end
	local frozenAt = guard.revealFrozenAt
	if frozenAt then
		guard.revealFrozenAt = nil
		guard.stuckFrom = nil -- a249 : figé dans la cinématique, ce n'est pas « coincé »
		guard.standingStill = nil
		guard.seenStill = nil
		guard.stillCap = nil
		guard.blockedFrom = nil
		guard.blockedTrail = nil
		local paused = now - frozenAt
		guard.stateEndsAt += paused
		local until_ = guard.intruderUntil
		if until_ then
			guard.intruderUntil = until_ + paused
		end
		if Chase.WaitAfterReveal then
			-- a249 (Cantin, 2026-11-17, L-235 décision 2 ; Play du 17/11 : il repartait dans l'image où la
			-- cinématique finissait) : il repart Chase.StartDelay s plus tard, sans capture avant (Wait).
			if state == "Chase" then
				setState(guard, "Wait")
				guard.stateEndsAt = now + startDelay()
			else
				guard.stateEndsAt = math.max(guard.stateEndsAt, now + startDelay())
			end
		elseif state == "Chase" then
			startChase(guard, now)
		end
		log(`{guard.label} : reprend après {math.round(paused * 10) / 10} s de cinématique`)
		return
	end
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
		if root and isInSafeZone(root.Position) then
			giveUp(guard, "zone safe, avant le départ") -- a157 : tous les genres (jour, nuit, policier, conducteur)
		elseif night then
			local reason = if player == nil or root == nil then "plus de cible" else nightRefusal(player, root.Position)
			if reason then
				giveUp(guard, `{reason}, avant le départ`)
			elseif now >= guard.stateEndsAt then
				startChase(guard, now)
			end
		elseif guard.driver then
			local driver = guard.driver :: DriverChase
			if player == nil or root == nil or not driverKeeps(driver, player) then
				giveUp(guard, if driver.GiveUpReason then `{driver.GiveUpReason}, avant le départ` else "plus de colis du camion avant le départ")
			elseif now >= guard.stateEndsAt then
				startChase(guard, now)
			end
		elseif player == nil or root == nil or (not guard.intruder and not CarryService.IsCarrying(player)) then
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
			-- a114 : son objet lié a été repris pendant Catch : il repart vers le porteur au lieu de rentrer.
			local carrier = if state == "Catch" then linkedCarrier(guard) else nil
			if carrier then
				retargetLinked(guard, carrier)
			elseif not (state == "Catch" and followAfterCatch(guard)) then
				-- Sinon (Cantin, 2026-11-13) : l'objet tombé à la capture est au sol, il va le garder (Follow).
				releaseFollow(guard)
				startReturn(guard, now)
			end
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
	if #guards == 0 and #nightGuards == 0 and #driverGuards == 0 then
		return
	end
	refreshRayFilter()
	local now = os.clock()
	for _, list in { guards, nightGuards, driverGuards } do
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
			return (value :: number) * REAL_SPEED_SCALE -- vague 61 : la vitesse imposée est à l'échelle 1
		end
		warn(`[GuardService] GetSpeedOverride({player.Name}) invalide ({value}) : vitesse de la zone`)
	end
	return Zones[zone].GuardSpeed -- déjà × RealSpeedScale (Config/Zones)
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
local function spawnGuard(player: Player, store: Model, zone: number, template: Model, label: string, intruder: boolean?): Guard?
	if chasedBy[player] ~= nil then
		return nil -- un vigile par voleur (Balance.Guard.PerThief)
	end
	if countChasing(store) >= Balance.Guard.MaxPerStore then
		log(`{store.Name} : déjà {Balance.Guard.MaxPerStore} vigiles en poursuite, pas de vigile pour {player.Name}`)
		return nil
	end
	if countActive() >= Balance.Guard.MaxActivePerServer and not freeSlot() then
		log(`déjà {Balance.Guard.MaxActivePerServer} vigiles en poursuite sur le serveur (9.7), pas de vigile pour {player.Name}`)
		return nil
	end

	local model = template:Clone()
	local humanoid, root = prepare(model, label)
	if humanoid == nil or root == nil then
		warnOnce(`bad:{label}`, `{label} : Humanoid ou HumanoidRootPart manquant, vigile non créé`)
		model:Destroy()
		return nil
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
		owner = player,
		intruder = intruder == true,
		nextAimAt = now,
		patrol = {},
		patrolIndex = 1,
		patrolStep = 1,
		pauseUntil = 0,
		onKnock = nil,
		nextScanAt = 0,
		stateEndsAt = now + startDelay(), -- a249 : Chase.StartDelay (vigile du magasin)
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
		`vigile ({label}) lancé sur {player.Name} depuis {store.Name}, zone {zone}, {chaseSpeedText(guard, player, `vitesse {Format.short(guard.speed)}`)}, {sizeText(scale, agent)} ({#guards} en jeu)`
	)
	return guard
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
		speed = nightChaseSpeed(zone),
		target = nil,
		state = "Patrol",
		spawnedAt = now,
		owner = nil,
		nextAimAt = now,
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
	log(`{guard.label} ({label}) en ronde, zone {zone}, {#points} point(s), {chaseSpeedText(guard, nil, `poursuite à {Format.short(guard.speed)}`)}, {sizeText(scale, agent)}`)
end

-- Conducteurs du camion (L-083 point 3) -----------------------------------------------------------

-- Pose un conducteur sur chase.Spawn et le lance sur chase.Target (Wait : REACTION_DELAY s, puis
-- Chase). N'attend pas. Renvoie sa copie, ou nil.
local function spawnDriver(chase: DriverChase): Model?
	local player = chase.Target
	if driverChasedBy[player] ~= nil then
		return nil -- un conducteur par porteur
	end
	local targetRoot, targetHumanoid = bodyOf(player)
	if targetRoot == nil or targetHumanoid == nil then
		return nil
	end
	local label = chase.Template:GetFullName()
	if not isUsable(chase.Template) then
		warnOnce(`bad:{label}`, `{label} : Humanoid ou HumanoidRootPart manquant (10.4), conducteur non créé`)
		return nil
	end
	local model = chase.Template:Clone() :: Model? -- nil si le modèle n'est pas Archivable
	if model == nil then
		warnOnce(`archivable:{label}`, `{label} n'est pas Archivable : conducteur non créé`)
		return nil
	end
	model.Name = chase.Name
	local humanoid, root = prepare(model, label)
	if humanoid == nil or root == nil then
		model:Destroy()
		return nil
	end
	local scale = scaleOf(model)
	local agent = agentFor(model)

	-- Pieds sur le point d'apparition, tourné vers sa cible.
	local base = chase.Spawn.Position
	local look = flat(targetRoot.Position - base)
	local frame = if look.Magnitude > 1e-3 then CFrame.lookAt(base, base + look.Unit) else chase.Spawn
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
		anims = AnimPlayer.new(
			animator :: Animator,
			AnimPlayer.modelFolder(model),
			if chase.Tired then Animations.Guard else Animations.Driver,
			if chase.Label then chase.Label else DRIVER_ANIM_LABEL
		),
		kind = "Driver",
		label = `{chase.Label or "conducteur"} {model.Name}`,
		store = nil,
		home = frame.Position,
		zone = chase.Zone,
		speed = driverSpeed(chase, targetHumanoid),
		target = player,
		state = "Wait",
		spawnedAt = now,
		owner = nil,
		nextAimAt = now,
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
		driver = chase,
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

	table.insert(driverGuards, guard)
	driverChasedBy[player] = guard
	refreshChaseState(player)
	log(
		`{guard.label} lancé sur {player.Name}, zone {chase.Zone}, {chaseSpeedText(guard, player, `vitesse {Format.short(guard.speed)} ({if chase.SpeedMultiplier > 0 then `× {Format.short(chase.SpeedMultiplier)} la sienne` else "fixe"})`)}, {sizeText(scale, agent)}`
	)
	return model
end

-- Colis tombé au sol (6.2) ----------------------------------------------------------------------

-- L'objet de `owner` vient de tomber à `position` (coup de batte, ou capture : la cible est alors
-- déjà vide, d'où `owner`) : le vigile le suit.
local function followDrop(guard: Guard, payload: any, position: Vector3, owner: Player?)
	local player = owner or guard.target
	guard.followOwner = nil
	endChase(guard)
	local now = os.clock()
	setState(guard, "Follow")
	guard.followPayload = payload
	guard.followPosition = position
	following[payload] = guard
	local store = guard.store
	if store then
		bindLink(payload, store, guard) -- a114 : l'objet reste lié à ce vigile (même vigile à la reprise)
	end
	guard.stateEndsAt = now + Bat.DroppedLifetime + FOLLOW_MARGIN
	guard.nextSteerAt = now
	guard.nextPathAt = now
	guard.anims:Stop("Walk")
	setWalkSpeed(guard, guard.speed) -- encore à 0 s'il ne s'était pas élancé (Wait)
	log(`{guard.label} : l'objet de {if player then player.Name else "?"} est tombé au sol, il va vers lui`)
end

-- Le colis que suit le vigile vient d'être ramassé par `player` : nouvelle poursuite, comme un
-- vigile qui vient d'apparaître (Wait : REACTION_DELAY s sans capture, puis Chase).
local function retarget(guard: Guard, player: Player)
	-- Vague 53 (point d'a157) : ramassé en zone safe, aucune poursuite ne repart ; le vigile qui suivait le
	-- colis au sol l'abandonne et rentre, celui qui rentrait continue.
	local body = bodyOf(player)
	if body and isInSafeZone(body.Position) then
		giveUp(guard, `{player.Name} est en zone safe`)
		return
	end
	local other = chasedBy[player]
	if other and other ~= guard then
		giveUp(other, "cible reprise par le vigile de l'objet ramassé")
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
	guard.anims:Stop("Walk") -- a114 : demi-tour pendant son retour
	guard.anims:Stop("Tired")
	guard.speed = chaseSpeed(player, guard.zone)
	guard.stateEndsAt = now + startDelay() -- a249 : Chase.StartDelay, comme à l'apparition
	refreshChaseState(player)
	log(`{guard.label} : change de cible, poursuit {player.Name} qui a ramassé l'objet (vitesse {Format.short(guard.speed)})`)
end

-- Un vigile de jour de `store` sort du GuardSpawn pour le porteur `player` de `payload` (colis de l'ancien
-- déroulé, ou objet NPCItem : lié à ce vigile). Peut attendre (rig de remplacement) : à appeler hors de
-- l'appel de CarryService. Revérifie après l'attente que `player` porte toujours `payload`.
local function spawnForCarrier(player: Player, payload: any, store: Model)
	local zone = payload.Zone
	if type(zone) ~= "number" or Zones[zone] == nil then
		zone = store:GetAttribute("Zone")
	end
	if type(zone) ~= "number" or Zones[zone] == nil then
		warn(`[GuardService] zone de l'objet de {player.Name} inconnue ({payload.Zone}) : pas de vigile`)
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
	if template == nil or player.Parent ~= Players or CarryService.GetPayload(player) ~= payload then
		return
	end
	local ok, result = pcall(spawnGuard :: any, player, store, zone, template, label)
	if not ok then
		warn(`[GuardService] vigile de {player.Name} non créé : {result}`)
		return
	end
	local spawned: Guard? = result
	if spawned then
		bindLink(payload, store, spawned)
	end
end

-- a114 : l'objet lié `payload`, au sol, vient d'être repris par `player`. Le vigile lié fait demi-tour ;
-- parti ou occupé, un vigile du même magasin ressort pour lui (voir l'en-tête, « Objet lié »).
local function onLinkedPickup(player: Player, payload: any, link: Link)
	link.carrier = player
	local body = bodyOf(player)
	if body and isInSafeZone(body.Position) then
		log(`{player.Name} reprend un objet lié en zone safe : aucun vigile ne repart`)
		return -- vague 53 (point d'a157) : ni demi-tour, ni nouveau vigile
	end
	local guard = link.guard
	local other = chasedBy[player]
	if guard and guard.alive then
		local state = guard.state
		if state == "Catch" then
			log(`{guard.label} : {player.Name} reprend son objet, il part à la fin de Catch`)
			return -- update : retargetLinked à la fin de Catch
		elseif (state == "Wait" or state == "Chase") and guard.target == player then
			return
		elseif state == "Tired" or state == "Return" then
			local store = guard.store
			if other == nil and store and countChasing(store) >= Balance.Guard.MaxPerStore then
				log(`{store.Name} : déjà {Balance.Guard.MaxPerStore} vigiles en poursuite, {guard.label} ne fait pas demi-tour pour {player.Name}`)
				return
			end
			log(`{guard.label} : fait demi-tour, {player.Name} a repris son objet`)
			retarget(guard, player)
			return
		end
	end
	if other then
		bindLink(payload, link.store, other) -- déjà poursuivi : pas de second vigile, c'est lui qui est lié
		log(`{player.Name} reprend un objet lié, déjà poursuivi par {other.label} : il devient lié`)
		return
	end
	log(`{player.Name} reprend un objet lié : un vigile de {link.store.Name} ressort`)
	task.spawn(spawnForCarrier, player, payload, link.store)
end

local function onCarryStarted(player: Player, payload: any)
	-- L-112 : un objet sorti d'un colis ouvert sur le rayon (NPCItem) fait partir le vigile du magasin à
	-- sa prise, comme un colis (Cantin, 2026-11-13, a114 : rétabli, lié à l'objet) ; tombé au sol (coup de
	-- batte, lâché, ou porteur attrapé : CarryService.Fail « Caught » le lâche, résultat « Dropped »), il
	-- suit les mêmes règles qu'un colis tombé, plus celles de l'objet lié.
	if type(payload) ~= "table" or payload.Kind ~= "NPCItem" then
		return -- seuls les objets sortis d'un colis PNJ ont un vigile (5.5 ; vague 50 : plus de colis porté fermé, NPCBox)
	end
	if droppedPayloads[payload] then
		-- Ramassé au sol (6.2) : le vigile qui suivait ce colis change de cible ; sinon le vigile lié à
		-- l'objet (a114) ; sans eux, aucun vigile (il n'apparaît qu'à la prise sur le rayon).
		droppedPayloads[payload] = nil
		local guard = following[payload]
		local link = links[payload]
		if guard and guard.alive and guard.state == "Follow" then
			if link then
				link.carrier = player
			end
			retarget(guard, player)
		elseif link then
			onLinkedPickup(player, payload, link)
		else
			log(`{player.Name} ramasse un objet tombé au sol : aucun vigile ne le suivait`)
		end
		return
	end
	if type(payload.StoreId) == "string" and string.sub(payload.StoreId, 1, 6) == "Truck_" then
		return -- colis du camion (TruckEventService, StoreId « Truck_<n> ») : pas de magasin, pas de vigile
	end
	local storeId = payload.StoreId
	local store = if type(storeId) == "string" then findStore(storeId) else nil
	if store == nil then
		warn(`[GuardService] magasin « {storeId} » de l'objet de {player.Name} introuvable : pas de vigile`)
		return
	end
	if linkable(payload) then
		-- a114 : objet pris sur le rayon, lié dès sa prise ; déjà poursuivi par un vigile de jour (intrus) :
		-- lié à celui-là, pas de second vigile.
		bindLink(payload, store, chasedBy[player])
		links[payload].carrier = player
	end
	-- Hors de l'appel de CarryService : le rig de remplacement peut demander d'attendre.
	task.spawn(spawnForCarrier, player, payload, store)
end

local function onCarryEnded(player: Player, payload: any, result: string, reason: string)
	local dropped = result == "Dropped" and type(payload) == "table"
	if dropped then
		droppedPayloads[payload] = true -- au sol jusqu'à sa prise (onCarryStarted) ou sa fin
	end
	if not dropped and type(payload) == "table" then
		itemCatches[payload] = nil -- a174 : rangé en zone safe ou revenu au rayon, le compteur s'efface
	end
	-- a114 : objet lié au sol, il le reste ; rangé en base ou reparti vers son rayon, le lien finit.
	local link = if type(payload) == "table" then links[payload] else nil
	if link then
		link.carrier = nil
		if not dropped then
			links[payload] = nil
		end
	end
	local guard = chasedBy[player]
	if guard == nil then
		-- Cantin, 2026-11-13 : porteur attrapé (le vigile lié joue Catch, sa poursuite est déjà finie) : il
		-- retient l'endroit où l'objet tombe et ira le garder à la fin de Catch (followAfterCatch).
		local linked = if dropped and link then link.guard else nil
		if linked and linked.alive and linked.state == "Catch" then
			releaseFollow(linked)
			local root = bodyOf(player)
			linked.followPayload = payload
			linked.followPosition = if root then root.Position else linked.root.Position
			linked.followOwner = player -- a231 : pour « l'objet de X » à la fin de Catch
			following[payload] = linked
		end
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
	links[payload] = nil -- a114 : fin du lien
	itemCatches[payload] = nil -- a174 : reparti vers son rayon
	local guard = following[payload]
	if guard then
		giveUp(guard, "objet resté au sol, reparti vers son rayon")
	end
end

followAfterCatch = function(guard: Guard): boolean
	local payload = guard.followPayload
	if not guard.alive or payload == nil or not droppedPayloads[payload] or following[payload] ~= guard then
		return false
	end
	followDrop(guard, payload, guard.followPosition, guard.followOwner)
	return true
end

retargetLinked = function(guard: Guard, player: Player)
	if not guard.alive then
		return
	end
	log(`{guard.label} : {player.Name} a repris son objet pendant Catch, il repart`)
	retarget(guard, player)
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

-- a113 (Cantin, 2026-11-13) : DropService refuse de lâcher le portage pendant cet étourdissement.
function GuardService.IsStunned(player: Player): boolean
	return stunTokens[player] ~= nil
end

function GuardService.GetGuard(player: Player): Model?
	local guard = chasedBy[player]
	return if guard then guard.model else nil
end

-- a114 : le vigile de jour lié à cet objet (NPCItem), s'il est en jeu ; nil sinon.
function GuardService.GetLinkedGuard(payload: any): Model?
	local link = links[payload]
	local guard = if link then link.guard else nil
	return if guard and guard.alive then guard.model else nil
end

-- a70 (vague 24) : les vigiles de jour de `store` qui rentrent vers sa réserve (GuardSpawn), donc à
-- travers le magasin : leur HumanoidRootPart. StoreHeistService lève le rideau local du voleur avant
-- leur arrivée (on ne doit jamais voir un vigile traverser ce rideau, Cantin 2026-11-11). Compte aussi
-- celui qui s'efface à la réserve (Fade) : arrivé, il ne traverse plus le rideau (sinon le rideau local
-- remontait 0,6 s pendant son effacement).
function GuardService.GetReturningGuards(store: Model): { BasePart }
	local roots: { BasePart } = {}
	for _, guard in guards do
		if guard.alive and guard.store == store and (guard.state == "Return" or guard.state == "Fade")
			and guard.returnTo == "Reserve" then
			table.insert(roots, guard.root)
		end
	end
	return roots
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

function GuardService.OnGuardGone(listener: GoneListener): () -> ()
	table.insert(goneListeners, listener)
	return function()
		local index = table.find(goneListeners, listener)
		if index then
			table.remove(goneListeners, index)
		end
	end
end

function GuardService.GetSpeedOverride(_player: Player, _zone: number): number?
	return nil
end

function GuardService.IsHiddenFromNight(_player: Player): boolean
	return false
end

function GuardService.IsNightChased(player: Player): boolean
	return nightChasedBy[player] ~= nil
end

function GuardService.ChaseIntruder(player: Player, store: Model): boolean
	local body = bodyOf(player)
	if player.Parent ~= Players or body == nil or isInSafeZone(body.Position) or chasedBy[player] ~= nil or RevealState.IsProtected(player) then
		return false
	end
	local zone = store:GetAttribute("Zone")
	if type(zone) ~= "number" or Zones[zone] == nil then
		warn(`[GuardService] {store:GetFullName()} : attribut Zone invalide ({zone}), pas de vigile pour {player.Name}`)
		return false
	end
	local template = findTemplate(zone)
	if template and not isUsable(template) then
		template = nil
	end
	local label = if template then template:GetFullName() else FALLBACK_NAME
	if template == nil then
		template = getFallback() -- peut attendre
	end
	if template == nil or player.Parent ~= Players then
		return false
	end
	local ok, err = pcall(spawnGuard :: any, player, store, zone, template, label, true)
	if not ok then
		warn(`[GuardService] vigile de l'intrus {player.Name} non créé : {err}`)
		return false
	end
	return chasedBy[player] ~= nil
end

function GuardService.StartDriverChase(chase: DriverChase): Model?
	local ok, result = pcall(spawnDriver, chase)
	if not ok then
		warn(`[GuardService] conducteur non créé : {result}`)
		return nil
	end
	return result
end

-- `position` est-elle dans une zone safe (tag SafeZone) ? Pour WitnessService (L-111 : pas de policier
-- lancé sur un joueur déjà à l'abri).
function GuardService.IsInSafeZone(position: Vector3): boolean
	return isInSafeZone(position)
end

-- Le modèle `name` du dossier Guards de Clément (NPC_Police, L-111), ou nil s'il n'est pas livré.
function GuardService.FindGuardModel(name: string): Model?
	return findGuardModel(name)
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
	-- Hors de l'appel : le rig de remplacement peut demander d'attendre. Vague 69 (a229) : un vigile par
	-- image, le premier tout de suite (les 12 d'un coup, avec le remplissage des rayons, gelaient le serveur).
	task.spawn(function()
		for index, plan in plans do
			if index > 1 then
				task.wait()
			end
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
	if GuardService._PathAvoid then
		GuardService._PathAvoid.Start() -- f70c3 : modificateurs sur les présentoirs bas des magasins PNJ
	end
	CarryService.OnCarryStarted(onCarryStarted)
	CarryService.OnCarryEnded(onCarryEnded)
	CarryService.OnDropExpired(onDropExpired)
	-- L-135 point 5 (Clément, 2026-11-14) : lâché ou tombé dans le magasin d'où vient l'objet (G, coup de
	-- batte, capture…), il revole sur son rayon au lieu de tomber (même règle que la capture, inItsStore).
	local setCheck = CarryService.SetBackToShelfCheck
	if setCheck then
		setCheck(inItsStore)
	end
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
		local driverGuard = driverChasedBy[player]
		if driverGuard then
			giveUp(driverGuard, "départ du joueur")
		end
		stunTokens[player] = nil
		chaseSent[player] = nil
		caughtAtNight[player] = nil
	end)
	-- Prépare le rig de remplacement dès le démarrage : le premier vigile apparaît sans attendre.
	task.spawn(getFallback)
end

return GuardService
