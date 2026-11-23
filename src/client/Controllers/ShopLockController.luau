--!strict
-- ShopLockController (client, agent a159, liaison L-163) : le verrou de la boutique (tuile Curtain devenue Lock).
--
-- Tant que Clément n'a pas livré de bouton (question dans la liaison), une invite V0 « Lock » (touche E) est posée
-- par ce client sur la porte de SA boutique (`PlotDoor/Window` du modèle taggé `PlayerPlot` dont OwnerUserId = mon
-- UserId), vue par moi seul. Déclenchée : remote LockShop, sans argument ; le serveur (SkillTreeService) décide de
-- tout et répond par un Notify. Le texte de l'invite suit les attributs du serveur : LockedUntil de la parcelle
-- (« Locked 23s ») et LockReadyAt du joueur (« Lock in 1:42 »), sinon « Lock (30s) » (durée selon Skill_Curtain).
-- Rien n'est décidé ici.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillTree = require(Shared:WaitForChild("Config"):WaitForChild("SkillTree"))

local PLOT_TAG = "PlayerPlot"
local OWNER_ATTRIBUTE = "OwnerUserId"
local DOOR_NAME = "PlotDoor"
local WINDOW_NAME = "Window"
local PROMPT_NAME = "LockPrompt"
local REFRESH = 0.25 -- s entre deux mises à jour du texte (V0)
-- Textes de l'invite, en anglais (L-036), V0 à valider par Clément.
local TEXT = {
	Object = "Shop Lock",
	Ready = "Lock (%ds)",
	Locked = "Locked %ds",
	Cooldown = "Ready in %d:%02d",
}

local player = Players.LocalPlayer
local Lock = SkillTree.Lock

local ShopLockController = {}

local prompt: ProximityPrompt? = nil
local net: any = nil

local function myPlot(): Model?
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:IsA("Model") and plot:GetAttribute(OWNER_ATTRIBUTE) == player.UserId then
			return plot :: Model
		end
	end
	return nil
end

local function windowOf(plot: Model?): Instance?
	local door = if plot then plot:FindFirstChild(DOOR_NAME) else nil
	return if door then door:FindFirstChild(WINDOW_NAME) else nil
end

-- Pièce qui porte l'invite : la vitre, ou sa première pièce si c'est un Model.
local function anchorOf(window: Instance?): BasePart?
	if window == nil then
		return nil
	end
	if window:IsA("BasePart") then
		return window
	end
	return window:FindFirstChildWhichIsA("BasePart", true)
end

local function textFor(plot: Model): string
	local now = Workspace:GetServerTimeNow()
	local lockedUntil = plot:GetAttribute(Lock.UntilAttribute)
	if type(lockedUntil) == "number" and lockedUntil > now then
		return string.format(TEXT.Locked, math.ceil(lockedUntil - now))
	end
	local readyAt = player:GetAttribute(Lock.ReadyAttribute)
	if type(readyAt) == "number" and readyAt > now then
		local left = math.ceil(readyAt - now)
		return string.format(TEXT.Cooldown, left // 60, left % 60)
	end
	local skill = SkillTree.ById.Curtain
	local level = player:GetAttribute(SkillTree.AttributePrefix .. "Curtain")
	local duration = if skill and type(level) == "number" and level > 0 then skill.Effects[level] else nil
	return string.format(TEXT.Ready, duration or Lock.BaseDuration)
end

local function refresh()
	local plot = myPlot()
	local anchor = anchorOf(windowOf(plot))
	if plot == nil or anchor == nil then
		if prompt then
			prompt:Destroy()
			prompt = nil
		end
		return
	end
	local current = prompt
	if current == nil or current.Parent ~= anchor then
		if current then
			current:Destroy()
		end
		local created = Instance.new("ProximityPrompt")
		created.Name = PROMPT_NAME
		created.ObjectText = TEXT.Object
		created.KeyboardKeyCode = Enum.KeyCode.E
		created.HoldDuration = 0
		created.MaxActivationDistance = 10 -- V0
		created.RequiresLineOfSight = false
		created.Triggered:Connect(function()
			if net then
				net.Client.LockShop:Fire()
			end
		end)
		created.Parent = anchor
		prompt = created
		current = created
	end
	local text = textFor(plot)
	if (current :: ProximityPrompt).ActionText ~= text then
		(current :: ProximityPrompt).ActionText = text
	end
end

function ShopLockController.Start()
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	while true do
		local ok, err = pcall(function()
			refresh()
		end)
		if not ok then
			warn(`[ShopLockController] {err}`)
		end
		task.wait(REFRESH)
	end
end

return ShopLockController
