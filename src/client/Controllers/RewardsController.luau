--!strict
-- RewardsController (DEV-101, client) : écran des récompenses UI_Rewards de Clément (L-057 ; Partie 2,
-- section 3.3 ; règles : Config/Rewards ; serveur : RewardService). Onglets Daily (calendrier de 7 jours)
-- et Playtime (paliers de temps de jeu du jour) ; pas d'onglet pour le coffre hebdomadaire (MAJ 1).
--
-- Rôle :
--   - UI_HUD.RewardsButton ouvre l'écran (un 2e appui le ferme) ; CloseButton le ferme. Ouverture et
--     fermeture par UI/Motion ; l'écran est du groupe « Menu » (attribut ScreenGroup de Clément) : en
--     ouvrir un autre le ferme (Motion.SetCloser), et inversement ;
--   - RewardsAlert (pastille rouge dans RewardsButton) visible quand une récompense attend : le jour
--     d'aujourd'hui pas encore réclamé, ou un palier de temps de jeu atteint et pas réclamé ;
--   - onglets Tabs.DailyTab et Tabs.PlaytimeTab : la page DailyPage ou PlaytimePage visible, l'image
--     Selected visible sur l'onglet choisi seulement. À la première ouverture, Daily ; ensuite, le dernier
--     onglet choisi ;
--   - Daily : Streak.Day1 à Day7, Today visible sur le jour d'aujourd'hui seulement, Claimed visible sur
--     les jours déjà réclamés de ce cycle (avant aujourd'hui, et aujourd'hui une fois réclamé). Les textes
--     de Clément (DayLabel, RewardName) ne sont pas touchés. DailyClaimButton : envoie ClaimDaily quand le
--     jour n'est pas réclamé ; ClaimLabel « CLAIM » (le texte de Clément), puis « CLAIMED » (un clic ne
--     fait alors rien) ;
--   - Playtime : une ligne par palier de Config/Rewards.Playtime, clonée depuis List.Template et nommée
--     Tier_<minutes> (LayoutOrder = rang). RewardName « Gift at 5 min » (le format du Template de
--     Clément), Icon gardée telle quelle ; si la ligne d'exemple Preview_<rang> de Clément existe, son
--     texte RewardName et l'image de son Icon sont repris pour ce palier, puis les Preview_* sont retirées
--     de la copie du joueur (comme NotifyController). Par ligne : pas atteint → Timer = temps restant
--     (« 12:34 », « 1:02:03 »), ClaimButton et Claimed cachés ; atteint → Timer « Ready! », ClaimButton
--     visible (envoie ClaimPlaytime(minutes)) ; réclamé → Timer « CLAIMED », Claimed visible, ClaimButton
--     caché.
-- État lu sur les attributs du Player posés par RewardService (Config/Rewards.Attributes) : jour du
-- calendrier, réclamé aujourd'hui, heure serveur du temps de jeu à 0 (le client compte
-- GetServerTimeNow() − RewardPlayStart), paliers réclamés. Le client ne décide rien : il demande.
-- Seuls sont touchés (2.2, « Libre pour Ironix ») : Enabled de l'écran, les textes, la visibilité, les
-- lignes clonées (nom, ordre) et l'image de leur Icon reprise d'une Preview ; jamais une couleur, une
-- taille ni une position de Clément. Écran recréé (ResetOnSpawn) : rebranché, fermé.
--
-- API (client) :
--   RewardsController.GetState() -> { Open, Tab, Day, DailyClaimed, PlaySeconds, Pending }
--       Pour un test (banc, barre de commande en Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Rewards = require(Config:WaitForChild("Rewards"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type Tab = "Daily" | "Playtime"

-- Une ligne de palier clonée.
type Row = {
	minutes: number,
	frame: GuiObject,
	timer: Instance?,
	claimButton: GuiObject?,
	claimed: GuiObject?,
}

-- Un jour du calendrier.
type DayFrame = {
	today: GuiObject?,
	claimed: GuiObject?,
}

-- Écran branché.
type Screen = {
	gui: ScreenGui,
	dailyPage: GuiObject?,
	playtimePage: GuiObject?,
	dailySelected: GuiObject?,
	playtimeSelected: GuiObject?,
	days: { DayFrame },
	claimLabel: Instance?,
	claimText: string, -- texte de ClaimLabel posé par Clément (« CLAIM »)
	rows: { Row },
	connections: { RBXScriptConnection },
}

local SCREEN = "UI_Rewards"
local HUD = "UI_HUD"
local HUD_BUTTON = "RewardsButton"
local HUD_ALERT = "RewardsAlert"
local ROW_FORMAT = "Tier_%d" -- nom des lignes clonées (jamais « Template »)
local PREVIEW_PREFIX = "Preview_"
local ATTRIBUTES = Rewards.Attributes

-- Textes, en anglais (L-036). V0 proposés, absents du doc, sauf « Ready! », « CLAIMED » et le format
-- « Gift at 5 min », repris de la maquette de Clément.
local GIFT_TEXT = "Gift at %d min"
local READY_TEXT = "Ready!"
local CLAIMED_TEXT = "CLAIMED"
local CLAIM_TEXT = "CLAIM" -- si ClaimLabel n'a pas de texte
-- V0 proposé, absent du doc : cadence (s) des minuteurs et de la pastille.
local REFRESH = 0.25

local IS_STUDIO = RunService:IsStudio()

local RewardsController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local tab: Tab = "Daily"
local net: any = nil
local reported: { [string]: boolean } = {}
local hudBound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local alerts: { GuiObject } = {}

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(`[Rewards] {message}`)
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

local function textOf(element: Instance?): string?
	local holder = textHolder(element)
	local text = if holder then (holder :: any).Text else nil
	return if type(text) == "string" and text ~= "" then text else nil
end

local function setVisible(element: GuiObject?, visible: boolean)
	if element and element.Visible ~= visible then
		element.Visible = visible
	end
end

local function isImage(inst: Instance?): boolean
	return inst ~= nil and (inst:IsA("ImageLabel") or inst:IsA("ImageButton"))
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

-- « 12:34 », « 1:02:03 » : temps restant avant un palier.
local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	local hours = whole // 3600
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, (whole % 3600) // 60, whole % 60)
	end
	return string.format("%d:%02d", whole // 60, whole % 60)
end

------------------------------------------------------------------------------
-- État lu sur les attributs de RewardService
------------------------------------------------------------------------------

type Status = {
	known: boolean, -- attributs posés (profil chargé)
	day: number,
	dailyClaimed: boolean,
	playSeconds: number,
	playClaimed: { [number]: boolean },
}

local function readStatus(): Status
	local day = localPlayer:GetAttribute(ATTRIBUTES.Day)
	local start = localPlayer:GetAttribute(ATTRIBUTES.PlayStart)
	local claimedText = localPlayer:GetAttribute(ATTRIBUTES.PlayClaimed)
	local claimed: { [number]: boolean } = {}
	if type(claimedText) == "string" then
		for word in string.gmatch(claimedText, "[^,]+") do
			local minutes = tonumber(word)
			if minutes then
				claimed[minutes] = true
			end
		end
	end
	local known = type(day) == "number" and type(start) == "number"
	return {
		known = known,
		day = if type(day) == "number" then day else 1,
		dailyClaimed = localPlayer:GetAttribute(ATTRIBUTES.DailyClaimed) == true,
		playSeconds = if type(start) == "number" then math.max(0, Workspace:GetServerTimeNow() - start) else 0,
		playClaimed = claimed,
	}
end

-- Une récompense attend : le jour pas réclamé, ou un palier atteint et pas réclamé.
local function hasPending(status: Status): boolean
	if not status.known then
		return false
	end
	if not status.dailyClaimed then
		return true
	end
	for _, tier in Rewards.Playtime do
		if not status.playClaimed[tier.Minutes] and status.playSeconds >= tier.Minutes * 60 then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Peinture
------------------------------------------------------------------------------

local function paintTabs(current: Screen)
	setVisible(current.dailyPage, tab == "Daily")
	setVisible(current.playtimePage, tab == "Playtime")
	setVisible(current.dailySelected, tab == "Daily")
	setVisible(current.playtimeSelected, tab == "Playtime")
end

local function paintDaily(current: Screen, status: Status)
	for index, dayFrame in current.days do
		setVisible(dayFrame.today, index == status.day)
		setVisible(dayFrame.claimed, index < status.day or (index == status.day and status.dailyClaimed))
	end
	setText(current.claimLabel, if status.dailyClaimed then CLAIMED_TEXT else current.claimText)
end

local function paintRows(current: Screen, status: Status)
	for _, row in current.rows do
		local claimed = status.playClaimed[row.minutes] == true
		local left = row.minutes * 60 - status.playSeconds
		local ready = not claimed and left <= 0
		setVisible(row.claimButton, ready)
		setVisible(row.claimed, claimed)
		setText(row.timer, if claimed then CLAIMED_TEXT elseif ready then READY_TEXT else clock(left))
	end
end

local function refresh()
	local status = readStatus()
	local pending = hasPending(status)
	for index = #alerts, 1, -1 do
		local alert = alerts[index]
		if alert.Parent == nil then
			table.remove(alerts, index)
		else
			setVisible(alert, pending)
		end
	end
	local current = screen
	if current and isOpen then
		paintDaily(current, status)
		paintRows(current, status)
	end
end

------------------------------------------------------------------------------
-- Réclamations
------------------------------------------------------------------------------

local function claimDaily()
	local status = readStatus()
	if not status.known or status.dailyClaimed or net == nil then
		return
	end
	net.Client.ClaimDaily:Fire()
end

local function claimPlaytime(minutes: number)
	local status = readStatus()
	if not status.known or status.playClaimed[minutes] or status.playSeconds < minutes * 60 or net == nil then
		return
	end
	net.Client.ClaimPlaytime:Fire(minutes)
end

------------------------------------------------------------------------------
-- Écran
------------------------------------------------------------------------------

local function close()
	isOpen = false
	local current = screen
	if current then
		Motion.Close(current.gui)
	end
end

local function selectTab(current: Screen, wanted: Tab)
	tab = wanted
	if screen == current then
		paintTabs(current)
		refresh()
	end
end

-- Lignes des paliers, clonées une fois par écran depuis List.Template.
local function buildRows(current: Screen, template: GuiObject, previews: { [number]: Instance })
	local parent = template.Parent
	for rank, tier in Rewards.Playtime do
		local clone: Instance? = template:Clone()
		if clone == nil then
			return -- Archivable = false : rien à cloner
		end
		local frame = clone :: GuiObject
		frame.Name = string.format(ROW_FORMAT, tier.Minutes)
		frame.LayoutOrder = rank
		local preview = previews[rank]
		local name = Find.path(frame, "RewardName")
		setText(name, (if preview then textOf(Find.path(preview, "RewardName")) else nil) or string.format(GIFT_TEXT, tier.Minutes))
		local icon = Find.path(frame, "Icon")
		local previewIcon = if preview then Find.path(preview, "Icon") else nil
		if isImage(icon) and isImage(previewIcon) then
			(icon :: any).Image = (previewIcon :: any).Image
		end
		local row: Row = {
			minutes = tier.Minutes,
			frame = frame,
			timer = Find.path(frame, "Timer"),
			claimButton = guiObject(frame, "ClaimButton"),
			claimed = guiObject(frame, "Claimed"),
		}
		local minutes = tier.Minutes
		local connection = onClick(row.claimButton, function()
			claimPlaytime(minutes)
		end)
		if connection then
			table.insert(current.connections, connection)
		end
		frame.Visible = true
		frame.Parent = parent
		table.insert(current.rows, row)
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
	Motion.SetCloser(gui, close) -- un autre écran du groupe ScreenGroup s'ouvre (L-089)

	local tabs = Find.path(gui, "Tabs")
	local dailyTab = if tabs then Find.path(tabs, "DailyTab") else nil
	local playtimeTab = if tabs then Find.path(tabs, "PlaytimeTab") else nil
	local dailyPage = guiObject(gui, "DailyPage")
	local claimButton = if dailyPage then Find.path(dailyPage, "DailyClaimButton") else nil
	local claimLabel = if claimButton then Find.path(claimButton, "ClaimLabel") else nil
	local current: Screen = {
		gui = gui,
		dailyPage = dailyPage,
		playtimePage = guiObject(gui, "PlaytimePage"),
		dailySelected = guiObject(dailyTab, "Selected"),
		playtimeSelected = guiObject(playtimeTab, "Selected"),
		days = {},
		claimLabel = claimLabel or claimButton,
		claimText = textOf(claimLabel or claimButton) or CLAIM_TEXT,
		rows = {},
		connections = {},
	}
	screen = current
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	for index = 1, #Rewards.Daily do
		local dayFrame = if dailyPage then Find.path(dailyPage, `Streak.Day{index}`) else nil
		if dayFrame == nil then
			reportOnce(`day:{index}`, `{SCREEN}.DailyPage.Streak.Day{index} introuvable`)
		end
		current.days[index] = { today = guiObject(dayFrame, "Today"), claimed = guiObject(dayFrame, "Claimed") }
	end
	if claimButton == nil then
		reportOnce("dailyClaim", `{SCREEN}.DailyPage.DailyClaimButton introuvable : le jour ne se réclame pas`)
	end
	keep(onClick(claimButton, claimDaily))
	keep(onClick(Find.path(gui, "CloseButton"), close))
	keep(onClick(dailyTab, function()
		selectTab(current, "Daily")
	end))
	keep(onClick(playtimeTab, function()
		selectTab(current, "Playtime")
	end))

	local template = guiObject(current.playtimePage or gui, "List.Template")
	if template == nil then
		reportOnce("template", `{SCREEN}.PlaytimePage.List.Template introuvable : aucun palier de temps de jeu`)
	else
		template.Visible = false
		-- Lignes d'exemple de Clément (Preview_<n>, à côté du Template) : texte et icône repris pour le
		-- palier de même rang, puis retirées de la copie du joueur.
		local previews: { [number]: Instance } = {}
		local siblings = (template.Parent :: Instance):GetChildren()
		for _, sibling in siblings do
			if string.sub(sibling.Name, 1, #PREVIEW_PREFIX) == PREVIEW_PREFIX then
				local rank = tonumber(string.sub(sibling.Name, #PREVIEW_PREFIX + 1))
				if rank then
					previews[rank] = sibling
				end
			end
		end
		buildRows(current, template, previews)
		for _, sibling in siblings do
			if string.sub(sibling.Name, 1, #PREVIEW_PREFIX) == PREVIEW_PREFIX then
				sibling:Destroy()
			end
		end
	end
	paintTabs(current)
end

-- Écran branché encore présent, ou celui de PlayerGui (branché au passage), ou nil.
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
	local current = currentScreen()
	if current == nil then
		reportOnce("screen", `écran {SCREEN} absent de PlayerGui : les récompenses ne s'ouvrent pas`)
		return
	end
	isOpen = true
	paintTabs(current)
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

------------------------------------------------------------------------------
-- Bouton du HUD
------------------------------------------------------------------------------

local function bindHud(gui: Instance)
	if hudBound[gui] then
		return
	end
	local found = Find.path(gui, HUD_BUTTON)
	if found == nil or not found:IsA("GuiButton") then
		reportOnce("hud", `{HUD}.{HUD_BUTTON} introuvable ou pas un bouton : les récompenses ne s'ouvrent pas`)
		return
	end
	hudBound[gui] = true
	local alert = guiObject(found, HUD_ALERT)
	if alert then
		table.insert(alerts, alert)
	else
		reportOnce("alert", `{HUD}.{HUD_BUTTON}.{HUD_ALERT} introuvable : pas de pastille`)
	end
	(found :: GuiButton).Activated:Connect(toggle)
	refresh()
end

function RewardsController.GetState(): { Open: boolean, Tab: string, Day: number, DailyClaimed: boolean, PlaySeconds: number, Pending: boolean }
	local status = readStatus()
	return {
		Open = isOpen,
		Tab = tab,
		Day = status.day,
		DailyClaimed = status.dailyClaimed,
		PlaySeconds = status.playSeconds,
		Pending = hasPending(status),
	}
end

function RewardsController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any

	for _, name in { ATTRIBUTES.Day, ATTRIBUTES.DailyClaimed, ATTRIBUTES.PlayStart, ATTRIBUTES.PlayClaimed } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	end
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

return RewardsController
