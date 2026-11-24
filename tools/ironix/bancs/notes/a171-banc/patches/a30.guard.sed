# a171, banc a30 (batte), scénario « guard » : ce qui tombe au coup de batte est un objet (NPCItem) donné devant le rayon
# (aide prise-directe d a158) au lieu d un colis fermé pris sur le rayon.
# a171-inclut: prise-directe.sed
s/Heist\.OnBoxGrabbed\(/a171OnGrabbed(/g
# Retirés (propres au colis fermé du rayon) : G3i et G7b (le colis tombé revole vers son rayon : un objet tombé expire,
# banc a158 carry), G8c (voir le rapport d a171 : un vigile poursuit maintenant Chloé), G9 (frappé dans le magasin : l objet
# n est plus lâché au sol, il échoue sans retour, CarryService.FailNoDrop, banc a45).
/"G3i le colis est reparti vers son rayon, pas de doublon"\)$/d
/"G7b le colis revole vers son rayon"\)$/d
/"G8c aucun vigile pour elle"\)$/d
/^section\("G9 Le porteur frappé avant/,/^summary\("scénario guard"\)/{/^summary/!d}
