--!strict
-- PawnShopController (DEV-034, client ; liaison L-106 point 4 et L-107 point 2 ; note docs/claude/notes/ui-pawnshop.md,
-- points 1 à 9) : le dialogue avec le receleur du hub, écran StarterGui/UI_PawnShop de Clément et bulle
-- ReplicatedStorage/Assets/UI/BB_PawnTalk au-dessus de Vendor_Pawn. Valeurs et répliques : Config/Pawn.
--
-- Rôle :
--   - ouverture quand le joueur monte sur la plaque ShopPad du stand taggé PawnShop (ShopPadController appelle
--     Open) ; fermeture quand il en descend (Leave), s'éloigne à plus de CLOSE_DISTANCE studs de la plaque, ou
--     par LeaveButton (le vendeur dit alors « Come back anytime! », qui reste FarewellTime s dans la bulle).
--     Un autre écran du groupe ScreenGroup qui s'ouvre le ferme aussi (Motion.SetCloser) ;
--   - à l'ouverture et à chaque changement de l'inventaire (attribut InventoryState) ou du portage (Carrying),
--     demande l'offre au serveur (PawnAsk) ; PawnOffer remplit les prix : SellHeldButton.Price (objet tenu),
--     SellAllButton.Price (tout l'inventaire hors objets exposés), en Format.money ;
--   - Dialog.Choices : SellHeldButton (1), SellAllButton (2), LeaveButton (3) ; DealButton (1) et NoDealButton (2)
--     les remplacent pour une confirmation : objet tenu de rareté Pawn.ConfirmFrom ou plus (« A Mythic? I'll give
--     you $1.44M. Deal? »), et chaque « tout vendre » (« 9 items for $2.1M. Deal? »). NoDealButton ramène les
--     3 choix. SellHeldButton est grisé (texte Pawn.DisabledColor) sans objet tenu ou pendant un portage ;
--     SellAllButton, sans objet à vendre ; un choix grisé fait seulement parler le vendeur ;
--   - vente : PawnSellHeld(uid de l'offre) ou PawnSellAll(nombre de l'offre) ; le serveur décide et répond par
--     PawnSold : vendu → « Pleasure doing business! » et Motion.Success sur le bouton (T.33 ; l'argent sursaute
--     et défile au HUD par GainController, T.38 et T.15) ; refusé → réplique Changed, secousse des choix
--     (T.18, UiMotion.Shake) et UI_Deny ;
--   - bulle : une copie de BB_PawnTalk dans PlayerGui (nom PawnTalk), Adornee = Head de Vendor_Pawn ; chaque
--     réplique est écrite dans Line et fait un pop (T.35, UiMotion.Toast) ;
--   - survol d'un choix (T.49) : KeyLabel et ChoiceLabel en Pawn.HoverColor (l'échelle × 1,06, l'appui et le
--     relâché, T.31 et T.32, viennent d'UiFeelController, comme pour tous les boutons) ;
--   - touches 1, 2 et 3 sur PC (ContextActionService, priorité haute, tant que l'écran est ouvert : la barre
--     du bas ne les reçoit pas pendant ce temps).
-- Seuls sont touchés : Enabled de l'écran, Visible des 5 choix, le texte des Price, la couleur du texte des
-- KeyLabel, ChoiceLabel et Price (survol et grisé demandés par Clément, remise à sa couleur ensuite), la Position
-- de Choices pendant la secousse (remise ensuite), et la copie de la bulle. Rien ne se décide ici.
--
-- API (client) :
--   PawnShopController.Open(anchor)    ouvre le dialogue (anchor = la plaque ShopPad du stand)
--   PawnShopController.Leave(anchor)   le joueur descend de la plaque : fermeture
--   PawnShopController.GetState() -> { Open, Mode, Line, HeldUid, HeldPrice, AllCount, AllPrice }   (bancs)

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Pawn = require(Config:WaitForChild("Pawn"))
local Rarities = require(Config:WaitForChild("Rarities"))
local UiMotion = require(Config:WaitForChild("UiMotion"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local InventoryState = require(Shared:WaitForChild("InventoryState"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

-- Mode : "Closed", "Choices", "ConfirmHeld", "ConfirmAll" ou "Waiting" ; ChoiceName : "SellHeld", "SellAll",
-- "Leave", "Deal" ou "NoDeal" (des string : l'ancien solveur refuse les comparaisons après un affinage).
type Mode = string
type ChoiceName = string

type Choice = {
	button: GuiObject,
	labels: { TextLabel }, -- KeyLabel, ChoiceLabel, Price présents
	colors: { [TextLabel]: Color3 }, -- couleur de Clément
	hoverLabels: { [TextLabel]: boolean }, -- KeyLabel et ChoiceLabel (jaunis au survol)
	price: TextLabel?,
	hovered: boolean,
	disabled: boolean,
}

type Screen = {
	gui: ScreenGui,
	choicesFrame: GuiObject?,
	choices: { [string]: Choice },
	connections: { RBXScriptConnection },
}

type Offer = { heldUid: string, heldItemId: string, heldPrice: number, allCount: number, allPrice: number }
type Pending = { kind: "Held" | "All", uid: string, count: number, price: number } -- uid : objet tenu ; count : tout vendre

-- Contrat (2.1, 2.2 et 10.4 ; Contract/UI et Contract/Models).
local SCREEN = "UI_PawnShop"
local BUBBLE = "BB_PawnTalk"
local BUBBLE_COPY = "PawnTalk"
local LINE = "Line"
local PAWN_TAG = "PawnShop"
local VENDOR = "Vendor_Pawn"
local HEAD = "Head"
local CHOICE_PATHS: { [string]: string } = {
	SellHeld = "Dialog.Choices.SellHeldButton",
	SellAll = "Dialog.Choices.SellAllButton",
	Leave = "Dialog.Choices.LeaveButton",
	Deal = "Dialog.Choices.DealButton",
	NoDeal = "Dialog.Choices.NoDealButton",
}
local CHOICES_PATH = "Dialog.Choices"
local LABELS = { "KeyLabel", "ChoiceLabel", "Price" }
local HOVER_LABELS = { KeyLabel = true, ChoiceLabel = true }
local ROOT_PART = "HumanoidRootPart"
local INVENTORY_ATTRIBUTE = InventoryState.Attribute
local CARRYING_ATTRIBUTE = "Carrying" -- CarryService

-- V0 proposés, absents du doc : distance (studs) à la plaque au-delà de laquelle l'écran se ferme (si la sortie
-- de la plaque n'a pas été vue) ; regroupement (s) des demandes d'offre ; attente (s) d'une réponse PawnSold
-- avant de rendre la main.
local CLOSE_DISTANCE = 16
local ASK_DELAY = 0.25
local WAIT_TIMEOUT = 3
local KEYS_ACTION = "PawnShopKeys"
local KEY_CODES = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.KeypadOne,
	Enum.KeyCode.KeypadTwo,
	Enum.KeyCode.KeypadThree,
}

local IS_STUDIO = RunService:IsStudio()
local LINES = Pawn.Lines
local CONFIRM_RARITY = Rarities.ById[Pawn.ConfirmFrom]
local CONFIRM_ORDER: number = if CONFIRM_RARITY then CONFIRM_RARITY.Order else math.huge
local POP_INFO = TweenInfo.new(UiMotion.Toast.Time, UiMotion.Toast.Style, UiMotion.Toast.Direction)
local HOVER_INFO = TweenInfo.new(UiMotion.Hover.Time, UiMotion.Hover.Style, UiMotion.Hover.Direction)

local PawnShopController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local screen: Screen? = nil
local mode: Mode = "Closed"
local openAt: BasePart? = nil
local offer: Offer? = nil
local pending: Pending? = nil
local lastButton: GuiObject? = nil
local currentLine = ""
local bubble: BillboardGui? = nil
local bubbleToken = 0
local askQueued = false
local waitToken = 0
local shakeToken = 0
local shakeOrigin: UDim2? = nil -- Position de Clément pendant une secousse
local confirmShown = false -- DealButton et NoDealButton montrés à la place des 3 choix
local reported: { [string]: boolean } = {}

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

------------------------------------------------------------------------------
-- Bulle du vendeur
------------------------------------------------------------------------------

-- Le stand taggé PawnShop qui contient `anchor`, ou nil.
local function standOf(anchor: Instance): Instance?
	for _, stand in CollectionService:GetTagged(PAWN_TAG) do
		if anchor:IsDescendantOf(stand) then
			return stand
		end
	end
	return nil
end

local function vendorHead(): BasePart?
	local anchor = openAt
	local stand = if anchor then standOf(anchor) else nil
	local vendor = if stand then Find.path(stand, VENDOR) else nil
	local head = if vendor then vendor:FindFirstChild(HEAD, true) else nil
	if head and head:IsA("BasePart") then
		return head :: BasePart
	end
	return nil
end

-- La copie de la bulle (créée au besoin), accrochée à la tête du vendeur ; nil si BB_PawnTalk manque.
local function ensureBubble(): BillboardGui?
	local existing = bubble
	if existing and existing.Parent ~= nil then
		return existing
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("UI") else nil
	local model = if folder then folder:FindFirstChild(BUBBLE) else nil
	if model == nil or not model:IsA("BillboardGui") then
		reportOnce("bubble", `[PawnShop] ReplicatedStorage/Assets/UI/{BUBBLE} absent : le vendeur ne parle pas`)
		return nil
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local copy = (model :: BillboardGui):Clone()
	copy.Name = BUBBLE_COPY
	copy.Enabled = false
	copy.ResetOnSpawn = false
	copy.Parent = playerGui
	bubble = copy
	return copy
end

local function say(text: string)
	currentLine = text
	bubbleToken += 1
	local copy = ensureBubble()
	if copy == nil then
		return
	end
	local head = vendorHead()
	if head then
		copy.Adornee = head
	elseif not copy.Adornee then
		reportOnce("head", `[PawnShop] {VENDOR}.{HEAD} introuvable dans le stand : bulle sans place`)
	end
	local line = Find.path(copy, LINE)
	if line and (line:IsA("TextLabel") or line:IsA("TextButton")) then
		(line :: any).Text = text
		Motion.Pop(line :: GuiObject, UiMotion.Toast.From, POP_INFO) -- T.35
	end
	copy.Enabled = true
end

-- La bulle s'éteint `delay` s plus tard, sauf si une autre réplique arrive d'ici là.
local function hideBubbleLater(delay: number)
	bubbleToken += 1
	local token = bubbleToken
	task.delay(delay, function()
		local copy = bubble
		if token == bubbleToken and copy then
			copy.Enabled = false
		end
	end)
end

------------------------------------------------------------------------------
-- Écran
------------------------------------------------------------------------------

local function choiceColor(choice: Choice, label: TextLabel): Color3
	if choice.disabled then
		return Pawn.DisabledColor
	end
	if choice.hovered and choice.hoverLabels[label] then
		return Pawn.HoverColor
	end
	return choice.colors[label]
end

local function paint(choice: Choice, animate: boolean)
	for _, label in choice.labels do
		local color = choiceColor(choice, label)
		if animate then
			TweenService:Create(label, HOVER_INFO, { TextColor3 = color }):Play()
		else
			label.TextColor3 = color
		end
	end
end

local function setPrice(choice: Choice?, value: number)
	local label = if choice then choice.price else nil
	if label then
		label.Text = Format.money(value)
	end
end

local function rarityOf(itemId: string): any
	local def = Items.ById[itemId]
	return if def then Rarities.ById[def.Rarity] else nil
end

local function isCarrying(): boolean
	return localPlayer:GetAttribute(CARRYING_ATTRIBUTE) ~= nil
end

local function hasHeld(): boolean
	local current = offer
	return current ~= nil and current.heldUid ~= "" and not isCarrying()
end

-- Choix montrés, prix et grisés, selon le mode et l'offre.
local function render()
	local current = screen
	if current == nil then
		return
	end
	for name, choice in current.choices do
		local isConfirm = name == "Deal" or name == "NoDeal"
		choice.button.Visible = isConfirm == confirmShown
	end
	local data = offer
	setPrice(current.choices.SellHeld, if data then data.heldPrice else 0)
	setPrice(current.choices.SellAll, if data then data.allPrice else 0)
	local waiting = pending
	setPrice(current.choices.Deal, if waiting then waiting.price else 0)
	local held = current.choices.SellHeld
	if held then
		held.disabled = not hasHeld()
		paint(held, false)
	end
	local all = current.choices.SellAll
	if all then
		all.disabled = data == nil or data.allCount == 0
		paint(all, false)
	end
end

-- Secousse des choix (T.18) : ±Amplitude px, Count allers-retours en Time s, puis retour exact.
local function shake()
	local current = screen
	local frame = if current then current.choicesFrame else nil
	if frame == nil then
		return
	end
	local target: GuiObject = frame
	shakeToken += 1
	local token = shakeToken
	local spec = UiMotion.Shake
	local origin: UDim2 = shakeOrigin or target.Position
	shakeOrigin = origin
	local step = spec.Time / (spec.Count * 2)
	task.spawn(function()
		for i = 1, spec.Count * 2 do
			if token ~= shakeToken then
				return
			end
			local side = if i % 2 == 1 then 1 else -1
			local goal = origin + UDim2.fromOffset(side * spec.Amplitude, 0)
			TweenService:Create(target, TweenInfo.new(step, spec.Style, spec.Direction), { Position = goal }):Play()
			task.wait(step)
		end
		if token == shakeToken then
			target.Position = origin
			shakeOrigin = nil
		end
	end)
end

local function ask()
	if askQueued or mode == "Closed" then
		return
	end
	askQueued = true
	task.delay(ASK_DELAY, function()
		askQueued = false
		if mode ~= "Closed" and net then
			net.Client.PawnAsk:Fire()
		end
	end)
end

local function unbindKeys()
	ContextActionService:UnbindAction(KEYS_ACTION)
end

local function closeDialog(farewell: boolean)
	if mode == "Closed" then
		return
	end
	mode = "Closed"
	openAt = nil
	pending = nil
	unbindKeys()
	confirmShown = false
	local current = screen
	if current then
		Motion.Close(current.gui)
	end
	if farewell then
		say(LINES.Farewell)
		hideBubbleLater(Pawn.FarewellTime)
	else
		hideBubbleLater(0)
	end
end

-- Rend la main après une vente sans réponse du serveur (perdue, ignorée).
local function startWaiting(button: GuiObject?)
	mode = "Waiting"
	lastButton = button
	waitToken += 1
	local token = waitToken
	task.delay(WAIT_TIMEOUT, function()
		if token == waitToken and mode == "Waiting" then
			mode = "Choices"
			pending = nil
			confirmShown = false
			render()
		end
	end)
end

local function buttonOf(name: ChoiceName): GuiObject?
	local current = screen
	local choice = if current then current.choices[name] else nil
	return if choice then choice.button else nil
end

local function choose(name: ChoiceName)
	if mode == "Closed" or mode == "Waiting" then
		return
	end
	local data = offer
	if mode == "Choices" then
		if name == "SellHeld" then
			if isCarrying() then
				say(LINES.NotYours)
			elseif data == nil or data.heldUid == "" then
				say(LINES.NothingHeld)
			else
				local rarity = rarityOf(data.heldItemId)
				if rarity and rarity.Order >= CONFIRM_ORDER then
					local article = if string.find(rarity.DisplayName, "^[AEIOUaeiou]") then "An" else "A"
					pending = { kind = "Held", uid = data.heldUid, count = 1, price = data.heldPrice }
					mode = "ConfirmHeld"
					confirmShown = true
					say(string.format(LINES.ConfirmHeld, article, rarity.DisplayName, Format.money(data.heldPrice)))
				else
					pending = { kind = "Held", uid = data.heldUid, count = 1, price = data.heldPrice }
					startWaiting(buttonOf("SellHeld"))
					net.Client.PawnSellHeld:Fire(data.heldUid)
				end
			end
		elseif name == "SellAll" then
			if data == nil or data.allCount == 0 then
				say(LINES.EmptyInventory)
			else
				pending = { kind = "All", uid = "", count = data.allCount, price = data.allPrice }
				mode = "ConfirmAll"
				confirmShown = true
				local price = Format.money(data.allPrice)
				say(if data.allCount == 1 then string.format(LINES.ConfirmAllOne, price) else string.format(LINES.ConfirmAll, data.allCount, price))
			end
		elseif name == "Leave" then
			closeDialog(true)
			return
		end
	elseif mode == "ConfirmHeld" or mode == "ConfirmAll" then
		local waiting = pending
		if name == "Deal" and waiting then
			startWaiting(buttonOf("Deal"))
			if waiting.kind == "Held" then
				net.Client.PawnSellHeld:Fire(waiting.uid)
			else
				net.Client.PawnSellAll:Fire(waiting.count)
			end
		elseif name == "NoDeal" then
			confirmShown = false
			pending = nil
			mode = "Choices"
			say(LINES.NoDeal)
		end
	end
	render()
end

local function onSold(amount: number, count: number)
	if mode == "Closed" then
		return
	end
	waitToken += 1
	-- Après une confirmation, DealButton disparaît : le saut se joue sur le choix qui revient.
	local kind = if pending then pending.kind else nil
	local button = if confirmShown and kind then buttonOf(if kind == "Held" then "SellHeld" else "SellAll") else lastButton
	pending = nil
	mode = "Choices"
	confirmShown = false
	if count > 0 then
		say(LINES.Sold)
		if button and button:IsA("GuiButton") then
			Motion.Success(button :: GuiButton) -- T.33
		end
	else
		say(LINES.Changed)
		Motion.PlaySound(UiMotion.Sounds.Deny)
		shake()
	end
	render()
end

local function onOffer(heldUid: string, heldItemId: string, heldPrice: number, allCount: number, allPrice: number)
	offer = { heldUid = heldUid, heldItemId = heldItemId, heldPrice = heldPrice, allCount = allCount, allPrice = allPrice }
	if mode ~= "Closed" then
		render()
	end
end

local function onKey(_action: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local key = input.KeyCode
	local index = if key == Enum.KeyCode.One or key == Enum.KeyCode.KeypadOne
		then 1
		elseif key == Enum.KeyCode.Two or key == Enum.KeyCode.KeypadTwo then 2
		else 3
	local confirming = mode == "ConfirmHeld" or mode == "ConfirmAll"
	if confirming then
		if index == 1 then
			choose("Deal")
		elseif index == 2 then
			choose("NoDeal")
		end
	elseif index == 1 then
		choose("SellHeld")
	elseif index == 2 then
		choose("SellAll")
	else
		choose("Leave")
	end
	return Enum.ContextActionResult.Sink
end

local function textLabel(root: Instance, name: string): TextLabel?
	local found = Find.path(root, name)
	return if found and found:IsA("TextLabel") then found :: TextLabel else nil
end

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
	end
	mode = "Closed" -- écran recréé (ResetOnSpawn) : fermé
	openAt = nil
	pending = nil
	confirmShown = false
	unbindKeys()
	gui.Enabled = false
	Motion.SetCloser(gui, function()
		closeDialog(false)
	end)
	local current: Screen = { gui = gui, choicesFrame = nil, choices = {}, connections = {} }
	local frame = Find.path(gui, CHOICES_PATH)
	current.choicesFrame = if frame and frame:IsA("GuiObject") then frame :: GuiObject else nil
	for name, path in CHOICE_PATHS do
		local button = Find.path(gui, path)
		if button == nil or not button:IsA("GuiObject") then
			reportOnce(`choice:{name}`, `[PawnShop] {SCREEN}.{path} introuvable`)
			continue
		end
		local choice: Choice = {
			button = button :: GuiObject,
			labels = {},
			colors = {},
			hoverLabels = {},
			price = textLabel(button, "Price"),
			hovered = false,
			disabled = false,
		}
		for _, labelName in LABELS do
			local label = textLabel(button, labelName)
			if label then
				table.insert(choice.labels, label)
				choice.colors[label] = label.TextColor3
				choice.hoverLabels[label] = HOVER_LABELS[labelName] == true
			end
		end
		current.choices[name] = choice
		local choiceName: ChoiceName = name
		local target = button :: GuiObject
		if target:IsA("GuiButton") then
			table.insert(current.connections, (target :: GuiButton).Activated:Connect(function()
				choose(choiceName)
			end))
		end
		table.insert(current.connections, target.MouseEnter:Connect(function()
			choice.hovered = true
			paint(choice, true)
		end))
		table.insert(current.connections, target.MouseLeave:Connect(function()
			choice.hovered = false
			paint(choice, true)
		end))
	end
	screen = current
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

function PawnShopController.Open(anchor: BasePart)
	local current = currentScreen()
	if current == nil then
		reportOnce("screen", `[PawnShop] écran {SCREEN} absent de PlayerGui : le receleur ne s'ouvre pas`)
		return
	end
	openAt = anchor
	mode = "Choices"
	pending = nil
	confirmShown = false
	render()
	Motion.Open(current.gui)
	say(LINES.Greeting)
	ContextActionService:BindActionAtPriority(KEYS_ACTION, onKey, false, Enum.ContextActionPriority.High.Value, table.unpack(KEY_CODES))
	if net then
		net.Client.PawnAsk:Fire()
	end
end

function PawnShopController.Leave(_anchor: BasePart)
	closeDialog(true)
end

function PawnShopController.GetState(): { [string]: any }
	local data = offer
	return {
		Open = mode ~= "Closed",
		Mode = mode,
		Line = currentLine,
		HeldUid = if data then data.heldUid else nil,
		HeldPrice = if data then data.heldPrice else nil,
		AllCount = if data then data.allCount else nil,
		AllPrice = if data then data.allPrice else nil,
	}
end

-- Fermeture si le joueur s'éloigne de la plaque (sortie de plaque pas vue), ou si l'écran disparaît.
local function checkOpen()
	local anchor = openAt
	if anchor == nil or mode == "Closed" then
		return
	end
	local current = screen
	if current == nil or current.gui.Parent == nil or anchor.Parent == nil then
		closeDialog(false)
		return
	end
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild(ROOT_PART) else nil
	if root and root:IsA("BasePart") and ((root :: BasePart).Position - anchor.Position).Magnitude > CLOSE_DISTANCE then
		closeDialog(true)
	end
end

function PawnShopController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	net.Client.PawnOffer:Connect(onOffer)
	net.Client.PawnSold:Connect(onSold)

	localPlayer:GetAttributeChangedSignal(INVENTORY_ATTRIBUTE):Connect(ask)
	localPlayer:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(function()
		if mode ~= "Closed" then
			render()
		end
		ask()
	end)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end

	RunService.Heartbeat:Connect(checkOpen)
end

return PawnShopController
