--!strict
-- HeldItemService (demande de Cantin du 2026-11-14, agent a142) : un objet de l'inventaire choisi dans la
-- barre du bas UI_Hotbar va DANS LA MAIN du joueur, comme un outil, visible par tous, à la taille qu'il a sur
-- un présentoir (modèle ITM_ de Clément à l'échelle du jeu, mutation de taille Tiny à Colossal comprise).
--
-- Rôle :
--   - remote HoldItem(itemUid) (HotbarController → InventoryController.HoldItem ; Net a contrôlé la forme et
--     le débit). Refusé, rien ne change (une ligne en Studio), si : profil pas chargé, personnage absent ou
--     mort, portage en cours (attribut Carrying de CarryService), objet qui n'est pas à lui ou inconnu du
--     catalogue, exposé (Display), au coffre-fort (Vault), tenu par un voleur (DisplayService.IsHeld), posé
--     au sol sous antivol (Spot), ou absent de l'état de l'inventaire (InventoryService : pas encore révélé
--     après une ouverture). Accepté : l'objet tenu avant (s'il y en a un) est rangé, puis un Tool neuf est
--     fait et mis en main (Humanoid:EquipTool, qui range l'outil de casse ou la batte). Le même uid déjà en
--     main : rien ne change ;
--   - le Tool : un modèle construit par DisplayService.BuildFloorItem (le même que sur un présentoir : copie
--     d'ITM_ ou bloc V0, Model:ScaleTo de la mutation, halo de rareté RarityHalo, attributs ItemId,
--     MutationSize, MutationEffect…), nommé HeldItem, tag de code CarriedItem (MutationFxController y montre
--     l'effet de la mutation, comme sur un objet porté), sans BB_Item. Ses pièces sont désancrées, sans
--     collision, ni contact, ni requête, sans masse, et soudées à une poignée invisible Handle au centre de
--     la boîte de l'objet. Tool.Grip suit Config/HeldItem (petit objet au bout de la main, gros objet tenu
--     par-dessous, centré devant le corps). Attribut HeldItemUid du Tool = son uid ; attribut HeldItem du
--     Player = l'uid tenu (absent sinon). CanBeDropped = false ;
--   - rien de ce qui compte ne vient du Tool : aucun service ne le lit, l'objet reste à sa place dans le
--     profil (Items), exposable, vendable et posable une seule fois comme avant. Le Tool est détruit dès qu'il
--     n'est plus en main (rangé par le client, autre outil ou autre objet pris, Humanoid:UnequipTools du
--     portage), à la mort, au retrait du personnage, au départ, à la fin du profil, au début d'un portage
--     (colis ou objet pris), et dès que l'objet ne peut plus être tenu (exposé, vendu, volé, au coffre-fort,
--     posé au sol) : revérifié à chaque changement de l'état de l'inventaire (attribut InventoryState) et
--     toutes les CheckInterval s. Il n'est jamais rangé dans le Backpack.
-- Braquage : l'outil de casse remplace l'objet tenu (touche, barre, écran, ou mis en main tout seul près
-- d'une vitrine cassable, InventoryController) ; WindowService ne compte que l'outil de casse.
--
-- API (côté serveur) :
--   HeldItemService.GetHeld(player) -> string?   uid de l'objet tenu en main (nil : rien)
--   HeldItemService.Stow(player)                 range l'objet tenu (rien s'il n'y en a pas)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local HeldItem = require(Shared.Config.HeldItem)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local InventoryState = require(Shared.InventoryState)
local Net = require(Shared.Net.Net)
local RarityHalo = require(Shared.RarityHalo)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)

type Data = ProfileTypes.Data
type ItemEntry = ProfileTypes.Item

-- Ce que ce service utilise de DisplayService (chargé au premier appel : pas de require croisé au chargement).
type DisplayApi = {
	BuildFloorItem: (ownerUserId: number, pivot: CFrame, itemUid: string, entry: ItemEntry) -> Model?,
	IsHeld: (player: Player, itemUid: string) -> boolean,
}

type Held = {
	uid: string,
	tool: Tool,
	connections: { RBXScriptConnection },
}

local CARRYING_ATTRIBUTE = "Carrying" -- CarryService : portage en cours
local HANDLE_NAME = "Handle"
local HANDLE_SIZE = Vector3.new(0.2, 0.2, 0.2) -- poignée invisible
-- Le modèle est construit à la place du joueur, puis soudé à la main : construit à y = -500 (l'ancienne
-- valeur), il arrivait pile à workspace.FallenPartsDestroyHeight et Roblox le détruisait souvent avec le Tool
-- avant que la soudure de la main ne le rattrape (vu en Play le 2026-11-14, 8 fois sur 10).
local BUILD_FALLBACK = CFrame.new(0, 50, 0) -- sans personnage : au-dessus du sol, loin de la hauteur de destruction

local function buildPivot(player: Player): CFrame
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.CFrame
	end
	return BUILD_FALLBACK
end

local IS_STUDIO = RunService:IsStudio()

local HeldItemService = {}
HeldItemService.Priority = 120 -- après DataService, DisplayService et InventoryService

local held: { [Player]: Held } = {}
local displayApi: DisplayApi? = nil
local noticed: { [string]: boolean } = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[HeldItemService] {message}`)
	end
end

local function once(key: string, message: string)
	if not noticed[key] then
		noticed[key] = true
		log(message)
	end
end

local function display(): DisplayApi?
	if displayApi == nil then
		local module = script.Parent:FindFirstChild("DisplayService")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok and type(result) == "table" then
				displayApi = result :: any
			else
				once("display", `DisplayService pas chargé : {result}`)
			end
		end
	end
	return displayApi
end

------------------------------------------------------------------------------
-- L'objet peut-il être tenu ?
------------------------------------------------------------------------------

local function isDisplayed(data: Data, uid: string): boolean
	for _, stored in data.Display do
		if stored == uid then
			return true
		end
	end
	return false
end

local function inVault(data: Data, uid: string): boolean
	for _, stored in data.Vault do
		if stored == uid then
			return true
		end
	end
	return false
end

-- Dans l'état de l'inventaire publié (pas exposé) : objet révélé, montré au joueur.
local function inInventoryState(player: Player, uid: string): boolean
	local state = InventoryState.Decode(player:GetAttribute(InventoryState.Attribute))
	for _, item in state.Items do
		if item.Uid == uid then
			return item.Slot == nil
		end
	end
	return false
end

-- Raison du refus, ou nil si l'objet `uid` peut être tenu par `player`.
local function refusal(player: Player, uid: string): string?
	local data = DataService.Get(player)
	if data == nil then
		return "profil pas chargé"
	end
	local entry = data.Items[uid]
	if type(entry) ~= "table" or Items.ById[entry.Id] == nil then
		return "objet absent de son profil"
	end
	if isDisplayed(data, uid) then
		return "exposé"
	end
	if inVault(data, uid) then
		return "au coffre-fort"
	end
	if (entry :: any).Spot ~= nil then
		return "posé au sol"
	end
	local api = display()
	if api and api.IsHeld(player, uid) then
		return "tenu par un voleur"
	end
	if not inInventoryState(player, uid) then
		return "pas dans l'état de l'inventaire"
	end
	return nil
end

------------------------------------------------------------------------------
-- Le Tool
------------------------------------------------------------------------------

-- Boîte des pièces du modèle (sans le halo) dans le repère de `frame` : centre et taille.
local function measure(model: Model, frame: CFrame): (Vector3, Vector3)
	local lo: Vector3? = nil
	local hi: Vector3? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= RarityHalo.DisplayPart then
			local part = descendant :: BasePart
			local half = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local point = frame:PointToObjectSpace(part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
						local low: Vector3 = lo or point
						local high: Vector3 = hi or point
						lo = Vector3.new(math.min(low.X, point.X), math.min(low.Y, point.Y), math.min(low.Z, point.Z))
						hi = Vector3.new(math.max(high.X, point.X), math.max(high.Y, point.Y), math.max(high.Z, point.Z))
					end
				end
			end
		end
	end
	local low: Vector3? = lo
	local high: Vector3? = hi
	if low == nil or high == nil then
		return Vector3.zero, Vector3.zero
	end
	return (low + high) / 2, high - low
end

-- Prise en main (Config/HeldItem) : où va le centre de l'objet, dans le repère de la main.
local function gripOf(size: Vector3): CFrame
	local large = math.max(size.X, size.Y, size.Z) > HeldItem.LargeSize
	local offset = Vector3.new(
		if large then -HeldItem.LargeCenterShift else 0,
		if large then size.Y / 2 - HeldItem.LargeBelowHand else 0,
		-(size.Z / 2 + HeldItem.Forward)
	)
	return (CFrame.new(offset) * CFrame.Angles(0, math.rad(HeldItem.Yaw), 0)):Inverse()
end

local function buildTool(player: Player, uid: string, entry: ItemEntry): Tool?
	local api = display()
	if api == nil then
		return nil
	end
	local model = api.BuildFloorItem(player.UserId, buildPivot(player), uid, entry)
	if model == nil then
		return nil
	end
	model.Name = HeldItem.ModelName
	CollectionService:AddTag(model, HeldItem.CarriedTag)
	local pivot = model:GetPivot()
	local center, size = measure(model, pivot)

	local handle = Instance.new("Part")
	handle.Name = HANDLE_NAME
	handle.Size = HANDLE_SIZE
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Anchored = false
	handle.CFrame = pivot * CFrame.new(center)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end

	local def = Items.ById[entry.Id]
	local tool = Instance.new("Tool")
	tool.Name = Mutations.ItemName(def.DisplayName, Mutations.Sanitize(entry.Mutation))
	tool.ToolTip = tool.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = gripOf(size)
	tool:SetAttribute(HeldItem.ToolAttribute, uid)
	handle.Parent = tool
	model.Parent = tool
	return tool
end

------------------------------------------------------------------------------
-- Tenir, ranger
------------------------------------------------------------------------------

local function stow(player: Player)
	local current = held[player]
	if current == nil then
		return
	end
	held[player] = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	if current.tool.Parent ~= nil then
		current.tool:Destroy()
	end
	if player:GetAttribute(HeldItem.PlayerAttribute) == current.uid then
		player:SetAttribute(HeldItem.PlayerAttribute, nil)
	end
end

local function recheck(player: Player)
	local current = held[player]
	if current == nil then
		return
	end
	local reason = refusal(player, current.uid)
	if reason ~= nil then
		log(`{player.Name} : {current.uid} rangé ({reason})`)
		stow(player)
	elseif player:GetAttribute(CARRYING_ATTRIBUTE) ~= nil then
		stow(player)
	end
end

local function onHoldItem(player: Player, itemUid: string)
	local current = held[player]
	if current and current.uid == itemUid and current.tool.Parent == player.Character then
		return -- déjà en main
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		log(`{player.Name} : HoldItem({itemUid}) refusé : personnage absent ou mort`)
		return
	end
	if player:GetAttribute(CARRYING_ATTRIBUTE) ~= nil then
		log(`{player.Name} : HoldItem({itemUid}) refusé : portage en cours`)
		return
	end
	local reason = refusal(player, itemUid)
	if reason ~= nil then
		log(`{player.Name} : HoldItem({itemUid}) refusé : {reason}`)
		return
	end
	local data = DataService.Get(player) :: Data -- vérifié par refusal
	local tool = buildTool(player, itemUid, data.Items[itemUid])
	if tool == nil then
		log(`{player.Name} : HoldItem({itemUid}) : modèle pas construit`)
		return
	end
	stow(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	tool.Parent = backpack or character
	humanoid:EquipTool(tool)
	if tool.Parent ~= character then
		tool:Destroy()
		return
	end
	local entry: Held = { uid = itemUid, tool = tool, connections = {} }
	held[player] = entry
	player:SetAttribute(HeldItem.PlayerAttribute, itemUid)
	table.insert(
		entry.connections,
		tool.AncestryChanged:Connect(function()
			if held[player] == entry and tool.Parent ~= player.Character then
				stow(player) -- rangé, remplacé par un autre outil, personnage retiré
			end
		end)
	)
	table.insert(
		entry.connections,
		humanoid.Died:Connect(function()
			if held[player] == entry then
				stow(player)
			end
		end)
	)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function HeldItemService.GetHeld(player: Player): string?
	local current = held[player]
	return if current then current.uid else nil
end

function HeldItemService.Stow(player: Player)
	stow(player)
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal(InventoryState.Attribute):Connect(function()
		recheck(player)
	end)
	player:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(function()
		if player:GetAttribute(CARRYING_ATTRIBUTE) ~= nil then
			stow(player) -- un colis ou un objet pris : mains libres
		end
	end)
	player.CharacterRemoving:Connect(function()
		stow(player)
	end)
end

function HeldItemService.Init()
	Net.Server.HoldItem:Connect(onHoldItem)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(stow)
	DataService.OnProfileReleasing(stow)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < HeldItem.CheckInterval then
			return
		end
		elapsed = 0
		for player in table.clone(held) do
			local ok, err = pcall(recheck :: any, player) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
			if not ok then
				warn(`[HeldItemService] objet tenu de {player.Name} : {err}`)
			end
		end
	end)
end

return HeldItemService
