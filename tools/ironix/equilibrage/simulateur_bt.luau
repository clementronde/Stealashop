--!nocheck
-- Joueur simulé de l'économie « B/T » (a479, 25/11). Léger et rapide (des centaines d'heures de jeu par partie) :
-- il ne remplace pas Outil/modele (profils Prudent, Moyen, Acharné de la v2), il ajoute les profils « robot ».
--
-- Ce que fait un joueur simulé, en boucle, jusqu'à son premier objet rapporté de la zone 6 :
--   1. il achète ce qui raccourcit son arrivée dans la zone suivante (niveau du tapis, trail), un présentoir s'il se
--      rembourse vite, puis le kit le moins cher qui casse la vitrine suivante ;
--   2. le jour, il braque (un objet par braquage, tiré avec les vraies règles : rareté du colis, contenu selon la
--      chance, objet, mutation d'effet, poids) tant que ses présentoirs ne sont pas pleins d'objets de sa zone, ou
--      quand l'argent lui manque ; sinon, et toute la nuit, il court sur le tapis.
--
-- Profil (p) :
--   Gain        multiplicateur du tapis : taps (+50 %) et bulles (une toutes les 5 s, ×3,05 en moyenne)
--   Flanerie    temps réel passé par seconde utile (1 = aucune seconde perdue)
--   Mode        "Best" : le meilleur objet de la zone à chaque braquage ; "Draw" : tirage réel
--   Table       chance de la boîte : nil = tirée dans la table (ShelfOpen.LuckTable) ; un nombre = toujours celle-là
--   Server, Skill   chance du serveur (×1, 2, 4, 8) et de l'arbre (×1 à ×1,5), comptées tout le temps
--   Mutation    multiplicateur fixe du revenu d'un objet en mode "Best" (1 ; 100 = Rainbow de 10 000 kg)
--   Panneau     true : attend les deux nombres du panneau (Speed et dégâts du kit) ; false : entre dès que le
--               vigile ne le rattrape plus et que la vitrine casse dans le chrono de police
--   Caught      chance d'être rattrapé à chaque braquage
--   Part        part des 20 colis de la zone qu'il obtient à chaque nuit
--   HeistShare, BoundShare   part du temps de jour passée à braquer (présentoirs pleins) : en temps normal, et
--               quand l'argent manque pour l'achat prévu
--   Session     nil, ou { Length = s de jeu par session, PerDay = sessions par jour, Cap = heures hors ligne comptées }
--   Income      multiplicateur des revenus des présentoirs (gamepass ×2 Cash) ; absent = 1
--   Cantin      nil, ou la chance du modèle de Cantin : { Rule, Perso, Skill, Server, Table } (voir Sim.DrawCantin)

local Balance, Zones, Rarities, Items = Config.Balance, Config.Zones, Config.Rarities, Config.Items
local ShelfBoxes, ShelfOpen, Mutations, Night = Config.ShelfBoxes, Config.ShelfOpen, Config.Mutations, Config.Night
local Chase, Training, Bubbles, Pawn, Unbox = Config.Chase, Config.Training, Config.Bubbles, Config.Pawn, Config.Unbox
local ItemWeight = charge("ItemWeight")

local Sim = {}

-- Hypothèses (pas des valeurs du jeu) : les mêmes que Outil/modele quand elles y existent.
Sim.Hypotheses = {
	InStore = 3, -- s pour entrer dans le magasin et atteindre le rayon
	Deposit = 6, -- s pour poser l'objet dans sa boutique
	PlotDistance = 60, -- studs entre l'arche de la zone safe et sa boutique
	CaughtLoss = 10, -- s perdues quand on est rattrapé
	OpenBase = 5.2, -- s d'ouverture d'un colis Commun (Config/Unbox, a287 : 5,2 s Commun, 9 s Rare, 13 s Légendaire)
	OpenPerRarity = 1.95, -- s de plus par rareté
	StandPayback = 1800, -- s : un présentoir s'achète s'il est remboursé en ce temps
	BoxesPerZone = 20, -- 2 magasins × 10 emplacements, remplis à chaque nuit
}

-- Bulles du tapis : valeur moyenne d'une bulle (× le gain d'une seconde) et délai moyen entre deux bulles.
local bubbleMean, bubbleTotal = 0, 0
for _, entry in Bubbles.Chances do
	bubbleMean += entry.Multiplier * entry.Percent
	bubbleTotal += entry.Percent
end
bubbleMean /= bubbleTotal
local bubbleEvery = (Bubbles.SpawnMin + Bubbles.SpawnMax) / 2
Sim.BubbleMean, Sim.BubbleEvery = bubbleMean, bubbleEvery
-- Multiplicateur du tapis : `taps` = part du temps où le joueur tape, `bubbles` = part des bulles prises.
function Sim.GainOf(taps, bubbles, bubbleValue)
	return (1 + Training.Treadmill.TapBonus * taps) * (1 + bubbles * (bubbleValue or bubbleMean) / bubbleEvery)
end

local function generator(seed)
	local state = (seed * 7919) % 2147483646 + 1
	local self = {}
	function self.NextNumber(_)
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	return self
end
Sim.Generator = generator

-- $/s d'un objet du catalogue dans une économie (Formulas.ItemIncome avec la table Income de l'économie).
function Sim.ItemIncome(eco, item)
	local rules = Rarities.IncomeRules
	local first = Rarities.FirstZone[item.Rarity]
	local above = if item.Zone and first then math.max(item.Zone - first, 0) else 0
	return eco.Income[item.Rarity] * (1 + rules.ZoneStep * above) * (1 + rules.RankStep) ^ (item.Rank - 1)
end

-- Meilleur objet tirable de la zone (rareté la plus haute de la zone, rang le plus haut) : revenu et rareté.
function Sim.BestOf(eco, zone)
	local best, bestRarity = 0, nil
	for _, rarityId in Rarities.ZoneRarities[zone] do
		local pool = Items.AllZones[rarityId] or (Items.ByZone[zone] or {})[rarityId] or {}
		for _, item in pool do
			local income = Sim.ItemIncome(eco, item)
			if income > best then
				best, bestRarity = income, rarityId
			end
		end
	end
	return best, bestRarity
end

-- Table de chance active (ShelfOpen.LuckTable, ou une table d'essai).
Sim.LuckTable = nil
local function luckTable()
	return Sim.LuckTable or ShelfOpen.LuckTable
end
local function drawTableLuck(rng)
	local total = 0
	for _, entry in luckTable() do
		total += math.max(entry.Weight, 0)
	end
	local roll = rng:NextNumber() * total
	local last = 1
	for _, entry in luckTable() do
		last = entry.Luck
		if roll < entry.Weight then
			return entry.Luck
		end
		roll -= entry.Weight
	end
	return last
end
Sim.DrawTableLuck = drawTableLuck

-- Essai (rapport, section chance) : autre règle pour ShelfOpen.ShelfStepUp. Sim.StepRule = nil : la règle du jeu, par la
-- vraie fonction ShelfBoxes.ContentWeights ; sinon function(chance) -> cran. La règle AboveBox est recopiée ici pour
-- l'essai seulement ; le rapport vérifie que la copie donne les mêmes poids que la vraie fonction au cran du jeu.
Sim.StepRule = nil
function Sim.ContentWeightsWith(boxRarity, luck, zone, stepUp)
	local odds = ShelfOpen.BoxRarityOdds[boxRarity]
	local allowed = Rarities.ZoneAllowed[zone]
	local box = Rarities.ById[boxRarity]
	local boost = if luck > 1 and luck < math.huge then luck else 1
	local weights = {}
	for _, rarity in Rarities.List do
		local weight = odds[rarity.Id] or 0
		if weight > 0 and allowed[rarity.Id] then
			local above = rarity.Order - box.Order
			weights[rarity.Id] = if above > 0 then weight * boost * stepUp ^ above else weight
		end
	end
	return weights
end

local weightCache = {}
function Sim.SetStepRule(rule)
	Sim.StepRule = rule
	table.clear(weightCache)
end
local function contentWeights(boxRarity, luck, zone)
	local key = `{boxRarity}/{luck}/{zone}`
	local cached = weightCache[key]
	if cached == nil then
		local weights = if Sim.StepRule then Sim.ContentWeightsWith(boxRarity, luck, zone, Sim.StepRule(luck)) else ShelfBoxes.ContentWeights(boxRarity, luck, zone)
		local list, total = {}, 0
		for _, rarity in Rarities.List do
			local weight = weights and weights[rarity.Id]
			if weight and weight > 0 then
				table.insert(list, { Id = rarity.Id, Weight = weight })
				total += weight
			end
		end
		cached = { List = list, Total = total }
		weightCache[key] = cached
	end
	return cached
end

-- Part de chaque rareté d'objet pour un braquage de la zone à cette chance (exact, sans tirage).
function Sim.Shares(zone, luck)
	local share, boxTotal = {}, 0
	for _, percent in ShelfBoxes.ZoneOdds[zone] do
		boxTotal += percent
	end
	for boxRarity, percent in ShelfBoxes.ZoneOdds[zone] do
		local weights = contentWeights(boxRarity, luck, zone)
		for _, entry in weights.List do
			share[entry.Id] = (share[entry.Id] or 0) + percent / boxTotal * entry.Weight / weights.Total
		end
	end
	return share
end

-- Un objet tiré comme le serveur le fait (StoreHeistService.startReveal) : rareté du colis de l'emplacement, contenu
-- selon la chance (ShelfBoxes.ContentWeights), objet (DrawWeight), mutation d'effet (sans chance), poids (avec la
-- chance). Les montées de rareté montrées pendant les coups (UnboxPlan.upgrades) ne changent pas l'objet : elles ne
-- sont pas tirées ici. Renvoie le revenu, la rareté et l'ordre de la rareté.
function Sim.Draw(eco, zone, luck, rng)
	local roll = rng:NextNumber() * 100
	local boxRarity
	for _, rarity in Rarities.List do
		local percent = ShelfBoxes.ZoneOdds[zone][rarity.Id]
		if percent then
			boxRarity = rarity.Id
			if roll < percent then
				break
			end
			roll -= percent
		end
	end
	local weights = contentWeights(boxRarity, luck, zone)
	roll = rng:NextNumber() * weights.Total
	local rarityId = weights.List[#weights.List].Id
	for _, entry in weights.List do
		if roll < entry.Weight then
			rarityId = entry.Id
			break
		end
		roll -= entry.Weight
	end
	local pool = Items.AllZones[rarityId] or (Items.ByZone[zone] or {})[rarityId]
	local total = 0
	for _, item in pool do
		total += item.DrawWeight
	end
	roll = rng:NextNumber() * total
	local picked = pool[#pool]
	for _, item in pool do
		if roll < item.DrawWeight then
			picked = item
			break
		end
		roll -= item.DrawWeight
	end
	local income = Sim.ItemIncome(eco, picked)
	roll = rng:NextNumber() * 100
	for _, effect in Mutations.Effects do
		if roll < effect.Chance then
			income *= effect.IncomeMultiplier
			break
		end
		roll -= effect.Chance
	end
	income *= ItemWeight.IncomeFactor(ItemWeight.Roll(rng, luck))
	return income, rarityId, Rarities.ById[rarityId].Order
end

---------------------------------------------------------------------------------------------- modèle de chance de Cantin
-- Modèle de chance de Cantin (25/11, note a479-passe3-cantin.md). Rien de ceci n'est dans le jeu : c'est un essai.
--   chance achetée c = personnelle (×3 Luck) × arbre (Box Luck) × serveur (×2, ×4, ×8) ;
--   à l'ouverture d'un colis : (b) les taux des hauts ×N de la table montent selon une règle (R1, R2, R3) ;
--                              (a) la chance finale du colis = ×N tiré × c (c'est le nombre affiché) ;
--                              puis la rareté de l'objet et le poids sont tirés avec cette chance finale, comme aujourd'hui ;
--   la chance du SERVEUR augmente en plus tout ce qui a un pourcentage : la rareté des colis en rayon
--   (Rarities.ZoneOdds) et les mutations d'effet (Gold, Rainbow…). V0 de cette règle : Sim.Boost.
-- spec = { Rule = "R1" | "R2" | "R3" | "Table" (taux inchangés), Perso, Skill, Server, Table = ×N imposé (facultatif) }.

-- « Ramené à 100 % » : dans une liste de poids, le premier est le résultat courant (×1, plus basse rareté, aucune
-- mutation) ; les autres (ou seulement ceux que `only` accepte) sont multipliés par k et pris sur le premier ; quand
-- le premier est vide, les autres sont ramenés au total de départ. Renvoie une nouvelle liste (mêmes entrées).
function Sim.Boost(list, k, only)
	local total, others = 0, 0
	local out = {}
	for index, entry in list do
		local copy = table.clone(entry)
		total += entry.Weight
		if index > 1 then
			if only == nil or only(entry) then
				copy.Weight = entry.Weight * k
			end
			others += copy.Weight
		end
		out[index] = copy
	end
	if others <= total then
		out[1].Weight = total - others
	else
		out[1].Weight = 0
		for index = 2, #out do
			out[index].Weight *= total / others
		end
	end
	return out
end

-- Table de chance de la boîte pour une chance achetée c, selon la règle :
--   R1 : tous les taux au-dessus de ×1 multipliés par c ;
--   R2 : seuls ×8 et ×10 multipliés par c (l'exemple de Cantin : ×10 de 0,5 % à 4 % avec ×8) ;
--   R3 : tous les taux au-dessus de ×1 multipliés par la racine de c ;
--   Table (ou autre) : taux inchangés.
local tableCache = {}
function Sim.TableFor(rule, c)
	local key = `{rule}/{c}/{tostring(Sim.LuckTable)}`
	local cached = tableCache[key]
	if cached == nil then
		local list = {}
		for _, entry in luckTable() do
			table.insert(list, { Luck = entry.Luck, Weight = entry.Weight })
		end
		table.sort(list, function(a, b)
			return a.Luck < b.Luck
		end)
		if rule == "R1" then
			cached = Sim.Boost(list, c)
		elseif rule == "R2" then
			cached = Sim.Boost(list, c, function(entry)
				return entry.Luck >= 8
			end)
		elseif rule == "R3" then
			cached = Sim.Boost(list, math.sqrt(c))
		else
			cached = list
		end
		tableCache[key] = cached
	end
	return cached
end

-- Rareté des colis en rayon avec la chance du serveur s : les raretés au-dessus de la plus basse de la zone × s.
local boxCache = {}
function Sim.BoxOdds(zone, s)
	local key = `{zone}/{s}`
	local cached = boxCache[key]
	if cached == nil then
		local list = {}
		for _, rarity in Rarities.List do
			local percent = ShelfBoxes.ZoneOdds[zone][rarity.Id]
			if percent then
				table.insert(list, { Id = rarity.Id, Weight = percent })
			end
		end
		cached = if s > 1 then Sim.Boost(list, s) else list
		boxCache[key] = cached
	end
	return cached
end

-- Mutations d'effet avec la chance du serveur s : chaque effet × s, pris sur « aucune mutation ».
local effectCache = {}
function Sim.EffectOdds(s)
	local cached = effectCache[s]
	if cached == nil then
		local used = 0
		for _, effect in Mutations.Effects do
			used += effect.Chance
		end
		local list = { { Id = "None", Weight = 100 - used, Multiplier = 1 } }
		for _, effect in Mutations.Effects do
			table.insert(list, { Id = effect.Id, Weight = effect.Chance, Multiplier = effect.IncomeMultiplier })
		end
		cached = if s > 1 then Sim.Boost(list, s) else list
		effectCache[s] = cached
	end
	return cached
end
function Sim.EffectMean(s)
	local total, weight = 0, 0
	for _, entry in Sim.EffectOdds(s) do
		total += entry.Weight * entry.Multiplier
		weight += entry.Weight
	end
	return total / weight
end

local function pickWeighted(list, rng)
	local total = 0
	for _, entry in list do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in list do
		if roll < entry.Weight then
			return entry
		end
		roll -= entry.Weight
	end
	return list[#list]
end

local function specLuck(spec)
	local server = spec.Server or 1
	return (spec.Perso or 1) * (spec.Skill or 1) * server, server
end

-- Table du ×N d'un colis pour ce joueur : { { Luck, Weight } } (un seul ×N si spec.Table l'impose).
function Sim.SpecTable(spec)
	local c = specLuck(spec)
	if spec.Table then
		return { { Luck = spec.Table, Weight = 100 } }, c
	end
	return Sim.TableFor(spec.Rule, c), c
end

-- Part de chaque rareté d'objet pour un braquage de la zone dans le modèle de Cantin (exact, sans tirage), et la
-- chance finale moyenne du colis.
function Sim.SharesCantin(zone, spec)
	local luckList, c = Sim.SpecTable(spec)
	local _, server = specLuck(spec)
	local boxes = Sim.BoxOdds(zone, server)
	local boxTotal, luckTotal = 0, 0
	for _, box in boxes do
		boxTotal += box.Weight
	end
	for _, entry in luckList do
		luckTotal += entry.Weight
	end
	local share = {}
	for _, box in boxes do
		if box.Weight > 0 then
			for _, entry in luckList do
				if entry.Weight > 0 then
					local weights = contentWeights(box.Id, entry.Luck * c, zone)
					for _, content in weights.List do
						share[content.Id] = (share[content.Id] or 0) + box.Weight / boxTotal * entry.Weight / luckTotal * content.Weight / weights.Total
					end
				end
			end
		end
	end
	return share
end

-- Un objet tiré dans le modèle de Cantin. Renvoie le revenu, la rareté, l'ordre de la rareté, la chance finale.
function Sim.DrawCantin(eco, zone, spec, rng)
	local luckList, c = Sim.SpecTable(spec)
	local _, server = specLuck(spec)
	local box = pickWeighted(Sim.BoxOdds(zone, server), rng)
	local luck = pickWeighted(luckList, rng).Luck * c
	local weights = contentWeights(box.Id, luck, zone)
	local rarityId = pickWeighted(weights.List, rng).Id
	local pool = Items.AllZones[rarityId] or (Items.ByZone[zone] or {})[rarityId]
	local total = 0
	for _, item in pool do
		total += item.DrawWeight
	end
	local roll = rng:NextNumber() * total
	local picked = pool[#pool]
	for _, item in pool do
		if roll < item.DrawWeight then
			picked = item
			break
		end
		roll -= item.DrawWeight
	end
	local income = Sim.ItemIncome(eco, picked) * pickWeighted(Sim.EffectOdds(server), rng).Multiplier
	income *= ItemWeight.IncomeFactor(ItemWeight.Roll(rng, luck))
	return income, rarityId, Rarities.ById[rarityId].Order, luck
end

function Sim.Walk(eco, shown)
	local stats = Balance.Stats
	return stats.RealSpeedScale * math.min(stats.MaxWalkSpeed, stats.BaseWalkSpeed + eco.WalkPerDecade * math.log10(1 + shown / eco.SpeedScale))
end

-- Part de la Speed du panneau à partir de laquelle le vigile ne rattrape plus un porteur qui court tout droit
-- (Config/Chase : il se rapproche de ClosingSpeedMax × (1 − Speed / Speed demandée), de HoldDistance à la capture).
function Sim.ChaseFraction(eco, zone)
	local required = eco.Speed[zone]
	if required <= 0 then
		return 0
	end
	local back = eco.Zones[zone].Distance / (Balance.Carry.NPCBoxSpeedMultiplier * Sim.Walk(eco, required))
	local closing = (Chase.HoldDistance - Balance.Guard.CatchDistance) / back
	return math.clamp(1 - closing / Chase.ClosingSpeedMax, 0.5, 1)
end

-- PV cassables dans le chrono de police par point de dégâts d'un joueur (5 coups/s, régénération comprise).
local function hpPerDamageInTimer()
	local T = Balance.Window.BreakTimer
	return T * Balance.Hit.MaxHitsPerSecond / (1 + Balance.Window.RegenPerSecond * T)
end

function Sim.Jouer(eco, p, seed, maxSeconds)
	local H = Sim.Hypotheses
	local rng = generator(seed)
	local zoneCount = #eco.Zones
	local cycleLength = Night.DayDuration + Night.NightDuration
	local s = {
		t = 0, -- temps de jeu (s)
		away = 0, -- temps hors ligne (s), sessions seulement
		cash = 0,
		speed = 0,
		level = 0, -- niveau enregistré du tapis (0 à 19)
		tools = { true },
		auras = {},
		trail = 0,
		standLevel = 0,
		stands = {},
		zone = 1,
		boxes = 0,
		cycle = -1,
		heistTime = 0,
		trainTime = 0,
		session = 0,
		spent = 0,
		offline = 0,
	}
	local out = { Entrees = {}, Achats = {}, Braquages = 0, Rattrape = 0, Raretes = {}, Zones = {}, Absences = {} }
	for zone = 1, zoneCount do
		out.Zones[zone] = { Duree = 0, Gagne = 0, Vendu = 0, Depense = 0, Attente = 0, Braquages = 0 }
	end
	local best = {}
	for zone = 1, zoneCount do
		best[zone] = Sim.BestOf(eco, zone)
	end

	local function slots()
		return Balance.Display.StartSlots + math.min(s.standLevel, 4) + math.max(0, s.standLevel - 5)
	end
	local function income()
		local total = 0
		for _, stand in s.stands do
			total += stand.Income
		end
		return total * (p.Income or 1)
	end
	local function trailOf(index)
		return if index > 0 then eco.Trails[index].Multiplier else 1
	end
	local function shown()
		return s.speed * trailOf(s.trail)
	end
	local function rate()
		return eco.Gain(s.level) * p.Gain
	end
	local function damage()
		local power, multiplier = 0, 1
		for index, tool in eco.Tools do
			if s.tools[index] then
				power = math.max(power, tool.Power)
			end
		end
		for index, aura in eco.Auras do
			if s.auras[index] then
				multiplier = math.max(multiplier, aura.Multiplier)
			end
		end
		return power * multiplier
	end
	-- Dégâts qu'il lui faut pour la vitrine de la zone (zone d'équipe : le partenaire est au panneau).
	local function damageNeeded(zone)
		local info = eco.Zones[zone]
		if p.Panneau then
			return info.Damage
		end
		local need = info.HP / hpPerDamageInTimer()
		return if info.Team then need - info.Damage else need
	end
	-- Kit le moins cher qui suffit : prix, arme et aura à acheter.
	local function kit(zone)
		local need = damageNeeded(zone)
		local bestCost, bestTool, bestAura = math.huge, nil, nil
		for ti, tool in eco.Tools do
			for ai = 0, #eco.Auras do
				local multiplier = if ai > 0 then eco.Auras[ai].Multiplier else 1
				if tool.Power * multiplier >= need * 0.999 then
					local cost = (if s.tools[ti] then 0 else tool.Price) + (if ai == 0 or s.auras[ai] then 0 else eco.Auras[ai].Price)
					if cost < bestCost then
						bestCost, bestTool, bestAura = cost, ti, ai
					end
				end
			end
		end
		return bestCost, bestTool, bestAura
	end
	local function speedNeeded(zone)
		return eco.Speed[zone] * (if p.Panneau then 1 else Sim.ChaseFraction(eco, zone))
	end

	local function advance(seconds, training)
		local real = seconds * p.Flanerie
		local stat = out.Zones[s.zone]
		stat.Duree += real
		stat.Gagne += income() * real
		if s.bound then
			stat.Attente += real
		end
		s.cash += income() * real
		if training then
			s.speed += rate() * seconds
			s.trainTime += real
		else
			s.heistTime += real
		end
		s.t += real
		if p.Session then
			s.session += real
			if s.session >= p.Session.Length then
				s.session -= p.Session.Length
				local absence = 86400 / p.Session.PerDay - p.Session.Length
				-- Chaque absence : niveau du tapis possédé, revenu et prix du niveau suivant (rapport « hors ligne »).
				table.insert(out.Absences, { Level = s.level, Income = income(), Next = eco.TreadCost[s.level + 1], Zone = s.zone, T = s.t })
				local earned = Config.Offline.Rate * math.min(absence, p.Session.Cap * 3600) * income()
				s.cash += earned
				s.offline += earned
				s.away += absence
			end
		end
	end

	local function buy(kind, name, cost)
		s.cash -= cost
		s.spent += cost
		out.Zones[s.zone].Depense += cost
		local rateNow = income()
		table.insert(out.Achats, { Kind = kind, Name = name, T = s.t, Price = cost, Minutes = if rateNow > 0 then cost / rateNow / 60 else math.huge, Zone = s.zone, Income = rateNow, Level = s.level })
	end

	-- Temps prévu avant d'être prêt pour la zone visée, sans autre achat ; puis le meilleur achat de vitesse.
	local function plan(target)
		local need = speedNeeded(target)
		local kitCost = kit(target)
		local I = income()
		-- Vitesse gagnée par seconde réelle : il ne court pas tout le temps (braquages de jour, temps perdu).
		local m = trailOf(s.trail)
		local r = rate() * (1 - 0.8 * p.HeistShare) / p.Flanerie
		local rBound = rate() * (1 - 0.8 * p.BoundShare) / p.Flanerie
		local function ready(speed, cash, r2, m2)
			local tau = math.max(0, need / m2 - speed) / r2
			local wait = if cash >= kitCost then 0 elseif I > 0 then (kitCost - cash) / I else math.huge
			return math.max(tau, wait)
		end
		local bestT = ready(s.speed, s.cash, r, m)
		local choice = nil
		local function try(kind, index, cost, r2, m2)
			local wait = if s.cash >= cost then 0 elseif I > 0 then (cost - s.cash) / I else math.huge
			if wait == math.huge then
				return
			end
			local T = wait + ready(s.speed + rBound * wait, s.cash + I * wait - cost, r2, m2)
			if T < bestT * 0.98 then
				bestT, choice = T, { Kind = kind, Index = index, Price = cost, Wait = wait }
			end
		end
		if s.level < #eco.TreadCost then
			try("Tapis", s.level + 1, eco.TreadCost[s.level + 1], r * 2, m)
		end
		if s.trail < #eco.Trails then
			local nextTrail = eco.Trails[s.trail + 1]
			try("Trail", s.trail + 1, nextTrail.Price, r, nextTrail.Multiplier)
		end
		return need, kitCost, bestT, choice
	end

	local function place(itemIncome, zone)
		if #s.stands < slots() then
			table.insert(s.stands, { Income = itemIncome, Zone = zone })
			return
		end
		local worst, worstIndex = math.huge, 0
		for index, stand in s.stands do
			if stand.Income < worst then
				worst, worstIndex = stand.Income, index
			end
		end
		if itemIncome > worst then
			s.stands[worstIndex] = { Income = itemIncome, Zone = zone }
			s.cash += Pawn.PriceFactor * worst
			out.Zones[s.zone].Vendu += Pawn.PriceFactor * worst
		else
			s.cash += Pawn.PriceFactor * itemIncome
			out.Zones[s.zone].Vendu += Pawn.PriceFactor * itemIncome
		end
	end

	local function tripSeconds(zone, rarityOrder)
		local info = eco.Zones[zone]
		local walk = Sim.Walk(eco, shown())
		local hit = damage() + (if info.Team then info.Damage else 0)
		local net = Balance.Hit.MaxHitsPerSecond * hit - Balance.Window.RegenPerSecond * info.HP
		local breakTime = if net > 0 then info.HP / net else Balance.Window.BreakTimer
		local open = H.OpenBase + H.OpenPerRarity * (rarityOrder - 1)
		return (info.Distance + H.PlotDistance) / walk + breakTime + H.InStore + open + info.Distance / (Balance.Carry.NPCBoxSpeedMultiplier * walk) + H.PlotDistance / walk + H.Deposit
	end

	local function heist(zone)
		local itemIncome, rarityId, order
		if p.Mode == "Best" then
			local value, id = Sim.BestOf(eco, zone)
			itemIncome, rarityId, order = value * (p.Mutation or 1), id, Rarities.ById[id].Order
		elseif p.Cantin then
			itemIncome, rarityId, order = Sim.DrawCantin(eco, zone, p.Cantin, rng)
		else
			local luck = (p.Table or drawTableLuck(rng)) * (p.Server or 1) * (p.Skill or 1)
			itemIncome, rarityId, order = Sim.Draw(eco, zone, luck, rng)
		end
		local trip = tripSeconds(zone, order) * (p.Trip or 1)
		s.boxes -= 1
		if rng:NextNumber() < (p.Caught or 0) then
			out.Rattrape += 1
			advance(trip * 0.7 + H.CaughtLoss, false)
			return
		end
		advance(trip, false)
		out.Braquages += 1
		out.Zones[zone].Braquages += 1
		out.Raretes[rarityId] = (out.Raretes[rarityId] or 0) + 1
		place(itemIncome, zone)
		if out.Entrees[zone] == nil then
			out.Entrees[zone] = {
				T = s.t,
				Jours = (s.t + s.away) / 86400,
				Speed = shown(),
				Tapis = s.level + 1,
				Presentoirs = slots(),
				Revenu = income(),
				Degats = damage(),
				Depense = s.spent,
				Braquages = out.Braquages,
				Argent = s.cash,
			}
		end
	end

	while s.t < maxSeconds and out.Entrees[zoneCount] == nil do
		local cycle = s.t // cycleLength
		if cycle ~= s.cycle then
			s.cycle = cycle
			s.boxes = math.floor(H.BoxesPerZone * p.Part + 0.5)
		end
		local isDay = s.t % cycleLength < Night.DayDuration
		local target = if s.zone < zoneCount then s.zone + 1 else nil

		-- Achats.
		local need, kitCost, _eta, choice = 0, 0, 0, nil
		local bought = true
		while bought and target ~= nil do
			bought = false
			need, kitCost, _eta, choice = plan(target)
			if choice ~= nil and s.cash >= choice.Price then
				if choice.Kind == "Tapis" then
					buy("Tapis", `Tapis {choice.Index + 1}`, choice.Price)
					s.level = choice.Index
				else
					buy("Trail", eco.Trails[choice.Index].Id, choice.Price)
					s.trail = choice.Index
				end
				bought = true
			elseif shown() >= need and s.cash >= kitCost then
				local _, ti, ai = kit(target)
				if not s.tools[ti] then
					buy("Arme", eco.Tools[ti].Id, eco.Tools[ti].Price)
					s.tools[ti] = true
				end
				if ai > 0 and not s.auras[ai] then
					buy("Aura", eco.Auras[ai].Id, eco.Auras[ai].Price)
					s.auras[ai] = true
				end
				s.zone = target
				s.heistTime, s.trainTime = 0, 0
				target = if s.zone < zoneCount then s.zone + 1 else nil
				bought = target ~= nil
			else
				local standCost = eco.StandCost[s.standLevel + 1]
				if standCost ~= nil and #s.stands >= slots() and s.cash >= standCost then
					local value = if p.Mode == "Best" then best[s.zone] * (p.Mutation or 1) else income() / math.max(1, #s.stands)
					-- L'étage lui-même n'ajoute pas de place : on le compte avec la place qui suit.
					local cost = if s.standLevel == 4 then standCost + (eco.StandCost[6] or 0) else standCost
					if cost <= H.StandPayback * value and (choice == nil or standCost <= 0.25 * choice.Price or s.cash - standCost >= choice.Price) then
						buy("Presentoir", `Présentoir, achat {s.standLevel + 1}`, standCost)
						s.standLevel += 1
						bought = true
					end
				end
			end
		end

		-- L'argent manque-t-il pour l'achat prévu (niveau du tapis, trail, ou le kit une fois la Speed atteinte) ?
		s.bound = target ~= nil and ((choice ~= nil and s.cash < choice.Price) or (shown() >= need and s.cash < kitCost))

		-- Braquer ou courir.
		local wantHeist = false
		if isDay and s.boxes > 0 then
			if #s.stands < slots() then
				wantHeist = true
			elseif p.Mode == "Best" then
				for _, stand in s.stands do
					if stand.Income < best[s.zone] * (p.Mutation or 1) then
						wantHeist = true
						break
					end
				end
			else
				for _, stand in s.stands do
					if stand.Zone < s.zone then
						wantHeist = true
						break
					end
				end
			end
			if not wantHeist and target ~= nil then
				if shown() >= need then
					wantHeist = true -- prêt, il ne manque que l'argent du kit
				else
					local bound = choice ~= nil and s.cash < choice.Price
					local share = if bound then p.BoundShare else p.HeistShare
					wantHeist = s.heistTime < share * (s.heistTime + s.trainTime)
				end
			end
		end
		if target == nil then
			wantHeist = true -- zone 6 atteinte : il va chercher son premier objet
			if not isDay or s.boxes <= 0 then
				advance(math.max(1, cycleLength - s.t % cycleLength), true)
				continue
			end
		end

		if wantHeist then
			heist(s.zone)
		else
			local I = income()
			local seconds = math.clamp(s.t / 20, 15, 600)
			if target ~= nil then
				local left = (need / trailOf(s.trail) - s.speed) / rate()
				if left > 0 then
					seconds = math.min(seconds, left)
				end
				if I > 0 then
					local goal = if choice ~= nil then choice.Price elseif shown() >= need then kitCost else nil
					if goal ~= nil and goal > s.cash then
						seconds = math.min(seconds, (goal - s.cash) / I)
					end
				end
			end
			-- Jusqu'au prochain changement de jour ou de nuit au plus.
			local inCycle = s.t % cycleLength
			local boundary = if inCycle < Night.DayDuration then Night.DayDuration - inCycle else cycleLength - inCycle
			seconds = math.max(1, math.min(seconds, boundary / p.Flanerie))
			advance(seconds, true)
		end
	end
	out.Fin = s.t
	out.Etat = s
	out.RevenuFinal = income()
	return out
end

return Sim
