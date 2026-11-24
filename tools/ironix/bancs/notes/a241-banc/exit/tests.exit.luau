--!nocheck
-- a241 (vague 72, L-219 point 2, Clément : « je casse la boutique, je rentre, je ressors : pas de poursuite ») :
-- Config/Chase.ChaseOnEmptyExit = true. Un intrus qui ressort SANS objet avant la fin du chrono est poursuivi tout
-- de suite (GuardService.ChaseIntruder, poursuite d'intrus) ; le reste ne change pas (chrono masqué, rideau baissé
-- pour lui, aucun second vigile à la fin du chrono ; casseur resté dehors : aucun vigile). Règle d'avant (false) :
-- banc a110, lancé par a241-banc/autres-bancs/a110 avec l'interrupteur à false.

startAll(true)
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(70, 3, 10))
local D = player("Dan", Vector3.new(75, 3, 10))
flush()
local Chase = sharedModule("Config/Chase")
check(Chase.ChaseOnEmptyExit == true, "N0 (banc) Chase.ChaseOnEmptyExit vaut true dans l'arbre")
local lucks = luckValues()
local LMIN, LMAX = lucks[1], lucks[#lucks]
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
local function timerShown(p, store)
	local endsAt = lastTimer(p, store)
	return endsAt ~= nil and endsAt > 0 and endsAt > Workspace:GetServerTimeNow()
end

section("N1 entrer puis sortir sans rien : le vigile sort pour elle")
breakStore(A, STORE_A)
local ends = chronoEnd(STORE_A)
local boxA = openBox(A, STORE_A, 1, LMAX)
advance(0.2)
check(isOpening(boxA) and insideStore(A), "N1 (banc) Alice est entrée et ouvre un colis")
local exitAt = now()
moveTo(A, Vector3.new(60, 3, 12))
advance(0.2)
local endsAt, sentAt = lastTimer(A)
check(endsAt == 0 and sentAt ~= nil and sentAt >= exitAt, "N1a sortie sans objet : chrono masqué tout de suite (HeistTimer 0)")
check(logCount("Alice sorti de " .. STORE_A.Name .. " sans objet : rideau baissé pour lui, le vigile sort pour lui", "PRINT", "server") == 1, "N1c sortie notée, le vigile sort pour elle")
check(logCount("Alice sorti de " .. STORE_A.Name .. " sans objet : rideau baissé pour lui, plus de chrono ni de vigile", "PRINT", "server") == 0, "N1d plus la règle d'avant")
check(guardFor(A) ~= nil and #guards() == 1, "N1e un vigile poursuit Alice, sorti tout de suite (avant la fin du chrono)")
check(now() < ends - 1, "N1 (banc) chrono pas fini (" .. math.round((ends - now()) * 10) / 10 .. " s)")
moveTo(A, Vector3.new(300, 3, 0)) -- elle court loin dans la rue
advance(ends - now() + 0.3)
check(logCount("fin du chrono, 0 vigile(s) sorti(s) pour 0 intrus dans le magasin", "PRINT", "server") == 1, "N1f fin du chrono : aucun second vigile pour elle (plus intruse)")
check(#guards() <= 1, "N1g jamais deux vigiles pour elle")
-- Règle a70 : rideau local levé tant que son vigile passe dans le magasin, puis baissé pour elle.
local waitedA = 0
while not closedFor(A) and waitedA < 8 do
	advance(0.1)
	waitedA += 0.1
end
check(closedFor(A), "N1b rideau baissé pour elle (ClosedStores), une fois son vigile hors du magasin")
local gone = false
for _ = 1, 120 do -- 30 s au plus : attrapée, ou abandon au bout de Balance.Guard.IntruderChaseTime
	advance(0.25)
	if guardFor(A) == nil or logCount("intrus sans objet", "PRINT", "server") > 0 or logCount("Alice attrapé", "PRINT", "server") > 0 then
		gone = true
		break
	end
end
check(gone, "N1h poursuite d'intrus sans objet : finie (abandon au bout de IntruderChaseTime, ou capture)")

section("N2 casseur resté dehors : aucun vigile")
breakStore(B, STORE_B)
local endsB = chronoEnd(STORE_B)
check(timerShown(B, STORE_B), "N2a Bob casse sans entrer : chrono affiché")
advance(endsB - now() + 0.3)
check(guardFor(B) == nil, "N2b aucun vigile pour lui (jamais entré)")

section("N3 sortir sans rien à côté d'un preneur : chacun son vigile")
local storeC = STORE_B
WindowS.Rebuild(storeC:FindFirstChild("Window"):GetAttribute("WindowId"))
for _ = 1, 160 do -- vitrine reconstruite et magasin rouvert (40 s au plus)
	advance(0.25)
	if storeC:FindFirstChild("Window"):GetAttribute("Broken") ~= true and storeC:GetAttribute("HeistOpen") ~= true then
		break
	end
end
breakStore(C, storeC)
standAt(D, storeC, 8)
advance(0.2)
check(insideStore(D) or rootOf(D).Position.Z < -32, "N3 (banc) Dan est entré")
local itemC = openAndReveal(C, storeC, 2, LMIN, { 1 })
check(itemC ~= nil and takeItem(C, storeC, 2), "N3 (banc) Chloé prend son objet")
advance(0.1)
check(guardFor(C) ~= nil, "N3a vigile de la prise pour Chloé (règle a114, inchangée)")
local pD = rootOf(D).Position
moveTo(D, Vector3.new(pD.X, 3, if pD.Z > 0 then 12 else -12))
advance(0.3)
check(guardFor(D) ~= nil, "N3b Dan ressort sans rien : son vigile sort aussi")
check(guardFor(C) ~= guardFor(D), "N3c deux vigiles distincts")
check(logCount("tick :", "WARN", "server") == 0, "N4 aucune erreur du tick")
check(logCount("ChaseIntruder", "WARN", "server") == 0, "N5 aucune erreur de ChaseIntruder")

summary("scénario exit a241")
