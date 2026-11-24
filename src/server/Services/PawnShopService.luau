--!strict
-- PawnShopService (DEV-034 ; liaison L-106 point 4, L-107 point 2 ; note docs/claude/notes/ui-pawnshop.md) : le
-- receleur du hub rachète les objets du joueur (Partie 1, 5.8 : « 120 × son $/s » ; 5.9). Valeurs : Config/Pawn.
--
-- Serveur autoritaire : le client ne choisit ni le prix ni les objets d'une vente « tout vendre » ; il dit
-- seulement ce qu'il a vu et confirmé (l'uid de l'objet tenu, le nombre d'objets), et le serveur refuse si ce
-- n'est plus vrai.
--
-- Ce qui se vend : les objets de l'inventaire tels que les montre l'écran d'inventaire (InventoryService : objet
-- connu du catalogue, pas au coffre-fort, déjà révélé), sans les objets exposés, revérifiés dans le profil.
-- Jamais un colis (pas encore ouvert) ni ce qui est porté au-dessus de la tête (colis PNJ, objet volé en cours
-- de vol : ils ne sont pas dans Items du joueur, ou sont exposés chez la victime).
--   - objet « tenu en main » : seulement l'objet dans la main (Clément, L-117 point 1). Depuis L-079, un objet
--     ne se tient jamais en main (un clic sur sa case le pose) : il n'y en a donc aucun, PawnOffer l'envoie
--     vide, le vendeur répond Lines.NothingHeld et PawnSellHeld est toujours refusé ; « tout vendre » reste ;
--   - prix d'un objet : math.floor(Pawn.PriceFactor × $/s), $/s = Formulas.ItemIncome(objet) ×
--     Mutations.IncomeMultiplier (même règle que l'inventaire et DisplayService ; vague 76 : rareté, zone et
--     rang de l'objet), sans les bonus du joueur.
--
-- Remotes (Net/Definitions, vague 29, absents du tableau 9.4) :
--   PawnAsk()                  → PawnOffer(heldUid, heldItemId, heldPrice, allCount, allPrice)
--   PawnSellHeld(itemUid)      itemUid doit être encore l'objet tenu ; vendu → PawnSold(prix, 1), puis PawnOffer
--   PawnSellAll(count)         count doit être encore le nombre d'objets vendables ; tous vendus →
--                              PawnSold(total, count), puis PawnOffer
-- Chaque remote vérifie : profil chargé, personnage à Pawn.Reach studs au plus de la plaque ShopPad d'un stand
-- taggé PawnShop (sinon de son pivot ; stands rangés dans un dossier de travail en « _ » ignorés, Find.inMap).
-- Loin du stand ou profil pas chargé : ignoré (une ligne en Studio). Vente refusée parce que l'offre a changé :
-- PawnSold(0, 0) puis la nouvelle PawnOffer.
-- Vente : chaque objet est retiré de Items du profil, puis l'argent est versé par DataService.AddCash, dans la
-- même exécution, sans yield (pas de vente en double). Puis InventoryService.Refresh (écran et barre du bas).
--
--
-- a314 (L-292, L-271 : bouton SellButton d'une ligne de UI_Displayed, confirmation YES / NO ; DisplayedController) :
-- vente d'UN objet depuis l'écran Display, au même prix et par la même vente qu'au comptoir (priceOfEntry, sell),
-- SANS la règle de distance (on vend depuis l'écran), avec toutes les autres :
--   - objet de la réserve ou de l'inventaire : il doit être vendable au comptoir (sellableUids : à lui, connu du
--     catalogue, révélé, ni au coffre-fort, ni posé au sol sous antivol). Un objet sous antivol PAS encore posé
--     (« PLACE ») est vendable au comptoir, donc ici aussi (V0 : la règle du receleur) ;
--   - objet exposé (Display) : il est d'abord retiré de son présentoir (DisplayService.Unplace, dans la même
--     exécution) ; refusé s'il est tenu par un voleur (vol en cours).
-- Remotes (Net/Definitions, absents du tableau 9.4) :
--   DisplayedSellAsk(itemUid)  → DisplayedSellPrice(itemUid, prix, vendable)   prix montré dans Confirm.SellPrice
--   DisplayedSell(itemUid)     → DisplayedSold(itemUid, argent versé, vendu)    le prix est recalculé ici ; refus :
--                                vendu = false, rien ne change (Notify « Warning » si le joueur doit savoir pourquoi)
-- Pas de vente en double : l'objet quitte Items et l'argent est versé dans la même exécution, sans yield ; une
-- seconde demande ne trouve plus l'objet (refusée, sans message).
--
-- API (côté serveur) :
--   PawnShopService.GetOffer(player) -> Offer?    l'offre du moment (nil : profil pas chargé) ; bancs d'essai
--   PawnShopService.PriceOf(player, itemUid) -> number?   prix de rachat d'un objet du joueur, nil s'il n'en a pas
--   PawnShopService.SellPrice(player, itemUid) -> (number?, string?)   a314 : prix de vente depuis l'écran Display,
--       ou nil et la raison du refus ("NoProfile", "NotOwned", "Unknown", "Held", "NotSellable")
--   PawnShopService.SellOne(player, itemUid) -> (number?, string?)     a314 : vend l'objet (argent versé), mêmes refus

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features) -- a414 : Analytics (ventes comptées)
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Pawn = require(Shared.Config.Pawn)
local Find = require(Shared.Contract.Find)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

type Data = ProfileTypes.Data

-- a314 : ce que la vente depuis l'écran Display utilise de DisplayService (chargé au premier appel : DisplayService
-- charge InventoryService, et les bancs d'essai du receleur n'ont pas toujours DisplayService).
type DisplayApi = {
	Unplace: (player: Player, itemUid: string) -> number?,
	IsHeld: (player: Player, itemUid: string) -> boolean,
}

export type Offer = {
	HeldUid: string?,
	HeldItemId: string?,
	HeldPrice: number,
	AllUids: { string },
	AllPrice: number,
}

-- Contrat (2.1 et 10.4, Contract/Tags et Contract/Models).
local PAWN_TAG = "PawnShop"
local PAD_NAME = "ShopPad"
local ROOT_PART = "HumanoidRootPart"

local IS_STUDIO = RunService:IsStudio()

-- a314 : messages de la vente depuis l'écran Display (anglais, L-036). Held reprend celui d'InventoryService ;
-- NotSellable et Sold : V0 proposés, absents du doc.
local SELL_MESSAGES = {
	Held = "This item is being stolen: hit the thief to get it back!",
	NotSellable = "This item can't be sold right now.",
	Sold = "%s sold for %s!", -- nom de l'objet, prix (Format.money)
}

local PawnShopService = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[PawnShopService] {message}`)
	end
end

------------------------------------------------------------------------------
-- Lieu
------------------------------------------------------------------------------

-- a436 : règle commune « dans la map jouée » (hors des dossiers de travail en « _ »).
local inGame = Find.inMap

-- Point du stand : sa plaque ShopPad, sinon son pivot (Model) ou sa position (pièce).
local function standPoint(stand: Instance): Vector3?
	local pad = Find.path(stand, PAD_NAME)
	if pad and pad:IsA("BasePart") then
		return (pad :: BasePart).Position
	end
	if stand:IsA("Model") then
		return (stand :: Model):GetPivot().Position
	end
	if stand:IsA("BasePart") then
		return (stand :: BasePart).Position
	end
	return nil
end

local function isNearStand(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild(ROOT_PART) else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local position = (root :: BasePart).Position
	for _, stand in CollectionService:GetTagged(PAWN_TAG) do
		if inGame(stand) then
			local point = standPoint(stand)
			if point and (position - point).Magnitude <= Pawn.Reach then
				return true
			end
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Prix et offre
------------------------------------------------------------------------------

-- Prix de rachat d'un objet du profil (nil : objet inconnu).
local function priceOfEntry(entry: any): number?
	local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
	if def == nil then
		return nil
	end
	local income = Formulas.ItemIncome(def.Id) -- vague 76 : rareté, zone et rang de l'objet
		* Mutations.IncomeMultiplier(entry.Mutation, entry.Weight) -- vague 62 : poids compris
	local price = math.floor(Pawn.PriceFactor * income)
	if price ~= price or price < 0 or price == math.huge then
		return nil
	end
	return price
end

-- Uid des objets vendables : ceux de l'inventaire montrés à l'écran (InventoryService), sans présentoir,
-- revérifiés dans le profil (à lui, ni exposé, ni au coffre-fort).
local function sellableUids(player: Player, data: Data): { string }
	InventoryService.Refresh(player) -- état à jour, tout de suite
	local displayed: { [string]: boolean } = {}
	for _, uid in data.Display do
		displayed[uid] = true
	end
	for _, uid in data.Vault do
		displayed[uid] = true
	end
	local list: { string } = {}
	for _, entry in InventoryService.GetState(player).Items do
		local uid = entry.Uid
		if entry.Slot == nil and not displayed[uid] and priceOfEntry(data.Items[uid]) ~= nil then
			table.insert(list, uid)
		end
	end
	return list
end

local function computeOffer(player: Player, data: Data): Offer
	local uids = sellableUids(player, data)
	local total = 0
	for _, uid in uids do
		total += priceOfEntry(data.Items[uid]) or 0
	end
	-- Aucun objet en main dans ce jeu (L-117 point 1) : rien à vendre « tenu ».
	return {
		HeldUid = nil,
		HeldItemId = nil,
		HeldPrice = 0,
		AllUids = uids,
		AllPrice = total,
	}
end

local function sendOffer(player: Player, offer: Offer)
	Net.Server.PawnOffer:Fire(player, offer.HeldUid or "", offer.HeldItemId or "", offer.HeldPrice, #offer.AllUids, offer.AllPrice)
end

-- Retire les objets du profil et verse leur prix. Sans yield. Renvoie le total versé.
-- a414 (vague GC7, Features.Analytics) : vente comptée juste après AddCash, gain Fence (SKU = rareté de l'objet, Bulk
-- si plusieurs) et événement ItemSold (valeur = objets vendus). require protégé au premier usage : TelemetryService
-- n'est pas chargé par tous les bancs du receleur.
local function logSale(player: Player, total: number, count: number, rarity: string?)
	if not Features.Analytics then
		return
	end
	local module = script.Parent:FindFirstChild("TelemetryService")
	local ok, telemetry = pcall(require, module :: any)
	if not ok or type(telemetry) ~= "table" then
		return
	end
	local sku = if count == 1 and rarity then rarity else "Bulk"
	pcall((telemetry :: any).LogEconomy, player, "Fence", total, sku, { `Items - {count}` })
	pcall((telemetry :: any).LogEvent, player, "ItemSold", { `Rarity - {sku}`, `Items - {count}` }, count)
end

local function sell(player: Player, data: Data, uids: { string }): number
	local total = 0
	local count = 0
	local rarity: string? = nil
	for _, uid in uids do
		local entry = data.Items[uid]
		local price = priceOfEntry(entry)
		if price then
			local def = Items.ById[(entry :: any).Id]
			rarity = if def then def.Rarity else nil
			data.Items[uid] = nil
			total += price
			count += 1
		end
	end
	if total > 0 then
		if DataService.AddCash(player, total) ~= nil then
			logSale(player, total, count, rarity)
		end
	end
	InventoryService.Refresh(player)
	return total
end

------------------------------------------------------------------------------
-- a314 : vente d'un objet depuis l'écran Display (sans la règle de distance)
------------------------------------------------------------------------------

local displayApi: DisplayApi? = nil
local function displayService(): DisplayApi?
	if displayApi == nil then
		local module = script.Parent:FindFirstChild("DisplayService")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok and type(result) == "table" then
				displayApi = result :: any
			end
		end
	end
	return displayApi
end

local function isExposed(data: Data, uid: string): boolean
	for _, stored in data.Display do
		if stored == uid then
			return true
		end
	end
	return false
end

-- Objet exposé montré dans l'état de l'inventaire (révélé, connu du catalogue, pas au coffre-fort). Après Refresh.
local function shownExposed(player: Player, uid: string): boolean
	for _, entry in InventoryService.GetState(player).Items do
		if entry.Uid == uid then
			return entry.Slot ~= nil
		end
	end
	return false
end

-- Prix de vente de l'objet `uid` et s'il est exposé, ou nil et la raison du refus. Sans yield.
local function checkOne(player: Player, data: Data, uid: string): (number?, boolean, string?)
	local entry = data.Items[uid]
	if entry == nil then
		return nil, false, "NotOwned"
	end
	local price = priceOfEntry(entry)
	if price == nil then
		return nil, false, "Unknown"
	end
	if table.find(sellableUids(player, data), uid) ~= nil then -- règles du comptoir (Refresh compris)
		return price, false, nil
	end
	if isExposed(data, uid) and shownExposed(player, uid) then
		local display = displayService()
		if display == nil or display.IsHeld(player, uid) then
			return nil, true, "Held"
		end
		return price, true, nil
	end
	return nil, false, "NotSellable"
end

-- Vend l'objet : retiré de son présentoir s'il est exposé, puis de Items, argent versé. Sans yield.
local function sellOne(player: Player, data: Data, uid: string): (number?, string?)
	local price, exposed, reason = checkOne(player, data, uid)
	if price == nil then
		return nil, reason
	end
	if exposed then
		local display = displayService()
		if display == nil or display.Unplace(player, uid) == nil then
			return nil, "Held"
		end
	end
	return sell(player, data, { uid }), nil
end

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[PawnShopService] Notify vers {player.Name} : {err}`)
	end
end

local function onDisplayedAsk(player: Player, itemUid: string)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local price, _, reason = checkOne(player, data, itemUid)
	if price == nil then
		log(`{player.Name} : DisplayedSellAsk({itemUid}) refusé ({reason})`)
	end
	Net.Server.DisplayedSellPrice:Fire(player, itemUid, price or 0, price ~= nil)
end

local function onDisplayedSell(player: Player, itemUid: string)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local entry = data.Items[itemUid]
	local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
	local amount, reason = sellOne(player, data, itemUid)
	if amount == nil then
		log(`{player.Name} : DisplayedSell({itemUid}) refusé ({reason})`)
		Net.Server.DisplayedSold:Fire(player, itemUid, 0, false)
		-- Rien à dire pour un objet qui n'est plus à lui (seconde demande d'un double clic, envoi malhonnête).
		if reason == "Held" then
			notify(player, SELL_MESSAGES.Held, "Warning")
		elseif reason ~= "NotOwned" then
			notify(player, SELL_MESSAGES.NotSellable, "Warning")
		end
		return
	end
	log(`{player.Name} a vendu {if def then def.Id else "?"} ({itemUid}) depuis l'écran Display pour ${amount}`)
	Net.Server.DisplayedSold:Fire(player, itemUid, amount, true)
	notify(player, string.format(SELL_MESSAGES.Sold, if def then def.DisplayName else "Item", Format.money(amount)), "Success")
end

------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------

-- Profil chargé et joueur au stand, sinon nil (une ligne en Studio).
local function checked(player: Player, what: string): Data?
	local data = DataService.Get(player)
	if data == nil then
		return nil
	end
	if not isNearStand(player) then
		log(`{player.Name} : {what} ignoré, loin du receleur`)
		return nil
	end
	return data
end

local function onAsk(player: Player)
	local data = checked(player, "PawnAsk")
	if data then
		sendOffer(player, computeOffer(player, data))
	end
end

local function onSellHeld(player: Player, itemUid: string)
	local data = checked(player, "PawnSellHeld")
	if data == nil then
		return
	end
	local offer = computeOffer(player, data)
	if offer.HeldUid == nil or offer.HeldUid ~= itemUid then
		log(`{player.Name} : PawnSellHeld({itemUid}) refusé, l'objet tenu est {offer.HeldUid or "aucun"}`)
		Net.Server.PawnSold:Fire(player, 0, 0)
		sendOffer(player, offer)
		return
	end
	local amount = sell(player, data, { itemUid })
	log(`{player.Name} a vendu {offer.HeldItemId} ({itemUid}) au receleur pour ${amount}`)
	Net.Server.PawnSold:Fire(player, amount, 1)
	sendOffer(player, computeOffer(player, data))
end

local function onSellAll(player: Player, count: number)
	local data = checked(player, "PawnSellAll")
	if data == nil then
		return
	end
	local offer = computeOffer(player, data)
	if #offer.AllUids == 0 or #offer.AllUids ~= count then
		log(`{player.Name} : PawnSellAll({count}) refusé, {#offer.AllUids} objet(s) vendable(s)`)
		Net.Server.PawnSold:Fire(player, 0, 0)
		sendOffer(player, offer)
		return
	end
	local amount = sell(player, data, offer.AllUids)
	log(`{player.Name} a vendu {count} objet(s) au receleur pour ${amount}`)
	Net.Server.PawnSold:Fire(player, amount, count)
	sendOffer(player, computeOffer(player, data))
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function PawnShopService.GetOffer(player: Player): Offer?
	local data = DataService.Get(player)
	return if data then computeOffer(player, data) else nil
end

function PawnShopService.PriceOf(player: Player, itemUid: string): number?
	local data = DataService.Get(player)
	return if data then priceOfEntry(data.Items[itemUid]) else nil
end

function PawnShopService.SellPrice(player: Player, itemUid: string): (number?, string?)
	local data = DataService.Get(player)
	if data == nil then
		return nil, "NoProfile"
	end
	local price, _, reason = checkOne(player, data, itemUid)
	return price, reason
end

function PawnShopService.SellOne(player: Player, itemUid: string): (number?, string?)
	local data = DataService.Get(player)
	if data == nil then
		return nil, "NoProfile"
	end
	return sellOne(player, data, itemUid)
end

function PawnShopService.Init()
	Net.Server.PawnAsk:Connect(onAsk)
	Net.Server.PawnSellHeld:Connect(onSellHeld)
	Net.Server.PawnSellAll:Connect(onSellAll)
	-- a314 : vente depuis l'écran Display.
	Net.Server.DisplayedSellAsk:Connect(onDisplayedAsk)
	Net.Server.DisplayedSell:Connect(onDisplayedSell)
end

return PawnShopService
