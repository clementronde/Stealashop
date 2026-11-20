--!strict
-- Prize/Grant (vague 80, a266 ; serveur) : donne un lot de Config/Wheel.Prize (argent en minutes de revenus, objet
-- d'un colis, boost ×2 argent, potion). Partagé par QuestService et WheelService. Module d'aide, dans un sous-dossier
-- de Services : le Loader ne le charge pas comme un service.
--
-- Mêmes règles que les récompenses (RewardService, Config/Rewards) :
--   Cash    minutes × 60 × revenu par seconde du joueur (DisplayService.GetIncome × GetGlobalMultiplier, bonus
--           compris), au moins Rewards.MinCashPerMinute $ par minute ; DataService.AddCash ;
--   Box     UnboxService.GiveItem : objet tiré comme le contenu d'un colis Tier, zone = la plus haute parmi les objets
--           du joueur (zone 1 sans objet), au moins MinZone ; inventaire plein : refusé (« InventoryFull ») ;
--   Boost   MonetizationService.AddCashBoost ;
--   Potion  PotionService.AddStock ; stock plein : refusé (« PotionFull »).
--
-- API :
--   Grant.Give(player, prize) -> (ok, message, cashAmount, reason)
--       Sans yield. ok = false : rien n'est donné ; reason = "InventoryFull", "PotionFull" ou "Unavailable".
--       cashAmount = l'argent versé (0 pour un autre lot), pour la télémétrie.
--   Grant.CashAmount(player, minutes) -> number      « X min de revenus » au moment de l'appel
--   Grant.IsGranting(player) -> boolean
--       true pendant le versement d'un lot d'argent (DataService.OnCashChanged appelle ses écouteurs pendant AddCash) :
--       QuestService ne compte pas ces lots dans la quête « gagner de l'argent ».

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Potions = require(Shared.Config.Potions)
local Rarities = require(Shared.Config.Rarities)
local Rewards = require(Shared.Config.Rewards)
local Wheel = require(Shared.Config.Wheel)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)

local Services = script.Parent.Parent
local DataService = require(Services.DataService)
local DisplayService = require(Services.DisplayService)
local MonetizationService = require(Services.MonetizationService)
local PotionService = require(Services.PotionService)
local UnboxService = require(Services.UnboxService)

type Prize = Wheel.Prize

local MESSAGES = Rewards.Messages

local Grant = {}

local granting: { [Player]: boolean } = {}

local function finite(value: any): number
	return if type(value) == "number" and value == value and math.abs(value) < math.huge then value else 0
end

-- Zone des objets offerts : la plus haute parmi les objets du joueur, zone 1 sans objet (comme RewardService).
local function bestZone(data: any): number
	local best = 1
	local items = data.Items
	if type(items) ~= "table" then
		return best
	end
	for _, entry in items do
		local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
		if def then
			local zone = def.Zone or entry.Zone
			if type(zone) == "number" and Zones[zone] ~= nil and zone > best then
				best = zone
			end
		end
	end
	return best
end

function Grant.CashAmount(player: Player, minutes: number): number
	local income = finite(DisplayService.GetIncome(player)) * finite(DisplayService.GetGlobalMultiplier(player))
	return math.floor(math.max(math.max(income, 0) * 60 * minutes, Rewards.MinCashPerMinute * minutes))
end

function Grant.IsGranting(player: Player): boolean
	return granting[player] == true
end

function Grant.Give(player: Player, prize: Prize): (boolean, string, number, string?)
	local data = DataService.Get(player)
	if data == nil then
		return false, MESSAGES.Unavailable, 0, "Unavailable"
	end
	local kind = prize.Kind
	if kind == "Cash" then
		local amount = Grant.CashAmount(player, prize.Minutes or 0)
		granting[player] = true
		local ok, result = pcall(DataService.AddCash, player, amount)
		granting[player] = nil
		if not ok or result == nil then
			return false, MESSAGES.Unavailable, 0, "Unavailable"
		end
		return true, string.format(MESSAGES.Cash, Format.money(amount)), amount, nil
	elseif kind == "Box" then
		local tier = prize.Tier or "Standard"
		local zone = math.max(bestZone(data), prize.MinZone or 1)
		local itemUid, reason, itemId = UnboxService.GiveItem(player, tier, zone, prize.MinRarity)
		if itemUid == nil then
			if reason == "InventoryFull" then
				return false, MESSAGES.ItemsFull, 0, "InventoryFull"
			end
			return false, MESSAGES.Unavailable, 0, "Unavailable"
		end
		local items = (data :: any).Items
		local entry = if type(items) == "table" then items[itemUid] else nil
		local def = if itemId then Items.ById[itemId] else nil
		local rarity = if def then Rarities.ById[def.Rarity] else nil
		local name = if def then Mutations.ItemName(def.DisplayName, if entry then entry.Mutation else nil) else tostring(itemId)
		return true, string.format(MESSAGES.Item, if rarity then rarity.DisplayName else "", name), 0, nil
	elseif kind == "Boost" then
		local minutes = prize.Minutes or 0
		if not MonetizationService.AddCashBoost(player, minutes * 60) then
			return false, MESSAGES.Unavailable, 0, "Unavailable"
		end
		return true, string.format(MESSAGES.Boost, minutes), 0, nil
	elseif kind == "Potion" then
		local id = prize.Potion or ""
		local count = math.max(1, math.floor(prize.Count or 1))
		local def = Potions.ById[id]
		if def == nil then
			return false, MESSAGES.Unavailable, 0, "Unavailable"
		end
		if not PotionService.AddStock(player, id, count) then
			return false, MESSAGES.Unavailable, 0, "PotionFull"
		end
		return true, string.format(Wheel.Messages.Potion, count, def.DisplayName), 0, nil
	end
	return false, MESSAGES.Unavailable, 0, "Unavailable"
end

return Grant
