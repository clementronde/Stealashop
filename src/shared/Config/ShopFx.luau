--!strict
-- Animations des boutiques (vague 63, a209 ; liaison L-204 points 1 à 3, d'après L-188 et les maquettes Figma
-- validées par Clément le 2026-11-16) : réglages lus par Controllers/UI/CrateLoop (boucle de la caisse exclusive),
-- Controllers/UI/PurchaseGlow (lueur arc-en-ciel d'un achat Robux) et Controllers/UI/DiamondBalance (solde de
-- diamants de UI_DiamondShop). Les valeurs de L-204 sont marquées « L-204 » ; le reste est « V0 proposé, absent du
-- doc », à régler à l'œil en jeu.
-- Unités : secondes, degrés ; « px » = pixels de la maquette Figma de la caisse (1130 × 372), convertis à la taille
-- affichée (CrateLoop : hauteur de Crate / DesignHeight) ; échelles en part de la taille posée par Clément (1 = sa taille).

local DeepFreeze = require(script.Parent.DeepFreeze)

local ShopFx = {
	-- 1. Caisse exclusive (`Crate` de UI_RobuxShop_v2, et de UI_RobuxShop si elle y est) : boucle de Period s tant
	-- que l'écran est allumé et la caisse à l'écran ; tout revient à la place de Clément à la fermeture.
	Crate = {
		Screens = { "UI_RobuxShop_v2", "UI_RobuxShop" },
		Element = "Crate",
		Period = 4, -- L-204 : « boucle de 4 s »
		DesignHeight = 372, -- hauteur de Crate dans la maquette (px)
		-- Backdrop.Rays : −45° en 4 s, linéaire (16 rayons : la boucle ne saute pas) ; son UIGradient Fade tourne à
		-- l'inverse (L-203 a : Fade.Rotation = −Rays.Rotation), sinon le fondu tourne avec les rayons.
		RaysTurn = -45, -- L-204
		FadeName = "Fade",
		-- Backdrop.Glow : transparence de GlowFrom à GlowTo (à mi-boucle) puis retour.
		GlowFrom = 0.45, -- L-204
		GlowTo = 0, -- L-204
		-- Icon (la caisse) : ± Bob px en Y, un aller-retour toutes les BobPeriod s (elle monte d'abord).
		Bob = 7, -- L-204 : « ± 7 px en Y toutes les 2 s »
		BobPeriod = 2, -- L-204
		-- puis une secousse centrée sur ShakeAt : ± ShakeAngle° (ShakeTurns allers-retours qui s'amortissent) et
		-- × ShakePop au milieu.
		ShakeAt = 2.8, -- L-204 : « vers 2,8 s »
		ShakeTime = 0.4, -- V0 proposé, absent du doc
		ShakeAngle = 5, -- L-204 : « ± 5° »
		ShakeTurns = 3, -- V0 proposé, absent du doc
		ShakePop = 1.05, -- L-204 : « × 1,05 »
		-- Backdrop.Shadow : se serre quand la caisse monte, s'élargit quand elle descend (largeur seulement).
		ShadowSpread = 0.12, -- V0 proposé, absent du doc : ± 12 % de largeur au bout du mouvement
		-- Odds.Odd_n : ± OddBob px en Y autour de leur place (jamais Size), décalées de OddPhase rad l'une de l'autre ;
		-- RarityGlow et Star suivent la case qu'ils entourent.
		OddBob = 4, -- L-204
		OddPeriod = 2, -- V0 proposé, absent du doc (comme la caisse ; 4 s doit en être un multiple)
		OddPhase = 0.9, -- L-204 : « décalées de 0,9 rad »
		-- Odds.Star : × StarMin → StarMax → StarMin en StarTime s, l'une après l'autre (de la plus commune à la plus
		-- rare), la première à StarStart s, puis toutes les StarGap s ; StarMin entre deux.
		StarMin = 0.2, -- L-204
		StarMax = 1.25, -- L-204
		StarTime = 0.6, -- L-204
		StarStart = 0.2, -- V0 proposé, absent du doc
		StarGap = 0.6, -- V0 proposé, absent du doc : à la suite (6 étoiles en 3,8 s)
		-- Odds.RarityGlow : pulse (× 1 → GlowPulseScale, et plus opaque) toutes les GlowPulsePeriod s.
		GlowPulsePeriod = 2, -- V0 proposé, absent du doc
		GlowPulseScale = 1.1, -- V0 proposé, absent du doc
		GlowPulseFade = 0.2, -- V0 proposé, absent du doc : + 0,2 de transparence au creux du pulse
		-- BuyRow.BuyButton3 : × ButtonPop, au sommet à ButtonAt s, en ButtonTime s.
		Button = "BuyButton3",
		ButtonAt = { 1.1, 3.1 }, -- L-204
		ButtonPop = 1.05, -- L-204
		ButtonTime = 0.3, -- V0 proposé, absent du doc
		-- NewBadge : saute une fois par boucle (BadgeJump px vers le haut en BadgeTime s, à partir de BadgeAt s).
		BadgeAt = 0.3, -- V0 proposé, absent du doc
		BadgeTime = 0.35, -- V0 proposé, absent du doc
		BadgeJump = 8, -- V0 proposé, absent du doc
		-- À l'ouverture, les cases de Odds (Appear = Cascade de Clément) entrent une à une, de la plus commune
		-- (Odd_1) à la plus rare, toutes les CellGap s ; RarityGlow et Star entrent avec leur case.
		CellGap = 0.033, -- L-204
		-- Decor (Hang1 à Hang4, DropIn) : caché sur téléphone (L-203 d).
		Decor = "Decor",
	},
	-- 2. Lueur d'un achat Robux : UI_PurchaseGlow.RainbowBorder s'allume d'un coup, le UIGradient tourne, le HUD se
	-- cache ; tout s'efface en FadeTime s à la fin de l'invite d'achat (ou au bout de Timeout s, filet de sécurité).
	PurchaseGlow = {
		Screen = "UI_PurchaseGlow",
		Element = "RainbowBorder",
		TurnsPerSecond = 0.5, -- L-204 : « environ 0,5 tour/s »
		FadeTime = 0.1, -- L-204
		Timeout = 60, -- V0 proposé, absent du doc : l'invite de Roblox n'a rien renvoyé
		-- Couleurs écrites seulement sur un UIGradient laissé blanc (celles de Clément sont gardées).
		Colors = { "1DC395", "3C9AB6", "8B63D9", "FF5CC8", "FFC21A" }, -- L-204
		-- Écrans du HUD cachés pendant l'achat (Controllers/UI/HudMask) ; les autres écrans restent.
		HideScreens = { "UI_HUD", "UI_Hotbar" }, -- V0 proposé, absent du doc
		MaskKey = "PurchaseGlow",
	},
	-- 3. Diamants (UI_DiamondShop, seul endroit où le solde s'affiche, décision de Clément) : Header.Balance.Amount
	-- écrit l'attribut Attribute du joueur ; une baisse (un achat) décompte comme Cash (Config/Hud.CashSpent : 1,9 s,
	-- Quint Out) et montre Balance.Spent (« -X », rouge) : il apparaît en SpentIn s, reste SpentHold s, puis monte de
	-- SpentRise (part de sa hauteur) et s'efface en SpentOut s.
	Diamonds = {
		Screen = "UI_DiamondShop",
		Amount = "Balance.Amount",
		Spent = "Balance.Spent",
		Attribute = "Diamonds", -- V0 proposé, absent du doc : publié par DataService au chargement du profil (fusion57 ; aucun achat en diamants encore)
		Prefix = "-", -- comme CashSpent
		SpentIn = 0.2, -- L-204
		SpentHold = 1, -- L-204
		SpentOut = 0.3, -- L-204
		SpentRise = 0.6, -- V0 proposé, absent du doc : il monte de 0,6 fois sa hauteur
	},
}

export type ShopFx = typeof(ShopFx)

return DeepFreeze(ShopFx)
