# a265 (vague 79, 2026-11-20) : banc pc-steal.
# a265 (vague 79) : faux Roblox client sans PromptButtonHoldEnded (HeistController s'y abonne depuis a265 pour
# envoyer "Cancel" au relâché) : signal ajouté à la liste SIGNALS du faux ProximityPrompt (ajout pur ; les sources des contrôleurs, collées dans le fichier, citent déjà le nom).
if (has(q{PromptButtonHoldBegan = true,}) && !has(q{PromptButtonHoldEnded = true})) {
	$t =~ s/PromptButtonHoldBegan = true,/PromptButtonHoldBegan = true, PromptButtonHoldEnded = true,/g;
}
