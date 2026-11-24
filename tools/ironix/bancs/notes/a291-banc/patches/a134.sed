# a291 : Fortune Tower pour 6 joueurs (a286, L-228 c, V0 « 3 et 6 ») : 3 casseurs, MaxHP 2.7B au lieu de 3.6B.
s/eq\(Config\.FortuneTower\.MaxHP, 4 \* 2_000_000 \* 5 \* 90, "Fortune Tower : 3\.6B PV \(5 coups\/s\)"\)/eq(Config.FortuneTower.MaxHP, 3 * 2_000_000 * 5 * 90, "Fortune Tower : 2.7B PV (a286 : 3 casseurs, 5 coups\/s)")/
