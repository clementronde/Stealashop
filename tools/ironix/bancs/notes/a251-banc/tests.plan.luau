--!nocheck
-- a251 : Shared/UnboxPlan, sans Roblox. D tirage ; P relecture ; O cote ; F format ; T durées.
local Plan = sharedModule("UnboxPlan", "client")
local Cfg = sharedModule("Config/Unbox", "client")
local Rarities = sharedModule("Config/Rarities", "client")
local New = Cfg.New

local seed = 12345
local function pick(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return 1 + seed % n
end

section("D. Tirage")
check(New.Enabled == true and New.ActionCount == 5 and New.FinalAction == "Hammer", "D0 Config : allumé, 5 actions, la masse en dernier")
check(#New.Actions == 7, "D0 7 actions (L-237)")
local problems = {}
local seenActions = {}
local upgradesSeen = {}
for _, rarity in Rarities.List do
	for _ = 1, 300 do
		local text = Plan.draw(rarity.Id, pick)
		local plan = text and Plan.parse(text)
		if plan == nil then
			problems["plan illisible : " .. tostring(text)] = true
			continue
		end
		if #text > Plan.MaxLength then
			problems["texte trop long"] = true
		end
		local steps = plan.Steps
		if #steps ~= 5 then
			problems["pas 5 actions"] = true
		end
		if steps[#steps].Action.Id ~= "Hammer" then
			problems["la dernière n'est pas la masse"] = true
		end
		local upgrades = 0
		for i, step in steps do
			seenActions[step.Action.Id] = true
			if i < #steps and step.Action.Id == "Hammer" then
				problems["la masse avant la fin"] = true
			end
			if i > 1 and steps[i - 1].Action.Id == step.Action.Id then
				problems["deux fois la même action de suite"] = true
			end
			if i > 1 and Rarities.ById[step.Rarity].Order < Rarities.ById[steps[i - 1].Rarity].Order then
				problems["rareté qui redescend"] = true
			end
			if i > 1 and step.Rarity ~= steps[i - 1].Rarity then
				upgrades += 1
				if i == #steps then
					problems["amélioration à la dernière action"] = true
				end
			end
		end
		upgradesSeen[rarity.Id] = upgrades
		if steps[1].Rarity ~= New.StartRarity then
			problems["amélioration à la première action"] = true
		end
		if steps[#steps].Rarity ~= rarity.Id then
			problems["la rareté montrée ne finit pas sur la rareté gagnée (" .. rarity.Id .. ")"] = true
		end
		local range = New.OddsRanges[rarity.Id]
		if plan.Odds < range[1] or plan.Odds > range[2] or plan.Odds ~= math.floor(plan.Odds) then
			problems["cote finale hors de la plage de " .. rarity.Id] = true
		end
	end
end
local list = {}
for message in problems do
	table.insert(list, message)
end
check(#list == 0, "D1 2 400 plans tirés, tous conformes" .. (if #list > 0 then " : " .. table.concat(list, " ; ") else ""))
local all = true
for _, action in New.Actions do
	all = all and seenActions[action.Id] == true
end
check(all, "D2 les 7 actions sortent")
check(upgradesSeen.Common == 0 and upgradesSeen.Uncommon == 1 and upgradesSeen.Rare == 2 and upgradesSeen.Epic == 3 and upgradesSeen.Secret == 3, "D3 améliorations : 0 (Commun), 1, 2, puis 3 au plus")
check(Plan.draw("Nope", pick) == nil, "D4 rareté inconnue : pas de plan")

section("P. Relecture")
local good = "Saw:Common,Kick:Uncommon,Drill:Uncommon,Search:Rare,Hammer:Rare|37"
local p = Plan.parse(good)
check(p ~= nil and #p.Steps == 5 and p.Odds == 37 and p.Steps[2].Action.Anim == "Unbox_Kick" and p.Steps[4].Rarity == "Rare", "P1 plan relu")
check(Plan.parse("Saw:Common,Fly:Common|3") == nil, "P2 action inconnue refusée")
check(Plan.parse("Saw:Rare,Kick:Common|3") == nil, "P3 rareté qui redescend refusée")
check(Plan.parse("Saw:Common,Kick:Gold|3") == nil, "P4 rareté inconnue refusée")
check(Plan.parse("Saw:Common|0") == nil and Plan.parse("Saw:Common") == nil and Plan.parse("") == nil and Plan.parse(nil) == nil and Plan.parse(42) == nil, "P5 cote absente ou nulle, vide, autre type : refusés")
check(Plan.parse(string.rep("Saw:Common,", 30) .. "Hammer:Common|3") == nil, "P6 trop long refusé")

section("O. Cote")
local values = {}
for i = 0, 5 do
	values[i] = Plan.oddsAt(p, i)
end
check(values[0] == 2, "O1 départ : le bas de la plage de la première rareté (2)")
local rising = true
for i = 1, 5 do
	rising = rising and values[i] >= values[i - 1]
end
check(rising, "O2 la cote ne redescend jamais")
check(values[1] > 2 and values[1] <= 4 and values[2] >= 5 and values[3] <= 12 and values[3] > values[2], "O3 chaque cote dans la plage de la rareté montrée")
check(values[4] >= 15 and values[5] > values[4] and values[5] < 37, "O4 dans la dernière rareté, la cote reste sous la cote finale (37)")
local c = Plan.parse("Saw:Common,Kick:Common,Drill:Common,Search:Common,Hammer:Common|2")
check(Plan.oddsAt(c, 5) == 2 and Plan.oddsAt(c, 1) == 2, "O5 cote finale au bas de la plage : elle ne bouge pas")

section("F. Format")
check(Plan.formatOdds(2.42) == "2.4" and Plan.formatOdds(3) == "3" and Plan.formatOdds(37.2) == "37", "F1 2.4, 3, 37")
check(Plan.formatOdds(1234) == "1.2K" and Plan.formatOdds(4800) == "4.8K" and Plan.formatOdds(12000) == "12K" and Plan.formatOdds(60000) == "60K", "F2 1.2K, 4.8K, 12K, 60K")
check(Plan.formatOdds(1500000) == "1.5M" and Plan.formatOdds(999.6) == "1K", "F3 1.5M, 1K")
check(Plan.oddsText(37) == "1 IN 37", "F4 « 1 IN 37 »")

section("T. Durées")
local revealCommon, totalCommon = Plan.typical("Common", "Small")
local revealRare = Plan.typical("Rare", "Small")
check(revealCommon >= 7.5 and revealCommon <= 9 and revealRare >= 8 and revealRare <= 9.5, string.format("T1 objet révélé vers 8 à 9 s (Commun %.1f s, Rare %.1f s)", revealCommon, revealRare))
check(totalCommon > revealCommon, "T2 la fin vient après la révélation")
check(math.abs(Plan.revealAt(p, "Rare") - (0.6 + (1.25 + 0.8 + 1.2 + 1.4) + 4 * 0.25 + 0.6 * 0.7 + 0.35 + 2 * 0.45 + 0.6 + 0.1)) < 1e-6, "T3 revealAt : somme des durées de repli")
local okCaps = true
for _, rarity in Rarities.List do
	for _, class in { "Small", "Large", "Colossal" } do
		local _, total = Plan.typical(rarity.Id, class)
		local client, server = Plan.clientMaxSeconds(rarity.Id, class), Plan.serverMaxSeconds(rarity.Id, class)
		okCaps = okCaps and client > total and server > client
	end
end
check(okCaps, "T4 durée typique < plafond du client < plafond du serveur, pour chaque rareté et chaque classe")
for _, rarity in Rarities.List do
	local r, small = Plan.typical(rarity.Id, "Small")
	local _, large = Plan.typical(rarity.Id, "Large")
	local _, colossal = Plan.typical(rarity.Id, "Colossal")
	print(string.format("DUREES %-9s révélé %.1f s ; fin Small %.1f s, Large %.1f s, Colossal %.1f s ; plafonds client/serveur Small %.1f/%.1f s, Colossal %.1f/%.1f s", rarity.Id, r, small, large, colossal, Plan.clientMaxSeconds(rarity.Id, "Small"), Plan.serverMaxSeconds(rarity.Id, "Small"), Plan.clientMaxSeconds(rarity.Id, "Colossal"), Plan.serverMaxSeconds(rarity.Id, "Colossal")))
end

summary("scénario plan")
