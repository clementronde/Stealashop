--!strict
-- Taille d'affichage des objets exposés : un minimum par rareté (a459, liaison L-354, demande de Clément du 2026-11-24 ;
-- a459b, L-367, règle de Cantin du 25/11 : « ça ne devrait pas être cappé pour le maximum, mais pour le minimum oui »).
-- Lu par DisplayService (côté serveur) ; le socle « BEST ITEM » (RarestDisplay, VfxController) montre la même taille.
--
-- Règle : sur un présentoir, l'objet garde la vraie taille de son modèle ITM_ (sa plus grande dimension, pièces
-- visibles, telle que livrée). S'il est plus petit que le minimum de sa rareté, il est agrandi jusqu'à ce minimum ; il
-- n'est jamais réduit (ni par la rareté, ni par le FitSize du présentoir). Le poids ne change pas la taille exposée
-- (il reste écrit dans BB_Item/Weight et garde la taille au sol, portée, en main et à l'ouverture du colis,
-- Config/Weight). Aucun ITM n'est réexporté : c'est une échelle d'affichage. Chaque objet est traité seul : les autres
-- modèles de sa rareté (exclusifs de la caisse compris) ne changent rien à sa taille.
--
-- Interrupteurs : Features.DisplayRaritySize (partout, PROD compris) et Features.DisplayRaritySizeDev (jeu DEV seulement,
-- Config/ProductIds.IsDev). Coupé : comme avant (taille du poids, Weight.ScaleCurve, puis réduction FitSize).
--
-- Origine des valeurs : « Clément » = bas des fourchettes de L-354 ; Divin : Cantin (25/11), comme Mythique et Secret.
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

local DisplaySize = {
	-- Allumé partout (DisplayRaritySize) ou dans le jeu DEV seulement (DisplayRaritySizeDev et ProductIds.IsDev).
	Enabled = Features.DisplayRaritySize == true or (Features.DisplayRaritySizeDev == true and ProductIds.IsDev == true),
	MinByRarity = MIN_BY_RARITY,
}

-- Plus grande dimension minimale (studs) d'un objet de rareté `rarityId` ; nil pour une rareté inconnue.
function DisplaySize.MinFor(rarityId: any): number?
	return if type(rarityId) == "string" then (MIN_BY_RARITY :: any)[rarityId] :: number? else nil
end

export type DisplaySize = typeof(DisplaySize)

return DeepFreeze(DisplaySize)
