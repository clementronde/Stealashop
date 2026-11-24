-- Banc a245 (vague 72, L-216 points 3 et 6) : rendez-vous du samedi à 16 h à Paris toute l'année
-- (Config/LiveEvents : Zone = "Paris", NextWeeklyStart) et compte à rebours de la MAJ (Config/Codes.NextUpdateAt).
local cache = {}
local function load(name: string): any
	if cache[name] ~= nil then
		return cache[name]
	end
	local fn = assert(loadstring(SOURCES[name], name))
	local parent = setmetatable({}, { __index = function(_, k)
		return k
	end })
	setfenv(fn, setmetatable({ script = { Parent = parent }, require = load }, { __index = _G }))
	cache[name] = fn()
	return cache[name]
end
local total, failed = 0, 0
local function check(ok: boolean, what: string)
	total += 1
	if not ok then
		failed += 1
		print("ÉCHEC : " .. what)
	end
end
local LiveEvents = load("LiveEvents")
local Codes = load("Codes")
local P = LiveEvents.ParseUtc
local WEEK = 7 * 86400

-- Décalage de Paris.
check(LiveEvents.ParisOffset(P("2026-12-19 15:00")) == 3600, "hiver : UTC + 1")
check(LiveEvents.ParisOffset(P("2027-07-03 14:00")) == 7200, "été : UTC + 2")
check(LiveEvents.ParisOffset(P("2027-03-28 00:59")) == 3600, "veille du passage à l'été")
check(LiveEvents.ParisOffset(P("2027-03-28 01:00")) == 7200, "passage à l'été, 01:00 UTC")
check(LiveEvents.ParisOffset(P("2027-10-31 00:59")) == 7200, "veille du retour à l'hiver")
check(LiveEvents.ParisOffset(P("2027-10-31 01:00")) == 3600, "retour à l'hiver, 01:00 UTC")
check(LiveEvents.ParisOffset(P("2026-12-31 23:59")) == 3600 and LiveEvents.ParisOffset(P("2027-01-01 00:00")) == 3600, "autour du 1er janvier")

-- Rendez-vous : samedi 16:00 à Paris.
local w = LiveEvents.Weekly[1]
check(#LiveEvents.Weekly == 1 and w.Event == "AdminAbuse" and w.Weekday == 6 and w.Time == "16:00" and w.Zone == "Paris" and w.Duration == 1800, "rendez-vous : AdminAbuse samedi 16:00 Paris 30 min")

local function openAt(t: number): any
	for _, slot in LiveEvents.SlotsAt(t) do
		if slot.StartsAt <= t and t < slot.EndsAt then
			return slot
		end
	end
	return nil
end
local SATURDAYS = { -- début attendu en UTC
	{ "2026-12-19 15:00", "hiver" },
	{ "2027-03-27 15:00", "veille du passage à l'été" },
	{ "2027-04-03 14:00", "premier samedi d'été" },
	{ "2027-07-03 14:00", "été" },
	{ "2027-10-30 14:00", "dernier samedi d'été" },
	{ "2027-11-06 15:00", "retour à l'hiver" },
}
for _, row in SATURDAYS do
	local start = P(row[1])
	local slot = openAt(start + 60)
	check(slot ~= nil and slot.StartsAt == start and slot.EndsAt == start + 1800 and slot.Event == "AdminAbuse", `créneau ouvert, {row[2]} ({row[1]} UTC)`)
	check(openAt(start - 1) == nil, `rien une seconde avant, {row[2]}`)
	check(openAt(start + 1800) == nil, `rien à la fin, {row[2]}`)
	check(LiveEvents.NextWeeklyStart(start - 60) == start, `prochain une minute avant, {row[2]}`)
	check(LiveEvents.NextWeeklyStart(start - 5 * 86400) == start, `prochain le lundi d'avant, {row[2]}`)
	check(Codes.NextUpdateAt(start - 3600) == start, `MAJ une heure avant, {row[2]}`)
	check(Codes.FormatCountdown(Codes.NextUpdateAt(start - 3600) - (start - 3600)) == "1h 00m", `compte à rebours 1h 00m, {row[2]}`)
end
-- Strictement après, et le passage d'heure entre deux samedis.
local SAT = P("2026-12-19 15:00")
check(LiveEvents.NextWeeklyStart(SAT) == SAT + WEEK, "à l'heure : samedi suivant")
check(Codes.NextUpdateAt(SAT + 1) == SAT + WEEK, "MAJ une seconde après : samedi suivant")
check(Codes.NextUpdateAt(P("2027-03-27 15:00")) == P("2027-04-03 14:00"), "de l'hiver à l'été : 6 j 23 h")
check(Codes.NextUpdateAt(P("2027-10-30 14:00")) == P("2027-11-06 15:00"), "de l'été à l'hiver : 7 j 1 h")
check(Codes.FormatCountdown(Codes.NextUpdateAt(SAT + 1) - (SAT + 1)) ~= nil, "jamais caché après l'heure")
-- Clés uniques par créneau (EventService ne lance qu'une fois par clé).
local seen, dup = {}, false
for _, slot in LiveEvents.SlotsAt(P("2027-07-03 14:10")) do
	if seen[slot.Key] then
		dup = true
	end
	seen[slot.Key] = true
end
check(not dup, "clés de créneaux uniques")
print(`banc a245 (rendez-vous et MAJ) : {total} vérification(s), {failed} échec(s)`)
