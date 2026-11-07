--!strict
-- UnboxController (DEV-019, client) : les établis d'ouverture de sa propre parcelle
-- (Partie 1, sections 5.6, 5.7 et 9.4).
--
-- Rôle :
--   - sur chaque UnboxBench_xx de la parcelle du joueur (attribut OwnerUserId = son UserId, posé
--     par PlotService), une invite créée ici, côté client seulement (ProximityPrompt
--     « UnboxPrompt ») :
--       « Place Box » quand le joueur porte un colis (attribut Carrying du Player, posé par
--       CarryService) et que l'établi est libre (attribut UnboxState = "Free" de l'établi, posé
--       par UnboxService) : envoie PlaceBox(benchIndex) ;
--       « Open » quand BoxReady(benchIndex) est arrivé (ou UnboxState = "Ready") : envoie
--       OpenBox(benchIndex) ;
--     sinon l'invite est cachée. Le serveur revérifie tout (parcelle, portée, établi débloqué et
--     libre, colis porté, attente écoulée) ;
--   - joue Place ou Unbox (contrat 2.4) au déclenchement, par AnimationController s'il est là ;
--   - UnboxReveal(benchIndex, itemUid, itemId) : ouvre l'écran gris UI_Unbox de Clément (contrat
--     2.2, Enabled = false au départ) et le remplit (DEV-021) : Rarity (DisplayNameUpper, texte à
--     la couleur de la rareté), ItemName (nom du catalogue), Income (« +$15/s »,
--     Formulas.ItemIncome ; un Secret n'a pas de zone au catalogue : son revenu est lu sur l'objet
--     exposé, attribut Income de DisplayService, sinon Income est caché). Fermé par ContinueButton
--     ou au bout de REVEAL_AUTO_CLOSE s ; des ouvertures d'affilée passent l'une après l'autre.
--     Bonus : le modèle ITM_<ItemId> dans un ViewportFrame posé dans ItemPreview (cadre décoratif),
--     quand les deux existent. En Studio, l'objet révélé est aussi écrit dans la sortie. La
--     révélation complète (storyboard 5.7) est DEV-050.
-- Les invites suivent le streaming : un établi qui sort de la zone chargée perd son invite, elle
-- revient avec lui. Seule UI créée ici : l'aperçu de ItemPreview. Aucune règle de jeu : le serveur
-- décide.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Formulas = require(Config:WaitForChild("Formulas"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))

type Mode = "Place" | "Open"

type Reveal = { itemUid: string, itemId: string }

type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
}

type BenchView = {
	attachment: Attachment,
	prompt: ProximityPrompt,
	mode: Mode?,
	connections: { RBXScriptConnection },
}

-- Contrat et attributs posés par les services serveur (lus sans require).
local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService
local CARRYING_ATTRIBUTE = "Carrying" -- CarryService : Id de rareté du colis porté
local STATE_ATTRIBUTE = "UnboxState" -- UnboxService : "Locked", "Free", "Waiting", "Ready"
local BENCH_PATTERN = "^UnboxBench_(%d+)$"
local PROMPT_NAME = "UnboxPrompt"

-- V0 proposé, absent du doc : textes (en anglais, L-036) et portée de l'invite. Le serveur
-- accepte la portée + 4 studs (UnboxService).
local PLACE_TEXT = "Place Box"
local OPEN_TEXT = "Open"
local OBJECT_TEXT = "Workbench"
local PROMPT_DISTANCE = 8

-- Écran de révélation (contrat 2.2) et ce qu'il lit ailleurs.
local REVEAL_SCREEN = "UI_Unbox"
local PREVIEW_HOLDER = "ItemPreview" -- cadre décoratif de Clément, hors contrat : aperçu s'il existe
local PREVIEW_NAME = "ItemViewport" -- ViewportFrame créé ici dans ItemPreview
local ITEMS_FOLDER = { "Assets", "Items" } -- modèles ITM_ de Clément, depuis ReplicatedStorage
local DISPLAY_TAG = "DisplayItem" -- DisplayService : objet exposé (attributs ItemUid et Income)
-- V0 proposé, absent du doc : l'écran se ferme tout seul au bout de ce délai (s).
local REVEAL_AUTO_CLOSE = 6
-- V0 proposé, absent du doc : attente max (s) de l'objet exposé dont on lit le revenu (Secret).
local SECRET_INCOME_WAIT = 2
-- V0 proposé, absent du doc : champ de vision (degrés) de la caméra de l'aperçu.
local PREVIEW_FOV = 30

local IS_STUDIO = RunService:IsStudio()
local MAX_BENCHES = Balance.Unbox.MaxBenches

local UnboxController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local animation: AnimationApi? = nil
local plot: Model? = nil
local plotConnections: { RBXScriptConnection } = {}
local watchedPlots: { [Instance]: RBXScriptConnection } = {}
local views: { [number]: BenchView } = {}
local ready: { [number]: boolean } = {} -- BoxReady reçu, pas encore ouvert
local revealQueue: { Reveal } = {} -- révélations en attente d'affichage
local revealing: Reveal? = nil -- révélation à l'écran
local revealToken = 0
local continueButton: GuiButton? = nil
local continueConnection: RBXScriptConnection? = nil
local screenMissingWarned = false

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
		anim.PlayPlayer(name)
	end
end

local function isCarrying(): boolean
	local carrying = localPlayer:GetAttribute(CARRYING_ATTRIBUTE)
	return type(carrying) == "string" and carrying ~= ""
end

-- Montre, cache ou change l'invite de l'établi `index` selon son état.
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

local function onTriggered(index: number)
	local view = views[index]
	if view == nil then
		return
	end
	if view.mode == "Place" then
		net.Client.PlaceBox:Fire(index)
		playAnimation("Place")
	elseif view.mode == "Open" then
		net.Client.OpenBox:Fire(index)
		playAnimation("Unbox")
	end
end

-- Numéro de l'établi si `inst` est un UnboxBench_xx, sinon nil.
local function benchIndexOf(inst: Instance): number?
	if not inst:IsA("Attachment") then
		return nil
	end
	local digits = string.match(inst.Name, BENCH_PATTERN)
	local index = if digits then tonumber(digits) else nil
	if index and index >= 1 and index <= MAX_BENCHES then
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
	local index = benchIndexOf(inst)
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

	local view: BenchView = { attachment = attachment, prompt = prompt, mode = nil, connections = {} }
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
				ready[index] = nil -- établi libéré, verrouillé ou de nouveau en attente
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
			local index = benchIndexOf(inst)
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
		print(`[Unbox] le colis de l'établi {index} est prêt`)
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

-- Écrit `text` dans le TextLabel `name` de l'écran (cherché parmi les descendants, Contract/Find),
-- ou le cache si `text` est nil ; `color` colore le texte. Élément absent : rien (le
-- ContractChecker le signale).
local function setText(screen: Instance, name: string, text: string?, color: Color3?)
	local found = Find.path(screen, name)
	if found == nil or not found:IsA("TextLabel") then
		return
	end
	local label = found :: TextLabel
	if text == nil then
		label.Visible = false
		return
	end
	label.Text = text
	label.Visible = true
	if color then
		label.TextColor3 = color
	end
end

-- Revenu de l'objet exposé `itemUid` (attribut Income posé par DisplayService), ou nil.
local function displayedIncome(itemUid: string): number?
	for _, model in CollectionService:GetTagged(DISPLAY_TAG) do
		if model:GetAttribute("ItemUid") == itemUid then
			local income = model:GetAttribute("Income")
			return if type(income) == "number" then income else nil
		end
	end
	return nil
end

local function clearPreview(screen: Instance)
	local holder = Find.path(screen, PREVIEW_HOLDER)
	local old = if holder then holder:FindFirstChild(PREVIEW_NAME) else nil
	if old then
		old:Destroy()
	end
end

-- Bonus : le modèle ITM_<ItemId> de Clément dans un ViewportFrame transparent posé dans
-- ItemPreview, vu de face (10.1 : face avant vers −Z du pivot). Rien si l'un des deux manque.
local function showPreview(screen: Instance, asset: string)
	clearPreview(screen)
	local holder = Find.path(screen, PREVIEW_HOLDER)
	if holder == nil or not holder:IsA("GuiObject") then
		return
	end
	local folder: Instance? = ReplicatedStorage
	for _, name in ITEMS_FOLDER do
		folder = if folder then folder:FindFirstChild(name) else nil
	end
	local template = if folder then folder:FindFirstChild(asset, true) else nil
	if template == nil or not (template:IsA("Model") or template:IsA("BasePart")) then
		return -- objet pas encore livré : ItemPreview reste tel que Clément l'a posé
	end
	local copy = template:Clone()
	if copy == nil then
		return -- Archivable = false
	end
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local model: Model
	if copy:IsA("Model") then
		model = copy :: Model
	else
		local part: Instance = copy
		model = Instance.new("Model")
		part.Parent = model
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = PREVIEW_NAME
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	model.Parent = viewport
	local center, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = PREVIEW_FOV
	local distance = (size.Magnitude / 2) / math.sin(math.rad(PREVIEW_FOV / 2))
	camera.CFrame = CFrame.lookAt(center.Position + model:GetPivot().LookVector * distance, center.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Parent = holder
end

local showNextReveal: () -> ()

local function closeReveal()
	revealToken += 1
	revealing = nil
	local screen = revealScreen()
	if screen then
		clearPreview(screen)
		screen.Enabled = false
	end
	showNextReveal()
end

-- ContinueButton ferme l'écran ; rebranché si l'écran a été recréé.
local function bindContinue(screen: Instance)
	local found = Find.path(screen, "ContinueButton")
	local button = if found and found:IsA("GuiButton") then found :: GuiButton else nil
	if button == continueButton then
		return
	end
	local old = continueConnection
	if old then
		old:Disconnect()
		continueConnection = nil
	end
	continueButton = button
	if button then
		continueConnection = button.Activated:Connect(function()
			if revealing ~= nil then
				closeReveal()
			end
		end)
	end
end

local function fillIncome(screen: Instance, reveal: Reveal, zone: number?, rarityId: string, token: number)
	if zone then
		setText(screen, "Income", Format.income(Formulas.ItemIncome(zone, rarityId)))
		return
	end
	-- Secret : revenu connu du serveur seul (zone du colis) ; lu sur l'objet s'il vient d'être exposé.
	setText(screen, "Income", nil)
	task.spawn(function()
		local deadline = os.clock() + SECRET_INCOME_WAIT
		while token == revealToken and os.clock() < deadline do
			local income = displayedIncome(reveal.itemUid)
			if income then
				setText(screen, "Income", Format.income(income))
				return
			end
			task.wait(0.1)
		end
	end)
end

showNextReveal = function()
	if revealing ~= nil then
		return
	end
	while #revealQueue > 0 do
		local reveal = table.remove(revealQueue, 1) :: Reveal
		local item = Items.ById[reveal.itemId]
		if item == nil then
			continue -- objet inconnu du catalogue client (déjà écrit dans la sortie)
		end
		local screen = revealScreen()
		if screen == nil then
			if IS_STUDIO and not screenMissingWarned then
				screenMissingWarned = true
				warn(`[Unbox] écran {REVEAL_SCREEN} absent de PlayerGui : révélation dans la sortie seulement`)
			end
			table.clear(revealQueue)
			return
		end
		revealing = reveal
		revealToken += 1
		local token = revealToken
		local rarity = Rarities.ById[item.Rarity]
		setText(screen, "Rarity", rarity.DisplayNameUpper, rarity.Color)
		setText(screen, "ItemName", item.DisplayName)
		fillIncome(screen, reveal, item.Zone, item.Rarity, token)
		showPreview(screen, item.Asset)
		bindContinue(screen)
		screen.Enabled = true
		task.delay(REVEAL_AUTO_CLOSE, function()
			if token == revealToken then
				closeReveal()
			end
		end)
		return
	end
end

local function onReveal(index: number, itemUid: string, itemId: string)
	ready[index] = nil
	refresh(index)
	table.insert(revealQueue, { itemUid = itemUid, itemId = itemId })
	showNextReveal()
	if not IS_STUDIO then
		return
	end
	local item = Items.ById[itemId]
	if item == nil then
		print(`[Unbox] établi {index} : objet inconnu {itemId} (uid {itemUid})`)
		return
	end
	local rarity = Rarities.ById[item.Rarity]
	-- Le Secret n'a pas de zone : son revenu dépend de celle du colis, que le client ne connaît pas.
	local zone = item.Zone
	local income = if zone then ` · {Formulas.ItemIncome(zone, item.Rarity)} $/s` else ""
	print(`[Unbox] établi {index} : {rarity.DisplayNameUpper} · {item.DisplayName}{income} ({itemId}, uid {itemUid})`)
end

function UnboxController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	animation = loadAnimationController()

	net.Client.BoxReady:Connect(onBoxReady)
	net.Client.UnboxReveal:Connect(onReveal)
	localPlayer:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(refreshAll)

	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(watchPlot)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(unwatchPlot)
	for _, inst in CollectionService:GetTagged(PLOT_TAG) do
		watchPlot(inst)
	end
end

return UnboxController
