--!nocheck
-- a229 (vague 69) : à la tombée de la nuit, les 12 vigiles de nuit posés un par image (après tests.head du banc
-- a21-night, copie a94 : 6 zones, 2 points de ronde chacune, StoreHeistService bouchonné).
print("\nA229 : tombée de la nuit étalée")
local F60 = 1 / 60
local function instances()
	return #Workspace:GetDescendants()
end
do
	NightCycle.SkipTo("Day")
	runFor(0.2)
	local refills = #Heist.Refills
	local before = instances()
	local t0 = os.clock()
	NightCycle.SkipTo("Night", 60)
	local first = os.clock() - t0
	local inFirst = instances() - before
	local guardsFirst = #nightGuards()
	check(#Heist.Refills == refills + 1, "un seul RefillAll à la tombée de la nuit")
	local longest, most, byFrame, seen = first, inFirst, true, guardsFirst
	for _ = 1, 30 do
		local c0 = instances()
		local t = os.clock()
		runFor(F60, nil, F60)
		longest = math.max(longest, os.clock() - t)
		most = math.max(most, instances() - c0)
		local n = #nightGuards()
		if n - seen > 1 then
			byFrame = false
		end
		seen = n
	end
	print(string.format("MESURE vigiles de nuit : image de la tombée %.2f ms, %d instance(s) créées, %d vigile(s) ; plus longue image %.2f ms ; au plus %d instance(s) créées dans une image", first * 1000, inFirst, guardsFirst, longest * 1000, most))
	check(guardsFirst == 1, `un seul vigile de nuit dans l'image de la tombée : {guardsFirst}`)
	check(byFrame, "jamais plus d'un vigile de nuit par image")
	check(seen == 12, `au bout de 12 images, les 12 vigiles de nuit (comme avant) : {seen}`)
	check(guardNamed("NightGuard_Z6_2") ~= nil and guardNamed("NightGuard_Z1_1") ~= nil, "noms et ordre des zones inchangés")
	check(attr("NightPhase") == "Night", "toujours la nuit")
end
do
	NightCycle.SkipTo("Day")
	runFor(0.2)
	NightCycle.SkipTo("Night", 60)
	runFor(3 * F60, nil, F60)
	local mid = #nightGuards()
	NightCycle.SkipTo("Day")
	runFor(0.5)
	check(mid >= 2 and mid < 12, `aube pendant la pose : {mid} vigile(s) posés`)
	check(#nightGuards() == 0, "aube pendant la pose : aucun vigile de nuit ne reste ni n'arrive après")
	NightCycle.SkipTo("Night", 60)
	runFor(30 * F60, nil, F60)
	check(#nightGuards() == 12, "nuit suivante : 12 vigiles de nuit")
	NightCycle.SkipTo("Day")
	runFor(0.5)
end
summary()
