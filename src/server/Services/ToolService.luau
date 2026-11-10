--!strict
-- ToolService (DEV-013) : outils de casse possédés, outil équipé et dégâts par coup
-- (Partie 1, sections 5.2, 7.1 et 7.2 ; sauvegarde 9.5 : Tools.Owned et Tools.Equipped).
--
-- On garde tous les outils achetés et on en équipe un (5.2). L'outil équipé est donné au
-- joueur sous forme de Tool Roblox, rendu à chaque apparition dès que le Backpack est prêt :
-- c'est le premier outil du Backpack, touche 1 (Balance.Hotbar.ToolSlot). La barre Roblox est cachée
-- depuis L-079 : on l'équipe depuis l'écran UI_Inventory ou avec les touches 1 et 2 (InventoryController).
-- Modèle : le `TOOL_*` de Clément (Config.Tools, champ Asset), cherché par son nom dans
-- ReplicatedStorage/Assets (Assets/Tools prévu) ; tant qu'il n'est pas livré, une poignée
-- grise V0. Les poings n'ont pas de modèle : Tool sans poignée. Le Tool porte l'attribut
-- `ToolId` (Id de Config.Tools), lu par HitController (client).
-- Aucun remote ici : les achats passeront par ShopService (BuyItem), les coups par WindowService.
--
-- La batte (DEV-043, 6.2 ; valeurs : Config/Bat) : tout le monde l'a, en slot 2 de la hotbar
-- (Bat.HotbarSlot). Un Tool fait du modèle `TOOL_Batte` de Clément (Bat.Asset, même recherche et
-- même préparation que les outils de casse), poignée grise V0 s'il n'est pas livré, nommé Bat.DisplayName.
-- Donné juste après l'outil de casse, à chaque apparition comme lui : la hotbar de Roblox range les
-- outils dans l'ordre où ils arrivent dans le Backpack, et un outil de casse remplacé (achat, Equip)
-- reprend la place libérée, le slot 1. Jamais avant l'outil de casse (profil pas encore chargé : ni
-- l'un ni l'autre). Elle porte l'attribut `BatTool` = true et jamais `ToolId` : HitController,
-- TutorialController et WindowService (IsHoldingTool) ne la prennent pas pour un outil de casse.
-- Son coup : BatService (serveur) et BatController (client).
--
-- API (serveur) :
--   ToolService.GetHitDamage(player) -> number
--       Dégâts par coup (7.1) = puissance de l'outil équipé × (1 + Force / 100) × M aura,
--       avec Force = Stats.Strength du profil. 0 tant que le profil n'est pas chargé.
--   ToolService.GetAuraMultiplier(player) -> number
--       Point d'accroche : renvoie 1. CosmeticService le remplace par le multiplicateur de
--       l'aura équipée (ToolService.GetAuraMultiplier = function(player) ... end).
--       Une erreur ou une valeur qui n'est pas un nombre > 0 compte pour 1.
--   ToolService.Equip(player, toolId) -> boolean
--       Équipe un outil possédé et remplace le Tool donné (remis en main s'il y était).
--       false si le profil n'est pas chargé, l'outil inconnu ou pas possédé.
--   ToolService.Grant(player, toolId) -> boolean
--       Ajoute l'outil aux outils possédés, sans l'équiper (boutique d'armes, DEV-031).
--   ToolService.Owns(player, toolId) -> boolean
--   ToolService.GetEquippedId(player) -> string?
--       Outil équipé ; un outil enregistré inconnu ou pas possédé compte comme les poings.
--   ToolService.IsHoldingTool(player) -> boolean
--       true si le joueur a son outil de casse en main (vérifié par WindowService). La batte n'en
--       est pas un.
--   ToolService.IsHoldingBat(player) -> boolean
--       true si le joueur a la batte en main (vérifié par BatService à chaque SwingBat).
--   ToolService.RefreshDamage(player)
--       Recalcule l'attribut Damage du Player. Appelé ici au chargement du profil, à chaque Equip
--       et à chaque changement de Force (attribut Strength posé par StatsService) ; CosmeticService
--       l'appellera quand l'aura équipée change (après avoir remplacé GetAuraMultiplier).
--
-- Attribut du Player (écrit seulement ici) : Damage = GetHitDamage, les dégâts d'un coup avec
-- l'outil équipé, les poings par défaut (7.1). Le HUD l'affiche (HudController, DEV-021) ; il ne
-- sert qu'à l'affichage : WindowService rappelle GetHitDamage à chaque coup.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Bat = require(Shared.Config.Bat)
local Formulas = require(Shared.Config.Formulas)
local Tools = require(Shared.Config.Tools)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)

type Data = ProfileTypes.Data
type ToolDef = Tools.Tool

-- Attribut du Tool donné au joueur : Id de l'outil (Config.Tools). Même nom dans HitController.
local TOOL_ID_ATTRIBUTE = "ToolId"
-- Attribut du Tool de la batte (true). Même nom dans BatController et HitController.
local BAT_ATTRIBUTE = "BatTool"
-- Attribut du Player lu par le HUD (même nom dans HudController).
local DAMAGE_ATTRIBUTE = "Damage"
-- Attribut du Player posé par StatsService : la Force, qui entre dans les dégâts.
local STRENGTH_ATTRIBUTE = "Strength"
-- Dossier des modèles de Clément (9.2).
local ASSETS_FOLDER = "Assets"
-- V0 proposé, absent du doc : poignée grise des outils dont le TOOL_* n'est pas encore livré.
local PLACEHOLDER_SIZE = Vector3.new(0.4, 0.4, 2.5)
local PLACEHOLDER_COLOR = Color3.fromRGB(150, 150, 150)

local ToolService = {}

local liveTools: { [Player]: Tool } = {} -- Tool de casse donné, dans le Backpack ou en main
local liveBats: { [Player]: Tool } = {} -- batte donnée, dans le Backpack ou en main
local warnedAssets: { [string]: boolean } = {}
local auraHookWarned = false

function ToolService.GetAuraMultiplier(_player: Player): number
	return 1
end

local function owns(data: Data, toolId: string): boolean
	return table.find(data.Tools.Owned, toolId) ~= nil
end

-- Outil équipé du profil s'il est connu et possédé, sinon l'outil de départ (les poings).
local function equippedDef(data: Data): ToolDef
	local def = Tools.ById[data.Tools.Equipped]
	if def ~= nil and owns(data, def.Id) then
		return def
	end
	return Tools.ById[Tools.DefaultId]
end

local function auraMultiplier(player: Player): number
	local ok, value = pcall(ToolService.GetAuraMultiplier, player)
	if ok and type(value) == "number" and value > 0 and value < math.huge then
		return value
	end
	if not auraHookWarned then
		auraHookWarned = true
		warn(`[ToolService] GetAuraMultiplier : erreur ou valeur invalide ({value}), multiplicateur 1 utilisé`)
	end
	return 1
end

-- Pièces d'un outil cloné : jamais ancrées, sans collision ni masse (elles suivent la main),
-- et soudées à la poignée si elles ne tiennent à rien. Les soudures déjà là (les WeldToHandle des
-- modèles de Clément, MOD-027) sont lues dans l'outil : GetJoints ne marche pas hors du Workspace.
local function prepareParts(tool: Tool, handle: BasePart)
	local joined: { [BasePart]: boolean } = {}
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("WeldConstraint") or descendant:IsA("JointInstance") then
			local joint = descendant :: any
			local ends: { Instance? } = { joint.Part0, joint.Part1 }
			for _, part in ends do
				if part ~= nil and part:IsA("BasePart") then
					joined[part :: BasePart] = true
				end
			end
		end
	end
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			if descendant ~= handle and not joined[descendant] then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
end

-- Tool fait du modèle TOOL_* de Clément, ou nil s'il n'est pas livré ou n'a pas de Handle.
local function fromAsset(assetName: string): Tool?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
	local asset = if assets then assets:FindFirstChild(assetName, true) else nil
	if asset == nil then
		return nil
	end
	local clone = asset:Clone()
	local tool: Tool
	if clone:IsA("Tool") then
		tool = clone
	else
		-- Livré en Model : son contenu passe dans un Tool.
		tool = Instance.new("Tool")
		for _, child in clone:GetChildren() do
			child.Parent = tool
		end
		clone:Destroy()
	end
	-- Jamais de script dans un outil (CLAUDE.md, modèles et scripts FX).
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local handle = tool:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		if not warnedAssets[assetName] then
			warnedAssets[assetName] = true
			warn(`[ToolService] {asset:GetFullName()} : pas de pièce « Handle » en enfant direct (10.4), poignée grise utilisée`)
		end
		tool:Destroy()
		return nil
	end
	tool.RequiresHandle = true
	prepareParts(tool, handle :: BasePart)
	return tool
end

-- Tool V0 : poignée grise (modèle pas livré), ou rien en main (`withHandle` false : les poings).
local function placeholder(withHandle: boolean): Tool
	local tool = Instance.new("Tool")
	if not withHandle then
		tool.RequiresHandle = false -- les poings : rien en main
		return tool
	end
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = PLACEHOLDER_SIZE
	handle.Color = PLACEHOLDER_COLOR
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.RequiresHandle = true
	return tool
end

local function buildTool(def: ToolDef): Tool
	local asset = def.Asset
	local tool = (if asset then fromAsset(asset) else nil) or placeholder(asset ~= nil)
	tool.Name = def.DisplayName
	tool.ToolTip = def.DisplayName
	tool.CanBeDropped = false
	tool:SetAttribute(TOOL_ID_ATTRIBUTE, def.Id)
	return tool
end

-- La batte : TOOL_Batte de Clément, sinon une poignée grise V0 ; attribut BatTool, jamais ToolId.
local function buildBat(): Tool
	local tool = fromAsset(Bat.Asset)
	if tool == nil then
		if not warnedAssets[Bat.Asset] then
			warnedAssets[Bat.Asset] = true
			print(`[ToolService] {Bat.Asset} pas trouvé dans ReplicatedStorage/{ASSETS_FOLDER} : batte en poignée grise V0`)
		end
		tool = placeholder(true)
	end
	local bat = tool :: Tool
	bat.Name = Bat.DisplayName
	bat.ToolTip = Bat.DisplayName
	bat.CanBeDropped = false
	bat:SetAttribute(BAT_ATTRIBUTE, true)
	return bat
end

-- `tool` est-il au joueur, dans son Backpack actuel ou en main ?
local function isLive(player: Player, tool: Tool?): boolean
	if tool == nil then
		return false
	end
	local parent = tool.Parent
	return parent ~= nil and (parent == player.Character or parent == player:FindFirstChildOfClass("Backpack"))
end

local function hasLiveTool(player: Player): boolean
	return isLive(player, liveTools[player])
end

-- Donne la batte si elle manque, seulement une fois l'outil de casse donné : elle arrive après lui
-- dans le Backpack, donc en slot 2 (Bat.HotbarSlot).
local function ensureBat(player: Player)
	if player.Parent ~= Players or not hasLiveTool(player) or isLive(player, liveBats[player]) then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		return
	end
	local old = liveBats[player]
	if old then
		old:Destroy()
	end
	local bat = buildBat()
	bat.Parent = backpack
	liveBats[player] = bat
end

-- (Re)donne l'outil équipé : l'ancien Tool est détruit d'abord, pour que le nouveau reprenne
-- son slot de la hotbar, puis remis en main si l'ancien y était.
local function giveTool(player: Player)
	local data = DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if data == nil or backpack == nil then
		return
	end
	local character = player.Character
	local old = liveTools[player]
	local wasHeld = old ~= nil and character ~= nil and old.Parent == character
	if old then
		old:Destroy()
	end
	local tool = buildTool(equippedDef(data))
	tool.Parent = backpack
	liveTools[player] = tool
	if wasHeld and character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:EquipTool(tool)
		end
	end
end

-- Donne l'outil s'il manque (nouvelle apparition, nouveau Backpack, profil tout juste chargé), puis
-- la batte derrière lui.
local function ensureTool(player: Player)
	if player.Parent ~= Players then
		return
	end
	if not hasLiveTool(player) then
		giveTool(player)
	end
	ensureBat(player)
end

local function watchPlayer(player: Player)
	-- Le Backpack est refait à chaque apparition : on attend la fin de l'apparition (defer).
	player.CharacterAdded:Connect(function()
		task.defer(ensureTool, player)
	end)
	player.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Backpack") then
			task.defer(ensureTool, player)
		end
	end)
	player:GetAttributeChangedSignal(STRENGTH_ATTRIBUTE):Connect(function()
		ToolService.RefreshDamage(player)
	end)
	task.defer(ensureTool, player)
end

function ToolService.GetHitDamage(player: Player): number
	local data = DataService.Get(player)
	if data == nil then
		return 0
	end
	return Formulas.HitDamage(equippedDef(data).Power, data.Stats.Strength, auraMultiplier(player))
end

function ToolService.Equip(player: Player, toolId: string): boolean
	local data = DataService.Get(player)
	if data == nil or Tools.ById[toolId] == nil or not owns(data, toolId) then
		return false
	end
	if data.Tools.Equipped ~= toolId then
		data.Tools.Equipped = toolId
		giveTool(player) -- reprend le slot 1 libéré ; la batte garde le sien
		ensureBat(player)
	else
		ensureTool(player)
	end
	ToolService.RefreshDamage(player)
	return true
end

function ToolService.Grant(player: Player, toolId: string): boolean
	local data = DataService.Get(player)
	if data == nil or Tools.ById[toolId] == nil then
		return false
	end
	if not owns(data, toolId) then
		table.insert(data.Tools.Owned, toolId)
	end
	return true
end

function ToolService.Owns(player: Player, toolId: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and owns(data, toolId)
end

function ToolService.GetEquippedId(player: Player): string?
	local data = DataService.Get(player)
	return if data then equippedDef(data).Id else nil
end

function ToolService.IsHoldingTool(player: Player): boolean
	local tool = liveTools[player]
	local character = player.Character
	return tool ~= nil and character ~= nil and tool.Parent == character
end

function ToolService.IsHoldingBat(player: Player): boolean
	local bat: Tool? = liveBats[player]
	local character = player.Character
	return bat ~= nil and character ~= nil and bat.Parent == character
end

function ToolService.RefreshDamage(player: Player)
	if DataService.Get(player) ~= nil then
		player:SetAttribute(DAMAGE_ATTRIBUTE, ToolService.GetHitDamage(player))
	end
end

function ToolService.Init()
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		liveTools[player] = nil
		liveBats[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	DataService.OnProfileLoaded(function(player: Player)
		ensureTool(player)
		ToolService.RefreshDamage(player)
	end)
end

return ToolService
