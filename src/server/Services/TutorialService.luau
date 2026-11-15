--!strict
-- TutorialService (DEV-046) : tutoriel de départ, du spawn au premier objet exposé, puis jusqu'à la
-- fin du bouclier débutant (Partie 1, sections 3, 5.11, 5.12, 6.4, 9.4, 9.5 et 14.2 ; valeurs et
-- textes : Config/Tutorial ; bulle et flèche : TutorialController, côté client).
--
-- Qui a un tuto (à l'attribution de sa parcelle, PlotService.OnPlotAssigned : le profil est chargé,
-- c'est « l'arrivée sur sa parcelle ») :
--   - un profil au tuto pas commencé (Tutorial.Step = 0, Done = false) commence à l'étape 1 ;
--   - sauf un ancien joueur, qui a joué avant que le tuto existe (profil DEV d'Ironix, testeurs) :
--     il est marqué Done = true sans rien afficher, Step reste à 0. Règle exacte (hasPlayed) : au
--     moins un objet (Items), un colis dans l'inventaire ou posé au sol (Boxes), un braquage ou un vol réussi
--     (Lifetime.Heists ou Lifetime.Steals > 0), un outil autre que les poings (Tools.Owned), une aura
--     ou un trail (Cosmetics.Auras, Cosmetics.Trails), ou une amélioration achetée (un niveau de
--     Upgrades > 0). L'argent, les stats et le temps de jeu seuls ne comptent pas : un joueur qui n'a
--     fait que s'entraîner a encore besoin du tuto ;
--   - reprise : un profil à Step 1 à 14 et Done = false reprend à son étape. Step garde l'étape la
--     plus avancée atteinte ; ce qui n'est pas sauvegardé (vitrine, magasin ouvert, objet porté) est
--     relu sur place : un joueur parti avec l'objet sur la tête (Step = 4) reprend à l'étape 2, car
--     l'objet est revenu sur son rayon (5.6). Vague 52 : un ancien profil à Step = 4 avec un colis dans
--     Boxes a un objet libre à la place (DataService.convertBoxes, au chargement) : il reprend à l'étape 5 ;
--   - Done = true : plus rien (tuto fini, passé, ou ancien joueur).
--
-- Étapes (Config/Tutorial.Steps, section 3) et ce qui les fait avancer : toujours ce qui se passe
-- dans le jeu, jamais un minuteur (At n'est qu'un repère d'équilibrage) :
--   1 → 2   premier coup du joueur sur la vitrine d'un magasin de la zone du tuto (TutorialZone, la
--           Supérette ou le Kiosque). Le serveur écoute HitWindow à côté de WindowService et garde le
--           coup s'il est plausible : outil de casse en main, personnage vivant, à
--           Balance.Hit.ServerMaxDistance studs au plus de la vitre (les règles de WindowService) ;
--   2 → 3   un magasin de la zone du tuto ouvert (vitrine cassée, chrono de 10 s :
--           StoreHeistService.IsOpen) et le joueur à StoreNearRadius studs au plus de sa vitrine :
--           c'est lui qui l'a cassée, ou un autre joueur juste devant lui. Possible dès l'étape 1 ;
--   3 → 4   un objet de magasin PNJ sur la tête (portage NPCItem de CarryService), ou rangé sous
--           antivol dans l'inventaire (Items, AntiTheft sans Spot : à l'entrée de la zone safe) ;
--   4 → 5   l'objet posé au sol de sa boutique (UnboxService.OnItemPlaced), ou l'objet du tuto déjà au
--           sol, ou libre dans l'inventaire (reprise) ;
--   (vague 52, a169 : plus aucun colis porté, rangé, posé ni ouvert en base, décision de Cantin du
--   2026-11-14 ; détail de l'étape 3 à 5 dans le paragraphe « Vague 31 » plus bas) ;
--   5 → 6   premier ramassage sur une plaque (DisplayService.OnCashOut, sauf « Leave »,
--           l'encaissement automatique au départ, et « Offline », les gains hors ligne) ;
--   6 → 7   TrainDuration (10 depuis la vague 61, 30 avant) s sur le tapis, cumulées (attribut TrainingMachine, posé par
--           TrainingService quand le joueur s'arrête sur la bande, L-071). Plus de banc depuis le
--           rééquilibrage v2 (2026-11-14) : l'étape garde son numéro et son Id, le tapis seul la passe ;
--   7 → 8   la clé à molette possédée (ToolToBuy), ou un outil plus fort ;
--   8 → 9   une aura possédée ;
--   9 → 10  le joueur passe l'arche de la zone 2 (ZoneGate, attribut Zone = GoalZone) : au-delà du
--           plan de l'arche, du côté opposé à l'arche de la zone 1 (sinon à la zone safe) ;
--   10      fin du bouclier débutant (NightCycleService.IsShielded) : ShieldEndMessage pendant
--           MessageDuration s, puis, avec un bot sur le serveur, l'étape 11 ; sans bot, le tuto est fini
--           (Step = 10, Done = true), comme avant la vague 36. Vague 61 (a199) : seulement avec
--           Tutorial.WaitShieldEnd ; sinon l'étape 10 passe tout de suite (11 avec un bot, sinon la fin) ;
--   Vague 36 (L-085 point 4, a121, V0 proposé) : le vol entre joueurs sur la boutique du bot (BotService). Après
--   l'étape 10 parce qu'une fois le bouclier débutant fini, le joueur entre dans le PvP : on lui montre alors à voler
--   (et le message « keep your bat close! » annonce la suite) ; avant, il n'a souvent pas de quoi casser une porte
--   vite ni d'objet exposé à protéger. Les numéros 1 à 10 ne changent pas (Step sauvegardé, funnel).
--   10 → 11 message de fin du bouclier fini et un bot présent (BotService.GetBotPlot) ;
--   11 → 12 GoToBotShop : le joueur à BotShopRadius studs de la porte du bot (PlotDoor/Window) ou dans le volume
--           Bounds de sa boutique (ou un objet du bot déjà pris) ;
--   12 → 13 StealFromBot : un objet du bot pris (BotService.OnTheft « Grabbed », ou un portage PlayerItem de
--           VictimUserId 0, celui de PvPService pour le bot) ;
--   13 → 12 BringStolenHome : l'objet perdu (vol raté : coup de batte, mort, BotService.OnTheft « Returned ») ;
--   12 → 14, 13 → 14  objet en main et le bot le poursuit (BotService.IsChasing) ; vague 38 (L-085 point 4, L-136 (a),
--           a126). « Grabbed » arrive juste avant le départ de la poursuite : relu un peu plus tard (task.defer) ;
--   14 → 13 EscapeBot (« le bot défend ») : le bot ne le poursuit plus (semé : laisse ou abandon), objet toujours en
--           main (funnel 14), ou l'objet déposé ; 14 → 12 : frappé, l'objet revole chez le bot (« Returned »).
--           L'étape 14 se joue entre 12 et 13 mais porte le numéro 14 (ajoutée à la fin, numéros et Id d'avant
--           inchangés) : pour garder dans Tutorial.Step l'étape la plus avancée, elle compte comme 12,5 (rank).
--           Sans IsChasing (ancien BotService), jamais d'étape 14 ;
--   13      l'objet déposé chez lui (OnTheft « Stolen ») : le tuto est fini (Step = 13, Done = true).
--   Vague 52 (a169, L-163, V0) : à l'étape 12, tant que la porte du bot n'est pas cassée (StealOpen) et que le
--   joueur n'est pas dedans, l'indice AnyoneCanRob (« every shop door breaks in 40 hits ») remplace la bulle.
--   Fin du tuto par le jeu (objet du bot ramené, fin du bouclier sans bot, bot absent aux étapes 11 à 13) :
--   Done = true tout de suite (sauvegardé), puis l'indice ProtectShop MessageDuration s, puis tout est caché
--   (step 0). Passer, ou un profil déjà fini : tout est caché tout de suite, sans ProtectShop.
--   Sans bot (GetBotPlot = nil : jamais venu, ou parti pendant ces étapes, BotService.OnChanged) : le tuto finit,
--   Step garde l'étape atteinte. Seule attente : une session qui reprend aux étapes 11 à 13 attend un bot absent
--   pendant ses BotWait premières secondes (serveur neuf : le bot arrive Bot.ArriveDelay s plus tard).
--   Un vol commencé avant l'étape 11 ne compte pas pour finir (remis à zéro en entrant à l'étape 11), un objet
--   tenu à ce moment-là si. Vol d'un vrai joueur : ne compte pas (le tuto montre le bot). Vague 37 (a124, L-117
--   point 7) : le bot défend sa boutique (BotService) : pendant le tuto du joueur poursuivi, BotService.IsGentle
--   (remplacé ici : session en cours) le fait courir moins vite et frapper au plus une fois, et la bulle BotChase
--   remplace celle de l'étape 12 pendant la poursuite (objet en main : étape 14, vague 38).
-- Retours en arrière, seulement pendant le braquage : étape 3 sans objet et magasin fermé → 2 ;
-- étape 4 sans objet, ni sur la tête ni dans l'inventaire (rattrapé, mort, déconnecté) → 3 si un magasin de la zone du tuto est encore
-- ouvert près du joueur, sinon 2. Ils ne changent que l'étape affichée, pas Tutorial.Step du profil
-- (l'étape la plus avancée). Une étape dont la condition est déjà remplie (reprise, achat fait
-- en avance) s'enchaîne avec la suivante dans le même contrôle. Contrôles : à chaque événement des
-- services, et toutes les Tutorial.Tick s (seuils d'argent, zone 2, bouclier, nuit, entraînement).
--
-- Vague 31 (L-112, a107), seul déroulé depuis la vague 52 (a169 ; décision de Cantin du 2026-11-14 : plus de
-- colis ramené en zone safe ; Features.ShelfOpen n'est plus lu ici). Mêmes étapes, mêmes Id et mêmes numéros
-- (un Tutorial.Step déjà sauvegardé garde son sens ; funnel 14.2 inchangé) ; le braquage se joue ainsi :
--   3 GrabBox    bulle « Open a box on the shelf! », flèche vers le colis fermé du rayon le
--                plus proche ; son colis s'ouvre : WaitReveal (flèche : le colis) ; l'objet sorti (le sien,
--                réservé, sinon un objet libre du rayon) : GrabItem (flèche : l'objet). Lu sur les rayons
--                (Shared/ShelfOpenState : tag ShelfItem, ShelfOpenState, ShelfOpenBy, ShelfReservedBy/Until).
--                Magasin fermé (fin du chrono) : l'étape attend tant que son ouverture va au bout ou que son
--                objet lui est réservé, sinon retour à 2 ;
--   3 → 4        un portage NPCItem (l'objet sur la tête), ou un objet sous antivol dans l'inventaire ;
--   4 PlaceBox   bulle « Bring the item back to your shop! » (flèche : sa boutique) ; rangé à l'entrée de la
--                zone safe (UnboxService.OnItemStowed) : PlaceFloorItem ;
--   4 → 5        un objet posé au sol de sa boutique (UnboxService.OnItemPlaced), ou l'objet du tuto déjà au
--                sol ou libre (reprise, colis converti au chargement par DataService) ;
--   5            WaitUnlock pendant l'antivol (objet volable ; flèche : l'objet au sol) ; vague 52 (a152 : l'objet
--                repris du sol va en main) : TakeUnlocked après « UNLOCKED! » (invite « Take » ; flèche : l'objet),
--                DisplayUnlocked l'objet en main (attribut HeldItem de HeldItemService ; flèche : un présentoir
--                libre, invite « Display »), PlaceItem l'objet libre dans l'inventaire, puis CollectCash comme
--                avant. Un objet sous antivol n'est jamais compté « dans l'inventaire » (il n'est pas exposable).
--   Funnel : 4 = objet NPCItem soulevé, 5 = rangé, 6 = posé au sol, 7 (« Premier objet révélé ») = premier
--   objet libre (antivol fini), pour garder l'ordre 6 → 7 → 8 du Creator Dashboard (noms d'avant gardés).
--
-- Résultats garantis (5.11), branchés sur les accroches des services, seulement pour ce joueur et
-- seulement pendant son tuto :
--   - 1er objet : StoreHeistService.SetContentOverride, appelée à la SORTIE de l'objet (pour l'ouvreur) d'un
--     colis d'un magasin de la zone du tuto, aux étapes 1 à 3 : l'objet sorti est GuaranteedItemId (le Pot de
--     nouilles, Rare, TutorialOnly ; Tier FirstBoxTier), sans cran de rareté (contenu imposé), une seule fois par
--     braquage (Session.guaranteed, remis à false au retour à l'étape 2 : rattrapé, le suivant est garanti) ;
--   - chance : StoreHeistService.SetLuckOverride impose Tutorial.ShelfLuck (×1,5, V0) aux ouvertures du tuto
--     tant que l'objet garanti n'est pas sorti ;
--   - vigile lent : GuardService.GetSpeedOverride rend GuardSpeed (12) pour ce joueur dans la zone
--     du tuto, aux étapes 1 à 4 ;
--   - antivol de 5 s : UnboxService.GetAntiTheftDelay rend Tutorial.AntiTheftDelay pour l'objet du tuto posé
--     aux étapes 1 à 4 (gardé comme dans le jeu normal : V0 de la vague 52).
-- Les accroches d'avant sont gardées et appelées pour tous les autres cas. Vague 52 : plus d'accroche sur
-- UnboxService.GetOpenDelay, GetLuck, OnBoxStowed, OnBoxPlaced, OnBoxOpened (plus aucun colis ouvert en base).
--
-- Guidage envoyé au client : TutorialStep(step, hint?, target?) (9.4), au début et à chaque
-- changement, jamais deux fois le même. step = étape en cours (0 = plus de tuto : tout cacher) ;
-- hint = clé de Config/Tutorial.Hints à afficher à la place de la bulle de l'étape (nil = la bulle
-- de l'étape) ; target = point du monde visé par la flèche (nil = pas de flèche). Cibles : vitrine
-- du magasin (étapes 1 à 3 ; la Supérette tant que le joueur n'en a pas choisi un autre), sa boutique
-- (4 : son SpawnPoint, au sol près de l'entrée), objet posé au sol, puis présentoir libre (objet en main ou
-- dans l'inventaire), puis plaque de ramassage (5), tapis (6), plaque de ramassage ou
-- comptoir WeaponShop (7) et AuraShop (8) selon l'argent, arche de la zone 2 (9), porte du bot (11, et 12
-- tant que sa boutique n'est pas ouverte au vol), objet du bot volable le plus proche (12, porte cassée ou
-- joueur dedans : attribut StealOpen de PvPService ; plus de coffre-fort depuis la vague 54), sa boutique
-- (13). Le tapis
-- est trouvé par son tag dans la parcelle ; la plaque, par DisplayService.GetCollectTarget (celle qui
-- porte le plus d'argent, sinon celle du premier objet exposé). Boutique du hub (PLOT_Shop, L-050) :
-- entre l'intérieur de la boutique (volume Bounds) et l'extérieur, la flèche vise d'abord la porte
-- (PlotDoor/Window) ; le joueur apparaît dans sa boutique, la première flèche va donc à sa porte.
-- Indices (Hints) : WindowRebuilding (étape 2, vitrine cassée rideau baissé) ; WaitReveal, GrabItem (3) ;
-- PlaceFloorItem (4 et 5, objet sous antivol dans l'inventaire) ; WaitUnlock, TakeUnlocked, DisplayUnlocked,
-- PlaceItem (objet dans l'inventaire, rien d'exposé), CollectCash (étape 5) ; StandOnTreadmill (étape 6, flèche vers le tapis, qui n'a plus d'invite :
-- L-071) ; CollectCash (7 et 8 sans assez d'argent) ; Night (bulle de nuit 5.12 :
-- alerte ou nuit, joueur dans le couloir ; flèche vers sa parcelle) ; NightClosed (la nuit, côté
-- zone safe, aux étapes qui visent le couloir : 1 à 3 et 9 ; pas de flèche) ; ShieldEnd (fin du
-- bouclier débutant) ; BotChase, AnyoneCanRob (12) ; ProtectShop (fin du tuto). EquipFists est choisi par le
-- client (outil pas en main près de la vitrine).
--
-- Fin du bouclier débutant (6.4, 10 min de jeu cumulées) : quand IsShielded passe de true à false
-- pendant le tuto, ShieldEndMessage s'affiche MessageDuration s, quelle que soit l'étape (une fois
-- par session). À l'étape 10, bouclier déjà fini : le message s'affiche alors s'il ne l'a pas été
-- dans cette session, puis le tuto finit.
--
-- Passer (5.11, remote TutorialSkip, 9.4) : accepté pour un tuto en cours à l'étape SkipFromStep (5)
-- ou plus. Refusé avant (sortie de Studio seulement). Vague 60 (a197, Cantin ; Tutorial.SkipOneStep, V0) : Passer
-- saute UNE étape, dans l'ordre du jeu : 5 → 6 → 7 → 8 → 9 → 10 → 11 (avec un bot, sinon fin) → 12 ; 14 → 13 (la
-- poursuite du bot ne ramène plus à 14 avant un nouveau passage à 12) ; 12 et 13 : fin du tuto (13 demande l'objet du
-- bot en main), avec ProtectShop. L'étape sautée compte comme faite (Tutorial.Step garde l'étape la plus avancée, la
-- reprise part de la suivante). Passer ne donne rien : étape 5 sans objet exposé ni encaissement, 7 sans la clé à
-- molette, 8 sans aura (l'argent reste au joueur, don de la vague 61 compris ; l'étape suivante verse le sien). Une étape suivante déjà remplie s'enchaîne (outil déjà acheté…).
-- Passer pendant ProtectShop cache tout. SkipOneStep = false : l'ancienne règle (Done = true, Step garde l'étape).
--
-- Liste des tâches (vague 60, a197) : TutorialStep porte aussi la progression de l'étape (have, need ; progressOf :
-- tapis, argent pour l'outil ou l'aura, Speed pour la zone 2, temps du bouclier) ; Shared/TutorialTasks en fait le
-- texte côté client. Flèche (vague 60) : toujours la cible exacte de l'étape, plus le détour par la porte de la
-- boutique du joueur (throughDoor, gardé derrière Tutorial.ArrowViaDoor).
--
-- Tuto court (vague 61, a199 ; Cantin : « maximum dans son entièreté 2 à 3 minutes » ; V0 de Config/Tutorial) :
--   - dons : en entrant à l'étape 7 (ou en la reprenant) sans la clé à molette ni de quoi la payer, le jeu verse
--     Tutorial.ToolGift (son prix) ; à l'étape 8, sans aura ni de quoi payer, Tutorial.AuraGift. Une seule fois par
--     profil : Tutorial.Gifts[« Tool » | « Aura »] = true, posé avant le versement (reprise au milieu, Passer, retour
--     à l'étape : jamais deux fois). Passer l'étape 6 mène à l'étape 7, qui donne son argent ; passer l'étape 7 ou 8 ne
--     reprend rien. Indices ToolGift et AuraGift (« Here's $300 for the tutorial: buy the Wrench! ») tant que le don est
--     versé et que l'argent suffit ; Tutorial.GiftCash = false : plus aucun don (attente d'avant) ;
--   - étape 10 : sans Tutorial.WaitShieldEnd, plus d'attente de la fin du bouclier débutant (10 min de jeu) : 10 → 11
--     tout de suite avec un bot, sinon fin du tuto (ProtectShop). Le bouclier lui-même ne change pas ;
--   - Tutorial.TrainDuration : 10 s de tapis.
--
-- Funnel d'onboarding (14.2) : AnalyticsService:LogOnboardingFunnelStepEvent(player, n, nom), dans
-- un pcall (refusé en Studio et côté client : la sortie de Studio l'écrit). Pour les nouveaux joueurs
-- seulement : un profil qui a commencé le tuto (Step ≥ 1), fini ou passé compris ; jamais un ancien
-- joueur. Une seule fois par joueur et par étape : déjà envoyées dans cette session, ou déjà
-- franchies d'après le profil au chargement (loggedFunnel). Roblox ne compte de toute façon que le
-- premier envoi d'une étape. Étapes : 1 tuto commencé, 2 coup sur une vitrine de magasin PNJ, 3 vitrine
-- PNJ cassée par lui, 4 objet PNJ soulevé, 5 dans la zone safe avec cet objet, 6 objet posé au sol, 7 objet
-- libre (antivol fini ; noms du Creator Dashboard gardés : « Premier colis volé »…), 8 un objet exposé, 9 premier encaissement, 10 un outil acheté ; vague 36, seulement pendant le tuto :
-- 11 boutique du bot atteinte (étape 12), 12 objet du bot pris (étape 13 ou 14), 13 objet du bot déposé chez lui
-- (fin) ; vague 38 : 14 bot semé avec son objet (14 → 13). Interrupteur de la télémétrie
-- (Config/Telemetry.Enabled = false, DEV-054) : aucune étape n'est envoyée.
--
-- Crochet de test, STUDIO SEULEMENT : workspace:SetAttribute("TutorialReset", userId) (barre de
-- commande serveur ; un nom de joueur marche aussi). Le tuto de ce joueur repart de l'étape 1
-- (Done = false), funnel compris, même pour un ancien joueur. Les objets et outils du profil
-- ne changent pas : un présentoir déjà occupé reste occupé, un objet du tuto (Pot de nouilles) encore
-- posé au sol fait reprendre à l'étape 5 et un objet sous antivol de l'inventaire à l'étape 4 (le poser
-- et le reprendre avant pour rejouer le braquage). Hors de Studio,
-- l'attribut n'est pas écouté.
--
-- Attributs du Player (pour les tests en Studio : la barre de commande a son propre cache de modules,
-- elle lit ces attributs) : TutorialStep (le step envoyé, 0 à la fin) et TutorialHint (l'indice envoyé,
-- absent sans indice). Un joueur qui n'a jamais eu de tuto n'en a pas. Vague 38 : NotifyController lit aussi
-- TutorialStep (> 0 = tuto en cours : un seul message à la fois dans UI_Toast, L-135 point 2).
--
-- API (serveur) :
--   TutorialService.GetStep(player) -> number    étape en cours, 0 sans tuto en cours
--   TutorialService.IsActive(player) -> boolean  tuto en cours (résultats garantis possibles)
--   TutorialService.Reset(player) -> boolean     STUDIO SEULEMENT, voir le crochet de test

local AnalyticsService = game:GetService("AnalyticsService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Cosmetics = require(Shared.Config.Cosmetics)
local ShelfOpenState = require(Shared.ShelfOpenState)
local Telemetry = require(Shared.Config.Telemetry)
local Tools = require(Shared.Config.Tools)
local Tutorial = require(Shared.Config.Tutorial)
local PvP = require(Shared.Config.PvP) -- vague 60 : BeginnerShieldDuration (progression de l'étape 10)
local Zones = require(Shared.Config.Zones) -- vague 60 : SpeedRequired de la zone 2 (progression de l'étape 9)
local Find = require(Shared.Contract.Find)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local GuardService = require(script.Parent.GuardService)
local NightCycleService = require(script.Parent.NightCycleService)
local PlotService = require(script.Parent.PlotService)
local StoreHeistService = require(script.Parent.StoreHeistService)
local ToolService = require(script.Parent.ToolService)
local UnboxService = require(script.Parent.UnboxService)
local WindowService = require(script.Parent.WindowService)

type Data = ProfileTypes.Data

-- Ce que ce service utilise de CarryService et de DisplayService (typé ici, comme UnboxService).
type CarryApi = {
	GetPayload: (player: Player) -> any,
	OnCarryStarted: (listener: (player: Player, payload: any) -> ()) -> any,
	OnCarryEnded: (listener: (player: Player, payload: any, result: string, reason: string) -> ()) -> any,
}
type DisplayApi = {
	OnCashOut: (listener: (player: Player, amount: number, source: string) -> ()) -> any,
	GetCollectTarget: (player: Player) -> Vector3?,
}
local CarryService: CarryApi = require(script.Parent.CarryService) :: any
local DisplayService: DisplayApi = require(script.Parent.DisplayService) :: any

-- Vague 36 : ce que ce service lit de BotService (étapes 11 à 13). require protégé, comme PvPService : sans
-- BotService (anciens bancs), jamais de bot, les étapes 11 à 13 sont sautées.
type BotApi = {
	GetBotPlot: () -> Model?,
	GetExposed: (plot: Model) -> { [number]: { Uid: string, ItemId: string, Income: number } },
	OnTheft: (listener: (thief: Player, itemId: string, stage: string) -> ()) -> any,
	OnChanged: (listener: (plot: Model?) -> ()) -> any,
	-- Vague 37 (a124, le bot défend sa boutique) : point d'accroche remplacé ici (poursuite plus douce pendant le
	-- tuto), et la poursuite en cours (bulle BotChase). Absents d'un ancien BotService.
	IsGentle: ((player: Player) -> boolean)?,
	IsChasing: ((player: Player) -> boolean)?,
}
local botModule = script.Parent:FindFirstChild("BotService")
local botLoaded: boolean, botResult: any = false, nil
if botModule and botModule:IsA("ModuleScript") then
	botLoaded, botResult = pcall(require, botModule)
end
local Bot: BotApi? = if botLoaded and type(botResult) == "table" and type(botResult.GetBotPlot) == "function"
	then botResult :: any
	else nil

-- Dernier guidage envoyé au client (pour ne jamais renvoyer le même).
type Sent = { step: number, hint: string?, target: Vector3?, have: number?, need: number? }

-- Tuto en cours d'un joueur (rien n'est gardé ici après Done).
type Session = {
	player: Player,
	step: number, -- étape en cours, copie de Tutorial.Step du profil
	storeId: string?, -- magasin de la zone du tuto du braquage en cours (StoreId = WindowId)
	hit: boolean, -- étape 1 : le joueur a frappé une vitrine de la zone du tuto
	cashedOut: boolean, -- étape 5 : premier encaissement fait
	trainSeconds: number, -- étape 6 : secondes passées sur une machine
	used: { [string]: boolean }, -- étape 6 : machines déjà utilisées ("Treadmill")
	shielded: boolean?, -- bouclier débutant au contrôle précédent (nil : pas encore lu)
	shieldShown: boolean, -- ShieldEndMessage déjà montré dans cette session
	messageUntil: number, -- os.clock() de fin d'affichage de ShieldEndMessage (0 : rien)
	sent: Sent?,
	-- L'objet garanti est déjà sorti d'un colis de ce braquage (une seule fois par braquage ; remis à false
	-- au retour à l'étape 2).
	guaranteed: boolean,
	-- Vague 36 (étapes 11 à 13) : début de la session (os.clock, attente d'un bot à la reprise), un objet du bot
	-- tenu (OnTheft « Grabbed » jusqu'à « Returned » ou « Stolen »), un objet du bot déposé chez lui depuis
	-- l'entrée à l'étape 11.
	startedAt: number,
	botHeld: boolean,
	botStolen: boolean,
	-- Vague 52 (L-163) : fin du tuto par le jeu, indice ProtectShop affiché jusqu'à cet os.clock() (0 : pas de
	-- fin en cours), puis tout est caché ; la raison de la fin, pour la sortie de Studio.
	outroUntil: number,
	outroWhy: string,
	-- Vague 60 (a197) : l'étape 14 passée (Skip) : jusqu'au retour à l'étape 12, la poursuite du bot ne ramène plus à 14.
	chaseSkipped: boolean,
}

local IS_STUDIO = RunService:IsStudio()

-- Étapes (Config/Tutorial.Steps, même ordre).
local STEP_ARRIVE = 1 -- ArriveAtPlot
local STEP_HIT = 2 -- HitWindow
local STEP_GRAB = 3 -- GrabBox
local STEP_PLACE = 4 -- PlaceBox
local STEP_DISPLAY = 5 -- DisplayItem
local STEP_TRAIN = 6 -- Train
local STEP_TOOL = 7 -- BuyTool
local STEP_AURA = 8 -- BuyAura
local STEP_ZONE = 9 -- GoToZone2
local STEP_SHIELD = 10 -- ShieldEnd
local STEP_BOT_SHOP = 11 -- GoToBotShop (vague 36)
local STEP_BOT_GRAB = 12 -- StealFromBot
local STEP_BOT_HOME = 13 -- BringStolenHome
local STEP_BOT_CHASE = 14 -- EscapeBot (vague 38) : se joue entre 12 et 13 (voir rank)
local LAST_STEP = STEP_BOT_CHASE -- plus grand numéro (bornes de la reprise), pas la dernière étape jouée

-- Étapes du funnel (Config/Tutorial.FunnelSteps, même ordre ; 14.2).
local FUNNEL_PLOT = 1
local FUNNEL_HIT = 2
local FUNNEL_BROKEN = 3
local FUNNEL_GRAB = 4
local FUNNEL_SAFE = 5
local FUNNEL_PLACED = 6
local FUNNEL_REVEALED = 7
local FUNNEL_DISPLAYED = 8
local FUNNEL_CASHOUT = 9
local FUNNEL_TOOL = 10
local FUNNEL_BOT_SHOP = 11 -- vague 36, seulement pendant le tuto
local FUNNEL_BOT_GRAB = 12
local FUNNEL_BOT_HOME = 13
local FUNNEL_BOT_ESCAPE = 14 -- vague 38 : bot semé avec son objet (14 → 13)

-- Rang d'une étape dans le jeu : son numéro, sauf l'étape 14, jouée entre 12 et 13 (vague 38). Sert à garder dans
-- Tutorial.Step l'étape la plus avancée (setStep).
local function rank(step: number): number
	return if step == STEP_BOT_CHASE then STEP_BOT_GRAB + 0.5 else step
end

-- Noms du contrat (2.1 et 10.4) lus ici.
local STORE_TAG = "NPCStore"
local GATE_TAG = "ZoneGate"
local SAFE_ZONE_TAG = "SafeZone"
local WEAPON_SHOP_TAG = "WeaponShop"
local AURA_SHOP_TAG = "AuraShop"
local ZONE_ATTRIBUTE = "Zone"
local INBOX_NAME = "_INBOX_CLEMENT"
local WINDOW = "Window"
local BOUNDS = "Bounds"
local SPAWN_POINT = "SpawnPoint"
local USE_POINT = "UsePoint"
local TREADMILL_TAG = "Treadmill"
-- Colis des rayons, posés par StoreHeistService (tag de code, hors contrat) ; attribut Landed (false
-- tant qu'un colis rendu vole).
local SHELF_BOX_TAG = "ShelfBox"
local LANDED_ATTRIBUTE = "Landed"
-- Entrée de la boutique du joueur (PLOT_Shop, nom validé par Ironix en L-050, pas encore au contrat).
local PLOT_DOOR = "PlotDoor"
local SLOT_FORMAT = "DisplaySlot_%02d"
-- Posé par PvPService sur une boutique (aucun nom du contrat) : ouverte au vol (porte cassée).
local STEAL_OPEN_ATTRIBUTE = "StealOpen"
-- Portage d'un objet volé (Types/Carry.PlayerItemPayload) : VictimUserId 0 = le bot (PvPService).
local PLAYER_ITEM_KIND = "PlayerItem"
local BOT_VICTIM_USER_ID = 0
-- Attribut du Player posé par TrainingService : la machine utilisée, nil sinon.
local MACHINE_ATTRIBUTE = "TrainingMachine"
-- Attribut du Player posé par HeldItemService : uid de l'objet tenu en main, absent sinon (vague 52, étape 5).
local HELD_ITEM_ATTRIBUTE = "HeldItem"
-- Attribut du Workspace du crochet de test (Studio seulement).
local RESET_ATTRIBUTE = "TutorialReset"
-- Attributs du Player posés ici (voir l'en-tête) : étape et indice envoyés au client.
local STEP_ATTRIBUTE = "TutorialStep"
local HINT_ATTRIBUTE = "TutorialHint"

-- V0 proposé, absent du doc : sans arche de la zone d'avant ni zone safe pour orienter l'arche de
-- l'étape 9, le joueur l'a passée à cette distance (studs) d'elle.
local GATE_REACH = 15

local TutorialService = {}
TutorialService.Priority = 200 -- après les services dont il remplace les accroches

local sessions: { [Player]: Session } = {}
-- Étapes du funnel déjà envoyées (ou franchies d'après le profil), par nouveau joueur.
local funnels: { [Player]: { [number]: boolean } } = {}
local funnelWarned = false
local safeBoxCache: { [Instance]: { cframe: CFrame, size: Vector3 } } = {}

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[TutorialService] {message}`)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Objet posé dans la map : dans le Workspace, hors _INBOX_CLEMENT (règle de WindowService).
local function inMap(inst: Instance): boolean
	if not inst:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not inst:IsDescendantOf(inbox)
end

-- Point du monde d'un objet du contrat : Attachment, pièce, ou pivot d'un Model (en bas au centre).
local function positionOf(inst: Instance?): Vector3?
	if inst == nil then
		return nil
	elseif inst:IsA("Attachment") then
		return (inst :: Attachment).WorldPosition
	elseif inst:IsA("BasePart") then
		return (inst :: BasePart).Position
	elseif inst:IsA("Model") then
		return (inst :: Model):GetPivot().Position
	end
	return nil
end

-- Boîte d'un objet : la pièce, ou la boîte englobante d'un Model.
local function boxOf(inst: Instance?): (CFrame?, Vector3?)
	if inst and inst:IsA("BasePart") then
		local part = inst :: BasePart
		return part.CFrame, part.Size
	elseif inst and inst:IsA("Model") then
		local cframe, size = (inst :: Model):GetBoundingBox()
		return cframe, size
	end
	return nil, nil
end

local function insideBox(cframe: CFrame, size: Vector3, position: Vector3): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

-- Premier objet de la map qui porte `tag` (et l'attribut Zone = `zone` s'il est donné).
local function taggedInMap(tag: string, zone: number?): Instance?
	for _, inst in CollectionService:GetTagged(tag) do
		if inMap(inst) and (zone == nil or inst:GetAttribute(ZONE_ATTRIBUTE) == zone) then
			return inst
		end
	end
	return nil
end

-- Élément de la parcelle du joueur, cherché par son nom du contrat 10.4 (chemin à points de Find).
local function plotPart(player: Player, path: string): Instance?
	local plot = PlotService.GetPlot(player)
	if plot == nil then
		return nil
	end
	return Find.path(plot, path)
end

-- Objet de la parcelle du joueur qui porte ce tag (Treadmill, Bench : comme TrainingService,
-- le tag plutôt que le nom, qu'un décor de la boutique pourrait porter aussi), sinon celui de ce nom.
local function plotTagged(player: Player, tag: string): Instance?
	local plot = PlotService.GetPlot(player)
	if plot == nil then
		return nil
	end
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(plot) then
			return inst
		end
	end
	return Find.path(plot, tag)
end

-- Plaque de ramassage à montrer (L-091 point 4 : plus de tapis de caisse CashPad) : celle de
-- DisplayService.GetCollectTarget, sans parcelle ou sans plaque aucune flèche.
local function collectTarget(player: Player): Vector3?
	local getter = (DisplayService :: any).GetCollectTarget
	if type(getter) ~= "function" then
		return nil -- faux DisplayService d'un banc sans plaques
	end
	local ok, result = pcall(getter, player)
	return if ok and typeof(result) == "Vector3" then result else nil
end

-- Pied de l'objet sous antivol posé au sol (UnboxService.GetFloorItem), nil s'il
-- n'est pas affiché ou qu'un voleur l'a en main (faux UnboxService d'un banc sans lui : nil).
local function floorItemTarget(player: Player, itemUid: string): Vector3?
	local getter = (UnboxService :: any).GetFloorItem
	if type(getter) ~= "function" then
		return nil
	end
	local ok, result = pcall(getter, player, itemUid)
	local position = if ok and type(result) == "table" then result.Position else nil
	return if typeof(position) == "Vector3" then position else nil
end

-- Point d'usage d'une machine de la parcelle (tag Treadmill ou Bench) : son UsePoint, sinon elle.
local function machinePoint(player: Player, tag: string): Vector3?
	local machine = plotTagged(player, tag)
	if machine == nil then
		return nil
	end
	return positionOf(Find.path(machine, USE_POINT)) or positionOf(machine)
end

-- Boutique du joueur (PLOT_Shop du hub, liaison L-050) : quand le joueur et la cible ne sont pas du
-- même côté de ses murs (volume Bounds de la parcelle), la flèche vise d'abord sa porte : le pivot de
-- PlotDoor/Window, au sol au milieu de l'entrée (sinon celui de PlotDoor). Le joueur apparaît dans sa
-- boutique : la première flèche le mène donc à sa porte, puis vers la Supérette. Sans PlotDoor ou
-- sans Bounds (parcelle grise) : la cible elle-même.
local function throughDoor(player: Player, position: Vector3?, target: Vector3?): Vector3?
	if position == nil or target == nil then
		return target
	end
	local plot = PlotService.GetPlot(player)
	if plot == nil then
		return target
	end
	local bounds = plot:FindFirstChild(BOUNDS) or Find.path(plot, BOUNDS)
	local door = plot:FindFirstChild(PLOT_DOOR, true)
	if bounds == nil or not bounds:IsA("BasePart") or door == nil then
		return target
	end
	local box = bounds :: BasePart
	if insideBox(box.CFrame, box.Size, position) == insideBox(box.CFrame, box.Size, target) then
		return target
	end
	return positionOf(door:FindFirstChild(WINDOW, true)) or positionOf(door) or target
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

------------------------------------------------------------------------------
-- Magasins de la zone du tuto
------------------------------------------------------------------------------

local function tutorialStores(): { Model }
	local list: { Model } = {}
	for _, inst in CollectionService:GetTagged(STORE_TAG) do
		if inst:IsA("Model") and inMap(inst) and inst:GetAttribute(ZONE_ATTRIBUTE) == Tutorial.TutorialZone then
			table.insert(list, inst :: Model)
		end
	end
	return list
end

-- La Supérette (STORE_Z<zone>_<TargetStoreId>, ou une variante _<Variante>), sinon le premier magasin
-- de la zone du tuto.
local function defaultStore(): Model?
	local wanted = `STORE_Z{Tutorial.TutorialZone}_{Tutorial.TargetStoreId}`
	local first: Model? = nil
	for _, store in tutorialStores() do
		if store.Name == wanted or string.sub(store.Name, 1, #wanted + 1) == wanted .. "_" then
			return store
		end
		if first == nil then
			first = store
		end
	end
	return first
end

-- Magasin du braquage en cours du joueur, sinon la Supérette.
local function storeOf(session: Session): Model?
	local id = session.storeId
	local model = if id then StoreHeistService.GetStoreModel(id) else nil
	return model or defaultStore()
end

-- Distance entre `position` et le point le plus proche de la vitre du magasin (règle de WindowService).
local function windowDistance(store: Model, position: Vector3): number?
	local cframe, size = boxOf(Find.path(store, WINDOW))
	if cframe == nil or size == nil then
		return nil
	end
	local p = cframe:PointToObjectSpace(position)
	local half = size / 2
	local clamped = Vector3.new(math.clamp(p.X, -half.X, half.X), math.clamp(p.Y, -half.Y, half.Y), math.clamp(p.Z, -half.Z, half.Z))
	return ((cframe:PointToWorldSpace(clamped)) - position).Magnitude
end

-- Un magasin de la zone du tuto ouvert (chrono de 10 s) dont la vitrine est à StoreNearRadius studs
-- au plus de `position` : son StoreId, le plus proche.
local function openStoreNear(position: Vector3?): string?
	if position == nil then
		return nil
	end
	local best: string? = nil
	local bestDistance = math.huge
	for _, store in tutorialStores() do
		local id = StoreHeistService.GetStoreId(store)
		if id and StoreHeistService.IsOpen(id) then
			local distance = windowDistance(store, position) or (store:GetPivot().Position - position).Magnitude
			if distance <= Tutorial.StoreNearRadius and distance < bestDistance then
				best, bestDistance = id, distance
			end
		end
	end
	return best
end

-- L-112 : ce que StoreHeistService pose sur les rayons de `store` (Shared/ShelfOpenState),
-- lu ici pour l'étape 3. (hint, cible) : son objet sorti (ou un objet libre, réservation passée) → GrabItem ;
-- son colis qui s'ouvre → WaitReveal ; sinon le colis fermé du rayon le plus proche du joueur, sans indice
-- (bulle de l'étape). `pending` : une ouverture à lui en cours ou son objet encore réservé (il
-- peut le prendre même après le chrono). Les deux premiers résultats sont nil sans rien sur les rayons.
local function shelfState(store: Model, player: Player, position: Vector3?): (string?, Vector3?, boolean)
	local now = serverNow()
	local userId = player.UserId
	local mine: Vector3? = nil
	local free: Vector3? = nil
	for _, item in CollectionService:GetTagged(ShelfOpenState.ItemTag) do
		if item:IsA("Model") and item:IsDescendantOf(store) then
			local reservedBy = item:GetAttribute(ShelfOpenState.ReservedByAttribute)
			local reservedUntil = item:GetAttribute(ShelfOpenState.ReservedUntilAttribute)
			local reserved = type(reservedUntil) == "number" and now < reservedUntil
			if reservedBy == userId and reserved then
				mine = (item :: Model):GetPivot().Position
			elseif not reserved and free == nil then
				free = (item :: Model):GetPivot().Position
			end
		end
	end
	if mine then
		return "GrabItem", mine, true
	end
	local opening: Vector3? = nil
	local closest: Vector3? = nil
	local closestDistance = math.huge
	for _, box in CollectionService:GetTagged(SHELF_BOX_TAG) do
		if box:IsA("Model") and box:IsDescendantOf(store) then
			local state = box:GetAttribute(ShelfOpenState.StateAttribute)
			local at = (box :: Model):GetPivot().Position
			if state == "Opening" and box:GetAttribute(ShelfOpenState.ByAttribute) == userId then
				opening = at
			elseif state == nil and box:GetAttribute(LANDED_ATTRIBUTE) ~= false then
				local distance = if position then (at - position).Magnitude else 0
				if distance < closestDistance then
					closest, closestDistance = at, distance
				end
			end
		end
	end
	if opening then
		return "WaitReveal", opening, true
	end
	if free then
		return "GrabItem", free, false
	end
	return nil, closest, false
end

------------------------------------------------------------------------------
-- Lecture du profil
------------------------------------------------------------------------------

-- Portage d'un objet de magasin PNJ (NPCItem ; vague 52 : plus de colis NPCBox porté).
local function npcPayload(player: Player): any
	local ok, payload = pcall(CarryService.GetPayload, player)
	if ok and type(payload) == "table" and payload.Kind == "NPCItem" then
		return payload
	end
	return nil
end

-- Objet sous antivol du profil (Types/Profile : AntiTheft, UnlockAt, Spot).
local function isAntiTheft(entry: any): boolean
	return type(entry) == "table" and entry.AntiTheft == true
end

-- Objet sous antivol posé au sol (`placed` = true) ou dans l'inventaire (false),
-- l'objet du tuto (le Pot de nouilles) d'abord, sinon celui de plus petit uid : (uid, objet).
local function findAntiTheftItem(data: Data, placed: boolean): (string?, any)
	local foundUid: string? = nil
	local found: any = nil
	for uid, entry in data.Items do
		if isAntiTheft(entry) and ((entry :: any).Spot ~= nil) == placed then
			if entry.Id == Tutorial.GuaranteedItemId then
				return uid, entry
			end
			if foundUid == nil or uid < (foundUid :: string) then
				foundUid, found = uid, entry
			end
		end
	end
	return foundUid, found
end

-- L'objet du tuto est posé au sol sous antivol, ou (reprise à l'étape 4 : colis du tuto converti au
-- chargement par DataService) libre dans l'inventaire, ni exposé ni au coffre : l'étape 5 peut
-- commencer. Un objet du tuto déjà exposé (crochet TutorialReset) ne compte pas : le braquage se rejoue.
local function tutorialItemHome(data: Data, step: number): boolean
	local placed: { [string]: boolean } = {}
	for _, uid in data.Display do
		placed[uid] = true
	end
	for _, uid in data.Vault do
		placed[uid] = true
	end
	for uid, entry in data.Items do
		if type(entry) ~= "table" or entry.Id ~= Tutorial.GuaranteedItemId then
			continue
		end
		if isAntiTheft(entry) then
			if (entry :: any).Spot ~= nil then
				return true
			end
		elseif step == STEP_PLACE and not placed[uid] then
			return true
		end
	end
	return false
end

local function ownsBoughtTool(data: Data): boolean
	for _, id in data.Tools.Owned do
		if id ~= Tools.DefaultId then
			return true
		end
	end
	return false
end

-- Étape 7 : la clé à molette, ou un outil au moins aussi fort.
local function ownsToolToBuy(data: Data): boolean
	local wanted = Tools.ById[Tutorial.ToolToBuy]
	if wanted == nil then
		return ownsBoughtTool(data)
	end
	for _, id in data.Tools.Owned do
		local tool = Tools.ById[id]
		if tool and tool.Id ~= Tools.DefaultId and tool.Power >= wanted.Power then
			return true
		end
	end
	return false
end

local function ownsAura(data: Data): boolean
	for _, id in data.Cosmetics.Auras do
		local def = Cosmetics.ById[id]
		if def and def.Kind == "Aura" then
			return true
		end
	end
	return false
end

local function toolPrice(): number
	local wanted = Tools.ById[Tutorial.ToolToBuy]
	return if wanted then wanted.Price else 0
end

local function cheapestAura(): number
	local price = math.huge
	for _, aura in Cosmetics.Auras do
		price = math.min(price, aura.Price)
	end
	return price
end

-- Vague 61 (a199) : dons du tuto (voir l'en-tête, « Tuto court »).
local GIFT_TOOL = "Tool"
local GIFT_AURA = "Aura"

local function gifted(data: Data, id: string): boolean
	local gifts = data.Tutorial.Gifts
	return type(gifts) == "table" and gifts[id] == true
end

-- Verse le don `id` une seule fois par profil, s'il manque de quoi payer `price` ; true si versé maintenant.
local function giveGift(player: Player, data: Data, id: string, amount: number, price: number): boolean
	if not Tutorial.GiftCash or gifted(data, id) or amount <= 0 or amount ~= amount or amount == math.huge or data.Cash >= price then
		return false
	end
	local gifts = data.Tutorial.Gifts
	if type(gifts) ~= "table" then
		gifts = {}
		data.Tutorial.Gifts = gifts
	end
	local marks = gifts :: { [string]: boolean }
	marks[id] = true -- avant le versement : jamais deux fois, même si la suite échoue
	if DataService.AddCash(player, amount) == nil then
		return false
	end
	return true
end

-- Ancien joueur (voir l'en-tête) : la raison, ou nil pour un nouveau joueur.
local function hasPlayed(data: Data): string?
	if next(data.Items) ~= nil then
		return "objets"
	elseif next(data.Boxes) ~= nil then
		return "colis dans l'inventaire ou posé"
	elseif data.Lifetime.Heists > 0 or data.Lifetime.Steals > 0 then
		return "braquages ou vols réussis"
	elseif ownsBoughtTool(data) then
		return "outil acheté"
	elseif #data.Cosmetics.Auras > 0 or #data.Cosmetics.Trails > 0 then
		return "aura ou trail"
	end
	local upgrades = data.Upgrades
	if upgrades.Treadmill > 0 or upgrades.Bench > 0 or upgrades.DisplaySlots > 0 or upgrades.UnboxBenches > 0 then
		return "améliorations"
	end
	return nil
end

-- Étapes du funnel déjà franchies d'après le profil d'un nouveau joueur (voir l'en-tête).
local function loggedFunnel(data: Data): { [number]: boolean }
	local step = data.Tutorial.Step
	local heisted = data.Lifetime.Heists > 0 or next(data.Boxes) ~= nil or next(data.Items) ~= nil
	-- Funnel 7 (« Premier objet révélé ») = un objet libre : l'antivol fini (voir l'en-tête).
	local hasItem = false
	for _, entry in data.Items do
		if not isAntiTheft(entry) then
			hasItem = true
			break
		end
	end
	return {
		[FUNNEL_PLOT] = step >= STEP_ARRIVE,
		[FUNNEL_HIT] = step >= STEP_HIT or heisted,
		[FUNNEL_BROKEN] = step >= STEP_GRAB or heisted,
		[FUNNEL_GRAB] = step >= STEP_PLACE or heisted,
		[FUNNEL_SAFE] = step >= STEP_DISPLAY or heisted,
		[FUNNEL_PLACED] = step >= STEP_DISPLAY or heisted,
		[FUNNEL_REVEALED] = hasItem,
		[FUNNEL_DISPLAYED] = next(data.Display) ~= nil or step >= STEP_TRAIN,
		[FUNNEL_CASHOUT] = step >= STEP_TRAIN,
		[FUNNEL_TOOL] = ownsBoughtTool(data),
		-- Vague 36 : envoyées pendant le tuto seulement (13 : à la fin, jamais renvoyée après une reprise).
		[FUNNEL_BOT_SHOP] = step >= STEP_BOT_GRAB,
		[FUNNEL_BOT_GRAB] = step >= STEP_BOT_HOME,
		[FUNNEL_BOT_HOME] = false,
		[FUNNEL_BOT_ESCAPE] = false, -- vague 38 : comme 13 (un renvoi après une reprise n'est pas compté par Roblox)
	}
end

-- Un objet dans l'inventaire (ni exposé ni au coffre-fort) ?
local function hasStoredItem(data: Data): boolean
	local placed: { [string]: boolean } = {}
	for _, uid in data.Display do
		placed[uid] = true
	end
	for _, uid in data.Vault do
		placed[uid] = true
	end
	for uid, entry in data.Items do
		if not placed[uid] and not isAntiTheft(entry) then -- sous antivol : pas encore exposable
			return true
		end
	end
	return false
end

-- Vague 52 : un objet de son inventaire en main (attribut HeldItem de HeldItemService ; a152 : l'objet repris du
-- sol à la fin de l'antivol y va), ni exposé ni au coffre-fort.
local function holdsStoredItem(player: Player, data: Data): boolean
	local uid = player:GetAttribute(HELD_ITEM_ATTRIBUTE)
	if type(uid) ~= "string" or isAntiTheft(data.Items[uid]) or data.Items[uid] == nil then
		return false
	end
	for _, placedUid in data.Display do
		if placedUid == uid then
			return false
		end
	end
	for _, placedUid in data.Vault do
		if placedUid == uid then
			return false
		end
	end
	return true
end

local function unlockedCount(base: number, level: any, max: number): number
	local bought = if type(level) == "number" then level else 0
	return math.clamp(base + bought, 1, max)
end

-- Premier présentoir débloqué et libre (sinon le 1er) : la cible de l'étape 5 quand l'objet est dans
-- l'inventaire (on l'y pose, L-089) ou qu'il n'y a encore rien.
local function freeSlotTarget(player: Player, data: Data): Vector3?
	local count = unlockedCount(Balance.Display.StartSlots, data.Upgrades.DisplaySlots, Balance.Display.MaxSlots)
	for index = 1, count do
		if data.Display[tostring(index)] == nil then
			return positionOf(plotPart(player, string.format(SLOT_FORMAT, index)))
		end
	end
	return positionOf(plotPart(player, string.format(SLOT_FORMAT, 1)))
end

-- Sol de sa boutique, près de l'entrée (SpawnPoint, sinon le pivot de la parcelle) : la cible de
-- l'étape 4 (on y rapporte le colis, puis on le pose au sol, L-089).
local function shopTarget(player: Player): Vector3?
	return positionOf(plotPart(player, SPAWN_POINT)) or positionOf(PlotService.GetPlot(player))
end

------------------------------------------------------------------------------
-- Zone safe et arche de la zone 2
------------------------------------------------------------------------------

-- Volume d'un objet taggé SafeZone : la pièce, sinon son enfant Bounds, sinon la boîte englobante
-- du Model (même règle que GuardService).
local function insideSafeZone(inst: Instance, position: Vector3): boolean
	local volume: Instance? = if inst:IsA("BasePart") then inst else inst:FindFirstChild(BOUNDS)
	if volume and volume:IsA("BasePart") then
		local part = volume :: BasePart
		return insideBox(part.CFrame, part.Size, position)
	end
	if inst:IsA("Model") then
		local cached = safeBoxCache[inst]
		if cached == nil then
			local cframe, size = (inst :: Model):GetBoundingBox()
			cached = { cframe = cframe, size = size }
			safeBoxCache[inst] = cached
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

-- Le joueur a passé l'arche de la zone `zone` (voir l'en-tête, étape 9 → 10).
local function pastGate(position: Vector3, zone: number): boolean
	local at = positionOf(taggedInMap(GATE_TAG, zone))
	if at == nil then
		return false
	end
	local from = positionOf(taggedInMap(GATE_TAG, zone - 1)) or positionOf(taggedInMap(SAFE_ZONE_TAG))
	local axis = if from then Vector3.new(at.X - from.X, 0, at.Z - from.Z) else Vector3.zero
	if axis.Magnitude < 1 then
		return (position - at).Magnitude <= GATE_REACH
	end
	return (position - at):Dot(axis.Unit) >= 0
end

------------------------------------------------------------------------------
-- Boutique du bot (vague 36, étapes 11 à 13)
------------------------------------------------------------------------------

-- Boutique du bot, nil sans bot (ou sans BotService).
local function botPlot(): Model?
	local api = Bot
	if api == nil then
		return nil
	end
	local ok, plot = pcall(api.GetBotPlot)
	if ok and typeof(plot) == "Instance" and (plot :: Instance):IsA("Model") then
		return plot :: Model
	end
	return nil
end

-- Porte de la boutique du bot : pivot de PlotDoor/Window (au sol au milieu de l'entrée), sinon PlotDoor, sinon
-- son SpawnPoint, sinon son pivot.
local function botDoor(plot: Model): Vector3?
	local door = plot:FindFirstChild(PLOT_DOOR, true)
	local at = if door then positionOf(door:FindFirstChild(WINDOW, true)) or positionOf(door) else nil
	return at or positionOf(Find.path(plot, SPAWN_POINT)) or plot:GetPivot().Position
end

-- `position` dans le volume Bounds de la boutique `plot`.
local function insidePlot(plot: Model, position: Vector3?): boolean
	if position == nil then
		return false
	end
	local bounds = plot:FindFirstChild(BOUNDS) or Find.path(plot, BOUNDS)
	if bounds == nil or not bounds:IsA("BasePart") then
		return false
	end
	local box = bounds :: BasePart
	return insideBox(box.CFrame, box.Size, position)
end

-- Étape 11 → 12 : dans la boutique du bot, ou à BotShopRadius studs de sa porte.
local function atBotShop(plot: Model, position: Vector3?): boolean
	if position == nil then
		return false
	end
	if insidePlot(plot, position) then
		return true
	end
	local door = botDoor(plot)
	return door ~= nil and (door - position).Magnitude <= Tutorial.BotShopRadius
end

-- Étape 12 : présentoir de l'objet exposé du bot le plus proche de `position` (tous volables depuis la vague 54) ;
-- nil sans objet exposé.
local function botItemTarget(plot: Model, position: Vector3?): Vector3?
	local api = Bot
	if api == nil then
		return nil
	end
	local ok, exposed = pcall(api.GetExposed, plot)
	if not ok or type(exposed) ~= "table" then
		return nil
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	for slot in exposed do
		if type(slot) == "number" then
			local at = positionOf(Find.path(plot, string.format(SLOT_FORMAT, slot)))
			local distance = if at and position then (at - position).Magnitude else slot
			if at and distance < bestDistance then
				best, bestDistance = at, distance
			end
		end
	end
	return best
end

-- Vague 37 : le bot poursuit-il ce joueur ? (BotService.IsChasing ; false sans bot ou avec un ancien BotService)
local function chasedByBot(player: Player): boolean
	local api = Bot
	local isChasing = if api then api.IsChasing else nil
	if isChasing == nil then
		return false
	end
	local ok, value = pcall(isChasing, player)
	return ok and value == true
end

-- Le joueur porte un objet volé au bot (portage PlayerItem de PvPService, VictimUserId 0).
local function carryingBotItem(player: Player): boolean
	local ok, payload = pcall(CarryService.GetPayload, player)
	return ok
		and type(payload) == "table"
		and payload.Kind == PLAYER_ITEM_KIND
		and payload.VictimUserId == BOT_VICTIM_USER_ID
end

------------------------------------------------------------------------------
-- Funnel (14.2)
------------------------------------------------------------------------------

local function logFunnel(player: Player, index: number)
	local logged = funnels[player]
	if logged == nil or logged[index] then
		return
	end
	logged[index] = true
	if not Telemetry.Enabled then
		return -- télémétrie coupée (voir l'en-tête)
	end
	local name = Tutorial.FunnelSteps[index] or tostring(index)
	local ok, err = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, name)
	end)
	if IS_STUDIO then
		local refused = if ok then "" else ` (refusé par Roblox en Studio : {err})`
		print(`[TutorialService] funnel {player.Name} : étape {index} « {name} »{refused}`)
	elseif not ok and not funnelWarned then
		funnelWarned = true
		warn(`[TutorialService] LogOnboardingFunnelStepEvent refusé : {err}`)
	end
end

------------------------------------------------------------------------------
-- Étapes
------------------------------------------------------------------------------

local function sameTarget(a: Vector3?, b: Vector3?): boolean
	if a == nil or b == nil then
		return a == b
	end
	return (a - b).Magnitude < 0.5
end

-- Vague 60 : have et need, la progression de l'étape (liste des tâches, Shared/TutorialTasks), nil sans progression.
local function send(session: Session, step: number, hint: string?, target: Vector3?, have: number?, need: number?)
	local last = session.sent
	if last and last.step == step and last.hint == hint and sameTarget(last.target, target) and last.have == have and last.need == need then
		return
	end
	session.sent = { step = step, hint = hint, target = target, have = have, need = need }
	session.player:SetAttribute(STEP_ATTRIBUTE, step)
	session.player:SetAttribute(HINT_ATTRIBUTE, hint)
	if have ~= nil and need ~= nil then
		Net.Server.TutorialStep:Fire(session.player, step, hint, target, have, need)
	else
		Net.Server.TutorialStep:Fire(session.player, step, hint, target)
	end
end

local function setStep(session: Session, data: Data, step: number, why: string)
	if step == session.step then
		return
	end
	local previous = session.step
	session.step = step
	-- Le profil garde l'étape la plus avancée : un retour en arrière du braquage (étapes 2 à 4) ne se
	-- sauvegarde pas, il se refait à la reprise d'après l'état du jeu (et le funnel reste exact).
	-- Vague 38 : comparé par rang (l'étape 14 se joue entre 12 et 13).
	if rank(step) > rank(data.Tutorial.Step) then
		data.Tutorial.Step = step
	end
	if step == STEP_TRAIN then
		session.trainSeconds = 0
		table.clear(session.used)
	elseif step == STEP_HIT then
		session.guaranteed = false -- nouveau braquage : l'objet du tuto est de nouveau garanti (ShelfOpen)
	elseif step == STEP_BOT_GRAB then
		session.chaseSkipped = false -- vague 60 : un nouveau vol sur le bot, sa poursuite compte de nouveau
	elseif step == STEP_BOT_SHOP then
		session.botStolen = false -- vague 36 : un vol au bot d'avant l'étape 11 ne compte pas
	end
	-- Vague 36 : funnel 11 (boutique du bot atteinte) et 12 (objet du bot pris), une seule fois (logFunnel).
	if step >= STEP_BOT_GRAB then
		logFunnel(session.player, FUNNEL_BOT_SHOP)
	end
	if step == STEP_BOT_HOME or step == STEP_BOT_CHASE then
		logFunnel(session.player, FUNNEL_BOT_GRAB)
	end
	-- Vague 38 : funnel 14, le bot semé (ou l'objet déposé) pendant l'étape 14.
	if previous == STEP_BOT_CHASE and step == STEP_BOT_HOME then
		logFunnel(session.player, FUNNEL_BOT_ESCAPE)
	end
	log(`{session.player.Name} : étape {previous} → {step} ({why})`)
end

-- Fin du tuto (fini, passé) : plus rien pour ce joueur, tout est caché chez lui.
local function finish(session: Session, data: Data?, why: string)
	local player = session.player
	if sessions[player] == session then
		sessions[player] = nil
	end
	if data then
		data.Tutorial.Done = true
	end
	player:SetAttribute(STEP_ATTRIBUTE, 0)
	player:SetAttribute(HINT_ATTRIBUTE, nil)
	Net.Server.TutorialStep:Fire(player, 0)
	log(`{player.Name} : tuto terminé à l'étape {session.step} ({why})`)
end

-- Vague 52 (L-163) : fin du tuto par le jeu. Done = true tout de suite (un départ pendant le message ne
-- fait pas rejouer la fin), puis l'indice ProtectShop MessageDuration s (evaluate), puis finish.
local function endByGame(session: Session, data: Data, why: string)
	data.Tutorial.Done = true
	session.outroUntil = os.clock() + Tutorial.MessageDuration
	session.outroWhy = why
	log(`{session.player.Name} : fin du tuto à l'étape {session.step} ({why}), message ProtectShop`)
	send(session, session.step, "ProtectShop", nil)
end

local function showShieldMessage(session: Session)
	session.shieldShown = true
	session.messageUntil = os.clock() + Tutorial.MessageDuration
	log(`{session.player.Name} : fin du bouclier débutant, message affiché`)
end

local function readShield(session: Session)
	local ok, value = pcall(NightCycleService.IsShielded, session.player)
	if not ok then
		return
	end
	local shielded = value == true
	if session.shielded == true and not shielded and not session.shieldShown then
		showShieldMessage(session)
	end
	session.shielded = shielded
end

-- Étape suivante si la condition de l'étape en cours est remplie, ou étape d'avant pour un retour en
-- arrière (voir l'en-tête) ; nil si rien ne change.
local function transition(session: Session, data: Data, position: Vector3?, carrying: boolean): (number?, string?)
	local step = session.step
	if step <= STEP_PLACE and tutorialItemHome(data, step) then
		return STEP_DISPLAY, "objet du tuto posé au sol"
	end
	local stored = findAntiTheftItem(data, false) ~= nil
	if step < STEP_PLACE and (carrying or stored) then
		return STEP_PLACE, if carrying then "objet sur la tête" else "objet sous antivol dans l'inventaire"
	end
	if step == STEP_PLACE then
		if carrying or stored then
			return nil, nil
		end
		local open = openStoreNear(position)
		if open then
			session.storeId = open
			return STEP_GRAB, "objet perdu, magasin encore ouvert"
		end
		return STEP_HIT, "objet perdu"
	end
	if step <= STEP_HIT then
		local open = openStoreNear(position)
		if open then
			session.storeId = open
			return STEP_GRAB, "vitrine cassée"
		end
		if step == STEP_ARRIVE and session.hit then
			return STEP_HIT, "premier coup sur la vitrine"
		end
		return nil, nil
	end
	if step == STEP_GRAB then
		local id = session.storeId
		if id == nil or not StoreHeistService.IsOpen(id) then
			-- Une ouverture lancée va au bout et son objet reste à lui pendant la réservation, même après le
			-- chrono (StoreHeistService) : l'étape attend.
			local store = if id then StoreHeistService.GetStoreModel(id) else nil
			if store then
				local _, _, pending = shelfState(store, session.player, position)
				if pending then
					return nil, nil
				end
			end
			return STEP_HIT, "magasin fermé sans objet"
		end
	elseif step == STEP_DISPLAY then
		if session.cashedOut then
			return STEP_TRAIN, "premier encaissement"
		end
	elseif step == STEP_TRAIN then
		if session.trainSeconds >= Tutorial.TrainDuration then
			return STEP_TOOL, `{Tutorial.TrainDuration} s d'entraînement`
		end
	elseif step == STEP_TOOL then
		if ownsToolToBuy(data) then
			return STEP_AURA, "outil acheté"
		end
	elseif step == STEP_AURA then
		if ownsAura(data) then
			return STEP_ZONE, "aura achetée"
		end
	elseif step == STEP_ZONE then
		if position and pastGate(position, Tutorial.GoalZone) then
			return STEP_SHIELD, `zone {Tutorial.GoalZone} atteinte`
		end
	elseif step == STEP_SHIELD then
		-- Vague 36 : message de fin du bouclier montré jusqu'au bout, et un bot présent (sinon evaluate finit le tuto).
		-- Vague 61 (a199) : sans WaitShieldEnd, plus d'attente du bouclier.
		local over = not Tutorial.WaitShieldEnd
			or (session.shielded == false and session.shieldShown and os.clock() >= session.messageUntil)
		if over and botPlot() ~= nil then
			return STEP_BOT_SHOP, if Tutorial.WaitShieldEnd then "fin du bouclier débutant, bot présent" else "zone 2 atteinte, bot présent"
		end
	elseif step >= STEP_BOT_SHOP then
		local plot = botPlot()
		if plot == nil then
			return nil, nil -- sans bot : evaluate finit le tuto (après l'attente d'une reprise)
		end
		local held = session.botHeld or carryingBotItem(session.player)
		local stolen = session.botStolen
		if step == STEP_BOT_SHOP then
			if held or stolen or atBotShop(plot, position) then
				return STEP_BOT_GRAB, "boutique du bot atteinte"
			end
		elseif step == STEP_BOT_GRAB then
			if held and not stolen and chasedByBot(session.player) then
				return STEP_BOT_CHASE, "objet du bot pris, le bot le poursuit" -- vague 38
			elseif held or stolen then
				return STEP_BOT_HOME, "objet du bot pris"
			end
		elseif not held and not stolen then
			return STEP_BOT_GRAB, "objet du bot perdu" -- étapes 13 et 14
		elseif step == STEP_BOT_HOME then
			-- Vague 38 : « le bot défend », objet en main pendant la poursuite. Vague 60 : pas après un Skip de l'étape 14.
			if not stolen and not session.chaseSkipped and chasedByBot(session.player) then
				return STEP_BOT_CHASE, "le bot le poursuit"
			end
		elseif step == STEP_BOT_CHASE then
			if stolen or not chasedByBot(session.player) then
				return STEP_BOT_HOME, if stolen then "objet déposé pendant la poursuite" else "bot semé avec son objet"
			end
		end
	end
	return nil, nil
end

-- Indice et cible de la flèche pour l'étape en cours (voir l'en-tête), avant le passage par la porte.
local function rawGuidance(session: Session, data: Data, position: Vector3?): (string?, Vector3?)
	local player = session.player
	local step = session.step
	if session.messageUntil > os.clock() then
		return "ShieldEnd", nil
	end
	local phase = NightCycleService.GetPhase()
	if phase == "Warning" or phase == "Night" then
		if position and NightCycleService.IsInCorridor(position) then
			return "Night", positionOf(plotPart(player, SPAWN_POINT)) or positionOf(PlotService.GetPlot(player))
		end
		if phase == "Night" and (step <= STEP_GRAB or step == STEP_ZONE) then
			return "NightClosed", nil
		end
	end
	if step <= STEP_GRAB then
		local store = storeOf(session)
		local hint: string? = nil
		local id = session.storeId
		if step == STEP_HIT and id and WindowService.IsBroken(id) and not StoreHeistService.IsOpen(id) then
			hint = "WindowRebuilding"
		end
		local target: Vector3? = nil
		if store then
			target = positionOf(Find.path(store, WINDOW)) or store:GetPivot().Position
		end
		if step == STEP_GRAB and store then
			-- L-112 : le colis du rayon à ouvrir, puis son colis qui s'ouvre, puis l'objet sorti.
			local shelfHint, shelfTarget = shelfState(store, player, position)
			return shelfHint, shelfTarget or target
		end
		return hint, target
	elseif step == STEP_PLACE then
		-- Objet sur la tête : la bulle de l'étape (rentrer à sa boutique) ; rangé sous antivol : le poser au sol.
		local hint = if npcPayload(player) == nil and findAntiTheftItem(data, false) ~= nil then "PlaceFloorItem" else nil
		return hint, shopTarget(player)
	elseif step == STEP_DISPLAY then
		local floorUid, floorItem = findAntiTheftItem(data, true)
		if floorUid and floorItem and next(data.Display) == nil then
			-- L-112 : objet au sol sous antivol (volable), puis « UNLOCKED! » et l'invite « Take » (vague 52 :
			-- a152, l'objet repris va en main).
			local unlockAt = floorItem.UnlockAt
			local unlocked = type(unlockAt) == "number" and serverNow() >= unlockAt
			return if unlocked then "TakeUnlocked" else "WaitUnlock", floorItemTarget(player, floorUid) or shopTarget(player)
		end
		if next(data.Display) ~= nil then
			return "CollectCash", collectTarget(player)
		end
		if holdsStoredItem(player, data) then
			return "DisplayUnlocked", freeSlotTarget(player, data) -- vague 52 : en main, l'invite « Display »
		end
		if hasStoredItem(data) then
			return "PlaceItem", freeSlotTarget(player, data)
		end
		if findAntiTheftItem(data, false) ~= nil then
			return "PlaceFloorItem", shopTarget(player)
		end
		return nil, freeSlotTarget(player, data)
	elseif step == STEP_TRAIN then
		if player:GetAttribute(MACHINE_ATTRIBUTE) ~= nil then
			return nil, nil
		end
		-- Le tapis n'a plus d'invite (L-071) : l'indice dit de s'arrêter dessus.
		local treadmill = machinePoint(player, TREADMILL_TAG)
		return if treadmill then "StandOnTreadmill" else nil, treadmill
	elseif step == STEP_TOOL then
		if data.Cash < toolPrice() then
			return "CollectCash", collectTarget(player)
		end
		-- Vague 61 : le don versé, l'indice le dit (« Here's $300 for the tutorial: buy the Wrench! »).
		return if gifted(data, GIFT_TOOL) then "ToolGift" else nil, positionOf(taggedInMap(WEAPON_SHOP_TAG))
	elseif step == STEP_AURA then
		if data.Cash < cheapestAura() then
			return "CollectCash", collectTarget(player)
		end
		return if gifted(data, GIFT_AURA) then "AuraGift" else nil, positionOf(taggedInMap(AURA_SHOP_TAG))
	elseif step == STEP_ZONE then
		return nil, positionOf(taggedInMap(GATE_TAG, Tutorial.GoalZone))
	elseif step == STEP_BOT_SHOP or step == STEP_BOT_GRAB then
		-- Vague 36 : la porte du bot, puis (boutique ouverte au vol, ou joueur dedans) son objet volable le plus proche.
		local plot = botPlot()
		if plot == nil then
			return nil, nil
		end
		-- Vague 37 : bulle BotChase pendant que le bot le poursuit (la flèche ne change pas).
		local chased = if chasedByBot(player) then "BotChase" else nil
		if step == STEP_BOT_GRAB and (plot:GetAttribute(STEAL_OPEN_ATTRIBUTE) == true or insidePlot(plot, position)) then
			return chased, botItemTarget(plot, position) or botDoor(plot)
		end
		if step == STEP_BOT_GRAB and chased == nil then
			return "AnyoneCanRob", botDoor(plot) -- vague 52 (L-163) : porte du bot pas encore cassée
		end
		return chased, botDoor(plot)
	elseif step == STEP_BOT_HOME or step == STEP_BOT_CHASE then
		-- dépôt : la DepositZone couvre le sol de sa boutique. Poursuivi avec l'objet : étape 14 et sa bulle (vague 38 ;
		-- avant, bulle BotChase à l'étape 13) ; la flèche ne change pas : on s'enfuit vers chez soi.
		return nil, shopTarget(player)
	end
	return nil, nil
end

-- Indice et cible de la flèche. Vague 60 (a197, Cantin) : la flèche vise la cible exacte de l'étape ; elle ne passe
-- plus d'abord par la porte de la boutique du joueur (throughDoor), sauf avec Tutorial.ArrowViaDoor (ancienne règle).
local function guidance(session: Session, data: Data, position: Vector3?): (string?, Vector3?)
	local hint, target = rawGuidance(session, data, position)
	if Tutorial.ArrowViaDoor then
		return hint, throughDoor(session.player, position, target)
	end
	return hint, target
end

-- Vague 60 (a197, liste des tâches) : progression de l'étape en cours, (have, need), ou nil, nil sans progression.
-- 6 : secondes de tapis ; 7 : argent / prix de l'outil ; 8 : argent / prix de l'aura la moins chère ; 9 : Speed
-- affichée / SpeedRequired de la zone 2 (conseil des panneaux, l'arche ne bloque pas) ; 10 : temps de jeu / durée du
-- bouclier débutant. Entiers (arrondis vers le bas) : un renvoi au plus par seconde ou par dollar.
local function progressOf(session: Session, data: Data): (number?, number?)
	local step = session.step
	if step == STEP_TRAIN then
		return math.floor(session.trainSeconds), Tutorial.TrainDuration
	elseif step == STEP_TOOL or step == STEP_AURA then
		local price = if step == STEP_TOOL then toolPrice() else cheapestAura()
		if price > 0 and price < math.huge then
			return math.floor(math.max(0, data.Cash)), price
		end
	elseif step == STEP_ZONE then
		local zone = Zones[Tutorial.GoalZone]
		local speed = session.player:GetAttribute("ShownSpeed") -- posé par StatsService
		if zone and zone.SpeedRequired > 0 and type(speed) == "number" and speed == speed then
			return math.floor(math.max(0, speed)), zone.SpeedRequired
		end
	elseif step == STEP_SHIELD then
		local getter = (NightCycleService :: any).GetShieldPlayed
		local ok, played = false, nil
		if type(getter) == "function" then
			ok, played = pcall(getter, session.player)
		end
		if ok and type(played) == "number" and played == played then
			return math.floor(math.max(0, played)), PvP.BeginnerShieldDuration
		end
	end
	return nil, nil
end

-- Relit tout pour ce joueur : étape, fin du tuto, guidage envoyé au client.
local function evaluate(session: Session)
	local player = session.player
	if sessions[player] ~= session then
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	if session.outroUntil > 0 then
		-- Vague 52 : message de fin (ProtectShop) en cours, puis tout est caché.
		if os.clock() >= session.outroUntil then
			finish(session, nil, session.outroWhy)
		else
			send(session, session.step, "ProtectShop", nil)
		end
		return
	end
	if data.Tutorial.Done then
		finish(session, nil, "profil déjà marqué fini")
		return
	end
	local root = rootOf(player)
	local position = if root then root.Position else nil
	local carrying = npcPayload(player) ~= nil
	readShield(session)

	-- Vague 36 : étapes 11 à 13 sans bot (jamais venu ou parti) : le tuto finit, sauf pendant les BotWait
	-- premières secondes d'une reprise (le bot d'un serveur neuf arrive un peu plus tard).
	if session.step >= STEP_BOT_SHOP and botPlot() == nil and os.clock() - session.startedAt >= Tutorial.BotWait then
		endByGame(session, data, "pas de bot sur le serveur : étapes du vol sautées")
		return
	end

	for _ = 1, LAST_STEP + 2 do
		local nextStep, why = transition(session, data, position, carrying)
		if nextStep == nil then
			break
		end
		setStep(session, data, nextStep, why or "")
	end

	-- Vague 61 (a199) : sans WaitShieldEnd, l'étape 10 finit tout de suite (pas de bot : la transition n'est pas passée à 11).
	if session.step == STEP_SHIELD and (not Tutorial.WaitShieldEnd or session.shielded == false) then
		if Tutorial.WaitShieldEnd and not session.shieldShown then
			showShieldMessage(session)
		end
		if os.clock() >= session.messageUntil then
			-- Avec un bot, la transition est déjà passée à l'étape 11 : ici, pas de bot (fin d'avant la vague 36).
			data.Tutorial.Step = STEP_SHIELD
			endByGame(session, data, if Tutorial.WaitShieldEnd then "bouclier débutant fini" else "zone 2 atteinte, pas de bot")
			return
		end
	end

	-- Vague 61 (a199) : dons des étapes 7 et 8 (voir l'en-tête), une seule fois par profil.
	if session.step == STEP_TOOL and not ownsToolToBuy(data) then
		if giveGift(player, data, GIFT_TOOL, Tutorial.ToolGift, toolPrice()) then
			log(`{player.Name} : don de {Tutorial.ToolGift} $ pour la clé à molette`)
		end
	elseif session.step == STEP_AURA and not ownsAura(data) then
		if giveGift(player, data, GIFT_AURA, Tutorial.AuraGift, cheapestAura()) then
			log(`{player.Name} : don de {Tutorial.AuraGift} $ pour l'aura`)
		end
	end

	-- Vague 36 : objet du bot déposé chez lui pendant l'étape 13 : le tuto est fini (Step = 13).
	if session.step == STEP_BOT_HOME and session.botStolen then
		logFunnel(player, FUNNEL_BOT_HOME)
		endByGame(session, data, "objet du bot ramené chez lui")
		return
	end

	local hint, target = guidance(session, data, position)
	local have, need = progressOf(session, data)
	send(session, session.step, hint, target, have, need)
end

local function newSession(player: Player, step: number): Session
	return {
		player = player,
		step = step,
		storeId = nil,
		hit = false,
		cashedOut = false,
		trainSeconds = 0,
		used = {},
		shielded = nil,
		shieldShown = false,
		messageUntil = 0,
		sent = nil,
		guaranteed = false,
		startedAt = os.clock(),
		botHeld = false,
		botStolen = false,
		outroUntil = 0,
		outroWhy = "",
		chaseSkipped = false,
	}
end

-- Début ou reprise du tuto, à l'arrivée sur la parcelle (voir l'en-tête).
local function start(player: Player)
	if sessions[player] then
		evaluate(sessions[player])
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local tutorial = data.Tutorial
	local step = if type(tutorial.Step) == "number" then math.floor(tutorial.Step) else 0
	if tutorial.Done then
		if step >= STEP_ARRIVE then
			funnels[player] = loggedFunnel(data) -- nouveau joueur qui a fini ou passé le tuto
		end
		return
	end
	if step < STEP_ARRIVE then
		local played = hasPlayed(data)
		if played then
			tutorial.Done = true
			log(`{player.Name} : ancien joueur ({played}), tuto marqué fini sans être lancé`)
			return
		end
		tutorial.Step = STEP_ARRIVE
		funnels[player] = {}
		logFunnel(player, FUNNEL_PLOT)
		step = STEP_ARRIVE
		log(`{player.Name} : nouveau joueur, tuto lancé à l'étape 1`)
	else
		step = math.clamp(step, STEP_ARRIVE, LAST_STEP)
		tutorial.Step = step
		funnels[player] = loggedFunnel(data)
		log(`{player.Name} : tuto repris à l'étape {step}`)
	end
	local session = newSession(player, step)
	sessions[player] = session
	evaluate(session)
end

local function stop(player: Player)
	sessions[player] = nil
	funnels[player] = nil
end

------------------------------------------------------------------------------
-- Résultats garantis (5.11) : accroches des services
------------------------------------------------------------------------------

-- Étapes 1 à 4 du tuto de ce joueur : le braquage guidé.
local function inTutorialHeist(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.step <= STEP_PLACE
end

local function installHooks()
	StoreHeistService.SetContentOverride(function(player: Player, drawn: StoreHeistService.OverrideInfo): StoreHeistService.OverrideResult?
		-- Avant la 1re prise seulement : à l'étape PlaceBox, l'objet du tuto est déjà porté ou rangé, et
		-- sinon chaque colis de zone 1 ouvert ensuite donnait l'objet garanti (audit du 2026-11-10).
		local session = sessions[player]
		if session == nil or session.step >= STEP_PLACE or drawn.Zone ~= Tutorial.TutorialZone then
			return nil
		end
		-- L-112 : appelée à la SORTIE de l'objet, pour l'ouvreur ; une seule fois par braquage (sinon chaque
		-- colis ouvert avant la prise donnerait l'objet garanti). Contenu imposé : aucun cran.
		if session.guaranteed then
			return nil
		end
		session.guaranteed = true
		local result: StoreHeistService.OverrideResult = {
			Tier = Tutorial.FirstBoxTier :: string,
			ItemId = Tutorial.GuaranteedItemId,
		}
		return result
	end)

	local baseSpeed = GuardService.GetSpeedOverride
	GuardService.GetSpeedOverride = function(player: Player, zone: number): number?
		if zone == Tutorial.TutorialZone and inTutorialHeist(player) then
			return Tutorial.GuardSpeed
		end
		return baseSpeed(player, zone)
	end

	-- L-112 : chance imposée à l'ouverture sur le rayon (Tutorial.ShelfLuck), tant que l'objet garanti
	-- n'est pas sorti dans ce braquage.
	StoreHeistService.SetLuckOverride(function(player: Player, drawn: StoreHeistService.OverrideInfo): number?
		local session = sessions[player]
		if session == nil or session.step >= STEP_PLACE or session.guaranteed or drawn.Zone ~= Tutorial.TutorialZone then
			return nil
		end
		return Tutorial.ShelfLuck
	end)
	-- L-112 : antivol raccourci de l'objet du tuto posé pendant le tuto (les 5 s du 1er colis d'avant).
	local baseAntiTheft = UnboxService.GetAntiTheftDelay
	UnboxService.GetAntiTheftDelay = function(player: Player, itemId: string): number
		if itemId == Tutorial.GuaranteedItemId and inTutorialHeist(player) then
			return Tutorial.AntiTheftDelay
		end
		return baseAntiTheft(player, itemId)
	end
end

------------------------------------------------------------------------------
-- Événements des services
------------------------------------------------------------------------------

-- Coup plausible sur la vitrine d'un magasin PNJ : outil en main, vivant, à portée (WindowService
-- l'a déjà traité : ce service ne fait que l'observer, rien n'est appliqué ici).
local function plausibleHit(player: Player, store: Model): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = rootOf(player)
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not ToolService.IsHoldingTool(player) then
		return false
	end
	local distance = windowDistance(store, root.Position)
	return distance ~= nil and distance <= Balance.Hit.ServerMaxDistance
end

local function onHitWindow(player: Player, windowId: string)
	local session = sessions[player]
	if session == nil and funnels[player] == nil then
		return
	end
	local store = StoreHeistService.GetStoreModel(windowId)
	if store == nil or not plausibleHit(player, store) then
		return
	end
	logFunnel(player, FUNNEL_HIT)
	if session and session.step <= STEP_HIT and store:GetAttribute(ZONE_ATTRIBUTE) == Tutorial.TutorialZone then
		session.hit = true
		session.storeId = windowId
		evaluate(session)
	end
end

local function onBroken(info: WindowService.BreakInfo)
	if info.Kind ~= "NPC" then
		return
	end
	logFunnel(info.Breaker, FUNNEL_BROKEN)
	for _, session in table.clone(sessions) do
		if session.step <= STEP_HIT then
			if session.player == info.Breaker and info.Model:GetAttribute(ZONE_ATTRIBUTE) == Tutorial.TutorialZone then
				session.storeId = info.WindowId
			end
			evaluate(session)
		end
	end
end

local function onCarryStarted(player: Player, payload: any)
	if type(payload) ~= "table" or payload.Kind ~= "NPCItem" then
		return
	end
	logFunnel(player, FUNNEL_GRAB)
	local session = sessions[player]
	if session then
		-- Seulement un magasin de la zone du tuto (pas un objet venu d'ailleurs, le camion par exemple).
		local storeId = payload.StoreId
		local store = if type(storeId) == "string" then StoreHeistService.GetStoreModel(storeId) else nil
		if store and store:GetAttribute(ZONE_ATTRIBUTE) == Tutorial.TutorialZone then
			session.storeId = storeId
		end
		evaluate(session)
	end
end

local function onCarryEnded(player: Player, _payload: any, result: string, _reason: string)
	-- « Consumed » : objet rangé dans l'inventaire, l'étape suit par OnItemStowed (le profil n'a pas
	-- encore l'objet ici).
	if result == "Consumed" then
		return
	end
	local session = sessions[player]
	if session then
		evaluate(session)
	end
end

-- L-112 : objet rapporté, rangé dans l'inventaire à l'entrée de la zone safe
-- (funnel 5), puis posé au sol de sa boutique sous antivol (funnel 6 ; étape 4 → 5).
local function onItemStowed(player: Player, _itemUid: string, _itemId: string)
	logFunnel(player, FUNNEL_SAFE)
	local session = sessions[player]
	if session then
		evaluate(session)
	end
end

local function onItemPlaced(player: Player, _itemUid: string, _itemId: string)
	logFunnel(player, FUNNEL_SAFE)
	logFunnel(player, FUNNEL_PLACED)
	local session = sessions[player]
	local data = DataService.Get(player)
	if session and data and session.step <= STEP_PLACE then
		setStep(session, data, STEP_DISPLAY, "objet posé au sol")
	end
	if session then
		evaluate(session)
	end
end

local function onCashOut(player: Player, amount: number, source: string)
	if source == "Leave" or source == "Offline" or amount <= 0 then
		return
	end
	logFunnel(player, FUNNEL_CASHOUT)
	local session = sessions[player]
	if session then
		if session.step == STEP_DISPLAY then
			session.cashedOut = true
		end
		evaluate(session)
	end
end

-- Vague 36 : vol sur la boutique du bot (BotService.OnTheft). Noté quelle que soit l'étape ; seules les étapes
-- 11 à 13 le lisent (botStolen remis à false en entrant à l'étape 11).
local function onBotTheft(thief: Player, _itemId: string, stage: string)
	local session = sessions[thief]
	if session == nil then
		return
	end
	if stage == "Grabbed" then
		session.botHeld = true
		-- Vague 38 : relu un peu plus tard. BotService émet « Grabbed » juste AVANT de lancer sa poursuite : relu
		-- tout de suite, l'étape 13 partirait chez le client une fraction de seconde avant l'étape 14.
		task.defer(evaluate, session)
		return
	elseif stage == "Returned" then
		session.botHeld = false
	elseif stage == "Stolen" then
		session.botHeld = false
		session.botStolen = true
	end
	evaluate(session)
end

local function onSkip(player: Player)
	local session = sessions[player]
	local data = DataService.Get(player)
	if session == nil or data == nil then
		log(`{player.Name} : TutorialSkip refusé : pas de tuto en cours`)
		return
	end
	if session.outroUntil > 0 then
		finish(session, nil, "message de fin passé") -- vague 60 : Passer pendant ProtectShop cache tout tout de suite
		return
	end
	if session.step < Tutorial.SkipFromStep then
		log(`{player.Name} : TutorialSkip refusé à l'étape {session.step} (possible à partir de l'étape {Tutorial.SkipFromStep})`)
		return
	end
	if not Tutorial.SkipOneStep then
		finish(session, data, "passé par le joueur")
		return
	end
	-- Vague 60 (a197, Cantin) : Passer saute UNE étape, dans l'ordre du jeu (voir l'en-tête, « Passer »).
	local step = session.step
	local nextStep: number? = nil
	if step >= STEP_DISPLAY and step < STEP_SHIELD then
		nextStep = step + 1
	elseif step == STEP_SHIELD then
		nextStep = if botPlot() ~= nil then STEP_BOT_SHOP else nil
	elseif step == STEP_BOT_SHOP then
		nextStep = STEP_BOT_GRAB
	elseif step == STEP_BOT_CHASE then
		nextStep = STEP_BOT_HOME
		session.chaseSkipped = true
	end
	-- Étape 12 (13 demande l'objet du bot en main) et 13 (la dernière) : passer finit le tuto.
	if nextStep == nil then
		endByGame(session, data, `étape {step} passée par le joueur, dernière étape`)
		return
	end
	session.messageUntil = 0 -- un message de fin du bouclier en cours ne cache plus l'étape suivante
	setStep(session, data, nextStep, `étape {step} passée par le joueur`)
	evaluate(session)
end

-- Contrôle régulier (voir l'en-tête) : entraînement, seuils, bouclier, nuit, et funnel 5, 8 et 10.
local function tick(dt: number)
	for player, session in table.clone(sessions) do
		if session.step == STEP_TRAIN then
			local machine = player:GetAttribute(MACHINE_ATTRIBUTE)
			if machine == "Treadmill" then
				session.trainSeconds += dt
				session.used[machine] = true
			end
		end
		evaluate(session)
	end
	for player, logged in funnels do
		if logged[FUNNEL_SAFE] and logged[FUNNEL_DISPLAYED] and logged[FUNNEL_TOOL] and logged[FUNNEL_REVEALED] then
			continue
		end
		local data = DataService.Get(player)
		if data == nil then
			continue
		end
		if not logged[FUNNEL_REVEALED] then
			-- L-112 : funnel 7 au premier objet libre (antivol fini, ou repris « UNLOCKED! ») : l'équivalent
			-- de l'ouverture en base, entre la pose (6) et l'exposition (8).
			local now = serverNow()
			for _, entry in data.Items do
				local unlockAt = if type(entry) == "table" then (entry :: any).UnlockAt else nil
				if not isAntiTheft(entry) or (type(unlockAt) == "number" and now >= unlockAt) then
					logFunnel(player, FUNNEL_REVEALED)
					break
				end
			end
		end
		if not logged[FUNNEL_SAFE] and npcPayload(player) ~= nil then
			local root = rootOf(player)
			if root and isInSafeZone(root.Position) then
				logFunnel(player, FUNNEL_SAFE)
			end
		end
		if not logged[FUNNEL_DISPLAYED] and next(data.Display) ~= nil then
			logFunnel(player, FUNNEL_DISPLAYED)
		end
		if not logged[FUNNEL_TOOL] and ownsBoughtTool(data) then
			logFunnel(player, FUNNEL_TOOL)
		end
	end
end

------------------------------------------------------------------------------
-- Crochet de test (Studio seulement)
------------------------------------------------------------------------------

local function resetPlayer(player: Player): boolean
	local data = DataService.Get(player)
	if data == nil then
		warn(`[TutorialService] TutorialReset : profil de {player.Name} pas chargé`)
		return false
	end
	data.Tutorial.Step = STEP_ARRIVE
	data.Tutorial.Done = false
	local session = newSession(player, STEP_ARRIVE)
	sessions[player] = session
	funnels[player] = {}
	log(`{player.Name} : tuto relancé depuis l'étape 1 (crochet de test)`)
	logFunnel(player, FUNNEL_PLOT)
	evaluate(session)
	return true
end

local function onResetAttribute()
	local value = Workspace:GetAttribute(RESET_ATTRIBUTE)
	if value == nil then
		return
	end
	Workspace:SetAttribute(RESET_ATTRIBUTE, nil)
	local player: Player? = nil
	local userId = tonumber(value)
	if userId then
		player = Players:GetPlayerByUserId(userId)
	elseif type(value) == "string" then
		local found = Players:FindFirstChild(value)
		player = if found and found:IsA("Player") then found else nil
	end
	if player == nil then
		warn(`[TutorialService] TutorialReset : aucun joueur « {tostring(value)} » sur ce serveur`)
		return
	end
	resetPlayer(player)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function TutorialService.GetStep(player: Player): number
	local session = sessions[player]
	return if session then session.step else 0
end

function TutorialService.IsActive(player: Player): boolean
	return sessions[player] ~= nil
end

function TutorialService.Reset(player: Player): boolean
	if not IS_STUDIO then
		warn("[TutorialService] Reset : Studio seulement")
		return false
	end
	return resetPlayer(player)
end

function TutorialService.Init()
	if not Tutorial.Enabled then
		print("[TutorialService] Config.Tutorial.Enabled = false : pas de tutoriel")
		return
	end
	installHooks()
	Net.Server.HitWindow:Connect(onHitWindow)
	Net.Server.TutorialSkip:Connect(onSkip)
	WindowService.OnBroken(onBroken)
	CarryService.OnCarryStarted(onCarryStarted)
	CarryService.OnCarryEnded(onCarryEnded)
	UnboxService.OnItemStowed(onItemStowed)
	UnboxService.OnItemPlaced(onItemPlaced)
	DisplayService.OnCashOut(onCashOut)
	local botApi = Bot
	if botApi then
		-- Vague 37 : pendant son tuto, le bot poursuit le joueur moins vite et le frappe au plus une fois.
		local previousGentle = botApi.IsGentle
		botApi.IsGentle = function(player: Player): boolean
			if sessions[player] ~= nil then
				return true
			end
			return previousGentle ~= nil and previousGentle(player)
		end
		botApi.OnTheft(onBotTheft)
		-- Arrivée ou départ du bot : les étapes 10 à 13 se relisent tout de suite.
		botApi.OnChanged(function(_plot: Model?)
			for _, session in table.clone(sessions) do
				evaluate(session)
			end
		end)
	end
	NightCycleService.OnPhaseChanged(function()
		for _, session in table.clone(sessions) do
			evaluate(session)
		end
	end)
	PlotService.OnPlotAssigned(function(player: Player, _plot: Model)
		start(player)
	end)
	Players.PlayerRemoving:Connect(stop)

	local last = os.clock()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < Tutorial.Tick then
			return
		end
		elapsed = if elapsed < 2 * Tutorial.Tick then elapsed - Tutorial.Tick else 0
		local now = os.clock()
		local step = now - last
		last = now
		local ok, err = pcall(tick :: any, step) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			warn(`[TutorialService] contrôle : {err}`)
		end
	end)

	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(RESET_ATTRIBUTE):Connect(onResetAttribute)
	end
end

return TutorialService
