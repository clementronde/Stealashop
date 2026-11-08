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
	-- V0 d'Ironix (2026-11-08, liaison L-078), absent du doc : dès que plus aucun joueur n'est dans le
	-- couloir, la nuit ne dure plus qu'au plus ce nombre de secondes (on n'attend plus devant le mur
	-- pour rien). Les rayons se remplissent toujours à la tombée de la nuit.
	EmptyCorridorRemaining = 30,
	CycleDuration = 10 * 60, -- DayDuration + NightDuration

	WarningText = "NIGHT FALLS IN 30s", -- doc : « LA NUIT TOMBE DANS 30 S », en anglais (L-036)

	-- Compte à rebours UI_HUD.NightCountdown (HudController), en anglais (L-036). %s = « 7:42 »
	-- (« 45s » sous une minute), %d = secondes.
	DayCountdownText = "Night in %s", -- liaison L-036 : « Nuit dans … » devient « Night in … »
	WarningCountdownText = "NIGHT FALLS IN %ds", -- V0 proposé, absent du doc : WarningText qui décompte (30s → 1s)
	NightCountdownText = "Dawn in %s", -- V0 proposé, absent du doc : pendant la nuit, temps avant l'aube

	-- Mur de nuit (tag `NightWall`, livré baissé : état jour). La nuit, il monte de sa hauteur
	-- (boîte englobante), ou de son attribut RiseHeight s'il en a un (proposition à Clément).
	WallRiseTime = 3, -- V0 proposé, absent du doc : durée de la montée (s)
	WallLowerTime = 2, -- V0 proposé, absent du doc : durée de la descente, à l'aube (s)
	-- V0 proposé, absent du doc : marge (studs) au-delà de chaque face du mur. Un joueur à plus de
	-- cette distance du côté safe n'est plus « dans le couloir » ; à plus de cette distance du côté
	-- couloir sans y avoir été à la tombée de la nuit, il y est entré : il est renvoyé chez lui.
	WallSideMargin = 4,

	-- Vigiles de nuit (tag `NightPatrol` sur les points de ronde)
	GuardsPerZone = 2,
	DetectionRange = 40, -- dans le cône de la lampe torche
	DetectionConeAngle = 45, -- V0 proposé, absent du doc : demi-angle du cône, en degrés
	PatrolSpeed = 10, -- V0 proposé, absent du doc : WalkSpeed pendant la ronde
	PatrolPause = 2, -- V0 proposé, absent du doc : pause à chaque point de ronde (s)
	ChaseSpeedBonus = 4, -- poursuite à la vitesse conseillée de la zone + 4
	CatchDistance = 4, -- V0 proposé, absent du doc : même valeur que le vigile de jour (5.5)
	GiveUpChaseDuration = 20, -- V0 proposé, absent du doc : même valeur que le vigile de jour (5.5)
	GiveUpLead = 120, -- V0 proposé, absent du doc : même valeur que le vigile de jour (5.5)

	-- Attrapé la nuit : colis rendu au magasin, retour à sa base, étourdi 2 s, aucune autre perte
	CaughtStunDuration = 2,
	-- V0 proposé, absent du doc : entre le coup du vigile (marqueur Impact de Catch) et le retour
	-- à la base, le temps de voir le coup (s).
	SendHomeDelay = 0.6,

	-- Pendant le bouclier débutant (PvP.BeginnerShieldDuration), les vigiles de nuit ignorent le joueur
	IgnoreShieldedPlayers = true,

	-- Ciel et lumière, côté client seulement, pendant le jeu (SkyController) : la place n'est jamais
	-- modifiée. Le jour, ce sont les réglages de Clément (Lighting) ; ces valeurs ne servent qu'à
	-- l'alerte et à la nuit. Toutes V0 proposées, absentes du doc.
	Sky = {
		DuskClockTime = 18.2, -- l'alerte amène le soleil jusqu'au couchant : « ciel qui rougit » (5.12)
		DuskTint = Color3.fromRGB(255, 120, 90), -- couleur mêlée à l'ambiance extérieure pendant l'alerte
		DuskTintAmount = 0.5, -- part de DuskTint à la fin de l'alerte (0 à 1)
		NightClockTime = 0, -- minuit
		NightOutdoorAmbient = Color3.fromRGB(70, 80, 125), -- nuit bleutée, assez claire pour jouer
		NightAmbient = Color3.fromRGB(45, 50, 80),
		NightBrightness = 1,
		TransitionTime = 3, -- tombée de la nuit et lever du jour (s)
	},
}

export type Night = typeof(Night)

return DeepFreeze(Night)
