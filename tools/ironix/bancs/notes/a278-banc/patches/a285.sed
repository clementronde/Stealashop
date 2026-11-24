# a278 (23/11, L-272) : IconHover = Spring est codé (UiAttrFx suit le pointeur, RobuxShopController tourne la caméra de
# la caisse) : plus de ligne « pas codé » en Studio ; à la place, l'élément est suivi (GetState().Springs) et reste au
# repos sans survol. Le reste du banc a285 (déjà corrigé par a297 et a298) est inchangé.
s/^check\(logHas\("IconHover = Spring", "PRINT", "client"\), "Spring : pas codé, une ligne en Studio"\)$/check(not logHas("IconHover = Spring", "PRINT", "client") and Fx.GetState().Springs == 1 and select(3, Fx.Spring(springBtn)) == 0, "a278 : Spring codé, suivi sans ligne en Studio, au repos sans survol")/
