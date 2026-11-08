--!strict
-- IndexController (DEV-111, client) : l'index des objets, écran UI_Index de Clément (maquette UI-111,
-- noms de ses calques ; Partie 2, section 3.4 ; règles : Config/Index ; découvertes : IndexService).
-- Seulement si Features.Index : à false, rien n'est branché et l'écran reste fermé.
--
-- Rôle :
--   - UI_HUD.IndexButton ouvre l'écran (un 2e appui le ferme) ; CloseButton le ferme. Ouverture et
--     fermeture animées par UI/Motion, comme les boutiques : les cartes sont retirées une fois l'écran
--     éteint, et une réouverture pendant la fermeture la rattrape ;
--   - 7 onglets : Tabs.Zone1Tab à Zone6Tab (les objets de la zone) et Tabs.SecretsTab (les Secrets).
--     À la première ouverture, la zone 1 ; ensuite, le dernier onglet choisi ;
--   - une carte par objet de l'onglet (Config/Index : ordre du catalogue, objet du tuto compris),
--     clonée depuis List.Template et nommée Item_<nn>_<ItemId> (LayoutOrder = rang) :
--       découvert      Icon.Image = l'icône ICON_<ItemId> (Contract/Icons), Icon.ImageColor3 blanc,
--                      Lock caché, ItemName = le nom anglais en capitales (« SODA CAN ») ;
--       pas découvert  la même icône en silhouette (Icon.ImageColor3 sombre), Lock visible,
--                      ItemName « ??? ».
--     Les deux teintes de l'icône sont lues sur les cartes d'exemple de Clément (Preview_* : Lock caché
--     = découvert, Lock visible = silhouette), sinon celles de sa maquette. Icône pas livrée : image
--     vide. Couleur de la rareté (doc : « silhouette noire avec la couleur de sa rareté ») : Rays et
--     Glow de la carte (ImageColor3) prennent celle de Config/Rarities, découvert ou pas ; RarityBar
--     n'est pas touchée (sombre sur toutes les cartes d'exemple) ;
--   - Counter (dans CounterPill) : « 23 / 83 discovered », tout le catalogue, Secrets compris ;
--   - ZoneReward, pour l'onglet ouvert : ZoneName = le texte de l'onglet (TabLabel) en capitales
--     (« MINI MART »), ZoneBar.Fill = la part découverte (seule la largeur en Scale change), ZoneCount
--     « 9 / 13 », Reward.RewardLabel « +5% INCOME », puis « +5% INCOME EARNED » une fois la zone
--     complète (le bonus est compté par le serveur). Onglet Secrets : les Secrets découverts, et Reward
--     caché (l'index complet donnera l'aura « Collectionneur », qui n'existe pas encore) ;
--   - l'écran suit l'attribut IndexDiscovered du Player (IndexService) : une découverte le met à jour
--     s'il est ouvert. Rien n'est envoyé au serveur.
-- Les cartes d'exemple de la maquette (Preview_*, à côté du Template) sont retirées de la copie du
-- joueur. Seuls sont touchés (2.2, « Libre pour Ironix ») : Enabled de l'écran, les textes, la
-- visibilité, les cartes clonées (nom, ordre), l'image et la teinte (ImageColor3) de leur icône et de
-- leurs rayons, la largeur de ZoneBar.Fill et le défilement de la liste ; jamais un style de Clément
-- (l'effet d'échelle de Motion est passager). Écran recréé (ResetOnSpawn) : rebranché, fermé.
--
-- API (client) : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Index = require(Config:WaitForChild("Index"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Zones = require(Config:WaitForChild("Zones"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local Icons = require(Contract:WaitForChild("Icons"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type Item = Items.Item

-- Un onglet : sa zone (nil = les Secrets) et son chemin dans l'écran (contrat 2.2).
type TabDef = { zone: number?, path: string }

-- Une carte clonée.
type Card = {
	item: Item,
	frame: GuiObject,
	icon: GuiObject?,
	lock: GuiObject?,
	name: Instance?,
	found: boolean?, -- état peint (nil : pas encore peint)
}

-- Écran branché.
type Screen = {
	gui: ScreenGui,
	template: GuiObject?,
	list: Instance?, -- la ScrollingFrame List
	counter: Instance?,
	zoneName: Instance?,
	zoneCount: Instance?,
	fill: GuiObject?,
	fillSize: UDim2, -- taille de Fill posée par Clément : seule la largeur en Scale change
	reward: GuiObject?,
	rewardShown: boolean, -- visibilité de Reward posée par Clément (rendue sur les onglets de zone)
	rewardLabel: Instance?,
	tabNames: { [number]: string }, -- [rang de l'onglet] = ZoneName
	foundColor: Color3,
	silhouetteColor: Color3,
	connections: { RBXScriptConnection },
	cards: { Card },
}

local SCREEN = "UI_Index"
local HUD = "UI_HUD"
local HUD_BUTTON = "IndexButton"
local CARD_FORMAT = "Item_%02d_%s" -- nom des cartes clonées (jamais « Template »)
local PREVIEW_PREFIX = "Preview_"
local TAB_LABEL = "TabLabel"
-- Éléments d'une carte teints à la couleur de la rareté (dans son cadre Clip).
local TINTED = { "Rays", "Glow" }

-- Onglets, dans l'ordre de l'écran : Zone1Tab à Zone6Tab, puis SecretsTab.
local TABS: { TabDef } = {}
for zone = 1, Index.ZoneCount do
	table.insert(TABS, { zone = zone, path = `Tabs.Zone{zone}Tab` })
end
table.insert(TABS, { zone = nil, path = "Tabs.SecretsTab" })

-- Textes, en anglais (L-036). V0 proposé, absent du doc, sauf le format du compteur et de la
-- récompense, repris de la maquette de Clément (« 23 / 74 discovered », « 9 / 13 », « +5% INCOME »).
local COUNTER_TEXT = "%d / %d discovered"
local ZONE_COUNT_TEXT = "%d / %d"
local REWARD_TEXT = "+%d%% INCOME"
local REWARD_EARNED_TEXT = "+%d%% INCOME EARNED"
local UNKNOWN_NAME = "???"
local SECRETS_NAME = "Secrets" -- ZoneName de l'onglet Secrets s'il n'a pas de TabLabel
-- Teintes de l'icône des cartes d'exemple de Clément (relevé de Studio du 2026-11-08), quand aucune
-- carte Preview_* ne les donne.
local FOUND_COLOR = Color3.new(1, 1, 1)
local SILHOUETTE_COLOR = Color3.fromRGB(17, 19, 24) -- (0,067 ; 0,075 ; 0,094)

local IS_STUDIO = RunService:IsStudio()

local IndexController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local tab = 1 -- rang de l'onglet ouvert dans TABS
local discovered: { [string]: boolean } = {}
local textures: { [string]: string } = {} -- [ItemId] = image de l'icône livrée
local missingIcons: { [string]: boolean } = {}
local reported: { [string]: boolean } = {}

-- Une ligne de sortie par sujet, en Studio seulement.
local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function isImage(inst: Instance?): boolean
	return inst ~= nil and (inst:IsA("ImageLabel") or inst:IsA("ImageButton"))
end

local function guiObject(root: Instance, path: string): GuiObject?
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

local function textOf(element: Instance?): string?
	local holder = textHolder(element)
	if holder then
		local text = (holder :: any).Text
		if type(text) == "string" and text ~= "" then
			return text
		end
	end
	return nil
end

local function setVisible(element: GuiObject?, visible: boolean)
	if element and element.Visible ~= visible then
		element.Visible = visible
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

-- Image de l'icône ICON_<ItemId> (une recherche par objet et par session), nil si elle n'est pas livrée.
local function textureOf(itemId: string): string?
	local known = textures[itemId]
	if known ~= nil or missingIcons[itemId] then
		return known
	end
	local texture = Icons.get(itemId)
	if texture ~= nil then
		textures[itemId] = texture
	else
		missingIcons[itemId] = true
		reportOnce(`icon:{itemId}`, `[Index] icône {Icons.name(itemId)} pas livrée : carte sans image`)
	end
	return texture
end

local function rarityColor(item: Item): Color3
	local rarity = Rarities.ById[item.Rarity]
	return if rarity then rarity.Color else FOUND_COLOR
end

local function itemsOf(def: TabDef): { Item }
	local zone = def.zone
	if zone ~= nil then
		return Index.ByZone[zone] or {}
	end
	return Index.Secrets
end

local function readDiscovered()
	discovered = Index.Decode(localPlayer:GetAttribute(Index.Attribute))
end

------------------------------------------------------------------------------
-- Cartes et en-tête
------------------------------------------------------------------------------

local function paint(current: Screen, card: Card)
	local found = discovered[card.item.Id] == true
	if card.found == found then
		return
	end
	card.found = found
	local icon = card.icon
	if icon then
		local image = icon :: any
		local texture = textureOf(card.item.Id) or ""
		if image.Image ~= texture then
			image.Image = texture
		end
		image.ImageColor3 = if found then current.foundColor else current.silhouetteColor
	end
	setVisible(card.lock, not found)
	setText(card.name, if found then string.upper(card.item.DisplayName) else UNKNOWN_NAME)
end

local function clearCards(current: Screen)
	for _, card in current.cards do
		card.frame:Destroy()
	end
	table.clear(current.cards)
end

-- Cartes de l'onglet ouvert, clonées depuis List.Template.
local function buildCards(current: Screen)
	clearCards(current)
	local template = current.template
	if template == nil then
		return
	end
	local parent = template.Parent
	local wanted: { string } = {}
	for rank, item in itemsOf(TABS[tab]) do
		local clone: Instance? = template:Clone()
		if clone == nil then
			return -- Archivable = false : rien à cloner
		end
		local frame = clone :: GuiObject
		frame.Name = string.format(CARD_FORMAT, rank, item.Id)
		frame.LayoutOrder = rank
		local color = rarityColor(item)
		for _, name in TINTED do
			local tinted = Find.path(frame, name)
			if tinted and isImage(tinted) then
				(tinted :: any).ImageColor3 = color
			end
		end
		local icon = Find.path(frame, "Icon")
		local card: Card = {
			item = item,
			frame = frame,
			icon = if icon and isImage(icon) then icon :: GuiObject else nil,
			lock = guiObject(frame, "Lock"),
			name = Find.path(frame, "ItemName"),
			found = nil,
		}
		paint(current, card)
		frame.Visible = true
		frame.Parent = parent
		table.insert(current.cards, card)
		local texture = textureOf(item.Id)
		if texture then
			table.insert(wanted, texture)
		end
	end
	if #wanted > 0 then
		task.spawn(Icons.preload, wanted)
	end
end

local function setFill(current: Screen, fraction: number)
	local fill = current.fill
	if fill then
		local size = current.fillSize
		local wanted = UDim2.new(math.clamp(fraction, 0, 1), size.X.Offset, size.Y.Scale, size.Y.Offset)
		if fill.Size ~= wanted then
			fill.Size = wanted
		end
	end
end

local function refreshHeader(current: Screen)
	setText(current.counter, string.format(COUNTER_TEXT, Index.CountAll(discovered), Index.Total))
	local zone = TABS[tab].zone
	local found: number, total: number
	if zone ~= nil then
		found, total = Index.CountZone(discovered, zone)
	else
		found, total = Index.CountSecrets(discovered)
	end
	setText(current.zoneName, current.tabNames[tab] or "")
	setText(current.zoneCount, string.format(ZONE_COUNT_TEXT, found, total))
	setFill(current, if total > 0 then found / total else 0)
	setVisible(current.reward, zone ~= nil and current.rewardShown)
	if zone ~= nil then
		local complete = total > 0 and found >= total
		local percent = math.round(Index.ZoneBonus * 100)
		setText(current.rewardLabel, string.format(if complete then REWARD_EARNED_TEXT else REWARD_TEXT, percent))
	end
end

local function scrollTop(current: Screen)
	local list = current.list
	if list and list:IsA("ScrollingFrame") then
		(list :: ScrollingFrame).CanvasPosition = Vector2.new(0, 0)
	end
end

-- Remet l'écran ouvert d'accord avec les découvertes (après un changement de l'attribut).
local function refresh()
	local current = screen
	if current == nil or not isOpen then
		return
	end
	for _, card in current.cards do
		paint(current, card)
	end
	refreshHeader(current)
end

------------------------------------------------------------------------------
-- Ouverture, fermeture, onglets
------------------------------------------------------------------------------

local function close()
	isOpen = false
	local current = screen
	if current then
		-- Cartes retirées une fois l'écran éteint ; une réouverture d'ici là les reconstruit.
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
	gui.Enabled = false -- fermé jusqu'au bouton du HUD

	local template = guiObject(gui, "List.Template")
	local foundColor: Color3? = nil
	local silhouetteColor: Color3? = nil
	if template == nil then
		reportOnce("template", `[Index] {SCREEN}.List.Template introuvable : l'index restera vide`)
	else
		template.Visible = false
		-- Cartes d'exemple de Clément (Preview_*, à côté du Template) : leurs teintes d'icône sont
		-- gardées, puis elles sont retirées de la copie du joueur (comme L-041).
		for _, sibling in (template.Parent :: Instance):GetChildren() do
			if string.sub(sibling.Name, 1, #PREVIEW_PREFIX) == PREVIEW_PREFIX then
				local icon = Find.path(sibling, "Icon")
				local lock = Find.path(sibling, "Lock")
				if icon and isImage(icon) and lock and lock:IsA("GuiObject") then
					local color = (icon :: any).ImageColor3 :: Color3
					if (lock :: GuiObject).Visible then
						silhouetteColor = silhouetteColor or color
					else
						foundColor = foundColor or color
					end
				end
				sibling:Destroy()
			end
		end
	end

	local zoneReward = Find.path(gui, "ZoneReward")
	local zoneBar = if zoneReward then Find.path(zoneReward, "ZoneBar") else nil
	local fill = if zoneBar then guiObject(zoneBar, "Fill") else nil
	local reward = if zoneReward then guiObject(zoneReward, "Reward") else nil
	local current: Screen = {
		gui = gui,
		template = template,
		list = if template then template.Parent else nil,
		counter = Find.path(gui, "Counter"),
		zoneName = if zoneReward then Find.path(zoneReward, "ZoneName") else nil,
		zoneCount = if zoneReward then Find.path(zoneReward, "ZoneCount") else nil,
		fill = fill,
		fillSize = if fill then fill.Size else UDim2.new(1, 0, 1, 0),
		reward = reward,
		rewardShown = if reward then reward.Visible else false,
		rewardLabel = if reward then Find.path(reward, "RewardLabel") else nil,
		tabNames = {},
		foundColor = foundColor or FOUND_COLOR,
		silhouetteColor = silhouetteColor or SILHOUETTE_COLOR,
		connections = {},
		cards = {},
	}
	screen = current
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	keep(onClick(Find.path(gui, "CloseButton"), close))
	for rank, def in TABS do
		local button = Find.path(gui, def.path)
		local label = if button then textOf(Find.path(button, TAB_LABEL)) else nil
		local zone = def.zone
		local fallback = SECRETS_NAME
		if zone ~= nil then
			local info = Zones[zone]
			fallback = if info then info.Theme else `Zone {zone}`
		end
		current.tabNames[rank] = string.upper(label or fallback)
		if button == nil then
			reportOnce(`tab:{def.path}`, `[Index] {SCREEN}.{def.path} introuvable : onglet pas branché`)
		end
		keep(onClick(button, function()
			if tab == rank then
				return
			end
			tab = rank
			if isOpen and screen == current then
				buildCards(current)
				refreshHeader(current)
				scrollTop(current)
			end
		end))
	end
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
		reportOnce("screen", `[Index] écran {SCREEN} absent de PlayerGui : l'index ne s'ouvre pas`)
		return
	end
	readDiscovered()
	isOpen = true
	buildCards(current)
	refreshHeader(current)
	scrollTop(current)
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

local hudBound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function bindHud(gui: Instance)
	if hudBound[gui] then
		return
	end
	local found = Find.path(gui, HUD_BUTTON)
	if found == nil or not found:IsA("GuiButton") then
		reportOnce("hud", `[Index] {HUD}.{HUD_BUTTON} introuvable ou pas un bouton : l'index ne s'ouvre pas`)
		return
	end
	hudBound[gui] = true
	(found :: GuiButton).Activated:Connect(toggle)
end

function IndexController.Start()
	if not Features.Index then
		return -- MAJ 2 : rien n'est branché, l'écran reste fermé
	end
	readDiscovered()
	localPlayer:GetAttributeChangedSignal(Index.Attribute):Connect(function()
		readDiscovered()
		refresh()
	end)

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
end

return IndexController
