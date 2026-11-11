--!strict
-- HotbarController (client, liaison L-095 point 6 ; noms : docs/claude/notes/ui-liste-pour-liaison.md,
-- lignes 22 à 25 ; prototype tools/clement/feel2_proto.luau) : la barre du bas de Clément,
-- StarterGui/UI_Hotbar, EN PLUS de l'écran d'inventaire UI_Inventory (on choisit dans l'écran, on se sert
-- de la barre). La barre Roblox reste coupée (InventoryController).
--
-- Une seule source : InventoryController. Il lit l'état (attribut InventoryState du Player), trouve
-- l'outil de casse et la batte, et fait les actions ; la barre ne fait que les montrer et les appeler
-- (GetInventory, GetTools, OnChanged, ToggleBreakingTool, ToggleBat, StartPlacing, StopPlacing,
-- PlaceItem). Les touches restent écoutées par InventoryController, qui les passe à la barre
-- (SetSlotKeys) : une seule écoute, jamais deux actions pour une touche.
--
-- Rôle :
--   - Bar (en bas au centre) : SlotCount cases sur PC, TouchSlotCount sur téléphone (attributs de Bar
--     posés par Clément ; écran tactile sans clavier = téléphone, règle de ShatterController). Une case =
--     une copie de Bar.Template nommée Slot_<clé>, LayoutOrder = son rang. Ordre : outil de casse (clé
--     Tool), batte (Bat), toujours là pour que 1 et 2 ne bougent pas ; puis les colis de l'inventaire
--     (pas posés au sol) et les objets de l'inventaire (pas exposés), du plus récent au plus ancien :
--     ce qui arrive pendant la partie passe devant ; au premier état lu, les colis (le plus récent
--     d'abord) puis les objets (ordre d'InventoryService, les plus rentables d'abord) ;
--   - chaque case : Icon = ICON_TOOL_<Id>, ICON_TOOL_Bat, ICON_BOX_<Tier> ou ICON_<ItemId> (Contract/
--     Icons ; pas livrée : l'image du Template pour un outil ou un colis, rien pour un objet), KeyLabel
--     = son numéro (caché sur téléphone), ItemName = le nom (« Fists », « Premium Box », nom de l'objet),
--     Income = « $X/s » pour un objet seulement ($/s de l'objet, mutation comprise, calculé par le
--     serveur avec Formulas.ItemIncome), caché sinon ; Clip.BackgroundColor3 = couleur de la rareté
--     assombrie de 45 % et Clip.Glow à la couleur de la rareté (colis et objets ; les outils gardent le
--     fond du modèle) ; Equipped sur l'outil en main ou le colis en cours de pose ;
--   - touches 1 à SlotCount (1 à TouchSlotCount sur téléphone), clic ou appui sur une case : outil de
--     casse ou batte en main, ou rangé s'il y était ; colis : mode pose (InventoryController.StartPlacing),
--     ou fin du mode pose s'il était en cours pour ce colis ; objet : posé sur le présentoir libre le
--     plus proche (PlaceItemAuto). Le serveur revérifie tout ;
--   - animations (Controllers/UI/Motion, sans le modifier) : survol T.34 HoverCard (Icon grossi et
--     penché, HoverOutline ; UiFeelController le branche aussi sur toute carte qui a un HoverOutline,
--     sans effet la 2e fois) ; appui et relâché T.31-32 par Motion.Pop (× Press.To puis retour en
--     Release.Time, Back Out) : Motion.Button doublerait le son UI_Hover de HoverCard ; réussite T.33
--     par Motion.Pop (× Success.From → 1 en Success.Time) sur la case d'un outil qui arrive en main ;
--   - un outil arrive en main (barre, touche, écran, près d'une vitrine…) : son UI_Equip et message vert
--     « <outil> equipped! » (NotifyController.Show, catégorie Success ; UI_Toast passe derrière Notify) ;
--   - Enabled de l'écran = branché et pas en poursuite (ChaseController.IsChased), revu toutes les TICK s :
--     ChaseFeelController cache la barre pendant la poursuite, ce code ne la rallume jamais tant qu'elle
--     dure, et la rallume après (même si l'écran est arrivé pendant la poursuite).
-- Seuls sont touchés (2.2, « Libre pour Ironix ») : Enabled de l'écran, les copies du Template (nom,
-- ordre, Visible), leurs textes, l'image de leur Icon, Visible de KeyLabel, Income et Equipped, et les
-- couleurs de Clip et Clip.Glow demandées par Clément (ligne 23 de la liste). Écran recréé
-- (ResetOnSpawn) : rebranché. Rien n'est envoyé au serveur ici.
--
-- À voir avec Clément (L-095 point 6, ligne 25) : sur un petit téléphone (667 × 375), la barre touche
-- l'argent. Le code ne déplace rien.
--
-- API (client) :
--   HotbarController.Use(index)        l'action de la case `index` (barre de commande, bancs)
--   HotbarController.GetState() -> { Bound, Enabled, Count, Phone, Slots = { { Key, Kind, Uid, Name,
--                                     Income, Equipped } } }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bat = require(Config:WaitForChild("Bat"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Tools = require(Config:WaitForChild("Tools"))
local UiMotion = require(Config:WaitForChild("UiMotion"))
local Format = require(Shared:WaitForChild("Format"))
local InventoryState = require(Shared:WaitForChild("InventoryState"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local Icons = require(Contract:WaitForChild("Icons"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

-- Ce que la barre utilise d'InventoryController.
type InventoryApi = {
	GetInventory: () -> InventoryState.State,
	GetTools: () -> { Breaking: Tool?, Bat: Tool?, Held: Tool? },
	GetState: () -> { [string]: any },
	OnChanged: (listener: () -> ()) -> () -> (),
	SetSlotKeys: (handler: ((index: number) -> boolean)?) -> (),
	ToggleBreakingTool: () -> (),
	ToggleBat: () -> (),
	StartPlacing: (boxUid: string) -> (),
	StopPlacing: () -> (),
	PlaceItem: (itemUid: string) -> (),
}
type ChaseApi = { IsChased: () -> boolean }
type NotifyApi = { Show: (message: string, kind: string?) -> () }

-- "Tool", "Bat", "Box" ou "Item" (une chaîne : l'ancien solveur suit mal les unions de chaînes fixes).
type Kind = string

-- Ce que montre une case.
type Slot = {
	key: string, -- Tool, Bat, Box_<uid>, Item_<uid>
	kind: Kind,
	uid: string?,
	name: string,
	icon: string, -- nom passé à Icons.get
	rarity: string?,
	income: number?,
	equipped: boolean,
}

-- Une case clonée.
type View = {
	frame: GuiButton,
	refs: { [string]: Instance? },
	slot: Slot,
	connections: { RBXScriptConnection },
}

-- Écran branché.
type Screen = {
	gui: ScreenGui,
	bar: Instance,
	template: GuiButton,
	templateIcon: string, -- image de l'Icon du Template (outil ou colis sans icône livrée)
	views: { [string]: View },
	connections: { RBXScriptConnection },
}

-- Contrat 2.2 (lignes 22 et 23 de la liste de Clément).
local SCREEN = "UI_Hotbar"
local BAR = "Bar"
local TEMPLATE = "Template"
local SLOT_PREFIX = "Slot_"
local PARTS = { "Clip", "Clip.Glow", "Icon", "KeyLabel", "ItemName", "Income", "Equipped" }
local SLOT_COUNT_ATTRIBUTE = "SlotCount"
local TOUCH_SLOT_COUNT_ATTRIBUTE = "TouchSlotCount"
-- Valeurs de la note de Clément (ligne 22), si l'attribut manque.
local DEFAULT_SLOTS = 6
local DEFAULT_TOUCH_SLOTS = 4
local MAX_SLOTS = 9 -- touches 1 à 9 d'InventoryController

local TOOL_ID_ATTRIBUTE = "ToolId" -- ToolService : l'outil de casse
local BAT_ATTRIBUTE = "BatTool" -- ToolService : la batte
local TOOL_ICON_PREFIX = "TOOL_" -- « ICON_TOOL_Fists » (L-090)
local BAT_ICON = "TOOL_Bat" -- « ICON_TOOL_Bat » (L-092 2a)
local BOX_ICON_PREFIX = "BOX_" -- « ICON_BOX_Premium » (L-089)

-- Textes, en anglais (L-036) : prototype de Clément (« $22.5K/s », « Crown equipped! ») ; « Premium Box »
-- V0 proposé, absent du doc.
local INCOME_TEXT = "%s/s"
local BOX_NAME = "%s Box"
local EQUIPPED_TEXT = "%s equipped!"
local SUCCESS_KIND = "Success" -- catégorie du message vert (NotifyController, UI_Toast)
local EQUIP_SOUND = "UI_Equip" -- ReplicatedStorage/Assets/Sounds/UI/UI_Equip
local DARKEN = 0.45 -- Clip : couleur de la rareté assombrie de 45 % (ligne 23)
local TICK = 0.25 -- V0 proposé, absent du doc : s entre deux vérifications de la poursuite

local PRESS_INFO = TweenInfo.new(UiMotion.Release.Time, UiMotion.Release.Style, UiMotion.Release.Direction)
local SUCCESS_INFO = TweenInfo.new(UiMotion.Success.Time, UiMotion.Success.Style, UiMotion.Success.Direction)

local IS_STUDIO = RunService:IsStudio()

local HotbarController = {}

local localPlayer = Players.LocalPlayer
local inventory: InventoryApi? = nil
local chase: ChaseApi? = nil
local notify: NotifyApi? = nil
local screen: Screen? = nil
local slots: { Slot } = {}
local count = DEFAULT_SLOTS
local phone = false
local refreshQueued = false
local arrival: { [string]: number } = {} -- clé de colis ou d'objet → rang d'arrivée (plus grand = plus récent)
local arrivals = 0
local textures: { [string]: string } = {}
local missingIcons: { [string]: boolean } = {}
local reported: { [string]: boolean } = {}
local characterConnection: RBXScriptConnection? = nil

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

------------------------------------------------------------------------------
-- Outils d'écran
------------------------------------------------------------------------------

local function isImage(inst: Instance?): boolean
	return inst ~= nil and (inst:IsA("ImageLabel") or inst:IsA("ImageButton"))
end

local function setText(element: Instance?, text: string)
	if element == nil then
		return
	end
	local holder: Instance? = element
	if not (element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox")) then
		holder = element:FindFirstChildWhichIsA("TextLabel", true)
	end
	if holder then
		local label = holder :: any
		if label.Text ~= text then
			label.Text = text
		end
	end
end

local function setVisible(element: Instance?, visible: boolean)
	if element and element:IsA("GuiObject") and (element :: GuiObject).Visible ~= visible then
		(element :: GuiObject).Visible = visible
	end
end

local function setImage(element: Instance?, image: string)
	if isImage(element) then
		local target = element :: any
		if target.Image ~= image then
			target.Image = image
		end
	end
end

-- Couleur d'une image (ImageColor3), sinon de son fond.
local function setColor(element: Instance?, color: Color3)
	if element == nil or not element:IsA("GuiObject") then
		return
	end
	if isImage(element) then
		(element :: any).ImageColor3 = color
	else
		(element :: GuiObject).BackgroundColor3 = color
	end
end

-- Image de l'icône ICON_<name> (une recherche par nom et par session), nil si elle n'est pas livrée.
local function textureOf(name: string): string?
	local known = textures[name]
	if known ~= nil or missingIcons[name] then
		return known
	end
	local texture = Icons.get(name)
	if texture ~= nil then
		textures[name] = texture
	else
		missingIcons[name] = true
		reportOnce(`icon:{name}`, `[Hotbar] icône {Icons.name(name)} pas livrée : case sans cette image`)
	end
	return texture
end

------------------------------------------------------------------------------
-- Cases : ce qu'elles montrent
------------------------------------------------------------------------------

local function isPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Nombre de cases : attribut de Bar (SlotCount, ou TouchSlotCount sur téléphone), entre 1 et 9.
local function slotCount(bar: Instance?): number
	local attribute = if phone then TOUCH_SLOT_COUNT_ATTRIBUTE else SLOT_COUNT_ATTRIBUTE
	local value = if bar then bar:GetAttribute(attribute) else nil
	local wanted = if type(value) == "number" then value else (if phone then DEFAULT_TOUCH_SLOTS else DEFAULT_SLOTS)
	return math.clamp(math.floor(wanted), 1, MAX_SLOTS)
end

local function toolName(tool: Tool?): (string, string)
	local id = if tool then tool:GetAttribute(TOOL_ID_ATTRIBUTE) else nil
	-- Pas encore d'outil (profil pas chargé) : celui du départ, comme l'écran (Tools.DefaultId).
	local wanted: string = if type(id) == "string" and Tools.ById[id] ~= nil then id else Tools.DefaultId
	for _, def in Tools.List do
		if def.Id == wanted then
			return def.DisplayName, def.Id
		end
	end
	return wanted, wanted
end

-- Colis et objets de l'inventaire, du plus récent au plus ancien (voir l'en-tête).
local function stockSlots(api: InventoryApi, placing: string?): { Slot }
	local current = api.GetInventory()
	local base: { Slot } = {}
	local boxes: { Slot } = {}
	for _, box in current.Boxes do
		if not box.Placed then
			table.insert(boxes, 1, { -- InventoryService : le plus ancien d'abord ; ici le plus récent d'abord
				key = "Box_" .. box.Uid,
				kind = "Box",
				uid = box.Uid,
				name = string.format(BOX_NAME, box.Tier),
				icon = BOX_ICON_PREFIX .. box.Tier,
				rarity = box.Rarity,
				income = nil,
				equipped = placing == box.Uid,
			})
		end
	end
	table.move(boxes, 1, #boxes, 1, base)
	for _, item in current.Items do
		local def = Items.ById[item.ItemId]
		if item.Slot == nil and def ~= nil then
			local rarity: string = def.Rarity
			local income: number = item.Income
			local slot: Slot = {
				key = "Item_" .. item.Uid,
				kind = "Item",
				uid = item.Uid,
				name = def.DisplayName,
				icon = def.Id,
				rarity = rarity,
				income = income,
				equipped = false,
			}
			table.insert(base, slot)
		end
	end
	-- Rang d'arrivée : ce qui n'a pas encore de rang en reçoit un plus grand que tous les autres, dans
	-- l'ordre de base (le premier de la liste est le plus récent du lot).
	local present: { [string]: boolean } = {}
	local fresh: { Slot } = {}
	for _, slot in base do
		present[slot.key] = true
		if arrival[slot.key] == nil then
			table.insert(fresh, slot)
		end
	end
	for rank, slot in fresh do
		arrival[slot.key] = arrivals + #fresh - rank + 1
	end
	arrivals += #fresh
	for key in arrival do
		if not present[key] then
			arrival[key] = nil -- parti (posé, exposé, ouvert) : s'il revient, il compte comme nouveau
		end
	end
	table.sort(base, function(a: Slot, b: Slot): boolean
		return arrival[a.key] > arrival[b.key]
	end)
	return base
end

local function buildSlots(api: InventoryApi): { Slot }
	local tools = api.GetTools()
	local held = tools.Held
	local placing = api.GetState().Placing
	local placingUid: string? = if type(placing) == "string" then placing else nil
	local breaking = tools.Breaking
	local name, id = toolName(breaking)
	local list: { Slot } = {
		{
			key = "Tool",
			kind = "Tool",
			uid = nil,
			name = name,
			icon = TOOL_ICON_PREFIX .. id,
			rarity = nil,
			income = nil,
			equipped = held ~= nil and held:GetAttribute(TOOL_ID_ATTRIBUTE) ~= nil,
		},
		{
			key = "Bat",
			kind = "Bat",
			uid = nil,
			name = Bat.DisplayName,
			icon = BAT_ICON,
			rarity = nil,
			income = nil,
			equipped = held ~= nil and held:GetAttribute(BAT_ATTRIBUTE) == true,
		},
	}
	for _, slot in stockSlots(api, placingUid) do
		if #list >= count then
			break
		end
		table.insert(list, slot)
	end
	while #list > count do
		table.remove(list)
	end
	return list
end

------------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------------

local function use(slot: Slot)
	local api = inventory
	if api == nil then
		return
	end
	local kind = slot.kind
	local uid = slot.uid
	if kind == "Tool" then
		api.ToggleBreakingTool()
	elseif kind == "Bat" then
		api.ToggleBat()
	elseif kind == "Box" and uid then
		if api.GetState().Placing == uid then
			api.StopPlacing()
		else
			api.StartPlacing(uid)
		end
	elseif kind == "Item" and uid then
		api.PlaceItem(uid)
	end
end

-- Touche 1 à 9, reçue d'InventoryController : traitée si la barre est là et que la touche a une case.
local function onSlotKey(index: number): boolean
	if screen == nil or index > count then
		return false
	end
	local slot = slots[index]
	if slot then
		use(slot)
	end
	return true
end

------------------------------------------------------------------------------
-- Cases : copies du Template
------------------------------------------------------------------------------

local function destroyView(view: View)
	for _, connection in view.connections do
		connection:Disconnect()
	end
	view.frame:Destroy()
end

local function newView(current: Screen, slot: Slot): View?
	local clone: Instance? = current.template:Clone()
	if clone == nil then
		return nil -- Archivable = false : rien à cloner
	end
	local frame = clone :: GuiButton
	frame.Name = SLOT_PREFIX .. slot.key
	local refs: { [string]: Instance? } = {}
	for _, path in PARTS do
		refs[path] = Find.path(frame, path)
	end
	local view: View = { frame = frame, refs = refs, slot = slot, connections = {} }
	table.insert(
		view.connections,
		frame.Activated:Connect(function()
			use(view.slot)
		end)
	)
	-- Appui (T.31) et relâché (T.32) en un sursaut : × Press.To, puis retour à 1 (Back Out).
	local function press()
		Motion.Pop(frame, UiMotion.Press.To, PRESS_INFO)
	end
	table.insert(view.connections, frame.MouseButton1Down:Connect(press))
	table.insert(
		view.connections,
		frame.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				press()
			end
		end)
	)
	Motion.HoverCard(frame) -- T.34
	setVisible(refs.Equipped, false)
	frame.Visible = true
	frame.Parent = current.bar
	return view
end

local function paint(current: Screen, view: View, slot: Slot, rank: number)
	view.slot = slot
	local refs = view.refs
	view.frame.LayoutOrder = rank
	setText(refs.KeyLabel, tostring(rank))
	setVisible(refs.KeyLabel, not phone)
	setText(refs.ItemName, slot.name)
	local texture = textureOf(slot.icon)
	if texture then
		setImage(refs.Icon, texture)
	elseif slot.kind == "Item" then
		setImage(refs.Icon, "")
	else
		setImage(refs.Icon, current.templateIcon)
	end
	local income = slot.income
	setVisible(refs.Income, income ~= nil)
	if income ~= nil then
		setText(refs.Income, string.format(INCOME_TEXT, Format.money(income)))
	end
	local rarity = if slot.rarity then Rarities.ById[slot.rarity] else nil
	if rarity then
		local color = rarity.Color
		local keep = 1 - DARKEN
		setColor(refs.Clip, Color3.new(color.R * keep, color.G * keep, color.B * keep))
		setColor(refs["Clip.Glow"], color)
	end
	setVisible(refs.Equipped, slot.equipped)
end

local function refresh()
	refreshQueued = false
	local api = inventory
	local current = screen
	if api == nil then
		return
	end
	if current and current.gui.Parent == nil then
		screen = nil
		current = nil
	end
	phone = isPhone()
	count = slotCount(if current then current.bar else nil)
	slots = buildSlots(api)
	if current == nil then
		return
	end
	local seen: { [string]: boolean } = {}
	for rank, slot in slots do
		local view = current.views[slot.key] or newView(current, slot)
		if view then
			current.views[slot.key] = view
			paint(current, view, slot, rank)
			seen[slot.key] = true
		end
	end
	for key, view in current.views do
		if not seen[key] then
			destroyView(view)
			current.views[key] = nil
		end
	end
end

local function queueRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(refresh)
end

------------------------------------------------------------------------------
-- Écran, poursuite
------------------------------------------------------------------------------

local function isChased(): boolean
	local api = chase
	if api == nil then
		return false
	end
	local ok, result = pcall(api.IsChased)
	return ok and result == true
end

-- Enabled = branché et pas en poursuite (jamais rallumé pendant une poursuite : ChaseFeelController).
local function updateEnabled()
	local current = screen
	if current == nil or current.gui.Parent == nil then
		return
	end
	local wanted = not isChased()
	if current.gui.Enabled ~= wanted then
		current.gui.Enabled = wanted
	end
end

local function unbind()
	local current = screen
	if current == nil then
		return
	end
	screen = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	for _, view in current.views do
		destroyView(view)
	end
end

local function bind(gui: ScreenGui)
	if screen and screen.gui == gui then
		return
	end
	local bar = Find.path(gui, BAR)
	local found = if bar then Find.path(bar, TEMPLATE) else nil
	if bar == nil or found == nil or not found:IsA("GuiButton") then
		reportOnce("template", `[Hotbar] {SCREEN}.{BAR}.{TEMPLATE} introuvable ou pas un bouton : pas de barre du bas`)
		return
	end
	unbind()
	local template = found :: GuiButton
	template.Visible = false
	local icon = Find.path(template, "Icon")
	local current: Screen = {
		gui = gui,
		bar = bar :: Instance,
		template = template,
		templateIcon = if isImage(icon) then (icon :: any).Image else "",
		views = {},
		connections = {},
	}
	screen = current
	for _, attribute in { SLOT_COUNT_ATTRIBUTE, TOUCH_SLOT_COUNT_ATTRIBUTE } do
		table.insert(current.connections, (bar :: Instance):GetAttributeChangedSignal(attribute):Connect(queueRefresh))
	end
	table.insert(
		current.connections,
		gui.AncestryChanged:Connect(function()
			if gui.Parent == nil and screen == current then
				unbind()
			end
		end)
	)
	refresh()
	updateEnabled()
end

------------------------------------------------------------------------------
-- Outil en main : son, message, réussite
------------------------------------------------------------------------------

local function onEquipped(tool: Tool)
	local key: string
	local name: string
	if tool:GetAttribute(BAT_ATTRIBUTE) == true then
		key, name = "Bat", Bat.DisplayName
	elseif tool:GetAttribute(TOOL_ID_ATTRIBUTE) ~= nil then
		key = "Tool"
		name = toolName(tool)
	else
		return
	end
	Motion.PlaySound(EQUIP_SOUND)
	local api = notify
	if api then
		pcall(api.Show, string.format(EQUIPPED_TEXT, name), SUCCESS_KIND)
	end
	local current = screen
	local view = if current then current.views[key] else nil
	if view and view.frame.Parent ~= nil then
		Motion.Pop(view.frame, UiMotion.Success.From, SUCCESS_INFO) -- T.33
	end
end

local function watchCharacter(character: Model?)
	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	if character == nil then
		return
	end
	characterConnection = character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") then
			onEquipped(child :: Tool)
		end
	end)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function HotbarController.Use(index: number)
	local slot = slots[index]
	if slot then
		use(slot)
	end
end

function HotbarController.GetState(): { [string]: any }
	local current = screen
	local list = {}
	for _, slot in slots do
		table.insert(list, {
			Key = slot.key,
			Kind = slot.kind,
			Uid = slot.uid,
			Name = slot.name,
			Income = slot.income,
			Equipped = slot.equipped,
		})
	end
	return {
		Bound = current ~= nil,
		Enabled = current ~= nil and current.gui.Enabled,
		Count = count,
		Phone = phone,
		Slots = list,
	}
end

function HotbarController.Start()
	local module = script.Parent:WaitForChild("InventoryController")
	local api = require(module :: ModuleScript) :: any
	inventory = api
	chase = sibling("ChaseController")
	notify = sibling("NotifyController")
	api.OnChanged(queueRefresh)
	api.SetSlotKeys(onSlotKey)

	localPlayer.CharacterAdded:Connect(watchCharacter)
	watchCharacter(localPlayer.Character)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	else
		reportOnce("screen", `[Hotbar] écran {SCREEN} absent de PlayerGui pour l'instant : touches 1 et 2 d'origine`)
		refresh()
	end

	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, message: any = pcall(updateEnabled)
			if not ok then
				reportOnce("enabled", `[Hotbar] poursuite : {message}`)
			end
		end
	end)
end

return HotbarController
