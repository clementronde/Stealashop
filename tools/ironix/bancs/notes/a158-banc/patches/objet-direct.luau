--!nocheck
-- a158 (aide commune aux bancs de la chaîne a51 : inventaire, barre du bas) : rapporter un colis, le poser au sol et
-- l'ouvrir en base n'existe plus. L'aide fullOpen du banc (renommée fullOpen_avant_a158 par patches/<nom>.sed), qui ne
-- servait qu'à obtenir un objet dans l'inventaire, est remplacée : l'objet entre directement dans le profil, comme
-- UnboxService.GiveItem (Source « NPC », zone), l'Index et l'inventaire sont prévenus. Renvoie l'uid de l'objet.
A158_ITEMS = 0
function fullOpen(player, rarity, itemId, tier, zone, lx, lz)
	local data = dataOf(player)
	A158_ITEMS += 1
	local uid = `a158-{A158_ITEMS}-{itemId}`
	data.Items[uid] = { Id = itemId, Source = "NPC", At = os.time(), Zone = zone or 1 }
	pcall(function()
		serverModule("IndexService").Discover(player, itemId)
	end)
	serverModule("InventoryService").Refresh(player)
	flush()
	return uid
end
