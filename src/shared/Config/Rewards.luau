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
-- Coffre hebdomadaire (3.3, MAJ 1 ; agent a166) : Weekly ci-dessous, coupé par Features.WeeklyChest.

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Une récompense :
--   Cash   Minutes minutes de revenus (revenu par seconde du joueur au moment où il réclame, bonus
--          compris, comme le HUD), au moins MinCashPerMinute $ par minute ;
--   Box    l'objet d'un colis Tier, donné tout de suite dans l'inventaire (vague 43, Cantin du 2026-11-14 :
--          plus de colis à ouvrir en base ; UnboxService.GiveItem) : zone = la plus haute parmi les objets
--          du joueur (zone 1 sans objet), au moins MinZone ; rareté tirée avec les probabilités de ce type
--          de colis dans cette zone, seulement parmi MinRarity et au-dessus si MinRarity est donné ; objet
--          de cette rareté dans la zone, mutation et taille tirées comme à la mise en rayon ;
--          Vague 80 (a267) : avec BoxRarity au lieu de Tier, c'est un colis de RAYON de cette rareté (vague 76 :
--          les colis des rayons n'ont plus de type) : zone = la plus haute parmi les objets du joueur, au moins
--          MinZone et au moins la première zone où cette rareté existe ; rareté de l'objet tirée comme à
--          l'ouverture de ce colis sur un rayon de cette zone (ShelfBoxes.ContentWeights, chance ×1) ;
--          UnboxService.GiveBoxRarityItem ;
--   Boost  boost ×2 argent pendant Minutes minutes (MonetizationService.AddCashBoost : compté seulement
--          en jeu, un 2e boost prolonge le 1er).
export type RewardKind = "Cash" | "Box" | "Boost"
export type Reward = {
	Kind: RewardKind,
	Minutes: number?, -- Cash, Boost
	Tier: string?, -- Box : Standard, Premium, Luxe
	BoxRarity: string?, -- Box (vague 80) : rareté du colis de rayon (Id de Config/Rarities) ; prime sur Tier
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

	-- Coffre hebdomadaire (3.3 ; agent a166, MAJ 1), coupé par Features.WeeklyChest. Semaine = du lundi
	-- 00:00 UTC au dimanche (V0 : UTC, comme le calendrier) ; son numéro = (jour UTC + MondayOffset) // 7.
	Weekly = {
		DaysNeeded = 5, -- 3.3 : 5 jours de connexion différents entre lundi et dimanche
		MondayOffset = 3, -- le jour UTC 0 (1/1/1970) était un jeudi : jour + 3 tombe sur un multiple de 7 le lundi
		-- 3.3 : « 1 colis Luxe » ; depuis le 14/11 (Cantin, vague 43) un objet tiré comme un colis Luxe
		-- (UnboxService.GiveItem). Vague 80 (a267) : plus de colis Luxe sur les rayons (vague 76) : un colis Épique
		-- de rayon, ouvert dans la meilleure zone du joueur (zone 4 au moins, la première qui a des Épiques).
		Reward = { Kind = "Box", BoxRarity = "Epic" } :: Reward, -- V0 proposé (Cantin, 20/11) ; avant : colis Luxe, zone 2 au moins
		-- 3.3 : « l'aura ou le trail exclusif de la semaine ». [date du lundi en UTC, « AAAA-MM-JJ »] = Id de
		-- Config/Cosmetics (aura ou trail). Vide en V0 : seulement l'objet tant que Clément n'a rien livré.
		Exclusives = {} :: { [string]: string },
		-- Studio seulement : workspace:SetAttribute(TestAttribute, true) allume le coffre (Features.WeeklyChest
		-- à false) ; RewardTest « weekly <joueur> <jours> » pose les jours comptés de la semaine.
		TestAttribute = "WeeklyChestTest",
	},

	-- V0 : cadence (s) du compte du temps de jeu et de la remise à zéro de minuit (serveur).
	Tick = 1,

	-- Attributs du Player, écrits par RewardService seulement, lus par RewardsController :
	Attributes = {
		Day = "RewardDay", -- jour du calendrier d'aujourd'hui (1 à 7)
		DailyClaimed = "RewardDailyClaimed", -- true : le jour d'aujourd'hui est réclamé
		DayEndsAt = "RewardDayEndsAt", -- heure serveur (GetServerTimeNow) du prochain minuit UTC
		PlayStart = "RewardPlayStart", -- heure serveur où le temps de jeu du jour vaudrait 0 (jeu = maintenant − PlayStart)
		PlayClaimed = "RewardPlayClaimed", -- paliers réclamés aujourd'hui, en minutes : « 5,15 » (vide : aucun)
		-- Coffre hebdomadaire (a166) : absents (nil) quand le coffre est coupé.
		WeeklyDays = "RewardWeeklyDays", -- jours de connexion comptés cette semaine (0 à 7)
		WeeklyClaimed = "RewardWeeklyClaimed", -- true : le coffre de cette semaine est réclamé
		WeekEndsAt = "RewardWeekEndsAt", -- heure serveur (GetServerTimeNow) du prochain lundi 00:00 UTC
	},

	-- Studio seulement (RewardService) : workspace:SetAttribute(TestAttribute, …), barre de commande serveur :
	--   « days <n> »               avance l'horloge des récompenses de n jours (tout le serveur) ;
	--   « play <joueur> <secondes> » ajoute ce temps de jeu à la journée du joueur ;
	--   « reset <joueur> »         remet ses récompenses à zéro (calendrier, temps de jeu, coffre) ;
	--   « weekly <joueur> <jours> » pose les jours comptés de sa semaine (coffre allumé seulement).
	TestAttribute = "RewardTest",

	-- Messages au joueur (Notify), en anglais (L-036). V0 proposés, absents du doc.
	Messages = {
		Cash = "+%s cash!", -- %s = la somme (Format.money)
		Box = "%s Box added to your inventory!", -- %s = le type (« Standard ») ; plus utilisé depuis la vague 43
		Item = "%s Item: %s", -- vague 43 : %s = la rareté (« Rare »), puis le nom de l'objet, mutation comprise
		ItemsFull = "Your inventory is full: display or sell an item, then claim your gift.", -- vague 43
		Boost = "×2 Cash for %d min!",
		AlreadyClaimed = "Already claimed today. Come back tomorrow!",
		NotYet = "Keep playing to unlock this gift.",
		BoxesFull = "Too many boxes in your inventory: open some, then claim your gift.",
		Unavailable = "This gift can't be given right now. Try again later.",
		-- Coffre hebdomadaire (a166), V0 :
		WeeklyNotYet = "Play on %d different days this week to open the chest.", -- %d = Weekly.DaysNeeded
		WeeklyAlreadyClaimed = "Weekly chest already opened. Come back on Monday!",
		WeeklyExclusive = "Weekly exclusive: %s!", -- %s = le nom de l'aura ou du trail (Config/Cosmetics)
	},
}

export type Rewards = typeof(Rewards)

return DeepFreeze(Rewards)
