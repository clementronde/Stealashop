--!strict
-- IndexController (DEV-111, client) : l'index des objets, écran UI_Index_v2 de Clément (L-083, points 5
-- et 6 : une seule liste qui défile, une section par zone, plus d'onglets), avec repli sur l'ancien
-- UI_Index (onglets, maquette UI-111) tant que la v2 n'est pas dans PlayerGui. Partie 2, section 3.4 ;
-- règles : Config/Index ; découvertes : IndexService.
-- Seulement si Features.Index : à false, rien n'est branché et l'écran reste fermé.
--
-- Rôle :
--   - UI_HUD.IndexButton ouvre l'écran (un 2e appui le ferme) ; CloseButton le ferme. Ouverture et
--     fermeture animées par UI/Motion (groupe ScreenGroup de l'écran, Motion.SetCloser), comme les
--     boutiques : les cartes sont retirées une fois l'écran éteint, et une réouverture pendant la
--     fermeture la rattrape. Quand UI_Index_v2 est branché, l'ancien UI_Index est éteint (Enabled) ;
--   - UI_Index_v2 : 7 sections dans List, Zone1Section à Zone6Section (les objets de la zone) et
--     SecretsSection (les Secrets). Dans chacune, les cartes vont dans son cadre Cards (UIGridLayout de
--     Clément) ; en-tête : ZoneName (texte de Clément gardé ; écrit seulement s'il est vide), ZoneBar.Fill
--     et ZoneCount, Reward.RewardLabel (Reward caché dans SecretsSection par Clément, laissé tel quel) ;
--   - UI_Index (repli) : 7 onglets, Tabs.Zone1Tab à Zone6Tab et Tabs.SecretsTab, et un seul en-tête
--     ZoneReward pour l'onglet ouvert (ZoneName = le texte de l'onglet en capitales). À la première
--     ouverture, la zone 1 ; ensuite, le dernier onglet choisi ;
--   - une carte par objet (Config/Index : ordre du catalogue, objet du tuto compris), clonée depuis
--     List.Template et nommée Item_<nn>_<ItemId> (LayoutOrder = rang dans sa zone) :
--       découvert      Icon.Image = l'icône ICON_<ItemId> (Contract/Icons), Icon.ImageColor3 blanc,
--                      Lock caché, ItemName = le nom anglais en capitales (« SODA CAN ») ;
--       pas découvert  la même icône en silhouette (Icon.ImageColor3 sombre), Lock visible,
--                      ItemName « ??? ».
--     Les deux teintes de l'icône sont lues sur les cartes d'exemple de Clément (Preview_* : Lock caché
--     = découvert, Lock visible = silhouette), sinon celles de sa maquette. Icône pas livrée : image
--     vide. Couleur de la rareté : Rays et Glow de la carte (ImageColor3) prennent celle de
--     Config/Rarities, découvert ou pas ; RarityBar.Rarity dit la rareté ; RarityBar n'est pas teinte ;
--   - Counter (dans CounterPill) : « 23 / 83 discovered », tout le catalogue, Secrets compris ;
--   - ZoneCount « 9 / 13 », ZoneBar.Fill = la part découverte (seule la largeur en Scale change),
--     RewardLabel = rewardText (à changer là quand la récompense d'une zone complète change) ;
--   - ScrollTrack (UI_Index_v2, L-083 point 5) : c'est le curseur de la barre de défilement. Sa place et
--     sa hauteur posées par Clément délimitent la piste ; le curseur y prend une hauteur proportionnelle
--     à la part visible de la liste (au moins TRACK_MIN_SHARE de la piste) et descend avec la liste
--     (List.CanvasPosition rapporté à AbsoluteCanvasSize − AbsoluteWindowSize). Rien à défiler : il
--     remplit la piste. Mis à jour sur les changements de CanvasPosition, AbsoluteCanvasSize et
--     AbsoluteWindowSize, pas à chaque image. Il ne se tire pas (la molette, le doigt et la barre de
--     Roblox font défiler la liste) ;
--   - l'écran suit l'attribut IndexDiscovered du Player (IndexService) : une découverte le met à jour
--     s'il est ouvert. Rien n'est envoyé au serveur.
-- Les cartes d'exemple de la maquette (Preview_*, à côté du Template ou dans un Cards) sont retirées de
-- la copie du joueur. Seuls sont touchés (2.2, « Libre pour Ironix ») : Enabled des écrans, les textes,
-- la visibilité, les cartes clonées (nom, ordre), l'image et la teinte (ImageColor3) de leur icône et de
-- leurs rayons, la largeur de ZoneBar.Fill, le défilement de la liste, la position et la hauteur de
-- ScrollTrack ; jamais un style de Clément (l'effet d'échelle de Motion est passager). Écran recréé
-- (ResetOnSpawn) : rebranché, fermé.
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

-- Une zone de l'index (nil = les Secrets) et son chemin dans l'écran (contrat 2.2) : onglet de UI_Index
-- ou section de UI_Index_v2.
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

-- Un en-tête et ses cartes : une section de UI_Index_v2, ou l'unique ZoneReward de UI_Index (sa zone
-- suit l'onglet ouvert).
type Section = {
	def: TabDef,
	cardParent: Instance?, -- Cards de la section (v2), List (repli)
	zoneName: Instance?,
	keepName: boolean, -- v2 : le texte de Clément est gardé (écrit seulement s'il est vide)
	zoneCount: Instance?,
	fill: GuiObject?,
	fillSize: UDim2, -- taille de Fill posée par Clément : seule la largeur en Scale change
	reward: GuiObject?,
	rewardShown: boolean, -- visibilité de Reward posée par Clément
	rewardLabel: Instance?,
}

-- Écran branché.
type Screen = {
	gui: ScreenGui,
	v2: boolean,
	template: GuiObject?,
	list: Instance?, -- la ScrollingFrame List
	counter: Instance?,
	sections: { Section },
	tabNames: { [number]: string }, -- repli : [rang de l'onglet] = ZoneName
	foundColor: Color3,
	silhouetteColor: Color3,
	track: GuiObject?, -- ScrollTrack (v2)
	trackPosition: UDim2, -- place et taille posées par Clément : la piste du curseur
	trackSize: UDim2,
	connections: { RBXScriptConnection },
	cards: { Card },
}

local SCREEN = "UI_Index_v2"
local LEGACY_SCREEN = "UI_Index" -- repli, tant que la v2 n'est pas livrée (question posée à Clément)
local HUD = "UI_HUD"
local HUD_BUTTON = "IndexButton"
local CARD_FORMAT = "Item_%02d_%s" -- nom des cartes clonées (jamais « Template »)
local PREVIEW_PREFIX = "Preview_"
local TAB_LABEL = "TabLabel"
-- Éléments d'une carte teints à la couleur de la rareté (dans son cadre Clip).
local TINTED = { "Rays", "Glow" }

-- Zones de l'index, dans l'ordre de l'écran : zones 1 à 6, puis les Secrets.
local TABS: { TabDef } = {} -- onglets de UI_Index
local SECTIONS: { TabDef } = {} -- sections de UI_Index_v2
for zone = 1, Index.ZoneCount do
	table.insert(TABS, { zone = zone, path = `Tabs.Zone{zone}Tab` })
	table.insert(SECTIONS, { zone = zone, path = `Zone{zone}Section` })
end
table.insert(TABS, { zone = nil, path = "Tabs.SecretsTab" })
table.insert(SECTIONS, { zone = nil, path = "SecretsSection" })

-- Textes, en anglais (L-036). V0 proposé, absent du doc, sauf le format du compteur et de la
-- récompense, repris de la maquette de Clément (« 23 / 74 discovered », « 9 / 13 », « +5% INCOME »).
local COUNTER_TEXT = "%d / %d discovered"
local ZONE_COUNT_TEXT = "%d / %d"
local UNKNOWN_NAME = "???"
local SECRETS_NAME = "Secrets" -- ZoneName des Secrets sans texte de Clément
-- Récompense d'une zone complète affichée dans RewardLabel : Index.ZoneRewardText (argent, vitesse et
-- revenus, L-083 point 7), suivi de ce mot une fois la zone complète. V0, en anglais.
local REWARD_EARNED_SUFFIX = " EARNED"
-- Teintes de l'icône des cartes d'exemple de Clément (relevé de Studio du 2026-11-08), quand aucune
-- carte Preview_* ne les donne.
local FOUND_COLOR = Color3.new(1, 1, 1)
local SILHOUETTE_COLOR = Color3.fromRGB(17, 19, 24) -- (0,067 ; 0,075 ; 0,094)
-- Hauteur minimale du curseur ScrollTrack, en part de sa piste. V0 proposé, absent du doc.
local TRACK_MIN_SHARE = 0.1

local IS_STUDIO = RunService:IsStudio()

local IndexController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local tab = 1 -- repli : rang de l'onglet ouvert dans TABS
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

-- Nom d'une zone quand l'écran n'en donne pas : le Theme de Config/Zones (« Mini Mart »).
local function fallbackName(def: TabDef): string
	local zone = def.zone
	if zone == nil then
		return SECRETS_NAME
	end
	local info = Zones[zone]
	return if info then info.Theme else `Zone {zone}`
end

-- Texte de RewardLabel pour une zone (complete : tous ses objets découverts, bonus déjà compté par le
-- serveur).
local function rewardText(zone: number, complete: boolean): string
	return Index.ZoneRewardText(zone) .. (if complete then REWARD_EARNED_SUFFIX else "")
end

local function readDiscovered()
	discovered = Index.Decode(localPlayer:GetAttribute(Index.Attribute))
end

------------------------------------------------------------------------------
-- Cartes et en-têtes
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

-- Cartes de chaque section (v2 : toutes les zones ; repli : l'onglet ouvert), clonées depuis
-- List.Template.
local function buildCards(current: Screen)
	clearCards(current)
	local template = current.template
	if template == nil then
		return
	end
	local wanted: { string } = {}
	for _, section in current.sections do
		local parent = section.cardParent
		if parent == nil then
			continue
		end
		for rank, item in itemsOf(section.def) do
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
			-- Nom de la rareté dans la bande du bas (RarityBar.Rarity, « COMMON » sur le modèle de
			-- Clément), découvert ou pas : la silhouette garde sa rareté (doc 3.4).
			local rarity = Rarities.ById[item.Rarity]
			if rarity then
				setText(Find.path(frame, "RarityBar.Rarity"), rarity.DisplayNameUpper)
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
	end
	if #wanted > 0 then
		task.spawn(Icons.preload, wanted)
	end
end

local function setFill(section: Section, fraction: number)
	local fill = section.fill
	if fill then
		local size = section.fillSize
		local wanted = UDim2.new(math.clamp(fraction, 0, 1), size.X.Offset, size.Y.Scale, size.Y.Offset)
		if fill.Size ~= wanted then
			fill.Size = wanted
		end
	end
end

local function refreshHeader(current: Screen)
	setText(current.counter, string.format(COUNTER_TEXT, Index.CountAll(discovered), Index.Total))
	for _, section in current.sections do
		local zone = section.def.zone
		local found: number, total: number
		if zone ~= nil then
			found, total = Index.CountZone(discovered, zone)
		else
			found, total = Index.CountSecrets(discovered)
		end
		if not section.keepName then
			setText(section.zoneName, current.tabNames[tab] or string.upper(fallbackName(section.def)))
		elseif textOf(section.zoneName) == nil then
			setText(section.zoneName, string.upper(fallbackName(section.def)))
		end
		setText(section.zoneCount, string.format(ZONE_COUNT_TEXT, found, total))
		setFill(section, if total > 0 then found / total else 0)
		setVisible(section.reward, zone ~= nil and section.rewardShown)
		if zone ~= nil then
			setText(section.rewardLabel, rewardText(zone, total > 0 and found >= total))
		end
	end
end

-- ScrollTrack suit la liste : hauteur = part visible, place = avancée du défilement.
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
	-- Haut de la piste (le point d'ancrage de Clément peut ne pas être en haut), puis haut du curseur.
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

-- En-tête d'une section, cherché sous `root`.
local function newSection(def: TabDef, root: Instance?, cardParent: Instance?, keepName: boolean): Section
	local zoneBar = if root then Find.path(root, "ZoneBar") else nil
	local fill = if zoneBar then guiObject(zoneBar, "Fill") else nil
	local reward = if root then guiObject(root, "Reward") else nil
	return {
		def = def,
		cardParent = cardParent,
		zoneName = if root then Find.path(root, "ZoneName") else nil,
		keepName = keepName,
		zoneCount = if root then Find.path(root, "ZoneCount") else nil,
		fill = fill,
		fillSize = if fill then fill.Size else UDim2.new(1, 0, 1, 0),
		reward = reward,
		rewardShown = if reward then reward.Visible else false,
		rewardLabel = if reward then Find.path(reward, "RewardLabel") else nil,
	}
end

local function legacyOf(gui: ScreenGui): ScreenGui?
	local parent = gui.Parent
	local legacy = if parent then parent:FindFirstChild(LEGACY_SCREEN) else nil
	return if legacy and legacy:IsA("ScreenGui") then legacy :: ScreenGui else nil
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
	Motion.SetCloser(gui, close) -- un autre écran du groupe ScreenGroup s'ouvre (L-089)
	local v2 = gui.Name == SCREEN
	local name = gui.Name
	if v2 then
		local legacy = legacyOf(gui)
		if legacy then
			legacy.Enabled = false -- l'ancien écran reste éteint
		end
	end

	local template = guiObject(gui, "List.Template")
	if template == nil then
		reportOnce(`template:{name}`, `[Index] {name}.List.Template introuvable : l'index restera vide`)
	else
		template.Visible = false
	end

	local sections: { Section } = {}
	if v2 then
		for _, def in SECTIONS do
			local root = Find.path(gui, def.path)
			local cards = if root then Find.path(root, "Cards") else nil
			if cards == nil then
				reportOnce(`section:{def.path}`, `[Index] {name}.{def.path}.Cards introuvable : section vide`)
			end
			table.insert(sections, newSection(def, root, cards, true))
		end
	else
		table.insert(sections, newSection(TABS[tab], Find.path(gui, "ZoneReward"), if template then template.Parent else nil, false))
	end

	-- Cartes d'exemple de Clément (Preview_*, à côté du Template ou dans un Cards) : leurs teintes
	-- d'icône sont gardées, puis elles sont retirées de la copie du joueur (comme L-041).
	local foundColor: Color3? = nil
	local silhouetteColor: Color3? = nil
	local holders: { Instance } = {}
	if template and template.Parent then
		table.insert(holders, template.Parent :: Instance)
	end
	for _, section in sections do
		local parent = section.cardParent
		if parent and not table.find(holders, parent) then
			table.insert(holders, parent)
		end
	end
	for _, holder in holders do
		for _, sibling in holder:GetChildren() do
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

	local list = if template then template.Parent else Find.path(gui, "List")
	local track = if v2 then guiObject(gui, "ScrollTrack") else nil
	local current: Screen = {
		gui = gui,
		v2 = v2,
		template = template,
		list = list,
		counter = Find.path(gui, "Counter"),
		sections = sections,
		tabNames = {},
		foundColor = foundColor or FOUND_COLOR,
		silhouetteColor = silhouetteColor or SILHOUETTE_COLOR,
		track = track,
		trackPosition = if track then track.Position else UDim2.new(),
		trackSize = if track then track.Size else UDim2.new(),
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

	if v2 then
		if track == nil then
			reportOnce("track", `[Index] {name}.ScrollTrack introuvable : pas de curseur de défilement`)
		elseif list and list:IsA("ScrollingFrame") then
			local frame = list :: ScrollingFrame
			for _, property in { "CanvasPosition", "AbsoluteCanvasSize", "AbsoluteWindowSize" } do
				keep(frame:GetPropertyChangedSignal(property):Connect(function()
					if screen == current then
						updateTrack(current)
					end
				end))
			end
			updateTrack(current)
		end
		return
	end

	-- Repli : onglets de UI_Index.
	for rank, def in TABS do
		local button = Find.path(gui, def.path)
		local label = if button then textOf(Find.path(button, TAB_LABEL)) else nil
		current.tabNames[rank] = string.upper(label or fallbackName(def))
		if button == nil then
			reportOnce(`tab:{def.path}`, `[Index] {name}.{def.path} introuvable : onglet pas branché`)
		end
		keep(onClick(button, function()
			if tab == rank then
				return
			end
			tab = rank
			current.sections[1].def = def
			if isOpen and screen == current then
				buildCards(current)
				refreshHeader(current)
				scrollTop(current)
			end
		end))
	end
end

-- L'écran à brancher dans PlayerGui : UI_Index_v2, sinon l'ancien UI_Index.
local function findScreen(playerGui: Instance): ScreenGui?
	for _, name in { SCREEN, LEGACY_SCREEN } do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then
			return gui :: ScreenGui
		end
	end
	return nil
end

-- Écran branché encore présent (l'ancien seulement si la v2 n'est pas arrivée), ou celui de PlayerGui
-- (branché au passage), ou nil.
local function currentScreen(): Screen?
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local wanted = if playerGui then findScreen(playerGui) else nil
	local current = screen
	if current and current.gui.Parent ~= nil and current.gui == wanted then
		return current
	end
	if wanted then
		bind(wanted)
		return screen
	end
	return nil
end

local function open()
	local current = currentScreen()
	if current == nil then
		reportOnce("screen", `[Index] écran {SCREEN} (ou {LEGACY_SCREEN}) absent de PlayerGui : l'index ne s'ouvre pas`)
		return
	end
	readDiscovered()
	isOpen = true
	buildCards(current)
	refreshHeader(current)
	scrollTop(current)
	updateTrack(current)
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
		if not child:IsA("ScreenGui") then
			return
		end
		if child.Name == SCREEN then
			bind(child :: ScreenGui)
		elseif child.Name == LEGACY_SCREEN then
			local current = screen
			if current and current.v2 and current.gui.Parent ~= nil then
				(child :: ScreenGui).Enabled = false -- la v2 est là : l'ancien reste éteint
			else
				bind(child :: ScreenGui)
			end
		elseif child.Name == HUD then
			bindHud(child)
		end
	end)
	local existing = findScreen(playerGui)
	if existing then
		bind(existing)
	end
	local hud = playerGui:FindFirstChild(HUD)
	if hud and hud:IsA("ScreenGui") then
		bindHud(hud)
	end
end

return IndexController
