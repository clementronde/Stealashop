--!nocheck
-- a171 (vague 52) : bancs de l'index (a40, a55). L'ouverture d'un colis en base n'existe plus ; aujourd'hui un objet entre
-- dans Items quand l'objet volé est rangé en zone safe (UnboxService.stowItem, qui appelle IndexService.Discover : vérifié
-- par le banc a105, scénario arrive). openBox donne donc l'objet comme ce rangement : entrée Items (Source « NPC », zone),
-- puis IndexService.Discover. Renvoie l'uid de l'objet. La suite (une seule découverte, attribut, zones complètes, bonus,
-- prime) est celle du banc d'origine.
A171_ITEMS = 0
function openBox(player, bench, rarity, itemId, tier, zone)
	local data = dataOf(player)
	A171_ITEMS += 1
	local uid = `a171-{A171_ITEMS}-{itemId}`
	data.Items[uid] = { Id = itemId, Source = "NPC", At = os.time(), Zone = zone or 1 }
	serverModule("IndexService").Discover(player, itemId)
	pcall(function()
		serverModule("InventoryService").Refresh(player)
	end)
	flush()
	return uid
end
