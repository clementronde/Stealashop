-- Scénarios du banc a262 (vague 76). Décisions de Cantin et Clément du 19/11 (consigne wave76-studio.md).
CHECKS, FAILS = 0, 0
local function check(ok, label)
	CHECKS += 1
	if not ok then
		FAILS += 1
		print("ÉCHEC : " .. label)
	elseif RAPPORT then
		print("ok : " .. label)
	end
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-9) * math.max(1, math.abs(b))
end

local Rarities = shared("Config/Rarities")
local ShelfBoxes = shared("Config/ShelfBoxes")
local ShelfOpen = shared("Config/ShelfOpen")
local Items = shared("Config/Items")
local Formulas = shared("Config/Formulas")
local Mutations = shared("Config/Mutations")
local ItemWeight = shared("ItemWeight")
local ItemOdds = shared("ItemOdds")
local UnboxPlan = shared("UnboxPlan")

local ORDER = {}
for _, r in Rarities.List do
	ORDER[r.Id] = r.Order
end

print("== A. Raretés par zone (décision 1)")
local EXPECTED = {
	{ "Common" },
	{ "Common", "Uncommon" },
	{ "Common", "Uncommon", "Rare" },
	{ "Common", "Uncommon", "Rare", "Epic" },
	{ "Uncommon", "Rare", "Epic", "Legendary" },
	{ "Rare", "Epic", "Legendary", "Mythic", "Secret" },
}
for zone, want in EXPECTED do
	local got = ShelfBoxes.ZoneRarities[zone] or {}
	check(table.concat(got, ",") == table.concat(want, ","), `zone {zone} : raretés {table.concat(want, ", ")} (obtenu {table.concat(got, ", ")})`)
	local odds = ShelfBoxes.ZoneOdds[zone] or {}
	local total, keys = 0, 0
	for id, pct in odds do
		total += pct
		keys += 1
		check(table.find(want, id) ~= nil and pct > 0, `zone {zone} : colis {id} permis et > 0`)
	end
	check(keys == #want and near(total, 100), `zone {zone} : chances des colis = 100 (obtenu {total})`)
	check(not ShelfBoxes.Allows(zone, "Divine"), `zone {zone} : jamais de Divine`)
end
for zone = 1, 5 do
	check(not ShelfBoxes.Allows(zone, "Secret"), `zone {zone} : pas de Secret`)
end
check(ShelfBoxes.FirstZone.Common == 1 and ShelfBoxes.FirstZone.Rare == 3 and ShelfBoxes.FirstZone.Mythic == 6 and ShelfBoxes.FirstZone.Secret == 6, "FirstZone : Commun 1, Rare 3, Mythique 6, Secret 6")
-- Repères de la décision 5 : sur la VRAIE part des objets (Cantin, 20/11 : « Viser l'objet »), section F.

print("== B. Colis à type : leur propre table (zone 1 : Commun seul) ; contenu des rayons limité à la zone (décision 3)")
for zone = 1, 6 do
	for tier, own in Rarities.BoxOdds do
		local odds = ShelfBoxes.OddsFor(zone, tier)
		local same = odds ~= nil
		for id, pct in own do
			same = same and math.abs(((odds :: any)[id] or 0) - pct) < 1e-9
		end
		if zone == 1 then
			check(odds ~= nil and near(odds.Common or 0, 100), `OddsFor(1, {tier}) : Commun seul`)
		else
			check(same, `OddsFor({zone}, {tier}) : la table du type, inchangée`)
		end
	end
	for _, boxRarity in ShelfBoxes.ZoneRarities[zone] do
		for _, entry in ShelfOpen.LuckTable do
			local weights = ShelfBoxes.ContentWeights(boxRarity, entry.Luck, zone)
			local total, outside = 0, false
			for id, w in weights or {} do
				total += w
				outside = outside or not ShelfBoxes.Allows(zone, id)
			end
			check(weights ~= nil and total > 0 and not outside, `contenu d'un colis {boxRarity} en zone {zone}, chance ×{entry.Luck} : raretés de la zone`)
		end
	end
end
local R: any = { NextNumber = function(_) return 0.5 end }
for _, id in { "Common", "Uncommon", "Rare", "Mythic", "Secret" } do
	check(Items.Pick(1, id, R) == nil or Items.Pick(1, id, R).Rarity == id, `Pick(1, {id})`)
end
check(Items.Pick(2, "Secret", R) == nil and Items.Pick(6, "Secret", R) ~= nil, "Secret tiré seulement en zone 6 (Items.Pick)")
check(Rarities.GrabTime("Common") == 0.3 and Rarities.GrabTime("Uncommon") == 0.3 and Rarities.GrabTime("Epic") == 0.6 and Rarities.GrabTime("Legendary") == 1 and Rarities.GrabTime(nil) == 0.3, "Rarities.GrabTime : 0,3 / 0,6 / 1 s, 0,3 si inconnue")
check(ShelfBoxes.GrabTime("Common") == 0.3 and ShelfBoxes.GrabTime("Rare") == 0.6 and ShelfBoxes.GrabTime("Mythic") == 1, "temps de prise 0,3 / 0,6 / 1 s")

print("== C. Catalogue : aucune rareté hors zone (décision 2)")
local byZone = {}
for _, item in Items.List do
	if item.Zone then
		byZone[item.Zone] = byZone[item.Zone] or {}
		table.insert(byZone[item.Zone], item)
		if item.TutorialOnly then
			check(item.Id == "Z1_PotDeNouilles" and item.Rarity == "Rare", "seul objet du tuto : Pot de nouilles, Rare (inchangé)")
		else
			check(ShelfBoxes.Allows(item.Zone, item.Rarity), `{item.Id} ({item.Rarity}) : rareté de sa zone {item.Zone}`)
		end
	else
		check(item.Rarity == "Secret" or item.Rarity == "Divine", `{item.Id} sans zone : Secret ou Divine`)
	end
end
for zone = 1, 6 do
	for _, rarityId in ShelfBoxes.ZoneRarities[zone] do
		local pool = Items.AllZones[rarityId] or (Items.ByZone[zone] or {})[rarityId]
		check(pool ~= nil and #pool > 0, `zone {zone} : au moins un objet {rarityId} tirable`)
	end
end

print("== D. Revenus (décision 4) et ordre de l'index (décision 7)")
check(Formulas.ItemIncome("Z1_CanetteDeSoda") == 1, "Canette de soda : 1 $/s")
local BASE = { Common = 1, Uncommon = 8, Rare = 60, Epic = 450, Legendary = 3500, Mythic = 25000, Secret = 150000 }
for id, value in BASE do
	check(Rarities.ById[id].Income == value, `revenu de base {id} = {value}`)
end
for _, item in Items.List do
	local first = ShelfBoxes.FirstZone[item.Rarity] or 1
	local above = if item.Zone then math.max(item.Zone - first, 0) else 0
	local want = Rarities.ById[item.Rarity].Income * (1 + 0.25 * above) * 1.1 ^ (item.Rank - 1)
	check(near(Formulas.ItemIncome(item.Id), want), `{item.Id} : revenu = base × (1 + 25 % × {above}) × 1,1^{item.Rank - 1}`)
end
for zone = 1, 6 do
	local list = byZone[zone]
	local increasing = true
	for i = 2, #list do
		local a, b = list[i - 1], list[i]
		increasing = increasing and ORDER[a.Rarity] <= ORDER[b.Rarity] and Formulas.ItemIncome(a.Id) < Formulas.ItemIncome(b.Id)
	end
	check(increasing, `zone {zone} : index par rareté puis revenu, revenus strictement croissants`)
end

print("== E. Améliorations de l'ouverture plafonnées à la zone")
for zone = 1, 6 do
	local list = ShelfBoxes.ZoneRarities[zone]
	local top = list[#list]
	local ok = true
	for _, start in list do
		local n = UnboxPlan.upgrades(start, 1000, function()
			return 0
		end, top)
		local reached = Rarities.List[ORDER[start] + n]
		ok = ok and reached ~= nil and (ORDER[reached.Id] <= ORDER[top] or reached.Id == start)
	end
	check(ok, `zone {zone} : améliorations jamais au-dessus de {top}`)
end

print("== F. Vraie cote « 1 IN N » (décisions 5 et 6)")
local sizes = { false }
if ItemWeight.Enabled() then
	table.insert(sizes, "Huge")
	table.insert(sizes, "Colossal")
else
	for _, s in Mutations.Sizes do
		table.insert(sizes, s.Id)
	end
end
local effects = { false }
for _, e in Mutations.Effects do
	table.insert(effects, e.Id)
end
local function mutation(size, effect)
	if not size and not effect then
		return nil
	end
	return { Size = size or nil, Effect = effect or nil }
end
local perZone = {}
for zone = 1, 6 do
	local total = 0
	local byRarity = {}
	local members = {}
	for _, item in Items.List do
		local itemZone = item.Zone or ShelfBoxes.FirstZone[item.Rarity]
		if itemZone == zone and not item.TutorialOnly then
			table.insert(members, item)
			for _, s in sizes do
				for _, e in effects do
					local c = ItemOdds.Chance(item.Id, mutation(s, e)) or 0
					total += c
					byRarity[item.Rarity] = (byRarity[item.Rarity] or 0) + c
				end
			end
		end
	end
	perZone[zone] = { members = members, byRarity = byRarity }
	check(near(total, 1, 1e-6), `zone {zone} : les chances de tous les objets, tailles et effets font 1 (obtenu {total})`)
	-- Une rareté plus haute est toujours plus rare : l'objet moyen d'une rareté est moins probable que l'objet moyen de
	-- la rareté en dessous (Cantin, 20/11 : la plus basse ≈ la moitié ; en zone 3, Commun 50 % et Peu commun 48 % : le
	-- dernier Commun de l'index passe sous le premier Peu commun, objet par objet ; noté dans le rapport).
	local count, mean = {}, {}
	for _, item in members do
		count[item.Rarity] = (count[item.Rarity] or 0) + 1
	end
	for id, n in count do
		mean[id] = (byRarity[id] or 0) / n
	end
	local ordered = true
	for a, ma in mean do
		for b, mb in mean do
			if ORDER[a] < ORDER[b] then
				ordered = ordered and ma > mb
			end
		end
	end
	check(ordered, `zone {zone} : l'objet moyen d'une rareté plus haute a une plus petite chance`)
	if RAPPORT then
		for _, a in members do
			for _, b in members do
				if ORDER[a.Rarity] < ORDER[b.Rarity] and (ItemOdds.Chance(a.Id) or 0) <= (ItemOdds.Chance(b.Id) or 0) then
					print(`croisement Z{zone} : {a.Id} ({a.Rarity}, {ItemOdds.Format(ItemOdds.OneIn(a.Id) or 0)}) <= {b.Id} ({b.Rarity}, {ItemOdds.Format(ItemOdds.OneIn(b.Id) or 0)})`)
				end
			end
		end
	end
end
-- Repères de Cantin (20/11, « Viser l'objet ») : vraie part de chaque rareté d'OBJET par zone, à la chance moyenne
-- (LuckTable, celle de la cote : somme des ItemOdds.Chance ci-dessus) et à ×1 (colis × contenu, ContentWeights).
local function shareAt(zone: number, luck: number): { [string]: number }
	local out = {}
	for boxRarity, pct in ShelfBoxes.ZoneOdds[zone] do
		local weights = ShelfBoxes.ContentWeights(boxRarity, luck, zone) or {}
		local total = 0
		for _, w in weights do
			total += w
		end
		for id, w in weights do
			out[id] = (out[id] or 0) + pct / 100 * w / total
		end
	end
	return out
end
A262_SHARE_AT = shareAt
local NEWEST = { [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary" }
for zone = 2, 6 do
	for _, case in { { "moyenne", perZone[zone].byRarity }, { "×1", shareAt(zone, 1) } } do
		local label, s = case[1], case[2]
		local list = ShelfBoxes.ZoneRarities[zone]
		local low = 100 * (s[list[1]] or 0)
		if zone == 2 then
			check(low >= 97 and low <= 99, `zone 2 ({label}) : Commun = le reste, de 97 à 99 % ({string.format("%.3f", low)} %)`)
		else
			check(low >= 45 and low <= 55, `zone {zone} ({label}) : la plus basse ≈ la moitié ({string.format("%.3f", low)} %)`)
		end
		if NEWEST[zone] then
			local pct = 100 * (s[NEWEST[zone]] or 0)
			check(pct >= 1 and pct <= 3, `zone {zone} ({label}) : la rareté qui apparaît ({NEWEST[zone]}) de 1 à 3 % ({string.format("%.3f", pct)} %)`)
		else
			local my, se = 100 * (s.Mythic or 0), 100 * (s.Secret or 0)
			check(my >= 0.4 and my <= 0.6, `zone 6 ({label}) : Mythique ≈ 0,5 % ({string.format("%.4f", my)} %)`)
			check(se >= 0.02 and se <= 0.05, `zone 6 ({label}) : Secret de 0,02 à 0,05 % ({string.format("%.4f", se)} %)`)
		end
	end
end
-- Le contenu peut toujours monter (une caisse ne garantit rien), réduit par cran sur les rayons (ShelfStepUp).
local up = ShelfBoxes.ContentWeights("Common", 1, 2)
local free = ShelfBoxes.ContentWeights("Common", 1, nil)
check(up ~= nil and (up.Uncommon or 0) > 0 and near(up.Uncommon / up.Common, ShelfOpen.ShelfStepUp * ShelfOpen.BoxRarityOdds.Common.Uncommon / ShelfOpen.BoxRarityOdds.Common.Common), "rayon : un colis Commun peut donner un Peu commun, poids × ShelfStepUp")
local up2 = ShelfBoxes.ContentWeights("Rare", 3, 6)
check(up2 ~= nil and near(up2.Legendary / up2.Rare, 3 * ShelfOpen.ShelfStepUp ^ 2 * ShelfOpen.BoxRarityOdds.Rare.Legendary / ShelfOpen.BoxRarityOdds.Rare.Rare), "rayon : deux crans au-dessus, × ShelfStepUp² × la chance")
check(free ~= nil and near(free.Uncommon / free.Common, ShelfOpen.BoxRarityOdds.Common.Uncommon / ShelfOpen.BoxRarityOdds.Common.Common), "sans zone (événement) : table inchangée")
local okN = true
for _, item in Items.List do
	if not item.TutorialOnly and item.Rarity ~= "Divine" then
		for _, s in sizes do
			for _, e in effects do
				local m = mutation(s, e)
				local c = ItemOdds.Chance(item.Id, m)
				local n = ItemOdds.OneIn(item.Id, m)
				local exact = if c then 1 / c else 0
				local off = if exact < 100 then math.abs(n - exact) > 0.5 else math.abs(n * c - 1) > 0.06
				if c == nil or n == nil or n < 1 or off then
					okN = false
					print(`   {item.Id} {s} {e} : chance {c}, N {n}`)
				end
			end
		end
	end
end
check(okN, "1 IN N = 1 / vraie chance, entier sous 100 (écart ≤ 0,5), sinon 2 chiffres (écart ≤ 6 %)")
check(ItemOdds.Chance("Z1_PotDeNouilles") == nil, "objet du tuto : pas de cote")
check(Formulas.UnboxOdds(1 / 37.4) == 37 and Formulas.UnboxOdds(1 / 12345) == 12000 and Formulas.UnboxOdds(1 / 1_560_000) == 1_600_000, "arrondi lisible (37, 12K, 1.6M)")
check(UnboxPlan.formatOdds and UnboxPlan.formatOdds(2_000_000_000) == "2B", "« 2B » au-delà du milliard")

print("== G. Chaque module de Config se charge (contrôles au chargement : Rebirths, Items…)")
local configKeys = {}
for key in SOURCES do
	if string.sub(key, 1, 7) == "Config/" then
		table.insert(configKeys, key)
	end
end
table.sort(configKeys)
for _, key in configKeys do
	local name = string.gsub(string.sub(key, 8), "%.luau$", "")
	local ok, err = pcall(shared, "Config/" .. name)
	check(ok, `Config/{name} se charge{if ok then "" else " (" .. tostring(err) .. ")"}`)
end
local Rebirths = shared("Config/Rebirths")
for _, tier in Rebirths.Tiers do
	local def = Items.ById[tier.ItemId]
	check(def ~= nil and def.Rarity == tier.Rarity and Rarities.Allows(tier.Zone, tier.Rarity), `renaissance {tier.Level} : {tier.ItemId} {tier.Rarity}, rareté de sa zone`)
end


if RAPPORT then
	print("== Rapport")
	for zone = 1, 6 do
		local parts = {}
		for _, item in perZone[zone].members do
			table.insert(parts, `{item.Id:gsub("^Z%d_", "")} {item.Rarity:sub(1, 1)} {string.format("%.4g", Formulas.ItemIncome(item.Id))}`)
		end
		print(`Z{zone} index : {table.concat(parts, " | ")}`)
		local odds = {}
		for _, id in ShelfBoxes.ZoneRarities[zone] do
			table.insert(odds, `{id} colis {ShelfBoxes.ZoneOdds[zone][id]} % objet {string.format("%.3f", 100 * (perZone[zone].byRarity[id] or 0))} %`)
		end
		print(`Z{zone} chances : {table.concat(odds, " ; ")}`)
	end
	local function show(label, id, m)
		print(`N {label} : {id} {ItemOdds.OneIn(id, m)} ({ItemOdds.Format(ItemOdds.OneIn(id, m))}) chance {ItemOdds.Chance(id, m)}`)
	end
	show("le plus commun de Z1", "Z1_CanetteDeSoda", nil)
	show("Rare de Z3", "Z3_ConsoleDeSalon", nil)
	show("Mythique de Z6 sans mutation", "Z6_StatueDeLaLiberte", nil)
	show("Gold", "Z6_StatueDeLaLiberte", { Effect = "Gold" })
	show("Colossal Rainbow", "Z6_StatueDeLaLiberte", { Size = "Colossal", Effect = "Rainbow" })
	show("Secret", Items.AllZones.Secret[1].Id, nil)
	show("Secret Colossal Rainbow", Items.AllZones.Secret[1].Id, { Size = "Colossal", Effect = "Rainbow" })
	show("Canette Colossal Rainbow", "Z1_CanetteDeSoda", { Size = "Colossal", Effect = "Rainbow" })
	local TOP = { [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary", [6] = "Secret" }
	for zone = 2, 6 do
		local parts = {}
		for _, luck in { 1, 3, 10 } do
			local s = A262_SHARE_AT(zone, luck)
			table.insert(parts, string.format("×%d %.4f %%", luck, 100 * (s[TOP[zone]] or 0)) .. (if zone == 6 then string.format(" (Mythique %.4f %%)", 100 * (s.Mythic or 0)) else ""))
		end
		print(`Z{zone} {TOP[zone]} : {table.concat(parts, " ; ")}`)
	end
	for _, w in WARNS do
		print("warn : " .. w)
	end
end

-- Correction 2 (Cantin, 20/11) : prix remis à l'échelle des nouveaux revenus. Améliorations en liste de prix (Costs),
-- toujours croissante, lue par Formulas.UpgradeCost ; prix d'argent du jeu croissants dans chaque famille.
local Upgrades = shared("Config/Upgrades")
local Tools = shared("Config/Tools")
local Cosmetics = shared("Config/Cosmetics")
local SkillTree = shared("Config/SkillTree")
local Monetization = shared("Config/Monetization")
for _, up in Upgrades.List do
	local costs = up.Costs
	check(costs ~= nil and #costs == up.MaxLevel, `{up.Id} : Costs a MaxLevel prix`)
	if costs ~= nil then
		local ok = true
		for n = 0, up.MaxLevel - 1 do
			ok = ok and Formulas.UpgradeCost(up.Id, n) == costs[n + 1] and (n == 0 or costs[n + 1] > costs[n])
		end
		check(ok, `{up.Id} : Formulas.UpgradeCost lit Costs, prix croissants`)
		check(Formulas.UpgradeCost(up.Id, up.MaxLevel) == nil, `{up.Id} : rien au-delà du maximum`)
	end
end
check(Upgrades.ById.Treadmill.Costs[1] == 150 and Upgrades.ById.Treadmill.Costs[19] == 35e9, "tapis : 150 au 1er niveau, 35 B au dernier (V0 proposé, Cantin 20/11)")
check(Upgrades.ById.DisplaySlots.Costs[1] == 500 and Upgrades.ById.DisplaySlots.Costs[16] == 4.3e6, "présentoirs : 500 puis 4,3 M au dernier")
local function rising(list, label)
	local ok, last = true, -1
	for _, x in list do
		ok = ok and x.Price > last
		last = x.Price
	end
	check(ok, `{label} : prix croissants`)
end
rising(Tools.List, "outils")
rising(Cosmetics.Auras, "auras")
rising(Cosmetics.Trails, "traînées")
check(Tools.ById.Wrench.Price == 300 and Tools.ById.Crowbar.Price == 3_100 and Tools.ById.AngleGrinder.Price == 69e6, "outils : clé 300, pied-de-biche 3 100, disqueuse 69 M")
check(Rebirths.Tiers[1].Cash == 170e6 and Rebirths.Tiers[10].Cash == 76e9, "renaissances : 170 M puis 76 B à la 10e")
check(SkillTree.ById.Walls.Prices[1] == 1_300, "arbre : Walls 1 300 au 1er niveau")
check(Monetization.StarterPack.Cash == 2_600, "pack de départ : 2 600 $")
local starter
for _, p in Monetization.Products do
	if p.Key == "StarterPack" then
		starter = p
	end
end
check(starter ~= nil and string.find(starter.Effect, "$2.6K", 1, true) ~= nil, "pack de départ : le texte suit la somme ($2.6K)")

print(string.format("banc a262 (raretés par zone, revenus, vraie cote) : %d vérification(s), %d échec(s)", CHECKS, FAILS))
