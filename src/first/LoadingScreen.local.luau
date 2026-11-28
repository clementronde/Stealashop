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
--
-- a532 (Cantin, 28/11) : vrai écran de chargement, derrière Features.LoadingReal / LoadingRealDev. Le choix se fait
-- dès que ReplicatedStorage/Shared est là (sans Shared une fois le jeu chargé : l'ancien déroulé) ; jusque-là,
-- l'ancien déroulé tourne, sans fermer à 100 %. Allumé : LoadingFlow (même dossier) suit les vraies étapes (jeu,
-- profil, personnage, écrans principaux, zone streamée, file de PreloadAsync), la barre et Root.Step (ou, sans lui,
-- un texte après le pourcentage) les suivent ; les contrôles du joueur sont coupés jusqu'à la fermeture ; fermeture
-- à 100 %, au Skip (le chargement continue derrière) ou au plus tard après LoadingConfig.MaxWait s (une ligne dans
-- la sortie avec les étapes pas finies). Éteint : le déroulé d'a187, inchangé.
-- À chaque fermeture (et sans UI_Loading ni Root), l'attribut LoadingDone (LoadingConfig.DoneAttribute) passe à true
-- sur le Player : Shared/LoadingGate le lit pour le tuto et les gains hors ligne.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local scriptFolder = script.Parent :: Instance
local configModule = scriptFolder:WaitForChild("LoadingConfig") :: ModuleScript
local Config = require(configModule) :: any

local player = Players.LocalPlayer
-- a532 : le jeu peut commencer (lu par Shared/LoadingGate) ; pcall : rien ne doit bloquer ce script.
local function markDone()
	pcall(function()
		player:SetAttribute(Config.DoneAttribute, true)
	end)
end

local template = ReplicatedFirst:WaitForChild(Config.ScreenName, Config.ScreenWait)
if template == nil or not template:IsA("ScreenGui") then
	markDone()
	return
end

local playerGui = player:WaitForChild("PlayerGui")
local screen = template:Clone()
local root = screen:FindFirstChild("Root")
if root == nil or not root:IsA("GuiObject") then
	screen:Destroy()
	markDone()
	return
end
local bar = root:FindFirstChild("Bar")
local fillFound = if bar then bar:FindFirstChild("Fill") else nil
local percentFound = if bar then bar:FindFirstChild("Percent") else nil
local tipFound = root:FindFirstChild("Tip")
local skipFound = root:FindFirstChild("SkipButton")
local stepFound = root:FindFirstChild("Step") -- a532 : texte de l'étape en cours, facultatif (demandé à Clément)
local fill: GuiObject? = if fillFound and fillFound:IsA("GuiObject") then fillFound else nil
local percent: TextLabel? = if percentFound and percentFound:IsA("TextLabel") then percentFound else nil
local tip: TextLabel? = if tipFound and tipFound:IsA("TextLabel") then tipFound else nil
local skip: GuiButton? = if skipFound and skipFound:IsA("GuiButton") then skipFound else nil
local stepLabel: TextLabel? = if stepFound and stepFound:IsA("TextLabel") then stepFound else nil

local closed = false
local closing = false -- 100 % atteint : fermeture programmée
local progress = 0
local random = Random.new()
local startedAt = os.clock()
-- a532 : "pending" tant que l'interrupteur n'est pas lu, puis "old" (déroulé d'a187) ou "real" (LoadingFlow).
local mode: string = "pending"
local pendingClose = false -- l'ancien déroulé a fini pendant "pending" : fermer s'il est choisi
local stepText: string? = nil -- a532 : étape en cours (vrai déroulé seulement)
local controls: any = nil -- a532 : contrôles du joueur coupés pendant le vrai déroulé

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
	local shown = stepText
	if stepLabel then
		if shown ~= nil then
			stepLabel.Text = shown
		end
		shown = nil -- Root.Step de Clément : le pourcentage reste seul
	end
	if percent then
		percent.Text = math.floor(p * 100) .. "%" .. (if shown ~= nil then " · " .. shown else "")
	end
end

-- Fermeture : fondu de tout l'écran, puis Destroy -----------------------------------------------------
local function close()
	if closed then
		return
	end
	closed = true
	markDone()
	local held = controls
	controls = nil
	if held ~= nil then
		pcall(function()
			held:Enable()
		end)
	end
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
		if mode == "pending" then
			pendingClose = true -- a532 : on attend le choix du déroulé
			return
		end
		closing = true
		task.delay(Config.BarTweenTime, close) -- la barre finit de se remplir avant le fondu
	end
end

-- Ancien déroulé (a187) : ses avancées sont ignorées une fois le vrai déroulé choisi.
-- Vrai déroulé choisi (fonction : le solveur ne fige pas `mode` après un premier test).
local function isReal(): boolean
	return mode == "real"
end

local function setOldProgress(p: number)
	if mode ~= "real" then
		setProgress(p)
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

-- Un objet par image, animation (ou son, vrai déroulé) des dossiers donnés, depuis ReplicatedStorage.
local function contentOf(inst: Instance): string?
	if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		return inst.Image
	elseif inst:IsA("Decal") then -- Texture compris (sous-classe de Decal)
		return inst.Texture
	elseif inst:IsA("Animation") then
		return inst.AnimationId
	elseif inst:IsA("Sound") then
		return inst.SoundId
	end
	return nil
end
local function collect(paths: { { string } }, classList: { string }): { Instance }
	local classes: { [string]: boolean } = {}
	for _, class in classList do
		classes[class] = true
	end
	local assets: { Instance } = {}
	local seen: { [string]: boolean } = {}
	for _, path in paths do
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
	return assets
end

local function preload(list: { Instance })
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end

-- a532 : vrai déroulé ------------------------------------------------------------------------------------
local function joined(a: { any }, b: { any }): { any }
	local out = table.clone(a)
	for _, v in b do
		table.insert(out, v)
	end
	return out
end

local function holdControls()
	task.spawn(function()
		local ok, found = pcall(function(): any
			local scripts = player:WaitForChild("PlayerScripts", 10)
			local module = if scripts then scripts:WaitForChild("PlayerModule", 10) else nil
			if module == nil then
				return nil
			end
			local okModule, playerModule = pcall(require, module :: any)
			return if okModule then (playerModule :: any):GetControls() else nil
		end)
		if ok and found ~= nil and not closed then
			controls = found
			pcall(function()
				found:Disable()
			end)
		end
	end)
end

local function startReal()
	local flowModule = scriptFolder:FindFirstChild("LoadingFlow")
	local okFlow, LoadingFlow = pcall(require, flowModule :: any)
	if not okFlow or type(LoadingFlow) ~= "table" then
		warn(`[LoadingScreen] LoadingFlow introuvable ou en erreur : écran fermé ({LoadingFlow})`)
		close()
		return
	end
	holdControls()
	local StarterGui = game:GetService("StarterGui")
	local Workspace = game:GetService("Workspace")
	local function rootPart(): BasePart?
		local character = player.Character
		local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
		return if part and part:IsA("BasePart") then part else nil
	end
	local deps = {
		now = os.clock,
		wait = function(seconds: number)
			task.wait(seconds)
		end,
		spawn = function(fn: () -> ())
			task.spawn(fn)
		end,
		gameLoaded = function(): boolean
			return game:IsLoaded()
		end,
		profileReady = function(): boolean
			return player:GetAttribute(Config.ProfileAttribute) == true
		end,
		characterReady = function(): boolean
			return rootPart() ~= nil
		end,
		screens = function(): { Instance }?
			if rootPart() == nil then
				return nil -- les écrans arrivent avec le personnage
			end
			local found: { Instance } = {}
			for _, name in Config.Screens do
				local copy = playerGui:FindFirstChild(name)
				if copy then
					table.insert(found, copy)
				elseif StarterGui:FindFirstChild(name) then
					return nil -- attendu (il est dans StarterGui), pas encore copié
				end
			end
			return found
		end,
		streaming = function(): boolean
			return (Workspace :: any).StreamingEnabled == true
		end,
		streamAround = function()
			local part = rootPart()
			if part then
				local left = math.max(1, Config.MaxWait - (os.clock() - startedAt))
				player:RequestStreamAroundAsync(part.Position, left)
			end
		end,
		assets = function(): { Instance }
			return collect(joined(Config.Preload, Config.RealPreload), joined(Config.PreloadClasses, Config.RealPreloadClasses))
		end,
		preload = preload,
	}
	task.spawn(function()
		local result = LoadingFlow.Run(Config, deps, function(p: number, step: string?)
			stepText = if step then Config.StepText[step] else nil
			setProgress(p)
		end, startedAt)
		if not result.Done then
			warn(
				`[LoadingScreen] chargement pas fini après {Config.MaxWait} s, entrée dans le jeu quand même ; étapes pas finies : {table.concat(result.Missing, ", ")}`
			)
			close()
		end
	end)
end

-- Lecture de l'interrupteur, dès que Shared est là.
local function readSwitch(shared: Instance): boolean
	local ok, on = pcall(function(): boolean
		local config = shared:WaitForChild("Config", 5)
		local featuresModule = if config then config:WaitForChild("Features", 5) else nil
		if config == nil or featuresModule == nil then
			return false
		end
		local Features = require(featuresModule :: any) :: any
		local isDev = false
		local ids = config:FindFirstChild("ProductIds")
		if ids then
			local okIds, result = pcall(require, ids :: any)
			isDev = okIds and type(result) == "table" and (result :: any).IsDev == true
		end
		return Features.LoadingReal == true or (Features.LoadingRealDev == true and isDev)
	end)
	return ok and on == true
end

local function choose(real: boolean)
	if mode ~= "pending" then
		return
	end
	mode = if real then "real" else "old"
	if closed then
		return
	end
	if real then
		startReal()
	elseif pendingClose and not closing then
		closing = true
		task.delay(Config.BarTweenTime, close)
	end
end

local function decide()
	if mode ~= "pending" or closed then
		return
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if shared then
		task.spawn(function()
			choose(readSwitch(shared))
		end)
	elseif game:IsLoaded() then
		choose(false) -- tout est arrivé, sans Shared : l'ancien déroulé
	else
		task.delay(Config.CheckInterval, decide)
	end
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
task.delay(Config.MaxDuration, function()
	if mode ~= "real" then
		close()
	end
end)
decide()

-- 2. Le vrai chargement (déroulé d'a187 ; arrêté si le vrai déroulé est choisi) ---------------------------
local weights = Config.Weights

preload({ screen })
setOldProgress(weights.Screen)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
if isReal() then
	return
end
setOldProgress(weights.Screen + weights.Game)

local assets = collect(Config.Preload, Config.PreloadClasses)
local base = weights.Screen + weights.Game
local size = math.max(1, Config.BatchSize)
for first = 1, #assets, size do
	if isReal() then
		return
	end
	local batch: { Instance } = {}
	for i = first, math.min(first + size - 1, #assets) do
		table.insert(batch, assets[i])
	end
	preload(batch)
	setOldProgress(base + weights.Assets * math.min(first + size - 1, #assets) / #assets)
end
setOldProgress(1)
