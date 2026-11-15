--!strict
-- EventService (vague 51, a167 ; MAJ 0, docs/claude/notes/feuille-de-route-maj.md section 3) : les événements live
-- du samedi. Formats, planning et textes : Config/LiveEvents.
--
-- Planning : toutes les LiveEvents.TickInterval s, l'heure du serveur (Workspace:GetServerTimeNow, secondes Unix,
-- la même sur tous les serveurs) est comparée aux créneaux (LiveEvents.Slots). Sans événement en cours, le premier
-- créneau ouvert (début ≤ maintenant < fin) pas encore lancé sur ce serveur part, jusqu'à la fin de son créneau :
-- tous les serveurs le lancent à la même seconde, sans admin ; un serveur qui démarre au milieu le rejoint avec le
-- temps qui reste. Un seul événement à la fois : un créneau ouvert pendant un autre événement attend sa fin, puis
-- part pour ce qui reste de son créneau (rien s'il est passé). Un créneau lancé ou arrêté par un admin ne repart
-- pas sur ce serveur.
--
-- Panel admin (AdminService, StartEvent, permis hors Studio pour un événement de LiveEvents) :
--   EventService.Launch(eventId, who) -> (ok, message) lance un format sur ce serveur seulement, tout de suite,
--                                                     pour sa durée par défaut ; refusé si un événement tourne
--   EventService.Stop(who) -> (ok, message)            arrête l'événement en cours (planifié ou non)
-- Journal (qui, quoi, quand) : chaque début et fin, dans la sortie (heure UTC) et dans GetJournal (les
-- LiveEvents.JournalSize dernières lignes).
--
-- Effets (facteurs de Config/LiveEvents ; 1 hors événement) :
--   - Income et TrainingGain : accroches enveloppées ici dans Init (DisplayService.GetIncomeMultiplier,
--     MonetizationService.GetTemporaryIncomeMultiplier pour l'exclure des gains hors ligne, comme les boosts,
--     TrainingService.GetGainMultiplier) : aucune ligne dans ces services ;
--   - ShelfLuck, TruckDelay, PotionDelay, WindowHealth : attributs du Workspace LiveEvent<effet> (absent = 1), lus
--     en une ligne par StoreHeistService, TruckEventService, PotionService et WindowService.
-- État répliqué au client (bannière UI_EventBanner, EventBannerController) : attributs LiveEvent (Id) et
-- LiveEventEndsAt (heure du serveur) du Workspace.
--
-- Télémétrie : LiveEventStart et LiveEventEnd (Config/Telemetry) pour chaque joueur présent, champs « Event - <Id> »
-- et « Source - Schedule|Admin », valeur = nombre de joueurs présents.
--
-- Pas en V0 : MessagingService. Pour qu'un admin lance un événement sur tous les serveurs : SubscribeAsync sur un
-- sujet « LiveEvent » au démarrage, PublishAsync({ Id, StartsAt, EndsAt }) depuis le panel (commande à part,
-- admins seulement), et chaque serveur reçu l'ajoute comme un créneau (même règle « un seul à la fois »).
--
-- API (serveur) :
--   EventService.Factor(effect) -> number          facteur de l'effet en cours (1 sans événement)
--   EventService.GetCurrent() -> Current?          { Id, Source, StartedAt, EndsAt }
--   EventService.GetJournal() -> { JournalEntry }  copie

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local LiveEvents = require(Shared.Config.LiveEvents)

local DisplayService = require(script.Parent.DisplayService)
local MonetizationService = require(script.Parent.MonetizationService)
local TelemetryService = require(script.Parent.TelemetryService)
local TrainingService = require(script.Parent.TrainingService)

export type Source = "Schedule" | "Admin"

export type Current = {
	Id: string,
	Source: Source,
	StartedAt: number,
	EndsAt: number,
}

export type JournalEntry = {
	At: number, -- heure du serveur (secondes Unix)
	Who: string,
	What: string,
}

type Running = {
	Format: LiveEvents.Format,
	Source: Source,
	StartedAt: number,
	EndsAt: number,
}

local SCHEDULE_WHO = "Schedule"

local EventService = {}

local current: Running? = nil
local launched: { [string]: boolean } = {} -- créneaux déjà lancés sur ce serveur (Slot.Key)
local journal: { JournalEntry } = {}
local loopStarted = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function note(who: string, what: string)
	local at = now()
	table.insert(journal, { At = at, Who = who, What = what })
	while #journal > LiveEvents.JournalSize do
		table.remove(journal, 1)
	end
	print(`[EventService] {os.date("!%Y-%m-%d %H:%M:%S", math.floor(at))} UTC : {who} : {what}`)
end

-- Attributs du Workspace (voir l'en-tête de Config/LiveEvents) : Id, fin, un attribut par effet ≠ 1.
local function publish()
	local running = current
	Workspace:SetAttribute(LiveEvents.IdAttribute, if running then running.Format.Id else nil)
	Workspace:SetAttribute(LiveEvents.EndsAtAttribute, if running then running.EndsAt else nil)
	for _, effect in LiveEvents.EffectIds do
		local factor = if running then running.Format.Effects[effect] else nil
		Workspace:SetAttribute(LiveEvents.EffectPrefix .. effect, if factor ~= nil and factor ~= 1 then factor else nil)
	end
end

local function telemetry(key: string, running: Running)
	local players = Players:GetPlayers()
	for _, player in players do
		local ok, err = pcall(TelemetryService.LogEvent :: any, player, key, { `Event - {running.Format.Id}`, `Source - {running.Source}` }, #players)
		if not ok then
			warn(`[EventService] télémétrie {key} : {err}`)
		end
	end
end

local function begin(format: LiveEvents.Format, source: Source, endsAt: number, who: string)
	local running: Running = { Format = format, Source = source, StartedAt = now(), EndsAt = endsAt }
	current = running
	publish()
	note(who, `début de {format.Id} ({source}), fin dans {math.round(endsAt - running.StartedAt)} s`)
	telemetry("LiveEventStart", running)
end

local function finish(who: string, why: string)
	local running = current
	if running == nil then
		return
	end
	current = nil
	publish()
	note(who, `fin de {running.Format.Id} ({why})`)
	telemetry("LiveEventEnd", running)
end

-- Un tour du planning (voir l'en-tête).
local function step()
	local t = now()
	local running = current
	if running and t >= running.EndsAt then
		finish(SCHEDULE_WHO, "temps écoulé")
	end
	if current ~= nil then
		return
	end
	for _, slot in LiveEvents.Slots do
		if not launched[slot.Key] and slot.StartsAt <= t and t < slot.EndsAt then
			launched[slot.Key] = true
			local format = LiveEvents.ById[slot.Event]
			if format then
				begin(format, "Schedule", slot.EndsAt, SCHEDULE_WHO)
			end
			return
		end
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function EventService.Factor(effect: string): number
	local running = current
	local factor = if running then running.Format.Effects[effect] else nil
	return factor or 1
end

function EventService.GetCurrent(): Current?
	local running = current
	if running == nil then
		return nil
	end
	return { Id = running.Format.Id, Source = running.Source, StartedAt = running.StartedAt, EndsAt = running.EndsAt }
end

function EventService.GetJournal(): { JournalEntry }
	return table.clone(journal)
end

function EventService.Launch(eventId: string, who: string): (boolean, string)
	local format = LiveEvents.ById[eventId]
	if format == nil then
		return false, LiveEvents.Messages.Unknown
	end
	step() -- un événement fini mais pas encore relevé ne bloque pas
	local running = current
	if running then
		return false, string.format(LiveEvents.Messages.Running, running.Format.DisplayName)
	end
	-- Un créneau ouvert maintenant cède la place à l'admin et ne repartira pas sur ce serveur.
	local t = now()
	for _, slot in LiveEvents.Slots do
		if slot.StartsAt <= t and t < slot.EndsAt then
			launched[slot.Key] = true
		end
	end
	begin(format, "Admin", t + format.Duration, who)
	return true, string.format(LiveEvents.Messages.Started, format.DisplayName, LiveEvents.FormatTimer(format.Duration))
end

function EventService.Stop(who: string): (boolean, string)
	local running = current
	if running == nil then
		return false, LiveEvents.Messages.NoneRunning
	end
	finish(who, "arrêté")
	return true, string.format(LiveEvents.Messages.Stopped, running.Format.DisplayName)
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

function EventService.Init()
	local baseIncome = DisplayService.GetIncomeMultiplier
	DisplayService.GetIncomeMultiplier = function(player: Player): number
		return baseIncome(player) * EventService.Factor("Income")
	end
	-- Gains hors ligne : OfflineService divise le revenu par GetTemporaryIncomeMultiplier (boosts exclus).
	local baseTemporary = MonetizationService.GetTemporaryIncomeMultiplier
	MonetizationService.GetTemporaryIncomeMultiplier = function(player: Player): number
		return baseTemporary(player) * EventService.Factor("Income")
	end
	local baseGain = TrainingService.GetGainMultiplier
	TrainingService.GetGainMultiplier = function(player: Player, kind: any): number
		return baseGain(player, kind) * EventService.Factor("TrainingGain")
	end
	publish()
end

function EventService.Start()
	if loopStarted then
		return
	end
	loopStarted = true
	local nextSlot = LiveEvents.Slots[1]
	print(`[EventService] {#LiveEvents.Formats} formats, {#LiveEvents.Slots} créneau(x) planifié(s){if nextSlot then `, premier : {nextSlot.Event} le {os.date("!%Y-%m-%d %H:%M", nextSlot.StartsAt)} UTC` else ""}`)
	while true do
		local ok, err = pcall(step :: any) -- :: any : l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			warn(`[EventService] planning : {err}`)
		end
		task.wait(LiveEvents.TickInterval)
	end
end

return EventService
