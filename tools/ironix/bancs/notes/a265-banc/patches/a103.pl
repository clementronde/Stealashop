# a265 (vague 79, 2026-11-20) : banc a103. Étape du maintien (GrabItem et GrabDropped avec "Begin", "End", "Cancel").
# Scénario « reserve », section R6 (GrabItem) : relâché trop tôt sans annulation, 2e début juste après (dans la fenêtre
# où l'ancien serveur prenait l'appel pour une fin) : rien n'est donné ; une fin 0,05 s après ce 2e début : rien ;
# annulé puis fin : rien ; maintien complet depuis le dernier début : donné (ce dernier cas échoue sur l'ancien code). Appels sans
# étape (A265_ETAPE_STRICTE, voir etape.pl) : refusés, rien n'est donné (R6f, R6g, K2i).
# Scénario « caught », K2c (GrabDropped) refait par étapes : mêmes cas, l'objet est ramassé à la fin.
if (has(q{"R5 aucune erreur du tick")})) {
	lit(q{check(logCount("tick :", "WARN", "server") == 0, "R5 aucune erreur du tick")},
		q{section("R6 a265 : le maintien de prise repart du dernier début")
advance(12)
check(waitNoGuard(60), "R6 (banc) plus de vigile")
reopen(A, STORE_A)
local item6 = reveal(A, 4)
local slot6 = item6:GetAttribute("SlotId")
local gt6 = sharedModule("Config/Rarities").GrabTime(item6:GetAttribute("BoxRarity"))
check(gt6 > 0.2, "R6 (banc) maintien de " .. gt6 .. " s")
standAt(A, STORE_A, 4)
local function grab6(phase)
	if phase then
		fireAs(A, "GrabItem", slot6, phase)
	else
		fireAs(A, "GrabItem", slot6) -- sans étape
	end
	flush()
end
grab6("Begin")
advance(gt6 + 0.2) -- relâché trop tôt, aucune annulation envoyée (le client peut mentir)
grab6("Begin")
check(not Carry.IsCarrying(A), "R6a 2e début " .. (gt6 + 0.2) .. " s après le 1er : rien n'est donné (a265)")
advance(0.05)
grab6("End")
check(not Carry.IsCarrying(A), "R6b fin 0,05 s après le 2e début : maintien trop court, rien n'est donné (a265)")
advance(0.3)
grab6("Begin")
advance(0.1)
grab6("Cancel")
advance(gt6 + 0.1)
grab6("End")
check(not Carry.IsCarrying(A), "R6c annulé au relâché : la fin qui suit est refusée (a265)")
advance(0.3)
grab6("Bogus")
check(not Carry.IsCarrying(A), "R6e étape inconnue : refusée, rien n'est donné (a265)")
advance(1.05) -- refus du journal limités à un par seconde et par joueur
A265_ETAPE_STRICTE = true -- banc : le correctif etape.pl ne traduit plus les appels sans étape
grab6(nil)
advance(gt6 + 0.05)
grab6(nil)
A265_ETAPE_STRICTE = false
check(not Carry.IsCarrying(A), "R6f deux appels sans étape, maintien complet entre eux : refusés, rien n'est donné (a265)")
check(logCount("étape de maintien absente", nil, "server") >= 1, "R6g refus « étape de maintien absente » au journal (a265)")
advance(0.3) -- débit du remote (5/s)
grab6("Begin")
advance(gt6 + 0.05)
grab6("End")
check(Carry.IsCarrying(A), "R6d maintien complet depuis le dernier début : l'objet est donné (a265)")
Carry.Consume(A)
flush()
check(logCount("tick :", "WARN", "server") == 0, "R5 aucune erreur du tick")}, 'R5');
}
if (has(q{"K2c un autre joueur le ramasse tout de suite")})) {
	lit(q{check(grabDrop(B, dropId), "K2c un autre joueur le ramasse tout de suite")},
		q{local function drop2(phase)
	if phase then
		fireAs(B, "GrabDropped", dropId, phase)
	else
		fireAs(B, "GrabDropped", dropId) -- sans étape
	end
	flush()
end
drop2("Begin")
advance(BatCfg.DroppedGrabTime + 0.2) -- relâché trop tôt, aucune annulation envoyée
drop2("Begin")
check(not Carry.IsCarrying(B), "K2g 2e début juste après un relâché : rien n'est ramassé (a265)")
advance(0.25)
drop2("Cancel")
advance(BatCfg.DroppedGrabTime + 0.1)
drop2("End")
check(not Carry.IsCarrying(B), "K2h annulé au relâché : la fin qui suit est refusée (a265)")
advance(0.25)
A265_ETAPE_STRICTE = true
drop2(nil)
advance(BatCfg.DroppedGrabTime + 0.05)
drop2(nil)
A265_ETAPE_STRICTE = false
check(not Carry.IsCarrying(B), "K2i deux appels sans étape : refusés, rien n'est ramassé (a265)")
advance(0.25)
drop2("Begin")
advance(BatCfg.DroppedGrabTime + 0.05)
drop2("End")
check(Carry.IsCarrying(B), "K2c un autre joueur le ramasse tout de suite (maintien par étapes, a265)")}, 'K2c');
}
