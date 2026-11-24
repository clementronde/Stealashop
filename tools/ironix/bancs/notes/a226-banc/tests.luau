--!nocheck
-- Banc a226 (vague 68) : marche des dégâts du panneau lissée et prix des kits. Lancé par run.sh, après SOURCES et
-- le chargeur du simulateur (Config, Format, charge). Vérifie dans les vraies tables de src/shared/Config.

local checks, fails = 0, 0
local function ok(condition, label)
	checks += 1
	if not condition then
		fails += 1
		print("ÉCHEC : " .. label)
	end
end
local function near(value, expected, tolerance, label)
	ok(type(value) == "number" and math.abs(value - expected) <= tolerance, `{label} : {tostring(value)} au lieu de {expected} (± {tolerance})`)
end
local function eq(value, expected, label)
	ok(value == expected, `{label} : {tostring(value)} au lieu de {tostring(expected)}`)
end

local Balance, Zones, Tools, Cosmetics = Config.Balance, Config.Zones, Config.Tools, Config.Cosmetics
local Potions, Tutorial = Config.Potions, Config.Tutorial

-- 1. Marche des dégâts du panneau : 1, 10, 300, 10K, 320K, 2M ---------------------------------------------
local damages = { 1, 10, 300, 10_000, 320_000, 2_000_000 }
eq(#Zones, 6, "six zones")
for index, damage in damages do
	eq(Zones[index].AdvisedDamage, damage, `zone {index} : dégâts du panneau`)
end
for index = 2, 5 do
	local step = Zones[index + 1].AdvisedDamage / Zones[index].AdvisedDamage
	ok(index == 5 or (step >= 25 and step <= 40), `zone {index + 1} : marche de ×{step} (×25 à ×40 attendu)`)
end
-- Zone 6 à deux joueurs : 4M d'équipe, ×12,5 la zone 5 (avant : ×100 d'un coup).
near(Balance.WindowHP.LastZoneTeamSize * Zones[6].AdvisedDamage / Zones[5].AdvisedDamage, 12.5, 1e-9, "zone 6 : équipe ×12,5 la zone 5")
ok(Zones[5].AdvisedDamage >= 300_000 and Zones[5].AdvisedDamage <= 500_000, "zone 5 entre 300K et 500K")

-- 2. Kits : arme × aura de la zone = dégâts du panneau -----------------------------------------------------
local function first(list, zone)
	for _, entry in list do
		if entry.TargetZones[1] <= zone and zone <= entry.TargetZones[2] then
			return entry
		end
	end
	return nil
end
for index = 2, 6 do
	local tool, aura = first(Tools.List, index), first(Cosmetics.Auras, index)
	eq(tool and aura and tool.Power * aura.Multiplier, damages[index], `zone {index} : arme × aura du kit`)
end
for id, power in { Fists = 1, Wrench = 5, Crowbar = 100, Hammer = 2_000, Sledgehammer = 40_000, FireAxe = 60_000, AngleGrinder = 100_000 } do
	eq(Tools.ById[id].Power, power, `{id} : puissance`)
end

-- 3. PV des vitrines (règle Balance.WindowHP inchangée) et temps de casse -----------------------------------
local hps = { 15, 272, 8_159, 271_967, 8_702_929, 108_786_611 }
for index, hp in hps do
	near(Zones[index].WindowHP, hp, 1, `zone {index} : PV de la vitrine`)
end
local regen, cap, timer = Balance.Window.RegenPerSecond, Balance.Hit.MaxHitsPerSecond, Balance.Window.BreakTimer
local function breakTime(hp, damage, hits)
	local net = hits * damage - regen * hp
	return if net > 0 then hp / net else math.huge
end
eq(timer, 8, "chrono de police")
for index = 2, 5 do
	local zone = Zones[index]
	near(breakTime(zone.WindowHP, zone.AdvisedDamage, cap), 6.5, 0.1, `zone {index} : seul au panneau, 6,5 s`)
	ok(breakTime(zone.WindowHP, 1.5 * Zones[index - 1].AdvisedDamage, cap) > timer, `zone {index} : kit d'avant et potion, pas dans le chrono`)
end
local z6, best = Zones[6], Zones[6].AdvisedDamage
local strength = Potions.ById.Strength.Multiplier
near(breakTime(z6.WindowHP, best, cap), 16.2, 0.1, "zone 6 : seul, 16,2 s")
near(breakTime(z6.WindowHP, best * strength, cap), 9.3, 0.1, "zone 6 : seul avec la potion, 9,3 s")
near(breakTime(z6.WindowHP, best, 2 * cap), 6.5, 0.05, "zone 6 : à deux, 6,5 s")
-- Huit joueurs au kit de la zone 5 : plus « jamais » (11,4 s) mais toujours hors du chrono sans potion.
local eight = breakTime(z6.WindowHP, Zones[5].AdvisedDamage, 8 * cap)
near(eight, 11.4, 0.1, "zone 6 : à huit avec le kit de la zone 5, 11,4 s")
ok(eight > timer, "zone 6 : à huit avec le kit de la zone 5, pas dans le chrono")

-- 4. Prix : croissants dans chaque famille ; premiers achats du tuto à 100 $ ------------------------------------
local function increasing(list, label)
	for index = 2, #list do
		ok(list[index].Price > list[index - 1].Price, `{label} : {list[index].Id} plus cher que {list[index - 1].Id}`)
	end
end
increasing(Tools.List, "armes")
increasing(Cosmetics.LegacyAuras, "auras d'avant")
increasing(Cosmetics.NewAuras, "nouvelles auras")
increasing(Cosmetics.Trails, "trails")
local legacy, new = {}, {}
for _, aura in Cosmetics.LegacyAuras do
	legacy[aura.Id] = aura
end
for _, aura in Cosmetics.NewAuras do
	new[aura.Id] = aura
end
for from, to in Cosmetics.Migration do
	eq(legacy[from] and new[to] and legacy[from].Price == new[to].Price, true, `migration {from} → {to} : même prix`)
end
eq(legacy.Spark.Price, 100, "Spark à 100 $")
eq(new.Shine.Price, 100, "Shine à 100 $")
eq(Cosmetics.Trails[1].Id, "Dust", "premier trail : Dust")
eq(Cosmetics.Trails[1].Price, 100, "Dust à 100 $")
eq(Tutorial.AuraGift, 100, "don du tuto pour l'aura : 100 $")
eq(Tools.ById.Wrench.Price, 300, "Wrench inchangée (300 $)")
for id, price in { Crowbar = 80_000, Hammer = 4_000_000, Sledgehammer = 120_000_000, FireAxe = 1_000_000_000, AngleGrinder = 7_000_000_000 } do
	eq(Tools.ById[id].Price, price, `{id} : prix`)
end

-- 5. La proposition du simulateur vaut le jeu ----------------------------------------------------------------------
local V2 = charge("Outil/proposition_v2")
local function sameFamily(list, proposed, field, label)
	eq(#list, #proposed, `{label} : nombre`)
	for index, entry in proposed do
		local real = list[index]
		eq(real and real.Id, entry.Id, `{label} {index} : Id`)
		eq(real and real[field], entry[field], `{label} {entry.Id} : {field}`)
		eq(real and real.Price, entry.Price, `{label} {entry.Id} : prix`)
	end
end
sameFamily(Tools.List, V2.Tools, "Power", "arme")
sameFamily(Cosmetics.Auras, V2.Auras, "Multiplier", "aura")
sameFamily(Cosmetics.Trails, V2.Trails, "Multiplier", "trail")

print(`banc a226 (Config) : {checks} vérification(s), {fails} échec(s)`)
