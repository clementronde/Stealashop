--!nocheck
-- a202 : Features.SingleBoxReveal = false, l'ouverture d'avant (montée de la chance, objet posé, GrabItem).
startAll(true)
local Features = sharedModule("Config/Features")
local A = player("Alice", Vector3.new(60, 3, 10))
flush()
local LMIN = luckValues()[1]

check(Features.SingleBoxReveal == false, "O0 (banc) Features.SingleBoxReveal = false")
reopen(A, STORE_A)
local item = openAndReveal(A, STORE_A, 1, LMIN, { 0 })
check(#remotes("RevealStarted") == 0, "O1 aucun RevealStarted")
check(not protected(A), "O1 aucune protection")
check(item ~= nil, "O1 objet posé sur le rayon")
check(takeItem(A, STORE_A, 1), "O1 GrabItem : Alice le prend")
local box2 = openBox(A, STORE_A, 2, LMIN)
check(box2 ~= nil and box2:GetAttribute("ShelfOpenState") == nil, "O2 mains pleines : pas d'ouverture (comme avant)")
summary("scénario oldflow")
