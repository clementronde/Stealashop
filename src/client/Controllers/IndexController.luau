--!strict
-- IndexController (DEV-111, client) : l'index des objets, écran UI_Index_v3 de Clément (L-095 point 1 :
-- l'Index du jeu de référence, docs/claude/notes/ui-index-v3.md), avec repli sur UI_Index_v2 (L-083,
-- points 5 et 6), puis sur l'ancien UI_Index (onglets, maquette UI-111), tant que la v3 n'est pas dans
-- PlayerGui. Partie 2, section 3.4 ; règles : Config/Index ; découvertes : IndexService.
-- a508 (L-475 point 1, Clément 26/11) : ces replis sont retirés ; seul UI_Index_v3 est lu (ou un UI_Index_v4), les
-- anciens écrans encore livrés restent éteints.
-- Vague 59 (a191, L-183) : UI_Index_v4 (ou UI_Index refait, reconnu à Cards et Footer.Pager) passe avant
-- tous les autres, qui restent lus tant qu'il n'est pas dans PlayerGui. Une zone à la fois (onglets
-- Tabs.Zone1Tab…Zone6Tab, SecretsTab : Selected allumé sur l'onglet choisi, ZoneAlert = sa récompense à
-- réclamer) ; Cards = Index.View.PageSize cartes (4 × 2) clonées depuis Template, Footer.Pager (PrevButton,
-- NextButton, en boucle ; PageLabel « 1/2 ») pour les suivantes. Carte : Clip à la couleur de la rareté
-- (assombrie tant que l'objet n'est pas trouvé ; Clip.RarityGradient en arc-en-ciel pour Mythique et
-- Secret), Rays et Glow teints, Icon (silhouette), ItemName (« ??? ») et l'attribut Rarity pour le module
-- d'animations d'UI. ZoneArt : façade Decal UI_ZoneArt_Z<n> (ou _Secrets) de ReplicatedStorage/Assets si elle
-- est livrée, ZoneName (ville, sinon thème), ZoneTheme (les 2 magasins) ; ZoneBar (Fill, ZoneCount « 9/13 »)
-- = progression vers la récompense ; UnlockedBar.Counter « Unlocked: 7/83 ». Footer.ClaimButton (caché pour
-- les Secrets) réclame la zone affichée (ClaimIndexReward(zone)), RewardCaption = Index.ZoneRewardText ou
-- « Claimed! », RewardIcon = icône de boutique de l'objet donné, ClaimAlert. Vague 61 (L-192, l'objet seul) :
-- Footer.ItemReward (facultatif) : RewardIcon = la même icône, RewardCaption = le nom de l'objet (« Wrench »,
-- aussi dans Amount d'un écran d'avant) ; Footer.CashReward et SpeedReward d'un écran d'avant : cachés.
-- Refus : View.Deny ; réussite : T.33 Success, comme la v3.
-- Vague 63 (a207, L-201) : l'index v4 de Figma est construit sous le nom UI_Index_v3 (liste par zone gardée) ;
-- nouveautés facultatives, l'écran d'avant marche encore : (1) avec ZoneArt.NameShade.ZoneTheme, ZoneName = la ville
-- (Config/Zones.City, « LONDON ») et ZoneTheme = le thème (« TOYS ») ; zone sans ville : textes de Clément gardés ;
-- (2) ZoneBar.RewardIcon = l'icône de l'objet donné par la zone, son « ? » Unknown caché (ZoneItem n'est plus
-- peint) ; (3) ClaimButton : en cours ou réclamée UIGradient, prête ReadyGradient (et ClaimAlert), ClaimLabel
-- « CLAIMED » une fois réclamée ; (4) Rewards.ItemReward : RewardIcon (Unknown caché) et RewardCaption = le nom de
-- l'objet (« WRENCH ») ; (5) Counter « 23 / 83 discovered » ; (6) Categories.LimitedButton caché (catégorie à venir).
-- Seulement si Features.Index : à false, rien n'est branché et l'écran reste fermé.
--
-- Rôle commun :
--   - UI_HUD.IndexButton (tous les exemplaires : LeftRail et LeftRailTouch) ouvre l'écran (un 2e appui
--     le ferme) ; CloseButton le ferme. Ouverture et
--     fermeture animées par UI/Motion (groupe ScreenGroup de l'écran, Motion.SetCloser), comme les
--     boutiques : les cartes sont retirées une fois l'écran éteint, et une réouverture pendant la
--     fermeture la rattrape. L'écran branché éteint les plus anciens (Enabled) ;
--   - une carte par objet (Config/Index, objet du tuto compris ; vague 71 : du moins rare au plus rare), clonée depuis
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
--     est passé à moins de View.ViewMargin px sous le haut de la liste) ; SpeedReward et CashReward cachés
--     depuis la vague 61 (L-192 : plus d'argent ni de vitesse, l'objet n'a pas de place en v3). Vague 34 (L-127 point 2) : la
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
--     caché hors de NORMAL. Vague GC6 (a410, MAJ 7, Features.IndexMutations) : en MUTATIONS, une carte est
--     trouvée si l'objet a été obtenu avec l'effet de l'onglet choisi, ou, sans onglets, avec au moins un effet
--     (attribut IndexMutations d'IndexService, Shared/IndexMutations) ; compteurs d'après ces cartes. Effets
--     obtenus : Template.MutationRow (facultatif, Clément) dans toutes les catégories, sinon « 2/7 » construit par
--     le code sur la carte en MUTATIONS ; fiche : Detail.DetailMutations (facultatif), sinon DetailIncome en
--     MUTATIONS. Avant (ou Features.IndexMutations à false) : toutes silhouettes, compteurs à 0. MutationTabs.<Effet>Tab (Config/Mutations.Effects)
--     : Selected sur l'onglet choisi, MutationCaption « Collect every item in SHINY! ». Changement de
--     catégorie ou d'onglet : la liste remonte, les cartes entrent une par une (T.29, View.CardsIn) ; les
--     onglets de mutation entrent à leur tour (View.TabsIn) ;
--   - UnlockedBar.Counter « Unlocked: 7/83 » (« 23 / 83 discovered » depuis L-201).
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
-- tremblent, la visibilité et le UIScale Pulse des pastilles « ! », l'image des RewardIcon et la visibilité de leur
-- Unknown, Enabled de UIGradient et ReadyGradient de ClaimButton, LimitedButton caché ; l'effet d'échelle de Motion est
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
local IndexMutations = require(Shared:WaitForChild("IndexMutations"))
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
	mutationsPainted: string?, -- vague GC6 (a410) : colonnes de mutations peintes (clé « catégorie|effets »)
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
	zoneTheme: Instance?, -- v3 refait (L-201) : ZoneArt.NameShade.ZoneTheme, le thème sous la ville
	rewardIcon: GuiObject?, -- v3 refait (L-201) : ZoneBar.RewardIcon, l'objet donné par la zone
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
	speedReward: GuiObject?, -- Rewards.SpeedReward et CashReward : cachés (L-192, plus d'argent ni de vitesse)
	cashReward: GuiObject?,
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
	-- v3 refait (L-201), facultatifs : ClaimButton.UIGradient (gris) et ReadyGradient (vert, prête) ;
	-- Rewards.ItemReward (RewardIcon, RewardCaption) : l'objet donné par la zone visible.
	claimGradient: UIGradient?,
	readyGradient: UIGradient?,
	itemIcon: GuiObject?,
	itemCaption: Instance?,
}

local SCREEN = "UI_Index_v3"
-- a508 (L-475 point 1, Clément 26/11) : plus de repli. UI_Index_v2 et UI_Index (rangés par le chef UI dans
-- ServerStorage/_OLD_UI) ne sont plus lus ; encore livrés dans PlayerGui, ils restent éteints (RETIRED_SCREENS).
local V2_SCREEN = "UI_Index_v2"
local LEGACY_SCREEN = "UI_Index"
local SCREEN_ORDER = { SCREEN } -- a508 : seul écran lu (avant : v3, puis v2, puis l'ancien UI_Index)
local RETIRED_SCREENS = { V2_SCREEN, LEGACY_SCREEN } -- a508 : gardés éteints s'ils sont encore livrés
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
local V3_COUNTER_TEXT = "Unlocked: %d/%d" -- UI_Index_v4 ; la v3 écrit COUNTER_TEXT depuis L-201 point 5
local V3_ZONE_COUNT_TEXT = "%d/%d"
local CAPTION_TEXT = "Collect every item in %s!"
local UNKNOWN_NAME = "???"
local UNKNOWN_INCOME = "???"
local CLAIMED_TEXT = "Claimed!" -- V0 : prime de la zone déjà réclamée (attribut IndexClaimed), UI_Index_v4
local V3_CLAIMED_TEXT = "CLAIMED" -- L-201 point 3 : ClaimLabel de la v3 une fois la zone réclamée
-- V0 proposé, absent du doc : attente (s) de la réponse du serveur à une réclamation ; un clic pendant ce
-- temps n'envoie rien, et la confirmation arrivée après ne fait plus sauter le bouton.
local CLAIM_WAIT = 5
-- Pastilles « ! » de Clément (L-127 point 3).
local ZONE_ALERT = "ZoneArt.ZoneAlert"
local CLAIM_ALERT = "ClaimAlert"
local CLAIM_ALL_ALERT = "ClaimAllAlert"
local CATEGORY_ALERT = "CategoryAlert"
-- v3 refait (L-201) : « ? » de Clément dans chaque RewardIcon, caché une fois l'image posée ; dégradés de ClaimButton ;
-- catégorie LIMITED pas encore créée (bouton caché).
local UNKNOWN = "Unknown"
local CLAIM_GRADIENT = "UIGradient"
local READY_GRADIENT = "ReadyGradient"
local LIMITED = "LimitedButton"
local SECRETS_NAME = "Secrets" -- ZoneName des Secrets sans texte de Clément
local STORE_SEPARATOR = "\n" -- V0 : entre les 2 noms de magasins dans ZoneName (v3)
-- Récompense d'une zone complète affichée dans RewardLabel (v2) : Index.ZoneRewardText (l'objet donné,
-- L-192), suivi de ce mot une fois la zone complète. V0, en anglais.
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
local mutationBook: IndexMutations.Decoded = {} -- vague GC6 (a410) : effets obtenus par objet (attribut IndexMutations)
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
		return Motion.Activated(element :: GuiButton):Connect(function()
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

-- Vague 71 (a238, L-213 point 3a) : une liste de Config/Index triée du moins rare au plus rare (Rarities.Order),
-- dans l'ordre du catalogue à égalité ; faite une fois par liste.
local NO_ITEMS: { Item } = {}
local sortedLists: { [{ Item }]: { Item } } = {}
local function byRarity(list: { Item }): { Item }
	local known = sortedLists[list]
	if known then
		return known
	end
	local sorted: { Item } = {}
	local position: { [Item]: number } = {}
	for index, item in list do
		table.insert(sorted, item)
		position[item] = index
	end
	table.sort(sorted, function(a: Item, b: Item): boolean
		local ra, rb = rarityOrder(a), rarityOrder(b)
		if ra ~= rb then
			return ra < rb
		end
		return position[a] < position[b]
	end)
	sortedLists[list] = sorted
	return sorted
end

local function itemsOf(def: TabDef): { Item }
	local zone = def.zone
	if zone ~= nil then
		return byRarity(Index.ByZone[zone] or NO_ITEMS)
	end
	return byRarity(Index.Secrets)
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

-- v3 refait (L-201 points 2 et 4) : image de l'objet donné par `zone` (Index.ZoneRewardIcon, icône de boutique) sur
-- `icon`, et son « ? » (Unknown) caché. Icône pas livrée : rien ne change, le « ? » reste.
local function paintRewardIcon(icon: GuiObject?, zone: number)
	if icon == nil then
		return
	end
	local iconName = Index.ZoneRewardIcon(zone)
	local texture = if iconName then textureOf(iconName) else nil
	if texture == nil then
		return
	end
	local image = icon :: any
	if image.Image ~= texture then
		image.Image = texture
	end
	setVisible(guiObject(icon, UNKNOWN), false)
end

-- v3 refait (L-201 point 1) : ZoneName = la ville, ZoneTheme = le thème (« LONDON », « TOYS »). Zone sans ville
-- (zone 1) : les textes de Clément sont gardés (écrits seulement s'ils sont vides).
local function paintCity(section: Section, zone: number)
	local info = Zones[zone]
	if info == nil then
		return
	end
	local city = info.City
	if city then
		setText(section.zoneName, string.upper(city))
		setText(section.zoneTheme, string.upper(info.Theme))
	elseif textOf(section.zoneName) == nil then
		setText(section.zoneName, string.upper(info.Theme))
	end
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

local function readMutations()
	mutationBook = IndexMutations.Decode(localPlayer:GetAttribute(IndexMutations.Attribute))
end

-- Vague GC6 (a410, MAJ 7) : colonnes de mutations allumées (Features.IndexMutations).
local function mutationsOn(): boolean
	return Features.IndexMutations == true
end

-- Objet trouvé, tel que l'écran le montre. En MUTATIONS (v3) : avant la vague GC6, aucun ; depuis (a410), l'objet
-- obtenu avec l'effet de l'onglet choisi (MutationTabs de Clément), ou, sans onglets (retirés en L-213), avec au moins
-- un effet.
local function isFound(current: Screen, item: Item): boolean
	if current.v3 and category == MUTATIONS then
		if not mutationsOn() then
			return false
		end
		local row = mutationBook[item.Id]
		if row == nil then
			return false
		end
		if next(current.mutationTabButtons) ~= nil and mutation ~= nil then
			return row[mutation :: string] == true
		end
		return next(row) ~= nil
	end
	return discovered[item.Id] == true
end

-- Effets obtenus pour `item`, dans l'ordre de Config/Mutations, en capitales (« GOLD · NEON »).
local MUTATION_SEPARATOR = " · " -- V0, comme Mutations.Label
local NO_MUTATION_TEXT = "No mutation yet" -- V0 proposé (Cantin, 23/11), anglais (L-036)
local MUTATION_COUNT_TEXT = "%d/%d" -- V0 : repli sur la carte, effets obtenus / colonnes
local MUTATION_FALLBACK = "MutationsFallback" -- étiquette de repli construite par le code (pas au contrat)
local function mutationNames(item: Item): { string }
	local names: { string } = {}
	local row = mutationBook[item.Id]
	if row then
		for _, effect in Mutations.Effects do
			if row[effect.Id] then
				table.insert(names, effect.DisplayNameUpper)
			end
		end
	end
	return names
end

-- Colonnes de mutations d'une carte (v3). Élément facultatif de Clément Template.MutationRow (Frame) avec son
-- Template (invisible, cloné par effet obtenu, nommé par l'Id de l'effet, texte MutationLabel), montré dans toutes les
-- catégories. Sans lui (repli lisible), en MUTATIONS seulement : une étiquette « 2/7 » construite par le code en haut
-- de la carte ; la liste complète va dans la fiche Detail.
local function paintMutations(current: Screen, card: Card)
	if not current.v3 or not mutationsOn() then
		return
	end
	local names = mutationNames(card.item)
	local key = `{category}|{table.concat(names, ",")}`
	if card.mutationsPainted == key then
		return
	end
	card.mutationsPainted = key
	local row = guiObject(card.frame, "MutationRow")
	if row then
		local template = guiObject(row, "Template")
		for _, child in row:GetChildren() do
			if child ~= template and child:IsA("GuiObject") and Mutations.EffectById[child.Name] ~= nil then
				child:Destroy()
			end
		end
		local owned = mutationBook[card.item.Id]
		if template and owned then
			for order, effect in Mutations.Effects do
				if owned[effect.Id] then
					local clone = template:Clone()
					clone.Name = effect.Id
					clone.LayoutOrder = order
					setText(Find.path(clone, "MutationLabel"), effect.DisplayNameUpper)
					clone.Visible = true
					clone.Parent = row
				end
			end
		end
		return
	end
	local label = card.frame:FindFirstChild(MUTATION_FALLBACK)
	local shown = category == MUTATIONS and #names > 0 and IndexMutations.Counts(card.item)
	if label == nil and shown then
		local built = Instance.new("TextLabel")
		built.Name = MUTATION_FALLBACK
		built.BackgroundTransparency = 1
		built.AnchorPoint = Vector2.new(0.5, 0)
		built.Position = UDim2.fromScale(0.5, 0.03)
		built.Size = UDim2.fromScale(0.9, 0.16)
		built.Font = Enum.Font.GothamBlack
		built.TextScaled = true
		built.TextColor3 = WHITE
		built.ZIndex = 50
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Parent = built
		built.Parent = card.frame
		label = built
	end
	if label and label:IsA("TextLabel") then
		label.Text = string.format(MUTATION_COUNT_TEXT, #names, IndexMutations.PerItem)
		label.Visible = shown
	end
end

-- Revenu affiché dans la fiche : « $X/s » (vague 76 : Formulas.ItemIncome, rareté, zone et rang de l'objet ;
-- un Secret a un seul revenu).
local function incomeText(item: Item): string
	return `{Format.money(Formulas.RoundIncome(Formulas.ItemIncome(item.Id)))}/s` -- a493 : sans décimales
end

------------------------------------------------------------------------------
-- Cartes et en-têtes
------------------------------------------------------------------------------

local function paint(current: Screen, card: Card)
	paintMutations(current, card)
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
	-- Vague GC6 (a410) : effets obtenus. DetailMutations (facultatif, Clément) dans toutes les catégories ; sans lui,
	-- en MUTATIONS, DetailIncome les montre à la place du revenu (repli lisible).
	if current.v3 and mutationsOn() and IndexMutations.Counts(item) then
		local names = mutationNames(item)
		local text = if #names > 0 then table.concat(names, MUTATION_SEPARATOR) else NO_MUTATION_TEXT
		local own = Find.path(detail, "DetailMutations")
		if own then
			setText(own, text)
		elseif category == MUTATIONS then
			setText(current.detailIncome, text)
		end
	end
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

-- Rewards (v3) : la zone de la section visible dans la liste. Vague 61 (L-192) : la récompense n'est plus
-- qu'un objet, sans place en v3 ; SpeedReward et CashReward (argent et vitesse d'avant) sont cachés.
local function refreshRewards(current: Screen)
	local rewards = current.rewards
	if rewards == nil then
		return
	end
	setVisible(current.speedReward, false)
	setVisible(current.cashReward, false)
	local rank = current.viewSection
	local section = if rank then current.sections[rank] else nil
	local zone = if section then section.def.zone else nil
	setVisible(rewards, current.rewardsShown and category == NORMAL and zone ~= nil)
	if zone == nil or section == nil then
		return
	end
	setText(current.claimLabel, if claimed[zone] then V3_CLAIMED_TEXT else (current.claimText or ""))
	-- L-201 point 3 : en cours ou réclamée, UIGradient (gris) ; prête, ReadyGradient (vert) à sa place (ClaimAlert :
	-- refreshAlerts). Sans ReadyGradient (écran d'avant) : rien ne change.
	local ready = current.readyGradient
	if ready then
		local claimable = isClaimable(zone)
		if ready.Enabled ~= claimable then
			ready.Enabled = claimable
		end
		local grey = current.claimGradient
		if grey and grey.Enabled == claimable then
			grey.Enabled = not claimable
		end
	end
	-- L-201 point 4 : Rewards.ItemReward, l'objet donné par la zone (son image et son nom, « WRENCH »).
	paintRewardIcon(current.itemIcon, zone)
	setText(current.itemCaption, string.upper(Index.ZoneRewardName(zone)))
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
		if current.v3 and zone ~= nil and section.zoneTheme ~= nil then
			paintCity(section, zone) -- v3 refait (L-201) : la ville et le thème ; sans ZoneTheme, les magasins comme avant
		elseif stores then
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
		-- v3 refait (L-201 point 2) : ZoneBar.RewardIcon (l'objet donné) remplace ZoneItem (laissé tel quel).
		if section.rewardIcon and zone ~= nil then
			paintRewardIcon(section.rewardIcon, zone)
		end
		local rarest = if section.zoneItem and section.rewardIcon == nil then rarestOf(itemsOf(section.def)) else nil
		if rarest then
			setImage(section.zoneItem, textureOf(rarest.Id) or "", if isFound(current, rarest) then FOUND_COLOR else silhouetteOf(rarest))
		end
	end
	if current.v3 then
		for _, item in Index.Listed do -- a497 : sans les objets hors tirage (Index.Total)
			if isFound(current, item) then
				all += 1
			end
		end
		setText(current.counter, string.format(COUNTER_TEXT, all, Index.Total)) -- L-201 point 5 : « 23 / 83 discovered »
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
	refresh() -- vague GC6 (a410) : les cartes trouvées dépendent de l'onglet choisi
	cardsIn(current)
end

-- Rien à réclamer : son de refus et le bouton tremble (View.Deny).
local function deny(shaking: { [GuiObject]: boolean }, button: GuiObject?)
	Motion.PlaySound(VIEW.Deny.Sound)
	if button == nil or shaking[button] then
		return
	end
	shaking[button] = true
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
		shaking[button] = nil
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
		deny(current.shaking, button) -- zone pas complète ou déjà réclamée
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
		deny(current.shaking, button)
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
		Motion.PlaySound("Index_Reward") -- vague 72 (a246, L-229 B) : la prime de la zone est confirmée
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
	local rewardIcon = if zoneBar then Find.path(zoneBar, "RewardIcon") else nil
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
		zoneTheme = if root then Find.path(root, "ZoneTheme") else nil,
		rewardIcon = if rewardIcon and isImage(rewardIcon) then rewardIcon :: GuiObject else nil,
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
	local older: { string } = table.move(SCREEN_ORDER, rank + 1, #SCREEN_ORDER, 1, {})
	table.move(RETIRED_SCREENS, 1, #RETIRED_SCREENS, #older + 1, older) -- a508
	for _, name in older do
		local other = parent:FindFirstChild(name)
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
	local claimGradient = if claimButton then claimButton:FindFirstChild(CLAIM_GRADIENT) else nil
	local readyGradient = if claimButton then claimButton:FindFirstChild(READY_GRADIENT) else nil
	local itemReward = if rewards then Find.path(rewards, "ItemReward") else nil
	local itemIcon = if itemReward then Find.path(itemReward, "RewardIcon") else nil
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
		speedReward = if rewards then guiObject(rewards, "SpeedReward") else nil,
		cashReward = if rewards then guiObject(rewards, "CashReward") else nil,
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
		claimGradient = if claimGradient and claimGradient:IsA("UIGradient") then claimGradient :: UIGradient else nil,
		readyGradient = if readyGradient and readyGradient:IsA("UIGradient") then readyGradient :: UIGradient else nil,
		itemIcon = if itemIcon and isImage(itemIcon) then itemIcon :: GuiObject else nil,
		itemCaption = if itemReward then Find.path(itemReward, "RewardCaption") else nil,
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
		-- Vague 72 (a242, L-213) : ClaimAllButton retiré par Clément (hors contrat) : branché seulement s'il revient.
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
			elseif key ~= SECRETS then -- SecretsButton : retiré de l'écran refait (L-201), facultatif
				reportOnce(`category:{key}`, `[Index] {name}.Categories.{key} introuvable : catégorie pas branchée`)
			end
		end
		-- L-201 point 6 : la catégorie LIMITED n'existe pas encore, son bouton reste caché.
		setVisible(if categories then guiObject(categories, LIMITED) else nil, false)
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

-- Vague 59 (L-183) : un écran v4 = UI_Index_v4, ou UI_Index refait sous son ancien nom (Cards et Footer.Pager
-- dedans). Il passe avant tous les autres (bloc « UI_Index_v4 » plus bas).
local V4_SCREEN = "UI_Index_v4"
local function isV4(inst: Instance): boolean
	if not inst:IsA("ScreenGui") then
		return false
	end
	if inst.Name == V4_SCREEN then
		return true
	end
	return false -- a508 (L-475) : l'ancien UI_Index refait en v4 n'est plus lu
end

-- L'écran à brancher dans PlayerGui : UI_Index_v3 (a508 : plus de repli ; jamais un v4).
local function findScreen(playerGui: Instance): ScreenGui?
	for _, name in SCREEN_ORDER do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") and not isV4(gui) then
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
		reportOnce("screen", `[Index] écran {SCREEN} absent de PlayerGui : l'index ne s'ouvre pas (a508 : {V2_SCREEN} et {LEGACY_SCREEN} ne sont plus lus)`)
		return
	end
	readDiscovered()
	readMutations()
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
		local first = byRarity(Index.ByZone[1] or NO_ITEMS) -- vague 71 : la première carte montrée
		local item = selected or first[1]
		if item then
			selected = item
			showDetail(current, item)
		end
	end
	Motion.Open(current.gui)
end

------------------------------------------------------------------------------
-- UI_Index_v4 (L-183, vague 59, a191) : une zone à la fois, grille Cards de 4 × 2, pages
------------------------------------------------------------------------------

-- Une carte de la v4 (page affichée).
type V4Card = { item: Item, frame: GuiObject }

type V4 = {
	gui: ScreenGui,
	template: GuiObject?,
	cardParent: Instance?, -- Cards
	counter: Instance?, -- UnlockedBar.Counter
	zoneArt: Instance?,
	zoneArtImage: string?, -- image posée par Clément, gardée quand aucune façade n'est livrée
	zoneName: Instance?,
	zoneTheme: Instance?,
	fill: GuiObject?,
	fillSize: UDim2,
	zoneCount: Instance?,
	tabs: { [number]: GuiObject }, -- [rang dans TABS] = onglet
	tabAlerts: { [number]: GuiObject },
	pageLabel: Instance?,
	claimButton: GuiObject?,
	claimShown: boolean, -- visibilité de ClaimButton posée par Clément
	claimAlert: GuiObject?,
	rewardIcon: Instance?,
	rewardCaption: Instance?,
	itemIcon: Instance?, -- Footer.ItemReward.RewardIcon (L-192)
	itemCaption: Instance?, -- Footer.ItemReward.RewardCaption (L-192)
	itemAmount: Instance?, -- Footer.ItemReward.Amount, d'avant L-192
	cashReward: GuiObject?, -- Footer.CashReward et SpeedReward d'avant L-192 : cachés
	speedReward: GuiObject?,
	shaking: { [GuiObject]: boolean },
	connections: { RBXScriptConnection },
	cards: { V4Card },
}

local V4_PAGE_TEXT = "%d/%d" -- V0 proposé, absent du doc : PageLabel « 1/2 »
local ZONE_ART_PREFIX = "UI_ZoneArt_" -- façades de l'index (notes figma, Images à générer) : UI_ZoneArt_Z1…, _Secrets
local v4: V4? = nil
local v4Open = false
local v4Tab = 1 -- rang dans TABS : zones 1 à 6, puis les Secrets
local v4Page = 1
local zoneArts: { [string]: string | false } = {} -- [nom du Decal] = image (false : pas livrée)

local function findV4(playerGui: Instance): ScreenGui?
	for _, name in { V4_SCREEN } do -- a508 : plus l'ancien UI_Index refait
		local gui = playerGui:FindFirstChild(name)
		if gui and isV4(gui) then
			return gui :: ScreenGui
		end
	end
	return nil
end

-- Image de la façade de la zone (Decal UI_ZoneArt_Z<n> ou UI_ZoneArt_Secrets sous ReplicatedStorage/Assets),
-- cherchée une fois par session ; nil si elle n'est pas livrée.
local function zoneArtOf(def: TabDef): string?
	local name = ZONE_ART_PREFIX .. (if def.zone then `Z{def.zone}` else "Secrets")
	local known = zoneArts[name]
	if known ~= nil then
		if type(known) == "string" then
			return known
		end
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local image: string | false = false
	if assets then
		for _, descendant in assets:GetDescendants() do
			if descendant.Name == name and descendant:IsA("Decal") and (descendant :: Decal).Texture ~= "" then
				image = (descendant :: Decal).Texture
				break
			end
		end
	end
	zoneArts[name] = image
	if image == false then
		reportOnce(`zoneart:{name}`, `[Index] façade {name} pas livrée : ZoneArt garde l'image de l'écran`)
		return nil
	end
	return image
end

local function v4Items(): { Item }
	return itemsOf(TABS[v4Tab])
end

local function v4Pages(): number
	return math.max(1, math.ceil(#v4Items() / VIEW.PageSize))
end

local function clearV4Cards(current: V4)
	for _, card in current.cards do
		card.frame:Destroy()
	end
	table.clear(current.cards)
end

-- Fond de la couleur de la rareté (assombri tant que l'objet n'est pas trouvé), silhouette et « ??? ».
local function paintV4Card(card: V4Card)
	local item = card.item
	local found = discovered[item.Id] == true
	local color = rarityColor(item)
	local clip = guiObject(card.frame, "Clip")
	if clip then
		clip.BackgroundColor3 = if found then color else color:Lerp(BLACK, VIEW.ClipDarken)
	end
	setImage(Find.path(card.frame, "Icon"), textureOf(item.Id) or "", if found then FOUND_COLOR else silhouetteOf(item))
	setText(Find.path(card.frame, "ItemName"), if found then item.DisplayName else UNKNOWN_NAME)
end

-- Cartes de la page affichée, clonées depuis Template.
local function buildV4Cards(current: V4)
	clearV4Cards(current)
	local template = current.template
	local parent = current.cardParent
	if template == nil or parent == nil then
		return
	end
	local items = v4Items()
	local first = (v4Page - 1) * VIEW.PageSize
	local wanted: { string } = {}
	for rank = first + 1, math.min(first + VIEW.PageSize, #items) do
		local item = items[rank]
		local clone: Instance? = template:Clone()
		if clone == nil then
			return -- Archivable = false : rien à cloner
		end
		local frame = clone :: GuiObject
		frame.Name = string.format(CARD_FORMAT, rank, item.Id)
		frame.LayoutOrder = rank
		-- Rareté lue par le module d'animations d'UI (dégradés qui bougent, L-182 point 2).
		frame:SetAttribute("Rarity", item.Rarity)
		local color = rarityColor(item)
		for _, name in TINTED do
			local tinted = Find.path(frame, name)
			if tinted and isImage(tinted) then
				(tinted :: any).ImageColor3 = color
			end
		end
		local rainbow = RAINBOW
		if rainbow and isRainbow(item) then
			local gradient = Find.path(frame, "Clip.RarityGradient")
			if gradient == nil or not gradient:IsA("UIGradient") then
				local clip = Find.path(frame, "Clip")
				gradient = if clip then clip:FindFirstChildOfClass("UIGradient") else nil
			end
			if gradient and gradient:IsA("UIGradient") then
				(gradient :: UIGradient).Color = rainbow
			end
		end
		local card: V4Card = { item = item, frame = frame }
		paintV4Card(card)
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

-- Pastilles « ! » de la v4, ouverte ou pas : la zone affichée (ClaimAlert) et chaque onglet de zone.
local function refreshV4Alerts(current: V4)
	AlertBadge.Set(current.claimAlert, isClaimable(TABS[v4Tab].zone))
	for rank, alert in current.tabAlerts do
		AlertBadge.Set(alert, isClaimable(TABS[rank].zone)) -- Secrets (zone nil) : toujours éteinte
	end
end

-- En-tête, barre de progression, pages et récompense de la zone affichée.
local function refreshV4(current: V4)
	local def = TABS[v4Tab]
	local zone = def.zone
	local items = itemsOf(def)
	local found, total = 0, #items
	for _, item in items do
		if discovered[item.Id] then
			found += 1
		end
	end
	setText(current.counter, string.format(V3_COUNTER_TEXT, Index.CountAll(discovered), Index.Total))
	local info = if zone then Zones[zone] else nil
	if info then
		setText(current.zoneName, string.upper(info.City or info.Theme))
		setText(current.zoneTheme, if #info.Stores > 0 then string.upper(table.concat(info.Stores, " · ")) else info.Theme)
	else
		setText(current.zoneName, string.upper(SECRETS_NAME))
	end
	local art = zoneArtOf(def)
	local zoneArt = current.zoneArt
	if zoneArt and isImage(zoneArt) then
		local wantedArt = art or current.zoneArtImage
		if wantedArt and (zoneArt :: any).Image ~= wantedArt then
			(zoneArt :: any).Image = wantedArt
		end
	end
	setText(current.zoneCount, string.format(V3_ZONE_COUNT_TEXT, found, total))
	local fill = current.fill
	if fill then
		local size = current.fillSize
		local wantedSize = UDim2.new(if total > 0 then math.clamp(found / total, 0, 1) else 0, size.X.Offset, size.Y.Scale, size.Y.Offset)
		if fill.Size ~= wantedSize then
			fill.Size = wantedSize
		end
	end
	for rank, button in current.tabs do
		setVisible(guiObject(button, SELECTED), rank == v4Tab)
	end
	setText(current.pageLabel, string.format(V4_PAGE_TEXT, v4Page, v4Pages()))
	-- Récompense : seulement pour une zone (les Secrets n'en ont pas).
	setVisible(current.claimButton, current.claimShown and zone ~= nil)
	if zone then
		local name = Index.ZoneRewardName(zone)
		setText(current.rewardCaption, if claimed[zone] then CLAIMED_TEXT else Index.ZoneRewardText(zone))
		-- Vague 61 (L-192) : Footer.ItemReward, l'objet seul (son nom et son image).
		setText(current.itemCaption, name)
		setText(current.itemAmount, name)
		local iconName = Index.ZoneRewardIcon(zone)
		local image = if iconName then Icons.get(iconName) else nil
		if image then
			setImage(current.rewardIcon, image, FOUND_COLOR)
			setImage(current.itemIcon, image, FOUND_COLOR)
		elseif iconName then
			reportOnce(`rewardicon:{iconName}`, `[Index] icône {Icons.name(iconName)} pas livrée : RewardIcon garde l'image de l'écran`)
		end
	end
	-- Plus d'argent ni de vitesse (L-192) : CashReward et SpeedReward d'un écran d'avant sont cachés.
	setVisible(current.cashReward, false)
	setVisible(current.speedReward, false)
	refreshV4Alerts(current)
end

local function closeV4()
	v4Open = false
	local current = v4
	if current then
		Motion.Close(current.gui, function()
			if not v4Open then
				clearV4Cards(current)
			end
		end)
	end
end

local function showV4(current: V4)
	if v4 ~= current or not v4Open then
		return
	end
	buildV4Cards(current)
	refreshV4(current)
end

local function bindV4(gui: ScreenGui)
	local old = v4
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
		clearV4Cards(old)
	end
	v4Open = false
	gui.Enabled = false -- fermé jusqu'au bouton du HUD
	Motion.SetCloser(gui, closeV4)
	-- Les écrans d'avant, rangés à côté, restent éteints.
	local parent = gui.Parent
	if parent then
		for _, name in table.move(RETIRED_SCREENS, 1, #RETIRED_SCREENS, #SCREEN_ORDER + 1, table.clone(SCREEN_ORDER)) do -- a508 : et les retirés
			local other = parent:FindFirstChild(name)
			if other and other ~= gui and other:IsA("ScreenGui") then
				(other :: ScreenGui).Enabled = false
			end
		end
	end
	local template = guiObject(gui, "Cards.Template") or guiObject(gui, "Template")
	if template == nil then
		reportOnce("v4template", `[Index] {gui.Name}.Cards.Template introuvable : l'index restera vide`)
	else
		template.Visible = false
	end
	local cards = Find.path(gui, "Cards")
	local zoneArt = Find.path(gui, "ZoneArt")
	local zoneBar = Find.path(gui, "ZoneBar")
	local fill = if zoneBar then guiObject(zoneBar, "Fill") else nil
	local footer = Find.path(gui, "Footer")
	local claimButton = if footer then guiObject(footer, "ClaimButton") else nil
	local current: V4 = {
		gui = gui,
		template = template,
		cardParent = cards or (if template then template.Parent else nil),
		counter = Find.path(gui, "UnlockedBar.Counter"),
		zoneArt = zoneArt,
		zoneArtImage = if zoneArt and isImage(zoneArt) then (zoneArt :: any).Image else nil,
		zoneName = if zoneArt then Find.path(zoneArt, "ZoneName") else nil,
		zoneTheme = if zoneArt then Find.path(zoneArt, "ZoneTheme") else nil,
		fill = fill,
		fillSize = if fill then fill.Size else UDim2.new(1, 0, 1, 0),
		zoneCount = if zoneBar then Find.path(zoneBar, "ZoneCount") else nil,
		tabs = {},
		tabAlerts = {},
		pageLabel = if footer then Find.path(footer, "Pager.PageLabel") else nil,
		claimButton = claimButton,
		claimShown = if claimButton then claimButton.Visible else false,
		claimAlert = if claimButton then guiObject(claimButton, CLAIM_ALERT) else nil,
		rewardIcon = if claimButton then Find.path(claimButton, "RewardIcon") else nil,
		rewardCaption = if claimButton then Find.path(claimButton, "RewardCaption") else nil,
		itemIcon = if footer then Find.path(footer, "ItemReward.RewardIcon") else nil,
		itemCaption = if footer then Find.path(footer, "ItemReward.RewardCaption") else nil,
		itemAmount = if footer then Find.path(footer, "ItemReward.Amount") else nil,
		cashReward = if footer then guiObject(footer, "CashReward") else nil,
		speedReward = if footer then guiObject(footer, "SpeedReward") else nil,
		shaking = {},
		connections = {},
		cards = {},
	}
	v4 = current
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	keep(onClick(Find.path(gui, "CloseButton"), closeV4))
	for rank, def in TABS do
		local button = guiObject(gui, def.path)
		if button == nil then
			reportOnce(`v4tab:{def.path}`, `[Index] {gui.Name}.{def.path} introuvable : onglet pas branché`)
			continue
		end
		current.tabs[rank] = button
		local alert = guiObject(button, "ZoneAlert")
		if alert then
			current.tabAlerts[rank] = alert
		end
		keep(onClick(button, function()
			if v4 == current and v4Open and v4Tab ~= rank then
				v4Tab = rank
				v4Page = 1
				showV4(current)
			end
		end))
	end
	local pager = if footer then Find.path(footer, "Pager") else nil
	if pager == nil then
		reportOnce("v4pager", `[Index] {gui.Name}.Footer.Pager introuvable : seule la 1re page se voit`)
	end
	-- Page suivante ou précédente, en boucle.
	local function turn(step: number)
		if v4 == current and v4Open then
			local pages = v4Pages()
			v4Page = ((v4Page - 1 + step) % pages) + 1
			showV4(current)
		end
	end
	keep(onClick(if pager then Find.path(pager, "PrevButton") else nil, function()
		turn(-1)
	end))
	keep(onClick(if pager then Find.path(pager, "NextButton") else nil, function()
		turn(1)
	end))
	if claimButton == nil then
		reportOnce("v4claim", `[Index] {gui.Name}.Footer.ClaimButton introuvable : récompense de zone pas réclamable`)
	end
	keep(onClick(claimButton, function()
		local zone = TABS[v4Tab].zone
		local button = claimButton
		if v4 ~= current or not v4Open or zone == nil or button == nil then
			return
		end
		if isClaimable(zone) then
			sendClaim(button, zone)
		else
			deny(current.shaking, button) -- zone pas complète ou déjà réclamée
		end
	end))
	refreshV4Alerts(current) -- pastilles « ! » allumées dès le branchement, écran fermé
end

local function openV4(gui: ScreenGui)
	local current = v4
	if current == nil or current.gui ~= gui then
		bindV4(gui)
		current = v4
	end
	if current == nil then
		return
	end
	readDiscovered()
	v4Open = true
	if v4Page > v4Pages() then
		v4Page = 1
	end
	showV4(current)
	Motion.Open(current.gui)
end

local function toggle()
	local fourth = v4
	if v4Open and fourth and fourth.gui.Parent == nil then
		v4Open = false -- écran recréé (ResetOnSpawn) : le nouveau est fermé
	end
	if v4Open then
		closeV4()
		return
	end
	if isOpen then
		close()
		return
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then findV4(playerGui) else nil
	if gui then
		openV4(gui)
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
		Motion.Activated(button):Connect(toggle)
	end
end

function IndexController.Start()
	if not Features.Index then
		return -- MAJ 2 : rien n'est branché, l'écran reste fermé
	end
	readDiscovered()
	readMutations()
	readClaimed()
	-- Pastilles « ! » de l'écran branché, ouvert ou pas (L-127).
	local function alerts()
		local current = screen
		if current and current.gui.Parent ~= nil then
			refreshAlerts(current)
		end
		local fourth = v4
		if fourth and fourth.gui.Parent ~= nil then
			if v4Open then
				for _, card in fourth.cards do
					paintV4Card(card)
				end
				refreshV4(fourth)
			else
				refreshV4Alerts(fourth)
			end
		end
	end
	localPlayer:GetAttributeChangedSignal(Index.Attribute):Connect(function()
		readDiscovered()
		refresh()
		alerts()
	end)
	-- Vague GC6 (a410) : colonnes de mutations.
	localPlayer:GetAttributeChangedSignal(IndexMutations.Attribute):Connect(function()
		readMutations()
		refresh()
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
		if isV4(child) then
			bindV4(child :: ScreenGui) -- vague 59 : la v4 passe avant les autres (bindV4 les éteint)
			return
		end
		local rank = screenRank(child.Name)
		if rank ~= nil then
			local current = screen
			local currentRank = if current and current.gui.Parent ~= nil then screenRank(current.gui.Name) else nil
			if (currentRank ~= nil and currentRank < rank) or (v4 ~= nil and (v4 :: V4).gui.Parent ~= nil) then
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
	local fourth = findV4(playerGui)
	if fourth then
		bindV4(fourth)
	end
	local hud = playerGui:FindFirstChild(HUD)
	if hud and hud:IsA("ScreenGui") then
		bindHud(hud)
	end
end

return IndexController
