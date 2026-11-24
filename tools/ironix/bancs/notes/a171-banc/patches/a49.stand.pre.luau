--!nocheck
-- a171 (vague 52), banc a49 « stand » : voir a49.stand.sed.
A171_PENDING = {}
A171_N = 0
function placePayload(player, n, payload)
	A171_PENDING[player] = A171_PENDING[player] or {}
	A171_PENDING[player][n] = payload
	return { Mutation = payload.Mutation, ItemId = payload.ItemId, Rarity = payload.Rarity, Zone = payload.Zone }
end
function openPlaced(player, n)
	local p = A171_PENDING[player] and A171_PENDING[player][n]
	if p == nil then
		return openPlaced_avant_a171(player, n)
	end
	A171_PENDING[player][n] = nil
	A171_N += 1
	local uid = `a171-{A171_N}`
	dataOf(player).Items[uid] = { Id = p.ItemId, Source = "NPC", At = os.time(), Zone = p.Zone or 1, Mutation = p.Mutation }
	pcall(function()
		serverModule("InventoryService").Refresh(player)
	end)
	flush()
	return uid
end
