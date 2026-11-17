--!strict
-- DisplayedController (vague 59, a191 ; L-182 point 6, L-183 ; vague 63, a206 : L-192 Q3 et Q4, L-202 point 4 ;
-- client) : panneau « Mes objets exposés » et sa réserve, écran UI_Displayed de Clément (nom gardé, L-192 Q4). Sans
-- l'écran, rien ne se passe (une ligne dans la sortie en Studio). Il glisse depuis le bord droit : attribut Appear =
-- SlideRight de Dock (L-202), joué par le module d'animations d'UI, pas ici.
--
-- Rôle :
--   - ouverture : DisplayedController.Toggle() (appelé par le HUD, UI_HUD.RightRail.DisplayedButton, a190) allume
--     et éteint l'ÉCRAN ENTIER (Enabled) ; CloseButton l'éteint. Vague 63 : plus d'OpenButton (L-202 point 4) ;
--   - Panel.List : une ligne par objet exposé de la base, clonée depuis List.Template (Row_<nn>_<uid>, rangées
--     du meilleur revenu au moins bon, puis par présentoir) : Icon = ICON_<ItemId>, IconBack à la couleur de la
--     rareté, RarityChip.RarityLabel = sa rareté (« LEGENDARY »), ItemName, Income « +$1.2K/s » (revenu de l'objet,
--     mutation comprise, sans les bonus du joueur), attribut Rarity sur la ligne (dégradés du module d'animations).
--     Vague 63 : ItemName et RarityChip.RarityLabel à la couleur de la rareté (TextColor3, puis Controllers/UI/
--     RarityFx : dégradé, reflet du Légendaire, arc-en-ciel du Mythique et plus) ; le fond de RarityChip n'est plus
--     touché (transparent chez Clément). RemoveButton → remote UnplaceItem(uid) : l'objet quitte son présentoir et
--     revient DANS LA MAIN, ou dans la réserve si les mains sont prises (InventoryService, règle de Clément) ;
--   - Panel.DisplayCount.CountLabel « 3/8 » (exposés / présentoirs débloqués) ;
--   - DisplayBestButton → remote EquipBest (« Exposer les meilleurs ») : le SERVEUR remplit les présentoirs
--     débloqués avec les objets possédés qui rapportent le plus (DisplayService.EquipBest) ; un objet exposé
--     moins bon va dans la réserve. Un appel par seconde au plus (Net, et ici pour ne rien perdre) ;
--   - vague 63, réserve (L-192 Q3, noms de L-202) : Panel.Reserve, caché quand la réserve est vide ;
--     Reserve.ReserveCount.ReserveCountLabel = le nombre d'objets en réserve ; Reserve.ReserveList.Template cloné
--     par objet (Reserve_<nn>_<uid>, du meilleur revenu au moins bon) : IconBack à la couleur de la rareté, Icon,
--     ItemName (couleur de la rareté), Income, attribut Rarity ; DisplayButton → remote PlaceFromReserve(uid) :
--     le serveur le pose sur un présentoir libre (sinon « No free display », rien ne bouge). Sans Reserve dans
--     l'écran : la réserve n'est pas montrée, rien ne casse.
--   - vague 66 (a219, L-210 point 2, Config/Displayed) : le serveur met dans la réserve tout objet ni exposé ni en
--     main (ReserveCatchAll) et échange avec l'exposé le moins rentable quand tout est pris (SwapWhenFull) ; ici, un
--     objet sous antivol pas encore posé au sol est listé à la suite, DisplayButton.DisplayLabel = LockedButtonText
--     (« PLACE ») : le bouton ferme le panneau et lance la pose au sol (InventoryController.PlaceItem).
--   - vague 72 (a242, L-219 point 4, L-231) : le bouton inventaire du HUD (toujours UI_HUD.DisplayedButton) ouvre cet
--     écran ; la réserve en sort (Config/Displayed.ShowReserve = false : Panel.Reserve caché, jamais rempli ; le serveur
--     la garde). CloseArrowButton (la flèche vers la droite, facultative) ferme comme CloseButton (la croix, repli).
--     Les lignes ne sont refaites que si ce qu'elles montrent change : un clic n'est plus perdu sur une ligne refaite
--     entre l'appui et le relâché.
-- Tout vient des attributs du Player posés par le serveur : InventoryState (Shared/InventoryState,
-- InventoryService), DisplaySlotsUnlocked et DisplayReserve (DisplayService). Le client ne décide rien.
-- Seuls sont touchés : Enabled de l'écran, Visible de Panel.Reserve, les lignes clonées (taille du Template
-- gardée), leurs textes, la couleur de leurs textes ItemName et RarityLabel, l'image de leur icône et la couleur de
-- fond d'IconBack.
--
-- API (client) :
--   DisplayedController.Open() / Close() / Toggle()
--   DisplayedController.IsOpen() -> boolean
--   DisplayedController.DisplayBest()          comme DisplayBestButton
--   DisplayedController.Remove(itemUid)        comme le RemoveButton d'une ligne
--   DisplayedController.Display(itemUid)       comme le DisplayButton d'une ligne de la réserve (vague 63)
--   DisplayedController.GetReserve() -> { string }   uids de la réserve, dans l'ordre du serveur (bancs)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local DisplayedConfig = require(Config:WaitForChild("Displayed"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local Icons = require(Contract:WaitForChild("Icons"))
local Format = require(Shared:WaitForChild("Format"))
local InventoryState = require(Shared:WaitForChild("InventoryState"))

type Entry = InventoryState.ItemEntry
type RarityFxApi = { Apply: (target: GuiObject, rarityId: string?) -> string? }

type Screen = {
	gui: ScreenGui,
	countLabel: Instance?,
	template: GuiObject?,
	rows: { GuiObject },
	reserve: GuiObject?, -- Panel.Reserve (vague 63)
	reserveCount: Instance?,
	reserveTemplate: GuiObject?,
	reserveRows: { GuiObject },
	rowsKey: string?, -- vague 72 : ce que montrent les lignes (refaites seulement s'il change)
	reserveKey: string?,
	connections: { RBXScriptConnection },
}

local SCREEN = "UI_Displayed"
local ROW_FORMAT = "Row_%02d_%s" -- nom des lignes clonées (jamais « Template »)
local RESERVE_ROW_FORMAT = "Reserve_%02d_%s" -- vague 63 : lignes de la réserve
local COUNT_TEXT = "%d/%d" -- V0 proposé, absent du doc : « 3/8 »
local SLOTS_ATTRIBUTE = "DisplaySlotsUnlocked" -- DisplayService
local RESERVE_ATTRIBUTE = DisplayedConfig.ReserveAttribute -- DisplayService (vague 63)
local SHOW_RESERVE = DisplayedConfig.ShowReserve ~= false -- vague 72 (a242, L-231) : réserve montrée dans l'écran
local CLOSE_ARROW = "CloseArrowButton" -- vague 72 (L-219 point 4) : la flèche vers la droite, nom proposé à Clément
-- V0 proposé, absent du doc : attente minimale entre deux demandes (Net en accepte une par seconde pour
-- EquipBest ; quatre par seconde pour UnplaceItem et PlaceFromReserve).
local BEST_COOLDOWN = 1
local REMOVE_COOLDOWN = 0.3

local IS_STUDIO = RunService:IsStudio()

local DisplayedController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local net: any = nil
local lastBest = -math.huge
local lastSend: { [string]: number } = {}
local reported: { [string]: boolean } = {}

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

-- Vague 63 : Controllers/UI/RarityFx (module d'aide, facultatif : sans lui, la couleur unie de la rareté).
local rarityFx: RarityFxApi? = nil
do
	local folder = script.Parent:FindFirstChild("UI")
	local module = if folder then folder:FindFirstChild("RarityFx") else nil
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			rarityFx = result :: any
		end
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

-- Vague 63 (L-202) : texte à la couleur de la rareté, puis son effet (RarityFx), comme dans Figma.
local function paintText(element: Instance?, rarityId: string, color: Color3)
	if element == nil or not (element:IsA("TextLabel") or element:IsA("TextButton")) then
		return
	end
	(element :: any).TextColor3 = color
	local fx = rarityFx
	if fx then
		pcall(fx.Apply, element :: GuiObject, rarityId)
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

local function inventory(): { Entry }
	return InventoryState.Decode(localPlayer:GetAttribute(InventoryState.Attribute)).Items
end

-- Objets exposés, du meilleur revenu au moins bon (puis par présentoir).
local function exposed(items: { Entry }): { Entry }
	local list: { Entry } = {}
	for _, entry in items do
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

-- Uids de la réserve (attribut DisplayReserve, dans l'ordre du serveur).
local function reserveUids(): { string }
	local list: { string } = {}
	local text = localPlayer:GetAttribute(RESERVE_ATTRIBUTE)
	if type(text) == "string" then
		for uid in string.gmatch(text, "[^,]+") do
			if InventoryState.IsSafeId(uid) then
				table.insert(list, uid)
			end
		end
	end
	return list
end

-- Objets de la réserve connus de l'état de l'inventaire (pas exposés), du meilleur revenu au moins bon, puis dans
-- l'ordre du serveur.
local function reserved(items: { Entry }): { Entry }
	local byUid: { [string]: Entry } = {}
	for _, entry in items do
		if entry.Slot == nil and Items.ById[entry.ItemId] ~= nil then
			byUid[entry.Uid] = entry
		end
	end
	local rank: { [string]: number } = {}
	local list: { Entry } = {}
	local count = 0
	for _, uid in reserveUids() do
		local entry = byUid[uid]
		if entry and rank[uid] == nil then
			count += 1
			rank[uid] = count
			table.insert(list, entry)
		end
	end
	-- Vague 66 (a219, L-210 point 2, Config/Displayed.ReserveCatchAll) : un objet sous antivol pas encore posé au sol
	-- (seul cas où l'état le montre) est listé aussi : son bouton lance la pose au sol (plus haut, buildReserve).
	if DisplayedConfig.ReserveCatchAll == true then
		for _, entry in items do
			if entry.AntiTheft == true and rank[entry.Uid] == nil and byUid[entry.Uid] ~= nil then
				count += 1
				rank[entry.Uid] = count
				table.insert(list, entry)
			end
		end
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return rank[a.Uid] < rank[b.Uid]
	end)
	return list
end

local function unlockedSlots(): number
	local value = localPlayer:GetAttribute(SLOTS_ATTRIBUTE)
	return if type(value) == "number" then value else 0
end

local function clearRows(rows: { GuiObject })
	for _, row in rows do
		row:Destroy()
	end
	table.clear(rows)
end

local function clearAll(current: Screen)
	clearRows(current.rows)
	clearRows(current.reserveRows)
	current.rowsKey = nil
	current.reserveKey = nil
end

-- Vague 72 : ce que montrent les lignes de `list` (ordre, objet, revenu, antivol).
local function keyOf(list: { Entry }): string
	local parts = table.create(#list)
	for _, entry in list do
		table.insert(parts, `{entry.Uid}:{entry.ItemId}:{entry.Income}:{entry.AntiTheft == true}`)
	end
	return table.concat(parts, ",")
end

-- Une demande au serveur (remote `name`, un uid), au plus une par REMOVE_COOLDOWN s et par uid.
local function send(name: string, uid: string)
	local key = name .. ":" .. uid
	local now = os.clock()
	if now - (lastSend[key] or -math.huge) < REMOVE_COOLDOWN then
		return
	end
	if net == nil then
		reportOnce("net", "[Displayed] Net pas prêt : demande pas envoyée")
		return
	end
	lastSend[key] = now
	net.Client[name]:Fire(uid)
end

-- Une copie de `template` pour `entry` (nom, ordre, icône, couleurs, textes), ou nil.
local function cloneRow(template: GuiObject, format: string, rank: number, entry: Entry): GuiObject?
	local found = Items.ById[entry.ItemId]
	if found == nil then
		return nil
	end
	local item: Items.Item = found
	local clone: Instance? = template:Clone()
	if clone == nil then
		return nil -- Archivable = false : rien à cloner
	end
	local row = clone :: GuiObject
	row.Name = string.format(format, rank, entry.Uid)
	row.LayoutOrder = rank
	row:SetAttribute("Rarity", item.Rarity)
	local rarity = Rarities.ById[item.Rarity]
	local color = if rarity then rarity.Color else Color3.new(1, 1, 1)
	local icon = Find.path(row, "Icon")
	local texture = Icons.get(item.Id)
	if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) and texture then
		(icon :: any).Image = texture
	end
	local back = guiObject(row, "IconBack")
	if back then
		back.BackgroundColor3 = color
	end
	setText(Find.path(row, "RarityChip.RarityLabel"), if rarity then rarity.DisplayNameUpper else item.Rarity)
	setText(Find.path(row, "ItemName"), item.DisplayName)
	setText(Find.path(row, "Income"), Format.income(entry.Income))
	paintText(Find.path(row, "ItemName"), item.Rarity, color)
	paintText(Find.path(row, "RarityChip.RarityLabel"), item.Rarity, color)
	return row
end

local function buildRows(current: Screen, list: { Entry })
	local key = keyOf(list)
	if key == current.rowsKey then
		return -- rien de changé : les lignes (et leurs boutons) restent
	end
	current.rowsKey = key
	clearRows(current.rows)
	local template = current.template
	if template == nil then
		return
	end
	for rank, entry in list do
		local row = cloneRow(template, ROW_FORMAT, rank, entry)
		if row == nil then
			continue
		end
		local uid = entry.Uid
		local _ = onClick(Find.path(row, "RemoveButton"), function()
			send("UnplaceItem", uid) -- détruite avec la ligne
		end)
		row.Visible = true
		row.Parent = template.Parent
		table.insert(current.rows, row)
	end
end

local closePanel: () -> () -- défini plus bas (DisplayedController.Close)

-- Vague 66 (a219) : objet sous antivol de la réserve : le panneau se ferme et la pose au sol commence
-- (InventoryController.PlaceItem, comme la barre du bas ; le serveur revérifie tout à PlaceBox).
local function placeOnFloor(uid: string)
	local module = script.Parent:FindFirstChild("InventoryController")
	local ok, result = pcall(function(): any
		return if module and module:IsA("ModuleScript") then (require(module) :: any).PlaceItem else nil
	end)
	if not ok or type(result) ~= "function" then
		reportOnce("placeOnFloor", `[Displayed] InventoryController.PlaceItem introuvable : objet sous antivol pas posé ({result})`)
		return
	end
	closePanel()
	local placed, err = pcall(result, uid)
	if not placed then
		reportOnce("placeOnFloorError", `[Displayed] InventoryController.PlaceItem : {err}`)
	end
end

local function buildReserve(current: Screen, list: { Entry })
	local key = keyOf(list)
	if key == current.reserveKey then
		return
	end
	current.reserveKey = key
	clearRows(current.reserveRows)
	local template = current.reserveTemplate
	if template == nil then
		return
	end
	for rank, entry in list do
		local row = cloneRow(template, RESERVE_ROW_FORMAT, rank, entry)
		if row == nil then
			continue
		end
		local uid = entry.Uid
		local locked = entry.AntiTheft == true
		local button = Find.path(row, "DisplayButton")
		if locked and button then
			setText(button:FindFirstChild("DisplayLabel"), DisplayedConfig.LockedButtonText) -- vague 66 : « PLACE »
		end
		local _ = onClick(button, function()
			if locked then
				placeOnFloor(uid)
			else
				send("PlaceFromReserve", uid) -- détruite avec la ligne
			end
		end)
		row.Visible = true
		row.Parent = template.Parent
		table.insert(current.reserveRows, row)
	end
end

-- Compteurs (écran ouvert ou pas) et lignes (écran ouvert seulement).
local function refresh()
	local current = screen
	if current == nil then
		return
	end
	local items = inventory()
	local list = exposed(items)
	local stock = reserved(items)
	setText(current.countLabel, string.format(COUNT_TEXT, #list, unlockedSlots()))
	setText(current.reserveCount, tostring(#stock))
	if current.reserve then
		current.reserve.Visible = #stock > 0
	end
	if isOpen then
		buildRows(current, list)
		buildReserve(current, stock)
	end
end

local function apply(current: Screen)
	current.gui.Enabled = isOpen
end

-- Définies plus bas (elles rebranchent l'écran au besoin).
local displayBest: () -> ()

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
		clearAll(old)
	end
	isOpen = false
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
	local reserve = guiObject(gui, "Reserve")
	if reserve and not SHOW_RESERVE then
		reserve.Visible = false -- vague 72 (L-231) : la réserve sort de l'écran, jamais remplie
		reserve = nil
	end
	local reserveTemplate = if reserve then guiObject(reserve, "ReserveList.Template") else nil
	if reserve == nil then
		if SHOW_RESERVE then -- sinon rien à signaler : la réserve n'est pas montrée (Config/Displayed.ShowReserve)
			reportOnce("reserve", `[Displayed] {SCREEN}.Panel.Reserve introuvable : la réserve n'est pas montrée`)
		end
	elseif reserveTemplate == nil then
		reportOnce("reserveTemplate", `[Displayed] {SCREEN}.Panel.Reserve.ReserveList.Template introuvable : réserve vide`)
	else
		reserveTemplate.Visible = false
	end
	local current: Screen = {
		gui = gui,
		countLabel = Find.path(gui, "DisplayCount.CountLabel"),
		template = template,
		rows = {},
		reserve = reserve,
		reserveCount = if reserve then Find.path(reserve, "ReserveCount.ReserveCountLabel") else nil,
		reserveTemplate = reserveTemplate,
		reserveRows = {},
		rowsKey = nil,
		reserveKey = nil,
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
	keep(onClick(Find.path(gui, CLOSE_ARROW), function() -- vague 72 : la flèche, si Clément l'a livrée
		closePanel()
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
		clearAll(current)
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
		send("UnplaceItem", itemUid)
	end
end

function DisplayedController.Display(itemUid: string)
	if type(itemUid) == "string" then
		send("PlaceFromReserve", itemUid)
	end
end

function DisplayedController.GetReserve(): { string }
	return reserveUids()
end

closePanel = DisplayedController.Close
displayBest = DisplayedController.DisplayBest

function DisplayedController.Start()
	localPlayer:GetAttributeChangedSignal(InventoryState.Attribute):Connect(refresh)
	localPlayer:GetAttributeChangedSignal(SLOTS_ATTRIBUTE):Connect(refresh)
	localPlayer:GetAttributeChangedSignal(RESERVE_ATTRIBUTE):Connect(refresh)
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
