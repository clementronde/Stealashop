# a262 (vague 76, 2026-11-20) : banc a199 (tuto court). Revenu du Pot de nouilles (Rare du tuto, zone 1) : 60 $/s
# (Rarities.Rare.Income, Formulas.ItemIncome) au lieu de 5 $/s.
lit(q{local income = Zones[1].BaseIncome * Rarities.ById.Rare.IncomeMultiplier}, q{local income = Rarities.ById.Rare.Income -- a262 : Pot de nouilles, 60 $/s (vague 76)}, 'revenu du tuto') if has(q{local income = Zones[1].BaseIncome * Rarities.ById.Rare.IncomeMultiplier});
