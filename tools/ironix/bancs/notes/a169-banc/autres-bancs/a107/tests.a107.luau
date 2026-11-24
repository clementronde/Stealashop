-- Banc a107 (vague 31, L-112, Features.ShelfOpen = true) : le tuto avec l'ouverture des colis sur le rayon.
-- Lu après la mise en place du banc a28 (faux services, fausse carte, TutorialService.Init, Alice, client).
-- Faux StoreHeistService du rayon (ce que le vrai pose, Shared/ShelfOpenState) : colis taggés ShelfBox dans
-- le magasin, ouverture (accroche SetLuckOverride, attributs ShelfOpen*), sortie (accroche SetContentOverride,
-- objet taggé ShelfItem réservé 5 s), prise (portage NPCItem). Faux UnboxService de la base : rangement
-- (OnItemStowed, objet sous antivol dans Items), pose au sol (GetAntiTheftDelay, UnlockAt, OnItemPlaced,
-- GetFloorItem), reprise « UNLOCKED! » sur un présentoir.

local ShelfOpenState = requireModule(SharedFolder.ShelfOpenState, "server")
local Features = requireModule(SharedFolder.Config.Features, "server")

---------------------------------------------------------------- faux rayon (StoreHeistService, L-112)
SHELF_N = 0
function makeShelfBox(storeName, position)
	SHELF_N += 1
	local store = STORES[storeName]
	local holder = store:FindFirstChild("ShelfBoxes") or folder(store, "ShelfBoxes")
	local model = new("Model", { Name = string.format("ShelfBox_%02d", SHELF_N) })
	part("Body", position + Vector3.new(0, 1, 0), Vector3.new(2, 2, 2), model)
	model.WorldPivot = CFrame.new(position)
	model:SetAttribute("SlotId", `{storeName}/{string.format("%02d", SHELF_N)}`)
	model:SetAttribute("Tier", "Standard")
	model:SetAttribute("Landed", true)
	addTag(model, "ShelfBox")
	model.Parent = holder
	return model
end
local function drawnOf(storeName, box)
	return table.freeze({ StoreId = storeName, SlotId = box:GetAttribute("SlotId"), Zone = STORES[storeName]:GetAttribute("Zone"), Tier = "Standard", Rarity = "Common", ItemId = "Z1_Banane" })
end
-- Lancement (StoreHeistService.startOpening) : chance de l'accroche du tuto, sinon ×1.
function openShelf(player, storeName, box)
	local luck = 1
	if LUCK_OVERRIDE then
		local ok, value = pcall(LUCK_OVERRIDE, player, drawnOf(storeName, box))
		if ok and type(value) == "number" and value >= 1 then
			luck = value
		end
	end
	local at = Workspace:GetServerTimeNow()
	box:SetAttribute(ShelfOpenState.ByAttribute, player.UserId)
	box:SetAttribute(ShelfOpenState.AtAttribute, at)
	box:SetAttribute(ShelfOpenState.LuckAttribute, luck)
	box:SetAttribute(ShelfOpenState.RevealAtAttribute, at + ShelfOpenState.revealDelay(luck))
	box:SetAttribute(ShelfOpenState.StateAttribute, "Opening")
	return luck
end
-- Sortie (StoreHeistService.reveal) : accroche du tuto pour l'ouvreur, le colis part, l'objet sort réservé.
function revealShelf(player, storeName, box)
	local itemId = "Z1_Banane"
	local overridden = false
	if CONTENT_OVERRIDE then
		local ok, result = pcall(CONTENT_OVERRIDE, player, drawnOf(storeName, box))
		if ok and type(result) == "table" and result.ItemId then
			itemId, overridden = result.ItemId, true
		end
	end
	local position = box.WorldPivot.Position
	local slotId = box:GetAttribute("SlotId")
	box:SetAttribute(ShelfOpenState.StateAttribute, "Revealed")
	box:Destroy()
	local item = new("Model", { Name = "ShelfItem" })
	part("Body", position + Vector3.new(0, 1, 0), Vector3.new(2, 2, 2), item)
	item.WorldPivot = CFrame.new(position)
	item:SetAttribute("SlotId", slotId)
	item:SetAttribute("ItemId", itemId)
	item:SetAttribute(ShelfOpenState.ReservedByAttribute, player.UserId)
	item:SetAttribute(ShelfOpenState.ReservedUntilAttribute, Workspace:GetServerTimeNow() + 5)
	addTag(item, ShelfOpenState.ItemTag)
	item.Parent = STORES[storeName]:FindFirstChild("ShelfBoxes")
	return item, itemId, overridden
end
-- Prise (StoreHeistService.grantItem) : l'objet quitte le rayon, portage NPCItem.
function grabShelfItem(player, storeName, item)
	local itemId = item:GetAttribute("ItemId")
	item:Destroy()
	local payload = { Kind = "NPCItem", ItemId = itemId, Rarity = Items.ById[itemId].Rarity, Zone = 1, StoreId = storeName, SlotId = "x", Luck = 1 }
	carryStart(player, payload)
	return payload
end

---------------------------------------------------------------- fausse base (UnboxService, L-112)
FLOOR_POS = {}
function FakeUnbox.GetFloorItem(_owner, uid)
	local position = FLOOR_POS[uid]
	return if position then { Uid = uid, Position = position } else nil
end
ITEM_N = 0
-- Rangement à l'entrée de la zone safe : Consume, objet sous antivol dans l'inventaire, OnItemStowed.
function stowItem(player)
	local payload = CARRY[player]
	assert(payload and payload.Kind == "NPCItem", "stowItem : aucun objet porté")
	carryEnd(player, "Consumed", "Consumed")
	ITEM_N += 1
	local uid = "item-" .. ITEM_N
	PROFILES[player].Items[uid] = { Id = payload.ItemId, Source = "NPC", At = 0, Zone = 1, AntiTheft = true }
	PROFILES[player].Lifetime.Heists += 1
	for _, listener in table.clone(ITEM_STOWED) do
		taskLib.spawn(listener, player, uid, payload.ItemId)
	end
	return uid
end
-- Pose au sol (UnboxService.placeFloorItem) : antivol par GetAntiTheftDelay, OnItemPlaced.
function placeItemFloor(player, uid, position)
	local entry = PROFILES[player].Items[uid]
	local delay = FakeUnbox.GetAntiTheftDelay(player, entry.Id)
	entry.Spot = { X = 0, Y = 0, Z = 0 }
	entry.UnlockAt = Workspace:GetServerTimeNow() + delay
	FLOOR_POS[uid] = position
	for _, listener in table.clone(ITEM_PLACED) do
		taskLib.spawn(listener, player, uid, entry.Id)
	end
	return delay
end
-- OpenBox(itemUid) après « UNLOCKED! » : l'objet redevient libre et va sur le présentoir n.
function displayFloorItem(player, uid, n)
	local entry = PROFILES[player].Items[uid]
	entry.AntiTheft, entry.UnlockAt, entry.Spot = nil, nil, nil
	FLOOR_POS[uid] = nil
	PROFILES[player].Display[tostring(n)] = uid
end
function resetStore(storeName)
	local holder = STORES[storeName]:FindFirstChild("ShelfBoxes")
	if holder then
		holder:Destroy()
	end
	closeStore(storeName)
	rebuildWindow(storeName)
end

print("== A107-A. Config/Tutorial (ShelfOpen)")
do
	check(Features.ShelfOpen == true, "passe « nouveau » : Features.ShelfOpen = true")
	local ok = true
	for _, s in Tutorial.Steps do
		if s.ShelfBubble and words(s.ShelfBubble) > Tutorial.BubbleMaxWords then
			ok = false
		end
	end
check(ok and Tutorial.Steps[3].ShelfBubble == nil and Tutorial.Steps[3].Bubble == "Open a box on the shelf!" and Tutorial.Steps[4].Bubble == "Bring the item back to your shop!", "a169 : bulles des étapes 3 et 4 = celles du rayon (ShelfBubble retiré), 8 mots au plus")
	local hintsOk = true
	for _, key in { "WaitReveal", "GrabItem", "PlaceFloorItem", "WaitUnlock", "DisplayUnlocked", "TakeUnlocked" } do
		local text = Tutorial.Hints[key]
		if text == nil or words(text) > Tutorial.BubbleMaxWords then
			hintsOk = false
		end
	end
	check(hintsOk, "6 indices (a169 : TakeUnlocked en plus), 8 mots au plus")
	check(Tutorial.ShelfLuck == 1.5 and Tutorial.AntiTheftDelay == 5, "V0 : chance du tuto ×1,5, antivol de l'objet du tuto 5 s")
	-- a121 (vague 36) : 13 étapes, les 10 premières inchangées.
	check(#Tutorial.Steps == 14 and Tutorial.Steps[3].Id == "GrabBox" and Tutorial.Steps[4].Id == "PlaceBox" and Tutorial.Steps[5].Id == "DisplayItem" and Tutorial.Steps[10].Id == "ShieldEnd", "mêmes 10 premières étapes et mêmes Id, 14 en tout (a126 : EscapeBot à la fin ; profils et funnel compatibles)")
end

print("== A107-B. Déroulé complet avec l'ouverture sur le rayon (Alice)")
PLOT_A, A = makePlot(1, -60, -60)
PROFILES[ALICE] = newProfile()
SHIELD[ALICE] = true
do
	local data = PROFILES[ALICE]
	assignPlot(ALICE, PLOT_A)
	check(data.Tutorial.Step == 1 and stateOk(ALICE, 1, nil, SUPERETTE_WINDOW), "étape 1, flèche vers la vitrine " .. describe(ALICE))
	local boxNear = makeShelfBox("STORE_Z1_Superette", Vector3.new(62, 3, 45))
	local boxFar = makeShelfBox("STORE_Z1_Superette", Vector3.new(70, 3, 70))
	holdTool(ALICE, true)
	moveTo(ALICE, Vector3.new(65, 3, 26))
	fireAsClient(ALICE, "HitWindow", "STORE_Z1_Superette")
	check(data.Tutorial.Step == 2, "premier coup : étape 2")
	breakWindow("STORE_Z1_Superette", ALICE)
	check(data.Tutorial.Step == 3, "vitrine cassée : étape 3")
	holdTool(ALICE, false)
	moveTo(ALICE, Vector3.new(63, 3, 40))
	step(0.6)
	check(stateOk(ALICE, 3, nil, Vector3.new(62, 3, 45)), "étape 3 : flèche vers le colis fermé le plus proche, sans indice " .. describe(ALICE))
	step(0.3)
	check(Controller.GetState().Text == "Open a box on the shelf!", `client : bulle de l'étape 3 « Open a box on the shelf! » ({Controller.GetState().Text})`)

	check(LUCK_OVERRIDE ~= nil, "accroche SetLuckOverride posée")
	check(LUCK_OVERRIDE(ALICE, drawnOf("STORE_Z2_MagasinDeJouets", boxFar)) == nil, "chance du tuto : jamais hors de la zone du tuto")
	local luck = openShelf(ALICE, "STORE_Z1_Superette", boxNear)
	check(luck == 1.5, "ouverture du tuto : chance imposée ×1,5")
	step(0.6)
	check(stateOk(ALICE, 3, "WaitReveal", Vector3.new(62, 3, 45)), "colis qui s'ouvre : indice WaitReveal, flèche sur le colis " .. describe(ALICE))
	local item, itemId, overridden = revealShelf(ALICE, "STORE_Z1_Superette", boxNear)
	check(overridden and itemId == Tutorial.GuaranteedItemId, "objet sorti = le Pot de nouilles (SetContentOverride à la sortie)")
	check(CONTENT_OVERRIDE(ALICE, drawnOf("STORE_Z1_Superette", boxFar)) == nil, "un 2e colis ouvert dans ce braquage n'est plus garanti")
	check(LUCK_OVERRIDE(ALICE, drawnOf("STORE_Z1_Superette", boxFar)) == nil, "ni sa chance imposée")
	step(0.6)
	check(stateOk(ALICE, 3, "GrabItem", Vector3.new(62, 3, 45)), "objet sorti : indice GrabItem, flèche sur l'objet " .. describe(ALICE))
	closeStore("STORE_Z1_Superette")
	step(0.6)
	check(data.Tutorial.Step == 3 and stateOk(ALICE, 3, "GrabItem", Vector3.new(62, 3, 45)), "chrono fini, objet encore réservé : l'étape 3 attend " .. describe(ALICE))

	grabShelfItem(ALICE, "STORE_Z1_Superette", item)
	step(0.1)
	check(data.Tutorial.Step == 4 and stateOk(ALICE, 4, nil, A.spawn), "objet sur la tête : étape 4, flèche vers sa boutique " .. describe(ALICE))
	check(funnelCount(ALICE, 4) == 1, "funnel 4 au portage NPCItem")
	check(guardSpeed(ALICE, 1) == 12, "vigile lent du tuto avec l'objet")
	step(0.3)
	check(Controller.GetState().Text == "Bring the item back to your shop!", `client : « Bring the item back to your shop! » ({Controller.GetState().Text})`)
	moveTo(ALICE, Vector3.new(0, 3, 0))
	step(0.6)
	check(funnelCount(ALICE, 5) == 1, "funnel 5 en zone safe avec l'objet")
	local uid = stowItem(ALICE)
	step(0.6)
	check(data.Tutorial.Step == 4 and stateOk(ALICE, 4, "PlaceFloorItem", A.spawn), "objet rangé sous antivol : indice PlaceFloorItem " .. describe(ALICE))
	check(funnelCount(ALICE, 5) == 1, "funnel 5 pas renvoyé au rangement")
	check(FakeUnbox.GetAntiTheftDelay(ALICE, "Z1_Banane") == 20, "antivol d'un autre objet : celui d'avant (accroche chaînée)")

	local floorAt = A.spawn + Vector3.new(4, -2.5, 0)
	moveTo(ALICE, A.spawn)
	local delay = placeItemFloor(ALICE, uid, floorAt)
	check(delay == 5, "antivol de l'objet du tuto : 5 s (au lieu de 20 s pour un Rare)")
	step(0.1)
	check(data.Tutorial.Step == 5 and stateOk(ALICE, 5, "WaitUnlock", floorAt), "objet posé au sol : étape 5, indice WaitUnlock, flèche sur l'objet " .. describe(ALICE))
	check(funnelCount(ALICE, 6) == 1 and funnelCount(ALICE, 7) == 0, "funnel 6 à la pose, pas encore 7")
	step(5.6)
check(stateOk(ALICE, 5, "TakeUnlocked", floorAt), "UNLOCKED! : indice TakeUnlocked, flèche sur l'objet (a169) " .. describe(ALICE))
	check(funnelCount(ALICE, 7) == 1 and funnelCount(ALICE, 8) == 0, "funnel 7 (« Premier objet révélé ») à la fin de l'antivol")
	-- a169 : « Take » : l'objet redevient libre et va en main (a152, attribut HeldItem) : DisplayUnlocked vers un présentoir libre.
	do
		local entry = data.Items[uid]
		entry.AntiTheft, entry.UnlockAt, entry.Spot = nil, nil, nil
		FLOOR_POS[uid] = nil
		ALICE:SetAttribute("HeldItem", uid)
		step(0.6)
		check(stateOk(ALICE, 5, "DisplayUnlocked", A.slot1), "objet repris en main : indice DisplayUnlocked, flèche vers le présentoir libre 1 " .. describe(ALICE))
		step(0.3)
		check(Controller.GetState().Text == "Put it on a display!", "client : « Put it on a display! » (" .. tostring(Controller.GetState().Text) .. ")")
		ALICE:SetAttribute("HeldItem", nil)
		step(0.6)
		check(stateOk(ALICE, 5, "PlaceItem", A.slot1), "objet rangé (plus en main) : indice PlaceItem " .. describe(ALICE))
	end
	displayFloorItem(ALICE, uid, 1)
	step(0.6)
	check(stateOk(ALICE, 5, "CollectCash", A.cashPad), "objet exposé : CollectCash " .. describe(ALICE))
	check(funnelCount(ALICE, 8) == 1, "funnel 8 à l'exposition")
	cashOut(ALICE, 10, "Pad")
	check(data.Tutorial.Step == 6 and funnelCount(ALICE, 9) == 1, "premier encaissement : étape 6, funnel 9")
	local order = funnelOf(ALICE)
	local sorted = true
	for i = 2, #order do
		if order[i] < order[i - 1] then
			sorted = false
		end
	end
	check(sorted and #order == 9, `funnel envoyé dans l'ordre 1 à 9 ({table.concat(order, ",")})`)
	resetStore("STORE_Z1_Superette")
end

print("== A107-C. Braquage raté : retours en arrière et objet de nouveau garanti (Bob)")
BOB = makePlayer("Bob", 2, Vector3.new(60, 3, 60))
PLOT_B, B = makePlot(2, 60, -60)
PROFILES[BOB] = newProfile()
SHIELD[BOB] = true
do
	local data = PROFILES[BOB]
	assignPlot(BOB, PLOT_B)
	local box = makeShelfBox("STORE_Z1_Superette", Vector3.new(62, 3, 45))
	moveTo(BOB, Vector3.new(63, 3, 40))
	breakWindow("STORE_Z1_Superette", BOB)
	step(0.1)
	check(data.Tutorial.Step == 3, "magasin ouvert près de lui : étape 3")
	openShelf(BOB, "STORE_Z1_Superette", box)
	local item, itemId = revealShelf(BOB, "STORE_Z1_Superette", box)
	check(itemId == Tutorial.GuaranteedItemId, "objet garanti")
	-- Réservation passée, magasin fermé, rien de pris : retour à l'étape 2.
	item:SetAttribute(ShelfOpenState.ReservedUntilAttribute, Workspace:GetServerTimeNow() - 1)
	closeStore("STORE_Z1_Superette")
	step(0.6)
	check(lastStep(BOB)[1] == 2 and data.Tutorial.Step == 3, "chrono fini sans prise ni réservation : étape 2 affichée (Tutorial.Step garde 3) " .. describe(BOB))
	item:Destroy()
	local box2 = makeShelfBox("STORE_Z1_Superette", Vector3.new(62, 3, 45))
	breakWindow("STORE_Z1_Superette", BOB)
	step(0.1)
	check(LUCK_OVERRIDE(BOB, drawnOf("STORE_Z1_Superette", box2)) == 1.5, "nouveau braquage : chance du tuto de nouveau")
	openShelf(BOB, "STORE_Z1_Superette", box2)
	local item2, itemId2 = revealShelf(BOB, "STORE_Z1_Superette", box2)
	check(itemId2 == Tutorial.GuaranteedItemId, "nouveau braquage : objet de nouveau garanti")
	grabShelfItem(BOB, "STORE_Z1_Superette", item2)
	step(0.1)
	check(data.Tutorial.Step == 4, "objet porté : étape 4")
	carryEnd(BOB, "Dropped", "Caught")
	step(0.6)
	check(lastStep(BOB)[1] == 3, "attrapé, objet au sol, magasin encore ouvert près de lui : étape 3 " .. describe(BOB))
	closeStore("STORE_Z1_Superette")
	moveTo(BOB, Vector3.new(0, 3, 0))
	step(0.6)
	check(lastStep(BOB)[1] == 2 and data.Tutorial.Step == 4, "magasin fermé : étape 2 affichée, Tutorial.Step garde 4 " .. describe(BOB))
	resetStore("STORE_Z1_Superette")
end

print("== A107-D. Reprise d'un profil en cours de tuto")
do
	-- Colis du tuto rangé avant L-112 (Step = 4), converti par DataService en objet libre de l'inventaire.
	local cara = makePlayer("Cara", 3, Vector3.new(-60, 3, 60))
	local plot, C = makePlot(3, -60, 60)
	local data = newProfile()
	data.Tutorial.Step = 4
	data.Items["conv-1"] = { Id = Tutorial.GuaranteedItemId, Source = "NPC", At = 0, Zone = 1 }
	PROFILES[cara] = data
	assignPlot(cara, plot)
	step(0.1)
	check(data.Tutorial.Step == 5 and stateOk(cara, 5, "PlaceItem", C.slot1), "Step 4 + colis converti en objet libre : étape 5, PlaceItem " .. describe(cara))
	-- Objet sous antivol dans l'inventaire (Step = 4) : il reste à le poser.
	local dan = makePlayer("Dan", 4, Vector3.new(60, 3, 60))
	local plotD, D = makePlot(4, 60, 60)
	local dataD = newProfile()
	dataD.Tutorial.Step = 4
	dataD.Items["at-1"] = { Id = Tutorial.GuaranteedItemId, Source = "NPC", At = 0, Zone = 1, AntiTheft = true }
	PROFILES[dan] = dataD
	assignPlot(dan, plotD)
	step(0.1)
	check(dataD.Tutorial.Step == 4 and stateOk(dan, 4, "PlaceFloorItem", D.spawn), "Step 4 + objet sous antivol rangé : étape 4, PlaceFloorItem " .. describe(dan))
	-- Objet posé au sol, antivol en cours (Step = 4 sauvegardé juste avant la pose) : étape 5, WaitUnlock.
	dataD.Items["at-1"].Spot = { X = 0, Y = 0, Z = 0 }
	dataD.Items["at-1"].UnlockAt = Workspace:GetServerTimeNow() + 30
	FLOOR_POS["at-1"] = D.spawn
	step(0.6)
	check(dataD.Tutorial.Step == 5 and stateOk(dan, 5, "WaitUnlock", D.spawn), "objet du tuto au sol : étape 5, WaitUnlock " .. describe(dan))
end

print("== A107-L. Sortie")
check(not logHas("contrôle :", "WARN", "server"), "aucune erreur dans le contrôle régulier")
check(not logHas("accroche", "WARN"), "aucune accroche refusée")
if VERBOSE then
	dumpLog()
end
summary()
