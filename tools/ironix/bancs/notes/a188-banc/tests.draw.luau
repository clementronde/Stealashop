--!nocheck
-- Banc a188, scénario draw : format et valeurs, StoreHeistService.DrawForZone, CarryService.PlaceItemDrop.

buildRainMap()
startRain()
local A = player("Alice", Vector3.new(60, 3, 10))
flush()
local Zones = sharedModule("Config/Zones")
local ShelfBoxes = sharedModule("Config/ShelfBoxes")
local Telemetry = sharedModule("Config/Telemetry")
local MODE = SO.LuckBoost

section("C. Format ItemRain et valeurs")
local format = LiveEvents.ById[IR.EventId]
check(IR.EventId == "ItemRain" and format ~= nil, "C1 format ItemRain dans Config/LiveEvents")
check(format and format.Duration == 15 * 60, "C2 durée : 15 min")
check(format and next(format.Effects) == nil, "C3 aucun facteur")
check(format and type(format.DisplayName) == "string" and #format.DisplayName > 0 and #format.Effect > 0, "C4 titre et texte de la bannière")
local planned = false
for _, slot in LiveEvents.Slots do
	planned = planned or slot.Event == IR.EventId
end
for _, entry in LiveEvents.Schedule do
	planned = planned or entry.Event == IR.EventId
end
for _, entry in LiveEvents.Weekly or {} do
	planned = planned or entry.Event == IR.EventId
end
check(not planned, "C5 aucune date : le format n'est dans aucun planning")
check(sharedModule("AdminLists").Has("Events", IR.EventId), "C6 au panel admin (liste Events)")
check(IR.DropEvery > 0 and IR.MaxOnGround >= 1 and IR.Lifetime > 0 and IR.FallTime < IR.Lifetime, "C7 rythme, plafond, durée au sol")
check(string.sub(IR.StoreId, 1, 6) == "Truck_", "C8 origine au préfixe des événements (pas de vigile de jour)")
check(Telemetry.Events.ItemRainPickup ~= nil and Telemetry.Events.ItemRainBanked ~= nil, "C9 télémétrie : ItemRainPickup et ItemRainBanked")
check(string.find(IR.Messages.Started, "%s", 1, true) ~= nil and #IR.Messages.Ended > 0, "C10 textes de début et de fin")
local zonesOk = #IR.Zones > 0
for _, z in IR.Zones do
	zonesOk = zonesOk and Zones[z] ~= nil
end
check(zonesOk, "C11 zones de la pluie connues")

section("D. DrawForZone : comme sur un rayon de la zone")
check(type(Heist.DrawForZone) == "function", "D0 StoreHeistService.DrawForZone existe")
-- Zone 1 : toute caisse est Commune (ShelfBoxes.ZoneOdds), quel que soit son type. Tirages forcés : rareté de la
-- caisse, chance, rareté de l'objet.
local lucks = luckValues()
for _, luck in { lucks[1], lucks[#lucks] } do
	local list = bands("Common", luck, MODE)
	for _, v in { 0.0001, 0.35, 0.7, 0.93, 0.9995 } do
		table.clear(HEIST_FORCED)
		table.insert(HEIST_FORCED, 0.5)
		table.insert(HEIST_FORCED, luckRoll(luck))
		table.insert(HEIST_FORCED, v)
		local content, got = Heist.DrawForZone(1)
		local left = #HEIST_FORCED
		table.clear(HEIST_FORCED)
		local want = expectedAt(list, v)
		local item = content and Items.ById[content.ItemId]
		check(left == 0 and got == luck, `D1 zone 1, chance ×{luck}, tirage {v} : trois tirages lus, chance rendue ({got})`)
		check(content ~= nil and content.Rarity == want, `D2 zone 1, chance ×{luck}, tirage {v} : objet {want} (caisse Commune) ({content and content.Rarity})`)
		check(item ~= nil and item.Rarity == content.Rarity and not item.TutorialOnly, `D3 objet du catalogue, de cette rareté ({content and content.ItemId})`)
		local zone = zoneFor(1, want)
		check(item ~= nil and (zone == nil or item.Zone == zone), `D4 objet de la zone 1, sinon de la plus proche ({item and item.Zone})`)
	end
end
-- Zone 2 : tirage le plus bas partout : la caisse est la plus basse de son type, l'objet le plus bas de cette caisse.
local expected = {}
for _, tier in { "Standard", "Premium", "Luxe" } do
	local odds = ShelfBoxes.OddsFor(2, tier)
	for _, r in Rarities.List do
		if (odds[r.Id] or 0) > 0 then
			expected[expectedAt(bands(r.Id, 1, MODE), 0)] = true
			break
		end
	end
end
local inSet, zoneOk, seen = true, true, {}
for _ = 1, 120 do
	table.clear(HEIST_FORCED)
	table.insert(HEIST_FORCED, 0)
	table.insert(HEIST_FORCED, luckRoll(1))
	table.insert(HEIST_FORCED, 0)
	local content = Heist.DrawForZone(2)
	table.clear(HEIST_FORCED)
	inSet = inSet and content ~= nil and expected[content.Rarity] == true
	if content then
		seen[content.Rarity] = true
		local item = Items.ById[content.ItemId]
		local zone = zoneFor(2, content.Rarity)
		zoneOk = zoneOk and item ~= nil and (zone == nil or item.Zone == zone)
	end
end
local all = true
for rarity in expected do
	all = all and seen[rarity] == true
end
check(inSet, "D5 zone 2, tirages au plus bas : la rareté la plus basse d'une caisse Standard, Premium ou Luxe")
check(all, "D6 zone 2 : les trois types de caisse sortent (répartition d'un remplissage)")
check(zoneOk, "D7 zone 2 : objets de la zone 2, sinon de la plus proche")
-- Tirages libres : toujours un objet valide.
local valid, luckOk, mutationOk = true, true, true
for zone in Zones do
	for _ = 1, 60 do
		local content, luck = Heist.DrawForZone(zone)
		local item = content and Items.ById[content.ItemId]
		valid = valid and item ~= nil and item.Rarity == content.Rarity and not item.TutorialOnly
		luckOk = luckOk and type(luck) == "number" and luck >= 1
		mutationOk = mutationOk and content ~= nil and Mutations.IsValid(content.Mutation)
	end
end
check(valid, "D8 tirages libres, zones 1 à 6 : un objet du catalogue à chaque fois")
check(luckOk and mutationOk, "D9 chance ≥ 1 et mutation valide")

section("P. CarryService.PlaceItemDrop")
local function npc(overrides)
	local payload = { Kind = "NPCItem", Zone = 1, Rarity = "Rare", ItemId = "Z1_PotDeNouilles", StoreId = IR.StoreId, SlotId = IR.SlotId, Luck = 1 }
	for k, v in overrides or {} do
		payload[k] = v
	end
	return payload
end
if Items.ById.Z1_PotDeNouilles == nil or Items.ById.Z1_PotDeNouilles.Rarity ~= "Rare" then
	-- Catalogue changé : un objet Rare de la zone 1, quel qu'il soit.
	local any = Items.ByZone[1].Rare[1]
	local base = npc
	npc = function(overrides)
		local payload = base(overrides)
		payload.ItemId = if overrides and overrides.ItemId then overrides.ItemId else any.Id
		return payload
	end
end
local spot = Vector3.new(60, STREET_TOP, 5)
clearLog()
local p1 = npc({ Mutation = Mutations.Sanitize({ Size = Mutations.Sizes[1].Id }) })
local id1, model1 = Carry.PlaceItemDrop(p1, spot, 20)
check(type(id1) == "string" and model1 ~= nil and model1.Parent == dropsFolder(), "P1 posé : dropId et modèle dans Workspace/CarryDrops")
local payloadBack, positionBack = Carry.GetDrop(id1)
check(payloadBack == p1 and positionBack == spot, "P2 GetDrop : même payload, même point du sol")
check(Carry.IsFallenDrop(id1) == true, "P3 IsFallenDrop : GrabDropped l'accepte")
check(model1:GetAttribute("BatDrop") == true and model1:GetAttribute("DropId") == id1 and model1:GetAttribute("ItemId") == p1.ItemId, "P4 attributs BatDrop, DropId, ItemId (invite de BatController)")
check(model1:GetAttribute("MutationSize") == Mutations.Sizes[1].Id, "P5 attribut MutationSize")
check(logCount("refusé", "WARN") == 0, "P6 aucun avertissement")
local refusals = {
	{ function() return Carry.PlaceItemDrop(p1, Vector3.new(70, STREET_TOP, 5), 20) end, "déjà porté ou au sol" },
	{ function() return Carry.PlaceItemDrop({ Kind = "PlayerItem", ItemUid = "u1", ItemId = p1.ItemId, Rarity = "Rare", Income = 1, VictimUserId = 9, SlotIndex = 1 }, spot, 20) end, "seul un objet NPCItem" },
	{ function() return Carry.PlaceItemDrop(npc({ Zone = 99 }), spot, 20) end, "zone inconnue" },
	{ function() return Carry.PlaceItemDrop(npc(), "ici", 20) end, "position invalide" },
	{ function() return Carry.PlaceItemDrop(npc(), spot, 0) end, "durée au sol invalide" },
	{ function() return Carry.PlaceItemDrop(npc(), spot, math.huge) end, "durée au sol invalide" },
}
for _, case in refusals do
	clearLog()
	local before = #dropsFolder():GetChildren()
	local id, model = case[1]()
	check(id == nil and model == nil and #dropsFolder():GetChildren() == before and logCount(case[2], "WARN") == 1, "P7 refus : " .. case[2])
end
local expired = {}
Carry.OnDropExpired(function(dropId, payload)
	table.insert(expired, { id = dropId, payload = payload })
end)
advance(19.8)
check(Carry.GetDrop(id1) == p1, "P8 encore au sol avant la fin de sa durée")
advance(0.4)
check(Carry.GetDrop(id1) == nil and model1.Parent == nil and #expired == 1 and expired[1].payload == p1, "P9 au bout de sa durée : retiré, OnDropExpired")
local p2 = npc()
local id2 = Carry.PlaceItemDrop(p2, spot, 30)
check(grabDrop(A, id2) and Carry.GetPayload(A) == p2, "P10 ramassé par GrabDropped : même payload sur la tête")
check(Carry.GetDrop(id2) == nil, "P11 plus au sol")
advance(3)
check(#guards() == 0, "P12 aucun vigile ne sort")
check(logCount("introuvable", "WARN") == 0, "P13 aucun avertissement de magasin introuvable")

summary("scénario draw")
if FAILS > 0 then
	for _, line in LOG do
		if line.kind == "WARN" then
			print("    [WARN] " .. line.text)
		end
	end
end
