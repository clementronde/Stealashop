# a262 (vague 76, 2026-11-19) : banc a48 (gains hors ligne). Formulas.ItemIncome prend l'objet (rareté, zone et rang).
lit(q{	return Formulas.ItemIncome(def.Zone or zone or 1, def.Rarity)}, q{	return Formulas.ItemIncome(def.Id)}, 'incomeOf') if has(q{function incomeOf(itemId, zone)});
# Revenus non entiers : la caisse reçoit un montant entier (arrondi en dessous, moins de 1 $ d'écart).
lit(q{check(#credits == 1 and near(credits[1].amount, absence * exposed), `retour :}, q{check(#credits == 1 and credits[1].amount <= absence * exposed and credits[1].amount > absence * exposed - 1, `retour (a262 : montant entier) :}, 'caisse') if has(q{near(credits[1].amount, absence * exposed), `retour :});
