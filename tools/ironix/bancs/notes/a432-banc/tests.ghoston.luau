--!nocheck
-- Scénario « ghoston » du banc a432 : Config/Unbox.PlaceGhost = true (pre.ghoston.luau) remet l'aperçu d'avant, rouge
-- hors de sa boutique, vert dans sa boutique ; le clic pose de la même façon, l'aperçu disparaît à la fin du mode.
local ada, Inventory = a432Start()
local UnboxConfig = sharedModule("Config/Unbox", "client")

section("interrupteur remis : l'aperçu d'avant revient")
check(A432_GHOST_SWITCH ~= true or UnboxConfig.PlaceGhost == true, "PlaceGhost = true dans cet arbre")
local uid = bringItem(ada, "Z3_Smartphone", "Rare", 3)
Inventory.StartPlacing(uid)
aimAt(floorPoint(ada, 6, 60))
advance(0.2)
local shown, ghost = ghostShown()
check(shown and ghost.Color == Color3.fromHex("#E8413C"), "aperçu rouge hors de sa boutique")
local target = floorPoint(ada, 18, 20)
standNear(ada, target)
aimAt(target)
advance(0.2)
shown, ghost = ghostShown()
check(shown and ghost.Color == Color3.fromHex("#35C93B"), "aperçu vert dans sa boutique")
worldClick()
flush()
advance(0.6)
check(dataOf(ada).Items[uid].Spot ~= nil, "clic : posé")
check(Inventory.GetState().Placing == nil and not ghostShown(), "fin du mode pose : aperçu retiré")

summary("scénario ghoston")
