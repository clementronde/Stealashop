--!strict
-- HitController (client) : coups sur les vitrines avec l'outil de casse (Partie 1, 5.2 et 9.4).
--
-- Quand le joueur active son outil de casse (clic ou tap : Tool.Activated), le contrôleur
-- vise la vitrine cassable la plus proche devant lui, à portée (Balance.Hit.Range, 8 studs),
-- et envoie HitWindow(windowId) au serveur, au plus 10 coups par seconde
-- (Balance.Hit.MaxHitsPerSecond). Il joue tout de suite l'animation du coup (5.2), même dans
-- le vide : HitWindow, ou HitWindowHeavy du Marteau à la Disqueuse (2.4, champ HitAnimation
-- de Config.Tools), via AnimationController s'il est là. Sur une vitrine, il passe aussi le
-- coup à ShatterController.LocalHit (retour local : mini-éclats, son de verre, léger
-- tremblement, au marqueur Impact de l'animation). Le serveur valide, applique les PV et les
-- renvoie à tous (WindowService).
--
-- Moment du coup (vague 8, 2026-11-07) : la vitrine visée est choisie au clic, mais HitWindow
-- part quand le coup touche, au marqueur Impact de l'animation (2.4 ; 0,133 s pour HitWindow,
-- 0,233 s pour HitWindowHeavy chez Clément), comme le retour local de ShatterController :
--   - animation pas livrée (ou AnimationController absent) : HitWindow part au clic, comme avant ;
--   - marqueur pas arrivé après Config.Shatter.Hit.ImpactMaxWait (0,3 s, le délai du retour
--     local) : le coup part quand même ;
--   - clic suivant avant le marqueur : le coup en attente part tout de suite, avant que
--     l'animation reparte du début (elle repart à chaque clic : son marqueur ne viendrait plus).
-- Un clic donne au plus un coup : un seul coup en attente à la fois, envoyé une seule fois par le
-- premier de ces trois moments. Les envois suivent l'ordre et le rythme des clics (à une image
-- près) : le débit vu par le serveur (10 coups/s au plus, Net) ne change pas. Au moment d'envoyer,
-- l'outil doit être encore en main et le personnage vivant, sinon le coup est abandonné (le
-- serveur l'aurait refusé). WindowService ne change pas : il mesure la portée à la réception,
-- donc au moment où le coup touche.
--
-- Lu sur les objets (rien n'est cherché par chemin) :
--   Tool de casse : attribut ToolId (ToolService) ;
--   vitrine `Window` des modèles taggés NPCStore et PlayerPlot : WindowId, MaxHP, Broken
--   (WindowService) ; parcelle : OwnerUserId (PlotService).
-- Pas d'API pour l'instant.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Shatter = require(Config:WaitForChild("Shatter"))
local Tools = require(Config:WaitForChild("Tools"))

-- Ce que ce contrôleur utilise d'AnimationController (a09).
type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
}

-- Ce que ce contrôleur utilise de ShatterController (a16, DEV-016).
type ShatterApi = {
	LocalHit: (windowId: string, point: Vector3, track: AnimationTrack?) -> (),
}

local TOOL_ID_ATTRIBUTE = "ToolId" -- posé par ToolService sur le Tool de casse
local WINDOW_NAME = "Window" -- enfant obligatoire (10.4)
local WINDOW_ID_ATTRIBUTE = "WindowId" -- posés par WindowService sur la vitrine
local MAX_HP_ATTRIBUTE = "MaxHP"
local BROKEN_ATTRIBUTE = "Broken"
local OWNER_ATTRIBUTE = "OwnerUserId" -- posé par PlotService sur la parcelle
local PLOT_TAG = "PlayerPlot"
local WINDOW_TAGS = { "NPCStore", PLOT_TAG } -- contrat 2.1
local DEFAULT_ANIMATION = "HitWindow"
local IMPACT_MARKER = "Impact" -- marqueur de HitWindow et HitWindowHeavy (2.4)

local MIN_INTERVAL = 1 / Balance.Hit.MaxHitsPerSecond
-- Attente max du marqueur Impact : la même que le retour local (ShatterController), pour que le
-- coup et ses mini-éclats partent ensemble même sans marqueur.
local IMPACT_MAX_WAIT: number = Shatter.Hit.ImpactMaxWait
-- V0 proposé, absent du doc : « devant lui » = dans le demi-espace devant le joueur
-- (produit scalaire ≥ 0, à plat, entre son regard et la direction de la vitre).
local FRONT_MIN_DOT = 0

local player = Players.LocalPlayer

-- Coup d'un clic qui attend le marqueur Impact de son animation.
type PendingHit = {
	WindowId: string,
	Tool: Tool,
	Character: Model,
	Sent: boolean, -- déjà parti (ou abandonné) : plus rien ne le renvoie
	Connection: RBXScriptConnection?, -- marqueur Impact de la piste jouée pour ce clic
}

local HitController = {}

local Net: any = nil
local animation: AnimationApi? = nil
local shatter: ShatterApi? = nil
local lastHitAt = -math.huge
local pending: PendingHit? = nil -- un seul à la fois
local hookedTools = setmetatable({} :: { [Tool]: boolean }, { __mode = "k" })

local function windowBox(object: Instance): (CFrame?, Vector3?)
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	elseif object:IsA("Model") then
		return object:GetBoundingBox()
	end
	return nil, nil
end

-- Point de la boîte (cf, size) le plus proche de `point` (même calcul que le serveur).
local function closestPoint(cf: CFrame, size: Vector3, point: Vector3): Vector3
	local p = cf:PointToObjectSpace(point)
	local h = size / 2
	return (cf:PointToWorldSpace(
		Vector3.new(math.clamp(p.X, -h.X, h.X), math.clamp(p.Y, -h.Y, h.Y), math.clamp(p.Z, -h.Z, h.Z))
	)) -- parenthèses : une seule valeur (PointToWorldSpace est déclarée variadique)
end

-- Id de la vitrine cassable la plus proche devant le joueur et à portée, et le point de la vitre
-- le plus proche de lui (même calcul que le serveur), ou nil.
local function findTarget(root: BasePart): (string?, Vector3?)
	local origin = root.Position
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local bestId: string? = nil
	local bestPoint: Vector3? = nil
	local bestDistance = Balance.Hit.Range
	for _, tag in WINDOW_TAGS do
		for _, model in CollectionService:GetTagged(tag) do
			local object = model:FindFirstChild(WINDOW_NAME) or model:FindFirstChild(WINDOW_NAME, true)
			if object == nil then
				continue
			end
			local id = object:GetAttribute(WINDOW_ID_ATTRIBUTE)
			local maxHP = object:GetAttribute(MAX_HP_ATTRIBUTE)
			if type(id) ~= "string" or type(maxHP) ~= "number" or maxHP <= 0 or object:GetAttribute(BROKEN_ATTRIBUTE) == true then
				continue -- pas encore prête, incassable ou cassée
			end
			if tag == PLOT_TAG and model:GetAttribute(OWNER_ATTRIBUTE) == player.UserId then
				continue -- sa propre boutique
			end
			local cf, size = windowBox(object)
			if cf == nil or size == nil then
				continue
			end
			local point = closestPoint(cf, size, origin)
			local offset = point - origin
			local distance = offset.Magnitude
			if distance > bestDistance then
				continue
			end
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude > 0.01 and flatLook.Magnitude > 0.01 and flat.Unit:Dot(flatLook.Unit) < FRONT_MIN_DOT then
				continue -- derrière lui
			end
			bestId, bestPoint, bestDistance = id, point, distance
		end
	end
	return bestId, bestPoint
end

-- Joue l'animation du coup ; renvoie sa piste (nil si l'animation n'est pas encore livrée).
local function playHit(tool: Tool): AnimationTrack?
	local api = animation
	if api == nil then
		return nil
	end
	local toolId = tool:GetAttribute(TOOL_ID_ATTRIBUTE)
	local def = if type(toolId) == "string" then Tools.ById[toolId] else nil
	local ok, track = pcall(api.PlayPlayer, if def then def.HitAnimation else DEFAULT_ANIMATION)
	return if ok then track else nil
end

-- Personnage vivant, outil en main : le coup peut partir (mêmes conditions qu'au clic).
local function canStrike(tool: Tool, character: Model): boolean
	if player.Character ~= character or tool.Parent ~= character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Envoie le coup en attente `hit`, une seule fois, quel que soit celui qui l'appelle en premier
-- (marqueur, délai max, clic suivant).
local function sendHit(hit: PendingHit)
	if hit.Sent then
		return
	end
	hit.Sent = true
	local connection = hit.Connection
	hit.Connection = nil
	if connection then
		connection:Disconnect()
	end
	if pending == hit then
		pending = nil
	end
	if canStrike(hit.Tool, hit.Character) then
		Net.Client.HitWindow:Fire(hit.WindowId)
	end
end

-- Le coup du clic précédent part tout de suite (avant que son animation reparte du début).
local function flushPending()
	local hit = pending
	if hit then
		sendHit(hit)
	end
end

-- Coup sur `windowId` qui part au marqueur Impact de `track`, au plus tard après IMPACT_MAX_WAIT.
local function deferHit(windowId: string, tool: Tool, character: Model, track: AnimationTrack)
	local hit: PendingHit = {
		WindowId = windowId,
		Tool = tool,
		Character = character,
		Sent = false,
		Connection = nil,
	}
	pending = hit
	-- Branché après le Play de ce clic : un marqueur de la lecture précédente ne peut pas l'atteindre.
	local ok, signal = pcall(function()
		return track:GetMarkerReachedSignal(IMPACT_MARKER)
	end)
	if ok and signal then
		hit.Connection = signal:Connect(function()
			sendHit(hit)
		end)
	end
	task.delay(IMPACT_MAX_WAIT, sendHit, hit)
end

local function onActivated(tool: Tool)
	local now = os.clock()
	if now - lastHitAt < MIN_INTERVAL then
		return
	end
	local character = player.Character
	if character == nil or tool.Parent ~= character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return
	end
	lastHitAt = now
	flushPending()
	local track = playHit(tool)
	local windowId, point = findTarget(root :: BasePart)
	if windowId then
		if track then
			deferHit(windowId, tool, character, track)
		else
			Net.Client.HitWindow:Fire(windowId) -- pas d'animation : le coup part au clic
		end
		local api = shatter
		if api and point then
			pcall(api.LocalHit, windowId, point, track)
		end
	end
end

local function hookTool(child: Instance)
	if not child:IsA("Tool") or child:GetAttribute(TOOL_ID_ATTRIBUTE) == nil then
		return
	end
	local tool = child :: Tool
	if hookedTools[tool] then
		return
	end
	hookedTools[tool] = true
	tool.Activated:Connect(function()
		onActivated(tool)
	end)
end

-- Un outil activé est forcément en main, donc enfant du personnage.
local function watchCharacter(character: Model)
	character.ChildAdded:Connect(hookTool)
	for _, child in character:GetChildren() do
		hookTool(child)
	end
end

function HitController.Start()
	Net = require(Shared:WaitForChild("Net"):WaitForChild("Net"))
	local module = script.Parent:FindFirstChild("AnimationController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any).PlayPlayer) == "function" then
			animation = result :: any
		end
	end
	local shatterModule = script.Parent:FindFirstChild("ShatterController")
	if shatterModule and shatterModule:IsA("ModuleScript") then
		local ok, result = pcall(require, shatterModule)
		if ok and type(result) == "table" and type((result :: any).LocalHit) == "function" then
			shatter = result :: any
		end
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

return HitController
