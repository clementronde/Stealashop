--!nocheck
---------------------------------------------------------------- a51 (L-089) : compatibilité des bancs d'avant L-089
-- Ajouté après la mise en place (setup.luau) des copies d'a51 des bancs qui posaient leurs colis sur un
-- présentoir (a38, a40, a46, a48, a49…). Depuis L-089, le colis porté entre dans l'inventaire à l'entrée de
-- la zone safe, puis se pose au sol de la boutique (PlaceBox(boxUid, point)) et s'ouvre par
-- OpenBox(boxUid). Ici :
--   - une Part taggée SafeZone qui couvre le hub, s'il n'y en a pas déjà ;
--   - placeBox(player, n, rarity, itemId, tier?, zone?) (placePayload(player, n, payload) : payload tout fait ;
--     placeStored(player, n, uid) : un colis déjà dans l'inventaire) : le joueur part au couloir, soulève le colis, rentre
--     au centre de sa boutique (le colis est rangé), puis le pose au point du sol n° n (FLOOR_SPOTS) ;
--     SLOT_UID[player][n] = uid du colis. Renvoie le colis sauvegardé (nil : refusé) ;
--   - slotBox(player, n) : le colis posé n° n (Boxes["n"] avant L-089) ; slotUid(player, n) : son uid ;
--   - floorBoxN(player, n) : son modèle FloorBox au sol (StandBox_0n avant) ;
--   - openPlaced(player, n) : OpenBox(boxUid) du colis n° n (attente écoulée, joueur à côté) ; renvoie l'uid
--     de l'objet révélé ; openBox(player, n, …) = placeBox puis openPlaced ;
--   - goToStand(player, n) : à côté du colis posé n° n s'il existe, sinon du présentoir n (comme avant).
-- Les objets ouverts vont dans l'inventaire (L-089 point 3), plus sur un présentoir.

COMPAT51 = true
CORRIDOR51 = Vector3.new(2000, 3, 0)
do
	local found = false
	for _, inst in CollectionService:GetTagged("SafeZone") do
		found = found or inst ~= nil
	end
	if not found then
		local hub = Workspace:FindFirstChild("Map") or Workspace
		local zone = make("Part", { Name = "SafeZone51", Anchored = true, Size = Vector3.new(800, 80, 800), CFrame = CFrame.new(0, 30, 0), Transparency = 1, CanCollide = false, CanQuery = false }, hub)
		addTag(zone, "SafeZone")
	end
end

-- Points du sol (coordonnées locales de la boutique) : loin des présentoirs (z ≤ 2), des établis (z 26),
-- du tapis et du banc (z 30), du tapis de caisse (26, 32), écartés de 6 studs.
FLOOR_SPOTS = {}
for i = 1, 24 do
	local col, row = (i - 1) % 8, (i - 1) // 8
	FLOOR_SPOTS[i] = { -21 + 6 * col, 12 + 4 * row }
end
SLOT_UID = {}

local function shopOrigin51(player)
	local plot = PlotService.GetPlot(player)
	local floor = plot and (plot.PrimaryPart or plot:FindFirstChild("PlotFloor", true))
	return if plot then plot:GetPivot() else CFrame.identity, floor
end
function floorPointN(player, n)
	local spot = FLOOR_SPOTS[n]
	local origin = shopOrigin51(player)
	return origin * Vector3.new(spot[1], 0.3, spot[2])
end
function slotUid(player, n)
	local byPlayer = SLOT_UID[player]
	return if byPlayer then byPlayer[n] else nil
end
function slotBox(player, n)
	local uid = slotUid(player, n)
	local data = DataService.Get(player)
	return if uid and data then data.Boxes[uid] else nil
end
function floorBoxN(player, n)
	local uid = slotUid(player, n)
	local plot = PlotService.GetPlot(player)
	if uid == nil or plot == nil then
		return nil
	end
	for _, child in plot:GetChildren() do
		if child.Name == "FloorBox" and child:GetAttribute("BoxUid") == uid then
			return child
		end
	end
	return nil
end
local baseGoToStand = goToStand
function goToStand(player, n)
	local box = slotBox(player, n)
	if box and box.Spot then
		player.Character:PivotTo(CFrame.new(floorPointN(player, n) + Vector3.new(1.5, 3, 1.5)))
		advance(0.3)
		return
	end
	if baseGoToStand then
		baseGoToStand(player, n)
	end
end
-- Comme placeBox, avec un payload tout fait (mutation comprise).
function placePayload(player, n, payload)
	return PLACE51(player, n, payload)
end
function placeBox(player, n, rarity, itemId, tier, zone)
	return PLACE51(player, n, { Kind = "NPCBox", Tier = tier or "Standard", Zone = zone or 1, Rarity = rarity, ItemId = itemId, StoreId = "Store_1", SlotId = "Store_1/01" })
end
-- Pose au point du sol n° n un colis déjà dans l'inventaire (uid) ; renvoie le colis sauvegardé.
function placeStored(player, n, uid)
	SLOT_UID[player] = SLOT_UID[player] or {}
	SLOT_UID[player][n] = uid
	local point = floorPointN(player, n)
	player.Character:PivotTo(CFrame.new(point + Vector3.new(1.5, 3, 1.5)))
	advance(0.3)
	fireAs(player, "PlaceBox", uid, point)
	flush()
	local box = DataService.Get(player).Boxes[uid]
	return if box and box.Spot then box else nil
end
function PLACE51(player, n, payload)
	local data = DataService.Get(player)
	local before = {}
	for uid in data.Boxes do
		before[uid] = true
	end
	player.Character:PivotTo(CFrame.new(CORRIDOR51))
	advance(0.05)
	CarryService.Give(player, payload)
	advance(0.05)
	player.Character:PivotTo(PlotService.GetPlot(player):GetPivot() * CFrame.new(0, 3, 6))
	advance(0.6)
	local uid = nil
	for key in DataService.Get(player).Boxes do
		if not before[key] then
			uid = key
		end
	end
	if uid == nil then
		return nil
	end
	SLOT_UID[player] = SLOT_UID[player] or {}
	SLOT_UID[player][n] = uid
	local point = floorPointN(player, n)
	player.Character:PivotTo(CFrame.new(point + Vector3.new(1.5, 3, 1.5)))
	advance(0.3)
	fireAs(player, "PlaceBox", uid, point)
	flush()
	local box = DataService.Get(player).Boxes[uid]
	return if box and box.Spot then box else nil
end
function openPlaced(player, n)
	local box = slotBox(player, n)
	assert(box and box.Spot, `aucun colis posé n° {n}`)
	advance(math.max(0, box.ReadyAt - Workspace:GetServerTimeNow()) + 0.3)
	goToStand(player, n)
	local before = #remotes("UnboxReveal")
	fireAs(player, "OpenBox", slotUid(player, n))
	flush()
	local reveals = remotes("UnboxReveal")
	if #reveals == before then
		return nil
	end
	return reveals[#reveals].args[2]
end
function openBox(player, n, rarity, itemId, tier, zone)
	local box = placeBox(player, n, rarity, itemId, tier, zone)
	assert(box, `colis {itemId} pas posé (n° {n})`)
	return openPlaced(player, n)
end
