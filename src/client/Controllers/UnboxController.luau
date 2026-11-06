--!strict
-- UnboxController (DEV-019, client) : les établis d'ouverture de sa propre parcelle
-- (Partie 1, sections 5.6, 5.7 et 9.4).
--
-- Rôle :
--   - sur chaque UnboxBench_xx de la parcelle du joueur (attribut OwnerUserId = son UserId, posé
--     par PlotService), une invite créée ici, côté client seulement (ProximityPrompt
--     « UnboxPrompt ») :
--       « Poser le colis » quand le joueur porte un colis (attribut Carrying du Player, posé par
--       CarryService) et que l'établi est libre (attribut UnboxState = "Free" de l'établi, posé
--       par UnboxService) : envoie PlaceBox(benchIndex) ;
--       « Ouvrir » quand BoxReady(benchIndex) est arrivé (ou UnboxState = "Ready") : envoie
--       OpenBox(benchIndex) ;
--     sinon l'invite est cachée. Le serveur revérifie tout (parcelle, portée, établi débloqué et
--     libre, colis porté, attente écoulée) ;
--   - joue Place ou Unbox (contrat 2.4) au déclenchement, par AnimationController s'il est là ;
--   - UnboxReveal(benchIndex, itemUid, itemId) : en attendant l'écran UI_Unbox de Clément et la
--     révélation complète (DEV-050), écrit l'objet révélé dans la sortie, en Studio.
-- Les invites suivent le streaming : un établi qui sort de la zone chargée perd son invite, elle
-- revient avec lui. Aucune UI créée ici, aucune règle de jeu : le serveur décide.

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

type Mode = "Place" | "Open"

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

-- V0 proposé, absent du doc : textes et portée de l'invite. Le serveur accepte la portée
-- + 4 studs (UnboxService).
local PLACE_TEXT = "Poser le colis"
local OPEN_TEXT = "Ouvrir"
local OBJECT_TEXT = "Établi"
local PROMPT_DISTANCE = 8

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

local function onReveal(index: number, itemUid: string, itemId: string)
	ready[index] = nil
	refresh(index)
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
