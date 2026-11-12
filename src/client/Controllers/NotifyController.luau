--!strict
-- NotifyController (client) : affiche les messages `Notify` du serveur (Net/Definitions :
-- Notify(message, kind?), kind = "Info", "Warning" (refus : son UI_Deny), "Alert" (avertissement sans
-- son, même allure que Warning) ou une autre catégorie libre).
--
-- Écran, dans cet ordre :
--   - `UI_Toast` de Clément (L-095 point 3 ; note docs/claude/notes/ui-feel2-horsligne-poursuite-barre.md) :
--     une copie de `Stack.Template` (TextLabel caché) par message, rangée à côté de lui (LayoutOrder =
--     ordre d'arrivée) : Text = le message, TextColor3 = UiMotion.Toast.Colors[kind] (« Success » en
--     vert 5DFF3A), sinon Toast.Other (blanc). Elle entre de Toast.From à 1 (Motion.Pop, Back Out),
--     reste Toast.Hold s, puis son texte et ses UIStroke s'effacent en Toast.FadeTime et elle est
--     détruite ; poussée dehors par un 4e message : détruite tout de suite (prototype feel2_proto.luau).
--     Seuls Enabled de l'écran, et Name, LayoutOrder, Text, TextColor3, Visible et la transparence
--     (avant destruction) des copies sont touchés ;
--   - sinon (repli) `UI_Notify` (contrat UI 2.2 : un `Template` caché avec `Icon` et `Label`) :
--   - écran de Clément livré (PlayerGui/UI_Notify, copié depuis StarterGui) : une copie de son Template
--     par message, rangée à côté de lui, Label = le message, montrée par Controllers/UI/Motion (Show),
--     retirée au bout de DURATION s (Hide, puis détruite). L'écran est allumé au premier message.
--     Seuls Enabled de l'écran, et Visible, LayoutOrder (ordre d'arrivée) et le texte de Label des
--     copies sont touchés (2.2, « Libre pour Ironix ») ; Icon reste tel que Clément l'a fait ;
--   - pas encore livré (ou livré sans Template) : un bandeau de secours fait par le code, NotifyV0
--     dans le PlayerGui, clairement provisoire. Les bandeaux s'empilent en bas au centre, au-dessus de
--     la barre d'outils (rien d'important en haut de l'écran, 2.2), STACK_BOTTOM de la hauteur. Chacun :
--     une pastille ronde à gauche (« ! » orange pour Warning, « ! » or pour Announce, « i » bleu
--     sinon), entière dans le bandeau avec une
--     marge de ICON_PAD px, puis le texte, ICON_GAP px après la pastille, aligné à gauche et réduit au
--     besoin pour tenir (deux lignes au plus sur téléphone). Bandeau de 48 px de haut, au plus 560 px
--     de large. Le repli est détruit dès que UI_Notify arrive.
-- Au plus MAX_SHOWN messages à la fois (le plus ancien part). Le même message encore affiché ne se
-- répète pas : il reste DURATION s de plus et son texte finit par « ×2 », « ×3 »…, après une espace.
-- Une nouvelle copie de l'écran (ResetOnSpawn) : les messages en cours restent sur l'ancienne, qui
-- disparaît avec eux ; les suivants vont sur la nouvelle. En Studio, chaque message est aussi écrit
-- dans la sortie.
--
-- API (client) :
--   NotifyController.OnNotify(fn(message, kind?)) -> déconnexion
--   NotifyController.Show(message, kind?)
--       Un message du client lui-même, montré comme un Notify du serveur (OfflineController : « Soon »).
--   NotifyController.GetShown() -> { { Message, Kind, Count, Text, Fallback, Toast, Color } }
--       Messages affichés, du plus ancien au plus récent, pour un test dans Studio (barre de commande
--       côté client).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local UiMotion = require(Shared:WaitForChild("Config"):WaitForChild("UiMotion"))

type Listener = (message: string, kind: string?) -> ()

-- Ce que ce contrôleur utilise de Controllers/UI/Motion (a37).
type MotionApi = {
	Show: (object: GuiObject) -> (),
	Hide: (object: GuiObject, after: (() -> ())?) -> (),
	Pop: ((object: GuiObject, from: number, info: TweenInfo) -> ())?,
	PlaySound: ((name: string) -> ())?,
}

type Entry = {
	Message: string,
	Kind: string?,
	Count: number,
	Object: GuiObject, -- copie du Template, ou bandeau de secours
	Label: TextLabel?,
	ExpiresAt: number, -- os.clock()
	Fallback: boolean,
	Toast: boolean, -- copie de UI_Toast.Stack.Template
}

export type ShownInfo = {
	Message: string,
	Kind: string?,
	Count: number,
	Text: string?,
	Fallback: boolean,
	Toast: boolean,
	Color: Color3?, -- TextColor3 d'un message de UI_Toast
}

-- Messages du bas de Clément (L-095 point 3) : `UI_Toast`, et dedans `Stack.Template` (TextLabel).
local TOAST_SCREEN = "UI_Toast"
local TOAST_TEMPLATE = "Stack.Template"
local TOAST = UiMotion.Toast
local TOAST_INFO = TweenInfo.new(TOAST.Time, TOAST.Style, TOAST.Direction)
local FADE_INFO = TweenInfo.new(TOAST.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Écran de Clément et ses éléments (contrat 2.2).
local SCREEN_NAME = "UI_Notify"
local TEMPLATE = "Template"
local PREVIEW_PREFIX = "Preview_" -- cartes d'exemple de Clément, à côté du Template
local LABEL = "Label"

-- s : durée d'affichage d'un message (relancée par une répétition) ; Toast.Hold du tableau de
-- Clément, 2,4 s (L-092 3d).
local DURATION: number = UiMotion.Toast.Hold
local MAX_SHOWN: number = TOAST.MaxShown -- tableau de Clément : 3 messages au plus
-- V0 proposés, absents du doc :
local COUNT_TEXT = "%s ×%d" -- même message répété : « … ×2 »
local FALLBACK_NAME = "NotifyV0"
local DISPLAY_ORDER = 15 -- au-dessus du HUD, sous l'alerte de vol (20)
local STACK_BOTTOM = 0.8 -- bas de la pile, en part de la hauteur de l'écran (barre d'outils dessous)
local STACK_WIDTH = 0.9 -- largeur de la pile, en part de la largeur de l'écran
local STACK_GAP = 6 -- px entre deux bandeaux
local TOAST_HEIGHT = 48 -- px (au moins 44 sur téléphone)
local TOAST_MAX_WIDTH = 560 -- px
local ICON_SIZE = 32 -- px, pastille ronde
local ICON_PAD = 10 -- px entre le bord gauche du bandeau et la pastille
local ICON_GAP = 12 -- px entre la pastille et le texte
local TEXT_PAD = 14 -- px entre le texte et le bord droit
local TEXT_MAX = 20 -- px : taille du texte au plus (réduit pour tenir)
local TEXT_MIN = 11 -- px : taille du texte au moins
local BACKGROUND = Color3.fromHex("#1B1B24") -- contour de la planche 10.6
local BACKGROUND_TRANSPARENCY = 0.12
local TEXT_COLOR = Color3.new(1, 1, 1)
local ICON_COLORS: { [string]: Color3 } = {
	Warning = Color3.fromHex("#FF8C1A"), -- orange « améliorations » (10.6)
	Info = Color3.fromHex("#2F9BFF"), -- bleu du Rare (10.6)
	Announce = Color3.fromHex("#FFC21A"), -- or du Légendaire (10.6) : annonce d'une ouverture rare (Config/Unbox)
	Alert = Color3.fromHex("#FF8C1A"), -- avertissement sans refus (L-106 point 6) : comme Warning
}
local ICON_GLYPHS: { [string]: string } = { Warning = "!", Info = "i", Announce = "!", Alert = "!" }

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local NotifyController = {}

local listeners: { Listener } = {}
local entries: { Entry } = {} -- du plus ancien au plus récent
local fallback: ScreenGui? = nil
local stack: Frame? = nil -- pile du repli
local order = 0
local motion: MotionApi? = nil
local motionSearched = false
local noticed: { [string]: boolean } = {}

local function once(key: string, message: string, isProblem: boolean?)
	if not IS_STUDIO or noticed[key] then
		return
	end
	noticed[key] = true
	if isProblem then
		warn(`[NotifyController] {message}`)
	else
		print(`[NotifyController] {message}`)
	end
end

-- Controllers/UI/Motion, s'il est là ; sinon nil (les messages apparaissent d'un coup).
local function motionApi(): MotionApi?
	if motionSearched then
		return motion
	end
	motionSearched = true
	local folder = script.Parent:FindFirstChild("UI")
	local module = if folder then folder:FindFirstChild("Motion") else nil
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			motion = result :: any
		end
	end
	return motion
end

local function textFor(entry: Entry): string
	return if entry.Count > 1 then string.format(COUNT_TEXT, entry.Message, entry.Count) else entry.Message
end

local function refreshText(entry: Entry)
	local label = entry.Label
	if label then
		label.Text = textFor(entry)
	end
end

------------------------------------------------------------------------------
-- Repli V0
------------------------------------------------------------------------------

local function destroyFallback()
	local gui = fallback
	fallback, stack = nil, nil
	if gui then
		gui:Destroy()
	end
	for index = #entries, 1, -1 do
		if entries[index].Fallback then
			table.remove(entries, index)
		end
	end
end

local function fallbackStack(playerGui: Instance): Frame
	local current = stack
	if fallback and fallback.Parent == playerGui and current then
		return current
	end
	destroyFallback()
	local screen = Instance.new("ScreenGui")
	screen.Name = FALLBACK_NAME
	screen.ResetOnSpawn = false
	screen.DisplayOrder = DISPLAY_ORDER

	local frame = Instance.new("Frame")
	frame.Name = "Stack"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, STACK_BOTTOM)
	frame.Size = UDim2.fromScale(STACK_WIDTH, 0.5)
	frame.BackgroundTransparency = 1
	frame.Active = false
	frame.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, STACK_GAP)
	layout.Parent = frame

	screen.Parent = playerGui
	fallback, stack = screen, frame
	return frame
end

local function corner(parent: Instance, radius: UDim)
	local round = Instance.new("UICorner")
	round.CornerRadius = radius
	round.Parent = parent
end

-- Un bandeau du repli (voir l'en-tête) : pastille entière à gauche, texte après elle.
local function makeToast(parent: Frame, kind: string?): (Frame, TextLabel)
	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(1, 0, 0, TOAST_HEIGHT)
	toast.BackgroundColor3 = BACKGROUND
	toast.BackgroundTransparency = BACKGROUND_TRANSPARENCY
	toast.BorderSizePixel = 0
	toast.Active = false
	toast.Visible = false
	corner(toast, UDim.new(0, 10))
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(TOAST_MAX_WIDTH, TOAST_HEIGHT)
	limit.MinSize = Vector2.new(0, TOAST_HEIGHT)
	limit.Parent = toast

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, ICON_PAD, 0.5, 0)
	icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	icon.BackgroundColor3 = ICON_COLORS[kind or ""] or ICON_COLORS.Info
	icon.BorderSizePixel = 0
	corner(icon, UDim.new(1, 0))
	icon.Parent = toast
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.BackgroundTransparency = 1
	glyph.Font = Enum.Font.GothamBlack
	glyph.TextScaled = true
	glyph.TextColor3 = TEXT_COLOR
	glyph.Text = ICON_GLYPHS[kind or ""] or ICON_GLYPHS.Info
	local glyphPad = Instance.new("UIPadding")
	glyphPad.PaddingTop = UDim.new(0.18, 0)
	glyphPad.PaddingBottom = UDim.new(0.18, 0)
	glyphPad.Parent = glyph
	glyph.Parent = icon

	local textLeft = ICON_PAD + ICON_SIZE + ICON_GAP
	local label = Instance.new("TextLabel")
	label.Name = LABEL
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, textLeft, 0.5, 0)
	label.Size = UDim2.new(1, -(textLeft + TEXT_PAD), 1, -8)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = TEXT_COLOR
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.TextScaled = true
	label.Text = ""
	local textSize = Instance.new("UITextSizeConstraint")
	textSize.MaxTextSize = TEXT_MAX
	textSize.MinTextSize = TEXT_MIN
	textSize.Parent = label
	label.Parent = toast

	toast.Parent = parent
	return toast, label
end

------------------------------------------------------------------------------
-- Affichage
------------------------------------------------------------------------------

-- Template de l'écran de Clément, ou nil (pas livré, ou sans Template : le repli s'affiche).
local function clementTemplate(playerGui: Instance): (ScreenGui?, GuiObject?)
	local screen = playerGui:FindFirstChild(SCREEN_NAME)
	if screen == nil or not screen:IsA("ScreenGui") then
		return nil, nil
	end
	local template = Find.path(screen, TEMPLATE)
	if template and template:IsA("GuiObject") then
		-- Cartes d'exemple de Clément (Preview_1, Preview_2…) : retirées de la copie du joueur, comme
		-- dans les autres écrans. Vu en Play le 2026-11-08 : elles restaient affichées pour toujours.
		local parent = template.Parent
		if parent then
			for _, child in parent:GetChildren() do
				if string.sub(child.Name, 1, #PREVIEW_PREFIX) == PREVIEW_PREFIX then
					child:Destroy()
				end
			end
		end
		return screen :: ScreenGui, template :: GuiObject
	end
	once("template", `{SCREEN_NAME} sans {TEMPLATE} (contrat 2.2) : messages dans le bandeau de secours`, true)
	return nil, nil
end

-- UI_Toast de Clément et son Stack.Template, ou nil (pas livré, ou sans Template TextLabel : repli).
local function toastTemplate(playerGui: Instance): (ScreenGui?, TextLabel?)
	local screen = playerGui:FindFirstChild(TOAST_SCREEN)
	if screen == nil or not screen:IsA("ScreenGui") then
		return nil, nil
	end
	local template = Find.path(screen, TOAST_TEMPLATE)
	if template and template:IsA("TextLabel") then
		return screen :: ScreenGui, template :: TextLabel
	end
	once("toastTemplate", `{TOAST_SCREEN} sans {TOAST_TEMPLATE} (TextLabel, L-095) : messages dans {SCREEN_NAME}`, true)
	return nil, nil
end

local function toastColor(kind: string?): Color3
	local color = if kind then TOAST.Colors[kind] else nil
	return color or TOAST.Other
end

-- Message de UI_Toast qui s'en va : le texte et ses contours s'effacent, puis la copie est détruite ;
-- `now` (poussé dehors par un message de plus) : détruite tout de suite.
local function fadeToast(object: GuiObject, now: boolean)
	if now or TOAST.FadeTime <= 0 then
		object:Destroy()
		return
	end
	if object:IsA("TextLabel") then
		TweenService:Create(object, FADE_INFO, { TextTransparency = 1 }):Play()
	end
	for _, descendant in object:GetDescendants() do
		if descendant:IsA("UIStroke") then
			TweenService:Create(descendant, FADE_INFO, { Transparency = 1 }):Play()
		end
	end
	task.delay(TOAST.FadeTime, function()
		object:Destroy()
	end)
end

local function removeEntry(entry: Entry, now: boolean?)
	local index = table.find(entries, entry)
	if index then
		table.remove(entries, index)
	end
	local object = entry.Object
	if object.Parent == nil then
		return
	end
	if entry.Toast then
		fadeToast(object, now == true)
		return
	end
	local api = motionApi()
	if api and object.Visible then
		api.Hide(object, function()
			object:Destroy()
		end)
	else
		object:Destroy()
	end
end

local function show(object: GuiObject)
	local api = motionApi()
	if api then
		api.Show(object)
	else
		object.Visible = true
	end
end

local function display(message: string, kind: string?)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	-- Le même message encore affiché : compté, pas répété.
	for _, entry in entries do
		if entry.Message == message and entry.Object.Parent ~= nil then
			entry.Count += 1
			entry.ExpiresAt = os.clock() + DURATION
			refreshText(entry)
			return
		end
	end
	while #entries >= MAX_SHOWN do
		removeEntry(entries[1], true)
	end
	order += 1
	local toastScreen, toastLabel = toastTemplate(playerGui)
	if toastScreen and toastLabel then
		destroyFallback()
		local copy = toastLabel:Clone()
		copy.Name = `Toast_{order}`
		copy.LayoutOrder = order
		copy.TextColor3 = toastColor(kind)
		copy.Visible = true
		local entry: Entry = {
			Message = message,
			Kind = kind,
			Count = 1,
			Object = copy,
			Label = copy,
			ExpiresAt = os.clock() + DURATION,
			Fallback = false,
			Toast = true,
		}
		refreshText(entry)
		copy.Parent = toastLabel.Parent
		if not toastScreen.Enabled then
			toastScreen.Enabled = true
		end
		table.insert(entries, entry)
		local api = motionApi()
		local pop = if api then api.Pop else nil
		if pop then
			pop(copy, TOAST.From, TOAST_INFO) -- 0,6 → 1, Back Out (UIScale passager de Motion)
		end
		once("toast", `messages dans l'écran {TOAST_SCREEN} de Clément`)
		return
	end
	local screen, template = clementTemplate(playerGui)
	local object: GuiObject
	local label: TextLabel?
	local isFallback = screen == nil
	if screen and template then
		destroyFallback()
		local copy = template:Clone()
		copy.Name = `{TEMPLATE}_{order}`
		copy.LayoutOrder = order
		copy.Visible = false
		local found = Find.path(copy, LABEL)
		label = if found and found:IsA("TextLabel") then found :: TextLabel else nil
		if label == nil then
			once("label", `{SCREEN_NAME}.{TEMPLATE}.{LABEL} introuvable ou pas un TextLabel : message sans texte`, true)
		end
		copy.Parent = template.Parent
		object = copy
		if not screen.Enabled then
			screen.Enabled = true
		end
		once("screen", `messages dans l'écran {SCREEN_NAME} de Clément`)
	else
		local toast, toastLabel = makeToast(fallbackStack(playerGui), kind)
		toast.LayoutOrder = order
		object, label = toast, toastLabel
		once("fallback", `{SCREEN_NAME} pas encore livré : messages dans le bandeau de secours`)
	end
	local entry: Entry = {
		Message = message,
		Kind = kind,
		Count = 1,
		Object = object,
		Label = label,
		ExpiresAt = os.clock() + DURATION,
		Fallback = isFallback,
		Toast = false,
	}
	refreshText(entry)
	table.insert(entries, entry)
	show(object)
end

local function step()
	local now = os.clock()
	for index = #entries, 1, -1 do
		local entry = entries[index]
		if entry.Object.Parent == nil then
			table.remove(entries, index) -- écran recréé (ResetOnSpawn) ou retiré
		elseif now >= entry.ExpiresAt then
			removeEntry(entry)
		end
	end
	-- L'écran de Clément arrive : le repli part.
	if fallback then
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui and (toastTemplate(playerGui) or clementTemplate(playerGui)) then
			destroyFallback()
		end
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function NotifyController.OnNotify(listener: Listener): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function NotifyController.Show(message: string, kind: string?)
	if IS_STUDIO then
		print(`[Notify{if kind then " " .. kind else ""}] {message}`)
	end
	xpcall(display, function(err: any)
		once(`error:{err}`, tostring(err), true)
	end, message, kind)
	-- Vague 26 (L-097 point 8) : un message « Warning » (action refusée, argent qui manque…) joue UI_Deny.
	-- L-106 point 6 : seulement les refus ; les avertissements (« Alert ») s'affichent sans son.
	if kind == UiMotion.Sounds.DenyKind then
		local api = motionApi()
		local play = if api then api.PlaySound else nil
		if play then
			play(UiMotion.Sounds.Deny)
		end
	end
	for _, listener in table.clone(listeners) do
		task.spawn(listener, message, kind)
	end
end

function NotifyController.GetShown(): { ShownInfo }
	local list: { ShownInfo } = {}
	for _, entry in entries do
		local label = entry.Label
		table.insert(list, {
			Message = entry.Message,
			Kind = entry.Kind,
			Count = entry.Count,
			Text = if label then label.Text else nil,
			Fallback = entry.Fallback,
			Toast = entry.Toast,
			Color = if entry.Toast and label then label.TextColor3 else nil,
		})
	end
	return list
end

function NotifyController.Start()
	local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any

	RunService.Heartbeat:Connect(function()
		xpcall(step, function(err: any)
			once(`error:{err}`, tostring(err), true)
		end)
	end)
	Net.Client.Notify:Connect(NotifyController.Show)
end

return NotifyController
