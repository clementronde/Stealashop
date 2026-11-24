--!nocheck
-- a426 (L-319) : Features.SafeZoneSpeed allumé. Zone safe du harnais : x de −425 à 25 (boutiques et hub) ; dehors : la rue
-- (x > 25). Sanctions de l'anti-triche actives : entrer et sortir de la zone, seul ou en portant, ne fait aucune détection.

startServer()
setStrict(true)
local Balance = sharedModule("Config/Balance")
local Features = sharedModule("Config/Features")
local SZ = Balance.SafeZoneSpeed
local MAX = Balance.Stats.MaxWalkSpeed * Balance.Stats.RealSpeedScale
local SAFE = SZ.WalkSpeed
local SAFE_STOLEN = SZ.WalkSpeed * SZ.StolenItemMultiplier
local STOLEN = Balance.Carry.StolenItemWalkSpeed
local NEWBIE = Balance.Stats.BaseWalkSpeed * Balance.Stats.RealSpeedScale
local ROAD_POINT = Vector3.new(40, 3, 0) -- dans la rue, hors de la zone
local function speedOf(player)
	return humanoidOf(player).WalkSpeed
end
local function wait(seconds)
	advance(seconds or 0.6)
end

section("Z0 Réglages")
check(Features.SafeZoneSpeed == true, "Z0a Features.SafeZoneSpeed allumé")
check(type(SZ) == "table" and SAFE > 0 and SZ.StolenItemMultiplier > 0 and SZ.StolenItemMultiplier < 1, "Z0b Balance.SafeZoneSpeed lu")
check(SAFE_STOLEN < SAFE and SAFE < MAX, `Z0c ordre : voleur {SAFE_STOLEN} < zone {SAFE} < plafond {MAX}`)

-- Ada (boutique 1, très rapide) expose 2 objets ; Bob (boutique 2, joueur neuf) vole.
local adaData = newProfile()
adaData.Stats.Speed = 1e30 -- plafond de la marche
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-chips", "Z1_PaquetDeChips", 2)
local ada = join("Ada", adaData)
local bobData = newProfile()
bobData.Stats.Strength = 10000
local bob = join("Bob", bobData)
wait(1)
local adaShop, bobShop = shopOf(ada), shopOf(bob)

section("Z1 Dans la zone (boutiques) : la même vitesse pour tous")
check(near(speedOf(ada), SAFE, 1e-3), `Z1a Ada (plafond {MAX} dehors) : {SAFE} (lu {speedOf(ada)})`)
check(near(speedOf(bob), SAFE, 1e-3), `Z1b Bob (joueur neuf) : {SAFE} (lu {speedOf(bob)})`)
check(near(ada:GetAttribute("WalkSpeed"), MAX, 1e-3), `Z1c attribut WalkSpeed d'Ada : la formule ({ada:GetAttribute("WalkSpeed")})`)

section("Z2 Sortie dans la rue puis retour : chacun la sienne dehors, aucune détection")
place(ada, HUB_CENTER)
place(bob, HUB_CENTER + Vector3.new(0, 0, -6))
settle()
check(near(speedOf(ada), SAFE, 1e-3), "Z2a Ada au milieu du hub : vitesse de la zone")
walk(ada, ROAD_POINT)
walk(bob, ROAD_POINT + Vector3.new(0, 0, -6))
arrive(ada, 30)
arrive(bob, 30)
wait()
check(near(speedOf(ada), MAX, 1e-3), `Z2b Ada dans la rue : {MAX} (lu {speedOf(ada)})`)
check(near(speedOf(bob), NEWBIE, 1e-3), `Z2c Bob dans la rue : {NEWBIE} (lu {speedOf(bob)})`)
walk(ada, HUB_CENTER)
arrive(ada, 60)
wait()
check(near(speedOf(ada), SAFE, 1e-3), `Z2d Ada revenue dans le hub : {SAFE} (lu {speedOf(ada)})`)
for i = 1, 6 do -- allers-retours de part et d'autre du bord (x = 25)
	walk(ada, Vector3.new(if i % 2 == 1 then 45 else 5, 3, -10))
	arrive(ada, 30)
end
wait(1.5)
check(strikes(ada) == 0 and strikes(bob) == 0, `Z2e aucune détection (Ada {strikes(ada)}, Bob {strikes(bob)}, journal {detections()})`)

section("Z3 Modificateurs dans la zone")
place(ada, HUB_CENTER)
settle()
check(near(speedOf(ada), SAFE, 1e-3), "Z3a de retour dans le hub")
Stats.SetSpeedModifier(ada, "Adrenaline", 1.25)
check(near(speedOf(ada), SAFE * 1.25, 1e-3), `Z3b Adrénaline × 1,25 : {SAFE * 1.25} (lu {speedOf(ada)})`)
Stats.SetSpeedModifier(ada, "Adrenaline", nil)
Stats.SetSpeedModifier(ada, "Carry", Balance.Carry.NPCBoxSpeedMultiplier)
check(near(speedOf(ada), SAFE * Balance.Carry.NPCBoxSpeedMultiplier, 1e-3), `Z3c objet de magasin PNJ × {Balance.Carry.NPCBoxSpeedMultiplier} (lu {speedOf(ada)})`)
Stats.SetSpeedModifier(ada, "Carry", nil)
Stats.SetSpeedModifier(ada, "GuardStun", 0)
check(speedOf(ada) == 0, "Z3d étourdi : immobile")
Stats.SetSpeedModifier(ada, "GuardStun", nil)
check(near(speedOf(ada), SAFE, 1e-3), "Z3e modificateurs retirés : vitesse de la zone")

section("Z4 Vol chez Ada : léger ralenti dans la zone, vitesse fixe dehors, dépôt réussi")
check(breakDoor(bob, adaShop), "Z4a porte d'Ada cassée")
check(steal(bob, adaShop, 1), "Z4b Bob porte la canette d'Ada")
check(near(speedOf(bob), SAFE_STOLEN, 1e-3), `Z4c Bob porte dans la zone : {SAFE_STOLEN} (lu {speedOf(bob)})`)
check(SAFE_STOLEN < SAFE, "Z4d Ada (vitesse de la zone) va plus vite que lui")
local A = refsOfShop(adaShop)
local Bs = refsOfShop(bobShop)
route(bob, { Vector3.new(A.door.X, 3, A.door.Z) - A.front * 2, A.outside })
arrive(bob, 60)
walk(bob, ROAD_POINT) -- en deux temps : une sortie de la boutique par le code (PutOutside) vide le but du client
arrive(bob, 60)
wait()
check(Carry.IsCarrying(bob), "Z4e il porte toujours dans la rue")
check(near(speedOf(bob), STOLEN, 1e-3), `Z4f Bob porte dans la rue : {STOLEN} (lu {speedOf(bob)}, Bob en {rootOf(bob).Position}, client en {clientPos(bob)})`)
route(bob, { Bs.outside, Vector3.new(Bs.door.X, 3, Bs.door.Z) - Bs.front * 6, Bs.center })
local sawSafe = false
for _ = 1, 1200 do
	advance(FRAME)
	if Carry.IsCarrying(bob) and near(speedOf(bob), SAFE_STOLEN, 1e-3) then
		sawSafe = true
	end
	if not Carry.IsCarrying(bob) then
		break
	end
end
wait()
check(sawSafe, "Z4g de retour dans la zone en portant : le ralenti de la zone")
check(not Carry.IsCarrying(bob) and bobData.Items["ada-soda"] ~= nil and adaData.Items["ada-soda"] == nil, "Z4h la canette est passée chez Bob (contrôle du dépôt de PvPService)")
check(near(speedOf(bob), SAFE, 1e-3), `Z4i Bob ne porte plus : vitesse de la zone (lu {speedOf(bob)})`)
check(strikes(ada) == 0 and strikes(bob) == 0, `Z4j aucune détection (journal {detections()})`)

section("Z5 Mort et réapparition dans sa boutique")
kill(ada)
wait(0.4)
spawnCharacter(ada, Vector3.new(0, 3, 0))
wait(1)
check(near(speedOf(ada), SAFE, 1e-3), `Z5a Ada réapparue dans sa boutique : {SAFE} (lu {speedOf(ada)})`)

summary("scénario zone")
