--!strict
-- SkillTreeController (vague 27, L-096 point 2, client) : l'écran UI_SkillTree de Clément (arbre de compétences ;
-- décision de Clément du 2026-11-11 : il sort au lancement). Contrat : Config/SkillTree (en-tête), remote
-- BuySkill, attribut Skill_<Id> du joueur posé par le serveur (SkillTreeService). Note de Clément :
-- docs/claude/notes/ui-skilltree-pour-ironix.md ; animations : docs/claude/notes/ui-motion-skilltree.md (T.n),
-- valeurs dans Config/UiMotion (SkillTree, Shake, CashBump, Close…).
--
-- Rôle :
--   - UI_HUD.SkillTreeButton (caché par Clément) : montré dans tous ses exemplaires (LeftRail sur PC,
--     LeftRailTouch sur téléphone), il ouvre l'écran (un 2e appui le ferme). Sur téléphone (écran tactile sans
--     clavier, même règle que la barre du bas), LeftRailTouch est montré et LeftRail caché (décision de Clément,
--     L-096, version B : la colonne de 5 boutons déborde sur l'argent). CloseButton ferme l'écran. Groupe
--     ScreenGroup « Menu » : un seul écran du groupe à la fois (Motion.SetCloser).
--   - Tuiles (13, posées à la main dans Tree, pas de Template) : seuls les visibilités et les textes changent.
--     Calque selon le niveau (attribut Skill_<Id>, 0 s'il manque) et OpensWhen : Bought si niveau ≥ 1,
--     Available si la tuile est ouverte, Locked sinon (Info caché). Tile_Next2 toujours Locked ; RootTile
--     (« UPGRADES ») : rien à acheter, jamais choisie. Info.Level « Lv 2/5 » ; Info.TileName = DisplayName et
--     Labels[niveau] (« Glass ×2 », « Cameras II ») ; un Label qui est un mot (« Stand », « Store ») s'écrit
--     seul (V0 proposé, comme le prototype de Clément : la tuile Shop Level montre « Store ») ; Price (blanc)
--     avec le prix suivant, ou PriceNeed (rouge) quand l'argent manque ; « MAX » au dernier niveau ; « SOON »
--     quand le niveau suivant n'est pas codé (Coded) ou n'a pas de prix.
--   - InfoPanel, tuile choisie (clic sur une tuile ouverte) : NodeName (DisplayName en capitales), NodeIcon
--     (l'icône de la tuile, sinon celle de Config/SkillTree), NodeLevel « Level 1 / 4 », NodeStat = Stat,
--     NodeEffect « ×2  ▶  ×3 » (« ×8  (MAX) » au dernier niveau, « — » sans Label), NodePrice ; BuyButton
--     (envoie BuySkill) quand l'achat est possible, sinon NeedButton : « Need $4M », « MAX LEVEL » ou
--     « Coming soon ». NeedButton refuse (T.18 : secousse, son UI_Deny). Changement de tuile : SelectionGlow
--     se pose sous elle (T.55), le panneau sursaute (T.56).
--   - CashPill.Cash : l'argent du joueur (attribut Cash), qui défile (T.15, Motion.Roll) et fait sursauter
--     CashPill (T.16, CashBump) ; « … » tant que le serveur ne l'a pas posé.
--   - Achat réussi (le niveau monte pendant que l'écran est ouvert) : la tuile gonfle et revient (T.57, T.58),
--     éclat et étincelles (T.59, T.60), BuyButton saute avec UI_Success (T.33) ; chaque voisine qui s'ouvre se
--     retourne et se découvre avec un badge NEW! (T.61 ; le badge est créé par le code : l'écran n'en a pas,
--     un NewBadge caché posé par Clément dans la tuile serait montré à la place). Le serveur décide de tout :
--     le client n'envoie qu'un Id ; un 2e clic sur BUY est ignoré tant que la réponse n'est pas arrivée
--     (PENDING_TIMEOUT).
--   - Navigation (SkillTree/Nav) : glisser, molette, pincement, zoom borné, zoom à l'ouverture, couche NavLayer
--     posée par le code (T.67 à T.74). Ouverture : Motion.Open (panneau, argent, Close…) et « bop bop bop »
--     des tuiles, de la tuile centrale vers les anneaux (T.54, SkillTree/Fx) ; fermeture T.28.
-- Éléments cherchés par leur nom parmi les descendants (Contract/Find) ; un élément absent est sauté (le
-- ContractChecker le signale). Jamais d'image, de couleur ni de taille de Clément changée : seuls Visible,
-- Text, NodeIcon.Image (icône de la tuile choisie), Position de SelectionGlow et de Tree (glisser), et les
-- effets passagers de SkillTree/Fx. Un écran recréé (ResetOnSpawn) est rebranché, fermé.
--
-- API (client ; barre de commande en Studio, bancs) :
--   SkillTreeController.Open() / .Close() / .Toggle()
--   SkillTreeController.Select(tileName) -> boolean    choisit une tuile ouverte (comme un clic)
--   SkillTreeController.GetState() -> { Open, Selected, Zoom, Pan }
--   SkillTreeController.GetNav() -> Nav?              navigation de l'écran branché (zoomAt, panBy, view…)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SkillTree = require(Config:WaitForChild("SkillTree"))
local UiMotion = require(Config:WaitForChild("UiMotion"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))
local Helpers = script.Parent:WaitForChild("SkillTree")
local Fx = require(Helpers:WaitForChild("Fx"))
local Nav = require(Helpers:WaitForChild("Nav"))

type Skill = SkillTree.Skill
type LayerName = "Bought" | "Available" | "Locked"
type OfferKind = "Price" | "Need" | "Max" | "Soon"
type Offer = { kind: OfferKind, price: number? }

type Tile = {
	name: string,
	skill: Skill?, -- nil : RootTile, Tile_Next2
	button: GuiObject,
	layers: { [string]: GuiObject },
	info: GuiObject?,
	level: Instance?,
	tileName: Instance?,
	price: Instance?,
	priceNeed: Instance?,
	icon: Instance?,
	ring: number, -- anneau autour de la tuile centrale (coordonnées Q, R)
	angle: number,
	revealing: boolean, -- se découvre (T.61) : reste Locked jusqu'au retournement
}

type Panel = {
	root: GuiObject?,
	nodeName: Instance?,
	nodeIcon: Instance?,
	nodeLevel: Instance?,
	nodeStat: Instance?,
	nodeEffect: Instance?,
	nodePrice: Instance?,
	buy: GuiButton?,
	need: GuiButton?,
	needLabel: Instance?,
}

type Screen = {
	gui: ScreenGui,
	tree: GuiObject?,
	tiles: { Tile }, -- de la tuile centrale vers les anneaux
	byName: { [string]: Tile },
	bySkill: { [string]: Tile },
	hexes: { GuiObject }, -- boutons des tuiles (pour Nav)
	glow: GuiObject?,
	panel: Panel,
	cash: TextLabel?,
	cashPill: GuiObject?,
	nav: Nav.Nav?,
	tileWidth: number, -- largeur d'une tuile au zoom 1 (px), mesurée à l'ouverture
	shownCash: number?, -- dernier argent écrit (départ du défilement)
	connections: { RBXScriptConnection },
}

local SCREEN = "UI_SkillTree"
local HUD = "UI_HUD"
local HUD_BUTTON = "SkillTreeButton"
local RAIL_PC = "LeftRail"
local RAIL_TOUCH = "LeftRailTouch"
local CASH_ATTRIBUTE = "Cash" -- posé par DataService sur le Player
local REMOTE = "BuySkill"
local LAYERS: { LayerName } = { "Bought", "Available", "Locked" }
local BODY = "Body" -- corps de l'hexagone dans chaque calque (copié pour l'éclat, T.59)

-- V0 proposés, absents du doc : textes de l'écran, en anglais (L-036), repris du prototype de Clément
-- (tools/clement/skilltree_proto.luau) et de sa note.
local LEVEL_TEXT = "Lv %d/%d" -- Info.Level
local NODE_LEVEL_TEXT = "Level %d / %d" -- InfoPanel.NodeLevel
local EFFECT_TEXT = "%s  ▶  %s" -- NodeEffect : actuel, suivant
local EFFECT_MAX_TEXT = "%s  (MAX)"
local NO_LABEL = "—" -- rien de décidé (note de Clément)
local MAX_TEXT = "MAX"
local SOON_TEXT = "SOON"
local NEED_TEXT = "Need %s"
local NEED_MAX_TEXT = "MAX LEVEL"
local NEED_SOON_TEXT = "Coming soon"
local UNKNOWN_TEXT = "…" -- argent pas encore posé par le serveur (comme le HUD)
-- V0 proposé, absent du doc : un 2e clic sur BUY pour la même compétence est ignoré pendant ce temps (s), sauf
-- si le niveau a changé entre-temps (réponse du serveur arrivée).
local PENDING_TIMEOUT = 1

local M = UiMotion.SkillTree
local PANEL_INFO = TweenInfo.new(M.PanelTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CASH_BUMP_INFO = TweenInfo.new(UiMotion.CashBump.Time, UiMotion.CashBump.Style, UiMotion.CashBump.Direction)
local IS_STUDIO = RunService:IsStudio()

local SkillTreeController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local selected: string? = nil -- nom de la tuile choisie
local hovered: GuiObject? = nil
local known: { [string]: number } = {} -- dernier niveau vu, par Id
local pending: { [string]: number } = {} -- envoi BuySkill en attente (os.clock), par Id
local net: any = nil
local reported: { [string]: boolean } = {}
local hudBound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

------------------------------------------------------------------------------
-- Règles des tuiles (Config/SkillTree)
------------------------------------------------------------------------------

local function levelOf(id: string): number
	local value = localPlayer:GetAttribute(SkillTree.AttributePrefix .. id)
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(0, math.floor(value))
end

local function cashOf(): number?
	local value = localPlayer:GetAttribute(CASH_ATTRIBUTE)
	return if type(value) == "number" and value == value then value else nil
end

local function isOpenSkill(skill: Skill): boolean
	local opens = skill.OpensWhen
	return opens == nil or levelOf(opens.Id) >= opens.Level
end

local function layerOf(skill: Skill): LayerName
	if levelOf(skill.Id) >= 1 then
		return "Bought"
	end
	return if isOpenSkill(skill) then "Available" else "Locked"
end

-- Ce que montre le prix : le prochain niveau, l'argent qui manque, le maximum ou « bientôt ».
local function offerOf(skill: Skill, level: number, cash: number?): Offer
	if level >= skill.MaxLevel then
		return { kind = "Max" }
	end
	local price = skill.Prices[level + 1]
	if level + 1 > skill.Coded or price == nil then
		return { kind = "Soon" }
	end
	if cash == nil or cash < price then
		return { kind = "Need", price = price }
	end
	return { kind = "Price", price = price }
end

-- Un Label qui est un mot (« Stand », « Concept Store ») est un nom à lui seul ; « ×2 », « II », « 30s »
-- complètent le nom de la compétence.
local function isWord(label: string): boolean
	return string.match(label, "^%u%l") ~= nil
end

local function tileNameOf(skill: Skill, level: number): string
	local label = skill.Labels[level]
	if label == nil or label == "" then
		return skill.DisplayName
	end
	return if isWord(label) then label else `{skill.DisplayName} {label}`
end

local function effectOf(skill: Skill, level: number): string
	local current = skill.Labels[level] or NO_LABEL
	if level >= skill.MaxLevel then
		return string.format(EFFECT_MAX_TEXT, current)
	end
	return string.format(EFFECT_TEXT, current, skill.Labels[level + 1] or NO_LABEL)
end

------------------------------------------------------------------------------
-- Écriture (textes et visibilités seulement)
------------------------------------------------------------------------------

local function setText(element: Instance?, text: string)
	if element and (element:IsA("TextLabel") or element:IsA("TextButton")) then
		local label = element :: any
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

local function guiObject(root: Instance, path: string): GuiObject?
	local found = Find.path(root, path)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function button(root: Instance, path: string): GuiButton?
	local found = Find.path(root, path)
	return if found and found:IsA("GuiButton") then found :: GuiButton else nil
end

local function imageOf(element: Instance?): string?
	if element and (element:IsA("ImageLabel") or element:IsA("ImageButton")) then
		return (element :: any).Image
	end
	return nil
end

local function refreshTile(tile: Tile)
	local skill = tile.skill
	if skill == nil then
		if tile.name == SkillTree.NeverTile then
			for _, name in LAYERS do
				setVisible(tile.layers[name], name == "Locked")
			end
			setVisible(tile.info, false)
		end
		return
	end
	if tile.revealing then
		return -- encore Locked jusqu'au retournement (T.61)
	end
	local level = levelOf(skill.Id)
	local layer = layerOf(skill)
	for _, name in LAYERS do
		setVisible(tile.layers[name], name == layer)
	end
	setVisible(tile.info, layer ~= "Locked")
	setText(tile.level, string.format(LEVEL_TEXT, level, skill.MaxLevel))
	setText(tile.tileName, tileNameOf(skill, level))
	local offer = offerOf(skill, level, cashOf())
	local need = offer.kind == "Need"
	setVisible(tile.price, not need)
	setVisible(tile.priceNeed, need)
	if need then
		setText(tile.priceNeed, Format.money(offer.price :: number))
	elseif offer.kind == "Price" then
		setText(tile.price, Format.money(offer.price :: number))
	else
		setText(tile.price, if offer.kind == "Max" then MAX_TEXT else SOON_TEXT)
	end
end

local function selectedTile(current: Screen): Tile?
	local name = selected
	return if name then current.byName[name] else nil
end

local function refreshPanel(current: Screen)
	local tile = selectedTile(current)
	local skill = if tile then tile.skill else nil
	if tile == nil or skill == nil then
		return
	end
	local panel = current.panel
	local level = levelOf(skill.Id)
	setText(panel.nodeName, string.upper(skill.DisplayName))
	local icon = panel.nodeIcon
	local texture = imageOf(tile.icon)
	if texture == nil or texture == "" then
		texture = skill.Icon or ""
	end
	if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) and (icon :: any).Image ~= texture then
		(icon :: any).Image = texture
	end
	setText(panel.nodeLevel, string.format(NODE_LEVEL_TEXT, level, skill.MaxLevel))
	setText(panel.nodeStat, skill.Stat)
	setText(panel.nodeEffect, effectOf(skill, level))
	local offer = offerOf(skill, level, cashOf())
	local priceText = if offer.kind == "Max" then MAX_TEXT
		elseif offer.kind == "Soon" then SOON_TEXT
		else Format.money(offer.price :: number)
	setText(panel.nodePrice, priceText)
	local canBuy = offer.kind == "Price" and layerOf(skill) ~= "Locked"
	setVisible(panel.buy, canBuy)
	setVisible(panel.need, not canBuy)
	local needText = if offer.kind == "Max" then NEED_MAX_TEXT
		elseif offer.kind == "Soon" then NEED_SOON_TEXT
		else string.format(NEED_TEXT, Format.money(offer.price :: number))
	setText(panel.needLabel, needText)
end

local function refreshAll(current: Screen)
	for _, tile in current.tiles do
		refreshTile(tile)
	end
	refreshPanel(current)
end

-- Argent de CashPill : défile (et CashPill sursaute) quand `animate`, sinon écrit d'un coup.
local function writeCash(current: Screen, animate: boolean)
	local label = current.cash
	if label == nil then
		return
	end
	local cash = cashOf()
	if cash == nil then
		Motion.StopRoll(label)
		label.Text = UNKNOWN_TEXT
		current.shownCash = nil
		return
	end
	local from = current.shownCash
	if animate and from ~= nil and from ~= cash then
		Motion.Roll(label, from, cash, Format.money)
		local pill = current.cashPill
		if pill then
			Motion.Pop(pill, UiMotion.CashBump.From, CASH_BUMP_INFO)
		end
	elseif not animate or from == nil then
		Motion.StopRoll(label)
		label.Text = Format.money(cash)
	end
	current.shownCash = cash
end

------------------------------------------------------------------------------
-- Choix d'une tuile, achat, refus
------------------------------------------------------------------------------

-- La première tuile ouverte, dans l'ordre de Config/SkillTree.
local function defaultTile(current: Screen): Tile?
	for _, skill in SkillTree.List do
		local tile = current.bySkill[skill.Id]
		if tile and layerOf(skill) ~= "Locked" then
			return tile
		end
	end
	return nil
end

-- Choisit `tile` (ouverte) : contour dessous, panneau à jour ; `animate` : T.55 et T.56.
local function choose(current: Screen, tile: Tile, animate: boolean): boolean
	local skill = tile.skill
	if skill == nil or tile.revealing or layerOf(skill) == "Locked" then
		return false
	end
	local changed = selected ~= tile.name
	selected = tile.name
	local glow = current.glow
	if glow then
		if animate and changed then
			Fx.moveGlow(glow, tile.button.Position)
		elseif not animate then
			Fx.placeGlow(glow, tile.button.Position)
		end
	end
	refreshPanel(current)
	local root = current.panel.root
	if animate and changed and root then
		Motion.Pop(root, M.PanelFrom, PANEL_INFO)
	end
	return true
end

local function deny(target: GuiObject?)
	if target then
		Fx.shake(target)
	end
	Motion.PlaySound(UiMotion.Sounds.Deny)
end

local function sendBuy(id: string)
	local api = net
	if api == nil then
		reportOnce("net", `[SkillTree] Net pas encore prêt : {REMOTE}({id}) pas envoyé`)
		return
	end
	local ok, err = pcall(function()
		api.Client[REMOTE]:Fire(id)
	end)
	if not ok then
		reportOnce("fire", `[SkillTree] {REMOTE} : envoi impossible ({err})`)
	end
end

local function onBuy()
	local current = screen
	if current == nil then
		return
	end
	local tile = selectedTile(current)
	local skill = if tile then tile.skill else nil
	if skill == nil then
		return
	end
	local offer = offerOf(skill, levelOf(skill.Id), cashOf())
	if offer.kind ~= "Price" or layerOf(skill) == "Locked" then
		deny(current.panel.buy)
		refreshPanel(current)
		return
	end
	local sentAt = pending[skill.Id]
	if sentAt ~= nil and os.clock() - sentAt < PENDING_TIMEOUT then
		return -- réponse du serveur pas encore arrivée
	end
	pending[skill.Id] = os.clock()
	sendBuy(skill.Id)
end

local function onNeed()
	local current = screen
	if current then
		deny(current.panel.need)
	end
end

------------------------------------------------------------------------------
-- Achat réussi (le niveau monte, T.57 à T.61 et T.33)
------------------------------------------------------------------------------

local function fontOf(tile: Tile): Font?
	local label = tile.tileName
	if label and label:IsA("TextLabel") then
		return (label :: TextLabel).FontFace
	end
	return nil
end

local function celebrate(current: Screen, skill: Skill, old: number, new: number)
	local tree = current.tree
	local tile = current.bySkill[skill.Id]
	-- Voisines qui s'ouvrent avec ce niveau : elles restent Locked jusqu'à leur retournement.
	local reveals: { Tile } = {}
	for _, other in SkillTree.List do
		local opens = other.OpensWhen
		local otherTile = current.bySkill[other.Id]
		if opens and opens.Id == skill.Id and opens.Level > old and opens.Level <= new and otherTile
			and levelOf(other.Id) == 0 then
			otherTile.revealing = true
			table.insert(reveals, otherTile)
		end
	end
	refreshAll(current)
	if tile then
		Fx.punch(tile.button)
		local body = Find.path(tile.layers.Bought or tile.button, BODY)
		if body and body:IsA("GuiObject") then
			Fx.flash(body :: GuiObject)
		end
		if tree then
			Fx.sparks(tree, tile.button, current.tileWidth)
		end
	end
	local buy = current.panel.buy
	if buy then
		Motion.Success(buy)
	end
	for _, other in reveals do
		local function uncover()
			other.revealing = false
			refreshTile(other)
		end
		if tree then
			Fx.reveal(tree, other.button, current.tileWidth, fontOf(other), uncover)
		else
			uncover()
		end
	end
end

local function onSkillChanged(skill: Skill)
	local new = levelOf(skill.Id)
	local old = known[skill.Id]
	known[skill.Id] = new
	if old ~= new then
		pending[skill.Id] = nil
	end
	local current = screen
	if current == nil or current.gui.Parent == nil then
		return
	end
	if isOpen and old ~= nil and new > old then
		celebrate(current, skill, old, new)
	else
		refreshAll(current)
	end
end

local function onCashChanged()
	local current = screen
	if current == nil or current.gui.Parent == nil then
		return
	end
	refreshAll(current)
	writeCash(current, isOpen)
end

------------------------------------------------------------------------------
-- Écran
------------------------------------------------------------------------------

-- Anneau (distance hexagonale à la tuile centrale) et angle d'une tuile, depuis ses attributs Q et R.
local function ringOf(object: Instance): (number, number)
	local q = object:GetAttribute("Q")
	local r = object:GetAttribute("R")
	local qn = if type(q) == "number" then q else 0
	local rn = if type(r) == "number" then r else 0
	return (math.abs(qn) + math.abs(rn) + math.abs(qn + rn)) / 2, math.atan2(rn, qn)
end

local function newTile(object: GuiObject, skill: Skill?): Tile
	local layers: { [string]: GuiObject } = {}
	for _, name in LAYERS do
		local layer = guiObject(object, name)
		if layer then
			layers[name] = layer
		end
	end
	local info = guiObject(object, "Info")
	local ring, angle = ringOf(object)
	return {
		name = object.Name,
		skill = skill,
		button = object,
		layers = layers,
		info = info,
		level = if info then Find.path(info, "Level") else nil,
		tileName = if info then Find.path(info, "TileName") else nil,
		price = if info then Find.path(info, "PriceRow.Price") else nil,
		priceNeed = if info then Find.path(info, "PriceRow.PriceNeed") else nil,
		icon = if info then Find.path(info, "Icon") else nil,
		ring = ring,
		angle = angle,
		revealing = false,
	}
end

local function treeObjects(current: Screen): { GuiObject }
	local list: { GuiObject } = {}
	for _, tile in current.tiles do
		table.insert(list, tile.button)
	end
	if current.glow then
		table.insert(list, current.glow :: GuiObject)
	end
	return list
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	local current = screen
	if current == nil then
		return
	end
	local objects = treeObjects(current)
	Fx.shrink(objects)
	Motion.Close(current.gui, function()
		for _, object in objects do
			Fx.dropScale(object)
		end
	end)
end

local function unbind(current: Screen)
	for _, connection in current.connections do
		connection:Disconnect()
	end
	table.clear(current.connections)
	local nav = current.nav
	if nav then
		nav.destroy()
	end
end

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		unbind(old)
	end
	isOpen = false
	hovered = nil
	gui.Enabled = false -- fermé jusqu'au bouton du HUD
	Motion.SetCloser(gui, close) -- un autre écran du groupe ScreenGroup s'ouvre (L-089)

	local tree = guiObject(gui, "Tree")
	local panelRoot = guiObject(gui, "InfoPanel")
	local panelBase: Instance = panelRoot or gui
	local cashLabel = Find.path(gui, "CashPill.Cash")
	local current: Screen = {
		gui = gui,
		tree = tree,
		tiles = {},
		byName = {},
		bySkill = {},
		hexes = {},
		glow = if tree then guiObject(tree, "SelectionGlow") else nil,
		panel = {
			root = panelRoot,
			nodeName = Find.path(panelBase, "NodeName"),
			nodeIcon = Find.path(panelBase, "NodeIcon"),
			nodeLevel = Find.path(panelBase, "NodeLevel"),
			nodeStat = Find.path(panelBase, "NodeStat"),
			nodeEffect = Find.path(panelBase, "NodeEffect"),
			nodePrice = Find.path(panelBase, "NodePrice"),
			buy = button(panelBase, "BuyButton"),
			need = button(panelBase, "NeedButton"),
			needLabel = Find.path(panelBase, "NeedLabel"),
		},
		cash = if cashLabel and cashLabel:IsA("TextLabel") then cashLabel :: TextLabel else nil,
		cashPill = guiObject(gui, "CashPill"),
		nav = nil,
		tileWidth = 0,
		shownCash = nil,
		connections = {},
	}
	screen = current

	if tree == nil then
		reportOnce("tree", `[SkillTree] {SCREEN}.Tree introuvable : pas de tuiles`)
	else
		local treeFrame = tree :: GuiObject
		-- Tuiles de compétence (champ Tile de Config/SkillTree), RootTile et Tile_Next2.
		local wanted: { [string]: Skill | boolean } = { [SkillTree.RootTile] = true, [SkillTree.NeverTile] = true }
		for _, skill in SkillTree.List do
			wanted[skill.Tile] = skill
		end
		for name, value in wanted do
			local object = guiObject(treeFrame, name)
			if object == nil then
				reportOnce(`tile:{name}`, `[SkillTree] {SCREEN}.Tree.{name} introuvable`)
				continue
			end
			local skill: Skill? = if type(value) == "table" then value :: Skill else nil
			local tile = newTile(object, skill)
			table.insert(current.tiles, tile)
			current.byName[name] = tile
			if skill then
				current.bySkill[skill.Id] = tile
			end
		end
		table.sort(current.tiles, function(a: Tile, b: Tile): boolean
			if a.ring ~= b.ring then
				return a.ring < b.ring
			end
			if a.angle ~= b.angle then
				return a.angle < b.angle
			end
			return a.name < b.name
		end)
		for _, tile in current.tiles do
			table.insert(current.hexes, tile.button)
		end
		-- Tree s'anime à part (zoom, « bop » des tuiles) : Motion.Open ne le met pas à l'échelle.
		Motion.KeepScale(treeFrame)
		current.nav = Nav.new(gui, treeFrame, {
			tiles = function(): { GuiObject }
				return current.hexes
			end,
			tap = function(object: GuiObject)
				local tile = current.byName[object.Name]
				if tile then
					choose(current, tile, true)
				end
			end,
			hover = function(object: GuiObject?)
				local previous = hovered
				hovered = object
				if previous then
					Fx.hover(previous, false)
				end
				if object then
					Fx.hover(object, true)
				end
			end,
			press = function(object: GuiObject)
				Fx.press(object)
			end,
			release = function(object: GuiObject)
				Fx.release(object, object == hovered)
			end,
		})
	end

	local closeButton = button(gui, "CloseButton")
	if closeButton then
		table.insert(current.connections, closeButton.Activated:Connect(close))
	end
	local buy = current.panel.buy
	if buy then
		table.insert(current.connections, buy.Activated:Connect(onBuy))
	end
	local need = current.panel.need
	if need then
		table.insert(current.connections, need.Activated:Connect(onNeed))
	end
	refreshAll(current)
	writeCash(current, false)
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
		reportOnce("screen", `[SkillTree] écran {SCREEN} absent de PlayerGui : le bouton Upgrades n'ouvre rien`)
		return
	end
	isOpen = true
	local objects = treeObjects(current)
	-- UIScale des tuiles posés avant Motion.Open : il ne les fait pas entrer une à une (OpenStagger), le
	-- « bop » s'en charge (T.54).
	for _, object in objects do
		Fx.scaleOf(object, 1)
	end
	refreshAll(current)
	writeCash(current, false)
	Motion.Open(current.gui)
	local nav = current.nav
	if nav then
		current.tileWidth = nav.reset()
	end
	local tile = selectedTile(current)
	if tile == nil or not choose(current, tile, false) then
		local first = defaultTile(current)
		if first then
			choose(current, first, false)
		end
	end
	local ordered: { GuiObject } = {}
	for _, item in current.tiles do
		table.insert(ordered, item.button)
	end
	Fx.bop(ordered, current.glow)
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

local function isPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function bindHud(gui: Instance)
	if hudBound[gui] then
		return
	end
	local bound = 0
	for _, found in Find.all(gui, HUD_BUTTON) do
		if found:IsA("GuiButton") then
			local hudButton = found :: GuiButton
			hudButton.Visible = true
			hudButton.Activated:Connect(toggle)
			bound += 1
		end
	end
	if bound == 0 then
		reportOnce("hud", `[SkillTree] {HUD}.{HUD_BUTTON} introuvable ou pas un bouton : l'écran {SCREEN} ne s'ouvre pas`)
		return
	end
	hudBound[gui] = true
	-- Téléphone (L-096, version B) : la colonne en 2 colonnes à la place de la colonne du PC.
	local pc = guiObject(gui, RAIL_PC)
	local touch = guiObject(gui, RAIL_TOUCH)
	if pc and touch and isPhone() then
		touch.Visible = true
		pc.Visible = false
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function SkillTreeController.Open()
	if not isOpen then
		open()
	end
end

function SkillTreeController.Close()
	close()
end

function SkillTreeController.Toggle()
	toggle()
end

function SkillTreeController.Select(tileName: string): boolean
	local current = currentScreen()
	local tile = if current then current.byName[tileName] else nil
	if current == nil or tile == nil then
		return false
	end
	return choose(current, tile, isOpen)
end

function SkillTreeController.GetState(): { Open: boolean, Selected: string?, Zoom: number, Pan: Vector2 }
	local current = screen
	local nav = if current then current.nav else nil
	local zoom, pan = 1, Vector2.zero
	if nav then
		zoom, pan = nav.view()
	end
	return { Open = isOpen, Selected = selected, Zoom = zoom, Pan = pan }
end

function SkillTreeController.GetNav(): Nav.Nav?
	local current = screen
	return if current then current.nav else nil
end

function SkillTreeController.Start()
	for _, skill in SkillTree.List do
		-- Pas encore posé (profil en cours de chargement) : son arrivée n'est pas un achat.
		if localPlayer:GetAttribute(SkillTree.AttributePrefix .. skill.Id) ~= nil then
			known[skill.Id] = levelOf(skill.Id)
		end
		localPlayer:GetAttributeChangedSignal(SkillTree.AttributePrefix .. skill.Id):Connect(function()
			onSkillChanged(skill)
		end)
	end
	localPlayer:GetAttributeChangedSignal(CASH_ATTRIBUTE):Connect(onCashChanged)

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

	-- Peut attendre que le serveur ait créé les remotes : en dernier.
	local ok, result = pcall(function(): any
		return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	end)
	if ok then
		net = result
	else
		reportOnce("net", `[SkillTree] Net introuvable : les achats ne partent pas ({result})`)
	end
end

return SkillTreeController
