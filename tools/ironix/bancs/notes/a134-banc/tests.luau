--!nocheck
-- Banc a134 (vague 40, 2026-11-14) : rééquilibrage v2, passe 2, dans src/shared/Config. Lancé par run.sh, après
-- SOURCES et le chargeur du simulateur (Config, Format, charge). Vérifie dans les vraies tables et formules :
-- dégâts, marche, tapis, PV des vitrines, casse seul et à deux, plafond de coups, potions, portes, camion, tour,
-- et que le jeu vaut la proposition (tools/ironix/equilibrage/proposition_v2.luau) champ par champ.

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

local Balance, Formulas, Zones = Config.Balance, Config.Formulas, Config.Zones
local Tools, Cosmetics, Potions = Config.Tools, Config.Cosmetics, Config.Potions
local Upgrades, Training = Config.Upgrades, Config.Training

-- 1. Dégâts d'un coup = arme × aura (plus de Force) --------------------------------------------------------
eq(Formulas.HitDamage(40, 3), 120, "HitDamage Crowbar × Flame")
eq(Formulas.HitDamage(5), 5, "HitDamage sans aura")
eq(Formulas.HitDamage(100_000, 20), 2_000_000, "HitDamage meilleur kit")
eq(Balance.Stats.StrengthDivisor, nil, "Balance.Stats.StrengthDivisor retiré")
eq(Balance.Stats.SpeedToWalkSpeed, nil, "Balance.Stats.SpeedToWalkSpeed retiré")
eq(Formulas.MachineMultiplier, nil, "Formulas.MachineMultiplier retiré")

-- 2. Marche = min(70, 16 + 4 × log10(1 + Speed affichée / 100)) -------------------------------------------
eq(Formulas.WalkSpeed(0), 16, "marche à 0")
for _, row in { { 100, 17.2 }, { 1e3, 20.2 }, { 3e3, 22.0 }, { 1e4, 24.0 }, { 1e5, 28.0 }, { 1e6, 32.0 }, { 3e6, 33.9 }, { 1e7, 36.0 }, { 1e8, 40.0 }, { 1e9, 44.0 }, { 3e9, 45.9 }, { 1e10, 48.0 }, { 1e12, 56.0 }, { 1e13, 60.0 } } do
	near(Formulas.WalkSpeed(row[1]), row[2], 0.05, `marche à Speed {row[1]}`)
end
for _, speed in { 1, 250, 4321, 9.9e7, 5e11 } do
	near(Formulas.WalkSpeed(speed), math.min(70, 16 + 4 * math.log10(1 + speed / 100)), 1e-9, `formule de la marche à {speed}`)
end
eq(Formulas.WalkSpeed(1e30), 70, "plafond de 70")
near(Formulas.WalkSpeed(3.2e15), 70, 0.05, "plafond atteint vers 3,2Qa")
ok(Formulas.WalkSpeed(3e15) < 70, "sous le plafond à 3Qa")
eq(Formulas.WalkSpeed(1500, 2), Formulas.WalkSpeed(3000), "le trail multiplie la Speed affichée")
eq(Formulas.ShownSpeed(1500, 12), 18_000, "Speed affichée = Vitesse × trail")
eq(Formulas.ShownSpeed(7), 7, "Speed affichée sans trail")
eq(Formulas.WalkSpeed(-50), 16, "Vitesse négative : 16")
eq(Formulas.WalkSpeed(0 / 0), 16, "Vitesse illisible : 16")
near(Formulas.WalkSpeed(10 * 12345) - Formulas.WalkSpeed(12345), 4, 0.02, "un zéro de plus = +4 de marche")

-- 3. Tapis : 2^(niveau affiché − 1) par seconde, niveaux 1 à 20, prix 150 × 3,8^(niveau − 1) ---------------
eq(Formulas.TreadmillGain(0), 1, "tapis niveau 1 : +1/s")
eq(Formulas.TreadmillGain(1), 2, "tapis niveau 2 : +2/s")
eq(Formulas.TreadmillGain(7), 128, "tapis niveau 8 : +128/s")
eq(Formulas.TreadmillGain(19), 524_288, "tapis niveau 20 : +524 288/s")
eq(Formulas.TreadmillGain(40), 524_288, "tapis au-delà du niveau 20 : borné")
eq(Formulas.TreadmillGain(-3), 1, "tapis niveau négatif : niveau 1")
eq(Formulas.TreadmillShownLevel(0), 1, "niveau affiché du profil neuf")
eq(Formulas.TreadmillShownLevel(19), 20, "niveau affiché maximal")
eq(Upgrades.ById.Treadmill.MaxLevel, 19, "19 achats de tapis")
eq(Formulas.UpgradeCost("Treadmill", 0), 150, "prix du niveau 2")
eq(Formulas.UpgradeCost("Treadmill", 1), 570, "prix du niveau 3")
eq(Formulas.UpgradeCost("Treadmill", 2), 2166, "prix du niveau 4")
eq(Formulas.UpgradeCost("Treadmill", 18), math.round(150 * 3.8 ^ 18), "prix du niveau 20")
eq(Formulas.UpgradeCost("Treadmill", 19), nil, "niveau 20 : plus rien à acheter")
local total = 0
for level = 0, 18 do
	total += Formulas.UpgradeCost("Treadmill", level)
end
near(total / 1e12, 5.5, 0.06, "cumul des 19 niveaux (5.5T)")
eq(Formulas.UpgradeCost("DisplaySlots", 0), 500, "présentoirs inchangés")
eq(Upgrades.ById.Bench, nil, "amélioration Bench retirée")
eq(#Upgrades.List, 2, "2 améliorations vendues")
eq(Training.Bench, nil, "Training.Bench retiré")
eq(Training.Treadmill.TapBonus, 0.5, "taps +50 % gardés")
-- Modèle du tapis : lu sur le niveau affiché (Base au niveau 1, Silver aux 2 et 3, Void au 20).
local function variant(stored)
	local list = Upgrades.TreadmillVariants
	return list[math.clamp(math.floor(Formulas.TreadmillShownLevel(stored) / Upgrades.TreadmillTierEvery) + 1, 1, #list)]
end
eq(variant(0), "Base", "tapis Base au niveau 1")
eq(variant(1), "Silver", "tapis Silver au niveau 2")
eq(variant(2), "Silver", "tapis Silver au niveau 3")
eq(variant(3), "Gold", "tapis Gold au niveau 4")
eq(variant(18), "Fire", "tapis Fire au niveau 19")
eq(variant(19), "Void", "tapis Void au niveau 20")

-- 4. Zones : seuils, PV des vitrines (passe 3 : chrono de police de 8 s), vigiles ---------------------------
local damages = { 1, 10, 120, 1_500, 20_000, 2_000_000 }
local hps = { 27, 272, 3_264, 40_795, 543_933, 108_786_611 }
local speeds = { 0, 3e3, 100e3, 3e6, 100e6, 3e9 }
local guards = { 13.4, 20.8, 26.2, 31.5, 37, 42.3 }
local incomes = { 1, 8, 60, 450, 3_500, 25_000 }
eq(#Zones, 6, "6 zones")
for index, zone in Zones do
	eq(zone.AdvisedDamage, damages[index], `zone {index} : Strength du panneau`)
	eq(zone.WindowHP, hps[index], `zone {index} : PV de la vitrine`)
	eq(zone.SpeedRequired, speeds[index], `zone {index} : Speed du panneau`)
	near(zone.GuardSpeed, guards[index], 1e-9, `zone {index} : vitesse du vigile`)
	eq(zone.BaseIncome, incomes[index], `zone {index} : revenu de base inchangé`)
	eq(zone.AdvisedSpeed, Formulas.WalkSpeed(zone.SpeedRequired), `zone {index} : marche conseillée = Formulas.WalkSpeed`)
	if index > 1 then
		near(zone.GuardSpeed, 0.9 * zone.AdvisedSpeed + 1, 0.05, `zone {index} : vigile = 0,9 × marche + 1`)
	end
end
near(Zones[5].WindowHP / 20_000, 27.197, 0.001, "zones 1 à 5 : 27,197 × dégâts du panneau")
near(108_786_611 / 2_000_000, 54.393, 0.001, "zone 6 : 54,393 × D")
-- Les trois nombres de la règle (Balance.WindowHP), faciles à remplacer.
eq(Balance.WindowHP.SoloBreakTime, 6.5, "Balance.WindowHP.SoloBreakTime")
eq(Balance.WindowHP.LastZoneBreakTime, 6.5, "Balance.WindowHP.LastZoneBreakTime")
eq(Balance.WindowHP.LastZoneTeamSize, 2, "Balance.WindowHP.LastZoneTeamSize")
eq(Balance.Window.RegenPerSecond, 0.03, "régénération 3 %/s")
-- Chrono de police de la passe 3. Balance.Window.BreakTimer (13 → 8) est changé par a135 : il arrive à la fusion.
local timer = 8
ok(Balance.Window.BreakTimer == 8 or Balance.Window.BreakTimer == 13, "chrono de police : 8 s (ou 13 s avant la fusion d'a135)")

-- Temps de casse (s) : PV / (coups/s × dégâts − régénération × PV) ; math.huge si la régénération l'emporte.
local regen, cap = Balance.Window.RegenPerSecond, Balance.Hit.MaxHitsPerSecond
local function breakTime(hp, damage, hits)
	local net = hits * damage - regen * hp
	return if net > 0 then hp / net else math.huge
end
eq(cap, 5, "plafond de 5 coups par seconde")
for index = 1, 5 do
	local zone = Zones[index]
	near(breakTime(zone.WindowHP, zone.AdvisedDamage, cap), 6.5, 0.1, `zone {index} : seul au panneau, casse en 6,5 s`)
	ok(breakTime(zone.WindowHP, zone.AdvisedDamage, 4) > timer, `zone {index} : à 4 coups/s, la police arrive avant`)
	ok(breakTime(zone.WindowHP, zone.AdvisedDamage, 4.5) <= timer, `zone {index} : à 4,5 coups/s, cassé dans le chrono`)
	if index > 1 then
		eq(breakTime(zone.WindowHP, Zones[index - 1].AdvisedDamage, cap), math.huge, `zone {index} : kit de la zone d'avant, jamais`)
		ok(breakTime(zone.WindowHP, 1.5 * Zones[index - 1].AdvisedDamage, cap) > timer, `zone {index} : kit d'avant et potion, pas dans le chrono`)
	end
end
local z6, best = Zones[6], Zones[6].AdvisedDamage
eq(best, Tools.List[#Tools.List].Power * Cosmetics.Auras[#Cosmetics.Auras].Multiplier, "zone 6 : le meilleur kit")
near(breakTime(z6.WindowHP, best, cap), 16.2, 0.1, "zone 6 : seul, 16,2 s")
ok(breakTime(z6.WindowHP, best, cap) > timer, "zone 6 : seul, raté")
near(breakTime(z6.WindowHP, best * Potions.ById.Strength.Multiplier, cap), 9.3, 0.1, "zone 6 : seul avec la potion, 9,3 s")
ok(breakTime(z6.WindowHP, best * Potions.ById.Strength.Multiplier, cap) > timer, "zone 6 : seul avec la potion, raté (chrono de 8 s)")
near(breakTime(z6.WindowHP, best, 2 * cap), 6.5, 0.05, "zone 6 : à deux, 6,5 s")
ok(breakTime(z6.WindowHP, best * 2.5, cap) <= timer, "zone 6 : seul avec Hydraulic Gloves, dans le chrono (5,0 s)")
eq(breakTime(z6.WindowHP, Zones[5].AdvisedDamage, 8 * cap), math.huge, "zone 6 : à huit avec le kit de la zone 5, jamais")

-- 5. Plafond de coups appliqué par le serveur (Net : débit régulier de HitWindow, seau à jetons) ------------
local Definitions = charge("Net/Definitions")
local RateLimiter = charge("Net/RateLimiter")
local hitDef
for _, def in Definitions.List do
	if def.Name == "HitWindow" then
		hitDef = def
	end
end
eq(hitDef.RatePerSecond, cap, "débit du remote HitWindow = Balance.Hit.MaxHitsPerSecond")
ok(type(hitDef.Jitter) == "number" and hitDef.Jitter > 0 and hitDef.Jitter <= 1, "HitWindow : débit régulier, au plus un coup d'avance")
-- Appels aux heures `times` (croissantes) : coups acceptés, et le plus grand nombre sur une seconde glissante.
local function run(times)
	local window = RateLimiter.new(hitDef.RatePerSecond, hitDef.Jitter) -- comme Net.getWindow
	local accepted = {}
	for _, t in times do
		if RateLimiter.allow(window, t) then
			table.insert(accepted, t)
		end
	end
	local worst = 0
	for i, t in accepted do
		local n = 0
		for j = i, #accepted do
			if accepted[j] < t + 1 - 1e-9 then
				n += 1
			end
		end
		worst = math.max(worst, n)
	end
	return #accepted, worst
end
local function regular(perSecond, seconds)
	local times = {}
	for i = 0, seconds * perSecond - 1 do
		times[i + 1] = i / perSecond
	end
	return times
end
for _, perSecond in { 7, 10, 20, 60, 500 } do
	local count, worst = run(regular(perSecond, 10))
	ok(count <= 10 * cap + 2, `{perSecond} clics/s pendant 10 s : {count} coups acceptés, {10 * cap + 2} au plus`)
	-- Envois bruts plus lents que 2 × le plafond : quelques jetons débordent (7 envois/s : 47 coups). Le client,
	-- lui, garde le clic trop tôt et envoie au rythme du plafond (HitController) : il ne perd rien (plus bas).
	ok(count >= 10 * cap - 5, `{perSecond} clics/s pendant 10 s : {count} coups acceptés, près du plafond`)
	ok(worst <= cap + 1, `{perSecond} clics/s : au plus {cap + 1} coups sur une seconde glissante ({worst})`)
end
-- Sur la durée : 5 coups par seconde, pas plus (60 s d'un tricheur à 500 envois par seconde).
local long = run(regular(500, 60))
ok(long <= 60 * cap + 2, `60 s à 500 envois/s : {long} coups acceptés, {60 * cap + 2} au plus`)
-- Le client au plafond (un envoi toutes les 0,2 s) ne perd aucun coup, même avec ± 40 ms d'écart du réseau.
eq((run(regular(5, 10))), 50, "5 envois/s réguliers : aucun coup perdu")
local jittered, seed = {}, 12345
for i = 0, 54 do -- 11 s de coups au plafond
	seed = (seed * 1103515245 + 12345) % 2147483648
	jittered[i + 1] = i * 0.2 + (seed / 2147483648 - 0.5) * 0.08
end
table.sort(jittered)
eq((run(jittered)), 55, "5 envois/s avec ± 40 ms d'écart : les 55 coups de 11 s passent")
-- La fenêtre glissante (sans Jitter) en perdait : c'est ce que le débit régulier corrige.
local strict = RateLimiter.new(cap)
local kept = 0
for _, t in jittered do
	if RateLimiter.allow(strict, t) then
		kept += 1
	end
end
ok(kept < 55, `fenêtre glissante, mêmes envois : {kept} coups sur 55 (des coups se perdaient)`)
-- Les autres remotes gardent la fenêtre glissante.
for _, def in Definitions.List do
	if def.Name ~= "HitWindow" then
		ok(def.Jitter == nil, `{def.Name} : fenêtre glissante gardée`)
	end
end
local plain = RateLimiter.new(3)
local passed = 0
for _ = 1, 10 do
	if RateLimiter.allow(plain, 100) then
		passed += 1
	end
end
eq(passed, 3, "fenêtre glissante inchangée : 3 appels sur 10 au même instant")

-- 6. Potions --------------------------------------------------------------------------------------------------
eq(Potions.ById.Speed, nil, "potion de vitesse retirée")
eq(#Potions.List, 3, "3 potions")
eq(Potions.ById.Strength.Multiplier, 1.5, "potion de force ×1,5")
eq(Potions.ById.Money.Multiplier, 2, "potion Money inchangée")
for _, potion in Potions.List do
	ok(potion.Id ~= "Speed" and potion.Model ~= "POT_Speed", "aucune potion Speed dans la liste")
end
ok(Config.SkillTree.ById.PotionTime ~= nil, "PotionTime reste dans l'arbre (autres potions)")

-- 7. Portes, camion, Fortune Tower --------------------------------------------------------------------------
for level, hp in { 50, 500, 6_000, 75_000, 1_000_000, 100_000_000 } do
	eq(Formulas.PlayerWindowHP(level), hp, `porte d'une boutique de niveau {level}`)
end
eq(Config.TruckEvent.HPPerDamage, 100, "camion : 100 × dégâts de sa zone")
eq(Config.TruckEvent.MaxHP, nil, "camion : plus de PV fixes")
for index, hp in { 100, 1_000, 12_000, 150_000, 2_000_000, 200_000_000 } do
	eq(Config.TruckEvent.HPPerDamage * Zones[index].AdvisedDamage, hp, `camion en zone {index}`)
	near(hp / (cap * Zones[index].AdvisedDamage), 20, 1e-6, `camion en zone {index} : 20 s seul au panneau (PV sans régénération)`)
end
eq(Config.FortuneTower.MaxHP, 4 * 2_000_000 * 5 * 90, "Fortune Tower : 3.6B PV (5 coups/s)")

-- 8. Le jeu vaut la proposition v2 (tools/ironix/equilibrage/proposition_v2.luau) ---------------------------
local V2 = charge("Outil/proposition_v2")
local function sameFamily(list, proposed, field, label)
	eq(#list, #proposed, `{label} : nombre`)
	for index, entry in proposed do
		local real = list[index]
		eq(real.Id, entry.Id, `{label} {index} : Id`)
		eq(real[field], entry[field], `{label} {entry.Id} : {field}`)
		eq(real.Price, entry.Price, `{label} {entry.Id} : prix`)
		eq(real.TargetZones[1], entry.Zones[1], `{label} {entry.Id} : première zone`)
		eq(real.TargetZones[2], entry.Zones[2], `{label} {entry.Id} : dernière zone`)
	end
end
sameFamily(Tools.List, V2.Tools, "Power", "arme")
sameFamily(Cosmetics.Auras, V2.Auras, "Multiplier", "aura")
sameFamily(Cosmetics.Trails, V2.Trails, "Multiplier", "trail")
eq(Balance.Stats.BaseWalkSpeed, V2.Stats.BaseWalkSpeed, "BaseWalkSpeed")
eq(Balance.Stats.MaxWalkSpeed, V2.Stats.MaxWalkSpeed, "MaxWalkSpeed")
eq(Balance.Stats.WalkPerDecade, V2.Stats.WalkPerDecade, "WalkPerDecade")
eq(Balance.Stats.SpeedScale, V2.Stats.SpeedScale, "SpeedScale")
eq(cap, V2.MaxHitsPerSecond, "MaxHitsPerSecond de la proposition")
eq(Balance.WindowHP.LastZoneTeamSize, V2.Zone6.Players, "dernière zone : deux joueurs")
-- La proposition du dépôt suit la passe 3 (BreakSeconds = 6,5) une fois la branche a138 fusionnée ; avant, elle
-- dit encore 11 s (passe 2) : les PV des vitrines et la casse acceptée ne sont alors pas comparés.
local samePass = V2.BreakSeconds == Balance.WindowHP.SoloBreakTime
if not samePass then
	print(`note : proposition_v2.luau en est à une casse de {V2.BreakSeconds} s, le jeu à {Balance.WindowHP.SoloBreakTime} s (passe 3) : PV des vitrines non comparés`)
end
eq(Potions.ById.Strength.Multiplier, V2.PotionStrength, "potion de force de la proposition")
eq(Config.PvP.PlayerWindowHPPerDamage, V2.PlayerWindowHPPerDamage, "portes : 50 × dégâts")

local Modele = charge("Outil/modele")
local proposed, actual = V2.Construire(), Modele.EcoActuelle()
for index, zone in proposed.Zones do
	local real = actual.Zones[index]
	for _, field in if samePass then { "WindowHP", "AdvisedDamage", "ReturnDistance", "BaseIncome", "SpeedShown", "StrengthShown", "TeamHits" } else { "AdvisedDamage", "ReturnDistance", "BaseIncome", "SpeedShown", "StrengthShown", "TeamHits" } do
		eq(real[field], zone[field], `simulateur, zone {index} : {field}`)
	end
	near(real.AdvisedSpeed, zone.AdvisedSpeed, 1e-9, `simulateur, zone {index} : AdvisedSpeed`)
	near(real.GuardSpeed, zone.GuardSpeed, 1e-9, `simulateur, zone {index} : GuardSpeed`)
end
for level = 0, 19 do
	eq(actual.MachineGain("Treadmill", level), proposed.MachineGain("Treadmill", level), `simulateur : gain du tapis au niveau enregistré {level}`)
	eq(actual.UpgradeCost("Treadmill", level), proposed.UpgradeCost("Treadmill", level), `simulateur : prix du tapis au niveau enregistré {level}`)
end
for level = 1, 6 do
	eq(actual.DoorHP(level), proposed.DoorHP(level), `simulateur : porte de niveau {level}`)
end
for _, speed in { 0, 808, 37_800, 1.3e6, 49.7e6, 1.6e9 } do
	near(actual.WalkSpeed(speed, 3), proposed.WalkSpeed(speed, 3), 1e-9, `simulateur : marche à {speed} × trail 3`)
end
eq(actual.HitDamage(300, 999, 5), proposed.HitDamage(300, 999, 5), "simulateur : dégâts")
eq(actual.MaxHits, proposed.MaxHits, "simulateur : plafond de coups")
if samePass then
	eq(actual.CasseMax, proposed.CasseMax, "simulateur : casse acceptée")
end
eq(actual.BestDamage, proposed.BestDamage, "simulateur : meilleur kit")

print(`banc a134 (rééquilibrage v2 dans Config) : {checks} vérification(s), {fails} échec(s)`)
