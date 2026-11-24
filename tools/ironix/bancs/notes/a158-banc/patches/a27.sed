# a158, banc a27 (camion, sans StoreHeistService dans son faux arbre) : plus aucun colis posé au sol à l explosion ;
# sans rayon d événement, le camion explose sans colis. Scénarios « explosion » et « grab » (colis au sol, GrabDropped) retirés.
s/check\(#truckDrops\(\) == 12, "C31 il explose et lâche ses 12 colis"\)/check(#truckDrops() == 0, "C31 a158 : il explose sans colis au sol (rayon d événement absent de ce banc)")/
s/check\(#truckDrops\(\) == 12 and not hasTag\(t2, "HitTarget"\), "F6 Explode : 12 colis, plus de coups possibles"\)/check(#truckDrops() == 0 and not hasTag(t2, "HitTarget"), "F6 a158 : Explode, aucun colis au sol, plus de coups possibles")/
/"F8 FX_BoxTrail pas livré : traînée V0 blanche"/d
/"F9 … annoncée une fois en Studio"/d
