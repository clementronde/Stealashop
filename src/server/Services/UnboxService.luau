--!strict
-- UnboxService (DEV-019, L-089, L-112) : l'objet ramené en zone safe, rangé sous antivol, posé au sol de sa
-- boutique puis repris (Partie 1, sections 5.6, 5.8, 7.3, 9.4 et 9.5 ; Config/ShelfOpen, Config/Unbox).
--
-- Vague 50 (a158, décision de Cantin du 2026-11-14 : « c'est bien le fait de ramener un colis à la zone safe
-- qui n'est plus possible ») : le colis porté, rangé dans l'inventaire, posé au sol, attendu puis ouvert en
-- base n'existe plus. Retirés d'ici : le rangement d'un colis (payload « NPCBox », Boxes[uid], remote
-- BoxSecured), le colis posé (modèle FloorBox, minuteur BB_OpenTimer, remote BoxReady), l'ouverture en base
-- (remote UnboxReveal, annonce, objet sur un présentoir) et GiveBox. Les colis s'ouvrent sur place (rayon de
-- magasin, camion, coffre de la Fortune Tower : StoreHeistService) ; ce service ne voit que l'objet qui en
-- sort. Le champ Boxes reste dans le profil : DataService.convertBoxes fait de chaque colis d'un ancien profil
-- un objet de l'inventaire au chargement, et plus rien n'y écrit. Les remotes BoxReady, UnboxReveal et
-- BoxSecured restent dans Net/Definitions (le client les écoute encore) : ils ne partent plus.
-- Gardé, le tronc commun de l'antivol au sol : remotes PlaceBox et OpenBox, attribut UnboxState des
-- présentoirs, findFloor, Config.Unbox (portée, sol, MaxPlacedBoxes).
--
-- Rôle :
--   - Arrivée (5.6 ; 14.2 étape 5) : 4 fois par seconde, un porteur d'un objet sorti d'un colis (CarryService,
--     payload Kind = "NPCItem") dont le HumanoidRootPart est dans le volume d'un objet taggé SafeZone (la pièce
--     elle-même, sinon son enfant direct Bounds, sinon la boîte englobante du Model ; seulement dans la map,
--     pas dans _INBOX_CLEMENT) range son objet. Juste avant, AntiCheatService.Verify (DEV-060) contrôle tout
--     de suite son dernier déplacement (téléport) et le trajet depuis le point où ce portage a commencé
--     (OnCarryStarted) : sanctionné, l'objet vient de revoler vers son rayon et rien n'est rangé. Puis
--     CarryService.Consume le lui retire et l'objet entre dans Items sous un uid neuf, AntiTheft = true
--     (Types/Profile), dans la même exécution, sans yield ; Lifetime.Heists + 1 d'un seul tenant (braquage
--     réussi, une seule fois par objet ; celui qui ramasse un objet tombé au sol et le rentre compte le
--     braquage) ; Notify, remote ItemSecured (arrivée en zone safe, UI_Escape), IndexService.Discover.
--     Inventaire plein (DisplayService.HasInventoryRoom) : le portage échoue (« InventoryFull »).
--   - Pose : PlaceBox(itemUid, point), sur le sol de SA boutique, au point visé. Le serveur décide de tout
--     (findFloor) : le joueur a sa boutique (PlotService), ne porte rien, a moins de Unbox.MaxPlacedBoxes
--     objets au sol (V0 : 8) ; le point est dans le volume Bounds de SA boutique (à Unbox.EdgeMargin studs du
--     bord au moins) ; le sol est cherché sous ce point par un rayon vers le bas, parti de Unbox.FloorRayUp
--     studs au-dessus du bas de Bounds, parmi les pièces de la parcelle (CanQuery) : il faut une surface assez
--     plate (normale.Y ≥ FloorMinNormalY) à FloorTolerance studs au plus du bas de Bounds (le haut d'un
--     présentoir ou d'un meuble n'est pas le sol) ; ce point du sol est à portée du personnage
--     (PromptDistance + ReachTolerance studs), à BoxSpacing studs au moins des autres objets posés et à
--     StandClearance studs (à plat) au moins de chaque DisplaySlot_xx, et le volume de l'objet (BoxFootprint)
--     n'y touche aucune pièce solide de la parcelle (CanCollide : mur, meuble, présentoir). Refus : un Notify
--     (MESSAGES). Accepté : Spot = ce point dans le repère du pivot de la parcelle (Types/Profile), et
--     l'antivol démarre : UnlockAt = heure serveur + ShelfOpen.AntiTheft[rareté] (GetAntiTheftDelay), ou
--     l'heure déjà promise si elle est plus tôt. Le modèle (DisplayService.BuildFloorItem : ITM_, halo) est au
--     sol, tag FloorItem, attribut UnlockAt ; UnboxController y met BB_AntiTheft (minuteur, puis « UNLOCKED! »)
--     et les invites. Pendant l'antivol : jamais sur un présentoir (DisplayService le refuse), volable
--     (PvPService, StealFloorItem).
--   - Fini : un Notify au propriétaire ; OpenBox(itemUid) le reprend (antivol retiré) et, vague 44 (a152), le
--     met en main (HeldItemService.Give, mains libres), sinon dans l'inventaire ; jamais tout seul sur un
--     présentoir.
--   - Au retour du joueur (profil chargé et parcelle attribuée), ses objets posés reviennent à leur place
--     (l'antivol compte aussi hors ligne). Un objet dont le point n'est plus dans le volume Bounds de la
--     parcelle (modèle de boutique changé ; il doit y tenir entier) ou qui est à moins de StandClearance d'un
--     présentoir (L-141 : présentoirs déplacés) revient dans l'inventaire, sous antivol, UnlockAt gardé
--     (MESSAGES.ItemBackToInventory) : jamais perdu.
--   - Boutique Robux (Cantin, 2026-11-12 ; MonetizationService, coupée tant que Features.RobuxShop = false) :
--     GetWaiting compte les objets sous antivol au sol ([itemUid] = UnlockAt ; pas un objet porté par un
--     voleur) et SkipWait(player, itemUid, s) avance leur UnlockAt (Ouvrir maintenant, son crédit, Fast Open à
--     l'achat) ; GetAntiTheftDelay est remplaçable (Fast Open × DelayFactor).
--   - attribut UnboxState sur chaque DisplaySlot_xx d'une parcelle attribuée, lu par InventoryController et
--     DisplayController (invites « Place Item » et « Display ») : "Locked" (pas encore débloqué), "Free"
--     (libre), "Taken" (un objet exposé, ou volé en ce moment). Remis à jour 4 fois par seconde ; retiré quand
--     la parcelle se libère.
--
-- Amélioration du colis offert (DEV-050 ; valeurs dans Config.Unbox ; il ne sert plus qu'à GiveItem) : jusqu'à
-- UpgradeMax (2) crans ; chaque cran réussit avec UpgradeChance (10 %) × la chance du joueur (GetLuck, 1 par
-- défaut ; probabilité bornée à 1) et fait monter d'une rareté, dans l'ordre de Rarities.List. Un cran n'est
-- tenté que si la rareté visée n'est ni Secret ni au-dessus (Divine, L-106), peut sortir de ce type de colis
-- dans sa zone (ShelfBoxes.OddsFor(zone, tier) > 0) et a au moins un objet tirable dans la zone
-- (Items.ByZone[zone][rareté]). Sinon, comme au premier échec, l'amélioration s'arrête. Un contenu imposé
-- (rareté qui ne peut pas sortir de ce type dans sa zone) n'est jamais amélioré.
--
-- Heure serveur : UnlockAt est en secondes depuis l'époque Unix, la même échelle que os.time(), mais lue avec
-- Workspace:GetServerTimeNow(), précise au millième. Le client lit la même horloge.
--
-- Remotes : PlaceBox(itemUid, point) et OpenBox(itemUid) (client → serveur, forme et débit déjà contrôlés par
-- Net) ; ItemSecured et Notify (serveur → client).
--
-- API (côté serveur) :
--   UnboxService.Refresh(player)
--       Recalcule tout de suite l'attribut UnboxState des présentoirs (après l'achat d'un présentoir,
--       ShopService) ; sinon la boucle le fait au plus 0,25 s plus tard.
--   UnboxService.GetAntiTheftDelay(player, itemId) -> number
--       Durée de l'antivol de l'objet qu'on pose (ShelfOpen.AntiTheft[rareté] par défaut). Remplaçable
--       (TutorialService : 5 s pour l'objet du tuto ; MonetizationService : Fast Open) :
--         UnboxService.GetAntiTheftDelay = function(player, itemId) ... end
--       Ne doit pas yield. Une valeur qui n'est pas un nombre fini ≥ 0 est ignorée.
--   UnboxService.GetLuck(player, box) -> number
--       Chance du joueur pour l'amélioration d'un colis offert (GiveItem ; box : Tier, Zone, ItemId, Rarity).
--       1 par défaut. Remplaçable comme GetAntiTheftDelay ; 0 = aucun cran. Ne doit pas yield. Une valeur qui
--       n'est pas un nombre fini ≥ 0 est ignorée (chance 1).
--   UnboxService.RollUpgrades(box, luck, rng?) -> { RarityId }
--       Le tirage de l'amélioration (règle plus haut), sans rien changer : les raretés atteintes, cran par
--       cran (vide : aucun cran). Pur, sans yield ; rng = un Random (celui du service par défaut).
--   UnboxService.OnItemStowed(listener), OnItemPlaced(listener) -> déconnexion
--       listener(player, itemUid, itemId) après chaque objet rangé sous antivol à l'entrée de la zone safe,
--       et après chaque objet posé au sol (tutoriel, boutique Robux).
--   UnboxService.GiveItem(player, tier, zone, minRarity?) -> (string?, string?, string?)
--       Vague 43 (récompenses, RewardService) : objet offert, tiré comme le contenu d'un colis de ce type dans
--       cette zone (ShelfBoxes.OddsFor, seulement parmi minRarity et au-dessus si minRarity est donné, parmi
--       les raretés qui ont un objet ; mutation tirée comme à la mise en rayon), puis les crans d'amélioration
--       (rollUpgrades, GetLuck), et l'objet entre tout de suite dans Items (Source « NPC », Zone, Mutation ;
--       sans antivol), IndexService.Discover, inventaire remis à jour. Inventaire plein
--       (DisplayService.HasInventoryRoom) : rien n'est écrit. Renvoie (uid de l'objet, nil, ItemId), ou nil et
--       la raison : "NoProfile", "InventoryFull", "Invalid", "NoContent". Sans yield.
--   UnboxService.GiveBoxRarityItem(player, boxRarity, zone) -> (string?, string?, string?)
--       Vague 80 (a267, coffre hebdomadaire) : pareil, pour un colis de RAYON de rareté boxRarity (vague 76) :
--       zone portée à la première où cette rareté existe ; rareté de l'objet tirée dans
--       ShelfBoxes.ContentWeights(boxRarity, 1, zone) (comme ce colis ouvert sur un rayon de cette zone, chance ×1),
--       sans cran d'amélioration ; vague 81 (a268) : plancher à boxRarity (les poids sous le plancher sont retirés :
--       boxRarity ou mieux, jamais en dessous). Sert aussi aux lots « colis d'une rareté » des quêtes et de la roue
--       (Prize/Grant). Mêmes retours.
--   UnboxService.GiveZoneBoxItem(player, rule, bestZone) -> (string?, string?, string?, ZoneBoxGift?)
--       a309 (Cantin, 22/11 ; paliers de 15 et 60 min, RewardService) : l'objet d'un colis de zone (règle de
--       Config/Rewards.ZoneBox) : zone et chances par Shared/ZoneBoxOdds, qui lit Config/Zones, Rarities.ZoneOdds et
--       ZoneRarities au moment du tirage ; objet Items.Pick(zone, rareté), mutation comme à la mise en rayon, sans cran
--       d'amélioration ; mêmes retours que GiveItem, plus { Zone, Rarity, Chance (%), StartRarity, Effect } pour l'ouverture
--       (MonetizationService.StartGiftReveal). Sans yield.
--   Pour PvPService (vol d'un objet sous antivol au sol), sans yield : GetFloorItem(owner, uid) -> FloorItem?,
--       GetFloorItems(owner), IsStealable(owner, uid), HoldFloorItem (le modèle sort du monde, plus de
--       reprise), ReleaseFloorItem (vol raté : il revient), TakeFloorItem (dépôt : le modèle part ; PvPService
--       retire l'objet du profil), IsFloorHeld.
--   Boutique Robux (DEV-100, MonetizationService : « Ouvrir maintenant », « Ouverture rapide ») :
--   UnboxService.GetWaiting(player) -> { [string]: number }
--       Objets sous antivol posés du joueur pas encore débloqués : [uid de l'objet] = heure serveur (UnlockAt).
--   UnboxService.SkipWait(player, itemUid, seconds) -> number?
--       Avance de `seconds` (au plus jusqu'à maintenant) la fin de l'antivol de cet objet posé, dans le profil
--       et au sol ; renvoie l'attente restante (0 = débloqué), nil s'il n'est pas posé et en attente. Sans yield.
--   Accroches du colis posé et ouvert en base (GetOpenDelay, OnBoxPlaced, OnBoxOpened, OnBoxStowed,
--       GetBoxPosition) : retirées aux vagues 52 et 53, plus aucun appelant.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local ItemWeight = require(Shared.ItemWeight) -- vague 62 (a203)
local Rarities = require(Shared.Config.Rarities)
local ShelfBoxes = require(Shared.Config.ShelfBoxes)
local ShelfOpen = require(Shared.Config.ShelfOpen)
local Unbox = require(Shared.Config.Unbox)
local Zones = require(Shared.Config.Zones)
local ZoneBoxOdds = require(Shared.ZoneBoxOdds) -- a309
local Find = require(Shared.Contract.Find)

local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)
local AntiCheatService = require(script.Parent.AntiCheatService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

type Box = ProfileTypes.Box
type Data = ProfileTypes.Data
type Spot = ProfileTypes.Spot
type StandState = "Locked" | "Free" | "Taken"

-- Ce qu'UnboxService utilise de CarryService (a11), de DisplayService (a14, a46) et d'InventoryService
-- (a51). Payload d'un objet sorti d'un colis : { Kind = "NPCItem", ItemId, Rarity, Mutation?, Zone, StoreId, SlotId, Luck }.
type CarryApi = {
	IsCarrying: (player: Player) -> boolean,
	GetPayload: (player: Player) -> any,
	Consume: (player: Player) -> any,
	Fail: (player: Player, reason: string) -> boolean,
	OnCarryStarted: (listener: (player: Player, payload: any) -> ()) -> any,
	OnCarryEnded: (listener: (player: Player, payload: any, result: string, reason: string) -> ()) -> any,
}
type DisplayApi = {
	-- Moins de Balance.Display.InventoryMax objets dans l'inventaire (L-089).
	HasInventoryRoom: (player: Player) -> boolean,
	-- Présentoirs de la parcelle du joueur ([numéro] = Attachment DisplaySlot_xx, bonus posés compris)
	-- et leur état : "Free", "Locked", "Taken".
	GetSlots: (player: Player) -> { [number]: Attachment },
	GetSlotStates: (player: Player) -> { [number]: string },
	-- Vague 31 (L-112) : modèle d'un objet sous antivol posé au sol.
	BuildFloorItem: (ownerUserId: number, pivot: CFrame, itemUid: string, entry: any) -> Model?,
}
type InventoryApi = {
	Refresh: (player: Player) -> (),
}

local CarryService: CarryApi = require(script.Parent.CarryService) :: any
local DisplayService: DisplayApi = require(script.Parent.DisplayService) :: any
-- Barre d'inventaire (InventoryService, a51), chargée si elle est là : sans elle (banc d'essai), rien ne
-- va dans la barre, le profil reste juste.
local inventoryModule = script.Parent:FindFirstChild("InventoryService")
local inventoryLoaded: boolean, inventoryResult: any = false, nil
if inventoryModule and inventoryModule:IsA("ModuleScript") then
	inventoryLoaded, inventoryResult = pcall(require, inventoryModule)
end
local InventoryService: InventoryApi? = if inventoryLoaded and type(inventoryResult) == "table" then inventoryResult :: any else nil

-- Vague 31 (L-112) : objet sous antivol rangé à l'arrivée, ou posé au sol (itemId = Id du catalogue).
export type ItemListener = (player: Player, itemUid: string, itemId: string) -> ()

-- Objet sous antivol posé au sol et volable en ce moment (PvPService, vague 31).
export type FloorItem = {
	Uid: string,
	ItemId: string,
	Rarity: string,
	Income: number, -- $/s de l'objet, mutation comprise, sans bonus (BB_Carry du voleur)
	Position: Vector3, -- pied de l'objet, au sol
	UnlockAt: number, -- heure serveur de la fin de l'antivol
}

-- Objet sous antivol affiché au sol (vague 31).
type ShownItem = {
	model: Model?, -- sorti du monde (Parent = nil) pendant qu'un voleur le porte
	base: CFrame, -- point du sol, tourné comme la parcelle
	unlockAt: number,
	unlocked: boolean,
	held: boolean, -- porté par un voleur (PvPService) : ni repris, ni reposé, ni revolé
}


-- Parcelle d'un joueur présent, telle que ce service l'affiche.
type Session = {
	plot: Model,
	slots: { [number]: Attachment }, -- présentoirs de la parcelle (DisplayService.GetSlots)
	items: { [string]: ShownItem }, -- vague 31 : objets sous antivol posés au sol, par uid d'objet
	states: { [number]: StandState? }, -- dernier UnboxState écrit sur chaque présentoir
}

-- Début du portage d'un objet sorti d'un colis (DEV-060), pour le contrôle du trajet au rangement : la table du
-- payload (celle de CarryService), la position du HumanoidRootPart et os.clock() à ce moment.
type CarryStart = { Payload: any, From: Vector3, At: number }

-- Contrat (10.4).
local BOUNDS = "Bounds"
local SAFE_ZONE_TAG = "SafeZone"
local INBOX_NAME = "_INBOX_CLEMENT"
-- Attribut de la parcelle posé par PlotService : UserId du propriétaire, 0 = libre.
local OWNER_ATTRIBUTE = "OwnerUserId"
-- Attributs posés par ce service (voir l'en-tête).
local STATE_ATTRIBUTE = "UnboxState"
local RARITY_ATTRIBUTE = "Rarity"
-- Vague 31 (L-112) : payload.Kind d'un objet sorti d'un colis ouvert sur le rayon (Types/Carry, a103) ;
-- objet sous antivol posé au sol : Model FloorItem (DisplayService.BuildFloorItem), tag de code FloorItem
-- (lu par UnboxController : BB_AntiTheft, invites « Display » et « Steal »), attributs ItemUid, ItemId,
-- Rarity, OwnerUserId, MutationSize, MutationEffect (DisplayService) et UnlockAt (heure serveur de la fin
-- de l'antivol, posé ici).
local NPC_ITEM_KIND = "NPCItem"
local FLOOR_ITEM_NAME = "FloorItem"
local FLOOR_ITEM_TAG = "FloorItem"
local UNLOCK_AT_ATTRIBUTE = "UnlockAt"
-- V0 proposé, absent du doc : antivol d'une rareté absente de ShelfOpen.AntiTheft (le plus long de la table).
local MAX_ANTI_THEFT = (function(): number
	local longest = 0
	for _, seconds in ShelfOpen.AntiTheft do
		longest = math.max(longest, seconds)
	end
	return longest
end)()

-- V0 proposé, absent du doc : portée (studs) de l'invite d'un objet posé, la même que celle
-- d'UnboxController, et marge du serveur pour la gigue réseau. Le serveur accepte PlaceBox et
-- OpenBox jusqu'à PROMPT_DISTANCE + REACH_TOLERANCE entre le HumanoidRootPart et le point du sol.
-- Valeurs dans Config.Unbox, partagées avec le client.
local PROMPT_DISTANCE = Unbox.PromptDistance
local REACH_TOLERANCE = Unbox.ReachTolerance
-- V0 proposé, absent du doc : cadence (s) de la boucle qui fait avancer les antivols, range les
-- objets portés dans la zone safe et remet à jour UnboxState.
local TICK = 0.25
-- V0 proposé, absent du doc : le volume de l'objet posé part de cette hauteur (studs) au-dessus du sol
-- (le sol lui-même ne le bloque pas).
local FOOTPRINT_LIFT = 0.1
-- V0 proposé, absent du doc : arrondi (studs) du point enregistré dans Spot.
local SPOT_ROUND = 0.01
-- V0 proposé, absent du doc : bloc de remplacement d'un objet posé au sol sans modèle (studs).
local V0_BOX_SIZE = Vector3.new(2, 2, 2)

-- Messages lus par le joueur (Notify), en anglais (L-036). V0 proposé, absent du doc.
local MESSAGES = {
	NoShop = "You don't have a shop yet: wait for one to free up.",
	-- Vague 31 (L-112), objets sous antivol, V0 proposés, absents du doc :
	ItemStowed = "Item secured! Put it down in your shop to start its anti-theft.",
	ItemsFull = "Your inventory is full: display or sell an item first.",
	ItemOutsideShop = "Put your item down inside your own shop.",
	ItemNotFloor = "Put your item on the floor of your shop.",
	ItemTooFar = "Get closer to put your item down.",
	ItemBlocked = "No room here: try another spot.",
	ItemTooMany = "Too many things on your floor: pick one up first.",
	ItemLocked = "Anti-theft still on: wait until it's UNLOCKED!",
	ItemHeld = "This item is being stolen: hit the thief to get it back!",
	-- %s = nom de l'objet (mutation devant)
	ItemUnlocked = "%s is UNLOCKED! Take your item!",
	-- Vague 44 (a152), V0 proposés, absents du doc : l'objet repris après l'antivol (jamais posé tout seul).
	ItemToHand = "%s is in your hand: put it on a display!",
	ItemToInventory = "%s is in your inventory.",
	ItemBackToInventory = "An item didn't fit in your shop: it's in your inventory.",
}
-- Catégorie des Notify d'information (objet gardé…) ; les refus partent en « Warning ».
local INFO_KIND = "Info"
-- Catégorie des réussites : texte vert dans UI_Toast (Config/UiMotion.Toast.Colors, L-095 point 3).
local SUCCESS_KIND = "Success"

local IS_STUDIO = RunService:IsStudio()
local REACH = PROMPT_DISTANCE + REACH_TOLERANCE

local UnboxService = {}

local sessions: { [Player]: Session } = {}
local itemStowedListeners: { ItemListener } = {}
local itemPlacedListeners: { ItemListener } = {}
local carryStarts: { [Player]: CarryStart } = {}
local safeBoxCache: { [Instance]: { cframe: CFrame, size: Vector3 } } = {}
local warned: { [string]: boolean } = {}
local random = Random.new()

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[UnboxService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[UnboxService] {message}`)
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function notify(player: Player, message: string, kind: string?)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind or "Warning")
	end)
	if not ok then
		warn(`[UnboxService] Notify vers {player.Name} : {err}`)
	end
end

-- Renvoie une fonction qui retire `listener` de `list` (même règle que DataService).
local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

local function refreshInventory(player: Player)
	local api = InventoryService
	if api == nil then
		return
	end
	local ok, err = pcall(api.Refresh :: any, player) -- :: any : sinon l'ancien solveur croit que pcall ne renvoie qu'une valeur
	if not ok then
		warn(`[UnboxService] InventoryService.Refresh ({player.Name}) : {err}`)
	end
end

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Point du sol d'un colis posé (Spot lisible), sinon nil.
local function spotOf(box: any): Vector3?
	local spot = if type(box) == "table" then box.Spot else nil
	if type(spot) ~= "table" or not (isFinite(spot.X) and isFinite(spot.Y) and isFinite(spot.Z)) then
		return nil
	end
	return Vector3.new(spot.X, spot.Y, spot.Z)
end

local function ownsPlot(player: Player, plot: Model): boolean
	return PlotService.GetPlot(player) == plot and plot:GetAttribute(OWNER_ATTRIBUTE) == player.UserId
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function inReach(player: Player, position: Vector3): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	return (root.Position - position).Magnitude <= REACH
end

-- État d'un présentoir selon DisplayService (voir DisplayApi), vide s'il ne répond pas.
local function slotStates(player: Player): { [number]: string }
	local ok, states = pcall(DisplayService.GetSlotStates, player)
	if ok and type(states) == "table" then
		return states
	end
	warn(`[UnboxService] DisplayService.GetSlotStates ({player.Name}) : {tostring(states)}`)
	return {}
end

-- Braquage réussi (en-tête) : Lifetime.Heists + 1. Sans yield. Un Lifetime illisible (profil
-- abîmé : Reconcile ne remplace pas une valeur du mauvais type) est signalé, pas réparé ici.
local function countHeist(player: Player, data: Data): number?
	local lifetime = (data :: any).Lifetime
	if type(lifetime) ~= "table" then
		warn(`[UnboxService] {player.Name} : Lifetime absent du profil, braquage non compté`)
		return nil
	end
	local heists = lifetime.Heists
	if type(heists) ~= "number" or heists ~= heists then
		warn(`[UnboxService] {player.Name} : Lifetime.Heists illisible ({tostring(heists)}), repart de 0`)
		heists = 0
	end
	lifetime.Heists = heists + 1
	return heists + 1
end

-- Uid neuf, absent de `list` (Items du profil).
local function newUid(list: { [string]: any }): string
	local uid = HttpService:GenerateGUID(false)
	while list[uid] ~= nil do
		uid = HttpService:GenerateGUID(false)
	end
	return uid
end

-- Vague 31 (L-112) : objet sous antivol (Types/Profile : AntiTheft, UnlockAt, Spot).
local function isAntiTheft(entry: any): boolean
	return type(entry) == "table" and entry.AntiTheft == true
end

-- Objets sous antivol posés au sol (comptés pour Unbox.MaxPlacedBoxes).
local function countFloorItems(data: Data): number
	local count = 0
	if type(data.Items) == "table" then
		for _, entry in data.Items do
			if isAntiTheft(entry) and (entry :: any).Spot ~= nil then
				count += 1
			end
		end
	end
	return count
end

-- Durée de l'antivol d'un objet (L-112 : ShelfOpen.AntiTheft[rareté du catalogue]).
local function antiTheftDuration(itemId: string): number
	local def = Items.ById[itemId]
	local seconds = if def then ShelfOpen.AntiTheft[def.Rarity] else nil
	if type(seconds) == "number" and seconds >= 0 then
		return seconds
	end
	warnOnce(`antitheft:{itemId}`, `antivol de {itemId} absent de Config/ShelfOpen.AntiTheft : {MAX_ANTI_THEFT} s (V0)`)
	return MAX_ANTI_THEFT
end

-- Durée de l'antivol de l'objet `itemId` pour ce joueur : UnboxService.GetAntiTheftDelay (remplaçable :
-- Fast Open, MonetizationService), sinon celle de sa rareté.
local function antiTheftDelay(player: Player, itemId: string): number
	local ok, value = pcall(UnboxService.GetAntiTheftDelay, player, itemId)
	if ok and type(value) == "number" and value >= 0 and value < math.huge then
		return value
	end
	local reason = if ok then "valeur invalide " .. tostring(value) else tostring(value)
	warn(`[UnboxService] GetAntiTheftDelay ({player.Name}) : {reason}, durée de la rareté utilisée`)
	return antiTheftDuration(itemId)
end

-- Nom affiché d'un objet du profil (mutation devant, « Big Gold Soda Can »).
local function itemNameOf(entry: any): string
	local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
	if def == nil then
		return "item"
	end
	return Mutations.ItemName(def.DisplayName, Mutations.Sanitize(entry.Mutation))
end

-- Revenu d'un objet du profil ($/s, mutation comprise, sans bonus), règle de DisplayService (7.1).
local function itemIncomeOf(entry: any): number
	local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
	if def == nil then
		return 0
	end
	return Formulas.RoundIncome( -- a493 : sans décimales, au moins 1 $/s (comme DisplayService)
		Formulas.ItemIncome(def.Id) * -- vague 76 : rareté, zone et rang de l'objet
			Mutations.IncomeMultiplier(entry.Mutation, entry.Weight) -- vague 62 : poids compris (mutation brute : repli de l'ancienne taille)
	)
end

local function emitItem(list: { ItemListener }, player: Player, itemUid: string, itemId: string)
	for _, listener in table.clone(list) do
		task.spawn(listener, player, itemUid, itemId)
	end
end

------------------------------------------------------------------------------
-- Zone safe
------------------------------------------------------------------------------

local function insideBox(cframe: CFrame, size: Vector3, position: Vector3): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

-- Seulement les objets de la map (pas ceux de _INBOX_CLEMENT), comme GuardService.
local function inMap(inst: Instance): boolean
	if not inst:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not inst:IsDescendantOf(inbox)
end

-- Volume d'un objet taggé SafeZone : la pièce elle-même, sinon son enfant direct Bounds, sinon la
-- boîte englobante du Model (même règle que GuardService et TutorialService).
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

------------------------------------------------------------------------------
-- Amélioration du colis (DEV-050, règle dans l'en-tête) et annonce
------------------------------------------------------------------------------

-- Probabilité (en %) que le colis `tier` de la zone `zone` donne `rarityId` (ShelfBoxes.OddsFor).
local function oddsOf(zone: number, tier: string, rarityId: string): number
	local odds = ShelfBoxes.OddsFor(zone, tier)
	local value = if odds then odds[rarityId] else nil
	return if type(value) == "number" then value else 0
end

-- Au moins un objet tirable de cette zone et de cette rareté (catalogue v2 : une liste par case).
local function hasItem(zone: number, rarityId: string): boolean
	local byZone = Items.ByZone[zone]
	local list: { Items.Item }? = if byZone then byZone[rarityId :: Rarities.RarityId] else nil
	if list == nil then
		return false
	end
	return #list > 0
end

-- Chance du joueur (UnboxService.GetLuck, remplaçable) ; 1 si l'accroche renvoie une valeur invalide.
local function luckOf(player: Player, box: Box): number
	local ok, value = pcall(UnboxService.GetLuck, player, table.clone(box))
	if ok and type(value) == "number" and value >= 0 and value < math.huge then
		return value
	end
	local reason = if ok then "valeur invalide " .. tostring(value) else tostring(value)
	warn(`[UnboxService] GetLuck ({player.Name}) : {reason}, chance 1 utilisée`)
	return 1
end

-- Raretés atteintes cran par cran (règle de l'en-tête). Rarities.List est rangée par Order (1 à 8) :
-- la rareté au-dessus de `r` est Rarities.List[r.Order + 1]. Jamais Secret ni Divine (SECRET_ORDER).
local SECRET_ORDER = Rarities.ById.Secret.Order
local function rollUpgrades(box: Box, luck: number, rng: Random): { string }
	local steps: { string } = {}
	local chance = Unbox.UpgradeChance * luck
	chance = if chance == chance then math.clamp(chance, 0, 1) else 0 -- NaN : aucun cran
	local current = Rarities.ById[box.Rarity]
	if chance <= 0 or current == nil then
		return steps -- règle coupée (UpgradeChance ou chance à 0), ou colis illisible
	end
	if oddsOf(box.Zone, box.Tier, box.Rarity) <= 0 then
		return steps -- contenu imposé (colis garanti du tuto) : jamais amélioré
	end
	for _ = 1, Unbox.UpgradeMax do
		local nextRarity = Rarities.List[current.Order + 1]
		if nextRarity == nil or nextRarity.Order >= SECRET_ORDER then
			break
		end
		if oddsOf(box.Zone, box.Tier, nextRarity.Id) <= 0 or not hasItem(box.Zone, nextRarity.Id) then
			break -- ce colis ne peut pas donner cette rareté dans sa zone (V0, à confirmer par Clément)
		end
		if rng:NextNumber() >= chance then
			break
		end
		table.insert(steps, nextRarity.Id)
		current = nextRarity
	end
	return steps
end

------------------------------------------------------------------------------
-- Sol de la boutique (objets sous antivol posés au sol)
------------------------------------------------------------------------------

-- Petit décor : ancré, sans collision ni contact, ignoré des rayons.
local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- Volume Bounds de la parcelle (10.4), ou nil.
local function boundsOf(plot: Model): BasePart?
	local found = Find.path(plot, BOUNDS)
	if found ~= nil and found:IsA("BasePart") then
		return found :: BasePart
	end
	return nil
end

-- Repère du sol : point `world` tourné comme la parcelle (face avant vers la rue, 10.1).
local function floorFrame(plot: Model, world: Vector3): CFrame
	return CFrame.new(world) * plot:GetPivot().Rotation
end

-- Point du monde d'un Spot (repère du pivot de la parcelle), et l'inverse, arrondi.
local function worldOf(plot: Model, spot: Vector3): Vector3
	return (plot:GetPivot():PointToWorldSpace(spot))
end

local function spotFrom(plot: Model, world: Vector3): Spot
	local p = plot:GetPivot():PointToObjectSpace(world)
	local function round(value: number): number
		return math.floor(value / SPOT_ROUND + 0.5) * SPOT_ROUND
	end
	return { X = round(p.X), Y = round(p.Y), Z = round(p.Z) }
end

-- Le point (monde) est-il dans l'emprise au sol de Bounds, à `margin` studs du bord au moins ?
local function insideFootprint(bounds: BasePart, world: Vector3, margin: number): boolean
	local p = bounds.CFrame:PointToObjectSpace(world)
	local half = bounds.Size / 2
	return math.abs(p.X) <= half.X - margin and math.abs(p.Z) <= half.Z - margin
end

-- Le point (monde) est-il à moins de StandClearance studs (à plat) d'un DisplaySlot_xx de la boutique ?
local function nearStand(session: Session, world: Vector3): boolean
	for _, slot in session.slots do
		local offset = slot.WorldPosition - world
		if Vector3.new(offset.X, 0, offset.Z).Magnitude < Unbox.StandClearance then
			return true
		end
	end
	return false
end

-- Colis ou objet posé au sol, revu au retour du joueur : nil s'il peut rester à sa place. L-141 (2026-11-14) :
-- la boutique passe de 64 à 48 studs de large et ses présentoirs bougent ; un point posé avec l'ancienne forme
-- peut être hors du volume Bounds, dans un mur (le colis doit tenir entier dans Bounds) ou sur un présentoir
-- (même écart StandClearance qu'à la pose) : il revient alors dans l'inventaire.
local function placedProblem(session: Session, bounds: BasePart?, world: Vector3): string?
	local footprint = Unbox.BoxFootprint
	if bounds and not insideFootprint(bounds, world, math.max(footprint.X, footprint.Z) / 2) then
		return "hors du volume Bounds de cette boutique"
	end
	if nearStand(session, world) then
		return "sur un présentoir"
	end
	return nil
end

------------------------------------------------------------------------------
-- Objets sous antivol posés au sol (vague 31, L-112)
------------------------------------------------------------------------------

local function clearShownItem(session: Session, itemUid: string)
	local shown = session.items[itemUid]
	if shown then
		session.items[itemUid] = nil
		local model = shown.model
		if model then
			model:Destroy()
		end
	end
end

-- Modèle de l'objet `entry` posé en `base` : DisplayService.BuildFloorItem (ITM_ de Clément ou bloc V0 de
-- DisplayService, halo, attributs), sinon un bloc V0 de la couleur de sa rareté. Petit décor : ancré, sans
-- collision ni rayon (le sol de la boutique reste visable autour). Pas encore rangé dans la parcelle.
local function buildFloorItemModel(player: Player, itemUid: string, entry: any, base: CFrame, unlockAt: number): Model
	local ok, built = pcall(DisplayService.BuildFloorItem, player.UserId, base, itemUid, entry)
	local model: Model
	if ok and typeof(built) == "Instance" and (built :: Instance):IsA("Model") then
		model = built :: Model
	else
		if not ok then
			warnOnce(`floorbuild:{itemUid}`, `DisplayService.BuildFloorItem ({player.Name}, {itemUid}) : {built}, bloc V0`)
		end
		local def = Items.ById[entry.Id]
		local rarity = if def then Rarities.ById[def.Rarity] else nil
		model = Instance.new("Model")
		local block = Instance.new("Part")
		block.Name = "Block"
		block.Size = V0_BOX_SIZE
		block.Color = if rarity then rarity.Color else Color3.new(1, 1, 1)
		block.Material = Enum.Material.SmoothPlastic
		block.CFrame = base * CFrame.new(0, V0_BOX_SIZE.Y / 2, 0)
		block.PivotOffset = CFrame.new(0, -V0_BOX_SIZE.Y / 2, 0)
		block.Parent = model
		model.PrimaryPart = block
		model:SetAttribute("ItemUid", itemUid)
		model:SetAttribute("ItemId", entry.Id)
		model:SetAttribute(RARITY_ATTRIBUTE, if def then def.Rarity else nil)
		model:SetAttribute(OWNER_ATTRIBUTE, player.UserId)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			prepare(descendant)
		end
	end
	model.Name = FLOOR_ITEM_NAME
	model:SetAttribute(UNLOCK_AT_ATTRIBUTE, unlockAt)
	CollectionService:AddTag(model, FLOOR_ITEM_TAG)
	return model
end

-- Affiche l'objet sous antivol `entry` (Spot et UnlockAt lisibles) à sa place.
local function showItem(player: Player, session: Session, itemUid: string, entry: any)
	local spot = spotOf(entry)
	local unlockAt = entry.UnlockAt
	if spot == nil or not isFinite(unlockAt) then
		return
	end
	clearShownItem(session, itemUid)
	local base = floorFrame(session.plot, worldOf(session.plot, spot))
	local model = buildFloorItemModel(player, itemUid, entry, base, unlockAt)
	session.items[itemUid] = {
		model = model,
		base = base,
		unlockAt = unlockAt,
		unlocked = unlockAt <= serverNow(),
		held = false,
	}
	model.Parent = session.plot
end

-- Antivol fini : le propriétaire est prévenu (une fois, s'il n'est pas en train de se faire voler l'objet) ;
-- objet repris du profil ou retiré par un autre chemin : son modèle part.
local function advanceItems(player: Player, session: Session, now: number)
	local data = DataService.Get(player)
	local items = if data and type(data.Items) == "table" then data.Items else nil
	for itemUid, shown in session.items do
		local entry = if items then items[itemUid] else nil
		if not shown.held and (not isAntiTheft(entry) or (entry :: any).Spot == nil) then
			clearShownItem(session, itemUid)
		elseif not shown.unlocked and now >= shown.unlockAt then
			shown.unlocked = true
			if not shown.held then
				notify(player, string.format(MESSAGES.ItemUnlocked, itemNameOf(entry)), SUCCESS_KIND)
				log(`{player.Name} : objet {itemUid} débloqué (antivol fini)`)
			end
		end
	end
end

-- Point du sol de SA boutique où poser un objet, sous le point visé `aim` (règle de l'en-tête) ; nil
-- et la clé du message de refus sinon. Sans yield.
local function findFloor(player: Player, session: Session, aim: Vector3): (Vector3?, string?)
	local plot = session.plot
	local bounds = boundsOf(plot)
	if bounds == nil then
		warnOnce(`bounds:{plot:GetFullName()}`, `{plot:GetFullName()} : pas de {BOUNDS} (contrat 10.4), aucun objet ne s'y pose`)
		return nil, "OutsideShop"
	end
	local footprint = Unbox.BoxFootprint
	local margin = Unbox.EdgeMargin + math.max(footprint.X, footprint.Z) / 2
	if not insideFootprint(bounds, aim, margin) then
		return nil, "OutsideShop"
	end
	-- Le bas de Bounds, à l'aplomb du point visé : le niveau du sol de la boutique.
	local p = bounds.CFrame:PointToObjectSpace(aim)
	local bottom = bounds.CFrame:PointToWorldSpace(Vector3.new(p.X, -bounds.Size.Y / 2, p.Z))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plot }
	local origin = bottom + Vector3.new(0, Unbox.FloorRayUp, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(Unbox.FloorRayUp + Unbox.FloorTolerance), 0), params)
	if result == nil or result.Normal.Y < Unbox.FloorMinNormalY or math.abs(result.Position.Y - bottom.Y) > Unbox.FloorTolerance then
		return nil, "NotFloor"
	end
	local point = result.Position
	if not inReach(player, point) then
		return nil, "TooFar"
	end
	if nearStand(session, point) then
		return nil, "Blocked"
	end
	for _, shown in session.items do
		if (shown.base.Position - point).Magnitude < Unbox.BoxSpacing then
			return nil, "Blocked"
		end
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { plot }
	overlap.RespectCanCollide = true
	local center = floorFrame(plot, point) * CFrame.new(0, FOOTPRINT_LIFT + footprint.Y / 2, 0)
	if #Workspace:GetPartBoundsInBox(center, footprint, overlap) > 0 then
		return nil, "Blocked"
	end
	return point, nil
end

-- Fait avancer les antivols : « UNLOCKED! » au propriétaire quand l'attente est écoulée.
local function advanceTimers()
	local now = serverNow()
	for player, session in sessions do
		if next(session.items) ~= nil then
			advanceItems(player, session, now)
		end
	end
end

------------------------------------------------------------------------------
-- Présentoirs (attribut UnboxState, pour la pose d'un objet de l'inventaire)
------------------------------------------------------------------------------

local function setState(session: Session, index: number, state: StandState?)
	if session.states[index] == state then
		return
	end
	session.states[index] = state
	local slot: Attachment? = session.slots[index]
	if slot then
		slot:SetAttribute(STATE_ATTRIBUTE, state)
	end
end

local function refreshStates(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	local states = slotStates(player)
	for index in session.slots do
		local state = states[index]
		setState(session, index, if state == "Free" or state == "Locked" or state == "Taken" then state :: StandState else nil)
	end
end

------------------------------------------------------------------------------
-- Rangement dans l'inventaire (entrée de la zone safe)
------------------------------------------------------------------------------

-- Anti-triche (DEV-060), juste avant la réussite d'un portage PNJ : AntiCheatService.Verify avec le point
-- et l'heure du début de ce portage. false : sanctionné, le portage vient d'échouer (rien n'est rangé).
local function verifyCarry(player: Player, payload: any): boolean
	local start = carryStarts[player]
	local from: Vector3?, since: number? = nil, nil
	if start and start.Payload == payload then
		from, since = start.From, start.At
	end
	return AntiCheatService.Verify(player, from, since)
end

-- Raison du refus si l'objet porté `payload` (Kind NPCItem) est mal formé, sinon nil.
local function checkItemPayload(payload: any): string?
	if type(payload.ItemId) ~= "string" or Items.ById[payload.ItemId] == nil then
		return `ItemId inconnu ({tostring(payload.ItemId)})`
	end
	if type(payload.Rarity) ~= "string" or Rarities.ById[payload.Rarity] == nil then
		return `Rarity inconnue ({tostring(payload.Rarity)})`
	end
	if type(payload.Zone) ~= "number" or Zones[payload.Zone] == nil then
		return `Zone inconnue ({tostring(payload.Zone)})`
	end
	return nil
end

-- Index des objets (IndexService.Discover), chargé à l'appel : IndexService requiert ce service.
local function discover(player: Player, itemId: string)
	local module = script.Parent:FindFirstChild("IndexService")
	if module == nil or not module:IsA("ModuleScript") then
		return
	end
	local loaded, api = pcall(require, module)
	local discoverFn: any = if loaded and type(api) == "table" then (api :: any).Discover else nil
	if type(discoverFn) ~= "function" then
		return
	end
	local ok, err = pcall(discoverFn, player, itemId)
	if not ok then
		warnOnce("discover", `IndexService.Discover : {err}`)
	end
end

-- Vague 31 (L-112) : l'objet sorti d'un colis ouvert sur le rayon (payload NPCItem,
-- StoreHeistService et CarryService, a103) entre dans l'inventaire à l'entrée de la zone safe, au même
-- endroit et avec les mêmes contrôles que le colis (anti-triche, Consume, profil écrit d'un seul tenant,
-- braquage compté). Il y est sous antivol (AntiTheft = true, sans UnlockAt : l'attente démarre à la pose au
-- sol). Inventaire plein (DisplayService.HasInventoryRoom) : le portage échoue (« InventoryFull »).
local function stowItem(player: Player, data: Data, payload: any)
	local problem = checkItemPayload(payload)
	if problem then
		warn(`[UnboxService] {player.Name} : objet porté mal formé ({problem}), portage rendu`)
		CarryService.Fail(player, "Invalid")
		return
	end
	if type(data.Items) ~= "table" then
		warnOnce(`items:{player.UserId}`, `{player.Name} : Items illisible dans le profil, objet gardé sur la tête`)
		return
	end
	local roomOk, room = pcall(DisplayService.HasInventoryRoom, player)
	if not (roomOk and room == true) then
		log(`{player.Name} : inventaire plein, l'objet porté n'est pas rangé`)
		notify(player, MESSAGES.ItemsFull)
		CarryService.Fail(player, "InventoryFull")
		return
	end
	local def = Items.ById[payload.ItemId]
	if def.Rarity ~= payload.Rarity then
		warn(`[UnboxService] {player.Name} : objet {payload.ItemId} ({def.Rarity}) porté comme {payload.Rarity} : la rareté du catalogue fait foi`)
	end
	if not verifyCarry(player, payload) then
		log(`{player.Name} : objet pas rangé, déplacement sanctionné par l'anti-triche (portage rendu)`)
		return
	end
	if CarryService.Consume(player) == nil then
		log(`{player.Name} : objet pas rangé, CarryService.Consume n'a rien rendu`)
		return
	end
	if DataService.Get(player) ~= data then
		warn(`[UnboxService] {player.Name} : profil perdu pendant le rangement, objet perdu`)
		return
	end
	local itemUid = newUid(data.Items)
	data.Items[itemUid] = {
		Id = def.Id,
		Source = "NPC",
		At = os.time(),
		Zone = payload.Zone,
		Mutation = if def.TutorialOnly then nil else Mutations.Sanitize(payload.Mutation),
		Weight = if def.TutorialOnly then nil else ItemWeight.Sanitize(payload.Weight), -- vague 62 (a203) : le poids suit l'objet
		AntiTheft = true,
	}
	local heists = countHeist(player, data) -- d'un seul tenant avec l'objet : sauvegardés ensemble
	log(`{player.Name} : objet {def.Id} ({def.Rarity}) rangé sous antivol ({itemUid} ; braquages réussis : {heists or "?"})`)
	notify(player, MESSAGES.ItemStowed, SUCCESS_KIND)
	-- Arrivée en zone safe (UI_Escape, L-095 point 4) ; vague 46 : remote ItemSecured, icône et nom de l'objet.
	local secured, securedErr = pcall(function()
		Net.Server.ItemSecured:Fire(player, def.Id)
	end)
	if not secured then
		warn(`[UnboxService] ItemSecured vers {player.Name} : {securedErr}`)
	end
	discover(player, def.Id)
	refreshInventory(player)
	emitItem(itemStowedListeners, player, itemUid, def.Id)
end

local function stow(player: Player)
	local data = DataService.Get(player)
	if data == nil or not CarryService.IsCarrying(player) then
		return
	end
	local payload = CarryService.GetPayload(player)
	-- Vague 50 (a158) : seul un objet sorti d'un colis (NPCItem) se range ; le colis porté fermé n'existe plus.
	if type(payload) == "table" and payload.Kind == NPC_ITEM_KIND then
		stowItem(player, data, payload)
	end
end

-- Porteurs entrés dans la zone safe : leur objet (NPCItem) va dans l'inventaire, sous antivol.
local function stowArrivals()
	for _, player in Players:GetPlayers() do
		if CarryService.IsCarrying(player) then
			local root = rootOf(player)
			if root and isInSafeZone(root.Position) then
				local ok, err = pcall(stow :: any, player) -- :: any : idem
				if not ok then
					warn(`[UnboxService] rangement de l'objet de {player.Name} : {err}`)
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Arrivée et départ du joueur
------------------------------------------------------------------------------

local function teardown(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	for itemUid in session.items do
		clearShownItem(session, itemUid)
	end
	for index, slot in session.slots do
		session.states[index] = nil
		slot:SetAttribute(STATE_ATTRIBUTE, nil)
	end
end

-- Vague 31 : remet à leur place les objets sous antivol posés au sol. Un objet dont le point n'est plus lisible
-- ou plus dans le volume Bounds de cette boutique revient dans l'inventaire, toujours sous antivol (UnlockAt
-- gardé : à la pose suivante, l'attente déjà commencée n'est pas perdue). Jamais perdu.
local function restoreItems(player: Player, session: Session, data: Data)
	if type(data.Items) ~= "table" then
		return
	end
	local bounds = boundsOf(session.plot)
	local restored, returned = 0, 0
	for itemUid, entry in data.Items do
		if not isAntiTheft(entry) or (entry :: any).Spot == nil then
			continue
		end
		local item = entry :: any
		local spot = spotOf(item)
		local problem: string? = nil
		if spot == nil then
			problem = `Spot invalide ({tostring(item.Spot)})`
		elseif not isFinite(item.UnlockAt) then
			problem = `UnlockAt invalide ({tostring(item.UnlockAt)})`
		else
			problem = placedProblem(session, bounds, worldOf(session.plot, spot))
		end
		if problem then
			item.Spot = nil
			if not isFinite(item.UnlockAt) then
				item.UnlockAt = nil
			end
			returned += 1
			warn(`[UnboxService] {player.Name} : objet posé {itemUid} ({problem}) : revient dans l'inventaire, sous antivol`)
		else
			showItem(player, session, itemUid, item)
			restored += 1
		end
	end
	if returned > 0 then
		notify(player, MESSAGES.ItemBackToInventory, INFO_KIND)
		refreshInventory(player)
	end
	if restored + returned > 0 then
		log(`{player.Name} : {restored} objet(s) sous antivol remis au sol, {returned} revenu(s) dans l'inventaire`)
	end
end

-- Profil chargé et parcelle attribuée : remet les objets sous antivol posés à leur place. Sans yield,
-- appelable plusieurs fois (profil chargé, parcelle attribuée). Vague 50 (a158) : plus aucun colis posé
-- (DataService.convertBoxes a déjà fait de chaque colis du profil un objet de l'inventaire).
local function setup(player: Player)
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if data == nil or plot == nil or player.Parent ~= Players then
		return
	end
	local existing = sessions[player]
	if existing then
		if existing.plot == plot then
			return
		end
		teardown(player)
	end
	local ok, slots = pcall(DisplayService.GetSlots, player)
	if not ok or type(slots) ~= "table" then
		warn(`[UnboxService] DisplayService.GetSlots ({player.Name}) : {tostring(slots)}, aucun présentoir`)
		slots = {}
	end
	local session: Session = { plot = plot, slots = slots, items = {}, states = {} }
	sessions[player] = session
	restoreItems(player, session, data)
	refreshStates(player)
end

------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------

-- Vague 31 (L-112) : PlaceBox(itemUid, point) d'un objet sous antivol de l'inventaire (sa boutique, mains
-- vides, findFloor, Unbox.MaxPlacedBoxes objets au sol au plus) ;
-- refus : un Notify. Accepté : Spot, et l'antivol démarre (UnlockAt = maintenant + ShelfOpen.AntiTheft[rareté],
-- ou l'heure déjà promise si elle est plus tôt : objet revenu dans l'inventaire après une première pose).
local function placeFloorItem(player: Player, data: Data, session: Session, itemUid: string, entry: any, point: Vector3)
	local what = `PlaceBox({itemUid}) (objet sous antivol)`
	if entry.Spot ~= nil then
		log(`{player.Name} : {what} refusé : déjà posé`)
		return
	end
	if Items.ById[entry.Id] == nil then
		warn(`[UnboxService] {player.Name} : objet {itemUid} inconnu du catalogue ({tostring(entry.Id)}), {what} refusé`)
		return
	end
	if CarryService.IsCarrying(player) then
		log(`{player.Name} : {what} refusé : porte déjà quelque chose`)
		return
	end
	local placed = countFloorItems(data)
	if placed >= Unbox.MaxPlacedBoxes then
		log(`{player.Name} : {what} refusé : {placed} objets déjà au sol`)
		notify(player, MESSAGES.ItemTooMany)
		return
	end
	local floor, why = findFloor(player, session, point)
	if floor == nil then
		local key = "Item" .. (why or "NotFloor")
		log(`{player.Name} : {what} refusé : {why or "NotFloor"}`)
		notify(player, (MESSAGES :: any)[key] or MESSAGES.ItemNotFloor)
		return
	end
	-- D'un seul tenant, sans yield : l'objet quitte l'inventaire en se posant, l'antivol démarre.
	local now = serverNow()
	local unlockAt = now + antiTheftDelay(player, entry.Id)
	local promised = entry.UnlockAt
	if isFinite(promised) and (promised :: number) < unlockAt then
		unlockAt = promised :: number
	end
	entry.UnlockAt = unlockAt
	entry.Spot = spotFrom(session.plot, floor)
	showItem(player, session, itemUid, entry)
	refreshInventory(player)
	log(`{player.Name} : objet {entry.Id} posé au sol ({itemUid}), antivol {string.format("%.1f", math.max(0, unlockAt - now))} s`)
	emitItem(itemPlacedListeners, player, itemUid, entry.Id)
end

-- Vague 31 (L-112) : OpenBox(itemUid) sur un objet posé au sol, antivol fini (« UNLOCKED! ») : le propriétaire
-- le reprend ; il n'est plus sous antivol et va en main s'il a les mains libres (vague 44, a152 : HeldItemService.Give),
-- sinon dans l'inventaire (barre du bas) ; jamais posé tout seul. Même portée que l'ouverture d'un colis.
local function takeFloorItem(player: Player, session: Session, itemUid: string, entry: any)
	local shown = session.items[itemUid]
	local what = `OpenBox({itemUid}) (objet sous antivol)`
	if entry.Spot == nil or shown == nil then
		log(`{player.Name} : {what} refusé : pas posé au sol`)
		return
	end
	if shown.held then
		notify(player, MESSAGES.ItemHeld)
		return
	end
	local where = shown.base.Position
	if not inReach(player, where) then
		log(`{player.Name} : {what} refusé : trop loin (plus de {REACH} studs)`)
		return
	end
	local unlockAt = entry.UnlockAt
	if not isFinite(unlockAt) or serverNow() < unlockAt then
		notify(player, MESSAGES.ItemLocked)
		return
	end
	-- D'un seul tenant : l'objet redevient un objet libre de l'inventaire, puis va en main (vague 44, a152).
	entry.AntiTheft = nil
	entry.UnlockAt = nil
	entry.Spot = nil
	clearShownItem(session, itemUid)
	local name = itemNameOf(entry)
	refreshInventory(player)
	local module = script.Parent:FindFirstChild("HeldItemService") -- require protégé : bancs sans lui
	local ok, inHand = pcall(function()
		return module ~= nil and (require(module :: ModuleScript) :: any).Give(player, itemUid) == true
	end)
	if not ok then
		warn(`[UnboxService] HeldItemService.Give ({player.Name}, {itemUid}) : {inHand}`)
	end
	local dest = if ok and inHand then "en main" else "dans l'inventaire (mains prises)"
	notify(player, string.format(if ok and inHand then MESSAGES.ItemToHand else MESSAGES.ItemToInventory, name), SUCCESS_KIND)
	log(`{player.Name} : objet {itemUid} repris du sol, {dest}`)
	refreshStates(player)
end

local function onPlaceBox(player: Player, boxUid: string, point: Vector3)
	local data = DataService.Get(player)
	local session = sessions[player]
	if data == nil then
		return
	end
	if session == nil or not ownsPlot(player, session.plot) then
		log(`{player.Name} : PlaceBox({boxUid}) refusé : pas de boutique`)
		notify(player, MESSAGES.NoShop)
		return
	end
	-- Vague 50 (a158) : le remote ne pose plus que des objets sous antivol (un uid de Boxes est refusé).
	local entry = if type(data.Items) == "table" then data.Items[boxUid] else nil
	if isAntiTheft(entry) then
		placeFloorItem(player, data, session, boxUid, entry, point)
		return
	end
	log(`{player.Name} : PlaceBox({boxUid}) refusé : aucun objet sous antivol de ce nom`)
end

local function onOpenBox(player: Player, boxUid: string)
	local data = DataService.Get(player)
	local session = sessions[player]
	if data == nil or session == nil or not ownsPlot(player, session.plot) then
		log(`{player.Name} : OpenBox({boxUid}) refusé : profil ou parcelle pas encore prêts`)
		return
	end
	-- Vague 50 (a158) : plus d'ouverture en base ; le remote ne reprend plus que des objets sous antivol.
	local entry = if type(data.Items) == "table" then data.Items[boxUid] else nil
	if isAntiTheft(entry) then
		takeFloorItem(player, session, boxUid, entry)
		return
	end
	log(`{player.Name} : OpenBox({boxUid}) refusé : aucun objet sous antivol posé de ce nom`)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

-- Vague 31 (L-112) : durée de l'antivol d'un objet posé au sol (ShelfOpen.AntiTheft[rareté]) ; remplaçable
-- par MonetizationService (Fast Open × DelayFactor). Ne doit pas yield.
function UnboxService.GetAntiTheftDelay(_player: Player, itemId: string): number
	return antiTheftDuration(itemId)
end

function UnboxService.GetLuck(_player: Player, _box: Box): number
	return 1
end

function UnboxService.RollUpgrades(box: Box, luck: number, rng: Random?): { string }
	return rollUpgrades(box, luck, rng or random)
end

function UnboxService.Refresh(player: Player)
	refreshStates(player)
end


-- Vague 31 (L-112) : objets sous antivol ------------------------------------------------------------------

function UnboxService.OnItemStowed(listener: ItemListener): () -> ()
	return subscribe(itemStowedListeners, listener)
end

function UnboxService.OnItemPlaced(listener: ItemListener): () -> ()
	return subscribe(itemPlacedListeners, listener)
end

-- Objet sous antivol posé au sol de `owner`, affiché et pas porté par un voleur : sa fiche, nil sinon.
local function floorItemOf(owner: Player, itemUid: string): FloorItem?
	local session = sessions[owner]
	local shown = if session then session.items[itemUid] else nil
	local data = DataService.Get(owner)
	local entry = if data and type(data.Items) == "table" then data.Items[itemUid] else nil
	if shown == nil or shown.held or not isAntiTheft(entry) or (entry :: any).Spot == nil then
		return nil
	end
	local def = Items.ById[(entry :: any).Id]
	if def == nil then
		return nil
	end
	return {
		Uid = itemUid,
		ItemId = def.Id,
		Rarity = def.Rarity :: string,
		Income = itemIncomeOf(entry),
		Position = shown.base.Position,
		UnlockAt = shown.unlockAt,
	}
end

function UnboxService.GetFloorItem(owner: Player, itemUid: string): FloorItem?
	return floorItemOf(owner, itemUid)
end

function UnboxService.GetFloorItems(owner: Player): { [string]: FloorItem }
	local list: { [string]: FloorItem } = {}
	local session = sessions[owner]
	if session == nil then
		return list
	end
	for itemUid in session.items do
		local item = floorItemOf(owner, itemUid)
		if item then
			list[itemUid] = item
		end
	end
	return list
end

-- L'antivol de cet objet court-il encore (volable) ? Objet absent, porté ou débloqué : false.
function UnboxService.IsStealable(owner: Player, itemUid: string): boolean
	local item = UnboxService.GetFloorItem(owner, itemUid)
	return item ~= nil and serverNow() < item.UnlockAt
end

function UnboxService.HoldFloorItem(owner: Player, itemUid: string): boolean
	if not UnboxService.IsStealable(owner, itemUid) then
		return false
	end
	local session = sessions[owner] :: Session
	local shown = session.items[itemUid]
	shown.held = true
	local model = shown.model
	if model then
		model.Parent = nil
	end
	log(`{owner.Name} : objet {itemUid} pris au sol par un voleur`)
	return true
end

function UnboxService.ReleaseFloorItem(owner: Player, itemUid: string): boolean
	local session = sessions[owner]
	local shown = if session then session.items[itemUid] else nil
	if session == nil or shown == nil or not shown.held then
		return false
	end
	shown.held = false
	local model = shown.model
	if model then
		model.Parent = session.plot
	end
	log(`{owner.Name} : objet {itemUid} revenu à sa place au sol`)
	return true
end

function UnboxService.TakeFloorItem(owner: Player, itemUid: string): boolean
	local session = sessions[owner]
	local shown = if session then session.items[itemUid] else nil
	if session == nil or shown == nil or not shown.held then
		return false
	end
	clearShownItem(session, itemUid)
	return true
end

function UnboxService.IsFloorHeld(owner: Player, itemUid: string): boolean
	local session = sessions[owner]
	local shown = if session then session.items[itemUid] else nil
	return shown ~= nil and shown.held
end

-- Rareté d'un objet offert (GiveItem) : tirée avec les poids de OddsFor(zone, tier), seulement parmi les
-- raretés d'ordre ≥ minOrder qui ont un objet (Items.Pick : Secrets et Divins, toutes zones). nil si aucune.
local function drawGiftRarity(zone: number, tier: string, minOrder: number): string?
	local total = 0
	local weights: { [string]: number } = {}
	for _, rarity in Rarities.List do
		local weight = oddsOf(zone, tier, rarity.Id)
		local allZones = Items.AllZones[rarity.Id]
		-- Vague 76 : un Secret seulement dans les zones qui l'ont (Items.Pick ; zone 6).
		local possible = if allZones ~= nil
			then #allZones > 0 and (Rarities.FirstZone[rarity.Id] == nil or Rarities.Allows(zone, rarity.Id))
			else hasItem(zone, rarity.Id)
		if rarity.Order >= minOrder and weight > 0 and possible then
			weights[rarity.Id] = weight
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber() * total
	local last: string? = nil
	for _, rarity in Rarities.List do
		local weight = weights[rarity.Id]
		if weight then
			last = rarity.Id
			if roll < weight then
				return rarity.Id
			end
			roll -= weight
		end
	end
	return last -- arrondi des nombres à virgule : la dernière rareté possible
end

-- Le type, la zone et la rareté minimale d'un don sont-ils connus ? (avertissement sinon)
local function validGift(player: Player, what: string, tier: string, zone: number, minRarity: string?): boolean
	local minimum = if minRarity ~= nil then Rarities.ById[minRarity] else nil
	if Balance.Heist.BoxTiers[tier] == nil or Zones[zone] == nil or (minRarity ~= nil and minimum == nil) then
		warn(`[UnboxService] {what} ({player.Name}) : colis {tostring(tier)} zone {tostring(zone)} rareté {tostring(minRarity)} inconnu`)
		return false
	end
	return true
end

-- Contenu d'un colis offert (GiveItem, qui donne l'objet tout de suite) : rareté (drawGiftRarity),
-- objet de cette rareté dans la zone (Items.Pick), mutation tirée comme à la mise en rayon (DEV-131).
-- nil (avertissement une fois) si aucune rareté n'est possible.
local function drawGift(tier: string, zone: number, minRarity: string?): (string?, Items.Item?, Mutations.Mutation?)
	local minimum = if minRarity ~= nil then Rarities.ById[minRarity] else nil
	local rarityId = drawGiftRarity(zone, tier, if minimum then minimum.Order else 0)
	local item = if rarityId then Items.Pick(zone, rarityId :: Rarities.RarityId, random) else nil
	if rarityId == nil or item == nil then
		warnOnce(`gift.{tier}.{zone}.{tostring(minRarity)}`, `colis offert {tier} zone {zone} (au moins {tostring(minRarity)}) : aucune rareté possible (Config)`)
		return nil, nil, nil
	end
	return rarityId, item, if item.TutorialOnly then nil else Mutations.Roll(random)
end

-- Vague 43 (Cantin, 2026-11-14 : « qu'on récupère des items à la place des box ») : le contenu d'un colis
-- offert (drawGift) entre tout de suite dans l'inventaire comme un objet. Vague 50 (a158) : GiveBox (colis
-- rangé dans Boxes) est retiré.
function UnboxService.GiveItem(player: Player, tier: string, zone: number, minRarity: string?): (string?, string?, string?)
	local data = DataService.Get(player)
	if data == nil or type(data.Items) ~= "table" then
		return nil, "NoProfile", nil
	end
	if not validGift(player, "GiveItem", tier, zone, minRarity) then
		return nil, "Invalid", nil
	end
	-- Vague 76 (V0 proposé, a262) : chaque zone n'a que certaines raretés (ShelfBoxes.ZoneOdds) ; une rareté minimale
	-- absente de la zone (Épique en zone 2) fait passer le don à la première zone où elle existe (zone 4).
	local firstZone = if minRarity then ShelfBoxes.FirstZone[minRarity] else nil
	if firstZone and firstZone > zone then
		zone = firstZone
	end
	local roomOk, room = pcall(DisplayService.HasInventoryRoom, player)
	if not (roomOk and room == true) then
		log(`{player.Name} : inventaire plein, objet offert ({tier}) pas donné`)
		return nil, "InventoryFull", nil
	end
	local rarityId, item, mutation = drawGift(tier, zone, minRarity)
	if rarityId == nil or item == nil then
		return nil, "NoContent", nil
	end
	-- Amélioration du colis, comme à l'ancienne ouverture en base : rollUpgrades avec la chance du joueur
	-- (UpgradeChance 10 % par cran, UpgradeMax 2), puis un objet de la rareté atteinte. Elle ne fait que monter :
	-- MinRarity reste garanti (J7 Épique ou mieux, 3.3).
	local box: Box = { Tier = tier :: any, Zone = zone, ItemId = item.Id, Rarity = rarityId, ReadyAt = nil, Mutation = mutation, Spot = nil, At = os.time() }
	local steps = rollUpgrades(box, luckOf(player, box), random)
	if #steps > 0 then
		local target = steps[#steps]
		local picked = Items.Pick(zone, target :: Rarities.RarityId, random)
		if picked ~= nil and picked.Rarity == target then
			item, rarityId = picked, target
		else
			table.clear(steps)
		end
	end
	local itemUid = newUid(data.Items)
	-- Zone gardée pour le revenu du Secret, qui n'a pas de zone au catalogue (DisplayService la lit).
	data.Items[itemUid] = { Id = item.Id, Source = "NPC", At = os.time(), Zone = zone, Mutation = mutation }
	local mutated = Mutations.Label(mutation)
	local upgraded = if #steps > 0 then `, {#steps} cran(s) : {table.concat(steps, " → ")}` else ""
	log(`{player.Name} : objet offert {item.Id} ({rarityId}, colis {tier} zone {zone}{upgraded}{if mutated then ", mutation " .. mutated else ""}) mis dans l'inventaire ({itemUid})`)
	discover(player, item.Id)
	refreshInventory(player)
	return itemUid, nil, item.Id
end

-- Vague 80 (a267) : objet d'un colis de rayon de rareté `boxRarity`, donné tout de suite (voir l'en-tête).
function UnboxService.GiveBoxRarityItem(player: Player, boxRarity: string, zone: number): (string?, string?, string?)
	local data = DataService.Get(player)
	if data == nil or type(data.Items) ~= "table" then
		return nil, "NoProfile", nil
	end
	local firstZone = ShelfBoxes.FirstZone[boxRarity]
	if Rarities.ById[boxRarity] == nil or firstZone == nil or Zones[zone] == nil then
		warn(`[UnboxService] GiveBoxRarityItem ({player.Name}) : colis {tostring(boxRarity)} zone {tostring(zone)} inconnu`)
		return nil, "Invalid", nil
	end
	zone = math.max(zone, firstZone)
	local roomOk, room = pcall(DisplayService.HasInventoryRoom, player)
	if not (roomOk and room == true) then
		log(`{player.Name} : inventaire plein, objet offert (colis {boxRarity}) pas donné`)
		return nil, "InventoryFull", nil
	end
	-- Vague 81 (a268) : plancher à la rareté du colis (« un colis Épique » = Épique ou mieux) : les poids du colis
	-- au-dessus du plancher seulement ; sous le plancher, rien.
	local floorOrder = (Rarities.ById[boxRarity] :: Rarities.Rarity).Order
	local weights = ShelfBoxes.ContentWeights(boxRarity, 1, zone)
	local total = 0
	if weights then
		for _, rarity in Rarities.List do
			if rarity.Order < floorOrder then
				weights[rarity.Id] = nil
			end
		end
		for _, weight in weights do
			total += weight
		end
	end
	local rarityId = boxRarity
	if weights and total > 0 then
		local roll = random:NextNumber() * total
		for _, rarity in Rarities.List do
			local weight = weights[rarity.Id]
			if weight and weight > 0 then
				rarityId = rarity.Id
				if roll < weight then
					break
				end
				roll -= weight
			end
		end
	end
	local item = Items.Pick(zone, rarityId :: Rarities.RarityId, random)
	if item == nil then
		rarityId = boxRarity -- rareté tirée sans objet dans la zone : celle du colis, qui y existe
		item = Items.Pick(zone, rarityId :: Rarities.RarityId, random)
	end
	if item == nil then
		warnOnce(`giftRarity.{boxRarity}.{zone}`, `colis offert {boxRarity} zone {zone} : aucun objet possible (Config)`)
		return nil, "NoContent", nil
	end
	local mutation = if item.TutorialOnly then nil else Mutations.Roll(random)
	local itemUid = newUid(data.Items)
	data.Items[itemUid] = { Id = item.Id, Source = "NPC", At = os.time(), Zone = zone, Mutation = mutation }
	local mutated = Mutations.Label(mutation)
	log(`{player.Name} : objet offert {item.Id} ({rarityId}, colis {boxRarity} zone {zone}{if mutated then ", mutation " .. mutated else ""}) mis dans l'inventaire ({itemUid})`)
	discover(player, item.Id)
	refreshInventory(player)
	return itemUid, nil, item.Id
end

-- a309 (Cantin, 22/11) : ce que l'ouverture du colis de zone offert doit montrer (MonetizationService.StartGiftReveal).
export type ZoneBoxGift = {
	Zone: number,
	Rarity: string, -- rareté tirée (celle de l'objet)
	Chance: number, -- sa chance dans ce colis, en pour cent
	StartRarity: string, -- la plus basse rareté possible de ce colis (montrée sur le colis au début de l'ouverture)
	Effect: string?, -- effet de la mutation de l'objet (Mutations), montré pendant l'ouverture
}

-- a309 : objet d'un colis de zone offert (paliers de temps de jeu, voir l'en-tête), donné tout de suite.
function UnboxService.GiveZoneBoxItem(player: Player, rule: ZoneBoxOdds.Rule, bestZone: number): (string?, string?, string?, ZoneBoxGift?)
	local data = DataService.Get(player)
	if data == nil or type(data.Items) ~= "table" then
		return nil, "NoProfile", nil, nil
	end
	-- Tout est lu maintenant (Config/Zones, Rarities.ZoneOdds et ZoneRarities), jamais recopié (Shared/ZoneBoxOdds).
	local zone = if type(rule) == "table" then ZoneBoxOdds.Zone(rule, bestZone) else nil
	if zone == nil then
		warn(`[UnboxService] GiveZoneBoxItem ({player.Name}) : règle ou zone {tostring(bestZone)} inconnue`)
		return nil, "Invalid", nil, nil
	end
	local roomOk, room = pcall(DisplayService.HasInventoryRoom, player)
	if not (roomOk and room == true) then
		log(`{player.Name} : inventaire plein, colis de zone offert (zone {zone}) pas donné`)
		return nil, "InventoryFull", nil, nil
	end
	local chances = ZoneBoxOdds.Chances(rule, zone)
	local drawn = ZoneBoxOdds.Draw(chances, random:NextNumber())
	local item = if drawn then Items.Pick(zone, drawn.Id :: Rarities.RarityId, random) else nil
	if drawn == nil or item == nil then
		warnOnce(`zoneBox.{zone}.{if drawn then drawn.Id else "none"}`, `colis de zone offert, zone {zone} : aucun objet possible (Config)`)
		return nil, "NoContent", nil, nil
	end
	local mutation = if item.TutorialOnly then nil else Mutations.Roll(random)
	local itemUid = newUid(data.Items)
	-- Zone gardée pour le revenu du Secret, qui n'a pas de zone au catalogue (DisplayService la lit).
	data.Items[itemUid] = { Id = item.Id, Source = "NPC", At = os.time(), Zone = zone, Mutation = mutation }
	local mutated = Mutations.Label(mutation)
	log(`{player.Name} : colis de zone offert, zone {zone} : {item.Id} ({drawn.Id}, {string.format("%.3f", drawn.Chance)} %{if mutated then ", mutation " .. mutated else ""}) mis dans l'inventaire ({itemUid})`)
	discover(player, item.Id)
	refreshInventory(player)
	return itemUid, nil, item.Id, { Zone = zone, Rarity = drawn.Id, Chance = drawn.Chance, StartRarity = chances[1].Id, Effect = if mutation then mutation.Effect else nil }
end

function UnboxService.GetWaiting(player: Player): { [string]: number }
	local waiting: { [string]: number } = {}
	local session = sessions[player]
	if session == nil then
		return waiting
	end
	local now = serverNow()
	-- Vague 31 (Cantin, 2026-11-12) : un objet sous antivol au sol (pas porté par un voleur) attend.
	-- Vague 50 (a158) : plus de colis posé en attente.
	for itemUid, item in session.items do
		if not item.held and not item.unlocked and item.unlockAt > now then
			waiting[itemUid] = item.unlockAt
		end
	end
	return waiting
end

-- Vague 31 : SkipWait sur un objet sous antivol posé au sol.
local function skipAntiTheft(player: Player, data: Data, session: Session, itemUid: string, seconds: number): number?
	local item = session.items[itemUid]
	local entry: any = if type(data.Items) == "table" then data.Items[itemUid] else nil
	if item == nil or item.held or item.unlocked or not isAntiTheft(entry) or not isFinite(entry.UnlockAt) then
		return nil
	end
	local now = serverNow()
	local current = entry.UnlockAt :: number
	if current <= now then
		return nil -- déjà fini : la boucle le marque au prochain pas
	end
	local unlockAt = math.max(now, current - seconds)
	entry.UnlockAt = unlockAt
	item.unlockAt = unlockAt
	local model = item.model
	if model then
		model:SetAttribute(UNLOCK_AT_ATTRIBUTE, unlockAt)
	end
	local left = unlockAt - now
	if left <= 0 then
		left = 0
		advanceItems(player, session, now) -- « UNLOCKED! » tout de suite (Notify au propriétaire)
	end
	log(`{player.Name} : antivol de l'objet {itemUid} réduit de {string.format("%.1f", seconds)} s, reste {string.format("%.1f", left)} s`)
	return left
end

function UnboxService.SkipWait(player: Player, boxUid: string, seconds: number): number?
	local data = DataService.Get(player)
	local session = sessions[player]
	if data == nil or session == nil or type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 then
		return nil
	end
	if session.items[boxUid] ~= nil then
		return skipAntiTheft(player, data, session, boxUid, seconds)
	end
	return nil -- vague 50 (a158) : plus de colis posé en attente
end

function UnboxService.Init()
	Net.Server.PlaceBox:Connect(onPlaceBox)
	Net.Server.OpenBox:Connect(onOpenBox)

	-- Les objets posés reviennent quand le profil est chargé ET la parcelle attribuée (PlotService attend le
	-- profil) ; les deux signaux rejouent ce qui est déjà fait au moment de l'abonnement.
	DataService.OnProfileLoaded(setup)
	PlotService.OnPlotAssigned(function(player: Player, _plot: Model)
		setup(player)
	end)
	PlotService.OnPlotReleased(function(player: Player, _plot: Model)
		teardown(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		carryStarts[player] = nil
		teardown(player)
	end)

	-- Où et quand le portage de l'objet a commencé (contrôle du trajet au rangement, DEV-060).
	CarryService.OnCarryStarted(function(player: Player, payload: any)
		local root = rootOf(player)
		if root and type(payload) == "table" and payload.Kind == NPC_ITEM_KIND then
			carryStarts[player] = { Payload = payload, From = root.Position, At = os.clock() }
		else
			carryStarts[player] = nil
		end
	end)
	CarryService.OnCarryEnded(function(player: Player, payload: any)
		local start = carryStarts[player]
		if start and start.Payload == payload then
			carryStarts[player] = nil
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < TICK then
			return
		end
		elapsed = 0
		stowArrivals()
		advanceTimers()
		for player in sessions do
			refreshStates(player)
		end
	end)
end

return UnboxService
