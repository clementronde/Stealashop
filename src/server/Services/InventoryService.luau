--!strict
-- InventoryService (L-089 points 1 et 3, L-079) : la barre d'inventaire en bas de l'écran, avec la
-- batte et les poings (Partie 1, sections 5.6, 5.8 et 9.5).
--
-- Forme choisie (V0, en attendant l'écran d'inventaire de Clément, maquettes en cours, L-079) : la
-- barre d'outils par défaut de Roblox (CoreGui Backpack). Chaque colis de l'inventaire et chaque objet
-- non exposé y est un Tool, après l'outil de casse (slot 1) et la batte (slot 2) de ToolService
-- (Balance.Hotbar) : la barre range les outils dans l'ordre où ils arrivent dans le Backpack, donc ce
-- service n'en donne aucun tant que l'outil de casse n'est pas là (au plus CORE_WAIT s : sans lui, la
-- barre se remplit quand même).
--
-- Le profil fait foi, jamais l'inverse : les Tools sont faits ici à partir du profil, remis d'accord
-- avec lui deux fois par seconde (et tout de suite à chaque Refresh), refaits à chaque apparition (le
-- Backpack est neuf). Le client ne peut rien créer : jeter, copier ou renommer un Tool chez lui ne
-- change rien, chaque action envoie un uid que le serveur revérifie dans le profil (PlaceBox,
-- PlaceItem). Un Tool qui ne correspond plus au profil (colis posé, objet exposé, vendu, volé) est
-- détruit, même en main.
--   - Colis de l'inventaire : Boxes[uid] sans Spot (Types/Profile v7), plus anciens d'abord (At).
--     Tool nommé « <Rareté> Box » (« Rare Box »), attributs InventoryKind = "Box", BoxUid, Tier,
--     Rarity, jamais l'ItemId (5.7 : l'objet reste secret jusqu'à l'ouverture). En main : une copie
--     de BOX_<Tier> (ReplicatedStorage/Assets, puis ServerStorage/Assets), teinte à la rareté
--     (pièce Tint), sinon un bloc V0 de cette couleur. Icône : le Decal ICON_BOX_<Tier> s'il est livré
--     (nom proposé à Clément, règle de Contract/Icons), sinon le nom du Tool.
--   - Objets de l'inventaire : Items[uid] ni exposé (Display) ni au coffre-fort (Vault), ItemId connu
--     du catalogue, qui rapportent le plus d'abord. Tool nommé comme l'objet, mutation devant (« Big
--     Gold Soda Can », DEV-131), attributs InventoryKind = "Item", ItemUid, ItemId, Rarity. En main :
--     une copie de ITM_<ItemId> (ReplicatedStorage/Assets/Items), sinon un bloc V0. Icône : ICON_<ItemId>
--     (L-055) s'il est livré.
--   - Un objet tout juste sorti d'un colis n'arrive qu'à sa révélation (HoldBack, UnboxService).
-- Les Tools ne se lâchent pas (CanBeDropped = false), n'ont ni script ni invite, leurs pièces sont
-- sans collision ni masse. Pendant un portage, CarryService les range comme les autres outils.
--
-- API (côté serveur) :
--   InventoryService.Refresh(player)
--       Remet tout de suite la barre d'accord avec le profil (après un changement de Boxes, Items,
--       Display). Sans yield. Sinon, la boucle le fait au plus SYNC_INTERVAL s plus tard.
--   InventoryService.HoldBack(player, itemUid, seconds)
--       Le Tool de cet objet n'apparaît pas avant `seconds` s (objet ouvert, pas encore révélé chez le
--       joueur : son nom en dirait trop). Sans yield.
--   InventoryService.GetTools(player) -> { Tool }
--       Tools d'inventaire donnés en ce moment (Backpack et main), pour les bancs d'essai.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local Icons = require(Shared.Contract.Icons)
local ProfileTypes = require(Shared.Types.Profile)
local DataService = require(script.Parent.DataService)

type Data = ProfileTypes.Data
type Kind = "Box" | "Item"

-- Ce qui doit être dans la barre : un colis ou un objet du profil.
type Wanted = {
	key: string, -- « Box:<uid> » ou « Item:<uid> »
	kind: Kind,
	uid: string,
	order: number, -- rang dans la barre (plus petit = plus tôt)
}

-- Colis et objets de l'inventaire, avant leur tri.
type BoxEntry = { uid: string, at: number }
type ItemEntry = { uid: string, income: number }

type State = {
	holdUntil: { [string]: number }, -- [itemUid] = os.clock() avant lequel son Tool ne vient pas
	backpack: Backpack?, -- Backpack vu au dernier passage
	backpackSince: number, -- os.clock() de son arrivée
}

-- Attributs des Tools posés ici (mêmes noms dans InventoryController).
local KIND_ATTRIBUTE = "InventoryKind"
local BOX_UID_ATTRIBUTE = "BoxUid"
local ITEM_UID_ATTRIBUTE = "ItemUid"
local ITEM_ID_ATTRIBUTE = "ItemId"
local RARITY_ATTRIBUTE = "Rarity"
local TIER_ATTRIBUTE = "Tier"
-- Attribut de l'outil de casse de ToolService (même nom là-bas).
local TOOL_ID_ATTRIBUTE = "ToolId"
-- Contrat (10.3, 10.4).
local BOX_PREFIX = "BOX_"
local TINT = "Tint"
local ASSETS = "Assets"
local ITEMS_FOLDER = "Items"
local HANDLE = "Handle"

-- V0 proposé, absent du doc : cadence (s) de la remise d'accord avec le profil ; attente (s) de l'outil
-- de casse de ToolService dans un Backpack neuf avant de remplir la barre sans lui.
local SYNC_INTERVAL = 0.5
local CORE_WAIT = 3
-- V0 proposé, absent du doc : blocs de remplacement (studs) tant que BOX_<Tier> ou ITM_<ItemId> n'est
-- pas livré, et poignée invisible des modèles livrés.
local V0_BOX_SIZE = Vector3.new(1.6, 1.6, 1.6)
local V0_ITEM_SIZE = Vector3.new(1, 1.2, 1)
local HANDLE_SIZE = Vector3.new(0.4, 0.4, 0.4)
-- V0 proposé, absent du doc : textes des Tools, en anglais (L-036).
local BOX_NAME = "%s Box" -- %s = rareté (« Rare Box »)
local BOX_TIP = "%s box · %s" -- type, rareté en capitales (« Premium box · RARE »)
local ITEM_TIP = "%s · %s" -- rareté en capitales, revenu (« RARE · +$5/s », Format.income)

local IS_STUDIO = RunService:IsStudio()

local InventoryService = {}

local states: { [Player]: State } = {}
local noticed: { [string]: boolean } = {}

local function once(key: string, message: string)
	if noticed[key] then
		return
	end
	noticed[key] = true
	if IS_STUDIO then
		print(`[InventoryService] {message}`)
	end
end

local function stateOf(player: Player): State
	local existing = states[player]
	if existing then
		return existing
	end
	local state: State = { holdUntil = {}, backpack = nil, backpackSince = os.clock() }
	states[player] = state
	return state
end

------------------------------------------------------------------------------
-- Ce que le profil met dans la barre
------------------------------------------------------------------------------

local function validZone(value: any): number?
	if type(value) == "number" and value % 1 == 0 and Zones[value] ~= nil then
		return value
	end
	return nil
end

-- Revenu d'un objet ($/s, sans bonus), pour l'ordre de la barre et l'info-bulle (7.1 ; même règle que
-- DisplayService : zone du catalogue, sinon celle de l'objet, sinon 1).
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

-- Colis puis objets de l'inventaire, dans l'ordre de la barre.
local function wantedOf(player: Player, data: Data): { Wanted }
	local list: { Wanted } = {}
	local now = os.clock()
	local state = stateOf(player)
	local boxes = (data :: any).Boxes
	local boxList: { BoxEntry } = {}
	if type(boxes) == "table" then
		for uid, box in boxes do
			if type(uid) == "string" and boxIsReadable(box) and box.Spot == nil then
				local at = if type(box.At) == "number" and box.At == box.At then box.At else 0
				table.insert(boxList, { uid = uid, at = at })
			end
		end
	end
	table.sort(boxList, function(a: BoxEntry, b: BoxEntry): boolean
		if a.at ~= b.at then
			return a.at < b.at
		end
		return a.uid < b.uid
	end)
	for index, entry in boxList do
		local wanted: Wanted = { key = "Box:" .. entry.uid, kind = "Box", uid = entry.uid, order = index }
		table.insert(list, wanted)
	end

	local placed: { [string]: boolean } = {}
	for _, uid in data.Display do
		placed[uid] = true
	end
	for _, uid in data.Vault do
		placed[uid] = true
	end
	local itemList: { ItemEntry } = {}
	for uid, entry in data.Items do
		local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
		local hold = state.holdUntil[uid]
		local waiting = hold ~= nil and hold > now
		if hold ~= nil and not waiting then
			state.holdUntil[uid] = nil
		end
		if def and not placed[uid] and not waiting then
			table.insert(itemList, { uid = uid, income = incomeOf(entry, def) })
		end
	end
	table.sort(itemList, function(a: ItemEntry, b: ItemEntry): boolean
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.uid < b.uid
	end)
	for index, entry in itemList do
		local wanted: Wanted = { key = "Item:" .. entry.uid, kind = "Item", uid = entry.uid, order = #boxList + index }
		table.insert(list, wanted)
	end
	return list
end

------------------------------------------------------------------------------
-- Tools
------------------------------------------------------------------------------

-- Premier élément nommé `name` dans ReplicatedStorage/Assets, puis dans ServerStorage/Assets.
local function findAsset(name: string, folderName: string?): Instance?
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild(ASSETS)
		local folder = if assets and folderName then assets:FindFirstChild(folderName) else assets
		local found = if folder then folder:FindFirstChild(name, true) else nil
		if found then
			return found
		end
	end
	return nil
end

-- Copie d'un modèle livré (Model, ou pièce seule mise dans un Model), sans script ni invite ; nil
-- s'il n'est pas livré.
local function copyOf(asset: Instance?): Model?
	if asset == nil then
		return nil
	end
	local ok, copy = pcall(function(): Instance?
		return asset:Clone()
	end)
	if not ok or copy == nil then
		return nil
	end
	local model: Model
	if copy:IsA("Model") then
		model = copy
	elseif copy:IsA("BasePart") then
		model = Instance.new("Model")
		copy.Parent = model
		model.PrimaryPart = copy
	else
		copy:Destroy()
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("ProximityPrompt") or descendant:IsA("ClickDetector") then
			descendant:Destroy() -- jamais de script dans un outil (CLAUDE.md) ; aucune invite en main
		end
	end
	if model:FindFirstChildWhichIsA("BasePart", true) == nil then
		model:Destroy()
		return nil
	end
	return model
end

-- Pièces d'un Tool : jamais ancrées, sans collision, sans contact, ignorées des rayons, sans masse,
-- soudées à la poignée.
local function weldParts(tool: Tool, handle: BasePart)
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			if part ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
end

-- Tool avec une poignée : le modèle livré (centré sur une poignée invisible), sinon un bloc V0
-- `size` à la couleur `color`, qui sert lui-même de poignée.
local function toolWith(model: Model?, size: Vector3, color: Color3): Tool
	local tool = Instance.new("Tool")
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = HANDLE
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	if model then
		handle.Size = HANDLE_SIZE
		handle.Transparency = 1
		local center = model:GetBoundingBox()
		model:PivotTo(handle.CFrame * center:ToObjectSpace(model:GetPivot()))
		model.Parent = tool
	else
		handle.Size = size
		handle.Color = color
		handle.Material = Enum.Material.SmoothPlastic
	end
	weldParts(tool, handle)
	return tool
end

local function buildBoxTool(uid: string, box: any): Tool
	local rarity = Rarities.ById[box.Rarity]
	local model = copyOf(findAsset(BOX_PREFIX .. box.Tier))
	if model then
		for _, descendant in model:GetDescendants() do
			if descendant.Name == TINT and descendant:IsA("BasePart") then
				(descendant :: BasePart).Color = rarity.Color
			end
		end
	else
		once(`box:{box.Tier}`, `{BOX_PREFIX}{box.Tier} pas encore livré : colis de l'inventaire en bloc V0`)
	end
	local tool = toolWith(model, V0_BOX_SIZE, rarity.Color)
	tool.Name = string.format(BOX_NAME, rarity.DisplayName)
	tool.ToolTip = string.format(BOX_TIP, box.Tier, rarity.DisplayNameUpper)
	tool.TextureId = Icons.get(BOX_PREFIX .. box.Tier) or ""
	tool:SetAttribute(KIND_ATTRIBUTE, "Box")
	tool:SetAttribute(BOX_UID_ATTRIBUTE, uid)
	tool:SetAttribute(TIER_ATTRIBUTE, box.Tier)
	tool:SetAttribute(RARITY_ATTRIBUTE, box.Rarity)
	return tool
end

local function buildItemTool(uid: string, entry: ProfileTypes.Item, def: Items.Item): Tool
	local rarity = Rarities.ById[def.Rarity]
	local model = copyOf(findAsset(def.Asset, ITEMS_FOLDER))
	if model == nil then
		once(`item:{def.Asset}`, `{def.Asset} pas encore livré : objet de l'inventaire en bloc V0`)
	end
	local tool = toolWith(model, V0_ITEM_SIZE, rarity.Color)
	local mutation = Mutations.Sanitize(entry.Mutation)
	tool.Name = Mutations.ItemName(def.DisplayName, mutation)
	tool.ToolTip = string.format(ITEM_TIP, rarity.DisplayNameUpper, Format.income(incomeOf(entry, def)))
	tool.TextureId = Icons.get(def.Id) or ""
	tool:SetAttribute(KIND_ATTRIBUTE, "Item")
	tool:SetAttribute(ITEM_UID_ATTRIBUTE, uid)
	tool:SetAttribute(ITEM_ID_ATTRIBUTE, def.Id)
	tool:SetAttribute(RARITY_ATTRIBUTE, def.Rarity)
	return tool
end

-- Clé d'un Tool d'inventaire (« Box:<uid> », « Item:<uid> »), nil pour un autre outil.
local function keyOf(tool: Instance): string?
	if not tool:IsA("Tool") then
		return nil
	end
	local kind = tool:GetAttribute(KIND_ATTRIBUTE)
	if kind == "Box" then
		local uid = tool:GetAttribute(BOX_UID_ATTRIBUTE)
		return if type(uid) == "string" then "Box:" .. uid else nil
	elseif kind == "Item" then
		local uid = tool:GetAttribute(ITEM_UID_ATTRIBUTE)
		return if type(uid) == "string" then "Item:" .. uid else nil
	end
	return nil
end

-- Tools d'inventaire du joueur (Backpack et main), par clé ; un doublon est détruit.
local function currentTools(player: Player, backpack: Backpack): { [string]: Tool }
	local found: { [string]: Tool } = {}
	local containers: { Instance } = { backpack }
	local character = player.Character
	if character then
		table.insert(containers, character)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			local key = keyOf(child)
			if key then
				if found[key] then
					child:Destroy()
				else
					found[key] = child :: Tool
				end
			end
		end
	end
	return found
end

-- L'outil de casse de ToolService est-il là (Backpack ou main) ?
local function hasCoreTool(player: Player, backpack: Backpack): boolean
	for _, container in { backpack, player.Character } :: { Instance? } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(TOOL_ID_ATTRIBUTE) ~= nil then
					return true
				end
			end
		end
	end
	return false
end

-- Remet la barre d'accord avec le profil. Sans yield.
local function sync(player: Player)
	if player.Parent ~= Players then
		return
	end
	local data = DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if data == nil or backpack == nil then
		return
	end
	local state = stateOf(player)
	if state.backpack ~= backpack then
		state.backpack = backpack
		state.backpackSince = os.clock()
	end
	if not hasCoreTool(player, backpack) and os.clock() - state.backpackSince < CORE_WAIT then
		return -- slots 1 et 2 d'abord (ToolService)
	end
	local existing = currentTools(player, backpack)
	local wanted = wantedOf(player, data)
	local keep: { [string]: boolean } = {}
	for _, entry in wanted do
		keep[entry.key] = true
	end
	for key, tool in existing do
		if not keep[key] then
			tool:Destroy()
			existing[key] = nil
		end
	end
	for _, entry in wanted do
		if not existing[entry.key] then
			local ok, result = pcall(function(): Tool?
				if entry.kind == "Box" then
					return buildBoxTool(entry.uid, (data :: any).Boxes[entry.uid])
				end
				local item = data.Items[entry.uid]
				local def = Items.ById[item.Id]
				return if def then buildItemTool(entry.uid, item, def) else nil
			end)
			if ok and result then
				result.Parent = backpack
			elseif not ok then
				warn(`[InventoryService] {player.Name} : Tool {entry.key} pas créé : {result}`)
			end
		end
	end
end

local function guardedSync(player: Player)
	local ok, err = pcall(sync :: any, player) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
	if not ok then
		warn(`[InventoryService] barre de {player.Name} : {err}`)
	end
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

function InventoryService.GetTools(player: Player): { Tool }
	local list: { Tool } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, tool in currentTools(player, backpack) do
			table.insert(list, tool)
		end
	end
	return list
end

function InventoryService.Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
	DataService.OnProfileLoaded(guardedSync)
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
