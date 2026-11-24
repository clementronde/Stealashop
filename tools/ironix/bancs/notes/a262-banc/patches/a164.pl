# a262 (vague 76, 2026-11-19) : banc a164 (renaissance). Formulas.ItemIncome prend l'objet.
lit(q{	return Config.Formulas.ItemIncome(zone or def.Zone, def.Rarity) * Config.Mutations.IncomeMultiplier(mutation)}, q{	return Config.Formulas.ItemIncome(def.Id) * Config.Mutations.IncomeMultiplier(mutation)}, 'incomeOf') if has(q{function incomeOf(id, zone, mutation)});
