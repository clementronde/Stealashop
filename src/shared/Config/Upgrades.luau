--!strict
-- Améliorations de base achetées sur sa parcelle (Partie 1, sections 7.5 et 7.1).
-- Coût du niveau n = C0 × g^n, où n = niveau déjà possédé (0 pour le premier
-- achat, qui coûte donc C0) : calcul dans Formulas.UpgradeCost.
-- `Id` est la clé de la sauvegarde (Upgrades, 9.5) et de BuyItem (9.4).

local DeepFreeze = require(script.Parent.DeepFreeze)

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
}

local List: { Upgrade } = {
	-- Tapis (v2 ; note equilibrage-v2-proposition.md, 4.2). Niveau AFFICHÉ = niveau enregistré + 1 : le joueur
	-- commence au niveau 1 (+1 Vitesse par seconde, Cantin) et 19 achats mènent au niveau 20.
	-- Gain = 2^(niveau affiché − 1) par seconde (Cantin ; Formulas.TreadmillGain, Config/Training) : EffectPerLevel
	-- ne sert plus au tapis (0). Prix du passage du niveau affiché L au suivant = 150 × 3,8^(L − 1) (V0 proposés,
	-- réglés au simulateur pour la zone 6 en 7 h 30).
	{ Id = "Treadmill", DisplayName = "Treadmill", EffectPerLevel = 0, MaxLevel = 19, BaseCost = 150, Growth = 3.8 },
	-- +1 présentoir, de 4 à 20 (Balance.Display)
	{ Id = "DisplaySlots", DisplayName = "Display Stands", EffectPerLevel = 1, MaxLevel = 16, BaseCost = 500, Growth = 2.5 },
}

local ById: { [string]: Upgrade } = {}
for _, upgrade in List do
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
-- Void au niveau 20, le dernier (note v2, 4.2).
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
