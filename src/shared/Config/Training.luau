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
		-- a180 (Cantin, 2026-11-15) : on ne monte qu'arrivé sur la bande par un de ses grands côtés (passer
		-- devant ou derrière ne déclenche rien ; Shared/TrainingZone.track). Interrupteur : false = règle
		-- d'avant (on monte dès l'entrée dans la zone), gardée pour les bancs qui la vérifient.
		SideEntryOnly = true,
		-- a310 : V0, demande de Cantin, 22/11 (« il suffit d'arriver contre un grand côté ») : marge (studs) dont
		-- l'emprise d'entrée déborde de la bande, en travers seulement (les deux grands côtés ; les bouts avant
		-- et arrière restent stricts). Un perso R15 collé au côté a le centre de son HumanoidRootPart à environ
		-- 1 stud du bord de la bande : 1,5 le couvre, avec une demi-stud pour le rebord du châssis et une
		-- arrivée un peu en biais. 0 = règle d'a180 (au-dessus de la bande elle-même).
		SideEntryMargin = 1.5,
		-- a200 (Cantin, 2026-11-15 : « quand on l'améliore, parfois ça nous arrête […] il faudrait que ça
		-- continue ») : quand MachineVariantService remplace le tapis (nouveau palier), la séance passe sur le
		-- nouveau tapis de la même parcelle sans s'arrêter. V0 proposé, absent du doc : délai (s) pendant
		-- lequel une séance dont le tapis vient d'être retiré attend son remplaçant avant de finir.
		SwapGrace = 0.5,
	},

	-- Section 3, étape 6 : le tapis s'allume, 30 s d'entraînement guidé
	GuidedDuration = 30,
}

export type Training = typeof(Training)

return DeepFreeze(Training)
