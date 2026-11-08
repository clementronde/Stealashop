--!strict
-- UnboxService (DEV-019, L-086) : colis posés et ouverts sur les présentoirs, attente selon la
-- rareté, ouverture des colis PNJ (Partie 1, sections 5.6, 5.7, 5.8, 7.3, 9.4 et 9.5).
--
-- Décision de Clément du 2026-11-08 (liaison L-086) : plus d'établis ni de coffre dans la boutique.
-- Le joueur pose son colis sur un présentoir libre et débloqué (DisplaySlot_xx, contrat 10.4), le
-- colis attend là, s'ouvre là, puis l'objet reste exposé sur ce même présentoir.
--
-- Rôle :
--   - Présentoirs : ceux de la parcelle du joueur, tels que DisplayService les trouve et les juge
--     (DisplayService.GetSlots, GetSlotStates : débloqués = StartSlots + niveau DisplaySlots, plus les
--     présentoirs bonus de la boutique Robux). Un présentoir qui porte un colis en attente compte comme
--     occupé pour DisplayService : aucun objet ne s'y pose, et rien n'y est volable (les colis ne sont
--     pas volables, 6.1). L'ancienne amélioration « Workbenches » (Upgrades.UnboxBenches) ne sert plus
--     à rien : le nombre de colis ouverts en même temps n'est limité que par les présentoirs libres.
--   - PlaceBox(slotIndex) : le joueur pose le colis PNJ qu'il porte sur un présentoir débloqué et
--     libre (ni objet ni colis) de sa parcelle, à portée. Juste avant, AntiCheatService.Verify
--     (DEV-060) contrôle tout de suite son dernier déplacement (téléport chez lui, colis sur la tête)
--     et le trajet depuis le point où ce portage a commencé (OnCarryStarted : au rayon, ou là où il a
--     ramassé le colis au sol) : sanctionné, le colis vient de revoler vers son rayon et rien n'est
--     posé. Puis CarryService.Consume le lui retire et le colis est écrit dans le profil :
--     Boxes["<n>"] = { Tier, Zone, ItemId, Rarity, ReadyAt, Mutation? } (9.5, profil v5 : clé = numéro du
--     présentoir en texte, Types/Profile), avec ReadyAt = heure serveur + attente de sa rareté
--     (table 7.3, Config.Rarities[..].OpenDelay).
--   - Présentoirs pleins (DisplayService garde la règle) : sans présentoir libre et débloqué, pas de
--     pose ; le joueur qui porte un colis près de ses présentoirs reçoit un Notify (MESSAGES.StandsFull)
--     une fois par colis porté, et PlaceBox sur un présentoir pris lui renvoie le même message.
--   - Braquage réussi : Lifetime.Heists + 1 dans le profil (9.5) au même moment, d'un seul tenant
--     avec l'écriture du colis. Un braquage réussit quand le colis volé arrive sur le présentoir (5.6
--     « Arrivée », 14.2 étape 6, réussite « Consumed » de Types/Carry) : avant, le colis peut
--     encore retourner sur son rayon (rattrapé, mort, départ, anomalie : 5.5, 5.6) ou tomber au
--     sol (coup de batte, 6.2). Une seule fois par colis : un colis n'est consommé qu'une fois.
--     Celui qui ramasse un colis tombé au sol et le pose compte le braquage, pas celui qui l'a
--     perdu.
--   - L'attente est horodatée : elle continue hors ligne et d'un serveur à l'autre. Au retour du
--     joueur (profil chargé et parcelle attribuée), ses colis réapparaissent sur leurs présentoirs, et
--     BoxReady part pour ceux qui sont déjà prêts.
--   - File des colis à poser (BoxQueue, profil v5) : un colis qui n'a pas de présentoir (migration
--     v4 → v5 sans place libre, ou présentoir absent de la parcelle au retour du joueur) y attend, sans
--     jamais être perdu. Dès qu'un présentoir débloqué se libère, le plus ancien y est posé tout seul
--     (contrôle une fois par seconde), avec son ReadyAt d'origine, et le joueur est prévenu
--     (MESSAGES.QueuePlaced). Pas de nouveau braquage compté : il l'a été à la première pose.
--   - Attente écoulée : BoxReady(slotIndex) au propriétaire.
--   - OpenBox(slotIndex) : attente écoulée (heure serveur), joueur sur sa parcelle, à portée du
--     présentoir → amélioration du colis tirée (plus bas), nouvel objet dans Items sous un uid unique
--     ({ Id = ItemId, Source = "NPC", At = os.time(), Zone, Mutation? : celle du colis, DEV-131 }), le colis quitte Boxes,
--     UnboxReveal(slotIndex, itemUid, itemId, zone, tier, startRarity, upgrades, mutationSize?,
--     mutationEffect?) au joueur, puis
--     DisplayService.PlaceItem(player, itemUid, slotIndex) : l'objet est exposé sur ce même présentoir
--     et rapporte tout de suite.
--   - Cas d'erreur (le présentoir ne peut plus prendre l'objet : présentoir bonus dont le gamepass
--     n'est plus possédé, boutique pas encore installée par DisplayService) : l'objet va sur le
--     présentoir libre le plus proche (DisplayService.PlaceAuto), sinon dans l'inventaire, et le joueur
--     reçoit un Notify (MESSAGES.ToInventory, catégorie « Info ») au moment où l'objet se révèle chez
--     lui, pas avant (le nom de l'objet ne doit pas arriver avant la révélation). Dans ce cas seulement,
--     l'ouverture est refusée si l'objet n'aurait ni présentoir ni place dans l'inventaire.
--   - L'objet exact reste caché jusqu'à l'ouverture (5.7) : l'ItemId ne quitte le serveur que dans
--     UnboxReveal. Aucun attribut, nom ni modèle d'objet ne le montre avant.
--
-- Amélioration du colis (DEV-050, étape 0 de la spec ouverture-colis, règle nouvelle de Clément du
-- 2026-11-07, valeurs dans Config.Unbox) : à OpenBox, avant tout envoi, jusqu'à UpgradeMax (2)
-- crans ; chaque cran réussit avec UpgradeChance (10 %) × la chance du joueur (GetLuck, 1 par
-- défaut ; probabilité bornée à 1) et fait monter le colis d'une rareté, dans l'ordre de
-- Rarities.List (Commun → Peu commun → Rare). Un cran n'est tenté que si la rareté visée :
--   - n'est pas Secret ;
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
-- mais lue avec Workspace:GetServerTimeNow(), précise au millième : avec os.time(), entier, un
-- colis pouvait s'ouvrir jusqu'à 1 s trop tôt. Le client lit la même horloge.
--
-- Dans le monde (visible par tous, rien de secret : la rareté se voit dès qu'on soulève le colis,
-- 5.6) :
--   - sur le présentoir, une copie du modèle BOX_<Tier> de Clément (cherché dans
--     ReplicatedStorage/Assets, puis ServerStorage/Assets), sa pièce Tint teinte à la couleur de la
--     rareté ; sans lui, un bloc V0 de cette couleur. La copie s'appelle StandBox_<nn> (sans le préfixe
--     BOX_, pour que le ContractChecker ne la prenne pas pour un modèle livré), est rangée dans la
--     parcelle et porte les attributs Rarity et ReadyAt. Son pivot (en bas au centre, 10.1) se pose sur
--     l'Attachment DisplaySlot_xx, là où DisplayService posera l'objet ;
--   - au-dessus, le minuteur : copie de BB_OpenTimer (ReplicatedStorage/Assets/UI, élément Label),
--     accrochée au pied du colis (le dessus du présentoir, où se pose son pivot : le
--     StudsOffsetWorldSpace de Clément part de là, liaison L-027), sinon un billboard V0. Le serveur
--     y écrit le temps restant (m:ss), puis « Ready! » ;
--   - attribut UnboxState sur chaque DisplaySlot_xx d'une parcelle attribuée, lu par UnboxController :
--     "Locked" (pas encore débloqué), "Free" (ni objet ni colis), "Taken" (un objet exposé, ou volé
--     en ce moment), "Waiting" (colis en attente), "Ready" (colis prêt). Remis à jour 4 fois par
--     seconde (un objet posé ou retiré par DisplayService, un présentoir acheté) ; retiré quand la
--     parcelle se libère.
--
-- Remotes : PlaceBox et OpenBox (client → serveur, forme et débit déjà contrôlés par Net) ;
-- BoxReady, UnboxReveal et Notify (serveur → client).
--
-- API (côté serveur) :
--   UnboxService.Refresh(player)
--       Recalcule tout de suite l'attribut UnboxState des présentoirs (après l'achat d'un présentoir,
--       ShopService) ; sinon la boucle le fait au plus 0,25 s plus tard. PlaceBox relit toujours le
--       profil : ce n'est que l'affichage côté client qui attend ce rafraîchissement.
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
--   UnboxService.OnBoxPlaced(listener) -> déconnexion
--       listener(player, slotIndex, box) après chaque colis posé par le joueur (tutoriel,
--       télémétrie ; pas pour un colis de la file posé tout seul). box est une copie du colis
--       sauvegardé, ItemId compris : ne jamais l'envoyer à un client.
--   UnboxService.OnBoxOpened(listener) -> déconnexion
--       listener(player, slotIndex, itemUid, itemId, revealDelay) après chaque ouverture (tutoriel,
--       télémétrie, index des objets) ; itemId = l'objet final, après l'amélioration ; revealDelay =
--       secondes jusqu'à l'objet révélé chez celui qui ouvre (le délai de l'annonce et du message de
--       l'inventaire), pour un message qui ne doit pas arriver avant la révélation (DEV-111).
--   Boutique Robux (DEV-100, MonetizationService : « Ouvrir maintenant », « Ouverture rapide ») :
--   UnboxService.GetWaiting(player) -> { [number]: number }
--       Colis du joueur pas encore prêts, affichés sur leurs présentoirs : [numéro de présentoir] =
--       heure serveur (ReadyAt) où chacun le sera. Vide sans colis en attente.
--   UnboxService.SkipWait(player, slotIndex, seconds) -> number?
--       Avance de `seconds` (au plus jusqu'à maintenant) l'heure d'ouverture du colis en attente sur
--       ce présentoir, dans le profil et sur le présentoir ; renvoie l'attente restante (0 = prêt :
--       BoxReady part tout de suite), nil s'il n'y a pas de colis en attente sur ce présentoir. Sans
--       yield.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local ShelfBoxes = require(Shared.Config.ShelfBoxes)
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
type StandState = "Locked" | "Free" | "Taken" | "Waiting" | "Ready"

-- Ce qu'UnboxService utilise de CarryService (a11) et de DisplayService (a14, a46). Payload d'un colis
-- PNJ : { Kind = "NPCBox", Tier, Zone, Rarity, ItemId, StoreId, SlotId }.
type CarryApi = {
	IsCarrying: (player: Player) -> boolean,
	GetPayload: (player: Player) -> any,
	Consume: (player: Player) -> any,
	OnCarryStarted: (listener: (player: Player, payload: any) -> ()) -> any,
	OnCarryEnded: (listener: (player: Player, payload: any, result: string, reason: string) -> ()) -> any,
}
type DisplayApi = {
	PlaceAuto: (player: Player, itemUid: string) -> number?,
	PlaceItem: (player: Player, itemUid: string, slotIndex: number) -> (boolean, string?),
	-- Place pour un objet de plus, présentoirs bonus de la boutique Robux compris (DEV-100).
	HasRoom: (player: Player) -> boolean,
	-- Présentoirs de la parcelle du joueur ([numéro] = Attachment DisplaySlot_xx, bonus posés compris)
	-- et leur état : "Free", "Locked", "Taken" (objet), "Boxed" (colis), "NoSlot" (L-086).
	GetSlots: (player: Player) -> { [number]: Attachment },
	GetSlotStates: (player: Player) -> { [number]: string },
}

local CarryService: CarryApi = require(script.Parent.CarryService) :: any
local DisplayService: DisplayApi = require(script.Parent.DisplayService) :: any

export type PlacedListener = (player: Player, slotIndex: number, box: Box) -> ()
export type OpenedListener = (player: Player, slotIndex: number, itemUid: string, itemId: string, revealDelay: number) -> ()

-- Colis affiché sur un présentoir.
type Shown = {
	model: Model,
	label: TextLabel?, -- texte du minuteur
	readyAt: number,
	ready: boolean,
	text: string?, -- dernier texte écrit dans le minuteur
}

-- Parcelle d'un joueur présent, telle que ce service l'affiche.
type Session = {
	plot: Model,
	slots: { [number]: Attachment }, -- présentoirs de la parcelle (DisplayService.GetSlots)
	shown: { [number]: Shown }, -- colis affichés, par présentoir
	states: { [number]: StandState? }, -- dernier UnboxState écrit sur chaque présentoir
	fullNotified: any, -- payload du colis porté pour lequel « présentoirs pleins » est déjà parti
	queueWarned: boolean, -- colis illisible de la file déjà signalé
}

-- Début du portage d'un colis PNJ (DEV-060), pour le contrôle du trajet à la pose : la table du
-- payload (celle de CarryService), la position du HumanoidRootPart et os.clock() à ce moment.
type CarryStart = { Payload: any, From: Vector3, At: number }

-- Contrat (10.3 et 2.2).
local BOX_PREFIX = "BOX_" -- BOX_Standard, BOX_Premium, BOX_Luxe
local TINT = "Tint" -- pièce du colis recolorée selon la rareté
local TIMER_BILLBOARD = "BB_OpenTimer"
local TIMER_LABEL = "Label"
-- Attribut de la parcelle posé par PlotService : UserId du propriétaire, 0 = libre.
local OWNER_ATTRIBUTE = "OwnerUserId"
-- payload.Kind d'un colis volé à un magasin PNJ (CarryService).
local NPC_BOX_KIND = "NPCBox"
-- Attributs posés par ce service (voir l'en-tête).
local STATE_ATTRIBUTE = "UnboxState"
local RARITY_ATTRIBUTE = "Rarity"
local READY_AT_ATTRIBUTE = "ReadyAt"
local BOX_MODEL_FORMAT = "StandBox_%02d"
local TIMER_NAME = "OpenTimer"
local TIMER_POINT = "TimerPoint"

-- V0 proposé, absent du doc : portée (studs) de l'invite d'un présentoir, la même que celle
-- d'UnboxController, et marge du serveur pour la gigue réseau. Le serveur accepte PlaceBox et
-- OpenBox jusqu'à PROMPT_DISTANCE + REACH_TOLERANCE entre le HumanoidRootPart et le présentoir.
-- Valeurs dans Config.Unbox, partagées avec le client (OpenNextButton suit la même règle).
local PROMPT_DISTANCE = Unbox.PromptDistance
local REACH_TOLERANCE = Unbox.ReachTolerance
-- V0 proposé, absent du doc : cadence (s) de la boucle qui fait avancer les minuteurs et remet à jour
-- UnboxState ; cadence (s) de la file des colis à poser et du message « présentoirs pleins ».
local TICK = 0.25
local SLOW_TICK = 1
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
	Locked = "This stand is locked: upgrade your Display Stands.",
	Busy = "This stand is already in use.",
	StandsFull = "All your stands are full: make room to place your box.",
	NotReady = "This box isn't ready yet.",
	InventoryFull = "Inventory full: display or sell an item before opening this box.",
	-- %s = nom de l'objet (Config.Items, DisplayName)
	ToInventory = "Your display stands are full: %s went to your inventory.",
	QueuePlaced = "Your waiting box is now on a free stand.",
}
-- Catégorie du Notify de l'inventaire et de la file : l'objet ou le colis est bien gardé.
local INFO_KIND = "Info"

local IS_STUDIO = RunService:IsStudio()
local REACH = PROMPT_DISTANCE + REACH_TOLERANCE

local UnboxService = {}

local sessions: { [Player]: Session } = {}
local placedListeners: { PlacedListener } = {}
local openedListeners: { OpenedListener } = {}
local carryStarts: { [Player]: CarryStart } = {}
local random = Random.new()

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[UnboxService] {message}`)
	end
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

-- Clé d'un présentoir dans Boxes : son numéro écrit en texte (Types/Profile).
local function slotKey(index: number): string
	return tostring(index)
end

-- File des colis à poser (v5) ; une file absente ou abîmée (Reconcile ne remplace pas une valeur du
-- mauvais type) est signalée et ignorée, jamais écrasée.
local function queueOf(data: Data): { Box }?
	local queue = (data :: any).BoxQueue
	return if type(queue) == "table" then queue else nil
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

-- checkContent, plus l'heure d'ouverture d'un colis sauvegardé.
local function checkSaved(box: any): string?
	local problem = checkContent(box)
	if problem == nil and (type(box.ReadyAt) ~= "number" or box.ReadyAt ~= box.ReadyAt) then
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

local function inReach(player: Player, slot: Attachment): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	return (root.Position - slot.WorldPosition).Magnitude <= REACH
end

-- État d'un présentoir selon DisplayService (voir DisplayApi), "NoSlot" s'il ne répond pas.
local function slotStates(player: Player): { [number]: string }
	local ok, states = pcall(DisplayService.GetSlotStates, player)
	if ok and type(states) == "table" then
		return states
	end
	warn(`[UnboxService] DisplayService.GetSlotStates ({player.Name}) : {tostring(states)}`)
	return {}
end

-- 5.8 : 30 objets non exposés au plus (Balance.Display.InventoryMax). Ne sert qu'au cas d'erreur de
-- l'ouverture (l'objet ne peut pas rester sur son présentoir) : DisplayService.HasRoom fait le compte
-- (présentoirs bonus compris ; un présentoir qui porte un colis compte comme occupé).
local function inventoryFull(player: Player): boolean
	local ok, room = pcall(DisplayService.HasRoom, player)
	return ok and room == false
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

local function newUid(data: Data): string
	local uid = HttpService:GenerateGUID(false)
	while data.Items[uid] ~= nil do
		uid = HttpService:GenerateGUID(false)
	end
	return uid
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

-- Raretés atteintes cran par cran (règle de l'en-tête). Rarities.List est rangée par Order (1 à 7) :
-- la rareté au-dessus de `r` est Rarities.List[r.Order + 1].
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
		if nextRarity == nil or nextRarity.Id == "Secret" then
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

-- Notify à `player` au moment où son objet se révèle chez lui (même délai que l'annonce) ; rien
-- s'il est parti entre-temps. Renvoie le délai.
local function notifyAtReveal(player: Player, message: string, kind: string, rarityId: string, upgrades: number): number
	local delay = revealDelayFor(rarityId, upgrades)
	task.delay(delay, function()
		if player.Parent == Players then
			notify(player, message, kind)
		end
	end)
	return delay
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
-- Colis affichés sur les présentoirs
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

-- Copie du modèle BOX_<tier> de Clément et la pièce qui portera le minuteur ; nil s'il n'est pas
-- encore livré.
local function cloneBoxTemplate(tier: string): (Model?, BasePart?)
	local template = findAsset(BOX_PREFIX .. tier)
	if template == nil or not template:IsA("Model") then
		return nil, nil
	end
	local model = (template :: Model):Clone() :: Model
	local anchor = model.PrimaryPart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
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

-- Modèle du colis posé sur le présentoir `index`, teint à la couleur de sa rareté, et la pièce qui
-- porte le minuteur.
local function buildBoxModel(index: number, box: Box, slotCFrame: CFrame): (Model, BasePart)
	local color = Rarities.ById[box.Rarity].Color
	local cloned, clonedAnchor = cloneBoxTemplate(box.Tier)
	local model: Model
	local anchor: BasePart
	if cloned and clonedAnchor then
		model, anchor = cloned, clonedAnchor
		local tint = Find.path(model, TINT)
		if tint ~= nil and tint:IsA("BasePart") then
			(tint :: BasePart).Color = color
		end
		model:PivotTo(slotCFrame) -- pivot en bas au centre (10.1), posé sur le présentoir
	else
		model = Instance.new("Model")
		local block = Instance.new("Part")
		block.Name = "Block"
		block.Size = V0_BOX_SIZE
		block.Color = color
		block.Material = Enum.Material.SmoothPlastic
		prepare(block)
		block.CFrame = slotCFrame * CFrame.new(0, V0_BOX_SIZE.Y / 2, 0)
		block.Parent = model
		model.PrimaryPart = block
		anchor = block
	end
	model.Name = string.format(BOX_MODEL_FORMAT, index)
	model:SetAttribute(RARITY_ATTRIBUTE, box.Rarity)
	model:SetAttribute(READY_AT_ATTRIBUTE, box.ReadyAt)
	return model, anchor
end

-- Minuteur au-dessus du colis : copie de BB_OpenTimer, accrochée au pied du colis (`base` : le
-- dessus du présentoir, où se pose le pivot du colis, avec ses axes ; le StudsOffsetWorldSpace de
-- Clément part de là, quelle que soit l'orientation de la pièce `anchor`) ; sinon billboard V0,
-- accroché au centre de son bloc. Renvoie son texte.
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
	warn(`[UnboxService] {TIMER_BILLBOARD} sans TextLabel « {TIMER_LABEL} » (contrat 2.2) : minuteur muet`)
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

-- UnboxState du présentoir `index` : son colis d'abord, puis ce qu'en dit DisplayService.
local function stateFor(session: Session, data: Data, index: number, displayState: string?): StandState?
	local shown = session.shown[index]
	if shown then
		return if shown.ready then "Ready" else "Waiting"
	end
	if data.Boxes[slotKey(index)] ~= nil or displayState == "Boxed" then
		return "Waiting" -- colis sauvegardé mais illisible (déjà signalé) : le présentoir reste occupé
	end
	if displayState == "Free" or displayState == "Locked" or displayState == "Taken" then
		return displayState :: StandState
	end
	return nil
end

local function refreshStates(player: Player)
	local session = sessions[player]
	local data = DataService.Get(player)
	if session == nil or data == nil then
		return
	end
	local states = slotStates(player)
	for index in session.slots do
		setState(session, index, stateFor(session, data, index, states[index]))
	end
end

-- Un présentoir débloqué de la parcelle est-il libre (ni objet ni colis) ?
local function hasFreeSlot(player: Player, session: Session, data: Data): boolean
	for index, state in slotStates(player) do
		if state == "Free" and session.slots[index] and data.Boxes[slotKey(index)] == nil then
			return true
		end
	end
	return false
end

local function markReady(player: Player, session: Session, index: number, shown: Shown)
	shown.ready = true
	setLabel(shown, READY_TEXT)
	setState(session, index, "Ready")
	Net.Server.BoxReady:Fire(player, index)
end

local function clearShown(session: Session, index: number)
	local shown = session.shown[index]
	if shown then
		session.shown[index] = nil
		shown.model:Destroy()
	end
end

-- Affiche le colis `box` sur le présentoir `index` ; BoxReady part tout de suite s'il est déjà prêt.
local function showBox(player: Player, session: Session, index: number, box: Box)
	local slot: Attachment? = session.slots[index]
	if slot == nil then
		return
	end
	clearShown(session, index)
	local model, anchor = buildBoxModel(index, box, slot.WorldCFrame)
	local shown: Shown = {
		model = model,
		label = buildTimer(anchor, slot.WorldCFrame),
		readyAt = box.ReadyAt,
		ready = false,
		text = nil,
	}
	session.shown[index] = shown
	model.Parent = session.plot
	local remaining = box.ReadyAt - serverNow()
	if remaining <= 0 then
		markReady(player, session, index, shown)
	else
		setLabel(shown, timerText(remaining))
		setState(session, index, "Waiting")
	end
end

-- File des colis à poser (en-tête) : pose les plus anciens sur les présentoirs débloqués libres, dans
-- l'ordre des numéros. Un colis illisible reste dans la file (signalé une fois). Sans yield.
local function drainQueue(player: Player, session: Session, data: Data)
	local queue = queueOf(data)
	if queue == nil or #queue == 0 then
		return
	end
	local free: { number } = {}
	for index, state in slotStates(player) do
		if state == "Free" and session.slots[index] and data.Boxes[slotKey(index)] == nil then
			table.insert(free, index)
		end
	end
	table.sort(free)
	local placed = 0
	local position = 1
	while position <= #queue and placed < #free do
		local box = queue[position]
		local problem = checkSaved(box)
		if problem then
			if not session.queueWarned then
				session.queueWarned = true
				warn(`[UnboxService] {player.Name} : colis n° {position} de la file illisible ({problem}) : gardé dans la file`)
			end
			position += 1
		else
			placed += 1
			local index = free[placed]
			table.remove(queue, position)
			data.Boxes[slotKey(index)] = box
			showBox(player, session, index, box)
			log(`{player.Name} : colis {box.Tier} {box.Rarity} de la file posé sur le présentoir {index} ({#queue} encore dans la file)`)
		end
	end
	if placed > 0 then
		notify(player, MESSAGES.QueuePlaced, INFO_KIND)
		refreshStates(player)
	end
end

-- Message « présentoirs pleins » au joueur qui porte un colis près de ses présentoirs sans place
-- libre, une fois par colis porté.
local function checkStandsFull(player: Player, session: Session, data: Data)
	if not CarryService.IsCarrying(player) then
		session.fullNotified = nil
		return
	end
	local payload = CarryService.GetPayload(player)
	if type(payload) ~= "table" or payload.Kind ~= NPC_BOX_KIND or session.fullNotified == payload then
		return
	end
	local root = rootOf(player)
	if root == nil then
		return
	end
	local near = false
	for _, slot in session.slots do
		if (root.Position - slot.WorldPosition).Magnitude <= PROMPT_DISTANCE then
			near = true
			break
		end
	end
	if near and not hasFreeSlot(player, session, data) then
		session.fullNotified = payload
		notify(player, MESSAGES.StandsFull)
		log(`{player.Name} : porte un colis, aucun présentoir libre`)
	end
end

-- Fait avancer tous les minuteurs ; BoxReady au propriétaire quand l'attente est écoulée.
local function advance()
	local now = serverNow()
	for player, session in sessions do
		for index, shown in session.shown do
			if not shown.ready then
				local remaining = shown.readyAt - now
				if remaining <= 0 then
					markReady(player, session, index, shown)
				else
					setLabel(shown, timerText(remaining))
				end
			end
		end
		refreshStates(player)
	end
end

-- File des colis et message des présentoirs pleins (une fois par seconde).
local function slowAdvance()
	for player, session in sessions do
		local data = DataService.Get(player)
		if data then
			drainQueue(player, session, data)
			checkStandsFull(player, session, data)
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
	for index in session.shown do
		clearShown(session, index)
	end
	for index, slot in session.slots do
		session.states[index] = nil
		slot:SetAttribute(STATE_ATTRIBUTE, nil)
	end
end

-- Profil chargé et parcelle attribuée : remet les colis sauvegardés sur leurs présentoirs. Sans
-- yield, appelable plusieurs fois (profil chargé, parcelle attribuée).
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
	local session: Session = {
		plot = plot,
		slots = slots,
		shown = {},
		states = {},
		fullNotified = nil,
		queueWarned = false,
	}
	sessions[player] = session

	local restored = 0
	local queue = queueOf(data)
	if queue == nil then
		warn(`[UnboxService] {player.Name} : BoxQueue absent ou illisible ({tostring((data :: any).BoxQueue)}) : file des colis inutilisable`)
	end
	for key, box in table.clone(data.Boxes) do
		local index = tonumber(key)
		local problem = checkSaved(box)
		local slot: Attachment? = if index then session.slots[index] else nil
		if problem then
			warn(`[UnboxService] {player.Name} : colis du présentoir {key} illisible ({problem}) : gardé dans le profil, non affiché`)
		elseif index == nil or slot == nil then
			-- Présentoir absent de cette parcelle : le colis passe dans la file, rien n'est perdu.
			if queue then
				data.Boxes[key] = nil
				table.insert(queue, box)
				warn(`[UnboxService] {player.Name} : colis sauvegardé sur le présentoir « {key} », absent de {plot:GetFullName()} : mis dans la file des colis à poser`)
			else
				warn(`[UnboxService] {player.Name} : colis sauvegardé sur le présentoir « {key} », absent de {plot:GetFullName()} : gardé dans le profil, non affiché`)
			end
		else
			showBox(player, session, index :: number, box)
			restored += 1
		end
	end
	drainQueue(player, session, data)
	refreshStates(player)
	local waiting = if queue then #queue else 0
	log(`{player.Name} : {restored} colis remis sur les présentoirs, {waiting} dans la file`)
end

------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------

local function onPlaceBox(player: Player, slotIndex: number)
	local data = DataService.Get(player)
	local session = sessions[player]
	if data == nil or session == nil or not ownsPlot(player, session.plot) then
		log(`{player.Name} : PlaceBox({slotIndex}) refusé : profil ou parcelle pas encore prêts`)
		return
	end
	local slot: Attachment? = session.slots[slotIndex]
	if slot == nil then
		log(`{player.Name} : PlaceBox({slotIndex}) refusé : pas de présentoir n° {slotIndex} sur sa parcelle`)
		return
	end
	if not CarryService.IsCarrying(player) then
		log(`{player.Name} : PlaceBox({slotIndex}) refusé : ne porte rien`)
		return
	end
	local payload = CarryService.GetPayload(player)
	if type(payload) ~= "table" or payload.Kind ~= NPC_BOX_KIND then
		log(`{player.Name} : PlaceBox({slotIndex}) refusé : ne porte pas un colis PNJ`)
		return
	end
	if not inReach(player, slot) then
		log(`{player.Name} : PlaceBox({slotIndex}) refusé : trop loin du présentoir (plus de {REACH} studs)`)
		return
	end
	local key = slotKey(slotIndex)
	local state = slotStates(player)[slotIndex]
	if state == "Locked" then
		log(`{player.Name} : PlaceBox({slotIndex}) refusé : présentoir verrouillé`)
		notify(player, MESSAGES.Locked)
		return
	end
	if data.Boxes[key] ~= nil or state ~= "Free" then
		local full = not hasFreeSlot(player, session, data)
		log(`{player.Name} : PlaceBox({slotIndex}) refusé : présentoir occupé ({tostring(state)}){if full then ", aucun de libre" else ""}`)
		notify(player, if full then MESSAGES.StandsFull else MESSAGES.Busy)
		return
	end
	local problem = checkContent(payload)
	if problem then
		warn(`[UnboxService] {player.Name} : colis porté mal formé ({problem}), PlaceBox refusé`)
		return
	end
	local itemRarity = Items.ById[payload.ItemId].Rarity
	if itemRarity ~= payload.Rarity then
		warn(`[UnboxService] {player.Name} : colis {payload.Rarity} qui contient un objet {itemRarity} : tirage à corriger (StoreHeistService)`)
	end

	local box: Box = {
		Tier = payload.Tier,
		Zone = payload.Zone,
		ItemId = payload.ItemId,
		Rarity = payload.Rarity,
		ReadyAt = 0,
		Mutation = Mutations.Sanitize(payload.Mutation), -- DEV-131 : absente du profil sans mutation
	}
	local delay = openDelay(player, box)
	-- Anti-triche (DEV-060), juste avant la réussite : le dernier déplacement (téléport chez soi) et
	-- le trajet depuis la prise (speed hack), sans attendre le contrôle suivant. Sanctionné : le colis
	-- vient de revoler vers son rayon (CarryService.ReportAnomaly), rien n'est posé.
	local start = carryStarts[player]
	local from: Vector3?, since: number? = nil, nil
	if start and start.Payload == payload then
		from, since = start.From, start.At
	end
	if not AntiCheatService.Verify(player, from, since) then
		log(`{player.Name} : PlaceBox({slotIndex}) refusé : déplacement sanctionné par l'anti-triche, colis rendu`)
		return
	end
	if CarryService.Consume(player) == nil then
		log(`{player.Name} : PlaceBox({slotIndex}) refusé : CarryService.Consume n'a rien rendu`)
		return
	end
	-- Consume ne devrait pas yield ; s'il l'a fait, le profil a pu partir entre-temps.
	if DataService.Get(player) ~= data or sessions[player] ~= session then
		warn(`[UnboxService] {player.Name} : profil ou parcelle perdus pendant la pose, colis perdu`)
		return
	end
	box.ReadyAt = serverNow() + delay
	if data.Boxes[key] ~= nil then
		-- Ne devrait pas arriver (contrôlé plus haut, sans yield) : le colis va dans la file plutôt
		-- que d'écraser l'autre.
		local queue = queueOf(data)
		if queue then
			table.insert(queue, box)
		end
		warn(`[UnboxService] {player.Name} : présentoir {slotIndex} pris pendant la pose, colis mis dans la file`)
		return
	end
	data.Boxes[key] = box
	local heists = countHeist(player, data) -- d'un seul tenant avec le colis : sauvegardés ensemble
	session.fullNotified = nil
	showBox(player, session, slotIndex, box)
	log(`{player.Name} : colis {box.Tier} {box.Rarity} posé sur le présentoir {slotIndex}, prêt dans {delay} s (braquages réussis : {heists or "?"})`)
	for _, listener in table.clone(placedListeners) do
		task.spawn(listener, player, slotIndex, table.clone(box))
	end
end

local function onOpenBox(player: Player, slotIndex: number)
	local data = DataService.Get(player)
	local session = sessions[player]
	if data == nil or session == nil or not ownsPlot(player, session.plot) then
		log(`{player.Name} : OpenBox({slotIndex}) refusé : profil ou parcelle pas encore prêts`)
		return
	end
	local slot: Attachment? = session.slots[slotIndex]
	local key = slotKey(slotIndex)
	local box = data.Boxes[key]
	if slot == nil or box == nil then
		log(`{player.Name} : OpenBox({slotIndex}) refusé : aucun colis sur ce présentoir`)
		return
	end
	if not inReach(player, slot) then
		log(`{player.Name} : OpenBox({slotIndex}) refusé : trop loin du présentoir (plus de {REACH} studs)`)
		return
	end
	if type(box.ReadyAt) ~= "number" or serverNow() < box.ReadyAt then
		log(`{player.Name} : OpenBox({slotIndex}) refusé : attente pas écoulée`)
		notify(player, MESSAGES.NotReady)
		return
	end
	local problem = checkContent(box)
	if problem then
		warn(`[UnboxService] {player.Name} : colis du présentoir {slotIndex} illisible ({problem}), ouverture refusée`)
		return
	end
	-- Le présentoir garde l'objet s'il est débloqué et sans autre objet (état "Boxed" de
	-- DisplayService : c'est son colis qui l'occupe). Sinon (cas d'erreur de l'en-tête), il faut une
	-- autre place.
	local keepHere = slotStates(player)[slotIndex] == "Boxed"
	if not keepHere and inventoryFull(player) then
		log(`{player.Name} : OpenBox({slotIndex}) refusé : présentoir indisponible, présentoirs et inventaire pleins`)
		notify(player, MESSAGES.InventoryFull)
		return
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

	-- D'un seul tenant, sans yield : l'objet entre dans Items quand le colis quitte Boxes.
	local uid = newUid(data)
	-- Zone gardée pour le revenu du Secret, qui n'a pas de zone au catalogue (DisplayService la lit).
	data.Items[uid] = { Id = itemId, Source = "NPC", At = os.time(), Zone = box.Zone, Mutation = mutation }
	data.Boxes[key] = nil
	clearShown(session, slotIndex)

	-- 5.7 : l'identité de l'objet ne part vers le client qu'ici, avec ce qu'il faut pour jouer les
	-- crans et composer le rouleau, et sa mutation (nom et revenu de l'écran d'ouverture). Sans mutation,
	-- les deux derniers arguments (facultatifs) ne partent pas : la forme d'avant DEV-131.
	if mutation then
		Net.Server.UnboxReveal:Fire(player, slotIndex, uid, itemId, box.Zone, box.Tier, startRarity, #steps, mutation.Size, mutation.Effect)
	else
		Net.Server.UnboxReveal:Fire(player, slotIndex, uid, itemId, box.Zone, box.Tier, startRarity, #steps)
	end
	local upgraded = if #steps > 0 then `, {#steps} cran(s) : {startRarity} → {table.concat(steps, " → ")}` else ""
	local mutated = Mutations.Label(mutation)
	log(`{player.Name} : présentoir {slotIndex} ouvert, {itemId} ({finalRarity}){upgraded}, uid {uid}{if mutated then ", mutation " .. mutated else ""}`)
	announce(player, itemId, finalRarity, #steps)

	-- L-086 : l'objet reste sur le présentoir de son colis ; sinon le plus proche, sinon l'inventaire.
	local placedOn: number? = nil
	if keepHere then
		local ok, done, reason = pcall(DisplayService.PlaceItem, player, uid, slotIndex)
		if ok and done == true then
			placedOn = slotIndex
		else
			warn(`[UnboxService] {player.Name} : {itemId} pas exposé sur le présentoir {slotIndex} ({if ok then tostring(reason) else tostring(done)}), autre place cherchée`)
		end
	end
	local failed = false
	if placedOn == nil then
		local ok, result = pcall(DisplayService.PlaceAuto, player, uid)
		if not ok then
			failed = true -- panne : on ne sait pas où est l'objet, pas de message au joueur
			warn(`[UnboxService] DisplayService.PlaceAuto ({player.Name}, {uid}) : {result}`)
		elseif type(result) == "number" then
			placedOn = result
		end
	end
	if failed then
		log(`{player.Name} : {itemId} gardé dans Items, présentoir inconnu (panne de DisplayService)`)
	elseif placedOn == nil then
		local item = Items.ById[itemId]
		local message = string.format(MESSAGES.ToInventory, if item then item.DisplayName else itemId)
		local delay = notifyAtReveal(player, message, INFO_KIND, finalRarity, #steps)
		log(`{player.Name} : aucun présentoir pour {itemId}, il reste dans l'inventaire (message dans {delay} s)`)
	else
		log(`{player.Name} : {itemId} exposé sur le présentoir {placedOn}`)
	end
	refreshStates(player)

	local revealAt = revealDelayFor(finalRarity, #steps)
	for _, listener in table.clone(openedListeners) do
		task.spawn(listener, player, slotIndex, uid, itemId, revealAt)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function UnboxService.GetOpenDelay(_player: Player, box: Box): number
	return Rarities.ById[box.Rarity].OpenDelay
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

function UnboxService.OnBoxPlaced(listener: PlacedListener): () -> ()
	return subscribe(placedListeners, listener)
end

function UnboxService.OnBoxOpened(listener: OpenedListener): () -> ()
	return subscribe(openedListeners, listener)
end

function UnboxService.GetWaiting(player: Player): { [number]: number }
	local waiting: { [number]: number } = {}
	local session = sessions[player]
	if session == nil then
		return waiting
	end
	local now = serverNow()
	for index, shown in session.shown do
		if not shown.ready and shown.readyAt > now then
			waiting[index] = shown.readyAt
		end
	end
	return waiting
end

function UnboxService.SkipWait(player: Player, slotIndex: number, seconds: number): number?
	local data = DataService.Get(player)
	local session = sessions[player]
	if data == nil or session == nil or type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 then
		return nil
	end
	local shown = session.shown[slotIndex]
	local box = data.Boxes[slotKey(slotIndex)]
	if shown == nil or shown.ready or box == nil or type(box.ReadyAt) ~= "number" then
		return nil
	end
	local now = serverNow()
	if box.ReadyAt <= now then
		return nil -- déjà prêt : la boucle le marque au prochain pas
	end
	local readyAt = math.max(now, box.ReadyAt - seconds)
	box.ReadyAt = readyAt
	shown.readyAt = readyAt
	shown.model:SetAttribute(READY_AT_ATTRIBUTE, readyAt)
	local left = readyAt - now
	if left <= 0 then
		markReady(player, session, slotIndex, shown)
		left = 0
	else
		setLabel(shown, timerText(left))
	end
	log(`{player.Name} : attente du colis du présentoir {slotIndex} réduite de {string.format("%.1f", seconds)} s, reste {string.format("%.1f", left)} s`)
	return left
end

function UnboxService.Init()
	Net.Server.PlaceBox:Connect(onPlaceBox)
	Net.Server.OpenBox:Connect(onOpenBox)

	-- Le colis revient quand le profil est chargé ET la parcelle attribuée (PlotService attend le
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

	-- Où et quand le portage du colis a commencé (contrôle du trajet à la pose, DEV-060).
	CarryService.OnCarryStarted(function(player: Player, payload: any)
		local root = rootOf(player)
		if root and type(payload) == "table" and payload.Kind == NPC_BOX_KIND then
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
	local slowElapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		slowElapsed += dt
		if elapsed >= TICK then
			elapsed = 0
			advance()
		end
		if slowElapsed >= SLOW_TICK then
			slowElapsed = 0
			slowAdvance()
		end
	end)
end

return UnboxService
