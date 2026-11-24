--!nocheck
-- Scénario « midnight » (DEV-101, 3.3 : remise à zéro à minuit UTC) : la vraie horloge du serveur passe
-- minuit (os.time() // 86400 change), sans le crochet de test : le jour réclamé redevient à réclamer (jour
-- suivant du calendrier), le temps de jeu et ses paliers repartent à zéro, RewardDayEndsAt suit.
-- os.time() du banc part de 0 : on est le jour UTC 0, minuit = 86400.

advance(1000)
startServer()
-- Jour UTC 0 : « LastDay = 0 » voudrait dire « jamais » ; Ada a déjà réclamé hier (jour 0 n'existe
-- pas en vrai, os.time() vaut ~1,8 milliard). On part donc du jour 1 : minuit = 2 × 86400.
advance(DAY - now() + 10, 10)
local data = newProfile8()
local ada = join("Ada", data)
advance(1.5)
claimDaily(ada)
addPlay(ada, 400)
claimPlay(ada, 5)
local s = stateOf(ada)
check(s.Day == 1 and s.DailyClaimed and #s.PlayClaimed == 1 and s.PlaySeconds >= 400, "jour 1 : J1 et le palier de 5 min réclamés")
check(ada:GetAttribute("RewardPlayClaimed") == "5", "attribut RewardPlayClaimed = « 5 »")
local midnight = 2 * DAY
check(near(ada:GetAttribute("RewardDayEndsAt") or 0, serverTime() + (midnight - now()), 1.6), "RewardDayEndsAt = heure serveur du prochain minuit UTC")

section("juste avant minuit")
advance(midnight - 3 - now(), 10)
s = stateOf(ada)
check(s.Day == 1 and s.DailyClaimed and #s.PlayClaimed == 1, "23:59:57 : toujours réclamé")
check(s.PlaySeconds > 80000, `temps de jeu compté par le serveur ({math.floor(s.PlaySeconds)} s)`)

section("minuit passé")
advance(5)
s = stateOf(ada)
check(s.Day == 2 and not s.DailyClaimed, "00:00:02 : J2 à réclamer")
check(#s.PlayClaimed == 0 and s.PlaySeconds < 5, `temps de jeu remis à zéro ({s.PlaySeconds} s), aucun palier réclamé`)
check(ada:GetAttribute("RewardDay") == 2 and ada:GetAttribute("RewardDailyClaimed") == false and ada:GetAttribute("RewardPlayClaimed") == "", "attributs remis à jour à minuit")
local start = ada:GetAttribute("RewardPlayStart")
check(type(start) == "number" and serverTime() - start < 5, "RewardPlayStart : le client compte de nouveau depuis 0")
check(near(ada:GetAttribute("RewardDayEndsAt"), serverTime() + (3 * DAY - now()), 1.6), "RewardDayEndsAt : le minuit suivant")
check(dataOf(ada).Rewards.Playtime.Day == 2, "profil : Playtime.Day = 2")
claimDaily(ada)
check(stateOf(ada).Day == 2 and stateOf(ada).DailyClaimed and dataOf(ada).Rewards.Daily.LastDay == 2, "J2 réclamé le jour UTC 2")
summary("scénario midnight")
