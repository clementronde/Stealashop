--!strict
-- WeaponShopController (DEV-031, client) : la boutique d'armes et son écran UI_WeaponShop de
-- Clément (Partie 1, sections 2.2, 5.2, 5.9 et 7.2).
--
-- Rôle :
--   - une invite créée ici, côté client (ProximityPrompt « WeaponShopPrompt »), sur chaque comptoir
--     taggé WeaponShop de la map (hors _INBOX_CLEMENT) : posée sur sa pièce principale, sinon sur le
--     comptoir lui-même (pièce ou Attachment), sinon sur sa première pièce (même règle que
--     ShopService). Elle ouvre UI_WeaponShop, et reste cachée tant que l'écran n'est pas là ;
--   - l'écran (contrat 2.2) : une ligne par outil de Config/Tools, dans l'ordre de la boutique,
--     clonée depuis List.Template (qui reste invisible) et rangée à côté de lui, nommée
--     Tool_<nn>_<Id> avec LayoutOrder = rang (l'ordre tient avec un UIListLayout trié par nom
--     comme par LayoutOrder). Dans chaque ligne : ItemName (nom de l'outil), Power
--     (« Power: 20 »), Price (Format.money, « Free » pour les poings), BuyButton (caché si l'outil
--     est possédé), EquipButton (visible si possédé ; « Equipped » sur l'outil équipé quand c'est un
--     TextButton qui porte son propre texte). Icon n'est pas touché ;
--   - BuyButton envoie BuyItem(toolId), EquipButton envoie EquipTool(toolId) ; le serveur
--     (ShopService) vérifie tout et prévient le joueur (Notify). La liste suit les attributs
--     OwnedTools et EquippedTool du Player (ShopService) : elle se met à jour après chaque achat
--     ou équipement ;
--   - CloseButton ferme l'écran ; il se ferme aussi quand le joueur s'éloigne du comptoir, meurt
--     ou réapparaît.
-- Les éléments sont cherchés par leur nom parmi les descendants (Contract/Find). Tant que l'écran
-- manque (UI-002 pas encore livré), le contrôleur attend sans erreur, avec une seule ligne dans la
-- sortie en Studio. Un écran recréé (ResetOnSpawn) est rebranché. Seuls les textes, la visibilité,
-- les lignes clonées et ScreenGui.Enabled sont touchés (2.2, « Libre pour Ironix »), jamais un style.
--
-- API (client) : aucune.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Tools = require(Config:WaitForChild("Tools"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))

type ToolDef = Tools.Tool

type Row = {
	tool: ToolDef,
	frame: GuiObject,
	buy: GuiButton?,
	equip: GuiButton?,
	equipText: string?, -- texte d'origine de l'EquipButton s'il porte son propre texte
}

type Screen = {
	gui: ScreenGui,
	rows: { Row },
	connections: { RBXScriptConnection },
}

type Shop = {
	inst: Instance,
	prompt: ProximityPrompt?,
	connections: { RBXScriptConnection },
}

-- Contrat (2.1 et 2.2) et attributs posés par ShopService (lus sans require).
local SCREEN = "UI_WeaponShop"
local SHOP_TAG = "WeaponShop"
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons pas encore posées : pas d'invite
local OWNED_ATTRIBUTE = "OwnedTools"
local EQUIPPED_ATTRIBUTE = "EquippedTool"
local PROMPT_NAME = "WeaponShopPrompt"

-- V0 proposés, absents du doc : textes (en anglais, L-036), portée de l'invite (le serveur accepte
-- 20 studs, ShopService), distance de fermeture de l'écran, délai avant de signaler l'écran
-- manquant (Roblox copie StarterGui à l'apparition du perso), délai pendant lequel un 2e clic sur
-- Buy du même outil est ignoré (le temps que le serveur réponde).
local ACTION_TEXT = "Shop"
local OBJECT_TEXT = "Weapon Shop"
local FREE_TEXT = "Free"
local POWER_FORMAT = "Power: %s"
local EQUIPPED_TEXT = "Equipped"
local PROMPT_DISTANCE = 10
local CLOSE_DISTANCE = PROMPT_DISTANCE + 4
local MISSING_SCREEN_DELAY = 10
local BUY_COOLDOWN = 1

local IS_STUDIO = RunService:IsStudio()

local WeaponShopController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local shops: { [Instance]: Shop } = {}
local screen: Screen? = nil
local openAnchor: Instance? = nil -- pièce ou Attachment de l'invite qui a ouvert l'écran
local pendingUntil: { [string]: number } = {}
local templateWarned = false

------------------------------------------------------------------------------
-- Comptoirs et invites
------------------------------------------------------------------------------

local function inMap(inst: Instance): boolean
	if not inst:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not inst:IsDescendantOf(inbox)
end

-- Pièce ou Attachment où se pose l'invite d'un comptoir, ou nil (pas encore chargé).
local function anchorOf(inst: Instance): Instance?
	if inst:IsA("Model") then
		local primary = (inst :: Model).PrimaryPart
		if primary and primary:IsDescendantOf(inst) then
			return primary
		end
	elseif inst:IsA("BasePart") or inst:IsA("Attachment") then
		return inst
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function positionOf(anchor: Instance): Vector3?
	if anchor:IsA("BasePart") then
		return (anchor :: BasePart).Position
	elseif anchor:IsA("Attachment") then
		return (anchor :: Attachment).WorldPosition
	end
	return nil
end

------------------------------------------------------------------------------
-- Écran
------------------------------------------------------------------------------

-- Outils possédés d'après OwnedTools ; avant le profil, les poings seuls (possédés au départ).
local function ownedSet(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local value = localPlayer:GetAttribute(OWNED_ATTRIBUTE)
	if type(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			set[id] = true
		end
	else
		set[Tools.DefaultId] = true
	end
	return set
end

local function refreshRows()
	local current = screen
	if current == nil then
		return
	end
	local owned = ownedSet()
	local equipped = localPlayer:GetAttribute(EQUIPPED_ATTRIBUTE)
	for _, row in current.rows do
		local has = owned[row.tool.Id] == true
		local buy = row.buy
		if buy then
			buy.Visible = not has
		end
		local equip = row.equip
		if equip then
			equip.Visible = has
			local original = row.equipText
			if original and equip:IsA("TextButton") then
				(equip :: TextButton).Text = if has and equipped == row.tool.Id then EQUIPPED_TEXT else original
			end
		end
	end
end

local function close()
	openAnchor = nil
	local current = screen
	if current then
		current.gui.Enabled = false
	end
end

local function open(anchor: Instance)
	local current = screen
	if current == nil then
		return
	end
	openAnchor = anchor
	refreshRows()
	current.gui.Enabled = true
end

local function onBuy(tool: ToolDef)
	local now = os.clock()
	if (pendingUntil[tool.Id] or 0) > now or ownedSet()[tool.Id] then
		return
	end
	pendingUntil[tool.Id] = now + BUY_COOLDOWN
	net.Client.BuyItem:Fire(tool.Id)
end

local function onEquip(tool: ToolDef)
	if localPlayer:GetAttribute(EQUIPPED_ATTRIBUTE) == tool.Id or not ownedSet()[tool.Id] then
		return
	end
	net.Client.EquipTool:Fire(tool.Id)
end

-- Le bouton `name` de `root` (cherché parmi les descendants), ou nil.
local function buttonIn(root: Instance, name: string): GuiButton?
	local found = Find.path(root, name)
	if found and found:IsA("GuiButton") then
		return found :: GuiButton
	end
	return nil
end

local function setText(root: Instance, name: string, text: string)
	local found = Find.path(root, name)
	if found and found:IsA("TextLabel") then
		(found :: TextLabel).Text = text
	end
end

local function buildRow(template: GuiObject, tool: ToolDef, connections: { RBXScriptConnection }): Row?
	local clone: Instance? = template:Clone()
	if clone == nil then
		return nil -- Archivable = false
	end
	local frame = clone :: GuiObject
	frame.Name = string.format("Tool_%02d_%s", tool.Order, tool.Id)
	frame.LayoutOrder = tool.Order
	setText(frame, "ItemName", tool.DisplayName)
	setText(frame, "Power", string.format(POWER_FORMAT, Format.short(tool.Power)))
	setText(frame, "Price", if tool.Price <= 0 then FREE_TEXT else Format.money(tool.Price))
	local buy = buttonIn(frame, "BuyButton")
	local equip = buttonIn(frame, "EquipButton")
	local equipText: string? = nil
	if equip and equip:IsA("TextButton") and (equip :: TextButton).Text ~= "" then
		equipText = (equip :: TextButton).Text
	end
	if buy then
		table.insert(connections, buy.Activated:Connect(function()
			onBuy(tool)
		end))
	end
	if equip then
		table.insert(connections, equip.Activated:Connect(function()
			onEquip(tool)
		end))
	end
	frame.Visible = true
	frame.Parent = template.Parent
	return { tool = tool, frame = frame, buy = buy, equip = equip, equipText = equipText }
end

local function setPromptsEnabled()
	local enabled = screen ~= nil
	for _, shop in shops do
		local prompt = shop.prompt
		if prompt then
			prompt.Enabled = enabled
		end
	end
end

local function unbind()
	local current = screen
	if current == nil then
		return
	end
	screen = nil
	openAnchor = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	for _, row in current.rows do
		row.frame:Destroy()
	end
	setPromptsEnabled()
end

local function bind(gui: ScreenGui)
	local current = screen
	if current and current.gui == gui then
		return
	end
	unbind()
	local found = Find.path(gui, "List.Template")
	if found == nil or not found:IsA("GuiObject") then
		if not templateWarned then
			templateWarned = true
			warn(`[WeaponShop] {SCREEN} : List.Template absent ou pas un GuiObject (contrat 2.2), écran pas branché`)
		end
		return
	end
	local template = found :: GuiObject
	template.Visible = false
	gui.Enabled = false
	-- Lignes d'exemple de la maquette de Clément (Preview_*, à côté du Template) : retirées de la
	-- copie du joueur, seules les lignes du code restent (liaison L-041).
	for _, sibling in (template.Parent :: Instance):GetChildren() do
		if string.sub(sibling.Name, 1, 8) == "Preview_" then
			sibling:Destroy()
		end
	end

	local connections: { RBXScriptConnection } = {}
	local rows: { Row } = {}
	for _, tool in Tools.List do
		local row = buildRow(template, tool, connections)
		if row then
			table.insert(rows, row)
		end
	end
	local closeButton = buttonIn(gui, "CloseButton")
	if closeButton then
		table.insert(connections, closeButton.Activated:Connect(close))
	end
	table.insert(connections, gui.AncestryChanged:Connect(function()
		if not gui:IsDescendantOf(localPlayer) then
			unbind()
		end
	end))
	screen = { gui = gui, rows = rows, connections = connections }
	refreshRows()
	setPromptsEnabled()
	if IS_STUDIO then
		print(`[WeaponShop] {SCREEN} branché : {#rows} outil(s)`)
	end
end

------------------------------------------------------------------------------
-- Invites des comptoirs
------------------------------------------------------------------------------

local function makePrompt(anchor: Instance): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = ACTION_TEXT
	prompt.ObjectText = OBJECT_TEXT
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Enabled = screen ~= nil
	prompt.Triggered:Connect(function()
		open(anchor)
	end)
	prompt.Parent = anchor
	return prompt
end

-- Pose l'invite sur la pièce actuelle du comptoir (elle change si le streaming retire la pièce).
local function ensurePrompt(shop: Shop)
	if shops[shop.inst] ~= shop then
		return -- comptoir retiré entre-temps
	end
	local anchor = anchorOf(shop.inst)
	local prompt = shop.prompt
	if prompt and anchor and prompt.Parent == anchor then
		return
	end
	if prompt then
		if openAnchor == prompt.Parent then
			close()
		end
		prompt:Destroy()
		shop.prompt = nil
	end
	if anchor then
		shop.prompt = makePrompt(anchor)
	end
end

local function attach(inst: Instance)
	if shops[inst] or not inMap(inst) then
		return
	end
	local shop: Shop = { inst = inst, prompt = nil, connections = {} }
	shops[inst] = shop
	local function later()
		task.defer(ensurePrompt, shop)
	end
	table.insert(shop.connections, inst.DescendantAdded:Connect(later))
	table.insert(shop.connections, inst.DescendantRemoving:Connect(later))
	ensurePrompt(shop)
end

local function detach(inst: Instance)
	local shop = shops[inst]
	if shop == nil then
		return
	end
	shops[inst] = nil
	for _, connection in shop.connections do
		connection:Disconnect()
	end
	local prompt = shop.prompt
	if prompt then
		if openAnchor == prompt.Parent then
			close()
		end
		prompt:Destroy()
	end
end

-- L'écran se ferme quand le joueur s'éloigne du comptoir (ou n'a plus de personnage).
local function onHeartbeat()
	local anchor = openAnchor
	if anchor == nil then
		return
	end
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local position = if anchor:IsDescendantOf(Workspace) then positionOf(anchor) else nil
	if root == nil or not root:IsA("BasePart") or position == nil then
		close()
	elseif (position - (root :: BasePart).Position).Magnitude > CLOSE_DISTANCE then
		close()
	end
end

function WeaponShopController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any

	localPlayer:GetAttributeChangedSignal(OWNED_ATTRIBUTE):Connect(refreshRows)
	localPlayer:GetAttributeChangedSignal(EQUIPPED_ATTRIBUTE):Connect(refreshRows)
	RunService.Heartbeat:Connect(onHeartbeat)

	CollectionService:GetInstanceAddedSignal(SHOP_TAG):Connect(attach)
	CollectionService:GetInstanceRemovedSignal(SHOP_TAG):Connect(detach)
	for _, inst in CollectionService:GetTagged(SHOP_TAG) do
		attach(inst)
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing)
	end
	task.delay(MISSING_SCREEN_DELAY, function()
		if screen == nil and IS_STUDIO then
			print(`[WeaponShop] écran {SCREEN} pas encore livré (UI-002) : la boutique d'armes attend l'écran`)
		end
	end)
end

return WeaponShopController
