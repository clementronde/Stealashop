--!nocheck
-- Scénario « upgrade » (a150, 2026-11-14, vague 43) : l'objet offert par une récompense passe par les crans
-- d'amélioration de l'ouverture en base (UnboxService.RollUpgrades, Config/Unbox : UpgradeChance 10 % par cran,
-- UpgradeMax 2, × GetLuck). Sur beaucoup de tirages, la part des objets montés d'un et de deux crans est celle
-- de la table ; chance 0 : aucun cran ; MinRarity toujours respecté.

advance(1000)
startServer()
days(10)
local Unbox = sharedModule("Config/Unbox")
local bob = join("Bob", newProfile8())
advance(1.5)
-- setup51 met la chance à 0 (tirages des autres scénarios sans cran) : ici, la chance par défaut du jeu (1).
UnboxService.GetLuck = function()
	return 1
end

-- Tire n objets offerts et compte les crans (lignes de log de GiveItem).
local function draws(tier, zone, minRarity, n)
	local from = #LOG
	local rarities = {}
	for _ = 1, n do
		local uid, _, itemId = UnboxService.GiveItem(bob, tier, zone, minRarity)
		if uid then
			local r = Items.ById[itemId].Rarity
			rarities[r] = (rarities[r] or 0) + 1
			dataOf(bob).Items[uid] = nil
		end
	end
	local one, two, gifts = 0, 0, 0
	for i = from + 1, #LOG do
		local text = LOG[i].text
		if string.find(text, "objet offert", 1, true) then
			gifts += 1
			if string.find(text, ", 1 cran(s) :", 1, true) then
				one += 1
			elseif string.find(text, ", 2 cran(s) :", 1, true) then
				two += 1
			end
		end
	end
	return gifts, one, two, rarities
end

-- Part attendue d'après la table : chaque rareté de départ (tirée chance 0) peut monter de k crans au plus
-- (RollUpgrades avec une chance de 1 : tous les crans possibles) ; P(1 cran) = c(1 - c) si k ≥ 2, c si k = 1 ;
-- P(2 crans) = c² si k ≥ 2.
local function expected(tier, zone, minRarity, n)
	local base = UnboxService.GetLuck
	UnboxService.GetLuck = function()
		return 0
	end
	local gifts, one, two, rarities = draws(tier, zone, minRarity, n)
	UnboxService.GetLuck = base
	check(one == 0 and two == 0 and gifts == n, `{tier} zone {zone} chance 0 : aucun cran sur {n}`)
	local c = Unbox.UpgradeChance
	local p1, p2 = 0, 0
	for rarity, count in rarities do
		local box = { Tier = tier, Zone = zone, ItemId = "", Rarity = rarity, At = 0 }
		local k = #UnboxService.RollUpgrades(box, 1 / c, Random.new(1))
		local p = count / gifts
		if k >= 2 then
			p1 += p * c * (1 - c)
			p2 += p * c * c
		elseif k == 1 then
			p1 += p * c
		end
	end
	return p1, p2
end

local N = 4000
for _, case in { { "Standard", 3, nil }, { "Premium", 4, nil }, { "Luxe", 4, "Epic" } } do
	local tier, zone, minRarity = case[1], case[2], case[3]
	section(`{tier} zone {zone}{if minRarity then " (au moins " .. minRarity .. ")" else ""}`)
	local p1, p2 = expected(tier, zone, minRarity, N)
	local gifts, one, two, rarities = draws(tier, zone, minRarity, N)
	local s1 = math.sqrt(math.max(p1 * (1 - p1), 1e-6) / gifts)
	local s2 = math.sqrt(math.max(p2 * (1 - p2), 1e-6) / gifts)
	check(p1 > 0, `la table permet un cran ici (attendu {string.format("%.2f", p1 * 100)} %)`)
	check(math.abs(one / gifts - p1) <= 4 * s1 + 0.002, `1 cran : {string.format("%.2f", one / gifts * 100)} % pour {string.format("%.2f", p1 * 100)} % attendus`)
	check(math.abs(two / gifts - p2) <= 4 * s2 + 0.002, `2 crans : {string.format("%.2f", two / gifts * 100)} % pour {string.format("%.2f", p2 * 100)} % attendus`)
	if minRarity then
		local below = 0
		for rarity, count in rarities do
			if Rarities.ById[rarity].Order < Rarities.ById[minRarity].Order then
				below += count
			end
		end
		check(below == 0, `aucun objet sous {minRarity} (les crans ne font que monter)`)
	end
end

section("chance du joueur ×10 : chaque cran possible réussit")
local base = UnboxService.GetLuck
UnboxService.GetLuck = function()
	return 10
end
local gifts, one, two = draws("Standard", 3, nil, 200)
UnboxService.GetLuck = base
check(gifts == 200 and one + two > 0, `GetLuck est lu ({one} à 1 cran, {two} à 2 crans sur 200)`)
check(logCount("[UnboxService]", "WARN") == 0, "aucun avertissement d'UnboxService")
summary("scénario upgrade")
