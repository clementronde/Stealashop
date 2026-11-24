--!nocheck
-- Scénario « daily » (DEV-101, Partie 2 3.3) : calendrier J1 à J7 avec les récompenses du doc (minutes de
-- revenus avec le minimum de 50 $/min, colis Standard / Premium / Luxe Épique ou mieux dans l'inventaire,
-- zone = la plus haute des objets, J7 zone 2 au moins ; boost ×2 argent boutique Robux coupée), une
-- réclamation par jour (deux réclamations le même jour, double clic), jour manqué = un jour en arrière,
-- cycle qui repart à J1, télémétrie de chaque gain.

advance(1000)
startServer()
days(10) -- jours UTC ≥ 10 : « hier » existe (os.time() du banc part de 0)

section("J1 : 5 min de revenus, 250 $ au moins (aucun objet exposé)")
local bob = join("Bob", newProfile8())
advance(1.5)
local s = stateOf(bob)
check(s and s.Day == 1 and not s.DailyClaimed, "nouveau joueur : J1, pas réclamé")
check(bob:GetAttribute("RewardDay") == 1 and bob:GetAttribute("RewardDailyClaimed") == false, "attributs RewardDay = 1, RewardDailyClaimed = false")
local cash = dataOf(bob).Cash
claimDaily(bob)
check(dataOf(bob).Cash == cash + 250, `+250 $ (5 × 50 $ au moins) : {dataOf(bob).Cash - cash}`)
local tel = telemetryOf(bob, "DailyReward")
check(#tel == 1 and tel[1].amount == 250 and tel[1].sku == "Day1", "télémétrie : LogEconomy DailyReward, 250, Day1")
check(tel[1] and tel[1].cash == dataOf(bob).Cash, "LogEconomy appelé juste après AddCash (solde à jour)")
local ev = eventsOf(bob, "RewardClaim")
check(#ev == 1 and ev[1].fields[1] == "Source - Daily" and ev[1].fields[2] == "Sku - Day1" and ev[1].fields[3] == "Gift - Cash", "événement RewardClaim : Source - Daily, Sku - Day1, Gift - Cash")
check(#notifies(bob, "+$250 cash!") == 1, "Notify « +$250 cash! »")
check(stateOf(bob).DailyClaimed and bob:GetAttribute("RewardDailyClaimed") == true, "J1 réclamé (état et attribut)")
check(dataOf(bob).Rewards.Daily.Streak == 1 and dataOf(bob).Rewards.Daily.LastDay == RewardService.GetDay(), "profil : Streak = 1, LastDay = aujourd'hui")

section("deux réclamations le même jour")
cash = dataOf(bob).Cash
claimDaily(bob)
check(dataOf(bob).Cash == cash and #telemetryOf(bob, "DailyReward") == 1, "2e réclamation : rien de plus")
check(#notifies(bob, "Already claimed today") == 1, "Notify « Already claimed today… »")

section("objets en zone 3 : J2, colis Standard de la zone 3")
local data = newProfile8()
addItem(data, "it_z3", "Z3_Smartphone", 1, 3, 5)
addItem(data, "it_z1", "Z1_Donut", 2, 1, 6)
local ada = join("Ada", data)
advance(1.5)
claimDaily(ada) -- J1
local income = DisplayService.GetIncome(ada) * DisplayService.GetGlobalMultiplier(ada)
check(income > 0, `Ada gagne {income} $/s`)
days(1)
check(stateOf(ada).Day == 2 and not stateOf(ada).DailyClaimed and ada:GetAttribute("RewardDay") == 2, "le lendemain : J2, pas réclamé")
local before = storedBoxes(ada)
-- Double clic : deux appels dans la même image.
advance(0.6)
fireAs(ada, "ClaimDaily")
fireAs(ada, "ClaimDaily")
flush()
local count, list = storedBoxes(ada)
check(count == before + 1, `double clic : un seul colis ({count - before})`)
local uid, box = next(list)
check(box and box.Tier == "Standard" and box.Zone == 3 and box.Spot == nil and box.ReadyAt == nil, "colis Standard, zone 3 (l'objet le plus haut), dans l'inventaire")
check(box and Items.ById[box.ItemId] and Items.ById[box.ItemId].Rarity == box.Rarity, "contenu tiré par le serveur (rareté de l'objet)")
check(box and type(box.At) == "number", "At posé (ordre de la barre)")
advance(0.6)
check(invOf(ada)["Box:" .. uid] ~= nil and countKeys(toolsOf(ada)) == 0, "colis dans l'état de l'inventaire (InventoryService), sans Tool (copie d'a61)")
check(#notifies(ada, "Standard Box added to your inventory!") == 1, "Notify « Standard Box added… »")
local evs = eventsOf(ada, "RewardClaim")
check(#evs == 2 and evs[2].fields[2] == "Sku - Day2" and evs[2].fields[3] == "Gift - Box", "événement RewardClaim Day2, Gift - Box")
check(#telemetryOf(ada, "DailyReward") == 1, "un colis n'envoie pas d'économie (pas d'argent)")

section("J3 : 15 min de revenus actuels")
days(1)
cash = dataOf(ada).Cash
income = DisplayService.GetIncome(ada) * DisplayService.GetGlobalMultiplier(ada)
local expected = math.floor(math.max(income * 60 * 15, 750))
claimDaily(ada)
check(dataOf(ada).Cash == cash + expected, `J3 : +{expected} $ ({dataOf(ada).Cash - cash})`)
check(telemetryOf(ada, "DailyReward")[2].sku == "Day3" and telemetryOf(ada, "DailyReward")[2].amount == expected, "télémétrie Day3")

section("J4 : colis Premium")
days(1)
before = storedBoxes(ada)
claimDaily(ada)
count, list = storedBoxes(ada)
local premium = 0
for _, b in list do
	if b.Tier == "Premium" and b.Zone == 3 then
		premium += 1
	end
end
check(count == before + 1 and premium == 1, "un colis Premium zone 3 de plus")

section("J5 : boost ×2 argent 15 min, boutique Robux coupée")
days(1)
check(MonetizationService.IsEnabled() == false, "Features.RobuxShop = false")
local g0 = DisplayService.GetGlobalMultiplier(ada)
claimDaily(ada)
local endsAt = ada:GetAttribute("CashBoostEndsAt")
check(type(endsAt) == "number" and near(endsAt, serverTime() + 900, 1.5), "CashBoostEndsAt = maintenant + 15 min")
check(near(DisplayService.GetGlobalMultiplier(ada), g0 * 2), `revenus ×2 ({g0} → {DisplayService.GetGlobalMultiplier(ada)})`)
check(near(dataOf(ada).Boosts.Cash, 900, 1.5), "Boosts.Cash = 900 s (profil)")
check(#notifies(ada, "×2 Cash for 15 min!") == 1, "Notify « ×2 Cash for 15 min! »")
check(eventsOf(ada, "RewardClaim")[5].fields[3] == "Gift - Boost", "événement Gift - Boost")

section("J6 : 30 min de revenus, boost compris")
days(1)
cash = dataOf(ada).Cash
income = DisplayService.GetIncome(ada) * DisplayService.GetGlobalMultiplier(ada)
expected = math.floor(math.max(income * 60 * 30, 1500))
claimDaily(ada)
check(dataOf(ada).Cash == cash + expected, `J6 : +{expected} $ (revenu ×2 pendant le boost)`)

section("J7 : colis Luxe Épique ou mieux")
days(1)
before = storedBoxes(ada)
claimDaily(ada)
count, list = storedBoxes(ada)
local luxe = nil
for _, b in list do
	if b.Tier == "Luxe" then
		luxe = b
	end
end
check(count == before + 1 and luxe ~= nil, "un colis Luxe de plus")
check(luxe and Rarities.ById[luxe.Rarity].Order >= Rarities.ById.Epic.Order, `rareté {luxe and luxe.Rarity} ≥ Épique`)
check(luxe and luxe.Zone == 3, "zone 3 (plus haute que le minimum 2)")
check(stateOf(ada).Day == 7 and stateOf(ada).DailyClaimed, "J7 réclamé")

section("après J7 : un nouveau cycle à J1")
days(1)
check(stateOf(ada).Day == 1 and not stateOf(ada).DailyClaimed, "le lendemain de J7 : J1")
cash = dataOf(ada).Cash
income = DisplayService.GetIncome(ada) * DisplayService.GetGlobalMultiplier(ada)
claimDaily(ada)
check(dataOf(ada).Cash == cash + math.floor(math.max(income * 300, 250)), "J1 du 2e cycle : 5 min de revenus")

section("J7 sans objet : zone 2 au moins ; tirages Épique ou mieux")
local daily = dataOf(bob).Rewards.Daily
daily.Streak = 6
daily.LastDay = RewardService.GetDay() - 1
check(stateOf(bob).Day == 7, "Bob : J7")
before = storedBoxes(bob)
claimDaily(bob)
count, list = storedBoxes(bob)
local bobLuxe = nil
for _, b in list do
	bobLuxe = b
end
check(count == before + 1 and bobLuxe and bobLuxe.Tier == "Luxe" and bobLuxe.Zone == 2, "colis Luxe zone 2 (aucun objet : zone 1, relevée à 2)")
local allEpic = true
for _ = 1, 40 do
	local giftUid = UnboxService.GiveBox(bob, "Luxe", 2, "Epic")
	local gift = giftUid and dataOf(bob).Boxes[giftUid]
	if gift == nil or Rarities.ById[gift.Rarity].Order < Rarities.ById.Epic.Order or Items.ById[gift.ItemId].Rarity ~= gift.Rarity then
		allEpic = false
	end
	dataOf(bob).Boxes[giftUid or ""] = nil
end
check(allEpic, "40 colis Luxe zone 2 offerts : tous Épique ou mieux, objet de la même rareté")
local z1, why = UnboxService.GiveBox(bob, "Luxe", 1, "Epic")
check(z1 == nil and why == "NoContent", "zone 1 Épique : aucune rareté possible (NoContent), rien d'écrit")
local bad, why2 = UnboxService.GiveBox(bob, "Gold", 2, nil)
check(bad == nil and why2 == "Invalid", "type inconnu : Invalid")

section("jour manqué : un jour en arrière, jamais avant J1")
local function statusFor(streak, ago)
	local d = dataOf(bob).Rewards.Daily
	d.Streak = streak
	d.LastDay = RewardService.GetDay() - ago
	return stateOf(bob)
end
check(statusFor(4, 1).Day == 5, "J4 hier → J5")
check(statusFor(4, 2).Day == 4, "J4 avant-hier (1 jour manqué) → J4 à nouveau")
check(statusFor(4, 3).Day == 3, "2 jours manqués → J3")
check(statusFor(1, 5).Day == 1, "J1 il y a 5 jours → J1 (jamais avant)")
check(statusFor(7, 3).Day == 1, "cycle fini il y a 3 jours → J1")
local future = statusFor(3, -2)
check(future.Day == 3 and future.DailyClaimed, "LastDay dans le futur (horloge qui recule) : rien à réclamer")
statusFor(4, 2)
cash = dataOf(bob).Cash
claimDaily(bob)
check(dataOf(bob).Rewards.Daily.Streak == 4 and stateOf(bob).DailyClaimed, "J4 réclamé à nouveau après un jour manqué (Streak reste 4)")
advance(1.2)
check(bob:GetAttribute("RewardDay") == 4 and bob:GetAttribute("RewardDailyClaimed") == true, "attributs remis à jour")

check(not logHas("ERREUR") and logCount("[RewardService]", "WARN") == 0, "aucun avertissement de RewardService")
summary("scénario daily")
