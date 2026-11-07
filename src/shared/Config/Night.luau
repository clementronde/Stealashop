--!strict
-- Cycle jour / nuit, une seule horloge par serveur (Partie 1, section 5.12, NightCycleService).
-- Un cycle = Jour (8 min, dont l'alerte des 30 dernières secondes) puis Nuit (2 min) ;
-- l'aube est instantanée.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- L'aube n'est pas une phase : c'est le passage instantané de Night à Day.
export type Phase = "Day" | "Warning" | "Night"

local Night = {
	DayDuration = 8 * 60,
	WarningDuration = 30, -- les 30 dernières secondes du jour
	NightDuration = 2 * 60,
	CycleDuration = 10 * 60, -- DayDuration + NightDuration

	WarningText = "NIGHT FALLS IN 30s", -- doc : « LA NUIT TOMBE DANS 30 S », en anglais (L-036)

	-- Vigiles de nuit (tag `NightPatrol` sur les points de ronde)
	GuardsPerZone = 2,
	DetectionRange = 40, -- dans le cône de la lampe torche
	DetectionConeAngle = 45, -- V0 proposé, absent du doc : demi-angle du cône, en degrés
	PatrolSpeed = 10, -- V0 proposé, absent du doc : WalkSpeed pendant la ronde
	ChaseSpeedBonus = 4, -- poursuite à la vitesse conseillée de la zone + 4
	CatchDistance = 4, -- V0 proposé, absent du doc : même valeur que le vigile de jour (5.5)
	GiveUpChaseDuration = 20, -- V0 proposé, absent du doc : même valeur que le vigile de jour (5.5)
	GiveUpLead = 120, -- V0 proposé, absent du doc : même valeur que le vigile de jour (5.5)

	-- Attrapé la nuit : colis rendu au magasin, retour à sa base, étourdi 2 s, aucune autre perte
	CaughtStunDuration = 2,

	-- Pendant le bouclier débutant (PvP.BeginnerShieldDuration), les vigiles de nuit ignorent le joueur
	IgnoreShieldedPlayers = true,
}

export type Night = typeof(Night)

return DeepFreeze(Night)
