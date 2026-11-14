--!strict
-- Entraînement sur sa parcelle : le tapis (Vitesse) (Partie 1, sections 5.1, 7.5 et 9.4).
-- Rééquilibrage v2 (Cantin, 2026-11-14) : plus de banc ni de Force. Gain du tapis par seconde =
-- GainPerSecond × GainGrowth^(niveau affiché − 1), niveau affiché de 1 à 20 = niveau enregistré de
-- Upgrades.Treadmill + 1 (calcul dans Formulas.TreadmillGain) : 1, 2, 4… 524 288 par seconde.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Training = {
	-- Tapis sans invite depuis L-071 (2026-11-08), par sa zone depuis L-093 (TrainingService).
	Treadmill = {
		GainPerSecond = 1, -- Cantin, 2026-11-14 : le niveau 1 rapporte 1 de Vitesse par seconde…
		GainGrowth = 2, -- … multiplié par 2 à chaque niveau du tapis
		AfkAllowed = true,
		TapBonus = 0.5, -- taper l'écran donne +50 % de gain
		TapBonusWindow = 1, -- V0 proposé, absent du doc : durée du bonus après un tap
		MaxTapsPerSecond = 6, -- TrainTap au tapis (9.4)
	},

	-- Section 3, étape 6 : le tapis s'allume, 30 s d'entraînement guidé
	GuidedDuration = 30,
}

export type Training = typeof(Training)

return DeepFreeze(Training)
