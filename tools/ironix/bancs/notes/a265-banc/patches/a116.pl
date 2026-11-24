# a265 (vague 79, 2026-11-20) : banc a116, scénario « hold ». Étape du maintien d'OpenShelfBox ("Begin", "End",
# "Cancel") : 2e début juste après un relâché (sans annulation) : rien ne s'ouvre ; fin 0,05 s après : rien ; annulé
# puis fin : rien ; maintien complet depuis le dernier début : l'ouverture part (échoue sur l'ancien code). Section H6, sur le magasin rouvert. Appels sans étape : refusés (H6e).
if (has(q{"H5 aucune erreur du tick")})) {
	lit(q{check(logCount("tick :", "WARN", "server") == 0, "H5 aucune erreur du tick")},
		q{section("H6 a265 : le maintien d'ouverture repart du dernier début")
advance(12) -- fin du braquage : rayon fermé, puis rouvert par Alice (sinon le chrono ferme le magasin au milieu de H6)
local t7 = 0
while #guards() > 0 and t7 < 60 do
	advance(0.5)
	t7 += 0.5
end
check(#guards() == 0, "H6 (banc) plus de vigile")
reopen(A, STORE_A)
local n7, box7 = nil, nil
for n = 1, 10 do
	local b = boxAt(STORE_A, n)
	if b and not isOpening(b) and n7 == nil then
		n7, box7 = n, b
	end
end
check(box7 ~= nil, "H6 (banc) un colis encore fermé")
if box7 then
	local gt7 = sharedModule("Config/Rarities").GrabTime(box7:GetAttribute("BoxRarity"))
	local slot7 = box7:GetAttribute("SlotId")
	standAt(A, STORE_A, n7)
	local function open7(phase)
		if phase then
			fireAs(A, "OpenShelfBox", slot7, phase)
		else
			fireAs(A, "OpenShelfBox", slot7) -- sans étape
		end
		flush()
	end
	open7("Begin")
	advance(gt7 + 0.2) -- relâché trop tôt, aucune annulation envoyée
	open7("Begin")
	check(not isOpening(box7), "H6a 2e début juste après un relâché : rien ne s'ouvre (a265)")
	advance(0.05)
	open7("End")
	check(not isOpening(box7), "H6b fin 0,05 s après le 2e début : trop court, rien ne s'ouvre (a265)")
	advance(0.3)
	open7("Begin")
	advance(0.1)
	open7("Cancel")
	advance(gt7 + 0.1)
	open7("End")
	check(not isOpening(box7), "H6c annulé au relâché : la fin qui suit est refusée (a265)")
	advance(0.3)
	A265_ETAPE_STRICTE = true -- banc : etape.pl ne traduit plus les appels sans étape
	open7(nil)
	advance(gt7 + 0.05)
	open7(nil)
	A265_ETAPE_STRICTE = false
	check(not isOpening(box7), "H6e deux appels sans étape : refusés, rien ne s'ouvre (a265)")
	advance(0.3)
	open7("Begin")
	advance(gt7 + 0.05)
	open7("End")
	check(isOpening(box7), "H6d maintien complet depuis le dernier début : l'ouverture part (a265)")
	if not isOpening(box7) then
		dumpLog("OpenShelfBox")
	end
end
check(logCount("tick :", "WARN", "server") == 0, "H5 aucune erreur du tick")}, 'H5');
}

# a265 (vague 79) : faux Roblox client sans PromptButtonHoldEnded (HeistController s'y abonne depuis a265 pour
# envoyer "Cancel" au relâché) : signal ajouté à la liste SIGNALS du faux ProximityPrompt (ajout pur ; les sources des contrôleurs, collées dans le fichier, citent déjà le nom).
if (has(q{PromptButtonHoldBegan = true,}) && !has(q{PromptButtonHoldEnded = true})) {
	$t =~ s/PromptButtonHoldBegan = true,/PromptButtonHoldBegan = true, PromptButtonHoldEnded = true,/g;
}
