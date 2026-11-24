--!nocheck
-- Scénario « gain » (DEV-102) : gain exact (absence × revenu × Rate), plafond de 4 h, gain versé dans la
-- caisse (CashRegister) et pas dans Cash, encaissé au CashPad, message au retour (après NotifyDelay),
-- télémétrie Offline / Income, départ sans encaisser, joueur sans boutique.

advance(1000)
startServer()

section("gain exact dans la caisse")
alignSecond()
local wall = wallNow()
local ada = join("Ada", newProfile(6, { LastSeenAt = wall - 600, Income = 50 }))
local credits = creditsOf(ada)
check(#credits == 1 and credits[1].ok and credits[1].amount == 600 * 50 * Offline.Rate, `600 s × 50 $/s × {Offline.Rate} = {600 * 50} $ (versé : {credits[1] and credits[1].amount})`)
check(dataOf(ada).Offline.LastSeenAt == wall, "LastSeenAt remis à maintenant dès le retour")
check(dataOf(ada).Cash == 1000, "Cash inchangé : le gain n'est pas dans l'argent")
check(DisplayService.GetRegister(ada) == 30000 and shopOf(ada):GetAttribute("CashRegister") == 30000, "caisse : 30 000 $ (attribut CashRegister de la boutique)")
check(logHas("[OfflineService] Ada absent 10 min 00 s, revenu $50/s × 1 : $30K dans la caisse", "PRINT", "server"), "une ligne dans la sortie")
check(#notifies(ada, "while you were away") == 0, "pas encore de message (le temps que le HUD apparaisse)")
advance(Offline.NotifyDelay + 0.1)
local messages = notifies(ada, "Your shop earned $30K while you were away!")
check(#messages == 1 and messages[1].args[2] == "Info", "« Your shop earned $30K while you were away! » (Info), après NotifyDelay")
check(#notifies(ada, "while you were away") == 1, "un seul message")

section("encaissé au CashPad, télémétrie Offline")
stepOnPad(ada)
check(dataOf(ada).Cash == 31000 and DisplayService.GetRegister(ada) == 0, "tapis de caisse : 30 000 $ passent dans Cash, caisse vide")
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
check(logHas("[OfflineService] Bea absent 10 h 00 min, comptées 4 h 00 min (plafond 4 h), revenu $10/s × 1 : $144K dans la caisse", "PRINT", "server"), "la sortie dit le plafond")
advance(Offline.NotifyDelay + 0.1)
check(#notifies(bea, "Your shop earned $144K while you were away!") == 1, "message : $144K")

section("départ sans encaisser : la caisse passe dans Cash, télémétrie Offline")
leave(bea)
check(SAVED["Player_2"].Cash == 1000 + 144000, "sauvegardé : Cash = 1 000 + 144 000 $")
check(sumOf(economyFor(bea, "Offline")) == 144000 and #economyFor(bea, "Income") == 0, "télémétrie : 144 000 $ en Offline")

section("gain mixte : hors ligne compté en premier, puis Income")
alignSecond()
local p = newProfile(6, { LastSeenAt = wallNow() - 100, Income = 7 })
addItem(p, "d", "Z1_Donut", 1, 1, 500)
local cid = join("Cid", p)
check(creditsOf(cid)[1] and creditsOf(cid)[1].amount == 700, "100 s × 7 $/s = 700 $")
advance(10)
local ingame = incomeOf("Z1_Donut")
local register = DisplayService.GetRegister(cid)
check(register >= 700 + math.floor(9.5 * ingame) and register <= 700 + 11 * ingame, `caisse : 700 $ hors ligne + revenus en jeu ({register})`)
stepOnPad(cid)
local cashed = dataOf(cid).Cash - 1000
advance(10)
stepOnPad(cid)
leave(cid)
local off, inc = sumOf(economyFor(cid, "Offline")), sumOf(economyFor(cid, "Income"))
check(off == 700, `Offline : 700 $ ({off})`)
check(inc == SAVED["Player_3"].Cash - 1000 - 700 and inc > 0, `Income : le reste ({inc} $), 1er encaissement {cashed} $`)

section("rien à exposer au départ : aucun gain, aucun message")
alignSecond()
local dan = join("Dan", newProfile(6, { LastSeenAt = wallNow() - 3600, Income = 0 }))
advance(Offline.NotifyDelay + 0.1)
check(#creditsOf(dan) == 0 and DisplayService.GetRegister(dan) == 0, "revenu 0 : rien versé")
check(#notifies(dan, "while you were away") == 0, "aucun message")
leave(dan)

section("gain de moins de 1 $ : versé, sans message")
alignSecond()
local eve = join("Eve", newProfile(6, { LastSeenAt = wallNow() - 2, Income = 0.25 }))
advance(Offline.NotifyDelay + 0.1)
check(#creditsOf(eve) == 1 and near(creditsOf(eve)[1].amount, 0.5), "2 s × 0,25 $/s = 0,50 $ versés")
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
check(#creditsOf(fay) == 1 and creditsOf(fay)[1].ok and DisplayService.GetRegister(fay) == 300, "300 $ gardés dans son compte en attendant une boutique")
leave(others[1])
advance(1.5)
check(shopOf(fay) ~= nil and DisplayService.GetRegister(fay) >= 300 and shopOf(fay):GetAttribute("CashRegister") >= 300, "boutique libérée puis donnée : la caisse affiche ses 300 $")
leave(fay)
local fayKey = `Player_{fay.UserId}`
check(SAVED[fayKey].Cash == 1300, "départ : 300 $ encaissés dans Cash")

summary("scénario gain")
