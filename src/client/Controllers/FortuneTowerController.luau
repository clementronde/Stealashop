--!strict
-- FortuneTowerController (client ; vague 37, a123 ; liaison L-108 point 8) : ce que le joueur voit de
-- l'événement de la Fortune Tower (serveur : FortuneTowerService ; valeurs : Config/FortuneTower). Rien de
-- ce qui compte ne se décide ici : PV, butin, contenu et ramassage sont au serveur.
--
--   - Barre de PV de la vitrine (modèle tagué FortuneVault, posé par le serveur) : une copie de
--     BB_FortuneHP de Clément (nom proposé, facultatif ; mêmes éléments `Fill` et `Label` que BB_TruckHP),
--     sinon de BB_TruckHP (la barre du camion, telle quelle), sinon de BB_WindowHP agrandie de
--     HealthBarScale et visible jusqu'à HealthBarMaxDistance studs (repli, comme le camion). Accrochée à
--     l'Attachment HealthBarPoint de la vitrine, sinon à sa pièce Window, sinon à sa PrimaryPart. `Label`
--     écrit « PV / PV max » (Format.hp), `Fill` prend la largeur des PV. Lue sur les attributs HP et MaxHP
--     (WindowService) : juste aussi pour un joueur qui arrive en cours de route. Cachée à la casse (Broken).
--   - Colis de la vitrine au sol (modèles de Workspace/CarryDrops portant l'attribut FortuneBox) :
--     ProximityPrompt GrabActionText (« Grab ») / « Luxury Box », maintien = temps de prise du type
--     (Balance.Heist.BoxTiers[Tier].GrabTime), portée Bat.DroppedGrabMaxDistance − 0,5, active mains
--     vides (attribut Carrying) et pas étourdi (BatStun). Début du maintien : GrabDropped(dropId) ;
--     invite déclenchée : GrabDropped(dropId) une seconde fois et animation Grab. Le serveur vérifie tout.
--     Plusieurs colis à portée : Roblox n'en montre qu'une par touche (Exclusivity OnePerButton).
--
-- Coupé par Config/Features.FortuneTower = false hors de Studio (en Studio, le crochet de test du serveur
-- peut faire apparaître une vitrine même coupé : ce contrôleur la montre).
--
-- API (client) : aucune.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Bat = require(Config:WaitForChild("Bat"))
local Features = require(Config:WaitForChild("Features"))
local FortuneTower = require(Config:WaitForChild("FortuneTower"))
local Shatter = require(Config:WaitForChild("Shatter"))
local Contract = Shared:WaitForChild("Contract")
local Find = require(Contract:WaitForChild("Find"))
local UI = require(Contract:WaitForChild("UI"))
local Format = require(Shared:WaitForChild("Format"))

type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
}

type VaultWatch = {
	Model: Model,
	Billboard: BillboardGui?,
	Fill: GuiObject?,
	FillHeight: UDim,
	Label: TextLabel?,
	Fraction: number?,
	Connections: { RBXScriptConnection },
}

type DropWatch = {
	DropId: string,
	Prompt: ProximityPrompt?,
}

-- Noms du contrat (2.2) et des modèles (Contract/Models.FortuneVault).
local BILLBOARD_NAMES = { "BB_FortuneHP", "BB_TruckHP" } -- dans l'ordre : la plus précise d'abord
local FALLBACK_BILLBOARD = "BB_WindowHP" -- repli : la barre des vitrines, agrandie
local HEALTH_BAR_POINT = "HealthBarPoint"
local WINDOW_NAME = "Window"
-- Posés par le serveur (mêmes noms dans FortuneTowerService, WindowService et CarryService).
local VAULT_TAG = "FortuneVault"
local HP_ATTRIBUTE = "HP"
local MAX_HP_ATTRIBUTE = "MaxHP"
local BROKEN_ATTRIBUTE = "Broken"
local BOX_ATTRIBUTE = "FortuneBox"
local DROP_ID_ATTRIBUTE = "DropId"
local TIER_ATTRIBUTE = "Tier"
local CARRYING_ATTRIBUTE = "Carrying"
local STUN_ATTRIBUTE = "BatStun"
local DROPS_FOLDER = "CarryDrops"
local GRAB_ANIMATION = "Grab" -- contrat 2.4
local PROMPT_NAME = "GrabPrompt"
local BOX_SUFFIX = "Box" -- « Luxury Box » (L-036, comme le camion)

-- V0 proposé, absent du doc : invite visible un demi-stud avant la portée du serveur (comme la batte).
local PROMPT_DISTANCE_MARGIN = 0.5

local IS_STUDIO = RunService:IsStudio()

local player = Players.LocalPlayer

local FortuneTowerController = {}

local Net: any = nil
local animation: AnimationApi? = nil
local playerGui: Instance? = nil
local vaults: { [Instance]: VaultWatch } = {}
local drops: { [Instance]: DropWatch } = {}
local said: { [string]: boolean } = {}

local function once(key: string, message: string)
	if said[key] or not IS_STUDIO then
		return
	end
	said[key] = true
	print(`[FortuneTowerController] {message}`)
end

-- Barre de PV -----------------------------------------------------------------------------------------

local function billboard(name: string): BillboardGui?
	local current: Instance? = ReplicatedStorage
	for _, segment in UI.BillboardFolder do
		current = if current then current:FindFirstChild(segment) else nil
	end
	local found = if current then current:FindFirstChild(name, true) else nil
	if found and found:IsA("BillboardGui") then
		return found :: BillboardGui
	end
	return nil
end

-- Modèle de la barre, et vrai pour le repli BB_WindowHP (à agrandir).
local function billboardTemplate(): (BillboardGui?, boolean)
	for _, name in BILLBOARD_NAMES do
		local found = billboard(name)
		if found then
			return found, false
		end
	end
	local fallback = billboard(FALLBACK_BILLBOARD)
	if fallback then
		once("fallback", `BB_FortuneHP et BB_TruckHP absents : barre de la vitrine = copie de {FALLBACK_BILLBOARD} agrandie`)
		return fallback, true
	end
	once("none", `ni BB_FortuneHP, ni BB_TruckHP, ni {FALLBACK_BILLBOARD} : pas de barre de PV sur la vitrine`)
	return nil, false
end

local function adorneeOf(model: Model): Instance?
	local point = Find.path(model, HEALTH_BAR_POINT)
	if point and (point:IsA("Attachment") or point:IsA("BasePart")) then
		return point
	end
	local window = Find.path(model, WINDOW_NAME)
	if window and window:IsA("BasePart") then
		return window
	end
	return model.PrimaryPart
end

local function refreshBar(watch: VaultWatch)
	local gui = watch.Billboard
	if gui == nil then
		return
	end
	local model = watch.Model
	local maxValue = model:GetAttribute(MAX_HP_ATTRIBUTE)
	local maxHp = if type(maxValue) == "number" then maxValue else 0
	if maxHp <= 0 or model:GetAttribute(BROKEN_ATTRIBUTE) == true then
		gui.Enabled = false
		return
	end
	local hpValue = model:GetAttribute(HP_ATTRIBUTE)
	local hp = math.clamp(if type(hpValue) == "number" then hpValue else maxHp, 0, maxHp)
	local fraction = hp / maxHp
	local wasVisible = gui.Enabled
	gui.Enabled = true
	local label = watch.Label
	if label then
		label.Text = `{Format.hp(hp)} / {Format.hp(maxHp)}`
	end
	local fill = watch.Fill
	if fill and watch.Fraction ~= fraction then
		local target = UDim2.new(fraction, 0, watch.FillHeight.Scale, watch.FillHeight.Offset)
		if wasVisible and watch.Fraction ~= nil then
			TweenService:Create(fill, TweenInfo.new(Shatter.HPBar.TweenTime), { Size = target }):Play()
		else
			fill.Size = target
		end
		watch.Fraction = fraction
	end
end

local function makeBillboard(watch: VaultWatch)
	local gui = playerGui
	if watch.Billboard or gui == nil then
		return
	end
	local template, fallback = billboardTemplate()
	local adornee = adorneeOf(watch.Model)
	if template == nil or adornee == nil then
		return
	end
	local copy = template:Clone()
	copy.Name = `{template.Name}_{watch.Model.Name}`
	if fallback then
		local scale = FortuneTower.HealthBarScale
		local size = copy.Size
		copy.Size = UDim2.new(size.X.Scale * scale, size.X.Offset * scale, size.Y.Scale * scale, size.Y.Offset * scale)
		copy.MaxDistance = FortuneTower.HealthBarMaxDistance
	end
	copy.Adornee = adornee
	copy.ResetOnSpawn = false
	copy.Enabled = false
	local fill = Find.path(copy, "Fill")
	local label = Find.path(copy, "Label")
	if fill and fill:IsA("GuiObject") then
		watch.Fill = fill :: GuiObject
		watch.FillHeight = (fill :: GuiObject).Size.Y
	end
	if label and label:IsA("TextLabel") then
		watch.Label = label :: TextLabel
	end
	watch.Fraction = nil
	copy.Parent = gui
	watch.Billboard = copy
	refreshBar(watch)
end

local function untrackVault(instance: Instance)
	local watch = vaults[instance]
	if watch == nil then
		return
	end
	vaults[instance] = nil
	for _, connection in watch.Connections do
		connection:Disconnect()
	end
	local gui = watch.Billboard
	watch.Billboard = nil
	if gui then
		gui:Destroy()
	end
end

local function trackVault(instance: Instance)
	if not instance:IsA("Model") or vaults[instance] ~= nil then
		return
	end
	local model = instance :: Model
	local watch: VaultWatch = {
		Model = model,
		Billboard = nil,
		Fill = nil,
		FillHeight = UDim.new(1, 0),
		Label = nil,
		Fraction = nil,
		Connections = {},
	}
	vaults[instance] = watch
	for _, name in { HP_ATTRIBUTE, MAX_HP_ATTRIBUTE, BROKEN_ATTRIBUTE } do
		table.insert(
			watch.Connections,
			model:GetAttributeChangedSignal(name):Connect(function()
				refreshBar(watch)
			end)
		)
	end
	makeBillboard(watch)
end

-- Colis au sol ----------------------------------------------------------------------------------------

local function play(name: string)
	local api = animation
	if api then
		pcall(api.PlayPlayer, name)
	end
end

local function promptEnabled(): boolean
	return player:GetAttribute(CARRYING_ATTRIBUTE) == nil and player:GetAttribute(STUN_ATTRIBUTE) == nil
end

local function refreshPrompts()
	local enabled = promptEnabled()
	for _, watch in drops do
		local prompt = watch.Prompt
		if prompt then
			prompt.Enabled = enabled
		end
	end
end

local function anchorOf(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return if part then part :: BasePart else nil
end

local function trackDrop(instance: Instance)
	if not instance:IsA("Model") or drops[instance] ~= nil or instance:GetAttribute(BOX_ATTRIBUTE) ~= true then
		return
	end
	local model = instance :: Model
	local dropId = model:GetAttribute(DROP_ID_ATTRIBUTE)
	local tier = model:GetAttribute(TIER_ATTRIBUTE)
	local part = anchorOf(model)
	if type(dropId) ~= "string" or part == nil then
		return
	end
	local info = if type(tier) == "string" then Balance.Heist.BoxTiers[tier] else nil
	local watch: DropWatch = { DropId = dropId, Prompt = nil }
	drops[instance] = watch
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = FortuneTower.GrabActionText
	prompt.ObjectText = if info then `{info.DisplayName} {BOX_SUFFIX}` else BOX_SUFFIX
	prompt.HoldDuration = if info then info.GrabTime else 0
	prompt.MaxActivationDistance = math.max(Bat.DroppedGrabMaxDistance - PROMPT_DISTANCE_MARGIN, 1)
	prompt.RequiresLineOfSight = false
	prompt.PromptButtonHoldBegan:Connect(function()
		Net.Client.GrabDropped:Fire(dropId) -- début du maintien
	end)
	prompt.Triggered:Connect(function()
		Net.Client.GrabDropped:Fire(dropId) -- fin du maintien
		play(GRAB_ANIMATION)
	end)
	prompt.Enabled = promptEnabled()
	prompt.Parent = part
	watch.Prompt = prompt
end

local function untrackDrop(instance: Instance)
	local watch = drops[instance]
	if watch == nil then
		return
	end
	drops[instance] = nil
	local prompt = watch.Prompt
	watch.Prompt = nil
	if prompt then
		prompt:Destroy()
	end
end

local function watchDrops(folder: Instance)
	-- Les attributs du colis sont posés par le serveur avant le parentage : déjà là à ChildAdded.
	folder.ChildAdded:Connect(trackDrop)
	folder.ChildRemoved:Connect(untrackDrop)
	for _, child in folder:GetChildren() do
		trackDrop(child)
	end
end

-- Démarrage -------------------------------------------------------------------------------------------

function FortuneTowerController.Start()
	if not Features.FortuneTower and not IS_STUDIO then
		return
	end
	Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	local module = script.Parent:FindFirstChild("AnimationController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any).PlayPlayer) == "function" then
			animation = result :: any
		end
	end

	local folder = Workspace:FindFirstChild(DROPS_FOLDER)
	if folder then
		watchDrops(folder)
	end
	Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == DROPS_FOLDER then
			watchDrops(child)
		end
	end)
	player:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(refreshPrompts)
	player:GetAttributeChangedSignal(STUN_ATTRIBUTE):Connect(refreshPrompts)

	-- Barres de PV : il faut le PlayerGui du joueur.
	playerGui = player:WaitForChild("PlayerGui")
	for _, instance in CollectionService:GetTagged(VAULT_TAG) do
		trackVault(instance)
	end
	-- Avec StreamingEnabled, la vitrine arrive et repart avec la zone autour du joueur.
	CollectionService:GetInstanceAddedSignal(VAULT_TAG):Connect(trackVault)
	CollectionService:GetInstanceRemovedSignal(VAULT_TAG):Connect(untrackVault)
end

return FortuneTowerController
