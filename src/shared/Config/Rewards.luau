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
--          l'ouverture de ce colis sur un rayon de cette zone (ShelfBoxes.ContentWeights, chance ×1), jamais
--          sous BoxRarity (plancher, vague 81) ;
--          UnboxService.GiveBoxRarityItem ;
--   Boost  boost ×2 argent pendant Minutes minutes (MonetizationService.AddCashBoost : compté seulement
--          en jeu, un 2e boost prolonge le 1er) ;
--   ZoneBox a309 (Cantin, 22/11) : un colis de zone, ouvert TOUT DE SUITE avec la scène d'ouverture de la caisse
--          exclusive (mêmes règles : Monetization.Crate.Reveal, zone safe seulement ; ailleurs, objet donné sans scène),
--          puis l'objet est dans l'inventaire (inventaire plein : refusé, comme Box). Zone et chances : la règle
--          ZoneBox[Rule] plus bas (Shared/ZoneBoxOdds lit Config/Zones et Rarities.ZoneOdds / ZoneRarities au moment
--          du tirage, rien n'est recopié ici) ; objet par Items.Pick(zone, rareté), comme les rayons ;
--          UnboxService.GiveZoneBoxItem.
export type RewardKind = "Cash" | "Box" | "Boost" | "ZoneBox"
export type Reward = {
	Kind: RewardKind,
	Minutes: number?, -- Cash, Boost
	Tier: string?, -- Box : Standard, Premium, Luxe
	BoxRarity: string?, -- Box (vague 80) : rareté du colis de rayon (Id de Config/Rarities) ; prime sur Tier
	MinRarity: string?, -- Box : rareté la plus basse possible (Id de Config/Rarities)
	MinZone: number?, -- Box : zone la plus basse possible
	Rule: string?, -- ZoneBox (a309) : nom de la règle dans Rewards.ZoneBox
}

-- a309 : règle d'un colis de zone (ZoneBox ; détail dans Shared/ZoneBoxOdds). Seuls les réglages de la règle sont ici :
-- zones, raretés de chaque zone et leurs chances se lisent dans Config/Zones et Config/Rarities, jamais recopiées.
export type ZoneBoxRule = {
	ZoneStep: number, -- zone de référence (la plus haute parmi les objets du joueur) + ZoneStep, au plus la dernière zone
	Exclude: { string }?, -- raretés jamais tirées (Id de Config/Rarities)
	TopCount: number?, -- seulement les TopCount meilleures raretés de la zone (Order), avec les poids TopWeights
	TopWeights: { number }?, -- de la plus basse à la plus haute ; une zone qui a moins de raretés prend les premiers
	TopBoost: number?, -- sans TopCount : chance de la plus haute rareté de la zone × TopBoost, l'écart pris sur la plus basse
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

	-- Paliers de temps de jeu dans la journée UTC (V0 3.3), du plus court au plus long. a309 (Cantin, 22/11 ; remplace les
	-- objets des colis Standard et Premium tirés dans Rarities.BoxOdds) : 15 et 60 min donnent un colis de zone (ZoneBox).
	Playtime = {
		{ Minutes = 5, Reward = { Kind = "Cash", Minutes = 2 } }, -- V0 3.3 : 2 min de revenus (100 $ au moins)
		{ Minutes = 15, Reward = { Kind = "ZoneBox", Rule = "BestZone" } }, -- validé par Cantin, 22/11 : colis de la meilleure zone
		{ Minutes = 30, Reward = { Kind = "Boost", Minutes = 10 } }, -- V0 3.3 : boost ×2 argent 10 min
		{ Minutes = 60, Reward = { Kind = "ZoneBox", Rule = "NextZone" } }, -- validé par Cantin, 22/11 : colis rare de la zone suivante
	} :: { PlaytimeTier },

	-- a309 (validé par Cantin, 22/11) : règles des colis de zone (Kind = "ZoneBox"), lues au moment du tirage par
	-- Shared/ZoneBoxOdds. Zone de référence = la plus haute parmi les objets du joueur (zone 1 sans objet).
	ZoneBox = {
		-- 15 min : un colis de la zone de référence, aux chances des rayons de cette zone (Rarities.ZoneOdds) améliorées :
		-- chance de la rareté la plus haute de la zone × 1,5, l'écart pris sur la plus basse (zone 3 : Rare 2 → 3 %,
		-- Commun 33 → 32 %) ; zone à une seule rareté (zone 1) : rien ne change. Secret compris (zone 6), comme les rayons.
		BestZone = { ZoneStep = 0, TopBoost = 1.5 },
		-- 60 min : un colis de la zone de référence + 1 (au plus la dernière zone de Config/Zones), tiré seulement parmi
		-- les 3 meilleures raretés de cette zone, sans Secret, à 60 / 30 / 10 % de la plus basse à la plus haute (zone 6 :
		-- Épique 60, Légendaire 30, Mythique 10). V0 (a309) : une zone à 2 raretés garde le rapport 60/30 (zone 2 :
		-- Commun 67, Peu commun 33).
		NextZone = { ZoneStep = 1, TopCount = 3, TopWeights = { 60, 30, 10 }, Exclude = { "Secret" } },
	} :: { [string]: ZoneBoxRule },

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
		-- Vague 81 (a268) : plancher à Épique (3.3 « Épique ») : Épique ou mieux, jamais un Rare.
		Reward = { Kind = "Box", BoxRarity = "Epic" } :: Reward, -- V0 proposé (Cantin, 20/11) : un objet Épique ou mieux (poids du colis Épique au-dessus du plancher) ; avant : colis Luxe, zone 2 au moins
		-- 3.3 : « l'aura ou le trail exclusif de la semaine ». [date du lundi en UTC, « AAAA-MM-JJ »] = Id de
		-- Config/Cosmetics (aura ou trail). Vide en V0 : seulement l'objet tant que Clément n'a rien livré.
		Exclusives = {} :: { [string]: string },
		-- Studio seulement : workspace:SetAttribute(TestAttribute, true) allume le coffre (Features.WeeklyChest
		-- à false) ; RewardTest « weekly <joueur> <jours> » pose les jours comptés de la semaine.
		TestAttribute = "WeeklyChestTest",
	},

	-- V0 : cadence (s) du compte du temps de jeu et de la remise à zéro de minuit (serveur).
	Tick = 1,

	-- a286 (Clément, L-224 point 3 : « récompense quotidienne seulement après le tuto ») : tant que le tuto du joueur
	-- n'est pas fini (profil Tutorial.Done, TutorialService), ClaimDaily est refusé (Messages.TutorialFirst) et le
	-- client montre le jour bloqué (attribut DailyLocked). Le temps de jeu et le coffre ne changent pas.
	DailyAfterTutorial = true,

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
		-- a286 (L-224 point 3, DailyAfterTutorial) : true tant que le tuto n'est pas fini (récompense du jour bloquée).
		DailyLocked = "RewardDailyLocked",
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
		TutorialFirst = "Finish the tutorial to claim your daily reward!", -- a286 : V0 du 2026-11-21 (L-224 point 3)
		Unavailable = "This gift can't be given right now. Try again later.",
		-- Coffre hebdomadaire (a166), V0 :
		WeeklyNotYet = "Play on %d different days this week to open the chest.", -- %d = Weekly.DaysNeeded
		WeeklyAlreadyClaimed = "Weekly chest already opened. Come back on Monday!",
		WeeklyExclusive = "Weekly exclusive: %s!", -- %s = le nom de l'aura ou du trail (Config/Cosmetics)
	},

	-- a303 (21/11, demande de Cantin : dire ce qu'on gagne à chaque palier) : texte du gain de chaque ligne de palier
	-- de UI_Rewards (PlaytimePage), en anglais (L-036), écrit par RewardsController d'après Playtime ci-dessus, dans
	-- RewardDesc (élément facultatif de Clément), sinon dans RewardName (Row). V0 proposés (2026-11-21), absents du doc.
	Texts = {
		Row = "%d min: %s", -- RewardName sans RewardDesc : %d = minutes du palier, %s = le gain
		Cash = "%s cash", -- %s = la somme (Format.money) : revenu répliqué (attribut Income du Player) × minutes, au moins MinCashPerMinute
		CashMinutes = "%d min of cash", -- revenu pas encore connu du client (attribut Income absent)
		Boost = "×2 Cash for %d min", -- %d = minutes du boost
		-- Box : l'objet d'un colis d'un type (Tier), donné tout de suite (UnboxService.GiveItem). Plus aucun palier de temps
		-- de jeu n'en donne depuis a309 (22/11 : « Item up to Epic / Mythic » abandonnés) ; un type absent : BoxDefault.
		Box = {} :: { [string]: string },
		-- a309 : colis de zone (Kind = "ZoneBox"), [Rule] = texte ; V0 (a309, 22/11). Une règle absente : BoxDefault.
		ZoneBox = {
			BestZone = "Box from your best zone",
			NextZone = "Rare box from the next zone",
		} :: { [string]: string },
		BoxFloor = "%s+ item", -- BoxRarity ou MinRarity : %s = la rareté plancher (Rarities DisplayName), « Epic+ item »
		BoxDefault = "Random item",
		-- Icône facultative : ImageLabel RewardIcon du Template, image prise dans le Decal de ce nom sous
		-- ReplicatedStorage/Assets (Texture non vide). Montrée seulement si les deux existent, sinon RewardIcon caché.
		Icons = {
			Cash = "UI_Icon_Reward_Cash",
			Box = "UI_Icon_Reward_Box",
			ZoneBox = "UI_Icon_Reward_Box", -- a309 : même icône que Box (V0)
			Boost = "UI_Icon_Reward_Boost",
		} :: { [string]: string },
	},
}

export type Rewards = typeof(Rewards)

return DeepFreeze(Rewards)
