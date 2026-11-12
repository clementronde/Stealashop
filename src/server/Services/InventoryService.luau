--!strict
-- InventoryService (L-079, L-089 points 1 et 3, L-091 point 6) : l'inventaire du joueur, montré par
-- l'écran UI_Inventory de Clément (InventoryController), qui remplace toute la barre d'outils de Roblox
-- (Partie 1, sections 5.6, 5.8 et 9.5).
--
-- Depuis la vague 21 (décision de Clément du 2026-11-10, L-079) : plus de barre Roblox, plus de Tool
-- pour les colis et les objets. Avant (vague 18), chaque colis de l'inventaire et chaque objet non exposé
-- était un Tool tenu en main ; on ne voyait ni rareté, ni mutation, ni revenu. Choix : leurs Tools sont
-- retirés plutôt que gardés cachés. Ils ne servaient plus à rien (le Backpack n'est plus montré, l'écran
-- montre tout et ses boutons envoient des uid), ils coûtaient une copie de modèle par objet et par colis
-- refaite à chaque apparition, et le serveur n'a jamais cru le Tool : chaque action revérifie l'uid dans
-- le profil. L'outil de casse et la batte restent des Tools (ToolService), tenus en main ; le joueur les
-- choisit depuis l'écran ou par les touches 1 et 2 (InventoryController).
--
-- Le profil fait foi : ce service en tire l'état de l'écran, l'écrit dans l'attribut InventoryState du
-- Player (texte de Shared/InventoryState) deux fois par seconde s'il a changé, et tout de suite à chaque
-- Refresh (DisplayService et UnboxService l'appellent après chaque changement) :
--   - objets : Items[uid] connus du catalogue, ni au coffre-fort (Vault), ni retenus (HoldBack plus bas),
--     les plus rentables d'abord ; chacun avec son revenu ($/s de l'objet, mutation comprise, sans bonus,
--     règle de DisplayService : zone du catalogue, sinon celle de l'objet, sinon 1), son présentoir s'il
--     est exposé (Display), sa mutation (Config/Mutations) ;
--   - colis : Boxes[uid] lisibles (type et rareté connus), ceux de l'inventaire d'abord (les plus anciens
--     d'abord, At), puis ceux posés au sol (les plus tôt prêts d'abord, ReadyAt). Jamais leur ItemId (5.7).
-- Un objet tout juste sorti d'un colis n'apparaît qu'à sa révélation (HoldBack, UnboxService).
-- Vague 31 (L-112, Features.ShelfOpen) : un objet sous antivol (Items[uid].AntiTheft) est marqué dans l'état
-- (AntiTheft) tant qu'il est dans l'inventaire : l'écran le pose au sol (PlaceBox), PlaceItemAuto le refuse
-- (Notify « Warning »). Posé au sol (Spot), il n'est plus dans l'état : UnboxService l'affiche au sol.
--
-- Remotes de l'écran (ajouts de la vague 21, absents du tableau 9.4 ; forme et débit contrôlés par Net) :
--   PlaceItemAuto(itemUid)  bouton PlaceButton d'un objet de l'inventaire : il va sur le présentoir libre
--       et débloqué le plus proche du personnage, sinon le premier libre (DisplayService.PlaceAuto, règle
--       V0 proposée, absente du doc), où que soit le joueur (comme Equip Best). Vérifié ici : profil
--       chargé, objet à lui et connu du catalogue, pas au coffre-fort, pas déjà exposé, pas tenu par un
--       voleur, une boutique, un présentoir libre. Réussite : Notify « Info » ; refus honnête : Notify
--       « Warning » ; envoi malhonnête (uid qui n'est pas à lui) : ignoré, une ligne en Studio.
--   UnplaceItem(itemUid)    bouton UnequipButton d'un objet exposé : il retourne dans l'inventaire
--       (DisplayService.Unplace). Vérifié ici : objet à lui et exposé, pas tenu par un voleur (6.1 :
--       l'objet volé reste où il est), de la place dans l'inventaire (moins de
--       Balance.Display.InventoryMax objets non exposés, 5.8). Mêmes réponses.
-- DisplayService est chargé au premier appel (il charge lui-même ce service à son démarrage : pas de
-- require croisé au chargement).
--
-- API (côté serveur) :
--   InventoryService.Refresh(player)
--       Réécrit tout de suite l'attribut InventoryState (après un changement de Boxes, Items, Display).
--       Sans yield. Sinon, la boucle le fait au plus SYNC_INTERVAL s plus tard.
--   InventoryService.HoldBack(player, itemUid, seconds)
--       Cet objet n'apparaît pas dans l'état avant `seconds` s (objet ouvert, pas encore révélé chez le
--       joueur : son nom en dirait trop). Sans yield.
--   InventoryService.GetState(player) -> InventoryState.State
--       L'état écrit en ce moment (bancs d'essai).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Features = require(Shared.Config.Features)
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local InventoryState = require(Shared.InventoryState)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)
local DataService = require(script.Parent.DataService)

type Data = ProfileTypes.Data
type ItemEntry = InventoryState.ItemEntry
type BoxEntry = InventoryState.BoxEntry

-- Ce que ce service utilise de DisplayService (a14, a46, a51).
type DisplayApi = {
	PlaceAuto: (player: Player, itemUid: string, near: Vector3?) -> number?,
	Unplace: (player: Player, itemUid: string) -> number?,
	IsHeld: (player: Player, itemUid: string) -> boolean,
	HasInventoryRoom: (player: Player) -> boolean,
}
-- Et de PlotService (a06).
type PlotApi = {
	GetPlot: (player: Player) -> Model?,
}

type State = {
	holdUntil: { [string]: number }, -- [itemUid] = os.clock() avant lequel l'objet n'est pas montré
	written: string?, -- dernier texte écrit dans l'attribut
}

-- Avant leur tri.
type SortedItem = { entry: ItemEntry, income: number }
type SortedBox = { entry: BoxEntry, key: number }

-- V0 proposé, absent du doc : cadence (s) de la remise d'accord avec le profil.
local SYNC_INTERVAL = 0.5
-- Catégories des Notify (comme DisplayService et UnboxService).
local INFO_KIND = "Info"
local WARNING_KIND = "Warning"
-- Messages lus par le joueur, en anglais (L-036). V0 proposés, absents du doc : Placed, Removed et
-- DisplaysFull reprennent les textes du prototype de Clément (tools/clement/inventory_proto.luau) ;
-- NoShop et Held, ceux de DisplayService.
local MESSAGES = {
	Placed = "%s placed on a display!", -- %s = nom de l'objet, mutation devant (« Big Gold Soda Can »)
	Removed = "%s removed from its display",
	DisplaysFull = "All your displays are full!",
	InventoryFull = "Your inventory is full: display or sell an item first.",
	NoShop = "You don't have a shop yet: wait for one to free up.",
	Held = "This item is being stolen: hit the thief to get it back!",
	-- Vague 31 (L-112), V0 proposé, absent du doc : objet sous antivol, à poser au sol avant un présentoir.
	AntiTheft = "Put this item down in your shop first: it can go on a display once UNLOCKED!",
}

local IS_STUDIO = RunService:IsStudio()

local InventoryService = {}

local states: { [Player]: State } = {}
local noticed: { [string]: boolean } = {}
local displayApi: DisplayApi? = nil
local plotApi: PlotApi? = nil

local function once(key: string, message: string)
	if noticed[key] then
		return
	end
	noticed[key] = true
	if IS_STUDIO then
		print(`[InventoryService] {message}`)
	end
end

local function log(message: string)
	if IS_STUDIO then
		print(`[InventoryService] {message}`)
	end
end

local function stateOf(player: Player): State
	local existing = states[player]
	if existing then
		return existing
	end
	local state: State = { holdUntil = {}, written = nil }
	states[player] = state
	return state
end

-- Service voisin chargé au premier appel (nil s'il manque, banc d'essai).
local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" then
		return result
	end
	once(`require:{name}`, `{name} pas chargé : {result}`)
	return nil
end

local function display(): DisplayApi?
	if displayApi == nil then
		displayApi = sibling("DisplayService")
	end
	return displayApi
end

local function plots(): PlotApi?
	if plotApi == nil then
		plotApi = sibling("PlotService")
	end
	return plotApi
end

------------------------------------------------------------------------------
-- État de l'écran, tiré du profil
------------------------------------------------------------------------------

local function validZone(value: any): number?
	if type(value) == "number" and value % 1 == 0 and Zones[value] ~= nil then
		return value
	end
	return nil
end

-- Revenu d'un objet ($/s, sans bonus), même règle que DisplayService (7.1).
local function incomeOf(entry: ProfileTypes.Item, def: Items.Item): number
	local zone = def.Zone or validZone((entry :: any).Zone) or 1
	return Formulas.ItemIncome(zone, def.Rarity) * Mutations.IncomeMultiplier(entry.Mutation)
end

local function boxIsReadable(box: any): boolean
	return type(box) == "table"
		and type(box.Tier) == "string"
		and Balance.Heist.BoxTiers[box.Tier] ~= nil
		and type(box.Rarity) == "string"
		and Rarities.ById[box.Rarity] ~= nil
end

local function finiteOr(value: any, default: number): number
	if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
		return value
	end
	return default
end

-- Vague 31 (L-112, Features.ShelfOpen) : objet sous antivol (Types/Profile : AntiTheft, UnlockAt, Spot).
-- Interrupteur coupé : l'ancien déroulé, les champs sont ignorés.
local function isAntiTheft(entry: any): boolean
	return Features.ShelfOpen == true and type(entry) == "table" and entry.AntiTheft == true
end

local function inVault(data: Data, uid: string): boolean
	for _, stored in data.Vault do
		if stored == uid then
			return true
		end
	end
	return false
end

-- Présentoir de l'objet (Display), nil s'il n'est pas exposé.
local function slotOf(data: Data, uid: string): number?
	for key, stored in data.Display do
		if stored == uid then
			return tonumber(key)
		end
	end
	return nil
end

local function stateFrom(player: Player, data: Data): InventoryState.State
	local now = os.clock()
	local state = stateOf(player)
	local slots: { [string]: number } = {}
	for key, uid in data.Display do
		local slot = tonumber(key)
		if slot and type(uid) == "string" then
			slots[uid] = slot
		end
	end
	local vault: { [string]: boolean } = {}
	for _, uid in data.Vault do
		vault[uid] = true
	end

	local items: { SortedItem } = {}
	for uid, entry in data.Items do
		local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
		local hold = state.holdUntil[uid]
		local waiting = hold ~= nil and hold > now
		if hold ~= nil and not waiting then
			state.holdUntil[uid] = nil
		end
		if def == nil or vault[uid] or waiting then
			continue
		end
		-- Vague 31 (L-112) : un objet sous antivol posé au sol de sa boutique n'est plus dans l'inventaire
		-- (UnboxService l'affiche au sol) ; dans l'inventaire, il est marqué (à poser au sol, pas exposable).
		local antiTheft = isAntiTheft(entry)
		if antiTheft and (entry :: any).Spot ~= nil then
			continue
		end
		if not InventoryState.IsSafeId(uid) then
			once(`uid:{uid}`, `objet « {uid} » : uid illisible pour l'écran, pas montré`)
			continue
		end
		local mutation = Mutations.Sanitize(entry.Mutation)
		local income = incomeOf(entry, def)
		table.insert(items, {
			income = income,
			entry = {
				Uid = uid,
				ItemId = def.Id,
				Income = income,
				Slot = slots[uid],
				Size = if mutation then mutation.Size else nil,
				Effect = if mutation then mutation.Effect else nil,
				AntiTheft = if antiTheft then true else nil,
			},
		})
	end
	table.sort(items, function(a: SortedItem, b: SortedItem): boolean
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.entry.Uid < b.entry.Uid
	end)

	local stored: { SortedBox } = {}
	local placed: { SortedBox } = {}
	local boxes = (data :: any).Boxes
	if type(boxes) == "table" then
		for uid, box in boxes do
			if type(uid) ~= "string" or not boxIsReadable(box) then
				continue
			end
			if not InventoryState.IsSafeId(uid) then
				once(`uid:{uid}`, `colis « {uid} » : uid illisible pour l'écran, pas montré`)
				continue
			end
			local isPlaced = box.Spot ~= nil
			local readyAt = if type(box.ReadyAt) == "number" then finiteOr(box.ReadyAt, 0) else nil
			local entry: BoxEntry = { Uid = uid, Tier = box.Tier, Rarity = box.Rarity, ReadyAt = readyAt, Placed = isPlaced }
			if isPlaced then
				table.insert(placed, { entry = entry, key = readyAt or 0 })
			else
				table.insert(stored, { entry = entry, key = finiteOr(box.At, 0) })
			end
		end
	end
	local function byKey(a: SortedBox, b: SortedBox): boolean
		if a.key ~= b.key then
			return a.key < b.key
		end
		return a.entry.Uid < b.entry.Uid
	end
	table.sort(stored, byKey)
	table.sort(placed, byKey)

	local result: InventoryState.State = { Items = {}, Boxes = {} }
	for _, item in items do
		table.insert(result.Items, item.entry)
	end
	for _, list in { stored, placed } do
		for _, box in list do
			table.insert(result.Boxes, box.entry)
		end
	end
	return result
end

-- Réécrit l'attribut s'il a changé. Sans yield.
local function sync(player: Player)
	if player.Parent ~= Players then
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local state = stateOf(player)
	local text = InventoryState.Encode(stateFrom(player, data))
	if text ~= state.written or player:GetAttribute(InventoryState.Attribute) ~= text then
		state.written = text
		player:SetAttribute(InventoryState.Attribute, text)
	end
end

local function guardedSync(player: Player)
	local ok, err = pcall(sync :: any, player) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
	if not ok then
		warn(`[InventoryService] inventaire de {player.Name} : {err}`)
	end
end

------------------------------------------------------------------------------
-- Remotes de l'écran
------------------------------------------------------------------------------

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[InventoryService] Notify vers {player.Name} : {err}`)
	end
end

-- Objet du joueur connu du catalogue, et son nom (mutation devant), ou nil.
local function ownedItem(data: Data, itemUid: string): (ProfileTypes.Item?, string?)
	local entry = data.Items[itemUid]
	local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
	if entry == nil or def == nil then
		return nil, nil
	end
	return entry, Mutations.ItemName(def.DisplayName, Mutations.Sanitize(entry.Mutation))
end

local function onPlaceItemAuto(player: Player, itemUid: string)
	local data = DataService.Get(player)
	local api = display()
	if data == nil or api == nil then
		return
	end
	local entry, name = ownedItem(data, itemUid)
	if entry == nil or name == nil then
		log(`{player.Name} : PlaceItemAuto({itemUid}) refusé : objet absent de son profil`)
		return
	end
	if inVault(data, itemUid) then
		log(`{player.Name} : PlaceItemAuto({itemUid}) refusé : au coffre-fort`)
		return
	end
	if api.IsHeld(player, itemUid) then
		notify(player, MESSAGES.Held, WARNING_KIND)
		return
	end
	if slotOf(data, itemUid) ~= nil then
		log(`{player.Name} : PlaceItemAuto({itemUid}) ignoré : déjà exposé`)
		return
	end
	if isAntiTheft(entry) then
		log(`{player.Name} : PlaceItemAuto({itemUid}) refusé : objet sous antivol (L-112)`)
		notify(player, MESSAGES.AntiTheft, WARNING_KIND)
		return
	end
	local plotService = plots()
	if plotService and plotService.GetPlot(player) == nil then
		notify(player, MESSAGES.NoShop, WARNING_KIND)
		return
	end
	local slot = api.PlaceAuto(player, itemUid)
	if slot == nil then
		notify(player, MESSAGES.DisplaysFull, WARNING_KIND)
		return
	end
	guardedSync(player)
	log(`{player.Name} : {itemUid} posé depuis l'inventaire sur le présentoir {slot}`)
	notify(player, string.format(MESSAGES.Placed, name), "Success") -- réussite : vert dans UI_Toast (L-095 point 3)
end

local function onUnplaceItem(player: Player, itemUid: string)
	local data = DataService.Get(player)
	local api = display()
	if data == nil or api == nil then
		return
	end
	local entry, name = ownedItem(data, itemUid)
	if entry == nil or name == nil then
		log(`{player.Name} : UnplaceItem({itemUid}) refusé : objet absent de son profil`)
		return
	end
	if slotOf(data, itemUid) == nil then
		log(`{player.Name} : UnplaceItem({itemUid}) ignoré : pas exposé`)
		return
	end
	if api.IsHeld(player, itemUid) then
		notify(player, MESSAGES.Held, WARNING_KIND)
		return
	end
	if not api.HasInventoryRoom(player) then
		notify(player, MESSAGES.InventoryFull, WARNING_KIND)
		return
	end
	local slot = api.Unplace(player, itemUid)
	if slot == nil then
		log(`{player.Name} : UnplaceItem({itemUid}) refusé par DisplayService`)
		return
	end
	guardedSync(player)
	log(`{player.Name} : {itemUid} repris du présentoir {slot} dans l'inventaire`)
	notify(player, string.format(MESSAGES.Removed, name), INFO_KIND)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function InventoryService.Refresh(player: Player)
	guardedSync(player)
end

function InventoryService.HoldBack(player: Player, itemUid: string, seconds: number)
	if type(itemUid) ~= "string" or type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		return
	end
	local state = stateOf(player)
	state.holdUntil[itemUid] = os.clock() + math.min(seconds, 60)
	task.delay(math.min(seconds, 60) + 0.05, function()
		if states[player] == state then
			guardedSync(player)
		end
	end)
end

function InventoryService.GetState(player: Player): InventoryState.State
	return InventoryState.Decode(player:GetAttribute(InventoryState.Attribute))
end

function InventoryService.Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
	DataService.OnProfileLoaded(guardedSync)
	Net.Server.PlaceItemAuto:Connect(onPlaceItemAuto)
	Net.Server.UnplaceItem:Connect(onUnplaceItem)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < SYNC_INTERVAL then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			guardedSync(player)
		end
	end)
end

return InventoryService
