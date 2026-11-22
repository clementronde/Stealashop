--!strict
-- ZoneBoxOdds (a309, 22/11, décision de Cantin) : zone et chances du colis de zone offert par les paliers de temps de
-- jeu (Config/Rewards : Kind = "ZoneBox", règles Rewards.ZoneBox), tiré par UnboxService.GiveZoneBoxItem. Pur, sans
-- yield, commun au serveur et aux bancs.
--
-- Règle obligatoire (Cantin, 22/11 : les magasins vont encore changer) : tout est lu AU MOMENT DE L'APPEL, rien n'est
-- recopié :
--   - zones existantes : Config/Zones (#Zones = la dernière zone) ;
--   - raretés de chaque zone : Rarities.ZoneRarities[zone], triées par Order ; leurs chances : Rarities.ZoneOdds[zone],
--     les mêmes tables que les rayons (StoreHeistService).
-- Une règle (Rewards.ZoneBox) ne porte que ses réglages :
--   ZoneStep    zones au-dessus de la zone de référence (0 : la même, 1 : la suivante), bornée à la dernière zone de
--               Config/Zones ; une zone sans raretés dans ZoneOdds fait descendre à la première zone en dessous qui en a ;
--   Exclude     raretés retirées avant tout (Id de Config/Rarities, par exemple Secret) ;
--   TopCount    seulement les TopCount meilleures raretés de la zone (ordre Order), avec les poids TopWeights (de la plus
--   TopWeights  basse à la plus haute) ; une zone qui en a moins prend les premiers poids (zone 2 : 60 et 30, soit
--               67 et 33 %) ;
--   TopBoost    sans TopCount : les chances des rayons, celle de la rareté la plus haute de la zone multipliée par
--               TopBoost, l'écart pris sur la rareté la plus basse (au plus toute sa chance) ; une zone à une seule
--               rareté ne change pas.
--
-- API :
--   ZoneBoxOdds.Zone(rule, bestZone, source?) -> number?
--       La zone du colis : bestZone + ZoneStep, entre 1 et la dernière zone (voir plus haut) ; nil si aucune zone.
--   ZoneBoxOdds.Chances(rule, zone, source?) -> { Entry }
--       Les raretés possibles, de la plus basse à la plus haute, Chance en pour cent (total 100) ; vide si aucune.
--   ZoneBoxOdds.Draw(chances, roll) -> Entry?
--       La rareté tirée pour roll dans [0, 1) (Random:NextNumber()) ; nil si chances est vide.
--   source = { Rarities = …, Zones = … } : tables à lire à la place de Config/Rarities et Config/Zones (bancs).

local Config = script.Parent:WaitForChild("Config")
local Rarities = require(Config:WaitForChild("Rarities"))
local Zones = require(Config:WaitForChild("Zones"))

export type Rule = { -- même forme que Config/Rewards.ZoneBoxRule
	ZoneStep: number,
	Exclude: { string }?,
	TopCount: number?,
	TopWeights: { number }?,
	TopBoost: number?,
}

export type Entry = {
	Id: string, -- RarityId
	Order: number,
	Chance: number, -- pour cent
}

-- Ce que le module lit : les champs de Config/Rarities et de Config/Zones dont il se sert.
export type Source = {
	Rarities: {
		ById: { [string]: { Order: number } },
		ZoneOdds: { [number]: { [string]: number } },
		ZoneRarities: { [number]: { string } },
	}?,
	Zones: { any }?,
}

local ZoneBoxOdds = {}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function raritiesOf(source: Source?): any
	return if source and source.Rarities then source.Rarities else Rarities
end

local function zonesOf(source: Source?): { any }
	return if source and source.Zones then source.Zones else Zones :: any
end

-- La zone a-t-elle au moins une rareté avec une chance (ZoneOdds) ?
local function hasRarities(rarities: any, zone: number): boolean
	local odds = rarities.ZoneOdds[zone]
	local list = rarities.ZoneRarities[zone]
	if type(odds) ~= "table" or type(list) ~= "table" then
		return false
	end
	for _, id in list do
		local value = odds[id]
		if finite(value) and value > 0 then
			return true
		end
	end
	return false
end

function ZoneBoxOdds.Zone(rule: Rule, bestZone: number, source: Source?): number?
	local rarities = raritiesOf(source)
	local last = #zonesOf(source)
	if last < 1 then
		return nil
	end
	local step = if finite(rule.ZoneStep) then math.floor(rule.ZoneStep :: number) else 0
	local base = if finite(bestZone) then math.floor(bestZone) else 1
	local zone = math.clamp(base + step, 1, last)
	while zone >= 1 and not hasRarities(rarities, zone) do
		zone -= 1
	end
	return if zone >= 1 then zone else nil
end

function ZoneBoxOdds.Chances(rule: Rule, zone: number, source: Source?): { Entry }
	local rarities = raritiesOf(source)
	local odds = rarities.ZoneOdds[zone]
	local list = rarities.ZoneRarities[zone]
	if type(odds) ~= "table" or type(list) ~= "table" then
		return {}
	end
	local excluded: { [string]: boolean } = {}
	local exclude = rule.Exclude
	if exclude then
		for _, id in exclude do
			excluded[id] = true
		end
	end
	local kept: { Entry } = {}
	for _, id in list do
		local value = odds[id]
		local def = rarities.ById[id]
		if def and not excluded[id] and finite(value) and value > 0 then
			table.insert(kept, { Id = id, Order = def.Order, Chance = value })
		end
	end
	table.sort(kept, function(a: Entry, b: Entry): boolean
		return a.Order < b.Order
	end)
	if #kept == 0 then
		return {}
	end
	local topCount = rule.TopCount
	if finite(topCount) then
		local weights = rule.TopWeights or {}
		local count = math.min(math.floor(topCount :: number), #kept, #weights)
		local top: { Entry } = {}
		for k = 1, count do
			local entry = kept[#kept - count + k]
			local weight = weights[k]
			entry.Chance = if finite(weight) and weight > 0 then weight else 0
			table.insert(top, entry)
		end
		kept = top
	end
	local total = 0
	for _, entry in kept do
		total += entry.Chance
	end
	if total <= 0 then
		return {}
	end
	for _, entry in kept do
		entry.Chance = entry.Chance * 100 / total
	end
	local boost = rule.TopBoost
	if topCount == nil and finite(boost) and #kept >= 2 then
		local high, low = kept[#kept], kept[1]
		local gain = math.clamp(high.Chance * ((boost :: number) - 1), -high.Chance, low.Chance)
		high.Chance += gain
		low.Chance -= gain
	end
	return kept
end

function ZoneBoxOdds.Draw(chances: { Entry }, roll: number): Entry?
	local total = 0
	for _, entry in chances do
		total += math.max(entry.Chance, 0)
	end
	local left = math.clamp(roll, 0, 1) * total
	local last: Entry? = nil
	for _, entry in chances do
		if entry.Chance > 0 then
			last = entry
			if left < entry.Chance then
				return entry
			end
			left -= entry.Chance
		end
	end
	return last -- arrondi des nombres à virgule : la dernière rareté possible
end

return ZoneBoxOdds
