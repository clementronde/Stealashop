--!nocheck
-- Scénario « spawn » (a88) : apparition (attente, plafond, durée de vie, cadence et PotionLuck, nuit), place sur
-- une rue du couloir (loin des bords, pas sous le décor, à travers un volume invisible, jamais côté safe), au
-- seul joueur, renvoi à la réapparition, départ.
startPotions()
local ada = join("Ada", newProfile())
local bob = join("Bob", newProfile())
local P = POTIONS_CFG
local t0 = now()

section("attente, apparition, joueur seul")
advance(P.SpawnEvery - 2, 0.25)
check(#spawnedTo(ada) == 0, `rien avant {P.SpawnEvery} s`)
local waited = waitSpawn(ada, 5)
check(waited ~= nil and math.abs(now() - t0 - P.SpawnEvery) <= 0.75, `1re potion au bout de {P.SpawnEvery} s (à {string.format("%.2f", now() - t0)} s)`)
local uid, id, position = lastSpawned(ada)
check(type(uid) == "string" and P.ById[id] ~= nil and position ~= nil and type(position.X) == "number", `PotionSpawned(uid, Id, position) : {uid}, {id}`)
local e = spawnedTo(ada)[1]
check(e and e.to == ada, "PotionSpawned envoyé à Ada seule (FireClient)")
check(#remotes("PotionSpawned", function(x) return x.to == nil end) == 0, "jamais à tous")

section("plafond et durée de vie")
local tFirst = now()
advance(2 * P.SpawnEvery + 1, 0.25)
check(countOf(livePotions(ada)) == P.MaxPerPlayer, `{P.MaxPerPlayer} potions au bout de 3 attentes`)
advance(P.Lifetime - 2 * P.SpawnEvery - 3, 0.25)
check(countOf(livePotions(ada)) == P.MaxPerPlayer and #spawnedTo(ada) == P.MaxPerPlayer, `plafond : pas de 4e (trouvé {#spawnedTo(ada)} envoi(s))`)
check(#removedTo(ada) == 0, "rien n'a encore expiré")
advance(4, 0.25)
local removed = removedTo(ada)
check(#removed == 1 and removed[1].args[1] == uid, `la 1re expire au bout de {P.Lifetime} s (PotionRemoved({uid}))`)
check(removed[1] and math.abs(removed[1].t - tFirst - P.Lifetime) <= 0.5, `expirée à {if removed[1] then string.format("%.2f", removed[1].t - tFirst) else "?"} s`)
local tFree = if removed[1] then removed[1].t else now()
waited = waitSpawn(ada, P.SpawnEvery + 5)
check(waited and math.abs(now() - tFree - P.SpawnEvery) <= 0.75, `sous le plafond : nouvelle attente complète ({string.format("%.2f", now() - tFree)} s)`)

section("places")
-- Beaucoup de tirages : le crochet clear vide les potions de Bob après chacune.
local spots = {}
local bad = {}
for _ = 1, 40 do
	local w = waitSpawn(bob, P.SpawnEvery + 6)
	if w == nil then
		break
	end
	local _, _, p = lastSpawned(bob)
	table.insert(spots, p)
	test("Bob clear")
end
check(#spots == 40, `40 apparitions pour Bob (trouvé {#spots})`)
local onA, onB = 0, 0
for _, p in spots do
	local ok = math.abs(p.Y) < 1e-3 and math.abs(p.Z) <= 52.5 - 15 + 1e-6 and p.X >= 400 + 15 - 1e-6 and p.X <= 600 - 15 + 1e-6
	-- Arbre (x 429 à 459, z -15 à 15) : le point et ses 4 voisins à 4 studs doivent être hors de lui.
	for _, d in { Vector3.new(0, 0, 0), Vector3.new(4, 0, 0), Vector3.new(-4, 0, 0), Vector3.new(0, 0, 4), Vector3.new(0, 0, -4) } do
		local q = p + d
		if q.X > 429 and q.X < 459 and math.abs(q.Z) < 15 then
			ok = false
		end
	end
	if not ok then
		table.insert(bad, tostring(p))
	end
	if p.X < 488 then
		onA += 1
	else
		onB += 1
	end
end
check(#bad == 0, `toutes sur une rue du couloir, au sol, à 15 studs des bords, pas sous l'arbre ({table.concat(bad, " ; ")})`)
check(onA > 0 and onB > 0, `les deux rues servent (A {onA}, B {onB}) : le volume invisible au-dessus de B est traversé`)
local types = {}
for _, x in spawnedTo(bob) do
	types[x.args[2]] = (types[x.args[2]] or 0) + 1
end
check(countOf(types) >= 3, `plusieurs types tirés ({countOf(types)})`)

section("PotionLuck")
for level = 1, 3 do
	skill(bob, "PotionLuck", level)
	test("Bob clear")
	local factor = SkillTreeService.GetEffect(bob, "PotionLuck")
	waitSpawn(bob, 60)
	test("Bob clear")
	local w2 = waitSpawn(bob, 60)
	check(factor and w2 and math.abs(w2 - P.SpawnEvery * factor) <= 0.5, `niveau {level} : une toutes les {P.SpawnEvery} × {factor} s (mesuré {w2})`)
end

section("nuit")
test("Bob clear")
advance(1, 0.25)
local nb = #spawnedTo(bob)
NIGHT = true
advance(120, 0.25)
check(#spawnedTo(bob) == nb, "la nuit : aucune nouvelle potion")
NIGHT = false
local tDawn = now()
waited = waitSpawn(bob, 60)
check(waited and math.abs(now() - tDawn - P.SpawnEvery * 0.5) <= 0.5, `à l'aube : une attente complète ({string.format("%.2f", now() - tDawn)} s)`)

section("réapparition et départ")
test("Ada spawn Money")
test("Ada spawn Money")
local before = livePotions(ada)
local n = #spawnedTo(ada)
spawnCharacter(ada, Vector3.new(0, 3, 0))
advance(0.3)
local resent = {}
local list = spawnedTo(ada)
for i = n + 1, #list do
	resent[list[i].args[1]] = true
end
local all = countOf(before) > 0
for u in before do
	if not resent[u] then
		all = false
	end
end
check(all and countOf(resent) == countOf(before), `nouveau personnage : les {countOf(before)} potions renvoyées, mêmes uid`)
local cy = newPlayer("Cy")
advance(P.SpawnEvery + 2, 0.25)
check(#spawnedTo(cy) == 0, "sans profil chargé : aucune potion")
leave(ada)
local after = #spawnedTo(ada) + #removedTo(ada)
advance(P.SpawnEvery * 2, 0.25)
check(#spawnedTo(ada) + #removedTo(ada) == after, "parti : plus rien vers lui")
check(not logHas("aucune BasePart", "WARN"), "les rues sont trouvées")
finish("scénario spawn")
