--!strict
-- TensionController (a465, client ; liaison L-340, retours de Clément après sa session de jeu, points 7 et 8 ; test
-- T-303) : la tension pendant un braquage. Réglages : Config/HeistTension ; interrupteur : Shared/HeistTension
-- (Features.HeistTension partout, HeistTensionDev dans le jeu DEV ; en Studio, workspace:SetAttribute("HeistTensionTest",
-- true ou false) force la réponse). Coupé : rien n'est posé, tout reste comme avant. Rien n'est envoyé au serveur :
-- le chemin part de ce que le client voit déjà (sa position, la porte de sa boutique, répliquée avec la map).
--
--   1. Chevrons au sol (L-340 point 1). Tant que le joueur local porte un objet volé (attribut Carrying du Player, posé
--      par CarryService : magasin PNJ, boutique d'un joueur, objet ramassé au sol), une file de copies de
--      ReplicatedStorage/Assets/FX/FX_ChaseChevron (Clément) va de lui à la porte de SA boutique (parcelle taggée
--      PlayerPlot dont OwnerUserId est le sien : enfant PlotDoor, sinon DepositZone, sinon son pivot). Le chemin vient
--      de PathfindingService (il contourne rayons et murs ; échec : la ligne droite), refait quand le joueur s'en
--      éloigne de plus de Chevrons.OffPath studs ou que la porte bouge, au plus toutes les RecomputeEvery s. Un
--      chevron tous les Spacing studs sur une grille fixe du chemin (il ne glisse pas : dépassé, il disparaît), Max au
--      plus, pointe (−Z) vers la boutique, collé au sol par un rayon vertical. Ses barres Left et Right s'allument en
--      vague vers la boutique (transparence From → Peak → From, Step s d'un chevron au suivant, Path.Wave). Tout part
--      au dépôt, à la perte de l'objet ou à la capture (Carrying retiré par le serveur), à la mort, ou si la tension
--      est coupée. Les copies vivent dans un dossier local du Workspace (Chevrons.Folder) ; aucune collision ni
--      requête, aucun script.
--   2. Chrono de la phase discrète (L-340 point 4). Tant qu'un chrono de braquage tourne (HeistController.GetTimers)
--      et que personne ne poursuit le joueur (ChaseController.IsChased), HudMask.SetSpare garde
--      Config/HeistTension.DiscreetKeep (UI_HUD.HeistTimer) sous les masques du HUD (écran de révélation…).
-- Le vigile en rouge (point 2), DropButton (point 3) et le flash d'arrivée (point 5) sont dans VfxController,
-- ChaseFeelController et UiFeelController ; « RUN! » plus grand et le bandeau de nuit : faits par Clément dans Studio.
-- Modèle FX_ChaseChevron absent : pas de chevron (une ligne en Studio, une fois).
--
-- API (client, pour un test dans Studio ou un banc) :
--   TensionController.GetState() -> { Enabled, Active, Chevrons, PathPoints, Computing, Spare, Target }

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Tension = require(Config:WaitForChild("HeistTension"))
local Vfx = require(Config:WaitForChild("Vfx"))
local Switch = require(Shared:WaitForChild("HeistTension"))
local Path = require(script.Parent:WaitForChild("Tension"):WaitForChild("Path"))
local HudMask = require(script.Parent:WaitForChild("UI"):WaitForChild("HudMask"))

-- Noms posés par d'autres (mêmes noms là-bas).
local CARRYING_ATTRIBUTE = "Carrying" -- CarryService, CarryController
local PLOT_TAG = "PlayerPlot" -- Contract/Tags
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService (ShopLockController, DisplayController)
local DOOR_NAME = "PlotDoor" -- enfant d'une parcelle (PlotDoorController, OutlineController)
local DEPOSIT_NAME = "DepositZone" -- Contract/Models.Plot

local IS_STUDIO = RunService:IsStudio()
local CHEVRONS = Tension.Chevrons

type ChaseApi = { IsChased: () -> boolean }
type HeistApi = { GetTimers: () -> { [string]: number } }
type Chevron = { model: Model, lit: { BasePart }, shown: number? }

export type State = {
	Enabled: boolean,
	Active: boolean,
	Chevrons: number, -- chevrons posés en ce moment
	PathPoints: number, -- points du chemin suivi (0 : pas encore de chemin)
	Computing: boolean,
	Spare: boolean, -- le chrono est gardé sous les masques du HUD
	Target: Vector3?,
}

local TensionController = {}

local localPlayer = Players.LocalPlayer
local chase: ChaseApi? = nil
local heist: HeistApi? = nil
local said: { [string]: boolean } = {}

local enabled = false
local active = false -- des chevrons sont voulus (objet porté, boutique trouvée)
local spareOn = false
local folder: Folder? = nil
local pool: { Chevron } = {} -- copies créées pour ce portage (réutilisées)
local used = 0 -- copies posées en ce moment (les premières du pool)
local points: { Vector3 }? = nil -- chemin suivi
local pathTarget: Vector3? = nil -- porte visée quand le chemin a été calculé
local computing = false
local computeToken = 0
local lastCompute = -math.huge
local clock = 0
local sinceRefresh = math.huge
local lift: number? = nil -- hauteur du pivot du modèle au-dessus de son point le plus bas
local target: Vector3? = nil

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		print(`[Tension] {message}`)
	end
end

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

-- Phase discrète --------------------------------------------------------------------------------------------------

local function chased(): boolean
	local api = chase
	if api == nil then
		return false
	end
	local ok, result = pcall(api.IsChased)
	return ok and result == true
end

local function heistRunning(): boolean
	local api = heist
	if api == nil then
		return false
	end
	local ok, timers = pcall(api.GetTimers)
	if not ok or type(timers) ~= "table" then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	for _, endsAt in timers do
		if type(endsAt) == "number" and endsAt > now then
			return true
		end
	end
	return false
end

local function updateSpare()
	local want = enabled and heistRunning() and not chased()
	if want == spareOn then
		return
	end
	spareOn = want
	HudMask.SetSpare(Tension.SpareKey, if want then Tension.DiscreetKeep :: any else nil)
end

-- Chevrons ----------------------------------------------------------------------------------------------------------

local function folderOf(path: { string }): Instance?
	local current: Instance? = ReplicatedStorage
	for _, name in path do
		current = if current then current:FindFirstChild(name) else nil
	end
	return current
end

local function template(): Model?
	local fx = folderOf(Vfx.FxFolder)
	local found = if fx then fx:FindFirstChild(CHEVRONS.Template, true) else nil
	if found and found:IsA("Model") then
		return found :: Model
	end
	sayOnce("template", `{table.concat(Vfx.FxFolder, "/")}/{CHEVRONS.Template} (Model) introuvable : pas de chevrons (L-340)`)
	return nil
end

local function myPlot(): Instance?
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:GetAttribute(OWNER_ATTRIBUTE) == localPlayer.UserId and plot:IsDescendantOf(Workspace) then
			return plot
		end
	end
	return nil
end

local function positionOf(instance: Instance?): Vector3?
	if instance == nil then
		return nil
	end
	if instance:IsA("BasePart") then
		return (instance :: BasePart).Position
	end
	if instance:IsA("Model") then
		return (instance :: Model):GetPivot().Position
	end
	return nil
end

-- La porte de sa boutique : PlotDoor, sinon DepositZone, sinon le pivot de la parcelle.
local function doorOf(plot: Instance): Vector3?
	return positionOf(plot:FindFirstChild(DOOR_NAME))
		or positionOf(plot:FindFirstChild(DEPOSIT_NAME))
		or positionOf(plot)
end

local function rootOf(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or humanoid.Health > 0 then
			return root :: BasePart
		end
	end
	return nil
end

local function ensureFolder(): Folder
	local current = folder
	if current and current.Parent == Workspace then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = CHEVRONS.Folder
	created.Parent = Workspace
	folder = created
	return created
end

-- Copie du modèle : ancrée, sans collision ni requête, sans script ; ses barres Left et Right.
local function newChevron(source: Model): Chevron
	local copy = source:Clone()
	local lit: { BasePart } = {}
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			if table.find(CHEVRONS.Lit, part.Name) ~= nil then
				table.insert(lit, part)
			end
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy() -- jamais de script dans une copie (CLAUDE.md)
		end
	end
	return { model = copy, lit = lit, shown = nil }
end

-- Hauteur du pivot au-dessus du point le plus bas du modèle (le pivot de Clément est au centre de Root, 0,1 stud).
local function liftOf(source: Model): number
	local pivotY = source:GetPivot().Position.Y
	local lowest = math.huge
	for _, descendant in source:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			lowest = math.min(lowest, part.Position.Y - part.Size.Y / 2)
		end
	end
	return if lowest < math.huge then math.max(pivotY - lowest, 0) else 0
end

local function groundY(position: Vector3, exclude: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local origin = position + Vector3.new(0, CHEVRONS.RayUp, 0)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -(CHEVRONS.RayUp + CHEVRONS.RayDown), 0), params)
	return if hit then hit.Position.Y else position.Y
end

local function hideFrom(count: number)
	for i = count + 1, used do
		local chevron = pool[i]
		if chevron then
			chevron.model.Parent = nil
		end
	end
	used = count
end

local function clearChevrons()
	computeToken += 1 -- un chemin en cours de calcul est oublié
	computing = false
	for _, chevron in pool do
		chevron.model:Destroy()
	end
	table.clear(pool)
	used = 0
	points = nil
	pathTarget = nil
	target = nil
	lastCompute = -math.huge
	local current = folder
	folder = nil
	if current then
		current:Destroy()
	end
end

-- Chemin du joueur à la porte : PathfindingService, sinon la ligne droite. En tâche à part (ComputeAsync attend).
local function compute(from: Vector3, to: Vector3)
	computing = true
	lastCompute = clock
	computeToken += 1
	local token = computeToken
	task.spawn(function()
		local result: { Vector3 } = { from, to }
		local ok, path = pcall(function()
			local agent = CHEVRONS.Agent
			local created = PathfindingService:CreatePath({
				AgentRadius = agent.Radius,
				AgentHeight = agent.Height,
				AgentCanJump = agent.CanJump,
			})
			created:ComputeAsync(from, to)
			return created
		end)
		if ok and path and path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			if #waypoints >= 2 then
				result = { from }
				for _, waypoint in waypoints do
					table.insert(result, waypoint.Position)
				end
			end
		end
		if token ~= computeToken then
			return -- portage fini ou chemin redemandé entre-temps
		end
		points = result
		pathTarget = to
		computing = false
		sinceRefresh = math.huge -- chevrons posés à l'image suivante
	end)
end

local function layout(root: BasePart)
	local current = points
	if current == nil then
		return
	end
	local source = template()
	if source == nil then
		hideFrom(0)
		return
	end
	if lift == nil then
		lift = liftOf(source)
	end
	local along = Path.Project(current, root.Position)
	local samples = Path.Sample(current, along, CHEVRONS)
	local parent = ensureFolder()
	local exclude: { Instance } = { parent }
	if localPlayer.Character then
		table.insert(exclude, localPlayer.Character :: Model)
	end
	for i, sample in samples do
		local chevron = pool[i]
		if chevron == nil then
			chevron = newChevron(source)
			pool[i] = chevron
		end
		local position = sample.Position
		local y = groundY(position, exclude) + (lift :: number) + CHEVRONS.GroundGap
		local at = Vector3.new(position.X, y, position.Z)
		chevron.model:PivotTo(CFrame.lookAt(at, at + sample.Direction))
		chevron.shown = sample.Index
		if chevron.model.Parent ~= parent then
			chevron.model.Parent = parent
		end
	end
	if #samples < used then
		hideFrom(#samples)
	end
	used = #samples
end

local function refresh(root: BasePart)
	local plot = myPlot()
	local door = if plot then doorOf(plot) else nil
	target = door
	if door == nil then
		sayOnce("plot", "boutique du joueur introuvable (PlayerPlot, OwnerUserId) : pas de chevrons")
		hideFrom(0)
		return
	end
	local current = points
	local need = current == nil
	if current and not need then
		local _, off = Path.Project(current, root.Position)
		local moved = if pathTarget then (pathTarget - door).Magnitude else math.huge
		need = off > CHEVRONS.OffPath or moved > CHEVRONS.TargetMoved
	end
	if need and not computing and clock - lastCompute >= CHEVRONS.RecomputeEvery then
		compute(root.Position, door)
	end
	layout(root)
end

-- La vague : chaque image, transparence des barres de chaque chevron posé (écrite seulement si elle change).
local function animate()
	for i = 1, used do
		local chevron = pool[i]
		local index = chevron and chevron.shown
		if chevron and index then
			local value = Path.Wave(index, clock, CHEVRONS)
			for _, part in chevron.lit do
				if math.abs(part.Transparency - value) > 0.01 then
					part.Transparency = value
				end
			end
		end
	end
end

local function step(dt: number)
	enabled = Switch.Enabled()
	updateSpare()
	local root = if enabled then rootOf() else nil
	local carrying = root ~= nil and localPlayer:GetAttribute(CARRYING_ATTRIBUTE) ~= nil
	if not carrying or root == nil then
		if active or #pool > 0 or folder ~= nil then
			clearChevrons()
		end
		active = false
		return
	end
	active = true
	clock += dt
	sinceRefresh += dt
	if sinceRefresh >= CHEVRONS.Refresh then
		sinceRefresh = 0
		refresh(root)
	end
	animate()
end

-- API --------------------------------------------------------------------------------------------------------------

function TensionController.GetState(): State
	return {
		Enabled = enabled,
		Active = active,
		Chevrons = used,
		PathPoints = if points then #(points :: { Vector3 }) else 0,
		Computing = computing,
		Spare = spareOn,
		Target = target,
	}
end

function TensionController.Start()
	chase = sibling("ChaseController")
	heist = sibling("HeistController")
	local function onError(err: any)
		sayOnce(`error:{err}`, tostring(err))
	end
	RunService.Heartbeat:Connect(function(dt: number)
		xpcall(step, onError, dt)
	end)
end

return TensionController
