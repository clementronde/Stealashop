--!nocheck
-- a191 : modules montés en plus de la mise en place d'a40 (copie a55/a117).
moduleScript(SERVICES, "CosmeticService", "server/Services/CosmeticService.luau")
moduleScript(SERVICES, "InventoryService", "server/Services/InventoryService.luau")
moduleScript(CONTROLLERS, "DisplayedController", "client/Controllers/DisplayedController.luau")

-- Profil avec tous les objets des zones `zones`, sauf `missing`.
function profileWith(zones, missing)
	local data = newProfile()
	local n = 0
	for _, zone in zones do
		for _, item in sharedModule("Config/Index").ByZone[zone] do
			if item.Id ~= missing then
				n += 1
				addItem(data, `it-{n}`, item.Id, nil, zone, 500)
			end
		end
	end
	return data
end
function indexTelemetry(player)
	local list = {}
	for _, e in TELEMETRY do
		if e.player == player and e.kind == "IndexReward" then
			table.insert(list, e)
		end
	end
	return list
end
function countOf(list, value)
	local n = 0
	for _, v in list or {} do
		if v == value then
			n += 1
		end
	end
	return n
end
-- a206 (vague 63) : Controllers/UI/RarityFx, que DisplayedController lit (facultatif) pour l'effet du texte de rareté.
moduleScript(CONTROLLERS:FindFirstChild("UI"), "RarityFx", "client/Controllers/UI/RarityFx.luau")
