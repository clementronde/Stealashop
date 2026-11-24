--!nocheck
-- a257 (vague 74, L-253, L-258) : Shared/UnboxPlan, sans Roblox. Copie du banc a251 corrigée (nombre d'actions selon le
-- résultat, rareté montrée qui part du colis) : D tirage ; N nombre d'actions ; G améliorations ; L places ; P relecture ;
-- O cote ; F format ; T durées.
local Plan = sharedModule("UnboxPlan", "client")
local Cfg = sharedModule("Config/Unbox", "client")
local Rarities = sharedModule("Config/Rarities", "client")
local New = Cfg.New

local seed = 12345
local function pick(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return 1 + seed % n
end
local function roll()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return (seed % 1000000) / 1000000
end
local function order(id)
	return Rarities.ById[id].Order
end

section("D. Tirage")
check(New.Enabled == true and New.ActionCount == nil and type(New.ActionsByRarity) == "table" and New.FinalAction == "Hammer", "D0 Config : allumé, ActionsByRarity à la place d'ActionCount, la masse en dernier")
check(#New.Actions == 7, "D0 7 actions (L-237)")
local problems = {}
local seenActions = {}
local drawn = 0
for _, rarity in Rarities.List do
	for _, start in { "Common", "Rare", "Epic" } do
		for u = 0, 2 do
			for _ = 1, 40 do
				drawn += 1
				local text = Plan.draw(rarity.Id, pick, start, u)
				local plan = text and Plan.parse(text)
				if plan == nil then
					problems["plan illisible : " .. tostring(text)] = true
					continue
				end
				if #text > Plan.MaxLength then
					problems["texte trop long"] = true
				end
				local steps = plan.Steps
				if #steps ~= Plan.count(rarity.Id, u) then
					problems["pas Plan.count actions"] = true
				end
				if steps[#steps].Action.Id ~= "Hammer" then
					problems["la dernière n'est pas la masse"] = true
				end
				local ups = 0
				for i, step in steps do
					seenActions[step.Action.Id] = true
					if i < #steps and step.Action.Id == "Hammer" then
						problems["la masse avant la fin"] = true
					end
					if i > 1 and steps[i - 1].Action.Id == step.Action.Id then
						problems["deux fois la même action de suite"] = true
					end
					if i > 1 and order(step.Rarity) < order(steps[i - 1].Rarity) then
						problems["rareté qui redescend"] = true
					end
					if i > 1 and step.Rarity ~= steps[i - 1].Rarity then
						ups += 1
						if order(step.Rarity) ~= order(steps[i - 1].Rarity) + 1 then
							problems["amélioration de plus d'un cran"] = true
						end
						if i == #steps then
							problems["amélioration à la dernière action"] = true
						end
					end
				end
				if steps[1].Rarity ~= start then
					problems["la rareté montrée ne part pas du colis (" .. start .. ")"] = true
				end
				if ups ~= u then
					problems[string.format("%d amélioration(s) au lieu de %d", ups, u)] = true
				end
				local range = New.OddsRanges[rarity.Id]
				if plan.Odds < range[1] or plan.Odds > range[2] or plan.Odds ~= math.floor(plan.Odds) then
					problems["cote finale hors de la plage de " .. rarity.Id] = true
				end
			end
		end
	end
end
local list = {}
for message in problems do
	table.insert(list, message)
end
check(#list == 0, string.format("D1 %d plans tirés (raretés × colis × 0 à 2 améliorations), tous conformes", drawn) .. (if #list > 0 then " : " .. table.concat(list, " ; ") else ""))
local all = true
for _, action in New.Actions do
	all = all and seenActions[action.Id] == true
end
check(all, "D2 les 7 actions sortent")
check(Plan.draw("Nope", pick) == nil, "D4 rareté inconnue : pas de plan")
local legend = Plan.parse(Plan.draw("Legendary", pick, "Common", 0))
check(legend ~= nil and legend.Steps[#legend.Steps].Rarity == "Common", "D5 colis Commun sans amélioration, objet Légendaire : la rareté montrée reste Commun (L-253 point 2)")
local unknown = Plan.parse(Plan.draw("Rare", pick, "Nope", 0))
check(unknown ~= nil and unknown.Steps[1].Rarity == New.StartRarity, "D6 rareté de colis inconnue : départ à StartRarity")

section("N. Nombre d'actions (L-253 point 1)")
check(Plan.count("Common") == 1 and Plan.count("Uncommon") == 2, "N1 Commun : la masse seule ; Peu commun : une action puis la masse")
local rising = true
for i = 2, #Rarities.List do
	rising = rising and Plan.count(Rarities.List[i].Id) >= Plan.count(Rarities.List[i - 1].Id)
end
check(rising, "N2 plus la rareté gagnée est haute, plus il y a d'actions")
check(Plan.count("Common", 1) == 3 and Plan.count("Common", 2) == 4 and Plan.count("Rare", 1) == 4, "N3 une amélioration demande une action avant et après : Commun +1 = 3, +2 = 4 ; Rare +1 = 4")
check(Plan.count("Divine", 50) == Plan.MaxSteps and Plan.count("Nope") >= 1, "N4 borné à MaxSteps, rareté inconnue : au moins 1")
local one = Plan.parse(Plan.draw("Common", pick, "Common", 0))
check(one ~= nil and #one.Steps == 1 and one.Steps[1].Action.Id == "Hammer", "N5 Commun sans amélioration : la masse seule")

section("G. Améliorations, tirées à part (L-253 point 2)")
local counts = { [0] = 0, [1] = 0, [2] = 0 }
local over = false
for _ = 1, 4000 do
	local u = Plan.upgrades("Common", 1, roll)
	counts[u] = (counts[u] or 0) + 1
	over = over or u > Cfg.UpgradeMax
end
check(not over, "G1 jamais plus d'UpgradeMax crans")
check(counts[1] > 250 and counts[1] < 550 and counts[2] > 10 and counts[2] < 80, string.format("G2 UpgradeChance 10 %% par cran : 1 cran %d / 4 000, 2 crans %d / 4 000", counts[1], counts[2]))
check(Plan.upgrades("Mythic", 1, function()
	return 0
end) == 0, "G3 jamais jusqu'à Secret")
check(Plan.upgrades("Common", 0, function()
	return 0
end) == 0, "G4 chance nulle : aucune amélioration")
check(Plan.upgrades("Common", 100, function()
	return 0.5
end) == Cfg.UpgradeMax, "G5 chance énorme : UpgradeMax crans")

section("L. Places (L-258)")
local P = New.Places
check(P.Enabled == true and P.Teleport == 0.34 and P.CameraLift == 0.7 and P.OddsSlide == 3.4, "L0 Config : places allumées, téléportation 0,34 s, caméra 0,7, glissement 3,4 studs")
local function joined(t)
	return table.concat(t, ",")
end
check(joined(Plan.places(1, true, true)) == "Top", "L1 une action : sur le colis")
check(joined(Plan.places(5, true, true)) == "Side,Other,Top,Side,Top", "L2 cinq actions : gauche, droite, dessus, gauche, dessus (la dernière sur le colis) : " .. joined(Plan.places(5, true, true)))
check(joined(Plan.places(5, false, false)) == "Side,Other,Side,Side,Side", "L3 sans Unbox_Stomp ni Unbox_Slam : à côté du colis : " .. joined(Plan.places(5, false, false)))
check(joined(Plan.places(4, false, true)) == "Side,Other,Side,Top", "L4 Unbox_Slam seule : la dernière sur le colis : " .. joined(Plan.places(4, false, true)))
local p5 = Plan.parse("Saw:Common,Kick:Common,Drill:Common,Search:Common,Hammer:Common|2")
local moves = Plan.moves(p5, true, true)
check(moves[3].Action.Id == "Stomp" and moves[5].Action.Id == "Slam" and moves[1].Action.Id == "Saw" and moves[4].Action.Id == "Search", "L5 sur le colis : Stomp, et Slam à la dernière")
check(moves[1].Teleport == false and moves[2].Teleport == true and moves[3].Teleport == true and moves[4].Teleport == true and moves[5].Teleport == true, "L6 téléportation à chaque changement de place, pas à la première")
local m3 = Plan.moves(p5, false, false)
check(m3[5].Action.Id == "Hammer" and m3[3].Action.Id == "Drill", "L7 repli : l'action tirée et la masse")
check(near(Plan.transition(true), 0.34, 1e-6) and near(Plan.transition(false), New.ActionGap, 1e-6), "L8 transition : 0,34 s en se téléportant, ActionGap sinon")

section("P. Relecture")
local good = "Saw:Common,Kick:Uncommon,Drill:Uncommon,Search:Rare,Hammer:Rare|37"
local p = Plan.parse(good)
check(p ~= nil and #p.Steps == 5 and p.Odds == 37 and p.Steps[2].Action.Anim == "Unbox_Kick" and p.Steps[4].Rarity == "Rare", "P1 plan relu")
check(Plan.parse("Saw:Common,Fly:Common|3") == nil, "P2 action inconnue refusée")
check(Plan.parse("Saw:Rare,Kick:Common|3") == nil, "P3 rareté qui redescend refusée")
check(Plan.parse("Saw:Common,Kick:Gold|3") == nil, "P4 rareté inconnue refusée")
check(Plan.parse("Saw:Common|0") == nil and Plan.parse("Saw:Common") == nil and Plan.parse("") == nil and Plan.parse(nil) == nil and Plan.parse(42) == nil, "P5 cote absente ou nulle, vide, autre type : refusés")
check(Plan.parse(string.rep("Saw:Common,", 30) .. "Hammer:Common|3") == nil, "P6 trop long refusé")
check(Plan.parse("Hammer:Common|3") ~= nil, "P7 une seule action (la masse) relue")

section("O. Cote")
local values = {}
for i = 0, 5 do
	values[i] = Plan.oddsAt(p, i)
end
check(values[0] == 2, "O1 départ : le bas de la plage de la première rareté (2)")
local up = true
for i = 1, 5 do
	up = up and values[i] >= values[i - 1]
end
check(up, "O2 la cote ne redescend jamais")
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
local revealLeg = Plan.typical("Legendary", "Small")
check(revealCommon < 4 and revealLeg > revealCommon + 3, string.format("T1 Commun bien plus court que Légendaire (%.1f s, %.1f s)", revealCommon, revealLeg))
check(totalCommon > revealCommon, "T2 la fin vient après la révélation")
local mv = Plan.moves(p, false, false)
local expect = New.Intro
for i, m in mv do
	if m.Teleport or i > 1 then
		expect += Plan.transition(m.Teleport)
	end
	expect += if i < #mv then m.Action.Duration else m.Action.Duration * m.Action.Impacts[#m.Action.Impacts]
end
expect += 0.35 + 2 * 0.45 + 0.6 + 0.1
check(math.abs(Plan.revealAt(p, "Rare") - expect) < 1e-6, string.format("T3 revealAt : somme des durées de repli et des téléportations (%.2f s)", expect))
local okCaps = true
for _, rarity in Rarities.List do
	for _, class in { "Small", "Large", "Colossal" } do
		for u = 0, 2 do
			for _, top in { false, true } do
				local _, total = Plan.typical(rarity.Id, class, u, top)
				local n = Plan.count(rarity.Id, u)
				local client, server = Plan.clientMaxSeconds(rarity.Id, class, n), Plan.serverMaxSeconds(rarity.Id, class, n)
				okCaps = okCaps and client > total and server > client
			end
		end
	end
end
check(okCaps, "T4 durée typique < plafond du client < plafond du serveur, pour chaque rareté, classe, amélioration, avec ou sans Stomp et Slam")
for _, rarity in Rarities.List do
	local n = Plan.count(rarity.Id)
	local r, small = Plan.typical(rarity.Id, "Small", 0, false)
	local rt, smallt = Plan.typical(rarity.Id, "Small", 0, true)
	local _, large = Plan.typical(rarity.Id, "Large", 0, false)
	local _, colossal = Plan.typical(rarity.Id, "Colossal", 0, false)
	print(string.format("DUREES %-9s N=%d révélé %.1f s, fin Small %.1f s (Stomp et Slam livrées : %.1f / %.1f s) ; Large %.1f s, Colossal %.1f s ; plafonds client/serveur Small %.1f/%.1f s", rarity.Id, n, r, small, rt, smallt, large, colossal, Plan.clientMaxSeconds(rarity.Id, "Small", n), Plan.serverMaxSeconds(rarity.Id, "Small", n)))
end

summary("scénario plan")
