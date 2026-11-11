--!strict
-- GainController (client, liaison L-091 point 3) : les gains qui s'affichent, puis volent vers le total.
--
-- Rôle :
--   - Entraînement : à chaque gain du tapis, « +2 Speed/s » au-dessus du joueur ; à chaque gain du
--     banc, « +X Power » (textes de L-091). Une copie de ReplicatedStorage/Assets/UI/BB_Gain de Clément
--     (Row.Amount, Row.Icon), posée sur le HumanoidRootPart, qui monte et s'efface (UiMotion.FloatGain),
--     puis détruite. Source : les attributs Speed (points d'entraînement) et Strength du Player, posés
--     par StatsService, quand ils montent pendant que l'attribut TrainingMachine vaut « Treadmill » ou
--     « Bench » (TrainingService). Gains rapprochés : un BB_Gain au plus par FloatGain.MinGap s, les
--     gains entre deux s'additionnent dans le suivant.
--   - Argent : quand l'attribut Cash du Player monte (DataService), Cash est retenu au HUD
--     (HudController.HoldCash) et le gain est classé à la fin de l'image (task.defer) :
--       * ramassage : l'attribut CashCollected du Player (DisplayService, il ne fait que monter) est
--         monté en même temps → « +$X » au-dessus du joueur (BB_Gain), et la case part de là ;
--       * récompense : l'écran UI_Rewards est ouvert (RewardsController.GetState().Open) → la case
--         part du centre de l'écran (UiMotion.CashFly.From) ;
--       * autre gain (index, camion…) : pas de case, le compteur sursaute seulement (CashBump).
--     La case est une copie de UI_HUD.CashFly.Template de Clément (Icon, FlyerAmount = « $X »), rangée
--     à la racine de UI_HUD comme dans son prototype (tools/clement/gain_proto.luau) : elle surgit,
--     attend, puis vole jusqu'au nombre Cash en rapetissant (UiMotion.CashFly). À l'arrivée : Cash est
--     relâché et défile (Motion.Roll, HudController), CashRow sursaute (Motion.Pop, CashBump), une copie
--     de CashFly.CounterPop (« +$X ») apparaît à droite du nombre, puis monte et s'efface
--     (UiMotion.CounterPop), et le son CashFly.Sound part. Gains rapprochés : tant que la case attend
--     encore au départ, un nouveau gain s'y ajoute (montant cumulé) ; une seule copie de CounterPop à
--     la fois.
-- Gains hors ligne (vague 22, L-092 3f) : au Claim de l'écran UI_Offline (OfflineController.GetState().Open,
-- vrai jusqu'au versement), la case part du centre de l'écran, comme pour une récompense, avant même le
-- cas du ramassage (CashCollected monte aussi : le versement passe par DisplayService.AddOfflineEarnings).
-- Rien n'est laissé : chaque BB_Gain, case et « +$X » est une copie détruite à la fin de son
-- animation, et les modèles de Clément (BB_Gain, Template, CounterPop) ne sont jamais modifiés. Seuls
-- leur Text, Visible, Position, Adornee, StudsOffset et transparences changent, sur les copies.
-- Couleur de Row.Amount et image de Row.Icon (vague 24) : d'abord les attributs de Clément sur le
-- modèle BB_Gain (SpeedColor, PowerColor, CashColor en Color3 ; SpeedIcon, PowerIcon, CashIcon en
-- rbxassetid). S'ils manquent : la couleur de Config/UiMotion.FloatGain.Colors, et l'image de l'icône
-- de la ligne du HUD du même chiffre (SpeedRow, StrengthRow, CashRow : la première ImageLabel de la
-- ligne), sinon celle du modèle BB_Gain.
--
-- API (client) : aucune. Pour un test dans Studio (barre de commande côté client) :
--   GainController.GetActive() -> { Gains: number, Flyers: number, Pops: number }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiMotion = require(Shared:WaitForChild("Config"):WaitForChild("UiMotion"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

-- Ce que ce contrôleur utilise de HudController et de RewardsController.
type HudApi = { HoldCash: (base: number) -> () -> () }
type RewardsApi = { GetState: () -> { Open: boolean } }

type Kind = {
	Name: string,
	Attribute: string, -- attribut du Player qui monte
	Machine: string?, -- TrainingMachine requis (nil : argent)
	HudLabel: string, -- nombre du HUD dont la ligne donne l'icône
	Text: (amount: number) -> string,
}

type Burst = { pending: number, lastAt: number, scheduled: boolean }
type Rise = { amount: number, release: (() -> ())? }
type Flyer = { object: GuiObject, amount: number, releases: { () -> () }, leaving: boolean, label: TextLabel? }
type Fade = { object: Instance, property: string, from: number }

-- Contrat (L-091, livré par Clément le 2026-11-10 ; relevé de la vague 21).
local GAIN_TEMPLATE = "BB_Gain"
local HUD_SCREEN = "UI_HUD"
local CASH_FLY = "CashFly"
local CASH_LABEL = "Cash"
local CASH_ROW = "CashRow"
-- Attributs du Player (mêmes noms dans StatsService, TrainingService et DisplayService).
local MACHINE_ATTRIBUTE = "TrainingMachine"
local COLLECTED_ATTRIBUTE = "CashCollected"

local SPEED: Kind = {
	Name = "Speed",
	Attribute = "Speed",
	Machine = "Treadmill",
	HudLabel = "Speed",
	Text = function(amount: number): string
		return `+{Format.short(amount)} Speed/s` -- L-091 : « +2 Speed/s »
	end,
}
local POWER: Kind = {
	Name = "Power",
	Attribute = "Strength",
	Machine = "Bench",
	HudLabel = "Strength",
	Text = function(amount: number): string
		return `+{Format.short(amount)} Power` -- L-091 : « +X Power »
	end,
}
local CASH: Kind = {
	Name = "Cash",
	Attribute = "Cash",
	Machine = nil,
	HudLabel = "Cash",
	Text = function(amount: number): string
		return `+{Format.money(amount)}` -- L-091 : « +$… »
	end,
}

local FLOAT = UiMotion.FloatGain
local FLY = UiMotion.CashFly
local POP = UiMotion.CounterPop
local GAIN_POP_INFO = TweenInfo.new(FLOAT.PopTime, FLOAT.PopStyle, Enum.EasingDirection.Out)
local GAIN_RISE_INFO = TweenInfo.new(FLOAT.Time, FLOAT.Style, FLOAT.Direction)
local FLY_POP_INFO = TweenInfo.new(FLY.PopTime, FLY.PopStyle, Enum.EasingDirection.Out)
local FLY_INFO = TweenInfo.new(FLY.Time, FLY.Style, FLY.Direction)
local BUMP_INFO = TweenInfo.new(UiMotion.CashBump.Time, UiMotion.CashBump.Style, UiMotion.CashBump.Direction)
local COUNTER_POP_INFO = TweenInfo.new(POP.Time, POP.Style, POP.Direction)
local COUNTER_FADE_INFO = TweenInfo.new(POP.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- V0 proposé, absent du doc : nom des UIScale posés sur les copies (détruits avec elles).
local COPY_SCALE = "GainScale"

local IS_STUDIO = RunService:IsStudio()

local GainController = {}

local localPlayer = Players.LocalPlayer
local random = Random.new()
local hud: HudApi? = nil
local rewards: RewardsApi? = nil
local offline: RewardsApi? = nil -- OfflineController : même GetState().Open
local bursts: { [Kind]: Burst } = {}
local lastValues: { [string]: number } = {}
local rises: { Rise } = {}
local collected = 0
local classifyQueued = false
local flyer: Flyer? = nil -- case qui attend encore au départ (un nouveau gain s'y ajoute)
local counterPop: GuiObject? = nil
local active = { Gains = 0, Flyers = 0, Pops = 0 }
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if IS_STUDIO and not warned[key] then
		warned[key] = true
		warn(message)
	end
end

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

local function playerGui(): PlayerGui?
	return localPlayer:FindFirstChildOfClass("PlayerGui")
end

local function hudScreen(): ScreenGui?
	local gui = playerGui()
	local screen = if gui then gui:FindFirstChild(HUD_SCREEN) else nil
	return if screen and screen:IsA("ScreenGui") then screen :: ScreenGui else nil
end

local function typed(root: Instance?, path: string, class: string): any
	if root == nil then
		return nil
	end
	local found = Find.path(root, path)
	return if found and found:IsA(class) then found else nil
end

-- Image de l'icône de la ligne du HUD qui porte le nombre `labelName` (SpeedRow/SpeedIcon…), ou nil.
local function hudIcon(labelName: string): string?
	local screen = hudScreen()
	local label = typed(screen, labelName, "TextLabel") :: TextLabel?
	local row = if label then label.Parent else nil
	if row == nil or row:IsA("ScreenGui") then
		return nil
	end
	for _, child in row:GetDescendants() do
		if child:IsA("ImageLabel") and (child :: ImageLabel).Image ~= "" then
			return (child :: ImageLabel).Image
		end
	end
	return nil
end

local function rootPart(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root :: BasePart else nil
end

------------------------------------------------------------------------------
-- Gain au-dessus du joueur (FloatGain)
------------------------------------------------------------------------------

local function floatGain(kind: Kind, amount: number)
	local root = rootPart()
	local gui = playerGui()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("UI") else nil
	local template = if folder then folder:FindFirstChild(GAIN_TEMPLATE) else nil
	if template == nil or not template:IsA("BillboardGui") then
		warnOnce("template", `[Gains] ReplicatedStorage/Assets/UI/{GAIN_TEMPLATE} absent : pas de gain au-dessus du joueur`)
		return
	end
	if root == nil or gui == nil then
		return
	end
	local billboard = (template :: BillboardGui):Clone()
	local row = typed(billboard, "Row", "GuiObject") :: GuiObject?
	local amountLabel = typed(billboard, "Amount", "TextLabel") :: TextLabel?
	local icon = typed(billboard, "Icon", "ImageLabel") :: ImageLabel?
	-- L-092 3e : un seul BB_Gain ; la copie dit sa sorte (GainKind) et Amount prend sa couleur.
	billboard:SetAttribute(FLOAT.KindAttribute, kind.Name)
	if amountLabel then
		amountLabel.Text = kind.Text(amount)
		-- Vague 24 : la couleur posée par Clément sur BB_Gain (attribut <Sorte>Color, Color3) passe
		-- avant celle de Config/UiMotion.FloatGain.Colors.
		local attributeColor = template:GetAttribute(`{kind.Name}Color`)
		local color: Color3? = if typeof(attributeColor) == "Color3"
			then attributeColor
			else (FLOAT.Colors :: { [string]: Color3 })[kind.Name]
		if color then
			amountLabel.TextColor3 = color
		end
	end
	-- Vague 24 : l'icône posée par Clément sur BB_Gain (attribut <Sorte>Icon, rbxassetid) passe avant
	-- celle de la ligne du HUD.
	local attributeIcon = template:GetAttribute(`{kind.Name}Icon`)
	local image: string? = if type(attributeIcon) == "string" and attributeIcon ~= ""
		then attributeIcon
		else hudIcon(kind.HudLabel)
	if icon and image then
		icon.Image = image
	end
	local base = billboard.StudsOffset
	if base.Magnitude < 1e-3 then
		base = Vector3.new(0, FLOAT.Height, 0)
	end
	local spread = (random:NextNumber() * 2 - 1) * FLOAT.SpreadX
	billboard.Adornee = root
	billboard.StudsOffset = base + Vector3.new(spread, 0, 0)

	-- Ce qui s'efface : le texte, l'icône et leurs contours, depuis leur transparence d'origine.
	local fades: { Fade } = {}
	if amountLabel then
		table.insert(fades, { object = amountLabel :: Instance, property = "TextTransparency", from = amountLabel.TextTransparency })
	end
	if icon then
		table.insert(fades, { object = icon :: Instance, property = "ImageTransparency", from = icon.ImageTransparency })
	end
	for _, descendant in billboard:GetDescendants() do
		if descendant:IsA("UIStroke") then
			table.insert(fades, { object = descendant :: Instance, property = "Transparency", from = (descendant :: UIStroke).Transparency })
		end
	end

	billboard.Parent = gui
	active.Gains += 1
	if row then
		local scale = Instance.new("UIScale")
		scale.Name = COPY_SCALE
		scale.Scale = FLOAT.PopFrom
		scale.Parent = row
		TweenService:Create(scale, GAIN_POP_INFO, { Scale = 1 }):Play()
	end
	local progress = Instance.new("NumberValue")
	progress.Value = 0
	progress:GetPropertyChangedSignal("Value"):Connect(function()
		local a = progress.Value
		billboard.StudsOffset = base + Vector3.new(spread, FLOAT.Rise * a, 0)
		local fade = math.clamp((a - FLOAT.FadeAt) / (1 - FLOAT.FadeAt), 0, 1)
		for _, item in fades do
			(item.object :: any)[item.property] = item.from + (1 - item.from) * fade
		end
	end)
	local rise = TweenService:Create(progress, GAIN_RISE_INFO, { Value = 1 })
	rise.Completed:Connect(function()
		active.Gains -= 1
		billboard:Destroy()
		progress:Destroy()
	end)
	rise:Play()
end

-- Un BB_Gain au plus par FloatGain.MinGap s et par sorte : les gains entre deux s'additionnent.
local function showGain(kind: Kind, amount: number)
	local burst = bursts[kind]
	if burst == nil then
		burst = { pending = 0, lastAt = -math.huge, scheduled = false }
		bursts[kind] = burst
	end
	local current: Burst = burst
	current.pending += amount
	if current.scheduled then
		return
	end
	local function flush()
		current.scheduled = false
		local total = current.pending
		current.pending = 0
		current.lastAt = os.clock()
		if total > 0 then
			floatGain(kind, total)
		end
	end
	local wait = current.lastAt + (if kind == CASH then FLOAT.CashMinGap else FLOAT.MinGap) - os.clock()
	if wait <= 0 then
		flush()
	else
		current.scheduled = true
		task.delay(wait, flush)
	end
end

------------------------------------------------------------------------------
-- Case qui vole vers l'argent (CashFly, CashBump, CounterPop)
------------------------------------------------------------------------------

type HudRefs = { screen: ScreenGui, label: TextLabel, row: GuiObject, fly: Instance? }

local function hudRefs(): HudRefs?
	local screen = hudScreen()
	local label = typed(screen, CASH_LABEL, "TextLabel") :: TextLabel?
	if screen == nil or label == nil then
		return nil
	end
	local row: GuiObject = label
	local ancestor = label:FindFirstAncestor(CASH_ROW)
	if ancestor and ancestor:IsA("GuiObject") then
		row = ancestor :: GuiObject
	end
	return { screen = screen, label = label, row = row, fly = Find.path(screen, CASH_FLY) }
end

local function bump(refs: HudRefs?)
	if refs then
		Motion.Pop(refs.row, UiMotion.CashBump.From, BUMP_INFO)
	end
end

local function releaseAll(releases: { () -> () })
	for _, release in releases do
		release()
	end
end

-- « +$X » à droite du nombre Cash : une copie de CashFly.CounterPop (une seule à la fois).
local function showCounterPop(refs: HudRefs, amount: number)
	local template = typed(refs.fly, "CounterPop", "TextLabel") :: TextLabel?
	if template == nil then
		return
	end
	local previous = counterPop
	if previous then
		counterPop = nil
		active.Pops -= 1
		previous:Destroy()
	end
	local pop = template:Clone()
	pop.Text = CASH.Text(amount)
	pop.Visible = true
	local label = refs.label
	local origin = refs.screen.AbsolutePosition
	pop.Position = UDim2.fromOffset(
		label.AbsolutePosition.X - origin.X + label.TextBounds.X + POP.OffsetX,
		label.AbsolutePosition.Y - origin.Y + label.AbsoluteSize.Y / 2
	)
	local scale = Instance.new("UIScale")
	scale.Name = COPY_SCALE
	scale.Scale = POP.From
	scale.Parent = pop
	pop.Parent = refs.screen
	counterPop = pop
	active.Pops += 1
	TweenService:Create(scale, COUNTER_POP_INFO, { Scale = 1 }):Play()
	task.delay(POP.Time + POP.Hold, function()
		if counterPop ~= pop then
			return -- remplacée entre-temps
		end
		local fade = TweenService:Create(pop, COUNTER_FADE_INFO, {
			TextTransparency = 1,
			Position = pop.Position - UDim2.fromOffset(0, POP.Rise),
		})
		for _, descendant in pop:GetDescendants() do
			if descendant:IsA("UIStroke") then
				TweenService:Create(descendant, COUNTER_FADE_INFO, { Transparency = 1 }):Play()
			end
		end
		fade.Completed:Connect(function()
			if counterPop == pop then
				counterPop = nil
				active.Pops -= 1
			end
			pop:Destroy()
		end)
		fade:Play()
	end)
end

local function arrive(amount: number, releases: { () -> () })
	releaseAll(releases) -- Cash défile (HudController)
	local refs = hudRefs()
	if refs == nil then
		return
	end
	bump(refs)
	showCounterPop(refs, amount)
	Motion.PlaySound(FLY.Sound)
end

-- Point de départ (pixels, repère de UI_HUD) : au-dessus du joueur, ou nil s'il n'est pas à l'écran.
local function worldStart(refs: HudRefs): Vector2?
	local root = rootPart()
	local camera = Workspace.CurrentCamera
	if root == nil or camera == nil then
		return nil
	end
	local point = root.Position + Vector3.new(0, FLOAT.Height, 0)
	local screenPoint, onScreen
	if refs.screen.IgnoreGuiInset then
		screenPoint, onScreen = camera:WorldToViewportPoint(point)
	else
		screenPoint, onScreen = camera:WorldToScreenPoint(point)
	end
	if not onScreen then
		return nil
	end
	local origin = refs.screen.AbsolutePosition
	return Vector2.new(screenPoint.X - origin.X, screenPoint.Y - origin.Y)
end

local function fly(amount: number, releases: { () -> () }, fromPlayer: boolean)
	local waiting = flyer
	if waiting and not waiting.leaving and waiting.object.Parent ~= nil then
		-- Gain rapproché : il s'ajoute à la case qui attend encore. Sa retenue tombe : celle de la
		-- case (la plus ancienne) garde l'argent d'avant les deux gains jusqu'à l'arrivée.
		waiting.amount += amount
		if waiting.label then
			waiting.label.Text = Format.money(waiting.amount)
		end
		releaseAll(releases)
		return
	end
	local refs = hudRefs()
	local template = if refs then typed(refs.fly, "Template", "GuiObject") :: GuiObject? else nil
	if refs == nil or template == nil then
		warnOnce("flyer", `[Gains] UI_HUD.{CASH_FLY}.Template absent : l'argent défile sans case qui vole`)
		releaseAll(releases)
		bump(refs)
		return
	end
	local copy = template:Clone()
	local label = typed(copy, "FlyerAmount", "TextLabel") :: TextLabel?
	if label then
		label.Text = Format.money(amount)
	end
	local start = if fromPlayer then worldStart(refs) else nil
	copy.Position = if start then UDim2.fromOffset(start.X, start.Y) else UDim2.fromScale(FLY.From.X, FLY.From.Y)
	copy.Visible = true
	local scale = Instance.new("UIScale")
	scale.Name = COPY_SCALE
	scale.Scale = 0
	scale.Parent = copy
	copy.Parent = refs.screen
	local current: Flyer = { object = copy, amount = amount, releases = table.clone(releases), leaving = false, label = label }
	flyer = current
	active.Flyers += 1
	TweenService:Create(scale, FLY_POP_INFO, { Scale = FLY.PopTo }):Play()
	task.delay(FLY.PopTime + FLY.Hold, function()
		current.leaving = true
		if flyer == current then
			flyer = nil
		end
		local now = hudRefs()
		if now == nil or copy.Parent == nil then
			active.Flyers -= 1
			copy:Destroy()
			arrive(current.amount, current.releases)
			return
		end
		local target = now.label
		local origin = now.screen.AbsolutePosition
		local goal = UDim2.fromOffset(
			target.AbsolutePosition.X - origin.X + FLY.TargetOffsetX,
			target.AbsolutePosition.Y - origin.Y + target.AbsoluteSize.Y / 2
		)
		local move = TweenService:Create(copy, FLY_INFO, { Position = goal })
		TweenService:Create(scale, FLY_INFO, { Scale = FLY.EndScale }):Play()
		move.Completed:Connect(function()
			active.Flyers -= 1
			copy:Destroy()
			arrive(current.amount, current.releases)
		end)
		move:Play()
	end)
end

------------------------------------------------------------------------------
-- Sources des gains
------------------------------------------------------------------------------

-- L'écran de `api` (RewardsController, OfflineController) est ouvert.
local function screenOpen(api: RewardsApi?): boolean
	if api == nil then
		return false
	end
	local ok, state = pcall(api.GetState)
	return ok and type(state) == "table" and state.Open == true
end

-- Fin d'image : les montées de Cash de l'image sont classées ensemble (voir l'en-tête).
local function classify()
	classifyQueued = false
	local list = rises
	rises = {}
	local fromPad = collected > 0
	collected = 0
	if #list == 0 then
		return
	end
	local total = 0
	local releases: { () -> () } = {}
	for _, rise in list do
		total += rise.amount
		if rise.release then
			table.insert(releases, rise.release)
		end
	end
	if not FLY.Enabled then
		-- Sans case qui vole (L-091, retour de Clément) : l'argent défile tout de suite, le compteur sursaute,
		-- et un ramassage, des gains hors ligne réclamés ou une récompense montrent « +$X » au-dessus du joueur.
		releaseAll(releases)
		bump(hudRefs())
		if fromPad or screenOpen(offline) or screenOpen(rewards) then
			showGain(CASH, total)
		end
		return
	end
	if screenOpen(offline) then
		fly(total, releases, false) -- gains hors ligne réclamés : du centre de l'écran
	elseif fromPad then
		showGain(CASH, total)
		fly(total, releases, true)
	elseif screenOpen(rewards) then
		fly(total, releases, false)
	else
		releaseAll(releases)
		bump(hudRefs())
	end
end

local function queueClassify()
	if not classifyQueued then
		classifyQueued = true
		task.defer(classify)
	end
end

-- Hausse d'un attribut numérique du Player depuis la dernière valeur vue (0 au premier passage).
local function riseOf(attribute: string): (number, number?)
	local value = localPlayer:GetAttribute(attribute)
	local previous = lastValues[attribute]
	if type(value) ~= "number" or value ~= value then
		lastValues[attribute] = nil
		return 0, nil
	end
	lastValues[attribute] = value
	if previous == nil or value <= previous then
		return 0, previous
	end
	return value - previous, previous
end

local function onTraining(kind: Kind)
	local amount = riseOf(kind.Attribute)
	if amount > 0 and localPlayer:GetAttribute(MACHINE_ATTRIBUTE) == kind.Machine then
		showGain(kind, amount)
	end
end

local function onCash()
	local amount, previous = riseOf(CASH.Attribute)
	if amount <= 0 or previous == nil then
		return
	end
	-- Retenu tout de suite (avant que le HUD ne fasse défiler la hausse), relâché à l'arrivée.
	local api = hud
	local release: (() -> ())? = nil
	if api then
		local ok, result = pcall(api.HoldCash, previous)
		if ok and type(result) == "function" then
			release = result
		end
	end
	table.insert(rises, { amount = amount, release = release })
	queueClassify()
end

local function onCollected()
	local amount = riseOf(COLLECTED_ATTRIBUTE)
	if amount > 0 then
		collected += amount
		queueClassify()
	end
end

function GainController.GetActive(): { Gains: number, Flyers: number, Pops: number }
	return table.clone(active)
end

function GainController.Start()
	hud = sibling("HudController")
	rewards = sibling("RewardsController")
	offline = sibling("OfflineController")
	for _, kind in { SPEED, POWER } do
		riseOf(kind.Attribute)
		localPlayer:GetAttributeChangedSignal(kind.Attribute):Connect(function()
			onTraining(kind)
		end)
	end
	riseOf(CASH.Attribute)
	riseOf(COLLECTED_ATTRIBUTE)
	localPlayer:GetAttributeChangedSignal(CASH.Attribute):Connect(onCash)
	localPlayer:GetAttributeChangedSignal(COLLECTED_ATTRIBUTE):Connect(onCollected)
end

return GainController
