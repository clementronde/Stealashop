# a262 (vague 76, 2026-11-20) : banc a79 (colis et camions par rareté). Un colis du rayon n'a plus de type : son
# modèle est BOX_<Rareté>, sinon le bloc V0 ; le repli BOX_<Tier> ne sert plus qu'aux colis qui gardent un type
# (camion). S4 vérifie donc qu'aucun colis du rayon ne prend BOX_<Tier> (S2 vérifie toujours chaque colis).
if (has(q{S4 repli sur BOX_<Tier> pour une rareté pas livrée})) {
	lit(q{check(byTier >= 1, `S4 repli sur BOX_<Tier> pour une rareté pas livrée (Commun en Premium : {byTier})`)}, q{check(byTier == 0, `S4 a262 : plus de repli BOX_<Tier> sur le rayon, colis sans type ({byTier})`)}, 'S4');
}
