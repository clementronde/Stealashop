# a262 (vague 76, 2026-11-20) : banc pc-reach (portée au début du maintien). Le maintien suit la rareté du colis et
# la zone 1 n'a que des colis Communs (0,3 s) : avant, le colis de R3 pouvait être Premium (0,6 s) et le refus de R4a
# tombait plus d'une seconde après celui de R2. Le serveur ne note qu'un refus par seconde et par joueur (Studio) :
# R4a attend donc 1,05 s avant son essai (rien d'autre ne change).
if (has(q{R4a WalkSpeed 10 : plafond 8})) {
	lit(q{local n4 = closedSlot()
}, q{local n4 = closedSlot()
advance(1.05) -- a262 : un refus noté par seconde et par joueur
}, 'R4a attente');
}
