# a265 (vague 79, 2026-11-20) : banc a29, scénario « edges », « maintien de la prise » refait par étapes de StealItem
# ("Begin", "End") : 2e début 1,2 s après le 1er (relâché sans annulation) : rien ; fin 0,5 s après : trop court ; fin
# 0,95 s après le dernier début : prise acceptée (échoue sur l'ancien code). Appels sans étape : refusés (S0).
if (has(q{section("maintien de la prise")})) {
	lit(q{standBy(bob, adaShop, 1)
fireAs(bob, "StealItem", 1, 1)
advance(0.5)
fireAs(bob, "StealItem", 1, 1)
flush()
check(not CarryService.IsCarrying(bob), "maintien de 0,5 s : trop court, refusé")
advance(0.45)
fireAs(bob, "StealItem", 1, 1)
flush()},
		q{standBy(bob, adaShop, 1)
A265_ETAPE_STRICTE = true -- banc : etape.pl ne traduit plus les appels sans étape
fireAs(bob, "StealItem", 1, 1)
advance(0.95)
fireAs(bob, "StealItem", 1, 1)
flush()
A265_ETAPE_STRICTE = false
check(not CarryService.IsCarrying(bob), "a265 S0 deux appels sans étape : refusés, rien n'est pris")
advance(0.3)
fireAs(bob, "StealItem", 1, 1, "Begin")
advance(1.2) -- relâché trop tôt, aucune annulation envoyée
fireAs(bob, "StealItem", 1, 1, "Begin")
flush()
check(not CarryService.IsCarrying(bob), "a265 S1 2e début 1,2 s après le 1er : rien n'est pris")
advance(0.5)
fireAs(bob, "StealItem", 1, 1, "End")
flush()
check(not CarryService.IsCarrying(bob), "maintien de 0,5 s : trop court, refusé")
advance(0.45)
fireAs(bob, "StealItem", 1, 1, "End")
flush()}, 'maintien de la prise');
}
