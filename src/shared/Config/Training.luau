--!strict
-- Entraînement sur sa parcelle : tapis (Vitesse) et banc (Force) (Partie 1, sections 5.1, 7.5 et 9.4).
-- Multiplicateur d'une machine = BaseMultiplier + 0,5 × niveau de son amélioration
-- (Upgrades.Treadmill / Upgrades.Bench, calcul dans Formulas.MachineMultiplier).

local DeepFreeze = require(script.Parent.DeepFreeze)

local Training = {
	-- Le doc donne « +0,5 au multiplicateur » par niveau sans écrire la valeur de
	-- départ : 1, déduit de 5.1 (+1 par seconde ou par répétition au niveau 0).
	BaseMultiplier = 1,

	-- Tapis sans invite depuis L-071 (2026-11-08) : marcher dessus fait s'entraîner (TrainingService).
	Treadmill = {
		GainPerSecond = 1, -- +1 Vitesse par seconde × multiplicateur du tapis
		AfkAllowed = true,
		TapBonus = 0.5, -- taper l'écran donne +50 % de gain
		TapBonusWindow = 1, -- V0 proposé, absent du doc : durée du bonus après un tap
		MaxTapsPerSecond = 6, -- TrainTap au tapis (9.4)
	},

	Bench = {
		Prompt = "Lift",
		GainPerRep = 1, -- +1 Force par répétition × multiplicateur du banc
		MaxRepsPerSecond = 3, -- 1 tap = 1 répétition, 3 par seconde au plus (5.1, 9.4)
	},

	-- Section 3, étape 6 : le tapis et le banc s'allument, 30 s d'entraînement guidé
	GuidedDuration = 30,
}

export type Training = typeof(Training)

return DeepFreeze(Training)
