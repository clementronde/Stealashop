--!nocheck
-- Rééquilibrage v2 (décisions de Cantin du 2026-11-14) : tout est recalculé à partir de zéro. Rien ici
-- n'est dans le jeu : ce sont des valeurs « V0 proposé », à valider par Cantin et Clément. Note :
-- docs/claude/notes/equilibrage-v2-proposition.md. Lancer : RAPPORT=v2 bash tools/ironix/equilibrage/run.sh
--
-- Décisions de départ (Cantin) :
--   1. Tapis : niveau 1 = +1 de vitesse par seconde, ×2 à chaque niveau, jusqu'au niveau 20 (2^19 par seconde).
--   2. Plus de banc. Dégâts d'un coup = dégâts de l'arme × multiplicateur de l'aura (× potion).
--   3. Potion de force : ×1,5. Elle n'entre dans AUCUN calcul de seuil ni de PV (précision de Cantin).
--   4. Zone 6 en 7 h 30 de jeu actif pour le joueur moyen.
--   5. Zone 6 jamais cassable seul : PV = ce que font DEUX des meilleurs joueurs possibles (meilleure arme ×
--      meilleure aura, 10 coups/s, sans potion) pendant le chrono de casse de 13 s. Seul avec la potion,
--      on reste dessous (1,5 < 2).
--
-- Formules :
--   Speed affichée    = Vitesse entraînée × M trail
--   WalkSpeed         = min(70, 16 + 4 × log10(1 + Speed affichée / 100))      (+4 de marche par ×10 de Speed)
--   Strength affichée = dégâts d'un coup = P arme × M aura
--   Gain du tapis     = 2^(niveau − 1) par seconde, niveau de 1 à 20 (× 1,5 avec les taps)
--   Prix du passage du niveau L au niveau L + 1 = BaseCost × CostGrowth^(L − 1)

local V2 = {}

-- Remplacerait Balance.Stats (StrengthDivisor et SpeedToWalkSpeed disparaissent).
V2.Stats = {
	BaseWalkSpeed = 16, -- inchangé
	MaxWalkSpeed = 70, -- inchangé : plus qu'une sécurité (Speed 3,2Qa)
	WalkPerDecade = 4, -- WalkSpeed gagné chaque fois que la Speed affichée est multipliée par 10
	SpeedScale = 100, -- Speed affichée à partir de laquelle la marche commence à monter
}

-- Remplacerait Upgrades.Treadmill et Training.Treadmill.GainPerSecond (l'amélioration Bench disparaît).
-- Le joueur commence au niveau 1 ; 19 achats mènent au niveau 20.
V2.Treadmill = {
	BaseGain = 1, -- décision de Cantin
	GainGrowth = 2, -- décision de Cantin
	MaxLevel = 20, -- décision de Cantin (Upgrades.MaxLevel)
	BaseCost = 150, -- V0 proposé : prix du passage au niveau 2 (réglé au simulateur)
	CostGrowth = 3.8, -- V0 proposé : réglé au simulateur pour la zone 6 en 7 h 30 (joueur moyen)
}

-- Remplacerait Tools.List (Power, Price, TargetZones). Zone = zone dont l'outil fait partie du kit d'entrée.
V2.Tools = {
	{ Id = "Fists", Power = 1, Price = 0, Zones = { 1, 1 } },
	{ Id = "Wrench", Power = 5, Price = 300, Zones = { 2, 2 } },
	{ Id = "Crowbar", Power = 40, Price = 40_000, Zones = { 3, 3 } },
	{ Id = "Hammer", Power = 300, Price = 1_000_000, Zones = { 4, 4 } },
	{ Id = "Sledgehammer", Power = 2_500, Price = 20_000_000, Zones = { 5, 5 } },
	{ Id = "FireAxe", Power = 20_000, Price = 250_000_000, Zones = { 5, 5 } }, -- palier du milieu de la zone 5
	{ Id = "AngleGrinder", Power = 100_000, Price = 5_000_000_000, Zones = { 6, 6 } },
}

-- Remplacerait Cosmetics.Auras (Multiplier, Price, TargetZones) : l'aura est le multiplicateur de force.
V2.Auras = {
	{ Id = "Spark", Multiplier = 2, Price = 500, Zones = { 2, 2 } },
	{ Id = "Flame", Multiplier = 3, Price = 60_000, Zones = { 3, 3 } },
	{ Id = "Lightning", Multiplier = 5, Price = 1_500_000, Zones = { 4, 4 } },
	{ Id = "Plasma", Multiplier = 8, Price = 30_000_000, Zones = { 5, 5 } },
	{ Id = "Galaxy", Multiplier = 12, Price = 400_000_000, Zones = { 5, 5 } }, -- palier du milieu de la zone 5
	{ Id = "Royal", Multiplier = 20, Price = 8_000_000_000, Zones = { 6, 6 } },
}

-- Remplacerait Cosmetics.Trails : le trail multiplie la Speed affichée (mêmes paliers que les auras).
V2.Trails = {
	{ Id = "Dust", Multiplier = 2, Price = 300, Zones = { 2, 2 } },
	{ Id = "Wind", Multiplier = 3, Price = 40_000, Zones = { 3, 3 } },
	{ Id = "Turbo", Multiplier = 5, Price = 1_000_000, Zones = { 4, 4 } },
	{ Id = "Comet", Multiplier = 8, Price = 20_000_000, Zones = { 5, 5 } },
	{ Id = "Hyperspace", Multiplier = 12, Price = 2_500_000_000, Zones = { 6, 6 } },
}

-- Remplacerait dans Zones : AdvisedDamage, WindowHP, AdvisedSpeed, GuardSpeed, BaseIncome ; ajouterait SpeedRequired.
--   SpeedRequired   Speed affichée du panneau (donne la vitesse de marche conseillée : 22, 28, 34, 40, 46)
--   AdvisedDamage   Strength du panneau = arme du kit × aura du kit (Kit)
--   WindowHP        zones 1 à 5 : WindowHPPerDamage × AdvisedDamage ; zone 6 : Zone6HPPerDamage × AdvisedDamage
--   GuardSpeed      GuardCarryFactor × AdvisedSpeed + GuardMargin (zone 1 gardée : 13,4, zone du tuto)
V2.Zones = {
	{ SpeedRequired = 0, Kit = { "Fists" }, BaseIncome = 1 },
	{ SpeedRequired = 3e3, Kit = { "Wrench", "Spark" }, BaseIncome = 8 },
	{ SpeedRequired = 100e3, Kit = { "Crowbar", "Flame" }, BaseIncome = 60 },
	{ SpeedRequired = 3e6, Kit = { "Hammer", "Lightning" }, BaseIncome = 450 },
	{ SpeedRequired = 100e6, Kit = { "Sledgehammer", "Plasma" }, BaseIncome = 3_500 },
	{ SpeedRequired = 3e9, Kit = { "AngleGrinder", "Royal" }, BaseIncome = 25_000 },
}
V2.WindowHPPerDamage = 35 -- zones 1 à 5 : casse en 7 s à 6 coups/s, 12 s à 4 coups/s (chrono : 13 s)
V2.GuardCarryFactor = 0.9 -- = Balance.Carry.NPCBoxSpeedMultiplier (vitesse du porteur d'un colis)
V2.GuardMargin = 1 -- au seuil du panneau, le vigile reprend 1 stud par seconde au porteur (aujourd'hui − 1)

-- Zone 6, jamais seul (règle de Cantin). D = meilleure arme × meilleure aura, sans potion.
--   PV maximum = Players × HitsPerSecond × D × BreakTimer / (1 + Regen × BreakTimer)
--              = 2 × 10 × D × 13 / (1 + 0,03 × 13) = 187,05 × D    (260 × D sans la régénération de 3 %/s)
--   Marge : à 187 × D il faudrait deux joueurs à 10 coups/s parfaits pendant 13 s. Valeur choisie :
--   Zone6HPPerDamage = 160 (0,855 × le maximum) : deux joueurs à 8,6 coups/s chacun y arrivent.
--   Seul avec la potion ×1,5 à 10 coups/s : casse au plus 1,5 × 10 × 13 / 1,39 = 140,3 × D < 160 × D.
V2.Zone6 = { Players = 2, HitsPerSecond = 10, HPPerDamage = 160 }

V2.PotionStrength = 1.5 -- Potions.Strength.Multiplier (aujourd'hui 2)
V2.PlayerWindowHPPerDamage = 50 -- PvP : inchangé (porte = 50 × dégâts conseillés de la zone du rang de la boutique)

-- Hypothèse du simulateur (pas une valeur du jeu) : coups par seconde de l'équipe qui casse la zone 6
-- avec le joueur simulé, tous à son niveau (2 joueurs à 9, ou 3 à 6).
V2.TeamHits = 18

local function byId(list)
	local map = {}
	for index, entry in list do
		map[entry.Id] = index
	end
	return map
end

-- La même forme d'économie que Modele.EcoActuelle(), avec les valeurs ci-dessus.
function V2.Construire()
	local Zones = Config.Zones
	local Tools = Config.Tools
	local Cosmetics = Config.Cosmetics
	local Rarities = Config.Rarities
	local SkillTree = Config.SkillTree
	local Formulas = Config.Formulas
	local Balance = Config.Balance
	local stats = V2.Stats

	local eco = { Nom = "V2", SansBanc = true }

	function eco.WalkSpeed(speed, trailMultiplier)
		local shown = speed * (trailMultiplier or 1)
		return math.min(stats.MaxWalkSpeed, stats.BaseWalkSpeed + stats.WalkPerDecade * math.log10(1 + shown / stats.SpeedScale))
	end
	function eco.HitDamage(toolPower, _strength, auraMultiplier)
		return toolPower * (auraMultiplier or 1)
	end
	function eco.ShownSpeed(speed, trailMultiplier)
		return speed * (trailMultiplier or 1)
	end
	eco.ShownStrength = eco.HitDamage

	local function family(source, values, field)
		local list = {}
		for index, value in values do
			local copy = table.clone(source[index])
			assert(copy.Id == value.Id, `proposition_v2 : {value.Id} n'est pas à sa place`)
			copy[field] = value[field]
			copy.Price = value.Price
			copy.TargetZones = value.Zones
			list[index] = copy
		end
		return list
	end
	eco.Tools = family(Tools.List, V2.Tools, "Power")
	eco.Auras = family(Cosmetics.Auras, V2.Auras, "Multiplier")
	eco.Trails = family(Cosmetics.Trails, V2.Trails, "Multiplier")
	local toolIndex, auraIndex = byId(eco.Tools), byId(eco.Auras)

	eco.BestDamage = eco.Tools[#eco.Tools].Power * eco.Auras[#eco.Auras].Multiplier
	eco.Zones = {}
	for index, zone in Zones do
		local proposed = V2.Zones[index]
		local damage = eco.Tools[toolIndex[proposed.Kit[1]]].Power * (if proposed.Kit[2] then eco.Auras[auraIndex[proposed.Kit[2]]].Multiplier else 1)
		local last = index == #Zones
		local walk = eco.WalkSpeed(proposed.SpeedRequired, 1)
		eco.Zones[index] = {
			WindowHP = (if last then V2.Zone6.HPPerDamage else V2.WindowHPPerDamage) * damage,
			AdvisedDamage = damage,
			AdvisedSpeed = walk,
			GuardSpeed = if index == 1 then zone.GuardSpeed else math.round((V2.GuardCarryFactor * walk + V2.GuardMargin) * 10) / 10,
			ReturnDistance = zone.ReturnDistance,
			BaseIncome = proposed.BaseIncome,
			SpeedShown = proposed.SpeedRequired,
			StrengthShown = damage,
			TeamHits = if last then V2.TeamHits else nil,
		}
	end
	assert(eco.Zones[#Zones].AdvisedDamage == eco.BestDamage, "proposition_v2 : le kit de la zone 6 doit être le meilleur kit")

	-- Niveau du simulateur n = niveau affiché − 1 (0 à 19).
	function eco.MachineGain(_kind, level)
		return V2.Treadmill.BaseGain * V2.Treadmill.GainGrowth ^ level
	end
	function eco.UpgradeCost(upgradeId, level)
		if upgradeId ~= "Treadmill" then
			return Formulas.UpgradeCost(upgradeId, level) -- présentoirs : inchangés
		end
		if level >= V2.Treadmill.MaxLevel - 1 then
			return nil
		end
		return math.round(V2.Treadmill.BaseCost * V2.Treadmill.CostGrowth ^ level)
	end
	function eco.ItemIncome(zone, rarityId)
		return eco.Zones[zone].BaseIncome * Rarities.ById[rarityId].IncomeMultiplier
	end

	function eco.DoorHP(stageLevel)
		local level = math.clamp(math.floor(stageLevel), 1, #eco.Zones)
		return V2.PlayerWindowHPPerDamage * eco.Zones[level].AdvisedDamage
	end
	eco.Glass = SkillTree.ById.GlassThickness.Effects
	eco.Walls = SkillTree.ById.Walls.Effects
	eco.Regen = SkillTree.ById.GlassRegen.Effects

	-- Bornes de la zone 6 (pour le rapport).
	local T, r = Balance.Window.BreakTimer, Balance.Window.RegenPerSecond
	local perHit = T / (1 + r * T) -- PV cassables en 13 s par coup/s et par point de dégâts : 9,353
	eco.Zone6 = {
		PerHit = perHit,
		Upper = V2.Zone6.Players * V2.Zone6.HitsPerSecond * perHit, -- × D : 187,05
		UpperNoRegen = V2.Zone6.Players * V2.Zone6.HitsPerSecond * T, -- × D : 260
		Lower = V2.PotionStrength * V2.Zone6.HitsPerSecond * perHit, -- × D : 140,3 (seul, potion)
		Chosen = V2.Zone6.HPPerDamage,
	}
	return eco
end

return V2
