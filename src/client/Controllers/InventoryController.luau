--!strict
-- InventoryController (L-089 points 2 et 3, L-079 ; client) : poser ce qu'on tient de sa barre
-- d'inventaire (Tools d'InventoryService : colis et objets non exposés).
--
-- Rôle :
--   - colis en main (Tool, attribut InventoryKind = "Box", BoxUid) : un clic ou un appui sur le sol
--     de sa boutique (Tool.Activated) envoie PlaceBox(boxUid, point visé) et joue Place (contrat 2.4).
--     Le point visé est celui sous le curseur ou le doigt (rayon de la caméra, sans son propre
--     personnage). Pendant qu'il le tient, un aperçu fantôme (une pièce translucide de la taille d'un
--     colis posé, Config.Unbox.BoxFootprint, tournée comme la parcelle) suit le point visé : vert si
--     la pose a des chances de passer (dans le volume Bounds de SA boutique, sol assez plat au niveau
--     du bas de Bounds, à portée), rouge sinon. Ce n'est qu'un aperçu : le serveur revérifie tout
--     (sol, présentoirs, autres colis, décor) et répond par un Notify en cas de refus ;
--   - objet en main (InventoryKind = "Item", ItemUid) : une invite « Place Item » sur chaque présentoir
--     libre de sa boutique (DisplaySlot_xx, attribut UnboxState = "Free" posé par UnboxService), créée
--     ici, côté client seulement ; elle envoie PlaceItem(itemUid, slotIndex) et joue Place. Le serveur
--     vérifie tout (DisplayService : objet à lui, dans sa boutique, présentoir libre et débloqué).
-- Rien d'autre n'est envoyé : Equip Best (remote EquipBest) attend le bouton de l'écran d'inventaire
-- de Clément (InventoryController.EquipBest, pour lui).
--
-- API (client) :
--   InventoryController.EquipBest()      demande au serveur de poser ses meilleurs objets (L-079)
--   InventoryController.GetState() -> { Kind, Uid, Aim, AimValid }
--       Ce qui est en main et le dernier point visé (bancs d'essai).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Unbox = require(Config:WaitForChild("Unbox"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))

type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
}

type StandView = {
	attachment: Attachment,
	prompt: ProximityPrompt,
	connections: { RBXScriptConnection },
}

-- Attributs posés par les services serveur (lus sans require).
local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService
local STATE_ATTRIBUTE = "UnboxState" -- UnboxService, sur chaque présentoir : "Locked", "Free", "Taken"
local KIND_ATTRIBUTE = "InventoryKind" -- InventoryService : "Box" ou "Item"
local BOX_UID_ATTRIBUTE = "BoxUid"
local ITEM_UID_ATTRIBUTE = "ItemUid"
local SLOT_PATTERN = "^DisplaySlot_(%d+)$" -- présentoirs, contrat 10.4
local BOUNDS = "Bounds"
local PROMPT_NAME = "PlaceItemPrompt"
local GHOST_NAME = "BoxGhost"

-- V0 proposés, absents du doc : textes (en anglais, L-036), portée et couleurs de l'aperçu.
local PLACE_TEXT = "Place Item"
local OBJECT_TEXT = "Stand"
local PROMPT_DISTANCE = Unbox.PromptDistance
local REACH = Unbox.PromptDistance + Unbox.ReachTolerance -- portée acceptée par le serveur (PlaceBox)
local AIM_DISTANCE = 200 -- studs : longueur du rayon de visée
local GHOST_TRANSPARENCY = 0.6
local GHOST_OK = Color3.fromHex("#35C93B") -- vert « acheter / OK », planche 10.6
local GHOST_BAD = Color3.fromHex("#E8413C") -- rouge « fermer », planche 10.6
-- Présentoirs de base et présentoirs bonus de la boutique Robux, comme DisplayService (V0 : 10 bonus).
local MAX_SLOTS = Balance.Display.MaxSlots + 10

local InventoryController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local animation: AnimationApi? = nil
local plot: Model? = nil
local plotConnections: { RBXScriptConnection } = {}
local watchedPlots: { [Instance]: RBXScriptConnection } = {}
local stands: { [number]: StandView } = {}
local held: Tool? = nil -- Tool d'inventaire en main
local heldConnections: { RBXScriptConnection } = {}
local characterConnections: { RBXScriptConnection } = {}
local ghost: BasePart? = nil
local lastAim: Vector3? = nil
local lastAimValid = false

local function loadAnimationController(): AnimationApi?
	local folder = script.Parent
	local module = if folder then folder:FindFirstChild("AnimationController") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" then
		return result :: any
	end
	return nil
end

local function playAnimation(name: string)
	local anim = animation
	if anim then
		pcall(anim.PlayPlayer, name)
	end
end

local function heldKind(): string?
	local tool = held
	if tool == nil then
		return nil
	end
	local kind = tool:GetAttribute(KIND_ATTRIBUTE)
	return if type(kind) == "string" then kind else nil
end

local function heldUid(name: string): string?
	local tool = held
	local uid = if tool then tool:GetAttribute(name) else nil
	return if type(uid) == "string" then uid else nil
end

------------------------------------------------------------------------------
-- Objet en main : invites des présentoirs libres
------------------------------------------------------------------------------

local function refreshStand(index: number)
	local view = stands[index]
	if view then
		view.prompt.Enabled = heldKind() == "Item" and view.attachment:GetAttribute(STATE_ATTRIBUTE) == "Free"
	end
end

local function refreshStands()
	for index in stands do
		refreshStand(index)
	end
end

local function slotIndexOf(inst: Instance): number?
	if not inst:IsA("Attachment") then
		return nil
	end
	local digits = string.match(inst.Name, SLOT_PATTERN)
	local index = if digits then tonumber(digits) else nil
	if index and index >= 1 and index <= MAX_SLOTS then
		return index
	end
	return nil
end

local function removeStand(index: number)
	local view = stands[index]
	if view == nil then
		return
	end
	stands[index] = nil
	for _, connection in view.connections do
		connection:Disconnect()
	end
	view.prompt:Destroy()
end

local function addStand(inst: Instance)
	local index = slotIndexOf(inst)
	if index == nil then
		return
	end
	local attachment = inst :: Attachment
	local existing = stands[index]
	if existing then
		if existing.attachment == attachment or existing.attachment.Parent ~= nil then
			return
		end
		removeStand(index)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ObjectText = OBJECT_TEXT
	prompt.ActionText = PLACE_TEXT
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Enabled = false
	local view: StandView = { attachment = attachment, prompt = prompt, connections = {} }
	table.insert(
		view.connections,
		prompt.Triggered:Connect(function()
			local uid = heldUid(ITEM_UID_ATTRIBUTE)
			if heldKind() == "Item" and uid and net then
				net.Client.PlaceItem:Fire(uid, index)
				playAnimation("Place")
			end
		end)
	)
	table.insert(
		view.connections,
		attachment:GetAttributeChangedSignal(STATE_ATTRIBUTE):Connect(function()
			refreshStand(index)
		end)
	)
	stands[index] = view
	prompt.Parent = attachment
	refreshStand(index)
end

------------------------------------------------------------------------------
-- Colis en main : visée, aperçu, pose
------------------------------------------------------------------------------

local function characterOf(): Model?
	return localPlayer.Character
end

local function boundsOf(current: Model?): BasePart?
	if current == nil then
		return nil
	end
	local found = Find.path(current, BOUNDS)
	return if found ~= nil and found:IsA("BasePart") then found :: BasePart else nil
end

-- Point du monde sous le curseur ou le dernier appui (rayon de la caméra), et sa normale.
local function aim(): (Vector3?, Vector3?)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil, nil
	end
	local ok, mouse = pcall(function()
		return localPlayer:GetMouse()
	end)
	if not ok or mouse == nil then
		return nil, nil
	end
	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	local character = characterOf()
	if character then
		table.insert(ignore, character)
	end
	local current = ghost
	if current then
		table.insert(ignore, current)
	end
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	if result == nil then
		return nil, nil
	end
	return result.Position, result.Normal
end

-- La pose a-t-elle des chances de passer (règle du serveur, en plus simple : voir l'en-tête) ?
local function looksValid(point: Vector3, normal: Vector3): boolean
	local bounds = boundsOf(plot)
	local character = characterOf()
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if bounds == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	local p = bounds.CFrame:PointToObjectSpace(point)
	local half = bounds.Size / 2
	local margin = Unbox.EdgeMargin + math.max(Unbox.BoxFootprint.X, Unbox.BoxFootprint.Z) / 2
	if math.abs(p.X) > half.X - margin or math.abs(p.Z) > half.Z - margin then
		return false
	end
	local bottom = bounds.CFrame:PointToWorldSpace(Vector3.new(p.X, -half.Y, p.Z))
	if normal.Y < Unbox.FloorMinNormalY or math.abs(point.Y - bottom.Y) > Unbox.FloorTolerance then
		return false
	end
	return ((root :: BasePart).Position - point).Magnitude <= REACH
end

local function hideGhost()
	local current = ghost
	if current then
		current.Parent = nil
	end
end

local function showGhost(point: Vector3, valid: boolean)
	local current = ghost
	if current == nil then
		local part = Instance.new("Part")
		part.Name = GHOST_NAME
		part.Size = Unbox.BoxFootprint
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = GHOST_TRANSPARENCY
		ghost = part
		current = part
	end
	local part = current :: BasePart
	local rotation = if plot then (plot :: Model):GetPivot().Rotation else CFrame.identity
	part.CFrame = CFrame.new(point) * rotation * CFrame.new(0, part.Size.Y / 2, 0)
	part.Color = if valid then GHOST_OK else GHOST_BAD
	part.Parent = Workspace
end

local function updateAim()
	if heldKind() ~= "Box" then
		hideGhost()
		return
	end
	local point, normal = aim()
	lastAim = point
	if point == nil or normal == nil then
		lastAimValid = false
		hideGhost()
		return
	end
	lastAimValid = looksValid(point, normal)
	showGhost(point, lastAimValid)
end

local function onActivated()
	local uid = heldUid(BOX_UID_ATTRIBUTE)
	if heldKind() ~= "Box" or uid == nil or net == nil then
		return
	end
	local point = aim()
	if point == nil then
		return
	end
	net.Client.PlaceBox:Fire(uid, point)
	playAnimation("Place")
end

------------------------------------------------------------------------------
-- Ce qui est en main
------------------------------------------------------------------------------

local function release()
	for _, connection in heldConnections do
		connection:Disconnect()
	end
	table.clear(heldConnections)
	held = nil
	lastAim, lastAimValid = nil, false
	hideGhost()
	refreshStands()
end

local function hold(tool: Tool)
	release()
	held = tool
	table.insert(heldConnections, tool.Activated:Connect(onActivated))
	if heldKind() == "Box" then
		table.insert(heldConnections, RunService.RenderStepped:Connect(updateAim))
	end
	refreshStands()
end

local function isInventoryTool(inst: Instance): boolean
	return inst:IsA("Tool") and inst:GetAttribute(KIND_ATTRIBUTE) ~= nil
end

local function watchCharacter(character: Model?)
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	release()
	if character == nil then
		return
	end
	table.insert(
		characterConnections,
		character.ChildAdded:Connect(function(child: Instance)
			if isInventoryTool(child) then
				hold(child :: Tool)
			end
		end)
	)
	table.insert(
		characterConnections,
		character.ChildRemoved:Connect(function(child: Instance)
			if child == held then
				release()
			end
		end)
	)
	for _, child in character:GetChildren() do
		if isInventoryTool(child) then
			hold(child :: Tool)
		end
	end
end

------------------------------------------------------------------------------
-- Sa boutique
------------------------------------------------------------------------------

local function setPlot(newPlot: Model?)
	if newPlot == plot then
		return
	end
	for index in stands do
		removeStand(index)
	end
	for _, connection in plotConnections do
		connection:Disconnect()
	end
	table.clear(plotConnections)
	plot = newPlot
	if newPlot == nil then
		return
	end
	table.insert(plotConnections, newPlot.DescendantAdded:Connect(addStand))
	table.insert(
		plotConnections,
		newPlot.DescendantRemoving:Connect(function(inst: Instance)
			local index = slotIndexOf(inst)
			local view = if index then stands[index] else nil
			if index and view and view.attachment == inst then
				removeStand(index)
			end
		end)
	)
	for _, inst in newPlot:GetDescendants() do
		addStand(inst)
	end
end

local function findPlot(): Model?
	for _, inst in CollectionService:GetTagged(PLOT_TAG) do
		if inst:IsA("Model") and inst:GetAttribute(OWNER_ATTRIBUTE) == localPlayer.UserId then
			return inst :: Model
		end
	end
	return nil
end

local function updatePlot()
	setPlot(findPlot())
end

local function watchPlot(inst: Instance)
	if watchedPlots[inst] then
		return
	end
	watchedPlots[inst] = inst:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(updatePlot)
	updatePlot()
end

local function unwatchPlot(inst: Instance)
	local connection = watchedPlots[inst]
	if connection then
		connection:Disconnect()
		watchedPlots[inst] = nil
	end
	updatePlot()
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function InventoryController.EquipBest()
	if net == nil then
		warn("[InventoryController] remotes pas encore prêts : EquipBest ignoré")
		return
	end
	net.Client.EquipBest:Fire()
end

function InventoryController.GetState(): { Kind: string?, Uid: string?, Aim: Vector3?, AimValid: boolean }
	local kind = heldKind()
	local uid = if kind == "Box" then heldUid(BOX_UID_ATTRIBUTE) elseif kind == "Item" then heldUid(ITEM_UID_ATTRIBUTE) else nil
	return { Kind = kind, Uid = uid, Aim = lastAim, AimValid = lastAimValid }
end

function InventoryController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	animation = loadAnimationController()

	localPlayer.CharacterAdded:Connect(watchCharacter)
	watchCharacter(localPlayer.Character)

	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(watchPlot)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(unwatchPlot)
	for _, inst in CollectionService:GetTagged(PLOT_TAG) do
		watchPlot(inst)
	end
end

return InventoryController
