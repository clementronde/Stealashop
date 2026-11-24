--!nocheck
-- a287 (2026-11-21, Cantin en jeu) : Shared/UnboxPlan et Config/Unbox.New, sans Roblox.
--   N  plusieurs coups pour toutes les raretés (Commun 3 au moins), plus rare = plus de coups (ordre de L-253)
--   C  cote qui monte d'un bout à l'autre (OddsClimb) : départ à 1 IN 2, chaque coup, l'éclatement, chaque silhouette,
--      la révélation sur la vraie cote ; jamais vers le bas, même texte arrondi
--   F  texte de BB_Reveal.Odds (finalOddsText)
local Plan = sharedModule("UnboxPlan", "client")
local Cfg = sharedModule("Config/Unbox", "client")
local Rarities = sharedModule("Config/Rarities", "client")
local New = Cfg.New
local function near(value, target, tolerance)
	return math.abs(value - target) <= tolerance
end

section("N. Nombre d'actions")
check(Plan.count("Common") >= 3, "N1 Commun sans amélioration : au moins 3 actions (" .. Plan.count("Common") .. ")")
local rising, list = true, {}
for i, rarity in Rarities.List do
	local n = Plan.count(rarity.Id)
	table.insert(list, rarity.Id .. " " .. n)
	if i > 1 and n <= Plan.count(Rarities.List[i - 1].Id) then
		rising = false
	end
end
check(rising, "N2 plus rare = plus de coups, strictement (" .. table.concat(list, ", ") .. ")")
check(Plan.count("Common", 1) == Plan.count("Common") + New.ActionsPerUpgrade and Plan.count("Divine", 50) == Plan.MaxSteps, "N3 + ActionsPerUpgrade par amélioration, borné à MaxSteps")
local seed = 287
local function pick(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return 1 + seed % n
end
local all = true
for _, rarity in Rarities.List do
	local p = Plan.parse(Plan.draw(rarity.Id, pick, "Common", 0, 50))
	if p == nil or #p.Steps ~= Plan.count(rarity.Id) or p.Steps[#p.Steps].Action.Id ~= New.FinalAction then
		all = false
		print("    " .. rarity.Id .. " : " .. tostring(p and #p.Steps))
	end
end
check(all, "N4 plans tirés : le nombre d'actions de la table, la masse en dernier")
local common = Plan.parse(Plan.draw("Common", pick, "Common", 0, 10))
check(common ~= nil and #common.Steps == 3 and common.Steps[1].Action.Id ~= "Hammer" and common.Steps[2].Action.Id ~= "Hammer", "N5 Commun : deux actions tirées puis la masse")
local reveal, total = Plan.typical("Common", "Small")
local revealLeg = Plan.typical("Legendary", "Small")
check(reveal > 3 and reveal < revealLeg, string.format("N6 durées : Commun révélé à %.1f s (plus tard qu'avant, 2,1 s), Légendaire à %.1f s", reveal, revealLeg))
local lines = {}
for _, rarity in Rarities.List do
	local r, t = Plan.typical(rarity.Id, "Small")
	table.insert(lines, string.format("%s %.1f/%.1f", rarity.Id, r, t))
end
print("DUREES a287 (révélation/fin, s) : " .. table.concat(lines, " ; "))

section("C. Cote qui monte")
check(New.OddsClimb.Enabled == true and Plan.climbs() and New.OddsClimb.Start == 2, "C0 OddsClimb allumé, départ 1 IN 2")
-- Suite complète d'une scène : départ, chaque Impact attendu de chaque action, l'éclatement, chaque silhouette, la
-- révélation. Rend la suite des valeurs et la suite des textes.
local function sequence(text, rarity)
	local p = Plan.parse(text)
	local values = { Plan.startOdds(p) }
	for index, step in p.Steps do
		local hits = #step.Action.Impacts
		for hit = 1, hits do
			table.insert(values, Plan.climbHit(p, index, hit, hits))
		end
	end
	local burstAt = #values
	local count = Rarities.ById[rarity].Order
	for s = 1, count do
		table.insert(values, Plan.climbSilhouette(p, s, count))
	end
	table.insert(values, p.Odds)
	local texts = {}
	for i, v in values do
		texts[i] = Plan.oddsText(v)
	end
	return values, texts, burstAt, p
end
local function numberOf(text)
	local s = string.match(text, "1 IN ([%d%.]+[KMB]?)")
	local mult = 1
	if string.sub(s, -1) == "K" then
		mult, s = 1e3, string.sub(s, 1, -2)
	elseif string.sub(s, -1) == "M" then
		mult, s = 1e6, string.sub(s, 1, -2)
	elseif string.sub(s, -1) == "B" then
		mult, s = 1e9, string.sub(s, 1, -2)
	end
	return tonumber(s) * mult
end
do
	local _, texts, burstAt = sequence("Saw:Common,Kick:Common,Hammer:Common|10", "Common")
	if VERBOSE or DUREES then
		print("SUITE a287 Commun |10 : " .. table.concat(texts, " → "))
	end
	local distinct, last = 0, nil
	for i = 1, burstAt do
		if texts[i] ~= last then
			distinct += 1
			last = texts[i]
		end
	end
	check(distinct >= 4, "C0b petite vraie cote (10) : au moins 4 cotes différentes jusqu'à l'éclatement (" .. table.concat(texts, " → ") .. ")")
end
local cases = {
	{ "Saw:Common,Kick:Common,Hammer:Common|10", "Common" },
	{ "Saw:Common,Kick:Uncommon,Drill:Uncommon,Search:Rare,Hammer:Rare|37", "Rare" },
	{ "Drill:Legendary,Inspect:Legendary,Drill:Legendary,Kick:Legendary,Saw:Legendary,Hammer:Legendary|10", "Epic" },
	{ "Saw:Common,Kick:Rare,Drill:Rare,Search:Rare,Inspect:Rare,Crowbar:Rare,Kick:Rare,Hammer:Rare|4800000", "Mythic" },
	{ "Saw:Common,Kick:Common,Hammer:Common|1", "Common" },
}
for _, case in cases do
	local values, texts, burstAt = sequence(case[1], case[2])
	local up, upText = true, true
	for i = 2, #values do
		if values[i] < values[i - 1] - 1e-9 then
			up = false
		end
		if numberOf(texts[i]) < numberOf(texts[i - 1]) then
			upText = false
		end
	end
	local final = string.match(case[1], "|(%d+)$")
	local start = math.min(2, tonumber(final))
	check(near(values[1], start, 1e-9), "C1 " .. case[2] .. " |" .. final .. " : départ " .. texts[1])
	check(up and upText, "C2 " .. case[2] .. " |" .. final .. " : jamais vers le bas (" .. table.concat(texts, " → ") .. ")")
	check(texts[#texts] == "1 IN " .. Plan.formatOdds(tonumber(final)), "C3 " .. case[2] .. " : finit sur la vraie cote (" .. texts[#texts] .. ")")
	local share = New.OddsClimb.HitsShare
	local k = New.OddsClimb.Offset
	check(near(math.log((values[burstAt] + k) / (start + k)), share * math.log((tonumber(final) + k) / (start + k)), 1e-6), "C4 " .. case[2] .. " : l'éclatement à HitsShare de la montée")
	if tonumber(final) >= 10 then
		local silhouettesUp = true
		for i = burstAt + 1, #values do
			if values[i] <= values[i - 1] then
				silhouettesUp = false
			end
		end
		check(silhouettesUp, "C5 " .. case[2] .. " : chaque silhouette plus haut que la précédente, la révélation plus haut encore")
	end
end
local p = Plan.parse("Saw:Common,Kick:Common,Hammer:Common|1000")
check(Plan.climbHit(p, 1, 1, 4) > Plan.startOdds(p) and Plan.climbHit(p, 1, 2, 4) > Plan.climbHit(p, 1, 1, 4) and Plan.climbHit(p, 2, 1, 1) > Plan.climbHit(p, 1, 4, 4), "C6 chaque coup monte (dans l'action, puis à l'action suivante)")
check(near(Plan.climbHit(p, 9, 9, 1), Plan.climbHit(p, 3, 1, 1), 1e-9) and near(Plan.climbSilhouette(p, 99, 2), Plan.climbSilhouette(p, 2, 2), 1e-9), "C7 indices hors bornes ramenés")
check(Plan.climbSilhouette(p, 2, 2) < 1000 and near(Plan.climb(p, 1), 1000, 1e-6) and near(Plan.climb(p, -1), 2, 1e-9), "C8 la dernière silhouette reste sous la vraie cote ; climb borné de 0 à 1")

section("F. Texte de BB_Reveal.Odds")
check(Plan.finalOddsText("Saw:Common,Kick:Common,Hammer:Common|10") == "1 IN 10", "F1 cote du plan : « 1 IN 10 »")
check(Plan.finalOddsText("Hammer:Rare|12000") == "1 IN 12K", "F2 grande cote : « 1 IN 12K »")
check(Plan.finalOddsText(nil) == nil and Plan.finalOddsText("n'importe quoi") == nil, "F3 sans plan lisible : nil (ligne cachée)")

summary("scénario plan")
