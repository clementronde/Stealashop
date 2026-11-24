# a171 : les aides de la chaîne a51 (colis rapporté, rangé, posé au sol puis ouvert en base) sont remplacées par celles de
# objet-sans-colis.luau (renommées ici en *_avant_a171).
s/^function bringBox\(/function bringBox_avant_a171(/
s/^function placeAt\(/function placeAt_avant_a171(/
s/^function openPlaced\(/function openPlaced_avant_a171(/
s/^function fullOpen\(/function fullOpen_avant_a171(/
