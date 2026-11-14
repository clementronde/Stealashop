--!strict
-- FortuneTowerService (liaison L-108 point 8, idée de Clément du 2026-11-12 ; vague 37, a123 ; pas encore
-- une tâche du backlog) : l'événement de la Fortune Tower. Valeurs : Config/FortuneTower (toutes V0
-- proposées, absentes du doc) ; interrupteur : Config/Features.FortuneTower, false tant que Clément n'a
-- pas validé. Modèle : TruckEventService (événement à plusieurs, PV partagés, butin au sol).
--
-- Une seule vitrine à la fois :
--   1. Apparition (Features.FortuneTower seulement), SpawnIntervalMin à SpawnIntervalMax s (tiré au
--      hasard) après la précédente ou le démarrage du serveur, quand tout est réuni : phase Day de
--      NightCycleService, au moins DawnDelay s après l'aube et MinDayLeft s avant l'alerte (elle a le
--      temps de vivre toute sa vie), au moins MinPlayers joueurs sur le serveur, et aucun camion de
--      l'événement en jeu (tag EventTruck). Une vitrine due attend que ce soit réuni.
--      Où, en zone FortuneTower.Zone (6) :
--        - sur un point tagué `FortuneVaultSpawn` (Attachment, pièce ou Model, dans la map ; nom proposé à
--          Clément, hors contrat, comme TruckSpawn) : le pivot de la vitrine (en bas au centre) va sur le
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
--      serveur, pour un effet de Clément). Butin tiré par le serveur à ce moment-là : LootCount colis
--      LootTier (Luxe), chacun : rareté selon RarityOdds (Mythique et plus, Divine à 0 sans objet Divine),
--      objet par Items.Pick(LootZone, …), repli sur la rareté tirable la plus proche en dessous dans ce
--      butin (sinon le colis est sauté) ; taille Huge ou Colossal selon SizeOdds, effet par Mutations.Roll
--      (comme sur un rayon). Posés au sol tout de suite (CarryService.PlaceDrop, BoxLifetime s), sur les
--      points LootSpawn_01 à _NN du modèle (Attachments ou pièces ; projetés au sol), sinon en rangée devant
--      la face avant (LootDistance, LootSpacing). Colis PNJ ordinaires : StoreId « Truck_Fortune_<n> »
--      (préfixe Truck_ : la convention des colis d'événement sans magasin, GuardService n'envoie pas de
--      vigile, StoreHeistService n'a rien à remettre en rayon ; TelemetryService les compte à part, en « Fortune », vague 39),
--      SlotId « Truck_Fortune_<n>/<kk> », attributs FortuneBox et Tier (lus par FortuneTowerController).
--      Notify à tous (Messages.Opened). La copie est retirée RemoveDelay s plus tard.
--   5. Colis au sol : GrabDropped(dropId) (9.4), en deux appels comme les colis du camion (début du
--      maintien, puis invite déclenchée), mêmes règles que TruckEventService : colis encore au sol, mains
--      vides, joueur vivant, hors zone safe (tag SafeZone), à Bat.DroppedGrabMaxDistance studs au plus,
--      maintien du temps de prise de son type (Balance.Heist.BoxTiers[Tier].GrabTime), revérifiés 10 fois
--      par seconde. Alors CarryService.PickUpDrop : porté, c'est un colis PNJ ordinaire (batte, lâcher,
--      rangement à l'entrée de la zone safe, ouverture : les règles existantes). Pas ramassé : il disparaît
--      BoxLifetime s après la casse. Ce service ne traite GrabDropped que pour ses colis.
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
local Balance = require(Shared.Config.Balance)
local Bat = require(Shared.Config.Bat)
local Features = require(Shared.Config.Features)
local FortuneTower = require(Shared.Config.FortuneTower)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Find = require(Shared.Contract.Find)
local Net = require(Shared.Net.Net)
local CarryTypes = require(Shared.Types.Carry)

local CarryService = require(script.Parent.CarryService)
local NightCycleService = require(script.Parent.NightCycleService)
local WindowService = require(script.Parent.WindowService)

type Vault = {
	Number: number,
	Model: Model,
	WindowId: string,
	EndsAt: number, -- os.clock()
	State: "Active" | "Open",
}

type Box = { DropId: string, Tier: string }
type Hold = { DropId: string, StartedAt: number }
type Loot = { Rarity: string, ItemId: string, Mutation: Mutations.Mutation? }

-- Noms proposés à Clément (Contract/Models.FortuneVault, facultatif ; L-108 point 8).
local VAULT_ASSET = "ENV_Event_FortuneVault"
local WINDOW_NAME = "Window"
local HEALTH_BAR_POINT = "HealthBarPoint"
local LOOT_SPAWN_FORMAT = "LootSpawn_%02d"
local OUTLINE_NAME = "OutlineHighlight"
local SPAWN_TAG = "FortuneVaultSpawn" -- point d'apparition, hors contrat (comme TruckSpawn)
-- Lus ailleurs.
local ASSETS_NAME = "Assets"
local STORE_TAG = "NPCStore"
local ZONE_GATE_TAG = "ZoneGate"
local SAFE_ZONE_TAG = "SafeZone"
local TRUCK_TAG = "EventTruck" -- camion en jeu (TruckEventService)
local BOUNDS_NAME = "Bounds"
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
local BOX_ATTRIBUTE = "FortuneBox"
local TIER_ATTRIBUTE = "Tier"
local TEST_ATTRIBUTE = "FortuneTest" -- Studio seulement, voir l'en-tête
local STORE_PREFIX = "Truck_Fortune_"

-- V0 proposé, absent du doc : après TruckEventService (130), dont il regarde le camion.
local PRIORITY = 135
-- V0 proposé, absent du doc : horaire et maintiens revus 10 fois par seconde (comme le camion).
local TICK = 0.1
-- V0 proposé, absent du doc : mêmes tolérances que les colis du camion (TruckEventService).
local GRAB_TIME_TOLERANCE = 0.1
local HOLD_EXPIRY = 1
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
local boxes: { [string]: Box } = {}
local holds: { [Player]: Hold } = {}
local lastRefusal: { [Player]: number } = {}
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

local function refuse(player: Player, dropId: string, reason: string)
	if not IS_STUDIO then
		return
	end
	local now = os.clock()
	if now - (lastRefusal[player] or -math.huge) < 1 then
		return
	end
	lastRefusal[player] = now
	warn(`[FortuneTowerService] GrabDropped de {player.Name} sur « {dropId} » refusé : {reason}`)
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

-- Même règle que TruckEventService et GuardService : la pièce taguée, son enfant Bounds, ou la boîte du modèle.
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
			local cframe, size = (instance :: Model):GetBoundingBox()
			if insideBox(cframe, size, position) then
				return true
			end
		end
	end
	return false
end

-- Place ---------------------------------------------------------------------------------------------

-- Hauteur du sol sous `position` ; personnages, colis au sol, vitrine et camions ignorés.
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
	for _, tag in { VAULT_TAG, TRUCK_TAG } do
		for _, instance in CollectionService:GetTagged(tag) do
			table.insert(exclude, instance)
		end
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

-- Joueur pris dans la vitrine à son apparition : posé PushMargin studs devant elle, au sol.
local function pushOut(model: Model)
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
			log(`{player.Name} était dans la vitrine à son apparition : posé devant elle`)
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
	pushOut(model)
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
local SIZE_ORDER: { string } = {}
for _, size in Mutations.Sizes do
	table.insert(SIZE_ORDER, size.Id)
end

-- Un colis du butin, ou nil (aucun objet tirable). Repli : la rareté tirable la plus proche en dessous,
-- parmi celles du butin (Divine sans objet → Secret ; Secret sans objet → Mythique).
local function drawLoot(): Loot?
	local rarity = roll(FortuneTower.RarityOdds, RARITY_ORDER)
	if rarity == nil then
		return nil
	end
	local order = Rarities.ById[rarity].Order
	for index = #Rarities.List, 1, -1 do
		local candidate = Rarities.List[index]
		if candidate.Order <= order and FortuneTower.RarityOdds[candidate.Id] ~= nil then
			local item = Items.Pick(FortuneTower.LootZone, candidate.Id, random)
			if item and not item.TutorialOnly then
				if candidate.Id ~= rarity then
					warnOnce(`empty.{rarity}`, `aucun objet {rarity} tirable : ce colis de la vitrine reçoit un objet {candidate.Id}`)
				end
				local effect = Mutations.Roll(random)
				local mutation: Mutations.Mutation = {
					Size = roll(FortuneTower.SizeOdds, SIZE_ORDER),
					Effect = if effect then effect.Effect else nil,
				}
				local rarityId: string = item.Rarity
				local loot: Loot = { Rarity = rarityId, ItemId = item.Id, Mutation = Mutations.Sanitize(mutation) }
				return loot
			end
		end
	end
	return nil
end

-- Points au sol du butin : LootSpawn_NN du modèle, sinon une rangée devant sa face avant.
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
		local spot = if frame
			then frame.Position
			else rowCenter + right * ((index - (count + 1) / 2) * FortuneTower.LootSpacing)
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
	for index, point in points do
		local loot = drawLoot()
		if loot == nil then
			warnOnce("draw", `aucun objet ne peut sortir de la vitrine (Config/FortuneTower, Config/Items) : colis sauté`)
			continue
		end
		local payload: CarryTypes.NPCBoxPayload = {
			Kind = "NPCBox",
			Tier = tier :: CarryTypes.BoxTier,
			Zone = FortuneTower.LootZone,
			Rarity = loot.Rarity,
			ItemId = loot.ItemId,
			StoreId = storeId,
			SlotId = `{storeId}/{string.format("%02d", index)}`,
			Mutation = loot.Mutation,
		}
		local attributes: { [string]: any } = { [BOX_ATTRIBUTE] = true, [TIER_ATTRIBUTE] = tier }
		local dropId = CarryService.PlaceDrop(payload, point, FortuneTower.BoxLifetime, attributes)
		if dropId then
			boxes[dropId] = { DropId = dropId, Tier = tier }
			local label = Mutations.Label(loot.Mutation)
			table.insert(placed, if label then `{loot.Rarity} {label}` else loot.Rarity)
		end
	end
	notifyAll(FortuneTower.Messages.Opened)
	log(
		`vitrine n° {vault.Number} cassée{if breaker then " par " .. breaker.Name else ""} : {#placed} colis {tier} au sol ({table.concat(placed, ", ")})`
	)
	task.delay(FortuneTower.RemoveDelay, function()
		if current == vault then
			current = nil
		end
		if model.Parent ~= nil then
			model:Destroy()
		end
	end)
end

-- Colis au sol (mêmes règles que les colis du camion, TruckEventService) --------------------------------

local function grabTimeOf(tier: string): number
	local info = Balance.Heist.BoxTiers[tier]
	return if info then info.GrabTime else 0
end

-- Tolérance de portée pendant un maintien (Cantin, 2026-11-14 ; même règle que StoreHeistService, « Portée ») :
-- min(WalkSpeed × (ping + ReachLatencyPad), ReachToleranceMax) studs, WalkSpeed et ping lus sur le serveur.
local function reachPad(player: Player): number
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	-- Lectures protégées (comme pingOf d'AntiCheatService) : les faux Roblox des bancs n'ont pas toujours ces membres.
	local okPing, ping = pcall(function(): number
		return player:GetNetworkPing()
	end)
	local okSpeed, walkSpeed = pcall(function(): number
		return if humanoid then humanoid.WalkSpeed else 0
	end)
	local latency = (if okPing and type(ping) == "number" and ping > 0 then ping else 0) + Balance.Heist.ReachLatencyPad
	local speed = if okSpeed and type(walkSpeed) == "number" and walkSpeed > 0 then walkSpeed else 0
	return math.min(speed * latency, Balance.Heist.ReachToleranceMax)
end

-- `lenient` : début du maintien ou revérification (tolérance reachPad), sinon strict (fin du maintien).
local function grabRefusal(player: Player, box: Box, lenient: boolean): string?
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
	if distance > Bat.DroppedGrabMaxDistance + (if lenient then reachPad(player) else 0) then
		return `trop loin ({math.round(distance * 10) / 10} studs)`
	end
	return nil
end

local function grant(player: Player, box: Box)
	if not CarryService.PickUpDrop(player, box.DropId) then
		refuse(player, box.DropId, "CarryService a refusé le ramassage")
		return
	end
	boxes[box.DropId] = nil
	log(`{player.Name} ramasse le colis {box.Tier} {box.DropId} de la vitrine`)
end

-- GrabDropped(dropId) : premier appel = début du maintien, second = fin.
local function onGrabDropped(player: Player, dropId: string)
	local box = boxes[dropId]
	if box == nil then
		return -- pas un colis de la vitrine : laissé au service qui l'a posé
	end
	local hold = holds[player]
	-- Portée souple au début du maintien, stricte à la fin (règle de StoreHeistService, « Portée »).
	local starting = not (hold ~= nil and hold.DropId == dropId) and grabTimeOf(box.Tier) > 0
	local reason = grabRefusal(player, box, starting)
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
		log(`colis de la vitrine {dropId} jamais ramassé : disparu`)
	end
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
	for player, hold in holds do
		local box = boxes[hold.DropId]
		if box == nil or now - hold.StartedAt > grabTimeOf(box.Tier) + HOLD_EXPIRY or grabRefusal(player, box, true) ~= nil then
			holds[player] = nil
		end
	end
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
	WindowService.OnBroken(onBroken)
	NightCycleService.OnPhaseChanged(onPhaseChanged)
	CarryService.OnDropExpired(onDropExpired)
	Net.Server.GrabDropped:Connect(onGrabDropped)
	Players.PlayerRemoving:Connect(function(player: Player)
		holds[player] = nil
		lastRefusal[player] = nil
	end)
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
