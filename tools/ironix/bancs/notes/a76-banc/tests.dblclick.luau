--!nocheck
-- Scénario « dblclick » (vague 25, sortie du Play de Cantin : PlaceBox refusés pour débit trop rapide) :
-- clics répétés au même point pendant la pose d'un colis = une seule demande PlaceBox (PLACE_GUARD, PLACE_MOVE) ;
-- après un refus, un essai visé ailleurs part tout de suite ; colis posé : sa case est vide, la touche et
-- le clic répétés sur cette case ne prennent pas le colis suivant.

advance(1000)
startServer()
local ada = join("Ada", newProfile())
advance(1.5)
buildInventoryUi(ada)
buildHotbarUi(ada)
startClient(ada)
advance(0.5)
local Hotbar = clientModule("HotbarController")
local Inventory = clientModule("InventoryController")
local first = bringBox(ada, "Rare", "Z3_Smartphone", "Premium", 3)
advance(0.2)
local second = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
advance(0.5)
check(layoutText(Hotbar.GetState().Layout) == `Tool,Bat,{second},{first},,` or layoutText(Hotbar.GetState().Layout) == `Tool,Bat,{first},{second},,`, `deux colis en cases 3 et 4 : {layoutText(Hotbar.GetState().Layout)}`)
local rank = if Hotbar.GetState().Layout[3] == first then 3 else 4
local key = if rank == 3 then "Three" else "Four"

section("clic, clic, clic : une seule demande")
pressKey(key)
advance(0.05)
check(Inventory.GetState().Placing == first, "touche : mode pose du premier colis")
local far = floorPoint(ada, 6, 60) -- hors de sa boutique : refusé par le serveur
aimAt(far)
advance(0.1)
local calls = #serverCalls("PlaceBox")
worldClick()
flush()
worldClick()
flush()
advance(0.2)
worldClick()
flush()
check(#serverCalls("PlaceBox") == calls + 1, `3 clics en 0,2 s : 1 PlaceBox ({#serverCalls("PlaceBox") - calls})`)
advance(0.6)
check(Inventory.GetState().Placing == first and dataOf(ada).Boxes[first].Spot == nil, "refusé : le mode reste")
local target = floorPoint(ada, 18, 20)
standNear(ada, target)
aimAt(target)
advance(0.1)
worldClick()
flush()
worldClick()
flush()
check(#serverCalls("PlaceBox") == calls + 2, "visée ailleurs 0,9 s après : le nouvel essai part ; le double clic au même point n'en ajoute pas")
advance(0.6)
check(dataOf(ada).Boxes[first].Spot ~= nil and Inventory.GetState().Placing == nil, "posé : fin du mode pose")

section("case du colis posé : vide, le suivant ne prend pas sa place")
local layout = Hotbar.GetState().Layout
check(layout[rank] == "" and table.find(layout, second) ~= nil and table.find(layout, second) ~= rank, `case {rank} vide, l'autre colis garde la sienne : {layoutText(layout)}`)
pressKey(key)
advance(0.05)
local empty = slotsOf()["Slot_Empty_" .. rank]
click(empty)
advance(0.05)
check(Inventory.GetState().Placing == nil, "touche et clic répétés sur la case vide : pas de mode pose du colis suivant")
local placeCalls = #serverCalls("PlaceBox")
worldClick()
flush()
check(#serverCalls("PlaceBox") == placeCalls, "et aucun PlaceBox")

summary("scénario dblclick")
