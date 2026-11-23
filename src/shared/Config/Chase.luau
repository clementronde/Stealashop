--!strict
-- Nouvelle poursuite du vigile (Cantin, 2026-11-14, vague 45, a153 ; Config/Features.GuardChaseV2).
-- Lu par GuardService. Toutes les valeurs : V0 proposé, absent du doc.
--
-- Déroulé, pour un poursuivant qui suit cette règle (Apply) :
--   1. Ruée : après le délai de réaction, il court à RushWalkFactor × la marche du voleur, au moins
--      RushMinSpeed studs/s, droit sur lui, jusqu'à être à HoldDistance studs (distance horizontale ;
--      la capture reste à Balance.Guard.CatchDistance). Une seule ruée par départ de poursuite.
--   2. Poursuite à distance : sa vitesse = la marche que le SERVEUR donne au voleur (Humanoid.WalkSpeed
--      posée par StatsService, colis compris ; jamais une vitesse venue du client) + le rapprochement :
--        r = Speed effective du voleur (voir plus bas, lue côté serveur) / SpeedRequired de la zone
--        rapprochement = ClosingSpeedMax × (1 − r), r borné entre 0 et 1
--      À 50 % du minimum : 4 studs/s ; à 99 % : 0,08 ; à 100 % : 0 (la distance ne bouge pas tant que le
--      voleur court tout droit ; s'il tourne, ralentit ou s'arrête, le vigile gagne du terrain).
--      Jamais moins de HoldMinSpeed (un voleur immobilisé, WalkSpeed 0, est quand même rattrapé).
--   3. Au-dessus du minimum (r > 1), AboveRequired :
--        "Hold" : rapprochement 0, la distance ne bouge pas ;
--        "Gain" : le voleur s'éloigne, le vigile perd ClosingSpeedMax × min(r − 1, 1) studs/s.
--   4. SpeedRequired = 0 (zone 1) : rapprochement 0, quel que soit AboveRequired. Zone1SpeedRequired
--      donne un minimum à la zone 1 (0 = aucun).
--   5. Vigile de nuit et policier (Cantin, 2026-11-14) : même ruée, même rapprochement, mais leur minimum
--      vaut la Speed effective actuelle du voleur × NightGuardRequiredFactor (PoliceRequiredFactor) : r = 1/2,
--      rapprochement 4 studs/s, ils attrapent toujours (environ 2,5 s après la ruée : 14 − 4 studs à 4 studs/s, a174), sauf si la poursuite
--      finit avant (zone safe ; policier : durée de WitnessService).
--   6. Conducteur du camion : même ruée, puis la marche du voleur × (1 + DriverGrowthPerSecond × secondes
--      depuis la fin de la ruée), au plus × DriverMaxFactor : il rattrape de plus en plus vite.
-- Speed effective = Speed du profil × multiplicateur du trail (StatsService.GetTrailMultiplier), celle du
-- HUD et de Formulas.WalkSpeed (Cantin : un trail ×2 double la Speed).
-- Vitesse imposée par le tutoriel (GuardService.GetSpeedOverride) : l'ancienne règle, sans ruée.
-- Features.GuardChaseV2 = false, ou Apply.<X> = false : la vitesse d'avant (Zones[zone].GuardSpeed,
-- Night.ChaseSpeed, vitesse fixe du policier, × la marche de sa cible pour le conducteur).

-- Vague 61 (a198, Cantin : vitesse réelle × Balance.Stats.RealSpeedScale, k) : les vitesses (studs/s) sont écrites à
-- l'échelle 1 puis × k ; le freinage (studs/s²) × k², pour freiner sur la même distance ; la croissance du
-- conducteur (par seconde) × k, pour qu'il rattrape sur la même distance. Les distances (HoldDistance, LagMaxStuds,
-- LagContactReach), les durées (LagMaxSeconds), le rappel HoldRecallGain (un temps de réponse) et les rapports de
-- Speed affichée (RushWalkFactor, *RequiredFactor, DriverMaxFactor) ne changent pas. Conséquence : un rapprochement
-- × k sur la même distance prend 1/k du temps (vigile de nuit, policier : 14 − 4 studs en ~1,25 s au lieu de 2,5 s),
-- comme le trajet jusqu'à la zone safe, qui se fait aussi en 1/k du temps.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)

local K = Balance.Stats.RealSpeedScale

export type AboveRequired = "Hold" | "Gain"

local Chase = {
	RushWalkFactor = 3.9, -- ruée : × la marche du voleur (a174, Cantin 2026-11-15 : +30 %, 3 → 3,9)
	RushMinSpeed = 78 * K, -- ruée : au moins (studs/s) (a174 : +30 %, 60 → 78 ; vague 61 : × k)
	HoldDistance = 14, -- fin de la ruée, à l'horizontale (studs) (a174, Cantin 2026-11-15 : 10 → 14)
	-- a174 : freinage de la fin de ruée (studs/s²) : sa vitesse ne dépasse pas la marche du voleur +
	-- √(2 × RushBrake × (distance − HoldDistance)), pour que l'élan du Humanoid ne le porte pas trop près. 0 = sans.
	RushBrake = 250 * K * K, -- V0 (vague 61 : × k²)
	-- Vague 67 (a224, Cantin : « il va tellement vite que parfois il nous attrape d'un coup ») : en arrivant, tout
	-- poursuivant de cette règle ralentit en continu. Sa vitesse ne dépasse pas la part de la vitesse du voleur qui
	-- l'éloigne + max(√(2 × RushBrake × (d − HoldDistance)⁺ + 2 × ApproachBrake × (d − capture)⁺), ApproachMinClosing).
	-- Voleur immobile : ≈ 10 studs/s à 10 studs de la capture, puis de moins en moins vite, les 10 derniers studs en
	-- ≈ 1,5 à 1,7 s (banc a224) ; jamais moins de ApproachMinClosing (il est toujours attrapé). En studs/s² et studs/s RÉELS, sans × k :
	-- Cantin veut voir arriver le vigile pendant une durée réelle. ApproachBrake = 0 : sans ce plafond (avant a224).
	ApproachBrake = 5, -- V0, absent du doc (studs/s²) ; Cantin 2026-11-16 : ralentir davantage en arrivant (10 → 5)
	ApproachMinClosing = 3, -- V0 proposé, absent du doc (studs/s)
	-- f70c3b (Cantin, 2026-11-18 : « pour la poursuite enleve le ralentissement quand le vigil est tres proche du joueur
	-- car sinon c'est bete car le joueur peut sarreter et le vigil ralenti enormement ») : false : le plafond d'arrivée
	-- ci-dessus compte toujours le voleur à sa marche, comme s'il courait encore (avant : la part de sa vitesse qui
	-- l'éloigne, 0 s'il s'arrête, d'où ≈ 3 studs/s au contact) ; et en poursuite à distance, un voleur qui s'éloigne
	-- moins vite que sa marche − HoldRecallMax (arrêté, ou qui ralentit) n'est plus tenu à distance : le vigile garde au
	-- moins sa marche + le rapprochement et l'attrape. Un voleur qui court tout droit : rien ne change (tenue à
	-- HoldDistance, retour doux, capture à CatchDistance). true : l'approche lente d'a224 (la règle d'avant).
	ApproachSlowNear = false, -- V0 (décision de Cantin du 18/11)
	ClosingSpeedMax = 8 * K, -- rapprochement à 0 % du minimum (studs/s ; vague 61 : × k)
	HoldMinSpeed = 12 * K, -- plancher de la poursuite à distance (studs/s), sous toute marche d'un voleur qui court (× k)
	AboveRequired = "Hold" :: AboveRequired, -- Cantin, 2026-11-14 : au-dessus, « ça garde toujours la même distance »
	-- Minimum de la zone 1 pour cette règle. a249 (Cantin, 2026-11-17, L-235 décision 3 : « zone 1 : capture possible »,
	-- petit minimum au lieu de 0) : V0 proposé, absent du doc = la Speed que donne l'étape « Train » du tutoriel
	-- (Tutorial.TrainDuration 10 s × Training.Treadmill.GainPerSecond 1, sans taper) : un joueur qui a fait le tutoriel
	-- est au minimum (gardé à distance), un joueur à 0 est rattrapé. Le premier braquage du tutoriel ne suit pas cette
	-- règle (GetSpeedOverride : vigile lent, Tutorial.GuardSpeed). 0 = sans minimum (avant a249).
	Zone1SpeedRequired = 10,
	NightGuardRequiredFactor = 2, -- vigile de nuit : minimum = Speed effective actuelle du voleur × ceci (Cantin)
	PoliceRequiredFactor = 2, -- policier : minimum = Speed effective actuelle du voleur × ceci (Cantin)
	DriverGrowthPerSecond = 0.02 * K, -- conducteur : + 2 % de la marche du voleur par seconde depuis la fin de la ruée (× k)
	DriverMaxFactor = 2, -- conducteur : au plus × la marche du voleur
	-- a173 (2026-11-15, Play de fusion48) : en poursuite à distance, rappel vers la distance prévue (la fin de
	-- ruée tombe 1 à 3 studs trop près quand les images n'ont pas la même durée, ou par l'élan du Humanoid) :
	-- vitesse + clamp(HoldRecallGain × (distance − distance prévue), −HoldRecallMax, +HoldRecallMax). Distance
	-- prévue = HoldDistance, qui baisse au rythme du rapprochement (vigile de nuit, policier : 4 studs/s), au
	-- moins la distance de capture. Pas pour le conducteur du camion.
	HoldRecallGain = 2, -- par seconde (V0)
	HoldRecallMax = 4 * K, -- studs/s (V0 ; vague 61 : × k)
	-- a174 (Cantin, 2026-11-15) : à la N-ième capture d'un porteur du même objet sorti d'un rayon (vigile du
	-- magasin, vigile de nuit, policier, conducteur du camion ; quel que soit le porteur, l'objet tombé puis
	-- ramassé par un autre compte toujours), l'objet ne tombe pas : il revole tel quel sur son rayon, comme une
	-- capture dans son magasin (GuardService). Compteur effacé quand l'objet est rangé en zone safe ou revient
	-- au rayon. 0 = jamais.
	ReturnToShelfAfterCatches = 3, -- V0 (Cantin : « au bout de la troisième fois »)
	-- a193 (Cantin, 2026-11-15, T-069 : « plus on est rapide, plus on a l'impression que le vigile est loin de
	-- nous », « il nous attrape de loin ») : le personnage appartient au client, le serveur reçoit sa position
	-- en retard (l'aller), et le client voit le vigile en retard (le retour). Pour tous les poursuivants
	-- (GuardService.chaseStep), la distance gardée (ruée, HoldDistance, rappel), le point visé et la capture se
	-- mesurent sur la position estimée du voleur : position reçue + sa vitesse au sol (bornée à sa WalkSpeed,
	-- donnée par le serveur) × min(player:GetNetworkPing() × LagPingFactor, LagMaxSeconds), au plus
	-- LagMaxStuds studs devant, et jamais à travers un mur (sinon la position reçue).
	-- false : la règle d'avant (position reçue seulement).
	LagCompensation = true, -- V0
	-- GetNetworkPing ≈ l'aller simple (comme AntiCheat.AllowPingFactor) : × 2 = l'aller-retour, ce que le
	-- joueur voit. Si un Play montre que GetNetworkPing donne déjà l'aller-retour (Shift+F3), mettre 1.
	LagPingFactor = 2, -- V0
	LagMaxSeconds = 0.3, -- V0 : plafond du retard compensé (s) ; au-delà, un client qui se met en retard exprès ne gagne rien de plus
	-- V0 : plafond de l'avance (studs). Sur le serveur, le vigile bute sur la copie du voleur (collisions) :
	-- à 14 studs de l'estimation, il reste ainsi au moins HoldDistance − LagMaxStuds (6) studs derrière elle.
	-- math.huge : sans plafond.
	LagMaxStuds = 8,
	-- V0 : capture aussi à LagContactReach studs de la copie du voleur sur le serveur (à l'horizontale, comme
	-- CatchReach.InRange ; corps qui se touchent, gros vigile compris) : un vigile bloqué derrière elle par les
	-- collisions attrape quand même. Dès que l'avance dépasse CatchDistance − LagContactReach (1 stud), c'est
	-- cette règle qui attrape en ligne droite : la capture se fait 1 stud plus près qu'avant, pas plus (le
	-- vigile ne peut pas doubler la copie du serveur).
	LagContactReach = 3,
	-- a416 (Cantin, 2026-11-23 : « le vigile attrape de hyper loin le joueur », « surtout dans les zones rapides ») :
	-- la capture vue par le joueur (server/Services/Guard/ClientView). Cause : le serveur mesure entre SON vigile et la
	-- COPIE du voleur, qu'il reçoit en retard (réseau + tampon de réplication de la physique, même à ping 0) ; l'écran du
	-- joueur montre son personnage à sa vraie place et le vigile en retard lui aussi. À la capture, le joueur voyait donc
	-- le vigile à 3 studs + sa vitesse × retard montant + celle du vigile × retard descendant. Banc a416 (retard simulé :
	-- 0,25 s de tampons + 67 ms de ping), avec l'objet : 12,5 studs en zone 1 (29 studs/s), 16,1, 19,7, 23,2, 26,7, puis
	-- 30,2 en zone 6 (83 studs/s) et 44,1 au plafond de la marche (126) ; avec cette règle : 3,5 à toutes les vitesses.
	-- La compensation d'a193 n'y changeait presque rien : elle ne compte que le ping (≈ 0 en Studio), plafonne l'avance à
	-- LagMaxStuds, et le vigile butait sur la copie (LagContactReach : capture à 3 studs de la copie).
	-- Avec Enabled, pour un voleur que les vigiles traversent (groupes de collision, plus bas), tous les poursuivants :
	--   1. retard = min(BaseSeconds + GetNetworkPing × LagPingFactor, MaxSeconds) : BaseSeconds = les deux tampons de
	--      réplication (personnage vers le serveur, vigile vers le client), qui restent à ping 0 ;
	--   2. position estimée du voleur = position reçue + vitesse au sol (bornée à sa WalkSpeed) × retard, sans plafond en
	--      studs, arrêtée WallMargin studs avant un mur : distance gardée et point visé s'y mesurent (comme a193). Le
	--      vigile se tient donc là où ce joueur le verra à la bonne distance, souvent DEVANT la copie du serveur ;
	--   3. capture seulement quand ce joueur a VU le vigile le toucher : distance entre la position reçue du voleur et la
	--      place du vigile `retard` s plus tôt (son relevé de positions, côté serveur) ≤ la portée, sans mur entre ces
	--      deux points (CatchReach). Rien ne vient du client ; une position estimée ne déclenche jamais une capture
	--      (demi-tour, départ arrêté : pas de capture de loin). Plus de capture au contact de la copie ;
	--   4. le vigile ne heurte plus les joueurs : groupe « Guards » sans collision avec « Players » (PlayerCollisionService)
	--      et « NightPass » (mur de nuit) ; un personnage poursuivi encore en « Default » passe en « Players ». Sans cela
	--      il bute sur la copie et ne peut pas se tenir devant elle. Tant qu'un voleur heurte encore les vigiles (groupes
	--      indisponibles), la règle d'avant s'applique pour lui (LagCompensation, LagContactReach) : jamais inoffensif ;
	--   5. sur un voleur à l'arrêt, il s'arrête net à StandOff studs (son élan le porterait dans le joueur), puis la
	--      capture vient dès que le serveur sait que le joueur l'a vu arriver (≈ un aller-retour plus tard) ;
	--   6. autour de la capture : dès qu'elle est attendue dans DisplaySeconds s (même mesure, avancée d'autant), le
	--      vigile s'arrête net : le joueur le voit s'arrêter au moment où il est immobilisé, sans le dépasser. Ensuite,
	--      pendant SettleSeconds s, il rejoint à SettleSpeed le joueur qui glisse encore sur son élan, jusqu'à StandOff.
	-- Un retard mal estimé décale seulement le vigile à l'écran, de vitesse × erreur (0,05 s : 4 studs à 83 studs/s) ; le
	-- moment de la capture ne change pas (distance prévue du serveur) : gonfler son ping ne fait rien gagner.
	-- Enabled = false : la règle d'avant (a193) pour tous.
	ClientView = {
		Enabled = true, -- V0 proposé (Cantin, 23/11), à confirmer
		-- V0 proposé (Cantin, 23/11), à confirmer en Play (recette T-1560 : distance vue en ligne droite − distance prévue,
		-- divisée par la vitesse, à ajouter ici). Vu en Play le 14/11 pour le seul trajet montant : 0,12 à 0,37 s à ping 0
		-- (Balance.Heist.ReachLatencyPad).
		BaseSeconds = 0.25,
		-- V0 proposé (Cantin, 23/11), à confirmer en Play : la part de BaseSeconds due à l'affichage du vigile chez le
		-- client (le reste : le trajet du personnage vers le serveur). Le vigile dépasse le joueur à la capture : plus ;
		-- il s'arrête trop tôt, puis fait un pas : moins. Jamais plus que la moitié du retard.
		DisplaySeconds = 0.12,
		MaxSeconds = 0.6, -- V0 proposé (Cantin, 23/11), à confirmer : plafond du retard compensé (s), ping compris
		WallMargin = 1, -- V0 proposé (Cantin, 23/11), à confirmer (studs)
		StandOff = 3, -- V0 proposé (Cantin, 23/11), à confirmer (studs ; sous la portée de capture, 4)
		StillSpeed = 2, -- V0 proposé (Cantin, 23/11), à confirmer : voleur « à l'arrêt » sous cette vitesse reçue (studs/s)
		SettleSeconds = 0.4, -- V0 proposé (Cantin, 23/11), à confirmer (s)
		SettleSpeed = 16 * K, -- V0 proposé (Cantin, 23/11), à confirmer (studs/s : la marche d'un joueur neuf, × k)
	},
	-- Vague 72 (a241, L-219 point 2, Clément : « je casse la boutique, je rentre, je ressors : pas de poursuite ») :
	-- un intrus (entré dans Bounds après la casse) qui en ressort SANS objet avant la fin du chrono « HEIST » est
	-- poursuivi tout de suite par le vigile du magasin (GuardService.ChaseIntruder, depuis le GuardSpawn), comme
	-- l'intrus resté dedans à la fin du chrono : Balance.Guard.IntruderChaseTime s de poursuite, sans fin s'il prend un
	-- objet. false : la règle d'avant (Cantin, 2026-11-13 : sorti sans rien, c'est fini pour lui, aucun vigile).
	-- Le casseur resté dehors (jamais entré) n'est pas concerné. V0 proposé, absent du doc.
	ChaseOnEmptyExit = true,
	-- a249 (Cantin, 2026-11-17, L-235 décision 1 : garder « Hold », mais une ruée nettement moins forte, sans l'effet
	-- « très vite puis très lent », et le vigile ne lâche jamais prise). Play du 17/11 : la ruée (RushWalkFactor × la
	-- marche, ≥ RushMinSpeed : 156 à 329 studs/s) freinait à RushBrake (1 000 studs/s²) alors que le Humanoid ne freine
	-- qu'à ≈ 700 : il finissait à 8 à 9 studs au lieu de 14, jusqu'à 2,4 studs (capture) si le voleur ralentissait.
	-- SpringReturn = true : le vigile du magasin (Apply.StoreGuard) ne fait plus de ruée. Sa vitesse est toujours
	--   marche du voleur + rapprochement + un surplus selon l'écart à la distance prévue (GuardService.springSpeed) :
	--   loin, au plus (SpringMaxFactor − 1) × la marche ; en arrivant, il freine à SpringBrake, puis le rappel
	--   (HoldRecallGain, HoldRecallMax) sur les 4 derniers studs, sans à-coup ; au-dessus du minimum, il garde
	--   HoldDistance studs et revient dès que le voleur s'éloigne (jamais d'abandon). Sur un voleur qui ralentit ou
	--   s'arrête, le plafond d'arrivée (ApproachBrake) freine à SpringBrake au lieu de RushBrake.
	--   false : la ruée d'avant. Vigile de nuit, policier, conducteur : la ruée, inchangée (ils attrapent toujours).
	SpringReturn = true,
	SpringMaxFactor = 1.5, -- V0 proposé, absent du doc : au plus × la marche du voleur (ruée d'avant : 3,9)
	SpringBrake = 20 * K * K, -- V0 proposé, absent du doc (studs/s², × k² : 80), bien sous ce que freine un Humanoid
	-- a249 (Cantin, 2026-11-18 : « plus vite de loin ») : Play de fusion68, 10 à 11 s entre la prise et le vigile à
	-- 14 studs (zone 1 : 11,15 s ; zone 5 : 10,11 s ; profil rapide, 76 studs/s avec l'objet), le vigile ne regagnant
	-- que (SpringMaxFactor − 1) × la marche = 38 studs/s. SpringFar = true (en retour doux) : loin du voleur, au plus
	-- SpringFarFactor × la marche, atteint à SpringFarDistance studs et au-delà ; en approchant, il redescend en continu
	-- (au plus SpringFarBrake studs/s²) jusqu'à SpringMaxFactor × la marche, puis le freinage SpringBrake et la tenue à
	-- HoldDistance d'avant : ni à-coup, ni longue approche au ralenti. Si un freinage plus doux que SpringFarBrake suffit
	-- pour atteindre SpringFarFactor à SpringFarDistance, il le prend ; sinon il ne l'atteint qu'un peu plus loin (profil
	-- rapide : ≈ 63 studs). false : au plus SpringMaxFactor × la marche, à toute distance.
	SpringFar = true,
	SpringFarFactor = 2.5, -- V0 (Cantin : ≈ 2,5 × la marche, de loin)
	SpringFarDistance = 40, -- V0 (Cantin : au-delà d'≈ 40 studs)
	SpringFarBrake = 40 * K * K, -- V0 proposé, absent du doc (studs/s², × k² : 160), toujours sous ce que freine un Humanoid
	-- a249 (Plays du 18/11 : le vigile mettait ≈ 3,3 à 4 s à sortir du magasin, autour de Shelf_A_Spine ; il allait de
	-- point en point du chemin, tous les 4 studs, à ≈ 40 studs/s réels pour 114 de WalkSpeed). Derrière un
	-- obstacle, le vigile vise le plus loin des PathLookahead points suivants du chemin qu'il peut joindre tout droit
	-- (rayons au centre, aux genoux et sur ses flancs, même hauteur de sol, jamais au-delà d'un saut ni par la zone
	-- safe) : il coupe les coins au lieu de s'arrêter à chaque point. 0 : point par point, la règle d'avant.
	PathLookahead = 8, -- V0 proposé, absent du doc
	-- a249 (L-235 décision 2) : le vigile du magasin part StartDelay s après la prise (apparition, objet ramassé au
	-- sol ; avant : 0,5 s, toujours le délai du vigile de nuit, du policier et du conducteur). WaitAfterReveal : après
	-- la cinématique d'ouverture (RevealProtected), tout poursuivant figé repart StartDelay s plus tard, sans capture
	-- avant (false : il repartait tout de suite).
	StartDelay = 1, -- V0 (Cantin : 1 s)
	WaitAfterReveal = true,
	-- a249 (Play de fusion67, petit chef 2 : le vigile de nuit attrape, puis le vigile de jour « rattrape » 1,3 s
	-- après) : un joueur attrapé (immobilisé par une capture, ou attrapé la nuit et pas encore renvoyé) n'est plus
	-- poursuivi ; les autres poursuivants abandonnent. false : la règle d'avant (deux captures possibles).
	OneCatchAtATime = true,
	-- a249 (Play de fusion68 : à la Supérette, un voleur coincé contre un rayon n'a jamais été attrapé, plus de 40 s ;
	-- le vigile était à 2,2 studs, à portée, mais le bout du rayon (Shelf_A_EndA, 0,3 stud) coupait chaque rayon de
	-- CatchReach.CanTouch, et le chemin ne menait pas plus près). StuckCatch = true : un voleur à portée de capture
	-- (CatchReach.InRange, sa position sur le serveur) qui n'a pas bougé de StuckMoveMax studs à l'horizontale depuis
	-- StuckCatchTime s est attrapé même sans ligne de vue (« coincé ») ; il pousse contre l'obstacle mais n'avance pas,
	-- il est approché et attrapé comme un voleur arrêté (le plafond d'arrivée compte sa vitesse lue pour 0). Sans ligne
	-- de vue, seulement si le vigile est bloqué lui aussi (pas bougé de StuckMoveMax studs depuis StuckCatchTime s), au
	-- même étage (StuckHeightMax studs d'écart au plus) et derrière un panneau mince : la ligne entre eux ne traverse pas
	-- plus de StuckWallMax studs de pièces qui bloquent (bout de rayon 0,3, dos 0,45 ; jamais un mur de 1 stud ni un
	-- plancher : banc a146). Vigile du magasin, policier, conducteur ; le vigile de nuit garde la ligne
	-- de vue. false : la règle d'avant (ligne de vue exigée).
	StuckCatch = true,
	StuckCatchTime = 0.3, -- V0 proposé, absent du doc (s)
	StuckMoveMax = 1, -- V0 proposé, absent du doc (studs)
	StuckWallMax = 0.75, -- V0 proposé, absent du doc (studs)
	StuckHeightMax = 3, -- V0 proposé, absent du doc (studs, entre les deux HumanoidRootPart)
	-- a250 (Play de fusion68, Confiserie : attrapé « coincé » à travers la porte vitrée DoorGlass_L, 0,3 stud) : le
	-- panneau mince doit être un rayon des deux côtés, c.-à-d. la pièce touchée par chaque rayon (ou un de ses parents)
	-- a un nom qui commence par StuckThinPrefix ; une porte, une vitrine, un mur, un frigo ou un comptoir reste un mur,
	-- quelle que soit son épaisseur. "" : tout panneau de StuckWallMax studs au plus (la règle d'avant).
	StuckThinPrefix = "Shelf", -- V0 proposé, absent du doc (rayons des magasins : Shelf_A_EndA, Shelf_WallL_Back…)
	-- a250 (Play de fusion68 : un vigile qui marchait encore à 3 studs/s vers un voleur arrêté passait pour bloqué) ;
	-- a250b (Play de fusion69 : le voleur coincé derrière Shelf_A_EndA attendait 1,4 s de plus) : en terrain ouvert
	-- (la ligne entre eux ne touche rien), le vigile n'est bloqué que si, sur les dernières StuckCatchTime s (fenêtre
	-- glissante), il a parcouru au plus StuckMoveMax studs et au plus StuckProgressShare de ce que sa marche (au moins
	-- ApproachMinClosing) lui ferait parcourir ; derrière un panneau de rayon (StuckThinPrefix), StuckMoveMax studs
	-- suffisent (il longe le rayon). 0 : seulement StuckMoveMax depuis son dernier mouvement (la règle d'avant).
	StuckProgressShare = 0.25, -- V0 proposé, absent du doc
	-- a250 (Play de fusion68, Supérette : voleur coincé derrière Shelf_A_EndA attrapé 3,3 à 3,4 s après l'arrivée du
	-- vigile, qui contournait le rayon à 3-10 studs/s) : quand le vigile suit un chemin, le plafond d'arrivée
	-- (ApproachBrake) mesure d sur la longueur du chemin qui reste, jamais moins que la ligne droite : il ne freine plus
	-- dans le détour comme s'il était déjà arrivé. false : d en ligne droite (la règle d'avant).
	ApproachAlongPath = true, -- V0
	-- a250b (Play de fusion69, Supérette : le même voleur attrapé 4,2 s après les 14 studs, le vigile freinant à
	-- ApproachBrake tout le détour) : voleur arrêté (StuckMoveMax en StuckCatchTime s) et hors de vue du vigile (son
	-- dernier pas de pilotage passait par un chemin) : il ne voit pas arriver le vigile, le plafond d'arrivée freine à
	-- ApproachBrakeHidden (studs/s² réels) au lieu d'ApproachBrake, sauf s'il l'a vu arrêté depuis son dernier
	-- mouvement ; et sur un voleur arrêté, le plafond ne remonte plus (chemin recalculé). 0 : ApproachBrake partout
	-- et plafond libre (la règle d'avant).
	ApproachBrakeHidden = 20, -- V0 proposé, absent du doc (studs/s²)
	-- a250b (même Play : sauté 4,5 studs avant la table Promo_A, retombé à son pied, 0,7 s à s'y hisser) : au point de
	-- saut d'un chemin, le vigile saute quand l'obstacle à hauteur de genou est à moins de WalkSpeed × PathJumpLead
	-- + 1 stud devant lui, ou à 2 studs du point. 0 : dès qu'il vise le point (la règle d'avant).
	PathJumpLead = 0.3, -- V0 proposé, absent du doc (s)
	-- a252 (Play de fusion69 b, Supérette : sauté 3,9 à 4 studs avant Promo_A, 0,5 s en l'air, car WalkSpeed 14,4 × 0,3
	-- = 4,3 studs) : l'avance WalkSpeed × PathJumpLead est plafonnée à PathJumpLeadMax studs (le « + 1 stud » reste).
	-- 0 ou absent : sans plafond (la règle d'avant).
	PathJumpLeadMax = 1.5, -- V0 proposé, absent du doc (studs)
	-- f70c3 (Play de diagnostic de fusion70, Supérette : le chemin du vigile passait toujours par-dessus la table basse
	-- Promo_A, 5,4 × 1,9 × 2,2 ; il y montait, sautait à +7 studs, et le voleur qui pousse derrière Shelf_A_EndA était
	-- attrapé en 2,02 s pour 2) : server/Services/Guard/PathAvoid pose au démarrage un PathfindingModifier (Label) sur
	-- chaque pièce d'un magasin PNJ (tag NPCStore) dont le nom, ou celui d'un parent, commence par un des Prefixes ;
	-- l'agent des vigiles paie Cost fois plus cher chaque stud dessus : il contourne ces présentoirs bas et n'y monte
	-- que s'il n'y a pas d'autre passage ; en coupant les coins d'un chemin, il teste aussi ses flancs à hauteur des
	-- genoux (il ne rogne plus le coin d'une table basse). Enabled = false : rien de tout ça (la règle d'avant).
	-- JumpMargin : un saut de chemin monte de la marche à franchir (point d'arrivée moins point de saut) + JumpMargin
	-- studs, au moins JumpMin, jamais plus que le saut du rig ; saut sans marche à monter : le saut du rig.
	-- 0 : toujours le saut du rig (7,2 studs, la règle d'avant).
	-- f70c3b (Play de rejeu de fusion71 : 24 pièces marquées, mais le vigile sautait encore sur Promo_A depuis 2 studs
	-- de son bord ; le modificateur posé sur la pièce ne couvre pas son dessus) : chaque pièce marquée reçoit aussi un
	-- volume invisible (ni collision, ni rayon, ni contact) de son empreinte, de son bas jusqu'à Headroom studs au-dessus
	-- d'elle, avec le même Label ; Cost = math.huge : l'agent ne passe jamais par là (ni dessus ni par un saut). En plus,
	-- aucun saut de chemin dont le point de saut ou le suivant est à moins de JumpNear studs d'une pièce marquée.
	PathAvoid = {
		Enabled = true, -- V0 : contournement des présentoirs bas
		Prefixes = { "Promo_" }, -- V0 proposé, absent du doc (question à Clément : d'autres présentoirs bas ?)
		Label = "GuardAvoid", -- nom de la zone pour PathfindingService (Costs de l'agent)
		Cost = math.huge, -- V0 proposé, absent du doc (× le coût d'un stud de sol ; math.huge : interdit)
		Headroom = 4, -- V0 proposé, absent du doc (studs au-dessus de la pièce couverts par le volume)
		JumpNear = 3, -- V0 proposé, absent du doc (studs ; 0 : pas d'interdiction de saut)
		JumpMargin = 2, -- V0 proposé, absent du doc (studs)
		JumpMin = 3, -- V0 proposé, absent du doc (studs)
	},
	-- f70c3b (T-217, Play de rejeu de fusion71, Kiosque : en poursuite directe dans la rue, le vigile percutait le
	-- lampadaire Lamp_S1, 1,35 stud de large, et passait de 93 à 49 studs/s en une image) : en vue, avant chaque MoveTo
	-- vers le point visé (GuardService chaseInSight), server/Services/Guard/Sidestep tire des rayons le long de ses
	-- flancs (à hauteur du centre et des genoux). Si l'un touche un obstacle fin (pièce qui collisionne, au plus ThinMax
	-- studs en X et en Z), il vise d'abord un point Beyond studs après l'obstacle, décalé de son côté libre du plus petit
	-- multiple de ShiftStep (au plus ShiftMax) qui laisse son couloir libre. Murs et gros obstacles : rien ne change.
	-- Enabled = false : droit sur le point visé (la règle d'avant).
	Sidestep = {
		Enabled = true, -- V0 : contournement des poteaux en poursuite directe
		ThinMax = 3, -- V0 proposé, absent du doc (studs)
		Beyond = 1.5, -- V0 proposé, absent du doc (studs)
		ShiftStep = 0.5, -- V0 proposé, absent du doc (studs)
		ShiftMax = 4, -- V0 proposé, absent du doc (studs)
	},
	-- a252 (L-244, Clément, 2026-11-18 : « on voit notre personnage tomber, et après le vigile récupère l'objet ») : quand
	-- l'objet porté revole sur son rayon après une capture par le vigile d'un magasin PNJ (capture dans son magasin, ou
	-- Chase.ReturnToShelfAfterCatches-ième capture), il passe d'abord par la main du vigile (server/Services/Guard/
	-- CatchPickUp) : au coup (marqueur Impact de Catch), l'objet tombe au sol entre les deux, le vigile joue PickUp et le
	-- prend en main au marqueur Grab, le tient, puis l'objet revole sur son rayon depuis sa main ; le joueur reste au sol
	-- (Knockdown arrêtée sur son marqueur Land, ChaseController) jusque-là, puis joue GetUp. Rien ne change aux règles
	-- (étourdissement, pertes) ; l'objet revient sur son rayon au plus MaxAfterImpact s plus tard qu'avant.
	CatchPickUp = {
		Enabled = true, -- V0 : interrupteur (false : l'objet revole dès la capture, comme avant)
		-- V0 false (question à Clément) : true = le vigile ramasse à CHAQUE capture d'un objet de magasin PNJ, dans la rue
		-- aussi, et l'objet revole toujours sur son rayon (aujourd'hui, dans la rue, il reste au sol, gardé par le
		-- vigile, et n'importe qui peut le reprendre : décision de Cantin du 13/11).
		Always = false,
		Reach = 2.5, -- V0 : l'objet tombe à 2,5 studs devant le vigile, vers le joueur (studs)
		FallTime = 0.3, -- V0 : durée de la chute (s)
		FallArc = 1.5, -- V0 : hauteur de l'arc de la chute (studs)
		PickUpDelay = 0.2, -- V0 : le vigile se baisse 0,2 s après le coup (s)
		GrabFallback = 0.5, -- V0 : PickUp absente (ou sans marqueur Grab) : en main 0,5 s après le début du geste (s)
		HoldTime = 0.4, -- V0 : il le tient 0,4 s, puis l'objet revole (s)
		HandMaxSize = 3, -- V0 : un objet plus grand est réduit à 3 studs (plus grand côté) dans sa main
		MaxAfterImpact = 1.6, -- V0 : l'objet revole au plus tard 1,6 s après le coup (étourdissement : 2,4 s)
		MaxAfterCatch = 2.2, -- V0 : sans coup (joueur protégé par sa cinématique), au plus tard 2,2 s après la capture
	},
	-- a252 (L-244) : la caméra de la capture (CatchSceneController) : plan large de côté qui montre le joueur et celui qui
	-- l'attrape en entier, puis retour. Toujours en deçà d'un mur s'il le peut ; sinon derrière, et tout ce qui reste
	-- entre la caméra et les deux corps devient transparent pour ce joueur (LocalTransparencyModifier), puis revient.
	-- Enabled = false : le plongeon d'avant (HeistFeel.Catch.Dive*).
	CatchShot = {
		Enabled = true, -- V0
		MoveTime = 0.35, -- V0 : la caméra glisse vers le plan large (s)
		Margin = 3, -- V0 : marge autour des deux corps (studs)
		BodyHeight = 7, -- V0 : hauteur à cadrer (vigile jusqu'à 1,4 × un R15) (studs)
		FocusRise = 0.5, -- V0 : point visé au-dessus du milieu des deux HumanoidRootPart (studs)
		Rise = 1.5, -- V0 : caméra au-dessus du point visé (studs)
		MinDistance = 9, -- V0 (studs)
		MaxDistance = 30, -- V0 (studs)
		SideAngle = 25, -- V0 : en plus du plein côté, essais à ± 25° (degrés)
		WallPad = 0.6, -- V0 : distance gardée devant un mur (studs)
		Fade = 0.8, -- V0 : LocalTransparencyModifier des pièces qui gênent
		MaxHidden = 40, -- V0 : pièces cachées au plus
		Recheck = 0.1, -- V0 : nouveau test des gêneurs toutes les 0,1 s
	},
	-- a252 (L-245 et L-238 c ; Clément, 2026-11-18 : « le vigile de nuit renvoie vers la base ») : le vigile de nuit renvoie
	-- déjà à la boutique après Arrest (NightCycleService.SendHome). La reprise 5,9 s plus tard vue au Play du 17/11 suivait
	-- une capture par le VIGILE DU MAGASIN, la nuit, qui laissait le joueur dans le couloir. V0 (question à Clément) : true =
	-- une capture par le vigile d'un magasin la nuit, dans le couloir, renvoie aussi à la boutique, DayCatchAtNightDelay s
	-- après le coup (pertes inchangées) ; false = relâché sur place (la règle d'avant).
	DayCatchAtNightSendsHome = true,
	DayCatchAtNightDelay = 2, -- V0 (s ; après le ramassage de l'objet, avant la fin de l'étourdissement, 2,4 s)
	-- a249 : diagnostic de la poursuite dans la sortie (aussi hors Studio) : chaque seconde, la distance, la phase,
	-- la distance prévue et les parts de la vitesse du vigile ; à chaque capture, la distance, le temps depuis
	-- l'apparition et dedans/dehors. En Studio, workspace:SetAttribute("ChaseDebug", true) fait de même.
	Debug = false,
	-- a277 (L-249, L-238 a, Clément : « Run est faite pour une course normale ») : course du vigile de magasin
	-- (server/Services/Guard/Gait). Au-dessus de FromFactor × sa course normale (la vitesse de poursuite de sa zone), il
	-- joue Sprint au lieu de Run ; il revient à Run sous BackFactor × (écart pour ne pas alterner sans cesse). Vitesse de
	-- lecture de Sprint = WalkSpeed / (Reference × échelle du modèle), bornée de RateMin à RateMax (comme Run). Sprint
	-- absente du modèle (pas encore livrée : orange au ContractChecker) ou Enabled = false : Run, comme avant.
	Sprint = {
		Enabled = true, -- V0
		FromFactor = 1.3, -- V0 proposé (Cantin, 23/11), absent du doc
		BackFactor = 1.15, -- V0 proposé (Cantin, 23/11), absent du doc
		-- V0 proposé (Cantin, 23/11), à confirmer par Clément : la vitesse au sol (studs/s, échelle 1) pour laquelle Sprint
		-- est faite (Run : ~20, Walk : ~10).
		Reference = 30,
		RateMin = 0.6, -- comme Run (GuardService GAIT_SPEED_MIN)
		RateMax = 1.6 * K, -- comme Run (GuardService GAIT_SPEED_MAX)
		Fade = 0.2, -- V0 proposé (Cantin, 23/11) : fondu entre Run et Sprint (s)
	},
	-- Qui suit cette règle (false : la vitesse d'avant, voir l'en-tête).
	Apply = {
		StoreGuard = true, -- vigile de jour d'un magasin PNJ
		NightGuard = true, -- vigile de nuit
		Police = true, -- policier appelé par un témoin
		TruckDriver = true, -- conducteur du camion
	},
}

export type Chase = typeof(Chase)

return DeepFreeze(Chase)
