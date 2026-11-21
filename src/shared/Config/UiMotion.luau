--!strict
-- Animations d'UI (DEV-052 ; Partie 1, section 2.2, « Libre pour Ironix : … animer à l'ouverture
-- et à la fermeture ») : ouverture et fermeture des écrans de Clément (UI_WeaponShop, UI_AuraShop,
-- UI_TheftAlert et son repli V0), apparition et disparition d'éléments du HUD (HeistTimer,
-- GuardMeter), chiffres qui défilent (Cash, Income). Lu par Controllers/UI/Motion (client).
-- L'échelle passe par un UIScale créé par le code et détruit à la fin de chaque animation : aucun
-- visuel de Clément ne change (couleur, taille, position, image, police, transparence).
--
-- Show, Hide, Roll et ScaleName sont des V0 proposés, absents du doc, à régler à l'œil en jeu ; les
-- autres viennent du tableau de Clément (Open, OpenStagger, Close et Swap : L-094, vague 24).
-- Unités : secondes ; échelles en part de la taille posée par Clément (1 = sa taille).

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Vague 64 (a212, Cantin : des écrans qui « pop ») : rythme de la vidéo de référence mesurée image par image
-- (docs/claude/notes/2026-11-16_video-effets-ui.md, sections 3 et 4). true : ouverture 0,55 → 1 en 0,38 s Back Out
-- (dépasse à ~1,045), fermeture Back In 0,2 s (gonfle de ~10 % puis tombe à 0), contenu bloc par bloc (Appear.Blocks),
-- cartes de gauche à droite (Appear.Cascade, OpenStagger), barre du bas qui s'écarte (HudAway). false : l'ancien
-- rythme exactement (L-094, L-182, L-188), sans blocs ni barre qui s'écarte.
local VIDEO_RHYTHM = true

-- Vague 73 (a256, L-230 et L-224 point 2, Clément : ouverture comme Throw a Seed, mesures dans
-- docs/claude/notes/2026-11-17_throw-a-seed-a-reprendre.md, sections 3 et 8). true : la fenêtre grandit de 0,84 à 1
-- (Back Out, 0,26 s), se ferme vers 0,9 en 0,13 s puis s'éteint d'un coup ; flou Size 16 sous la caméra (entrée 0,2 s Quad
-- InOut, sortie 70 ms après le clic en 0,15 s) sur toutes les grandes fenêtres (Windows) ; tout le HUD (HudHide) caché à
-- l'image où une grande fenêtre s'allume et rendu à l'image où elle s'éteint (la barre du bas ne s'écarte plus : HudAway
-- coupé). false : le rythme de la vague 64 exactement.
local WINDOW_TAS = true
-- V0 proposé, absent du doc : les grandes fenêtres (L-230 : « boutiques, index, inventaire, renaissance, réglages… ») ;
-- les petites (cadeau, hors ligne, notification, UI_HelpInvite) ne floutent ni ne cachent rien. Un autre ScreenGui aussi
-- s'il porte l'attribut Blur (flou) ou HideHud (HUD caché) = true, posé par Clément.
local WINDOWS: { string } = {
	"UI_WeaponShop", "UI_AuraShop", "UI_RobuxShop", "UI_RobuxShop_v2", "UI_DiamondShop", "UI_PawnShop",
	"UI_Index", "UI_Index_v2", "UI_Index_v3", "UI_Index_v4", "UI_Inventory", "UI_Displayed", "UI_Rebirth",
	"UI_Settings", "UI_Rewards", "UI_SkillTree", "UI_Wheel", "UI_Quests",
}

-- Vague 74 (a258, L-259, Clément : ouverture et fermeture comme la vidéo de référence E, voile noir UI_Veil et flou
-- derrière les fenêtres centrales). true : ouverture 0,5 → 1,055 (0,17 s Quad Out) → 1 (0,16 s Quad InOut), fermeture
-- 1 → 1,04 (0,06 s Quad Out) → 0,5 (0,1 s Quad In) puis l'écran s'éteint ; flou ≈ 10 (entrée 0,2 s Quad Out, sortie
-- 0,13 s) et voile (Veil) seulement derrière CENTRAL. false : le rythme de la vague 73 exactement. Ne joue que si
-- WINDOW_TAS est allumé (les deux s'empilent).
local WINDOW_E = WINDOW_TAS and true
-- L-259 (b) : boutiques Robux, armes, auras, diamants, prêteur, index, arbre de compétences, réglages, renaissance,
-- récompenses, gains hors ligne ; pas UI_Displayed (panneau de côté), ni alertes, notifications, bannières.
-- V0 proposé : l'inventaire (L-259, « index et inventaire d'abord ») et la roue (UI_Wheel, grande fenêtre de L-230) ; vague 80 (a266) : UI_Quests, V0 proposé (Cantin, 20/11).
local CENTRAL: { string } = {
	"UI_WeaponShop", "UI_AuraShop", "UI_RobuxShop", "UI_RobuxShop_v2", "UI_DiamondShop", "UI_PawnShop",
	"UI_Index", "UI_Index_v2", "UI_Index_v3", "UI_Index_v4", "UI_Inventory", "UI_Rebirth",
	"UI_Settings", "UI_Rewards", "UI_SkillTree", "UI_Wheel", "UI_Offline", "UI_Quests",
}

local UiMotion = {
	VideoRhythm = VIDEO_RHYTHM,
	WindowTas = WINDOW_TAS,
	WindowE = WINDOW_E,
	Windows = WINDOWS,
	-- Écran qui s'ouvre (Motion.Open) : ses cadres racine (Root) passent de From à 1. Valeurs validées par
	-- Clément sur les prototypes (L-094 ; tableau « Étendues à tout le jeu » de
	-- docs/claude/notes/ui-motion-skilltree.md, ligne « Fenêtre qui s'ouvre », qui remplace l'ancien V0
	-- 0,9 → 1 en 0,25 ; tools/clement/inventory_proto.luau, OpenFrom et OpenTime).
	Open = {
		From = if WINDOW_E then 0.5 elseif WINDOW_TAS then 0.84 else 0.55, -- vague 74 : 0,5 (L-259) ; vague 73 : 0,84 (L-230) ; tableau : « Root 0,55 → 1 en 0,14 », Back Out
		-- Vague 74 (L-259) : d'abord From → Peak en PeakTime (PeakStyle, PeakDirection), puis Peak → 1 en Time ; Peak nil : un seul tween.
		Peak = (if WINDOW_E then 1.055 else nil) :: number?,
		PeakTime = 0.17,
		PeakStyle = Enum.EasingStyle.Quad,
		PeakDirection = Enum.EasingDirection.Out,
		Time = if WINDOW_E then 0.16 elseif WINDOW_TAS then 0.26 elseif VIDEO_RHYTHM then 0.38 else 0.14, -- vague 74 : 0,16 s ; vague 73 : 0,26 (mesure : 0,2 à 0,33) ; vague 64 : 0,38 s (vidéo : 0,55 → 1,055 → 1)
		Style = if WINDOW_E then Enum.EasingStyle.Quad else Enum.EasingStyle.Back, -- le Back Out dépasse un peu 1 (environ 1,04), puis revient à 1
		Direction = if WINDOW_E then Enum.EasingDirection.InOut else Enum.EasingDirection.Out,
	},
	-- Contenu qui arrive après la fenêtre (Motion.Open, puis chaque carte ou rangée) : de From à 1 en
	-- Time, la première Start s après l'ouverture, puis Gap s entre deux, Max cartes au plus (les
	-- suivantes partent avec la Max-ième). Tableau : ligne « Contenu qui arrive après la fenêtre ».
	-- Vague 64 : les cartes comme dans la vidéo (« 5 cartes de gauche à droite, 22 ms de décalage, à partir de +230 ms ;
	-- chacune de 0,2 à 1 en 0,13 s, Quad Out ») ; Max 8 : décalage total plafonné à ~0,15 s (fiche, section 3).
	OpenStagger = {
		From = if VIDEO_RHYTHM then 0.2 else 0, -- tableau : « chaque carte ou rangée 0 → 1 en 0,14 ; départ à 0,08 ; 0,035 entre deux, 14 au plus »
		Time = if VIDEO_RHYTHM then 0.13 else 0.14,
		Start = if VIDEO_RHYTHM then 0.23 else 0.08,
		Gap = if VIDEO_RHYTHM then 0.022 else 0.035,
		Max = if VIDEO_RHYTHM then 8 else 14,
		Style = if VIDEO_RHYTHM then Enum.EasingStyle.Quad else Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
		-- Cartes = cadres qui ont un enfant HoverOutline (HoverCard.Outline). Sans carte visible : les
		-- enfants visibles de ces cadres (prototype tools/clement/ui_feel_proto.luau, staggerItems).
		Rows = { "Rows", "Tree", "Body", "DailyPage" },
		RowTolerance = 4, -- px : même rangée à 4 px près, triée de gauche à droite (prototype ui_feel_proto)
		ScaleName = "StaggerScale", -- V0 proposé, absent du doc : UIScale passager de chaque carte
	},
	-- Écran qui se ferme (Motion.Close) : sortie courte de 1 à To, puis l'écran s'éteint. Tableau :
	-- « Fenêtre qui se ferme : 1 → 0 en 0,09 », Quad In (L-094). Vague 64 : Back In en 0,2 s (vidéo : elle gonfle
	-- de ~11 % puis rétrécit jusqu'à 0, en 0,17 à 0,22 s).
	Close = {
		To = if WINDOW_E then 0.5 elseif WINDOW_TAS then 0.9 else 0, -- vague 74 : 0,5 (L-259) ; vague 73 : « vers 89 à 92 % en 0,13 s, puis disparition d'un coup »
		-- Vague 74 (L-259) : d'abord 1 → Peak en PeakTime, puis Peak → To en Time ; Peak nil : un seul tween. Sans fondu.
		Peak = (if WINDOW_E then 1.04 else nil) :: number?,
		PeakTime = 0.06,
		PeakStyle = Enum.EasingStyle.Quad,
		PeakDirection = Enum.EasingDirection.Out,
		Time = if WINDOW_E then 0.1 elseif WINDOW_TAS then 0.13 elseif VIDEO_RHYTHM then 0.2 else 0.09,
		Style = if WINDOW_TAS then Enum.EasingStyle.Quad elseif VIDEO_RHYTHM then Enum.EasingStyle.Back else Enum.EasingStyle.Quad,
		Direction = Enum.EasingDirection.In,
	},
	-- Changement d'onglet (Motion.Swap) : les cartes visibles sortent (1 → 0 en OutTime, OutGap s entre
	-- deux, de la dernière à la première, OpenStagger.Max au plus), puis la page change et les nouvelles
	-- cartes entrent comme OpenStagger. Tableau : ligne « Changement d'onglet » ; prototype
	-- ui_feel_proto.luau (SwapOutGap, SwapOutTime).
	Swap = {
		OutTime = 0.1, -- tableau : « sortie : cartes à 0 en 0,1, 0,03 entre deux ; entrée comme OpenStagger »
		OutGap = 0.03,
		Style = Enum.EasingStyle.Quad, -- tableau : Quad In, puis Back Out
		Direction = Enum.EasingDirection.In,
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
		-- Écrans dont le contrôleur joue lui-même la réussite ou le refus : l'Index (ClaimButton de Rewards :
		-- « Claimed! » ou refus UI_Deny, jamais un achat) ; l'arbre de compétences (vague 27 : BuyButton saute
		-- quand le niveau monte vraiment, pas à chaque clic).
		SkipScreens = { "UI_Index_v3", "UI_Index_v2", "UI_Index", "UI_SkillTree" },
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
	-- Message en bas (tableau : `UI_Toast` ; L-095 point 3, note ui-feel2-horsligne-poursuite-barre.md).
	-- NotifyController : chaque message est une copie de UI_Toast.Stack.Template qui entre de From à 1
	-- (Back Out), reste Hold s, puis s'efface en FadeTime (texte et contour) ; MaxShown à la fois. Repli
	-- sur UI_Notify (Motion.Show) si UI_Toast manque.
	Toast = {
		From = 0.6, -- tableau : « 0,6 → 1 en 0,2 ; 2,4 s à l'écran ; s'efface en 0,25 ; 3 messages au plus »
		Time = 0.2,
		Style = Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
		Hold = 2.4,
		FadeTime = 0.25,
		MaxShown = 3,
		-- Couleur du texte selon le kind du message (note : « les Notify de réussite (objet équipé, achat,
		-- colis en sécurité) en vert (5dff3a), les informations en blanc ») ; un autre kind : Other.
		Colors = {
			Success = Color3.fromHex("5DFF3A"),
		} :: { [string]: Color3 },
		Other = Color3.new(1, 1, 1),
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
		-- Retour de Clément en Play (L-091, 2026-11-11) : environ 1 s entre deux « +$X » de ramassage (deux
		-- textes se superposaient) ; les ramassages entre deux s'additionnent.
		CashMinGap = 1,
		-- Couleur de Row.Amount selon l'attribut GainKind posé sur la copie (L-092 3e : un seul BB_Gain) ;
		-- prototype de Clément tools/clement/gain_proto.luau, lignes 151 à 153.
		KindAttribute = "GainKind",
		Colors = {
			Speed = Color3.fromHex("4FD2FF"),
			Power = Color3.fromHex("FF7A3A"),
			Cash = Color3.fromHex("5CFF4A"),
		},
		-- Vague 47 (a155) : couleur du « ×2 » du trail ajouté à Row.Amount quand BB_Gain n'a pas
		-- Row.Multiplier. V0 proposé, absent du doc ; Clément choisira dans son élément.
		TrailMultiplierColor = Color3.fromHex("FFD84D"),
		-- Vague 60 (a196, Cantin, T-097) : sans Row.Multiplier, le « ×2 » est un petit TextLabel (Name) créé par le
		-- code dans Row.Amount, posé au coin haut droit du nombre (V0 proposés, absents du doc) : hauteur Size × celle
		-- du texte, centre à Raise × la hauteur du texte depuis son haut ; Row.Amount garde un blanc à sa place.
		-- Mode = "Unicode" : l'exposant Unicode d'a178 (« +1ˣ² Speed/s »).
		TrailExponent = {
			Mode = "Label",
			Name = "TrailExponent",
			Size = 0.55,
			Raise = 0.15,
		},
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
		-- Retour de Clément en Play (liaison L-091, 2026-11-11) : plus de case carrée qui vole ; on garde le
		-- « +$X » de BB_Gain au-dessus du joueur, et le compteur sursaute. true remet la case.
		Enabled = false,
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
		From = 1.12, -- tableau : « 1,12 → 1 en 0,25 et tic UI_Click_Tick ; rouge sous 3 s »
		Time = 0.25,
		Style = Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
		Sound = "UI_Click_Tick",
		RedBelow = 3, -- à 3 s ou moins (prototype feel2_proto.luau : « n <= 3 »)
		RedColor = Color3.fromHex("E8413C"), -- L-092 3c (Clément) : le texte de HeistTimer
		-- Vague 42 (L-153, L-157 point 4 : « en rouge », Clément) : HeistTimer pendant tout le chrono de police.
		-- V0 proposé, absent du doc : le même rouge que RedColor.
		PoliceColor = Color3.fromHex("E8413C"),
	},
	-- RUN! (UI_Chase.RunBanner, UiFeelController ; L-092 3a, accord de Clément) : il s'anime à part,
	-- avec son propre UIScale passager (Motion.Open et Close ne le mettent pas à l'échelle). Le
	-- battement et l'inclinaison suivent le rythme des bords (ChasePulse.Rate).
	RunBanner = {
		Name = "RunBanner",
		ScaleName = "RunBannerScale", -- V0 proposé, absent du doc : UIScale passager, détruit à la fin de la poursuite
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
		-- Vague 59 (a192, L-184 point 2, Clément : « un bord d'écran rouge qui pulse environ toutes les 1,2 s ») :
		-- 1 battement toutes les 1,2 s (avant : 1,6 par seconde).
		Rate = 1 / 1.2,
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
	-- Arrivée en zone safe avec un colis (UI_Escape ; UiFeelController.Escape, au remote BoxSecured) :
	-- note ui-L092-retours.md, section 2, et prototype tools/clement/feel2_proto.luau (escape).
	SafeFlash = {
		Screen = "UI_Escape",
		FlashFrom = 0.05, -- tableau : « UI_Escape.Flash transparence 0,05 → 1 en 0,5 ; champ de vision + 12 en 0,08 puis retour en 0,45 ; bannière 0 → 1 en 0,35 »
		FlashTime = 0.5,
		FlashStyle = Enum.EasingStyle.Quad, -- tableau : Quad Out
		FovAdd = 12,
		FovInTime = 0.08,
		FovOutTime = 0.45,
		FovStyle = Enum.EasingStyle.Quad,
		BannerDelay = 0.1, -- prototype feel2_proto.luau : la bannière part 0,1 s après le flash
		BannerTime = 0.35,
		BannerStyle = Enum.EasingStyle.Back, -- tableau : Back Out
		TitleFrom = -14, -- note : « Title de −14° à −3° » (−3° = sa Rotation dans Studio, remise à la fin)
		TitleTime = 0.45, -- prototype feel2_proto.luau
		Parts = { "BoxIcon", "Subtitle" }, -- note : « puis BoxIcon et Subtitle arrivent 0,07 s l'un après l'autre »
		PartsDelay = 0.16, -- prototype feel2_proto.luau : 0,16 + rang × 0,07
		PartsGap = 0.07,
		PartsTime = 0.25, -- prototype feel2_proto.luau
		Hold = 2.3, -- note : « au bout de 2,3 s, Banner rapetisse à 0 en 0,15 s, puis l'écran s'éteint »
		OutTime = 0.15,
		Sounds = { "Heist_SafeFlash", "Heist_Escape" }, -- note : « Heist_SafeFlash, puis Heist_Escape 0,12 s après »
		SoundGap = 0.12,
		BoxIconPrefix = "BOX_", -- Icons.get("BOX_<Tier>") = ICON_BOX_<Tier>, comme l'inventaire (L-089)
		ScaleName = "EscapeScale", -- V0 proposé, absent du doc : UIScale passager de Banner, BoxIcon, Subtitle
		-- Vague 46 (a154), objet ramené (remote ItemSecured) : textes passagers de Title et Subtitle, V0 proposés,
		-- absents du doc (Clément garde ses textes pour le colis). Subtitle : rareté puis nom de l'objet.
		ItemTitle = "Item secured!",
		ItemSubtitle = "%s %s",
	},
	-- Vague 46 (a154) : révélation d'un colis ouvert sur le rayon (ShelfOpenController → UiFeelController.RevealFlash),
	-- chez l'ouvreur : le flash d'UI_Escape et le zoom de SafeFlash, sans bannière. V0 = les valeurs de SafeFlash.
	RevealFlash = {
		FlashFrom = 0.05,
		FlashTime = 0.5,
		FlashStyle = Enum.EasingStyle.Quad,
		FovAdd = 12,
		FovInTime = 0.08,
		FovOutTime = 0.45,
		FovStyle = Enum.EasingStyle.Quad,
	},
	-- Bandeau d'entrée de zone (UI_ZoneBanner, liaison L-110 ; ZoneBannerController, au passage d'une arche).
	-- V0 proposés, absents du doc (L-110 dit seulement « quelques secondes, avec un fondu ») : à valider par Clément.
	ZoneBanner = {
		Screen = "UI_ZoneBanner",
		FadeIn = 0.35, -- s : de transparent à l'allure de Clément
		Hold = 3, -- s : bandeau plein
		FadeOut = 0.6, -- s : retour à transparent, puis l'écran s'éteint
	},
	-- V0 proposé, absent du doc : UIScale passager de Motion.Pop (sursauts : CashBump, TimerTick…).
	PopScaleName = "PopScale",
	-- V0 proposé, absent du doc : nom du UIScale ajouté par le code sur un cadre animé (jamais un
	-- nom du contrat 2.2 ; il disparaît à la fin de l'animation).
	ScaleName = "MotionScale",
	-- Vague 26 (L-097 point 8 ; ui-feel-sons-victoire-camion.md : « UI_Open et UI_Close sur les fenêtres,
	-- UI_Deny quand l'argent manque ») : sons de Clément (Assets/Sounds/UI), joués par Motion.PlaySound.
	Sounds = {
		Open = "UI_Open", -- Motion.Open d'un écran fermé (ou en train de se fermer)
		Close = "UI_Close", -- Motion.Close d'un écran ouvert ; pas pour ceux fermés par l'ouverture d'un autre du groupe
		Deny = "UI_Deny", -- message Notify du genre DenyKind (refus)
		-- L-106 point 6 : UI_Deny ne sonne que sur un vrai refus (pas assez d'argent, action interdite) :
		-- les messages « Warning ». Les simples avertissements (attrapé, volé, nuit, alarme…) partent en
		-- « Alert » (AlertKind) : même allure que « Warning », sans son.
		DenyKind = "Warning",
		AlertKind = "Alert",
	},
	-- Vague 27 (L-096 point 2) : refus quand l'argent manque (T.18 de docs/claude/notes/ui-motion-skilltree.md ;
	-- prototype tools/clement/skilltree_proto.luau, ShakeTime et ShakeAmp). L'élément part de ±Amplitude px
	-- Count fois (aller-retour) en Time s, puis revient exactement à sa Position.
	Shake = {
		Amplitude = 6, -- tableau : « secousse de ±6 px, 4 allers-retours en 0,30 », Quad
		Count = 4,
		Time = 0.3,
		Style = Enum.EasingStyle.Quad,
		Direction = Enum.EasingDirection.Out,
	},
	-- Arbre de compétences (UI_SkillTree, SkillTreeController ; vague 27, L-096 point 2) : tableaux « Propres à
	-- l'arbre de compétences » et « Navigation dans l'arbre » de docs/claude/notes/ui-motion-skilltree.md
	-- (T.54 à T.72), valeurs du prototype de Clément (tools/clement/skilltree_proto.luau, tableau M).
	SkillTree = {
		-- V0 proposés, absents du doc : UIScale de chaque tuile et de SelectionGlow (posé à l'ouverture, détruit à
		-- la fermeture), UIScale du zoom de Tree (gardé tant que l'écran est branché).
		ScaleName = "SkillTreeScale",
		ZoomScaleName = "SkillTreeZoom",
		-- T.54 : « chaque tuile 0 → 1 en 0,38 ; 0,055 entre deux tuiles, de la tuile centrale vers les
		-- anneaux ; départ à 0,12 », Back Out. SelectionGlow arrive après la dernière tuile (prototype).
		PopTime = 0.38,
		PopGap = 0.055,
		PopStart = 0.12,
		PopStyle = Enum.EasingStyle.Back,
		-- Tuile survolée, appuyée, relâchée (T.30 à T.32 ; prototype : tuile × 1,07, « s'enfonce » × 0,88).
		TileHover = 1.07,
		TilePress = 0.88,
		-- T.55 : contour qui s'efface en 0,08, se pose sous la tuile choisie, puis apparaît (transparence
		-- d'origine, échelle 0,92 → 1) en 0,20, Quad Out.
		SelectOut = 0.08,
		SelectIn = 0.2,
		SelectFrom = 0.92,
		-- T.56 : panneau de gauche qui change de tuile, 0,9 → 1 en 0,25, Back Out.
		PanelFrom = 0.9,
		PanelTime = 0.25,
		-- T.57 et T.58 : la tuile gonfle (1 → 1,3 en 0,09, Quad Out), puis revient (1,3 → 1 en 0,60, Elastic Out).
		PunchTo = 1.3,
		PunchTime = 0.09,
		SettleTime = 0.6,
		SettleStyle = Enum.EasingStyle.Elastic,
		-- T.59 : copie blanche du corps de la tuile, qui s'efface en 0,35 (Quad Out).
		FlashTime = 0.35,
		-- T.60 : 12 losanges or et blancs, à 0,9 largeur de tuile (± 25 %), en 0,55 (Quad Out). Couleurs,
		-- contour et taille (12 % de la tuile) : prototype.
		SparkCount = 12,
		SparkDistance = 0.9,
		SparkSpread = 0.25,
		SparkTime = 0.55,
		SparkSize = 0.12,
		SparkGold = Color3.fromHex("FFD23F"),
		SparkWhite = Color3.fromHex("FFFFFF"),
		SparkStroke = Color3.fromHex("040435"),
		-- T.61 : après 0,30, la voisine se retourne (1 → 0 en 0,10, Quad In), puis pop 0 → 1 en 0,45 (Back
		-- Out), étincelles et badge NEW! (1,6 s ; entrée en 0,3 et sortie en 0,15 : prototype).
		RevealDelay = 0.3,
		RevealShrink = 0.1,
		RevealPop = 0.45,
		BadgeText = "NEW!",
		BadgeHold = 1.6,
		BadgeIn = 0.3,
		BadgeOut = 0.15,
		-- T.67 à T.72 : navigation.
		DragThreshold = 6, -- px avant qu'un appui devienne un glisser (sinon c'est un clic sur la tuile)
		PanLimit = 0.55, -- décalage au plus : 55 % de la taille de l'arbre (zoomée)
		Rubber = 0.35, -- au-delà, l'arbre suit à 35 % (élastique)
		SnapTime = 0.35, -- au relâché hors limite, retour à la limite (Back Out)
		ZoomStep = 0.12, -- molette : ±12 % par cran
		ZoomTime = 0.14, -- lissage du zoom (Quad Out), molette et pincement
		ZoomMin = 0.75,
		ZoomMax = 1.8,
		StartTilePx = 100, -- zoom à l'ouverture : 1, ou plus pour que les tuiles fassent au moins 100 px
		-- Couche NavLayer posée par le code (T.74) : au-dessus de l'arbre, sous le panneau, l'argent et Close
		-- (ZIndex du prototype).
		NavLayerZIndex = 15,
	},

	-- Vague 59 (a189, L-182 points 1 à 3) : nouvelle direction de l'UI (vidéo de Break and Steal an Egg mesurée image
	-- par image). Valeurs de la ligne L-182, sauf celles marquées « V0 proposé, absent du doc ».
	-- Animations posées par Clément en attributs sur ses GuiObject (noms et valeurs : Contract/Attributes, Appear, Hover,
	-- Press) : Appear est joué par Controllers/UI/Appear (UiMotionController le lance à l'ouverture, Motion.Close et
	-- Motion.Hide attendent sa fermeture) ; Hover et Press par Motion.Button et Motion.HoverCard.
	Appear = {
		-- Pop : « cadre de 0,55 à 1 en 0,15 s, Quint Out, sans rebond ; fermeture en 0,07 s, Quad In ».
		-- Vague 64 (vidéo, sections 3 et 4) : ouverture 0,55 → 1 en 0,38 s Back Out, sans fondu ; fermeture Back In
		-- en 0,2 s jusqu'à 0 (elle prend son élan, puis disparaît).
		Pop = {
			From = 0.55,
			Time = if VIDEO_RHYTHM then 0.38 else 0.15,
			Style = if VIDEO_RHYTHM then Enum.EasingStyle.Back else Enum.EasingStyle.Quint,
			Direction = Enum.EasingDirection.Out,
			CloseTo = if VIDEO_RHYTHM then 0 else 0.4, -- L-188 : « fermeture de 1 à 0,4 en 0,07 s, Quad In »
			CloseTime = if VIDEO_RHYTHM then 0.2 else 0.07,
			CloseStyle = if VIDEO_RHYTHM then Enum.EasingStyle.Back else Enum.EasingStyle.Quad,
			CloseDirection = Enum.EasingDirection.In,
		},
		-- Cascade : « les enfants d'une liste entrent l'un après l'autre, 0,05 s d'écart, d'abord le fond puis le
		-- contenu » : le cadre (le fond) est là tout de suite, ses enfants visibles (sauf Template) entrent ensuite.
		-- Vague 64 : les cartes de la vidéo (22 ms d'écart, 0,2 → 1 en 0,13 s Quad Out, à partir de +230 ms, plafond
		-- ~0,15 s de décalage total) ; fermeture : tout part avec le cadre (CloseTo, CloseTime et la courbe de Pop).
		Cascade = {
			Gap = if VIDEO_RHYTHM then 0.022 else 0.05,
			Start = if VIDEO_RHYTHM then 0.23 else 0.05, -- L-188 : le contenu « une ou deux images après » le fond (0,05 s : entre les deux, à 30 images/s)
			From = if VIDEO_RHYTHM then 0.2 else 0, -- V0 proposé, absent du doc
			Time = if VIDEO_RHYTHM then 0.13 else 0.15, -- V0 proposé, absent du doc : comme Pop
			Style = if VIDEO_RHYTHM then Enum.EasingStyle.Quad else Enum.EasingStyle.Quint, -- V0 proposé, absent du doc : comme Pop
			Direction = Enum.EasingDirection.Out,
			Max = if VIDEO_RHYTHM then 8 else 14, -- V0 proposé, absent du doc : comme OpenStagger.Max (les suivants partent avec le 14e)
			Late = if VIDEO_RHYTHM then 0.45 else 0.3, -- V0 proposé, absent du doc : s pendant lesquelles un enfant cloné après l'ouverture entre aussi
			CloseTo = if VIDEO_RHYTHM then 0 else 0.4, -- V0 proposé, absent du doc : tous ensemble, comme la fermeture de Pop
			CloseTime = if VIDEO_RHYTHM then 0.2 else 0.07,
		},
		-- Vague 64 (a212 ; vidéo, section 3 : « titre à +130 ms, onglets à +200, lignes à +270 et +330, récompense à +400,
		-- bouton à +470 ») : dans un écran qui s'ouvre, les éléments Pop et Stamp posés DANS un cadre animé (un élément
		-- Appear, ou un cadre racine que Motion.Open met à l'échelle) sont des blocs : ils attendent cachés (UIScale à 0),
		-- puis entrent l'un après l'autre dans l'ordre de lecture (de haut en bas, puis de gauche à droite), le premier
		-- Start s après l'ouverture, Gap s entre deux ; si les blocs sont nombreux, l'écart se resserre pour que le dernier
		-- parte au plus tard Start + Span s après l'ouverture (tout en place en ~0,5 s). Un bloc Pop entre de From à 1 en
		-- Time (Style) ; un bloc Stamp garde son tampon. Les éléments Appear posés directement dans l'écran (le cadre),
		-- Cascade, SlideRight et DropIn ne sont pas des blocs. Enabled = false : pas de blocs (comme avant).
		Blocks = {
			Enabled = VIDEO_RHYTHM,
			Start = 0.13,
			Gap = 0.065,
			Span = 0.32,
			From = 0, -- V0 proposé, absent du doc : caché tant qu'il attend
			Time = 0.15, -- V0 proposé, absent du doc
			Style = Enum.EasingStyle.Back, -- V0 proposé, absent du doc : petit pop
			Direction = Enum.EasingDirection.Out,
			RowTolerance = 4, -- px : même rangée à 4 px près (comme OpenStagger)
		},
		-- Stamp : « titre de 1,6 à 1 et de −5° à 0 en 0,13 s ».
		Stamp = {
			From = 1.6,
			Tilt = -5, -- degrés, ajoutés à la Rotation posée par Clément, qui revient exactement
			Time = 0.13,
			Style = Enum.EasingStyle.Quad, -- V0 proposé, absent du doc
			Direction = Enum.EasingDirection.Out, -- V0 proposé, absent du doc
			CloseTo = if VIDEO_RHYTHM then 0 else 0.4, -- V0 proposé, absent du doc : comme Pop
			CloseTime = if VIDEO_RHYTHM then 0.2 else 0.07,
		},
		-- SlideRight : « panneau depuis le bord droit en 0,17 s, Quint Out ». Il part de juste derrière le bord droit
		-- de l'écran ; seule sa Position bouge, remise exactement à la fin.
		SlideRight = {
			Time = 0.17,
			Style = Enum.EasingStyle.Quint,
			Direction = Enum.EasingDirection.Out,
			CloseTime = 0.1, -- V0 proposé, absent du doc : il repart vers la droite
			CloseStyle = Enum.EasingStyle.Quad, -- V0 proposé, absent du doc
			CloseDirection = Enum.EasingDirection.In,
		},
		-- DropIn (L-188) : « tombe de sa hauteur à sa place en 0,25 s, Back Out, 0,05 s d'écart, puis se balance de ± 2 à
		-- 3° toutes les 1,2 s » (décor Decor.Hang1 à Hang4 de UI_RobuxShop). L'écart : entre frères DropIn, dans l'ordre
		-- LayoutOrder puis nom. Le balancement dure tant que l'élément est affiché ; pas de fermeture.
		DropIn = {
			Time = 0.25,
			Style = Enum.EasingStyle.Back,
			Direction = Enum.EasingDirection.Out,
			Gap = 0.05,
			Sway = 2.5, -- degrés de part et d'autre de la Rotation de Clément (« ± 2 à 3° »)
			SwayPeriod = 1.2, -- s pour un aller-retour
		},
		ScaleName = "AppearScale", -- V0 proposé, absent du doc : UIScale passager, détruit à la fin de l'animation
		SlideName = "AppearSlide", -- V0 proposé, absent du doc : NumberValue passagère du glissement
	},
	-- Hover = Pop : « × 1,10 en 0,067 s, un peu plus foncé (calque Shade, Hover.ShadeTransparency) ; une carte se
	-- penche de 3° et son objet grossit de 15 % en débordant » (carte : cadre avec HoverOutline, ou un cadre qui n'est
	-- pas un bouton). Son UI_Hover comme Hover.
	HoverPop = {
		To = 1.1,
		Time = 0.067,
		Style = Enum.EasingStyle.Quad, -- V0 proposé, absent du doc
		Direction = Enum.EasingDirection.Out,
		CardTilt = 3, -- degrés, ajoutés à la Rotation de la carte posée par Clément
		IconScale = 1.15, -- son Icon (pas de décalage ni de rotation de l'Icon, contrairement à HoverCard)
	},
	-- Press = Squash : « 0,75 en 0,033 s puis 1,1 et retour en 0,1 s » : 0,75 tant que le bouton est tenu, puis au
	-- relâché 1,1 et retour (à 1, ou au survol si la souris est dessus ; le pic est alors 1,1 fois le survol).
	PressSquash = {
		To = 0.75,
		Time = 0.033,
		Bounce = 1.1,
		BounceTime = 0.05, -- V0 proposé, absent du doc : la ligne ne donne que le total
		BackTime = 0.1,
		Style = Enum.EasingStyle.Quad, -- V0 proposé, absent du doc
		Direction = Enum.EasingDirection.Out,
	},
	-- Un seul son par action : le clic d'un bouton (son choisi dans les réglages, UI_Click_<Id>, SettingsController)
	-- se tait quand l'action a déjà son son (UI_Success des boutons de Success.Buttons ; UI_Open, UI_Close, UI_Deny
	-- joués par Motion dans les ClickGuard s autour du clic). UI_Hover ne compte pas.
	ClickGuard = 0.05, -- V0 proposé, absent du doc
	-- Raretés qui bougent (Controllers/UI/RarityFx) : un UIGradient (celui de Clément nommé GradientName, sinon créé
	-- par le code) sur le texte ou le fond d'une carte ; la couleur de l'élément passe au blanc le temps de l'effet
	-- (le dégradé porte les couleurs) et revient à Clear.
	RarityFx = {
		GradientName = "RarityGradient", -- nom des maquettes Figma (Clip.RarityGradient de l'index v4)
		-- « dégradé fixe jusqu'à Épique, reflet qui passe à Légendaire, arc-en-ciel qui défile pour Mythique et
		-- Secret » ; L-188 : Divine aussi en arc-en-ciel.
		Kinds = {
			Common = "Static",
			Uncommon = "Static",
			Rare = "Static",
			Epic = "Static",
			Legendary = "Sheen",
			Mythic = "Rainbow",
			Secret = "Rainbow",
			Divine = "Rainbow",
		} :: { [string]: string },
		Light = 0.25, -- V0 proposé, absent du doc : haut du dégradé, couleur de la rareté tirée vers le blanc
		Dark = 0.3, -- V0 proposé, absent du doc : bas du dégradé, tirée vers le noir
		Rotation = 90, -- V0 proposé, absent du doc : dégradé fixe de haut en bas
		SheenRotation = 45, -- V0 proposé, absent du doc : reflet en biais
		SheenPeriod = 2, -- V0 proposé, absent du doc : un reflet toutes les 2 s
		SheenPass = 0.6, -- V0 proposé, absent du doc : il traverse en 0,6 s
		SheenWidth = 0.12, -- V0 proposé, absent du doc : demi-largeur du reflet, en part de l'élément
		SheenColor = Color3.new(1, 1, 1),
		SheenStrength = 0.8, -- V0 proposé, absent du doc
		RainbowRotation = 0, -- V0 proposé, absent du doc : il défile de gauche à droite
		RainbowPeriod = 3, -- « cycle d'environ 3 s »
	},
	-- Flou derrière les boutiques et l'index (UiMotionController) : BlurEffect Name créé par le code dans Lighting
	-- (local au joueur), jamais pendant une poursuite (ChaseController.IsChased) ; détruit une fois parti.
	Blur = {
		Name = "UiBlur", -- V0 proposé, absent du doc
		Size = if WINDOW_E then 10 elseif WINDOW_TAS then 16 else 12, -- vague 74 (L-259) : « environ 10, à régler à l'œil » ; vague 73 (L-230) : « ≈ 16 »
		InTime = if WINDOW_TAS then 0.2 else 0.17, -- vague 74 (L-259) : 0,2 s Quad Out ; vague 73 : TweenInfo(0.2, Quad, InOut)
		OutTime = if WINDOW_E then 0.13 elseif WINDOW_TAS then 0.15 else 0.17, -- vague 74 : « à 0 en 0,13 s » ; vague 73 : 0,15 s ; avant : 0,17 s
		OutDelay = if WINDOW_E then 0 elseif WINDOW_TAS then 0.07 else 0, -- vague 73 : « sortie 70 ms après le clic »
		Style = if WINDOW_TAS then Enum.EasingStyle.Quad else Enum.EasingStyle.Quint,
		Direction = if WINDOW_E then Enum.EasingDirection.Out elseif WINDOW_TAS then Enum.EasingDirection.InOut else Enum.EasingDirection.Out,
		-- Vague 73 (L-230 : « sous la caméra, pour ne rien laisser dans Lighting ») : true = sous Workspace.CurrentCamera
		-- (Lighting si la caméra manque) ; false = dans Lighting, comme avant.
		UnderCamera = WINDOW_TAS,
		-- Écrans qui floutent le jeu derrière eux (V0 proposé : les boutiques d'achat et l'index, toutes versions) ;
		-- un autre ScreenGui aussi s'il porte l'attribut Attribute = true (posé par Clément).
		Screens = (if WINDOW_E then CENTRAL elseif WINDOW_TAS then WINDOWS else { "UI_WeaponShop", "UI_AuraShop", "UI_RobuxShop", "UI_RobuxShop_v2", "UI_DiamondShop", "UI_Index", "UI_Index_v2", "UI_Index_v3" }) :: { string },
		Attribute = "Blur",
	},
	-- Vague 74 (a258, L-259 b) : voile noir de Clément (écran Screen, cadre Frame) derrière la fenêtre de Blur.Screens
	-- allumée la plus haute (UiMotionController, en même temps que le flou, jamais en poursuite) : écran allumé à
	-- DisplayOrder de la fenêtre + Offset, cadre de transparence 1 à celle posée par Clément (0,62) en InTime, retour à 1
	-- en OutTime à la fermeture, puis écran éteint et valeurs de Clément remises. Une fenêtre qui en remplace une autre :
	-- le voile reste. Écran absent : pas de voile (flou seul). Enabled = false : jamais de voile.
	Veil = {
		Enabled = WINDOW_E,
		Screen = "UI_Veil",
		Frame = "Veil",
		Offset = -1, -- L-259 : « DisplayOrder égal à celui de la fenêtre moins 1 »
		InTime = 0.2, -- L-259 : 1 → 0,62 en 0,2 s, Quad Out
		OutTime = 0.13, -- L-259 : « à 0 en 0,13 s »
		Style = Enum.EasingStyle.Quad,
		Direction = Enum.EasingDirection.Out,
		CloseOnClick = true, -- V0 proposé (L-259 : « à toi de voir ») : un clic sur le voile ferme la fenêtre
	},
	-- Vague 64 (a212 ; L-188 B : « le HUD se cache derrière les fenêtres de boutique » ; vidéo, section 3 : la barre du
	-- bas descend hors de l'écran en ~150 ms à l'ouverture et revient en ~170 ms à la fermeture). Tant qu'un écran plein
	-- de Screens (ou un ScreenGui qui porte l'attribut Attribute = true, posé par Clément) est allumé, chaque élément de
	-- Targets descend par sa Position jusqu'à passer sous le bord du bas (taille inconnue : de Distance, en part de la
	-- hauteur de l'écran), puis revient exactement à la Position de Clément quand l'écran s'est éteint
	-- (UiMotionController → Controllers/UI/HudMask.SetAway). Jamais en poursuite : la barre reste ou revient. Réglage
	-- « animations réduites » : elle part et revient d'un coup. Enabled = false : rien ne bouge.
	HudAway = {
		Enabled = VIDEO_RHYTHM and not WINDOW_TAS, -- vague 73 : coupé, le HUD entier est caché (HudHide)
		-- V0 proposé, absent du doc : les boutiques d'achat (L-188 ; index et récompenses : Clément tranche).
		Screens = { "UI_WeaponShop", "UI_AuraShop", "UI_RobuxShop", "UI_RobuxShop_v2", "UI_DiamondShop" },
		Attribute = "HudAway", -- V0 proposé, absent du doc
		-- V0 proposé, absent du doc : la barre d'actions (écran, chemin depuis l'écran).
		Targets = { { Screen = "UI_Hotbar", Path = "Bar" } },
		Distance = 0.15, -- fiche, section 3 : « Position décalée de +15 % vers le bas »
		OutTime = 0.15,
		OutStyle = Enum.EasingStyle.Quad,
		OutDirection = Enum.EasingDirection.In,
		BackTime = 0.17,
		BackStyle = Enum.EasingStyle.Back,
		BackDirection = Enum.EasingDirection.Out,
		Recheck = 0.5, -- V0 proposé, absent du doc : s entre deux revues de la barre écartée (copie neuve de l'écran)
	},
	-- Vague 66 (a222, L-210 point 6 : « surtout l'apparition des éléments au défilement ») : dans une liste qui défile
	-- (ScrollingFrame) d'un écran de Screens (ou d'un ScreenGui avec l'attribut Attribute = true ; false le coupe), les
	-- cartes et lignes hors de la zone visible à l'ouverture entrent quand elles y arrivent en défilant, une fois chacune
	-- par ouverture, avec la courbe des cartes de la cascade (Appear.Cascade : From, Time, Style, Gap, Max).
	-- Controllers/UI/ScrollReveal, armé par UiMotionController. Enabled = false : rien ne bouge au défilement.
	ScrollReveal = {
		Enabled = VIDEO_RHYTHM,
		-- V0 proposé, absent du doc : boutiques, index, objets exposés (L-210), inventaire et récompenses.
		Screens = {
			"UI_WeaponShop", "UI_AuraShop", "UI_RobuxShop", "UI_RobuxShop_v2", "UI_DiamondShop", "UI_PawnShop",
			"UI_Index", "UI_Index_v2", "UI_Index_v3", "UI_Index_v4", "UI_Displayed", "UI_Inventory", "UI_Rewards",
		},
		Attribute = "ScrollReveal", -- V0 proposé, absent du doc
		ArmDelay = 0.6, -- V0 proposé, absent du doc : s après l'ouverture (la cascade d'ouverture a fini, ~0,55 s)
		Split = 0.5, -- V0 proposé, absent du doc : un enfant plus long que la moitié de la zone visible est une section (zone de l'index) : ses enfants entrent un par un
		Depth = 3, -- V0 proposé, absent du doc : niveaux de sections au plus
		ScaleName = "RevealScale", -- V0 proposé, absent du doc : UIScale passager, détruit à la fin
	},
	-- Vague 66 (a222, L-210 point 9 : « le bouton grossit et dépasse du cadre de la carte ») : un bouton posé dans une
	-- carte de liste (sous une ScrollingFrame) grossit au survol, au rebond de Press = Squash et à la réussite au plus
	-- jusqu'au bord de sa carte (le premier parent qui dessine un cadre : fond, UIStroke ou image), moins Inset px et
	-- l'épaisseur de son propre UIStroke. Aucun visuel de Clément changé (ni ClipsDescendants ni taille). Hors d'une
	-- liste (HUD…) : comme avant. Enabled = false : comme avant partout.
	-- Vague 73 (a256, L-230 point 1) : tant qu'une grande fenêtre (Windows, ou un ScreenGui avec l'attribut Attribute = true)
	-- est allumée, les écrans de Hide sont éteints à l'image même (Controllers/UI/HudMask, masque MaskKey), sans fondu, et
	-- rendus à l'image où elle s'éteint. Jamais en poursuite (comme le flou). Enabled = false : rien n'est caché.
	HudHide = {
		Enabled = WINDOW_TAS,
		Screens = WINDOWS,
		Attribute = "HideHud", -- V0 proposé, absent du doc
		Hide = { "UI_HUD", "UI_Hotbar" }, -- V0 proposé, absent du doc : le HUD (stats, argent, boutons de côté, barre du bas)
		MaskKey = "WindowHud", -- V0 proposé, absent du doc : clé du masque
		-- Correctif f70 (B2 ; décision de Cantin du 18/11, L-241 : UI_Hotbar.Bar.InventoryButton ouvre ET ferme
		-- UI_Displayed) : écrans de Hide qu'une grande fenêtre laisse allumés, par fenêtre. Un écran de Hide n'est gardé
		-- que si TOUTES les grandes fenêtres allumées le gardent. Flou et ouverture de ces fenêtres : inchangés.
		Keep = { UI_Displayed = { "UI_Hotbar" } } :: { [string]: { string } }, -- V0 proposé, absent du doc
	},
	HoverFit = {
		Enabled = true,
		Inset = 2, -- V0 proposé, absent du doc : px gardés entre le bouton grossi et le bord de la carte
	},
	-- a285 (21/11) : effets posés en attribut par Clément sur ses écrans, joués par Controllers/UI/UiAttrFx
	-- (Features.UiAttrFx). Valeurs des deux fiches de L-272, mesurées image par image (V0 proposés le 2026-11-21, à
	-- régler en jeu) : docs/claude/notes/ui-reference-tiktok-2026-11-21.md section 8 (« fiche HUD ») et
	-- ui-reference-shop-tiktok-2026-11-21.md section 5 (« fiche shop »). Une valeur que ni l'une ni l'autre ne donne
	-- est marquée « V0 a285, absent des fiches ».
	AttrFx = {
		-- Gleam = "Loop" | "Hover" (ItemName des cartes, de Crate et de Featured ; fiche shop, effet 3, aspect validé par
		-- Clément sur frames/apercu_reflet_titre.gif) : une copie blanche du texte par-dessus, à 0,92 sur les lettres et
		-- 0,35 sur le contour, avec une bande douce (cosinus) penchée qui défile.
		Gleam = {
			Name = "GleamFx", -- copie créée sur l'élément, détruite avec lui
			TextPeak = 0.92, -- opacité au cœur du reflet, sur les lettres
			StrokePeak = 0.35, -- opacité au cœur du reflet, sur le contour
			Rotation = 15, -- degrés
			Loop = { Pass = 3, Pause = 2, Width = 0.22, Style = Enum.EasingStyle.Sine }, -- Width : largeur de la bande
			Hover = { Pass = 0.8, Width = 0.12, Style = Enum.EasingStyle.Linear }, -- un passage au survol de la carte
		},
		-- UIGradient nommé Gleam, enfant d'un UIStroke ou d'un TextLabel (boutons du HUD, posés par Clément ; fiche HUD,
		-- demande 4) : Offset.X défile de From à To en Sweep s (Linear), puis Pause s, en boucle ; tous ceux d'un écran
		-- partent ensemble à son ouverture ; écran fermé ou caché : Offset remis à (From ; 0).
		GleamGradient = {
			Name = "Gleam",
			Sweep = 0.8,
			Pause = 1.9,
			From = -0.7,
			To = 0.7,
		},
		-- IconHover (fiche HUD, demandes 2 et 3 ; un seul contrat pour les deux fiches, tranché par a285 : valeurs de la
		-- fiche HUD, où Clément a déjà posé Jump) : au survol de l'élément (bouton ou carte), son enfant Icon…
		IconHover = {
			Icon = "Icon",
			-- … "Jump" : monte de Height × sa hauteur en Up s, redescend en Down s (Sine InOut), retrouve sa Position ;
			-- un saut par entrée, pas interrompu si la souris part, pas de nouveau saut avant la fin du précédent.
			Jump = { Height = 0.13, Up = 0.18, Down = 0.2 },
			-- … "Lean" : Rotation de la sienne à Tilt degrés en Time s (Quad Out), tenue au survol, retour en BackTime s.
			Lean = { Tilt = -3.5, Time = 0.07, BackTime = 0.07 },
			-- "Spring" (sur Crate, fiche shop effet 4 : la caméra de Icon.Preview suit le pointeur) : pas encore codé,
			-- rien ne bouge (une ligne en Studio).
		},
		-- Idle = "Wiggle" (Featured.Icon.Hammer, Decor.Hang1 à Hang4 ; fiche shop, effet 5) : toutes les Every s, un
		-- balancement de ± Angle degrés autour de sa Rotation en Time s ; les éléments d'un même écran décalés de
		-- Stagger s ; le premier Every s après l'affichage (après le DropIn d'Appear).
		Wiggle = {
			Angle = 12,
			Time = 0.8,
			Every = 4,
			Stagger = 0.7,
		},
		-- Idle = "Fall" (FallLayer des cartes d'argent ; fiche shop, effet 6) : des copies de son FallItem tombent du
		-- haut au bas du calque, avec un fondu ; le FallItem posé est caché le temps de l'effet et revient ensuite.
		Fall = {
			Layer = "FallLayer",
			Item = "FallItem",
			CopyName = "FallItemFx",
			Count = 12, -- copies en l'air au plus, par calque
			Time = 6, -- s de chute
			Transparency = 0.75, -- des copies
			MinScale = 0.7, -- taille des copies, en part du FallItem
			MaxScale = 1.1,
			SpeedSpread = 0.15, -- ± part de la vitesse de chute
			Spin = 40, -- V0 a285, absent des fiches : degrés de rotation au plus pendant la chute
			FadeIn = 0.15, -- V0 a285, absent des fiches : part de la chute
			FadeOut = 0.3, -- V0 a285, absent des fiches
		},
	},
}

export type UiMotion = typeof(UiMotion)

return DeepFreeze(UiMotion)
