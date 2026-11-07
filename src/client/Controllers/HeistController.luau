--!strict
-- HeistController (DEV-015, client) : invites de prise sur les colis des magasins PNJ et chrono
-- du braquage (Partie 1, sections 5.3 et 9.4).
--
-- Rôle :
--   - Sur chaque colis d'un rayon (dossier `ShelfBoxes` d'un magasin taggé NPCStore, rempli par
--     StoreHeistService), une invite ProximityPrompt créée ici, sur l'Attachment ShelfSlot_xx du
--     colis : maintien = temps de prise de son type (Balance.Heist.BoxTiers[Tier].GrabTime),
--     portée = Balance.Heist.GrabMaxDistance. L'invite n'est active que si le magasin est ouvert
--     (HeistOpen), le colis posé (Landed), les mains vides (attribut Carrying du joueur, posé par
--     CarryService), le joueur dans le volume Bounds du magasin et, pendant l'avance du casseur,
--     seulement pour le casseur.
--   - Début du maintien : GrabItem(slotId). Invite déclenchée : GrabItem(slotId) une seconde fois
--     (le serveur vérifie la durée entre les deux) et animation Grab (AnimationController s'il est
--     là). Le serveur décide de tout : ce contrôleur ne fait que demander.
--   - HeistTimer(storeId, endsAt) : chrono du braquage, endsAt en heure serveur
--     (workspace:GetServerTimeNow()), 0 = masqué. Relayé à OnTimer : HudController l'affiche dans
--     UI_HUD.HeistTimer (DEV-021). En Studio, une ligne dans la sortie à chaque envoi du serveur.
--
-- API (client) :
--   HeistController.OnTimer(fn(storeId, endsAt)) -> déconnexion   (endsAt = 0 : chrono masqué)
--   HeistController.GetTimers() -> { [storeId]: endsAt }   (copie des chronos affichés)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared:WaitForChild("Config"):WaitForChild("Balance"))

-- Ce que ce contrôleur utilise d'AnimationController (a09).
type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
}

type TimerListener = (storeId: string, endsAt: number) -> ()

type StoreWatch = {
	Model: Model,
	Bounds: BasePart?,
	Folder: Instance?,
	Prompts: { [Instance]: ProximityPrompt }, -- colis → son invite
	Connections: { RBXScriptConnection },
	FolderConnections: { RBXScriptConnection },
}

local STORE_TAG = "NPCStore" -- contrat 2.1
local BOUNDS_NAME = "Bounds" -- contrat 10.4
-- Posés par StoreHeistService (mêmes noms là-bas).
local BOXES_FOLDER = "ShelfBoxes"
local OPEN_ATTRIBUTE = "HeistOpen"
local EXCLUSIVE_ATTRIBUTE = "HeistExclusiveUntil"
local BREAKER_ATTRIBUTE = "HeistBreakerId"
local SLOT_ID_ATTRIBUTE = "SlotId"
local SLOT_ATTRIBUTE = "Slot"
local TIER_ATTRIBUTE = "Tier"
local LANDED_ATTRIBUTE = "Landed"
-- Posé par CarryService sur le Player tant qu'il porte (Id de rareté).
local CARRYING_ATTRIBUTE = "Carrying"
local PROMPT_NAME = "GrabPrompt"
local GRAB_ANIMATION = "Grab" -- contrat 2.4

-- V0 proposé, absent du doc : invites revues 5 fois par seconde (volume Bounds, fin de l'avance).
local REFRESH_INTERVAL = 0.2
-- V0 proposé, absent du doc : invite visible un demi-stud avant la portée du serveur, pour qu'un
-- léger retard de la position côté serveur ne fasse pas refuser la prise.
local PROMPT_DISTANCE_MARGIN = 0.5
-- V0 proposé, absent du doc : texte de l'invite.
local ACTION_TEXT = "Voler"

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local HeistController = {}

local Net: any = nil
local animation: AnimationApi? = nil
local watches: { [Instance]: StoreWatch } = {}
local timers: { [string]: number } = {}
local timerListeners: { TimerListener } = {}

local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function localRoot(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function boundsOf(watch: StoreWatch): BasePart?
	local bounds = watch.Bounds
	if bounds and bounds:IsDescendantOf(watch.Model) then
		return bounds
	end
	local found = watch.Model:FindFirstChild(BOUNDS_NAME, true)
	watch.Bounds = if found and found:IsA("BasePart") then found else nil
	return watch.Bounds
end

-- Le joueur peut-il prendre un colis dans ce magasin, en ce moment ? (Le serveur revérifie tout.)
local function canGrabHere(watch: StoreWatch): boolean
	local model = watch.Model
	if model:GetAttribute(OPEN_ATTRIBUTE) ~= true then
		return false
	end
	if localPlayer:GetAttribute(CARRYING_ATTRIBUTE) ~= nil then
		return false
	end
	local exclusiveUntil = model:GetAttribute(EXCLUSIVE_ATTRIBUTE)
	if
		type(exclusiveUntil) == "number"
		and Workspace:GetServerTimeNow() < exclusiveUntil
		and model:GetAttribute(BREAKER_ATTRIBUTE) ~= localPlayer.UserId
	then
		return false -- avance du casseur
	end
	local root = localRoot()
	local bounds = boundsOf(watch)
	return root ~= nil and bounds ~= nil and inside(bounds, root.Position)
end

local function refreshStore(watch: StoreWatch)
	if next(watch.Prompts) == nil then
		return
	end
	local allowed = canGrabHere(watch)
	for box, prompt in watch.Prompts do
		prompt.Enabled = allowed and box:GetAttribute(LANDED_ATTRIBUTE) ~= false
	end
end

local function refreshAll()
	for _, watch in watches do
		refreshStore(watch)
	end
end

local function playGrab()
	local api = animation
	if api then
		pcall(api.PlayPlayer, GRAB_ANIMATION)
	end
end

local function removePrompt(watch: StoreWatch, box: Instance)
	local prompt = watch.Prompts[box]
	if prompt then
		watch.Prompts[box] = nil
		prompt:Destroy()
	end
end

local function addPrompt(watch: StoreWatch, box: Instance)
	if watch.Prompts[box] then
		return
	end
	local slotId = box:GetAttribute(SLOT_ID_ATTRIBUTE)
	local slotName = box:GetAttribute(SLOT_ATTRIBUTE)
	local tier = box:GetAttribute(TIER_ATTRIBUTE)
	if type(slotId) ~= "string" or type(slotName) ~= "string" or type(tier) ~= "string" then
		return
	end
	local info = Balance.Heist.BoxTiers[tier]
	local anchor = watch.Model:FindFirstChild(slotName, true)
	if info == nil or anchor == nil or not anchor:IsA("Attachment") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = ACTION_TEXT
	prompt.ObjectText = `Colis {info.DisplayName}`
	prompt.HoldDuration = info.GrabTime
	prompt.MaxActivationDistance = math.max(Balance.Heist.GrabMaxDistance - PROMPT_DISTANCE_MARGIN, 1)
	prompt.RequiresLineOfSight = false -- les rayons cachent parfois le colis
	prompt.Enabled = false
	prompt.PromptButtonHoldBegan:Connect(function()
		Net.Client.GrabItem:Fire(slotId) -- début du maintien
	end)
	prompt.Triggered:Connect(function()
		Net.Client.GrabItem:Fire(slotId) -- fin du maintien
		playGrab()
	end)
	prompt.Parent = anchor
	watch.Prompts[box] = prompt
	refreshStore(watch)
end

local function watchFolder(watch: StoreWatch, folder: Instance)
	if watch.Folder == folder then
		return
	end
	for _, connection in watch.FolderConnections do
		connection:Disconnect()
	end
	table.clear(watch.FolderConnections)
	for box in table.clone(watch.Prompts) do
		removePrompt(watch, box)
	end
	watch.Folder = folder
	table.insert(
		watch.FolderConnections,
		folder.ChildAdded:Connect(function(box: Instance)
			addPrompt(watch, box)
		end)
	)
	table.insert(
		watch.FolderConnections,
		folder.ChildRemoved:Connect(function(box: Instance)
			removePrompt(watch, box)
		end)
	)
	for _, box in folder:GetChildren() do
		addPrompt(watch, box)
	end
end

local function watchStore(instance: Instance)
	if not instance:IsA("Model") or watches[instance] ~= nil then
		return
	end
	local model = instance :: Model
	local watch: StoreWatch = {
		Model = model,
		Bounds = nil,
		Folder = nil,
		Prompts = {},
		Connections = {},
		FolderConnections = {},
	}
	watches[instance] = watch
	table.insert(
		watch.Connections,
		instance.ChildAdded:Connect(function(child: Instance)
			if child.Name == BOXES_FOLDER then
				watchFolder(watch, child)
			end
		end)
	)
	for _, name in { OPEN_ATTRIBUTE, EXCLUSIVE_ATTRIBUTE, BREAKER_ATTRIBUTE } do
		table.insert(
			watch.Connections,
			instance:GetAttributeChangedSignal(name):Connect(function()
				refreshStore(watch)
			end)
		)
	end
	local folder = instance:FindFirstChild(BOXES_FOLDER)
	if folder then
		watchFolder(watch, folder)
	end
end

local function unwatchStore(instance: Instance)
	local watch = watches[instance]
	if watch == nil then
		return
	end
	watches[instance] = nil
	for _, connection in watch.Connections do
		connection:Disconnect()
	end
	for _, connection in watch.FolderConnections do
		connection:Disconnect()
	end
	for box in table.clone(watch.Prompts) do
		removePrompt(watch, box)
	end
end

-- Chrono ---------------------------------------------------------------------------------------

local function onHeistTimer(storeId: string, endsAt: number)
	if endsAt > 0 then
		timers[storeId] = endsAt
	else
		timers[storeId] = nil
	end
	if IS_STUDIO then
		-- Le compte à rebours lui-même est à l'écran (HudController, UI_HUD.HeistTimer).
		if endsAt > 0 then
			print(`[Heist] {storeId} : chrono de {math.ceil(endsAt - Workspace:GetServerTimeNow())} s`)
		else
			print(`[Heist] {storeId} : chrono masqué`)
		end
	end
	for _, listener in table.clone(timerListeners) do
		task.spawn(listener, storeId, endsAt)
	end
end

-- API -----------------------------------------------------------------------------------------

function HeistController.OnTimer(listener: TimerListener): () -> ()
	table.insert(timerListeners, listener)
	return function()
		local index = table.find(timerListeners, listener)
		if index then
			table.remove(timerListeners, index)
		end
	end
end

function HeistController.GetTimers(): { [string]: number }
	return table.clone(timers)
end

function HeistController.Start()
	Net = require(Shared:WaitForChild("Net"):WaitForChild("Net"))
	local module = script.Parent:FindFirstChild("AnimationController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any).PlayPlayer) == "function" then
			animation = result :: any
		end
	end

	Net.Client.HeistTimer:Connect(onHeistTimer)

	for _, instance in CollectionService:GetTagged(STORE_TAG) do
		watchStore(instance)
	end
	-- Avec StreamingEnabled, un magasin arrive et repart avec la zone autour du joueur.
	CollectionService:GetInstanceAddedSignal(STORE_TAG):Connect(watchStore)
	CollectionService:GetInstanceRemovedSignal(STORE_TAG):Connect(unwatchStore)
	localPlayer:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(refreshAll)

	while true do
		task.wait(REFRESH_INTERVAL)
		xpcall(refreshAll, function(err: any)
			warn(`[HeistController] {err}`)
		end)
	end
end

return HeistController
