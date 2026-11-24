# a262 (vague 76, 2026-11-19) : banc a29 (vol entre joueurs). Revenus de la vague 76 (Formulas.ItemIncome : rareté, zone
# et rang) : Canette 1, Paquet de chips 1,331, Donut 1,4641, Banane 1,771561, Pot de nouilles 60, Robot jouet (Peu commun
# de zone 2, rang 5) 11,7128 $/s. Ada : 62,331 (63,7951 avec le donut) ; Bob avec la canette : 2,771561.
return unless has(q{addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)});
inc('near');
if (has(q{revenu d'Ada : 7 $/s})) {
	lit(q{check(ada:GetAttribute("Income") == 7, `revenu d'Ada : 7 $/s}, q{check(A262_NEAR(ada:GetAttribute("Income"), 62.331), `revenu d'Ada : 62,331 $/s (a262)}, 'ada 7');
	lit(q{check(panel.Income == "+$7/s", `panneau : valeur exposée « +$7/s »}, q{check(panel.Income == "+$62.3/s", `panneau : valeur exposée « +$62.3/s »}, 'panneau 7');
	lit(q{gui:FindFirstChild("Income").Text == "+$7/s"}, q{gui:FindFirstChild("Income").Text == "+$62.3/s"}, 'textes');
	lit(q{check(ada:GetAttribute("Income") == 6, `fuite : l'objet ne rapporte plus à Ada (6 $/s}, q{check(A262_NEAR(ada:GetAttribute("Income"), 61.331), `fuite : l'objet ne rapporte plus à Ada (61,331 $/s}, 'ada 6');
	lit(q{check(bob:GetAttribute("Income") == 2, `il rapporte aussitôt : 2 $/s}, q{check(A262_NEAR(bob:GetAttribute("Income"), 2.771561), `il rapporte aussitôt : 2,771561 $/s}, 'bob 2');
	lit(q{check(after and after.Income == "+$6/s", "panneau : la valeur exposée d'Ada a baissé (+$6/s)")}, q{check(after and after.Income == "+$61.3/s", "panneau : la valeur exposée d'Ada a baissé (+$61.3/s)")}, 'panneau 6');
}
if (has(q{il rapporte de nouveau (8 $/s})) {
	lit(q{check(ada:GetAttribute("Income") == 8, `{label} : il rapporte de nouveau (8 $/s}, q{check(A262_NEAR(ada:GetAttribute("Income"), 63.7951), `{label} : il rapporte de nouveau (63,7951 $/s}, 'fails 8');
	lit(q{check(ada:GetAttribute("Income") == 7, "pendant la fuite : 7 $/s chez Ada")}, q{check(A262_NEAR(ada:GetAttribute("Income"), 62.7951), "pendant la fuite : 62,7951 $/s chez Ada")}, 'fails 7');
	lit(q{check(ada2:GetAttribute("Income") == 8, `ses 4 objets rapportent (8 $/s}, q{check(A262_NEAR(ada2:GetAttribute("Income"), 63.7951), `ses 4 objets rapportent (63,7951 $/s}, 'fails 8b');
}
if (has(q{revenus : Dan 120 $/s, Ada 7 $/s})) {
	lit(q{check(dan:GetAttribute("Income") == 120 and ada:GetAttribute("Income") == 7, `revenus : Dan 120 $/s, Ada 7 $/s}, q{check(A262_NEAR(dan:GetAttribute("Income"), 11.7128) and A262_NEAR(ada:GetAttribute("Income"), 62.7951), `revenus : Dan 11,7128 $/s, Ada 62,7951 $/s}, 'dan');
}
