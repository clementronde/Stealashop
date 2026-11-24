# f70c2 (Cantin, 18/11 : passage fluide du témoin de la course à la pose) : le scénario F1 du banc a182 lisait le cap du
# témoin 3 s après le premier coup, quand il était posté et tourné d'un coup. Il freine désormais sur ses derniers studs
# (Photo.BrakeDistance) et se tourne en Photo.TurnTime s : la lecture passe à 3,6 s, et le pas suivant à 4,7 s au lieu de
# 5,3 s (la lecture de l'appel reste à 8,3 s du premier coup). Le passage fluide lui-même : banc f70c2.
/F1 le « \? » monte pendant la marche/{n;s/^(\t)advance\(3\)$/\1advance(3.6) -- f70c2 : freinage et rotation progressive/}
/F1 trace : à son poste/{n;n;s/^(\t)advance\(5\.3\)$/\1advance(4.7) -- f70c2 : même heure qu'avant (8,3 s du premier coup)/}
