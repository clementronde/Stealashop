# a170 : l'onglet Boxes de l'écran d'inventaire est retiré (vague 52) : s'il est encore dans l'écran, BoxesTab et
# BoxesSection sont cachés et n'ont plus d'effet ; SelectTab("Boxes") est ignoré ; UI_Inventory au contrat passe de 64 à
# 45 éléments (BoxesTab, BoxesTab.Selected et les 17 de BoxesSection retirés).
/"BoxesTab : BoxesSection seule visible"\)$/c\
check(Inventory.GetState().Tab ~= "Boxes" and not shown(INV.sections.Boxes.frame) and not shown(INV.tabs.Boxes.button), "a170 : BoxesTab et BoxesSection cachés, clic sans effet")
/"Selected suit l'onglet"\)$/d
/"aucun colis : CountLabel « 0 »"\)$/d
/"SelectTab\(\\"Boxes\\"\)"\)$/c\
check(Inventory.GetState().Tab ~= "Boxes" and not shown(INV.sections.Boxes.frame), "a170 : SelectTab(\\"Boxes\\") ignoré")
/"onglet inconnu : ignoré"\)$/c\
check(Inventory.GetState().Tab ~= "Boxes" and Inventory.GetState().Tab ~= "Nope", "onglet inconnu : ignoré")
s/#spec\.Elements == 64, `UI_Inventory au contrat : 64 éléments \(7, 8 d'onglets, 20 \+ 17 \+ 12 des sections\)/#spec.Elements == 45, `UI_Inventory au contrat : 45 éléments (7, 6 d'onglets, 20 + 12 des sections ; a170)/
