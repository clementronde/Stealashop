--!strict
-- Taille d'affichage des objets exposés (a459, liaison L-354 ; a459b et a459c, L-367, règle finale de Cantin du 25/11,
-- « garder les écarts »). Lu par DisplayService (côté serveur) ; le socle « BEST ITEM » (RarestDisplay,
-- VfxController) suit la même règle, avec sa propre place.
--
-- Règle, sur un présentoir :
--   1. Facteur de la rareté (BaseFactor) : minimum de la rareté (MinByRarity) / taille du modèle médian de cette
--      rareté (Median des plus grandes dimensions des modèles ITM_ livrés du catalogue actif, exclusifs compris,
--      mesurés par DisplayService), jamais sous ×1 (Cantin, 25/11 : le facteur ne réduit jamais un modèle). Le même
--      facteur pour tous les modèles d'une rareté : les écarts sont gardés.
--   2. Taille de base : la vraie taille du modèle (sa plus grande dimension, pièces visibles) × ce facteur ; un objet
--      qui reste sous le minimum de sa rareté est remonté à ce minimum (le modèle médian y est tout juste, sauf si
--      le médian dépasse déjà le minimum : facteur ×1, vraie taille).
--   3. Grossissement par le poids : ×1 au poids minimal (Weight.Min), jusqu'à GrowthByRarity au poids maximal
--      (Weight.Max) seulement, entre les deux la forme de Weight.ScaleCurve (courbe logarithmique douce) ramenée à
--      cet écart.
--   4. Aucun maximum par rareté : les seules limites sont la place physique (DisplayService) : la hauteur sous le
--      plafond du présentoir (FitSize.Y, flottement retiré) et la largeur jusqu'aux présentoirs voisins (déborder du
--      présentoir sur un côté sans voisin est permis ; le tour de l'encaissement, DisplayMotion.SpinTime, ne compte
--      pas). Un objet qui déborde est réduit juste assez pour tenir.
-- Aucun ITM n'est réexporté : c'est une échelle d'affichage. L'objet porté, en main, au sol et à l'ouverture du colis
-- gardent la taille de leur poids (Config/Weight).
--
-- Interrupteurs : Features.DisplayRaritySize (partout, PROD compris) et Features.DisplayRaritySizeDev (jeu DEV seulement,
-- Config/ProductIds.IsDev). Coupé : comme avant (taille du poids, Weight.ScaleCurve, puis réduction FitSize).
--
-- Origine des valeurs : minimums = bas des fourchettes de Clément (L-354), Divin : Cantin (25/11) ; grossissements :
-- V0 de Cantin (25/11). Unités : studs, kg.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Rarities = require(script.Parent.Rarities)
local Weight = require(script.Parent.Weight)

-- Module de Config chargé s'il est là (bancs à liste de modules fixe, comme dans Config/Items).
local function optional(name: string): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild(name)
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end
local Features: any = optional("Features")
local ProductIds: any = optional("ProductIds")

-- Plus grande dimension minimale (studs) d'un objet exposé, par rareté.
local MIN_BY_RARITY: { [Rarities.RarityId]: number } = {
	Common = 4, -- Clément
	Uncommon = 4, -- Clément
	Rare = 4, -- Clément
	Epic = 5, -- Clément
	Legendary = 5, -- Clément
	Mythic = 7, -- Clément
	Secret = 7, -- Clément
	Divine = 7, -- Cantin (25/11)
}

-- Grossissement au poids maximal (×), par rareté ; ×1 au poids minimal.
local GROWTH_BY_RARITY: { [Rarities.RarityId]: number } = {
	Common = 1.25, -- V0 Cantin
	Uncommon = 1.25, -- V0 Cantin
	Rare = 1.25, -- V0 Cantin
	Epic = 1.5, -- V0 Cantin
	Legendary = 1.5, -- V0 Cantin
	Mythic = 2, -- V0 Cantin
	Secret = 2, -- V0 Cantin
	Divine = 2, -- V0 Cantin
}

local DisplaySize = {
	-- Allumé partout (DisplayRaritySize) ou dans le jeu DEV seulement (DisplayRaritySizeDev et ProductIds.IsDev).
	Enabled = Features.DisplayRaritySize == true or (Features.DisplayRaritySizeDev == true and ProductIds.IsDev == true),
	MinByRarity = MIN_BY_RARITY,
	GrowthByRarity = GROWTH_BY_RARITY,
	-- a491 (L-429, trophées plus gros, idée 10 validée par Clément le 26/11 ; mesures du chef 3D à côté d'un R15 de
	-- 5 studs). Allumé partout (Features.BiggerTrophies) ou dans le jeu DEV seulement (BiggerTrophiesDev et IsDev).
	Trophies = {
		Enabled = Features.BiggerTrophies == true or (Features.BiggerTrophiesDev == true and ProductIds.IsDev == true),
		-- L-429 point 3 : hauteur d'un objet exposé à l'échelle ×1 du poids (10 kg = ×2 : 5 studs, la taille du perso)
		BaseHeight = 2.5,
		-- L-429 point 3 (objets plats) : la moitié du plus grand côté compte comme hauteur quand elle est plus grande.
		-- V0 a491 : règle générale à la place de la liste des 10 objets plats de L-429 (aucun nom en dur).
		FlatShare = 0.5,
		-- L-429 point 2 : hauteur du colis de l'ouverture au départ (0,6 fois le perso), avant les améliorations
		OpenBoxHeight = 3,
	},
}

-- Plus grande dimension minimale (studs) d'un objet de rareté `rarityId` ; nil pour une rareté inconnue.
function DisplaySize.MinFor(rarityId: any): number?
	return if type(rarityId) == "string" then (MIN_BY_RARITY :: any)[rarityId] :: number? else nil
end

-- a459c (L-367) : médiane des tailles `sides` (studs ; les valeurs non positives ou illisibles sont ignorées) : celle
-- du milieu, ou la moyenne des deux du milieu pour un nombre pair ; nil sans aucune taille. Ne modifie pas `sides`.
function DisplaySize.Median(sides: { number }): number?
	local sorted: { number } = {}
	for _, side in sides do
		if type(side) == "number" and side > 0 and side < math.huge then
			table.insert(sorted, side)
		end
	end
	local count = #sorted
	if count == 0 then
		return nil
	end
	table.sort(sorted)
	local middle = (count + 1) // 2
	return if count % 2 == 1 then sorted[middle] else (sorted[middle] + sorted[middle + 1]) / 2
end

-- a459c (L-367) : échelle (×) de la taille de base d'un modèle de rareté `rarityId` dont la plus grande dimension est
-- `side` : le facteur de la rareté (minimum / `median`, taille du modèle médian de la rareté), jamais sous ×1 (Cantin,
-- 25/11 : le facteur ne réduit jamais un modèle), relevé juste assez pour que l'objet atteigne le minimum s'il reste
-- en dessous. Sans médiane lisible : `side` sert de médiane (l'objet est remonté au minimum s'il est plus petit, sinon
-- gardé à sa vraie taille). nil pour une rareté sans minimum ou une taille illisible.
function DisplaySize.BaseFactor(rarityId: any, side: any, median: any): number?
	local minimum = DisplaySize.MinFor(rarityId)
	if type(minimum) ~= "number" or not (minimum > 0) or type(side) ~= "number" or not (side > 0 and side < math.huge) then
		return nil
	end
	local middle = if type(median) == "number" and median > 0 and median < math.huge then median else side
	return math.max(1, minimum / middle, minimum / side)
end

-- Grossissement (×, de 1 à GrowthByRarity) d'un objet de rareté `rarityId` qui pèse `kg` : la forme de
-- Weight.ScaleCurve entre Weight.Min et Weight.Max, ramenée de ×1 à ×GrowthByRarity. Poids borné à [Min, Max] ;
-- absent ou illisible : Weight.Reference. 1 pour une rareté inconnue.
function DisplaySize.GrowthFor(rarityId: any, kg: any): number
	local top = if type(rarityId) == "string" then (GROWTH_BY_RARITY :: any)[rarityId] :: number? else nil
	if type(top) ~= "number" or not (top > 0) then
		return 1
	end
	local weight = if type(kg) == "number" and kg == kg then kg else Weight.Reference
	weight = math.clamp(weight, Weight.Min, Weight.Max)
	local low, high = Weight.ScaleAt(Weight.Min), Weight.ScaleAt(Weight.Max)
	if not (low > 0 and high > low) then
		return 1
	end
	local t = math.clamp(math.log(Weight.ScaleAt(weight) / low) / math.log(high / low), 0, 1)
	return top ^ t
end

-- a491 (L-429 point 3) : facteur (×, au moins 1) qui donne à un modèle haut de `height` studs, de plus grand côté
-- `side`, au moins Trophies.BaseHeight de haut à ×1 : max(1, BaseHeight / max(hauteur, FlatShare × plus grand côté)).
-- Jamais sous ×1 : un objet déjà assez haut garde sa taille. 1 pour des mesures illisibles.
function DisplaySize.TrophyFactor(height: any, side: any): number
	local h = if type(height) == "number" and height > 0 and height < math.huge then height else 0
	local s = if type(side) == "number" and side > 0 and side < math.huge then side else 0
	local reference = math.max(h, s * DisplaySize.Trophies.FlatShare)
	if not (reference > 0) then
		return 1
	end
	return math.max(1, DisplaySize.Trophies.BaseHeight / reference)
end

export type DisplaySize = typeof(DisplaySize)

return DeepFreeze(DisplaySize)
