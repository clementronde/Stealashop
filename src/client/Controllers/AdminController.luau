--!strict
-- AdminController (vague 29, liaison L-108 point 4 ; client) : le panel admin, écran UI_Admin et bouton
-- UI_HUD.AdminButton de Clément (docs/claude/notes/ui-admin.md). Le serveur (AdminService) décide de tout : qui est
-- admin, chaque commande et chaque argument. Ce contrôleur n'envoie que des Id et des nombres (remote
-- AdminCommand, Config/Admin) et affiche la réponse (AdminResult) dans Root.StatusLabel.
--
--   - AdminButton (caché par Clément) : montré seulement quand le serveur a posé l'attribut IsAdmin = true sur le
--     joueur ; il ouvre et ferme UI_Admin (UI/Motion, groupe ScreenGroup « Menu », Motion.SetCloser). Attribut
--     retiré : bouton caché, écran fermé. Vague 38 (L-135 point 3) : caché aussi tant qu'un autre écran le demande
--     (SetHidden ; PawnShopController pendant le dialogue UI_PawnShop.Dialog, qui passait dessus), remontré ensuite.
--   - Listes (PlayerList, ChoiceList, MutationList, EventList, ZoneList) : une copie du Template caché par entrée,
--     EntryName = le texte, Selected allumé sur l'entrée choisie ; entrées de Shared/AdminLists (Config), joueurs
--     de Players (tenus à jour pendant que l'écran existe).
--   - TargetSection : le joueur choisi est la cible de toutes les actions ; soi-même par défaut (TargetLabel
--     « Target: you »). Joueur parti : retour à soi.
--   - StatsSection et BaseSection : le nombre tapé dans la boîte (« 1.5M », « 2B », « 10,000 » acceptés) part
--     avec la commande du bouton (GiveCash, GiveSpeed, GiveStrength, SetTreadmill, SetBench, SetShopLevel,
--     SetRayons).
--   - GiveSection : KindRow choisit la sorte (Selected allumé), SearchBox filtre ChoiceList, MutationTitle et
--     MutationList ne sont montrés que pour un objet ; GiveButton envoie GiveItem, GiveBox, GiveAura, GiveTrail,
--     GivePotion ou GiveGamepass.
--   - EventList : un clic lance l'événement (StartEvent) ; ZoneList : un clic téléporte la cible (Teleport).
--   - ResetProfileButton : premier clic, StatusLabel « Click again to confirm » ; second clic dans les
--     RESET_WINDOW s, ResetProfile part avec le mot de confirmation.
-- Ce qui est touché dans l'écran de Clément : Enabled, Visible de AdminButton, des Selected, de MutationTitle /
-- MutationList et des copies de Template, les textes de StatusLabel, TargetLabel et EntryName. Écran recréé
-- (ResetOnSpawn) : rebranché, fermé.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Admin = require(Shared:WaitForChild("Config"):WaitForChild("Admin"))
local AdminLists = require(Shared:WaitForChild("AdminLists"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type Entry = AdminLists.Entry

-- Une liste de l'écran : son Template et les copies posées.
type List = {
	template: GuiButton,
	copies: { GuiButton },
}

type Screen = {
	gui: ScreenGui,
	connections: { RBXScriptConnection },
	status: TextLabel?,
	targetLabel: TextLabel?,
	players: List?,
	choices: List?,
	mutations: List?,
	mutationTitle: GuiObject?,
	search: TextBox?,
	kindButtons: { [string]: GuiButton },
	resetLabel: TextLabel?,
	resetText: string?,
}

local SCREEN = "UI_Admin"
local HUD = "UI_HUD"
local HUD_BUTTON = "AdminButton"
local ADMIN_ATTRIBUTE = "IsAdmin"
local RESET_WINDOW = 5 -- V0 : secondes pour le second clic de ResetProfileButton

-- Sortes de GiveSection : bouton de KindRow, liste de AdminLists, commande.
local KINDS: { { button: string, list: string, command: string } } = {
	{ button = "ItemKindButton", list = "Items", command = "GiveItem" },
	{ button = "BoxKindButton", list = "Boxes", command = "GiveBox" },
	{ button = "AuraKindButton", list = "Auras", command = "GiveAura" },
	{ button = "TrailKindButton", list = "Trails", command = "GiveTrail" },
	{ button = "PotionKindButton", list = "Potions", command = "GivePotion" },
	{ button = "GamepassKindButton", list = "Gamepasses", command = "GiveGamepass" },
}

-- Boutons des lignes : boîte lue, commande envoyée.
local ROWS: { { button: string, box: string, command: string } } = {
	{ button = "GiveCashButton", box = "CashBox", command = "GiveCash" },
	{ button = "GiveSpeedButton", box = "SpeedBox", command = "GiveSpeed" },
	{ button = "GiveStrengthButton", box = "StrengthBox", command = "GiveStrength" },
	{ button = "SetTreadmillButton", box = "TreadmillBox", command = "SetTreadmill" },
	{ button = "SetBenchButton", box = "BenchBox", command = "SetBench" },
	{ button = "SetShopLevelButton", box = "ShopLevelBox", command = "SetShopLevel" },
	{ button = "SetRayonsButton", box = "RayonsBox", command = "SetRayons" },
}

local SUFFIXES: { [string]: number } = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }

local IS_STUDIO = RunService:IsStudio()

local AdminController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local screen: Screen? = nil
local isOpen = false
local target: Player? = nil -- nil = soi
local kindIndex = 1
local choiceId: string? = nil
local mutationId = ""
local resetArmedAt: number? = nil
local hudButton: GuiButton? = nil
local hiddenBy: { [string]: boolean } = {} -- vague 38 : écrans qui cachent AdminButton (SetHidden)
local reported: { [string]: boolean } = {}

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		warn(message)
	end
end

local function isAdmin(): boolean
	return localPlayer:GetAttribute(ADMIN_ATTRIBUTE) == true
end

-- « 1.5M » → 1 500 000 ; nil si illisible.
function AdminController.ParseNumber(text: string): number?
	local clean = string.lower((string.gsub(text, "[%s,_%$]", "")))
	local digits, suffix = string.match(clean, "^([%d%.]+)(%a?)$")
	local value = if digits then tonumber(digits) else nil
	if value == nil then
		return nil
	end
	if suffix ~= nil and suffix ~= "" then
		local factor = SUFFIXES[suffix]
		if factor == nil then
			return nil
		end
		value *= factor
	end
	return value
end

------------------------------------------------------------------------------
-- Statut et envoi
------------------------------------------------------------------------------

local function setStatus(text: string)
	local current = screen
	local label = if current then current.status else nil
	if label then
		label.Text = text
	end
end

local function targetOrNil(): Player?
	local chosen = target
	if chosen ~= nil and chosen.Parent == Players and chosen ~= localPlayer then
		return chosen
	end
	return nil
end

local function send(commandId: string, value: number?, text: string?, text2: string?)
	if net == nil then
		setStatus("Admin remote unavailable.")
		return
	end
	local command = Admin.ById[commandId]
	local who = if command and command.Target then targetOrNil() else nil
	setStatus(Admin.Messages.Sent)
	net.Client.AdminCommand:Fire(commandId, who, value, text, text2)
end

------------------------------------------------------------------------------
-- Listes
------------------------------------------------------------------------------

local function listOf(gui: Instance, path: string): List?
	local found = Find.path(gui, path)
	if found == nil or not found:IsA("GuiButton") then
		reportOnce(`list:{path}`, `[Admin] {SCREEN}.{path} introuvable ou pas un bouton : liste vide`)
		return nil
	end
	local template = found :: GuiButton
	template.Visible = false
	return { template = template, copies = {} }
end

local function setSelected(button: GuiButton, on: boolean)
	local selected = button:FindFirstChild("Selected", true)
	if selected and selected:IsA("GuiObject") then
		(selected :: GuiObject).Visible = on
	end
end

-- Remplace les copies de `list` par une par entrée ; `isChosen(id)` allume Selected ; `onClick(id)`.
local function fill(current: Screen, list: List?, entries: { Entry }, isChosen: (string) -> boolean, onClick: (string) -> ())
	if list == nil then
		return
	end
	for _, copy in list.copies do
		copy:Destroy()
	end
	table.clear(list.copies)
	for index, entry in entries do
		local copy = list.template:Clone()
		copy.Name = `Entry_{index}`
		copy.LayoutOrder = index
		local label = copy:FindFirstChild("EntryName", true)
		if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
			(label :: any).Text = entry.Label
		end
		setSelected(copy, isChosen(entry.Id))
		copy:SetAttribute("EntryId", entry.Id)
		copy.Visible = true
		copy.Parent = list.template.Parent
		table.insert(current.connections, copy.Activated:Connect(function()
			onClick(entry.Id)
		end))
		table.insert(list.copies, copy)
	end
end

local function repaintSelection(list: List?, isChosen: (string) -> boolean)
	if list == nil then
		return
	end
	for _, copy in list.copies do
		local id = copy:GetAttribute("EntryId")
		setSelected(copy, type(id) == "string" and isChosen(id))
	end
end

local refreshPlayers: (Screen) -> ()

local function chooseTarget(current: Screen, id: string)
	local userId = tonumber(id)
	local chosen: Player? = nil
	for _, player in Players:GetPlayers() do
		if player.UserId == userId then
			chosen = player
		end
	end
	target = if chosen == localPlayer then nil else chosen
	refreshPlayers(current)
end

refreshPlayers = function(current: Screen)
	local chosen = targetOrNil()
	target = chosen
	local label = current.targetLabel
	if label then
		label.Text = if chosen then string.format(Admin.Messages.TargetOther, chosen.Name) else Admin.Messages.TargetSelf
	end
	local entries: { Entry } = { { Id = tostring(localPlayer.UserId), Label = `{localPlayer.Name} (you)` } }
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer then
			table.insert(entries, { Id = tostring(player.UserId), Label = player.Name })
		end
	end
	local selectedId = tostring(if chosen then chosen.UserId else localPlayer.UserId)
	fill(current, current.players, entries, function(id: string): boolean
		return id == selectedId
	end, function(id: string)
		chooseTarget(current, id)
	end)
end

local function refreshChoices(current: Screen)
	local kind = KINDS[kindIndex]
	for index, info in KINDS do
		local button = current.kindButtons[info.button]
		if button then
			setSelected(button, index == kindIndex)
		end
	end
	local isItem = kind.list == "Items"
	if current.mutationTitle then
		(current.mutationTitle :: GuiObject).Visible = isItem
	end
	local mutationFrame = if current.mutations then current.mutations.template.Parent else nil
	if mutationFrame and mutationFrame:IsA("GuiObject") then
		mutationFrame.Visible = isItem
	end
	local query = string.lower(if current.search then current.search.Text else "")
	local entries: { Entry } = {}
	for _, entry in AdminLists.Entries(kind.list) do
		if query == "" or string.find(string.lower(entry.Label), query, 1, true) or string.find(string.lower(entry.Id), query, 1, true) then
			table.insert(entries, entry)
		end
	end
	local function isChosen(id: string): boolean
		return id == choiceId
	end
	fill(current, current.choices, entries, isChosen, function(id: string)
		choiceId = id
		repaintSelection(current.choices, isChosen)
	end)
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

local function onActivated(current: Screen, path: string, handler: () -> ())
	local found = Find.path(current.gui, path)
	if found == nil or not found:IsA("GuiButton") then
		reportOnce(`button:{path}`, `[Admin] {SCREEN}.{path} introuvable ou pas un bouton : pas branché`)
		return
	end
	table.insert(current.connections, (found :: GuiButton).Activated:Connect(function()
		handler()
	end))
end

local function textBox(gui: Instance, name: string): TextBox?
	local found = Find.path(gui, name)
	return if found and found:IsA("TextBox") then found :: TextBox else nil
end

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
	end
	isOpen = false
	resetArmedAt = nil
	gui.Enabled = false -- fermé jusqu'au bouton du HUD
	Motion.SetCloser(gui, close)

	local status = Find.path(gui, "StatusLabel")
	local targetLabel = Find.path(gui, "TargetLabel")
	local mutationTitle = Find.path(gui, "MutationTitle")
	local resetButton = Find.path(gui, "ResetProfileButton")
	local resetLabel = if resetButton then resetButton:FindFirstChild("Label", true) else nil
	local current: Screen = {
		gui = gui,
		connections = {},
		status = if status and status:IsA("TextLabel") then status :: TextLabel else nil,
		targetLabel = if targetLabel and targetLabel:IsA("TextLabel") then targetLabel :: TextLabel else nil,
		players = listOf(gui, "PlayerList.Template"),
		choices = listOf(gui, "ChoiceList.Template"),
		mutations = listOf(gui, "MutationList.Template"),
		mutationTitle = if mutationTitle and mutationTitle:IsA("GuiObject") then mutationTitle :: GuiObject else nil,
		search = textBox(gui, "SearchBox"),
		kindButtons = {},
		resetLabel = if resetLabel and resetLabel:IsA("TextLabel") then resetLabel :: TextLabel else nil,
		resetText = nil,
	}
	current.resetText = if current.resetLabel then current.resetLabel.Text else nil
	screen = current
	setStatus(Admin.Messages.Ready)

	onActivated(current, "CloseButton", close)

	for _, row in ROWS do
		local box = textBox(gui, row.box)
		onActivated(current, row.button, function()
			local value = if box then AdminController.ParseNumber(box.Text) else nil
			if value == nil then
				setStatus("Type a number first.")
				return
			end
			send(row.command, value)
		end)
	end

	for index, info in KINDS do
		local found = Find.path(gui, info.button)
		if found and found:IsA("GuiButton") then
			current.kindButtons[info.button] = found :: GuiButton
			table.insert(current.connections, (found :: GuiButton).Activated:Connect(function()
				if kindIndex ~= index then
					kindIndex = index
					choiceId = nil
					refreshChoices(current)
				end
			end))
		else
			reportOnce(`kind:{info.button}`, `[Admin] {SCREEN}.{info.button} introuvable : sorte pas branchée`)
		end
	end
	local search = current.search
	if search then
		table.insert(current.connections, search:GetPropertyChangedSignal("Text"):Connect(function()
			refreshChoices(current)
		end))
	end
	local function mutationChosen(id: string): boolean
		return id == mutationId
	end
	fill(current, current.mutations, AdminLists.Entries("Mutations"), mutationChosen, function(id: string)
		mutationId = id
		repaintSelection(current.mutations, mutationChosen)
	end)
	onActivated(current, "GiveButton", function()
		local kind = KINDS[kindIndex]
		local chosen = choiceId
		if chosen == nil then
			setStatus("Pick something to give first.")
			return
		end
		if kind.list == "Items" and mutationId ~= "" then
			send(kind.command, nil, chosen, mutationId)
		else
			send(kind.command, nil, chosen)
		end
	end)

	fill(current, listOf(gui, "EventList.Template"), AdminLists.Entries("Events"), function(_id: string): boolean
		return false
	end, function(id: string)
		send("StartEvent", nil, id)
	end)
	fill(current, listOf(gui, "ZoneList.Template"), AdminLists.Entries("Zones"), function(_id: string): boolean
		return false
	end, function(id: string)
		send("Teleport", tonumber(id))
	end)

	onActivated(current, "ResetProfileButton", function()
		local now = os.clock()
		local armed = resetArmedAt
		if armed ~= nil and now - armed <= RESET_WINDOW then
			resetArmedAt = nil
			if current.resetLabel and current.resetText then
				current.resetLabel.Text = current.resetText
			end
			send("ResetProfile", nil, Admin.ResetConfirm)
			return
		end
		resetArmedAt = now
		setStatus(Admin.Messages.ConfirmReset)
		if current.resetLabel then
			current.resetLabel.Text = Admin.Messages.ConfirmReset
		end
		task.delay(RESET_WINDOW, function()
			if resetArmedAt == now then
				resetArmedAt = nil
				if current.resetLabel and current.resetText then
					current.resetLabel.Text = current.resetText
				end
			end
		end)
	end)

	table.insert(current.connections, Players.PlayerAdded:Connect(function()
		refreshPlayers(current)
	end))
	table.insert(current.connections, Players.PlayerRemoving:Connect(function(player: Player)
		if player == target then
			target = nil
		end
		task.defer(refreshPlayers, current)
	end))
	refreshPlayers(current)
	refreshChoices(current)
end

local function open()
	if not isAdmin() then
		return
	end
	local current = screen
	if current == nil or current.gui.Parent == nil then
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		local found = if playerGui then playerGui:FindFirstChild(SCREEN) else nil
		if found == nil or not found:IsA("ScreenGui") then
			reportOnce("screen", `[Admin] écran {SCREEN} absent de PlayerGui : le panel ne s'ouvre pas`)
			return
		end
		bind(found :: ScreenGui)
		current = screen
	end
	if current == nil then
		return
	end
	isOpen = true
	refreshPlayers(current)
	Motion.Open(current.gui)
end

local function toggleScreen()
	if isOpen then
		close()
	else
		open()
	end
end

local function showButton()
	local button = hudButton
	if button then
		button.Visible = isAdmin() and next(hiddenBy) == nil
	end
	if not isAdmin() and isOpen then
		close()
	end
end

-- Vague 38 (L-135 point 3) : `reason` (ex. « PawnShop ») cache AdminButton tant qu'il le demande ; le bouton revient
-- quand plus aucun écran ne le cache (et seulement pour un admin). Le panel ouvert reste ouvert.
function AdminController.SetHidden(reason: string, hidden: boolean)
	if hidden then
		hiddenBy[reason] = true
	else
		hiddenBy[reason] = nil
	end
	showButton()
end

local function bindHud(gui: Instance)
	local found = Find.path(gui, HUD_BUTTON)
	if found == nil or not found:IsA("GuiButton") then
		reportOnce("hud", `[Admin] {HUD}.{HUD_BUTTON} introuvable ou pas un bouton : le panel ne s'ouvre pas`)
		return
	end
	local button = found :: GuiButton
	if hudButton == button then
		return
	end
	hudButton = button
	button.Activated:Connect(toggleScreen)
	showButton()
end

------------------------------------------------------------------------------

function AdminController.Start()
	local ok, result = pcall(function()
		return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	end)
	if ok then
		net = result
		net.Client.AdminResult:Connect(function(_commandId: string, _ok: boolean, message: string)
			setStatus(message)
		end)
	end
	localPlayer:GetAttributeChangedSignal(ADMIN_ATTRIBUTE):Connect(showButton)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if not child:IsA("ScreenGui") then
			return
		end
		if child.Name == SCREEN then
			bind(child :: ScreenGui)
		elseif child.Name == HUD then
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
end

return AdminController
