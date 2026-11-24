--!nocheck
-- a171 (vague 52) : aides communes aux scénarios de la chaîne a51 (inventaire, barre du bas, index, mutations) que a158 avait
-- retirés parce qu'ils obtenaient leurs objets par un colis rapporté, posé au sol puis ouvert en base (n'existe plus).
-- Même parcours, avec un objet : le joueur rapporte un objet sorti d'un colis (payload NPCItem) en zone safe, il entre dans
-- l'inventaire sous antivol (Items[uid].AntiTheft), PlaceBox(uid, point) le pose au sol (l'antivol démarre : UnlockAt),
-- OpenBox(uid) le reprend une fois l'antivol fini (objet libre, même uid). Les aides gardent leur nom et leurs arguments :
--   bringBox(...) -> uid de l'objet rangé ; placeAt(uid, …) -> l'entrée Items (ReadyAt = UnlockAt) ; openPlaced(uid) -> uid ;
--   fullOpen(...) -> uid de l'objet libre.
function a171Npc(itemId, rarity, zone, mutation)
	return { Kind = "NPCItem", ItemId = itemId, Rarity = rarity, Zone = zone or 1, StoreId = "Store_1", SlotId = "Store_1/01", Luck = 1, Mutation = mutation }
end
function bringBox(player, rarity, itemId, tier, zone, mutation)
	moveTo(player, CORRIDOR)
	advance(0.05)
	local before = {}
	for uid in dataOf(player).Items do
		before[uid] = true
	end
	CarryService.Give(player, a171Npc(itemId, rarity, zone, mutation))
	advance(0.3)
	moveTo(player, refsOfShop(shopOf(player)).center)
	advance(0.6)
	for uid in dataOf(player).Items do
		if not before[uid] then
			return uid
		end
	end
	return nil
end
function placeAt(player, uid, lx, lz, from)
	local point = floorPoint(player, lx, lz)
	if from then
		moveTo(player, from)
	else
		standNear(player, point)
	end
	advance(0.3)
	fireAs(player, "PlaceBox", uid, point)
	flush()
	local entry = dataOf(player).Items[uid]
	return entry and setmetatable({}, { __index = function(_, k)
		if k == "ReadyAt" then
			return entry.UnlockAt
		end
		return entry[k]
	end })
end
function openPlaced(player, uid)
	local entry = dataOf(player).Items[uid]
	assert(entry and entry.Spot, `objet {uid} pas posé`)
	advance(math.max(0, (entry.UnlockAt or 0) - serverTime()) + 0.3)
	local model = UnboxService.GetFloorItem and UnboxService.GetFloorItem(player, uid)
	local at = model and (model.position or model.Position) or nil
	if typeof(at) ~= "Vector3" then
		local spot = entry.Spot
		at = refsOfShop(shopOf(player)).origin * Vector3.new(spot.X or 0, 0.3, spot.Z or 0)
	end
	standNear(player, at)
	fireAs(player, "OpenBox", uid)
	flush()
	local now = dataOf(player).Items[uid]
	if now == nil or now.AntiTheft then
		return nil
	end
	return uid
end
function fullOpen(player, rarity, itemId, tier, zone, lx, lz)
	local uid = bringBox(player, rarity, itemId, tier, zone)
	assert(uid, `objet {itemId} pas rangé`)
	local entry = placeAt(player, uid, lx or 0, lz or 0)
	assert(entry and entry.Spot, `objet {itemId} pas posé`)
	return openPlaced(player, uid)
end
