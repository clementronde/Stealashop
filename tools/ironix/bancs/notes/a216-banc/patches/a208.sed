# a216 (vague 65) : les cartes de la v2 sont gardées écran fermé (plus refaites à chaque ouverture).
s/check\(v2Keys\(V2, "CashSection"\) == "", "cartes clonées retirées à la fermeture"\)/check(v2Keys(V2, "CashSection") == "Cash10,Cash30,Cash60,Cash180,Cash300,Cash720", "a216 : cartes gardées à la fermeture")/
