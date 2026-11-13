--!strict
-- PvPController (DEV-041, DEV-040, DEV-044, client) : le vol entre joueurs côté joueur (Partie 1,
-- sections 6.1 et 6.4 ; contrat UI 2.2 ; boutique du hub, liaison L-050). Il ne fait que demander et
-- afficher : PvPService (serveur) décide de tout.
--
-- Rôle :
--   - Invites de vol : sur chaque objet exposé de la boutique d'un autre joueur (Model taggé
--     DisplayItem par DisplayService, attributs DisplaySlot et ItemId), une invite ProximityPrompt
--     créée ici sur la pièce principale de l'objet : « Steal », le nom de l'objet, maintien
--     PvP.StealGrabTime (1 s), portée PvP.StealMaxDistance − PROMPT_DISTANCE_MARGIN. Active
--     seulement si la boutique est ouverte au vol (attribut StealOpen de la parcelle, posé par
--     PvPService), mains vides (attribut Carrying du joueur, CarryService), joueur dans le volume
--     Bounds de la boutique, objet pas à l'abri (SafeSlots), et pas d'interdiction de voler cette
--     boutique (attribut RobCooldown_<PlotIndex> du joueur local, heure serveur de fin, posé par
--     PvPService quand le propriétaire l'a frappé ou qu'il est mort dedans). Plus aucune protection
--     des boutiques (Cantin, 2026-11-12).
--     Début du maintien : StealItem(plotIndex, slotIndex) ; invite déclenchée : StealItem une seconde
--     fois (le serveur mesure le maintien entre les deux) et animation Grab.
--   - Panneau de repérage (6.1, point 1) : à PvP.ScoutDistance studs ou moins du volume Bounds de la
--     boutique d'un autre joueur, un panneau au-dessus de sa porte (PlotDoor/Window), vu par le
--     joueur local seul (rangé dans son PlayerGui) :
--       OwnerName  « Alice's Shop » ;
--       Income     valeur exposée, attribut ExposedIncome du propriétaire (DisplayService, sinon
--                  Income) : « +$12.4K/s » ;
--       HP         PV de la porte, « HP 840 » (WindowController.GetHP, sinon l'attribut MaxHP de la
--                  porte ; 0 si elle est cassée), écrits comme la barre BB_WindowHP (Format.hp) ;
--       Status     caché, sauf : « ROB AGAIN IN 42s » (interdiction du joueur local sur cette
--                  boutique), sinon « OPEN » (porte cassée, fenêtre de vol ouverte ; vague 33 : sans
--                  chrono, le voleur a tout son temps).
--     Copie du billboard BB_ShopInfo de Clément (ReplicatedStorage/Assets/UI, mêmes 4 éléments ;
--     nom proposé, pas encore au contrat 2.2) dès qu'il existe, sinon un panneau V0 gris.
--   - Étiquette « SAFE » V0 au pied de chaque objet à l'abri (coffre-fort V0 de PvPService), chez
--     tout le monde : le voleur comprend pourquoi l'objet n'a pas d'invite.
--   - Bot joueur (L-105, BotService) : sa boutique (attribut BotName de la parcelle, OwnerUserId = 0) a
--     les mêmes invites et le même panneau (« Bot's Shop », valeur exposée = attribut BotIncome).
--   - L'objet volé porté au-dessus de la tête : rien ici, CarryService (visuel serveur, BB_Carry,
--     contour rouge, malus) et CarryController (animations, outils rangés) suffisent.
-- Mobile : l'état de chaque boutique (volume, porte, droit de voler, objets à l'abri) est calculé une
-- fois par tour, puis lu par ses objets ; volume et porte sont gardés tant qu'ils sont dans la parcelle.
--
-- API (client), pour les tests dans Studio :
--   PvPController.GetPanelText(plot) -> { OwnerName, Income, HP, Status }?   panneau affiché, ou nil
--   PvPController.GetPrompt(itemModel) -> ProximityPrompt?                    invite d'un objet exposé

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Contract = Shared:WaitForChild("Contract")
local Items = require(Config:WaitForChild("Items"))
local PvP = require(Config:WaitForChild("PvP"))
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))
local Format = require(Shared:WaitForChild("Format"))

-- Ce que ce contrôleur utilise d'AnimationController et de WindowController.
type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
}
type WindowApi = {
	GetHP: (windowId: string) -> (number?, number?),
}

export type PanelText = {
	OwnerName: string,
	Income: string,
	HP: string,
	Status: string?,
}

type ItemWatch = {
	Model: Model,
	Plot: Model?, -- sa parcelle, trouvée à l'arrivée de l'objet
	Prompt: ProximityPrompt?,
	SafeTag: BillboardGui?,
}

type PlotWatch = {
	Plot: Model,
	Bounds: BasePart?, -- gardés tant qu'ils sont dans la parcelle (streaming)
	Door: Instance?,
	Allowed: boolean, -- le joueur local peut voler ici en ce moment (refait à chaque tour)
	Safe: { [number]: boolean }, -- présentoirs à l'abri (refait à chaque tour)
	Gui: BillboardGui?,
	Point: Attachment?,
	Text: PanelText?,
}

local PLOT_TAG = "PlayerPlot" -- contrat 2.1
local DISPLAY_TAG = "DisplayItem" -- posé par DisplayService (tag de code)
local BOUNDS = "Bounds" -- contrat 10.4
local DOOR = "PlotDoor" -- boutique du hub (L-050)
local WINDOW = "Window"
local TEMPLATE_NAME = "BB_ShopInfo" -- proposé à Clément, pas encore au contrat 2.2
local FIELDS = { "OwnerName", "Income", "HP", "Status" }
local GRAB_ANIMATION = "Grab" -- contrat 2.4
-- Posés par PlotService, DisplayService, WindowService, CarryService et PvPService (mêmes noms là-bas).
local OWNER_ATTRIBUTE = "OwnerUserId"
local PLOT_INDEX_ATTRIBUTE = "PlotIndex"
local SLOT_ATTRIBUTE = "DisplaySlot"
local ITEM_ID_ATTRIBUTE = "ItemId"
local INCOME_ATTRIBUTE = "Income"
local EXPOSED_INCOME_ATTRIBUTE = "ExposedIncome" -- sans les bonus de la boutique Robux (DEV-100)
local CARRYING_ATTRIBUTE = "Carrying"
local WINDOW_ID_ATTRIBUTE = "WindowId"
local MAX_HP_ATTRIBUTE = "MaxHP"
local BROKEN_ATTRIBUTE = "Broken"
local OPEN_ATTRIBUTE = "StealOpen"
local SAFE_SLOTS_ATTRIBUTE = "SafeSlots"
local ROB_COOLDOWN_FORMAT = "RobCooldown_%d" -- sur le joueur local, posé par PvPService
local BOT_NAME_ATTRIBUTE = "BotName" -- PlotService : boutique du bot joueur (L-105)
local BOT_INCOME_ATTRIBUTE = "BotIncome" -- BotService : sa valeur exposée
-- Noms des objets créés ici (côté client seulement).
local PROMPT_NAME = "StealPrompt"
local PANEL_PREFIX = "ShopInfo_"
local POINT_NAME = "ShopInfoPoint"
local SAFE_TAG_NAME = "SafeTag"
local SAFE_POINT_NAME = "SafeTagPoint"

-- Textes lus par le joueur, en anglais (L-036).
local ACTION_TEXT = "Steal"
local SHOP_NAME = "%s's Shop"
local HP_TEXT = "HP %s"
local SAFE_TEXT = "SAFE"
local STATUS = {
	Cooldown = "ROB AGAIN IN %ds", -- V0, à valider par Clément
	Open = "OPEN", -- V0, vague 33 : sans chrono (avant « OPEN: %ds »)
}

-- V0 proposé, absent du doc : invites et panneaux revus 5 fois par seconde.
local REFRESH_INTERVAL = 0.2
-- V0 proposé, absent du doc : invite visible un demi-stud avant la portée du serveur.
local PROMPT_DISTANCE_MARGIN = 0.5
-- V0 proposé, absent du doc : panneau gris en attendant BB_ShopInfo (taille en studs), posé
-- PANEL_LIFT studs au-dessus du haut de la porte, au-dessus de la barre de PV BB_WindowHP.
local PANEL_SIZE = UDim2.fromScale(7, 3.2)
local PANEL_LIFT = 3.6
local TEXT_COLOR = Color3.new(1, 1, 1)
local STROKE_COLOR = Color3.fromHex("#1B1B24") -- contour du texte, planche 10.6
local INCOME_COLOR = Color3.fromHex("#35C93B") -- vert « acheter / OK », planche 10.6
local STATUS_COLOR = Color3.fromHex("#FF8C1A") -- orange « améliorations », planche 10.6
-- V0 proposé, absent du doc : étiquette « SAFE » au pied de l'objet à l'abri.
local SAFE_SIZE = UDim2.fromScale(2.2, 0.7)
local SAFE_LIFT = 0.4
local SAFE_COLOR = Color3.fromHex("#4FC3FF")
local SAFE_MAX_DISTANCE = 60

local localPlayer = Players.LocalPlayer

local PvPController = {}

local Net: any = nil
local animation: AnimationApi? = nil
local windows: WindowApi? = nil
local playerGui: Instance? = nil
local itemWatches: { [Instance]: ItemWatch } = {}
local plotWatches: { [Instance]: PlotWatch } = {}

-- Outils ----------------------------------------------------------------------------------------

local function localRoot(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Distance de `point` au pavé `part` (0 dedans).
local function distanceTo(part: BasePart, point: Vector3): number
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	local dx = math.max(math.abs(p.X) - h.X, 0)
	local dy = math.max(math.abs(p.Y) - h.Y, 0)
	local dz = math.max(math.abs(p.Z) - h.Z, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function number(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if type(value) == "number" and value == value then value else nil
end

-- Valeur exposée d'un joueur ($/s de ses objets, sans bonus).
local function exposedIncome(player: Player): number
	return number(player, EXPOSED_INCOME_ATTRIBUTE) or number(player, INCOME_ATTRIBUTE) or 0
end

local function ownerOf(plot: Model): Player?
	local id = number(plot, OWNER_ATTRIBUTE)
	if id == nil or id == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(id)
end

local function isMine(plot: Model): boolean
	return number(plot, OWNER_ATTRIBUTE) == localPlayer.UserId
end

-- Propriétaire de la boutique, pour le panneau : nom affiché et valeur exposée d'un autre
-- joueur, ou du bot joueur (L-105 : attributs BotName de PlotService et BotIncome de BotService sur la
-- parcelle, OwnerUserId = 0) ; nil pour une boutique libre.
local function shopOwner(plot: Model): (string?, number)
	local owner = ownerOf(plot)
	if owner then
		return owner.DisplayName, exposedIncome(owner)
	end
	local botName = plot:GetAttribute(BOT_NAME_ATTRIBUTE)
	if type(botName) == "string" then
		return botName, number(plot, BOT_INCOME_ATTRIBUTE) or 0
	end
	return nil, 0
end

-- Parcelle (Model taggé PlayerPlot) qui contient `instance`, ou nil.
local function plotOf(instance: Instance): Model?
	local current = instance.Parent
	while current do
		if current:IsA("Model") and CollectionService:HasTag(current, PLOT_TAG) then
			return current :: Model
		end
		current = current.Parent
	end
	return nil
end

-- Volume Bounds de la boutique, gardé tant qu'il est dans la parcelle.
local function boundsOf(watch: PlotWatch): BasePart?
	local cached = watch.Bounds
	if cached and cached:IsDescendantOf(watch.Plot) then
		return cached
	end
	local found = Find.path(watch.Plot, BOUNDS)
	watch.Bounds = if found and found:IsA("BasePart") then found :: BasePart else nil
	return watch.Bounds
end

-- Porte de la boutique : l'objet Window de PlotDoor (sinon le premier Window de la parcelle).
local function doorOf(watch: PlotWatch): Instance?
	local cached = watch.Door
	if cached and cached:IsDescendantOf(watch.Plot) then
		return cached
	end
	local plot = watch.Plot
	local door = plot:FindFirstChild(DOOR, true)
	local window = if door then door:FindFirstChild(WINDOW, true) else nil
	watch.Door = window or plot:FindFirstChild(WINDOW, true)
	return watch.Door
end

-- Présentoirs à l'abri : attribut SafeSlots « 3 » ou « 3,7 ».
local function safeSlots(plot: Model): { [number]: boolean }
	local slots: { [number]: boolean } = {}
	local text = plot:GetAttribute(SAFE_SLOTS_ATTRIBUTE)
	if type(text) == "string" then
		for piece in string.gmatch(text, "%d+") do
			local slot = tonumber(piece)
			if slot then
				slots[slot] = true
			end
		end
	end
	return slots
end

-- Secondes restantes de l'interdiction du joueur local sur cette boutique (0 : aucune).
local function cooldownLeft(plot: Model): number
	local index = number(plot, PLOT_INDEX_ATTRIBUTE)
	if index == nil then
		return 0
	end
	local endsAt = number(localPlayer, string.format(ROB_COOLDOWN_FORMAT, index))
	if endsAt == nil then
		return 0
	end
	return math.max(0, endsAt - Workspace:GetServerTimeNow())
end

-- Peut-il voler dans cette boutique, en ce moment ? (Le serveur revérifie tout.)
local function canStealIn(watch: PlotWatch, root: BasePart?): boolean
	local plot = watch.Plot
	if isMine(plot) or plot:GetAttribute(OPEN_ATTRIBUTE) ~= true or cooldownLeft(plot) > 0 then
		return false
	end
	if localPlayer:GetAttribute(CARRYING_ATTRIBUTE) ~= nil then
		return false
	end
	if shopOwner(plot) == nil then
		return false
	end
	local bounds = boundsOf(watch)
	return root ~= nil and bounds ~= nil and inside(bounds, root.Position)
end

local function mainPart(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	local first = model:FindFirstChildWhichIsA("BasePart", true)
	return if first then first :: BasePart else nil
end

local function textLabel(gui: Instance, name: string): TextLabel?
	local found = Find.path(gui, name)
	return if found and found:IsA("TextLabel") then found :: TextLabel else nil
end

-- Invites et étiquettes des objets exposés -----------------------------------------------------------

local function playGrab()
	local api = animation
	if api then
		pcall(api.PlayPlayer, GRAB_ANIMATION)
	end
end

local function makePrompt(watch: ItemWatch, plot: Model)
	local part = mainPart(watch.Model)
	local plotIndex = number(plot, PLOT_INDEX_ATTRIBUTE)
	local slot = number(watch.Model, SLOT_ATTRIBUTE)
	local itemId = watch.Model:GetAttribute(ITEM_ID_ATTRIBUTE)
	if part == nil or plotIndex == nil or slot == nil then
		return
	end
	local item = if type(itemId) == "string" then Items.ById[itemId] else nil
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = ACTION_TEXT
	prompt.ObjectText = if item then item.DisplayName else ""
	prompt.HoldDuration = PvP.StealGrabTime
	prompt.MaxActivationDistance = math.max(PvP.StealMaxDistance - PROMPT_DISTANCE_MARGIN, 1)
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.PromptButtonHoldBegan:Connect(function()
		Net.Client.StealItem:Fire(plotIndex, slot) -- début du maintien
	end)
	prompt.Triggered:Connect(function()
		Net.Client.StealItem:Fire(plotIndex, slot) -- fin du maintien
		playGrab()
	end)
	prompt.Parent = part
	watch.Prompt = prompt
end

local function removeSafeTag(watch: ItemWatch)
	local tag = watch.SafeTag
	if tag then
		watch.SafeTag = nil
		local point = tag.Adornee
		tag:Destroy()
		if point and point.Name == SAFE_POINT_NAME then
			point:Destroy()
		end
	end
end

local function makeSafeTag(watch: ItemWatch)
	local part = mainPart(watch.Model)
	local parent = playerGui
	if part == nil or parent == nil then
		return
	end
	local point = Instance.new("Attachment")
	point.Name = SAFE_POINT_NAME
	point.Parent = part
	point.WorldPosition = watch.Model:GetPivot().Position + Vector3.new(0, SAFE_LIFT, 0)
	local gui = Instance.new("BillboardGui")
	gui.Name = SAFE_TAG_NAME
	gui.Size = SAFE_SIZE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.MaxDistance = SAFE_MAX_DISTANCE
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextColor3 = SAFE_COLOR
	label.TextStrokeColor3 = STROKE_COLOR
	label.TextStrokeTransparency = 0
	label.Text = SAFE_TEXT
	label.Parent = gui
	gui.Adornee = point
	gui.Parent = parent
	watch.SafeTag = gui
end

local function removePrompt(watch: ItemWatch)
	local prompt = watch.Prompt
	if prompt then
		watch.Prompt = nil
		prompt:Destroy()
	end
end

local function refreshItem(watch: ItemWatch)
	local plot = watch.Plot
	local state = if plot then plotWatches[plot] else nil
	if plot == nil or state == nil then
		return
	end
	local slot = number(watch.Model, SLOT_ATTRIBUTE)
	local safe = slot ~= nil and state.Safe[slot] == true
	local tag = watch.SafeTag
	if safe and not tag then
		makeSafeTag(watch)
	elseif tag and not safe then
		removeSafeTag(watch)
	end
	if isMine(plot) then
		removePrompt(watch)
		return
	end
	if watch.Prompt == nil then
		makePrompt(watch, plot)
	end
	local prompt = watch.Prompt
	if prompt then
		prompt.Enabled = state.Allowed and not safe
	end
end

-- Panneau de repérage ------------------------------------------------------------------------------------

local function template(): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(TEMPLATE_NAME, true) else nil
	if found and found:IsA("BillboardGui") then
		return found
	end
	return nil
end

-- Panneau V0 en attendant BB_ShopInfo : les 4 éléments, l'un sous l'autre.
local function placeholderPanel(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = PANEL_SIZE
	gui.LightInfluence = 0
	for index, name in FIELDS do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.fromScale(1, 1 / #FIELDS)
		label.Position = UDim2.fromScale(0, (index - 1) / #FIELDS)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		label.TextColor3 = if name == "Income" then INCOME_COLOR elseif name == "Status" then STATUS_COLOR else TEXT_COLOR
		label.TextStrokeColor3 = STROKE_COLOR
		label.TextStrokeTransparency = 0
		label.Text = ""
		label.Parent = gui
	end
	return gui
end

local function doorBox(door: Instance): (CFrame?, Vector3?)
	if door:IsA("BasePart") then
		local part = door :: BasePart
		return part.CFrame, part.Size
	elseif door:IsA("Model") then
		return (door :: Model):GetBoundingBox()
	end
	return nil, nil
end

local function hidePanel(watch: PlotWatch)
	local gui, point = watch.Gui, watch.Point
	watch.Gui, watch.Point, watch.Text = nil, nil, nil
	if gui then
		gui:Destroy()
	end
	if point then
		point:Destroy()
	end
end

local function showPanel(watch: PlotWatch, door: Instance): BillboardGui?
	local existing = watch.Gui
	if existing and existing.Parent ~= nil then
		return existing
	end
	local parent = playerGui
	local part: BasePart? = nil
	if door:IsA("BasePart") then
		part = door :: BasePart
	elseif door:IsA("Model") then
		part = mainPart(door :: Model)
	end
	local cf, size = doorBox(door)
	if parent == nil or part == nil or cf == nil or size == nil then
		return nil
	end
	local model = template()
	local gui = if model then model:Clone() else placeholderPanel()
	gui.Name = PANEL_PREFIX .. watch.Plot.Name
	gui.ResetOnSpawn = false
	-- Point d'accroche au-dessus du milieu de la porte (les vantaux ne sont pas centrés).
	local point = Instance.new("Attachment")
	point.Name = POINT_NAME
	point.Parent = part
	point.WorldPosition = cf.Position + Vector3.new(0, size.Y / 2 + PANEL_LIFT, 0)
	gui.Adornee = point
	gui.Parent = parent
	watch.Gui, watch.Point = gui, point
	return gui
end

local function doorHP(door: Instance): number
	if door:GetAttribute(BROKEN_ATTRIBUTE) == true then
		return 0
	end
	local maxHp = number(door, MAX_HP_ATTRIBUTE) or 0
	local windowId = door:GetAttribute(WINDOW_ID_ATTRIBUTE)
	local api = windows
	if api and type(windowId) == "string" then
		local ok, hp = pcall(api.GetHP, windowId)
		if ok and type(hp) == "number" then
			return hp
		end
	end
	return maxHp
end

local function statusOf(plot: Model): string?
	local left = cooldownLeft(plot)
	if left > 0 then
		return string.format(STATUS.Cooldown, math.ceil(left))
	end
	if plot:GetAttribute(OPEN_ATTRIBUTE) == true then
		return STATUS.Open -- vague 33 : plus de chrono chez un joueur
	end
	return nil
end

local function refreshPanel(watch: PlotWatch, root: BasePart?)
	local plot = watch.Plot
	local name, income = shopOwner(plot)
	local bounds = boundsOf(watch)
	if name == nil or isMine(plot) or root == nil or bounds == nil or distanceTo(bounds, root.Position) > PvP.ScoutDistance then
		hidePanel(watch)
		return
	end
	local door = doorOf(watch)
	local gui = if door then showPanel(watch, door) else nil
	if door == nil or gui == nil then
		hidePanel(watch)
		return
	end
	local text: PanelText = {
		OwnerName = string.format(SHOP_NAME, name),
		Income = Format.income(income),
		HP = string.format(HP_TEXT, Format.hp(doorHP(door))),
		Status = statusOf(plot),
	}
	watch.Text = text
	for _, name in FIELDS do
		local label = textLabel(gui, name)
		if label then
			local value = (text :: any)[name]
			label.Visible = value ~= nil
			label.Text = if value ~= nil then value else ""
		end
	end
end

-- Suivi ---------------------------------------------------------------------------------------------------------

local function watchPlot(instance: Instance): PlotWatch?
	-- Seules les boutiques de la map : le gabarit PLOT_Shop de Clément (ReplicatedStorage/Assets/Plots)
	-- porte aussi le tag, et il était suivi comme une 7e boutique.
	if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
		return nil
	end
	local existing = plotWatches[instance]
	if existing then
		return existing
	end
	local watch: PlotWatch = {
		Plot = instance :: Model,
		Bounds = nil,
		Door = nil,
		Allowed = false,
		Safe = {},
		Gui = nil,
		Point = nil,
		Text = nil,
	}
	plotWatches[instance] = watch
	return watch
end

local function unwatchPlot(instance: Instance)
	local watch = plotWatches[instance]
	if watch then
		plotWatches[instance] = nil
		hidePanel(watch)
	end
end

-- État d'une boutique pour ce tour : droit de voler et objets à l'abri.
local function updatePlot(watch: PlotWatch, root: BasePart?)
	watch.Safe = safeSlots(watch.Plot)
	watch.Allowed = canStealIn(watch, root)
end

local function watchItem(instance: Instance)
	if not instance:IsA("Model") or itemWatches[instance] ~= nil then
		return
	end
	local plot = plotOf(instance)
	local watch: ItemWatch = { Model = instance :: Model, Plot = plot, Prompt = nil, SafeTag = nil }
	itemWatches[instance] = watch
	local state = if plot then watchPlot(plot) else nil
	if state then
		updatePlot(state, localRoot())
	end
	refreshItem(watch)
end

local function unwatchItem(instance: Instance)
	local watch = itemWatches[instance]
	if watch == nil then
		return
	end
	itemWatches[instance] = nil
	removePrompt(watch)
	removeSafeTag(watch)
end

local function refreshAll()
	local root = localRoot()
	for _, watch in plotWatches do
		updatePlot(watch, root)
		refreshPanel(watch, root)
	end
	for _, watch in itemWatches do
		refreshItem(watch)
	end
end

-- API ---------------------------------------------------------------------------------------------------------

function PvPController.GetPanelText(plot: Instance): PanelText?
	local watch = plotWatches[plot]
	if watch == nil or watch.Gui == nil then
		return nil
	end
	return watch.Text
end

function PvPController.GetPrompt(itemModel: Instance): ProximityPrompt?
	local watch = itemWatches[itemModel]
	return if watch then watch.Prompt else nil
end

local function optional(name: string, field: string): any
	local module = script.Parent:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any)[field]) == "function" then
			return result
		end
	end
	return nil
end

function PvPController.Start()
	Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	playerGui = localPlayer:WaitForChild("PlayerGui")
	animation = optional("AnimationController", "PlayPlayer")
	windows = optional("WindowController", "GetHP")

	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		watchPlot(plot)
	end
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(function(plot: Instance)
		watchPlot(plot)
	end)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(unwatchPlot)
	for _, item in CollectionService:GetTagged(DISPLAY_TAG) do
		watchItem(item)
	end
	-- Avec StreamingEnabled, les objets exposés arrivent et repartent avec la zone autour du joueur.
	CollectionService:GetInstanceAddedSignal(DISPLAY_TAG):Connect(watchItem)
	CollectionService:GetInstanceRemovedSignal(DISPLAY_TAG):Connect(unwatchItem)
	localPlayer:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(refreshAll)

	if RunService:IsStudio() then
		local watched = 0
		for _ in plotWatches do
			watched += 1
		end
		print(`[PvPController] {watched} boutique(s) suivie(s) pour le repérage et le vol`)
	end
	while true do
		task.wait(REFRESH_INTERVAL)
		xpcall(refreshAll, function(err: any)
			warn(`[PvPController] {err}`)
		end)
	end
end

return PvPController
