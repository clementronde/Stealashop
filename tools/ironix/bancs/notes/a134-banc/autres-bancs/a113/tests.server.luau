--!nocheck
-- a113 S. Lâcher côté serveur (DropCarried → DropService → CarryService.Drop) : refus sans portage, chute au
-- sol sous le joueur, vigile qui suit l'objet, reprise par un autre (et par celui qui l'a lâché), retour sur
-- le rayon sans preneur, objet NPCItem, objet volé (revient chez son propriétaire), refus étourdi, mort,
-- trop rapproché.

moduleScript(SERVICES, "DropService", "server/Services/DropService.luau")
local Carry = serverModule("CarryService")
local Guard = serverModule("GuardService")
local BatS = serverModule("BatService")
local Bat = sharedModule("Config/Bat")
startServer()

local B = newPlayer("Bob") -- porteur
local C = newPlayer("Chloe") -- reprend
spawnCharacter(B, Vector3.new(85, 3, 10))
spawnCharacter(C, Vector3.new(110, 3, -10))
flush()
advance(0.5) -- rig de remplacement du vigile prêt

local ended = {}
Carry.OnCarryEnded(function(player, payload, result, reason)
	table.insert(ended, { player = player, payload = payload, result = result, reason = reason })
end)
local function lastEnded()
	return ended[#ended]
end
local function drop(player)
	fireAs(player, "DropCarried")
	flush()
end
local function lastDrop()
	local list = batDrops()
	local model = list[#list]
	local id = model and model:GetAttribute("DropId")
	local payload, position = Carry.GetDrop(id)
	return model, id, payload, position
end
local function grab(player, dropId, hold)
	fireAs(player, "GrabDropped", dropId)
	advance(hold)
	fireAs(player, "GrabDropped", dropId)
	flush()
end
local function lastChase(player)
	local list = remotes("ChaseState", function(e)
		return e.to == player
	end)
	return list[#list]
end
local uid = 0
local function npcItem()
	uid += 1
	return { Kind = "NPCItem", ItemId = "Z1_Donut", Rarity = "Common", Zone = 1, StoreId = "STORE_TEST", SlotId = `STORE_TEST/{uid}`, Luck = 1 }
end

section("S1 Refus sans portage")
clearLog()
drop(B)
check(#batDrops() == 0 and not Carry.IsCarrying(B), "S1a rien au sol, rien ne change")
check(logHas("ne porte rien", "WARN", "server"), "S1b refus noté : ne porte rien")

section("S2 Colis du rayon lâché : au sol sous le joueur, le vigile le suit")
breakStore(B, STORE_A)
advance(1.1)
local shelfStart = shelfCount(STORE_A)
check(grabShelf(B, STORE_A, fullSlot(STORE_A)), "S2a Bob prend un colis")
local box = Carry.GetPayload(B)
advance(0.2)
moveTo(B, Vector3.new(90, 3, 10))
check(#guards() == 1 and guards()[1]:GetAttribute("TargetUserId") == B.UserId, "S2b un vigile poursuit Bob")
local guard = guards()[1]
advance(0.3)
clearLog()
drop(B)
local model, id, payload, position = lastDrop()
check(not Carry.IsCarrying(B), "S2c Bob ne porte plus rien")
check(payload == box, "S2d le même colis est au sol (même table)")
check(position ~= nil and math.abs(position.X - 90) < 0.5 and math.abs(position.Z - 10) < 0.5 and math.abs(position.Y) < 0.1, `S2e au sol sous Bob ({position})`)
check(model and model:GetAttribute("BatDrop") == true and model:GetAttribute("Tier") == box.Tier, "S2f attributs BatDrop et Tier (invite de BatController)")
check(lastEnded() and lastEnded().result == "Dropped" and lastEnded().reason == "Released", "S2g OnCarryEnded « Dropped », raison « Released »")
check(guard:GetAttribute("TargetUserId") == 0 and lastChase(B).args[1] == false, "S2h le vigile lâche Bob (ChaseState false)")
check(logHas("est tombé au sol, il va vers lui", "PRINT", "server"), "S2i il va vers l'objet, comme après la batte")
check(Carry.IsFallenDrop(id), "S2j colis tombé des mains (GrabDropped accepté)")

section("S3 Reprise par une autre joueuse, puis par celui qui l'a lâché")
moveTo(C, Vector3.new(position.X + 2, 3, position.Z))
grab(C, id, Bat.DroppedGrabTime)
check(Carry.GetPayload(C) == box, "S3a Chloé le reprend, même payload")
check(guard:GetAttribute("TargetUserId") == C.UserId, "S3b le vigile la poursuit")
moveTo(C, Vector3.new(100, 3, 10))
advance(0.1)
drop(C)
model, id, payload, position = lastDrop()
check(payload == box and not Carry.IsCarrying(C), "S3c Chloé le lâche à son tour")
moveTo(B, Vector3.new(position.X - 2, 3, position.Z))
grab(B, id, Bat.DroppedGrabTime)
check(Carry.GetPayload(B) == box, "S3d Bob le reprend (aucun délai pour celui qui lâche)")
check(#census().duplicates == 0, "S3e aucun doublon")

section("S4 Personne ne le reprend : il revole vers son rayon")
advance(0.6)
drop(B)
model, id, payload, position = lastDrop()
check(payload == box, "S4a au sol")
advance(Bat.DroppedLifetime + 0.2)
check(Carry.GetDrop(id) == nil and isDestroyed(model), "S4b au bout de 15 s : retiré du sol")
advance(3)
check(shelfCount(STORE_A) == shelfStart and #census().duplicates == 0, `S4c revenu sur son rayon ({shelfCount(STORE_A)}/{shelfStart})`)

section("S5 Objet sorti d'un colis (NPCItem)")
local item = npcItem()
moveTo(B, Vector3.new(120, 3, 0))
check(Carry.StartCarry(B, item), "S5a Bob porte un objet NPCItem")
flush()
advance(0.6)
drop(B)
model, id, payload, position = lastDrop()
check(payload == item and model:GetAttribute("ItemId") == "Z1_Donut", "S5b l'objet est au sol (attribut ItemId)")
moveTo(C, Vector3.new(position.X + 2, 3, position.Z))
grab(C, id, Bat.DroppedGrabTime)
check(Carry.GetPayload(C) == item, "S5c Chloé le reprend")
Carry.Consume(C, "Test")
flush()

section("S6 Objet volé à un joueur (PlayerItem) : revient chez son propriétaire")
local stolen = { Kind = "PlayerItem", ItemUid = "uid-a113", ItemId = "Z1_Donut", Rarity = "Common", Income = 1, VictimUserId = C.UserId, SlotIndex = 1 }
check(Carry.StartCarry(B, stolen), "S6a Bob porte un objet volé")
flush()
advance(0.6)
local before = #batDrops()
drop(B)
check(not Carry.IsCarrying(B) and #batDrops() == before, "S6b rien ne tombe au sol")
check(lastEnded().payload == stolen and lastEnded().result == "Failed" and lastEnded().reason == "Released", "S6c OnCarryEnded « Failed », raison « Released » (PvPService le rend)")

section("S7 Refus : étourdi (capture, batte), trop rapproché, mort")
check(type(Guard.IsStunned) == "function" and Guard.IsStunned(B) == false, "S7a GuardService.IsStunned existe, Bob pas étourdi")
check(Carry.StartCarry(B, npcItem()), "S7b Bob porte un objet")
flush()
advance(0.6)
local realGuard, realBat = Guard.IsStunned, BatS.IsStunned
Guard.IsStunned = function()
	return true
end
clearLog()
drop(B)
check(Carry.IsCarrying(B) and logHas("étourdi par une capture", "WARN", "server"), "S7c étourdi par une capture : refusé")
Guard.IsStunned = realGuard
BatS.IsStunned = function()
	return true
end
advance(0.6)
clearLog()
drop(B)
check(Carry.IsCarrying(B) and logHas("coup de batte", "WARN", "server"), "S7d étourdi par la batte : refusé")
BatS.IsStunned = realBat
advance(1.1)
drop(B)
check(not Carry.IsCarrying(B), "S7e plus étourdi : accepté")
check(Carry.StartCarry(B, npcItem()), "S7f il reprend un objet")
flush()
clearLog()
drop(B)
check(Carry.IsCarrying(B) and logHas("trop rapproché", "WARN", "server"), "S7g aussitôt après un lâcher : refusé (0,5 s)")
advance(1.1)
humanoidOf(B).Health = 0
clearLog()
drop(B)
check(logHas("pas de personnage vivant", "WARN", "server"), "S7h personnage mort : refusé")

summary("scénario server")
