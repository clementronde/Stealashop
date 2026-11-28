--!strict
-- ItemOdds (vague 50, a161 ; L-165 point 5) : la chance d'un objet, écrite « 1 in 5,300,000,000 » sur le
-- grand socle de l'objet le plus rare (BB_RarestDisplay.Odds, VfxController) et « 1 IN N » à l'ouverture d'un colis
-- (Formulas.UnboxOdds, StoreHeistService). Commun au serveur et au client.
--
-- Vague 76 (Cantin et Clément, 19/11) : la VRAIE chance d'avoir cet objet, avec sa mutation et sa classe de taille,
-- en ouvrant le colis d'un emplacement de rayon de sa zone (un Secret, sans zone : la première zone où sa rareté
-- existe, la 6) ; la même pour tous les exemplaires d'un même objet et d'une même mutation :
--   chance = Σ sur la chance du joueur (ShelfOpen.LuckTable, poids relatifs ; ×1 seul sans Reveal.TableLuck)
--              [ Σ sur la rareté du colis (ShelfBoxes.ZoneOdds[zone])
--                  P(colis) × P(rareté de l'objet | colis, chance) (ShelfBoxes.ContentWeights, limitée à la zone, montée réduite par cran) ]
--              × P(classe de taille | chance) (Huge, Colossal : ItemWeight.SizeChance ; sans taille : le reste)
--            × part de l'objet dans sa rareté et sa zone (DrawWeight / total, comme Items.Pick)
--            × P(effet) (Config/Mutations ; sans effet : 1 − la somme des effets).
-- Ni le bonus de chance du serveur (ServerLuck, Robux) ni un contenu imposé (tuto) n'y entrent. Un objet TutorialOnly
-- (que nul tirage ne donne) ou d'une rareté sans zone (Divine) n'a pas de chance : nil.
--
-- API :
--   ItemOdds.Chance(itemId, mutation?) -> number?   probabilité entre 0 et 1, nil si inconnue ou nulle
--   ItemOdds.OneIn(itemId, mutation?) -> number?    1 / Chance, arrondi lisible (Formulas.UnboxOdds), nil sinon
--   ItemOdds.Format(oneIn) -> string                 « 1 in 5,300,000,000 » (au-delà de 1e15 : « 1 in 5.3Qa »)

local Config = script.Parent:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Mutations = require(Config:WaitForChild("Mutations"))
local ShelfOpen = require(Config:WaitForChild("ShelfOpen"))
local ShelfBoxes = require(Config:WaitForChild("ShelfBoxes"))
local Formulas = require(Config:WaitForChild("Formulas"))
local Format = require(script.Parent:WaitForChild("Format"))
local ItemWeight = require(script.Parent:WaitForChild("ItemWeight"))

-- Au-delà, les chiffres ne tiennent plus sur le billboard ni dans un double exact : écriture courte.
local GROUPED_UNTIL = 1e15

local ItemOdds = {}

local function poolOf(item: Items.Item, zone: number): { Items.Item }?
	local all = Items.AllZones[item.Rarity]
	if all then
		return all
	end
	local byRarity = Items.ByZone[zone]
	return if byRarity then byRarity[item.Rarity] else nil
end

-- Somme des chances (pour cent) d'une famille de mutations.
local function familyTotal(list: { any }): number
	local total = 0
	for _, entry in list do
		total += math.max(entry.Chance, 0)
	end
	return total
end

-- Paliers de taille du poids (ItemWeight.SizeMutationFor).
local SIZED: { string } = { "Huge", "Colossal", "Titan", "Cosmic" }

-- Probabilité (0 à 1) de la classe de taille `sizeId` (nil : ni Huge ni Colossal) à la chance `luck`.
local function sizeChance(sizeId: string?, luck: number): number
	if sizeId then
		return ItemWeight.SizeChance(sizeId, luck) / 100
	end
	-- a528 : Titan et Cosmic aussi (0 tant qu'ItemWeight.SizeChance ne les connaît pas)
	local sized = 0
	for _, id in SIZED do
		sized += ItemWeight.SizeChance(id, luck)
	end
	return 1 - sized / 100
end

function ItemOdds.Chance(itemId: string, mutation: any): number?
	local item = Items.ById[itemId]
	if item == nil or item.TutorialOnly then
		return nil
	end
	local zone = item.Zone or ShelfBoxes.FirstZone[item.Rarity]
	local boxOdds = if zone then ShelfBoxes.ZoneOdds[zone] else nil
	if zone == nil or boxOdds == nil then
		return nil
	end
	local pool = poolOf(item, zone)
	if pool == nil or table.find(pool, item) == nil then
		return nil
	end
	local poolWeight = 0
	for _, other in pool do
		poolWeight += other.DrawWeight
	end
	local clean = Mutations.Sanitize(mutation)
	local sizeId = if clean then clean.Size else nil
	local effect = if clean and clean.Effect then Mutations.EffectById[clean.Effect] else nil
	local effectChance = if effect then effect.Chance / 100 else 1 - familyTotal(Mutations.Effects) / 100
	local lucks: { ShelfOpen.LuckEntry } = if ShelfOpen.Reveal.TableLuck then ShelfOpen.LuckTable else { { Luck = 1, Weight = 1 } }
	local luckTotal, sum = 0, 0
	for _, entry in lucks do
		local luckWeight = math.max(entry.Weight, 0)
		local luck = math.max(entry.Luck, 1)
		local boxTotal, rarityChance = 0, 0
		for boxRarity, percent in boxOdds do
			boxTotal += percent
			local weights = ShelfBoxes.ContentWeights(boxRarity, luck, zone)
			if weights and (weights[item.Rarity] or 0) > 0 then
				local total = 0
				for _, weight in weights do
					total += weight
				end
				rarityChance += percent * weights[item.Rarity] / total
			end
		end
		luckTotal += luckWeight
		if boxTotal > 0 then
			sum += luckWeight * rarityChance / boxTotal * sizeChance(sizeId, luck)
		end
	end
	if luckTotal <= 0 or poolWeight <= 0 then
		return nil
	end
	local chance = sum / luckTotal * item.DrawWeight / poolWeight * effectChance
	return if chance > 0 and chance == chance then chance else nil
end

function ItemOdds.OneIn(itemId: string, mutation: any): number?
	local chance = ItemOdds.Chance(itemId, mutation)
	if chance == nil then
		return nil
	end
	return Formulas.UnboxOdds(chance)
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
