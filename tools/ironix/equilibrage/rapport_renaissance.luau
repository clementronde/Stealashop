--!nocheck
-- Rapport des renaissances (Outil/renaissance) dans l'économie v2, passe 3. Tableaux Markdown.
--   RAPPORT=renaissance bash tools/ironix/equilibrage/run.sh
--   RAPPORT=renaissance COURT=1 bash tools/ironix/equilibrage/run.sh   proposition, joueur moyen seulement

local Modele = charge("Outil/modele")
local V2 = charge("Outil/proposition_v2")
local R = charge("Outil/renaissance")
local Items = Config.Items
local Rarities = Config.Rarities

local eco = V2.Construire()
local seeds = OPTIONS.Graines
local maxSeconds = math.max(OPTIONS.Heures, 200) * 3600

local function nombre(value)
	if value == nil then
		return "—"
	end
	return Format.short(value)
end
local function duree(seconds)
	if seconds == nil or seconds ~= seconds then
		return "—"
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
local function trie(list)
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted
end
local function mediane(list)
	if #list == 0 then
		return nil
	end
	local sorted = trie(list)
	return sorted[(#sorted + 1) // 2]
end
local function etendue(list)
	if #list == 0 then
		return "—"
	end
	local sorted = trie(list)
	-- 10e et 90e centiles (25 parties : 3e et 23e)
	local low = sorted[math.max(1, math.floor(#sorted * 0.1 + 0.5))]
	local high = sorted[math.min(#sorted, math.ceil(#sorted * 0.9))]
	return `{duree(sorted[(#sorted + 1) // 2])} ({duree(low)} à {duree(high)})`
end
local function profilDe(id)
	for _, profil in Modele.Profils do
		if profil.Id == id then
			return profil
		end
	end
	return nil
end
local function objetTexte(itemId)
	local item = Items.ById[itemId]
	return `{item.DisplayName} ({Rarities.ById[item.Rarity].DisplayName}, zone {item.Zone})`
end

local function parties(profil, reglages)
	local runs = {}
	for seed = 1, seeds do
		table.insert(runs, R.Partie(eco, profil, seed, reglages, maxSeconds))
	end
	return runs
end
local function colonne(runs, n, field)
	local values = {}
	for _, run in runs do
		local cycle = run.Cycles[n]
		if cycle ~= nil and cycle[field] ~= nil then
			table.insert(values, cycle[field])
		end
	end
	return values
end

-- Tableau détaillé d'une série de parties.
local function detail(runs, reglages)
	local paliers = reglages.Paliers or R.Paliers
	local first = mediane(colonne(runs, 1, "Duree"))
	entete({ "Renaissance", "Argent requis", "Objet requis", "Bonus de revenus", "Durée du cycle", "÷ 1er cycle", "Cible", "Temps cumulé", "Entrée en zone 6 dans le cycle", "Objet trouvé après", "Revenus à la renaissance", "Gardé (3 objets)", "Argent pour la cible" })
	for n, palier in paliers do
		local durations = colonne(runs, n, "Duree")
		local done = #durations
		local med = mediane(durations)
		local revenue = mediane(colonne(runs, n, "Revenu"))
		local target = R.Cible1 * R.Part[n]
		-- Argent qui mettrait la médiane du cycle sur la cible (au rythme des revenus de fin de cycle).
		local suggestion = if med and revenue then math.max(0, palier.Cash + (target - med) * revenue) else nil
		ligne({
			tostring(n),
			nombre(palier.Cash),
			objetTexte(palier.Objet),
			`×{1 + (reglages.Bonus or R.Bonus) * n}`,
			(if done < #runs then `{done}/{#runs} parties, ` else "") .. etendue(durations),
			if med and first then string.format("%d %%", math.floor(med / first * 100 + 0.5)) else "—",
			duree(target),
			etendue(colonne(runs, n, "Fin")),
			etendue(colonne(runs, n, "Zone6")),
			etendue(colonne(runs, n, "Objet")),
			nombre(revenue) .. "/s",
			nombre(mediane(colonne(runs, n, "Garde"))) .. "/s",
			nombre(suggestion),
		})
	end
end

local moyen = profilDe("Moyen")

print(`Renaissances dans l'économie v2 (passe 3) : {seeds} parties par profil ; médiane (10e à 90e centile).`)
print(`Bonus +{math.floor(R.Bonus * 100)} % de revenus par renaissance, {R.Garde} objets gardés.`)

titre("R1. Proposition, joueur moyen")
local proposition = parties(moyen, {})
detail(proposition, {})

if OPTIONS.Court then
	return
end

titre("R2. Proposition, les trois profils : temps cumulé à chaque renaissance")
local byProfile = { Moyen = proposition }
for _, id in { "Prudent", "Acharné" } do
	byProfile[id] = parties(profilDe(id), {})
end
entete({ "Profil", "R1", "R2", "R3", "R4", "R5", "R6", "R7", "R8", "R9", "R10" })
for _, id in { "Prudent", "Moyen", "Acharné" } do
	local cells = { id }
	for n = 1, 10 do
		local values = colonne(byProfile[id], n, "Fin")
		cells[n + 1] = if #values == 0 then "—" else duree(mediane(values)) .. (if #values < seeds then ` ({#values}/{seeds})` else "")
	end
	ligne(cells)
end

titre("R3. Variantes (joueur moyen) : temps cumulé et durée du cycle")
local variantes = {
	{ "Proposition", {}, proposition },
	{ "Sans objet gardé", { Garde = 0 } },
	{ "1 objet gardé", { Garde = 1 } },
	{ "+100 % par renaissance", { Bonus = 1 } },
	{ "+25 % par renaissance", { Bonus = 0.25 } },
	{ "Sans Marteau-piqueur gardé", { SansOutil = true } },
	{ "Sans Fortune Tower", { SansFortune = true } },
	{ "Tableau de la Partie 2 (10 K$ ×10)", { Paliers = R.PartieDeux } },
}
entete({ "Variante", "R1", "R2", "R4", "R6", "R8", "R10", "Cycle 2 ÷ cycle 1", "Cycle 10 ÷ cycle 1", "Plus court ÷ cycle 1" })
for _, variante in variantes do
	local runs = variante[3] or parties(moyen, variante[2])
	local first = mediane(colonne(runs, 1, "Duree"))
	local cells = { variante[1] }
	for _, n in { 1, 2, 4, 6, 8, 10 } do
		local values = colonne(runs, n, "Fin")
		table.insert(cells, if #values == 0 then "—" else duree(mediane(values)))
	end
	local shortest = math.huge
	for n = 2, 10 do
		local med = mediane(colonne(runs, n, "Duree"))
		if med then
			shortest = math.min(shortest, med)
		end
	end
	local function part(n)
		local med = mediane(colonne(runs, n, "Duree"))
		return if med and first then string.format("%d %%", math.floor(med / first * 100 + 0.5)) else "—"
	end
	table.insert(cells, part(2))
	table.insert(cells, part(10))
	table.insert(cells, if shortest < math.huge and first then string.format("%d %%", math.floor(shortest / first * 100 + 0.5)) else "—")
	ligne(cells)
end

titre("R4. Zone 6 (décision 4) : vitrine de 108.8M, chrono de 8 s, dégâts k × D (D = 2M)")
entete({ "k (outil ou aura de renaissance ÷ Angle Grinder × Royal)", "Seul", "Seul, potion ×1,5", "Deux", "Règle tenue ?" })
for _, k in { 1, 1.1, 1.124, 1.25, 1.5, 2, 2.5 } do
	local z = R.Zone6(k)
	local function c(t)
		return if t == math.huge then "jamais" elseif t <= V2.BreakTimer then string.format("%.1f s", t) else string.format("non (%.1f s)", t)
	end
	local ok = z.SeulPotion > V2.BreakTimer and z.Deux <= V2.BreakTimer
	ligne({ tostring(k), c(z.Seul), c(z.SeulPotion), c(z.Deux), if ok then "oui" else "**non**" })
end
