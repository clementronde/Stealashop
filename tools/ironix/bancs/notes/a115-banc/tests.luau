-- Scénarios du banc a115 (Cantin, 2026-11-13).
--   M : mesures avant / après (lignes MESURE) ;
--   E : entrée instantanée (serveur sans attente, client qui se met en place sans attendre le serveur) ;
--   S : sortie du tapis au premier mouvement (TrainLeave), banc inchangé ; remontée par le cœur de la machine ;
--   L : TreadmillRun rejoué s'il s'arrête.

local FRAME = 1 / 60
local alice = newPlayer("Alice")
local bob = newPlayer("Bob")
newPlot("PLOT_Shop_01", alice, Vector3.new(0, 0, 0))
newPlot("PLOT_Shop_02", bob, Vector3.new(0, 0, 100))
TrainingService.Init()
startClient(alice)

local STAND_T = Vector3.new(0, 4.2, 0) -- HumanoidRootPart sur le UsePoint du tapis d'Alice
local STAND_B = Vector3.new(20, 3.2, 0) -- … du banc
local function away(p)
	setMove(p, 0, 0)
	moveTo(p, Vector3.new(p.UserId * 10, 3, -400))
	step(0.6, FRAME) -- au-delà de SETTLE_TIME (0,5 s) du serveur
end
local function fmt(t)
	return if t == nil then "jamais (attend le serveur)" else string.format("%.3f s", t)
end

------------------------------------------------------------------------ M mesures
local m1Server, m1Anim
do
	-- La boucle pose la position à chaque image tant qu'il marche ; une fois en place, elle ne la touche plus.
	away(alice)
	ANIM.playing = {}
	local x, entered = 8, nil
	local t = 0
	local walking = true
	while t < 2.5 and (m1Server == nil or m1Anim == nil) do
		if walking then
			x = math.max(2.5, x - 16 * FRAME)
			moveTo(alice, Vector3.new(x, 3, 1))
			if entered == nil and x <= 3 then
				entered = NOW
			end
		end
		step(FRAME, FRAME)
		t += FRAME
		if entered and m1Server == nil and machineOf(alice) == "Treadmill" then
			m1Server = NOW - entered
		end
		if entered and m1Anim == nil and ANIM.playing.TreadmillRun then
			m1Anim = NOW - entered
		end
		if machineOf(alice) ~= nil or ANIM.playing.TreadmillRun then
			walking = false
		end
	end
	print(`MESURE {MODE} : entrée au tapis, première image dans la zone → séance du serveur : {fmt(m1Server)}, TreadmillRun chez le client : {fmt(m1Anim)} (banc sans réseau ; en jeu, + aller-retour avant le changement)`)
end

-- M2 : le serveur ne répond pas encore (profil pas chargé : comme un aller-retour du réseau qui traîne).
local m2Anim
do
	away(alice)
	NOT_LOADED[alice] = true
	ANIM.playing = {}
	moveTo(alice, Vector3.new(2.5, 3, 1))
	local t0 = NOW
	for _ = 1, 30 do
		step(FRAME, FRAME)
		if m2Anim == nil and ANIM.playing.TreadmillRun then
			m2Anim = NOW - t0
		end
	end
	print(`MESURE {MODE} : sans réponse du serveur (0,5 s), TreadmillRun chez le client après : {fmt(m2Anim)}`)
	NOT_LOADED[alice] = nil
	step(2, FRAME)
	away(alice)
end

-- M3 : sur le tapis, un petit pas (0,5 stud) avec une touche de déplacement.
local m3Off
do
	away(alice)
	moveTo(alice, Vector3.new(0.5, 3, 1))
	step(1, FRAME)
	local on = machineOf(alice) == "Treadmill"
	setMove(alice, 1, 0)
	local t0 = NOW
	local p = rootPos(alice)
	moveTo(alice, p + Vector3.new(0.5, 0, 0))
	for _ = 1, 120 do
		step(FRAME, FRAME)
		if m3Off == nil and machineOf(alice) == nil then
			m3Off = NOW - t0
		end
	end
	print(`MESURE {MODE} : sur le tapis ({on}), petit pas de 0,5 stud avec la touche : descendu après {if m3Off then string.format("%.3f s", m3Off) else "jamais (2 s : toujours dessus)"}`)
	away(alice)
end

if MODE ~= "nouveau" then
	print("banc a115 (montée et sortie des machines) : SAUTÉ (arbre d'avant a115, mesures « avant » ci-dessus) : 0 vérification(s), 0 échec(s)")
	return
end

check("M1 séance du serveur à la première image dans la zone (START_DWELL 0, contrôle à chaque Heartbeat)", m1Server ~= nil and m1Server <= FRAME + 1e-9, m1Server)
check("M1 TreadmillRun à la première image dans la zone", m1Anim ~= nil and m1Anim <= FRAME + 1e-9, m1Anim)
check("M2 sans réponse du serveur : le client anime à la première image", m2Anim ~= nil and m2Anim <= FRAME + 1e-9, m2Anim)
check("M3 petit pas au tapis : descendu à l'image suivante", m3Off ~= nil and m3Off <= FRAME + 1e-9, m3Off)

------------------------------------------------------------------------ E entrée prédite
do
	away(alice)
	NOT_LOADED[alice] = true -- le serveur ne confirme pas : on voit le client seul
	local sentBefore = SENT.TrainLeave
	moveTo(alice, Vector3.new(2.5, 3, 4.5)) -- coin de la zone (X ±3, Z −6 à 5), hors de la bande
	step(FRAME, FRAME)
	check("E1 le client se place lui-même sur le UsePoint", rootPos(alice) == STAND_T, tostring(rootPos(alice)))
	check("E1 figé en local (WalkSpeed 0, sans rotation)", humOf(alice).WalkSpeed == 0 and humOf(alice).AutoRotate == false)
	check("E1 TreadmillRun joué sans attendre le serveur", ANIM.playing.TreadmillRun == true)
	check("E1 rien chez le serveur (pas encore de séance, aucun gain)", machineOf(alice) == nil and SPEEDMOD[alice] == nil)
	step(1.2, FRAME)
	check("E2 toujours en attente avant PREDICT_TIMEOUT (1,5 s)", ANIM.playing.TreadmillRun == true)
	step(0.4, FRAME)
	check("E2 pas de réponse : annulé (animation arrêtée)", ANIM.playing.TreadmillRun == nil)
	check("E2 vitesse et rotation rendues", humOf(alice).WalkSpeed == 16 and humOf(alice).AutoRotate == true, humOf(alice).WalkSpeed)
	check("E2 aucun TrainLeave pour une annulation", SENT.TrainLeave == sentBefore)
	step(1, FRAME)
	check("E2 resté sur la bande : pas de nouvelle tentative du client", ANIM.playing.TreadmillRun == nil)
	-- Le serveur répond enfin (profil chargé) : il le met en séance ; le client suit l'attribut.
	NOT_LOADED[alice] = nil
	step(FRAME, FRAME)
	check("E3 séance du serveur : le client suit (TreadmillRun)", machineOf(alice) == "Treadmill" and ANIM.playing.TreadmillRun == true)
	check("E3 figé par le serveur", SPEEDMOD[alice] == 0 and humOf(alice).WalkSpeed == 0)
	away(alice)
	check("E3 parti : séance finie, animation arrêtée", machineOf(alice) == nil and ANIM.playing.TreadmillRun == nil)
	-- Machine d'un autre : le client ne se met pas en place (le serveur refusera).
	moveTo(alice, Vector3.new(1, 3, 101))
	step(FRAME, FRAME)
	check("E4 tapis de Bob : le client d'Alice ne bouge pas", rootPos(alice) == Vector3.new(1, 3, 101) and ANIM.playing.TreadmillRun == nil)
	away(alice)
	-- Banc : montée instantanée aussi.
	moveTo(alice, Vector3.new(23.5, 3, 1))
	step(FRAME, FRAME)
	check("E5 banc : séance et BenchIdle à la première image", machineOf(alice) == "Bench" and ANIM.playing.BenchIdle == true)
	check("E5 banc : placé sur le UsePoint", rootPos(alice) == STAND_B, tostring(rootPos(alice)))
	check("E5 banc : boucle BenchLift lancée", SPAWNED >= 1)
	away(alice)
end

------------------------------------------------------------------------ S sortie au premier mouvement
do
	away(alice)
	-- Il arrive en tenant la touche : la touche tenue depuis la montée ne le fait pas descendre.
	setMove(alice, -1, 0)
	moveTo(alice, Vector3.new(2.5, 3, 1))
	step(FRAME, FRAME)
	check("S1 monté en marchant", machineOf(alice) == "Treadmill")
	step(1, FRAME)
	check("S1 touche tenue depuis la montée : reste dessus (figé, il court sur place)", machineOf(alice) == "Treadmill" and rootPos(alice) == STAND_T)
	setMove(alice, 0, 0)
	step(0.3, FRAME)
	check("S1 touche relâchée : toujours dessus", machineOf(alice) == "Treadmill")
	local sent = SENT.TrainLeave
	setMove(alice, 0, 1)
	step(FRAME, FRAME)
	check("S2 il bouge : TrainLeave envoyé", SENT.TrainLeave == sent + 1, SENT.TrainLeave - sent)
	check("S2 descendu tout de suite (séance du serveur finie)", machineOf(alice) == nil)
	check("S2 TreadmillRun arrêté", ANIM.playing.TreadmillRun == nil)
	check("S2 vitesse rendue, plus figé", SPEEDMOD[alice] == nil and humOf(alice).WalkSpeed == 16 and humOf(alice).AutoRotate == true)
	step(0.5, FRAME)
	check("S3 encore sur la bande (pas de physique ici) : pas de remontée en boucle", machineOf(alice) == nil and ANIM.playing.TreadmillRun == nil)
	-- Il quitte la bande (encore dans la zone) puis y revient : remonte tout de suite.
	setMove(alice, 0, 0)
	moveTo(alice, Vector3.new(2.6, 3, 0))
	step(0.2, FRAME)
	check("S3 à côté de la bande, dans la zone : ne remonte pas", machineOf(alice) == nil)
	moveTo(alice, Vector3.new(1, 3, 0))
	step(FRAME, FRAME)
	check("S4 revenu sur la bande : remonte à la première image", machineOf(alice) == "Treadmill" and ANIM.playing.TreadmillRun == true)
	-- Touche tenue au moment de la descente, relâchée sur la bande puis pressée : redescend.
	setMove(alice, 1, 0)
	step(FRAME, FRAME)
	check("S4 bouge (touche pas tenue à la montée) : redescend", machineOf(alice) == nil)
	setMove(alice, 0, 0)
	away(alice)

	-- Banc : bouger ne fait rien (sortie inchangée : saut ou éloigné).
	moveTo(alice, Vector3.new(21, 3, 0))
	step(FRAME, FRAME)
	check("S5 banc : monté", machineOf(alice) == "Bench")
	local sentB = SENT.TrainLeave
	setMove(alice, 1, 0)
	step(0.5, FRAME)
	check("S5 banc : bouger ne fait pas descendre, pas de TrainLeave", machineOf(alice) == "Bench" and SENT.TrainLeave == sentB)
	LEAVE:Fire(alice)
	step(FRAME, FRAME)
	check("S5 banc : TrainLeave reçu quand même → ignoré", machineOf(alice) == "Bench")
	setMove(alice, 0, 0)
	step(0.6, FRAME) -- après SETTLE_TIME
	setState(alice, "Jumping")
	check("S6 banc : saut → descendu", machineOf(alice) == nil and ANIM.playing.BenchIdle == nil)
	moveTo(alice, STAND_B)
	setState(alice, "Landed")
	step(1, FRAME)
	check("S6 banc : retombé à sa place : ne remonte pas", machineOf(alice) == nil and ANIM.playing.BenchIdle == nil)
	moveTo(alice, Vector3.new(23, 3, 0)) -- à 3 studs du UsePoint : hors du cœur (2,5), dans la zone
	step(0.2, FRAME)
	check("S6 banc : à côté, dans la zone : ne remonte pas", machineOf(alice) == nil)
	moveTo(alice, Vector3.new(21.5, 3, 0))
	step(FRAME, FRAME)
	check("S7 banc : revenu à sa place (cœur) : remonte à la première image", machineOf(alice) == "Bench" and ANIM.playing.BenchIdle == true)
	away(alice)

	-- Serveur seul : TrainLeave avant la séance (montée du client pas encore vue) : le tapis est bloqué.
	away(bob)
	NOT_LOADED[bob] = true
	moveTo(bob, Vector3.new(0.5, 3, 101))
	step(0.1, FRAME)
	LEAVE:Fire(bob)
	NOT_LOADED[bob] = nil
	step(0.5, FRAME)
	check("S8 TrainLeave avant la séance : pas remis sur le tapis", machineOf(bob) == nil)
	moveTo(bob, Vector3.new(2.6, 3, 100))
	step(0.1, FRAME)
	moveTo(bob, Vector3.new(0.5, 3, 100))
	step(FRAME, FRAME)
	check("S8 quitté puis revenu sur la bande : monte", machineOf(bob) == "Treadmill")
	away(bob)
	LEAVE:Fire(bob)
	step(0.1, FRAME)
	check("S8 TrainLeave hors machine : rien", machineOf(bob) == nil)
end

------------------------------------------------------------------------ L boucle de TreadmillRun
do
	away(alice)
	moveTo(alice, Vector3.new(1, 3, 1))
	step(FRAME, FRAME)
	check("L1 sur le tapis, TreadmillRun joue", machineOf(alice) == "Treadmill" and ANIM.playing.TreadmillRun == true)
	ANIM.playing.TreadmillRun = nil -- arrêtée par autre chose (fin d'une piste sans boucle…)
	step(FRAME, FRAME)
	check("L1 rejouée à l'image suivante", ANIM.playing.TreadmillRun == true)
	local plays = ANIM.plays.TreadmillRun
	step(2, FRAME)
	check("L1 toujours en course après 2 s", machineOf(alice) == "Treadmill" and ANIM.playing.TreadmillRun == true and ANIM.plays.TreadmillRun > plays)
	away(alice)
	check("L2 descendu : arrêtée et plus rejouée", ANIM.playing.TreadmillRun == nil)
	step(0.5, FRAME)
	check("L2 toujours arrêtée", ANIM.playing.TreadmillRun == nil)
end

check("aucune erreur dans la sortie", not hasLog("ERREUR"))
print("banc a115 (montée et sortie des machines) : " .. CHECKS .. " vérification(s), " .. FAILS .. " échec(s)")
