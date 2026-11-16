--!strict
-- Nouveau HUD (vague 59, a190 ; liaison L-182 points 4, 7 et 8, L-183 `UI_HUD`) : réglages des animations du HUD
-- qui ne sont pas des attributs d'écran de Clément (ceux-là, Appear, Hover et Press, sont lus par le module d'a189).
-- Lu par HudController (CashSpent), GainController (tapis, TrainGainFly) et HudMenuController (TopLeftRow, boutons en situation).
-- Les durées viennent des fiches de Clément (L-182 : « environ 1,9 s, Quint Out », « 5 morceaux par seconde »,
-- « environ 0,75 s », « × 1,1 à × 1,4 toutes les 0,2 s ») ; le reste est marqué « V0 proposé, absent du doc ».
-- Unités : secondes ; échelles en part de la taille posée par Clément (1 = sa taille).

local DeepFreeze = require(script.Parent.DeepFreeze)

local Hud = {
	-- L-182 point 4 : après un achat (toute baisse de l'attribut Cash), le compteur Cash décompte de l'ancienne
	-- valeur à la nouvelle au lieu de sauter, et UI_HUD.CashSpent (TextLabel rouge de Clément, caché) montre
	-- le montant dépensé (« -$1.2K ») pendant le décompte. Plusieurs achats pendant le décompte : les montants
	-- s'additionnent et le décompte repart du nombre affiché.
	CashSpent = {
		Element = "CashSpent",
		Time = 1.9, -- L-182 : « environ 1,9 s »
		Style = Enum.EasingStyle.Quint, -- L-182 : « Quint Out »
		Direction = Enum.EasingDirection.Out,
		Hold = 0.3, -- V0 proposé, absent du doc : CashSpent reste encore 0,3 s après la fin du décompte
		Prefix = "-", -- V0 proposé, absent du doc : « -$1.2K » (Shared/Format.money derrière)
	},
	-- L-182 point 8 : sur le tapis, le gain d'une seconde (TrainingService, TREADMILL_TICK = 1, inchangé) s'affiche
	-- en ChunksPerSecond « +X » répartis sur la seconde (un toutes les 1 / ChunksPerSecond s), même total ; chacun
	-- vit Life s (montée et effacement de Config/UiMotion.FloatGain, plus courts).
	-- a200 (décision de Cantin, 2026-11-15 : « il faudrait qu'il n'y en ait que 1 par seconde ») : 1 = un seul
	-- « +X Speed/s » par seconde avec le gain entier (l'affichage d'avant a190, vie FloatGain.Time), le compteur
	-- Speed pulse une fois (SpeedPulse.Max) ; 5 = les morceaux d'a190 (code gardé).
	TreadmillGain = {
		ChunksPerSecond = 1, -- V0 (Cantin) : 1 par seconde ; L-182 disait « 5 morceaux par seconde »
		Period = 1, -- s couvertes par les morceaux : TREADMILL_TICK de TrainingService
		Life = 0.75, -- L-182 : « chaque +X vit environ 0,75 s »
		Text = "+%s Speed", -- V0 proposé, absent du doc : « +0.4 Speed » (un morceau n'est plus « par seconde »)
	},
	-- L-182 point 8 : le compteur de vitesse du HUD (SpeedRow s'il existe, sinon le nombre Speed) pulse à chaque
	-- morceau : il saute à une échelle entre Min et Max, puis revient à 1 en Time. Les 5 morceaux d'une seconde
	-- montent de Min à Max (V0 proposé, absent du doc : la fiche dit seulement « × 1,1 à × 1,4 »).
	SpeedPulse = {
		Min = 1.1,
		Max = 1.4,
		Time = 0.2, -- L-182 : « toutes les 0,2 s » ; retour à 1 avant le morceau suivant
		Style = Enum.EasingStyle.Quad, -- V0 proposé, absent du doc
		Direction = Enum.EasingDirection.Out,
		Row = "SpeedRow", -- cadre de Clément autour du nombre Speed (comme CashRow), facultatif
	},
	-- Vague 64 (a213, Cantin : « les gains de vitesse se déplacent vers lui pour dire que ça va vers là ») : chaque
	-- « +X » du tapis (un par seconde, ChunksPerSecond plus haut) jaillit du joueur, reste un instant, puis le compteur
	-- Speed du HUD l'aspire ; le nombre Speed ne monte qu'à son arrivée (HudController.HoldSpeed), avec la pulsation
	-- SpeedPulse. Mesures de la vidéo de référence (docs/claude/notes/2026-11-16_video-effets-ui.md, section 2 : « +8 »
	-- du banc, trajet joueur → compteur) ; le reste est « V0 proposé, absent du doc ». Animations réduites (VISUAL
	-- EFFECTS sur OFF ou ReducedMotionEnabled de Roblox), joueur hors de l'écran ou Enabled = false (ni plafond ni poursuite) :
	-- l'ancien « +X » qui monte sur place (BB_Gain, UiMotion.FloatGain) et le compteur qui pulse tout de suite.
	TrainGainFly = {
		Enabled = true,
		-- Modèle facultatif de Clément dans UI_HUD (Amount, Icon, Multiplier facultatif ; ses attributs SpeedColor et
		-- SpeedIcon passent avant ceux de BB_Gain). Absent : une copie de BB_Gain.Row dans un cadre fait par le code.
		Template = "TrainGainFly.Template",
		PopFrom = 0, -- fiche : « toute petite » sur le joueur
		PopTime = 0.08, -- fiche : taille finale en ≈ 80 ms
		PopStyle = Enum.EasingStyle.Back, -- fiche : « Back Out ou Quint Out » (Out)
		JetTime = 0.33, -- fiche : ≈ 350 px en ≈ 0,33 s, les deux tiers dans les 0,13 premières secondes
		JetStyle = Enum.EasingStyle.Quint, -- Out
		JetMin = 0.15, -- part de la largeur de l'écran (fiche : « 12 à 18 % », ≈ 350 px sur 1920) ; V0 dans cet écart
		JetMax = 0.18,
		JetAngle = 50, -- V0 proposé, absent du doc : degrés au plus de part et d'autre de la verticale (le gain monte)
		Hold = 0.7, -- fiche : presque immobile ≈ 0,7 s
		SuckTime = 0.15, -- fiche : aspiré en ≈ 0,15 s (Quad In)
		SuckStyle = Enum.EasingStyle.Quad, -- In
		EndScale = 0.3, -- fiche : rétrécit de 1 à ≈ 0,3
		Edge = 0.06, -- V0 proposé, absent du doc : le gain reste à 6 % au moins des bords de l'écran
		-- Repli sans modèle de Clément (V0 proposés, absents du doc) : hauteur en part de celle de l'écran (fiche : chiffre
		-- à ≈ 3,5 %, pastille comprise ≈ 5 %), largeur = Aspect × hauteur (« +2 Speed/s »), au-dessus du HUD (ZIndex).
		Height = 0.05,
		Aspect = 3.5,
		ZIndex = 10,
		Name = "TrainGain", -- V0 : nom des copies en vol dans UI_HUD (détruites à l'arrivée ; pas « TrainGainFly », le dossier du modèle)
	},
	-- Vague 63 (a205, L-202 point 1, L-192 Q1) : plus de menu « More » (MenuButton, MenuPanel retirés par Clément).
	-- Les petites icônes (RewardsButton, InviteButton, SettingsButton, RebirthButton) sont dans le cadre TopLeftRow,
	-- dans la barre de Roblox. Avec l'attribut FollowTopbarInset = true, le code le cale sur la place libre de cette
	-- barre : bord gauche à GuiService.TopbarInset.Min.X + Gap px (valeur de Clément), centré en hauteur dans la barre.
	TopLeftRow = {
		Frame = "TopLeftRow",
		Attribute = "FollowTopbarInset",
		Gap = 8, -- L-202 (Clément) : « TopbarInset.Min.X + 8 px »
	},
	-- Cadence (s) du recalcul des boutons en situation (tapis, couloir) et de leur recharge. V0 proposé, absent du doc.
	Refresh = 0.1,
}

export type Hud = typeof(Hud)

return DeepFreeze(Hud)
