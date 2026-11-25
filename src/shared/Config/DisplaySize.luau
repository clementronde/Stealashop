--!strict
-- Taille d'affichage des objets exposés par rareté (a459, liaison L-354, demande de Clément du 2026-11-24 après
-- comparaison avec les jeux du genre). Lu par DisplayService (côté serveur) ; le socle du plus rare (RarestDisplay,
-- VfxController) montre la même taille, sans la réduction du présentoir (attribut FitScale, comme avant).
--
-- Règle : sur un présentoir, la plus grande dimension de l'objet (pièces visibles) est mise à la taille de sa rareté,
-- de Min à Max studs ; le poids place l'objet dans cette fourchette (1 kg = Min, 10 000 kg = Max, droite en échelle
-- logarithmique du poids : 10 kg ≈ Min + 25 % de l'écart, 250 kg ≈ 60 %). Ensuite, comme avant, l'objet est réduit
-- pour tenir dans le FitSize de son présentoir (6,5 × 12,5 × 6, hauteur du flottement retirée) et jamais au-delà de
-- Weight.DisplayMaxScale. Aucun ITM n'est réexporté : c'est une échelle d'affichage. L'objet porté, en main, au sol
-- et à l'ouverture du colis gardent la taille de leur poids (Config/Weight).
--
-- Interrupteurs : Features.DisplayRaritySize (partout, PROD compris) et Features.DisplayRaritySizeDev (jeu DEV seulement,
-- Config/ProductIds.IsDev). Coupé : la taille du poids, comme avant (Weight.ScaleCurve, puis FitSize).
--
-- Origine des valeurs : « Clément » = L-354 ; V0 = proposé par a459, absent du doc.
-- Unités : studs, kg.

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

export type Range = {
	Min: number, -- studs, plus grande dimension de l'objet au poids le plus léger (Weight.Min)
	Max: number, -- studs, au poids le plus lourd (Weight.Max)
}

local BY_RARITY: { [Rarities.RarityId]: Range } = {
	Common = { Min = 4, Max = 5 }, -- Clément
	Uncommon = { Min = 4, Max = 5 }, -- Clément
	Rare = { Min = 4, Max = 5 }, -- Clément
	Epic = { Min = 5, Max = 6 }, -- Clément
	Legendary = { Min = 5, Max = 6 }, -- Clément
	Mythic = { Min = 7, Max = 9 }, -- Clément
	Secret = { Min = 7, Max = 9 }, -- Clément
	Divine = { Min = 7, Max = 9 }, -- V0 : comme Mythique et Secret (Clément n'a pas donné le Divin, aucun objet encore)
}

local DisplaySize = {
	-- Allumé partout (DisplayRaritySize) ou dans le jeu DEV seulement (DisplayRaritySizeDev et ProductIds.IsDev).
	Enabled = Features.DisplayRaritySize == true or (Features.DisplayRaritySizeDev == true and ProductIds.IsDev == true),
	ByRarity = BY_RARITY,
	-- Poids qui donnent Min et Max (V0 : tout l'écart des poids tirés, Config/Weight).
	WeightLow = Weight.Min,
	WeightHigh = Weight.Max,
}

-- Taille visée (studs, plus grande dimension) d'un objet de rareté `rarityId` qui pèse `kg` ; nil pour une rareté
-- inconnue. Un poids absent ou illisible compte comme Weight.Reference.
function DisplaySize.TargetFor(rarityId: any, kg: any): number?
	local range = if type(rarityId) == "string" then (BY_RARITY :: any)[rarityId] :: Range? else nil
	if range == nil then
		return nil
	end
	local weight = if type(kg) == "number" and kg == kg and kg > 0 and kg < math.huge then kg else Weight.Reference
	local low, high = DisplaySize.WeightLow, DisplaySize.WeightHigh
	local t = math.log(math.clamp(weight, low, high) / low) / math.log(high / low)
	return range.Min + (range.Max - range.Min) * t
end

export type DisplaySize = typeof(DisplaySize)

return DeepFreeze(DisplaySize)
