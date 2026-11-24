# a262 (vague 76, 2026-11-20) : banc a171 (couverture après a158 : a74, a76, a61, a51, a40, a55, a49, a38, a30, a146,
# a123). Formulas.ItemIncome prend l'objet (rareté, zone et rang) : chaque revenu attendu est celui de l'objet du
# scénario. Le Smartphone est devenu Peu commun : a61 lit sa rareté dans Config/Items (texte et couleur de la carte).
lit(q{Formulas.ItemIncome(def.Zone or 3, def.Rarity)}, q{Formulas.ItemIncome(def.Id)}, 'a74 slots') if has(q{Formulas.ItemIncome(def.Zone or 3, def.Rarity)});
if (has(q{addItem(data, "high", "Z3_Smartphone", nil, 3, 2) -- Rare zone 3, avec mutation})) {
	lit(q{local rare = Rarities.ById.Rare
check(cardPart(high, "Icon")}, q{local rare = Rarities.ById[Items.ById.Z3_Smartphone.Rarity] -- a262 : Peu commun depuis la vague 76
check(cardPart(high, "Icon")}, 'a61 rareté');
	lit(q{Formulas.ItemIncome(3, "Rare")}, q{Formulas.ItemIncome("Z3_Smartphone")}, 'a61 revenu', 1);
}
lit(q{near(inv["Item:high"].Income, Formulas.ItemIncome(3, "Rare"), 1e-3)}, q{near(inv["Item:high"].Income, Formulas.ItemIncome("Z3_Smartphone"), 1e-3)}, 'a51 revenu') if has(q{near(inv["Item:high"].Income, Formulas.ItemIncome(3, "Rare"), 1e-3)});
lit(q{expected += Formulas.ItemIncome(zone, item.Rarity)}, q{expected += Formulas.ItemIncome(item.Id)}, 'a55 revenu') if has(q{expected += Formulas.ItemIncome(zone, item.Rarity)});
lit(q{local base = Formulas.ItemIncome(2, "Common")}, q{local base = Formulas.ItemIncome("Z2_CanardEnPlastique")}, 'a49 stand') if has(q{local base = Formulas.ItemIncome(2, "Common")});
# a74/slots : l'objet et le colis du scénario sont des Smartphones (Peu commun depuis la vague 76) : leur couleur.
lit(q{section("couleur de rareté")
local rare = Rarities.ById.Rare.Color}, q{section("couleur de rareté")
local rare = Rarities.ById[Items.ById.Z3_Smartphone.Rarity].Color -- a262 : Smartphone Peu commun (vague 76)}, 'a74 couleur') if has(q{"objet Rare : Clip assombri de 45 %, Glow à la couleur"});
