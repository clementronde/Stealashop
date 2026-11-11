--!strict
-- TruckEventService (liaison L-049, décision de Clément du 2026-11-07 ; pas encore une tâche du
-- backlog) : l'événement camion. Valeurs : Config/TruckEvent ; interrupteur : Config/Features.TruckEvent.
--
-- Un seul camion à la fois :
--   1. Apparition, SpawnIntervalMin à SpawnIntervalMax s (tiré au hasard) après l'apparition
--      précédente (ou le démarrage du serveur), seulement de jour : phase Day de NightCycleService,
--      au moins DawnDelay s après l'aube et MinDayLeft s avant l'alerte. Un camion dû pendant
--      l'alerte ou la nuit attend que ces conditions reviennent. Zone tirée au hasard dans SpawnZones.
--      Où :
--        - sur un point taggé `TruckSpawn` (Attachment, pièce ou Model, attribut Zone ; nom proposé à
--          Clément, hors contrat) s'il y en a dans la zone, au hasard : le pivot du camion (en bas au
--          centre) va sur le point, l'avant (−Z) du camion suit celui du point ;
--        - sinon calculé : au milieu des deux magasins PNJ de la zone (ils se font face de part et
--          d'autre de la chaussée), c'est-à-dire au milieu de la chaussée, en long dans le sens du
--          couloir (de l'arche ZoneGate de la plus petite zone vers celle de la plus grande). Le
--          camion fait 12,6 studs de large : il laisse 24 studs devant chaque vitrine de la carte
--          actuelle. Un seul magasin dans la zone : à sa hauteur, sur la ligne des arches ; aucun :
--          au milieu de la zone, sur la ligne des arches. Sol trouvé par un rayon.
--      Le camion = une copie de ENV_Event_Truck (Clément, ReplicatedStorage/Assets, sinon
--      ServerStorage/Assets), vidée de tout script, toutes pièces ancrées, nommée EventTruck, tag
--      EventTruck (posé par le code), attributs Zone et TruckNumber. Son contour OutlineHighlight
--      vient du modèle ; sa barre de vie (copie de BB_WindowHP à HealthBarPoint) est posée par
--      TruckController, côté client. Notify à tous.
--      Conducteurs (liaison L-071, point 7) : chaque Model du camion qui a un Humanoid. S'il a une
--      animation Idle dans son dossier Animations (Contract/Animations.Driver), ce service la joue en
--      boucle (Animator du Humanoid, créé s'il manque ; réplication aux clients) ; pour qu'il bouge,
--      seule sa racine (RootPart, HumanoidRootPart ou PrimaryPart) est ancrée, ses membres reliés à
--      elle par ses articulations restent libres. Sans Idle, il est ancré comme le reste et immobile.
--      À l'explosion, TruckController le fait voler avec les pièces.
--   2. PV partagés : cible d'événement de WindowService (AddTarget, MaxHP, sans régénération),
--      frappée avec les outils et les règles des vitrines (HitController, HitWindow : dégâts du
--      joueur, portée, débit, coup au marqueur Impact). Ses PV : attribut HP du camion.
--   3. Départ sans rien lâcher, avec un Notify : pas cassé au bout de Lifetime s, ou dès que l'alerte
--      de la nuit commence (ou la nuit, si on y saute).
--   3'. Fin du chrono du camion (demande de Clément du 2026-11-10, liaison L-083 point 3) : Lifetime s
--      après l'apparition, ou plus tôt à l'alerte de la nuit (ou la nuit), que le camion ait explosé ou
--      non (pas cassé : il part, point 3). Les conducteurs réapparaissent d'un coup au point du camion
--      et poursuivent les joueurs qui portent un colis de CE camion (StoreId « Truck_<n> »), vivants et
--      hors zone safe : un conducteur par porteur, DriverChaseMax au plus et pas plus que de
--      conducteurs dans le modèle de Clément (ENV_Event_Truck, par ordre de nom), les porteurs les
--      plus proches du camion d'abord. Chacun apparaît à DriverSpawnSpacing studs de l'autre, de part
--      et d'autre du pivot du camion, au sol. La poursuite elle-même est celle de GuardService
--      (StartDriverChase : chemin, capture à Balance.Guard.CatchDistance, coup au marqueur Impact de
--      Catch, chute du joueur, étourdi CatchStunDuration s), à DriverSpeedMultiplier × la WalkSpeed du
--      porteur (au moins DriverMinSpeed), abandon à la zone safe (le colis y est rangé) ou quand il ne
--      porte plus ce colis, jamais au bout d'un temps (poursuite sans fin, Cantin 2026-11-11). Attrapé : CarryService.Fail(…, "Caught"), le
--      colis est perdu. Notify DriversChase au porteur poursuivi. Aucun porteur : aucun conducteur.
--      GuardService est chargé à ce moment-là, protégé : sans lui (bancs), pas de poursuite.
--   4. À 0 PV (WindowService.OnBroken, Kind « Event ») : explosion.
--      - Le serveur coupe collisions, contacts et requêtes de toutes les pièces du camion, éteint son
--        contour et pose ExplodedAt (heure serveur) : TruckController fait voler les pièces
--        Pieces/Piece_xx depuis BlastPoint puis les efface (effet seulement, côté client : rien de ce
--        qui compte n'en dépend). La copie est retirée RemoveDelay s plus tard.
--      - Colis : Boxes (12 : 6 Standard, 4 Premium, 2 Luxe), types répartis au hasard sur
--        BoxSpawn_01 à _12 (BlastPoint pour un point qui manque). Contenu tiré comme sur un rayon de
--        la zone du camion : rareté selon ShelfBoxes.OddsFor (zone 1 : Communs seulement, L-033),
--        objet par Items.Pick, repli sur la rareté tirable la plus proche en dessous (comme
--        StoreHeistService), mutation par Mutations.Roll (DEV-131, comme sur un rayon). Chaque colis est posé tout de suite à son point d'arrivée
--        (CarryService.PlaceDrop), au sol, de ScatterMinRadius à ScatterRadius studs du centre du
--        camion, du côté de son point de sortie (ScatterSpread), et jamais sur un autre : au moins
--        BoxGap studs bord à bord entre deux colis, d'après la largeur des modèles BOX_<Tier> (cône
--        élargi, puis cercles plus grands si la place manque : voir landingPoint). Le client le fait voler depuis son
--        BoxSpawn avec la traînée FX_BoxTrail (attributs TruckBox, Tier, FlightFrom, FlightStartsAt,
--        FlightDuration) ; les départs sont espacés de LaunchStagger s. Ramassable une fois atterri.
--      - Notify à tous.
--   5. Colis du camion au sol : GrabDropped(dropId) (9.4), en deux appels comme GrabItem (début du
--      maintien, puis invite déclenchée). Le serveur vérifie : colis atterri et encore au sol, mains
--      vides, joueur vivant, hors zone safe (tag SafeZone), à Bat.DroppedGrabMaxDistance studs au
--      plus du colis, maintien du temps de prise de son type (Balance.Heist.BoxTiers[Tier].GrabTime),
--      revérifiés 10 fois par seconde pendant le maintien. Alors CarryService.PickUpDrop : porté,
--      c'est un colis PNJ ordinaire (StoreId « Truck_<n> », SlotId « Truck_<n>/<kk> »), à poser sur
--      un établi pour l'ouvrir. Aucun vigile ne le poursuit : le camion n'a pas de magasin. Pas
--      ramassé : il disparaît BoxLifetime s après son atterrissage. Porteur en échec (mort, départ,
--      attrapé la nuit) : le colis est perdu, il n'a pas de rayon où revenir.
--      Ce service ne traite GrabDropped que pour ses colis : un autre colis au sol (batte, DEV-048) est
--      laissé au service qui l'a posé.
--
-- Crochet de test, STUDIO SEULEMENT (comme NightSkipTo) : en Play, dans la barre de commande serveur :
--       workspace:SetAttribute("TruckSpawnNow", 3)          -- un camion tout de suite en zone 3 (1 à 6)
--       workspace:SetAttribute("TruckSpawnNow", "Explode")  -- le camion présent explose tout de suite
--       workspace:SetAttribute("TruckSpawnNow", "Leave")    -- le camion présent, pas cassé, part tout de suite :
--                                                           -- fin de son chrono (point 3')
--       workspace:SetAttribute("TruckSpawnNow", "Chase")    -- fin du chrono tout de suite, même après
--                                                           -- l'explosion : les conducteurs poursuivent les
--                                                           -- porteurs de ses colis (point 3')
--   Le service lit l'attribut, l'efface et agit, même de nuit ; un camion présent est remplacé sans
--   message. Hors de Studio, l'attribut n'est pas écouté.
--
-- API (serveur) : aucune. Posé par ce service, lu par TruckController : le tag EventTruck et les
-- attributs du camion (Zone, TruckNumber, ExplodedAt ; WindowId, MaxHP, HP et Broken venant de
-- WindowService), les attributs des colis du camion (plus haut).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Bat = require(Shared.Config.Bat)
local Features = require(Shared.Config.Features)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local ShelfBoxes = require(Shared.Config.ShelfBoxes)
local TruckEvent = require(Shared.Config.TruckEvent)
local Zones = require(Shared.Config.Zones)
local Find = require(Shared.Contract.Find)
local Animations = require(Shared.Contract.Animations)
local Net = require(Shared.Net.Net)
local CarryTypes = require(Shared.Types.Carry)

local CarryService = require(script.Parent.CarryService)
local NightCycleService = require(script.Parent.NightCycleService)
local WindowService = require(script.Parent.WindowService)

type TruckState = "Active" | "Exploding"

type Truck = {
	Number: number, -- 1, 2, 3… depuis le démarrage du serveur
	Zone: number,
	Model: Model,
	WindowId: string,
	SpawnedAt: number, -- os.clock()
	State: TruckState,
}

-- Chrono d'un camion (point 3') : survit à l'explosion et au retrait de la copie.
type Chrono = {
	Number: number,
	Zone: number,
	Frame: CFrame, -- pivot du camion (en bas au centre) : où réapparaissent les conducteurs
	EndsAt: number, -- os.clock()
}

-- Ce que ce service utilise de GuardService (chargé à la fin du chrono, voir loadGuardService).
type GuardApi = { StartDriverChase: (chase: any) -> Model? }

-- Colis du camion au sol (ou en vol vers le sol).
type TruckBox = {
	DropId: string,
	Tier: string,
	LandsAt: number, -- os.clock() de l'atterrissage
}

type Hold = { DropId: string, StartedAt: number }

-- Point d'arrivée d'un colis déjà posé à l'explosion, et sa largeur au sol.
type Landing = { Position: Vector3, Width: number }

-- Noms du contrat lus ici (L-049, Contract/Models ; tags et attribut : 2.1).
local TRUCK_ASSET = "ENV_Event_Truck"
local BLAST_POINT = "BlastPoint"
local BOX_SPAWN_FORMAT = "BoxSpawn_%02d"
local OUTLINE_NAME = "OutlineHighlight"
local ASSETS_NAME = "Assets"
local ZONE_GATE_TAG = "ZoneGate"
local STORE_TAG = "NPCStore"
local SAFE_ZONE_TAG = "SafeZone"
local BOUNDS_NAME = "Bounds"
local ZONE_ATTRIBUTE = "Zone"
local INBOX_NAME = "_INBOX_CLEMENT"
local SANDBOX_NAME = "_SANDBOX_IRONIX"
-- Proposition de nom à Clément, hors contrat (pas encore posé) : points d'apparition du camion.
local TRUCK_SPAWN_TAG = "TruckSpawn"
local DROPS_FOLDER = "CarryDrops" -- dossier des colis au sol de CarryService

-- Posés par ce service, lus par TruckController (mêmes noms là-bas).
local TRUCK_NAME = "EventTruck" -- jamais « ENV_… » dans la map : c'est le nom de l'asset (ContractChecker)
local TRUCK_TAG = "EventTruck" -- tag posé par le code, hors du contrat de la section 2.1
local NUMBER_ATTRIBUTE = "TruckNumber"
local SPAWNED_AT_ATTRIBUTE = "SpawnedAt" -- heure serveur de l'apparition (sons d'arrivée, vague 26)
local EXPLODED_AT_ATTRIBUTE = "ExplodedAt"
local TRUCK_BOX_ATTRIBUTE = "TruckBox"
local TIER_ATTRIBUTE = "Tier"
local FLIGHT_FROM_ATTRIBUTE = "FlightFrom"
local FLIGHT_STARTS_AT_ATTRIBUTE = "FlightStartsAt"
local FLIGHT_DURATION_ATTRIBUTE = "FlightDuration"
local SKIP_ATTRIBUTE = "TruckSpawnNow" -- Studio seulement (test), voir l'en-tête

-- V0 proposé, absent du doc : après NightCycleService (120), dont il lit les phases.
local PRIORITY = 130
-- V0 proposé, absent du doc : horaire, départ et maintiens revus 10 fois par seconde.
local TICK = 0.1
-- V0 proposé, absent du doc : écart du réseau toléré sur la durée de maintien (comme GrabItem), et
-- sur l'heure d'atterrissage (le client voit le colis atterrir à l'heure serveur, à la latence près).
local GRAB_TIME_TOLERANCE = 0.1
local LANDING_TOLERANCE = 0.15
-- V0 proposé, absent du doc : un maintien non conclu expire 1 s après sa durée (comme GrabItem).
local HOLD_EXPIRY = 1
-- V0 proposé, absent du doc : sol cherché de 20 studs au-dessus à 40 en dessous du point visé.
local GROUND_RAY_UP = 20
local GROUND_RAY_DOWN = 40
-- V0 proposé, absent du doc : zone sans magasin ni arche suivante, le camion va à 40 studs après son arche.
local GATE_FALLBACK_DISTANCE = 40
-- V0 proposé, absent du doc (a42) : point d'arrivée d'un colis, 20 essais au hasard par largeur de cône,
-- puis des cercles jusqu'à 20 studs au-delà de ScatterRadius si la place manque.
local LANDING_TRIES = 20
local LANDING_EXTRA_RADIUS = 20
local BOX_PREFIX = "BOX_" -- modèles des colis de Clément (10.3), mesurés pour l'écart entre colis

local IS_STUDIO = RunService:IsStudio()
local ENABLED: boolean = Features.TruckEvent

local TruckEventService = {}
TruckEventService.Priority = PRIORITY

local current: Truck? = nil
local chrono: Chrono? = nil
local truckCount = 0
local nextSpawnAt = math.huge -- os.clock() ; posé au Start
local dayStartedAt = -math.huge -- os.clock() de la dernière aube
local boxes: { [string]: TruckBox } = {}
local holds: { [Player]: Hold } = {}
local lastRefusal: { [Player]: number } = {}
local warned: { [string]: boolean } = {}
local boxCache: { [Instance]: { cframe: CFrame, size: Vector3 } } = {}
local random = Random.new()

-- Outils ----------------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[TruckEventService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[TruckEventService] {message}`)
end

-- Prise refusée : signalée en Studio seulement (aide au test), une ligne par seconde et par joueur.
local function refuse(player: Player, dropId: string, reason: string)
	if not IS_STUDIO then
		return
	end
	local now = os.clock()
	if now - (lastRefusal[player] or -math.huge) < 1 then
		return
	end
	lastRefusal[player] = now
	warn(`[TruckEventService] GrabDropped de {player.Name} sur « {dropId} » refusé : {reason}`)
end

local function notifyAll(message: string, kind: string)
	Net.Server.Notify:FireAll(message, kind)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function inMap(instance: Instance): boolean
	if not instance:IsDescendantOf(Workspace) then
		return false
	end
	for _, name in { INBOX_NAME, SANDBOX_NAME } do
		local folder = Workspace:FindFirstChild(name)
		if folder and instance:IsDescendantOf(folder) then
			return false
		end
	end
	return true
end

local function zoneOf(instance: Instance): number?
	local value = instance:GetAttribute(ZONE_ATTRIBUTE)
	return if type(value) == "number" then value else nil
end

-- Pivot d'un point du décor : Attachment, pièce ou Model.
local function frameOf(instance: Instance): CFrame?
	if instance:IsA("Attachment") then
		return (instance :: Attachment).WorldCFrame
	elseif instance:IsA("PVInstance") then
		return (instance :: PVInstance):GetPivot()
	end
	return nil
end

local function taggedInZone(tag: string, zone: number): { Instance }
	local list: { Instance } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if zoneOf(instance) == zone and inMap(instance) then
			table.insert(list, instance)
		end
	end
	return list
end

-- HumanoidRootPart d'un joueur vivant, ou nil.
local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root :: BasePart
end

local function insideBox(cframe: CFrame, size: Vector3, position: Vector3): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

-- Dans un volume taggé SafeZone : la pièce elle-même, sinon son enfant direct Bounds, sinon la boîte
-- englobante du modèle (même règle que GuardService).
local function inSafeZone(position: Vector3): boolean
	for _, instance in CollectionService:GetTagged(SAFE_ZONE_TAG) do
		if not inMap(instance) then
			continue
		end
		local part: Instance? = if instance:IsA("BasePart") then instance else instance:FindFirstChild(BOUNDS_NAME)
		if part and part:IsA("BasePart") then
			local box = part :: BasePart
			if insideBox(box.CFrame, box.Size, position) then
				return true
			end
		elseif instance:IsA("Model") then
			local cached = boxCache[instance]
			if cached == nil then
				local cframe, size = (instance :: Model):GetBoundingBox()
				cached = { cframe = cframe, size = size }
				boxCache[instance] = cached
			end
			if insideBox(cached.cframe, cached.size, position) then
				return true
			end
		end
	end
	return false
end

-- Place ---------------------------------------------------------------------------------------------

-- Hauteur du sol sous `position` (rayon vers le bas) ; personnages, colis au sol et camions ignorés.
local function groundY(position: Vector3, fallbackY: number): number
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(exclude, character)
		end
	end
	local drops = Workspace:FindFirstChild(DROPS_FOLDER)
	if drops then
		table.insert(exclude, drops)
	end
	for _, truck in CollectionService:GetTagged(TRUCK_TAG) do
		table.insert(exclude, truck)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local origin = Vector3.new(position.X, position.Y + GROUND_RAY_UP, position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(GROUND_RAY_UP + GROUND_RAY_DOWN), 0), params)
	return if result then result.Position.Y else fallbackY
end

-- Position du pivot de l'arche de la zone, ou nil.
local function gatePosition(zone: number): Vector3?
	for _, gate in taggedInZone(ZONE_GATE_TAG, zone) do
		local frame = frameOf(gate)
		if frame then
			return frame.Position
		end
	end
	return nil
end

-- Sens du couloir, à plat : de l'arche de la plus petite zone vers celle de la plus grande (la rue est
-- droite, section 4). Sans deux arches : l'axe X du monde (le couloir de la carte actuelle).
local function corridorDirection(): Vector3
	local first: Vector3?, last: Vector3? = nil, nil
	local firstZone, lastZone = math.huge, -math.huge
	for _, gate in CollectionService:GetTagged(ZONE_GATE_TAG) do
		local zone = zoneOf(gate)
		local frame = frameOf(gate)
		if zone and frame and inMap(gate) then
			if zone < firstZone then
				firstZone, first = zone, frame.Position
			end
			if zone > lastZone then
				lastZone, last = zone, frame.Position
			end
		end
	end
	if first and last and firstZone < lastZone then
		local direction = flat(last - first)
		if direction.Magnitude > 1e-3 then
			return direction.Unit
		end
	end
	return Vector3.xAxis
end

-- Pivot du camion calculé depuis les magasins et les arches de la zone (voir l'en-tête), ou nil.
local function computedFrame(zone: number): CFrame?
	local direction = corridorDirection()
	local gate = gatePosition(zone)
	local stores: { Vector3 } = {}
	for _, store in taggedInZone(STORE_TAG, zone) do
		local frame = frameOf(store)
		if frame then
			table.insert(stores, frame.Position)
		end
	end
	local center: Vector3
	local fallbackY: number
	if #stores >= 2 then
		local sum = Vector3.zero
		for _, position in stores do
			sum += position
		end
		center = sum / #stores
		fallbackY = center.Y
	elseif gate then
		local along: number
		if #stores == 1 then
			along = (stores[1] - gate):Dot(direction)
		else
			local nextGate = gatePosition(zone + 1)
			along = if nextGate then (nextGate - gate):Dot(direction) / 2 else GATE_FALLBACK_DISTANCE
		end
		center = gate + direction * along
		fallbackY = if #stores == 1 then stores[1].Y else gate.Y
	elseif #stores == 1 then
		center = stores[1]
		fallbackY = center.Y
	else
		return nil
	end
	local position = Vector3.new(center.X, groundY(center, fallbackY), center.Z)
	return CFrame.lookAt(position, position + direction)
end

-- Pivot du camion dans `zone` : un point TruckSpawn de la zone au hasard, sinon calculé.
local function spawnFrame(zone: number): CFrame?
	local points = taggedInZone(TRUCK_SPAWN_TAG, zone)
	while #points > 0 do
		local index = random:NextInteger(1, #points)
		local frame = frameOf(points[index])
		if frame then
			return frame
		end
		table.remove(points, index)
	end
	return computedFrame(zone)
end

-- Modèle ENV_Event_Truck de Clément, ou nil s'il n'est pas rangé dans Assets.
local function findTemplate(): Model?
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild(ASSETS_NAME)
		local found = if assets then assets:FindFirstChild(TRUCK_ASSET, true) else nil
		if found and found:IsA("Model") then
			return found :: Model
		end
	end
	return nil
end

-- Conducteurs (L-071, point 7) ----------------------------------------------------------------------

type Driver = { Rig: Model, Humanoid: Humanoid, Root: BasePart, Idle: boolean }

-- Shared/Anim/AnimPlayer, chargé au premier conducteur (rien à charger sans conducteur).
type AnimPlayerApi = typeof(require(Shared.Anim.AnimPlayer))
local animPlayerModule: AnimPlayerApi? = nil
local function animPlayer(): AnimPlayerApi
	local loaded = animPlayerModule
	if loaded then
		return loaded
	end
	local module = require(Shared.Anim.AnimPlayer)
	animPlayerModule = module
	return module
end

-- Pièce racine d'un conducteur : RootPart du Humanoid, sinon HumanoidRootPart, sinon PrimaryPart.
local function driverRoot(rig: Model, humanoid: Humanoid): BasePart?
	local root = humanoid.RootPart
	if root and root:IsDescendantOf(rig) then
		return root
	end
	local named = rig:FindFirstChild("HumanoidRootPart")
	if named and named:IsA("BasePart") then
		return named :: BasePart
	end
	return rig.PrimaryPart
end

-- Les conducteurs du camion `model` : chaque Model qui a un Humanoid (le camion lui-même exclu), avec
-- sa pièce racine. Idle = son dossier Animations a une animation Idle livrée (Contract/Animations.Driver).
local function driversOf(model: Model): { Driver }
	local list: { Driver } = {}
	local idleName = Animations.Driver[1].Name
	for _, descendant in model:GetDescendants() do
		local rig = descendant.Parent
		if descendant:IsA("Humanoid") and rig and rig ~= model and rig:IsA("Model") then
			local humanoid = descendant :: Humanoid
			local root = driverRoot(rig :: Model, humanoid)
			if root then
				local animation = animPlayer().findAnimation(animPlayer().modelFolder(rig), idleName)
				table.insert(list, { Rig = rig :: Model, Humanoid = humanoid, Root = root, Idle = animation ~= nil })
			end
		end
	end
	return list
end

-- Les deux pièces d'une articulation ou d'une soudure (Motor6D, Weld, WeldConstraint…), sinon nil.
local function jointParts(instance: Instance): (BasePart?, BasePart?)
	if instance:IsA("JointInstance") then
		local joint = instance :: JointInstance
		return joint.Part0, joint.Part1
	elseif instance:IsA("WeldConstraint") then
		local weld = instance :: WeldConstraint
		return weld.Part0, weld.Part1
	end
	return nil, nil
end

-- Pièces d'un conducteur animé qui doivent rester libres pour que ses articulations bougent : celles
-- du conducteur reliées à sa racine, de proche en proche, par ses articulations et soudures (Motor6D
-- d'un rig R15), racine exclue. Une pièce qui ne lui est pas reliée reste ancrée (elle tomberait).
-- Lu sur les articulations elles-mêmes : la copie n'est pas encore dans le Workspace.
local function animatedParts(driver: Driver): { [BasePart]: boolean }
	local free: { [BasePart]: boolean } = {}
	if not driver.Idle then
		return free
	end
	local links: { [BasePart]: { BasePart } } = {}
	local function link(a: BasePart, b: BasePart)
		local list = links[a] or {}
		links[a] = list
		table.insert(list, b)
	end
	for _, descendant in driver.Rig:GetDescendants() do
		local part0, part1 = jointParts(descendant)
		if part0 and part1 and part0:IsDescendantOf(driver.Rig) and part1:IsDescendantOf(driver.Rig) then
			link(part0, part1)
			link(part1, part0)
		end
	end
	local seen: { [BasePart]: boolean } = { [driver.Root] = true }
	local queue: { BasePart } = { driver.Root }
	while #queue > 0 do
		local part = table.remove(queue) :: BasePart
		local neighbours = links[part]
		if neighbours then
			for _, other in neighbours do
				if not seen[other] then
					seen[other] = true
					free[other] = true
					table.insert(queue, other)
				end
			end
		end
	end
	return free
end

-- Joue l'Idle de chaque conducteur animé (le camion est déjà dans le Workspace). Animator absent : créé
-- ici, côté serveur (il réplique les animations aux clients).
local function playDriverIdles(drivers: { Driver })
	for _, driver in drivers do
		if driver.Idle then
			local ok, err = pcall(function()
				local animator = driver.Humanoid:FindFirstChildOfClass("Animator")
				if animator == nil then
					local created = Instance.new("Animator")
					created.Parent = driver.Humanoid
					animator = created
				end
				local anims = animPlayer().new(animator :: Animator, animPlayer().modelFolder(driver.Rig), Animations.Driver, "Conducteur")
				anims:Play(Animations.Driver[1].Name)
			end)
			if not ok then
				warnOnce(`driver.{driver.Rig.Name}`, `conducteur {driver.Rig.Name} : Idle non jouée ({err})`)
			end
		end
	end
end

-- Tirage (comme un rayon de la zone, StoreHeistService) ------------------------------------------------

local function drawRarity(tier: string, zone: number): string?
	local odds = ShelfBoxes.OddsFor(zone, tier)
	if odds == nil then
		return nil
	end
	local total = 0
	for _, rarity in Rarities.List do
		total += odds[rarity.Id] or 0
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber() * total
	local last: string? = nil
	for _, rarity in Rarities.List do
		local weight = odds[rarity.Id] or 0
		if weight > 0 then
			last = rarity.Id
			if roll < weight then
				return rarity.Id
			end
			roll -= weight
		end
	end
	return last -- arrondi des nombres à virgule : la dernière rareté possible
end

-- Rareté et objet d'un colis de type `tier` en zone `zone`, ou nil (Config incohérente).
local function drawContent(tier: string, zone: number): (string?, string?)
	local rarity = drawRarity(tier, zone)
	if rarity == nil then
		return nil, nil
	end
	local item = Items.Pick(zone, rarity :: Rarities.RarityId, random)
	if item then
		return item.Rarity, item.Id
	end
	-- Case vide : la rareté tirable la plus proche en dessous (Rarities.List va de Commun à Secret).
	local order = Rarities.ById[rarity].Order
	for index = #Rarities.List, 1, -1 do
		local candidate = Rarities.List[index]
		if candidate.Order < order then
			local fallback = Items.Pick(zone, candidate.Id, random)
			if fallback then
				warnOnce(
					`empty.{zone}.{rarity}`,
					`aucun objet {rarity} tirable en zone {zone} (Config/Items) : ces colis du camion reçoivent un objet {candidate.Id}`
				)
				return fallback.Rarity, fallback.Id
			end
		end
	end
	return nil, nil
end

-- Types des colis (Config.Boxes), mélangés : le n-ième sort de BoxSpawn_n.
local function boxTiers(): { string }
	local list: { string } = {}
	for _, entry in TruckEvent.Boxes do
		for _ = 1, entry.Count do
			table.insert(list, entry.Tier)
		end
	end
	for index = #list, 2, -1 do
		local other = random:NextInteger(1, index)
		list[index], list[other] = list[other], list[index]
	end
	return list
end

-- Largeur au sol d'un colis de type `tier` : la plus grande dimension horizontale du modèle BOX_<Tier>
-- de Clément (Assets), sinon TruckEvent.BoxFallbackWidth (le bloc gris de CarryService).
local function boxWidth(tier: string): number
	local name = BOX_PREFIX .. tier
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild(ASSETS_NAME)
		local found = if assets then assets:FindFirstChild(name, true) else nil
		if found and found:IsA("Model") then
			local size = (found :: Model):GetExtentsSize()
			return math.max(size.X, size.Z)
		elseif found and found:IsA("BasePart") then
			local size = (found :: BasePart).Size
			return math.max(size.X, size.Z)
		end
	end
	return TruckEvent.BoxFallbackWidth
end

-- Place libre à `point` pour un colis de largeur `width` : marge (studs, bord à bord) avec le plus
-- proche des colis déjà posés ; math.huge s'il n'y en a pas.
local function clearance(point: Vector3, width: number, taken: { Landing }): number
	local worst = math.huge
	for _, other in taken do
		local gap = flat(point - other.Position).Magnitude - (width + other.Width) / 2
		if gap < worst then
			worst = gap
		end
	end
	return worst
end

-- Un point au hasard dans le cône de demi-angle `spread` autour de l'angle `base`, entre `minRadius`
-- et `maxRadius` studs de `center` (à plat).
local function scatterPoint(center: Vector3, base: number, spread: number, minRadius: number, maxRadius: number): Vector3
	local angle = base + (random:NextNumber() * 2 - 1) * spread
	local radius = minRadius + random:NextNumber() * (maxRadius - minRadius)
	return center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
end

-- Point d'arrivée au sol d'un colis de largeur `width` sorti en `from` d'un camion centré en `center`
-- (voir l'en-tête), à au moins BoxGap studs des colis déjà posés (`taken`, demande d'Ironix du
-- 2026-11-08 : des colis l'un dans l'autre faisaient prendre le mauvais avec E). Essais au hasard, de
-- plus en plus larges : dans le cône ScatterSpread, puis de son côté du camion (± 90°), puis tout
-- autour ; toujours entre ScatterMinRadius et ScatterRadius. Sans place libre : cercles de plus en
-- plus grands au-delà de ScatterRadius, un stud à la fois (premier point libre, jamais dans un autre
-- colis) ; au pire, le point le moins serré essayé.
local function landingPoint(from: Vector3, center: Vector3, width: number, taken: { Landing }): Vector3
	local out = flat(from - center)
	local base = if out.Magnitude > 1e-3 then math.atan2(out.Z, out.X) else random:NextNumber() * 2 * math.pi
	local maxRadius = math.max(TruckEvent.ScatterRadius, 0)
	local minRadius = math.clamp(TruckEvent.ScatterMinRadius, 0, maxRadius)
	local gap = math.max(TruckEvent.BoxGap, 0)
	local best: Vector3? = nil
	local bestRoom = -math.huge
	local function try(point: Vector3): boolean
		local room = clearance(point, width, taken)
		if room > bestRoom then
			best, bestRoom = point, room
		end
		return room >= gap
	end
	local spreads = { TruckEvent.ScatterSpread, math.max(TruckEvent.ScatterSpread, math.pi / 2), math.pi }
	local found: Vector3? = nil
	for _, spread in spreads do
		for _ = 1, LANDING_TRIES do
			local point = scatterPoint(center, base, spread, minRadius, maxRadius)
			if try(point) then
				found = point
				break
			end
		end
		if found then
			break
		end
	end
	if found == nil then
		local radius = maxRadius
		while found == nil and radius <= maxRadius + LANDING_EXTRA_RADIUS do
			radius += 1
			local steps = math.max(8, math.ceil(2 * math.pi * radius / math.max(width + gap, 0.5)))
			for step = 0, steps - 1 do
				local angle = base + (if step % 2 == 0 then 1 else -1) * math.ceil(step / 2) * 2 * math.pi / steps
				local point = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
				if try(point) then
					found = point
					break
				end
			end
		end
	end
	local target = found or best or scatterPoint(center, base, TruckEvent.ScatterSpread, minRadius, maxRadius)
	return Vector3.new(target.X, groundY(target, center.Y), target.Z)
end

-- Camion ------------------------------------------------------------------------------------------

-- Retire le camion sans rien lâcher. `message` : Notify à tous, aucun si nil.
local function removeTruck(truck: Truck, message: string?)
	if current ~= truck then
		return
	end
	current = nil
	WindowService.RemoveTarget(truck.WindowId)
	truck.Model:Destroy()
	if message then
		notifyAll(message, "Info")
	end
end

local function spawnTruck(zone: number): boolean
	local template = findTemplate()
	if template == nil then
		warnOnce(
			"template",
			`{TRUCK_ASSET} introuvable dans ReplicatedStorage/{ASSETS_NAME} (ni ServerStorage/{ASSETS_NAME}) : pas de camion`
		)
		return false
	end
	local frame = spawnFrame(zone)
	if frame == nil then
		warnOnce(`frame.{zone}`, `zone {zone} : ni point {TRUCK_SPAWN_TAG}, ni magasin, ni arche dans la map : pas de camion`)
		return false
	end
	local model = template:Clone() :: Model? -- nil si le modèle n'est pas Archivable
	if model == nil then
		warnOnce("archivable", `{template:GetFullName()} n'est pas Archivable : pas de camion`)
		return false
	end
	local drivers = driversOf(model)
	local free: { [BasePart]: boolean } = {}
	for _, driver in drivers do
		for part in animatedParts(driver) do
			free[part] = true
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy() -- jamais de script dans un modèle (CLAUDE.md)
		elseif descendant:IsA("BasePart") then
			-- Livré ancré ; il ne doit pas tomber en morceaux avant l'explosion. Seuls les membres d'un
			-- conducteur animé restent libres, tenus par ses articulations à sa racine ancrée.
			descendant.Anchored = not free[descendant :: BasePart]
		end
	end
	truckCount += 1
	model.Name = TRUCK_NAME
	model:SetAttribute(ZONE_ATTRIBUTE, zone)
	model:SetAttribute(NUMBER_ATTRIBUTE, truckCount)
	-- Vague 26 (a81) : heure serveur de l'apparition, pour les sons d'arrivée de TruckController (seuls
	-- ceux qui voient le camion arriver les entendent, pas un joueur qui le reçoit plus tard par le streaming).
	model:SetAttribute(SPAWNED_AT_ATTRIBUTE, Workspace:GetServerTimeNow())
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- le camion et ses points arrivent ensemble
	model:PivotTo(frame)
	model.Parent = Workspace
	CollectionService:AddTag(model, TRUCK_TAG)
	playDriverIdles(drivers)
	local windowId = WindowService.AddTarget(model, TruckEvent.MaxHP)
	if windowId == nil then
		model:Destroy()
		return false
	end
	current = {
		Number = truckCount,
		Zone = zone,
		Model = model,
		WindowId = windowId,
		SpawnedAt = os.clock(),
		State = "Active",
	}
	chrono = { Number = truckCount, Zone = zone, Frame = frame, EndsAt = os.clock() + TruckEvent.Lifetime }
	notifyAll(string.format(TruckEvent.Messages.Spawned, zone), "Info")
	local p = frame.Position
	log(
		`camion n° {truckCount} en zone {zone} ({math.round(p.X)}, {math.round(p.Y)}, {math.round(p.Z)}), {TruckEvent.MaxHP} PV, part dans {TruckEvent.Lifetime} s`
	)
	return true
end

local function explode(truck: Truck, impactPoint: Vector3?, breaker: Player?)
	if current ~= truck or truck.State ~= "Active" then
		return
	end
	truck.State = "Exploding"
	local model = truck.Model
	local center = model:GetPivot().Position
	local blast = Find.path(model, BLAST_POINT)
	local blastPosition: Vector3 = if blast and blast:IsA("Attachment")
		then (blast :: Attachment).WorldPosition
		else impactPoint or center + Vector3.new(0, 5, 0)
	-- Les pièces volent côté client : la copie du serveur ne bloque plus rien ni personne.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	local outline = model:FindFirstChild(OUTLINE_NAME, true)
	if outline and outline:IsA("Highlight") then
		(outline :: Highlight).Enabled = false
	end
	local serverNow = Workspace:GetServerTimeNow()
	model:SetAttribute(EXPLODED_AT_ATTRIBUTE, serverNow)

	local storeId = `Truck_{truck.Number}`
	local placed = 0
	local byTier: { [string]: number } = {}
	local widths: { [string]: number } = {}
	-- Les colis déjà au sol (camion précédent, coup de batte) comptent aussi : rien ne tombe dessus.
	local taken: { Landing } = {}
	local drops = Workspace:FindFirstChild(DROPS_FOLDER)
	if drops then
		for _, drop in drops:GetChildren() do
			if drop:IsA("Model") and drop:FindFirstChildWhichIsA("BasePart", true) then
				local frame, size = (drop :: Model):GetBoundingBox()
				table.insert(taken, { Position = frame.Position, Width = math.max(size.X, size.Z) })
			end
		end
	end
	for index, tier in boxTiers() do
		local spawnPoint = Find.path(model, string.format(BOX_SPAWN_FORMAT, index))
		local from: Vector3 = if spawnPoint and spawnPoint:IsA("Attachment")
			then (spawnPoint :: Attachment).WorldPosition
			else blastPosition
		local rarity, itemId = drawContent(tier, truck.Zone)
		if rarity == nil or itemId == nil then
			warnOnce(`draw.{tier}.{truck.Zone}`, `aucun objet ne peut sortir d'un colis {tier} en zone {truck.Zone} : colis du camion sauté`)
			continue
		end
		local payload: CarryTypes.NPCBoxPayload = {
			Kind = "NPCBox",
			Tier = tier :: CarryTypes.BoxTier,
			Zone = truck.Zone,
			Rarity = rarity,
			ItemId = itemId,
			StoreId = storeId,
			SlotId = `{storeId}/{string.format("%02d", index)}`,
			-- DEV-131 (L-084) : mêmes règles que la mise en rayon, jamais pour un objet TutorialOnly.
			Mutation = if Items.ById[itemId].TutorialOnly then nil else Mutations.Roll(random),
		}
		local launch = (index - 1) * TruckEvent.LaunchStagger
		local landsIn = launch + TruckEvent.FlightTime
		local attributes: { [string]: any } = {
			[TRUCK_BOX_ATTRIBUTE] = true,
			[TIER_ATTRIBUTE] = tier,
			[FLIGHT_FROM_ATTRIBUTE] = from,
			[FLIGHT_STARTS_AT_ATTRIBUTE] = serverNow + launch,
			[FLIGHT_DURATION_ATTRIBUTE] = TruckEvent.FlightTime,
		}
		local width = widths[tier] or boxWidth(tier)
		widths[tier] = width
		local landing = landingPoint(from, center, width, taken)
		local dropId = CarryService.PlaceDrop(payload, landing, landsIn + TruckEvent.BoxLifetime, attributes)
		if dropId then
			table.insert(taken, { Position = landing, Width = width })
			boxes[dropId] = { DropId = dropId, Tier = tier, LandsAt = os.clock() + landsIn }
			placed += 1
			byTier[tier] = (byTier[tier] or 0) + 1
		end
	end
	notifyAll(TruckEvent.Messages.Exploded, "Info")
	local parts: { string } = {}
	for _, tier in Balance.Heist.TierOrder do
		table.insert(parts, `{byTier[tier] or 0} {tier}`)
	end
	log(
		`camion n° {truck.Number} cassé{if breaker then " par " .. breaker.Name else ""} : explosion, {placed} colis lâchés ({table.concat(parts, ", ")}), zone {truck.Zone}`
	)
	task.delay(TruckEvent.RemoveDelay, function()
		if current == truck then
			current = nil
		end
		if model.Parent ~= nil then
			model:Destroy()
		end
	end)
end

-- Poursuite des conducteurs (point 3') ------------------------------------------------------------------

-- GuardService, chargé au premier besoin et protégé : il n'est pas dans tous les arbres de test.
local guardApi: GuardApi? = nil
local function loadGuardService(): GuardApi?
	if guardApi then
		return guardApi
	end
	local ok, result = pcall(function(): any
		return require(script.Parent.GuardService) :: any
	end)
	if ok and type(result) == "table" and type(result.StartDriverChase) == "function" then
		guardApi = result :: GuardApi
		return guardApi
	end
	warnOnce("guardservice", `GuardService indisponible ({if ok then "sans StartDriverChase" else result}) : pas de poursuite des conducteurs`)
	return nil
end

-- `player` porte-t-il un colis du camion `storeId` (« Truck_<n> ») ?
local function carriesBoxOf(player: Player, storeId: string): boolean
	local payload = CarryService.GetPayload(player)
	if payload == nil or payload.Kind ~= "NPCBox" then
		return false
	end
	return (payload :: CarryTypes.NPCBoxPayload).StoreId == storeId
end

-- Les conducteurs du modèle de Clément, par ordre de nom (TruckDriver_01, _02…).
local function driverTemplates(): { Model }
	local template = findTemplate()
	local list: { Model } = {}
	if template then
		for _, driver in driversOf(template) do
			table.insert(list, driver.Rig)
		end
	end
	table.sort(list, function(a: Model, b: Model): boolean
		return a.Name < b.Name
	end)
	return list
end

-- Fin du chrono `c` : les conducteurs poursuivent les porteurs d'un colis de ce camion.
local function launchDrivers(c: Chrono, why: string)
	local storeId = `Truck_{c.Number}`
	type Candidate = { Player: Player, Distance: number }
	local candidates: { Candidate } = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and carriesBoxOf(player, storeId) and not inSafeZone(root.Position) then
			table.insert(candidates, { Player = player, Distance = flat(root.Position - c.Frame.Position).Magnitude })
		end
	end
	if #candidates == 0 then
		log(`camion n° {c.Number} : fin du chrono ({why}), aucun porteur de ses colis hors zone safe, pas de conducteur`)
		return
	end
	table.sort(candidates, function(a: Candidate, b: Candidate): boolean
		return a.Distance < b.Distance
	end)
	local templates = driverTemplates()
	local count = math.min(#candidates, #templates, math.max(math.floor(TruckEvent.DriverChaseMax), 0))
	if count == 0 then
		warnOnce("nodriver", `aucun conducteur (Model avec un Humanoid) dans {TRUCK_ASSET} : pas de poursuite à la fin du chrono`)
		return
	end
	local guards = loadGuardService()
	if guards == nil then
		return
	end
	local frame = c.Frame
	local launched = 0
	for index = 1, count do
		local player = candidates[index].Player
		local side = (index - (count + 1) / 2) * TruckEvent.DriverSpawnSpacing
		local point = frame.Position + frame.RightVector * side
		-- Tourné vers sa cible par GuardService.
		local spawnAt = CFrame.new(point.X, groundY(point, frame.Position.Y), point.Z)
		local model = guards.StartDriverChase({
			Template = templates[index],
			Name = `{templates[index].Name}_T{c.Number}`,
			Target = player,
			Spawn = spawnAt,
			Zone = c.Zone,
			SpeedMultiplier = TruckEvent.DriverSpeedMultiplier,
			MinSpeed = TruckEvent.DriverMinSpeed,
			Keeps = function(target: Player): boolean
				return carriesBoxOf(target, storeId)
			end,
			CaughtMessage = TruckEvent.Messages.DriverCaught,
		})
		if model then
			launched += 1
			Net.Server.Notify:Fire(player, TruckEvent.Messages.DriversChase, "Warning")
		end
	end
	log(`camion n° {c.Number} : fin du chrono ({why}), {launched} conducteur(s) lancé(s) sur {#candidates} porteur(s)`)
end

-- Fin du chrono `c` (point 3') : le camion part s'il n'a pas explosé, puis les conducteurs.
local function endChrono(c: Chrono, why: string, leftMessage: string)
	if chrono ~= c then
		return
	end
	chrono = nil
	local truck = current
	if truck and truck.Number == c.Number and truck.State == "Active" then
		log(`camion n° {truck.Number} pas cassé ({why}) : il part`)
		removeTruck(truck, leftMessage)
	end
	launchDrivers(c, why)
end

-- Colis du camion au sol ------------------------------------------------------------------------------

local function grabTimeOf(tier: string): number
	local info = Balance.Heist.BoxTiers[tier]
	return if info then info.GrabTime else 0
end

-- Raison du refus d'une prise de `box` par `player`, ou nil si elle est permise maintenant.
local function grabRefusal(player: Player, box: TruckBox): string?
	if os.clock() + LANDING_TOLERANCE < box.LandsAt then
		return "colis encore en vol"
	end
	local payload, position = CarryService.GetDrop(box.DropId)
	if payload == nil or position == nil then
		return "colis plus au sol"
	end
	if CarryService.IsCarrying(player) then
		return "mains pleines"
	end
	local root = rootOf(player)
	if root == nil then
		return "pas de personnage vivant"
	end
	if inSafeZone(root.Position) then
		return "en zone safe"
	end
	local distance = (root.Position - position).Magnitude
	if distance > Bat.DroppedGrabMaxDistance then
		return `trop loin ({math.round(distance * 10) / 10} studs)`
	end
	return nil
end

local function grant(player: Player, box: TruckBox)
	if not CarryService.PickUpDrop(player, box.DropId) then
		refuse(player, box.DropId, "CarryService a refusé le ramassage")
		return
	end
	boxes[box.DropId] = nil
	log(`{player.Name} ramasse le colis {box.Tier} {box.DropId} du camion`)
end

-- GrabDropped(dropId) : premier appel = début du maintien, second = fin (comme GrabItem).
local function onGrabDropped(player: Player, dropId: string)
	local box = boxes[dropId]
	if box == nil then
		return -- pas un colis du camion : laissé au service qui l'a posé (batte, DEV-048)
	end
	local hold = holds[player]
	local reason = grabRefusal(player, box)
	if reason then
		if hold and hold.DropId == dropId then
			holds[player] = nil
		end
		refuse(player, dropId, reason)
		return
	end
	local required = grabTimeOf(box.Tier)
	local now = os.clock()
	if hold and hold.DropId == dropId then
		local elapsed = now - hold.StartedAt
		if elapsed + GRAB_TIME_TOLERANCE >= required then
			holds[player] = nil
			grant(player, box)
		else
			refuse(player, dropId, `maintien trop court ({math.round(elapsed * 100) / 100} s sur {required} s)`)
		end
		return
	end
	if required <= 0 then
		holds[player] = nil
		grant(player, box)
		return
	end
	holds[player] = { DropId = dropId, StartedAt = now }
end

local function onDropExpired(dropId: string, _payload: any)
	if boxes[dropId] then
		boxes[dropId] = nil
		log(`colis du camion {dropId} jamais ramassé : disparu`)
	end
end

-- Horaire ---------------------------------------------------------------------------------------------

local function randomInterval(): number
	local low = math.max(TruckEvent.SpawnIntervalMin, 0)
	local high = math.max(TruckEvent.SpawnIntervalMax, low)
	return low + random:NextNumber() * (high - low)
end

-- De jour, assez loin de l'aube et de l'alerte (voir l'en-tête). Cycle coupé : toujours le jour.
local function daySpawnAllowed(): boolean
	if not Features.NightCycle then
		return true
	end
	if NightCycleService.GetPhase() ~= "Day" then
		return false
	end
	if NightCycleService.GetPhaseEndsAt() - Workspace:GetServerTimeNow() < TruckEvent.MinDayLeft then
		return false
	end
	return os.clock() - dayStartedAt >= TruckEvent.DawnDelay
end

local function randomZone(): number?
	local list = TruckEvent.SpawnZones
	if #list == 0 then
		return nil
	end
	return list[random:NextInteger(1, #list)]
end

local function step()
	local now = os.clock()
	for player, hold in holds do
		local box = boxes[hold.DropId]
		if box == nil or now - hold.StartedAt > grabTimeOf(box.Tier) + HOLD_EXPIRY or grabRefusal(player, box) ~= nil then
			holds[player] = nil
		end
	end
	local running = chrono
	if running and now >= running.EndsAt then
		endChrono(running, `{TruckEvent.Lifetime} s`, TruckEvent.Messages.Left)
	end
	local truck = current
	if truck then
		if truck.Model.Parent == nil then
			current = nil -- retiré par quelqu'un d'autre
		end
		return
	end
	if now < nextSpawnAt or not daySpawnAllowed() then
		return
	end
	nextSpawnAt = now + randomInterval()
	local zone = randomZone()
	if zone then
		spawnTruck(zone)
	end
end

local function onPhaseChanged(phase: string, previous: string)
	if phase == "Day" and previous == "Night" then
		dayStartedAt = os.clock()
		return
	end
	-- L'alerte (ou la nuit) arrête le chrono : le camion part s'il n'a pas explosé, les conducteurs
	-- poursuivent les porteurs de ses colis.
	local running = chrono
	if (phase == "Warning" or phase == "Night") and running then
		endChrono(running, phase, TruckEvent.Messages.LeftNight)
	end
end

local function onBroken(info: WindowService.BreakInfo)
	local truck = current
	if info.Kind ~= "Event" or truck == nil or info.Model ~= truck.Model then
		return
	end
	explode(truck, info.ImpactPoint, info.Breaker)
end

-- Crochet de test (Studio seulement) ------------------------------------------------------------------

local function onSkip()
	local value = Workspace:GetAttribute(SKIP_ATTRIBUTE)
	if value == nil or value == "" then
		return
	end
	Workspace:SetAttribute(SKIP_ATTRIBUTE, nil)
	local word = if type(value) == "string" then string.lower((string.gsub(value, "%s", ""))) else nil
	local truck = current
	if word == "explode" then
		if truck == nil or truck.State ~= "Active" then
			warn(`[TruckEventService] {SKIP_ATTRIBUTE} = {value} : aucun camion en jeu`)
		else
			WindowService.RemoveTarget(truck.WindowId) -- plus aucun coup pendant l'explosion
			explode(truck, nil, nil)
		end
		return
	end
	if word == "leave" or word == "chase" then
		-- Leave : seulement un camion pas encore cassé (comme avant) ; Chase : même après l'explosion.
		local running = chrono
		if word == "leave" and (truck == nil or truck.State ~= "Active") then
			warn(`[TruckEventService] {SKIP_ATTRIBUTE} = {value} : aucun camion en jeu (après l'explosion : "Chase")`)
		elseif running == nil then
			warn(`[TruckEventService] {SKIP_ATTRIBUTE} = {value} : aucun chrono de camion en cours`)
		else
			endChrono(running, `{SKIP_ATTRIBUTE} = {value}`, TruckEvent.Messages.Left)
		end
		return
	end
	local zone = if type(value) == "number" then value elseif word then tonumber(word) else nil
	if zone == nil or zone ~= math.floor(zone) or Zones[zone] == nil then
		warn(`[TruckEventService] {SKIP_ATTRIBUTE} = {value} : attendu une zone de 1 à {#Zones}, "Explode", "Leave" ou "Chase"`)
		return
	end
	if truck then
		removeTruck(truck, nil)
	end
	chrono = nil -- remplacé sans message : pas de poursuite pour l'ancien camion
	spawnTruck(zone)
end

-- Démarrage -----------------------------------------------------------------------------------------

function TruckEventService.Init()
	if not ENABLED then
		return
	end
	WindowService.OnBroken(onBroken)
	NightCycleService.OnPhaseChanged(onPhaseChanged)
	CarryService.OnDropExpired(onDropExpired)
	Net.Server.GrabDropped:Connect(onGrabDropped)
	Players.PlayerRemoving:Connect(function(player: Player)
		holds[player] = nil
		lastRefusal[player] = nil
	end)
end

function TruckEventService.Start()
	if not ENABLED then
		print("[TruckEventService] événement camion coupé (Features.TruckEvent = false) : aucun camion")
		return
	end
	nextSpawnAt = os.clock() + randomInterval()
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(SKIP_ATTRIBUTE):Connect(onSkip)
	end
	local delivered = if findTemplate() then TRUCK_ASSET else `{TRUCK_ASSET} pas encore rangé dans Assets, aucun camion`
	print(
		`[TruckEventService] événement camion : un camion toutes les {TruckEvent.SpawnIntervalMin} à {TruckEvent.SpawnIntervalMax} s, de jour ; {delivered}`
	)
	while true do
		task.wait(TICK)
		xpcall(step, function(err: any)
			warn(`[TruckEventService] tick : {err}\n{debug.traceback()}`)
		end)
	end
end

return TruckEventService
