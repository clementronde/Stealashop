--!strict
-- UnboxController (vague 31, L-112 ; client) : les objets sous antivol posés au sol des boutiques.
-- Vague 52 (a170, lot D de la vague 48) : le colis porté, rangé, posé et ouvert en base n'existe plus
-- (décision de Cantin du 2026-11-14) ; les colis s'ouvrent sur place (rayon, camion, coffre). L'ouverture
-- en base (invite « Open » des FloorBox, BoxReady, UnboxReveal, écran UI_Unbox, dossier Unbox sauf
-- AntiTheftChains, retenue du revenu du HUD) est retirée. Le nom du fichier reste (contrat, bancs).
--
-- Rôle :
--   - sur chaque objet sous antivol posé au sol (Model FloorItem d'UnboxService, tag de code FloorItem,
--     toutes les boutiques), une copie de BB_AntiTheft de Clément (sinon un billboard V0 aux mêmes noms)
--     accrochée au-dessus de l'objet : ItemName = son nom (mutation devant) à la couleur de sa rareté,
--     TimeLabel = le temps restant (m:ss, attribut UnlockAt, heure serveur), puis « UNLOCKED! » en vert
--     (5cff4a), avec UI_Success chez le propriétaire (son V0). Invites créées ici : chez le propriétaire,
--     « Take » une fois débloqué → OpenBox(itemUid) (a152 : le serveur le reprend, en main ou dans
--     l'inventaire) ; chez les autres, « Steal » (maintien PvP.StealGrabTime) pendant l'antivol, boutique
--     ouverte au vol (StealOpen de la parcelle) et mains vides → StealFloorItem(plotIndex, itemUid) au début
--     et à la fin du maintien, animation Grab. Le serveur revérifie tout.
--     UnboxController.GetFloorView(model) -> { TimeText, ItemText, OwnerPrompt, StealPrompt, Chains }? (bancs).
--   - vague 34 (L-127 point 4, Clément) : sur cet objet encore sous antivol à son arrivée, les chaînes et le
--     cadenas du kit ReplicatedStorage/Assets/FX/FX_AntiTheft, posés une fois côté client autour de l'objet
--     (Unbox/AntiTheftChains, reprise de wrap(item) de tools/clement/antitheft_proto.luau), dans un Model
--     AntiTheftChains sous l'objet, ancrés, sans collision ni requête. À « UNLOCKED! » : le cadenas saute de
--     0,3 × k en 0,12 s, tout passe en transparence 1 en 0,25 s et est détruit. Kit absent : rien (une ligne
--     dans la sortie). BB_AntiTheft reste au-dessus de l'objet.
--   - a178 (Cantin, 15/11) : BB_AntiTheft se montre selon la distance entre le personnage local et l'objet
--     (Config/Unbox.LockShowDistance), quel que soit le zoom : sa MaxDistance (comptée depuis la caméra) est
--     levée et Enabled suit cette distance. Un objet tenu en main encore sous antivol (Model HeldItem, tag
--     CarriedItem, attributs AntiTheft et UnlockAt de HeldItemService) porte le même BB_AntiTheft (nom,
--     minuteur, ou Unbox.LockedText sans UnlockAt), retiré à la fin de l'antivol ou quand l'objet quitte la main.
--     UnboxController.GetHeldView(model) -> { TimeText, Shown }? (bancs).
--   - vague 63 (a205, L-202 point 3) : BB_AntiTheft.LockIcon (cadenas doré de Clément, facultatif) caché quand
--     TimeLabel passe à « UNLOCKED! » sur un objet posé au sol, visible sinon ; sur l'objet tenu, il reste tel que
--     Clément l'a posé (le billboard part avec l'antivol). GetFloorView(model).LockIcon (bancs).
-- Aucune règle de jeu : le serveur décide.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local PvP = require(Config:WaitForChild("PvP"))
local Items = require(Config:WaitForChild("Items"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Unbox = require(Config:WaitForChild("Unbox"))
local HeldItem = require(Config:WaitForChild("HeldItem"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local UI = require(Shared:WaitForChild("Contract"):WaitForChild("UI"))
local UnboxFolder = script.Parent:WaitForChild("Unbox")
-- Vague 34 : module d'aide des chaînes ; absent (faux arbres des bancs d'avant la vague 34), pas de chaînes.
local AntiTheftChains = if UnboxFolder:FindFirstChild("AntiTheftChains")
	then require(UnboxFolder:WaitForChild("AntiTheftChains")) -- déjà là : pas d'attente
	else nil

type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
}

-- Vague 31 (L-112) : un objet sous antivol posé au sol, son BB_AntiTheft et son invite.
type FloorView = {
	model: Model,
	uid: string,
	mine: boolean, -- objet du joueur local : invite « Display » ; sinon « Steal »
	gui: BillboardGui,
	point: Attachment,
	timeLabel: TextLabel?,
	lockIcon: GuiObject?, -- vague 63 (L-202 point 3) : cadenas doré de BB_AntiTheft, caché à « UNLOCKED! »
	ownerPrompt: ProximityPrompt?,
	stealPrompt: ProximityPrompt?,
	unlocked: boolean,
	seenLocked: boolean, -- vu sous antivol ici (le son de « UNLOCKED! » ne part qu'à la fin vue)
	chains: Model?, -- vague 34 (L-127 point 4) : chaînes et cadenas posés sur l'objet (AntiTheftChains)
	connections: { RBXScriptConnection },
}

-- Contrat et attributs posés par les services serveur (lus sans require).
local OWNER_ATTRIBUTE = "OwnerUserId" -- UnboxService : propriétaire de l'objet posé
local ITEM_UID_ATTRIBUTE = "ItemUid" -- UnboxService : uid de l'objet posé
local PROMPT_NAME = "UnboxPrompt"

-- V0 proposé, absent du doc : portée de l'invite « Take » (Config.Unbox). Le serveur accepte la portée
-- + Config.Unbox.ReachTolerance (UnboxService).
local PROMPT_DISTANCE = Unbox.PromptDistance

-- Vague 31 (L-112) : objets sous antivol posés au sol (UnboxService : Model FloorItem, tag de code FloorItem,
-- attributs ItemUid, ItemId, OwnerUserId, MutationSize, MutationEffect, UnlockAt ; parcelle : PlotIndex,
-- StealOpen de PvPService ; joueur : Carrying de CarryService).
local FLOOR_ITEM_NAME = "FloorItem"
local FLOOR_ITEM_TAG = "FloorItem"
local UNLOCK_AT_ATTRIBUTE = "UnlockAt"
local PLOT_INDEX_ATTRIBUTE = "PlotIndex"
local STEAL_OPEN_ATTRIBUTE = "StealOpen"
local CARRYING_ATTRIBUTE = "Carrying"
local ANTI_THEFT_BILLBOARD = "BB_AntiTheft" -- L-112 : ItemName, TimeLabel (MaxDistance 10, de Clément)
local ANTI_THEFT_POINT = "AntiTheftPoint"
local LOCK_ICON = "LockIcon" -- vague 63 (L-202 point 3) : cadenas de BB_AntiTheft, facultatif
local STEAL_PROMPT_NAME = "StealFloorPrompt"
-- L-112 : « UNLOCKED! » en vert (5cff4a, la couleur de BB_ShelfOpen) ; son V0 en attendant celui de Clément.
local UNLOCKED_TEXT = "UNLOCKED!"
local UNLOCKED_COLOR = Color3.fromHex("5cff4a")
local UNLOCK_SOUND = "UI_Success"
-- V0 proposé, absent du doc : textes des invites (anglais, L-036), marge de portée de l'invite de vol (comme
-- PvPController) et cadence (s) du minuteur.
local TAKE_TEXT = "Take" -- vague 44 (a152) : l'objet débloqué se reprend (en main ou dans l'inventaire), « Display » avant
local STEAL_TEXT = "Steal"
local STEAL_DISTANCE_MARGIN = 0.5
-- a265 (vague 79), V0 proposé, absent du doc : relâché plus de 0,1 s avant la fin du maintien = annulé ("Cancel"
-- envoyé au serveur, qui vide le maintien). La marge évite d'annuler un maintien conclu si le relâché arrive avant Triggered.
local HOLD_CANCEL_MARGIN = 0.1
local FLOOR_TICK = 0.1

local UnboxController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local animation: AnimationApi? = nil
-- Vague 31 : objets sous antivol affichés au sol, par modèle (toutes les boutiques).
local floorViews: { [Instance]: FloorView } = {}
-- a178 : objets tenus en main encore sous antivol, par modèle HeldItem.
type HeldView = { model: Model, gui: BillboardGui, point: Attachment, timeLabel: TextLabel?, connection: RBXScriptConnection? }
local heldViews: { [Instance]: HeldView } = {}
local floorElapsed = 0
local antiTheftMissingWarned = false
local chainsMissingWarned = false

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

-- Joue une animation du joueur ; true si elle joue (livrée, personnage présent).
local function playAnimation(name: string): boolean
	local anim = animation
	if anim == nil then
		return false
	end
	local ok, track = pcall(anim.PlayPlayer, name)
	return ok and track ~= nil
end

------------------------------------------------------------------------------
-- Objets sous antivol posés au sol (vague 31, L-112)
------------------------------------------------------------------------------

-- Son d'interface de Clément (UI/Motion.PlaySound), s'il est là ; sinon rien.
local function playUiSound(name: string)
	local ui = script.Parent:FindFirstChild("UI")
	local module = if ui then ui:FindFirstChild("Motion") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return
	end
	local ok, motion = pcall(require, module)
	local play: any = if ok and type(motion) == "table" then (motion :: any).PlaySound else nil
	if type(play) == "function" then
		pcall(play, name)
	end
end

-- Billboard BB_AntiTheft de Clément (ReplicatedStorage/Assets/UI), sinon un billboard V0 aux mêmes noms.
local function antiTheftBillboard(): BillboardGui
	local folder: Instance? = ReplicatedStorage
	for _, name in UI.BillboardFolder do
		folder = if folder then folder:FindFirstChild(name) else nil
	end
	local template = if folder then folder:FindFirstChild(ANTI_THEFT_BILLBOARD) else nil
	if template and template:IsA("BillboardGui") then
		return template:Clone() :: BillboardGui
	end
	if not antiTheftMissingWarned then
		antiTheftMissingWarned = true
		print(`[UnboxController] {ANTI_THEFT_BILLBOARD} pas encore livré : billboard V0 au-dessus des objets sous antivol`)
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(4, 40, 1.9, 24)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 10
	gui.LightInfluence = 0
	for index, name in { "ItemName", "TimeLabel" } do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.fromScale(1, 0.5)
		label.Position = UDim2.fromScale(0, (index - 1) * 0.5)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Text = ""
		label.Parent = gui
	end
	return gui
end

local function floorLabel(gui: Instance, name: string): TextLabel?
	local found = Find.path(gui, name)
	return if found and found:IsA("TextLabel") then found :: TextLabel else nil
end

-- Vague 63 (L-202 point 3) : LockIcon de BB_AntiTheft (cadenas doré de Clément), ou nil (billboard V0, ancien BB).
local function lockIconOf(gui: Instance): GuiObject?
	local found = Find.path(gui, LOCK_ICON)
	return if found and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function floorTimeText(remaining: number): string
	local seconds = math.max(0, math.ceil(remaining))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function removeFloorView(model: Instance)
	local view = floorViews[model]
	if view == nil then
		return
	end
	floorViews[model] = nil
	for _, connection in view.connections do
		connection:Disconnect()
	end
	for _, inst in { view.gui, view.point, view.ownerPrompt, view.stealPrompt, view.chains } :: { Instance? } do
		if inst then
			inst:Destroy()
		end
	end
end

-- a178 : d'où se compte la distance du verrou : le personnage local (nil : pas encore de personnage).
local function lockOrigin(): Vector3?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

-- a178 : BB_AntiTheft allumé à LockShowDistance studs au plus du personnage, quel que soit le zoom ; sans
-- personnage, allumé (comme avant).
local function showLock(gui: BillboardGui, point: Attachment, origin: Vector3?)
	local shown = origin == nil or (point.WorldPosition - origin).Magnitude <= Unbox.LockShowDistance
	if gui.Enabled ~= shown then
		gui.Enabled = shown
	end
end

-- Remet à jour le minuteur et les invites d'un objet sous antivol (heure serveur, attributs du serveur).
local function refreshFloorView(view: FloorView, now: number, origin: Vector3?)
	showLock(view.gui, view.point, origin)
	local unlockAt = view.model:GetAttribute(UNLOCK_AT_ATTRIBUTE)
	local remaining = if type(unlockAt) == "number" then unlockAt - now else 0
	local unlocked = remaining <= 0
	local label = view.timeLabel
	if label then
		local text = if unlocked then UNLOCKED_TEXT else floorTimeText(remaining)
		if label.Text ~= text then
			label.Text = text
		end
		if unlocked and not view.unlocked then
			label.TextColor3 = UNLOCKED_COLOR
		end
	end
	-- Vague 63 (L-202 point 3) : le cadenas doré disparaît avec « UNLOCKED! » (le cadenas 3D saute déjà).
	local lockIcon = view.lockIcon
	if lockIcon and lockIcon.Visible == unlocked then
		lockIcon.Visible = not unlocked
	end
	if unlocked and not view.unlocked then
		view.unlocked = true
		local chains = view.chains
		if chains then
			if AntiTheftChains then AntiTheftChains.Release(chains) end -- vague 34 : le cadenas saute, tout s'efface, puis est détruit
		end
		if view.mine and view.seenLocked then
			playUiSound(UNLOCK_SOUND) -- « UNLOCKED! » chez le propriétaire (V0 : UI_Success)
		end
	elseif not unlocked then
		view.seenLocked = true
	end
	local ownerPrompt = view.ownerPrompt
	if ownerPrompt then
		ownerPrompt.Enabled = unlocked
	end
	local stealPrompt = view.stealPrompt
	if stealPrompt then
		local parent = view.model.Parent
		local open = parent ~= nil and parent:GetAttribute(STEAL_OPEN_ATTRIBUTE) == true
		stealPrompt.Enabled = not unlocked and open and localPlayer:GetAttribute(CARRYING_ATTRIBUTE) == nil
	end
end

local function addFloorView(inst: Instance)
	if floorViews[inst] or not inst:IsA("Model") or inst.Name ~= FLOOR_ITEM_NAME then
		return
	end
	local model = inst :: Model
	local holder = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local itemUid = model:GetAttribute(ITEM_UID_ATTRIBUTE)
	local itemId = model:GetAttribute("ItemId")
	if holder == nil or type(itemUid) ~= "string" or type(itemId) ~= "string" then
		-- Pas encore arrivé en entier (streaming) : réessai à l'arrivée d'une pièce.
		local retry: RBXScriptConnection? = nil
		retry = model.DescendantAdded:Connect(function()
			if retry then
				retry:Disconnect()
			end
			addFloorView(model)
		end)
		return
	end
	local part = holder :: BasePart
	local def = Items.ById[itemId]
	local rarity = if def then Rarities.ById[def.Rarity] else nil
	local mutation = Mutations.Sanitize({ Size = model:GetAttribute("MutationSize"), Effect = model:GetAttribute("MutationEffect") })
	local name = if def then Mutations.ItemName(def.DisplayName, mutation) else itemId
	local mine = model:GetAttribute(OWNER_ATTRIBUTE) == localPlayer.UserId

	-- Billboard posé au-dessus de l'objet (sommet de sa boîte) : son StudsOffset part de là.
	local boxCFrame, boxSize = model:GetBoundingBox()
	local point = Instance.new("Attachment")
	point.Name = ANTI_THEFT_POINT
	point.Parent = part
	point.WorldPosition = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2, 0)
	local gui = antiTheftBillboard()
	gui.Name = ANTI_THEFT_BILLBOARD
	gui.Adornee = point
	gui.MaxDistance = math.huge -- a178 : la distance au personnage décide (showLock)
	local itemLabel = floorLabel(gui, "ItemName")
	if itemLabel then
		itemLabel.Text = name
		if rarity then
			itemLabel.TextColor3 = rarity.Color
		end
	end
	gui.Parent = part

	local view: FloorView = {
		model = model,
		uid = itemUid,
		mine = mine,
		gui = gui,
		point = point,
		timeLabel = floorLabel(gui, "TimeLabel"),
		lockIcon = lockIconOf(gui),
		ownerPrompt = nil,
		stealPrompt = nil,
		unlocked = false,
		seenLocked = false,
		chains = nil,
		connections = {},
	}
	-- Vague 34 (L-127 point 4) : chaînes et cadenas de Clément autour de l'objet, posés une fois, seulement
	-- s'il est encore sous antivol à son arrivée (un objet déjà débloqué n'en a pas).
	local unlockAt = model:GetAttribute(UNLOCK_AT_ATTRIBUTE)
	if type(unlockAt) == "number" and unlockAt > Workspace:GetServerTimeNow() then
		local api = AntiTheftChains
		local kit = if api then api.Kit() else nil
		if api and kit then
			local ok, chains = pcall(api.Wrap, model, kit)
			if ok then
				view.chains = chains
			else
				warn(`[UnboxController] chaînes de l'antivol ({itemUid}) : {chains}`)
			end
		elseif not chainsMissingWarned then
			chainsMissingWarned = true
			print("[UnboxController] FX_AntiTheft pas encore livré (ReplicatedStorage/Assets/FX) : pas de chaînes sur les objets sous antivol")
		end
	end
	if mine then
		-- Propriétaire : « Take » une fois l'antivol fini (OpenBox : le serveur le reprend, en main ou dans l'inventaire).
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.ActionText = TAKE_TEXT
		prompt.ObjectText = name
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Enabled = false
		table.insert(
			view.connections,
			prompt.Triggered:Connect(function()
				if net then
					net.Client.OpenBox:Fire(itemUid)
				end
			end)
		)
		prompt.Parent = part
		view.ownerPrompt = prompt
	else
		-- Autre joueur : « Steal » pendant l'antivol, boutique ouverte au vol (StealFloorItem en deux appels).
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = STEAL_PROMPT_NAME
		prompt.ActionText = STEAL_TEXT
		prompt.ObjectText = name
		prompt.HoldDuration = PvP.StealGrabTime
		prompt.MaxActivationDistance = math.max(PvP.StealMaxDistance - STEAL_DISTANCE_MARGIN, 1)
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		-- a265 (vague 79) : étape envoyée avec chaque appel ; relâché avant la fin = "Cancel" (le serveur vide le maintien).
		local function fire(phase: string)
			local plotModel = model.Parent
			local plotIndex = if plotModel then plotModel:GetAttribute(PLOT_INDEX_ATTRIBUTE) else nil
			if net and type(plotIndex) == "number" then
				net.Client.StealFloorItem:Fire(plotIndex, itemUid, phase)
			end
		end
		local holdBegan: number? = nil
		table.insert(
			view.connections,
			prompt.PromptButtonHoldBegan:Connect(function()
				holdBegan = os.clock()
				fire("Begin") -- début du maintien
			end)
		)
		table.insert(
			view.connections,
			prompt.PromptButtonHoldEnded:Connect(function()
				local began = holdBegan
				holdBegan = nil
				if began and os.clock() - began < prompt.HoldDuration - HOLD_CANCEL_MARGIN then
					fire("Cancel")
				end
			end)
		)
		table.insert(
			view.connections,
			prompt.Triggered:Connect(function()
				holdBegan = nil
				fire("End") -- fin du maintien
				playAnimation("Grab")
			end)
		)
		prompt.Parent = part
		view.stealPrompt = prompt
	end
	table.insert(
		view.connections,
		model.AncestryChanged:Connect(function()
			if model.Parent == nil then
				removeFloorView(model) -- volé (porté) ou repris : le serveur le sort du monde
			end
		end)
	)
	floorViews[model] = view
	refreshFloorView(view, Workspace:GetServerTimeNow(), lockOrigin())
end

------------------------------------------------------------------------------
-- a178 : objet tenu en main encore sous antivol (HeldItemService)
------------------------------------------------------------------------------

local function removeHeldView(model: Instance)
	local view = heldViews[model]
	if view == nil then
		return
	end
	heldViews[model] = nil
	if view.connection then
		view.connection:Disconnect()
	end
	view.gui:Destroy()
	view.point:Destroy()
end

-- Minuteur du verrou en main ; false : l'antivol est fini (le verrou part).
local function refreshHeldView(view: HeldView, now: number, origin: Vector3?): boolean
	local unlockAt = view.model:GetAttribute(HeldItem.UnlockAtAttribute)
	if view.model:GetAttribute(HeldItem.LockedAttribute) ~= true or (type(unlockAt) == "number" and unlockAt <= now) then
		return false
	end
	local label = view.timeLabel
	if label then
		local text = if type(unlockAt) == "number" then floorTimeText(unlockAt - now) else Unbox.LockedText
		if label.Text ~= text then
			label.Text = text
		end
	end
	showLock(view.gui, view.point, origin)
	return true
end

local function addHeldView(inst: Instance)
	if heldViews[inst] or not inst:IsA("Model") or inst.Name ~= HeldItem.ModelName then
		return
	end
	local model = inst :: Model
	if model:GetAttribute(HeldItem.LockedAttribute) ~= true then
		return
	end
	local holder = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local itemId = model:GetAttribute("ItemId")
	if holder == nil or type(itemId) ~= "string" then
		local retry: RBXScriptConnection? = nil
		retry = model.DescendantAdded:Connect(function()
			if retry then
				retry:Disconnect()
			end
			addHeldView(model)
		end)
		return
	end
	local part = holder :: BasePart
	local def = Items.ById[itemId]
	local rarity = if def then Rarities.ById[def.Rarity] else nil
	local mutation = Mutations.Sanitize({ Size = model:GetAttribute("MutationSize"), Effect = model:GetAttribute("MutationEffect") })
	local boxCFrame, boxSize = model:GetBoundingBox()
	local point = Instance.new("Attachment")
	point.Name = ANTI_THEFT_POINT
	point.Parent = part
	point.WorldPosition = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2, 0)
	local gui = antiTheftBillboard()
	gui.Name = ANTI_THEFT_BILLBOARD
	gui.Adornee = point
	gui.MaxDistance = math.huge
	local itemLabel = floorLabel(gui, "ItemName")
	if itemLabel then
		itemLabel.Text = if def then Mutations.ItemName(def.DisplayName, mutation) else itemId
		if rarity then
			itemLabel.TextColor3 = rarity.Color
		end
	end
	gui.Parent = part
	local view: HeldView = { model = model, gui = gui, point = point, timeLabel = floorLabel(gui, "TimeLabel"), connection = nil }
	-- Tool détruit (rangé, posé, autre outil) : le tag CarriedItem part avec lui (Start), ou le modèle est sorti.
	view.connection = model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			removeHeldView(model)
		end
	end)
	heldViews[model] = view
	if not refreshHeldView(view, Workspace:GetServerTimeNow(), lockOrigin()) then
		removeHeldView(model)
	end
end

local function stepFloorViews(dt: number)
	if AntiTheftChains then AntiTheftChains.Step(dt) end -- fin de l'antivol : à chaque image, seulement pendant l'animation
	floorElapsed += dt
	if floorElapsed < FLOOR_TICK then
		return
	end
	floorElapsed = 0
	local now = Workspace:GetServerTimeNow()
	local origin = lockOrigin()
	for _, view in floorViews do
		refreshFloorView(view, now, origin)
	end
	for model, view in heldViews do
		if not refreshHeldView(view, now, origin) then
			removeHeldView(model) -- a178 : fin de l'antivol, le verrou en main part
		end
	end
end

function UnboxController.GetHeldView(model: Instance): { TimeText: string?, Shown: boolean }?
	local view = heldViews[model]
	if view == nil then
		return nil
	end
	return { TimeText = if view.timeLabel then view.timeLabel.Text else nil, Shown = view.gui.Enabled }
end

local function chainsShown(view: FloorView): boolean
	local chains = view.chains
	local api = AntiTheftChains
	return api ~= nil and chains ~= nil and chains.Parent ~= nil and not api.IsReleasing(chains)
end

function UnboxController.GetFloorView(
	model: Instance
): { TimeText: string?, ItemText: string?, OwnerPrompt: boolean?, StealPrompt: boolean?, Chains: boolean, LockIcon: boolean? }?
	local view = floorViews[model]
	if view == nil then
		return nil
	end
	local ownerPrompt, stealPrompt = view.ownerPrompt, view.stealPrompt
	local itemLabel = floorLabel(view.gui, "ItemName")
	return {
		TimeText = if view.timeLabel then view.timeLabel.Text else nil,
		ItemText = if itemLabel then itemLabel.Text else nil,
		OwnerPrompt = if ownerPrompt then ownerPrompt.Enabled else nil,
		StealPrompt = if stealPrompt then stealPrompt.Enabled else nil,
		Chains = chainsShown(view), -- vague 34 : chaînes posées, pas encore en train de partir
		LockIcon = if view.lockIcon then view.lockIcon.Visible else nil, -- vague 63 : cadenas doré montré
	}
end

function UnboxController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	animation = loadAnimationController()

	-- Vague 31 (L-112) : objets sous antivol posés au sol, toutes les boutiques (tag de code FloorItem).
	CollectionService:GetInstanceAddedSignal(FLOOR_ITEM_TAG):Connect(addFloorView)
	CollectionService:GetInstanceRemovedSignal(FLOOR_ITEM_TAG):Connect(removeFloorView)
	for _, inst in CollectionService:GetTagged(FLOOR_ITEM_TAG) do
		addFloorView(inst)
	end
	-- a178 : objet tenu en main sous antivol (HeldItemService : Model HeldItem, tag CarriedItem).
	CollectionService:GetInstanceAddedSignal(HeldItem.CarriedTag):Connect(addHeldView)
	CollectionService:GetInstanceRemovedSignal(HeldItem.CarriedTag):Connect(removeHeldView)
	for _, inst in CollectionService:GetTagged(HeldItem.CarriedTag) do
		addHeldView(inst)
	end
	RunService.Heartbeat:Connect(stepFloorViews)
end

return UnboxController
