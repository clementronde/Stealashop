--!strict
-- DisplayController (DEV-020, client) : caisse, revenus et halos des objets exposés, côté joueur
-- (Partie 1, sections 5.6 et 5.8).
--
-- Rôle :
--   - lit les attributs posés par DisplayService : Income ($/s total), CashCollected (argent
--     encaissé depuis l'arrivée, qui ne fait que monter) et DisplaySlotsUnlocked (présentoirs
--     débloqués) sur le Player ; CashRegister (argent en caisse) sur sa parcelle. Le revenu est à
--     l'écran : HudController écrit UI_HUD.Income depuis le même attribut Income (DEV-021) ;
--   - à chaque encaissement au CashPad, écrit le montant dans la sortie (en Studio seulement)
--     et prévient les écouteurs d'OnCashOut (plus tard : chiffre flottant, son de caisse DEV-051) ;
--   - anime en local les halos créés par le serveur : les rayons des objets Légendaire, Mythique
--     et Secret tournent, l'arc-en-ciel du Secret défile. Rien n'est envoyé au serveur.
-- Ce contrôleur ne crée aucune UI (9.3) : l'inventaire et le HUD sont des écrans de Clément.
--
-- API (client) :
--   DisplayController.GetIncome() -> number          revenu des objets exposés ($/s)
--   DisplayController.GetRegister() -> number        argent dans la caisse de sa parcelle
--   DisplayController.GetUnlockedSlots() -> number   présentoirs débloqués (0 sans parcelle)
--   DisplayController.OnIncomeChanged(fn(income)) -> déconnexion
--   DisplayController.OnRegisterChanged(fn(amount)) -> déconnexion
--   DisplayController.OnCashOut(fn(amount)) -> déconnexion
--   DisplayController.PlaceItem(itemUid, slotIndex)
--       Demande au serveur d'exposer un objet de l'inventaire sur un présentoir (pour l'écran
--       d'inventaire de Clément). Le serveur vérifie tout et répond par Notify en cas de refus.
--   DisplayController.FormatMoney(amount) -> string  « 300 $ », « 12,4 K$ », « 2 M$ », « 3 Md$ »

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
}

type Animated = {
	halo: BasePart,
	center: Attachment?,
	rays: { Ray },
	rainbow: boolean,
	light: PointLight?,
	gradient: UIGradient?,
}

local DisplayController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local plotTag = "PlayerPlot" -- relu dans Contract/Models au démarrage
local rainbowColors: { Color3 } = {}
local ownPlot: Instance? = nil
local registerConnection: RBXScriptConnection? = nil
local lastCollected = 0
local incomeListeners: { Listener } = {}
local registerListeners: { Listener } = {}
local cashOutListeners: { Listener } = {}
local animated: { [Instance]: Animated } = {}

local function subscribe(list: { Listener }, listener: Listener): () -> ()
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
-- Montants (même écriture que les billboards de DisplayService)
------------------------------------------------------------------------------

local function oneDecimal(value: number): string
	local tenths = math.floor(value * 10 + 1e-9)
	local whole, decimal = tenths // 10, tenths % 10
	if decimal == 0 then
		return string.format("%d", whole)
	end
	return string.format("%d,%d", whole, decimal)
end

local function groupThousands(value: number): string
	local digits = string.format("%d", math.floor(value))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1 ")))
	return (string.gsub(grouped, "^ ", ""))
end

local MONEY_UNITS = {
	{ Value = 1e9, Suffix = "Md$" },
	{ Value = 1e6, Suffix = "M$" },
	{ Value = 1e3, Suffix = "K$" },
}
local function formatMoney(amount: number): string
	if amount ~= amount or amount < 0 then
		amount = 0
	end
	for i, unit in MONEY_UNITS do
		if amount >= unit.Value then
			local scaled = amount / unit.Value
			if scaled < 100 then
				return `{oneDecimal(scaled)} {unit.Suffix}`
			elseif scaled < 1000 or i == 1 then
				return `{groupThousands(scaled)} {unit.Suffix}`
			end
		end
	end
	return `{groupThousands(amount)} $`
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
		print(`[Caisse] +{formatMoney(amount)} encaissés (revenu de ta boutique : {formatMoney(DisplayController.GetIncome())}/s)`)
	end
	emit(cashOutListeners, amount)
end

local function onIncomeChanged()
	emit(incomeListeners, numberAttribute(localPlayer, INCOME_ATTRIBUTE))
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

local function track(model: Instance)
	local kind = model:GetAttribute(HALO_ATTRIBUTE)
	if kind ~= "Rays" and kind ~= "Rainbow" then
		return
	end
	task.spawn(function()
		local found = model:FindFirstChild(HALO_PART) or model:WaitForChild(HALO_PART, HALO_WAIT)
		if found == nil or not found:IsA("BasePart") then
			return
		end
		if not CollectionService:HasTag(model, DISPLAY_TAG) or not model:IsDescendantOf(Workspace) then
			return -- retiré pendant l'attente
		end
		local halo = found :: BasePart
		local centerFound = halo:FindFirstChild(RAYS_CENTER)
		local center = if centerFound ~= nil and centerFound:IsA("Attachment") then centerFound :: Attachment else nil
		local rays: { Ray } = {}
		if center then
			for _, child in halo:GetChildren() do
				if child:IsA("Attachment") and string.sub(child.Name, 1, #RAY_PREFIX) == RAY_PREFIX then
					local tip = child :: Attachment
					local offset = tip.Position - center.Position
					table.insert(rays, {
						attachment = tip,
						beam = tip:FindFirstChildOfClass("Beam") :: Beam?,
						angle = math.atan2(offset.Y, offset.X),
						radius = math.sqrt(offset.X * offset.X + offset.Y * offset.Y),
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
			rainbow = kind == "Rainbow",
			light = halo:FindFirstChildOfClass("PointLight") :: PointLight?,
			gradient = if gradient ~= nil and gradient:IsA("UIGradient") then gradient :: UIGradient else nil,
		}
	end)
end

local function animate()
	local camera = Workspace.CurrentCamera
	if camera == nil or next(animated) == nil then
		return
	end
	local eye = camera.CFrame.Position
	local t = os.clock()
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
		if center then
			local base = center.Position
			local turn = t * RAYS_TURN_SPEED
			for i, ray in entry.rays do
				local angle = ray.angle + turn
				ray.attachment.Position = base + Vector3.new(math.cos(angle) * ray.radius, math.sin(angle) * ray.radius, 0)
				local beam = ray.beam
				if entry.rainbow and beam then
					beam.Color = ColorSequence.new(rainbowAt(t / RAINBOW_PERIOD + i / #entry.rays))
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

function DisplayController.PlaceItem(itemUid: string, slotIndex: number)
	if net == nil then
		warn("[DisplayController] remotes pas encore prêts : PlaceItem ignoré")
		return
	end
	net.Client.PlaceItem:Fire(itemUid, slotIndex)
end

DisplayController.FormatMoney = formatMoney

function DisplayController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local models = require(shared:WaitForChild("Contract"):WaitForChild("Models") :: ModuleScript) :: any
	plotTag = models.Plot.Tag
	local rarities = require(shared:WaitForChild("Config"):WaitForChild("Rarities") :: ModuleScript) :: any
	local secret = rarities.ById.Secret
	rainbowColors = if secret and secret.RainbowColors then secret.RainbowColors else {}

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
	end)
	for _, model in CollectionService:GetTagged(DISPLAY_TAG) do
		track(model)
	end
	RunService.Heartbeat:Connect(animate)

	-- Peut attendre que le serveur ait créé les remotes.
	net = require(shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
end

return DisplayController
