--!nocheck
-- F. Features.ShelfOpen = false (pre.oldflow.luau) : l'ancien déroulé. OpenShelfBox ne fait rien, le
-- colis se prend fermé par GrabItem et se porte en NPCBox. (Le reste de l'ancien déroulé est vérifié par
-- les bancs a17-heist, a30, a36 et a70, qui forcent le même interrupteur.)

startAll()
local Features = sharedModule("Config/Features")
check(Features.ShelfOpen == false, "F0 (banc) Features.ShelfOpen = false")
local A = player("Alice", Vector3.new(60, 3, 10))
flush()
breakStore(A, STORE_A)
local box1 = boxAt(STORE_A, 1)
standAt(A, STORE_A, 1)
fireOpen(A, box1:GetAttribute("SlotId"))
advance(1)
check(box1:GetAttribute("ShelfOpenState") == nil and boxAt(STORE_A, 1) == box1 and itemCount(STORE_A) == 0, "F1 OpenShelfBox sans effet")
check(#Witness.raised == 0, "F2 aucun témoin sollicité")
check(grabShelf(A, STORE_A, 1), "F3 le colis fermé se prend par GrabItem")
local payload = Carry.GetPayload(A)
check(payload ~= nil and payload.Kind == "NPCBox" and payload.Tier ~= nil, "F4 portage NPCBox")
Carry.Fail(A, "Caught")
flush()
advance(2)
check(boxAt(STORE_A, 1) ~= nil and #batDrops() == 0, "F5 attrapé : le colis retourne sur son rayon (ancienne règle), rien au sol")
check(logCount("tick :", "WARN", "server") == 0, "F6 aucune erreur du tick")

summary("scénario oldflow")
