# a263 (vague 77, 2026-11-20) : banc a103, scénario « reserve ». Après un refus « maintien trop court » de GrabItem, le
# serveur vide le maintien : l'appui suivant recommence un maintien (avant, passé GrabTime, il passait pour une fin et
# donnait l'objet tout de suite). Cas R4m ; l'attente d'expiration qui suit couvre ce nouveau maintien.
if (has(q{"R4a maintien trop court : refusé"})) {
	lit(q{"R4a maintien trop court : refusé")
	advance(1.2) -- le maintien ouvert expire},
	q{"R4a maintien trop court : refusé")
	advance(grabTime + 0.03)
	standAt(A, STORE_A, 3)
	fireAs(A, "GrabItem", item3:GetAttribute("SlotId"))
	flush()
	check(not Carry.IsCarrying(A), "R4m après le refus, l'appui suivant recommence un maintien, il ne donne rien (a263)")
	advance(grabTime + 1.2) -- le maintien ouvert expire}, 'R4a');
}
