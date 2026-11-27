--!strict
-- Coups plus secs et course portée calée (a519, L-448 ; Clément, 2026-11-26, repasse animation point 12 : « oui »).
-- Lu par Shared/Anim/StrikeFeel (AnimationController, ShatterController, Reveal/Unbox), allumé par
-- Features.StrikeFeel / StrikeFeelDev. Le code ne retouche jamais l'animation de Clément : seulement le fondu au
-- lancement, la vitesse de lecture et un arrêt sur image, côté client, sur le joueur local.
-- Sources : « L-448 » : la ligne de la liaison ; « V0 » : V0 proposé (Cantin, 2026-11-27), absent du doc.

local DeepFreeze = require(script.Parent.DeepFreeze)

local AnimFeel = {
	-- Fondu (s) du lancement d'un coup : les animations du joueur au marqueur Impact, sans boucle (Contract/Animations :
	-- HitWindow, HitWindowHeavy, SwingBat, Unbox_*). L-448 : « de 0 à 0,03 s au lieu de 0,1 s » ; V0 : 0,03.
	StrikeFade = 0.03,
	-- Arrêt sur impact (s) au marqueur Impact, sur la piste du coup seule (L-448 : « 40, 70 ou 100 ms selon le coup »).
	-- V0 : léger 40 ms (coups répétés vite), moyen 70 ms, lourd 100 ms (coup final ou outil lourd).
	Hitstop = {
		Default = 0.04, -- V0 : tout coup absent de la liste ci-dessous
		HitWindow = 0.04, -- V0 : léger, jusqu'à 5 coups par seconde
		HitWindowHeavy = 0.1, -- V0 : lourd (Marteau à la Disqueuse)
		SwingBat = 0.07, -- V0 : moyen
		Unbox_Kick = 0.07, -- V0 : moyen
		Unbox_Stomp = 0.07, -- V0 : moyen
		Unbox_Slam = 0.1, -- V0 : lourd, le coup qui casse le colis
	} :: { [string]: number },
	-- Course portée (CarryRun, haut du corps) : vitesse de lecture = vitesse au sol / RunRefSpeed, bornée.
	Run = {
		Names = { "CarryRun" }, -- L-448 : les courses du joueur jouées par le code (les jambes suivent le script Animate de Roblox)
		RefSpeed = 16, -- V0 : studs/s auxquels l'animation joue à sa vitesse d'origine (marche de base de Roblox)
		MinRate = 0.5, -- V0
		MaxRate = 3, -- V0 : au-delà, les bras battent trop vite pour se lire
	},
}

export type AnimFeel = typeof(AnimFeel)

return DeepFreeze(AnimFeel)
