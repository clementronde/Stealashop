--!nocheck
-- a157 (Cantin, 2026-11-14) : en zone safe (faux monde : x < 25), plus de chrono HEIST ni de vigile de fin de
-- chrono pour ce joueur ; vigile en attente de départ qui abandonne si sa cible est déjà à l'abri.

startAll(true)
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(20, 3, -10)) -- à l'abri, près du magasin B
local D = player("Dan", Vector3.new(40, 3, -10)) -- dehors, près du magasin B
flush()
local lucks = luckValues()
local LMIN = lucks[1]
local function chronoEnd(store)
	return store:GetAttribute("HeistEndsAt") - SERVER_TIME_OFFSET
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
local function shownSince(p, since, store)
	return #remotes("HeistTimer", function(e)
		return e.to == p and e.args[1] == (store or STORE_A).Name and e.t >= since and e.args[2] > 0
	end)
end
local function chaseStates(p, active, since)
	return #remotes("ChaseState", function(e)
		return e.to == p and e.args[1] == active and e.t >= since
	end)
end

section("S1 objet en main, arrivée en zone safe pendant le chrono HEIST")
breakStore(B, STORE_A)
local ends = chronoEnd(STORE_A)
check(timerShown(B), "S1 (banc) chrono du casseur affiché")
local item = openAndReveal(B, STORE_A, 2, LMIN, { 1 })
check(item ~= nil and takeItem(B, STORE_A, 2), "S1 (banc) Bob prend son objet")
check(now() < ends - 0.5, "S1 (banc) chrono pas fini")
local t0 = now()
moveTo(B, Vector3.new(0, 3, 0)) -- tout de suite à l'abri : son vigile est encore en attente de départ
advance(0.2)
local endsAt, sentAt = lastTimer(B)
check(endsAt == 0 and sentAt ~= nil and sentAt >= t0, "S1a à l'abri : chrono HEIST masqué tout de suite")
check(logCount("Bob en zone safe : plus de chrono ni de vigile pour " .. STORE_A.Name, "PRINT", "server") == 1, "S1b trace dans la sortie")
advance(0.6)
check(logCount("abandonne Bob (zone safe, avant le départ)", "PRINT", "server") == 1, "S1c son vigile abandonne avant même de partir")
check(chaseStates(B, false, t0) >= 1, "S1d ChaseState(false) pour lui")
advance(ends - now() + 0.5)
check(shownSince(B, t0 + 0.1) == 0 and not timerShown(B), "S1e jusqu'à la fin du chrono : aucun chrono renvoyé")
check(guardFor(B) == nil, "S1f aucun vigile ne le poursuit")

section("S2 joueur à l'abri près d'un magasin cassé")
breakStore(A, STORE_B)
advance(0.3)
check(timerShown(D, STORE_B), "S2a Dan, dehors près du magasin : chrono affiché (règle d'avant)")
check(shownSince(C, 0, STORE_B) == 0, "S2b Chloé, à l'abri à la même distance : aucun chrono")
check(logCount("tick :", "WARN", "server") == 0, "S3 aucune erreur du tick")

summary("scénario safe")
