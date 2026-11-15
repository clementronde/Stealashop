--!strict
-- LoadingScreen (LocalScript de ReplicatedFirst, liaison L-177, vague 58, a187) : l'écran de chargement de Clément,
-- ReplicatedFirst/UI_Loading (ScreenGui, DisplayOrder 1000, ResetOnSpawn faux, aucun script dedans).
--
-- Déroulé :
--   1. clone de UI_Loading dans le PlayerGui, puis ReplicatedFirst:RemoveDefaultLoadingScreen() ;
--   2. PreloadAsync du clone (illustration et logo tout de suite), puis game:IsLoaded(), puis préchargement en lots
--      des dossiers de LoadingConfig.Preload ; la barre suit ce vrai chargement (Root.Bar.Fill.Size, tween court,
--      Root.Bar.Percent.Text), jamais un minuteur ;
--   3. Root.Tip : une astuce au hasard toutes les 4 à 5 s, derrière le début « TIP: » de Clément ;
--   4. Root.SkipButton caché, visible après 5 s ; un clic ferme l'écran (le préchargement continue derrière) ;
--      fermeture à 100 % et au plus tard après 20 s ;
--   5. fondu de 0,4 s de tout l'écran (fonds, images, textes, UIStroke), puis Destroy() : le HUD, dessous, se voit.
-- Sans UI_Loading, ce script ne fait rien (écran Roblox par défaut). Un élément absent de l'écran est sauté.
-- Ne dépend pas de ReplicatedStorage/Shared (pas encore arrivé quand ce script tourne) : réglages dans LoadingConfig.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local scriptFolder = script.Parent :: Instance
local configModule = scriptFolder:WaitForChild("LoadingConfig") :: ModuleScript
local Config = require(configModule) :: any

local template = ReplicatedFirst:WaitForChild(Config.ScreenName, Config.ScreenWait)
if template == nil or not template:IsA("ScreenGui") then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screen = template:Clone()
local root = screen:FindFirstChild("Root")
if root == nil or not root:IsA("GuiObject") then
	screen:Destroy()
	return
end
local bar = root:FindFirstChild("Bar")
local fillFound = if bar then bar:FindFirstChild("Fill") else nil
local percentFound = if bar then bar:FindFirstChild("Percent") else nil
local tipFound = root:FindFirstChild("Tip")
local skipFound = root:FindFirstChild("SkipButton")
local fill: GuiObject? = if fillFound and fillFound:IsA("GuiObject") then fillFound else nil
local percent: TextLabel? = if percentFound and percentFound:IsA("TextLabel") then percentFound else nil
local tip: TextLabel? = if tipFound and tipFound:IsA("TextLabel") then tipFound else nil
local skip: GuiButton? = if skipFound and skipFound:IsA("GuiButton") then skipFound else nil

local closed = false
local closing = false -- 100 % atteint : fermeture programmée
local progress = 0
local random = Random.new()

-- Barre ---------------------------------------------------------------------------------------------
local function showProgress(p: number)
	if closed then
		return
	end
	if fill then
		TweenService:Create(
			fill,
			TweenInfo.new(Config.BarTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(p, 1) }
		):Play()
	end
	if percent then
		percent.Text = math.floor(p * 100) .. "%"
	end
end

-- Fermeture : fondu de tout l'écran, puis Destroy -----------------------------------------------------
local function close()
	if closed then
		return
	end
	closed = true
	if skip then
		skip.Active = false
	end
	local info = TweenInfo.new(Config.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local targets: { Instance } = root:GetDescendants()
	table.insert(targets, root)
	for _, inst in targets do
		local goal: { [string]: any } = {}
		if inst:IsA("UIStroke") then
			goal.Transparency = 1
		elseif inst:IsA("GuiObject") then
			goal.BackgroundTransparency = 1
			if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
				goal.ImageTransparency = 1
			end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				goal.TextTransparency = 1
			end
		end
		if next(goal) ~= nil then
			TweenService:Create(inst, info, goal):Play()
		end
	end
	task.delay(Config.FadeTime, function()
		screen:Destroy()
	end)
end

local function setProgress(p: number)
	progress = math.clamp(p, progress, 1)
	showProgress(progress)
	if progress >= 1 and not closing then
		closing = true
		task.delay(Config.BarTweenTime, close) -- la barre finit de se remplir avant le fondu
	end
end

-- Astuces ---------------------------------------------------------------------------------------------
local prefix: string = Config.TipPrefix
if tip then
	local found = string.match(tip.Text, "^(.-</font>%s*)")
	if found then
		prefix = found -- le début de Clément, sa couleur comprise
	end
end
local tips: { string } = Config.Tips
local lastTip = 0
local function nextTip()
	local label = tip
	if closed or label == nil or #tips == 0 then
		return
	end
	local index = random:NextInteger(1, #tips)
	if #tips > 1 and index == lastTip then
		index = index % #tips + 1 -- jamais deux fois la même de suite
	end
	lastTip = index
	label.Text = prefix .. tips[index]
	task.delay(random:NextNumber(Config.TipIntervalMin, Config.TipIntervalMax), nextTip)
end

-- 1. L'écran, à la place de celui de Roblox -------------------------------------------------------------
if fill then
	fill.Size = UDim2.fromScale(0, 1)
end
if percent then
	percent.Text = "0%"
end
local skipButton = skip
if skipButton then
	skipButton.Visible = false
	skipButton.Activated:Connect(close)
	task.delay(Config.SkipDelay, function()
		if not closed then
			skipButton.Visible = true
		end
	end)
end
nextTip()
screen.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()
task.delay(Config.MaxDuration, close)

-- 2. Le vrai chargement ----------------------------------------------------------------------------------
local weights = Config.Weights
local function preload(list: { Instance })
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end

preload({ screen })
setProgress(weights.Screen)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
setProgress(weights.Screen + weights.Game)

-- Un objet par image ou animation des dossiers de Config.Preload.
local classes: { [string]: boolean } = {}
for _, class in Config.PreloadClasses do
	classes[class] = true
end
local function contentOf(inst: Instance): string?
	if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		return inst.Image
	elseif inst:IsA("Decal") then -- Texture compris (sous-classe de Decal)
		return inst.Texture
	elseif inst:IsA("Animation") then
		return inst.AnimationId
	end
	return nil
end
local assets: { Instance } = {}
local seen: { [string]: boolean } = {}
for _, path in Config.Preload do
	local folder: Instance? = ReplicatedStorage
	for _, name in path do
		folder = if folder then folder:FindFirstChild(name) else nil
	end
	if folder then
		for _, inst in folder:GetDescendants() do
			local content = if classes[inst.ClassName] then contentOf(inst) else nil
			if content and content ~= "" and content ~= "rbxassetid://0" and not seen[content] then
				seen[content] = true
				table.insert(assets, inst)
			end
		end
	end
end

local base = weights.Screen + weights.Game
local size = math.max(1, Config.BatchSize)
for first = 1, #assets, size do
	local batch: { Instance } = {}
	for i = first, math.min(first + size - 1, #assets) do
		table.insert(batch, assets[i])
	end
	preload(batch)
	setProgress(base + weights.Assets * math.min(first + size - 1, #assets) / #assets)
end
setProgress(1)
