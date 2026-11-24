--!nocheck
-- a172 (2026-11-15, vague 53, point d'a157) : un objet lié (a114) repris EN ZONE SAFE ne relance aucune poursuite :
-- ni le vigile qui le gardait au sol (retarget), ni demi-tour ou nouveau vigile du magasin (onLinkedPickup).
-- Contrôle : la même reprise hors zone safe relance bien la poursuite (comme le banc a114, L2).

startAll(true)
local Guard = serverModule("GuardService")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(70, 3, 10))
flush()
local LMIN = luckValues()[1]
local STREET = Vector3.new(65, 3, 12) -- couloir, devant STORE_A, hors zone safe
local IN_SAFE = Vector3.new(10, 0, 12) -- zone safe du banc : x de -105 à 25

local function waitFor(fn, maxSeconds)
	local t = 0
	while not fn() and t < maxSeconds do
		advance(0.1)
		t += 0.1
	end
	return fn()
end
local function grabDrop(p, dropId)
	fireAs(p, "GrabDropped", dropId)
	advance(BatCfg.DroppedGrabTime + 0.05)
	fireAs(p, "GrabDropped", dropId)
	flush()
	return Carry.IsCarrying(p)
end
local function takeFresh(p, n)
	reopen(p, STORE_A)
	local item = openAndReveal(p, STORE_A, n, LMIN, { 1 })
	check(item ~= nil and takeItem(p, STORE_A, n), "(banc) " .. p.Name .. " prend l'objet sorti")
	advance(0.1)
	return Carry.GetPayload(p)
end
local function dropAt(p, position)
	local id = Carry.Drop(p, position, "Banc")
	flush()
	return id
end

section("Z0 contrôle hors zone safe : la reprise relance la poursuite")
local payload0 = takeFresh(A, 1)
local g0 = guardFor(A)
check(g0 ~= nil and Guard.GetLinkedGuard(payload0) == g0, "Z0a un vigile lié poursuit Alice")
moveTo(A, STREET)
advance(1)
local drop0 = dropAt(A, STREET + Vector3.new(4, -3, 0))
check(drop0 ~= nil, "Z0 (banc) objet lâché dans le couloir")
advance(0.5)
moveTo(B, STREET + Vector3.new(2, 0, 0))
check(grabDrop(B, drop0), "Z0 (banc) Bob le reprend dans le couloir")
check(waitFor(function()
	return guardFor(B) ~= nil
end, 3), "Z0b hors zone safe, un vigile poursuit Bob")
-- Fin du contrôle : Bob rend l'objet à son rayon (attrapé dans le magasin : il revole).
moveTo(B, IN_SAFE + Vector3.new(0, 3, 0))
advance(3)
check(guardFor(B) == nil, "Z0 (banc) Bob en zone safe : plus poursuivi")
Carry.Fail(B, "Banc")
flush()
advance(20) -- vigiles rentrés, objet revenu

section("Z1 objet gardé au sol par son vigile, repris en zone safe : pas de poursuite (retarget)")
local before = logCount("est en zone safe", "PRINT", "server") + logCount("reprend un objet lié en zone safe", "PRINT", "server")
local payload = takeFresh(A, 2)
local g1 = guardFor(A)
check(g1 ~= nil, "Z1 (banc) un vigile poursuit Alice")
moveTo(A, Vector3.new(30, 3, 12)) -- au bord de la zone safe, côté couloir
advance(0.5)
local drop1 = dropAt(A, IN_SAFE)
check(drop1 ~= nil, "Z1 (banc) objet lâché dans la zone safe")
advance(0.3)
moveTo(C, IN_SAFE + Vector3.new(-2, 3, 0))
check(Carry.PickUpDrop(C, drop1) == true, "Z1 (banc) Chloe le reprend dans la zone safe (CarryService.PickUpDrop : BatService refuse déjà GrabDropped en zone safe, la garde de GuardService couvre le reste)")
advance(3)
check(guardFor(C) == nil, "Z1a aucun vigile ne poursuit Chloe")
check(logCount("poursuit Chloe qui a ramassé le colis", "PRINT", "server") == 0, "Z1b pas de changement de cible vers Chloe")
check(logCount("est en zone safe", "PRINT", "server") + logCount("reprend un objet lié en zone safe", "PRINT", "server") > before, "Z1c la reprise en zone safe est notée")
check(logCount("ressort", "PRINT", "server") == 0, "Z1d aucun vigile ne ressort du magasin")

section("Z2 objet lié repris en zone safe pendant le retour de son vigile : ni demi-tour ni nouveau vigile (onLinkedPickup)")
local before2 = logCount("reprend un objet lié en zone safe", "PRINT", "server")
local drop2 = dropAt(C, IN_SAFE + Vector3.new(0, 0, 4))
check(drop2 ~= nil, "Z2 (banc) Chloe le lâche dans la zone safe")
advance(0.3)
moveTo(B, IN_SAFE + Vector3.new(-2, 3, 4))
check(Carry.PickUpDrop(B, drop2) == true, "Z2 (banc) Bob le reprend dans la zone safe (CarryService.PickUpDrop)")
advance(3)
check(guardFor(B) == nil, "Z2a aucun vigile ne poursuit Bob")
check(logCount("fait demi-tour, Bob a repris son objet", "PRINT", "server") == 0, "Z2b pas de demi-tour")
check(logCount("ressort", "PRINT", "server") == 0, "Z2c aucun vigile ne ressort du magasin")
check(logCount("reprend un objet lié en zone safe", "PRINT", "server") > before2 or Guard.GetLinkedGuard(payload) == nil, "Z2d reprise en zone safe notée (ou objet plus lié)")

summary("scénario safe")
