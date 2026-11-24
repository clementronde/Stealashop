--!nocheck
-- B. Colis lâchés par le camion qui ne se chevauchent pas (demande d'Ironix du 2026-11-08) :
-- au moins BoxGap studs bord à bord entre deux colis, d'après la largeur des modèles BOX_<Tier>,
-- dans le cercle ScatterMinRadius à ScatterRadius tant que la place suffit, recalé plus loin sinon,
-- et jamais sur un colis déjà au sol.

local TruckEvent = sharedModule("Config/TruckEvent")
local Carry = serverModule("CarryService")
startServer()

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local WIDTH = { Standard = 2, Premium = 2.4, Luxe = 3.2 } -- BOX_SIZES du setup (X = Z)

-- Colis au sol du camion en jeu : position (CarryService) et largeur selon leur type.
local function landed(truckNumber)
	local out = {}
	for _, model in truckDrops() do
		local payload, position = Carry.GetDrop(model:GetAttribute("DropId"))
		if payload and (truckNumber == nil or payload.StoreId == `Truck_{truckNumber}`) then
			table.insert(out, { position = position, width = WIDTH[payload.Tier], tier = payload.Tier, model = model })
		end
	end
	return out
end
-- Plus petite marge bord à bord entre deux colis de la liste.
local function minGap(list)
	local worst = math.huge
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			local gap = flat(a.position - b.position).Magnitude - (a.width + b.width) / 2
			worst = math.min(worst, gap)
		end
	end
	return worst
end

section("B. Valeurs")
check(TruckEvent.BoxGap == 1 and TruckEvent.BoxFallbackWidth == 2 and TruckEvent.GrabCameraWeight == 0.5, "B1 V0 : 1 stud entre deux colis, 2 studs sans modèle, poids de la caméra 0,5")

section("B'. Une explosion par zone, deux fois : jamais deux colis l'un dans l'autre")
local worstGap, worstRadius, minRadius, explosions = math.huge, 0, math.huge, 0
local allInside = true
for round = 1, 2 do
	for zone = 1, 6 do
		Workspace:SetAttribute("TruckSpawnNow", zone)
		flush()
		local truck = trucks()[1]
		local center = truck:GetPivot().Position
		local number = truck:GetAttribute("TruckNumber")
		Workspace:SetAttribute("TruckSpawnNow", "Explode")
		flush()
		explosions += 1
		local list = landed(number)
		if #list ~= 12 then
			check(false, `B2 explosion {explosions} (zone {zone}) : 12 colis attendus, {#list}`)
		end
		worstGap = math.min(worstGap, minGap(list))
		for _, box in list do
			local r = flat(box.position - center).Magnitude
			worstRadius = math.max(worstRadius, r)
			minRadius = math.min(minRadius, r)
			if r > TruckEvent.ScatterRadius + 1e-6 or r < TruckEvent.ScatterMinRadius - 1e-6 then
				allInside = false
			end
		end
		advance(5) -- le camion explosé est retiré (RemoveDelay)
	end
end
check(explosions == 12, `B3 12 explosions ({explosions})`)
check(worstGap >= TruckEvent.BoxGap - 1e-6, `B4 entre deux colis d'une même explosion, au moins 1 stud bord à bord (pire : {math.floor(worstGap * 100) / 100})`)
check(allInside, `B5 tous dans le cercle {TruckEvent.ScatterMinRadius} à {TruckEvent.ScatterRadius} studs (de {math.floor(minRadius * 10) / 10} à {math.floor(worstRadius * 10) / 10})`)
local everything = landed(nil)
check(minGap(everything) >= TruckEvent.BoxGap - 1e-6, `B6 colis de deux camions de la même zone : jamais l'un sur l'autre non plus ({#everything} au sol)`)

section("B''. Sans place libre : recalé plus loin, jamais dessus")
advance(70) -- tous les colis précédents ont disparu (BoxLifetime)
check(#truckDrops() == 0, "B7 sol vidé")
Workspace:SetAttribute("TruckSpawnNow", 2)
flush()
local truck = trucks()[1]
local center = truck:GetPivot().Position
-- Le cercle 6–15 studs est couvert de colis posés au sol (coups de batte), tous les 2,2 studs.
local fillers = {}
local rarities = { "Common" }
local n = 0
for x = -16, 16, 3.3 do
	for z = -16, 16, 3.3 do
		local r = math.sqrt(x * x + z * z)
		if r >= 5 and r <= 16.5 then
			n += 1
			local id = Carry.PlaceDrop({ Kind = "NPCBox", Tier = "Standard", Zone = 2, Rarity = "Common", ItemId = "Z2_BallonDeFoot", StoreId = "Filler", SlotId = `Filler/{n}` }, center + Vector3.new(x, 0, z), 300)
			if id then
				table.insert(fillers, id)
			end
		end
	end
end
check(#fillers > 60, `B8 {#fillers} colis posés autour du camion`)
local number = truck:GetAttribute("TruckNumber")
Workspace:SetAttribute("TruckSpawnNow", "Explode")
flush()
local list = landed(number)
local fillerList = {}
for _, id in fillers do
	local payload, position = Carry.GetDrop(id)
	if payload then
		table.insert(fillerList, { position = position, width = 2 })
	end
end
local beyond = 0
for _, box in list do
	if flat(box.position - center).Magnitude > TruckEvent.ScatterRadius + 1e-6 then
		beyond += 1
	end
end
local combined = table.clone(list)
for _, f in fillerList do
	table.insert(combined, f)
end
check(#list == 12, `B9 les 12 colis sont lâchés ({#list})`)
check(beyond > 0, `B10 cercle plein : recalés au-delà de {TruckEvent.ScatterRadius} studs ({beyond} colis)`)
check(minGap(combined) >= TruckEvent.BoxGap - 1e-6, `B11 aucun sur un autre colis (pire marge : {math.floor(minGap(combined) * 100) / 100})`)
check(logCount("", "WARN", "server") == 0, "B12 aucun avertissement côté serveur")

summary("scénario colis du camion")
