--!strict
-- DisplayedController (vague 59, a191 ; L-182 point 6, L-183, client) : panneau « Mes objets exposés »,
-- écran UI_Displayed de Clément (nom à confirmer par lui ; pas encore dans Studio : sans l'écran, rien ne se
-- passe, une ligne dans la sortie en Studio). Il glisse depuis le bord droit : attribut Appear = SlideRight
-- de Panel, joué par le module d'animations d'UI (L-182 point 1), pas ici.
--
-- Rôle :
--   - ouverture : DisplayedController.Toggle() (appelé par le HUD, UI_HUD.RightRail.DisplayedButton, a190),
--     ou OpenButton de l'écran s'il existe encore (maquette Figma ; à retirer si le HUD le porte) ; CloseButton
--     ferme. Avec OpenButton, l'écran reste allumé et seul Panel (et DisplayBestButton s'il est à côté)
--     se montre ou se cache ; sans lui, c'est l'écran entier (Enabled) ;
--   - Panel.List : une ligne par objet exposé de la base, clonée depuis List.Template (Row_<nn>_<uid>, rangées
--     du meilleur revenu au moins bon, puis par présentoir) : Icon = ICON_<ItemId>, IconBack et RarityChip à la
--     couleur de la rareté, RarityChip.RarityLabel = sa rareté (« LEGENDARY »), ItemName, Income « +$1.2K/s »
--     (revenu de l'objet, mutation comprise, sans les bonus du joueur), attribut Rarity sur la ligne (dégradés
--     du module d'animations). RemoveButton → remote UnplaceItem(uid) : l'objet quitte son présentoir et
--     retourne dans le stock du joueur (Items du profil, ni exposé ni perdu) ;
--   - Panel.DisplayCount.CountLabel « 3/8 » (exposés / présentoirs débloqués) ; OpenButton.OpenCount.OpenCountLabel
--     = le nombre d'exposés ;
--   - DisplayBestButton → remote EquipBest (« Exposer les meilleurs ») : le SERVEUR remplit les présentoirs
--     débloqués avec les objets possédés qui rapportent le plus (DisplayService.EquipBest) ; un objet exposé
--     moins bon retourne dans le stock. Un appel par seconde au plus (Net, et ici pour ne rien perdre).
-- Tout vient des attributs du Player posés par le serveur : InventoryState (Shared/InventoryState,
-- InventoryService) et DisplaySlotsUnlocked (DisplayService). Le client ne décide rien.
-- Seuls sont touchés : Enabled de l'écran, Visible de Panel (et DisplayBestButton), les lignes clonées, leurs
-- textes, l'image de leur icône et la couleur de fond d'IconBack et de RarityChip.
--
-- API (client) :
--   DisplayedController.Open() / Close() / Toggle()
--   DisplayedController.IsOpen() -> boolean
--   DisplayedController.DisplayBest()          comme DisplayBestButton
--   DisplayedController.Remove(itemUid)        comme le RemoveButton d'une ligne

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local Icons = require(Contract:WaitForChild("Icons"))
local Format = require(Shared:WaitForChild("Format"))
local InventoryState = require(Shared:WaitForChild("InventoryState"))

type Entry = InventoryState.ItemEntry

type Screen = {
	gui: ScreenGui,
	panel: GuiObject?,
	best: GuiObject?, -- DisplayBestButton
	bestInPanel: boolean,
	openButton: GuiObject?,
	openCount: Instance?,
	countLabel: Instance?,
	template: GuiObject?,
	rows: { GuiObject },
	connections: { RBXScriptConnection },
}

local SCREEN = "UI_Displayed"
local ROW_FORMAT = "Row_%02d_%s" -- nom des lignes clonées (jamais « Template »)
local COUNT_TEXT = "%d/%d" -- V0 proposé, absent du doc : « 3/8 »
local SLOTS_ATTRIBUTE = "DisplaySlotsUnlocked" -- DisplayService
-- V0 proposé, absent du doc : attente minimale entre deux demandes (Net en accepte une par seconde pour
-- EquipBest ; quatre par seconde pour UnplaceItem).
local BEST_COOLDOWN = 1
local REMOVE_COOLDOWN = 0.3

local IS_STUDIO = RunService:IsStudio()

local DisplayedController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local net: any = nil
local lastBest = -math.huge
local lastRemove: { [string]: number } = {}
local reported: { [string]: boolean } = {}

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

local function guiObject(root: Instance, path: string): GuiObject?
	local found = Find.path(root, path)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function setText(element: Instance?, text: string)
	if element == nil then
		return
	end
	local holder: Instance? = element
	if not (element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox")) then
		holder = element:FindFirstChildWhichIsA("TextLabel", true)
	end
	if holder and (holder :: any).Text ~= text then
		(holder :: any).Text = text
	end
end

local function onClick(element: Instance?, handler: () -> ()): RBXScriptConnection?
	if element and element:IsA("GuiButton") then
		return (element :: GuiButton).Activated:Connect(function()
			handler()
		end)
	end
	return nil
end

-- Objets exposés, du meilleur revenu au moins bon (puis par présentoir).
local function exposed(): { Entry }
	local state = InventoryState.Decode(localPlayer:GetAttribute(InventoryState.Attribute))
	local list: { Entry } = {}
	for _, entry in state.Items do
		if entry.Slot ~= nil and Items.ById[entry.ItemId] ~= nil then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return (a.Slot or 0) < (b.Slot or 0)
	end)
	return list
end

local function unlockedSlots(): number
	local value = localPlayer:GetAttribute(SLOTS_ATTRIBUTE)
	return if type(value) == "number" then value else 0
end

local function clearRows(current: Screen)
	for _, row in current.rows do
		row:Destroy()
	end
	table.clear(current.rows)
end

local function sendRemove(uid: string)
	local now = os.clock()
	if now - (lastRemove[uid] or -math.huge) < REMOVE_COOLDOWN then
		return
	end
	if net == nil then
		reportOnce("net", "[Displayed] Net pas prêt : demande pas envoyée")
		return
	end
	lastRemove[uid] = now
	net.Client.UnplaceItem:Fire(uid)
end

local function buildRows(current: Screen, list: { Entry })
	clearRows(current)
	local template = current.template
	if template == nil then
		return
	end
	for rank, entry in list do
		local found = Items.ById[entry.ItemId]
		if found == nil then
			continue
		end
		local item: Items.Item = found
		local clone: Instance? = template:Clone()
		if clone == nil then
			return -- Archivable = false : rien à cloner
		end
		local row = clone :: GuiObject
		row.Name = string.format(ROW_FORMAT, rank, entry.Uid)
		row.LayoutOrder = rank
		row:SetAttribute("Rarity", item.Rarity)
		local rarity = Rarities.ById[item.Rarity]
		local color = if rarity then rarity.Color else Color3.new(1, 1, 1)
		local icon = Find.path(row, "Icon")
		local texture = Icons.get(item.Id)
		if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) and texture then
			(icon :: any).Image = texture
		end
		for _, path in { "IconBack", "RarityChip" } do
			local back = guiObject(row, path)
			if back then
				back.BackgroundColor3 = color
			end
		end
		setText(Find.path(row, "RarityChip.RarityLabel"), if rarity then rarity.DisplayNameUpper else item.Rarity)
		setText(Find.path(row, "ItemName"), item.DisplayName)
		setText(Find.path(row, "Income"), Format.income(entry.Income))
		local uid = entry.Uid
		local _ = onClick(Find.path(row, "RemoveButton"), function()
			sendRemove(uid) -- détruite avec la ligne
		end)
		row.Visible = true
		row.Parent = template.Parent
		table.insert(current.rows, row)
	end
end

-- Compteurs (écran ouvert ou pas) et lignes (écran ouvert seulement).
local function refresh()
	local current = screen
	if current == nil then
		return
	end
	local list = exposed()
	setText(current.countLabel, string.format(COUNT_TEXT, #list, unlockedSlots()))
	setText(current.openCount, tostring(#list))
	if isOpen then
		buildRows(current, list)
	end
end

local function apply(current: Screen)
	if current.openButton then
		current.gui.Enabled = true
		if current.panel then
			current.panel.Visible = isOpen
		end
		if current.best and not current.bestInPanel then
			current.best.Visible = isOpen
		end
	else
		current.gui.Enabled = isOpen
	end
end

-- Définies plus bas (elles rebranchent l'écran au besoin).
local closePanel: () -> ()
local togglePanel: () -> ()
local displayBest: () -> ()

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
		clearRows(old)
	end
	isOpen = false
	local panel = guiObject(gui, "Panel")
	local best = guiObject(gui, "DisplayBestButton")
	local template = guiObject(gui, "List.Template")
	if template == nil then
		reportOnce("template", `[Displayed] {SCREEN}.Panel.List.Template introuvable : panneau vide`)
	else
		template.Visible = false
	end
	if best == nil then
		reportOnce("best", `[Displayed] {SCREEN}.DisplayBestButton introuvable : pas d'« Exposer les meilleurs »`)
	end
	local openButton = guiObject(gui, "OpenButton")
	local current: Screen = {
		gui = gui,
		panel = panel,
		best = best,
		bestInPanel = best ~= nil and panel ~= nil and best:IsDescendantOf(panel),
		openButton = openButton,
		openCount = if openButton then Find.path(openButton, "OpenCountLabel") else nil,
		countLabel = Find.path(gui, "DisplayCount.CountLabel"),
		template = template,
		rows = {},
		connections = {},
	}
	screen = current
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	keep(onClick(Find.path(gui, "CloseButton"), function()
		closePanel()
	end))
	keep(onClick(openButton, function()
		togglePanel()
	end))
	keep(onClick(best, function()
		displayBest()
	end))
	apply(current)
	refresh()
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

function DisplayedController.IsOpen(): boolean
	return isOpen
end

function DisplayedController.Open()
	local current = currentScreen()
	if current == nil then
		reportOnce("screen", `[Displayed] écran {SCREEN} absent de PlayerGui : le panneau ne s'ouvre pas`)
		return
	end
	isOpen = true
	apply(current)
	refresh()
end

function DisplayedController.Close()
	isOpen = false
	local current = screen
	if current and current.gui.Parent ~= nil then
		apply(current)
		clearRows(current)
	end
end

function DisplayedController.Toggle()
	if isOpen then
		DisplayedController.Close()
	else
		DisplayedController.Open()
	end
end

function DisplayedController.DisplayBest()
	local now = os.clock()
	if now - lastBest < BEST_COOLDOWN then
		return
	end
	if net == nil then
		reportOnce("net", "[Displayed] Net pas prêt : demande pas envoyée")
		return
	end
	lastBest = now
	net.Client.EquipBest:Fire()
end

function DisplayedController.Remove(itemUid: string)
	if type(itemUid) == "string" then
		sendRemove(itemUid)
	end
end

closePanel = DisplayedController.Close
togglePanel = DisplayedController.Toggle
displayBest = DisplayedController.DisplayBest

function DisplayedController.Start()
	localPlayer:GetAttributeChangedSignal(InventoryState.Attribute):Connect(refresh)
	localPlayer:GetAttributeChangedSignal(SLOTS_ATTRIBUTE):Connect(refresh)
	-- Les remotes attendent le serveur : sans bloquer le reste.
	task.spawn(function()
		local ok, result = pcall(function(): any
			return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
		end)
		if ok then
			net = result
		else
			reportOnce("netRequire", `[Displayed] Net introuvable : les demandes ne partent pas ({result})`)
		end
	end)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui) -- écran recréé (ResetOnSpawn) : rebranché, fermé
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end
end

return DisplayedController
