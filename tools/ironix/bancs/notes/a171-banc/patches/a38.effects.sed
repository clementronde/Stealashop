# a171, banc a38 (boutique Robux) : seules les attentes de colis posés en base sont retirées ; « Ouvrir maintenant » et Fast
# Open sur l antivol de l objet posé au sol sont vérifiés par le banc a105 (scénarios robux et norobux).
/^section\("Ouverture rapide"\)/,/^section\("\+4 présentoirs"\)/{/^section\("\+4/!d}
/^local cidBox = placeBox\(cid, 1, "Rare", rareId, "Premium", rareZone\)/d
/"attente normale \(Rare : 45 s\)"\)$/d
