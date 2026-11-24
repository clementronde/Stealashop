--!nocheck
-- Scénario « gain » (DEV-102) : gain exact (absence × revenu × Rate), plafond de 4 h, message au retour
-- (après NotifyDelay), télémétrie Offline / Income, joueur sans boutique.
-- Copie d'a59 (2026-11-10, L-091 : plus de caisse CashPad) : le gain est versé directement dans Cash au
-- retour (source « Offline » d'OnCashOut, attribut CashCollected), rien ne reste sur les plaques.
-- Copie d'a64 (2026-11-11, L-092 3f) : le gain attend le Claim (join réclame tout de suite, helpers.luau) ;
-- plus de Notify au retour (l'écran UI_Offline le remplace) ; moins de 1 $ : rien en attente, rien versé.

advance(1000)
startServer()
local cashOutSources = {}
DisplayService.OnCashOut(function(player, amount, source)
	table.insert(cashOutSources, { player = player, amount = amount, source = source })
end)

section("gain exact versé dans l'argent")
alignSecond()
local wall = wallNow()
local ada = join("Ada", newProfile(6, { LastSeenAt = wall - 600, Income = 50 }))
local credits = creditsOf(ada)
check(#credits == 1 and credits[1].ok and credits[1].amount == 600 * 50 * Offline.Rate, `600 s × 50 $/s × {Offline.Rate} = {600 * 50} $ (versé : {credits[1] and credits[1].amount})`)
check(dataOf(ada).Offline.LastSeenAt == wall, "LastSeenAt remis à maintenant dès le retour")
check(dataOf(ada).Cash == 31000, "Cash : 1 000 + 30 000 $, versés tout de suite")
check(DisplayService.GetRegister(ada) == 0 and (shopOf(ada):GetAttribute("CashRegister") or 0) == 0, "rien sur les plaques (CashRegister = 0)")
check(ada:GetAttribute("CashCollected") == 30000, "CashCollected = 30 000 (le client voit l'encaissement : OnCashOut)")
local adaOut = nil
for _, e in cashOutSources do
	if e.player == ada then
		adaOut = e
	end
end
check(adaOut ~= nil and adaOut.source == "Offline" and adaOut.amount == 30000, "OnCashOut(Ada, 30 000, « Offline »)")
check(logHas("[OfflineService] Ada absent 10 min 00 s, revenu $50/s × 1 : $30K, $30K en attente du Claim", "PRINT", "server"), "une ligne dans la sortie au retour")
check(logHas("[OfflineService] Ada réclame ses gains hors ligne : $30K versés dans son argent", "PRINT", "server"), "une ligne au Claim")
check(ada:GetAttribute("OfflinePending") == 0 and (dataOf(ada).Offline.Pending or 0) == 0, "après le Claim : plus rien en attente")
advance(Offline.OpenDelay + 0.1)
check(#notifies(ada, "while you were away") == 0, "aucun message du serveur (l'écran UI_Offline le remplace)")

section("télémétrie Offline")
leave(ada)
local offline = economyFor(ada, "Offline")
check(#offline == 1 and offline[1].amount == 30000 and offline[1].transaction == "TimedReward", "télémétrie : Offline 30 000 $ (TimedReward), envoyée au départ (cumul)")
check(offline[1] and offline[1].flow.Name == "Source" and offline[1].currency == "Cash" and offline[1].balance == 31000, "Source, monnaie Cash, solde 31 000 $")
check(#economyFor(ada, "Income") == 0, "rien en Income : tout venait des gains hors ligne")

section("plafond de 4 h")
alignSecond()
local bea = join("Bea", newProfile(6, { LastSeenAt = wallNow() - 10 * 3600, Income = 10 }))
local capped = creditsOf(bea)
check(#capped == 1 and capped[1].amount == Offline.MaxHours * 3600 * 10, `10 h d'absence : comptées {Offline.MaxHours} h → {Offline.MaxHours * 3600 * 10} $ ({capped[1] and capped[1].amount})`)
check(logHas("[OfflineService] Bea absent 10 h 00 min, comptées 4 h 00 min (plafond 4 h), revenu $10/s × 1 : $144K, $144K en attente du Claim", "PRINT", "server"), "la sortie dit le plafond")
check(logHas("[OfflineService] Bea réclame ses gains hors ligne : $144K versés dans son argent", "PRINT", "server"), "Claim : $144K")

section("départ : sauvegardé, télémétrie Offline")
leave(bea)
check(SAVED["Player_2"].Cash == 1000 + 144000, "sauvegardé : Cash = 1 000 + 144 000 $")
check(sumOf(economyFor(bea, "Offline")) == 144000 and #economyFor(bea, "Income") == 0, "télémétrie : 144 000 $ en Offline")

section("gain mixte : hors ligne d'abord, puis Income ramassé sur la plaque")
alignSecond()
local p = newProfile(6, { LastSeenAt = wallNow() - 100, Income = 7 })
addItem(p, "d", "Z1_Donut", 1, 1, 500)
local cid = join("Cid", p)
check(creditsOf(cid)[1] and creditsOf(cid)[1].amount == 700, "100 s × 7 $/s = 700 $")
check(dataOf(cid).Cash == 1700, "700 $ déjà dans Cash")
advance(10)
local ingame = incomeOf("Z1_Donut")
local register = DisplayService.GetRegister(cid)
check(register >= math.floor(9.5 * ingame) and register <= 11 * ingame, `plaques : revenus en jeu seulement ({register})`)
stepOnPad(cid)
local cashed = dataOf(cid).Cash - 1700
check(cashed >= math.floor(9.5 * ingame), `plaque 1 ramassée : {cashed} $`)
advance(10)
stepOnPad(cid)
leave(cid)
local off, inc = sumOf(economyFor(cid, "Offline")), sumOf(economyFor(cid, "Income"))
check(off == 700, `Offline : 700 $ ({off})`)
check(inc == SAVED["Player_3"].Cash - 1000 - 700 and inc > 0, `Income : le reste ({inc} $), 1er ramassage {cashed} $`)

section("rien à exposer au départ : aucun gain, aucun message")
alignSecond()
local dan = join("Dan", newProfile(6, { LastSeenAt = wallNow() - 3600, Income = 0 }))
advance(Offline.OpenDelay + 0.1)
check(#creditsOf(dan) == 0 and dataOf(dan).Cash == 1000, "revenu 0 : rien versé")
check(#notifies(dan, "while you were away") == 0, "aucun message")
leave(dan)

section("gain de moins de 1 $ : accepté, rien versé, sans message")
alignSecond()
local eve = join("Eve", newProfile(6, { LastSeenAt = wallNow() - 2, Income = 0.25 }))
advance(Offline.OpenDelay + 0.1)
check(#creditsOf(eve) == 0 and eve:GetAttribute("OfflinePending") == 0 and (dataOf(eve).Offline.Pending or 0) == 0, "2 s × 0,25 $/s = 0,50 $ : moins de 1 $, rien en attente, aucun Claim (copie a64)")
check(dataOf(eve).Cash == 1000, "moins de 1 $ : Cash inchangé (dollars entiers)")
check(#notifies(eve, "while you were away") == 0, "moins de 1 $ : aucun message")
leave(eve)

section("joueur sans boutique (6 boutiques prises)")
local others = {}
for i = 1, 6 do
	others[i] = join(`P{i}`, nil)
end
alignSecond()
local fay = join("Fay", newProfile(6, { LastSeenAt = wallNow() - 60, Income = 5 }))
check(shopOf(fay) == nil, "Fay n'a pas de boutique")
check(#creditsOf(fay) == 1 and creditsOf(fay)[1].ok and dataOf(fay).Cash == 1300, "sans boutique : 300 $ versés quand même dans Cash")
leave(others[1])
advance(1.5)
check(shopOf(fay) ~= nil and (shopOf(fay):GetAttribute("CashRegister") or 0) == 0, "boutique donnée ensuite : rien sur ses plaques")
leave(fay)
local fayKey = `Player_{fay.UserId}`
check(SAVED[fayKey].Cash == 1300, "départ : Cash sauvegardé 1 300 $")

summary("scénario gain")
