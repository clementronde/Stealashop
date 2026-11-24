# a262 (vague 76) : patch partagé des bancs de la réserve et des présentoirs (a51, a191, a219, a242). Plus d'objet
# Épique en zone 3 (Rarities.ZoneOdds : Épique dès la zone 4) : « un Épique de la zone 3 » devient celui de la zone 4
# (il rapporte toujours le plus). Formulas.ItemIncome prend l'objet : revenu de l'objet de test lui-même.
if (has(q{pick(3, "Epic")})) {
	lit(q{pick(3, "Epic")}, q{pick(4, "Epic")}, 'Épique de zone 3', 1);
	lit(q{Formulas.ItemIncome(3, "Epic")}, q{Formulas.ItemIncome(E3)}, 'revenu E3', 1) if has(q{Formulas.ItemIncome(3, "Epic")});
}
lit(q{Formulas.ItemIncome(2, "Uncommon")}, q{Formulas.ItemIncome(U1)}, 'revenu U1', 1) if has(q{local C1, U1, R3}) && has(q{Formulas.ItemIncome(2, "Uncommon")});
lit(q{Formulas.ItemIncome(3, "Rare")}, q{Formulas.ItemIncome(R3)}, 'revenu R3', 1) if has(q{pick(3, "Rare")}) && has(q{Formulas.ItemIncome(3, "Rare")});
lit(q{Formulas.ItemIncome(def.Zone or zone or 1, def.Rarity)}, q{Formulas.ItemIncome(def.Id)}, 'revenu def', 1) if has(q{Formulas.ItemIncome(def.Zone or zone or 1, def.Rarity)});
lit(q{a219Pick(3, "Epic")}, q{a219Pick(4, "Epic")}, 'Épique de zone 3 (a219)', 1) if has(q{a219Pick(3, "Epic")});
