--!strict
-- MusicController (DEV-051, client) : la musique de fond du joueur, en fondu enchaîné avec les musiques
-- d'événement (liaison L-056, demande de Clément du 2026-11-07 ; valeurs : Config/Music).
--
-- Fond (demande de Cantin du 2026-11-11 : plus de musique par zone) : partout, zone safe, couloir,
-- toutes les zones, de jour comme de nuit, la playlist Music.AmbientTracks (6 morceaux, Morning Mood
-- en premier) : chaque morceau joue une fois (copie sans boucle) ; à sa fin (signal Ended), le suivant
-- monte en fondu (FadeTime), et après le dernier on repart du premier. Elle ne redémarre pas d'une
-- zone à l'autre (la position du joueur ne compte pas pour le fond). Un morceau absent de Studio est
-- sauté (une ligne en Studio, une fois) ; aucun morceau : Music.FallbackTrack (MUS_Hub) en boucle
-- partout (une ligne) ; sans lui non plus : silence (hors événements). MUS_Z1 à MUS_Z6 ne sont plus
-- jouées.
--
-- Pistes : les Sound de Clément dans ReplicatedStorage/Assets/Music (sous-dossiers compris). Ils ne
-- sont jamais modifiés : chaque piste jouée est une copie, faite la première fois qu'elle sert, rangée
-- dans SoundService (son 2D, chez ce joueur seulement), en boucle (Looped forcé sur la copie), sauf
-- les morceaux de la playlist (Looped = false forcé).
-- Volume plein d'une piste = le Volume du Sound de Clément × le réglage du joueur (attribut
-- Music.VolumeAttribute du Player local, de 0 à 1, absent : 1 ; posé par UI_Settings), suivi en direct.
--
-- Fondu : une seule piste visée à la fois. Elle monte vers son volume plein pendant que toutes les
-- autres descendent, à la même vitesse (de 0 au plein en FadeTime s) : deux pistes ne sont jamais à
-- fond ensemble, et leurs parts additionnées ne dépassent jamais une piste pleine. Une piste
-- descendue à 0 est mise en pause (Playing = false) : le morceau de fond reprend où il en était après
-- un événement.
--
-- Musiques d'événement (liaison L-071, points 6 et 7 ; Config/Music), avant le fond, dans cet ordre :
--   1. poursuite : Music.ChaseTrack (MUS_Chase) tant qu'un vigile poursuit le joueur local
--      (ChaseController.IsChased, d'après le remote ChaseState de GuardService) ;
--   2. braquage (vague 26, ordre de Clément) : Music.HeistTrack (MUS_Heist) tant qu'un chrono de
--      braquage est affiché chez le joueur (HeistController.GetTimers, remote HeistTimer, après la casse
--      d'une vitrine), avec la respiration Music.HeistBreath (Heist_Breath, Assets/Sounds) en boucle,
--      dont le volume suit le fondu de MUS_Heist (son d'effet : groupe SFX, réglage SfxVolume) ;
--   3. camion : Music.TruckTrack (MUS_Truck) tant que le joueur est à moins de TruckRadius studs d'un
--      camion de l'événement (tag EventTruck, posé par TruckEventService) ou, après l'explosion, d'un de
--      ses colis au sol (Workspace/CarryDrops, attribut TruckBox). Une fois dedans, il en sort au-delà
--      de TruckRadius + TruckExitMargin. Camion et colis hors du streaming : pas comptés ;
--   4. sinon le fond (plus haut).
-- Une musique d'événement absente (ou qui n'est pas un Sound) ne change rien : la suivante, ou le
-- fond, continue (une ligne en Studio, une fois). Redescendue au silence, elle repart du début au
-- prochain événement (RestartEventTracks ; MUS_Chase part de Config/ChaseFeel.MusicStartAt, L-095, la
-- première fois comme les suivantes) ; reprise pendant son fondu de sortie, elle continue sans saut.
-- Vague 24 : MUS_Chase n'est visée que Config/ChaseFeel.MusicDelay s après le départ de la poursuite
-- (sons du départ espacés), sauf pendant ce fondu de sortie (elle reprend tout de suite).
--
-- a477 (L-377, L-385, Clément 25/11 ; Config/Music.Steal, Features.StealMusic / StealMusicDev) : musique du vol.
-- Allumée, l'ordre devient :
--   0a. vol : Steal.StealTrack (MUS_Steal) tant que le joueur local porte un objet volé (attribut Carrying de
--       CarryService : rayon PNJ comme présentoir d'un joueur), avec ou sans vigile. À la prise (Carrying posé), revue
--       tout de suite ; MUS_Steal repart du début, monte en TensionFadeIn s, et la piste qui jouait est coupée net
--       (CutOthersOnSteal). Arrivée (fin du portage et remote ItemSecured à 1 s au plus l'un de l'autre) : MUS_Steal
--       descend en SafeOutTime s et le fond ne revient que SafeReturnDelay s après ; sinon (objet lâché) : fondu normal. Capture : CutChase coupe
--       aussi MUS_Steal, qui ne repart pas avant la fin du portage ;
--   0b. victime : Steal.VictimTrack (MUS_Victim) tant qu'un voleur porte un objet du joueur local
--       (TheftAlertController.IsRobbed), montée en TensionFadeIn s ;
--   1. poursuite (MUS_Chase, montée en TensionFadeIn s, délai MusicDelay inchangé) ;
--   2. braquage : chrono PNJ comme avant, et aussi dès le 1er coup du joueur local sur la porte d'une boutique de joueur
--      (remote WindowHit, Id « Plot_<PlotIndex> »), tant que ce coup date de PlotHeistHold s au plus ou que la boutique
--      reste ouverte au vol (StealOpen) à PlotHeistRadius studs au plus ;
--   3. camion ; 4. fond.
-- Coupée : rien de tout cela, la musique fait exactement comme avant.
--
-- Rien n'est envoyé au serveur. API (client) :
--   MusicController.GetState() -> { Track, Levels, Event }
--       Piste visée (nil : silence), part du volume plein de chaque copie (0 à 1) et événement dont la
--       musique joue ("Steal", "Victim", "Chase", "Heist", "Truck", nil : le fond), pour un test dans Studio (barre de
--       commande côté client).
--   MusicController.CutChase()   vague 59 : coupe MUS_Chase d'un coup (capture, CatchSceneController) ; a477 : MUS_Steal aussi

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Music = require(Shared:WaitForChild("Config"):WaitForChild("Music"))
-- Départ de MUS_Chase (L-095, Clément : « à partir de 1,5 s ») : Config/ChaseFeel.MusicStartAt, 0 sans lui.
local chaseFeelModule = Shared:WaitForChild("Config"):FindFirstChild("ChaseFeel")
local CHASE_START_AT: number = if chaseFeelModule and chaseFeelModule:IsA("ModuleScript")
	then (require(chaseFeelModule) :: any).MusicStartAt or 0
	else 0
-- Vague 24 (sons du départ espacés) : MUS_Chase ne monte que Config/ChaseFeel.MusicDelay s après le
-- départ de la poursuite (0 sans lui), sauf si elle est encore audible (fondu de sortie).
local CHASE_DELAY: number = if chaseFeelModule and chaseFeelModule:IsA("ModuleScript")
	then (require(chaseFeelModule) :: any).MusicDelay or 0
	else 0

-- a477 (L-385) : musique du vol, Config/Music.Steal (absent d'un ancien Config : coupée).
local STEAL: any = (Music :: any).Steal
local STEAL_ON: boolean = type(STEAL) == "table" and STEAL.Enabled == true
local STEAL_TRACK: string? = if STEAL_ON then STEAL.StealTrack else nil
local FAST_IN: { [string]: boolean } = {}
if STEAL_ON then
	for _, name in STEAL.TensionTracks do
		FAST_IN[name] = true
	end
end
-- Arrivée (L-385 point 5) : remote ItemSecured (objet mis à l'abri, magasin PNJ comme boutique de joueur) reçu à
-- SECURED_WINDOW s au plus de la fin du portage, dans un sens ou dans l'autre. Les boutiques sont dans la zone safe :
-- la position seule ne distingue pas l'arrivée d'un objet lâché chez la victime.
local SECURED_WINDOW = 1

type Track = {
	Copy: Sound,
	FullVolume: number, -- Volume du Sound de Clément
	Level: number, -- part du volume plein, de 0 à 1
	Written: number, -- dernier Volume écrit sur la copie
}

export type EventKind = string -- "Chase", "Heist" ou "Truck"

export type State = {
	Track: string?,
	Levels: { [string]: number },
	Event: EventKind?,
}

-- Ce que ce contrôleur utilise de ChaseController.
type ChaseApi = {
	IsChased: () -> boolean,
}

-- Ce que ce contrôleur utilise de HeistController (chronos affichés : storeId → endsAt, heure serveur).
type HeistApi = {
	GetTimers: () -> { [string]: number },
}

-- a477 : ce que ce contrôleur utilise de TheftAlertController.
type TheftApi = {
	IsRobbed: () -> boolean,
}

local ROOT_PART = "HumanoidRootPart"
-- a477 : posés par le serveur (mêmes noms dans CarryService, PvPService, WindowService, PlotService).
local CARRYING_ATTRIBUTE = "Carrying"
local PLOT_TAG = "PlayerPlot"
local PLOT_INDEX_ATTRIBUTE = "PlotIndex"
local STEAL_OPEN_ATTRIBUTE = "StealOpen"
local PLOT_WINDOW_PATTERN = "^Plot_(%d+)"
-- Posés par le serveur (mêmes noms dans TruckEventService et CarryService).
local TRUCK_TAG = "EventTruck"
local DROPS_FOLDER = "CarryDrops"
local TRUCK_BOX_ATTRIBUTE = "TruckBox"

local IS_STUDIO = RunService:IsStudio()
local FOLDER_PATH = `ReplicatedStorage.{table.concat(Music.Folder, ".")}`

local localPlayer = Players.LocalPlayer

local MusicController = {}

local tracks: { [string]: Track } = {} -- copies faites, par nom de piste
local target: string? = nil -- piste visée ; nil = silence
local volumeScale = 1
local sinceCheck = math.huge -- première vérification à la première image
local said: { [string]: boolean } = {}
local chase: ChaseApi? = nil
local heist: HeistApi? = nil
local breath: Sound? = nil -- copie en boucle de Heist_Breath, avec MUS_Heist
local breathFull = 0 -- Volume du Sound de Clément
local event: EventKind? = nil -- événement dont la musique joue
local nearTruck = false -- dans le cercle du camion (avec la marge de sortie)
local chasedFor = 0 -- secondes depuis le départ de la poursuite (0 hors poursuite)
local ambientIndex = 1 -- morceau de la playlist en cours (Music.AmbientTracks)
-- a477 (L-385) :
local theft: TheftApi? = nil
local stealBlocked = false -- capture : MUS_Steal ne repart pas avant la fin du portage
local stealOutFast = false -- arrivée en zone safe : MUS_Steal descend en SafeOutTime s
local holdUntil = -math.huge -- arrivée en zone safe : silence de fond jusqu'à cette heure (os.clock)
local plotHitIndex: number? = nil -- boutique de joueur frappée en dernier par le joueur local (PlotIndex)
local plotHitAt = -math.huge -- heure (os.clock) de ce coup
local carryEndedAt = -1e9 -- heure (os.clock) de la dernière fin de portage
local securedAt = -2e9 -- heure (os.clock) du dernier ItemSecured (jamais : loin de carryEndedAt)

local function sayOnce(key: string, message: string, isProblem: boolean?)
	if not IS_STUDIO or said[key] then
		return
	end
	said[key] = true
	if isProblem then
		warn(`[MusicController] {message}`)
	else
		print(`[MusicController] {message}`)
	end
end

-- Pistes ----------------------------------------------------------------------------------------------

-- `effect` : ce que le manque de la piste change, pour la ligne de Studio (nil : pas de ligne).
local function findTemplate(name: string, effect: string?): Sound?
	local current: Instance? = ReplicatedStorage
	for _, segment in Music.Folder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	if current == nil then
		sayOnce("folder", `{FOLDER_PATH} absent : pas de musique (L-056)`)
		return nil
	end
	local found = current:FindFirstChild(name, true)
	if found and found:IsA("Sound") then
		return found :: Sound
	end
	if effect then
		sayOnce(`track:{name}`, `{name} absent de {FOLDER_PATH} (ou pas un Sound) : {effect}`)
	end
	return nil
end

local SKIP_EFFECT = "morceau sauté dans la playlist de fond (demande du 2026-11-11)"

-- Fin d'un morceau de la playlist (signal Ended) : il est remis au début et à 0, et si c'était le
-- morceau en cours, on passe au suivant (après le dernier : le premier), revu à l'image suivante.
local function onAmbientEnded(name: string)
	local track = tracks[name]
	if track then
		track.Level = 0
		track.Copy.TimePosition = 0
	end
	local list = Music.AmbientTracks
	if list[ambientIndex] == name then
		ambientIndex = ambientIndex % #list + 1
	end
	sinceCheck = math.huge
end

-- La copie de la piste `name`, faite au besoin ; false si la piste manque. `ambient` : morceau de la
-- playlist (sans boucle, suivi de sa fin) ; sinon la copie joue en boucle.
local function ensureTrack(name: string, effect: string?, ambient: boolean?): boolean
	if tracks[name] then
		return true
	end
	local template = findTemplate(name, effect)
	if template == nil then
		return false
	end
	local copy = template:Clone() :: Sound?
	if copy == nil then
		sayOnce(`archivable:{name}`, `{name} ne se copie pas (Archivable = false) : {effect or SKIP_EFFECT}`, true)
		return false
	end
	copy.Looped = not ambient
	copy.Playing = false
	copy.Volume = 0
	copy.Parent = SoundService
	if ambient then
		copy.Ended:Connect(function()
			onAmbientEnded(name)
		end)
	end
	tracks[name] = { Copy = copy, FullVolume = template.Volume, Level = 0, Written = 0 }
	return true
end

local FALLBACK_EFFECT = "pas de musique de fond"

-- Piste de fond : le morceau en cours de la playlist, ou le suivant présent (les absents sautés, une
-- ligne en Studio chacun) ; aucun : MUS_Hub ; sinon nil (silence).
local function backgroundTrack(): string?
	local list = Music.AmbientTracks
	local skipped: { string } = {}
	for offset = 0, #list - 1 do
		local index = (ambientIndex - 1 + offset) % #list + 1
		local name = list[index]
		if ensureTrack(name, nil, true) then
			ambientIndex = index
			for _, missing in skipped do
				sayOnce(`track:{missing}`, `{missing} absent de {FOLDER_PATH} (ou pas un Sound) : {SKIP_EFFECT}`)
			end
			return name
		end
		table.insert(skipped, name)
	end
	sayOnce("playlist", `aucun morceau de la playlist de fond dans {FOLDER_PATH} : repli sur {Music.FallbackTrack} partout (demande du 2026-11-11)`)
	if ensureTrack(Music.FallbackTrack, FALLBACK_EFFECT) then
		return Music.FallbackTrack
	end
	return nil
end

local function localPosition(): Vector3?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild(ROOT_PART) else nil
	return if root and root:IsA("BasePart") then (root :: BasePart).Position else nil
end

-- Événements (L-071) ----------------------------------------------------------------------------------

local CHASE: EventKind = "Chase"
local TRUCK: EventKind = "Truck"
local CHASE_EFFECT = "la musique de fond continue pendant les poursuites (L-071)"
local TRUCK_EFFECT = "la musique de fond continue près du camion (L-071)"
local HEIST: EventKind = "Heist"
local HEIST_EFFECT = "pas de musique de tension pendant le braquage (L-097)"
local STEAL_KIND: EventKind = "Steal"
local VICTIM_KIND: EventKind = "Victim"
local STEAL_EFFECT = "pas de musique pendant le vol (L-385)"
local VICTIM_EFFECT = "pas de musique chez le joueur volé (L-385)"

local function within(instance: Instance, position: Vector3, radius: number): boolean
	return instance:IsA("PVInstance") and ((instance :: PVInstance):GetPivot().Position - position).Magnitude <= radius
end

-- Un chrono de braquage est-il affiché chez le joueur (et pas encore fini) ?
local function heistRunning(): boolean
	local api = heist
	if api == nil then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	for _, endsAt in api.GetTimers() do
		if endsAt > now then
			return true
		end
	end
	return false
end

-- a477 : dans la map jouée (Workspace, aucun ancêtre en « _ » : dossiers de travail), comme Contract/Find.inMap.
local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local node: Instance? = instance
	while node ~= nil and node ~= Workspace do
		if string.sub(node.Name, 1, 1) == "_" then
			return false
		end
		node = node.Parent
	end
	return true
end

-- a477 (L-385 point 1) : la boutique de joueur d'index `index`, dans la map jouée.
local function plotByIndex(index: number): Instance?
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:GetAttribute(PLOT_INDEX_ATTRIBUTE) == index and inMap(plot) then
			return plot
		end
	end
	return nil
end

-- a477 (L-385 point 1) : braquage d'une boutique de joueur en cours chez le joueur local (après son 1er coup sur la porte).
local function plotHeistRunning(position: Vector3?): boolean
	local index = plotHitIndex
	if index == nil then
		return false
	end
	if os.clock() - plotHitAt <= STEAL.PlotHeistHold then
		return true
	end
	local plot = plotByIndex(index)
	if plot and plot:GetAttribute(STEAL_OPEN_ATTRIBUTE) == true and position and within(plot, position, STEAL.PlotHeistRadius) then
		return true
	end
	plotHitIndex = nil -- fini : il faudra un nouveau coup
	return false
end

-- a477 (L-385 points 2 et 3) : le joueur local porte-t-il un objet volé ?
local function carrying(): boolean
	return localPlayer:GetAttribute(CARRYING_ATTRIBUTE) ~= nil
end

-- Le Sound Heist_Breath de Clément (Assets/Sounds, sous-dossiers compris, comme MarkerSounds), ou nil.
local function findBreath(): Sound?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local sounds = if assets then assets:FindFirstChild("Sounds") else nil
	local found = if sounds then sounds:FindFirstChild(Music.HeistBreath, true) else nil
	return if found and found:IsA("Sound") then found :: Sound else nil
end

-- Respiration avec la tension : copie en boucle (SoundService ; nom sans MUS_, donc rangée dans le
-- groupe SFX par SettingsController), volume = son Volume × la part de MUS_Heist. Absente : rien.
local function updateBreath(heistLevel: number)
	if heistLevel <= 0 then
		local copy = breath
		if copy and copy.Playing then
			copy.Playing = false
		end
		return
	end
	local copy = breath
	if copy == nil then
		local template = findBreath()
		if template == nil then
			sayOnce("breath", `{Music.HeistBreath} absent de ReplicatedStorage.Assets.Sounds : pas de respiration pendant le braquage (L-097)`)
			return
		end
		local made = template:Clone()
		made.Looped = true
		made.Volume = 0
		made.Parent = SoundService
		breathFull = template.Volume
		breath = made
		copy = made
	end
	local sound = copy :: Sound
	sound.Volume = breathFull * heistLevel
	if not sound.Playing then
		sound.TimePosition = 0
		sound.Playing = true
	end
end


-- Le joueur, en `position`, est-il près du camion de l'événement ou d'un de ses colis au sol ? Une fois
-- dedans, le cercle grandit de TruckExitMargin.
local function truckNear(position: Vector3): boolean
	local radius = Music.TruckRadius + (if nearTruck then Music.TruckExitMargin else 0)
	for _, truck in CollectionService:GetTagged(TRUCK_TAG) do
		if truck:IsDescendantOf(Workspace) and within(truck, position, radius) then
			return true
		end
	end
	local drops = Workspace:FindFirstChild(DROPS_FOLDER)
	if drops then
		for _, drop in drops:GetChildren() do
			if drop:GetAttribute(TRUCK_BOX_ATTRIBUTE) == true and within(drop, position, radius) then
				return true
			end
		end
	end
	return false
end

-- Musique d'événement à jouer, dans l'ordre de priorité, et son événement ; nil : le fond.
local function eventTrack(position: Vector3?): (string?, EventKind?)
	if STEAL_ON then
		-- a477 (L-385) : MUS_Steal, puis MUS_Victim, avant tout le reste.
		if carrying() and not stealBlocked and ensureTrack(STEAL.StealTrack, STEAL_EFFECT) then
			return STEAL.StealTrack, STEAL_KIND
		end
		local robbed = theft
		if robbed and robbed.IsRobbed() and ensureTrack(STEAL.VictimTrack, VICTIM_EFFECT) then
			return STEAL.VictimTrack, VICTIM_KIND
		end
	end
	local api = chase
	local chaseTrack = tracks[Music.ChaseTrack]
	local audible = chaseTrack ~= nil and chaseTrack.Level > 0
	if api and api.IsChased() and (chasedFor >= CHASE_DELAY or audible) and ensureTrack(Music.ChaseTrack, CHASE_EFFECT) then
		return Music.ChaseTrack, CHASE
	end
	if (heistRunning() or (STEAL_ON and plotHeistRunning(position))) and ensureTrack(Music.HeistTrack, HEIST_EFFECT) then
		return Music.HeistTrack, HEIST
	end
	if position then
		nearTruck = truckNear(position)
	end
	if nearTruck and ensureTrack(Music.TruckTrack, TRUCK_EFFECT) then
		return Music.TruckTrack, TRUCK
	end
	return nil, nil
end

-- Boucle ----------------------------------------------------------------------------------------------

local function check()
	local name, kind = eventTrack(localPosition())
	if kind == nil then
		-- a477 (L-385 point 5) : arrivée en zone safe, le fond attend SafeReturnDelay s.
		name = if os.clock() < holdUntil then nil else backgroundTrack()
	end
	if kind == STEAL_KIND then
		stealOutFast = false -- reprise d'un objet : MUS_Steal remonte normalement
	end
	-- a477 (L-385 point 2) : à la prise, ce qui jouait est coupé net (en pause : le fond reprendra où il en était).
	if kind == STEAL_KIND and name ~= target and STEAL.CutOthersOnSteal then
		for other, track in tracks do
			if other ~= name and track.Level > 0 then
				track.Level = 0
				track.Written = 0
				track.Copy.Volume = 0
				track.Copy.Playing = false
			end
		end
	end
	-- Musique d'événement qui revient du silence : elle repart du début (MUS_Chase : de CHASE_START_AT).
	if name and name ~= target and kind ~= nil and Music.RestartEventTracks then
		local track = tracks[name]
		if track and track.Level <= 0 then
			track.Copy.TimePosition = if kind == CHASE then CHASE_START_AT else 0
		end
	end
	event = kind
	target = name
end

-- Vitesse d'un fondu de `time` s (0 : tout de suite).
local function rateOf(dt: number, time: number): number
	return if time > 0 then dt / time else math.huge
end

local function fade(dt: number)
	local rate = rateOf(dt, Music.FadeTime)
	for name, track in tracks do
		local goal = if name == target then 1 else 0
		local level = track.Level
		if level < goal then
			-- a477 (L-385) : les pistes de tension montent en TensionFadeIn s.
			local up = if FAST_IN[name] then rateOf(dt, STEAL.TensionFadeIn) else rate
			level = math.min(level + up, goal)
		elseif level > goal then
			-- a477 (L-385 point 5) : MUS_Steal à l'arrivée en zone safe descend en SafeOutTime s.
			local down = if stealOutFast and name == STEAL_TRACK then rateOf(dt, STEAL.SafeOutTime) else rate
			level = math.max(level - down, goal)
			if level <= 0 and name == STEAL_TRACK then
				stealOutFast = false
			end
		end
		track.Level = level
		local copy = track.Copy
		local volume = track.FullVolume * level * volumeScale
		if volume ~= track.Written then
			copy.Volume = volume
			track.Written = volume
		end
		local playing = level > 0 or goal > 0
		if copy.Playing ~= playing then
			copy.Playing = playing -- false : en pause, la piste reprendra où elle en était
		end
	end
	local heistTrack = tracks[Music.HeistTrack]
	updateBreath(if heistTrack then heistTrack.Level else 0)
end

local function step(dt: number)
	local api = chase
	chasedFor = if api and api.IsChased() then chasedFor + dt else 0
	sinceCheck += dt
	if sinceCheck >= Music.CheckInterval then
		sinceCheck = 0
		check()
	end
	fade(dt)
end

local function readVolumeScale()
	local value = localPlayer:GetAttribute(Music.VolumeAttribute)
	volumeScale = if type(value) == "number" and value == value then math.clamp(value, 0, 1) else 1
end

-- API -------------------------------------------------------------------------------------------------

function MusicController.GetState(): State
	local levels: { [string]: number } = {}
	for name, track in tracks do
		levels[name] = track.Level
	end
	return { Track = target, Levels = levels, Event = event }
end

-- Vague 59 (a192, L-184 point 1) : à la capture, la musique de poursuite est coupée d'un coup (sans fondu de
-- sortie) ; le fond remonte ensuite comme d'habitude. Pas encore jouée : rien.
-- a477 (L-385 point 6) : MUS_Steal aussi, qui ne repart pas avant la fin du portage (l'objet part au même moment).
function MusicController.CutChase()
	local names = { Music.ChaseTrack }
	if STEAL_TRACK then
		table.insert(names, STEAL_TRACK)
		stealBlocked = carrying()
	end
	for _, name in names do
		local track = tracks[name]
		if track then
			track.Level = 0
			track.Written = 0
			track.Copy.Volume = 0
			track.Copy.Playing = false
		end
	end
	sinceCheck = math.huge -- musique revue dès la prochaine image
end

-- a477 (L-385 point 5) : arrivée avec l'objet, si la fin du portage et ItemSecured sont proches : MUS_Steal (si elle
-- s'entend) descend en SafeOutTime s, le fond attend SafeReturnDelay s après la fin du portage.
local function arrival()
	if carrying() or math.abs(carryEndedAt - securedAt) > SECURED_WINDOW then
		return
	end
	local track = if STEAL_TRACK then tracks[STEAL_TRACK] else nil
	if track and track.Level > 0 then
		stealOutFast = true
		holdUntil = carryEndedAt + STEAL.SafeReturnDelay
		sinceCheck = math.huge
	end
end

-- a477 (L-385) : le portage commence ou finit (attribut Carrying).
local function onCarryingChanged()
	sinceCheck = math.huge -- prise : MUS_Steal tout de suite
	if carrying() then
		return
	end
	stealBlocked = false
	carryEndedAt = os.clock()
	arrival()
end

local function onItemSecured()
	securedAt = os.clock()
	arrival()
end

-- a477 (L-385 point 1) : un coup validé du joueur local sur la porte d'une boutique de joueur (Id « Plot_<PlotIndex> »).
local function onWindowHit(windowId: string, _point: Vector3, hitter: Player?)
	if hitter ~= localPlayer or type(windowId) ~= "string" then
		return
	end
	local digits: string? = string.match(windowId, PLOT_WINDOW_PATTERN)
	local index = if digits then tonumber(digits) else nil
	if index then
		plotHitIndex = index
		plotHitAt = os.clock()
		sinceCheck = math.huge
	end
end

-- TheftAlertController, s'il est là (a477, MUS_Victim) ; sans lui, pas de musique chez le joueur volé.
local function loadTheft(): TheftApi?
	local module = script.Parent:FindFirstChild("TheftAlertController")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" and type((result :: any).IsRobbed) == "function" then
		return result :: any
	end
	sayOnce("theft", `TheftAlertController : require impossible ({result}) : pas de musique chez le joueur volé`, true)
	return nil
end

-- ChaseController, s'il est là (poursuite : L-071, point 6) ; sans lui, pas de musique de poursuite.
local function loadChase(): ChaseApi?
	local module = script.Parent:FindFirstChild("ChaseController")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" and type((result :: any).IsChased) == "function" then
		return result :: any
	end
	sayOnce("chase", `ChaseController : require impossible ({result}) : pas de musique de poursuite`, true)
	return nil
end

-- HeistController, s'il est là (chrono du braquage) ; sans lui, pas de musique de tension.
local function loadHeist(): HeistApi?
	local module = script.Parent:FindFirstChild("HeistController")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" and type((result :: any).GetTimers) == "function" then
		return result :: any
	end
	sayOnce("heist", `HeistController : require impossible ({result}) : pas de musique de tension`, true)
	return nil
end

function MusicController.Start()
	chase = loadChase()
	heist = loadHeist()
	readVolumeScale()
	localPlayer:GetAttributeChangedSignal(Music.VolumeAttribute):Connect(readVolumeScale)
	if STEAL_ON then
		theft = loadTheft()
		localPlayer:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(onCarryingChanged)
		local netFolder = Shared:FindFirstChild("Net")
		local module = if netFolder then netFolder:FindFirstChild("Net") else nil
		local net: any = nil
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			net = if ok then result else nil
		end
		local hitWired = net ~= nil and pcall(function()
			net.Client.WindowHit:Connect(onWindowHit)
		end)
		if not hitWired then
			sayOnce("windowhit", "remote WindowHit absent : pas de MUS_Heist chez un joueur (L-385)")
		end
		local securedWired = net ~= nil and pcall(function()
			net.Client.ItemSecured:Connect(onItemSecured)
		end)
		if not securedWired then
			sayOnce("secured", "remote ItemSecured absent : MUS_Steal sort au fondu normal à l'arrivée (L-385)")
		end
	end
	local function onError(err: any) -- a283 (audit a271 point 12) : définie une fois, pas une fermeture par image
		sayOnce(`error:{err}`, tostring(err), true)
	end
	RunService.Heartbeat:Connect(function(dt: number)
		xpcall(step, onError, dt)
	end)
end

return MusicController
