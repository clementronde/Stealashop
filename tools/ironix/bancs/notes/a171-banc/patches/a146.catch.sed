# a171, banc a146, scénario « catch » (le porteur tient un objet NPCItem, aide prise-directe d a158 déjà posée par a158) :
# attrapé hors du magasin, l objet tombe au sol 15 s (CarryService « Dropped (Caught) ») et son vigile reste près de lui ;
# le banc tient « le » vigile actif (le premier trouvé) : on attend que le premier soit rentré avant chaque nouvelle poursuite.
s/^check\(chased\(STORE_B\), "G5a/advance(25) -- a171 : le vigile de G4 garde l objet tombé, puis rentre\ncheck(chased(STORE_B), "G5a/
s/^advance\(12\) -- le vigile du premier magasin est rentré/advance(25) -- a171 : le vigile de G5 garde l objet tombé, puis rentre/
