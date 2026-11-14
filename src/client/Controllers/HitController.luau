--!strict
-- HitController (client) : coups sur les vitrines avec l'outil de casse (Partie 1, 5.2 et 9.4).
--
-- Quand le joueur active son outil de casse (clic ou tap : Tool.Activated), le contrôleur
-- vise la vitrine cassable la plus proche devant lui, à portée (Balance.Hit.Range, 8 studs),
-- et envoie HitWindow(windowId) au serveur, au plus 5 coups par seconde
-- (Balance.Hit.MaxHitsPerSecond ; 10 avant le rééquilibrage v2 du 2026-11-14). Un clic arrivé trop tôt
-- (moins de 1 / MaxHitsPerSecond s après le coup d'avant) n'est plus perdu : il est gardé (un seul à la fois)
-- et part dès que l'intervalle est écoulé. Sans cela, un joueur qui clique 7 fois par seconde ne donnerait
-- que 3,5 coups par seconde (un clic sur deux), sous les 4,42 qu'il faut pour casser une vitrine à son
-- niveau en 13 s (Config/Zones) ; avec, il donne 5 coups par seconde. Le plafond reste celui du serveur (Net). Il joue tout de suite l'animation du coup (5.2), même dans
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
-- près) : le débit vu par le serveur (5 coups/s au plus, Net) ne change pas. Au moment d'envoyer,
-- l'outil doit être encore en main et le personnage vivant, sinon le coup est abandonné (le
-- serveur l'aurait refusé). WindowService ne change pas : il mesure la portée à la réception,
-- donc au moment où le coup touche.
--
-- Cible d'événement (camion de l'événement, liaison L-049) : un modèle taggé HitTarget par
-- WindowService, visé comme une vitrine (même portée, même « devant lui », même coup au marqueur
-- Impact, même HitWindow), la boîte du modèle tenant lieu de vitre. Seule différence : pas de retour
-- de verre (ShatterController.LocalHit), ce n'est pas une vitre. Son retour local est le son du
-- coup sur le camion (TruckController.LocalHit, DEV-053), joué au moment où le coup part : au
-- marqueur Impact, au délai max, au clic suivant, ou au clic sans animation, comme HitWindow.
-- Le chiffre de dégâts de chaque coup, lui, attend la réponse du serveur (DamageNumberController).
--
-- Lu sur les objets (rien n'est cherché par chemin) :
--   Tool de casse : attribut ToolId (ToolService). La batte (slot 2, attribut BatTool, jamais
--   ToolId) est ignorée ici : son coup est à BatController ;
--   vitrine `Window` des modèles taggés NPCStore et PlayerPlot : WindowId, MaxHP, Broken
--   (WindowService) ; parcelle : OwnerUserId (PlotService) ;
--   modèle taggé HitTarget : WindowId, MaxHP, Broken (WindowService).
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

-- Ce que ce contrôleur utilise de TruckController (a27 ; son du coup, DEV-053).
type TruckApi = {
	LocalHit: (targetId: string, point: Vector3) -> (),
}

local TOOL_ID_ATTRIBUTE = "ToolId" -- posé par ToolService sur le Tool de casse
local BAT_ATTRIBUTE = "BatTool" -- posé par ToolService sur la batte (BatController)
local WINDOW_NAME = "Window" -- enfant obligatoire (10.4)
local WINDOW_ID_ATTRIBUTE = "WindowId" -- posés par WindowService sur la vitrine
local MAX_HP_ATTRIBUTE = "MaxHP"
local BROKEN_ATTRIBUTE = "Broken"
local OWNER_ATTRIBUTE = "OwnerUserId" -- posé par PlotService sur la parcelle
local PLOT_TAG = "PlayerPlot"
local WINDOW_TAGS = { "NPCStore", PLOT_TAG } -- contrat 2.1
local HIT_TARGET_TAG = "HitTarget" -- posé par WindowService sur une cible d'événement (hors contrat 2.1)
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
	Point: Vector3, -- point visé (celui que le serveur calculera), pour le retour local du camion
	IsWindow: boolean, -- false : cible d'événement
	Tool: Tool,
	Character: Model,
	Sent: boolean, -- déjà parti (ou abandonné) : plus rien ne le renvoie
	Connection: RBXScriptConnection?, -- marqueur Impact de la piste jouée pour ce clic
}

local HitController = {}

local Net: any = nil
local animation: AnimationApi? = nil
local shatter: ShatterApi? = nil
local truck: TruckApi? = nil
local lastHitAt = -math.huge -- heure « de rythme » du dernier coup (voir onActivated)
local queuedClick = false -- un clic trop tôt attend la fin de l'intervalle (voir l'en-tête)
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

-- Id de la vitrine (ou de la cible d'événement) cassable la plus proche devant le joueur et à
-- portée, le point de sa boîte le plus proche de lui (même calcul que le serveur), et true si c'est
-- une vitre (false : cible d'événement) ; nil si rien n'est à portée.
local function findTarget(root: BasePart): (string?, Vector3?, boolean)
	local origin = root.Position
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local bestId: string? = nil
	local bestPoint: Vector3? = nil
	local bestDistance = Balance.Hit.Range
	local bestIsWindow = false
	-- `object` porte les attributs de WindowService ; sa boîte est ce qu'on frappe.
	local function consider(object: Instance, isWindow: boolean)
		local id = object:GetAttribute(WINDOW_ID_ATTRIBUTE)
		local maxHP = object:GetAttribute(MAX_HP_ATTRIBUTE)
		if type(id) ~= "string" or type(maxHP) ~= "number" or maxHP <= 0 or object:GetAttribute(BROKEN_ATTRIBUTE) == true then
			return -- pas encore prête, incassable ou cassée
		end
		local cf, size = windowBox(object)
		if cf == nil or size == nil then
			return
		end
		local point = closestPoint(cf, size, origin)
		local offset = point - origin
		local distance = offset.Magnitude
		if distance > bestDistance then
			return
		end
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 0.01 and flatLook.Magnitude > 0.01 and flat.Unit:Dot(flatLook.Unit) < FRONT_MIN_DOT then
			return -- derrière lui
		end
		bestId, bestPoint, bestDistance, bestIsWindow = id, point, distance, isWindow
	end
	for _, tag in WINDOW_TAGS do
		for _, model in CollectionService:GetTagged(tag) do
			local object = model:FindFirstChild(WINDOW_NAME) or model:FindFirstChild(WINDOW_NAME, true)
			if object == nil then
				continue
			end
			if tag == PLOT_TAG and model:GetAttribute(OWNER_ATTRIBUTE) == player.UserId then
				continue -- sa propre boutique
			end
			consider(object, true)
		end
	end
	for _, target in CollectionService:GetTagged(HIT_TARGET_TAG) do
		consider(target, false)
	end
	return bestId, bestPoint, bestIsWindow
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

-- Envoie le coup au serveur ; sur une cible d'événement, joue au même moment son retour local (son
-- du coup sur le camion). Les vitres ont le leur dans ShatterController.LocalHit.
local function strike(windowId: string, point: Vector3, isWindow: boolean)
	Net.Client.HitWindow:Fire(windowId)
	local api = truck
	if api and not isWindow then
		pcall(api.LocalHit, windowId, point)
	end
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
		strike(hit.WindowId, hit.Point, hit.IsWindow)
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
local function deferHit(
	windowId: string,
	point: Vector3,
	isWindow: boolean,
	tool: Tool,
	character: Model,
	track: AnimationTrack
)
	local hit: PendingHit = {
		WindowId = windowId,
		Point = point,
		IsWindow = isWindow,
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

-- `due` : le clic gardé, qui part à l'heure prévue (son attente est finie : pas de nouveau contrôle).
local function onActivated(tool: Tool, due: boolean?)
	local now = os.clock()
	local wait = MIN_INTERVAL - (now - lastHitAt)
	if wait > 0 and not due then
		-- Trop tôt : ce clic part à la fin de l'intervalle (un seul en attente ; les suivants sont ignorés).
		if not queuedClick then
			queuedClick = true
			task.delay(wait, function()
				queuedClick = false
				onActivated(tool, true)
			end)
		end
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
	-- Rythme tenu sur la durée : un coup parti à peine en retard sur son heure prévue (une image, le délai du
	-- clic gardé : un quart de période au plus) ne retarde pas le suivant, dû MIN_INTERVAL après cette heure
	-- prévue. Un joueur qui clique assez vite donne ainsi 5 coups par seconde, pas 4,6 (13 images sur 60).
	local planned = lastHitAt + MIN_INTERVAL
	lastHitAt = if now - planned <= MIN_INTERVAL / 4 then planned else now
	flushPending()
	local track = playHit(tool)
	local windowId, point, isWindow = findTarget(root :: BasePart)
	if windowId and point then
		if track then
			deferHit(windowId, point, isWindow, tool, character, track)
		else
			strike(windowId, point, isWindow) -- pas d'animation : le coup part au clic
		end
		local api = shatter
		if api and isWindow then
			pcall(api.LocalHit, windowId, point, track) -- retour de verre : vitres seulement
		end
	end
end

local function hookTool(child: Instance)
	if not child:IsA("Tool") or child:GetAttribute(TOOL_ID_ATTRIBUTE) == nil or child:GetAttribute(BAT_ATTRIBUTE) == true then
		return -- pas un outil de casse (la batte est à BatController)
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
	local truckModule = script.Parent:FindFirstChild("TruckController")
	if truckModule and truckModule:IsA("ModuleScript") then
		local ok, result = pcall(require, truckModule)
		if ok and type(result) == "table" and type((result :: any).LocalHit) == "function" then
			truck = result :: any
		end
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

return HitController
