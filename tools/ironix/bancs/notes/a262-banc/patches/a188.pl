# a262 (vague 76, 2026-11-20) : banc a188 (pluie d'objets). Le contenu d'un colis suit ShelfOpen.BoxRarityOdds limité
# aux raretés de sa zone (Rarities.ZoneOdds) : en zone 1, tout objet tiré est Commun, quel que soit le tirage.
if (has(q|objet {want} (caisse Commune)|)) {
	lit(q|		local want = expectedAt(list, v)
|, q|		local want = "Common" -- a262 : zone 1, contenu limité aux Communs (vague 76)
|, 'D2');
}
