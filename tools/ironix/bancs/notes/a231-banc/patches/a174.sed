# a231 (vague 70) : les journaux de GuardService sur l'objet volé disent « objet » au lieu de « colis » ; les attentes
# des bancs qui les lisent suivent (les sources du jeu n'ont plus ces motifs, seuls les scénarios changent).
s/(poursuit [A-Za-z]+ qui a ramassé) le colis/\1 l'objet/g
s/abandonne le colis tombé au sol/abandonne l'objet tombé au sol/g
s/\(colis resté au sol, reparti vers son rayon\)/(objet resté au sol, reparti vers son rayon)/g
s/ramasse un colis tombé au sol : aucun vigile/ramasse un objet tombé au sol : aucun vigile/g
s/cible reprise par le vigile du colis ramassé/cible reprise par le vigile de l'objet ramassé/g
s/sans nouvelles du colis au sol/sans nouvelles de l'objet au sol/g
s/\(ne porte plus de colis\)/(ne porte plus d'objet)/g
/^local id1, pos1 = caughtDrops\(A, payload, "C1a 1re capture :"\)$/a\
check(waitFor(function() return logCount("l'objet de Alice est tombé au sol, il va vers lui", "PRINT", "server") >= 1 end, 5) and logCount("de ? est tombé au sol", "PRINT", "server") == 0, "a231 C1a journal du vigile : « l'objet de Alice est tombé au sol », plus « ? »")
