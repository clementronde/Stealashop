--!nocheck
-- a130 (vague 39) : BatBoxKnockdown, champ Source : Store, Truck (« Truck_<n> ») et Fortune (« Truck_Fortune_<n> »,
-- colis de la vitrine de la Fortune Tower, catégorie à part). Mise en place de la copie a126 du banc a35, lue sur place.
startServer()
local cy = join("Cy", newProfile())
local dan = join("Dan", newProfile())
giveBat(cy)
giveBat(dan)
advance(1.2)
local function equipBat(player)
	if not holdsBat(player) then
		humanoidOf(player):EquipTool(batOf(player))
	end
end
local function boxPayload(zone, rarity, storeId)
	local def = Items.ByZone[zone][rarity][1]
	return { Kind = "NPCBox", Tier = "Premium", Zone = zone, Rarity = rarity, ItemId = def.Id, StoreId = storeId, SlotId = `{storeId}/01` }
end
local function knock(zone, rarity, storeId)
	moveTo(cy, Vector3.new(420, 3, 4), Vector3.new(0, 0, -1))
	equipBat(cy)
	moveTo(dan, Vector3.new(420, 3, 0), Vector3.new(0, 0, -1))
	check(CarryService.StartCarry(dan, boxPayload(zone, rarity, storeId)), `Dan porte un colis {storeId}`)
	advance(0.9)
	fireAs(cy, "SwingBat")
	flush()
	check(not CarryService.IsCarrying(dan), `le colis {storeId} tombe`)
	advance(3.2)
	local list = eventsNamed("BatBoxKnockdown")
	return list[#list], #list
end

section("T. Source du colis tombé")
local e, n = knock(2, "Rare", "STORE_Z2_Kiosque")
check(n == 1 and fieldOf(e, 3) == "Source - Store", `T1 magasin : Source - Store (trouvé {tostring(e and fieldOf(e, 3))})`)
e, n = knock(3, "Epic", "Truck_4")
check(n == 2 and fieldOf(e, 3) == "Source - Truck", `T2 camion : Source - Truck (trouvé {tostring(e and fieldOf(e, 3))})`)
e, n = knock(6, "Mythic", "Truck_Fortune_2")
check(n == 3 and fieldOf(e, 3) == "Source - Fortune", `T3 Fortune Tower : Source - Fortune (trouvé {tostring(e and fieldOf(e, 3))})`)
check(e and fieldOf(e, 1) == "Zone - 6" and fieldOf(e, 2) == "Rarity - Mythic", "T4 Zone et Rarity inchangés")
summary("scénario telem")
