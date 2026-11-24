# a218 (vague 66, L-210 point 1) : Cash300 a l'Id 0 : « Soon » en permanence à la place du prix.
s/check\(textOf\(cardNamed\(gui, "Cash300"\), "Price"\) == "799", "prix de la Config affiché"\)/check(textOf(cardNamed(gui, "Cash300"), "Price") == "Soon", "a218 : Id à 0 : « Soon » à la place du prix")/
