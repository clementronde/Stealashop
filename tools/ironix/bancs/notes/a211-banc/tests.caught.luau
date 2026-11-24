--!nocheck
-- a211 : un joueur attrapé dans un magasin n'en est plus l'intrus (bug vu en Play le 16/11 : deux « Caught! »).
startAll(true)
local Guard = serverModule("GuardService")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(66, 3, 10))
flush()
local LMIN = luckValues()[1]
local catches = {}
Guard.OnCatch(function(p)
	table.insert(catches, { p = p, t = now() })
end)
local function catchesOf(p)
	local n = 0
	for _, c in catches do
		if c.p == p then
			n += 1
		end
	end
	return n
end
local function chronoEndsAt(p)
	local list = remotes("HeistTimer", function(e)
		return e.to == p and e.args[2] > 0
	end)
	return if #list > 0 then list[#list].args[2] else nil
end
local function insideStore(p, store)
	local b = store:FindFirstChild("Bounds")
	local r = rootOf(p)
	if b == nil or r == nil then
		return false
	end
	local o = b.CFrame:PointToObjectSpace(r.Position)
	return math.abs(o.X) <= b.Size.X / 2 and math.abs(o.Y) <= b.Size.Y / 2 and math.abs(o.Z) <= b.Size.Z / 2
end

section("C1 attrapé dans le magasin, fin du chrono pendant son coup : une seule capture ; Bob, autre intrus, poursuivi")
reopen(A, STORE_A)
local endsAt = chronoEndsAt(A)
check(endsAt ~= nil, "C1 (banc) chrono d'Alice reçu")
-- Bob entre aussi, loin de la réserve, sans rien prendre.
moveTo(B, Vector3.new(55, 3, 36))
local _, ev = startReveal(A, STORE_A, 10, LMIN) -- rayon 10 : à côté de la porte de la réserve (GuardSpawn)
check(ev ~= nil, "C1 (banc) cinématique lancée")
local serverNow = function()
	return now() + SERVER_TIME_OFFSET
end
local lead = 2
if endsAt then
	advance(math.max(endsAt - serverNow() - lead, 0))
end
revealDone(A, ev and ev.args[10])
check(Carry.IsCarrying(A), "C1 (banc) objet porté à la fin de la cinématique")
check(waitFor(function()
	return catchesOf(A) >= 1
end, lead - 0.1), "C1 (banc) Alice attrapée avant la fin du chrono")
local caughtAt = now()
check(insideStore(A, STORE_A), "C1 (banc) Alice encore dans le magasin, étourdie")
local caughtNotes = #notifies("Caught", A)
-- Fin du chrono (Alice toujours dedans : sortie seulement après le coup, CatchStunDuration s), puis 8 s de plus.
if endsAt then
	advance(math.max(endsAt - serverNow() + 0.3, 0))
end
check(now() - caughtAt < Balance.Guard.CatchStunDuration, "C1 (banc) fin du chrono pendant le coup de la capture")
check(guardFor(B) ~= nil, "C1 Bob, intrus sans capture, a son vigile à la fin du chrono")
check(guardFor(A) == nil, "C1 aucun 2e vigile pour Alice à la fin du chrono")
advance(8)
check(catchesOf(A) == 1, "C1 Alice attrapée une seule fois (" .. catchesOf(A) .. ")")
check(#notifies("Caught", A) == caughtNotes, "C1 un seul « Caught! » pour Alice")
check(remotes("CatchScene", function(e)
	return e.to == A
end)[2] == nil, "C1 une seule scène de capture pour Alice")
check(not insideStore(A, STORE_A), "C1 Alice sortie du magasin après le coup")
check(catchesOf(B) >= 1 or guardFor(B) ~= nil, "C1 Bob encore poursuivi (ou attrapé) après la capture d'Alice")
Carry.Consume(A)
flush()
waitFor(function()
	return #guards() == 0
end, 60)

section("C2 intrus sans capture : toujours poursuivi à la fin du chrono")
moveTo(A, Vector3.new(65, 3, -12))
moveTo(B, Vector3.new(66, 3, -12))
advance(0.5)
reopen(A, STORE_B)
local endsB = chronoEndsAt(A)
check(endsB ~= nil, "C2 (banc) chrono reçu")
moveTo(A, Vector3.new(58, 3, -36))
advance(0.3)
local before = catchesOf(A)
if endsB then
	advance(math.max(endsB - serverNow() + 0.3, 0))
end
check(guardFor(A) ~= nil, "C2 le vigile de fin de chrono poursuit Alice, intruse sans capture")
check(catchesOf(A) == before, "C2 (banc) pas encore attrapée")
summary("scénario caught")
