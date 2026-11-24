# a217 (vague 65) : les lignes de la boutique d'auras sont gardées écran fermé (plus refaites à chaque ouverture).
s/#rowsOf\(shopGui\) == 0, "K17 CloseButton : écran fermé, lignes retirées"/#rowsOf(shopGui) == 5, "K17 (a217) CloseButton : écran fermé, lignes gardées"/
s/#rowsOf\(shopGui\) == 0, "Z3 \(a37\) éteint au bout de la sortie : lignes retirées"/#rowsOf(shopGui) == 5, "Z3 (a37, a217) éteint au bout de la sortie : lignes gardées"/
s/#rowsOf\(shopGui\) == 0, "Z7 \(a37\) puis éteint, lignes retirées"/#rowsOf(shopGui) == 5, "Z7 (a37, a217) puis éteint, lignes gardées"/
