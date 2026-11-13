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

local UiMotion = {
	-- Écran qui s'ouvre (Motion.Open) : ses cadres racine (Root) passent de From à 1. Valeurs validées par
	-- Clément sur les prototypes (L-094 ; tableau « Étendues à tout le jeu » de
	-- docs/claude/notes/ui-motion-skilltree.md, ligne « Fenêtre qui s'ouvre », qui remplace l'ancien V0
	-- 0,9 → 1 en 0,25 ; tools/clement/inventory_proto.luau, OpenFrom et OpenTime).
	Open = {
		From = 0.55, -- tableau : « Root 0,55 → 1 en 0,14 », Back Out
		Time = 0.14,
		Style = Enum.EasingStyle.Back, -- le Back Out dépasse un peu 1 (environ 1,04), puis revient à 1
		Direction = Enum.EasingDirection.Out,
	},
	-- Contenu qui arrive après la fenêtre (Motion.Open, puis chaque carte ou rangée) : de From à 1 en
	-- Time, la première Start s après l'ouverture, puis Gap s entre deux, Max cartes au plus (les
	-- suivantes partent avec la Max-ième). Tableau : ligne « Contenu qui arrive après la fenêtre ».
	OpenStagger = {
		From = 0, -- tableau : « chaque carte ou rangée 0 → 1 en 0,14 ; départ à 0,08 ; 0,035 entre deux, 14 au plus »
		Time = 0.14,
		Start = 0.08,
		Gap = 0.035,
		Max = 14,
		Style = Enum.EasingStyle.Back,
		Direction = Enum.EasingDirection.Out,
		-- Cartes = cadres qui ont un enfant HoverOutline (HoverCard.Outline). Sans carte visible : les
		-- enfants visibles de ces cadres (prototype tools/clement/ui_feel_proto.luau, staggerItems).
		Rows = { "Rows", "Tree", "Body", "DailyPage" },
		RowTolerance = 4, -- px : même rangée à 4 px près, triée de gauche à droite (prototype ui_feel_proto)
		ScaleName = "StaggerScale", -- V0 proposé, absent du doc : UIScale passager de chaque carte
	},
	-- Écran qui se ferme (Motion.Close) : sortie courte de 1 à To, puis l'écran s'éteint. Tableau :
	-- « Fenêtre qui se ferme : 1 → 0 en 0,09 », Quad In (L-094).
	Close = {
		To = 0,
		Time = 0.09,
		Style = Enum.EasingStyle.Quad,
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
}

export type UiMotion = typeof(UiMotion)

return DeepFreeze(UiMotion)
