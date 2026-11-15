--!strict
-- FortuneTowerService (liaison L-108 point 8, idée de Clément du 2026-11-12 ; vague 37, a123 ; pas encore
-- une tâche du backlog) : l'événement de la Fortune Tower. Valeurs : Config/FortuneTower (toutes V0
-- proposées, validées par Clément : L-145 (a), vague 42) ; interrupteur : Config/Features.FortuneTower,
-- true depuis cette validation. Modèle : TruckEventService (événement à plusieurs, PV partagés, butin au sol).
--
-- Une seule vitrine à la fois :
--   1. Apparition (Features.FortuneTower seulement), SpawnIntervalMin à SpawnIntervalMax s (tiré au
--      hasard) après la précédente ou le démarrage du serveur, quand tout est réuni : phase Day de
--      NightCycleService, au moins DawnDelay s après l'aube et MinDayLeft s avant l'alerte (elle a le
--      temps de vivre toute sa vie), au moins MinPlayers joueurs sur le serveur, et aucun camion de
--      l'événement en jeu (tag EventTruck). Une vitrine due attend que ce soit réuni.
--      Où, en zone FortuneTower.Zone (6) :
--        - sur un point tagué `FortuneVaultSpawn` (Attachment, pièce ou Model, dans la map ; au contrat,
--          facultatif, depuis la vague 42 : Contract/Tags) : le pivot de la vitrine (en bas au centre) va sur le
--          point, sa face avant suit l'avant (−Z) du point ;
--        - sinon calculé : au milieu des magasins PNJ de la zone (au milieu de la chaussée), décalé de
--          ComputedOffset studs dans le sens du couloir (de l'arche de la plus petite zone vers celle de la
--          plus grande ; axe X sans deux arches), là où le camion ne se pose pas, face aux joueurs qui
--          arrivent ; sans magasin : ComputedOffset studs après l'arche de la zone. Sol trouvé par un rayon.
--      Le modèle = une copie d'ENV_Event_FortuneVault de Clément (ReplicatedStorage/Assets, sinon
--      ServerStorage/Assets, sous-dossiers permis), vidée de tout script, toutes pièces ancrées, nommée
--      FortuneVault, tag FortuneVault (posé par le code), attributs Zone, VaultNumber, SpawnedAt et EndsAt
--      (heures serveur). Absent : en Studio seulement, un bloc V0 gris et doré fait par le code (vitre
--      Window, HealthBarPoint), avec une ligne dans la sortie ; hors de Studio, pas d'événement (une ligne).
--      Un joueur pris dedans est posé PushMargin studs devant elle. Notify à tous (Messages.Spawned).
--   2. PV partagés : cible d'événement de WindowService (AddTarget, MaxHP, sans régénération), frappée avec
--      les outils et les règles des vitrines (HitController, HitWindow : dégâts du joueur, portée, débit,
--      coup au marqueur Impact) ; barre de PV de FortuneTowerController (attributs HP et MaxHP).
--   3. Fermée sans rien lâcher, avec un Notify : pas cassée au bout de Lifetime s (Messages.Sealed), ou
--      dès que l'alerte de la nuit commence (ou la nuit, si on y saute : Messages.SealedNight).
--   4. À 0 PV (WindowService.OnBroken, Kind « Event ») : ouverte. Sa vitre Window (et ses pièces) devient
--      invisible et ne bloque plus rien, son contour OutlineHighlight s'éteint, attribut OpenedAt (heure
--      serveur, pour un effet de Clément). Butin : LootCount caisses LootTier (Luxe) sur un rayon
--      d'événement de StoreHeistService (AddEventShelf, vague 42, demande de Cantin du 2026-11-14 ; StoreId
--      « Truck_Fortune_<n> », préfixe Truck_ : la convention des colis d'événement sans magasin, GuardService
--      n'envoie pas de vigile ; TelemetryService les compte à part, en « Fortune », vague 39). Un ShelfSlot
--      par point, tourné comme la vitrine : vague 42 (L-145 (c) : on entre dans le coffre), sur les points
--      LootSpawn_01 à _NN du modèle (Attachments ou pièces, à l'intérieur), chacun sur la première surface
--      sous son point, coffre compris (le sol du coffre ; rayon parti LootRayUp studs au-dessus) ; sans point
--      (ou bloc V0) : en rangée devant la face avant (LootDistance, LootSpacing), sur le sol de la rue. Rien
--      d'autre que la vitre ne ferme le coffre : elle cachée, on y entre. Seule la rareté de la caisse est
--      tirée ici (RarityOdds : Mythique et plus, Divine à 0 sans objet Divine) ; tout le reste est celui d'un
--      rayon de magasin : maintien sur E (GrabTime), chance tirée par le serveur, rareté de l'objet
--      (BoxRarityOdds et chance, la rareté de la caisse étant un minimum : la chance ne fait que monter,
--      L-145 (a)), objet des zones LootZones (Secret : toutes zones), effet comme en magasin et taille tirée
--      dans SizeOdds (L-145 (a)), puis GrabItem et portage de l'objet ; ni témoins, ni vigile. Rayon retiré
--      au bout de BoxLifetime s (avec la vitrine). Notify à tous (Messages.Opened). La copie est retirée
--      RemoveDelay s plus tard.
--      Vague 50 (a158, décision de Cantin du 2026-11-14 : le colis porté n'existe plus) : plus aucun colis
--      posé au sol pour être pris fermé (CarryService.PlaceDrop, GrabDropped, portage NPCBox retirés). Sans
--      rayon d'événement (StoreHeistService absent d'un banc, AddEventShelf refusé) : la vitrine s'ouvre sans
--      colis (avertissement si AddEventShelf refuse ; une ligne en Studio si le service manque).
--      Jamais enfermé (vague 42) : quand la vitrine se referme ou est retirée (Seal, fin au temps, alerte,
--      remplacée, retrait après l'ouverture), un joueur dans sa boîte est d'abord posé PushMargin studs
--      devant elle, comme à l'apparition.
--
-- Crochet de test, STUDIO SEULEMENT, même quand Features.FortuneTower = false (pour voir la proposition
-- avant de la valider) : en Play, dans la barre de commande serveur :
--       workspace:SetAttribute("FortuneTest", true)     -- une vitrine tout de suite (remplace celle en jeu)
--       workspace:SetAttribute("FortuneTest", "Open")   -- la vitrine en jeu s'ouvre tout de suite (butin)
--       workspace:SetAttribute("FortuneTest", "Seal")   -- la vitrine en jeu se referme tout de suite
--   Le service lit l'attribut, l'efface et agit, même de nuit ou seul. Hors de Studio, rien n'est écouté.
--
-- API (serveur, vague 39) : Force(« Spawn » | « Open » | « Seal ») → (ok, message), pour AdminService (commande
-- StartEvent, événements Fortune, FortuneOpen, FortuneSeal) et le crochet de test. Le camion
-- (TruckEventService) n'apparaît pas tant qu'une vitrine est en jeu (tag FortuneVault). Posé par ce service, lu par FortuneTowerController : le tag FortuneVault et les
-- attributs de la vitrine (plus haut ; WindowId, MaxHP, HP et Broken venant de WindowService), les
-- attributs FortuneBox et Tier de ses colis au sol.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local FortuneTower = require(Shared.Config.FortuneTower)
local Rarities = require(Shared.Config.Rarities)
local Find = require(Shared.Contract.Find)
local Net = require(Shared.Net.Net)

local NightCycleService = require(script.Parent.NightCycleService)
local WindowService = require(script.Parent.WindowService)

type Vault = {
	Number: number,
	Model: Model,
	WindowId: string,
	EndsAt: number, -- os.clock()
	State: "Active" | "Open",
}



-- Noms proposés à Clément (Contract/Models.FortuneVault, facultatif ; L-108 point 8).
local VAULT_ASSET = "ENV_Event_FortuneVault"
local WINDOW_NAME = "Window"
local HEALTH_BAR_POINT = "HealthBarPoint"
local LOOT_SPAWN_FORMAT = "LootSpawn_%02d"
local OUTLINE_NAME = "OutlineHighlight"
local SPAWN_TAG = "FortuneVaultSpawn" -- point d'apparition, au contrat depuis la vague 42 (Contract/Tags, facultatif)
-- Lus ailleurs.
local ASSETS_NAME = "Assets"
local STORE_TAG = "NPCStore"
local ZONE_GATE_TAG = "ZoneGate"

local TRUCK_TAG = "EventTruck" -- camion en jeu (TruckEventService)

local ZONE_ATTRIBUTE = "Zone"
local INBOX_NAME = "_INBOX_CLEMENT"
local SANDBOX_NAME = "_SANDBOX_IRONIX"
local DROPS_FOLDER = "CarryDrops"
-- Posés par ce service, lus par FortuneTowerController (mêmes noms là-bas).
local VAULT_NAME = "FortuneVault" -- jamais « ENV_… » dans la map : c'est le nom de l'asset (ContractChecker)
local VAULT_TAG = "FortuneVault"
local NUMBER_ATTRIBUTE = "VaultNumber"
local SPAWNED_AT_ATTRIBUTE = "SpawnedAt"
local ENDS_AT_ATTRIBUTE = "EndsAt"
local OPENED_AT_ATTRIBUTE = "OpenedAt"
local TEST_ATTRIBUTE = "FortuneTest" -- Studio seulement, voir l'en-tête
local STORE_PREFIX = "Truck_Fortune_"

-- V0 proposé, absent du doc : après TruckEventService (130), dont il regarde le camion.
local PRIORITY = 135
-- V0 proposé, absent du doc : horaire revu 10 fois par seconde (comme le camion).
local TICK = 0.1
local GROUND_RAY_UP = 20
local GROUND_RAY_DOWN = 40
local PUSH_HEIGHT = 3 -- HumanoidRootPart d'un R15 au-dessus du sol

local IS_STUDIO = RunService:IsStudio()
local ENABLED: boolean = Features.FortuneTower == true
-- Le crochet de test marche en Studio même coupé : le reste du service doit alors l'écouter aussi.
local LISTENING = ENABLED or IS_STUDIO

local FortuneTowerService = {}
FortuneTowerService.Priority = PRIORITY

local current: Vault? = nil
local vaultCount = 0
local nextSpawnAt = math.huge -- os.clock() ; posé au Start
local dayStartedAt = -math.huge

local warned: { [string]: boolean } = {}
local random = Random.new()

-- Outils ----------------------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[FortuneTowerService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[FortuneTowerService] {message}`)
end


-- Vague 42 : StoreHeistService (rayons d'événement), chargé dans Init, protégé (les bancs d'avant ne l'ont pas).
type HeistApi = {
	AddEventShelf: (options: any) -> Model?,
	RemoveEventShelf: (id: string) -> boolean,
}
local heistApi: HeistApi? = nil

-- Retire le rayon d'événement de la vitrine (colis pas ouverts, objets pas pris), s'il y en a un.
local function removeShelf(vault: Vault)
	local api = heistApi
	if api then
		pcall(api.RemoveEventShelf, `{STORE_PREFIX}{vault.Number}`)
	end
end

local function notifyAll(message: string)
	Net.Server.Notify:FireAll(message, FortuneTower.NotifyKind)
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

local function frameOf(instance: Instance): CFrame?
	if instance:IsA("Attachment") then
		return (instance :: Attachment).WorldCFrame
	elseif instance:IsA("PVInstance") then
		return (instance :: PVInstance):GetPivot()
	end
	return nil
end

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

-- Place ---------------------------------------------------------------------------------------------

-- Hauteur du sol sous `position` ; personnages, colis au sol, vitrine et camions ignorés. Vague 42 :
-- `inside` (point LootSpawn_NN dans le coffre) : rayon parti `rayUp` studs au-dessus du point, vitrine
-- comprise (son sol), sauf `ignore` (le point lui-même, s'il est une pièce), et nil quand rien n'est
-- trouvé dessous.
local function castGround(position: Vector3, rayUp: number, inside: boolean, ignore: Instance?): number?
	local exclude: { Instance } = {}
	if ignore then
		table.insert(exclude, ignore)
	end
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
	local tags: { string } = if inside then { TRUCK_TAG } else { VAULT_TAG, TRUCK_TAG }
	for _, tag in tags do
		for _, instance in CollectionService:GetTagged(tag) do
			table.insert(exclude, instance)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local origin = Vector3.new(position.X, position.Y + rayUp, position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(rayUp + GROUND_RAY_DOWN), 0), params)
	return if result then result.Position.Y else nil
end

local function groundY(position: Vector3, fallbackY: number): number
	return castGround(position, GROUND_RAY_UP, false) or fallbackY
end

-- Sens du couloir, à plat (même règle que TruckEventService), et position de l'arche de `zone`.
local function corridor(zone: number): (Vector3, Vector3?)
	local first: Vector3?, last: Vector3?, gate: Vector3? = nil, nil, nil
	local firstZone, lastZone = math.huge, -math.huge
	for _, instance in CollectionService:GetTagged(ZONE_GATE_TAG) do
		local z = zoneOf(instance)
		local frame = frameOf(instance)
		if z and frame and inMap(instance) then
			if z < firstZone then
				firstZone, first = z, frame.Position
			end
			if z > lastZone then
				lastZone, last = z, frame.Position
			end
			if z == zone then
				gate = frame.Position
			end
		end
	end
	if first and last and firstZone < lastZone then
		local d = last - first
		local flat = Vector3.new(d.X, 0, d.Z)
		if flat.Magnitude > 1e-3 then
			return flat.Unit, gate
		end
	end
	return Vector3.xAxis, gate
end

-- Pivot de la vitrine (voir l'en-tête, point 1), ou nil.
local function spawnFrame(): CFrame?
	local zone = FortuneTower.Zone
	local points: { CFrame } = {}
	for _, instance in CollectionService:GetTagged(SPAWN_TAG) do
		local frame = frameOf(instance)
		if frame and inMap(instance) then
			table.insert(points, frame)
		end
	end
	if #points > 0 then
		return points[random:NextInteger(1, #points)]
	end
	local direction, gate = corridor(zone)
	local sum, count = Vector3.zero, 0
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		local frame = frameOf(store)
		if frame and zoneOf(store) == zone and inMap(store) then
			sum += frame.Position
			count += 1
		end
	end
	local center: Vector3
	if count > 0 then
		center = sum / count
	elseif gate then
		center = gate
	else
		return nil
	end
	local spot = center + direction * FortuneTower.ComputedOffset
	local position = Vector3.new(spot.X, groundY(spot, center.Y), spot.Z)
	return CFrame.lookAt(position, position - direction) -- face avant (−Z) vers les joueurs qui arrivent
end

-- Modèle de Clément, ou nil.
local function findTemplate(): Model?
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild(ASSETS_NAME)
		local found = if assets then assets:FindFirstChild(VAULT_ASSET, true) else nil
		if found and found:IsA("Model") then
			return found :: Model
		end
	end
	return nil
end

-- Bloc V0 (Studio seulement) : socle, cadre doré, vitre Window, HealthBarPoint ; pivot en bas au centre.
local function buildV0(): Model
	local w, h, d = FortuneTower.V0Width, FortuneTower.V0Height, FortuneTower.V0Depth
	local model = Instance.new("Model")
	model.Name = VAULT_ASSET .. "_V0"
	local function block(name: string, size: Vector3, center: Vector3, color: Color3, material: Enum.Material, transparency: number): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.CFrame = CFrame.new(center)
		part.Color = color
		part.Material = material
		part.Transparency = transparency
		part.Parent = model
		return part
	end
	local gold = Color3.fromRGB(255, 194, 26)
	local base = block("Base", Vector3.new(w, 1, d), Vector3.new(0, 0.5, 0), Color3.fromRGB(70, 70, 80), Enum.Material.SmoothPlastic, 0)
	block("Top", Vector3.new(w, 1, d), Vector3.new(0, h - 0.5, 0), gold, Enum.Material.Metal, 0)
	block("Back", Vector3.new(w, h - 2, 1), Vector3.new(0, h / 2, d / 2 - 0.5), gold, Enum.Material.Metal, 0)
	block("SideLeft", Vector3.new(1, h - 2, d), Vector3.new(-w / 2 + 0.5, h / 2, 0), gold, Enum.Material.Metal, 0)
	block("SideRight", Vector3.new(1, h - 2, d), Vector3.new(w / 2 - 0.5, h / 2, 0), gold, Enum.Material.Metal, 0)
	block("Treasure", Vector3.new(6, 6, 4), Vector3.new(0, 4, 0), Rarities.ById.Mythic.Color, Enum.Material.Neon, 0)
	block(WINDOW_NAME, Vector3.new(w - 2, h - 2, 0.5), Vector3.new(0, h / 2, -d / 2 + 0.25), Color3.fromRGB(170, 220, 255), Enum.Material.Glass, 0.5)
	local point = Instance.new("Attachment")
	point.Name = HEALTH_BAR_POINT
	point.Position = Vector3.new(0, h + 2, 0) - base.Position -- dans le repère du socle
	point.Parent = base
	model.PrimaryPart = base
	base.PivotOffset = CFrame.new(0, -0.5, 0)
	return model
end

-- Joueur pris dans la vitrine (`why` : à son apparition, ou quand elle se referme ou est retirée, vague
-- 42) : posé PushMargin studs devant elle, au sol.
local function pushOut(model: Model, why: string)
	local pivot = model:GetPivot()
	local cframe, size = model:GetBoundingBox()
	local front = pivot.LookVector
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local character = player.Character
		if root and character and insideBox(cframe, size, root.Position) then
			local spot = cframe.Position + front * (size.Z / 2 + FortuneTower.PushMargin)
			local y = groundY(spot, pivot.Position.Y) + PUSH_HEIGHT
			character:PivotTo(CFrame.new(spot.X, y, spot.Z) * root.CFrame.Rotation)
			log(`{player.Name} était dans la vitrine {why} : posé devant elle`)
		end
	end
end

-- Vitrine ---------------------------------------------------------------------------------------------

local function removeVault(vault: Vault, message: string?)
	if current ~= vault then
		return
	end
	current = nil
	WindowService.RemoveTarget(vault.WindowId)
	pushOut(vault.Model, "quand elle s'est refermée") -- vague 42 : jamais enfermé
	removeShelf(vault)
	vault.Model:Destroy()
	if message then
		notifyAll(message)
	end
end

local function spawnVault(): boolean
	local template = findTemplate()
	local model: Model
	if template then
		local copy = template:Clone() :: Model? -- nil si le modèle n'est pas Archivable
		if copy == nil then
			warnOnce("archivable", `{template:GetFullName()} n'est pas Archivable : pas de vitrine`)
			return false
		end
		model = copy
	elseif IS_STUDIO then
		warnOnce("v0", `{VAULT_ASSET} pas encore rangé dans ReplicatedStorage/{ASSETS_NAME} : bloc V0 (Studio seulement)`)
		model = buildV0()
	else
		warnOnce("template", `{VAULT_ASSET} introuvable dans ReplicatedStorage/{ASSETS_NAME} (ni ServerStorage) : pas de vitrine`)
		return false
	end
	local frame = spawnFrame()
	if frame == nil then
		model:Destroy()
		warnOnce("frame", `zone {FortuneTower.Zone} : ni point {SPAWN_TAG}, ni magasin, ni arche dans la map : pas de vitrine`)
		return false
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy() -- jamais de script dans un modèle (CLAUDE.md)
		elseif descendant:IsA("BasePart") then
			(descendant :: BasePart).Anchored = true
		end
	end
	vaultCount += 1
	local serverNow = Workspace:GetServerTimeNow()
	model.Name = VAULT_NAME
	model:SetAttribute(ZONE_ATTRIBUTE, FortuneTower.Zone)
	model:SetAttribute(NUMBER_ATTRIBUTE, vaultCount)
	model:SetAttribute(SPAWNED_AT_ATTRIBUTE, serverNow)
	model:SetAttribute(ENDS_AT_ATTRIBUTE, serverNow + FortuneTower.Lifetime)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:PivotTo(frame)
	model.Parent = Workspace
	CollectionService:AddTag(model, VAULT_TAG)
	local windowId = WindowService.AddTarget(model, FortuneTower.MaxHP)
	if windowId == nil then
		model:Destroy()
		return false
	end
	pushOut(model, "à son apparition")
	current = {
		Number = vaultCount,
		Model = model,
		WindowId = windowId,
		EndsAt = os.clock() + FortuneTower.Lifetime,
		State = "Active",
	}
	notifyAll(FortuneTower.Messages.Spawned)
	local p = frame.Position
	log(
		`vitrine n° {vaultCount} en zone {FortuneTower.Zone} ({math.round(p.X)}, {math.round(p.Y)}, {math.round(p.Z)}), {FortuneTower.MaxHP} PV, se referme dans {FortuneTower.Lifetime} s`
	)
	return true
end

-- Tirage d'une clé dans une table de pour cent ({ [Id] = % }), dans l'ordre de `order`, ou nil.
local function roll(odds: { [string]: number }, order: { string }): string?
	local total = 0
	for _, id in order do
		total += math.max(odds[id] or 0, 0)
	end
	if total <= 0 then
		return nil
	end
	local value = random:NextNumber() * total
	local last: string? = nil
	for _, id in order do
		local weight = math.max(odds[id] or 0, 0)
		if weight > 0 then
			last = id
			if value < weight then
				return id
			end
			value -= weight
		end
	end
	return last
end

local RARITY_ORDER: { string } = {}
for _, rarity in Rarities.List do
	table.insert(RARITY_ORDER, rarity.Id)
end
-- Points au sol du butin : LootSpawn_NN du modèle, posé sur la première surface sous lui, coffre compris
-- (vague 42 : son sol, à l'intérieur), sinon une rangée devant sa face avant, sur le sol de la rue.
local function lootPoints(model: Model, count: number): { Vector3 }
	local pivot = model:GetPivot()
	local cframe, size = model:GetBoundingBox()
	local front = pivot.LookVector
	local right = pivot.RightVector
	local rowCenter = cframe.Position + front * (size.Z / 2 + FortuneTower.LootDistance)
	local points: { Vector3 } = {}
	for index = 1, count do
		local spawnPoint = Find.path(model, string.format(LOOT_SPAWN_FORMAT, index))
		local frame = if spawnPoint then frameOf(spawnPoint) else nil
		if frame then
			local spot = frame.Position
			local own: Instance? = if spawnPoint and spawnPoint:IsA("PVInstance") then spawnPoint else nil
			local y = castGround(spot, FortuneTower.LootRayUp, true, own) or groundY(spot, pivot.Position.Y)
			table.insert(points, Vector3.new(spot.X, y, spot.Z))
			continue
		end
		local spot = rowCenter + right * ((index - (count + 1) / 2) * FortuneTower.LootSpacing)
		table.insert(points, Vector3.new(spot.X, groundY(spot, pivot.Position.Y), spot.Z))
	end
	return points
end

local function openVault(vault: Vault, breaker: Player?)
	if current ~= vault or vault.State ~= "Active" then
		return
	end
	vault.State = "Open"
	local model = vault.Model
	local window = Find.path(model, WINDOW_NAME)
	if window then
		local parts: { Instance } = if window:IsA("BasePart") then { window } else {}
		for _, descendant in window:GetDescendants() do
			table.insert(parts, descendant)
		end
		for _, instance in parts do
			if instance:IsA("BasePart") then
				local part = instance :: BasePart
				part.Transparency = 1
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			end
		end
	end
	local outline = model:FindFirstChild(OUTLINE_NAME, true)
	if outline and outline:IsA("Highlight") then
		(outline :: Highlight).Enabled = false
	end
	model:SetAttribute(OPENED_AT_ATTRIBUTE, Workspace:GetServerTimeNow())

	local storeId = `{STORE_PREFIX}{vault.Number}`
	local tier = FortuneTower.LootTier
	local points = lootPoints(model, FortuneTower.LootCount)
	local placed: { string } = {}
	-- Vague 42 (demande de Cantin) : colis à ouvrir sur place, comme sur un rayon (StoreHeistService).
	-- Vague 50 (a158, Cantin 2026-11-14) : plus aucun colis posé au sol pour être porté fermé ; sans rayon
	-- d'événement, la vitrine s'ouvre sans colis.
	local spots: { any } = {}
	local rotation = model:GetPivot().Rotation
	for _, point in points do
		local rarity = roll(FortuneTower.RarityOdds, RARITY_ORDER)
		if rarity then
			table.insert(spots, { CFrame = CFrame.new(point) * rotation, Tier = tier, Rarity = rarity })
			table.insert(placed, rarity)
		end
	end
	local addShelf = if heistApi then heistApi.AddEventShelf else nil
	local shelf = if addShelf and #spots > 0
		then addShelf({
			Id = storeId,
			Zone = FortuneTower.Zone,
			ItemZones = FortuneTower.LootZones,
			SizeOdds = FortuneTower.SizeOdds,
			Spots = spots,
			Lifetime = FortuneTower.BoxLifetime,
		})
		else nil
	if shelf == nil then
		if #spots > 0 and addShelf then
			warnOnce("noshelf", "StoreHeistService.AddEventShelf a refusé le rayon d'événement : la vitrine s'ouvre sans colis")
		elseif #spots > 0 then
			log("StoreHeistService.AddEventShelf indisponible : la vitrine s'ouvre sans colis (plus de colis porté)")
		end
		table.clear(placed)
	end
	notifyAll(FortuneTower.Messages.Opened)
	log(
		`vitrine n° {vault.Number} cassée{if breaker then " par " .. breaker.Name else ""} : {#placed} colis {tier} à ouvrir sur place (caisses {table.concat(placed, ", ")})`
	)
	task.delay(FortuneTower.RemoveDelay, function()
		if current == vault then
			current = nil
		end
		removeShelf(vault)
		if model.Parent ~= nil then
			pushOut(model, "à son retrait") -- vague 42 : jamais enfermé
			model:Destroy()
		end
	end)
end

-- Horaire ---------------------------------------------------------------------------------------------

local function randomInterval(): number
	local low = math.max(FortuneTower.SpawnIntervalMin, 0)
	local high = math.max(FortuneTower.SpawnIntervalMax, low)
	return low + random:NextNumber() * (high - low)
end

-- Raison pour laquelle une vitrine due attend encore, ou nil si elle peut apparaître.
local function spawnBlocker(): string?
	if #Players:GetPlayers() < FortuneTower.MinPlayers then
		return "pas assez de joueurs"
	end
	for _, truck in CollectionService:GetTagged(TRUCK_TAG) do
		if truck:IsDescendantOf(Workspace) then
			return "camion en jeu"
		end
	end
	if not Features.NightCycle then
		return nil
	end
	if NightCycleService.GetPhase() ~= "Day" then
		return "pas le jour"
	end
	if NightCycleService.GetPhaseEndsAt() - Workspace:GetServerTimeNow() < FortuneTower.MinDayLeft then
		return "alerte de la nuit trop proche"
	end
	if os.clock() - dayStartedAt < FortuneTower.DawnDelay then
		return "aube trop proche"
	end
	return nil
end

local function step()
	local now = os.clock()
	local vault = current
	if vault then
		if vault.Model.Parent == nil then
			current = nil -- retirée par quelqu'un d'autre
		elseif vault.State == "Active" and now >= vault.EndsAt then
			log(`vitrine n° {vault.Number} pas cassée en {FortuneTower.Lifetime} s : refermée`)
			removeVault(vault, FortuneTower.Messages.Sealed)
		end
		return
	end
	if not ENABLED or now < nextSpawnAt or spawnBlocker() ~= nil then
		return
	end
	nextSpawnAt = now + randomInterval()
	spawnVault()
end

local function onPhaseChanged(phase: string, previous: string)
	if phase == "Day" and previous == "Night" then
		dayStartedAt = os.clock()
		return
	end
	local vault = current
	if (phase == "Warning" or phase == "Night") and vault and vault.State == "Active" then
		log(`vitrine n° {vault.Number} refermée : {phase}`)
		removeVault(vault, FortuneTower.Messages.SealedNight)
	end
end

local function onBroken(info: WindowService.BreakInfo)
	local vault = current
	if info.Kind ~= "Event" or vault == nil or info.Model ~= vault.Model then
		return
	end
	openVault(vault, info.Breaker)
end

-- Lancer, ouvrir, refermer à la main (crochet de test et AdminService) ----------------------------------

-- Vague 39 : « Spawn » (une vitrine tout de suite, remplace celle en jeu), « Open » (la vitrine fermée en jeu
-- s'ouvre, butin) ou « Seal » (elle se referme sans rien lâcher), même de nuit ou seul. Refusé quand le
-- service n'écoute pas (hors de Studio avec Features.FortuneTower = false : ni casse ni colis branchés).
-- Renvoie ok et un message en anglais (texte du jeu, montré à l'admin).
function FortuneTowerService.Force(action: string): (boolean, string)
	if not LISTENING then
		return false, "Fortune Tower is off (Features.FortuneTower)."
	end
	local vault = current
	if action == "Open" or action == "Seal" then
		if vault == nil or vault.State ~= "Active" then
			return false, "No closed Fortune vault in play."
		end
		if action == "Open" then
			WindowService.RemoveTarget(vault.WindowId) -- plus aucun coup
			openVault(vault, nil)
			return true, `Fortune vault {vault.Number} opened`
		end
		removeVault(vault, FortuneTower.Messages.Sealed)
		return true, `Fortune vault {vault.Number} sealed`
	elseif action == "Spawn" then
		if vault then
			removeVault(vault, nil)
		end
		if not spawnVault() then
			return false, "No Fortune vault could spawn (see the output)."
		end
		return true, `Fortune vault {vaultCount} spawned`
	end
	return false, "Unknown Fortune Tower action."
end

-- Crochet de test (Studio seulement) ------------------------------------------------------------------

local function onTest()
	local value = Workspace:GetAttribute(TEST_ATTRIBUTE)
	if value == nil or value == false or value == "" then
		return
	end
	Workspace:SetAttribute(TEST_ATTRIBUTE, nil)
	local word = if type(value) == "string" then string.lower((string.gsub(value, "%s", ""))) else nil
	if word == "open" or word == "seal" then
		if not FortuneTowerService.Force(if word == "open" then "Open" else "Seal") then
			warn(`[FortuneTowerService] {TEST_ATTRIBUTE} = {value} : aucune vitrine fermée en jeu`)
		end
		return
	end
	if value ~= true and word ~= "spawn" then
		warn(`[FortuneTowerService] {TEST_ATTRIBUTE} = {value} : attendu true, "Open" ou "Seal"`)
		return
	end
	FortuneTowerService.Force("Spawn")
end

-- Démarrage -----------------------------------------------------------------------------------------

function FortuneTowerService.Init()
	if not LISTENING then
		return
	end
	local module = script.Parent:FindFirstChild("StoreHeistService")
	if module and module:IsA("ModuleScript") then
		local ok, api = pcall(require, module)
		if ok and type(api) == "table" and type((api :: any).AddEventShelf) == "function" then
			heistApi = api :: any
		end
	end
	if heistApi == nil then
		log("StoreHeistService.AddEventShelf indisponible : la vitrine s'ouvrira sans colis (plus de colis porté)")
	end
	WindowService.OnBroken(onBroken)
	NightCycleService.OnPhaseChanged(onPhaseChanged)
end

function FortuneTowerService.Start()
	if not ENABLED then
		local test = if IS_STUDIO then ` ; test Studio : workspace:SetAttribute("{TEST_ATTRIBUTE}", true)` else ""
		print(`[FortuneTowerService] événement Fortune Tower coupé (Features.FortuneTower = false) : aucune vitrine automatique{test}`)
		if not LISTENING then
			return
		end
	else
		nextSpawnAt = os.clock() + randomInterval()
		local delivered = if findTemplate() then VAULT_ASSET else `{VAULT_ASSET} pas encore rangé dans Assets`
		print(
			`[FortuneTowerService] événement Fortune Tower : une vitrine toutes les {FortuneTower.SpawnIntervalMin} à {FortuneTower.SpawnIntervalMax} s, de jour, {FortuneTower.MaxHP} PV ; {delivered}`
		)
	end
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(onTest)
	end
	while true do
		task.wait(TICK)
		xpcall(step, function(err: any)
			warn(`[FortuneTowerService] tick : {err}\n{debug.traceback()}`)
		end)
	end
end

return FortuneTowerService
