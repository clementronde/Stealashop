--!strict
-- Améliorations de base achetées sur sa parcelle (Partie 1, sections 7.5 et 7.1).
-- Coût du niveau n = C0 × g^n, où n = niveau déjà possédé (0 pour le premier
-- achat, qui coûte donc C0) : calcul dans Formulas.UpgradeCost.
-- `Id` est la clé de la sauvegarde (Upgrades, 9.5) et de BuyItem (9.4).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type UpgradeId = "Treadmill" | "Bench" | "DisplaySlots" | "UnboxBenches"

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
	-- +1 établi d'ouverture, de 1 à 4 (Balance.Unbox)
	{ Id = "UnboxBenches", DisplayName = "Workbenches", EffectPerLevel = 1, MaxLevel = 3, BaseCost = 2_000, Growth = 12 },
}

local ById: { [string]: Upgrade } = {}
for _, upgrade in List do
	ById[upgrade.Id] = upgrade
end

local Upgrades = {
	List = List,
	ById = ById,
}

export type Upgrades = typeof(Upgrades)

return DeepFreeze(Upgrades)
