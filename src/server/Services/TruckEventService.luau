--!strict
-- TruckEventService (liaison L-049, décision de Clément du 2026-11-07 ; pas encore une tâche du
-- backlog) : l'événement camion. Valeurs : Config/TruckEvent ; interrupteur : Config/Features.TruckEvent.
--
-- Un seul camion à la fois :
--   1. Apparition, SpawnIntervalMin à SpawnIntervalMax s (tiré au hasard) après l'apparition
--      précédente (ou le démarrage du serveur), seulement de jour : phase Day de NightCycleService,
--      au moins DawnDelay s après l'aube et MinDayLeft s avant l'alerte. Un camion dû pendant
--      l'alerte ou la nuit attend que ces conditions reviennent. Zone tirée au hasard dans SpawnZones.
--      Vague 39 : pas de camion tant qu'une vitrine de la Fortune Tower est en jeu (tag FortuneVault posé
--      par FortuneTowerService, fermée ou ouverte) ; le camion dû attend qu'elle soit retirée.
--      a425 (L-318 Q1) : de même tant que ArmoredVanService.HoldsTruck() (fourgon blindé en jeu ou en attente, juste
--      après lui, ou départ à l'horaire proche) : jamais les deux véhicules en même temps.
--      Où :
--        - sur un point taggé `TruckSpawn` (Attachment, pièce ou Model, attribut Zone ; posé par
--          Clément, Contract/Tags) s'il y en a dans la zone, au hasard : le pivot du camion (en bas au
--          centre) va sur le point, l'avant (−Z) du camion suit celui du point ;
--        - sinon calculé : au milieu des deux magasins PNJ de la zone (ils se font face de part et
--          d'autre de la chaussée), c'est-à-dire au milieu de la chaussée, en long dans le sens du
--          couloir (de l'arche ZoneGate de la plus petite zone vers celle de la plus grande). Le
--          camion fait 12,6 studs de large : il laisse 24 studs devant chaque vitrine de la carte
--          actuelle. Un seul magasin dans la zone : à sa hauteur, sur la ligne des arches ; aucun :
--          au milieu de la zone, sur la ligne des arches. Sol trouvé par un rayon.
--      Chargement tiré dès l'apparition (a79, L-097 point 3 ; avant : à l'explosion, mêmes chances) :
--      types et contenus des colis du point 4. Le camion = une copie de ENV_Event_Truck_<Rareté>, la
--      rareté la plus haute de ce chargement (Clément, ReplicatedStorage/Assets, sinon ServerStorage/Assets),
--      si elle est rangée et a Root, Pieces, BlastPoint et HealthBarPoint ; sinon ENV_Event_Truck (ligne
--      dans la sortie). Un camion par rareté sans conducteur reçoit une copie de ceux d'ENV_Event_Truck,
--      à la même place par rapport à Root. La copie est vidée de tout script, toutes pièces ancrées, nommée EventTruck, tag
--      EventTruck (posé par le code), attributs Zone et TruckNumber. Son contour OutlineHighlight
--      vient du modèle ; sa barre de vie (copie de BB_WindowHP à HealthBarPoint) est posée par
--      TruckController, côté client. Notify à tous.
--      Conducteurs (liaison L-071, point 7) : chaque Model du camion qui a un Humanoid. S'il a une
--      animation Idle dans son dossier Animations (Contract/Animations.Driver), ce service la joue en
--      boucle (Animator du Humanoid, créé s'il manque ; réplication aux clients) ; pour qu'il bouge,
--      seule sa racine (RootPart, HumanoidRootPart ou PrimaryPart) est ancrée, ses membres reliés à
--      elle par ses articulations restent libres. Sans Idle, il est ancré comme le reste et immobile.
--      À l'explosion, TruckController le fait voler avec les pièces.
--      Arrivée en roulant (a97, vague 29, L-105 point 2) : le camion est posé tout de suite à sa place
--      finale (PV, coups, chrono et colis ne changent pas), mais chaque client qui le voit arriver joue
--      une copie locale qui roule depuis ArriveDistance studs, dérape, se couche sur le côté et éjecte les
--      conducteurs (TruckController). Le serveur pose ArriveUpright (pose debout par rapport au pivot,
--      CFrame) et ArriveEndsAt (heure serveur de l'impact au sol), coupe collisions et contacts de toutes
--      les pièces jusqu'à la fin du rebond, puis les remet et sort par le côté le plus proche un joueur
--      resté dans la caisse. Pose livrée : ArriveDeliveredPose ("Auto" : couché si ses conducteurs le
--      sont, sinon si Pieces est plus large que haut) ; un camion livré debout est couché à sa place
--      (toutes les pièces sauf Root, qui reste debout ; HealthBarPoint au-dessus de la caisse couchée).
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
--        BoxSpawn_01 à _12 (BlastPoint pour un point qui manque), tirés à l'apparition : rareté selon
--        ShelfBoxes.OddsFor de la zone du camion (zone 1 : Communs seulement, L-033), sans les raretés qui
--        finissaient en colis vide, ramenée à 100 (truckOdds, a295), repli sur la rareté tirable la plus proche en
--        dessous (comme StoreHeistService). a440 (Features.ZoneBoxEverywhere) : la rareté voulue est celle d'un colis
--        de zone (règle Config/Rewards.TierZoneBox du type, zone de référence = celle du camion ; zoneBoxPick), sans
--        Rarities.BoxOdds ni Balance.Heist.BoxTiers ; même repli vers le bas. Chaque colis a son point d'arrivée au
--        sol, de ScatterMinRadius à ScatterRadius studs du centre du camion, du côté de son point de sortie
--        (ScatterSpread), et jamais sur un autre : au moins BoxGap studs bord à bord entre deux colis, d'après
--        la largeur des modèles BOX_<Rareté>, sinon BOX_<Tier> (cône élargi, puis cercles plus grands si la
--        place manque : voir landingPoint).
--      - Notify à tous.
--   4'. Vague 42 (a148, demande de Cantin du 2026-11-14) : les colis vont sur un rayon d'événement de
--      StoreHeistService (AddEventShelf, StoreId « Truck_<n> », un ShelfSlot par point d'arrivée ci-dessus),
--      chacun en vol (serveur) de son BoxSpawn à son point ; la rareté tirée au chargement est celle de la
--      CAISSE (le modèle du camion en dépend toujours), minimum de l'objet (la chance ne fait que monter) ; on
--      l'ouvre sur place comme sur un rayon (maintien GrabTime, chance tirée par le serveur, objet, mutation et
--      taille tirés à la sortie, Mutations.Roll : pas de taille garantie), puis on prend l'objet (GrabItem,
--      portage NPCItem). Ni témoins, ni vigile ; les conducteurs (point 3') poursuivent qui porte un objet de
--      ce camion. Pas ouverte : la caisse disparaît FlightTime + BoxLifetime s après l'explosion.
--   5. Vague 50 (a158, décision de Cantin du 2026-11-14 : le colis porté n'existe plus) : plus aucun colis du
--      camion posé au sol pour être pris fermé (CarryService.PlaceDrop, GrabDropped, portage NPCBox retirés).
--      Sans rayon d'événement (StoreHeistService absent d'un banc, AddEventShelf refusé) : le camion explose
--      sans colis (avertissement si AddEventShelf refuse ; une ligne en Studio si le service manque).
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
-- API (serveur) : TruckEventService.LandingPoint et BoxWidth (a516, voir la fin du fichier). Posé par ce service, lu par TruckController : le tag EventTruck et les
-- attributs du camion (Zone, TruckNumber, SpawnedAt, ArriveUpright, ArriveEndsAt, ExplodedAt, LeftAt ; WindowId, MaxHP, HP et Broken venant de
-- WindowService), les attributs des colis du camion (plus haut).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)

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

local CarryService = require(script.Parent.CarryService)
local NightCycleService = require(script.Parent.NightCycleService)
local WindowService = require(script.Parent.WindowService)

-- a440 (Features.ZoneBoxEverywhere) : chargé s'il est là ; absent (faux arbres des bancs plus anciens) : coupé.
local ZoneBoxEverywhere: any = (function(): any
	local ok, result = pcall(function(): any
		return require(Shared.ZoneBoxEverywhere)
	end)
	return if ok and type(result) == "table" then result else nil
end)()

type TruckState = "Active" | "Exploding"

-- Collisions d'une pièce du camion, coupées pendant l'arrivée (a97), remises à la fin.
type SavedCollision = { CanCollide: boolean, CanTouch: boolean }

-- Un colis du chargement, tiré à l'apparition du camion (a79, L-097 point 3). Rarity et ItemId nil :
-- aucun objet ne peut sortir de ce colis dans la zone (Config incohérente), colis sauté à l'explosion.
-- a440 : Rule = règle de colis de zone du colis (Features.ZoneBoxEverywhere ; nil : coupé, rareté par le type Tier).
type Load = { Tier: string, Rule: string?, Rarity: string?, ItemId: string?, Mutation: Mutations.Mutation? }

type Truck = {
	Number: number, -- 1, 2, 3… depuis le démarrage du serveur
	Zone: number,
	Model: Model,
	WindowId: string,
	SpawnedAt: number, -- os.clock()
	State: TruckState,
	Load: { Load }, -- le n-ième sort de BoxSpawn_n
	Arriving: { [BasePart]: SavedCollision }?, -- pendant l'arrivée (a97) : collisions à remettre
}

-- Chrono d'un camion (point 3') : survit à l'explosion et au retrait de la copie.
type Chrono = {
	Number: number,
	Zone: number,
	Frame: CFrame, -- pivot du camion (en bas au centre) : où réapparaissent les conducteurs
	EndsAt: number, -- os.clock()
	Asset: string, -- modèle de Clément copié (ENV_Event_Truck_<Rareté> ou ENV_Event_Truck) : ses conducteurs
}

-- Ce que ce service utilise de GuardService (chargé à la fin du chrono, voir loadGuardService).
type GuardApi = { StartDriverChase: (chase: any) -> Model? }


-- Point d'arrivée d'un colis déjà posé à l'explosion, et sa largeur au sol.
type Landing = { Position: Vector3, Width: number }

-- Noms du contrat lus ici (L-049, Contract/Models ; tags et attribut : 2.1).
local TRUCK_ASSET = "ENV_Event_Truck"
-- Camion à la rareté la plus haute de son chargement (a79, L-097 point 3), sinon TRUCK_ASSET.
local TRUCK_RARITY_FORMAT = "ENV_Event_Truck_%s"
local ROOT_NAME = "Root"
local PIECES_NAME = "Pieces"
local HEALTH_BAR_POINT = "HealthBarPoint"
local BLAST_POINT = "BlastPoint"
local BOX_SPAWN_FORMAT = "BoxSpawn_%02d"
local OUTLINE_NAME = "OutlineHighlight"
local ASSETS_NAME = "Assets"
local ZONE_GATE_TAG = "ZoneGate"
local STORE_TAG = "NPCStore"
local SAFE_ZONE_TAG = "SafeZone"
local BOUNDS_NAME = "Bounds"
local ZONE_ATTRIBUTE = "Zone"
-- Points d'apparition du camion, posés par Clément (Contract/Tags, attribut Zone ; a436).
local TRUCK_SPAWN_TAG = "TruckSpawn"
local DROPS_FOLDER = "CarryDrops" -- dossier des colis au sol de CarryService

-- Posés par ce service, lus par TruckController (mêmes noms là-bas).
local TRUCK_NAME = "EventTruck" -- jamais « ENV_… » dans la map : c'est le nom de l'asset (ContractChecker)
local TRUCK_TAG = "EventTruck" -- tag posé par le code, hors du contrat de la section 2.1
local FORTUNE_VAULT_TAG = "FortuneVault" -- vitrine en jeu, posé par FortuneTowerService (vague 39)
local NUMBER_ATTRIBUTE = "TruckNumber"
local SPAWNED_AT_ATTRIBUTE = "SpawnedAt" -- heure serveur de l'apparition (sons d'arrivée, vague 26)
local EXPLODED_AT_ATTRIBUTE = "ExplodedAt"
-- Vague 26 (Config/Vfx.TruckDust, VfxController) : heure serveur de l'apparition et du retrait du camion
-- (poussière à l'arrivée et au départ ; un retrait après l'explosion porte aussi ExplodedAt : pas de poussière).
-- SpawnedAt est déclaré plus haut (même attribut, posé une seule fois).
local LEFT_AT_ATTRIBUTE = "LeftAt"

local SKIP_ATTRIBUTE = "TruckSpawnNow" -- Studio seulement (test), voir l'en-tête
-- Arrivée en roulant (a97, vague 29), lus par TruckController et VfxController (mêmes noms là-bas) :
-- pose debout du camion par rapport à son pivot final (CFrame), et heure serveur de l'impact au sol.
local ARRIVE_UPRIGHT_ATTRIBUTE = "ArriveUpright"
local ARRIVE_ENDS_AT_ATTRIBUTE = "ArriveEndsAt"
-- V0 proposé, absent du doc : un joueur sorti du camion est posé à 3 studs au-dessus du sol (HumanoidRootPart d'un R15).
local PUSH_HEIGHT = 3

-- V0 proposé, absent du doc : après NightCycleService (120), dont il lit les phases.
local PRIORITY = 130
-- V0 proposé, absent du doc : horaire et départ revus 10 fois par seconde.
local TICK = 0.1
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
-- Vague 42 : StoreHeistService (AddEventShelf), chargé dans Init, protégé.
local heistApi: { AddEventShelf: (options: any) -> Model? }? = nil
-- a425 (L-318 Q1) : ArmoredVanService.HoldsTruck, chargé dans Init, protégé : pas de camion pendant le fourgon blindé,
-- ni juste avant ni juste après (règle et valeurs : ArmoredVanService, Config/ArmoredVan). Absent : aucun écart.
local vanApi: { HoldsTruck: () -> boolean }? = nil
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


local function notifyAll(message: string, kind: string)
	Net.Server.Notify:FireAll(message, kind)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- a436 : règle commune « dans la map jouée » (hors des dossiers de travail en « _ »).
local inMap = Find.inMap

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

-- Modèle `name` de Clément (défaut : ENV_Event_Truck), ou nil s'il n'est pas rangé dans Assets.
local function findTemplate(name: string?): Model?
	local wanted = name or TRUCK_ASSET
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild(ASSETS_NAME)
		local found = if assets then assets:FindFirstChild(wanted, true) else nil
		if found and found:IsA("Model") then
			return found :: Model
		end
	end
	return nil
end

-- Pièce Root d'un camion (PrimaryPart chez Clément), ou nil.
local function truckRoot(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	local root = model:FindFirstChild(ROOT_NAME, true)
	return if root and root:IsA("BasePart") then root :: BasePart else nil
end

-- Ce qui manque à un camion par rareté pour TruckEventService et TruckController (Contract/Models.Truck :
-- Root, Pieces, BlastPoint, HealthBarPoint), ou nil s'il est complet. Les BoxSpawn_xx et le contour ont
-- déjà leur repli (BlastPoint, pas de contour), comme pour ENV_Event_Truck.
local function truckProblem(model: Model): string?
	local missing: { string } = {}
	if truckRoot(model) == nil then
		table.insert(missing, ROOT_NAME)
	end
	local pieces = model:FindFirstChild(PIECES_NAME, true)
	if pieces == nil or not pieces:IsA("Model") then
		table.insert(missing, PIECES_NAME)
	end
	for _, name in { BLAST_POINT, HEALTH_BAR_POINT } do
		local point = model:FindFirstChild(name, true)
		if point == nil or not point:IsA("Attachment") then
			table.insert(missing, name)
		end
	end
	return if #missing > 0 then table.concat(missing, ", ") else nil
end

-- Rareté la plus haute du chargement (Rarities.Order), ou nil.
local function topRarity(load: { Load }): string?
	local best: Rarities.Rarity? = nil
	for _, entry in load do
		local rarity = if entry.Rarity then Rarities.ById[entry.Rarity] else nil
		if rarity and (best == nil or rarity.Order > best.Order) then
			best = rarity
		end
	end
	return if best then best.Id else nil
end

-- Modèle du camion pour ce chargement : ENV_Event_Truck_<rareté la plus haute> s'il est rangé et complet,
-- sinon ENV_Event_Truck (ligne dans la sortie). Renvoie aussi son nom.
local function pickTemplate(load: { Load }): (Model?, string)
	local rarity = topRarity(load)
	if rarity then
		local name = string.format(TRUCK_RARITY_FORMAT, rarity)
		local found = findTemplate(name)
		if found == nil then
			-- Facultatif (repli prévu) : une ligne en Studio, pas un avertissement.
			if not warned[`truck.{name}`] then
				warned[`truck.{name}`] = true
				log(`{name} pas rangé dans Assets : camion {TRUCK_ASSET} à la place`)
			end
		else
			local problem = truckProblem(found)
			if problem == nil then
				return found, name
			end
			warnOnce(`truck.{name}.parts`, `{name} : il manque {problem} (Contract/Models) : camion {TRUCK_ASSET} à la place`)
		end
	end
	return findTemplate(), TRUCK_ASSET
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

-- Les camions par rareté de Clément n'ont pas de conducteur (relevé du 2026-11-11) : la copie `model` d'un
-- ENV_Event_Truck_<Rareté> reçoit une copie de ceux d'ENV_Event_Truck, à la même place par rapport à Root
-- (les 9 camions ont leur cabine au même endroit). Renvoie le nombre de conducteurs copiés.
local function borrowDrivers(model: Model): number
	if #driversOf(model) > 0 then
		return 0
	end
	local base = findTemplate()
	local root = truckRoot(model)
	local baseRoot = if base then truckRoot(base) else nil
	if base == nil or root == nil or baseRoot == nil then
		return 0
	end
	local count = 0
	for _, driver in driversOf(base) do
		local copy = driver.Rig:Clone() :: Model?
		if copy then
			copy:PivotTo(root.CFrame * baseRoot.CFrame:ToObjectSpace(driver.Rig:GetPivot()))
			copy.Parent = model
			count += 1
		end
	end
	return count
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

-- Arrivée en roulant (a97, vague 29 ; L-105 point 2) ----------------------------------------------------

-- Temps de l'arrivée depuis l'apparition : jusqu'à l'impact au sol, puis jusqu'à la fin du rebond.
-- (0, 0) : arrivée coupée (ArriveDistance = 0), le camion est là tout de suite, comme avant.
local function arrivalTimes(): (number, number)
	if TruckEvent.ArriveDistance <= 0 then
		return 0, 0
	end
	local landing = math.max(TruckEvent.ArriveDriveTime, 0)
		+ math.max(TruckEvent.ArriveSkidTime, 0)
		+ math.max(TruckEvent.ArriveTipTime, 0)
	return landing, landing + math.max(TruckEvent.ArriveSettleTime, 0)
end

-- Coins des pièces de la caisse (Pieces, sinon tout le camion), hors `skip`, dans l'espace de `pivot`.
local function bodyPoints(model: Model, pivot: CFrame, skip: { [Instance]: boolean }): { Vector3 }
	local points: { Vector3 } = {}
	local pieces = model:FindFirstChild(PIECES_NAME, true)
	local source: Instance = if pieces then pieces else model
	for _, descendant in source:GetDescendants() do
		if descendant:IsA("BasePart") and not skip[descendant] then
			local part = descendant :: BasePart
			local half = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner: Vector3 = part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
						local inPivot: Vector3 = pivot:PointToObjectSpace(corner)
						table.insert(points, inPivot)
					end
				end
			end
		end
	end
	return points
end

-- Rotation qui amène le vecteur unitaire `from` sur `to` (perpendiculaires ici : un quart de tour).
local function rotationTo(from: Vector3, to: Vector3): CFrame
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-6 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(from:Dot(to), -1, 1)))
end

-- Bascule de `from` vers `to` autour de l'arête au sol la plus loin dans la direction horizontale `side`
-- (le camion pivote sur ses roues ou sur son flanc, sans glisser), dans l'espace du pivot.
local function aboutEdge(points: { Vector3 }, side: Vector3, from: Vector3, to: Vector3): CFrame
	local far, low = -math.huge, math.huge
	for _, point in points do
		far = math.max(far, point:Dot(side))
		low = math.min(low, point.Y)
	end
	local edge = side * far + Vector3.new(0, low, 0)
	return CFrame.new(edge) * rotationTo(from, to) * CFrame.new(-edge)
end

-- Pièces à laisser hors de la caisse : Root (invisible, elle reste debout) et les conducteurs.
local function bodySkip(model: Model, drivers: { Driver }): { [Instance]: boolean }
	local skip: { [Instance]: boolean } = {}
	local root = truckRoot(model)
	if root then
		skip[root] = true
	end
	for _, driver in drivers do
		for _, descendant in driver.Rig:GetDescendants() do
			skip[descendant] = true
		end
	end
	return skip
end

-- Pose livrée de la copie `model` : côté du toit d'un camion couché (dans l'espace du pivot), et la
-- bascule à appliquer d'abord s'il est livré debout (nil s'il est déjà couché). Couché : selon
-- ArriveDeliveredPose ; "Auto" = ses conducteurs couchés (leur haut donne le côté du toit), sinon la
-- caisse plus large que haute (toit du côté ArriveTipSide). Debout (la vidéo de Clément montre un camion
-- debout) : il se couche du côté ArriveTipSide, sur l'arête de ses roues, puis la caisse couchée est
-- recentrée sur son point (elle garde le milieu de la chaussée).
local function deliveredPose(model: Model, drivers: { Driver }): (Vector3, CFrame?)
	local pivot = model:GetPivot()
	local up = Vector3.zero
	for _, driver in drivers do
		up += pivot:VectorToObjectSpace(driver.Root.CFrame.UpVector)
	end
	local points = bodyPoints(model, pivot, bodySkip(model, drivers))
	local sideRoof = Vector3.new(if TruckEvent.ArriveTipSide < 0 then -1 else 1, 0, 0)
	if #points == 0 then
		return sideRoof, nil
	end
	local driverRoof: Vector3? = nil
	if up.Magnitude > 1e-3 and math.abs(up.Unit.Y) < 0.5 then
		driverRoof = Vector3.new(up.X, 0, up.Z).Unit
	end
	local mode = TruckEvent.ArriveDeliveredPose
	local lying: boolean
	if mode == "Lying" then
		lying = true
	elseif mode == "Upright" then
		lying = false
	elseif driverRoof then
		lying = true
	else
		local lowX: number, highX: number, lowY: number, highY: number = math.huge, -math.huge, math.huge, -math.huge
		for _, point in points do
			lowX = math.min(lowX, point.X)
			highX = math.max(highX, point.X)
			lowY = math.min(lowY, point.Y)
			highY = math.max(highY, point.Y)
		end
		lying = highX - lowX > highY - lowY
	end
	if lying then
		return driverRoof or sideRoof, nil
	end
	local function middle(list: { Vector3 }): number
		local low: number, high: number = math.huge, -math.huge
		for _, point in list do
			low = math.min(low, point:Dot(sideRoof))
			high = math.max(high, point:Dot(sideRoof))
		end
		return (low + high) / 2
	end
	local fall = aboutEdge(points, sideRoof, Vector3.new(0, 1, 0), sideRoof)
	local fallen: { Vector3 } = {}
	for _, point in points do
		table.insert(fallen, fall * point)
	end
	return sideRoof, CFrame.new(-sideRoof * (middle(fallen) - middle(points))) * fall
end

-- Pose debout (attribut ArriveUpright, dans l'espace du pivot) de la copie couchée `model`, toit vers
-- `roof` : redressée sur l'arête au sol de ses roues (côté opposé au toit). La copie locale bascule donc
-- autour de cette arête, sans glisser, comme un camion qui se couche.
local function uprightPose(model: Model, drivers: { Driver }, roof: Vector3): CFrame
	local points = bodyPoints(model, model:GetPivot(), bodySkip(model, drivers))
	if #points == 0 then
		return CFrame.identity
	end
	return aboutEdge(points, -roof, roof, Vector3.new(0, 1, 0))
end

-- Couche une copie livrée debout (`tip`, dans l'espace de son pivot) : toutes ses pièces sauf Root, qui
-- reste debout sur son point (L-049, b), et les Attachments de Root (BoxSpawn_xx, BlastPoint). La barre
-- de vie (HealthBarPoint) reste au-dessus du milieu de la caisse, à la même hauteur au-dessus d'elle.
local function applyTip(model: Model, tip: CFrame)
	local pivot = model:GetPivot()
	local world = pivot * tip * pivot:Inverse()
	local root = truckRoot(model)
	local skip: { [Instance]: boolean } = {}
	if root then
		skip[root] = true
	end
	local before = bodyPoints(model, pivot, skip)
	local healthPoint = model:FindFirstChild(HEALTH_BAR_POINT, true)
	local clearance: number? = nil
	if healthPoint and healthPoint:IsA("Attachment") and #before > 0 then
		local top = -math.huge
		for _, point in before do
			top = math.max(top, point.Y)
		end
		clearance = pivot:PointToObjectSpace((healthPoint :: Attachment).WorldPosition).Y - top
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= root then
			local part = descendant :: BasePart
			part.CFrame = world * part.CFrame
		elseif descendant:IsA("Model") and (descendant :: Model).PrimaryPart == nil then
			-- Pieces/Piece_xx, Cargo… : leur pivot suit leurs pièces (l'explosion les fait voler par lui).
			local inner = descendant :: Model
			inner.WorldPivot = world * inner.WorldPivot
		elseif descendant:IsA("Attachment") and root and descendant.Parent == root and descendant ~= healthPoint then
			local attachment = descendant :: Attachment
			attachment.CFrame = root.CFrame:ToObjectSpace(world * attachment.WorldCFrame)
		end
	end
	local holder = if healthPoint then healthPoint.Parent else nil
	if clearance and healthPoint and holder and holder:IsA("BasePart") then
		local after = bodyPoints(model, pivot, skip)
		local lowX: number, highX: number, lowZ: number, highZ: number, top: number =
			math.huge, -math.huge, math.huge, -math.huge, -math.huge
		for _, point in after do
			lowX = math.min(lowX, point.X)
			highX = math.max(highX, point.X)
			lowZ = math.min(lowZ, point.Z)
			highZ = math.max(highZ, point.Z)
			top = math.max(top, point.Y)
		end
		local lift: number = clearance
		local position = pivot * Vector3.new((lowX + highX) / 2, top + lift, (lowZ + highZ) / 2)
		local attachment = healthPoint :: Attachment
		attachment.CFrame = (holder :: BasePart).CFrame:ToObjectSpace(CFrame.new(position) * attachment.WorldCFrame.Rotation)
	end
end

-- Fin de l'arrivée : collisions et contacts remis ; un joueur resté dans la caisse est posé à
-- ArrivePushMargin studs du flanc (ou de l'avant, de l'arrière) le plus proche, au sol.
local function finishArrival(truck: Truck)
	local saved = truck.Arriving
	truck.Arriving = nil
	if saved == nil or current ~= truck or truck.State ~= "Active" or truck.Model.Parent == nil then
		return
	end
	for part, collision in saved do
		if part.Parent ~= nil then
			part.CanCollide = collision.CanCollide
			part.CanTouch = collision.CanTouch
		end
	end
	-- Boîte de la caisse dans l'espace du pivot (debout, à plat : on ne sort jamais par le haut ou le bas).
	local model = truck.Model
	local pivot = model:GetPivot()
	local points = bodyPoints(model, pivot, bodySkip(model, driversOf(model)))
	if #points == 0 then
		return
	end
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, point in points do
		low = Vector3.new(math.min(low.X, point.X), math.min(low.Y, point.Y), math.min(low.Z, point.Z))
		high = Vector3.new(math.max(high.X, point.X), math.max(high.Y, point.Y), math.max(high.Z, point.Z))
	end
	local middle = (low + high) / 2
	local margin = math.max(TruckEvent.ArrivePushMargin, 0)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local character = player.Character
		local p = if root then pivot:PointToObjectSpace(root.Position) else Vector3.zero
		local inside = p.X >= low.X and p.X <= high.X and p.Y >= low.Y and p.Y <= high.Y and p.Z >= low.Z and p.Z <= high.Z
		if root and character and inside then
			local exitX = if p.X < middle.X then low.X - margin else high.X + margin
			local exitZ = if p.Z < middle.Z then low.Z - margin else high.Z + margin
			local target = if math.abs(exitX - p.X) <= math.abs(exitZ - p.Z)
				then Vector3.new(exitX, p.Y, p.Z)
				else Vector3.new(p.X, p.Y, exitZ)
			local world = pivot:PointToWorldSpace(target)
			local y = groundY(world, pivot.Position.Y) + PUSH_HEIGHT
			character:PivotTo(CFrame.new(world.X, y, world.Z) * root.CFrame.Rotation)
			log(`{player.Name} était dans le camion n° {truck.Number} à la fin de son arrivée : sorti par le côté`)
		end
	end
end

-- a440 : colis de zone du camion (Features.ZoneBoxEverywhere) -------------------------------------------
-- Allumé : la rareté de chaque colis est celle d'un colis de zone (Shared/ZoneBoxOdds), règle Config/Rewards.TierZoneBox
-- de son type (Config/TruckEvent.Boxes : 6 Standard → Zone, 4 Premium → BestZone, 2 Luxe → NextZone), zone de
-- référence = la zone du camion ; puis l'objet comme avant (contentOf : Items.Pick dans la zone du camion, sinon la
-- rareté tirable la plus proche en dessous). Ni Balance.Heist.BoxTiers ni Rarities.BoxOdds ne sont lus. Renvoie le
-- tirage à passer à drawLoad (rareté voulue et nom de la règle) ; nil si l'interrupteur est coupé ou le module absent.
type ZonePick = (tier: string, zone: number) -> (string?, string?)
local function zoneBoxPick(): ZonePick?
	if ZoneBoxEverywhere == nil or not ZoneBoxEverywhere.Enabled() then
		return nil
	end
	return function(tier: string, zone: number): (string?, string?)
		local name, rule = ZoneBoxEverywhere.Rule(tier)
		local rarity = if rule then ZoneBoxEverywhere.DrawRarity(rule, zone, random) else nil
		if rarity == nil then
			warnOnce(`zonebox.{tier}.{zone}`, `colis de zone du camion : type {tier} sans règle ({tostring(name)}) ou zone {zone} sans rareté (Config/Rewards.TierZoneBox, ZoneBox, Rarities.ZoneOdds) : colis sauté`)
		end
		return rarity, name
	end
end

-- Tirage (comme un rayon de la zone, StoreHeistService) ------------------------------------------------

-- La rareté `rarityId` a-t-elle un objet qu'Items.Pick peut rendre en zone `zone` ? (Secret : seulement les zones qui
-- l'ont, la 6 ; Divine : toutes zones dès qu'un objet existe ; les autres : Items.ByZone, sans TutorialOnly.) Même
-- règle que drawGiftRarity d'UnboxService.
local function drawable(zone: number, rarityId: string): boolean
	local allZones = Items.AllZones[rarityId]
	if allZones ~= nil then
		return next(allZones) ~= nil and (Rarities.FirstZone[rarityId] == nil or Rarities.Allows(zone, rarityId))
	end
	local byRarity = Items.ByZone[zone]
	local list = if byRarity then byRarity[rarityId] else nil
	return list ~= nil and next(list) ~= nil
end

-- Table du camion pour un colis `tier` en zone `zone` : ShelfBoxes.OddsFor sans les raretés qui finissaient en colis
-- vide (aucun objet tirable à leur niveau ni en dessous dans la zone, drawable), ramenée à 100 ; une rareté gardée sans
-- objet retombe toujours, comme avant, sur la plus proche en dessous qui en a (drawContent). nil si rien ne reste
-- (Config incohérente). a295 (vague 84) : V0, choisie par le grand chef le 21/11 (la doc 7.3 dit les tables du camion
-- non limitées à la zone). Zones 1 à 4 inchangées (aucun colis vide avant) ; zones 5 et 6 : la même distribution
-- qu'avant parmi les colis non vides (avant : 5,6 colis vides sur 12 en zone 5, 8,8 en zone 6).
local function truckOdds(tier: string, zone: number): { [string]: number }?
	local odds = ShelfBoxes.OddsFor(zone, tier)
	if odds == nil then
		return nil
	end
	local kept: { [string]: number } = {}
	local total = 0
	local below = false -- un objet tirable à ce niveau ou en dessous (Rarities.List va de Commun à Divine)
	for _, rarity in Rarities.List do
		below = below or drawable(zone, rarity.Id)
		local weight = odds[rarity.Id] or 0
		if weight > 0 and below then
			kept[rarity.Id] = weight
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	for rarityId, weight in kept do
		kept[rarityId] = weight / total * 100
	end
	return kept
end

local function drawRarity(tier: string, zone: number): string?
	local odds = truckOdds(tier, zone)
	if odds == nil then
		return nil
	end
	local roll = random:NextNumber() * 100
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

-- Rareté et objet d'un colis de rareté voulue `rarity` en zone `zone` (la rareté tirable la plus proche en dessous si
-- la zone n'en a pas), ou nil (Config incohérente). a440 : séparé de drawContent, pour les colis de zone.
local function contentOf(rarity: string, zone: number): (string?, string?)
	local item = Items.Pick(zone, rarity :: Rarities.RarityId, random)
	if item then
		return item.Rarity, item.Id
	end
	-- Case vide : la rareté tirable la plus proche en dessous (Rarities.List va de Commun à Secret ; truckOdds garantit
	-- qu'il y en a une).
	local order = Rarities.ById[rarity].Order
	for index = #Rarities.List, 1, -1 do
		local candidate = Rarities.List[index]
		if candidate.Order < order then
			local fallback = Items.Pick(zone, candidate.Id, random)
			if fallback then
				-- Vague 76 : une rareté absente de la zone (Rarities.ZoneOdds) n'y a aucun objet, sans incohérence : pas d'avertissement.
				if Rarities.Allows(zone, rarity) then
					warnOnce(
						`empty.{zone}.{rarity}`,
						`aucun objet {rarity} tirable en zone {zone} (Config/Items) : ces colis du camion reçoivent un objet {candidate.Id}`
					)
				end
				return fallback.Rarity, fallback.Id
			end
		end
	end
	return nil, nil
end

-- Rareté et objet d'un colis de type `tier` en zone `zone`, ou nil (Config incohérente).
local function drawContent(tier: string, zone: number): (string?, string?)
	local rarity = drawRarity(tier, zone)
	if rarity == nil then
		return nil, nil
	end
	return contentOf(rarity, zone)
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

-- Chargement d'un camion de la zone `zone` : types mélangés (boxTiers), contenu tiré comme sur un rayon
-- (drawContent), mutation par Mutations.Roll (DEV-131, jamais pour un objet TutorialOnly). Tiré à
-- l'apparition (a79) au lieu de l'explosion : mêmes chances, mais le modèle du camion en dépend.
-- a440 : `pick` (zoneBoxPick, Features.ZoneBoxEverywhere) donne la rareté voulue de chaque colis (colis de zone) et le
-- nom de sa règle, à la place du tirage par type (drawContent) ; l'objet suit le même chemin (contentOf).
local function drawLoad(zone: number, pick: ((tier: string, zone: number) -> (string?, string?))?): { Load }
	local load: { Load } = {}
	for _, tier in boxTiers() do
		local rarity: string?, itemId: string?, rule: string? = nil, nil, nil
		if pick then
			local wanted: string?
			wanted, rule = pick(tier, zone)
			if wanted then
				rarity, itemId = contentOf(wanted, zone)
			end
		else
			rarity, itemId = drawContent(tier, zone)
		end
		local mutation: Mutations.Mutation? = nil
		if itemId and not Items.ById[itemId].TutorialOnly then
			mutation = Mutations.Roll(random)
		end
		table.insert(load, { Tier = tier, Rule = rule, Rarity = rarity, ItemId = itemId, Mutation = mutation })
	end
	return load
end

-- Largeur au sol d'un colis : la plus grande dimension horizontale du modèle de Clément BOX_<Rareté>
-- (L-097 point 3), sinon BOX_<Tier> (Assets), sinon TruckEvent.BoxFallbackWidth (le bloc gris de CarryService).
local function boxWidth(rarity: string?, tier: string): number
	local names = { BOX_PREFIX .. tier }
	if rarity then
		table.insert(names, 1, BOX_PREFIX .. rarity)
	end
	for _, name in names do
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
	truck.Model:SetAttribute(LEFT_AT_ATTRIBUTE, Workspace:GetServerTimeNow()) -- répliqué avant le retrait
	truck.Model:Destroy()
	if message then
		notifyAll(message, "Info")
	end
end

local function spawnTruck(zone: number): boolean
	if findTemplate() == nil then
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
	-- Chargement tiré dès l'apparition (a79, L-097 point 3) : le camion prend le modèle de sa rareté la plus haute.
	local load = drawLoad(zone, zoneBoxPick()) -- a440 : colis de zone avec Features.ZoneBoxEverywhere
	local found, asset = pickTemplate(load)
	if found == nil then
		return false
	end
	local template: Model = found
	local model = template:Clone() :: Model? -- nil si le modèle n'est pas Archivable
	if model == nil then
		warnOnce("archivable", `{template:GetFullName()} n'est pas Archivable : pas de camion`)
		return false
	end
	local borrowed = if asset ~= TRUCK_ASSET then borrowDrivers(model) else 0
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
	-- Arrivée en roulant (a97) : pose debout pour la copie locale des clients (le camion livré debout est
	-- d'abord couché), collisions et contacts coupés jusqu'à la fin de l'arrivée (personne n'est bloqué).
	local landing, arrivalEnd = arrivalTimes()
	local arriving: { [BasePart]: SavedCollision }? = nil
	if landing > 0 then
		local roof, tip = deliveredPose(model, drivers)
		if tip then
			applyTip(model, tip)
			log(`{asset} livré debout : couché à sa place (côté {TruckEvent.ArriveTipSide})`)
		end
		model:SetAttribute(ARRIVE_UPRIGHT_ATTRIBUTE, uprightPose(model, drivers, roof))
		local saved: { [BasePart]: SavedCollision } = {}
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				local part = descendant :: BasePart
				saved[part] = { CanCollide = part.CanCollide, CanTouch = part.CanTouch }
				part.CanCollide = false
				part.CanTouch = false
			end
		end
		arriving = saved
	end
	truckCount += 1
	model.Name = TRUCK_NAME
	model:SetAttribute(ZONE_ATTRIBUTE, zone)
	model:SetAttribute(NUMBER_ATTRIBUTE, truckCount)
	-- Vague 26 (a81) : heure serveur de l'apparition, pour les sons d'arrivée de TruckController (seuls
	-- ceux qui voient le camion arriver les entendent, pas un joueur qui le reçoit plus tard par le streaming).
	local serverNow = Workspace:GetServerTimeNow()
	model:SetAttribute(SPAWNED_AT_ATTRIBUTE, serverNow)
	if arriving then
		model:SetAttribute(ARRIVE_ENDS_AT_ATTRIBUTE, serverNow + landing) -- impact au sol : FX_TruckDust (VfxController)
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- le camion et ses points arrivent ensemble
	model:PivotTo(frame)
	model.Parent = Workspace
	CollectionService:AddTag(model, TRUCK_TAG)
	playDriverIdles(drivers)
	-- PV selon la zone (rééquilibrage v2) : HPPerDamage × les dégâts conseillés de sa zone.
	local zoneInfo = Zones[zone] or Zones[1]
	local maxHP = math.max(1, math.round(TruckEvent.HPPerDamage * zoneInfo.AdvisedDamage))
	local windowId = WindowService.AddTarget(model, maxHP)
	if windowId == nil then
		model:Destroy()
		return false
	end
	local truck: Truck = {
		Number = truckCount,
		Zone = zone,
		Model = model,
		WindowId = windowId,
		SpawnedAt = os.clock(),
		State = "Active",
		Load = load,
		Arriving = arriving,
	}
	current = truck
	if arriving then
		task.delay(arrivalEnd, finishArrival, truck)
	end
	chrono = { Number = truckCount, Zone = zone, Frame = frame, EndsAt = os.clock() + TruckEvent.Lifetime, Asset = asset }
	notifyAll(string.format(TruckEvent.Messages.Spawned, zone), "Info")
	local p = frame.Position
	local drivenBy = if borrowed > 0 then `, {borrowed} conducteur(s) repris de {TRUCK_ASSET}` else ""
	log(
		`camion n° {truckCount} en zone {zone} ({math.round(p.X)}, {math.round(p.Y)}, {math.round(p.Z)}), modèle {asset}{drivenBy}, {maxHP} PV, part dans {TruckEvent.Lifetime} s`
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
	-- Vague 42 (a148, demande de Cantin) : colis à ouvrir sur place, comme sur un rayon (rayon d'événement de
	-- StoreHeistService : même maintien, même chance tirée par le serveur, même sortie, objet et mutation tirés
	-- à l'ouverture, puis GrabItem) ; la rareté du chargement devient celle de la caisse. Chaque caisse vole du
	-- BoxSpawn à son point d'arrivée (vol du serveur, placeBox). Vague 50 (a158, Cantin 2026-11-14) : plus aucun
	-- colis posé au sol pour être porté fermé ; sans rayon d'événement, le camion ne lâche rien (avertissement).
	local spots: { any } = {}
	for index, entry in truck.Load do
		local spawnPoint = Find.path(model, string.format(BOX_SPAWN_FORMAT, index))
		local from: Vector3 = if spawnPoint and spawnPoint:IsA("Attachment")
			then (spawnPoint :: Attachment).WorldPosition
			else blastPosition
		local rarity = entry.Rarity
		if rarity then
			local look = `{rarity}.{entry.Tier}`
			local width = widths[look] or boxWidth(rarity, entry.Tier)
			widths[look] = width
			local landing = landingPoint(from, center, width, taken)
			table.insert(taken, { Position = landing, Width = width })
			table.insert(spots, { CFrame = CFrame.new(landing), Tier = entry.Tier, Rarity = rarity, From = from })
		end
	end
	local addShelf = if heistApi then heistApi.AddEventShelf else nil
	local shelf = if addShelf and #spots > 0
		then addShelf({ Id = storeId, Zone = truck.Zone, Spots = spots, Lifetime = TruckEvent.FlightTime + TruckEvent.BoxLifetime, NextZoneChance = TruckEvent.NextZoneChance }) -- L-166 Q5 (a181)
		else nil
	if shelf then
		for _, spot in spots do
			placed += 1
			byTier[spot.Tier] = (byTier[spot.Tier] or 0) + 1
		end
	elseif #spots > 0 and addShelf then
		warnOnce("noshelf", "StoreHeistService.AddEventShelf a refusé le rayon d'événement : le camion explose sans colis")
	elseif #spots > 0 then
		log("StoreHeistService.AddEventShelf indisponible : le camion explose sans colis (plus de colis porté)")
	end
	notifyAll(TruckEvent.Messages.Exploded, "Info")
	local parts: { string } = {}
	-- a440 : colis de zone (Load.Rule) : les types dans l'ordre de Config/TruckEvent.Boxes, avec leur règle ; sinon
	-- l'ordre des types (Balance.Heist.TierOrder), comme avant.
	local zoned = false
	for _, entry in truck.Load do
		zoned = zoned or entry.Rule ~= nil
	end
	local order: { string } = {}
	if zoned then
		for _, entry in TruckEvent.Boxes do
			table.insert(order, entry.Tier)
		end
	else
		for _, tier in Balance.Heist.TierOrder do
			table.insert(order, tier)
		end
	end
	for _, tier in order do
		local rule = if zoned and ZoneBoxEverywhere then ZoneBoxEverywhere.RuleName(tier) else nil
		table.insert(parts, `{byTier[tier] or 0} {tier}{if rule then " → " .. rule else ""}`)
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

-- `player` porte-t-il un objet sorti d'une caisse du camion `storeId` (« Truck_<n> », NPCItem, vague 42) ?
local function carriesBoxOf(player: Player, storeId: string): boolean
	local payload = CarryService.GetPayload(player)
	if payload == nil or payload.Kind ~= "NPCItem" then
		return false
	end
	return (payload :: any).StoreId == storeId
end

-- Les conducteurs du modèle de Clément `asset` (celui du camion), par ordre de nom (TruckDriver_01,
-- _02…) ; un camion par rareté sans conducteur prend ceux d'ENV_Event_Truck (comme borrowDrivers).
local function driverTemplates(asset: string): { Model }
	local list: { Model } = {}
	for _, name in { asset, TRUCK_ASSET } do
		local template = findTemplate(name)
		if template then
			for _, driver in driversOf(template) do
				table.insert(list, driver.Rig)
			end
		end
		if #list > 0 then
			break
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
	local templates = driverTemplates(c.Asset)
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
			Net.Server.Notify:Fire(player, TruckEvent.Messages.DriversChase, "Alert")
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

-- Horaire ---------------------------------------------------------------------------------------------

local function randomInterval(): number
	local low = math.max(TruckEvent.SpawnIntervalMin, 0)
	local high = math.max(TruckEvent.SpawnIntervalMax, low)
	return (low + random:NextNumber() * (high - low)) * (Workspace:GetAttribute("LiveEventTruckDelay") :: number? or 1) -- a167 : EventService
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

-- Une vitrine de la Fortune Tower dans le Workspace (vague 39) : pas de camion en même temps.
local function fortuneInPlay(): boolean
	for _, vault in CollectionService:GetTagged(FORTUNE_VAULT_TAG) do
		if vault:IsDescendantOf(Workspace) then
			return true
		end
	end
	return false
end

-- a425 : le fourgon blindé retient-il le camion ?
local function vanHolds(): boolean
	local api = vanApi
	if api == nil then
		return false
	end
	local ok, held = pcall(api.HoldsTruck)
	return ok and held == true
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
	nextSpawnAt = math.min(nextSpawnAt, now + math.max(TruckEvent.SpawnIntervalMax, 0) * (Workspace:GetAttribute("LiveEventTruckDelay") :: number? or 1)) -- a167 : attente raccourcie dès le début
	if now < nextSpawnAt or not daySpawnAllowed() or fortuneInPlay() or vanHolds() then
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

-- Fusion de la vague 29 (Ironix) : pas de coup sur le camion pendant son arrivée, quand les clients voient
-- encore la copie qui roule ailleurs (le vrai camion est déjà posé à sa place finale).
local function hitGate(_player: Player, windowId: string, _kind: string, _model: Model): boolean
	local truck = current
	return not (truck ~= nil and truck.WindowId == windowId and truck.Arriving ~= nil)
end

-- Démarrage -----------------------------------------------------------------------------------------

function TruckEventService.Init()
	if not ENABLED then
		return
	end
	-- Vague 42 : rayons d'événement de StoreHeistService (colis ouverts sur place), protégé (bancs d'avant).
	local module = script.Parent:FindFirstChild("StoreHeistService")
	if module and module:IsA("ModuleScript") then
		local ok, api = pcall(require, module)
		if ok and type(api) == "table" and type((api :: any).AddEventShelf) == "function" then
			heistApi = api :: any
		end
	end
	if heistApi == nil then
		log("StoreHeistService.AddEventShelf indisponible : le camion explosera sans colis (plus de colis porté)")
	end
	local vanModule = script.Parent:FindFirstChild("ArmoredVanService") -- a425 (L-318 Q1)
	if vanModule and vanModule:IsA("ModuleScript") then
		local ok, api = pcall(require, vanModule)
		if ok and type(api) == "table" and type((api :: any).HoldsTruck) == "function" then
			vanApi = api :: any
		end
	end
	WindowService.OnBroken(onBroken)
	-- Accès protégé : les faux WindowService des bancs n'ont pas tous AddHitGate.
	local addHitGate: ((gate: typeof(hitGate)) -> ())? = (WindowService :: any).AddHitGate
	if addHitGate then
		addHitGate(hitGate)
	end
	NightCycleService.OnPhaseChanged(onPhaseChanged)
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
	local byRarity: { string } = {}
	for _, rarity in Rarities.List do
		local name = string.format(TRUCK_RARITY_FORMAT, rarity.Id)
		local found = findTemplate(name)
		if found and truckProblem(found) == nil then
			table.insert(byRarity, rarity.Id)
		end
	end
	if #byRarity > 0 then
		delivered ..= ` ; camions par rareté (le plus rare du chargement) : {table.concat(byRarity, ", ")}`
	end
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

-- a516 (fourgon blindé V2) : le placement des colis du camion, repris par ArmoredVanService (12 colis au sol à la casse)
-- plutôt que recopié. Point d'arrivée au sol (landingPoint) d'un colis de largeur `width` sorti en `from` d'un véhicule
-- centré en `center`, loin des colis de `taken` ; largeur au sol d'un colis BOX_<Rareté> (boxWidth).
function TruckEventService.LandingPoint(from: Vector3, center: Vector3, width: number, taken: { Landing }): Vector3
	return landingPoint(from, center, width, taken)
end

function TruckEventService.BoxWidth(rarity: string): number
	return boxWidth(rarity, "Standard")
end

return TruckEventService
