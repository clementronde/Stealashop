--!nocheck
-- Banc a64 (vague 22, L-092 3f), côté serveur : gains hors ligne en attente du Claim (vrai OfflineService,
-- vrai DataService avec le faux ProfileStore d'ext38, vrai DisplayService, vrai TelemetryService, vrai Net).
-- Monté sur la copie a64 du banc a48 (autres-bancs/a48-banc : stubs, setup, helpers), sans le Claim
-- automatique de join (AUTO_CLAIM = false) : chaque Claim est envoyé à la main par claim(player).

AUTO_CLAIM = false
advance(1000)
startServer()
local paid = {}
DisplayService.OnCashOut(function(player, amount, source)
	if source == "Offline" then
		table.insert(paid, { player = player, amount = amount })
	end
end)
local function paidTo(player)
	local total, count = 0, 0
	for _, e in paid do
		if e.player == player then
			total += e.amount
			count += 1
		end
	end
	return total, count
end

section("O1. retour : le gain attend le Claim, rien n'est versé")
alignSecond()
local wall = wallNow()
local ada = join("Ada", newProfile(6, { LastSeenAt = wall - 600, Income = 50 }))
check(ada:GetAttribute("OfflinePending") == 30000, `attribut OfflinePending = 30 000 ({ada:GetAttribute("OfflinePending")})`)
check(dataOf(ada).Offline.Pending == 30000, "profil : Offline.Pending = 30 000")
check(OfflineService.GetPending(ada) == 30000, "GetPending = 30 000")
check(dataOf(ada).Cash == 1000 and #creditsOf(ada) == 0, "Cash inchangé (1 000 $), aucun versement")
check(dataOf(ada).Offline.LastSeenAt == wall, "LastSeenAt remis à maintenant en même temps")
check(logHas("[OfflineService] Ada absent 10 min 00 s, revenu $50/s × 1 : $30K, $30K en attente du Claim", "PRINT", "server"), "ligne dans la sortie")
advance(Offline.OpenDelay + 0.5)
check(#notifies(ada) == 0, "aucun Notify du serveur (l'écran UI_Offline s'en charge)")

section("O2. Claim : versé une fois, remis à 0")
claim(ada)
check(dataOf(ada).Cash == 31000, `Cash = 31 000 ({dataOf(ada).Cash})`)
check((dataOf(ada).Offline.Pending or 0) == 0 and ada:GetAttribute("OfflinePending") == 0, "Pending et attribut remis à 0")
local total, count = paidTo(ada)
check(count == 1 and total == 30000, `OnCashOut « Offline » une fois, 30 000 $ ({count} × {total})`)
check(ada:GetAttribute("CashCollected") == 30000, "CashCollected monte (le client voit l'encaissement)")
check(logHas("[OfflineService] Ada réclame ses gains hors ligne : $30K versés dans son argent", "PRINT", "server"), "ligne du Claim")

section("O3. double Claim refusé")
claim(ada) -- même seconde : le débit Net le laisse passer (2/s), le service ne trouve rien
advance(1.1)
claim(ada)
for _ = 1, 5 do
	fireAs(ada, "ClaimOffline") -- rafale : le débit en coupe une partie, le reste ne trouve rien
end
flush()
advance(1.1)
claim(ada)
check(dataOf(ada).Cash == 31000, `toujours 31 000 $ ({dataOf(ada).Cash})`)
total, count = paidTo(ada)
check(count == 1 and total == 30000 and #creditsOf(ada) == 1, `toujours un seul versement ({count}, {#creditsOf(ada)} appel(s) à AddOfflineEarnings)`)
check(OfflineService.Claim(ada) == 0, "OfflineService.Claim : 0 (rien en attente)")
fireAs(ada, "ClaimOffline", 999999)
flush()
check(dataOf(ada).Cash == 31000, "argument envoyé par le client : refusé par Net (aucun argument attendu), rien versé")
leave(ada)
check(SAVED["Player_1"].Cash == 31000 and (SAVED["Player_1"].Offline.Pending or 0) == 0, "sauvegardé : 31 000 $, rien en attente")
local tel = economyFor(ada, "Offline")
check(sumOf(tel) == 30000 and #economyFor(ada, "Income") == 0, `télémétrie : 30 000 $ en Offline ({sumOf(tel)})`)

section("O4. départ sans Claim : gardé dans le profil, versé une seule fois au retour suivant")
alignSecond()
local bea = join("Bea", newProfile(6, { LastSeenAt = wallNow() - 10 * 3600, Income = 10 }))
local first = Offline.MaxHours * 3600 * 10
check(bea:GetAttribute("OfflinePending") == first, `plafond de 4 h : {first} $ en attente`)
leave(bea)
local savedBea = SAVED["Player_2"]
check(savedBea.Offline.Pending == first and savedBea.Cash == 1000, "départ sans Claim : sauvegardé en attente, Cash inchangé")
check(#creditsOf(bea) == 0, "rien versé au départ")
savedBea.Offline.Income = 3 -- revenu relevé au départ (la boutique de Bea n'avait rien d'exposé dans ce banc)
alignSecond()
away(100)
alignSecond()
local back = join("Bea", nil, 2)
local again = back:GetAttribute("OfflinePending")
check(type(again) == "number" and again >= first + 300 and again <= first + 310, `retour : l'ancien montant + le nouveau gain ({again} $ ≈ {first} + 100 s × 3 $/s)`)
check(dataOf(back).Cash == 1000, "toujours rien versé avant le Claim")
claim(back)
check(dataOf(back).Cash == 1000 + again, `Claim : {again} $ versés en une fois`)
claim(back)
advance(1.1)
claim(back)
check(dataOf(back).Cash == 1000 + again and #creditsOf(back) == 1, "jamais deux fois")
leave(back)
check(SAVED["Player_2"].Cash == 1000 + again and SAVED["Player_2"].Offline.Pending == 0, "sauvegardé : versé, plus rien en attente")
SAVED["Player_2"].Offline.Income = 0 -- revenu relevé nul : ce retour-là ne rapporte rien
alignSecond()
local third = join("Bea", nil, 2)
check(third:GetAttribute("OfflinePending") == 0, "retour suivant tout de suite : rien en attente (pas d'écran)")
claim(third)
check(dataOf(third).Cash == 1000 + again, "Claim sans rien en attente : rien")
leave(third)

section("O5. nouveau joueur : rien en attente, aucun écran")
alignSecond()
local neo = join("Neo", nil)
check(neo:GetAttribute("OfflinePending") == 0, "attribut OfflinePending = 0 (OfflineController n'ouvre rien)")
check(dataOf(neo).Offline.Pending == nil and dataOf(neo).Offline.LastSeenAt == wallNow(), "profil neuf : pas de Pending, heure posée")
claim(neo)
check(dataOf(neo).Cash == 0 and #creditsOf(neo) == 0, "Claim d'un nouveau joueur : rien versé")
leave(neo)

section("O6. Pending illisible : remis à 0, sans gain")
for _, bad in { -5, 0 / 0, math.huge, "abc" } do
	alignSecond()
	local p = newProfile(6, { LastSeenAt = 0, Income = 0 })
	p.Offline.Pending = bad
	local cid = join("Cid", p)
	check(cid:GetAttribute("OfflinePending") == 0 and dataOf(cid).Offline.Pending == 0, `Pending = {tostring(bad)} : remis à 0`)
	claim(cid)
	check(dataOf(cid).Cash == 1000, `Pending = {tostring(bad)} : rien versé`)
	leave(cid)
end
check(logHas("Offline.Pending illisible", "WARN", "server"), "ligne orange")
alignSecond()
local q = newProfile(6, { LastSeenAt = 0, Income = 0 })
q.Offline.Pending = 1234.75
local dot = join("Dot", q)
check(dot:GetAttribute("OfflinePending") == 1234, "Pending à centimes : dollars entiers (1 234)")
claim(dot)
check(dataOf(dot).Cash == 2234, "Claim : 1 234 $")
leave(dot)

section("O7. session reprise par un autre serveur : le Claim ne verse rien, Pending gardé")
alignSecond()
local eve = join("Eve", newProfile(6, { LastSeenAt = wallNow() - 100, Income = 4 }))
check(eve:GetAttribute("OfflinePending") == 400, "400 $ en attente")
local key = `Player_{eve.UserId}`
local profile = SESSIONS[key]
profile:EndSession()
claim(eve)
check(profile.Data.Cash == 1000 and profile.Data.Offline.Pending == 400, "profil fermé : rien versé, Pending gardé (l'autre serveur le montrera)")
leave(eve)

section("O8. plantage après le retour : la sauvegarde garde le montant en attente")
alignSecond()
local fay = join("Fay", newProfile(6, { LastSeenAt = wallNow() - 200, Income = 5 }))
check(fay:GetAttribute("OfflinePending") == 1000, "1 000 $ en attente")
DataService.Save(fay)
advance(0.5)
local crash = deepCopy(SAVED[`Player_{fay.UserId}`])
check(crash.Offline.Pending == 1000 and crash.Offline.LastSeenAt == wallNow(), "sauvegarde : Pending et heure du retour ensemble")
claim(fay)
check(dataOf(fay).Cash == 2000, "Claim : versé")
leave(fay)
SAVED[`Player_{fay.UserId}`] = crash -- le serveur a planté avant de sauvegarder le Claim : seule l'autre sauvegarde reste
alignSecond()
local fay2 = join("Fay", nil, fay.UserId)
local pend = fay2:GetAttribute("OfflinePending")
check(pend >= 1000 and pend <= 1000 + 5 * 3, `rien perdu : les 1 000 $ sont de nouveau en attente (le versement est perdu avec lui), le temps compté une fois ({pend})`)
check(dataOf(fay2).Cash == 1000, "Cash de la sauvegarde : le Claim n'y était pas, il n'est pas payé deux fois")
claim(fay2)
check(dataOf(fay2).Cash == 1000 + pend, "versé une fois")
leave(fay2)

summary("scénario a64")
