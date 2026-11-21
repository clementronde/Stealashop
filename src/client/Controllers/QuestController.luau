--!strict
-- QuestController (DEV-132, UI-130 ; vague 80, a266 ; client) : écran des quêtes du jour UI_Quests et bouton
-- QuestsButton du HUD (noms proposés à Clément ; tout est facultatif : écran ou élément absent, rien ne s'affiche,
-- aucune erreur). Règles : Config/Quests ; serveur : QuestService. Coupé par Features.Quests (rien n'est branché ;
-- HudController cache QuestsButton).
--
-- Rôle :
--   - UI_HUD.QuestsButton (tous les exemplaires, LeftRail et LeftRailTouch) ouvre l'écran, un 2e appui le ferme ;
--     CloseButton le ferme. Ouverture et fermeture par UI/Motion (écran du groupe ScreenGroup de Clément) ;
--   - QuestsAlert (pastille « ! » dans chaque QuestsButton, UI/AlertBadge) allumée quand une quête finie attend
--     d'être réclamée, éteinte quand elle est réclamée ;
--   - une ligne par quête du jour, clonée depuis List.Template et nommée Quest_<place> (LayoutOrder = place) :
--     QuestName (texte de la quête, « Rob 3 stores »), ProgressLabel (« 2/3 »), Bar.Fill (taille X en Scale = part
--     faite, la hauteur de Clément gardée), RewardLabel (la récompense), Icon (Decal ICON_<Icon> de Clément s'il est
--     livré, sinon l'image du Template), ClaimButton (visible quand la quête est finie et pas réclamée : envoie
--     ClaimQuest(place)), Claimed (visible quand elle est réclamée) ; ClaimLabel « CLAIM », puis « DONE » ;
--   - Timer : « New quests in 12:34:56 » (prochain minuit UTC).
-- État lu sur les attributs du Player posés par QuestService (Config/Quests.Attributes). Le client ne décide rien :
-- il demande. Seuls sont touchés : Enabled de l'écran, les textes, Visible des lignes, de ClaimButton et de Claimed, la
-- taille X de Bar.Fill et l'image d'Icon ; jamais une couleur ni une position de Clément.
--
-- API (client) :
--   QuestController.Open()                       ouvre l'écran s'il est fermé
--   QuestController.GetState() -> { Open, Pending, Slots }   pour un test (banc, barre de commande)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Quests = require(Config:WaitForChild("Quests"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Icons = require(Shared:WaitForChild("Contract"):WaitForChild("Icons"))
local Format = require(Shared:WaitForChild("Format"))
local AlertBadge = require(Shared:WaitForChild("AlertBadge"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type Slot = {
	id: string?,
	progress: number,
	goal: number,
	claimed: boolean,
}

type Row = {
	slot: number,
	frame: GuiObject,
	name: Instance?,
	progress: Instance?,
	fill: GuiObject?,
	reward: Instance?,
	icon: Instance?,
	iconDefault: string?, -- image du Template
	claimButton: GuiObject?,
	claimLabel: Instance?,
	claimed: GuiObject?,
	shownId: string?, -- quête peinte (icône posée une fois par quête)
}

type Screen = {
	gui: ScreenGui,
	rows: { Row },
	timer: Instance?,
	connections: { RBXScriptConnection },
}

local SCREEN = "UI_Quests"
local HUD = "UI_HUD"
local HUD_BUTTON = "QuestsButton"
local HUD_ALERT = "QuestsAlert"
local ROW_FORMAT = "Quest_%d" -- nom des lignes clonées (jamais « Template »)
local ATTRIBUTES = Quests.Attributes
local MESSAGES = Quests.Messages
-- V0 proposé (Cantin, 20/11) : cadence (s) du minuteur et de la pastille.
local REFRESH = 0.25

local IS_STUDIO = RunService:IsStudio()

local QuestController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local net: any = nil
local reported: { [string]: boolean } = {}
local hudBound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local alerts: { GuiObject } = {}

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(`[Quests] {message}`)
	end
end

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function guiObject(root: Instance?, path: string): GuiObject?
	if root == nil then
		return nil
	end
	local found = Find.path(root, path)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

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

local function setVisible(element: GuiObject?, visible: boolean)
	if element and element.Visible ~= visible then
		element.Visible = visible
	end
end

local function isImage(inst: Instance?): boolean
	return inst ~= nil and (inst:IsA("ImageLabel") or inst:IsA("ImageButton"))
end

local function onClick(element: Instance?, handler: () -> ()): RBXScriptConnection?
	if element == nil then
		return nil
	end
	if element:IsA("GuiButton") then
		return Motion.Activated(element :: GuiButton):Connect(function()
			handler()
		end)
	end
	return nil
end

-- « 3:00 », « 12:34:56 ».
local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	local hours = whole // 3600
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, (whole % 3600) // 60, whole % 60)
	end
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Un objectif ou une progression écrits pour la quête (argent, durée ou nombre).
local function amountText(quest: Quests.Quest, value: number): string
	if quest.Event == "EarnCash" then
		return Format.money(value)
	elseif quest.Event == "Treadmill" then
		return clock(value)
	end
	return tostring(math.floor(value))
end

------------------------------------------------------------------------------
-- État lu sur les attributs de QuestService
------------------------------------------------------------------------------

local function readSlots(): { Slot }
	local slots: { Slot } = {}
	for slot = 1, Quests.PerDay do
		local id = localPlayer:GetAttribute(string.format(ATTRIBUTES.Id, slot))
		local progress = localPlayer:GetAttribute(string.format(ATTRIBUTES.Progress, slot))
		local goal = localPlayer:GetAttribute(string.format(ATTRIBUTES.Goal, slot))
		slots[slot] = {
			id = if type(id) == "string" and Quests.ById[id] ~= nil then id else nil,
			progress = if type(progress) == "number" then progress else 0,
			goal = if type(goal) == "number" and goal > 0 then goal else 1,
			claimed = localPlayer:GetAttribute(string.format(ATTRIBUTES.Claimed, slot)) == true,
		}
	end
	return slots
end

local function isReady(slot: Slot): boolean
	return slot.id ~= nil and not slot.claimed and slot.progress >= slot.goal
end

local function hasPending(slots: { Slot }): boolean
	for _, slot in slots do
		if isReady(slot) then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Peinture
------------------------------------------------------------------------------

local function paintRow(row: Row, slot: Slot)
	local quest = if slot.id then Quests.ById[slot.id] else nil
	setVisible(row.frame, quest ~= nil)
	if quest == nil then
		return
	end
	local goalText = amountText(quest, slot.goal)
	setText(row.name, string.format(quest.Text, goalText))
	setText(row.progress, string.format(MESSAGES.ProgressFormat, amountText(quest, math.min(slot.progress, slot.goal)), goalText))
	setText(row.reward, quest.RewardText)
	local fill = row.fill
	if fill then
		local ratio = math.clamp(slot.progress / slot.goal, 0, 1)
		local size = fill.Size
		if math.abs(size.X.Scale - ratio) > 1e-3 or size.X.Offset ~= 0 then
			fill.Size = UDim2.new(ratio, 0, size.Y.Scale, size.Y.Offset)
		end
	end
	if row.shownId ~= quest.Id then
		row.shownId = quest.Id
		local texture = if quest.Icon then Icons.get(quest.Icon) else nil
		if isImage(row.icon) then
			(row.icon :: any).Image = texture or row.iconDefault or ""
		end
	end
	local ready = isReady(slot)
	setVisible(row.claimButton, ready)
	setVisible(row.claimed, slot.claimed)
	setText(row.claimLabel, if slot.claimed then MESSAGES.ClaimedText else MESSAGES.ClaimText)
end

local function refresh()
	if not Features.Quests then
		return
	end
	local slots = readSlots()
	local pending = hasPending(slots)
	for index = #alerts, 1, -1 do
		local alert = alerts[index]
		if alert.Parent == nil then
			table.remove(alerts, index)
		else
			AlertBadge.Set(alert, pending)
		end
	end
	local current = screen
	if current and isOpen and current.gui.Parent ~= nil then
		for _, row in current.rows do
			paintRow(row, slots[row.slot])
		end
		local endsAt = localPlayer:GetAttribute(ATTRIBUTES.EndsAt)
		if type(endsAt) == "number" then
			setText(current.timer, string.format(MESSAGES.Timer, clock(endsAt - Workspace:GetServerTimeNow())))
		end
	end
end

------------------------------------------------------------------------------
-- Écran
------------------------------------------------------------------------------

local function claim(slot: number)
	local slots = readSlots()
	if net == nil or slots[slot] == nil or not isReady(slots[slot]) then
		return
	end
	net.Client.ClaimQuest:Fire(slot)
end

local function close()
	isOpen = false
	local current = screen
	if current then
		Motion.Close(current.gui)
	end
end

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
	end
	isOpen = false
	gui.Enabled = false -- fermé jusqu'au bouton du HUD
	Motion.SetCloser(gui, close)
	local current: Screen = {
		gui = gui,
		rows = {},
		timer = Find.path(gui, "Timer"),
		connections = {},
	}
	screen = current
	local closeConnection = onClick(Find.path(gui, "CloseButton"), close)
	if closeConnection then
		table.insert(current.connections, closeConnection)
	end
	local template = guiObject(gui, "List.Template")
	if template == nil then
		reportOnce("template", `{SCREEN}.List.Template introuvable : aucune quête affichée`)
		return
	end
	template.Visible = false
	local parent = template.Parent
	local templateIcon = Find.path(template, "Icon")
	for slot = 1, Quests.PerDay do
		local clone: Instance? = template:Clone()
		if clone == nil then
			return -- Archivable = false : rien à cloner
		end
		local frame = clone :: GuiObject
		frame.Name = string.format(ROW_FORMAT, slot)
		frame.LayoutOrder = slot
		local claimButton = guiObject(frame, "ClaimButton")
		local row: Row = {
			slot = slot,
			frame = frame,
			name = Find.path(frame, "QuestName"),
			progress = Find.path(frame, "ProgressLabel"),
			fill = guiObject(frame, "Bar.Fill"),
			reward = Find.path(frame, "RewardLabel"),
			icon = Find.path(frame, "Icon"),
			iconDefault = if isImage(templateIcon) then (templateIcon :: any).Image else nil,
			claimButton = claimButton,
			claimLabel = if claimButton then Find.path(claimButton, "ClaimLabel") else nil,
			claimed = guiObject(frame, "Claimed"),
			shownId = nil,
		}
		local connection = onClick(claimButton, function()
			claim(slot)
		end)
		if connection then
			table.insert(current.connections, connection)
		end
		frame.Visible = false -- montrée par refresh quand la place a une quête
		frame.Parent = parent
		table.insert(current.rows, row)
	end
end

local function currentScreen(): Screen?
	local current = screen
	if current and current.gui.Parent ~= nil then
		return current
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild(SCREEN) else nil
	if gui and gui:IsA("ScreenGui") then
		bind(gui :: ScreenGui)
		return screen
	end
	return nil
end

local function open()
	if not Features.Quests then
		return
	end
	local current = currentScreen()
	if current == nil then
		reportOnce("screen", `écran {SCREEN} absent de PlayerGui : les quêtes ne s'ouvrent pas`)
		return
	end
	isOpen = true
	refresh()
	Motion.Open(current.gui)
end

local function toggle()
	if isOpen then
		close()
	else
		open()
	end
end

local function bindHud(gui: Instance)
	if hudBound[gui] then
		return
	end
	hudBound[gui] = true
	for _, found in Find.all(gui, HUD_BUTTON) do
		if found:IsA("GuiButton") then
			local alert = guiObject(found, HUD_ALERT)
			if alert then
				table.insert(alerts, alert)
			end
			Motion.Activated(found :: GuiButton):Connect(toggle)
		end
	end
	refresh()
end

function QuestController.Open()
	if not isOpen then
		open()
	end
end

function QuestController.GetState(): { Open: boolean, Pending: boolean, Slots: { Slot } }
	local slots = readSlots()
	return { Open = isOpen, Pending = hasPending(slots), Slots = slots }
end

function QuestController.Start()
	if not Features.Quests then
		return -- coupé : rien n'est branché (HudController cache QuestsButton)
	end
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui)
		elseif child.Name == HUD and child:IsA("ScreenGui") then
			bindHud(child)
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
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < REFRESH then
			return
		end
		elapsed = 0
		refresh()
	end)
	refresh()
end

return QuestController
