--!strict
-- WheelController (DEV-141 ; vague 80, a266 ; L-165 point 3 ; client) : roue de la fortune, écran UI_Wheel de Clément
-- (version grise puis habillée du 2026-11-14). Règles : Config/Wheel ; serveur : WheelService. Coupé par
-- Features.Wheel (rien ne s'ouvre ; HudController cache WheelButton). Écran ou élément absent : rien ne s'affiche,
-- aucune erreur.
--
-- Rôle :
--   - la zone WheelZone du hub (HubController → WheelController.Open) et UI_HUD.WheelButton (facultatif, tous les
--     exemplaires) ouvrent l'écran ; CloseButton le ferme ; ouverture et fermeture par UI/Motion ;
--   - WheelAlert (pastille « ! » de WheelButton, UI/AlertBadge) allumée quand le tour gratuit du jour attend ;
--   - Wheel.Segment_01 à Segment_08 (ordre de Config/Wheel.Sectors) : Amount = le lot (« 5 MIN CASH »), Icon = Decal
--     ICON_<Icon> de Clément s'il est livré (sinon son icône d'exemple reste), Chance (facultatif) = « 30% » ;
--   - SpinButton : envoie SpinWheel() quand un tour est permis (gratuit du jour, ou tour en plus) ; SpinLabel garde le
--     texte de Clément quand un tour attend, « ... » pendant le tour, le temps avant minuit UTC sinon ; Timer :
--     « Next spin in 12:34:56 » quand le tour gratuit est pris, vide sinon ;
--   - au résultat (remote WheelResult(secteur, message), décidé et déjà donné par le serveur) : la roue (Wheel.Rotation)
--     tourne Config/Wheel.Turns tours puis s'arrête avec ce secteur sous Pointer (SpinSeconds, Quint Out), puis Result
--     montre le message pendant ResultSeconds. Sans Result, ou écran fermé, le message part en notification ;
--   - BuySpinButton.PriceLabel (facultatifs) : « Soon » tant que Config/Wheel.ExtraSpin.ProductId = 0 (aucun achat).
--     a511 (L-481, règle Roblox des objets payants au hasard) : avec un produit, BuySpinButton n'est visible que si
--     PolicyService permet les objets payants au hasard à ce joueur (ArePaidRandomItemsRestricted faux ; pas encore lu
--     ou erreur : caché, comme la caisse de RobuxShopController) et si les 8 Chance sont là (chances vues avant l'achat).
--     Le futur achat doit passer par WheelController.CanBuySpins().
--   - a511 : Chance = la vraie chance du joueur (Config/Wheel.LuckyWeights avec la chance du serveur × la chance
--     personnelle, comme le tirage de WheelService), à une décimale, somme 100 %, remise à jour tant que l'écran est ouvert.
-- Angles : le centre de chaque segment autour du centre de Wheel (mise en page de Clément, sans la rotation) et celui
-- de Pointer ; un segment centré sur la roue (cadre plein tourné) prend sa Rotation ; sans mise en page lisible,
-- Segment_01 en haut et les suivants dans le sens des aiguilles d'une montre, Pointer en haut.
-- Seuls sont touchés : Enabled de l'écran, les textes, Visible de Result et de BuySpinButton (a511), l'image des Icon
-- et Wheel.Rotation.
--
-- API (client) :
--   WheelController.Open()                                  ouvre l'écran (roue allumée et écran présent)
--   WheelController.GetState() -> { Open, Spinning, FreeReady, Extra, LastSector, LastMessage, Rotation }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Wheel = require(Config:WaitForChild("Wheel"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Icons = require(Shared:WaitForChild("Contract"):WaitForChild("Icons"))
local AlertBadge = require(Shared:WaitForChild("AlertBadge"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type Screen = {
	gui: ScreenGui,
	wheel: GuiObject?,
	pointer: GuiObject?,
	result: GuiObject?,
	spinButton: Instance?,
	spinLabel: Instance?,
	spinText: string, -- texte de SpinLabel posé par Clément
	timer: Instance?,
	segments: { GuiObject? },
	buy: GuiObject?, -- a511 : BuySpinButton (facultatif)
	connections: { RBXScriptConnection },
}

local SCREEN = "UI_Wheel"
local HUD = "UI_HUD"
local HUD_BUTTON = "WheelButton"
local HUD_ALERT = "WheelAlert"
local SEGMENT_FORMAT = "Segment_%02d"
local ATTRIBUTES = Wheel.Attributes
local MESSAGES = Wheel.Messages
local SPIN_TEXT = "SPIN" -- si SpinLabel n'a pas de texte
-- V0 proposé (Cantin, 20/11) : cadence (s) des minuteurs et de la pastille ; attente (s) d'une réponse du serveur.
local REFRESH = 0.25
local ANSWER_TIMEOUT = 5

local IS_STUDIO = RunService:IsStudio()

local WheelController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local spinning = false
local askedAt = -math.huge
local lastSector: number? = nil
local lastMessage: string? = nil
local resultToken = 0
local net: any = nil
local reported: { [string]: boolean } = {}
local hudBound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local alerts: { GuiObject } = {}
local rng = Random.new()
-- a511 (L-481) : règle Roblox des objets payants au hasard, lue une fois quand un produit de tours existe.
local spinPolicy: "unknown" | "allowed" | "restricted" = "unknown"

-- a511 : Shared/OpenLuck chargé s'il est là (comme WheelService) ; absent : chances sans chance achetée.
local OpenLuck: any = (function(): any
	local found = Shared:FindFirstChild("OpenLuck")
	if found == nil then
		return nil
	end
	local ok, module = pcall(require, found :: any)
	return if ok and type(module) == "table" then module else nil
end)()

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(`[Wheel] {message}`)
	end
end

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function guiObject(root: Instance?, path: string): GuiObject?
	if root == nil then
		return nil
	end
	local found = Find.path(root, path)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function textHolder(element: Instance?): Instance?
	if element == nil then
		return nil
	end
	if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
		return element
	end
	return element:FindFirstChildWhichIsA("TextLabel", true)
end

local function setText(element: Instance?, text: string)
	local holder = textHolder(element)
	if holder then
		local label = holder :: any
		if label.Text ~= text then
			label.Text = text
		end
	end
end

local function textOf(element: Instance?): string?
	local holder = textHolder(element)
	local text = if holder then (holder :: any).Text else nil
	return if type(text) == "string" and text ~= "" then text else nil
end

local function setVisible(element: GuiObject?, visible: boolean)
	if element and element.Visible ~= visible then
		element.Visible = visible
	end
end

local function onClick(element: Instance?, handler: () -> ()): RBXScriptConnection?
	if element ~= nil and element:IsA("GuiButton") then
		return Motion.Activated(element :: GuiButton):Connect(function()
			handler()
		end)
	end
	return nil
end

local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d:%02d", whole // 3600, (whole % 3600) // 60, whole % 60)
end

local function number(value: any): number
	return if type(value) == "number" and value == value then value else 0
end

-- Centre d'un objet d'UI à l'écran (mise en page, sans la rotation), ou nil s'il n'a pas de taille lisible.
local function centerOf(element: GuiObject): (number?, number?)
	local ok, position, size = pcall(function()
		return element.AbsolutePosition, element.AbsoluteSize
	end)
	if not ok or typeof(position) ~= "Vector2" or typeof(size) ~= "Vector2" then
		return nil, nil
	end
	return position.X + size.X / 2, position.Y + size.Y / 2
end

------------------------------------------------------------------------------
-- État lu sur les attributs de WheelService
------------------------------------------------------------------------------

local function freeReady(): boolean
	return localPlayer:GetAttribute(ATTRIBUTES.FreeReady) == true
end

local function extraSpins(): number
	return math.max(0, math.floor(number(localPlayer:GetAttribute(ATTRIBUTES.ExtraSpins))))
end

local function canSpin(): boolean
	return freeReady() or extraSpins() > 0
end

------------------------------------------------------------------------------
-- Peinture
------------------------------------------------------------------------------

-- a511 (L-481) : la chance achetée qui pèse sur ce joueur (comme drawLucky de WheelService) ; 1 sans modèle R2.
local function boughtLuck(): number
	if OpenLuck == nil or OpenLuck.V2 ~= true then
		return 1
	end
	local ok, luck = pcall(function(): any
		return OpenLuck.Bought({ Server = Workspace:GetAttribute("ServerLuck"), Personal = OpenLuck.PersonalFactorOf(localPlayer) })
	end)
	return if ok and type(luck) == "number" then luck else 1
end

-- a511 : chances affichées (pour cent, une décimale, somme 100), les vraies du prochain tour.
local function chances(): { number }
	return Wheel.Percents(Wheel.LuckyWeights(boughtLuck(), if OpenLuck then OpenLuck.Shift else nil))
end

local function formatChance(percent: number): string
	return string.format("%g%%", percent)
end

local function paintChances(current: Screen)
	local percents = chances()
	for index in Wheel.Sectors do
		local segment = current.segments[index]
		local chance = if segment then Find.path(segment, "Chance") else nil
		if chance then
			setText(chance, formatChance(percents[index] or 0))
		end
	end
end

-- a511 : toutes les chances sont écrites à l'écran (chaque Segment_NN a son Chance).
local function chancesShown(current: Screen): boolean
	for index in Wheel.Sectors do
		local segment = current.segments[index]
		if segment == nil or textHolder(Find.path(segment, "Chance")) == nil then
			return false
		end
	end
	return true
end

-- a511 (L-481) : un tour en plus peut être proposé à l'achat (produit créé, PolicyService d'accord, chances affichées).
local function canBuySpins(current: Screen?): boolean
	return Features.Wheel == true
		and Wheel.ExtraSpin.ProductId ~= 0
		and spinPolicy == "allowed"
		and current ~= nil
		and chancesShown(current)
end

local function paintBuy(current: Screen)
	local buy = current.buy
	if buy == nil then
		return
	end
	if Wheel.ExtraSpin.ProductId == 0 then
		setText(Find.path(buy, "PriceLabel") or buy, MESSAGES.Soon)
		return
	end
	setText(Find.path(buy, "PriceLabel") or buy, `R$ {Wheel.ExtraSpin.Price}`)
	setVisible(buy, canBuySpins(current))
end

local function paintSegments(current: Screen)
	for index, sector in Wheel.Sectors do
		local segment = current.segments[index]
		if segment == nil then
			reportOnce(`segment:{index}`, `{SCREEN}.Wheel.{string.format(SEGMENT_FORMAT, index)} introuvable`)
			continue
		end
		setText(Find.path(segment, "Amount"), sector.Label)
		local icon = Find.path(segment, "Icon")
		local texture = if sector.Icon then Icons.get(sector.Icon) else nil
		if texture and icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
			(icon :: any).Image = texture
		end
	end
	paintChances(current)
	paintBuy(current)
end

local function refresh()
	if not Features.Wheel then
		return
	end
	local ready = freeReady()
	for index = #alerts, 1, -1 do
		local alert = alerts[index]
		if alert.Parent == nil then
			table.remove(alerts, index)
		else
			AlertBadge.Set(alert, ready)
		end
	end
	if spinning and os.clock() - askedAt > ANSWER_TIMEOUT and lastSector == nil then
		spinning = false -- pas de réponse du serveur (tour refusé) : le bouton revient
	end
	local current = screen
	if current == nil or not isOpen or current.gui.Parent == nil then
		return
	end
	local nextAt = localPlayer:GetAttribute(ATTRIBUTES.NextFreeAt)
	local left = if type(nextAt) == "number" then nextAt - Workspace:GetServerTimeNow() else 0
	if spinning then
		setText(current.spinLabel, MESSAGES.Spinning)
	elseif canSpin() then
		setText(current.spinLabel, current.spinText)
	else
		setText(current.spinLabel, clock(left))
	end
	setText(current.timer, if ready then "" else string.format(MESSAGES.NextIn, clock(left)))
	-- a511 (L-481) : chances et bouton d'achat suivis tant que l'écran est ouvert (une chance qui commence ou finit).
	paintChances(current)
	paintBuy(current)
end

------------------------------------------------------------------------------
-- Tour
------------------------------------------------------------------------------

-- Angle (degrés, 0 = droite, sens des aiguilles d'une montre) de chaque segment dans la mise en page de Clément,
-- roue à Rotation 0. a312 (Play f92) : l'AbsolutePosition d'un segment suit la rotation de la roue (à partir du 2e
-- tour d'une session, l'arrêt était faux de la rotation de départ) ; on la retire, pour que les trois sources
-- d'angle (position, Rotation d'un cadre plein, repli) parlent de la même roue non tournée.
local function segmentAngles(current: Screen): { number }
	local count = #Wheel.Sectors
	local angles: { number } = {}
	local wheel = current.wheel
	local cx, cy
	local wheelRotation = 0
	if wheel then
		local x, y = centerOf(wheel)
		cx, cy = x, y
		wheelRotation = number(wheel.Rotation)
	end
	local distinct: { [number]: boolean } = {}
	local distinctCount = 0
	for index = 1, count do
		local segment = current.segments[index]
		local angle: number? = nil
		if segment and cx and cy then
			local sx, sy = centerOf(segment)
			if sx and sy then
				local dx, dy = sx - cx, sy - cy
				local radius = if wheel then number(wheel.AbsoluteSize.X) * 0.05 else 0
				if math.sqrt(dx * dx + dy * dy) > math.max(4, radius) then
					angle = math.deg(math.atan2(dy, dx)) - wheelRotation
				else
					angle = -90 + number(segment.Rotation) -- cadre plein tourné par Clément
				end
			end
		end
		local value = angle or (-90 + (index - 1) * 360 / count)
		angles[index] = value
		local key = math.floor(value % 360 + 0.5)
		if not distinct[key] then
			distinct[key] = true
			distinctCount += 1
		end
	end
	if distinctCount < count then
		-- Mise en page illisible (tailles nulles, segments superposés) : Segment_01 en haut, puis sens horaire.
		for index = 1, count do
			angles[index] = -90 + (index - 1) * 360 / count
		end
	end
	return angles
end

local function pointerAngle(current: Screen): number
	local wheel, pointer = current.wheel, current.pointer
	if wheel and pointer then
		local cx, cy = centerOf(wheel)
		local px, py = centerOf(pointer)
		if cx and cy and px and py then
			local dx, dy = px - cx, py - cy
			if math.sqrt(dx * dx + dy * dy) > 4 then
				return math.deg(math.atan2(dy, dx))
			end
		end
	end
	return -90 -- en haut
end

-- Rotation finale de la roue pour que le secteur `index` s'arrête sous Pointer.
local function targetRotation(current: Screen, index: number): number
	local wheel = current.wheel :: GuiObject
	local count = #Wheel.Sectors
	local base = segmentAngles(current)[index]
	local jitter = (rng:NextNumber() * 2 - 1) * Wheel.Jitter * (180 / count)
	local start = number(wheel.Rotation) % 360
	wheel.Rotation = start -- même image : la rotation reste petite d'un tour à l'autre
	local desired = (pointerAngle(current) - base + jitter) % 360
	return start + Wheel.Turns * 360 + ((desired - start) % 360)
end

local function showResult(message: string)
	local current = screen
	local result = if current then current.result else nil
	if current == nil or not isOpen or result == nil or current.gui.Parent == nil then
		-- Pas de Result (ou écran fermé) : le message part en notification.
		local module = script.Parent:FindFirstChild("NotifyController")
		if module and module:IsA("ModuleScript") then
			local ok: boolean, loaded: any = pcall(require, module)
			local show: any = if ok and loaded then loaded.Show else nil
			if show ~= nil then
				(show :: any)(message, "Info")
			end
		end
		return
	end
	setText(result, message)
	setVisible(result, true)
	resultToken += 1
	local token = resultToken
	task.delay(Wheel.ResultSeconds, function()
		if token == resultToken then
			setVisible(result, false)
		end
	end)
end

local function onWheelResult(index: number, message: string)
	if Wheel.Sectors[index] == nil then
		return
	end
	lastSector = index
	lastMessage = message
	local current = screen
	local wheel = if current then current.wheel else nil
	if current == nil or wheel == nil or not isOpen then
		spinning = false
		if message ~= "" then
			showResult(message)
		end
		refresh()
		return
	end
	local rotation = targetRotation(current, index)
	local tween = TweenService:Create(wheel, TweenInfo.new(Wheel.SpinSeconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = rotation })
	tween.Completed:Connect(function()
		spinning = false
		if message ~= "" then
			showResult(message)
		end
		refresh()
	end)
	tween:Play()
end

local function spin()
	if spinning or net == nil or not canSpin() then
		return
	end
	local current = screen
	if current and current.result then
		resultToken += 1
		setVisible(current.result, false)
	end
	spinning = true
	askedAt = os.clock()
	lastSector = nil
	lastMessage = nil
	refresh()
	net.Client.SpinWheel:Fire()
end

------------------------------------------------------------------------------
-- Écran
------------------------------------------------------------------------------

local function close()
	isOpen = false
	local current = screen
	if current then
		Motion.Close(current.gui)
	end
end

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
	end
	isOpen = false
	gui.Enabled = false
	Motion.SetCloser(gui, close)
	local wheel = guiObject(gui, "Wheel")
	local spinButton = Find.path(gui, "SpinButton")
	local spinLabel = if spinButton then Find.path(spinButton, "SpinLabel") else nil
	local current: Screen = {
		gui = gui,
		wheel = wheel,
		pointer = guiObject(gui, "Pointer"),
		result = guiObject(gui, "Result"),
		spinButton = spinButton,
		spinLabel = spinLabel or spinButton,
		spinText = textOf(spinLabel or spinButton) or SPIN_TEXT,
		timer = Find.path(gui, "Timer"),
		segments = {},
		buy = guiObject(gui, "BuySpinButton"),
		connections = {},
	}
	for index = 1, #Wheel.Sectors do
		current.segments[index] = if wheel then guiObject(wheel, string.format(SEGMENT_FORMAT, index)) else nil
	end
	if wheel == nil then
		reportOnce("wheel", `{SCREEN}.Wheel introuvable : la roue ne tourne pas à l'écran (le lot part en notification)`)
	end
	screen = current
	setVisible(current.result, false)
	paintSegments(current) -- a511 : peint aussi les chances et BuySpinButton (paintBuy)
	local spinConnection = onClick(spinButton, spin)
	if spinConnection then
		table.insert(current.connections, spinConnection)
	end
	local closeConnection = onClick(Find.path(gui, "CloseButton"), close)
	if closeConnection then
		table.insert(current.connections, closeConnection)
	end
end

local function currentScreen(): Screen?
	local current = screen
	if current and current.gui.Parent ~= nil then
		return current
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild(SCREEN) else nil
	if gui and gui:IsA("ScreenGui") then
		bind(gui :: ScreenGui)
		return screen
	end
	return nil
end

local function open()
	if not Features.Wheel then
		return
	end
	local current = currentScreen()
	if current == nil then
		reportOnce("screen", `écran {SCREEN} absent de PlayerGui : la roue ne s'ouvre pas`)
		return
	end
	isOpen = true
	refresh()
	Motion.Open(current.gui)
end

local function toggle()
	if isOpen then
		close()
	else
		open()
	end
end

local function bindHud(gui: Instance)
	if hudBound[gui] then
		return
	end
	hudBound[gui] = true
	for _, found in Find.all(gui, HUD_BUTTON) do
		if found:IsA("GuiButton") then
			local alert = guiObject(found, HUD_ALERT)
			if alert then
				table.insert(alerts, alert)
			end
			Motion.Activated(found :: GuiButton):Connect(toggle)
		end
	end
	refresh()
end

function WheelController.Open()
	if not isOpen then
		open()
	end
end

-- a511 (L-481) : un tour en plus peut être acheté maintenant (produit créé, PolicyService d'accord, chances affichées).
-- Le futur achat (PromptProductPurchase) doit le vérifier avant d'ouvrir la fenêtre de Roblox.
function WheelController.CanBuySpins(): boolean
	return canBuySpins(screen)
end

-- a511 : chances affichées (pour cent, somme 100), pour les bancs et la barre de commande.
function WheelController.GetChances(): { number }
	return chances()
end

function WheelController.GetState(): { Open: boolean, Spinning: boolean, FreeReady: boolean, Extra: number, LastSector: number?, LastMessage: string?, Rotation: number? }
	local current = screen
	return {
		Open = isOpen,
		Spinning = spinning,
		FreeReady = freeReady(),
		Extra = extraSpins(),
		LastSector = lastSector,
		LastMessage = lastMessage,
		Rotation = if current and current.wheel then current.wheel.Rotation else nil,
	}
end

function WheelController.Start()
	if not Features.Wheel then
		return -- coupée : rien n'est branché (HudController cache WheelButton)
	end
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	net.Client.WheelResult:Connect(onWheelResult)
	-- a511 (L-481) : PolicyService lu une fois, seulement quand un produit de tours existe ; erreur : achat caché.
	if Wheel.ExtraSpin.ProductId ~= 0 then
		task.spawn(function()
			local ok, info = pcall(function(): any
				return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(localPlayer)
			end)
			if ok and type(info) == "table" and type(info.ArePaidRandomItemsRestricted) == "boolean" then
				spinPolicy = if info.ArePaidRandomItemsRestricted then "restricted" else "allowed"
			else
				spinPolicy = "restricted"
				reportOnce("policy", `PolicyService pas lu ({if ok then "réponse inattendue" else tostring(info)}) : achat de tours caché`)
			end
			refresh()
		end)
	end
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui)
		elseif child.Name == HUD and child:IsA("ScreenGui") then
			bindHud(child)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end
	local hud = playerGui:FindFirstChild(HUD)
	if hud and hud:IsA("ScreenGui") then
		bindHud(hud)
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < REFRESH then
			return
		end
		elapsed = 0
		refresh()
	end)
	refresh()
end

return WheelController
