--!strict
-- PlotDoorController (client) : la boutique du joueur (`PLOT_Shop` de Clément, liaison L-050).
--
-- Le propriétaire traverse ses propres murs invisibles (`PlotBarrier`, et `Stage_j/Barriers` dès le
-- niveau 2 de la boutique, L-096) et sa porte
-- (`PlotDoor`/`Window`), côté client seulement : chez les autres joueurs, ces pièces restent
-- solides et il faut casser la porte (WindowService). Les vantaux `Leaf_L` et `Leaf_R` coulissent
-- quand le propriétaire approche (visuel local, comme Clément le prévoit). Rien n'est envoyé au
-- serveur, rien ne change chez les autres.
--
-- Côté serveur (PvPService, DEV-041) : la porte se casse selon le doc (WindowService), et un
-- non-propriétaire est sorti devant la porte s'il se trouve dans `Bounds` alors qu'elle est intacte,
-- ou quand elle se reconstruit (même un voleur chargé, qui garde ce qu'il porte). Le passage du
-- propriétaire reste ici, sur son seul client. Niveaux de boutique : Partie 2 (MAJ 2).
--
-- Ma boutique = le modèle taggé `PlayerPlot` dont l'attribut `OwnerUserId` (PlotService) vaut mon
-- UserId. Les pièces arrivent par le streaming et la porte est refaite par le serveur après une
-- casse : tout est revu quand une pièce apparaît ou que le serveur remet `CanCollide`.
--
-- a456 (L-334, Clément 24/11 : « tes vitres te bloquent aussi, tu sors par la porte ») : avec Features.OwnerSolidWalls
-- (partout) ou OwnerSolidWallsDev (jeu DEV, Config/ProductIds.IsDev), le propriétaire ne traverse plus que sa porte
-- (`PlotDoor`/`Window`) : `PlotBarrier` et `Stage_j/Barriers` ne sont plus touchés ici et restent solides pour lui,
-- comme pour les autres. `PlotBarrier` laisse libre l'ouverture de la porte (Barrier_FL, Barrier_FR, Barrier_FTop) et
-- le propriétaire réapparaît dans sa boutique (SpawnPoint). Les vitres `Pane_*` restent sans collision dans le modèle
-- (GlassThrowService, L-291) : rien ne change pour les autres joueurs ni pour l'intrus projeté. Coupé : comme avant.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId"
local BARRIER_NAME = "PlotBarrier"
local STAGE_PATTERN = "^Stage_%d+$" -- niveaux de la boutique (L-096)
local STAGE_BARRIERS = "Barriers"
local DOOR_NAME = "PlotDoor"
local WINDOW_NAME = "Window"
local LEAVES: { [string]: number } = { Leaf_L = -1, Leaf_R = 1 } -- sens du coulissement le long de la façade

-- V0, absents du doc : distance d'ouverture, course des vantaux (un vantail fait 6 studs), vitesse.
local OPEN_DISTANCE = 10
local SLIDE = 5.7
local SLIDE_TIME = 0.35

local player = Players.LocalPlayer

type Leaf = { model: Model, sign: number, base: CFrame }

type Mine = {
	plot: Model,
	connections: { RBXScriptConnection },
	parts: { [BasePart]: RBXScriptConnection },
	leaves: { Leaf },
	open: number, -- 0 fermé, 1 ouvert
}

local PlotDoorController = {}

local mine: Mine? = nil
local wallsSolid = false -- a456 (L-334) : murs invisibles solides pour moi aussi (lu une fois, au Start)

-- a456 : Features.OwnerSolidWalls (partout) ou OwnerSolidWallsDev dans le jeu DEV (Config/ProductIds.IsDev).
local function solidWallsEnabled(): boolean
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local config = if shared then shared:FindFirstChild("Config") else nil
	local featuresModule = if config then config:FindFirstChild("Features") else nil
	if config == nil or featuresModule == nil then
		return false
	end
	local ok, features = pcall(require, featuresModule :: any)
	if not ok or type(features) ~= "table" then
		return false
	end
	if (features :: any).OwnerSolidWalls == true then
		return true
	end
	if (features :: any).OwnerSolidWallsDev ~= true then
		return false
	end
	local idsModule = config:FindFirstChild("ProductIds")
	if idsModule == nil then
		return false
	end
	local iok, ids = pcall(require, idsModule :: any)
	return iok and type(ids) == "table" and (ids :: any).IsDev == true
end

local function isMine(plot: Instance): boolean
	return plot:IsA("Model") and plot:GetAttribute(OWNER_ATTRIBUTE) == player.UserId
end

-- Pièce traversable pour moi : CanCollide coupé ici, et recoupé si le serveur le remet (porte refaite).
local function passThrough(state: Mine, part: BasePart)
	if state.parts[part] then
		return
	end
	part.CanCollide = false
	state.parts[part] = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
		if part.CanCollide and mine == state then
			part.CanCollide = false
		end
	end)
end

local function passContainer(state: Mine, container: Instance)
	if container:IsA("BasePart") then
		passThrough(state, container)
	end
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			passThrough(state, d)
		end
	end
end

local function collectLeaves(state: Mine, window: Instance)
	for name, sign in LEAVES do
		local leaf = window:FindFirstChild(name)
		if leaf and leaf:IsA("Model") then
			local known = false
			for _, entry in state.leaves do
				if entry.model == leaf then
					known = true
				end
			end
			if not known then
				table.insert(state.leaves, { model = leaf, sign = sign, base = leaf:GetPivot() })
			end
		end
	end
end

-- Tout ce qui doit me laisser passer dans ma boutique : la porte, et les murs invisibles tant que
-- Features.OwnerSolidWalls est coupé (a456, L-334 : allumé, ils restent solides pour moi aussi).
local function scan(state: Mine)
	local plot = state.plot
	if not wallsSolid then
		local barrier = plot:FindFirstChild(BARRIER_NAME, true)
		if barrier then
			passContainer(state, barrier)
		end
		-- Grands murs invisibles des niveaux 2 et plus : `Stage_j/Barriers`, copiés par ShopStageService (L-096).
		for _, child in plot:GetChildren() do
			local walls = if string.match(child.Name, STAGE_PATTERN) then child:FindFirstChild(STAGE_BARRIERS) else nil
			if walls then
				passContainer(state, walls)
			end
		end
	end
	local door = plot:FindFirstChild(DOOR_NAME, true)
	local window = if door then door:FindFirstChild(WINDOW_NAME, true) else nil
	if window then
		passContainer(state, window)
		collectLeaves(state, window)
	end
end

local function release()
	local state = mine
	if state == nil then
		return
	end
	mine = nil
	for _, connection in state.connections do
		connection:Disconnect()
	end
	for part, connection in state.parts do
		connection:Disconnect()
		if part.Parent ~= nil then
			part.CanCollide = true -- plus ma boutique : solide comme pour les autres
		end
	end
	for _, leaf in state.leaves do
		if leaf.model.Parent ~= nil then
			leaf.model:PivotTo(leaf.base)
		end
	end
end

local function adopt(plot: Model)
	if mine and mine.plot == plot then
		return
	end
	release()
	local state: Mine = { plot = plot, connections = {}, parts = {}, leaves = {}, open = 0 }
	mine = state
	scan(state)
	-- Streaming et porte refaite : une nouvelle pièce relance le relevé au tour suivant.
	local pending = false
	table.insert(
		state.connections,
		plot.DescendantAdded:Connect(function()
			if pending then
				return
			end
			pending = true
			task.defer(function()
				pending = false
				if mine == state then
					scan(state)
				end
			end)
		end)
	)
	table.insert(
		state.connections,
		plot:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(function()
			if not isMine(plot) and mine == state then
				release()
			end
		end)
	)
end

local function consider(plot: Instance)
	if plot:IsA("Model") and plot:IsDescendantOf(workspace) and isMine(plot) then
		adopt(plot)
	end
end

-- a318 (L-300) : une boutique qui revient du streaming est le même objet, annoncé de nouveau : une seule écoute du
-- propriétaire par boutique, retirée à sa sortie (avant, une de plus à chaque retour).
local ownerLinks: { [Instance]: RBXScriptConnection } = {}

local function track(plot: Instance)
	consider(plot)
	if not ownerLinks[plot] then
		ownerLinks[plot] = plot:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(function()
			consider(plot)
		end)
	end
end

local function untrack(plot: Instance)
	local link = ownerLinks[plot]
	if link then
		link:Disconnect()
		ownerLinks[plot] = nil
	end
	local state = mine
	if state and (state.plot :: Instance) == plot then
		release()
	end
end

-- Vantaux : ouverts quand je suis à moins d'OPEN_DISTANCE de ma porte, fermés sinon.
local function step(dt: number)
	local state = mine
	if state == nil or #state.leaves == 0 then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local target = 0
	if root and root:IsA("BasePart") then
		local center = Vector3.zero
		for _, leaf in state.leaves do
			center += leaf.base.Position
		end
		center /= #state.leaves
		if (root.Position - center).Magnitude <= OPEN_DISTANCE then
			target = 1
		end
	end
	if state.open == target then
		return
	end
	local delta = dt / SLIDE_TIME
	state.open = if target > state.open then math.min(target, state.open + delta) else math.max(target, state.open - delta)
	local axis = state.plot:GetPivot().RightVector
	for _, leaf in state.leaves do
		if leaf.model.Parent ~= nil then
			leaf.model:PivotTo(leaf.base + axis * (leaf.sign * SLIDE * state.open))
		end
	end
end

function PlotDoorController.Start()
	wallsSolid = solidWallsEnabled()
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		track(plot)
	end
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(untrack)
	RunService.RenderStepped:Connect(step)
end

return PlotDoorController
