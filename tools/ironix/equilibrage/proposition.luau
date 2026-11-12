--!nocheck
-- La nouvelle échelle PROPOSÉE (liaison L-108, point 1). Rien ici n'est dans le jeu : ce sont les
-- valeurs à discuter, que le simulateur compare à l'économie actuelle (src/shared/Config).
-- Chaque table dit quel fichier de Config elle remplacerait. Tout ce qui n'est pas cité ici reste
-- comme aujourd'hui (revenus de base des zones, raretés, mutations, prix des outils, des auras et
-- des trails, présentoirs, chrono de casse, régénération, distances).
--
-- Idée : la stat affichée monte sans fin (K, M, B, T), la vitesse de marche réelle reste bornée.
--   Speed affichée    = Vitesse entraînée × M trail
--   WalkSpeed         = min(70, 16 + 4 × log10(1 + Speed affichée / 100))     (+4 de marche par ×10)
--   Strength affichée = dégâts par coup = P outil × (1 + Force entraînée) × M aura
-- Les seuils de vitesse des zones sont les Speed qui donnent les vitesses de marche conseillées
-- d'aujourd'hui (22, 28, 34, 40 ; 46 au lieu de 48 en zone 6) : la map, l'anti-triche et les animations de
-- course gardent leurs vitesses réelles.

local Proposition = {}

-- Remplacerait Balance.Stats.
Proposition.Stats = {
	BaseWalkSpeed = 16, -- inchangé
	MaxWalkSpeed = 70, -- inchangé (atteint à Speed 3.1Qa : très loin)
	WalkPerDecade = 4, -- WalkSpeed gagné chaque fois que la Speed affichée est multipliée par 10
	SpeedScale = 100, -- Speed affichée à partir de laquelle la marche commence à monter
	StrengthDivisor = 1, -- aujourd'hui 100 : dégâts = P outil × (1 + Force / 100) × M aura
}

-- Remplacerait dans Zones : AdvisedDamage, WindowHP, AdvisedSpeed, GuardSpeed, et ajouterait SpeedRequired.
-- ReturnDistance et BaseIncome ne changent pas. AdvisedSpeed (WalkSpeed) se déduit de SpeedRequired :
-- 22, 28, 34 et 40 comme aujourd'hui, 46 au lieu de 48 en zone 6 (un pas de ×30 comme les autres zones).
--   SpeedRequired   Speed affichée du panneau (donne la vitesse de marche conseillée de la zone)
--   AdvisedDamage   Strength affichée du panneau (= dégâts par coup conseillés)
--   WindowHP        = WindowHPPerDamage × AdvisedDamage (règle de la section 4, gardée)
--   GuardSpeed      = GuardCarryFactor × AdvisedSpeed + GuardMargin, arrondi à 0,1 (aujourd'hui 0,9 × … − 1) ;
--                   zone 1 gardée (13,4 : zone du tuto)
Proposition.WindowHPPerDamage = 35
Proposition.GuardCarryFactor = 0.9
Proposition.GuardMargin = 1
Proposition.Zones = {
	{ SpeedRequired = 0, AdvisedDamage = 1 },
	{ SpeedRequired = 3e3, AdvisedDamage = 5e3 },
	{ SpeedRequired = 100e3, AdvisedDamage = 1e6 },
	{ SpeedRequired = 3e6, AdvisedDamage = 100e6 },
	{ SpeedRequired = 100e6, AdvisedDamage = 10e9 },
	{ SpeedRequired = 3e9, AdvisedDamage = 1e12 },
}

-- Remplacerait la règle « 1 + 0,5 × niveau » (Formulas.MachineMultiplier, Upgrades.EffectPerLevel) et
-- les prix du tapis et du banc (Upgrades : BaseCost 200, Growth 1,9). 20 niveaux, comme aujourd'hui
-- (les 11 modèles de tapis de Clément gardent leur palier tous les 2 niveaux).
--   gain du niveau n = BaseGain × GainGrowth^n   (par seconde au tapis, par répétition au banc)
--   prix du niveau n = BaseCost × CostGrowth^n
Proposition.Machines = {
	Treadmill = { BaseGain = 4, GainGrowth = 2, BaseCost = 200, CostGrowth = 3.6 },
	Bench = { BaseGain = 6, GainGrowth = 2, BaseCost = 200, CostGrowth = 3.6 },
}

-- Remplacerait les multiplicateurs des trails (Cosmetics.Trails : 1,1 / 1,25 / 1,4 / 1,6 / 1,8).
-- Dans un log, ×1,1 ne se voit pas : mêmes paliers que les auras. Prix inchangés.
Proposition.TrailMultipliers = { 1.5, 2, 3, 5, 8 }

-- Portes des boutiques de joueurs. Base par niveau de boutique : la règle de la vague 29 est gardée
-- (PvP.PlayerWindowHPPerDamage × AdvisedDamage de la zone du même rang), sur la nouvelle échelle.
-- Arbre (Glass, Walls, Glass Regen) : inchangé dans la proposition. VarianteArbre est une option à
-- discuter : les zones sont séparées par ×100 à ×200 de dégâts au lieu de ×8 à ×10, donc une porte
-- entièrement améliorée ne tient plus face à un voleur d'une zone au-dessus ; avec ces
-- multiplicateurs plus grands (aujourd'hui Glass 1,5 / 2 / 3 / 5 / 8 et Walls 1,25 / 1,5 / 2 / 3),
-- elle tient de nouveau.
Proposition.PlayerWindowHPPerDamage = 50
Proposition.VarianteArbre = {
	Glass = { 2, 4, 10, 25, 60 },
	Walls = { 1.5, 2.5, 5, 10 },
}

-- La même économie que Modele.EcoActuelle(), avec les valeurs ci-dessus.
function Proposition.Construire()
	local Zones = Config.Zones
	local Tools = Config.Tools
	local Cosmetics = Config.Cosmetics
	local Upgrades = Config.Upgrades
	local Rarities = Config.Rarities
	local SkillTree = Config.SkillTree
	local Formulas = Config.Formulas
	local stats = Proposition.Stats

	local eco = { Nom = "Proposée" }

	function eco.WalkSpeed(speed, trailMultiplier)
		local shown = speed * (trailMultiplier or 1)
		return math.min(stats.MaxWalkSpeed, stats.BaseWalkSpeed + stats.WalkPerDecade * math.log10(1 + shown / stats.SpeedScale))
	end
	function eco.HitDamage(toolPower, strength, auraMultiplier)
		return toolPower * (1 + strength / stats.StrengthDivisor) * (auraMultiplier or 1)
	end
	function eco.ShownSpeed(speed, trailMultiplier)
		return speed * (trailMultiplier or 1)
	end
	eco.ShownStrength = eco.HitDamage

	eco.Zones = {}
	for index, zone in Zones do
		local proposed = Proposition.Zones[index]
		eco.Zones[index] = {
			WindowHP = Proposition.WindowHPPerDamage * proposed.AdvisedDamage,
			AdvisedDamage = proposed.AdvisedDamage,
			-- vitesse de marche que donne le seuil rond (21,97 pour 3K : à 0,03 près celle d'aujourd'hui)
			AdvisedSpeed = eco.WalkSpeed(proposed.SpeedRequired, 1),
			GuardSpeed = if index == 1 then zone.GuardSpeed else math.round((Proposition.GuardCarryFactor * eco.WalkSpeed(proposed.SpeedRequired, 1) + Proposition.GuardMargin) * 10) / 10,
			ReturnDistance = zone.ReturnDistance,
			BaseIncome = zone.BaseIncome,
			SpeedShown = proposed.SpeedRequired,
			StrengthShown = proposed.AdvisedDamage,
		}
	end

	function eco.MachineGain(kind, level)
		local machine = Proposition.Machines[kind]
		return machine.BaseGain * machine.GainGrowth ^ level
	end
	function eco.UpgradeCost(upgradeId, level)
		local machine = Proposition.Machines[upgradeId]
		if machine == nil then
			return Formulas.UpgradeCost(upgradeId, level) -- présentoirs : inchangés
		end
		if level >= Upgrades.ById[upgradeId].MaxLevel then
			return nil
		end
		return math.round(machine.BaseCost * machine.CostGrowth ^ level)
	end
	function eco.ItemIncome(zone, rarityId)
		return eco.Zones[zone].BaseIncome * Rarities.ById[rarityId].IncomeMultiplier
	end

	eco.Tools = Tools.List
	eco.Auras = Cosmetics.Auras
	eco.Trails = {}
	for index, trail in Cosmetics.Trails do
		local copy = table.clone(trail)
		copy.Multiplier = Proposition.TrailMultipliers[index]
		eco.Trails[index] = copy
	end

	function eco.DoorHP(stageLevel)
		local level = math.clamp(math.floor(stageLevel), 1, #eco.Zones)
		return Proposition.PlayerWindowHPPerDamage * eco.Zones[level].AdvisedDamage
	end
	eco.Glass = SkillTree.ById.GlassThickness.Effects
	eco.Walls = SkillTree.ById.Walls.Effects
	eco.Regen = SkillTree.ById.GlassRegen.Effects
	return eco
end

return Proposition
