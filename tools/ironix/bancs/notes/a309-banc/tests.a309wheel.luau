--!nocheck
-- a309 (22/11, Cantin : « fais la roue de la chance aussi »), scénario « wheel », sur le harnais du banc a266 (vrais
-- WheelService, Prize/Grant, UnboxService, MonetizationService) : les secteurs BOX (2) et RARE BOX (6) donnent le colis
-- de zone des cadeaux de 15 et 60 min (mêmes règles Config/Rewards.ZoneBox, même fonction de tirage
-- UnboxService.GiveZoneBoxItem / Shared/ZoneBoxOdds) ; 100 000 tirages par zone (1 à 6) pour chacun ; les autres
-- secteurs, les poids et le repli inchangés (100 000 tirages de WheelService.Draw) ; tour en zone safe : Result vide
-- puis la scène quand la roue s'arrête (SpinSeconds), sans message ; hors zone safe : le message en notification.

advance(1000)
startServer()
wheelTest("days 10")
local Rewards = sharedModule("Config/Rewards")
local RaritiesCfg = sharedModule("Config/Rarities")
local ItemsCfg = sharedModule("Config/Items")
local ZoneBoxOdds = sharedModule("ZoneBoxOdds")
local SafeZoneMod = sharedModule("SafeZone")
local Grant = requireModule(SERVICES:FindFirstChild("Prize"):FindFirstChild("Grant"), "server")
local N = 100000

section("secteurs : BOX et RARE BOX sur les règles des cadeaux, le reste inchangé")
-- Secteurs d'avant a309 (Config/Wheel de fusion90), sauf les lots de BOX et RARE BOX.
local BEFORE = {
	{ "5 MIN CASH", "WHEEL_Cash", 30, { Kind = "Cash", Minutes = 5 } },
	{ "BOX", "WHEEL_Box", 20, nil },
	{ "x2 CASH 10 MIN", "WHEEL_Boost", 15, { Kind = "Boost", Minutes = 10 } },
	{ "MONEY POTION", "WHEEL_PotionMoney", 5, { Kind = "Potion", Potion = "Money", Count = 1 } },
	{ "15 MIN CASH", "WHEEL_Cash", 15, { Kind = "Cash", Minutes = 15 } },
	{ "RARE BOX", "WHEEL_BoxRare", 7, nil },
	{ "STRENGTH POTION", "WHEEL_PotionStrength", 5, { Kind = "Potion", Potion = "Strength", Count = 1 } },
	{ "60 MIN CASH", "WHEEL_Jackpot", 3, { Kind = "Cash", Minutes = 60 } },
}
local function samePrize(a, b)
	for k, v in a do
		if b[k] ~= v then
			return false
		end
	end
	for k, v in b do
		if a[k] ~= v then
			return false
		end
	end
	return true
end
check(#Wheel.Sectors == #BEFORE, `{#Wheel.Sectors} secteurs`)
for index, old in BEFORE do
	local sector = Wheel.Sectors[index]
	local same = sector and sector.Label == old[1] and sector.Icon == old[2] and sector.Weight == old[3]
	if old[4] then
		same = same and samePrize(sector.Prize, old[4])
	end
	check(same, `secteur {index} « {sector and sector.Label} » : texte, icône, poids {sector and sector.Weight}{if old[4] then ", lot" else ""} inchangés`)
end
check(samePrize(Wheel.Sectors[2].Prize, { Kind = "ZoneBox", Rule = "BestZone" }), "BOX : colis de zone, règle BestZone (celle des 15 min)")
check(samePrize(Wheel.Sectors[6].Prize, { Kind = "ZoneBox", Rule = "NextZone" }), "RARE BOX : colis de zone, règle NextZone (celle des 60 min)")
check(Rewards.Playtime[2].Reward.Rule == Wheel.Sectors[2].Prize.Rule and Rewards.Playtime[4].Reward.Rule == Wheel.Sectors[6].Prize.Rule, "mêmes règles que les paliers de 15 et 60 min")
check(samePrize(Wheel.Fallback, { Kind = "Cash", Minutes = 5 }), "repli inchangé (5 min de revenus)")

local rngDraw = Random.new(3096)
local counts = {}
for _ = 1, N do
	local index = WheelService.Draw(rngDraw)
	counts[index] = (counts[index] or 0) + 1
end
local drawOk, parts = true, {}
for index, old in BEFORE do
	local share = (counts[index] or 0) * 100 / N
	local p = old[3] / 100
	if math.abs(share - old[3]) > 400 * math.sqrt(p * (1 - p) / N) + 0.02 then
		drawOk = false
	end
	table.insert(parts, string.format("%d:%.2f", index, share))
end
check(drawOk, `WheelService.Draw, {N} tirages : {table.concat(parts, " ")} (poids 30 20 15 5 15 7 5 3)`)

section("BOX et RARE BOX : 100 000 tirages par zone de référence")
local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local EXPECTED = {
	[2] = { -- BOX = 15 min
		{ Common = 100 },
		{ Common = 97.6, Uncommon = 2.4 },
		{ Common = 32, Uncommon = 65, Rare = 3 },
		{ Common = 37.1, Uncommon = 37.5, Rare = 21.2, Epic = 4.2 },
		{ Uncommon = 37.3, Rare = 37.5, Epic = 21, Legendary = 4.2 },
		{ Rare = 38.8775, Epic = 36.4, Legendary = 24.235, Mythic = 0.42, Secret = 0.0675 },
	},
	[6] = { -- RARE BOX = 60 min
		{ Common = 200 / 3, Uncommon = 100 / 3 },
		{ Common = 60, Uncommon = 30, Rare = 10 },
		{ Uncommon = 60, Rare = 30, Epic = 10 },
		{ Rare = 60, Epic = 30, Legendary = 10 },
		{ Epic = 60, Legendary = 30, Mythic = 10 },
		{ Epic = 60, Legendary = 30, Mythic = 10 },
	},
}
local function fmt(map)
	local out = {}
	for _, id in ORDER do
		if map[id] then
			table.insert(out, `{id} {string.format("%.3f", map[id])}`)
		end
	end
	return table.concat(out, ", ")
end
for _, index in { 2, 6 } do
	local rule = Rewards.ZoneBox[Wheel.Sectors[index].Prize.Rule]
	for best = 1, 6 do
		local zone = ZoneBoxOdds.Zone(rule, best)
		local chances = ZoneBoxOdds.Chances(rule, zone)
		local rng = Random.new(30960 + index * 10 + best)
		local tally = {}
		for _ = 1, N do
			local id = ZoneBoxOdds.Draw(chances, rng:NextNumber()).Id
			tally[id] = (tally[id] or 0) + 1
		end
		local share, ok, want = {}, true, EXPECTED[index][best]
		for id, n in tally do
			share[id] = n * 100 / N
			if want[id] == nil then
				ok = false
			end
		end
		for id, value in want do
			local p = value / 100
			if math.abs((share[id] or 0) - value) > 400 * math.sqrt(p * (1 - p) / N) + 0.02 then
				ok = false
			end
		end
		check(ok, `{Wheel.Sectors[index].Label}, zone de référence {best} (colis zone {zone}) : {fmt(share)}`)
		print(`TIRAGES | {Wheel.Sectors[index].Label} | {best} | {zone} | {fmt(share)} | {fmt(want)}`)
	end
end

section("Grant.Give passe par UnboxService.GiveZoneBoxItem (une seule fonction)")
local carl = join("Carl", newProfile8(), 73)
advance(1.5)
local unbox = serverModule("UnboxService")
local real = unbox.GiveZoneBoxItem
local calls = {}
unbox.GiveZoneBoxItem = function(player, rule, bestZone)
	table.insert(calls, { rule = rule, best = bestZone })
	return real(player, rule, bestZone)
end
local okBox, _, _, _, reveal = Grant.Give(carl, Wheel.Sectors[2].Prize)
check(okBox and #calls == 1 and calls[1].rule == Rewards.ZoneBox.BestZone and calls[1].best == 1, "BOX : GiveZoneBoxItem(règle BestZone de Config/Rewards, zone 1)")
check(type(reveal) == "table" and type(reveal.ItemId) == "string" and reveal.StartRarity == "Common", "BOX : Grant rend de quoi ouvrir le colis (ItemId, StartRarity)")
dataOf(carl).Items["z6"] = { Id = (function()
	for _, item in ItemsCfg.List do
		if item.Zone == 6 then
			return item.Id
		end
	end
end)(), Source = "NPC", At = 1, Zone = 6 }
local secret, wrong = 0, 0
for n = 1, 300 do
	local keysBefore = itemKeys(carl)
	local ok, _, _, _, gift = Grant.Give(carl, Wheel.Sectors[6].Prize)
	local got = giftsSince(carl, keysBefore)[1]
	local rarity = got and ItemsCfg.ById[got.entry.Id].Rarity
	if rarity == "Secret" then
		secret += 1
	end
	if not ok or got == nil or got.entry.Zone ~= 6 or not table.find({ "Epic", "Legendary", "Mythic" }, rarity) or gift.StartRarity ~= "Epic" then
		wrong += 1
	end
	if got then
		dataOf(carl).Items[got.uid] = nil
	end
end
check(#calls == 301 and calls[301].rule == Rewards.ZoneBox.NextZone and calls[301].best == 6, "RARE BOX : GiveZoneBoxItem(règle NextZone, zone 6)")
check(secret == 0 and wrong == 0, `RARE BOX depuis la zone 6, 300 dons : {secret} Secret, {wrong} incohérent(s)`)
unbox.GiveZoneBoxItem = real

section("tour en zone safe : Result vide, puis la scène quand la roue s'arrête")
local data = newProfile8()
addItem(data, "z3", (function()
	for _, item in ItemsCfg.List do
		if item.Zone == 3 then
			return item.Id
		end
	end
end)(), nil, 3, 1)
local ada = join("Ada", data, 71)
advance(1.5)
check(SafeZoneMod.ContainsPlayer(ada), "Ada en zone safe")
local function revealsOf(player)
	return remotes("RevealStarted", function(e)
		return e.args[1] == player
	end)
end
wheelTest("force 6")
local keys = itemKeys(ada)
spin(ada)
local wr = wheelResults(ada)
local gifts = giftsSince(ada, keys)
local g = gifts[1] and gifts[1].entry
check(#wr == 1 and wr[1].args[1] == 6 and wr[1].args[2] == "", `WheelResult(6, « {wr[1] and wr[1].args[2]} ») : Result vide`)
check(#gifts == 1 and g.Zone == 4 and table.find({ "Uncommon", "Rare", "Epic" }, ItemsCfg.ById[g.Id].Rarity), `RARE BOX : objet de la zone 4 (zone 3 + 1) : {g and g.Id}`)
check(#revealsOf(ada) == 0, "pas de scène pendant que la roue tourne")
advance(Wheel.SpinSeconds + 0.2)
local rv = revealsOf(ada)
check(#rv == 1 and rv[1].args[2] == "ExclusiveCrate" and rv[1].args[4] == g.Id, `roue arrêtée ({Wheel.SpinSeconds} s) : RevealStarted de {g and g.Id}`)
check(#notifies(ada, giftText(g)) == 0, "pas de message pour l'objet montré")
local ws = eventsOf(ada, "WheelSpin")
check(#ws == 1 and ws[1].fields[2] == "Gift - ZoneBox", "événement WheelSpin : Gift - ZoneBox")
advance(40)

section("tour hors zone safe : le message en notification")
wheelTest("reset Ada")
wheelTest("force 2")
ada.Character.HumanoidRootPart.CFrame = CFrame.new(5000, 3, 5000)
advance(0.2)
check(not SafeZoneMod.ContainsPlayer(ada), "Ada hors de la zone safe")
keys = itemKeys(ada)
spin(ada)
gifts = giftsSince(ada, keys)
g = gifts[1] and gifts[1].entry
local before = #revealsOf(ada)
check(#gifts == 1 and g.Zone == 4 and wheelResults(ada)[2].args[2] == "", `BOX : objet de la meilleure zone (4) : {g and g.Id}, Result vide`)
advance(Wheel.SpinSeconds + 0.2)
check(#revealsOf(ada) == before and #notifies(ada, giftText(g)) == 1, `pas de scène, Notify « {g and giftText(g)} »`)

section("inventaire plein : le repli, comme avant")
local MAX = sharedModule("Config/Balance").Display.InventoryMax
local full = newProfile8()
for n = 1, MAX do
	addItem(full, string.format("full-%02d", n), "Z1_Banane", nil, 1, n)
end
local dan = join("Dan", full, 74)
advance(1.5)
wheelTest("force 2")
keys = itemKeys(dan)
local cash = dataOf(dan).Cash
spin(dan)
advance(Wheel.SpinSeconds + 0.2)
local dr = wheelResults(dan)
check(#giftsSince(dan, keys) == 0 and dataOf(dan).Cash > cash and dr[1] and string.find(dr[1].args[2], "Prize unavailable", 1, true), `BOX refusé (plein) : repli donné, « {dr[1] and dr[1].args[2]} »`)
check(#revealsOf(dan) == 0, "repli : pas de scène")
check(logCount("[WheelService]", "WARN") == 0 and logCount("[UnboxService]", "WARN") == 0 and logCount("[MonetizationService]", "WARN") == 0, "aucun avertissement")
summary("scénario a309wheel")
