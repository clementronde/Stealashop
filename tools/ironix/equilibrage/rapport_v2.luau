--!nocheck
-- Rapport du rééquilibrage v2 (Outil/proposition_v2) : tableaux Markdown, valeurs d'aujourd'hui (lues dans
-- src/shared/Config) contre valeurs proposées, et parties simulées.
--   RAPPORT=v2 bash tools/ironix/equilibrage/run.sh           rapport complet
--   RAPPORT=v2 COURT=1 bash tools/ironix/equilibrage/run.sh   seulement les temps par zone (pour régler)

local Modele = charge("Outil/modele")
local V2 = charge("Outil/proposition_v2")

local Balance = Config.Balance
local Zones = Config.Zones
local Tools = Config.Tools
local Cosmetics = Config.Cosmetics
local Upgrades = Config.Upgrades
local Training = Config.Training
local Formulas = Config.Formulas
local Potions = Config.Potions
local Night = Config.Night
local SkillTree = Config.SkillTree

local eco = V2.Construire()
local seeds = OPTIONS.Graines
local maxSeconds = OPTIONS.Heures * 3600

---------------------------------------------------------------------------------------------- écriture

local function nombre(value)
	if value == nil then
		return "—"
	end
	if value == math.huge then
		return "∞"
	end
	return Format.short(value)
end
local function duree(seconds)
	if seconds == nil or seconds ~= seconds then
		return "—"
	end
	if seconds == math.huge then
		return "jamais"
	end
	if seconds < 0.05 then
		return "< 0.1 s"
	end
	if seconds < 60 then
		return string.format("%.1f s", seconds)
	end
	local minutes = math.floor(seconds / 60 + 0.5)
	if minutes < 60 then
		return `{minutes} min`
	end
	return string.format("%d h %02d", minutes // 60, minutes % 60)
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
	return sorted[(#sorted + 1) // 2]
end
local function etendue(list, format)
	if #list == 0 then
		return "—"
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return `{format(sorted[(#sorted + 1) // 2])} ({format(sorted[1])} à {format(sorted[#sorted])})`
end
local function fixe(value, digits)
	return string.format(`%.{digits or 1}f`, value)
end

local function jouer(economy, profil, count)
	local runs = {}
	for seed = 1, count do
		table.insert(runs, Modele.Jouer(economy, profil, seed, maxSeconds))
	end
	return runs
end
local function champ(runs, zone, field)
	local values = {}
	for _, run in runs do
		local entry = run.Entrees[zone]
		if entry ~= nil then
			table.insert(values, entry[field])
		end
	end
	return values
end
local function tempsZone(runs, zone)
	local times = champ(runs, zone, "T")
	return if #times < #runs then `{#times}/{#runs} parties, {etendue(times, duree)}` else etendue(times, duree)
end
local function profilDe(id)
	for _, profil in Modele.Profils do
		if profil.Id == id then
			return profil
		end
	end
	return nil
end

print(`Rééquilibrage v2 : {seeds} parties par profil, {OPTIONS.Heures} h au plus par partie.`)

local parties = {}
local function tableauTemps()
	entete({ "Profil", "Zone 2", "Zone 3", "Zone 4", "Zone 5", "Zone 6" })
	for _, profil in Modele.Profils do
		local runs = parties[profil.Id] or jouer(eco, profil, seeds)
		parties[profil.Id] = runs
		local cells = { profil.Id }
		for zone = 2, #eco.Zones do
			table.insert(cells, tempsZone(runs, zone))
		end
		ligne(cells)
	end
end
local function tableauMoyen()
	local runs = parties.Moyen
	entete({ "Zone", "Temps de jeu", "Speed affichée", "WalkSpeed", "Strength", "Casse", "Outil", "Niveau du tapis", "Présentoirs", "Revenus", "Depuis la zone d'avant : tapis", "braquages" })
	local previous = { TempsTapis = 0, TempsBraquage = 0 }
	for zone = 2, #eco.Zones do
		local function m(field)
			return mediane(champ(runs, zone, field))
		end
		local tools, best, bestCount = {}, "—", 0
		for _, name in champ(runs, zone, "Outil") do
			tools[name] = (tools[name] or 0) + 1
			if tools[name] > bestCount then
				best, bestCount = name, tools[name]
			end
		end
		local tapis, braquage = m("TempsTapis"), m("TempsBraquage")
		if tapis == nil then
			ligne({ tostring(zone), "—" })
			continue
		end
		ligne({
			tostring(zone),
			duree(m("T")),
			nombre(m("Vitesse")),
			fixe(m("Marche")),
			nombre(m("Degats")),
			duree(m("Casse")),
			best,
			tostring(m("Tapis") + 1),
			tostring(m("Presentoirs")),
			`${nombre(m("Revenu"))}/s`,
			duree(tapis - previous.TempsTapis),
			duree(braquage - previous.TempsBraquage),
		})
		previous = { TempsTapis = tapis, TempsBraquage = braquage }
	end
end

if OPTIONS.Court then
	tableauTemps()
	print("")
	tableauMoyen()
	return
end

---------------------------------------------------------------------------------------------- 1. marche

titre("1. Vitesse de marche réelle selon la Speed affichée")
print("Aujourd'hui : WalkSpeed = min(70, 16 + 0,05 × Vitesse × M trail). Proposition : WalkSpeed = min(70, 16 + 4 × log10(1 + Speed affichée / 100)), Speed affichée = Vitesse entraînée × M trail.")
print("")
entete({ "Speed affichée", "WalkSpeed", "Repère" })
local reperes = { [3e3] = "panneau zone 2", [100e3] = "panneau zone 3", [3e6] = "panneau zone 4", [100e6] = "panneau zone 5", [3e9] = "panneau zone 6" }
for _, speed in { 0, 100, 1e3, 3e3, 1e4, 1e5, 1e6, 3e6, 1e7, 1e8, 1e9, 3e9, 1e10, 1e11, 1e12, 1e13, 1e15, 3.2e15 } do
	ligne({ nombre(speed), fixe(eco.WalkSpeed(speed, 1)), reperes[speed] or "" })
end

---------------------------------------------------------------------------------------------- 2. zones

titre("2. Zones (Config/Zones) : aujourd'hui → proposition")
entete({ "Zone", "Speed du panneau", "WalkSpeed conseillé", "Kit du panneau", "Strength du panneau = dégâts/coup", "PV vitrine", "PV / dégâts", "Vigile", "$/s d'un Commun" })
for index, zone in Zones do
	local new = eco.Zones[index]
	local names = {}
	for _, id in V2.Zones[index].Kit do
		table.insert(names, (Tools.ById[id] or Cosmetics.ById[id]).DisplayName)
	end
	local kit = table.concat(names, " × ")
	ligne({
		tostring(index),
		`{zone.AdvisedSpeed} → {nombre(new.SpeedShown)}`,
		`{zone.AdvisedSpeed} → {fixe(new.AdvisedSpeed)}`,
		kit,
		`{nombre(zone.AdvisedDamage)} → {nombre(new.AdvisedDamage)}`,
		`{nombre(zone.WindowHP)} → {nombre(new.WindowHP)}`,
		`{fixe(zone.WindowHP / zone.AdvisedDamage, 0)} → {fixe(new.WindowHP / new.AdvisedDamage, 0)}`,
		`{zone.GuardSpeed} → {new.GuardSpeed}`,
		`{nombre(zone.BaseIncome)} → {nombre(new.BaseIncome)}`,
	})
end
print("")
print("Casse d'une vitrine par un joueur seul qui a les dégâts du panneau (régénération 3 %/s, chrono 13 s) :")
print("")
entete({ "Zone", "à 4 coups/s", "à 6 coups/s", "à 10 coups/s", "avec le kit de la zone d'avant, 10 coups/s" })
for index = 1, #eco.Zones do
	local new = eco.Zones[index]
	local function t(damage, hits)
		local seconds = Modele.BreakTime(new.WindowHP, damage, hits)
		return if seconds > Balance.Window.BreakTimer then `non ({duree(seconds)})` else duree(seconds)
	end
	ligne({ tostring(index), t(new.AdvisedDamage, 4), t(new.AdvisedDamage, 6), t(new.AdvisedDamage, 10), if index > 1 then t(eco.Zones[index - 1].AdvisedDamage, 10) else "—" })
end

---------------------------------------------------------------------------------------------- 3. zone 6

titre("3. Zone 6 : jamais seul")
local z6 = eco.Zone6
local best = eco.BestDamage
local T, regen = Balance.Window.BreakTimer, Balance.Window.RegenPerSecond
print(`D = meilleure arme × meilleure aura = {nombre(eco.Tools[#eco.Tools].Power)} × {eco.Auras[#eco.Auras].Multiplier} = {nombre(best)} par coup, sans potion. Chrono {T} s, régénération {regen * 100} %/s des PV max, {Balance.Hit.MaxHitsPerSecond} coups/s au plus par joueur.`)
print("")
print(`Une vitrine de PV points casse dans le chrono si : coups/s × dégâts × {T} ≥ PV × (1 + {regen} × {T}), soit PV ≤ {fixe(z6.PerHit, 3)} × coups/s × dégâts.`)
print("")
entete({ "Qui frappe", "Dégâts par seconde", "PV cassables en 13 s", "En multiples de D" })
local function cas(label, players, hits, factor)
	local dps = players * hits * factor * best
	ligne({ label, nombre(dps), nombre(dps * z6.PerHit), fixe(players * hits * factor * z6.PerHit, 1) })
end
cas("Seul, 10 coups/s, sans potion", 1, 10, 1)
cas(`Seul, 10 coups/s, potion ×{V2.PotionStrength}`, 1, 10, V2.PotionStrength)
cas("Deux, 10 coups/s chacun, sans potion (maximum de la règle)", 2, 10, 1)
cas("Deux, 8,6 coups/s chacun, sans potion", 2, 8.6, 1)
cas("Trois, 6 coups/s chacun, sans potion", 3, 6, 1)
cas(`Deux, 6 coups/s chacun, potion ×{V2.PotionStrength}`, 2, 6, V2.PotionStrength)
cas("Deux, 6 coups/s chacun, sans potion", 2, 6, 1)
print("")
print(`Bornes : plus de {fixe(z6.Lower, 1)} × D (seul avec potion), au plus {fixe(z6.Upper, 2)} × D (deux au maximum ; {fixe(z6.UpperNoRegen, 0)} × D sans la régénération). Valeur choisie : {z6.Chosen} × D = {nombre(z6.Chosen * best)} PV.`)
print("")
entete({ "Avec les PV choisis", "Temps de casse" })
local hp6 = z6.Chosen * best
local function casse(label, players, hits, factor, damage)
	local seconds = Modele.BreakTime(hp6, (damage or best) * factor, players * hits)
	ligne({ label, if seconds > T then `non ({duree(seconds)} > {T} s)` else duree(seconds) })
end
casse("Seul, 10 coups/s, sans potion", 1, 10, 1)
casse("Seul, 10 coups/s, potion", 1, 10, V2.PotionStrength)
casse("Deux, 10 coups/s", 2, 10, 1)
casse("Deux, 9 coups/s", 2, 9, 1)
casse("Deux, 8 coups/s", 2, 8, 1)
casse("Trois, 6 coups/s", 3, 6, 1)
casse("Quatre, 6 coups/s", 4, 6, 1)
casse("Deux, 6 coups/s, potion", 2, 6, V2.PotionStrength)
local mid = eco.Tools[#eco.Tools].Power * eco.Auras[#eco.Auras - 1].Multiplier
casse(`Quatre, 10 coups/s, {eco.Tools[#eco.Tools].DisplayName} × {eco.Auras[#eco.Auras - 1].DisplayName} ({nombre(mid)})`, 4, 10, 1, mid)
casse(`Huit, 10 coups/s, kit de la zone 5 ({nombre(eco.Zones[5].AdvisedDamage)})`, 8, 10, 1, eco.Zones[5].AdvisedDamage)

---------------------------------------------------------------------------------------------- 4. tapis

titre("4. Tapis (Config/Upgrades, Config/Training) : aujourd'hui → proposition")
print(`Niveau affiché de 1 à {V2.Treadmill.MaxLevel} (le joueur commence au niveau 1). Aujourd'hui : niveaux 0 à 20, gain 1 + 0,5 × niveau, prix 200 × 1,9^niveau. Proposition : gain {V2.Treadmill.BaseGain} × {V2.Treadmill.GainGrowth}^(niveau − 1), prix du passage au niveau suivant {V2.Treadmill.BaseCost} × {V2.Treadmill.CostGrowth}^(niveau − 1). Taps : +{Training.Treadmill.TapBonus * 100} % (inchangé).`)
print("")
entete({ "Niveau", "Gain par seconde (avant → après)", "Prix pour passer à ce niveau (avant → après)", "Cumul (avant → après)", "Modèle du tapis" })
local cumulOld, cumulNew = 0, 0
for level = 1, V2.Treadmill.MaxLevel do
	local n = level - 1
	local priceOld = if n > 0 then Formulas.UpgradeCost("Treadmill", n - 1) else nil
	local priceNew = if n > 0 then eco.UpgradeCost("Treadmill", n - 1) else nil
	cumulOld += priceOld or 0
	cumulNew += priceNew or 0
	local variant = Upgrades.TreadmillVariants[math.min(#Upgrades.TreadmillVariants, level // Upgrades.TreadmillTierEvery + 1)]
	ligne({
		tostring(level),
		`{Training.Treadmill.GainPerSecond * Formulas.MachineMultiplier("Treadmill", n)} → {nombre(eco.MachineGain("Treadmill", n))}`,
		if n > 0 then `${nombre(priceOld)} → ${nombre(priceNew)}` else "—",
		if n > 0 then `${nombre(cumulOld)} → ${nombre(cumulNew)}` else "—",
		variant,
	})
end

---------------------------------------------------------------------------------------------- 5. boutique

titre("5. Armes, auras, trails (Config/Tools, Config/Cosmetics) : aujourd'hui → proposition")
local function boutique(label, old, new, field)
	entete({ label, field .. " (avant → après)", "Prix (avant → après)", "Zones visées (avant → après)" })
	for index, entry in new do
		local before = old[index]
		ligne({
			entry.DisplayName,
			`{if before[field] < 1000 then tostring(before[field]) else nombre(before[field])} → {if entry[field] < 1000 then tostring(entry[field]) else nombre(entry[field])}`,
			`${nombre(before.Price)} → ${nombre(entry.Price)}`,
			`{before.TargetZones[1]}-{before.TargetZones[2]} → {entry.TargetZones[1]}-{entry.TargetZones[2]}`,
		})
	end
	print("")
end
boutique("Arme", Tools.List, eco.Tools, "Power")
boutique("Aura", Cosmetics.Auras, eco.Auras, "Multiplier")
boutique("Trail", Cosmetics.Trails, eco.Trails, "Multiplier")
print(`Potion de force (Config/Potions) : ×{Potions.ById.Strength.Multiplier} → ×{V2.PotionStrength}.`)

---------------------------------------------------------------------------------------------- 6. portes

titre("6. Portes des boutiques de joueurs (Config/PvP, Formulas.PlayerWindowHP)")
print(`Base = {V2.PlayerWindowHPPerDamage} × Strength du panneau de la zone du même rang que le niveau de la boutique (règle inchangée). Arbre inchangé : Glass jusqu'à ×{eco.Glass[#eco.Glass]}, Walls jusqu'à ×{eco.Walls[#eco.Walls]}, réparation de {regen * 100} à {eco.Regen[#eco.Regen] * 100} %/s. Pas de chrono sur la porte d'un joueur.`)
print("")
local function porte(level, treeFull, damage, hits)
	local hp = eco.DoorHP(level) * (if treeFull then eco.Glass[#eco.Glass] * eco.Walls[#eco.Walls] else 1)
	return Modele.BreakTime(hp, damage, hits, if treeFull then eco.Regen[#eco.Regen] else regen)
end
entete({ "Niveau de boutique", "PV de base (avant → après)", "Arbre complet (×24)", "Sans arbre : voleur du même rang, 6 coups/s", "Sans arbre : voleur d'une zone au-dessus", "Arbre complet : même rang, 10 coups/s", "Arbre complet : une zone au-dessus, 10 coups/s", "Arbre complet : meilleur kit, 10 coups/s" })
for level = 1, 5 do
	local own, above = eco.Zones[level].AdvisedDamage, eco.Zones[level + 1].AdvisedDamage
	ligne({
		tostring(level),
		`{nombre(Formulas.PlayerWindowHP(level))} → {nombre(eco.DoorHP(level))}`,
		nombre(eco.DoorHP(level) * eco.Glass[#eco.Glass] * eco.Walls[#eco.Walls]),
		duree(porte(level, false, own, 6)),
		duree(porte(level, false, above, 6)),
		duree(porte(level, true, own, 10)),
		duree(porte(level, true, above, 10)),
		duree(porte(level, true, best, 10)),
	})
end

---------------------------------------------------------------------------------------------- 7. parties

titre("7. Parties simulées : temps de jeu actif pour entrer dans chaque zone")
print(`Médiane de {seeds} parties (de la plus rapide à la plus lente), premier colis rapporté de la zone, sans aucune aide (ni gains hors ligne, ni récompenses, ni camion, ni potion, ni gamepass). Zone 6 : cassée en équipe ({V2.TeamHits} coups/s en tout, au niveau du joueur).`)
print("")
tableauTemps()

titre("8. Le joueur moyen à son entrée dans chaque zone (médianes)")
tableauMoyen()

titre("9. Répartition du temps jusqu'à la zone 6 (médianes)")
entete({ "Profil", "Tapis", "Braquages", "Part d'entraînement", "Colis rapportés", "Niveau du tapis" })
for _, profil in Modele.Profils do
	local tapis, braquage, colis, niveau = {}, {}, {}, {}
	for _, run in parties[profil.Id] do
		if run.Entrees[#eco.Zones] ~= nil then
			table.insert(tapis, run.Temps.Tapis)
			table.insert(braquage, run.Temps.Braquage)
			table.insert(colis, run.Colis)
			table.insert(niveau, run.Entrees[#eco.Zones].Tapis + 1)
		end
	end
	if #tapis > 0 then
		local a, b = mediane(tapis), mediane(braquage)
		ligne({ profil.Id, duree(a), duree(b), `{fixe(a / (a + b) * 100, 0)} %`, tostring(mediane(colis)), tostring(mediane(niveau)) })
	end
end

titre("10. Ce que coûte chaque achat au joueur moyen")
print("Prix divisé par ce qu'il gagne par minute au moment de l'achat (présentoirs et receleur). Médianes des parties où l'achat est fait avant la zone 6.")
print("")
entete({ "Article", "Prix", "Acheté à", "Minutes de revenus", "Parties" })
local function achat(name, price)
	local times, minutes = {}, {}
	for _, run in parties.Moyen do
		for _, bought in run.Achats do
			if bought.Name == name then
				table.insert(times, bought.T)
				table.insert(minutes, bought.Minutes)
				break
			end
		end
	end
	ligne({ name, `${nombre(price)}`, duree(mediane(times)), if #minutes > 0 then fixe(mediane(minutes)) else "—", `{#times}/{#parties.Moyen}` })
end
for _, list in { eco.Tools, eco.Auras, eco.Trails } do
	for _, entry in list do
		if entry.Price > 0 then
			achat(entry.DisplayName, entry.Price)
		end
	end
end
for _, level in { 3, 5, 8, 10, 12, 14, 16, 18, 20 } do
	local name = `Treadmill {level - 1}`
	local times, minutes = {}, {}
	for _, run in parties.Moyen do
		for _, bought in run.Achats do
			if bought.Name == name then
				table.insert(times, bought.T)
				table.insert(minutes, bought.Minutes)
				break
			end
		end
	end
	ligne({ `Tapis niveau {level}`, `${nombre(eco.UpgradeCost("Treadmill", level - 2))}`, duree(mediane(times)), if #minutes > 0 then fixe(mediane(minutes)) else "—", `{#times}/{#parties.Moyen}` })
end

---------------------------------------------------------------------------------------------- 11. aides

titre("11. Aides : de combien elles raccourcissent la zone 6 du joueur moyen")
local moyen = profilDe("Moyen")
local function z6De(runs)
	return mediane(champ(runs, #eco.Zones, "T"))
end
-- 3 fois plus de parties que les autres sections : l'effet d'une aide est du même ordre que l'écart entre
-- deux médianes de 25 parties.
local aidSeeds = seeds * 3
local base = z6De(jouer(eco, moyen, aidSeeds))
local function aide(label, aides)
	Modele.Aides = aides
	local runs = jouer(eco, moyen, aidSeeds)
	Modele.Aides = nil
	local t = z6De(runs)
	local offline, cash, boxes, trucks = {}, {}, {}, {}
	for _, run in runs do
		table.insert(offline, run.Aides.Offline)
		table.insert(cash, run.Aides.Cash)
		table.insert(boxes, run.Aides.Boites)
		table.insert(trucks, run.Aides.Camions)
	end
	ligne({ label, duree(t), if t and base then `{fixe((1 - t / base) * 100, 0)} %` else "—", `${nombre(mediane(offline))}`, `${nombre(mediane(cash))}`, tostring(mediane(boxes)), tostring(mediane(trucks)) })
end
local function reglage(session, perDay, offline, daily, truck)
	return { Session = session * 60, SessionsParJour = perDay, Offline = offline, Daily = daily, Truck = truck, TruckEvery = 600, TruckBoxes = 1 }
end
print(`Médianes de {aidSeeds} parties. Hypothèses : sessions de 45 min, 2 par jour, absence plus longue que le plafond des gains hors ligne (4 h de revenus des présentoirs à chaque retour) ; récompenses toutes réclamées ; un camion toutes les 10 min de jour, dans une zone au hasard, 1 colis rapporté quand il est dans une zone que le joueur braque déjà.`)
print("")
entete({ "Aides comptées", "Entrée en zone 6", "Temps gagné", "Gains hors ligne reçus", "Argent des récompenses", "Colis offerts", "Camions pillés" })
ligne({ "Aucune (référence)", duree(base), "—", "—", "—", "—", "—" })
aide("Gains hors ligne seuls (sessions de 45 min)", reglage(45, 2, true, false, false))
aide("Gains hors ligne seuls (sessions de 90 min)", reglage(90, 1, true, false, false))
aide("Gains hors ligne seuls (sessions de 20 min)", reglage(20, 3, true, false, false))
aide("Récompenses quotidiennes et de temps de jeu seules", reglage(45, 2, false, true, false))
aide("Camion seul", reglage(45, 2, false, false, true))
aide("Les trois (sessions de 45 min)", reglage(45, 2, true, true, true))

---------------------------------------------------------------------------------------------- 12. sensibilité

titre("12. Sensibilité : ce qui fait bouger la zone 6 du joueur moyen")
entete({ "Variante", "Zone 5", "Zone 6", "Part d'entraînement" })
local function essai(label, change, restore)
	change()
	local economy = V2.Construire()
	local runs = jouer(economy, moyen, seeds)
	restore()
	local tapis, braquage = {}, {}
	for _, run in runs do
		table.insert(tapis, run.Temps.Tapis)
		table.insert(braquage, run.Temps.Braquage)
	end
	local a, b = mediane(tapis), mediane(braquage)
	local times = champ(runs, #economy.Zones, "T")
	ligne({ label, duree(mediane(champ(runs, 5, "T"))), if #times < #runs then `{#times}/{#runs} parties, {duree(mediane(times))}` else duree(mediane(times)), `{fixe(a / (a + b) * 100, 0)} %` })
end
local function nothing() end
essai("Proposition telle quelle", nothing, nothing)
local function champDe(tbl, field, value)
	local before = tbl[field]
	return function()
		tbl[field] = value
	end, function()
		tbl[field] = before
	end
end
local growth = V2.Treadmill.CostGrowth
essai(`Prix des niveaux ×{growth - 0.3} par niveau (au lieu de ×{growth})`, champDe(V2.Treadmill, "CostGrowth", growth - 0.3))
essai(`Prix des niveaux ×{growth + 0.3} par niveau`, champDe(V2.Treadmill, "CostGrowth", growth + 0.3))
local function prix(factor)
	local saved = {}
	return function()
		for _, list in { V2.Tools, V2.Auras, V2.Trails } do
			for _, entry in list do
				saved[entry] = entry.Price
				entry.Price *= factor
			end
		end
	end, function()
		for entry, price in saved do
			entry.Price = price
		end
	end
end
essai("Armes, auras et trails 2 fois moins chers", prix(0.5))
essai("Armes, auras et trails 2 fois plus chers", prix(2))
essai("Vigile à 0,9 × vitesse conseillée − 1 (règle d'aujourd'hui, au lieu de + 1)", champDe(V2, "GuardMargin", -1))
essai("Vigile à 0,9 × vitesse conseillée", champDe(V2, "GuardMargin", 0))
essai("Vigile à 0,9 × vitesse conseillée + 2", champDe(V2, "GuardMargin", 2))
local H = Modele.Hypotheses
essai("Avance sur le vigile 10 studs (au lieu de 20)", champDe(H, "GuardGap", 10))
essai("Avance sur le vigile 30 studs", champDe(H, "GuardGap", 30))
local partBefore = moyen.Part
essai("Il obtient 25 % des colis de sa zone (au lieu de 50 %)", function()
	moyen.Part = 0.25
end, function()
	moyen.Part = partBefore
end)
essai("Il obtient 100 % des colis de sa zone", function()
	moyen.Part = 1
end, function()
	moyen.Part = partBefore
end)
print("")
print(`Cycle jour / nuit : {Night.DayDuration} s de jour, {Night.NightDuration} s de nuit (pas de braquage la nuit). Hypothèses : voir Modele.Hypotheses et Modele.Profils.`)
