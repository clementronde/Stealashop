--!nocheck
-- pc-reach (2026-11-14, Cantin) : portée souple au début et pendant le maintien, stricte à la fin.
-- Géométrie (buildStore du banc a30) : STORE_A, rayon à Z = 56, Y = 4 ; Bounds X 51..79, Z 32..58, Y 0..12.
-- Le joueur est placé à `d` studs devant l'emplacement, à sa hauteur (distance = d exactement).

startAll()
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
flush()
local GMAX = Balance.Heist.GrabMaxDistance
-- pc-cantin (2026-11-14) : plafond qui suit la vitesse, max(ReachToleranceMin, WalkSpeed × ReachToleranceSeconds).
local PAD, MIN, SEC = Balance.Heist.ReachLatencyPad, Balance.Heist.ReachToleranceMin, Balance.Heist.ReachToleranceSeconds
check(PAD == 0.8 and MIN == 8 and SEC == 0.8, "R0 valeurs V0 : ReachLatencyPad 0,8 s, ReachToleranceMin 8 studs, ReachToleranceSeconds 0,8 s")
check(Balance.Heist.ReachToleranceMax == nil, "R0 ReachToleranceMax n'existe plus")
local function capAt(ws)
	return math.max(MIN, ws * SEC)
end
check(math.abs(capAt(65) - 52) < 1e-9, "R0 plafond à 65 studs/s : 52 studs")
check(capAt(10) == 8 and math.abs(capAt(22) - 17.6) < 1e-9, "R0 plafond à 10 studs/s : 8 ; à 22 studs/s : 17,6 (22 × 0,8 > 8)")

-- WalkSpeed écrite sans signal (StatsService remet sinon la sienne) : c'est la valeur que lit le serveur.
local function setSpeed(p, ws)
	rawget(humanoidOf(p), "_props").WalkSpeed = ws
end
local function at(p, n, d)
	local pos = slotAttachment(STORE_A, n).WorldPosition
	moveTo(p, Vector3.new(pos.X, pos.Y, pos.Z - d), Vector3.new(0, 0, 1))
end
local function atPoint(p, v)
	moveTo(p, v, Vector3.new(0, 0, 1))
end
-- Débit du remote (5/s) : au moins 0,3 s entre deux appels du même joueur.
local lastCall = {}
local function spaced(p)
	local last = lastCall[p]
	if last and now() - last < 0.3 then
		advance(0.3 - (now() - last))
	end
	lastCall[p] = now()
end
-- Un colis fermé encore jamais utilisé par le scénario (un maintien laissé ouvert sur un colis ferait
-- d'un nouvel appel sur ce colis une « fin » de maintien).
local used = {}
local function closedSlot()
	for n = 1, 10 do
		local b = boxAt(STORE_A, n)
		if b and not isOpening(b) and not used[n] then
			used[n] = true
			return n, b
		end
	end
	return nil, nil
end
-- Deux appels OpenShelfBox : début depuis startPlace, maintien de GrabTime + 0,05 s sur place
-- (revérifications), fin depuis endPlace.
local function holdOpen(p, n, startPlace, endPlace)
	local box = boxAt(STORE_A, n)
	local slotId = box:GetAttribute("SlotId")
	startPlace()
	spaced(p)
	fireAs(p, "OpenShelfBox", slotId)
	flush()
	advance(Balance.Heist.BoxTiers[box:GetAttribute("Tier")].GrabTime + 0.05)
	endPlace()
	spaced(p)
	fireAs(p, "OpenShelfBox", slotId)
	flush()
	return isOpening(box), box
end
-- Refus notés (warn du serveur) dont le texte correspond au motif Lua `pattern`.
local function refusals(pattern)
	local c = 0
	for _, line in LOG do
		if line.kind == "WARN" and line.side == "server" and string.find(line.text, pattern) then
			c += 1
		end
	end
	return c
end

breakStore(A, STORE_A)
check(STORE_A:GetAttribute("HeistOpen") == true, "R0b magasin ouvert, Alice est le casseur")
setSpeed(A, 22)
PING[A] = 0.15
local pad = math.min(22 * (0.15 + PAD), capAt(22)) -- 22 × 0,95 = 20,9, plafonnée à 17,6 (plafond à 22 studs/s)
check(math.abs(pad - 17.6) < 1e-9, "R0c tolérance attendue à la marche 22 et au ping 0,15 s : plafonnée à 17,6 studs")

section("R1 début du maintien en courant, fin à portée stricte")
local n1 = closedSlot()
local ok1 = holdOpen(A, n1, function() at(A, n1, 12.6) end, function() at(A, n1, 7.9) end)
check(ok1, "R1a début à 12,6 studs (WalkSpeed 22, ping 0,15 s) accepté, fin à 7,9 studs : ouverture lancée")
check(refusals("trop loin") == 0, "R1b aucun refus « trop loin »")

section("R2 fin du maintien à 12,6 studs : refusée")
local n2 = closedSlot()
local ok2 = holdOpen(A, n2, function() at(A, n2, 12.6) end, function() at(A, n2, 12.6) end)
check(not ok2, "R2a début et fin à 12,6 studs : rien ne s'ouvre")
check(refusals("OpenShelfBox de Alice .*trop loin %(12%.6") == 1, "R2b un seul refus « trop loin (12.6 studs) », à la fin")

section("R3 au-delà de la tolérance dès le début : refusé")
-- Bounds ne laisse que 24 studs devant l'emplacement (en sortir baisse le rideau pour le joueur) : à 22 studs/s la
-- limite (8 + 17,6) est dehors, l'essai se fait donc à 10 studs/s (tolérance min(10 × 0,95, 8) = 8, limite 16).
setSpeed(A, 10)
local pad3 = math.min(10 * (0.15 + PAD), capAt(10))
local n3 = closedSlot()
local ok3 = holdOpen(A, n3, function() at(A, n3, GMAX + pad3 + 0.3) end, function() at(A, n3, 7.9) end)
setSpeed(A, 22)
check(not ok3, "R3a WalkSpeed 10 : début à " .. (GMAX + pad3 + 0.3) .. " studs refusé : la fin à 7,9 studs ne conclut rien (aucun maintien ouvert)")

section("R4 plafond qui suit la vitesse : max(ReachToleranceMin, WalkSpeed × ReachToleranceSeconds)")
-- Ping de 5 s : la tolérance touche le plafond. Bounds ne laisse que 24 studs devant l'emplacement (sortir de
-- Bounds baisse le rideau pour le joueur) : le plafond au-dessus de 8 se mesure à WalkSpeed 18 (plafond 14,4 ; limite 22,4).
-- Un seul appel refusé n'ouvre aucun maintien : le même colis sert ensuite au début accepté.
local function startRefused(p, n, d)
	local slotId = boxAt(STORE_A, n):GetAttribute("SlotId")
	local before = refusals("OpenShelfBox de " .. p.Name .. " .*trop loin")
	at(p, n, d)
	spaced(p)
	fireAs(p, "OpenShelfBox", slotId)
	flush()
	return refusals("OpenShelfBox de " .. p.Name .. " .*trop loin") == before + 1
end
PING[A] = 5
setSpeed(A, 10)
local n4 = closedSlot()
check(startRefused(A, n4, GMAX + 8 + 0.3), "R4a WalkSpeed 10 : plafond 8, début à 16,3 studs refusé")
check(holdOpen(A, n4, function() at(A, n4, GMAX + 8 - 0.3) end, function() at(A, n4, 7.9) end), "R4b WalkSpeed 10 : début à 15,7 studs accepté, fin à 7,9 : ouverture lancée")
setSpeed(A, 18)
advance(2) -- on laisse finir l'ouverture de R4b (sans cette attente, l'appel de R4c ne laissait aucun refus noté)
local n4c = closedSlot()
check(startRefused(A, n4c, GMAX + 14.4 + 0.3), "R4c WalkSpeed 18 : plafond 14,4, début à 22,7 studs refusé")
check(holdOpen(A, n4c, function() at(A, n4c, GMAX + 14.4 - 0.3) end, function() at(A, n4c, 7.9) end), "R4d WalkSpeed 18 : début à 22,1 studs accepté (plafond fixe de 8 : refusé), fin à 7,9 : ouverture lancée")
setSpeed(A, 22)
PING[A] = 0.15

section("R5 volume Bounds agrandi au début seulement")
-- Bob, qui n'est pas encore entré (un intrus qui ressort de Bounds est fermé dehors, règle (c) de l'en-tête).
setSpeed(B, 22)
PING[B] = 0.15
local n5 = closedSlot()
local p5 = slotAttachment(STORE_A, n5).WorldPosition
-- Point hors de Bounds (Z 58,5 : 0,5 stud derrière le fond du volume, Z 32..58), à 2,5 studs de l'emplacement.
local outside = Vector3.new(p5.X, p5.Y, 58.5)
check((outside - p5).Magnitude <= GMAX, "R5 (banc) le point dehors est à portée stricte de l'emplacement")
local beforeB = refusals("hors du volume Bounds")
local ok5 = holdOpen(B, n5, function() atPoint(B, outside) end, function() at(B, n5, 3) end)
check(ok5 and refusals("hors du volume Bounds") == beforeB, "R5a début juste hors de Bounds accepté, fin dedans : ouverture lancée")
local n5b = closedSlot()
local p5b = slotAttachment(STORE_A, n5b).WorldPosition
local ok5b = holdOpen(B, n5b, function() at(B, n5b, 3) end, function() atPoint(B, Vector3.new(p5b.X, p5b.Y, 58.5)) end)
check(not ok5b and refusals("hors du volume Bounds") == beforeB + 1, "R5b fin juste hors de Bounds : refusée")

section("R6 tricheur : les deux appels de loin")
local n6 = closedSlot()
local box6 = boxAt(STORE_A, n6)
local slot6 = box6:GetAttribute("SlotId")
at(A, n6, 15)
for _ = 1, 3 do
	spaced(A)
	fireAs(A, "OpenShelfBox", slot6)
	flush()
	advance(0.4)
end
check(not isOpening(box6), "R6a trois appels depuis 15 studs (WalkSpeed 22) : rien ne s'ouvre")
PING[A] = 5 -- ping énorme : plafond max(8, 22 × 0,8) = 17,6 studs
for _ = 1, 3 do
	spaced(A)
	fireAs(A, "OpenShelfBox", slot6)
	flush()
	advance(0.4)
end
check(not isOpening(box6), "R6b ping de 5 s, appels depuis 15 studs : un début accepté, aucune fin")
setSpeed(A, 10) -- limite 8 + 8 = 16 : reste dans Bounds (à 22 studs/s, 25,6 serait dehors)
at(A, n6, GMAX + capAt(10) + 1)
for _ = 1, 3 do
	spaced(A)
	fireAs(A, "OpenShelfBox", slot6)
	flush()
	advance(0.4)
end
check(not isOpening(box6), "R6c ping de 5 s, WalkSpeed 10, trois appels depuis 17 studs (plafond 8) : tous refusés")
setSpeed(A, 22)
PING[A] = 0.15

section("R7 à 65 studs/s (mesure du 14/11) : début en courant accepté, tricheur et fin lointaine refusés")
setSpeed(A, 65)
PING[A] = 0.05
-- Tolérance min(65 × 0,85, 52) = 52 studs : 15,7 studs (vu en Play) laisse bien plus de 5 studs de marge.
local n7 = closedSlot()
local before7 = refusals("OpenShelfBox de Alice .*trop loin")
check(holdOpen(A, n7, function() at(A, n7, 15.7) end, function() at(A, n7, 7.9) end), "R7a WalkSpeed 65 : début à 15,7 studs, fin à 7,9 : ouverture lancée")
check(refusals("OpenShelfBox de Alice .*trop loin") == before7, "R7b aucun refus « trop loin » pour cette ouverture")
local n7b, box7 = closedSlot()
check(n7b ~= nil, "R7 (banc) encore un colis fermé")
if n7b then
	check(not holdOpen(A, n7b, function() at(A, n7b, 15) end, function() at(A, n7b, 12.6) end), "R7c début à 15, fin à 12,6 studs : refusée (fin stricte)")
	check(refusals("OpenShelfBox de Alice .*trop loin %(12%.6") == 2, "R7d un refus « trop loin (12.6 studs) » de plus, à la fin")
	local slot7 = box7:GetAttribute("SlotId")
	at(A, n7b, 15)
	for _ = 1, 3 do
		spaced(A)
		fireAs(A, "OpenShelfBox", slot7)
		flush()
		advance(0.4)
	end
	check(not isOpening(box7), "R7e tricheur à 65 studs/s, trois appels depuis 15 studs : rien ne s'ouvre")
end
setSpeed(A, 22)

section("R8 GrabItem : même règle")
local maxLuck = 1
for _, e in SO.LuckTable do
	maxLuck = math.max(maxLuck, e.Luck)
end
advance(SOS.revealDelay(maxLuck) + 1) -- les objets ouverts plus haut sont sortis
local n8
for n = 1, 10 do
	if itemAt(STORE_A, n) then
		n8 = n
		break
	end
end
check(n8 ~= nil, "R8 (banc) un objet sorti sur le rayon")
local item8 = itemAt(STORE_A, n8)
local id8 = item8:GetAttribute("SlotId")
local gt8 = Balance.Heist.BoxTiers[item8:GetAttribute("Tier")].GrabTime
local function holdGrab(p, n, d1, d2, slotId, gt)
	at(p, n, d1)
	spaced(p)
	fireAs(p, "GrabItem", slotId)
	flush()
	advance(gt + 0.05)
	at(p, n, d2)
	spaced(p)
	fireAs(p, "GrabItem", slotId)
	flush()
	return Carry.IsCarrying(p)
end
check(not holdGrab(A, n8, 12.6, 12.6, id8, gt8), "R8a début et fin à 12,6 studs : objet pas pris")
check(itemAt(STORE_A, n8) == item8, "R8b l'objet reste sur le rayon")
check(not holdGrab(A, n8, 15, 15, id8, gt8), "R8c tricheur, les deux appels depuis 15 studs : objet pas pris")
local before8 = refusals("GrabItem de Alice .*trop loin")
check(holdGrab(A, n8, 12.6, 7.9, id8, gt8), "R8d début à 12,6 studs en courant, fin à 7,9 : objet pris")
check(refusals("GrabItem de Alice .*trop loin") == before8, "R8e aucun refus « trop loin » pour cette prise")

section("R9 GrabDropped (BatService) : même règle")
moveTo(A, Vector3.new(65, 3, 12)) -- dans le couloir, hors de la zone safe
check(Carry.Fail(A, "Caught") == true, "R9 (banc) Alice lâche l'objet")
flush()
local list = batDrops()
local model = list[#list]
local dropId = model and model:GetAttribute("DropId")
local _, dropPos = Carry.GetDrop(dropId)
check(dropPos ~= nil, "R9 (banc) objet au sol")
setSpeed(B, 22)
PING[B] = 0.15
local DMAX = BatCfg.DroppedGrabMaxDistance
local function holdDrop(d1, d2)
	moveTo(B, dropPos + Vector3.new(d1, 0, 0))
	spaced(B)
	fireAs(B, "GrabDropped", dropId)
	flush()
	advance(BatCfg.DroppedGrabTime + 0.05)
	moveTo(B, dropPos + Vector3.new(d2, 0, 0))
	spaced(B)
	fireAs(B, "GrabDropped", dropId)
	flush()
	return Carry.IsCarrying(B)
end
if dropPos then
	check(not holdDrop(DMAX + 4.6, DMAX + 4.6), "R9a début et fin à " .. (DMAX + 4.6) .. " studs : pas ramassé")
	check(not holdDrop(DMAX + pad + 0.5, DMAX - 0.1), "R9b début au-delà de la tolérance : pas ramassé")
	advance(BatCfg.DroppedGrabTime + 1.1) -- le maintien ouvert par la fin de R9b expire
	check(holdDrop(DMAX + 4.6, DMAX - 0.1), "R9c début à " .. (DMAX + 4.6) .. " studs en courant, fin à portée : ramassé")
end

check(logCount("tick :", "WARN", "server") == 0, "R10 aucune erreur du tick")
summary("scénario reach")
