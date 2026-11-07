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
--   2. PV partagés : cible d'événement de WindowService (AddTarget, MaxHP, sans régénération),
--      frappée avec les outils et les règles des vitrines (HitController, HitWindow : dégâts du
--      joueur, portée, débit, coup au marqueur Impact). Ses PV : attribut HP du camion.
--   3. Départ sans rien lâcher, avec un Notify : pas cassé au bout de Lifetime s, ou dès que l'alerte
--      de la nuit commence (ou la nuit, si on y saute).
--   4. À 0 PV (WindowService.OnBroken, Kind « Event ») : explosion.
--      - Le serveur coupe collisions, contacts et requêtes de toutes les pièces du camion, éteint son
--        contour et pose ExplodedAt (heure serveur) : TruckController fait voler les pièces
--        Pieces/Piece_xx depuis BlastPoint puis les efface (effet seulement, côté client : rien de ce
--        qui compte n'en dépend). La copie est retirée RemoveDelay s plus tard.
--      - Colis : Boxes (12 : 6 Standard, 4 Premium, 2 Luxe), types répartis au hasard sur
--        BoxSpawn_01 à _12 (BlastPoint pour un point qui manque). Contenu tiré comme sur un rayon de
--        la zone du camion : rareté selon ShelfBoxes.OddsFor (zone 1 : Communs seulement, L-033),
--        objet par Items.Pick, repli sur la rareté tirable la plus proche en dessous (comme
--        StoreHeistService). Chaque colis est posé tout de suite à son point d'arrivée
--        (CarryService.PlaceDrop), au sol, de ScatterMinRadius à ScatterRadius studs du centre du
--        camion, du côté de son point de sortie (ScatterSpread). Le client le fait voler depuis son
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
--       workspace:SetAttribute("TruckSpawnNow", "Leave")    -- le camion présent part tout de suite
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
local Rarities = require(Shared.Config.Rarities)
local ShelfBoxes = require(Shared.Config.ShelfBoxes)
local TruckEvent = require(Shared.Config.TruckEvent)
local Zones = require(Shared.Config.Zones)
local Find = require(Shared.Contract.Find)
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

-- Colis du camion au sol (ou en vol vers le sol).
type TruckBox = {
	DropId: string,
	Tier: string,
	LandsAt: number, -- os.clock() de l'atterrissage
}

type Hold = { DropId: string, StartedAt: number }

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

local IS_STUDIO = RunService:IsStudio()
local ENABLED: boolean = Features.TruckEvent

local TruckEventService = {}
TruckEventService.Priority = PRIORITY

local current: Truck? = nil
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

-- Point d'arrivée au sol d'un colis sorti en `from` d'un camion centré en `center` (voir l'en-tête).
local function landingPoint(from: Vector3, center: Vector3): Vector3
	local out = flat(from - center)
	local base = if out.Magnitude > 1e-3 then math.atan2(out.Z, out.X) else random:NextNumber() * 2 * math.pi
	local angle = base + (random:NextNumber() * 2 - 1) * TruckEvent.ScatterSpread
	local maxRadius = math.max(TruckEvent.ScatterRadius, 0)
	local minRadius = math.clamp(TruckEvent.ScatterMinRadius, 0, maxRadius)
	local radius = minRadius + random:NextNumber() * (maxRadius - minRadius)
	local target = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
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
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy() -- jamais de script dans un modèle (CLAUDE.md)
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true -- livré ancré ; il ne doit pas tomber en morceaux avant l'explosion
		end
	end
	truckCount += 1
	model.Name = TRUCK_NAME
	model:SetAttribute(ZONE_ATTRIBUTE, zone)
	model:SetAttribute(NUMBER_ATTRIBUTE, truckCount)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- le camion et ses points arrivent ensemble
	model:PivotTo(frame)
	model.Parent = Workspace
	CollectionService:AddTag(model, TRUCK_TAG)
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
		local dropId = CarryService.PlaceDrop(payload, landingPoint(from, center), landsIn + TruckEvent.BoxLifetime, attributes)
		if dropId then
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
	local truck = current
	if truck then
		if truck.Model.Parent == nil then
			current = nil -- retiré par quelqu'un d'autre
		elseif truck.State == "Active" and now - truck.SpawnedAt >= TruckEvent.Lifetime then
			log(`camion n° {truck.Number} pas cassé en {TruckEvent.Lifetime} s : il part`)
			removeTruck(truck, TruckEvent.Messages.Left)
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
	local truck = current
	if (phase == "Warning" or phase == "Night") and truck and truck.State == "Active" then
		log(`camion n° {truck.Number} : {phase}, il part`)
		removeTruck(truck, TruckEvent.Messages.LeftNight)
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
	if word == "explode" or word == "leave" then
		if truck == nil or truck.State ~= "Active" then
			warn(`[TruckEventService] {SKIP_ATTRIBUTE} = {value} : aucun camion en jeu`)
		elseif word == "explode" then
			WindowService.RemoveTarget(truck.WindowId) -- plus aucun coup pendant l'explosion
			explode(truck, nil, nil)
		else
			removeTruck(truck, TruckEvent.Messages.Left)
		end
		return
	end
	local zone = if type(value) == "number" then value elseif word then tonumber(word) else nil
	if zone == nil or zone ~= math.floor(zone) or Zones[zone] == nil then
		warn(`[TruckEventService] {SKIP_ATTRIBUTE} = {value} : attendu une zone de 1 à {#Zones}, "Explode" ou "Leave"`)
		return
	end
	if truck then
		removeTruck(truck, nil)
	end
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
