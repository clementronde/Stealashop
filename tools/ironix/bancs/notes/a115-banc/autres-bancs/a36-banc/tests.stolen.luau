--!nocheck
-- V. Objet volé à un joueur (6.1, 9.6), sanctions actives : téléport ou speed hack pendant la fuite →
-- l'objet revient sur son présentoir (PvPService, par CarryService.ReportAnomaly), le voleur revient
-- en arrière ; téléport droit dans sa propre DepositZone : AntiCheatService.Verify, appelé par
-- PvPService juste avant le dépôt, le voit avant le transfert (sans lui, le vol aurait réussi).

startServer()
setStrict(true)

-- Ada (boutique 1) expose 3 objets, le Pot de nouilles est à l'abri ; Bob (boutique 2) vole.
local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
addItem(adaData, "ada-noodles", "Z1_PotDeNouilles", 3)
local ada = join("Ada", adaData)
local bobData = newProfile()
bobData.Stats.Strength = 10000
local bob = join("Bob", bobData)
advance(1)
local adaShop, bobShop = shopOf(ada), shopOf(bob)
local items = 0
local function count()
	local n = 0
	for _, data in STORE do
		for _ in data.Items do
			n += 1
		end
	end
	return n
end
items = count()

section("V0 Arrivée")
check(adaShop == SHOPS[1].model and bobShop == SHOPS[2].model, "V0a boutiques 1 et 2")
check(strikes(ada) == 0 and strikes(bob) == 0, "V0b aucune détection à l'arrivée")

section("V1 Téléport pendant la fuite : l'objet revient sur son présentoir")
check(breakDoor(bob, adaShop), "V1a porte d'Ada cassée")
check(steal(bob, adaShop, 1), "V1b Bob porte la canette d'Ada")
check(Display.IsHeld(ada, "ada-soda"), "V1c présentoir 1 vidé (objet tenu)")
local from = rootOf(bob).Position
cheatTeleport(bob, Vector3.new(-150, 3, -100)) -- au milieu du hub, 230 studs plus loin
advance(0.4)
local d = lastDetection()
check(strikes(bob) == 1 and d.Kind == "Teleport" and d.Carrying, "V1d détection « Teleport » en portant")
check(not Carry.IsCarrying(bob), "V1e l'objet lui est retiré")
check(not Display.IsHeld(ada, "ada-soda") and adaData.Display["1"] == "ada-soda", "V1f la canette est revenue sur le présentoir 1 d'Ada")
check(adaData.Items["ada-soda"] ~= nil and bobData.Items["ada-soda"] == nil, "V1g toujours à Ada, jamais à Bob")
check(horizontal(rootOf(bob).Position, from) < 2, "V1h Bob revient à sa dernière position valide")
check(count() == items, "V1i aucun objet en plus ni en moins")

section("V2 Speed hack (× 2) pendant la fuite, par les portes : l'objet revient avant le dépôt")
check(steal(bob, adaShop, 1), "V2a Bob reprend la canette (porte toujours cassée)")
local s0 = strikes(bob)
check(near(humanoidOf(bob).WalkSpeed, 16, 1e-3), `V2b WalkSpeed avec l'objet volé : vitesse fixe 16 (lu {humanoidOf(bob).WalkSpeed})`)
route(bob, shopRoute(adaShop, bobShop))
setHack(bob, 2)
local caught = false
for _ = 1, 300 do
	advance(FRAME)
	if strikes(bob) > s0 or not Carry.IsCarrying(bob) then
		caught = strikes(bob) > s0
		break
	end
end
setHack(bob, 1)
stop(bob)
d = lastDetection()
check(caught and d.Kind == "Speed" and d.Carrying, "V2c détection « Speed » en portant, avant d'arriver chez lui")
check(not Carry.IsCarrying(bob) and not Display.IsHeld(ada, "ada-soda") and adaData.Display["1"] == "ada-soda", "V2d la canette est revenue sur son présentoir")
check(bobData.Items["ada-soda"] == nil and count() == items, "V2e rien n'a changé de propriétaire")

section("V2b Sprint (× 4) en ligne droite (noclip) dès la prise : vu au dépôt par le contrôle du trajet")
check(breakDoor(bob, adaShop), "V2f porte d'Ada recassée")
check(steal(bob, adaShop, 1), "V2f2 Bob reprend la canette")
s0 = strikes(bob)
walk(bob, SHOPS[2].S.center) -- à travers les murs (noclip), droit chez lui
setHack(bob, 4)
for _ = 1, 150 do
	advance(FRAME)
	if strikes(bob) > s0 or not Carry.IsCarrying(bob) then
		break
	end
end
setHack(bob, 1)
stop(bob)
d = lastDetection()
check(strikes(bob) == s0 + 1 and d.Kind == "Speed" and string.find(d.Detail, "trajet de", 1, true) ~= nil, `V2g détecté au dépôt par le trajet : {d and d.Detail}`)
check(not Carry.IsCarrying(bob) and adaData.Display["1"] == "ada-soda" and bobData.Items["ada-soda"] == nil, "V2h la canette est revenue chez Ada")

section("V3 Téléport dans sa propre DepositZone : vu par Verify avant le dépôt")
check(breakDoor(bob, adaShop), "V3a porte d'Ada recassée")
check(steal(bob, adaShop, 2), "V3b Bob porte les chips d'Ada")
advance(2) -- assez pour que le contrôle du dépôt de PvPService (65,6 studs/s au plus) laisse passer 100 studs
s0 = strikes(bob)
-- Juste après une vérification périodique (une toutes les 8 images) : la suivante viendrait trop tard,
-- PvPService (10 fois par seconde) voit le voleur dans sa DepositZone avant.
while FRAMES % 8 ~= 0 do
	advance(FRAME)
end
cheatTeleport(bob, SHOPS[2].S.center)
for _ = 1, 4 do
	advance(FRAME)
end
check(FRAMES % 8 ~= 0, "V3c (aucune vérification périodique depuis le téléport)")
d = lastDetection()
check(strikes(bob) == s0 + 1 and d.Kind == "Teleport", "V3d détecté au moment du dépôt (Verify)")
check(not Carry.IsCarrying(bob) and adaData.Display["2"] == "ada-chips" and not Display.IsHeld(ada, "ada-chips"), "V3e les chips sont revenues chez Ada")
check(bobData.Items["ada-chips"] == nil and bobData.Lifetime.Steals == 0, "V3f le vol n'a pas eu lieu (rien chez Bob, Steals = 0)")
check(adaShop:GetAttribute("Protection") == nil, "V3g Ada n'a pas l'immunité d'un vol subi")
check(logHas("[AntiCheatService] Bob : téléport", "WARN", "server"), "V3h ligne « téléport » dans la sortie")

section("V4 Contrôle : sans Verify, le même téléport aurait réussi le vol")
check(breakDoor(bob, adaShop), "V4a porte d'Ada recassée")
check(steal(bob, adaShop, 2), "V4b Bob reprend les chips")
advance(2)
local realVerify = AC.Verify
AC.Verify = function()
	return true
end
while FRAMES % 8 ~= 0 do
	advance(FRAME)
end
cheatTeleport(bob, SHOPS[2].S.center)
for _ = 1, 4 do
	advance(FRAME)
end
AC.Verify = realVerify
check(bobData.Items["ada-chips"] ~= nil and adaData.Items["ada-chips"] == nil, "V4c sans Verify : les chips sont passées chez Bob (le contrôle du dépôt de PvPService ne les a pas vues : 100 studs en 2,8 s)")
advance(0.5)
check(strikes(bob) >= s0 + 2, "V4d la vérification périodique voit bien le téléport, mais après le transfert")

summary("scénario stolen")
