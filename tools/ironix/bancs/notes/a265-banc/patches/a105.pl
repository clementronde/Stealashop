# a265 (vague 79, 2026-11-20) : banc a105, scénario « steal », « second vol » : StealFloorItem par étapes ("Begin",
# "End", "Cancel"). 2e début juste après un relâché : rien ; annulé puis fin : rien ; maintien complet depuis le dernier
# début : Bob porte l'objet (échoue sur l'ancien code). Appels sans étape : refusés (F4).
if (has(q{section("second vol : dépôt chez Bob")})) {
	lit(q{section("second vol : dépôt chez Bob")
standByItem(bob)
steal(bob)
check(CarryService.IsCarrying(bob), "Bob porte l'objet")},
		q{section("second vol : dépôt chez Bob")
standByItem(bob)
local function floor2(phase)
	if phase then
		fireAs(bob, "StealFloorItem", plotIndex, uid, phase)
	else
		fireAs(bob, "StealFloorItem", plotIndex, uid) -- sans étape
	end
	flush()
end
floor2("Begin")
advance(PvP.StealGrabTime + 0.2) -- relâché trop tôt, aucune annulation envoyée
floor2("Begin")
check(not CarryService.IsCarrying(bob), "a265 F1 2e début juste après un relâché : rien n'est pris")
advance(0.3)
floor2("Cancel")
advance(PvP.StealGrabTime + 0.1)
floor2("End")
check(not CarryService.IsCarrying(bob), "a265 F2 annulé au relâché : la fin qui suit est refusée")
advance(0.3)
A265_ETAPE_STRICTE = true -- banc : etape.pl ne traduit plus les appels sans étape
floor2(nil)
advance(PvP.StealGrabTime + 0.05)
floor2(nil)
A265_ETAPE_STRICTE = false
check(not CarryService.IsCarrying(bob), "a265 F4 deux appels sans étape : refusés, rien n'est pris")
advance(0.3)
floor2("Begin")
advance(PvP.StealGrabTime + 0.05)
floor2("End")
check(CarryService.IsCarrying(bob), "Bob porte l'objet (maintien par étapes, a265 F3)")}, 'second vol');
}
