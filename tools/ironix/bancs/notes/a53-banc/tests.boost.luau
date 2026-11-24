--!nocheck
-- Scénario « boost » (DEV-101) : boost ×2 argent des récompenses avec la boutique Robux coupée
-- (Features.RobuxShop = false, valeur du dépôt) : un 2e boost prolonge le 1er, il n'est compté qu'en jeu
-- (gardé dans Boosts.Cash au départ), il finit (attribut retiré, ×1), il ne compte pas hors ligne
-- (GetTemporaryIncomeMultiplier) ; rien d'autre de la boutique ne s'allume (ni pack de départ, ni Ouvrir
-- maintenant).

advance(1000)
startServer()
days(10)
local data = newProfile8()
addItem(data, "it1", "Z2_YoYo", 1, 2, 5)
data.Lifetime.PlaySeconds = 0 -- 1re heure : le pack de départ serait proposé si la boutique était ouverte
data.Rewards.Daily = { Streak = 4, LastDay = 9 } -- J5 aujourd'hui
local ada = join("Ada", data, 60)
advance(1.5)
check(ada:GetAttribute("StarterPackEndsAt") == nil, "boutique coupée : pas d'offre du pack de départ")
local g0 = DisplayService.GetGlobalMultiplier(ada)
check(near(MonetizationService.GetTemporaryIncomeMultiplier(ada), 1), "pas de boost : ×1")

section("J5 puis palier de 30 min : 15 + 10 min")
claimDaily(ada)
addPlay(ada, 1800)
claimPlay(ada, 30)
check(near(ada:GetAttribute("CashBoostEndsAt") or 0, serverTime() + 1500, 2), "le 2e boost prolonge le 1er : 25 min")
check(near(DisplayService.GetGlobalMultiplier(ada), g0 * 2), "×2, pas ×4")
check(near(MonetizationService.GetTemporaryIncomeMultiplier(ada), 2), "GetTemporaryIncomeMultiplier = 2 (hors ligne : retiré)")
advance(1.2)
check(ada:GetAttribute("OpenNowReadyAt") == nil, "boutique coupée : pas d'OpenNowReadyAt")

section("compté seulement en jeu")
advance(100)
local left = ada:GetAttribute("CashBoostEndsAt") - serverTime()
leave(ada)
local saved = SAVED["Player_60"]
check(saved and near(saved.Boosts.Cash, left, 1.2), `départ : reste gardé dans le profil ({saved and saved.Boosts.Cash})`)
advance(500)
ada = join("Ada", nil, 60)
advance(1.5)
check(near(ada:GetAttribute("CashBoostEndsAt") or 0, serverTime() + saved.Boosts.Cash, 2), `retour : le boost reprend où il en était ({(ada:GetAttribute("CashBoostEndsAt") or 0) - serverTime()} s)`)
advance(saved.Boosts.Cash + 3, 1)
check(ada:GetAttribute("CashBoostEndsAt") == nil, "boost fini : attribut retiré")
check(near(DisplayService.GetGlobalMultiplier(ada), g0), "revenus ×1 de nouveau")
summary("scénario boost")
