--!strict
-- Récompenses quotidiennes et de temps de jeu (DEV-101 ; Partie 2, section 3.3 et « Proposition V0
-- d'Ironix » juste dessous ; liaison L-057). Lu par RewardService (serveur) et RewardsController (client).
--
-- Origine de chaque valeur, notée en commentaire :
--   3.3     section 3.3 de la Partie 2 (calendrier, jour manqué, minuit UTC) ;
--   V0 3.3  « Proposition V0 d'Ironix (2026-11-08) », écrite sous la section 3.3 (minimum par minute,
--           zone des colis, boost, paliers de temps de jeu) ;
--   V0      V0 proposé, absent du doc.
-- Unités : minutes pour les récompenses et les paliers (comme le doc), secondes ailleurs.
--
-- Le coffre hebdomadaire (3.3) reste pour la MAJ 1 : pas d'onglet dans UI_Rewards, rien ici.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Une récompense :
--   Cash   Minutes minutes de revenus (revenu par seconde du joueur au moment où il réclame, bonus
--          compris, comme le HUD), au moins MinCashPerMinute $ par minute ;
--   Box    un colis Tier mis dans l'inventaire (un Tool de la barre, à poser au sol de sa boutique) :
--          zone = la plus haute parmi les objets du joueur (zone 1 sans objet), au moins MinZone ;
--          rareté tirée avec les probabilités de ce type de colis dans cette zone, seulement parmi
--          MinRarity et au-dessus si MinRarity est donné ;
--   Boost  boost ×2 argent pendant Minutes minutes (MonetizationService.AddCashBoost : compté seulement
--          en jeu, un 2e boost prolonge le 1er).
export type RewardKind = "Cash" | "Box" | "Boost"
export type Reward = {
	Kind: RewardKind,
	Minutes: number?, -- Cash, Boost
	Tier: string?, -- Box : Standard, Premium, Luxe
	MinRarity: string?, -- Box : rareté la plus basse possible (Id de Config/Rarities)
	MinZone: number?, -- Box : zone la plus basse possible
}

-- Un palier de temps de jeu : Minutes de jeu dans la journée UTC.
export type PlaytimeTier = {
	Minutes: number,
	Reward: Reward,
}

local Rewards = {
	-- Calendrier de 7 jours (3.3), une réclamation par jour, dans l'ordre J1 à J7.
	Daily = {
		{ Kind = "Cash", Minutes = 5 }, -- 3.3 : J1, 5 min de revenus
		{ Kind = "Box", Tier = "Standard" }, -- 3.3 : J2, colis Standard
		{ Kind = "Cash", Minutes = 15 }, -- 3.3 : J3, 15 min de revenus
		{ Kind = "Box", Tier = "Premium" }, -- 3.3 : J4, colis Premium
		{ Kind = "Boost", Minutes = 15 }, -- 3.3 : J5, boost ×2 argent 15 min
		{ Kind = "Cash", Minutes = 30 }, -- 3.3 : J6, 30 min de revenus
		-- 3.3 : J7, colis Luxe garanti Épique ou mieux ; V0 3.3 : zone 2 au moins (la zone 1 n'a que des
		-- Communs, L-033).
		{ Kind = "Box", Tier = "Luxe", MinRarity = "Epic", MinZone = 2 },
	} :: { Reward },

	-- Paliers de temps de jeu dans la journée UTC (V0 3.3), du plus court au plus long.
	Playtime = {
		{ Minutes = 5, Reward = { Kind = "Cash", Minutes = 2 } }, -- V0 3.3 : 2 min de revenus (100 $ au moins)
		{ Minutes = 15, Reward = { Kind = "Box", Tier = "Standard" } }, -- V0 3.3 : colis Standard
		{ Minutes = 30, Reward = { Kind = "Boost", Minutes = 10 } }, -- V0 3.3 : boost ×2 argent 10 min
		{ Minutes = 60, Reward = { Kind = "Box", Tier = "Premium" } }, -- V0 3.3 : colis Premium
	} :: { PlaytimeTier },

	-- V0 3.3 : « X min de revenus » rapporte au moins 50 $ par minute (J1 : 250 $ au moins).
	MinCashPerMinute = 50,

	-- 3.3 : remise à zéro à minuit UTC. Longueur d'un jour UTC, en secondes (os.time() // DayLength =
	-- numéro du jour UTC).
	DayLength = 86400,

	-- 3.3 : un jour manqué fait reculer d'un jour au lieu de repartir à J1. V0 (le doc ne dit pas pour
	-- plusieurs jours) : un jour de recul par jour manqué, jamais avant J1. Après J7, un nouveau cycle
	-- repart à J1.
	BackPerMissedDay = 1,

	-- V0 : cadence (s) du compte du temps de jeu et de la remise à zéro de minuit (serveur).
	Tick = 1,

	-- Attributs du Player, écrits par RewardService seulement, lus par RewardsController :
	Attributes = {
		Day = "RewardDay", -- jour du calendrier d'aujourd'hui (1 à 7)
		DailyClaimed = "RewardDailyClaimed", -- true : le jour d'aujourd'hui est réclamé
		DayEndsAt = "RewardDayEndsAt", -- heure serveur (GetServerTimeNow) du prochain minuit UTC
		PlayStart = "RewardPlayStart", -- heure serveur où le temps de jeu du jour vaudrait 0 (jeu = maintenant − PlayStart)
		PlayClaimed = "RewardPlayClaimed", -- paliers réclamés aujourd'hui, en minutes : « 5,15 » (vide : aucun)
	},

	-- Studio seulement (RewardService) : workspace:SetAttribute(TestAttribute, …), barre de commande serveur :
	--   « days <n> »               avance l'horloge des récompenses de n jours (tout le serveur) ;
	--   « play <joueur> <secondes> » ajoute ce temps de jeu à la journée du joueur ;
	--   « reset <joueur> »         remet ses récompenses à zéro (calendrier et temps de jeu).
	TestAttribute = "RewardTest",

	-- Messages au joueur (Notify), en anglais (L-036). V0 proposés, absents du doc.
	Messages = {
		Cash = "+%s cash!", -- %s = la somme (Format.money)
		Box = "%s Box added to your inventory!", -- %s = le type (« Standard »)
		Boost = "×2 Cash for %d min!",
		AlreadyClaimed = "Already claimed today. Come back tomorrow!",
		NotYet = "Keep playing to unlock this gift.",
		BoxesFull = "Too many boxes in your inventory: open some, then claim your gift.",
		Unavailable = "This gift can't be given right now. Try again later.",
	},
}

export type Rewards = typeof(Rewards)

return DeepFreeze(Rewards)
