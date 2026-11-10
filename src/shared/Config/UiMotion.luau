--!strict
-- Animations d'UI (DEV-052 ; Partie 1, section 2.2, « Libre pour Ironix : … animer à l'ouverture
-- et à la fermeture ») : ouverture et fermeture des écrans de Clément (UI_WeaponShop, UI_AuraShop,
-- UI_TheftAlert et son repli V0), apparition et disparition d'éléments du HUD (HeistTimer,
-- GuardMeter), chiffres qui défilent (Cash, Income). Lu par Controllers/UI/Motion (client).
-- L'échelle passe par un UIScale créé par le code et détruit à la fin de chaque animation : aucun
-- visuel de Clément ne change (couleur, taille, position, image, police, transparence).
--
-- Toutes les valeurs ci-dessous sont des V0 proposés, absents du doc, à régler à l'œil en jeu.
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
	-- Bouton survolé à la souris (Motion.Hover, boutons fixes du HUD : demande de Cantin, 2026-11-10) :
	-- il grossit jusqu'à To, puis revient à 1 quand la souris sort.
	Hover = {
		To = 1.08, -- V0 proposé, absent du doc
		Time = 0.12, -- V0 proposé, absent du doc
		Style = Enum.EasingStyle.Back, -- V0 proposé, absent du doc : petit rebond, l'effet « pop »
		Direction = Enum.EasingDirection.Out, -- V0 proposé, absent du doc
		ScaleName = "HoverScale", -- V0 proposé, absent du doc : UIScale à part, retiré quand le bouton est revenu à 1
	},
	-- V0 proposé, absent du doc : nom du UIScale ajouté par le code sur un cadre animé (jamais un
	-- nom du contrat 2.2 ; il disparaît à la fin de l'animation).
	ScaleName = "MotionScale",
}

export type UiMotion = typeof(UiMotion)

return DeepFreeze(UiMotion)
