-- Copie a147 (2026-11-14, vague 41) : Eve, arrivée après Ada avec les mêmes uid, a ses uid renommés par uids-uniques.luau
-- (« v-soda#2 ») : la ligne 67 d origine attend « v-soda » ; elle attend maintenant l uid du présentoir 1 d Eve à son arrivée.
--!nocheck
-- Scénario « custom » : les événements custom (LogCustomEvent) branchés sur les vrais services.
--   PvPTheftSuccess : vol entre joueurs déposé (PvPService.OnTheftEnded « Stolen ») ;
--   PvPTheftFail : vol raté, avec sa raison (batte de la victime, mort du voleur, attrapé la nuit,
--     départ de la victime, batte d'un tiers) ;
--   BatBoxKnockdown : colis PNJ que la batte fait tomber hors zone safe (BatService.OnHit « Box »),
--     colis d'un magasin ou du camion ; rien pour les autres usages de la batte ;
--   GuardCatch : porteur d'un colis PNJ rattrapé (CarryService.Fail(…, "Caught"), comme le vigile),
--     par zone et par phase ; rien pour les autres fins de portage, ni pour un objet volé attrapé.

startServer()

local adaData = victimProfile()
local ada = join("Ada", adaData)
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
local dan = join("Dan", newProfile())
local eveData = victimProfile()
local eve = join("Eve", eveData)
local eveSoda = eveData.Display["1"] -- a147 : uid renommé à l'arrivée (uids-uniques.luau)
for _, player in { ada, bob, cy, dan, eve } do
	giveBat(player)
end
advance(1.2)
local adaShop = shopOf(ada)
local eveShop = shopOf(eve)

local function expect(e, label, name, player, f1, f2, f3)
	check(e ~= nil, `{label} : un événement {name}`)
	if e == nil then
		return
	end
	check(e.name == name and e.player == player, `{label} : {name} pour {player.Name} (trouvé {e.name} pour {e.player and e.player.Name})`)
	check(e.value == 1, `{label} : valeur 1 (trouvé {tostring(e.value)})`)
	check(fieldOf(e, 1) == f1, `{label} : champ 1 « {tostring(f1)} » (trouvé {tostring(fieldOf(e, 1))})`)
	check(fieldOf(e, 2) == f2, `{label} : champ 2 « {tostring(f2)} » (trouvé {tostring(fieldOf(e, 2))})`)
	check(fieldOf(e, 3) == f3, `{label} : champ 3 « {tostring(f3)} » (trouvé {tostring(fieldOf(e, 3))})`)
end
local function equipBat(player)
	if not holdsBat(player) then
		humanoidOf(player):EquipTool(batOf(player))
	end
end
local function boxPayload(zone, rarity, storeId)
	local def = Items.ByZone[zone][rarity][1]
	return { Kind = "NPCBox", Tier = "Premium", Zone = zone, Rarity = rarity, ItemId = def.Id, StoreId = storeId, SlotId = `{storeId}/01` }
end

section("vol réussi")
check(breakDoor(bob, adaShop), "porte d'Ada cassée par Bob")
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
check(#ANALYTICS.custom == 0, "rien à la prise : l'événement part à la fin du vol")
runHome(bob, adaShop)
check(adaData.Items["v-soda"] == nil and DataService.Get(bob).Items["v-soda"] ~= nil, "objet déposé chez Bob")
local list = eventsNamed("PvPTheftSuccess")
check(#list == 1, `un PvPTheftSuccess (trouvé {#list})`)
expect(list[1], "vol réussi", "PvPTheftSuccess", bob, "Rarity - Common", "Zone - 1", nil)
check(#eventsNamed("PvPTheftFail") == 0, "aucun PvPTheftFail")
check(logHas("Bob : PvPTheftSuccess (Rarity - Common, Zone - 1)", "PRINT", "server"), "Studio : une ligne dans la sortie")

section("vol raté : la victime frappe son voleur à la batte")
check(breakDoor(bob, eveShop), "porte d'Eve cassée par Bob")
check(steal(bob, eveShop, 1), "Bob prend la Canette de soda d'Eve")
moveTo(eve, rootOf(bob).Position + Vector3.new(0, 0, 4), Vector3.new(0, 0, -1))
equipBat(eve)
fireAs(eve, "SwingBat")
flush()
check(not CarryService.IsCarrying(bob) and eveData.Display["1"] == eveSoda, "l'objet revient sur son présentoir")
list = eventsNamed("PvPTheftFail", bob)
expect(lastOf(list), "batte de la victime", "PvPTheftFail", bob, "Reason - Bat", "Rarity - Common", "Zone - 1")
check(#eventsNamed("BatBoxKnockdown") == 0, "un coup sur un voleur n'est pas un colis tombé (usage « Defend »)")

section("vol raté : le voleur meurt")
advance(3.1)
check(steal(cy, eveShop, 2), "Cy prend le Paquet de chips d'Eve (porte encore ouverte)")
kill(cy)
flush()
expect(lastOf(eventsNamed("PvPTheftFail", cy)), "mort du voleur", "PvPTheftFail", cy, "Reason - Died", "Rarity - Common", "Zone - 1")
spawnCharacter(cy, HUB_CENTER)
giveBat(cy)

section("vol raté : voleur attrapé par un vigile de nuit")
check(breakDoor(bob, eveShop), "porte d'Eve recassée par Bob")
check(steal(bob, eveShop, 4), "Bob prend le Donut d'Eve")
local guardsBefore = #eventsNamed("GuardCatch")
CarryService.Fail(bob, "Caught")
flush()
expect(lastOf(eventsNamed("PvPTheftFail", bob)), "voleur attrapé", "PvPTheftFail", bob, "Reason - Caught", "Rarity - Common", "Zone - 1")
check(#eventsNamed("GuardCatch") == guardsBefore, "un objet volé attrapé n'est pas un GuardCatch (colis PNJ seulement)")

section("vol raté : coup de batte d'un tiers hors zone safe")
advance(3.1)
check(steal(bob, eveShop, 5), "Bob prend la Banane d'Eve")
moveTo(bob, Vector3.new(400, 3, 0), Vector3.new(0, 0, -1))
moveTo(cy, Vector3.new(400, 3, 4), Vector3.new(0, 0, -1))
equipBat(cy)
local knocks = #eventsNamed("BatBoxKnockdown")
fireAs(cy, "SwingBat")
flush()
expect(lastOf(eventsNamed("PvPTheftFail", bob)), "batte d'un tiers", "PvPTheftFail", bob, "Reason - Bat", "Rarity - Common", "Zone - 1")
check(#eventsNamed("BatBoxKnockdown") == knocks, "coup « Thief » : pas de BatBoxKnockdown")

section("vol raté : la victime part")
spawnCharacter(bob, HUB_CENTER)
check(breakDoor(cy, eveShop), "porte d'Eve cassée par Cy")
check(steal(cy, eveShop, 2), "Cy prend le Paquet de chips d'Eve")
leave(eve)
flush()
expect(lastOf(eventsNamed("PvPTheftFail", cy)), "départ de la victime", "PvPTheftFail", cy, "Reason - VictimLeft", "Rarity - Common", "Zone - 1")
check(#eventsNamed("PvPTheftSuccess") == 1, "toujours un seul vol réussi")
check(#eventsNamed("PvPTheftFail") == 5, `5 vols ratés en tout (trouvé {#eventsNamed("PvPTheftFail")})`)

section("colis PNJ tombé à la batte (usage « Box »)")
-- (un personnage neuf est posé chez lui par PlotService : on déplace les personnages existants)
moveTo(cy, Vector3.new(420, 3, 4), Vector3.new(0, 0, -1))
equipBat(cy)
moveTo(dan, Vector3.new(420, 3, 0), Vector3.new(0, 0, -1))
check(CarryService.StartCarry(dan, boxPayload(2, "Rare", "STORE_Z2_Kiosque")), "Dan porte un colis Rare de la zone 2 hors zone safe")
advance(0.9)
fireAs(cy, "SwingBat")
flush()
check(not CarryService.IsCarrying(dan), "le colis de Dan tombe")
list = eventsNamed("BatBoxKnockdown")
check(#list == 1, `un BatBoxKnockdown (trouvé {#list})`)
expect(list[1], "colis de magasin", "BatBoxKnockdown", cy, "Zone - 2", "Rarity - Rare", "Source - Store")
advance(3.2) -- immunité de Dan après le coup (6.4) et étourdissement
moveTo(dan, Vector3.new(420, 3, 0), Vector3.new(0, 0, -1))
check(CarryService.StartCarry(dan, boxPayload(3, "Epic", "Truck_1")), "Dan porte un colis Épique du camion (zone 3)")
fireAs(cy, "SwingBat")
flush()
list = eventsNamed("BatBoxKnockdown")
check(#list == 2, `un second BatBoxKnockdown (trouvé {#list})`)
expect(list[2], "colis du camion", "BatBoxKnockdown", cy, "Zone - 3", "Rarity - Epic", "Source - Truck")
check(#eventsNamed("GuardCatch") == guardsBefore, "un colis tombé n'est pas une capture")

section("capture par un vigile, par zone et par phase")
advance(3.2)
spawnCharacter(dan, Vector3.new(500, 3, 0))
check(CarryService.StartCarry(dan, boxPayload(4, "Epic", "STORE_Z4_Bijouterie")), "Dan porte un colis Épique de la zone 4")
CarryService.Fail(dan, "Caught")
flush()
list = eventsNamed("GuardCatch")
check(#list == guardsBefore + 1, "un GuardCatch")
expect(lastOf(list), "capture de jour", "GuardCatch", dan, "Zone - 4", "Phase - Day", "Rarity - Epic")
PHASE = "Night"
check(CarryService.StartCarry(dan, boxPayload(5, "Common", "STORE_Z5_Pharmacie")), "Dan porte un colis Commun de la zone 5, la nuit")
CarryService.Fail(dan, "Caught")
flush()
expect(lastOf(eventsNamed("GuardCatch")), "capture de nuit", "GuardCatch", dan, "Zone - 5", "Phase - Night", "Rarity - Common")
PHASE = "Day"
PHASE_FAILS = true
check(CarryService.StartCarry(dan, boxPayload(1, "Common", "STORE_Z1_Superette")), "Dan porte un colis de la zone 1, phase illisible")
CarryService.Fail(dan, "Caught")
flush()
expect(lastOf(eventsNamed("GuardCatch")), "phase illisible", "GuardCatch", dan, "Zone - 1", nil, "Rarity - Common")
PHASE_FAILS = false
local catches = #eventsNamed("GuardCatch")
check(CarryService.StartCarry(dan, boxPayload(1, "Common", "STORE_Z1_Superette")), "Dan reporte un colis")
kill(dan)
flush()
spawnCharacter(dan, Vector3.new(500, 3, 0))
check(CarryService.StartCarry(dan, boxPayload(1, "Common", "STORE_Z1_Superette")), "et encore un")
CarryService.Consume(dan, "Placed")
CarryService.Fail(dan, "Anomaly") -- ne porte plus rien : sans effet
flush()
check(#eventsNamed("GuardCatch") == catches, "mort ou colis posé : pas de GuardCatch")
-- Correctif du 2026-11-08 : capture de nuit sans colis, par GuardService.OnCatch.
local guardStub = serverModule("GuardService")
guardStub._catch(dan, 3, true, false)
flush()
expect(lastOf(eventsNamed("GuardCatch")), "capture de nuit sans colis", "GuardCatch", dan, "Zone - 3", "Phase - Night", "Rarity - None")
check(#eventsNamed("GuardCatch") == catches + 1, "capture de nuit sans colis : un GuardCatch")
guardStub._catch(dan, 3, true, true) -- avec colis : déjà compté par OnCarryEnded
guardStub._catch(dan, 3, false, false) -- de jour sans colis : rien
flush()
check(#eventsNamed("GuardCatch") == catches + 1, "avec colis, ou de jour : rien de plus par OnCatch")

section("fin")
check(noRefusal(), "aucun événement refusé par le faux AnalyticsService (noms et champs)")
local names = {}
for _, name in Telemetry.Events do
	names[name] = true
end
for _, e in ANALYTICS.custom do
	if not names[e.name] or e.value ~= 1 then
		check(false, `événement inattendu : {e.name} = {tostring(e.value)}`)
	end
end
local economy = ANALYTICS.economy
check(#economy == 1 and economy[1].player == eve and economy[1].sku == "Income", "seul envoi d'économie : la caisse d'Eve, encaissée à son départ")
check(not logHas("[TelemetryService]", "WARN"), "aucun avertissement de TelemetryService")
check(not logHas("ERREUR"), "aucune erreur dans les tâches")

if VERBOSE then
	dumpLog("TelemetryService")
end
summary("scénario custom")
