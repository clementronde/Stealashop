--!strict
-- Taille d'affichage des objets exposés par rareté (a459, liaison L-354, demande de Clément du 2026-11-24 après
-- comparaison avec les jeux du genre). Lu par DisplayService (côté serveur) ; le socle du plus rare (RarestDisplay,
-- VfxController) montre la même taille, sans la réduction du présentoir (attribut FitScale, comme avant).
--
-- Règle : sur un présentoir, la plus grande dimension de l'objet (pièces visibles) est mise à la taille de sa rareté,
-- de Min à Max studs. a459b (L-367, décision de Cantin du 25/11) : c'est la taille réelle de son modèle qui le place
-- dans cette fourchette, plus son poids. Taille réelle = plus grande dimension des pièces visibles du modèle ITM_
-- d'origine, avant toute mise à l'échelle. DisplayService la compare à celle du plus petit et du plus grand ITM_ livrés
-- de la même rareté (Config/Items, catalogue actif) : le plus petit va à Min, le plus grand à Max, les autres entre les
-- deux selon leur taille relative (échelle logarithmique : un modèle deux fois plus grand que le plus petit monte
-- d'autant qu'un modèle deux fois plus petit que le plus grand descend), bornée à [Min, Max]. Le poids ne change plus
-- la taille exposée (il reste écrit dans BB_Item/Weight et sert ailleurs, Config/Weight).
-- Ensuite, comme avant, l'objet est réduit pour tenir dans le FitSize de son présentoir (6,5 × 12,5 × 6, hauteur du
-- flottement retirée) et jamais au-delà de Weight.DisplayMaxScale. Aucun ITM n'est réexporté : c'est une échelle
-- d'affichage. L'objet porté, en main, au sol et à l'ouverture du colis gardent la taille de leur poids (Config/Weight).
--
-- Interrupteurs : Features.DisplayRaritySize (partout, PROD compris) et Features.DisplayRaritySizeDev (jeu DEV seulement,
-- Config/ProductIds.IsDev). Coupé : la taille du poids, comme avant (Weight.ScaleCurve, puis FitSize).
--
-- Origine des valeurs : « Clément » = L-354 ; V0 = proposé par a459 ou a459b, absent du doc.
-- Unités : studs.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Rarities = require(script.Parent.Rarities)

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
	Min: number, -- studs, plus grande dimension montrée du plus petit modèle ITM_ de la rareté
	Max: number, -- studs, celle du plus grand
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
	-- a459b (L-367) : place dans la fourchette (0 = Min, 1 = Max) d'un objet seul de sa rareté, quand tous les modèles
	-- de sa rareté ont la même taille ou quand aucun n'est mesurable (V0 : le milieu).
	SinglePosition = 0.5,
}

local function valid(x: any): boolean
	return type(x) == "number" and x == x and x > 0 and x < math.huge
end

-- a459b (L-367) : place (de 0 à 1) dans la fourchette d'un modèle dont la plus grande dimension réelle est `side`
-- studs, quand le plus petit modèle livré de sa rareté mesure `smallest` et le plus grand `largest` (échelle
-- logarithmique, bornée à [0, 1]). SinglePosition si l'écart est nul ou illisible. Ne dépend pas du poids.
function DisplaySize.PositionFor(side: any, smallest: any, largest: any): number
	if not (valid(side) and valid(smallest) and valid(largest)) or not (largest > smallest) then
		return DisplaySize.SinglePosition
	end
	local t = math.log(math.clamp(side, smallest, largest) / smallest) / math.log(largest / smallest)
	return math.clamp(t, 0, 1)
end

-- Taille visée (studs, plus grande dimension) d'un objet de rareté `rarityId` placé à `position` (0 = Min, 1 = Max,
-- bornée) dans sa fourchette ; nil pour une rareté inconnue. Une place illisible compte comme SinglePosition.
function DisplaySize.TargetAt(rarityId: any, position: any): number?
	local range = if type(rarityId) == "string" then (BY_RARITY :: any)[rarityId] :: Range? else nil
	if range == nil then
		return nil
	end
	local t = if type(position) == "number" and position == position
		then math.clamp(position, 0, 1)
		else DisplaySize.SinglePosition
	return range.Min + (range.Max - range.Min) * t
end

export type DisplaySize = typeof(DisplaySize)

return DeepFreeze(DisplaySize)
