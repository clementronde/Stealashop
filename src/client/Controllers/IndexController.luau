--!strict
-- IndexController (DEV-111, client) : l'index des objets, écran UI_Index_v3 de Clément (L-095 point 1 :
-- l'Index du jeu de référence, docs/claude/notes/ui-index-v3.md), avec repli sur UI_Index_v2 (L-083,
-- points 5 et 6), puis sur l'ancien UI_Index (onglets, maquette UI-111), tant que la v3 n'est pas dans
-- PlayerGui. Partie 2, section 3.4 ; règles : Config/Index ; découvertes : IndexService.
-- Seulement si Features.Index : à false, rien n'est branché et l'écran reste fermé.
--
-- Rôle commun :
--   - UI_HUD.IndexButton (tous les exemplaires : LeftRail et LeftRailTouch) ouvre l'écran (un 2e appui
--     le ferme) ; CloseButton le ferme. Ouverture et
--     fermeture animées par UI/Motion (groupe ScreenGroup de l'écran, Motion.SetCloser), comme les
--     boutiques : les cartes sont retirées une fois l'écran éteint, et une réouverture pendant la
--     fermeture la rattrape. L'écran branché éteint les plus anciens (Enabled) ;
--   - une carte par objet (Config/Index : ordre du catalogue, objet du tuto compris), clonée depuis
--     List.Template et nommée Item_<nn>_<ItemId> (LayoutOrder = rang dans sa zone), Rays et Glow (dans
--     son cadre Clip) teints de la couleur de la rareté (Config/Rarities), découvert ou pas ;
--   - l'écran suit l'attribut IndexDiscovered du Player (IndexService) : une découverte le met à jour
--     s'il est ouvert. Rien n'est envoyé au serveur.
--
-- UI_Index_v3 (ui-index-v3.md, « Mise en page » et « Pour Ironix ») :
--   - List : Zone1Section à Zone6Section et SecretsSection ; dans chacune, les cartes vont dans son
--     Content.Cards ; ZoneArt.ZoneName = les magasins PNJ de la zone (Config/Zones.Stores, « MINI MART / KIOSK » sur 2 lignes,
--     vague 24 ; SecretsSection : texte de Clément gardé, écrit seulement s'il est vide) ;
--     Content.ZoneBar : Fill (part trouvée), ZoneCount « 4/13 », ZoneItem = l'objet le plus rare de la
--     section (rareté la plus haute, le dernier du catalogue à égalité), en silhouette tant qu'il n'est
--     pas trouvé ;
--   - carte (Template, un TextButton) : Clip.BackgroundColor3 = couleur de la rareté, assombrie
--     (View.ClipDarken) si l'objet n'est pas trouvé ; Secret : le UIGradient de Clip prend les couleurs
--     de l'arc-en-ciel (Rarities.RainbowColors). Icon = ICON_<ItemId> ; trouvé : Icon blanc, ItemName =
--     le nom (« Soda Can ») ; pas trouvé : silhouette (Icon.ImageColor3 = couleur de la rareté vers le
--     noir, View.SilhouetteDarken) et « ??? ». Lock n'est pas touché (caché par Clément). Survol : rien
--     ici (UiFeelController : HoverCard) ;
--   - Detail, la fiche de l'objet cliqué (Template.Activated, jamais au survol ; le son de clic est
--     celui de SettingsController) : fond (BackgroundColor3) à la couleur de la rareté (UIGradient
--     arc-en-ciel pour un Secret, celui de Clément sinon), IconFrame.DetailIcon (silhouette s'il n'est
--     pas trouvé), DetailName (« ??? »), DetailRarity (nom de la rareté, TextColor3 de sa couleur
--     éclaircie, View.RarityLighten), DetailIncome « $X/s » (Formulas.ItemIncome dans la zone de l'objet ;
--     un Secret, qui rapporte selon la zone où il est volé : « $X-$Y/s », de la zone 1 à la zone 6 ;
--     « ??? » s'il n'est pas trouvé). À l'ouverture : le dernier objet cliqué, sinon le 1er de la zone 1.
--     Animation T.45 DetailPop (Motion.Pop sur DetailIcon) à chaque clic ;
--   - Rewards, la récompense de la zone visible dans la liste (la dernière section visible dont le haut
--     est passé à moins de View.ViewMargin px sous le haut de la liste) : SpeedReward.Amount « +3% » (Icon vide :
--     l'icône de vitesse du HUD, SpeedRow.SpeedIcon.IconImage)
--     (Index.ZoneSpeedBonus), CashReward.Amount « +$10.2K » (Index.ZoneCash). Vague 34 (L-127 point 2) : la
--     prime d'une zone complète attend d'être réclamée (IndexService). ClaimButton réclame la zone visible
--     (remote ClaimIndexReward(zone)) ; UnlockedBar.ClaimAllButton toutes les zones complètes pas encore
--     réclamées, en une demande (ClaimIndexReward sans zone) ; le serveur revérifie tout. Rien à réclamer
--     (zone pas complète, déjà réclamée, aucune zone) : View.Deny (son UI_Deny, le bouton tremble). Réussite :
--     T.33 Success (Motion.Success) sur le bouton quand le serveur confirme (attribut IndexClaimed), au plus
--     CLAIM_WAIT s après la demande ; un 2e clic avant la réponse n'envoie rien. ClaimLabel dit CLAIMED_TEXT
--     une fois la zone réclamée, sinon le texte de Clément. T.46 RewardsSwap (Motion.Pop sur Rewards) quand
--     la zone visible change ;
--   - pastilles « ! » (L-127 point 3, UI/AlertBadge : visibles et battantes tant qu'il y a à réclamer,
--     éteintes une fois réclamé, écran ouvert ou pas) : ClaimAllButton.ClaimAllAlert et
--     Categories.NormalButton.CategoryAlert (au moins une zone à réclamer), Rewards.ClaimButton.ClaimAlert
--     (la zone visible), Zone<N>Section.ZoneArt.ZoneAlert (cette zone) ; SecretsSection.ZoneArt.ZoneAlert,
--     SecretsButton et MutationsButton.CategoryAlert restent éteintes (rien à y réclamer). La pastille
--     IndexAlert du HUD est allumée par RailAlertController ;
--   - Categories : NormalButton (les zones), SecretsButton (SecretsSection seule), MutationsButton (les
--     zones, MutationTabs et MutationCaption montrés) ; Selected allumé sur la catégorie choisie ; Rewards
--     caché hors de NORMAL. Un index par mutation n'existe pas côté serveur : en MUTATIONS, toutes les
--     cartes sont des silhouettes et les compteurs à 0. MutationTabs.<Effet>Tab (Config/Mutations.Effects)
--     : Selected sur l'onglet choisi, MutationCaption « Collect every item in SHINY! ». Changement de
--     catégorie ou d'onglet : la liste remonte, les cartes entrent une par une (T.29, View.CardsIn) ; les
--     onglets de mutation entrent à leur tour (View.TabsIn) ;
--   - UnlockedBar.Counter « Unlocked: 7/83 ».
-- UI_Index_v2 (repli) : List, 7 sections (Cards, ZoneName, ZoneBar.Fill, ZoneCount, Reward.RewardLabel),
--   Counter « 23 / 83 discovered », ScrollTrack (curseur de défilement qui suit la liste), cartes avec
--   Lock et RarityBar.Rarity ; teintes de l'icône lues sur les cartes d'exemple Preview_* (retirées).
-- UI_Index (repli) : 7 onglets Tabs.Zone1Tab à Zone6Tab et Tabs.SecretsTab, un seul en-tête ZoneReward.
--
-- Seuls sont touchés (2.2, « Libre pour Ironix ») : Enabled des écrans, les textes, la visibilité, les
-- cartes clonées (nom, ordre), l'image et la teinte des icônes (cartes, DetailIcon, ZoneItem), la couleur
-- des rayons, du fond Clip des cartes et du fond de Detail (et leur UIGradient pour un Secret), la
-- couleur du texte de DetailRarity, la largeur de ZoneBar.Fill, le défilement de la liste, la position
-- et la hauteur de ScrollTrack (v2), la place de ClaimButton et de ClaimAllButton le temps qu'ils
-- tremblent, la visibilité et le UIScale Pulse des pastilles « ! » ; l'effet d'échelle de Motion est
-- passager. Écran recréé (ResetOnSpawn) : rebranché, fermé.
--
-- API (client) : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Formulas = require(Config:WaitForChild("Formulas"))
local Index = require(Config:WaitForChild("Index"))
local Items = require(Config:WaitForChild("Items"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Zones = require(Config:WaitForChild("Zones"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local Icons = require(Contract:WaitForChild("Icons"))
local Format = require(Shared:WaitForChild("Format"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))
local AlertBadge = require(Shared:WaitForChild("AlertBadge"))

type Item = Items.Item

-- Une zone de l'index (nil = les Secrets) et son chemin dans l'écran (contrat 2.2) : onglet de UI_Index
-- ou section de UI_Index_v2 et v3.
type TabDef = { zone: number?, path: string }

-- Une carte clonée.
type Card = {
	item: Item,
	frame: GuiObject,
	icon: GuiObject?,
	lock: GuiObject?,
	name: Instance?,
	clip: GuiObject?,
	found: boolean?, -- état peint (nil : pas encore peint)
}

-- Un en-tête et ses cartes : une section de UI_Index_v2 / v3, ou l'unique ZoneReward de UI_Index (sa
-- zone suit l'onglet ouvert).
type Section = {
	def: TabDef,
	root: GuiObject?, -- la section (v2, v3)
	cardParent: Instance?, -- Cards de la section (v2, v3), List (repli)
	zoneName: Instance?,
	keepName: boolean, -- v2, v3 : le texte de Clément est gardé (écrit seulement s'il est vide)
	zoneCount: Instance?,
	fill: GuiObject?,
	fillSize: UDim2, -- taille de Fill posée par Clément : seule la largeur en Scale change
	reward: GuiObject?,
	rewardShown: boolean, -- visibilité de Reward posée par Clément
	rewardLabel: Instance?,
	zoneItem: GuiObject?, -- v3 : l'objet le plus rare de la section
	zoneAlert: GuiObject?, -- v3 : ZoneArt.ZoneAlert (L-127)
}

-- Écran branché.
type Screen = {
	gui: ScreenGui,
	v2: boolean, -- une liste à sections (UI_Index_v2 ou v3)
	v3: boolean,
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
	-- v3
	detail: GuiObject?,
	detailGradient: UIGradient?,
	detailGradientBase: ColorSequence?, -- couleurs du UIGradient de Detail posées par Clément
	detailIcon: GuiObject?,
	detailName: Instance?,
	detailRarity: Instance?,
	detailIncome: Instance?,
	rewards: GuiObject?,
	rewardsShown: boolean, -- visibilité de Rewards posée par Clément
	speedAmount: Instance?,
	speedIcon: Instance?, -- Rewards.SpeedReward.Icon, remplie avec l'icône de vitesse du HUD si vide
	cashAmount: Instance?,
	claimButton: GuiObject?,
	claimLabel: Instance?,
	claimText: string?, -- texte de ClaimLabel posé par Clément (« Claim! »)
	viewSection: number?, -- rang dans sections de la section visible dans la liste (Rewards)
	categories: { [string]: GuiObject }, -- [NormalButton…] = bouton
	mutationTabs: GuiObject?,
	mutationTabButtons: { [string]: GuiObject }, -- [Id de l'effet] = onglet
	caption: Instance?,
	shaking: { [GuiObject]: boolean }, -- boutons qui tremblent (View.Deny)
	claimAllButton: GuiObject?, -- UnlockedBar.ClaimAllButton (L-127)
	claimAllAlert: GuiObject?,
	claimAlert: GuiObject?, -- Rewards.ClaimButton.ClaimAlert
	categoryAlert: GuiObject?, -- Categories.NormalButton.CategoryAlert
}

local SCREEN = "UI_Index_v3"
local V2_SCREEN = "UI_Index_v2" -- repli, tant que la v3 n'est pas livrée
local LEGACY_SCREEN = "UI_Index" -- repli, tant que la v2 n'est pas livrée
local SCREEN_ORDER = { SCREEN, V2_SCREEN, LEGACY_SCREEN } -- du plus récent au plus ancien
local HUD = "UI_HUD"
local HUD_BUTTON = "IndexButton"
local CARD_FORMAT = "Item_%02d_%s" -- nom des cartes clonées (jamais « Template »)
local PREVIEW_PREFIX = "Preview_"
local TAB_LABEL = "TabLabel"
local SELECTED = "Selected"
-- Éléments d'une carte teints à la couleur de la rareté (dans son cadre Clip).
local TINTED = { "Rays", "Glow" }
-- Catégories de UI_Index_v3 (Root.Categories).
local NORMAL = "NormalButton"
local SECRETS = "SecretsButton"
local MUTATIONS = "MutationsButton"
local CATEGORIES = { NORMAL, SECRETS, MUTATIONS }

-- Zones de l'index, dans l'ordre de l'écran : zones 1 à 6, puis les Secrets.
local TABS: { TabDef } = {} -- onglets de UI_Index
local SECTIONS: { TabDef } = {} -- sections de UI_Index_v2 et v3
for zone = 1, Index.ZoneCount do
	table.insert(TABS, { zone = zone, path = `Tabs.Zone{zone}Tab` })
	table.insert(SECTIONS, { zone = zone, path = `Zone{zone}Section` })
end
table.insert(TABS, { zone = nil, path = "Tabs.SecretsTab" })
table.insert(SECTIONS, { zone = nil, path = "SecretsSection" })

-- Textes, en anglais (L-036). V0 proposé, absent du doc, sauf le format du compteur et de la
-- récompense, repris de la maquette de Clément (« 23 / 74 discovered », « 9 / 13 », « +5% INCOME ») et,
-- pour la v3, de son prototype (« Unlocked: 7/83 », « 4/13 », « Collect every item in SHINY! »).
local COUNTER_TEXT = "%d / %d discovered"
local ZONE_COUNT_TEXT = "%d / %d"
local V3_COUNTER_TEXT = "Unlocked: %d/%d"
local V3_ZONE_COUNT_TEXT = "%d/%d"
local CAPTION_TEXT = "Collect every item in %s!"
local UNKNOWN_NAME = "???"
local UNKNOWN_INCOME = "???"
local CLAIMED_TEXT = "Claimed!" -- V0 : prime de la zone déjà réclamée (attribut IndexClaimed)
-- V0 proposé, absent du doc : attente (s) de la réponse du serveur à une réclamation ; un clic pendant ce
-- temps n'envoie rien, et la confirmation arrivée après ne fait plus sauter le bouton.
local CLAIM_WAIT = 5
-- Pastilles « ! » de Clément (L-127 point 3).
local ZONE_ALERT = "ZoneArt.ZoneAlert"
local CLAIM_ALERT = "ClaimAlert"
local CLAIM_ALL_ALERT = "ClaimAllAlert"
local CATEGORY_ALERT = "CategoryAlert"
local SECRETS_NAME = "Secrets" -- ZoneName des Secrets sans texte de Clément
local STORE_SEPARATOR = "\n" -- V0 : entre les 2 noms de magasins dans ZoneName (v3)
-- Icône de vitesse du HUD (UI_HUD.StatsPanel.SpeedRow.SpeedIcon.IconImage), reprise dans
-- Rewards.SpeedReward.Icon quand Clément l'a laissée vide (comme GainController pour BB_Gain).
local HUD_SPEED_LABEL = "Speed"
local HUD_SPEED_ICON = "IconImage"
-- Récompense d'une zone complète affichée dans RewardLabel (v2) : Index.ZoneRewardText (argent, vitesse
-- et revenus, L-083 point 7), suivi de ce mot une fois la zone complète. V0, en anglais.
local REWARD_EARNED_SUFFIX = " EARNED"
-- Teintes de l'icône des cartes d'exemple de Clément (relevé de Studio du 2026-11-08), quand aucune
-- carte Preview_* ne les donne (v2, repli).
local FOUND_COLOR = Color3.new(1, 1, 1)
local SILHOUETTE_COLOR = Color3.fromRGB(17, 19, 24) -- (0,067 ; 0,075 ; 0,094)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
-- Hauteur minimale du curseur ScrollTrack, en part de sa piste. V0 proposé, absent du doc.
local TRACK_MIN_SHARE = 0.1

local VIEW = Index.View
local DETAIL_POP_INFO = TweenInfo.new(VIEW.DetailPop.Time, VIEW.DetailPop.Style, VIEW.DetailPop.Direction)
local REWARDS_SWAP_INFO = TweenInfo.new(VIEW.RewardsSwap.Time, VIEW.RewardsSwap.Style, VIEW.RewardsSwap.Direction)

local IS_STUDIO = RunService:IsStudio()

-- Couleurs de l'arc-en-ciel du Secret (Config/Rarities), pour le UIGradient de Clip et de Detail.
local RAINBOW: ColorSequence? = nil
do
	local secret = Rarities.ById.Secret
	local colors = if secret then secret.RainbowColors else nil
	if colors and #colors >= 2 then
		local keypoints: { ColorSequenceKeypoint } = {}
		for index, color in colors do
			table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
		end
		RAINBOW = ColorSequence.new(keypoints)
	end
end

local IndexController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local tab = 1 -- repli : rang de l'onglet ouvert dans TABS
local category = NORMAL -- v3 : catégorie choisie
local mutation: string? = nil -- v3 : Id de l'onglet de mutation choisi
local selected: Item? = nil -- v3 : objet montré dans Detail
local discovered: { [string]: boolean } = {}
local claimed: { [number]: boolean } = {} -- zones dont la prime est réclamée (attribut IndexClaimed)
-- Réclamation envoyée, en attente de la réponse du serveur : le bouton qui sautera (T.33) et l'heure.
local pendingClaim: { button: GuiObject, at: number }? = nil
local net: any = nil
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

-- Image et teinte d'une icône (ImageLabel ou ImageButton).
local function setImage(element: Instance?, texture: string, color: Color3)
	if element == nil or not isImage(element) then
		return
	end
	local image = element :: any
	if image.Image ~= texture then
		image.Image = texture
	end
	if image.ImageColor3 ~= color then
		image.ImageColor3 = color
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

local function rarityOrder(item: Item): number
	local rarity = Rarities.ById[item.Rarity]
	return if rarity then rarity.Order else 0
end

local function isRainbow(item: Item): boolean
	local rarity = Rarities.ById[item.Rarity]
	return rarity ~= nil and rarity.Rainbow
end

local function silhouetteOf(item: Item): Color3
	return rarityColor(item):Lerp(BLACK, VIEW.SilhouetteDarken)
end

local function itemsOf(def: TabDef): { Item }
	local zone = def.zone
	if zone ~= nil then
		return Index.ByZone[zone] or {}
	end
	return Index.Secrets
end

-- L'objet le plus rare d'une liste (le dernier du catalogue à égalité), nil si elle est vide.
local function rarestOf(items: { Item }): Item?
	local best: Item? = nil
	for _, item in items do
		if best == nil or rarityOrder(item) >= rarityOrder(best) then
			best = item
		end
	end
	return best
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

-- ZoneName de la v3 : les noms des magasins PNJ de la zone (Config/Zones.Stores, ceux des enseignes et
-- du panneau BB_StoreInfo), en majuscules, un par ligne (« MINI MART\nKIOSK »), ou nil (Secrets).
local function storeNames(def: TabDef): string?
	local zone = def.zone
	local info = if zone then Zones[zone] else nil
	if info == nil or #info.Stores == 0 then
		return nil
	end
	return string.upper(table.concat(info.Stores, STORE_SEPARATOR))
end

-- Texte de RewardLabel pour une zone (complete : tous ses objets découverts, bonus déjà compté par le
-- serveur).
local function rewardText(zone: number, complete: boolean): string
	return Index.ZoneRewardText(zone) .. (if complete then REWARD_EARNED_SUFFIX else "")
end

local function readDiscovered()
	discovered = Index.Decode(localPlayer:GetAttribute(Index.Attribute))
end

local function readClaimed()
	claimed = Index.DecodeZones(localPlayer:GetAttribute(Index.ClaimedAttribute))
end

-- La prime de `zone` attend d'être réclamée : zone complète (découvertes), pas encore réclamée.
local function isClaimable(zone: number?): boolean
	return zone ~= nil and not claimed[zone] and Index.IsZoneComplete(discovered, zone)
end

local function anyClaimable(): boolean
	return #Index.ClaimableZones(discovered, claimed) > 0
end

-- Objet trouvé, tel que l'écran le montre : en MUTATIONS (v3), aucun (pas d'index par mutation).
local function isFound(current: Screen, item: Item): boolean
	if current.v3 and category == MUTATIONS then
		return false
	end
	return discovered[item.Id] == true
end

-- Revenu affiché dans la fiche : « $X/s » dans la zone de l'objet ; un Secret, de la zone 1 à la 6.
local function incomeText(item: Item): string
	local zone = item.Zone
	if zone ~= nil and Zones[zone] ~= nil then
		return `{Format.money(Formulas.ItemIncome(zone, item.Rarity))}/s`
	end
	local low = Formulas.ItemIncome(1, item.Rarity)
	local high = Formulas.ItemIncome(#Zones, item.Rarity)
	return `{Format.money(low)}-{Format.money(high)}/s`
end

------------------------------------------------------------------------------
-- Cartes et en-têtes
------------------------------------------------------------------------------

local function paint(current: Screen, card: Card)
	local found = isFound(current, card.item)
	if card.found == found then
		return
	end
	card.found = found
	local texture = textureOf(card.item.Id) or ""
	if current.v3 then
		local color = rarityColor(card.item)
		setImage(card.icon, texture, if found then FOUND_COLOR else silhouetteOf(card.item))
		local clip = card.clip
		if clip then
			clip.BackgroundColor3 = if found then color else color:Lerp(BLACK, VIEW.ClipDarken)
		end
		setText(card.name, if found then card.item.DisplayName else UNKNOWN_NAME)
		return
	end
	setImage(card.icon, texture, if found then current.foundColor else current.silhouetteColor)
	setVisible(card.lock, not found)
	setText(card.name, if found then string.upper(card.item.DisplayName) else UNKNOWN_NAME)
end

local function clearCards(current: Screen)
	for _, card in current.cards do
		card.frame:Destroy()
	end
	table.clear(current.cards)
end

-- Fiche Detail (v3) : l'objet `item`.
local function showDetail(current: Screen, item: Item)
	local detail = current.detail
	if detail == nil then
		return
	end
	local found = isFound(current, item)
	local color = rarityColor(item)
	detail.BackgroundColor3 = color
	local gradient = current.detailGradient
	if gradient then
		local wanted = if isRainbow(item) and RAINBOW then RAINBOW else current.detailGradientBase
		if wanted then
			gradient.Color = wanted
		end
	end
	setImage(current.detailIcon, textureOf(item.Id) or "", if found then FOUND_COLOR else silhouetteOf(item))
	setText(current.detailName, if found then item.DisplayName else UNKNOWN_NAME)
	local rarity = Rarities.ById[item.Rarity]
	setText(current.detailRarity, if rarity then rarity.DisplayName else item.Rarity)
	local rarityLabel = textHolder(current.detailRarity)
	if rarityLabel then
		(rarityLabel :: any).TextColor3 = color:Lerp(WHITE, VIEW.RarityLighten)
	end
	setText(current.detailIncome, if found then incomeText(item) else UNKNOWN_INCOME)
end

-- Cartes de chaque section (v2, v3 : toutes les zones ; repli : l'onglet ouvert), clonées depuis
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
			-- Clément ; v2 et repli), découvert ou pas : la silhouette garde sa rareté (doc 3.4).
			local rarity = Rarities.ById[item.Rarity]
			if rarity then
				setText(Find.path(frame, "RarityBar.Rarity"), rarity.DisplayNameUpper)
			end
			local icon = Find.path(frame, "Icon")
			local clip = if current.v3 then guiObject(frame, "Clip") else nil
			local rainbow = RAINBOW
			if clip and rainbow and isRainbow(item) then
				local gradient = clip:FindFirstChildOfClass("UIGradient")
				if gradient then
					gradient.Color = rainbow
				end
			end
			local card: Card = {
				item = item,
				frame = frame,
				icon = if icon and isImage(icon) then icon :: GuiObject else nil,
				lock = guiObject(frame, "Lock"),
				name = Find.path(frame, "ItemName"),
				clip = clip,
				found = nil,
			}
			paint(current, card)
			frame.Visible = true
			frame.Parent = parent
			table.insert(current.cards, card)
			if current.detail then
				local connection = onClick(frame, function()
					if screen == current and isOpen then
						selected = item
						showDetail(current, item)
						local detailIcon = current.detailIcon
						if detailIcon then
							Motion.Pop(detailIcon, VIEW.DetailPop.From, DETAIL_POP_INFO)
						end
					end
				end)
				local _ = connection -- détruite avec la carte
			end
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

-- Trouvés et total d'une section, tels que l'écran les montre.
local function countSection(current: Screen, section: Section): (number, number)
	local items = itemsOf(section.def)
	local found = 0
	for _, item in items do
		if isFound(current, item) then
			found += 1
		end
	end
	return found, #items
end

-- Rewards.SpeedReward.Icon vide (aucune icône de chaussure livrée) : l'image de l'icône de vitesse du
-- HUD (SpeedRow.SpeedIcon.IconImage, sinon la 1re image non vide de la ligne du nombre Speed). Seule
-- l'image est posée, et seulement si Clément l'a laissée vide.
local function fillSpeedIcon(icon: Instance?)
	if icon == nil or not isImage(icon) or (icon :: any).Image ~= "" then
		return
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui then playerGui:FindFirstChild(HUD) else nil
	local label = if hud then Find.path(hud, HUD_SPEED_LABEL) else nil
	local row = if label and label:IsA("TextLabel") then label.Parent else nil
	if row == nil or row:IsA("ScreenGui") then
		return
	end
	local image: string? = nil
	local preferred = Find.path(row, HUD_SPEED_ICON)
	if preferred and isImage(preferred) and (preferred :: any).Image ~= "" then
		image = (preferred :: any).Image
	else
		for _, child in row:GetDescendants() do
			if child:IsA("ImageLabel") and (child :: ImageLabel).Image ~= "" then
				image = (child :: ImageLabel).Image
				break
			end
		end
	end
	if image then
		(icon :: any).Image = image
	end
end

-- Rewards (v3) : la zone de la section visible dans la liste.
local function refreshRewards(current: Screen)
	local rewards = current.rewards
	if rewards == nil then
		return
	end
	fillSpeedIcon(current.speedIcon)
	local rank = current.viewSection
	local section = if rank then current.sections[rank] else nil
	local zone = if section then section.def.zone else nil
	setVisible(rewards, current.rewardsShown and category == NORMAL and zone ~= nil)
	if zone == nil or section == nil then
		return
	end
	local reward = Index.ZoneReward(zone)
	setText(current.speedAmount, `+{math.round(reward.Speed * 100)}%`)
	setText(current.cashAmount, `+{Format.money(reward.Cash)}`)
	setText(current.claimLabel, if claimed[zone] then CLAIMED_TEXT else (current.claimText or ""))
end

-- Pastilles « ! » de l'écran (L-127 point 3), ouvert ou pas : allumées tant qu'il y a à réclamer.
local function refreshAlerts(current: Screen)
	if not current.v3 then
		return
	end
	local any = anyClaimable()
	AlertBadge.Set(current.claimAllAlert, any)
	AlertBadge.Set(current.categoryAlert, any)
	local rank = current.viewSection
	local section = if rank then current.sections[rank] else nil
	AlertBadge.Set(current.claimAlert, section ~= nil and isClaimable(section.def.zone))
	for _, each in current.sections do
		AlertBadge.Set(each.zoneAlert, isClaimable(each.def.zone)) -- Secrets (zone nil) : toujours éteinte
	end
end

local function refreshHeader(current: Screen)
	local all = 0
	for _, section in current.sections do
		local zone = section.def.zone
		local found: number, total: number
		if current.v3 then
			found, total = countSection(current, section)
		elseif zone ~= nil then
			found, total = Index.CountZone(discovered, zone)
		else
			found, total = Index.CountSecrets(discovered)
		end
		local stores = if current.v3 then storeNames(section.def) else nil
		if stores then
			setText(section.zoneName, stores) -- v3 : les magasins PNJ de la zone (retour de Cantin, vague 24)
		elseif not section.keepName then
			setText(section.zoneName, current.tabNames[tab] or string.upper(fallbackName(section.def)))
		elseif textOf(section.zoneName) == nil then
			setText(section.zoneName, string.upper(fallbackName(section.def)))
		end
		setText(section.zoneCount, string.format(if current.v3 then V3_ZONE_COUNT_TEXT else ZONE_COUNT_TEXT, found, total))
		setFill(section, if total > 0 then found / total else 0)
		setVisible(section.reward, zone ~= nil and section.rewardShown)
		if zone ~= nil then
			setText(section.rewardLabel, rewardText(zone, total > 0 and found >= total))
		end
		local rarest = if section.zoneItem then rarestOf(itemsOf(section.def)) else nil
		if rarest then
			setImage(section.zoneItem, textureOf(rarest.Id) or "", if isFound(current, rarest) then FOUND_COLOR else silhouetteOf(rarest))
		end
	end
	if current.v3 then
		for _, item in Items.List do
			if isFound(current, item) then
				all += 1
			end
		end
		setText(current.counter, string.format(V3_COUNTER_TEXT, all, Index.Total))
	else
		setText(current.counter, string.format(COUNTER_TEXT, Index.CountAll(discovered), Index.Total))
	end
	refreshRewards(current)
	refreshAlerts(current)
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

-- Rang de la section visible dans la liste (v3) : la dernière section montrée dont le haut est passé
-- à moins de View.ViewMargin px sous le haut de la liste ; sinon la première montrée.
local function sectionInView(current: Screen): number?
	local list = current.list
	if list == nil or not list:IsA("GuiObject") then
		return nil
	end
	local top = (list :: GuiObject).AbsolutePosition.Y + VIEW.ViewMargin
	local best: number? = nil
	for rank, section in current.sections do
		local root = section.root
		if root and root.Visible then
			if best == nil or root.AbsolutePosition.Y <= top then
				best = rank
			end
		end
	end
	return best
end

-- La liste a défilé (v3) : Rewards suit la zone visible, avec RewardsSwap quand elle change.
local function onScroll(current: Screen)
	local rank = sectionInView(current)
	local previous = current.viewSection
	if rank == previous then
		return
	end
	current.viewSection = rank
	refreshRewards(current)
	refreshAlerts(current)
	local rewards = current.rewards
	if rewards and rewards.Visible and isOpen and previous ~= nil then
		Motion.Pop(rewards, VIEW.RewardsSwap.From, REWARDS_SWAP_INFO)
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
	local item = selected
	if item then
		showDetail(current, item)
	end
end

------------------------------------------------------------------------------
-- Catégories et mutations (v3)
------------------------------------------------------------------------------

local function select(buttons: { [string]: GuiObject }, chosen: string?)
	for key, button in buttons do
		setVisible(guiObject(button, SELECTED), key == chosen)
	end
end

-- Les cartes des sections montrées entrent une par une (T.29, entrée seulement).
local function cardsIn(current: Screen)
	local info = VIEW.CardsIn
	local count = 0
	for _, section in current.sections do
		local root = section.root
		if root == nil or not root.Visible then
			continue
		end
		for _, card in current.cards do
			if count >= info.Max then
				return
			end
			if card.frame.Parent == section.cardParent then
				local delay = info.Start + count * info.Gap
				Motion.Pop(card.frame, 0, TweenInfo.new(info.Time, info.Style, info.Direction, 0, false, delay))
				count += 1
			end
		end
	end
end

local function tabsIn(current: Screen)
	local info = VIEW.TabsIn
	for index, effect in Mutations.Effects do
		local button = current.mutationTabButtons[effect.Id]
		if button then
			Motion.Pop(button, 0, TweenInfo.new(info.Time, info.Style, info.Direction, 0, false, (index - 1) * info.Gap))
		end
	end
end

local function paintCaption(current: Screen)
	local id = mutation
	local button = if id then current.mutationTabButtons[id] else nil
	local effect = if id then Mutations.EffectById[id] else nil
	local label = if button then textOf(Find.path(button, TAB_LABEL)) else nil
	local name = label or (if effect then effect.DisplayNameUpper else "")
	setText(current.caption, string.format(CAPTION_TEXT, name))
end

-- Catégorie et visibilité des sections, de MutationTabs et de MutationCaption.
local function applyCategory(current: Screen)
	for _, section in current.sections do
		local secrets = section.def.zone == nil
		setVisible(section.root, (category == SECRETS) == secrets)
	end
	select(current.categories, category)
	setVisible(current.mutationTabs, category == MUTATIONS)
	local caption = current.caption
	if caption and caption:IsA("GuiObject") then
		setVisible(caption :: GuiObject, category == MUTATIONS)
	end
	select(current.mutationTabButtons, mutation)
	paintCaption(current)
end

local function setCategory(current: Screen, name: string)
	if screen ~= current or not isOpen then
		return
	end
	local changed = category ~= name
	category = name
	applyCategory(current)
	scrollTop(current)
	current.viewSection = sectionInView(current)
	refresh()
	if changed then
		cardsIn(current)
		if name == MUTATIONS then
			tabsIn(current)
		end
	end
end

local function setMutation(current: Screen, id: string)
	if screen ~= current or not isOpen then
		return
	end
	mutation = id
	select(current.mutationTabButtons, id)
	paintCaption(current)
	scrollTop(current)
	cardsIn(current)
end

-- Rien à réclamer : son de refus et le bouton tremble (View.Deny).
local function deny(current: Screen, button: GuiObject?)
	Motion.PlaySound(VIEW.Deny.Sound)
	if button == nil or current.shaking[button] then
		return
	end
	current.shaking[button] = true
	local base = button.Position
	for index, offset in VIEW.Deny.Offsets do
		task.delay((index - 1) * VIEW.Deny.Step, function()
			if button.Parent ~= nil then
				button.Position = UDim2.new(base.X.Scale + offset, base.X.Offset, base.Y.Scale, base.Y.Offset)
			end
		end)
	end
	task.delay(#VIEW.Deny.Offsets * VIEW.Deny.Step, function()
		button.Position = base
		current.shaking[button] = nil
	end)
end

-- Envoie la réclamation (zone nil = toutes) ; le bouton sautera (T.33) à la confirmation du serveur.
-- Une demande déjà en attente : rien n'est renvoyé.
local function sendClaim(button: GuiObject, zone: number?)
	local waiting = pendingClaim
	if waiting and os.clock() - waiting.at < CLAIM_WAIT then
		return
	end
	if net == nil then
		reportOnce("net", "[Index] Net pas prêt : réclamation pas envoyée")
		return
	end
	pendingClaim = { button = button, at = os.clock() }
	net.Client.ClaimIndexReward:Fire(zone)
end

-- Rewards.ClaimButton : la prime de la zone visible.
local function onClaim(current: Screen)
	local rank = current.viewSection
	local section = if rank then current.sections[rank] else nil
	local zone = if section then section.def.zone else nil
	local button = current.claimButton
	if zone == nil or button == nil then
		return
	end
	if isClaimable(zone) then
		sendClaim(button, zone)
	else
		deny(current, button) -- zone pas complète ou déjà réclamée
	end
end

-- UnlockedBar.ClaimAllButton : toutes les zones complètes pas encore réclamées, en une demande.
local function onClaimAll(current: Screen)
	local button = current.claimAllButton
	if button == nil then
		return
	end
	if anyClaimable() then
		sendClaim(button, nil)
	else
		deny(current, button)
	end
end

-- Attribut IndexClaimed changé : une zone de plus réclamée confirme la demande en attente (T.33 Success).
local function onClaimedChanged()
	local before = claimed
	readClaimed()
	local gained = false
	for zone in claimed do
		if not before[zone] then
			gained = true
		end
	end
	local waiting = pendingClaim
	if waiting and gained then
		pendingClaim = nil
		local button = waiting.button
		if os.clock() - waiting.at < CLAIM_WAIT and button.Parent ~= nil and button:IsA("GuiButton") then
			Motion.Success(button :: GuiButton)
		end
	elseif waiting and os.clock() - waiting.at >= CLAIM_WAIT then
		pendingClaim = nil
	end
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
	local zoneItem = if zoneBar then Find.path(zoneBar, "ZoneItem") else nil
	return {
		def = def,
		root = if root and root:IsA("GuiObject") then root :: GuiObject else nil,
		cardParent = cardParent,
		zoneName = if root then Find.path(root, "ZoneName") else nil,
		keepName = keepName,
		zoneCount = if root then Find.path(root, "ZoneCount") else nil,
		fill = fill,
		fillSize = if fill then fill.Size else UDim2.new(1, 0, 1, 0),
		reward = reward,
		rewardShown = if reward then reward.Visible else false,
		rewardLabel = if reward then Find.path(reward, "RewardLabel") else nil,
		zoneItem = if zoneItem and isImage(zoneItem) then zoneItem :: GuiObject else nil,
		zoneAlert = if root then guiObject(root, ZONE_ALERT) else nil,
	}
end

local function screenRank(name: string): number?
	return table.find(SCREEN_ORDER, name)
end

-- Les écrans plus anciens que `gui`, rangés à côté de lui, sont éteints.
local function disableOlder(gui: ScreenGui)
	local rank = screenRank(gui.Name)
	local parent = gui.Parent
	if rank == nil or parent == nil then
		return
	end
	for older = rank + 1, #SCREEN_ORDER do
		local other = parent:FindFirstChild(SCREEN_ORDER[older])
		if other and other:IsA("ScreenGui") then
			(other :: ScreenGui).Enabled = false
		end
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
	Motion.SetCloser(gui, close) -- un autre écran du groupe ScreenGroup s'ouvre (L-089)
	local name = gui.Name
	local v3 = name == SCREEN
	local v2 = v3 or name == V2_SCREEN
	disableOlder(gui) -- les anciens écrans restent éteints

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
				reportOnce(`section:{name}:{def.path}`, `[Index] {name}.{def.path}.Cards introuvable : section vide`)
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
	local track = if v2 and not v3 then guiObject(gui, "ScrollTrack") else nil
	local detail = if v3 then guiObject(gui, "Detail") else nil
	local detailGradient = if detail then detail:FindFirstChildOfClass("UIGradient") else nil
	local rewards = if v3 then guiObject(gui, "Rewards") else nil
	local claimButton = if rewards then guiObject(rewards, "ClaimButton") else nil
	local claimLabel = if claimButton then Find.path(claimButton, "ClaimLabel") else nil
	local claimAllButton = if v3 then guiObject(gui, "UnlockedBar.ClaimAllButton") else nil
	local current: Screen = {
		gui = gui,
		v2 = v2,
		v3 = v3,
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
		detail = detail,
		detailGradient = detailGradient,
		detailGradientBase = if detailGradient then detailGradient.Color else nil,
		detailIcon = if detail then guiObject(detail, "DetailIcon") else nil,
		detailName = if detail then Find.path(detail, "DetailName") else nil,
		detailRarity = if detail then Find.path(detail, "DetailRarity") else nil,
		detailIncome = if detail then Find.path(detail, "DetailIncome") else nil,
		rewards = rewards,
		rewardsShown = if rewards then rewards.Visible else false,
		speedAmount = if rewards then Find.path(rewards, "SpeedReward.Amount") else nil,
		speedIcon = if rewards then Find.path(rewards, "SpeedReward.Icon") else nil,
		cashAmount = if rewards then Find.path(rewards, "CashReward.Amount") else nil,
		claimButton = claimButton,
		claimLabel = claimLabel,
		claimText = textOf(claimLabel),
		viewSection = nil,
		categories = {},
		mutationTabs = if v3 then guiObject(gui, "MutationTabs") else nil,
		mutationTabButtons = {},
		caption = if v3 then Find.path(gui, "MutationCaption") else nil,
		shaking = {},
		claimAllButton = claimAllButton,
		claimAllAlert = if claimAllButton then guiObject(claimAllButton, CLAIM_ALL_ALERT) else nil,
		claimAlert = if claimButton then guiObject(claimButton, CLAIM_ALERT) else nil,
		categoryAlert = if v3 then guiObject(gui, `Categories.{NORMAL}.{CATEGORY_ALERT}`) else nil,
	}
	screen = current
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	keep(onClick(Find.path(gui, "CloseButton"), close))

	if v3 then
		if detail == nil then
			reportOnce("detail", `[Index] {name}.Detail introuvable : pas de fiche au clic`)
		end
		if rewards == nil then
			reportOnce("rewards", `[Index] {name}.Rewards introuvable : pas de récompense de zone`)
		end
		keep(onClick(claimButton, function()
			if screen == current and isOpen then
				onClaim(current)
			end
		end))
		if claimAllButton == nil then
			reportOnce("claimAll", `[Index] {name}.UnlockedBar.ClaimAllButton introuvable : pas de « Claim All »`)
		end
		keep(onClick(claimAllButton, function()
			if screen == current and isOpen then
				onClaimAll(current)
			end
		end))
		local categories = Find.path(gui, "Categories")
		for _, key in CATEGORIES do
			local button = if categories then guiObject(categories, key) else nil
			if button then
				current.categories[key] = button
				keep(onClick(button, function()
					setCategory(current, key)
				end))
			else
				reportOnce(`category:{key}`, `[Index] {name}.Categories.{key} introuvable : catégorie pas branchée`)
			end
		end
		local tabs = current.mutationTabs
		for _, effect in Mutations.Effects do
			local button = if tabs then guiObject(tabs, `{effect.Id}Tab`) else nil
			if button then
				current.mutationTabButtons[effect.Id] = button
				keep(onClick(button, function()
					setMutation(current, effect.Id)
				end))
			end
		end
		if mutation == nil then
			-- L'onglet que Clément a montré choisi (Selected visible), sinon le premier.
			for _, effect in Mutations.Effects do
				local button = current.mutationTabButtons[effect.Id]
				local mark = if button then guiObject(button, SELECTED) else nil
				if mark and mark.Visible then
					mutation = effect.Id
					break
				end
			end
			mutation = mutation or (if #Mutations.Effects > 0 then Mutations.Effects[1].Id else nil)
		end
		if list and list:IsA("ScrollingFrame") then
			keep((list :: ScrollingFrame):GetPropertyChangedSignal("CanvasPosition"):Connect(function()
				if screen == current and isOpen then
					onScroll(current)
				end
			end))
		end
		refreshAlerts(current) -- pastilles « ! » allumées dès le branchement, écran fermé
		return
	end

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

-- L'écran à brancher dans PlayerGui : UI_Index_v3, sinon UI_Index_v2, sinon l'ancien UI_Index.
local function findScreen(playerGui: Instance): ScreenGui?
	for _, name in SCREEN_ORDER do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then
			return gui :: ScreenGui
		end
	end
	return nil
end

-- Écran branché encore présent (un plus ancien seulement si les plus récents ne sont pas là), ou
-- celui de PlayerGui (branché au passage), ou nil.
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
		reportOnce("screen", `[Index] écran {SCREEN} (ou {V2_SCREEN}, {LEGACY_SCREEN}) absent de PlayerGui : l'index ne s'ouvre pas`)
		return
	end
	readDiscovered()
	isOpen = true
	if current.v3 then
		applyCategory(current)
	end
	buildCards(current)
	scrollTop(current)
	current.viewSection = if current.v3 then sectionInView(current) else nil
	refreshHeader(current)
	updateTrack(current)
	if current.v3 then
		local first = Index.ByZone[1]
		local item = selected or (if first then first[1] else nil)
		if item then
			selected = item
			showDetail(current, item)
		end
	end
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
	-- Tous les exemplaires : LeftRail.IndexButton (PC) et LeftRailTouch.IndexButton (téléphone).
	local buttons: { GuiButton } = {}
	for _, found in Find.all(gui, HUD_BUTTON) do
		if found:IsA("GuiButton") then
			table.insert(buttons, found :: GuiButton)
		end
	end
	if #buttons == 0 then
		reportOnce("hud", `[Index] {HUD}.{HUD_BUTTON} introuvable ou pas un bouton : l'index ne s'ouvre pas`)
		return
	end
	hudBound[gui] = true
	for _, button in buttons do
		button.Activated:Connect(toggle)
	end
end

function IndexController.Start()
	if not Features.Index then
		return -- MAJ 2 : rien n'est branché, l'écran reste fermé
	end
	readDiscovered()
	readClaimed()
	-- Pastilles « ! » de l'écran branché, ouvert ou pas (L-127).
	local function alerts()
		local current = screen
		if current and current.gui.Parent ~= nil then
			refreshAlerts(current)
		end
	end
	localPlayer:GetAttributeChangedSignal(Index.Attribute):Connect(function()
		readDiscovered()
		refresh()
		alerts()
	end)
	localPlayer:GetAttributeChangedSignal(Index.ClaimedAttribute):Connect(function()
		onClaimedChanged()
		refresh()
		alerts()
	end)
	-- Les remotes attendent le serveur : sans bloquer le reste.
	task.spawn(function()
		local ok, result = pcall(function(): any
			return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
		end)
		if ok then
			net = result
		else
			reportOnce("netRequire", `[Index] Net introuvable : les réclamations ne partent pas ({result})`)
		end
	end)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if not child:IsA("ScreenGui") then
			return
		end
		local rank = screenRank(child.Name)
		if rank ~= nil then
			local current = screen
			local currentRank = if current and current.gui.Parent ~= nil then screenRank(current.gui.Name) else nil
			if currentRank ~= nil and currentRank < rank then
				(child :: ScreenGui).Enabled = false -- un écran plus récent est là : l'ancien reste éteint
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
