--!strict
-- DamageNumberController (DEV-053, client) : chiffres de dégâts flottants (Partie 1, 5.2 et 5.4 :
-- « chiffre de dégâts flottant »). Réglages : Shared/Config/HitFeedback (Damage).
--
-- À chaque coup validé par le serveur, un chiffre (« -4.5 ») jaillit du point de frappe, monte en
-- dérivant un peu sur le côté, puis s'efface. Il vient du serveur, jamais d'une supposition du
-- client : WindowHit(windowId, point, frappeur, dégâts), que WindowService envoie pour chaque coup
-- validé (celui qui casse compris) au frappeur et aux joueurs à moins de
-- Config.Shatter.HitBroadcastRadius studs du point, sur les trois cibles : vitrines des magasins PNJ,
-- portes des boutiques des joueurs (PlotDoor/Window) et cible d'événement (le camion). Un coup refusé
-- par le serveur n'envoie rien, donc n'affiche rien. Celui qui frappe voit son chiffre une latence
-- aller-retour après l'impact de son coup, quand le serveur l'a validé ; son retour immédiat reste
-- le son et les éclats (ShatterController, TruckController).
--
-- Le chiffre : Prefix (« - ») puis les dégâts au format du HUD (Shared/Format.short : 4.5, 12, 1.2K).
-- Ses propres coups en grand ; ceux des autres à OtherScale, et seulement si la caméra est à moins
-- de OtherMaxDistance studs du point. Au plus MaxAlive chiffres à la fois (le plus ancien part). Effets
-- visuels coupés dans les réglages du joueur (VfxEnabled = false, L-095) : plus ceux des autres.
--
-- Modèle de Clément lu par son nom (contrat 2.2) : le BillboardGui Damage.Template (« BB_Damage »,
-- nom proposé) de ReplicatedStorage/Assets/UI ou d'un de ses sous-dossiers, avec un TextLabel
-- Damage.Label (« Label ») : sa taille, son style et sa portée sont gardés ; le code n'écrit que le
-- texte et l'anime (rebond d'apparition par un UIScale, montée par StudsOffsetWorldSpace, puis
-- effacement de ses textes, images, contours et fonds). Tant qu'il manque (ou s'il n'a pas son
-- Label) : un chiffre V0 créé ici, blanc cerclé de sombre, toujours devant le décor, de taille fixe
-- à l'écran (Height pixels) ; une ligne en Studio. Rien n'est posé dans l'interface : le chiffre est
-- dans le monde, au point de frappe (rien en haut de l'écran).
--
-- API (client) : aucune.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HitFeedback = require(Shared:WaitForChild("Config"):WaitForChild("HitFeedback"))
local Settings = require(Shared:WaitForChild("Config"):WaitForChild("Settings"))
local UI = require(Shared:WaitForChild("Contract"):WaitForChild("UI"))
local Format = require(Shared:WaitForChild("Format"))

local Damage = HitFeedback.Damage

local HOLDER_NAME = "DamageNumber" -- Attachment local du Terrain qui porte un chiffre
local V0_NAME = "DamageNumber_V0" -- chiffre du code, tant que le modèle de Clément manque

local IS_STUDIO = RunService:IsStudio()

local player = Players.LocalPlayer
local rng = Random.new()

local DamageNumberController = {}

local v0Template: BillboardGui? = nil
local alive: { Attachment } = {} -- du plus ancien au plus récent
local noticed = false
local warned: { [string]: boolean } = {}

local function warnOnce(message: string)
	if warned[message] then
		return
	end
	warned[message] = true
	warn(`[DamageNumber] {message}`)
end

-- Le modèle de Clément (Assets/UI ou un sous-dossier), s'il a son TextLabel Label ; sinon nil.
local function clementTemplate(): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(Damage.Template, true) else nil
	if found == nil or not found:IsA("BillboardGui") then
		return nil
	end
	local label = found:FindFirstChild(Damage.Label, true)
	if label == nil or not label:IsA("TextLabel") then
		warnOnce(`{Damage.Template} sans TextLabel {Damage.Label} : chiffres de dégâts V0 du code`)
		return nil
	end
	return found :: BillboardGui
end

-- Chiffre V0 du code : blanc cerclé de sombre, taille fixe à l'écran, toujours devant le décor.
local function makeV0(): BillboardGui
	local existing = v0Template
	if existing then
		return existing
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = V0_NAME
	gui.Size = UDim2.fromOffset(Damage.Width, Damage.Height)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = Damage.Label
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Damage.Font
	label.TextScaled = true
	label.TextColor3 = Damage.Color
	label.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Color = Damage.StrokeColor
	stroke.Thickness = Damage.StrokeThickness
	stroke.Parent = label
	label.Parent = gui
	v0Template = gui
	return gui
end

local function template(): BillboardGui
	local own = clementTemplate()
	if own then
		return own
	end
	if IS_STUDIO and not noticed then
		noticed = true
		print(
			`[DamageNumber] {Damage.Template} absent de ReplicatedStorage.{table.concat(UI.BillboardFolder, ".")} : chiffres de dégâts V0 du code`
		)
	end
	return makeV0()
end

-- Efface tout ce qui se voit dans le chiffre : textes, images, contours et fonds.
local function fade(gui: BillboardGui)
	if gui.Parent == nil then
		return
	end
	local info = TweenInfo.new(Damage.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, object in gui:GetDescendants() do
		local goals: { [string]: number }? = nil
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			goals = { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 }
		elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
			goals = { ImageTransparency = 1, BackgroundTransparency = 1 }
		elseif object:IsA("GuiObject") then
			goals = { BackgroundTransparency = 1 }
		elseif object:IsA("UIStroke") then
			goals = { Transparency = 1 }
		end
		if goals then
			TweenService:Create(object, info, goals):Play()
		end
	end
end

-- Garde au plus MaxAlive chiffres : le plus ancien part.
local function remember(holder: Attachment)
	for index = #alive, 1, -1 do
		if alive[index].Parent == nil then
			table.remove(alive, index) -- déjà retiré par Debris
		end
	end
	table.insert(alive, holder)
	while #alive > Damage.MaxAlive do
		local oldest = table.remove(alive, 1)
		if oldest then
			oldest:Destroy()
		end
	end
end

local function show(point: Vector3, damage: number, mine: boolean)
	local camera = Workspace.CurrentCamera
	if not mine and camera and (camera.CFrame.Position - point).Magnitude > Damage.OtherMaxDistance then
		return
	end
	if not mine and Settings.VfxReduced(player) then
		return -- effets visuels coupés (réglages du joueur, L-095) : seulement ses propres chiffres
	end
	local gui = template():Clone()
	local found = gui:FindFirstChild(Damage.Label, true)
	if found == nil or not found:IsA("TextLabel") then
		gui:Destroy() -- ne se produit pas : les deux modèles ont leur Label
		return
	end
	local label = found :: TextLabel
	label.Text = Damage.Prefix .. Format.short(damage)
	local holder = Instance.new("Attachment")
	holder.Name = HOLDER_NAME
	holder.Position = point + Vector3.new(0, Damage.Lift, 0) -- Terrain au centre du monde : position = monde
	gui.Adornee = holder
	gui.Parent = holder
	-- Rebond d'apparition : un UIScale sur le texte (celui du modèle s'il en a un, sa valeur gardée).
	local existing = label:FindFirstChildOfClass("UIScale")
	local scale: UIScale = existing or Instance.new("UIScale")
	local full = scale.Scale * (if mine then 1 else Damage.OtherScale)
	scale.Scale = full * Damage.PopFrom
	scale.Parent = label
	holder.Parent = Workspace.Terrain
	TweenService:Create(
		scale,
		TweenInfo.new(Damage.PopTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = full }
	):Play()
	-- Il jaillit : vite au début, puis ralentit, en dérivant sur le côté vu de la caméra.
	local side = if camera then camera.CFrame.RightVector else Vector3.xAxis
	local offset = side * rng:NextNumber(-Damage.Drift, Damage.Drift) + Vector3.new(0, Damage.Rise, 0)
	TweenService:Create(
		gui,
		TweenInfo.new(Damage.Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + offset }
	):Play()
	task.delay(math.max(Damage.Lifetime - Damage.FadeTime, 0), fade, gui)
	Debris:AddItem(holder, Damage.Lifetime + 0.1)
	remember(holder)
end

function DamageNumberController.Start()
	local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	Net.Client.WindowHit:Connect(function(_windowId: string, point: Vector3, hitter: Player?, damage: number?)
		if typeof(point) ~= "Vector3" or type(damage) ~= "number" or damage ~= damage or damage <= 0 then
			return -- message sans dégâts (ou dégâts nuls, invalides) : pas de chiffre
		end
		xpcall(show, function(err: any)
			warnOnce(tostring(err))
		end, point, damage, hitter == player)
	end)
end

return DamageNumberController
