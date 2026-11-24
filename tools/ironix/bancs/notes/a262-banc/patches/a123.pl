# a262 (vague 76, 2026-11-20) : banc a123 (Fortune Tower, colis du camion).
# Scénario « inside » : le Mythique n'existe plus qu'en zone 6 (Rarities.ZoneOdds), la tour ne peut donc sortir
# que des Mythiques de la zone 6 (F4c) ; le reste de F4 est inchangé.
# Scénario « truck » : le maintien suit la rareté du colis (Commun et Peu commun 0,3 s) et un camion de zone 2 n'a
# que des colis Communs ou Peu communs (aucun objet plus rare dans la zone : repli sur la rareté en dessous) ; le
# maintien trop court de H2b passe de 0,3 s à 0,15 s (0,15 + 0,1 de tolérance < 0,3).
if (has(q{F4c Mythiques de plusieurs zones})) {
	lit(q{check(zoneSeen >= 2, `F4c Mythiques de plusieurs zones (pas seulement la 6) : {zoneSeen} zone(s)`)}, q{check(zoneSeen <= 1 and (zoneSeen == 0 or zones[6] == true), `F4c a262 : Mythiques de la zone 6 seulement (vague 76) : {zoneSeen} zone(s)`)}, 'F4c');
}
if (has(q{H2b maintien trop court : pas d'ouverture})) {
	lit(q{fireAs(A, "OpenShelfBox", slotId)
advance(0.3)
fireAs(A, "OpenShelfBox", slotId)}, q{fireAs(A, "OpenShelfBox", slotId)
advance(0.15) -- a262 : colis Commun ou Peu commun (0,3 s)
fireAs(A, "OpenShelfBox", slotId)}, 'H2b');
}
