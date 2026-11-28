--!strict
-- SecuredTier (a521, 28/11 ; liaison L-405) : le palier de la carte « ITEM SECURED! » et le coup de chance. Commun au
-- serveur (UnboxService : coup de chance, 4e argument d'ItemSecured ; CrossServerAnnounce) et au client
-- (Controllers/Escape/SecuredCard). Réglages : Config/SecuredCard.Tier et Lucky ; derrière Features.SecuredCardV2
-- (ou SecuredCardV2Dev dans le jeu DEV et TEST).
--
-- API :
--   SecuredTier.On(name) -> boolean            Features[name] partout, ou Features[name .. "Dev"] dans le jeu DEV
--   SecuredTier.BigIncome() -> number          $/s d'un gros objet (SecuredCard.Tier.BigIncome, sinon
--                                              Config/Announce.ValueMinIncome)
--   SecuredTier.TierOf(rarity, income?, lucky?) -> (tier, tag?)
--        tier « Grand » (coup de chance, rareté d'ordre GrandOrder ou plus, ou income ≥ BigIncome), « Legendary »
--        (rareté d'ordre LegendaryOrder), « Normal » sinon ; tag = texte de Card.RarityTag aux gros paliers
--        (« LUCKY! », « MYTHIC! », « JACKPOT! »), nil sinon.
--   SecuredTier.LuckyFor(player, itemId, mutation?) -> boolean?   (serveur) coup de chance : cote « 1 in N » ≥
--        Lucky.MinOneIn et chance achetée ≤ Lucky.MaxBoughtLuck ; nil quand SecuredCardV2 est coupé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features")) :: any
local Rarities = require(Config:WaitForChild("Rarities"))
local Card = require(Config:WaitForChild("SecuredCard"))

local SecuredTier = {}

local devFlag: boolean? = nil
local function isDev(): boolean
	if devFlag == nil then
		local module = Config:FindFirstChild("ProductIds")
		local ok, ids = false, nil
		if module ~= nil and module:IsA("ModuleScript") then
			ok, ids = pcall(require, module)
		end
		devFlag = ok and type(ids) == "table" and (ids :: any).IsDev == true
	end
	return devFlag == true
end

function SecuredTier.On(name: string): boolean
	return Features[name] == true or (Features[name .. "Dev"] == true and isDev())
end

function SecuredTier.BigIncome(): number
	local own = (Card.Tier :: any).BigIncome
	if type(own) == "number" then
		return own
	end
	local ok, announce = pcall(function(): any
		return require(Config:WaitForChild("Announce")) :: any
	end)
	local value = if ok and type(announce) == "table" then (announce :: any).ValueMinIncome else nil
	return if type(value) == "number" then value else math.huge
end

function SecuredTier.TierOf(rarityId: string?, income: number?, lucky: boolean?): (string, string?)
	local rarity = if type(rarityId) == "string" then Rarities.ById[rarityId] else nil
	local order = if rarity then rarity.Order else 0
	local tags = Card.Tag
	if lucky == true then
		return "Grand", tags.Lucky
	end
	if rarity and order >= Card.Tier.GrandOrder then
		return "Grand", string.format(tags.Rarity, rarity.DisplayNameUpper)
	end
	if type(income) == "number" and income == income and income >= SecuredTier.BigIncome() then
		return "Grand", tags.Big
	end
	if order >= Card.Tier.LegendaryOrder then
		return "Legendary", nil
	end
	return "Normal", nil
end

local function luckModules(): (any, any)
	local okOdds, odds = pcall(function(): any
		return require(Shared:WaitForChild("ItemOdds")) :: any
	end)
	local okLuck, luck = pcall(function(): any
		return require(Shared:WaitForChild("OpenLuck")) :: any
	end)
	return if okOdds then odds else nil, if okLuck then luck else nil
end

function SecuredTier.LuckyFor(player: Player, itemId: string, mutation: any): boolean?
	if not SecuredTier.On("SecuredCardV2") then
		return nil
	end
	local ItemOdds, OpenLuck = luckModules()
	if ItemOdds == nil or OpenLuck == nil then
		return false
	end
	local okOdds, oneIn = pcall(ItemOdds.OneIn, itemId, mutation)
	if not okOdds or type(oneIn) ~= "number" or oneIn < Card.Lucky.MinOneIn then
		return false
	end
	local okBought, bought = pcall(function(): number
		return OpenLuck.Bought({
			Server = Workspace:GetAttribute("ServerLuck"),
			Skill = OpenLuck.SkillFactorOf(player),
			Personal = OpenLuck.PersonalFactorOf(player),
		})
	end)
	return okBought and type(bought) == "number" and bought <= Card.Lucky.MaxBoughtLuck
end

return table.freeze(SecuredTier)
