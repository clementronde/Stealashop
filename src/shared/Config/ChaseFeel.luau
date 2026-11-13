--!strict
-- Ambiance de la poursuite côté client (liaison L-095 ; demande de Clément du 2026-11-10 :
-- docs/claude/notes/ui-feel2-horsligne-poursuite-barre.md, « Pour Ironix », point « Poursuite »).
-- Lu par ChaseFeelController (et MusicController pour MusicStartAt). Le doc ne fixe aucune de ces
-- valeurs. Sources :
--   « Note » : la note de Clément citée plus haut ;
--   « Proto » : son prototype tools/clement/feel2_proto.luau (startChase, shout, stopLoop) ;
--   « V0 » : V0 proposé, absent du doc.
-- Unités : secondes ; échelles de UIScale (1 = taille de Clément).

local DeepFreeze = require(script.Parent.DeepFreeze)

local ChaseFeel = {
	-- Sons (ReplicatedStorage/Assets/Sounds, sous-dossiers compris, cherchés par MarkerSounds.find).
	Sounds = {
		Grab = "Heist_Grab", -- Note : au départ de la poursuite
		Whistle = "Chase_Whistle", -- Note : après Heist_Grab (WhistleDelay)
		Radio = "Guard_Radio", -- Note : une phrase du vigile sur deux, « à essayer »
	},
	-- Vague 24 (Play de Cantin du 2026-11-11 : « on dirait un seul bloc de son ») : les sons du départ
	-- sont espacés pour qu'on distingue chacun. Heist_Grab à 0 s, puis :
	WhistleDelay = 0.5, -- V0 proposé, absent du doc (la note de Clément disait 0,15 s)
	-- Chase_Siren retirée (Clément, L-117 point 5).

	-- Musique de poursuite (MUS_Chase, jouée par MusicController) : elle part de 1,5 s de son début.
	MusicStartAt = 1.5, -- Note (« Chase_Music (à partir de 1,5 s) »)
	-- Vague 24 : MUS_Chase commence à monter (fondu de Music.FadeTime) MusicDelay s après le départ de
	-- la poursuite, à Music.CheckInterval près. Encore audible (fondu de sortie d'une poursuite d'avant) :
	-- elle reprend tout de suite, sans attendre.
	MusicDelay = 1.8, -- V0 proposé, absent du doc

	-- Bulle du vigile : copie de ReplicatedStorage/Assets/UI/BB_GuardShout sur sa tête.
	ShoutTemplate = "BB_GuardShout",
	ShoutFolder = { "Assets", "UI" }, -- depuis ReplicatedStorage
	Bang = {
		PopScale = 1.35, -- Note : 0 → 1,35 → 1
		PopTime = 0.15, -- Proto : 0 → 1,35 en 0,15 s (Back)…
		SettleTime = 0.15, -- Proto : … puis 1,35 → 1 en 0,15 s
		ShakeStart = 0.1, -- Proto : tremblement (Rotation, degrés) à partir de 0,17 s…
		ShakeStep = 0.07, -- Proto : … un angle toutes les 0,07 s
		ShakeAngles = { 14, -12, 8, -5, 0 }, -- Proto
	},
	FirstShoutDelay = 0.6, -- Proto : première phrase 0,6 s après l'apparition de la bulle
	ShoutEvery = 2.4, -- Note : une phrase toutes les 2,4 s
	-- Vague 24 : Bubble, Tail et Bang grossissent, restent et rapetissent ensemble à chaque phrase, puis
	-- sont cachés (Visible = false) : rien ne reste entre deux phrases. Bang garde son « pop » et tremble.
	ShoutInTime = 0.2, -- Note : la bulle grossit de 0 à 1 en 0,2 s (Back)
	ShoutHold = 1.6, -- Note : reste 1,6 s
	ShoutOutTime = 0.12, -- Note : rapetisse en 0,12 s
	RadioEvery = 2, -- Note (« une fois sur deux ») : Guard_Radio avec la 1re phrase, la 3e, la 5e…
	-- V0 : phrases du vigile (en anglais) ; reprend la liste du prototype. Jamais deux fois la même
	-- d'affilée.
	Lines = { "STOP RIGHT THERE!", "THIEF!", "COME BACK HERE!", "FREEZE!", "GIVE IT BACK!", "STOP NOW!" },

	-- Barres cachées pendant la poursuite (Note : « cacher la barre de gauche et la barre du bas »).
	HudScreen = "UI_HUD",
	-- UI_HUD.LeftRail (PC) et, vague 24, UI_HUD.LeftRailTouch (téléphone, mêmes boutons) : Visible.
	Rails = { "LeftRail", "LeftRailTouch" },
	Hotbar = "UI_Hotbar", -- ScreenGui de la barre du bas (Enabled)
	BarsRefresh = 0.2, -- V0 : barres revues toutes les 0,2 s pendant la poursuite (copie neuve d'un écran)
}

export type ChaseFeel = typeof(ChaseFeel)

return DeepFreeze(ChaseFeel)
