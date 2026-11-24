# fusion57 : DataService publie l'attribut joueur Diamonds au chargement du profil (lu par DiamondBalance d'a209, dans UI_DiamondShop seulement).
s/^check\(ada:GetAttribute\("Diamonds"\) == nil, "aucun attribut Diamonds \(rien d'affiché hors de UI_DiamondShop\)"\)/check(ada:GetAttribute("Diamonds") == 0, "(fusion57) attribut Diamonds publié au chargement (0), lu par UI_DiamondShop seulement")/
