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
--   - prix d'un objet : math.floor(Pawn.PriceFactor × $/s), $/s = Formulas.ItemIncome(zone, rareté) ×
--     Mutations.IncomeMultiplier (même règle que l'inventaire et DisplayService ; zone : celle du catalogue,
--     sinon celle de l'objet, sinon 1), sans les bonus du joueur.
--
-- Remotes (Net/Definitions, vague 29, absents du tableau 9.4) :
--   PawnAsk()                  → PawnOffer(heldUid, heldItemId, heldPrice, allCount, allPrice)
--   PawnSellHeld(itemUid)      itemUid doit être encore l'objet tenu ; vendu → PawnSold(prix, 1), puis PawnOffer
--   PawnSellAll(count)         count doit être encore le nombre d'objets vendables ; tous vendus →
--                              PawnSold(total, count), puis PawnOffer
-- Chaque remote vérifie : profil chargé, personnage à Pawn.Reach studs au plus de la plaque ShopPad d'un stand
-- taggé PawnShop (sinon de son pivot ; stands rangés dans _INBOX_CLEMENT ou _SHOWROOM_CLEMENT ignorés). Loin du
-- stand ou profil pas chargé : ignoré (une ligne en Studio). Vente refusée parce que l'offre a changé :
-- PawnSold(0, 0) puis la nouvelle PawnOffer.
-- Vente : chaque objet est retiré de Items du profil, puis l'argent est versé par DataService.AddCash, dans la
-- même exécution, sans yield (pas de vente en double). Puis InventoryService.Refresh (écran et barre du bas).
--
-- API (côté serveur) :
--   PawnShopService.GetOffer(player) -> Offer?    l'offre du moment (nil : profil pas chargé) ; bancs d'essai
--   PawnShopService.PriceOf(player, itemUid) -> number?   prix de rachat d'un objet du joueur, nil s'il n'en a pas

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Config.Formulas)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Pawn = require(Shared.Config.Pawn)
local Zones = require(Shared.Config.Zones)
local Find = require(Shared.Contract.Find)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

type Data = ProfileTypes.Data

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
local IGNORED_FOLDERS = { "_INBOX_CLEMENT", "_SHOWROOM_CLEMENT" } -- livraisons, vitrine de Clément : pas en jeu
local ROOT_PART = "HumanoidRootPart"

local IS_STUDIO = RunService:IsStudio()

local PawnShopService = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[PawnShopService] {message}`)
	end
end

------------------------------------------------------------------------------
-- Lieu
------------------------------------------------------------------------------

local function inGame(inst: Instance): boolean
	if not inst:IsDescendantOf(Workspace) then
		return false
	end
	for _, name in IGNORED_FOLDERS do
		local folder = Workspace:FindFirstChild(name)
		if folder and inst:IsDescendantOf(folder) then
			return false
		end
	end
	return true
end

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

local function validZone(value: any): number?
	if type(value) == "number" and value % 1 == 0 and Zones[value] ~= nil then
		return value
	end
	return nil
end

-- Prix de rachat d'un objet du profil (nil : objet inconnu).
local function priceOfEntry(entry: any): number?
	local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
	if def == nil then
		return nil
	end
	local zone = def.Zone or validZone(entry.Zone) or 1
	local income = Formulas.ItemIncome(zone, def.Rarity) * Mutations.IncomeMultiplier(entry.Mutation)
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
local function sell(player: Player, data: Data, uids: { string }): number
	local total = 0
	for _, uid in uids do
		local price = priceOfEntry(data.Items[uid])
		if price then
			data.Items[uid] = nil
			total += price
		end
	end
	if total > 0 then
		DataService.AddCash(player, total)
	end
	InventoryService.Refresh(player)
	return total
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

function PawnShopService.Init()
	Net.Server.PawnAsk:Connect(onAsk)
	Net.Server.PawnSellHeld:Connect(onSellHeld)
	Net.Server.PawnSellAll:Connect(onSellAll)
end

return PawnShopService
