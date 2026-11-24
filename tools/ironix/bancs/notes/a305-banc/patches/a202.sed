# a305 (22/11, Cantin 2026-11-21 : Balance.Heist.Duration de 6 à 10 s) : G2 compte les captures à partir de l'ouverture
# du colis. Avec 10 s, le braquage de G1 est encore ouvert quand Alice attend sa fermeture (début de G2) : le vigile l'y
# attrape (vers 8 s, sans cinématique, RevealProtected absent, rien en main), capture normale avant fireOpen, que
# `catches` gardait. On vide `catches` juste avant fireOpen : « aucune capture pendant la cinématique » reste vérifié.
s/^local beforeReveal = #revealsOf\(A\)(\r?)$/table.clear(catches) -- a305 : seules les captures d'après l'ouverture comptent\1\nlocal beforeReveal = #revealsOf(A)\1/
