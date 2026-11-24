--!nocheck
-- a309 (22/11, Cantin), scénario « draw » : les colis de zone des paliers de 15 et 60 min (Shared/ZoneBoxOdds, règles
-- Config/Rewards.ZoneBox). Chances exactes et 100 000 tirages par zone de référence (1 à 6) et par palier, comparés aux
-- attendus de la décision ; jamais de Secret à 60 min ; zone + 1 plafonnée à la dernière zone de Config/Zones ; un
-- faux ZoneOdds (zone 7 ajoutée, une rareté retirée d'une zone, une zone vidée) change les tirages sans toucher à
-- Config/Rewards ; chaque rareté possible a des objets (Items.Pick).

startServer()
local ZoneBoxOdds = sharedModule("ZoneBoxOdds")
local Rewards = sharedModule("Config/Rewards")
local Zones = sharedModule("Config/Zones")
local RaritiesCfg = sharedModule("Config/Rarities")
local ItemsCfg = sharedModule("Config/Items")
local BEST = Rewards.ZoneBox.BestZone
local NEXT = Rewards.ZoneBox.NextZone
local N = 100000

-- Attendus de la décision du 22/11 (en %), par zone de référence (bestZone) ; 60 min : la zone suivante.
local EXPECTED = {
	BestZone = {
		[1] = { Common = 100 },
		[2] = { Common = 97.6, Uncommon = 2.4 },
		[3] = { Common = 32, Uncommon = 65, Rare = 3 },
		[4] = { Common = 37.1, Uncommon = 37.5, Rare = 21.2, Epic = 4.2 },
		[5] = { Uncommon = 37.3, Rare = 37.5, Epic = 21, Legendary = 4.2 },
		[6] = { Rare = 38.8775, Epic = 36.4, Legendary = 24.235, Mythic = 0.42, Secret = 0.0675 },
	},
	NextZone = {
		[1] = { Common = 200 / 3, Uncommon = 100 / 3 }, -- zone 2, V0 (60 et 30 : 67 et 33 %)
		[2] = { Common = 60, Uncommon = 30, Rare = 10 }, -- zone 3
		[3] = { Uncommon = 60, Rare = 30, Epic = 10 }, -- zone 4
		[4] = { Rare = 60, Epic = 30, Legendary = 10 }, -- zone 5
		[5] = { Epic = 60, Legendary = 30, Mythic = 10 }, -- zone 6
		[6] = { Epic = 60, Legendary = 30, Mythic = 10 }, -- zone 6 (plafond)
	},
}
local EXPECTED_ZONE = { BestZone = { 1, 2, 3, 4, 5, 6 }, NextZone = { 2, 3, 4, 5, 6, 6 } }

local function byId(chances)
	local out = {}
	for _, entry in chances do
		out[entry.Id] = entry.Chance
	end
	return out
end
local function sameSet(a, b)
	for id in a do
		if b[id] == nil then
			return false
		end
	end
	for id in b do
		if a[id] == nil then
			return false
		end
	end
	return true
end
-- 100 000 tirages : part de chaque rareté (en %).
local function measure(chances, seed)
	local rng = Random.new(seed)
	local counts = {}
	for _ = 1, N do
		local drawn = ZoneBoxOdds.Draw(chances, rng:NextNumber())
		counts[drawn.Id] = (counts[drawn.Id] or 0) + 1
	end
	local share = {}
	for id, n in counts do
		share[id] = n * 100 / N
	end
	return share
end
-- Écart permis : 4 écarts-types d'une loi binomiale à N tirages, plus 0,02 point.
local function tolerance(percent)
	local p = percent / 100
	return 400 * math.sqrt(p * (1 - p) / N) + 0.02
end
local function fmt(map, order)
	local parts = {}
	for _, id in order do
		if map[id] then
			table.insert(parts, `{id} {string.format("%.3f", map[id])}`)
		end
	end
	return table.concat(parts, ", ")
end
local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" }

section("règles de Config/Rewards")
check(Rewards.Playtime[2].Minutes == 15 and Rewards.Playtime[2].Reward.Kind == "ZoneBox" and Rewards.Playtime[2].Reward.Rule == "BestZone", "15 min : ZoneBox, règle BestZone")
check(Rewards.Playtime[4].Minutes == 60 and Rewards.Playtime[4].Reward.Kind == "ZoneBox" and Rewards.Playtime[4].Reward.Rule == "NextZone", "60 min : ZoneBox, règle NextZone")
check(BEST.ZoneStep == 0 and BEST.TopBoost == 1.5 and BEST.TopCount == nil, "BestZone : même zone, rareté la plus haute × 1,5")
check(NEXT.ZoneStep == 1 and NEXT.TopCount == 3 and NEXT.TopWeights[1] == 60 and NEXT.TopWeights[2] == 30 and NEXT.TopWeights[3] == 10, "NextZone : zone + 1, 3 meilleures raretés à 60/30/10")
check(NEXT.Exclude and table.find(NEXT.Exclude, "Secret") ~= nil, "NextZone : Secret exclu par son Id")
check(#Zones == 6, `Config/Zones : {#Zones} zones (la dernière = le plafond)`)

PRINT_TABLE = {}
for _, rule in { "BestZone", "NextZone" } do
	section(`{rule} : chances et 100 000 tirages par zone de référence`)
	for best = 1, 6 do
		local zone = ZoneBoxOdds.Zone(Rewards.ZoneBox[rule], best)
		check(zone == EXPECTED_ZONE[rule][best], `{rule}, zone de référence {best} : colis de la zone {zone} (attendu {EXPECTED_ZONE[rule][best]})`)
		local chances = ZoneBoxOdds.Chances(Rewards.ZoneBox[rule], zone)
		local got, want = byId(chances), EXPECTED[rule][best]
		local exact = sameSet(got, want)
		local total = 0
		for id, value in got do
			total += value
			if want[id] == nil or math.abs(value - want[id]) > 1e-6 then
				exact = false
			end
		end
		check(exact and math.abs(total - 100) < 1e-6, `{rule}, zone {best} : chances {fmt(got, ORDER)} (attendu {fmt(want, ORDER)})`)
		for k = 2, #chances do
			if RaritiesCfg.ById[chances[k].Id].Order <= RaritiesCfg.ById[chances[k - 1].Id].Order then
				check(false, `{rule}, zone {best} : raretés triées par Order`)
			end
		end
		local share = measure(chances, 309000 + best * 10 + (if rule == "NextZone" then 1 else 0))
		local ok, worst = true, 0
		for id in share do
			if want[id] == nil then
				ok = false
			end
		end
		for id, value in want do
			local d = math.abs((share[id] or 0) - value)
			if d > tolerance(value) then
				ok = false
			end
			worst = math.max(worst, d)
		end
		check(ok, `{rule}, zone {best} : tirages {fmt(share, ORDER)} (plus grand écart {string.format("%.3f", worst)} point)`)
		table.insert(PRINT_TABLE, `TIRAGES | {rule} | {best} | {zone} | {fmt(share, ORDER)} | {fmt(want, ORDER)}`)
		if rule == "NextZone" then
			check(share.Secret == nil and got.Secret == nil, `NextZone, zone {best} : aucun Secret ({N} tirages)`)
		end
	end
end
for _, line in PRINT_TABLE do
	print(line)
end

section("zone + 1 plafonnée à la dernière zone")
check(ZoneBoxOdds.Zone(NEXT, 6) == #Zones and ZoneBoxOdds.Zone(NEXT, 99) == #Zones, "zone de référence 6 ou 99 : zone 6")
check(ZoneBoxOdds.Zone(BEST, 0) == 1 and ZoneBoxOdds.Zone(BEST, -3) == 1 and ZoneBoxOdds.Zone(NEXT, 0 / 0) == 2, "zone 0, négative ou illisible : zone 1 (+ 1)")
local secretSeen = 0
for best = 1, 6 do
	local chances = ZoneBoxOdds.Chances(NEXT, ZoneBoxOdds.Zone(NEXT, best))
	local rng = Random.new(77 + best)
	for _ = 1, N do
		if ZoneBoxOdds.Draw(chances, rng:NextNumber()).Id == "Secret" then
			secretSeen += 1
		end
	end
end
check(secretSeen == 0, `60 min : aucun Secret sur {6 * N} tirages (zones 1 à 6)`)
check(byId(ZoneBoxOdds.Chances(BEST, 6)).Secret ~= nil, "15 min en zone 6 : le Secret reste possible (non exclu, V0)")

section("chaque rareté possible a des objets (Items.Pick)")
local rng = Random.new(3090)
local picksOk = true
for _, rule in { BEST, NEXT } do
	for best = 1, 6 do
		local zone = ZoneBoxOdds.Zone(rule, best)
		for _, entry in ZoneBoxOdds.Chances(rule, zone) do
			for _ = 1, 20 do
				local item = ItemsCfg.Pick(zone, entry.Id, rng)
				if item == nil or item.Rarity ~= entry.Id or item.TutorialOnly then
					picksOk = false
					print(`    Pick({zone}, {entry.Id}) : {item and item.Id}`)
				end
			end
		end
	end
end
check(picksOk, "Items.Pick(zone, rareté) rend un objet de cette rareté pour chaque rareté de chaque colis")

section("faux ZoneOdds : les tirages changent, Config/Rewards non")
local rulesBefore = { BEST.ZoneStep, BEST.TopBoost, NEXT.ZoneStep, NEXT.TopCount, NEXT.TopWeights[1], NEXT.TopWeights[2], NEXT.TopWeights[3], NEXT.Exclude[1] }
local odds, lists = {}, {}
for zone = 1, 6 do
	odds[zone] = table.clone(RaritiesCfg.ZoneOdds[zone])
	lists[zone] = table.clone(RaritiesCfg.ZoneRarities[zone])
end
-- zone 7 ajoutée (Légendaire 50, Mythique 30, Secret 20) ; Légendaire retiré de la zone 5.
odds[7] = { Legendary = 50, Mythic = 30, Secret = 20 }
lists[7] = { "Legendary", "Mythic", "Secret" }
odds[5].Legendary = nil
table.remove(lists[5], table.find(lists[5], "Legendary"))
local zones7 = table.clone(Zones)
table.insert(zones7, { Id = 7 })
local fake = { Rarities = { ById = RaritiesCfg.ById, ZoneOdds = odds, ZoneRarities = lists }, Zones = zones7 }

check(ZoneBoxOdds.Zone(NEXT, 6, fake) == 7 and ZoneBoxOdds.Zone(NEXT, 7, fake) == 7, "7 zones : zone 6 + 1 = 7, plafond 7")
local n7 = byId(ZoneBoxOdds.Chances(NEXT, 7, fake))
check(sameSet(n7, { Legendary = true, Mythic = true }) and math.abs(n7.Legendary - 200 / 3) < 1e-6 and math.abs(n7.Mythic - 100 / 3) < 1e-6, `60 min, zone 7 : Secret exclu, 2 raretés à 60/30 ({fmt(n7, ORDER)})`)
local b7 = byId(ZoneBoxOdds.Chances(BEST, 7, fake))
check(math.abs(b7.Secret - 30) < 1e-6 and math.abs(b7.Legendary - 40) < 1e-6 and math.abs(b7.Mythic - 30) < 1e-6, `15 min, zone 7 : Secret 20 × 1,5, écart pris sur Légendaire ({fmt(b7, ORDER)})`)
local s7 = measure(ZoneBoxOdds.Chances(BEST, 7, fake), 3097)
check(math.abs(s7.Secret - 30) < tolerance(30) and math.abs(s7.Legendary - 40) < tolerance(40), `15 min, zone 7 : tirages {fmt(s7, ORDER)}`)

local n5 = byId(ZoneBoxOdds.Chances(NEXT, ZoneBoxOdds.Zone(NEXT, 4, fake), fake))
check(sameSet(n5, { Uncommon = true, Rare = true, Epic = true }) and math.abs(n5.Uncommon - 60) < 1e-6 and math.abs(n5.Epic - 10) < 1e-6, `60 min depuis la zone 4, zone 5 sans Légendaire : {fmt(n5, ORDER)} (vrai : Rare 60, Épique 30, Légendaire 10)`)
local m5 = measure(ZoneBoxOdds.Chances(NEXT, 5, fake), 3095)
check(m5.Legendary == nil and math.abs(m5.Uncommon - 60) < tolerance(60), `60 min, zone 5 sans Légendaire : tirages {fmt(m5, ORDER)}`)
local b5 = byId(ZoneBoxOdds.Chances(BEST, 5, fake))
local epic5 = RaritiesCfg.ZoneOdds[5].Epic * 100 / (RaritiesCfg.ZoneOdds[5].Uncommon + RaritiesCfg.ZoneOdds[5].Rare + RaritiesCfg.ZoneOdds[5].Epic)
check(b5.Legendary == nil and math.abs(b5.Epic - epic5 * 1.5) < 1e-6, `15 min, zone 5 sans Légendaire : la plus haute est Épique, × 1,5 ({fmt(b5, ORDER)})`)

-- une zone sans aucune rareté : on descend à la première zone en dessous qui en a.
local empty = { Rarities = { ById = RaritiesCfg.ById, ZoneOdds = table.clone(odds), ZoneRarities = lists }, Zones = zones7 }
empty.Rarities.ZoneOdds[7] = {}
check(ZoneBoxOdds.Zone(NEXT, 6, empty) == 6, "zone 7 vide : le colis de la zone 6")
local after = { BEST.ZoneStep, BEST.TopBoost, NEXT.ZoneStep, NEXT.TopCount, NEXT.TopWeights[1], NEXT.TopWeights[2], NEXT.TopWeights[3], NEXT.Exclude[1] }
local same = true
for k = 1, #rulesBefore do
	same = same and rulesBefore[k] == after[k]
end
check(same, "Config/Rewards.ZoneBox inchangé")
check(ZoneBoxOdds.Zone(NEXT, 6) == 6 and byId(ZoneBoxOdds.Chances(NEXT, 5)).Legendary == 10, "sans faux ZoneOdds : de nouveau les vraies tables")
summary("scénario a309draw")
