--!strict
-- RobuxShopController (DEV-100, client) : boutique Robux, écran UI_RobuxShop de Clément (UI-100, noms
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
--                  dans la sortie en Studio. Caché pour Ouvrir maintenant sans colis à ouvrir ;
--       Owned      gamepass possédé (attribut Pass<Clé> du Player, posé par MonetizationService) :
--                  Owned visible et BuyButton caché (la coche verte et le bouton gris de la maquette).
--     Les cartes suivent les attributs du Player (Pass…, StarterPackEndsAt, OpenNowReadyAt, Income) et
--     se mettent à jour chaque seconde tant que l'écran est ouvert ;
--   - les cartes d'exemple de la maquette (Preview_*, à côté du Template) sont retirées de la copie du
--     joueur, comme dans les boutiques d'armes et d'auras.
-- Ouverture et fermeture animées (DEV-052) par UI/Motion, comme les boutiques d'armes et d'auras : les
-- cartes sont retirées une fois l'écran éteint, et une réouverture pendant la fermeture la rattrape.
-- Seuls sont touchés : Enabled de l'écran, les textes, la visibilité, le nom et l'ordre des cartes
-- clonées, l'image de Icon (2.2, « Libre pour Ironix ») ; jamais un style (l'effet d'échelle de Motion
-- est passager). Texte d'un élément : sur lui
-- s'il en porte un, sinon dans son premier TextLabel ; en capitales si le texte d'exemple l'est
-- (« ×2 CASH »). Le serveur décide tout (MonetizationService) : le client n'envoie rien, il ouvre la
-- fenêtre d'achat de Roblox et affiche.
--
-- API (client) :
--   RobuxShopController.Open(anchor?)
--       Ouvre l'écran, comme le bouton du HUD (sans effet s'il est déjà ouvert, ou si la boutique et
--       sa vitrine sont coupées). `anchor` est ignoré : la boutique Robux ne se ferme pas quand on
--       s'éloigne. Appelé par ShopPadController (plaque ShopPad du comptoir, L-071).

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

-- Onglet (Monetization.Tab), en texte : l'ancien solveur élargit ses valeurs d'un module à l'autre.
type Tab = string
type Pass = Monetization.Pass
type Product = Monetization.Product

-- Une offre de l'écran : un gamepass ou un produit développeur.
type Offer = {
	key: string,
	tab: Tab,
	order: number,
	displayName: string,
	effect: string,
	icon: string,
	pass: Pass?,
	product: Product?,
}

-- Une carte clonée.
type Card = {
	offer: Offer,
	frame: GuiObject,
	buy: GuiObject?,
	owned: GuiObject?,
	soonUntil: number?, -- os.clock() jusqu'où Price montre SOON_TEXT (clic sans achat possible)
}

-- Écran branché.
type Shop = {
	gui: ScreenGui,
	template: GuiObject?,
	icons: { [string]: string }, -- [IconAsset] = image, lues dans les cartes de la maquette
	connections: { RBXScriptConnection },
	cards: { Card },
}

local SCREEN = "UI_RobuxShop"
local HUD = "UI_HUD"
local HUD_BUTTON = "RobuxShopButton"
local SHOP_TAG = "RobuxShop"
local PROMPT_NAME = "RobuxShopPrompt"
local CARD_PREFIX = "Offer_" -- nom des cartes clonées (jamais « Template »)
local ASSETS_FOLDER = "Assets" -- icônes de Clément (MOD-100), depuis ReplicatedStorage
local ICON_ASSET_ATTRIBUTE = "IconAsset" -- posé par Clément sur les Icon de la maquette

-- Onglets, dans l'ordre de l'écran (L-047).
local TABS: { { Tab: Tab, Path: string } } = {
	{ Tab = "Offers", Path = "Tabs.OffersTab" },
	{ Tab = "Gamepasses", Path = "Tabs.GamepassesTab" },
	{ Tab = "Cash", Path = "Tabs.CashTab" },
	{ Tab = "Boosts", Path = "Tabs.BoostsTab" },
}
local TAB_RANK: { [string]: number } = { Offers = 1, Gamepasses = 2, Cash = 3, Boosts = 4 }

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
	NoBox = "No box is waiting",
	AlmostReady = "Your box is almost ready",
}
local CASH_PACK_TEXT = "+%s · %s" -- montant, effet
-- V0 proposé, absent du doc : cadence (s) de la mise à jour des cartes, écran ouvert.
local REFRESH_INTERVAL = 1
-- V0 proposé, absent du doc (L-071) : texte écrit à la place du prix quand on clique sur une offre
-- qu'on ne peut pas encore acheter (vitrine, ou Id à 0), en anglais (L-036), et durée (s) de ce texte.
local SOON_TEXT = "Soon"
local SOON_DURATION = 2

local IS_STUDIO = RunService:IsStudio()
-- Achats réels (MAJ 1) ; sinon, la vitrine (Features.RobuxShopPreview) : aucun appel à
-- MarketplaceService.
local LIVE = Features.RobuxShop
local ACTIVE = Features.RobuxShop or Features.RobuxShopPreview

local RobuxShopController = {}

local localPlayer = Players.LocalPlayer
local started = false -- Start est passé avec la boutique ou sa vitrine
local offers: { Offer } = {}
local shop: Shop? = nil
local isOpen = false
local chosenTab: Tab? = nil -- dernier onglet choisi par le joueur
local tab: Tab = "Gamepasses"
local prices: { [number]: number } = {} -- [Id Roblox] = prix lu chez Roblox
local fetching: { [number]: boolean } = {}
local prompts: { [Instance]: ProximityPrompt } = {}
local shopConnections: { [Instance]: { RBXScriptConnection } } = {}
local reported: { [string]: boolean } = {}

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
				pass = pass :: Pass?,
				product = nil :: Product?,
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
				pass = nil :: Pass?,
				product = product :: Product?,
			}
			table.insert(offers, offer)
		end
	end
	table.sort(offers, function(a: Offer, b: Offer): boolean
		if a.tab ~= b.tab then
			return (TAB_RANK[a.tab] or 0) < (TAB_RANK[b.tab] or 0)
		end
		return a.order < b.order
	end)
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

local function offersOf(current: Tab): { Offer }
	local list: { Offer } = {}
	for _, offer in offers do
		if offer.tab == current and (offer.key ~= "StarterPack" or starterOffered()) then
			table.insert(list, offer)
		end
	end
	return list
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

-- Image d'un Decal de Clément nommé `name` (ReplicatedStorage/Assets, sous-dossiers compris).
local function decalTexture(name: string): string?
	local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
	if assets == nil then
		return nil
	end
	for _, found in Find.all(assets, name) do
		if found:IsA("Decal") and (found :: Decal).Texture ~= "" then
			return (found :: Decal).Texture
		end
	end
	return nil
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

local function refreshCard(card: Card)
	local offer = card.offer
	local id, isPass, configPrice = purchaseOf(offer)
	-- Vitrine : jamais de lecture chez Roblox, le prix de la Config.
	local price = if LIVE and id and id ~= 0 then robloxPrice(id, isPass) or configPrice else configPrice
	setText(card.frame, "ItemName", offer.displayName)
	setText(card.frame, "Effect", effectOf(offer))
	local soonUntil = card.soonUntil
	if soonUntil and os.clock() < soonUntil then
		setText(card.frame, "Price", SOON_TEXT)
	else
		card.soonUntil = nil
		setText(card.frame, "Price", tostring(math.floor(price)))
	end
	local owned = owns(offer)
	setVisible(card.owned, owned)
	setVisible(card.buy, not owned and id ~= nil)
end

local function clearCards(current: Shop)
	for _, card in current.cards do
		card.frame:Destroy()
	end
	table.clear(current.cards)
end

-- Pas d'achat possible (vitrine, Id à 0) : « Soon » à la place du prix, puis le prix de nouveau.
local function showSoon(card: Card)
	card.soonUntil = os.clock() + SOON_DURATION
	refreshCard(card)
	task.delay(SOON_DURATION, function()
		local current = shop
		if isOpen and current and table.find(current.cards, card) then
			refreshCard(card)
		end
	end)
end

local function buy(card: Card)
	local offer = card.offer
	local id, isPass = purchaseOf(offer)
	if id == nil or owns(offer) then
		return -- rien à acheter (Ouvrir maintenant sans colis, gamepass possédé) : bouton caché, clic tardif ignoré
	end
	if not LIVE then
		reportOnce("preview", `[RobuxShop] vitrine (Features.RobuxShop = false, RobuxShopPreview = true) : pas d'achat, « {SOON_TEXT} » à la place du prix`)
		showSoon(card)
		return
	end
	if id == 0 then
		reportOnce(`id0:{offer.key}`, `[RobuxShop] {offer.key} : Id à 0 dans Config/Monetization (pas encore créé sur le Creator Hub) : pas d'achat`)
		showSoon(card)
		return
	end
	local ok, err = pcall(function()
		if isPass then
			MarketplaceService:PromptGamePassPurchase(localPlayer, id)
		else
			MarketplaceService:PromptProductPurchase(localPlayer, id)
		end
	end)
	if not ok and IS_STUDIO then
		warn(`[RobuxShop] fenêtre d'achat de {offer.key} ({id}) : {err}`)
	end
end

-- Cartes de l'onglet ouvert, clonées depuis List.Template.
local function buildCards()
	local current = shop
	if current == nil then
		return
	end
	clearCards(current)
	local template = current.template
	if template == nil then
		return
	end
	for _, offer in offersOf(tab) do
		local frame = template:Clone()
		frame.Name = CARD_PREFIX .. offer.key
		frame.LayoutOrder = offer.order
		frame.Visible = true
		local image = decalTexture(offer.icon) or current.icons[offer.icon]
		local icon = Find.path(frame, "Icon")
		if image and icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
			(icon :: any).Image = image
		end
		local card: Card = { offer = offer, frame = frame, buy = guiObject(frame, "BuyButton"), owned = guiObject(frame, "Owned"), soonUntil = nil }
		onClick(card.buy, function()
			buy(card)
		end)
		table.insert(current.cards, card)
		refreshCard(card)
		frame.Parent = template.Parent
	end
end

-- Met à jour les cartes ; refait la liste si les offres de l'onglet ont changé (pack de départ).
refreshCards = function()
	local current = shop
	if current == nil or not isOpen then
		return
	end
	local wanted = offersOf(tab)
	local same = #wanted == #current.cards
	for index, offer in wanted do
		if not same or current.cards[index].offer ~= offer then
			same = false
			break
		end
	end
	if not same then
		buildCards()
		return
	end
	for _, card in current.cards do
		refreshCard(card)
	end
end

local function closeShop()
	isOpen = false
	local current = shop
	if current then
		-- Cartes retirées une fois l'écran éteint ; une réouverture d'ici là les reconstruit.
		Motion.Close(current.gui, function()
			clearCards(current)
		end)
	end
end

local function setTab(chosen: Tab)
	chosenTab = chosen
	tab = chosen
	if isOpen then
		buildCards()
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

local function bind(gui: ScreenGui)
	local old = shop
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
		clearCards(old)
	end
	isOpen = false
	gui.Enabled = false -- fermé jusqu'au bouton du HUD ou à l'invite
	Motion.SetCloser(gui, closeShop) -- un autre écran du groupe ScreenGroup s'ouvre (L-089)

	local template = guiObject(gui, "List.Template")
	local icons: { [string]: string } = {}
	if template == nil then
		reportOnce("template", `[RobuxShop] {SCREEN}.List.Template introuvable : la boutique restera vide`)
	else
		local list = template.Parent :: Instance
		icons = readIcons(list)
		-- Cartes d'exemple de la maquette de Clément (Preview_*, à côté du Template) : retirées de la
		-- copie du joueur, seules les cartes du code restent (comme L-041).
		for _, sibling in list:GetChildren() do
			if string.sub(sibling.Name, 1, 8) == "Preview_" then
				sibling:Destroy()
			end
		end
	end
	local current: Shop = { gui = gui, template = template, icons = icons, connections = {}, cards = {} }
	shop = current
	local function keep(connection: RBXScriptConnection?)
		if connection then
			table.insert(current.connections, connection)
		end
	end
	keep(onClick(Find.path(gui, "CloseButton"), closeShop))
	for _, entry in TABS do
		local chosen = entry.Tab
		keep(onClick(Find.path(gui, entry.Path), function()
			setTab(chosen)
		end))
	end
end

-- Écran branché encore présent, ou celui de PlayerGui (branché au passage), ou nil.
local function currentShop(): Shop?
	local current = shop
	if current and current.gui.Parent ~= nil then
		return current
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild(SCREEN) else nil
	if gui and gui:IsA("ScreenGui") then
		bind(gui :: ScreenGui)
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
	tab = chosenTab or (if starterOffered() then "Offers" else "Gamepasses")
	isOpen = true
	buildCards()
	Motion.Open(current.gui)
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
			(found :: GuiButton).Activated:Connect(toggleShop)
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

	local watched = { INCOME_ATTRIBUTE, STARTER_ATTRIBUTE, OPEN_NOW_ATTRIBUTE }
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
