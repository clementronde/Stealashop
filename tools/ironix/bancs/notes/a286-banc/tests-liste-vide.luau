--!nocheck
-- Banc a286, partie « liste-vide » : liste unique sans aucun objet (ni exposé ni en réserve) : Panel.ListEmpty montré,
-- aucune ligne ; l'ancien écran (avec Panel.Reserve) n'a pas de ListEmpty à gérer (partie « liste » d'a242 et a219).
advance(1000)
startServer()
local ada = join("Ada", newProfile())
advance(1.5)
local gui = buildGui(ada:FindFirstChildOfClass("PlayerGui"))
gui.Dock.Panel.ListEmpty.Visible = false -- le code doit le montrer
startClient(ada)
advance(0.6)
local Displayed = clientModule("DisplayedController")
section("liste vide")
Displayed.Toggle()
flush()
check(#rowsIn(gui.Dock.Panel.List, nil) == 0, "aucune ligne")
check(gui.Dock.Panel.ListEmpty.Visible == true, "ListEmpty montré")
check(not logHas("Reserve introuvable", ""), "aucune ligne « Reserve introuvable »")
summary("scénario a286 liste vide")
