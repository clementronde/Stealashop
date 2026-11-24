--!nocheck
-- Scénarios du banc a295 (vague 84, 21/11) : colis du camion jamais vides, chances relatives gardées.
CHECKS, FAILS = 0, 0
local function check(ok, label)
	CHECKS += 1
	if not ok then
		FAILS += 1
		print("ÉCHEC : " .. label)
	elseif RAPPORT then
		print("ok : " .. label)
	end
end
local function near(a, b, eps)
	return math.abs(a - b) <= eps
end
local function pct(v)
	return string.format("%.3f", v)
end

-- Random de Roblox (seul NextNumber et NextInteger servent ici), graine fixe : banc reproductible.
math.randomseed(295)
Random = {
	new = function(_seed)
		return {
			NextNumber = function(_self, a, b)
				local x = math.random()
				if a ~= nil and b ~= nil then
					return a + (b - a) * x
				end
				return x
			end,
			NextInteger = function(_self, a, b)
				return math.random(a, b)
			end,
		}
	end,
}
WARN295 = {}

local Rarities = shared("Config/Rarities")
local ShelfBoxes = shared("Config/ShelfBoxes")
local Items = shared("Config/Items")
local TruckEvent = shared("Config/TruckEvent")
local Draw = shared("TruckDraw295")
local TIERS = { "Standard", "Premium", "Luxe" }
local COUNT = {}
for _, entry in TruckEvent.Boxes do
	COUNT[entry.Tier] = (COUNT[entry.Tier] or 0) + entry.Count
end

-- Rareté tirable dans la zone, calculée ici sans le code du service : un objet non TutorialOnly dans
-- Items.ByZone[zone][rareté], ou dans Items.AllZones[rareté] (Secret : seulement les zones qui l'ont ; Divine : toutes).
local function hasItem(zone, id)
	local all = Items.AllZones[id]
	if all ~= nil then
		if Rarities.FirstZone[id] ~= nil and not Rarities.Allows(zone, id) then
			return false
		end
		for _, item in all do
			if not item.TutorialOnly then
				return true
			end
		end
		return false
	end
	local byZone = Items.ByZone[zone]
	local list = if byZone then byZone[id] else nil
	for _, item in list or {} do
		if not item.TutorialOnly then
			return true
		end
	end
	return false
end

-- Vieux tirage (avant a295), calcul exact : la table OddsFor, une rareté sans objet retombe sur la plus proche en
-- dessous qui en a, sinon colis vide. Rend { [rareté] = % }, % de colis vides.
local function oldTable(zone, tier)
	local odds = ShelfBoxes.OddsFor(zone, tier)
	local total = 0
	for _, r in Rarities.List do
		total += odds[r.Id] or 0
	end
	local out, empty = {}, 0
	for index, r in Rarities.List do
		local w = (odds[r.Id] or 0) / total * 100
		if w > 0 then
			local got = nil
			for j = index, 1, -1 do
				if hasItem(zone, Rarities.List[j].Id) then
					got = Rarities.List[j].Id
					break
				end
			end
			if got then
				out[got] = (out[got] or 0) + w
			else
				empty += w
			end
		end
	end
	return out, empty
end

-- Vieux tirage parmi les colis non vides : oldTable ramenée à 100 (zones 1 à 4 : rien ne change, aucun colis vide).
local function oldDelivered(zone, tier)
	local old, empty = oldTable(zone, tier)
	local out = {}
	for id, v in old do
		out[id] = v / (100 - empty) * 100
	end
	return out
end

-- Table de tirage attendue après a295 (V0 du grand chef, 21/11) : OddsFor sans les raretés qui n'ont aucun objet à
-- leur niveau ni en dessous dans la zone, ramenée à 100.
local function drawTable(zone, tier)
	local odds = ShelfBoxes.OddsFor(zone, tier)
	local total, kept, below = 0, {}, false
	for _, r in Rarities.List do
		below = below or hasItem(zone, r.Id)
		local w = odds[r.Id] or 0
		if w > 0 and below then
			kept[r.Id] = w
			total += w
		end
	end
	for id, w in kept do
		kept[id] = w / total * 100
	end
	return kept
end

-- Distribution livrée d'une table de tirage en zone `zone` : chaque rareté sans objet retombe sur la plus proche en
-- dessous qui en a.
local function delivered(t, zone)
	local out = {}
	for index, r in Rarities.List do
		local w = t[r.Id]
		if w then
			for j = index, 1, -1 do
				local id = Rarities.List[j].Id
				if hasItem(zone, id) then
					out[id] = (out[id] or 0) + w
					break
				end
			end
		end
	end
	return out
end

local function show(t)
	local parts = {}
	for _, r in Rarities.List do
		if t[r.Id] then
			table.insert(parts, string.sub(r.Id, 1, 2) .. " " .. pct(t[r.Id]))
		end
	end
	return table.concat(parts, ", ")
end
local function sameTable(got, want, eps, label)
	for id, v in want do
		check(got[id] ~= nil and near(got[id], v, eps), `{label} : {id} {pct(got[id] or 0)} = {pct(v)}`)
	end
	for id, v in got do
		check(want[id] ~= nil, `{label} : {id} ({pct(v)}) en trop`)
	end
end

print("== A. Vieux tirage (calcul exact) : colis vides par camion de 12")
local line = {}
for zone = 1, 6 do
	local empties = 0
	for _, tier in TIERS do
		local old, empty = oldTable(zone, tier)
		empties += COUNT[tier] * empty / 100
		if RAPPORT then
			print(`  Z{zone} {tier} livré avant : {show(old)} ; vides {pct(empty)} % ; livré après : {show(delivered(drawTable(zone, tier), zone))}`)
		end
	end
	table.insert(line, `Z{zone} {string.format("%.2f", empties)}`)
end
print("  vieux code : " .. table.concat(line, ", ") .. " colis vides sur 12")

if Draw.truckOdds ~= nil then
	print("== B. Table du camion (truckOdds) et distribution livrée (calcul exact)")
	for zone = 1, 6 do
		for _, tier in TIERS do
			local got = Draw.truckOdds(tier, zone)
			check(got ~= nil, `Z{zone} {tier} : une table`)
			got = got or {}
			local sum = 0
			for _, v in got do
				sum += v
			end
			check(near(sum, 100, 1e-9), `Z{zone} {tier} : somme {sum} = 100`)
			sameTable(got, drawTable(zone, tier), 1e-9, `Z{zone} {tier} tirage`)
			-- Rapports entre raretés gardées = rapports de Rarities.BoxOdds.
			local odds = ShelfBoxes.OddsFor(zone, tier)
			local ref = nil
			for _, r in Rarities.List do
				if got[r.Id] then
					if ref == nil then
						ref = r.Id
					else
						check(near(got[r.Id] / got[ref], odds[r.Id] / odds[ref], 1e-9), `Z{zone} {tier} : rapport {r.Id}/{ref} gardé`)
					end
				end
			end
			-- Livré après = livré avant parmi les colis non vides.
			sameTable(delivered(got, zone), oldDelivered(zone, tier), 1e-9, `Z{zone} {tier} livré = avant (non vides)`)
			-- Zones 1 à 4 : table de tirage = OddsFor tel quel, livré identique à avant, repli vers le bas compris.
			if zone <= 4 then
				local old, empty = oldTable(zone, tier)
				check(empty == 0, `Z{zone} {tier} : aucun colis vide avant non plus`)
				local raw, rawTotal = {}, 0
				for _, r in Rarities.List do
					rawTotal += odds[r.Id] or 0
				end
				for _, r in Rarities.List do
					if (odds[r.Id] or 0) > 0 then
						raw[r.Id] = odds[r.Id] / rawTotal * 100
					end
				end
				sameTable(got, raw, 1e-9, `Z{zone} {tier} tirage = OddsFor tel quel`)
				sameTable(delivered(got, zone), old, 1e-9, `Z{zone} {tier} livré identique à avant`)
			end
		end
	end
	-- Distribution livrée en zones 5 et 6, écrite à la main (OddsFor sans les raretés qui finissaient vides, à 100,
	-- puis le repli vers le bas : en zone 5, Mythique et Secret donnent un Légendaire).
	local HAND = {
		[5] = {
			Standard = { Uncommon = 22 / 30 * 100, Rare = 7 / 30 * 100, Epic = 1 / 30 * 100 },
			Premium = { Uncommon = 35 / 65 * 100, Rare = 20 / 65 * 100, Epic = 8 / 65 * 100, Legendary = 2 / 65 * 100 },
			Luxe = { Uncommon = 25, Rare = 40, Epic = 25, Legendary = 10 },
		},
		[6] = {
			Standard = { Rare = 87.5, Epic = 12.5 },
			Premium = { Rare = 20 / 30 * 100, Epic = 8 / 30 * 100, Legendary = 6, Mythic = 0.2 / 30 * 100 },
			Luxe = { Rare = 40 / 75 * 100, Epic = 25 / 75 * 100, Legendary = 8 / 75 * 100, Mythic = 2.4, Secret = 0.2 / 75 * 100 },
		},
	}
	for zone, tiers in HAND do
		for tier, want in tiers do
			sameTable(delivered(Draw.truckOdds(tier, zone) or {}, zone), want, 1e-6, `Z{zone} {tier} livré, à la main`)
		end
	end
	-- Divine : dans la table de tirage partout où sa chance est > 0 (repli vers le bas tant qu'aucun objet Divine
	-- n'existe, comme avant) ; aujourd'hui 0 partout, donc jamais.
	for zone = 1, 6 do
		for _, tier in TIERS do
			local got = Draw.truckOdds(tier, zone) or {}
			local odds = ShelfBoxes.OddsFor(zone, tier)
			check((got.Divine ~= nil) == ((odds.Divine or 0) > 0), `Z{zone} {tier} : Divine selon sa chance`)
		end
	end
end

print("== C. 10 000 camions par zone (drawLoad) : aucun colis vide, objet de la zone et de la rareté tirée")
local TRUCKS = 10000
for zone = 1, 6 do
	local empty, boxes, wrong, tierBad = 0, 0, 0, 0
	for _ = 1, TRUCKS do
		local load = Draw.drawLoad(zone)
		local seen = {}
		for _, box in load do
			boxes += 1
			seen[box.Tier] = (seen[box.Tier] or 0) + 1
			if box.Rarity == nil or box.ItemId == nil then
				empty += 1
			else
				local item = Items.ById[box.ItemId]
				local zoneOk = item ~= nil and (item.Zone == zone or Items.AllZones[item.Rarity] ~= nil)
				if item == nil or item.Rarity ~= box.Rarity or not zoneOk or item.TutorialOnly then
					wrong += 1
				end
			end
		end
		for _, tier in TIERS do
			if seen[tier] ~= COUNT[tier] then
				tierBad += 1
			end
		end
	end
	check(empty == 0, `Z{zone} : {empty} colis vides sur {boxes} ({string.format("%.2f", empty / TRUCKS)} par camion)`)
	check(wrong == 0, `Z{zone} : {wrong} colis à l'objet hors zone ou d'une autre rareté`)
	check(tierBad == 0, `Z{zone} : 6 Standard, 4 Premium, 2 Luxe par camion ({tierBad} camions faux)`)
end
local warned = {}
for key, message in WARN295 do
	table.insert(warned, key .. " : " .. message)
end
check(#warned == 0, "aucun avertissement du repli (" .. table.concat(warned, " | ") .. ")")

print("== D. Échantillon (200 000 colis par zone et type, drawContent) : livré = vieux tirage exact parmi les non vides, à 0,5 point")
local DRAWS = 200000
for zone = 1, 6 do
	for _, tier in TIERS do
		local want = oldDelivered(zone, tier)
		local counts, empty = {}, 0
		for _ = 1, DRAWS do
			local rarity, itemId = Draw.drawContent(tier, zone)
			if rarity == nil or itemId == nil then
				empty += 1
			else
				counts[rarity] = (counts[rarity] or 0) + 1
			end
		end
		check(empty == 0, `Z{zone} {tier} : {empty} colis vides`)
		local worst = 0
		for _, r in Rarities.List do
			local seen = (counts[r.Id] or 0) / math.max(1, DRAWS - empty) * 100
			local w = want[r.Id] or 0
			worst = math.max(worst, math.abs(seen - w))
			check(near(seen, w, 0.5), `Z{zone} {tier} : {r.Id} livré {pct(seen)} %, attendu {pct(w)} %`)
		end
		if RAPPORT then
			print(`  Z{zone} {tier} : plus grand écart {pct(worst)} point`)
		end
	end
end

print(`banc a295 (camion sans colis vides) : {CHECKS} vérification(s), {FAILS} échec(s)`)
