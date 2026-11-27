--!strict
-- ArmoredVanService (GC6, a409, MAJ 6, DEV-133) : la casse du siècle. Valeurs : Config/ArmoredVan ; interrupteur
-- Features.ArmoredVan. Repris de TruckEventService (cible d'événement de WindowService, PV partagés, annonces), sans
-- le toucher : un seul fourgon à la fois, indépendant du camion.
--
--   1. Horaire : départ toutes les Period s, à heure fixe (os.time() multiple de Period, + Offset : l'heure pile et la
--      demie en V0), annoncé WarnBefore s avant (Shared/Announce). Il ne part que de jour (phase Day de
--      NightCycleService) avec au moins TravelTime s avant l'alerte ; sinon il attend le jour suivant (DawnDelay s après
--      l'aube) ; un départ en attente est remplacé par celui de l'heure suivante.
--      a425 (L-318 Q1) : jamais en même temps que le camion (TruckEventService, modèle taggé EventTruck) : un départ dû
--      pendant un camion, ou moins de TruckGap s après lui, attend (annonce DelayedTruck) et part dès que la voie est
--      libre ; dans l'autre sens, TruckEventService demande HoldsTruck() avant chaque camion (pas pendant un fourgon,
--      en jeu ou en attente, ni TruckGap s après lui, ni dans les TruckLead s avant un départ à l'horaire).
--      a425 (L-318 Q2) : attributs du Workspace StateAttribute ("Soon" de l'annonce au départ, "Road" pendant le
--      trajet, absent sinon) et EndsAtAttribute (heure serveur du départ, puis de la fuite) : EventBannerController
--      montre le fourgon et son minuteur dans UI_EventBanner quand aucun événement live n'y est.
--   2. Trajet : de l'arche ZoneGate de la plus petite zone à celle de la plus grande, en TravelTime s à vitesse
--      constante, posé au sol (rayon), l'avant (−Z) dans le sens du trajet. Collisions, contacts et requêtes coupés :
--      il ne pousse ni ne bloque personne. Moins de deux arches dans la map : pas de fourgon (une ligne).
--   3. Modèle : copie de ENV_Event_ArmoredVan de Clément (Assets), vidée de ses scripts, toutes pièces ancrées ; absent :
--      un fourgon en blocs construit ici (VanSize). Nom ArmoredVan, tag ArmoredVan (posés par le code). Barre de vie :
--      copie de BB_ArmoredVanHP (Assets/UI) ou repli construit ici (Title, Bar/Fill, HPText), au point HealthBarPoint
--      ou au-dessus du fourgon, remplie par le serveur (répliquée).
--   4. PV partagés : WindowService.AddTarget(model, PV) ; PV = HPPerDamage × somme des dégâts par coup des joueurs du
--      serveur au départ (ToolService.GetHitDamage), au moins MinHP. Frappé comme le camion (HitController, HitWindow).
--      Dégâts de chacun comptés par WindowService.OnHit.
--   5. Casse (OnBroken) : classement par dégâts (Ranking) ; chaque casseur avec au moins MinShare des PV reçoit un colis
--      de zone (Rewards : top 3 le meilleur, puis selon sa part), UnboxService.GiveZoneBoxItem depuis sa meilleure zone,
--      objet mis dans l'inventaire tout de suite ; Notify à chacun, annonce du top 3 à tous ; retrait RemoveDelay s
--      plus tard. a425 (L-324) : le fourgon s'arrête, sa barre et son contour s'éteignent, attribut ExplodedAt (heure
--      serveur) : ArmoredVanController reprend l'explosion du camion (pièces depuis BlastPoint, Cargo visible, jet de
--      billets à CashPoint). a425 (L-325 réponse 2) : inventaire plein, le colis tombe derrière le fourgon (rayon
--      d'événement StoreHeistService.AddEventShelf, StoreId « Truck_ArmoredVan_<n>_<UserId> », DropLifetime s), à
--      ouvrir par n'importe qui ; rareté tirée ici par la même règle (Shared/ZoneBoxOdds). Sans rayon : perdu (Lost).
--      a509 (L-457, Features.ArmoredVanBurst / ArmoredVanBurstDev et BurstBoxes) : le colis de chaque casseur récompensé jaillit du fourgon (depuis BlastPoint, sinon
--      le centre du modèle) et retombe derrière lui sur ce même rayon d'événement, à ouvrir sur place comme les colis
--      du camion, au lieu d'aller dans l'inventaire ; sans rayon d'événement, l'objet va dans l'inventaire.
--   6. Échappé (fin du trajet ou alerte de la nuit) : annonce, retrait, rien n'est donné.
--
-- Crochet de test, STUDIO SEULEMENT (barre de commande serveur) :
--   workspace:SetAttribute("ArmoredVanNow", true)       -- un fourgon tout de suite (même de nuit)
--   workspace:SetAttribute("ArmoredVanNow", "Break")    -- le fourgon présent est cassé tout de suite (récompenses)
--   workspace:SetAttribute("ArmoredVanNow", "Escape")   -- le fourgon présent s'échappe tout de suite
--
-- API (serveur) :
--   ArmoredVanService.NextDeparture(unix) -> number   heure (os.time) du prochain départ à l'horaire, après unix
--   ArmoredVanService.Ranking(damage, maxHP) -> { Place }   classement pur des casseurs (bancs)
--   ArmoredVanService.MaxHP(damages) -> number        PV du fourgon pour ces dégâts par coup (bancs)
--   ArmoredVanService.IsActive() -> boolean
--   ArmoredVanService.HoldsTruck() -> boolean         a425 : vrai si un camion ne doit pas apparaître maintenant
--   ArmoredVanService.BlocksTruck(untilDeparture, active, waiting, sinceVan) -> boolean   règle pure (bancs)
--   ArmoredVanService.TruckAllowsVan(truckInPlay, sinceTruck) -> boolean                  règle pure (bancs)
--   ArmoredVanService.DropOffsets(count) -> { number }   écarts latéraux des colis tombés (bancs)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ArmoredVan = require(Shared.Config.ArmoredVan)
local Features = require(Shared.Config.Features)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local Announce = require(Shared.Announce)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
local ZoneBoxOdds = require(Shared.ZoneBoxOdds)

local DataService = require(script.Parent.DataService)
local NightCycleService = require(script.Parent.NightCycleService)
local ToolService = require(script.Parent.ToolService)
local UnboxService = require(script.Parent.UnboxService)
local WindowService = require(script.Parent.WindowService)

export type Place = {
	UserId: number,
	Damage: number,
	Share: number, -- part des PV max, de 0 à 1
	Rank: number,
	Tier: ArmoredVan.RewardTier?, -- nil : trop peu de dégâts
}

type Van = {
	Model: Model,
	WindowId: string,
	MaxHP: number,
	From: number, -- os.clock() du départ
	Path: { Vector3 },
	Length: number,
	Damage: { [number]: number }, -- [UserId] = dégâts
	Names: { [number]: string },
	Done: boolean,
	Heartbeat: RBXScriptConnection?,
}

local TAG = "ArmoredVan" -- posé par le code, hors du contrat 2.1
local VAN_NAME = "ArmoredVan"
local ZONE_GATE_TAG = "ZoneGate"
local ZONE_ATTRIBUTE = "Zone"
local HEALTH_BAR_POINT = "HealthBarPoint"
local ASSETS_NAME = "Assets"
local INBOX_NAME = "_INBOX_CLEMENT"
local SANDBOX_NAME = "_SANDBOX_IRONIX"
local TEST_ATTRIBUTE = "ArmoredVanNow" -- Studio seulement
local HP_ATTRIBUTE = "HP" -- posé par WindowService sur la cible
local ENDS_AT_ATTRIBUTE = "EndsAt" -- heure serveur de la fin du trajet (lisible par une UI)
local TICK = 0.5 -- V0 : horaire revu 2 fois par seconde
-- a425 : camion de l'événement (posé par TruckEventService), casse vue par les clients, colis tombés.
local TRUCK_TAG = "EventTruck"
local EXPLODED_AT_ATTRIBUTE = "ExplodedAt" -- heure serveur de la casse, lue par ArmoredVanController
local OUTLINE_NAME = "OutlineHighlight"
local BAR_NAME = "VanHP"
local BLAST_POINT = "BlastPoint"
local DROP_PREFIX = "Truck_ArmoredVan_" -- préfixe Truck_ : ni vigile ni témoin (GuardService), comme la Fortune Tower
local GROUND_RAY_UP = 30 -- V0 : sol cherché de 30 studs au-dessus…
local GROUND_RAY_DOWN = 60 -- … à 60 en dessous du point
local IS_STUDIO = RunService:IsStudio()
local ENABLED: boolean = (Features :: any).ArmoredVan == true
-- a509 (L-457) : colis qui jaillissent, Features.ArmoredVanBurst (partout) ou ArmoredVanBurstDev (jeu DEV, Config/ProductIds
-- chargé s'il est là ; sans lui, jeu PROD), et le réglage Config/ArmoredVan.BurstBoxes. Coupé : inventaire, comme avant.
local IS_DEV: boolean = (function(): boolean
	local ok, ids = pcall(function(): any
		return require(Shared.Config.ProductIds)
	end)
	return ok and type(ids) == "table" and ids.IsDev == true
end)()
local BURST: boolean = ArmoredVan.BurstBoxes == true
	and ((Features :: any).ArmoredVanBurst == true or ((Features :: any).ArmoredVanBurstDev == true and IS_DEV))

local ArmoredVanService = {}
ArmoredVanService.Priority = 135 -- V0 : après NightCycleService (120) et TruckEventService (130)

local van: Van? = nil
local announcedSlot = -1 -- départ déjà annoncé (WarnBefore)
local startedSlot = -1 -- départ déjà fait (ou mis en attente)
local pending = false -- un départ attend le jour
local dayStartedAt = -math.huge -- os.clock() de la dernière aube
local warned: { [string]: boolean } = {}
local truckSeenAt = -math.huge -- a425 : os.clock() du dernier camion vu en jeu
local vanEndedAt = -math.huge -- a425 : os.clock() de la fin du dernier fourgon (cassé ou échappé)
local vanCount = 0
-- a425 : StoreHeistService (AddEventShelf), chargé dans Init, protégé (absent d'un banc : colis perdu).
local heistApi: { AddEventShelf: (options: any) -> Model? }? = nil

-- Un colis gagné qui n'entre pas dans l'inventaire (a425, L-325 réponse 2), ou qui jaillit du fourgon (a509, Burst).
type Drop = { Player: Player, Label: string, Zone: number, Rarity: string, Burst: boolean, Place: Place }

local function log(message: string)
	if IS_STUDIO then
		print(`[ArmoredVanService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[ArmoredVanService] {message}`)
	end
end

local function announce(message: string, detail: string?)
	local ok, problem = pcall(function()
		Announce.send(message, detail, ArmoredVan.AnnounceIcon)
	end)
	if not ok then
		warnOnce("announce", `annonce ratée ({tostring(problem)})`)
	end
end

local function notify(player: Player, message: string, kind: string)
	pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
end

-- Calculs purs (bancs) ------------------------------------------------------------------------------------------

function ArmoredVanService.NextDeparture(unix: number): number
	local period = ArmoredVan.Period
	local offset = ArmoredVan.Offset
	return (math.floor((unix - offset) / period) + 1) * period + offset
end

function ArmoredVanService.MaxHP(damages: { number }): number
	local total = 0
	for _, damage in damages do
		if type(damage) == "number" and damage == damage and damage > 0 and damage < math.huge then
			total += damage
		end
	end
	return math.max(ArmoredVan.MinHP, math.round(ArmoredVan.HPPerDamage * total))
end

function ArmoredVanService.Ranking(damage: { [number]: number }, maxHP: number): { Place }
	local places: { Place } = {}
	for userId, value in damage do
		if type(value) == "number" and value > 0 and value < math.huge then
			table.insert(places, { UserId = userId, Damage = value, Share = math.clamp(value / math.max(maxHP, 1), 0, 1), Rank = 0, Tier = nil })
		end
	end
	table.sort(places, function(a: Place, b: Place): boolean
		if a.Damage ~= b.Damage then
			return a.Damage > b.Damage
		end
		return a.UserId < b.UserId
	end)
	for index, place in places do
		place.Rank = index
		if place.Share >= ArmoredVan.MinShare then
			for _, tier in ArmoredVan.Rewards do
				local byRank = tier.MaxRank ~= nil and index <= tier.MaxRank
				local byShare = tier.MinShare ~= nil and place.Share >= tier.MinShare
				if byRank or byShare then
					place.Tier = tier
					break
				end
			end
		end
	end
	return places
end

-- a425 (L-318 Q1) : un camion peut-il apparaître ? Non pendant un fourgon (active), ni pendant un départ en attente
-- (waiting), ni moins de TruckGap s après la fin du dernier (sinceVan), ni dans les TruckLead s avant un départ.
function ArmoredVanService.BlocksTruck(untilDeparture: number, active: boolean, waiting: boolean, sinceVan: number): boolean
	return active or waiting or sinceVan < ArmoredVan.TruckGap or untilDeparture <= ArmoredVan.TruckLead
end

-- a425 (L-318 Q1) : le fourgon peut-il partir ? Aucun camion en jeu, et le dernier parti depuis TruckGap s au moins.
function ArmoredVanService.TruckAllowsVan(truckInPlay: boolean, sinceTruck: number): boolean
	return not truckInPlay and sinceTruck >= ArmoredVan.TruckGap
end

-- a425 (L-325) : écarts latéraux (studs) de `count` colis côte à côte, centrés derrière le fourgon.
function ArmoredVanService.DropOffsets(count: number): { number }
	local offsets: { number } = {}
	local n = math.max(math.floor(count), 0)
	for index = 1, n do
		table.insert(offsets, (index - (n + 1) / 2) * ArmoredVan.DropSpacing)
	end
	return offsets
end

-- Carte ---------------------------------------------------------------------------------------------------------

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

local function groundY(position: Vector3, exclude: { Instance }): number
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local origin = position + Vector3.new(0, GROUND_RAY_UP, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -(GROUND_RAY_UP + GROUND_RAY_DOWN), 0), params)
	return if result then result.Position.Y else position.Y
end

-- Points du trajet : les arches de zone, de la plus petite à la plus grande, au sol.
local function pathPoints(): { Vector3 }
	local byZone: { [number]: Vector3 } = {}
	local zones: { number } = {}
	for _, gate in CollectionService:GetTagged(ZONE_GATE_TAG) do
		local zone = gate:GetAttribute(ZONE_ATTRIBUTE)
		if type(zone) == "number" and not table.find(zones, zone) and gate:IsA("PVInstance") and inMap(gate) then
			byZone[zone] = (gate :: PVInstance):GetPivot().Position
			table.insert(zones, zone)
		end
	end
	table.sort(zones)
	local points: { Vector3 } = {}
	for _, zone in zones do
		local p = byZone[zone]
		table.insert(points, Vector3.new(p.X, groundY(p, {}), p.Z))
	end
	return points
end

local function pathLength(points: { Vector3 }): number
	local length = 0
	for i = 2, #points do
		length += (points[i] - points[i - 1]).Magnitude
	end
	return length
end

-- Pivot du fourgon à la distance `distance` du début du trajet, avant (−Z) dans le sens du trajet.
local function frameAt(points: { Vector3 }, distance: number): CFrame
	local left = math.max(distance, 0)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local segment = (b - a).Magnitude
		if left <= segment or i == #points then
			local t = if segment > 0 then math.clamp(left / segment, 0, 1) else 0
			local position = a:Lerp(b, t)
			local ahead = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			if ahead.Magnitude < 1e-3 then
				return CFrame.new(position)
			end
			return CFrame.lookAt(position, position + ahead.Unit)
		end
		left -= segment
	end
	return CFrame.new(points[1])
end

-- Modèle --------------------------------------------------------------------------------------------------------

local function findAsset(name: string): Instance?
	for _, service in { ReplicatedStorage, ServerStorage } :: { Instance } do
		local assets = service:FindFirstChild(ASSETS_NAME)
		local found = if assets then assets:FindFirstChild(name, true) else nil
		if found then
			return found
		end
	end
	return nil
end

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

-- Repli : un fourgon en blocs (VanSize), pivot en bas au centre, avant vers −Z.
local function buildFallback(): Model
	local size = ArmoredVan.VanSize
	local model = Instance.new("Model")
	local wheel = size.Y * 0.18
	local root = block(model, "Root", Vector3.new(size.X, 0.2, size.Z), CFrame.new(0, 0.1, 0), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	root.Transparency = 1
	model.PrimaryPart = root
	local bodyHeight = size.Y - wheel
	local cabLength = size.Z * 0.25
	local steel = Color3.fromRGB(70, 76, 84)
	block(model, "Body", Vector3.new(size.X, bodyHeight, size.Z - cabLength), CFrame.new(0, wheel + bodyHeight / 2, cabLength / 2), steel, Enum.Material.DiamondPlate)
	block(model, "Cab", Vector3.new(size.X, bodyHeight * 0.75, cabLength), CFrame.new(0, wheel + bodyHeight * 0.375, -(size.Z - cabLength) / 2), steel, Enum.Material.Metal)
	block(model, "Windshield", Vector3.new(size.X * 0.85, bodyHeight * 0.3, 0.4), CFrame.new(0, wheel + bodyHeight * 0.55, -size.Z / 2), Color3.fromRGB(40, 60, 80), Enum.Material.Glass)
	block(model, "Stripe", Vector3.new(size.X + 0.2, bodyHeight * 0.12, size.Z - cabLength), CFrame.new(0, wheel + bodyHeight * 0.55, cabLength / 2), Color3.fromRGB(255, 196, 40), Enum.Material.Neon)
	for index, z in { -size.Z * 0.32, size.Z * 0.32 } do
		for side, x in { -size.X / 2, size.X / 2 } do
			block(model, `Wheel_{index}{side}`, Vector3.new(wheel * 0.8, wheel * 2, wheel * 2), CFrame.new(x, wheel, z), Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end
	local point = Instance.new("Attachment")
	point.Name = HEALTH_BAR_POINT
	point.Position = Vector3.new(0, size.Y + 3, 0)
	point.Parent = root
	return model
end

local function makeModel(): (Model?, string)
	local asset = findAsset(ArmoredVan.Asset)
	if asset and asset:IsA("Model") then
		local copy = (asset :: Model):Clone() :: Model?
		if copy then
			return copy, ArmoredVan.Asset
		end
		warnOnce("archivable", `{asset:GetFullName()} n'est pas Archivable : fourgon en blocs à la place`)
	elseif not warned.asset then
		warned.asset = true
		log(`{ArmoredVan.Asset} pas rangé dans Assets : fourgon en blocs (repli)`)
	end
	return buildFallback(), "repli"
end

local function prepare(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy() -- jamais de script dans un modèle (CLAUDE.md)
		elseif descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	model.Name = VAN_NAME
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

-- Barre de vie (Fill = part des PV restants, HPText = « 1.2K / 3K »).
local function attachBar(model: Model, maxHP: number)
	local point = model:FindFirstChild(HEALTH_BAR_POINT, true)
	local adornee: Instance? = if point and point:IsA("Attachment") then point else model.PrimaryPart
	local gui: BillboardGui
	local template = findAsset(ArmoredVan.BillboardAsset)
	if template and template:IsA("BillboardGui") then
		gui = (template :: BillboardGui):Clone()
	else
		gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(ArmoredVan.BillboardSize.X, ArmoredVan.BillboardSize.Y)
		gui.AlwaysOnTop = true
		gui.MaxDistance = ArmoredVan.BillboardMaxDistance
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.45)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 210, 60)
		title.TextStrokeTransparency = 0
		title.Text = "ARMORED VAN"
		title.Parent = gui
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.Position = UDim2.fromScale(0, 0.5)
		bar.Size = UDim2.fromScale(1, 0.5)
		bar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		bar.Parent = gui
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(230, 70, 60)
		fill.BorderSizePixel = 0
		fill.Parent = bar
		local text = Instance.new("TextLabel")
		text.Name = "HPText"
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0
		text.ZIndex = 2
		text.Parent = bar
	end
	gui.Name = "VanHP"
	if adornee == nil or not adornee:IsA("Attachment") then
		local _, size = model:GetBoundingBox()
		gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 3, 0)
	end
	if adornee then
		gui.Adornee = adornee
	end
	gui.Parent = adornee or model
	local fill = gui:FindFirstChild("Fill", true)
	local text = gui:FindFirstChild("HPText", true)
	local function refresh()
		local hp = model:GetAttribute(HP_ATTRIBUTE)
		local value = if type(hp) == "number" then math.max(hp, 0) else maxHP
		if fill and fill:IsA("GuiObject") then
			fill.Size = UDim2.fromScale(math.clamp(value / maxHP, 0, 1), fill.Size.Y.Scale)
		end
		if text and text:IsA("TextLabel") then
			text.Text = `{Format.short(value)} / {Format.short(maxHP)}`
		end
	end
	refresh()
	model:GetAttributeChangedSignal(HP_ATTRIBUTE):Connect(refresh)
end

-- Fourgon ---------------------------------------------------------------------------------------------------------

-- a425 (L-318 Q2) : état lu par la bannière (EventBannerController) ; nil efface.
local function setState(state: string?, endsAt: number?)
	Workspace:SetAttribute(ArmoredVan.StateAttribute, state)
	Workspace:SetAttribute(ArmoredVan.EndsAtAttribute, endsAt)
end

local function removeVan(current: Van, delay: number)
	if van == current then
		van = nil
		setState(nil, nil)
	end
	if not current.Done then
		vanEndedAt = os.clock()
	end
	current.Done = true
	if current.Heartbeat then
		current.Heartbeat:Disconnect()
	end
	WindowService.RemoveTarget(current.WindowId)
	task.delay(delay, function()
		current.Model:Destroy()
	end)
end

local function escape(current: Van)
	if current.Done then
		return
	end
	removeVan(current, 0)
	announce(ArmoredVan.Messages.Escaped)
	log("fourgon échappé : rien n'est donné")
end

local function spawnVan(): boolean
	if van ~= nil then
		return false
	end
	local points = pathPoints()
	if #points < 2 then
		warnOnce("path", `moins de deux arches {ZONE_GATE_TAG} dans la map : pas de fourgon`)
		return false
	end
	local model, origin = makeModel()
	if model == nil then
		return false
	end
	prepare(model)
	local damages: { number } = {}
	for _, player in Players:GetPlayers() do
		local ok, damage = pcall(ToolService.GetHitDamage, player)
		if ok and type(damage) == "number" then
			table.insert(damages, damage)
		end
	end
	local maxHP = ArmoredVanService.MaxHP(damages)
	model:PivotTo(frameAt(points, 0))
	local endsAt = Workspace:GetServerTimeNow() + ArmoredVan.TravelTime
	model:SetAttribute(ENDS_AT_ATTRIBUTE, endsAt)
	model.Parent = Workspace
	CollectionService:AddTag(model, TAG)
	local windowId = WindowService.AddTarget(model, maxHP)
	if windowId == nil then
		model:Destroy()
		return false
	end
	attachBar(model, maxHP)
	local current: Van = {
		Model = model,
		WindowId = windowId,
		MaxHP = maxHP,
		From = os.clock(),
		Path = points,
		Length = pathLength(points),
		Damage = {},
		Names = {},
		Done = false,
		Heartbeat = nil,
	}
	van = current
	vanCount += 1
	setState("Road", endsAt)
	current.Heartbeat = RunService.Heartbeat:Connect(function()
		if current.Done then
			return
		end
		local t = (os.clock() - current.From) / ArmoredVan.TravelTime
		if t >= 1 then
			escape(current)
			return
		end
		model:PivotTo(frameAt(current.Path, t * current.Length))
	end)
	announce(ArmoredVan.Messages.Started, ArmoredVan.Messages.StartedDetail)
	log(`fourgon ({origin}) : {maxHP} PV, {math.round(current.Length)} studs en {ArmoredVan.TravelTime} s`)
	return true
end

-- Meilleure zone parmi les objets du joueur (zone 1 sans objet) : la même règle que RewardService.
local function bestZone(data: any): number
	local best = 1
	local items = if type(data) == "table" then data.Items else nil
	if type(items) ~= "table" then
		return best
	end
	for _, entry in items do
		local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
		if def then
			local zone = def.Zone or entry.Zone
			if type(zone) == "number" and Zones[zone] ~= nil and zone > best then
				best = zone
			end
		end
	end
	return best
end

-- a425 (L-325 réponse 2) : zone et rareté du colis qui tombe, par la règle du colis gagné (comme GiveZoneBoxItem).
local function dropFor(player: Player, tier: ArmoredVan.RewardTier, best: number, place: Place, burst: boolean): Drop?
	local ok, zone, rarity = pcall(function(): (number?, string?)
		local z = ZoneBoxOdds.Zone(tier.Rule :: any, best)
		if z == nil then
			return nil, nil
		end
		local drawn = ZoneBoxOdds.Draw(ZoneBoxOdds.Chances(tier.Rule :: any, z), math.random())
		return z, if drawn then drawn.Id else nil
	end)
	if not ok or zone == nil or rarity == nil then
		warnOnce("drop", `colis tombé du fourgon : aucune rareté pour {player.Name} (zone {tostring(best)})`)
		return nil
	end
	return { Player = player, Label = tier.Label, Zone = zone, Rarity = rarity, Burst = burst, Place = place }
end

-- L'objet du colis tout droit dans l'inventaire ; inventaire plein : le colis tombe derrière le fourgon (drops).
local function giveItem(player: Player, place: Place, tier: ArmoredVan.RewardTier, data: any, drops: { Drop }): boolean
	local percent = math.round(place.Share * 100)
	local ok, itemUid, reason, itemId = pcall(function(): (string?, string?, string?)
		local uid, why, id = UnboxService.GiveZoneBoxItem(player, tier.Rule, bestZone(data))
		return uid, why, id
	end)
	if not ok or itemUid == nil or itemId == nil then
		if ok and reason == "InventoryFull" then
			local drop = dropFor(player, tier, bestZone(data), place, false)
			if drop then
				table.insert(drops, drop) -- posé et annoncé après la boucle (placeDrops)
			else
				notify(player, ArmoredVan.Messages.Lost, "Warning")
			end
		else
			warnOnce(`give:{tostring(if ok then reason else itemUid)}`, `colis du fourgon pas donné à {player.Name} ({tostring(if ok then reason else itemUid)})`)
		end
		return false
	end
	local def = Items.ById[itemId]
	local entry = (data :: any).Items[itemUid]
	local rarity = if def then Rarities.ById[def.Rarity] else nil
	local name = if def then Mutations.ItemName(def.DisplayName, if entry then entry.Mutation else nil) else tostring(itemId)
	notify(player, string.format(ArmoredVan.Messages.Reward, place.Rank, percent, tier.Label, if rarity then rarity.DisplayName else "", name), "Success")
	log(`{player.Name} : #{place.Rank} ({percent} %), {tier.Label} : {itemId}`)
	return true
end

local function reward(player: Player, place: Place, drops: { Drop }): boolean
	local tier = place.Tier
	if tier == nil then
		notify(player, ArmoredVan.Messages.TooLittle, "Info")
		return false
	end
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	-- a509 (L-457) : le colis jaillit du fourgon, à ouvrir sur place (posé et annoncé après la boucle, placeDrops).
	if BURST and heistApi ~= nil then
		local drop = dropFor(player, tier, bestZone(data), place, true)
		if drop then
			table.insert(drops, drop)
			return false
		end
	end
	return giveItem(player, place, tier, data, drops)
end

-- a425 (L-325 réponse 2) : chaque colis qui n'est pas entré dans l'inventaire tombe derrière le fourgon arrêté, côte à
-- côte, sur un rayon d'événement à lui (n'importe qui l'ouvre et prend l'objet). Renvoie le nombre de colis posés.
local function placeDrops(current: Van, drops: { Drop }): number
	if #drops == 0 then
		return 0
	end
	local model = current.Model
	local pivot = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local blast = model:FindFirstChild(BLAST_POINT, true)
	-- a509 : colis qui jaillissent (BURST) sans BlastPoint : du centre du modèle (comme l'explosion).
	local from: Vector3? = if blast and blast:IsA("Attachment")
		then (blast :: Attachment).WorldPosition
		elseif BURST then model:GetBoundingBox().Position
		else nil
	-- Avant vers −Z (LookVector) : l'arrière est de l'autre côté.
	local behind = pivot.Position - pivot.LookVector * (size.Z / 2 + ArmoredVan.DropBehind)
	local offsets = ArmoredVanService.DropOffsets(#drops)
	local addShelf = if heistApi then heistApi.AddEventShelf else nil
	local placed = 0
	for index, drop in drops do
		local point = behind + pivot.RightVector * offsets[index]
		local ground = Vector3.new(point.X, groundY(point, { model }), point.Z)
		local shelf: Model? = nil
		if addShelf then
			local ok, result = pcall(addShelf, {
				Id = `{DROP_PREFIX}{vanCount}_{drop.Player.UserId}`,
				Zone = drop.Zone,
				Spots = { { CFrame = CFrame.new(ground), Rarity = drop.Rarity, From = from } },
				Lifetime = ArmoredVan.DropLifetime,
			})
			shelf = if ok then result else nil
		end
		if shelf and drop.Burst then
			placed += 1
			notify(drop.Player, string.format(ArmoredVan.Messages.Burst, drop.Place.Rank, math.round(drop.Place.Share * 100), drop.Label), "Success")
			log(`{drop.Player.Name} : #{drop.Place.Rank}, {drop.Label} ({drop.Rarity}, zone {drop.Zone}) jailli du fourgon`)
		elseif shelf then
			placed += 1
			notify(drop.Player, string.format(ArmoredVan.Messages.Full, drop.Label), "Warning")
			log(`{drop.Player.Name} : inventaire plein, {drop.Label} ({drop.Rarity}, zone {drop.Zone}) tombé derrière le fourgon`)
		elseif drop.Burst then
			-- a509 : rayon refusé, l'objet va dans l'inventaire comme avant (plein : perdu, le rayon manque).
			local data = DataService.Get(drop.Player)
			local tier = drop.Place.Tier
			local full: { Drop } = {}
			if data and tier and giveItem(drop.Player, drop.Place, tier, data, full) then
				placed += 1
			elseif #full > 0 then
				notify(drop.Player, ArmoredVan.Messages.Lost, "Warning")
			end
			warnOnce("noburst", "StoreHeistService.AddEventShelf refusé : colis du fourgon mis dans l'inventaire")
		else
			notify(drop.Player, ArmoredVan.Messages.Lost, "Warning")
			warnOnce("noshelf", "StoreHeistService.AddEventShelf indisponible ou refusé : colis du fourgon perdu (inventaire plein)")
		end
	end
	return placed
end

local function breakVan(current: Van)
	if current.Done then
		return
	end
	removeVan(current, ArmoredVan.RemoveDelay)
	-- a425 (L-324) : l'explosion se joue chez les clients (ArmoredVanController, comme le camion) ; ici le fourgon est
	-- arrêté (removeVan), sa barre et son contour s'éteignent.
	local model = current.Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BillboardGui") and descendant.Name == BAR_NAME then
			(descendant :: BillboardGui).Enabled = false
		elseif descendant:IsA("Highlight") and descendant.Name == OUTLINE_NAME then
			(descendant :: Highlight).Enabled = false
		end
	end
	model:SetAttribute(EXPLODED_AT_ATTRIBUTE, Workspace:GetServerTimeNow())
	local places = ArmoredVanService.Ranking(current.Damage, current.MaxHP)
	local top: { string } = {}
	local rewarded = 0
	local drops: { Drop } = {}
	for _, place in places do
		local player = Players:GetPlayerByUserId(place.UserId)
		if #top < 3 then
			table.insert(top, current.Names[place.UserId] or "?")
		end
		if player and reward(player, place, drops) then
			rewarded += 1
		end
	end
	rewarded += placeDrops(current, drops)
	announce(string.format(ArmoredVan.Messages.Broken, table.concat(top, ", ")), string.format(ArmoredVan.Messages.BrokenDetail, rewarded))
	log(`fourgon cassé : {#places} casseur(s), {rewarded} colis donné(s)`)
end

-- Horaire ---------------------------------------------------------------------------------------------------------

local function dayAllows(): boolean
	if NightCycleService.GetPhase() ~= "Day" then
		return false
	end
	if os.clock() - dayStartedAt < ArmoredVan.DawnDelay then
		return false
	end
	return NightCycleService.GetPhaseEndsAt() - Workspace:GetServerTimeNow() >= ArmoredVan.TravelTime
end

-- a425 (L-318 Q1) : un camion de l'événement est-il en jeu ? Note l'heure du dernier vu (pause TruckGap).
local function truckInPlay(): boolean
	for _, truck in CollectionService:GetTagged(TRUCK_TAG) do
		if truck:IsDescendantOf(Workspace) then
			truckSeenAt = os.clock()
			return true
		end
	end
	return false
end

local function step()
	local now = os.time()
	local slot = ArmoredVanService.NextDeparture(now)
	local last = slot - ArmoredVan.Period -- dernier départ à l'horaire, déjà passé
	local roadFree = ArmoredVanService.TruckAllowsVan(truckInPlay(), os.clock() - truckSeenAt)
	if slot - now <= ArmoredVan.WarnBefore and announcedSlot ~= slot then
		announcedSlot = slot
		announce(string.format(ArmoredVan.Messages.Soon, math.max(0, slot - now)), ArmoredVan.Messages.SoonDetail)
		if van == nil and roadFree and NightCycleService.GetPhase() == "Day" then
			setState("Soon", Workspace:GetServerTimeNow() + math.max(0, slot - now))
		end
	end
	if startedSlot ~= last then
		startedSlot = last
		if van == nil then
			if dayAllows() and roadFree then
				pending = false
				if not spawnVan() then
					setState(nil, nil) -- pas de fourgon (pas de trajet) : la bannière s'éteint
				end
			else
				pending = true
				setState(nil, nil)
				announce(if roadFree then ArmoredVan.Messages.Delayed else ArmoredVan.Messages.DelayedTruck)
			end
		end
	elseif pending and van == nil and dayAllows() and roadFree then
		pending = false
		spawnVan()
	end
end

local function onHit(player: Player, windowId: string, _kind: string, _model: Model, damage: number)
	local current = van
	if current == nil or current.WindowId ~= windowId or current.Done then
		return
	end
	if type(damage) == "number" and damage > 0 and damage < math.huge then
		current.Damage[player.UserId] = (current.Damage[player.UserId] or 0) + damage
		current.Names[player.UserId] = player.Name
	end
end

local function onBroken(info: WindowService.BreakInfo)
	local current = van
	if current and info.WindowId == current.WindowId then
		breakVan(current)
	end
end

local function onPhaseChanged(phase: string, _previous: string)
	if phase == "Day" then
		dayStartedAt = os.clock()
	elseif van ~= nil then
		escape(van :: Van) -- alerte ou nuit : le mur ferme le couloir
	end
end

local function onTest()
	local value = Workspace:GetAttribute(TEST_ATTRIBUTE)
	if value == nil then
		return
	end
	Workspace:SetAttribute(TEST_ATTRIBUTE, nil)
	local current = van
	if value == "Break" and current then
		breakVan(current)
	elseif value == "Escape" and current then
		escape(current)
	elseif value == true then
		if current then
			removeVan(current, 0)
		end
		spawnVan()
	end
end

function ArmoredVanService.IsActive(): boolean
	return van ~= nil
end

function ArmoredVanService.HoldsTruck(): boolean
	if not ENABLED then
		return false
	end
	local now = os.time()
	return ArmoredVanService.BlocksTruck(ArmoredVanService.NextDeparture(now) - now, van ~= nil, pending, os.clock() - vanEndedAt)
end

function ArmoredVanService.Init()
	if not ENABLED then
		return
	end
	WindowService.OnHit(onHit :: any)
	WindowService.OnBroken(onBroken)
	-- a425 (L-325) : rayons d'événement de StoreHeistService (colis tombés), protégé comme dans TruckEventService.
	local module = script.Parent:FindFirstChild("StoreHeistService")
	if module and module:IsA("ModuleScript") then
		local ok, api = pcall(require, module)
		if ok and type(api) == "table" and type((api :: any).AddEventShelf) == "function" then
			heistApi = api :: any
		end
	end
	NightCycleService.OnPhaseChanged(onPhaseChanged :: any)
end

function ArmoredVanService.Start()
	if not ENABLED then
		print("[ArmoredVanService] casse du siècle coupée (Features.ArmoredVan = false) : aucun fourgon")
		return
	end
	-- Le départ en cours au démarrage du serveur est déjà passé : on attend le suivant.
	startedSlot = ArmoredVanService.NextDeparture(os.time()) - ArmoredVan.Period
	if NightCycleService.GetPhase() == "Day" then
		dayStartedAt = -math.huge
	end
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(onTest)
	end
	local model = if findAsset(ArmoredVan.Asset) then ArmoredVan.Asset else `{ArmoredVan.Asset} pas encore rangé, repli en blocs`
	print(`[ArmoredVanService] casse du siècle : un fourgon toutes les {ArmoredVan.Period // 60} min à heure fixe, de jour ; {model}`)
	while true do
		task.wait(TICK)
		xpcall(step, function(err: any)
			warn(`[ArmoredVanService] tick : {err}\n{debug.traceback()}`)
		end)
	end
end

return ArmoredVanService
