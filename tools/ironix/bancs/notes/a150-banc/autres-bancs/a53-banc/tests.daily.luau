--!nocheck
-- Copie d'a150 (2026-11-14, vague 43) : J2, J4 et J7 donnent un OBJET dans l'inventaire (UnboxService.GiveItem),
-- tiré comme le contenu du colis (type, zone, MinRarity, MinZone, mutation), Notify « <Rareté> Item: <nom> ».
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

section("objets en zone 3 : J2, objet d'un colis Standard de la zone 3")
local data = newProfile8()
addItem(data, "it_z3", "Z3_Smartphone", 1, 3, 5)
addItem(data, "it_z1", "Z1_Donut", 2, 1, 6)
data.Boxes["old-box"] = { Tier = "Standard", Zone = 1, ItemId = "Z1_Banane", Rarity = "Common", At = 1 }
local ada = join("Ada", data)
advance(1.5)
claimDaily(ada) -- J1
local income = DisplayService.GetIncome(ada) * DisplayService.GetGlobalMultiplier(ada)
check(income > 0, `Ada gagne {income} $/s`)
days(1)
check(stateOf(ada).Day == 2 and not stateOf(ada).DailyClaimed and ada:GetAttribute("RewardDay") == 2, "le lendemain : J2, pas réclamé")
local boxesBefore = storedBoxes(ada)
local keys = itemKeys(ada)
-- Double clic : deux appels dans la même image.
advance(0.6)
fireAs(ada, "ClaimDaily")
fireAs(ada, "ClaimDaily")
flush()
local gifts = giftsSince(ada, keys)
check(#gifts == 1, `double clic : un seul objet ({#gifts})`)
check(storedBoxes(ada) == boxesBefore and dataOf(ada).Boxes["old-box"] ~= nil, "aucun colis de plus ; le colis déjà dans le profil reste (rien de retiré ni converti)")
local gift = gifts[1] and gifts[1].entry
local def = gift and Items.ById[gift.Id]
check(def ~= nil and gift.Zone == 3 and gift.Source == "NPC" and type(gift.At) == "number", "objet du catalogue, Zone 3 (l'objet le plus haut), Source NPC, At posé")
check(def and (def.Zone == 3 or def.Zone == nil), `objet de la zone 3 ({def and def.Id})`)
check(gift and gift.AntiTheft == nil and gift.UnlockAt == nil, "pas d'antivol : un objet prêt à exposer")
check(gift and dataOf(ada).Index ~= nil and dataOf(ada).Index[gift.Id] ~= nil, "découvert dans l'Index")
advance(0.6)
check(gifts[1] and invOf(ada)["Item:" .. gifts[1].uid] ~= nil, "objet dans l'état de l'inventaire (InventoryService)")
check(gift and #notifies(ada, giftText(gift)) == 1, `Notify « {gift and giftText(gift)} »`)
check(#notifies(ada, "Box added") == 0, "plus de Notify « … Box added… »")
local evs = eventsOf(ada, "RewardClaim")
check(#evs == 2 and evs[2].fields[2] == "Sku - Day2" and evs[2].fields[3] == "Gift - Box", "événement RewardClaim Day2, Gift - Box")
check(#telemetryOf(ada, "DailyReward") == 1, "un objet n'envoie pas d'économie (pas d'argent)")

section("J3 : 15 min de revenus actuels")
days(1)
cash = dataOf(ada).Cash
income = DisplayService.GetIncome(ada) * DisplayService.GetGlobalMultiplier(ada)
local expected = math.floor(math.max(income * 60 * 15, 750))
claimDaily(ada)
check(dataOf(ada).Cash == cash + expected, `J3 : +{expected} $ ({dataOf(ada).Cash - cash})`)
check(telemetryOf(ada, "DailyReward")[2].sku == "Day3" and telemetryOf(ada, "DailyReward")[2].amount == expected, "télémétrie Day3")

section("J4 : objet d'un colis Premium")
days(1)
keys = itemKeys(ada)
claimDaily(ada)
gifts = giftsSince(ada, keys)
check(#gifts == 1 and gifts[1].entry.Zone == 3, "un objet de plus, zone 3")
check(gifts[1] and (sharedModule("Config/ShelfBoxes").OddsFor(3, "Premium")[Items.ById[gifts[1].entry.Id].Rarity] or 0) > 0, "rareté possible dans un colis Premium de la zone 3")

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

section("J7 : objet d'un colis Luxe, Épique ou mieux")
days(1)
keys = itemKeys(ada)
claimDaily(ada)
gifts = giftsSince(ada, keys)
local luxe = gifts[1] and gifts[1].entry
check(#gifts == 1 and luxe ~= nil, "un objet de plus")
check(luxe and Rarities.ById[Items.ById[luxe.Id].Rarity].Order >= Rarities.ById.Epic.Order, `rareté {luxe and Items.ById[luxe.Id].Rarity} ≥ Épique`)
check(luxe and luxe.Zone == 3, "zone 3 (plus haute que le minimum 2)")
check(stateOf(ada).Day == 7 and stateOf(ada).DailyClaimed, "J7 réclamé")

section("après J7 : un nouveau cycle à J1")
days(1)
check(stateOf(ada).Day == 1 and not stateOf(ada).DailyClaimed, "le lendemain de J7 : J1")
cash = dataOf(ada).Cash
income = DisplayService.GetIncome(ada) * DisplayService.GetGlobalMultiplier(ada)
claimDaily(ada)
check(dataOf(ada).Cash == cash + math.floor(math.max(income * 300, 250)), "J1 du 2e cycle : 5 min de revenus")

section("J7 sans objet : zone 2 au moins ; tirages Épique ou mieux, mutations tirées")
local daily = dataOf(bob).Rewards.Daily
daily.Streak = 6
daily.LastDay = RewardService.GetDay() - 1
check(stateOf(bob).Day == 7, "Bob : J7")
keys = itemKeys(bob)
claimDaily(bob)
gifts = giftsSince(bob, keys)
check(#gifts == 1 and gifts[1].entry.Zone == 2, "objet zone 2 (aucun objet : zone 1, relevée à 2)")
for uid in dataOf(bob).Items do
	dataOf(bob).Items[uid] = nil
end
local allEpic, allZone, mutated = true, true, 0
for _ = 1, 200 do
	local uid, why, itemId = UnboxService.GiveItem(bob, "Luxe", 2, "Epic")
	local entry = uid and dataOf(bob).Items[uid]
	if entry == nil or entry.Id ~= itemId or Rarities.ById[Items.ById[itemId].Rarity].Order < Rarities.ById.Epic.Order then
		allEpic = false
	end
	local itemDef = entry and Items.ById[entry.Id]
	if itemDef == nil or entry.Zone ~= 2 or (itemDef.Zone ~= nil and itemDef.Zone ~= 2) then
		allZone = false
	end
	if entry and entry.Mutation ~= nil then
		mutated += 1
	end
	if uid then
		dataOf(bob).Items[uid] = nil
	end
end
check(allEpic, "200 objets Luxe zone 2 offerts : tous Épique ou mieux")
check(allZone, "tous de la zone 2 (ou Secret, toutes zones, Zone gardée à 2)")
check(mutated > 0 and mutated < 200, `mutations tirées comme à la mise en rayon ({mutated} sur 200)`)
local z1, why = UnboxService.GiveItem(bob, "Luxe", 1, "Epic")
check(z1 == nil and why == "NoContent" and next(dataOf(bob).Items) == nil, "zone 1 Épique : aucune rareté possible (NoContent), rien d'écrit")
local bad, why2 = UnboxService.GiveItem(bob, "Gold", 2, nil)
check(bad == nil and why2 == "Invalid", "type inconnu : Invalid")
local boxUid = UnboxService.GiveBox(bob, "Luxe", 2, "Epic")
check(boxUid ~= nil and dataOf(bob).Boxes[boxUid] ~= nil, "GiveBox marche toujours (admin, autres sources)")
dataOf(bob).Boxes[boxUid or ""] = nil

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
