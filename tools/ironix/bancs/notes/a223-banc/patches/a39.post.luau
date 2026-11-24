-- a223 (vague 66, L-210 point 7) : poursuite (faux ChaseController) et boutique ouverte hors de sa plaque.
section("(a223) poursuite")
SOURCES["client/Controllers/ChaseController.luau"] = "local M = { chased = false }\nfunction M.IsChased()\n\treturn M.chased\nend\nreturn M\n"
local fakeChase = requireModule(moduleScript(CONTROLLERS, "ChaseController", "client/Controllers/ChaseController.luau"), "client")
check(WEAPON.Enabled == true, "(a223) départ : sur la plaque des armes, UI_WeaponShop ouvert")
fakeChase.chased = true
advance(0.2)
check(WEAPON.Enabled == false, "(a223) une poursuite qui commence sur la plaque ferme l'écran")
step(FAR_SPOT)
step(spot)
advance(0.5)
check(WEAPON.Enabled == false, "(a223) poursuivi : monter sur la plaque n'ouvre rien")
fakeChase.chased = false
advance(0.2)
check(WEAPON.Enabled == true, "(a223) poursuite finie, toujours sur la plaque : ouvert")

section("(a223) boutique ouverte hors de sa plaque")
step(FAR_SPOT)
check(WEAPON.Enabled == false, "(a223) loin : UI_WeaponShop fermé")
click(hudButton(HUD, "RobuxShopButton"))
check(ROBUX.Enabled == true, "(a223) bouton du HUD loin des plaques : UI_RobuxShop ouvert")
step(FAR_SPOT + Vector3.new(5, 0, 0), 1)
check(ROBUX.Enabled == true, "(a223) ouverte au HUD, loin des plaques : reste ouverte")
step(spot)
check(WEAPON.Enabled == true, "(a223) monter sur la plaque des armes l'ouvre")
step(FAR_SPOT)
check(WEAPON.Enabled == false, "(a223) en descendre la ferme")
check(ROBUX.Enabled == true, "(a223) la boutique Robux ouverte au HUD n'est pas fermée par la plaque des armes")
click(hudButton(HUD, "RobuxShopButton"))
check(ROBUX.Enabled == false, "(a223) le bouton du HUD la referme")
check(logCount("[ShopPad] ChaseController", "WARN", "client") == 0, "(a223) ShopPad : aucun avertissement sur ChaseController")

