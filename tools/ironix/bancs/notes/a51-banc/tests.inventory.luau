--!nocheck
-- Scénario « inventory » (L-089 points 1 et 3, L-079) : la barre suit le profil. Objets non exposés =
-- Tools (les plus rentables d'abord), objets exposés ou au coffre-fort : pas de Tool. PlaceItem depuis
-- l'inventaire : le Tool s'en va. Mort (Backpack neuf) : la barre est refaite, sans doublon. Vol entre
-- joueurs : l'objet tenu n'a pas de Tool chez la victime, puis passe chez le voleur. Départ et retour :
-- colis posés remis au sol, colis de l'inventaire gardés ; un point hors de Bounds revient dans
-- l'inventaire. Un Tool détruit chez le client ne change rien : le serveur le refait.

advance(1000)
startServer()

section("objets de l'inventaire : des Tools, les plus rentables d'abord")
local data = newProfile()
addItem(data, "low", "Z1_Banane", nil, 1, 10) -- Commun zone 1
addItem(data, "high", "Z3_Smartphone", nil, 3, 20) -- Rare zone 3
addItem(data, "shown", "Z1_Donut", 1, 1, 30) -- exposé
addItem(data, "safe", "Z1_Banane", nil, 1, 40)
data.Vault["1"] = "safe" -- au coffre-fort
data.Items.ghost = { Id = "Pas_Un_Objet", Source = "NPC", At = 0 } -- ItemId inconnu
local ada = join("Ada", data)
advance(1.5)
local tools = toolsOf(ada)
check(tools["Item:low"] ~= nil and tools["Item:high"] ~= nil, "Tools des deux objets de l'inventaire")
check(tools["Item:shown"] == nil and tools["Item:safe"] == nil and tools["Item:ghost"] == nil, "pas de Tool pour l'objet exposé, celui du coffre-fort, ni un ItemId inconnu")
local order = backpackOrder(ada)
check(order[3] == tools["Item:high"] and order[4] == tools["Item:low"], "après l'outil et la batte : le plus rentable d'abord")
check(tools["Item:high"].Name == Items.ById.Z3_Smartphone.DisplayName and tools["Item:high"]:GetAttribute("ItemId") == "Z3_Smartphone", "nom et ItemId de l'objet (pas secret une fois révélé)")

section("PlaceItem depuis l'inventaire")
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.3)
fireAs(ada, "PlaceItem", "high", 2)
flush()
check(dataOf(ada).Display["2"] == "high", "objet posé sur le présentoir 2")
check(toolsOf(ada)["Item:high"] == nil, "son Tool a quitté la barre tout de suite")
local exposed = DisplayService.GetExposed(ada)
check(exposed[2] and exposed[2].Uid == "high", "exposé et rapporte")
-- Présentoir pris, verrouillé : refus (DisplayService), le Tool reste.
advance(0.3)
fireAs(ada, "PlaceItem", "low", 1)
fireAs(ada, "PlaceItem", "low", 9)
flush()
check(dataOf(ada).Display["1"] == "shown" and toolsOf(ada)["Item:low"] ~= nil and #notifies(ada, "already taken") == 1 and #notifies(ada, "locked") == 1, "présentoir pris ou verrouillé : refusé, Tool gardé")
-- Hors de sa boutique : refus.
moveTo(ada, CORRIDOR)
advance(0.3)
fireAs(ada, "PlaceItem", "low", 3)
flush()
check(dataOf(ada).Display["3"] == nil and #notifies(ada, "Go back to your shop") == 1, "hors de sa boutique : refusé")
-- L'objet retiré d'un présentoir (Unplace) revient dans la barre.
DisplayService.Unplace(ada, "high")
check(toolsOf(ada)["Item:high"] ~= nil, "Unplace : le Tool revient tout de suite")

section("mort : Backpack neuf, barre refaite sans doublon")
local before = countKeys(toolsOf(ada))
local uid = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
check(toolsOf(ada)["Box:" .. uid] ~= nil and countKeys(toolsOf(ada)) == before + 1, "un colis de plus dans la barre")
-- Le colis en main au moment de la mort.
local humanoid = ada.Character:FindFirstChildOfClass("Humanoid")
humanoid:EquipTool(toolsOf(ada)["Box:" .. uid])
advance(0.1)
check(toolsOf(ada)["Box:" .. uid].Parent == ada.Character, "colis en main")
spawnCharacter(ada, refsOfShop(shopOf(ada)).center)
advance(0.2)
advance(1.2)
local after = toolsOf(ada)
check(countKeys(after) == before + 1 and after["Box:" .. uid] ~= nil and after["Box:" .. uid].Parent == ada:FindFirstChild("Backpack"), "après la réapparition : tous les Tools refaits, une fois chacun")
local orderAfter = backpackOrder(ada)
check(orderAfter[1]:GetAttribute("ToolId") ~= nil and orderAfter[2]:GetAttribute("BatTool") == true, "l'outil de casse et la batte gardent les slots 1 et 2")
check(countKeys(dataOf(ada).Boxes) == 1 and countKeys(dataOf(ada).Items) == 5, "profil inchangé par la mort")

section("un Tool détruit (ou copié) chez le client ne change rien")
local box = toolsOf(ada)["Box:" .. uid]
box:Destroy()
advance(0.6)
check(toolsOf(ada)["Box:" .. uid] ~= nil, "Tool détruit : refait d'après le profil")
local copy = toolsOf(ada)["Item:low"]:Clone()
copy.Parent = ada:FindFirstChild("Backpack")
advance(0.6)
local n = 0
for _, child in ada:FindFirstChild("Backpack"):GetChildren() do
	if child:GetAttribute("ItemUid") == "low" then
		n += 1
	end
end
check(n == 1, "Tool en double : un seul gardé")

section("vol entre joueurs : l'objet tenu n'a pas de Tool, puis change de barre")
moveTo(ada, refsOfShop(shopOf(ada)).center)
advance(0.3)
fireAs(ada, "PlaceItem", "high", 3)
flush()
check(DisplayService.Hold(ada, "high") == 3, "objet exposé tenu par un voleur")
advance(0.6)
check(toolsOf(ada)["Item:high"] == nil, "tenu : pas de Tool chez la victime")
local bob = join("Bob", nil)
advance(1.5)
-- Transfert sûr (PvPService au dépôt) : TakeHeld, Items de la victime vidé, Items du voleur, PlaceAuto.
DisplayService.TakeHeld(ada, "high")
local entry = dataOf(ada).Items.high
dataOf(ada).Items.high = nil
dataOf(bob).Items.high = { Id = entry.Id, Source = "PvP", At = 0, Zone = entry.Zone }
local slot = DisplayService.PlaceAuto(bob, "high")
advance(0.6)
check(toolsOf(ada)["Item:high"] == nil and slot ~= nil and toolsOf(bob)["Item:high"] == nil, "déposé : exposé chez Bob, aucun Tool ni chez l'un ni chez l'autre")
DisplayService.Unplace(bob, "high")
check(toolsOf(bob)["Item:high"] ~= nil and toolsOf(ada)["Item:high"] == nil, "retiré chez Bob : son Tool, jamais chez Ada")

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
check(toolsOf(ada2)["Box:" .. uid] ~= nil and toolsOf(ada2)["Box:" .. placed] == nil, "colis de l'inventaire dans la barre, colis posé non")
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
check(floorBoxOf(ada3, placed) == nil and toolsOf(ada3)["Box:" .. placed] ~= nil, "pas au sol : dans la barre")
check(#notifies(ada3, "didn't fit in this shop") == 1, "« A box of yours didn't fit in this shop… »")

summary("scénario inventory")
