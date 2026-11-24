# a263 (vague 77, 2026-11-20) : banc a116, scénario « hold ». Après un refus « maintien trop court », le serveur vide
# le maintien : l'appel suivant recommence un maintien (avant, il passait pour une fin et lançait l'ouverture tout de
# suite, puis la vraie fin était refusée). H2b refait donc un maintien complet après le refus ; H2d vérifie que l'appel
# suivant le refus ne lance rien.
if (has(q{H2 maintien trop court refusé})) {
	lit(q{		advance(required - short + 0.02)
		call(A, box)
		check(isOpening(box), "H2b " .. tier .. " : maintien de " .. (required + 0.02) .. " s accepté, ouverture lancée")},
	q{		call(A, box)
		check(not isOpening(box), "H2d " .. tier .. " : après le refus, l'appui suivant recommence un maintien, il ne lance rien (a263)")
		advance(required + 0.02)
		call(A, box)
		check(isOpening(box), "H2b " .. tier .. " : maintien de " .. (required + 0.02) .. " s accepté, ouverture lancée")}, 'H2b');
}
