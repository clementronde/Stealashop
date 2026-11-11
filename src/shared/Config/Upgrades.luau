--!strict
-- Améliorations de base achetées sur sa parcelle (Partie 1, sections 7.5 et 7.1).
-- Coût du niveau n = C0 × g^n, où n = niveau déjà possédé (0 pour le premier
-- achat, qui coûte donc C0) : calcul dans Formulas.UpgradeCost.
-- `Id` est la clé de la sauvegarde (Upgrades, 9.5) et de BuyItem (9.4).

local DeepFreeze = require(script.Parent.DeepFreeze)

-- L-086 (2026-11-08) : plus d'établis d'ouverture, les colis s'ouvrent sur les présentoirs.
-- L'amélioration « Workbenches » (UnboxBenches) n'est plus vendue ; son niveau reste dans le profil
-- (Upgrades.UnboxBenches, Types/Profile), sans effet.
export type UpgradeId = "Treadmill" | "Bench" | "DisplaySlots"

export type Upgrade = {
	Id: UpgradeId,
	DisplayName: string,
	EffectPerLevel: number,
	MaxLevel: number,
	BaseCost: number, -- C0, prix du 1er niveau
	Growth: number, -- g
}

local List: { Upgrade } = {
	-- +0,5 au multiplicateur de gain de vitesse du tapis
	{ Id = "Treadmill", DisplayName = "Treadmill", EffectPerLevel = 0.5, MaxLevel = 20, BaseCost = 200, Growth = 1.9 },
	-- +0,5 au multiplicateur de gain de force du banc
	{ Id = "Bench", DisplayName = "Weight Bench", EffectPerLevel = 0.5, MaxLevel = 20, BaseCost = 200, Growth = 1.9 },
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
-- Palier du niveau n = TreadmillVariants[floor(n / TreadmillTierEvery) + 1], le dernier au-delà.
-- V0 proposé, absent du doc : un palier toutes les 2 améliorations (Base aux niveaux 0 et 1, Silver au
-- niveau 2… Void au niveau 20, MaxLevel du tapis).
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
