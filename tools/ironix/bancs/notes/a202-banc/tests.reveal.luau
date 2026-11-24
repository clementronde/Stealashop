--!nocheck
-- a202 (vague 62, L-198) : un seul colis par braquage et cinématique d'ouverture (Features.SingleBoxReveal = true).
startAll(true)
local Features = sharedModule("Config/Features")
local Guard = serverModule("GuardService")
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(66, 3, 10))
flush()
local LMIN = luckValues()[1]
local R = SO.Reveal
local STREET = Vector3.new(65, 3, 12)

local function noGuard(p)
	return waitFor(function()
		return guardFor(p) == nil
	end, 60)
end
local function consume(p)
	Carry.Consume(p)
	flush()
	noGuard(p)
end

check(Features.SingleBoxReveal == true, "R0 Features.SingleBoxReveal = true")
check(R.RevealMaxSeconds.Small == 8 and R.RevealMaxSeconds.Large == 10 and R.RevealMaxSeconds.Colossal == 12 and R.CeilingRepairSeconds == 20, "R0 Config/ShelfOpen.Reveal : plafonds 8/10/12 s (client : 6/8/10), plafond réparé en 20 s")

section("R1 ouverture : contenu tiré tout de suite, RevealStarted à tous, ouvreur protégé et immobile")
reopen(A, STORE_A)
IW.kg, IW.scale, IW.size, IW.class = 12, 1.1, nil, "Small"
table.clear(IW.lucks)
local box1, ev = startReveal(A, STORE_A, 1, 3)
check(ev ~= nil and ev.to == nil, "R1 RevealStarted envoyé à tous (FireAll)")
local a = if ev then ev.args else {}
local id1 = a[10]
check(a[1] == A and type(a[2]) == "string", "R1 RevealStarted : ouvreur et magasin (" .. tostring(a[2]) .. ")")
check(a[3] == "ShelfSlot_01", "R1 RevealStarted : SlotName = ShelfSlot_01 (" .. tostring(a[3]) .. ")")
check(type(a[4]) == "string" and a[4] ~= "" and type(a[5]) == "string", "R1 RevealStarted : ItemId et Rarity (" .. tostring(a[4]) .. ", " .. tostring(a[5]) .. ")")
check(type(a[6]) == "string", "R1 RevealStarted : Mutation = effet ou chaîne vide")
check(a[7] == 12 and a[8] == 1.1 and a[9] == "Small", "R1 RevealStarted : Weight 12, Scale 1.1, SizeClass Small")
check(type(id1) == "string" and id1 ~= "", "R1 RevealStarted : RevealId (" .. tostring(id1) .. ")")
check(IW.lucks[1] == 3, "R1 ItemWeight.Roll reçoit la chance de la boîte (×3, reçu " .. tostring(IW.lucks[1]) .. ")")
local call = IW.calls[#IW.calls]
check(call ~= nil and call.freeHeight > 0 and call.modelHeight > 0, "R1 SizeClassFor : hauteur libre et hauteur du modèle")
check(box1 ~= nil and noShelfAttrs(box1), "R1 aucun attribut ShelfOpen* sur le colis (l'ouverture d'avant ne joue pas chez le client)")
check(itemAt(STORE_A, 1) == nil, "R1 aucun objet posé sur le rayon pendant la cinématique")
check(protected(A), "R1 Alice : RevealProtected")
check(humanoidOf(A).WalkSpeed == 0, "R1 Alice immobile (WalkSpeed " .. tostring(humanoidOf(A).WalkSpeed) .. ")")
local timers = remotes("HeistTimer", function(e)
	return e.to == A
end)
check(#timers > 0 and timers[#timers].args[2] == 0, "R1 chrono caché pour Alice (HeistTimer 0)")
check(not Carry.IsCarrying(A), "R1 Alice ne porte rien pendant la cinématique")

section("R2 un seul colis : un second refusé pendant la cinématique")
local box2 = openBox(A, STORE_A, 2, LMIN)
check(box2 ~= nil and box2:GetAttribute("ShelfOpenState") == nil, "R2 colis du rayon 2 pas ouvert")
check(#revealsOf(A) == 1, "R2 aucun second RevealStarted")
standAt(A, STORE_A, 1)

local function closed(store)
	return waitFor(function()
		return store:GetAttribute("HeistOpen") ~= true
	end, 60)
end
local function catchInStreet(p)
	moveTo(p, STREET)
	return waitFor(function()
		return not Carry.IsCarrying(p)
	end, 30)
end
local function lastDropOf()
	local list = batDrops()
	local m = list[#list]
	if m == nil then
		return nil, nil
	end
	local id = m:GetAttribute("DropId")
	return id, Carry.GetDrop(id)
end
local function grabDrop(p, id)
	local _, _, position = nil, Carry.GetDrop(id)
	fireAs(p, "GrabDropped", id)
	advance(BatCfg.DroppedGrabTime + 0.05)
	fireAs(p, "GrabDropped", id)
	flush()
	return Carry.IsCarrying(p)
end

section("R3 RevealDone : faux id et id d'un autre ignorés, puis fin")
revealDone(A, "R999")
revealDone(B, id1)
check(protected(A) and #endedFor(id1) == 0, "R3 faux id et id envoyé par Bob ignorés")
revealDone(A, id1)
local ended = endedFor(id1)
check(#ended == 1 and ended[1].to == nil, "R3 RevealEnded à tous")
check(not protected(A), "R3 protection levée")
check(humanoidOf(A).WalkSpeed > 0, "R3 Alice bouge de nouveau (" .. tostring(humanoidOf(A).WalkSpeed) .. ")")
check(Carry.IsCarrying(A), "R3 objet sur la tête d'Alice")
local payload = Carry.GetPayload(A)
check(payload ~= nil and payload.Weight == 12 and payload.ItemId == a[4] and payload.Rarity == a[5], "R3 payload : ItemId, Rarity, Weight 12")
check(boxAt(STORE_A, 1) == nil and itemAt(STORE_A, 1) == nil, "R3 colis retiré, rien sur le rayon")

section("R5 spam : RevealDone répété, un seul RevealEnded")
for _ = 1, 6 do
	fireAs(A, "RevealDone", id1)
end
flush()
check(#endedFor(id1) == 1, "R5 un seul RevealEnded (" .. #endedFor(id1) .. ")")

section("R6 capture dans la rue : l'objet tombe avec son poids, puis elle rouvre")
check(catchInStreet(A), "R6 (banc) Alice attrapée dans la rue")
local _, dropPayload = lastDropOf()
check(dropPayload ~= nil and dropPayload.Weight == 12, "R6 objet au sol avec Weight 12")
advance(Balance.Guard.CatchStunDuration + 0.5)
noGuard(A)
closed(STORE_A)
reopen(A, STORE_A)
-- R4 : un objet porté (ici un objet de joueur, sans vigile lié) bloque toute ouverture.
local before = #revealsOf(A)
check(Carry.StartCarry(A, { Kind = "PlayerItem", ItemUid = "u1", ItemId = a[4], Rarity = "Common", Income = 1, VictimUserId = B.UserId, SlotIndex = 1 }), "R4 (banc) Alice porte un objet")
local box3 = openBox(A, STORE_A, 3, LMIN)
check(Carry.IsCarrying(A), "R4 (banc) Alice porte encore")
check(#revealsOf(A) == before and box3 ~= nil and box3:GetAttribute("ShelfOpenState") == nil, "R4 mains pleines : colis du rayon 3 pas ouvert")
Carry.Consume(A)
flush()
local _, ev2 = startReveal(A, STORE_A, 3, LMIN)
check(ev2 ~= nil, "R6 après la perte, Alice rouvre un colis")
local id2 = if ev2 then ev2.args[10] else nil

section("R7 plafond de temps (Small 8 s)")
advance(7.5)
check(protected(A) and #endedFor(id2) == 0, "R7 encore en cinématique à 7,5 s")
advance(0.7)
check(#endedFor(id2) == 1 and Carry.IsCarrying(A), "R7 finie au plafond, objet porté")
consume(A)
check(not Carry.IsCarrying(A), "R7 (banc) objet rangé (Consume)")

section("R8 sortie du joueur pendant sa cinématique : objet sur le rayon, libre")
local C = player("Chloe", Vector3.new(62, 3, -10))
flush()
reopen(C, STORE_B)
local _, ev3 = startReveal(C, STORE_B, 1, LMIN)
check(ev3 ~= nil, "R8 (banc) Chloé ouvre")
local id3 = if ev3 then ev3.args[10] else nil
leave(C)
advance(0.2)
check(#endedFor(id3) == 1, "R8 RevealEnded")
local left = itemAt(STORE_B, 1)
check(left ~= nil and left:GetAttribute("Weight") == 12, "R8 objet posé sur le rayon, avec Weight")
check(left ~= nil and (left:GetAttribute("ShelfReservedUntil") or 0) <= Workspace:GetServerTimeNow() + 0.01, "R8 objet libre (pas réservé)")

section("R9 mort pendant la cinématique : objet sur le rayon, réservé à l'ouvreur")
local D = player("Dan", Vector3.new(63, 3, -10))
flush()
advance(1.1) -- avance du casseur (Chloé)
local _, ev4 = startReveal(D, STORE_B, 2, LMIN)
check(ev4 ~= nil, "R9 (banc) Dan ouvre")
local id4 = if ev4 then ev4.args[10] else nil
humanoidOf(D).Health = 0
advance(0.3)
check(#endedFor(id4) == 1 and not protected(D), "R9 RevealEnded, protection levée")
local dead = itemAt(STORE_B, 2)
check(dead ~= nil and dead:GetAttribute("ShelfReservedBy") == D.UserId and (dead:GetAttribute("ShelfReservedUntil") or 0) > Workspace:GetServerTimeNow(), "R9 objet réservé à Dan")

section("R10 tirage par la boîte seule : bonus des événements coupé")
Workspace:SetAttribute("LiveEventShelfLuck", 5)
table.clear(IW.lucks)
noGuard(A)
closed(STORE_A)
reopen(A, STORE_A)
local box5, ev5 = startReveal(A, STORE_A, 4, 2)
revealDone(A, if ev5 then ev5.args[10] else nil)
local p5 = Carry.GetPayload(A)
check(ev5 ~= nil and IW.lucks[1] == 2 and p5 ~= nil and p5.Luck == 2, "R10 chance = ×2 (celle de la boîte), LiveEventShelfLuck ignoré (" .. tostring(p5 and p5.Luck) .. ")")
Workspace:SetAttribute("LiveEventShelfLuck", nil)
consume(A)

section("R11 gros objet : plafond cassé, réparé 20 s après la fin")
IW.kg, IW.scale, IW.size, IW.class = 500, 3, "Huge", "Large"
closed(STORE_B)
reopen(B, STORE_B)
local _, ev6 = startReveal(B, STORE_B, 5, LMIN)
check(ev6 ~= nil and ev6.args[9] == "Large" and ev6.args[7] == 500 and ev6.args[8] == 3, "R11 RevealStarted : Large, 500 kg, taille ×3")
check(STORE_B:GetAttribute("CeilingBroken") == true, "R11 CeilingBroken = true")
advance(9.5)
check(protected(B), "R11 plafond Large : encore en cinématique à 9,5 s")
advance(0.7)
check(not protected(B) and Carry.IsCarrying(B), "R11 finie à 10 s, objet porté")
local p6 = Carry.GetPayload(B)
check(p6 ~= nil and p6.Weight == 500 and p6.Mutation ~= nil and p6.Mutation.Size == "Huge", "R11 payload : 500 kg, mutation de taille Huge")
Carry.Consume(B)
flush()
advance(R.CeilingRepairSeconds - 1)
check(STORE_B:GetAttribute("CeilingBroken") == true, "R11 plafond encore cassé avant 20 s")
advance(1.5)
check(STORE_B:GetAttribute("CeilingBroken") == false, "R11 plafond réparé après 20 s")

section("R12 trois captures : retour au rayon, avec son poids")
noGuard(A)
closed(STORE_A)
reopen(A, STORE_A)
local _, ev7 = startReveal(A, STORE_A, 6, LMIN)
revealDone(A, if ev7 then ev7.args[10] else nil)
check(Carry.IsCarrying(A), "R12 (banc) Alice porte l'objet de 500 kg")
for n = 1, 3 do
	check(catchInStreet(A), "R12 (banc) capture " .. n)
	advance(Balance.Guard.CatchStunDuration + 0.2)
	if n < 3 then
		local id, dp = lastDropOf()
		check(dp ~= nil and dp.Weight == 500, "R12 au sol après la capture " .. n .. ", Weight 500")
		check(id ~= nil and grabDrop(A, id), "R12 (banc) Alice reprend l'objet au sol")
	end
end
check(waitFor(function()
	local it = itemAt(STORE_A, 6)
	return it ~= nil and it:GetAttribute("Weight") == 500
end, 10), "R12 après la 3e capture, l'objet revient sur le rayon 6 avec Weight 500")

summary("scénario reveal")
