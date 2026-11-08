--!strict
-- UnboxController (DEV-019, DEV-050, DEV-052, L-086 ; client) : les colis posés sur les présentoirs
-- de sa propre parcelle et l'ouverture des colis v2 (Partie 1, sections 5.6, 5.7 et 9.4 ; spec
-- ouverture-colis validée par Clément le 2026-11-07, liaison L-046). Plus d'établis depuis L-086
-- (2026-11-08) : on pose et on ouvre le colis sur un présentoir, l'objet y reste exposé.
--
-- Rôle :
--   - sur chaque DisplaySlot_xx de la parcelle du joueur (attribut OwnerUserId = son UserId, posé
--     par PlotService), une invite créée ici, côté client seulement (ProximityPrompt
--     « UnboxPrompt ») :
--       « Place Box » quand le joueur porte un colis (attribut Carrying du Player, posé par
--       CarryService) et que le présentoir est débloqué et libre (attribut UnboxState = "Free" du
--       présentoir, posé par UnboxService) : envoie PlaceBox(slotIndex) et joue Place (contrat 2.4) ;
--       « Open » quand BoxReady(slotIndex) est arrivé (ou UnboxState = "Ready") : garde une copie
--       locale du colis du présentoir (StandBox_<nn>, sans son minuteur : le serveur détruit le sien
--       à l'ouverture), puis envoie OpenBox(slotIndex) ;
--     sinon l'invite est cachée (présentoir verrouillé, objet exposé, colis qui attend). Le serveur
--     revérifie tout (parcelle, portée, présentoir débloqué et libre, colis porté, attente écoulée) ;
--   - UnboxReveal(slotIndex, itemUid, itemId, zone, tier, startRarity, upgrades, mutationSize?,
--     mutationEffect?) (mutation de l'objet, DEV-131 : nom et revenu à l'écran) : joue la
--     séquence de la spec dans l'écran UI_Unbox v2 de Clément (contrat 2.2, Enabled = false au
--     départ) : crans d'amélioration tirés par le serveur, animation Unbox (marqueur Open, secours
--     0,45 s : le couvercle saute, un faisceau sort), rouleau dans la fenêtre Reel posée au-dessus
--     du colis à chaque image (L-080), éclat, textes, boutons ; version complète pour Rare et plus, courte pour
--     Commun et Peu commun ; toutes les durées dans Config.Unbox. Modules d'aide (dossier Unbox) :
--     Sequence (le déroulé), Screen (l'affichage, remis dans l'état de Studio à la fermeture),
--     Reel (le rouleau) ;
--   - objet exposé caché (L-086) : le serveur pose l'objet sur le présentoir du colis dès
--     l'ouverture (DisplayItem_<nn> de DisplayService, attribut ItemUid), donc juste sous le rouleau.
--     Pour ne pas gâcher la surprise, ce modèle est sorti du jeu sur ce client seulement, jusqu'à la
--     révélation de la séquence (événement Reveal) ou la fermeture de l'écran, au plus
--     HIDE_MAX s ; les autres joueurs le voient tout de suite, comme avant ;
--   - SkipButton (« TAP TO SKIP ») : pendant le rouleau, le gagnant arrive au centre en 0,4 s ;
--     ensuite, tout s'affiche d'un coup ;
--   - ContinueButton ferme l'écran, sinon il se ferme tout seul Config.Unbox.AutoClose s après
--     les boutons ; des ouvertures d'affilée passent l'une après l'autre ;
--   - OpenNextButton (« OPEN NEXT ») : seulement si un autre présentoir de la parcelle a un colis
--     prêt à portée selon la règle d'OpenBox (Config.Unbox : 8 + 4 studs entre le HumanoidRootPart
--     et le présentoir, moins une marge) ; il envoie OpenBox de ce présentoir, à distance, et la
--     séquence suivante part à son UnboxReveal ;
--   - revenu du HUD (vague 8) : le serveur expose l'objet, donc l'attribut Income du Player monte,
--     dès l'ouverture. Pour ne pas gâcher la surprise, chaque UnboxReveal retient le revenu du HUD
--     (HudController.HoldIncome) jusqu'à ce que l'écran ait fini de compter le revenu de l'objet
--     (événement CountEnd de la séquence, avec le son Unbox_Cash). Sans HudController, rien n'est
--     retenu. La retenue est relâchée tout de suite si l'écran manque, si l'objet est inconnu, et
--     dès que l'écran se ferme (réapparition, erreur) avant ce moment.
-- En Studio, l'objet révélé est aussi écrit dans la sortie. Sans UI_Unbox, la sortie seulement.
-- Les invites suivent le streaming : un présentoir qui sort de la zone chargée perd son invite, elle
-- revient avec lui. Aucune règle de jeu : le serveur décide (amélioration et objet compris).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Formulas = require(Config:WaitForChild("Formulas"))
local Items = require(Config:WaitForChild("Items"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Unbox = require(Config:WaitForChild("Unbox"))
local Zones = require(Config:WaitForChild("Zones"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local UnboxFolder = script.Parent:WaitForChild("Unbox")
local Screen = require(UnboxFolder:WaitForChild("Screen"))
local Sequence = require(UnboxFolder:WaitForChild("Sequence"))

type Mode = "Place" | "Open"

type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
	OnMarker: ((animName: string, markerName: string, callback: () -> ()) -> () -> ())?,
}

type StandView = {
	attachment: Attachment,
	prompt: ProximityPrompt,
	mode: Mode?,
	connections: { RBXScriptConnection },
}

-- Ce que ce contrôleur utilise de HudController.
type HudApi = {
	HoldIncome: () -> () -> (),
}

-- Copie locale d'un colis de présentoir, prise à l'appui sur « Open ».
type Pending = { model: Model, at: number }

-- Révélation reçue, en attente d'affichage, avec la copie locale de son colis, la retenue du
-- revenu du HUD (nil : rien de retenu) et le retour de l'objet exposé caché (nil : rien de caché).
type Queued = { reveal: Sequence.Reveal, box: Model?, release: (() -> ())?, unhide: (() -> ())? }

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
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService
local CARRYING_ATTRIBUTE = "Carrying" -- CarryService : Id de rareté du colis porté
local STATE_ATTRIBUTE = "UnboxState" -- UnboxService : "Locked", "Free", "Taken", "Waiting", "Ready"
local SLOT_PATTERN = "^DisplaySlot_(%d+)$" -- présentoirs, contrat 10.4
local BOX_MODEL_FORMAT = "StandBox_%02d" -- UnboxService : colis posé sur le présentoir, dans la parcelle
local ITEM_UID_ATTRIBUTE = "ItemUid" -- DisplayService : sur chaque objet exposé (DisplayItem_<nn>)
local PROMPT_NAME = "UnboxPrompt"
local LOCAL_BOX_NAME = "UnboxLocalBox"

-- V0 proposé, absent du doc : textes (en anglais, L-036) et portée de l'invite (Config.Unbox). Le
-- serveur accepte la portée + 4 studs (UnboxService).
local PLACE_TEXT = "Place Box"
local OPEN_TEXT = "Open"
local OBJECT_TEXT = "Stand"
local PROMPT_DISTANCE = Unbox.PromptDistance
-- OpenNextButton : la portée d'OpenBox (8 + 4 studs), moins une marge pour ne jamais proposer un
-- présentoir que le serveur refuserait.
local OPEN_NEXT_REACH = Unbox.PromptDistance + Unbox.ReachTolerance - Unbox.OpenNextMargin

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
-- Présentoirs de base (Balance.Display.MaxSlots) et présentoirs bonus de la boutique Robux, comme
-- DisplayService (V0 : 10 bonus au plus).
local MAX_SLOTS = Balance.Display.MaxSlots + 10

local UnboxController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local animation: AnimationApi? = nil
local hudApi: HudApi? = nil
local plot: Model? = nil
local plotConnections: { RBXScriptConnection } = {}
local watchedPlots: { [Instance]: RBXScriptConnection } = {}
local views: { [number]: StandView } = {}
local ready: { [number]: boolean } = {} -- BoxReady reçu, pas encore ouvert
local pendingBoxes: { [number]: Pending } = {}
local revealQueue: { Queued } = {} -- révélations en attente d'affichage
local running: Running? = nil -- révélation à l'écran
local screenMissingWarned = false
local errorWarned = false
local rng = Random.new()

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

-- Objet exposé caché pendant l'ouverture (en-tête, L-086) : le modèle de sa parcelle qui porte
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

local function isCarrying(): boolean
	local carrying = localPlayer:GetAttribute(CARRYING_ATTRIBUTE)
	return type(carrying) == "string" and carrying ~= ""
end

-- Montre, cache ou change l'invite du présentoir `index` selon son état.
local function refresh(index: number)
	local view = views[index]
	if view == nil then
		return
	end
	local state = view.attachment:GetAttribute(STATE_ATTRIBUTE)
	local mode: Mode? = nil
	if ready[index] or state == "Ready" then
		mode = "Open"
	elseif state == "Free" and isCarrying() then
		mode = "Place"
	end
	view.mode = mode
	if mode == "Open" then
		view.prompt.ActionText = OPEN_TEXT
	elseif mode == "Place" then
		view.prompt.ActionText = PLACE_TEXT
	end
	view.prompt.Enabled = mode ~= nil
end

local function refreshAll()
	for index in views do
		refresh(index)
	end
end

-- Copie locale du colis du présentoir `index` (StandBox_<nn> d'UnboxService), sans scripts ni
-- billboard (le minuteur « Ready! »), gardée hors du jeu jusqu'à son UnboxReveal.
local function captureBox(index: number)
	local now = os.clock()
	for key, pending in pendingBoxes do
		if now - pending.at > PENDING_MAX then
			pendingBoxes[key] = nil
			pending.model:Destroy()
		end
	end
	local current = plot
	local original = if current then current:FindFirstChild(string.format(BOX_MODEL_FORMAT, index)) else nil
	if original == nil or not original:IsA("Model") then
		return
	end
	local ok, copy = pcall(function(): Instance?
		return original:Clone()
	end)
	if not ok or copy == nil or not copy:IsA("Model") then
		return
	end
	local model = copy :: Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("BillboardGui") then
			descendant:Destroy()
		end
	end
	model.Name = LOCAL_BOX_NAME
	local old = pendingBoxes[index]
	if old then
		old.model:Destroy()
	end
	pendingBoxes[index] = { model = model, at = now }
end

-- La copie locale du colis du présentoir `index`, posée dans le jeu à la place de celui du serveur.
local function takeBox(index: number): Model?
	local pending = pendingBoxes[index]
	pendingBoxes[index] = nil
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

local function onTriggered(index: number)
	local view = views[index]
	if view == nil then
		return
	end
	if view.mode == "Place" then
		net.Client.PlaceBox:Fire(index)
		playAnimation("Place")
	elseif view.mode == "Open" then
		-- L'animation Unbox est jouée par la séquence, après les crans d'amélioration.
		captureBox(index)
		net.Client.OpenBox:Fire(index)
	end
end

-- Numéro du présentoir si `inst` est un DisplaySlot_xx, sinon nil.
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

local function removeView(index: number)
	local view = views[index]
	if view == nil then
		return
	end
	views[index] = nil
	for _, connection in view.connections do
		connection:Disconnect()
	end
	view.prompt:Destroy()
end

local function addView(inst: Instance)
	local index = slotIndexOf(inst)
	if index == nil then
		return
	end
	local attachment = inst :: Attachment
	local existing = views[index]
	if existing then
		if existing.attachment == attachment or existing.attachment.Parent ~= nil then
			return -- déjà là (un nom en double est signalé par le ContractChecker)
		end
		removeView(index)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ObjectText = OBJECT_TEXT
	prompt.ActionText = PLACE_TEXT
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Enabled = false

	local view: StandView = { attachment = attachment, prompt = prompt, mode = nil, connections = {} }
	table.insert(
		view.connections,
		prompt.Triggered:Connect(function()
			onTriggered(index)
		end)
	)
	table.insert(
		view.connections,
		attachment:GetAttributeChangedSignal(STATE_ATTRIBUTE):Connect(function()
			if attachment:GetAttribute(STATE_ATTRIBUTE) ~= "Ready" then
				ready[index] = nil -- colis ouvert, présentoir libéré ou de nouveau en attente
			end
			refresh(index)
		end)
	)
	views[index] = view
	prompt.Parent = attachment
	refresh(index)
end

local function setPlot(newPlot: Model?)
	if newPlot == plot then
		return
	end
	local hadPlot = plot ~= nil
	for index in views do
		removeView(index)
	end
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
	table.insert(plotConnections, newPlot.DescendantAdded:Connect(addView))
	table.insert(
		plotConnections,
		newPlot.DescendantRemoving:Connect(function(inst: Instance)
			local index = slotIndexOf(inst)
			local view = if index then views[index] else nil
			if index and view and view.attachment == inst then
				removeView(index)
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

local function onBoxReady(index: number)
	ready[index] = true
	refresh(index)
	if IS_STUDIO then
		print(`[Unbox] le colis du présentoir {index} est prêt`)
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

-- Autre présentoir de sa parcelle avec un colis prêt, à portée d'OpenBox (le plus proche), sauf `exclude`.
local function nextStand(exclude: number): number?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local position = (root :: BasePart).Position
	local best: number? = nil
	local bestDistance = math.huge
	for index, view in views do
		if index ~= exclude and (ready[index] or view.attachment:GetAttribute(STATE_ATTRIBUTE) == "Ready") then
			local distance = (view.attachment.WorldPosition - position).Magnitude
			if distance <= OPEN_NEXT_REACH and distance < bestDistance then
				best, bestDistance = index, distance
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
-- révélé (Reveal) : son modèle exposé peut revenir sur le présentoir (L-086).
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
		pcall(current.view.SetOpenNext, current.view, nextStand(current.reveal.SlotIndex) ~= nil, nil)
	end
end

-- OpenNextButton : ouvre à distance l'autre colis prêt, puis ferme cet écran.
local function openNext()
	local current = running
	if current == nil or current.runner:SinceButtons() == nil then
		return
	end
	local index = nextStand(current.reveal.SlotIndex)
	if index == nil then
		return
	end
	captureBox(index)
	net.Client.OpenBox:Fire(index)
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
		return current ~= nil and nextStand(current.reveal.SlotIndex) ~= nil
	end,
}

local function startReveal(entry: Queued, screen: ScreenGui, plan: Sequence.Plan)
	-- Point du présentoir : Upgrade et le rouleau s'y placent s'il n'y a pas de copie du colis (L-080).
	local stand = views[entry.reveal.SlotIndex]
	local anchor = if stand then stand.attachment.WorldPosition else nil
	local view = Screen.new(screen, plan, entry.box, hooks, anchor)
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
				warn(`[Unbox] présentoir {entry.reveal.SlotIndex} : {why}`)
			end
			if entry.box then
				entry.box:Destroy()
			end
			releaseIncome(entry.release)
			unhideExposed(entry.unhide)
			continue
		end
		if IS_STUDIO and plan.Mismatch then
			warn(`[Unbox] présentoir {entry.reveal.SlotIndex} : {entry.reveal.StartRarity} + {entry.reveal.Upgrades} cran(s) ≠ {plan.Rarity.Id} ({entry.reveal.ItemId}) : catalogues client et serveur différents ?`)
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
		warn(`[Unbox] présentoir {entry.reveal.SlotIndex} : écran {REVEAL_SCREEN} impossible à lancer ({err})`)
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
	index: any,
	itemUid: any,
	itemId: any,
	zone: any,
	tier: any,
	startRarity: any,
	upgrades: any,
	mutationSize: any,
	mutationEffect: any
)
	if type(index) ~= "number" or type(itemUid) ~= "string" or type(itemId) ~= "string" then
		return
	end
	ready[index] = nil
	refresh(index)
	local item = Items.ById[itemId]
	-- DEV-131 : mutation de l'objet (Id inconnus ignorés), pour son nom et son revenu à l'écran.
	local mutation = Mutations.Sanitize({ Size = mutationSize, Effect = mutationEffect })
	-- Défauts si le serveur n'envoie pas encore la forme v2 (zone, type, rareté de départ, crans).
	local reveal: Sequence.Reveal = {
		SlotIndex = index,
		ItemUid = itemUid,
		ItemId = itemId,
		Zone = if type(zone) == "number" then zone elseif item and item.Zone then item.Zone else 1,
		Tier = if type(tier) == "string" then tier else "Standard",
		StartRarity = if type(startRarity) == "string" then startRarity elseif item then item.Rarity else "Common",
		Upgrades = if type(upgrades) == "number" then upgrades else 0,
		Mutation = mutation,
	}
	-- Retenue prise ici, avant que le HUD traite la hausse d'Income qui suit UnboxReveal.
	-- L-086 : l'objet exposé sur ce présentoir reste caché jusqu'à la révélation (en-tête).
	table.insert(revealQueue, { reveal = reveal, box = takeBox(index), release = holdIncome(), unhide = hideExposed(itemUid) })
	showNextReveal()
	if not IS_STUDIO then
		return
	end
	if item == nil then
		print(`[Unbox] présentoir {index} : objet inconnu {itemId} (uid {itemUid})`)
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
		`[Unbox] présentoir {index} : {rarity.DisplayNameUpper} · {Mutations.ItemName(item.DisplayName, mutation)}{income} ({itemId}, uid {itemUid}) ; colis {reveal.Tier} de la zone {reveal.Zone}{upgraded}{if mutated then ", mutation " .. mutated else ""}`
	)
end

function UnboxController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	animation = loadAnimationController()
	hudApi = loadHud()

	net.Client.BoxReady:Connect(onBoxReady)
	net.Client.UnboxReveal:Connect(onReveal)
	localPlayer:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(refreshAll)

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
