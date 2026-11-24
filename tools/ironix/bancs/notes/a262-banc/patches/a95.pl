# a262 (vague 76, 2026-11-19) : banc a95 (receleur). Formulas.ItemIncome prend l'objet : prix de la Canette, du Paquet de
# chips doré et du Pot de nouilles.
return unless has(q{local pSoda, pChips, pNoodles = price(1, "Common")});
lit(q{local function price(zone, rarity, mutation)
	return math.floor(120 * Formulas.ItemIncome(zone, rarity) * Mutations.IncomeMultiplier(mutation))}, q{local function price(itemId, mutation)
	return math.floor(120 * Formulas.ItemIncome(itemId) * Mutations.IncomeMultiplier(mutation))}, 'price');
lit(q{local pSoda, pChips, pNoodles = price(1, "Common"), price(1, "Common", { Effect = "Gold" }), price(1, "Rare")}, q{local pSoda, pChips, pNoodles = price("Z1_CanetteDeSoda"), price("Z1_PaquetDeChips", { Effect = "Gold" }), price("Z1_PotDeNouilles")}, 'prix');
