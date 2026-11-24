-- a198 (vague 61) : scénarios de la poursuite à l'échelle, collés à la place de ceux d'a193 (tests.luau d'a193
-- jusqu'à ses scénarios, lu sur place : run, window, comp, finish, speedFor). Marche w à l'échelle 1 (speedFor
-- d'a193), donc K × w en vrai ; 70 = le plafond.
local K = BalanceCfg.Stats.RealSpeedScale or 1
local box = BalanceCfg.Carry.NPCBoxSpeedMultiplier
print(string.format("  échelle K = %s", tostring(K)))
if A193_SCENARIO == "a198hold" then
	section("a198hold : au-dessus du minimum, 14 studs gardés, ruée à l'échelle")
	-- Détections comptées au fil de l'eau (le journal de GetLog ne garde que les LogSize dernières).
	local speed, fly = 0, 0
	AC.OnDetection(function(_, d)
		if d.Kind == "Fly" then
			fly += 1
		else
			speed += 1
			print(string.format("    détection : %s %s (portait %s) %s", d.Name, d.Kind, tostring(d.Carrying), d.Detail))
		end
	end)
	for _, w in { 30, 50, 70 } do
		for _, R in { 0, 0.1 } do
			local label = string.format("V%d/%d", w, R * 1000)
			local rec = run(w, R, 7)
			check(rec ~= nil and rec.switchT ~= nil, label .. " : braquage, ruée et fin de ruée")
			if rec ~= nil and rec.switchT ~= nil then
				local expectedWalk = K * math.min(w, BalanceCfg.Stats.MaxWalkSpeed) * box
				check(near(rec.walk, expectedWalk, 0.05), label .. string.format(" : marche du porteur K × w × %.2f = %.2f (%.2f)", box, expectedWalk, rec.walk))
				local rush = math.max(ChaseCfg.RushMinSpeed, ChaseCfg.RushWalkFactor * rec.walk)
				check(near(rec.maxSpeed, rush, 0.5), label .. string.format(" : ruée à max(%.0f, 3,9 × marche) = %.1f (%.1f)", ChaseCfg.RushMinSpeed, rush, rec.maxSpeed))
				local expected = ChaseCfg.HoldDistance + rec.walk * R - comp(rec.walk, R)
				local lo, hi, mean = window(rec, "seen")
				local slo, shi = window(rec, "server")
				print(string.format("  mesure %s : marche %.1f, ruée %.1f, distance vue %s à %s (attendu %.2f), serveur %s à %s",
					label, rec.walk, rec.maxSpeed, fmt(lo), fmt(hi), expected, fmt(slo), fmt(shi)))
				check(rec.caught == nil, label .. " : pas de capture au-dessus du minimum")
				check(mean ~= nil and lo >= expected - 0.5 and hi <= expected + 0.5,
					label .. string.format(" : distance vue %.2f ± 0,5 (%s à %s)", expected, fmt(lo), fmt(hi)))
				if R == 0 then
					check(slo >= ChaseCfg.HoldDistance - 0.5 and shi <= ChaseCfg.HoldDistance + 0.5,
						label .. " : 14 ± 0,5 studs gardés (" .. fmt(slo) .. " à " .. fmt(shi) .. ")")
				end
			end
			finish(rec)
		end
	end
	-- Un joueur légal à K × 70 (porteur compris) n'est jamais pris pour un speed hack ni un téléport. Les détections
	-- « Fly » viennent du faux monde du harnais (plus de sol au-delà de sa carte, que le voleur dépasse à K = 2) : comptées
	-- à part, sans rapport avec la vitesse.
	print(string.format("  mesure A1 : %d détection(s) Speed ou Teleport, %d Fly (sol absent du harnais)", speed, fly))
	check(speed == 0, string.format("A1 anti-triche : aucune détection Speed ou Teleport d'un joueur légal (%d)", speed))
else
	section("a198catch : bien sous le minimum, capture plus rapide (rapprochement × K)")
	for _, w in { 30, 50, 70 } do
		local label = string.format("W%d/100", w)
		local rec = run(w, 0.1, 6)
		check(rec ~= nil and rec.caught ~= nil, label .. " : attrapé sous le minimum")
		if rec ~= nil and rec.caught ~= nil then
			print(string.format("  mesure %s : marche %.1f, attrapé %.2f s après la fin de ruée", label, rec.caught.walk,
				rec.caught.t - (rec.switchT or rec.startT)))
		end
		finish(rec)
	end
end
summary("scénario " .. A193_SCENARIO)
