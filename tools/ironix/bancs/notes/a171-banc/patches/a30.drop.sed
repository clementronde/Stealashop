# a171, banc a30 (batte), scénario « drop » : ce qui tombe au coup de batte est un objet (NPCItem) donné devant le rayon
# (aide prise-directe d a158) au lieu d un colis fermé pris sur le rayon.
# a171-inclut: prise-directe.sed
s/Heist\.OnBoxGrabbed\(/a171OnGrabbed(/g
# Retirés (propres au colis fermé du rayon) : D1c et D1i (rayon compté : l objet est donné devant le rayon sans le vider),
# D3c et D3d (retour en vol sur le rayon : un objet tombé expire, banc a158 carry), D4 (nuit, même retour), D5 (colis du
# camion porté : lot A, il n y en a plus).
/"D1c le rayon reste vide tant que le colis est sorti"\)$/d
/"D1i posé sur un établi : il ne revient jamais"\)$/d
/D3c revenu sur son emplacement d'origine/d
/"D3d en vol vers le rayon"\)$/d
/^section\("D4 Nuit/,/^summary\("scénario drop"\)/{/^summary/!d}
