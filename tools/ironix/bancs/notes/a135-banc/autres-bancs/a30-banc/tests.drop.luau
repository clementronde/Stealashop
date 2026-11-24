--!nocheck
-- D. Le colis tombé au sol (6.2), à 3 joueurs : ramassage par un troisième joueur, même contenu,
-- le frappeur sans priorité, refus (maintien trop court, trop loin, mains pleines, étourdi, zone
-- safe, maintien interrompu), retour sur son rayon d'origine au bout de 15 s, nuit (rayons remplis :
-- il ne revient pas), colis du camion (laissés à TruckEventService).

local Carry = serverModule("CarryService")
local Heist = serverModule("StoreHeistService")
local Window = serverModule("WindowService")
local Bat = sharedModule("Config/Bat")
local Balance = sharedModule("Config/Balance")
startServer()

local A = newPlayer("Alice") -- frappeuse
local B = newPlayer("Bob") -- casseur et porteur
local C = newPlayer("Chloe") -- troisième joueuse
spawnCharacter(A, Vector3.new(80, 3, 0), Vector3.new(1, 0, 0))
spawnCharacter(B, Vector3.new(85, 3, 10))
spawnCharacter(C, Vector3.new(110, 3, 10))
flush()
equipBat(A)
local grabbedFrom = {}
Heist.OnBoxGrabbed(function(player, payload)
	grabbedFrom[payload] = player
end)
local function swing(player)
	fireAs(player, "SwingBat")
	flush()
end
-- Maintien complet : début, attente `hold` s, fin.
local function grab(player, dropId, hold)
	fireAs(player, "GrabDropped", dropId)
	advance(hold)
	fireAs(player, "GrabDropped", dropId)
	flush()
end
-- Le dernier colis tombé après un coup de batte : modèle, id, payload, position.
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
-- Debout à `distance` studs (à l'horizontale) du colis, HumanoidRootPart à 3 studs du sol.
local function standNear(player, position, distance)
	moveTo(player, Vector3.new(position.X + distance, 3, position.Z))
end
-- Magasin ouvert : sinon fin du chrono, vitrine reconstruite et cassée de nouveau par Bob.
local Window = serverModule("WindowService")
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
	advance(1.1) -- fin de l'avance du casseur
end
-- Bob prend un colis du rayon `slot` de STORE_A, sort du magasin et s'arrête en `at` ; Alice le
-- frappe de 5 studs. Renvoie le colis tombé.
local lastHitOnB = -math.huge
local function hitCarrier(slot, at, fromSide)
	if now() - lastHitOnB < Bat.HitImmunity + 0.05 then
		advance(Bat.HitImmunity + 0.05 - (now() - lastHitOnB))
	end
	ensureOpen(STORE_A)
	slot = slot or fullSlot(STORE_A)
	assert(grabShelf(B, STORE_A, slot), "prise refusée")
	local payload = Carry.GetPayload(B)
	moveTo(B, at)
	local side = fromSide or -1 -- Alice à 5 studs, côté −X par défaut
	moveTo(A, at + Vector3.new(5 * side, 0, 0), Vector3.new(-side, 0, 0))
	equipBat(A)
	advance(0.85) -- recharge de la frappeuse
	swing(A)
	assert(not Carry.IsCarrying(B), "coup raté")
	lastHitOnB = now()
	return payload
end

section("D1 Un troisième joueur ramasse le colis : même contenu")
breakStore(B, STORE_A)
advance(1.1) -- fin de l'avance du casseur
local shelfStart = shelfCount(STORE_A)
check(shelfStart == 10, "D1a 10 colis sur les rayons de STORE_A")
local slot = fullSlot(STORE_A)
local original = hitCarrier(slot, Vector3.new(85, 3, 0))
local model, id, payload, position = lastDrop()
check(payload == original and grabbedFrom[original] == B, "D1b au sol : le colis pris sur le rayon par Bob (même table)")
check(shelfCount(STORE_A) == shelfStart - 1, "D1c le rayon reste vide tant que le colis est sorti")
standNear(C, position, 3)
standNear(A, position, -3)
fireAs(C, "GrabDropped", id)
fireAs(A, "GrabDropped", id)
advance(Bat.DroppedGrabTime)
fireAs(C, "GrabDropped", id)
flush()
fireAs(A, "GrabDropped", id)
flush()
check(Carry.GetPayload(C) == original, "D1d Chloé tient 0,5 s : elle le porte, même payload")
check(Carry.GetPayload(C).Rarity == original.Rarity and Carry.GetPayload(C).ItemId == original.ItemId, "D1e même rareté, même objet caché")
check(not Carry.IsCarrying(A), "D1f la frappeuse, qui tenait en même temps, n'a rien : aucune priorité")
check(Carry.GetDrop(id) == nil and isDestroyed(model), "D1g plus au sol")
check(#census().duplicates == 0, "D1h aucun doublon")
Carry.Consume(C, "Test")
CONSUMED[original] = true
flush()
check(shelfCount(STORE_A) == shelfStart - 1, "D1i posé sur un établi : il ne revient jamais")

section("D2 Refus")
advance(1)
local second = hitCarrier(nil, Vector3.new(90, 3, -5))
model, id, payload, position = lastDrop()
check(payload == second, "D2a nouveau colis au sol")
-- Bob, frappé et étourdi, essaie de reprendre son colis tout de suite.
standNear(B, position, 2)
clearLog()
grab(B, id, 0.6)
check(not Carry.IsCarrying(B) and logHas("étourdi"), "D2b le porteur frappé, étourdi : refusé")
advance(1.1)
standNear(C, position, 3)
clearLog()
grab(C, id, 0.3)
check(not Carry.IsCarrying(C) and logHas("maintien trop court"), "D2c tenu 0,3 s : refusé (0,5 s)")
advance(1.6) -- le maintien trop court expire
standNear(C, position, 7.6) -- 8,2 studs du point du sol (HumanoidRootPart à 3 studs au-dessus)
clearLog()
grab(C, id, 0.6)
check(not Carry.IsCarrying(C) and logHas("trop loin"), "D2d à 8,2 studs : refusé")
-- Maintien interrompu : elle s'éloigne pendant le maintien.
advance(1.1)
standNear(C, position, 3)
fireAs(C, "GrabDropped", id)
advance(0.2)
standNear(C, position, 20)
advance(0.2)
standNear(C, position, 3)
advance(0.2)
fireAs(C, "GrabDropped", id)
flush()
check(not Carry.IsCarrying(C), "D2e partie à 20 studs pendant le maintien : annulé")
-- Mains pleines.
advance(1.1)
local Gb = { Kind = "NPCBox", Tier = "Standard", Zone = 1, Rarity = "Common", ItemId = "Z1_Donut", StoreId = "STORE_TEST", SlotId = "STORE_TEST/1" }
Carry.StartCarry(C, Gb)
flush()
clearLog()
grab(C, id, 0.6)
check(Carry.GetPayload(C) == Gb and logHas("mains pleines"), "D2f mains pleines : refusé")
Carry.Consume(C, "Test")
flush()
advance(1.1)
-- Bob, plus étourdi, le reprend : n'importe qui, le porteur d'avant compris.
standNear(B, position, 2)
grab(B, id, 0.55)
check(Carry.GetPayload(B) == second, "D2g Bob, plus étourdi, reprend son colis")
moveTo(B, Vector3.new(-40, 3, 0)) -- zone safe : le vigile abandonne
flush()
Carry.Consume(B, "Test")
CONSUMED[second] = true
flush()
-- Zone safe : un colis tombé au bord de la zone safe (elle finit en x = 25) ; Alice frappe du côté
-- du couloir.
advance(3.2)
local third = hitCarrier(nil, Vector3.new(27, 3, 0), 1)
model, id, payload, position = lastDrop()
moveTo(C, Vector3.new(23, 3, 0)) -- en zone safe, à 4 studs du colis
clearLog()
grab(C, id, 0.6)
check(not Carry.IsCarrying(C) and logHas("en zone safe"), "D2h ramasseuse en zone safe : refusé")
moveTo(C, Vector3.new(29, 3, 0))
advance(1.1)
grab(C, id, 0.55)
check(Carry.GetPayload(C) == third, "D2i hors zone safe, à 2 studs : ramassé")
Carry.Consume(C, "Test")
CONSUMED[third] = true
flush()

section("D3 Pas ramassé en 15 s : il retourne sur son rayon d'origine")
advance(3.2)
local slotNumber = fullSlot(STORE_A)
local slotName = string.format("ShelfSlot_%02d", slotNumber)
local fourth = hitCarrier(slotNumber, Vector3.new(95, 3, 5))
model, id, payload, position = lastDrop()
local count = shelfCount(STORE_A)
local droppedAt = now()
advance(Bat.DroppedLifetime - 0.2)
check(Carry.GetDrop(id) == payload and not isDestroyed(model), "D3a 14,8 s : toujours au sol")
local returned
local function shelfBoxAt(name)
	for _, b in shelfBoxes(STORE_A) do
		if b:GetAttribute("Slot") == name then
			return b
		end
	end
	return nil
end
advance(0.25)
returned = shelfBoxAt(slotName)
check(Carry.GetDrop(id) == nil and isDestroyed(model), `D3b {string.format("%.2f", now() - droppedAt)} s : plus au sol`)
check(returned ~= nil and shelfCount(STORE_A) == count + 1, `D3c revenu sur son emplacement d'origine ({slotName})`)
check(returned and returned:GetAttribute("Landed") == false, "D3d en vol vers le rayon")
advance(2)
check(returned and returned:GetAttribute("Landed") == true, "D3e posé sur le rayon")
local rarityText = returned and returned:FindFirstChild("Rarity", true)
check(rarityText and rarityText.Text == sharedModule("Config/Rarities").ById[fourth.Rarity].DisplayNameUpper, "D3f même rareté affichée sur le rayon")
check(#census().duplicates == 0 and #census().ground == 0, "D3g aucun doublon, rien au sol")
-- Le même colis, repris : même contenu (le contenu ne change pas, 6.2).
ensureOpen(STORE_A)
assert(grabShelf(B, STORE_A, slotNumber), "reprise refusée")
local again = Carry.GetPayload(B)
check(again ~= fourth and again.SlotId == fourth.SlotId and again.ItemId == fourth.ItemId and again.Rarity == fourth.Rarity, "D3h repris sur le rayon : même objet caché, même rareté")
moveTo(B, Vector3.new(-40, 3, 0))
flush()
Carry.Consume(B, "Test")
CONSUMED[again] = true
flush()

section("D4 Nuit : rayons remplis pendant qu'il est au sol, il ne revient pas")
advance(1)
local fifth = hitCarrier(nil, Vector3.new(100, 3, 5))
model, id, payload, position = lastDrop()
advance(11) -- fin du chrono : le magasin ferme (sinon le remplissage attend sa fermeture)
check(STORE_A:GetAttribute("HeistOpen") == false, "D4a magasin fermé")
Heist.RefillAll()
flush()
check(shelfCount(STORE_A) == 10, "D4b tombée de la nuit : 10 colis neufs")
clearLog()
advance(Bat.DroppedLifetime)
check(Carry.GetDrop(id) == nil and shelfCount(STORE_A) == 10, "D4c resté au sol : il disparaît, toujours 10 colis (pas de doublon)")
check(logHas("magasin rempli depuis", "PRINT", "server"), "D4d « ne revient pas (magasin rempli depuis) »")

section("D5 Colis du camion")
local Truck = serverModule("TruckEventService")
Workspace:SetAttribute("TruckSpawnNow", 1)
flush()
Workspace:SetAttribute("TruckSpawnNow", "Explode")
flush()
advance(2) -- tous atterris
local truckBoxes = {}
for _, child in dropsFolder():GetChildren() do
	if child:GetAttribute("TruckBox") == true then
		table.insert(truckBoxes, child)
	end
end
check(#truckBoxes == 12, "D5a 12 colis du camion au sol")
local tb = truckBoxes[1]
local tbId = tb:GetAttribute("DropId")
local tbPayload, tbPosition = Carry.GetDrop(tbId)
local tier = tb:GetAttribute("Tier")
standNear(C, tbPosition, 2)
clearLog()
grab(C, tbId, Balance.Heist.BoxTiers[tier].GrabTime)
check(Carry.GetPayload(C) == tbPayload, `D5b colis {tier} du camion ramassé par TruckEventService (maintien de son type)`)
check(not logHas("[BatService]"), "D5c BatService ne s'en mêle pas")
check(tb:GetAttribute("BatDrop") == nil, "D5d un colis du camion n'est pas marqué BatDrop")
-- Chloé, qui porte un colis du camion, est frappée : il tombe, c'est maintenant un colis de batte.
moveTo(C, Vector3.new(120, 3, 5))
moveTo(A, Vector3.new(115, 3, 5), Vector3.new(1, 0, 0))
advance(3.2)
equipBat(A)
swing(A)
model, id, payload, position = lastDrop()
check(payload == tbPayload and model:GetAttribute("BatDrop") == true and model:GetAttribute("TruckBox") == nil, "D5e tombé : colis de batte (BatDrop), même payload")
check(#guards() == 0 or guardFor(C) == nil, "D5f aucun vigile pour un colis du camion")
standNear(B, position, 2)
advance(2.1)
grab(B, id, Bat.DroppedGrabTime)
check(Carry.GetPayload(B) == tbPayload, "D5g ramassé par Bob en 0,5 s (le temps du colis tombé, quel que soit son type)")
-- Un autre colis du camion, porté, frappé, jamais ramassé : il disparaît (pas de rayon).
Carry.Consume(B, "Test")
flush()
local tb2 = truckBoxes[2]
local tb2Id = tb2:GetAttribute("DropId")
local tb2Payload, tb2Position = Carry.GetDrop(tb2Id)
standNear(C, tb2Position, 2)
advance(2.1)
grab(C, tb2Id, Balance.Heist.BoxTiers[tb2:GetAttribute("Tier")].GrabTime)
check(Carry.GetPayload(C) == tb2Payload, "D5h Chloé porte un second colis du camion")
moveTo(C, Vector3.new(130, 3, -5))
moveTo(A, Vector3.new(125, 3, -5), Vector3.new(1, 0, 0))
advance(3.2)
swing(A)
model, id, payload, position = lastDrop()
local shelves = shelfCount(STORE_A) + shelfCount(STORE_B)
advance(Bat.DroppedLifetime + 0.2)
check(Carry.GetDrop(id) == nil and shelfCount(STORE_A) + shelfCount(STORE_B) == shelves, "D5i resté 15 s au sol : il disparaît, aucun rayon ne le reçoit")
check(#census().duplicates == 0, "D5j aucun doublon")

summary("scénario drop")
