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
-- Le jeu DEV est reconnu ici par game.GameId = DevGameId, la règle de Config/ProductIds en « Auto » et du choix du
-- store des profils (DataService). Ce module ne peut pas lire ProductIds.IsDev : ProductIds exige Balance, et
-- Balance lit ce module (boucle de require). DevGameId est donc écrit une seconde fois ici ; le banc a486 vérifie
-- qu'il vaut Balance.Profiles.DevGameId et que Economy.IsDev suit ProductIds.IsDev.
--
-- Changer un nombre de la table 2 (taux du hors ligne, prix d'un niveau du tapis…) : une valeur ci-dessous, aucun
-- code à toucher. Ne jamais changer la table 1 : c'est l'économie des profils de PROD et le repère de la conversion.
--
-- API :
--   Economy.Version: number            1 ou 2, la table active
--   Economy.Active: Table              Economy.Tables[Economy.Version]
--   Economy.Tables: { Table }          les deux tables
--   Economy.IsDev: boolean             ce serveur est le jeu DEV
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
	-- Config/Offline.Rate : part des revenus gagnée hors ligne (1 = 100 %). Le plafond d'heures (MaxHours) reste dans
	-- Config/Offline, le même pour les deux tables.
	OfflineRate: number,
	-- Config/Balance.Profiles.DevStoreName : store des profils du jeu DEV (un nouveau nom = profils DEV remis à zéro,
	-- comme le 14/11 ; rien n'est effacé, l'autre store reste intact). Le store de PROD ne dépend jamais de la table.
	DevStoreName: string,
}

-- Table 1 : l'économie d'avant. Les mêmes nombres que ceux écrits dans chaque module de Config (banc a486).
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
	DevStoreName = "PlayerData_DEV_20261114",
}

-- Table 2 : l'économie « B/T » (note d'a479, passe 4, validée par Cantin le 25/11). Chaque nombre vient de la « Liste
-- exacte des valeurs de Config à changer » de la note ; n'en changer aucun sans elle.
local TABLE_2: Table = {
	Version = 2,
	-- Échelle régulière, × 60 par rareté ; Divine = 5 × Secret (aucun objet encore).
	Income = { Common = 1, Uncommon = 60, Rare = 3_600, Epic = 220_000, Legendary = 13_000_000, Mythic = 800_000_000, Secret = 50_000_000_000, Divine = 250_000_000_000 },
	-- × 107 environ par zone jusqu'à la zone 5 ; zone 6 à 30T (décision de Cantin : le joueur moyen y arrive en 20 h).
	SpeedRequired = { 0, 15_000, 1_600_000, 170_000_000, 19_000_000_000, 30_000_000_000_000 },
	-- Calés sur les zones 2 à 5 : la marche aux panneaux reste 22, 28, 34, 40 ; zone 6 : 49,4 (avant 46).
	WalkPerDecade = 2.95,
	SpeedScale = 140,
	TreadmillGainPerSecond = 6,
	-- 25 niveaux affichés. Découpage de Cantin : niveaux 1 à 3 en zone 1, 4 à 8 en zone 2, 9 à 12 en zone 3, 13 à 16
	-- en zone 4, 17 à 25 en zone 5, avec un grand saut à l'entrée de chaque zone (230K, 95M, 9,5B). Niveaux 19 à 25 :
	-- au moins une absence complète de 5 h du joueur moyen (la règle du hors ligne, en zone 5 seulement). Ces prix et
	-- OfflineRate vont ensemble (question ouverte L-413 : hors ligne à 50 %).
	TreadmillMaxLevel = 24,
	TreadmillCosts = { 150, 450, 590, 1_200, 2_200, 4_000, 8_100, 230_000, 450_000, 810_000, 1_400_000, 95_000_000, 200_000_000, 420_000_000, 880_000_000, 9_500_000_000, 29_000_000_000, 340_000_000_000, 690_000_000_000, 1.1e12, 1.7e12, 2.6e12, 3.9e12, 5.9e12 },
	DisplaySlotCosts = { 450, 1_200, 900, 1_800, 140_000, 230_000, 360_000, 84_000_000, 190_000_000, 380_000_000, 2_100_000_000, 5_300_000_000, 18_000_000_000, 40e9, 100e9, 250e9 },
	Floor2Cost = 140_000,
	Floor2Costs = { 230_000, 360_000, 84_000_000, 190_000_000, 380_000_000, 2_100_000_000, 5_300_000_000, 18_000_000_000 },
	-- Les puissances ne changent pas ; Wrench et Crowbar gardent leur prix (le tutoriel reste juste).
	ToolPrices = { Fists = 0, Wrench = 300, Crowbar = 3_100, Hammer = 450_000, Sledgehammer = 400_000_000, FireAxe = 36_000_000_000, AngleGrinder = 160_000_000_000 },
	CosmeticPrices = {
		Shine = 100,
		Fire = 1_800,
		Storm = 180_000,
		Poison = 450_000,
		Tornado = 400_000_000,
		Angel = 19_000_000_000,
		Demon = 74_000_000_000,
		Chained = 160_000_000_000,
		-- Anciennes auras : le prix de leur équivalente (Config/Cosmetics.Migration).
		Spark = 100,
		Flame = 1_800,
		Lightning = 450_000,
		Plasma = 400_000_000,
		Galaxy = 19_000_000_000,
		Royal = 160_000_000_000,
		Dust = 100,
		Wind = 1_300,
		Turbo = 360_000,
		Comet = 320_000_000,
		Hyperspace = 120_000_000_000,
	},
	-- Un prix garde sa valeur comptée en armes (courbe « ancien dollar → nouveau dollar », arrondie à 2 chiffres).
	SkillPrices = {
		Walls = { 1_300, 13_000, 1_000_000, 740_000_000 },
		GlassThickness = { 1_900, 17_000, 450_000, 75_000_000, 12_000_000_000 },
		GlassRegen = { 2_600, 32_000, 630_000, 75_000_000, 8_400_000_000 },
		Cameras = { 980, 6_900, 630_000 },
		Bodyguards = { 4_200, 190_000, 48_000_000, 22_000_000_000, 370_000_000_000 },
		PotionLuck = { 1_700, 23_000, 1_800_000 },
		Curtain = { 2_600, 78_000 },
		DoorGuard = { 48_000_000 },
		PotionTime = { 4_200, 190_000 },
		Traps = { 78_000, 2_900_000, 320_000_000, 36_000_000_000 },
		BoxLuck = { 8_300, 190_000, 31_000_000, 5_200_000_000, 95_000_000_000 },
		FittingRoom = { 190_000 },
		-- 1 h du revenu de référence de la zone 3, puis de la zone 5.
		OfflineTime1 = { 5_400_000 },
		OfflineTime2 = { 130_000_000_000 },
	},
	-- V0 d'attente : la renaissance est coupée avec cette table (Features.RebirthBT), à resimuler.
	RebirthCash = { 390e9, 9.7e12, 26e12, 39e12, 51e12, 63e12, 97e12, 140e12, 150e12, 180e12 },
	Zone1SpeedRequired = 60,
	LeaderboardSpeedLog = true,
	LeaderboardSuffix = "_E2",
	AdminMaxAmount = 1e30,
	-- Cantin, 25/11 : 100 %, comme la table 1, tant que Clément n'a pas répondu à L-413 (50 %).
	OfflineRate = 1,
	-- Décision de Cantin (25/11) : profils du jeu DEV remis à zéro avec cette table.
	DevStoreName = "PlayerData_DEV_BT_20261125",
}

local TABLES: { Table } = { TABLE_1, TABLE_2 }

-- « Steal a Shop [DEV] » : le même nombre que Balance.Profiles.DevGameId (voir l'en-tête).
local DEV_GAME_ID = 10774974820

local function currentGameId(): number?
	local ok, id = pcall(function(): any
		return (game :: any).GameId
	end)
	return if ok and type(id) == "number" then id else nil
end

local function isDevGame(gameId: number?): boolean
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

local Economy = {
	Version = VERSION,
	Active = TABLES[VERSION],
	Tables = TABLES,
	IsDev = isDevGame(GAME_ID),
	DevGameId = DEV_GAME_ID,
	-- Renaissance coupée avec la table 2 (décision de Cantin, 25/11 : à resimuler), sauf Features.RebirthBT.
	RebirthAllowed = VERSION ~= 2 or Features.RebirthBT == true,
	VersionFor = versionFor,
}

export type Economy = typeof(Economy)

return DeepFreeze(Economy)
