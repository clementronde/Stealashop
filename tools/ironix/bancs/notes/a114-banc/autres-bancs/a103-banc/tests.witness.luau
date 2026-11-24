--!nocheck
-- W. Témoins et police (WitnessService, L-111) : Raise au lancement de chaque ouverture, Calm seulement
-- quand la dernière ouverture du magasin est finie, ouverture refusée pendant l'appel (Notify), police
-- appelée pendant la montée (OnCall) : ShelfRevealAt avancé à maintenant, sortie immédiate, chance atteinte.

startAll()
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(70, 3, 10))
flush()
local lucks = luckValues()
local LMIN, LMAX = lucks[1], lucks[#lucks]
local LBIG = lucks[#lucks - 2]
local MESSAGE = "Witnesses are calling the police!"
local function calmsFor(store)
	local n = 0
	for _, e in Witness.calmed do
		if e.store == store then
			n += 1
		end
	end
	return n
end

section("W1 Raise au lancement, Calm à la dernière ouverture du magasin")
breakStore(A, STORE_A)
advance(1.1)
local calm0 = calmsFor(STORE_A) -- WindowService ou d'autres peuvent avoir calmé avant
local boxA = openBox(A, STORE_A, 1, LBIG)
check(isOpening(boxA), "W1 (banc) Alice ouvre à ×" .. LBIG)
check(#Witness.raised == 0, "W1a plus de Raise au lancement (L-118 : les témoins ont fui à la casse)")
advance(0.5)
local boxB = openBox(B, STORE_A, 2, LMIN)
check(isOpening(boxB), "W1 (banc) Bob ouvre à ×" .. LMIN)
check(#Witness.raised == 0, "W1b toujours aucun Raise")
advance(SOS.revealDelay(LMIN) + 0.1)
check(itemAt(STORE_A, 2) ~= nil and isOpening(boxA), "W1 (banc) l'objet de Bob est sorti, Alice ouvre encore")
check(calmsFor(STORE_A) == calm0, "W1c pas de Calm tant qu'une autre ouverture est en cours dans le magasin")
advance(boxA:GetAttribute("ShelfRevealAt") - Workspace:GetServerTimeNow() + 0.1)
check(itemAt(STORE_A, 1) ~= nil, "W1 (banc) l'objet d'Alice est sorti")
check(calmsFor(STORE_A) == calm0 + 1, "W1d Calm une fois, à la sortie du dernier objet")
check(calmsFor(STORE_B) == 0, "W1e l'autre magasin n'est pas concerné")

section("W2 ouverture refusée pendant l'appel")
advance(20)
-- L-118 : le magasin reste ouvert tant que des joueurs y sont : vitrine neuve.
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
reopen(A, STORE_A)
advance(1.1) -- fin de l'avance du casseur : Chloé peut ouvrir
Witness.calling[STORE_A] = true
local raised = #Witness.raised
local since = now()
local box3 = openBox(C, STORE_A, 3, LMIN)
check(not isOpening(box3) and #Witness.raised == raised, "W2a un témoin appelle la police : pas d'ouverture")
local sent = notifiesSince(MESSAGE, since, C)
check(#sent == 1 and sent[1].args[2] == "Warning", "W2b Notify « " .. MESSAGE .. " » (Warning)")
openBox(C, STORE_A, 3, LMIN)
check(#notifiesSince(MESSAGE, since, C) == 1, "W2c pas un second message dans la même seconde")
advance(1.05)
openBox(C, STORE_A, 3, LMIN)
check(#notifiesSince(MESSAGE, since, C) == 2 and not isOpening(box3), "W2d un nouveau message une seconde plus tard, toujours refusé")
check(#notifiesSince(MESSAGE, since, A) == 0, "W2e seulement au joueur refusé")
-- Hors de portée pendant l'appel : refus ordinaire, sans message.
advance(1.1)
since = now()
standAt(C, STORE_A, 10)
fireOpen(C, box3:GetAttribute("SlotId"))
check(#notifiesSince(MESSAGE, since) == 0, "W2f refus pour une autre raison (trop loin) : pas de message")
Witness.calling[STORE_A] = false
advance(1.05)
box3 = openBox(C, STORE_A, 3, LMIN)
check(isOpening(box3), "W2g appel fini : l'ouverture repart")

section("W3 police appelée pendant la montée")
advance(20)
-- L-118 : le magasin reste ouvert tant que des joueurs y sont : vitrine neuve.
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
reopen(A, STORE_A)
local box4 = openBox(A, STORE_A, 4, LMAX)
local box5 = openBox(A, STORE_A, 5, LBIG)
check(isOpening(box4) and isOpening(box5), "W3 (banc) deux ouvertures en cours (×" .. LMAX .. " et ×" .. LBIG .. ")")
local openAt4, openAt5 = box4:GetAttribute("ShelfOpenAt"), box5:GetAttribute("ShelfOpenAt")
local advanced = {}
for _, b in { box4, box5 } do
	b:GetAttributeChangedSignal("ShelfRevealAt"):Connect(function()
		advanced[b] = b:GetAttribute("ShelfRevealAt")
	end)
end
advance(1) -- L-118 point 4 : montée de 2 s au plus
local calmBefore = calmsFor(STORE_A)
Witness._call(STORE_B, A)
flush()
check(isOpening(box4) and isOpening(box5), "W3a police appelée pour un autre magasin : rien ne change")
local callAt = Workspace:GetServerTimeNow()
Witness._call(STORE_A, A)
flush()
local item4, item5 = itemAt(STORE_A, 4), itemAt(STORE_A, 5)
check(item4 ~= nil and item5 ~= nil and boxAt(STORE_A, 4) == nil and boxAt(STORE_A, 5) == nil, "W3b les deux objets sortent tout de suite")
check(advanced[box4] ~= nil and near(advanced[box4], callAt, 1e-6) and near(advanced[box5] or 0, callAt, 1e-6), "W3c ShelfRevealAt avancé à maintenant sur les deux colis")
local reached4 = SOS.luckAt(openAt4, LMAX, callAt)
local reached5 = SOS.luckAt(openAt5, LBIG, callAt)
check(reached4 > 1 and reached4 < LMAX, "W3 (banc) chance atteinte entre ×1 et ×" .. LMAX .. " : ×" .. reached4)
check(item4 ~= nil and near(item4:GetAttribute("ShelfLuck"), reached4, 1e-9), "W3d la chance s'arrête là où elle en était (×" .. tostring(item4 and item4:GetAttribute("ShelfLuck")) .. ")")
check(item5 ~= nil and near(item5:GetAttribute("ShelfLuck"), reached5, 1e-9), "W3e pareil pour la seconde ouverture")
check(item4 ~= nil and near(item4:GetAttribute("ShelfReservedUntil"), callAt + SO.ReserveTime, 0.01), "W3f réservation comptée depuis cette sortie")
check(calmsFor(STORE_A) == calmBefore + 1, "W3g Calm une fois, les deux ouvertures finies")
advance(SOS.revealDelay(LMAX))
check(itemAt(STORE_A, 4) == item4 and itemAt(STORE_A, 5) == item5, "W3h à l'heure prévue au départ : rien de plus ne sort")
advance(20)
-- L-118 : le magasin reste ouvert tant que des joueurs y sont : vitrine neuve.
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
reopen(A, STORE_A)
check(takeItem(A, STORE_A, 4), "W3j l'objet sorti plus tôt se prend au braquage suivant")
check(near(Carry.GetPayload(A).Luck, reached4, 1e-9), "W3k payload : la chance atteinte")
Carry.Consume(A)
flush()

section("W4 police pendant les rabats")
advance(12)
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
reopen(A, STORE_A)
local box6 = openBox(A, STORE_A, 6, LMAX)
advance(SO.FlapsTime / 2)
Witness._call(STORE_A, A)
flush()
local item6 = itemAt(STORE_A, 6)
check(item6 ~= nil and item6:GetAttribute("ShelfLuck") == 1, "W4a pendant les rabats : l'objet sort à ×1")
check(logCount("tick :", "WARN", "server") == 0 and logCount("WitnessService", "WARN", "server") == 0, "W5 aucune erreur")

summary("scénario witness")
