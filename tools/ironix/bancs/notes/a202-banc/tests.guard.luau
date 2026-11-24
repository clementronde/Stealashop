--!nocheck
-- a202 : vigiles et batte pendant la cinématique d'ouverture.
startAll(true)
local Guard = serverModule("GuardService")
local BatS = serverModule("BatService")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(66, 3, 10))
flush()
local LMIN = luckValues()[1]
local catches = {}
Guard.OnCatch(function(p)
	table.insert(catches, p)
end)
local function chronoEndsAt(p)
	local list = remotes("HeistTimer", function(e)
		return e.to == p and e.args[2] > 0
	end)
	return if #list > 0 then list[#list].args[2] else nil
end

section("G1 chrono en pause : fini pendant la cinématique, aucun vigile pour l'ouvreur jusqu'à la fin")
reopen(A, STORE_A)
local _, ev = startReveal(A, STORE_A, 1, LMIN)
check(ev ~= nil, "G1 (banc) cinématique lancée")
advance(5.8)
check(STORE_A ~= nil and guardFor(A) == nil, "G1 aucun vigile pour Alice pendant sa cinématique (5,8 s)")
revealDone(A, ev and ev.args[10])
advance(0.3)
check(Carry.IsCarrying(A) and guardFor(A) ~= nil, "G1 à la fin : objet porté, le vigile le poursuit")
Carry.Consume(A)
flush()
waitFor(function()
	return guardFor(A) == nil
end, 60)

section("G2 vigile du chrono déjà sorti : figé pendant la cinématique, puis reprise")
moveTo(A, Vector3.new(65, 3, 12))
waitFor(function()
	return STORE_A:GetAttribute("HeistOpen") ~= true
end, 60)
reopen(A, STORE_A)
local endsAt = chronoEndsAt(A)
check(endsAt ~= nil, "G2 (banc) chrono d'Alice reçu")
standAt(A, STORE_A, 2)
local box = boxAt(STORE_A, 2)
local slotId = box and box:GetAttribute("SlotId")
-- Le vigile de fin de chrono sort pour Alice, puis elle ouvre : la cinématique part avec le vigile sorti.
check(waitFor(function()
	return guardFor(A) ~= nil
end, 12), "G2 (banc) le vigile de fin de chrono sort pour Alice")
local beforeReveal = #revealsOf(A)
fireOpen(A, slotId)
advance(0.2)
local guard = guardFor(A)
check(#revealsOf(A) > beforeReveal, "G2 (banc) cinématique lancée juste après la fin du chrono")
check(guard ~= nil, "G2 (banc) le vigile du chrono vise Alice")
local root = guard and guard:FindFirstChild("HumanoidRootPart")
local p0 = root and root.Position
advance(3)
local p1 = root and root.Position
check(p0 ~= nil and p1 ~= nil and (p1 - p0).Magnitude < 0.5, "G2 vigile figé pendant la cinématique (" .. string.format("%.2f", if p0 and p1 then (p1 - p0).Magnitude else -1) .. " studs)")
check(#catches == 0, "G2 aucune capture pendant la cinématique")
check(not Guard.ChaseIntruder(A, STORE_A), "G2 ChaseIntruder refusé pour un joueur protégé")
local ev2 = lastReveal(A)
revealDone(A, ev2 and ev2.args[10])
check(Carry.IsCarrying(A), "G2 à la fin : objet porté")
advance(0.3)
local p2 = root and root.Position
check(guardFor(A) ~= nil and p2 ~= nil and (p2 - p1).Magnitude > 0.5, "G2 le vigile reprend la poursuite")
Carry.Consume(A)
flush()
waitFor(function()
	return guardFor(A) == nil
end, 60)

section("G3 batte : aucun coup sur un joueur protégé")
local hits = {}
BatS.OnHit(function(attacker, victim)
	table.insert(hits, { attacker = attacker, victim = victim })
end)
reopen(B, STORE_B)
advance(1.1) -- avance du casseur (Bob)
local _, ev3 = startReveal(A, STORE_B, 3, LMIN)
check(ev3 ~= nil, "G3 (banc) cinématique lancée")
local ra = rootOf(A)
equipBat(B)
moveTo(B, ra.Position + Vector3.new(0, 0, -2.5), ra.Position)
face(B, ra.Position)
advance(0.2)
fireAs(B, "SwingBat")
advance(0.6)
check(#hits == 0, "G3 coup de batte de Bob sur Alice protégée : aucun effet")
revealDone(A, ev3 and ev3.args[10])
summary("scénario guard")
