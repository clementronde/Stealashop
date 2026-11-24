--!nocheck
-- D. Explosion : 12 colis 6/4/2, contenu tiré dans la zone du camion, points d'arrivée, vol avec la
-- traînée de Clément, pièces qui volent puis s'effacent (client), copie retirée (serveur).

local Tool = serverModule("ToolService")
local Carry = serverModule("CarryService")
local Items = sharedModule("Config/Items")
local Rarities = sharedModule("Config/Rarities")
local TruckEvent = sharedModule("Config/TruckEvent")
local Balance = sharedModule("Config/Balance")
startServer()
local A = newPlayer("Alice")
spawnCharacter(A, Vector3.new(240, 3, 10), Vector3.new(0, 0, -1))
giveTool(A, "Hammer")
Tool.damage[A] = 600
startClient(A)

Workspace:SetAttribute("TruckSpawnNow", 3)
flush()
local truck = currentTruck()
local center = truck:GetPivot().Position
local id = truck:GetAttribute("WindowId")
-- Positions de départ des pièces et des BoxSpawn, avant l'explosion.
local pieceStart = {}
for _, piece in truck.Pieces:GetChildren() do
	pieceStart[piece] = piece:GetBoundingBox().Position
end
local spawnPoints = {}
for i = 1, 12 do
	spawnPoints[i] = truck:FindFirstChild(string.format("BoxSpawn_%02d", i), true).WorldPosition
end
local blast = truck:FindFirstChild("BlastPoint", true).WorldPosition

fireAs(A, "HitWindow", id) -- 1000 → 400
advance(0.15)
fireAs(A, "HitWindow", id) -- 400 → 0
flush()
local explodedAt = now()

section("D. Le camion explose")
check(truck:GetAttribute("Broken") == true, "D1 Broken")
local serverAt = truck:GetAttribute("ExplodedAt")
check(type(serverAt) == "number" and near(serverAt, Workspace:GetServerTimeNow(), 1e-6), "D2 ExplodedAt = heure serveur de l'explosion")
local solid = 0
for _, d in truck:GetDescendants() do
	if d:IsA("BasePart") and (d.CanCollide or d.CanQuery or d.CanTouch) then
		solid += 1
	end
end
check(solid == 0, `D3 plus aucune collision, contact ni requête sur la copie du serveur ({solid})`)
check(truck.OutlineHighlight.Enabled == false, "D4 contour éteint")
check(#notifies("The truck exploded: grab the boxes!") == 1, "D5 Notify « The truck exploded: grab the boxes! » à tous")
local fx = Workspace:FindFirstChildOfClass("Explosion")
check(fx ~= nil and fx.BlastPressure == 0 and fx.DestroyJointRadiusPercent == 0 and fx.Position == blast, "D6 explosion locale à BlastPoint, sans force ni dégât")

section("D'. 12 colis, 6 Standard, 4 Premium, 2 Luxe, tirés dans la zone 3")
local drops = truckDrops()
check(#drops == 12, `D7 12 colis ({#drops})`)
local tiers = {}
local fromSeen = {}
local inZone, labelsOk, noItemId, starts, onRoad, inRadius = true, true, true, true, true, true
for _, model in drops do
	local dropId = model:GetAttribute("DropId")
	local payload, position = Carry.GetDrop(dropId)
	local tier = model:GetAttribute("Tier")
	tiers[tier] = (tiers[tier] or 0) + 1
	local item = payload and Items.ById[payload.ItemId]
	if payload == nil or payload.Kind ~= "NPCBox" or payload.Zone ~= 3 or payload.Tier ~= tier or item == nil or item.Rarity ~= payload.Rarity or (item.Zone ~= 3 and payload.Rarity ~= "Secret") then
		inZone = false
	end
	if payload == nil or payload.StoreId ~= "Truck_1" or not string.match(payload.SlotId, "^Truck_1/%d%d$") then
		inZone = false
	end
	for name, value in model:GetAttributes() do
		if payload and value == payload.ItemId then
			noItemId = false
		end
	end
	local from = model:GetAttribute("FlightFrom")
	for i, p in spawnPoints do
		if (p - from).Magnitude < 1e-6 then
			fromSeen[i] = true
		end
	end
	local index = tonumber(string.match(payload.SlotId, "(%d%d)$"))
	if not near(model:GetAttribute("FlightStartsAt"), serverAt + (index - 1) * TruckEvent.LaunchStagger, 1e-6) or model:GetAttribute("FlightDuration") ~= TruckEvent.FlightTime then
		starts = false
	end
	if (spawnPoints[index] - from).Magnitude > 1e-6 then
		starts = false
	end
	if not near(position.Y, 0, 1e-6) then
		onRoad = false
	end
	local horizontal = Vector3.new(position.X - center.X, 0, position.Z - center.Z).Magnitude
	if horizontal < TruckEvent.ScatterMinRadius - 1e-6 or horizontal > TruckEvent.ScatterRadius + 1e-6 then
		inRadius = false
	end
	local label = model:FindFirstChild("BB_Box", true)
	local rarityLabel = label and label:FindFirstChild("Rarity", true)
	if rarityLabel == nil or rarityLabel.Text ~= Rarities.ById[payload.Rarity].DisplayNameUpper then
		labelsOk = false
	end
end
check(tiers.Standard == 6 and tiers.Premium == 4 and tiers.Luxe == 2, `D8 6 Standard, 4 Premium, 2 Luxe ({tiers.Standard}/{tiers.Premium}/{tiers.Luxe})`)
check(inZone, "D9 contenu tiré dans la zone 3 (objet de la zone et de sa rareté, ou Secret), StoreId Truck_1")
check(noItemId, "D10 l'objet reste secret : aucun attribut du colis ne porte son ItemId")
check(labelsOk, "D11 étiquette BB_Box : rareté du colis, comme un colis au sol")
local allSpawns = true
for i = 1, 12 do
	allSpawns = allSpawns and fromSeen[i] == true
end
check(allSpawns and starts, "D12 un colis par BoxSpawn_01 à _12, départs espacés de 0,04 s, vol de 1,1 s")
check(onRoad, "D13 posés au sol (sur la route)")
check(inRadius, "D14 de 6 à 15 studs du centre du camion")

section("D''. Vol avec la traînée (client)")
-- Le premier colis (départ à 0) : en l'air à 0,4 s, avec la traînée de Clément.
local first, last = nil, nil
for _, model in drops do
	local payload = Carry.GetDrop(model:GetAttribute("DropId"))
	local index = tonumber(string.match(payload.SlotId, "(%d%d)$"))
	if index == 1 then
		first = model
	elseif index == 12 then
		last = model
	end
end
local _, landing = Carry.GetDrop(first:GetAttribute("DropId"))
local landPivot = nil
advance(0.4)
local anchor = first.PrimaryPart
local trail = anchor:FindFirstChildOfClass("Trail")
check(trail ~= nil and trail.Enabled == true, "D15 traînée copiée sur le colis en vol")
check(trail and trail.Attachment0 and trail.Attachment0.Name == "TrailTop" and trail.Attachment0.Parent == anchor and trail.Attachment1.Name == "TrailBottom", "D16 ses deux Attachments copiés avec elle (TrailTop, TrailBottom)")
check(trail and trail.Lifetime == 0.5, "D17 réglages de Clément gardés (Lifetime)")
local midY = first:GetPivot().Position.Y
check(midY > landing.Y + 3, `D18 en l'air au milieu du vol (y = {midY})`)
local prompt = anchor:FindFirstChildOfClass("ProximityPrompt")
check(prompt ~= nil and prompt.Enabled == false, "D19 invite coupée pendant le vol")
advance(TruckEvent.FlightTime - 0.4 + 0.05)
-- Bloc V0 de CarryService (BOX_* pas livré) : 1,6 stud de haut, posé par le dessous sur le point d'arrivée.
local expected = landing + Vector3.new(0, 0.8, 0)
check((first.PrimaryPart.Position - expected).Magnitude < 1e-6, `D20 atterri pile à sa place serveur ({first.PrimaryPart.Position})`)
check(trail.Enabled == false, "D21 traînée coupée à l'atterrissage")
-- Copie a42 : quand plusieurs colis sont à portée, une seule invite reste allumée (le colis visé) ;
-- Alice s'éloigne donc pour que D22 et D26 voient l'invite de chaque colis atterri (aucun à portée).
moveTo(A, Vector3.new(240, 3, 200), Vector3.new(0, 0, -1))
advance(0.3)
check(prompt.Enabled == true, "D22 invite active une fois le colis atterri")
check(prompt.ActionText == "Grab" and prompt.ObjectText == `{Balance.Heist.BoxTiers[first:GetAttribute("Tier")].DisplayName} Box`, `D23 invite « {prompt.ActionText} » / « {prompt.ObjectText} »`)
check(prompt.HoldDuration == Balance.Heist.BoxTiers[first:GetAttribute("Tier")].GrabTime and prompt.MaxActivationDistance == 7.5, "D24 maintien du type du colis, portée 7,5")
advance(1)
check(trail.Parent == nil, "D25 traînée retirée quand sa queue a disparu")
local lastPrompt = last.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
check(lastPrompt.Enabled == true, "D26 le dernier colis (départ à 0,44 s) a atterri lui aussi")
moveTo(A, Vector3.new(240, 3, 10), Vector3.new(0, 0, -1)) -- copie a42 : retour près du camion

section("D'''. Les pièces volent puis s'effacent (client)")
-- Rejoué depuis le début : nouvelle explosion pour suivre les pièces.
advance(TruckEvent.RemoveDelay)
check(isDestroyed(truck) and #trucks() == 0, "D27 copie du camion retirée par le serveur 4,5 s après")
Workspace:SetAttribute("TruckSpawnNow", 3)
flush()
local truck2 = currentTruck()
local starts2 = {}
for _, piece in truck2.Pieces:GetChildren() do
	starts2[piece] = piece:GetBoundingBox().Position
end
local blast2 = truck2:FindFirstChild("BlastPoint", true).WorldPosition
fireAs(A, "HitWindow", truck2:GetAttribute("WindowId"))
advance(0.15)
fireAs(A, "HitWindow", truck2:GetAttribute("WindowId"))
flush()
-- À chaque image : le centre de chaque pièce reste au-dessus de la route (demi-hauteur 3,95).
local lowest = math.huge
ON_FRAME = function()
	for piece in starts2 do
		if piece.Parent ~= nil then
			lowest = math.min(lowest, piece:GetBoundingBox().Position.Y - 3.95)
		end
	end
end
advance(0.5)
local away, upright = 0, true
for piece, start in starts2 do
	local position = piece:GetBoundingBox().Position
	if (position - blast2).Magnitude > (start - blast2).Magnitude + 3 then
		away += 1
	end
	if not isOrthonormal(piece:GetPivot(), 1e-6) then
		upright = false
	end
end
check(away == 20, `D28 les 20 pièces s'écartent de BlastPoint ({away})`)
check(upright, "D29 rotations propres (orthonormées)")
advance(2)
check(lowest >= -1e-6, `D30 elles retombent sans passer sous la route (marge mini {lowest})`)
ON_FRAME = nil
local visible = true
for piece in starts2 do
	visible = visible and piece.Body.LocalTransparencyModifier == 0
end
check(visible, "D31 encore visibles avant DebrisLifetime (3 s)")
advance(TruckEvent.DebrisLifetime + TruckEvent.DebrisFadeTime - 2.5 + 0.1)
local faded = true
for piece in starts2 do
	faded = faded and piece.Body.LocalTransparencyModifier == 1
end
check(faded, "D32 effacées après DebrisLifetime + DebrisFadeTime (local : LocalTransparencyModifier)")
check(truck2.Parent ~= nil, "D33 … avant que le serveur retire la copie (RemoveDelay 4,5 s ≥ 3 + 1)")
advance(1)
check(isDestroyed(truck2), "D34 puis la copie est retirée")

section("D''''. Zone 1 : Communs seulement (L-033)")
Workspace:SetAttribute("TruckSpawnNow", 1)
flush()
local before = #truckDrops()
Workspace:SetAttribute("TruckSpawnNow", "Explode")
flush()
local commons, total = true, 0
for _, model in truckDrops() do
	local payload = Carry.GetDrop(model:GetAttribute("DropId"))
	if payload and payload.StoreId == "Truck_3" then
		total += 1
		commons = commons and payload.Rarity == "Common" and Items.ById[payload.ItemId].Zone == 1 and not Items.ById[payload.ItemId].TutorialOnly
	end
end
check(total == 12 and commons, `D35 zone 1 : 12 colis, tous Communs de la zone 1 ({total})`)

section("D'''''. Répartition des raretés sur beaucoup de camions (zone 6)")
local counts = {}
for _ = 1, 40 do
	advance(TruckEvent.RemoveDelay + 0.1)
	Workspace:SetAttribute("TruckSpawnNow", 6)
	flush()
	local t = currentTruck()
	local number = t:GetAttribute("TruckNumber")
	Workspace:SetAttribute("TruckSpawnNow", "Explode")
	flush()
	for _, model in truckDrops() do
		local payload = Carry.GetDrop(model:GetAttribute("DropId"))
		if payload and payload.StoreId == `Truck_{number}` then
			counts[payload.Tier] = counts[payload.Tier] or {}
			counts[payload.Tier][payload.Rarity] = (counts[payload.Tier][payload.Rarity] or 0) + 1
		end
	end
end
local odds = sharedModule("Config/ShelfBoxes").OddsFor(6, "Standard")
local commonStd = (counts.Standard and counts.Standard.Common or 0) / 240
check(math.abs(commonStd * 100 - (odds.Common or 0)) < 12, `D36 colis Standard de la zone 6 : {math.round(commonStd * 100)} % de Communs, ShelfBoxes.OddsFor en donne {odds.Common}`)
local excluded = {}
for tier, byRarity in counts do
	local tierOdds = sharedModule("Config/ShelfBoxes").OddsFor(6, tier)
	for rarity in byRarity do
		if (tierOdds[rarity] or 0) <= 0 then
			table.insert(excluded, `{tier} {rarity}`)
		end
	end
end
check(#excluded == 0, `D37 jamais une rareté que les probabilités du type excluent ({table.concat(excluded, ", ")})`)

summary("scénario explosion")
