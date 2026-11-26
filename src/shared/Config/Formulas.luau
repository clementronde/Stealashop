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
-- Vague 61 (a198, Cantin) : × Balance.Stats.RealSpeedScale, base et plafond compris (32 au départ, 140 au plus
-- à × 2) ; la Speed affichée ne change pas.
function Formulas.WalkSpeed(speed: number, trailMultiplier: number?): number
	local stats = Balance.Stats
	local shown = Formulas.ShownSpeed(speed, trailMultiplier)
	if shown ~= shown or shown < 0 then
		shown = 0
	end
	return stats.RealSpeedScale
		* math.min(stats.MaxWalkSpeed, stats.BaseWalkSpeed + stats.WalkPerDecade * math.log10(1 + shown / stats.SpeedScale))
end

-- Plafond réel de la marche (vague 61) : Balance.Stats.MaxWalkSpeed × RealSpeedScale (140 à × 2).
function Formulas.MaxWalkSpeed(): number
	return Balance.Stats.MaxWalkSpeed * Balance.Stats.RealSpeedScale
end

-- a493 (Cantin, 26/11 : « aucun $/s n'a de décimales ») : arrondi du revenu final d'un objet (mutation et poids
-- compris) et du total des plaques après le M global, à l'entier le plus proche (,5 monte), au moins 1 $/s (V0).
-- Seul arrondi des $/s : DisplayService.itemIncome, UnboxService.itemIncomeOf, StoreHeistService.revealIncome et le
-- total de DisplayService (reconcile) l'appellent ; personne ne l'applique deux fois.
function Formulas.RoundIncome(value: number): number
	return math.max(1, math.floor(value + 0.5))
end

-- Revenu d'un objet ($/s), vague 76 (Cantin et Clément, 19/11), avant mutation et poids (qui multiplient le résultat,
-- Mutations.IncomeMultiplier) :
--   Income de sa rareté (Config/Rarities)
--   × (1 + ZoneStep × zones au-dessus de la première zone où cette rareté existe, Rarities.FirstZone ; 0 au moins)
--   × (1 + RankStep)^(rang − 1), rang dans sa rareté et sa zone (Items : ordre de l'index)
--   × M global (renaissances, gamepasses, groupe, amis : 1 par défaut).
-- Ex. : Canette de soda 1 $/s ; un Peu commun de zone 3 au rang 1 : 8 × 1,25 = 10 $/s. Un Secret (sans zone) : Income
-- de sa rareté au rang 1. Objet inconnu : erreur (les appelants vérifient Items.ById avant).
function Formulas.ItemIncome(itemId: string, globalMultiplier: number?): number
	-- Config/Items chargé au premier appel seulement : Formulas reste lisible sans le catalogue (bancs).
	local Items = require(script.Parent.Items)
	local item = Items.ById[itemId]
	assert(item, `Formulas.ItemIncome : objet inconnu {itemId}`)
	local rarity = Rarities.ById[item.Rarity]
	assert(rarity, `Formulas.ItemIncome : rareté inconnue {item.Rarity}`)
	local rules = Rarities.IncomeRules
	local first = Rarities.FirstZone[item.Rarity]
	local above = if item.Zone and first then math.max(item.Zone - first, 0) else 0
	return rarity.Income * (1 + rules.ZoneStep * above) * (1 + rules.RankStep) ^ (item.Rank - 1) * (globalMultiplier or 1)
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
	if upgrade.Costs ~= nil then
		-- Vague 76 : liste de prix (Config/Upgrades, Costs), remise à l'échelle des nouveaux revenus.
		return upgrade.Costs[math.floor(currentLevel) + 1]
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
-- v2 : 50, 500, 15K, 500K, 16M, 100M (vague 68), puisque AdvisedDamage = arme × aura du kit de la zone ;
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

-- Vague 76 (Cantin et Clément, 19/11) : cote « 1 IN N » de l'ouverture d'un colis = 1 / la vraie chance d'avoir cet
-- objet avec sa mutation et sa taille sur un emplacement de rayon de sa zone (`chance`, de 0 à 1 : Shared/ItemOdds,
-- calculée par le serveur ; elle ne dépend plus de la caisse déjà trouvée). Arrondi lisible : à l'entier sous 100,
-- à 2 chiffres significatifs au-delà (12 000, 23 000 000). nil si la chance est nulle ou illisible.
function Formulas.UnboxOdds(chance: number): number?
	if type(chance) ~= "number" or not (chance > 0 and chance <= 1) then
		return nil
	end
	local n = 1 / chance
	if n < 100 then
		return math.max(math.floor(n + 0.5), 1)
	end
	local step = 10 ^ (math.floor(math.log10(n)) - 1)
	local rounded = math.floor(n / step + 0.5) * step
	return if rounded < math.huge then rounded else nil
end

export type Formulas = typeof(Formulas)

return DeepFreeze(Formulas)
