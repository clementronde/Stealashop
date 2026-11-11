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
-- Cases stables, rangées par le joueur (vague 25, retour du Play de Cantin du 2026-11-11 ; décision
-- d'Ironix) : la disposition = HotbarLayout.Size (6) cases, chacune "Tool" (outil de casse), "Bat"
-- (batte), l'uid d'un colis de l'inventaire (pas posé) ou d'un objet de l'inventaire (pas exposé), ou
-- vide (Shared/HotbarLayout) :
--   - chaque chose garde sa case tant qu'elle est dans l'inventaire. Partie (colis posé, objet exposé,
--     ouvert, volé), sa case devient vide : rien ne se décale. Une chose nouvelle (arrivée pendant la
--     partie, ou revenue d'un présentoir) prend la première case vide montrée ; s'il n'y en a pas, elle
--     reste seulement dans l'écran d'inventaire ;
--   - au chargement : la disposition sauvegardée (attribut HotbarLayout du Player, posé par HotbarService
--     au chargement du profil) ; ce qui n'existe plus devient une case vide, ce qui est dans l'inventaire
--     sans case y reste (pas « nouveau »). Rien de sauvegardé (texte vide, ou attribut toujours absent
--     LAYOUT_WAIT s après l'inventaire) : outil, batte, puis les colis (le plus récent d'abord) et les
--     objets (ordre d'InventoryService, les plus rentables d'abord) dans les cases suivantes ;
--   - glisser-déposer, souris et doigt : une carte de UI_Inventory (objet de l'inventaire, colis pas
--     posé, outil : n'importe quel outil de casse donne "Tool", la batte "Bat") lâchée sur une case la
--     remplace (l'ancienne chose retourne seulement dans l'inventaire ; si la chose avait déjà une case,
--     celle-ci se vide) ; une case lâchée sur une autre : échange ; lâchée hors de Bar : case vidée.
--     Le glisser commence après DRAG_PIXELS de déplacement (ou, au doigt, après HOLD_TIME sans bouger :
--     un glissé du doigt qui fait défiler la liste reste un défilement). Une copie de la carte suit le
--     pointeur (DragGhost, CanvasGroup semi-transparent dans l'écran HotbarDrag créé par ce code,
--     détruit à la fin) ; la case visée montre son HoverOutline. Pendant le glisser, la liste de
--     l'inventaire ne défile pas (ScrollingEnabled remis à la fin). Un clic simple garde son effet ; le
--     clic qui termine un glisser est ignoré (SUPPRESS_TIME) ;
--   - sauvegarde : chaque changement (glisser, case vidée ou remplie) envoie SetHotbar(6 identifiants)
--     au serveur, regroupé en SEND_DELAY s ; HotbarService le vérifie et le garde dans le profil.
--
-- Rôle :
--   - Bar (en bas au centre) : SlotCount cases sur PC, TouchSlotCount sur téléphone (attributs de Bar
--     posés par Clément, au plus HotbarLayout.Size ; écran tactile sans clavier = téléphone, règle de
--     ShatterController ; les cases suivantes sont gardées mais pas montrées). Une case = une copie de
--     Bar.Template nommée Slot_<clé> (Slot_Tool, Slot_Bat, Slot_Box_<uid>, Slot_Item_<uid>, et
--     Slot_Empty_<rang> pour une case vide), LayoutOrder = son rang ;
--   - chaque case : Icon = ICON_TOOL_<Id>, ICON_TOOL_Bat, ICON_BOX_<Tier> ou ICON_<ItemId> (Contract/
--     Icons ; pas livrée : l'image du Template pour un outil ou un colis, rien pour un objet ; rien sur
--     une case vide), KeyLabel = son numéro (caché sur téléphone), ItemName = le nom (« Fists »,
--     « Premium Box », nom de l'objet ; vide sur une case vide), Income = « $X/s » pour un objet seulement
--     ($/s de l'objet, mutation comprise, calculé par le serveur avec Formulas.ItemIncome), caché sinon ;
--     Clip.BackgroundColor3 = couleur de la rareté assombrie de 45 % et Clip.Glow à la couleur de la
--     rareté (colis et objets ; les outils et les cases vides gardent le fond du modèle) ; Equipped sur
--     l'outil en main ou le colis en cours de pose ;
--   - touches 1 à SlotCount (1 à TouchSlotCount sur téléphone), clic ou appui sur une case : outil de
--     casse ou batte en main, ou rangé s'il y était ; colis : mode pose (InventoryController.StartPlacing),
--     ou fin du mode pose s'il était en cours pour ce colis ; objet : posé sur le présentoir libre le
--     plus proche (PlaceItemAuto) ; case vide : rien. Le serveur revérifie tout ;
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
-- ordre, Visible), leurs textes, l'image de leur Icon, Visible de KeyLabel, Income, Equipped et
-- HoverOutline (case visée pendant un glisser), les couleurs de Clip et Clip.Glow demandées par Clément
-- (ligne 23 de la liste), ScrollingEnabled de la liste de l'inventaire pendant un glisser, et l'écran
-- HotbarDrag de ce code. Écran recréé (ResetOnSpawn) : rebranché.
--
-- À voir avec Clément (L-095 point 6, ligne 25) : sur un petit téléphone (667 × 375), la barre touche
-- l'argent. Le code ne déplace rien.
--
-- API (client) :
--   HotbarController.Use(index)        l'action de la case `index` (barre de commande, bancs)
--   HotbarController.GetState() -> { Bound, Enabled, Count, Phone, Ready, Dragging, Layout = { 6 ids },
--                                     Slots = { { Key, Kind, Id, Uid, Name, Income, Equipped } } }

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
local HotbarLayout = require(Shared:WaitForChild("HotbarLayout"))
local InventoryState = require(Shared:WaitForChild("InventoryState"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local Icons = require(Contract:WaitForChild("Icons"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

-- Ce que la barre utilise d'InventoryController.
type CardDrag = {
	Press: (key: string, frame: GuiObject, input: InputObject, list: Instance?) -> (),
	Suppress: () -> boolean,
}
type InventoryApi = {
	GetInventory: () -> InventoryState.State,
	GetTools: () -> { Breaking: Tool?, Bat: Tool?, Held: Tool? },
	GetState: () -> { [string]: any },
	OnChanged: (listener: () -> ()) -> () -> (),
	SetSlotKeys: (handler: ((index: number) -> boolean)?) -> (),
	SetCardDrag: (hooks: CardDrag?) -> (),
	ToggleBreakingTool: () -> (),
	ToggleBat: () -> (),
	StartPlacing: (boxUid: string) -> (),
	StopPlacing: () -> (),
	PlaceItem: (itemUid: string) -> (),
}
type ChaseApi = { IsChased: () -> boolean }
type NotifyApi = { Show: (message: string, kind: string?) -> () }

-- "Tool", "Bat", "Box", "Item" ou "Empty" (une chaîne : l'ancien solveur suit mal les unions de chaînes fixes).
type Kind = string

-- Ce que montre une case.
type Slot = {
	key: string, -- Tool, Bat, Box_<uid>, Item_<uid>, Empty_<rang>
	id: string, -- identifiant de la disposition : "Tool", "Bat", uid, "" (vide)
	kind: Kind,
	uid: string?,
	name: string,
	icon: string?, -- nom passé à Icons.get ; nil pour une case vide
	rarity: string?,
	income: number?,
	equipped: boolean,
}

-- Une case clonée.
type View = {
	frame: GuiButton,
	refs: { [string]: Instance? },
	slot: Slot,
	rank: number,
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

-- Un appui sur une carte de l'inventaire ou une case de la barre : peut-être un glisser.
type Press = {
	source: string, -- "Card" (UI_Inventory) ou "Slot" (case de la barre)
	id: string, -- identifiant glissé
	from: number?, -- rang de la case d'origine (Slot)
	frame: GuiObject,
	input: InputObject,
	touch: boolean,
	start: Vector2,
	position: Vector2,
	list: ScrollingFrame?, -- liste de l'inventaire (défilement)
	canvas: Vector2?, -- CanvasPosition de la liste à l'appui
	scrolling: boolean?, -- ScrollingEnabled de la liste avant le glisser
	dragging: boolean,
	ghost: GuiObject?,
	target: number?, -- case visée
	connections: { RBXScriptConnection },
}

-- Contrat 2.2 (lignes 22 et 23 de la liste de Clément).
local SCREEN = "UI_Hotbar"
local BAR = "Bar"
local TEMPLATE = "Template"
local SLOT_PREFIX = "Slot_"
local PARTS = { "Clip", "Clip.Glow", "Icon", "KeyLabel", "ItemName", "Income", "Equipped", "HoverOutline" }
local SLOT_COUNT_ATTRIBUTE = "SlotCount"
local TOUCH_SLOT_COUNT_ATTRIBUTE = "TouchSlotCount"
-- Valeurs de la note de Clément (ligne 22), si l'attribut manque.
local DEFAULT_SLOTS = 6
local DEFAULT_TOUCH_SLOTS = 4
local MAX_SLOTS = HotbarLayout.Size -- cases gardées (décision d'Ironix, vague 25)

local TOOL_ID_ATTRIBUTE = "ToolId" -- ToolService : l'outil de casse
local BAT_ATTRIBUTE = "BatTool" -- ToolService : la batte
local TOOL_ICON_PREFIX = "TOOL_" -- « ICON_TOOL_Fists » (L-090)
local BAT_ICON = "TOOL_Bat" -- « ICON_TOOL_Bat » (L-092 2a)
local BOX_ICON_PREFIX = "BOX_" -- « ICON_BOX_Premium » (L-089)
-- Noms des cartes de UI_Inventory (InventoryController) : Item_<uid>, Box_<uid>, Tool_<Id>, Tool_Bat.
local CARD_ITEM = "Item_"
local CARD_BOX = "Box_"
local CARD_TOOL = "Tool_"
local CARD_BAT = "Tool_Bat"

-- Textes, en anglais (L-036) : prototype de Clément (« $22.5K/s », « Crown equipped! ») ; « Premium Box »
-- V0 proposé, absent du doc.
local INCOME_TEXT = "%s/s"
local BOX_NAME = "%s Box"
local EQUIPPED_TEXT = "%s equipped!"
local SUCCESS_KIND = "Success" -- catégorie du message vert (NotifyController, UI_Toast)
local EQUIP_SOUND = "UI_Equip" -- ReplicatedStorage/Assets/Sounds/UI/UI_Equip
local DARKEN = 0.45 -- Clip : couleur de la rareté assombrie de 45 % (ligne 23)
local TICK = 0.25 -- V0 proposé, absent du doc : s entre deux vérifications de la poursuite

-- Glisser-déposer et sauvegarde (vague 25). V0 proposés, absents du doc : déplacement (px) qui fait d'un
-- appui un glisser ; appui immobile du doigt (s) qui le fait aussi ; défilement de la liste (px) qui
-- fait d'un appui un défilement ; durée (s) pendant laquelle le clic qui termine un glisser est ignoré ;
-- transparence de la copie qui suit le pointeur ; ordre d'affichage de l'écran HotbarDrag (au-dessus de
-- tout) ; regroupement des envois (s) ; attente de l'attribut HotbarLayout après l'inventaire (s).
local DRAG_PIXELS = 8
local HOLD_TIME = 0.3
local SCROLL_PIXELS = 3
local SUPPRESS_TIME = 0.25
local GHOST_TRANSPARENCY = 0.35
local DRAG_LAYER = "HotbarDrag"
local DRAG_GHOST = "DragGhost"
local DRAG_ORDER = 100
local SEND_DELAY = 0.5
local LAYOUT_WAIT = 5

local PRESS_INFO = TweenInfo.new(UiMotion.Release.Time, UiMotion.Release.Style, UiMotion.Release.Direction)
local SUCCESS_INFO = TweenInfo.new(UiMotion.Success.Time, UiMotion.Success.Style, UiMotion.Success.Direction)

local IS_STUDIO = RunService:IsStudio()

local HotbarController = {}

local localPlayer = Players.LocalPlayer
local inventory: InventoryApi? = nil
local chase: ChaseApi? = nil
local notify: NotifyApi? = nil
local net: any = nil
local screen: Screen? = nil
local slots: { Slot } = {}
local rankViews: { [number]: View } = {}
local count = DEFAULT_SLOTS
local phone = false
local refreshQueued = false
local layout: { string } = HotbarLayout.Default()
local ready = false -- disposition chargée (sauvegardée ou de départ)
local inventorySeenAt: number? = nil -- os.clock() du premier état d'inventaire lu
local waitQueued = false
local known: { [string]: boolean } = {} -- identifiants déjà vus dans l'inventaire (pas « nouveaux »)
local stock: { [string]: Slot } = {} -- ce qui peut aller dans la barre, par identifiant
local lastSent: string? = nil -- dernière disposition connue du serveur (texte HotbarLayout)
local sendQueued = false
local press: Press? = nil
local dragEndedAt = -math.huge
local dragLayer: ScreenGui? = nil
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

-- Le point (pixels, repère d'InputObject.Position et d'AbsolutePosition) est-il dans l'objet ?
local function contains(object: Instance?, point: Vector2): boolean
	if object == nil or not object:IsA("GuiObject") then
		return false
	end
	local gui = object :: GuiObject
	local origin = gui.AbsolutePosition
	local size = gui.AbsoluteSize
	return point.X >= origin.X and point.X <= origin.X + size.X and point.Y >= origin.Y and point.Y <= origin.Y + size.Y
end

------------------------------------------------------------------------------
-- Ce qui peut aller dans la barre
------------------------------------------------------------------------------

local function isPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Nombre de cases montrées : attribut de Bar (SlotCount, ou TouchSlotCount sur téléphone), de 1 à
-- HotbarLayout.Size.
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

local function emptySlot(rank: number): Slot
	return {
		key = "Empty_" .. rank,
		id = HotbarLayout.Empty,
		kind = "Empty",
		uid = nil,
		name = "",
		icon = nil,
		rarity = nil,
		income = nil,
		equipped = false,
	}
end

-- Ce qui peut aller dans la barre (outil, batte, colis pas posés, objets pas exposés), par identifiant,
-- et l'ordre de la disposition de départ et des arrivées : colis du plus récent au plus ancien, puis
-- objets (ordre d'InventoryService).
local function readStock(api: InventoryApi): ({ [string]: Slot }, { Slot }, boolean)
	local tools = api.GetTools()
	local held = tools.Held
	local inventoryState = api.GetState()
	local placing = inventoryState.Placing
	local placingUid: string? = if type(placing) == "string" then placing else nil
	local name, id = toolName(tools.Breaking)
	local found: { [string]: Slot } = {
		[HotbarLayout.Tool] = {
			key = "Tool",
			id = HotbarLayout.Tool,
			kind = "Tool",
			uid = nil,
			name = name,
			icon = TOOL_ICON_PREFIX .. id,
			rarity = nil,
			income = nil,
			equipped = held ~= nil and held:GetAttribute(TOOL_ID_ATTRIBUTE) ~= nil,
		},
		[HotbarLayout.Bat] = {
			key = "Bat",
			id = HotbarLayout.Bat,
			kind = "Bat",
			uid = nil,
			name = Bat.DisplayName,
			icon = BAT_ICON,
			rarity = nil,
			income = nil,
			equipped = held ~= nil and held:GetAttribute(BAT_ATTRIBUTE) == true,
		},
	}
	local order: { Slot } = {}
	local current = api.GetInventory()
	for _, box in current.Boxes do
		if not box.Placed then
			local slot: Slot = {
				key = "Box_" .. box.Uid,
				id = box.Uid,
				kind = "Box",
				uid = box.Uid,
				name = string.format(BOX_NAME, box.Tier),
				-- ICON_BOX_<Rareté> (a79, L-097 point 3), sinon ICON_BOX_<Tier>
				icon = if textureOf(BOX_ICON_PREFIX .. box.Rarity) then BOX_ICON_PREFIX .. box.Rarity else BOX_ICON_PREFIX .. box.Tier,
				rarity = box.Rarity,
				income = nil,
				equipped = placingUid == box.Uid,
			}
			found[box.Uid] = slot
			table.insert(order, 1, slot) -- InventoryService : le plus ancien d'abord ; ici le plus récent d'abord
		end
	end
	for _, item in current.Items do
		local def = Items.ById[item.ItemId]
		if item.Slot == nil and def ~= nil then
			local rarity: string = def.Rarity
			local income: number = item.Income
			local slot: Slot = {
				key = "Item_" .. item.Uid,
				id = item.Uid,
				kind = "Item",
				uid = item.Uid,
				name = def.DisplayName,
				icon = def.Id,
				rarity = rarity,
				income = income,
				equipped = false,
			}
			found[item.Uid] = slot
			table.insert(order, slot)
		end
	end
	return found, order, inventoryState.Loaded == true
end

------------------------------------------------------------------------------
-- Disposition : chargement, cases vidées, arrivées, sauvegarde
------------------------------------------------------------------------------

local function indexOf(id: string): number?
	for index, value in layout do
		if value == id then
			return index
		end
	end
	return nil
end

-- Première case vide montrée (1 à count), nil s'il n'y en a pas.
local function firstEmpty(): number?
	for index = 1, count do
		if layout[index] == HotbarLayout.Empty then
			return index
		end
	end
	return nil
end

local function sendNow()
	sendQueued = false
	if not ready then
		return
	end
	local text = HotbarLayout.Encode(layout)
	if text == lastSent then
		return
	end
	local client = if net then net.Client else nil
	if client == nil then
		return -- remotes pas prêts : renvoyé au prochain changement
	end
	local list = HotbarLayout.Decode(text) or layout
	lastSent = text
	client.SetHotbar:Fire(table.unpack(list, 1, HotbarLayout.Size))
end

local function queueSend()
	if sendQueued then
		return
	end
	sendQueued = true
	task.delay(SEND_DELAY, sendNow)
end

local queueRefresh: () -> ()

-- Met la disposition d'accord avec l'inventaire (voir l'en-tête).
local function syncLayout(order: { Slot }, loaded: boolean)
	if not loaded then
		return -- profil pas encore chargé : outil et batte seulement
	end
	if not ready then
		local saved = localPlayer:GetAttribute(HotbarLayout.Attribute)
		if saved == nil then
			local now = os.clock()
			local seenAt = inventorySeenAt or now
			inventorySeenAt = seenAt
			if now - seenAt < LAYOUT_WAIT then
				if not waitQueued then
					waitQueued = true
					task.delay(LAYOUT_WAIT, function()
						waitQueued = false
						queueRefresh()
					end)
				end
				return
			end
			reportOnce("layoutMissing", `[Hotbar] attribut {HotbarLayout.Attribute} absent : disposition de départ`)
		end
		ready = true
		lastSent = if type(saved) == "string" then saved else nil
		local decoded = HotbarLayout.Decode(saved)
		if decoded then
			layout = decoded
		else
			layout = HotbarLayout.Default()
			for _, slot in order do
				local index = firstEmpty()
				if index == nil then
					break
				end
				layout[index] = slot.id
			end
		end
		for id in stock do
			known[id] = true -- déjà là au chargement : pas « nouveau »
		end
	end
	-- Parti : case vide, rien ne bouge.
	for index, id in layout do
		if id ~= HotbarLayout.Empty and stock[id] == nil then
			layout[index] = HotbarLayout.Empty
		end
	end
	-- Nouveau : première case vide montrée, sinon seulement dans l'inventaire.
	for _, slot in order do
		if not known[slot.id] then
			known[slot.id] = true
			if indexOf(slot.id) == nil then
				local index = firstEmpty()
				if index then
					layout[index] = slot.id
				end
			end
		end
	end
	for id in known do
		if stock[id] == nil then
			known[id] = nil -- parti : s'il revient (objet retiré d'un présentoir), il compte comme nouveau
		end
	end
	if HotbarLayout.Encode(layout) ~= lastSent then
		queueSend()
	end
end

local function buildSlots(api: InventoryApi): { Slot }
	local found, order, loaded = readStock(api)
	stock = found
	syncLayout(order, loaded)
	local list: { Slot } = {}
	for rank = 1, count do
		local id = layout[rank]
		local slot = if id ~= nil and id ~= HotbarLayout.Empty then stock[id] else nil
		table.insert(list, slot or emptySlot(rank))
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

-- Le clic qui termine un glisser (ou qui arrive pendant) ne compte pas.
local function suppressed(): boolean
	local current = press
	return (current ~= nil and current.dragging) or os.clock() - dragEndedAt < SUPPRESS_TIME
end

------------------------------------------------------------------------------
-- Glisser-déposer
------------------------------------------------------------------------------

local function layer(): ScreenGui?
	local existing = dragLayer
	if existing and existing.Parent ~= nil then
		return existing
	end
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = DRAG_LAYER
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false -- même repère qu'InputObject.Position
	gui.DisplayOrder = DRAG_ORDER
	gui.Parent = playerGui
	dragLayer = gui
	return gui
end

-- Case montrée sous le point, nil s'il n'y en a pas.
local function slotAt(point: Vector2): number?
	for rank = 1, count do
		local view = rankViews[rank]
		if view and view.frame.Parent ~= nil and contains(view.frame, point) then
			return rank
		end
	end
	return nil
end

local function outlineOf(rank: number?): Instance?
	local view = if rank then rankViews[rank] else nil
	return if view then view.refs.HoverOutline else nil
end

local function setTarget(current: Press, rank: number?)
	if current.target == rank then
		return
	end
	setVisible(outlineOf(current.target), false)
	current.target = rank
	setVisible(outlineOf(rank), true)
end

local function placeGhost(current: Press)
	local ghost = current.ghost
	if ghost then
		ghost.Position = UDim2.fromOffset(current.position.X, current.position.Y)
	end
end

local function makeGhost(current: Press): GuiObject?
	local parent = layer()
	if parent == nil then
		return nil
	end
	local size = current.frame.AbsoluteSize
	local holder = Instance.new("CanvasGroup")
	holder.Name = DRAG_GHOST
	holder.BackgroundTransparency = 1
	holder.GroupTransparency = GHOST_TRANSPARENCY
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.Active = false
	pcall(function()
		(holder :: any).Interactable = false -- ne prend ni survol ni clic
	end)
	local copy: Instance? = current.frame:Clone()
	if copy and copy:IsA("GuiObject") then
		local gui = copy :: GuiObject
		gui.Name = "Copy"
		gui.AnchorPoint = Vector2.new(0, 0)
		gui.Position = UDim2.fromScale(0, 0)
		gui.Size = UDim2.fromScale(1, 1)
		gui.Visible = true
		gui.Parent = holder
	end
	holder.Parent = parent
	return holder
end

local function scrolled(current: Press): boolean
	local list = current.list
	local canvas = current.canvas
	if list == nil or canvas == nil then
		return false
	end
	return (list.CanvasPosition - canvas).Magnitude > SCROLL_PIXELS
end

local function endPress(current: Press)
	if press ~= current then
		return
	end
	press = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	setTarget(current, nil)
	local ghost = current.ghost
	current.ghost = nil
	if ghost then
		ghost:Destroy()
	end
	local list = current.list
	if list and current.scrolling ~= nil then
		list.ScrollingEnabled = current.scrolling :: boolean
	end
end

local function startDrag(current: Press)
	if current.dragging then
		return
	end
	current.dragging = true
	local list = current.list
	if list then
		current.scrolling = list.ScrollingEnabled
		list.ScrollingEnabled = false -- le doigt glisse la carte, pas la liste
	end
	current.ghost = makeGhost(current)
	placeGhost(current)
	setTarget(current, slotAt(current.position))
end

local function move(current: Press, point: Vector2)
	current.position = point
	if not current.dragging then
		if scrolled(current) then
			endPress(current) -- la liste défile : ce n'est pas un glisser
			return
		end
		if (point - current.start).Magnitude < DRAG_PIXELS then
			return
		end
		startDrag(current)
		return
	end
	placeGhost(current)
	setTarget(current, slotAt(point))
end

-- Lâché en `point` : la disposition change (voir l'en-tête).
local function drop(current: Press, point: Vector2)
	local target = slotAt(point)
	local id = current.id
	local changed = false
	if current.source == "Card" then
		if target and stock[id] ~= nil and layout[target] ~= id then
			local old = indexOf(id)
			if old then
				layout[old] = HotbarLayout.Empty
			end
			layout[target] = id -- l'ancienne chose retourne seulement dans l'inventaire
			changed = true
		end
	else
		local from = current.from
		if from == nil or layout[from] ~= id then
			return -- la case a changé pendant le glisser
		end
		if target then
			if target ~= from then
				layout[from], layout[target] = layout[target], layout[from]
				changed = true
			end
		else
			local bar = if screen then screen.bar else nil
			if not contains(bar, point) then
				layout[from] = HotbarLayout.Empty
				changed = true
			end
		end
	end
	if changed then
		queueRefresh()
		queueSend()
	end
end

local function finish(current: Press, point: Vector2?)
	if press ~= current then
		return
	end
	if current.dragging then
		local at = point or current.position
		current.position = at
		dragEndedAt = os.clock()
		local ok, message: any = pcall(drop, current, at)
		if not ok then
			reportOnce("drop", `[Hotbar] lâcher : {message}`)
		end
	end
	endPress(current)
end

local function pointOf(input: InputObject): Vector2
	local position = input.Position
	return Vector2.new(position.X, position.Y)
end

-- Appui (clic gauche ou doigt) sur une carte ou une case : un glisser s'il bouge (voir l'en-tête).
local function beginPress(source: string, id: string, from: number?, frame: GuiObject, input: InputObject, list: Instance?)
	local old = press
	if old then
		endPress(old) -- fin jamais reçue (fenêtre quittée…) : l'ancien appui est abandonné, sans lâcher
	end
	if not ready or screen == nil or id == HotbarLayout.Empty then
		return
	end
	local inputType = input.UserInputType
	local touch = inputType == Enum.UserInputType.Touch
	if not touch and inputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local scroller: ScrollingFrame? = if list and list:IsA("ScrollingFrame") then list :: ScrollingFrame else nil
	local start = pointOf(input)
	local current: Press = {
		source = source,
		id = id,
		from = from,
		frame = frame,
		input = input,
		touch = touch,
		start = start,
		position = start,
		list = scroller,
		canvas = if scroller then scroller.CanvasPosition else nil,
		scrolling = nil,
		dragging = false,
		ghost = nil,
		target = nil,
		connections = {},
	}
	press = current
	table.insert(
		current.connections,
		UserInputService.InputChanged:Connect(function(changed: InputObject)
			if press ~= current then
				return
			end
			local changedType = changed.UserInputType
			if (touch and changed == current.input) or (not touch and changedType == Enum.UserInputType.MouseMovement) then
				move(current, pointOf(changed))
			end
		end)
	)
	table.insert(
		current.connections,
		UserInputService.InputEnded:Connect(function(ended: InputObject)
			if press ~= current then
				return
			end
			local endedType = ended.UserInputType
			if (touch and ended == current.input) or (not touch and endedType == Enum.UserInputType.MouseButton1) then
				finish(current, pointOf(ended))
			end
		end)
	)
	if touch then
		task.delay(HOLD_TIME, function()
			if press == current and not current.dragging and not scrolled(current) then
				startDrag(current) -- doigt posé sans bouger : on prend la carte
			end
		end)
	end
end

-- Appui sur une carte de UI_Inventory (InventoryController.SetCardDrag) : son identifiant de disposition.
local function cardId(key: string): string?
	if key == CARD_BAT then
		return HotbarLayout.Bat
	elseif string.sub(key, 1, #CARD_TOOL) == CARD_TOOL then
		return HotbarLayout.Tool -- n'importe quel outil de casse : la case de l'outil de casse
	end
	local uid: string? = nil
	if string.sub(key, 1, #CARD_BOX) == CARD_BOX then
		uid = string.sub(key, #CARD_BOX + 1)
	elseif string.sub(key, 1, #CARD_ITEM) == CARD_ITEM then
		uid = string.sub(key, #CARD_ITEM + 1)
	end
	if uid and stock[uid] ~= nil then
		return uid -- pas un objet exposé ni un colis posé
	end
	return nil
end

local function onCardPress(key: string, frame: GuiObject, input: InputObject, list: Instance?)
	local id = cardId(key)
	if id then
		beginPress("Card", id, nil, frame, input, list)
	end
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
	local view: View = { frame = frame, refs = refs, slot = slot, rank = 0, connections = {} }
	table.insert(
		view.connections,
		frame.Activated:Connect(function()
			if not suppressed() then
				use(view.slot)
			end
		end)
	)
	-- Appui (T.31) et relâché (T.32) en un sursaut : × Press.To, puis retour à 1 (Back Out).
	local function pressed()
		Motion.Pop(frame, UiMotion.Press.To, PRESS_INFO)
	end
	table.insert(view.connections, frame.MouseButton1Down:Connect(pressed))
	table.insert(
		view.connections,
		frame.InputBegan:Connect(function(input: InputObject)
			local inputType = input.UserInputType
			if inputType == Enum.UserInputType.Touch then
				pressed()
			end
			if inputType == Enum.UserInputType.Touch or inputType == Enum.UserInputType.MouseButton1 then
				-- Glisser de case en case.
				local ok, message: any = pcall(beginPress, "Slot", view.slot.id, view.rank, frame, input, nil)
				if not ok then
					reportOnce("slotPress", `[Hotbar] appui sur une case : {message}`)
				end
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
	view.rank = rank
	local refs = view.refs
	view.frame.LayoutOrder = rank
	setText(refs.KeyLabel, tostring(rank))
	setVisible(refs.KeyLabel, not phone)
	setText(refs.ItemName, slot.name)
	local icon = slot.icon
	local texture = if icon then textureOf(icon) else nil
	if texture then
		setImage(refs.Icon, texture)
	elseif slot.kind == "Item" or slot.kind == "Empty" then
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
	table.clear(rankViews)
	if current == nil then
		return
	end
	local seen: { [string]: boolean } = {}
	for rank, slot in slots do
		local view = current.views[slot.key] or newView(current, slot)
		if view then
			current.views[slot.key] = view
			paint(current, view, slot, rank)
			rankViews[rank] = view
			seen[slot.key] = true
		end
	end
	for key, view in current.views do
		if not seen[key] then
			destroyView(view)
			current.views[key] = nil
		end
	end
	local held = press
	if held and held.dragging then
		setVisible(outlineOf(held.target), true) -- case visée recréée
	end
end

queueRefresh = function()
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

-- Écrans plein écran de Clément devant lesquels la barre se cache (vague 27, vu en Play le 2026-11-11 : même
-- DisplayOrder que UI_SkillTree, ses cases prenaient le clic du bouton Close de l'arbre).
local FULL_SCREENS = { "UI_SkillTree" }

local function fullScreenOpen(): boolean
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return false
	end
	for _, name in FULL_SCREENS do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") and (gui :: ScreenGui).Enabled then
			return true
		end
	end
	return false
end

-- Enabled = branché, pas en poursuite (jamais rallumé pendant une poursuite : ChaseFeelController) et pas
-- sous un écran plein (FULL_SCREENS).
local function updateEnabled()
	local current = screen
	if current == nil or current.gui.Parent == nil then
		return
	end
	local wanted = not isChased() and not fullScreenOpen()
	if current.gui.Enabled ~= wanted then
		current.gui.Enabled = wanted
	end
end

local function unbind()
	local current = screen
	if current == nil then
		return
	end
	local held = press
	if held then
		endPress(held)
	end
	screen = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	for _, view in current.views do
		destroyView(view)
	end
	table.clear(rankViews)
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
			Id = slot.id,
			Uid = slot.uid,
			Name = slot.name,
			Income = slot.income,
			Equipped = slot.equipped,
		})
	end
	local held = press
	return {
		Bound = current ~= nil,
		Enabled = current ~= nil and current.gui.Enabled,
		Count = count,
		Phone = phone,
		Ready = ready,
		Dragging = held ~= nil and held.dragging,
		Layout = table.clone(layout),
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
	api.SetCardDrag({ Press = onCardPress, Suppress = suppressed }) -- glisser une carte de UI_Inventory (vague 25)
	localPlayer:GetAttributeChangedSignal(HotbarLayout.Attribute):Connect(queueRefresh)
	localPlayer:GetAttributeChangedSignal(InventoryState.Attribute):Connect(queueRefresh)
	task.spawn(function()
		-- Peut attendre que le serveur ait créé les remotes ; la disposition est envoyée ensuite.
		net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
		if ready and HotbarLayout.Encode(layout) ~= lastSent then
			queueSend()
		end
	end)

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
