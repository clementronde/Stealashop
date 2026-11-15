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
--      rapprochement 4 studs/s, ils attrapent toujours (environ 1,5 s après la ruée), sauf si la poursuite
--      finit avant (zone safe ; policier : durée de WitnessService).
--   6. Conducteur du camion : même ruée, puis la marche du voleur × (1 + DriverGrowthPerSecond × secondes
--      depuis la fin de la ruée), au plus × DriverMaxFactor : il rattrape de plus en plus vite.
-- Speed effective = Speed du profil × multiplicateur du trail (StatsService.GetTrailMultiplier), celle du
-- HUD et de Formulas.WalkSpeed (Cantin : un trail ×2 double la Speed).
-- Vitesse imposée par le tutoriel (GuardService.GetSpeedOverride) : l'ancienne règle, sans ruée.
-- Features.GuardChaseV2 = false, ou Apply.<X> = false : la vitesse d'avant (Zones[zone].GuardSpeed,
-- Night.ChaseSpeed, vitesse fixe du policier, × la marche de sa cible pour le conducteur).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type AboveRequired = "Hold" | "Gain"

local Chase = {
	RushWalkFactor = 3, -- ruée : × la marche du voleur
	RushMinSpeed = 60, -- ruée : au moins (studs/s)
	HoldDistance = 10, -- fin de la ruée, à l'horizontale (studs)
	ClosingSpeedMax = 8, -- rapprochement à 0 % du minimum (studs/s)
	HoldMinSpeed = 12, -- plancher de la poursuite à distance (studs/s), sous toute marche d'un voleur qui court
	AboveRequired = "Hold" :: AboveRequired, -- Cantin, 2026-11-14 : au-dessus, « ça garde toujours la même distance »
	Zone1SpeedRequired = 0, -- minimum de la zone 1 pour cette règle (Cantin : zone 1 sans minimum)
	NightGuardRequiredFactor = 2, -- vigile de nuit : minimum = Speed effective actuelle du voleur × ceci (Cantin)
	PoliceRequiredFactor = 2, -- policier : minimum = Speed effective actuelle du voleur × ceci (Cantin)
	DriverGrowthPerSecond = 0.02, -- conducteur : + 2 % de la marche du voleur par seconde depuis la fin de la ruée
	DriverMaxFactor = 2, -- conducteur : au plus × la marche du voleur
	-- a173 (2026-11-15, Play de fusion48) : en poursuite à distance, rappel vers la distance prévue (la fin de
	-- ruée tombe 1 à 3 studs trop près quand les images n'ont pas la même durée, ou par l'élan du Humanoid) :
	-- vitesse + clamp(HoldRecallGain × (distance − distance prévue), −HoldRecallMax, +HoldRecallMax). Distance
	-- prévue = HoldDistance, qui baisse au rythme du rapprochement (vigile de nuit, policier : 4 studs/s), au
	-- moins la distance de capture. Pas pour le conducteur du camion.
	HoldRecallGain = 2, -- par seconde (V0)
	HoldRecallMax = 4, -- studs/s (V0)
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
