# a262 (vague 76, 2026-11-20) : banc a239 (annonce de nuit, premier braquage, mutations). Le Secret et le Mythique
# n'existent plus qu'en zone 6 (Rarities.ZoneOdds) : les deux magasins du banc deviennent la Banque et la Salle des
# coffres (zone 6, « Bank » et « Vault » dans Config/Zones). Chaque rayon tire sa rareté dans la zone (0,9999 : la plus
# haute, Secret) : ONE = 1 Secret par magasin, ALL = 10 Secrets par magasin (N3 : 20 colis ; N4c : 10).
# M2 : Tutorial.FirstBoxTier n'existe plus ; le premier colis du tuto est un Commun de zone 1 (0,3 s, Standard).
if (has(q{N4b une seule, au singulier})) {
	lit(q{local STORE_Z4 = buildStore("STORE_Z4_Bijouterie", 4, 130, 1)}, q{local STORE_Z4 = buildStore("STORE_Z6_Banque", 6, 130, 1) -- a262 : Secret : zone 6 seulement}, 'banque');
	lit(q{local STORE_Z5 = buildStore("STORE_Z5_GalerieDArt", 5, 130, -1)}, q{local STORE_Z5 = buildStore("STORE_Z6_SalleDesCoffres", 6, 130, -1) -- a262}, 'coffres');
	lit(q{string.find(text, "Jewelry", 1, true) or string.find(text, "Art Gallery", 1, true)}, q{string.find(text, "Bank", 1, true) or string.find(text, "Vault", 1, true)}, 'N2d');
	lit(q{"^8 rare boxes just appeared! Best: SECRET"}, q{"^20 rare boxes just appeared! Best: SECRET"}, 'N3');
	lit(q{"A SECRET box just appeared at Art Gallery!"}, q{"A SECRET box just appeared at Vault!"}, 'N4b');
	lit(q{"4 rare boxes just appeared! Best: SECRET at Jewelry"}, q{"10 rare boxes just appeared! Best: SECRET at Bank"}, 'N4c');
}
lit(q{tier = Tutorial.FirstBoxTier,}, q{tier = "Standard", -- a262 : FirstBoxTier retiré (vague 76), colis Commun du tuto}, 'M2') if has(q{tier = Tutorial.FirstBoxTier,});
