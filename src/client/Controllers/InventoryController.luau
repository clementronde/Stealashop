--!strict
-- InventoryController (L-079, L-089 points 2 et 3, L-091 point 6 ; client) : l'écran d'inventaire
-- UI_Inventory de Clément, qui remplace toute la barre d'outils de Roblox (décision de Clément du
-- 2026-11-10, L-079 : outil et batte compris, on les équipe depuis l'écran).
--
-- Rôle :
--   - barre Roblox coupée (StarterGui:SetCoreGuiEnabled(Backpack, false)) : plus aucun Tool montré en
--     bas de l'écran. L'outil de casse et la batte de ToolService restent des Tools, dans le Backpack ou
--     en main. Touches (comme les slots de l'ancienne barre, Balance.Hotbar) : 1 met l'outil de casse en
--     main ou le range, 2 la batte. Rien pendant un portage (attribut Carrying, CarryService) ;
--   - UI_HUD.InventoryButton ouvre l'écran (un 2e appui le ferme), CloseButton le ferme. Ouverture et
--     fermeture animées par UI/Motion (groupe ScreenGroup de l'écran, Motion.SetCloser) ; les cartes sont
--     retirées une fois l'écran éteint ;
--   - onglets Tabs.ItemsTab, BoxesTab, ToolsTab, PotionsTab : l'image Selected sur l'onglet choisi, sa
--     section (ItemsSection…) seule visible dans List. À la première ouverture, Items ; ensuite, le
--     dernier choisi. ScrollTrack suit la liste (même règle que l'Index v2, IndexController) ;
--   - état lu dans l'attribut InventoryState du Player (InventoryService, texte de Shared/InventoryState),
--     OwnedTools (ShopService), DisplaySlotsUnlocked (DisplayService) ; l'écran ouvert suit chaque
--     changement. Une carte par élément, clonée du Template de sa section dans son Cards, nommée
--     Item_<uid>, Box_<uid> ou Tool_<Id> (Tool_Bat pour la batte), LayoutOrder = rang :
--       Items  (les plus rentables d'abord) Icon = ICON_<ItemId> (Contract/Icons ; pas livrée : vide),
--              ItemName, RarityBar.Rarity, Rays et Glow à la couleur de la rareté, MutationTag caché sans
--              mutation (MutationLabel « BIG · GOLD »), Income (« +$12K/s », mutation comprise, sans les
--              bonus du joueur), DisplayedBadge sur un objet exposé. PlaceButton (objet de l'inventaire) →
--              PlaceItemAuto(uid) : le serveur le pose sur le présentoir libre le plus proche, sinon le
--              premier libre ; UnequipButton (objet exposé) → UnplaceItem(uid) : il revient dans
--              l'inventaire ;
--       Boxes  (ceux de l'inventaire, puis ceux posés au sol) Icon = ICON_BOX_<Tier> (pas livrée : l'image
--              du Template), BoxName « PREMIUM BOX », RarityBar.Rarity, Rays et Glow à la couleur de la
--              rareté. Dans l'inventaire : PlaceButton → mode pose (plus bas). Posé : PlacedPill
--              (« ON FLOOR »), puis TimerPill/TimerLabel (« 0:42 », heure serveur) pendant l'attente, puis
--              ReadyPill quand il est prêt ;
--       Tools  outils possédés (Config/Tools, dans leur ordre), puis la batte : Icon = ICON_TOOL_<Id>
--              (ICON_TOOL_Bat pour la batte ; pas livrée : l'image du Template), ToolName, ToolStat
--              (« Power 20 » ; batte : « Stun 2s »). EquippedPill sur l'outil tenu en main, EquipButton sur
--              les autres : il met l'outil en main ; un outil possédé qui n'est pas l'outil de casse donné
--              passe d'abord par EquipTool(id) (ShopService, qui remplace le Tool), puis va en main dès
--              qu'il arrive. Un clic sur la carte de l'outil tenu le range ;
--       Potions  pas de potions dans le jeu : section vide, CountLabel « 0 ».
--     Un clic sur une carte fait ce que montre son bouton. HoverOutline est montré au survol ;
--   - Counter « 9 / 30 items » (objets non exposés / Balance.Display.InventoryMax), Displays
--     « 4 / 6 displays » (objets exposés / présentoirs débloqués), SectionCount.CountLabel de chaque
--     section = son nombre de cartes ; EquipBestButton → EquipBest ;
--   - mode pose d'un colis (PlaceButton d'un colis de l'inventaire, sans Tool en main) : l'écran se
--     ferme, l'outil tenu est rangé, un aperçu fantôme (une pièce translucide de la taille d'un colis
--     posé, Config.Unbox.BoxFootprint, tournée comme la parcelle) suit le point visé sous le curseur ou
--     le doigt : vert si la pose a des chances de passer (dans le volume Bounds de SA boutique, sol assez
--     plat au niveau du bas de Bounds, à portée), rouge sinon. Un clic ou un appui sur le monde envoie
--     PlaceBox(boxUid, point visé) et joue Place (contrat 2.4) ; le serveur revérifie tout et répond par
--     un Notify en cas de refus (le mode reste, pour réessayer). Fin du mode : colis posé (il quitte
--     l'inventaire), touche Q (V0), écran rouvert, outil pris (1, 2, écran), portage, mort.
-- Rien de ce qui compte ne se décide ici : chaque bouton envoie un uid ou un Id que le serveur revérifie.
-- Seuls sont touchés (2.2, « Libre pour Ironix ») : Enabled de l'écran, les textes, la visibilité, les
-- cartes clonées (nom, ordre), l'image de leur icône et la teinte (ImageColor3) de leurs rayons, le
-- défilement de la liste, la position et la hauteur de ScrollTrack ; jamais un style de Clément. Écran
-- recréé (ResetOnSpawn) : rebranché, fermé.
--
-- API (client) :
--   InventoryController.Open() / Close() / Toggle()
--   InventoryController.SelectTab(name)        "Items", "Boxes", "Tools" ou "Potions"
--   InventoryController.StartPlacing(boxUid)   mode pose de ce colis (barre de commande, bancs)
--   InventoryController.EquipBest()            demande au serveur de poser ses meilleurs objets
--   InventoryController.GetState() -> { Open, Tab, Placing, Aim, AimValid, Items, Boxes, Tools }

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Bat = require(Config:WaitForChild("Bat"))
local Items = require(Config:WaitForChild("Items"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Tools = require(Config:WaitForChild("Tools"))
local Unbox = require(Config:WaitForChild("Unbox"))
local Format = require(Shared:WaitForChild("Format"))
local InventoryState = require(Shared:WaitForChild("InventoryState"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local Icons = require(Contract:WaitForChild("Icons"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
}

-- "Items", "Boxes", "Tools" ou "Potions" (TAB_ORDER ; une chaîne : l'ancien solveur suit mal les unions de
-- chaînes fixes).
type TabName = string

-- Ce qu'une carte fait au clic, selon ce qu'elle montre (remis à chaque peinture).
type Handlers = {
	Card: (() -> ())?,
	PlaceButton: (() -> ())?,
	UnequipButton: (() -> ())?,
	EquipButton: (() -> ())?,
}

-- Une carte clonée.
type CardView = {
	frame: GuiObject,
	refs: { [string]: Instance? }, -- éléments de la carte, par chemin (CARD_PARTS)
	handlers: Handlers,
	connections: { RBXScriptConnection },
}

-- Une section de List et son onglet.
type Section = {
	tab: TabName,
	frame: GuiObject?,
	cards: Instance?, -- cadre Cards (UIGridLayout de Clément)
	template: GuiObject?,
	count: Instance?, -- SectionCount.CountLabel
	button: Instance?, -- Tabs.<Nom>Tab
	selected: GuiObject?,
	views: { [string]: CardView },
}

-- Écran branché.
type Screen = {
	gui: ScreenGui,
	list: Instance?,
	track: GuiObject?,
	trackPosition: UDim2, -- place et taille posées par Clément : la piste du curseur
	trackSize: UDim2,
	counter: Instance?,
	displays: Instance?,
	sections: { [TabName]: Section },
	connections: { RBXScriptConnection },
}

-- Une carte d'outil (outil de casse possédé, ou la batte).
type ToolCard = {
	key: string,
	toolId: string?, -- nil pour la batte
	name: string,
	stat: string,
	icon: string, -- nom passé à Icons.get (« TOOL_Hammer »)
}

-- Mode pose d'un colis.
type Placing = {
	uid: string,
	connections: { RBXScriptConnection },
}

-- Contrat 2.2 (tableau UI_Inventory).
local SCREEN = "UI_Inventory"
local HUD = "UI_HUD"
local HUD_BUTTON = "InventoryButton"
local TAB_ORDER: { TabName } = { "Items", "Boxes", "Tools", "Potions" }
local CARD_PARTS: { [TabName]: { string } } = {
	Items = { "Icon", "ItemName", "RarityBar.Rarity", "Rays", "Glow", "MutationTag", "MutationTag.MutationLabel", "Income", "DisplayedBadge", "PlaceButton", "UnequipButton", "HoverOutline" },
	Boxes = { "Icon", "BoxName", "RarityBar.Rarity", "Rays", "Glow", "PlaceButton", "PlacedPill", "ReadyPill", "TimerPill", "TimerPill.TimerLabel", "HoverOutline" },
	Tools = { "Icon", "ToolName", "ToolStat", "Rays", "Glow", "EquipButton", "EquippedPill", "HoverOutline" },
	Potions = {},
}
local CARD_BUTTONS = { "PlaceButton", "UnequipButton", "EquipButton" }
local PREVIEW_PREFIX = "Preview_"
local BOX_ICON_PREFIX = "BOX_" -- Icons.name("BOX_Premium") = « ICON_BOX_Premium » (L-089)
local TOOL_ICON_PREFIX = "TOOL_" -- « ICON_TOOL_Hammer » (L-090)
local BAT_KEY = "Bat" -- carte Tool_Bat, icône ICON_TOOL_Bat (nom proposé à Clément)

-- Attributs posés par les services serveur (lus sans require).
local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService
local OWNED_ATTRIBUTE = "OwnedTools" -- ShopService : « Fists,Wrench »
local SLOTS_ATTRIBUTE = "DisplaySlotsUnlocked" -- DisplayService
local CARRYING_ATTRIBUTE = "Carrying" -- CarryService
local TOOL_ID_ATTRIBUTE = "ToolId" -- ToolService : l'outil de casse
local BAT_ATTRIBUTE = "BatTool" -- ToolService : la batte
local BOUNDS = "Bounds"
local GHOST_NAME = "BoxGhost"

-- Textes, en anglais (L-036). V0 proposés, absents du doc, sur les exemples de la maquette de Clément
-- (« 9 / 30 items », « 4 / 6 displays », « PREMIUM BOX », « Power 20 », « 0:42 ») ; la batte n'a pas de
-- puissance : sa carte dit son étourdissement (Config/Bat).
local COUNTER_TEXT = "%d / %d items"
local DISPLAYS_TEXT = "%d / %d displays"
local BOX_NAME = "%s BOX"
local TOOL_STAT = "Power %s"
local BAT_STAT = "Stun %ss"
local TIMER_TEXT = "%d:%02d"

-- Touches des anciens slots de la barre (1 à 9).
local SLOT_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
local TOOL_KEY = SLOT_KEYS[Balance.Hotbar.ToolSlot]
local BAT_KEY_CODE = SLOT_KEYS[Balance.Hotbar.BatSlot]
-- V0 proposés, absents du doc : touche qui quitte le mode pose ; attente (s) de l'outil demandé à
-- EquipTool avant de renoncer à le mettre en main ; cadence (s) des minuteurs des colis ; garde (s)
-- contre un double envoi du même bouton ; hauteur minimale du curseur ScrollTrack (part de sa piste,
-- comme l'Index v2).
local CANCEL_KEY = Enum.KeyCode.Q
local PENDING_TOOL_TIME = 3
local TICK = 0.25
local SEND_GUARD = 0.5
local TRACK_MIN_SHARE = 0.1
-- Aperçu du colis (couleurs de la planche 10.6 ; portée acceptée par le serveur, PlaceBox).
local REACH = Unbox.PromptDistance + Unbox.ReachTolerance
local AIM_DISTANCE = 200 -- studs : longueur du rayon de visée (V0)
local GHOST_TRANSPARENCY = 0.6 -- V0
local GHOST_OK = Color3.fromHex("#35C93B") -- vert « acheter / OK », planche 10.6
local GHOST_BAD = Color3.fromHex("#E8413C") -- rouge « fermer », planche 10.6

local IS_STUDIO = RunService:IsStudio()

local InventoryController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local animation: AnimationApi? = nil
local screen: Screen? = nil
local isOpen = false
local tab: TabName = "Items"
local state: InventoryState.State = { Items = {}, Boxes = {} }
local plot: Model? = nil
local watchedPlots: { [Instance]: RBXScriptConnection } = {}
local placing: Placing? = nil
local ghost: BasePart? = nil
local lastAim: Vector3? = nil
local lastAimValid = false
local pendingTool: string? = nil
local pendingToolUntil = 0
local sentAt: { [string]: number } = {}
local tickToken = 0
local textures: { [string]: string } = {}
local missingIcons: { [string]: boolean } = {}
local preloaded: { [string]: boolean } = {} -- textures déjà téléchargées (Icons.preload)
local reported: { [string]: boolean } = {}
local characterConnections: { RBXScriptConnection } = {}
local backpackConnection: RBXScriptConnection? = nil

-- Une ligne de sortie par sujet, en Studio seulement.
local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

local function loadAnimationController(): AnimationApi?
	local folder = script.Parent
	local module = if folder then folder:FindFirstChild("AnimationController") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" then
		return result :: any
	end
	return nil
end

local function playAnimation(name: string)
	local anim = animation
	if anim then
		pcall(anim.PlayPlayer, name)
	end
end

------------------------------------------------------------------------------
-- Outils d'écran
------------------------------------------------------------------------------

local function isImage(inst: Instance?): boolean
	return inst ~= nil and (inst:IsA("ImageLabel") or inst:IsA("ImageButton"))
end

local function guiObject(root: Instance?, path: string): GuiObject?
	if root == nil then
		return nil
	end
	local found = Find.path(root, path)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

-- Texte affiché d'un élément : le sien (TextLabel, TextButton, TextBox), sinon celui de son premier
-- TextLabel.
local function textHolder(element: Instance?): Instance?
	if element == nil then
		return nil
	end
	if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
		return element
	end
	return element:FindFirstChildWhichIsA("TextLabel", true)
end

local function setText(element: Instance?, text: string)
	local holder = textHolder(element)
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

local function tint(element: Instance?, color: Color3)
	if isImage(element) then
		(element :: any).ImageColor3 = color
	end
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

local function hover(element: Instance?)
	if element and element:IsA("GuiButton") then
		Motion.Hover(element :: GuiButton)
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
		reportOnce(`icon:{name}`, `[Inventory] icône {Icons.name(name)} pas livrée : carte sans cette image`)
	end
	return texture
end

-- Un bouton n'envoie pas deux fois la même demande en SEND_GUARD s.
local function canSend(key: string): boolean
	local now = os.clock()
	if (sentAt[key] or -math.huge) + SEND_GUARD > now then
		return false
	end
	sentAt[key] = now
	return true
end

------------------------------------------------------------------------------
-- Personnage, outils en main
------------------------------------------------------------------------------

local function isCarrying(): boolean
	return localPlayer:GetAttribute(CARRYING_ATTRIBUTE) ~= nil
end

local function humanoidOf(): Humanoid?
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function isBreakingTool(inst: Instance): boolean
	return inst:IsA("Tool") and inst:GetAttribute(TOOL_ID_ATTRIBUTE) ~= nil
end

local function isBatTool(inst: Instance): boolean
	return inst:IsA("Tool") and inst:GetAttribute(BAT_ATTRIBUTE) == true
end

-- Premier Tool qui répond à `test`, en main d'abord, puis dans le Backpack.
local function findTool(test: (Instance) -> boolean): Tool?
	for _, container in { localPlayer.Character, localPlayer:FindFirstChildOfClass("Backpack") } :: { Instance? } do
		if container then
			for _, child in container:GetChildren() do
				if test(child) then
					return child :: Tool
				end
			end
		end
	end
	return nil
end

local function isHeld(tool: Tool?): boolean
	local character = localPlayer.Character
	return tool ~= nil and character ~= nil and tool.Parent == character
end

local stopPlacing: () -> ()

local function equip(tool: Tool)
	local humanoid = humanoidOf()
	if humanoid == nil or isCarrying() then
		return
	end
	stopPlacing()
	humanoid:EquipTool(tool)
end

local function unequip()
	local humanoid = humanoidOf()
	if humanoid then
		humanoid:UnequipTools()
	end
end

-- Touche 1 ou 2 : en main, ou rangé s'il y était.
local function toggleTool(test: (Instance) -> boolean)
	local tool = findTool(test)
	if tool == nil then
		return
	end
	if isHeld(tool) then
		unequip()
	else
		equip(tool)
	end
end

-- Carte d'outil : l'outil de casse donné va en main (ou se range s'il y est) ; un autre outil possédé est
-- d'abord équipé par le serveur (EquipTool), puis mis en main à son arrivée.
local function useToolCard(card: ToolCard)
	if not canSend("ToolCard:" .. card.key) then
		return -- un double clic (ou le bouton et sa carte) ne met pas l'outil en main pour le ranger aussitôt
	end
	if card.toolId == nil then
		toggleTool(isBatTool)
		return
	end
	local current = findTool(isBreakingTool)
	if current and current:GetAttribute(TOOL_ID_ATTRIBUTE) == card.toolId then
		toggleTool(isBreakingTool)
		return
	end
	if net == nil or isCarrying() or not canSend("EquipTool:" .. card.key) then
		return
	end
	pendingTool = card.toolId
	pendingToolUntil = os.clock() + PENDING_TOOL_TIME
	net.Client.EquipTool:Fire(card.toolId)
end

-- Un Tool arrive dans le Backpack : l'outil demandé par la carte va en main.
local function onBackpackChild(child: Instance)
	local wanted = pendingTool
	if wanted == nil or not isBreakingTool(child) or child:GetAttribute(TOOL_ID_ATTRIBUTE) ~= wanted then
		return
	end
	pendingTool = nil
	if os.clock() <= pendingToolUntil then
		task.defer(function()
			if child.Parent ~= nil and not isHeld(child :: Tool) then
				equip(child :: Tool)
			end
		end)
	end
end

local function watchBackpack()
	if backpackConnection then
		backpackConnection:Disconnect()
		backpackConnection = nil
	end
	local backpack = localPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		backpackConnection = backpack.ChildAdded:Connect(onBackpackChild)
	end
end

------------------------------------------------------------------------------
-- Barre Roblox
------------------------------------------------------------------------------

local function hideHotbar()
	local ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	if not ok then
		reportOnce("hotbar", `[Inventory] barre d'outils de Roblox pas coupée : {err}`)
	end
end

------------------------------------------------------------------------------
-- Sa boutique, visée et aperçu du colis
------------------------------------------------------------------------------

local function findPlot(): Model?
	for _, inst in CollectionService:GetTagged(PLOT_TAG) do
		if inst:IsA("Model") and inst:GetAttribute(OWNER_ATTRIBUTE) == localPlayer.UserId then
			return inst :: Model
		end
	end
	return nil
end

local function updatePlot()
	plot = findPlot()
end

local function watchPlot(inst: Instance)
	if watchedPlots[inst] then
		return
	end
	watchedPlots[inst] = inst:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(updatePlot)
	updatePlot()
end

local function unwatchPlot(inst: Instance)
	local connection = watchedPlots[inst]
	if connection then
		connection:Disconnect()
		watchedPlots[inst] = nil
	end
	updatePlot()
end

local function boundsOf(current: Model?): BasePart?
	if current == nil then
		return nil
	end
	local found = Find.path(current, BOUNDS)
	return if found ~= nil and found:IsA("BasePart") then found :: BasePart else nil
end

-- Point du monde sous (x, y) à l'écran (par défaut : le curseur, ou le dernier appui), et sa normale.
local function aim(x: number?, y: number?): (Vector3?, Vector3?)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil, nil
	end
	local screenX, screenY = x, y
	if screenX == nil or screenY == nil then
		local ok, mouse = pcall(function()
			return localPlayer:GetMouse()
		end)
		if not ok or mouse == nil then
			return nil, nil
		end
		screenX, screenY = mouse.X, mouse.Y
	end
	local ray = camera:ScreenPointToRay(screenX :: number, screenY :: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	local character = localPlayer.Character
	if character then
		table.insert(ignore, character)
	end
	local current = ghost
	if current then
		table.insert(ignore, current)
	end
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	if result == nil then
		return nil, nil
	end
	return result.Position, result.Normal
end

-- La pose a-t-elle des chances de passer (règle du serveur, en plus simple : voir l'en-tête) ?
local function looksValid(point: Vector3, normal: Vector3): boolean
	local bounds = boundsOf(plot)
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if bounds == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	local p = bounds.CFrame:PointToObjectSpace(point)
	local half = bounds.Size / 2
	local margin = Unbox.EdgeMargin + math.max(Unbox.BoxFootprint.X, Unbox.BoxFootprint.Z) / 2
	if math.abs(p.X) > half.X - margin or math.abs(p.Z) > half.Z - margin then
		return false
	end
	local bottom = bounds.CFrame:PointToWorldSpace(Vector3.new(p.X, -half.Y, p.Z))
	if normal.Y < Unbox.FloorMinNormalY or math.abs(point.Y - bottom.Y) > Unbox.FloorTolerance then
		return false
	end
	return ((root :: BasePart).Position - point).Magnitude <= REACH
end

local function hideGhost()
	local current = ghost
	if current then
		current.Parent = nil
	end
end

local function showGhost(point: Vector3, valid: boolean)
	local current = ghost
	if current == nil then
		local part = Instance.new("Part")
		part.Name = GHOST_NAME
		part.Size = Unbox.BoxFootprint
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = GHOST_TRANSPARENCY
		ghost = part
		current = part
	end
	local part = current :: BasePart
	local rotation = if plot then (plot :: Model):GetPivot().Rotation else CFrame.identity
	part.CFrame = CFrame.new(point) * rotation * CFrame.new(0, part.Size.Y / 2, 0)
	part.Color = if valid then GHOST_OK else GHOST_BAD
	part.Parent = Workspace
end

local function updateAim()
	if placing == nil then
		hideGhost()
		return
	end
	local point, normal = aim()
	lastAim = point
	if point == nil or normal == nil then
		lastAimValid = false
		hideGhost()
		return
	end
	lastAimValid = looksValid(point, normal)
	showGhost(point, lastAimValid)
end

------------------------------------------------------------------------------
-- Mode pose d'un colis
------------------------------------------------------------------------------

-- Le colis est-il encore dans l'inventaire (pas posé) d'après l'état du serveur ?
local function isStoredBox(uid: string): boolean
	for _, box in state.Boxes do
		if box.Uid == uid then
			return not box.Placed
		end
	end
	return false
end

stopPlacing = function()
	local current = placing
	if current == nil then
		return
	end
	placing = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	lastAim, lastAimValid = nil, false
	hideGhost()
end

local function placeAt(current: Placing, x: number?, y: number?)
	if placing ~= current or net == nil then
		return
	end
	local point = aim(x, y)
	if point == nil then
		return
	end
	net.Client.PlaceBox:Fire(current.uid, point)
	playAnimation("Place")
end

local function startPlacing(uid: string)
	stopPlacing()
	if not isStoredBox(uid) or isCarrying() or humanoidOf() == nil then
		return
	end
	unequip() -- un clic ne doit pas aussi frapper avec l'outil tenu
	local current: Placing = { uid = uid, connections = {} }
	placing = current
	table.insert(current.connections, RunService.RenderStepped:Connect(updateAim))
	table.insert(
		current.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				placeAt(current, input.Position.X, input.Position.Y)
			elseif input.KeyCode == CANCEL_KEY then
				stopPlacing()
			end
		end)
	)
	table.insert(
		current.connections,
		UserInputService.TouchTap:Connect(function(positions: { Vector2 }, processed: boolean)
			local first = positions[1]
			if not processed and first then
				placeAt(current, first.X, first.Y)
			end
		end)
	)
	updateAim()
end

------------------------------------------------------------------------------
-- Ce que l'écran montre
------------------------------------------------------------------------------

local function readState()
	state = InventoryState.Decode(localPlayer:GetAttribute(InventoryState.Attribute))
	local current = placing
	if current and not isStoredBox(current.uid) then
		stopPlacing() -- posé (ou disparu) : fin du mode pose
	end
end

local function ownedSet(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local value = localPlayer:GetAttribute(OWNED_ATTRIBUTE)
	if type(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			set[id] = true
		end
	else
		set[Tools.DefaultId] = true -- avant le profil : les poings seuls (possédés au départ)
	end
	return set
end

local function toolCards(): { ToolCard }
	local owned = ownedSet()
	local list: { ToolCard } = {}
	for _, def in Tools.List do
		if owned[def.Id] then
			table.insert(list, {
				key = def.Id :: string,
				toolId = def.Id :: string,
				name = string.upper(def.DisplayName),
				stat = string.format(TOOL_STAT, Format.short(def.Power)),
				icon = TOOL_ICON_PREFIX .. def.Id,
			})
		end
	end
	table.insert(list, {
		key = BAT_KEY,
		toolId = nil,
		name = string.upper(Bat.DisplayName),
		stat = string.format(BAT_STAT, Format.short(Bat.StunDuration)),
		icon = TOOL_ICON_PREFIX .. BAT_KEY,
	})
	return list
end

local function timerText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format(TIMER_TEXT, whole // 60, whole % 60)
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

------------------------------------------------------------------------------
-- Cartes
------------------------------------------------------------------------------

local function destroyView(view: CardView)
	for _, connection in view.connections do
		connection:Disconnect()
	end
	view.frame:Destroy()
end

local function clearCards(current: Screen)
	for _, section in current.sections do
		for key, view in section.views do
			destroyView(view)
			section.views[key] = nil
		end
	end
end

local function newView(section: Section, key: string): CardView?
	local template = section.template
	local parent = section.cards
	if template == nil or parent == nil then
		return nil
	end
	local clone: Instance? = template:Clone()
	if clone == nil then
		return nil -- Archivable = false : rien à cloner
	end
	local frame = clone :: GuiObject
	frame.Name = key
	local refs: { [string]: Instance? } = {}
	for _, path in CARD_PARTS[section.tab] do
		refs[path] = Find.path(frame, path)
	end
	local view: CardView = { frame = frame, refs = refs, handlers = {}, connections = {} }
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(view.connections, connection)
		end
	end
	keep(onClick(frame, function()
		local handler = view.handlers.Card
		if handler then
			handler()
		end
	end))
	for _, name in CARD_BUTTONS do
		local button = refs[name]
		if button then
			hover(button)
			keep(onClick(button, function()
				local handler: (() -> ())? = (view.handlers :: any)[name]
				if handler then
					handler()
				end
			end))
		end
	end
	local outline = refs.HoverOutline
	if outline and frame:IsA("GuiObject") then
		setVisible(outline, false)
		keep(frame.MouseEnter:Connect(function()
			setVisible(outline, true)
		end))
		keep(frame.MouseLeave:Connect(function()
			setVisible(outline, false)
		end))
	end
	frame.Visible = true
	frame.Parent = parent
	return view
end

local function paintItem(view: CardView, entry: InventoryState.ItemEntry)
	local def = Items.ById[entry.ItemId]
	if def == nil then
		return
	end
	local refs = view.refs
	local rarity = Rarities.ById[def.Rarity]
	setImage(refs.Icon, textureOf(def.Id) or "")
	if rarity then
		tint(refs.Rays, rarity.Color)
		tint(refs.Glow, rarity.Color)
		setText(refs["RarityBar.Rarity"], rarity.DisplayNameUpper)
	end
	setText(refs.ItemName, string.upper(def.DisplayName))
	local label = Mutations.Label({ Size = entry.Size, Effect = entry.Effect })
	setVisible(refs.MutationTag, label ~= nil)
	if label then
		setText(refs["MutationTag.MutationLabel"], label)
	end
	setText(refs.Income, Format.income(entry.Income))
	local displayed = entry.Slot ~= nil
	setVisible(refs.DisplayedBadge, displayed)
	setVisible(refs.PlaceButton, not displayed)
	setVisible(refs.UnequipButton, displayed)
	local uid = entry.Uid
	local function place()
		if net and canSend("PlaceItemAuto:" .. uid) then
			net.Client.PlaceItemAuto:Fire(uid)
		end
	end
	local function unplace()
		if net and canSend("UnplaceItem:" .. uid) then
			net.Client.UnplaceItem:Fire(uid)
		end
	end
	view.handlers.PlaceButton = if displayed then nil else place
	view.handlers.UnequipButton = if displayed then unplace else nil
	view.handlers.Card = if displayed then unplace else place
end

local close: () -> ()

local function paintBox(view: CardView, entry: InventoryState.BoxEntry, now: number)
	local refs = view.refs
	local rarity = Rarities.ById[entry.Rarity]
	local texture = textureOf(BOX_ICON_PREFIX .. entry.Tier)
	if texture then
		setImage(refs.Icon, texture) -- pas livrée : l'image du Template reste
	end
	if rarity then
		tint(refs.Rays, rarity.Color)
		tint(refs.Glow, rarity.Color)
		setText(refs["RarityBar.Rarity"], rarity.DisplayNameUpper)
	end
	setText(refs.BoxName, string.format(BOX_NAME, string.upper(entry.Tier)))
	local placed = entry.Placed
	local readyAt = entry.ReadyAt
	local remaining = if placed and readyAt then readyAt - now else 0
	local ready = placed and remaining <= 0
	setVisible(refs.PlaceButton, not placed)
	setVisible(refs.PlacedPill, placed)
	setVisible(refs.TimerPill, placed and not ready)
	setVisible(refs.ReadyPill, ready)
	if placed and not ready then
		setText(refs["TimerPill.TimerLabel"], timerText(remaining))
	end
	local uid = entry.Uid
	local function place()
		close()
		startPlacing(uid)
	end
	view.handlers.PlaceButton = if placed then nil else place
	view.handlers.Card = if placed then nil else place
end

local function paintTool(view: CardView, card: ToolCard, held: Tool?)
	local refs = view.refs
	local texture = textureOf(card.icon)
	if texture then
		setImage(refs.Icon, texture) -- pas livrée : l'image du Template reste
	end
	setText(refs.ToolName, card.name)
	setText(refs.ToolStat, card.stat)
	local inHand = false
	if held then
		if card.toolId == nil then
			inHand = isBatTool(held)
		else
			inHand = isBreakingTool(held) and held:GetAttribute(TOOL_ID_ATTRIBUTE) == card.toolId
		end
	end
	setVisible(refs.EquipButton, not inHand)
	setVisible(refs.EquippedPill, inHand)
	local function use()
		useToolCard(card)
	end
	view.handlers.EquipButton = if inHand then nil else use
	view.handlers.Card = use
end

-- Remet les cartes d'une section d'accord avec `keys` (dans l'ordre), peintes par `paint`.
local function syncSection<T>(section: Section, entries: { T }, keyOf: (T) -> string, paint: (CardView, T) -> ())
	local seen: { [string]: boolean } = {}
	for rank, entry in entries do
		local key = keyOf(entry)
		local view = section.views[key] or newView(section, key)
		if view then
			section.views[key] = view
			view.frame.LayoutOrder = rank
			paint(view, entry)
			seen[key] = true
		end
	end
	for key, view in section.views do
		if not seen[key] then
			destroyView(view)
			section.views[key] = nil
		end
	end
	setText(section.count, tostring(#entries))
end

local function heldTool(): Tool?
	local character = localPlayer.Character
	return if character then character:FindFirstChildWhichIsA("Tool") else nil
end

local function refreshBoxes(current: Screen)
	local now = serverNow()
	syncSection(current.sections["Boxes"], state.Boxes, function(entry: InventoryState.BoxEntry): string
		return "Box_" .. entry.Uid
	end, function(view: CardView, entry: InventoryState.BoxEntry)
		paintBox(view, entry, now)
	end)
end

local function refreshTools(current: Screen)
	local held = heldTool()
	syncSection(current.sections["Tools"], toolCards(), function(card: ToolCard): string
		return "Tool_" .. card.key
	end, function(view: CardView, card: ToolCard)
		paintTool(view, card, held)
	end)
end

local function refreshCounters(current: Screen)
	local stored, displayed = 0, 0
	for _, entry in state.Items do
		if entry.Slot ~= nil then
			displayed += 1
		else
			stored += 1
		end
	end
	local unlocked = localPlayer:GetAttribute(SLOTS_ATTRIBUTE)
	local slots = if type(unlocked) == "number" then unlocked else Balance.Display.StartSlots
	setText(current.counter, string.format(COUNTER_TEXT, stored, Balance.Display.InventoryMax))
	setText(current.displays, string.format(DISPLAYS_TEXT, displayed, slots))
	setText(current.sections["Potions"].count, "0")
end

-- ScrollTrack suit la liste : hauteur = part visible, place = avancée du défilement (règle de l'Index
-- v2, IndexController).
local function updateTrack(current: Screen)
	local track = current.track
	local list = current.list
	if track == nil or list == nil or not list:IsA("ScrollingFrame") then
		return
	end
	local frame = list :: ScrollingFrame
	local window = frame.AbsoluteWindowSize.Y
	local canvas = frame.AbsoluteCanvasSize.Y
	local range = canvas - window
	local share = 1
	local progress = 0
	if range > 0 and canvas > 0 then
		share = math.clamp(window / canvas, TRACK_MIN_SHARE, 1)
		progress = math.clamp(frame.CanvasPosition.Y / range, 0, 1)
	end
	local size = current.trackSize
	local position = current.trackPosition
	local anchor = track.AnchorPoint.Y
	local topScale = position.Y.Scale - anchor * size.Y.Scale
	local topOffset = position.Y.Offset - anchor * size.Y.Offset
	local free = (1 - share) * progress
	local heightScale = size.Y.Scale * share
	local heightOffset = math.round(size.Y.Offset * share)
	local wantedSize = UDim2.new(size.X.Scale, size.X.Offset, heightScale, heightOffset)
	local wantedPosition = UDim2.new(
		position.X.Scale,
		position.X.Offset,
		topScale + size.Y.Scale * free + anchor * heightScale,
		math.round(topOffset + size.Y.Offset * free + anchor * heightOffset)
	)
	if track.Size ~= wantedSize then
		track.Size = wantedSize
	end
	if track.Position ~= wantedPosition then
		track.Position = wantedPosition
	end
end

-- Remet l'écran ouvert d'accord avec l'état.
local function refresh()
	local current = screen
	if current == nil or not isOpen then
		return
	end
	local wanted: { string } = {}
	syncSection(current.sections["Items"], state.Items, function(entry: InventoryState.ItemEntry): string
		return "Item_" .. entry.Uid
	end, function(view: CardView, entry: InventoryState.ItemEntry)
		paintItem(view, entry)
		local texture = textures[entry.ItemId]
		if texture and not preloaded[texture] then
			preloaded[texture] = true
			table.insert(wanted, texture)
		end
	end)
	refreshBoxes(current)
	refreshTools(current)
	refreshCounters(current)
	updateTrack(current)
	if #wanted > 0 then
		task.spawn(Icons.preload, wanted)
	end
end

-- Minuteurs des colis posés, tant que l'écran est ouvert.
local function startTicker()
	tickToken += 1
	local token = tickToken
	task.spawn(function()
		while true do
			task.wait(TICK)
			local current = screen
			if token ~= tickToken or not isOpen or current == nil then
				return
			end
			refreshBoxes(current)
		end
	end)
end

------------------------------------------------------------------------------
-- Ouverture, fermeture, onglets
------------------------------------------------------------------------------

local function scrollTop(current: Screen)
	local list = current.list
	if list and list:IsA("ScrollingFrame") then
		(list :: ScrollingFrame).CanvasPosition = Vector2.new(0, 0)
	end
end

local function selectTab(current: Screen, wanted: TabName)
	tab = wanted
	for _, name in TAB_ORDER do
		local section = current.sections[name]
		setVisible(section.frame, name == wanted)
		setVisible(section.selected, name == wanted)
	end
	scrollTop(current)
	updateTrack(current)
end

close = function()
	isOpen = false
	tickToken += 1
	local current = screen
	if current then
		-- Cartes retirées une fois l'écran éteint ; une réouverture d'ici là les remet d'accord.
		Motion.Close(current.gui, function()
			clearCards(current)
		end)
	end
end

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
		clearCards(old)
	end
	isOpen = false
	tickToken += 1
	gui.Enabled = false -- fermé jusqu'au bouton du HUD
	Motion.SetCloser(gui, close) -- un autre écran du groupe ScreenGroup s'ouvre (L-089)
	local name = gui.Name

	local sections: { [TabName]: Section } = {}
	for _, tabName in TAB_ORDER do
		local frame = guiObject(gui, `{tabName}Section`)
		local cards = if frame then Find.path(frame, "Cards") else nil
		local template = if tabName ~= "Potions" then guiObject(cards, "Template") else nil
		if frame == nil then
			reportOnce(`section:{tabName}`, `[Inventory] {name}.{tabName}Section introuvable : onglet vide`)
		elseif tabName ~= "Potions" and template == nil then
			reportOnce(`template:{tabName}`, `[Inventory] {name}.{tabName}Section.Cards.Template introuvable : section vide`)
		end
		if template then
			template.Visible = false
		end
		-- Cartes d'exemple de la maquette (Preview_*), retirées de la copie du joueur.
		if cards then
			for _, child in cards:GetChildren() do
				if string.sub(child.Name, 1, #PREVIEW_PREFIX) == PREVIEW_PREFIX then
					child:Destroy()
				end
			end
		end
		local button = Find.path(gui, `Tabs.{tabName}Tab`)
		if button == nil then
			reportOnce(`tab:{tabName}`, `[Inventory] {name}.Tabs.{tabName}Tab introuvable : onglet pas branché`)
		end
		sections[tabName] = {
			tab = tabName,
			frame = frame,
			cards = cards,
			template = template,
			count = if frame then Find.path(frame, "SectionCount.CountLabel") else nil,
			button = button,
			selected = guiObject(button, "Selected"),
			views = {},
		}
	end

	local track = guiObject(gui, "ScrollTrack")
	local list = Find.path(gui, "List")
	local current: Screen = {
		gui = gui,
		list = list,
		track = track,
		trackPosition = if track then track.Position else UDim2.new(),
		trackSize = if track then track.Size else UDim2.new(),
		counter = Find.path(gui, "Counter"),
		displays = Find.path(gui, "Displays"),
		sections = sections,
		connections = {},
	}
	screen = current
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	local closeButton = Find.path(gui, "CloseButton")
	hover(closeButton)
	keep(onClick(closeButton, close))
	local equipBest = Find.path(gui, "EquipBestButton")
	if equipBest == nil then
		reportOnce("equipbest", `[Inventory] {name}.EquipBestButton introuvable : pas d'Equip Best`)
	end
	hover(equipBest)
	keep(onClick(equipBest, function()
		InventoryController.EquipBest()
	end))
	for _, tabName in TAB_ORDER do
		local button = sections[tabName].button
		hover(button)
		keep(onClick(button, function()
			if screen == current and tab ~= tabName then
				selectTab(current, tabName)
			end
		end))
	end
	if track == nil then
		reportOnce("track", `[Inventory] {name}.ScrollTrack introuvable : pas de curseur de défilement`)
	elseif list and list:IsA("ScrollingFrame") then
		local frame = list :: ScrollingFrame
		for _, property in { "CanvasPosition", "AbsoluteCanvasSize", "AbsoluteWindowSize" } do
			keep(frame:GetPropertyChangedSignal(property):Connect(function()
				if screen == current then
					updateTrack(current)
				end
			end))
		end
	end
	selectTab(current, tab)
end

-- Écran branché encore présent, ou celui de PlayerGui (branché au passage), ou nil.
local function currentScreen(): Screen?
	local current = screen
	if current and current.gui.Parent ~= nil then
		return current
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local found = if playerGui then playerGui:FindFirstChild(SCREEN) else nil
	if found and found:IsA("ScreenGui") then
		bind(found :: ScreenGui)
		return screen
	end
	return nil
end

local function open()
	stopPlacing()
	local current = currentScreen()
	if current == nil then
		reportOnce("screen", `[Inventory] écran {SCREEN} absent de PlayerGui : l'inventaire ne s'ouvre pas`)
		return
	end
	readState()
	isOpen = true
	selectTab(current, tab)
	refresh()
	Motion.Open(current.gui)
	startTicker()
end

local function toggle()
	if isOpen then
		close()
	else
		open()
	end
end

------------------------------------------------------------------------------
-- Bouton du HUD, touches, personnage
------------------------------------------------------------------------------

local hudBound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function bindHud(gui: Instance)
	if hudBound[gui] then
		return
	end
	local found = Find.path(gui, HUD_BUTTON)
	if found == nil or not found:IsA("GuiButton") then
		reportOnce("hud", `[Inventory] {HUD}.{HUD_BUTTON} introuvable ou pas un bouton : l'inventaire ne s'ouvre pas`)
		return
	end
	hudBound[gui] = true
	(found :: GuiButton).Activated:Connect(toggle)
end

local function onInput(input: InputObject, processed: boolean)
	if processed then
		return
	end
	local key = input.KeyCode
	if key == TOOL_KEY then
		toggleTool(isBreakingTool)
	elseif key == BAT_KEY_CODE then
		toggleTool(isBatTool)
	end
end

local function watchCharacter(character: Model?)
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	stopPlacing()
	pendingTool = nil
	hideHotbar()
	task.defer(watchBackpack) -- le Backpack est refait à chaque apparition
	if character == nil then
		return
	end
	local function onTools(child: Instance)
		if child:IsA("Tool") then
			if isBreakingTool(child) and child:GetAttribute(TOOL_ID_ATTRIBUTE) == pendingTool then
				pendingTool = nil -- le serveur l'a mis en main lui-même (l'ancien y était)
			end
			if child.Parent == character then
				stopPlacing()
			end
			local current = screen
			if current and isOpen then
				refreshTools(current)
			end
		end
	end
	table.insert(characterConnections, character.ChildAdded:Connect(onTools))
	table.insert(characterConnections, character.ChildRemoved:Connect(onTools))
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function InventoryController.Open()
	open()
end

function InventoryController.Close()
	if isOpen then
		close()
	end
end

function InventoryController.Toggle()
	toggle()
end

function InventoryController.SelectTab(name: string)
	local current = currentScreen()
	if current and table.find(TAB_ORDER, name) then
		selectTab(current, name)
	end
end

function InventoryController.StartPlacing(boxUid: string)
	readState()
	if isOpen then
		close()
	end
	startPlacing(boxUid)
end

function InventoryController.EquipBest()
	if net == nil then
		warn("[InventoryController] remotes pas encore prêts : EquipBest ignoré")
		return
	end
	if canSend("EquipBest") then
		net.Client.EquipBest:Fire()
	end
end

function InventoryController.GetState(): { [string]: any }
	local current = placing
	return {
		Open = isOpen,
		Tab = tab,
		Placing = if current then current.uid else nil,
		Aim = lastAim,
		AimValid = lastAimValid,
		Items = #state.Items,
		Boxes = #state.Boxes,
		Tools = #toolCards(),
	}
end

function InventoryController.Start()
	hideHotbar() -- tout de suite : la barre ne doit pas apparaître le temps des remotes
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	animation = loadAnimationController()

	readState()
	localPlayer:GetAttributeChangedSignal(InventoryState.Attribute):Connect(function()
		readState()
		refresh()
	end)
	for _, attribute in { OWNED_ATTRIBUTE, SLOTS_ATTRIBUTE } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	localPlayer:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(function()
		if isCarrying() then
			stopPlacing()
		end
	end)
	localPlayer.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Backpack") then
			watchBackpack()
		end
	end)
	localPlayer.CharacterAdded:Connect(watchCharacter)
	watchCharacter(localPlayer.Character)
	UserInputService.InputBegan:Connect(onInput)

	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(watchPlot)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(unwatchPlot)
	for _, inst in CollectionService:GetTagged(PLOT_TAG) do
		watchPlot(inst)
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child:IsA("ScreenGui") then
			if child.Name == SCREEN then
				bind(child :: ScreenGui)
			elseif child.Name == HUD then
				bindHud(child)
			end
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end
	local hud = playerGui:FindFirstChild(HUD)
	if hud and hud:IsA("ScreenGui") then
		bindHud(hud)
	end
end

return InventoryController
