--!strict
-- ItemRainService (vague 58, a188 ; liaison L-170 Q7, décision de Clément du 2026-11-15 : « une pluie d'objets à la
-- place de la pluie de colis » ; docs/claude/notes/feuille-de-route-maj.md, section 3) : la pluie d'objets,
-- événement live du samedi. Valeurs : Config/ItemRain (toutes V0) ; format (titre, bannière, 15 min) :
-- Config/LiveEvents, Id « ItemRain ».
--
-- Lancement : comme tout événement live, par EventService (StartEvent du panel admin, permis hors Studio pour un
-- admin ; pas de ligne au planning : aucune date). Ce service ne lance rien : toutes les ItemRain.TickInterval s, il
-- lit l'attribut LiveEvent du Workspace (posé par EventService seul). Tant qu'il vaut ItemRain.EventId, il pleut.
--
-- Pendant la pluie :
--   - un objet toutes les ItemRain.DropEvery s, un seul par tour et jamais de rattrapage : aucune rafale de
--     créations dans une image (un modèle d'objet copié toutes les 5 s) ;
--   - où : sur une rue du couloir (BasePart nommée ItemRain.StreetName, choisie selon sa surface, comme les potions
--     de PotionService), à EdgeMargin studs de ses bords ; le point est gardé si un rayon vers le bas touche d'abord
--     la rue (personnages, vigiles et pièces invisibles traversés), de même à Clearance studs autour (pas sous un
--     lampadaire, une arche, un camion), s'il est côté couloir (NightCycleService.IsInCorridor), hors de toute zone
--     safe (Shared/SafeZone : le hub n'en reçoit jamais), dans une zone de ItemRain.Zones et à MinSpacing studs des
--     autres objets de la pluie encore au sol. SpawnTries tirages, sinon rien à ce tour ;
--   - zone du point : celle du magasin PNJ (tag NPCStore, attribut Zone) le plus proche, à plat ;
--   - objet : tiré comme sur un rayon d'un magasin de cette zone (StoreHeistService.DrawForZone : type de caisse,
--     rareté de la caisse selon la zone, chance, puis rareté, objet et mutation de la sortie) ;
--   - au sol : CarryService.PlaceItemDrop, le même objet au sol qu'après un coup de batte (Workspace/CarryDrops, halo,
--     étiquette, invite « Grab » de BatController, ramassage GrabDropped de BatService : mains vides, vivant, pas
--     étourdi, hors zone safe, à 8 studs, maintien de 0,5 s). Il tombe de FallHeight studs en FallTime s (chute
--     jouée ici, à chaque image, pour un objet à la fois) ;
--   - plafond : ItemRain.MaxOnGround objets de la pluie encore au sol (jamais ramassés) ; au plafond, rien ne tombe ;
--   - pas ramassé : il disparaît au bout de ItemRain.Lifetime s (CarryService) ;
--   - la nuit (ItemRain.PauseAtNight) : rien ne tombe, le couloir est fermé ; l'événement continue de tourner.
--
-- Ramassé, c'est un objet porté comme les autres (NPCItem, origine ItemRain.StoreId) : malus de portage, rangé dans
-- l'inventaire à l'entrée de la zone safe (UnboxService), il tombe au sol sur un coup de batte ou une
-- capture, où n'importe qui le reprend ; resté au sol Bat.DroppedLifetime s, il disparaît (il n'a pas de rayon où
-- revenir) ; perdu aussi si le porteur meurt ou part. Sans vigile de jour : son origine a le préfixe « Truck_ » des
-- événements (GuardService : pas de magasin, pas de vigile), ce sont des cadeaux d'événement. Les vigiles de nuit et
-- la police gardent leurs règles.
--
-- Début et fin : Notify à tout le serveur (ItemRain.Messages). À la fin, plus rien ne tombe ; les objets déjà au sol
-- y restent jusqu'au bout de leur temps (aucun retrait en rafale), un objet en train de tomber finit sa chute.
--
-- Télémétrie : le début et la fin partent déjà d'EventService (LiveEventStart, LiveEventEnd). Ici : ItemRainPickup
-- (1re prise d'un objet de la pluie) et ItemRainBanked (rangé en base), champs Zone et Rarity ; un coup de batte sur
-- un porteur part en BatBoxKnock, Source « Rain » (TelemetryService). Bilan de la pluie dans la sortie, à la fin.
--
-- Tester dans Studio (barre de commande serveur) :
--   require(game.ServerScriptService.Server.Services.EventService).Launch("ItemRain", "test")
--   require(game.ServerScriptService.Server.Services.EventService).Stop("test")
--
-- API (serveur) :
--   ItemRainService.IsRaining() -> boolean    l'événement tourne sur ce serveur
--   ItemRainService.GetStats() -> Stats       copie : Dropped, PickedUp, Banked depuis le début de la pluie en cours
--                                             (ou de la dernière), OnGround = objets de la pluie encore au sol

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ItemRain = require(Shared.Config.ItemRain)
local LiveEvents = require(Shared.Config.LiveEvents)
local Zones = require(Shared.Config.Zones)
local Net = require(Shared.Net.Net)
local SafeZone = require(Shared.SafeZone)
local CarryTypes = require(Shared.Types.Carry)

local CarryService = require(script.Parent.CarryService)
local NightCycleService = require(script.Parent.NightCycleService)
local StoreHeistService = require(script.Parent.StoreHeistService)
local TelemetryService = require(script.Parent.TelemetryService)

export type Stats = {
	Dropped: number,
	PickedUp: number,
	Banked: number,
	OnGround: number,
}

-- Noms du contrat (2.1) et dossiers hors carte.
local STORE_TAG = "NPCStore"
local ZONE_ATTRIBUTE = "Zone"
local INBOX_NAME = "_INBOX_CLEMENT"
local SANDBOX_NAME = "_SANDBOX_IRONIX"
local ACTIVE_GUARDS = "ActiveGuards" -- vigiles en jeu (GuardService), traversés par les rayons
-- V0 proposés, absents du doc (mêmes valeurs que PotionService).
local RAY_HEIGHT = 40 -- studs au-dessus de la rue d'où partent les rayons
local RAY_LENGTH = 80 -- studs vers le bas
local INVISIBLE_SKIPS = 4 -- pièces invisibles (Transparency 1) traversées au plus par un rayon
local STREET_RESCAN = 10 -- s au moins entre deux recherches des rues
local STANDING_HEIGHT = 3 -- studs : centre d'un joueur debout sur le point (contrôle de la zone safe)
local NOTIFY_KIND = "Info"

local IS_STUDIO = RunService:IsStudio()

local ItemRainService = {}

local random = Random.new()
local raining = false
local nextDropAt = 0 -- os.clock()
local dropped, pickedUp, banked = 0, 0, 0
-- Objets de la pluie encore au sol, jamais ramassés : [dropId] = point du sol.
local onGround: { [string]: Vector3 } = {}
-- Objets de la pluie : [payload] = true tant qu'il n'a jamais été ramassé, false ensuite (clés faibles).
local rainPayloads: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local streets: { BasePart } = {}
local streetsScannedAt = -math.huge
local warned: { [string]: boolean } = {}
local loopStarted = false

local function log(message: string)
	if IS_STUDIO then
		print(`[ItemRainService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[ItemRainService] {message}`)
	end
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

-- Place ------------------------------------------------------------------------------------------------

-- Rues du couloir (voir l'en-tête) : une seule recherche dans le Workspace (lecture seule), refaite au plus toutes
-- les STREET_RESCAN s tant que la liste est vide.
local function currentStreets(): { BasePart }
	local alive: { BasePart } = {}
	for _, part in streets do
		if part.Parent ~= nil and inMap(part) then
			table.insert(alive, part)
		end
	end
	streets = alive
	local t = os.clock()
	if #streets == 0 and t - streetsScannedAt >= STREET_RESCAN then
		streetsScannedAt = t
		for _, descendant in Workspace:GetDescendants() do
			if descendant.Name == ItemRain.StreetName and descendant:IsA("BasePart") and inMap(descendant) then
				table.insert(streets, descendant)
			end
		end
		if #streets == 0 then
			warnOnce("streets", `aucune BasePart « {ItemRain.StreetName} » dans le Workspace : rien ne tombe`)
		else
			log(`{#streets} rue(s) « {ItemRain.StreetName} » trouvée(s)`)
		end
	end
	return streets
end

-- Rayons d'une recherche : personnages et vigiles exclus, puis chaque pièce invisible touchée (volumes de zone,
-- déclencheurs), ajoutée au filtre au fil des tirs. Les objets au sol ne répondent pas aux rayons (CarryService).
type Rays = { Params: RaycastParams, Exclude: { Instance } }

local function newRays(): Rays
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(exclude, character)
		end
	end
	local guards = Workspace:FindFirstChild(ACTIVE_GUARDS)
	if guards then
		table.insert(exclude, guards)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return { Params = params, Exclude = exclude }
end

-- Première pièce visible sous le point (x, z), depuis la hauteur `top` + RAY_HEIGHT.
local function groundAt(x: number, z: number, top: number, rays: Rays): RaycastResult?
	local origin = Vector3.new(x, top + RAY_HEIGHT, z)
	local direction = Vector3.new(0, -RAY_LENGTH, 0)
	for _ = 1, INVISIBLE_SKIPS + 1 do
		local result = Workspace:Raycast(origin, direction, rays.Params)
		if result == nil or result.Instance.Transparency < 1 then
			return result
		end
		table.insert(rays.Exclude, result.Instance)
		rays.Params.FilterDescendantsInstances = rays.Exclude
	end
	return nil
end

local function isStreet(result: RaycastResult?): boolean
	return result ~= nil and result.Instance.Name == ItemRain.StreetName
end

-- Zone du magasin PNJ le plus proche de `position`, à plat ; nil sans magasin dans la carte.
local function zoneAt(position: Vector3): number?
	local best: number? = nil
	local bestDistance = math.huge
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		local zone = store:GetAttribute(ZONE_ATTRIBUTE)
		if type(zone) == "number" and Zones[zone] ~= nil and store:IsA("PVInstance") and inMap(store) then
			local pivot = (store :: PVInstance):GetPivot().Position
			local distance = Vector3.new(pivot.X - position.X, 0, pivot.Z - position.Z).Magnitude
			if distance < bestDistance then
				best, bestDistance = zone, distance
			end
		end
	end
	return best
end

-- Un point au sol d'une rue du couloir pour un nouvel objet, et sa zone ; nil sans point à ce tour.
local function findSpot(): (Vector3?, number)
	local list = currentStreets()
	local total = 0
	for _, part in list do
		total += part.Size.X * part.Size.Z
	end
	if total <= 0 then
		return nil, 0
	end
	local rays = newRays()
	local offsets = {
		Vector3.new(ItemRain.Clearance, 0, 0),
		Vector3.new(-ItemRain.Clearance, 0, 0),
		Vector3.new(0, 0, ItemRain.Clearance),
		Vector3.new(0, 0, -ItemRain.Clearance),
	}
	for _ = 1, ItemRain.SpawnTries do
		local roll = random:NextNumber() * total
		local street = list[#list]
		for _, part in list do
			roll -= part.Size.X * part.Size.Z
			if roll < 0 then
				street = part
				break
			end
		end
		local size = street.Size
		local hx, hz = size.X / 2 - ItemRain.EdgeMargin, size.Z / 2 - ItemRain.EdgeMargin
		if hx <= 0 or hz <= 0 then
			continue
		end
		local inStreet = Vector3.new(random:NextNumber(-hx, hx), size.Y / 2, random:NextNumber(-hz, hz))
		local point: Vector3 = (street.CFrame:PointToWorldSpace(inStreet)) -- parenthèses : une seule valeur
		local hit = groundAt(point.X, point.Z, point.Y, rays)
		if hit == nil or not isStreet(hit) then
			continue
		end
		local clear = true
		for _, offset in offsets do
			if not isStreet(groundAt(point.X + offset.X, point.Z + offset.Z, point.Y, rays)) then
				clear = false
				break
			end
		end
		local ground = hit.Position
		-- Jamais en zone safe (hub compris) : ni le point du sol, ni la hauteur d'un joueur debout dessus (un volume
		-- de zone safe peut commencer au-dessus du sol).
		local standing = ground + Vector3.new(0, STANDING_HEIGHT, 0)
		if not clear or not NightCycleService.IsInCorridor(ground) or SafeZone.Contains(ground) or SafeZone.Contains(standing) then
			continue
		end
		local zone = zoneAt(ground)
		if zone == nil then
			warnOnce("stores", `aucun magasin PNJ (tag {STORE_TAG}, attribut {ZONE_ATTRIBUTE}) dans la carte : rien ne tombe`)
			return nil, 0
		end
		if table.find(ItemRain.Zones, zone) == nil then
			continue
		end
		local free = true
		for _, other in onGround do
			if (other - ground).Magnitude < ItemRain.MinSpacing then
				free = false
				break
			end
		end
		if free then
			return ground, zone
		end
	end
	return nil, 0
end

-- Chute et pose --------------------------------------------------------------------------------------

-- L'objet, déjà posé à son point par CarryService, part de FallHeight studs au-dessus et y retombe en FallTime s
-- (chute accélérée). Appelé dans sa propre tâche, juste après la pose : le premier PivotTo passe avant la
-- réplication, les clients le voient arriver d'en haut. S'arrête si l'objet est ramassé ou retiré.
local function fall(model: Model)
	local height, duration = ItemRain.FallHeight, ItemRain.FallTime
	if height <= 0 or duration <= 0 then
		return
	end
	local landed = model:GetPivot()
	local started = os.clock()
	while model.Parent ~= nil do
		local alpha = math.min((os.clock() - started) / duration, 1)
		model:PivotTo(landed + Vector3.new(0, height * (1 - alpha * alpha), 0))
		if alpha >= 1 then
			break
		end
		task.wait()
	end
end

-- Fait tomber un objet. false si rien n'est tombé à ce tour (pas de point, tirage vide, refus de CarryService).
local function dropOne(): boolean
	local ground, zone = findSpot()
	if ground == nil then
		return false
	end
	local content, luck = StoreHeistService.DrawForZone(zone)
	if content == nil then
		warnOnce(`draw.{zone}`, `aucun objet ne peut sortir en zone {zone} (Config : ShelfBoxes, ShelfOpen, Items) : rien ne tombe là`)
		return false
	end
	local payload: CarryTypes.NPCItemPayload = {
		Kind = "NPCItem",
		ItemId = content.ItemId,
		Rarity = content.Rarity,
		Mutation = content.Mutation,
		Zone = zone,
		StoreId = ItemRain.StoreId,
		SlotId = ItemRain.SlotId,
		Luck = luck,
	}
	local dropId, model = CarryService.PlaceItemDrop(payload, ground, ItemRain.Lifetime)
	if dropId == nil then
		return false
	end
	onGround[dropId] = ground
	rainPayloads[payload] = true
	dropped += 1
	if model then
		task.spawn(fall, model)
	end
	log(`{dropId} : {content.Rarity} ({content.ItemId}) tombe en zone {zone}, chance ×{luck}`)
	return true
end

-- Oublie les objets de la pluie qui ne sont plus au sol (ramassés ou disparus). Renvoie ceux qui restent.
local function countOnGround(): number
	local count = 0
	for dropId in onGround do
		if CarryService.GetDrop(dropId) == nil then
			onGround[dropId] = nil
		else
			count += 1
		end
	end
	return count
end

-- Début, fin, tour --------------------------------------------------------------------------------------

local function notifyAll(message: string)
	Net.Server.Notify:FireAll(message, NOTIFY_KIND)
end

local function begin()
	dropped, pickedUp, banked = 0, 0, 0
	nextDropAt = os.clock() -- le premier objet tombe tout de suite
	local endsAt = Workspace:GetAttribute(LiveEvents.EndsAtAttribute)
	local format = LiveEvents.ById[ItemRain.EventId]
	local remaining = if type(endsAt) == "number" then endsAt - Workspace:GetServerTimeNow() elseif format then format.Duration else 0
	notifyAll(string.format(ItemRain.Messages.Started, LiveEvents.FormatTimer(remaining)))
	log(`la pluie commence pour {math.round(remaining)} s : un objet toutes les {ItemRain.DropEvery} s, {ItemRain.MaxOnGround} au sol au plus`)
end

local function finish()
	notifyAll(ItemRain.Messages.Ended)
	print(`[ItemRainService] fin de la pluie : {dropped} objet(s) tombé(s), {pickedUp} ramassé(s), {banked} rangé(s) en base, {countOnGround()} encore au sol`)
end

local function step()
	local running = Workspace:GetAttribute(LiveEvents.IdAttribute) == ItemRain.EventId
	if running ~= raining then
		raining = running
		if running then
			begin()
		else
			finish()
		end
	end
	if not raining then
		return
	end
	local t = os.clock()
	if t < nextDropAt then
		return
	end
	nextDropAt = t + ItemRain.DropEvery -- un seul objet par tour, jamais de rattrapage
	if ItemRain.PauseAtNight and NightCycleService.IsNight() then
		return -- couloir fermé
	end
	if countOnGround() >= ItemRain.MaxOnGround then
		return -- plafond
	end
	dropOne()
end

-- Télémétrie ------------------------------------------------------------------------------------------

local function logItem(player: Player, key: string, payload: any)
	local ok, err = pcall(TelemetryService.LogEvent :: any, player, key, { `Zone - {payload.Zone}`, `Rarity - {payload.Rarity}` })
	if not ok then
		warn(`[ItemRainService] télémétrie {key} : {err}`)
	end
end

local function onCarryStarted(player: Player, payload: any)
	if rainPayloads[payload] == true then
		rainPayloads[payload] = false
		pickedUp += 1
		logItem(player, "ItemRainPickup", payload)
	end
end

local function onCarryEnded(player: Player, payload: any, result: string, _reason: string)
	if result == "Consumed" and rainPayloads[payload] ~= nil then
		rainPayloads[payload] = nil
		banked += 1
		logItem(player, "ItemRainBanked", payload)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function ItemRainService.IsRaining(): boolean
	return raining
end

function ItemRainService.GetStats(): Stats
	return { Dropped = dropped, PickedUp = pickedUp, Banked = banked, OnGround = countOnGround() }
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

function ItemRainService.Init()
	CarryService.OnCarryStarted(onCarryStarted)
	CarryService.OnCarryEnded(onCarryEnded)
end

function ItemRainService.Start()
	if loopStarted then
		return
	end
	loopStarted = true
	while true do
		local ok, err = pcall(step :: any) -- :: any : l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			warn(`[ItemRainService] tour : {err}`)
		end
		task.wait(ItemRain.TickInterval)
	end
end

return ItemRainService
