--!nocheck
-- Scénario « combat » (a159, L-163 règle 3) : combat égal à la batte. Un propriétaire très fort et un débutant
-- frappent chacun un intrus dans leur boutique : même étourdissement, même durée, aucun dégât.
startServer()
local Bat = sharedModule("Config/Bat")
local adaData = victimProfile()
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
local cyData = newProfile()
addItem(cyData, "cy-soda", "Z1_CanetteDeSoda", 1)
addItem(cyData, "cy-chips", "Z1_PaquetDeChips", 2)
local cy = join("Cy", cyData)
local dan = join("Dan", newProfile())
for _, p in { ada, bob, cy, dan } do
	giveBat(p)
end
advance(1.2)
DAMAGE[ada] = 1e9 -- Ada : très forte
DAMAGE[cy] = 1 -- Cy : débutant
local hits = {}
BatService.OnHit(function(hitter, target, usage)
	table.insert(hits, { hitter = hitter, target = target, usage = usage })
end)

-- `victim` entre dans la boutique cassée de `owner`, qui le frappe. Renvoie l'attribut BatStun juste après,
-- la durée de l'étourdissement (s) et la vie de la cible avant et après.
local function ownerHits(owner, victim)
	local plot = shopOf(owner)
	local S = refsOfShop(plot)
	check(breakDoor(victim, plot), `{victim.Name} casse la porte de {owner.Name}`)
	advance(3.2) -- immunité de batte et étourdissements précédents finis
	moveTo(victim, S.center, Vector3.new(0, 0, -1))
	advance(0.2)
	local hum = humanoidOf(victim)
	local before = hum.Health
	local pos = rootOf(victim).Position
	moveTo(owner, pos + Vector3.new(0, 0, 4), Vector3.new(0, 0, -1))
	if not holdsBat(owner) then
		humanoidOf(owner):EquipTool(batOf(owner))
	end
	local count = #hits
	fireAs(owner, "SwingBat")
	flush()
	local stunned = victim:GetAttribute("BatStun")
	local t0 = now()
	while victim:GetAttribute("BatStun") ~= nil and now() - t0 < 10 do
		advance(0.05, 0.05)
	end
	return #hits == count + 1, stunned, now() - t0, before, hum.Health
end

section("combat égal")
local okA, stunA, durA, hpA0, hpA1 = ownerHits(ada, bob)
local okC, stunC, durC, hpC0, hpC1 = ownerHits(cy, dan)
print(`  mesure : Ada (1e9) → Bob : {stunA}, {string.format("%.2f", durA)} s ; Cy (1) → Dan : {stunC}, {string.format("%.2f", durC)} s`)
check(okA and okC, "les deux coups sont des coups réussis")
check(stunA == "Stun" and stunC == "Stun", `même effet : Stun et Stun (trouvé {stunA}, {stunC})`)
check(math.abs(durA - durC) < 0.11 and math.abs(durA - Bat.StunDuration) < 0.15, `même durée : Bat.StunDuration = {Bat.StunDuration} s (mesuré {string.format("%.2f", durA)} et {string.format("%.2f", durC)})`)
check(hpA0 == hpA1 and hpC0 == hpC1, "aucun dégât sur la cible (vie inchangée)")

section("sortie")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
summary("scénario combat")
