--!strict
-- UpgradeController (DEV-033, client) : invites d'achat des améliorations de base, sur sa propre
-- parcelle (Partie 1, sections 5.1, 5.8, 7.5 et 9.4).
--
-- Rôle : sur la parcelle dont le joueur est propriétaire (attribut OwnerUserId = son UserId, posé
-- par PlotService), quatre invites créées ici, côté client seulement (ProximityPrompt
-- « UpgradePrompt », touche F ou bouton Y, maintien de HOLD_DURATION s) :
--   - « Upgrade ($380) » sur le tapis (tag Treadmill) et sur le banc (tag Bench), avec le nom et le
--     niveau (« Treadmill Lv 1/20 »). Posée sur l'Attachment UpgradePoint du modèle s'il existe
--     (proposition de contrat, hors 10.4 pour l'instant), sinon sur un point créé ici au-dessus du
--     modèle. Jamais sur le UsePoint, qui porte l'invite « Run » / « Lift » de TrainingService :
--     les deux invites n'ont pas la même touche, elles s'affichent ensemble ;
--   - « Unlock stand ($500) » sur le prochain DisplaySlot_xx verrouillé (« Stands 4/20 ») ;
--   - « Unlock workbench ($2K) » sur le prochain UnboxBench_xx verrouillé (« Workbenches 1/4 »).
-- Chacune envoie BuyItem(Id de l'amélioration) ; le serveur (ShopService) revérifie tout et prévient
-- le joueur (Notify). Le prix affiché est Formulas.UpgradeCost(Id, niveau), avec le niveau lu dans
-- les attributs TreadmillLevel, BenchLevel, DisplaySlotsLevel et UnboxBenchesLevel du Player
-- (ShopService) : pour l'affichage seulement. Le prochain présentoir verrouillé est le n° départ +
-- niveau + 1 (Balance.Display, Balance.Unbox), comme côté serveur. Au niveau max, l'invite
-- disparaît. Après un achat, l'invite est coupée jusqu'au nouveau niveau, ou PENDING_TIMEOUT s si
-- le serveur refuse : un 2e maintien ne paie jamais un prix qui n'était pas affiché.
-- Les invites suivent le streaming et les changements de parcelle. Aucune UI créée ici.
--
-- API (client) : aucune.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Formulas = require(Config:WaitForChild("Formulas"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))

type Kind = "Machine" | "Stand" | "Workbench"

type Offer = {
	id: string, -- Id de Config/Upgrades
	kind: Kind,
	tag: string?, -- tag de la machine (Machine seulement)
	prompt: ProximityPrompt?,
	pendingLevel: number?, -- niveau au moment du dernier achat demandé
	pendingUntil: number,
}

-- Contrat (2.1 et 10.4) et attributs posés par les services serveur (lus sans require).
local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId" -- PlotService
local LEVEL_FORMAT = "%sLevel" -- ShopService : TreadmillLevel, BenchLevel…
local SLOT_FORMAT = "DisplaySlot_%02d"
local BENCH_FORMAT = "UnboxBench_%02d"
local POINT_NAME = "UpgradePoint" -- proposé à Clément : lu s'il existe dans le tapis ou le banc
local MADE_POINT_NAME = "UpgradePointV0" -- point créé ici à défaut, côté client seulement
local PROMPT_NAME = "UpgradePrompt"

-- V0 proposés, absents du doc : textes (en anglais, L-036), portée et maintien de l'invite, touches
-- (pas E, celle des invites Run / Lift / Place Box : elles restent visibles à côté), hauteur du point
-- créé au-dessus d'une machine, délai d'attente de la réponse du serveur après un achat.
local TEXT = {
	Upgrade = "Upgrade (%s)",
	UnlockStand = "Unlock stand (%s)",
	UnlockWorkbench = "Unlock workbench (%s)",
	MachineLevel = "%s Lv %d/%d",
	Stands = "Stands %d/%d",
	Workbenches = "Workbenches %d/%d",
}
local PROMPT_DISTANCE = 8
local HOLD_DURATION = 0.5
local KEYBOARD_KEY = Enum.KeyCode.F
local GAMEPAD_KEY = Enum.KeyCode.ButtonY
local POINT_HEIGHT = 0.5 -- studs au-dessus du sommet du modèle
local PENDING_TIMEOUT = 1.5

local UpgradeController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local plot: Model? = nil
local plotConnections: { RBXScriptConnection } = {}
local watchedPlots: { [Instance]: RBXScriptConnection } = {}
local madePoints: { [Instance]: Attachment } = {} -- machine → point créé ici
local refreshQueued = false

local offers: { Offer } = {
	{ id = "Treadmill", kind = "Machine", tag = "Treadmill", pendingUntil = 0 },
	{ id = "Bench", kind = "Machine", tag = "Bench", pendingUntil = 0 },
	{ id = "DisplaySlots", kind = "Stand", pendingUntil = 0 },
	{ id = "UnboxBenches", kind = "Workbench", pendingUntil = 0 },
}

local function levelOf(id: string): number?
	local value = localPlayer:GetAttribute(string.format(LEVEL_FORMAT, id))
	return if type(value) == "number" then value else nil
end

-- Point de l'invite d'une machine : son UpgradePoint, sinon un point créé ici au-dessus d'elle.
local function machinePoint(machine: Instance): Attachment?
	local given = Find.path(machine, POINT_NAME)
	if given and given:IsA("Attachment") then
		return given :: Attachment
	end
	local made = madePoints[machine]
	if made and made:IsDescendantOf(machine) then
		return made
	end
	local part: BasePart? = nil
	local primary = if machine:IsA("Model") then (machine :: Model).PrimaryPart else nil
	if primary and primary:IsDescendantOf(machine) then
		part = primary
	elseif machine:IsA("BasePart") then
		part = machine :: BasePart
	else
		local found = machine:FindFirstChildWhichIsA("BasePart", true)
		part = if found then found :: BasePart else nil
	end
	if part == nil then
		return nil -- pas encore chargée (streaming)
	end
	local carrier = part :: BasePart
	local top: Vector3
	if machine:IsA("Model") then
		local boxCFrame, boxSize = (machine :: Model):GetBoundingBox()
		top = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2 + POINT_HEIGHT, 0)
	else
		top = carrier.Position + Vector3.new(0, carrier.Size.Y / 2 + POINT_HEIGHT, 0)
	end
	local offset: Vector3 = carrier.CFrame:PointToObjectSpace(top)
	local point = Instance.new("Attachment")
	point.Name = MADE_POINT_NAME
	point.CFrame = CFrame.new(offset)
	point.Parent = carrier
	madePoints[machine] = point
	return point
end

local function attachmentIn(root: Instance, name: string): Attachment?
	local found = Find.path(root, name)
	if found and found:IsA("Attachment") then
		return found :: Attachment
	end
	return nil
end

-- Où poser l'invite de `offer` au niveau `level`, ou nil (rien à acheter ici pour l'instant).
local function targetFor(offer: Offer, plotModel: Model, level: number): Attachment?
	if offer.kind == "Machine" then
		for _, machine in CollectionService:GetTagged(offer.tag or "") do
			if machine:IsDescendantOf(plotModel) then
				return machinePoint(machine)
			end
		end
		return nil
	elseif offer.kind == "Stand" then
		local index = Balance.Display.StartSlots + level + 1
		return if index <= Balance.Display.MaxSlots then attachmentIn(plotModel, string.format(SLOT_FORMAT, index)) else nil
	end
	local index = Balance.Unbox.StartBenches + level + 1
	return if index <= Balance.Unbox.MaxBenches then attachmentIn(plotModel, string.format(BENCH_FORMAT, index)) else nil
end

-- Textes de l'invite : action (avec le prix) et objet (avec le niveau ou le compte).
local function textsFor(offer: Offer, level: number, cost: number): (string, string)
	local price = Format.money(cost)
	if offer.kind == "Machine" then
		local upgrade = Upgrades.ById[offer.id]
		return string.format(TEXT.Upgrade, price), string.format(TEXT.MachineLevel, upgrade.DisplayName, level, upgrade.MaxLevel)
	elseif offer.kind == "Stand" then
		local display = Balance.Display
		local unlocked = math.min(display.StartSlots + level, display.MaxSlots)
		return string.format(TEXT.UnlockStand, price), string.format(TEXT.Stands, unlocked, display.MaxSlots)
	end
	local unbox = Balance.Unbox
	local unlocked = math.min(unbox.StartBenches + level, unbox.MaxBenches)
	return string.format(TEXT.UnlockWorkbench, price), string.format(TEXT.Workbenches, unlocked, unbox.MaxBenches)
end

local scheduleRefresh: () -> ()

local function onTriggered(offer: Offer, prompt: ProximityPrompt)
	local level = levelOf(offer.id)
	if level == nil or offer.prompt ~= prompt or not prompt.Enabled then
		return
	end
	offer.pendingLevel = level
	offer.pendingUntil = os.clock() + PENDING_TIMEOUT
	prompt.Enabled = false
	net.Client.BuyItem:Fire(offer.id)
	task.delay(PENDING_TIMEOUT, scheduleRefresh)
end

local function newPrompt(offer: Offer): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.HoldDuration = HOLD_DURATION
	prompt.KeyboardKeyCode = KEYBOARD_KEY
	prompt.GamepadKeyCode = GAMEPAD_KEY
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		onTriggered(offer, prompt)
	end)
	return prompt
end

local function hide(offer: Offer)
	local prompt = offer.prompt
	if prompt then
		offer.prompt = nil
		prompt:Destroy()
	end
end

local function refreshOffer(offer: Offer)
	local plotModel = plot
	local level = levelOf(offer.id)
	if plotModel == nil or level == nil then
		hide(offer)
		return
	end
	local cost = Formulas.UpgradeCost(offer.id, level)
	local target = if cost then targetFor(offer, plotModel, level) else nil
	if cost == nil or target == nil then
		hide(offer) -- niveau max, ou point pas encore chargé
		return
	end
	local prompt = offer.prompt
	if prompt == nil or prompt.Parent ~= target then
		-- Déplacée (achat), ou détruite avec son point (streaming) : une invite neuve.
		hide(offer)
		local fresh = newPrompt(offer)
		fresh.Parent = target
		offer.prompt = fresh
		prompt = fresh
	end
	local current = prompt :: ProximityPrompt
	local action, object = textsFor(offer, level, cost)
	current.ActionText = action
	current.ObjectText = object
	current.Enabled = not (offer.pendingLevel == level and os.clock() < offer.pendingUntil)
end

local function refreshAll()
	refreshQueued = false
	for _, offer in offers do
		refreshOffer(offer)
	end
end

-- Une seule mise à jour par image, quel que soit le nombre d'événements.
scheduleRefresh = function()
	if not refreshQueued then
		refreshQueued = true
		task.defer(refreshAll)
	end
end

local function setPlot(newPlot: Model?)
	if newPlot == plot then
		return
	end
	for _, offer in offers do
		hide(offer)
	end
	for _, point in madePoints do
		point:Destroy()
	end
	table.clear(madePoints)
	for _, connection in plotConnections do
		connection:Disconnect()
	end
	table.clear(plotConnections)
	plot = newPlot
	if newPlot then
		local function onDescendant(_inst: Instance)
			scheduleRefresh()
		end
		table.insert(plotConnections, newPlot.DescendantAdded:Connect(onDescendant))
		table.insert(plotConnections, newPlot.DescendantRemoving:Connect(onDescendant))
	end
	scheduleRefresh()
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

function UpgradeController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any

	for _, offer in offers do
		localPlayer:GetAttributeChangedSignal(string.format(LEVEL_FORMAT, offer.id)):Connect(scheduleRefresh)
	end
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(watchPlot)
	CollectionService:GetInstanceRemovedSignal(PLOT_TAG):Connect(unwatchPlot)
	for _, inst in CollectionService:GetTagged(PLOT_TAG) do
		watchPlot(inst)
	end
end

return UpgradeController
