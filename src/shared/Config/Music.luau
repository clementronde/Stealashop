--!strict
-- Musique de fond par zone (liaison L-056, demande de Clément du 2026-11-07 ; DEV-051). Lu par
-- MusicController (client). Le doc ne fixe aucune de ces valeurs.
--   Noms : ceux de Clément, acceptés par Ironix en L-056 (préfixe MUS_ en 10.3) ;
--   « V0 » : V0 proposé, absent du doc, à régler en jeu.
-- Unités : secondes, studs.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Music = {
	-- Pistes de Clément : des Sound en boucle, chacun avec son volume de départ (L-056).
	Folder = { "Assets", "Music" }, -- depuis ReplicatedStorage ; sous-dossiers permis
	HubTrack = "MUS_Hub", -- zone safe (tag SafeZone)
	ZoneTrack = "MUS_Z%d", -- MUS_Z1 à MUS_Z6 : zone du couloir, d'après les arches ZoneGate

	FadeTime = 2, -- V0 : durée d'un fondu enchaîné : l'ancienne piste descend pendant que la nouvelle monte
	CheckInterval = 0.25, -- V0 : zone du joueur revue 4 fois par seconde
	-- V0 : studs à faire au-delà du plan d'une arche avant de changer de piste, et autant en deçà pour
	-- revenir : un joueur arrêté sous l'arche ne fait pas aller et venir la musique.
	GateMargin = 2,

	-- Réglage du volume, point d'accroche sans écran (pas encore d'écran de réglages chez Clément) :
	-- attribut du Player local, de 0 (muet) à 1 (le volume de Clément) ; absent ou invalide : 1.
	-- Un futur écran le pose côté client, ou le serveur depuis la sauvegarde.
	VolumeAttribute = "MusicVolume", -- V0 : nom proposé
}

export type Music = typeof(Music)

return DeepFreeze(Music)
