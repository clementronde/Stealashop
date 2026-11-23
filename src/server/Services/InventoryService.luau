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
--   - vague 52 (a170) : plus de colis dans l'état (le colis porté, rangé, posé n'existe plus) ; le champ
--     Boxes du profil reste, vide après chargement (DataService.convertBoxes).
-- Un objet tout juste sorti d'un colis n'apparaît qu'à sa révélation (HoldBack, UnboxService).
-- Vague 31 (L-112) : un objet sous antivol (Items[uid].AntiTheft) est marqué dans l'état
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
--   TakeDisplayItem(itemUid)  vague 44 (a152, Cantin, 2026-11-14) : invite « Take » (touche E) d'un objet
--       exposé de SA boutique (DisplayController) : mêmes contrôles et mêmes réponses qu'UnplaceItem, plus un
--       personnage vivant à Unbox.PromptDistance + Unbox.ReachTolerance studs au plus de son présentoir (la
--       portée des autres invites de la boutique). L'objet va dans l'inventaire ; la barre du bas lui donne sa
--       première case vide s'il y en a une (HotbarController). Ses $/s s'arrêtent (il n'est plus exposé).
--       Un voleur qui maintient « Steal » sur cet objet voit sa prise refusée (présentoir vide, PvPService).
--   Vague 63 (a206, règle de Clément, L-192 Q3) : UnplaceItem (RemoveButton de UI_Displayed) et TakeDisplayItem
--       remettent l'objet DANS LA MAIN (HeldItemService.Give : mains libres seulement, vivant, sans portage, aucun
--       Tool en main ; Notify « … removed from its display ») ; mains prises (outil, batte, autre objet, portage,
--       mort) : il va dans la réserve (DisplayService.AddToReserve ; Notify « … moved to your reserve ») ; réserve
--       pleine : il reste dans l'inventaire, comme avant.
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
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Unbox = require(Shared.Config.Unbox) -- vague 44 : portée de l'invite « Take »
local InventoryState = require(Shared.InventoryState)
local ItemWeight = require(Shared.ItemWeight) -- vague 62 : poids montré dans la barre d'objets
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)
local DataService = require(script.Parent.DataService)

type Data = ProfileTypes.Data
type ItemEntry = InventoryState.ItemEntry

-- Ce que ce service utilise de DisplayService (a14, a46, a51).
type DisplayApi = {
	PlaceAuto: (player: Player, itemUid: string, near: Vector3?) -> number?,
	Unplace: (player: Player, itemUid: string) -> number?,
	IsHeld: (player: Player, itemUid: string) -> boolean,
	HasInventoryRoom: (player: Player) -> boolean,
	GetSlots: (player: Player) -> { [number]: Attachment }, -- vague 44 : portée de TakeDisplayItem
	AddToReserve: ((player: Player, itemUid: string) -> boolean)?, -- vague 63 (a206) : objet retiré sans main libre
}
-- Vague 63 (a206) : et de HeldItemService (objet retiré à la main : en main).
type HeldApi = {
	Give: (player: Player, itemUid: string) -> boolean,
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
	AntiTheft = "Put it down in your shop first: display it once UNLOCKED!",
	-- Vague 63 (a206), V0 proposé, absent du doc : objet retiré d'un présentoir sans main libre, rangé dans la réserve.
	ToReserve = "%s removed from its display: moved to your inventory", -- vague 63 : mains prises
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

local heldApi: HeldApi? = nil
local function heldItems(): HeldApi?
	if heldApi == nil then
		heldApi = sibling("HeldItemService")
	end
	return heldApi
end

------------------------------------------------------------------------------
-- État de l'écran, tiré du profil
------------------------------------------------------------------------------

-- Revenu d'un objet ($/s, sans bonus), même règle que DisplayService (7.1).
local function incomeOf(entry: ProfileTypes.Item, def: Items.Item): number
	return Formulas.ItemIncome(def.Id) * -- vague 76 : rareté, zone et rang de l'objet
		Mutations.IncomeMultiplier(entry.Mutation, entry.Weight) -- vague 62 : poids compris
end

-- Vague 31 (L-112) : objet sous antivol (Types/Profile : AntiTheft, UnlockAt, Spot).
local function isAntiTheft(entry: any): boolean
	return type(entry) == "table" and entry.AntiTheft == true
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
				Weight = if ItemWeight.Enabled() then ItemWeight.Sanitize(entry.Weight) else nil,
			},
		})
	end
	table.sort(items, function(a: SortedItem, b: SortedItem): boolean
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.entry.Uid < b.entry.Uid
	end)

	local result: InventoryState.State = { Items = {} }
	for _, item in items do
		table.insert(result.Items, item.entry)
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

-- Vague 44 (a152) : le personnage vivant est-il à portée du présentoir `slot` (invite « Take ») ?
local function inTakeReach(player: Player, api: DisplayApi, slot: number): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local attachment = api.GetSlots(player)[slot]
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 or not attachment then
		return false
	end
	return ((root :: BasePart).Position - attachment.WorldPosition).Magnitude <= Unbox.PromptDistance + Unbox.ReachTolerance
end

-- UnplaceItem (écran, où que soit le joueur) et, vague 44, TakeDisplayItem (invite « Take », à portée).
local function unplace(player: Player, itemUid: string, what: string, nearOnly: boolean)
	local data = DataService.Get(player)
	local api = display()
	if data == nil or api == nil then
		return
	end
	local entry, name = ownedItem(data, itemUid)
	if entry == nil or name == nil then
		log(`{player.Name} : {what}({itemUid}) refusé : objet absent de son profil`)
		return
	end
	local exposedAt = slotOf(data, itemUid)
	if exposedAt == nil then
		log(`{player.Name} : {what}({itemUid}) ignoré : pas exposé`)
		return
	end
	if nearOnly and not inTakeReach(player, api, exposedAt) then
		log(`{player.Name} : {what}({itemUid}) refusé : trop loin du présentoir {exposedAt} ou personnage absent`)
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
		log(`{player.Name} : {what}({itemUid}) refusé par DisplayService`)
		return
	end
	guardedSync(player)
	-- Vague 63 (a206, règle de Clément, L-192 Q3) : l'objet retiré à la main revient DANS LA MAIN (HeldItemService.Give,
	-- mains libres seulement : vivant, sans portage, aucun Tool en main) ; sinon il va dans la réserve
	-- (DisplayService.AddToReserve) ; réserve pleine : il reste dans l'inventaire (barre du bas), comme avant.
	local held = heldItems()
	local inHand = false
	if held then
		local ok, given = pcall(held.Give, player, itemUid)
		inHand = ok and given == true
	end
	local where = "dans l'inventaire"
	local message = MESSAGES.Removed
	local addToReserve = api.AddToReserve
	if inHand then
		where = "dans la main"
	elseif addToReserve and addToReserve(player, itemUid) then
		where = "dans la réserve"
		message = MESSAGES.ToReserve
	end
	log(`{player.Name} : {itemUid} repris du présentoir {slot}, {where}`)
	notify(player, string.format(message, name), INFO_KIND)
end

local function onUnplaceItem(player: Player, itemUid: string)
	unplace(player, itemUid, "UnplaceItem", false)
end

local function onTakeDisplayItem(player: Player, itemUid: string)
	unplace(player, itemUid, "TakeDisplayItem", true)
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
	Net.Server.TakeDisplayItem:Connect(onTakeDisplayItem)
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
