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
--   - anime en local les halos créés par le serveur : les rayons des objets Légendaire, Mythique
--     et Secret tournent, l'arc-en-ciel du Secret défile. Rien n'est envoyé au serveur ;
--   - téléphone (vague 39, a129 ; audit perf-telephone.md, correction 2 ; valeurs : Config/DisplayHalo) :
--     lumière et particules de chaque halo exposé éteintes au-delà d'EffectsDistance de la caméra
--     (rallumées en revenant, sauf VISUAL EFFECTS sur OFF : CosmeticController garde la main), rayons
--     tournés seulement dans le champ de la caméra, couleurs de l'arc-en-ciel des rayons calculées une fois.
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

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local HaloConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DisplayHalo"))

type Listener = (value: number) -> ()

local IS_STUDIO = RunService:IsStudio()

-- Attributs et objets posés par DisplayService (mêmes noms que côté serveur).
local INCOME_ATTRIBUTE = "Income"
local COLLECTED_ATTRIBUTE = "CashCollected"
local SLOTS_ATTRIBUTE = "DisplaySlotsUnlocked"
local REGISTER_ATTRIBUTE = "CashRegister"
local DISPLAY_TAG = "DisplayItem"
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
		part.CFrame = rest * CFrame.new(0, -sink, 0)
		task.delay(SINK_TIME, function()
			if plateRest[part] == rest then
				part.CFrame = rest
				plateRest[part] = nil
			end
		end)
	end
	return position
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
		if not CollectionService:HasTag(model, DISPLAY_TAG) or not model:IsDescendantOf(Workspace) then
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
	CollectionService:GetInstanceRemovedSignal(DISPLAY_TAG):Connect(function(model: Instance)
		animated[model] = nil
		lit[model] = nil
	end)
	for _, model in CollectionService:GetTagged(DISPLAY_TAG) do
		track(model)
	end
	RunService.Heartbeat:Connect(animate)

	-- Peut attendre que le serveur ait créé les remotes.
	net = require(shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	local remote = net.Client.CashCollect
	if remote then
		remote:Connect(onCashCollect)
	end
end

return DisplayController
