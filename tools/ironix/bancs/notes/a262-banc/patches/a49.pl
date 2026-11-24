# a262 (vague 76, 2026-11-19) : banc a49 (mutations). Formulas.ItemIncome prend l'objet ; revenus de la vague 76 : Canette
# Big Gold 4, Paquet de chips 1,331, Pot de nouilles 60 (Ada 65,331) ; Banane 1,771561 (Bob avec la canette : 5,771561).
inc('near');
lit(q{Formulas.ItemIncome(2, "Rare")}, q{Formulas.ItemIncome("Z3_ConsoleDeSalon")}, 'config', 1) if has(q{Formulas.ItemIncome(2, "Rare")});
if (has(q{revenu d'Ada : 4 + 1 + 5 = 10 $/s})) {
	lit(q{check(ada:GetAttribute("Income") == 10, `revenu d'Ada : 4 + 1 + 5 = 10 $/s}, q{check(A262_NEAR(ada:GetAttribute("Income"), 65.331), `revenu d'Ada : 4 + 1,331 + 60 = 65,331 $/s}, 'ada');
	lit(q{check(ada:GetAttribute("Income") == 10, `échec : Ada retrouve ses 10 $/s}, q{check(A262_NEAR(ada:GetAttribute("Income"), 65.331), `échec : Ada retrouve ses 65,331 $/s}, 'ada échec');
	lit(q{check(bob:GetAttribute("Income") == 5, `revenu de Bob : 1 + 4 = 5 $/s}, q{check(A262_NEAR(bob:GetAttribute("Income"), 5.771561), `revenu de Bob : 1,771561 + 4 $/s}, 'bob');
}
