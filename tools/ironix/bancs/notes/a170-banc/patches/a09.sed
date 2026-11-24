# a170 : Unbox et Celebrate sortent du contrat des animations du joueur (vague 52) : 13 animations au lieu de 15, et
# l'entrée Unbox/Open de MarkerSounds part. Le test « marqueur sans son livré » passe sur Knockback/Land (son absent du
# faux arbre, comme Unbox_Open avant).
s/countLog\("4\/15 animation\(s\) préchargée\(s\)", "print"\) == 1, "préchargement : 4\/15 \(a134 : 17 moins BenchLift et BenchIdle\)"/countLog("4\/13 animation(s) préchargée(s)", "print") == 1, "préchargement : 4\/13 (a170 : 15 moins Unbox et Celebrate)"/
s/addAnimation\(pf, "Unbox", "rbxassetid:\/\/34", \{ length = 0\.5, loop = false, markers = \{ marker\("Open", 0\.2\) \} \}\)/addAnimation(pf, "Knockback", "rbxassetid:\/\/34", { length = 0.5, loop = false, markers = { marker("Land", 0.2) } })/
s/^(\s*)AC\.PlayPlayer\("Unbox"\)$/\1AC.PlayPlayer("Knockback")/
s/check\(countLog\("son « Unbox_Open » absent", "warn"\) == 1, "son absent signalé au passage du marqueur"\)/check(countLog("son « Knockback_Land » absent", "warn") == 1, "son absent signalé au passage du marqueur (a170 : Knockback\/Land)")/
