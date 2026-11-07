--!strict
-- PlotDoorController (client) : la boutique du joueur (`PLOT_Shop` de Clément, liaison L-050).
--
-- Le propriétaire traverse ses propres murs invisibles (`PlotBarrier`) et sa porte
-- (`PlotDoor`/`Window`), côté client seulement : chez les autres joueurs, ces pièces restent
-- solides et il faut casser la porte (WindowService). Les vantaux `Leaf_L` et `Leaf_R` coulissent
-- quand le propriétaire approche (visuel local, comme Clément le prévoit). Rien n'est envoyé au
-- serveur, rien ne change chez les autres.
--
-- V0 en attendant le code complet de la boutique (niveaux, porte cassable selon le doc, voleur
-- sorti quand la porte se reconstruit) : le serveur ne vérifie pas encore qui est à l'intérieur.
--
-- Ma boutique = le modèle taggé `PlayerPlot` dont l'attribut `OwnerUserId` (PlotService) vaut mon
-- UserId. Les pièces arrivent par le streaming et la porte est refaite par le serveur après une
-- casse : tout est revu quand une pièce apparaît ou que le serveur remet `CanCollide`.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId"
local BARRIER_NAME = "PlotBarrier"
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

-- Tout ce qui doit me laisser passer dans ma boutique : murs invisibles et porte.
local function scan(state: Mine)
	local plot = state.plot
	local barrier = plot:FindFirstChild(BARRIER_NAME, true)
	if barrier then
		passContainer(state, barrier)
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

local function track(plot: Instance)
	consider(plot)
	plot:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(function()
		consider(plot)
	end)
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
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		track(plot)
	end
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(function(plot: Instance)
		local state = mine
		if state and (state.plot :: Instance) == plot then
			release()
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return PlotDoorController
