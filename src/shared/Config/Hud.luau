--!strict
-- Nouveau HUD (vague 59, a190 ; liaison L-182 points 4, 7 et 8, L-183 `UI_HUD`) : réglages des animations du HUD
-- qui ne sont pas des attributs d'écran de Clément (ceux-là, Appear, Hover et Press, sont lus par le module d'a189).
-- Lu par HudController (CashSpent), GainController (tapis) et HudMenuController (menu, boutons en situation).
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
	-- en Pieces « +X » répartis sur la seconde (un toutes les 1 / Pieces s), même total ; chacun vit Life s
	-- (montée et effacement de Config/UiMotion.FloatGain, plus courts). Pieces = 1 : l'ancien affichage
	-- (« +2 Speed/s », un BB_Gain par seconde).
	TreadmillGain = {
		Pieces = 5, -- L-182 : « 5 morceaux par seconde »
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
	-- L-183 : menu de la colonne de gauche (MenuButton ouvre MenuPanel). V0 proposé, absent du doc : le menu se
	-- referme quand on choisit un de ses boutons, ou au 2e appui sur MenuButton.
	Menu = {
		Button = "MenuButton",
		Panel = "MenuPanel",
		Alert = "MenuAlert",
		CloseOnPick = true,
	},
	-- Cadence (s) du recalcul des boutons en situation (tapis, couloir) et de leur recharge. V0 proposé, absent du doc.
	Refresh = 0.1,
}

export type Hud = typeof(Hud)

return DeepFreeze(Hud)
