--!strict
-- RevealController (client, vague 62, a204 ; décision de Cantin et Clément du 2026-11-15, liaison L-198 ; valeurs :
-- Config/Reveal ; noms : Contract/Animations.Reveal, Contract/Models (Ceiling), Contract/UI (BB_Reveal)) : la
-- cinématique d'ouverture d'un colis sur son rayon, vue par tous. Interrupteur : Features.SingleBoxReveal (faux :
-- rien ne se branche).
--
-- Le serveur (a202) décide de tout et envoie RevealStarted à tous les clients (ouvreur, magasin, rayon, objet,
-- rareté, mutation d'effet, poids, taille finale, classe de taille, id), puis RevealEnded à la fin de la phase.
-- Ici, sans rien décider :
--   1. une scène par RevealStarted, jouée par l'ouvreur et par chaque joueur à moins de SpectatorMaxDistance du rayon
--      (les autres n'en voient rien ; leur plafond suit quand même CeilingBroken). La scène :
--      - copie locale du rig CAM_Reveal de Clément (facultatif, Config/Reveal.RigPath), ItemAnchor posé sur
--        l'emplacement du rayon, face avant (−Z) tournée vers l'allée du magasin (centre de son volume Bounds) ;
--      - copie locale de l'objet (ITM_<ItemId> de Assets/Items, sinon un bloc V0 à la couleur de la rareté), cachée
--        jusqu'au Reveal, tenue sur ItemAnchor ; le colis du rayon et un éventuel objet sorti du serveur sur ce rayon
--        sont cachés en local pendant la scène ;
--      - étape 1, Open<Rareté> : marqueurs Open (son Unbox_Open) et Reveal (l'objet sort de PopFrom à sa taille de
--        départ, Back Out ; colis caché ; FX_ShelfReveal aux couleurs de la rareté ; sons ; billboard BB_Reveal, ou V0 :
--        nom, rareté, poids « 1 250 kg », mutation ; chez l'ouvreur, flash d'UI_Escape à partir de FlashMinRarity) ;
--      - étape 2, Grow<Classe> : Grow et Top (l'objet grandit de sa taille de départ à sa taille finale entre les deux,
--        au fil de la piste ; Top inconnu d'avance : la fin de l'animation, ou son image clé « Top » si elle est
--        nommée), Explode (Large et Colossal : le plafond saute, Reveal/Ceiling), Land (fin) ;
--      - un marqueur absent tombe à la fin de son animation (Explode : à Top) ; une animation absente, ou encore
--        vide au bout de AnimLoadWait s, joue son étape en repli codé (mêmes marqueurs, instants de Fallback) ;
--      - plafond client : MaxSeconds[classe] ; ensuite tout ce qui reste est joué d'un coup jusqu'à Land.
--   2. l'ouvreur, en plus : caméra Scriptable qui suit CameraPart (écart à ItemAnchor × la taille montrée de l'objet ;
--      repli : devant l'objet, côté allée, à Distance × taille, et pour un Colossal après Explode, vue de loin devant la
--      vitrine), HUD masqué (Controllers/UI/HudMask, clé MaskKey ; seuls KeepScreens et HeistFeel.NeverMask restent).
--      À Land : RevealDone(revealId) au serveur (une fois), caméra et HUD rendus. Mort, personnage retiré, nouvelle
--      cinématique ou RevealEnded avant Land : caméra et HUD rendus aussi (sans RevealDone).
--   3. après Land, l'objet local reste jusqu'à RevealEnded (l'objet passe sur la tête de l'ouvreur), au plus HoldMax s ;
--      puis tout ce qui a été créé est détruit et tout ce qui a été caché est remis. Ouvreur parti : fin.
-- Deux cinématiques en même temps (deux magasins) : deux scènes, chacune la sienne ; la caméra n'est prise que pour
-- la sienne.
--
-- API (client, pour un banc ou la barre de commande) :
--   RevealController.Play(payload)  joue une scène comme RevealStarted (payload = table aux noms du contrat)
--   RevealController.End(revealId)  comme RevealEnded
--   RevealController.GetState() -> { Started, Finished, Skipped, DoneSent, Scenes = { { Id, Opener, Stage, Mode,
--     Fired, Scale, Camera, Item, Rig } } }

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Reveal = require(Config:WaitForChild("Reveal"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local UI = require(Shared:WaitForChild("Contract"):WaitForChild("UI"))
local AnimPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("AnimPlayer"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
local HudMask = require(script.Parent:WaitForChild("UI"):WaitForChild("HudMask"))
local RevealFolder = script.Parent:WaitForChild("Reveal")
local Logic = require(RevealFolder:WaitForChild("Logic"))
local Ceiling = require(RevealFolder:WaitForChild("Ceiling"))

type Payload = Logic.Payload
type SizeClass = Logic.SizeClass

type Scene = {
	id: string,
	payload: Payload,
	opener: boolean,
	store: Model?,
	slot: string, -- nom de l'Attachment du rayon
	base: CFrame, -- pied de l'objet, LookVector vers l'allée
	aisle: Vector3,
	front: Vector3, -- du centre du magasin vers la rue
	frontPoint: Vector3,
	t: number, -- secondes depuis le début
	stage: string, -- "Open", "Grow", "Hold"
	stageT: number,
	mode: string, -- "Anim" ou "Fallback" (étape en cours)
	track: AnimationTrack?,
	trackStopped: boolean,
	trackConnections: { RBXScriptConnection },
	timeline: Logic.Timeline,
	fired: { [string]: boolean },
	growAt: number?, -- TimePosition de la piste au marqueur Grow (Anim) ou stageT (repli)
	topAt: number?,
	revealT: number?,
	spin: number,
	rig: Model?,
	animator: Animator?,
	animFolder: Instance?,
	camPart: BasePart?,
	anchorPart: BasePart?,
	item: Model?,
	itemBaseScale: number,
	itemHeight: number, -- hauteur à la taille 1
	shownScale: number,
	appliedScale: number,
	startScale: number,
	board: BillboardGui?,
	created: { Instance },
	hidden: { [BasePart]: number },
	connections: { RBXScriptConnection },
	cameraTaken: boolean,
	cameraType: Enum.CameraType?,
	cameraSubject: Instance?,
	blend: number,
	blendFrom: CFrame?,
	masked: boolean,
	doneSent: boolean,
	pending: boolean,
	holdT: number,
}

local RevealController = {}

local localPlayer = Players.LocalPlayer
local IS_STUDIO = RunService:IsStudio()
local FX_FOLDER = "_RevealFX"
local SHELF_BOX_TAG = "ShelfBox"
local SHELF_ITEM_TAG = "ShelfItem"
local STORE_TAG = "NPCStore"
local EVENT_SHELF_TAG = "EventShelf"
local UP = Vector3.new(0, 1, 0)

local scenes: { [string]: Scene } = {}
local order: { string } = {}
local started, finished, skipped, doneSent = 0, 0, 0, 0
local said: { [string]: boolean } = {}
local net: any = nil
local siblings: { [string]: any } = {}

local function sayOnce(key: string, message: string)
	if IS_STUDIO and not said[key] then
		said[key] = true
		print(`[Reveal] {message}`)
	end
end

local function sibling(name: string): any
	if siblings[name] ~= nil then
		return siblings[name] or nil
	end
	local module = script.Parent:FindFirstChild(name)
	local result: any = false
	if module and module:IsA("ModuleScript") then
		local ok, loaded = pcall(require, module)
		if ok and type(loaded) == "table" then
			result = loaded
		end
	end
	siblings[name] = result
	return result or nil
end

local function lowEnd(): boolean
	local shatter = sibling("ShatterController")
	if shatter and type(shatter.IsLowEnd) == "function" then
		local ok, result = pcall(shatter.IsLowEnd)
		return ok and result == true
	end
	return false
end

local function fxFolder(): Instance
	local existing = Workspace:FindFirstChild(FX_FOLDER)
	if existing then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = FX_FOLDER
	f.Parent = Workspace
	return f
end

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

local function partsOf(root: Instance): { BasePart }
	local out: { BasePart } = {}
	if root:IsA("BasePart") then
		table.insert(out, root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function hideLocal(scene: Scene, root: Instance)
	for _, part in partsOf(root) do
		if scene.hidden[part] == nil then
			scene.hidden[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
end

local function stripScripts(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
end

local function quiet(root: Instance)
	for _, part in partsOf(root) do
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
end

local function playSound(name: string, at: Instance?)
	local template = MarkerSounds.find(name)
	if template == nil then
		sayOnce(`sound:{name}`, `son « {name} » absent de ReplicatedStorage.Assets.Sounds : pas joué (L-198)`)
		return
	end
	pcall(MarkerSounds.playSound, template, at)
end

local function rarityOrder(id: string): number
	local rarity = Rarities.ById[id]
	return if rarity then rarity.Order else 0
end

-- Magasin, rayon, cadre ----------------------------------------------------------------------------------------

local function findStore(shopId: string): Model?
	for _, tag in { STORE_TAG, EVENT_SHELF_TAG } do
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsA("Model") and (inst:GetAttribute("StoreId") == shopId or inst.Name == shopId) then
				return inst
			end
		end
	end
	return nil
end

local function taggedIn(tag: string, store: Model, slot: string, slotName: string): Instance?
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(store) and (inst:GetAttribute("Slot") == slot or inst:GetAttribute("SlotId") == slotName) then
			return inst
		end
	end
	return nil
end

local function rootOf(player: Player?): BasePart?
	local character = if player then player.Character else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Pied de l'objet (position), et la direction de l'allée, de la rue et le point de la vitrine.
local function frameOf(store: Model?, payload: Payload, slot: string): (Vector3?, CFrame?, Vector3?, Vector3?)
	local position: Vector3? = nil
	local slotFrame: CFrame? = nil
	if store then
		local attachment = store:FindFirstChild(slot, true)
		if attachment and attachment:IsA("Attachment") then
			slotFrame = attachment.WorldCFrame
		else
			local box = taggedIn(SHELF_BOX_TAG, store, slot, payload.SlotName) or taggedIn(SHELF_ITEM_TAG, store, slot, payload.SlotName)
			if box and box:IsA("PVInstance") then
				slotFrame = (box :: PVInstance):GetPivot()
			end
		end
	end
	if slotFrame then
		position = slotFrame.Position
	else
		local root = rootOf(payload.Opener)
		if root then
			local front = root.CFrame * CFrame.new(0, -3, -4)
			slotFrame = front
			position = front.Position
		end
	end
	if position == nil then
		return nil, nil, nil, nil
	end
	local center: Vector3? = nil
	local window: Vector3? = nil
	if store then
		local bounds = store:FindFirstChild("Bounds", true)
		center = if bounds and bounds:IsA("BasePart") then bounds.Position else store:GetPivot().Position
		local glass = store:FindFirstChild("Window", true)
		if glass and glass:IsA("BasePart") then
			window = glass.Position
		elseif glass and glass:IsA("Model") then
			window = glass:GetPivot().Position
		end
	end
	return position, slotFrame, center, window
end

-- Objet ---------------------------------------------------------------------------------------------------------

local function v0Item(color: Color3): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1.2, 1.6, 1.2)
	root.CFrame = CFrame.new(0, 0.8, 0)
	root.PivotOffset = CFrame.new(0, -0.8, 0)
	root.Color = color
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildItem(payload: Payload): Model
	local def = Items.ById[payload.ItemId]
	local rarity = Rarities.ById[payload.Rarity]
	local model: Model? = nil
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("Items") else nil
	local template = if folder and def then folder:FindFirstChild(def.Asset, true) else nil
	if template and (template:IsA("Model") or template:IsA("BasePart")) then
		local clone = template:Clone()
		if clone then
			stripScripts(clone)
			if clone:IsA("Model") then
				model = clone
			elseif clone:IsA("BasePart") then
				local wrapper = Instance.new("Model")
				clone.Parent = wrapper
				wrapper.PrimaryPart = clone
				model = wrapper
			end
		end
	else
		sayOnce(`item:{payload.ItemId}`, `modèle de {payload.ItemId} absent de Assets/Items : bloc V0`)
	end
	local object = model or v0Item(if rarity then rarity.Color else Color3.new(1, 1, 1))
	for _, part in partsOf(object) do
		part.Anchored = true
	end
	quiet(object)
	object.Name = "RevealItem"
	return object
end

local function heightOf(model: Model): number
	local ok, size = pcall(function()
		return model:GetExtentsSize()
	end)
	if ok and typeof(size) == "Vector3" and (size :: Vector3).Y > 0 then
		return (size :: Vector3).Y
	end
	return 1.6
end

-- Rig de caméra de Clément ------------------------------------------------------------------------------------

local function rigTemplate(): Instance?
	local current: Instance? = ReplicatedStorage
	for _, segment in Reveal.RigPath do
		current = if current then current:FindFirstChild(segment) else nil
	end
	return current
end

local function buildRig(scene: Scene)
	local template = rigTemplate()
	if template == nil or not template:IsA("Model") then
		sayOnce("rig", `{table.concat(Reveal.RigPath, "/")} absent : cinématique en repli codé (L-198)`)
		return
	end
	local rig = template:Clone()
	stripScripts(rig)
	local camPart = rig:FindFirstChild(Reveal.CameraPart, true)
	local anchorPart = rig:FindFirstChild(Reveal.ItemAnchor, true)
	if camPart == nil or not camPart:IsA("BasePart") or anchorPart == nil or not anchorPart:IsA("BasePart") then
		sayOnce("rigparts", `CAM_Reveal sans {Reveal.CameraPart} ou {Reveal.ItemAnchor} (pièces) : repli codé`)
		rig:Destroy()
		return
	end
	local controller = rig:FindFirstChildWhichIsA("AnimationController", true)
	local animator: Animator? = nil
	if controller then
		local found = controller:FindFirstChildOfClass("Animator")
		if found then
			animator = found
		else
			local created = Instance.new("Animator")
			created.Parent = controller
			animator = created
		end
	else
		sayOnce("rigctrl", "CAM_Reveal sans AnimationController : repli codé, caméra sur CameraPart immobile")
	end
	quiet(rig)
	camPart.LocalTransparencyModifier = 1
	anchorPart.LocalTransparencyModifier = 1
	local offset = anchorPart.CFrame:ToObjectSpace(rig:GetPivot())
	rig:PivotTo(scene.base * offset)
	rig.Name = "RevealRig"
	rig.Parent = fxFolder()
	scene.rig = rig
	scene.camPart = camPart
	scene.anchorPart = anchorPart
	scene.animator = animator
	scene.animFolder = AnimPlayer.modelFolder(rig)
	table.insert(scene.created, rig)
end

-- Caméra de l'ouvreur ------------------------------------------------------------------------------------------

local function takeCamera(scene: Scene)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local ok = pcall(function()
		scene.cameraType = camera.CameraType
		scene.cameraSubject = camera.CameraSubject
		scene.blendFrom = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
	end)
	scene.cameraTaken = ok
end

local function giveCamera(scene: Scene)
	if not scene.cameraTaken then
		return
	end
	scene.cameraTaken = false
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	pcall(function()
		camera.CameraType = scene.cameraType or Enum.CameraType.Custom
		local character = localPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local subject = scene.cameraSubject
		camera.CameraSubject = (if subject and subject.Parent ~= nil then subject else humanoid) :: any
	end)
end

local function releaseOpener(scene: Scene)
	giveCamera(scene)
	if scene.masked then
		scene.masked = false
		HudMask.Pop(Reveal.MaskKey)
	end
end

-- Pied de l'objet en ce moment (ItemAnchor animé, sinon le cadre de départ).
local function anchorFrame(scene: Scene): CFrame
	local anchor = scene.anchorPart
	if anchor and anchor.Parent ~= nil then
		return anchor.CFrame
	end
	return scene.base
end

local function cameraTarget(scene: Scene): CFrame
	local s = math.max(if scene.fired.Reveal then scene.shownScale else scene.startScale, Reveal.Camera.MinScale)
	local anchor = anchorFrame(scene)
	local camPart = scene.camPart
	if camPart and scene.mode == "Anim" then
		local offset = anchor:ToObjectSpace(camPart.CFrame)
		return anchor * Logic.scaledOffset(offset, s)
	end
	local CAM = Reveal.Camera
	local base = scene.base.Position
	local height = scene.itemHeight * s
	if scene.payload.SizeClass == "Colossal" and scene.fired.Explode then
		local h = scene.itemHeight * scene.shownScale
		local from = Vector3.new(scene.frontPoint.X, base.Y, scene.frontPoint.Z)
			+ scene.front * (CAM.FarBack + 1.2 * h)
			+ UP * (CAM.FarUp + 0.6 * h)
		return CFrame.lookAt(from, base + UP * (h * 0.5))
	end
	local look = base + UP * (height * CAM.LookHeight)
	local from = base + scene.aisle * (CAM.Distance * s) + UP * (CAM.Height * s)
	return CFrame.lookAt(from, look)
end

local function updateCamera(scene: Scene, dt: number)
	if not scene.cameraTaken then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local target = cameraTarget(scene)
	scene.blend += dt
	local result: CFrame
	if scene.mode == "Anim" then
		local from = scene.blendFrom
		if from and scene.blend < Reveal.Camera.BlendIn then
			result = from:Lerp(target, Logic.easeInOut(scene.blend / Reveal.Camera.BlendIn))
		else
			result = target
		end
	else
		local alpha = 1 - math.exp(-Reveal.Camera.Smooth * dt)
		result = camera.CFrame:Lerp(target, alpha)
	end
	pcall(function()
		camera.CFrame = result
	end)
end

-- Billboard et effets du Reveal ------------------------------------------------------------------------------------

local function boardTemplate(): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(Reveal.Board) else nil
	if found and found:IsA("BillboardGui") then
		return found
	end
	return nil
end

local function v0Board(): BillboardGui
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(Reveal.BoardV0Size.X, Reveal.BoardV0Size.Y)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	for index, name in { "ItemName", "Rarity", "Weight", "Mutation" } do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 0.25)
		label.Position = UDim2.fromScale(0, (index - 1) * 0.25)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Parent = board
	end
	return board
end

local function setText(board: Instance, name: string, text: string?, color: Color3?)
	local label = Find.path(board, name)
	if label == nil or not label:IsA("TextLabel") then
		return
	end
	if text == nil then
		label.Visible = false
		return
	end
	label.Text = text
	if color then
		label.TextColor3 = color
	end
end

local function showBoard(scene: Scene)
	local item = scene.item
	local adornee = if item then (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)) else nil
	if adornee == nil then
		return
	end
	local template = boardTemplate()
	local board: BillboardGui = if template then template:Clone() else v0Board()
	local payload = scene.payload
	local def = Items.ById[payload.ItemId]
	local rarity = Rarities.ById[payload.Rarity]
	setText(board, "ItemName", if def then def.DisplayName else payload.ItemId, nil)
	setText(board, "Rarity", if rarity then rarity.DisplayNameUpper else string.upper(payload.Rarity), if rarity then rarity.Color else nil)
	setText(board, "Weight", if payload.Weight > 0 then Logic.formatWeight(payload.Weight) else nil, nil)
	setText(board, "Mutation", if payload.Mutation then string.upper(payload.Mutation) else nil, nil)
	board.Name = "RevealBoard"
	board.Adornee = adornee
	board.Parent = fxFolder()
	scene.board = board
	table.insert(scene.created, board)
end

local function burst(scene: Scene, center: Vector3)
	if lowEnd() then
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local fx = if assets then assets:FindFirstChild("FX") else nil
	local template = if fx then fx:FindFirstChild(Reveal.RevealFx, true) else nil
	if template == nil or not template:IsA("Model") then
		return
	end
	local copy = template:Clone()
	if copy == nil then
		return
	end
	stripScripts(copy)
	for _, part in partsOf(copy) do
		part.Anchored = true
	end
	quiet(copy)
	copy:PivotTo(CFrame.new(center))
	copy.Parent = fxFolder()
	table.insert(scene.created, copy)
	local rarity = Rarities.ById[scene.payload.Rarity]
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			if rarity then
				d.Color = ColorSequence.new(rarity.Color)
			end
			local count = d:GetAttribute("EmitCount")
			d:Emit(if type(count) == "number" then count else Reveal.RevealEmit)
		end
	end
end

-- Marqueurs ---------------------------------------------------------------------------------------------------------

local fire: (scene: Scene, marker: string) -> ()

local function itemCenter(scene: Scene): Vector3
	return anchorFrame(scene).Position + UP * (scene.itemHeight * scene.shownScale * 0.5)
end

local function soundAt(scene: Scene): Instance?
	if scene.opener then
		return nil -- SoundService : entendu sans distance
	end
	local item = scene.item
	return if item then item.PrimaryPart else nil
end

local function onReveal(scene: Scene)
	local store = scene.store
	if store then
		local box = taggedIn(SHELF_BOX_TAG, store, scene.slot, scene.payload.SlotName)
		if box then
			hideLocal(scene, box)
		end
	end
	scene.revealT = scene.t
	local item = scene.item
	if item then
		item.Parent = fxFolder()
	end
	burst(scene, itemCenter(scene))
	showBoard(scene)
	playSound(Reveal.Sounds.Reveal, soundAt(scene))
	playSound(Reveal.Sounds.Confetti, soundAt(scene))
	if scene.opener and rarityOrder(scene.payload.Rarity) >= rarityOrder(Reveal.FlashMinRarity) then
		local feel = sibling("UiFeelController")
		if feel and type(feel.RevealFlash) == "function" then
			pcall(feel.RevealFlash)
		end
	end
end

local function onExplode(scene: Scene)
	local store = scene.store
	if scene.pending and store then
		scene.pending = false
	end
	if store then
		local radius = Reveal.Ceiling.Radius * math.max(scene.payload.Scale, 1)
		if Ceiling.Explode(store, anchorFrame(scene).Position, radius, lowEnd()) then
			playSound(Reveal.Sounds.Explode, soundAt(scene))
		end
	end
end

local function onLand(scene: Scene)
	scene.stage = "Hold"
	scene.holdT = 0
	scene.shownScale = scene.payload.Scale
	if scene.opener then
		if not scene.doneSent and net then
			scene.doneSent = true
			doneSent += 1
			net.Client.RevealDone:Fire(scene.id)
		end
		releaseOpener(scene)
	end
end

fire = function(scene: Scene, marker: string)
	if scene.fired[marker] then
		return
	end
	-- Ordre du contrat : rien ne grandit avant le Reveal, Explode au plus tard à Top, Land en dernier.
	if marker == "Grow" or marker == "Top" or marker == "Explode" or marker == "Land" then
		fire(scene, "Open")
		fire(scene, "Reveal")
	end
	if marker == "Top" or marker == "Explode" or marker == "Land" then
		fire(scene, "Grow")
	end
	if (marker == "Top" or marker == "Land") and Logic.breaksCeiling(scene.payload.SizeClass) then
		fire(scene, "Explode")
	end
	if marker == "Land" then
		fire(scene, "Top")
	end
	if scene.fired[marker] then
		return
	end
	scene.fired[marker] = true
	if marker == "Open" then
		playSound(Reveal.Sounds.Open, soundAt(scene))
	elseif marker == "Reveal" then
		onReveal(scene)
	elseif marker == "Grow" then
		local track = scene.track
		scene.growAt = if scene.mode == "Anim" and track then track.TimePosition else scene.stageT
		if scene.mode == "Anim" and track then
			local ok, at = pcall(function()
				return track:GetTimeOfKeyframe("Top")
			end)
			scene.topAt = if ok and type(at) == "number" and at > (scene.growAt :: number) then at else nil
		end
	elseif marker == "Explode" then
		if Logic.breaksCeiling(scene.payload.SizeClass) then
			onExplode(scene)
		end
	elseif marker == "Land" then
		onLand(scene)
	end
end

-- Étapes ------------------------------------------------------------------------------------------------------------

local function stopTrack(scene: Scene)
	for _, connection in scene.trackConnections do
		connection:Disconnect()
	end
	table.clear(scene.trackConnections)
	local track = scene.track
	if track then
		pcall(function()
			track:Stop(0)
		end)
	end
	scene.track = nil
end

local function startStage(scene: Scene, stage: string)
	stopTrack(scene)
	scene.stage = stage
	scene.stageT = 0
	scene.mode = "Fallback"
	scene.trackStopped = false
	local animator = scene.animator
	if animator == nil then
		return
	end
	local name = if stage == "Open"
		then `{Reveal.OpenPrefix}{scene.payload.Rarity}`
		else `{Reveal.GrowPrefix}{scene.payload.SizeClass}`
	local animation, why = AnimPlayer.findAnimation(scene.animFolder, name)
	if animation == nil then
		sayOnce(`anim:{name}`, `CAM_Reveal : « {name} » non jouée ({why}) : repli codé`)
		return
	end
	local found: Animation = animation
	local ok, result = pcall(function(): AnimationTrack
		return (animator :: Animator):LoadAnimation(found)
	end)
	if not ok then
		sayOnce(`load:{name}`, `CAM_Reveal : « {name} » non chargée ({result}) : repli codé`)
		return
	end
	local track = result :: AnimationTrack
	for _, marker in Logic.markers(if stage == "Open" then "Open" else "Grow", scene.payload.SizeClass) do
		table.insert(scene.trackConnections, track:GetMarkerReachedSignal(marker):Connect(function()
			if scenes[scene.id] == scene and scene.track == track then
				fire(scene, marker)
			end
		end))
	end
	table.insert(scene.trackConnections, track.Stopped:Connect(function()
		if scene.track == track then
			scene.trackStopped = true
		end
	end))
	scene.track = track
	scene.mode = "Anim"
	scene.blend = 0
	scene.blendFrom = if Workspace.CurrentCamera then Workspace.CurrentCamera.CFrame else nil
	pcall(function()
		track:Play(0)
	end)
end

local function endStage(scene: Scene)
	local stage = scene.stage
	for _, marker in Logic.markers(if stage == "Open" then "Open" else "Grow", scene.payload.SizeClass) do
		fire(scene, marker)
	end
	if scene.stage == "Open" then
		startStage(scene, "Grow")
	end
end

local function toFallback(scene: Scene)
	stopTrack(scene)
	scene.mode = "Fallback"
	scene.stageT = 0
end

local function stepStage(scene: Scene, dt: number)
	scene.stageT += dt
	local stage = scene.stage
	if stage == "Hold" then
		return
	end
	if scene.mode == "Anim" then
		local track = scene.track
		if track == nil then
			toFallback(scene)
			return
		end
		if track.Length <= 0 then
			if scene.stageT >= Reveal.AnimLoadWait then
				sayOnce(`empty:{stage}`, "CAM_Reveal : animation vide (pas publiée au nom du groupe ?) : repli codé")
				toFallback(scene)
			end
			return
		end
		if scene.trackStopped or (not track.IsPlaying and scene.stageT > 0.1) then
			endStage(scene)
		end
		return
	end
	local list = Logic.markers(if stage == "Open" then "Open" else "Grow", scene.payload.SizeClass)
	local times = if stage == "Open" then scene.timeline.Open else scene.timeline.Grow
	for _, marker in list do
		local at = times[marker]
		if at and scene.stageT >= at then
			fire(scene, marker)
		end
	end
	if scene.stage == stage then
		local stageEnd = if stage == "Open" then scene.timeline.OpenEnd else scene.timeline.GrowEnd
		if scene.stageT >= stageEnd then
			endStage(scene)
		end
	end
end

-- Taille montrée de l'objet, puis sa pose.
local function updateItem(scene: Scene, dt: number)
	local payload = scene.payload
	if not scene.fired.Reveal then
		scene.shownScale = scene.startScale
		return
	end
	local f = 0
	if scene.fired.Top or scene.stage == "Hold" then
		f = 1
	elseif scene.fired.Grow then
		local growAt = scene.growAt or 0
		local track = scene.track
		if scene.mode == "Anim" and track then
			local topAt = scene.topAt or track.Length
			f = if topAt > growAt then (track.TimePosition - growAt) / (topAt - growAt) else 1
		else
			local growTime = scene.timeline.Grow.Top - scene.timeline.Grow.Grow
			f = if growTime > 0 then (scene.stageT - growAt) / growTime else 1
		end
	end
	local pop = 1
	local revealT = scene.revealT
	if revealT then
		local p = (scene.t - revealT) / Reveal.Fallback.PopTime
		pop = Reveal.PopFrom + (1 - Reveal.PopFrom) * Logic.backOut(p)
	end
	scene.shownScale = Logic.growScale(scene.startScale, payload.Scale, f) * pop
	local item = scene.item
	if item == nil then
		return
	end
	if scene.mode ~= "Anim" or scene.rig == nil then
		scene.spin += Reveal.Fallback.Spin * dt
	end
	local target = math.max(scene.shownScale, 0.01)
	if math.abs(target - scene.appliedScale) > 1e-3 then
		scene.appliedScale = target
		pcall(function()
			item:ScaleTo(scene.itemBaseScale * target)
		end)
	end
	pcall(function()
		item:PivotTo(anchorFrame(scene) * CFrame.Angles(0, scene.spin, 0))
	end)
	local board = scene.board
	local primary = item.PrimaryPart
	if board and primary then
		local top = anchorFrame(scene).Position.Y + scene.itemHeight * scene.shownScale
		board.StudsOffsetWorldSpace = Vector3.new(0, top - primary.Position.Y + Reveal.BoardOffset, 0)
	end
end

-- Plafond client d'une scène (Config/Reveal.MaxSeconds).
local function maxSeconds(class: SizeClass): number
	if class == "Colossal" then
		return Reveal.MaxSeconds.Colossal
	elseif class == "Large" then
		return Reveal.MaxSeconds.Large
	end
	return Reveal.MaxSeconds.Small
end

-- Fin ---------------------------------------------------------------------------------------------------------------

local function finish(scene: Scene, reason: string)
	if scenes[scene.id] ~= scene then
		return
	end
	scenes[scene.id] = nil
	local index = table.find(order, scene.id)
	if index then
		table.remove(order, index)
	end
	finished += 1
	stopTrack(scene)
	for _, connection in scene.connections do
		connection:Disconnect()
	end
	table.clear(scene.connections)
	if scene.opener then
		releaseOpener(scene)
	end
	local store = scene.store
	if scene.pending and store then
		scene.pending = false
		Ceiling.SetPending(store, false)
	end
	local item = scene.item
	if item then
		item:Destroy()
	end
	for _, inst in scene.created do
		inst:Destroy()
	end
	table.clear(scene.created)
	for part, value in scene.hidden do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = value
		end
	end
	table.clear(scene.hidden)
	if IS_STUDIO then
		print(`[Reveal] fin de {scene.id} ({reason})`)
	end
end

local function step(dt: number)
	for _, id in table.clone(order) do
		local scene = scenes[id]
		if scene == nil then
			continue
		end
		scene.t += dt
		if scene.stage ~= "Hold" and scene.t >= maxSeconds(scene.payload.SizeClass) then
			sayOnce("max", "cinématique arrêtée par MaxSeconds (Land jamais atteint)")
			fire(scene, "Land")
		end
		stepStage(scene, dt)
		updateItem(scene, dt)
		updateCamera(scene, dt)
		if scene.stage == "Hold" then
			scene.holdT += dt
			if scene.holdT >= Reveal.HoldMax then
				finish(scene, "HoldMax")
			end
		end
	end
	Ceiling.Step(dt)
end

-- Début ---------------------------------------------------------------------------------------------------------

local function begin(payload: Payload)
	if scenes[payload.RevealId] then
		return
	end
	local isOpener = payload.Opener == localPlayer
	if isOpener then
		for _, id in table.clone(order) do
			local other = scenes[id]
			if other and other.opener then
				finish(other, "nouvelle cinématique")
			end
		end
	end
	local store = findStore(payload.ShopId)
	local slot = Logic.slotAttachment(payload.SlotName)
	local position, slotFrame, center, window = frameOf(store, payload, slot)
	local camera = Workspace.CurrentCamera
	if position == nil then
		skipped += 1
		sayOnce("noplace", `cinématique {payload.RevealId} : magasin « {payload.ShopId} » ou rayon introuvable ici, rien à montrer`)
		return
	end
	local at = position :: Vector3
	if not isOpener and camera and (camera.CFrame.Position - at).Magnitude > Reveal.SpectatorMaxDistance then
		skipped += 1
		return
	end
	local aisle = if center then flat(center - at) else nil
	if aisle == nil and slotFrame then
		aisle = flat((slotFrame :: CFrame).LookVector)
	end
	local aisleDir: Vector3 = aisle or Vector3.new(0, 0, -1)
	local front = if center and window then flat(window - center) else nil
	local scene: Scene = {
		id = payload.RevealId,
		payload = payload,
		opener = isOpener,
		store = store,
		slot = slot,
		base = CFrame.lookAt(at, at + aisleDir),
		aisle = aisleDir,
		front = front or aisleDir,
		frontPoint = window or center or at,
		t = 0,
		stage = "Open",
		stageT = 0,
		mode = "Fallback",
		track = nil,
		trackStopped = false,
		trackConnections = {},
		timeline = Logic.fallback(Reveal.Fallback, payload.SizeClass),
		fired = {},
		growAt = nil,
		topAt = nil,
		revealT = nil,
		spin = 0,
		rig = nil,
		animator = nil,
		animFolder = nil,
		camPart = nil,
		anchorPart = nil,
		item = nil,
		itemBaseScale = 1,
		itemHeight = 1.6,
		shownScale = 0,
		appliedScale = 1,
		startScale = Logic.startScale(payload.Scale, Reveal.StartScale),
		board = nil,
		created = {},
		hidden = {},
		connections = {},
		cameraTaken = false,
		cameraType = nil,
		cameraSubject = nil,
		blend = 0,
		blendFrom = nil,
		masked = false,
		doneSent = false,
		pending = false,
		holdT = 0,
	}
	scenes[scene.id] = scene
	table.insert(order, scene.id)
	started += 1

	-- Objet (hors du jeu jusqu'au Reveal), à sa taille de départ.
	local item = buildItem(payload)
	scene.itemHeight = heightOf(item)
	local okScale, baseScale = pcall(function()
		return item:GetScale()
	end)
	scene.itemBaseScale = if okScale and type(baseScale) == "number" and baseScale > 0 then baseScale else 1
	scene.item = item
	buildRig(scene)
	if store then
		local shelfItem = taggedIn(SHELF_ITEM_TAG, store, slot, payload.SlotName)
		if shelfItem then
			hideLocal(scene, shelfItem)
		end
		if Logic.breaksCeiling(payload.SizeClass) then
			scene.pending = true
			Ceiling.SetPending(store, true)
		end
	end
	if isOpener then
		takeCamera(scene)
		scene.masked = true
		HudMask.Push(Reveal.MaskKey, { KeepScreens = table.clone(Reveal.KeepScreens) })
		local character = localPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			table.insert(scene.connections, humanoid.Died:Connect(function()
				finish(scene, "mort")
			end))
		end
		table.insert(scene.connections, localPlayer.CharacterRemoving:Connect(function()
			finish(scene, "personnage retiré")
		end))
	end
	startStage(scene, "Open")
	if IS_STUDIO then
		print(
			`[Reveal] {scene.id} : {payload.ItemId} ({payload.Rarity}, {Logic.formatWeight(payload.Weight)}, ×{payload.Scale}, {payload.SizeClass}), {if isOpener then "ouvreur" else "spectateur"}, {if scene.rig then "rig" else "repli"}`
		)
	end
end

-- API -----------------------------------------------------------------------------------------------------------

function RevealController.Play(payload: any)
	local parsed = Logic.parse(payload)
	if parsed then
		begin(parsed)
	end
end

function RevealController.End(revealId: string)
	local scene = scenes[revealId]
	if scene then
		finish(scene, "RevealEnded")
	end
end

function RevealController.GetState(): { [string]: any }
	local list = {}
	for _, id in order do
		local scene = scenes[id]
		if scene then
			local fired = {}
			for _, marker in { "Open", "Reveal", "Grow", "Explode", "Top", "Land" } do
				if scene.fired[marker] then
					table.insert(fired, marker)
				end
			end
			table.insert(list, {
				Id = id,
				Opener = scene.opener,
				Stage = scene.stage,
				Mode = scene.mode,
				Fired = fired,
				Scale = scene.shownScale,
				Camera = scene.cameraTaken,
				Masked = scene.masked,
				Item = scene.item,
				Rig = scene.rig,
				Board = scene.board,
			})
		end
	end
	return { Started = started, Finished = finished, Skipped = skipped, DoneSent = doneSent, Scenes = list }
end

local function watchStore(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local store = inst :: Model
	store:GetAttributeChangedSignal(Reveal.Ceiling.Attribute):Connect(function()
		Ceiling.Refresh(store)
	end)
	if store:GetAttribute(Reveal.Ceiling.Attribute) == true then
		Ceiling.Refresh(store)
	end
end

function RevealController.Start()
	if Features.SingleBoxReveal ~= true then
		return
	end
	local ok, loaded = pcall(function()
		return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	end)
	if not ok then
		warn(`[Reveal] Net indisponible : {loaded}`)
		return
	end
	net = loaded
	net.Client.RevealStarted:Connect(function(...: any)
		local payload = Logic.parse(...)
		if payload == nil then
			sayOnce("badpayload", "RevealStarted illisible : ignoré")
			return
		end
		begin(payload)
	end)
	net.Client.RevealEnded:Connect(function(revealId: any)
		if type(revealId) == "string" then
			RevealController.End(revealId)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, id in table.clone(order) do
			local scene = scenes[id]
			if scene and scene.payload.Opener == player then
				finish(scene, "ouvreur parti")
			end
		end
	end)
	for _, store in CollectionService:GetTagged(STORE_TAG) do
		watchStore(store)
	end
	CollectionService:GetInstanceAddedSignal(STORE_TAG):Connect(watchStore)
	RunService.RenderStepped:Connect(step)
end

return RevealController
