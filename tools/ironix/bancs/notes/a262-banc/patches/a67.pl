# a262 (vague 76, 2026-11-19) : banc a67 (index v3). Formulas.ItemIncome prend l'objet ; le Yo-yo est Commun (raretés V0) ;
# un Secret a un seul revenu (150 000 $/s, plus de fourchette de zones).
if (has(q{local function income(zone, rarity)})) {
	lit(q{local function income(zone, rarity)
	return `{Format.money(Formulas.ItemIncome(zone, rarity))}/s`}, q{local function income(itemId)
	return `{Format.money(Formulas.ItemIncome(itemId))}/s`}, 'income');
	lit(q{textOf(detail, "DetailIncome") == income(1, "Common")}, q{textOf(detail, "DetailIncome") == income("Z1_CanetteDeSoda")}, 'soda');
	lit(q{textOf(detail, "DetailRarity") == "Uncommon" and textOf(detail, "DetailIncome") == income(2, "Uncommon")}, q{textOf(detail, "DetailRarity") == "Common" and textOf(detail, "DetailIncome") == income("Z2_YoYo")}, 'yoyo');
	lit(q{check(sameColor(detail.DetailRarity.TextColor3, Rarities.ById.Uncommon.Color:Lerp(}, q{check(sameColor(detail.DetailRarity.TextColor3, Rarities.ById.Common.Color:Lerp(}, 'yoyo couleur');
	lit(q{local low = Format.money(Formulas.ItemIncome(1, "Secret"))
local high = Format.money(Formulas.ItemIncome(#Zones, "Secret"))
check(textOf(detail, "DetailIncome") == `{low}-{high}/s`, `Secret : revenu de la zone 1 à la 6}, q{local low = Format.money(Formulas.ItemIncome("Secret_ChatPorteBonheurDore"))
check(textOf(detail, "DetailIncome") == `{low}/s`, `Secret : un seul revenu (a262)}, 'secret');
}
lit(q{	exposed += Formulas.ItemIncome(1, "Common")}, q{	exposed += Formulas.ItemIncome("Z1_Carotte")}, 'carotte') if has(q{	exposed += Formulas.ItemIncome(1, "Common")});
