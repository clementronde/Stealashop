--!nocheck
-- C. Ce que le code fait lui-même n'est jamais pris pour de la triche (DEV-060). Chaque déplacement
-- fait par un service, avec les vrais services : réapparition, placement sur sa parcelle, Retour base
-- (ReturnBaseService → PlotService.TeleportHome), sortie d'une boutique à la reconstruction de sa porte
-- (PvPService → PlotService.PutOutside), sortie d'un magasin fermé ou reconstruit (StoreHeistService),
-- placement sur le tapis (TrainingService), knockback de la batte (BatService), coup du vigile
-- (GuardService), renvoi de nuit (NightCycleService : TeleportHome, ou derrière le mur sans parcelle),
-- capture par un vigile de nuit. Sanctions actives : la moindre détection se verrait (retour en
-- arrière, portage rendu). Contrôle : le même déplacement, Allow coupé et sanctions coupées (Studio),
-- est détecté quand il est assez grand pour l'être : c'est bien l'appel à Allow qui le couvre.

startServer()
setStrict(true)
local function strong()
	local data = newProfile()
	data.Stats.Strength = 10000
	return data
end
local A = join("Alice", strong()) -- boutique 1 (tapis, banc)
local B = join("Bob", newProfile()) -- boutique 2, Force 0 : sa porte casse en un coup
local C = join("Chloe", newProfile()) -- sans boutique (2 seulement)
advance(1)

-- Joue `fn`, puis attend `wait` s ; renvoie le nombre de détections de `player` pendant ce temps.
local function detectionsDuring(player, fn, wait)
	local s0 = strikes(player)
	fn()
	advance(wait or 3)
	return strikes(player) - s0
end
-- Contrôle : même chose, Allow coupé, sanctions coupées.
local function control(player, fn, wait)
	setStrict(false)
	local n
	withoutAllow(function()
		n = detectionsDuring(player, fn, wait)
	end)
	setStrict(true)
	return n
end

section("C0 Arrivées")
check(Plot.GetPlot(A) == SHOPS[1].model and Plot.GetPlot(B) == SHOPS[2].model and Plot.GetPlot(C) == nil, "C0a boutiques 1 et 2, Chloé attend")
check(strikes(A) + strikes(B) + strikes(C) == 0, "C0b apparition puis placement sur la parcelle : rien")

section("C1 Réapparition (mort dans le couloir, apparition à l'allée, PlotService la pose chez elle)")
place(A, Vector3.new(300, 3, 0))
settle()
local n = detectionsDuring(A, function()
	kill(A)
	advance(0.5)
	spawnCharacter(A, Vector3.new(0, 3, 0))
end, 4)
check(n == 0, `C1a aucune détection ({n})`)
check(horizontal(rootOf(A).Position, SHOPS[1].S.spawn) < 1, "C1b elle est chez elle")
n = control(A, function()
	kill(A)
	advance(0.5)
	spawnCharacter(A, Vector3.new(0, 3, 0))
end, 4)
check(n == 0, `C1c même sans les Allow : rien (nouveau personnage, puis SpawnGrace) ({n})`)

section("C2 Retour base (ReturnBaseService → PlotService.TeleportHome)")
place(A, Vector3.new(300, 3, 0))
settle()
n = detectionsDuring(A, function()
	fireAs(A, "ReturnToBase")
end)
check(horizontal(rootOf(A).Position, SHOPS[1].S.spawn) < 1, "C2a elle est rentrée (400 studs)")
check(n == 0, `C2b aucune détection ({n})`)
place(A, Vector3.new(300, 3, 0))
settle()
n = control(A, function()
	Plot.TeleportHome(A)
end)
check(n == 1, `C2c contrôle : le même retour sans Allow est un téléport détecté ({n})`)

-- a41 (2026-11-08, L-071, point 3) : le tapis n'a plus d'invite. Copie d'a65 (2026-11-11, L-093) : le
-- banc non plus ; on monte sur l'une ou l'autre machine en entrant dans sa zone (boîte du modèle + 1
-- stud), même en marchant : le serveur place le joueur sur le UsePoint (Allow). Au tapis il n'est pas
-- immobilisé (il peut finir son pas sur la bande) ; au banc, vitesse 0.
section("C3 Tapis et banc (TrainingService : placement sur la machine)")
local prompt, usePoint = machinePrompt("Treadmill")
check(prompt == nil, "C3a plus d'invite au tapis (L-071)")
place(A, usePoint + Vector3.new(0, 3, -12)) -- 12 studs devant
settle()
n = detectionsDuring(A, function()
	walk(A, usePoint + Vector3.new(0.8, 3, 0.8)) -- jusqu'au tapis, un peu à côté du centre
	arrive(A, 3)
	stop(A) -- elle s'y arrête
end, 5)
check(A:GetAttribute("TrainingMachine") == "Treadmill", "C3b Alice, entrée dans la zone du tapis, s'y entraîne")
check(horizontal(rootOf(A).Position, usePoint) < 1.2, "C3c placée sur le UsePoint par le serveur, puis un pas sur la bande (a65 : montée à l'entrée de la zone)")
check(humanoidOf(A).WalkSpeed > 0, "C3c' pas immobilisée au tapis")
check(n == 0, `C3d aucune détection, ni au placement ni pendant 5 s d'entraînement ({n})`)
n = detectionsDuring(A, function()
	walk(A, usePoint + Vector3.new(0, 3, -30))
end, 3)
stop(A)
check(A:GetAttribute("TrainingMachine") == nil and n == 0, `C3e descendue, repartie à pied : rien ({n})`)
n = control(A, function()
	walk(A, usePoint + Vector3.new(0.8, 3, 0.8))
	arrive(A, 3)
	stop(A)
end, 3)
check(n == 0 and A:GetAttribute("TrainingMachine") == "Treadmill", `C3f contrôle : le placement (quelques studs) reste sous les seuils, même sans Allow ({n})`)
walk(A, usePoint + Vector3.new(0, 3, -12))
arrive(A, 5)
stop(A)
check(A:GetAttribute("TrainingMachine") == nil, "C3f' descendue")
local benchPrompt, benchPoint = machinePrompt("Bench")
check(benchPrompt == nil, "C3g' plus d'invite au banc (a65, L-093)")
place(A, benchPoint + Vector3.new(0, 3, -12)) -- 12 studs devant le banc
settle()
n = detectionsDuring(A, function()
	walk(A, benchPoint + Vector3.new(0, 3, -1)) -- elle entre dans la zone du banc
	arrive(A, 4)
	stop(A)
end, 5)
check(A:GetAttribute("TrainingMachine") == "Bench" and near(humanoidOf(A).WalkSpeed, 0, 1e-6), "C3g au banc : vitesse 0")
check(n == 0, `C3h aucune détection, ni au placement ni pendant 5 s au banc ({n})`)
Training.Stop(A)
flush()
advance(0.5)

section("C4 Magasin fermé avec Bob dedans, sans colis (StoreHeistService le sort devant la vitrine)")
ensureOpen(A, STORE_B)
place(A, Vector3.new(40, 3, 0))
local deep = Vector3.new(65, 3, -57) -- au fond du magasin, contre le rayon
place(B, deep)
n = detectionsDuring(B, function()
	advance(10) -- fin du chrono : le rideau tombe
end, 2)
check(rootOf(B).Position.Z > -31, `C4a Bob est sorti devant la vitrine (z {string.format("%.1f", rootOf(B).Position.Z)})`)
check(n == 0, `C4b aucune détection ({n})`)
advance(25) -- reconstruction, nouveau braquage possible
ensureOpen(A, STORE_B)
place(A, Vector3.new(40, 3, 0))
place(B, deep)
settle()
n = control(B, function()
	advance(10)
end, 2)
check(n == 1, `C4c contrôle : la même sortie sans Allow (32 studs) est détectée ({n})`)

section("C5 Vitrine reconstruite avec Alice dedans, colis en main (sortie, colis gardé)")
advance(25)
ensureOpen(A, STORE_A)
local slot = fullSlot(STORE_A)
check(grabShelf(A, STORE_A, slot), "C5a Alice porte un colis")
-- Le vigile la rattraperait dans le magasin : 120 studs d'avance (placement du banc), il abandonne et
-- rentre ; puis elle revient au fond du magasin (fermé, mais un porteur peut y rester).
place(A, Vector3.new(65, 3, 200))
advance(8)
place(A, Vector3.new(60, 3, 57))
settle()
local brokenAt = now()
n = detectionsDuring(A, function()
	while Carry.IsCarrying(A) and rootOf(A).Position.Z > 31 and now() - brokenAt < 30 do
		advance(0.1) -- la vitrine se reconstruit (30 s après la casse) : tout le monde est sorti
	end
end, 1)
check(rootOf(A).Position.Z < 31 and Carry.IsCarrying(A), `C5b sortie devant la vitrine, colis gardé (z {string.format("%.1f", rootOf(A).Position.Z)})`)
check(n == 0, `C5c aucune détection ({n})`)
Carry.Fail(A, "banc") -- le colis revole vers son rayon
advance(3)

section("C6 Coup de batte sur un porteur (BatService : knockback 40 studs/s, étourdi 2 s)")
advance(20)
ensureOpen(A, STORE_A)
check(grabShelf(B, STORE_A, fullSlot(STORE_A)), "C6a Bob porte un colis")
place(B, Vector3.new(120, 3, 10))
place(A, Vector3.new(115, 3, 10), Vector3.new(1, 0, 0))
settle()
equipBat(A)
n = detectionsDuring(B, function()
	fireAs(A, "SwingBat")
	flush()
end, 3)
check(not Carry.IsCarrying(B), "C6b le colis de Bob est tombé")
local pushed = horizontal(rootOf(B).Position, Vector3.new(120, 3, 10))
check(pushed > 5, `C6c Bob a été poussé de {string.format("%.1f", pushed)} studs`)
check(n == 0, `C6d aucune détection ({n})`)
unequip(A)
advance(16) -- le colis au sol retourne sur son rayon

section("C7 Rattrapé par le vigile (GuardService : coup qui le projette, étourdi 1,5 s)")
ensureOpen(A, STORE_A)
check(grabShelf(B, STORE_A, fullSlot(STORE_A)), "C7a Bob reprend un colis")
place(B, Vector3.new(70, 3, 26)) -- devant la vitrine : le vigile arrive du fond
local caught = false
n = detectionsDuring(B, function()
	for _ = 1, 300 do
		advance(FRAME)
		if not Carry.IsCarrying(B) then
			caught = true
			break
		end
	end
end, 3)
check(caught and logHas("Bob rattrapé", "PRINT", "server"), "C7b le vigile l'a rattrapé")
check(n == 0, `C7c aucune détection ({n})`)
advance(5)

section("C8 Porte d'une boutique reconstruite avec Alice dedans (PvPService → PlotService.PutOutside)")
local bobShop = SHOPS[2]
check(breakDoor(A, bobShop.model), "C8a Alice casse la porte de Bob")
place(A, bobShop.S.back) -- au fond de la boutique de Bob
settle()
n = detectionsDuring(A, function()
	for _ = 1, 400 do
		advance(0.1)
		if not Window.IsBroken(Window.GetWindowId(bobShop.model)) then
			break
		end
	end
end, 2)
check(horizontal(rootOf(A).Position, bobShop.S.outside) < 12, "C8b Alice est sortie devant la porte (80 studs plus loin)")
check(n == 0, `C8c aucune détection ({n})`)
check(breakDoor(A, bobShop.model), "C8d porte recassée")
place(A, bobShop.S.back)
settle()
n = control(A, function()
	for _ = 1, 400 do
		advance(0.1)
		if not Window.IsBroken(Window.GetWindowId(bobShop.model)) then
			break
		end
	end
end, 2)
check(n == 1, `C8e contrôle : la même sortie sans Allow est un téléport détecté ({n})`)

section("C9 Nuit : entrée dans le couloir après la tombée (NightCycleService renvoie chez soi)")
place(A, HUB_CENTER)
place(C, HUB_CENTER + Vector3.new(0, 0, -20))
settle()
Workspace:SetAttribute("NightSkipTo", "Night 300")
advance(1)
check(Night.IsNight(), "C9a c'est la nuit")
-- Le joueur entre à pied dans le couloir ; dès qu'il est renvoyé, il lâche la touche (il continuerait sinon).
local function prepare(player, z)
	place(player, Vector3.new(15, 3, z))
	settle()
end
local function enterCorridor(player, z, sentBack)
	walk(player, Vector3.new(60, 3, z))
	for _ = 1, 120 do
		advance(FRAME)
		if sentBack() then
			stop(player)
			return true
		end
	end
	stop(player)
	return false
end
local homeA = false
prepare(A, 0)
n = detectionsDuring(A, function()
	homeA = enterCorridor(A, 0, function()
		return horizontal(rootOf(A).Position, SHOPS[1].S.spawn) < 1
	end)
end, 2)
check(homeA, "C9b Alice est renvoyée chez elle (TeleportHome)")
check(n == 0, `C9c aucune détection ({n})`)
local safeC = false
prepare(C, -10)
local nc = detectionsDuring(C, function()
	safeC = enterCorridor(C, -10, function()
		return rootOf(C).Position.X < 0
	end)
end, 2)
check(safeC, "C9d Chloé (sans boutique) est renvoyée dans la zone safe")
check(nc == 0, `C9e aucune détection ({nc})`)
prepare(A, 0)
n = control(A, function()
	enterCorridor(A, 0, function()
		return horizontal(rootOf(A).Position, SHOPS[1].S.spawn) < 1
	end)
end, 2)
check(n == 1, `C9f contrôle : le même renvoi sans Allow est détecté ({n})`)
prepare(C, -10)
nc = control(C, function()
	enterCorridor(C, -10, function()
		return rootOf(C).Position.X < 0
	end)
end, 2)
check(nc == 1, `C9g contrôle : le renvoi derrière le mur sans Allow est détecté ({nc})`)

section("C10 Nuit : capturé par un vigile de nuit (coup, puis renvoi chez soi)")
Workspace:SetAttribute("NightSkipTo", "Day")
advance(1)
place(B, Vector3.new(205, 3, 0)) -- sur la ronde, dans le couloir à la tombée de la nuit
settle()
Workspace:SetAttribute("NightSkipTo", "Night 300")
advance(1)
local sentHome = false
n = detectionsDuring(B, function()
	for _ = 1, 600 do
		advance(0.1)
		if horizontal(rootOf(B).Position, SHOPS[2].S.spawn) < 1 then
			sentHome = true
			break
		end
	end
end, 3)
check(logHas("Bob attrapé, renvoyé chez lui", "PRINT", "server"), "C10a un vigile de nuit l'a attrapé")
check(sentHome, "C10b Bob est renvoyé chez lui")
check(n == 0, `C10c aucune détection ({n})`)

section("C11 Bilan")
check(strikes(A) + strikes(B) + strikes(C) == #AC.GetLog(), "C11a toutes les détections viennent des contrôles (Allow coupé)")
for _, entry in AC.GetLog() do
	check(entry.Sanctioned == false, `C11b détection de contrôle, non sanctionnée : {entry.Name} {entry.Detail}`)
end

summary("scénario code")
