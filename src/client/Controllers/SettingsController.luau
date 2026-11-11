--!strict
-- SettingsController (L-095 point 2, client) : les réglages du joueur, écran UI_Settings de Clément
-- (docs/claude/notes/ui-settings.md), valeurs dans Config/Settings, sauvegarde par SettingsService.
--
-- Rôle :
--   - Réglages en vigueur : attributs du Player MusicVolume, SfxVolume, VfxEnabled et ClickSound, posés
--     par le serveur au chargement du profil (SettingsService), puis par ce contrôleur dès que le joueur
--     les change (aussitôt, sans attendre le serveur). Absents ou invalides : Settings.Default.
--       * MusicVolume : lu par MusicController (Config/Music.VolumeAttribute), qui suit en direct ;
--       * SfxVolume : Volume du SoundGroup Settings.SfxGroup créé ici dans SoundService. Tout Sound qui
--         arrive dans SoundService ou dans Workspace (sons d'UI de Motion et de MarkerSounds, sons des
--         marqueurs, de la casse, du camion, de l'alerte, des pas…) y est rangé à l'exécution, sauf la
--         musique (nom en MUS_) et un son déjà rangé dans un autre groupe par Clément. Les objets Sound
--         de Clément dans Studio ne changent pas : seules leurs copies du jeu sont rangées ;
--       * VfxEnabled : lu par ShatterController (casse en version allégée), CosmeticController (auras à
--         moitié), DamageNumberController (seulement ses propres chiffres) et DisplayController (gerbe
--         d'argent réduite), par Settings.VfxReduced ;
--       * ClickSound : le son joué à chaque clic d'un bouton des écrans UI_* (Activated), objet Sound
--         Assets/Sounds/UI/Clicks/UI_Click_<Id> de Clément, joué en 2D par MarkerSounds (donc dans le
--         groupe SFX). Laissés de côté : le Template caché d'une liste (ses copies, elles, sont
--         branchées), et PrevButton / NextButton de ClickRow, qui jouent eux-mêmes le nouveau son.
--   - UI_HUD.SettingsButton (caché dans Studio) : montré par le code si Features.Settings ; il ouvre
--     UI_Settings (un 2e appui le ferme), Root.Window.CloseButton le ferme. Ouverture et fermeture par
--     UI/Motion (groupe ScreenGroup « Menu », Motion.SetCloser), comme les autres menus.
--   - MusicRow et SoundRow : Slider.Track (clic sur la barre) et Slider.Knob (bouton rond qu'on glisse,
--     souris ou doigt, UserInputService) règlent le volume de 0 à 1 ; Track.Fill prend la largeur de la
--     valeur (seule la largeur en Scale change), Knob se place à la valeur (seul Position.X.Scale
--     change), ValueLabel « 80% ». Pendant le glisser, le bouton rond grossit (KnobGrab, T.47) par un
--     UIScale Settings.Motion.KnobGrab.ScaleName posé à 1 à la liaison (Motion.Button ne le met donc
--     pas à l'échelle au survol) ; aucun UIScale si Clément en a déjà posé un.
--   - VfxRow.Toggle : bascule VfxEnabled. OnFill ou OffFill visible, ToggleLabel « ON » / « OFF »,
--     ToggleKnob glisse d'un bout à l'autre (ToggleSlide, T.48). Les deux places de ToggleKnob et de
--     ToggleLabel sont celles de Clément (relevées à la liaison, état montré par OnFill) et leur
--     symétrique (AnchorPoint.X et Position.X.Scale renversés).
--   - ClickRow : PrevButton et NextButton parcourent Settings.Clicks (en boucle), ChoiceLabel montre le
--     nom (« CLASSIC ») ; le nouveau son est joué tout de suite.
--   - Sauvegarde : Settings.SaveDelay s après le dernier changement, un seul SaveSettings(music, sfx,
--     vfx, click) part au serveur (un glisser ou plusieurs clics = un envoi).
-- Ce qui est touché dans l'écran de Clément, et rien d'autre : Enabled, les textes, Visible de OnFill /
-- OffFill et de SettingsButton, la largeur de Fill, Position de Knob, Position et AnchorPoint de
-- ToggleKnob et ToggleLabel, le UIScale KnobScale. Écran recréé (ResetOnSpawn) : rebranché, fermé.
--
-- API (client) :
--   SettingsController.Get() -> Values     réglages en vigueur (pour un banc ou la barre de commande)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Settings = require(Config:WaitForChild("Settings"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type Values = Settings.Values

-- Un curseur (MusicRow, SoundRow).
type Slider = {
	attribute: string,
	track: GuiObject?,
	fill: GuiObject?,
	fillSize: UDim2, -- taille de Fill posée par Clément : seule la largeur en Scale change
	knob: GuiObject?,
	knobPosition: UDim2, -- place du Knob posée par Clément : seul Position.X.Scale change
	knobScale: UIScale?,
	label: Instance?,
}

-- Une place de ToggleKnob ou de ToggleLabel.
type Spot = { anchor: Vector2, position: UDim2 }
type Mover = { object: GuiObject, on: Spot, off: Spot }

-- Écran branché.
type Screen = {
	gui: ScreenGui,
	sliders: { [string]: Slider }, -- [nom de la rangée]
	onFill: GuiObject?,
	offFill: GuiObject?,
	toggleLabel: Instance?,
	movers: { Mover },
	moverTweens: { Tween },
	shownVfx: boolean?, -- état montré par la bascule (nil : pas encore peinte)
	choice: Instance?,
	connections: { RBXScriptConnection },
}

local SCREEN = "UI_Settings"
local HUD = "UI_HUD"
local HUD_BUTTON = "SettingsButton"
local SCREEN_PREFIX = "UI_" -- écrans de Clément (contrat 2.2) : leurs boutons font le son de clic
local TEMPLATE = "Template"
local ROWS: { [string]: string } = {
	MusicRow = Settings.MusicAttribute,
	SoundRow = Settings.SfxAttribute,
}
local PREV_BUTTON = "ClickRow.PrevButton"
local NEXT_BUTTON = "ClickRow.NextButton"
-- Textes, en anglais (L-036) : ceux de Clément (ToggleLabel « ON », ValueLabel « 80% »).
local ON_TEXT = "ON"
local OFF_TEXT = "OFF"
local VALUE_FORMAT = "%d%%"

local KNOB = Settings.Motion.KnobGrab
local SLIDE = Settings.Motion.ToggleSlide
local GRAB_INFO = TweenInfo.new(KNOB.Time, KNOB.Style, KNOB.Direction)
local LET_GO_INFO = TweenInfo.new(KNOB.ReleaseTime, KNOB.Style, KNOB.Direction)
local SLIDE_INFO = TweenInfo.new(SLIDE.Time, SLIDE.Style, SLIDE.Direction)

local IS_STUDIO = RunService:IsStudio()

local SettingsController = {}

local localPlayer = Players.LocalPlayer
local screen: Screen? = nil
local isOpen = false
local sfxGroup: SoundGroup? = nil
local dragging: string? = nil -- rangée du curseur qu'on glisse
local dragTouch: InputObject? = nil -- doigt qui glisse (toucher), nil à la souris
local saveToken = 0
local net: any = nil
local reported: { [string]: boolean } = {}
local clickWired: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watchedScreens: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local hudBound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Une ligne de sortie par sujet, en Studio seulement.
local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		print(message)
	end
end

------------------------------------------------------------------------------
-- Réglages en vigueur
------------------------------------------------------------------------------

local function readValues(): Values
	local default = Settings.Default
	local vfx = localPlayer:GetAttribute(Settings.VfxAttribute)
	local click = localPlayer:GetAttribute(Settings.ClickAttribute)
	return {
		Music = Settings.ReadVolume(localPlayer:GetAttribute(Settings.MusicAttribute)) or default.Music,
		Sfx = Settings.ReadVolume(localPlayer:GetAttribute(Settings.SfxAttribute)) or default.Sfx,
		Vfx = if type(vfx) == "boolean" then vfx else default.Vfx,
		Click = if Settings.IsClick(click) then click :: string else default.Click,
	}
end

function SettingsController.Get(): Values
	return readValues()
end

-- Envoi au serveur, Settings.SaveDelay s après le dernier changement.
local function scheduleSave()
	saveToken += 1
	local token = saveToken
	task.delay(Settings.SaveDelay, function()
		if token ~= saveToken or net == nil then
			return
		end
		local values = readValues()
		net.Client.SaveSettings:Fire(values.Music, values.Sfx, values.Vfx, values.Click)
	end)
end

local function change(attribute: string, value: any)
	if localPlayer:GetAttribute(attribute) ~= value then
		localPlayer:SetAttribute(attribute, value)
	end
	scheduleSave()
end

------------------------------------------------------------------------------
-- Sons : groupe SFX et son de clic
------------------------------------------------------------------------------

local function applySfxVolume()
	local group = sfxGroup
	if group then
		group.Volume = readValues().Sfx
	end
end

-- Un son du jeu rejoint le groupe SFX, sauf la musique et un son déjà dans un groupe.
local function adopt(inst: Instance)
	local group = sfxGroup
	if group == nil or not inst:IsA("Sound") then
		return
	end
	local sound = inst :: Sound
	if sound.SoundGroup ~= nil or string.sub(sound.Name, 1, #Settings.MusicPrefix) == Settings.MusicPrefix then
		return
	end
	sound.SoundGroup = group
end

local function watchSounds(root: Instance)
	root.DescendantAdded:Connect(adopt)
	for _, descendant in root:GetDescendants() do
		adopt(descendant)
	end
end

local function playClick(id: string?)
	local name = Settings.ClickSound(id or readValues().Click)
	local template = MarkerSounds.find(name)
	if template == nil then
		reportOnce(`click:{name}`, `[Settings] son de clic {name} absent de ReplicatedStorage.Assets.Sounds : clic sans son`)
		return
	end
	MarkerSounds.playSound(template, nil)
end

-- `inst` est le Template caché d'une liste, ou dedans.
local function inTemplate(inst: Instance): boolean
	local node: Instance? = inst
	while node ~= nil and not node:IsA("LayerCollector") do
		if node.Name == TEMPLATE then
			return true
		end
		node = node.Parent
	end
	return false
end

-- PrevButton / NextButton de ClickRow : ils jouent le nouveau son eux-mêmes.
local function isChoiceButton(button: Instance): boolean
	local parent = button.Parent
	return (button.Name == "PrevButton" or button.Name == "NextButton") and parent ~= nil and parent.Name == "ClickRow"
end

local function wireClick(inst: Instance)
	if clickWired[inst] or inst.Parent == nil or not inst:IsA("GuiButton") or inTemplate(inst) or isChoiceButton(inst) then
		return
	end
	clickWired[inst] = true
	(inst :: GuiButton).Activated:Connect(function()
		playClick(nil)
	end)
end

-- Un écran de Clément : ses boutons, puis ce qui y arrive (copies des contrôleurs, branchées à la fin
-- de l'image : une copie renommée juste après son arrivée n'est plus « Template »).
local function watchScreen(gui: Instance)
	if watchedScreens[gui] or not gui:IsA("LayerCollector") or string.sub(gui.Name, 1, #SCREEN_PREFIX) ~= SCREEN_PREFIX then
		return
	end
	watchedScreens[gui] = true
	gui.DescendantAdded:Connect(function(descendant: Instance)
		task.defer(wireClick, descendant)
	end)
	for _, descendant in gui:GetDescendants() do
		wireClick(descendant)
	end
end

------------------------------------------------------------------------------
-- Écran : affichage
------------------------------------------------------------------------------

local function setText(element: Instance?, text: string)
	if element == nil then
		return
	end
	local holder: Instance? = element
	if not (element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox")) then
		holder = element:FindFirstChildWhichIsA("TextLabel", true)
	end
	if holder then
		local label = holder :: any
		if label.Text ~= text then
			label.Text = text
		end
	end
end

local function setVisible(element: GuiObject?, visible: boolean)
	if element and element.Visible ~= visible then
		element.Visible = visible
	end
end

local function paintSlider(slider: Slider, value: number)
	local fraction = math.clamp(value, 0, 1)
	local fill = slider.fill
	if fill then
		local size = slider.fillSize
		local wanted = UDim2.new(fraction, size.X.Offset, size.Y.Scale, size.Y.Offset)
		if fill.Size ~= wanted then
			fill.Size = wanted
		end
	end
	local knob = slider.knob
	if knob then
		local base = slider.knobPosition
		local wanted = UDim2.new(fraction, base.X.Offset, base.Y.Scale, base.Y.Offset)
		if knob.Position ~= wanted then
			knob.Position = wanted
		end
	end
	setText(slider.label, string.format(VALUE_FORMAT, math.floor(fraction * 100 + 0.5)))
end

local function stopMovers(current: Screen)
	for _, tween in current.moverTweens do
		tween:Cancel()
	end
	table.clear(current.moverTweens)
end

-- Rien si la bascule montre déjà cet état (un glissement en cours n'est pas coupé par l'écho de
-- l'attribut).
local function paintToggle(current: Screen, on: boolean, animate: boolean)
	if current.shownVfx == on then
		return
	end
	current.shownVfx = on
	setVisible(current.onFill, on)
	setVisible(current.offFill, not on)
	setText(current.toggleLabel, if on then ON_TEXT else OFF_TEXT)
	stopMovers(current)
	for _, mover in current.movers do
		local spot = if on then mover.on else mover.off
		local object = mover.object
		if animate then
			-- Ancre et place glissent ensemble, comme dans le prototype de Clément.
			local goal: { [string]: any } = { AnchorPoint = spot.anchor, Position = spot.position }
			local tween = TweenService:Create(object, SLIDE_INFO, goal)
			table.insert(current.moverTweens, tween)
			tween:Play()
		else
			object.AnchorPoint = spot.anchor
			object.Position = spot.position
		end
	end
end

local function paintChoice(current: Screen, id: string)
	local click = Settings.Clicks[Settings.ClickIndex(id)]
	setText(current.choice, click.DisplayName)
end

-- L'écran d'accord avec les réglages en vigueur (sauf le curseur qu'on glisse).
local function paint(current: Screen, animate: boolean)
	local values = readValues()
	for rowName, slider in current.sliders do
		if dragging ~= rowName then
			paintSlider(slider, if slider.attribute == Settings.MusicAttribute then values.Music else values.Sfx)
		end
	end
	paintToggle(current, values.Vfx, animate)
	paintChoice(current, values.Click)
end

------------------------------------------------------------------------------
-- Écran : curseurs
------------------------------------------------------------------------------

local function knobTo(slider: Slider, scale: number, info: TweenInfo)
	local knobScale = slider.knobScale
	if knobScale and knobScale.Parent ~= nil then
		local goal: { [string]: any } = { Scale = scale }
		TweenService:Create(knobScale, info, goal):Play()
	end
end

local function fractionAt(slider: Slider, x: number): number
	local track = slider.track
	if track == nil then
		return 0
	end
	return math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
end

local function dragTo(x: number)
	local current = screen
	local rowName = dragging
	if current == nil or rowName == nil then
		return
	end
	local slider = current.sliders[rowName]
	if slider == nil then
		return
	end
	local value = fractionAt(slider, x)
	paintSlider(slider, value)
	change(slider.attribute, value) -- le groupe SFX et MusicController suivent l'attribut
end

local function startDrag(rowName: string, input: InputObject)
	local current = screen
	if current == nil or not isOpen then
		return
	end
	local slider = current.sliders[rowName]
	if slider == nil then
		return
	end
	dragging = rowName
	dragTouch = if input.UserInputType == Enum.UserInputType.Touch then input else nil
	knobTo(slider, KNOB.To, GRAB_INFO)
	dragTo(input.Position.X)
end

local function stopDrag()
	local rowName = dragging
	if rowName == nil then
		return
	end
	dragging = nil
	dragTouch = nil
	local current = screen
	local slider = if current then current.sliders[rowName] else nil
	if slider then
		knobTo(slider, 1, LET_GO_INFO)
	end
end

local function isPress(input: InputObject): boolean
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
end

------------------------------------------------------------------------------
-- Écran : liaison, ouverture, fermeture
------------------------------------------------------------------------------

local function close()
	isOpen = false
	stopDrag()
	local current = screen
	if current then
		Motion.Close(current.gui)
	end
end

local function guiObject(root: Instance, path: string): GuiObject?
	local found = Find.path(root, path)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

-- Place symétrique d'une place de Clément (de l'autre côté de son parent).
local function mirror(spot: Spot): Spot
	local p = spot.position
	return {
		anchor = Vector2.new(1 - spot.anchor.X, spot.anchor.Y),
		position = UDim2.new(1 - p.X.Scale, -p.X.Offset, p.Y.Scale, p.Y.Offset),
	}
end

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
		stopMovers(old)
	end
	stopDrag()
	isOpen = false
	gui.Enabled = false -- fermé jusqu'au bouton du HUD
	Motion.SetCloser(gui, close) -- un autre écran du groupe ScreenGroup s'ouvre (L-089)

	local connections: { RBXScriptConnection } = {}
	local sliders: { [string]: Slider } = {}
	for rowName, attribute in ROWS do
		local row = Find.path(gui, rowName)
		if row == nil then
			reportOnce(`row:{rowName}`, `[Settings] {SCREEN}.{rowName} introuvable : réglage pas branché`)
			continue
		end
		local track = guiObject(row, "Slider.Track")
		local fill = if track then guiObject(track, "Fill") else nil
		local knob = guiObject(row, "Slider.Knob")
		local knobScale: UIScale? = nil
		if knob and knob:FindFirstChildOfClass("UIScale") == nil then
			local scale = Instance.new("UIScale")
			scale.Name = KNOB.ScaleName
			scale.Scale = 1
			scale.Parent = knob
			knobScale = scale
		end
		local slider: Slider = {
			attribute = attribute,
			track = track,
			fill = fill,
			fillSize = if fill then fill.Size else UDim2.new(1, 0, 1, 0),
			knob = knob,
			knobPosition = if knob then knob.Position else UDim2.new(),
			knobScale = knobScale,
			label = Find.path(row, "ValueLabel"),
		}
		sliders[rowName] = slider
		local function grip(object: GuiObject)
			table.insert(connections, object.InputBegan:Connect(function(input: InputObject)
				if isPress(input) then
					startDrag(rowName, input)
				end
			end))
		end
		if track then
			grip(track)
		end
		if knob then
			grip(knob)
		end
		if track == nil or knob == nil then
			reportOnce(`slider:{rowName}`, `[Settings] {SCREEN}.{rowName}.Slider : Track ou Knob introuvable`)
		end
	end

	local toggle = Find.path(gui, "VfxRow.Toggle")
	local onFill = if toggle then guiObject(toggle, "OnFill") else nil
	local offFill = if toggle then guiObject(toggle, "OffFill") else nil
	-- Places de Clément : celles de l'état qu'il a montré (OnFill visible = ON).
	local shownOn = onFill == nil or onFill.Visible
	local movers: { Mover } = {}
	for _, name in { "ToggleKnob", "ToggleLabel" } do
		local object = if toggle then guiObject(toggle, name) else nil
		if object then
			local spot: Spot = { anchor = object.AnchorPoint, position = object.Position }
			local other = mirror(spot)
			table.insert(movers, { object = object, on = if shownOn then spot else other, off = if shownOn then other else spot })
		end
	end
	if toggle == nil then
		reportOnce("toggle", `[Settings] {SCREEN}.VfxRow.Toggle introuvable : effets visuels pas branchés`)
	end

	local current: Screen = {
		gui = gui,
		sliders = sliders,
		onFill = onFill,
		offFill = offFill,
		toggleLabel = if toggle then Find.path(toggle, "ToggleLabel") else nil,
		movers = movers,
		moverTweens = {},
		shownVfx = nil,
		choice = Find.path(gui, "ClickRow.ChoiceLabel"),
		connections = connections,
	}
	screen = current

	local function onActivated(path: string, handler: () -> ())
		local button = Find.path(gui, path)
		if button and button:IsA("GuiButton") then
			table.insert(connections, (button :: GuiButton).Activated:Connect(function()
				handler()
			end))
		else
			reportOnce(`button:{path}`, `[Settings] {SCREEN}.{path} introuvable ou pas un bouton`)
		end
	end
	onActivated("CloseButton", close)
	if toggle then
		onActivated("VfxRow.Toggle", function()
			local on = not readValues().Vfx
			if screen == current then
				paintToggle(current, on, true) -- avant l'attribut : son signal trouve l'état déjà montré
			end
			change(Settings.VfxAttribute, on)
		end)
	end
	local function step(delta: number)
		local count = #Settings.Clicks
		local index = (Settings.ClickIndex(readValues().Click) - 1 + delta) % count + 1
		local id = Settings.Clicks[index].Id
		change(Settings.ClickAttribute, id)
		if screen == current then
			paintChoice(current, id)
		end
		playClick(id)
	end
	onActivated(PREV_BUTTON, function()
		step(-1)
	end)
	onActivated(NEXT_BUTTON, function()
		step(1)
	end)
	paint(current, false)
end

local function currentScreen(): Screen?
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local found = if playerGui then playerGui:FindFirstChild(SCREEN) else nil
	local wanted = if found and found:IsA("ScreenGui") then found :: ScreenGui else nil
	local bound = screen
	if bound and bound.gui == wanted and bound.gui.Parent ~= nil then
		return bound
	end
	if wanted then
		bind(wanted)
		return screen
	end
	return nil
end

local function open()
	local current = currentScreen()
	if current == nil then
		reportOnce("screen", `[Settings] écran {SCREEN} absent de PlayerGui : les réglages ne s'ouvrent pas`)
		return
	end
	isOpen = true
	paint(current, false)
	Motion.Open(current.gui)
end

local function toggleScreen()
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
	local found = Find.path(gui, HUD_BUTTON)
	if found == nil or not found:IsA("GuiButton") then
		reportOnce("hud", `[Settings] {HUD}.{HUD_BUTTON} introuvable ou pas un bouton : les réglages ne s'ouvrent pas`)
		return
	end
	hudBound[gui] = true
	local button = found :: GuiButton
	button.Visible = true -- caché par Clément tant que le code ne le montre pas (Features.Settings)
	button.Activated:Connect(toggleScreen)
end

------------------------------------------------------------------------------

function SettingsController.Start()
	-- Groupe des effets sonores (créé ici, jamais par Clément) et rangement des sons du jeu.
	local group = Instance.new("SoundGroup")
	group.Name = Settings.SfxGroup
	group.Parent = SoundService
	sfxGroup = group
	applySfxVolume()
	watchSounds(SoundService)
	watchSounds(Workspace)

	local ok, result = pcall(function()
		return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	end)
	if ok then
		net = result
	end

	local function onAttribute()
		applySfxVolume()
		local current = screen
		if current and current.gui.Parent ~= nil then
			paint(current, false)
		end
	end
	for _, attribute in { Settings.MusicAttribute, Settings.SfxAttribute, Settings.ClickAttribute } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(onAttribute)
	end
	localPlayer:GetAttributeChangedSignal(Settings.VfxAttribute):Connect(function()
		local current = screen
		if current and current.gui.Parent ~= nil then
			paintToggle(current, readValues().Vfx, false)
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging == nil then
			return
		end
		local touch = dragTouch
		local kind = input.UserInputType
		if (touch == nil and kind == Enum.UserInputType.MouseMovement) or (touch ~= nil and input == touch) then
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local touch = dragTouch
		if dragging ~= nil and isPress(input) and (touch == nil or input == touch) then
			stopDrag()
		end
	end)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		watchScreen(child)
		if not Features.Settings or not child:IsA("ScreenGui") then
			return
		end
		if child.Name == SCREEN then
			bind(child :: ScreenGui)
		elseif child.Name == HUD then
			bindHud(child)
		end
	end)
	for _, child in playerGui:GetChildren() do
		watchScreen(child)
	end
	if not Features.Settings then
		return -- réglages sauvegardés appliqués (sons, effets), mais ni bouton ni écran
	end
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end
	local hud = playerGui:FindFirstChild(HUD)
	if hud and hud:IsA("ScreenGui") then
		bindHud(hud)
	end
end

return SettingsController
