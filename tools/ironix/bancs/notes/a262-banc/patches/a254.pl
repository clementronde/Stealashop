# a262 (vague 76, 2026-11-20) : banc a254 (annonces au serveur, UI_Announce). Les raretés suivent la zone : le
# Secret et le Mythique n'existent plus qu'en zone 6 (Rarities.ZoneOdds). Le magasin de zone 4 du banc devient la
# Banque (zone 6) : chaque rayon tire sa rareté dans la zone (0,9999 : la plus haute, Secret ; 0,997 : Mythique ;
# 0 : la plus basse). A1 : Secret de la Banque + Légendaire de la Galerie d'art : « 2 rare boxes … Best: SECRET »,
# détail de la zone 6. A2 : deux Mythiques à la Banque (la Galerie d'art tire des Légendaires, sous le seuil de jour).
if (has(q{A1d detail : })) {
	lit(q{local STORE_Z4 = buildStore("STORE_Z4_Bijouterie", 4, 130, 1)}, q{local STORE_Z4 = buildStore("STORE_Z6_Banque", 6, 130, 1) -- a262 : Secret et Mythique : zone 6 seulement}, 'banque');
	lit(q{local MYTHIC = { 0, 0.9999, 0, 0, 0, 0, 0, 0, 0, 0 }}, q{local MYTHIC = { 0, 0.997, 0.997, 0, 0, 0, 0, 0, 0, 0 } -- a262 : 2 Mythiques à la Banque}, 'mythic');
	lit(q{string.find(detail, "^Zone [45]")}, q{string.find(detail, "^Zone 6")}, 'A1d');
}
