# a171, banc a49 (mutations), scénario « stand » : plus de colis posé ni ouvert en base. placePayload et openPlaced (n° de
# présentoir) donnent l objet du payload, mutation comprise, comme le rangement d un objet volé (a49.stand.pre.luau) ; la
# suite (revenu ×, BB_Item, échelle, bonus globaux, profils chargés) est celle d origine. Retirés : UnboxReveal et la ligne
# d ouverture (ouverture en base), « colis amélioré » (crans à l ouverture en base ; GiveItem garde les siens, banc a53) et
# « colis de l ancienne file » (BoxQueue : conversion des colis, bancs a105 convert et a158 base).
s/^function placePayload\(/function placePayload_avant_a171(/
s/^function openPlaced\(player, (n|slot|uid)\)/function openPlaced_avant_a171(player, \1)/
/^check\(r ~= nil and r\.args\.n == 9/d
/^check\(logHas\("mutation BIG · GOLD"/d
/^check\(r2 ~= nil and r2\.args\[8\] == nil/d
s/^check\(box ~= nil and type\(box\.Mutation\) == "table"(.*), "colis posé \(Boxes\[uid\]\)\.Mutation = \{ Size = Big, Effect = Gold \}"\)/check(box ~= nil and type(box.Mutation) == "table"\1, "a171 : objet rapporté, Mutation = { Size = Big, Effect = Gold }")/
/^section\("colis amélioré : la mutation reste/,/^summary\("scénario stand"\)/{/^summary/!d}
