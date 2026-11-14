--!nocheck
-- Modèle du simulateur d'équilibrage (liaison L-108, point 1).
--
-- Deux économies passent par le même joueur simulé :
--   Modele.EcoActuelle()   les vraies formules et tables de src/shared/Config (Formulas, Zones, Tools,
--                          Cosmetics, Upgrades, Training, Rarities, Mutations, ShelfBoxes, SkillTree) ;
--   Outil/proposition      la nouvelle échelle (même forme de table, voir Proposition.Construire).
--
-- Forme d'une économie (eco) :
--   eco.Zones[z]           WindowHP, AdvisedDamage, AdvisedSpeed (WalkSpeed), GuardSpeed, ReturnDistance,
--                          BaseIncome, SpeedShown et StrengthShown (ce que le panneau annonce)
--   eco.WalkSpeed(vitesse, mTrail)             vitesse de marche réelle
--   eco.HitDamage(pOutil, force, mAura)        dégâts par coup
--   eco.MachineGain("Treadmill"|"Bench", n)    gain par seconde (tapis) ou par répétition (banc) au niveau n
--   eco.UpgradeCost(id, n)                     prix du niveau suivant (nil au maximum)
--   eco.ItemIncome(zone, rareté)               $/s d'un objet
--   eco.Tools, eco.Auras, eco.Trails           listes (Power ou Multiplier, Price, TargetZones)
--   eco.DoorHP(niveau), eco.Glass, eco.Walls, eco.Regen   porte d'une boutique de joueur et arbre
--   eco.ShownSpeed(vitesse, mTrail), eco.ShownStrength(pOutil, force, mAura)   nombres du HUD
--
-- Ce que le modèle NE compte PAS (toutes des aides : le jeu réel va un peu plus vite) : gamepasses et
-- boosts Robux, renaissances (Partie 2, pas codées), gains hors ligne, récompenses quotidiennes et de
-- temps de jeu, primes et bonus de l'Index, camion, potions, vols entre joueurs (somme nulle).

local Balance = Config.Balance
local Formulas = Config.Formulas
local Zones = Config.Zones
local Tools = Config.Tools
local Cosmetics = Config.Cosmetics
local Upgrades = Config.Upgrades
local Training = Config.Training
local Rarities = Config.Rarities
local Mutations = Config.Mutations
local ShelfBoxes = Config.ShelfBoxes
local SkillTree = Config.SkillTree
local Night = Config.Night
local Tutorial = Config.Tutorial

local Modele = {}

-- Ajouts du rééquilibrage v2 (2026-11-14, Outil/proposition_v2), sans effet sur les autres économies :
--   eco.SansBanc = true        plus de banc : les dégâts ne dépendent que de l'outil et de l'aura
--   eco.Zones[z].TeamHits      zone d'équipe : la vitrine se casse à plusieurs, ce total de coups par
--                              seconde (tous au niveau du joueur simulé), dans le chrono de casse entier
--   eco.MaxHits                passe 2 : plafond de coups par seconde ; tous les profils frappent à ce plafond
--   eco.BreakTimer             passe 3 : chrono de casse proposé (à la place de Balance.Window.BreakTimer)
--   eco.CasseMax               passe 2 : temps de casse accepté par tous les profils (à la place de profil.CasseMax)
--   eco.HeistDuration          passe 2 : chrono du braquage après la casse ; l'ouverture du colis (rabats et
--                              montée de la chance, Config/ShelfOpen) est comptée, et chaque seconde passée
--                              dans le magasin après le chrono rapproche le vigile (voir heist)
--   Modele.Aides               nil, ou { Session, Offline, Daily, Truck… } : aides comptées (voir Jouer)

-- Hypothèses du modèle : ce ne sont PAS des valeurs du jeu, mais ce qu'il faut bien supposer pour
-- faire jouer un joueur. À mesurer en Play et à corriger ici.
Modele.Hypotheses = {
	GuardGap = 20, -- studs entre le voleur et le vigile quand le vigile s'élance (il sort de la réserve)
	GuardReaction = 0.5, -- s ; GuardService.REACTION_DELAY (constante locale du service, recopiée)
	LuckyEscape = 0.15, -- chance résiduelle de s'en sortir quand le vigile rattrape avant la zone safe (esquives)
	InStore = 3, -- s pour entrer dans le magasin et atteindre le rayon, en plus du temps de prise
	Deposit = 6, -- s pour poser et ouvrir le colis dans sa boutique
	PlotDistance = 60, -- studs entre l'arche de la zone safe et sa boutique (zone safe de 240 studs)
	CaughtLoss = 10, -- s perdues quand on est rattrapé (étourdi 2,4 s, retour sans colis)
	BenchRepsPerSecond = 1, -- banc automatique : une répétition par boucle de BenchLift (environ 1 s)
	TrainChunk = 15, -- s : durée d'une séance d'entraînement avant de redécider
	CashMemory = 300, -- s : fenêtre de la moyenne des ventes au receleur (rythme d'argent estimé par le joueur)
	UpgradeBudget = 240, -- s de revenus qu'un joueur met sans réfléchir dans une amélioration
	SlotPayback = 900, -- s : un présentoir de plus s'achète s'il est remboursé en ce temps
}

-- Profils de joueurs. Coups : coups par seconde sur une vitrine (plafond serveur : 10). Vert : attend que
-- les deux nombres du panneau soient verts avant d'entrer dans une zone ; sinon il entre dès que la casse
-- tient dans CasseMax secondes et que le vigile ne le rattrape pas. Part : part des colis de la zone qu'il
-- obtient à chaque nuit (les autres joueurs prennent le reste). Taps : tape sur le tapis (+50 %).
-- Flanerie : temps réel passé par action utile (1,5 = un tiers du temps à autre chose). Malin : poids
-- donné au temps gagné quand il achète un niveau de machine (0 = n'achète que ce qui est bon marché).
Modele.Profils = {
	{ Id = "Prudent", Coups = 4, Vert = true, CasseMax = 0.95 * Balance.Window.BreakTimer, Part = 0.35, Taps = false, Flanerie = 1.5, Malin = 0.5 },
	{ Id = "Moyen", Coups = 6, Vert = false, CasseMax = 10, Part = 0.5, Taps = true, Flanerie = 1.25, Malin = 0.75 },
	{ Id = "Acharné", Coups = 9, Vert = false, CasseMax = 12.5, Part = 0.75, Taps = true, Flanerie = 1.05, Malin = 1 },
}

---------------------------------------------------------------------------------------------- économie actuelle

function Modele.EcoActuelle()
	local eco = { Nom = "Actuelle" }
	eco.Zones = {}
	for index, zone in Zones do
		eco.Zones[index] = {
			WindowHP = zone.WindowHP,
			AdvisedDamage = zone.AdvisedDamage,
			AdvisedSpeed = zone.AdvisedSpeed,
			GuardSpeed = zone.GuardSpeed,
			ReturnDistance = zone.ReturnDistance,
			BaseIncome = zone.BaseIncome,
			SpeedShown = zone.AdvisedSpeed, -- le panneau annonce un WalkSpeed
			StrengthShown = zone.AdvisedDamage, -- et les dégâts conseillés (L-108 point 5)
		}
	end
	eco.WalkSpeed = Formulas.WalkSpeed
	eco.HitDamage = Formulas.HitDamage
	function eco.MachineGain(kind, level)
		local base = if kind == "Treadmill" then Training.Treadmill.GainPerSecond else Training.Bench.GainPerRep
		return base * Formulas.MachineMultiplier(kind, level)
	end
	eco.UpgradeCost = Formulas.UpgradeCost
	eco.ItemIncome = Formulas.ItemIncome
	eco.Tools = Tools.List
	eco.Auras = Cosmetics.Auras
	eco.Trails = Cosmetics.Trails
	eco.DoorHP = Formulas.PlayerWindowHP
	eco.Glass = SkillTree.ById.GlassThickness.Effects
	eco.Walls = SkillTree.ById.Walls.Effects
	eco.Regen = SkillTree.ById.GlassRegen.Effects
	function eco.ShownSpeed(speed, _trail)
		return speed
	end
	function eco.ShownStrength(_power, strength, _aura)
		return strength
	end
	return eco
end

---------------------------------------------------------------------------------------------- règles communes

-- Temps de casse (s) d'une vitrine de `hp` PV : coups réguliers, régénération continue (Balance.Window).
function Modele.BreakTime(hp, damage, hitsPerSecond, regen)
	local net = hitsPerSecond * damage - (regen or Balance.Window.RegenPerSecond) * hp
	if net <= 0 then
		return math.huge
	end
	return hp / net
end

-- Fuite avec un colis PNJ : (chance de rentrer, durée du retour jusqu'à l'arche safe).
-- Durée de l'ouverture d'un colis sur le rayon pour cette chance : rabats, puis montée (Config/ShelfOpen,
-- L-118 point 4 : RiseMax × √(tics / tics de la plus forte chance)).
function Modele.OpenTime(luck)
	local ShelfOpen = Config.ShelfOpen
	local most = 1
	for _, entry in ShelfOpen.LuckTable do
		most = math.max(most, entry.Luck)
	end
	local rise = ShelfOpen.RiseMax * math.min(1, math.sqrt(math.log(luck) / math.log(most)))
	return ShelfOpen.FlapsTime + rise
end
function Modele.OpenTimeMean()
	local ShelfOpen = Config.ShelfOpen
	local total, weight = 0, 0
	for _, entry in ShelfOpen.LuckTable do
		total += entry.Weight * Modele.OpenTime(entry.Luck)
		weight += entry.Weight
	end
	return total / weight
end

function Modele.Escape(eco, zone, walk, gap)
	local H = Modele.Hypotheses
	local info = eco.Zones[zone]
	local carry = walk * Balance.Carry.NPCBoxSpeedMultiplier
	local back = info.ReturnDistance / carry
	if carry >= info.GuardSpeed then
		return 1, back
	end
	local caughtAfter = ((gap or H.GuardGap) + H.GuardReaction * carry) / (info.GuardSpeed - carry)
	if caughtAfter >= back then
		return 1, back
	end
	return H.LuckyEscape * caughtAfter / back, back
end

-- Plus petite valeur x ≥ 0 telle que ok(x), pour un critère croissant ; math.huge si jamais atteint.
local function smallest(ok)
	if ok(0) then
		return 0
	end
	local high = 1
	while not ok(high) do
		high *= 4
		if high > 1e30 then
			return math.huge
		end
	end
	local low = high / 4
	if low < 1 then
		low = 0
	end
	for _ = 1, 60 do
		local middle = (low + high) / 2
		if ok(middle) then
			high = middle
		else
			low = middle
		end
	end
	return high
end
Modele.Smallest = smallest

-- Kit d'entrée d'une zone : pour chaque famille, le premier article (du moins cher au plus cher) dont
-- les zones visées (TargetZones du doc, 7.2 et 7.4) couvrent cette zone. 0 = rien (zone 1, ou pas d'article).
local function kitIndex(list, zone)
	if zone <= 1 then
		return 0
	end
	for index, entry in list do
		if entry.TargetZones[1] <= zone and entry.TargetZones[2] >= zone and entry.Price > 0 then
			return index
		end
	end
	return 0
end
Modele.KitIndex = kitIndex

-- Espérance du multiplicateur de revenu des mutations (une taille et un effet tirés à part).
function Modele.MutationMean()
	local function family(list)
		local mean = 1
		for _, entry in list do
			mean += entry.Chance / 100 * (entry.IncomeMultiplier - 1)
		end
		return mean
	end
	return family(Mutations.Sizes) * family(Mutations.Effects)
end

-- Espérance du multiplicateur de rareté d'un colis de ce type dans cette zone.
function Modele.RarityMean(zone, tier)
	local mean = 0
	for rarityId, chance in ShelfBoxes.OddsFor(zone, tier) do
		mean += chance / 100 * Rarities.ById[rarityId].IncomeMultiplier
	end
	return mean
end

-- Générateur pseudo-aléatoire à graine (Park-Miller), le même sur toutes les machines.
local function generator(seed)
	local state = (seed * 7919) % 2147483646 + 1
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

local function rollWeighted(random, list, chanceOf, idOf)
	local roll = random() * 100
	for _, entry in list do
		local chance = chanceOf(entry)
		if roll < chance then
			return idOf(entry)
		end
		roll -= chance
	end
	return nil
end

---------------------------------------------------------------------------------------------- une partie

-- Fait jouer un joueur du profil donné jusqu'à son premier colis de zone 6 (ou maxSeconds).
-- Renvoie { Entrees[z] = { T, Vitesse, Force, Marche, Degats, Casse, Revenu, Tapis, Banc }, Achats = {…},
-- Temps = { Tapis, Banc, Braquage }, Colis, Rattrape, Fin }.
function Modele.Jouer(eco, profil, seed, maxSeconds)
	local H = Modele.Hypotheses
	local random = generator(seed)
	local zoneCount = #eco.Zones
	local mutationOf = function()
		local size = rollWeighted(random, Mutations.Sizes, function(e)
			return e.Chance
		end, function(e)
			return e.IncomeMultiplier
		end) or 1
		local effect = rollWeighted(random, Mutations.Effects, function(e)
			return e.Chance
		end, function(e)
			return e.IncomeMultiplier
		end) or 1
		return size * effect
	end

	local s = {
		t = 0,
		cash = 0,
		speed = 0,
		strength = 0,
		levels = { Treadmill = 0, Bench = 0, DisplaySlots = 0 },
		tool = 1, -- Tools.List[1] = poings
		aura = 0,
		trail = 0,
		stands = {}, -- revenus des objets exposés
		pending = {}, -- colis en attente d'ouverture : { Ready, Income }
		sales = 0, -- rythme moyen des ventes au receleur ($/s)
		zone = 1,
		cycle = -1,
		supply = {},
		boostUntil = 0, -- aides : fin du boost ×2 argent (temps de jeu)
	}
	local mutationMean = Modele.MutationMean()
	local out = { Entrees = {}, Achats = {}, Temps = { Tapis = 0, Banc = 0, Braquage = 0 }, Colis = 0, Rattrape = 0 }

	local function auraOf(index)
		return if index > 0 then eco.Auras[index].Multiplier else Cosmetics.NoneMultiplier
	end
	local function trailOf(index)
		return if index > 0 then eco.Trails[index].Multiplier else Cosmetics.NoneMultiplier
	end
	local function damage()
		return eco.HitDamage(eco.Tools[s.tool].Power, s.strength, auraOf(s.aura))
	end
	local function walk()
		return eco.WalkSpeed(s.speed, trailOf(s.trail))
	end
	local function standIncome()
		local total = 0
		for _, income in s.stands do
			total += income
		end
		return total
	end
	local function cashRate()
		return standIncome() + s.sales
	end
	local function speedRate()
		local rate = eco.MachineGain("Treadmill", s.levels.Treadmill)
		return if profil.Taps then rate * (1 + Training.Treadmill.TapBonus) else rate
	end
	local function strengthRate()
		if eco.SansBanc then
			return 1
		end
		return eco.MachineGain("Bench", s.levels.Bench) * math.min(H.BenchRepsPerSecond, Training.Bench.MaxRepsPerSecond)
	end

	-- Le temps passe : les présentoirs rapportent, la mémoire des ventes s'efface.
	local function advance(seconds, category)
		local real = seconds * profil.Flanerie
		s.cash += standIncome() * real * (if s.t < s.boostUntil then 2 else 1)
		s.t += real
		s.sales *= math.exp(-real / H.CashMemory)
		out.Temps[category] += real
	end
	local function sell(income)
		local price = Formulas.FenceValue(income)
		s.cash += price
		s.sales += price / H.CashMemory
	end
	local function slots()
		return math.min(Balance.Display.MaxSlots, Balance.Display.StartSlots + s.levels.DisplaySlots)
	end
	-- Un objet ouvert : exposé s'il reste un présentoir, sinon il remplace le moins bon (vendu au
	-- receleur), sinon il est vendu.
	local function place(income)
		if #s.stands < slots() then
			table.insert(s.stands, income)
			return
		end
		local worst, worstIndex = math.huge, 0
		for index, value in s.stands do
			if value < worst then
				worst, worstIndex = value, index
			end
		end
		if income > worst then
			s.stands[worstIndex] = income
			sell(worst)
		else
			sell(income)
		end
	end
	local function openReady()
		local index = 1
		while index <= #s.pending do
			local box = s.pending[index]
			if box.Ready <= s.t then
				table.remove(s.pending, index)
				place(box.Income)
			else
				index += 1
			end
		end
	end

	-- Coups par seconde sur la vitrine de cette zone, et temps de casse accepté : ceux du profil, ou ceux
	-- de l'équipe dans une zone d'équipe (TeamHits, chrono de casse entier).
	local function hitsIn(zone)
		return eco.Zones[zone].TeamHits or eco.MaxHits or profil.Coups
	end
	local function breakMax(zone)
		return if eco.Zones[zone].TeamHits then (eco.BreakTimer or Balance.Window.BreakTimer) else (eco.CasseMax or profil.CasseMax)
	end
	-- Critère d'entrée du profil dans une zone, avec ces dégâts et cette vitesse de marche.
	local function accepts(zone, hitDamage, walkSpeed)
		local info = eco.Zones[zone]
		local breakTime = Modele.BreakTime(info.WindowHP, hitDamage, hitsIn(zone))
		local chance = Modele.Escape(eco, zone, walkSpeed)
		if profil.Vert then
			-- Marge de 0,1 % : un seuil rond (« 3K ») retombe parfois un cheveu sous la valeur exacte.
			local green = hitDamage >= info.AdvisedDamage * 0.999 and walkSpeed >= info.AdvisedSpeed * 0.999
			return green and breakTime <= breakMax(zone) and chance >= 1, breakTime
		end
		return breakTime <= breakMax(zone) and chance >= 1, breakTime
	end

	-- Ce qu'il manque pour entrer dans la zone : Vitesse et Force à atteindre avec le kit prévu (celui
	-- qu'il a, ou le kit d'entrée de la zone s'il est meilleur) et prix des articles du kit à acheter.
	local needCache = {}
	local function needs(zone)
		local tool = math.max(s.tool, kitIndex(eco.Tools, zone))
		local aura = math.max(s.aura, kitIndex(eco.Auras, zone))
		local trail = math.max(s.trail, kitIndex(eco.Trails, zone))
		local key = `{zone}/{tool}/{aura}/{trail}`
		local stat = needCache[key]
		if stat == nil then
			local okDamage = eco.HitDamage(eco.Tools[tool].Power, 1e30, auraOf(aura))
			stat = {
				Speed = smallest(function(x)
					return (accepts(zone, okDamage, eco.WalkSpeed(x, trailOf(trail))))
				end),
				Strength = smallest(function(x)
					return (accepts(zone, eco.HitDamage(eco.Tools[tool].Power, x, auraOf(aura)), 1e30))
				end),
			}
			needCache[key] = stat
		end
		local cost = 0
		local kit = {}
		if tool > s.tool then
			cost += eco.Tools[tool].Price
			table.insert(kit, { Family = "tool", Index = tool, Entry = eco.Tools[tool] })
		end
		if aura > s.aura then
			cost += eco.Auras[aura].Price
			table.insert(kit, { Family = "aura", Index = aura, Entry = eco.Auras[aura] })
		end
		if trail > s.trail then
			cost += eco.Trails[trail].Price
			table.insert(kit, { Family = "trail", Index = trail, Entry = eco.Trails[trail] })
		end
		return stat.Speed, stat.Strength, cost, kit
	end

	local function refreshZone()
		local hitDamage, walkSpeed = damage(), walk()
		for zone = zoneCount, 2, -1 do
			if accepts(zone, hitDamage, walkSpeed) then
				s.zone = math.max(s.zone, zone)
				break
			end
		end
	end

	local function buy(kind, name, price, extra)
		s.cash -= price
		local rate = cashRate()
		table.insert(out.Achats, {
			Kind = kind,
			Name = name,
			T = s.t,
			Price = price,
			Minutes = if rate > 0 then price / rate / 60 else math.huge,
			Zone = s.zone,
			Extra = extra,
		})
	end

	-- Durée d'un braquage réussi dans cette zone, de sa boutique à sa boutique (sans la flânerie).
	local openMean = if eco.HeistDuration ~= nil then Modele.OpenTimeMean() else 0
	local function tripSeconds(zone, tier)
		local info = eco.Zones[zone]
		local walkSpeed = walk()
		local breakTime = Modele.BreakTime(info.WindowHP, damage(), hitsIn(zone))
		local _, back = Modele.Escape(eco, zone, walkSpeed)
		local outbound = (info.ReturnDistance + H.PlotDistance) / walkSpeed
		local inside = breakTime + H.InStore + Balance.Heist.BoxTiers[tier].GrabTime
		if eco.HeistDuration ~= nil then
			inside += openMean
		end
		return outbound + inside + back + H.PlotDistance / walkSpeed + H.Deposit, outbound, inside, back
	end
	-- Argent par seconde que le joueur attend d'un braquage dans sa zone : ses présentoirs, plus un
	-- colis Premium moyen revendu au receleur (ou qui chasse un objet revendu), par trajet.
	local function heistRate()
		local tier = "Premium"
		local item = eco.ItemIncome(s.zone, "Common") * Modele.RarityMean(s.zone, tier) * mutationMean
		return standIncome() + Formulas.FenceValue(item) / (tripSeconds(s.zone, tier) * profil.Flanerie)
	end
	-- Niveau suivant d'une machine : (prix, temps d'entraînement qu'il fait gagner d'ici la zone visée).
	local function machineCase(machine, needSpeed, needStrength)
		local level = s.levels[machine]
		local price = eco.UpgradeCost(machine, level)
		if price == nil then
			return nil, 0
		end
		local missing = if machine == "Treadmill" then math.max(0, needSpeed - s.speed) else math.max(0, needStrength - s.strength)
		if missing == math.huge then
			return price, 0
		end
		local rate = if machine == "Treadmill" then speedRate() else strengthRate()
		local gain = eco.MachineGain(machine, level + 1) / eco.MachineGain(machine, level)
		return price, missing / rate * profil.Flanerie * (1 - 1 / gain)
	end

	local function shop(target)
		local bought = true
		while bought do
			bought = false
			local rate = cashRate()
			-- 1. Kit d'entrée de la zone visée.
			if target ~= nil then
				local needSpeed, needStrength, _, kit = needs(target)
				for _, item in kit do
					if s.cash >= item.Entry.Price then
						buy("Kit", item.Entry.DisplayName, item.Entry.Price)
						s[item.Family] = item.Index
						bought = true
					end
				end
				-- 2. Niveaux de machine : bon marché, ou rentables (le temps de braquage qu'ils coûtent
				-- est plus court que le temps d'entraînement qu'ils font gagner).
				for _, machine in if eco.SansBanc then { "Treadmill" } else { "Treadmill", "Bench" } do
					local price, saved = machineCase(machine, needSpeed, needStrength)
					if price ~= nil and s.cash >= price then
						local cheap = rate > 0 and price / rate <= H.UpgradeBudget
						if cheap or price / heistRate() <= profil.Malin * saved then
							buy("Machine", `{machine} {s.levels[machine] + 1}`, price)
							s.levels[machine] += 1
							bought = true
						end
					end
				end
			end
			-- 3. Présentoir de plus, quand ils sont tous pris et qu'il se rembourse vite.
			local slotPrice = eco.UpgradeCost("DisplaySlots", s.levels.DisplaySlots)
			if slotPrice ~= nil and #s.stands >= slots() and s.cash >= slotPrice then
				local average = standIncome() / math.max(1, #s.stands)
				if slotPrice <= H.SlotPayback * average then
					buy("Presentoir", `Display {slots() + 1}`, slotPrice)
					s.levels.DisplaySlots += 1
					bought = true
				end
			end
			-- 4. Outil, aura ou trail suivant, hors kit, s'il ne coûte presque rien au vu des revenus.
			for _, family in { { "tool", eco.Tools }, { "aura", eco.Auras }, { "trail", eco.Trails } } do
				local nextEntry = family[2][s[family[1]] + 1]
				if nextEntry ~= nil and rate > 0 and s.cash >= nextEntry.Price and nextEntry.Price / rate <= H.UpgradeBudget then
					buy("Confort", nextEntry.DisplayName, nextEntry.Price)
					s[family[1]] += 1
					bought = true
				end
			end
		end
		refreshZone()
	end

	local function restock()
		for zone = 1, zoneCount do
			local stock = {}
			for tier, info in Balance.Heist.BoxTiers do
				local count = 0
				for _ = 1, info.Count * 2 do -- 2 magasins par zone
					if random() < profil.Part then
						count += 1
					end
				end
				stock[tier] = count
			end
			s.supply[zone] = stock
		end
	end
	local function pickTier(zone)
		local stock = s.supply[zone]
		for index = #Balance.Heist.TierOrder, 1, -1 do -- Luxe, puis Premium, puis Standard
			local tier = Balance.Heist.TierOrder[index]
			if stock[tier] > 0 then
				return tier
			end
		end
		return nil
	end

	local function train(wantSpeed, wantStrength)
		local leftSpeed = math.max(0, wantSpeed - s.speed) / speedRate()
		local leftStrength = math.max(0, wantStrength - s.strength) / strengthRate()
		if leftStrength > leftSpeed then
			local seconds = math.clamp(leftStrength, 1, H.TrainChunk)
			s.strength += strengthRate() * seconds
			advance(seconds, "Banc")
		else
			local seconds = math.clamp(if leftSpeed > 0 then leftSpeed else H.TrainChunk, 1, H.TrainChunk)
			s.speed += speedRate() * seconds
			if out.Plafond == nil and walk() >= Balance.Stats.MaxWalkSpeed then
				out.Plafond = s.t -- la vitesse de marche touche le plafond
			end
			advance(seconds, "Tapis")
		end
	end

	local function heist(zone, tier)
		local info = eco.Zones[zone]
		local walkSpeed = walk()
		local hitDamage = damage()
		local breakTime = Modele.BreakTime(info.WindowHP, hitDamage, hitsIn(zone))
		local chance = Modele.Escape(eco, zone, walkSpeed)
		local whole, outbound, inside, back = tripSeconds(zone, tier)
		if eco.HeistDuration ~= nil then
			-- Chrono du braquage : la chance de l'ouverture est tirée (Config/ShelfOpen.LuckTable) ; si la prise
			-- finit après le chrono, le vigile est sorti à la fin du chrono et a couru vers le joueur entre-temps.
			local roll, luck = random() * 100, 1
			for _, entry in Config.ShelfOpen.LuckTable do
				luck = entry.Luck
				if roll < entry.Weight then
					break
				end
				roll -= entry.Weight
			end
			local late = H.InStore + Modele.OpenTime(luck) + Balance.Heist.BoxTiers[tier].GrabTime - eco.HeistDuration
			if late > 0 then
				out.EnRetard = (out.EnRetard or 0) + 1
				chance = Modele.Escape(eco, zone, walkSpeed, math.max(0, H.GuardGap - late * info.GuardSpeed))
			end
		end
		if random() >= chance then
			out.Rattrape += 1
			advance(outbound + inside + back / 2 + H.CaughtLoss, "Braquage")
			return
		end
		advance(whole, "Braquage")
		s.supply[zone][tier] -= 1
		out.Colis += 1
		local rarityId
		local openDelay
		if out.Colis == 1 then
			-- Premier colis du tuto : rareté garantie, attente raccourcie (Config/Tutorial).
			rarityId, openDelay = Tutorial.GuaranteedRarity, Tutorial.OpenDelay
		else
			local roll = random() * 100
			for _, rarity in Rarities.List do
				local share = ShelfBoxes.OddsFor(zone, tier)[rarity.Id] or 0
				if roll < share then
					rarityId = rarity.Id
					break
				end
				roll -= share
			end
			rarityId = rarityId or "Common"
			openDelay = Rarities.ById[rarityId].OpenDelay
		end
		-- Accroche facultative (Outil/chance, section 12) : ouverture avec chance et crans. Absente : rien
		-- ne change (même tirage, mêmes résultats que les sections 6 à 11).
		if Modele.Ouverture ~= nil then
			local start = rarityId
			local final, wait, inStore, police = Modele.Ouverture(random, zone, tier, rarityId, out.Colis == 1)
			rarityId = final
			openDelay = if out.Colis == 1 then openDelay else wait
			if inStore > 0 then
				advance(inStore, "Braquage")
			end
			out.Ouvertures = (out.Ouvertures or 0) + 1
			out.ParZone = out.ParZone or {}
			out.ParZone[zone] = (out.ParZone[zone] or 0) + 1
			out.ParType = out.ParType or {}
			out.ParType[tier] = (out.ParType[tier] or 0) + 1
			out.Crans = (out.Crans or 0) + (Rarities.ById[final].Order - Rarities.ById[start].Order)
			out.Raretes = out.Raretes or {}
			out.Raretes[final] = (out.Raretes[final] or 0) + 1
			if police then
				out.Police = (out.Police or 0) + 1
				-- La police part au bout de la rue : traitée comme une seconde poursuite de vigile.
				if random() >= chance then
					out.Rattrape += 1
					advance(H.CaughtLoss, "Braquage")
					return
				end
			end
		end
		table.insert(s.pending, { Ready = s.t + openDelay, Income = eco.ItemIncome(zone, rarityId) * mutationOf() })
		if out.Entrees[zone] == nil then
			out.Entrees[zone] = {
				T = s.t,
				Vitesse = eco.ShownSpeed(s.speed, trailOf(s.trail)),
				Force = eco.ShownStrength(eco.Tools[s.tool].Power, s.strength, auraOf(s.aura)),
				Marche = walkSpeed,
				Degats = hitDamage,
				Casse = breakTime,
				Revenu = cashRate(),
				Tapis = s.levels.Treadmill,
				Banc = s.levels.Bench,
				Presentoirs = slots(),
				Outil = eco.Tools[s.tool].DisplayName,
				TempsTapis = out.Temps.Tapis,
				TempsBanc = out.Temps.Banc,
				TempsBraquage = out.Temps.Braquage,
			}
		end
	end

	-- Aides (Modele.Aides, nil = aucune ; ce sont des hypothèses de jeu, pas des valeurs du jeu) :
	--   Session   s de jeu par session ; SessionsParJour sessions par jour ;
	--   Offline   au début de chaque session après la première : Config/Offline (Rate × MaxHours h du
	--             revenu des présentoirs ; on suppose l'absence plus longue que le plafond) ;
	--   Daily     Config/Rewards : calendrier de 7 jours (un par jour) et paliers de temps de jeu du jour ;
	--   Truck     un camion toutes les TruckEvery s de jour, dans une zone au hasard ; s'il est dans une
	--             zone que le joueur braque déjà seul, il en rapporte TruckBoxes colis (un trajet sans casse chacun).
	local A = Modele.Aides
	local aid = { session = 0, day = 0, dayStart = 0, claimed = {}, truckAt = 0 }
	out.Aides = { Offline = 0, Cash = 0, Boites = 0, Boost = 0, Camions = 0 }
	local function rarityFrom(zone, tier, minOrder)
		local odds = ShelfBoxes.OddsFor(zone, tier)
		local total = 0
		for _, rarity in Rarities.List do
			if rarity.Order >= minOrder then
				total += odds[rarity.Id] or 0
			end
		end
		local roll = random() * total
		local picked = nil
		for _, rarity in Rarities.List do
			if rarity.Order >= minOrder then
				local share = odds[rarity.Id] or 0
				picked = picked or (if share > 0 then rarity.Id else nil)
				if roll < share then
					return rarity.Id
				end
				roll -= share
			end
		end
		return picked or "Common"
	end
	local function grant(reward)
		if reward.Kind == "Cash" then
			local rate = cashRate() * (if s.t < s.boostUntil then 2 else 1)
			local amount = math.max(rate * 60, Config.Rewards.MinCashPerMinute) * reward.Minutes
			s.cash += amount
			out.Aides.Cash += amount
		elseif reward.Kind == "Boost" then
			s.boostUntil = math.max(s.boostUntil, s.t) + reward.Minutes * 60
			out.Aides.Boost += reward.Minutes
		else
			local zone = math.max(s.zone, reward.MinZone or 1)
			local minOrder = if reward.MinRarity then Rarities.ById[reward.MinRarity].Order else 1
			place(eco.ItemIncome(zone, rarityFrom(zone, reward.Tier, minOrder)) * mutationOf())
			out.Aides.Boites += 1
		end
	end
	local function aides()
		local session = s.t // A.Session
		if session ~= aid.session then
			aid.session = session
			if A.Offline then
				local amount = Config.Offline.Rate * Config.Offline.MaxHours * 3600 * standIncome()
				s.cash += amount
				out.Aides.Offline += amount
			end
			if session % A.SessionsParJour == 0 then
				aid.day += 1
				aid.dayStart = s.t
				aid.claimed = {}
			end
		end
		if A.Daily then
			if not aid.claimed.Daily then
				aid.claimed.Daily = true
				grant(Config.Rewards.Daily[aid.day % #Config.Rewards.Daily + 1])
			end
			for _, tier in Config.Rewards.Playtime do
				if not aid.claimed[tier.Minutes] and s.t - aid.dayStart >= tier.Minutes * 60 then
					aid.claimed[tier.Minutes] = true
					grant(tier.Reward)
				end
			end
		end
		if A.Truck and s.t - aid.truckAt >= A.TruckEvery and s.t % Night.CycleDuration < Night.DayDuration then
			aid.truckAt = s.t
			local zone = math.floor(random() * zoneCount) + 1
			if zone <= s.zone and eco.Zones[zone].TeamHits == nil then
				out.Aides.Camions += 1
				for _ = 1, A.TruckBoxes do
					local roll = random() * 12
					local tier = if roll < 6 then "Standard" elseif roll < 10 then "Premium" else "Luxe"
					local info = eco.Zones[zone]
					advance((2 * (info.ReturnDistance + H.PlotDistance)) / walk() + H.Deposit, "Braquage")
					place(eco.ItemIncome(zone, rarityFrom(zone, tier, 1)) * mutationOf())
				end
			end
		end
	end

	while s.t < maxSeconds and out.Entrees[zoneCount] == nil do
		if A ~= nil then
			aides()
		end
		local cycle = s.t // Night.CycleDuration
		if cycle ~= s.cycle then
			s.cycle = cycle
			restock() -- les rayons se remplissent à la nuit (5.12)
		end
		openReady()
		local target = if s.zone < zoneCount then s.zone + 1 else nil
		shop(target)
		target = if s.zone < zoneCount then s.zone + 1 else nil

		-- Où braquer : sa meilleure zone, sinon celle d'en dessous, s'il y reste des colis pour lui.
		local isDay = s.t % Night.CycleDuration < Night.DayDuration
		local heistZone, heistTier = nil, nil
		if isDay then
			for zone = s.zone, math.max(1, s.zone - 1), -1 do
				local tier = pickTier(zone)
				if tier ~= nil then
					heistZone, heistTier = zone, tier
					break
				end
			end
		end

		if target == nil then
			if heistZone ~= nil then
				heist(heistZone, heistTier)
			else
				train(math.huge, 0)
			end
		else
			local needSpeed, needStrength, cost = needs(target)
			if needSpeed == math.huge or needStrength == math.huge then
				out.Bloque = target -- zone inatteignable avec cette économie (plafond de vitesse)
				if out.Entrees[s.zone] ~= nil then
					break
				end
				-- Entré dans sa zone sans y avoir encore rapporté de colis : il y braque d'abord (son entrée compte).
				if heistZone ~= nil then
					heist(heistZone, heistTier)
				else
					train(math.huge, 0)
				end
				continue
			end
			local trainTime = math.max(0, needSpeed - s.speed) / speedRate() + math.max(0, needStrength - s.strength) / strengthRate()
			local rate = cashRate()
			local cashTime = if cost <= s.cash then 0 elseif rate > 0 then (cost - s.cash) / rate else math.huge
			-- L'entraînement est le plus long : vaut-il mieux aller gagner d'abord le niveau suivant de la machine ?
			local earnFirst = false
			if heistZone ~= nil and trainTime > cashTime then
				local leftSpeed = math.max(0, needSpeed - s.speed) / speedRate()
				local leftStrength = math.max(0, needStrength - s.strength) / strengthRate()
				local price, saved = machineCase(if leftStrength > leftSpeed then "Bench" else "Treadmill", needSpeed, needStrength)
				if price ~= nil and price > s.cash then
					earnFirst = (price - s.cash) / heistRate() < profil.Malin * saved
				end
			end
			if heistZone ~= nil and (trainTime <= cashTime or earnFirst) then
				heist(heistZone, heistTier)
			elseif trainTime > 0 then
				train(needSpeed, needStrength)
			elseif heistZone ~= nil then
				heist(heistZone, heistTier)
			else
				-- Rien à braquer (nuit, rayons vides) et stats prêtes : il prend de l'avance pour la zone d'après.
				local after = math.min(zoneCount, target + 1)
				local nextSpeed, nextStrength = needs(after)
				train(if nextSpeed == math.huge then s.speed else nextSpeed, if nextStrength == math.huge then s.strength else nextStrength)
			end
		end
	end
	out.Fin = s.t
	out.Etat = s
	return out
end

return Modele
