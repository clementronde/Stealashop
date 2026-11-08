--!strict
-- AuraShopController (DEV-032, client) : boutique d'auras et de trails, écran UI_AuraShop de
-- Clément (contrat 2.2, UI-003 ; Partie 1, sections 5.9, 5.10 et 7.4).
--
-- Rôle :
--   - une invite (ProximityPrompt « AuraShopPrompt » : « Shop », « Aura Shop »), créée ici côté
--     client sur le comptoir taggé AuraShop (sa PrimaryPart, sinon sa première pièce), ouvre
--     l'écran ; CloseButton le ferme, et il se ferme seul quand le joueur s'éloigne du comptoir ;
--   - deux onglets, Tabs.AurasTab et Tabs.TrailsTab (auras à l'ouverture, puis le dernier
--     onglet choisi). Une ligne par aura ou par trail de Config/Cosmetics, dans l'ordre des
--     paliers, clonée depuis List.Template :
--       ItemName     nom affiché (Config, en anglais)
--       Bonus        « ×1.5 power » (aura) ou « ×1.1 speed » (trail)
--       Price        prix, Format.money (« $15K »)
--       Icon         texture de Clément (Decal FX_Aura_… ou FX_Trail_… de ReplicatedStorage/Assets)
--                    si elle est livrée ; sinon l'image posée dans le Template reste
--       BuyButton    visible tant que l'objet n'est pas possédé : envoie BuyItem(id), traité par
--                    ShopService
--       EquipButton  visible quand l'objet est possédé : envoie EquipCosmetic(id) ; son texte dit
--                    « Equip », ou « Unequip » sur l'objet équipé
--     Les lignes suivent les attributs OwnedCosmetics, EquippedAura et EquippedTrail du Player
--     (posés par CosmeticService) : elles se mettent à jour après chaque achat ou équipement ;
--   - tant que UI_AuraShop manque (UI-003 pas encore livré), l'invite reste mais n'ouvre rien :
--     une seule ligne dans la sortie, en Studio. Un écran recréé (ResetOnSpawn) est rebranché, fermé ;
--   - ouverture et fermeture animées (DEV-052) par UI/Motion : Motion.Open et Motion.Close
--     allument et éteignent l'écran ; les lignes sont retirées une fois l'écran éteint (pas pendant
--     sa sortie), et une réouverture pendant la fermeture la rattrape.
-- Les éléments sont cherchés par leur nom parmi les descendants de l'écran (Contract/Find). Seuls
-- sont touchés : Enabled de l'écran, les textes, la visibilité, le nom et l'ordre des lignes
-- clonées, l'image de Icon (2.2, « Libre pour Ironix ») ; jamais un style (l'effet d'échelle de
-- Motion est passager). Texte d'un bouton :
-- écrit sur le bouton s'il en porte déjà un, sinon dans le premier TextLabel qu'il contient.
-- Casse : un texte d'exemple en capitales (« AURA NAME », « EQUIP ») donne un texte en capitales
-- (« SPARK », « UNEQUIP ») ; sinon le texte est écrit tel quel.
-- Le serveur décide tout (prix, argent, possession) : le client demande et affiche.
--
-- API (client) : aucune.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type Kind = "Aura" | "Trail"
type Cosmetic = typeof(Cosmetics.Auras[1])

type Row = {
	def: Cosmetic,
	frame: GuiObject,
	buy: GuiObject?,
	equip: GuiObject?,
	equipText: Instance?, -- TextButton ou TextLabel où écrire « Equip » / « Unequip »
}

-- Écran branché.
type Shop = {
	gui: ScreenGui,
	template: GuiObject?,
	connections: { RBXScriptConnection },
	rows: { Row },
}

local SCREEN = "UI_AuraShop"
local SHOP_TAG = "AuraShop"
local PROMPT_NAME = "AuraShopPrompt"
local ROW_PREFIX = "Item_" -- nom des lignes clonées (jamais « Template »)
local ROOT_PART = "HumanoidRootPart"
local ASSETS_FOLDER = "Assets" -- textures de Clément, depuis ReplicatedStorage

-- Attributs du Player posés par CosmeticService (mêmes noms là-bas).
local OWNED_ATTRIBUTE = "OwnedCosmetics"
local AURA_ATTRIBUTE = "EquippedAura"
local TRAIL_ATTRIBUTE = "EquippedTrail"

-- V0 proposé, absent du doc : textes (en anglais, L-036), portée de l'invite, et distance au
-- comptoir (studs) au-delà de laquelle l'écran se ferme.
local ACTION_TEXT = "Shop"
local OBJECT_TEXT = "Aura Shop"
local EQUIP_TEXT = "Equip"
local UNEQUIP_TEXT = "Unequip"
local PROMPT_DISTANCE = 10
local CLOSE_DISTANCE = 16

local IS_STUDIO = RunService:IsStudio()

local AuraShopController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local shop: Shop? = nil
local tab: Kind = "Aura"
local openAt: BasePart? = nil -- pièce du comptoir d'où l'écran est ouvert ; nil = fermé
local prompts: { [Instance]: ProximityPrompt } = {}
local shopConnections: { [Instance]: { RBXScriptConnection } } = {}
local reported: { [string]: boolean } = {}

-- Une ligne de sortie par sujet, en Studio seulement.
local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

-- Données --------------------------------------------------------------------------------------

local function ownedSet(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local value = localPlayer:GetAttribute(OWNED_ATTRIBUTE)
	if type(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			set[id] = true
		end
	end
	return set
end

local function equippedId(kind: string): string?
	local value = localPlayer:GetAttribute(if kind == "Aura" then AURA_ATTRIBUTE else TRAIL_ATTRIBUTE)
	return if type(value) == "string" then value else nil
end

-- « ×1.5 power », « ×1.25 speed » (%g : 1.25 reste 1.25, 2 s'écrit 2).
local function bonusText(def: Cosmetic): string
	local word = if def.Kind == "Aura" then "power" else "speed"
	return `×{string.format("%g", def.Multiplier)} {word}`
end

-- Texture du premier Decal de Clément nommé `name` (ReplicatedStorage/Assets, sous-dossiers
-- compris), ou nil. Un Decal, pas le premier objet de ce nom : les modèles d'effet portent les mêmes
-- noms (L-042).
local function textureOf(name: string): string?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
	for _, found in if assets then Find.all(assets, name) else {} do
		if found:IsA("Decal") and (found :: Decal).Texture ~= "" then
			return (found :: Decal).Texture
		end
	end
	return nil
end

-- Écran ----------------------------------------------------------------------------------------

-- En capitales si le texte d'exemple de Clément l'est (« AURA NAME » : noms en capitales, planche
-- 10.6), sinon tel quel : la casse suit son style sans qu'on le touche.
local function matchCase(sample: string, text: string): string
	if string.find(sample, "%a") ~= nil and sample == string.upper(sample) then
		return string.upper(text)
	end
	return text
end

-- Écrit `text` dans `element` s'il affiche un texte, à la casse de son texte actuel.
local function writeText(element: Instance?, text: string)
	if element and (element:IsA("TextLabel") or element:IsA("TextButton")) then
		local label = element :: any
		label.Text = matchCase(label.Text, text)
	end
end

-- Écrit `text` dans l'élément `name` de `root` ; élément absent : rien (le ContractChecker le
-- signale).
local function setText(root: Instance, name: string, text: string)
	writeText(Find.path(root, name), text)
end

-- Où écrire le texte d'un bouton : le bouton s'il porte déjà un texte, sinon le premier TextLabel
-- qu'il contient (bouton habillé) ; nil pour un bouton sans texte, auquel on n'en ajoute pas.
local function textHolder(button: Instance): Instance?
	if button:IsA("TextButton") and (button :: TextButton).Text ~= "" then
		return button
	end
	return button:FindFirstChildWhichIsA("TextLabel", true)
end

local function guiObject(root: Instance, name: string): GuiObject?
	local found = Find.path(root, name)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

-- Clic sur un élément : Activated pour un bouton, sinon toucher ou clic gauche sur le cadre.
local function onClick(element: Instance?, handler: () -> ()): RBXScriptConnection?
	if element == nil then
		return nil
	end
	if element:IsA("GuiButton") then
		return (element :: GuiButton).Activated:Connect(function()
			handler()
		end)
	end
	if element:IsA("GuiObject") then
		return (element :: GuiObject).InputBegan:Connect(function(input: InputObject)
			local inputType = input.UserInputType
			if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
				handler()
			end
		end)
	end
	return nil
end

local function clearRows(current: Shop)
	for _, row in current.rows do
		row.frame:Destroy()
	end
	table.clear(current.rows)
end

-- Boutons et texte d'équipement de chaque ligne, d'après les attributs du Player.
local function refreshRows()
	local current = shop
	if current == nil then
		return
	end
	local owned = ownedSet()
	for _, row in current.rows do
		local def = row.def
		local isOwned = owned[def.Id] == true
		local buy, equip, label = row.buy, row.equip, row.equipText
		if buy then
			buy.Visible = not isOwned
		end
		if equip then
			equip.Visible = isOwned
		end
		writeText(label, if isOwned and equippedId(def.Kind) == def.Id then UNEQUIP_TEXT else EQUIP_TEXT)
	end
end

-- Lignes de l'onglet ouvert, clonées depuis List.Template.
local function buildRows()
	local current = shop
	if current == nil then
		return
	end
	clearRows(current)
	local template = current.template
	if template == nil then
		return
	end
	local sorted = table.clone(if tab == "Aura" then Cosmetics.Auras else Cosmetics.Trails)
	table.sort(sorted, function(a: Cosmetic, b: Cosmetic): boolean
		return a.Order < b.Order
	end)
	for _, def in sorted do
		local frame = template:Clone()
		frame.Name = ROW_PREFIX .. def.Id
		frame.LayoutOrder = def.Order
		frame.Visible = true
		setText(frame, "ItemName", def.DisplayName)
		setText(frame, "Bonus", bonusText(def))
		setText(frame, "Price", Format.money(def.Price))
		local texture = textureOf(def.Texture)
		local icon = Find.path(frame, "Icon")
		if texture and icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
			(icon :: any).Image = texture
		end
		local buy = guiObject(frame, "BuyButton")
		local equip = guiObject(frame, "EquipButton")
		local id = def.Id
		onClick(buy, function()
			net.Client.BuyItem:Fire(id)
		end)
		onClick(equip, function()
			net.Client.EquipCosmetic:Fire(id)
		end)
		table.insert(current.rows, {
			def = def,
			frame = frame,
			buy = buy,
			equip = equip,
			equipText = if equip then textHolder(equip) else nil,
		})
		frame.Parent = template.Parent
	end
	refreshRows()
end

local function closeShop()
	openAt = nil
	local current = shop
	if current then
		-- Lignes retirées une fois l'écran éteint ; une réouverture d'ici là les reconstruit.
		Motion.Close(current.gui, function()
			clearRows(current)
		end)
	end
end

local function setTab(kind: Kind)
	tab = kind
	if openAt then
		buildRows()
	end
end

local function bind(gui: ScreenGui)
	local old = shop
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
		clearRows(old)
	end
	openAt = nil
	gui.Enabled = false -- fermé jusqu'à l'invite

	local template = guiObject(gui, "List.Template")
	if template == nil then
		reportOnce("template", `[AuraShop] {SCREEN}.List.Template introuvable : la liste restera vide`)
	else
		-- Lignes d'exemple de la maquette de Clément (Preview_*, à côté du Template) : retirées de
		-- la copie du joueur, seules les lignes du code restent (liaison L-041).
		for _, sibling in (template.Parent :: Instance):GetChildren() do
			if string.sub(sibling.Name, 1, 8) == "Preview_" then
				sibling:Destroy()
			end
		end
	end
	local current: Shop = { gui = gui, template = template, connections = {}, rows = {} }
	shop = current
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	keep(onClick(Find.path(gui, "CloseButton"), closeShop))
	keep(onClick(Find.path(gui, "Tabs.AurasTab"), function()
		setTab("Aura")
	end))
	keep(onClick(Find.path(gui, "Tabs.TrailsTab"), function()
		setTab("Trail")
	end))
end

-- Écran branché encore présent, ou celui de PlayerGui (branché au passage), ou nil.
local function currentShop(): Shop?
	local current = shop
	if current and current.gui.Parent ~= nil then
		return current
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild(SCREEN) else nil
	if gui and gui:IsA("ScreenGui") then
		bind(gui :: ScreenGui)
		return shop
	end
	return nil
end

local function openShop(counter: BasePart)
	local current = currentShop()
	if current == nil then
		reportOnce("screen", `[AuraShop] écran {SCREEN} absent de PlayerGui (UI-003 pas encore livré) : la boutique ne s'ouvre pas`)
		return
	end
	openAt = counter
	buildRows()
	Motion.Open(current.gui)
end

-- Fermeture quand le joueur s'éloigne du comptoir, ou que le comptoir ou l'écran disparaît.
local function checkOpen()
	local counter = openAt
	if counter == nil then
		return
	end
	local current = shop
	if current == nil or current.gui.Parent == nil or counter.Parent == nil then
		closeShop()
		return
	end
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild(ROOT_PART) else nil
	if root and root:IsA("BasePart") and ((root :: BasePart).Position - counter.Position).Magnitude > CLOSE_DISTANCE then
		closeShop()
	end
end

-- Comptoirs ------------------------------------------------------------------------------------

local function promptPart(counter: Instance): BasePart?
	if counter:IsA("BasePart") then
		return counter :: BasePart
	end
	if counter:IsA("Model") then
		local primary = (counter :: Model).PrimaryPart
		if primary and primary:IsDescendantOf(counter) then
			return primary
		end
	end
	return counter:FindFirstChildWhichIsA("BasePart", true)
end

-- Pose l'invite si elle manque (comptoir tout juste chargé, ou pièce de l'invite sortie du
-- streaming).
local function ensurePrompt(counter: Instance)
	local existing = prompts[counter]
	if existing then
		if existing:IsDescendantOf(counter) then
			return
		end
		existing:Destroy()
		prompts[counter] = nil
	end
	local part = promptPart(counter)
	if part == nil then
		return -- pas encore chargé : DescendantAdded rappellera
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = ACTION_TEXT
	prompt.ObjectText = OBJECT_TEXT
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		openShop(part)
	end)
	prompt.Parent = part
	prompts[counter] = prompt
end

local function addCounter(counter: Instance)
	if shopConnections[counter] or not counter:IsDescendantOf(Workspace) then
		return
	end
	shopConnections[counter] = {
		counter.DescendantAdded:Connect(function(descendant: Instance)
			if descendant:IsA("BasePart") then
				ensurePrompt(counter)
			end
		end),
		counter.DescendantRemoving:Connect(function(descendant: Instance)
			local prompt = prompts[counter]
			if prompt and prompt.Parent == descendant then
				task.defer(ensurePrompt, counter)
			end
		end),
	}
	ensurePrompt(counter)
end

local function removeCounter(counter: Instance)
	local connections = shopConnections[counter]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		shopConnections[counter] = nil
	end
	local prompt = prompts[counter]
	if prompt then
		prompt:Destroy()
		prompts[counter] = nil
	end
end

function AuraShopController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any

	for _, attribute in { OWNED_ATTRIBUTE, AURA_ATTRIBUTE, TRAIL_ATTRIBUTE } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(refreshRows)
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end

	CollectionService:GetInstanceAddedSignal(SHOP_TAG):Connect(addCounter)
	CollectionService:GetInstanceRemovedSignal(SHOP_TAG):Connect(removeCounter)
	for _, counter in CollectionService:GetTagged(SHOP_TAG) do
		addCounter(counter)
	end

	RunService.Heartbeat:Connect(checkOpen)
end

return AuraShopController
