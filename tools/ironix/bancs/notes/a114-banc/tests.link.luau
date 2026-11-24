--!nocheck
-- a114 L. Objet lié au vigile (Cantin, 2026-11-13 ; Features.ShelfOpen = true, sans WitnessService) :
-- ouvrir ne déclenche rien ; prendre l'objet sorti fait sortir un vigile, lié à l'objet ; attrapé, l'objet
-- tombe, le vigile le garde à côté (2026-11-13) et poursuit qui le reprend (le joueur attrapé compris) ;
-- 15 s au sol ou rangé : fin du lien ; fin du chrono : pas de second vigile ;
-- camion et objet volé à un joueur : jamais liés ; attrapé dans le magasin de l'objet : il revole sur son rayon.

startAll(true)
local Guard = serverModule("GuardService")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(70, 3, 10))
flush()
local LMIN = luckValues()[1]
local STREET = Vector3.new(65, 3, 12) -- couloir, devant STORE_A, hors zone safe

local function waitFor(fn, maxSeconds)
	local t = 0
	while not fn() and t < maxSeconds do
		advance(0.1)
		t += 0.1
	end
	return fn()
end
local function lastDrop()
	local list = batDrops()
	local model = list[#list]
	if model == nil then
		return nil
	end
	local id = model:GetAttribute("DropId")
	local payload, position = Carry.GetDrop(id)
	return model, id, payload, position
end
local function grabDrop(p, dropId)
	fireAs(p, "GrabDropped", dropId)
	advance(BatCfg.DroppedGrabTime + 0.05)
	fireAs(p, "GrabDropped", dropId)
	flush()
	return Carry.IsCarrying(p)
end
local function caught(p)
	return waitFor(function()
		return not Carry.IsCarrying(p)
	end, 30)
end
local function chasersOf(p)
	local n = 0
	for _, g in guards() do
		if g:GetAttribute("TargetUserId") == p.UserId then
			n += 1
		end
	end
	return n
end
local spawnZ = STORE_A:FindFirstChild("GuardSpawn", true)

section("L1 ouvrir ne déclenche rien ; prendre l'objet sorti : un vigile, lié à l'objet")
reopen(A, STORE_A)
local item = openAndReveal(A, STORE_A, 1, LMIN, { 1 })
check(item ~= nil and #guards() == 0, "L1a objet sorti du colis : aucun vigile à l'ouverture")
check(takeItem(A, STORE_A, 1), "L1 (banc) Alice prend l'objet")
local payload = Carry.GetPayload(A)
advance(0.1)
local g1 = guardFor(A)
check(g1 ~= nil and #guards() == 1, "L1b un vigile sort tout de suite pour Alice")
check(g1 ~= nil and Guard.GetLinkedGuard(payload) == g1, "L1c ce vigile est lié à l'objet (GetLinkedGuard)")

-- 2026-11-13 (Cantin, session principale) : attrapé, l'objet tombe et le vigile va le garder à côté (Follow)
-- jusqu'à ce qu'il revole vers son rayon ; il ne rentre plus. Ancienne version : tests.link.avant-garde-objet.luau.
section("L2 capture : il garde l'objet tombé, puis poursuit qui le reprend (même vigile)")
moveTo(A, STREET)
check(caught(A), "L2 (banc) le vigile attrape Alice")
local model, dropId, dropPayload, dropPosition = lastDrop()
check(dropPayload == payload, "L2a l'objet est au sol")
check(Guard.GetLinkedGuard(payload) == g1, "L2b toujours lié au vigile qui vient d'attraper")
check(waitFor(function()
	return logCount("est tombé au sol, il va vers lui", "PRINT", "server") >= 1
end, 5) and logCount("rentre en marchant", "PRINT", "server") == 0, "L2c le vigile va garder l'objet tombé (Follow), il ne rentre pas")
check(guardFor(B) == nil, "L2 (banc) personne n'est poursuivi")
moveTo(B, dropPosition + Vector3.new(-2, 3, 0))
check(grabDrop(B, dropId), "L2 (banc) Bob reprend l'objet")
check(waitFor(function()
	return guardFor(B) ~= nil
end, 3) and guardFor(B) == g1 and #guards() == 1, "L2d le même vigile poursuit Bob")
check(logCount("poursuit Bob qui a ramassé le colis", "PRINT", "server") == 1 or logCount("Bob a repris son objet pendant Catch", "PRINT", "server") == 1, "L2e changement de cible noté")
check(caught(B), "L2 (banc) le vigile attrape Bob")
model, dropId, dropPayload, dropPosition = lastDrop()
check(dropPayload == payload and Guard.GetLinkedGuard(payload) == g1, "L2f objet au sol, toujours lié au même vigile")
-- Le joueur attrapé le premier le reprend, son étourdissement fini.
advance(Balance.Guard.CatchStunDuration + 0.2)
moveTo(A, dropPosition + Vector3.new(2, 3, 0))
check(grabDrop(A, dropId), "L2 (banc) Alice reprend l'objet (étourdissement fini)")
check(waitFor(function()
	return guardFor(A) ~= nil
end, 3) and guardFor(A) == g1 and #guards() == 1, "L2g le même vigile repart derrière Alice")

section("L3 il reste à côté de l'objet tant qu'il est au sol (12 s), puis poursuit qui le reprend")
check(caught(A), "L3 (banc) attrapée de nouveau")
model, dropId, dropPayload, dropPosition = lastDrop()
advance(12)
check(Carry.GetDrop(dropId) == payload, "L3 (banc) l'objet est encore au sol")
check(#guards() == 1 and Guard.GetLinkedGuard(payload) == g1, "L3a le vigile est toujours là, lié à l'objet")
local g1root = g1 and g1:FindFirstChild("HumanoidRootPart")
local g1pos = g1root and g1root.Position
check(g1pos ~= nil and (Vector3.new(g1pos.X, 0, g1pos.Z) - Vector3.new(dropPosition.X, 0, dropPosition.Z)).Magnitude <= 6, "L3c il attend à côté de l'objet")
moveTo(B, dropPosition + Vector3.new(-2, 3, 0))
check(grabDrop(B, dropId), "L3 (banc) Bob reprend l'objet")
advance(0.1)
local g2 = guardFor(B)
check(g2 == g1 and #guards() == 1, "L3b le même vigile poursuit Bob, aucun autre ne sort")
check(Guard.GetLinkedGuard(payload) == g1, "L3d toujours lié au même vigile")
check(logCount("ressort", "PRINT", "server") == 0, "L3e aucun vigile ne ressort du magasin")

section("L4 15 s au sol sans preneur : fin du lien")
check(caught(B), "L4 (banc) le nouveau vigile attrape Bob")
model, dropId, dropPayload, dropPosition = lastDrop()
advance(BatCfg.DroppedLifetime + 0.3)
check(Carry.GetDrop(dropId) == nil, "L4a l'objet a revolé vers son rayon")
check(Guard.GetLinkedGuard(payload) == nil, "L4b plus lié à aucun vigile")
advance(3)
check(itemAt(STORE_A, 1) ~= nil, "L4c il est revenu sur son rayon")
check(chasersOf(A) == 0 and chasersOf(B) == 0 and chasersOf(C) == 0, "L4d aucun vigile ne repart")

section("L5 rangé en base : fin du lien")
check(waitFor(function()
	return #guards() == 0
end, 30), "L5 (banc) plus de vigile")
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
reopen(C, STORE_A)
check(openAndReveal(C, STORE_A, 2, LMIN, { 1 }) ~= nil and takeItem(C, STORE_A, 2), "L5 (banc) Chloé prend un objet")
local payloadC = Carry.GetPayload(C)
advance(0.1)
local g3 = guardFor(C)
check(g3 ~= nil and Guard.GetLinkedGuard(payloadC) == g3, "L5a vigile sorti et lié")
Carry.Consume(C)
flush()
check(Guard.GetLinkedGuard(payloadC) == nil, "L5b rangé : plus lié")
advance(0.5)
check(chasersOf(C) == 0, "L5c le vigile abandonne")

section("L6 lâché hors du magasin, repris par un autre ; fin du chrono : pas de second vigile")
check(waitFor(function()
	return #guards() == 0
end, 30), "L6 (banc) plus de vigile")
reopen(A, STORE_B)
local endsB = STORE_B:GetAttribute("HeistEndsAt") - SERVER_TIME_OFFSET
check(openAndReveal(A, STORE_B, 1, LMIN, { 1 }) ~= nil and takeItem(A, STORE_B, 1), "L6 (banc) Alice prend un objet de STORE_B")
local payloadB = Carry.GetPayload(A)
advance(0.1)
local g4 = guardFor(A)
check(g4 ~= nil and Guard.GetLinkedGuard(payloadB) == g4, "L6a vigile à la prise, lié")
standAt(C, STORE_B, 6) -- Chloé entre pendant le chrono et y reste
moveTo(A, Vector3.new(65, 3, -12))
advance(0.1)
Carry.Drop(A, nil, "Released")
flush()
model, dropId, dropPayload, dropPosition = lastDrop()
check(dropPayload == payloadB and chasersOf(A) == 0, "L6b Alice lâche l'objet dehors : son vigile la quitte")
moveTo(B, dropPosition + Vector3.new(2, 3, 0))
check(grabDrop(B, dropId), "L6 (banc) Bob le ramasse")
check(guardFor(B) == g4, "L6c le même vigile poursuit Bob")
GOALS[B] = Vector3.new(600, 3, -12) -- Bob court plus vite que le vigile (vitesse de portage > vitesse de la zone 1)
check(now() < endsB, "L6 (banc) avant la fin du chrono (" .. math.round((endsB - now()) * 10) / 10 .. " s)")
advance(endsB - now() + 0.3)
check(Carry.GetPayload(B) == payloadB and chasersOf(B) == 1 and guardFor(B) == g4, "L6d fin du chrono : Bob garde un seul vigile, le lié")
check(chasersOf(A) == 0, "L6e aucun vigile pour Alice (sortie, l'objet a déjà le sien)")
check(guardFor(C) ~= nil, "L6f un vigile pour Chloé, encore dans le magasin")
check(logCount(STORE_B.Name .. " : fin du chrono, 1 vigile(s) sorti(s) pour 1 intrus dans le magasin", "PRINT", "server") == 1, "L6g fin du chrono notée : 1 intrus dans le magasin")
GOALS[B] = nil
Carry.Consume(B)
flush()

section("L7 camion et objet volé à un joueur : jamais liés")
check(waitFor(function()
	return #guards() == 0
end, 60), "L7 (banc) plus de vigile")
local truck = { Kind = "NPCBox", Tier = "Standard", Zone = 1, Rarity = "Common", ItemId = "Z1_CanetteDeSoda", StoreId = "Truck_1", SlotId = "Truck_1/1" }
local truckId = Carry.PlaceDrop(truck, Vector3.new(120, 0, 0))
check(truckId ~= nil, "L7 (banc) colis du camion posé au sol")
moveTo(B, Vector3.new(122, 3, 0))
check(Carry.PickUpDrop(B, truckId), "L7 (banc) Bob le ramasse (PickUpDrop, comme TruckEventService)")
flush()
advance(0.5)
check(#guards() == 0 and Guard.GetLinkedGuard(truck) == nil, "L7a colis du camion : aucun vigile, pas lié")
Carry.Consume(B)
flush()
local stolen = { Kind = "PlayerItem", ItemUid = "uid-a114", ItemId = "Z1_CanetteDeSoda", Rarity = "Common", Income = 1, VictimUserId = C.UserId, SlotIndex = 1 }
check(Carry.StartCarry(B, stolen), "L7 (banc) Bob porte un objet volé à un joueur")
flush()
advance(0.5)
check(#guards() == 0 and Guard.GetLinkedGuard(stolen) == nil, "L7b objet volé : aucun vigile, pas lié")
Carry.Fail(B, "Caught")
flush()
check(Guard.GetLinkedGuard(stolen) == nil and #guards() == 0, "L7c toujours rien après la perte")

-- 2026-11-13 au soir (Cantin, session principale) : attrapé dans le magasin d'où vient l'objet, l'objet ne tombe
-- pas, il revole sur son rayon ; le vigile ne le garde pas, il rentre au GuardSpawn (le magasin se referme).
section("L10 attrapé dans le magasin de l'objet : l'objet revole sur son rayon, le vigile rentre")
check(waitFor(function()
	return #guards() == 0
end, 60), "L10 (banc) plus de vigile")
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
reopen(A, STORE_A)
check(openAndReveal(A, STORE_A, 3, LMIN, { 1 }) ~= nil and takeItem(A, STORE_A, 3), "L10 (banc) Alice prend l'objet du rayon 3")
local payloadIn = Carry.GetPayload(A)
local dropsBefore = #batDrops()
local followBefore = logCount("est tombé au sol, il va vers lui", "PRINT", "server")
local returnBefore = logCount("rentre en marchant vers la réserve (GuardSpawn), déjà dans le magasin", "PRINT", "server")
advance(0.1)
local g5 = guardFor(A)
check(g5 ~= nil and Guard.GetLinkedGuard(payloadIn) == g5, "L10 (banc) un vigile sort pour Alice, lié à l'objet")
standAt(A, STORE_A, 3) -- elle reste dans le magasin
check(caught(A), "L10 (banc) attrapée dans le magasin")
check(logCount("attrapé dans le magasin de son objet, l'objet revole sur son rayon", "PRINT", "server") == 1, "L10a capture dans le magasin de l'objet notée")
check(#batDrops() == dropsBefore, "L10b l'objet ne tombe pas au sol")
check(Guard.GetLinkedGuard(payloadIn) == nil, "L10c plus lié à aucun vigile")
advance(3)
check(itemAt(STORE_A, 3) ~= nil, "L10d l'objet est revenu sur son rayon 3")
check(waitFor(function()
	return logCount("rentre en marchant vers la réserve (GuardSpawn), déjà dans le magasin", "PRINT", "server") > returnBefore
end, 10), "L10e à la fin de Catch, le vigile rentre au GuardSpawn")
check(logCount("est tombé au sol, il va vers lui", "PRINT", "server") == followBefore, "L10f il ne garde aucun objet (pas de Follow)")
check(waitFor(function()
	return g5 == nil or g5.Parent == nil
end, 30), "L10g le vigile s'efface")

check(logCount("tick :", "WARN", "server") == 0, "L8 aucune erreur du tick")
check(logCount("[GuardService]", "WARN", "server") == 0, "L9 aucun avertissement de GuardService")

summary("scénario link")
