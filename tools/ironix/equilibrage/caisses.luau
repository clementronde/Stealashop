--!nocheck
-- Rareté de l'objet tirée à l'ouverture, dans la table de la caisse (liaison L-122, vague 32, agent a108).
-- Règle de Cantin (2026-11-13) : la rareté posée sur le rayon (ShelfBoxes.ZoneOdds / Rarities.BoxOdds)
-- devient celle de la CAISSE ; à l'ouverture, la rareté de l'objet est tirée dans
-- BoxRarityOdds[rareté de la caisse], après que la chance tirée (LuckTable) a multiplié certains poids
-- (règle LuckBoost), puis normalisation. Remplace les crans de la vague 31 (Outil/chance, mode Infini).
--
-- Rien ici n'est dans le jeu : `Proposees` est une PROPOSITION, à coller dans
-- src/shared/Config/ShelfOpen.luau (BoxRarityOdds) après l'accord de Clément. Si le jeu a déjà ses
-- BoxRarityOdds, `Caisses.Modes().Jeu` les lit.
--
-- Utilisé par rapport.luau (section 13) et, par l'accroche Modele.Ouverture, par les parties simulées.

local Chance = charge("Outil/chance")
local Rarities = Config.Rarities
local ShelfOpen = Config.ShelfOpen
local ShelfBoxes = Config.ShelfBoxes

local Caisses = {}

-- PROPOSÉ (a108) : BoxRarityOdds[rareté de la caisse][rareté de l'objet], en pour cent (chaque ligne
-- fait 100). Forme : environ 57 % de la rareté de la caisse, puis 20 %, 8 %, 3 %, 2 %, 1 %, 0,5 % en
-- descendant, et 9 %, 2 %, 0,3 %, 0,05 %, 0,008 % en montant, coupé aux bords et ramené à 100. La caisse
-- Commune est à part (plus serrée : c'est toute la zone 1). Divine : 0 tant que le catalogue n'a aucun
-- objet Divine ; la caisse Divine n'est jamais posée (Rarities.BoxOdds.Divine = 0 partout).
Caisses.Proposees = {
	Common = { Common = 88.841, Uncommon = 9, Rare = 1.8, Epic = 0.3, Legendary = 0.05, Mythic = 0.008, Secret = 0.001, Divine = 0 },
	Uncommon = { Common = 23, Uncommon = 64.29, Rare = 10, Epic = 2.3, Legendary = 0.34, Mythic = 0.06, Secret = 0.01, Divine = 0 },
	Rare = { Common = 8.3, Uncommon = 21, Rare = 58.94, Epic = 9.3, Legendary = 2.1, Mythic = 0.31, Secret = 0.05, Divine = 0 },
	Epic = { Common = 3, Uncommon = 8, Rare = 20, Epic = 57.6, Legendary = 9.1, Mythic = 2, Secret = 0.3, Divine = 0 },
	Legendary = { Common = 2, Uncommon = 3, Rare = 8, Epic = 20, Legendary = 56, Mythic = 9, Secret = 2, Divine = 0 },
	Mythic = { Common = 1, Uncommon = 2, Rare = 3, Epic = 8, Legendary = 20, Mythic = 57, Secret = 9, Divine = 0 },
	Secret = { Common = 0.5, Uncommon = 1, Rare = 2, Epic = 3.5, Legendary = 8.5, Mythic = 22, Secret = 62.5, Divine = 0 },
	Divine = { Common = 0.5, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 3.5, Mythic = 8, Secret = 22, Divine = 60 },
}

-- Règles de la chance (LuckBoost). `luck` multiplie les poids de :
--   "AboveLowest" (contrat de la vague 32) : toutes les raretés sauf la plus basse de la table ;
--   "AboveBox"    (proposé, a108) : les raretés au-dessus de celle de la caisse ; si aucune n'a de poids
--                 (caisse Secret tant qu'il n'y a pas de Divine), la rareté de la caisse elle-même.
-- Puis normalisation. Renvoie { [RarityId] = probabilité }.
function Caisses.Booste(cotes, boxId, luck, regle)
	local boxOrder = Rarities.ById[boxId].Order
	local lowest, above = nil, false
	for _, rarity in Rarities.List do
		local w = cotes[rarity.Id] or 0
		if w > 0 then
			lowest = lowest or rarity.Order
			if rarity.Order > boxOrder then
				above = true
			end
		end
	end
	local out, total = {}, 0
	for _, rarity in Rarities.List do
		local w = cotes[rarity.Id] or 0
		if w > 0 then
			local boosted
			if regle == "AboveLowest" then
				boosted = rarity.Order > lowest
			elseif above then
				boosted = rarity.Order > boxOrder
			else
				boosted = rarity.Order >= boxOrder
			end
			out[rarity.Id] = if boosted then w * luck else w
			total += out[rarity.Id]
		end
	end
	for id, w in out do
		out[id] = w / total
	end
	return out
end

-- Un « mode » : { Nom, Cotes (BoxRarityOdds), Regle, Table (LuckTable), Boost (Chance ×N Robux sur la
-- chance des cotes, pas sur le compteur ; défaut 1) }.
function Caisses.Modes()
	return {
		AboveLowest = { Nom = "Caisses proposées, AboveLowest", Cotes = Caisses.Proposees, Regle = "AboveLowest", Table = ShelfOpen.LuckTable },
		AboveBox = { Nom = "Caisses proposées, AboveBox (proposé)", Cotes = Caisses.Proposees, Regle = "AboveBox", Table = ShelfOpen.LuckTable },
		Jeu = if ShelfOpen.BoxRarityOdds
			then { Nom = `Dans le jeu ({ShelfOpen.LuckBoost or "AboveLowest"})`, Cotes = ShelfOpen.BoxRarityOdds, Regle = ShelfOpen.LuckBoost or "AboveLowest", Table = ShelfOpen.LuckTable }
			else nil,
	}
end

-- Répartition de la rareté de l'objet pour une caisse de rareté `boxId`, toutes chances mêlées (la police
-- arrête la montée : chance atteinte, comme Outil/chance).
function Caisses.ParCaisse(boxId, mode)
	local result = {}
	for _, line in Chance.Lignes({ Table = mode.Table }) do
		for id, q in Caisses.Booste(mode.Cotes[boxId], boxId, line.Atteinte * (mode.Boost or 1), mode.Regle) do
			result[id] = (result[id] or 0) + line.Proba * q
		end
	end
	return result
end

-- Répartition finale d'un colis (zone, type) : rareté de la caisse (ShelfBoxes.OddsFor), puis table.
function Caisses.Repartition(zone, tier, mode)
	local result = {}
	for boxId, share in ShelfBoxes.OddsFor(zone, tier) do
		if share > 0 then
			for id, q in Caisses.ParCaisse(boxId, mode) do
				result[id] = (result[id] or 0) + share / 100 * q
			end
		end
	end
	return result
end

-- Rang moyen de la rareté (1 = Commun … 7 = Secret).
function Caisses.Rang(repartition)
	local rank = 0
	for id, q in repartition do
		rank += q * Rarities.ById[id].Order
	end
	return rank
end

-- Accroche pour Modele.Ouverture (même forme que Chance.Accroche) : la rareté reçue est celle de la
-- caisse ; la rareté de l'objet est tirée à l'ouverture. Un contenu imposé (colis du tuto) ne change pas.
function Caisses.Accroche(mode)
	return function(random, zone, tier, boxId, imposed)
		local luck = Chance.Tirer(random, mode.Table)
		local issue = Chance.Issue(luck)
		local final = boxId
		if not imposed then
			local roll = random()
			final = nil
			for _, rarity in Rarities.List do
				local q = Caisses.Booste(mode.Cotes[boxId], boxId, issue.Atteinte * (mode.Boost or 1), mode.Regle)[rarity.Id] or 0
				if roll < q then
					final = rarity.Id
					break
				end
				roll -= q
			end
			final = final or boxId
			-- Rareté sans objet tirable (Divine aujourd'hui) : la plus proche en dessous (repli du jeu).
			while #(Config.Items.AllZones[final] or { 1 }) == 0 do
				final = Rarities.List[Rarities.ById[final].Order - 1].Id
			end
		end
		return final, ShelfOpen.AntiTheft[final], issue.Delai, issue.Police
	end
end

return Caisses
