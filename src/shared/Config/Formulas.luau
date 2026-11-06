--!strict
-- Formules d'économie (Partie 1, section 7.1), en fonctions pures : elles ne lisent
-- que leurs arguments et les constantes gelées de Config. Le serveur les appelle
-- pour tout ce qui touche à l'argent, aux PV et aux stats ; le client seulement
-- pour afficher.

local DeepFreeze = require(script.Parent.DeepFreeze)
local Balance = require(script.Parent.Balance)
local Zones = require(script.Parent.Zones)
local Rarities = require(script.Parent.Rarities)
local Upgrades = require(script.Parent.Upgrades)
local Training = require(script.Parent.Training)
local PvP = require(script.Parent.PvP)

local Formulas = {}

-- Dégâts par coup = P outil × (1 + Force / 100) × M aura.
-- Sans aura équipée, M aura = 1. Exemple zone 3 : Marteau 20, Force 100, Flamme ×2 = 80.
function Formulas.HitDamage(toolPower: number, strength: number, auraMultiplier: number?): number
	return toolPower * (1 + strength / Balance.Stats.StrengthDivisor) * (auraMultiplier or 1)
end

-- WalkSpeed = min(70, 16 + 0,05 × Vitesse × M trail). Sans trail équipé, M trail = 1.
-- Le malus de portage et l'Adrénaline ne sont pas inclus (voir Balance.Carry et PvP).
function Formulas.WalkSpeed(speed: number, trailMultiplier: number?): number
	local stats = Balance.Stats
	return math.min(stats.MaxWalkSpeed, stats.BaseWalkSpeed + stats.SpeedToWalkSpeed * speed * (trailMultiplier or 1))
end

-- Revenu d'un objet ($/s) = R zone × M rareté × M global.
-- M global (renaissances, gamepasses, groupe, amis) arrive en Partie 2 : 1 par défaut.
function Formulas.ItemIncome(zone: number, rarityId: string, globalMultiplier: number?): number
	local zoneInfo = Zones[zone]
	assert(zoneInfo, `Formulas.ItemIncome : zone inconnue {zone}`)
	local rarity = Rarities.ById[rarityId]
	assert(rarity, `Formulas.ItemIncome : rareté inconnue {rarityId}`)
	return zoneInfo.BaseIncome * rarity.IncomeMultiplier * (globalMultiplier or 1)
end

-- Coût du niveau n = C0 × g^n, avec n = niveau déjà possédé (0 pour le premier achat,
-- qui coûte C0 comme l'indique la colonne « C0 (1er niveau) » de 7.5).
-- Renvoie nil quand le niveau maximal est atteint.
-- Arrondi au dollar le plus proche : V0 proposé, absent du doc (g^n n'est pas entier).
function Formulas.UpgradeCost(upgradeId: string, currentLevel: number): number?
	local upgrade = Upgrades.ById[upgradeId]
	assert(upgrade, `Formulas.UpgradeCost : amélioration inconnue {upgradeId}`)
	if currentLevel >= upgrade.MaxLevel then
		return nil
	end
	return math.round(upgrade.BaseCost * upgrade.Growth ^ currentLevel)
end

-- Multiplicateur de gain du tapis ou du banc = 1 + 0,5 × niveau de son amélioration (5.1, 7.5).
function Formulas.MachineMultiplier(upgradeId: "Treadmill" | "Bench", level: number): number
	return Training.BaseMultiplier + Upgrades.ById[upgradeId].EffectPerLevel * level
end

-- PV de la vitrine d'un joueur = 50 × les dégâts par coup de son propriétaire (6).
function Formulas.PlayerWindowHP(ownerDamage: number): number
	return PvP.PlayerWindowHPPerDamage * ownerDamage
end

-- Prix de rachat d'un objet par le receleur = 120 × son $/s (5.8).
function Formulas.FenceValue(income: number): number
	return Balance.Display.FenceIncomeMultiplier * income
end

export type Formulas = typeof(Formulas)

return DeepFreeze(Formulas)
