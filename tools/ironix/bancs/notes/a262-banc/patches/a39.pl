# a262 (vague 76, 2026-11-20) : banc a39 (renaissances). Config/Rebirths reprend la rareté et la zone de chaque objet
# demandé dans Config/Items (raretés du catalogue réattribuées par la vague 76) : Diamant géant et Trône en or
# Légendaires, Statue de la Liberté Mythique, Peluche géante Peu commune, PC gamer Rare, Couronne Épique, Masque
# ancien Légendaire, Coffre de diamants et Clé du coffre ultime Mythiques. Le Diamant géant (palier 1) est donc
# « LEGENDARY » : le texte de Rarity change avec lui (l'écran de Clément montrait « RARE » ; seul le texte change).
if (has(q|"Z6_DiamantGeant", "Rare", 6,|)) {
	lit(q|"Z6_DiamantGeant", "Rare", 6,|, q|"Z6_DiamantGeant", "Legendary", 6,|, 'palier 1');
	lit(q|"Z6_TroneEnOr", "Epic", 6,|, q|"Z6_TroneEnOr", "Legendary", 6,|, 'palier 2');
	lit(q|"Z6_StatueDeLaLiberte", "Epic", 6,|, q|"Z6_StatueDeLaLiberte", "Mythic", 6,|, 'palier 3');
	lit(q|"Z2_PelucheGeante", "Legendary", 2,|, q|"Z2_PelucheGeante", "Uncommon", 2,|, 'palier 4');
	lit(q|"Z3_PcGamer", "Legendary", 3,|, q|"Z3_PcGamer", "Rare", 3,|, 'palier 5');
	lit(q|"Z4_Couronne", "Legendary", 4,|, q|"Z4_Couronne", "Epic", 4,|, 'palier 6');
	lit(q|"Z6_CoffreDeDiamants", "Legendary", 6,|, q|"Z6_CoffreDeDiamants", "Mythic", 6,|, 'palier 8');
	lit(q|check(el("ItemRequirement.Rarity").Text == "RARE", "Rarity : RARE")|, q|check(el("ItemRequirement.Rarity").Text == "LEGENDARY", "Rarity : LEGENDARY (a262)")|, 'Rarity');
	lit(q|	[el("Hint")] = { Text = true },
|, q|	[el("Hint")] = { Text = true },
	[el("ItemRequirement.Rarity")] = { Text = true }, -- a262 : Diamant géant Légendaire (vague 76)
|, 'allowed');
	lit(q|rebirthEl(lower, "ItemRequirement.Rarity").Text == "Rare", "Giant Diamond, Rare")|, q|rebirthEl(lower, "ItemRequirement.Rarity").Text == "Legendary", "Giant Diamond, Legendary (a262)")|, 'minuscules');
}
