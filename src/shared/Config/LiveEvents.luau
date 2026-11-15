--!strict
-- Événements live du samedi (MAJ 0 ; docs/claude/notes/feuille-de-route-maj.md, section 3 ; vague 51, a167).
-- Lu par EventService (serveur : planning, effets, panel admin), AdminLists (choix du panel) et
-- EventBannerController (client : bannière UI_EventBanner). Toutes les valeurs sont V0 proposées, absentes du
-- doc, sauf le rendez-vous de chaque samedi à 16 h (Paris) et les formats de la section 3.
--
-- Formats : un événement = Id, nom affiché, effet en une ligne (textes du jeu, en anglais), durée par défaut (s)
-- et effets. Un effet = un facteur (> 0, fini) ; absent = 1. Effets connus (EffectIds) et où ils jouent :
--   Income        × revenus des présentoirs, tout le serveur (DisplayService.GetIncomeMultiplier ; exclu des
--                 gains hors ligne comme les boosts : MonetizationService.GetTemporaryIncomeMultiplier)
--   ShelfLuck     × chance tirée à l'ouverture d'un colis de rayon (StoreHeistService.startOpening) : les
--                 raretés au-dessus du seuil sortent plus souvent, « ×N LUCK » affiché monte plus haut
--   TruckDelay    × délai entre deux camions (TruckEventService : tirage et attente en cours)
--   PotionDelay   × délai entre deux potions (PotionService.spawnInterval)
--   WindowHealth  × PV des vitrines PNJ (WindowService.computeMaxHP, recalculé à chaque tick)
--   TrainingGain  × gains du tapis (TrainingService.GetGainMultiplier)
-- Les effets s'ajoutent aux gamepasses et aux potions (multiplicateurs), jamais entre événements : un seul à la
-- fois (EventService).
--
-- Pas encore en format (section 3) : Pluie de colis (plus de colis au sol depuis a158 : elle attend une pluie
-- d'objets à décider), Nuit éternelle (la nuit ferme le couloir et se raccourcit dès qu'il est vide : règle à
-- décider), Fortune garantie (Fortune Tower coupée jusqu'à la MAJ 2).
--
-- Planning : deux listes. Weekly = les rendez-vous de chaque semaine (Cantin, 15/11 : pas de date fixe) : Event,
-- Weekday (0 = dimanche … 6 = samedi), Time = « HH:MM » en UTC (Paris = UTC + 1 l'hiver), Duration facultative.
-- Schedule = les créneaux datés, ponctuels : Event = Id d'un format, Start = « AAAA-MM-JJ HH:MM » en UTC,
-- Duration facultative (s, sinon celle du format). Tous les serveurs lisent la même heure (horloge du serveur,
-- Workspace:GetServerTimeNow) : l'événement part partout à la même seconde, sans admin ; un serveur qui démarre
-- pendant le créneau le rejoint avec le temps qui reste. Slots = les créneaux datés calculés (début et fin en
-- secondes Unix), triés par début ; SlotsAt(t) = Slots plus, pour chaque rendez-vous de Weekly, le dernier créneau
-- commencé à t et le suivant (Key « <Event>@<début Unix> »). Une ligne fausse (format inconnu, date ou heure
-- illisible, durée nulle) arrête le chargement.
--
-- État répliqué (attributs du Workspace, posés par EventService seul) : IdAttribute (Id du format, absent hors
-- événement), EndsAtAttribute (fin, heure du serveur), et un attribut EffectPrefix .. <effet> par effet ≠ 1
-- (« LiveEventIncome » = 2…), que les services lisent en une ligne (absent = 1).

local DeepFreeze = require(script.Parent.DeepFreeze)

export type Format = {
	Id: string,
	DisplayName: string, -- titre de la bannière (Title)
	Effect: string, -- effet en une ligne (Effect)
	Duration: number, -- s, durée par défaut (lancement par un admin, ligne du planning sans Duration)
	Effects: { [string]: number },
}

export type Planned = {
	Event: string,
	Start: string, -- UTC, « AAAA-MM-JJ HH:MM »
	Duration: number?,
}

export type Weekly = {
	Event: string,
	Weekday: number, -- 0 = dimanche … 6 = samedi
	Time: string, -- UTC, « HH:MM »
	Duration: number?,
}

export type Slot = {
	Key: string, -- « <Event>@<Start> » : un créneau n'est lancé qu'une fois par serveur
	Event: string,
	StartsAt: number, -- secondes Unix (UTC)
	EndsAt: number,
}

local EffectIds = { "Income", "ShelfLuck", "TruckDelay", "PotionDelay", "WindowHealth", "TrainingGain" }

local Formats: { Format } = {
	-- Le rendez-vous du samedi 16 h : ×2 revenus pour tous, camion toutes les 2 à 3 min (8 à 12 min × 0,25).
	-- Un admin distribue des colis dans le hub avec le panel (GiveBox), rien d'automatique.
	{ Id = "AdminAbuse", DisplayName = "ADMIN ABUSE", Effect = "x2 cash for everyone, trucks every 2-3 min", Duration = 30 * 60, Effects = { Income = 2, TruckDelay = 0.25 } },
	-- Chance ×3 : la chance tirée à chaque ouverture de colis de rayon est triplée.
	{ Id = "LuckRush", DisplayName = "LUCK x3", Effect = "x3 luck on every shelf box", Duration = 15 * 60, Effects = { ShelfLuck = 3 } },
	-- Nuit des soldes (Partie 2, section 5) : vitrines PNJ à −50 % de PV.
	{ Id = "SaleNight", DisplayName = "SALE NIGHT", Effect = "Store windows at half health", Duration = 10 * 60, Effects = { WindowHealth = 0.5 } },
	-- Pluie de potions : 5 fois plus fréquentes.
	{ Id = "PotionRain", DisplayName = "POTION RAIN", Effect = "Potions spawn 5x more often", Duration = 10 * 60, Effects = { PotionDelay = 0.2 } },
	-- Week-end ×2 entraînement : samedi et dimanche.
	{ Id = "TrainingWeekend", DisplayName = "TRAINING WEEKEND", Effect = "x2 treadmill gains", Duration = 48 * 3600, Effects = { TrainingGain = 2 } },
}

-- V0 : le rendez-vous du samedi, 16 h à Paris (15:00 UTC), 30 min, chaque semaine.
local Weekly: { Weekly } = {
	{ Event = "AdminAbuse", Weekday = 6, Time = "15:00", Duration = 30 * 60 },
}

-- Créneaux datés ponctuels : aucun (les autres formats se lancent au panel admin, StartEvent).
local Schedule: { Planned } = {}

-- Jours depuis le 1970-01-01 pour une date du calendrier grégorien (algorithme « days from civil »).
local function daysFromCivil(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (month + 9) % 12
	local doy = (153 * mp + 2) // 5 + day - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- « AAAA-MM-JJ HH:MM » (UTC) → secondes Unix ; nil si illisible.
local function parseUtc(text: string): number?
	local ys, mos, ds, hs, mis = string.match(text, "^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d)$")
	if ys == nil then
		return nil
	end
	local year, month, day = tonumber(ys) :: number, tonumber(mos) :: number, tonumber(ds) :: number
	local hour, minute = tonumber(hs) :: number, tonumber(mis) :: number
	if month < 1 or month > 12 or day < 1 or day > 31 or hour > 23 or minute > 59 then
		return nil
	end
	return daysFromCivil(year, month, day) * 86400 + hour * 3600 + minute * 60
end

local function isFactor(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge
end

local ById: { [string]: Format } = {}
for _, format in Formats do
	assert(ById[format.Id] == nil, `Config.LiveEvents : format en double {format.Id}`)
	assert(format.Duration > 0 and format.Duration < math.huge, `Config.LiveEvents : durée de {format.Id} invalide`)
	for effect, factor in format.Effects do
		assert(table.find(EffectIds, effect) ~= nil, `Config.LiveEvents : effet inconnu {effect} ({format.Id})`)
		assert(isFactor(factor), `Config.LiveEvents : facteur de {effect} invalide ({format.Id})`)
	end
	ById[format.Id] = format
end

local Slots: { Slot } = {}
for _, planned in Schedule do
	local format = ById[planned.Event]
	assert(format ~= nil, `Config.LiveEvents : planning, format inconnu {planned.Event}`)
	local startsAt = parseUtc(planned.Start)
	assert(startsAt ~= nil, `Config.LiveEvents : planning, date illisible « {planned.Start} » (AAAA-MM-JJ HH:MM, UTC)`)
	local duration = planned.Duration or format.Duration
	assert(duration > 0 and duration < math.huge, `Config.LiveEvents : planning, durée invalide ({planned.Event} {planned.Start})`)
	table.insert(Slots, { Key = `{planned.Event}@{planned.Start}`, Event = planned.Event, StartsAt = startsAt, EndsAt = startsAt + duration })
end
table.sort(Slots, function(a: Slot, b: Slot): boolean
	return a.StartsAt < b.StartsAt
end)

-- Rendez-vous de chaque semaine : premier début (semaine Unix 0, le jour 3 = dimanche 1970-01-04) et durée.
local WEEK = 7 * 86400
local weeklyRules: { { Event: string, First: number, Duration: number } } = {}
for _, rule in Weekly do
	local format = ById[rule.Event]
	assert(format ~= nil, `Config.LiveEvents : rendez-vous, format inconnu {rule.Event}`)
	local hs, mis = string.match(rule.Time, "^(%d%d):(%d%d)$")
	local hour, minute = tonumber(hs), tonumber(mis)
	assert(hour ~= nil and minute ~= nil and hour <= 23 and minute <= 59, `Config.LiveEvents : rendez-vous, heure illisible « {rule.Time} » (HH:MM, UTC)`)
	assert(rule.Weekday == math.floor(rule.Weekday) and rule.Weekday >= 0 and rule.Weekday <= 6, `Config.LiveEvents : rendez-vous, jour invalide ({rule.Event})`)
	local duration = rule.Duration or format.Duration
	assert(duration > 0 and duration < WEEK, `Config.LiveEvents : rendez-vous, durée invalide ({rule.Event})`)
	table.insert(weeklyRules, { Event = rule.Event, First = (3 + rule.Weekday) * 86400 + hour * 3600 + minute * 60, Duration = duration })
end

-- Créneaux à regarder à l'heure `t` : les datés, plus le dernier commencé et le suivant de chaque rendez-vous.
local function slotsAt(t: number): { Slot }
	local list = table.clone(Slots)
	for _, rule in weeklyRules do
		local last = rule.First + math.floor((t - rule.First) / WEEK) * WEEK
		for _, startsAt in { last, last + WEEK } do
			table.insert(list, { Key = `{rule.Event}@{startsAt}`, Event = rule.Event, StartsAt = startsAt, EndsAt = startsAt + rule.Duration })
		end
	end
	table.sort(list, function(a: Slot, b: Slot): boolean
		return a.StartsAt < b.StartsAt
	end)
	return list
end

-- Chrono de la bannière : « 29:59 », « 1:05:00 ».
local function formatTimer(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

local LiveEvents = {
	EffectIds = EffectIds,
	Formats = Formats,
	ById = ById,
	Weekly = Weekly,
	Schedule = Schedule,
	Slots = Slots,
	SlotsAt = slotsAt,
	-- Attributs du Workspace (voir l'en-tête).
	IdAttribute = "LiveEvent",
	EndsAtAttribute = "LiveEventEndsAt",
	EffectPrefix = "LiveEvent",
	-- V0 : relecture du planning toutes les TickInterval s.
	TickInterval = 1,
	-- V0 : lignes gardées dans le journal (qui, quoi, quand).
	JournalSize = 50,
	-- Écran facultatif de Clément (Contract/UI) : Title, Timer, Effect.
	BannerScreen = "UI_EventBanner",
	-- Textes du jeu (anglais), réponses au panel admin.
	Messages = {
		Started = "%s started for %s",
		Stopped = "%s stopped",
		Running = "%s is already running: stop it first.",
		NoneRunning = "No live event running.",
		Unknown = "Unknown live event.",
	},
	ParseUtc = parseUtc,
	FormatTimer = formatTimer,
}

export type LiveEvents = typeof(LiveEvents)

return DeepFreeze(LiveEvents)
