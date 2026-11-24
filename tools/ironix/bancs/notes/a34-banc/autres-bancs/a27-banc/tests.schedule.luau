--!nocheck
-- B. Horaire de l'événement : jour seulement, un camion à la fois, place dans le couloir, départ au
-- bout de 3 min ou à l'alerte de la nuit.

local Night = serverModule("NightCycleService")
local TruckEvent = sharedModule("Config/TruckEvent")
startServer()

local maxTrucks = 0
local spawnTimes = {}
local seen = {}
ON_FRAME = function()
	local list = trucks()
	if #list > maxTrucks then
		maxTrucks = #list
	end
	for _, t in list do
		if not seen[t] then
			seen[t] = true
			table.insert(spawnTimes, now())
		end
	end
end
-- Avance jusqu'à l'apparition d'un camion (au plus `limit` s) ; renvoie l'heure ou nil.
local function waitTruck(limit)
	local deadline = now() + limit
	local count = #spawnTimes
	while now() < deadline do
		advance(0.1, 0.1)
		if #spawnTimes > count then
			return spawnTimes[#spawnTimes]
		end
	end
	return nil
end

-- Coins de la boîte du camion dans le monde.
local function worldCorners(model)
	local cf, size = model:GetBoundingBox()
	local out = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, cf * Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2))
			end
		end
	end
	return out
end

section("B. Apparition de jour, toutes les 8 à 12 min")
advance(TruckEvent.SpawnIntervalMin - 1, 0.1)
check(#trucks() == 0, "B1 aucun camion avant 8 min")
local first = waitTruck(TruckEvent.SpawnIntervalMax - TruckEvent.SpawnIntervalMin + 2)
check(first ~= nil and first >= TruckEvent.SpawnIntervalMin - 0.05 and first <= TruckEvent.SpawnIntervalMax + 0.2, `B2 premier camion entre 8 et 12 min ({first})`)
local truck = currentTruck()
local zone = truck and truck:GetAttribute("Zone")
check(type(zone) == "number" and zone >= 1 and zone <= 6, `B3 zone tirée de 1 à 6 ({zone})`)
local pivot = truck:GetPivot()
check(
	near(pivot.Position.X, STORE_X[zone], 1e-6) and near(pivot.Position.Z, 0, 1e-6) and near(pivot.Position.Y, 0, 1e-6),
	`B4 au milieu de la chaussée, entre les deux magasins de la zone, posé sur la route ({pivot.Position})`
)
check(math.abs(pivot.ZVector.X) > 0.9999 and math.abs(pivot.UpVector.Y) > 0.9999, "B5 en long dans le sens du couloir (axe Z du camion le long de X)")
local maxZ, minY = 0, math.huge
for _, corner in worldCorners(truck) do
	maxZ = math.max(maxZ, math.abs(corner.Z))
	minY = math.min(minY, corner.Y)
end
check(maxZ <= 6.3 + 1e-6 and 30.75 - maxZ >= 24, `B6 ne bloque pas les vitrines (bord à {maxZ} studs du milieu, 24 studs libres devant chaque vitrine)`)
check(near(minY, 0, 1e-6), "B7 posé sur la route, pas dedans")
local spawned = notifies(`A truck appeared in Zone {zone}! Break it together!`)
check(#spawned == 1 and spawned[1].to == nil, "B8 Notify en anglais à tous (FireAll)")
check(truck.Name == "EventTruck" and truck.Parent == Workspace, "B9 copie EventTruck dans le Workspace")
check(truck:GetAttribute("MaxHP") == 1000 and truck:GetAttribute("HP") == 1000 and hasTag(truck, "HitTarget"), "B10 cible de 1000 PV (WindowService)")
check(truck:GetAttribute("WindowId") == "EventTruck" and truck:GetAttribute("Broken") == false, "B11 attributs de WindowService posés")
local outline = truck:FindFirstChild("OutlineHighlight")
check(outline ~= nil and outline.Enabled == true, "B12 contour OutlineHighlight du modèle")
local anchored = true
for _, d in truck:GetDescendants() do
	if d:IsA("BasePart") and not d.Anchored then
		anchored = false
	end
end
check(anchored, "B13 toutes les pièces ancrées")

section("B'. Départ au bout de 3 min, sans rien lâcher")
advance(TruckEvent.Lifetime - (now() - first) - 0.5, 0.1)
check(currentTruck() == truck, "B14 encore là à 2 min 59")
advance(1, 0.1)
check(#trucks() == 0 and isDestroyed(truck), "B15 parti au bout de 3 min")
check(#notifies("The truck drove away.") == 1, "B16 Notify « The truck drove away. »")
check(#truckDrops() == 0 and not hasTag(truck, "HitTarget"), "B17 aucun colis lâché, plus une cible")

section("B''. Le suivant, compté depuis l'apparition du précédent")
local second = waitTruck(TruckEvent.SpawnIntervalMax + 1)
check(
	second ~= nil and second - first >= TruckEvent.SpawnIntervalMin - 0.15 and second - first <= TruckEvent.SpawnIntervalMax + 0.15,
	`B18 second camion 8 à 12 min après le premier ({second and second - first})`
)
local t2 = currentTruck()
Night._set("Warning", 30)
flush()
check(t2 ~= nil and isDestroyed(t2), "B19 parti dès que l'alerte de la nuit commence")
check(#notifies("Night is coming: the truck drove away.") == 1, "B20 Notify « Night is coming: the truck drove away. »")

section("B'''. Jamais pendant l'alerte ni la nuit")
advance(30, 0.25)
Night._set("Night", 120)
advance(24 * 60, 0.25)
check(#trucks() == 0, "B21 aucun camion pendant 24 min d'alerte et de nuit")
Night._set("Day", 450) -- aube
local dawn = now()
local third = waitTruck(TruckEvent.DawnDelay + 2)
check(third ~= nil and third - dawn >= TruckEvent.DawnDelay - 0.05 and third - dawn <= TruckEvent.DawnDelay + 0.2, `B22 le camion en retard arrive 30 s après l'aube ({third and third - dawn})`)

section("B''''. Pas si l'alerte tombe dans moins de 60 s")
Workspace:SetAttribute("TruckSpawnNow", "Leave")
flush()
check(#trucks() == 0, "B23 (crochet Leave) plus de camion")
local spawnsBefore = #spawnTimes
ON_FRAME = function()
	Night._set("Day", TruckEvent.MinDayLeft - 10) -- même phase : seule l'heure de fin bouge
	local list = trucks()
	if #list > maxTrucks then
		maxTrucks = #list
	end
	for _, t in list do
		if not seen[t] then
			seen[t] = true
			table.insert(spawnTimes, now())
		end
	end
end
advance(13 * 60, 0.25)
check(#spawnTimes == spawnsBefore, "B24 13 min avec moins de 60 s avant l'alerte : aucun camion")
ON_FRAME = function()
	for _, t in trucks() do
		if not seen[t] then
			seen[t] = true
			table.insert(spawnTimes, now())
		end
	end
end
Night._set("Day", 300)
local fourth = waitTruck(1)
check(fourth ~= nil, "B25 dès qu'il reste assez de jour, le camion en retard arrive")
check(maxTrucks == 1, `B26 jamais plus d'un camion à la fois (max vu : {maxTrucks})`)

summary("scénario horaire")
