--!strict
-- UnboxService (DEV-019, L-089) : colis rangés dans l'inventaire à l'entrée de la zone safe, posés
-- au sol de sa boutique, attente selon la rareté, ouverture des colis PNJ (Partie 1, sections 5.6,
-- 5.7, 5.8, 7.3, 9.4 et 9.5).
--
-- Décisions de Clément du 2026-11-09 (liaison L-089, points 1 à 3 ; L-079) : plus d'établi ni de
-- présentoir imposé (L-086 remplacé). Le colis porté entre dans l'inventaire dès que le joueur entre
-- dans la zone safe ; le joueur le prend dans son inventaire (écran UI_Inventory, InventoryService) et le
-- pose où il veut sur le sol de SA boutique ; il s'ouvre là ; l'objet gagné va dans l'inventaire.
--
-- Rôle :
--   - Rangement (« Arrivée », 5.6 ; 14.2 étape 5) : 4 fois par seconde, un porteur de colis PNJ
--     (CarryService, payload Kind = "NPCBox") dont le HumanoidRootPart est dans le volume d'un objet
--     taggé SafeZone (la pièce elle-même, sinon son enfant direct Bounds, sinon la boîte englobante du
--     Model ; seulement dans la map, pas dans _INBOX_CLEMENT) range son colis. Juste avant,
--     AntiCheatService.Verify (DEV-060) contrôle tout de suite son dernier déplacement (téléport) et le
--     trajet depuis le point où ce portage a commencé (OnCarryStarted) : sanctionné, le colis vient de
--     revoler vers son rayon et rien n'est rangé. Puis CarryService.Consume le lui retire et le colis
--     est écrit dans le profil, dans la même exécution, sans yield : Boxes[uid] = { Tier, Zone,
--     ItemId, Rarity, Mutation?, At } (9.5, profil v7 : uid neuf, HttpService:GenerateGUID ; Spot
--     absent = dans l'inventaire ; Types/Profile). InventoryService le montre dans l'écran d'inventaire.
--     Plus de Unbox.BoxInventoryMax colis dans l'inventaire (V0 : 50) : le colis n'entre pas, le
--     portage échoue (CarryService.Fail, raison « InventoryFull ») et le colis revole vers son rayon,
--     avec un Notify (MESSAGES.BoxesFull).
--   - Braquage réussi : Lifetime.Heists + 1 au même moment, d'un seul tenant avec l'écriture du colis
--     (réussite « Consumed » de Types/Carry). Avant, le colis peut encore retourner sur son rayon
--     (rattrapé, mort, départ, anomalie : 5.5, 5.6) ou tomber au sol (coup de batte, 6.2). Une seule
--     fois par colis. Celui qui ramasse un colis tombé au sol et le rentre compte le braquage.
--   - PlaceBox(boxUid, point) : le joueur pose un colis de son inventaire (Spot absent) sur le sol de
--     sa boutique, au point visé. Le serveur décide de tout (règle plus bas, findFloor) : le joueur a
--     sa boutique (PlotService), ne porte rien, a moins de Unbox.MaxPlacedBoxes colis posés (V0 : 8) ;
--     le point est dans le volume Bounds de SA boutique (à Unbox.EdgeMargin studs du bord au moins) ;
--     le sol est cherché sous ce point par un rayon vers le bas, parti de Unbox.FloorRayUp studs
--     au-dessus du bas de Bounds, parmi les pièces de la parcelle (CanQuery) : il faut une surface
--     assez plate (normale.Y ≥ FloorMinNormalY) à FloorTolerance studs au plus du bas de Bounds (le
--     haut d'un présentoir ou d'un meuble n'est pas le sol) ; ce point du sol est à portée du
--     personnage (PromptDistance + ReachTolerance studs), à BoxSpacing studs au moins des autres colis
--     posés et à StandClearance studs (à plat) au moins de chaque DisplaySlot_xx, et le volume du
--     colis (BoxFootprint) n'y touche aucune pièce solide de la parcelle (CanCollide : mur, meuble,
--     présentoir). Refus : un Notify (MESSAGES). Accepté : Spot = ce point dans le repère du pivot de
--     la parcelle (Types/Profile), ReadyAt = heure serveur + attente de sa rareté (table 7.3,
--     Config.Rarities[..].OpenDelay ; GetOpenDelay plus bas), ou l'heure déjà promise si elle est plus
--     tôt (colis repris d'un présentoir à la migration v7 : aucune attente perdue).
--   - Attente écoulée : BoxReady(boxUid) au propriétaire.
--   - OpenBox(boxUid) : colis posé, attente écoulée (heure serveur), joueur sur sa parcelle et à
--     portée du colis, place pour l'objet (inventaire pas plein, sinon un présentoir libre) →
--     amélioration du colis tirée (plus bas), nouvel objet dans Items sous un uid unique ({ Id = ItemId,
--     Source = "NPC", At = os.time(), Zone, Mutation? : celle du colis, DEV-131 }), le colis quitte
--     Boxes, UnboxReveal(boxUid, itemUid, itemId, zone, tier, startRarity, upgrades, mutationSize?,
--     mutationEffect?) au joueur. L'objet va dans l'inventaire (L-089 point 3 : il n'est plus exposé
--     tout seul) ; InventoryService ne le montre qu'au moment où il se révèle chez celui qui ouvre
--     (HoldBack : son nom ne doit pas arriver avant la révélation, 5.7). Inventaire plein
--     (Balance.Display.InventoryMax objets non exposés, 5.8) mais un présentoir libre : l'objet y est
--     exposé (DisplayService.PlaceAuto, le plus proche du colis) et le joueur reçoit un Notify
--     (MESSAGES.ToStand) à la révélation. Ni l'un ni l'autre : ouverture refusée (MESSAGES.InventoryFull).
--   - Au retour du joueur (profil chargé et parcelle attribuée), ses colis posés réapparaissent à leur
--     place, et BoxReady part pour ceux déjà prêts. Un colis posé dont le point n'est plus dans le
--     volume Bounds de la parcelle (modèle de boutique changé ; le colis doit y tenir entier) ou qui est à
--     moins de StandClearance d'un présentoir (L-141 : présentoirs déplacés) revient dans l'inventaire,
--     ReadyAt gardé (MESSAGES.BackToInventory) : jamais perdu. Même règle pour les objets sous antivol.
--   - L'objet exact reste caché jusqu'à l'ouverture (5.7) : l'ItemId ne quitte le serveur que dans
--     UnboxReveal. Aucun attribut, nom ni modèle (colis posé, état de l'inventaire) ne le montre avant.
--
-- Vague 31 (L-112, décisions de Cantin du 2026-11-12 ; Features.ShelfOpen, Config/ShelfOpen) : le colis
-- s'ouvre sur le rayon du magasin (StoreHeistService, a103) ; le joueur rapporte l'objet lui-même (portage
-- Kind « NPCItem »). Ici, la base (à false : rien de tout cela, l'ancien déroulé exact) :
--   - Arrivée : à l'entrée de la zone safe, comme le colis (même boucle, AntiCheatService.Verify, Consume,
--     profil écrit d'un seul tenant, braquage compté, Notify, BoxSecured), l'objet entre dans Items sous un
--     uid neuf, AntiTheft = true (Types/Profile) ; IndexService.Discover. Inventaire plein
--     (DisplayService.HasInventoryRoom) : le portage échoue (« InventoryFull »).
--   - Pose : PlaceBox(itemUid, point) (même remote, mêmes règles que le colis : findFloor, MaxPlacedBoxes
--     colis et objets au sol). L'antivol démarre : UnlockAt = heure serveur + ShelfOpen.AntiTheft[rareté].
--     Le modèle (DisplayService.BuildFloorItem : ITM_, halo) est au sol, tag FloorItem, attribut UnlockAt ;
--     UnboxController y met BB_AntiTheft (minuteur, puis « UNLOCKED! ») et les invites. Pendant l'antivol :
--     jamais sur un présentoir (DisplayService le refuse), volable (PvPService, StealFloorItem).
--   - Fini : un Notify au propriétaire ; OpenBox(itemUid) le reprend (antivol retiré) et le met sur le
--     présentoir libre le plus proche (DisplayService.PlaceAuto), sinon dans l'inventaire.
--   - Au retour du joueur, ses objets posés reviennent à leur place (l'antivol compte aussi hors ligne, comme
--     l'attente des colis) ; un point hors de Bounds : retour dans l'inventaire, sous antivol.
--   - Les colis déjà dans les profils deviennent des objets au chargement (DataService, convertBoxes). Les
--     colis donnés pendant la partie (récompenses, camion, tuto) gardent l'ancien déroulé.
--   - Boutique Robux (Cantin, 2026-11-12 ; MonetizationService, coupée tant que Features.RobuxShop = false) :
--     GetWaiting compte aussi les objets sous antivol au sol ([itemUid] = UnlockAt ; pas un objet porté par
--     un voleur) et SkipWait(player, itemUid, s) avance leur UnlockAt (Ouvrir maintenant, son crédit, Fast Open
--     à l'achat) ; UnboxService.GetAntiTheftDelay(player, itemId) -> number (ShelfOpen.AntiTheft[rareté] par
--     défaut, remplaçable comme GetOpenDelay : Fast Open × DelayFactor).
--   API ajoutée : OnItemStowed(listener), OnItemPlaced(listener) : listener(player, itemUid, itemId) ;
--   pour PvPService : GetFloorItem(owner, uid) -> FloorItem?, GetFloorItems(owner), IsStealable(owner, uid),
--   HoldFloorItem (le modèle sort du monde, plus de reprise), ReleaseFloorItem (vol raté : il revient),
--   TakeFloorItem (dépôt : le modèle part ; PvPService retire l'objet du profil), IsFloorHeld. Sans yield.
--
-- Amélioration du colis (DEV-050, étape 0 de la spec ouverture-colis, règle nouvelle de Clément du
-- 2026-11-07, valeurs dans Config.Unbox) : à OpenBox, avant tout envoi, jusqu'à UpgradeMax (2)
-- crans ; chaque cran réussit avec UpgradeChance (10 %) × la chance du joueur (GetLuck, 1 par
-- défaut ; probabilité bornée à 1) et fait monter le colis d'une rareté, dans l'ordre de
-- Rarities.List (Commun → Peu commun → Rare). Un cran n'est tenté que si la rareté visée :
--   - n'est ni Secret ni au-dessus (Divine, L-106) ;
--   - peut sortir de ce colis dans sa zone (ShelfBoxes.OddsFor(zone, tier) > 0) : jamais en zone 1,
--     qui ne tire que des Communs (L-033) ;
--   - a au moins un objet tirable dans la zone (Items.ByZone[zone][rareté]).
-- Sinon, comme au premier échec, l'amélioration s'arrête (V0 à confirmer par Clément : la spec ne
-- pose la condition « que ce colis peut donner » que pour le frôlement). Un colis au contenu imposé
-- n'est jamais amélioré : c'est un colis dont la propre rareté ne peut pas sortir de son type dans
-- sa zone, comme le colis garanti du tuto (objet Rare en zone 1, posé par
-- StoreHeistService.SetContentOverride). Un colis amélioré change d'objet : Items.Pick(zone,
-- rareté finale) ; sans cran, l'objet tiré à la mise en rayon reste. UnboxReveal donne au client
-- la rareté de départ et le nombre de crans (chaque cran monte d'une rareté : le client en déduit
-- les raretés), la zone et le type du colis (composition du rouleau, revenu du Secret).
--
-- Annonce (5.7, étape 6 : « Légendaire et plus, annonce à tout le serveur » ; Rarities.Announce) :
-- un Notify (catégorie Config.Unbox.AnnounceKind) aux autres joueurs du serveur, au moment où
-- l'objet se révèle chez celui qui ouvre (durées de Config.Unbox, ouverture au secours de 0,45 s).
-- Texte V0 en anglais (L-036) : « Alice unboxed a LEGENDARY Giant Plush! ».
--
-- Heure serveur : ReadyAt est en secondes depuis l'époque Unix, la même échelle que os.time(),
-- mais lue avec Workspace:GetServerTimeNow(), précise au millième. Le client lit la même horloge.
--
-- Dans le monde (visible par tous, rien de secret : la rareté se voit dès qu'on soulève le colis,
-- 5.6) :
--   - au sol, une copie du modèle BOX_<Rareté> de Clément (L-097 point 3, déjà à sa couleur ; cherché
--     dans ReplicatedStorage/Assets, puis ServerStorage/Assets), sinon BOX_<Tier>, sa pièce Tint teinte à
--     la couleur de la rareté ; sans lui, un bloc V0 de cette couleur. L'écran d'ouverture
--     (UnboxController) en fait une copie locale : il montre donc le même modèle. La copie s'appelle FloorBox (sans le préfixe BOX_, pour que le ContractChecker ne
--     la prenne pas pour un modèle livré), est rangée dans la parcelle, son pivot (en bas au centre,
--     10.1) posé sur le point du sol, tournée comme la parcelle (face avant vers la rue), et porte les
--     attributs BoxUid, OwnerUserId, Rarity, ReadyAt et UnboxState ("Waiting" puis "Ready"), lus par
--     UnboxController (invite « Open » du propriétaire) ;
--   - au-dessus, le minuteur : copie de BB_OpenTimer (ReplicatedStorage/Assets/UI, élément Label),
--     accrochée au pied du colis (le StudsOffsetWorldSpace de Clément part de là, liaison L-027),
--     sinon un billboard V0. Le serveur y écrit le temps restant (m:ss), puis « Ready! » ;
--   - attribut UnboxState sur chaque DisplaySlot_xx d'une parcelle attribuée, lu par
--     InventoryController (invite « Place Item » quand on tient un objet de l'inventaire) : "Locked"
--     (pas encore débloqué), "Free" (libre), "Taken" (un objet exposé, ou volé en ce moment). Remis à
--     jour 4 fois par seconde ; retiré quand la parcelle se libère.
--
-- Remotes : PlaceBox(boxUid, point) et OpenBox(boxUid) (client → serveur, forme et débit déjà
-- contrôlés par Net) ; BoxReady, UnboxReveal et Notify (serveur → client).
--
-- API (côté serveur) :
--   UnboxService.Refresh(player)
--       Recalcule tout de suite l'attribut UnboxState des présentoirs (après l'achat d'un présentoir,
--       ShopService) ; sinon la boucle le fait au plus 0,25 s plus tard.
--   UnboxService.GetOpenDelay(player, box) -> number
--       Attente d'ouverture, en secondes, du colis qu'on pose (box : Tier, Zone, ItemId, Rarity).
--       Par défaut, celle de sa rareté (7.3). TutorialService la remplace pour le premier colis
--       (5 s, Config.Tutorial.OpenDelay) :
--         UnboxService.GetOpenDelay = function(player, box) ... end
--       Ne doit pas yield. Une valeur qui n'est pas un nombre fini ≥ 0 est ignorée.
--   UnboxService.GetLuck(player, box) -> number
--       Chance du joueur pour l'amélioration du colis qu'il ouvre (box : copie du colis sauvegardé).
--       1 par défaut : aucune source de chance au MVP (un bonus en Partie 2). Remplaçable comme
--       GetOpenDelay ; 0 = aucun cran pour ce colis. Ne doit pas yield. Une valeur qui n'est pas un
--       nombre fini ≥ 0 est ignorée (chance 1).
--   UnboxService.RollUpgrades(box, luck, rng?) -> { RarityId }
--       Le tirage de l'amélioration (règle plus haut), sans rien changer : les raretés atteintes,
--       cran par cran (vide : aucun cran). Pur, sans yield ; rng = un Random (celui du service par
--       défaut). Appelé par OpenBox ; exposé pour les bancs d'essai et la télémétrie.
--   UnboxService.OnBoxStowed(listener) -> déconnexion
--       listener(player, boxUid, box) après chaque colis rangé dans l'inventaire à l'entrée de la
--       zone safe (tutoriel, funnel 14.2 étape 5). box est une copie du colis sauvegardé, ItemId
--       compris : ne jamais l'envoyer à un client.
--   UnboxService.OnBoxPlaced(listener) -> déconnexion
--       listener(player, boxUid, box) après chaque colis posé au sol par le joueur (tutoriel,
--       boutique Robux, télémétrie). Même règle pour box.
--   UnboxService.OnBoxOpened(listener) -> déconnexion
--       listener(player, boxUid, itemUid, itemId, revealDelay) après chaque ouverture (tutoriel,
--       télémétrie, index des objets) ; itemId = l'objet final, après l'amélioration ; revealDelay =
--       secondes jusqu'à l'objet révélé chez celui qui ouvre (le délai de l'annonce et de
--       l'objet dans l'inventaire), pour un message qui ne doit pas arriver avant la révélation (DEV-111).
--   UnboxService.GiveBox(player, tier, zone, minRarity?) -> (string?, string?)
--       Colis offert (récompenses, DEV-101, RewardService) : écrit dans l'inventaire du profil comme un
--       colis rangé (Boxes[uid] sans Spot, At = maintenant, montré dans l'inventaire), avec les mêmes règles :
--       au plus Unbox.BoxInventoryMax colis dans l'inventaire. Contenu tiré par le serveur avec les
--       probabilités de ce type de colis dans cette zone (ShelfBoxes.OddsFor), seulement parmi minRarity et
--       au-dessus si minRarity est donné (les autres poids gardent leurs proportions) et parmi les
--       raretés qui ont un objet dans la zone ; mutation tirée comme à la mise en rayon. Ni braquage
--       compté, ni OnBoxStowed (ce n'est pas un colis rapporté du couloir). Renvoie l'uid du colis, ou
--       nil et la raison : "NoProfile", "InventoryFull" (rien n'est écrit : la récompense reste à
--       réclamer), "Invalid" (type, zone ou rareté inconnus), "NoContent" (aucune rareté possible). Sans
--       yield.
--   UnboxService.GetBoxPosition(player, boxUid) -> Vector3?
--       Point du monde (pied du colis) d'un colis posé au sol et affiché ; nil sinon (tutoriel).
--   Boutique Robux (DEV-100, MonetizationService : « Ouvrir maintenant », « Ouverture rapide ») :
--   UnboxService.GetWaiting(player) -> { [string]: number }
--       Colis posés du joueur pas encore prêts : [uid du colis] = heure serveur (ReadyAt) où chacun le
--       sera. Vide sans colis en attente.
--   UnboxService.SkipWait(player, boxUid, seconds) -> number?
--       Avance de `seconds` (au plus jusqu'à maintenant) l'heure d'ouverture de ce colis posé, dans le
--       profil et au sol ; renvoie l'attente restante (0 = prêt : BoxReady part tout de suite), nil
--       s'il n'est pas posé et en attente. Sans yield.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Features = require(Shared.Config.Features)
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local ShelfBoxes = require(Shared.Config.ShelfBoxes)
local ShelfOpen = require(Shared.Config.ShelfOpen)
local Unbox = require(Shared.Config.Unbox)
local Zones = require(Shared.Config.Zones)
local Find = require(Shared.Contract.Find)
local UI = require(Shared.Contract.UI)
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
-- (a51). Payload d'un colis PNJ : { Kind = "NPCBox", Tier, Zone, Rarity, ItemId, StoreId, SlotId }.
type CarryApi = {
	IsCarrying: (player: Player) -> boolean,
	GetPayload: (player: Player) -> any,
	Consume: (player: Player) -> any,
	Fail: (player: Player, reason: string) -> boolean,
	OnCarryStarted: (listener: (player: Player, payload: any) -> ()) -> any,
	OnCarryEnded: (listener: (player: Player, payload: any, result: string, reason: string) -> ()) -> any,
}
type DisplayApi = {
	PlaceAuto: (player: Player, itemUid: string, near: Vector3?) -> number?,
	-- Place pour un objet de plus : un présentoir libre ou l'inventaire (DEV-100, présentoirs bonus compris).
	HasRoom: (player: Player) -> boolean,
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
	HoldBack: (player: Player, itemUid: string, seconds: number) -> (),
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

export type BoxListener = (player: Player, boxUid: string, box: Box) -> ()
export type OpenedListener = (player: Player, boxUid: string, itemUid: string, itemId: string, revealDelay: number) -> ()
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

-- Colis affiché au sol.
type Shown = {
	model: Model,
	label: TextLabel?, -- texte du minuteur
	base: CFrame, -- point du sol où il est posé, tourné comme la parcelle
	readyAt: number,
	ready: boolean,
	text: string?, -- dernier texte écrit dans le minuteur
}

-- Parcelle d'un joueur présent, telle que ce service l'affiche.
type Session = {
	plot: Model,
	slots: { [number]: Attachment }, -- présentoirs de la parcelle (DisplayService.GetSlots)
	shown: { [string]: Shown }, -- colis posés et affichés, par uid
	items: { [string]: ShownItem }, -- vague 31 : objets sous antivol posés au sol, par uid d'objet
	states: { [number]: StandState? }, -- dernier UnboxState écrit sur chaque présentoir
}

-- Début du portage d'un colis PNJ (DEV-060), pour le contrôle du trajet au rangement : la table du
-- payload (celle de CarryService), la position du HumanoidRootPart et os.clock() à ce moment.
type CarryStart = { Payload: any, From: Vector3, At: number }

-- Contrat (10.3, 10.4 et 2.2).
local BOX_PREFIX = "BOX_" -- BOX_Standard, BOX_Premium, BOX_Luxe
local TINT = "Tint" -- pièce du colis recolorée selon la rareté
local TIMER_BILLBOARD = "BB_OpenTimer"
local TIMER_LABEL = "Label"
local BOUNDS = "Bounds"
local SAFE_ZONE_TAG = "SafeZone"
local INBOX_NAME = "_INBOX_CLEMENT"
-- Attribut de la parcelle posé par PlotService : UserId du propriétaire, 0 = libre.
local OWNER_ATTRIBUTE = "OwnerUserId"
-- payload.Kind d'un colis volé à un magasin PNJ (CarryService).
local NPC_BOX_KIND = "NPCBox"
-- Attributs posés par ce service (voir l'en-tête).
local STATE_ATTRIBUTE = "UnboxState"
local BOX_UID_ATTRIBUTE = "BoxUid"
local RARITY_ATTRIBUTE = "Rarity"
local READY_AT_ATTRIBUTE = "ReadyAt"
local BOX_MODEL_NAME = "FloorBox"
local TIMER_NAME = "OpenTimer"
local TIMER_POINT = "TimerPoint"
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

-- V0 proposé, absent du doc : portée (studs) de l'invite d'un colis, la même que celle
-- d'UnboxController, et marge du serveur pour la gigue réseau. Le serveur accepte PlaceBox et
-- OpenBox jusqu'à PROMPT_DISTANCE + REACH_TOLERANCE entre le HumanoidRootPart et le point du sol.
-- Valeurs dans Config.Unbox, partagées avec le client (OpenNextButton suit la même règle).
local PROMPT_DISTANCE = Unbox.PromptDistance
local REACH_TOLERANCE = Unbox.ReachTolerance
-- V0 proposé, absent du doc : cadence (s) de la boucle qui fait avancer les minuteurs, range les
-- colis portés dans la zone safe et remet à jour UnboxState.
local TICK = 0.25
-- V0 proposé, absent du doc : le volume du colis posé part de cette hauteur (studs) au-dessus du sol
-- (le sol lui-même ne le bloque pas).
local FOOTPRINT_LIFT = 0.1
-- V0 proposé, absent du doc : arrondi (studs) du point enregistré dans Spot.
local SPOT_ROUND = 0.01
-- V0 proposé, absent du doc : texte du minuteur quand le colis est prêt, en anglais (L-036).
local READY_TEXT = "Ready!"
-- V0 proposé, absent du doc : bloc de remplacement de BOX_<Tier> (studs).
local V0_BOX_SIZE = Vector3.new(2, 2, 2)
-- V0 proposé, absent du doc : billboard de remplacement de BB_OpenTimer.
local V0_TIMER_SIZE = UDim2.fromScale(4, 1.2) -- en studs
local V0_TIMER_GAP = 1.2 -- studs entre le haut du colis et le bas du minuteur
local V0_TIMER_MAX_DISTANCE = 60

-- Messages lus par le joueur (Notify), en anglais (L-036). V0 proposé, absent du doc.
local MESSAGES = {
	Stowed = "Box secured! Open it in your shop.", -- texte de Clément (L-106 point 5), envoyé avec le remote BoxSecured
	BoxesFull = "Too many boxes in your inventory: open some first.",
	NoShop = "You don't have a shop yet: wait for one to free up.",
	OutsideShop = "Put your box down inside your own shop.",
	NotFloor = "Put your box on the floor of your shop.",
	TooFar = "Get closer to put your box down.",
	Blocked = "No room here: try another spot.",
	TooMany = "Too many boxes on the floor: open one first.",
	NotReady = "This box isn't ready yet.",
	InventoryFull = "Inventory full: display or sell an item before opening this box.",
	-- %s = nom de l'objet (Config.Items, DisplayName)
	ToStand = "Your inventory is full: %s went on a display stand.",
	BackToInventory = "A box of yours didn't fit in this shop: it's back in your inventory.",
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
	ItemUnlocked = "%s is UNLOCKED! Put it on a display.",
	ItemToStand = "%s placed on a display!",
	ItemBack = "%s is back in your inventory: your displays are full.",
	ItemBackToInventory = "An item of yours didn't fit in this shop: it's back in your inventory.",
}
-- Catégorie des Notify d'information (objet gardé…) ; les refus partent en « Warning ».
local INFO_KIND = "Info"
-- Catégorie des réussites : texte vert dans UI_Toast (Config/UiMotion.Toast.Colors, L-095 point 3).
local SUCCESS_KIND = "Success"

local IS_STUDIO = RunService:IsStudio()
local REACH = PROMPT_DISTANCE + REACH_TOLERANCE

local UnboxService = {}

local sessions: { [Player]: Session } = {}
local stowedListeners: { BoxListener } = {}
local placedListeners: { BoxListener } = {}
local openedListeners: { OpenedListener } = {}
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

local function emit(list: { BoxListener }, player: Player, boxUid: string, box: Box)
	for _, listener in table.clone(list) do
		task.spawn(listener, player, boxUid, table.clone(box))
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

-- Raison du refus si `content` (colis porté ou sauvegardé) est mal formé, sinon nil.
local function checkContent(content: any): string?
	if type(content) ~= "table" then
		return "pas une table"
	end
	if type(content.Tier) ~= "string" or Balance.Heist.BoxTiers[content.Tier] == nil then
		return `Tier inconnu ({tostring(content.Tier)})`
	end
	if type(content.Zone) ~= "number" or Zones[content.Zone] == nil then
		return `Zone inconnue ({tostring(content.Zone)})`
	end
	if type(content.Rarity) ~= "string" or Rarities.ById[content.Rarity] == nil then
		return `Rarity inconnue ({tostring(content.Rarity)})`
	end
	if type(content.ItemId) ~= "string" or Items.ById[content.ItemId] == nil then
		return `ItemId inconnu ({tostring(content.ItemId)})`
	end
	return nil
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

-- checkContent, plus le point du sol et l'heure d'ouverture d'un colis posé.
local function checkPlaced(box: any): string?
	local problem = checkContent(box)
	if problem == nil and spotOf(box) == nil then
		problem = `Spot invalide ({tostring(box.Spot)})`
	end
	if problem == nil and not isFinite(box.ReadyAt) then
		problem = `ReadyAt invalide ({tostring(box.ReadyAt)})`
	end
	return problem
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

-- Uid neuf, absent de `list` (Items ou Boxes du profil).
local function newUid(list: { [string]: any }): string
	local uid = HttpService:GenerateGUID(false)
	while list[uid] ~= nil do
		uid = HttpService:GenerateGUID(false)
	end
	return uid
end

-- Colis de l'inventaire (Spot absent) et colis posés, comptés dans le profil.
local function countBoxes(data: Data): (number, number)
	local stored, placed = 0, 0
	for _, box in data.Boxes do
		if type(box) == "table" and box.Spot ~= nil then
			placed += 1
		else
			stored += 1
		end
	end
	return stored, placed
end

-- Vague 31 (L-112, Features.ShelfOpen) : objet sous antivol (Types/Profile : AntiTheft, UnlockAt, Spot).
-- Interrupteur coupé : champs ignorés, l'ancien déroulé exact.
local function isAntiTheft(entry: any): boolean
	return Features.ShelfOpen == true and type(entry) == "table" and entry.AntiTheft == true
end

-- Objets sous antivol posés au sol (comptés avec les colis posés pour Unbox.MaxPlacedBoxes).
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
	local zone = def.Zone or (if type(entry.Zone) == "number" and Zones[entry.Zone] ~= nil then entry.Zone else nil) or 1
	return Formulas.ItemIncome(zone, def.Rarity) * Mutations.IncomeMultiplier(Mutations.Sanitize(entry.Mutation))
end

local function emitItem(list: { ItemListener }, player: Player, itemUid: string, itemId: string)
	for _, listener in table.clone(list) do
		task.spawn(listener, player, itemUid, itemId)
	end
end

-- Attente d'ouverture du colis `box` : UnboxService.GetOpenDelay (remplaçable), sinon celle de
-- sa rareté.
local function openDelay(player: Player, box: Box): number
	local ok, value = pcall(UnboxService.GetOpenDelay, player, table.clone(box))
	if ok and type(value) == "number" and value >= 0 and value < math.huge then
		return value
	end
	local reason = if ok then "valeur invalide " .. tostring(value) else tostring(value)
	warn(`[UnboxService] GetOpenDelay ({player.Name}) : {reason}, attente de la rareté utilisée`)
	return Rarities.ById[box.Rarity].OpenDelay
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

-- Article anglais devant un mot en capitales : « a LEGENDARY », « an EPIC ».
local function article(word: string): string
	return if string.find(word, "^[AEIOU]") then "an" else "a"
end

-- Délai (s) entre UnboxReveal et l'objet révélé chez celui qui ouvre, si rien ne le presse :
-- `upgrades` crans, ouverture au secours de 0,45 s, rouleau, dernier cran, pause, couleurs
-- (Config.Unbox ; même calcul que la séquence d'UnboxController).
local function revealDelay(full: boolean, upgrades: number): number
	local reel = if full then Unbox.ReelDuration.Full else Unbox.ReelDuration.Short
	return upgrades * Unbox.UpgradeStep
		+ Unbox.OpenFallback
		+ Unbox.ReelExit
		+ reel
		+ Unbox.LastNotch
		+ Unbox.StopPause
		+ Unbox.ColorIn
end

-- Délai jusqu'à l'objet révélé chez celui qui ouvre, pour un objet de rareté finale `rarityId`.
local function revealDelayFor(rarityId: string, upgrades: number): number
	local rarity = Rarities.ById[rarityId]
	return revealDelay(if rarity then rarity.FullReveal else true, upgrades)
end

-- Notify à `player` après `delay` s (au moment où son objet se révèle chez lui) ; rien s'il est
-- parti entre-temps.
local function notifyLater(player: Player, message: string, kind: string, delay: number)
	task.delay(delay, function()
		if player.Parent == Players then
			notify(player, message, kind)
		end
	end)
end

-- Annonce à tout le serveur d'un objet Légendaire ou mieux (Rarities.Announce, 5.7 étape 6) : un
-- Notify aux autres joueurs, quand l'objet se révèle chez `player`. V0 : le texte, la catégorie
-- (Config.Unbox.AnnounceKind) et l'affichage (UI_Notify, pas encore livré).
local function announce(player: Player, itemId: string, rarityId: string, upgrades: number)
	local rarity = Rarities.ById[rarityId]
	local item = Items.ById[itemId]
	if rarity == nil or item == nil or not rarity.Announce then
		return
	end
	local name = rarity.DisplayNameUpper
	local message = `{player.DisplayName} unboxed {article(name)} {name} {item.DisplayName}!`
	local delay = revealDelay(rarity.FullReveal, upgrades)
	log(`annonce dans {delay} s aux autres joueurs : {message}`)
	task.delay(delay, function()
		for _, other in Players:GetPlayers() do
			if other ~= player then
				notify(other, message, Unbox.AnnounceKind)
			end
		end
	end)
end

------------------------------------------------------------------------------
-- Colis posés au sol
------------------------------------------------------------------------------

-- Premier élément nommé `name` dans ReplicatedStorage/Assets, puis dans ServerStorage/Assets.
local function findAsset(name: string): Instance?
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild("Assets")
		local found = if assets then Find.path(assets, name) else nil
		if found then
			return found
		end
	end
	return nil
end

-- Billboard modèle BB_OpenTimer de Clément (directement dans ReplicatedStorage/Assets/UI, 2.2).
local function findTimerTemplate(): BillboardGui?
	local folder: Instance? = ReplicatedStorage
	for _, name in UI.BillboardFolder do
		folder = if folder then folder:FindFirstChild(name) else nil
	end
	local template = if folder then folder:FindFirstChild(TIMER_BILLBOARD) else nil
	if template ~= nil and template:IsA("BillboardGui") then
		return template :: BillboardGui
	end
	return nil
end

-- Petit décor : ancré, sans collision ni contact, ignoré des rayons.
local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- Copie du modèle de Clément `name` et la pièce qui portera le minuteur ; nil s'il n'est pas
-- encore livré.
local function cloneBoxTemplate(name: string): (Model?, BasePart?)
	local template = findAsset(name)
	if template == nil or not template:IsA("Model") then
		return nil, nil
	end
	local model = (template :: Model):Clone() :: Model
	local anchor = model.PrimaryPart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("ProximityPrompt") then
			descendant:Destroy() -- jamais de script dans un modèle (CLAUDE.md) ; l'invite est au client
		elseif descendant:IsA("BasePart") then
			prepare(descendant)
			anchor = anchor or descendant
		end
	end
	if anchor == nil then
		model:Destroy()
		return nil, nil
	end
	return model, anchor
end

-- Modèle du colis `boxUid` posé au sol en `base`, teint à la couleur de sa rareté, et la pièce qui
-- porte le minuteur.
local function buildBoxModel(player: Player, boxUid: string, box: Box, base: CFrame): (Model, BasePart)
	local color = Rarities.ById[box.Rarity].Color
	-- BOX_<Rareté> (L-097 point 3), déjà à la couleur de sa rareté ; sinon BOX_<Tier>, teint.
	local cloned, clonedAnchor = cloneBoxTemplate(BOX_PREFIX .. box.Rarity)
	local byRarity = cloned ~= nil
	if cloned == nil then
		cloned, clonedAnchor = cloneBoxTemplate(BOX_PREFIX .. box.Tier)
	end
	local model: Model
	local anchor: BasePart
	if cloned and clonedAnchor then
		model, anchor = cloned, clonedAnchor
		local tint = Find.path(model, TINT)
		if not byRarity and tint ~= nil and tint:IsA("BasePart") then
			(tint :: BasePart).Color = color
		end
		model:PivotTo(base) -- pivot en bas au centre (10.1), posé sur le sol
	else
		model = Instance.new("Model")
		local block = Instance.new("Part")
		block.Name = "Block"
		block.Size = V0_BOX_SIZE
		block.Color = color
		block.Material = Enum.Material.SmoothPlastic
		prepare(block)
		block.CFrame = base * CFrame.new(0, V0_BOX_SIZE.Y / 2, 0)
		block.PivotOffset = CFrame.new(0, -V0_BOX_SIZE.Y / 2, 0) -- pivot en bas au centre, comme un BOX_ (10.1)
		block.Parent = model
		model.PrimaryPart = block
		anchor = block
	end
	model.Name = BOX_MODEL_NAME
	model:SetAttribute(BOX_UID_ATTRIBUTE, boxUid)
	model:SetAttribute(OWNER_ATTRIBUTE, player.UserId)
	model:SetAttribute(RARITY_ATTRIBUTE, box.Rarity)
	model:SetAttribute(READY_AT_ATTRIBUTE, box.ReadyAt)
	return model, anchor
end

-- Minuteur au-dessus du colis : copie de BB_OpenTimer, accrochée au pied du colis (`base`, avec ses
-- axes ; le StudsOffsetWorldSpace de Clément part de là) ; sinon billboard V0, accroché au centre de
-- son bloc. Renvoie son texte.
local function buildTimer(anchor: BasePart, base: CFrame): TextLabel?
	local template = findTimerTemplate()
	local gui: BillboardGui
	if template then
		gui = template:Clone() :: BillboardGui
		local point = Instance.new("Attachment")
		point.Name = TIMER_POINT
		point.CFrame = anchor.CFrame:ToObjectSpace(base)
		point.Parent = anchor
		gui.Adornee = point
	else
		gui = Instance.new("BillboardGui")
		gui.Size = V0_TIMER_SIZE
		gui.StudsOffsetWorldSpace = Vector3.new(0, anchor.Size.Y / 2 + V0_TIMER_GAP + V0_TIMER_SIZE.Y.Scale / 2, 0)
		gui.MaxDistance = V0_TIMER_MAX_DISTANCE
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = TIMER_LABEL
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Text = ""
		label.Parent = gui
		gui.Adornee = anchor
	end
	gui.Name = TIMER_NAME
	gui.Parent = anchor
	local label = Find.path(gui, TIMER_LABEL)
	if label ~= nil and label:IsA("TextLabel") then
		return label :: TextLabel
	end
	warnOnce("timerLabel", `{TIMER_BILLBOARD} sans TextLabel « {TIMER_LABEL} » (contrat 2.2) : minuteur muet`)
	return nil
end

local function timerText(remaining: number): string
	local seconds = math.max(0, math.ceil(remaining))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function setLabel(shown: Shown, text: string)
	if shown.text == text then
		return
	end
	shown.text = text
	local label = shown.label
	if label then
		label.Text = text
	end
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

local function markReady(player: Player, boxUid: string, shown: Shown)
	shown.ready = true
	setLabel(shown, READY_TEXT)
	shown.model:SetAttribute(STATE_ATTRIBUTE, "Ready")
	Net.Server.BoxReady:Fire(player, boxUid)
end

local function clearShown(session: Session, boxUid: string)
	local shown = session.shown[boxUid]
	if shown then
		session.shown[boxUid] = nil
		shown.model:Destroy()
	end
end

-- Affiche le colis posé `box` à sa place ; BoxReady part tout de suite s'il est déjà prêt.
local function showBox(player: Player, session: Session, boxUid: string, box: Box)
	local spot = spotOf(box)
	local readyAt = box.ReadyAt
	if spot == nil or readyAt == nil then
		return
	end
	clearShown(session, boxUid)
	local base = floorFrame(session.plot, worldOf(session.plot, spot))
	local model, anchor = buildBoxModel(player, boxUid, box, base)
	local shown: Shown = {
		model = model,
		label = buildTimer(anchor, base),
		base = base,
		readyAt = readyAt,
		ready = false,
		text = nil,
	}
	session.shown[boxUid] = shown
	model.Parent = session.plot
	local remaining = readyAt - serverNow()
	if remaining <= 0 then
		markReady(player, boxUid, shown)
	else
		model:SetAttribute(STATE_ATTRIBUTE, "Waiting")
		setLabel(shown, timerText(remaining))
	end
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

-- Point du sol de SA boutique où poser un colis, sous le point visé `aim` (règle de l'en-tête) ; nil
-- et la clé du message de refus sinon. Sans yield.
local function findFloor(player: Player, session: Session, data: Data, aim: Vector3): (Vector3?, string?)
	local plot = session.plot
	local bounds = boundsOf(plot)
	if bounds == nil then
		warnOnce(`bounds:{plot:GetFullName()}`, `{plot:GetFullName()} : pas de {BOUNDS} (contrat 10.4), aucun colis ne s'y pose`)
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
	for _, box in data.Boxes do
		local spot = spotOf(box)
		if spot and (worldOf(plot, spot) - point).Magnitude < Unbox.BoxSpacing then
			return nil, "Blocked"
		end
	end
	-- Vague 31 : les objets sous antivol posés au sol gardent la même place qu'un colis.
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

-- Fait avancer les minuteurs ; BoxReady au propriétaire quand l'attente est écoulée.
local function advanceTimers()
	local now = serverNow()
	for player, session in sessions do
		for boxUid, shown in session.shown do
			if not shown.ready then
				local remaining = shown.readyAt - now
				if remaining <= 0 then
					markReady(player, boxUid, shown)
				else
					setLabel(shown, timerText(remaining))
				end
			end
		end
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

-- Vague 31 (L-112, Features.ShelfOpen) : l'objet sorti d'un colis ouvert sur le rayon (payload NPCItem,
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
		AntiTheft = true,
	}
	local heists = countHeist(player, data) -- d'un seul tenant avec l'objet : sauvegardés ensemble
	log(`{player.Name} : objet {def.Id} ({def.Rarity}) rangé sous antivol ({itemUid} ; braquages réussis : {heists or "?"})`)
	notify(player, MESSAGES.ItemStowed, SUCCESS_KIND)
	-- Arrivée en zone safe (UI_Escape, L-095 point 4) : même remote que le colis, icône de sa rareté (V0).
	local secured, securedErr = pcall(function()
		Net.Server.BoxSecured:Fire(player, "Standard", def.Rarity)
	end)
	if not secured then
		warn(`[UnboxService] BoxSecured vers {player.Name} : {securedErr}`)
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
	if type(payload) == "table" and payload.Kind == NPC_ITEM_KIND and Features.ShelfOpen then
		stowItem(player, data, payload)
		return
	end
	if type(payload) ~= "table" or payload.Kind ~= NPC_BOX_KIND then
		return
	end
	local problem = checkContent(payload)
	if problem then
		warn(`[UnboxService] {player.Name} : colis porté mal formé ({problem}), rendu à son rayon`)
		CarryService.Fail(player, "Invalid")
		return
	end
	if type(data.Boxes) ~= "table" then
		warnOnce(`boxes:{player.UserId}`, `{player.Name} : Boxes illisible dans le profil, colis gardé sur la tête`)
		return
	end
	local stored = countBoxes(data)
	if stored >= Unbox.BoxInventoryMax then
		log(`{player.Name} : {stored} colis dans l'inventaire, le colis porté revole vers son rayon`)
		notify(player, MESSAGES.BoxesFull)
		CarryService.Fail(player, "InventoryFull")
		return
	end
	local itemRarity = Items.ById[payload.ItemId].Rarity
	if itemRarity ~= payload.Rarity then
		warn(`[UnboxService] {player.Name} : colis {payload.Rarity} qui contient un objet {itemRarity} : tirage à corriger (StoreHeistService)`)
	end
	-- Anti-triche (DEV-060), juste avant la réussite : le dernier déplacement (téléport chez soi) et
	-- le trajet depuis la prise (speed hack), sans attendre le contrôle suivant. Sanctionné : le colis
	-- vient de revoler vers son rayon (CarryService.ReportAnomaly), rien n'est rangé.
	if not verifyCarry(player, payload) then
		log(`{player.Name} : colis pas rangé, déplacement sanctionné par l'anti-triche (colis rendu)`)
		return
	end
	if CarryService.Consume(player) == nil then
		log(`{player.Name} : colis pas rangé, CarryService.Consume n'a rien rendu`)
		return
	end
	-- Consume ne devrait pas yield ; s'il l'a fait, le profil a pu partir entre-temps.
	if DataService.Get(player) ~= data then
		warn(`[UnboxService] {player.Name} : profil perdu pendant le rangement, colis perdu`)
		return
	end
	local box: Box = {
		Tier = payload.Tier,
		Zone = payload.Zone,
		ItemId = payload.ItemId,
		Rarity = payload.Rarity,
		ReadyAt = nil,
		Mutation = Mutations.Sanitize(payload.Mutation), -- DEV-131 : absente du profil sans mutation
		Spot = nil,
		At = os.time(),
	}
	local boxUid = newUid(data.Boxes)
	data.Boxes[boxUid] = box
	local heists = countHeist(player, data) -- d'un seul tenant avec le colis : sauvegardés ensemble
	log(`{player.Name} : colis {box.Tier} {box.Rarity} rangé dans l'inventaire ({boxUid} ; braquages réussis : {heists or "?"})`)
	-- Réussite (L-095 point 3) : message en vert dans UI_Toast ; arrivée en zone safe côté client (point 4).
	notify(player, MESSAGES.Stowed, SUCCESS_KIND)
	local secured, securedErr = pcall(function()
		Net.Server.BoxSecured:Fire(player, box.Tier, box.Rarity) -- rareté : icône ICON_BOX_<Rareté> (L-097 point 3)
	end)
	if not secured then
		warn(`[UnboxService] BoxSecured vers {player.Name} : {securedErr}`)
	end
	refreshInventory(player)
	emit(stowedListeners, player, boxUid, box)
end

-- Porteurs de colis PNJ entrés dans la zone safe : leur colis va dans l'inventaire.
local function stowArrivals()
	for _, player in Players:GetPlayers() do
		if CarryService.IsCarrying(player) then
			local root = rootOf(player)
			if root and isInSafeZone(root.Position) then
				local ok, err = pcall(stow :: any, player) -- :: any : idem
				if not ok then
					warn(`[UnboxService] rangement du colis de {player.Name} : {err}`)
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
	for boxUid in session.shown do
		clearShown(session, boxUid)
	end
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
	if not Features.ShelfOpen or type(data.Items) ~= "table" then
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

-- Profil chargé et parcelle attribuée : remet les colis posés à leur place. Sans yield, appelable
-- plusieurs fois (profil chargé, parcelle attribuée).
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
	local session: Session = { plot = plot, slots = slots, shown = {}, items = {}, states = {} }
	sessions[player] = session
	restoreItems(player, session, data)

	if type(data.Boxes) ~= "table" then
		warn(`[UnboxService] {player.Name} : Boxes absent ou illisible ({tostring(data.Boxes)}) : aucun colis affiché`)
		refreshStates(player)
		return
	end
	local bounds = boundsOf(plot)
	local restored, returned, stored = 0, 0, 0
	for boxUid, box in table.clone(data.Boxes) do
		if type(box) ~= "table" or box.Spot == nil then
			stored += 1
			continue
		end
		local problem = checkPlaced(box)
		local spot = spotOf(box)
		if problem == nil and spot then
			problem = placedProblem(session, bounds, worldOf(plot, spot))
		end
		if problem then
			-- Jamais perdu : retour dans l'inventaire, l'heure promise gardée si elle est lisible.
			box.Spot = nil
			if not isFinite(box.ReadyAt) then
				box.ReadyAt = nil
			end
			returned += 1
			warn(`[UnboxService] {player.Name} : colis posé {boxUid} ({problem}) : revient dans l'inventaire`)
		else
			showBox(player, session, boxUid, box)
			restored += 1
		end
	end
	if returned > 0 then
		notify(player, MESSAGES.BackToInventory, INFO_KIND)
		refreshInventory(player)
	end
	refreshStates(player)
	log(`{player.Name} : {restored} colis remis au sol, {returned} revenu(s) dans l'inventaire, {stored + returned} dans l'inventaire`)
end

------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------

-- Vague 31 (L-112) : PlaceBox(itemUid, point) d'un objet sous antivol de l'inventaire. Mêmes règles que
-- la pose d'un colis (sa boutique, mains vides, findFloor, Unbox.MaxPlacedBoxes colis et objets au sol) ;
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
	local _, placedBoxes = countBoxes(data)
	local placed = placedBoxes + countFloorItems(data)
	if placed >= Unbox.MaxPlacedBoxes then
		log(`{player.Name} : {what} refusé : {placed} colis et objets déjà au sol`)
		notify(player, MESSAGES.ItemTooMany)
		return
	end
	local floor, why = findFloor(player, session, data, point)
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
-- le reprend ; il n'est plus sous antivol et va sur le présentoir libre le plus proche (DisplayService.PlaceAuto,
-- le chemin existant), sinon dans l'inventaire. Même portée que l'ouverture d'un colis.
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
	-- D'un seul tenant : l'objet redevient un objet libre de l'inventaire, puis va sur un présentoir.
	entry.AntiTheft = nil
	entry.UnlockAt = nil
	entry.Spot = nil
	clearShownItem(session, itemUid)
	local name = itemNameOf(entry)
	local ok, slot = pcall(DisplayService.PlaceAuto, player, itemUid, where)
	if ok and type(slot) == "number" then
		notify(player, string.format(MESSAGES.ItemToStand, name), SUCCESS_KIND)
		log(`{player.Name} : objet {itemUid} repris du sol, exposé sur le présentoir {slot}`)
	else
		if not ok then
			warn(`[UnboxService] DisplayService.PlaceAuto ({player.Name}, {itemUid}) : {slot}`)
		end
		notify(player, string.format(MESSAGES.ItemBack, name), INFO_KIND)
		log(`{player.Name} : objet {itemUid} repris du sol, dans l'inventaire (présentoirs pleins)`)
	end
	refreshInventory(player)
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
	local box = if type(data.Boxes) == "table" then data.Boxes[boxUid] else nil
	if type(box) ~= "table" then
		local entry = if type(data.Items) == "table" then data.Items[boxUid] else nil
		if isAntiTheft(entry) then
			placeFloorItem(player, data, session, boxUid, entry, point)
			return
		end
		log(`{player.Name} : PlaceBox({boxUid}) refusé : aucun colis de ce nom`)
		return
	end
	if box.Spot ~= nil then
		log(`{player.Name} : PlaceBox({boxUid}) refusé : colis déjà posé`)
		return
	end
	local problem = checkContent(box)
	if problem then
		warn(`[UnboxService] {player.Name} : colis {boxUid} illisible ({problem}), PlaceBox refusé`)
		return
	end
	if CarryService.IsCarrying(player) then
		log(`{player.Name} : PlaceBox({boxUid}) refusé : porte déjà quelque chose`)
		return
	end
	local _, placedBoxes = countBoxes(data)
	local placed = placedBoxes + countFloorItems(data) -- vague 31 : objets sous antivol au sol compris (0 sans eux)
	if placed >= Unbox.MaxPlacedBoxes then
		log(`{player.Name} : PlaceBox({boxUid}) refusé : {placed} colis déjà posés`)
		notify(player, MESSAGES.TooMany)
		return
	end
	local floor, why = findFloor(player, session, data, point)
	if floor == nil then
		local key = why or "NotFloor"
		log(`{player.Name} : PlaceBox({boxUid}) refusé : {key}`)
		notify(player, (MESSAGES :: any)[key] or MESSAGES.NotFloor)
		return
	end
	-- D'un seul tenant, sans yield : le colis quitte l'inventaire en se posant.
	local readyAt = serverNow() + openDelay(player, box)
	local promised = box.ReadyAt
	if isFinite(promised) and (promised :: number) < readyAt then
		readyAt = promised :: number -- heure déjà promise (migration v7) : aucune attente perdue
	end
	box.ReadyAt = readyAt
	box.Spot = spotFrom(session.plot, floor)
	showBox(player, session, boxUid, box)
	refreshInventory(player)
	log(`{player.Name} : colis {box.Tier} {box.Rarity} posé au sol ({boxUid}), prêt dans {string.format("%.1f", math.max(0, readyAt - serverNow()))} s`)
	emit(placedListeners, player, boxUid, box)
end

local function onOpenBox(player: Player, boxUid: string)
	local data = DataService.Get(player)
	local session = sessions[player]
	if data == nil or session == nil or not ownsPlot(player, session.plot) then
		log(`{player.Name} : OpenBox({boxUid}) refusé : profil ou parcelle pas encore prêts`)
		return
	end
	local box = if type(data.Boxes) == "table" then data.Boxes[boxUid] else nil
	local shown = session.shown[boxUid]
	if type(box) ~= "table" then
		local entry = if type(data.Items) == "table" then data.Items[boxUid] else nil
		if isAntiTheft(entry) then
			takeFloorItem(player, session, boxUid, entry)
			return
		end
	end
	if type(box) ~= "table" or box.Spot == nil or shown == nil then
		log(`{player.Name} : OpenBox({boxUid}) refusé : aucun colis posé de ce nom`)
		return
	end
	local where = shown.base.Position
	if not inReach(player, where) then
		log(`{player.Name} : OpenBox({boxUid}) refusé : trop loin du colis (plus de {REACH} studs)`)
		return
	end
	local readyAt = box.ReadyAt
	if readyAt == nil or not isFinite(readyAt) or serverNow() < readyAt then
		log(`{player.Name} : OpenBox({boxUid}) refusé : attente pas écoulée`)
		notify(player, MESSAGES.NotReady)
		return
	end
	local problem = checkContent(box)
	if problem then
		warn(`[UnboxService] {player.Name} : colis {boxUid} illisible ({problem}), ouverture refusée`)
		return
	end
	-- L-089 point 3 : l'objet va dans l'inventaire ; plein, sur un présentoir libre ; sinon, refus.
	local roomOk, inventoryRoom = pcall(DisplayService.HasInventoryRoom, player)
	local toInventory = roomOk and inventoryRoom == true
	if not toInventory then
		local ok, room = pcall(DisplayService.HasRoom, player)
		if not (ok and room == true) then
			log(`{player.Name} : OpenBox({boxUid}) refusé : inventaire et présentoirs pleins`)
			notify(player, MESSAGES.InventoryFull)
			return
		end
	end

	-- Amélioration du colis (en-tête) : le serveur décide des crans et de l'objet avant tout envoi.
	local startRarity = box.Rarity
	local steps = rollUpgrades(box, luckOf(player, box), random)
	local itemId = box.ItemId
	local finalRarity = startRarity
	if #steps > 0 then
		local target = steps[#steps]
		local picked = Items.Pick(box.Zone, target :: Rarities.RarityId, random)
		if picked ~= nil and picked.Rarity == target then
			itemId, finalRarity = picked.Id, target
		else
			warn(`[UnboxService] {player.Name} : amélioration en {target} sans objet tirable en zone {box.Zone}, colis ouvert sans cran`)
			table.clear(steps)
		end
	end

	-- Mutation du colis (DEV-131) : elle passe à l'objet, même amélioré (rareté et mutation sont
	-- indépendantes) ; jamais sur un objet TutorialOnly (le colis du tuto n'en a pas : garde-fou).
	local finalItem = Items.ById[itemId]
	local mutation = if finalItem and finalItem.TutorialOnly then nil else Mutations.Sanitize(box.Mutation)
	local revealAt = revealDelayFor(finalRarity, #steps)

	-- D'un seul tenant, sans yield : l'objet entre dans Items quand le colis quitte Boxes.
	local uid = newUid(data.Items)
	-- Zone gardée pour le revenu du Secret, qui n'a pas de zone au catalogue (DisplayService la lit).
	data.Items[uid] = { Id = itemId, Source = "NPC", At = os.time(), Zone = box.Zone, Mutation = mutation }
	data.Boxes[boxUid] = nil
	clearShown(session, boxUid)
	-- L'objet n'arrive dans l'inventaire qu'à la révélation (5.7 : son nom en dirait trop).
	local inventory = InventoryService
	if inventory then
		local held, err = pcall(inventory.HoldBack :: any, player, uid, revealAt) -- :: any : idem
		if not held then
			warn(`[UnboxService] InventoryService.HoldBack ({player.Name}) : {err}`)
		end
	end

	-- 5.7 : l'identité de l'objet ne part vers le client qu'ici, avec ce qu'il faut pour jouer les
	-- crans et composer le rouleau, et sa mutation (nom et revenu de l'écran d'ouverture). Sans mutation,
	-- les deux derniers arguments (facultatifs) ne partent pas.
	if mutation then
		Net.Server.UnboxReveal:Fire(player, boxUid, uid, itemId, box.Zone, box.Tier, startRarity, #steps, mutation.Size, mutation.Effect)
	else
		Net.Server.UnboxReveal:Fire(player, boxUid, uid, itemId, box.Zone, box.Tier, startRarity, #steps)
	end
	local upgraded = if #steps > 0 then `, {#steps} cran(s) : {startRarity} → {table.concat(steps, " → ")}` else ""
	local mutated = Mutations.Label(mutation)
	log(`{player.Name} : colis {boxUid} ouvert, {itemId} ({finalRarity}){upgraded}, uid {uid}{if mutated then ", mutation " .. mutated else ""}`)
	announce(player, itemId, finalRarity, #steps)

	if toInventory then
		log(`{player.Name} : {itemId} dans l'inventaire (montré dans {string.format("%.1f", revealAt)} s)`)
	else
		local ok, result = pcall(DisplayService.PlaceAuto, player, uid, where)
		if not ok then
			warn(`[UnboxService] DisplayService.PlaceAuto ({player.Name}, {uid}) : {result}`)
		elseif type(result) == "number" then
			local name = if finalItem then finalItem.DisplayName else itemId
			notifyLater(player, string.format(MESSAGES.ToStand, name), INFO_KIND, revealAt)
			log(`{player.Name} : inventaire plein, {itemId} exposé sur le présentoir {result}`)
		else
			log(`{player.Name} : inventaire plein et aucun présentoir pour {itemId} : il reste dans Items`)
		end
	end
	refreshInventory(player)
	refreshStates(player)

	for _, listener in table.clone(openedListeners) do
		task.spawn(listener, player, boxUid, uid, itemId, revealAt)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function UnboxService.GetOpenDelay(_player: Player, box: Box): number
	return Rarities.ById[box.Rarity].OpenDelay
end

-- Vague 31 (L-112) : durée de l'antivol d'un objet posé au sol (ShelfOpen.AntiTheft[rareté]) ; remplaçable
-- comme GetOpenDelay (MonetizationService : Fast Open × DelayFactor). Ne doit pas yield.
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

function UnboxService.OnBoxStowed(listener: BoxListener): () -> ()
	return subscribe(stowedListeners, listener)
end

function UnboxService.OnBoxPlaced(listener: BoxListener): () -> ()
	return subscribe(placedListeners, listener)
end

function UnboxService.OnBoxOpened(listener: OpenedListener): () -> ()
	return subscribe(openedListeners, listener)
end

function UnboxService.GetBoxPosition(player: Player, boxUid: string): Vector3?
	local session = sessions[player]
	local shown = if session then session.shown[boxUid] else nil
	return if shown then shown.base.Position else nil
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

-- Rareté d'un colis offert (GiveBox) : tirée avec les poids de OddsFor(zone, tier), seulement parmi les
-- raretés d'ordre ≥ minOrder qui ont un objet (Items.Pick : Secrets et Divins, toutes zones). nil si aucune.
local function drawGiftRarity(zone: number, tier: string, minOrder: number): string?
	local total = 0
	local weights: { [string]: number } = {}
	for _, rarity in Rarities.List do
		local weight = oddsOf(zone, tier, rarity.Id)
		local allZones = Items.AllZones[rarity.Id]
		local possible = if allZones ~= nil then #allZones > 0 else hasItem(zone, rarity.Id)
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

function UnboxService.GiveBox(player: Player, tier: string, zone: number, minRarity: string?): (string?, string?)
	local data = DataService.Get(player)
	if data == nil or type(data.Boxes) ~= "table" then
		return nil, "NoProfile"
	end
	local minimum = if minRarity ~= nil then Rarities.ById[minRarity] else nil
	if Balance.Heist.BoxTiers[tier] == nil or Zones[zone] == nil or (minRarity ~= nil and minimum == nil) then
		warn(`[UnboxService] GiveBox ({player.Name}) : colis {tostring(tier)} zone {tostring(zone)} rareté {tostring(minRarity)} inconnu`)
		return nil, "Invalid"
	end
	local stored = countBoxes(data)
	if stored >= Unbox.BoxInventoryMax then
		log(`{player.Name} : {stored} colis dans l'inventaire, colis offert {tier} pas donné`)
		return nil, "InventoryFull"
	end
	local rarityId = drawGiftRarity(zone, tier, if minimum then minimum.Order else 0)
	local item = if rarityId then Items.Pick(zone, rarityId :: Rarities.RarityId, random) else nil
	if rarityId == nil or item == nil then
		warnOnce(`gift.{tier}.{zone}.{tostring(minRarity)}`, `colis offert {tier} zone {zone} (au moins {tostring(minRarity)}) : aucune rareté possible (Config)`)
		return nil, "NoContent"
	end
	local box: Box = {
		Tier = tier :: any,
		Zone = zone,
		ItemId = item.Id,
		Rarity = rarityId,
		ReadyAt = nil,
		Mutation = if item.TutorialOnly then nil else Mutations.Roll(random), -- comme la mise en rayon (DEV-131)
		Spot = nil,
		At = os.time(),
	}
	local boxUid = newUid(data.Boxes)
	data.Boxes[boxUid] = box
	log(`{player.Name} : colis offert {tier} {rarityId} (zone {zone}) mis dans l'inventaire ({boxUid})`)
	refreshInventory(player)
	return boxUid, nil
end

function UnboxService.GetWaiting(player: Player): { [string]: number }
	local waiting: { [string]: number } = {}
	local session = sessions[player]
	if session == nil then
		return waiting
	end
	local now = serverNow()
	for boxUid, shown in session.shown do
		if not shown.ready and shown.readyAt > now then
			waiting[boxUid] = shown.readyAt
		end
	end
	-- Vague 31 (Cantin, 2026-11-12) : un objet sous antivol au sol (pas porté par un voleur) attend aussi.
	for itemUid, item in session.items do
		if not item.held and not item.unlocked and item.unlockAt > now then
			waiting[itemUid] = item.unlockAt
		end
	end
	return waiting
end

-- Vague 31 : SkipWait sur un objet sous antivol posé au sol (même règle que pour un colis).
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
	local shown = session.shown[boxUid]
	local box = if type(data.Boxes) == "table" then data.Boxes[boxUid] else nil
	if shown == nil or shown.ready or type(box) ~= "table" or not isFinite(box.ReadyAt) then
		return nil
	end
	local now = serverNow()
	local current = box.ReadyAt :: number
	if current <= now then
		return nil -- déjà prêt : la boucle le marque au prochain pas
	end
	local readyAt = math.max(now, current - seconds)
	box.ReadyAt = readyAt
	shown.readyAt = readyAt
	shown.model:SetAttribute(READY_AT_ATTRIBUTE, readyAt)
	local left = readyAt - now
	if left <= 0 then
		markReady(player, boxUid, shown)
		left = 0
	else
		setLabel(shown, timerText(left))
	end
	log(`{player.Name} : attente du colis {boxUid} réduite de {string.format("%.1f", seconds)} s, reste {string.format("%.1f", left)} s`)
	return left
end

function UnboxService.Init()
	Net.Server.PlaceBox:Connect(onPlaceBox)
	Net.Server.OpenBox:Connect(onOpenBox)

	-- Les colis reviennent quand le profil est chargé ET la parcelle attribuée (PlotService attend le
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

	-- Où et quand le portage du colis a commencé (contrôle du trajet au rangement, DEV-060).
	CarryService.OnCarryStarted(function(player: Player, payload: any)
		local root = rootOf(player)
		if root and type(payload) == "table" and (payload.Kind == NPC_BOX_KIND or payload.Kind == NPC_ITEM_KIND) then
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
