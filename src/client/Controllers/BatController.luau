--!strict
-- BatController (client, DEV-043 et DEV-048) : la batte vue par le joueur (Partie 1, 6.2 et 9.4 ;
-- serveur : BatService ; la batte elle-même est donnée par ToolService ; valeurs : Config/Bat).
-- Rien de ce qui compte ne se décide ici : cible, recharge, portée, effet et ramassage sont au serveur.
--
--   - Coup : quand le joueur active la batte (clic ou tap : Tool.Activated du Tool qui porte
--     l'attribut BatTool), au plus une fois toutes les Bat.Cooldown s, personnage vivant, batte en
--     main, mains vides (attribut Carrying) et pas étourdi : il joue SwingBat (AnimationController
--     s'il est là) et envoie SwingBat au serveur quand le coup touche, au marqueur Impact de
--     l'animation (2.4), comme les coups sur les vitrines (HitController) :
--       - SwingBat pas livrée (ou AnimationController absent) : SwingBat part au clic ;
--       - marqueur pas arrivé après Bat.ImpactMaxWait s : le coup part quand même ;
--       - au moment d'envoyer, la batte doit être encore en main et le personnage vivant, sinon le
--         coup est abandonné (le serveur l'aurait refusé).
--     Même dans le vide : c'est le serveur qui choisit la cible. Le son du coup est celui du
--     marqueur (MarkerSounds : SwingBat_Impact, joué par AnimationController).
--   - Étourdi par un coup (attribut BatStun du joueur local, posé par BatService) : « Knockback »
--     → Knockback, puis Stunned tant que l'attribut reste ; « Stun » → Stunned tant qu'il reste.
--     Fin (attribut retiré) : Stunned s'arrête. Animations pas livrées : rien ne se joue.
--   - Colis tombé au sol après un coup (modèles de Workspace/CarryDrops portant BatDrop, posés par
--     CarryService) : ProximityPrompt Bat.GrabActionText (« Grab ») / « Premium Box », maintien
--     Bat.DroppedGrabTime, portée Bat.DroppedGrabMaxDistance − 0,5, active mains vides et pas
--     étourdi. Début du maintien : GrabDropped(dropId) ; invite déclenchée : GrabDropped(dropId)
--     une seconde fois et animation Grab. Les colis du camion (TruckBox) restent à TruckController.
--   - Alerte de vol (TheftAlert(true), envoyée par PvPService à la victime ; 6.2 usage 1,
--     PvP.AutoEquipBatOnAlert) : la batte s'équipe toute seule, si le joueur ne porte rien.
--
-- Lu sur les objets (rien n'est cherché par chemin) : attributs BatTool (Tool, ToolService),
-- Carrying (Player, CarryService), BatStun (Player, BatService), DropId, Tier et BatDrop (colis au
-- sol, CarryService). API (client) : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Bat = require(Config:WaitForChild("Bat"))
local PvP = require(Config:WaitForChild("PvP"))

-- Ce que ce contrôleur utilise d'AnimationController (a09).
type AnimationApi = {
	PlayPlayer: (name: string) -> AnimationTrack?,
	StopPlayer: (name: string) -> (),
}

-- Coup d'un clic qui attend le marqueur Impact de SwingBat.
type PendingSwing = {
	Tool: Tool,
	Character: Model,
	Sent: boolean, -- déjà parti (ou abandonné) : plus rien ne le renvoie
	Connection: RBXScriptConnection?,
}

type DropWatch = {
	Model: Model,
	DropId: string,
	Prompt: ProximityPrompt?,
}

-- Posés par le serveur (mêmes noms dans ToolService, BatService et CarryService).
local BAT_ATTRIBUTE = "BatTool"
local STUN_ATTRIBUTE = "BatStun"
local CARRYING_ATTRIBUTE = "Carrying"
local DROPS_FOLDER = "CarryDrops"
local DROP_ID_ATTRIBUTE = "DropId"
local TIER_ATTRIBUTE = "Tier"
local BAT_DROP_ATTRIBUTE = "BatDrop"
-- Contrat 2.4.
local SWING_ANIMATION = "SwingBat"
local STUNNED_ANIMATION = "Stunned"
local KNOCKBACK_ANIMATION = "Knockback"
local GRAB_ANIMATION = "Grab"
local IMPACT_MARKER = "Impact"
local PROMPT_NAME = "GrabPrompt"
local BOX_SUFFIX = "Box" -- « Premium Box » (L-036, comme le camion)

-- V0 proposé, absent du doc : invite visible un demi-stud avant la portée du serveur (comme les rayons).
local PROMPT_DISTANCE_MARGIN = 0.5

local player = Players.LocalPlayer

local BatController = {}

local Net: any = nil
local animation: AnimationApi? = nil
local lastSwingAt = -math.huge
local pending: PendingSwing? = nil
local hookedTools = setmetatable({} :: { [Tool]: boolean }, { __mode = "k" })
local drops: { [Instance]: DropWatch } = {}
local stunKind: string? = nil
local stunToken = 0

local function isBat(instance: Instance): boolean
	return instance:IsA("Tool") and instance:GetAttribute(BAT_ATTRIBUTE) == true
end

local function isCarrying(): boolean
	return player:GetAttribute(CARRYING_ATTRIBUTE) ~= nil
end

local function isStunned(): boolean
	return player:GetAttribute(STUN_ATTRIBUTE) ~= nil
end

local function play(name: string): AnimationTrack?
	local api = animation
	if api == nil then
		return nil
	end
	local ok, track = pcall(api.PlayPlayer, name)
	return if ok then track else nil
end

local function stopAnimation(name: string)
	local api = animation
	if api then
		pcall(api.StopPlayer, name)
	end
end

-- Le coup ------------------------------------------------------------------------------------------

-- Personnage vivant, batte en main : le coup peut partir.
local function canStrike(tool: Tool, character: Model): boolean
	if player.Character ~= character or tool.Parent ~= character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Envoie le coup en attente `swing`, une seule fois (marqueur, délai max ou clic suivant).
local function sendSwing(swing: PendingSwing)
	if swing.Sent then
		return
	end
	swing.Sent = true
	local connection = swing.Connection
	swing.Connection = nil
	if connection then
		connection:Disconnect()
	end
	if pending == swing then
		pending = nil
	end
	if canStrike(swing.Tool, swing.Character) then
		Net.Client.SwingBat:Fire()
	end
end

local function onActivated(tool: Tool)
	local now = os.clock()
	if now - lastSwingAt < Bat.Cooldown then
		return
	end
	local character = player.Character
	if character == nil or not canStrike(tool, character) or isCarrying() or isStunned() then
		return
	end
	lastSwingAt = now
	local previous = pending
	if previous then
		sendSwing(previous) -- avant que l'animation reparte du début
	end
	local track = play(SWING_ANIMATION)
	if track == nil then
		Net.Client.SwingBat:Fire() -- pas d'animation : le coup part au clic
		return
	end
	local swing: PendingSwing = { Tool = tool, Character = character, Sent = false, Connection = nil }
	pending = swing
	-- Branché après le Play de ce clic : un marqueur de la lecture précédente ne peut pas l'atteindre.
	local ok, signal = pcall(function()
		return track:GetMarkerReachedSignal(IMPACT_MARKER)
	end)
	if ok and signal then
		swing.Connection = signal:Connect(function()
			sendSwing(swing)
		end)
	end
	task.delay(Bat.ImpactMaxWait, sendSwing, swing)
end

local function hookTool(child: Instance)
	if not isBat(child) then
		return
	end
	local tool = child :: Tool
	if hookedTools[tool] then
		return
	end
	hookedTools[tool] = true
	tool.Activated:Connect(function()
		onActivated(tool)
	end)
end

-- Une batte activée est forcément en main, donc enfant du personnage.
local function watchCharacter(character: Model)
	character.ChildAdded:Connect(hookTool)
	for _, child in character:GetChildren() do
		hookTool(child)
	end
end

-- La batte s'équipe toute seule à l'alerte de vol (6.2, usage 1).
local function equipBat()
	if isCarrying() then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	for _, child in character:GetChildren() do
		if isBat(child) then
			return -- déjà en main
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		return
	end
	for _, child in backpack:GetChildren() do
		if isBat(child) then
			humanoid:EquipTool(child :: Tool)
			return
		end
	end
end

-- Étourdi -----------------------------------------------------------------------------------------

local function onStunChanged()
	local value = player:GetAttribute(STUN_ATTRIBUTE)
	local kind = if type(value) == "string" then value else nil
	if kind == stunKind then
		return
	end
	stunKind = kind
	stunToken += 1
	local token = stunToken
	if kind == nil then
		stopAnimation(STUNNED_ANIMATION)
		return
	end
	local function startStunned()
		if token == stunToken and stunKind ~= nil then
			play(STUNNED_ANIMATION)
		end
	end
	if kind == "Knockback" then
		local track = play(KNOCKBACK_ANIMATION)
		if track then
			track.Stopped:Once(startStunned)
			return
		end
	end
	startStunned()
end

-- Colis tombé au sol -------------------------------------------------------------------------------

local function anchorOf(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return if part then part :: BasePart else nil
end

local function refreshPrompt(watch: DropWatch)
	local prompt = watch.Prompt
	if prompt then
		prompt.Enabled = not isCarrying() and not isStunned()
	end
end

local function refreshPrompts()
	for _, watch in drops do
		refreshPrompt(watch)
	end
end

local function trackDrop(instance: Instance)
	if not instance:IsA("Model") or drops[instance] ~= nil or instance:GetAttribute(BAT_DROP_ATTRIBUTE) ~= true then
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
	local watch: DropWatch = { Model = model, DropId = dropId, Prompt = nil }
	drops[instance] = watch
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = Bat.GrabActionText
	prompt.ObjectText = if info then `{info.DisplayName} {BOX_SUFFIX}` else BOX_SUFFIX
	prompt.HoldDuration = Bat.DroppedGrabTime
	prompt.MaxActivationDistance = math.max(Bat.DroppedGrabMaxDistance - PROMPT_DISTANCE_MARGIN, 1)
	prompt.RequiresLineOfSight = false
	prompt.PromptButtonHoldBegan:Connect(function()
		Net.Client.GrabDropped:Fire(dropId) -- début du maintien
	end)
	prompt.Triggered:Connect(function()
		Net.Client.GrabDropped:Fire(dropId) -- fin du maintien
		play(GRAB_ANIMATION)
	end)
	prompt.Parent = part
	watch.Prompt = prompt
	refreshPrompt(watch)
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

-- Démarrage ----------------------------------------------------------------------------------------

function BatController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	local module = script.Parent:FindFirstChild("AnimationController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type((result :: any).PlayPlayer) == "function" then
			animation = result :: any
		end
	end

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
	player:GetAttributeChangedSignal(STUN_ATTRIBUTE):Connect(function()
		onStunChanged()
		refreshPrompts()
	end)
	player:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(refreshPrompts)
	onStunChanged()

	local folder = Workspace:FindFirstChild(DROPS_FOLDER)
	if folder then
		watchDrops(folder)
	end
	Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == DROPS_FOLDER then
			watchDrops(child)
		end
	end)

	Net.Client.TheftAlert:Connect(function(active: boolean)
		if active and PvP.AutoEquipBatOnAlert then
			equipBat()
		end
	end)
end

return BatController
