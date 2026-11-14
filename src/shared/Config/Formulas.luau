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

-- Rééquilibrage v2 (Cantin, 2026-11-14) : plus de banc ni de Force.
-- Dégâts par coup = P arme × M aura (c'est la « Strength » affichée). Sans aura équipée, M aura = 1.
-- Exemple zone 3 : Crowbar 40 × Flame ×3 = 120. La potion de force (×1,5) s'applique en plus, au coup
-- seulement (WindowService.GetHitDamageMultiplier) : elle n'entre dans aucun seuil ni aucun PV.
function Formulas.HitDamage(toolPower: number, auraMultiplier: number?): number
	return toolPower * (auraMultiplier or 1)
end

-- Speed affichée (HUD, panneaux) = Vitesse entraînée × M trail. Sans trail équipé, M trail = 1.
function Formulas.ShownSpeed(speed: number, trailMultiplier: number?): number
	return speed * (trailMultiplier or 1)
end

-- WalkSpeed = min(70, 16 + 4 × log10(1 + Speed affichée / 100)) : chaque fois que la Speed affichée est
-- multipliée par 10, la marche gagne 4 (v2). Une Vitesse négative ou illisible compte pour 0.
-- Le malus de portage et l'Adrénaline ne sont pas inclus (voir Balance.Carry et PvP).
function Formulas.WalkSpeed(speed: number, trailMultiplier: number?): number
	local stats = Balance.Stats
	local shown = Formulas.ShownSpeed(speed, trailMultiplier)
	if shown ~= shown or shown < 0 then
		shown = 0
	end
	return math.min(stats.MaxWalkSpeed, stats.BaseWalkSpeed + stats.WalkPerDecade * math.log10(1 + shown / stats.SpeedScale))
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

-- Niveau affiché du tapis (1 à 20) = niveau enregistré de l'amélioration Treadmill (0 à 19, borné) + 1.
function Formulas.TreadmillShownLevel(level: number): number
	local stored = if level == level then math.clamp(math.floor(level), 0, Upgrades.ById.Treadmill.MaxLevel) else 0
	return stored + 1
end

-- Gain de Vitesse du tapis par seconde = 1 × 2^(niveau affiché − 1), sans les taps ni les bonus (v2, Cantin) :
-- 1 au niveau enregistré 0, 2 au suivant… 524 288 au niveau enregistré 19 (niveau affiché 20).
function Formulas.TreadmillGain(level: number): number
	local settings = Training.Treadmill
	return settings.GainPerSecond * settings.GainGrowth ^ (Formulas.TreadmillShownLevel(level) - 1)
end

-- PV de base de la vitrine (porte) d'un joueur, selon le niveau de sa boutique (StageLevel, 1 à 6 ; borné,
-- v2 : 50, 500, 6K, 75K, 1M, 100M, puisque AdvisedDamage = arme × aura du kit de la zone ;
-- un niveau illisible compte pour 1) : 50 × les dégâts conseillés de la zone du même rang (vague 29, V0
-- proposé, absent du doc ; voir Config/PvP). L'arbre (Glass, Walls) multiplie ce nombre (WindowService).
function Formulas.PlayerWindowHP(stageLevel: number): number
	local level = if stageLevel == stageLevel then math.clamp(math.floor(stageLevel), 1, #Zones) else 1
	return PvP.PlayerWindowHPPerDamage * Zones[level].AdvisedDamage
end

-- Prix de rachat d'un objet par le receleur = 120 × son $/s (5.8).
function Formulas.FenceValue(income: number): number
	return Balance.Display.FenceIncomeMultiplier * income
end

export type Formulas = typeof(Formulas)

return DeepFreeze(Formulas)
