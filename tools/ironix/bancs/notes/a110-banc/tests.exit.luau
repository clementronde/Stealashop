--!nocheck
-- E. Sortir du magasin sans rien (Cantin, 2026-11-13 ; Features.ShelfOpen = true, sans WitnessService) :
-- entré puis sorti sans objet avant la fin du chrono, c'est fini pour ce joueur : son chrono disparaît tout de
-- suite, aucun vigile ne sort pour lui, le rideau reste baissé chez lui jusqu'à la réouverture. Sorti en
-- portant un objet, ou encore dedans à la fin du chrono : un vigile (règle d'avant). Casseur resté dehors :
-- chrono jusqu'à la fin, sans vigile.

startAll(true)
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(70, 3, 10))
local D = player("Dan", Vector3.new(75, 3, 10))
flush()
local lucks = luckValues()
local LMIN, LMAX = lucks[1], lucks[#lucks]
local shutter = STORE_A:FindFirstChild("Shutter")
local shutterOpenY = shutter.Position.Y
local function shutterDown()
	return shutter.Position.Y < shutterOpenY - 5
end
local function insideStore(p)
	return rootOf(p).Position.Z > 32
end
local function chronoEnd(store)
	return store:GetAttribute("HeistEndsAt") - SERVER_TIME_OFFSET
end
local function closedFor(p, store)
	local closed = p:GetAttribute("ClosedStores")
	return type(closed) == "string" and string.find(closed, (store or STORE_A).Name, 1, true) ~= nil
end
-- Dernier HeistTimer envoyé à `p` pour ce magasin : endsAt (0 = masqué) et heure d'envoi ; nil sans envoi.
local function lastTimer(p, store)
	local list = remotes("HeistTimer", function(e)
		return e.to == p and e.args[1] == (store or STORE_A).Name
	end)
	local e = list[#list]
	if e == nil then
		return nil, nil
	end
	return e.args[2], e.t
end
-- Chrono affiché chez `p` (le client l'efface aussi de lui-même à son heure de fin).
local function timerShown(p, store)
	local endsAt = lastTimer(p, store)
	return endsAt ~= nil and endsAt > 0 and endsAt > Workspace:GetServerTimeNow()
end
local function shownSince(p, since, store)
	return #remotes("HeistTimer", function(e)
		return e.to == p and e.args[1] == (store or STORE_A).Name and e.t >= since and e.args[2] > 0
	end)
end
local function rebuild(store)
	WindowS.Rebuild(store:FindFirstChild("Window"):GetAttribute("WindowId"))
	flush()
end

section("E1 entrer puis sortir sans rien (seul)")
breakStore(A, STORE_A)
local ends = chronoEnd(STORE_A)
check(timerShown(A), "E1 (banc) chrono du casseur affiché")
local boxA = openBox(A, STORE_A, 1, LMAX) -- ouverture lancée, il part sans attendre l'objet
advance(0.2)
check(isOpening(boxA) and insideStore(A), "E1 (banc) Alice est entrée et ouvre un colis")
check(logCount("Alice entre dans " .. STORE_A.Name, "PRINT", "server") == 1, "E1 (banc) comptée comme intruse en entrant")
local exitAt = now()
moveTo(A, Vector3.new(60, 3, 12))
advance(0.2)
local endsAt, sentAt = lastTimer(A)
check(endsAt == 0 and sentAt ~= nil and sentAt >= exitAt, "E1a sortie sans objet : chrono masqué tout de suite (HeistTimer 0)")
check(not timerShown(A), "E1b plus de chrono affiché")
check(closedFor(A), "E1c rideau baissé pour elle (ClosedStores)")
check(logCount("Alice sorti de " .. STORE_A.Name .. " sans objet", "PRINT", "server") == 1, "E1d sortie notée « sans objet »")
standAt(A, STORE_A, 5)
advance(0.3)
check(not insideStore(A), "E1e elle revient : ressortie devant la vitrine")
moveTo(A, Vector3.new(60, 3, 12))
local alwaysClosed, noTimer = true, true
while now() < ends + 0.3 do
	advance(0.25)
	alwaysClosed = alwaysClosed and closedFor(A)
end
check(#guards() == 0 and guardFor(A) == nil, "E1f fin du chrono : aucun vigile ne sort pour elle")
for _ = 1, 60 do -- 15 s : ouverture finie, réservation passée, magasin fermé, rideau tombé (vitrine reconstruite 20 s après la fermeture)
	advance(0.25)
	alwaysClosed = alwaysClosed and closedFor(A)
	noTimer = noTimer and not timerShown(A)
end
check(alwaysClosed, "E1g rideau local jamais relevé chez elle, ni à la fin du chrono ni après, jusqu'à la réouverture")
check(noTimer and shownSince(A, exitAt + 0.1) == 0, "E1h aucun chrono renvoyé après sa sortie")
check(#guards() == 0, "E1i toujours aucun vigile")
check(STORE_A:GetAttribute("HeistOpen") == false and shutterDown(), "E1j magasin fermé, vrai rideau tombé")
advance(10) -- WindowService reconstruit la vitrine RebuildDelay s après la fermeture
flush()
check(STORE_A:FindFirstChild("Window"):GetAttribute("Broken") ~= true and not closedFor(A), "E1k réouverture (vitrine reconstruite) : plus fermé pour elle")

section("E2 sortir avec un objet, rester dedans, sortir sans rien (à plusieurs)")
breakStore(B, STORE_A)
ends = chronoEnd(STORE_A)
standAt(C, STORE_A, 6)
standAt(D, STORE_A, 8)
local itemB = openAndReveal(B, STORE_A, 2, LMIN, { 1 })
check(itemB ~= nil, "E2 (banc) l'objet de Bob est sorti")
check(takeItem(B, STORE_A, 2), "E2 (banc) Bob prend son objet")
check(now() < ends - 2, "E2 (banc) chrono pas fini (" .. math.round((ends - now()) * 10) / 10 .. " s)")
local exitB = now()
moveTo(B, Vector3.new(65, 3, 12))
moveTo(D, Vector3.new(75, 3, 12))
advance(0.2)
check(timerShown(B) and shownSince(B, 0) > 0 and select(1, lastTimer(B)) > 0, "E2a Bob sorti avec un objet : il garde son chrono")
check(logCount("Bob sorti de " .. STORE_A.Name .. " : rideau baissé pour lui", "PRINT", "server") == 1, "E2b Bob : rideau baissé pour lui (règle d'avant)")
local endsD, sentD = lastTimer(D)
check(endsD == 0 and sentD ~= nil and sentD >= exitB, "E2c Dan sorti sans rien : chrono masqué tout de suite")
check(closedFor(D), "E2d Dan : rideau baissé pour lui")
check(timerShown(C) and insideStore(C), "E2e Chloé, restée dedans, garde son chrono")
advance(ends - now() + 0.3)
check(guardFor(B) ~= nil, "E2f fin du chrono : un vigile sort pour Bob (sorti avec un objet)")
check(guardFor(C) ~= nil, "E2g un vigile sort pour Chloé (encore dedans)")
check(guardFor(D) == nil and #guards() == 2, "E2h aucun vigile pour Dan (sorti sans rien)")
check(not timerShown(B) and not timerShown(C) and not timerShown(D), "E2i plus aucun chrono")
-- Choix d'a110 : la règle a70 reste (rideau local levé tant qu'un vigile, sorti pour un AUTRE intrus, est dans le
-- magasin) ; l'entrée reste refusée.
standAt(D, STORE_A, 9)
advance(0.3)
check(not insideStore(D), "E2j Dan revient pendant le passage des vigiles : entrée refusée")
moveTo(D, Vector3.new(75, 3, 12))

section("E3 encore dedans à la fin du chrono, puis sortie sans rien")
moveTo(C, Vector3.new(70, 3, 12))
advance(0.2)
check(not insideStore(C) and guardFor(C) ~= nil, "E3a Chloé sort sans rien après le chrono : son vigile la poursuit toujours")
check(logCount("Chloe sorti de " .. STORE_A.Name .. " sans objet", "PRINT", "server") == 0, "E3b pas de sortie « sans objet » après le chrono (règle d'avant)")
check(logCount("Chloe sorti de " .. STORE_A.Name .. " : rideau baissé pour lui", "PRINT", "server") == 1, "E3c rideau baissé pour elle")

section("E4 casseur resté dehors")
breakStore(A, STORE_B)
local endsB = chronoEnd(STORE_B)
check(timerShown(A, STORE_B), "E4a Alice casse sans entrer : chrono affiché")
advance(endsB - now() - 0.5)
check(timerShown(A, STORE_B), "E4b chrono affiché jusqu'à la fin (temps pour entrer)")
advance(0.8)
local endsA4, sentA4 = lastTimer(A, STORE_B)
check(endsA4 == 0 and sentA4 ~= nil and sentA4 >= endsB - 0.2, "E4c fin du chrono : chrono masqué")
check(guardFor(A) == nil, "E4d aucun vigile pour elle (jamais entrée)")
check(logCount("tick :", "WARN", "server") == 0, "E5 aucune erreur du tick")

summary("scénario exit")
