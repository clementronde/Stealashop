--!strict
-- ItemOdds (vague 50, a161 ; L-165 point 5) : la chance d'un objet, écrite « 1 in 5,300,000,000 » sur le
-- grand socle de l'objet le plus rare (BB_RarestDisplay.Odds, VfxController). Commun au serveur et au client.
--
-- Le jeu ne garde pas la chance du tirage avec l'objet (ni la caisse, ni la chance du joueur) : ce module
-- calcule une chance de référence, la même pour tous les exemplaires d'un même objet et d'une même mutation
-- (V0 proposé, absent du doc, à valider par Clément) :
--   chance = P(rareté) × 1 / (objets tirables de cette rareté) × P(taille) × P(effet)
--   - P(rareté) : poids de la rareté dans la caisse de référence `box` (ShelfOpen.BoxRarityOdds[box],
--     poids ramenés à 1), sans chance du joueur ; le VfxController passe Vfx.RarestDisplay.OddsBox ;
--   - objets tirables : Items.ByZone[zone de l'objet][rareté] (Items.AllZones pour Secret et Divine),
--     comme Items.Pick ; un objet hors de cette liste (TutorialOnly) n'a pas de chance : nil ;
--   - P(taille), P(effet) : Chance de la mutation (Config/Mutations, pour cent) ; sans mutation dans une
--     famille, cette famille ne compte pas (la chance est celle d'un objet « au moins » de cette mutation).
--
-- API :
--   ItemOdds.Chance(itemId, mutation?, box) -> number?   probabilité entre 0 et 1, nil si inconnue ou nulle
--   ItemOdds.OneIn(itemId, mutation?, box) -> number?    1 / Chance, arrondi à l'entier, nil sinon
--   ItemOdds.Format(oneIn) -> string                      « 1 in 5,300,000,000 » (au-delà de 1e15 : « 1 in 5.3Qa »)

local Config = script.Parent:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Mutations = require(Config:WaitForChild("Mutations"))
local ShelfOpen = require(Config:WaitForChild("ShelfOpen"))
local Format = require(script.Parent:WaitForChild("Format"))

-- Au-delà, les chiffres ne tiennent plus sur le billboard ni dans un double exact : écriture courte.
local GROUPED_UNTIL = 1e15

local ItemOdds = {}

local function poolOf(item: Items.Item): { Items.Item }?
	local all = Items.AllZones[item.Rarity]
	if all then
		return all
	end
	local zone = item.Zone
	local byRarity = if zone then Items.ByZone[zone] else nil
	return if byRarity then byRarity[item.Rarity] else nil
end

function ItemOdds.Chance(itemId: string, mutation: any, box: string): number?
	local item = Items.ById[itemId]
	local odds = ShelfOpen.BoxRarityOdds[box]
	if item == nil or odds == nil then
		return nil
	end
	local total = 0
	for _, weight in odds do
		if type(weight) == "number" and weight > 0 then
			total += weight
		end
	end
	local weight = odds[item.Rarity]
	if total <= 0 or type(weight) ~= "number" or weight <= 0 then
		return nil
	end
	local pool = poolOf(item)
	if pool == nil or table.find(pool, item) == nil then
		return nil
	end
	local chance = weight / total / #pool
	local clean = Mutations.Sanitize(mutation)
	if clean then
		local size = if clean.Size then Mutations.SizeById[clean.Size] else nil
		local effect = if clean.Effect then Mutations.EffectById[clean.Effect] else nil
		if size then
			chance *= size.Chance / 100
		end
		if effect then
			chance *= effect.Chance / 100
		end
	end
	return if chance > 0 and chance == chance then chance else nil
end

function ItemOdds.OneIn(itemId: string, mutation: any, box: string): number?
	local chance = ItemOdds.Chance(itemId, mutation, box)
	if chance == nil then
		return nil
	end
	return math.max(1, math.round(1 / chance))
end

-- 5300000000 -> « 5,300,000,000 ».
local function grouped(value: number): string
	local digits = string.format("%.0f", value)
	local out = ""
	local count = 0
	for index = #digits, 1, -1 do
		out = string.sub(digits, index, index) .. out
		count += 1
		if count % 3 == 0 and index > 1 then
			out = "," .. out
		end
	end
	return out
end

function ItemOdds.Format(oneIn: number): string
	local value = if oneIn == oneIn then math.max(1, math.round(oneIn)) else 1
	if value >= GROUPED_UNTIL then
		return `1 in {Format.short(value)}`
	end
	return `1 in {grouped(value)}`
end

return ItemOdds
