--!nocheck
-- a174 (2026-11-15, vague 54, Cantin) : troisième capture d'un même objet (Chase.ReturnToShelfAfterCatches = 3).
-- Mise en place du banc a114 (a66-banc/autres-bancs/a30-banc, a114-banc/autres-bancs/a103-banc/head.luau), sans témoins.
--   C1 trois captures du même objet, par deux porteurs (Alice, Bob, Alice) : aux 1re et 2e il tombe ; à la 3e il ne
--      tombe pas, il revole tel quel (même ItemId, rareté, mutation, type) sur son rayon, en vol puis posé, libre ;
--   C2 repris sur le rayon : compteur neuf (la capture suivante le fait tomber) ;
--   C3 deux captures puis rangé en zone safe (Consume, comme UnboxService) : gardé, rien ne revient au rayon.
startAll(true)
local Guard = serverModule("GuardService")
local ChaseCfg = sharedModule("Config/Chase")
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
local function attrs(m)
	if m == nil then
		return nil
	end
	return table.concat({
		tostring(m:GetAttribute("ItemId")),
		tostring(m:GetAttribute("Rarity")),
		tostring(m:GetAttribute("MutationSize")),
		tostring(m:GetAttribute("MutationEffect")),
		tostring(m:GetAttribute("Tier")),
	}, "/")
end
-- Attrapé dans la rue : l'objet tombe ; renvoie l'id du colis au sol et sa position.
local function caughtDrops(p, payload, label)
	moveTo(p, STREET)
	check(caught(p), label .. " (banc) " .. p.Name .. " est attrapé(e)")
	local _, id, dropPayload, position = lastDrop()
	check(dropPayload == payload, label .. " l'objet tombe au sol")
	advance(Balance.Guard.CatchStunDuration + 0.2)
	return id, position
end

check(ChaseCfg.ReturnToShelfAfterCatches == 3, "C0 Config/Chase : ReturnToShelfAfterCatches = 3")

section("C1 trois captures du même objet par deux porteurs : retour au rayon tel quel à la 3e")
reopen(A, STORE_A)
local shown = openAndReveal(A, STORE_A, 1, LMIN, { 1 })
local before = attrs(shown)
check(shown ~= nil and takeItem(A, STORE_A, 1), "C1 (banc) Alice prend l'objet du rayon 1 (" .. tostring(before) .. ")")
local payload = Carry.GetPayload(A)
advance(0.1)
check(guardFor(A) ~= nil, "C1 (banc) un vigile poursuit Alice")
local id1, pos1 = caughtDrops(A, payload, "C1a 1re capture :")
moveTo(B, pos1 + Vector3.new(-2, 3, 0))
check(grabDrop(B, id1), "C1 (banc) Bob reprend l'objet")
local id2, pos2 = caughtDrops(B, payload, "C1b 2e capture (autre porteur) :")
moveTo(A, pos2 + Vector3.new(2, 3, 0))
check(grabDrop(A, id2), "C1 (banc) Alice le reprend")
check(Carry.GetPayload(A) == payload, "C1 (banc) même objet (même payload)")
local dropsBefore = #batDrops()
local backLogs = logCount("capture 3 de cet objet, il revole sur son rayon", "PRINT", "server")
moveTo(A, STREET)
check(caught(A), "C1 (banc) Alice attrapée une 3e fois")
check(#batDrops() == dropsBefore and Carry.GetDrop(id2) == nil, "C1c 3e capture : rien ne tombe au sol")
check(logCount("capture 3 de cet objet, il revole sur son rayon", "PRINT", "server") == backLogs + 1, "C1d 3e capture notée par GuardService")
check(logCount("(Caught) : revient sur", "PRINT", "server") >= 1, "C1e StoreHeistService le fait revoler (échec sans chute « Caught »)")
local flying = itemAt(STORE_A, 1)
check(flying ~= nil and flying:GetAttribute("Landed") == false, "C1f l'objet est en vol vers son rayon 1 (même vol qu'une capture dans le magasin)")
check(Guard.GetLinkedGuard(payload) == nil, "C1g plus lié à aucun vigile")
advance(3)
local back = itemAt(STORE_A, 1)
check(back ~= nil and back:GetAttribute("Landed") == true, "C1h posé sur son rayon 1")
check(attrs(back) == before, "C1i tel quel : même ItemId, rareté, mutation, type (" .. tostring(attrs(back)) .. ")")
check(boxAt(STORE_A, 1) == nil, "C1j c'est l'objet posé (pas un colis fermé)")
check(not Carry.IsCarrying(A) and not Carry.IsCarrying(B), "C1k personne ne le porte")

section("C2 repris sur son rayon : compteur neuf, la capture suivante le fait tomber")
check(waitFor(function()
	return #guards() == 0
end, 60), "C2 (banc) plus de vigile")
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
reopen(B, STORE_A)
check(takeItem(B, STORE_A, 1), "C2a Bob reprend l'objet revenu sur le rayon 1 (libre, réservation passée)")
local payload2 = Carry.GetPayload(B)
check(payload2 ~= nil and payload2 ~= payload and payload2.ItemId == payload.ItemId, "C2b même objet, nouveau portage")
advance(0.1)
local logs1 = logCount("capture 1 de cet objet", "PRINT", "server")
local id3, pos3 = caughtDrops(B, payload2, "C2c capture suivante :")
check(logCount("capture 1 de cet objet", "PRINT", "server") == logs1 + 1, "C2d comptée comme 1re capture")

section("C3 deux captures puis rangé en zone safe : objet gardé")
moveTo(C, pos3 + Vector3.new(-2, 3, 0))
check(grabDrop(C, id3), "C3 (banc) Chloé reprend l'objet")
local id4, pos4 = caughtDrops(C, payload2, "C3a 2e capture :")
moveTo(A, pos4 + Vector3.new(2, 3, 0))
check(grabDrop(A, id4), "C3 (banc) Alice le reprend")
local backBefore = logCount("revient sur", "PRINT", "server")
moveTo(A, Vector3.new(10, 3, 12)) -- zone safe du banc
advance(1)
check(Carry.Consume(A, "Stowed") == payload2, "C3 (banc) rangé à l'arrivée en zone safe (Consume, comme UnboxService)")
flush()
advance(3)
check(itemAt(STORE_A, 1) == nil and logCount("revient sur", "PRINT", "server") == backBefore, "C3b rien ne revient au rayon")
check(not Carry.IsCarrying(A) and #batDrops() == 0, "C3c ni porté ni au sol : gardé")

check(logCount("tick :", "WARN", "server") == 0, "C8 aucune erreur du tick")
check(logCount("[GuardService]", "WARN", "server") == 0, "C9 aucun avertissement de GuardService")
summary("scénario capture")
