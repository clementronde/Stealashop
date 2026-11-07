--!strict
-- MusicController (DEV-051, client) : la musique de fond de la zone du joueur, en fondu enchaîné
-- (liaison L-056, demande de Clément du 2026-11-07 ; valeurs : Config/Music).
--
-- Pistes : les Sound de Clément dans ReplicatedStorage/Assets/Music (sous-dossiers compris),
-- MUS_Hub pour la zone safe et MUS_Z1 à MUS_Z6 pour les zones du couloir. Ils ne sont jamais
-- modifiés : chaque piste jouée est une copie, faite la première fois qu'elle sert, rangée dans
-- SoundService (son 2D, chez ce joueur seulement) et jouée en boucle (Looped forcé sur la copie).
-- Volume plein d'une piste = le Volume du Sound de Clément × le réglage du joueur (attribut
-- Music.VolumeAttribute du Player local, de 0 à 1, absent : 1).
--
-- Zone du joueur, d'après la position de son HumanoidRootPart, revue toutes les CheckInterval s :
--   1. dans le volume d'un objet taggé SafeZone (la pièce elle-même, sinon son enfant Bounds, sinon
--      la boîte englobante du Model : règle de NightCycleService) : MUS_Hub ;
--   2. sinon, au-delà du plan d'une arche ZoneGate (attribut Zone, 1 à 6) : MUS_Z<n>, n étant la
--      zone de l'arche passée la plus loin. Le fond du couloir est donc en zone 6, et entre deux
--      arches on est dans la zone de la dernière passée. « Au-delà » comme dans TutorialService
--      (étape 9) : du côté opposé à l'arche d'avant, sinon à la zone safe (à défaut des deux, du
--      côté de l'arche d'après). Pour changer de piste, il faut dépasser le plan de GateMargin
--      studs ; pour revenir à la zone d'avant, revenir de GateMargin studs en deçà ;
--   3. sinon (entre la zone safe et l'arche 1, ou hors de la carte) : MUS_Hub.
--   Pas encore de personnage : la piste ne change pas. Objets de _INBOX_CLEMENT ignorés.
-- Streaming : la position d'une arche et le volume de la zone safe sont gardés une fois vus (ils ne
-- bougent pas) : une arche sortie du streaming compte toujours.
--
-- Fondu : une seule piste visée à la fois. Elle monte vers son volume plein pendant que toutes les
-- autres descendent, à la même vitesse (de 0 au plein en FadeTime s) : deux pistes ne sont jamais à
-- fond ensemble, et leurs parts additionnées ne dépassent jamais une piste pleine. Une piste
-- descendue à 0 est mise en pause (Playing = false) : elle reprend où elle en était quand le joueur
-- revient dans sa zone. Piste absente : rien ne joue dans cette zone (l'ancienne piste s'éteint),
-- avec une ligne en Studio ; elle est cherchée à nouveau tant que le joueur y reste.
--
-- Rien n'est envoyé au serveur. API (client) :
--   MusicController.GetState() -> { Zone, Track, Levels }
--       Zone du joueur (0 = zone safe, 1 à 6 ; nil avant le premier personnage), piste visée (nil :
--       silence) et part du volume plein de chaque copie (0 à 1), pour un test dans Studio (barre
--       de commande côté client).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Music = require(Shared:WaitForChild("Config"):WaitForChild("Music"))
local Attributes = require(Shared:WaitForChild("Contract"):WaitForChild("Attributes"))

type Volume = { CFrame: CFrame, Size: Vector3 }

type Track = {
	Copy: Sound,
	FullVolume: number, -- Volume du Sound de Clément
	Level: number, -- part du volume plein, de 0 à 1
	Written: number, -- dernier Volume écrit sur la copie
}

export type State = {
	Zone: number?,
	Track: string?,
	Levels: { [string]: number },
}

-- Noms du contrat (2.1 et 10.4).
local SAFE_ZONE_TAG = "SafeZone"
local GATE_TAG = "ZoneGate"
local BOUNDS = "Bounds"
local ROOT_PART = "HumanoidRootPart"
local INBOX_NAME = "_INBOX_CLEMENT" -- livraisons pas encore posées : ignorées, comme dans les services
local ZONE = Attributes.Zone
local HUB = 0 -- zone safe

local IS_STUDIO = RunService:IsStudio()
local FOLDER_PATH = `ReplicatedStorage.{table.concat(Music.Folder, ".")}`

local localPlayer = Players.LocalPlayer

local MusicController = {}

local gates: { [number]: Vector3 } = {} -- arche de chaque zone, gardée une fois vue
local safeVolumes: { [string]: Volume } = {} -- volumes SafeZone vus, par nom complet
local tracks: { [string]: Track } = {} -- copies faites, par nom de piste
local zone: number? = nil
local target: string? = nil -- piste visée ; nil = silence
local volumeScale = 1
local sinceCheck = math.huge -- première vérification à la première image
local said: { [string]: boolean } = {}

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

-- Carte ---------------------------------------------------------------------------------------------

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	local inbox = Workspace:FindFirstChild(INBOX_NAME)
	return inbox == nil or not instance:IsDescendantOf(inbox)
end

local function insideBox(volume: Volume, position: Vector3): boolean
	local p = volume.CFrame:PointToObjectSpace(position)
	local size = volume.Size
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

-- Volume d'un objet SafeZone, ou nil tant que ses pièces ne sont pas là (streaming).
local function volumeOf(instance: Instance): Volume?
	local part: Instance? = if instance:IsA("BasePart") then instance else instance:FindFirstChild(BOUNDS)
	if part and part:IsA("BasePart") then
		return { CFrame = (part :: BasePart).CFrame, Size = (part :: BasePart).Size }
	end
	if instance:IsA("Model") and instance:FindFirstChildWhichIsA("BasePart", true) then
		local cframe, size = (instance :: Model):GetBoundingBox()
		return { CFrame = cframe, Size = size }
	end
	return nil
end

-- Point d'une arche : Attachment, pièce, ou pivot d'un Model (comme TutorialService) ; centre de ses
-- pièces si sa PrimaryPart n'est pas là ; nil tant qu'aucune pièce n'est là (streaming).
local function gatePosition(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		local parent = instance.Parent
		return if parent and parent:IsA("BasePart") then (instance :: Attachment).WorldPosition else nil
	elseif instance:IsA("BasePart") then
		return (instance :: BasePart).Position
	elseif instance:IsA("Model") then
		local model = instance :: Model
		if model.PrimaryPart then
			return model:GetPivot().Position
		elseif model:FindFirstChildWhichIsA("BasePart", true) then
			local cframe = model:GetBoundingBox()
			return cframe.Position
		end
	end
	return nil
end

-- Garde la position des arches et le volume de la zone safe qui sont là en ce moment.
local function refreshMap()
	for _, instance in CollectionService:GetTagged(GATE_TAG) do
		local value = instance:GetAttribute(ZONE.Name)
		if type(value) == "number" and value % 1 == 0 and value >= ZONE.Min and value <= ZONE.Max and inMap(instance) then
			local position = gatePosition(instance)
			if position then
				gates[value] = position
			end
		end
	end
	for _, instance in CollectionService:GetTagged(SAFE_ZONE_TAG) do
		if inMap(instance) then
			local volume = volumeOf(instance)
			if volume then
				safeVolumes[instance:GetFullName()] = volume
			end
		end
	end
end

-- Direction horizontale de `from` vers `to`, ou nil si les deux points sont l'un sur l'autre.
local function direction(from: Vector3, to: Vector3): Vector3?
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return if flat.Magnitude >= 1 then flat.Unit else nil
end

-- Le centre de zone safe le plus proche de `at`.
local function hubPoint(at: Vector3): Vector3?
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, volume in safeVolumes do
		local center = volume.CFrame.Position
		local distance = (center - at).Magnitude
		if distance < bestDistance then
			best, bestDistance = center, distance
		end
	end
	return best
end

-- Sens « vers le fond du couloir » au niveau de l'arche `n`, posée en `at`.
local function axisOf(n: number, at: Vector3): Vector3?
	local before = gates[n - 1] or hubPoint(at)
	local axis = if before then direction(before, at) else nil
	if axis == nil then
		local after = gates[n + 1]
		axis = if after then direction(at, after) else nil
	end
	return axis
end

-- Zone de `position` (voir l'en-tête) ; `current` = zone d'avant, pour la marge des arches.
local function zoneAt(position: Vector3, current: number?): number
	for _, volume in safeVolumes do
		if insideBox(volume, position) then
			return HUB
		end
	end
	local best = HUB
	for n, at in gates do
		if n > best then
			local margin = if current ~= nil and n <= current then -Music.GateMargin else Music.GateMargin
			local axis = axisOf(n, at)
			if axis and (position - at):Dot(axis) >= margin then
				best = n
			end
		end
	end
	return best
end

-- Pistes ----------------------------------------------------------------------------------------------

local function trackName(n: number): string
	return if n == HUB then Music.HubTrack else string.format(Music.ZoneTrack, n)
end

local function findTemplate(name: string): Sound?
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
	sayOnce(`track:{name}`, `{name} absent de {FOLDER_PATH} (ou pas un Sound) : pas de musique dans cette zone (L-056)`)
	return nil
end

-- La copie de la piste `name`, faite au besoin ; false si la piste manque.
local function ensureTrack(name: string): boolean
	if tracks[name] then
		return true
	end
	local template = findTemplate(name)
	if template == nil then
		return false
	end
	local copy = template:Clone() :: Sound?
	if copy == nil then
		sayOnce(`archivable:{name}`, `{name} ne se copie pas (Archivable = false) : pas de musique dans cette zone`, true)
		return false
	end
	copy.Looped = true
	copy.Playing = false
	copy.Volume = 0
	copy.Parent = SoundService
	tracks[name] = { Copy = copy, FullVolume = template.Volume, Level = 0, Written = 0 }
	return true
end

-- Boucle ----------------------------------------------------------------------------------------------

local function localPosition(): Vector3?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild(ROOT_PART) else nil
	return if root and root:IsA("BasePart") then (root :: BasePart).Position else nil
end

local function check()
	refreshMap()
	local position = localPosition()
	if position then
		zone = zoneAt(position, zone)
	end
	local current = zone
	if current == nil then
		return
	end
	local name = trackName(current)
	target = if ensureTrack(name) then name else nil
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
end

local function step(dt: number)
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
	return { Zone = zone, Track = target, Levels = levels }
end

function MusicController.Start()
	readVolumeScale()
	localPlayer:GetAttributeChangedSignal(Music.VolumeAttribute):Connect(readVolumeScale)
	RunService.Heartbeat:Connect(function(dt: number)
		xpcall(step, function(err: any)
			sayOnce(`error:{err}`, tostring(err), true)
		end, dt)
	end)
end

return MusicController
