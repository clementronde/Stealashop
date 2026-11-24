# a308 : NavLayer (bouton plein cadre de UI_WeaponShop) est branché depuis Hover.FillParentScreens.
s/check\(countClass\(navLayer, "UIScale"\) == 0, "F1f calque plein cadre : laissé de côté"\)/check(countClass(navLayer, "UIScale") == 1, "F1f calque plein cadre de UI_WeaponShop : branché (a308, Hover.FillParentScreens)")/
