--!nocheck
-- Scénario « inventory » (L-089 points 1 et 3, L-079) : l'état de l'inventaire suit le profil (copie d'a61,
-- vague 21 : attribut InventoryState du Player au lieu des Tools de la barre). Objets non exposés et
-- exposés (avec leur présentoir), les plus rentables d'abord ; objets au coffre-fort ou inconnus : absents.
-- PlaceItem : l'état suit tout de suite. Mort : rien ne change, aucun Tool d'objet. Le client ne peut rien
-- écrire : l'attribut est réécrit d'après le profil. Vol entre joueurs : l'objet tenu reste exposé dans
-- l'état de la victime, puis passe chez le voleur. Départ et retour : colis posés remis au sol, colis de
-- l'inventaire gardés ; un point hors de Bounds revient dans l'inventaire.

advance(1000)
startServer()

section("objets : dans l'état, les plus rentables d'abord")
local data = newProfile()
addItem(data, "low", "Z1_Banane", nil, 1, 10) -- Commun zone 1
addItem(data, "high", "Z3_Smartphone", nil, 3, 20) -- Rare zone 3
addItem(data, "shown", "Z1_Donut", 1, 1, 30) -- exposé
addItem(data, "safe", "Z1_Banane", nil, 1, 40)
data.Vault["1"] = "safe" -- au coffre-fort
data.Items.ghost = { Id = "Pas_Un_Objet", Source = "NPC", At = 0 } -- ItemId inconnu
local ada = join("Ada", data)
advance(1.5)
local inv = invOf(ada)
check(inv["Item:low"] ~= nil and inv["Item:high"] ~= nil, "les deux objets de l'inventaire")
check(inv["Item:shown"] == nil and invItem(ada, "shown") ~= nil and invItem(ada, "shown").Slot == 1, "l'objet exposé : dans l'état, avec son présentoir (1)")
check(invItem(ada, "safe") == nil and invItem(ada, "ghost") == nil, "ni l'objet du coffre-fort, ni un ItemId inconnu")
local items = invState(ada).Items
check(#items == 3 and items[1].Uid == "high", "le plus rentable d'abord")
check(inv["Item:high"].ItemId == "Z3_Smartphone" and near(inv["Item:high"].Income, Formulas.ItemIncome(3, "Rare"), 1e-3), "ItemId et revenu ($/s de l'objet)")
check(countKeys(toolsOf(ada)) == 0, "aucun Tool d'objet")

section("PlaceItem depuis l'inventaire")
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.3)
fireAs(ada, "PlaceItem", "high", 2)
flush()
check(dataOf(ada).Display["2"] == "high", "objet posé sur le présentoir 2")
check(invOf(ada)["Item:high"] == nil and invItem(ada, "high").Slot == 2, "l'état suit tout de suite (présentoir 2)")
local exposed = DisplayService.GetExposed(ada)
check(exposed[2] and exposed[2].Uid == "high", "exposé et rapporte")
-- Présentoir pris, verrouillé : refus (DisplayService), l'objet reste dans l'inventaire.
advance(0.3)
fireAs(ada, "PlaceItem", "low", 1)
fireAs(ada, "PlaceItem", "low", 9)
flush()
check(dataOf(ada).Display["1"] == "shown" and invOf(ada)["Item:low"] ~= nil and #notifies(ada, "already taken") == 1 and #notifies(ada, "locked") == 1, "présentoir pris ou verrouillé : refusé, objet gardé")
-- Hors de sa boutique : refus.
moveTo(ada, CORRIDOR)
advance(0.3)
fireAs(ada, "PlaceItem", "low", 3)
flush()
check(dataOf(ada).Display["3"] == nil and #notifies(ada, "Go back to your shop") == 1, "hors de sa boutique : refusé")
-- L'objet retiré d'un présentoir (Unplace) revient dans l'inventaire.
DisplayService.Unplace(ada, "high")
check(invOf(ada)["Item:high"] ~= nil, "Unplace : de retour dans l'inventaire tout de suite")

section("mort : rien ne change")
local before = invState(ada)
local uid = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
check(invOf(ada)["Box:" .. uid] ~= nil and #invState(ada).Boxes == #before.Boxes + 1, "un colis de plus dans l'état")
local text = ada:GetAttribute("InventoryState")
spawnCharacter(ada, refsOfShop(shopOf(ada)).center)
advance(0.2)
advance(1.2)
check(ada:GetAttribute("InventoryState") == text and countKeys(toolsOf(ada)) == 0, "après la réapparition : état identique, aucun Tool d'inventaire")
local orderAfter = backpackOrder(ada)
check(#orderAfter == 2 and orderAfter[1]:GetAttribute("ToolId") ~= nil and orderAfter[2]:GetAttribute("BatTool") == true, "le Backpack : l'outil de casse et la batte, rien d'autre")
check(countKeys(dataOf(ada).Boxes) == 1 and countKeys(dataOf(ada).Items) == 5, "profil inchangé par la mort")

section("l'attribut est réécrit d'après le profil")
ada:SetAttribute("InventoryState", "1;I,fake,Z3_Smartphone,999,0,,")
advance(0.6)
check(ada:GetAttribute("InventoryState") == text, "état faux : réécrit d'après le profil au plus 0,5 s plus tard")

section("vol entre joueurs : l'objet tenu reste exposé chez la victime, puis change d'état")
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.3)
fireAs(ada, "PlaceItem", "high", 3)
flush()
check(DisplayService.Hold(ada, "high") == 3, "objet exposé tenu par un voleur")
advance(0.6)
check(invOf(ada)["Item:high"] == nil and invItem(ada, "high").Slot == 3, "tenu : toujours exposé dans l'état (le profil ne change pas)")
local bob = join("Bob", nil)
advance(1.5)
-- Transfert sûr (PvPService au dépôt) : TakeHeld, Items de la victime vidé, Items du voleur, PlaceAuto.
DisplayService.TakeHeld(ada, "high")
local entry = dataOf(ada).Items.high
dataOf(ada).Items.high = nil
dataOf(bob).Items.high = { Id = entry.Id, Source = "PvP", At = 0, Zone = entry.Zone }
local slot = DisplayService.PlaceAuto(bob, "high")
advance(0.6)
check(invItem(ada, "high") == nil and slot ~= nil and invItem(bob, "high") ~= nil and invItem(bob, "high").Slot == slot, "déposé : exposé chez Bob, plus rien chez Ada")
DisplayService.Unplace(bob, "high")
check(invOf(bob)["Item:high"] ~= nil and invItem(ada, "high") == nil, "retiré chez Bob : dans son inventaire, jamais chez Ada")

section("départ et retour : colis posés remis au sol, inventaire gardé")
local placed = bringBox(ada, "Rare", "Z3_Smartphone", "Premium", 3)
placeAt(ada, placed, 6, 20)
local readyAt = dataOf(ada).Boxes[placed].ReadyAt
local userId = ada.UserId
leave(ada)
advance(2)
check(SAVED["Player_" .. userId] ~= nil and SAVED["Player_" .. userId].Boxes[placed] ~= nil, "profil sauvegardé au départ, colis posé compris")
local ada2 = join("Ada", nil, userId)
advance(1.5)
local back = dataOf(ada2).Boxes[placed]
check(back and back.Spot and near(back.ReadyAt, readyAt, 1e-6), "colis posé gardé (Spot, ReadyAt)")
local model = floorBoxOf(ada2, placed)
check(model ~= nil, "remis au sol de sa boutique")
check(invOf(ada2)["Box:" .. uid] ~= nil and invOf(ada2)["Box:" .. placed] == nil and invBox(ada2, placed).Placed, "colis de l'inventaire dans l'état, colis posé marqué posé")
check(remotes("UnboxReveal", function(e) return e.to == ada2 end)[1] == nil, "rien n'est ouvert au retour")

section("point hors de Bounds au retour : retour dans l'inventaire")
local userId2 = ada2.UserId
local saved = dataOf(ada2)
saved.Boxes[placed].Spot = { X = 500, Y = 0.3, Z = 0 }
leave(ada2)
advance(2)
local ada3 = join("Ada", nil, userId2)
advance(1.5)
local returned = dataOf(ada3).Boxes[placed]
check(returned and returned.Spot == nil and near(returned.ReadyAt, readyAt, 1e-6), "Spot retiré, ReadyAt gardé")
check(floorBoxOf(ada3, placed) == nil and invOf(ada3)["Box:" .. placed] ~= nil, "pas au sol : dans l'inventaire")
check(#notifies(ada3, "didn't fit in this shop") == 1, "« A box of yours didn't fit in this shop… »")

summary("scénario inventory")
