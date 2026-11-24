--!nocheck
-- G. Le vigile suit le colis (6.2, GuardService) : le colis de sa cible tombe → il va vers lui sans
-- capturer personne ; quelqu'un le ramasse → il change de cible (même vigile, attente de réaction,
-- poursuite neuve) avec les règles d'abandon de 5.5 (zone safe, 20 s comptées du changement,
-- 120 studs) ; personne ne le ramasse → il abandonne ; colis ramassé sans vigile qui le suit : aucun
-- vigile ; colis du camion : aucun vigile.

local Carry = serverModule("CarryService")
local Window = serverModule("WindowService")
local Bat = sharedModule("Config/Bat")
local Balance = sharedModule("Config/Balance")
startServer()

local A = newPlayer("Alice") -- frappeuse
local B = newPlayer("Bob") -- casseur et premier porteur
local C = newPlayer("Chloe") -- ramasseuse
spawnCharacter(A, Vector3.new(80, 3, -10), Vector3.new(1, 0, 0))
spawnCharacter(B, Vector3.new(85, 3, 10))
spawnCharacter(C, Vector3.new(110, 3, -10))
flush()
advance(0.5) -- rig de remplacement du vigile prêt

local function swing(player)
	fireAs(player, "SwingBat")
	flush()
end
local function grab(player, dropId, hold)
	fireAs(player, "GrabDropped", dropId)
	advance(hold)
	fireAs(player, "GrabDropped", dropId)
	flush()
end
local function lastDrop()
	local list = batDrops()
	local model = list[#list]
	local id = model and model:GetAttribute("DropId")
	local payload, position = Carry.GetDrop(id)
	return model, id, payload, position
end
local function ensureOpen(store)
	if store:GetAttribute("HeistOpen") == true then
		return
	end
	local w = store:FindFirstChild("Window")
	if w:GetAttribute("Broken") == true then
		Window.Rebuild(w:GetAttribute("WindowId"))
		flush()
	end
	breakStore(B, store)
	advance(1.1)
end
local function chaseStates(player)
	return remotes("ChaseState", function(e)
		return e.to == player
	end)
end
local function lastChase(player)
	local list = chaseStates(player)
	return list[#list]
end
-- Plus aucun vigile : on attend qu'ils soient tous rentrés (ou partis).
local function waitNoGuard(maxSeconds)
	local t = 0
	while #guards() > 0 and t < maxSeconds do
		advance(0.5)
		t += 0.5
	end
	return #guards() == 0
end
-- Bob prend un colis de STORE_A et sort dans le couloir en `at`, son vigile derrière lui.
local function grabAndRun(at)
	ensureOpen(STORE_A)
	assert(grabShelf(B, STORE_A, fullSlot(STORE_A)), "prise refusée")
	local payload = Carry.GetPayload(B)
	advance(0.2)
	moveTo(B, at)
	return payload
end
-- Alice frappe Bob de 5 studs (côté −X).
local function hitB()
	local p = rootOf(B).Position
	moveTo(A, p - Vector3.new(5, 0, 0), Vector3.new(1, 0, 0))
	equipBat(A)
	swing(A)
	assert(not Carry.IsCarrying(B), "coup raté")
end

section("G1 Le vigile poursuit Bob")
local box = grabAndRun(Vector3.new(90, 3, 10))
check(#guards() == 1, "G1a un vigile")
local guard = guards()[1]
check(guard:GetAttribute("TargetUserId") == B.UserId, "G1b il poursuit Bob (TargetUserId)")
check(lastChase(B) and lastChase(B).args[1] == true, "G1c ChaseState(true) à Bob")
GOALS[B] = Vector3.new(400, 3, 10)
advance(2)
local groot = guard:FindFirstChild("HumanoidRootPart")
local lead = (rootOf(B).Position - groot.Position).Magnitude
check(lead < 60 and Carry.IsCarrying(B), `G1d poursuite en cours ({math.floor(lead)} studs entre eux)`)

section("G2 Le colis de Bob tombe : le vigile va vers lui, sans capturer")
GOALS[B] = nil
clearLog()
hitB()
local model, id, payload, position = lastDrop()
check(payload == box, "G2a le colis de Bob au sol")
check(guard:GetAttribute("TargetUserId") == 0, "G2b le vigile n'a plus de cible (TargetUserId = 0)")
check(lastChase(B).args[1] == false, "G2c ChaseState(false) à Bob")
check(logHas("est tombé au sol, il va vers lui", "PRINT", "server"), "G2d « il va vers lui »")
advance(6)
local d = Vector3.new(groot.Position.X - position.X, 0, groot.Position.Z - position.Z).Magnitude
check(d <= 3.5, `G2e il s'arrête près du colis ({string.format("%.1f", d)} studs)`)
check(not logHas("rattrapé", "PRINT", "server"), "G2f il n'a capturé personne (Bob, étourdi tout près, compris)")
check(#guards() == 1 and guards()[1] == guard, "G2g toujours le même vigile, seul")

section("G3 Chloé ramasse le colis : le vigile la poursuit (après sa réaction)")
moveTo(C, Vector3.new(position.X + 2, 3, position.Z))
clearLog()
grab(C, id, Bat.DroppedGrabTime)
check(Carry.GetPayload(C) == box, "G3a Chloé porte le même colis")
check(guard:GetAttribute("TargetUserId") == C.UserId, "G3b le même vigile la poursuit (TargetUserId)")
check(#guards() == 1, "G3c aucun nouveau vigile")
check(lastChase(C) and lastChase(C).args[1] == true and lastChase(C).args[2] == guard, "G3d ChaseState(true, vigile) à Chloé")
check(logHas("change de cible, poursuit Chloe", "PRINT", "server"), "G3e « change de cible »")
advance(Balance.Guard.CatchDistance > 0 and 0.4 or 0)
check(Carry.IsCarrying(C), "G3f 0,4 s après, tout près du vigile : pas encore capturée (délai de réaction)")
advance(1)
check(not Carry.IsCarrying(C) and logHas("Chloe rattrapé", "PRINT", "server"), "G3g puis capturée (4 studs)")
check(lastChase(C).args[1] == false, "G3h ChaseState(false) à Chloé")
advance(2.5)
check(#census().ground == 0 and #census().carried == 0 and #census().duplicates == 0, "G3i le colis est reparti vers son rayon, pas de doublon")
waitNoGuard(30)

section("G4 Le nouveau porteur atteint la zone safe : abandon")
local box2 = grabAndRun(Vector3.new(60, 3, 0))
guard = guards()[1]
advance(1)
hitB()
model, id, payload, position = lastDrop()
moveTo(C, Vector3.new(position.X - 2, 3, position.Z))
grab(C, id, Bat.DroppedGrabTime)
check(guard:GetAttribute("TargetUserId") == C.UserId, "G4a le vigile poursuit Chloé")
GOALS[C] = Vector3.new(-40, 3, 0) -- vers la zone safe (x < 25)
clearLog()
advance(4)
check(Carry.IsCarrying(C) and logHas("abandonne Chloe (zone safe)", "PRINT", "server"), "G4b Chloé en zone safe : le vigile abandonne")
GOALS[C] = nil
Carry.Consume(C, "Test")
CONSUMED[box2] = true
flush()
waitNoGuard(30)

section("G5 20 s de poursuite, comptées à partir du changement de cible")
local box3 = grabAndRun(Vector3.new(90, 3, 0))
guard = guards()[1]
local spawnedAt = now()
advance(2)
hitB()
model, id, payload, position = lastDrop()
advance(1.5)
moveTo(C, Vector3.new(position.X + 2, 3, position.Z))
grab(C, id, Bat.DroppedGrabTime)
local retargetAt = now()
GOALS[C] = Vector3.new(700, 3, 0) -- elle court droit devant (14,4 contre 13,4)
clearLog()
-- a66 (Cantin, 2026-11-11) : poursuite sans fin (Balance.Guard sans GiveUpChaseDuration) ; avant a66,
-- les anciens contrôles.
local ENDLESS = Balance.Guard.GiveUpChaseDuration == nil
if ENDLESS then
	advance(22)
	check(guard:GetAttribute("TargetUserId") == C.UserId and not logHas("abandonne", "PRINT", "server"), `G5a a66 : {string.format("%.1f", now() - retargetAt)} s après le changement de cible, il la poursuit toujours`)
	check(not logHas("s de poursuite", "PRINT", "server"), "G5b a66 : plus d'abandon au bout de 20 s (poursuite sans fin)")
else
	advance(Balance.Guard.GiveUpChaseDuration - (retargetAt - spawnedAt) + 1)
	check(guard:GetAttribute("TargetUserId") == C.UserId and not logHas("abandonne", "PRINT", "server"), `G5a {string.format("%.1f", now() - spawnedAt)} s après l'apparition du vigile : il la poursuit toujours`)
	advance(retargetAt + Balance.Guard.GiveUpChaseDuration + 0.5 - now())
	check(logHas("abandonne Chloe (20 s de poursuite)", "PRINT", "server"), `G5b {string.format("%.1f", now() - retargetAt)} s après le changement : abandon (20 s)`)
end
GOALS[C] = nil
Carry.Consume(C, "Test")
CONSUMED[box3] = true
flush()
waitNoGuard(40)

section("G6 120 studs d'avance : abandon")
local box4 = grabAndRun(Vector3.new(90, 3, 0))
guard = guards()[1]
advance(1)
hitB()
model, id, payload, position = lastDrop()
moveTo(C, Vector3.new(position.X + 2, 3, position.Z))
grab(C, id, Bat.DroppedGrabTime)
check(guard:GetAttribute("TargetUserId") == C.UserId, "G6a le vigile poursuit Chloé")
moveTo(C, Vector3.new(position.X + 130, 3, position.Z))
clearLog()
advance(1)
if ENDLESS then
	check(guard:GetAttribute("TargetUserId") == C.UserId and not logHas("abandonne Chloe", "PRINT", "server"), "G6b a66 : 130 studs d'avance, il la poursuit toujours (poursuite sans fin)")
else
	check(logHas("abandonne Chloe (120 studs d'avance)", "PRINT", "server"), "G6b 130 studs d'avance : abandon")
end
Carry.Consume(C, "Test")
CONSUMED[box4] = true
flush()
waitNoGuard(30)

section("G7 Personne ne ramasse : le vigile abandonne, le colis rentre sur son rayon")
local box5 = grabAndRun(Vector3.new(90, 3, 0))
guard = guards()[1]
advance(1)
hitB()
model, id, payload, position = lastDrop()
moveTo(B, Vector3.new(150, 3, 20))
moveTo(C, Vector3.new(150, 3, -20))
clearLog()
advance(Bat.DroppedLifetime + 0.3)
check(Carry.GetDrop(id) == nil and logHas("abandonne le colis tombé au sol (colis resté au sol, reparti vers son rayon)", "PRINT", "server"), "G7a 15 s sans preneur : le vigile abandonne")
check(logHas("resté au sol : revient sur", "PRINT", "server"), "G7b le colis revole vers son rayon")
check(waitNoGuard(30), "G7c le vigile rentre et disparaît")

section("G8 Colis ramassé sans vigile qui le suit : aucun vigile")
local box6 = grabAndRun(Vector3.new(60, 3, 0))
moveTo(B, Vector3.new(0, 3, 0)) -- zone safe : son vigile abandonne
advance(1)
check(guards()[1] == nil or guards()[1]:GetAttribute("TargetUserId") == 0, "G8a Bob en zone safe : plus de poursuite")
moveTo(B, Vector3.new(140, 3, 0)) -- il ressort dans le couloir
advance(Bat.HitImmunity)
hitB()
model, id, payload, position = lastDrop()
moveTo(C, Vector3.new(position.X + 2, 3, position.Z))
clearLog()
grab(C, id, Bat.DroppedGrabTime)
check(Carry.GetPayload(C) == box6, "G8b Chloé le ramasse")
check(guardFor(C) == nil and logHas("aucun vigile ne le suivait", "PRINT", "server"), "G8c aucun vigile pour elle")
Carry.Consume(C, "Test")
CONSUMED[box6] = true
flush()
waitNoGuard(30)

section("G9 Le porteur frappé avant que son vigile s'élance (état Wait)")
advance(Bat.HitImmunity) -- immunité de Bob (G8)
-- Chrono neuf : le magasin ne doit pas fermer (et sortir Chloé) pendant la scène.
local w = STORE_A:FindFirstChild("Window")
if w:GetAttribute("Broken") == true then
	Window.Rebuild(w:GetAttribute("WindowId"))
	flush()
end
ensureOpen(STORE_A)
assert(grabShelf(B, STORE_A, fullSlot(STORE_A)), "prise refusée")
local box7 = Carry.GetPayload(B)
advance(0.25) -- le vigile vient d'apparaître, il réagit en 0,5 s
guard = guards()[1]
local p = rootOf(B).Position
moveTo(A, Vector3.new(p.X, 3, p.Z - 4), Vector3.new(0, 0, 1))
equipBat(A)
clearLog()
swing(A)
check(not Carry.IsCarrying(B) and guard:GetAttribute("TargetUserId") == 0, "G9a touché dans le magasin : le vigile suit le colis")
model, id, payload, position = lastDrop()
moveTo(C, Vector3.new(position.X + 2, 3, position.Z))
grab(C, id, Bat.DroppedGrabTime)
check(guard:GetAttribute("TargetUserId") == C.UserId and #guards() == 1, "G9b Chloé le ramasse : le même vigile la poursuit")
moveTo(C, Vector3.new(-40, 3, 0))
advance(1)
Carry.Consume(C, "Test")
CONSUMED[box7] = true
flush()
check(#census().duplicates == 0, "G9c aucun doublon")

summary("scénario guard")
