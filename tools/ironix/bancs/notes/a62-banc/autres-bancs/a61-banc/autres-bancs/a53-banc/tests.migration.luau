--!nocheck
-- Scénario « migration » (profil v8, DataService MIGRATIONS[8]) : v7 → v8 (Rewards complété depuis le
-- modèle : J1, aucun temps de jeu), v6 → v8 en une fois (colis d'abord rangés par la v7), Rewards déjà là
-- gardé s'il est lisible, valeurs illisibles remises à zéro (avertissements), Rewards qui n'est pas une
-- table remis du modèle, profil v9 refusé (TooNew), sauvegarde en v8 et retour sans 2e migration.

advance(1000)
startServer()
days(10)

local function v7(rewards)
	local data = newProfile8()
	data.Version = 7
	data.Rewards = rewards
	return data
end

section("v7 → v8 : Rewards depuis le modèle")
local ada = join("Ada", v7(nil), 70)
advance(1.5)
local d = dataOf(ada)
check(d.Version == 8, "profil en v8")
check(d.Rewards and d.Rewards.Daily.Streak == 0 and d.Rewards.Daily.LastDay == 0, "Daily : aucun jour réclamé")
check(d.Rewards.Playtime.Seconds < 2 and next(d.Rewards.Playtime.Claimed) == nil, "Playtime : aucun temps, aucun palier")
check(stateOf(ada).Day == 1 and ada:GetAttribute("RewardDay") == 1, "J1 à réclamer")
check(logCount("migration v8", "WARN") == 0, "rien d'abîmé : aucun avertissement")

section("v6 → v8 en une fois")
local old = newProfile(6)
old.Boxes["3"] = { Tier = "Premium", Zone = 2, ItemId = "Z2_YoYo", Rarity = "Uncommon", ReadyAt = 4000 }
local bob = join("Bob", old)
advance(1.5)
local db = dataOf(bob)
check(db.Version == 8 and db.BoxQueue == nil and countKeys(db.Boxes) == 1 and db.Rewards ~= nil, "v6 → v8 : colis rangé (v7), Rewards ajouté (v8)")

section("Rewards déjà là, en partie lisible")
local cy = join("Cy", v7({ Daily = { Streak = 3, LastDay = 9 }, Playtime = { Day = 10, Seconds = 120, Claimed = { ["5"] = 7 } } }))
advance(1.5)
local dc = dataOf(cy)
check(dc.Rewards.Daily.Streak == 3 and dc.Rewards.Daily.LastDay == 9, "Daily lisible gardé")
check(dc.Rewards.Playtime.Seconds >= 120 and dc.Rewards.Playtime.Claimed["5"] == 7, "Playtime lisible gardé (même jour UTC)")
check(stateOf(cy).Day == 4, "J3 hier → J4 aujourd'hui")
local partial = join("Pa", v7({ Daily = { Streak = 2 } }))
advance(1.5)
local dp = dataOf(partial)
check(dp.Rewards.Daily.Streak == 2 and dp.Rewards.Daily.LastDay == 0 and type(dp.Rewards.Playtime) == "table", "champs manquants complétés depuis le modèle")

section("valeurs illisibles")
local di = join("Di", v7({ Daily = { Streak = 12, LastDay = -4 }, Playtime = { Day = 0 / 0, Seconds = "beaucoup", Claimed = 5 } }))
advance(1.5)
local dd = dataOf(di)
check(dd.Rewards.Daily.Streak == 0 and dd.Rewards.Daily.LastDay == 0, "Streak 12 et LastDay −4 : remis à 0")
check(type(dd.Rewards.Playtime.Claimed) == "table" and dd.Rewards.Playtime.Seconds < 2, "Seconds et Claimed illisibles : remis à zéro")
check(logHas("Rewards.Daily.Streak illisible", "WARN") and logHas("Rewards.Playtime.Claimed n'est pas une table", "WARN"), "avertissements dans la sortie")
local ev = join("Ev", v7("abîmé"))
advance(1.5)
check(type(dataOf(ev).Rewards) == "table" and dataOf(ev).Rewards.Daily.Streak == 0, "Rewards qui n'est pas une table : repart du modèle")
check(logHas("Rewards n'est pas une table", "WARN"), "avertissement")
local fi = join("Fi", v7({ Daily = "x", Playtime = { Day = 10, Seconds = 30, Claimed = {} } }))
advance(1.5)
check(type(dataOf(fi).Rewards.Daily) == "table" and dataOf(fi).Rewards.Playtime.Seconds >= 30, "Daily qui n'est pas une table : du modèle, Playtime gardé")

section("profil neuf et profil v9 (serveur pas à jour)")
local ne = join("Ne", nil)
advance(1.5)
check(dataOf(ne).Version == 8 and dataOf(ne).Rewards.Daily.Streak == 0, "profil neuf : v8, Rewards du modèle")
local future = newProfile8()
future.Version = 9
local fu = join("Fu", future)
advance(1.5)
check(dataOf(fu) == nil and #KICKS >= 1 and string.find(KICKS[#KICKS].message, "just updated", 1, true) ~= nil, "profil v9 : refusé (TooNew), joueur expulsé")

section("sauvegarde : v8 écrit, réclamation gardée")
claimDaily(ada)
leave(ada)
advance(2)
local saved = SAVED["Player_70"]
check(saved and saved.Version == 8 and saved.Rewards.Daily.Streak == 1 and saved.Rewards.Daily.LastDay == 10, "sauvegardé en v8 avec J1 réclamé")
local ada2 = join("Ada", nil, 70)
advance(1.5)
check(dataOf(ada2).Version == 8 and stateOf(ada2).DailyClaimed, "retour le même jour : J1 toujours réclamé (un 2e serveur ne redonne rien)")
local cash = dataOf(ada2).Cash
claimDaily(ada2)
check(dataOf(ada2).Cash == cash, "rien de plus")
summary("scénario migration")
