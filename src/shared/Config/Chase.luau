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
	-- ≈ 1,7 à 2 s ; jamais moins de ApproachMinClosing (il est toujours attrapé). En studs/s² et studs/s RÉELS, sans × k :
	-- Cantin veut voir arriver le vigile pendant une durée réelle. ApproachBrake = 0 : sans ce plafond (avant a224).
	ApproachBrake = 5, -- V0, absent du doc (studs/s²) ; Cantin 2026-11-16 : ralentir davantage en arrivant (10 → 5)
	ApproachMinClosing = 3, -- V0 proposé, absent du doc (studs/s)
	ClosingSpeedMax = 8 * K, -- rapprochement à 0 % du minimum (studs/s ; vague 61 : × k)
	HoldMinSpeed = 12 * K, -- plancher de la poursuite à distance (studs/s), sous toute marche d'un voleur qui court (× k)
	AboveRequired = "Hold" :: AboveRequired, -- Cantin, 2026-11-14 : au-dessus, « ça garde toujours la même distance »
	Zone1SpeedRequired = 0, -- minimum de la zone 1 pour cette règle (Cantin : zone 1 sans minimum)
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
