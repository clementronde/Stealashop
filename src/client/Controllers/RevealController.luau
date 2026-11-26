--!strict
-- RevealController (client, vague 62, a204 ; décision de Cantin et Clément du 2026-11-15, liaison L-198 ; valeurs :
-- Config/Reveal ; noms : Contract/Animations.Reveal, Contract/Models (Ceiling), Contract/UI (BB_Reveal)) : la
-- cinématique d'ouverture d'un colis sur son rayon, vue par tous. Toujours branché (a438 : plus de
-- Features.SingleBoxReveal).
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
--      À Land : RevealDone(revealId) au serveur (une fois), caméra et HUD rendus ; f70c4 : la caméra du jeu repart
--      derrière le perso et l'image glisse du dernier plan vers elle en Return.Time s, champ de vision et bords
--      d'UI_Unbox en fondu (Config/Reveal.Return). Mort, personnage retiré, nouvelle cinématique ou RevealEnded avant
--      Land : caméra et HUD rendus d'un coup (sans RevealDone).
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
local Reveal = require(Config:WaitForChild("Reveal"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Formulas = require(Config:WaitForChild("Formulas")) -- a287 : revenu de BB_Reveal.Income
local Mutations = require(Config:WaitForChild("Mutations")) -- a287
local Format = require(Shared:WaitForChild("Format")) -- a287
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local UI = require(Shared:WaitForChild("Contract"):WaitForChild("UI"))
local AnimPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("AnimPlayer"))
local MarkerSounds = require(Shared:WaitForChild("Anim"):WaitForChild("MarkerSounds"))
local HudMask = require(script.Parent:WaitForChild("UI"):WaitForChild("HudMask"))
local RevealFolder = script.Parent:WaitForChild("Reveal")
local Logic = require(RevealFolder:WaitForChild("Logic"))
local Ceiling = require(RevealFolder:WaitForChild("Ceiling"))
local Shelf = require(RevealFolder:WaitForChild("Shelf")) -- a220 : le meuble casse sous un objet trop gros
-- Vague 73 (a251, L-236) : la nouvelle ouverture du colis (Reveal/Unbox, Config/Unbox.New, Shared/UnboxPlan). Quand le
-- serveur envoie un plan (RevealStarted.plan), l'étape Open<Rareté> est remplacée par l'étape « Unbox » : le colis au
-- sol de l'allée, les actions du perso, les silhouettes ; son évènement « Burst » tire le marqueur Open, « Reveal » le
-- marqueur Reveal, « Done » lance l'étape Grow<Classe> d'avant. Sans plan (interrupteur coupé) ou module absent
-- (arbre d'un banc) : rien ne change.
local UnboxConfig = require(Config:WaitForChild("Unbox"))
local unboxModule = RevealFolder:FindFirstChild("Unbox")
local planModule = Shared:FindFirstChild("UnboxPlan")
local Unbox: any = if unboxModule and planModule then require(unboxModule) else nil
local UnboxPlan: any = if unboxModule and planModule then require(planModule) else nil

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
	playerLook: Vector3?, -- f70c4 : direction de la caméra du joueur avant la scène (son inclinaison au retour)
	returnFocus: Vector3?, -- f70c4 : centre de l'objet à Land (point visé par le dernier plan)
	blend: number,
	blendFrom: CFrame?,
	masked: boolean,
	doneSent: boolean,
	pending: boolean,
	holdT: number,
	unbox: any, -- vague 73 : état de Reveal/Unbox (nil : cinématique d'avant)
	maxT: number, -- plafond client de la scène (s)
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

-- Vague 72 (a246, L-229 B) : son de la rareté au Reveal (Low, Mid ou High, Config/Reveal.Sounds).
local function raritySound(id: string): string
	local order = rarityOrder(id)
	if order >= rarityOrder(Reveal.Sounds.RarityHighFrom) then
		return Reveal.Sounds.RarityHigh
	elseif order >= rarityOrder(Reveal.Sounds.RarityMidFrom) then
		return Reveal.Sounds.RarityMid
	end
	return Reveal.Sounds.RarityLow
end

-- Son d'une table { Small, Large, Colossal } pour la classe `class` (Small par défaut).
local function sizeSound(byClass: any, class: string): string
	return byClass[class] or byClass.Small
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
	-- a225 : la mutation habille la copie comme les autres objets (MutationFxController, tag RevealItem),
	-- suivie dès son entrée dans le jeu (onReveal) et retirée avec elle (finish).
	object:SetAttribute("MutationEffect", payload.Mutation)
	CollectionService:AddTag(object, "RevealItem")
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
		scene.playerLook = camera.CFrame.LookVector
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
		-- Vague 75 (a259) : jamais rendue en Scriptable (prise pendant une autre cinématique, la capture par exemple : la
		-- caméra resterait figée une fois les deux finies).
		local before = scene.cameraType
		camera.CameraType = if before and before ~= Enum.CameraType.Scriptable then before else Enum.CameraType.Custom
		local character = localPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local subject = scene.cameraSubject
		camera.CameraSubject = (if subject and subject.Parent ~= nil then subject else humanoid) :: any
	end)
end

-- Retour au jeu (f70c4, Config/Reveal.Return) -------------------------------------------------------------------
-- La caméra du jeu est rendue tout de suite (le joueur bouge et tourne la caméra comme d'habitude), tournée derrière le
-- perso ; pendant Return.Time s, ce qui est montré glisse du dernier plan vers ce qu'elle calcule. Pour qu'elle ne
-- prenne pas le mélange pour sa propre direction, son CFrame à elle lui est remis juste avant qu'elle calcule
-- (priorité Camera − 1) ; le mélange est écrit juste après (Camera + 1). Les pièces cachées par la scène restent cachées
-- jusqu'à la fin du retour (la vue ne repasse pas derrière un rayon redevenu opaque).
-- 2e passe (Play de fusion71) : le mur (L-234) se cherche depuis un point qui glisse du point visé par le dernier plan
-- vers la tête du perso (plus de Camera.Focus, encore celui d'avant la scène à la première image : éclair sous le sol) ;
-- les persos et PNJ (vigile, foule) sont ignorés ; la caméra rapprochée par un obstacle s'en éloigne à OutSpeed au plus.

type Return = {
	scene: Scene,
	given: boolean, -- caméra du jeu rendue (première image du retour)
	t: number,
	time: number,
	from: CFrame, -- dernier plan de la cinématique
	own: CFrame?, -- CFrame calculé par la caméra du jeu à cette image (avant le mélange)
	fade: any, -- Reveal/Unbox.ScreenFade (champ de vision, bords), ou nil
	origin: Vector3, -- point visé par le dernier plan (départ du rayon tête → caméra)
	pull: number, -- studs dont un obstacle rapproche la caméra en ce moment
	hidden: { [BasePart]: number },
	connections: { RBXScriptConnection },
}

local RETURN_BEFORE = "RevealReturnBefore"
local RETURN_AFTER = "RevealReturnAfter"
local back: Return? = nil

local function endReturn()
	local current = back
	if current == nil then
		return
	end
	back = nil
	pcall(RunService.UnbindFromRenderStep, RunService, RETURN_BEFORE)
	pcall(RunService.UnbindFromRenderStep, RunService, RETURN_AFTER)
	for _, connection in current.connections do
		connection:Disconnect()
	end
	if not current.given then
		giveCamera(current.scene) -- coupé avant sa première image
	end
	if current.fade and Unbox then
		Unbox.ScreenFade(current.fade, 1)
	end
	for part, value in current.hidden do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = value
		end
	end
end

-- Distance libre de `origin` vers `target` : ce qui les sépare, moins Margin (jamais derrière un mur, L-234). Les
-- persos, les PNJ (tout modèle avec un Humanoid : vigile, foule), les volumes invisibles et la scène sont ignorés.
local function clearReach(current: Return, origin: Vector3, target: Vector3): number
	local offset = target - origin
	local full = offset.Magnitude
	if full < 1e-3 then
		return full
	end
	local exclude: { Instance } = { fxFolder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	for part in current.hidden do
		table.insert(exclude, part)
	end
	for _ = 1, 8 do
		local ok, hit = pcall(function(): RaycastResult?
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclude
			params.RespectCanCollide = true
			return Workspace:Raycast(origin, offset, params)
		end)
		if not ok or hit == nil then
			return full
		end
		local part = hit.Instance
		local model = part:FindFirstAncestorWhichIsA("Model")
		while model and model:FindFirstChildOfClass("Humanoid") == nil do
			model = model:FindFirstAncestorWhichIsA("Model")
		end
		if model then
			table.insert(exclude, model) -- perso ou PNJ
			continue
		end
		if part:IsA("BasePart") and part.Transparency >= 0.95 then
			table.insert(exclude, part) -- volume invisible
			continue
		end
		return math.max((hit.Position - origin).Magnitude - Reveal.Return.Margin, 0)
	end
	return full
end

-- Première image du retour : la caméra du jeu est rendue (avant qu'elle calcule), tournée derrière le perso (sa
-- direction en ce moment) à l'inclinaison de la caméra du joueur avant la scène ; le dernier plan est gardé.
local function handOver(current: Return, camera: Camera)
	current.given = true
	current.from = camera.CFrame
	local scene = current.scene
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local look = scene.playerLook or current.from.LookVector
	local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), Reveal.Return.PitchMin, Reveal.Return.PitchMax)
	local facing: Vector3 = (if root and root:IsA("BasePart") then flat(root.CFrame.LookVector) else nil)
		or flat(current.from.LookVector)
		or Vector3.new(0, 0, -1)
	local direction = facing * math.cos(pitch) + UP * math.sin(pitch)
	-- Point visé par le dernier plan : sur son axe, à la profondeur de l'objet (onLand), sinon de la tête.
	local target = scene.returnFocus or (if root and root:IsA("BasePart") then root.Position + UP * 1.5 else nil)
	local depth = if target then (target - current.from.Position):Dot(current.from.LookVector) else 0
	current.origin = current.from.Position + current.from.LookVector * math.max(depth, 0.5)
	giveCamera(scene)
	pcall(function()
		local at = current.from.Position
		camera.CFrame = CFrame.lookAt(at, at + direction) -- la caméra du jeu part de cette direction
	end)
end

local function returnBefore()
	local current = back
	local camera = Workspace.CurrentCamera
	if current == nil or camera == nil then
		return
	end
	if not current.given then
		handOver(current, camera)
	elseif current.own and camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CFrame = current.own :: CFrame
	end
end

-- Tête du perso (point que la caméra du jeu suit), sinon nil.
local function headPosition(): Vector3?
	local character = localPlayer.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position + UP * 1.5 else nil
end

local function returnAfter(dt: number)
	local current = back
	local camera = Workspace.CurrentCamera
	if current == nil or not current.given then
		return
	end
	if camera == nil or camera.CameraType == Enum.CameraType.Scriptable then
		endReturn() -- une autre caméra scriptée a pris la main : elle décide
		return
	end
	local R = Reveal.Return
	current.t += dt
	local e = Logic.easeInOut(math.min(current.t / current.time, 1))
	local own = camera.CFrame
	current.own = own
	if current.fade and Unbox then
		Unbox.ScreenFade(current.fade, e, Logic.easeInOut(if R.FovTime > 0 then math.min(current.t / R.FovTime, 1) else 1))
	end
	-- Un obstacle peut rapprocher la caméra d'un coup (L-234), elle s'en éloigne à OutSpeed au plus.
	local cf = current.from:Lerp(own, e)
	local origin = current.origin:Lerp(headPosition() or current.origin, e)
	local offset = cf.Position - origin
	local wanted = offset.Magnitude
	local blocked = wanted - clearReach(current, origin, cf.Position)
	current.pull = math.clamp(math.max(blocked, current.pull - R.OutSpeed * dt), 0, wanted)
	if current.t >= current.time and (current.pull <= 0.05 or current.t >= current.time + R.Settle) then
		endReturn() -- l'image est déjà celle de la caméra du jeu
		return
	end
	if wanted > 1e-3 then
		cf = cf.Rotation + (origin + offset.Unit * (wanted - current.pull))
	end
	camera.CFrame = cf
end

local function startReturn(scene: Scene, fade: any)
	endReturn()
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil or Reveal.Return.Time <= 0 then
		giveCamera(scene)
		if fade and Unbox then
			Unbox.ScreenFade(fade, 1)
		end
		return
	end
	local current: Return = {
		scene = scene,
		given = false,
		t = 0,
		time = Reveal.Return.Time,
		from = CFrame.identity, -- dernier plan, pris à la première image (handOver)
		own = nil,
		fade = fade,
		origin = Vector3.zero, -- pris à la première image (handOver)
		pull = 0,
		hidden = scene.hidden,
		connections = {},
	}
	scene.hidden = {}
	back = current
	table.insert(current.connections, humanoid.Died:Connect(endReturn))
	table.insert(current.connections, localPlayer.CharacterRemoving:Connect(endReturn))
	RunService:BindToRenderStep(RETURN_BEFORE, Enum.RenderPriority.Camera.Value - 1, returnBefore)
	RunService:BindToRenderStep(RETURN_AFTER, Enum.RenderPriority.Camera.Value + 1, returnAfter)
end

-- soft (f70c4) : fin normale (Land), retour au jeu en douceur ; sinon (mort, départ, nouvelle cinématique) d'un coup.
local function releaseOpener(scene: Scene, soft: boolean?)
	local fade = if scene.unbox then Unbox.Release(scene.unbox, soft == true) else nil
	if soft == true and scene.cameraTaken then
		startReturn(scene, fade)
	else
		giveCamera(scene)
		if fade then
			Unbox.ScreenFade(fade, 1)
		end
	end
	if scene.masked then
		scene.masked = false
		HudMask.Pop(Reveal.MaskKey)
		if soft == true then
			playSound(Reveal.Sounds.HudBack) -- a279 (L-229) : UI_Whoosh, les boutons du HUD reviennent
		end
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
	if scene.unbox and scene.stage == "Unbox" then
		return Unbox.CameraTarget(scene.unbox)
	end
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
	if scene.unbox then
		from = Unbox.Clear(scene.unbox, from, look) -- L-234 : jamais dans un mur ni derrière un rayon
	end
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
	-- Vague 75 (a259, T-222) : à l'entrée dans l'ouverture du colis, fondu (départ et arrivée en douceur) depuis la caméra du
	-- joueur ; le lissage du repli, qui part d'un coup, ne sert qu'ensuite.
	local unboxBlend: number = if scene.unbox and scene.stage == "Unbox" then UnboxConfig.New.Camera.BlendIn or 0 else 0
	if scene.mode ~= "Anim" and scene.blendFrom and scene.blend < unboxBlend then
		result = (scene.blendFrom :: CFrame):Lerp(target, Logic.easeInOut(scene.blend / unboxBlend))
	elseif scene.mode == "Anim" then
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
	local names = { "ItemName", "Rarity", "Weight", "Mutation", "Odds", "Income" } -- a287 : Odds et Income en plus
	for index, name in names do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1 / #names)
		label.Position = UDim2.fromScale(0, (index - 1) / #names)
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

-- a287 (2026-11-21, Cantin : « tous les objets ont une chance sur 112 », le texte d'exemple de Clément) : revenu de
-- l'objet révélé, « +$3/s », comme une fois exposé (DisplayService : Formulas.ItemIncome × Mutations.IncomeMultiplier,
-- l'effet de la mutation et le poids compris, sans le multiplicateur du joueur) ; nil si illisible (ligne cachée).
local function incomeText(payload: Payload): string?
	-- a493 (Cantin, 26/11) : le nombre du serveur, celui de la boutique, tel quel ; absent (ancien serveur, caisse
	-- Robux) : le calcul d'a287 ci-dessous.
	if payload.Income ~= nil then
		return `+{Format.money(payload.Income)}/s`
	end
	local ok, base = pcall(Formulas.ItemIncome, payload.ItemId, nil)
	if not ok or type(base) ~= "number" or base ~= base or base < 0 or base >= math.huge then
		return nil
	end
	local mutation = if payload.Mutation then { Effect = payload.Mutation } else nil
	local okFactor, factor = pcall(Mutations.IncomeMultiplier, mutation, if payload.Weight > 0 then payload.Weight else nil)
	local safe = if okFactor and type(factor) == "number" and factor == factor and factor >= 0 and factor < math.huge then factor else 1
	return `+{Format.money(Formulas.RoundIncome(base * safe))}/s` -- a493 : même arrondi que la boutique
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
	-- a287 : la vraie cote du plan du serveur (la même que la dernière de BB_UnboxOdds), cachée sans plan ; le revenu.
	setText(board, "Odds", if UnboxPlan then UnboxPlan.finalOddsText(payload.Plan) else nil, nil)
	setText(board, "Income", incomeText(payload), nil)
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
	playSound(raritySound(scene.payload.Rarity), soundAt(scene)) -- vague 72 (a246, L-229 B)
	if scene.unbox then
		Unbox.OnReveal(scene.unbox) -- vague 73 : son zoom et son fondu des bords remplacent le flash d'UI_Escape
		scene.revealT = scene.t - Reveal.Fallback.PopTime -- pas de sortie de 0,2 à 1 : la silhouette était déjà à cette taille
	elseif scene.opener and rarityOrder(scene.payload.Rarity) >= rarityOrder(Reveal.FlashMinRarity) then
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
			local at = soundAt(scene) -- vague 72 (a246) : Ceiling_Crash, puis Ceiling_Debris
			task.delay(Reveal.Sounds.DebrisDelay, playSound, Reveal.Sounds.Debris, at)
		end
	end
end

local function onLand(scene: Scene)
	playSound(sizeSound(Reveal.Sounds.Land, scene.payload.SizeClass), soundAt(scene)) -- vague 72 (a246, L-229 B)
	scene.stage = "Hold"
	scene.holdT = 0
	scene.shownScale = scene.payload.Scale
	if scene.opener then
		if not scene.doneSent and net then
			scene.doneSent = true
			doneSent += 1
			net.Client.RevealDone:Fire(scene.id)
		end
		scene.returnFocus = itemCenter(scene)
		releaseOpener(scene, true) -- f70c4 : retour au jeu en douceur (Config/Reveal.Return)
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
	if stage == "Grow" then
		playSound(sizeSound(Reveal.Sounds.Grow, scene.payload.SizeClass), soundAt(scene)) -- vague 72 (a246, L-229 B)
	end
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
	if scene.unbox then
		-- Vague 73 : la nouvelle ouverture avance à chaque image (ses effets finissent pendant Grow et Hold) ; ses
		-- évènements ne comptent que pendant son étape.
		local event = Unbox.Step(scene.unbox, dt)
		if event and scene.pending and scene.store then
			-- Le plafond attend son Explode plus longtemps qu'avant (Ceiling.PendingWait) : l'attente repart à chaque étape.
			Ceiling.SetPending(scene.store, true)
		end
		if scene.stage == "Unbox" then
			if event == "Burst" then
				fire(scene, "Open")
			elseif event == "Reveal" then
				fire(scene, "Reveal")
			elseif event == "Done" then
				startStage(scene, "Grow")
			end
			return
		end
	end
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
	if scene.fired.Grow then
		-- a220 (L-210 point 3) : ce que l'objet touche en grandissant casse (Reveal/Shelf, Config/Reveal.Shelf).
		local _, first = Shelf.Grow(scene.id, scene.shownScale)
		if first then
			playSound(Reveal.Shelf.Sound, soundAt(scene))
		end
	end
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
	if scene.unbox then
		Unbox.Destroy(scene.unbox)
	end
	Shelf.Forget(scene.id)
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
		if scene.stage ~= "Hold" and scene.t >= scene.maxT then
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
	Shelf.Step(dt)
end

-- Début ---------------------------------------------------------------------------------------------------------

-- Vague 73 (a251, L-236) : si le serveur a envoyé un plan, la scène passe par la nouvelle ouverture. Le pied de l'objet
-- (scene.base) devient le point au sol de l'allée où le colis est posé : l'objet, le rig, le meuble qui casse et la
-- caméra de la croissance partent de là.
local function beginUnbox(scene: Scene, slotFrame: CFrame, aisleDir: Vector3)
	local payload = scene.payload
	if payload.Plan == nil or Unbox == nil or UnboxConfig.New.Enabled ~= true then
		return
	end
	local plan = UnboxPlan.parse(payload.Plan)
	if plan == nil then
		sayOnce("badplan", `plan « {payload.Plan} » illisible : cinématique d'avant`)
		return
	end
	local store = scene.store
	local shelfBox = if store then taggedIn(SHELF_BOX_TAG, store, scene.slot, payload.SlotName) else nil
	local ok, state = pcall(Unbox.Begin, {
		Id = scene.id,
		Opener = scene.opener,
		Player = payload.Opener,
		Store = store,
		SlotFrame = slotFrame,
		AisleHint = aisleDir,
		ShelfBox = shelfBox,
		Rarity = payload.Rarity,
		SizeClass = payload.SizeClass,
		ItemId = payload.ItemId,
		ItemScale = scene.startScale,
		Plan = plan,
		LowEnd = lowEnd(),
		Folder = fxFolder(),
		Hide = function(part: BasePart)
			hideLocal(scene, part)
		end,
		ItemTop = function(): number
			local anchor = scene.anchorPart
			local y = if anchor and anchor.Parent ~= nil then anchor.Position.Y else scene.base.Position.Y
			return y + scene.itemHeight * math.max(scene.shownScale, 0)
		end,
	})
	if not ok then
		warn(`[Reveal] nouvelle ouverture impossible ({state}) : cinématique d'avant`)
		return
	end
	if shelfBox then
		hideLocal(scene, shelfBox) -- le vrai colis reste sur son rayon, caché : c'est sa copie locale qui saute dans l'allée
	end
	scene.unbox = state
	scene.base = state.base
	scene.aisle = state.base.LookVector
	scene.maxT = UnboxPlan.clientMaxSeconds(payload.Rarity, payload.SizeClass, #plan.Steps) -- vague 74 : selon le plan tiré
end

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
		endReturn() -- f70c4 : un retour au jeu encore en cours finit d'un coup (caméra du jeu rendue avant d'être reprise)
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
		playerLook = nil,
		returnFocus = nil,
		blend = 0,
		blendFrom = nil,
		masked = false,
		doneSent = false,
		pending = false,
		holdT = 0,
		unbox = nil,
		maxT = maxSeconds(payload.SizeClass),
	}
	scenes[scene.id] = scene
	table.insert(order, scene.id)
	started += 1
	beginUnbox(scene, slotFrame or CFrame.new(at), aisleDir)

	-- Objet (hors du jeu jusqu'au Reveal), à sa taille de départ.
	local item = buildItem(payload)
	scene.itemHeight = heightOf(item)
	local okScale, baseScale = pcall(function()
		return item:GetScale()
	end)
	scene.itemBaseScale = if okScale and type(baseScale) == "number" and baseScale > 0 then baseScale else 1
	scene.item = item
	-- a220 : pièces du meuble que l'objet touchera à sa taille finale (dimensions à la taille 1, avant toute rotation).
	local okSize, size1 = pcall(function()
		return item:GetExtentsSize()
	end)
	if okSize and typeof(size1) == "Vector3" then
		Shelf.Plan(scene.id, store, scene.base, size1, payload.Scale, lowEnd())
	end
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
	if scene.unbox then
		scene.stage = "Unbox" -- vague 73 : pas d'Open<Rareté>, l'étape est menée par Reveal/Unbox (stepStage)
	else
		startStage(scene, "Open")
	end
	if IS_STUDIO then
		print(
			`[Reveal] {scene.id} : {payload.ItemId} ({payload.Rarity}, {Logic.formatWeight(payload.Weight)}, ×{payload.Scale}, {payload.SizeClass}), {if isOpener then "ouvreur" else "spectateur"}, {if scene.rig then "rig" else "repli"}{if scene.unbox then `, plan {payload.Plan}` else ""}`
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
				Unbox = if scene.unbox then Unbox.GetState(scene.unbox) else nil,
			})
		end
	end
	local current = back
	return {
		Started = started,
		Finished = finished,
		Skipped = skipped,
		DoneSent = doneSent,
		Scenes = list,
		Returning = if current then current.t else nil, -- f70c4 : secondes écoulées du retour au jeu en cours
	}
end

-- a318 (L-300) : un magasin qui sort du streaming puis revient est le même objet, annoncé de nouveau : une seule
-- écoute par magasin, retirée à sa sortie (avant, une écoute de plus à chaque retour).
local storeLinks: { [Instance]: RBXScriptConnection } = {}

local function watchStore(inst: Instance)
	if not inst:IsA("Model") or storeLinks[inst] then
		return
	end
	local store = inst :: Model
	storeLinks[inst] = store:GetAttributeChangedSignal(Reveal.Ceiling.Attribute):Connect(function()
		Ceiling.Refresh(store)
	end)
	if store:GetAttribute(Reveal.Ceiling.Attribute) == true then
		Ceiling.Refresh(store)
	end
end

local function unwatchStore(inst: Instance)
	local link = storeLinks[inst]
	if link then
		link:Disconnect()
		storeLinks[inst] = nil
	end
end

function RevealController.Start()
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
	CollectionService:GetInstanceRemovedSignal(STORE_TAG):Connect(unwatchStore)
	RunService.RenderStepped:Connect(step)
end

return RevealController
