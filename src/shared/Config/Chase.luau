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
	-- a249 : diagnostic de la poursuite dans la sortie (aussi hors Studio) : chaque seconde, la distance, la phase,
	-- la distance prévue et les parts de la vitesse du vigile ; à chaque capture, la distance, le temps depuis
	-- l'apparition et dedans/dehors. En Studio, workspace:SetAttribute("ChaseDebug", true) fait de même.
	Debug = false,
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
