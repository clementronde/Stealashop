--!strict
-- Musique de fond (liaison L-056, demande de Clément du 2026-11-07 ; DEV-051 ; fond unique depuis la
-- demande de Cantin du 2026-11-11). Lu par MusicController (client). Le doc ne fixe aucune de ces valeurs.
--   Noms : ceux de Clément, acceptés par Ironix en L-056 (préfixe MUS_ en 10.3) ;
--   « V0 » : V0 proposé, absent du doc, à régler en jeu.
-- Unités : secondes, studs.

local DeepFreeze = require(script.Parent.DeepFreeze)

local Music = {
	-- Pistes de Clément : des Sound, chacun avec son volume de départ (L-056).
	Folder = { "Assets", "Music" }, -- depuis ReplicatedStorage ; sous-dossiers permis
	-- Demande de Cantin du 2026-11-11 : plus de musique par zone. Partout (zone safe, couloir, toutes
	-- les zones, de jour comme de nuit), une playlist de fond qui ne redémarre pas d'une zone à
	-- l'autre : ces morceaux dans cet ordre, chacun joué une fois, puis retour au premier après le
	-- dernier. Un morceau absent de Studio est sauté. MUS_Z1 à MUS_Z6 ne sont plus jouées.
	AmbientTracks = {
		"MUS_Ambient_MorningMood", -- Grieg, Morning Mood (l'ancien MUS_Ambient)
		"MUS_Ambient_Spring", -- Vivaldi, Le Printemps
		"MUS_Ambient_TurkishMarch", -- Mozart, Marche turque
		"MUS_Ambient_Gymnopedie", -- Satie, Gymnopédie n° 1
		"MUS_Ambient_ClairDeLune", -- Debussy, Clair de lune
		"MUS_Ambient_ClassicEaster", -- APM, Classic Easter
	},
	FallbackTrack = "MUS_Hub", -- fond partout, en boucle, tant qu'aucun morceau de la playlist n'est dans Studio

	FadeTime = 2, -- V0 : durée d'un fondu enchaîné : l'ancienne piste descend pendant que la nouvelle monte
	CheckInterval = 0.25, -- V0 : musiques d'événement revues 4 fois par seconde

	-- Musiques d'événement (liaison L-071, points 6 et 7 ; noms de Clément, Sound en boucle dans le même
	-- dossier). Elles passent avant le fond, dans cet ordre (ordre de Clément, vague 26) : 1. la
	-- poursuite, 2. le braquage, 3. le camion, 4. le fond. Même fondu enchaîné. Une musique d'événement
	-- pas encore livrée ne change rien : la suivante (ou le fond) joue.
	ChaseTrack = "MUS_Chase", -- tant qu'un vigile poursuit le joueur local (ChaseController)
	-- Vague 26 (L-097 point 8, ui-feel2-horsligne-poursuite-barre.md) : tension tant que le chrono du
	-- braquage est affiché chez le joueur (HeistTimer, après la casse d'une vitrine). Avec elle, en
	-- boucle et au même fondu, la respiration Heist_Breath (un son d'effet de Assets/Sounds, donc au
	-- volume SfxVolume).
	HeistTrack = "MUS_Heist",
	HeistBreath = "Heist_Breath",
	TruckTrack = "MUS_Truck", -- près du camion de l'événement, ou de ses colis au sol après l'explosion
	TruckRadius = 100, -- V0 : MUS_Truck commence à moins de 100 studs du camion ou d'un de ses colis au sol…
	TruckExitMargin = 10, -- V0 : … et s'arrête au-delà de 110 studs (pas d'aller-retour au bord du cercle)
	-- V0 : une musique d'événement redescendue au silence repart du début au prochain événement, au lieu
	-- de reprendre où elle en était comme le fond.
	RestartEventTracks = true,

	-- Réglage du volume de la musique : attribut du Player local, de 0 (muet) à 1 (le volume de
	-- Clément) ; absent ou invalide : 1. Posé par SettingsController (UI_Settings) et SettingsService.
	VolumeAttribute = "MusicVolume",
}

export type Music = typeof(Music)

return DeepFreeze(Music)
