--!strict
-- ChaseFeelController (client) : l'ambiance de la poursuite voulue par Clément (liaison L-095 ;
-- docs/claude/notes/ui-feel2-horsligne-poursuite-barre.md, « Pour Ironix », point « Poursuite » ;
-- valeurs : Config/ChaseFeel, reprises de la note et du prototype tools/clement/feel2_proto.luau).
--
-- Suit ChaseController (IsChased, GetGuard, d'après le remote ChaseState de GuardService) à chaque image :
--   1. au départ, espacés (vague 24) : Heist_Grab, Chase_Whistle WhistleDelay s après (sons 2D, chez ce
--      joueur seulement ; plus de Chase_Siren, retirée à la demande de Clément, L-117 point 5). MUS_Chase et
--      la musique de zone baissée : MusicController (fondu enchaîné), qui fait monter MUS_Chase
--      ChaseFeel.MusicDelay s après le départ, de ChaseFeel.MusicStartAt ;
--   2. bulle du vigile : une copie de ReplicatedStorage/Assets/UI/BB_GuardShout posée sur la tête du
--      vigile qui poursuit le joueur local (Adornee, rangée dans le PlayerGui : personne d'autre ne la
--      voit). Une phrase (Lines) toutes les ShoutEvery s : Bubble, Tail et Bang (vague 24 : ensemble,
--      chacun par son UIScale) grossissent de 0 à 1 (Back ; Bang 0 → 1,35 → 1 et tremble), restent
--      ShoutHold s, rapetissent, puis sont cachés (Visible = false) jusqu'à la phrase suivante ;
--      Guard_Radio une phrase sur RadioEvery. Vigile pas encore là (streaming) : la bulle arrive avec
--      lui ; vigile disparu : la bulle s'en va et revient avec lui ;
--   3. vague 59 (a192, L-182 point 9) : tout le HUD masqué pendant la poursuite sauf UI_Chase (« RUN! », les bords),
--      UI_HUD.HeistTimer (Config/HeistFeel.ChaseMask, par Controllers/UI/HudMask : écrans
--      Enabled, éléments Visible, revus toutes les HeistFeel.MaskRefresh s), puis rendu tel qu'il était. Avant :
--      seulement LeftRail, LeftRailTouch et UI_Hotbar (ChaseFeel.Rails, Hotbar et BarsRefresh ne sont plus lus) ;
--   4. vague 59 : le vigile qui poursuit le joueur passe en rouge, un Highlight (HeistFeel.Highlight) posé par ce
--      client dans le modèle du vigile, que lui seul voit ; il part avec la bulle.
-- À la fin de la poursuite (fin, capture, mort, renvoi : ChaseState(false)) : bulle et Highlight détruits, le HUD
-- revient. Un son ou BB_GuardShout absent : rien (une ligne en Studio, une fois).
-- Rien n'est envoyé au serveur. Ne touche ni aux écrans de StarterGui ni aux modèles de Clément.
--
-- API (client, pour un test dans Studio) :
--   ChaseFeelController.GetState() -> { Active, Bubble, Shouts }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChaseFeel = require(Shared:WaitForChild("Config"):WaitForChild("ChaseFeel"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
local HeistFeel = require(Shared:WaitForChild("Config"):WaitForChild("HeistFeel"))
local HudMask = require(script.Parent:WaitForChild("UI"):WaitForChild("HudMask"))

-- Ce que ce contrôleur utilise de ChaseController.
type ChaseApi = {
	IsChased: () -> boolean,
	GetGuard: () -> Model?,
}

export type State = {
	Active: boolean,
	Bubble: BillboardGui?,
	Shouts: number, -- phrases dites par la bulle actuelle
}

local IS_STUDIO = RunService:IsStudio()

local ChaseFeelController = {}

local localPlayer = Players.LocalPlayer
local chase: ChaseApi? = nil
local active = false
local chaseToken = 0
local bubble: BillboardGui? = nil
local bubbleToken = 0
local shouts = 0
local lastLine = 0
local highlight: Highlight? = nil -- vague 59 : le vigile qui poursuit, en rouge
local MASK_KEY = "Chase" -- vague 59 : masque du HUD (Controllers/UI/HudMask)
local said: { [string]: boolean } = {}
local rng = Random.new()

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		print(`[ChaseFeel] {message}`)
	end
end

local function tween(instance: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(instance, info, goal):Play()
end

-- Sons ------------------------------------------------------------------------------------------------

local function soundTemplate(name: string): Sound?
	local template = MarkerSounds.find(name)
	if template == nil then
		sayOnce(`sound:{name}`, `son « {name} » absent de ReplicatedStorage.Assets.Sounds : pas joué (L-095)`)
	end
	return template
end

-- Son joué une fois, en 2D.
local function playOnce(name: string)
	local template = soundTemplate(name)
	if template then
		MarkerSounds.playSound(template, nil)
	end
end


-- Bulle du vigile ----------------------------------------------------------------------------------------

local function scaleOf(object: GuiObject): UIScale
	local found = object:FindFirstChildOfClass("UIScale")
	if found then
		return found
	end
	local scale = Instance.new("UIScale")
	scale.Parent = object
	return scale
end

local function guiChild(parent: Instance, name: string): GuiObject?
	local found = parent:FindFirstChild(name, true)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function shoutTemplate(): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, segment in ChaseFeel.ShoutFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(ChaseFeel.ShoutTemplate) else nil
	if found and found:IsA("BillboardGui") then
		return found :: BillboardGui
	end
	sayOnce("bubble", `{ChaseFeel.ShoutTemplate} absent de ReplicatedStorage.Assets.UI : pas de bulle sur le vigile (L-095)`)
	return nil
end

-- Où poser la bulle : la tête du vigile, sinon sa pièce principale.
local function headOf(guard: Model): BasePart?
	local head = guard:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head :: BasePart
	end
	local root = guard:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root :: BasePart
	end
	return guard.PrimaryPart
end

local function nextLine(): string
	local lines = ChaseFeel.Lines
	local index = rng:NextInteger(1, #lines)
	if index == lastLine and #lines > 1 then
		index = index % #lines + 1
	end
	lastLine = index
	return lines[index]
end

local function destroyBubble()
	bubbleToken += 1
	local gui = bubble
	bubble = nil
	if gui then
		gui:Destroy()
	end
end

local function clearHighlight()
	local mark = highlight
	highlight = nil
	if mark then
		mark:Destroy()
	end
end

-- Vague 59 (L-182 point 9) : Highlight rouge dans le modèle du vigile qui poursuit, côté client seulement ; il
-- suit le vigile (streaming, changement de vigile) indépendamment de la bulle.
local function markGuard(guard: Model?)
	local current = highlight
	if current and guard and current.Parent == guard and current.Adornee == guard then
		return
	end
	clearHighlight()
	if guard == nil or not guard:IsDescendantOf(Workspace) then
		return
	end
	local spec = HeistFeel.Highlight
	local mark = Instance.new("Highlight")
	mark.Name = spec.Name
	mark.FillColor = spec.FillColor
	mark.FillTransparency = spec.FillTransparency
	mark.OutlineColor = spec.OutlineColor
	mark.OutlineTransparency = spec.OutlineTransparency
	mark.Adornee = guard
	mark.Parent = guard
	highlight = mark
end

-- Morceaux de la bulle qui apparaissent et disparaissent ensemble (vague 24 : avant, Tail ou Bang
-- restaient affichés quand Bubble s'en allait).
local PARTS = { "Bubble", "Tail", "Bang" }

local function partsOf(gui: BillboardGui): { GuiObject }
	local out: { GuiObject } = {}
	for _, name in PARTS do
		local part = guiChild(gui, name)
		if part then
			table.insert(out, part)
		end
	end
	return out
end

-- Bulle fermée : chaque morceau à l'échelle 0 et caché.
local function closeParts(parts: { GuiObject })
	for _, part in parts do
		scaleOf(part).Scale = 0
		part.Visible = false
	end
end

-- « ! » : 0 → PopScale (Back), puis 1, et il tremble.
local function popBang(bang: GuiObject, token: number)
	local spec = ChaseFeel.Bang
	local bangScale = scaleOf(bang)
	bang.Rotation = 0
	tween(bangScale, spec.PopTime, { Scale = spec.PopScale }, Enum.EasingStyle.Back)
	task.delay(spec.PopTime, function()
		if token == bubbleToken then
			tween(bangScale, spec.SettleTime, { Scale = 1 })
		end
	end)
	for i, angle in spec.ShakeAngles do
		task.delay(spec.ShakeStart + i * spec.ShakeStep, function()
			if token == bubbleToken then
				bang.Rotation = angle
			end
		end)
	end
end

-- Une phrase : Bubble, Tail et Bang grossissent, restent, puis rapetissent et sont cachés, ensemble.
local function shout(gui: BillboardGui, token: number)
	local parts = partsOf(gui)
	if #parts == 0 then
		return
	end
	shouts += 1
	local label = gui:FindFirstChild("ShoutLabel", true)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		(label :: TextLabel).Text = nextLine()
	end
	for _, part in parts do
		part.Visible = true
		scaleOf(part).Scale = 0
		if part.Name == "Bang" then
			popBang(part, token)
		else
			tween(scaleOf(part), ChaseFeel.ShoutInTime, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	if (shouts - 1) % ChaseFeel.RadioEvery == 0 then
		playOnce(ChaseFeel.Sounds.Radio)
	end
	local shoutNumber = shouts
	task.delay(ChaseFeel.ShoutHold, function()
		if token ~= bubbleToken or shoutNumber ~= shouts then
			return
		end
		for _, part in parts do
			tween(scaleOf(part), ChaseFeel.ShoutOutTime, { Scale = 0 })
		end
		task.delay(ChaseFeel.ShoutOutTime, function()
			if token == bubbleToken and shoutNumber == shouts then
				closeParts(parts)
			end
		end)
	end)
end

local function createBubble(guard: Model)
	local template = shoutTemplate()
	local head = headOf(guard)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if template == nil or head == nil or playerGui == nil then
		return
	end
	destroyBubble()
	local token = bubbleToken
	local gui = template:Clone()
	gui.Adornee = head
	gui.Parent = playerGui
	bubble = gui
	shouts = 0
	-- Fermée jusqu'à la première phrase : rien n'est visible.
	closeParts(partsOf(gui))
	-- Les phrases, tant que cette bulle vit.
	task.delay(ChaseFeel.FirstShoutDelay, function()
		while token == bubbleToken do
			shout(gui, token)
			task.wait(ChaseFeel.ShoutEvery)
		end
	end)
end

-- Bulle sur le vigile qui poursuit le joueur local, s'il est là ; partie avec lui sinon.
local function updateBubble(api: ChaseApi)
	markGuard(api.GetGuard())
	local current = bubble
	if current then
		local adornee = current.Adornee
		if current.Parent and adornee and adornee:IsDescendantOf(Workspace) then
			return
		end
		destroyBubble()
	end
	local guard = api.GetGuard()
	if guard and guard:IsDescendantOf(Workspace) then
		createBubble(guard)
	end
end

-- HUD masqué (vague 59, L-182 point 9) -----------------------------------------------------------------------

local function maskHud()
	local spec = HeistFeel.ChaseMask
	HudMask.Push(MASK_KEY, {
		KeepScreens = spec.KeepScreens,
		Partial = { [spec.Hud] = spec.KeepHud },
	})
end

-- Départ et fin ----------------------------------------------------------------------------------------------

local function begin()
	active = true
	chaseToken += 1
	local token = chaseToken
	playOnce(ChaseFeel.Sounds.Grab)
	task.delay(ChaseFeel.WhistleDelay, function()
		if token == chaseToken and active then
			playOnce(ChaseFeel.Sounds.Whistle)
		end
	end)
	maskHud()
end

local function finish()
	active = false
	chaseToken += 1
	destroyBubble()
	clearHighlight()
	HudMask.Pop(MASK_KEY)
end

local function step(dt: number)
	local api = chase
	if api == nil then
		return
	end
	local chased = api.IsChased()
	if chased and not active then
		begin()
	elseif not chased and active then
		finish()
	end
	if not active then
		return
	end
	updateBubble(api)
end

-- API -------------------------------------------------------------------------------------------------

function ChaseFeelController.GetState(): State
	return { Active = active, Bubble = bubble, Shouts = shouts }
end

local function loadChase(): ChaseApi?
	local module = script.Parent:FindFirstChild("ChaseController")
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" and type((result :: any).IsChased) == "function" then
		return result :: any
	end
	return nil
end

function ChaseFeelController.Start()
	chase = loadChase()
	if chase == nil then
		sayOnce("chase", "ChaseController introuvable : pas d'ambiance de poursuite")
		return
	end
	RunService.Heartbeat:Connect(function(dt: number)
		xpcall(step, function(err: any)
			sayOnce(`error:{err}`, tostring(err))
		end, dt)
	end)
end

return ChaseFeelController
