--!nocheck
-- Scénario « security » (DEV-102) : heure de départ dans le futur, horloge qui recule, revenu illisible,
-- retour immédiat, plantage après le retour (2e chargement), session reprise par un autre serveur, aucun
-- remote, crochet de Studio OfflineTest.
-- Copie d'a64 (2026-11-11, L-092 3f) : un seul remote, ClaimOffline ; le crochet met en attente, claim(player) verse.

advance(1000)
startServer()

section("heure de départ dans le futur")
alignSecond()
local wall = wallNow()
local ada = join("Ada", newProfile(6, { LastSeenAt = wall + 500, Income = 50 }))
check(#creditsOf(ada) == 0 and DisplayService.GetRegister(ada) == 0, "aucun gain")
check(dataOf(ada).Offline.LastSeenAt == wall, "l'heure repart de maintenant")
check(logHas("[OfflineService] Ada : heure de départ dans le futur (500 s d'avance) : aucun gain hors ligne", "WARN", "server"), "ligne orange")
leave(ada)

section("horloge qui recule")
local p = newProfile(6)
addItem(p, "a", "Z1_Donut", 1, 1, 500)
alignSecond()
local bea = join("Bea", p)
advance(Offline.SnapshotInterval + 1)
leave(bea)
local savedAt = SAVED["Player_2"].Offline.LastSeenAt
check(savedAt == wallNow() and SAVED["Player_2"].Offline.Income > 0, "départ sauvegardé avec l'heure et le revenu")
away(-3600)
alignSecond()
local back = join("Bea", nil, 2)
check(#creditsOf(back) == 0, "horloge reculée d'1 h : aucun gain")
check(dataOf(back).Offline.LastSeenAt == wallNow() and dataOf(back).Offline.LastSeenAt < savedAt, "l'heure repart de la nouvelle heure")
leave(back)
away(3600)

section("revenu illisible dans un profil v6")
for _, bad in { -5, 0 / 0, math.huge } do
	alignSecond()
	local cid = join("Cid", newProfile(6, { LastSeenAt = wallNow() - 100, Income = bad }))
	check(#creditsOf(cid) == 0, `Income = {tostring(bad)} : aucun gain`)
	leave(cid)
end
check(OfflineService.ComputeEarnings(0, 100, 5) == 0, "ComputeEarnings : heure inconnue (0) → 0")
check(OfflineService.ComputeEarnings(100, 100, 5) == 0, "ComputeEarnings : absence nulle → 0")
local g, s = OfflineService.ComputeEarnings(100, 160, 5)
check(g == 300 and s == 60, "ComputeEarnings : 60 s × 5 $/s = 300 $")
local g2, s2 = OfflineService.ComputeEarnings(1, 1 + 10 * 3600, 1)
check(s2 == Offline.MaxHours * 3600 and g2 == Offline.MaxHours * 3600, "ComputeEarnings : bornée à MaxHours")

section("retour immédiat : rien de plus qu'en restant")
local d = newProfile(6)
addItem(d, "x", "Z1_Donut", 1, 1, 500)
alignSecond()
local dan = join("Dan", d)
advance(Offline.SnapshotInterval + 1)
local income = OfflineService.GetIncome(dan)
leave(dan)
local again = join("Dan", nil, dan.UserId)
local quick = creditsOf(again)
check(#quick == 0 or quick[1].amount <= income + 1e-6, `revenu dans la même seconde : au plus 1 s de revenu ({quick[1] and quick[1].amount or 0} $)`)

section("plantage après le retour : la sauvegarde automatique a déjà l'heure du retour")
leave(again)
alignSecond()
away(500)
local eve = join("Dan", nil, dan.UserId)
local paid = creditsOf(eve)
check(#paid == 1 and paid[1].amount > 0, `retour après 500 s : payé ({paid[1] and paid[1].amount} $)`)
local loadWall = wallNow()
DataService.Save(eve)
advance(0.5)
local crash = deepCopy(SAVED[`Player_{dan.UserId}`])
check(crash.Offline.LastSeenAt == loadWall, "sauvegarde après le retour : LastSeenAt = heure du retour")
leave(eve)
SAVED[`Player_{dan.UserId}`] = crash -- le serveur a planté : seule la sauvegarde automatique reste
local before = #OFFLINE_CREDITS
alignSecond()
local after = join("Dan", nil, dan.UserId)
local second = creditsOf(after)
local lastPaid = second[#second]
check(#OFFLINE_CREDITS == before or (lastPaid and lastPaid.amount <= (wallNow() - loadWall) * income + 1e-6), "2e chargement : seul le temps depuis la sauvegarde compte, pas les 500 s une 2e fois")
leave(after)

section("session reprise par un autre serveur : ce serveur n'écrit plus rien")
alignSecond()
local fay = join("Fay", nil)
local key = `Player_{fay.UserId}`
local profile = SESSIONS[key]
profile:EndSession() -- comme une session reprise : DataService.Get renvoie nil
local frozen = SAVED[key].Offline.LastSeenAt
away(60)
advance(Offline.SnapshotInterval * 2)
check(DataService.Get(fay) == nil and profile.Data.Offline.LastSeenAt == frozen and SAVED[key].Offline.LastSeenAt == frozen, "aucun relevé après la fin de session")
leave(fay)

section("un seul remote : ClaimOffline, sans argument (copie a64)")
local defs = sharedModule("Net/Definitions")
local found, seen = {}, 0
for _, def in defs.List do
	seen += 1
	if type(def) == "table" and type(def.Name) == "string" and string.find(string.lower(def.Name), "offline", 1, true) then
		table.insert(found, def)
	end
end
check(seen > 10 and #found == 1 and found[1].Name == "ClaimOffline" and found[1].Direction == "ClientToServer" and #found[1].Args == 0, `un seul remote des gains hors ligne parmi les {seen} : ClaimOffline, client → serveur, sans argument`)

section("crochet de Studio OfflineTest")
local g = newProfile(6)
addItem(g, "y", "Z1_Banane", 1, 1, 500)
local gus = join("Gus", g)
advance(1.5)
local inc = OfflineService.GetIncome(gus)
Workspace:SetAttribute("OfflineTest", "Gus 120")
flush()
check(#creditsOf(gus) == 0 and gus:GetAttribute("OfflinePending") == math.floor(120 * inc), `« Gus 120 » : {math.floor(120 * inc)} $ en attente du Claim, rien versé encore`)
check(Workspace:GetAttribute("OfflineTest") == nil, "attribut remis à nil")
check(logHas("[OfflineService] Gus test : absence simulée 2 min 00 s", "PRINT", "server"), "ligne de test dans la sortie")
claim(gus)
local tests = creditsOf(gus)
check(#tests == 1 and tests[1].amount == math.floor(120 * inc), `Claim : 120 s × {inc} $/s versés ({tests[1] and tests[1].amount})`)
advance(Offline.OpenDelay + 0.1)
check(#notifies(gus, "while you were away") == 0, "aucun message du serveur, comme un vrai retour")
Workspace:SetAttribute("OfflineTest", "Gus 99999")
flush()
claim(gus)
check(creditsOf(gus)[2] and creditsOf(gus)[2].amount == math.floor(Offline.MaxHours * 3600 * inc), "absence simulée bornée au plafond")
Workspace:SetAttribute("OfflineTest", "Gus abc")
flush()
Workspace:SetAttribute("OfflineTest", "Personne 10")
flush()
claim(gus)
check(#creditsOf(gus) == 2 and logCount("[OfflineService] test : « ", "WARN", "server") == 2, "valeurs refusées : rien en attente, rien versé, ligne orange")
stepOnPad(gus)
leave(gus)
check(sumOf(economyFor(gus, "Offline")) == math.floor(120 * inc) + math.floor(Offline.MaxHours * 3600 * inc), "télémétrie Offline pour l'absence simulée")

summary("scénario security")
