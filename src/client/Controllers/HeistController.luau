--!strict
-- HeistController (DEV-015, client) : invites de prise sur les colis des magasins PNJ et chrono
-- du braquage (Partie 1, sections 5.3 et 9.4).
--
-- Rôle :
--   - Sur chaque colis d'un rayon (dossier `ShelfBoxes` d'un magasin taggé NPCStore, rempli par
--     StoreHeistService), une invite ProximityPrompt créée ici, sur l'Attachment ShelfSlot_xx du
--     colis : maintien = temps de prise du type du colis (attribut Tier du colis, plus de
--     l'emplacement : les colis sont placés au hasard, L-033 ; Balance.Heist.BoxTiers[Tier].GrabTime),
--     portée = Balance.Heist.GrabMaxDistance. Textes en anglais (L-036) : « Steal », « Premium Box ».
--     L'étiquette BB_Box et le contour du colis sont gérés par ShelfBoxController. L'invite n'est
--     active que si le magasin est ouvert
--     (HeistOpen), le colis posé (Landed), les mains vides (attribut Carrying du joueur, posé par
--     CarryService), le joueur dans le volume Bounds du magasin et, pendant l'avance du casseur,
--     seulement pour le casseur.
--   - Début du maintien : GrabItem(slotId). Invite déclenchée : GrabItem(slotId) une seconde fois
--     (le serveur vérifie la durée entre les deux) et animation Grab (AnimationController s'il est
--     là). Le serveur décide de tout : ce contrôleur ne fait que demander.
--   - HeistTimer(storeId, endsAt) : chrono du braquage, endsAt en heure serveur
--     (workspace:GetServerTimeNow()), 0 = masqué. Relayé à OnTimer : HudController l'affiche dans
--     UI_HUD.HeistTimer (DEV-021). En Studio, une ligne dans la sortie à chaque envoi du serveur.
--   - Ouverture sur le rayon (vague 31, L-112), seulement si Features.ShelfOpen (false : tout ce qui
--     précède, inchangé) : sur un colis fermé, l'invite « Open » (maintien = GrabTime du type du colis,
--     comme la prise) demande OpenShelfBox(slotId) au début et à la fin du maintien ; plus d'invite sur
--     ce colis pendant son ouverture (attribut ShelfOpenState,
--     Shared/ShelfOpenState ; l'animation est à ShelfOpenController). Sur l'objet sorti (tag ShelfItem),
--     l'invite « Steal » demande GrabItem(slotId) au début et à la fin du maintien, comme un colis
--     (maintien : Tier de l'objet, sinon celui du colis qui était à cet emplacement) ; cachée chez les
--     autres joueurs tant que ShelfReservedUntil n'est pas passé (le serveur revérifie).
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
local Features = require(Shared:WaitForChild("Config"):WaitForChild("Features"))
local Items = require(Shared:WaitForChild("Config"):WaitForChild("Items"))
local Mutations = require(Shared:WaitForChild("Config"):WaitForChild("Mutations"))
local ShelfOpenState = require(Shared:WaitForChild("ShelfOpenState"))

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
-- V0 proposé, absent du doc : texte de l'invite, en anglais (L-036). Sous lui, le type du colis :
-- « Standard Box », « Premium Box », « Luxury Box » (BoxTiers[Tier].DisplayName + BOX_SUFFIX).
local ACTION_TEXT = "Steal"
local BOX_SUFFIX = "Box"

-- Ouverture sur le rayon (L-112). V0 proposé, absent du doc : textes en anglais (L-036) ; après un appui
-- sur « Open », l'invite reste coupée 1 s en attendant l'état posé par le serveur (pas de double envoi).
local SHELF_OPEN = Features.ShelfOpen
local OPEN_ACTION_TEXT = "Open"
local ITEM_ACTION_TEXT = "Steal"
local ITEM_PROMPT_NAME = "ShelfItemPrompt"
local OPEN_PENDING_TIME = 1

local IS_STUDIO = RunService:IsStudio()

local localPlayer = Players.LocalPlayer

local HeistController = {}

local Net: any = nil
local animation: AnimationApi? = nil
local watches: { [Instance]: StoreWatch } = {}
local timers: { [string]: number } = {}
local timerListeners: { TimerListener } = {}
local openPending: { [Instance]: number } = {} -- colis → os.clock() de l'appui sur « Open »
local tierBySlot: { [string]: string } = {} -- SlotId → Tier du dernier colis vu à cet emplacement
local itemPrompts: { [Model]: ProximityPrompt } = {} -- objets sortis (tag ShelfItem) → leur invite
local saidItemSlot = false

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
	local clock = os.clock()
	for box, prompt in watch.Prompts do
		local enabled = allowed and box:GetAttribute(LANDED_ATTRIBUTE) ~= false
		if SHELF_OPEN and enabled then
			-- Colis fermé seulement, et pas juste après un appui.
			local pendingAt: number? = openPending[box]
			if pendingAt and clock - pendingAt >= OPEN_PENDING_TIME then
				openPending[box] = nil
				pendingAt = nil
			end
			enabled = box:GetAttribute(ShelfOpenState.StateAttribute) == nil and pendingAt == nil
		end
		prompt.Enabled = enabled
	end
end

-- Magasin d'un objet sorti : son ancêtre suivi, sinon celui dont le volume Bounds le contient.
local function storeOfItem(item: Model): StoreWatch?
	local current = item.Parent
	while current ~= nil and current ~= Workspace do
		local watch = watches[current]
		if watch then
			return watch
		end
		current = current.Parent
	end
	local position = item:GetPivot().Position
	for _, watch in watches do
		local bounds = boundsOf(watch)
		if bounds and inside(bounds, position) then
			return watch
		end
	end
	return nil
end

-- L'invite de prise d'un objet sorti : active comme celle d'un colis, et seulement pour l'ouvreur tant que
-- l'objet lui est réservé (ShelfReservedBy, ShelfReservedUntil).
local function refreshItems()
	if next(itemPrompts) == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for item, prompt in itemPrompts do
		local watch = storeOfItem(item)
		local enabled = watch ~= nil and canGrabHere(watch)
		if enabled then
			local reservedUntil = item:GetAttribute(ShelfOpenState.ReservedUntilAttribute)
			if type(reservedUntil) == "number" and now < reservedUntil then
				enabled = item:GetAttribute(ShelfOpenState.ReservedByAttribute) == localPlayer.UserId
			end
		end
		prompt.Enabled = enabled
	end
end

local function refreshAll()
	for _, watch in watches do
		refreshStore(watch)
	end
	refreshItems()
end

local function playGrab()
	local api = animation
	if api then
		pcall(api.PlayPlayer, GRAB_ANIMATION)
	end
end

local function removePrompt(watch: StoreWatch, box: Instance)
	local prompt = watch.Prompts[box]
	openPending[box] = nil
	if prompt then
		watch.Prompts[box] = nil
		prompt:Destroy()
	end
end

-- Objets sortis (L-112) ---------------------------------------------------------------------------

local function removeItemPrompt(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local prompt = itemPrompts[instance :: Model]
	if prompt then
		itemPrompts[instance :: Model] = nil
		prompt:Destroy()
	end
end

local function addItemPrompt(instance: Instance)
	if not instance:IsA("Model") or itemPrompts[instance :: Model] then
		return
	end
	local item = instance :: Model
	local slotId = item:GetAttribute(SLOT_ID_ATTRIBUTE)
	local anchor = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
	if type(slotId) ~= "string" or anchor == nil then
		if IS_STUDIO and not saidItemSlot then
			saidItemSlot = true
			warn(`[HeistController] objet sorti {item.Name} sans attribut SlotId (ou sans pièce) : pas d'invite de prise (L-112)`)
		end
		return
	end
	local tierAttribute = item:GetAttribute(TIER_ATTRIBUTE)
	local tier = if type(tierAttribute) == "string" then tierAttribute else tierBySlot[slotId]
	local info = if tier then Balance.Heist.BoxTiers[tier] else nil
	local itemId = item:GetAttribute("ItemId")
	local def = if type(itemId) == "string" then Items.ById[itemId] else nil
	local mutation = {
		Size = item:GetAttribute("MutationSize"),
		Effect = item:GetAttribute("MutationEffect"),
	}
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = ITEM_PROMPT_NAME
	prompt.ActionText = ITEM_ACTION_TEXT
	prompt.ObjectText = if def then Mutations.ItemName(def.DisplayName, mutation) else ""
	prompt.HoldDuration = if info then info.GrabTime else 0
	prompt.MaxActivationDistance = math.max(Balance.Heist.GrabMaxDistance - PROMPT_DISTANCE_MARGIN, 1)
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.PromptButtonHoldBegan:Connect(function()
		Net.Client.GrabItem:Fire(slotId) -- début du maintien
	end)
	prompt.Triggered:Connect(function()
		Net.Client.GrabItem:Fire(slotId) -- fin du maintien
		playGrab()
	end)
	prompt.Parent = anchor
	itemPrompts[item] = prompt
	refreshItems()
end

local function addPrompt(watch: StoreWatch, box: Instance)
	if watch.Prompts[box] then
		return
	end
	if SHELF_OPEN and CollectionService:HasTag(box, ShelfOpenState.ItemTag) then
		return -- objet sorti : son invite à part (addItemPrompt)
	end
	local slotId = box:GetAttribute(SLOT_ID_ATTRIBUTE)
	local slotName = box:GetAttribute(SLOT_ATTRIBUTE)
	local tier = box:GetAttribute(TIER_ATTRIBUTE)
	if type(slotId) ~= "string" or type(slotName) ~= "string" or type(tier) ~= "string" then
		return
	end
	tierBySlot[slotId] = tier
	local info = Balance.Heist.BoxTiers[tier]
	local anchor = watch.Model:FindFirstChild(slotName, true)
	if info == nil or anchor == nil or not anchor:IsA("Attachment") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = ACTION_TEXT
	prompt.ObjectText = `{info.DisplayName} {BOX_SUFFIX}`
	prompt.HoldDuration = info.GrabTime
	prompt.MaxActivationDistance = math.max(Balance.Heist.GrabMaxDistance - PROMPT_DISTANCE_MARGIN, 1)
	prompt.RequiresLineOfSight = false -- les rayons cachent parfois le colis
	prompt.Enabled = false
	if SHELF_OPEN then
		-- L-112 : rester appuyé ouvre le colis sur place (Cantin, 2026-11-13 : même maintien que la prise,
		-- GrabTime du type) ; le serveur vérifie la durée, tire la chance et décide de tout.
		prompt.ActionText = OPEN_ACTION_TEXT
		prompt.PromptButtonHoldBegan:Connect(function()
			Net.Client.OpenShelfBox:Fire(slotId) -- début du maintien
		end)
		prompt.Triggered:Connect(function()
			openPending[box] = os.clock()
			prompt.Enabled = false
			Net.Client.OpenShelfBox:Fire(slotId) -- fin du maintien
		end)
	else
		prompt.PromptButtonHoldBegan:Connect(function()
			Net.Client.GrabItem:Fire(slotId) -- début du maintien
		end)
		prompt.Triggered:Connect(function()
			Net.Client.GrabItem:Fire(slotId) -- fin du maintien
			playGrab()
		end)
	end
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
	Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
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
	if SHELF_OPEN then
		for _, item in CollectionService:GetTagged(ShelfOpenState.ItemTag) do
			addItemPrompt(item)
		end
		CollectionService:GetInstanceAddedSignal(ShelfOpenState.ItemTag):Connect(addItemPrompt)
		CollectionService:GetInstanceRemovedSignal(ShelfOpenState.ItemTag):Connect(removeItemPrompt)
	end

	while true do
		task.wait(REFRESH_INTERVAL)
		xpcall(refreshAll, function(err: any)
			warn(`[HeistController] {err}`)
		end)
	end
end

return HeistController
