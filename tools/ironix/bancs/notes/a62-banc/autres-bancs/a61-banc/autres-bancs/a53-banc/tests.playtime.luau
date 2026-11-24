--!nocheck
-- Scénario « playtime » (DEV-101, V0 3.3) : paliers de 5, 15, 30 et 60 min de jeu dans la journée UTC, temps
-- compté par le serveur, chaque palier une fois par jour (double clic, palier inconnu, trop tôt), gardés à la
-- reconnexion le même jour, remis à zéro le lendemain ; récompenses 2 min de revenus (100 $ au moins), colis
-- Standard, boost 10 min, colis Premium ; télémétrie.

advance(1000)
startServer()
days(10)
local ada = join("Ada", newProfile8(), 50)
advance(1.5)
local first = stateOf(ada).PlaySeconds
check(first < 2, "à l'arrivée : 0 s de jeu aujourd'hui")
advance(10)
local s = stateOf(ada)
check(near(s.PlaySeconds - first, 10, 0.2), `10 s plus tard : +{s.PlaySeconds - first} s`)

section("trop tôt")
local cash = dataOf(ada).Cash
claimPlay(ada, 5)
check(dataOf(ada).Cash == cash and #notifies(ada, "Keep playing") == 1, "palier de 5 min à 10 s : refusé, Notify « Keep playing… »")
claimPlay(ada, 7)
check(logHas("palier de 7 min inconnu") and dataOf(ada).Cash == cash, "palier inconnu (7) : ignoré")

section("5 min : 2 min de revenus, 100 $ au moins")
advance(290)
claimPlay(ada, 5)
check(dataOf(ada).Cash == cash + 100, `+100 $ ({dataOf(ada).Cash - cash})`)
local tel = telemetryOf(ada, "PlaytimeReward")
check(#tel == 1 and tel[1].amount == 100 and tel[1].sku == "Playtime5", "télémétrie : PlaytimeReward, 100, Playtime5")
local ev = eventsOf(ada, "RewardClaim")
check(#ev == 1 and ev[1].fields[1] == "Source - Playtime" and ev[1].fields[2] == "Sku - Playtime5", "événement RewardClaim Source - Playtime")
advance(0.3)
fireAs(ada, "ClaimPlaytime", 5)
fireAs(ada, "ClaimPlaytime", 5)
flush()
check(dataOf(ada).Cash == cash + 100 and #eventsOf(ada, "RewardClaim") == 1, "double clic après coup : rien de plus")
check(dataOf(ada).Rewards.Playtime.Claimed["5"] ~= nil and ada:GetAttribute("RewardPlayClaimed") == "5", "Claimed[« 5 »] noté, attribut « 5 »")

section("15 min : colis Standard")
claimPlay(ada, 15)
check(#notifies(ada, "Keep playing") == 2, "15 min à 5 min de jeu : refusé")
addPlay(ada, 600)
local before = storedBoxes(ada)
claimPlay(ada, 15)
local count, list = storedBoxes(ada)
local std = nil
for _, b in list do
	std = b
end
check(count == before + 1 and std and std.Tier == "Standard" and std.Zone == 1, "colis Standard zone 1 (aucun objet)")

section("30 min : boost ×2 argent 10 min")
addPlay(ada, 900)
claimPlay(ada, 30)
check(near(ada:GetAttribute("CashBoostEndsAt") or 0, serverTime() + 600, 1.5), "CashBoostEndsAt = maintenant + 10 min")

section("60 min : colis Premium")
addPlay(ada, 1800)
claimPlay(ada, 60)
count, list = storedBoxes(ada)
local prem = 0
for _, b in list do
	if b.Tier == "Premium" then
		prem += 1
	end
end
check(count == before + 2 and prem == 1, "colis Premium dans l'inventaire")
s = stateOf(ada)
check(#s.PlayClaimed == 4 and s.PlayClaimed[1] == 5 and s.PlayClaimed[4] == 60, "4 paliers réclamés")
check(ada:GetAttribute("RewardPlayClaimed") == "5,15,30,60", "attribut « 5,15,30,60 »")
local startAttr = ada:GetAttribute("RewardPlayStart")
check(near(serverTime() - startAttr, s.PlaySeconds, 1.6), "RewardPlayStart suit le temps compté (test « play » compris)")
check(#eventsOf(ada, "RewardClaim") == 4 and #telemetryOf(ada, "PlaytimeReward") == 1, "4 événements, 1 seul gain d'argent")

section("reconnexion le même jour : rien à refaire")
local played = s.PlaySeconds
leave(ada)
advance(30)
ada = join("Ada", nil, 50)
advance(1.5)
s = stateOf(ada)
check(s and s.PlaySeconds >= played and s.PlaySeconds < played + 3, `temps de jeu gardé ({math.floor(s.PlaySeconds)} s, l'absence ne compte pas)`)
check(#s.PlayClaimed == 4, "paliers déjà réclamés gardés")
cash = dataOf(ada).Cash
claimPlay(ada, 5)
check(dataOf(ada).Cash == cash, "5 min de nouveau : rien")

section("le lendemain : tout repart à zéro")
days(1)
s = stateOf(ada)
check(#s.PlayClaimed == 0 and s.PlaySeconds < 2, "nouveau jour : 0 s, aucun palier")
addPlay(ada, 300)
claimPlay(ada, 5)
check(dataOf(ada).Cash == cash + 100, "5 min réclamable de nouveau")
check(logCount("[RewardService]", "WARN") == 0, "aucun avertissement de RewardService")
summary("scénario playtime")
