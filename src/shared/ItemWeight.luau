--!strict
-- ItemWeight (vague 62, a203 ; décision de Cantin et Clément du 2026-11-15, liaison L-198) : le poids d'un objet,
-- de 1 à 10 000 kg, et ce qu'il change : la taille du modèle, le revenu, la mutation de taille (Huge, Colossal) et
-- la classe de taille de la cinématique d'ouverture. Commun au serveur et au client. Valeurs : Config/Weight.
-- Interrupteur : Features.SingleBoxReveal (lu par Config/Mutations : false = les mutations de taille d'avant).
--
-- Contrat de la vague 62 (a202 tire, a204 montre, a203 calcule ; ne pas changer sans le dire) :
--   ItemWeight.Roll(rng, luck) -> number               poids tiré (kg), `luck` = multiplicateur de chance de la
--                                                      boîte (×1 à ×8, celui de la rareté) : il multiplie les
--                                                      chances des paliers lourds, sans rien garantir
--   ItemWeight.ScaleFor(kg) -> number                  échelle du modèle (10 kg = ×1, racine cubique du poids)
--   ItemWeight.IncomeFactor(kg) -> number              multiplicateur du revenu (10 kg = ×1)
--   ItemWeight.SizeMutationFor(kg) -> string?          "Huge", "Colossal" ou nil (Id de Config/Mutations)
--   ItemWeight.SizeClassFor(kg, freeHeight, modelHeight) -> "Small" | "Large" | "Colossal"
--        Colossal : palier Colossal (la caméra sort du magasin) ; Large : l'objet grandi (modelHeight, hauteur du
--        modèle à l'échelle 1, × ScaleFor) atteint freeHeight (hauteur libre sous le plafond, studs) ; Small sinon.
-- En plus :
--   ItemWeight.Enabled() -> boolean                    Features.SingleBoxReveal (bancs : SetEnabledForTest)
--   ItemWeight.RollForSize(rng, luck, sizeId) -> number   poids tiré dans le palier de sizeId ("Huge" ou
--                                                      "Colossal" : Fortune Tower, tailles garanties) ; autre : Roll
--   ItemWeight.TierChances(luck) -> { number }         chance de chaque palier de Config/Weight.Tiers, pour cent
--   ItemWeight.SizeChance(sizeId, luck) -> number      chance (pour cent) de tirer ce palier de taille
--   ItemWeight.Sanitize(value) -> number?              poids lu (profil, attribut) ramené à 1…10 000 ; nil si illisible
--   ItemWeight.LegacyFor(sizeId?) -> number            poids d'un objet d'avant le poids (Config/Weight.Legacy)
--   ItemWeight.Effective(weight?, sizeId?) -> number   le poids s'il est lisible, sinon LegacyFor(sizeId)
--   ItemWeight.CappedScale(kg, cap) -> number          ScaleFor(kg), au plus cap
--   ItemWeight.Migrate(items) -> number                Items du profil : Weight posé là où il manque, Tiny et Big retirées (DataService)
--   ItemWeight.Format(kg) -> string                    « 3.4 kg », « 12 kg », « 1,250 kg »

local Config = script.Parent.Config
local Weight = require(Config.Weight)
local Features = require(Config.Features)

export type SizeClass = "Small" | "Large" | "Colossal"

local ItemWeight = {}

local enabledOverride: boolean? = nil

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function clampKg(kg: any): number
	if not finite(kg) then
		return Weight.Reference
	end
	return math.clamp(kg, Weight.Min, Weight.Max)
end

local function cleanLuck(luck: any): number
	return if finite(luck) and luck > 1 then luck else 1
end

-- Arrondi vers le bas (le poids reste dans son palier) : au dixième sous 100 kg, au kilo au-delà.
local function rounded(kg: number): number
	if kg < 100 then
		return math.max(Weight.Min, math.floor(kg * 10 + 1e-6) / 10)
	end
	return math.floor(kg + 1e-6)
end

function ItemWeight.Enabled(): boolean
	if enabledOverride ~= nil then
		return enabledOverride
	end
	return Features.SingleBoxReveal == true
end

-- Bancs seulement : force l'interrupteur (nil = celui de Features).
function ItemWeight.SetEnabledForTest(value: boolean?)
	enabledOverride = value
end

-- Chances relatives de chaque palier pour cette chance (paliers lourds × luck), et leur total.
local function weightsFor(luck: any): ({ number }, number)
	local boost = cleanLuck(luck)
	local list: { number } = {}
	local total = 0
	for index, tier in Weight.Tiers do
		local chance = math.max(tier.Chance, 0)
		if tier.Min >= Weight.LuckFrom then
			chance *= boost
		end
		list[index] = chance
		total += chance
	end
	return list, total
end

function ItemWeight.TierChances(luck: number): { number }
	local list, total = weightsFor(luck)
	local out: { number } = {}
	for index, chance in list do
		out[index] = if total > 0 then chance / total * 100 else 0
	end
	return out
end

-- Part du palier `tier` comprise entre lo et hi (kg), en échelle logarithmique (0 à 1).
local function share(tier: Weight.Tier, lo: number, hi: number): number
	if tier.Max <= tier.Min then
		return if tier.Min >= lo and (tier.Min < hi or hi >= Weight.Max) then 1 else 0
	end
	local a, b = math.max(tier.Min, lo), math.min(tier.Max, hi)
	if b <= a then
		return 0
	end
	return math.log(b / a) / math.log(tier.Max / tier.Min)
end

-- Poids tiré dans le palier `tier`, entre lo et hi (en échelle logarithmique).
local function drawIn(rng: Random, tier: Weight.Tier, lo: number, hi: number): number
	if tier.Max <= tier.Min then
		return tier.Min
	end
	local a, b = math.max(tier.Min, lo), math.min(tier.Max, hi)
	local kg = a * (b / a) ^ rng:NextNumber()
	return math.clamp(rounded(kg), a, math.max(a, b - 0.1))
end

-- Tirage limité à [lo, hi) kg (hi = Max : 10 000 kg compris).
local function rollBetween(rng: Random, luck: any, lo: number, hi: number): number
	local list = weightsFor(luck)
	local parts: { number } = {}
	local total = 0
	for index, tier in Weight.Tiers do
		local part = list[index] * share(tier, lo, hi)
		parts[index] = part
		total += part
	end
	if total <= 0 then
		return clampKg(lo)
	end
	local roll = rng:NextNumber() * total
	local last = 0
	for index, part in parts do
		if part > 0 then
			last = index
			if roll < part then
				return drawIn(rng, Weight.Tiers[index], lo, hi)
			end
			roll -= part
		end
	end
	return drawIn(rng, Weight.Tiers[last], lo, hi) -- arrondi des nombres à virgule : le dernier palier possible
end

function ItemWeight.Roll(rng: Random, luck: number): number
	return rollBetween(rng, luck, Weight.Min, Weight.Max)
end

-- Bornes du palier de la mutation de taille `sizeId` ; nil pour une autre taille.
local function sizeRange(sizeId: any): (number?, number?)
	if sizeId == "Huge" then
		return Weight.HugeFrom, Weight.ColossalFrom
	elseif sizeId == "Colossal" then
		return Weight.ColossalFrom, Weight.Max
	end
	return nil, nil
end

function ItemWeight.RollForSize(rng: Random, luck: number, sizeId: string?): number
	local lo, hi = sizeRange(sizeId)
	if lo == nil or hi == nil then
		return ItemWeight.Roll(rng, luck)
	end
	return rollBetween(rng, luck, lo, hi)
end

function ItemWeight.SizeChance(sizeId: string, luck: number): number
	local lo, hi = sizeRange(sizeId)
	if lo == nil or hi == nil then
		return 0
	end
	local list, total = weightsFor(luck)
	if total <= 0 then
		return 0
	end
	local sum = 0
	for index, tier in Weight.Tiers do
		sum += list[index] * share(tier, lo, hi)
	end
	return sum / total * 100
end

function ItemWeight.ScaleFor(kg: number): number
	return Weight.ScaleAt(clampKg(kg)) -- a234 : courbe par points de Config/Weight (ScaleCurve)
end

function ItemWeight.IncomeFactor(kg: number): number
	return (clampKg(kg) / Weight.Reference) ^ Weight.IncomeExponent
end

function ItemWeight.CappedScale(kg: number, cap: number): number
	local scale = ItemWeight.ScaleFor(kg)
	return if finite(cap) and cap > 0 then math.min(scale, cap) else scale
end

function ItemWeight.SizeMutationFor(kg: number): string?
	local w = clampKg(kg)
	if w >= Weight.ColossalFrom then
		return "Colossal"
	elseif w >= Weight.HugeFrom then
		return "Huge"
	end
	return nil
end

function ItemWeight.SizeClassFor(kg: number, freeHeight: number, modelHeight: number): SizeClass
	local w = clampKg(kg)
	if w >= Weight.ColossalFrom then
		return "Colossal"
	end
	if finite(freeHeight) and finite(modelHeight) and freeHeight > 0 and modelHeight > 0 then
		if modelHeight * ItemWeight.ScaleFor(w) >= freeHeight then
			return "Large"
		end
	end
	return "Small"
end

function ItemWeight.Sanitize(value: any): number?
	if not finite(value) then
		return nil
	end
	return math.clamp(value, Weight.Min, Weight.Max)
end

function ItemWeight.LegacyFor(sizeId: any): number
	local legacy = if type(sizeId) == "string" then Weight.Legacy[sizeId] else nil
	return if legacy then legacy else Weight.Reference
end

function ItemWeight.Effective(weight: any, sizeId: any): number
	local clean = ItemWeight.Sanitize(weight)
	return if clean then clean else ItemWeight.LegacyFor(sizeId)
end

-- Profil (DataService, au chargement, sans changement de version) : chaque objet sans poids lisible reçoit celui
-- de sa mutation de taille d'avant (Config/Weight.Legacy : au moins son revenu d'avant, Huge et Colossal dans
-- leur palier) ; un poids hors de 1…10 000 kg y est ramené. Vague 70 (a231) : poids en marche, une fois le poids
-- posé, la taille d'avant que le poids ne donne plus (Tiny, Big : ni lues ni écrites, Config/Mutations) est retirée
-- de la mutation (sans effet, la mutation part) ; Huge et Colossal restent. Poids coupé : la mutation n'est pas
-- touchée. Idempotent. Renvoie le nombre d'objets changés.
local WEIGHT_SIZES: { [string]: boolean } = { Huge = true, Colossal = true } -- ceux de SizeMutationFor

function ItemWeight.Migrate(items: any): number
	if type(items) ~= "table" then
		return 0
	end
	local changed = 0
	for _, entry in items do
		if type(entry) ~= "table" then
			continue
		end
		local current = entry.Weight
		local clean = ItemWeight.Sanitize(current)
		local mutation = entry.Mutation
		local touched = false
		if clean == nil then
			entry.Weight = ItemWeight.LegacyFor(if type(mutation) == "table" then mutation.Size else nil)
			touched = true
		elseif clean ~= current then
			entry.Weight = clean
			touched = true
		end
		if ItemWeight.Enabled() and type(mutation) == "table" and mutation.Size ~= nil and not WEIGHT_SIZES[mutation.Size] then
			mutation.Size = nil -- après le poids, qui l'a lue
			if next(mutation) == nil then
				entry.Mutation = nil
			end
			touched = true
		end
		if touched then
			changed += 1
		end
	end
	return changed
end

-- 1250 -> « 1,250 ».
local function grouped(value: number): string
	local digits = string.format("%d", value)
	local out = ""
	local count = 0
	for index = #digits, 1, -1 do
		out = string.sub(digits, index, index) .. out
		count += 1
		if count % 3 == 0 and index > 1 then
			out = Weight.ThousandsSeparator .. out
		end
	end
	return out
end

-- Texte du poids (élément Weight des billboards et cases) : une décimale sous 100 kg si elle n'est pas nulle
-- (« 3.4 kg », « 12 kg »), le kilo entier au-delà (« 1,250 kg »), toujours arrondi vers le bas.
function ItemWeight.Format(kg: number): string
	local w = clampKg(kg)
	local text: string
	if w < 100 then
		local tenths = math.floor(w * 10 + 1e-6)
		text = if tenths % 10 == 0 then tostring(tenths // 10) else string.format("%d.%d", tenths // 10, tenths % 10)
	else
		text = grouped(math.floor(w + 1e-6))
	end
	return `{text} {Weight.Unit}`
end

return table.freeze(ItemWeight)
