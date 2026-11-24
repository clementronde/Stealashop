--!nocheck
-- Banc a188, scénario rain : la pluie d'objets de bout en bout (vrai ItemRainService, vrais CarryService, BatService,
-- GuardService et StoreHeistService).

buildRainMap()
startRain()
local A = player("Alice", Vector3.new(60, 3, 10)) -- rue de la zone 1
local B = player("Bob", Vector3.new(135, 3, 10)) -- rue de la zone 2
flush()
watchRain()
local EPS = FRAME + 0.01 -- un objet est relevé à l'image où il apparaît
local TICK = IR.TickInterval
local function startNotifies()
	return #notifies("ITEM RAIN!")
end
local function endNotifies()
	return #notifies(IR.Messages.Ended)
end

section("R1 Sans événement : rien ne tombe")
advance(IR.DropEvery * 2 + 1)
check(#RECORDS == 0 and dropsFolder() == nil, "R1a aucun objet au sol")
check(startNotifies() == 0 and endNotifies() == 0, "R1b aucune annonce")
check(Rain.IsRaining() == false, "R1c IsRaining : false")
-- Un autre événement live ne fait rien tomber.
Workspace:SetAttribute(LiveEvents.IdAttribute, "PotionRain")
advance(IR.DropEvery + 1)
check(#RECORDS == 0 and startNotifies() == 0, "R1d un autre événement live (PotionRain) : rien")
Workspace:SetAttribute(LiveEvents.IdAttribute, nil)
advance(TICK + 0.1)
check(endNotifies() == 0, "R1e sa fin : pas d'annonce de fin de pluie")

section("R2 Début : annonce, premier objet, chute")
startEvent()
advance(TICK + 0.1)
check(Rain.IsRaining() == true, "R2a IsRaining : true")
local starts = notifies("ITEM RAIN!")
check(#starts == 1 and starts[1].to == nil, "R2b une annonce à tout le serveur")
check(#starts == 1 and string.find(starts[1].args[1], "15:00", 1, true) ~= nil and starts[1].args[2] == "Info", "R2c avec le temps restant (15:00), style Info")
check(#RECORDS == 1, "R2d le premier objet tombe tout de suite (" .. #RECORDS .. ")")
local first = RECORDS[1]
if first then
	local m = first.model
	check(m:GetAttribute("BatDrop") == true and m:GetAttribute("ItemId") == first.payload.ItemId, "R2e au sol comme un objet lâché : attributs BatDrop et ItemId")
	check(Carry.IsFallenDrop(first.id) == true, "R2f ramassable par GrabDropped (IsFallenDrop)")
	check(first.payload.Kind == "NPCItem" and first.payload.StoreId == IR.StoreId and first.payload.SlotId == IR.SlotId, "R2g objet NPCItem, origine de la pluie")
	advance(IR.FallTime + 0.2)
	local landedY = m:GetPivot().Position.Y
	check(near(first.startY - landedY, IR.FallHeight, IR.FallHeight * 0.05), `R2h il part de {IR.FallHeight} studs au-dessus de son point ({first.startY - landedY})`)
	check(not first.rose and near(first.lowestY, landedY, 1e-6), "R2i il descend sans jamais remonter, jusqu'à son point")
	local pivot = m:GetPivot().Position
	check(near(pivot.X, first.position.X, 1e-3) and near(pivot.Z, first.position.Z, 1e-3) and math.abs(landedY - first.position.Y) < 2, "R2j posé sur son point du sol")
	advance(1)
	check(near(m:GetPivot().Position.Y, landedY, 1e-6), "R2k il ne bouge plus une fois posé")
end

section("R3 La nuit : rien ne tombe, l'événement continue")
local beforeNight = #RECORDS
Night._set("Night")
advance(IR.DropEvery * 3)
check(#RECORDS == beforeNight, "R3a aucun objet pendant la nuit (" .. (#RECORDS - beforeNight) .. ")")
check(Rain.IsRaining() == true and endNotifies() == 0, "R3b l'événement tourne toujours, pas d'annonce de fin")
Night._set("Day")
advance(IR.DropEvery + TICK + 0.1)
check(#RECORDS == beforeNight + 1, "R3c au jour, la pluie reprend (" .. (#RECORDS - beforeNight) .. ")")

section("R4 Fin : annonce, plus rien ne tombe, disparition")
stopEvent()
advance(TICK + 0.1)
check(Rain.IsRaining() == false, "R4a IsRaining : false")
local ends = notifies(IR.Messages.Ended)
check(#ends == 1 and ends[1].to == nil, "R4b une annonce de fin à tout le serveur")
check(logCount("fin de la pluie", "PRINT") == 1, "R4c bilan dans la sortie")
local atEnd = #RECORDS
local stillThere = groundCount()
check(stillThere == atEnd and atEnd == 2, "R4d les objets déjà au sol y restent (" .. stillThere .. ")")
advance(IR.DropEvery * 3)
check(#RECORDS == atEnd, "R4e plus rien ne tombe (" .. (#RECORDS - atEnd) .. ")")
-- Disparition : chaque objet pas ramassé part Lifetime s après être tombé.
local lifeOk, goneOk = true, true
for _, rec in RECORDS do
	local left = rec.t + IR.Lifetime - now()
	if left > 0.3 then
		advance(left - 0.2)
	end
	lifeOk = lifeOk and onGround(rec) and rec.model.Parent ~= nil
	advance(0.4)
	goneOk = goneOk and Carry.GetDrop(rec.id) == nil and rec.model.Parent == nil
end
check(lifeOk, `R4f encore là juste avant {IR.Lifetime} s`)
check(goneOk, `R4g disparu au bout de {IR.Lifetime} s (modèle retiré)`)
check(groundCount() == 0 and Rain.GetStats().OnGround == 0, "R4h plus aucun objet de la pluie au sol")
check(endNotifies() == 1 and startNotifies() == 1, "R4i aucune autre annonce")
check(logCount("ItemRainService", "WARN") == 0, "R4j aucun avertissement d'ItemRainService")

section("R5 Rythme et plafond")
local base = #RECORDS
startEvent()
advance(TICK + 0.1)
check(startNotifies() == 2, "R5a relancée : nouvelle annonce")
check(#RECORDS == base + 1, "R5b premier objet tout de suite")
local t0 = RECORDS[base + 1] and RECORDS[base + 1].t or now()
local capBinds = IR.Lifetime > (IR.MaxOnGround + 1) * IR.DropEvery + 1
-- Jusqu'au plafond : un objet toutes les DropEvery s.
advance(t0 + (IR.MaxOnGround - 1) * IR.DropEvery + TICK + 0.1 - now())
check(#RECORDS == base + IR.MaxOnGround, `R5c {IR.MaxOnGround} objets en {(IR.MaxOnGround - 1) * IR.DropEvery} s ({#RECORDS - base})`)
local rhythm = true
for i = base + 2, #RECORDS do
	local gap = RECORDS[i].t - RECORDS[i - 1].t
	rhythm = rhythm and gap >= IR.DropEvery - EPS and gap <= IR.DropEvery + TICK + EPS
end
check(rhythm, `R5d un objet toutes les {IR.DropEvery} s`)
check(groundCount() == IR.MaxOnGround and Rain.GetStats().OnGround == IR.MaxOnGround, "R5e plafond atteint")
if capBinds then
	advance(IR.DropEvery * 2 + 0.2)
	check(#RECORDS == base + IR.MaxOnGround, "R5f au plafond, rien ne tombe pendant deux tours (" .. (#RECORDS - base - IR.MaxOnGround) .. ")")
	-- Le premier objet disparaît à t0 + Lifetime : une place se libère, la pluie reprend.
	advance(t0 + IR.Lifetime + IR.DropEvery + TICK + 0.1 - now())
	local more = #RECORDS - base - IR.MaxOnGround
	check(more >= 1 and more <= 2, "R5g une place libérée par une disparition : la pluie reprend (" .. more .. ")")
else
	print("    R5f, R5g sautés : avec ces valeurs, le plafond ne tient pas deux tours")
end
check(MAX_GROUND <= IR.MaxOnGround, `R5h jamais plus de {IR.MaxOnGround} objets de la pluie au sol ({MAX_GROUND})`)
check(MAX_NEW_PER_FRAME <= 1, "R5i jamais deux objets créés dans la même image (" .. MAX_NEW_PER_FRAME .. ")")
local stats = Rain.GetStats()
check(stats.Dropped == #RECORDS - base and stats.PickedUp == 0 and stats.Banked == 0, "R5j bilan : objets tombés depuis le début de cette pluie")

section("R6 Ramassage, port, télémétrie")
local function landed()
	for i = #RECORDS, 1, -1 do
		local rec = RECORDS[i]
		if onGround(rec) and now() - rec.t > IR.FallTime + 0.1 and rec.t + IR.Lifetime - now() > 8 then
			return rec
		end
	end
	return nil
end
local rec1 = landed()
check(rec1 ~= nil, "R6a un objet posé à ramasser")
if rec1 then
	local before = groundCount()
	check(grabDrop(A, rec1.id) and Carry.GetPayload(A) == rec1.payload, "R6b Alice le ramasse (GrabDropped, maintien) : le même objet sur la tête")
	check(A:GetAttribute("Carrying") == rec1.payload.Rarity, "R6c porté comme un objet volé au magasin (attribut Carrying)")
	check(groundCount() == before - 1 and rec1.model.Parent == nil, "R6d il n'est plus au sol")
	local picks = telemetry("ItemRainPickup", A)
	check(#picks == 1 and picks[1].fields[1] == `Zone - {rec1.payload.Zone}` and picks[1].fields[2] == `Rarity - {rec1.payload.Rarity}`, "R6e télémétrie ItemRainPickup (Zone, Rarity)")
	check(Rain.GetStats().PickedUp == 1, "R6f bilan : 1 ramassé")
	advance(3)
	check(#guards() == 0, "R6g sans vigile : aucun ne sort")
	check(logCount("introuvable", "WARN") == 0, "R6h aucun avertissement de magasin introuvable")
	-- Rangé en base (ce que fait UnboxService à l'entrée de la zone safe).
	check(Carry.Consume(A, "Stored") == rec1.payload, "R6i rangé en base")
	local banks = telemetry("ItemRainBanked", A)
	check(#banks == 1 and banks[1].fields[1] == `Zone - {rec1.payload.Zone}`, "R6j télémétrie ItemRainBanked")
	check(Rain.GetStats().Banked == 1, "R6k bilan : 1 rangé")
end
-- Lâché (touche G) : il retombe comme tout objet, n'importe qui le reprend ; il ne compte plus dans le plafond.
local rec2 = landed()
check(rec2 ~= nil, "R6l un deuxième objet posé")
if rec2 then
	check(grabDrop(B, rec2.id), "R6m Bob en ramasse un")
	local rainGround = Rain.GetStats().OnGround
	local released = Carry.Drop(B, nil, "Released")
	check(released ~= nil and Carry.GetDrop(released) == rec2.payload, "R6n lâché : au sol sous lui")
	check(Rain.GetStats().OnGround == rainGround, "R6o un objet relâché ne compte pas dans le plafond de la pluie")
	check(grabDrop(A, released) and Carry.GetPayload(A) == rec2.payload, "R6p Alice le reprend")
	check(#telemetry("ItemRainPickup") == 2, "R6q ItemRainPickup une seule fois par objet (1re prise)")
	-- Relâché et jamais repris : il disparaît (pas de rayon où revenir), sans doublon.
	local again = Carry.Drop(A, nil, "Released")
	advance(BatCfg.DroppedLifetime + 0.3)
	check(again ~= nil and Carry.GetDrop(again) == nil, "R6r relâché et pas repris : disparu au bout de Bat.DroppedLifetime")
	check(#census().duplicates == 0, "R6s aucun doublon")
	check(#telemetry("ItemRainBanked") == 1, "R6t pas compté comme rangé")
end
-- Mort du porteur : l'objet est perdu.
local rec3 = landed()
if rec3 and grabDrop(B, rec3.id) then
	humanoidOf(B).Health = 0
	humanoidOf(B).Died:Fire()
	flush()
	check(not Carry.IsCarrying(B) and Carry.GetDrop(rec3.id) == nil, "R6u porteur mort : l'objet est perdu")
	spawnCharacter(B, Vector3.new(135, 3, 10))
else
	check(false, "R6u un troisième objet à ramasser")
end
check(logCount("ItemRainService", "WARN") == 0, "R6v aucun avertissement d'ItemRainService")

section("R7 Lieu et zone de chaque objet tombé (" .. #RECORDS .. ")")
local hz = STREET_1.Size.Z / 2 - IR.EdgeMargin
local onStreet, margins, corridor, hub, arch, spacing, zones, drawn, valid = true, true, true, true, true, true, true, true, true
local perZone = { 0, 0 }
check(#DRAWS == #RECORDS, `R7a un tirage DrawForZone par objet tombé ({#DRAWS} pour {#RECORDS})`)
for i, rec in RECORDS do
	local p = rec.position
	onStreet = onStreet and near(p.Y, STREET_TOP, 1e-6)
	local in1 = p.X >= 0 + IR.EdgeMargin - 1e-6 and p.X <= 100 - IR.EdgeMargin + 1e-6
	local in2 = p.X >= 100 + IR.EdgeMargin - 1e-6 and p.X <= 200 - IR.EdgeMargin + 1e-6
	margins = margins and (in1 or in2) and math.abs(p.Z) <= hz + 1e-6
	corridor = corridor and p.X > 27
	hub = hub and p.X > 25 -- jamais dans le volume SafeZone (x ≤ 25), donc jamais sur la rue du hub
	arch = arch and math.abs(p.X - 150) > 2 + IR.Clearance - 1e-6
	spacing = spacing and rec.nearest >= IR.MinSpacing - 1e-6
	local zone = zoneOfPoint(p)
	perZone[zone] += 1
	zones = zones and rec.payload.Zone == zone
	local draw = DRAWS[i]
	drawn = drawn and draw ~= nil and draw.zone == zone and draw.content ~= nil and draw.content.ItemId == rec.payload.ItemId and draw.content.Rarity == rec.payload.Rarity and draw.content.Mutation == rec.payload.Mutation and draw.luck == rec.payload.Luck
	local item = Items.ById[rec.payload.ItemId]
	valid = valid and item ~= nil and item.Rarity == rec.payload.Rarity
end
check(onStreet, "R7b tous sur le dessus d'une rue « Street »")
check(margins, `R7c à {IR.EdgeMargin} studs au moins des bords de la rue`)
check(corridor, "R7d tous côté couloir")
check(hub, "R7e jamais en zone safe, jamais sur la rue du hub")
check(arch, `R7f jamais sous l'arche ni à {IR.Clearance} studs`)
check(spacing, `R7g à {IR.MinSpacing} studs au moins d'un autre objet de la pluie au sol`)
check(zones, "R7h zone de l'objet = celle des magasins les plus proches")
check(perZone[1] > 0 and perZone[2] > 0, `R7i il en tombe dans les deux zones (zone 1 : {perZone[1]}, zone 2 : {perZone[2]} ; volume invisible traversé)`)
check(drawn, "R7j objet, rareté, mutation et chance : ceux du tirage de sa zone (StoreHeistService.DrawForZone)")
check(valid, "R7k objets du catalogue, à leur rareté")

summary("scénario rain")
if FAILS > 0 then
	for _, line in LOG do
		if line.kind == "WARN" then
			print("    [WARN] " .. line.text)
		end
	end
end
