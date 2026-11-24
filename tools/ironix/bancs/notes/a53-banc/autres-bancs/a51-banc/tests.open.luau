--!nocheck
-- Scénario « open » (L-089 points 2 et 3) : OpenBox(boxUid) ouvre le colis posé au sol (attente écoulée,
-- à portée, chez soi). L'objet entre dans Items et va dans l'inventaire (pas exposé), son Tool n'arrive
-- qu'à la révélation (HoldBack), UnboxReveal(boxUid, …) au joueur, FloorBox retiré, OnBoxOpened. Refus :
-- pas prêt, trop loin, colis d'un autre, colis inconnu, colis pas posé. Double clic : un seul objet.
-- Inventaire plein : l'objet va sur un présentoir libre (message à la révélation) ; tout plein : refus.
-- Mutation et heure promise (migration) suivent.

advance(1000)
startServer()

section("ouverture d'un colis posé")
local ada = join("Ada", nil)
advance(1.5)
local uid = bringBox(ada, "Rare", "Z3_Smartphone", "Premium", 3)
local box = placeAt(ada, uid, 6, 20)
check(box and box.Spot ~= nil, "colis posé")
local opened = {}
UnboxService.OnBoxOpened(function(player, boxUid, itemUid, itemId, delay)
	table.insert(opened, { player = player, boxUid = boxUid, itemUid = itemUid, itemId = itemId, delay = delay })
end)
-- Pas prêt : refus.
standNear(ada, floorPoint(ada, 6, 20))
advance(0.3)
fireAs(ada, "OpenBox", uid)
flush()
check(dataOf(ada).Boxes[uid] ~= nil and countKeys(dataOf(ada).Items) == 0 and #notifies(ada, "isn't ready yet") == 1, "pas prêt : refusé, « This box isn't ready yet. »")
-- Prêt, trop loin : refus.
advance(Rarities.ById.Rare.OpenDelay + 0.5)
moveTo(ada, floorPoint(ada, 6, 20) + Vector3.new(0, 3, 14))
advance(0.3)
fireAs(ada, "OpenBox", uid)
flush()
check(dataOf(ada).Boxes[uid] ~= nil and countKeys(dataOf(ada).Items) == 0, "à 14 studs : refusé")
-- Bob ne peut pas ouvrir le colis d'Ada.
local bob = join("Bob", nil)
advance(1.5)
standNear(bob, floorPoint(ada, 6, 20))
advance(0.3)
fireAs(bob, "OpenBox", uid)
flush()
check(dataOf(ada).Boxes[uid] ~= nil and countKeys(dataOf(bob).Items) == 0, "Bob ne peut pas ouvrir le colis d'Ada")
-- Ouverture.
local itemUid = openPlaced(ada, uid)
check(itemUid ~= nil, "OpenBox accepté")
local entry = itemUid and dataOf(ada).Items[itemUid]
check(entry ~= nil and entry.Id == "Z3_Smartphone" and entry.Source == "NPC" and entry.Zone == 3, "objet dans Items (Id, Source NPC, Zone)")
check(dataOf(ada).Boxes[uid] == nil and floorBoxOf(ada, uid) == nil, "le colis a quitté Boxes et le sol")
local displayed = false
for _, u in dataOf(ada).Display do
	if u == itemUid then
		displayed = true
	end
end
check(not displayed and next(DisplayService.GetExposed(ada)) == nil, "l'objet n'est pas exposé tout seul (L-089 point 3)")
local reveal = remotes("UnboxReveal")[1]
check(reveal and reveal.to == ada and reveal.args[1] == uid and reveal.args[2] == itemUid and reveal.args[3] == "Z3_Smartphone" and reveal.args[4] == 3 and reveal.args[5] == "Premium" and reveal.args[6] == "Rare" and reveal.args[7] == 0, "UnboxReveal(boxUid, itemUid, itemId, zone, tier, rareté, crans)")
flush()
check(#opened == 1 and opened[1].boxUid == uid and opened[1].itemUid == itemUid and near(opened[1].delay, revealDelay("Rare"), 1e-6), "OnBoxOpened(player, boxUid, itemUid, itemId, délai de révélation)")
-- Le Tool de l'objet n'arrive qu'à la révélation.
advance(0.6)
check(toolsOf(ada)["Item:" .. itemUid] == nil, "pas de Tool de l'objet avant la révélation (5.7)")
advance(revealDelay("Rare"))
local tool = toolsOf(ada)["Item:" .. itemUid]
check(tool ~= nil and tool.Name == "Smartphone" or (tool ~= nil and tool:GetAttribute("ItemId") == "Z3_Smartphone"), `Tool de l'objet après la révélation ({tool and tool.Name or "absent"})`)
check(tool ~= nil and tool:GetAttribute("ItemUid") == itemUid and tool:GetAttribute("Rarity") == "Rare" and tool.TextureId == ICON_TEXTURE.Z3_Smartphone, "attributs ItemUid, ItemId, Rarity ; icône ICON_<ItemId>")
check(tool ~= nil and string.find(tool.ToolTip, "RARE", 1, true) ~= nil and string.find(tool.ToolTip, "/s", 1, true) ~= nil, `info-bulle rareté et revenu ({tool and tool.ToolTip})`)

section("double clic : un seul objet")
local u2 = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
placeAt(ada, u2, 12, 20)
advance(Rarities.ById.Common.OpenDelay + 0.5)
standNear(ada, UnboxService.GetBoxPosition(ada, u2))
advance(0.6)
local items = countKeys(dataOf(ada).Items)
fireAs(ada, "OpenBox", u2)
fireAs(ada, "OpenBox", u2)
flush()
check(countKeys(dataOf(ada).Items) == items + 1 and #remotes("UnboxReveal") == 2, "deux OpenBox d'affilée : un objet, un UnboxReveal")
advance(0.6)
fireAs(ada, "OpenBox", "pas-un-colis")
flush()
check(countKeys(dataOf(ada).Items) == items + 1, "colis inconnu : refusé")
local u3 = bringBox(ada, "Common", "Z1_Banane", "Standard", 1)
advance(0.6)
fireAs(ada, "OpenBox", u3)
flush()
check(dataOf(ada).Boxes[u3] ~= nil and countKeys(dataOf(ada).Items) == items + 1, "colis de l'inventaire (pas posé) : refusé")

section("mutation : elle passe à l'objet")
local u4 = bringBox(ada, "Common", "Z1_Banane", "Standard", 1, { Size = "Big", Effect = "Gold" })
check(dataOf(ada).Boxes[u4].Mutation ~= nil and dataOf(ada).Boxes[u4].Mutation.Size == "Big", "mutation gardée dans le colis de l'inventaire")
placeAt(ada, u4, 18, 20)
local mUid = openPlaced(ada, u4)
local mEntry = mUid and dataOf(ada).Items[mUid]
check(mEntry and mEntry.Mutation and mEntry.Mutation.Size == "Big" and mEntry.Mutation.Effect == "Gold", "objet ouvert avec la mutation du colis")
local mReveal = remotes("UnboxReveal")[#remotes("UnboxReveal")]
check(mReveal.args.n == 9 and mReveal.args[8] == "Big" and mReveal.args[9] == "Gold", "UnboxReveal avec la mutation (9 arguments)")
advance(revealDelay("Common") + 0.6)
local mTool = toolsOf(ada)["Item:" .. mUid]
check(mTool and mTool.Name == "Big Gold " .. Items.ById.Z1_Banane.DisplayName, `Tool nommé avec sa mutation ({mTool and mTool.Name})`)

section("inventaire plein : l'objet va sur un présentoir libre")
local data = newProfile()
for i = 1, Balance.Display.InventoryMax do
	addItem(data, "inv" .. i, "Z1_Banane", nil, 1, 100 + i)
end
local cy = join("Cy", data)
advance(1.5)
check(DisplayService.HasInventoryRoom(cy) == false and DisplayService.HasRoom(cy) == true, "30 objets dans l'inventaire : plus de place dans l'inventaire, mais un présentoir libre")
local uc = bringBox(cy, "Uncommon", "Z1_Donut", "Standard", 1)
placeAt(cy, uc, 6, 20)
local cItem = openPlaced(cy, uc)
check(cItem ~= nil and dataOf(cy).Display["1"] == cItem or (cItem ~= nil and next(DisplayService.GetExposed(cy)) ~= nil), "ouvert : l'objet est exposé sur un présentoir libre")
check(#notifies(cy, "went on a display stand") == 0, "message pas encore parti (avant la révélation)")
advance(revealDelay("Uncommon") + 0.2)
check(#notifies(cy, "Your inventory is full: " .. Items.ById.Z1_Donut.DisplayName .. " went on a display stand.") == 1, "« Your inventory is full: <objet> went on a display stand. » à la révélation")
-- Présentoirs pleins aussi : refus.
for slot = 1, 4 do
	if dataOf(cy).Display[tostring(slot)] == nil then
		addItem(dataOf(cy), "st" .. slot, "Z1_Banane", slot, 1, 50)
	end
end
advance(1.2)
check(DisplayService.HasRoom(cy) == false, "présentoirs et inventaire pleins")
local uf = bringBox(cy, "Common", "Z1_Banane", "Standard", 1)
placeAt(cy, uf, 12, 20)
local before = countKeys(dataOf(cy).Items)
local none = openPlaced(cy, uf)
check(none == nil and dataOf(cy).Boxes[uf] ~= nil and countKeys(dataOf(cy).Items) == before and #notifies(cy, "Inventory full: display or sell") == 1, "tout plein : ouverture refusée, colis gardé, « Inventory full… »")

section("heure promise d'un colis repris d'un présentoir (migration v7)")
local dd = newProfile()
dd.Boxes["3"] = { Tier = "Luxe", Zone = 2, ItemId = "Z2_Parapluie", Rarity = "Epic", ReadyAt = 1000 + SERVER_TIME_OFFSET + 5 }
if Items.ById.Z2_Parapluie == nil then
	-- Un Épique de la zone 2, quel qu'il soit.
	for _, item in Items.List do
		if item.Zone == 2 and item.Rarity == "Epic" and not item.TutorialOnly then
			dd.Boxes["3"].ItemId = item.Id
			break
		end
	end
end
local di = join("Di", dd)
advance(1.5)
local migrated = next(dataOf(di).Boxes)
check(migrated ~= nil and dataOf(di).Boxes[migrated].Spot == nil and dataOf(di).Boxes[migrated].ReadyAt ~= nil, "colis du présentoir 3 dans l'inventaire, heure promise gardée")
local readyBefore = #remotes("BoxReady", function(e) return e.to == di end)
local placedBox = placeAt(di, migrated, 6, 20)
check(placedBox and placedBox.ReadyAt <= serverTime() + 0.01, "posé : prêt tout de suite (l'heure promise est passée), pas une nouvelle attente d'Épique")
advance(0.3)
check(#remotes("BoxReady", function(e) return e.to == di end) == readyBefore + 1, "BoxReady tout de suite")

summary("scénario open")
