--!nocheck
-- a172 (vague 53) : Features.ShelfOpen n'existe plus, ancien-deroule.luau du banc ne force plus rien : la prise d'un
-- colis fermé est remplacée par l'aide d'a158 (patches/prise-directe.luau) : le voleur reçoit un objet NPCItem du magasin.
function grabShelf(player, store, slotNumber)
	local slotName = string.format("ShelfSlot_%02d", slotNumber)
	local attachment = store:FindFirstChild(slotName, true)
	local p = attachment.WorldPosition
	local side = if p.Z > 0 then -1 else 1
	local mover = place or moveTo -- selon le banc
	mover(player, Vector3.new(p.X, 3, p.Z + side * 3), Vector3.new(0, 0, -side))
	local zone = store:GetAttribute("Zone") or 1
	local item = sharedModule("Config/Items").ByZone[zone].Common[1]
	local storeId = serverModule("StoreHeistService").GetStoreId(store) or store.Name
	local payload = { Kind = "NPCItem", ItemId = item.Id, Rarity = "Common", Zone = zone, StoreId = storeId, SlotId = `{storeId}/{string.format("%02d", slotNumber)}`, Luck = 1 }
	local ok = serverModule("CarryService").StartCarry(player, payload) == true
	flush()
	return ok
end
