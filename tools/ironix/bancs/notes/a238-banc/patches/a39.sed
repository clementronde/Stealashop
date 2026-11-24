# a238 (vague 71, L-213 point 1b) : Ouvrir maintenant sans colis garde son bouton, au prix du premier palier (19).
s/and not shown\(openNow, "BuyButton"\), "sans colis : « No (box|item) is waiting », pas de bouton"\)/and shown(openNow, "BuyButton") and textOf(openNow, "Price") == "19", "a238 : sans colis : « No \1 is waiting », bouton au prix du premier palier")/
