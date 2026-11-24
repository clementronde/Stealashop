# a170 : plus de colis dans l'état d'inventaire (vague 52) : un « B » encodé par le banc n'allume plus la pastille
# InventoryAlert (colis à poser n'existe plus) ; Encode ignore Boxes.
s/check\(allLit\(both\("InventoryAlert"\), true\), "colis à poser : allumée"\)/check(allLit(both("InventoryAlert"), false), "a170 : plus de colis dans l'état, pastille éteinte")/
