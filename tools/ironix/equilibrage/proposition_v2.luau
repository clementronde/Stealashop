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
-- Passe 3 (Cantin, 14/11) : le chrono de casse (police) passe de 13 s à 8 s. Coups plafonnés à 5 par seconde
-- pour tout le monde ; zones 1 à 5, un joueur seul au niveau du panneau casse en 6,5 s ; chrono du braquage
-- après la casse : 6 s (Balance.Heist.Duration : 10).
--   PV / dégâts = BreakSeconds × MaxHitsPerSecond / (1 + Regen × BreakSeconds) = 6,5 × 5 / 1,195 = 27,197
--   (passe 2 : 41,35, soit 11 s ; passe 1 : 35). Sous 4,22 coups/s, un joueur au panneau ne casse plus dans les 8 s.
V2.MaxHitsPerSecond = 5 -- Balance.Hit.MaxHitsPerSecond (aujourd'hui 10)
V2.BreakTimer = 8 -- Balance.Window.BreakTimer (aujourd'hui 13)
V2.BreakSeconds = 6.5
V2.HeistDuration = 6
V2.WindowHPPerDamage = V2.BreakSeconds * V2.MaxHitsPerSecond / (1 + 0.03 * V2.BreakSeconds)
V2.GuardCarryFactor = 0.9 -- = Balance.Carry.NPCBoxSpeedMultiplier (vitesse du porteur d'un colis)
V2.GuardMargin = 1 -- au seuil du panneau, le vigile reprend 1 stud par seconde au porteur (aujourd'hui − 1)

-- Zone 6 (passe 3) : un joueur seul ne casse pas dans les 8 s, même avec la potion ×1,5 ; deux sans potion oui.
-- D = meilleure arme × meilleure aura. PV cassables en 8 s = 6,452 × coups/s × dégâts (8 / (1 + 0,03 × 8)),
-- 5 coups/s par joueur : seul sans potion 32,3 × D ; seul avec la potion : 48,4 × D ; deux sans potion : 64,5 × D.
-- Les PV doivent donc être au-dessus de 48,4 × D et au plus à 64,5 × D.
-- Valeur choisie : 2 × la règle des zones 1 à 5 = 54,39 × D : deux joueurs au panneau cassent en 6,5 s, comme un
-- joueur seul dans les autres zones ; seul avec la potion : 9,3 s, raté. (Passe 2 : 82,7 × D ; passe 1 : 160 × D.)
V2.Zone6 = { Players = 2, HitsPerSecond = V2.MaxHitsPerSecond, HPPerDamage = 2 * V2.WindowHPPerDamage }

V2.PotionStrength = 1.5 -- Potions.Strength.Multiplier (aujourd'hui 2)
V2.PlayerWindowHPPerDamage = 50 -- PvP : inchangé (porte = 50 × dégâts conseillés de la zone du rang de la boutique)

-- Hypothèse du simulateur (pas une valeur du jeu) : coups par seconde de l'équipe qui casse la zone 6
-- avec le joueur simulé, tous à son niveau (2 joueurs au plafond de 5).
V2.TeamHits = 2 * V2.MaxHitsPerSecond

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

	local eco = { Nom = "V2", SansBanc = true, MaxHits = V2.MaxHitsPerSecond, HeistDuration = V2.HeistDuration }
	-- Tous les profils frappent au plafond et acceptent la casse du panneau (11 s) ; marge jusqu'à 12 s.
	eco.CasseMax = V2.BreakSeconds + 1
	eco.BreakTimer = V2.BreakTimer

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
			WindowHP = math.round((if last then V2.Zone6.HPPerDamage else V2.WindowHPPerDamage) * damage),
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
	local T, r = V2.BreakTimer, Balance.Window.RegenPerSecond
	local perHit = T / (1 + r * T) -- PV cassables dans le chrono par coup/s et par point de dégâts : 6,452
	eco.Zone6 = {
		PerHit = perHit,
		Upper = V2.Zone6.Players * V2.Zone6.HitsPerSecond * perHit, -- × D : 93,5 (deux, sans potion)
		UpperNoRegen = V2.Zone6.Players * V2.Zone6.HitsPerSecond * T, -- × D : 130
		LowerNoPotion = V2.Zone6.HitsPerSecond * perHit, -- × D : 46,8 (seul, sans potion)
		Lower = V2.PotionStrength * V2.Zone6.HitsPerSecond * perHit, -- × D : 70,1 (seul, potion)
		Chosen = V2.Zone6.HPPerDamage,
	}
	return eco
end

return V2
