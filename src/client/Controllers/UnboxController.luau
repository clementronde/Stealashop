--!strict
-- UnboxController (DEV-019, DEV-050, DEV-052, L-089 ; client) : les colis posés au sol de sa propre
-- boutique et l'ouverture des colis v2 (Partie 1, sections 5.6, 5.7 et 9.4 ; spec ouverture-colis
-- validée par Clément le 2026-11-07, liaison L-046). Depuis L-089 (2026-11-09) : le colis rentre dans
-- l'inventaire à l'entrée de la zone safe, le joueur le pose où il veut au sol de sa boutique
-- (InventoryController), il s'ouvre là, et l'objet va dans l'inventaire.
--
-- Rôle :
--   - sur chaque colis posé de sa boutique (Model FloorBox d'UnboxService, attributs BoxUid et
--     OwnerUserId = son UserId), une invite créée ici, côté client seulement (ProximityPrompt
--     « UnboxPrompt ») : « Open » quand BoxReady(boxUid) est arrivé (ou attribut UnboxState = "Ready"
--     du colis) : garde une copie locale du colis (sans son minuteur : le serveur détruit le sien à
--     l'ouverture), puis envoie OpenBox(boxUid). Cachée pendant l'attente. Le serveur revérifie tout
--     (parcelle, portée, attente écoulée, place pour l'objet) ;
--   - UnboxReveal(boxUid, itemUid, itemId, zone, tier, startRarity, upgrades, mutationSize?,
--     mutationEffect?) (mutation de l'objet, DEV-131 : nom et revenu à l'écran) : joue la
--     séquence de la spec dans l'écran UI_Unbox v2 de Clément (contrat 2.2, Enabled = false au
--     départ) : crans d'amélioration tirés par le serveur, animation Unbox (marqueur Open, secours
--     0,45 s : le couvercle saute, un faisceau sort), rouleau dans la fenêtre Reel posée au-dessus
--     du colis à chaque image (L-080), éclat, textes, boutons ; version complète pour Rare et plus, courte pour
--     Commun et Peu commun ; toutes les durées dans Config.Unbox. Modules d'aide (dossier Unbox) :
--     Sequence (le déroulé), Screen (l'affichage, remis dans l'état de Studio à la fermeture),
--     Reel (le rouleau) ;
--   - objet exposé caché : l'objet va dans l'inventaire (son Tool n'arrive qu'à la révélation,
--     InventoryService). Seul cas où il est exposé tout de suite (inventaire plein, présentoir libre :
--     DisplayItem_<nn> de DisplayService, attribut ItemUid) : ce modèle est sorti du jeu sur ce client
--     seulement, jusqu'à la révélation de la séquence (événement Reveal) ou la fermeture de l'écran, au
--     plus HIDE_MAX s ; les autres joueurs le voient tout de suite ;
--   - SkipButton (« TAP TO SKIP ») : pendant le rouleau, le gagnant arrive au centre en 0,4 s ;
--     ensuite, tout s'affiche d'un coup ;
--   - ContinueButton ferme l'écran, sinon il se ferme tout seul Config.Unbox.AutoClose s après
--     les boutons ; des ouvertures d'affilée passent l'une après l'autre ;
--   - OpenNextButton (« OPEN NEXT ») : seulement si un autre colis posé de sa boutique est prêt à
--     portée selon la règle d'OpenBox (Config.Unbox : 8 + 4 studs entre le HumanoidRootPart et le
--     colis, moins une marge) ; il envoie OpenBox de ce colis, à distance, et la séquence suivante
--     part à son UnboxReveal ;
--   - revenu du HUD (vague 8) : chaque UnboxReveal retient le revenu du HUD
--     (HudController.HoldIncome) jusqu'à ce que l'écran ait fini de compter le revenu de l'objet
--     (événement CountEnd de la séquence, avec le son Unbox_Cash) : utile quand l'objet est exposé
--     tout de suite (inventaire plein). Sans HudController, rien n'est retenu. La retenue est relâchée
--     tout de suite si l'écran manque, si l'objet est inconnu, et dès que l'écran se ferme
--     (réapparition, erreur) avant ce moment.
--   - vague 31 (L-112, Features.ShelfOpen) : sur chaque objet sous antivol posé au sol (Model FloorItem
--     d'UnboxService, tag de code FloorItem, toutes les boutiques), une copie de BB_AntiTheft de Clément
--     (sinon un billboard V0 aux mêmes noms) accrochée au-dessus de l'objet : ItemName = son nom (mutation
--     devant) à la couleur de sa rareté, TimeLabel = le temps restant (m:ss, attribut UnlockAt, heure
--     serveur), puis « UNLOCKED! » en vert (5cff4a), avec UI_Success chez le propriétaire (son V0). Invites
--     créées ici : chez le propriétaire, « Display » une fois débloqué → OpenBox(itemUid) (le serveur le
--     reprend et l'expose) ; chez les autres, « Steal » (maintien PvP.StealGrabTime) pendant l'antivol,
--     boutique ouverte au vol (StealOpen de la parcelle) et mains vides → StealFloorItem(plotIndex, itemUid)
--     au début et à la fin du maintien, animation Grab. Le serveur revérifie tout.
--     UnboxController.GetFloorView(model) -> { TimeText, ItemText, OwnerPrompt, StealPrompt, Chains }? (bancs).
--   - vague 34 (L-127 point 4, Clément) : sur cet objet encore sous antivol à son arrivée, les chaînes et le
--     cadenas du kit ReplicatedStorage/Assets/FX/FX_AntiTheft, posés une fois côté client autour de l'objet
--     (Unbox/AntiTheftChains, reprise de wrap(item) de tools/clement/antitheft_proto.luau), dans un Model
--     AntiTheftChains sous l'objet, ancrés, sans collision ni requête. À « UNLOCKED! » : le cadenas saute de
--     0,3 × k en 0,12 s, tout passe en transparence 1 en 0,25 s et est détruit. Kit absent : rien (une ligne
--     dans la sortie). BB_AntiTheft reste au-dessus de l'objet.
-- En Studio, l'objet révélé est aussi écrit dans la sortie. Sans UI_Unbox, la sortie seulement.
-- Les invites suivent le streaming : un colis qui sort de la zone chargée perd son invite, elle
-- revient avec lui. Aucune règle de jeu : le serveur décide (amélioration et objet compris).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Formulas = require(Config:WaitForChild("Formulas"))
local PvP = require(Config:WaitForChild("PvP"))
local Items = require(Config:WaitForChild("Items"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Unbox = require(Config:WaitForChild("Unbox"))
local Zones = require(Config:WaitForChild("Zones"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local UI = require(Shared:WaitForChild("Contract"):WaitForChild("UI"))
local UnboxFolder = script.Parent:WaitForChild("Unbox")
local Screen = require(UnboxFolder:WaitForChild("Screen"))
local Sequence = require(UnboxFolder:WaitForChild("Sequence"))
-- Vague 34 : module d'aide des chaînes ; absent (faux arbres des bancs d'avant la vague 34), pas de chaînes.
local AntiTheftChains = if UnboxFolder:FindFirstChild("AntiTheftChains")
	then require(UnboxFolder:WaitForChild("AntiTheftChains")) -- déjà là : pas d'attente
	else nil

type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
	OnMarker: ((animName: string, markerName: string, callback: () -> ()) -> () -> ())?,
}

-- Un colis posé de sa boutique et son invite.
type BoxView = {
	model: Model,
	prompt: ProximityPrompt,
	connections: { RBXScriptConnection },
}

-- Vague 31 (L-112) : un objet sous antivol posé au sol, son BB_AntiTheft et son invite.
type FloorView = {
	model: Model,
	uid: string,
	mine: boolean, -- objet du joueur local : invite « Display » ; sinon « Steal »
	gui: BillboardGui,
	point: Attachment,
	timeLabel: TextLabel?,
	ownerPrompt: ProximityPrompt?,
	stealPrompt: ProximityPrompt?,
	unlocked: boolean,
	seenLocked: boolean, -- vu sous antivol ici (le son de « UNLOCKED! » ne part qu'à la fin vue)
	chains: Model?, -- vague 34 (L-127 point 4) : chaînes et cadenas posés sur l'objet (AntiTheftChains)
	connections: { RBXScriptConnection },
}

-- Ce que ce contrôleur utilise de HudController.
type HudApi = {
	HoldIncome: () -> () -> (),
}

-- Copie locale d'un colis posé, prise à l'appui sur « Open ».
type Pending = { model: Model, at: number }

-- Révélation reçue, en attente d'affichage, avec la copie locale de son colis, le point où il était
-- posé, la retenue du revenu du HUD (nil : rien de retenu) et le retour de l'objet exposé caché (nil :
-- rien de caché).
type Queued = { reveal: Sequence.Reveal, box: Model?, anchor: Vector3?, release: (() -> ())?, unhide: (() -> ())? }

type Running = {
	reveal: Sequence.Reveal,
	runner: Sequence.Runner,
	view: Screen.View,
	screen: ScreenGui,
	connections: { RBXScriptConnection },
	nextCheck: number,
	release: (() -> ())?, -- retenue du revenu, relâchée à CountEnd ou à la fermeture
	unhide: (() -> ())?, -- objet exposé caché, rendu à Reveal ou à la fermeture
}

-- Contrat et attributs posés par les services serveur (lus sans require).
local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService (parcelle), UnboxService (colis posé)
local STATE_ATTRIBUTE = "UnboxState" -- UnboxService, sur le colis posé : "Waiting", "Ready"
local BOX_UID_ATTRIBUTE = "BoxUid" -- UnboxService : uid du colis posé
local BOX_MODEL_NAME = "FloorBox" -- UnboxService : colis posé au sol, dans la parcelle
local ITEM_UID_ATTRIBUTE = "ItemUid" -- DisplayService : sur chaque objet exposé (DisplayItem_<nn>)
local PROMPT_NAME = "UnboxPrompt"
local LOCAL_BOX_NAME = "UnboxLocalBox"

-- V0 proposé, absent du doc : textes (en anglais, L-036) et portée de l'invite (Config.Unbox). Le
-- serveur accepte la portée + 4 studs (UnboxService).
local OPEN_TEXT = "Open"
local OBJECT_TEXT = "Box"
local PROMPT_DISTANCE = Unbox.PromptDistance
-- OpenNextButton : la portée d'OpenBox (8 + 4 studs), moins une marge pour ne jamais proposer un
-- colis que le serveur refuserait.
local OPEN_NEXT_REACH = Unbox.PromptDistance + Unbox.ReachTolerance - Unbox.OpenNextMargin

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
local STEAL_PROMPT_NAME = "StealFloorPrompt"
-- L-112 : « UNLOCKED! » en vert (5cff4a, la couleur de BB_ShelfOpen) ; son V0 en attendant celui de Clément.
local UNLOCKED_TEXT = "UNLOCKED!"
local UNLOCKED_COLOR = Color3.fromHex("5cff4a")
local UNLOCK_SOUND = "UI_Success"
-- V0 proposé, absent du doc : textes des invites (anglais, L-036), marge de portée de l'invite de vol (comme
-- PvPController) et cadence (s) du minuteur.
local DISPLAY_TEXT = "Display"
local STEAL_TEXT = "Steal"
local STEAL_DISTANCE_MARGIN = 0.5
local FLOOR_TICK = 0.1

-- Écran de révélation (contrat 2.2).
local REVEAL_SCREEN = "UI_Unbox"
-- V0 proposé, absent du doc : une copie de colis gardée plus longtemps (s) sans UnboxReveal est jetée
-- (OpenBox refusé : pas encore prêt, inventaire plein…).
local PENDING_MAX = 15
-- V0 proposé, absent du doc : cadence (s) de la recherche d'un autre colis prêt (OpenNextButton).
local OPEN_NEXT_CHECK = 0.25
-- V0 proposé, absent du doc : l'objet exposé caché pendant l'ouverture revient au plus tard après ce
-- délai (s), même si l'écran reste ouvert (révélation la plus longue : environ 6 s avec 2 crans).
local HIDE_MAX = 12

local IS_STUDIO = RunService:IsStudio()

local UnboxController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local animation: AnimationApi? = nil
local hudApi: HudApi? = nil
local plot: Model? = nil
local plotConnections: { RBXScriptConnection } = {}
local watchedPlots: { [Instance]: RBXScriptConnection } = {}
local views: { [string]: BoxView } = {}
local ready: { [string]: boolean } = {} -- BoxReady reçu, pas encore ouvert
local pendingBoxes: { [string]: Pending } = {}
-- Dernier point connu de chaque colis posé : le serveur retire le modèle juste avant UnboxReveal.
local lastBase: { [string]: Vector3 } = {}
local revealQueue: { Queued } = {} -- révélations en attente d'affichage
local running: Running? = nil -- révélation à l'écran
local screenMissingWarned = false
local errorWarned = false
local rng = Random.new()
-- Vague 31 : objets sous antivol affichés au sol, par modèle (toutes les boutiques).
local floorViews: { [Instance]: FloorView } = {}
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

local function loadHud(): HudApi?
	local folder = script.Parent
	local module = if folder then folder:FindFirstChild("HudController") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" and type((result :: any).HoldIncome) == "function" then
		return result :: any
	end
	return nil
end

-- Retient le revenu du HUD jusqu'à la révélation (HudController.HoldIncome) ; nil sans HUD.
local function holdIncome(): (() -> ())?
	local api = hudApi
	if api == nil then
		return nil
	end
	local ok, release = pcall(api.HoldIncome)
	if ok and type(release) == "function" then
		return release
	end
	return nil
end

local function releaseIncome(release: (() -> ())?)
	if release then
		pcall(release)
	end
end

-- Objet exposé caché pendant l'ouverture (en-tête) : le modèle de sa parcelle qui porte
-- ItemUid = `itemUid` est sorti du jeu sur ce client (Parent = nil, sans effet sur le serveur), qu'il
-- soit déjà là ou qu'il arrive ensuite. Renvoie la fonction qui le rend (à appeler une fois ; elle
-- est aussi appelée toute seule après HIDE_MAX s).
local function hideExposed(itemUid: string): () -> ()
	local current = plot
	local hidden: Instance? = nil
	local home: Instance? = nil
	local done = false
	local connection: RBXScriptConnection? = nil
	local function tryHide(inst: Instance)
		if done or hidden ~= nil or not inst:IsA("Model") or inst:GetAttribute(ITEM_UID_ATTRIBUTE) ~= itemUid then
			return
		end
		local parent = inst.Parent
		if parent == nil then
			return
		end
		-- Après le signal en cours : changer le parent pendant DescendantAdded est refusé.
		task.defer(function()
			if done or hidden ~= nil or inst.Parent ~= parent then
				return
			end
			if pcall(function()
				inst.Parent = nil
			end) then
				hidden, home = inst, parent
			end
		end)
	end
	local function restore()
		if done then
			return
		end
		done = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		local model, parent = hidden, home
		hidden, home = nil, nil
		if model and parent and parent:IsDescendantOf(Workspace) then
			pcall(function()
				model.Parent = parent
			end)
		end
	end
	if current then
		connection = current.DescendantAdded:Connect(tryHide)
		for _, inst in current:GetDescendants() do
			tryHide(inst)
		end
	end
	task.delay(HIDE_MAX, restore)
	return restore
end

local function unhideExposed(unhide: (() -> ())?)
	if unhide then
		pcall(unhide)
	end
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

local function isReady(boxUid: string): boolean
	local view = views[boxUid]
	return ready[boxUid] == true or (view ~= nil and view.model:GetAttribute(STATE_ATTRIBUTE) == "Ready")
end

-- Montre ou cache l'invite du colis `boxUid` selon son état.
local function refresh(boxUid: string)
	local view = views[boxUid]
	if view then
		view.prompt.Enabled = isReady(boxUid)
	end
end

-- Pied d'un colis posé (pivot de son modèle, en bas au centre).
local function basePosition(view: BoxView): Vector3
	return view.model:GetPivot().Position
end

-- Copie locale du colis posé `boxUid` (FloorBox d'UnboxService), sans scripts ni billboard (le
-- minuteur « Ready! ») ni invite, gardée hors du jeu jusqu'à son UnboxReveal.
local function captureBox(boxUid: string)
	local now = os.clock()
	for key, pending in pendingBoxes do
		if now - pending.at > PENDING_MAX then
			pendingBoxes[key] = nil
			pending.model:Destroy()
		end
	end
	local view = views[boxUid]
	if view == nil then
		return
	end
	local ok, copy = pcall(function(): Instance?
		return view.model:Clone()
	end)
	if not ok or copy == nil or not copy:IsA("Model") then
		return
	end
	local model = copy :: Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("BillboardGui") or descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
	model.Name = LOCAL_BOX_NAME
	local old = pendingBoxes[boxUid]
	if old then
		old.model:Destroy()
	end
	pendingBoxes[boxUid] = { model = model, at = now }
end

-- La copie locale du colis `boxUid`, posée dans le jeu à la place de celle du serveur.
local function takeBox(boxUid: string): Model?
	local pending = pendingBoxes[boxUid]
	pendingBoxes[boxUid] = nil
	if pending == nil then
		return nil
	end
	if os.clock() - pending.at > PENDING_MAX then
		pending.model:Destroy()
		return nil
	end
	pending.model.Parent = Workspace
	return pending.model
end

local function openBox(boxUid: string)
	-- L'animation Unbox est jouée par la séquence, après les crans d'amélioration.
	captureBox(boxUid)
	net.Client.OpenBox:Fire(boxUid)
end

-- Uid du colis si `inst` est un colis posé de ce joueur (FloorBox, BoxUid, OwnerUserId), sinon nil.
local function boxUidOf(inst: Instance): string?
	if not inst:IsA("Model") or inst.Name ~= BOX_MODEL_NAME then
		return nil
	end
	local uid = inst:GetAttribute(BOX_UID_ATTRIBUTE)
	if type(uid) ~= "string" or inst:GetAttribute(OWNER_ATTRIBUTE) ~= localPlayer.UserId then
		return nil
	end
	return uid
end

local function removeView(boxUid: string)
	local view = views[boxUid]
	if view == nil then
		return
	end
	views[boxUid] = nil
	lastBase[boxUid] = basePosition(view)
	for _, connection in view.connections do
		connection:Disconnect()
	end
	view.prompt:Destroy()
end

local function addView(inst: Instance)
	local boxUid = boxUidOf(inst)
	if boxUid == nil then
		return
	end
	local model = inst :: Model
	local existing = views[boxUid]
	if existing then
		if existing.model == model or existing.model.Parent ~= nil then
			return
		end
		removeView(boxUid)
	end
	local holder = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if holder == nil then
		return -- pas encore arrivé en entier (streaming) : DescendantAdded le rappellera
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ObjectText = OBJECT_TEXT
	prompt.ActionText = OPEN_TEXT
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Enabled = false

	local view: BoxView = { model = model, prompt = prompt, connections = {} }
	table.insert(
		view.connections,
		prompt.Triggered:Connect(function()
			if isReady(boxUid) then
				openBox(boxUid)
			end
		end)
	)
	table.insert(
		view.connections,
		model:GetAttributeChangedSignal(STATE_ATTRIBUTE):Connect(function()
			refresh(boxUid)
		end)
	)
	views[boxUid] = view
	prompt.Parent = holder
	refresh(boxUid)
end

local function onDescendantAdded(inst: Instance)
	if inst:IsA("BasePart") then
		-- Une pièce d'un colis posé arrive après son modèle (streaming) : on réessaie le modèle.
		local model = inst:FindFirstAncestorWhichIsA("Model")
		if model then
			addView(model)
		end
		return
	end
	addView(inst)
end

local function setPlot(newPlot: Model?)
	if newPlot == plot then
		return
	end
	local hadPlot = plot ~= nil
	for boxUid in views do
		removeView(boxUid)
	end
	table.clear(lastBase)
	for _, connection in plotConnections do
		connection:Disconnect()
	end
	table.clear(plotConnections)
	-- Changement de parcelle : les BoxReady de l'ancienne ne valent plus. Ceux reçus avant que la
	-- parcelle soit connue (plot encore nil) sont gardés.
	if hadPlot then
		table.clear(ready)
	end
	plot = newPlot
	if newPlot == nil then
		return
	end
	table.insert(plotConnections, newPlot.DescendantAdded:Connect(onDescendantAdded))
	table.insert(
		plotConnections,
		newPlot.DescendantRemoving:Connect(function(inst: Instance)
			local boxUid = boxUidOf(inst)
			local view = if boxUid then views[boxUid] else nil
			if boxUid and view and view.model == inst then
				removeView(boxUid)
			end
		end)
	)
	for _, inst in newPlot:GetDescendants() do
		addView(inst)
	end
end

-- Parcelle dont le joueur est propriétaire, ou nil.
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

local function onBoxReady(boxUid: any)
	if type(boxUid) ~= "string" then
		return
	end
	ready[boxUid] = true
	refresh(boxUid)
	if IS_STUDIO then
		print(`[Unbox] le colis {boxUid} est prêt`)
	end
end

-- Écran de révélation ------------------------------------------------------------------------

-- Copie de UI_Unbox dans PlayerGui (Roblox la copie depuis StarterGui), ou nil.
local function revealScreen(): ScreenGui?
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local screen = if playerGui then playerGui:FindFirstChild(REVEAL_SCREEN) else nil
	if screen and screen:IsA("ScreenGui") then
		return screen
	end
	return nil
end

-- Autre colis posé de sa boutique, prêt, à portée d'OpenBox (le plus proche), sauf `exclude`.
local function nextBox(exclude: string): string?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local position = (root :: BasePart).Position
	local best: string? = nil
	local bestDistance = math.huge
	for boxUid, view in views do
		if boxUid ~= exclude and isReady(boxUid) then
			local distance = (basePosition(view) - position).Magnitude
			if distance <= OPEN_NEXT_REACH and distance < bestDistance then
				best, bestDistance = boxUid, distance
			end
		end
	end
	return best
end

local showNextReveal: () -> ()

local function closeReveal()
	local current = running
	if current == nil then
		return
	end
	running = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	local ok, err = pcall(current.view.Close :: any, current.view)
	if not ok then
		warn(`[Unbox] fermeture de {REVEAL_SCREEN} : {err}`)
	end
	-- Fermé avant d'avoir montré le revenu (réapparition, erreur) : le HUD n'attend plus.
	local release = current.release
	current.release = nil
	releaseIncome(release)
	local unhide = current.unhide
	current.unhide = nil
	unhideExposed(unhide)
	showNextReveal()
end

-- L'écran a fini de compter le revenu de l'objet (CountEnd) : le HUD peut le montrer. L'objet est
-- révélé (Reveal) : son modèle exposé peut revenir sur le présentoir.
local function checkIncome(current: Running)
	local release = current.release
	if release and current.runner:IsFired("CountEnd") then
		current.release = nil
		releaseIncome(release)
	end
	local unhide = current.unhide
	if unhide and current.runner:IsFired("Reveal") then
		current.unhide = nil
		unhideExposed(unhide)
	end
end

-- Une image de la séquence en cours (dt réel, en secondes).
local function stepReveal(dt: number)
	local current = running
	if current == nil then
		return
	end
	if current.screen.Parent == nil then
		closeReveal() -- écran recréé (réapparition du perso) : on n'y touche plus
		return
	end
	local ok, err = pcall(current.runner.Update :: any, current.runner, dt)
	if not ok then
		if not errorWarned then
			errorWarned = true
			warn(`[Unbox] séquence d'ouverture interrompue : {err}`)
		end
		closeReveal()
		return
	end
	checkIncome(current)
	local since = current.runner:SinceButtons()
	if since == nil then
		return
	end
	if since >= Unbox.AutoClose then
		closeReveal()
		return
	end
	current.nextCheck -= dt
	if current.nextCheck <= 0 then
		current.nextCheck = OPEN_NEXT_CHECK
		pcall(current.view.SetOpenNext, current.view, nextBox(current.reveal.BoxUid) ~= nil, nil)
	end
end

-- OpenNextButton : ouvre à distance l'autre colis prêt, puis ferme cet écran.
local function openNext()
	local current = running
	if current == nil or current.runner:SinceButtons() == nil then
		return
	end
	local boxUid = nextBox(current.reveal.BoxUid)
	if boxUid == nil then
		return
	end
	openBox(boxUid)
	closeReveal()
end

local function bindButton(current: Running, path: string, callback: () -> ())
	local found = Find.path(current.screen, path)
	if found == nil or not found:IsA("GuiButton") then
		return
	end
	table.insert(
		current.connections,
		(found :: GuiButton).Activated:Connect(function()
			if running == current then
				callback()
			end
		end)
	)
end

-- Caméra libre pendant l'ouverture (demande d'Ironix, 2026-11-08) : le SkipButton de Clément couvre
-- tout l'écran et captait la souris et le doigt, donc la caméra ne bougeait plus. Il ne capte plus
-- rien (Interactable = false sur la copie du joueur ; son visuel ne change pas) et le code reconnaît
-- lui-même un appui court et immobile, n'importe où : celui-là passe le rouleau, un glisser ou un
-- clic droit tourne la caméra. Valeurs V0 proposées, absentes du doc.
local TAP_MAX_TIME = 0.3 -- s entre l'appui et le relâché
local TAP_MAX_MOVE = 12 -- px entre l'appui et le relâché

local function isTapInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function bindTapToSkip(current: Running, button: GuiObject, callback: () -> ())
	pcall(function()
		(button :: any).Interactable = false
	end)
	local startedAt: number? = nil
	local startedFrom: Vector3? = nil
	table.insert(
		current.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or not isTapInput(input) then
				return
			end
			startedAt, startedFrom = os.clock(), input.Position
		end)
	)
	table.insert(
		current.connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local at, from = startedAt, startedFrom
			if not isTapInput(input) or at == nil or from == nil then
				return
			end
			startedAt, startedFrom = nil, nil
			local quick = os.clock() - at <= TAP_MAX_TIME
			local still = (input.Position - from).Magnitude <= TAP_MAX_MOVE
			if quick and still and running == current and button.Visible then
				callback()
			end
		end)
	)
end

local hooks: Screen.Hooks = {
	PlayPlayer = playAnimation,
	CanOpenNext = function(): boolean
		local current = running
		return current ~= nil and nextBox(current.reveal.BoxUid) ~= nil
	end,
}

local function startReveal(entry: Queued, screen: ScreenGui, plan: Sequence.Plan)
	-- Point du colis posé : Upgrade et le rouleau s'y placent s'il n'y a pas de copie du colis (L-080).
	local view = Screen.new(screen, plan, entry.box, hooks, entry.anchor)
	local runner = Sequence.new(plan, view :: any)
	local current: Running = {
		reveal = entry.reveal,
		runner = runner,
		view = view,
		screen = screen,
		connections = {},
		nextCheck = 0,
		release = entry.release,
		unhide = entry.unhide,
	}
	running = current
	local skipButton = Find.path(screen, "SkipButton")
	if skipButton and skipButton:IsA("GuiObject") then
		bindTapToSkip(current, skipButton :: GuiObject, function()
			runner:Skip()
			checkIncome(current) -- après le rouleau, Skip montre tout d'un coup, revenu compris
		end)
	end
	bindButton(current, "ContinueButton", function()
		if runner:SinceButtons() ~= nil then
			closeReveal()
		end
	end)
	bindButton(current, "OpenNextButton", openNext)
	table.insert(current.connections, RunService.RenderStepped:Connect(stepReveal))
	stepReveal(0)
end

showNextReveal = function()
	if running ~= nil then
		return
	end
	while #revealQueue > 0 do
		local entry = table.remove(revealQueue, 1) :: Queued
		local plan, why = Sequence.plan(entry.reveal, rng)
		if plan == nil then
			if IS_STUDIO then
				warn(`[Unbox] colis {entry.reveal.BoxUid} : {why}`)
			end
			if entry.box then
				entry.box:Destroy()
			end
			releaseIncome(entry.release)
			unhideExposed(entry.unhide)
			continue
		end
		if IS_STUDIO and plan.Mismatch then
			warn(`[Unbox] colis {entry.reveal.BoxUid} : {entry.reveal.StartRarity} + {entry.reveal.Upgrades} cran(s) ≠ {plan.Rarity.Id} ({entry.reveal.ItemId}) : catalogues client et serveur différents ?`)
		end
		local screen = revealScreen()
		if screen == nil then
			if IS_STUDIO and not screenMissingWarned then
				screenMissingWarned = true
				warn(`[Unbox] écran {REVEAL_SCREEN} absent de PlayerGui : révélation dans la sortie seulement`)
			end
			playAnimation("Unbox") -- sans écran, le perso ouvre quand même son colis
			for _, queued in { entry, table.unpack(revealQueue) } do
				if queued.box then
					queued.box:Destroy()
				end
				releaseIncome(queued.release) -- sans écran, le revenu se montre tout de suite
				unhideExposed(queued.unhide) -- et l'objet exposé aussi
			end
			table.clear(revealQueue)
			return
		end
		local ok, err = pcall(startReveal, entry, screen, plan)
		if ok then
			return
		end
		warn(`[Unbox] colis {entry.reveal.BoxUid} : écran {REVEAL_SCREEN} impossible à lancer ({err})`)
		if running then
			closeReveal() -- relâche le revenu et passe à la révélation suivante
			return
		end
		if entry.box then
			entry.box:Destroy()
		end
		releaseIncome(entry.release)
		unhideExposed(entry.unhide)
	end
end

local function onReveal(
	boxUid: any,
	itemUid: any,
	itemId: any,
	zone: any,
	tier: any,
	startRarity: any,
	upgrades: any,
	mutationSize: any,
	mutationEffect: any
)
	if type(boxUid) ~= "string" or type(itemUid) ~= "string" or type(itemId) ~= "string" then
		return
	end
	ready[boxUid] = nil
	-- Point du colis, pris avant que son modèle quitte le jeu (le serveur l'a déjà détruit chez lui).
	local view = views[boxUid]
	local anchor: Vector3? = if view then basePosition(view) else lastBase[boxUid]
	lastBase[boxUid] = nil
	refresh(boxUid)
	local item = Items.ById[itemId]
	-- DEV-131 : mutation de l'objet (Id inconnus ignorés), pour son nom et son revenu à l'écran.
	local mutation = Mutations.Sanitize({ Size = mutationSize, Effect = mutationEffect })
	-- Défauts si le serveur n'envoie pas encore la forme v2 (zone, type, rareté de départ, crans).
	local reveal: Sequence.Reveal = {
		BoxUid = boxUid,
		ItemUid = itemUid,
		ItemId = itemId,
		Zone = if type(zone) == "number" then zone elseif item and item.Zone then item.Zone else 1,
		Tier = if type(tier) == "string" then tier else "Standard",
		StartRarity = if type(startRarity) == "string" then startRarity elseif item then item.Rarity else "Common",
		Upgrades = if type(upgrades) == "number" then upgrades else 0,
		Mutation = mutation,
	}
	local box = takeBox(boxUid)
	if anchor == nil and box then
		anchor = box:GetPivot().Position
	end
	-- Retenue prise ici, avant que le HUD traite une hausse d'Income qui suivrait UnboxReveal
	-- (inventaire plein : objet exposé tout de suite, caché jusqu'à la révélation).
	table.insert(revealQueue, { reveal = reveal, box = box, anchor = anchor, release = holdIncome(), unhide = hideExposed(itemUid) })
	showNextReveal()
	if not IS_STUDIO then
		return
	end
	if item == nil then
		print(`[Unbox] colis {boxUid} : objet inconnu {itemId} (uid {itemUid})`)
		return
	end
	local rarity = Rarities.ById[item.Rarity]
	if rarity == nil then
		return
	end
	-- Même début de ligne qu'avant la v2 (bancs d'essai) ; zone, type et crans à la suite.
	local itemZone = item.Zone or reveal.Zone
	local income = if Zones[itemZone] then ` · {Formulas.ItemIncome(itemZone, rarity.Id) * Mutations.IncomeMultiplier(mutation)} $/s` else ""
	local upgraded = if reveal.Upgrades > 0 then `, {reveal.Upgrades} cran(s) depuis {reveal.StartRarity}` else ""
	local mutated = Mutations.Label(mutation)
	print(
		`[Unbox] colis {boxUid} : {rarity.DisplayNameUpper} · {Mutations.ItemName(item.DisplayName, mutation)}{income} ({itemId}, uid {itemUid}) ; colis {reveal.Tier} de la zone {reveal.Zone}{upgraded}{if mutated then ", mutation " .. mutated else ""}`
	)
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

-- Remet à jour le minuteur et les invites d'un objet sous antivol (heure serveur, attributs du serveur).
local function refreshFloorView(view: FloorView, now: number)
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
		-- Propriétaire : « Display » une fois l'antivol fini (OpenBox : le serveur le reprend et l'expose).
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.ActionText = DISPLAY_TEXT
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
		local function fire()
			local plotModel = model.Parent
			local plotIndex = if plotModel then plotModel:GetAttribute(PLOT_INDEX_ATTRIBUTE) else nil
			if net and type(plotIndex) == "number" then
				net.Client.StealFloorItem:Fire(plotIndex, itemUid)
			end
		end
		table.insert(view.connections, prompt.PromptButtonHoldBegan:Connect(fire)) -- début du maintien
		table.insert(
			view.connections,
			prompt.Triggered:Connect(function()
				fire() -- fin du maintien
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
	refreshFloorView(view, Workspace:GetServerTimeNow())
end

local function stepFloorViews(dt: number)
	if AntiTheftChains then AntiTheftChains.Step(dt) end -- fin de l'antivol : à chaque image, seulement pendant l'animation
	floorElapsed += dt
	if floorElapsed < FLOOR_TICK then
		return
	end
	floorElapsed = 0
	local now = Workspace:GetServerTimeNow()
	for _, view in floorViews do
		refreshFloorView(view, now)
	end
end

local function chainsShown(view: FloorView): boolean
	local chains = view.chains
	local api = AntiTheftChains
	return api ~= nil and chains ~= nil and chains.Parent ~= nil and not api.IsReleasing(chains)
end

function UnboxController.GetFloorView(
	model: Instance
): { TimeText: string?, ItemText: string?, OwnerPrompt: boolean?, StealPrompt: boolean?, Chains: boolean }?
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
	}
end

function UnboxController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	animation = loadAnimationController()
	hudApi = loadHud()

	-- Vague 31 (L-112) : objets sous antivol posés au sol, toutes les boutiques (tag de code FloorItem).
	if Features.ShelfOpen then
		CollectionService:GetInstanceAddedSignal(FLOOR_ITEM_TAG):Connect(addFloorView)
		CollectionService:GetInstanceRemovedSignal(FLOOR_ITEM_TAG):Connect(removeFloorView)
		for _, inst in CollectionService:GetTagged(FLOOR_ITEM_TAG) do
			addFloorView(inst)
		end
		RunService.Heartbeat:Connect(stepFloorViews)
	end

	net.Client.BoxReady:Connect(onBoxReady)
	net.Client.UnboxReveal:Connect(onReveal)

	-- Marqueur Open de l'animation Unbox (contrat 2.4) : le couvercle saute à ce moment-là.
	local anim = animation
	local onMarker = if anim then anim.OnMarker else nil
	if onMarker then
		onMarker("Unbox", "Open", function()
			local current = running
			if current then
				current.runner:OpenMarker()
			end
		end)
	end

	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(watchPlot)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(unwatchPlot)
	for _, inst in CollectionService:GetTagged(PLOT_TAG) do
		watchPlot(inst)
	end
end

return UnboxController
