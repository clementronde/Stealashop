--!nocheck
-- Scénario « a219off » (vague 66, 2026-11-16) : Config/Displayed avec ReserveCatchAll = false et SwapWhenFull = false :
-- le comportement d'a206 revient (pas d'ajout automatique, « No free display », pas de ligne « PLACE »).
SOURCES["shared/Config/Displayed.luau"] = string.gsub(string.gsub(SOURCES["shared/Config/Displayed.luau"], "ReserveCatchAll = true", "ReserveCatchAll = false"), "SwapWhenFull = true", "SwapWhenFull = false")
advance(1000)
startServer()
local Displayed = sharedModule("Config/Displayed")
local DisplayService = serverModule("DisplayService")

section("interrupteurs coupés")
check(Displayed.ReserveCatchAll == false and Displayed.SwapWhenFull == false, "ReserveCatchAll et SwapWhenFull coupés")

section("pas d'ajout automatique")
local data = a219Profile()
local ada = join("Ada", data)
advance(2.5)
check(a219Reserve(ada) == "", `c2 reste hors réserve (« {a219Reserve(ada)} »)`)
check(DisplayService.AddToReserve(ada, "c2") == true and a219Reserve(ada) == "c2", "AddToReserve(c2) : comme avant")

section("pas d'échange : « No free display »")
fireAs(ada, "PlaceFromReserve", "c2")
advance(1.2)
check(#notifies(ada, "No free display") == 1, "Notify « No free display »")
check(a219Displayed(ada).c2 == nil and a219Displayed(ada).c1 == 4 and a219Reserve(ada) == "c2", "rien ne bouge")

section("client : pas de ligne pour l'objet sous antivol")
local gui = a219Gui(ada:FindFirstChildOfClass("PlayerGui"))
startClient(ada)
advance(0.6)
clientModule("DisplayedController").Toggle()
flush()
check(a219Rows(gui) == 1 and a219Row(gui, "at1") == nil, `réserve : c2 seul ({a219Rows(gui)})`)

summary("scénario a219off")
