--!strict
-- ZoneBoxEverywhere (a440, lot 6 du check-up a417, R13 ; décision C1 de Cantin, 24/11 : « colis de zone partout,
-- comme les paliers de 15 et 60 min ») : fin des types de colis Standard / Premium / Luxe hors des rayons (les rayons
-- n'en ont plus depuis la vague 76). Interrupteur Config/Features.ZoneBoxEverywhere (partout) et ZoneBoxEverywhereDev
-- (jeu DEV seulement, Config/ProductIds.IsDev), comme ChaseV3. Allumé :
--   - le camion (TruckEventService), les cadeaux du jour J2 et J4 (RewardService ; J7 est un colis
--     Épique ou mieux, BoxRarity, allumé comme coupé : Cantin, 25/11) et les codes « Item »
--     (CodeService) donnent un colis de zone (Shared/ZoneBoxOdds) : l'ancien type devient la règle
--     Config/Rewards.TierZoneBox[type] de Config/Rewards.ZoneBox ; la Fortune Tower tire ses caisses dans la règle
--     Config/FortuneTower.ZoneBox.
-- Coupé : les types et leurs tables (Balance.Heist.BoxTiers, Rarities.BoxOdds), comme avant.
-- Aucune migration de profil : un joueur ne garde jamais un colis typé (DataService.convertBoxes, vague 31, ouvre au
-- chargement tout colis rangé avant la vague 50 ; plus aucun colis n'est rangé depuis ; Cantin, 25/11).
-- En Studio, workspace:SetAttribute("ZoneBoxEverywhereTest", true ou false) force la réponse (lu à chaque appel) : pour
-- comparer les deux chemins dans le même Play, sans toucher à Config/Features.
--
-- API :
--   ZoneBoxEverywhere.Enabled() -> boolean
--   ZoneBoxEverywhere.RuleName(tier) -> string?          nom de la règle de l'ancien type (Rewards.TierZoneBox)
--   ZoneBoxEverywhere.Rule(tier) -> (string?, Rule?)     ce nom et la règle (Rewards.ZoneBox[nom]) ; nil, nil si inconnu
--   ZoneBoxEverywhere.Odds(rule, reference) -> (zone?, { [RarityId] = pour cent })
--       zone du colis (ZoneBoxOdds.Zone) et ses chances (ZoneBoxOdds.Chances), lues au moment de l'appel (Fortune Tower)
--   ZoneBoxEverywhere.DrawRarity(rule, reference, rng) -> (RarityId?, zone?)   une rareté tirée (camion)
--   ZoneBoxEverywhere.ZoneOf(name, reference) -> zone?   a517 : zone du colis de la règle Rewards.ZoneBox[name]

-- Services de Roblox lus sans lever d'erreur (bancs sans `game`) : absents, ni Studio ni attribut de test.
local function service(name: string): any
	local ok, result = pcall(function(): any
		return (game :: any):GetService(name)
	end)
	return if ok then result else nil
end
local RunService = service("RunService")
local Workspace = service("Workspace")

local Config = script.Parent:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features")) :: any
local Rewards = require(Config:WaitForChild("Rewards"))
local ZoneBoxOdds = require(script.Parent:WaitForChild("ZoneBoxOdds"))

export type Rule = ZoneBoxOdds.Rule

local TEST_ATTRIBUTE = "ZoneBoxEverywhereTest"

-- Config/ProductIds chargé s'il est là ; sans lui, IsDev faux (PROD), comme ChaseV3.
local isDev = (function(): boolean
	local module = Config:FindFirstChild("ProductIds")
	if module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return (result :: any).IsDev == true
		end
	end
	return false
end)()

local isStudio = (function(): boolean
	if RunService == nil or Workspace == nil then
		return false
	end
	local ok, result = pcall(function(): boolean
		return RunService:IsStudio()
	end)
	return ok and result == true
end)()

local base = Features.ZoneBoxEverywhere == true or (Features.ZoneBoxEverywhereDev == true and isDev)

local ZoneBoxEverywhere = {}

function ZoneBoxEverywhere.Enabled(): boolean
	if isStudio then
		local forced = Workspace:GetAttribute(TEST_ATTRIBUTE)
		if type(forced) == "boolean" then
			return forced
		end
	end
	return base
end

function ZoneBoxEverywhere.RuleName(tier: any): string?
	local name = if type(tier) == "string" then (Rewards.TierZoneBox :: any)[tier] else nil
	return if type(name) == "string" then name else nil
end

function ZoneBoxEverywhere.Rule(tier: any): (string?, Rule?)
	local name = ZoneBoxEverywhere.RuleName(tier)
	local rule = if name then (Rewards.ZoneBox :: any)[name] else nil
	if type(rule) ~= "table" then
		return nil, nil
	end
	return name, rule :: Rule
end

-- a517 : zone du colis de la règle `name` de Config/Rewards.ZoneBox (ZoneBoxOdds.Zone, la même que DrawRarity) ; nil si
-- la règle est inconnue.
function ZoneBoxEverywhere.ZoneOf(name: any, reference: number): number?
	local rule = if type(name) == "string" then (Rewards.ZoneBox :: any)[name] else nil
	return if type(rule) == "table" then ZoneBoxOdds.Zone(rule :: Rule, reference) else nil
end

function ZoneBoxEverywhere.Odds(rule: Rule, reference: number): (number?, { [string]: number })
	local odds: { [string]: number } = {}
	local zone = ZoneBoxOdds.Zone(rule, reference)
	if zone then
		for _, entry in ZoneBoxOdds.Chances(rule, zone) do
			odds[entry.Id] = entry.Chance
		end
	end
	return zone, odds
end

function ZoneBoxEverywhere.DrawRarity(rule: Rule, reference: number, rng: Random): (string?, number?)
	local zone = ZoneBoxOdds.Zone(rule, reference)
	local drawn = if zone then ZoneBoxOdds.Draw(ZoneBoxOdds.Chances(rule, zone), rng:NextNumber()) else nil
	return if drawn then drawn.Id else nil, zone
end

return ZoneBoxEverywhere
