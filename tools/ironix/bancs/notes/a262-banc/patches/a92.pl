# a262 (vague 76, 2026-11-20) : banc a92 (rareté Divine). Config/Rarities : IncomeMultiplier devient Income ($/s de
# base de la rareté, Formulas.ItemIncome) ; le Divine reste à 5 × le Secret et toujours au-dessus des autres.
if (has(q{A4 V0 : ×5 000 (5 × Secret)})) {
	lit(q{divine.IncomeMultiplier == 5 * secret.IncomeMultiplier}, q{divine.Income == 5 * secret.Income}, 'A4');
	lit(q{b.IncomeMultiplier > a.IncomeMultiplier}, q{b.Income > a.Income}, 'monotone', 1);
}
# B4 : le Secret n'existe plus qu'en zone 6 (Rarities.ZoneOdds) : Items.Pick le rend en zone 6, nil ailleurs.
if (has(q{B4 Items.Pick(zone, \"Secret\") rend toujours le Secret})) {
	lit(q{secretEverywhere = secretEverywhere and s ~= nil and s.Rarity == "Secret"}, q{secretEverywhere = secretEverywhere and (if zone == 6 then s ~= nil and s.Rarity == "Secret" else s == nil) -- a262}, 'B4');
	lit(q{"B4 Items.Pick(zone, \"Secret\") rend toujours le Secret (inchangé)"}, q{"B4 a262 : Items.Pick(zone, \"Secret\") rend le Secret en zone 6, nil ailleurs"}, 'B4 texte');
}
# C1 : Formulas.ItemIncome prend un objet du catalogue (aucun Divine au catalogue) : le rapport se lit sur Config/Rarities.
if (has(q{C1 ItemIncome(3, Divine) = 5 × ItemIncome(3, Secret)})) {
	lit(q{near(Formulas.ItemIncome(3, "Divine"), 5 * Formulas.ItemIncome(3, "Secret"))}, q{near(Rarities.ById.Divine.Income, 5 * Rarities.ById.Secret.Income)}, 'C1');
}
