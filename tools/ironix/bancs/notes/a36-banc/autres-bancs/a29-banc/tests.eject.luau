--!nocheck
-- Scénario « eject » : la boutique du hub côté serveur (liaison L-050). Un non-propriétaire dans
-- Bounds porte intacte est sorti devant la porte ; pendant les 10 s de vol et tant que la porte est
-- cassée, personne n'est sorti ; à la reconstruction, tout le monde sort, même un voleur chargé (il
-- garde l'objet) ; la boutique tournée de 90° sort par sa porte ; le propriétaire n'est jamais sorti.

startServer()

local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3)
local ada = join("Ada", adaData)
local bobData = newProfile()
local bob = join("Bob", bobData)
local cyData = newProfile()
addItem(cyData, "cy-banana", "Z1_Banane", 1)
addItem(cyData, "cy-donut", "Z1_Donut", 2)
local cy = join("Cy", cyData)
advance(1.2)
local adaShop, cyShop = shopOf(ada), shopOf(cy)
local adaBounds, cyBounds = boundsOf(adaShop), boundsOf(cyShop)

-- `player` est-il sorti devant la porte de la boutique `index` ?
local function outsideFront(player, index, label)
	local S = SHOPS[index].S
	local root = rootOf(player)
	local position = root.Position
	local flat = Vector3.new(position.X - S.door.X, 0, position.Z - S.door.Z)
	check(not insideBox(boundsOf(SHOPS[index].model), position), `{label} : hors du volume Bounds`)
	check(flat:Dot(S.front) > 4 and flat.Magnitude < 9, `{label} : devant la porte, à environ 6 studs ({math.round(flat.Magnitude * 10) / 10})`)
	check(root.CFrame.LookVector:Dot(S.front) > 0.99, `{label} : tourné vers l'extérieur`)
	check(position.Y > 2.5 and position.Y < 4, `{label} : debout sur le sol ({math.round(position.Y * 100) / 100})`)
end

section("porte intacte : un non-propriétaire dedans est sorti")
moveTo(bob, SHOPS[1].S.center)
advance(0.2)
outsideFront(bob, 1, "Bob sorti de chez Ada")
check(#notifies(bob, "Only the owner can be inside this shop.") == 1, "Notify : seul le propriétaire peut être dedans")
moveTo(bob, SHOPS[1].S.center)
advance(0.2)
moveTo(bob, SHOPS[1].S.center)
advance(0.2)
check(#notifies(bob, "Only the owner can be inside this shop.") == 1, "message limité (une fois toutes les 3 s)")
check(insideBox(adaBounds, rootOf(ada).Position), "Ada, propriétaire, reste dans sa boutique")
moveTo(cy, SHOPS[3].S.center)
moveTo(ada, SHOPS[3].S.center)
advance(0.2)
outsideFront(ada, 3, "Ada sortie de la boutique tournée de Cy")
check(insideBox(cyBounds, rootOf(cy).Position), "Cy reste chez lui")

section("porte cassée : on entre librement, même après les 10 s")
check(breakDoor(bob, adaShop), "Bob casse la porte d'Ada")
moveTo(cy, SHOPS[1].S.center)
advance(0.5)
check(insideBox(adaBounds, rootOf(cy).Position), "pendant les 10 s : Cy reste dans la boutique cassée")
check(steal(bob, adaShop, 1), "Bob prend la Canette et reste dedans")
advance(12)
check(adaShop:GetAttribute("StealOpen") == nil, "10 s écoulées : fenêtre de vol fermée")
check(#remotes("HeistTimer", function(e) return e.to == cy and e.args[1] == "Plot_1" and e.args[2] == 0 end) == 1, "chrono masqué pour Cy à la fermeture")
check(WindowService.IsBroken(windowIdOf(adaShop)), "la porte est toujours cassée (reconstruction à 30 s)")
check(insideBox(adaBounds, rootOf(cy).Position) and insideBox(adaBounds, rootOf(bob).Position), "porte cassée : personne n'est sorti")

section("porte reconstruite : tout le monde sort, le voleur garde l'objet")
advance(18)
check(not WindowService.IsBroken(windowIdOf(adaShop)), "porte d'Ada reconstruite (30 s après la casse)")
outsideFront(bob, 1, "voleur sorti à la reconstruction")
outsideFront(cy, 1, "Cy sorti à la reconstruction")
check(#notifies(bob, "The door is fixed: you were moved outside.") == 1 and #notifies(cy, "The door is fixed: you were moved outside.") == 1, "Notify : la porte est refaite, sortis")
check(CarryService.IsCarrying(bob) and CarryService.GetPayload(bob).ItemUid == "ada-soda", "le voleur sorti porte toujours la Canette")
check(adaData.Items["ada-soda"] ~= nil, "le profil d'Ada n'a pas changé")
runHome(bob, adaShop)
check(bobData.Items["ada-soda"] ~= nil and adaData.Items["ada-soda"] == nil, "il peut encore la déposer chez lui (contrôle du dépôt repris de sa sortie)")
invariants("reconstruction", 5)

section("reconstruction en avance (pendant les 10 s) : fenêtre fermée, tout le monde sort")
advance(125, 0.5) -- fin de l'immunité d'Ada
check(breakDoor(bob, adaShop), "porte recassée")
moveTo(cy, SHOPS[1].S.center)
standBy(bob, adaShop, 2)
fireAs(bob, "StealItem", 1, 2) -- début de maintien
advance(0.3)
WindowService.Rebuild(windowIdOf(adaShop))
advance(0.2)
check(adaShop:GetAttribute("StealOpen") == nil, "fenêtre de vol fermée")
outsideFront(cy, 1, "Cy sorti")
outsideFront(bob, 1, "Bob sorti")
fireAs(bob, "StealItem", 1, 2) -- fin de maintien, mais boutique fermée
flush()
check(not CarryService.IsCarrying(bob), "le maintien en cours est annulé")

section("parcelle libérée : la porte se refait, ceux qui sont dedans sortent")
check(breakDoor(bob, cyShop), "Bob casse la porte de Cy (boutique tournée)")
moveTo(ada, SHOPS[3].S.center)
advance(0.2)
check(insideBox(cyBounds, rootOf(ada).Position), "porte cassée : Ada entre chez Cy")
local cyId = cy.UserId
moveTo(cy, SHOPS[3].S.center)
leave(cy)
advance(0.2)
check(not WindowService.IsBroken(windowIdOf(cyShop)), "Cy parti : sa porte est refaite")
outsideFront(ada, 3, "Ada sortie de la parcelle libérée")
check(not logHas("Cy sorti de PLOT_Shop_03", "PRINT", "server"), "le propriétaire qui part n'est pas « sorti » de chez lui")
check(STORE[cyId].Items["cy-banana"] ~= nil, "la sauvegarde de Cy garde ses objets")
moveTo(bob, SHOPS[3].S.center)
advance(0.3)
outsideFront(bob, 3, "parcelle libre, porte intacte : Bob en est sorti (il y serait enfermé)")

section("sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
if VERBOSE then
	dumpLog()
end
summary("scénario eject")
