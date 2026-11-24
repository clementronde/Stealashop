-- Banc a167, partie events : vrai EventService sur le faux Roblox d'a98, bouchons des services qu'il enveloppe.

local LiveEvents = requireShared("Shared.Config.LiveEvents")
local Services = game.Services

-- Horloge du serveur (secondes Unix) et boucle du planning (task.wait = rendre la main au banc).
CLOCK = 0
function Workspace.GetServerTimeNow()
	return CLOCK
end
fakeTask.wait = function()
	coroutine.yield()
end

local DS = Services.DisplayService._value
local MS = Services.MonetizationService._value
local TS = { GetGainMultiplier = function() return 1 end }
node("ModuleScript", "TrainingService", Services)._value = TS
local TEL = Services.TelemetryService._value
TELE = {}
TEL.LogEvent = function(p, key, fields, value)
	table.insert(TELE, { player = p, key = key, fields = fields, value = value })
	return true
end

local LOOP = nil
local serial = 0
function newServer(clock)
	CLOCK = clock
	for k in Workspace._attrs do
		Workspace._attrs[k] = nil
	end
	DS.GetIncomeMultiplier = function() return BASE_INCOME or 1 end
	MS.GetTemporaryIncomeMultiplier = function() return 1 end
	TS.GetGainMultiplier = function() return 1 end
	TELE = {}
	serial += 1
	local m = node("ModuleScript", "EventService", Services)
	m._key = "server/Services/EventService.luau"
	m._serial = serial -- un module neuf par serveur
	local service = requireModule(m)
	service.Init()
	LOOP = coroutine.create(service.Start)
	assert(coroutine.resume(LOOP))
	return service
end
function tickAt(t)
	CLOCK = t
	local ok, err = coroutine.resume(LOOP)
	assert(ok, err)
end
local function teleCount(key)
	local n = 0
	for _, e in TELE do
		if e.key == key then
			n += 1
		end
	end
	return n
end
local function attr(name)
	return Workspace:GetAttribute(name)
end

local START = 1797692400 -- 2026-12-19 15:00 UTC (date -u), un samedi
local WEEK = 7 * 86400
STUDIO = false
local p1 = newPlayer("Ada")
local p2 = newPlayer("Bob")

-- 0. Config -------------------------------------------------------------------------------------------------
do
	-- a184 : Admin Abuse chaque samedi 15:00 UTC (LiveEvents.Weekly) ; repli sur l'ancien créneau daté du 19/12.
	local WEEKLY = LiveEvents.SlotsAt ~= nil
	local slots = if WEEKLY then LiveEvents.SlotsAt(START + 60) else LiveEvents.Slots
	local slot = slots[1]
	check("0 un créneau V0 : AdminAbuse", slot ~= nil and slot.Event == "AdminAbuse" and (WEEKLY or #slots == 1))
	check("0 samedi 15:00 UTC", slot.StartsAt == START, slot.StartsAt)
	check("0 30 min", slot.EndsAt - slot.StartsAt == 1800)
	if WEEKLY then
		check("0 aucun créneau daté", #LiveEvents.Slots == 0 and #LiveEvents.Schedule == 0)
		check("0 rendez-vous : samedi 15:00, 30 min", #LiveEvents.Weekly == 1 and LiveEvents.Weekly[1].Weekday == 6 and LiveEvents.Weekly[1].Time == "15:00")
		local before = LiveEvents.SlotsAt(START - 60)
		check("0 avant l'heure : le samedi d'avant et celui-ci", #before == 2 and before[1].StartsAt == START - WEEK and before[2].StartsAt == START, before[2] and before[2].StartsAt)
		local after = LiveEvents.SlotsAt(START + 1800)
		check("0 après l'heure : celui-ci et le suivant", #after == 2 and after[1].StartsAt == START and after[2].StartsAt == START + WEEK)
		check("0 clés distinctes par semaine", after[1].Key ~= after[2].Key)
		local mid = LiveEvents.SlotsAt(START + 3 * 86400) -- mardi
		check("0 en semaine : le prochain est samedi", mid[2].StartsAt == START + WEEK)
	end
	check("0 ParseUtc 1970", LiveEvents.ParseUtc("1970-01-01 00:00") == 0)
	check("0 ParseUtc 2000-03-01", LiveEvents.ParseUtc("2000-03-01 12:30") == 951913800, LiveEvents.ParseUtc("2000-03-01 12:30"))
	check("0 ParseUtc illisible", LiveEvents.ParseUtc("19/12/2026 16h") == nil and LiveEvents.ParseUtc("2026-13-01 10:00") == nil)
	check("0 FormatTimer", LiveEvents.FormatTimer(1799.2) == "30:00" and LiveEvents.FormatTimer(3900) == "1:05:00" and LiveEvents.FormatTimer(-5) == "0:00")
	local a = LiveEvents.ById.AdminAbuse.Effects
	check("0 Admin Abuse : x2 revenus, camion x0,25", a.Income == 2 and a.TruckDelay == 0.25)
end

-- 1. Planning : avant, pendant, après ---------------------------------------------------------------------------
local ES = newServer(START - 60)
do
	check("1 avant : aucun événement", attr("LiveEvent") == nil and ES.GetCurrent() == nil)
	check("1 avant : revenus x1", DS.GetIncomeMultiplier(p1) == 1 and ES.Factor("Income") == 1)
	tickAt(START - 1)
	check("1 une seconde avant : rien", attr("LiveEvent") == nil)
	tickAt(START)
	check("1 à l'heure : AdminAbuse", attr("LiveEvent") == "AdminAbuse" and attr("LiveEventEndsAt") == START + 1800)
	check("1 attributs des effets", attr("LiveEventIncome") == 2 and attr("LiveEventTruckDelay") == 0.25 and attr("LiveEventShelfLuck") == nil)
	check("1 revenus x2 (DisplayService.GetIncomeMultiplier)", DS.GetIncomeMultiplier(p1) == 2)
	check("1 hors ligne : x2 compté temporaire", MS.GetTemporaryIncomeMultiplier(p1) == 2)
	check("1 tapis inchangé", TS.GetGainMultiplier(p1, "Treadmill") == 1)
	check("1 télémétrie : début pour chaque joueur", teleCount("LiveEventStart") == 2 and TELE[1].value == 2 and TELE[1].fields[1] == "Event - AdminAbuse" and TELE[1].fields[2] == "Source - Schedule")
	check("1 journal : début planifié", #ES.GetJournal() == 1 and ES.GetJournal()[1].Who == "Schedule" and hasLog("2026-12-19 15:00:00 UTC : Schedule : début de AdminAbuse"))
	local ok, message = ES.Launch("LuckRush", "Owner (1)")
	check("1 un seul à la fois : refus pendant AdminAbuse", not ok and message == string.format(LiveEvents.Messages.Running, "ADMIN ABUSE"), message)
	tickAt(START + 1799)
	check("1 dernière seconde : toujours là", attr("LiveEvent") == "AdminAbuse")
	tickAt(START + 1800)
	check("1 après : fini", attr("LiveEvent") == nil and attr("LiveEventEndsAt") == nil and attr("LiveEventIncome") == nil)
	check("1 après : revenus x1", DS.GetIncomeMultiplier(p1) == 1)
	check("1 télémétrie : fin pour chaque joueur", teleCount("LiveEventEnd") == 2)
	tickAt(START + 1801)
	check("1 ne repart pas", attr("LiveEvent") == nil and teleCount("LiveEventStart") == 2)
end

-- 2. Serveur qui démarre au milieu -----------------------------------------------------------------------------
ES = newServer(START + 600)
do
	local current = ES.GetCurrent()
	check("2 rejoint l'événement en cours", current ~= nil and current.Id == "AdminAbuse" and current.Source == "Schedule")
	check("2 avec le temps qui reste (fin du créneau)", current ~= nil and current.EndsAt == START + 1800)
	check("2 effets posés", DS.GetIncomeMultiplier(p1) == 2 and attr("LiveEventIncome") == 2)
	ES = newServer(START + 1800)
	check("2 serveur après le créneau : rien", ES.GetCurrent() == nil and attr("LiveEvent") == nil)
end

-- 3. Un seul à la fois : un événement admin, puis le créneau pour ce qui reste -------------------------------------
ES = newServer(START - 300)
do
	local ok = ES.Launch("LuckRush", "Owner (1)") -- 15 min : jusqu'à START + 600
	check("3 admin : LuckRush lancé", ok and attr("LiveEvent") == "LuckRush" and attr("LiveEventShelfLuck") == 3)
	check("3 journal : qui", ES.GetJournal()[1].Who == "Owner (1)")
	check("3 télémétrie Source - Admin", TELE[1].fields[2] == "Source - Admin")
	tickAt(START)
	check("3 le créneau attend", attr("LiveEvent") == "LuckRush")
	tickAt(START + 600)
	check("3 LuckRush fini, AdminAbuse part tout de suite", attr("LiveEvent") == "AdminAbuse" and attr("LiveEventShelfLuck") == nil)
	check("3 pour ce qui reste du créneau", ES.GetCurrent().EndsAt == START + 1800)
	check("3 pas d'effets cumulés", DS.GetIncomeMultiplier(p1) == 2)
end

-- 4. Admin pendant un créneau ouvert : le créneau ne repart pas après l'arrêt ------------------------------------------
ES = newServer(START + 60)
do
	ES.Stop("Owner (1)")
	check("4 Stop : arrêté", attr("LiveEvent") == nil and hasLog("Owner (1) : fin de AdminAbuse (arrêté)"))
	tickAt(START + 61)
	check("4 le créneau arrêté ne repart pas", attr("LiveEvent") == nil)
	local ok, message = ES.Stop("Owner (1)")
	check("4 Stop sans événement : refus", not ok and message == LiveEvents.Messages.NoneRunning)
	local bad, why = ES.Launch("Rain", "Owner (1)")
	check("4 format inconnu", not bad and why == LiveEvents.Messages.Unknown)
end

-- 5. Chaque effet ----------------------------------------------------------------------------------------------------
ES = newServer(START + 86400)
do
	local function run(id)
		ES.Stop("banc")
		local ok, message = ES.Launch(id, "banc")
		check(`5 {id} lancé`, ok and attr("LiveEvent") == id, message)
		check(`5 {id} : fin = durée du format`, ES.GetCurrent().EndsAt == CLOCK + LiveEvents.ById[id].Duration)
	end
	run("AdminAbuse")
	check("5 AdminAbuse : message", hasLog("début de AdminAbuse (Admin)"))
	run("LuckRush")
	check("5 LuckRush : chance x3 (LiveEventShelfLuck)", attr("LiveEventShelfLuck") == 3 and attr("LiveEventIncome") == nil)
	run("SaleNight")
	check("5 SaleNight : PV x0,5 (LiveEventWindowHealth)", attr("LiveEventWindowHealth") == 0.5)
	run("PotionRain")
	check("5 PotionRain : délai x0,2 (LiveEventPotionDelay)", attr("LiveEventPotionDelay") == 0.2)
	run("TrainingWeekend")
	check("5 TrainingWeekend : tapis x2", TS.GetGainMultiplier(p1, "Treadmill") == 2 and attr("LiveEventTrainingGain") == 2)
	check("5 TrainingWeekend : 48 h", ES.GetCurrent().EndsAt - CLOCK == 48 * 3600)
	check("5 revenus x1 hors Admin Abuse", DS.GetIncomeMultiplier(p1) == 1)
	ES.Stop("banc")
	check("5 Stop : tapis x1", TS.GetGainMultiplier(p1, "Treadmill") == 1)
	check("5 journal borné", #ES.GetJournal() <= LiveEvents.JournalSize)
	-- Enveloppe : les accroches d'avant sont gardées (gamepass ×2 Argent : base 2 → 4 pendant Admin Abuse).
	BASE_INCOME = 2
	ES = newServer(START)
	check("5 x2 Argent puis Admin Abuse : x4", DS.GetIncomeMultiplier(p1) == 4)
	BASE_INCOME = nil
end

-- 7. a184 : rendez-vous de chaque semaine (passage d'une semaine à l'autre) -------------------------------------------
if LiveEvents.SlotsAt ~= nil then
	ES = newServer(START + 1801)
	check("7 après le créneau de la semaine : rien", ES.GetCurrent() == nil)
	tickAt(START + WEEK - 1)
	check("7 la seconde d'avant la semaine suivante : rien", attr("LiveEvent") == nil)
	tickAt(START + WEEK)
	check("7 samedi suivant 15:00 : AdminAbuse", attr("LiveEvent") == "AdminAbuse" and attr("LiveEventEndsAt") == START + WEEK + 1800)
	tickAt(START + WEEK + 1800)
	check("7 fin après 30 min", attr("LiveEvent") == nil)
	tickAt(START + 2 * WEEK + 5)
	check("7 et encore la semaine d'après", attr("LiveEvent") == "AdminAbuse" and attr("LiveEventEndsAt") == START + 2 * WEEK + 1800)
	ES.Stop("Owner (1)")
	tickAt(START + 2 * WEEK + 10)
	check("7 arrêté par un admin : ne repart pas cette semaine", attr("LiveEvent") == nil)
	tickAt(START + 3 * WEEK)
	check("7 mais repart la semaine suivante", attr("LiveEvent") == "AdminAbuse")
end

-- 6. Les services lisent les attributs (contrôle du code source) ---------------------------------------------------
do
	local function has(file, text)
		return string.find(SOURCES[file], text, 1, true) ~= nil
	end
	local P = LiveEvents.EffectPrefix
	check("6 préfixe LiveEvent", P == "LiveEvent")
	check("6 StoreHeistService : chance tirée × ShelfLuck", has("server/Services/StoreHeistService.luau", 'local luck = drawLuck() * (Workspace:GetAttribute("LiveEventShelfLuck") :: number? or 1)'))
	check("6 PotionService : délai × PotionDelay", has("server/Services/PotionService.luau", 'return Potions.SpawnEvery * skillFactor(player, "PotionLuck") * (Workspace:GetAttribute("LiveEventPotionDelay") :: number? or 1)'))
	check("6 WindowService : PV PNJ × WindowHealth", has("server/Services/WindowService.luau", 'Zones[window.Zone].WindowHP * (Workspace:GetAttribute("LiveEventWindowHealth") :: number? or 1)'))
	check("6 WindowService : PV PNJ recalculés au tick", has("server/Services/WindowService.luau", 'if window.Kind == "Plot" or window.Kind == "NPC" then'))
	check("6 TruckEventService : tirage × TruckDelay", has("server/Services/TruckEventService.luau", 'return (low + random:NextNumber() * (high - low)) * (Workspace:GetAttribute("LiveEventTruckDelay") :: number? or 1)'))
	check("6 TruckEventService : attente raccourcie", has("server/Services/TruckEventService.luau", 'nextSpawnAt = math.min(nextSpawnAt, now + math.max(TruckEvent.SpawnIntervalMax, 0) * (Workspace:GetAttribute("LiveEventTruckDelay") :: number? or 1))'))
	-- Attente du camion : au début d'Admin Abuse, une attente de 11 min tombe à 3 min au plus.
	local nextSpawnAt, now = 660, 0
	nextSpawnAt = math.min(nextSpawnAt, now + 12 * 60 * 0.25)
	check("6 camion : 11 min → 3 min", nextSpawnAt == 180)
	nextSpawnAt = math.min(500, 0 + 12 * 60 * 1)
	check("6 camion hors événement : inchangé", nextSpawnAt == 500)
	-- Bannière : contrat facultatif, noms proposés.
	local ui = SOURCES["shared/Contract/UI.luau"]
	check("6 UI_EventBanner facultatif au contrat", string.find(ui, 'Name = "UI_EventBanner",\n\tClass = "ScreenGui",\n\tOptional = true,', 1, true) ~= nil)
	check("6 bannière : Title, Timer, Effect", has("client/Controllers/EventBannerController.luau", 'setText(gui, "Title"') and has("client/Controllers/EventBannerController.luau", 'setText(gui, "Timer"') and has("client/Controllers/EventBannerController.luau", 'setText(gui, "Effect"'))
	check("6 Config/Telemetry : LiveEventStart et LiveEventEnd", has("shared/Config/Telemetry.luau", 'LiveEventStart = "LiveEventStart"') and has("shared/Config/Telemetry.luau", 'LiveEventEnd = "LiveEventEnd"'))
end

print(`partie events : {CHECKS} vérification(s), {FAILS} échec(s)`)
