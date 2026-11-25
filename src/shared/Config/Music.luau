--!strict
-- Musique de fond (liaison L-056, demande de Clément du 2026-11-07 ; DEV-051 ; fond unique depuis la
-- demande de Cantin du 2026-11-11). Lu par MusicController (client). Le doc ne fixe aucune de ces valeurs.
--   Noms : ceux de Clément, acceptés par Ironix en L-056 (préfixe MUS_ en 10.3) ;
--   « V0 » : V0 proposé, absent du doc, à régler en jeu.
-- Unités : secondes, studs.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- a477 : module de Config chargé s'il est là (bancs à liste de modules fixe), comme Config/Outlines.
local function optional(name: string): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild(name)
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end
local Features: any = optional("Features")
local ProductIds: any = optional("ProductIds")

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

	-- a477 (L-377, L-385 ; Clément 25/11 : « quand on vole une boutique, que ce soit NPC ou joueur, il faut que la
	-- musique change » ; bascule nette et rapide). Allumé partout (Features.StealMusic) ou dans le jeu DEV seulement
	-- (Features.StealMusicDev et ProductIds.IsDev). Coupé : tout comme avant. Ordre des musiques allumé :
	-- MUS_Steal > MUS_Victim > MUS_Chase > MUS_Heist > MUS_Truck > fond.
	Steal = {
		Enabled = Features.StealMusic == true or (Features.StealMusicDev == true and ProductIds.IsDev == true),
		-- L-385 (2), (3) : tant que le joueur local porte un objet volé (attribut Carrying de CarryService : rayon d'un
		-- magasin PNJ comme présentoir d'un joueur), avec ou sans vigile ; repart du début à chaque prise.
		StealTrack = "MUS_Steal", -- L-385
		-- L-385 (4) : tant qu'un voleur porte un objet du joueur local (TheftAlertController, avec la sirène), par-dessus
		-- tout sauf MUS_Steal ; fin quand l'objet est rattrapé, rendu ou mis à l'abri chez le voleur.
		VictimTrack = "MUS_Victim", -- L-385
		-- L-385 : montée de ces pistes en TensionFadeIn s au lieu de FadeTime (le retour au calme garde FadeTime).
		TensionTracks = { "MUS_Steal", "MUS_Victim", "MUS_Chase" }, -- L-385
		TensionFadeIn = 0.25, -- L-385 : « environ 0,2 à 0,3 s »
		-- L-385 (2) : à la prise, la piste qui jouait (fond, MUS_Heist, MUS_Chase…) est coupée net, pas recouverte.
		CutOthersOnSteal = true, -- L-385
		-- L-385 (5) : arrivée en zone safe avec l'objet (fin du portage dans une zone `SafeZone`) : MUS_Steal descend en
		-- SafeOutTime s, puis le fond revient SafeReturnDelay s après la fin du portage.
		SafeOutTime = 0.3, -- L-385
		SafeReturnDelay = 0.8, -- L-385
		-- L-385 (1) : 1er coup du joueur local sur la porte d'une boutique de joueur → MUS_Heist (avec Heist_Breath),
		-- tant que son dernier coup date de PlotHeistHold s au plus, ou que la boutique reste ouverte au vol (attribut
		-- StealOpen) et qu'il est à PlotHeistRadius studs au plus de son pivot.
		PlotHeistHold = 6, -- V0
		PlotHeistRadius = 60, -- V0 : une boutique fait environ 80 studs de long au niveau 2
	},

	-- Réglage du volume de la musique : attribut du Player local, de 0 (muet) à 1 (le volume de
	-- Clément) ; absent ou invalide : 1. Posé par SettingsController (UI_Settings) et SettingsService.
	VolumeAttribute = "MusicVolume",
}

export type Music = typeof(Music)

return DeepFreeze(Music)
