--!strict
-- StoreHeistService (DEV-015) : braquage des magasins PNJ, chrono de 10 s, rideau, rayons et
-- tirage des colis (Partie 1, sections 5.3, 5.5, 5.6, 5.7, 5.11, 5.12, 7.3 et 9.4 ; question
-- « Vitrine PNJ partagée » de la section 15 ; règles des colis de Clément, liaison L-031 et L-033,
-- acceptées par Ironix le 2026-11-07).
--
-- Magasin PNJ = Model taggé `NPCStore` (attribut Zone), posé dans la map (Workspace, hors
-- _INBOX_CLEMENT, comme WindowService). Enfants lus, cherchés parmi les descendants (contrat
-- 10.4) : `ShelfSlot_01` à `_10` (Attachments ; leur attribut Tier n'est plus lu, L-033),
-- `Bounds` (volume intérieur), `Shutter` (rideau livré en position ouvert), `Window` (on sort
-- les joueurs devant elle).
--
-- Règles :
--   - Rayons : à chaque remplissage (démarrage, RefillAll à la tombée de la nuit), le
--     serveur répartit au hasard sur les ShelfSlot du magasin un jeu neuf de colis :
--     Balance.Heist.BoxTiers[Tier].Count de chaque type (6 Standard, 3 Premium, 1 Luxe, L-033).
--     Le type appartient au colis, plus à l'emplacement : le temps de prise est celui du colis
--     (attribut Tier du colis, lu par HeistController). Magasin à moins de 10 rayons (contrat
--     incomplet) : le Luxe est posé d'abord, puis les Premium, les Standard en trop manquent.
--     Les colis sont créés par le code dans un dossier `ShelfBoxes` du magasin (`ShelfBox_01`…,
--     numéro de l'emplacement, tag ShelfBox) : le modèle du magasin n'en contient pas. Aspect :
--     modèle `BOX_<Tier>` de Clément s'il existe dans ReplicatedStorage/Assets (ou
--     ServerStorage/Assets), sinon un bloc V0 (carton brun, carton bleu scellé, caisse en bois
--     cerclée d'or, 7.3). Sur le rayon, le colis garde l'aspect de son type (pas teint).
--   - Contenu tiré à la mise en rayon (L-031), plus à la prise : la rareté selon
--     ShelfBoxes.ZoneOdds[zone][Tier] s'il existe (zone 1 = zone tuto : Communs seulement, L-033),
--     sinon Rarities.BoxOdds[Tier] (7.3) ; puis un objet au hasard parmi ceux de la zone et de
--     cette rareté (Items.Pick, catalogue v2 : plusieurs objets par case, jamais un objet
--     TutorialOnly ; un Secret, toutes zones). Case vide (Config incohérente) : la rareté tirable
--     la plus proche en dessous, avec un avertissement par case (drawContent). Ce contenu ne quitte
--     jamais le serveur avant OpenBox (5.7) : ni le colis ni son étiquette ne portent l'ItemId ou
--     le nom de l'objet.
--   - Étiquette : chaque colis du rayon porte BB_Box (CarryService.AttachBoxLabel : copie de
--     ReplicatedStorage/Assets/UI/BB_Box accrochée à son LabelPoint) : catégorie de l'objet (ligne
--     cachée tant qu'elle est vide), rareté à sa couleur, mutation cachée (MAJ 4). Le colis porté
--     garde la même étiquette (CarryService). ShelfBoxController (client) ne montre que celles des
--     colis en vue et ne garde que 25 contours.
--   - Casse (WindowService.OnBroken, vitrine d'un magasin PNJ) : le magasin ouvre pour
--     Balance.Heist.Duration (10 s). Vitrine partagée (proposition de 5.3 point 8 et de la
--     section 15) : tout le monde peut entrer ; le casseur a Balance.Heist.BreakerHeadStart
--     (1 s) d'avance exclusive pour prendre un colis. HeistTimer(storeId, endsAt) part au
--     casseur et aux joueurs à TIMER_RADIUS studs ou moins du magasin, puis à ceux qui
--     s'approchent pendant le chrono ; HeistTimer(storeId, 0) le masque.
--   - Prise : GrabItem(slotId), en deux appels (voir « Maintien » plus bas). Le serveur vérifie :
--     magasin ouvert, colis posé sur le rayon, avance du casseur, mains vides
--     (CarryService.IsCarrying), joueur vivant dans le volume Bounds et à GrabMaxDistance
--     (8 studs) au plus de l'emplacement, maintien du type du colis (Balance.Heist.BoxTiers). Le
--     rayon se vide, CarryService.StartCarry reçoit le payload avec le contenu tiré à la mise en
--     rayon (ou celui de l'accroche du tuto, plus bas), et le chrono est masqué pour ce joueur
--     (« le chrono ne compte plus pour lui », 5.3 point 5).
--   - Accroche du tuto (5.11) : StoreHeistService.SetContentOverride(fn), appelée à chaque prise
--     avant StartCarry. fn peut remplacer, pour ce joueur, le type, la rareté et l'objet du colis
--     qu'il soulève (1er colis Premium, objet Rare garanti : Tutorial.FirstBoxTier et
--     GuaranteedItemId, le Pot de nouilles, qu'aucun tirage ne donne) ;
--     le BB_Box du colis porté, construit par CarryService d'après le payload, montre alors le
--     contenu remplacé. Le colis du rayon, lui, garde le sien : s'il revient (porteur rattrapé),
--     c'est avec son contenu d'origine. TutorialService (pas encore écrit) posera cette accroche.
--   - Fermeture, à la fin du chrono : plus aucune prise ; le rideau `Shutter` tombe (il descend
--     de sa propre hauteur, comme dans la greybox) ; les joueurs dedans sans colis sont sortis
--     devant la vitrine, avec un Notify. Tant que le magasin est fermé, un joueur sans colis qui
--     se retrouve dans le volume Bounds en est sorti de la même façon (pas de camping dedans).
--   - Reconstruction : WindowService reconstruit la vitrine 20 s après la fermeture (30 s après
--     la casse). Le rideau remonte alors, et tout joueur encore dedans est sorti, colis gardé
--     (sinon il serait enfermé derrière la vitre).
--   - Les colis pris ne reviennent pas avant la nuit : RefillAll() est un nouveau tirage (5.12).
--     Pour chaque magasin, tous les colis encore posés (ou en vol de retour) sont retirés et un
--     jeu neuf est réparti au hasard, chacun avec son contenu tiré. NightCycleService (DEV-047)
--     l'appelle à chaque tombée de la nuit.
--   - Remplissage d'un magasin ouvert (choix V0, absent du doc) : il attend la fermeture du
--     magasin (fin du chrono, ou vitrine reconstruite avant). Aucun colis ne change donc sous les
--     mains d'un joueur pendant les 10 s, et la nouvelle répartition se fait rideau baissé, une fois
--     les joueurs sans colis sortis. Les autres magasins sont remplis tout de suite.
--   - Colis en vol de retour au moment d'un remplissage : retiré avec les autres (il était du
--     tirage précédent).
--   - Colis sortis du magasin (portés, ou au sol au jalon M3) : ils gardent leur contenu. Échec du
--     porteur (CarryService.OnCarryEnded, résultat « Failed », colis PNJ) : le colis revole vers
--     son emplacement (5.5), depuis la tête du porteur si elle existe encore, avec son contenu
--     d'origine (sinon mourir exprès relancerait le dé). Si son magasin a été rempli depuis sa
--     prise (nuit), il ne revient pas : nouveau tirage, pas de doublon.
--
-- Maintien (temps de prise de 5.3, vérifié par le serveur) : le client envoie GrabItem(slotId)
-- au début du maintien de l'invite, puis une seconde fois quand elle se déclenche. Le premier
-- appel ouvre un maintien sur ce colis (heure serveur) ; le second n'est accepté que si
-- GrabTime − GRAB_TIME_TOLERANCE s se sont écoulées. Pendant le maintien, le serveur revérifie
-- tout 10 fois par seconde : s'il sort du volume, s'éloigne au-delà de 8 studs, meurt, porte
-- déjà un colis, si le colis du rayon change ou si le magasin ferme, le maintien est annulé. Un
-- maintien non conclu expire GrabTime + HOLD_EXPIRY s après son début. Un seul maintien par
-- joueur : un appel sur un autre rayon remplace le précédent. Le client ne peut donc pas prendre
-- plus vite que GrabTime − 0,1 s, ni sans rester à portée pendant ce temps. Comme il n'existe
-- pas de remote d'annulation, relâcher l'invite ne prévient pas le serveur : un nouvel appui sur
-- le même rayon dans la seconde qui suit, sans s'être éloigné, conclut tout de suite (le joueur
-- est bien resté à portée tout ce temps).
--
-- Posé par le serveur, lu par HeistController et ShelfBoxController :
--   sur le magasin : StoreId (texte), HeistOpen (booléen) ; pendant le chrono seulement,
--     HeistEndsAt et HeistExclusiveUntil (heures serveur, workspace:GetServerTimeNow()) et
--     HeistBreakerId (UserId du casseur) ;
--   sur chaque colis du rayon : tag ShelfBox ; SlotId (à renvoyer dans GrabItem, « <StoreId>/03 »),
--     Slot (nom de l'Attachment, « ShelfSlot_03 »), Tier (type du colis), Landed (false tant
--     qu'un colis rendu vole) ; son étiquette BB_Box.
--
-- API (serveur) :
--   StoreHeistService.RefillAll() -> number
--       Nouveau tirage de tous les magasins (voir plus haut). Renvoie le nombre de colis posés
--       tout de suite (les magasins ouverts sont remplis à leur fermeture, pas comptés). Pour
--       NightCycleService (la nuit, 5.12).
--   StoreHeistService.IsOpen(store) -> boolean
--       store = le Model du magasin ou son StoreId. true pendant les 10 s du chrono.
--   StoreHeistService.OnBoxGrabbed(listener) -> déconnexion
--       listener(player, payload) après chaque prise réussie (CarryService.StartCarry a accepté).
--   StoreHeistService.ReturnBox(payload, from?) -> boolean
--       Remet sur son emplacement, avec son contenu d'origine, le colis sorti de ce payload NPCBox,
--       en vol depuis `from` (Vector3) s'il est donné. false si le colis est inconnu, déjà revenu,
--       d'avant un remplissage de son magasin, ou si son emplacement est occupé. Utilisé ici à
--       l'échec du porteur ; servira au colis tombé au sol qui revient au bout de 15 s (DEV-048) :
--       le payload doit être la même table que celle donnée à StartCarry (CarryService la garde).
--   StoreHeistService.SetContentOverride(fn?)
--       Accroche du tuto (voir plus haut). fn(player, drawn) -> override?, appelée à chaque prise,
--       ne doit pas yield. drawn = { StoreId, SlotId, Zone, Tier, Rarity, ItemId } (contenu du
--       colis du rayon). override = nil (rien ne change) ou { Tier?, Rarity?, ItemId? } : Tier =
--       type du colis porté (clé de Balance.Heist.BoxTiers) ; ItemId = objet (de la zone du
--       magasin, ou un Secret) ; Rarity seule = un objet de cette rareté est tiré dans la zone
--       (Items.Pick : jamais un objet TutorialOnly, sans le repli de la mise en rayon).
--       Un remplacement invalide est ignoré, avec un avertissement. nil retire l'accroche.
--   StoreHeistService.GetStoreId(model) -> string? et GetStoreModel(storeId) -> Model?
--       StoreId = l'id de vitrine de WindowService (le nom du modèle, « STORE_Z1_Superette »).
--
-- Payload d'un colis PNJ, transmis à CarryService : { Kind = "NPCBox", Tier, Zone, Rarity,
-- ItemId, StoreId, SlotId }. ItemId ne doit jamais partir vers un client avant OpenBox (5.7).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local ShelfBoxes = require(Shared.Config.ShelfBoxes)
local Zones = require(Shared.Config.Zones)
local Attributes = require(Shared.Contract.Attributes)
local Net = require(Shared.Net.Net)

local WindowService = require(script.Parent.WindowService)

export type NPCBoxPayload = {
	Kind: "NPCBox",
	Tier: string, -- "Standard", "Premium" ou "Luxe"
	Zone: number,
	Rarity: string, -- Id de Rarities ("Epic"…)
	ItemId: string, -- Id de Items ("Z3_Smartphone"…), secret jusqu'à OpenBox
	StoreId: string,
	SlotId: string,
}

-- Contenu du colis du rayon, passé à l'accroche du tuto.
export type OverrideInfo = {
	StoreId: string,
	SlotId: string,
	Zone: number,
	Tier: string,
	Rarity: string,
	ItemId: string,
}

-- Ce que l'accroche du tuto remplace (champs absents = inchangés).
export type OverrideResult = {
	Tier: string?,
	Rarity: string?,
	ItemId: string?,
}

export type ContentOverride = (player: Player, drawn: OverrideInfo) -> OverrideResult?

-- Ce que ce service utilise de CarryService (a11, DEV-017). Typé ici pour ne pas dépendre
-- des noms de types de son module.
type CarryApi = {
	StartCarry: (player: Player, payload: NPCBoxPayload) -> boolean,
	IsCarrying: (player: Player) -> boolean,
	OnCarryEnded: (listener: (player: Player, payload: any, result: string, reason: string) -> ()) -> any,
	AttachBoxLabel: (model: Model, rarityId: string, itemId: string) -> BillboardGui?,
}

local CarryService: CarryApi = require(script.Parent.CarryService) :: any

type Content = { Rarity: string, ItemId: string }

-- Colis posé sur un rayon, ou en vol vers lui.
type ShelfBox = {
	Tier: string,
	Content: Content, -- tiré à la mise en rayon (L-031), jamais envoyé aux clients
	Model: Model,
	Landed: boolean, -- false tant que le colis rendu vole vers le rayon
	StopFlight: (() -> ())?,
}

type Slot = {
	Store: Store,
	Number: number, -- 1 à 10
	Name: string, -- « ShelfSlot_03 »
	Id: string, -- « <StoreId>/03 », envoyé par le client dans GrabItem
	Attachment: Attachment,
	Box: ShelfBox?, -- colis posé (ou en vol vers le rayon) ; nil = rayon vide
}

-- Colis sorti du magasin (porté, ou au sol au jalon M3) : ce qui revient sur le rayon s'il revient.
type OutBox = {
	Slot: Slot,
	Tier: string,
	Content: Content, -- contenu d'origine, même si l'accroche du tuto a changé celui du porteur
}

type Store = {
	Id: string,
	Model: Model,
	Zone: number,
	Bounds: BasePart?,
	Window: PVInstance?,
	Shutter: PVInstance?,
	ShutterParts: { BasePart },
	ShutterCollide: { [BasePart]: boolean }, -- CanCollide d'origine, rideau ouvert
	ShutterOpen: CFrame,
	ShutterClosed: CFrame,
	ShutterDown: boolean,
	ShutterToken: number,
	StopShutter: (() -> ())?,
	Slots: { Slot },
	Folder: Folder,
	Open: boolean,
	Token: number, -- change à chaque ouverture et fermeture : périme les délais en cours
	Breaker: Player?,
	ExclusiveUntil: number, -- os.clock() de fin de l'avance du casseur
	EndsAt: number, -- heure serveur de fin du chrono
	Viewers: { [Player]: boolean }, -- joueurs qui voient le chrono
	RefillPending: boolean, -- RefillAll pendant le chrono : nouveau tirage à la fermeture
}

type Hold = { Slot: Slot, Box: ShelfBox, StartedAt: number }

type GrabbedListener = (player: Player, payload: NPCBoxPayload) -> ()

type BoxLook = {
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	Trim: Color3?, -- bande de scellé (Premium) ou cerclage (Luxe)
	Bands: number, -- 1 = scellé sur le dessus, 2 = deux cercles autour de la caisse
}

local STORE_TAG = "NPCStore" -- contrat 2.1 (Contract/Tags)
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons pas encore posées : ignorées (comme WindowService)
local SLOT_FORMAT = "ShelfSlot_%02d" -- contrat 10.4
local BOUNDS_NAME = "Bounds"
local SHUTTER_NAME = "Shutter"
local WINDOW_NAME = "Window"
local ASSETS_NAME = "Assets" -- ReplicatedStorage/Assets et ServerStorage/Assets (Clément, 9.2)
local BOX_PREFIX = "BOX_" -- BOX_Standard, BOX_Premium, BOX_Luxe (10.3, Contract/Models)

-- Noms posés par ce service, lus par HeistController et ShelfBoxController (mêmes noms là-bas).
local BOXES_FOLDER = "ShelfBoxes"
local BOX_NAME_FORMAT = "ShelfBox_%02d"
local SHELF_BOX_TAG = "ShelfBox" -- tag posé par le code, hors du contrat de la section 2.1
local STORE_ID_ATTRIBUTE = "StoreId"
local OPEN_ATTRIBUTE = "HeistOpen"
local ENDS_AT_ATTRIBUTE = "HeistEndsAt"
local EXCLUSIVE_ATTRIBUTE = "HeistExclusiveUntil"
local BREAKER_ATTRIBUTE = "HeistBreakerId"
local SLOT_ID_ATTRIBUTE = "SlotId"
local SLOT_ATTRIBUTE = "Slot"
local TIER_ATTRIBUTE = "Tier"
local LANDED_ATTRIBUTE = "Landed"

local MAX_ID_LENGTH = 64 -- longueur max d'un slotId accepté par Net (Definitions)

-- V0 proposé, absent du doc : services, joueurs et colis vérifiés 10 fois par seconde.
local TICK = 0.1
-- V0 proposé, absent du doc : après WindowService (100) pour lire les WindowId à l'Init.
local PRIORITY = 110
-- V0 proposé, absent du doc : le chrono est montré aux joueurs à 60 studs ou moins du centre
-- du magasin (le boulevard devant lui et le magasin d'en face).
local TIMER_RADIUS = 60
-- V0 proposé, absent du doc : écart du réseau toléré sur la durée de maintien.
local GRAB_TIME_TOLERANCE = 0.1
-- V0 proposé, absent du doc : un maintien non conclu expire 1 s après sa durée.
local HOLD_EXPIRY = 1
-- V0 proposé, absent du doc : rideau. Il tombe en 0,4 s, remonte en 0,8 s, et reste
-- franchissable 3 s après sa chute : un joueur qui a pris un colis dans les dernières
-- secondes, et son vigile, peuvent encore sortir. Un joueur sans colis qui entre pendant ce
-- temps est sorti comme les autres.
local SHUTTER_FALL_TIME = 0.4
local SHUTTER_RISE_TIME = 0.8
local SHUTTER_EXIT_GRACE = 3
-- V0 proposé, absent du doc : on sort les joueurs à 6 studs devant la vitrine (comme
-- l'apparition de PlotService), sol cherché de 4 studs au-dessus jusqu'à 8 en dessous.
local EJECT_DISTANCE = 6
local GROUND_RAY_UP = 4
local GROUND_RAY_DOWN = 8
local EJECT_LIFT = 0.1
-- V0 proposé, absent du doc : vol du colis rendu vers son rayon, à 150 studs/s, entre 0,4 et
-- 1,5 s, en arc (hauteur = 20 % de la distance, entre 2 et 12 studs).
local FLIGHT_SPEED = 150
local FLIGHT_MIN_TIME = 0.4
local FLIGHT_MAX_TIME = 1.5
local FLIGHT_ARC = 0.2
local FLIGHT_ARC_MIN = 2
local FLIGHT_ARC_MAX = 12

-- V0 proposé, absent du doc : blocs de remplacement tant que BOX_<Tier> n'est pas livré
-- (MOD-013). Aspect de 7.3 ; bois et or de la planche de style (10.6).
local V0_LOOKS: { [string]: BoxLook } = {
	Standard = {
		Size = Vector3.new(1.6, 1.2, 1.6),
		Color = Color3.fromRGB(176, 132, 84), -- carton brun
		Material = Enum.Material.SmoothPlastic,
		Bands = 0,
	},
	Premium = {
		Size = Vector3.new(1.8, 1.4, 1.8),
		Color = Color3.fromRGB(58, 104, 176), -- carton bleu
		Material = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(235, 235, 240), -- bande de scellé
		Bands = 1,
	},
	Luxe = {
		Size = Vector3.new(1.9, 1.6, 1.9),
		Color = Color3.fromHex("#9A5B2E"), -- bois (10.6)
		Material = Enum.Material.WoodPlanks,
		Trim = Color3.fromHex("#FFC52E"), -- or (10.6)
		Bands = 2,
	},
}

-- Messages lus par le joueur (Notify), en anglais (L-036).
local MESSAGES = {
	Closed = "Too late: the shutter came down!",
}

local IS_STUDIO = RunService:IsStudio()

local StoreHeistService = {}
StoreHeistService.Priority = PRIORITY

local stores: { [Instance]: Store } = {}
local storesById: { [string]: Store } = {}
local slotsById: { [string]: Slot } = {}
local holds: { [Player]: Hold } = {}
-- Colis sortis, par payload (la table donnée à StartCarry, que CarryService garde telle quelle).
local outBoxes: { [any]: OutBox } = {}
local grabbedListeners: { GrabbedListener } = {}
local contentOverride: ContentOverride? = nil
local lastRefusal: { [Player]: number } = {}
local templates: { [string]: Instance } = {} -- BOX_<Tier> trouvé
local templateSearched: { [string]: boolean } = {} -- cherché une fois par type, trouvé ou non
local noticed: { [string]: boolean } = {}
local random = Random.new()

-- Outils ----------------------------------------------------------------------------------

local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

local function log(message: string)
	if IS_STUDIO then
		print(`[StoreHeistService] {message}`)
	end
end

-- Avertissement écrit une seule fois par serveur (Config ou modèle mal formé).
local function warnOnce(key: string, message: string)
	if noticed[key] then
		return
	end
	noticed[key] = true
	warn(`[StoreHeistService] {message}`)
end

-- Prise refusée : signalée en Studio seulement (aide au test), une ligne par seconde et par joueur.
local function refuse(player: Player, slotId: string, reason: string)
	if not IS_STUDIO then
		return
	end
	local now = os.clock()
	if now - (lastRefusal[player] or -math.huge) < 1 then
		return
	end
	lastRefusal[player] = now
	warn(`[StoreHeistService] GrabItem de {player.Name} sur « {slotId} » refusé : {reason}`)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Boîte orientée d'une pièce ou d'un modèle.
local function boxOf(object: PVInstance): (CFrame, Vector3)
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	return (object :: Model):GetBoundingBox()
end

-- Étendue de la boîte (cf, size) le long de la direction unitaire `axis`.
local function extentAlong(cf: CFrame, size: Vector3, axis: Vector3): number
	return math.abs(cf.RightVector:Dot(axis)) * size.X
		+ math.abs(cf.UpVector:Dot(axis)) * size.Y
		+ math.abs(cf.LookVector:Dot(axis)) * size.Z
end

local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not instance:IsDescendantOf(inbox)
end

-- HumanoidRootPart d'un joueur vivant, ou nil.
local function rootOf(player: Player): (BasePart?, Humanoid?)
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

local function isCarrying(player: Player): boolean
	local ok, carrying = pcall(CarryService.IsCarrying, player)
	return ok and carrying == true
end

-- Copie mélangée de `list` (Fisher-Yates).
local function shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for index = #copy, 2, -1 do
		local other = random:NextInteger(1, index)
		copy[index], copy[other] = copy[other], copy[index]
	end
	return copy
end

-- Déplace `target` sur la trajectoire path(alpha), alpha de 0 à 1 en `duration` s, à chaque
-- Heartbeat. Renvoie une fonction qui arrête le mouvement. `done` est appelé à l'arrivée.
local function animate(target: PVInstance, path: (alpha: number) -> CFrame, duration: number, done: (() -> ())?): () -> ()
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
	connection = RunService.Heartbeat:Connect(function()
		if target.Parent == nil then
			stop()
			return
		end
		local alpha = if duration > 0 then math.min((os.clock() - started) / duration, 1) else 1
		target:PivotTo(path(alpha))
		if alpha >= 1 then
			stop()
			if done then
				done()
			end
		end
	end)
	return stop
end

-- Tirage (serveur seulement) -----------------------------------------------------------------

-- Probabilités d'un type de colis dans une zone : celles de la zone (ShelfBoxes.ZoneOdds, zone 1
-- = Communs seulement, L-033), sinon celles du type (Rarities.BoxOdds, 7.3).
local function oddsFor(tier: string, zone: number): { [string]: number }?
	local byZone = ShelfBoxes.ZoneOdds[zone]
	local odds = if byZone then byZone[tier] else nil
	return odds or Rarities.BoxOdds[tier]
end

-- Rareté tirée selon oddsFor(tier, zone) (pourcentages).
local function drawRarity(tier: string, zone: number): string?
	local odds = oddsFor(tier, zone)
	if odds == nil then
		return nil
	end
	local total = 0
	for _, rarity in Rarities.List do
		total += odds[rarity.Id] or 0
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber() * total
	local last: string? = nil
	for _, rarity in Rarities.List do
		local weight = odds[rarity.Id] or 0
		if weight > 0 then
			last = rarity.Id
			if roll < weight then
				return rarity.Id
			end
			roll -= weight
		end
	end
	return last -- arrondi des nombres à virgule : la dernière rareté possible
end

-- Un objet au hasard parmi ceux de la zone et de la rareté (Items.Pick : plusieurs objets par case
-- au catalogue v2, jamais un objet TutorialOnly) ; un Secret, toutes zones. nil si la case est vide.
local function drawItem(zone: number, rarityId: string): string?
	local item = Items.Pick(zone, rarityId :: Rarities.RarityId, random)
	return if item then item.Id else nil
end

-- Contenu d'un colis de la mise en rayon. Repli (V0 proposé, absent du doc) si la case (zone,
-- rareté) tirée est vide : la rareté tirable la plus proche en dessous, avec un avertissement par
-- case ; rien en dessous : nil (rayon laissé vide, signalé par fillStore). Le catalogue v2 n'a
-- aucune case vide qu'un tirage puisse atteindre (zone 1 : Communs seulement, ShelfBoxes.ZoneOdds) :
-- ce repli ne sert qu'à une Config incohérente. La rareté du contenu reste celle de son objet.
local function drawContent(tier: string, zone: number): Content?
	local rarity = drawRarity(tier, zone)
	if rarity == nil then
		return nil
	end
	local itemId = drawItem(zone, rarity)
	if itemId then
		return { Rarity = rarity, ItemId = itemId }
	end
	-- Rarities.List va de Commun à Secret : en partant de la fin, la première rareté plus basse qui
	-- a un objet est la plus proche en dessous.
	local drawnOrder = Rarities.ById[rarity].Order
	local list = Rarities.List
	for index = #list, 1, -1 do
		local candidate = list[index]
		if candidate.Order < drawnOrder then
			local fallbackRarity: string = candidate.Id
			local fallbackItem = drawItem(zone, fallbackRarity)
			if fallbackItem then
				warnOnce(
					`empty.{zone}.{rarity}`,
					`aucun objet {rarity} tirable en zone {zone} (Config/Items) : ces colis reçoivent un objet {fallbackRarity} à la place`
				)
				return { Rarity = fallbackRarity, ItemId = fallbackItem }
			end
		end
	end
	return nil
end

-- Types des colis d'un remplissage, du plus rare au plus courant (1 Luxe, 3 Premium, 6 Standard) :
-- si un magasin a moins de rayons que de colis, ce sont des Standard qui manquent.
local function layoutTiers(): { string }
	local list: { string } = {}
	local order = Balance.Heist.TierOrder
	for index = #order, 1, -1 do
		local tier = order[index]
		local info = Balance.Heist.BoxTiers[tier]
		local count = if info then info.Count else 0
		for _ = 1, count do
			table.insert(list, tier)
		end
	end
	return list
end

-- Colis des rayons -----------------------------------------------------------------------------

-- Modèle BOX_<Tier> de Clément, cherché une fois par type, ou nil.
local function boxTemplate(tier: string): Instance?
	if templateSearched[tier] then
		return templates[tier]
	end
	templateSearched[tier] = true
	local name = BOX_PREFIX .. tier
	local found: Instance? = nil
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild(ASSETS_NAME)
		local candidate = if assets then assets:FindFirstChild(name, true) else nil
		if candidate and (candidate:IsA("Model") or candidate:IsA("BasePart")) then
			found = candidate
			break
		end
	end
	if found then
		templates[tier] = found
	end
	return found
end

-- Bloc V0 : pivot en bas au centre (10.1), comme un BOX_* livré.
local function makeV0Box(tier: string): Model
	local look = V0_LOOKS[tier] or V0_LOOKS.Standard
	local size = look.Size
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = size
	body.CFrame = CFrame.new(0, size.Y / 2, 0)
	body.Color = look.Color
	body.Material = look.Material
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.PivotOffset = CFrame.new(0, -size.Y / 2, 0)
	body.Parent = model
	model.PrimaryPart = body
	local trim = look.Trim
	if trim then
		local bands: { CFrame } = {}
		local bandSize: Vector3
		if look.Bands == 1 then
			-- bande de scellé sur le dessus, d'un bord à l'autre
			bandSize = Vector3.new(size.X + 0.04, 0.06, size.Z * 0.25)
			table.insert(bands, CFrame.new(0, size.Y + 0.01, 0))
		else
			-- deux cercles dorés autour de la caisse
			bandSize = Vector3.new(size.X + 0.08, size.Y * 0.12, size.Z + 0.08)
			table.insert(bands, CFrame.new(0, size.Y * 0.25, 0))
			table.insert(bands, CFrame.new(0, size.Y * 0.75, 0))
		end
		for index, cf in bands do
			local band = Instance.new("Part")
			band.Name = `Trim_{index}`
			band.Size = bandSize
			band.CFrame = cf
			band.Color = trim
			band.Material = if look.Bands == 2 then Enum.Material.Metal else Enum.Material.SmoothPlastic
			band.TopSurface = Enum.SurfaceType.Smooth
			band.BottomSurface = Enum.SurfaceType.Smooth
			band.Parent = model
		end
	end
	return model
end

-- Modèle d'un colis de type `tier` pour l'emplacement `slot`, avec son étiquette BB_Box.
local function makeBoxModel(slot: Slot, tier: string, content: Content): Model
	local model: Model? = nil
	local template = boxTemplate(tier)
	if template then
		local clone = template:Clone() -- nil si le modèle n'est pas Archivable
		if clone then
			for _, descendant in clone:GetDescendants() do
				if descendant:IsA("LuaSourceContainer") then
					descendant:Destroy() -- jamais de script dans un colis (contrat)
				end
			end
			if clone:IsA("Model") then
				model = clone
			elseif clone:IsA("BasePart") then
				local wrapper = Instance.new("Model")
				clone.Parent = wrapper
				wrapper.PrimaryPart = clone
				model = wrapper
			end
		end
	end
	local box = model or makeV0Box(tier)
	for _, descendant in box:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- petit décor posé sur un rayon : ni collision, ni contact, ni requête (les rayons
			-- de ShelfBoxController et des vigiles le traversent)
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	-- Jamais « BOX_… » dans la map : ce nom est celui de l'asset (ContractChecker).
	box.Name = string.format(BOX_NAME_FORMAT, slot.Number)
	box.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- le colis et son étiquette arrivent ensemble
	box:SetAttribute(SLOT_ID_ATTRIBUTE, slot.Id)
	box:SetAttribute(SLOT_ATTRIBUTE, slot.Name)
	box:SetAttribute(TIER_ATTRIBUTE, tier)
	CollectionService:AddTag(box, SHELF_BOX_TAG)
	local ok, label = pcall(CarryService.AttachBoxLabel, box, content.Rarity, content.ItemId)
	if not ok then
		warnOnce("label.error", `CarryService.AttachBoxLabel : {label}`)
	elseif label == nil then
		warnOnce(`label.{tier}`, `colis {tier} de {slot.Id} : aucune étiquette BB_Box posée (colis sans pièce ?)`)
	end
	return box
end

local function setLanded(box: ShelfBox, landed: boolean)
	box.Landed = landed
	box.Model:SetAttribute(LANDED_ATTRIBUTE, landed)
end

-- Arrête le vol d'un colis et retire son modèle.
local function discard(box: ShelfBox)
	local stop = box.StopFlight
	if stop then
		box.StopFlight = nil
		stop()
	end
	box.Model:Destroy()
end

-- Pose un colis sur le rayon vide `slot`, en vol depuis `from` s'il est donné.
local function placeBox(slot: Slot, tier: string, content: Content, from: Vector3?)
	local model = makeBoxModel(slot, tier, content)
	local box: ShelfBox = { Tier = tier, Content = content, Model = model, Landed = false, StopFlight = nil }
	local target = slot.Attachment.WorldCFrame
	slot.Box = box
	if from == nil then
		setLanded(box, true)
		model:PivotTo(target)
		model.Parent = slot.Store.Folder
		return
	end
	setLanded(box, false)
	local start: Vector3 = from
	local rotation = target.Rotation
	local finish = target.Position
	local distance = (finish - start).Magnitude
	local height = math.clamp(distance * FLIGHT_ARC, FLIGHT_ARC_MIN, FLIGHT_ARC_MAX)
	local duration = math.clamp(distance / FLIGHT_SPEED, FLIGHT_MIN_TIME, FLIGHT_MAX_TIME)
	model:PivotTo(CFrame.new(start) * rotation)
	model.Parent = slot.Store.Folder
	box.StopFlight = animate(model, function(alpha: number): CFrame
		local position = start:Lerp(finish, alpha) + Vector3.new(0, 4 * height * alpha * (1 - alpha), 0)
		return CFrame.new(position) * rotation
	end, duration, function()
		box.StopFlight = nil
		if slot.Box == box then
			model:PivotTo(target)
			setLanded(box, true)
		end
	end)
end

local function removeBox(slot: Slot)
	local box = slot.Box
	slot.Box = nil
	if box then
		discard(box)
	end
end

local function cancelHolds(store: Store)
	for player, hold in holds do
		if hold.Slot.Store == store then
			holds[player] = nil
		end
	end
end

-- Nouveau tirage du magasin (L-031, L-033, 5.12) : retire tous ses colis (posés ou en vol de
-- retour), oublie ceux qui en sont sortis, puis répartit au hasard un jeu neuf de colis sur ses
-- rayons, chacun avec son contenu tiré. Renvoie le nombre de colis posés.
local function fillStore(store: Store): number
	store.RefillPending = false
	cancelHolds(store)
	for payload, out in outBoxes do
		if out.Slot.Store == store then
			outBoxes[payload] = nil -- tirage précédent : il ne reviendra pas
		end
	end
	for _, slot in store.Slots do
		removeBox(slot)
	end
	local tiers = layoutTiers()
	local count = 0
	for index, slot in shuffled(store.Slots) do
		local tier = tiers[index]
		if tier == nil then
			break -- plus de rayons que de colis : le reste reste vide
		end
		local content = drawContent(tier, store.Zone)
		if content then
			placeBox(slot, tier, content, nil)
			count += 1
		else
			warnOnce(
				`draw.{tier}.{store.Zone}`,
				`aucun objet ne peut sortir d'un colis {tier} en zone {store.Zone} (Config : ShelfBoxes, Rarities, Items) : rayon laissé vide`
			)
		end
	end
	return count
end

-- Rideau -------------------------------------------------------------------------------------

local function stopShutter(store: Store)
	local stop = store.StopShutter
	if stop then
		store.StopShutter = nil
		stop()
	end
end

local function setShutterSolid(store: Store, solid: boolean)
	for _, part in store.ShutterParts do
		part.CanCollide = solid
	end
end

local function restoreShutterCollide(store: Store)
	for part, canCollide in store.ShutterCollide do
		part.CanCollide = canCollide
	end
end

-- Baisse le rideau : il tombe de sa hauteur, franchissable pendant SHUTTER_EXIT_GRACE s.
local function lowerShutter(store: Store)
	local shutter = store.Shutter
	if shutter == nil or store.ShutterDown then
		return
	end
	store.ShutterDown = true
	store.ShutterToken += 1
	local token = store.ShutterToken
	stopShutter(store)
	setShutterSolid(store, false)
	local from = shutter:GetPivot()
	local to = store.ShutterClosed
	store.StopShutter = animate(shutter, function(alpha: number): CFrame
		return from:Lerp(to, TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
	end, SHUTTER_FALL_TIME)
	task.delay(SHUTTER_EXIT_GRACE, function()
		if store.ShutterToken == token and store.ShutterDown and stores[store.Model] == store then
			setShutterSolid(store, true)
		end
	end)
end

-- Remonte le rideau en position ouverte (d'un coup si `instant`).
local function raiseShutter(store: Store, instant: boolean)
	local shutter = store.Shutter
	if shutter == nil or not store.ShutterDown then
		return
	end
	store.ShutterDown = false
	store.ShutterToken += 1
	stopShutter(store)
	restoreShutterCollide(store)
	local to = store.ShutterOpen
	if instant then
		shutter:PivotTo(to)
		return
	end
	local from = shutter:GetPivot()
	store.StopShutter = animate(shutter, function(alpha: number): CFrame
		return from:Lerp(to, TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end, SHUTTER_RISE_TIME)
end

-- Sortie devant la vitrine -----------------------------------------------------------------------

-- Hauteur du sol sous `position`, cherchée autour de `referenceY` ; personnages et pièces sans
-- collision ignorés.
local function groundY(position: Vector3, referenceY: number): number
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(characters, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characters
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local origin = Vector3.new(position.X, referenceY + GROUND_RAY_UP, position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(GROUND_RAY_UP + GROUND_RAY_DOWN), 0), params)
	return if result then result.Position.Y else referenceY
end

-- Point au sol devant la vitrine, au hasard sur sa largeur, et direction vers la rue.
local function ejectSpot(store: Store): (Vector3, Vector3)
	local pivot = store.Model:GetPivot()
	local center = if store.Bounds then store.Bounds.Position else pivot.Position
	local window = store.Window
	-- Vers la rue : du centre du magasin vers sa vitrine (à défaut, l'avant du pivot, 10.1).
	local front = pivot.Position
	local out = flat(pivot.LookVector)
	local windowCf: CFrame? = nil
	local windowSize = Vector3.zero
	if window then
		local cf, size = boxOf(window)
		windowCf, windowSize = cf, size
		front = cf.Position
		local toWindow = flat(cf.Position - center)
		if toWindow.Magnitude > 1e-3 then
			out = toWindow
		end
	end
	out = if out.Magnitude > 1e-3 then out.Unit else Vector3.zAxis
	local side = Vector3.yAxis:Cross(out).Unit
	local halfWidth = if windowCf then math.max(extentAlong(windowCf, windowSize, side) / 2 - 1, 0) else 0
	local spot = front + out * EJECT_DISTANCE + side * ((random:NextNumber() * 2 - 1) * halfWidth)
	return Vector3.new(spot.X, groundY(spot, pivot.Y), spot.Z), out
end

-- Sort `player` devant la vitrine de `store`, tourné vers la rue.
local function moveOut(store: Store, player: Player, root: BasePart, humanoid: Humanoid)
	local character = player.Character
	if character == nil then
		return
	end
	local ground, out = ejectSpot(store)
	-- R15 : HipHeight = du bas du HumanoidRootPart au sol ; R6 : jambes de 2 studs.
	local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else 2
	local position = ground + Vector3.new(0, hip + root.Size.Y / 2 + EJECT_LIFT, 0)
	local target = CFrame.lookAt(position, position + out)
	character:PivotTo(target * root.CFrame:ToObjectSpace(character:GetPivot()))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

-- Sort les joueurs qui sont dans le volume Bounds : ceux sans colis, ou tous si `everyone`.
-- Renvoie les joueurs sortis.
local function ejectInside(store: Store, everyone: boolean): { Player }
	local moved: { Player } = {}
	local bounds = store.Bounds
	if bounds == nil then
		return moved
	end
	for _, player in Players:GetPlayers() do
		local root, humanoid = rootOf(player)
		if root and humanoid and inside(bounds, root.Position) and (everyone or not isCarrying(player)) then
			moveOut(store, player, root, humanoid)
			table.insert(moved, player)
		end
	end
	return moved
end

-- Chrono -----------------------------------------------------------------------------------------

local function hideTimer(store: Store, player: Player)
	if store.Viewers[player] then
		store.Viewers[player] = nil
		if player.Parent == Players then
			Net.Server.HeistTimer:Fire(player, store.Id, 0)
		end
	end
end

local function showTimer(store: Store, player: Player)
	if not store.Viewers[player] then
		store.Viewers[player] = true
		Net.Server.HeistTimer:Fire(player, store.Id, store.EndsAt)
	end
end

-- Chrono montré aux joueurs proches sans colis, masqué pour ceux qui en portent un.
local function updateViewers(store: Store)
	local center = if store.Bounds then store.Bounds.Position else store.Model:GetPivot().Position
	for _, player in Players:GetPlayers() do
		if isCarrying(player) then
			hideTimer(store, player)
		elseif not store.Viewers[player] then
			local root = rootOf(player)
			if root and (root.Position - center).Magnitude <= TIMER_RADIUS then
				showTimer(store, player)
			end
		end
	end
end

-- Ouverture et fermeture ---------------------------------------------------------------------------

local function setHeistAttributes(store: Store)
	local model = store.Model
	model:SetAttribute(OPEN_ATTRIBUTE, store.Open)
	if store.Open then
		local headStartLeft = math.max(store.ExclusiveUntil - os.clock(), 0)
		model:SetAttribute(ENDS_AT_ATTRIBUTE, store.EndsAt)
		model:SetAttribute(EXCLUSIVE_ATTRIBUTE, Workspace:GetServerTimeNow() + headStartLeft)
		model:SetAttribute(BREAKER_ATTRIBUTE, if store.Breaker then store.Breaker.UserId else nil)
	else
		model:SetAttribute(ENDS_AT_ATTRIBUTE, nil)
		model:SetAttribute(EXCLUSIVE_ATTRIBUTE, nil)
		model:SetAttribute(BREAKER_ATTRIBUTE, nil)
	end
end

-- Ferme le magasin : plus de prise, chrono masqué, rideau baissé si la vitrine est cassée,
-- joueurs sans colis sortis, puis nouveau tirage si RefillAll est passé pendant le chrono.
local function closeStore(store: Store)
	if not store.Open then
		return
	end
	store.Open = false
	store.Token += 1
	store.Breaker = nil
	setHeistAttributes(store)
	cancelHolds(store)
	for player in table.clone(store.Viewers) do
		hideTimer(store, player)
	end
	if WindowService.IsBroken(store.Id) then
		lowerShutter(store)
	end
	local moved = ejectInside(store, false)
	for _, player in moved do
		Net.Server.Notify:Fire(player, MESSAGES.Closed, "Warning")
	end
	log(`{store.Id} fermé, rideau baissé ; {#moved} joueur(s) sans colis sorti(s)`)
	if store.RefillPending then
		log(`{store.Id} : remplissage reporté à la fermeture, {fillStore(store)} colis répartis au hasard`)
	end
end

local function openStore(store: Store, breaker: Player?)
	if store.Open then
		return
	end
	local duration = Balance.Heist.Duration
	store.Open = true
	store.Token += 1
	local token = store.Token
	store.Breaker = if breaker and breaker.Parent == Players then breaker else nil
	store.ExclusiveUntil = os.clock() + Balance.Heist.BreakerHeadStart
	store.EndsAt = Workspace:GetServerTimeNow() + duration
	raiseShutter(store, true) -- au cas où il serait resté baissé
	setHeistAttributes(store)
	local first = store.Breaker
	if first and not isCarrying(first) then
		showTimer(store, first)
	end
	updateViewers(store)
	task.delay(duration, function()
		if store.Token == token and stores[store.Model] == store then
			closeStore(store)
		end
	end)
	log(
		`{store.Id} ouvert pour {duration} s par {if first then first.Name else "?"} ({Balance.Heist.BreakerHeadStart} s d'avance pour lui)`
	)
end

-- Prise ----------------------------------------------------------------------------------------------

local function grabTime(box: ShelfBox): number
	local info = Balance.Heist.BoxTiers[box.Tier]
	return if info then info.GrabTime else 0
end

-- Raison du refus d'une prise sur `slot`, ou nil si elle est permise maintenant.
local function grabRefusal(player: Player, slot: Slot): string?
	local store = slot.Store
	if not store.Open then
		return "magasin fermé"
	end
	local box = slot.Box
	if box == nil or not box.Landed then
		return "rayon vide"
	end
	if player ~= store.Breaker and os.clock() < store.ExclusiveUntil then
		return "avance du casseur"
	end
	if isCarrying(player) then
		return "mains pleines"
	end
	local root = rootOf(player)
	if root == nil then
		return "pas de personnage vivant"
	end
	local bounds = store.Bounds
	if bounds == nil then
		return "magasin sans volume Bounds"
	end
	if not inside(bounds, root.Position) then
		return "hors du volume Bounds"
	end
	local distance = (root.Position - slot.Attachment.WorldPosition).Magnitude
	if distance > Balance.Heist.GrabMaxDistance then
		return `trop loin ({math.round(distance * 10) / 10} studs)`
	end
	return nil
end

-- Contenu remis au porteur : celui du colis, ou celui de l'accroche du tuto s'il est valide.
local function contentFor(player: Player, slot: Slot, box: ShelfBox): (string, Content)
	local override = contentOverride
	if override == nil then
		return box.Tier, box.Content
	end
	local store = slot.Store
	local drawn: OverrideInfo = {
		StoreId = store.Id,
		SlotId = slot.Id,
		Zone = store.Zone,
		Tier = box.Tier,
		Rarity = box.Content.Rarity,
		ItemId = box.Content.ItemId,
	}
	local ok, result = pcall(override, player, drawn)
	if not ok then
		warn(`[StoreHeistService] accroche SetContentOverride : {result}`)
		return box.Tier, box.Content
	end
	if result == nil then
		return box.Tier, box.Content
	end
	local function invalid(reason: string): (string, Content)
		warn(`[StoreHeistService] accroche SetContentOverride pour {player.Name} ignorée : {reason}`)
		return box.Tier, box.Content
	end
	if type(result) ~= "table" then
		return invalid(`elle renvoie un {type(result)}, pas une table`)
	end
	local tier = result.Tier or box.Tier
	if type(tier) ~= "string" or Balance.Heist.BoxTiers[tier] == nil then
		return invalid(`type de colis inconnu ({tier})`)
	end
	local rarity: string = box.Content.Rarity
	local itemId: string = box.Content.ItemId
	local wantedItem = result.ItemId
	local wantedRarity = result.Rarity
	if wantedRarity ~= nil and type(wantedRarity) ~= "string" then
		return invalid(`rareté invalide ({wantedRarity})`)
	end
	if wantedItem ~= nil then
		local item = if type(wantedItem) == "string" then Items.ById[wantedItem] else nil
		if item == nil then
			return invalid(`objet inconnu ({wantedItem})`)
		end
		if wantedRarity ~= nil and wantedRarity ~= item.Rarity then
			return invalid(`{item.Id} est {item.Rarity}, pas {wantedRarity}`)
		end
		if item.Zone ~= nil and item.Zone ~= store.Zone then
			return invalid(`{item.Id} est un objet de la zone {item.Zone}, pas de la zone {store.Zone}`)
		end
		rarity, itemId = item.Rarity, item.Id
	elseif wantedRarity ~= nil and wantedRarity ~= rarity then
		local drawnItem = drawItem(store.Zone, wantedRarity)
		if drawnItem == nil then
			return invalid(`aucun objet {wantedRarity} en zone {store.Zone}`)
		end
		rarity, itemId = wantedRarity, drawnItem
	end
	if tier == box.Tier and itemId == box.Content.ItemId then
		return box.Tier, box.Content
	end
	log(`accroche du tuto : {player.Name} reçoit un colis {tier} {rarity} ({itemId}) au lieu de {box.Tier} {box.Content.Rarity}`)
	local content: Content = { Rarity = rarity, ItemId = itemId }
	return tier, content
end

local function grant(player: Player, slot: Slot)
	local store = slot.Store
	local box = slot.Box
	if box == nil then
		return
	end
	local tier, content = contentFor(player, slot, box)
	local payload: NPCBoxPayload = {
		Kind = "NPCBox",
		Tier = tier,
		Zone = store.Zone,
		Rarity = content.Rarity,
		ItemId = content.ItemId,
		StoreId = store.Id,
		SlotId = slot.Id,
	}
	-- Rayon réservé pendant l'appel : une autre prise ne peut pas passer si StartCarry attend.
	slot.Box = nil
	outBoxes[payload] = { Slot = slot, Tier = box.Tier, Content = box.Content }
	local ok, started = pcall(CarryService.StartCarry, player, payload)
	if not ok or started ~= true then
		outBoxes[payload] = nil
		if not ok then
			warn(`[StoreHeistService] CarryService.StartCarry : {started}`)
		end
		if slot.Box == nil and stores[store.Model] == store then
			slot.Box = box -- rien n'a changé : le colis reste sur le rayon
		else
			discard(box) -- rayon rempli entre-temps : pas de doublon
		end
		refuse(player, slot.Id, "CarryService a refusé le portage")
		return
	end
	discard(box)
	hideTimer(store, player)
	log(`{player.Name} prend le colis {box.Tier} {slot.Name} de {store.Id} : {content.Rarity} ({content.ItemId})`)
	for _, listener in table.clone(grabbedListeners) do
		task.spawn(listener, player, payload)
	end
end

-- GrabItem(slotId) : premier appel = début du maintien, second = fin (voir l'en-tête).
local function onGrabItem(player: Player, slotId: string)
	local slot = slotsById[slotId]
	if slot == nil then
		refuse(player, slotId, "emplacement inconnu")
		return
	end
	local hold = holds[player]
	local reason = grabRefusal(player, slot)
	if reason then
		if hold and hold.Slot == slot then
			holds[player] = nil
		end
		refuse(player, slotId, reason)
		return
	end
	local box = slot.Box :: ShelfBox -- grabRefusal a vérifié qu'il est posé
	local required = grabTime(box)
	local now = os.clock()
	if hold and hold.Slot == slot and hold.Box == box then
		local elapsed = now - hold.StartedAt
		if elapsed + GRAB_TIME_TOLERANCE >= required then
			holds[player] = nil
			grant(player, slot)
		else
			refuse(player, slotId, `maintien trop court ({math.round(elapsed * 100) / 100} s sur {required} s)`)
		end
		return
	end
	if required <= 0 then
		holds[player] = nil
		grant(player, slot)
		return
	end
	holds[player] = { Slot = slot, Box = box, StartedAt = now }
end

-- Retour d'un colis ------------------------------------------------------------------------------

local function returnBox(payload: any, from: Vector3?): boolean
	if type(payload) ~= "table" then
		return false
	end
	local out = outBoxes[payload]
	if out == nil then
		return false -- inconnu, déjà revenu, ou d'avant un remplissage de son magasin
	end
	outBoxes[payload] = nil
	local slot = out.Slot
	if stores[slot.Store.Model] ~= slot.Store or slot.Box ~= nil then
		return false -- magasin retiré, ou emplacement occupé : pas de doublon
	end
	placeBox(slot, out.Tier, out.Content, from)
	return true
end

-- Tête (ou centre) du porteur, point de départ du vol de retour.
local function carrierPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil or not character:IsDescendantOf(Workspace) then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position + Vector3.new(0, 2, 0)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, 3, 0)
	end
	return nil
end

local function onCarryEnded(player: Player, payload: any, result: string, reason: string)
	if type(payload) ~= "table" or payload.Kind ~= "NPCBox" then
		return
	end
	if result == "Consumed" then
		outBoxes[payload] = nil -- posé sur un établi : il ne reviendra jamais
		return
	end
	if result ~= "Failed" then
		return -- « Dropped » (DEV-048) : au sol, il reviendra par ReturnBox s'il n'est pas ramassé
	end
	if returnBox(payload, carrierPosition(player)) then
		log(`colis {payload.Tier} de {player.Name} ({reason}) : revient sur {payload.SlotId}`)
	else
		log(
			`colis {payload.Tier} de {player.Name} ({reason}) : ne revient pas sur {payload.SlotId} (magasin rempli depuis, ou colis inconnu)`
		)
	end
end

-- Magasins --------------------------------------------------------------------------------------------

local function findShutter(store: Store, model: Model)
	local object = model:FindFirstChild(SHUTTER_NAME, true)
	if object == nil or not object:IsA("PVInstance") then
		warn(`[StoreHeistService] {model:GetFullName()} : pas de rideau « {SHUTTER_NAME} » (Part ou Model), il ne tombera pas`)
		return
	end
	local shutter = object :: PVInstance
	local parts: { BasePart } = {}
	if object:IsA("BasePart") then
		table.insert(parts, object)
	end
	for _, descendant in shutter:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	local collide: { [BasePart]: boolean } = {}
	for _, part in parts do
		collide[part] = part.CanCollide
	end
	local cf, size = boxOf(shutter)
	local drop = extentAlong(cf, size, Vector3.yAxis)
	local open = shutter:GetPivot()
	store.Shutter = shutter
	store.ShutterParts = parts
	store.ShutterCollide = collide
	store.ShutterOpen = open
	store.ShutterClosed = open - Vector3.new(0, drop, 0)
end

local function register(instance: Instance)
	if not instance:IsA("Model") or stores[instance] ~= nil or not inMap(instance) then
		return
	end
	local model = instance :: Model
	local zone = model:GetAttribute(Attributes.Zone.Name)
	if type(zone) ~= "number" or Zones[zone] == nil then
		warn(`[StoreHeistService] {model:GetFullName()} : attribut {Attributes.Zone.Name} invalide ({zone}), magasin ignoré`)
		return
	end
	local id = WindowService.GetWindowId(model) or model.Name
	if storesById[id] ~= nil then
		warn(`[StoreHeistService] {model:GetFullName()} : StoreId « {id} » déjà pris, magasin ignoré`)
		return
	end
	local bounds = model:FindFirstChild(BOUNDS_NAME, true)
	local window = model:FindFirstChild(WINDOW_NAME, true)
	local folder = Instance.new("Folder")
	folder.Name = BOXES_FOLDER

	local store: Store = {
		Id = id,
		Model = model,
		Zone = zone,
		Bounds = if bounds and bounds:IsA("BasePart") then bounds else nil,
		Window = if window and window:IsA("PVInstance") then window else nil,
		Shutter = nil,
		ShutterParts = {},
		ShutterCollide = {},
		ShutterOpen = CFrame.identity,
		ShutterClosed = CFrame.identity,
		ShutterDown = false,
		ShutterToken = 0,
		StopShutter = nil,
		Slots = {},
		Folder = folder,
		Open = false,
		Token = 0,
		Breaker = nil,
		ExclusiveUntil = 0,
		EndsAt = 0,
		Viewers = {},
		RefillPending = false,
	}
	if store.Bounds == nil then
		warn(`[StoreHeistService] {model:GetFullName()} : pas de volume « {BOUNDS_NAME} » (Part), aucune prise possible`)
	end
	findShutter(store, model)

	-- Le type des colis ne vient plus de l'emplacement (L-033) : l'attribut Tier des ShelfSlot
	-- n'est pas lu.
	for number = 1, Balance.Heist.ShelfSlots do
		local name = string.format(SLOT_FORMAT, number)
		local attachment = model:FindFirstChild(name, true)
		if attachment == nil or not attachment:IsA("Attachment") then
			warn(`[StoreHeistService] {model:GetFullName()} : {name} manquant (Attachment), rayon ignoré`)
			continue
		end
		local slotId = `{id}/{string.format("%02d", number)}`
		if #slotId > MAX_ID_LENGTH or slotsById[slotId] ~= nil then
			warn(`[StoreHeistService] {attachment:GetFullName()} : identifiant « {slotId} » trop long ou en double, rayon ignoré`)
			continue
		end
		local slot: Slot = {
			Store = store,
			Number = number,
			Name = name,
			Id = slotId,
			Attachment = attachment,
			Box = nil,
		}
		table.insert(store.Slots, slot)
	end
	local boxTotal = #layoutTiers()
	if #store.Slots < boxTotal then
		warn(
			`[StoreHeistService] {model:GetFullName()} : {#store.Slots} rayon(s) pour {boxTotal} colis, {boxTotal - #store.Slots} colis Standard en moins`
		)
	end

	for _, slot in store.Slots do
		slotsById[slot.Id] = slot
	end
	stores[model] = store
	storesById[id] = store
	model:SetAttribute(STORE_ID_ATTRIBUTE, id)
	setHeistAttributes(store)
	folder.Parent = model
	fillStore(store) -- rayons pleins au démarrage, répartis au hasard
end

local function unregister(instance: Instance)
	local store = stores[instance]
	if store == nil then
		return
	end
	stores[instance] = nil
	storesById[store.Id] = nil
	store.Open = false
	store.Token += 1
	store.ShutterToken += 1
	stopShutter(store)
	cancelHolds(store)
	for player in table.clone(store.Viewers) do
		hideTimer(store, player)
	end
	for payload, out in outBoxes do
		if out.Slot.Store == store then
			outBoxes[payload] = nil
		end
	end
	for _, slot in store.Slots do
		slotsById[slot.Id] = nil
		removeBox(slot)
	end
	store.Folder:Destroy()
end

-- Tick : maintiens, chrono des joueurs proches, sortie des magasins fermés.
local function step()
	local now = os.clock()
	for player, hold in holds do
		local slot = hold.Slot
		if
			slot.Box ~= hold.Box
			or now - hold.StartedAt > grabTime(hold.Box) + HOLD_EXPIRY
			or grabRefusal(player, slot) ~= nil
		then
			holds[player] = nil
		end
	end
	for _, store in stores do
		if store.Open then
			updateViewers(store)
		else
			for _, player in ejectInside(store, false) do
				log(`{player.Name} sorti de {store.Id} (magasin fermé)`)
			end
		end
	end
end

local function onBroken(info: WindowService.BreakInfo)
	if info.Kind ~= "NPC" then
		return
	end
	local store = stores[info.Model]
	if store == nil then
		return
	end
	openStore(store, info.Breaker)
end

local function onRebuilt(_windowId: string, model: Model)
	local store = stores[model]
	if store == nil then
		return
	end
	closeStore(store) -- vitrine reconstruite avant la fin du chrono (WindowService.Rebuild)
	raiseShutter(store, false)
	for _, player in ejectInside(store, true) do
		log(`{player.Name} sorti de {store.Id} : la vitrine est reconstruite`)
	end
end

-- API ----------------------------------------------------------------------------------------------

function StoreHeistService.RefillAll(): number
	local count, deferred = 0, 0
	for _, store in stores do
		if store.Open then
			store.RefillPending = true -- nouveau tirage à la fermeture (voir l'en-tête)
			deferred += 1
		else
			count += fillStore(store)
		end
	end
	local later = if deferred > 0 then `, {deferred} magasin(s) ouvert(s) rempli(s) à leur fermeture` else ""
	log(`rayons remplis (nouveau tirage) : {count} colis répartis au hasard{later}`)
	return count
end

function StoreHeistService.IsOpen(store: Instance | string): boolean
	local found = if type(store) == "string" then storesById[store] else stores[store]
	return found ~= nil and found.Open
end

function StoreHeistService.OnBoxGrabbed(listener: GrabbedListener): () -> ()
	return subscribe(grabbedListeners, listener)
end

function StoreHeistService.ReturnBox(payload: NPCBoxPayload, from: Vector3?): boolean
	return returnBox(payload, from)
end

function StoreHeistService.SetContentOverride(override: ContentOverride?)
	contentOverride = override
end

function StoreHeistService.GetStoreId(model: Instance): string?
	local store = stores[model]
	return if store then store.Id else nil
end

function StoreHeistService.GetStoreModel(storeId: string): Model?
	local store = storesById[storeId]
	return if store then store.Model else nil
end

function StoreHeistService.Init()
	for _, instance in CollectionService:GetTagged(STORE_TAG) do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal(STORE_TAG):Connect(function(instance: Instance)
		-- Après WindowService, qui enregistre la vitrine sur le même signal.
		task.defer(register, instance)
	end)
	CollectionService:GetInstanceRemovedSignal(STORE_TAG):Connect(unregister)
	WindowService.OnBroken(onBroken)
	WindowService.OnRebuilt(onRebuilt)
	CarryService.OnCarryEnded(onCarryEnded)
	Net.Server.GrabItem:Connect(onGrabItem)
	Players.PlayerRemoving:Connect(function(player: Player)
		holds[player] = nil
		lastRefusal[player] = nil
		for _, store in stores do
			store.Viewers[player] = nil
		end
	end)

	local storeCount, boxCount = 0, 0
	for _, store in stores do
		storeCount += 1
		for _, slot in store.Slots do
			if slot.Box then
				boxCount += 1
			end
		end
	end
	local delivered: { string } = {}
	for _, tier in Balance.Heist.TierOrder do
		if boxTemplate(tier) then
			table.insert(delivered, BOX_PREFIX .. tier)
		end
	end
	local looks = if #delivered > 0 then `modèles {table.concat(delivered, ", ")}` else "blocs V0 (aucun BOX_* livré)"
	print(
		`[StoreHeistService] {storeCount} magasin(s) prêt(s), {boxCount} colis répartis au hasard sur les rayons, contenu tiré à la mise en rayon ({looks})`
	)
end

function StoreHeistService.Start()
	while true do
		task.wait(TICK)
		xpcall(step, function(err: any)
			warn(`[StoreHeistService] tick : {err}`)
		end)
	end
end

return StoreHeistService
