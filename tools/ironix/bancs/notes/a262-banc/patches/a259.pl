# a262 (vague 76, 2026-11-20) : banc a259 (ouverture du colis). Formulas.UnboxOdds(chance) : la cote « 1 IN N » est
# 1 / la vraie chance de l'objet (Shared/ItemOdds), arrondie lisiblement (entier sous 100, 2 chiffres significatifs
# au-delà) ; elle ne dépend plus des poids de la caisse ni du nombre d'objets de la rareté.
if (has(q|"R1 cote = total des poids / poids de la rareté × objets de la rareté (50, 5, 3)"|)) {
	$t =~ s/check\(Formulas\.UnboxOdds\(w, "Epic", 5\) == 50.*?"R3 bornée de 1 à 999 999 999"\)/A262_R1_R3/s or die "a262 : R1-R3 introuvables\n";
	lit(q|A262_R1_R3|, q|check(Formulas.UnboxOdds(0.02) == 50 and Formulas.UnboxOdds(1 / 3) == 3 and Formulas.UnboxOdds(1 / 12345) == 12000, "R1 a262 : cote = 1 / vraie chance, arrondie (50, 3, 12 000)")
check(Formulas.UnboxOdds(0) == nil and Formulas.UnboxOdds(0 / 0) == nil and Formulas.UnboxOdds(-1) == nil and Formulas.UnboxOdds(2) == nil, "R2 a262 : chance nulle, NaN, négative ou au-dessus de 1 : nil")
check(Formulas.UnboxOdds(1) == 1 and Formulas.UnboxOdds(1 / 23456789) == 23000000 and Formulas.UnboxOdds(1e-9) == 1e9, "R3 a262 : 1 au plus bas, 2 chiffres significatifs au-delà de 100")|, 'R1-R3');
}
if (has(q|"V4 a259 (L-262) : cote finale = vraie chance de l'objet|)) {
	lit(q|plan.Odds == math.floor(plan.Odds) and plan.Odds >= pool, "V4 a259 (L-262) : cote finale = vraie chance de l'objet, entière, au moins le nombre d'objets de sa rareté ("|, q|plan.Odds == math.floor(plan.Odds) and plan.Odds == sharedModule("ItemOdds").OneIn(a[4], nil), "V4 a262 : cote finale = ItemOdds.OneIn de l'objet, sans mutation ni classe de taille ("|, 'V4');
}
