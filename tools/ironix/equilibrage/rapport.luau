--!nocheck
-- Rapport du simulateur d'équilibrage : tableaux Markdown, économie actuelle contre proposition.
-- Lancé par chargeur.luau (bash tools/ironix/equilibrage/run.sh).

local Modele = charge("Outil/modele")
local Proposition = charge("Outil/proposition")

local Balance = Config.Balance
local Upgrades = Config.Upgrades
local Training = Config.Training
local Night = Config.Night

local actuelle = Modele.EcoActuelle()
local proposee = Proposition.Construire()
local ecos = { actuelle, proposee }
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
local function barre(value, low, high, width)
	local count = math.clamp(math.floor((value - low) / (high - low) * width + 0.5), 0, width)
	return string.rep("█", count) .. string.rep("·", width - count)
end

print(`Simulateur d'équilibrage : {seeds} parties par profil, {OPTIONS.Heures} h au plus par partie.`)

---------------------------------------------------------------------------------------------- 1. courbe

titre("1. Vitesse de marche réelle selon la stat Speed (sans trail)")
print("Aujourd'hui : WalkSpeed = min(70, 16 + 0,05 × Vitesse × M trail).")
print("")
entete({ "Vitesse (aujourd'hui)", "WalkSpeed", "16 … 70", "Temps de tapis niveau 0, avec taps" })
for _, speed in { 0, 120, 240, 360, 480, 640, 800, 1100, 2000 } do
	local walk = actuelle.WalkSpeed(speed, 1)
	local rate = actuelle.MachineGain("Treadmill", 0) * (1 + Training.Treadmill.TapBonus)
	ligne({ nombre(speed), string.format("%.1f", walk), barre(walk, 16, 70, 27), duree(speed / rate) })
end
print("")
print("Proposition : WalkSpeed = min(70, 16 + 4 × log10(1 + Speed × M trail / 100)).")
print("")
entete({ "Speed affichée (proposition)", "WalkSpeed", "16 … 70", "Repère" })
local reperes = {
	[3e3] = "panneau zone 2",
	[100e3] = "panneau zone 3",
	[3e6] = "panneau zone 4",
	[100e6] = "panneau zone 5",
	[3e9] = "panneau zone 6",
	[3.2e15] = "plafond",
}
for _, speed in { 0, 100, 1e3, 3e3, 10e3, 100e3, 1e6, 3e6, 10e6, 100e6, 1e9, 3e9, 10e9, 100e9, 1e12, 1e13, 1e14, 1e15, 3.2e15 } do
	local walk = proposee.WalkSpeed(speed, 1)
	ligne({ nombre(speed), string.format("%.1f", walk), barre(walk, 16, 70, 27), reperes[speed] or "" })
end

---------------------------------------------------------------------------------------------- 2. zones

titre("2. Les 6 zones, au seuil du panneau")
for _, eco in ecos do
	print(`**Économie {string.lower(eco.Nom)}**`)
	print("")
	entete({ "Zone", "Speed du panneau", "WalkSpeed", "Strength du panneau (dégâts/coup)", "PV vitrine", "Casse à 4 / 6 / 9 coups/s", "Vigile", "Retour avec colis", "Vigile : écart par seconde", "$/s Commun" })
	for index, zone in eco.Zones do
		local breaks = {}
		for _, hits in { 4, 6, 9 } do
			table.insert(breaks, duree(Modele.BreakTime(zone.WindowHP, zone.AdvisedDamage, hits)))
		end
		local carry = zone.AdvisedSpeed * Balance.Carry.NPCBoxSpeedMultiplier
		ligne({
			tostring(index),
			nombre(zone.SpeedShown),
			string.format("%.1f", zone.AdvisedSpeed),
			nombre(zone.StrengthShown),
			nombre(zone.WindowHP),
			table.concat(breaks, " / "),
			string.format("%.1f", zone.GuardSpeed),
			duree(zone.ReturnDistance / carry),
			string.format("%+.1f", carry - zone.GuardSpeed),
			nombre(zone.BaseIncome),
		})
	end
	print("")
end
print("« Vigile : écart par seconde » : studs que le porteur gagne (+) ou perd (−) sur le vigile chaque seconde, à la vitesse du panneau.")

---------------------------------------------------------------------------------------------- 3. stats à entraîner

titre("3. Stats à entraîner pour un panneau vert, avec le kit d'entrée de la zone")
print("Kit d'entrée : le premier outil, la première aura et le premier trail dont les zones visées (doc 7.2 et 7.4) couvrent la zone.")
print("")
local vert = { Coups = 4, Vert = true, CasseMax = 0.95 * Balance.Window.BreakTimer }
for _, eco in ecos do
	print(`**Économie {string.lower(eco.Nom)}**`)
	print("")
	entete({ "Zone", "Kit (outil, aura, trail)", "Prix du kit", "Vitesse entraînée", "Force entraînée", "Temps de tapis au niveau 0, avec taps", "Niveau de tapis pour le faire en 5 min" })
	for index = 2, #eco.Zones do
		local zone = eco.Zones[index]
		local tool = eco.Tools[math.max(1, Modele.KitIndex(eco.Tools, index))]
		local aura = eco.Auras[Modele.KitIndex(eco.Auras, index)]
		local trail = eco.Trails[Modele.KitIndex(eco.Trails, index)]
		local needSpeed = Modele.Smallest(function(x)
			return eco.WalkSpeed(x, trail.Multiplier) >= zone.AdvisedSpeed * 0.999
		end)
		local needStrength = Modele.Smallest(function(x)
			return eco.HitDamage(tool.Power, x, aura.Multiplier) >= zone.AdvisedDamage * 0.999
		end)
		local tap = 1 + Training.Treadmill.TapBonus
		local level5 = "—"
		for level = 0, Upgrades.ById.Treadmill.MaxLevel do
			if needSpeed / (eco.MachineGain("Treadmill", level) * tap) <= 300 then
				level5 = tostring(level)
				break
			end
		end
		ligne({
			tostring(index),
			`{tool.DisplayName}, {aura.DisplayName} ×{aura.Multiplier}, {trail.DisplayName} ×{trail.Multiplier}`,
			nombre(tool.Price + aura.Price + trail.Price),
			nombre(needSpeed),
			nombre(needStrength),
			duree(needSpeed / (eco.MachineGain("Treadmill", 0) * tap)),
			level5,
		})
	end
	print("")
end

---------------------------------------------------------------------------------------------- 4. machines

titre("4. Tapis et banc : gain et prix par niveau")
print("Gain : par seconde au tapis (× 1,5 avec les taps), par répétition au banc. Prix : celui du passage à ce niveau.")
print("")
entete({ "Niveau", "Gain actuel", "Prix actuel", "Cumul actuel", "Gain proposé", "Prix proposé", "Cumul proposé" })
local totals = { 0, 0 }
for level = 0, Upgrades.ById.Treadmill.MaxLevel do
	local cells = { tostring(level) }
	for index, eco in ecos do
		local price = if level > 0 then eco.UpgradeCost("Treadmill", level - 1) else 0
		totals[index] += price
		table.insert(cells, nombre(eco.MachineGain("Treadmill", level)))
		table.insert(cells, if level > 0 then "$" .. nombre(price) else "—")
		table.insert(cells, "$" .. nombre(totals[index]))
	end
	ligne(cells)
end

---------------------------------------------------------------------------------------------- 5. portes

titre("5. Porte d'une boutique de joueur (niveau de boutique × arbre)")
print("Voleur à 6 coups/s. « Même rang » : ses dégâts sont ceux du panneau de la zone du même numéro que le niveau de la boutique ; « zone au-dessus » : ceux de la zone suivante.")
print("")
local function porte(eco, label, glass, walls, regen)
	print(`**{label}**`)
	print("")
	entete({ "Niveau de boutique", "PV de base", "Sans arbre, même rang", "Sans arbre, zone au-dessus", "Arbre complet : PV", "Arbre complet, même rang", "Arbre complet, zone au-dessus", "Arbre complet, 2 zones au-dessus" })
	local full = glass[#glass] * walls[#walls]
	local fullRegen = regen[#regen]
	for stage = 1, 5 do -- 5 rayons au plus (ShopStageService)
		local base = eco.DoorHP(stage)
		local same = eco.Zones[stage].AdvisedDamage
		local above = eco.Zones[math.min(#eco.Zones, stage + 1)].AdvisedDamage
		local above2 = if eco.Zones[stage + 2] then eco.Zones[stage + 2].AdvisedDamage else nil
		ligne({
			tostring(stage),
			nombre(base),
			duree(Modele.BreakTime(base, same, 6)),
			duree(Modele.BreakTime(base, above, 6)),
			nombre(base * full),
			duree(Modele.BreakTime(base * full, same, 6, fullRegen)),
			duree(Modele.BreakTime(base * full, above, 6, fullRegen)),
			if above2 then duree(Modele.BreakTime(base * full, above2, 6, fullRegen)) else "—",
		})
	end
	print("")
end
porte(actuelle, "Économie actuelle (Glass ×8, Walls ×3, réparation 8 %/s)", actuelle.Glass, actuelle.Walls, actuelle.Regen)
porte(proposee, "Proposition, arbre inchangé (Glass ×8, Walls ×3)", proposee.Glass, proposee.Walls, proposee.Regen)
porte(proposee, "Proposition, variante de l'arbre (Glass ×60, Walls ×10)", Proposition.VarianteArbre.Glass, Proposition.VarianteArbre.Walls, proposee.Regen)

---------------------------------------------------------------------------------------------- 6. parties simulées

local function jouer(eco, profil, count)
	local runs = {}
	for seed = 1, count do
		table.insert(runs, Modele.Jouer(eco, profil, seed, maxSeconds))
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

titre("6. Parties simulées : temps de jeu pour entrer dans chaque zone")
print("Médiane (la plus rapide à la plus lente) du premier colis rapporté de la zone, depuis la première connexion.")
print("")
local parties = {}
entete({ "Économie", "Profil", "Zone 2", "Zone 3", "Zone 4", "Zone 5", "Zone 6", "Plafond de 70 atteint" })
for _, eco in ecos do
	parties[eco.Nom] = {}
	for _, profil in Modele.Profils do
		local runs = jouer(eco, profil, seeds)
		parties[eco.Nom][profil.Id] = runs
		local cells = { eco.Nom, profil.Id }
		for zone = 2, #eco.Zones do
			local times = champ(runs, zone, "T")
			table.insert(cells, if #times < #runs then `{#times}/{#runs} parties, {etendue(times, duree)}` else etendue(times, duree))
		end
		local caps = {}
		for _, run in runs do
			if run.Plafond ~= nil then
				table.insert(caps, run.Plafond)
			end
		end
		table.insert(cells, if #caps == 0 then "jamais" else `{duree(mediane(caps))} ({#caps}/{#runs})`)
		ligne(cells)
	end
end

titre("7. Le joueur moyen à son entrée dans chaque zone (médianes)")
for _, eco in ecos do
	local runs = parties[eco.Nom].Moyen
	print(`**Économie {string.lower(eco.Nom)}**`)
	print("")
	entete({ "Zone", "Temps de jeu", "Speed affichée", "WalkSpeed", "Strength affichée", "Dégâts/coup", "Casse de la vitrine", "Outil", "Tapis / banc", "Présentoirs", "Revenus", "Depuis la zone d'avant : tapis", "banc", "braquages" })
	local previous = { TempsTapis = 0, TempsBanc = 0, TempsBraquage = 0 }
	for zone = 2, #eco.Zones do
		local function m(field)
			return mediane(champ(runs, zone, field))
		end
		local tools = {}
		for _, name in champ(runs, zone, "Outil") do
			tools[name] = (tools[name] or 0) + 1
		end
		local best, bestCount = "—", 0
		for name, count in tools do
			if count > bestCount then
				best, bestCount = name, count
			end
		end
		local now = { TempsTapis = m("TempsTapis"), TempsBanc = m("TempsBanc"), TempsBraquage = m("TempsBraquage") }
		local function since(field)
			return if now[field] then duree(math.max(0, now[field] - previous[field])) else "—"
		end
		ligne({
			tostring(zone),
			duree(m("T")),
			nombre(m("Vitesse")),
			if m("Marche") then string.format("%.1f", m("Marche")) else "—",
			nombre(m("Force")),
			nombre(m("Degats")),
			duree(m("Casse")),
			best,
			if m("Tapis") then `{m("Tapis")} / {m("Banc")}` else "—",
			nombre(m("Presentoirs")),
			if m("Revenu") then "$" .. nombre(m("Revenu")) .. "/s" else "—",
			since("TempsTapis"),
			since("TempsBanc"),
			since("TempsBraquage"),
		})
		for field, value in now do
			previous[field] = value or previous[field]
		end
	end
	print("")
end

titre("8. Répartition du temps et colis jusqu'à la zone 6 (médianes)")
entete({ "Économie", "Profil", "Tapis", "Banc", "Braquages", "Part d'entraînement", "Colis rapportés", "Fois rattrapé" })
for _, eco in ecos do
	for _, profil in Modele.Profils do
		local runs = parties[eco.Nom][profil.Id]
		local function m(pick)
			local values = {}
			for _, run in runs do
				table.insert(values, pick(run))
			end
			return mediane(values)
		end
		local tapis = m(function(run)
			return run.Temps.Tapis
		end)
		local banc = m(function(run)
			return run.Temps.Banc
		end)
		local braquage = m(function(run)
			return run.Temps.Braquage
		end)
		ligne({
			eco.Nom,
			profil.Id,
			duree(tapis),
			duree(banc),
			duree(braquage),
			string.format("%.0f %%", 100 * (tapis + banc) / (tapis + banc + braquage)),
			nombre(m(function(run)
				return run.Colis
			end)),
			nombre(m(function(run)
				return run.Rattrape
			end)),
		})
	end
end

titre("9. Ce que coûte chaque achat au joueur moyen")
print("« Minutes de revenus » : prix divisé par ce qu'il gagne par minute au moment de l'achat (présentoirs et receleur). Le doc vise 3 à 7 min pour un outil (7.2).")
print("")
entete({ "Article", "Prix", "Actuelle : acheté à", "Actuelle : minutes de revenus", "Proposée : acheté à", "Proposée : minutes de revenus" })
local function achat(eco, name)
	local times, minutes = {}, {}
	for _, run in parties[eco.Nom].Moyen do
		for _, purchase in run.Achats do
			if purchase.Name == name then
				table.insert(times, purchase.T)
				table.insert(minutes, purchase.Minutes)
				break
			end
		end
	end
	if #times == 0 then
		return "pas acheté", "—"
	end
	local share = if #times < seeds then ` ({#times}/{seeds})` else ""
	return duree(mediane(times)) .. share, string.format("%.1f", mediane(minutes))
end
for _, list in { actuelle.Tools, actuelle.Auras, actuelle.Trails } do
	for _, entry in list do
		if entry.Price > 0 then
			local t1, m1 = achat(actuelle, entry.DisplayName)
			local t2, m2 = achat(proposee, entry.DisplayName)
			ligne({ entry.DisplayName, "$" .. nombre(entry.Price), t1, m1, t2, m2 })
		end
	end
end
for _, level in { 1, 3, 5, 8, 10, 12, 14, 16, 18, 20 } do
	local name = `Treadmill {level}`
	local t1, m1 = achat(actuelle, name)
	local t2, m2 = achat(proposee, name)
	ligne({ `Tapis niveau {level}`, `${nombre(actuelle.UpgradeCost("Treadmill", level - 1))} / ${nombre(proposee.UpgradeCost("Treadmill", level - 1))}`, t1, m1, t2, m2 })
end
for _, slot in { 5, 8, 12, 16, 20 } do
	local name = `Display {slot}`
	local t1, m1 = achat(actuelle, name)
	local t2, m2 = achat(proposee, name)
	ligne({ `Présentoir n° {slot}`, "$" .. nombre(actuelle.UpgradeCost("DisplaySlots", slot - Balance.Display.StartSlots - 1)), t1, m1, t2, m2 })
end

---------------------------------------------------------------------------------------------- 10. après la zone 6

titre("10. Après la zone 6 : jusqu'où monte la vitesse (proposition)")
print("Tapis au niveau 20, taps, meilleur trail de la proposition, sans gamepass ni renaissance.")
print("")
do
	local best = proposee.Trails[#proposee.Trails].Multiplier
	local rate = proposee.MachineGain("Treadmill", Upgrades.ById.Treadmill.MaxLevel) * (1 + Training.Treadmill.TapBonus) * best
	entete({ "Heures de tapis au niveau 20", "Speed affichée", "WalkSpeed" })
	for _, hours in { 1, 10, 100, 1000 } do
		local shown = rate * hours * 3600
		ligne({ tostring(hours), nombre(shown), string.format("%.1f", proposee.WalkSpeed(shown, 1)) })
	end
end

---------------------------------------------------------------------------------------------- 11. sensibilité

titre("11. Sensibilité de la proposition aux hypothèses du modèle (joueur moyen, zone 6)")
local few = math.min(seeds, 11)
local function essai(label, change, restore)
	change()
	local eco = Proposition.Construire()
	local times, shares = {}, {}
	for _, profil in Modele.Profils do
		if profil.Id == "Moyen" then
			local probe = table.clone(profil)
			if type(restore) == "table" then
				for key, value in restore do
					probe[key] = value
				end
			end
			for seed = 1, few do
				local run = Modele.Jouer(eco, probe, seed, maxSeconds)
				if run.Entrees[#eco.Zones] then
					table.insert(times, run.Entrees[#eco.Zones].T)
				end
				local training = run.Temps.Tapis + run.Temps.Banc
				table.insert(shares, training / (training + run.Temps.Braquage))
			end
		end
	end
	ligne({ label, if #times < few then `{#times}/{few} parties` else duree(mediane(times)), string.format("%.0f %%", 100 * mediane(shares)) })
	if type(restore) == "function" then
		restore()
	end
end
local H = Modele.Hypotheses
local M = Proposition.Machines
local function machines(field, value)
	local before = M.Treadmill[field]
	return function()
		M.Treadmill[field], M.Bench[field] = value, value
	end, function()
		M.Treadmill[field], M.Bench[field] = before, before
	end
end
local function hypothese(field, value)
	local before = H[field]
	return function()
		H[field] = value
	end, function()
		H[field] = before
	end
end
entete({ "Variante", "Entrée en zone 6 (médiane)", "Part d'entraînement" })
essai("Proposition telle quelle", function() end, nil)
essai("Avance sur le vigile 10 studs (au lieu de 20)", hypothese("GuardGap", 10))
essai("Avance sur le vigile 30 studs", hypothese("GuardGap", 30))
essai("Banc : 1 répétition toutes les 1,5 s", hypothese("BenchRepsPerSecond", 1 / 1.5))
essai("Banc : 2 répétitions par seconde", hypothese("BenchRepsPerSecond", 2))
essai("Il obtient 25 % des colis de sa zone (serveur plein)", function() end, { Part = 0.25 })
essai("Il obtient 100 % des colis de sa zone (seul)", function() end, { Part = 1 })
essai("Prix des niveaux ×3 par niveau (au lieu de ×3,6)", machines("CostGrowth", 3))
essai("Prix des niveaux ×4 par niveau", machines("CostGrowth", 4))
essai("Gain ×1,8 par niveau (au lieu de ×2)", machines("GainGrowth", 1.8))
essai("Gain ×2,2 par niveau", machines("GainGrowth", 2.2))
do
	local before = Proposition.GuardMargin
	essai("Vigile à 0,9 × vitesse conseillée − 1 (règle d'aujourd'hui)", function()
		Proposition.GuardMargin = -1
	end, function()
		Proposition.GuardMargin = before
	end)
end
print("")
print(`Cycle jour / nuit : {Night.DayDuration} s de jour, {Night.NightDuration} s de nuit (pas de braquage la nuit). Hypothèses : voir Modele.Hypotheses.`)
