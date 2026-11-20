--!strict
-- Roue de la fortune du hub (DEV-141 ; liaison L-165 point 3 : ENV_Hub_Wheel, zone WheelZone, écran UI_Wheel de
-- Clément ; vague 80, a266). Lu par WheelService (serveur : tirage, don, tour gratuit du jour) et WheelController
-- (client : textes des secteurs, animation). Coupée par Features.Wheel.
--
-- Toutes les valeurs sont des V0 proposés (Cantin, 20/11), absentes du doc, sauf « un tour gratuit par jour » et
-- « tours en plus en Robux » (consigne de la vague 80).
--
-- Règle : un tour gratuit par jour UTC (remise à zéro à minuit UTC, comme Config/Rewards). Le serveur tire le secteur
-- avec les poids ci-dessous AVANT l'animation, le donne, puis envoie WheelResult(secteur, message) au joueur : le
-- client fait tourner la roue jusqu'à ce secteur et montre le message. Un lot refusé (inventaire d'objets plein,
-- stock de potions plein) est remplacé par Fallback : le tour n'est jamais perdu pour rien.
-- Tours en plus en Robux : ExtraSpin.ProductId = 0 → coupés (bouton « Soon » s'il existe) ; le profil peut déjà
-- garder des tours en plus (WheelService.AddSpins, pas encore branché à MonetizationService).

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Un lot, partagé avec Config/Quests (serveur : Services/Prize/Grant) :
--   Cash    Minutes minutes de revenus (comme Config/Rewards : revenu par seconde bonus compris, au moins
--           Rewards.MinCashPerMinute $ par minute) ;
--   Box     l'objet d'un colis d'une rareté, donné tout de suite dans l'inventaire (vague 81 : comme le coffre de la
--           semaine, UnboxService.GiveBoxRarityItem, cette rareté ou mieux) ; zone = la plus haute parmi les objets du joueur ; rareté =
--           la Rank-ième de Rarities.ZoneRarities[zone] (1 = la plus basse ; "Top" ou au-delà de la liste = la plus haute) ;
--   Boost   boost ×2 argent pendant Minutes minutes (MonetizationService.AddCashBoost) ;
--   Potion  Count potions Potion (Id de Config/Potions) dans l'inventaire de potions (PotionService.AddStock).
export type PrizeKind = "Cash" | "Box" | "Boost" | "Potion"
export type Prize = {
	Kind: PrizeKind,
	Minutes: number?, -- Cash, Boost
	Rank: (number | string)?, -- Box : 1, 2… ou "Top" (1 par défaut)
	Potion: string?, -- Potion : Money, Strength, Invisibility
	Count: number?, -- Potion (1 par défaut)
}

-- Un secteur de la roue, dans l'ordre de Segment_01 à Segment_08 de UI_Wheel.
export type Sector = {
	Label: string, -- texte de Segment_NN.Amount (anglais, court)
	Icon: string?, -- Decal ICON_<Icon> livré par Clément (Contract/Icons) ; absent : l'icône de Clément reste
	Weight: number, -- poids du tirage (la chance = Weight / somme des poids)
	Prize: Prize,
}

local Wheel = {
	-- V0 proposé (Cantin, 20/11) : 8 secteurs (UI_Wheel en a 8), poids sur 100 pour lire la chance directement.
	Sectors = {
		{ Label = "5 MIN CASH", Icon = "WHEEL_Cash", Weight = 30, Prize = { Kind = "Cash", Minutes = 5 } }, -- V0 proposé (Cantin, 20/11)
		{ Label = "BOX", Icon = "WHEEL_Box", Weight = 20, Prize = { Kind = "Box", Rank = 1 } }, -- V0 proposé (Cantin, 20/11)
		{ Label = "x2 CASH 10 MIN", Icon = "WHEEL_Boost", Weight = 15, Prize = { Kind = "Boost", Minutes = 10 } }, -- V0 proposé (Cantin, 20/11)
		{ Label = "MONEY POTION", Icon = "WHEEL_PotionMoney", Weight = 5, Prize = { Kind = "Potion", Potion = "Money", Count = 1 } }, -- V0 proposé (Cantin, 20/11)
		{ Label = "15 MIN CASH", Icon = "WHEEL_Cash", Weight = 15, Prize = { Kind = "Cash", Minutes = 15 } }, -- V0 proposé (Cantin, 20/11)
		{ Label = "RARE BOX", Icon = "WHEEL_BoxRare", Weight = 7, Prize = { Kind = "Box", Rank = 2 } }, -- V0 proposé (Cantin, 20/11)
		{ Label = "STRENGTH POTION", Icon = "WHEEL_PotionStrength", Weight = 5, Prize = { Kind = "Potion", Potion = "Strength", Count = 1 } }, -- V0 proposé (Cantin, 20/11)
		{ Label = "60 MIN CASH", Icon = "WHEEL_Jackpot", Weight = 3, Prize = { Kind = "Cash", Minutes = 60 } }, -- V0 proposé (Cantin, 20/11)
	} :: { Sector },

	-- V0 proposé (Cantin, 20/11) : lot donné à la place d'un lot refusé (inventaire ou stock de potions plein).
	Fallback = { Kind = "Cash", Minutes = 5 } :: Prize,

	-- Tours en plus achetés en Robux. V0 proposé (Cantin, 20/11) : coupés tant que ProductId = 0 (aucun produit
	-- créé) ; Price n'est qu'affiché (PriceLabel). MaxExtra : tours en plus gardés au plus dans le profil.
	ExtraSpin = {
		ProductId = 0, -- V0 proposé (Cantin, 20/11) : 0 = pas encore de produit Robux
		Price = 25, -- V0 proposé (Cantin, 20/11) : Robux, affiché seulement
		MaxExtra = 99, -- V0 proposé (Cantin, 20/11)
	},

	-- Animation du client (WheelController). V0 proposé (Cantin, 20/11).
	SpinSeconds = 4.5, -- durée du tour (Quint Out)
	Turns = 5, -- tours complets avant de s'arrêter sur le secteur tiré
	Jitter = 0.3, -- écart au centre du secteur, en fraction de demi-secteur (0 = toujours au centre)
	ResultSeconds = 4, -- V0 proposé (Cantin, 20/11) : Result reste visible ce temps après l'arrêt

	-- Longueur d'un jour UTC (comme Config/Rewards.DayLength).
	DayLength = 86400,
	-- V0 proposé (Cantin, 20/11) : cadence (s) de la remise à jour des attributs (minuit UTC).
	Tick = 1,

	-- Attributs du Player, écrits par WheelService seulement, lus par WheelController.
	Attributes = {
		FreeReady = "WheelFreeReady", -- true : le tour gratuit du jour attend
		NextFreeAt = "WheelNextFreeAt", -- heure serveur (GetServerTimeNow) du prochain minuit UTC
		ExtraSpins = "WheelExtraSpins", -- tours en plus gardés (0 en V0)
	},

	-- Studio seulement (WheelService), barre de commande serveur :
	--   workspace:SetAttribute("WheelTest", "days <n>")            avance l'horloge de la roue de n jours
	--   workspace:SetAttribute("WheelTest", "reset <joueur>")      rend le tour gratuit du jour
	--   workspace:SetAttribute("WheelTest", "spins <joueur> <n>")  pose n tours en plus
	--   workspace:SetAttribute("WheelTest", "force <secteur>")     le prochain tour tombe sur ce secteur (1 à 8)
	TestAttribute = "WheelTest",

	-- Messages au joueur, en anglais (L-036). V0 proposés (Cantin, 20/11).
	Messages = {
		Potion = "+%d %s Potion!", -- %d = nombre, %s = nom de la potion (Config/Potions)
		NoSpin = "No spin left. Come back tomorrow!",
		Soon = "Soon",
		Free = "FREE SPIN",
		NextIn = "Next spin in %s", -- %s = « 12:34:56 »
		Spinning = "...",
		Fallback = "Prize unavailable, you got %s instead.", -- %s = le message du lot de repli
	},
}

export type Wheel = typeof(Wheel)

return DeepFreeze(Wheel)
