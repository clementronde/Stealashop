--!strict
-- Le « jus » de l'encaissement sur une plaque CollectPad_xx (a317, liaison L-299, demande de Clément du 2026-11-23,
-- d'après le concurrent principal). Lu par CashFlashController (voile) et GainController (compteur et son), côté client.
-- Seulement quand le joueur local vide une de SES plaques (DisplayController.OnCollect) : jamais pour l'encaissement
-- automatique, les gains hors ligne ni le revenu par seconde (L-184 point 3 ne change pas).
--
-- Toutes les valeurs sont celles de L-299 (et du prototype tools/clement/cash_flash_demo.luau), en V0 : absentes du
-- doc partagé. Unités : secondes, facteurs sans unité.

local DeepFreeze = require(script.Parent.DeepFreeze)

local CashFlash = {
	-- false : tout comme avant L-299 (compteur tout de suite, son Cash_Collect, pas de voile).
	Enabled = true, -- V0

	-- 1. Voile vert sur les bords de l'écran : StarterGui/UI_CashFlash de Clément (Enabled = false au repos), bandes
	-- EdgeGlow.Top, Bottom, Left, Right. Leur BackgroundTransparency posée par Clément est le voile à son plus fort
	-- (« posée ») ; chaque bande va de sa transparence du moment à
	--     posée + (1 − posée) × Strength × (1 − clamp((n − 1) / RankSpan, 0, 1))
	-- en InTime (Quad Out), tient HoldTime, revient à 1 en OutTime (Quad In), puis l'écran repasse à Enabled = false
	-- OffDelay s plus tard. n = rang de la plaque dans la tournée : 1 à la première, +1 si la précédente date de moins
	-- de RankWindow s, sinon 1 : le voile se renforce le long d'une rangée. Une nouvelle plaque relance le voile.
	Screen = "UI_CashFlash",
	Container = "EdgeGlow",
	Bands = { "Top", "Bottom", "Left", "Right" },
	Strength = 0.45, -- V0 (L-299)
	RankSpan = 7, -- V0 (L-299) : au 8e rang de la tournée, le voile est à son plus fort
	RankWindow = 2, -- V0 (L-299, « ~2 s ») : secondes
	InTime = 0.06, -- V0 (L-299)
	HoldTime = 0.18, -- V0 (L-299)
	OutTime = 0.45, -- V0 (L-299)
	OffDelay = 0.05, -- V0 (prototype : Enabled = false 0,5 s après le début du retour)

	-- 2. Compteur et son : Cash (UI_HUD) est retenu (HudController.HoldCash) jusqu'à l'arrivée du premier billet 3D au
	-- compteur (VfxController.Collect) ; alors il défile en RollTime, CashRow grossit à PopScale en PopUpTime (Quad
	-- Out) puis revient à 1 en PopDownTime (Quad Out). Sound (cherché par son nom dans Assets/Sounds : il est rangé dans
	-- Assets/Sounds/Cash), PlaybackSpeed × (1 ± PitchJitter) au hasard, part au contact depuis a422 (SoundOnContact,
	-- plus bas). Cash_Collect n'est plus joué sur les plaques (il reste pour les autres gains, et en secours si Sound
	-- manque). Sans billets (VISUAL EFFECTS sur OFF, compteur hors écran) : tout de suite.
	RollTime = 0.3, -- V0 (L-299, « ~0,3 s »)
	PopScale = 1.15, -- V0 (L-299)
	PopUpTime = 0.08, -- V0 (L-299, « ~0,08 s »)
	PopDownTime = 0.3, -- V0 (L-299, « ~0,3 s »)
	Sound = "Cash_Pad", -- son de Clément (L-299)
	PitchJitter = 0.03, -- V0 (L-299, « ± 3 % »)
	-- a422 (Cantin, 24/11 : « le son doit partir dès le contact avec la plaque », ce qui remplace le moment de L-299) :
	-- Sound part au contact (remote CashCollect du joueur local, DisplayController.OnCollect : la plaque flashe et
	-- s'enfonce), plus à l'arrivée du premier billet, qui garde le compteur et CashRow ; un seul son par plaque. Sound
	-- absent d'Assets/Sounds : FallbackSound à sa place, au même moment. false : le son à l'arrivée du premier billet
	-- (L-299).
	SoundOnContact = true, -- V0 proposé (Cantin, 24/11)
	FallbackSound = "Cash_Collect", -- V0 proposé (Cantin, 24/11) : un son part toujours au contact, même sans Cash_Pad

	-- Appariement (V0 proposé, absent du doc) : la hausse de Cash et le remote CashCollect de la plaque arrivent presque
	-- ensemble, dans un ordre qui n'est pas garanti. Une hausse de CashCollected sans plaque vue attend le remote au plus
	-- MatchWindow s ; sans lui, c'est l'encaissement automatique ou les gains hors ligne : comme avant. Une plaque vue
	-- attend son premier billet au plus LandTimeout s (filet de sécurité), puis le compteur part quand même.
	MatchWindow = 0.3, -- V0 proposé : secondes
	LandTimeout = 2, -- V0 proposé : secondes
}

export type CashFlash = typeof(CashFlash)

return DeepFreeze(CashFlash)
