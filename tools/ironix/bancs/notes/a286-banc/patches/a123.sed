# a286 (L-228 c, L-232, V0 « 3 et 6 ») : Fortune Tower pour 6 joueurs : 3 casseurs (MaxHP 2.7B au lieu de 3.6B) et
# 6 caisses (LootCount) au lieu de 8 ; 5 événements = 30 caisses, 25 événements = 150 objets.
s/check\(#boxes == 8, `F1a 8 caisses/check(#boxes == 6, `F1a 6 caisses (a286)/
s/^(local ok(Row|Rarity|Inside) = )#boxes == 8$/\1#boxes == 6/
s/"F3c 8 colis sur les LootSpawn/"F3c 6 colis (a286) sur les LootSpawn/
s/check\(opened == 40, `F4a 40 caisses/check(opened == 30, `F4a 30 caisses (a286)/
s/check\(#shelfBoxes\(n7\) == 8, "F6a 8 caisses"\)/check(#shelfBoxes(n7) == 6, "F6a 6 caisses (a286)")/
s/check\(#shelfBoxes\(n7\) == 8, "F6b /check(#shelfBoxes(n7) == 6, "F6b /
s/check\(draws == 200, `I1a 200 objets/check(draws == 150, `I1a 150 objets (a286)/
s/FortuneTower\.MaxHP == 4 \* Zones\[6\]\.AdvisedDamage \* 5 \* 90 and FortuneTower\.MaxHP == 3600000000, `A0b a134 : PV = 4 ×/FortuneTower.MaxHP == 3 * Zones[6].AdvisedDamage * 5 * 90 and FortuneTower.MaxHP == 2700000000, `A0b a286 : PV = 3 ×/
s/FortuneTower\.LootCount == 8 and FortuneTower\.LootTier == "Luxe", "A0g 180 s, 8 colis Luxe"/FortuneTower.LootCount == 6 and FortuneTower.LootTier == "Luxe", "A0g 180 s, 6 colis Luxe (a286)"/
s/string\.find\(label\.Text, "1\.5B", 1, true\)/string.find(label.Text, "600M", 1, true)/
