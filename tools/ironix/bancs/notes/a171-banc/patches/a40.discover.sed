# a171 : objets donnés comme au rangement en zone safe (objet-index.luau).
# a171-inclut: objet-index.sed
# Plus de révélation retardée (rouleau de l ouverture en base) : le message de zone part dès que l objet entre (Discover).
/^check\(#notifies\(cid, "complete"\) == 0, "pas de message avant la révélation de l'objet"\)/d
/^check\(#notifies\(cid, "complete"\) == 0, `toujours rien /d
s/^check\(#notifies\(dan, "complete"\) == 0, "parti avant la révélation : aucun message"\)/check(#notifies(dan, "complete") == 1, "a171 : plus de révélation retardée, message dès l'entrée de l'objet (avant le départ)")/
