--!nocheck
-- Rapport de l'économie « B/T » (a479, 25/11) : bash tools/ironix/equilibrage/bt.sh
--   COURT=1 : seulement les temps par zone et l'état aux entrées (pour régler Outil/valeurs_bt).
-- Sections : 1 temps par zone ; 2 valeurs (aujourd'hui → proposé, avec le calcul) ; 3 jours de calendrier ;
-- 4 la chance (parts, sources, tables d'essai) ; 5 grands nombres ; 6 conversion des profils.

local BT = charge("Outil/economie_bt")
local Sim = charge("Outil/simulateur_bt")

local Balance, Zones, Rarities, Items = Config.Balance, Config.Zones, Config.Rarities, Config.Items
local ShelfOpen, Mutations, Weight = Config.ShelfOpen, Config.Mutations, Config.Weight
local ItemWeight = charge("ItemWeight")

local seeds = OPTIONS.Graines

---------------------------------------------------------------------------------------------- écriture

local function duree(seconds)
	if seconds == nil then
		return "—"
	end
	if seconds < 60 then
		return string.format("%.0f s", seconds)
	end
	local minutes = math.floor(seconds / 60 + 0.5)
	if minutes < 60 then
		return `{minutes} min`
	end
	if minutes < 100 * 60 then
		return string.format("%d h %02d", minutes // 60, minutes % 60)
	end
	return string.format("%d h", math.floor(minutes / 60 + 0.5))
end
local function ligne(cells)
	print("| " .. table.concat(cells, " | ") .. " |")
end
local function entete(cells)
	ligne(cells)
	local dashes = {}
	for index = 1, #cells do
		dashes[index] = "---"
	end
	ligne(dashes)
end
local function titre(text)
	print("")
	print("### " .. text)
	print("")
end
local function mediane(list)
	if #list == 0 then
		return nil
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[(#sorted + 1) // 2], sorted[1], sorted[#sorted]
end
local function nombre(value)
	return Format.short(value)
end
local function fois(value)
	if value >= 100 then
		return string.format("× %.0f", value)
	elseif value >= 10 then
		return string.format("× %.1f", value)
	end
	return string.format("× %.2f", value)
end
local function pct(value)
	if value >= 10 then
		return string.format("%.0f %%", value)
	elseif value >= 1 then
		return string.format("%.1f %%", value)
	elseif value >= 0.1 then
		return string.format("%.2f %%", value)
	end
	return string.format("%.3f %%", value)
end

---------------------------------------------------------------------------------------------- profils

-- Le tapis du robot : il tape tout le temps (+50 %) et prend toutes les bulles (une toutes les 5 s, ×3,05 en moyenne).
local robotGain = Sim.GainOf(1, 1)
local P = {}
-- Le joueur moyen de référence joue 1 h 30 par jour en deux sessions de 45 min et touche ses gains hors ligne
-- (Config/Offline : 100 % du revenu, MaxHours heures comptées par absence).
local SESSION = { Length = 2700, PerDay = 2, Cap = Config.Offline.MaxHours }
P.RobotBest = { Id = "Robot chanceux : le meilleur objet à chaque magasin", Gain = robotGain, Flanerie = 1, Mode = "Best", Panneau = false, Part = 1, HeistShare = 0, BoundShare = 0 }
P.RobotAbsolu = { Id = "Robot, chance absolue : en plus Rainbow, 10 000 kg et bulles ×20 à chaque fois", Gain = Sim.GainOf(1, 1, 20), Flanerie = 1, Mode = "Best", Mutation = 100, Panneau = false, Part = 1, HeistShare = 0, BoundShare = 0 }
P.RobotTable10 = { Id = "Robot, chance de boîte ×10 à chaque colis (tirage réel)", Gain = robotGain, Flanerie = 1, Mode = "Draw", Table = 10, Panneau = false, Part = 1, HeistShare = 0.15, BoundShare = 0.6 }
P.RobotNormal = { Id = "Robot sans chance particulière (table de chance normale)", Gain = robotGain, Flanerie = 1, Mode = "Draw", Panneau = false, Part = 1, HeistShare = 0.15, BoundShare = 0.6 }
P.Moyen = { Id = "Joueur moyen (1 h 30 par jour en deux sessions, absences payées)", Gain = Sim.GainOf(0.6, 0.5), Flanerie = 1.25, Mode = "Draw", Panneau = true, Part = 0.5, Caught = 0.08, Trip = 1.2, HeistShare = 0.25, BoundShare = 0.4, Session = SESSION }
P.MoyenContinu = { Id = "Joueur moyen qui ne quitte jamais le jeu (aucun gain hors ligne)", Gain = Sim.GainOf(0.6, 0.5), Flanerie = 1.25, Mode = "Draw", Panneau = true, Part = 0.5, Caught = 0.08, Trip = 1.2, HeistShare = 0.25, BoundShare = 0.4 }
P.Passif = { Id = "Joueur passif (ne tape pas, ne prend aucune bulle ; mêmes sessions)", Gain = 1, Flanerie = 1.25, Mode = "Draw", Panneau = true, Part = 0.5, Caught = 0.08, Trip = 1.2, HeistShare = 0.25, BoundShare = 0.4, Session = SESSION }

local function avec(profil, changes)
	local copy = table.clone(profil)
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

local function jouer(economy, profil, count, hours)
	local runs = {}
	for seed = 1, (if profil.Mode == "Best" then 1 else count) do
		table.insert(runs, Sim.Jouer(economy, profil, seed, (hours or 3000) * 3600))
	end
	return runs
end
local function champ(runs, zone, field)
	local list = {}
	for _, run in runs do
		if run.Entrees[zone] then
			table.insert(list, run.Entrees[zone][field or "T"])
		end
	end
	return list
end
local function celluleTemps(runs, zone, court)
	local list = champ(runs, zone)
	local m, lo, hi = mediane(list)
	if m == nil then
		return "jamais"
	end
	local text = if #runs > 1 and not court then `{duree(m)} ({duree(lo)} à {duree(hi)})` else duree(m)
	return if #list < #runs then `{#list}/{#runs} : {text}` else text
end
local function celluleJours(runs, profil)
	if not profil.Session then
		return "sans arrêt"
	end
	local m = mediane(champ(runs, 6, "Jours"))
	return if m then string.format("%.1f j", m) else "jamais"
end
local function partieMediane(runs)
	local sorted = table.clone(runs)
	table.sort(sorted, function(a, b)
		return a.Fin < b.Fin
	end)
	return sorted[(#sorted + 1) // 2]
end

local eco = BT.Construire()
local actuelle = BT.Actuelle()

-- « Optimise tout » : le robot à tirage réel essaie plusieurs partages du temps de jour entre braquage et tapis,
-- et garde le plus rapide (médiane de 9 parties).
local function optimise(profil)
	local bestShares, bestTime = nil, math.huge
	for _, heistShare in { 0.03, 0.08, 0.15, 0.3, 0.5 } do
		for _, boundShare in { 0.3, 0.6, 0.9 } do
			local essai = avec(profil, { HeistShare = heistShare, BoundShare = boundShare })
			local m = mediane(champ(jouer(eco, essai, 9), 6))
			if m ~= nil and m < bestTime then
				bestTime, bestShares = m, { heistShare, boundShare }
			end
		end
	end
	if bestShares then
		profil.HeistShare, profil.BoundShare = bestShares[1], bestShares[2]
	end
	return bestShares
end
optimise(P.RobotNormal)
optimise(P.RobotTable10)

---------------------------------------------------------------------------------------------- 1. temps par zone

print(`Économie B/T : {seeds} parties par profil tiré au hasard (médiane, puis de la plus courte à la plus longue).`)
print(`Tapis du robot : × {string.format("%.2f", robotGain)} (taps × bulles) ; du joueur moyen : × {string.format("%.2f", P.Moyen.Gain)} ; temps perdu du joueur moyen : × {P.Moyen.Flanerie}.`)
print(`Partage du temps de jour du robot à tirage réel (braquage / tapis), trouvé par essais : {P.RobotNormal.HeistShare} en temps normal, {P.RobotNormal.BoundShare} quand l'argent manque.`)
titre("1. Temps de jeu pour entrer dans chaque zone (économie proposée)")
entete({ "Profil", "Zone 2", "Zone 3", "Zone 4", "Zone 5", "Zone 6", "Zone 6, en jours" })
local kept = {}
for _, profil in { P.Moyen, P.MoyenContinu, P.Passif, P.RobotBest, P.RobotTable10, P.RobotNormal, P.RobotAbsolu } do
	local runs = jouer(eco, profil, seeds)
	kept[profil] = runs
	local cells = { profil.Id }
	for zone = 2, 6 do
		table.insert(cells, celluleTemps(runs, zone))
	end
	table.insert(cells, celluleJours(runs, profil))
	ligne(cells)
end
for _, profil in { P.Moyen, P.RobotBest, P.RobotNormal } do
	titre(`{profil.Id} : état à l'entrée de chaque zone (partie médiane)`)
	entete({ "Zone", "Temps", "Speed", "Tapis", "Présentoirs", "Revenu", "Dépensé", "Braquages", "Argent en poche" })
	local run = partieMediane(kept[profil])
	for zone = 1, 6 do
		local e = run.Entrees[zone]
		if e then
			ligne({ tostring(zone), duree(e.T), nombre(e.Speed), tostring(e.Tapis), tostring(e.Presentoirs), Format.income(e.Revenu), Format.money(e.Depense), tostring(e.Braquages), Format.money(e.Argent) })
		end
	end
	print("")
	local parts = {}
	for _, achat in run.Achats do
		table.insert(parts, `{achat.Name} {Format.money(achat.Price)} à {duree(achat.T)}`)
	end
	print("Achats : " .. table.concat(parts, " ; "))
end
titre("Joueur moyen, par zone (partie médiane) : durée, gains, dépenses, attente d'argent")
entete({ "Zone", "Durée dans la zone", "Gagné en jouant", "Gagné hors ligne (toute la partie)", "Revenu moyen en jeu", "Dépensé", "Temps où l'argent manque", "Braquages" })
do
	local run = partieMediane(kept[P.Moyen])
	for zone = 1, 5 do
		local z = run.Zones[zone]
		ligne({ tostring(zone), duree(z.Duree), Format.money(z.Gagne), if zone == 5 then Format.money(run.Etat.offline) else "", Format.income(z.Gagne / math.max(z.Duree, 1)), Format.money(z.Depense), pct(100 * z.Attente / math.max(z.Duree, 1)), tostring(z.Braquages) })
	end
end

-- Hors ligne (décision de Cantin, 25/11) : une absence complète ne doit pas rapporter plus que le prix du niveau
-- suivant du tapis. Mesuré sur le joueur moyen : son revenu au moment où il achète chaque niveau.
local ABSENCE = if (OPTIONS.Absence or 0) > 0 then OPTIONS.Absence else (BT.AbsenceHours or 5)
local function achatsDe(runs, name)
	local times, incomes = {}, {}
	for _, run in runs do
		for _, achat in run.Achats do
			if achat.Name == name then
				table.insert(times, achat.T)
				table.insert(incomes, achat.Income)
			end
		end
	end
	return (mediane(times)), (mediane(incomes)), #times
end
-- Hors ligne : à chaque retour d'absence du joueur moyen, son gain d'une absence complète (ABSENCE heures) contre le
-- prix du niveau suivant du tapis. centile(liste, q) : valeur au rang q (0 à 1).
local function centile(list, q)
	if #list == 0 then
		return nil
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.clamp(math.ceil(q * #sorted), 1, #sorted)]
end
-- Revenus du joueur moyen à ses retours d'absence pendant que le niveau `level` (affiché) est le suivant.
local function absencesAvant(runs, level)
	local incomes = {}
	for _, run in runs do
		for _, absence in run.Absences do
			if absence.Level + 2 == level then
				table.insert(incomes, absence.Income)
			end
		end
	end
	return incomes
end
-- Part des retours d'absence où le gain d'une absence complète dépasse le prix du niveau suivant (niveaux 9 à 20).
local function depassements(runs)
	local over, total = 0, 0
	for _, run in runs do
		for _, absence in run.Absences do
			if absence.Next ~= nil and absence.Level + 2 >= 9 then
				total += 1
				if absence.Income * ABSENCE * 3600 > absence.Next then
					over += 1
				end
			end
		end
	end
	return if total > 0 then over / total else 0, total
end

-- ESSAI=tapis : cherche les prix des niveaux du tapis (de LIBRE au dernier) tels que le prix du niveau suivant vaille
-- l'absence complète du joueur moyen au centile RATIO de ses retours (point fixe amorti), et les imprime.
--   SPEED6 : Speed de la zone 6 ; FIXE5=1 : les zones 2 à 5 gardent leur Speed (sinon suite régulière jusqu'à SPEED6) ;
--   NIVEAUX : nombre de niveaux du tapis (20 par défaut ; 25 : préparation de la question 10, × 2 par niveau).
if OPTIONS.Essai == "tapis" then
	local q = tonumber(OPTIONS.Rapport2) or 0.8
	local levels = math.max(OPTIONS.Niveaux or 0, #eco.TreadCost + 1)
	local speeds, statsLast = nil, nil
	if (OPTIONS.Speed6 or 0) > 0 then
		speeds = { 0 }
		if OPTIONS.Fixe5 == 1 then
			for zone = 2, 5 do
				speeds[zone] = BT.SpeedRequired[zone]
			end
			speeds[6] = OPTIONS.Speed6
			statsLast = 5
		else
			local ratio = (OPTIONS.Speed6 / BT.SpeedRequired[2]) ^ (1 / 4)
			for zone = 2, 6 do
				speeds[zone] = if zone == 6 then OPTIONS.Speed6 else BT.Round2(BT.SpeedRequired[2] * ratio ^ (zone - 2))
			end
		end
	end
	local prices = {}
	for index = 1, #eco.TreadCost do
		prices[index] = eco.TreadCost[index]
	end
	for index = #eco.TreadCost + 1, levels - 1 do
		prices[index] = BT.Round2(prices[index - 1] * 2)
	end
	local essai, runs
	for pass = 1, (OPTIONS.Passes or 10) do
		essai = BT.Construire({ TreadPrices = prices, TreadLevels = levels, SpeedRequired = speeds, StatsLast = statsLast })
		runs = jouer(essai, P.Moyen, math.min(seeds, 21))
		local parts = {}
		for level = (OPTIONS.Libre or 9), levels do
			local incomes = absencesAvant(runs, level)
			local income = centile(incomes, q)
			if income then
				local target = income * ABSENCE * 3600
				-- Jamais moins cher que le niveau d'avant × 1,5 : les prix montent toujours.
				prices[level - 1] = math.max(BT.Round2(math.sqrt(prices[level - 1] * target)), BT.Round2(prices[level - 2] * 1.5))
			end
			table.insert(parts, `\{ "abs", {string.format("%g", prices[level - 1])}, {string.format("%g", BT.Round2(income or 0))} \}`)
		end
		local share = depassements(runs)
		print(`passe {pass} : zone 5 {celluleTemps(runs, 5, true)}, zone 6 {celluleTemps(runs, 6, true)}, {celluleJours(runs, P.Moyen)}, absences au-dessus du prix {pct(100 * share)} ; ` .. table.concat(parts, ", "))
	end
	if (OPTIONS.Niveaux or 0) > 20 then
		-- Préparation des niveaux 21 et suivants : tableau des niveaux, temps des joueurs, fin de la zone 5.
		essai = BT.Construire({ TreadPrices = prices, TreadLevels = levels, SpeedRequired = speeds, StatsLast = statsLast })
		local count = math.min(seeds, 41)
		local moyen = jouer(essai, P.Moyen, count)
		titre(`Préparation : tapis à {levels} niveaux, zone 6 à Speed {nombre(essai.Speed[6])} (zones 2 à 5 : {nombre(essai.Speed[2])}, {nombre(essai.Speed[3])}, {nombre(essai.Speed[4])}, {nombre(essai.Speed[5])})`)
		entete({ "Profil", "Zone 5", "Zone 6", "Zone 6, en jours" })
		for _, profil in { P.Moyen, P.MoyenContinu, P.RobotBest, P.RobotTable10, P.RobotNormal } do
			local played = if profil == P.Moyen then moyen else jouer(essai, profil, count)
			ligne({ profil.Id, celluleTemps(played, 5), celluleTemps(played, 6), celluleJours(played, profil) })
		end
		print("")
		entete({ "Niveau du tapis", "Valeur d'une apparition", "Gain par seconde", "Prix", "Acheté par le joueur moyen à (médiane)", "Son revenu aux retours d'absence (médiane)", "Prix ÷ absence complète", "Retours où l'absence dépasse le prix" })
		for level = 17, levels do
			local t, _, bought = achatsDe(moyen, `Tapis {level}`)
			local incomes = absencesAvant(moyen, level)
			local over = 0
			for _, income in incomes do
				if income * ABSENCE * 3600 > essai.TreadCost[level - 1] then
					over += 1
				end
			end
			local median = mediane(incomes)
			ligne({
				tostring(level),
				nombre(BT.Tapis.GainPerTick * BT.Tapis.GainGrowth ^ (level - 1)),
				nombre(essai.Gain(level - 1)),
				Format.money(essai.TreadCost[level - 1]),
				if t then duree(t) .. (if bought < #moyen then ` ({bought}/{#moyen} parties)` else "") else "jamais acheté",
				if median then Format.income(median) else "—",
				if median then string.format("%.2f", essai.TreadCost[level - 1] / (median * ABSENCE * 3600)) else "—",
				if #incomes > 0 then pct(100 * over / #incomes) else "—",
			})
		end
		local fromLast, cash = {}, {}
		for _, run in moyen do
			local entry = run.Entrees[6]
			if entry then
				local last = 0
				for _, achat in run.Achats do
					if achat.Kind == "Tapis" or achat.Kind == "Trail" then
						last = math.max(last, achat.T)
					end
				end
				table.insert(fromLast, entry.T - last)
				table.insert(cash, entry.Argent)
			end
		end
		print("")
		print(`Fin de la zone 5, joueur moyen : du dernier achat de vitesse à la zone 6, {duree(mediane(fromLast))} de jeu ; argent en poche à l'arrivée, {Format.money(mediane(cash) or 0)}. Absences au-dessus du prix du niveau suivant : {pct(100 * depassements(moyen))} des retours.`)
		local scale = Balance.Stats.RealSpeedScale
		print(`Marche au panneau de la zone 6 : {string.format("%.1f", Sim.Walk(essai, essai.Speed[6]) / scale)} à l'échelle 1 (zone 5 : {string.format("%.1f", Sim.Walk(essai, essai.Speed[5]) / scale)}).`)
	end
	return
end
local LAST_LEVEL = #eco.TreadCost + 1
titre(`1.1 Hors ligne et prix du tapis : à chaque retour d'absence du joueur moyen, une absence complète ({ABSENCE} h, arbre compris) contre le prix du niveau suivant`)
entete({ "Niveau du tapis", "Prix", "Acheté à (médiane)", "Retours d'absence par partie pendant qu'il est le suivant", "Revenu du joueur moyen à ces retours (médiane)", `Absence de {ABSENCE} h à ce revenu`, "Prix ÷ cette absence", "Retours où l'absence complète dépasse le prix" })
for level = 2, LAST_LEVEL do
	local runs = kept[P.Moyen]
	local t, _, count = achatsDe(runs, `Tapis {level}`)
	local incomes = absencesAvant(runs, level)
	local over = 0
	for _, income in incomes do
		if income * ABSENCE * 3600 > eco.TreadCost[level - 1] then
			over += 1
		end
	end
	local median = mediane(incomes)
	ligne({
		tostring(level),
		Format.money(eco.TreadCost[level - 1]),
		if t then duree(t) .. (if count < #runs then ` ({count}/{#runs} parties)` else "") else "jamais acheté",
		string.format("%.1f", #incomes / #runs),
		if median then Format.income(median) else "—",
		if median then Format.money(median * ABSENCE * 3600) else "—",
		if median then string.format("%.2f", eco.TreadCost[level - 1] / (median * ABSENCE * 3600)) else "—",
		if #incomes > 0 then pct(100 * over / #incomes) else "—",
	})
end

titre(`1.1 bis Une absence complète ({ABSENCE} h) du joueur moyen, zone par zone : ce qu'elle paie en niveaux du tapis`)
entete({ "Zone où il est à son retour", "Retours d'absence par partie", "Son revenu (médiane)", `Absence de {Config.Offline.MaxHours} h`, `Absence de {ABSENCE} h`, "Prix du niveau suivant (médiane)", "Niveaux du tapis payés d'un coup (médiane, puis le plus)", "Retours où elle paie au moins le niveau suivant" })
for zone = 2, 5 do
	local incomes, nexts, paid = {}, {}, {}
	local over, total = 0, 0
	for _, run in kept[P.Moyen] do
		for _, absence in run.Absences do
			if absence.Zone == zone and absence.Next ~= nil then
				total += 1
				local gain = absence.Income * ABSENCE * 3600
				table.insert(incomes, absence.Income)
				table.insert(nexts, absence.Next)
				-- Niveaux consécutifs que ce gain paie d'un coup, à partir du niveau suivant.
				local count, left = 0, gain
				for index = absence.Level + 1, #eco.TreadCost do
					if left < eco.TreadCost[index] then
						break
					end
					left -= eco.TreadCost[index]
					count += 1
				end
				table.insert(paid, count)
				if count >= 1 then
					over += 1
				end
			end
		end
	end
	if total > 0 then
		local medianIncome = mediane(incomes)
		local medianPaid, _, mostPaid = mediane(paid)
		ligne({ tostring(zone), string.format("%.1f", total / #kept[P.Moyen]), Format.income(medianIncome), Format.money(medianIncome * Config.Offline.MaxHours * 3600), Format.money(medianIncome * ABSENCE * 3600), Format.money(mediane(nexts)), `{medianPaid}, {mostPaid}`, pct(100 * over / total) })
	else
		ligne({ tostring(zone), "0", "—", "—", "—", "—", "—", "—" })
	end
end
do
	local share, total = depassements(kept[P.Moyen])
	print("")
	print(`Sur tous les retours d'absence du joueur moyen (niveaux 9 à {LAST_LEVEL}, {total} retours) : l'absence complète de {ABSENCE} h dépasse le prix du niveau suivant {pct(100 * share)} des fois.`)
	-- Fin de la zone 5 : du dernier niveau du tapis, puis du dernier achat de vitesse, à l'entrée en zone 6.
	local fromLevel, fromLast, cash = {}, {}, {}
	for _, run in kept[P.Moyen] do
		local entry = run.Entrees[6]
		if entry then
			local lastLevel, last = nil, 0
			for _, achat in run.Achats do
				if achat.Name == `Tapis {LAST_LEVEL}` then
					lastLevel = achat.T
				end
				if achat.Kind == "Tapis" or achat.Kind == "Trail" then
					last = math.max(last, achat.T)
				end
			end
			if lastLevel then
				table.insert(fromLevel, entry.T - lastLevel)
			end
			table.insert(fromLast, entry.T - last)
			table.insert(cash, entry.Argent)
		end
	end
	print(`Fin de la zone 5, joueur moyen : du niveau {LAST_LEVEL} du tapis à la zone 6, {duree(mediane(fromLevel))} de jeu ({#fromLevel}/{#kept[P.Moyen]} parties ont le niveau {LAST_LEVEL}) ; du dernier achat de vitesse (niveau du tapis ou trail) à la zone 6, {duree(mediane(fromLast))} de jeu ; argent en poche à l'arrivée, {Format.money(mediane(cash) or 0)}.`)
end
if OPTIONS.Court then
	return
end

titre("1.2 Le réglage de la durée : la Speed de la zone 6 (les zones 2 à 5 ne bougent pas)")
entete({ "Speed de la zone 6", "Marche au panneau de la zone 6 (échelle 1)", "Joueur moyen : zone 6", "Robot chanceux : zone 6", "Robot sans chance : zone 6" })
for _, top in { 10e12, 20e12, 30e12, 40e12, 60e12 } do
	local speeds = table.clone(BT.SpeedRequired)
	speeds[6] = top
	local essai = BT.Construire({ SpeedRequired = speeds })
	ligne({ nombre(top), string.format("%.1f", Sim.Walk(essai, top) / Balance.Stats.RealSpeedScale), celluleTemps(jouer(essai, P.Moyen, 11), 6, true), celluleTemps(jouer(essai, P.RobotBest, 1), 6, true), celluleTemps(jouer(essai, P.RobotNormal, 11), 6, true) })
end

titre("1.3 Avec les gamepasses du tapis (L-351 : ×2 Speed et ×4 Training ne se cumulent plus, le plus haut compte ; ×2 Cash sur les revenus)")
entete({ "Profil", "Sans gamepass", "×2 Speed seul (tapis ×2)", "×4 Training, avec ou sans ×2 Speed (tapis ×4)", "×4 Training et ×2 Cash" })
for _, profil in { P.Moyen, P.RobotBest, P.RobotNormal } do
	local cells = { profil.Id }
	for _, pass in { { 1, 1 }, { 2, 1 }, { 4, 1 }, { 4, 2 } } do
		table.insert(cells, celluleTemps(jouer(eco, avec(profil, { Gain = profil.Gain * pass[1], Income = pass[2] }), 11), 6, true))
	end
	ligne(cells)
end

titre("L'économie d'aujourd'hui avec les mêmes joueurs simulés (pour comparer)")
entete({ "Profil", "Zone 2", "Zone 3", "Zone 4", "Zone 5", "Zone 6" })
for _, profil in { P.Moyen, P.MoyenContinu, P.RobotBest, P.RobotNormal } do
	local runs = jouer(actuelle, profil, seeds)
	local cells = { profil.Id }
	for zone = 2, 6 do
		table.insert(cells, celluleTemps(runs, zone))
	end
	ligne(cells)
end

---------------------------------------------------------------------------------------------- 2. valeurs

titre("2.1 $/s par rareté (Config/Rarities, Income)")
entete({ "Rareté", "Aujourd'hui", "Proposé", "Facteur", "Marche depuis la rareté d'avant" })
do
	local previous = nil
	for _, rarity in Rarities.List do
		local new = BT.Income[rarity.Id]
		ligne({ rarity.Id, nombre(rarity.Income), nombre(new), fois(new / rarity.Income), if previous then fois(new / previous) else "—" })
		previous = new
	end
end

-- Revenu moyen d'un objet d'une rareté dans une zone (pondéré par DrawWeight), sans mutation ni poids.
local function meanIncome(economy, zone, rarityId)
	local pool = Items.AllZones[rarityId] or (Items.ByZone[zone] or {})[rarityId] or {}
	local total, weight = 0, 0
	for _, item in pool do
		total += item.DrawWeight * Sim.ItemIncome(economy, item)
		weight += item.DrawWeight
	end
	return if weight > 0 then total / weight else 0
end
local effectMean = 1
for _, effect in Mutations.Effects do
	effectMean += effect.Chance / 100 * (effect.IncomeMultiplier - 1)
end
-- Espérance du facteur de poids (kg / 10)^(1/3) à cette chance (log-uniforme dans chaque palier).
local function weightMean(luck)
	local chances = ItemWeight.TierChances(luck)
	local total = 0
	local p = Weight.IncomeExponent
	for index, tier in Weight.Tiers do
		local value
		if tier.Max <= tier.Min then
			value = (tier.Min / Weight.Reference) ^ p
		else
			local a, b = tier.Min / Weight.Reference, tier.Max / Weight.Reference
			value = (b ^ p - a ^ p) / (p * math.log(b / a))
		end
		total += chances[index] / 100 * value
	end
	return total
end
-- Revenu moyen de l'objet d'un braquage dans la zone à cette chance (mutation d'effet et poids compris).
local function heistValue(economy, zone, luck)
	local total = 0
	for rarityId, share in Sim.Shares(zone, luck) do
		total += share * meanIncome(economy, zone, rarityId)
	end
	return total * effectMean * weightMean(luck)
end
local function tableMean(fn)
	local total, weight = 0, 0
	for _, entry in (Sim.LuckTable or ShelfOpen.LuckTable) do
		total += entry.Weight * fn(entry.Luck)
		weight += entry.Weight
	end
	return total / weight
end

titre("2.2 Objets par zone : le meilleur objet et l'objet moyen d'un braquage")
entete({ "Zone", "Rareté la plus haute", "Sa part des braquages", "Meilleur objet aujourd'hui", "Meilleur objet proposé", "Objet moyen d'un braquage aujourd'hui", "Objet moyen proposé", "Facteur" })
for zone = 1, 6 do
	local oldBest = Sim.BestOf(actuelle, zone)
	local newBest, rarityId = Sim.BestOf(eco, zone)
	local share = tableMean(function(luck)
		return Sim.Shares(zone, luck)[rarityId] or 0
	end)
	local oldMean = tableMean(function(luck)
		return heistValue(actuelle, zone, luck)
	end)
	local newMean = tableMean(function(luck)
		return heistValue(eco, zone, luck)
	end)
	ligne({ tostring(zone), rarityId, pct(100 * share), Format.income(oldBest), Format.income(newBest), Format.income(oldMean), Format.income(newMean), fois(newMean / oldMean) })
end
print("")
print(`Zone 6 sans le Secret : meilleur Mythique proposé {Format.income(BT.Income.Mythic * (1 + Rarities.IncomeRules.RankStep) ^ 2)} (aujourd'hui {Format.income(Rarities.ById.Mythic.Income * (1 + Rarities.IncomeRules.RankStep) ^ 2)}).`)
print(`Secret proposé : {Format.income(BT.Income.Secret)} ; en Gold (×2) {Format.income(2 * BT.Income.Secret)} ; en Rainbow (×10) {Format.income(10 * BT.Income.Secret)} ; Rainbow de 10 000 kg (×100) {Format.income(100 * BT.Income.Secret)}.`)
print(`Mutation d'effet moyenne : × {string.format("%.3f", effectMean)} ; poids moyen à chance ×1 : × {string.format("%.3f", weightMean(1))}.`)

titre("2.3 Zones (Config/Zones, Balance.Stats, Tools.Power)")
print(`Marche : WalkSpeed = min(70, 16 + {string.format("%.3f", BT.Stats.WalkPerDecade)} × log10(1 + Speed / {string.format("%.1f", BT.Stats.SpeedScale)})) (aujourd'hui : 16 + {Balance.Stats.WalkPerDecade} × log10(1 + Speed / {Balance.Stats.SpeedScale})). Une zone = × {string.format("%.1f", BT.Stats.Ratio)} de Speed = + 6 de marche. Plafond de 70 atteint à Speed {nombre(BT.Stats.SpeedScale * (10 ^ ((Balance.Stats.MaxWalkSpeed - Balance.Stats.BaseWalkSpeed) / BT.Stats.WalkPerDecade) - 1))}.`)
print("")
entete({ "Zone", "Speed aujourd'hui", "Speed proposée", "Marche au panneau (échelle 1)", "Vigile (échelle 1)", "Speed qui suffit vraiment", "Kit", "Dégâts aujourd'hui", "Dégâts proposés", "PV aujourd'hui", "PV proposés" })
for index, zone in Zones do
	local info = eco.Zones[index]
	local scale = Balance.Stats.RealSpeedScale
	local walk = Sim.Walk(eco, info.Speed) / scale
	local guard = if index == 1 then zone.GuardSpeed / scale else math.round((Balance.Carry.NPCBoxSpeedMultiplier * walk + 1) * 10) / 10
	ligne({
		tostring(index),
		nombre(zone.SpeedRequired),
		nombre(info.Speed),
		string.format("%.1f (aujourd'hui %.1f)", walk, zone.AdvisedSpeed / scale),
		string.format("%.1f", guard),
		if index == 1 then "—" else pct(100 * Sim.ChaseFraction(eco, index)),
		table.concat(zone.Kit, " + "),
		nombre(zone.AdvisedDamage),
		nombre(info.Damage),
		nombre(zone.WindowHP),
		nombre(info.HP),
	})
end

local function regle(zone, minutes)
	if zone == nil then
		return "—"
	end
	local text = if minutes >= 1 then string.format("%g min", minutes) else string.format("%.0f s", minutes * 60)
	return `{text} du revenu de référence de la zone {zone} ({Format.income(BT.Reference[zone])})`
end

titre("2.4 Tapis (Config/Training, Config/Upgrades.Treadmill)")
print(`Crédits : {BT.Tapis.TicksPerSecond} par seconde (aujourd'hui 1). Un crédit au niveau n = {BT.Tapis.GainPerTick} × {BT.Tapis.GainGrowth}^(n − 1), × 1,5 avec un tap, × le gamepass, puis × le trail pour la Speed affichée.`)
print("")
entete({ "Niveau affiché", "Gain par seconde aujourd'hui", "Gain par seconde proposé", "Valeur d'une apparition", "Prix pour y passer, aujourd'hui", "Prix proposé", "Calcul" })
for level = 1, #eco.TreadCost + 1 do
	local row = if level > 1 then BT.TreadmillCosts[level - 1] else nil
	ligne({
		tostring(level),
		if level <= #actuelle.TreadCost + 1 then nombre(actuelle.Gain(level - 1)) else "—",
		nombre(eco.Gain(level - 1)),
		nombre(BT.Tapis.GainPerTick * BT.Tapis.GainGrowth ^ (level - 1)),
		if level == 1 then "départ" elseif actuelle.TreadCost[level - 1] then Format.money(actuelle.TreadCost[level - 1]) else "nouveau",
		if level > 1 then Format.money(eco.TreadCost[level - 1]) else "départ",
		if row == nil then "—" elseif row[1] == "abs" then `au moins une absence de {BT.AbsenceHours or 5} h du joueur moyen à ses retours ({Format.income(row[3])})` else regle(row[1], row[2]),
	})
end

for _, family in { { "2.5 Armes (Config/Tools)", eco.Tools, "Power", "Puissance" }, { "2.6 Auras (Config/Cosmetics)", eco.Auras, "Multiplier", "Multiplicateur" }, { "2.7 Trails (Config/Cosmetics)", eco.Trails, "Multiplier", "Multiplicateur" } } do
	titre(family[1])
	entete({ "Id", family[4] .. " aujourd'hui", family[4] .. " proposé", "Prix aujourd'hui", "Prix proposé", "Calcul" })
	for _, entry in family[2] do
		ligne({ entry.Id, nombre(entry.Old[family[3]]), nombre(entry[family[3]]), Format.money(entry.Old.Price), Format.money(entry.Price), regle(entry.Zone, entry.Minutes) })
	end
end

titre("2.8 Présentoirs (Config/Upgrades.DisplaySlots, Costs 1 à 4 ; Config/ShopGrowth.Floor2, Cost et Costs)")
entete({ "Achat", "Prix aujourd'hui", "Prix proposé", "Calcul" })
do
	local names = { "5e présentoir", "6e présentoir", "7e présentoir", "8e présentoir", "L'étage", "Étage, place 1", "Étage, place 2", "Étage, place 3", "Étage, place 4", "Étage, place 5", "Étage, place 6", "Étage, place 7", "Étage, place 8" }
	for index, name in names do
		local row = BT.StandCosts[index]
		ligne({ name, Format.money(actuelle.StandCost[index]), Format.money(eco.StandCost[index]), regle(row[1], row[2]) })
	end
end

-- Courbe « ancien dollar → nouveau dollar » : un montant garde sa valeur comptée en armes. Entre deux armes, en
-- proportion sur une échelle logarithmique ; sous la première et au-dessus de la dernière, le rapport de celle-ci.
local anchorsOld, anchorsNew = {}, {}
for _, tool in eco.Tools do
	if tool.Old.Price > 0 then
		table.insert(anchorsOld, tool.Old.Price)
		table.insert(anchorsNew, tool.Price)
	end
end
local function convert(value, fromList, toList)
	if value <= 0 then
		return 0
	end
	local n = #fromList
	if value <= fromList[1] then
		return value * toList[1] / fromList[1]
	end
	if value >= fromList[n] then
		return value * toList[n] / fromList[n]
	end
	for index = 1, n - 1 do
		local a, b = fromList[index], fromList[index + 1]
		if value <= b then
			local t = math.log(value / a) / math.log(b / a)
			return toList[index] * (toList[index + 1] / toList[index]) ^ t
		end
	end
	return value
end
local function versNouveau(value)
	return convert(value, anchorsOld, anchorsNew)
end
local function versAncien(value)
	return convert(value, anchorsNew, anchorsOld)
end

titre("2.9 Prix secondaires : la courbe « ancien dollar → nouveau dollar » (un prix garde sa valeur comptée en armes)")
entete({ "Repère (arme)", "Ancien prix", "Nouveau prix", "Rapport" })
for index, old in anchorsOld do
	local name
	for _, tool in eco.Tools do
		if tool.Old.Price == old then
			name = tool.Id
		end
	end
	ligne({ name, Format.money(old), Format.money(anchorsNew[index]), fois(anchorsNew[index] / old) })
end
print("")
print("Arbre de compétences (Config/SkillTree, Prices) :")
print("")
entete({ "Compétence", "Prix aujourd'hui", "Prix proposés" })
local function listOf(values, fn)
	local parts = {}
	for _, value in values do
		table.insert(parts, Format.money(fn(value)))
	end
	return table.concat(parts, ", ")
end
local function same(value)
	return value
end
local function converti(value)
	return BT.Round2(versNouveau(value))
end
for _, skill in Config.SkillTree.List do
	ligne({ skill.Id, listOf(skill.Prices, same), listOf(skill.Prices, converti) })
end
ligne({ "BoxLuck (a476, L-374, pas encore dans main)", listOf({ 6000, 50000, 450000, 4000000, 35000000 }, same), listOf({ 6000, 50000, 450000, 4000000, 35000000 }, converti) })
print("")
print("Renaissances (Config/Rebirths, Cash) :")
print("")
entete({ "Renaissance", "Argent aujourd'hui", "Argent proposé" })
for level = 1, 10 do
	local tier = Config.Rebirths.Get(level)
	ligne({ tostring(level), Format.money(tier.Cash), Format.money(converti(tier.Cash)) })
end
print("")
print("Autres montants écrits en dollars :")
print("")
entete({ "Clé", "Aujourd'hui", "Proposé", "Calcul" })
ligne({ "Monetization.StarterPack.Cash", Format.money(2600), Format.money(converti(2600)), "courbe" })
ligne({ "Rewards.MinCashPerMinute", Format.money(Config.Rewards.MinCashPerMinute), Format.money(Config.Rewards.MinCashPerMinute), "inchangé : le revenu de la zone 1 ne change pas" })
ligne({ "Admin.MaxAmount", nombre(Config.Admin.MaxAmount), "1e30", "au-dessus de tout montant possible (section 5)" })
ligne({ "Badges « Millionaire Shop » (BestIncome)", Format.income(1e6), Format.income(1e6), "inchangé : atteint en zone 4 ou 5 (quelques Épiques), comme un cap de mi-partie" })

---------------------------------------------------------------------------------------------- 3. calendrier

titre("3. Jours de calendrier du joueur moyen (sessions et gains hors ligne à 100 %)")
entete({ "Rythme", "Hors ligne compté par absence", "Zone 5 : jours (heures de jeu)", "Zone 6 : jours (heures de jeu)" })
local function calendrier(label, length, perDay, cap, profil)
	local runs = jouer(eco, avec(profil or P.Moyen, { Session = { Length = length, PerDay = perDay, Cap = cap } }), seeds)
	local cells = { label, `{cap} h` }
	for _, zone in { 5, 6 } do
		local days = mediane(champ(runs, zone, "Jours"))
		local hours = mediane(champ(runs, zone))
		table.insert(cells, if days then string.format("%.1f j (%s)", days, duree(hours)) else "jamais")
	end
	ligne(cells)
end
calendrier("45 min par jour, en une session", 2700, 1, 4)
calendrier("1 h 30 par jour, en deux sessions de 45 min", 2700, 2, 4)
calendrier("1 h 30 par jour, en deux sessions de 45 min", 2700, 2, 5)
calendrier("3 h par jour, en deux sessions de 1 h 30", 5400, 2, 4)
calendrier("Joueur passif, 1 h 30 par jour en deux sessions", 2700, 2, 4, P.Passif)
calendrier("Robot sans chance, 8 h par jour en deux sessions", 4 * 3600, 2, 4, P.RobotNormal)

---------------------------------------------------------------------------------------------- 4. chance

local lucks = { 1, 1.5, 2, 3, 5, 8, 10, 15, 20, 40, 80, 120 }
titre("4.1 Ce que fait la chance d'un colis : part de la rareté la plus haute de la zone")
do
	local head = { "Zone (rareté la plus haute)" }
	for _, luck in lucks do
		table.insert(head, "×" .. luck)
	end
	entete(head)
	for zone = 2, 6 do
		local _, rarityId = Sim.BestOf(eco, zone)
		if zone == 6 then
			rarityId = "Mythic"
		end
		local cells = { `{zone} ({rarityId})` }
		for _, luck in lucks do
			table.insert(cells, pct(100 * (Sim.Shares(zone, luck)[rarityId] or 0)))
		end
		ligne(cells)
	end
	local cells = { "6 (Secret)" }
	for _, luck in lucks do
		table.insert(cells, pct(100 * (Sim.Shares(6, luck).Secret or 0)))
	end
	ligne(cells)
end
titre("4.2 Revenu moyen de l'objet d'un braquage selon la chance (économie proposée ; × par rapport à la chance ×1)")
do
	local head = { "Zone" }
	for _, luck in lucks do
		table.insert(head, "×" .. luck)
	end
	entete(head)
	for zone = 2, 6 do
		local base = heistValue(eco, zone, 1)
		local cells = { tostring(zone) }
		for _, luck in lucks do
			table.insert(cells, if luck == 1 then Format.income(base) else fois(heistValue(eco, zone, luck) / base))
		end
		ligne(cells)
	end
	local cells = { "Poids seul" }
	for _, luck in lucks do
		table.insert(cells, fois(weightMean(luck) / weightMean(1)))
	end
	ligne(cells)
	print("")
	print("La même chose dans l'économie d'aujourd'hui (les marches entre raretés sont plus petites, la chance y rapporte moins) :")
	print("")
	entete(head)
	for zone = 2, 6 do
		local base = heistValue(actuelle, zone, 1)
		cells = { tostring(zone) }
		for _, luck in lucks do
			table.insert(cells, if luck == 1 then Format.income(base) else fois(heistValue(actuelle, zone, luck) / base))
		end
		ligne(cells)
	end
end

local function variante(base, label, changes, reference)
	local profil = avec(base, changes)
	local runs = jouer(eco, profil, seeds)
	local z5 = mediane(champ(runs, 5))
	local z6 = mediane(champ(runs, 6))
	local income = mediane(champ(runs, 6, "Revenu"))
	local gain = if reference and z6 then string.format("%+.0f %% (%s)", 100 * (z6 / reference - 1), duree(math.abs(reference - z6))) else "référence"
	ligne({ label, duree(z5), duree(z6), gain, if income then Format.income(income) else "—" })
	return z6
end
if OPTIONS.Ancien then -- sections des passes 1 à 3, gardées pour mémoire (ANCIEN=1)
for _, base in { P.RobotNormal, P.Moyen } do
	titre(`4.3 Ce que chaque source de chance fait gagner : {base.Id}`)
	entete({ "Chance", "Zone 5", "Zone 6", "Écart sur la zone 6", "Revenu à l'entrée en zone 6" })
	local reference = variante(base, "Table normale, rien d'autre (×1 à ×10 tirée à chaque colis)", {}, nil)
	variante(base, "Aucune chance de boîte (toujours ×1)", { Table = 1 }, reference)
	variante(base, "Chance de boîte toujours ×10 (le robot le plus chanceux)", { Table = 10 }, reference)
	variante(base, "Arbre : Box Luck niveau 1 (×1,1)", { Skill = 1.1 }, reference)
	variante(base, "Arbre : Box Luck niveau 5 (×1,5)", { Skill = 1.5 }, reference)
	variante(base, "Chance du serveur ×2, tout le temps", { Server = 2 }, reference)
	variante(base, "Chance du serveur ×4, tout le temps", { Server = 4 }, reference)
	variante(base, "Chance du serveur ×8, tout le temps", { Server = 8 }, reference)
	variante(base, "Serveur ×8 et arbre ×1,5, tout le temps", { Server = 8, Skill = 1.5 }, reference)
	variante(base, "Tout au maximum : boîte ×10, serveur ×8, arbre ×1,5 (×120)", { Table = 10, Server = 8, Skill = 1.5 }, reference)
end
end

-- Une dose de chance du serveur dure 30 min (a476, L-375). Braquages faits en 30 min par un joueur au niveau du
-- panneau qui ne fait que braquer : 80 % du temps est de jour, un trajet dure tripAt(zone).
local function tripAt(zone)
	local H = Sim.Hypotheses
	local info = eco.Zones[zone]
	local walk = Sim.Walk(eco, info.Speed)
	local lowest = Rarities.ById[Rarities.ZoneRarities[zone][1]].Order
	return (info.Distance + H.PlotDistance) / walk + Balance.WindowHP.SoloBreakTime + H.InStore + H.OpenBase + H.OpenPerRarity * lowest + info.Distance / (Balance.Carry.NPCBoxSpeedMultiplier * walk) + H.PlotDistance / walk + H.Deposit
end
if OPTIONS.Ancien then -- sections des passes 1 à 3, gardées pour mémoire (ANCIEN=1)
titre("4.3 bis Ce que rapporte UNE dose de chance du serveur (30 min passées à braquer, au niveau du panneau)")
entete({ "Zone", "Braquages en 30 min", "Objets de la rareté la plus haute : sans, ×2, ×4, ×8", "Revenu ajouté par les 30 min : sans, ×2, ×4, ×8", "Zone 6 : chance d'un Secret : sans, ×2, ×4, ×8" })
for zone = 3, 6 do
	local heists = 0.8 * 1800 / tripAt(zone)
	local _, rarityId = Sim.BestOf(eco, zone)
	if zone == 6 then
		rarityId = "Mythic"
	end
	local counts, values, secrets = {}, {}, {}
	for _, server in { 1, 2, 4, 8 } do
		table.insert(counts, string.format("%.2f", heists * tableMean(function(luck)
			return Sim.Shares(zone, luck * server)[rarityId] or 0
		end)))
		table.insert(values, Format.income(heists * tableMean(function(luck)
			return heistValue(eco, zone, luck * server)
		end)))
		table.insert(secrets, pct(100 * heists * tableMean(function(luck)
			return Sim.Shares(zone, luck * server).Secret or 0
		end)))
	end
	ligne({ `{zone} ({rarityId})`, string.format("%.0f", heists), table.concat(counts, ", "), table.concat(values, ", "), if zone == 6 then table.concat(secrets, ", ") else "—" })
end
end
print("")
print("« Revenu ajouté » = somme des $/s des objets rapportés, s'ils étaient tous exposés ; un joueur n'expose que les meilleurs.")

if OPTIONS.Ancien then -- sections des passes 1 à 3, gardées pour mémoire (ANCIEN=1)
titre("4.4 Table de chance de la boîte (Config/ShelfOpen.LuckTable) : celle d'aujourd'hui et quatre essais")
entete({ "Table", "Taux", "Chance moyenne", "Objet moyen d'un braquage en zone 5 (× la chance ×1)", "Part des Légendaires de zone 5 venus d'un colis à ×5 ou plus", "Robot sans chance : zone 6", "Joueur moyen : zone 6" })
for _, entry in BT.LuckTables do
	Sim.LuckTable = entry.Table
	local list = entry.Table or ShelfOpen.LuckTable
	local parts, total = {}, 0
	for _, row in list do
		total += row.Weight
	end
	for _, row in list do
		table.insert(parts, `×{row.Luck} {pct(100 * row.Weight / total)}`)
	end
	local meanLuck = tableMean(function(luck)
		return luck
	end)
	local value = tableMean(function(luck)
		return heistValue(eco, 5, luck)
	end) / heistValue(eco, 5, 1)
	local high, all = 0, 0
	for _, row in list do
		local share = row.Weight * (Sim.Shares(5, row.Luck).Legendary or 0)
		all += share
		if row.Luck >= 5 then
			high += share
		end
	end
	local robot = mediane(champ(jouer(eco, P.RobotNormal, seeds), 6))
	local moyen = mediane(champ(jouer(eco, P.Moyen, seeds), 6))
	ligne({ entry.Id, table.concat(parts, ", "), string.format("× %.2f", meanLuck), fois(value), pct(100 * high / all), duree(robot), duree(moyen) })
end
Sim.LuckTable = nil
end

---------------------------------------------------------------------------------------------- 4.5 cran de montée

-- Décision de Cantin (25/11) : adoucir ShelfOpen.ShelfStepUp (0,05 : chaque cran au-dessus du colis est 20 fois plus
-- dur sur un rayon) pour que la chance donne plus souvent une rareté au-dessus du colis. Règles d'essai : le cran
-- fixe, ou le cran qui s'ouvre avec la chance. La rareté du colis lui-même ne change pas.
if OPTIONS.Ancien then -- sections des passes 1 à 3, gardées pour mémoire (ANCIEN=1)
local stepRules = {
	{ Id = "Aujourd'hui : cran 0,05", Rule = nil },
	{ Id = "Cran fixe 0,10", Rule = function(_luck)
		return 0.10
	end },
	{ Id = "Cran fixe 0,20", Rule = function(_luck)
		return 0.20
	end },
	{ Id = "Cran 0,05 × racine de la chance, au plus 0,5", Rule = function(luck)
		return math.min(0.5, 0.05 * math.sqrt(math.max(luck, 1)))
	end },
	{ Id = "Cran 0,05 × chance, au plus 0,5", Rule = function(luck)
		return math.min(0.5, 0.05 * math.max(luck, 1))
	end },
	{ Id = "Cran 0,05 × chance, au plus 1", Rule = function(luck)
		return math.min(1, 0.05 * math.max(luck, 1))
	end },
}
do
	-- La copie de la règle (Sim.ContentWeightsWith) donne-t-elle les mêmes parts que la vraie fonction au cran du jeu ?
	local real = {}
	for zone = 2, 6 do
		for _, luck in { 1, 3, 10, 120 } do
			real[`{zone}/{luck}`] = Sim.Shares(zone, luck)
		end
	end
	Sim.SetStepRule(function(_luck)
		return ShelfOpen.ShelfStepUp
	end)
	for zone = 2, 6 do
		for _, luck in { 1, 3, 10, 120 } do
			for rarityId, share in Sim.Shares(zone, luck) do
				assert(math.abs(share - (real[`{zone}/{luck}`][rarityId] or 0)) < 1e-12, `rapport_bt : la copie de la règle du cran diverge (zone {zone}, chance {luck}, {rarityId})`)
			end
		end
	end
	Sim.SetStepRule(nil)
end

local contexts = {
	{ Id = "boîte seule", Factor = 1 },
	{ Id = "boîte × serveur ×8", Factor = 8 },
	{ Id = "boîte × serveur ×8 × arbre ×1,5", Factor = 12 },
}
titre("4.5 Le cran de montée (ShelfOpen.ShelfStepUp) : part de la rareté la plus haute de chaque zone selon la règle")
entete({ "Règle du cran", "Chance", "Zone 2 : Peu commun", "Zone 3 : Rare", "Zone 4 : Épique", "Zone 5 : Légendaire", "Zone 6 : Mythique", "Zone 6 : Secret" })
for _, rule in stepRules do
	Sim.SetStepRule(rule.Rule)
	for _, context in contexts do
		local cells = { rule.Id, context.Id }
		for _, case in { { 2, "Uncommon" }, { 3, "Rare" }, { 4, "Epic" }, { 5, "Legendary" }, { 6, "Mythic" }, { 6, "Secret" } } do
			table.insert(cells, pct(100 * tableMean(function(luck)
				return Sim.Shares(case[1], luck * context.Factor)[case[2]] or 0
			end)))
		end
		ligne(cells)
	end
end
Sim.SetStepRule(nil)

titre("4.5 bis Parts de chaque rareté d'objet par zone, chance de boîte seule (tes repères du 20/11)")
do
	local head = { "Zone" }
	for _, rule in stepRules do
		table.insert(head, rule.Id)
	end
	entete(head)
	for zone = 2, 6 do
		local cells = { tostring(zone) }
		for _, rule in stepRules do
			Sim.SetStepRule(rule.Rule)
			local parts = {}
			for _, rarity in Rarities.List do
				local share = tableMean(function(luck)
					return Sim.Shares(zone, luck)[rarity.Id] or 0
				end)
				if share > 0 then
					table.insert(parts, `{rarity.Id} {pct(100 * share)}`)
				end
			end
			table.insert(cells, table.concat(parts, ", "))
		end
		ligne(cells)
	end
	Sim.SetStepRule(nil)
end

titre("4.5 ter Ce que la règle change : une dose de chance du serveur ×8 (30 min à braquer) et le temps jusqu'à la zone 6")
entete({ "Règle du cran", "Zone 5, Légendaires par dose : sans, avec ×8", "Zone 6, Mythiques par dose : sans, avec ×8", "Zone 6, chance d'un Secret par dose : sans, avec ×8", "Joueur moyen : zone 6", "Joueur moyen avec serveur ×8 tout le temps", "Revenu du joueur moyen à l'arrivée : sans, avec ×8", "Robot sans chance : zone 6", "Robot, boîte ×10 : zone 6" })
do
	local count = math.min(seeds, 21)
	for _, rule in stepRules do
		Sim.SetStepRule(rule.Rule)
		local function dose(zone, rarityId, server)
			return 0.8 * 1800 / tripAt(zone) * tableMean(function(luck)
				return Sim.Shares(zone, luck * server)[rarityId] or 0
			end)
		end
		local moyen = jouer(eco, P.Moyen, count)
		local moyen8 = jouer(eco, avec(P.Moyen, { Server = 8 }), count)
		ligne({
			rule.Id,
			string.format("%.2f, %.2f", dose(5, "Legendary", 1), dose(5, "Legendary", 8)),
			string.format("%.2f, %.2f", dose(6, "Mythic", 1), dose(6, "Mythic", 8)),
			`{pct(100 * dose(6, "Secret", 1))}, {pct(100 * dose(6, "Secret", 8))}`,
			celluleTemps(moyen, 6, true),
			celluleTemps(moyen8, 6, true),
			`{Format.income(mediane(champ(moyen, 6, "Revenu")) or 0)}, {Format.income(mediane(champ(moyen8, 6, "Revenu")) or 0)}`,
			celluleTemps(jouer(eco, P.RobotNormal, count), 6, true),
			celluleTemps(jouer(eco, P.RobotTable10, count), 6, true),
		})
	end
	Sim.SetStepRule(nil)
end
end

---------------------------------------------------------------------------------------------- 4.6 modèle de chance de Cantin

-- Modèle de chance de Cantin (25/11) : chance achetée = personnelle × arbre × serveur ; à l'ouverture, les taux des
-- hauts ×N montent (règles R1, R2, R3) et le ×N tiré est multiplié par la chance achetée ; la chance du serveur
-- augmente aussi la rareté des colis en rayon et les mutations d'effet (Outil/simulateur_bt, Sim.DrawCantin).
local cantinRules = {
	{ Id = "R2", Name = "R2 (choisie) : seuls ×8 et ×10 multipliés par la chance" },
}
local cantinLevels = {
	{ Id = "×2 (serveur ×2)", Spec = { Server = 2 } },
	{ Id = "×4 (serveur ×4)", Spec = { Server = 4 } },
	{ Id = "×8 (serveur ×8)", Spec = { Server = 8 } },
	{ Id = "×36 (perso ×3, arbre ×1,5, serveur ×8)", Spec = { Perso = 3, Skill = 1.5, Server = 8 } },
	{ Id = "×360 (les mêmes, et la boîte tire ×10 à chaque colis)", Spec = { Perso = 3, Skill = 1.5, Server = 8, Table = 10 } },
}
local function specOf(rule, base)
	local spec = table.clone(base)
	spec.Rule = rule
	return spec
end

titre("4.6 Modèle de chance de Cantin : les taux du ×N de la boîte selon la règle")
do
	local head = { "Règle", "Chance achetée" }
	for _, entry in Sim.TableFor("Table", 1) do
		table.insert(head, "×" .. entry.Luck)
	end
	table.insert(head, "×N moyen")
	table.insert(head, "Chance finale moyenne du colis (×N × chance achetée)")
	entete(head)
	local function row(name, rule, c)
		local cells = { name, if c == 1 then "aucune" else "×" .. c }
		local total, mean = 0, 0
		local list = Sim.TableFor(rule, c)
		for _, entry in list do
			total += entry.Weight
		end
		for _, entry in list do
			table.insert(cells, pct(100 * entry.Weight / total))
			mean += entry.Weight / total * entry.Luck
		end
		table.insert(cells, string.format("× %.2f", mean))
		table.insert(cells, string.format("× %.1f", mean * c))
		ligne(cells)
	end
	row("Aujourd'hui", "Table", 1)
	for _, rule in cantinRules do
		for _, c in { 2, 4, 8, 36, 360 } do
			row(rule.Name, rule.Id, c)
		end
	end
end

-- Revenu moyen de l'objet d'un braquage dans le modèle de Cantin (mutation et poids compris).
local function heistValueCantin(zone, spec)
	local luckList, c = Sim.SpecTable(spec)
	local total, weight = 0, 0
	for _, entry in luckList do
		if entry.Weight > 0 then
			local fixed = table.clone(spec)
			fixed.Table = entry.Luck
			local value = 0
			for rarityId, share in Sim.SharesCantin(zone, fixed) do
				value += share * meanIncome(eco, zone, rarityId)
			end
			total += entry.Weight * value * weightMean(entry.Luck * c)
			weight += entry.Weight
		end
	end
	return total / weight * Sim.EffectMean(spec.Server or 1)
end
local noLuck = { Rule = "Table" }

titre("4.6 bis Modèle de Cantin : parts des objets rares et valeur d'un braquage (la chance du serveur compte aussi sur les colis en rayon et les mutations)")
entete({ "Règle", "Chance", "Zone 5 : Légendaires", "Zone 6 : Mythiques", "Zone 6 : Secrets", "Un Secret tous les … braquages", "Un Mythique tous les … braquages", "Objets avec une mutation", "Colis en rayon, zone 6 : Mythique, Secret", "Objet moyen d'un braquage, zone 5", "Objet moyen d'un braquage, zone 6" })
do
	local base5, base6 = heistValueCantin(5, noLuck), heistValueCantin(6, noLuck)
	-- Part des objets qui sortent avec une mutation d'effet (la chance du serveur les multiplie, sans plafond).
	local function mutes(spec)
		local list = Sim.EffectOdds(spec.Server or 1)
		local total = 0
		for _, entry in list do
			total += entry.Weight
		end
		return pct(100 * (1 - list[1].Weight / total))
	end
	-- Part des colis Mythique et Secret sur les rayons de la zone 6 (la chance du serveur agit à la mise en rayon).
	local function colis(spec)
		local total, mythic, secret = 0, 0, 0
		for _, entry in Sim.BoxOdds(6, spec.Server or 1) do
			total += entry.Weight
			if entry.Id == "Mythic" then mythic = entry.Weight elseif entry.Id == "Secret" then secret = entry.Weight end
		end
		return `{pct(100 * mythic / total)}, {pct(100 * secret / total)}`
	end
	local function row(name, levelName, spec)
		local s5, s6 = Sim.SharesCantin(5, spec), Sim.SharesCantin(6, spec)
		local secret = s6.Secret or 0
		ligne({ name, levelName, pct(100 * (s5.Legendary or 0)), pct(100 * (s6.Mythic or 0)), pct(100 * secret), string.format("%.0f", 1 / secret), string.format("%.0f", 1 / (s6.Mythic or 1e-9)), mutes(spec), colis(spec), if spec == noLuck then Format.income(base5) else fois(heistValueCantin(5, spec) / base5), if spec == noLuck then Format.income(base6) else fois(heistValueCantin(6, spec) / base6) })
	end
	row("Sans chance achetée", "×1", noLuck)
	for _, rule in cantinRules do
		for _, level in cantinLevels do
			if level.Spec.Table == nil or rule.Id == "R2" then
				row(rule.Name, level.Id, specOf(rule.Id, level.Spec))
			end
		end
	end
end

titre("4.6 ter Modèle de Cantin : temps jusqu'à la zone 6 et revenu à l'arrivée, chance active tout le temps")
entete({ "Règle", "Chance", "Joueur moyen : zone 6", "Son revenu à l'arrivée", "Robot sans chance : zone 6", "Son revenu à l'arrivée" })
do
	local count = math.min(seeds, 15)
	local function row(name, levelName, cantin)
		local moyen = jouer(eco, avec(P.Moyen, { Cantin = cantin or false }), count)
		local robot = jouer(eco, avec(P.RobotNormal, { Cantin = cantin or false }), count)
		ligne({ name, levelName, celluleTemps(moyen, 6, true), Format.income(mediane(champ(moyen, 6, "Revenu")) or 0), celluleTemps(robot, 6, true), Format.income(mediane(champ(robot, 6, "Revenu")) or 0) })
	end
	row("Aujourd'hui", "aucune", nil)
	for _, rule in cantinRules do
		for _, level in cantinLevels do
			if level.Spec.Table == nil or rule.Id == "R2" then
				row(rule.Name, level.Id, specOf(rule.Id, level.Spec))
			end
		end
	end
end

titre("4.6 quater Modèle de Cantin : ce que rapporte une dose (serveur ×2, ×4, ×8 pendant 30 min ; personnelle ×3 pendant 30 min), passée à braquer")
entete({ "Règle", "Dose", "Zone 5 : Légendaires, sans puis avec", "Zone 6 : Mythiques, sans puis avec", "Zone 6 : chance d'un Secret, sans puis avec", "Zone 6 : revenu ajouté, sans puis avec" })
do
	local doses = {
		{ Id = "Serveur ×2, 30 min", Spec = { Server = 2 }, Seconds = 1800 },
		{ Id = "Serveur ×4, 30 min", Spec = { Server = 4 }, Seconds = 1800 },
		{ Id = "Serveur ×8, 30 min", Spec = { Server = 8 }, Seconds = 1800 },
		{ Id = "Personnelle ×3, 30 min", Spec = { Perso = 3 }, Seconds = 1800 },
		{ Id = "Personnelle ×3 pendant un serveur ×8, 30 min", Spec = { Perso = 3, Server = 8 }, Seconds = 1800 },
	}
	for _, rule in cantinRules do
		for _, dose in doses do
			local spec = specOf(rule.Id, dose.Spec)
			local h5, h6 = 0.8 * dose.Seconds / tripAt(5), 0.8 * dose.Seconds / tripAt(6)
			local b5, b6 = Sim.SharesCantin(5, noLuck), Sim.SharesCantin(6, noLuck)
			local s5, s6 = Sim.SharesCantin(5, spec), Sim.SharesCantin(6, spec)
			ligne({
				rule.Name,
				dose.Id,
				string.format("%.2f, %.2f", h5 * (b5.Legendary or 0), h5 * (s5.Legendary or 0)),
				string.format("%.2f, %.2f", h6 * (b6.Mythic or 0), h6 * (s6.Mythic or 0)),
				`{pct(100 * h6 * (b6.Secret or 0))}, {pct(100 * (1 - (1 - (s6.Secret or 0)) ^ h6))}`,
				`{Format.income(h6 * heistValueCantin(6, noLuck))}, {Format.income(h6 * heistValueCantin(6, spec))}`,
			})
		end
	end
end

titre("4.6 quinquies La roue (Config/Wheel) : règle V0, les secteurs les plus rares multipliés par la chance, pris sur le plus courant")
do
	local sectors = {}
	for _, sector in Config.Wheel.Sectors do
		table.insert(sectors, { Label = sector.Label, Weight = sector.Weight })
	end
	table.sort(sectors, function(a, b)
		return a.Weight > b.Weight
	end)
	local head = { "Chance" }
	for _, sector in sectors do
		table.insert(head, `{sector.Label} ({sector.Weight} %)`)
	end
	entete(head)
	for _, luck in { 3, 4.5, 8, 24, 36 } do
		local list = Sim.Boost(sectors, luck, function(entry)
			return entry.Weight <= 7
		end)
		local total = 0
		for _, entry in list do
			total += entry.Weight
		end
		local cells = { "×" .. luck }
		for _, entry in list do
			table.insert(cells, pct(100 * entry.Weight / total))
		end
		ligne(cells)
	end
end


---------------------------------------------------------------------------------------------- 5. grands nombres

titre("5. Grands nombres")
print(`2^53 = {string.format("%.0f", 2 ^ 53)} ({nombre(2 ^ 53)}) : dernier entier exact. 2^53 + 1 == 2^53 : {tostring(2 ^ 53 + 1 == 2 ^ 53)}.`)
do
	entete({ "Argent en poche", "Pas entre deux montants que le jeu sait écrire", "En part du montant" })
	for _, cash in { 1e15, 1e16, 1e18, 1e21, 1e24, 1e30 } do
		-- Plus petit pas représentable autour de `cash` (un double a 53 bits de mantisse).
		local step = 2 ^ (math.floor(math.log(cash, 2)) - 52)
		ligne({ Format.money(cash), if step < 1 then string.format("$%g", step) else Format.money(step), string.format("%.1g", step / cash) })
	end
end
print("")
print("Format.short au-delà de T : " .. table.concat({ nombre(4e12), nombre(9.99e14), nombre(1e15), nombre(2 ^ 53), nombre(1.234e18), nombre(5e21), nombre(7.7e24), nombre(1e27), nombre(1e30), nombre(9.99e35), nombre(1e36), nombre(1e40) }, ", "))
do
	local Leaderboard = Config.Leaderboard
	print("")
	entete({ "Classement", "Valeur", "Valeur rangée (entier)", "Valeur relue", "Erreur" })
	for _, case in { { "Income", 50e9 }, { "Income", 4.2e15 }, { "Income", 1e30 }, { "Speed", 4e12 }, { "Speed", 2 ^ 53 }, { "Speed", 1e17 }, { "Speed", 1e21 } } do
		local stored = Leaderboard.Encode(case[1], case[2])
		local back = Leaderboard.Decode(case[1], stored)
		ligne({ case[1], nombre(case[2]), string.format("%.0f", stored), nombre(back), string.format("%.2g %%", 100 * math.abs(back - case[2]) / case[2]) })
	end
	print("")
	print(`Speed rangée en logarithme comme Income (proposé) : 4T → {string.format("%.0f", math.round(math.log10(1 + 4e12) * Leaderboard.LogScale))} ; 1e21 → {string.format("%.0f", math.round(math.log10(1 + 1e21) * Leaderboard.LogScale))} ; erreur de relecture {string.format("%.1g %%", 100 * math.abs(10 ^ (math.round(math.log10(1 + 1e21) * Leaderboard.LogScale) / Leaderboard.LogScale) - 1 - 1e21) / 1e21)}.`)
end
do
	titre("5.1 Gains hors ligne (Config/Offline : 100 %, 4 h ; 5 h avec les 2 × 30 min de l'arbre) et argent possible")
	local stands = 16
	local run = partieMediane(kept[P.Moyen])
	local cases = {
		{ "Joueur moyen à l'entrée de la zone 6", run.RevenuFinal, 1 },
		{ "Zone 6 installée : 16 Légendaires de zone 6 moyens", stands * meanIncome(eco, 6, "Legendary") * effectMean * weightMean(1), 1 },
		{ "Zone 6 avancée : 16 Mythiques moyens", stands * meanIncome(eco, 6, "Mythic") * effectMean * weightMean(1), 1 },
		{ "Un Secret et 15 Mythiques", (BT.Income.Secret + 15 * meanIncome(eco, 6, "Mythic")) * effectMean * weightMean(1), 1 },
		{ "Gros joueur après des mois : 20 Secrets moyens, 10 renaissances (×6), ×2 Cash, VIP, 4 amis", 20 * BT.Income.Secret * effectMean * weightMean(1), 6 * 2 * 1.1 * 1.6 },
		{ "Plafond théorique : 20 Secrets Rainbow de 10 000 kg, mêmes bonus, boost ×2 et événement ×2", 20 * BT.Income.Secret * 100, 6 * 2 * 1.1 * 1.6 * 2 * 2 },
	}
	entete({ "Cas", "Revenu", "Hors ligne 4 h", "Hors ligne 5 h", "En 30 jours (10 h comptées par jour)", "En un an sans arrêt" })
	for _, case in cases do
		local income = case[2] * case[3]
		ligne({ case[1], Format.income(income), Format.money(income * 4 * 3600), Format.money(income * 5 * 3600), Format.money(income * 30 * 36000), Format.money(income * 365 * 86400) })
	end
end

---------------------------------------------------------------------------------------------- 6. conversion des profils

titre("6. Conversion d'un profil existant (argent : courbe des armes ; Speed : courbe des panneaux)")
entete({ "Argent aujourd'hui", "Argent converti", "Retour", "Ce qu'il achetait", "Ce qu'il achète" })
local function achetable(economy, cash)
	local best = "rien"
	for _, tool in economy.Tools do
		if tool.Price > 0 and tool.Price <= cash then
			best = tool.Id
		end
	end
	return best
end
for _, cash in { 100, 300, 1000, 3100, 20e3, 88e3, 500e3, 1.2e6, 9.9e6, 69e6, 170e6, 5e9, 76e9 } do
	local new = versNouveau(cash)
	ligne({ Format.money(cash), Format.money(new), Format.money(versAncien(new)), achetable(actuelle, cash), achetable(eco, new) })
end
print("")
local speedOld, speedNew = {}, {}
for zone = 2, 6 do
	speedOld[zone - 1], speedNew[zone - 1] = actuelle.Speed[zone], eco.Speed[zone]
end
entete({ "Speed affichée aujourd'hui", "Speed affichée convertie", "Retour", "Zones ouvertes avant", "Zones ouvertes après" })
local function ouvertes(economy, shown)
	local open = 1
	for zone = 2, 6 do
		if shown >= economy.Speed[zone] then
			open = zone
		end
	end
	return tostring(open)
end
for _, shown in { 10, 500, 3e3, 20e3, 100e3, 1e6, 3e6, 50e6, 100e6, 1e9, 3e9, 50e9 } do
	local new = convert(shown, speedOld, speedNew)
	ligne({ nombre(shown), nombre(new), nombre(convert(new, speedNew, speedOld)), ouvertes(actuelle, shown), ouvertes(eco, new) })
end
