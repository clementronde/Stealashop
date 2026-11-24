--!nocheck
-- a192 (vague 59, L-184 point 1) : remote CatchScene de GuardService, au coup du vigile.
-- Mise en place du banc a174 (a66-banc/autres-bancs/a30-banc, a114-banc/autres-bancs/a103-banc/head.luau), sans témoins.
--   S1 capture dans la rue : CatchScene(false, "Drop", 0, ItemId) envoyé au seul joueur attrapé, une fois, au coup ;
--   S2 capture dans le magasin de l'objet : "Shelf" ;
--   S3 joueur parti avant le coup : rien envoyé, aucune erreur ; règles inchangées (étourdissement, Notify).
startAll(true)
local Guard = serverModule("GuardService")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
flush()
local LMIN = luckValues()[1]
local STREET = Vector3.new(65, 3, 12)

local function waitFor(fn, maxSeconds)
	local t = 0
	while not fn() and t < maxSeconds do
		advance(0.05)
		t += 0.05
	end
	return fn()
end
local function scenes(p)
	return remotes("CatchScene", function(e)
		return p == nil or e.to == p
	end)
end
local function knockTime(p)
	local seen = nil
	waitFor(function()
		local root = rootOf(p)
		if seen == nil and root and root:FindFirstChild("GuardKnockback") then
			seen = now()
		end
		return seen ~= nil
	end, 10)
	return seen
end

section("S1 capture dans la rue")
reopen(A, STORE_A)
check(openAndReveal(A, STORE_A, 1, LMIN, { 1 }) ~= nil and takeItem(A, STORE_A, 1), "S1 (banc) Alice prend l'objet du rayon 1")
local payload = Carry.GetPayload(A)
advance(0.1)
moveTo(A, STREET)
local caughtAt = nil
check(waitFor(function()
	if not Carry.IsCarrying(A) then
		caughtAt = caughtAt or now()
	end
	return caughtAt ~= nil
end, 30), "S1 (banc) Alice attrapée dans la rue")
local before = #scenes(A)
local knock = knockTime(A)
flush()
local list = scenes(A)
check(#list >= 1, `S1a CatchScene envoyé à Alice ({#list})`)
local e = list[1]
check(e and e.args[1] == false and e.args[2] == "Drop" and e.args[3] == 0, `S1b jour, objet tombé, pas de renvoi ({e and e.args[1]}, {e and e.args[2]}, {e and e.args[3]})`)
check(e and e.args[4] == payload.ItemId, `S1c ItemId de l'objet porté ({e and e.args[4]} / {payload.ItemId})`)
check(knock ~= nil and e and math.abs(e.t - knock) <= 0.06, `S1d envoyé au coup (poussée à {knock}, remote à {e and e.t})`)
advance(Balance.Guard.CatchStunDuration + 0.5)
check(#scenes(A) == 1 and #scenes(B) == 0, "S1e une seule fois, et à Alice seulement")
check(#notifies("Caught", A) >= 1, "S1f le message « Caught! » part toujours (règle inchangée)")

section("S2 capture dans le magasin de l'objet")
check(waitFor(function()
	return #guards() == 0
end, 60), "S2 (banc) plus de vigile")
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
reopen(A, STORE_A)
check(openAndReveal(A, STORE_A, 3, LMIN, { 1 }) ~= nil and takeItem(A, STORE_A, 3), "S2 (banc) Alice prend l'objet du rayon 3")
local payload2 = Carry.GetPayload(A)
advance(0.1)
standAt(A, STORE_A, 3)
check(waitFor(function()
	return not Carry.IsCarrying(A)
end, 30), "S2 (banc) attrapée dans le magasin")
knockTime(A)
flush()
local list2 = scenes(A)
local e2 = list2[#list2]
check(#list2 == 2 and e2.args[2] == "Shelf" and e2.args[4] == payload2.ItemId, `S2a CatchScene « Shelf » avec l'objet ({e2 and e2.args[2]})`)
advance(Balance.Guard.CatchStunDuration + 0.5)

section("S3 joueur parti avant le coup")
check(waitFor(function()
	return #guards() == 0
end, 60), "S3 (banc) plus de vigile")
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
reopen(B, STORE_A)
check(openAndReveal(B, STORE_A, 2, LMIN, { 1 }) ~= nil and takeItem(B, STORE_A, 2), "S3 (banc) Bob prend l'objet du rayon 2")
advance(0.1)
moveTo(B, STREET)
local gone = waitFor(function()
	return not Carry.IsCarrying(B)
end, 30)
check(gone, "S3 (banc) Bob attrapé")
leave(B)
advance(3)
check(#scenes(B) <= 1, `S3a au plus un envoi à Bob ({#scenes(B)})`)

check(logCount("CatchScene vers", "WARN", "server") == 0, "S8 aucun envoi raté")
check(logCount("[Net] envoi de CatchScene mal formé", "WARN", "server") == 0, "S9 arguments conformes à Net/Definitions")
check(logCount("tick :", "WARN", "server") == 0, "S10 aucune erreur du tick")
summary("scénario server")
