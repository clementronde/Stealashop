--!strict
-- Animations d'UI (DEV-052 ; Partie 1, section 2.2, « Libre pour Ironix : … animer à l'ouverture
-- et à la fermeture ») : ouverture et fermeture des écrans de Clément (UI_WeaponShop, UI_AuraShop,
-- UI_TheftAlert et son repli V0), apparition et disparition d'éléments du HUD (HeistTimer,
-- GuardMeter), chiffres qui défilent (Cash, Income). Lu par Controllers/UI/Motion (client).
-- L'échelle passe par un UIScale créé par le code et détruit à la fin de chaque animation : aucun
-- visuel de Clément ne change (couleur, taille, position, image, police, transparence).
--
-- Open, Close, Show, Hide, Roll et ScaleName sont des V0 proposés, absents du doc, à régler à l'œil
-- en jeu ; les autres viennent du tableau de Clément (voir plus bas).
-- Unités : secondes ; échelles en part de la taille posée par Clément (1 = sa taille).

local DeepFreeze = require(script.Parent.DeepFreeze)

local UiMotion = {
	-- Écran qui s'ouvre (Motion.Open) : ses cadres racine passent de From à 1.
	Open = {
		From = 0.9, -- V0 proposé, absent du doc
		Time = 0.25, -- V0 proposé, absent du doc
		Style = Enum.EasingStyle.Back, -- V0 proposé, absent du doc : léger rebond au-dessus de 1, puis 1
		Direction = Enum.EasingDirection.Out, -- V0 proposé, absent du doc
	},
	-- Écran qui se ferme (Motion.Close) : sortie courte de 1 à To, puis l'écran s'éteint.
	Close = {
		To = 0.9, -- V0 proposé, absent du doc
		Time = 0.12, -- V0 proposé, absent du doc
		Style = Enum.EasingStyle.Quad, -- V0 proposé, absent du doc
		Direction = Enum.EasingDirection.In, -- V0 proposé, absent du doc
	},
	-- Élément qui apparaît (Motion.Show : HeistTimer, GuardMeter) : de From à 1, rebond plus marqué
	-- qu'un écran, l'élément est petit.
	Show = {
		From = 0.6, -- V0 proposé, absent du doc
		Time = 0.2, -- V0 proposé, absent du doc
		Style = Enum.EasingStyle.Back, -- V0 proposé, absent du doc
		Direction = Enum.EasingDirection.Out, -- V0 proposé, absent du doc
	},
	-- Élément qui disparaît (Motion.Hide) : de 1 à To, puis Visible = false.
	Hide = {
		To = 0.6, -- V0 proposé, absent du doc
		Time = 0.12, -- V0 proposé, absent du doc
		Style = Enum.EasingStyle.Quad, -- V0 proposé, absent du doc
		Direction = Enum.EasingDirection.In, -- V0 proposé, absent du doc
	},
	-- Chiffre qui défile (Motion.Roll : Cash, Income) de l'ancienne valeur à la nouvelle.
	Roll = {
		Time = 0.6, -- V0 proposé, absent du doc (l'écran d'ouverture compte en 0,9 s ou 0,45 s, Config/Unbox)
		Style = Enum.EasingStyle.Cubic, -- V0 proposé, absent du doc : vite au début, freine à la fin
		Direction = Enum.EasingDirection.Out, -- V0 proposé, absent du doc
	},
	-- Valeurs suivantes (Hover à SafeFlash) : tableau « Étendues à tout le jeu (2026-11-10, validées par
	-- Clément sur l'inventaire et en Play) » de docs/claude/notes/ui-motion-skilltree.md (liaison L-091,
	-- points 3 et 7), sauf les lignes marquées « V0 proposé, absent du doc » ou « prototype ».

	-- Bouton survolé à la souris (Motion.Button, alias Motion.Hover) : il grossit jusqu'à To, son
	-- calque Shade (enfant direct, s'il existe) passe à ShadeTransparency, son UI_Hover.
	Hover = {
		To = 1.06, -- tableau : « × 1,06 en 0,08 »
		Time = 0.08,
		Style = Enum.EasingStyle.Quad, -- tableau : Quad Out
		Direction = Enum.EasingDirection.Out,
		ShadeTransparency = 0.78, -- tableau : « calque Shade de transparence 1 → 0,78 »
		Sound = "UI_Hover", -- tableau : « son UI_Hover »
		ScaleName = "HoverScale", -- V0 proposé, absent du doc : UIScale à part, retiré quand le bouton est revenu à 1
	},
	-- Bouton appuyé (Motion.Button).
	Press = {
		To = 0.95, -- tableau : « × 0,95 en 0,05 ; Shade 0,62 »
		Time = 0.05,
		Style = Enum.EasingStyle.Quad,
		Direction = Enum.EasingDirection.Out,
		ShadeTransparency = 0.62,
	},
	-- Bouton relâché (Motion.Button) : retour à 1, ou à Hover.To si la souris est encore dessus.
	Release = {
		Time = 0.2, -- tableau : « retour en 0,2 », Back Out
		Style = Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
	},
	-- Achat ou validation (Motion.Success) : le bouton saute à From, puis revient en Time ; UI_Success
	-- SoundDelay s après le clic.
	Success = {
		From = 1.22, -- tableau : « bouton × 1,22 → 1 en 0,28 ; UI_Success 0,12 s après le clic »
		Time = 0.28,
		Style = Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
		SoundDelay = 0.12,
		Sound = "UI_Success",
		-- Boutons qui la jouent à chaque clic (prototype tools/clement/ui_feel_proto.luau, table SUCCESS).
		Buttons = { "BuyButton", "EquipButton", "ClaimButton", "DailyClaimButton", "ConfirmButton", "PlaceButton", "EquipBestButton" },
	},
	-- Carte survolée (Motion.HoverCard : un cadre avec un enfant HoverOutline) : son Icon grossit,
	-- penche et se décale ; HoverOutline visible ; retour en BackTime.
	HoverCard = {
		IconScale = 1.12, -- tableau : « Icon × 1,12, −6°, décalée de (0,02 ; −0,03) en 0,1 »
		Tilt = -6,
		ShiftX = 0.02,
		ShiftY = -0.03,
		Time = 0.1,
		Style = Enum.EasingStyle.Back, -- tableau : Back Out, puis Quad Out
		Direction = Enum.EasingDirection.Out,
		BackTime = 0.12, -- tableau : « retour en 0,12 »
		BackStyle = Enum.EasingStyle.Quad,
		Outline = "HoverOutline",
		Icon = "Icon",
	},
	-- Message en bas (tableau : `UI_Toast`). Pas encore lu : NotifyController (UI_Notify) entre déjà
	-- par Motion.Show, de 0,6 à 1 en 0,2 Back Out (les mêmes valeurs) ; il garde 4 s à l'écran au lieu
	-- de Hold, à décider avec Clément (liaison L-091).
	Toast = {
		From = 0.6,
		Time = 0.2,
		Style = Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
		Hold = 2.4,
		FadeTime = 0.25,
		MaxShown = 3,
	},
	-- Gain au-dessus du joueur (BB_Gain, GainController).
	FloatGain = {
		PopFrom = 0.4, -- tableau : « Row 0,4 → 1 en 0,16 » Back Out
		PopTime = 0.16,
		PopStyle = Enum.EasingStyle.Back,
		Rise = 2.2, -- tableau : « monte de 2,2 studs en 1 », Quad Out
		Time = 1,
		Style = Enum.EasingStyle.Quad,
		Direction = Enum.EasingDirection.Out,
		FadeAt = 0.55, -- tableau : « s'efface à partir de 55 % »
		SpreadX = 1, -- tableau : « décalage au hasard de ± 1 stud »
		Height = 3.2, -- prototype gain_proto.luau (StudsOffset 3,2), si BB_Gain n'a pas son propre StudsOffset
		MinGap = 0.25, -- prototype gain_proto.luau (GainBurstGap) : un BB_Gain au plus par 0,25 s, les gains entre deux s'additionnent
	},
	-- Case qui vole vers l'argent (UI_HUD.CashFly.Template, GainController).
	CashFly = {
		PopTo = 1.1, -- tableau : « surgit 0 → 1,1 en 0,22 ; attend 0,23 ; vole jusqu'au compteur en 0,4 en rapetissant à 0,3 »
		PopTime = 0.22,
		PopStyle = Enum.EasingStyle.Back,
		Hold = 0.23,
		Time = 0.4,
		Style = Enum.EasingStyle.Quad, -- tableau : Back Out, puis Quad In
		Direction = Enum.EasingDirection.In,
		EndScale = 0.3,
		From = { X = 0.5, Y = 0.55 }, -- prototype gain_proto.luau : départ au centre (gains hors ligne, récompenses)
		TargetOffsetX = 20, -- prototype gain_proto.luau : arrivée 20 px après le bord gauche du nombre
		Sound = "Cash_Collect", -- tableau : « son Cash_Collect » à l'arrivée
	},
	-- Arrivée au compteur : CashRow sursaute.
	CashBump = {
		From = 1.15, -- tableau : « CashRow 1,15 → 1 en 0,3 », Back Out
		Time = 0.3,
		Style = Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
	},
	-- « +$X » à côté du compteur (copie de UI_HUD.CashFly.CounterPop).
	CounterPop = {
		From = 0.4, -- tableau : « 0,4 → 1 en 0,22, 1,6 s, puis monte de 24 px et s'efface en 0,4 »
		Time = 0.22,
		Style = Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
		Hold = 1.6,
		Rise = 24,
		FadeTime = 0.4,
		OffsetX = 14, -- prototype gain_proto.luau : 14 px après la fin du texte de l'argent
	},
	-- Chrono du vol (HeistTimer, ou son enfant Box s'il existe) : à chaque seconde.
	TimerTick = {
		From = 1.12, -- tableau : « 1,12 → 1 en 0,25 et tic UI_Click_Tick ; rouge sous 3 s » (rouge : pas branché)
		Time = 0.25,
		Style = Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
		Sound = "UI_Click_Tick",
		RedBelow = 3,
	},
	-- RUN! (UI_Chase.RunBanner). Pas encore lu (voir le rapport de la vague 21, L-091) : Motion.Open
	-- met déjà UI_Chase à l'échelle ; deux UIScale sur RunBanner se gêneraient.
	RunBanner = {
		Peak = 1.18, -- tableau : « 0 → 1,18 en 0,18, puis 1 en 0,12 ; il bat (+5 %) avec les bords et penche de ± 1,5° »
		InTime = 0.18,
		SettleTime = 0.12,
		Style = Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
		Beat = 0.05,
		Tilt = 1.5,
	},
	-- Bords rouges de poursuite (UI_Chase : ScreenEdges, Vignette.Edge) : la transparence bat en sinus.
	ChasePulse = {
		Min = 0.1, -- tableau : « transparence de 0,1 à 0,6, 1,6 battement par seconde »
		Max = 0.6,
		Rate = 1.6,
		Targets = { "ScreenEdges", "Vignette.Edge" },
	},
	-- Caméra pendant la poursuite.
	ChaseFov = {
		Add = 6, -- tableau : « champ de vision + 6 en 0,3, retour en 0,4 », Quad Out
		InTime = 0.3,
		OutTime = 0.4,
		Style = Enum.EasingStyle.Quad,
		Direction = Enum.EasingDirection.Out,
	},
	-- Arrivée en zone safe (UI_Escape). Pas encore lu (voir le rapport de la vague 21, L-091).
	SafeFlash = {
		FlashFrom = 0.05, -- tableau : « UI_Escape.Flash transparence 0,05 → 1 en 0,5 ; champ de vision + 12 en 0,08 puis retour en 0,45 ; bannière 0 → 1 en 0,35 »
		FlashTime = 0.5,
		FovAdd = 12,
		FovInTime = 0.08,
		FovOutTime = 0.45,
		BannerTime = 0.35,
	},
	-- V0 proposé, absent du doc : UIScale passager de Motion.Pop (sursauts : CashBump, TimerTick…).
	PopScaleName = "PopScale",
	-- V0 proposé, absent du doc : nom du UIScale ajouté par le code sur un cadre animé (jamais un
	-- nom du contrat 2.2 ; il disparaît à la fin de l'animation).
	ScaleName = "MotionScale",
}

export type UiMotion = typeof(UiMotion)

return DeepFreeze(UiMotion)
