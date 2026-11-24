# a262 (vague 76, 2026-11-20) : banc a158 (fin du colis porté). Raretés du catalogue réattribuées (vague 76) : le
# Smartphone est Peu commun ; l'objet volé du banc devient la Console de salon, Rare de la zone 3 (StartCarry vérifie
# que la rareté du colis est celle de l'objet).
if (has(q|ItemId = "Z3_Smartphone", Rarity = "Rare", Income = 12400|)) {
	lit(q|ItemId = "Z3_Smartphone", Rarity = "Rare", Income = 12400|, q|ItemId = "Z3_ConsoleDeSalon", Rarity = "Rare", Income = 12400|, 'objet volé');
}
