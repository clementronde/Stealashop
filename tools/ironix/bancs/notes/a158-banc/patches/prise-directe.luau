--!nocheck
-- a158 (aide commune aux bancs de l ancien déroulé) : la prise d'un colis fermé sur le rayon n'existe plus. L'aide grabShelf du banc
-- (renommée grabShelf_avant_a158 par patches/<nom>.sed) est remplacée : le joueur, placé devant le rayon, reçoit
-- directement de CarryService un objet sorti d'un colis de ce magasin (payload NPCItem, Commun de la zone). Le banc
-- garde Features.ShelfOpen coupé (ancien-deroule.luau) : son sujet est ce qui arrive au porteur, pas l ouverture.
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
