--!strict
-- DisplayController (DEV-020, client) : caisse, revenus et halos des objets exposés, côté joueur
-- (Partie 1, sections 5.6 et 5.8).
--
-- Rôle :
--   - lit les attributs posés par DisplayService : Income ($/s total), CashCollected (argent
--     encaissé depuis l'arrivée, qui ne fait que monter) et DisplaySlotsUnlocked (présentoirs
--     débloqués) sur le Player ; CashRegister (argent en caisse) sur sa parcelle. Le revenu est à
--     l'écran : HudController écrit UI_HUD.Income depuis le même attribut Income (DEV-021) ;
--   - à chaque encaissement (plaque, encaissement automatique, gains hors ligne : chaque hausse de
--     CashCollected), écrit le montant dans la sortie (en Studio seulement) et prévient les écouteurs
--     d'OnCashOut (« +$X » qui vole vers le compteur, son de caisse DEV-051) ;
--   - ramassage sur une plaque CollectPad_xx (remote CashCollect, envoyé à tous, L-091 point 5) :
--     gerbe des ParticleEmitter de `Plate/BurstPoint` (Emit(EmitCount)), Glow allumé un instant,
--     plaque enfoncée de son attribut SinkDepth, chez tous les joueurs qui ont la parcelle chargée ;
--     chez le propriétaire, prévient aussi les écouteurs d'OnCollect. Le montant écrit sur la plaque
--     (AmountGui/Amount) vient du serveur, visible par tous ;
--     a317 (L-304 point 3, Q3 validée par Cantin le 23/11) : chez tous ces joueurs aussi, les objets exposés dont
--     l'argent va sur cette plaque font un tour et deux sauts (ItemIdleController.Hop, Config/DisplayMotion) ; le voile,
--     le compteur et le son (L-299, CashFlashController et GainController) restent au propriétaire, par OnCollect ;
--   - anime en local les halos créés par le serveur : les rayons des objets Légendaire, Mythique
--     et Secret tournent, l'arc-en-ciel du Secret défile. Rien n'est envoyé au serveur ;
--   - téléphone (vague 39, a129 ; audit perf-telephone.md, correction 2 ; valeurs : Config/DisplayHalo) :
--     lumière et particules de chaque halo exposé éteintes au-delà d'EffectsDistance de la caméra
--     (rallumées en revenant, sauf VISUAL EFFECTS sur OFF : CosmeticController garde la main), rayons
--     tournés seulement dans le champ de la caméra, couleurs de l'arc-en-ciel des rayons calculées une fois.
--   - vague 44 (a152, demande de Cantin du 2026-11-14), invites créées ici, côté client seulement, chez le
--     propriétaire (textes en anglais et choix V0 proposés, absents du doc ; portée Unbox.PromptDistance, celle
--     des autres invites de la boutique ; touche E de Roblox) :
--       « Take » (TakeDisplayPrompt) sur chaque objet exposé de SA boutique (OwnerUserId = le sien) : remote
--       TakeDisplayItem(uid), InventoryService le remet dans l'inventaire (barre du bas si une case est libre) ;
--       « Display » (DisplayHeldPrompt) sur chaque présentoir DisplaySlot_xx libre de SA boutique (attribut
--       UnboxState = "Free" d'UnboxService), seulement avec un objet en main (attribut HeldItem du Player,
--       HeldItemService) qui n'est pas sous antivol : remote PlaceItem(uid, présentoir), DisplayService vérifie.
--     Les deux sont cachées pendant un portage (attribut Carrying). Le serveur revérifie tout.
-- Ce contrôleur ne crée aucune UI (9.3) : l'inventaire et le HUD sont des écrans de Clément.
--
-- API (client) :
--   DisplayController.GetIncome() -> number          revenu des objets exposés ($/s)
--   DisplayController.GetRegister() -> number        argent sur toutes les plaques de sa parcelle
--   DisplayController.GetUnlockedSlots() -> number   présentoirs débloqués (0 sans parcelle)
--   DisplayController.OnIncomeChanged(fn(income)) -> déconnexion
--   DisplayController.OnRegisterChanged(fn(amount)) -> déconnexion
--   DisplayController.OnCashOut(fn(amount)) -> déconnexion
--       Chaque encaissement du joueur local (plaques, automatique, hors ligne), une fois par hausse.
--   DisplayController.OnCollect(fn(amount, slotIndex, position)) -> déconnexion
--       Ramassage du joueur local sur une de ses plaques : montant, numéro de la plaque, position du
--       dessus de la plaque (BurstPoint). Arrive avec, ou juste avant, l'OnCashOut du même montant.
--   DisplayController.PlaceItem(itemUid, slotIndex)
--       Demande au serveur d'exposer un objet de l'inventaire sur un présentoir (pour l'écran
--       d'inventaire de Clément). Le serveur vérifie tout et répond par Notify en cas de refus.
--   DisplayController.FormatMoney(amount) -> string  Shared/Format.money : « $300 », « $12.4K », « $2M »
--   DisplayController.GetOwnerPrompts() -> { Take = { [uid]: allumée }, Display = { [présentoir]: allumée } }
--   DisplayController.ItemsOnPad(plot, padSlot) -> { Model }   a317 : objets exposés dont l'argent va sur cette plaque

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local HaloConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DisplayHalo"))
-- Vague 44 (a152) : invites « Take » et « Display » du propriétaire.
local HeldItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HeldItem"))
local ItemsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Items"))
local Mutations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mutations"))
local UnboxConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Unbox"))
local InventoryState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InventoryState"))

type Listener = (value: number) -> ()

local IS_STUDIO = RunService:IsStudio()

-- Attributs et objets posés par DisplayService (mêmes noms que côté serveur).
local INCOME_ATTRIBUTE = "Income"
local COLLECTED_ATTRIBUTE = "CashCollected"
local SLOTS_ATTRIBUTE = "DisplaySlotsUnlocked"
local REGISTER_ATTRIBUTE = "CashRegister"
local DISPLAY_TAG = "DisplayItem"
local RAREST_TAG = "RarestItem" -- a178 : copie locale du socle (VfxController) : son halo est animé aussi
local HALO_ATTRIBUTE = "Halo"
local HALO_PART = "RarityHalo"
local RAYS_CENTER = "RaysCenter"
local RAY_PREFIX = "Ray_"
local ITEM_BILLBOARD = "BB_Item"
local RAINBOW_GRADIENT = "RarityRainbow"
-- Posés par PlotService.
local PLOT_INDEX_ATTRIBUTE = "PlotIndex"
local OWNER_ATTRIBUTE = "OwnerUserId"
-- Plaque de ramassage (contrat 10.4, L-091 point 5) et ses effets, posés par Clément.
local PAD_FORMAT = "CollectPad_%02d"
local PAD_PATTERN = "^CollectPad_(%d+)$" -- a317
local DISPLAY_SLOT_ATTRIBUTE = "DisplaySlot" -- a317 : numéro du présentoir d'un objet exposé (DisplayService)
local PLATE = "Plate"
local BURST_POINT = "BurstPoint"
local GLOW = "Glow"
local EMIT_COUNT_ATTRIBUTE = "EmitCount"
local SINK_ATTRIBUTE = "SinkDepth"

-- V0 proposé, absent du doc : gerbe d'un ParticleEmitter sans attribut EmitCount, durée du Glow et
-- de l'enfoncement de la plaque, au ramassage.
local DEFAULT_EMIT_COUNT = 10
local GLOW_TIME = 0.35
local SINK_TIME = 0.15

-- V0 proposé, absent du doc : animation locale des halos.
local RAYS_TURN_SPEED = 0.5 -- radians par seconde
local RAINBOW_PERIOD = 3 -- secondes pour parcourir tout l'arc-en-ciel
local GRADIENT_TURN_SPEED = 90 -- degrés par seconde (texte de rareté d'un Secret)
local ANIMATION_DISTANCE = 120 -- studs : plus loin de la caméra, le halo n'est pas animé (mobile)
local HALO_WAIT = 5 -- secondes d'attente du halo d'un objet qui vient d'arriver

-- Vague 44 (a152), V0 proposés, absents du doc : textes (anglais, L-036) et cadence (s) de la revue des invites.
local TAKE_PROMPT = "TakeDisplayPrompt"
local TAKE_TEXT = "Take"
local PLACE_PROMPT = "DisplayHeldPrompt"
local PLACE_TEXT = "Display"
local PROMPT_TICK = 0.2
local SLOT_PATTERN = "^DisplaySlot_(%d+)$" -- présentoirs (contrat 10.4)
local SLOT_STATE_ATTRIBUTE = "UnboxState" -- UnboxService, sur chaque DisplaySlot_xx : "Free", "Taken", "Locked"
local CARRYING_ATTRIBUTE = "Carrying" -- CarryService : portage en cours
local ITEM_UID_ATTRIBUTE = "ItemUid"
local ITEM_ID_ATTRIBUTE = "ItemId"

type Ray = {
	attachment: Attachment,
	beam: Beam?,
	angle: number, -- angle de départ autour du centre, dans le plan XY du halo
	radius: number,
	step: number?, -- teinte de l'arc-en-ciel écrite sur le rayon (Secret), nil avant la première
}

type Animated = {
	halo: BasePart,
	center: Attachment?,
	rays: { Ray },
	reach: number, -- rayon (studs) d'une sphère autour du halo qui contient tous les rayons
	rainbow: boolean,
	light: PointLight?,
	gradient: UIGradient?,
}

-- Lumière et particules d'un halo, coupées au loin (Config/DisplayHalo.EffectsDistance).
type Lit = {
	halo: BasePart,
	lights: { Light },
	emitters: { ParticleEmitter },
	on: boolean, -- état voulu au dernier passage
}

local DisplayController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local settings: any = nil -- Config/Settings (effets visuels coupés : gerbe réduite), lu au démarrage
local plotTag = "PlayerPlot" -- relu dans Contract/Models au démarrage
local rainbowColors: { Color3 } = {}
local ownPlot: Instance? = nil
local registerConnection: RBXScriptConnection? = nil
local lastCollected = 0
local incomeListeners: { Listener } = {}
local registerListeners: { Listener } = {}
local cashOutListeners: { Listener } = {}
type CollectListener = (amount: number, slotIndex: number, position: Vector3) -> ()
local collectListeners: { CollectListener } = {}
local plateRest: { [BasePart]: CFrame } = {} -- position de repos d'une plaque enfoncée
local animated: { [Instance]: Animated } = {}
local lit: { [Instance]: Lit } = {}
local rainbowSequences: { ColorSequence } = {} -- Config/DisplayHalo.RainbowSteps teintes, calculées au démarrage
local nextCull = 0 -- os.clock() de la prochaine revue des distances (lumière et particules)
-- Vague 44 (a152) : invites du propriétaire.
local takePrompts: { [Instance]: ProximityPrompt } = {} -- [objet exposé] = « Take »
type SlotPrompt = { attachment: Attachment, index: number, prompt: ProximityPrompt }
local slotPrompts: { [Attachment]: SlotPrompt } = {}
local slotPlot: Instance? = nil -- parcelle dont les présentoirs ont leur invite « Display »
local slotConnection: RBXScriptConnection? = nil
local promptClock = 0
local itemIdle: any = nil -- a317 : ItemIdleController (Hop), cherché au premier encaissement

local function subscribe<T>(list: { T }, listener: T): () -> ()
	table.insert(list, listener)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

local function emit(list: { Listener }, value: number)
	for _, listener in table.clone(list) do
		task.spawn(listener, value)
	end
end

local function numberAttribute(instance: Instance?, name: string): number
	if instance == nil then
		return 0
	end
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

------------------------------------------------------------------------------
-- Revenus et caisse
------------------------------------------------------------------------------

-- Sa parcelle : celle dont le PlotIndex est le sien et dont il est le propriétaire.
local function findOwnPlot(): Instance?
	local index = localPlayer:GetAttribute(PLOT_INDEX_ATTRIBUTE)
	if index == nil then
		return nil
	end
	for _, plot in CollectionService:GetTagged(plotTag) do
		if plot:GetAttribute(PLOT_INDEX_ATTRIBUTE) == index and plot:GetAttribute(OWNER_ATTRIBUTE) == localPlayer.UserId then
			return plot
		end
	end
	return nil
end

local function refreshOwnPlot()
	local plot = findOwnPlot()
	if plot == ownPlot then
		return
	end
	local old = registerConnection
	if old then
		old:Disconnect()
		registerConnection = nil
	end
	ownPlot = plot
	if plot then
		registerConnection = plot:GetAttributeChangedSignal(REGISTER_ATTRIBUTE):Connect(function()
			emit(registerListeners, numberAttribute(plot, REGISTER_ATTRIBUTE))
		end)
	end
	emit(registerListeners, numberAttribute(plot, REGISTER_ATTRIBUTE))
end

-- Une parcelle arrive (début, ou streaming) : on suit ses changements de propriétaire.
local function watchPlot(plot: Instance)
	plot:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(refreshOwnPlot)
	refreshOwnPlot()
end

local function onCollectedChanged()
	local value = numberAttribute(localPlayer, COLLECTED_ATTRIBUTE)
	local amount = value - lastCollected
	lastCollected = value
	if amount <= 0 then
		return
	end
	if IS_STUDIO then
		print(`[Caisse] +{Format.money(amount)} encaissés (revenu de ta boutique : {Format.money(DisplayController.GetIncome())}/s)`)
	end
	emit(cashOutListeners, amount)
end

local function onIncomeChanged()
	emit(incomeListeners, numberAttribute(localPlayer, INCOME_ATTRIBUTE))
end

------------------------------------------------------------------------------
-- Ramassage sur une plaque (visuel local)
------------------------------------------------------------------------------

local function plotByIndex(plotIndex: number): Instance?
	for _, plot in CollectionService:GetTagged(plotTag) do
		if plot:GetAttribute(PLOT_INDEX_ATTRIBUTE) == plotIndex then
			return plot
		end
	end
	return nil
end

-- Gerbe de BurstPoint, Glow un instant, plaque enfoncée de SinkDepth puis remise en place.
local function burst(pad: Instance): Vector3
	local plateFound = pad:FindFirstChild(PLATE, true)
	local plate: BasePart? = if plateFound ~= nil and plateFound:IsA("BasePart") then plateFound :: BasePart else nil
	local pointFound = pad:FindFirstChild(BURST_POINT, true)
	local position = if pad:IsA("BasePart") then (pad :: BasePart).Position else Vector3.zero
	if pointFound ~= nil and pointFound:IsA("Attachment") then
		local point = pointFound :: Attachment
		position = point.WorldPosition
		for _, child in point:GetChildren() do
			if child:IsA("ParticleEmitter") then
				local count = child:GetAttribute(EMIT_COUNT_ATTRIBUTE)
				local n = if type(count) == "number" and count == count and count > 0 then math.floor(count) else DEFAULT_EMIT_COUNT
				if settings and settings.VfxReduced(localPlayer) then
					n = math.ceil(n * settings.VfxOff.BurstFactor) -- réglages du joueur (L-095 ; à 0 : pas de gerbe)
				end
				if n > 0 then
					child:Emit(n)
				end
			end
		end
	end
	if plate == nil then
		return position
	end
	local part = plate :: BasePart
	local glow = part:FindFirstChild(GLOW)
	if glow ~= nil and glow:IsA("Light") then
		local light = glow :: Light
		light.Enabled = true
		task.delay(GLOW_TIME, function()
			light.Enabled = false
		end)
	end
	local sink = part:GetAttribute(SINK_ATTRIBUTE)
	if type(sink) == "number" and sink == sink and sink > 0 then
		local rest = plateRest[part] or part.CFrame
		plateRest[part] = rest
		-- Vers le bas du monde, quelle que soit la rotation de la plaque (épaisseur sur Y ou sur Z, comme
		-- DisplayService.isOnPad) : avant, le long de son Y local, une plaque couchée sur Z glissait de côté.
		part.CFrame = CFrame.new(0, -sink, 0) * rest
		task.delay(SINK_TIME, function()
			if plateRest[part] == rest then
				part.CFrame = rest
				plateRest[part] = nil
			end
		end)
	end
	return position
end

-- a317 (L-304 point 3) : numéros des plaques CollectPad_xx d'une parcelle, relus au plus toutes les PAD_CACHE_TIME s.
type PadCache = { at: number, pads: { [number]: boolean }, lowest: number? }
local padCache: { [Instance]: PadCache } = setmetatable({}, { __mode = "k" }) :: any
local PAD_CACHE_TIME = 10 -- V0 proposé, absent du doc : secondes

local function padsOf(plot: Instance): PadCache
	local cached = padCache[plot]
	local now = os.clock()
	if cached and now - cached.at < PAD_CACHE_TIME then
		return cached
	end
	local pads: { [number]: boolean } = {}
	local lowest: number? = nil
	for _, descendant in plot:GetDescendants() do
		local digits = string.match(descendant.Name, PAD_PATTERN)
		local n = if digits then tonumber(digits) else nil
		if n then
			pads[n] = true
			if lowest == nil or n < lowest then
				lowest = n
			end
		end
	end
	local fresh: PadCache = { at = now, pads = pads, lowest = lowest }
	padCache[plot] = fresh
	return fresh
end

-- a317 : objets exposés de `plot` dont l'argent va sur la plaque `padSlot` : celle de leur présentoir, sinon celle au
-- plus petit numéro (comme DisplayService.padSlotFor).
function DisplayController.ItemsOnPad(plot: Instance, padSlot: number): { Model }
	local result: { Model } = {}
	local cache: PadCache? = nil
	for _, model in CollectionService:GetTagged(DISPLAY_TAG) do
		if not model:IsA("Model") or not model:IsDescendantOf(plot) then
			continue
		end
		local slot = model:GetAttribute(DISPLAY_SLOT_ATTRIBUTE)
		if type(slot) ~= "number" then
			continue
		end
		local target = slot
		if slot ~= padSlot then
			local pads = cache or padsOf(plot)
			cache = pads
			if not pads.pads[slot] then
				target = pads.lowest or slot
			end
		end
		if target == padSlot then
			table.insert(result, model :: Model)
		end
	end
	return result
end

-- a317 : tour et sauts des objets de la plaque vidée (ItemIdleController.Hop), chez tous les joueurs (L-304 Q3,
-- validé par Cantin le 23/11).
local function hopItems(plot: Instance, padSlot: number)
	local idle: any = itemIdle
	if idle == nil then
		local module = script.Parent:FindFirstChild("ItemIdleController")
		if module == nil or not module:IsA("ModuleScript") then
			return
		end
		local ok, result = pcall(require, module)
		if not ok or type(result) ~= "table" then
			return
		end
		idle = result
		itemIdle = result
	end
	if type(idle.Hop) ~= "function" then
		return
	end
	for _, model in DisplayController.ItemsOnPad(plot, padSlot) do
		(idle.Hop :: any)(model)
	end
end

local function onCashCollect(plotIndex: number, slotIndex: number, amount: number)
	local plot = plotByIndex(plotIndex)
	local pad = if plot then plot:FindFirstChild(string.format(PAD_FORMAT, slotIndex), true) else nil
	local position = Vector3.zero
	if pad then
		local ok, result = pcall(burst, pad)
		if ok then
			position = result
		elseif IS_STUDIO then
			warn(`[DisplayController] gerbe de {pad:GetFullName()} : {result}`)
		end
	end
	if plot then
		local ok, err = pcall(hopItems :: any, plot, slotIndex) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok and IS_STUDIO then
			warn(`[DisplayController] tour des objets de la plaque {slotIndex} : {err}`)
		end
	end
	if plot and plot:GetAttribute(OWNER_ATTRIBUTE) == localPlayer.UserId then
		for _, listener in table.clone(collectListeners) do
			task.spawn(listener, amount, slotIndex, position)
		end
	end
end

------------------------------------------------------------------------------
-- Halos (visuel local)
------------------------------------------------------------------------------

-- Couleur de l'arc-en-ciel du Secret (planche 10.6) à la phase `phase` (1 = un tour).
local function rainbowAt(phase: number): Color3
	local count = #rainbowColors
	if count == 0 then
		return Color3.fromHSV(phase % 1, 0.7, 1)
	end
	local x = (phase % 1) * count
	local k = math.floor(x)
	local from = rainbowColors[k + 1]
	local to = rainbowColors[(k + 1) % count + 1]
	return from:Lerp(to, x - k)
end

-- Champ de la caméra pour l'image en cours (rayons tournés seulement à l'écran) : CFrame, tangentes des
-- demi-angles du champ et 1 / leur cosinus (pour élargir le champ du rayon d'une sphère).
local viewCFrame = CFrame.identity
local viewTanX, viewTanY, viewSecX, viewSecY = 1, 1, 1, 1

-- Lit le champ de la caméra ; false si elle n'a pas encore de taille (fenêtre pas prête) : tout est alors
-- réputé à l'écran.
local function readView(camera: Camera): boolean
	local fov = camera.FieldOfView
	local size = camera.ViewportSize
	if fov <= 0 or size.X <= 0 or size.Y <= 0 then
		return false
	end
	viewCFrame = camera.CFrame
	viewTanY = math.tan(math.rad(fov) / 2)
	viewTanX = viewTanY * size.X / size.Y
	viewSecX = math.sqrt(1 + viewTanX * viewTanX)
	viewSecY = math.sqrt(1 + viewTanY * viewTanY)
	return true
end

-- Une sphère (centre `position`, rayon `radius`) touche-t-elle le champ de la caméra (readView) ?
local function onScreen(position: Vector3, radius: number): boolean
	local p = viewCFrame:PointToObjectSpace(position)
	local depth = -p.Z -- devant la caméra : positif
	if depth < -radius then
		return false
	end
	return math.abs(p.X) <= depth * viewTanX + radius * viewSecX and math.abs(p.Y) <= depth * viewTanY + radius * viewSecY
end

local function track(model: Instance)
	local kind = model:GetAttribute(HALO_ATTRIBUTE)
	if type(kind) ~= "string" or kind == "None" then
		return -- Commun : aucun halo
	end
	local turns = kind == "Rays" or kind == "Rainbow" or kind == "Divine" -- rayons qui tournent (Divine : L-106)
	task.spawn(function()
		local found = model:FindFirstChild(HALO_PART) or model:WaitForChild(HALO_PART, HALO_WAIT)
		if found == nil or not found:IsA("BasePart") then
			return
		end
		local tagged = CollectionService:HasTag(model, DISPLAY_TAG) or CollectionService:HasTag(model, RAREST_TAG)
		if not tagged or not model:IsDescendantOf(Workspace) then
			return -- retiré pendant l'attente
		end
		local halo = found :: BasePart
		-- Lumière et particules du halo (HaloLight, HaloSparkles), coupées au loin (cullEffects).
		local lights: { Light } = {}
		local emitters: { ParticleEmitter } = {}
		for _, child in halo:GetChildren() do
			if child:IsA("Light") then
				table.insert(lights, child :: Light)
			elseif child:IsA("ParticleEmitter") then
				table.insert(emitters, child :: ParticleEmitter)
			end
		end
		if #lights > 0 or #emitters > 0 then
			lit[model] = { halo = halo, lights = lights, emitters = emitters, on = true }
		end
		if not turns then
			return
		end
		local centerFound = halo:FindFirstChild(RAYS_CENTER)
		local center = if centerFound ~= nil and centerFound:IsA("Attachment") then centerFound :: Attachment else nil
		local rays: { Ray } = {}
		local longest = 0
		if center then
			for _, child in halo:GetChildren() do
				if child:IsA("Attachment") and string.sub(child.Name, 1, #RAY_PREFIX) == RAY_PREFIX then
					local tip = child :: Attachment
					local offset = tip.Position - center.Position
					local radius = math.sqrt(offset.X * offset.X + offset.Y * offset.Y)
					longest = math.max(longest, radius)
					table.insert(rays, {
						attachment = tip,
						beam = tip:FindFirstChildOfClass("Beam") :: Beam?,
						angle = math.atan2(offset.Y, offset.X),
						radius = radius,
						step = nil,
					})
				end
			end
		end
		local billboard = model:FindFirstChild(ITEM_BILLBOARD)
		local gradient = if billboard then billboard:FindFirstChild(RAINBOW_GRADIENT, true) else nil
		animated[model] = {
			halo = halo,
			center = center,
			rays = rays,
			-- Le halo entier, plus les rayons et leur largeur au bout (RarityHalo : 0,4 × la longueur).
			reach = halo.Size.Magnitude / 2 + longest * 1.25,
			rainbow = kind == "Rainbow",
			light = halo:FindFirstChildOfClass("PointLight") :: PointLight?,
			gradient = if gradient ~= nil and gradient:IsA("UIGradient") then gradient :: UIGradient else nil,
		}
	end)
end

-- Lumière et particules des halos allumées seulement près de la caméra (Config/DisplayHalo). Rien quand
-- VISUAL EFFECTS est sur OFF : CosmeticController les a toutes éteintes et les rallumera à leur état ; le
-- passage suivant remet ensuite l'état voulu ici.
local function cullEffects(eye: Vector3)
	local limit = HaloConfig.EffectsDistance
	if limit <= 0 or (settings ~= nil and settings.VfxReduced(localPlayer)) then
		return
	end
	local far = limit + math.max(HaloConfig.EffectsMargin, 0)
	for model, entry in lit do
		local halo = entry.halo
		if halo.Parent == nil then
			lit[model] = nil
			continue
		end
		local distance = (halo.Position - eye).Magnitude
		local on = if distance < limit then true elseif distance > far then false else entry.on
		entry.on = on
		for _, light in entry.lights do
			if light.Enabled ~= on then
				light.Enabled = on
			end
		end
		for _, emitter in entry.emitters do
			if emitter.Enabled ~= on then
				emitter.Enabled = on
			end
		end
	end
end

-- Couleur d'un rayon du Secret à la phase `phase` : teinte précalculée, écrite seulement si elle change.
local function paintRay(ray: Ray, beam: Beam, phase: number)
	local count = #rainbowSequences
	if count == 0 then
		beam.Color = ColorSequence.new(rainbowAt(phase)) -- RainbowSteps à 0 : comme avant la vague 39
		return
	end
	local k = math.min(math.floor((phase % 1) * count), count - 1) + 1
	if ray.step ~= k then
		ray.step = k
		beam.Color = rainbowSequences[k]
	end
end

local function animate()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	local t = os.clock()
	if t >= nextCull then
		nextCull = t + HaloConfig.EffectsInterval
		cullEffects(eye)
	end
	if next(animated) == nil then
		return
	end
	local screenOnly = HaloConfig.RaysOnScreenOnly and readView(camera)
	for model, entry in animated do
		local halo = entry.halo
		if halo.Parent == nil then
			animated[model] = nil
			continue
		end
		if (halo.Position - eye).Magnitude > ANIMATION_DISTANCE then
			continue
		end
		local center = entry.center
		if center and (not screenOnly or onScreen(halo.Position, entry.reach)) then
			local base = center.Position
			local turn = t * RAYS_TURN_SPEED
			for i, ray in entry.rays do
				local angle = ray.angle + turn
				ray.attachment.Position = base + Vector3.new(math.cos(angle) * ray.radius, math.sin(angle) * ray.radius, 0)
				local beam = ray.beam
				if entry.rainbow and beam then
					paintRay(ray, beam, t / RAINBOW_PERIOD + i / #entry.rays)
				end
			end
		end
		if entry.rainbow then
			local light = entry.light
			if light then
				light.Color = rainbowAt(t / RAINBOW_PERIOD)
			end
			local gradient = entry.gradient
			if gradient then
				gradient.Rotation = (t * GRADIENT_TURN_SPEED) % 360
			end
		end
	end
end

------------------------------------------------------------------------------
-- Invites du propriétaire (vague 44, a152) : « Take » sur ses objets exposés, « Display » sur ses présentoirs
-- libres quand il tient un objet en main
------------------------------------------------------------------------------

local function newPrompt(name: string, action: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = ""
	prompt.MaxActivationDistance = UnboxConfig.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Enabled = false
	return prompt
end

-- Pièce qui porte l'invite d'un objet exposé : sa PrimaryPart, sinon sa première pièce hors halo.
local function promptPart(model: Instance): BasePart?
	if model:IsA("Model") and (model :: Model).PrimaryPart then
		return (model :: Model).PrimaryPart
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= HALO_PART then
			return descendant :: BasePart
		end
	end
	return nil
end

local function trackTake(model: Instance)
	if takePrompts[model] or model:GetAttribute(OWNER_ATTRIBUTE) ~= localPlayer.UserId then
		return -- objet d'un autre joueur ou du bot : pas d'invite « Take »
	end
	local uid = model:GetAttribute(ITEM_UID_ATTRIBUTE)
	local part = promptPart(model)
	if type(uid) ~= "string" or part == nil then
		return
	end
	local itemId = model:GetAttribute(ITEM_ID_ATTRIBUTE)
	local def = if type(itemId) == "string" then ItemsConfig.ById[itemId] else nil
	local prompt = newPrompt(TAKE_PROMPT, TAKE_TEXT)
	if def then
		local mutation = Mutations.Sanitize({ Size = model:GetAttribute("MutationSize"), Effect = model:GetAttribute("MutationEffect") })
		prompt.ObjectText = Mutations.ItemName(def.DisplayName, mutation)
	end
	prompt.Triggered:Connect(function()
		if net then
			net.Client.TakeDisplayItem:Fire(uid)
		end
	end)
	prompt.Parent = part
	takePrompts[model] = prompt
end

local function addSlot(instance: Instance)
	if not instance:IsA("Attachment") or slotPrompts[instance :: Attachment] then
		return
	end
	local digits = string.match(instance.Name, SLOT_PATTERN)
	local index = if digits then tonumber(digits) else nil
	if index == nil then
		return
	end
	local attachment = instance :: Attachment
	local slotIndex: number = index
	local prompt = newPrompt(PLACE_PROMPT, PLACE_TEXT)
	prompt.Triggered:Connect(function()
		local uid = localPlayer:GetAttribute(HeldItemConfig.PlayerAttribute)
		if net and type(uid) == "string" then
			net.Client.PlaceItem:Fire(uid, slotIndex)
		end
	end)
	prompt.Parent = attachment
	slotPrompts[attachment] = { attachment = attachment, index = slotIndex, prompt = prompt }
end

local function clearSlots()
	local connection = slotConnection
	if connection then
		connection:Disconnect()
		slotConnection = nil
	end
	for _, entry in slotPrompts do
		entry.prompt:Destroy()
	end
	table.clear(slotPrompts)
end

-- L'objet tenu est-il sous antivol (il se pose au sol, pas sur un présentoir) ?
local function heldIsAntiTheft(uid: string): boolean
	local state = InventoryState.Decode(localPlayer:GetAttribute(InventoryState.Attribute))
	for _, item in state.Items do
		if item.Uid == uid then
			return item.AntiTheft == true
		end
	end
	return false
end

-- Nom de l'objet tenu (nom du Tool de HeldItemService : mutation devant).
local function heldName(): string
	local character = localPlayer.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute(HeldItemConfig.ToolAttribute) ~= nil then
				return child.Name
			end
		end
	end
	return ""
end

local function updatePrompts()
	if slotPlot ~= ownPlot then
		clearSlots()
		slotPlot = ownPlot
		local plot = ownPlot
		if plot then
			for _, descendant in plot:GetDescendants() do
				addSlot(descendant)
			end
			slotConnection = plot.DescendantAdded:Connect(addSlot) -- rayons posés plus tard (RayonService)
		end
	end
	local carrying = localPlayer:GetAttribute(CARRYING_ATTRIBUTE) ~= nil
	local uid = localPlayer:GetAttribute(HeldItemConfig.PlayerAttribute)
	local holding = type(uid) == "string" and not carrying and not heldIsAntiTheft(uid)
	local name = if holding then heldName() else ""
	for attachment, entry in slotPrompts do
		if attachment.Parent == nil then
			entry.prompt:Destroy()
			slotPrompts[attachment] = nil
			continue
		end
		local on = holding and attachment:GetAttribute(SLOT_STATE_ATTRIBUTE) == "Free"
		if entry.prompt.ObjectText ~= name then
			entry.prompt.ObjectText = name
		end
		if entry.prompt.Enabled ~= on then
			entry.prompt.Enabled = on
		end
	end
	for model, prompt in takePrompts do
		if prompt.Parent == nil or not model:IsDescendantOf(Workspace) then
			prompt:Destroy()
			takePrompts[model] = nil
		elseif prompt.Enabled == carrying then
			prompt.Enabled = not carrying
		end
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function DisplayController.GetIncome(): number
	return numberAttribute(localPlayer, INCOME_ATTRIBUTE)
end

function DisplayController.GetRegister(): number
	return numberAttribute(ownPlot, REGISTER_ATTRIBUTE)
end

function DisplayController.GetUnlockedSlots(): number
	return numberAttribute(localPlayer, SLOTS_ATTRIBUTE)
end

function DisplayController.OnIncomeChanged(listener: Listener): () -> ()
	return subscribe(incomeListeners, listener)
end

function DisplayController.OnRegisterChanged(listener: Listener): () -> ()
	return subscribe(registerListeners, listener)
end

function DisplayController.OnCashOut(listener: Listener): () -> ()
	return subscribe(cashOutListeners, listener)
end

function DisplayController.OnCollect(listener: CollectListener): () -> ()
	return subscribe(collectListeners, listener)
end

function DisplayController.PlaceItem(itemUid: string, slotIndex: number)
	if net == nil then
		warn("[DisplayController] remotes pas encore prêts : PlaceItem ignoré")
		return
	end
	net.Client.PlaceItem:Fire(itemUid, slotIndex)
end

DisplayController.FormatMoney = Format.money

-- Vague 44 (a152) : invites du propriétaire en ce moment (bancs, barre de commande) : Take[uid] et
-- Display[numéro du présentoir] = true si l'invite est allumée, false si elle est cachée.
function DisplayController.GetOwnerPrompts(): { Take: { [string]: boolean }, Display: { [number]: boolean } }
	local result = { Take = {} :: { [string]: boolean }, Display = {} :: { [number]: boolean } }
	for model, prompt in takePrompts do
		local uid = model:GetAttribute(ITEM_UID_ATTRIBUTE)
		if type(uid) == "string" then
			result.Take[uid] = prompt.Enabled
		end
	end
	for _, entry in slotPrompts do
		result.Display[entry.index] = entry.prompt.Enabled
	end
	return result
end

function DisplayController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local models = require(shared:WaitForChild("Contract"):WaitForChild("Models") :: ModuleScript) :: any
	plotTag = models.Plot.Tag
	local rarities = require(shared:WaitForChild("Config"):WaitForChild("Rarities") :: ModuleScript) :: any
	local secret = rarities.ById.Secret
	rainbowColors = if secret and secret.RainbowColors then secret.RainbowColors else {}
	-- Vague 39 : un tour de l'arc-en-ciel des rayons, calculé une fois (Config/DisplayHalo.RainbowSteps).
	local steps = math.max(math.floor(HaloConfig.RainbowSteps), 0)
	for k = 0, steps - 1 do
		table.insert(rainbowSequences, ColorSequence.new(rainbowAt(k / steps)))
	end
	local settingsModule = shared:WaitForChild("Config"):FindFirstChild("Settings")
	if settingsModule and settingsModule:IsA("ModuleScript") then
		settings = require(settingsModule) :: any
	end

	lastCollected = numberAttribute(localPlayer, COLLECTED_ATTRIBUTE)
	localPlayer:GetAttributeChangedSignal(COLLECTED_ATTRIBUTE):Connect(onCollectedChanged)
	localPlayer:GetAttributeChangedSignal(INCOME_ATTRIBUTE):Connect(onIncomeChanged)
	localPlayer:GetAttributeChangedSignal(PLOT_INDEX_ATTRIBUTE):Connect(refreshOwnPlot)

	CollectionService:GetInstanceAddedSignal(plotTag):Connect(watchPlot)
	CollectionService:GetInstanceRemovedSignal(plotTag):Connect(function()
		refreshOwnPlot()
	end)
	for _, plot in CollectionService:GetTagged(plotTag) do
		watchPlot(plot)
	end

	CollectionService:GetInstanceAddedSignal(DISPLAY_TAG):Connect(track)
	CollectionService:GetInstanceAddedSignal(DISPLAY_TAG):Connect(trackTake) -- vague 44 : invite « Take »
	CollectionService:GetInstanceRemovedSignal(DISPLAY_TAG):Connect(function(model: Instance)
		animated[model] = nil
		lit[model] = nil
		local prompt = takePrompts[model]
		if prompt then
			takePrompts[model] = nil
			prompt:Destroy()
		end
	end)
	for _, model in CollectionService:GetTagged(DISPLAY_TAG) do
		track(model)
		trackTake(model)
	end
	-- a178 : halo de la copie du socle (pas d'invite « Take » sur elle).
	CollectionService:GetInstanceAddedSignal(RAREST_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(RAREST_TAG):Connect(function(model: Instance)
		animated[model] = nil
		lit[model] = nil
	end)
	RunService.Heartbeat:Connect(animate)
	-- Vague 44 : invites du propriétaire revues toutes les PROMPT_TICK s.
	RunService.Heartbeat:Connect(function(dt: number)
		promptClock += dt
		if promptClock < PROMPT_TICK then
			return
		end
		promptClock = 0
		local ok, err = pcall(updatePrompts :: any) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok and IS_STUDIO then
			warn(`[DisplayController] invites du propriétaire : {err}`)
		end
	end)

	-- Peut attendre que le serveur ait créé les remotes.
	net = require(shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	local remote = net.Client.CashCollect
	if remote then
		remote:Connect(onCashCollect)
	end
end

return DisplayController
