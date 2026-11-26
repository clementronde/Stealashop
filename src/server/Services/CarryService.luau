--!strict
-- CarryService (DEV-017) : l'objet porté au-dessus de la tête (Partie 1, sections
-- 5.6, 5.5, 6.1, 6.2, 9.3, 9.4 et 9.6).
--
-- Vague 50 (a158, décision de Cantin du 2026-11-14) : le colis porté fermé (payload « NPCBox ») n'existe plus.
-- On ne porte que des objets : sorti d'un colis ouvert sur place (« NPCItem » : rayon de magasin, camion,
-- coffre de la Fortune Tower) ou volé à un joueur (« PlayerItem »). PlaceDrop (colis posé au sol sans
-- porteur) est retiré ; dans la suite, « colis » porté ou au sol se lit « objet NPCItem ».
--
-- Un seul colis porté à la fois (5.3). Dès qu'un joueur le soulève, il flotte au-dessus de sa
-- tête, soudé à la tête et sans masse, à la couleur de sa rareté, avec son halo et son étiquette
-- BB_Carry : tout le monde le voit (objets créés par le serveur, répliqués à tous). Pendant le
-- portage : malus de vitesse (StatsService, clé "Carry"), saut autorisé, aucun outil en main.
-- Le portage finit par une réussite (Consume), un échec (Fail : mort, départ, capture, anomalie)
-- ou un coup de batte qui fait tomber le colis (Drop, BatService). Ce service ne remet jamais
-- rien en place lui-même : le service d'origine réagit à OnCarryEnded (le braquage remet le colis
-- sur son rayon, le vol PvP rend l'objet à son présentoir). Aucun remote ici : la prise arrive par
-- GrabItem (StoreHeistService) ou StealItem (PvPService), le rangement dans l'inventaire à l'entrée de
-- la zone safe (UnboxService, L-089), le
-- dépôt d'un objet volé par PvPService (Consume, raison « Deposited »).
--
-- Payload (Shared/Types/Carry) : { Kind = "PlayerItem", ItemUid, ItemId, Rarity, Income, VictimUserId,
-- SlotIndex } pour un objet volé à un joueur (DEV-041, PvPService : vitesse fixe, contour rouge,
-- BB_Carry) ; { Kind = "NPCItem", ItemId, Rarity, Mutation?, Zone, StoreId, SlotId, Luck } pour un objet
-- sorti d'un colis ouvert sur le rayon d'un magasin PNJ (L-112, StoreHeistService : c'est l'objet qui
-- flotte, comme un objet volé, avec son halo et BB_Carry, sans contour rouge ; malus du colis PNJ,
-- −10 % ; il tombe au sol comme un colis, voir Drop et Fail). Fabriqué par le serveur, vérifié par
-- StartCarry, puis toujours repassé tel quel (même table) aux écouteurs : le lire, ne jamais le modifier.
--
-- API (serveur) :
--   CarryService.StartCarry(player, payload) -> boolean
--       Le joueur soulève `payload`. false, et rien ne change (le colis reste où il est), si le
--       joueur porte déjà, n'a pas de personnage vivant avec une tête, ou si le payload est
--       invalide ou déjà porté ou au sol (ces deux derniers cas avertissent, avec la pile d'appel).
--   CarryService.IsCarrying(player) -> boolean
--   CarryService.GetPayload(player) -> Payload?
--   CarryService.Consume(player, reason?) -> Payload?
--       Fin réussie (colis rangé dans l'inventaire, objet déposé) : visuels et malus retirés, puis
--       OnCarryEnded(…, "Consumed", reason ou "Consumed"). Renvoie le payload, nil si le joueur ne
--       portait rien. Ne regarde pas le type : l'appelant vérifie GetPayload(player).Kind avant.
--   CarryService.Fail(player, reason) -> boolean
--       Échec : le colis est perdu pour le porteur, OnCarryEnded(…, "Failed", reason). false si le
--       joueur ne portait rien (UnboxService passe "InventoryFull" et "Invalid", L-089). Raisons
--       posées ici : "Died" (mort) ; "Left" (départ) ;
--       "CharacterRemoved" (personnage retiré sans mourir ; à une déconnexion, selon l'ordre des
--       événements de Roblox, la raison est "Left" ou "CharacterRemoved") ; "Anomaly"
--       (ReportAnomaly) ; "Bat" (Drop d'un objet volé). Les autres services passent la leur
--       (GuardService : "Caught" ; PvPService : "VictimLeft", la victime part pendant la fuite, et
--       "NoRoom", plus de place chez le voleur au dépôt ; la batte, DEV-043 : "Bat").
--       Objet NPCItem et raison "Caught" (L-112 : attrapé par le vigile, la police ou le vigile de
--       nuit) : l'objet ne retourne pas sur son rayon, il tombe au sol sous le porteur et peut être
--       repris, comme un colis après un coup de batte (même colis au sol que Drop, attribut BatDrop,
--       Bat.DroppedLifetime s) ; OnCarryEnded(…, "Dropped", "Caught"), et Fail renvoie true. Le joueur
--       attrapé ne peut pas le reprendre avant Balance.Guard.CatchStunDuration s (V0 proposé, absent
--       du doc : le temps de son étourdissement ; les autres joueurs, tout de suite).
--   CarryService.FailNoDrop(player, reason) -> boolean
--       Comme Fail, sans jamais de chute : OnCarryEnded(…, "Failed", reason), l'objet revole vers son rayon.
--       GuardService (Cantin, 2026-11-13) : porteur attrapé dans le magasin d'où vient l'objet ("Caught").
--   CarryService.SetBackToShelfCheck(check)
--       L-135 point 5 (Clément, 2026-11-14) : `check(player) -> boolean`, posé par GuardService (porteur d'un
--       objet NPCItem dans le volume Bounds du magasin d'où il vient). Vrai au moment d'une chute (Drop : coup
--       de batte ; Fail "Caught" d'un objet NPCItem) : rien ne tombe, l'objet revole tout de suite vers son
--       rayon, comme FailNoDrop (OnCarryEnded(…, "Failed", raison), Drop renvoie nil). Sans check, ou s'il
--       échoue : la chute habituelle. Dans la rue, rien ne change.
--   CarryService.ReportAnomaly(player, detail) -> boolean
--       Point d'accroche de l'anti-triche (9.6, AntiCheatService DEV-060) : écrit `detail` dans la
--       sortie (warn), puis Fail(player, "Anomaly"). false si le joueur ne portait rien.
--   CarryService.OnCarryStarted(listener) -> déconnexion
--       listener(player, payload), une fois le colis sur la tête.
--   CarryService.OnCarryEnded(listener) -> déconnexion
--       listener(player, payload, result, reason), result = "Consumed", "Failed" ou "Dropped".
--       Visuels, malus et attribut sont déjà retirés : IsCarrying(player) vaut false.
--   Colis au sol après un coup de batte (DEV-048, branché par BatService, vague 10) :
--   CarryService.Drop(player, position) -> string?
--       Coup de batte sur un porteur hors zone safe (6.2) : le colis PNJ tombe au sol à `position`
--       (point du sol, calculé par l'appelant), avec sa couleur, son halo et son étiquette BB_Box,
--       dans Workspace/CarryDrops (attribut DropId, plus Tier = type du colis et BatDrop = true,
--       lus par BatController pour l'invite). Puis OnCarryEnded(…, "Dropped", "Bat"), écouteurs
--       appelés avant le retour de Drop (le porteur est encore à l'endroit du coup). Renvoie son
--       dropId ; nil si le joueur ne portait rien. Position invalide : avertissement, le colis tombe
--       au pied du porteur. Un objet volé à un joueur ne tombe jamais : Fail(player, "Bat"), il
--       revole chez son propriétaire (6.2, remis par PvPService), et Drop renvoie nil. Un objet
--       NPCItem (L-112) tombe comme un colis (sans attribut Tier).
--   CarryService.PickUpDrop(player, dropId) -> boolean
--       Ramassage d'un colis au sol (GrabDropped, 9.4) : le nouveau porteur reçoit le même payload
--       (même table : même rareté, même objet caché, 6.2), par StartCarry ; le colis quitte le sol
--       avant (jamais deux exemplaires) et y revient si StartCarry refuse. L'appelant vérifie avant
--       la distance, le temps de prise, la zone safe et les protections (BatService, TruckEventService).
--   CarryService.IsFallenDrop(dropId) -> boolean
--       true si `dropId` est encore au sol et y est tombé des mains d'un porteur (Drop, ou Fail
--       "Caught" d'un objet NPCItem) : BatService accepte alors GrabDropped.
--   CarryService.GetDrop(dropId) -> (Payload?, Vector3?)
--       Payload et position (point du sol) d'un colis encore au sol ; nil, nil sinon (ramassé,
--       expiré, inconnu, ou dropId qui n'est pas une chaîne).
--   CarryService.PlaceItemDrop(payload, position, lifetime) -> (dropId?, Model?)
--       Vague 58 (a188, pluie d'objets, ItemRainService) : pose au sol à `position` (point du sol), sans porteur,
--       un objet NPCItem neuf, pour `lifetime` s. Même objet au sol qu'après un Drop (attributs DropId, BatDrop,
--       ItemId, MutationSize, MutationEffect ; invite de BatController, ramassage GrabDropped de BatService,
--       IsFallenDrop vrai, OnDropExpired à la fin). Renvoie aussi son modèle (l'appelant peut jouer une chute :
--       PivotTo, le point du sol ne change pas). nil, nil avec un avertissement si le payload est invalide, pas
--       un NPCItem, déjà porté ou au sol, ou si la position ou la durée est invalide.
--   CarryService.OnDropExpired(listener) -> déconnexion
--       listener(dropId, payload, position) quand un colis reste au sol sans être ramassé :
--       Bat.DroppedLifetime secondes (6.2 : 15 s). Le modèle est déjà retiré et GetDrop(dropId) vaut nil.
--       StoreHeistService remet alors sur son rayon un objet de magasin (vol depuis `position`).
--   CarryService.Transfer(from, to, reason) -> boolean
--       a428 (L-328 point 7, DisguiseService : la police d'une dénonciation attrape le voleur) : l'objet NPCItem porté
--       par `from` passe tel quel (même table) sur la tête de `to`, comme une chute suivie d'un ramassage immédiat :
--       OnCarryEnded(from, …, "Dropped", reason) puis OnCarryStarted(to, …) (les vigiles suivent l'objet comme après
--       une chute). Jamais de retour au rayon. false, et rien ne change, si `from` ne porte pas d'objet NPCItem, ou
--       si `to` porte déjà, est parti ou n'a pas de personnage vivant avec une tête.
--   Étiquette des colis du rayon (L-031) :
--   CarryService.AttachBoxLabel(model, rarityId, itemId?, mutation?) -> BillboardGui?
--       Pose sur `model`, un colis qui n'est pas porté (StoreHeistService : chaque colis du rayon),
--       la même étiquette BB_Box que sur la tête (voir plus bas), à son LabelPoint : rareté seule
--       (vague 32 ; itemId et mutation ne servent plus qu'à la vérification, vague 53). Secret : tag
--       CarryRainbow sur l'étiquette seule, CarryController anime sa rareté (le colis du rayon
--       garde l'aspect de son type). nil, avec un avertissement, si la rareté ou l'objet est
--       inconnu ; nil si le modèle n'a aucune pièce.
--
-- Ce que voient les autres :
--   - attribut Carrying du Player = Id de la rareté portée (« Legendary »), nil sinon. Le client le
--     suit (CarryController : animations CarryIdle et CarryRun) ;
--   - Model « CarryVisual » dans le personnage : BOX_<Rareté> de Clément (L-097 point 3), sinon
--     BOX_<Tier> (ITM_<ItemId> pour un objet volé), cherché dans ReplicatedStorage/Assets, soudé à la tête par son CarryAttachment (10.4 :
--     dessous, au centre ; à défaut, par le pivot du modèle, en bas au centre), Balance.Carry.HeadGap
--     studs au-dessus du haut de la tête (V0, à régler sur les bras levés de CarryIdle, L-071). Tout
--     ce qui se porte passe par StartCarry, donc par cette soudure : colis du rayon (StoreHeistService),
--     objet volé (PvPService), colis au sol après un coup de batte et colis du camion (PickUpDrop).
--     Pièces nommées Tint teintes à la couleur de la rareté (BOX_<Tier> et bloc V0 seulement :
--     BOX_<Rareté> est déjà à sa couleur). Modèle pas encore
--     livré : bloc V0. Pour le porteur seulement, CarryController le cache jusqu'à ce que Grab le pose
--     sur la tête (marqueur Grab) ;
--   - halo de rareté (5.6) en objets natifs (lumière, particules, rayons), V0 en attendant les
--     textures de Clément (MOD-041) : Commun aucun, Peu commun léger, Rare et Épique net,
--     Légendaire et Mythique rayons, Divine rayons plus forts (L-106), Secret arc-en-ciel (couleurs animées par CarryController,
--     tag CarryRainbow posé par le code, hors du contrat de la section 2.1). Sur un colis dont le
--     modèle a déjà ses effets (BOX_Epic : lumière ; BOX_Legendary et plus : étincelles et lumière),
--     le halo ne pose pas sa lumière ni ses étincelles : seulement ce qui manque (rayons) ;
--   - étiquette, accrochée à l'Attachment LabelPoint du modèle de Clément (BOX_*, liaison L-023 et
--     L-031 ; il règle la hauteur avec le StudsOffset de l'étiquette), sinon à un LabelPoint créé
--     au sommet du visuel (objet volé, bloc V0) :
--       colis PNJ : copie de ReplicatedStorage/Assets/UI/BB_Box (contrat 2.2, L-031), la même que
--       sur le rayon : Rarity = nom de la rareté en capitales (« LEGENDARY ») à sa couleur.
--       Vague 32 (Cantin, 2026-11-13) : sur une caisse (rayon, portée, au sol),
--       la rareté seule, Category et Mutation cachées (la mutation ne se voit qu'une fois l'objet
--       sorti, BB_Item). Ni le nom ni l'ItemId de l'objet : il reste secret
--       jusqu'à l'ouverture (5.7). Taille, décalage, AlwaysOnTop et MaxDistance : ceux de Clément ;
--       objet volé à un joueur : copie de BB_Carry (contrat 2.2 : ItemName, Rarity, Income) : nom
--       précédé de sa mutation (« Big Gold Soda Can » ; si Clément ajoute un champ Mutation à
--       BB_Carry, la mutation y va et ItemName garde le nom seul), rareté, $/s (Format.income,
--       « +$15/s », mutation comprise), et un contour rouge (6.1).
--     Étiquette pas encore livrée : étiquette V0, rareté seule.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Bat = require(Shared.Config.Bat)
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local ItemWeight = require(Shared.ItemWeight) -- vague 62 (a203)
local WeightConfig = require(Shared.Config.Weight)
local Rarities = require(Shared.Config.Rarities)
local ShelfBoxes = require(Shared.Config.ShelfBoxes)
local Zones = require(Shared.Config.Zones)
local Find = require(Shared.Contract.Find)
local UI = require(Shared.Contract.UI)
local Format = require(Shared.Format)
local RarityHalo = require(Shared.RarityHalo)
local CarryTypes = require(Shared.Types.Carry)
-- a483 (Cantin, 25/11) : contour rouge de l'objet volé pour la victime seule (Shared/StolenOutline). require protégé :
-- un faux arbre de banc sans ce module garde la règle 6.1 (vu de tous).
local StolenOutlineModule = Shared:FindFirstChild("StolenOutline")
local stolenOutlineVictimOnly: boolean = if StolenOutlineModule
	then (function(): boolean
		local ok, result = pcall(require, StolenOutlineModule :: any)
		return ok and type(result) == "table" and (result :: any).VictimOnly() == true
	end)()
	else false

local StatsService = require(script.Parent.StatsService)

type Payload = CarryTypes.Payload
type NPCItemPayload = CarryTypes.NPCItemPayload
type EndResult = CarryTypes.EndResult
type Rarity = Rarities.Rarity
type Item = Items.Item

-- Noms du contrat (10.4 et 2.2).
local ASSETS_FOLDER = "Assets"
local CARRY_ATTACHMENT = "CarryAttachment"
local TINT = "Tint"
local BB_CARRY = "BB_Carry" -- objet volé à un joueur
local BB_BOX = "BB_Box" -- colis PNJ, sur le rayon comme sur la tête (L-031)
-- Champ de la mutation : au contrat de BB_Box ; facultatif dans BB_Carry (nom proposé à Clément, DEV-131).
local MUTATION_FIELD = "Mutation"
-- Noms posés par ce service (mêmes noms dans CarryController pour l'attribut et le tag).
local CARRYING_ATTRIBUTE = "Carrying"
local SPEED_KEY = "Carry"
local RAINBOW_TAG = "CarryRainbow"
local CARRIED_ITEM_TAG = "CarriedItem" -- a119 : objet porté ou lâché (MutationFxController, client)
local VISUAL_NAME = "CarryVisual"
local WELD_NAME = "CarryWeld"
local LABEL_POINT = "LabelPoint"
local DROPS_FOLDER = "CarryDrops"
local DROP_ID_ATTRIBUTE = "DropId"
-- Raison passée à Fail par GuardService à la capture (vigile de jour, police, vigile de nuit).
local CAUGHT_REASON = "Caught"
-- V0 proposé, absent du doc : sol cherché jusqu'à 50 studs sous le porteur attrapé (comme BatService).
local GROUND_RAY_DOWN = 50
local ACTIVE_GUARDS = "ActiveGuards" -- vigiles en jeu (GuardService), ignorés par ce rayon

-- Espace (studs) entre le haut de la tête et le dessous du colis : Balance.Carry.HeadGap (V0, L-071).
local HEAD_GAP: number = Balance.Carry.HeadGap
-- V0 proposé, absent du doc : bloc gris tant que ITM_<ItemId> n'est pas livré.
local PLACEHOLDER_ITEM_SIZE = Vector3.new(1.2, 1.2, 1.2)
-- V0 proposé, absent du doc : contour de l'objet volé (6.1), rouge « fermer » de la planche 10.6.
local OUTLINE_COLOR = Color3.fromHex("#E8413C")
-- V0 proposé, absent du doc : contour du texte de l'étiquette V0 (couleur de contour de 10.6).
local TEXT_STROKE_COLOR = Color3.fromHex("#1B1B24")
-- Halo de rareté (5.6) : rendu commun avec DisplayService, Shared/RarityHalo (vague 37, a122).

type Visual = {
	model: Model,
	anchor: BasePart, -- pièce soudée à la tête (celle du CarryAttachment), ancrée quand le colis est au sol
	offset: CFrame, -- point posé sur la tête (dessous du colis), dans l'espace de anchor
}

type Carry = {
	payload: Payload,
	humanoid: Humanoid,
	visual: Visual,
	connections: { RBXScriptConnection },
}

type Drop = {
	payload: Payload,
	visual: Visual,
	position: Vector3,
	lifetime: number, -- secondes au sol avant d'expirer
	timer: thread,
	fallen: boolean, -- tombé des mains d'un porteur (Drop, capture) ou posé par PlaceItemDrop (a188) : toujours vrai depuis la vague 50
	lockedFor: Player?, -- L-112 : le joueur attrapé, qui ne peut pas le reprendre avant lockedUntil
	lockedUntil: number, -- os.clock()
}

type StartedListener = (player: Player, payload: Payload) -> ()
type EndedListener = (player: Player, payload: Payload, result: EndResult, reason: string) -> ()
type DropExpiredListener = (dropId: string, payload: Payload, position: Vector3) -> ()

local IS_STUDIO = RunService:IsStudio()

local CarryService = {}

local carries: { [Player]: Carry } = {}
-- Payloads portés ou au sol, contre les doublons : la table elle-même pour un colis PNJ (un nouveau
-- tirage est une nouvelle table), l'uid pour un objet volé (unique, 9.6).
local held: { [any]: boolean } = {}
local drops: { [string]: Drop } = {}
local dropCount = 0
local startedListeners: { StartedListener } = {}
local endedListeners: { EndedListener } = {}
local dropExpiredListeners: { DropExpiredListener } = {}
local noticed: { [string]: boolean } = {}
-- L-135 point 5 : porteur dans le magasin d'où vient son objet (SetBackToShelfCheck, posé par GuardService).
local backToShelfCheck: ((player: Player) -> boolean)? = nil

-- Vrai si l'objet de `player` doit revoler sur son rayon au lieu de tomber (voir SetBackToShelfCheck).
local function backToShelf(player: Player, carry: Carry): boolean
	local check = backToShelfCheck
	if check == nil or carry.payload.Kind == "PlayerItem" then
		return false
	end
	local ok, result = pcall(check, player)
	if not ok then
		warn(`[CarryService] contrôle « dans son magasin » ({player.Name}) : {result}`)
		return false
	end
	return result == true
end

-- Renvoie une fonction qui retire `listener` de `list`.
local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

-- Écrit un message une seule fois par serveur : avertissement (modèle mal formé), ou simple ligne
-- en Studio (asset pas encore livré, c'est attendu tant que Clément n'a pas livré).
local function once(key: string, message: string, isWarning: boolean)
	if noticed[key] then
		return
	end
	noticed[key] = true
	if isWarning then
		warn(message)
	elseif IS_STUDIO then
		print(message)
	end
end

local function keyOf(payload: Payload): any
	if payload.Kind == "PlayerItem" then
		return "PlayerItem:" .. payload.ItemUid
	end
	return payload
end

local function describe(payload: Payload): string
	if payload.Kind == "NPCItem" then
		return `objet {payload.ItemId} ({payload.Rarity}) sorti d'un colis ({payload.StoreId}, {payload.SlotId})`
	end
	return `objet {payload.ItemId} ({payload.Rarity}) du joueur {payload.VictimUserId}`
end

-- Objet volé à un joueur : vitesse fixe (Cantin, 2026-11-13) ; sinon −10 % (5.6) : objet sorti d'un colis
-- (L-112 ; Balance.Carry.NPCBoxSpeedMultiplier garde son nom).
-- a426 (L-319) : dans une zone safe, l'objet volé donne Balance.SafeZoneSpeed.WalkSpeed × StolenItemMultiplier
-- (StatsService ne s'en sert que si Features.SafeZoneSpeed est allumé).
local SAFE_ZONE_SPEED = (Balance :: any).SafeZoneSpeed
local STOLEN_SAFE_ZONE_SPEED: number? = if type(SAFE_ZONE_SPEED) == "table"
	then SAFE_ZONE_SPEED.WalkSpeed * SAFE_ZONE_SPEED.StolenItemMultiplier
	else nil
local function applySpeed(player: Player, payload: Payload)
	if payload.Kind == "PlayerItem" then
		StatsService.SetFixedSpeed(player, Balance.Carry.StolenItemWalkSpeed, STOLEN_SAFE_ZONE_SPEED)
	else
		StatsService.SetSpeedModifier(player, SPEED_KEY, Balance.Carry.NPCBoxSpeedMultiplier)
	end
end

-- Vérification ---------------------------------------------------------------------

local function isInteger(value: any): boolean
	return type(value) == "number" and value == math.floor(value)
end

local function isText(value: any): boolean
	return type(value) == "string" and value ~= ""
end

-- Raison du refus d'un payload, ou nil s'il est valide. Le payload vient toujours du serveur :
-- un refus est un bogue du service appelant, à corriger.
local function invalidReason(payload: any): string?
	if type(payload) ~= "table" then
		return `payload absent ({payload})`
	end
	local rarity = Rarities.ById[payload.Rarity]
	if rarity == nil then
		return `rareté inconnue ({payload.Rarity})`
	end
	local item = Items.ById[payload.ItemId]
	if item == nil then
		return `objet inconnu ({payload.ItemId})`
	end
	if item.Rarity ~= rarity.Id then
		return `{item.Id} est {item.Rarity}, pas {rarity.Id}`
	end
	if not Mutations.IsValid(payload.Mutation) then
		return "mutation invalide (Config/Mutations)"
	end
	if payload.Kind == "NPCItem" then
		local luck = payload.Luck
		if type(luck) ~= "number" or not (luck >= 1) or luck == math.huge then
			return `chance invalide ({luck})`
		end
		-- Objet sorti (L-112) : le tirage de la sortie peut le prendre dans une zone voisine (StoreHeistService,
		-- vague 32), Zone reste celle du magasin.
		if not isInteger(payload.Zone) or Zones[payload.Zone] == nil then
			return `zone inconnue ({payload.Zone})`
		end
		if not isText(payload.StoreId) or not isText(payload.SlotId) then
			return "StoreId ou SlotId manquant"
		end
	elseif payload.Kind == "PlayerItem" then
		if not isText(payload.ItemUid) then
			return "ItemUid manquant"
		end
		local income = payload.Income
		if type(income) ~= "number" or income ~= income or income < 0 or income == math.huge then
			return `revenu invalide ({income})`
		end
		if not isInteger(payload.VictimUserId) or not isInteger(payload.SlotIndex) then
			return "VictimUserId ou SlotIndex manquant"
		end
	else
		return `Kind inconnu ({payload.Kind})`
	end
	return nil
end

-- Visuel ---------------------------------------------------------------------------

-- Copie du modèle de Clément nommé `name`, cherché dans ReplicatedStorage/Assets (comme
-- ToolService), ou nil s'il n'est pas livré.
local function findAsset(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
	return if assets then assets:FindFirstChild(name, true) else nil
end

local function cloneAsset(name: string): Model?
	local asset = findAsset(name)
	if asset == nil then
		once(name, `[CarryService] {name} pas encore livré dans ReplicatedStorage/{ASSETS_FOLDER} : bloc V0 à la place`, false)
		return nil
	end
	if asset:IsA("Model") then
		return asset:Clone() :: Model
	elseif asset:IsA("BasePart") then
		local model = Instance.new("Model")
		local part = asset:Clone() :: BasePart
		part.Parent = model
		model.PrimaryPart = part
		return model
	end
	once(name, `[CarryService] {asset:GetFullName()} n'est ni un Model ni une pièce : bloc V0 à la place`, true)
	return nil
end

-- Pièce d'accroche d'un modèle et point (dans l'espace de cette pièce) qui se pose sur la tête :
-- son CarryAttachment (10.4), sinon le pivot du modèle (en bas au centre, 10.1).
local function anchorOf(model: Model): (BasePart?, CFrame)
	local attachment = model:FindFirstChild(CARRY_ATTACHMENT, true)
	if attachment and attachment:IsA("Attachment") then
		local parent = attachment.Parent
		if parent and parent:IsA("BasePart") then
			return parent, attachment.CFrame
		end
	end
	local root = model.PrimaryPart or (model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?)
	if root == nil then
		return nil, CFrame.identity
	end
	local pivot: CFrame = root.CFrame:ToObjectSpace(model:GetPivot())
	return root, pivot
end

-- Bloc gris V0 : une pièce Tint (teinte à la couleur de la rareté), le point d'accroche dessous.
local function placeholder(size: Vector3): (Model, BasePart, CFrame)
	local model = Instance.new("Model")
	local part = Instance.new("Part")
	part.Name = TINT
	part.Size = size
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
	model.PrimaryPart = part
	return model, part, CFrame.new(0, -size.Y / 2, 0)
end

-- Modèle du visuel, sa pièce d'accroche, le point d'accroche, et true si c'est le bloc V0.
local function sourceModel(assetName: string): (Model, BasePart, CFrame, boolean)
	local model = cloneAsset(assetName)
	if model then
		local anchor, offset = anchorOf(model)
		if anchor then
			return model, anchor, offset, false
		end
		once(`{assetName}.anchor`, `[CarryService] {assetName} ne contient aucune pièce : bloc V0 à la place`, true)
		model:Destroy()
	end
	local block, part, offset = placeholder(PLACEHOLDER_ITEM_SIZE)
	return block, part, offset, true
end

-- Pièces d'un visuel : sans script ni invite, jamais ancrées, sans collision, sans masse, ignorées
-- par les rayons (caméra, ligne de vue des vigiles), toutes soudées à la pièce d'accroche.
local function prepare(model: Model, anchor: BasePart)
	for _, descendant in model:GetDescendants() do
		if not descendant:IsDescendantOf(model) then
			continue -- dans un objet déjà retiré
		end
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("ProximityPrompt") or descendant:IsA("ClickDetector") then
			descendant:Destroy() -- jamais de script dans un modèle (CLAUDE.md), aucune invite sur la tête
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			if descendant ~= anchor then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = anchor
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
end

-- Teint les pièces Tint (10.4). Renvoie leur nombre.
local function tint(model: Model, color: Color3): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant.Name == TINT and descendant:IsA("BasePart") then
			descendant.Color = color
			count += 1
		end
	end
	return count
end

-- Écrit `text` dans l'élément `name` de l'étiquette (TextLabel ou TextButton, cherché parmi les
-- descendants, Contract/Find), ou cache l'élément (tout GuiObject) si `text` est nil ; `color`
-- colore le texte. Élément absent : rien (le ContractChecker le signale déjà).
local function fill(gui: Instance, name: string, text: string?, color: Color3?)
	local element = Find.path(gui, name)
	if element == nil or not element:IsA("GuiObject") then
		return
	end
	if text == nil then
		(element :: GuiObject).Visible = false
		return
	end
	if not (element:IsA("TextLabel") or element:IsA("TextButton")) then
		return
	end
	local label = element :: any
	label.Text = text
	label.Visible = true
	if color then
		label.TextColor3 = color
	end
end

-- Modèle de billboard `name` de Clément (ReplicatedStorage/Assets/UI, contrat 2.2), ou nil.
local function labelTemplate(name: string): BillboardGui?
	local folder: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		folder = if folder then folder:FindFirstChild(segment) else nil
	end
	local template = if folder then folder:FindFirstChild(name) else nil
	if template and template:IsA("BillboardGui") then
		return template
	end
	local path = `ReplicatedStorage/{table.concat(UI.BillboardFolder, "/")}`
	if template then
		once(name, `[CarryService] {template:GetFullName()} n'est pas un BillboardGui : étiquette V0 à la place`, true)
	else
		once(name, `[CarryService] {name} pas encore livré dans {path} : étiquette V0 (rareté seule)`, false)
	end
	return nil
end

-- Étiquette V0 en attendant BB_Box ou BB_Carry (UI-001) : la rareté seule, à sa couleur.
-- `maxDistance` : portée (studs), illimitée si nil.
local function placeholderLabel(maxDistance: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 0.9)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.7, 0)
	gui.LightInfluence = 0
	if maxDistance then
		gui.MaxDistance = maxDistance
	end
	local label = Instance.new("TextLabel")
	label.Name = "Rarity"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = TEXT_STROKE_COLOR
	label.Parent = gui
	return gui
end

-- Point d'accroche de l'étiquette : le LabelPoint livré dans le modèle (Attachment dans une pièce),
-- sinon un LabelPoint créé au sommet du visuel (`top`, CFrame dans l'espace de anchor).
local function labelPoint(model: Model, anchor: BasePart, top: CFrame): Attachment
	local delivered = model:FindFirstChild(LABEL_POINT, true)
	local holder = if delivered then delivered.Parent else nil
	if delivered and delivered:IsA("Attachment") and holder and holder:IsA("BasePart") then
		return delivered
	end
	local point = Instance.new("Attachment")
	point.Name = LABEL_POINT
	point.CFrame = top
	point.Parent = anchor
	return point
end

-- Étiquette BB_Box d'un colis PNJ (L-031) : la rareté de la caisse à sa couleur, seule (vague 32,
-- Cantin, 2026-11-13) ; lignes Category et Mutation cachées, la mutation ne se voit qu'une fois l'objet
-- sorti (BB_Item). Jamais le nom ni l'ItemId de l'objet (5.7).
local function boxLabel(rarity: Rarity): BillboardGui
	local template = labelTemplate(BB_BOX)
	local gui = if template then template:Clone() :: BillboardGui else placeholderLabel(ShelfBoxes.V0LabelMaxDistance)
	gui.Name = BB_BOX
	fill(gui, "Category", nil)
	fill(gui, "Rarity", rarity.DisplayNameUpper, rarity.Color)
	fill(gui, "Mutation", nil)
	return gui
end

-- $/s d'un objet sorti d'un colis (L-112), comme une fois exposé (DisplayService) : Formulas.ItemIncome (vague 76 :
-- rareté, zone et rang de l'objet), mutation comprise.
local function npcItemIncome(payload: NPCItemPayload): number
	return Formulas.RoundIncome( -- a493 : sans décimales, comme la boutique
		Formulas.ItemIncome(payload.ItemId) -- vague 76 : rareté, zone et rang de l'objet
			* Mutations.IncomeMultiplier(payload.Mutation, payload.Weight) -- vague 62 : poids compris
	)
end

-- Étiquette BB_Carry d'un objet porté (objet volé à un joueur, 6.1 ; objet sorti d'un colis, L-112) :
-- nom (précédé de sa mutation, DEV-131), rareté à sa couleur, $/s. Champ Mutation facultatif (a125,
-- L-131 g : au contrat, Contract/UI, avertissement orange s'il manque) : s'il existe, la mutation y va en
-- capitales, ItemName garde le nom seul et MutationFxController (client) lui donne le style de la mutation.
local function itemLabel(itemId: string, mutation: Mutations.Mutation?, income: number, rarity: Rarity, weight: number?): BillboardGui
	local template = labelTemplate(BB_CARRY)
	local gui = if template then template:Clone() :: BillboardGui else placeholderLabel(nil)
	gui.Name = BB_CARRY
	local name = Items.ById[itemId].DisplayName
	if Find.path(gui, MUTATION_FIELD) ~= nil then
		fill(gui, "ItemName", name)
		fill(gui, MUTATION_FIELD, Mutations.Label(mutation))
	else
		fill(gui, "ItemName", Mutations.ItemName(name, mutation))
	end
	fill(gui, "Rarity", rarity.DisplayNameUpper, rarity.Color)
	fill(gui, "Income", Format.income(income))
	-- Vague 62 (a203) : poids « 1,250 kg » dans l'élément facultatif Weight de BB_Carry (nom proposé à Clément), caché sans poids connu.
	local kg = ItemWeight.Sanitize(weight)
	fill(gui, WeightConfig.Field, if kg then ItemWeight.Format(kg) else nil)
	return gui
end

-- Étiquette au-dessus du visuel (voir labelPoint) : BB_Carry pour un objet (volé à un joueur, ou sorti
-- d'un colis). BB_Box ne sert plus qu'aux colis du rayon (AttachBoxLabel).
local function addLabel(model: Model, anchor: BasePart, top: CFrame, payload: Payload, rarity: Rarity)
	local point = labelPoint(model, anchor, top)
	local gui: BillboardGui
	if payload.Kind == "PlayerItem" then
		gui = itemLabel(payload.ItemId, payload.Mutation, payload.Income, rarity, payload.Weight)
	else
		gui = itemLabel(payload.ItemId, payload.Mutation, npcItemIncome(payload), rarity, payload.Weight)
	end
	gui.Adornee = point
	gui.Parent = point
end

-- Contour rouge de l'objet volé, visible par tous (6.1) ; a483 : plus posé quand Shared/StolenOutline.VictimOnly().
local function addOutline(model: Model)
	local outline = Instance.new("Highlight")
	outline.Name = "StolenOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = OUTLINE_COLOR
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
end

-- a220 (L-210 point 3, Clément 2026-11-16 : « sur la tête, l'objet garde sa vraie taille, même énorme ») : le modèle
-- porté (et le même modèle tombé au sol) prend l'échelle de son poids, comme sur un présentoir (Mutations.Scale :
-- ItemWeight.ScaleFor, au plus Weight.DisplayMaxScale ; sans poids, sa mutation de taille), au plus
-- Weight.CarryMaxScale (1 = l'ancien rendu, taille du catalogue). Mise à l'échelle autour du pivot, avant les soudures ;
-- renvoie le point d'accroche `offset` (espace de la pièce d'accroche) à la nouvelle échelle. Échec : taille normale.
local function scaleVisual(model: Model, offset: CFrame, payload: Payload): CFrame
	local ok, value = pcall(Mutations.Scale, payload.Mutation, payload.Weight)
	local scale = if ok and type(value) == "number" and value == value and value > 0 and value < math.huge then value else 1
	scale = math.min(scale, WeightConfig.CarryMaxScale)
	if math.abs(scale - 1) < 1e-3 then
		return offset
	end
	local applied, problem = pcall(function()
		model:ScaleTo(model:GetScale() * scale)
	end)
	if not applied then
		once(`scale.{payload.ItemId}`, `[CarryService] {payload.ItemId} : Model:ScaleTo(×{scale}) a échoué ({problem}), taille normale`, true)
		return offset
	end
	return offset.Rotation + offset.Position * scale
end

-- Visuel complet d'un payload (modèle, teinte, halo, étiquette), pas encore placé ni parenté.
local function buildVisual(payload: Payload): Visual
	local rarity = Rarities.ById[payload.Rarity]
	-- Vague 50 (a158) : ce qui se porte est toujours un objet (ITM_<ItemId>) ; plus de colis BOX_ sur la tête.
	local assetName: string = Items.ById[payload.ItemId].Asset
	local model, anchor, offset, isPlaceholder = sourceModel(assetName)
	model.Name = VISUAL_NAME
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- arrive en entier chez les clients
	offset = scaleVisual(model, offset, payload) -- a220 : à la taille de son poids, avant le halo et l'étiquette
	prepare(model, anchor)
	-- Un objet garde ses couleurs ; seul le bloc V0 (pièce Tint) prend celle de la rareté.
	if isPlaceholder then
		tint(model, rarity.Color)
	end
	local height = model:GetExtentsSize().Y
	RarityHalo.AddCarried(anchor, offset * CFrame.new(0, height / 2, 0), rarity, RarityHalo.NoEffects)
	addLabel(model, anchor, offset * CFrame.new(0, height, 0), payload, rarity)
	if payload.Kind == "PlayerItem" and not stolenOutlineVictimOnly then -- a483 : sinon, posé par le client de la victime
		addOutline(model)
	end
	if rarity.Rainbow then
		CollectionService:AddTag(model, RAINBOW_TAG)
	end
	-- a119 (L-127 point 5) : un objet porté ou lâché montre sa mutation comme exposé ;
	-- MutationFxController (client) joue l'effet de Clément sur les modèles taggés CarriedItem.
	local mutation = Mutations.Sanitize(payload.Mutation)
	model:SetAttribute("MutationSize", if mutation then mutation.Size else nil)
	model:SetAttribute("MutationEffect", if mutation then mutation.Effect else nil)
	model:SetAttribute(WeightConfig.Attribute, ItemWeight.Sanitize(payload.Weight)) -- vague 62 (a203)
	CollectionService:AddTag(model, CARRIED_ITEM_TAG)
	return { model = model, anchor = anchor, offset = offset }
end

-- Déplace tout le visuel pour que son point d'accroche arrive sur `target` (CFrame monde).
local function place(visual: Visual, target: CFrame)
	local model = visual.model
	local anchorFromPivot = model:GetPivot():ToObjectSpace(visual.anchor.CFrame)
	model:PivotTo(target * visual.offset:Inverse() * anchorFromPivot:Inverse())
end

-- Soude le point d'accroche du visuel juste au-dessus de la tête (5.6 : soudé à la tête).
local function weldToHead(visual: Visual, head: BasePart)
	local headTop = CFrame.new(0, head.Size.Y / 2 + HEAD_GAP, 0)
	place(visual, head.CFrame * headTop)
	local weld = Instance.new("Weld")
	weld.Name = WELD_NAME
	weld.Part0 = head
	weld.Part1 = visual.anchor
	weld.C0 = headTop
	weld.C1 = visual.offset
	weld.Parent = visual.anchor
end

-- Portage -------------------------------------------------------------------------

-- Finit le portage en cours : retire visuel, malus et attribut, puis prévient les écouteurs.
-- Renvoie le payload, ou nil si le joueur ne portait rien.
local function finish(player: Player, result: EndResult, reason: string): Payload?
	local carry = carries[player]
	if carry == nil then
		return nil
	end
	carries[player] = nil
	for _, connection in carry.connections do
		connection:Disconnect()
	end
	carry.visual.model:Destroy()
	if result ~= "Dropped" then
		held[keyOf(carry.payload)] = nil -- un colis tombé au sol reste tenu (Drop)
	end
	player:SetAttribute(CARRYING_ATTRIBUTE, nil)
	if carry.payload.Kind == "PlayerItem" then
		StatsService.SetFixedSpeed(player, nil)
	else
		StatsService.SetSpeedModifier(player, SPEED_KEY, nil)
	end
	if IS_STUDIO then
		print(`[CarryService] {player.Name} : fin du portage, {result} ({reason})`)
	end
	for _, listener in table.clone(endedListeners) do
		task.spawn(listener, player, carry.payload, result, reason)
	end
	return carry.payload
end

-- Range l'outil tenu dans le Backpack (5.6 : ni outil ni batte en main pendant le portage).
local function stowTools(player: Player)
	local carry = carries[player]
	if carry and carry.humanoid.Parent ~= nil then
		carry.humanoid:UnequipTools()
	end
end

function CarryService.StartCarry(player: Player, payload: Payload): boolean
	if carries[player] ~= nil or player.Parent ~= Players then
		return false
	end
	local problem = invalidReason(payload)
	if problem then
		warn(debug.traceback(`[CarryService] StartCarry({player.Name}) refusé : {problem}`, 2))
		return false
	end
	if held[keyOf(payload)] then
		warn(debug.traceback(`[CarryService] StartCarry({player.Name}) refusé : {describe(payload)} déjà porté ou au sol`, 2))
		return false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local headInstance = if character then character:FindFirstChild("Head") else nil
	if
		character == nil
		or humanoid == nil
		or humanoid.Health <= 0
		or headInstance == nil
		or not headInstance:IsA("BasePart")
	then
		return false -- pas de personnage vivant : le colis reste où il est
	end
	local head = headInstance :: BasePart

	local visual = buildVisual(payload)
	weldToHead(visual, head)
	visual.model.Parent = character

	local carry: Carry = { payload = payload, humanoid = humanoid, visual = visual, connections = {} }
	carries[player] = carry
	held[keyOf(payload)] = true
	player:SetAttribute(CARRYING_ATTRIBUTE, payload.Rarity)
	applySpeed(player, payload)
	humanoid:UnequipTools()

	local connections = carry.connections
	table.insert(
		connections,
		humanoid.Died:Connect(function()
			finish(player, "Failed", "Died")
		end)
	)
	table.insert(
		connections,
		character.AncestryChanged:Connect(function()
			if not character:IsDescendantOf(Workspace) then
				finish(player, "Failed", if player.Parent == Players then "CharacterRemoved" else "Left")
			end
		end)
	)
	table.insert(
		connections,
		character.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Tool") then
				task.defer(stowTools, player) -- pas pendant l'événement : Roblox refuse de changer le parent
			end
		end)
	)

	if IS_STUDIO then
		print(`[CarryService] {player.Name} soulève : {describe(payload)}`)
	end
	for _, listener in table.clone(startedListeners) do
		task.spawn(listener, player, payload)
	end
	return true
end

function CarryService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
end

function CarryService.GetPayload(player: Player): Payload?
	local carry = carries[player]
	return if carry then carry.payload else nil
end

function CarryService.Consume(player: Player, reason: string?): Payload?
	return finish(player, "Consumed", reason or "Consumed")
end

-- Définies plus bas, avec les colis au sol : le colis ou l'objet porté tombe au sol.
local fall: (player: Player, carry: Carry, position: Vector3, reason: string) -> string
local groundBelow: (player: Player, humanoid: Humanoid) -> Vector3

function CarryService.Fail(player: Player, reason: string): boolean
	local text = if type(reason) == "string" and reason ~= "" then reason else "Unknown"
	local carry = carries[player]
	if carry ~= nil and carry.payload.Kind == "NPCItem" and text == CAUGHT_REASON and not backToShelf(player, carry) then
		-- L-112 : attrapé avec un objet sorti d'un colis, il le lâche ; l'objet reste au sol, à reprendre.
		local dropId = fall(player, carry, groundBelow(player, carry.humanoid), text)
		local drop = drops[dropId]
		if drop then
			drop.lockedFor = player
			drop.lockedUntil = os.clock() + Balance.Guard.CatchStunDuration
		end
		return true
	end
	return finish(player, "Failed", text) ~= nil
end

function CarryService.FailNoDrop(player: Player, reason: string): boolean
	local text = if type(reason) == "string" and reason ~= "" then reason else "Unknown"
	return finish(player, "Failed", text) ~= nil
end

function CarryService.SetBackToShelfCheck(check: ((player: Player) -> boolean)?)
	backToShelfCheck = check
end

function CarryService.ReportAnomaly(player: Player, detail: string): boolean
	if carries[player] == nil then
		return false
	end
	warn(`[CarryService] anomalie anti-triche de {player.Name} ({detail}) : colis rendu`)
	return CarryService.Fail(player, "Anomaly")
end

function CarryService.OnCarryStarted(listener: StartedListener): () -> ()
	return subscribe(startedListeners, listener)
end

function CarryService.OnCarryEnded(listener: EndedListener): () -> ()
	return subscribe(endedListeners, listener)
end

-- Étiquette BB_Box d'un colis qui n'est pas porté (colis du rayon, L-031) : voir l'en-tête.
-- Vague 32 : la rareté seule (celle de la caisse) ; `itemId` (nil : contenu pas encore tiré) et `mutation`
-- ne sont plus montrés (vague 53).
function CarryService.AttachBoxLabel(model: Model, rarityId: string, itemId: string?, _mutation: Mutations.Mutation?): BillboardGui?
	local rarity = Rarities.ById[rarityId]
	local item: Item? = if itemId ~= nil then Items.ById[itemId] else nil
	if rarity == nil or (itemId ~= nil and item == nil) then
		warn(debug.traceback(`[CarryService] AttachBoxLabel({model.Name}) : rareté « {rarityId} » ou objet « {tostring(itemId)} » inconnu`, 2))
		return nil
	end
	local anchor, offset = anchorOf(model)
	if anchor == nil then
		return nil
	end
	local point = labelPoint(model, anchor, offset * CFrame.new(0, model:GetExtentsSize().Y, 0))
	local gui = boxLabel(rarity)
	if rarity.Rainbow then
		CollectionService:AddTag(gui, RAINBOW_TAG) -- l'étiquette seule : le colis garde l'aspect de son type
	end
	gui.Adornee = point
	gui.Parent = point
	return gui
end

-- Objet au sol (DEV-048, L-112 : coup de batte, capture) ---------------------

-- Attribut posé sur un objet tombé au sol, lu par BatController (même nom là-bas).
local BAT_DROP_ATTRIBUTE = "BatDrop"

local function dropsFolder(): Instance
	local existing = Workspace:FindFirstChild(DROPS_FOLDER)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = DROPS_FOLDER
	folder.Parent = Workspace
	return folder
end

local function expire(dropId: string)
	local drop = drops[dropId]
	if drop == nil then
		return
	end
	drops[dropId] = nil
	held[keyOf(drop.payload)] = nil
	drop.visual.model:Destroy()
	if IS_STUDIO then
		print(`[CarryService] {dropId} : {drop.lifetime} s au sol sans preneur, retiré ({describe(drop.payload)})`)
	end
	for _, listener in table.clone(dropExpiredListeners) do
		task.spawn(listener, dropId, drop.payload, drop.position)
	end
end

local function isValidPosition(position: any): boolean
	return typeof(position) == "Vector3"
		and position == position -- pas de NaN
		and math.abs(position.X) < math.huge
		and math.abs(position.Y) < math.huge
		and math.abs(position.Z) < math.huge
end

-- Pied du porteur (repli d'un Drop sans position valide) : sous son HumanoidRootPart, sinon le
-- pivot de son personnage, sinon l'origine.
local function feetOf(player: Player, humanoid: Humanoid): Vector3
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	end
	return if character then character:GetPivot().Position else Vector3.zero
end

-- Colis au sol : visuel posé à `position` (point du sol), ancré, dans Workspace/CarryDrops, tenu
-- (held) jusqu'à sa prise ou son expiration au bout de `lifetime` secondes. Renvoie son dropId.
local function createDrop(payload: Payload, position: Vector3, lifetime: number, attributes: { [string]: any }?): string
	dropCount += 1
	local dropId = `Drop_{dropCount}`
	local visual = buildVisual(payload)
	place(visual, CFrame.new(position))
	visual.anchor.Anchored = true
	visual.model.Name = dropId
	if attributes then
		for name, value in attributes do
			visual.model:SetAttribute(name, value)
		end
	end
	visual.model:SetAttribute(DROP_ID_ATTRIBUTE, dropId)
	visual.model.Parent = dropsFolder()
	held[keyOf(payload)] = true
	drops[dropId] = {
		payload = payload,
		visual = visual,
		position = position,
		lifetime = lifetime,
		timer = task.delay(lifetime, expire, dropId),
		fallen = false,
		lockedFor = nil,
		lockedUntil = 0,
	}
	return dropId
end

-- Point du sol sous le porteur (là où tombe l'objet d'un joueur attrapé, L-112) : rayon vers le bas
-- qui ignore les personnages, les vigiles et les colis au sol ; à défaut, ses pieds.
function groundBelow(player: Player, humanoid: Humanoid): Vector3
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local exclude: { Instance } = {}
		for _, other in Players:GetPlayers() do
			local otherCharacter = other.Character
			if otherCharacter then
				table.insert(exclude, otherCharacter)
			end
		end
		for _, name in { ACTIVE_GUARDS, DROPS_FOLDER } do
			local folder = Workspace:FindFirstChild(name)
			if folder then
				table.insert(exclude, folder)
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		params.RespectCanCollide = true
		params.IgnoreWater = true
		local result = Workspace:Raycast(root.Position, Vector3.new(0, -GROUND_RAY_DOWN, 0), params)
		if result then
			return result.Position
		end
	end
	return feetOf(player, humanoid)
end

-- Le colis PNJ ou l'objet NPCItem porté tombe au sol à `position` (coup de batte : `reason` "Bat" ;
-- capture, L-112 : "Caught") : colis au sol de Bat.DroppedLifetime s, que BatController montre et que
-- GrabDropped ramasse (attribut BatDrop), puis OnCarryEnded(…, "Dropped", reason). Renvoie son dropId.
function fall(player: Player, carry: Carry, position: Vector3, reason: string): string
	local payload = carry.payload
	local attributes: { [string]: any } = { [BAT_DROP_ATTRIBUTE] = true }
	if payload.Kind == "NPCItem" then
		-- a107 : objet déjà visible, son nom va sur l'invite au sol (BatController), pas « Box ».
		local mutation = payload.Mutation
		attributes.ItemId = payload.ItemId
		attributes.MutationSize = if mutation then mutation.Size else nil
		attributes.MutationEffect = if mutation then mutation.Effect else nil
	end
	local dropId = createDrop(payload, position, Bat.DroppedLifetime, attributes)
	drops[dropId].fallen = true
	if IS_STUDIO then
		print(`[CarryService] {dropId} : {player.Name} lâche ({reason}), {describe(payload)} au sol pour {Bat.DroppedLifetime} s`)
	end
	finish(player, "Dropped", reason) -- reste tenu : il est au sol
	return dropId
end

function CarryService.Drop(player: Player, position: Vector3): string?
	local carry = carries[player]
	if carry == nil then
		return nil
	end
	local payload = carry.payload
	if payload.Kind == "PlayerItem" then
		CarryService.Fail(player, "Bat") -- 6.2 : l'objet revole vers le présentoir de son propriétaire
		return nil
	end
	if backToShelf(player, carry) then
		-- L-135 point 5 (Clément, 2026-11-14) : tombé dans son propre magasin, il revole sur son rayon.
		if IS_STUDIO then
			print(`[CarryService] {player.Name} lâche (Bat) dans le magasin de l'objet : {describe(payload)} revole sur son rayon`)
		end
		finish(player, "Failed", "Bat")
		return nil
	end
	local at = position
	if not isValidPosition(at) then
		warn(debug.traceback(`[CarryService] Drop({player.Name}) : position invalide ({position}), colis posé au pied du porteur`, 2))
		at = feetOf(player, carry.humanoid)
	end
	return fall(player, carry, at, "Bat")
end

function CarryService.PickUpDrop(player: Player, dropId: string): boolean
	local drop = if type(dropId) == "string" then drops[dropId] else nil
	if drop == nil or carries[player] ~= nil then
		return false
	end
	if drop.lockedFor == player and os.clock() < drop.lockedUntil then
		return false -- L-112 : il vient d'être attrapé, encore étourdi
	end
	-- Retiré du sol avant StartCarry (jamais deux exemplaires), remis si StartCarry refuse.
	local key = keyOf(drop.payload)
	drops[dropId] = nil
	held[key] = nil
	if not CarryService.StartCarry(player, drop.payload) then
		drops[dropId] = drop
		held[key] = true
		return false
	end
	task.cancel(drop.timer)
	drop.visual.model:Destroy()
	return true
end

function CarryService.IsFallenDrop(dropId: string): boolean
	local drop = if type(dropId) == "string" then drops[dropId] else nil
	return drop ~= nil and drop.fallen
end

function CarryService.GetDrop(dropId: string): (Payload?, Vector3?)
	local drop = if type(dropId) == "string" then drops[dropId] else nil
	if drop == nil then
		return nil, nil
	end
	return drop.payload, drop.position
end

function CarryService.PlaceItemDrop(payload: Payload, position: Vector3, lifetime: number): (string?, Model?)
	local problem = invalidReason(payload)
	if problem == nil and payload.Kind ~= "NPCItem" then
		problem = "seul un objet NPCItem se pose au sol sans porteur"
	elseif problem == nil and held[keyOf(payload)] then
		problem = `{describe(payload)} déjà porté ou au sol`
	elseif problem == nil and not isValidPosition(position) then
		problem = `position invalide ({position})`
	elseif problem == nil and not (type(lifetime) == "number" and lifetime > 0 and lifetime < math.huge) then
		problem = `durée au sol invalide ({lifetime})`
	end
	if problem then
		warn(debug.traceback(`[CarryService] PlaceItemDrop refusé : {problem}`, 2))
		return nil, nil
	end
	local mutation = payload.Mutation
	local dropId = createDrop(payload, position, lifetime, {
		[BAT_DROP_ATTRIBUTE] = true,
		ItemId = payload.ItemId,
		MutationSize = if mutation then mutation.Size else nil,
		MutationEffect = if mutation then mutation.Effect else nil,
	})
	local drop = drops[dropId]
	drop.fallen = true -- se ramasse par GrabDropped, comme un objet tombé des mains (BatService)
	if IS_STUDIO then
		print(`[CarryService] {dropId} : {describe(payload)} posé au sol sans porteur pour {lifetime} s`)
	end
	return dropId, drop.visual.model
end

function CarryService.Transfer(from: Player, to: Player, reason: string): boolean
	local carry = carries[from]
	if carry == nil or carry.payload.Kind ~= "NPCItem" or from == to or carries[to] ~= nil or to.Parent ~= Players then
		return false
	end
	local character = to.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local head = if character then character:FindFirstChild("Head") else nil
	if character == nil or not character:IsDescendantOf(Workspace) or humanoid == nil or humanoid.Health <= 0 or head == nil or not head:IsA("BasePart") then
		return false
	end
	local text = if type(reason) == "string" and reason ~= "" then reason else "Transfer"
	local feet = feetOf(from, carry.humanoid)
	local payload = finish(from, "Dropped", text) :: Payload
	held[keyOf(payload)] = nil -- « Dropped » le laisse tenu : il ne touche pas le sol
	if CarryService.StartCarry(to, payload) then
		return true
	end
	-- Secours (tout est vérifié plus haut) : l'objet tombe aux pieds de `from`, à reprendre comme après une chute.
	CarryService.PlaceItemDrop(payload, feet, Bat.DroppedLifetime)
	return false
end

function CarryService.OnDropExpired(listener: DropExpiredListener): () -> ()
	return subscribe(dropExpiredListeners, listener)
end

function CarryService.Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		finish(player, "Failed", "Left")
	end)
end

return CarryService
