--!strict
-- CarryService (DEV-017) : le colis ou l'objet porté au-dessus de la tête (Partie 1, sections
-- 5.6, 5.5, 6.1, 6.2, 9.3, 9.4 et 9.6).
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
-- Payload (Shared/Types/Carry) : { Kind = "NPCBox", Tier, Zone, Rarity, ItemId, StoreId, SlotId, Mutation? }
-- pour un colis PNJ ; { Kind = "PlayerItem", ItemUid, ItemId, Rarity, Income, VictimUserId,
-- SlotIndex } pour un objet volé à un joueur (DEV-041, PvPService : malus −25 %, contour rouge,
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
--       a113 (Cantin, 2026-11-13) : Drop(player, position?, reason?). `position` nil = le point du sol sous
--       le porteur ; `reason` (défaut "Bat") est la raison passée à OnCarryEnded (et à Fail pour un objet
--       volé). DropService passe nil et "Released" quand le joueur lâche lui-même (remote DropCarried) :
--       même colis au sol, même délai, même vigile qui le suit qu'après un coup de batte.
--   CarryService.PickUpDrop(player, dropId) -> boolean
--       Ramassage d'un colis au sol (GrabDropped, 9.4) : le nouveau porteur reçoit le même payload
--       (même table : même rareté, même objet caché, 6.2), par StartCarry ; le colis quitte le sol
--       avant (jamais deux exemplaires) et y revient si StartCarry refuse. L'appelant vérifie avant
--       la distance, le temps de prise, la zone safe et les protections (BatService, TruckEventService).
--   CarryService.IsFallenDrop(dropId) -> boolean
--       true si `dropId` est encore au sol et y est tombé des mains d'un porteur (Drop, ou Fail
--       "Caught" d'un objet NPCItem), pas posé par PlaceDrop : BatService accepte alors GrabDropped.
--   CarryService.GetDrop(dropId) -> (Payload?, Vector3?)
--       Payload et position (point du sol) d'un colis encore au sol ; nil, nil sinon (ramassé,
--       expiré, inconnu, ou dropId qui n'est pas une chaîne).
--   CarryService.OnDropExpired(listener) -> déconnexion
--       listener(dropId, payload, position) quand un colis reste au sol sans être ramassé :
--       Bat.DroppedLifetime secondes (6.2 : 15 s) après un coup de batte, le `lifetime` de PlaceDrop
--       sinon. Le modèle est déjà retiré et GetDrop(dropId) vaut nil. StoreHeistService remet alors
--       sur son rayon un colis de magasin (vol depuis `position`) ; un colis du camion disparaît.
--   Événement camion (liaison L-049, TruckEventService) :
--   CarryService.PlaceDrop(payload, position, lifetime?, attributes?) -> string?
--       Pose au sol à `position` un colis PNJ qu'aucun joueur ne porte : le même colis au sol que
--       Drop (couleur, halo, BB_Box, Workspace/CarryDrops, attribut DropId, PickUpDrop, GetDrop),
--       sans OnCarryEnded. Il expire (OnDropExpired, modèle retiré) au bout de `lifetime` secondes
--       (défaut Bat.DroppedLifetime). `attributes` : posés sur le modèle avant qu'il entre dans la map
--       (lus par le client ; DropId ne se remplace pas). Renvoie le dropId ; nil, avec un
--       avertissement, si le payload est invalide, déjà porté ou au sol, ou n'est pas un colis PNJ.
--   Étiquette des colis du rayon (L-031) :
--   CarryService.AttachBoxLabel(model, rarityId, itemId?, mutation?) -> BillboardGui?
--       Pose sur `model`, un colis qui n'est pas porté (StoreHeistService : chaque colis du rayon),
--       la même étiquette BB_Box que sur la tête (voir plus bas), à son LabelPoint. itemId nil (vague 32,
--       Features.ShelfOpen : caisse dont le contenu n'est tiré qu'à l'ouverture) : rareté seule. Secret : tag
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
--       sur le rayon : Category = catégorie de l'objet (Items, ligne cachée tant qu'elle est vide),
--       Rarity = nom de la rareté en capitales (« LEGENDARY ») à sa couleur, Mutation = la mutation
--       du payload en capitales (DEV-131, Mutations.Label : « BIG · GOLD »), cachée sans mutation.
--       Vague 32 (Cantin, 2026-11-13), avec Features.ShelfOpen : sur une caisse (rayon, portée, au sol),
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
local Features = require(Shared.Config.Features)
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local ShelfBoxes = require(Shared.Config.ShelfBoxes)
local Zones = require(Shared.Config.Zones)
local Find = require(Shared.Contract.Find)
local UI = require(Shared.Contract.UI)
local Format = require(Shared.Format)
local CarryTypes = require(Shared.Types.Carry)

local StatsService = require(script.Parent.StatsService)

type Payload = CarryTypes.Payload
type NPCItemPayload = CarryTypes.NPCItemPayload
type EndResult = CarryTypes.EndResult
type Rarity = Rarities.Rarity
type Item = Items.Item

-- Noms du contrat (10.4 et 2.2).
local ASSETS_FOLDER = "Assets"
local BOX_PREFIX = "BOX_"
local CARRY_ATTACHMENT = "CarryAttachment"
local TINT = "Tint"
local BB_CARRY = "BB_Carry" -- objet volé à un joueur
local BB_BOX = "BB_Box" -- colis PNJ, sur le rayon comme sur la tête (L-031)
-- Champ de la mutation : au contrat de BB_Box ; facultatif dans BB_Carry (nom proposé à Clément, DEV-131).
local MUTATION_FIELD = "Mutation"
-- Vague 32 (Cantin, 2026-11-13), Features.ShelfOpen : sur une caisse (rayon, portée ou au sol), BB_Box ne
-- montre que sa rareté ; la catégorie et la mutation n'apparaissent qu'une fois l'objet sorti (BB_Item).
local BOX_LABEL_RARITY_ONLY: boolean = Features.ShelfOpen == true
-- Noms posés par ce service (mêmes noms dans CarryController pour l'attribut et le tag).
local CARRYING_ATTRIBUTE = "Carrying"
local SPEED_KEY = "Carry"
local RAINBOW_TAG = "CarryRainbow"
local VISUAL_NAME = "CarryVisual"
local WELD_NAME = "CarryWeld"
local HALO_POINT = "HaloPoint"
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
-- V0 proposé, absent du doc : blocs gris tant que BOX_<Tier> ou ITM_<ItemId> n'est pas livré.
local PLACEHOLDER_BOX_SIZE = Vector3.new(2, 1.6, 2)
local PLACEHOLDER_ITEM_SIZE = Vector3.new(1.2, 1.2, 1.2)
-- V0 proposé, absent du doc : contour de l'objet volé (6.1), rouge « fermer » de la planche 10.6.
local OUTLINE_COLOR = Color3.fromHex("#E8413C")
-- V0 proposé, absent du doc : contour du texte de l'étiquette V0 (couleur de contour de 10.6).
local TEXT_STROKE_COLOR = Color3.fromHex("#1B1B24")
-- V0 proposé, absent du doc : texture de particules livrée avec Roblox (aucun asset publié).
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- V0 proposé, absent du doc : intensité de chaque palier de halo (Rarities.Halo). Le doc dit
-- seulement « plus denses à chaque palier » ; Commun (None) n'a rien.
type HaloSpec = {
	LightRange: number, -- studs
	LightBrightness: number,
	ParticleRate: number, -- particules par seconde
	ParticleSize: number, -- studs
	Rays: boolean, -- rayons de lumière autour du colis
}
local HALOS: { [string]: HaloSpec } = {
	Light = { LightRange = 6, LightBrightness = 1, ParticleRate = 4, ParticleSize = 0.25, Rays = false },
	Clear = { LightRange = 10, LightBrightness = 2, ParticleRate = 10, ParticleSize = 0.35, Rays = false },
	Rays = { LightRange = 14, LightBrightness = 3, ParticleRate = 14, ParticleSize = 0.4, Rays = true },
	Rainbow = { LightRange = 16, LightBrightness = 3, ParticleRate = 20, ParticleSize = 0.45, Rays = true },
	Divine = { LightRange = 18, LightBrightness = 3.5, ParticleRate = 24, ParticleSize = 0.5, Rays = true }, -- L-106
}
-- V0 proposé, absent du doc : 8 rayons vers les coins d'un cube ; longueur et largeur en studs.
local RAY_LENGTH = 2.6
local RAY_WIDTH = 0.35
local RAY_DIRECTIONS: { Vector3 } = {}
for _, x in { -1, 1 } do
	for _, y in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(RAY_DIRECTIONS, Vector3.new(x, y, z).Unit)
		end
	end
end

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
	fallen: boolean, -- tombé des mains d'un porteur (Drop, capture), pas posé par PlaceDrop
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
	if payload.Kind == "NPCBox" then
		return `colis {payload.Tier} {payload.Rarity} ({payload.StoreId}, {payload.SlotId})`
	elseif payload.Kind == "NPCItem" then
		return `objet {payload.ItemId} ({payload.Rarity}) sorti d'un colis ({payload.StoreId}, {payload.SlotId})`
	end
	return `objet {payload.ItemId} ({payload.Rarity}) du joueur {payload.VictimUserId}`
end

local function speedMultiplier(payload: Payload): number
	if payload.Kind == "PlayerItem" then
		return Balance.Carry.StolenItemSpeedMultiplier -- −25 % (6.1)
	end
	return Balance.Carry.NPCBoxSpeedMultiplier -- −10 % (5.6) : colis PNJ, et objet sorti d'un colis (L-112)
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
	if payload.Kind == "NPCBox" or payload.Kind == "NPCItem" then
		if payload.Kind == "NPCBox" and Balance.Heist.BoxTiers[payload.Tier] == nil then
			return `type de colis inconnu ({payload.Tier})`
		end
		local luck = payload.Luck
		if payload.Kind == "NPCItem" and (type(luck) ~= "number" or not (luck >= 1) or luck == math.huge) then
			return `chance invalide ({luck})`
		end
		if not isInteger(payload.Zone) or Zones[payload.Zone] == nil then
			return `zone inconnue ({payload.Zone})`
		end
		-- Colis : son objet est de la zone du magasin. Objet sorti (L-112) : le tirage de la sortie peut le
		-- prendre dans une zone voisine (StoreHeistService, vague 32), Zone reste celle du magasin.
		if payload.Kind == "NPCBox" and item.Zone ~= nil and item.Zone ~= payload.Zone then
			return `{item.Id} est un objet de la zone {item.Zone}, pas de la zone {payload.Zone}`
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
local function sourceModel(payload: Payload, assetName: string): (Model, BasePart, CFrame, boolean)
	local model = cloneAsset(assetName)
	if model then
		local anchor, offset = anchorOf(model)
		if anchor then
			return model, anchor, offset, false
		end
		once(`{assetName}.anchor`, `[CarryService] {assetName} ne contient aucune pièce : bloc V0 à la place`, true)
		model:Destroy()
	end
	local block, part, offset = placeholder(if payload.Kind == "NPCBox" then PLACEHOLDER_BOX_SIZE else PLACEHOLDER_ITEM_SIZE)
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

local function colorSequence(rarity: Rarity): ColorSequence
	local colors = rarity.RainbowColors
	if rarity.Rainbow and colors and #colors >= 2 then
		local keypoints: { ColorSequenceKeypoint } = {}
		for index, color in colors do
			table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
		end
		return ColorSequence.new(keypoints)
	end
	return ColorSequence.new(rarity.Color)
end

-- Effets déjà posés par Clément dans un modèle BOX_<Rareté> (L-097 point 3 : Épique, une lumière Glow ;
-- Légendaire et plus, des étincelles Sparkles et Glow dans Body) : le halo du code ne les double pas.
type OwnEffects = { Light: boolean, Particles: boolean, Beams: boolean }
local NO_EFFECTS: OwnEffects = { Light = false, Particles = false, Beams = false }

local function ownEffects(model: Model): OwnEffects
	local found: OwnEffects = { Light = false, Particles = false, Beams = false }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Light") then
			found.Light = true
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Sparkles") then
			found.Particles = true
		elseif descendant:IsA("Beam") then
			found.Beams = true
		end
	end
	return found
end

-- Halo de rareté (5.6) autour de `center` (CFrame dans l'espace de anchor). `own` : effets que le modèle
-- a déjà (choix d'a79, L-097 point 3) : sa lumière remplace celle du halo, ses particules les
-- étincelles du halo, ses Beams les rayons ; le reste du halo est posé comme avant.
local function addHalo(anchor: BasePart, center: CFrame, rarity: Rarity, own: OwnEffects)
	local spec = HALOS[rarity.Halo]
	if spec == nil then
		return -- Commun : aucun halo
	end
	local wantsRays = spec.Rays and not own.Beams
	if own.Light and own.Particles and not wantsRays then
		return -- le modèle a déjà tout le halo
	end
	local colors = colorSequence(rarity)
	local point = Instance.new("Attachment")
	point.Name = HALO_POINT
	point.CFrame = center
	point.Parent = anchor

	if not own.Light then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = spec.LightRange
		light.Brightness = spec.LightBrightness
		light.Shadows = false
		light.Parent = point
	end

	if not own.Particles then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "HaloSparkles"
		sparkles.Texture = SPARKLE_TEXTURE
		sparkles.Color = colors
		sparkles.LightEmission = 1
		sparkles.LightInfluence = 0
		sparkles.Rate = spec.ParticleRate
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(1.5, 2.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(spec.ParticleSize, 0)
		sparkles.Transparency = NumberSequence.new(0.1, 1)
		sparkles.LockedToPart = true -- un halo qui suit le colis, pas une traînée
		sparkles.Parent = point
	end

	if not wantsRays then
		return
	end
	for index, direction in RAY_DIRECTIONS do
		local tip = Instance.new("Attachment")
		tip.Name = `HaloRayTip_{index}`
		tip.CFrame = center * CFrame.new(direction * RAY_LENGTH)
		tip.Parent = anchor
		local ray = Instance.new("Beam")
		ray.Name = `HaloRay_{index}`
		ray.Attachment0 = point
		ray.Attachment1 = tip
		ray.FaceCamera = true
		ray.Color = colors
		ray.LightEmission = 1
		ray.LightInfluence = 0
		ray.Width0 = RAY_WIDTH
		ray.Width1 = 0
		ray.Transparency = NumberSequence.new(0.15, 1)
		ray.Segments = 1
		ray.Parent = point
	end
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

-- Étiquette BB_Box d'un colis PNJ (L-031), sur le rayon comme sur la tête : la catégorie de
-- l'objet (ligne cachée tant qu'elle est vide), la rareté à sa couleur, la mutation (DEV-131,
-- « BIG · GOLD », cachée sans mutation). Jamais le nom ni l'ItemId de l'objet (5.7).
-- Vague 32 : avec Features.ShelfOpen (BOX_LABEL_RARITY_ONLY), ou sans objet (`item` nil : caisse du rayon
-- dont le contenu n'est pas encore tiré), la rareté seule : lignes Category et Mutation cachées.
local function boxLabel(rarity: Rarity, item: Item?, mutation: Mutations.Mutation?): BillboardGui
	local template = labelTemplate(BB_BOX)
	local gui = if template then template:Clone() :: BillboardGui else placeholderLabel(ShelfBoxes.V0LabelMaxDistance)
	gui.Name = BB_BOX
	local shown: Item? = if BOX_LABEL_RARITY_ONLY then nil else item
	local category = if shown then shown.Category else nil
	fill(gui, "Category", if category ~= nil and category ~= "" then category else nil)
	fill(gui, "Rarity", rarity.DisplayNameUpper, rarity.Color)
	fill(gui, "Mutation", if shown then Mutations.Label(mutation) else nil)
	return gui
end

-- $/s d'un objet sorti d'un colis (L-112), comme une fois exposé (DisplayService) : revenu de sa zone
-- (celle du magasin pour un Secret, qui n'a pas de zone) et de sa rareté, mutation comprise.
local function npcItemIncome(payload: NPCItemPayload): number
	local item = Items.ById[payload.ItemId]
	return Formulas.ItemIncome(item.Zone or payload.Zone, payload.Rarity) * Mutations.IncomeMultiplier(payload.Mutation)
end

-- Étiquette BB_Carry d'un objet porté (objet volé à un joueur, 6.1 ; objet sorti d'un colis, L-112) :
-- nom (précédé de sa mutation, DEV-131), rareté à sa couleur, $/s. Champ Mutation facultatif, hors
-- contrat tant que Clément ne l'a pas créé : s'il existe, la mutation y va en capitales et ItemName
-- garde le nom seul.
local function itemLabel(itemId: string, mutation: Mutations.Mutation?, income: number, rarity: Rarity): BillboardGui
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
	return gui
end

-- Étiquette au-dessus du visuel (voir labelPoint) : BB_Box pour un colis PNJ, BB_Carry pour un
-- objet (volé à un joueur, ou sorti d'un colis).
local function addLabel(model: Model, anchor: BasePart, top: CFrame, payload: Payload, rarity: Rarity)
	local point = labelPoint(model, anchor, top)
	local gui: BillboardGui
	if payload.Kind == "NPCBox" then
		gui = boxLabel(rarity, Items.ById[payload.ItemId], payload.Mutation)
	elseif payload.Kind == "PlayerItem" then
		gui = itemLabel(payload.ItemId, payload.Mutation, payload.Income, rarity)
	else
		gui = itemLabel(payload.ItemId, payload.Mutation, npcItemIncome(payload), rarity)
	end
	gui.Adornee = point
	gui.Parent = point
end

-- Contour rouge de l'objet volé, visible par tous (6.1).
local function addOutline(model: Model)
	local outline = Instance.new("Highlight")
	outline.Name = "StolenOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = OUTLINE_COLOR
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
end

-- Visuel complet d'un payload (modèle, teinte, halo, étiquette), pas encore placé ni parenté.
local function buildVisual(payload: Payload): Visual
	local rarity = Rarities.ById[payload.Rarity]
	local assetName: string
	-- Colis PNJ : BOX_<Rareté> de Clément (L-097 point 3), déjà à la couleur de sa rareté, sinon BOX_<Tier>.
	local byRarity = false
	if payload.Kind == "NPCBox" then
		local rarityName = BOX_PREFIX .. payload.Rarity
		byRarity = findAsset(rarityName) ~= nil
		assetName = if byRarity then rarityName else BOX_PREFIX .. payload.Tier
	else
		assetName = Items.ById[payload.ItemId].Asset
	end
	local model, anchor, offset, isPlaceholder = sourceModel(payload, assetName)
	model.Name = VISUAL_NAME
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- arrive en entier chez les clients
	prepare(model, anchor)
	-- Un objet volé garde ses couleurs, BOX_<Rareté> aussi (Tint déjà à la couleur, choix de Clément) ;
	-- BOX_<Tier> et le bloc V0 prennent celle de la rareté.
	local paint = isPlaceholder or (payload.Kind == "NPCBox" and not byRarity)
	if paint and tint(model, rarity.Color) == 0 then
		once(`{assetName}.{TINT}`, `[CarryService] {assetName} : aucune pièce {TINT} (10.4), colis pas teint à la couleur de sa rareté`, true)
	end
	local height = model:GetExtentsSize().Y
	local own = if payload.Kind == "NPCBox" and not isPlaceholder then ownEffects(model) else NO_EFFECTS
	addHalo(anchor, offset * CFrame.new(0, height / 2, 0), rarity, own)
	addLabel(model, anchor, offset * CFrame.new(0, height, 0), payload, rarity)
	if payload.Kind == "PlayerItem" then
		addOutline(model)
	end
	if rarity.Rainbow then
		CollectionService:AddTag(model, RAINBOW_TAG)
	end
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
	StatsService.SetSpeedModifier(player, SPEED_KEY, nil)
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
	StatsService.SetSpeedModifier(player, SPEED_KEY, speedMultiplier(payload))
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
	if carry ~= nil and carry.payload.Kind == "NPCItem" and text == CAUGHT_REASON then
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
-- Vague 32 : `itemId` nil = caisse dont le contenu n'est pas encore tiré (Features.ShelfOpen) : la rareté
-- seule (celle de la caisse).
function CarryService.AttachBoxLabel(model: Model, rarityId: string, itemId: string?, mutation: Mutations.Mutation?): BillboardGui?
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
	local gui = boxLabel(rarity, item, Mutations.Sanitize(mutation))
	if rarity.Rainbow then
		CollectionService:AddTag(gui, RAINBOW_TAG) -- l'étiquette seule : le colis garde l'aspect de son type
	end
	gui.Adornee = point
	gui.Parent = point
	return gui
end

-- Colis au sol (DEV-048 : coup de batte, BatService ; camion : PlaceDrop) ------------

-- Attributs posés sur un colis tombé après un coup de batte, lus par BatController (même nom là-bas).
local TIER_ATTRIBUTE = "Tier"
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
	if payload.Kind == "NPCBox" then
		attributes[TIER_ATTRIBUTE] = payload.Tier
	elseif payload.Kind == "NPCItem" then
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

function CarryService.Drop(player: Player, position: Vector3?, reason: string?): string?
	local carry = carries[player]
	if carry == nil then
		return nil
	end
	local why = if type(reason) == "string" and reason ~= "" then reason else "Bat"
	local payload = carry.payload
	if payload.Kind == "PlayerItem" then
		CarryService.Fail(player, why) -- 6.2 : l'objet revole vers le présentoir de son propriétaire
		return nil
	end
	local at: Vector3
	if position == nil then
		at = groundBelow(player, carry.humanoid) -- a113 : lâché par le joueur, au sol sous lui
	elseif isValidPosition(position) then
		at = position
	else
		warn(debug.traceback(`[CarryService] Drop({player.Name}) : position invalide ({position}), colis posé au pied du porteur`, 2))
		at = feetOf(player, carry.humanoid)
	end
	return fall(player, carry, at, why)
end

function CarryService.PlaceDrop(payload: Payload, position: Vector3, lifetime: number?, attributes: { [string]: any }?): string?
	local problem = invalidReason(payload)
	if problem == nil and payload.Kind ~= "NPCBox" then
		problem = "seul un colis PNJ se pose au sol (6.2)"
	end
	if problem == nil and held[keyOf(payload)] then
		problem = `{describe(payload)} déjà porté ou au sol`
	end
	if problem == nil and (typeof(position) ~= "Vector3" or position ~= position) then
		problem = `position invalide ({position})`
	end
	if problem then
		warn(debug.traceback(`[CarryService] PlaceDrop refusé : {problem}`, 2))
		return nil
	end
	local seconds = if type(lifetime) == "number" and lifetime > 0 and lifetime < math.huge then lifetime else Bat.DroppedLifetime
	local dropId = createDrop(payload, position, seconds, attributes)
	if IS_STUDIO then
		print(`[CarryService] {dropId} posé au sol sans porteur pour {seconds} s : {describe(payload)}`)
	end
	return dropId
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

function CarryService.OnDropExpired(listener: DropExpiredListener): () -> ()
	return subscribe(dropExpiredListeners, listener)
end

function CarryService.Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		finish(player, "Failed", "Left")
	end)
end

return CarryService
