--!nocheck
-- Scénario « reward » d'a55 (L-083 point 7) : zone complète de l'Index = prime unique (Index.ZoneCash,
-- 10 min de revenu de la collection de la zone), +3 % de WalkSpeed permanent (modificateur « Index » de
-- StatsService) et les +5 % de revenus d'avant. Prime une seule fois par zone et par joueur
-- (IndexRewards du profil), télémétrie IndexReward, Notify, profil abîmé, réapparition.
-- Copie a117 (vague 34, L-127 point 2) : la prime n'est plus versée toute seule (ni à la complétion, ni au
-- chargement) : elle attend IndexService.Claim (remote ClaimIndexReward) ; message ZoneComplete changé.
-- Les réclamations elles-mêmes (zone, toutes, double demande, refus) sont dans a117-banc.

advance(1000)
startServer()
StatsService = serverModule("StatsService")

local function walk(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return if humanoid then humanoid.WalkSpeed else -1
end
local function telemetryOf(player)
	local list = {}
	for _, e in TELEMETRY do
		if e.player == player and e.kind == "IndexReward" then
			table.insert(list, e)
		end
	end
	return list
end
-- Profil v3 (migré au chargement) avec tous les objets des zones `zones`, sauf `missing`.
local function profileWith(zones, missing)
	local data = newProfile()
	local n = 0
	for _, zone in zones do
		for _, item in Index.ByZone[zone] do
			if item.Id ~= missing then
				n += 1
				addItem(data, `it-{n}`, item.Id, nil, zone, 500)
			end
		end
	end
	return data
end

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(Features.Index == true, "Features.Index = true (pre.on)")

section("Config/Index : montants")
check(Index.ZoneCashMinutes == 10 and Index.ZoneSpeedBonus == 0.03 and Index.ZoneBonus == 0.05, "10 min, +3 % de vitesse, +5 % de revenus")
local cashes = {}
for zone = 1, Index.ZoneCount do
	local expected = 0
	for _, item in Index.ByZone[zone] do
		expected += Formulas.ItemIncome(zone, item.Rarity)
	end
	expected = math.floor(expected * 600)
	check(Index.ZoneCash(zone) == expected, `zone {zone} : prime {Index.ZoneCash(zone)} $ = 600 × revenu de la collection`)
	table.insert(cashes, `{zone} = {Index.ZoneCash(zone)} ({Index.ZoneRewardText(zone)})`)
end
print("    primes : " .. table.concat(cashes, " ; "))
check(Index.ZoneCash(1) == 10200 and Index.ZoneCash(2) == 1531200, "zone 1 : 10 200 $ (17 $/s), zone 2 : 1 531 200 $ (2 552 $/s)")
check(Index.ZoneCash(0) == 0 and Index.ZoneCash(7) == 0, "zone inconnue : 0")
check(Index.ZoneRewardText(1) == "+$10.2K +3% SPEED +5% INCOME", `texte de l'écran : « {Index.ZoneRewardText(1)} »`)
local r = Index.ZoneReward(2)
check(r.Cash == 1531200 and r.Speed == 0.03 and r.Income == 0.05, "ZoneReward(2)")
check(Index.SpeedMultiplier({}) == 1, "aucune zone : × 1")

section("zone complétée en jeu : prime, vitesse, télémétrie, message")
local ada = join("Ada", profileWith({ 1 }, "Z1_Carotte"))
advance(1.5)
check(dataOf(ada).IndexRewards == nil, "profil chargé sans IndexRewards (champ facultatif, aucune prime due)")
check(math.abs(walk(ada) - 16) < 1e-3, `WalkSpeed 16 sans zone complète ({walk(ada)})`)
check(IndexService.GetSpeedMultiplier(ada) == 1, "GetSpeedMultiplier = 1")
local cash0 = dataOf(ada).Cash
check(IndexService.Discover(ada, "Z1_Carotte"), "la Carotte complète la zone 1")
flush()
check(dataOf(ada).Cash == cash0 and dataOf(ada).IndexRewards == nil, "a117 : prime pas versée toute seule")
check(#notifies(ada, "Index: Zone 1 complete! +3% speed and +5% income forever. Claim your $10.2K in the Index!") == 1, "un Notify (a117 : la prime est à réclamer)")
check(IndexService.Claim(ada, 1) == 1, "a117 : Claim(zone 1) verse 1 prime")
check(dataOf(ada).Cash == cash0 + 10200, `prime de 10 200 $ (trouvé +{dataOf(ada).Cash - cash0})`)
check(type(dataOf(ada).IndexRewards) == "table" and type(dataOf(ada).IndexRewards["1"]) == "number", "IndexRewards[« 1 »] = date du versement")
local tel = telemetryOf(ada)
check(#tel == 1 and tel[1].amount == 10200 and tel[1].sku == "IndexZone1", "télémétrie : IndexReward, 10 200, SKU IndexZone1")
check(math.abs(walk(ada) - 16 * 1.03) < 1e-3, `WalkSpeed × 1,03 = 16,48 ({walk(ada)})`)
check(math.abs(IndexService.GetSpeedMultiplier(ada) - 1.03) < 1e-9, "GetSpeedMultiplier = 1,03")
check(math.abs(IndexService.GetIncomeBonus(ada) - 0.05) < 1e-9, "les +5 % de revenus restent")
check(ada:GetAttribute("WalkSpeed") == 16, "attribut WalkSpeed (formule 7.1, sans modificateurs) inchangé")

section("une seule fois")
check(not IndexService.Discover(ada, "Z1_Carotte"), "2e Discover : rien")
check(IndexService.Claim(ada, 1) == 0 and IndexService.Claim(ada, nil) == 0, "a117 : 2e Claim refusé")
flush()
check(dataOf(ada).Cash == cash0 + 10200 and #telemetryOf(ada) == 1 and #notifies(ada, "complete") == 1, "ni 2e prime, ni 2e message")
spawnCharacter(ada, Vector3.new(0, 3, 0))
advance(0.5)
check(math.abs(walk(ada) - 16.48) < 1e-3, `réapparition : toujours × 1,03 ({walk(ada)})`)
local paidAt = dataOf(ada).IndexRewards["1"]
leave(ada)
local saved = SAVED["Player_1"]
check(saved ~= nil and saved.IndexRewards ~= nil and saved.IndexRewards["1"] == paidAt, "sauvegardé avec IndexRewards")
local cashSaved = saved.Cash
local back = join("Ada", nil, 1)
advance(1.5)
check(dataOf(back).Cash == cashSaved and #telemetryOf(back) == 0 and #notifies(back, "complete") == 0, "retour : rien de plus")
check(math.abs(walk(back) - 16.48) < 1e-3, `retour : vitesse remise au chargement ({walk(back)})`)
leave(back)

section("zones déjà complètes au chargement (profil d'avant ce code) : à réclamer, payées une fois (a117)")
local bob = join("Bob", profileWith({ 1, 2 }))
advance(1.5)
local bd = dataOf(bob)
check(bd.Cash == 1000 and bd.IndexRewards == nil and #notifies(bob, "complete") == 0, `a117 : rien de versé au chargement, ni message ({bd.Cash} $)`)
check(bob:GetAttribute("IndexClaimed") == "", "a117 : attribut IndexClaimed vide")
check(IndexService.Claim(bob, nil) == 2, "a117 : Claim All verse 2 primes")
check(bd.Cash == 1000 + 10200 + 1531200, `zones 1 et 2 payées : {bd.Cash} $`)
check(bd.IndexRewards["1"] ~= nil and bd.IndexRewards["2"] ~= nil and bd.IndexRewards["3"] == nil, "IndexRewards : 1 et 2")
check(#telemetryOf(bob) == 2, "2 envois de télémétrie")
check(bob:GetAttribute("IndexClaimed") == "1,2", "a117 : IndexClaimed « 1,2 »")
check(math.abs(walk(bob) - 16 * 1.06) < 1e-3, `WalkSpeed × 1,06 ({walk(bob)})`)
local bobUser = bob.UserId
leave(bob)
local bob2 = join("Bob", nil, bobUser)
advance(1.5)
check(dataOf(bob2).Cash == 1000 + 10200 + 1531200 and #notifies(bob2, "complete") == 0, "retour : aucune 2e prime")
leave(bob2)

section("colis : prime à la révélation, pas avant")
local cid = join("Cid", profileWith({ 1 }, "Z1_Carotte"))
advance(1.5)
local c0 = dataOf(cid).Cash
check(openBox(cid, 1, "Common", "Z1_Carotte", "Standard", 1) ~= nil, "la Carotte ouverte")
check(dataOf(cid).Cash == c0 and math.abs(walk(cid) - 16) < 1e-3 and dataOf(cid).IndexRewards == nil, "avant la révélation : ni prime ni vitesse")
advance(revealDelay("Common") + 0.5)
check(dataOf(cid).Cash == c0 and math.abs(walk(cid) - 16.48) < 1e-3 and #notifies(cid, "Zone 1 complete") == 1, "à la révélation : vitesse et message, prime à réclamer (a117)")
check(IndexService.Claim(cid, 1) == 1 and dataOf(cid).Cash == c0 + 10200, "a117 : réclamée, prime versée")
leave(cid)

section("départ pendant la révélation : à réclamer au retour (a117)")
local dan = join("Dan", profileWith({ 1 }, "Z1_Carotte"))
advance(1.5)
local danUser = dan.UserId
check(openBox(dan, 1, "Common", "Z1_Carotte", "Standard", 1) ~= nil, "la Carotte ouverte")
leave(dan)
advance(revealDelay("Common") + 0.5)
check(SAVED[`Player_{danUser}`] ~= nil and SAVED[`Player_{danUser}`].IndexRewards == nil, "parti avant : rien de versé")
local d0 = SAVED[`Player_{danUser}`].Cash
local dan2 = join("Dan", nil, danUser)
advance(1.5)
check(dataOf(dan2).Cash == d0 and dataOf(dan2).IndexRewards == nil and math.abs(walk(dan2) - 16.48) < 1e-3, "retour : vitesse, prime pas versée toute seule (a117)")
check(IndexService.Claim(dan2, nil) == 1 and dataOf(dan2).Cash == d0 + 10200 and dataOf(dan2).IndexRewards["1"] ~= nil, "retour : prime réclamée, versée une fois (a117)")
leave(dan2)

section("IndexRewards abîmé : rien de versé, vitesse quand même")
local broken = profileWith({ 1 })
broken.IndexRewards = "oups"
local eve = join("Eve", broken)
advance(1.5)
check(IndexService.Claim(eve, nil) == 0, "a117 : réclamation refusée")
check(dataOf(eve).Cash == 1000 and #telemetryOf(eve) == 0, "aucune prime (on ne sait plus ce qui est payé)")
check(eve:GetAttribute("IndexClaimed") == "1", "a117 : IndexClaimed = les zones complètes (rien à montrer à réclamer)")
check(logHas("[IndexService] Eve : IndexRewards illisible", "WARN", "server"), "avertissement")
check(math.abs(walk(eve) - 16.48) < 1e-3, `vitesse × 1,03 ({walk(eve)})`)
leave(eve)

summary("scénario reward")
