--!strict
-- RobuxShopController (DEV-100, client) : boutique Robux, écran UI_RobuxShop_v2 de Clément (UI-100, noms
-- validés en L-047 ; Partie 2, sections 3.1 et 4 ; offres : Config/Monetization). Seulement si
-- Features.RobuxShop ou Features.RobuxShopPreview : les deux à false, rien n'est branché et l'écran
-- reste fermé.
--
-- Vitrine (L-071, décision d'Ironix du 2026-11-08) : avec Features.RobuxShop à false (jusqu'à la
-- MAJ 1 ; MonetizationService coupé) et Features.RobuxShopPreview à true, l'écran s'ouvre comme
-- ci-dessous (bouton du HUD, invite du comptoir, plaque ShopPad), avec les mêmes onglets, cartes et
-- prix, mais rien ne s'achète : aucun appel à MarketplaceService (ni fenêtre d'achat, ni lecture des
-- prix chez Roblox : ceux de la Config), et un clic sur BuyButton écrit SOON_TEXT (« Soon ») à la
-- place du prix pendant SOON_DURATION secondes. Le même retour vaut, boutique ouverte, pour une offre
-- dont l'Id est encore à 0. Le serveur étant coupé, la vitrine ne montre ni gamepass possédé, ni pack
-- de départ (onglet Offers vide), ni colis à ouvrir (« No box is waiting »). Avec Features.RobuxShop à
-- true, tout marche comme ci-dessous (vague 13), sauf ce retour « Soon » sur une offre à l'Id 0.
--
-- Rôle :
--   - ouvre l'écran par UI_HUD.RobuxShopButton (partout ; un 2e appui le ferme) et par une invite
--     (ProximityPrompt « RobuxShopPrompt » : « Shop », « Robux Shop ») sur le comptoir taggé RobuxShop
--     de la zone safe (sa PrimaryPart, sinon sa première pièce), ou en marchant sur la plaque ShopPad
--     du comptoir (ShopPadController, L-071) ; CloseButton le ferme. Il ne se ferme pas quand on
--     s'éloigne du comptoir : la boutique Robux s'ouvre partout (5.9) ;
--   - 4 onglets : Tabs.OffersTab (pack de départ, tant que l'attribut StarterPackEndsAt le propose),
--     GamepassesTab, CashTab (packs d'argent), BoostsTab (Ouvrir maintenant). À l'ouverture : Offres si
--     le pack de départ est proposé, sinon Gamepasses ; ensuite le dernier onglet choisi ;
--   - une carte par offre codée (Ready) de l'onglet, clonée depuis List.Template, dans l'ordre de la
--     Config :
--       Icon       image de l'offre : Decal nommé comme son Icon dans ReplicatedStorage/Assets (rendus
--                  MOD-100), sinon l'image d'une carte de la maquette dont l'attribut IconAsset porte ce
--                  nom (lue avant que les cartes Preview_* soient retirées), sinon celle du Template ;
--       ItemName   nom (Config) ;
--       Effect     ligne d'effet ; pack d'argent : « +$12.4K · 10 min of income » (revenu du HUD,
--                  attribut Income, Monetization.CashPackAmount) ; Ouvrir maintenant : attente du colis
--                  qui attend le plus (attribut OpenNowReadyAt) ;
--       Price      prix en Robux : celui de Roblox (MarketplaceService:GetProductInfoAsync, gardé en
--                  cache) quand l'Id existe, sinon celui de la Config ; Ouvrir maintenant : le palier de
--                  l'attente restante (Monetization.OpenNowTier) ;
--       BuyButton  ouvre la fenêtre d'achat de Roblox (PromptGamePassPurchase, PromptProductPurchase) ;
--                  Id à 0 : pas d'achat, « Soon » à la place du prix (vitrine, plus haut) et une ligne
--                  dans la sortie en Studio. Ouvrir maintenant sans colis à ouvrir : visible (vague 71) ;
--                  vague 66 (a218, L-210) : offre pas en vente (Id à 0, effet pas codé, aucun palier
--                  d'Ouvrir maintenant créé) : Price dit « Soon » en permanence, bouton visible ;
--       Owned      gamepass possédé (attribut Pass<Clé> du Player, posé par MonetizationService) :
--                  Owned visible et BuyButton caché (la coche verte et le bouton gris de la maquette).
--     Les cartes suivent les attributs du Player (Pass…, StarterPackEndsAt, OpenNowReadyAt, Income) et
--     se mettent à jour chaque seconde tant que l'écran est ouvert ;
--   - les cartes d'exemple de la maquette (Preview_*, à côté du Template) sont retirées de la copie du
--     joueur, comme dans les boutiques d'armes et d'auras.
-- Ouverture et fermeture animées (DEV-052) par UI/Motion, comme les boutiques d'armes et d'auras : les
-- cartes restent écran fermé (vague 65, a216 : refaites seulement si les offres ont changé), et une réouverture
-- pendant la fermeture la rattrape.
-- Seuls sont touchés : Enabled de l'écran, les textes, la visibilité, le nom et l'ordre des cartes
-- clonées, l'image de Icon (2.2, « Libre pour Ironix ») ; jamais un style (l'effet d'échelle de Motion
-- est passager). Texte d'un élément : sur lui
-- s'il en porte un, sinon dans son premier TextLabel ; en capitales si le texte d'exemple l'est
-- (« ×2 CASH »). Le serveur décide tout (MonetizationService) : le client n'envoie rien, il ouvre la
-- fenêtre d'achat de Roblox et affiche.
--
-- Vague 63 (a208 ; L-196, L-200, L-204) :
--   - 6 packs d'argent ; le boost du HUD « zZz » (a319 : « ×2 Speed » est devenu un gamepass) (Monetization.ShopBoosts, prix, Id et Ready
--     de Config/Boosts : même produit que les boutons du HUD) dans l'onglet Boosts, avant Ouvrir maintenant.
--     Pas encore codés côté serveur (Ready = false) : la carte montre le prix et « Soon » au clic, rien n'est
--     vendu, même boutique ouverte ;
--   - UI_RobuxShop_v2 (L-200, noms v3 de L-204 ; a438 : le seul écran, l'ancien UI_RobuxShop est retiré et
--     gardé éteint s'il est encore livré). Une seule liste List qui défile :
--       Tabs.*Tab   ne filtrent plus : ils font défiler List jusqu'à leur section (Shop.ScrollTime) :
--                   OffersTab = Crate, ou Featured si la caisse est cachée, sinon GamepassesSection ;
--       GamepassesSection, BoostsSection, CashSection : Grid remplie depuis son Template (mêmes champs que
--                   les cartes plus haut, sauf Effect, jamais écrit : caché par Clément) ; section cachée
--                   sans offre ; la Grid prend le nombre de rangées de ses cartes (attribut Columns de la
--                   Grid) et List.Content suit (seules les hauteurs en Scale et les rapports changent) ;
--       CardColor   couleur de chaque carte (Config/Monetization, proposition de Clément en L-204) : les tons
--                   du UIGradient de la carte et ses Studs passent de la couleur du Template à la sienne,
--                   en gardant les mêmes écarts (plus clair, plus foncé) ;
--       Featured    pack de départ tant qu'il est proposé (caché sinon) : ItemName, Perks.Perk1 à 3 (Label,
--                   d'après la Config), Timer.Label (« Ends in 42:10 »), BuyButton (Price) ;
--       Crate       caisse exclusive (Monetization.Crate) : cachée sauf Monetization.Crate.Live (a294), chances
--                   décidées (Odds) et PolicyService:GetPolicyInfoForPlayerAsync qui permet les objets
--                   payants au hasard (ArePaidRandomItemsRestricted faux ; erreur = cachée). Odd_n.Chance =
--                   chance réelle, BuyRow.BuyButton1 à 3 : Price, Count (« 3 CRATES ») et OldPrice
--                   (UnitPrice × Count, caché sans remise). Crate.Ready à false : « Soon », rien de vendu.
--   - lueur d'achat (L-204 point 2) : juste avant d'ouvrir une fenêtre d'achat de Roblox, PurchaseGlow.Show()
--     (Controllers/UI/PurchaseGlow, a209) s'il existe ; jamais sur « Soon » (aucune fenêtre ne se fermerait).
--
-- API (client) :
--   RobuxShopController.Open(anchor?)
--       Ouvre l'écran, comme le bouton du HUD (sans effet s'il est déjà ouvert, ou si la boutique et
--       sa vitrine sont coupées). `anchor` est ignoré : la boutique Robux ne se ferme pas quand on
--       s'éloigne. Appelé par ShopPadController (plaque ShopPad du comptoir, L-071).
--   RobuxShopController.Leave(anchor?)
--       Vague 66 (L-210 point 7) : le joueur descend de la plaque du comptoir : l'écran se ferme s'il est ouvert.
--
-- Vague 71 (a238, L-213 point 1) :
--   (a) v2 : List.CanvasSize posé par le code (AutomaticCanvasSize = None) à la hauteur de List.Content plus le
--       UIPadding de List (haut + bas, en px), refait à chaque changement de Content.AbsoluteSize : la dernière
--       rangée (3 h, 5 h, 12 h) n'est plus sous le bord (AutomaticCanvasSize ne suivait pas fitGrid et fitContent) ;
--   (b) Ouvrir maintenant garde son bouton de prix sans objet à ouvrir : prix du premier palier (Config), et au
--       clic « No item » (ou « Almost ready » sous OpenNow.MinRemaining) à la place du prix pendant SOON_DURATION s ;
--   (c) Clip.Watermark de chaque carte clonée reprend l'image de son Icon (sans Watermark : rien).
--
-- Vague 72 (a247, L-229, L-216 point 8) : son Shop_Buy (Motion.PlaySound, Assets/Sounds ; absent = muet) quand une
-- fenêtre d'achat de Roblox se ferme sur un achat fait (PromptProductPurchaseFinished, PromptGamePassPurchaseFinished
-- du joueur local), boutique ouverte seulement (Features.RobuxShop), quel que soit le bouton qui l'a ouverte. Les
-- cartes de la chance du serveur (ServerLuck2, 4, 8) sont des produits comme les autres (onglet Boosts).
--
-- Vague 73 (a253 ; L-242 point 3, L-243, L-247) :
--   - lots de la caisse : Count = « Buy x1 », « Buy x3 », « Buy x10 » ; Effect de nouveau écrit dans les cartes clonées
--     de la v2 (effectOf) ;
--   - Featured : OldPrice = Monetization.StarterPack.OldPrice, DiscountTag.DiscountLabel = « 75% OFF » (tiré du prix
--     affiché) ; les deux cachés sans remise. OfferLabel garde le texte de Clément ;
--   - écran allumé : chaque Rays (cartes, cases de la caisse, Featured ; hors Template et hors Crate.Backdrop, que tourne
--     CrateLoop) tourne de Shop.RaysTurn par Shop.RaysPeriod, son UIGradient Fade à l'inverse ; tout revient à la
--     valeur de Clément à l'extinction de l'écran et au réglage « animations réduites » ;
--   - ViewportFrame Preview : CurrentCamera remis sur sa Camera après la copie dans le PlayerGui (L-247 a) ; celle de la
--     caisse (Crate.Icon.Preview) se balance de ± Shop.PreviewSway° autour du pivot de son modèle (L-247 b).
--     a278 (L-272) : Crate en IconHover = Spring : au survol (ou au toucher), la caisse se tourne vers le pointeur à la
--     place du balancement (UI/UiAttrFx.Spring, Config/UiMotion.AttrFx.IconHover.Spring), puis le balancement reprend.
--   Onglets (Root.Tabs, cachés par Clément, L-243 c) : leur code reste, il ne touche jamais leur visibilité.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Monetization = require(Config:WaitForChild("Monetization"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))
-- a278 (L-272) : IconHover = Spring sur Crate : UI/UiAttrFx suit le pointeur (UiAttrFx.Spring) ; module absent ou
-- Features.UiAttrFx coupé : poids 0, la caméra de la caisse se balance comme avant.
local springOf = function(_: Instance): (number, number, number)
	return 0, 0, 0
end
do
	local folder = script.Parent:FindFirstChild("UI")
	local module = if folder then folder:FindFirstChild("UiAttrFx") else nil
	if module and module:IsA("ModuleScript") then
		local ok, loaded = pcall(require, module)
		if ok and type(loaded) == "table" and type((loaded :: any).Spring) == "function" then
			springOf = (loaded :: any).Spring
		end
	end
end

-- Onglet (Monetization.Tab), en texte : l'ancien solveur élargit ses valeurs d'un module à l'autre.
type Tab = string
type Pass = Monetization.Pass
type Product = Monetization.Product
type ShopBoost = Monetization.ShopBoost
type CratePack = Monetization.CratePack

-- Une offre de l'écran : un gamepass, un produit développeur, un boost du HUD ou un lot de la caisse.
type Offer = {
	key: string,
	tab: Tab,
	order: number,
	displayName: string,
	effect: string,
	icon: string,
	color: Color3?,
	pass: Pass?,
	product: Product?,
	boost: ShopBoost?,
	crate: CratePack?,
}

-- Une carte : clonée (cloned = true, retirée à la fermeture) ou un cadre de Clément de la v2 (Featured, un
-- bouton de la caisse : gardés).
type Card = {
	offer: Offer,
	frame: GuiObject,
	buy: GuiObject?,
	owned: GuiObject?,
	soonUntil: number?, -- os.clock() jusqu'où Price montre SOON_TEXT (clic sans achat possible)
	soonText: string?, -- vague 71 : texte montré à la place de SOON_TEXT (Ouvrir maintenant sans objet)
	cloned: boolean,
}

-- Hauteurs d'une section de la v2, en largeurs de la section, lues au branchement (fitGrid).
type GridFit = {
	ratio: UIAspectRatioConstraint,
	grid: GuiObject,
	layout: UIGridLayout,
	height: number, -- hauteur de la section
	gridHeight: number,
	cell: number, -- hauteur d'une carte
	gap: number, -- écart entre deux rangées
	columns: number,
	scales: { [GuiObject]: { position: number, size: number } }, -- Scale en Y des enfants de la section
}

-- Une section à cartes de la v2.
type Section = {
	tab: Tab,
	frame: GuiObject,
	grid: GuiObject?,
	template: GuiObject?,
	fit: GridFit?,
}

-- List.Content de la v2 : hauteur gardée en rapport largeur / hauteur (fitContent).
type ContentFit = {
	ratio: UIAspectRatioConstraint,
	layout: UIListLayout,
	gap: number, -- écart entre deux blocs, en largeurs de Content
	extra: number, -- marge en bas, en largeurs de Content
}

-- Écran branché.
type Shop = {
	gui: ScreenGui,
	icons: { [string]: string }, -- [IconAsset] = image, lues dans les cartes de la maquette
	connections: { RBXScriptConnection },
	cards: { Card },
	-- v2
	list: ScrollingFrame?,
	content: ContentFit?,
	sections: { Section },
	featured: GuiObject?,
	featuredCard: Card?,
	crate: GuiObject?,
	crateCards: { Card },
	state: string?, -- pack de départ et caisse montrés à la dernière construction
}

local SCREEN = "UI_RobuxShop_v2" -- vague 63 (L-200) ; a438 : le seul écran (l'ancien UI_RobuxShop est retiré)
local RETIRED_SCREEN = "UI_RobuxShop" -- a438 : ancien écran, plus lu ; s'il est encore livré, gardé éteint
local HUD = "UI_HUD"
local HUD_BUTTON = "RobuxShopButton"
local SHOP_TAG = "RobuxShop"
local PROMPT_NAME = "RobuxShopPrompt"
local CARD_PREFIX = "Offer_" -- nom des cartes clonées (jamais « Template »)
local ASSETS_FOLDER = "Assets" -- icônes de Clément (MOD-100), depuis ReplicatedStorage
local ICON_ASSET_ATTRIBUTE = "IconAsset" -- posé par Clément sur les Icon de la maquette
local CARD_COLOR_ATTRIBUTE = "CardColor" -- posé par Clément sur chaque carte de la v2 (L-204)
local COLUMNS_ATTRIBUTE = "Columns" -- posé par Clément sur chaque Grid de la v2 (L-204)

-- Onglets, dans l'ordre de l'écran (L-047).
local TABS: { { Tab: Tab, Path: string } } = {
	{ Tab = "Offers", Path = "Tabs.OffersTab" },
	{ Tab = "Gamepasses", Path = "Tabs.GamepassesTab" },
	{ Tab = "Cash", Path = "Tabs.CashTab" },
	{ Tab = "Boosts", Path = "Tabs.BoostsTab" },
}
local TAB_RANK: { [string]: number } = { Offers = 1, Gamepasses = 2, Cash = 3, Boosts = 4 }
-- Sections à cartes de la v2 (L-200), dans l'ordre de la liste.
local SECTIONS: { { Tab: Tab, Name: string } } = {
	{ Tab = "Gamepasses", Name = "GamepassesSection" },
	{ Tab = "Boosts", Name = "BoostsSection" },
	{ Tab = "Cash", Name = "CashSection" },
}

-- Attributs du Player posés par DisplayService et MonetizationService (mêmes noms là-bas).
local INCOME_ATTRIBUTE = "Income"
local PASS_ATTRIBUTE_PREFIX = "Pass"
local STARTER_ATTRIBUTE = "StarterPackEndsAt"
local OPEN_NOW_ATTRIBUTE = "OpenNowReadyAt"

-- V0 proposé, absent du doc : textes (en anglais, L-036) et portée de l'invite (comme les autres
-- comptoirs).
local ACTION_TEXT = "Shop"
local OBJECT_TEXT = "Robux Shop"
local PROMPT_DISTANCE = 10
local OPEN_NOW_TEXT = {
	Waiting = "%s (%s left)", -- effet, attente restante
	NoBox = "No item is waiting", -- vague 53 : l'antivol d'un objet posé (V0, anglais)
	AlmostReady = "Your item is almost unlocked",
	-- Vague 71 (a238), V0 proposé, absent du doc : écrits dans Price au clic sans palier à acheter.
	NoItemPrice = "No item",
	AlmostReadyPrice = "Almost ready",
}
local CASH_PACK_TEXT = "+%s · %s" -- montant, effet
-- Vague 63, V0 proposé, absent du doc (textes de la maquette de Clément, L-200) : minuteur du pack de départ,
-- lot de la caisse, chance d'une case, avantages du pack de départ.
local TIMER_TEXT = "Ends in %s"
-- Vague 73 (a253, L-243 a) : « Buy x1 », « Buy x3 », « Buy x10 » de la maquette de Clément.
local CRATE_COUNT_TEXT = { One = "Buy x%d", Many = "Buy x%d" }
-- Vague 73 (a253, L-242 point 3), V0 proposé, absent du doc : remise du pack de départ (Featured.DiscountTag).
local DISCOUNT_TEXT = "%d%% OFF"
-- Vague 73 (a253) : rayons qui tournent (Shop.RaysTurn) et caméra de la caisse 3D (Crate.Icon.Preview, L-247).
local RAYS_NAME = "Rays"
local FADE_NAME = "Fade"
local BACKDROP_NAME = "Backdrop" -- Crate.Backdrop.Rays : tournés par CrateLoop, pas ici
local TEMPLATE_NAME = "Template"
local PREVIEW_NAME = "Preview"
local REDUCED_CHECK = 0.5 -- s entre deux lectures du réglage « animations réduites »
local PERK_TEXT = { Boost = "×%d Cash %s", Hours = "%dh", Minutes = "%d min" }
-- V0 proposé, absent du doc : cadence (s) de la mise à jour des cartes, écran ouvert.
local REFRESH_INTERVAL = 1
-- V0 proposé, absent du doc (L-071) : texte écrit à la place du prix quand on clique sur une offre
-- qu'on ne peut pas encore acheter (vitrine, ou Id à 0), en anglais (L-036), et durée (s) de ce texte.
local SOON_TEXT = "Soon"
local SOON_DURATION = 2
-- Vague 72 (a247, L-229) : son d'un achat Robux réussi.
local BUY_SOUND = "Shop_Buy"

local IS_STUDIO = RunService:IsStudio()
-- Achats réels (MAJ 1) ; sinon, la vitrine (Features.RobuxShopPreview) : aucun appel à
-- MarketplaceService.
local LIVE = Features.RobuxShop
local ACTIVE = Features.RobuxShop or Features.RobuxShopPreview
-- a294 (L-276, Cantin 21/11) : caisse allumée = Monetization.Crate.Live (jeu DEV avec Features.RobuxCrateDev, ou
-- Features.RobuxCrate partout) ; ses lots se vendent même boutique coupée (vitrine), les autres offres restent « Soon ».
local CRATE_FEATURE = Monetization.Crate.Live == true
-- a500 (26/11, Cantin) : jeu TEST (Monetization.PurchasesDisabled, dit par le serveur de Config : Config/ProductIds) : la
-- boutique reste visible, chaque carte écrit TEST_TEXT dans son Price à la place du prix et un clic ne lance rien
-- (aucune fenêtre d'achat de Roblox, aucune lueur). Texte en anglais (L-036), demandé par Cantin.
local PURCHASES_OFF = Monetization.PurchasesDisabled == true
local TEST_TEXT = "Not available in test"

-- Achat réel permis pour cette offre : boutique ouverte, ou lot de la caisse allumée.
local function liveFor(offer: Offer): boolean
	return LIVE or (CRATE_FEATURE and offer.crate ~= nil)
end

local RobuxShopController = {}

local localPlayer = Players.LocalPlayer
local started = false -- Start est passé avec la boutique ou sa vitrine
local offers: { Offer } = {}
local crateOffers: { Offer } = {}
local shop: Shop? = nil
local isOpen = false
local prices: { [number]: number } = {} -- [Id Roblox] = prix lu chez Roblox
local fetching: { [number]: boolean } = {}
local prompts: { [Instance]: ProximityPrompt } = {}
local shopConnections: { [Instance]: { RBXScriptConnection } } = {}
local reported: { [string]: boolean } = {}
-- Règle Roblox des objets payants au hasard (caisse) : "unknown" tant que PolicyService n'a pas répondu.
local cratePolicy: "unknown" | "allowed" | "restricted" = "unknown"
local scrollTween: Tween? = nil
-- Vague 73 (a253) : rayons qui tournent écran allumé, et caméra de la caisse 3D qui se balance.
type Spin = { object: GuiObject, rotation: number, fade: UIGradient?, fadeRotation: number }
type Sway = { camera: Camera, base: CFrame, focus: Vector3 }
local spins: { Spin } = {}
local sway: Sway? = nil
-- a285 (21/11, L-247 c) : modèle 3D de la caisse (Crate.Icon.Preview), tagué CarryRainbow tant que la caisse se voit
-- (CarryController colore ses pièces Tint aux RainbowColors du Secret, comme un colis Secret porté).
local crateModel: Model? = nil
local CRATE_RAINBOW_TAG = "CarryRainbow"
local motionLoop: RBXScriptConnection? = nil
local motionStart = 0
local reducedAt = -math.huge
local reducedNow = false

-- Une ligne de sortie par sujet, en Studio seulement.
local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

-- Offres -----------------------------------------------------------------------------------------

local function buildOffers()
	table.clear(offers)
	for _, pass in Monetization.Passes do
		if pass.Ready then
			local offer: Offer = {
				key = pass.Key :: string,
				tab = "Gamepasses",
				order = pass.Order,
				displayName = pass.DisplayName,
				effect = pass.Effect,
				icon = pass.Icon,
				color = pass.CardColor,
				pass = pass :: Pass?,
				product = nil :: Product?,
				boost = nil :: ShopBoost?,
				crate = nil :: CratePack?,
			}
			table.insert(offers, offer)
		end
	end
	for _, product in Monetization.Products do
		if product.Ready then
			local offer: Offer = {
				key = product.Key :: string,
				tab = product.Tab,
				order = product.Order,
				displayName = product.DisplayName,
				effect = product.Effect,
				icon = product.Icon,
				color = product.CardColor,
				pass = nil :: Pass?,
				product = product :: Product?,
				boost = nil :: ShopBoost?,
				crate = nil :: CratePack?,
			}
			table.insert(offers, offer)
		end
	end
	-- Vague 63 : boosts du HUD, montrés même pas codés (« Soon » au clic, comme leur bouton du HUD).
	for _, boost in Monetization.ShopBoosts do
		local offer: Offer = {
			key = boost.Key,
			tab = "Boosts",
			order = boost.Order,
			displayName = boost.DisplayName,
			effect = boost.Effect,
			icon = boost.Icon,
			color = boost.CardColor,
			pass = nil :: Pass?,
			product = nil :: Product?,
			boost = boost :: ShopBoost?,
			crate = nil :: CratePack?,
		}
		table.insert(offers, offer)
	end
	table.sort(offers, function(a: Offer, b: Offer): boolean
		if a.tab ~= b.tab then
			return (TAB_RANK[a.tab] or 0) < (TAB_RANK[b.tab] or 0)
		end
		return a.order < b.order
	end)
	table.clear(crateOffers)
	for index, pack in Monetization.Crate.Packs do
		local offer: Offer = {
			key = `Crate{pack.Count}`,
			tab = "Crate",
			order = index,
			displayName = "",
			effect = "",
			icon = "",
			color = nil :: Color3?,
			pass = nil :: Pass?,
			product = nil :: Product?,
			boost = nil :: ShopBoost?,
			crate = pack :: CratePack?,
		}
		table.insert(crateOffers, offer)
	end
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function numberAttribute(name: string): number?
	local value = localPlayer:GetAttribute(name)
	return if type(value) == "number" and value == value then value else nil
end

local function starterOffered(): boolean
	local endsAt = numberAttribute(STARTER_ATTRIBUTE)
	return endsAt ~= nil and endsAt > serverNow()
end

-- Vague 63 : caisse montrée (interrupteur, chances décidées, règle Roblox du pays du joueur).
local function crateShown(): boolean
	return CRATE_FEATURE and #Monetization.Crate.Odds > 0 and cratePolicy == "allowed"
end

local function owns(offer: Offer): boolean
	return offer.pass ~= nil and localPlayer:GetAttribute(PASS_ATTRIBUTE_PREFIX .. offer.key) == true
end

-- Attente restante (s) du colis qui attend le plus, nil sans colis en attente.
local function openNowRemaining(): number?
	local readyAt = numberAttribute(OPEN_NOW_ATTRIBUTE)
	local remaining = if readyAt then readyAt - serverNow() else 0
	return if remaining > 0 then remaining else nil
end

local function duration(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Id Roblox à acheter et genre (gamepass ou produit), et prix de la Config ; Id 0 = pas créé, nil =
-- rien à acheter maintenant (Ouvrir maintenant sans colis).
local function purchaseOf(offer: Offer): (number?, boolean, number)
	local pass = offer.pass
	if pass then
		return pass.Id, true, pass.Price
	end
	local boost = offer.boost
	if boost then
		return boost.Boost.Id, false, boost.Boost.Price
	end
	local pack = offer.crate
	if pack then
		return pack.Id, false, pack.Price
	end
	local product = offer.product :: Product
	if product.Tiers then
		local remaining = openNowRemaining()
		local tier = if remaining then Monetization.OpenNowTier(remaining) else nil
		if tier == nil then
			return nil, false, product.Price
		end
		return tier.Id, false, tier.Price
	end
	return product.Id, false, product.Price
end

-- Effet pas encore codé (vague 63 : boost du HUD ou caisse) : « Soon » au clic, rien de vendu.
local function notReady(offer: Offer): boolean
	local boost = offer.boost
	if boost then
		return not boost.Boost.Ready
	end
	return offer.crate ~= nil and not Monetization.Crate.Ready
end

-- Vague 66 (a218, L-210 point 1) : offre pas encore en vente : effet pas codé, produit pas créé sur le Creator
-- Hub (Id à 0), ou Ouvrir maintenant dont aucun palier n'est créé. Sa carte montre « Soon » à la place du prix, en
-- permanence, bouton visible (au clic, rien), pour qu'on ne la croie pas en panne.
local function notForSale(offer: Offer, id: number?): boolean
	if id == 0 or notReady(offer) then
		return true
	end
	local product = offer.product
	local tiers = if product then product.Tiers else nil
	if tiers == nil then
		return false
	end
	for _, tier in tiers do
		if tier.Id ~= 0 then
			return false
		end
	end
	return true
end

-- a485 (brief L-351 point 5, Monetization.ExtraStands.Gate : Features.ExtraStandsGate) : la carte +4 Displays seulement si
-- le serveur a vu les présentoirs bonus utilisables dans la boutique du joueur (attribut ExtraStandsReady ; dans le
-- Floor_2 : une fois l'étage acheté, Cantin le 25/11), ou si le gamepass est déjà possédé (carte « Owned ») ; Gate
-- coupé : toujours, comme avant.
local function extraStandsShown(offer: Offer): boolean
	local gate = Monetization.ExtraStands
	if offer.key ~= "ExtraStands" or not gate.Gate then
		return true
	end
	return localPlayer:GetAttribute(gate.Attribute) == true or owns(offer)
end

local function offersOf(current: Tab): { Offer }
	local list: { Offer } = {}
	for _, offer in offers do
		if offer.tab == current and (offer.key ~= "StarterPack" or starterOffered()) and extraStandsShown(offer) then
			table.insert(list, offer)
		end
	end
	return list
end

local function starterOffer(): Offer?
	for _, offer in offers do
		if offer.key == "StarterPack" then
			return offer
		end
	end
	return nil
end

-- Écran ------------------------------------------------------------------------------------------

-- En capitales si le texte d'exemple de Clément l'est (« ×2 CASH »), sinon tel quel.
local function matchCase(sample: string, text: string): string
	if string.find(sample, "%a") ~= nil and sample == string.upper(sample) then
		return string.upper(text)
	end
	return text
end

-- Où écrire le texte d'un élément : lui-même s'il porte un texte (ou n'est pas un bouton), sinon son
-- premier TextLabel.
local function textHolder(element: Instance): Instance?
	if element:IsA("TextLabel") or element:IsA("TextBox") then
		return element
	end
	if element:IsA("TextButton") and (element :: TextButton).Text ~= "" then
		return element
	end
	return element:FindFirstChildWhichIsA("TextLabel", true)
end

local function setText(root: Instance, name: string, text: string)
	local element = Find.path(root, name)
	local holder = if element then textHolder(element) else nil
	if holder then
		local label = holder :: any
		local written = matchCase(label.Text, text)
		if label.Text ~= written then
			label.Text = written
		end
	end
end

local function guiObject(root: Instance, name: string): GuiObject?
	local found = Find.path(root, name)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
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

-- Image d'un Decal de Clément nommé `name` (ReplicatedStorage/Assets, sous-dossiers compris). Vague 65 (a216) :
-- tout Assets est lu en une seule passe à la première carte de l'écran branché (avant : une passe de tout Assets par
-- carte, à chaque ouverture), puis gardé jusqu'au prochain branchement (bind).
local decalTextures: { [string]: string }? = nil
local function decalTexture(name: string): string?
	local textures = decalTextures
	if textures == nil then
		local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
		if assets == nil then
			return nil
		end
		local read: { [string]: string } = {}
		for _, found in assets:GetDescendants() do
			if found:IsA("Decal") and read[found.Name] == nil and (found :: Decal).Texture ~= "" then
				read[found.Name] = (found :: Decal).Texture -- le premier, comme Find.all avant
			end
		end
		decalTextures = read
		textures = read
	end
	return (textures :: { [string]: string })[name]
end

-- Vague 63 (L-204) : ton `sample` d'une carte de couleur `base` (base éclaircie ou foncée), refait sur `color`.
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local function retone(sample: Color3, base: Color3, color: Color3): Color3
	local s = { sample.R, sample.G, sample.B }
	local b = { base.R, base.G, base.B }
	if s[1] + s[2] + s[3] >= b[1] + b[2] + b[3] then
		-- sample = base:Lerp(blanc, k) : k lu sur le canal qui a le plus de marge
		local room, k = 0, 0
		for i = 1, 3 do
			if 1 - b[i] > room then
				room = 1 - b[i]
				k = (s[i] - b[i]) / room
			end
		end
		return color:Lerp(WHITE, math.clamp(k, 0, 1))
	end
	-- sample = base:Lerp(noir, k)
	local most, k = 0, 0
	for i = 1, 3 do
		if b[i] > most then
			most = b[i]
			k = 1 - s[i] / most
		end
	end
	return color:Lerp(BLACK, math.clamp(k, 0, 1))
end

local function sameColor(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.02
end

-- Carte clonée repeinte à la couleur de son offre : seulement si Clément a posé CardColor sur le Template
-- (couleur de départ), et seulement les tons de la carte (ses UIGradient) et ses Studs, enfants directs.
local function paintCard(frame: GuiObject, color: Color3?)
	local base = frame:GetAttribute(CARD_COLOR_ATTRIBUTE)
	if color == nil or typeof(base) ~= "Color3" then
		return
	end
	local from = base :: Color3
	frame:SetAttribute(CARD_COLOR_ATTRIBUTE, color)
	if sameColor(from, color) then
		return
	end
	for _, child in frame:GetChildren() do
		if child:IsA("UIGradient") then
			local gradient = child :: UIGradient
			local keypoints = {}
			for _, keypoint in gradient.Color.Keypoints do
				table.insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, retone(keypoint.Value, from, color)))
			end
			gradient.Color = ColorSequence.new(keypoints)
		elseif child.Name == "Studs" and child:IsA("ImageLabel") and sameColor((child :: ImageLabel).ImageColor3, from) then
			(child :: ImageLabel).ImageColor3 = color
		end
	end
end

-- Prix Roblox d'un Id (cache), demandé une fois en tâche de fond ; la carte se met à jour à l'arrivée.
local refreshCards: () -> ()
local function robloxPrice(id: number, isPass: boolean): number?
	local known = prices[id]
	if known or fetching[id] then
		return known
	end
	fetching[id] = true
	task.spawn(function()
		local infoType = if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product
		local ok, info = pcall(function(): any
			return MarketplaceService:GetProductInfoAsync(id, infoType)
		end)
		local price = if ok and type(info) == "table" then info.PriceInRobux else nil
		if type(price) == "number" then
			prices[id] = price
			refreshCards()
		else
			reportOnce(`price:{id}`, `[RobuxShop] prix de {id} pas lu chez Roblox ({if ok then "pas de PriceInRobux" else tostring(info)}) : prix de la Config affiché`)
			task.delay(30, function()
				fetching[id] = nil -- nouvel essai à la prochaine mise à jour (V0 : 30 s)
			end)
		end
	end)
	return nil
end

local function effectOf(offer: Offer): string
	local product = offer.product
	if product == nil then
		return offer.effect
	end
	if product.Minutes then
		local amount = Monetization.CashPackAmount(numberAttribute(INCOME_ATTRIBUTE) or 0, product.Minutes)
		return string.format(CASH_PACK_TEXT, Format.money(amount), offer.effect)
	end
	if product.Tiers then
		local remaining = openNowRemaining()
		if remaining == nil then
			return OPEN_NOW_TEXT.NoBox
		end
		if Monetization.OpenNowTier(remaining) == nil then
			return OPEN_NOW_TEXT.AlmostReady
		end
		return string.format(OPEN_NOW_TEXT.Waiting, offer.effect, duration(remaining))
	end
	return offer.effect
end

-- Vague 63 : textes propres à la v2 (lot de la caisse, minuteur et avantages du pack de départ).
-- Vague 73 (a253, L-242 point 3) : `price` = prix affiché, pour l'ancien prix et la remise du pack de départ.
local function refreshExtras(card: Card, price: number)
	local offer = card.offer
	local pack = offer.crate
	if pack then
		setText(card.frame, "Count", string.format(if pack.Count == 1 then CRATE_COUNT_TEXT.One else CRATE_COUNT_TEXT.Many, pack.Count))
		local old = guiObject(card.frame, "OldPrice")
		local full = Monetization.Crate.UnitPrice * pack.Count
		local discounted = full > pack.Price
		local holder = if old and discounted then textHolder(old) else nil
		if holder and (holder :: any).Text ~= tostring(full) then
			(holder :: any).Text = tostring(full)
		end
		setVisible(old, discounted)
		return
	end
	if offer.key == "StarterPack" and not card.cloned then
		local endsAt = numberAttribute(STARTER_ATTRIBUTE)
		setText(card.frame, "Timer", string.format(TIMER_TEXT, duration(if endsAt then endsAt - serverNow() else 0)))
		local starter = Monetization.StarterPack
		local seconds = starter.BoostSeconds
		local length = if seconds % 3600 == 0
			then string.format(PERK_TEXT.Hours, seconds // 3600)
			else string.format(PERK_TEXT.Minutes, math.floor(seconds / 60))
		setText(card.frame, "Perk1", string.format(PERK_TEXT.Boost, Monetization.CashBoost.Multiplier, length))
		setText(card.frame, "Perk2", starter.Tool)
		setText(card.frame, "Perk3", Format.money(starter.Cash))
		-- Vague 73 (a253, L-242 point 3) : ancien prix et remise (Monetization.StarterPack.OldPrice) ; cachés sans remise.
		local oldPrice = starter.OldPrice
		local discounted = oldPrice ~= nil and oldPrice > price and price > 0
		if oldPrice ~= nil and discounted then
			setText(card.frame, "OldPrice", tostring(math.floor(oldPrice)))
			setText(card.frame, "DiscountTag.DiscountLabel", string.format(DISCOUNT_TEXT, math.floor((1 - price / oldPrice) * 100 + 0.5)))
		end
		setVisible(guiObject(card.frame, "OldPrice"), discounted)
		setVisible(guiObject(card.frame, "DiscountTag"), discounted)
	end
end

local function refreshCard(card: Card)
	local offer = card.offer
	local id, isPass, configPrice = purchaseOf(offer)
	-- Vitrine : jamais de lecture chez Roblox, le prix de la Config.
	local price = if liveFor(offer) and id and id ~= 0 then robloxPrice(id, isPass) or configPrice else configPrice
	if offer.displayName ~= "" then
		setText(card.frame, "ItemName", offer.displayName)
	end
	if card.cloned then
		-- Vague 73 (a253, L-243 b) : Effect de nouveau visible dans les cartes de la v2 (cartes clonées seulement :
		-- Featured et les boutons de la caisse gardent leurs textes).
		setText(card.frame, "Effect", effectOf(offer))
	end
	local soonUntil = card.soonUntil
	local unsold = notForSale(offer, id) -- vague 66 (a218) : « Soon » en permanence
	if PURCHASES_OFF then
		setText(card.frame, "Price", TEST_TEXT) -- a500 : jeu TEST, jamais de prix ni de « Soon »
	elseif unsold then
		setText(card.frame, "Price", SOON_TEXT)
	elseif soonUntil and os.clock() < soonUntil then
		setText(card.frame, "Price", card.soonText or SOON_TEXT)
	else
		card.soonUntil = nil
		card.soonText = nil
		setText(card.frame, "Price", tostring(math.floor(price)))
	end
	if card.buy ~= card.frame then
		local owned = owns(offer)
		-- Vague 71 (a238, L-213 point 1b) : Ouvrir maintenant garde son bouton sans objet à ouvrir (premier palier).
		local tiered = offer.product ~= nil and (offer.product :: Product).Tiers ~= nil
		setVisible(card.owned, owned)
		setVisible(card.buy, not owned and (id ~= nil or unsold or tiered))
	end
	refreshExtras(card, price)
end

local function clearCards(current: Shop)
	for _, card in current.cards do
		if card.cloned then
			card.frame:Destroy()
		end
	end
	table.clear(current.cards)
end

-- Pas d'achat possible (vitrine, Id à 0) : « Soon » à la place du prix, puis le prix de nouveau.
local function showSoon(card: Card, text: string?)
	card.soonUntil = os.clock() + SOON_DURATION
	card.soonText = text
	refreshCard(card)
	task.delay(SOON_DURATION, function()
		local current = shop
		if isOpen and current and table.find(current.cards, card) then
			refreshCard(card)
		end
	end)
end

-- Vague 63 (L-204 point 2) : lueur d'achat d'a209 (Controllers/UI/PurchaseGlow), si elle existe.
local function showPurchaseGlow()
	local ui = script.Parent:FindFirstChild("UI")
	local module = if ui then ui:FindFirstChild("PurchaseGlow") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return
	end
	local ok, glow = pcall(require :: any, module) -- module d'a209, peut-être absent : pas de require statique
	local show = if ok and type(glow) == "table" then (glow :: any).Show else nil
	if type(show) == "function" then
		local shown, err = pcall(show)
		if not shown and IS_STUDIO then
			warn(`[RobuxShop] PurchaseGlow.Show : {err}`)
		end
	end
end

local function buy(card: Card)
	local offer = card.offer
	if PURCHASES_OFF then
		reportOnce("test", `[RobuxShop] jeu TEST (Config/ProductIds.PurchasesDisabled) : pas d'achat, « {TEST_TEXT} »`)
		return
	end
	local id, isPass = purchaseOf(offer)
	local product = offer.product
	if id == nil and product and product.Tiers and not notForSale(offer, id) then
		-- Vague 71 (a238, L-213 point 1b) : Ouvrir maintenant sans palier à acheter : on dit pourquoi, rien de vendu.
		showSoon(card, if openNowRemaining() then OPEN_NOW_TEXT.AlmostReadyPrice else OPEN_NOW_TEXT.NoItemPrice)
		return
	end
	if id == nil or owns(offer) then
		return -- rien à acheter (Ouvrir maintenant sans colis, gamepass possédé) : bouton caché, clic tardif ignoré
	end
	if not liveFor(offer) then
		reportOnce("preview", `[RobuxShop] vitrine (Features.RobuxShop = false, RobuxShopPreview = true) : pas d'achat, « {SOON_TEXT} » à la place du prix`)
		showSoon(card)
		return
	end
	if notReady(offer) then
		reportOnce(`ready:{offer.key}`, `[RobuxShop] {offer.key} : effet pas encore codé côté serveur (Ready = false) : pas d'achat`)
		showSoon(card)
		return
	end
	if id == 0 then
		reportOnce(`id0:{offer.key}`, `[RobuxShop] {offer.key} : Id à 0 dans Config/Monetization (pas encore créé sur le Creator Hub) : pas d'achat`)
		showSoon(card)
		return
	end
	-- a485 (L-351, Cantin le 25/11) : +4 Displays avec Monetization.ExtraStands.Gate, fenêtre d'achat ouverte par le
	-- serveur, qui la refuse tant que l'étage de la boutique n'est pas acheté (MonetizationService, remote
	-- PromptExtraStands) ; lueur seulement si le serveur a dit oui à la carte (attribut), sinon elle resterait Timeout s.
	local viaServer = isPass and offer.key == "ExtraStands" and Monetization.ExtraStands.Gate
	if not viaServer or localPlayer:GetAttribute(Monetization.ExtraStands.Attribute) == true then
		showPurchaseGlow()
	end
	local ok, err = pcall(function()
		if viaServer then
			local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
			Net.Client.PromptExtraStands:Fire()
		elseif isPass then
			MarketplaceService:PromptGamePassPurchase(localPlayer, id)
		else
			MarketplaceService:PromptProductPurchase(localPlayer, id)
		end
	end)
	if not ok and IS_STUDIO then
		warn(`[RobuxShop] fenêtre d'achat de {offer.key} ({id}) : {err}`)
	end
end

-- Carte clonée depuis `template`, posée dans le parent du Template.
local function cloneCard(current: Shop, template: GuiObject, offer: Offer): Card
	local frame = template:Clone()
	frame.Name = CARD_PREFIX .. offer.key
	frame.LayoutOrder = offer.order
	frame.Visible = true
	paintCard(frame, offer.color)
	local image = decalTexture(offer.icon) or current.icons[offer.icon]
	local icon = Find.path(frame, "Icon")
	if image and icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
		(icon :: any).Image = image
	end
	-- Vague 71 (a238, L-213 point 1c) : le filigrane reprend l'image de l'Icon de l'offre (pas celle du Template).
	local watermark = Find.path(frame, "Clip.Watermark")
	if icon and watermark and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) and (watermark:IsA("ImageLabel") or watermark:IsA("ImageButton")) then
		(watermark :: any).Image = (icon :: any).Image
	end
	local card: Card = { offer = offer, frame = frame, buy = guiObject(frame, "BuyButton"), owned = guiObject(frame, "Owned"), soonUntil = nil, cloned = true }
	onClick(card.buy, function()
		buy(card)
	end)
	table.insert(current.cards, card)
	refreshCard(card)
	frame.Parent = template.Parent
	return card
end

-- v2 : hauteurs ---------------------------------------------------------------------------------

-- La Grid d'une section prend la hauteur de `count` cartes (rangées de `columns`), la section et ses enfants
-- gardent leurs hauteurs en pixels (seuls les Scale en Y et le rapport de la section changent).
local function fitGrid(fit: GridFit, count: number)
	local rows = math.max(1, math.ceil(count / fit.columns))
	local gridHeight = rows * fit.cell + (rows - 1) * fit.gap
	local height = fit.height - fit.gridHeight + gridHeight
	local k = fit.height / height
	for child, scale in fit.scales do
		local position, size = child.Position, child.Size
		child.Position = UDim2.new(position.X.Scale, position.X.Offset, scale.position * k, position.Y.Offset)
		child.Size = UDim2.new(size.X.Scale, size.X.Offset, scale.size * k, size.Y.Offset)
	end
	local gridSize = fit.grid.Size
	fit.grid.Size = UDim2.new(gridSize.X.Scale, gridSize.X.Offset, gridHeight / height, gridSize.Y.Offset)
	local cellSize, cellPadding = fit.layout.CellSize, fit.layout.CellPadding
	fit.layout.CellSize = UDim2.new(cellSize.X.Scale, cellSize.X.Offset, fit.cell / gridHeight, cellSize.Y.Offset)
	fit.layout.CellPadding = UDim2.new(cellPadding.X.Scale, cellPadding.X.Offset, fit.gap / gridHeight, cellPadding.Y.Offset)
	fit.ratio.AspectRatio = 1 / height
end

-- Hauteurs d'une section lues telles que Clément les a construites, ou nil (pas de rapport ou de UIGridLayout).
local function readGridFit(section: GuiObject, grid: GuiObject?): GridFit?
	local ratio = section:FindFirstChildOfClass("UIAspectRatioConstraint")
	local layout = if grid then grid:FindFirstChildOfClass("UIGridLayout") else nil
	if ratio == nil or layout == nil or grid == nil or ratio.AspectRatio <= 0 then
		return nil
	end
	local height = 1 / ratio.AspectRatio
	local gridHeight = grid.Size.Y.Scale * height
	local cell = layout.CellSize.Y.Scale * gridHeight
	if gridHeight <= 0 or cell <= 0 then
		return nil
	end
	local attribute = grid:GetAttribute(COLUMNS_ATTRIBUTE)
	local columns = if type(attribute) == "number" and attribute >= 1
		then math.floor(attribute)
		elseif layout.FillDirectionMaxCells > 0 then layout.FillDirectionMaxCells
		else math.max(1, math.floor(1 / math.max(layout.CellSize.X.Scale, 0.01)))
	local scales: { [GuiObject]: { position: number, size: number } } = {}
	for _, child in section:GetChildren() do
		if child:IsA("GuiObject") then
			local object = child :: GuiObject
			scales[object] = { position = object.Position.Y.Scale, size = object.Size.Y.Scale }
		end
	end
	return {
		ratio = ratio,
		grid = grid,
		layout = layout,
		height = height,
		gridHeight = gridHeight,
		cell = cell,
		gap = layout.CellPadding.Y.Scale * gridHeight,
		columns = columns,
		scales = scales,
	}
end

-- Blocs de List.Content (enfants qui gardent un rapport largeur / hauteur) et leur hauteur en largeurs.
local function blockHeights(content: Instance, visibleOnly: boolean): (number, number)
	local total, count = 0, 0
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") and (not visibleOnly or (child :: GuiObject).Visible) then
			local ratio = child:FindFirstChildOfClass("UIAspectRatioConstraint")
			if ratio and ratio.AspectRatio > 0 then
				total += (child :: GuiObject).Size.X.Scale / ratio.AspectRatio
				count += 1
			end
		end
	end
	return total, count
end

local function readContentFit(content: Instance?): ContentFit?
	if content == nil then
		return nil
	end
	local ratio = content:FindFirstChildOfClass("UIAspectRatioConstraint")
	local layout = content:FindFirstChildOfClass("UIListLayout")
	if ratio == nil or layout == nil or ratio.AspectRatio <= 0 then
		return nil
	end
	local total = 1 / ratio.AspectRatio
	local gap = layout.Padding.Scale * total
	local heights, count = blockHeights(content, true)
	return { ratio = ratio, layout = layout, gap = gap, extra = math.max(0, total - heights - gap * math.max(0, count - 1)) }
end

-- Vague 71 (a238, L-213 point 1a) : la hauteur à défiler de List suit celle de List.Content (plus le UIPadding de
-- List, en px) ; AutomaticCanvasSize ne suivait pas les hauteurs changées par fitGrid et fitContent. Seulement quand
-- Content garde son rapport largeur / hauteur (current.content) : sa hauteur ne dépend alors pas du canvas.
local function fitCanvas(current: Shop)
	local list = current.list
	local content = if list then list:FindFirstChild("Content") else nil
	if current.content == nil or list == nil or content == nil or not content:IsA("GuiObject") then
		return
	end
	local padding = list:FindFirstChildOfClass("UIPadding")
	local pad = if padding then padding.PaddingTop.Offset + padding.PaddingBottom.Offset else 0
	local height = math.ceil((content :: GuiObject).AbsoluteSize.Y + pad)
	if list.AutomaticCanvasSize ~= Enum.AutomaticSize.None then
		list.AutomaticCanvasSize = Enum.AutomaticSize.None
	end
	local canvas = list.CanvasSize
	local wanted = UDim2.new(canvas.X.Scale, canvas.X.Offset, 0, height)
	if canvas ~= wanted then
		list.CanvasSize = wanted
	end
end

-- List.Content reprend la hauteur de ses blocs visibles (sections cachées ou agrandies).
local function fitContent(current: Shop)
	local fit = current.content
	local list = current.list
	local content = if list then list:FindFirstChild("Content") else nil
	if fit == nil or content == nil then
		return
	end
	local heights, count = blockHeights(content, true)
	local total = heights + fit.gap * math.max(0, count - 1) + fit.extra
	if total > 0 then
		fit.ratio.AspectRatio = 1 / total
		fit.layout.Padding = UDim.new(fit.gap / total, 0)
	end
	fitCanvas(current)
end

-- v2 : défilement ----------------------------------------------------------------------------------

local function scrollTo(current: Shop, target: GuiObject?)
	local list = current.list
	if list == nil or target == nil then
		return
	end
	local y = target.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
	local bottom = math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y)
	local goal = Vector2.new(list.CanvasPosition.X, math.clamp(y, 0, bottom))
	local previous = scrollTween
	if previous then
		previous:Cancel()
		scrollTween = nil
	end
	local time = Monetization.Shop.ScrollTime
	if time <= 0 then
		list.CanvasPosition = goal
		return
	end
	local tween = game:GetService("TweenService"):Create(list, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CanvasPosition = goal })
	scrollTween = tween
	tween:Play()
end

-- Section d'un onglet de la v2 (OffersTab : la caisse, sinon le pack de départ, sinon les gamepasses).
local function sectionOf(current: Shop, chosen: Tab): GuiObject?
	if chosen == "Offers" then
		for _, candidate in { current.crate, current.featured } do
			if candidate and candidate.Visible then
				return candidate
			end
		end
		chosen = "Gamepasses"
	end
	for _, section in current.sections do
		if section.tab == chosen and section.frame.Visible then
			return section.frame
		end
	end
	return nil
end

-- Cartes ---------------------------------------------------------------------------------------

local function v2State(): string
	-- a485 : carte +4 Displays montrée ou non (extraStandsShown) : les cartes sont refaites quand elle change.
	local extra = "-"
	for _, offer in offers do
		if offer.key == "ExtraStands" and extraStandsShown(offer) then
			extra = "E"
		end
	end
	return (if starterOffered() then "S" else "-") .. (if crateShown() then "C" else "-") .. extra
end

-- v2 : toutes les sections à la fois, le pack de départ et la caisse.
local function buildV2(current: Shop)
	clearCards(current)
	for _, section in current.sections do
		local list = offersOf(section.tab)
		local template = section.template
		if template then
			for _, offer in list do
				cloneCard(current, template, offer)
			end
		end
		setVisible(section.frame, #list > 0 and template ~= nil)
		if section.fit then
			fitGrid(section.fit, #list)
		end
	end
	local featuredCard = current.featuredCard
	local showFeatured = featuredCard ~= nil and starterOffered()
	setVisible(current.featured, showFeatured)
	if featuredCard and showFeatured then
		table.insert(current.cards, featuredCard)
		refreshCard(featuredCard)
	end
	local showCrate = crateShown() and #current.crateCards > 0
	setVisible(current.crate, showCrate)
	if showCrate and current.crate then
		local odds = Monetization.Crate.Odds
		for index, chance in odds do
			local text = if chance == math.floor(chance) then string.format("%d%%", chance) else string.format("%.1f%%", chance)
			setText(current.crate, `Odd_{index}.Chance`, text)
		end
		for _, card in current.crateCards do
			table.insert(current.cards, card)
			refreshCard(card)
		end
	end
	current.state = v2State()
	fitContent(current)
end

-- Met à jour les cartes ; refait la liste si les offres de l'onglet ont changé (pack de départ).
refreshCards = function()
	local current = shop
	if current == nil or not isOpen then
		return
	end
	if current.state ~= v2State() then
		buildV2(current)
		return
	end
	for _, card in current.cards do
		refreshCard(card)
	end
end

-- Vague 73 (a253, L-242 point 3, L-243, L-247 point 1) : rayons et caisse 3D -------------------------------------

-- Réglage « animations réduites » d'Appear (Controllers/UI/Appear), lu sans require statique (absent : non).
local function reducedMotion(): boolean
	local ui = script.Parent:FindFirstChild("UI")
	local module = if ui then ui:FindFirstChild("Appear") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return false
	end
	local ok, appear = pcall(require :: any, module)
	local reduced = if ok and type(appear) == "table" then (appear :: any).Reduced else nil
	if type(reduced) ~= "function" then
		return false
	end
	local ran, value = pcall(reduced)
	return ran and value == true
end

-- Tout revient à la valeur de Clément : Rotation des rayons et de leur Fade, CFrame de la caméra de la caisse.
local function restoreMotion()
	for _, spin in spins do
		spin.object.Rotation = spin.rotation
		local fade = spin.fade
		if fade then
			fade.Rotation = spin.fadeRotation
		end
	end
	local current = sway
	if current then
		current.camera.CFrame = current.base
	end
end

-- `inst` est dans un Template (jamais tourné : ses copies prendraient la rotation du moment).
local function inTemplate(inst: Instance, gui: Instance): boolean
	local node: Instance? = inst
	while node ~= nil and node ~= gui do
		if node.Name == TEMPLATE_NAME then
			return true
		end
		node = node.Parent
	end
	return false
end

-- Rayons à faire tourner : tout Rays de l'écran, hors Template et hors Crate.Backdrop (CrateLoop).
local function collectSpins(current: Shop)
	restoreMotion()
	table.clear(spins)
	local crate = current.crate
	local backdrop = if crate then crate:FindFirstChild(BACKDROP_NAME) else nil
	for _, found in current.gui:GetDescendants() do
		local rotation = if found.Name == RAYS_NAME and found:IsA("GuiObject") then (found :: any).Rotation else nil
		if type(rotation) == "number" and not (backdrop and found:IsDescendantOf(backdrop)) and not inTemplate(found, current.gui) then
			local fade = found:FindFirstChild(FADE_NAME)
			local gradient = if fade and fade:IsA("UIGradient") and type((fade :: any).Rotation) == "number" then fade :: UIGradient else nil
			table.insert(spins, {
				object = found :: GuiObject,
				rotation = rotation,
				fade = gradient,
				fadeRotation = if gradient then gradient.Rotation else 0,
			})
		end
	end
end

local function stopMotion()
	local loop = motionLoop
	if loop then
		loop:Disconnect()
		motionLoop = nil
	end
	restoreMotion()
end

local function stepMotion()
	local current = shop
	if current == nil or current.gui.Parent == nil or not current.gui.Enabled then
		stopMotion() -- écran fermé (fin de l'animation de fermeture) ou retiré
		return
	end
	local now = os.clock()
	if now - reducedAt >= REDUCED_CHECK then
		reducedAt = now
		local was = reducedNow
		reducedNow = reducedMotion()
		if reducedNow and not was then
			restoreMotion()
		end
	end
	if reducedNow then
		return
	end
	local spec = Monetization.Shop
	local t = now - motionStart
	local turn = spec.RaysTurn * (t % spec.RaysPeriod) / spec.RaysPeriod
	local stale = false
	for _, spin in spins do
		if spin.object.Parent ~= nil then
			spin.object.Rotation = spin.rotation + turn
			local fade = spin.fade
			if fade then
				fade.Rotation = spin.fadeRotation - turn -- le fondu ne tourne pas avec les rayons (L-203 a)
			end
		else
			stale = true -- cartes refaites écran ouvert (buildV2) : rayons relus à l'image suivante
		end
	end
	if stale then
		collectSpins(current)
	end
	local swing = sway
	if swing then
		local angle = math.rad(spec.PreviewSway) * math.sin(2 * math.pi * t / spec.PreviewSwayPeriod)
		-- a278 (L-272, IconHover = Spring) : au survol de Crate, la caisse se tourne vers le pointeur (la caméra tourne
		-- autour d'elle dans l'autre sens) à la place du balancement, mélangés par le poids du ressort.
		local x, y, weight = 0, 0, 0
		local crate = current.crate
		if crate then
			x, y, weight = springOf(crate)
		end
		if weight ~= 0 then
			local yaw = angle + weight * (math.rad(-x) - angle)
			local pitch = weight * math.rad(y)
			swing.camera.CFrame = CFrame.new(swing.focus) * CFrame.Angles(0, yaw, 0)
				* CFrame.fromAxisAngle(swing.base.RightVector, pitch) * CFrame.new(-swing.focus) * swing.base
		else
			swing.camera.CFrame = CFrame.new(swing.focus) * CFrame.Angles(0, angle, 0) * CFrame.new(-swing.focus) * swing.base
		end
	end
end

-- Écran ouvert : rayons relus (cartes refaites) et boucle lancée si elle ne tourne pas.
local function startMotion(current: Shop)
	collectSpins(current)
	if motionLoop ~= nil then
		return
	end
	local heartbeat = (RunService :: any).Heartbeat
	if heartbeat == nil then
		return -- faux Roblox des bancs
	end
	motionStart = os.clock()
	reducedAt = -math.huge
	reducedNow = false
	motionLoop = heartbeat:Connect(stepMotion)
end

-- L-247 a : le lien CurrentCamera de chaque ViewportFrame Preview est perdu à la copie dans le PlayerGui ; on le remet
-- sur sa Camera. Celle de la caisse (Crate.Icon.Preview) se balance autour du pivot de son modèle (L-247 b).
-- a285 (21/11) : la caisse 3D sans Camera (L-252, L-260 d : pas encore livrée par Clément) : une Camera créée ici dans
-- la copie du joueur, face avant de la caisse (−Z, L-252), à une distance qui la montre en entier ; une ligne en Studio.
local function fallbackCamera(viewport: ViewportFrame, model: Model): Camera
	local center, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.FieldOfView = 40 -- V0 proposé le 2026-11-21 (a285), absent du doc
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.1
	local focus = center.Position
	-- LookVector = −Z du cadre de la caisse : sa face avant, la caméra se met devant et la regarde.
	local eye = focus + center.LookVector * distance + Vector3.new(0, size.Y * 0.15, 0)
	camera.CFrame = CFrame.lookAt(eye, focus)
	camera.Parent = viewport
	reportOnce("previewCamera", `[RobuxShop] {viewport:GetFullName()} sans Camera (L-260 d) : caméra de repli face à la caisse`)
	return camera
end

local function bindPreviews(current: Shop)
	sway = nil
	crateModel = nil
	for _, found in current.gui:GetDescendants() do
		if found.Name == PREVIEW_NAME and found:IsA("ViewportFrame") then
			local viewport = found :: ViewportFrame
			local camera = viewport:FindFirstChildOfClass("Camera")
			local crate = current.crate
			local inCrate = crate ~= nil and viewport:IsDescendantOf(crate)
			local crateBox = if inCrate then viewport:FindFirstChildWhichIsA("Model", true) else nil
			if crateBox and crateModel == nil then
				crateModel = crateBox
			end
			if camera == nil and crateBox then
				camera = fallbackCamera(viewport, crateBox)
			end
			if camera then
				if viewport.CurrentCamera ~= camera then
					viewport.CurrentCamera = camera
				end
				if sway == nil and crateBox then
					sway = { camera = camera, base = camera.CFrame, focus = crateBox:GetPivot().Position }
				end
			end
		end
	end
end

-- a285 (L-247 c) : arc-en-ciel du Tint de la caisse 3D tant que la boutique est ouverte et la caisse montrée.
local function setCrateRainbow(on: boolean)
	local model = crateModel
	if model == nil or model.Parent == nil then
		return
	end
	pcall(function() -- pcall : faux CollectionService des bancs
		local tagged = CollectionService:HasTag(model, CRATE_RAINBOW_TAG)
		if on and not tagged then
			CollectionService:AddTag(model, CRATE_RAINBOW_TAG)
		elseif not on and tagged then
			CollectionService:RemoveTag(model, CRATE_RAINBOW_TAG)
		end
	end)
end

local function closeShop()
	isOpen = false
	setCrateRainbow(false)
	local current = shop
	if current then
		-- Vague 65 (a216) : cartes gardées écran fermé (avant : retirées puis toutes reclonées à chaque ouverture) ;
		-- l'ouverture les met à jour, ou les refait si les offres ont changé (refreshCards).
		Motion.Close(current.gui)
	end
end

local function setTab(chosen: Tab)
	local current = shop
	if current and isOpen then
		scrollTo(current, sectionOf(current, chosen))
	end
end

-- Images des Icon de la maquette (Template et cartes Preview_*), par leur attribut IconAsset.
local function readIcons(list: Instance): { [string]: string }
	local icons: { [string]: string } = {}
	for _, descendant in list:GetDescendants() do
		if descendant.Name == "Icon" and (descendant:IsA("ImageLabel") or descendant:IsA("ImageButton")) then
			local asset = descendant:GetAttribute(ICON_ASSET_ATTRIBUTE)
			local image = (descendant :: any).Image
			if type(asset) == "string" and type(image) == "string" and image ~= "" and icons[asset] == nil then
				icons[asset] = image
			end
		end
	end
	return icons
end

-- Cartes d'exemple de la maquette de Clément (Preview_*, à côté du Template) : retirées de la copie du
-- joueur, seules les cartes du code restent (comme L-041).
local function removePreviews(parent: Instance)
	for _, sibling in parent:GetChildren() do
		if string.sub(sibling.Name, 1, 8) == "Preview_" then
			sibling:Destroy()
		end
	end
end

-- v2 (L-200) : sections, pack de départ et caisse.
local function bindV2(current: Shop, keep: (RBXScriptConnection?) -> ())
	local gui = current.gui
	local list = Find.path(gui, "List")
	current.list = if list and list:IsA("ScrollingFrame") then list :: ScrollingFrame else nil
	if current.list == nil then
		reportOnce("v2list", `[RobuxShop] {SCREEN}.List introuvable ou pas un ScrollingFrame : pas de défilement`)
	end
	for _, entry in SECTIONS do
		local frame = guiObject(gui, entry.Name)
		if frame == nil then
			reportOnce(`v2:{entry.Name}`, `[RobuxShop] {SCREEN}.{entry.Name} introuvable : ses offres ne sont pas montrées`)
		else
			local grid = guiObject(frame, "Grid")
			local template = if grid then guiObject(grid, "Template") else nil
			if grid then
				removePreviews(grid)
			end
			local fit = readGridFit(frame, grid)
			table.insert(current.sections, { tab = entry.Tab, frame = frame, grid = grid, template = template, fit = fit })
		end
	end
	local featured = guiObject(gui, "Featured")
	current.featured = featured
	local starter = starterOffer()
	if featured and starter then
		local button = guiObject(featured, "BuyButton")
		local card: Card = { offer = starter, frame = featured, buy = button, owned = nil, soonUntil = nil, cloned = false }
		current.featuredCard = card
		keep(onClick(button, function()
			buy(card)
		end))
	end
	local crate = guiObject(gui, "Crate")
	current.crate = crate
	if crate then
		for index, offer in crateOffers do
			local button = guiObject(crate, `BuyButton{index}`)
			if button then
				local card: Card = { offer = offer, frame = button, buy = button, owned = nil, soonUntil = nil, cloned = false }
				table.insert(current.crateCards, card)
				keep(onClick(button, function()
					buy(card)
				end))
			end
		end
	end
	-- Hauteur de List.Content lue avec tous les blocs de la maquette visibles, puis caisse et pack de départ
	-- cachés jusqu'à l'ouverture (buildV2).
	local content = if current.list then (current.list :: ScrollingFrame):FindFirstChild("Content") else nil
	current.content = readContentFit(content)
	if content and content:IsA("GuiObject") then
		-- Vague 71 (a238, L-213 point 1a) : le canvas suit Content (fitContent, largeur de l'écran, barre de défilement).
		keep((content :: GuiObject):GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if shop == current then
				fitCanvas(current)
			end
		end))
	end
	setVisible(crate, false)
	setVisible(featured, false)
	bindPreviews(current) -- vague 73 (a253, L-247 a et b)
end

local function bind(gui: ScreenGui)
	local old = shop
	stopMotion() -- vague 73 : rayons et caméra de l'ancien écran remis en place
	table.clear(spins)
	sway = nil
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
		clearCards(old)
	end
	isOpen = false
	decalTextures = nil -- vague 65 (a216) : images relues pour ce nouvel écran
	gui.Enabled = false -- fermé jusqu'au bouton du HUD ou à l'invite
	Motion.SetCloser(gui, closeShop) -- un autre écran du groupe ScreenGroup s'ouvre (L-089)

	local current: Shop = {
		gui = gui,
		icons = readIcons(gui),
		connections = {},
		cards = {},
		list = nil,
		content = nil,
		sections = {},
		featured = nil,
		featuredCard = nil,
		crate = nil,
		crateCards = {},
		state = nil,
	}
	shop = current
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	bindV2(current, keep)
	keep(onClick(Find.path(gui, "CloseButton"), closeShop))
	for _, entry in TABS do
		local chosen = entry.Tab
		keep(onClick(Find.path(gui, entry.Path), function()
			setTab(chosen)
		end))
	end
end

-- Écran à brancher dans PlayerGui : UI_RobuxShop_v2 (a438 : le seul).
local function findScreen(playerGui: Instance): ScreenGui?
	local gui = playerGui:FindFirstChild(SCREEN)
	return if gui and gui:IsA("ScreenGui") then gui :: ScreenGui else nil
end

-- Écran branché encore présent, ou celui de PlayerGui
-- (branché au passage), ou nil.
local function currentShop(): Shop?
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local wanted = if playerGui then findScreen(playerGui) else nil
	local current = shop
	if current and current.gui.Parent ~= nil and (wanted == nil or current.gui == wanted) then
		return current
	end
	if wanted then
		bind(wanted)
		return shop
	end
	return nil
end

local function openShop()
	local current = currentShop()
	if current == nil then
		reportOnce("screen", `[RobuxShop] écran {SCREEN} absent de PlayerGui : la boutique ne s'ouvre pas`)
		return
	end
	isOpen = true
	refreshCards() -- vague 65 (a216) : cartes gardées mises à jour ; refaites seulement si les offres ont changé
	local list = current.list
	if list then
		local previous = scrollTween
		if previous then
			previous:Cancel()
			scrollTween = nil
		end
		list.CanvasPosition = Vector2.new(0, 0) -- la liste s'ouvre en haut (caisse ou pack de départ)
	end
	Motion.Open(current.gui)
	startMotion(current) -- vague 73 (a253) : rayons qui tournent, caméra de la caisse 3D
	setCrateRainbow(crateShown()) -- a285 (L-247 c)
end

local function toggleShop()
	if isOpen then
		closeShop()
	else
		openShop()
	end
end

function RobuxShopController.Open(_anchor: Instance?)
	if started and not isOpen then
		openShop()
	end
end

-- Vague 66 (a223, L-210 point 7) : le joueur sort de la plaque ShopPad du comptoir : l'écran se ferme s'il est ouvert.
function RobuxShopController.Leave(_anchor: Instance?)
	if isOpen then
		closeShop()
	end
end

-- Règle Roblox de la caisse (vague 63) -------------------------------------------------------------

-- PolicyService : objets payants au hasard permis pour ce joueur ? Lu une fois, seulement avec la caisse
-- allumée ; une erreur la garde cachée.
local function readCratePolicy()
	if not CRATE_FEATURE then
		return
	end
	task.spawn(function()
		local ok, info = pcall(function(): any
			return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(localPlayer)
		end)
		if ok and type(info) == "table" and type(info.ArePaidRandomItemsRestricted) == "boolean" then
			cratePolicy = if info.ArePaidRandomItemsRestricted then "restricted" else "allowed"
		else
			cratePolicy = "restricted"
			reportOnce("policy", `[RobuxShop] PolicyService pas lu ({if ok then "réponse inattendue" else tostring(info)}) : caisse cachée`)
		end
		refreshCards()
	end)
end

-- Bouton du HUD --------------------------------------------------------------------------------

local hudBound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function bindHud(gui: Instance)
	if hudBound[gui] then
		return
	end
	-- Chaque exemplaire du bouton (L-099 point 1 : UI_HUD.LeftRail sur PC et UI_HUD.LeftRailTouch sur
	-- téléphone ont les mêmes boutons) ouvre et ferme la boutique.
	local bound = 0
	for _, found in Find.all(gui, HUD_BUTTON) do
		if found:IsA("GuiButton") then
			Motion.Activated(found :: GuiButton):Connect(toggleShop)
			bound += 1
		end
	end
	if bound == 0 then
		reportOnce("hud", `[RobuxShop] {HUD}.{HUD_BUTTON} introuvable ou pas un bouton : la boutique ne s'ouvre que par le comptoir`)
		return
	end
	hudBound[gui] = true
end

-- Comptoir -------------------------------------------------------------------------------------

local function promptPart(counter: Instance): BasePart?
	if counter:IsA("BasePart") then
		return counter :: BasePart
	end
	if counter:IsA("Model") then
		local primary = (counter :: Model).PrimaryPart
		if primary and primary:IsDescendantOf(counter) then
			return primary
		end
	end
	return counter:FindFirstChildWhichIsA("BasePart", true)
end

-- Pose l'invite si elle manque (comptoir tout juste chargé, ou pièce de l'invite sortie du streaming).
local function ensurePrompt(counter: Instance)
	local existing = prompts[counter]
	if existing then
		if existing:IsDescendantOf(counter) then
			return
		end
		existing:Destroy()
		prompts[counter] = nil
	end
	local part = promptPart(counter)
	if part == nil then
		return -- pas encore chargé : DescendantAdded rappellera
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = ACTION_TEXT
	prompt.ObjectText = OBJECT_TEXT
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(openShop)
	prompt.Parent = part
	prompts[counter] = prompt
end

local function addCounter(counter: Instance)
	if shopConnections[counter] or not counter:IsDescendantOf(Workspace) then
		return
	end
	shopConnections[counter] = {
		counter.DescendantAdded:Connect(function(descendant: Instance)
			if descendant:IsA("BasePart") then
				ensurePrompt(counter)
			end
		end),
		counter.DescendantRemoving:Connect(function(descendant: Instance)
			local prompt = prompts[counter]
			if prompt and prompt.Parent == descendant then
				task.defer(ensurePrompt, counter)
			end
		end),
	}
	ensurePrompt(counter)
end

local function removeCounter(counter: Instance)
	local connections = shopConnections[counter]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		shopConnections[counter] = nil
	end
	local prompt = prompts[counter]
	if prompt then
		prompt:Destroy()
		prompts[counter] = nil
	end
end

function RobuxShopController.Start()
	if not ACTIVE then
		return -- ni boutique (MAJ 1) ni vitrine : rien n'est branché, l'écran reste fermé
	end
	started = true
	buildOffers()
	readCratePolicy()
	if LIVE or CRATE_FEATURE then -- a294 : aussi pour un lot de la caisse allumée, boutique coupée
		-- Vague 72 (a247) : Shop_Buy à la fin d'un achat fait (pcall : signaux absents d'un faux Roblox de banc).
		pcall(function()
			MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _productId: number, isPurchased: boolean)
				if isPurchased and userId == localPlayer.UserId then
					Motion.PlaySound(BUY_SOUND)
				end
			end)
			MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, _passId: number, wasPurchased: boolean)
				if wasPurchased and player == localPlayer then
					Motion.PlaySound(BUY_SOUND)
				end
			end)
		end)
	end

	local watched = { INCOME_ATTRIBUTE, STARTER_ATTRIBUTE, OPEN_NOW_ATTRIBUTE, Monetization.ExtraStands.Attribute } -- a485
	for _, pass in Monetization.Passes do
		table.insert(watched, PASS_ATTRIBUTE_PREFIX .. pass.Key)
	end
	for _, attribute in watched do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(function()
			refreshCards()
		end)
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if not child:IsA("ScreenGui") then
			return
		end
		if child.Name == SCREEN then
			bind(child :: ScreenGui)
		elseif child.Name == RETIRED_SCREEN then
			(child :: ScreenGui).Enabled = false -- a438 : l'ancien écran reste éteint
		elseif child.Name == HUD then
			bindHud(child)
		end
	end)
	local existing = findScreen(playerGui)
	if existing then
		bind(existing)
	end
	local retired = playerGui:FindFirstChild(RETIRED_SCREEN)
	if retired and retired:IsA("ScreenGui") then
		(retired :: ScreenGui).Enabled = false -- a438 : l'ancien écran reste éteint
	end
	local hud = playerGui:FindFirstChild(HUD)
	if hud and hud:IsA("ScreenGui") then
		bindHud(hud)
	end

	CollectionService:GetInstanceAddedSignal(SHOP_TAG):Connect(addCounter)
	CollectionService:GetInstanceRemovedSignal(SHOP_TAG):Connect(removeCounter)
	for _, counter in CollectionService:GetTagged(SHOP_TAG) do
		addCounter(counter)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < REFRESH_INTERVAL then
			return
		end
		elapsed = 0
		if isOpen then
			local current = shop
			if current == nil or current.gui.Parent == nil then
				closeShop()
			else
				refreshCards()
			end
		end
	end)
end

return RobuxShopController
