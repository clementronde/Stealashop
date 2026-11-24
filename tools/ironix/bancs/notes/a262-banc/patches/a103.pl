# a262 (vague 76, 2026-11-19) : banc a103 (ouverture sur le rayon). Formulas.ItemIncome prend l'objet.
lit(q{local income = Formulas.ItemIncome(def.Zone or 1, def.Rarity) * Mutations}, q{local income = Formulas.ItemIncome(def.Id) * Mutations}, 'income') if has(q{local income = Formulas.ItemIncome(def.Zone or 1, def.Rarity) * Mutations});
