--!nocheck
-- a116 (2026-11-13, Cantin) : ouvrir un colis du rayon en RESTANT APPUYÉ sur E. Deux appels OpenShelfBox(slotId)
-- (début puis fin du maintien), temps écoulé vérifié par le serveur : GrabTime du type du colis
-- (Balance.Heist.BoxTiers), même tolérance que GrabItem (0,1 s). Un seul appel ne lance rien.

startAll()
local A = player("Alice", Vector3.new(60, 3, 10))
flush()
local TOL = 0.1
local function grabTimeOf(tier)
	return Balance.Heist.BoxTiers[tier].GrabTime
end
-- Premier rayon dont le colis fermé (pas en cours d'ouverture) est du type `tier`.
local function slotOfTier(store, tier)
	for n = 1, 10 do
		local b = boxAt(store, n)
		if b and b:GetAttribute("Tier") == tier and not isOpening(b) then
			return n, b
		end
	end
	return nil, nil
end
local function call(p, box)
	fireAs(p, "OpenShelfBox", box:GetAttribute("SlotId"))
	flush()
end

breakStore(A, STORE_A)
check(STORE_A:GetAttribute("HeistOpen") == true, "H0 magasin ouvert, Alice est le casseur")

section("H1 un appui seul est refusé")
local n1, box1 = slotOfTier(STORE_A, "Standard")
standAt(A, STORE_A, n1)
call(A, box1)
check(not isOpening(box1), "H1a un seul appel OpenShelfBox : rien ne s'ouvre")
advance(grabTimeOf("Standard") + 1.2) -- au-delà de GrabTime + HOLD_EXPIRY : le maintien a expiré
check(not isOpening(box1), "H1b toujours fermé après l'expiration du maintien")
call(A, box1)
check(not isOpening(box1), "H1c un appel après l'expiration recommence un maintien, il ne lance rien")
advance(grabTimeOf("Standard") + 1.2)

section("H2 maintien trop court refusé, maintien suffisant accepté, pour chaque type")
for _, tier in { "Standard", "Premium", "Luxe" } do
	local required = grabTimeOf(tier)
	local n, box = slotOfTier(STORE_A, tier)
	check(box ~= nil, "H2 " .. tier .. " : un colis de ce type sur le rayon")
	advance(1.05) -- débit du remote (5/s) : les appels du type précédent sont sortis de la fenêtre
	if box then
		standAt(A, STORE_A, n)
		call(A, box)
		local short = math.max(required - TOL - 0.08, 0.05)
		advance(short)
		call(A, box)
		check(not isOpening(box), "H2a " .. tier .. " : maintien de " .. short .. " s sur " .. required .. " s refusé")
		advance(required - short + 0.02)
		call(A, box)
		check(isOpening(box), "H2b " .. tier .. " : maintien de " .. (required + 0.02) .. " s accepté, ouverture lancée")
		check(box:GetAttribute("ShelfOpenBy") == A.UserId, "H2c " .. tier .. " : ShelfOpenBy = Alice")
	end
end

section("H3 même tolérance que la prise")
advance(1.05)
local n3, box3 = slotOfTier(STORE_A, "Standard")
standAt(A, STORE_A, n3)
call(A, box3)
advance(grabTimeOf("Standard") - TOL + 0.02)
call(A, box3)
check(isOpening(box3), "H3a maintien de GrabTime − 0,1 s (+ 0,02) accepté")

section("H4 un maintien sur un autre colis remplace le premier")
advance(1.05)
local n5, box5 = slotOfTier(STORE_A, "Standard")
local n6, box6 = nil, nil
for n = 1, 10 do
	local b = boxAt(STORE_A, n)
	if b and b ~= box5 and not isOpening(b) then
		n6, box6 = n, b
	end
end
check(box5 ~= nil and box6 ~= nil, "H4 deux colis encore fermés")
if box5 and box6 then
	standAt(A, STORE_A, n5)
	call(A, box5)
	advance(0.3)
	standAt(A, STORE_A, n6)
	call(A, box6)
	advance(0.05)
	standAt(A, STORE_A, n5)
	call(A, box5)
	check(not isOpening(box5), "H4a fin sur le premier colis après un début sur un autre : rien ne s'ouvre")
end
check(logCount("tick :", "WARN", "server") == 0, "H5 aucune erreur du tick")

summary("scénario hold")
