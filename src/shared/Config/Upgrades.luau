--!strict
-- Améliorations de base achetées sur sa parcelle (Partie 1, sections 7.5 et 7.1).
-- Coût du niveau n = C0 × g^n, où n = niveau déjà possédé (0 pour le premier
-- achat, qui coûte donc C0) : calcul dans Formulas.UpgradeCost.
-- `Id` est la clé de la sauvegarde (Upgrades, 9.5) et de BuyItem (9.4).

local DeepFreeze = require(script.Parent.DeepFreeze)

-- a486 : table de l'économie à appliquer par-dessus les nombres de ce fichier (Config/Economy.Override : la table 2
-- quand elle est active). nil avec la table 1, ou sans le module (bancs à liste de modules fixe, comme dans
-- Config/Items) : les nombres écrits dans ce fichier, qui SONT la table 1, ne sont jamais remplacés.
local ECO: any = (function(): any
	local found, module = pcall(function(): any
		return script.Parent:FindFirstChild("Economy")
	end)
	if found and module ~= nil then
		local ok, result = pcall(require, module :: any)
		if ok and type(result) == "table" then
			return result.Override
		end
	end
	return nil
end)()

-- L-086 (2026-11-08) : plus d'établis d'ouverture, les colis s'ouvrent sur les présentoirs.
-- L'amélioration « Workbenches » (UnboxBenches) n'est plus vendue ; son niveau reste dans le profil
-- (Upgrades.UnboxBenches, Types/Profile), sans effet.
-- Rééquilibrage v2 (Cantin, 2026-11-14) : plus de banc. L'amélioration « Weight Bench » (Bench) n'est plus
-- vendue ; son niveau reste dans le profil (Upgrades.Bench), sans effet, comme UnboxBenches.
export type UpgradeId = "Treadmill" | "DisplaySlots"

export type Upgrade = {
	Id: UpgradeId,
	DisplayName: string,
	EffectPerLevel: number,
	MaxLevel: number,
	BaseCost: number, -- C0, prix du 1er niveau
	Growth: number, -- g
	-- Vague 76 (Cantin, 20/11 : prix remis à l'échelle des nouveaux revenus) : Costs[n + 1] = prix du niveau n, à la place
	-- de C0 × g^n quand la liste est là (Formulas.UpgradeCost) ; #Costs = MaxLevel.
	Costs: { number }?,
}

local List: { Upgrade } = {
	-- Tapis (v2 ; note equilibrage-v2-proposition.md, 4.2). Niveau AFFICHÉ = niveau enregistré + 1 : le joueur
	-- commence au niveau 1 (+1 Vitesse par seconde, Cantin) et 19 achats mènent au niveau 20.
	-- Gain = 2^(niveau affiché − 1) par seconde (Cantin ; Formulas.TreadmillGain, Config/Training) : EffectPerLevel
	-- ne sert plus au tapis (0). Prix du passage du niveau affiché L au suivant = 150 × 3,8^(L − 1) (V0 proposés,
	-- réglés au simulateur pour la zone 6 en 7 h 30).
	-- Vague 76 : Costs, V0 proposé (Cantin, 20/11), avant : 150 × 3,8^n (150, 570, 2 166, 8 231, 31 277, 118 853,
	-- 451 640, 1,72 M, 6,52 M, 24,8 M, 94,2 M, 358 M, 1,36 B, 5,17 B, 19,6 B, 74,6 B, 284 B, 1,08 T, 4,09 T) : chaque
	-- niveau × le facteur des revenus de la zone où le joueur moyen l'achète (simulateur), sans jamais baisser.
	{
		Id = "Treadmill",
		DisplayName = "Treadmill",
		EffectPerLevel = 0,
		MaxLevel = 19,
		BaseCost = 150,
		Growth = 3.8,
		Costs = { 150, 570, 2_200, 2_800, 3_600, 4_600, 15_000, 46_000, 140_000, 430_000, 1_300_000, 3_700_000, 14_000_000, 51_000_000, 190_000_000, 700_000_000, 2_600_000_000, 9_600_000_000, 35_000_000_000 },
	},
	-- +1 présentoir, de 4 à 20 (Balance.Display)
	-- Vague 76 : Costs, V0 proposé (Cantin, 20/11), avant : 500 × 2,5^n (500, 1 250, 3 125, 7 813, 19 531, 48 828,
	-- 122 070, 305 176, 762 939, 1,91 M, 4,77 M, 11,9 M, 29,8 M, 74,5 M, 186 M, 466 M), même règle que le tapis.
	{
		Id = "DisplaySlots",
		DisplayName = "Display Stands",
		EffectPerLevel = 1,
		MaxLevel = 16,
		BaseCost = 500,
		Growth = 2.5,
		Costs = { 500, 1_300, 1_600, 2_100, 2_800, 3_600, 4_800, 9_800, 20_000, 42_000, 72_000, 120_000, 300_000, 750_000, 1_800_000, 4_300_000 },
	},
}

-- a486 : niveaux et prix pris dans la table active de l'économie (Config/Economy). Table 2 : tapis à 24 achats (25
-- niveaux affichés, gain × 2 par niveau, 6 crédits par seconde au niveau 1), prix par zone avec un grand saut à l'entrée
-- de chaque zone (niveaux 9, 13 et 17), niveaux 19 à 25 au prix d'une absence complète ; présentoirs refaits.
if ECO ~= nil then
	for _, upgrade in List do
		if upgrade.Id == "Treadmill" then
			assert(type(ECO.TreadmillMaxLevel) == "number" and type(ECO.TreadmillCosts) == "table", "Config/Upgrades : tapis absent de Config/Economy")
			upgrade.MaxLevel = ECO.TreadmillMaxLevel
			upgrade.Costs = ECO.TreadmillCosts
		elseif upgrade.Id == "DisplaySlots" then
			assert(type(ECO.DisplaySlotCosts) == "table", "Config/Upgrades : présentoirs absents de Config/Economy")
			upgrade.Costs = ECO.DisplaySlotCosts
		end
	end
end

local ById: { [string]: Upgrade } = {}
for _, upgrade in List do
	assert(upgrade.Costs == nil or #upgrade.Costs == upgrade.MaxLevel, `Config.Upgrades : {upgrade.Id}, Costs doit avoir MaxLevel prix`)
	ById[upgrade.Id] = upgrade
end

-- Modèle du tapis de la parcelle selon le niveau de l'amélioration Treadmill (liaison L-082, L-093 point 3
-- et L-097 point 2 ; MachineVariantService). « Base » = le tapis posé par Clément dans la parcelle ; les
-- autres sont des copies de ReplicatedStorage/Assets/Plots/PLOT_Treadmill_<Variante>.
-- Ordre validé par Clément (L-097, 2026-11-11). Pour un nouveau tapis (Jungle, Pirate, Samurai…),
-- l'ajouter à la fin : il arrive TreadmillTierEvery niveaux après le précédent (au-delà de MaxLevel 20,
-- il faut monter MaxLevel ou baisser le pas).
-- Palier du niveau AFFICHÉ n (v2 : niveau enregistré + 1) = TreadmillVariants[floor(n / TreadmillTierEvery) + 1],
-- le dernier au-delà. Un palier toutes les 2 améliorations : Base au niveau 1, Silver aux niveaux 2 et 3…
-- Void au niveau 20, le dernier (note v2, 4.2). a486 : avec la table 2 de l'économie (25 niveaux), les niveaux 21 à
-- 25 gardent Void (MachineVariantService borne l'indice à la liste).
local TreadmillTierEvery = 2
local TreadmillVariants: { string } = {
	"Base",
	"Silver",
	"Gold",
	"CashRegister",
	"Police",
	"LaserVault",
	"Ice",
	"Toxic",
	"Candy",
	"Fire",
	"Void",
}

local Upgrades = {
	List = List,
	ById = ById,
	TreadmillTierEvery = TreadmillTierEvery,
	TreadmillVariants = TreadmillVariants,
}

export type Upgrades = typeof(Upgrades)

return DeepFreeze(Upgrades)
