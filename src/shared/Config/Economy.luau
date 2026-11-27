--!strict
-- Économie « B/T » (a486, 25/11 ; note d'a479 « a479-economie-BT », décisions de Cantin du 25/11) : les deux tables
-- de nombres de l'économie et celle qui est active sur ce serveur. Même principe que le catalogue d'objets v2 / v3
-- (Config/Items, a429).
--
--   table 1  l'économie d'avant, recopiée telle quelle (les nombres écrits dans chaque module de Config) ;
--   table 2  l'économie « B/T » : raretés × 60 (Secret à 50B $/s), zone 6 à Speed 30T, tapis à 6 crédits par seconde
--            et 25 niveaux, prix refaits (note d'a479, « Liste exacte des valeurs de Config à changer »).
--
-- Table active (Economy.Version, Economy.Active) : la 2 avec Features.EconomyBT (partout, false) ou avec
-- Features.EconomyBTDev dans le jeu DEV (true) ; sinon la 1. Calculée une fois, au chargement : chaque module de
-- Config y lit ses nombres au chargement (Rarities, Zones, Balance, Tools, Cosmetics, Training, Upgrades, ShopGrowth,
-- SkillTree, Rebirths, Chase, Leaderboard, WeeklyLeaderboard, Admin, Offline ; Net/Definitions pour la borne de
-- l'admin). Aucun service ne teste l'interrupteur. Sans republier : une clé Feature_EconomyBT du Creator Hub
-- (Shared/LiveFeatures) ; elle n'est pas dans LiveFeatures.Hot, donc prise au prochain serveur. Un profil sauvegardé
-- dans l'autre table est converti à son chargement, dans les deux sens (Shared/EconomyProfile, DataService).
--
-- Comment un module lit la table : par Economy.Override, la table à appliquer PAR-DESSUS les nombres de son fichier.
-- Avec la table 1, Override vaut nil : rien n'est remplacé, les nombres écrits dans chaque module restent seuls en
-- jeu, exactement comme avant a486 (les anciens bancs qui retouchent ces nombres dans une copie de src gardent aussi
-- leur effet). Tables[1] en est la copie : elle sert à la conversion des profils, et le banc a486 vérifie qu'elle
-- vaut les nombres des modules. Avec la table 2, Override = Tables[2] : chaque module y prend ses nombres.
--
-- Le jeu DEV est reconnu ici par game.GameId = DevGameId, la règle de Config/ProductIds en « Auto » et du choix du
-- store des profils (DataService). Ce module ne peut pas lire ProductIds.IsDev : ProductIds exige Balance, et
-- Balance lit ce module (boucle de require). DevGameId est donc écrit une seconde fois ici ; le banc a486 vérifie
-- qu'il vaut Balance.Profiles.DevGameId et que Economy.IsDev suit ProductIds.IsDev.
-- a500 (26/11) : le jeu est maintenant reconnu par Config/GameEnv (module feuille, sans boucle) : le jeu TEST compte comme
-- le DEV (EconomyBTDev, table 2). DEV_GAME_ID ne sert plus que de repli sans GameEnv (bancs à liste de modules fixe).
--
-- Changer un nombre de la table 2 (taux du hors ligne, prix d'un niveau du tapis…) : une valeur ci-dessous, aucun
-- code à toucher. Ne jamais changer la table 1 : c'est l'économie des profils de PROD et le repère de la conversion.
--
-- API :
--   Economy.Version: number            1 ou 2, la table active
--   Economy.Active: Table              Economy.Tables[Economy.Version]
--   Economy.Override: Table?           la table à appliquer par-dessus les nombres des modules : nil avec la table 1,
--                                      Economy.Active sinon (voir plus haut)
--   Economy.Tables: { Table }          les deux tables
--   Economy.IsDev: boolean             ce serveur est le jeu DEV ou le jeu TEST (a500)
--   Economy.IsTest: boolean            ce serveur est le jeu TEST (a500)
--   Economy.RebirthAllowed: boolean    la renaissance peut s'allumer avec la table active (table 2 : seulement avec
--                                      Features.RebirthBT ; lu par Config/Rebirths.Enabled)
--   Economy.VersionFor(features, gameId) -> number    le même choix pour des interrupteurs et un GameId donnés (bancs)

local DeepFreeze = require(script.Parent.DeepFreeze)

-- Module de Config chargé s'il est là (bancs à liste de modules fixe, comme dans Config/Items).
local function optional(name: string): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild(name)
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end
local Features: any = optional("Features")

export type Table = {
	Version: number,
	-- Config/Rarities : Income[RarityId], $/s de base de la rareté.
	Income: { [string]: number },
	-- a497 : règle de zone du revenu (Config/Rarities.IncomeRules.ZoneRule ; Formulas.ItemIncome) : × ZoneFactor par zone de
	-- l'objet ; Secret et Divin en zone NoZone, caisse exclusive en zone ExclusiveZone. nil (table 1) : +25 % par zone.
	IncomeRule: { ZoneFactor: number, NoZone: number, ExclusiveZone: number }?,
	-- Config/Zones : SpeedRequired des zones 1 à 6 (Speed affichée du panneau).
	SpeedRequired: { number },
	-- Config/Balance.Stats : WalkSpeed = min(Max, Base + WalkPerDecade × log10(1 + Speed affichée / SpeedScale)).
	WalkPerDecade: number,
	SpeedScale: number,
	-- Config/Training.Treadmill.GainPerSecond : crédits de Vitesse par seconde au niveau 1 du tapis.
	TreadmillGainPerSecond: number,
	-- Config/Upgrades, Treadmill : MaxLevel (niveaux achetés ; niveaux affichés = MaxLevel + 1) et Costs (MaxLevel prix).
	TreadmillMaxLevel: number,
	TreadmillCosts: { number },
	-- Config/Upgrades, DisplaySlots : Costs (16 prix : 5e à 20e présentoir ; avec l'étage, seuls les 4 premiers servent).
	DisplaySlotCosts: { number },
	-- Config/ShopGrowth.Floor2 : Cost (l'étage) et Costs (ses 8 places).
	Floor2Cost: number,
	Floor2Costs: { number },
	-- Config/Tools : Price[ToolId].
	ToolPrices: { [string]: number },
	-- Config/Cosmetics : Price[Id] des auras (les 8 de Clément et les 6 anciennes, au prix de leur équivalente) et des trails.
	CosmeticPrices: { [string]: number },
	-- Config/SkillTree : Prices[SkillId] = { prix du niveau 1, du niveau 2… }.
	SkillPrices: { [string]: { number } },
	-- Config/Rebirths : Cash des renaissances 1 à 10.
	RebirthCash: { number },
	-- Config/Chase.Zone1SpeedRequired : ce que donne l'étape « Train » du tutoriel (10 s de tapis au niveau 1).
	Zone1SpeedRequired: number,
	-- Config/Leaderboard : classement Speed rangé en logarithme (comme Income) ; suffixe du nom des OrderedDataStore
	-- des classements de cette table (Config/Leaderboard, Config/WeeklyLeaderboard) : les valeurs d'une table ne se
	-- comparent pas à celles de l'autre.
	LeaderboardSpeedLog: boolean,
	LeaderboardSuffix: string,
	-- Config/Admin.MaxAmount et borne `value` du remote AdminCommand (Net/Definitions).
	AdminMaxAmount: number,
	-- Config/Offline.Rate : part des revenus gagnée hors ligne (1 = 100 %). Le plafond d'heures : OfflineMaxHours.
	OfflineRate: number,
	-- a515 (Cantin, 27/11) : Config/Offline.MaxHours, plafond de base de l'absence comptée, en heures (+30 min par nœud
	-- OfflineTime de l'arbre).
	OfflineMaxHours: number,
	-- Config/Balance.Profiles.DevStoreName : store des profils du jeu DEV (un nouveau nom = profils DEV remis à zéro,
	-- comme le 14/11 ; rien n'est effacé, l'autre store reste intact). Le store de PROD ne dépend jamais de la table.
	DevStoreName: string,
}

-- Table 1 : l'économie d'avant. Les mêmes nombres que ceux écrits dans chaque module de Config (banc a486) ; jamais
-- appliquée aux modules (Economy.Override), lue par la conversion des profils.
local TABLE_1: Table = {
	Version = 1,
	Income = { Common = 1, Uncommon = 8, Rare = 60, Epic = 450, Legendary = 3_500, Mythic = 25_000, Secret = 150_000, Divine = 750_000 },
	SpeedRequired = { 0, 3_000, 100_000, 3_000_000, 100_000_000, 3_000_000_000 },
	WalkPerDecade = 4,
	SpeedScale = 100,
	TreadmillGainPerSecond = 1,
	TreadmillMaxLevel = 19,
	TreadmillCosts = { 150, 570, 2_200, 2_800, 3_600, 4_600, 15_000, 46_000, 140_000, 430_000, 1_300_000, 3_700_000, 14_000_000, 51_000_000, 190_000_000, 700_000_000, 2_600_000_000, 9_600_000_000, 35_000_000_000 },
	DisplaySlotCosts = { 500, 1_300, 1_600, 2_100, 2_800, 3_600, 4_800, 9_800, 20_000, 42_000, 72_000, 120_000, 300_000, 750_000, 1_800_000, 4_300_000 },
	Floor2Cost = 2_800,
	Floor2Costs = { 3_600, 4_800, 9_800, 20_000, 42_000, 72_000, 120_000, 300_000 },
	ToolPrices = { Fists = 0, Wrench = 300, Crowbar = 3_100, Hammer = 88_000, Sledgehammer = 1_200_000, FireAxe = 9_900_000, AngleGrinder = 69_000_000 },
	CosmeticPrices = {
		-- Les 8 auras de Clément.
		Shine = 100,
		Fire = 4_700,
		Storm = 22_000,
		Poison = 130_000,
		Tornado = 1_900_000,
		Angel = 15_000_000,
		Demon = 39_000_000,
		Chained = 110_000_000,
		-- Les 6 anciennes auras (retirées de la boutique).
		Spark = 100,
		Flame = 4_700,
		Lightning = 130_000,
		Plasma = 1_900_000,
		Galaxy = 15_000_000,
		Royal = 110_000_000,
		-- Trails.
		Dust = 100,
		Wind = 3_100,
		Turbo = 88_000,
		Comet = 1_200_000,
		Hyperspace = 30_000_000,
	},
	SkillPrices = {
		Walls = { 1_300, 8_300, 120_000, 1_600_000 },
		GlassThickness = { 1_900, 9_600, 88_000, 630_000, 6_000_000 },
		GlassRegen = { 2_600, 15_000, 100_000, 630_000, 5_000_000 },
		Cameras = { 980, 5_300, 100_000 },
		Bodyguards = { 3_800, 49_000, 530_000, 7_900_000, 160_000_000 },
		PotionLuck = { 1_700, 12_000, 150_000 },
		Curtain = { 2_600, 27_000 },
		DoorGuard = { 530_000 },
		PotionTime = { 3_800, 49_000 },
		Traps = { 27_000, 180_000, 1_100_000, 9_900_000 },
		BoxLuck = { 6_000, 50_000, 450_000, 4_000_000, 35_000_000 },
		FittingRoom = { 50_000 },
		OfflineTime1 = { 250_000 },
		OfflineTime2 = { 2_500_000 },
	},
	RebirthCash = { 170e6, 4.2e9, 11e9, 17e9, 22e9, 27e9, 42e9, 59e9, 63e9, 76e9 },
	Zone1SpeedRequired = 10,
	LeaderboardSpeedLog = false,
	LeaderboardSuffix = "",
	AdminMaxAmount = 1e15,
	OfflineRate = 1,
	OfflineMaxHours = 4,
	DevStoreName = "PlayerData_DEV_20261114",
}

-- Table 2 : l'économie « B/T » (note d'a479, passe 4, validée par Cantin le 25/11). a497 (Cantin, 26/11 ; note
-- a497-note-gains-zone, sections 1 et 5) : revenus × 25 par rareté et × 10 par zone (IncomeRule), et les prix recalés sur
-- ces revenus : la zone 6 vers 20 h pour le joueur moyen, et la force d'une zone (son kit) en autant de temps que sa
-- vitesse. Chaque nombre vient des notes ; n'en changer aucun sans elles.
local TABLE_2: Table = {
	Version = 2,
	-- a497 : × 25 par rareté (25^rareté, Commun = 1), le revenu de base d'un objet de zone 1 ; la zone multiplie par 10
	-- (IncomeRule ; Formulas.ItemIncome). Avant (a486) : × 60 par rareté et +25 % par zone.
	Income = { Common = 1, Uncommon = 25, Rare = 625, Epic = 15_625, Legendary = 390_625, Mythic = 9_765_625, Secret = 244_140_625, Divine = 6_103_515_625 },
	-- a497 (Cantin, 26/11) : × 10 par zone de l'objet ; Secret et Divin comptent en zone 6, la caisse exclusive en zone 5,5.
	IncomeRule = { ZoneFactor = 10, NoZone = 6, ExclusiveZone = 5.5 },
	-- × 107 environ par zone jusqu'à la zone 5 ; zone 6 à 30T (décision de Cantin : le joueur moyen y arrive en 20 h).
	SpeedRequired = { 0, 15_000, 1_600_000, 170_000_000, 19_000_000_000, 30_000_000_000_000 },
	-- Calés sur les zones 2 à 5 : la marche aux panneaux reste 22, 28, 34, 40 ; zone 6 : 49,4 (avant 46).
	WalkPerDecade = 2.95,
	SpeedScale = 140,
	TreadmillGainPerSecond = 6,
	-- 25 niveaux affichés. Découpage de Cantin : niveaux 1 à 3 en zone 1, 4 à 8 en zone 2, 9 à 12 en zone 3, 13 à 16
	-- en zone 4, 17 à 25 en zone 5, avec un grand saut à l'entrée de chaque zone. Niveaux 19 à 25 : au moins une absence
	-- complète de 5 h du joueur moyen, payée à 50 % (la règle du hors ligne, en zone 5 seulement ; OfflineRate). a497 :
	-- prix recalés sur les revenus × 25 / × 10 (avant, a490 : 150, 450, 590, 1,2K … 2,7T) ; 93T et 500T au lieu de 94T
	-- et 490T (note a497) pour garder × 1,5 au moins d'un niveau au suivant de 19 à 25.
	TreadmillMaxLevel = 24,
	TreadmillCosts = { 150, 450, 17_000, 35_000, 63_000, 120_000, 240_000, 1_200_000, 2_400_000, 4_400_000, 7_800_000, 3.6e9, 7.6e9, 16e9, 34e9, 1.7e12, 5.3e12, 33e12, 60e12, 93e12, 140e12, 220e12, 330e12, 500e12 },
	DisplaySlotCosts = { 600, 1_600, 17_000, 34_000, 3_100_000, 5_200_000, 8_300_000, 3.3e9, 7.4e9, 15e9, 650e9, 1.6e12, 5.5e12, 12e12, 30e12, 75e12 },
	Floor2Cost = 3_100_000,
	Floor2Costs = { 5_200_000, 8_300_000, 3.3e9, 7.4e9, 15e9, 650e9, 1.6e12, 5.5e12 },
	-- Les puissances ne changent pas. a497 : le kit d'une zone (arme et aura de Config/Zones.Kit) coûte ce qu'il faut pour
	-- que sa force arrive en même temps que sa vitesse ; Wrench et Shine (zone 2) restent payés par les dons du tuto.
	ToolPrices = { Fists = 0, Wrench = 400, Crowbar = 550_000, Hammer = 250_000_000, Sledgehammer = 350e9, FireAxe = 160e12, AngleGrinder = 1.2e15 },
	CosmeticPrices = {
		Shine = 130,
		Fire = 320_000,
		Storm = 83_000_000,
		Poison = 250_000_000,
		Tornado = 350e9,
		Angel = 66e12,
		Demon = 420e12,
		Chained = 1.2e15,
		-- Anciennes auras : le prix de leur équivalente (Config/Cosmetics.Migration).
		Spark = 130,
		Flame = 320_000,
		Lightning = 250_000_000,
		Plasma = 350e9,
		Galaxy = 66e12,
		Royal = 1.2e15,
		Dust = 100,
		Wind = 37_000,
		Turbo = 2_000_000,
		Comet = 12e9,
		Hyperspace = 21e12,
	},
	-- Un prix garde sa valeur comptée en revenus (courbe « dollar de la passe 4 → nouveau dollar », a497, arrondie à
	-- 2 chiffres).
	SkillPrices = {
		Walls = { 1_700, 30_000, 22_000_000, 31e9 },
		GlassThickness = { 2_600, 58_000, 9_400_000, 2.4e9, 1.8e12 },
		GlassRegen = { 3_500, 280_000, 13_000_000, 2.4e9, 1e12 },
		Cameras = { 1_300, 9_300, 13_000_000 },
		Bodyguards = { 5_600, 3_800_000, 1.5e9, 4.2e12, 110e12 },
		PotionLuck = { 2_300, 120_000, 41_000_000 },
		Curtain = { 3_500, 1_500_000 },
		DoorGuard = { 1.5e9 },
		PotionTime = { 5_600, 3_800_000 },
		Traps = { 1_500_000, 67_000_000, 12e9, 8.6e12 },
		BoxLuck = { 11_000, 3_800_000, 900_000_000, 520e9, 29e12 },
		FittingRoom = { 3_800_000 },
		-- 1 h du revenu de référence de la zone 3, puis de la zone 5.
		OfflineTime1 = { 120_000_000 },
		OfflineTime2 = { 39e12 },
	},
	-- V0 d'attente : la renaissance est coupée avec cette table (Features.RebirthBT), à resimuler (a497 : courbe).
	RebirthCash = { 120e12, 3e15, 8e15, 12e15, 16e15, 19e15, 30e15, 43e15, 46e15, 55e15 },
	Zone1SpeedRequired = 60,
	LeaderboardSpeedLog = true,
	LeaderboardSuffix = "_E2",
	AdminMaxAmount = 1e30,
	-- L-413 (Cantin le 25/11, Clément le 26/11 ; a490) : 50 % des revenus ; a515 (Cantin, 27/11) : 2 h au plus au lieu de
	-- 4 h (Config/Offline.MaxHours, +30 min par nœud OfflineTime de l'arbre : 3 h avec les deux).
	OfflineRate = 0.5,
	OfflineMaxHours = 2,
	-- Décision de Cantin (25/11) : profils du jeu DEV remis à zéro avec cette table. a497 (V0 de la note, question 9) :
	-- encore une fois avec les revenus × 25 / × 10 (avant : PlayerData_DEV_BT_20261125).
	DevStoreName = "PlayerData_DEV_BT_20261126",
}

-- a513 (Cantin, 27/11 ; L-444 b) : table 2 du poids V2 (Features.WeightIncomeV2 / WeightIncomeV2Dev ; Tables[2] quand
-- Economy.WeightIncomeV2). Avec le revenu proportionnel au poids (Config/Weight, ×9 en moyenne à ×1 au lieu de ×1,22),
-- les prix de la table 2 sont remis à l'échelle pour que le joueur moyen du simulateur entre dans chaque zone au même
-- temps qu'aujourd'hui (9 min, 41 min, 1 h 51, 6 h 01, 21 h 01 ; note a513-page). Règle : prix de la table 2 × le facteur
-- de sa bande, arrondi à 2 chiffres : moins de 10K ×1 (le début ne change pas), 10K à 100K ×2, 100K à 1M ×3,5, 1M à 1B
-- ×1,2, 1B à 600B ×3, 600B et plus ×5. Exceptions : niveaux 21 et 24 du tapis à 460T et 1,65Qa (× 1,5 au moins d'un
-- niveau au suivant, comme a497). Renaissances et arbre : la même règle (non simulés). Tout le reste : la table 2.
local WEIGHT_V2_PRICES = {
	TreadmillCosts = { 150, 450, 34_000, 70_000, 130_000, 420_000, 840_000, 1_400_000, 2_900_000, 5_300_000, 9_400_000, 11e9, 23e9, 48e9, 100e9, 8.5e12, 27e12, 170e12, 300e12, 460e12, 700e12, 1.1e15, 1.65e15, 2.5e15 },
	DisplaySlotCosts = { 600, 1_600, 34_000, 68_000, 3_700_000, 6_200_000, 10_000_000, 9.9e9, 22e9, 45e9, 3.3e12, 8e12, 28e12, 60e12, 150e12, 380e12 },
	Floor2Cost = 3_700_000,
	Floor2Costs = { 6_200_000, 10_000_000, 9.9e9, 22e9, 45e9, 3.3e12, 8e12, 28e12 },
	ToolPrices = { Fists = 0, Wrench = 400, Crowbar = 1_900_000, Hammer = 300_000_000, Sledgehammer = 1.1e12, FireAxe = 800e12, AngleGrinder = 6e15 },
	CosmeticPrices = {
		Shine = 130,
		Fire = 1_100_000,
		Storm = 100_000_000,
		Poison = 300_000_000,
		Tornado = 1.1e12,
		Angel = 330e12,
		Demon = 2.1e15,
		Chained = 6e15,
		Spark = 130,
		Flame = 1_100_000,
		Lightning = 300_000_000,
		Plasma = 1.1e12,
		Galaxy = 330e12,
		Royal = 6e15,
		Dust = 100,
		Wind = 74_000,
		Turbo = 2_400_000,
		Comet = 36e9,
		Hyperspace = 110e12,
	},
	SkillPrices = {
		Walls = { 1_700, 60_000, 26_000_000, 93e9 },
		GlassThickness = { 2_600, 120_000, 11_000_000, 7.2e9, 9e12 },
		GlassRegen = { 3_500, 980_000, 16_000_000, 7.2e9, 5e12 },
		Cameras = { 1_300, 9_300, 16_000_000 },
		Bodyguards = { 5_600, 4_600_000, 4.5e9, 21e12, 550e12 },
		PotionLuck = { 2_300, 420_000, 49_000_000 },
		Curtain = { 3_500, 1_800_000 },
		DoorGuard = { 4.5e9 },
		PotionTime = { 5_600, 4_600_000 },
		Traps = { 1_800_000, 80_000_000, 36e9, 43e12 },
		BoxLuck = { 22_000, 4_600_000, 1.1e9, 1.6e12, 150e12 },
		FittingRoom = { 4_600_000 },
		OfflineTime1 = { 140_000_000 },
		OfflineTime2 = { 200e12 },
	},
	RebirthCash = { 600e12, 15e15, 40e15, 60e15, 80e15, 95e15, 150e15, 220e15, 230e15, 280e15 },
}
local TABLE_2_WEIGHT_V2: Table = table.clone(TABLE_2)
TABLE_2_WEIGHT_V2.TreadmillCosts = WEIGHT_V2_PRICES.TreadmillCosts
TABLE_2_WEIGHT_V2.DisplaySlotCosts = WEIGHT_V2_PRICES.DisplaySlotCosts
TABLE_2_WEIGHT_V2.Floor2Cost = WEIGHT_V2_PRICES.Floor2Cost
TABLE_2_WEIGHT_V2.Floor2Costs = WEIGHT_V2_PRICES.Floor2Costs
TABLE_2_WEIGHT_V2.ToolPrices = WEIGHT_V2_PRICES.ToolPrices
TABLE_2_WEIGHT_V2.CosmeticPrices = WEIGHT_V2_PRICES.CosmeticPrices
TABLE_2_WEIGHT_V2.SkillPrices = WEIGHT_V2_PRICES.SkillPrices
TABLE_2_WEIGHT_V2.RebirthCash = WEIGHT_V2_PRICES.RebirthCash

local TABLES: { Table } = { TABLE_1, TABLE_2 }

-- a500 : Config/GameEnv chargé s'il est là (voir l'en-tête) ; sans lui, le jeu DEV seul, comme avant.
local GameEnv: any = (function(): any
	local env = optional("GameEnv")
	return if type(env.IsDevLikeFor) == "function" then env else nil
end)()

-- « Steal a Shop [DEV] » : GameEnv.DevGameId ; repli sans GameEnv : le même nombre que Balance.Profiles.DevGameId.
local DEV_GAME_ID: number = if GameEnv ~= nil then GameEnv.DevGameId else 10774974820

local function currentGameId(): number?
	local ok, id = pcall(function(): any
		return (game :: any).GameId
	end)
	return if ok and type(id) == "number" then id else nil
end

local function isDevGame(gameId: number?): boolean
	if GameEnv ~= nil then
		return GameEnv.IsDevLikeFor(gameId) == true -- a500 : DEV ou TEST
	end
	return gameId ~= nil and gameId ~= 0 and gameId == DEV_GAME_ID
end

local function versionFor(features: any, gameId: number?): number
	if type(features) ~= "table" then
		return 1
	end
	if features.EconomyBT == true or (features.EconomyBTDev == true and isDevGame(gameId)) then
		return 2
	end
	return 1
end

local GAME_ID = currentGameId()
local VERSION = versionFor(Features, GAME_ID)

-- a513 (Cantin, 27/11 ; L-444 b) : poids → revenu proportionnel (Config/Weight lit Economy.WeightIncomeV2), avec la
-- table 2 seulement : Features.WeightIncomeV2 (partout) ou WeightIncomeV2Dev (DEV et TEST). Allumé, la table 2 prend
-- les prix remis à l'échelle (TABLE_2_WEIGHT_V2) ; coupé, ou avec la table 1, tout est comme avant.
local function weightV2For(features: any, gameId: number?): boolean
	return type(features) == "table"
		and versionFor(features, gameId) == 2
		and (features.WeightIncomeV2 == true or (features.WeightIncomeV2Dev == true and isDevGame(gameId)))
end
local WEIGHT_V2 = weightV2For(Features, GAME_ID)
if WEIGHT_V2 then
	TABLES[2] = TABLE_2_WEIGHT_V2
end

local Economy = {
	Version = VERSION,
	Active = TABLES[VERSION],
	-- La table à appliquer par-dessus les nombres des modules : aucune avec la table 1 (voir l'en-tête).
	Override = (if VERSION ~= 1 then TABLES[VERSION] else nil) :: Table?,
	Tables = TABLES,
	IsDev = isDevGame(GAME_ID),
	IsTest = GameEnv ~= nil and GameEnv.IsTestFor(GAME_ID) == true,
	DevGameId = DEV_GAME_ID,
	-- Renaissance coupée avec la table 2 (décision de Cantin, 25/11 : à resimuler), sauf Features.RebirthBT.
	RebirthAllowed = VERSION ~= 2 or Features.RebirthBT == true,
	VersionFor = versionFor,
	-- a513 : le poids V2 est allumé sur ce serveur (table 2 et Features.WeightIncomeV2 / WeightIncomeV2Dev) ; la table 2
	-- remise à l'échelle (Tables[2] quand WeightIncomeV2 est vrai) ; le même choix pour des interrupteurs donnés (bancs).
	WeightIncomeV2 = WEIGHT_V2,
	WeightV2Table = TABLE_2_WEIGHT_V2,
	WeightV2For = weightV2For,
}

export type Economy = typeof(Economy)

return DeepFreeze(Economy)
