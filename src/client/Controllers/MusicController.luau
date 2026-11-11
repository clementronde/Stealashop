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
-- Rien n'est envoyé au serveur. API (client) :
--   MusicController.GetState() -> { Track, Levels, Event }
--       Piste visée (nil : silence), part du volume plein de chaque copie (0 à 1) et événement dont la
--       musique joue ("Chase", "Heist", "Truck", nil : le fond), pour un test dans Studio (barre de
--       commande côté client).

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

local ROOT_PART = "HumanoidRootPart"
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

local function within(instance: Instance, position: Vector3, radius: number): boolean
	return instance:IsA("PVInstance") and ((instance :: PVInstance):GetPivot().Position - position).Magnitude <= radius
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
	local api = chase
	local chaseTrack = tracks[Music.ChaseTrack]
	local audible = chaseTrack ~= nil and chaseTrack.Level > 0
	if api and api.IsChased() and (chasedFor >= CHASE_DELAY or audible) and ensureTrack(Music.ChaseTrack, CHASE_EFFECT) then
		return Music.ChaseTrack, CHASE
	end
	if heistRunning() and ensureTrack(Music.HeistTrack, HEIST_EFFECT) then
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
		name = backgroundTrack()
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

local function fade(dt: number)
	local rate = if Music.FadeTime > 0 then dt / Music.FadeTime else math.huge
	for name, track in tracks do
		local goal = if name == target then 1 else 0
		local level = track.Level
		if level < goal then
			level = math.min(level + rate, goal)
		elseif level > goal then
			level = math.max(level - rate, goal)
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
	RunService.Heartbeat:Connect(function(dt: number)
		xpcall(step, function(err: any)
			sayOnce(`error:{err}`, tostring(err), true)
		end, dt)
	end)
end

return MusicController
