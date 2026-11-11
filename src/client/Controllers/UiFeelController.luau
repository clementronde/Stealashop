--!strict
-- UiFeelController (client, liaison L-091 point 7) : les animations d'UI « qui donnent envie de
-- toucher », branchées sur tous les écrans de Clément, valeurs dans Config/UiMotion (tableau de
-- docs/claude/notes/ui-motion-skilltree.md).
--
-- Rôle :
--   - Boutons : chaque GuiButton des écrans UI_* du PlayerGui (copies de StarterGui, et ce que les
--     contrôleurs y clonent ensuite) reçoit Motion.Button : survol (Hover, calque Shade, son
--     UI_Hover), appui (Press), relâché (Release). Les boutons nommés dans UiMotion.Success.Buttons
--     (Buy, Equip, Claim, Confirm, Place, Equip Best…) font en plus Motion.Success à chaque clic,
--     comme dans le prototype de Clément (tools/clement/ui_feel_proto.luau) : le serveur peut encore
--     refuser l'achat, le bouton a déjà sauté. Laissés de côté : le Template caché d'une liste (et ce
--     qu'il contient ; ses copies, elles, sont branchées), un bouton à la racine d'un écran (Motion.Open
--     met déjà la racine à l'échelle) et un bouton aussi grand que son parent (calque de glisser).
--   - Cartes : un cadre avec un enfant HoverOutline (Index, inventaire, boutiques…) reçoit
--     Motion.HoverCard (et pas l'effet de bouton) ; ses boutons à lui (PLACE…) gardent le leur.
--   - Sons d'UI : donne à Motion le moyen de les jouer (Shared/Anim/MarkerSounds, son 2D, rien s'il
--     manque dans ReplicatedStorage/Assets/Sounds : une ligne par son, en Studio).
--   - Poursuite (ChaseController.IsChased) : ChasePulse (la transparence des bords rouges de UI_Chase,
--     ScreenEdges et Vignette.Edge, bat en sinus) et ChaseFov (champ de vision de la caméra + Add). À
--     la fin, chaque transparence reprend sa valeur d'origine et la caméra son champ de vision.
--     RunBanner (L-092 3a) : entrée 0 → 1,18 → 1 par un UIScale passager (RunBanner.ScaleName),
--     puis il bat (+5 %) et penche (± 1,5°) au rythme des bords ; à la fin, UIScale détruit et
--     Rotation d'origine remise. Motion.KeepScale l'écarte de l'échelle de Motion.Open.
-- Ce qui est touché, et rien d'autre : ce que fait Motion (UIScale passagers, Shade, HoverOutline, Icon
-- des cartes, tous remis ensuite), la transparence des bords de UI_Chase et RunBanner pendant la poursuite et
-- Camera.FieldOfView. Aucun objet n'est laissé une fois l'animation finie.
--
-- API (client) : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiMotion = require(Shared:WaitForChild("Config"):WaitForChild("UiMotion"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

type ChaseApi = { IsChased: () -> boolean }
type Pulse = { object: Instance, property: string, base: number }

local SCREEN_PREFIX = "UI_" -- écrans de Clément (contrat 2.2)
local CHASE_SCREEN = "UI_Chase"
local TEMPLATE = "Template"

local SUCCESS: { [string]: boolean } = {}
for _, name in UiMotion.Success.Buttons do
	SUCCESS[name] = true
end
local function successSkipped(button: Instance): boolean
	for _, screen in UiMotion.Success.SkipScreens do
		if button:FindFirstAncestor(screen) ~= nil then
			return true
		end
	end
	return false
end

local PULSE = UiMotion.ChasePulse
local FOV = UiMotion.ChaseFov
local FOV_IN_INFO = TweenInfo.new(FOV.InTime, FOV.Style, FOV.Direction)
local FOV_OUT_INFO = TweenInfo.new(FOV.OutTime, FOV.Style, FOV.Direction)
local BANNER = UiMotion.RunBanner
local BANNER_IN_INFO = TweenInfo.new(BANNER.InTime, BANNER.Style, BANNER.Direction)
local BANNER_SETTLE_INFO = TweenInfo.new(BANNER.SettleTime, BANNER.Style, BANNER.Direction)

local UiFeelController = {}

local localPlayer = Players.LocalPlayer
local chase: ChaseApi? = nil
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local successWired: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local chasing = false
local chaseStartedAt = 0
local pulses: { Pulse } = {}
local fovBase: number? = nil -- champ de vision d'avant la poursuite, remis à la fin
local fovTween: Tween? = nil
-- RunBanner pendant la poursuite (L-092 3a) : son UIScale passager, sa Rotation d'origine, et
-- `beating` une fois l'entrée finie.
type Banner = { object: GuiObject, scale: UIScale?, rotation: number, tween: Tween?, beating: boolean }
local banner: Banner? = nil

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

------------------------------------------------------------------------------
-- Boutons et cartes
------------------------------------------------------------------------------

-- `inst` est le Template caché d'une liste, ou dedans.
local function inTemplate(inst: Instance): boolean
	local current: Instance? = inst
	while current ~= nil and not current:IsA("LayerCollector") do
		if current.Name == TEMPLATE then
			return true
		end
		current = current.Parent
	end
	return false
end

local function fillsParent(object: GuiObject): boolean
	local size = object.Size
	return size.X.Scale >= 1 and size.Y.Scale >= 1
end

local function wire(inst: Instance)
	if inst.Parent == nil or not inst:IsA("GuiObject") or inTemplate(inst) then
		return
	end
	local object = inst :: GuiObject
	if object:FindFirstChild(UiMotion.HoverCard.Outline) ~= nil then
		Motion.HoverCard(object)
		return
	end
	if not object:IsA("GuiButton") then
		return
	end
	local parent = object.Parent
	if parent == nil or parent:IsA("LayerCollector") or fillsParent(object) then
		return
	end
	local button = object :: GuiButton
	Motion.Button(button)
	if SUCCESS[button.Name] and not successWired[button] and not successSkipped(button) then
		successWired[button] = true
		button.Activated:Connect(function()
			Motion.Success(button)
		end)
	end
end

-- Un écran de Clément : ce qu'il contient, puis ce qui y arrive (copies des contrôleurs). Le
-- branchement attend la fin de l'image : une copie renommée juste après son arrivée n'est plus
-- « Template ».
local function watchScreen(screen: Instance)
	if watched[screen] or not screen:IsA("LayerCollector") or string.sub(screen.Name, 1, #SCREEN_PREFIX) ~= SCREEN_PREFIX then
		return
	end
	watched[screen] = true
	if screen.Name == CHASE_SCREEN then
		-- RunBanner s'anime à part (L-092 3a) : Motion.Open ne le met pas à l'échelle.
		local runBanner = screen:FindFirstChild(BANNER.Name, true)
		if runBanner and runBanner:IsA("GuiObject") then
			Motion.KeepScale(runBanner)
		end
	end
	screen.DescendantAdded:Connect(function(descendant: Instance)
		task.defer(wire, descendant)
	end)
	for _, descendant in screen:GetDescendants() do
		wire(descendant)
	end
end

------------------------------------------------------------------------------
-- Poursuite : bords qui battent (ChasePulse) et champ de vision (ChaseFov)
------------------------------------------------------------------------------

local function addPulse(object: Instance, property: string)
	table.insert(pulses, { object = object, property = property, base = (object :: any)[property] })
end

local function collectPulses()
	table.clear(pulses)
	local gui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local screen = if gui then gui:FindFirstChild(CHASE_SCREEN) else nil
	if screen == nil then
		return
	end
	for _, path in PULSE.Targets do
		local target = Find.path(screen, path)
		if target and target:IsA("GuiObject") then
			if target:IsA("ImageLabel") or target:IsA("ImageButton") then
				addPulse(target, "ImageTransparency")
			else
				-- Un cadre : ses images, sinon son propre fond.
				local images = 0
				for _, child in target:GetDescendants() do
					if child:IsA("ImageLabel") or child:IsA("ImageButton") then
						addPulse(child, "ImageTransparency")
						images += 1
					end
				end
				if images == 0 then
					-- Un cadre transparent (ScreenEdges, plein écran) n'est qu'un conteneur : ce sont ses
					-- bandes (Left, Right, Bottom) qui battent, sinon tout l'écran se voile de gris.
					if (target :: GuiObject).BackgroundTransparency < 1 then
						addPulse(target, "BackgroundTransparency")
					else
						for _, child in target:GetChildren() do
							if child:IsA("GuiObject") and child.BackgroundTransparency < 1 then
								addPulse(child, "BackgroundTransparency")
							end
						end
					end
				end
			end
		end
	end
end

local function restorePulses()
	for _, pulse in pulses do
		if pulse.object.Parent ~= nil then
			(pulse.object :: any)[pulse.property] = pulse.base
		end
	end
	table.clear(pulses)
end

local function tweenFov(goal: number, info: TweenInfo, finish: (() -> ())?)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local previous = fovTween
	if previous then
		previous:Cancel()
	end
	local tween = TweenService:Create(camera, info, { FieldOfView = goal })
	fovTween = tween
	tween.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and fovTween == tween then
			fovTween = nil
			if finish then
				finish()
			end
		end
	end)
	tween:Play()
end

-- RunBanner (L-092 3a) : entrée 0 → Peak → 1 par son UIScale passager, puis battement et
-- inclinaison au rythme des bords (step). Un UIScale qui n'est pas le sien (Clément) : pas d'échelle.
local function startBanner()
	local gui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local screen = if gui then gui:FindFirstChild(CHASE_SCREEN) else nil
	local found = if screen then screen:FindFirstChild(BANNER.Name, true) else nil
	if found == nil or not found:IsA("GuiObject") then
		return
	end
	local object = found :: GuiObject
	Motion.KeepScale(object)
	local state: Banner = { object = object, scale = nil, rotation = object.Rotation, tween = nil, beating = false }
	banner = state
	if object:FindFirstChildOfClass("UIScale") ~= nil then
		state.beating = true
		return
	end
	local scale = Instance.new("UIScale")
	scale.Name = BANNER.ScaleName
	scale.Scale = 0
	scale.Parent = object
	state.scale = scale
	local enter = TweenService:Create(scale, BANNER_IN_INFO, { Scale = BANNER.Peak })
	state.tween = enter
	enter.Completed:Connect(function(playback: Enum.PlaybackState)
		if playback ~= Enum.PlaybackState.Completed or banner ~= state then
			return
		end
		local settle = TweenService:Create(scale, BANNER_SETTLE_INFO, { Scale = 1 })
		state.tween = settle
		settle.Completed:Connect(function(settled: Enum.PlaybackState)
			if settled == Enum.PlaybackState.Completed and banner == state then
				state.tween = nil
				state.beating = true
			end
		end)
		settle:Play()
	end)
	enter:Play()
end

-- Fin de la poursuite : UIScale détruit, Rotation d'origine remise.
local function stopBanner()
	local state = banner
	if state == nil then
		return
	end
	banner = nil
	local tween = state.tween
	if tween then
		tween:Cancel()
	end
	local scale = state.scale
	if scale then
		scale:Destroy()
	end
	if state.object.Parent ~= nil then
		state.object.Rotation = state.rotation
	end
end

-- Battement (+Beat quand les bords sont le plus visibles) et inclinaison (± Tilt degrés).
local function beatBanner(elapsed: number)
	local state = banner
	if state == nil or not state.beating or state.object.Parent == nil then
		return
	end
	local phase = 2 * math.pi * PULSE.Rate * elapsed
	local scale = state.scale
	if scale then
		scale.Scale = 1 + BANNER.Beat * (0.5 - 0.5 * math.sin(phase))
	end
	state.object.Rotation = state.rotation + BANNER.Tilt * math.sin(phase)
end

local function startChase()
	chaseStartedAt = os.clock()
	collectPulses()
	startBanner()
	local camera = Workspace.CurrentCamera
	if camera then
		if fovBase == nil then
			fovBase = camera.FieldOfView
		end
		tweenFov((fovBase :: number) + FOV.Add, FOV_IN_INFO, nil)
	end
end

local function stopChase()
	restorePulses()
	stopBanner()
	local base = fovBase
	if base then
		tweenFov(base, FOV_OUT_INFO, function()
			fovBase = nil
		end)
	end
end

local function step()
	local api = chase
	local now = api ~= nil and api.IsChased()
	if now ~= chasing then
		chasing = now
		if now then
			startChase()
		else
			stopChase()
		end
	end
	if not chasing then
		return
	end
	beatBanner(os.clock() - chaseStartedAt)
	if #pulses == 0 then
		return
	end
	local wave = 0.5 + 0.5 * math.sin(2 * math.pi * PULSE.Rate * (os.clock() - chaseStartedAt))
	local value = PULSE.Min + (PULSE.Max - PULSE.Min) * wave
	for _, pulse in pulses do
		if pulse.object.Parent ~= nil then
			(pulse.object :: any)[pulse.property] = value
		end
	end
end

------------------------------------------------------------------------------

function UiFeelController.Start()
	local ok, markerSounds = pcall(function()
		return require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds")) :: any
	end)
	if ok and type(markerSounds) == "table" then
		Motion.SetSoundPlayer(function(name: string)
			markerSounds.play(name, nil) -- son 2D, pour le joueur local seulement
		end)
	end
	chase = sibling("ChaseController")
	RunService.Heartbeat:Connect(step)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(watchScreen)
	for _, child in playerGui:GetChildren() do
		watchScreen(child)
	end
end

return UiFeelController
