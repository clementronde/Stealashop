--!nocheck
-- Économie « B/T » (a479, 25/11, demande de Cantin : un jeu beaucoup plus long, des nombres beaucoup plus grands).
-- Rien ici n'est dans le jeu : ce sont des V0 proposés, à relire par Cantin avant de toucher src. Note :
-- a479-economie-BT.md (dossier des notes de session). Lancer : bash tools/ironix/equilibrage/bt.sh
--
-- Trois nombres de départ (demande de Cantin, valeurs choisies par a479), le reste en découle :
--   1. le meilleur objet (le Secret, sans mutation, 10 kg) rapporte 50B $/s ;
--   2. la zone 6 demande une Speed de 4T ;
--   3. le tapis crédite 6 fois par seconde (au lieu d'une) : niveau 1 = 6 de Speed par seconde.
--
-- Règle des prix : prix = revenu de référence de la zone où on l'achète × un nombre de minutes, arrondi à
-- 2 chiffres. Le revenu de référence (BT.Reference) est ce que gagne le joueur moyen du simulateur au milieu
-- de la zone ; le rapport le compare à ce que le simulateur mesure.

local BT = {}

-- Les valeurs proposées sont toutes dans Outil/valeurs_bt (un seul fichier à relire et à régler).
for key, value in charge("Outil/valeurs_bt") do
	BT[key] = value
end
-- Marche (Config/Balance.Stats) : les Speed des panneaux sont en suite géométrique (× q par zone) ; pour garder les
-- vitesses de marche d'aujourd'hui aux panneaux (22, 28, 34, 40, 46 à l'échelle 1, soit + 6 par zone) :
--   WalkPerDecade = 6 / log10(q), SpeedScale = Speed de la zone 2 / (q − 1).
-- `last` (6 par défaut) : dernière zone de la suite régulière ; 5 quand la zone 6 est fixée à part (essai des niveaux 21 à 25).
local function statsOf(speeds, last)
	last = last or 6
	local q = (speeds[last] / speeds[2]) ^ (1 / (last - 2))
	return { WalkPerDecade = 6 / math.log10(q), SpeedScale = speeds[2] / (q - 1), Ratio = q }
end
BT.Stats = statsOf(BT.SpeedRequired, BT.StatsLast)
BT.StatsOf = statsOf

local function round2(value)
	if value <= 0 then
		return 0
	end
	local step = 10 ^ (math.floor(math.log10(value)) - 1)
	return math.floor(value / step + 0.5) * step
end
BT.Round2 = round2

local function price(zone, minutes)
	return round2(BT.Reference[zone] * minutes * 60)
end
BT.Price = price

-- Parts de l'ancienne table de chance, et tables d'essai (rapport, section « chance de la boîte »).
BT.LuckTables = {
	{ Id = "Actuelle", Table = nil }, -- ShelfOpen.LuckTable telle quelle
	{
		Id = "Plus plate",
		Table = { { Luck = 1, Weight = 40 }, { Luck = 1.5, Weight = 24 }, { Luck = 2, Weight = 16 }, { Luck = 3, Weight = 10 }, { Luck = 5, Weight = 6 }, { Luck = 8, Weight = 3 }, { Luck = 10, Weight = 1 } },
	},
	{
		Id = "Plus sèche",
		Table = { { Luck = 1, Weight = 70 }, { Luck = 1.5, Weight = 15 }, { Luck = 2, Weight = 8 }, { Luck = 3, Weight = 4 }, { Luck = 5, Weight = 2 }, { Luck = 8, Weight = 0.8 }, { Luck = 10, Weight = 0.2 } },
	},
	{
		Id = "Avec un gros lot",
		Table = { { Luck = 1, Weight = 55 }, { Luck = 1.5, Weight = 20 }, { Luck = 2, Weight = 12 }, { Luck = 3, Weight = 7 }, { Luck = 5, Weight = 4 }, { Luck = 8, Weight = 1.5 }, { Luck = 10, Weight = 0.4 }, { Luck = 25, Weight = 0.1 } },
	},
	{
		Id = "Très généreuse",
		Table = { { Luck = 1, Weight = 40 }, { Luck = 2, Weight = 25 }, { Luck = 5, Weight = 18 }, { Luck = 10, Weight = 10 }, { Luck = 25, Weight = 5 }, { Luck = 50, Weight = 2 } },
	},
}

-- Construit l'économie proposée (mêmes champs que l'économie actuelle lue par BT.Actuelle).
-- options (essais du rapport) : SpeedRequired = autre table des Speed demandées ; TapisZone5 = facteur des prix des
-- niveaux 17 à 20 du tapis.
function BT.Construire(options)
	local O = options or {}
	local speeds = O.SpeedRequired or BT.SpeedRequired
	local stats = statsOf(speeds, O.StatsLast or BT.StatsLast)
	local Zones, Tools, Cosmetics, Rarities, Items = Config.Zones, Config.Tools, Config.Cosmetics, Config.Rarities, Config.Items
	local Balance = Config.Balance
	local eco = { Nom = "B/T" }
	eco.TicksPerSecond = BT.Tapis.TicksPerSecond
	eco.Gain = function(level) -- niveau enregistré 0 à 19 ; Speed par seconde, sans taps ni bulles
		return BT.Tapis.TicksPerSecond * BT.Tapis.GainPerTick * BT.Tapis.GainGrowth ^ level
	end
	eco.WalkPerDecade, eco.SpeedScale = stats.WalkPerDecade, stats.SpeedScale
	eco.Income = BT.Income
	eco.Tools, eco.Auras, eco.Trails = {}, {}, {}
	local function priced(list, id)
		for _, row in list do
			if row[1] == id then
				return price(row[2], row[3]), row[2], row[3]
			end
		end
		return 0, nil, nil
	end
	for index, tool in Tools.List do
		local p, zone, minutes = priced(BT.Tools, tool.Id)
		eco.Tools[index] = { Id = tool.Id, Power = if BT.ToolPower then BT.ToolPower[tool.Id] else tool.Power, Price = p, Old = tool, Zone = zone, Minutes = minutes }
	end
	for index, aura in Cosmetics.Auras do
		local p, zone, minutes = priced(BT.Auras, aura.Id)
		eco.Auras[index] = { Id = aura.Id, Multiplier = aura.Multiplier, Price = p, Old = aura, Zone = zone, Minutes = minutes }
	end
	for index, trail in Cosmetics.Trails do
		local p, zone, minutes = priced(BT.Trails, trail.Id)
		eco.Trails[index] = { Id = trail.Id, Multiplier = trail.Multiplier, Price = p, Old = trail, Zone = zone, Minutes = minutes }
	end
	eco.TreadCost, eco.TreadRule = {}, BT.TreadmillCosts
	for index, row in BT.TreadmillCosts do
		-- { zone, minutes } : prix en minutes du revenu de référence ; { "abs", prix, revenu } : prix fixé, égal à une
		-- absence complète (BT.AbsenceHours) du joueur moyen à ce revenu (rapport, « hors ligne et prix du tapis »).
		local base = if O.TreadPrices and O.TreadPrices[index] then O.TreadPrices[index] elseif row[1] == "abs" then row[2] else price(row[1], row[2])
		eco.TreadCost[index] = round2(base * (if index >= 16 then (O.TapisZone5 or 1) else 1))
	end
	-- Essai (question 10) : niveaux au-delà de la table (TreadLevels niveaux en tout), prix donnés par TreadPrices.
	for index = #BT.TreadmillCosts + 1, (O.TreadLevels or 0) - 1 do
		eco.TreadCost[index] = round2(O.TreadPrices[index])
	end
	eco.StandCost, eco.StandRule = {}, BT.StandCosts
	for index, row in BT.StandCosts do
		eco.StandCost[index] = price(row[1], row[2])
	end
	eco.Speed = speeds
	eco.Zones = {}
	local perDamage = function(players, seconds)
		return players * seconds * Balance.Hit.MaxHitsPerSecond / (1 + Balance.Window.RegenPerSecond * seconds)
	end
	local rule = Balance.WindowHP
	for index, zone in Zones do
		local tool, aura
		for _, entry in eco.Tools do
			if entry.Id == zone.Kit[1] then
				tool = entry
			end
		end
		for _, entry in eco.Auras do
			if zone.Kit[2] and entry.Id == Cosmetics.Current(zone.Kit[2]) then
				aura = entry
			end
		end
		local damage = tool.Power * (if aura then aura.Multiplier else 1)
		local last = index == #Zones
		eco.Zones[index] = {
			Damage = damage,
			HP = if index == 1 then zone.WindowHP else math.round((if last then perDamage(rule.LastZoneTeamSize, rule.LastZoneBreakTime) else perDamage(1, rule.SoloBreakTime)) * damage),
			Distance = zone.ReturnDistance,
			Speed = speeds[index],
			Team = last,
		}
	end
	return eco
end

-- L'économie d'aujourd'hui, lue dans src/shared/Config, sous la même forme.
function BT.Actuelle()
	local Zones, Tools, Cosmetics, Rarities, Upgrades = Config.Zones, Config.Tools, Config.Cosmetics, Config.Rarities, Config.Upgrades
	local Balance, Training, ShopGrowth = Config.Balance, Config.Training, Config.ShopGrowth
	local eco = { Nom = "Actuelle" }
	eco.TicksPerSecond = 1
	eco.Gain = function(level)
		return Training.Treadmill.GainPerSecond * Training.Treadmill.GainGrowth ^ level
	end
	eco.WalkPerDecade, eco.SpeedScale = Balance.Stats.WalkPerDecade, Balance.Stats.SpeedScale
	eco.Income = {}
	for _, rarity in Rarities.List do
		eco.Income[rarity.Id] = rarity.Income
	end
	eco.Tools, eco.Auras, eco.Trails = {}, {}, {}
	for index, tool in Tools.List do
		eco.Tools[index] = { Id = tool.Id, Power = tool.Power, Price = tool.Price, Old = tool }
	end
	for index, aura in Cosmetics.Auras do
		eco.Auras[index] = { Id = aura.Id, Multiplier = aura.Multiplier, Price = aura.Price, Old = aura }
	end
	for index, trail in Cosmetics.Trails do
		eco.Trails[index] = { Id = trail.Id, Multiplier = trail.Multiplier, Price = trail.Price, Old = trail }
	end
	eco.TreadCost = table.clone(Upgrades.ById.Treadmill.Costs)
	local stands = Upgrades.ById.DisplaySlots.Costs
	eco.StandCost = { stands[1], stands[2], stands[3], stands[4], ShopGrowth.Floor2.Cost }
	for _, cost in ShopGrowth.Floor2.Costs do
		table.insert(eco.StandCost, cost)
	end
	eco.Speed, eco.Zones = {}, {}
	for index, zone in Zones do
		eco.Speed[index] = zone.SpeedRequired
		eco.Zones[index] = { Damage = zone.AdvisedDamage, HP = zone.WindowHP, Distance = zone.ReturnDistance, Speed = zone.SpeedRequired, Team = index == #Zones }
	end
	return eco
end

return BT
