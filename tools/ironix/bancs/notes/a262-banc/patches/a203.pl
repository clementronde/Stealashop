# a262 (vague 76, 2026-11-20) : banc a203 (poids des objets), point 11. Shared/ItemOdds donne la VRAIE chance :
# moyenne sur la chance du joueur (ShelfOpen.LuckTable) et « sans mutation » = ni Huge ni Colossal. Pour un Commun de
# la zone 1 (colis et contenu toujours Communs), Huge / sans taille = Σ poids × SizeChance(Huge, chance)
# / Σ poids × (100 − Huge − Colossal), chances de la table.
if (has(q|"ItemOdds : P(Huge) = chance du palier de poids"|)) {
	lit(q|		local base = ItemOdds.Chance(itemId, nil, box)
		local huge = ItemOdds.Chance(itemId, { Size = "Huge" }, box)
		check(near(huge, base * ItemWeight.SizeChance("Huge", 1) / 100, 1e-15), "ItemOdds : P(Huge) = chance du palier de poids")|, q|		for _, item in Items.List do -- a262 : un Commun de la zone 1
			if item.Zone == 1 and item.Rarity == "Common" and not item.TutorialOnly then itemId = item.Id break end
		end
		local base = ItemOdds.Chance(itemId, nil)
		local huge = ItemOdds.Chance(itemId, { Size = "Huge" })
		local lucks = if ShelfOpen.Reveal.TableLuck then ShelfOpen.LuckTable else { { Luck = 1, Weight = 1 } }
		local sumHuge, sumNone = 0, 0
		for _, e in lucks do
			local l = math.max(e.Luck, 1)
			sumHuge += e.Weight * ItemWeight.SizeChance("Huge", l)
			sumNone += e.Weight * (100 - ItemWeight.SizeChance("Huge", l) - ItemWeight.SizeChance("Colossal", l))
		end
		check(huge ~= nil and base ~= nil and near(huge / base, sumHuge / sumNone, 1e-12), `ItemOdds a262 : P(Huge) = chance du palier de poids, moyenne sur la chance du joueur ({itemId})`)|, 'P(Huge)');
}
