-- Vague 40 (2026-11-14, fusion, chrono de police à 8 s) : C1 borne le chrono du vigile par max(BreakTimer, Heist.Duration) (13 dans le faux arbre, heist-13s.luau) au lieu de BreakTimer seul ; ancien fichier : tests.close.avant-vague40.luau.
--!nocheck
-- C. Règle du braquage de Clément (L-118 points 8 et 9, 2026-11-13 ; réécrit ce jour) : chrono du vigile lancé
-- au premier coup ; à sa fin, un vigile sort pour chaque intrus et personne n'est sorti du magasin ; un joueur
-- qui n'y était pas n'entre plus ; en sortant, le magasin se ferme pour soi ; vide, il se ferme et le rideau
-- tombe ; l'objet non pris reste sur son rayon ; RefillAll attend la fermeture (sans WitnessService).

startAll(true)
local A = player("Alice", Vector3.new(60, 3, 10))
local B = player("Bob", Vector3.new(65, 3, 10))
local C = player("Chloe", Vector3.new(70, 3, 10))
flush()
local lucks = luckValues()
local LMIN, LMAX = lucks[1], lucks[#lucks]
local shutter = STORE_A:FindFirstChild("Shutter")
local shutterOpenY = shutter.Position.Y
local function shutterDown()
	return shutter.Position.Y < shutterOpenY - 5
end
local function insideStore(p)
	return rootOf(p).Position.Z > 32
end
local function chronoEnd()
	return STORE_A:GetAttribute("HeistEndsAt") - SERVER_TIME_OFFSET
end
local function closedFor(p)
	local closed = p:GetAttribute("ClosedStores")
	return type(closed) == "string" and string.find(closed, STORE_A.Name, 1, true) ~= nil
end
local function waitGuards()
	for _ = 1, 120 do
		if #guards() == 0 then
			break
		end
		advance(0.5)
	end
end
check(Heist ~= nil and logCount("tick :", "WARN", "server") == 0, "C0 sans WitnessService : le service démarre")

section("C1 fin du chrono du vigile")
breakStore(A, STORE_A)
local ends = chronoEnd()
check(ends > now() + 1 and ends <= now() + math.max(Balance.Window.BreakTimer, Balance.Heist.Duration) + 0.1, "C1 (banc) chrono du vigile en cours (" .. math.round((ends - now()) * 10) / 10 .. " s)")
local boxA = openBox(A, STORE_A, 1, LMAX)
check(isOpening(boxA), "C1 (banc) Alice ouvre à ×" .. LMAX .. " (sans témoins)")
standAt(B, STORE_A, 5)
advance(ends - now() + 0.2)
check(STORE_A:GetAttribute("HeistOpen") == true, "C1a fin du chrono : magasin encore ouvert (des intrus y sont)")
check(insideStore(A) and insideStore(B), "C1b personne n'est sorti du magasin")
check(guardFor(A) ~= nil and guardFor(B) ~= nil and #guards() == 2, "C1c un vigile sort pour chaque intrus")
standAt(C, STORE_A, 6)
advance(0.2)
check(not insideStore(C), "C1d après le chrono, un joueur qui n'y était pas n'entre plus")
local box2 = openBox(A, STORE_A, 2, LMIN)
check(isOpening(box2), "C1e après le chrono, un intrus ouvre encore")

section("C2 sortir ferme le magasin pour soi ; vide, il se ferme")
moveTo(B, Vector3.new(65, 3, 12))
advance(0.2)
-- ClosedStores peut attendre qu'aucun vigile ne soit dans le magasin (rideau local retenu, a70) : on lit la sortie.
check(logCount("Bob sorti de " .. STORE_A.Name .. " : rideau baissé pour lui", "PRINT", "server") == 1, "C2a Bob sorti : magasin fermé pour lui")
standAt(B, STORE_A, 5)
advance(0.2)
check(not insideStore(B), "C2b il revient : ressorti devant la vitrine")
moveTo(A, Vector3.new(60, 3, 12))
advance(SOS.revealDelay(LMIN) + SO.ReserveTime + 0.5)
check(STORE_A:GetAttribute("HeistOpen") == false, "C2c plus personne dedans, ouvertures finies : magasin fermé")
check(logCount("Alice sorti de " .. STORE_A.Name .. " : rideau baissé pour lui", "PRINT", "server") == 1, "C2d fermé aussi pour Alice")
waitGuards()
advance(1)
check(shutterDown(), "C2e vigiles sortis : le rideau tombe")

section("C3 objet sorti non pris")
advance(25)
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
check(not closedFor(A) and not closedFor(B), "C3 (banc) réouverture : plus fermé pour personne")
breakStore(B, STORE_A)
ends = chronoEnd()
openBox(B, STORE_A, 3, LMIN)
advance(SOS.revealDelay(LMIN) + 0.1)
local item3 = itemAt(STORE_A, 3)
check(item3 ~= nil, "C3 (banc) l'objet de Bob est sorti")
moveTo(B, Vector3.new(65, 3, 12)) -- il part sans le prendre
advance(math.max(ends, now() + SO.ReserveTime) - now() + 0.5)
check(STORE_A:GetAttribute("HeistOpen") == false, "C3a chrono fini, personne dedans : magasin fermé")
waitGuards()
advance(1)
check(shutterDown(), "C3b le rideau tombe")
check(itemAt(STORE_A, 3) == item3, "C3c l'objet non pris reste sur son rayon")
advance(25)
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
check(itemAt(STORE_A, 3) == item3, "C3d toujours là quand le magasin se reconstruit")
breakStore(C, STORE_A)
check(takeItem(C, STORE_A, 3), "C3e au braquage suivant, n'importe qui le prend (le casseur d'abord)")
Carry.Consume(C)
flush()

section("C4 nuit (RefillAll) pendant une ouverture")
moveTo(C, Vector3.new(70, 3, 12))
advance(chronoEnd() - now() + 0.5)
waitGuards()
advance(25)
WindowS.Rebuild(STORE_A:FindFirstChild("Window"):GetAttribute("WindowId"))
flush()
breakStore(A, STORE_A)
ends = chronoEnd()
local box4 = openBox(A, STORE_A, 4, LMAX)
local reveal4 = box4:GetAttribute("ShelfRevealAt") - SERVER_TIME_OFFSET
local before = {}
for _, m in shelfBoxes(STORE_A) do
	before[m] = true
end
Heist.RefillAll()
flush()
local same = true
for _, m in shelfBoxes(STORE_A) do
	if not before[m] then
		same = false
	end
end
check(same and isOpening(box4), "C4a RefillAll pendant l'ouverture : les rayons de ce magasin ne changent pas")
check(boxCount(STORE_B) == 10, "C4b l'autre magasin est rempli tout de suite")
advance(reveal4 - now() + 0.1)
local item4 = itemAt(STORE_A, 4)
check(item4 ~= nil, "C4c l'ouverture va au bout")
moveTo(A, Vector3.new(60, 3, 12)) -- elle part sans le prendre
advance(math.max(ends, reveal4 + SO.ReserveTime) - now() + 0.5)
check(boxCount(STORE_A) == 10 and itemCount(STORE_A) == 0, "C4d magasin fermé : rayons remplis (10 colis neufs, aucun objet sorti)")
check(isDestroyed(item4), "C4e l'objet non pris a été retiré")
check(logCount("tick :", "WARN", "server") == 0, "C5 aucune erreur du tick")

summary("scénario close")
