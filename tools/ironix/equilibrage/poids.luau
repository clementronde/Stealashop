--!nocheck
-- Rapport « poids » du simulateur (vague 62, a203) : RAPPORT=poids bash tools/ironix/equilibrage/run.sh
-- Loi du poids de Config/Weight (Shared/ItemWeight) : chances par palier à ×1, ×4 et ×8, 100 000 tirages, taille et
-- revenu par poids, revenu moyen comparé aux anciennes tailles, parties simulées avec et sans le poids.

local Modele = charge("Outil/modele")
local ItemWeight = charge("ItemWeight")
local Weight = Config.Weight
local Mutations = Config.Mutations
local ShelfOpen = Config.ShelfOpen

local seeds = OPTIONS.Graines
local maxSeconds = OPTIONS.Heures * 3600

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
local function pct(value)
	if value >= 1 then
		return string.format("%.2f %%", value)
	elseif value >= 0.01 then
		return string.format("%.3f %%", value)
	end
	return string.format("%.5f %%", value)
end
local function kgText(tier)
	if tier.Max <= tier.Min then
		return ItemWeight.Format(tier.Min)
	end
	return `{ItemWeight.Format(tier.Min)} à {ItemWeight.Format(tier.Max)}`
end

-- Faux Random (Park-Miller), comme Modele.
local function fakeRandom(seed)
	local state = (seed * 7919) % 2147483646 + 1
	return {
		NextNumber = function(_self)
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end,
	}
end

-- Espérance exacte de (kg / Reference) ^ p pour une chance donnée (log-uniforme dans chaque palier).
local function mean(luck, exponent)
	local chances = ItemWeight.TierChances(luck)
	local total = 0
	for index, tier in Weight.Tiers do
		local value
		if tier.Max <= tier.Min then
			value = (tier.Min / Weight.Reference) ^ exponent
		else
			local a, b = tier.Min / Weight.Reference, tier.Max / Weight.Reference
			value = (b ^ exponent - a ^ exponent) / (exponent * math.log(b / a))
		end
		total += chances[index] / 100 * value
	end
	return total
end

local LUCKS = { 1, 4, 8 }

print(`Simulateur, rapport « poids » (vague 62) : {seeds} parties par profil, {OPTIONS.Heures} h au plus par partie.`)

titre("1. Chances par palier (Config/Weight.Tiers ; paliers lourds dès " .. ItemWeight.Format(Weight.LuckFrom) .. " × la chance de la boîte)")
entete({ "Palier", "×1", "×4", "×8", "Taille", "Revenu" })
local tables = {}
for _, luck in LUCKS do
	tables[luck] = ItemWeight.TierChances(luck)
end
for index, tier in Weight.Tiers do
	local lo = ItemWeight.ScaleFor(tier.Min)
	ligne({
		kgText(tier),
		pct(tables[1][index]),
		pct(tables[4][index]),
		pct(tables[8][index]),
		string.format("×%.2f", lo),
		string.format("×%.2f", ItemWeight.IncomeFactor(tier.Min)),
	})
end
print("")
entete({ "Regroupement", "×1", "×4", "×8" })
local function sumWhere(luck, predicate)
	local sum = 0
	for index, tier in Weight.Tiers do
		if predicate(tier) then
			sum += tables[luck][index]
		end
	end
	return sum
end
ligne({ "5 à 50 kg", pct(sumWhere(1, function(t) return t.Min >= 5 and t.Max <= 50 end)), pct(sumWhere(4, function(t) return t.Min >= 5 and t.Max <= 50 end)), pct(sumWhere(8, function(t) return t.Min >= 5 and t.Max <= 50 end)) })
ligne({ "lourds (≥ " .. ItemWeight.Format(Weight.LuckFrom) .. ")", pct(sumWhere(1, function(t) return t.Min >= Weight.LuckFrom end)), pct(sumWhere(4, function(t) return t.Min >= Weight.LuckFrom end)), pct(sumWhere(8, function(t) return t.Min >= Weight.LuckFrom end)) })
ligne({ "Huge (" .. ItemWeight.Format(Weight.HugeFrom) .. " à " .. ItemWeight.Format(Weight.ColossalFrom) .. ")", pct(ItemWeight.SizeChance("Huge", 1)), pct(ItemWeight.SizeChance("Huge", 4)), pct(ItemWeight.SizeChance("Huge", 8)) })
ligne({ "Colossal (≥ " .. ItemWeight.Format(Weight.ColossalFrom) .. ")", pct(ItemWeight.SizeChance("Colossal", 1)), pct(ItemWeight.SizeChance("Colossal", 4)), pct(ItemWeight.SizeChance("Colossal", 8)) })
ligne({ "10 000 kg", pct(tables[1][#Weight.Tiers]), pct(tables[4][#Weight.Tiers]), pct(tables[8][#Weight.Tiers]) })

titre("2. 100 000 tirages (ItemWeight.Roll)")
entete({ "Chance", "Min", "Médiane", "Max", "Huge", "Colossal", "10 000 kg", "Revenu moyen tiré", "Revenu moyen exact" })
for _, luck in LUCKS do
	local rng = fakeRandom(62 + luck)
	local list = {}
	local huge, colossal, top, income = 0, 0, 0, 0
	local count = 100000
	for i = 1, count do
		local kg = ItemWeight.Roll(rng, luck)
		list[i] = kg
		local size = ItemWeight.SizeMutationFor(kg)
		if size == "Huge" then
			huge += 1
		elseif size == "Colossal" then
			colossal += 1
		end
		if kg >= 10000 then
			top += 1
		end
		income += ItemWeight.IncomeFactor(kg)
	end
	table.sort(list)
	ligne({
		`×{luck}`,
		ItemWeight.Format(list[1]),
		ItemWeight.Format(list[count // 2]),
		ItemWeight.Format(list[count]),
		pct(huge / count * 100),
		pct(colossal / count * 100),
		tostring(top),
		string.format("×%.3f", income / count),
		string.format("×%.3f", mean(luck, Weight.IncomeExponent)),
	})
end

titre("3. Taille et revenu selon le poids")
entete({ "Poids", "Taille (ScaleFor)", "Revenu (IncomeFactor)", "Mutation de taille" })
for _, kg in { 1, 2.2, 5, 10, 20, 50, 80, 100, 250, 500, 1000, 1250, 2500, 5000, 10000 } do
	ligne({ ItemWeight.Format(kg), string.format("×%.2f", ItemWeight.ScaleFor(kg)), string.format("×%.2f", ItemWeight.IncomeFactor(kg)), ItemWeight.SizeMutationFor(kg) or "—" })
end

titre("4. Revenu moyen de la taille : anciennes tailles contre poids")
local old = 1
for _, entry in Mutations.Sizes do
	old += entry.Chance / 100 * (entry.IncomeMultiplier - 1)
end
local luckMix, luckTotal = 0, 0
for _, entry in ShelfOpen.LuckTable do
	luckMix += entry.Weight * mean(entry.Luck, Weight.IncomeExponent)
	luckTotal += entry.Weight
end
luckMix /= luckTotal
entete({ "Tirage", "Revenu moyen (taille seule)" })
ligne({ "Anciennes tailles (Tiny, Big, Huge, Colossal)", string.format("×%.3f", old) })
for _, luck in { 1, 1.5, 2, 3, 4, 5, 8, 10 } do
	ligne({ `Poids à ×{luck}`, string.format("×%.3f", mean(luck, Weight.IncomeExponent)) })
end
ligne({ "Poids, chance tirée dans ShelfOpen.LuckTable", string.format("×%.3f", luckMix) })
print("")
print("Migration des profils (Config/Weight.Legacy, revenu d'avant → revenu avec le poids) :")
print("")
entete({ "Taille d'avant", "Revenu d'avant", "Poids donné", "Revenu avec le poids", "Taille du modèle avant → après" })
ligne({ "aucune", "×1", ItemWeight.Format(ItemWeight.LegacyFor(nil)), string.format("×%.2f", ItemWeight.IncomeFactor(ItemWeight.LegacyFor(nil))), "×1 → ×1" })
for _, entry in Mutations.Sizes do
	local kg = ItemWeight.LegacyFor(entry.Id)
	ligne({ entry.Id, `×{entry.IncomeMultiplier}`, ItemWeight.Format(kg), string.format("×%.2f", ItemWeight.IncomeFactor(kg)), string.format("×%s → ×%.2f", tostring(entry.Scale), ItemWeight.ScaleFor(kg)) })
end

titre("5. Parties simulées : économie actuelle, anciennes tailles contre poids (chance de la boîte ×1, puis LuckTable)")
local eco = Modele.EcoActuelle()
local function median(list)
	if #list == 0 then
		return nil
	end
	table.sort(list)
	return list[(#list + 1) // 2]
end
local function duree(seconds)
	if seconds == nil then
		return "—"
	end
	local minutes = math.floor(seconds / 60 + 0.5)
	if minutes < 60 then
		return `{minutes} min`
	end
	return string.format("%d h %02d", minutes // 60, minutes % 60)
end
local function drawLuck(random)
	local roll = random() * luckTotal
	for _, entry in ShelfOpen.LuckTable do
		if roll < entry.Weight then
			return entry.Luck
		end
		roll -= entry.Weight
	end
	return 1
end
local modes = {
	{ Nom = "anciennes tailles", Poids = nil },
	{
		Nom = "poids ×1",
		Poids = {
			Moyenne = mean(1, Weight.IncomeExponent),
			Tirage = function(random)
				return ItemWeight.IncomeFactor(ItemWeight.Roll({ NextNumber = function() return random() end }, 1))
			end,
		},
	},
	{
		Nom = "poids, LuckTable",
		Poids = {
			Moyenne = luckMix,
			Tirage = function(random)
				local luck = drawLuck(random)
				return ItemWeight.IncomeFactor(ItemWeight.Roll({ NextNumber = function() return random() end }, luck))
			end,
		},
	},
}
entete({ "Profil", "Tirage", "Zone 3", "Zone 5", "Zone 6", "Revenu à l'entrée de la zone 6" })
for _, profil in Modele.Profils do
	for _, mode in modes do
		Modele.Poids = mode.Poids
		local times = { [3] = {}, [5] = {}, [6] = {} }
		local incomes = {}
		for seed = 1, seeds do
			local run = Modele.Jouer(eco, profil, seed, maxSeconds)
			for zone, list in times do
				local entry = run.Entrees[zone]
				if entry then
					table.insert(list, entry.T)
				end
			end
			local six = run.Entrees[6]
			if six then
				table.insert(incomes, six.Revenu)
			end
		end
		local inc = median(incomes)
		ligne({ profil.Id, mode.Nom, duree(median(times[3])), duree(median(times[5])), duree(median(times[6])), if inc then Format.income(inc) else "—" })
	end
end
Modele.Poids = nil
