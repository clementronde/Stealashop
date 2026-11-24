--!nocheck
-- K. Fin du portage d'un objet sorti : attrapé par le vigile (« Caught »), l'objet tombe au sol et se
-- reprend (GrabDropped), pas tout de suite par le joueur attrapé ; coup de batte ; resté au sol, il revole
-- vers son rayon ; mort, départ : retour sur le rayon ; rangé : il ne revient pas ; rayons remplis
-- entre-temps : il disparaît.

startAll()
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(70, 3, 10))
flush()
local LMIN = luckValues()[1]
local STREET = Vector3.new(65, 3, 12) -- dans le couloir, devant STORE_A, hors de la zone safe
local ended = {}
Carry.OnCarryEnded(function(p, payload, result, reason)
	table.insert(ended, { player = p, payload = payload, result = result, reason = reason, t = now() })
end)
local function lastEnd()
	return ended[#ended]
end
local function waitNoGuard(maxSeconds)
	local t = 0
	while #guards() > 0 and t < maxSeconds do
		advance(0.5)
		t += 0.5
	end
	return #guards() == 0
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
local function grabDrop(p, dropId, hold)
	fireAs(p, "GrabDropped", dropId)
	advance(hold or (BatCfg.DroppedGrabTime + 0.05))
	fireAs(p, "GrabDropped", dropId)
	flush()
	return Carry.IsCarrying(p)
end
-- `p` (casseur) ouvre le colis du rayon `n`, prend l'objet sorti et sort dans le couloir.
local function carryOut(p, n, at)
	if not waitNoGuard(90) then
		error("vigile encore là")
	end
	WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId")) -- magasin rouvert pour tous
	flush()
	reopen(p, STORE_A)
	local item = openAndReveal(p, STORE_A, n, LMIN, { 1 })
	assert(item and takeItem(p, STORE_A, n), "prise refusée (rayon " .. n .. ")")
	local payload = Carry.GetPayload(p)
	moveTo(p, at or STREET)
	return payload
end

section("K1 attrapé par le vigile : l'objet tombe au sol")
local payload = carryOut(A, 1)
moveTo(B, STREET + Vector3.new(5, 0, 0))
local caughtAt = nil
for _ = 1, 300 do
	advance(0.1)
	if not Carry.IsCarrying(A) then
		caughtAt = now()
		break
	end
end
check(caughtAt ~= nil, "K1 (banc) le vigile a rattrapé Alice")
local e = lastEnd()
check(e ~= nil and e.player == A and e.payload == payload and e.result == "Dropped" and e.reason == "Caught", "K1a OnCarryEnded : Dropped, Caught (" .. tostring(e and e.result) .. ", " .. tostring(e and e.reason) .. ")")
local model, dropId, dropPayload, dropPosition = lastDrop()
check(model ~= nil and dropPayload == payload, "K1b l'objet est au sol (Workspace/CarryDrops, attribut BatDrop), même payload")
check(dropId ~= nil and Carry.IsFallenDrop(dropId), "K1c IsFallenDrop")
check(dropPosition ~= nil and math.abs(dropPosition.Y) < 0.6 and (Vector3.new(dropPosition.X, 0, dropPosition.Z) - Vector3.new(STREET.X, 0, STREET.Z)).Magnitude < 12, "K1d posé au sol, là où elle a été attrapée")
check(model ~= nil and model:FindFirstChild("BB_Carry", true) ~= nil, "K1e l'objet au sol garde son étiquette BB_Carry")
check(itemAt(STORE_A, 1) == nil and boxAt(STORE_A, 1) == nil, "K1f il ne retourne pas sur son rayon")
check(#notifies("Caught!", A) >= 1, "K1g message de capture du vigile")

section("K2 reprise de l'objet tombé")
moveTo(A, dropPosition + Vector3.new(2, 3, 0))
check(not grabDrop(A, dropId), "K2a le joueur attrapé ne le reprend pas tout de suite (étourdi)")
check(Carry.GetDrop(dropId) == payload, "K2b l'objet est toujours au sol")
moveTo(B, dropPosition + Vector3.new(-2, 3, 0))
check(grabDrop(B, dropId), "K2c un autre joueur le ramasse tout de suite")
check(Carry.GetPayload(B) == payload and Carry.GetDrop(dropId) == nil, "K2d même payload, plus rien au sol")
check(B.Character:FindFirstChild("CarryVisual") ~= nil and B:GetAttribute("Carrying") == payload.Rarity, "K2e il le porte sur la tête")
-- a114 (Cantin, 2026-11-13) : l'objet reste lié au vigile qui vient d'attraper : il fait demi-tour.
check(guardFor(B) ~= nil, "K2f a114 : le vigile qui vient d'attraper fait demi-tour derrière celui qui ramasse")
Carry.Consume(B)
flush()

section("K3 le joueur attrapé reprend son objet après l'étourdissement")
payload = carryOut(A, 2)
local failAt = now()
check(Carry.Fail(A, "Caught") == true, "K3a Fail(« Caught ») d'un objet sorti : true")
model, dropId, dropPayload, dropPosition = lastDrop()
check(dropPayload == payload and not Carry.IsCarrying(A), "K3b au sol, plus porté")
moveTo(A, dropPosition + Vector3.new(1, 3, 0))
check(not grabDrop(A, dropId), "K3c refusé juste après la chute")
advance(Balance.Guard.CatchStunDuration - (now() - failAt) + 0.1)
check(grabDrop(A, dropId), "K3d repris après CatchStunDuration (" .. Balance.Guard.CatchStunDuration .. " s)")
check(Carry.GetPayload(A) == payload, "K3e même payload")

section("K4 coup de batte : l'objet tombe comme un colis")
moveTo(A, STREET + Vector3.new(20, 0, 0))
moveTo(C, STREET + Vector3.new(15, 0, 0), Vector3.new(1, 0, 0))
equipBat(C)
SHIELDED[A] = true
fireAs(C, "SwingBat")
advance(0.6)
check(Carry.GetPayload(A) == payload, "K4a bouclier débutant : le coup ne fait rien tomber")
SHIELDED[A] = nil
advance(1)
fireAs(C, "SwingBat")
advance(0.6)
e = lastEnd()
check(not Carry.IsCarrying(A) and e.payload == payload and e.result == "Dropped" and e.reason == "Bat", "K4b coup de batte : Dropped, Bat")
model, dropId, dropPayload, dropPosition = lastDrop()
check(dropPayload == payload and Carry.IsFallenDrop(dropId), "K4c l'objet est au sol")
moveTo(B, dropPosition + Vector3.new(-2, 3, 0))
check(grabDrop(B, dropId), "K4d ramassé par GrabDropped (BatService)")

section("K5 resté au sol : il revole vers son rayon")
check(Carry.Fail(B, "Caught") == true, "K5 (banc) Bob le lâche")
model, dropId, dropPayload, dropPosition = lastDrop()
advance(BatCfg.DroppedLifetime - 0.5)
check(Carry.GetDrop(dropId) == payload and itemAt(STORE_A, 2) == nil, "K5a encore au sol juste avant Bat.DroppedLifetime")
advance(0.6)
local back = itemAt(STORE_A, 2)
check(Carry.GetDrop(dropId) == nil and back ~= nil, "K5b au bout de " .. BatCfg.DroppedLifetime .. " s : plus au sol, de retour sur son rayon")
check(back ~= nil and back:GetAttribute("ItemId") == payload.ItemId and back:GetAttribute("Rarity") == payload.Rarity, "K5c le même objet")
check(back ~= nil and back:GetAttribute("Landed") == false, "K5d en vol (Landed = false)")
advance(1.6)
check(back ~= nil and back:GetAttribute("Landed") == true and cfClose(back:GetPivot(), slotAttachment(STORE_A, 2).WorldCFrame, 1e-3), "K5e posé sur son ShelfSlot")
check(back ~= nil and back:GetAttribute("ShelfLuck") == payload.Luck and back:GetAttribute("ShelfReservedBy") == A.UserId, "K5f attributs gardés (chance, ouvreur)")
check(itemCount(STORE_A) == 1, "K5g un seul exemplaire")

section("K6 mort, départ, rangement")
payload = carryOut(A, 3)
local hum = humanoidOf(A)
hum.Health = 0
hum.Died:Fire()
flush()
e = lastEnd()
check(e.payload == payload and e.result == "Failed" and e.reason == "Died", "K6a mort : Failed, Died")
check(#batDrops() == 0, "K6b rien au sol")
advance(1.6)
back = itemAt(STORE_A, 3)
check(back ~= nil and back:GetAttribute("ItemId") == payload.ItemId and back:GetAttribute("Landed") == true, "K6c l'objet est revenu sur son rayon")
spawnCharacter(A, STREET)
flush()
payload = carryOut(C, 4)
Carry.Consume(C)
flush()
advance(2)
check(itemAt(STORE_A, 4) == nil and boxAt(STORE_A, 4) == nil, "K6d rangé (Consumed) : il ne revient pas")
payload = carryOut(B, 5)
leave(B)
advance(1.6)
back = itemAt(STORE_A, 5)
check(back ~= nil and back:GetAttribute("ItemId") == payload.ItemId, "K6e départ du porteur : l'objet est revenu sur son rayon")

section("K7 rayons remplis entre-temps : l'objet ne revient pas")
payload = carryOut(A, 6)
advance(12) -- fin du chrono
Heist.RefillAll()
flush()
check(boxCount(STORE_A) == 10 and itemCount(STORE_A) == 0, "K7a nuit : 10 colis neufs, plus aucun objet sorti")
Carry.Fail(A, "Anomaly")
flush()
advance(2)
check(boxCount(STORE_A) == 10 and itemCount(STORE_A) == 0, "K7b l'objet porté pendant le remplissage disparaît (pas de doublon)")
check(logCount("tick :", "WARN", "server") == 0, "K8 aucune erreur du tick")

summary("scénario caught")
