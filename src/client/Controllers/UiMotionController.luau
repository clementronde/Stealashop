--!strict
-- UiMotionController (vague 59, a189, L-182 points 1 et 3 ; client) : le module commun de la nouvelle direction de
-- l'UI. Il suit les écrans UI_* du PlayerGui (copies de StarterGui, et ce que les contrôleurs y clonent ensuite).
--
-- Rôle :
--   - Apparitions (attribut Appear de Clément, Controllers/UI/Appear) : un écran qui s'allume (Enabled passe à vrai)
--     joue l'entrée de ses éléments Appear visibles ; un élément Appear qui devient visible (Visible) joue la sienne.
--     Un écran qui s'éteint, un élément caché, retiré ou détruit : tout revient à l'état de Clément. La fermeture
--     courte se joue par Motion.Close (écran) ou Motion.Hide (élément), qui l'attendent avant d'éteindre ; un écran
--     éteint directement (Enabled = false) disparaît d'un coup. Hover et Press sont lus par Motion.Button et
--     Motion.HoverCard (branchés par UiFeelController) ; la valeur d'un des trois attributs qui n'est pas au contrat
--     donne une ligne dans la sortie, en Studio, une fois par élément.
--   - Flou (L-182 point 3) : un BlurEffect UiMotion.Blur.Name créé dans Lighting (local au joueur) monte à Blur.Size
--     quand un écran de Blur.Screens (ou un ScreenGui qui porte l'attribut Blur.Attribute = true) est allumé, et part
--     en Blur.OutTime à sa fermeture (dès que Motion le ferme), ou dès qu'une poursuite commence
--     (ChaseController.IsChased) : jamais de flou pendant une poursuite. Parti, il est détruit. Une connexion
--     Heartbeat seulement tant qu'un de ces écrans est allumé ou que le flou est là.
--   - Barre du bas qui s'écarte (vague 64, a212, Config/UiMotion.HudAway) : tant qu'un écran de HudAway.Screens (ou
--     un ScreenGui avec l'attribut HudAway.Attribute = true) est allumé, Controllers/UI/HudMask.SetAway la fait sortir
--     par le bas ; elle revient quand il s'éteint, ou dès qu'une poursuite commence. Animations réduites : d'un coup.
--   - Cartes au défilement (vague 66, a222, Config/UiMotion.ScrollReveal) : un écran qui s'allume arme
--     Controllers/UI/ScrollReveal (les cartes de ses listes hors de la zone visible entrent en défilant) ; éteint, il
--     est désarmé.
--   - Vague 73 (a256, L-230, Config/UiMotion.WindowTas) : flou sous la caméra (Blur.UnderCamera), sortie Blur.OutDelay s
--     après le clic ; tout le HUD (HudHide.Hide) éteint à l'image où une grande fenêtre (HudHide.Screens, ou l'attribut
--     HudHide.Attribute = true) s'allume, rendu à l'image où elle s'éteint (HudMask, masque HudHide.MaskKey) ; sauf
--     les écrans que toutes les fenêtres allumées gardent (HudHide.Keep, correctif f70 : UI_Displayed garde UI_Hotbar).
-- Connexions : une par écran pour Enabled, DescendantAdded et AncestryChanged, et une ou deux par élément qui porte
-- un attribut d'animation ; toutes coupées quand l'élément quitte l'écran ou que l'écran quitte le PlayerGui.
-- Aucun script dans l'UI ; aucune valeur de Clément changée durablement.
--
-- API (client) :
--   UiMotionController.GetBlur() -> { Active: boolean, Size: number, Wanted: boolean }   état du flou (bancs)
--   UiMotionController.GetWatchCount() -> number   éléments suivis (bancs : aucune connexion qui reste)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiMotion = require(Shared:WaitForChild("Config"):WaitForChild("UiMotion"))
local Attributes = require(Shared:WaitForChild("Contract"):WaitForChild("Attributes"))
local UI = script.Parent:WaitForChild("UI")
local Appear = require(UI:WaitForChild("Appear"))
local Motion = require(UI:WaitForChild("Motion"))

type ChaseApi = { IsChased: () -> boolean }
-- HudMask (vague 64) : lu s'il est là (un banc qui ne monte que Motion et Appear : pas de barre qui s'écarte).
type HudMaskApi = {
	SetAway: (boolean, boolean?) -> (),
	Push: (string, { HideScreens: { string }? }) -> (),
	Pop: (string) -> (),
}
local hudMask: HudMaskApi? = (function(): HudMaskApi?
	local module = UI:FindFirstChild("HudMask")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result :: any else nil
end)()

local AWAY = UiMotion.HudAway
local AWAY_RECHECK = AWAY.Recheck
local AWAY_SCREENS: { [string]: boolean } = {}
for _, name in AWAY.Screens do
	AWAY_SCREENS[name] = true
end
-- ScrollReveal (vague 66, a222) : lu s'il est là (un banc qui ne le monte pas : rien au défilement).
type ScrollRevealApi = { Arm: (ScreenGui) -> (), Disarm: (ScreenGui) -> () }
local scrollReveal: ScrollRevealApi? = (function(): ScrollRevealApi?
	local module = UI:FindFirstChild("ScrollReveal")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result :: any else nil
end)()

local awayScreens: { [ScreenGui]: boolean } = {}
-- Vague 73 (a256, L-230 point 1, Config/UiMotion.HudHide) : grandes fenêtres qui cachent tout le HUD.
local HIDE = UiMotion.HudHide
local HIDE_SCREENS: { [string]: boolean } = {}
for _, name in HIDE.Screens do
	HIDE_SCREENS[name] = true
end
-- Correctif f70 (B2, Config/UiMotion.HudHide.Keep) : par grande fenêtre, les écrans de Hide qu'elle laisse allumés.
local HIDE_KEEP: { [string]: { [string]: boolean } } = {}
for window, kept in HIDE.Keep do
	local set: { [string]: boolean } = {}
	for _, name in kept do
		set[name] = true
	end
	HIDE_KEEP[window] = set
end
local hideScreens: { [ScreenGui]: boolean } = {}
local hideKey = "" -- écrans de Hide masqués en ce moment, joints par des virgules ("" : masque retiré)
local awayWanted = false
local awayRecheck = 0

local SCREEN_PREFIX = "UI_"
local TEMPLATE = "Template"
local BLUR = UiMotion.Blur
local BLUR_IN_INFO = TweenInfo.new(BLUR.InTime, BLUR.Style, BLUR.Direction)
local BLUR_OUT_INFO = TweenInfo.new(BLUR.OutTime, BLUR.Style, BLUR.Direction, 0, false, BLUR.OutDelay)
local IS_STUDIO = RunService:IsStudio()

local BLUR_SCREENS: { [string]: boolean } = {}
for _, name in BLUR.Screens do
	BLUR_SCREENS[name] = true
end

-- Les trois attributs d'animation et leurs valeurs connues (Contract/Attributes).
local WATCHED: { { name: string, values: { [string]: boolean }, list: string } } = {}
for _, def in { Attributes.Appear, Attributes.Hover, Attributes.Press } do
	local values: { [string]: boolean } = {}
	for _, value in def.Values do
		values[value] = true
	end
	table.insert(WATCHED, { name = def.Name, values = values, list = table.concat(def.Values, ", ") })
end

local UiMotionController = {}

local localPlayer = Players.LocalPlayer
local chase: ChaseApi? = nil
local screens: { [Instance]: { RBXScriptConnection } } = {}
local objects: { [Instance]: { RBXScriptConnection } } = {}
local warned: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local blurScreens: { [ScreenGui]: boolean } = {}
local blur: BlurEffect? = nil
local blurTween: Tween? = nil
local blurWanted = false
local blurStep: RBXScriptConnection? = nil

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

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

local function shownInScreen(object: GuiObject): boolean
	local current: Instance? = object
	while current ~= nil do
		if current:IsA("GuiObject") and not (current :: GuiObject).Visible then
			return false
		end
		if current:IsA("LayerCollector") then
			return (current :: LayerCollector).Enabled
		end
		current = current.Parent
	end
	return false
end

------------------------------------------------------------------------------
-- Flou
------------------------------------------------------------------------------

local function lighting(): Instance?
	local ok, service = pcall(function(): Instance
		return game:GetService("Lighting")
	end)
	return if ok then service else nil
end

local function wantsBlur(): boolean
	local api = chase
	if api ~= nil and api.IsChased() then
		return false
	end
	for gui in blurScreens do
		if gui.Enabled and gui.Parent ~= nil and Motion.GetState(gui) ~= "Closing" then
			return true
		end
	end
	return false
end

local function stopBlurStep()
	local connection = blurStep
	blurStep = nil
	if connection then
		connection:Disconnect()
	end
end

local function setBlur(wanted: boolean)
	if wanted == blurWanted then
		return
	end
	blurWanted = wanted
	local previous = blurTween
	blurTween = nil
	if previous then
		previous:Cancel()
	end
	local effect = blur
	if wanted and (effect == nil or effect.Parent == nil) then
		-- Vague 73 (L-230) : sous la caméra (rien dans Lighting, qui est à Clément) ; Lighting si elle manque.
		local camera: Instance? = nil
		if BLUR.UnderCamera then
			local ok, found = pcall(function(): any
				return game:GetService("Workspace").CurrentCamera
			end)
			camera = if ok and typeof(found) == "Instance" then found else nil
		end
		local parent = if camera ~= nil then camera else lighting()
		if parent == nil then
			return
		end
		local created = Instance.new("BlurEffect")
		created.Name = BLUR.Name
		created.Size = 0
		created.Parent = parent
		blur = created
		effect = created
	end
	if effect == nil then
		return
	end
	local current: BlurEffect = effect
	local tween = TweenService:Create(current, if wanted then BLUR_IN_INFO else BLUR_OUT_INFO, { Size = if wanted then BLUR.Size else 0 })
	blurTween = tween
	tween.Completed:Connect(function(playback: Enum.PlaybackState)
		if playback ~= Enum.PlaybackState.Completed or blurTween ~= tween then
			return
		end
		blurTween = nil
		if not blurWanted then
			if blur == current then
				blur = nil
			end
			current:Destroy() -- parti : rien n'est laissé dans Lighting
		end
	end)
	tween:Play()
end

-- Vague 64 (a212, Config/UiMotion.HudAway) : la barre du bas s'écarte tant qu'un écran plein est allumé (elle part à
-- l'ouverture et revient quand l'écran s'est éteint, comme dans la vidéo), jamais pendant une poursuite.
local function wantsAway(): boolean
	if not AWAY.Enabled then
		return false
	end
	local api = chase
	if api ~= nil and api.IsChased() then
		return false
	end
	for gui in awayScreens do
		if gui.Enabled and gui.Parent ~= nil then
			return true
		end
	end
	return false
end

local function updateAway(dt: number)
	local wanted = wantsAway()
	awayRecheck += dt
	-- Rappel toutes les AWAY_RECHECK s tant qu'elle est écartée : une copie neuve de la barre (ResetOnSpawn) suit.
	if wanted == awayWanted and not (wanted and awayRecheck >= AWAY_RECHECK) then
		return
	end
	awayWanted = wanted
	awayRecheck = 0
	local api = hudMask
	if api ~= nil then
		api.SetAway(wanted, Appear.Reduced())
	end
end

-- Vague 73 (a256, L-230 point 1, Config/UiMotion.HudHide) : tout le HUD (HudHide.Hide) éteint tant qu'une grande
-- fenêtre est allumée, à l'image même où elle s'allume et jusqu'à l'image où elle s'éteint (Controllers/UI/HudMask,
-- masque inverse HideScreens). Jamais en poursuite.
-- Correctif f70 (B2) : les écrans de Hide à éteindre sont ceux qu'au moins une grande fenêtre allumée ne garde pas
-- (HudHide.Keep : UI_Displayed garde UI_Hotbar, dont l'InventoryButton le referme). Liste vide : rien à cacher.
local function wantedHide(): { string }
	local list: { string } = {}
	if not HIDE.Enabled then
		return list
	end
	local api = chase
	if api ~= nil and api.IsChased() then
		return list
	end
	local open: { ScreenGui } = {}
	for gui in hideScreens do
		if gui.Enabled and gui.Parent ~= nil then
			table.insert(open, gui)
		end
	end
	if #open == 0 then
		return list
	end
	for _, name in HIDE.Hide do
		for _, gui in open do
			local kept = HIDE_KEEP[gui.Name]
			if kept == nil or not kept[name] then
				table.insert(list, name)
				break
			end
		end
	end
	return list
end

local function updateHide()
	local list = wantedHide()
	local key = table.concat(list, ",")
	if key == hideKey then
		return
	end
	local api = hudMask
	if api == nil or type((api :: any).Push) ~= "function" then
		return
	end
	hideKey = key
	if #list > 0 then
		api.Push(HIDE.MaskKey, { HideScreens = list }) -- remplace le masque d'avant (même clé) si la liste change
	else
		api.Pop(HIDE.MaskKey)
	end
end

local function updateBlur(dt: number?)
	setBlur(wantsBlur())
	updateAway(dt or 0)
	updateHide()
	local anyOpen = false
	for gui in blurScreens do
		if gui.Enabled then
			anyOpen = true
			break
		end
	end
	for gui in awayScreens do
		if gui.Enabled then
			anyOpen = true
			break
		end
	end
	for gui in hideScreens do
		if gui.Enabled then
			anyOpen = true
			break
		end
	end
	-- Heartbeat (poursuite, fermeture par Motion) seulement tant qu'un écran à flou est allumé ou que le flou est là.
	if anyOpen or blur ~= nil then
		if blurStep == nil then
			blurStep = RunService.Heartbeat:Connect(function(dt: number)
				updateBlur(dt)
			end)
		end
	else
		stopBlurStep()
	end
end

local function blursBehind(screen: Instance): boolean
	return BLUR_SCREENS[screen.Name] == true or screen:GetAttribute(BLUR.Attribute) == true
end

------------------------------------------------------------------------------
-- Éléments et écrans
------------------------------------------------------------------------------

local function unwatchObject(object: Instance)
	local list = objects[object]
	if list == nil then
		return
	end
	objects[object] = nil
	for _, connection in list do
		connection:Disconnect()
	end
	Appear.Reset(object)
end

-- Ligne dans la sortie (Studio, une fois par élément) pour une valeur qui n'est pas au contrat.
local function checkValues(object: Instance)
	if not IS_STUDIO or warned[object] then
		return
	end
	for _, def in WATCHED do
		local value = object:GetAttribute(def.name)
		if value ~= nil and not (type(value) == "string" and def.values[value]) then
			warned[object] = true
			print(`[UiMotion] {object:GetFullName()} : {def.name} = « {tostring(value)} » inconnu ({def.list}) : ignoré`)
		end
	end
end

local function hasAnimation(object: Instance): boolean
	for _, def in WATCHED do
		if object:GetAttribute(def.name) ~= nil then
			return true
		end
	end
	return false
end

local function watchObject(inst: Instance, screen: Instance)
	if objects[inst] or inst.Parent == nil or not inst:IsA("GuiObject") or not inst:IsDescendantOf(screen) then
		return
	end
	if not hasAnimation(inst) then
		return
	end
	checkValues(inst)
	if inTemplate(inst) or not Appear.Has(inst) then
		return -- Hover et Press : lus par Motion à chaque survol et appui, rien à suivre ici
	end
	local object = inst :: GuiObject
	local list: { RBXScriptConnection } = {}
	objects[object] = list
	table.insert(list, object:GetPropertyChangedSignal("Visible"):Connect(function()
		if object.Visible then
			if shownInScreen(object) then
				Appear.Play(object)
			end
		else
			Appear.Reset(object)
		end
	end))
	table.insert(list, object.AncestryChanged:Connect(function()
		if object.Parent == nil or not object:IsDescendantOf(screen) then
			unwatchObject(object)
		end
	end))
end

local function unwatchScreen(screen: Instance)
	local list = screens[screen]
	if list == nil then
		return
	end
	screens[screen] = nil
	for _, connection in list do
		connection:Disconnect()
	end
	for object in table.clone(objects) do
		if object:IsDescendantOf(screen) then
			unwatchObject(object)
		end
	end
	Appear.Reset(screen)
	local reveal = scrollReveal
	if reveal ~= nil and screen:IsA("ScreenGui") then
		reveal.Disarm(screen :: ScreenGui)
	end
	if screen:IsA("ScreenGui") then
		blurScreens[screen :: ScreenGui] = nil
		awayScreens[screen :: ScreenGui] = nil
		hideScreens[screen :: ScreenGui] = nil
	end
	updateBlur()
end

local function watchScreen(screen: Instance)
	if screens[screen] or not screen:IsA("ScreenGui") or string.sub(screen.Name, 1, #SCREEN_PREFIX) ~= SCREEN_PREFIX then
		return
	end
	local gui = screen :: ScreenGui
	local list: { RBXScriptConnection } = {}
	screens[gui] = list
	if blursBehind(gui) then
		blurScreens[gui] = true
	end
	if AWAY.Enabled and (AWAY_SCREENS[gui.Name] or gui:GetAttribute(AWAY.Attribute) == true) then
		awayScreens[gui] = true
	end
	if HIDE.Enabled and (HIDE_SCREENS[gui.Name] or gui:GetAttribute(HIDE.Attribute) == true) then
		hideScreens[gui] = true
	end
	table.insert(list, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			Appear.Open(gui)
		else
			Appear.Reset(gui)
		end
		local reveal = scrollReveal
		if reveal ~= nil then
			if gui.Enabled then
				reveal.Arm(gui) -- vague 66 : cartes hors de la zone visible, au défilement
			else
				reveal.Disarm(gui)
			end
		end
		if blurScreens[gui] or awayScreens[gui] or hideScreens[gui] then
			updateBlur()
		end
	end))
	-- Branché à la fin de l'image : une copie renommée juste après son arrivée n'est plus « Template ».
	table.insert(list, gui.DescendantAdded:Connect(function(descendant: Instance)
		task.defer(watchObject, descendant, gui)
	end))
	table.insert(list, gui.AncestryChanged:Connect(function()
		if gui.Parent == nil or gui.Parent ~= localPlayer:FindFirstChildOfClass("PlayerGui") then
			unwatchScreen(gui)
		end
	end))
	for _, descendant in gui:GetDescendants() do
		watchObject(descendant, gui)
	end
	if blurScreens[gui] or awayScreens[gui] or hideScreens[gui] then
		updateBlur()
	end
end

------------------------------------------------------------------------------

function UiMotionController.GetBlur(): { Active: boolean, Size: number, Wanted: boolean }
	local effect = blur
	return {
		Active = effect ~= nil and effect.Parent ~= nil,
		Size = if effect then effect.Size else 0,
		Wanted = blurWanted,
	}
end

function UiMotionController.GetWatchCount(): number
	local n = 0
	for _ in objects do
		n += 1
	end
	return n
end

function UiMotionController.Start()
	chase = sibling("ChaseController")
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(watchScreen)
	for _, child in playerGui:GetChildren() do
		watchScreen(child)
	end
end

return UiMotionController
