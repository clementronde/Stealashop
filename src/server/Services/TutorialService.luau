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
--   - reprise : un profil à Step 1 à 10 et Done = false reprend à son étape. Step garde l'étape la
--     plus avancée atteinte ; ce qui n'est pas sauvegardé (vitrine, magasin ouvert, colis porté) est
--     relu sur place : un joueur parti avec un colis sur la tête (Step = 4) reprend à l'étape 2, car
--     le colis est revenu sur son rayon (5.6) ;
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
--   3 → 4   un colis PNJ sur la tête (CarryService), ou dans l'inventaire (Boxes sans Spot : rangé à
--           l'entrée de la zone safe, L-089) ;
--   4 → 5   un colis posé au sol de sa boutique (UnboxService.OnBoxPlaced ; L-089 : plus d'établi ni
--           de présentoir imposé) ;
--   5 → 6   premier encaissement au tapis de caisse (DisplayService.OnCashOut, sauf « Leave »,
--           l'encaissement automatique au départ) ;
--   6 → 7   TrainDuration (30) s sur le tapis ou le banc, cumulées (attribut TrainingMachine, posé
--           par TrainingService : sur le tapis, quand le joueur s'arrête sur la bande, L-071 ; au
--           banc, par son invite) ;
--   7 → 8   la clé à molette possédée (ToolToBuy), ou un outil plus fort ;
--   8 → 9   une aura possédée ;
--   9 → 10  le joueur passe l'arche de la zone 2 (ZoneGate, attribut Zone = GoalZone) : au-delà du
--           plan de l'arche, du côté opposé à l'arche de la zone 1 (sinon à la zone safe) ;
--   10      fin du bouclier débutant (NightCycleService.IsShielded) : ShieldEndMessage pendant
--           MessageDuration s, puis le tuto est fini (Step = 10, Done = true).
-- Retours en arrière, seulement pendant le braquage : étape 3 sans colis et magasin fermé → 2 ;
-- étape 4 sans colis, ni sur la tête ni dans l'inventaire (rattrapé, mort, déconnecté) → 3 si un magasin de la zone du tuto est encore
-- ouvert près du joueur, sinon 2. Ils ne changent que l'étape affichée, pas Tutorial.Step du profil
-- (l'étape la plus avancée). Une étape dont la condition est déjà remplie (reprise, achat fait
-- en avance) s'enchaîne avec la suivante dans le même contrôle. Contrôles : à chaque événement des
-- services, et toutes les Tutorial.Tick s (seuils d'argent, zone 2, bouclier, nuit, entraînement).
--
-- Résultats garantis (5.11), branchés sur les accroches des services, seulement pour ce joueur et
-- seulement pendant son tuto :
--   - 1er colis : StoreHeistService.SetContentOverride. Tant que le joueur n'a pas posé de colis
--     (étapes 1 à 4), le colis qu'il soulève dans un magasin de la zone du tuto devient un colis
--     FirstBoxTier (Premium) qui contient GuaranteedItemId (le Pot de nouilles, Rare, TutorialOnly).
--     S'il est rattrapé, le colis revient sur son rayon avec son contenu d'origine, et le suivant est
--     garanti à son tour ;
--   - vigile lent : GuardService.GetSpeedOverride rend GuardSpeed (12) pour ce joueur dans la zone
--     du tuto, aux étapes 1 à 4 ;
--   - attente de 5 s : UnboxService.GetOpenDelay rend OpenDelay pour le colis du Pot de nouilles posé
--     pendant le tuto (étapes 1 à 4) ;
--   - aucun cran d'amélioration : UnboxService.GetLuck rend 0 pour tout colis qui contient
--     GuaranteedItemId (ce colis n'existe que par le tuto ; il reste sans cran même ouvert après
--     Passer). UnboxService ne l'améliorerait pas de toute façon (Rare impossible en Premium de zone 1).
-- Les accroches d'avant sont gardées et appelées pour tous les autres cas.
--
-- Guidage envoyé au client : TutorialStep(step, hint?, target?) (9.4), au début et à chaque
-- changement, jamais deux fois le même. step = étape en cours (0 = plus de tuto : tout cacher) ;
-- hint = clé de Config/Tutorial.Hints à afficher à la place de la bulle de l'étape (nil = la bulle
-- de l'étape) ; target = point du monde visé par la flèche (nil = pas de flèche). Cibles : vitrine
-- du magasin (étapes 1 à 3 ; la Supérette tant que le joueur n'en a pas choisi un autre), sa boutique
-- (4 : son SpawnPoint, au sol près de l'entrée), colis posé au sol, puis présentoir libre (objet dans
-- l'inventaire), puis tapis de caisse (5), tapis puis banc (6), tapis de caisse ou
-- comptoir WeaponShop (7) et AuraShop (8) selon l'argent, arche de la zone 2 (9). Tapis, banc et
-- tapis de caisse sont trouvés par leur tag dans la parcelle. Boutique du hub (PLOT_Shop, L-050) :
-- entre l'intérieur de la boutique (volume Bounds) et l'extérieur, la flèche vise d'abord la porte
-- (PlotDoor/Window) ; le joueur apparaît dans sa boutique, la première flèche va donc à sa porte.
-- Indices (Hints) : WindowRebuilding (étape 2, vitrine cassée rideau baissé) ; PlaceBox (étapes 4 et 5,
-- colis dans l'inventaire) ; WaitBox, OpenBox, PlaceItem (objet dans l'inventaire, rien d'exposé),
-- CollectCash (étape 5) ; StandOnTreadmill (étape 6, flèche vers le tapis, qui n'a plus d'invite :
-- L-071) ; CollectCash (7 et 8 sans assez d'argent) ; Night (bulle de nuit 5.12 :
-- alerte ou nuit, joueur dans le couloir ; flèche vers sa parcelle) ; NightClosed (la nuit, côté
-- zone safe, aux étapes qui visent le couloir : 1 à 3 et 9 ; pas de flèche) ; ShieldEnd (fin du
-- bouclier débutant). EquipFists est choisi par le client (outil pas en main près de la vitrine).
--
-- Fin du bouclier débutant (6.4, 10 min de jeu cumulées) : quand IsShielded passe de true à false
-- pendant le tuto, ShieldEndMessage s'affiche MessageDuration s, quelle que soit l'étape (une fois
-- par session). À l'étape 10, bouclier déjà fini : le message s'affiche alors s'il ne l'a pas été
-- dans cette session, puis le tuto finit.
--
-- Passer (5.11, remote TutorialSkip, 9.4) : accepté pour un tuto en cours à l'étape SkipFromStep (5)
-- ou plus ; Done = true, Step garde l'étape passée. Refusé avant (sortie de Studio seulement).
--
-- Funnel d'onboarding (14.2) : AnalyticsService:LogOnboardingFunnelStepEvent(player, n, nom), dans
-- un pcall (refusé en Studio et côté client : la sortie de Studio l'écrit). Pour les nouveaux joueurs
-- seulement : un profil qui a commencé le tuto (Step ≥ 1), fini ou passé compris ; jamais un ancien
-- joueur. Une seule fois par joueur et par étape : déjà envoyées dans cette session, ou déjà
-- franchies d'après le profil au chargement (loggedFunnel). Roblox ne compte de toute façon que le
-- premier envoi d'une étape. Étapes : 1 tuto commencé, 2 coup sur une vitrine de magasin PNJ, 3 vitrine
-- PNJ cassée par lui, 4 colis PNJ soulevé, 5 dans la zone safe avec ce colis, 6 colis posé, 7 colis
-- ouvert, 8 un objet exposé, 9 premier encaissement, 10 un outil acheté. Interrupteur de la télémétrie
-- (Config/Telemetry.Enabled = false, DEV-054) : aucune étape n'est envoyée.
--
-- Crochet de test, STUDIO SEULEMENT : workspace:SetAttribute("TutorialReset", userId) (barre de
-- commande serveur ; un nom de joueur marche aussi). Le tuto de ce joueur repart de l'étape 1
-- (Done = false), funnel compris, même pour un ancien joueur. Les objets, colis et outils du profil
-- ne changent pas : un présentoir déjà occupé reste occupé, un colis du tuto (Pot de nouilles) encore
-- posé au sol fait reprendre à l'étape 5 et un colis de l'inventaire à l'étape 4 (l'ouvrir avant pour
-- rejouer le braquage). Hors de Studio,
-- l'attribut n'est pas écouté.
--
-- Attributs du Player (pour les tests en Studio : la barre de commande a son propre cache de modules,
-- elle lit ces attributs) : TutorialStep (le step envoyé, 0 à la fin) et TutorialHint (l'indice envoyé,
-- absent sans indice). Un joueur qui n'a jamais eu de tuto n'en a pas.
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
local Telemetry = require(Shared.Config.Telemetry)
local Tools = require(Shared.Config.Tools)
local Tutorial = require(Shared.Config.Tutorial)
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
type Box = ProfileTypes.Box

-- Ce que ce service utilise de CarryService et de DisplayService (typé ici, comme UnboxService).
type CarryApi = {
	GetPayload: (player: Player) -> any,
	OnCarryStarted: (listener: (player: Player, payload: any) -> ()) -> any,
	OnCarryEnded: (listener: (player: Player, payload: any, result: string, reason: string) -> ()) -> any,
}
type DisplayApi = {
	OnCashOut: (listener: (player: Player, amount: number, source: string) -> ()) -> any,
}
local CarryService: CarryApi = require(script.Parent.CarryService) :: any
local DisplayService: DisplayApi = require(script.Parent.DisplayService) :: any

-- Dernier guidage envoyé au client (pour ne jamais renvoyer le même).
type Sent = { step: number, hint: string?, target: Vector3? }

-- Tuto en cours d'un joueur (rien n'est gardé ici après Done).
type Session = {
	player: Player,
	step: number, -- étape en cours, copie de Tutorial.Step du profil
	storeId: string?, -- magasin de la zone du tuto du braquage en cours (StoreId = WindowId)
	hit: boolean, -- étape 1 : le joueur a frappé une vitrine de la zone du tuto
	cashedOut: boolean, -- étape 5 : premier encaissement fait
	trainSeconds: number, -- étape 6 : secondes passées sur une machine
	used: { [string]: boolean }, -- étape 6 : machines déjà utilisées ("Treadmill", "Bench")
	shielded: boolean?, -- bouclier débutant au contrôle précédent (nil : pas encore lu)
	shieldShown: boolean, -- ShieldEndMessage déjà montré dans cette session
	messageUntil: number, -- os.clock() de fin d'affichage de ShieldEndMessage (0 : rien)
	sent: Sent?,
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
local LAST_STEP = STEP_SHIELD

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
local BENCH_TAG = "Bench"
local CASH_PAD_TAG = "CashPad"
-- Entrée de la boutique du joueur (PLOT_Shop, nom validé par Ironix en L-050, pas encore au contrat).
local PLOT_DOOR = "PlotDoor"
local SLOT_FORMAT = "DisplaySlot_%02d"
-- Attribut du Player posé par TrainingService : la machine utilisée, nil sinon.
local MACHINE_ATTRIBUTE = "TrainingMachine"
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

-- Objet de la parcelle du joueur qui porte ce tag (Treadmill, Bench, CashPad : comme TrainingService,
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

------------------------------------------------------------------------------
-- Lecture du profil
------------------------------------------------------------------------------

local function npcPayload(player: Player): any
	local ok, payload = pcall(CarryService.GetPayload, player)
	if ok and type(payload) == "table" and payload.Kind == "NPCBox" then
		return payload
	end
	return nil
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
	local hasItem = next(data.Items) ~= nil
	local heisted = data.Lifetime.Heists > 0 or next(data.Boxes) ~= nil or hasItem
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
	}
end

-- Colis du tuto (le Pot de nouilles), sinon celui de plus petit uid, posé au sol (`placed` = true) ou
-- dans l'inventaire (`placed` = false, L-089) : (uid, colis).
local function findBox(data: Data, placed: boolean): (string?, Box?)
	local foundUid: string? = nil
	local foundBox: Box? = nil
	for uid, box in data.Boxes do
		if type(box) == "table" and (box.Spot ~= nil) == placed then
			if box.ItemId == Tutorial.GuaranteedItemId then
				return uid, box
			end
			if foundUid == nil or uid < (foundUid :: string) then
				foundUid, foundBox = uid, box
			end
		end
	end
	return foundUid, foundBox
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
	for uid in data.Items do
		if not placed[uid] then
			return true
		end
	end
	return false
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

local function isDisplayed(data: Data, itemUid: string): boolean
	for _, uid in data.Display do
		if uid == itemUid then
			return true
		end
	end
	return false
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

local function send(session: Session, step: number, hint: string?, target: Vector3?)
	local last = session.sent
	if last and last.step == step and last.hint == hint and sameTarget(last.target, target) then
		return
	end
	session.sent = { step = step, hint = hint, target = target }
	session.player:SetAttribute(STEP_ATTRIBUTE, step)
	session.player:SetAttribute(HINT_ATTRIBUTE, hint)
	Net.Server.TutorialStep:Fire(session.player, step, hint, target)
end

local function setStep(session: Session, data: Data, step: number, why: string)
	if step == session.step then
		return
	end
	local previous = session.step
	session.step = step
	-- Le profil garde l'étape la plus avancée : un retour en arrière du braquage (étapes 2 à 4) ne se
	-- sauvegarde pas, il se refait à la reprise d'après l'état du jeu (et le funnel reste exact).
	if step > data.Tutorial.Step then
		data.Tutorial.Step = step
	end
	if step == STEP_TRAIN then
		session.trainSeconds = 0
		table.clear(session.used)
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
	if step <= STEP_PLACE then
		local _, box = findBox(data, true)
		if box ~= nil and box.ItemId == Tutorial.GuaranteedItemId then
			return STEP_DISPLAY, "colis du tuto posé au sol"
		end
	end
	local stored = findBox(data, false) ~= nil
	if step < STEP_PLACE and (carrying or stored) then
		return STEP_PLACE, if carrying then "colis sur la tête" else "colis dans l'inventaire"
	end
	if step == STEP_PLACE then
		if carrying or stored then
			return nil, nil
		end
		local open = openStoreNear(position)
		if open then
			session.storeId = open
			return STEP_GRAB, "colis perdu, magasin encore ouvert"
		end
		return STEP_HIT, "colis perdu"
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
			return STEP_HIT, "magasin fermé sans colis"
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
		return hint, target
	elseif step == STEP_PLACE then
		-- Colis sur la tête : la bulle de l'étape (rentrer à sa boutique) ; rangé : le poser au sol.
		local hint = if npcPayload(player) == nil and findBox(data, false) ~= nil then "PlaceBox" else nil
		return hint, shopTarget(player)
	elseif step == STEP_DISPLAY then
		local uid, box = findBox(data, true)
		if uid and box then
			local readyAt = box.ReadyAt
			local ready = type(readyAt) ~= "number" or serverNow() >= readyAt
			local hint = if ready then "OpenBox" else "WaitBox"
			return hint, UnboxService.GetBoxPosition(player, uid) or shopTarget(player)
		end
		if next(data.Display) ~= nil then
			return "CollectCash", positionOf(plotTagged(player, CASH_PAD_TAG))
		end
		if hasStoredItem(data) then
			return "PlaceItem", freeSlotTarget(player, data)
		end
		if findBox(data, false) ~= nil then
			return "PlaceBox", shopTarget(player)
		end
		return nil, freeSlotTarget(player, data)
	elseif step == STEP_TRAIN then
		if player:GetAttribute(MACHINE_ATTRIBUTE) ~= nil then
			return nil, nil
		end
		if session.used.Treadmill then
			return nil, machinePoint(player, BENCH_TAG) -- le banc garde son invite « Lift »
		end
		-- Le tapis n'a plus d'invite (L-071) : l'indice dit de s'arrêter dessus.
		local treadmill = machinePoint(player, TREADMILL_TAG)
		return if treadmill then "StandOnTreadmill" else nil, treadmill
	elseif step == STEP_TOOL then
		if data.Cash < toolPrice() then
			return "CollectCash", positionOf(plotTagged(player, CASH_PAD_TAG))
		end
		return nil, positionOf(taggedInMap(WEAPON_SHOP_TAG))
	elseif step == STEP_AURA then
		if data.Cash < cheapestAura() then
			return "CollectCash", positionOf(plotTagged(player, CASH_PAD_TAG))
		end
		return nil, positionOf(taggedInMap(AURA_SHOP_TAG))
	elseif step == STEP_ZONE then
		return nil, positionOf(taggedInMap(GATE_TAG, Tutorial.GoalZone))
	end
	return nil, nil
end

-- Indice et cible de la flèche, qui passe par la porte de la boutique du joueur (throughDoor).
local function guidance(session: Session, data: Data, position: Vector3?): (string?, Vector3?)
	local hint, target = rawGuidance(session, data, position)
	return hint, throughDoor(session.player, position, target)
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
	if data.Tutorial.Done then
		finish(session, nil, "profil déjà marqué fini")
		return
	end
	local root = rootOf(player)
	local position = if root then root.Position else nil
	local carrying = npcPayload(player) ~= nil
	readShield(session)

	for _ = 1, LAST_STEP + 2 do
		local nextStep, why = transition(session, data, position, carrying)
		if nextStep == nil then
			break
		end
		setStep(session, data, nextStep, why or "")
	end

	if session.step == STEP_SHIELD and session.shielded == false then
		if not session.shieldShown then
			showShieldMessage(session)
		end
		if os.clock() >= session.messageUntil then
			data.Tutorial.Step = STEP_SHIELD
			finish(session, data, "bouclier débutant fini")
			return
		end
	end

	local hint, target = guidance(session, data, position)
	send(session, session.step, hint, target)
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
		-- Avant la 1re prise seulement : à l'étape PlaceBox, le colis du tuto est déjà porté ou rangé, et
		-- sinon chaque colis de zone 1 volé ensuite donnait l'objet garanti (audit du 2026-11-10).
		local session = sessions[player]
		if session == nil or session.step >= STEP_PLACE or drawn.Zone ~= Tutorial.TutorialZone then
			return nil
		end
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

	local baseDelay = UnboxService.GetOpenDelay
	UnboxService.GetOpenDelay = function(player: Player, box: Box): number
		if box.ItemId == Tutorial.GuaranteedItemId and inTutorialHeist(player) then
			return Tutorial.OpenDelay
		end
		return baseDelay(player, box)
	end

	local baseLuck = UnboxService.GetLuck
	UnboxService.GetLuck = function(player: Player, box: Box): number
		if box.ItemId == Tutorial.GuaranteedItemId then
			return 0
		end
		return baseLuck(player, box)
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
	if type(payload) ~= "table" or payload.Kind ~= "NPCBox" then
		return
	end
	logFunnel(player, FUNNEL_GRAB)
	local session = sessions[player]
	if session then
		-- Seulement un magasin de la zone du tuto (pas un colis venu d'ailleurs, le camion par exemple).
		local storeId = payload.StoreId
		local store = if type(storeId) == "string" then StoreHeistService.GetStoreModel(storeId) else nil
		if store and store:GetAttribute(ZONE_ATTRIBUTE) == Tutorial.TutorialZone then
			session.storeId = storeId
		end
		evaluate(session)
	end
end

local function onCarryEnded(player: Player, _payload: any, result: string, _reason: string)
	-- « Consumed » : colis rangé dans l'inventaire, l'étape suit par OnBoxStowed (le profil n'a pas
	-- encore le colis ici).
	if result == "Consumed" then
		return
	end
	local session = sessions[player]
	if session then
		evaluate(session)
	end
end

-- Colis rangé dans l'inventaire à l'entrée de la zone safe (L-089) : funnel 5.
local function onBoxStowed(player: Player, _boxUid: string, _box: Box)
	logFunnel(player, FUNNEL_SAFE)
	local session = sessions[player]
	if session then
		evaluate(session)
	end
end

local function onBoxPlaced(player: Player, _boxUid: string, _box: Box)
	logFunnel(player, FUNNEL_SAFE)
	logFunnel(player, FUNNEL_PLACED)
	local session = sessions[player]
	local data = DataService.Get(player)
	if session and data and session.step <= STEP_PLACE then
		setStep(session, data, STEP_DISPLAY, "colis posé au sol")
	end
	if session then
		evaluate(session)
	end
end

local function onBoxOpened(player: Player, _boxUid: string, itemUid: string, _itemId: string)
	logFunnel(player, FUNNEL_REVEALED)
	local data = DataService.Get(player)
	if data and isDisplayed(data, itemUid) then
		logFunnel(player, FUNNEL_DISPLAYED)
	end
	local session = sessions[player]
	if session then
		evaluate(session)
	end
end

local function onCashOut(player: Player, amount: number, source: string)
	if source == "Leave" or amount <= 0 then
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

local function onSkip(player: Player)
	local session = sessions[player]
	local data = DataService.Get(player)
	if session == nil or data == nil then
		log(`{player.Name} : TutorialSkip refusé : pas de tuto en cours`)
		return
	end
	if session.step < Tutorial.SkipFromStep then
		log(`{player.Name} : TutorialSkip refusé à l'étape {session.step} (possible à partir de l'étape {Tutorial.SkipFromStep})`)
		return
	end
	finish(session, data, "passé par le joueur")
end

-- Contrôle régulier (voir l'en-tête) : entraînement, seuils, bouclier, nuit, et funnel 5, 8 et 10.
local function tick(dt: number)
	for player, session in table.clone(sessions) do
		if session.step == STEP_TRAIN then
			local machine = player:GetAttribute(MACHINE_ATTRIBUTE)
			if machine == "Treadmill" or machine == "Bench" then
				session.trainSeconds += dt
				session.used[machine] = true
			end
		end
		evaluate(session)
	end
	for player, logged in funnels do
		if logged[FUNNEL_SAFE] and logged[FUNNEL_DISPLAYED] and logged[FUNNEL_TOOL] then
			continue
		end
		local data = DataService.Get(player)
		if data == nil then
			continue
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
	UnboxService.OnBoxStowed(onBoxStowed)
	UnboxService.OnBoxPlaced(onBoxPlaced)
	UnboxService.OnBoxOpened(onBoxOpened)
	DisplayService.OnCashOut(onCashOut)
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
