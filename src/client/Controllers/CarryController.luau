--!strict
-- CarryController (DEV-017, client) : le portage côté joueur (Partie 1, section 5.6).
--
-- Rôle :
--   - suit l'attribut Carrying du joueur local (posé par CarryService : Id de la rareté portée,
--     nil sinon) et appelle AnimationController.SetCarrying(true/false), qui joue CarryIdle à
--     l'arrêt et CarryRun en courant. Sans AnimationController, rien, sans erreur ;
--   - pendant le portage, range tout outil que le joueur sort (5.6 : ni outil ni batte en main).
--     Le serveur fait de même et fait foi ; ici, c'est pour que l'outil ne s'affiche pas en main ;
--   - saut : autorisé (Balance.Carry.CanJump = true, 5.6), rien à faire. Si CanJump passe à false,
--     le saut est coupé pendant le portage ;
--   - colis et objets Secret, portés ou au sol (tag CarryRainbow posé par CarryService) : anime en
--     local leur arc-en-ciel (RainbowColors de la rareté) sur les pièces Tint, la lumière du halo
--     et le texte Rarity de l'étiquette.
-- Aucun remote, aucune UI créée.
--
-- API (client) :
--   CarryController.IsCarrying() -> boolean   le joueur local porte un colis ou un objet

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Balance = require(Config:WaitForChild("Balance"))
local Rarities = require(Config:WaitForChild("Rarities"))

type AnimationApi = {
	SetCarrying: (carrying: boolean) -> (),
}

-- Mêmes noms que CarryService.
local CARRYING_ATTRIBUTE = "Carrying"
local RAINBOW_TAG = "CarryRainbow"
local TINT = "Tint"
local RARITY_LABEL = "Rarity"
-- V0 proposé, absent du doc : durée d'un tour complet de l'arc-en-ciel, en secondes.
local RAINBOW_PERIOD = 2

type Rainbow = {
	tints: { BasePart },
	lights: { Light },
	labels: { TextLabel },
}

local CarryController = {}

local localPlayer = Players.LocalPlayer
local animation: AnimationApi? = nil
local carrying = false
local characterConnection: RBXScriptConnection? = nil
local rainbowColors: { Color3 } = {}
local rainbows: { [Instance]: Rainbow } = {}
local rainbowConnection: RBXScriptConnection? = nil

local function loadAnimationController(): AnimationApi?
	local folder = script.Parent
	local module = if folder then folder:FindFirstChild("AnimationController") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" and type((result :: any).SetCarrying) == "function" then
		return result :: any
	end
	return nil
end

-- Portage du joueur local ----------------------------------------------------------

local function humanoidOf(): Humanoid?
	local character = localPlayer.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function stowTools()
	local humanoid = humanoidOf()
	if carrying and humanoid then
		humanoid:UnequipTools()
	end
end

local function applyJump()
	if Balance.Carry.CanJump then
		return -- saut autorisé pendant le portage (5.6) : on ne touche à rien
	end
	local humanoid = humanoidOf()
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not carrying)
	end
end

local function watchCharacter(character: Model)
	if characterConnection then
		characterConnection:Disconnect()
	end
	characterConnection = character.ChildAdded:Connect(function(child: Instance)
		if carrying and child:IsA("Tool") then
			task.defer(stowTools) -- pas pendant l'événement : Roblox refuse de changer le parent
		end
	end)
	applyJump()
end

local function onCarryingChanged()
	local now = localPlayer:GetAttribute(CARRYING_ATTRIBUTE) ~= nil
	if now == carrying then
		return
	end
	carrying = now
	local anim = animation
	if anim then
		anim.SetCarrying(now)
	end
	if now then
		stowTools()
	end
	applyJump()
end

-- Arc-en-ciel des Secrets ----------------------------------------------------------

local function rainbowAt(clock: number): Color3
	local count = #rainbowColors
	local position = (clock / RAINBOW_PERIOD) % 1 * count
	local index = math.floor(position)
	local from = rainbowColors[index + 1]
	local to = rainbowColors[(index + 1) % count + 1]
	return from:Lerp(to, position - index)
end

local function collect(model: Instance): Rainbow
	local rainbow: Rainbow = { tints = {}, lights = {}, labels = {} }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == TINT then
			table.insert(rainbow.tints, descendant)
		elseif descendant:IsA("Light") then
			table.insert(rainbow.lights, descendant)
		elseif descendant:IsA("TextLabel") and descendant.Name == RARITY_LABEL then
			table.insert(rainbow.labels, descendant)
		end
	end
	return rainbow
end

local function updateRainbows()
	local color = rainbowAt(os.clock())
	for model, rainbow in rainbows do
		if #rainbow.tints + #rainbow.lights + #rainbow.labels == 0 then
			rainbow = collect(model) -- descendants pas encore arrivés au moment du tag
			rainbows[model] = rainbow
		end
		for _, part in rainbow.tints do
			part.Color = color
		end
		for _, light in rainbow.lights do
			light.Color = color
		end
		for _, label in rainbow.labels do
			label.TextColor3 = color
		end
	end
end

local function addRainbow(model: Instance)
	rainbows[model] = collect(model)
	if rainbowConnection == nil then
		rainbowConnection = RunService.RenderStepped:Connect(updateRainbows)
	end
end

local function removeRainbow(model: Instance)
	rainbows[model] = nil
	local connection = rainbowConnection
	if next(rainbows) == nil and connection then
		connection:Disconnect()
		rainbowConnection = nil
	end
end

function CarryController.IsCarrying(): boolean
	return carrying
end

function CarryController.Start()
	animation = loadAnimationController()

	localPlayer:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(onCarryingChanged)
	localPlayer.CharacterAdded:Connect(watchCharacter)
	local character = localPlayer.Character
	if character then
		watchCharacter(character)
	end
	onCarryingChanged()

	for _, rarity in Rarities.List do
		local colors = rarity.RainbowColors
		if rarity.Rainbow and colors and #colors >= 2 then
			rainbowColors = colors
			break
		end
	end
	if #rainbowColors >= 2 then
		CollectionService:GetInstanceAddedSignal(RAINBOW_TAG):Connect(addRainbow)
		CollectionService:GetInstanceRemovedSignal(RAINBOW_TAG):Connect(removeRainbow)
		for _, model in CollectionService:GetTagged(RAINBOW_TAG) do
			addRainbow(model)
		end
	end
end

return CarryController
