--!nocheck
-- a229 (vague 69) : remplissage des rayons à la tombée de la nuit, un magasin par image (RefillAll(true)).
-- 12 magasins de 10 rayons, comme la map DEV (mesuré dans Studio le 16/11 : 12 NPCStore, 120 ShelfSlot).
local extra = {}
for i = 1, 10 do
	local side = if i % 2 == 0 then -1 else 1
	table.insert(extra, buildStore(string.format("STORE_Z1_Banc%02d", i), 1, 130 + 60 * ((i - 1) // 2), side))
end
startAll(true)
flush()
local all = { STORE_A, STORE_B }
for _, s in extra do
	table.insert(all, s)
end
local FRAME60 = 1 / 60
local function total()
	local n = 0
	for _, s in all do
		n += boxCount(s)
	end
	return n
end
-- Instances des colis posés (colis, pièces, étiquette BB_Box…).
local function boxInstances()
	local n = 0
	for _, s in all do
		for _, m in shelfBoxes(s) do
			n += 1 + #m:GetDescendants()
		end
	end
	return n
end
local function snapshot()
	local set = {}
	for _, s in all do
		for _, m in shelfBoxes(s) do
			set[m] = true
		end
	end
	return set
end
-- Magasins dont tous les colis sont neufs (aucun dans `old`).
local function freshStores(old)
	local n = 0
	for _, s in all do
		local fresh = boxCount(s) == 10
		for _, m in shelfBoxes(s) do
			if old[m] then
				fresh = false
			end
		end
		if fresh then
			n += 1
		end
	end
	return n
end

section("R0 mise en place")
check(total() == 120, `12 magasins pleins au démarrage : {total()} colis`)

section("R1 d'un coup (RefillAll(), comme avant a229)")
do
	local old = snapshot()
	local t0 = os.clock()
	local placed = Heist.RefillAll()
	local spent = os.clock() - t0
	print(string.format("MESURE rayons d'un coup : une image de %.2f ms, %d colis, %d instance(s) posées", spent * 1000, placed, boxInstances()))
	check(placed == 120 and freshStores(old) == 12, "R1 RefillAll() sans argument : les 12 magasins tout de suite (bancs et appels d'avant)")
end

section("R2 un magasin par image (RefillAll(true))")
do
	local old = snapshot()
	local before = boxInstances()
	local t0 = os.clock()
	local n = Heist.RefillAll(true)
	local first = os.clock() - t0
	local inFirst = freshStores(old)
	check(n == 12, `R2a renvoie le nombre de magasins : {n}`)
	check(inFirst == 1, `R2b un seul magasin rempli dans l'image de l'appel : {inFirst}`)
	local longest, byFrame, prev = first, true, inFirst
	for _ = 1, 20 do
		local t = os.clock()
		advance(FRAME60, FRAME60)
		longest = math.max(longest, os.clock() - t)
		local f = freshStores(old)
		if f - prev > 1 then
			byFrame = false
		end
		prev = f
	end
	print(string.format("MESURE rayons étalés : image de l'appel %.2f ms (%d instance(s) posées sur %d), plus longue image %.2f ms", first * 1000, math.floor(before / 12 + 0.5), before, longest * 1000))
	check(byFrame, "R2c jamais plus d'un magasin par image")
	check(prev == 12 and total() == 120, `R2d au bout de 12 images, les 12 magasins pleins (comme avant) : {prev} magasin(s), {total()} colis`)
	check(logHas("rayons remplis (nouveau tirage) : 120 colis", "PRINT"), "R2e sortie : 120 colis une fois fini")
end

section("R3 un remplissage d'un coup pendant l'étalement l'arrête")
do
	Heist.RefillAll(true)
	advance(2 * FRAME60, FRAME60)
	Heist.RefillAll()
	local after = snapshot()
	advance(20 * FRAME60, FRAME60)
	check(freshStores(after) == 0 and total() == 120, "R3 l'étalement d'avant ne retire plus rien")
end

section("R4 magasin ouvert : reporté à sa fermeture, comme avant")
do
	local p = player("Alice", Vector3.new(60, 3, 10))
	flush()
	local opened = breakHard(p, STORE_A)
	check(opened and Heist.IsOpen(STORE_A), "R4a STORE_A ouvert")
	local old = snapshot()
	Heist.RefillAll(true)
	advance(20 * FRAME60, FRAME60)
	local same = true
	for _, m in shelfBoxes(STORE_A) do
		if not old[m] then
			same = false
		end
	end
	check(same and freshStores(old) == 11, "R4b STORE_A garde ses colis, les 11 autres sont remplis")
	check(logHas("1 magasin(s) ouvert(s) rempli(s) à leur fermeture", "PRINT"), "R4c sortie : 1 magasin reporté")
end
check(logCount("tick :", "WARN", "server") == 0, "aucune erreur du tick")

summary("scénario refill")
