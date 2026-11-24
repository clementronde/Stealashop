--!strict
-- ItemLoopController (a429, lot100 ; liaison L-339, Clément 24/11) : petite animation en boucle des objets du catalogue
-- v3 (Config/Items, Features.ItemsV3 / ItemsV3Dev). Chaque modèle animé de Clément a un AnimationController avec son
-- Animator et un dossier Animations avec l'objet Animation « Boucle » (Contract/Animations.ItemLoop) ; elle ne bouge
-- que des os, donc elle se joue en même temps que l'idle et le flottement d'ItemIdleController (qui déplacent les
-- pièces). Aucun script dans le modèle : tout se joue ici, en local, chez chaque joueur ; rien n'est envoyé au serveur.
--
-- Objets suivis : les objets exposés (tag DisplayItem, DisplayService) et portés ou lâchés (tag CarriedItem,
-- CarryService et HeldItemService), copies des modèles ITM_ qui gardent leur AnimationController et leurs Animations.
-- Un objet sans Boucle (les objets v2, Z4_LunettesDeStar) n'est pas suivi, sans message. La boucle est chargée par son
-- nom (jamais un ID), jouée en boucle tant que l'objet est à moins de Config/ItemIdle.LoopMaxDistance de la caméra,
-- arrêtée au-delà (contrôle toutes les LoopCheckInterval s) ; LoopEnabled = false : aucune boucle.
--
-- API (client) :
--   ItemLoopController.GetStats() -> { Tracked: number, Playing: number }   pour les tests

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemIdle = require(Shared:WaitForChild("Config"):WaitForChild("ItemIdle"))
local Animations = require(Shared:WaitForChild("Contract"):WaitForChild("Animations"))

local TAGS = { "DisplayItem", "CarriedItem" } -- posés par DisplayService, CarryService et HeldItemService (mêmes noms)
local FOLDER: string = Animations.FolderName
local LOOP_NAME: string = Animations.ItemLoop.Name
local FADE = 0.2 -- s, fondu d'entrée et de sortie de la boucle

type Entry = {
	model: Model,
	animator: Animator,
	animation: Animation,
	track: AnimationTrack?,
}

local entries: { [Model]: Entry } = {}

local ItemLoopController = {}

-- L'Animator de l'AnimationController du modèle et son objet Animation « Boucle », ou nil.
local function find(model: Model): (Animator?, Animation?)
	local folder = model:FindFirstChild(FOLDER)
	local animation = if folder then folder:FindFirstChild(LOOP_NAME) else nil
	if animation == nil or not animation:IsA("Animation") or (animation :: Animation).AnimationId == "" then
		return nil, nil
	end
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = if controller then controller:FindFirstChildOfClass("Animator") else nil
	if animator == nil then
		return nil, nil
	end
	return animator, animation :: Animation
end

local function stop(entry: Entry)
	local current = entry.track
	entry.track = nil
	if current ~= nil then
		local active: AnimationTrack = current
		pcall(function()
			active:Stop(FADE)
			active:Destroy()
		end)
	end
end

local function play(entry: Entry)
	if entry.track ~= nil then
		return
	end
	local ok, loaded = pcall(function(): AnimationTrack
		return entry.animator:LoadAnimation(entry.animation)
	end)
	if not ok then
		return
	end
	loaded.Looped = true
	loaded:Play(FADE)
	entry.track = loaded
end

local function untrack(model: Instance)
	local entry = entries[model :: Model]
	if entry then
		entries[model :: Model] = nil
		stop(entry)
	end
end

local function track(inst: Instance)
	if not inst:IsA("Model") or entries[inst :: Model] ~= nil then
		return
	end
	local model = inst :: Model
	local animator, animation = find(model)
	if animator == nil or animation == nil then
		return
	end
	entries[model] = { model = model, animator = animator, animation = animation, track = nil }
end

-- Distance caméra ↔ objet : boucle jouée de près, arrêtée de loin ou quand l'objet a quitté la place.
local function refresh()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else nil
	local range: number = ItemIdle.LoopMaxDistance
	for model, entry in entries do
		if not model:IsDescendantOf(Workspace) then
			if model.Parent == nil then
				untrack(model)
			else
				stop(entry)
			end
			continue
		end
		local near = eye ~= nil and (model:GetPivot().Position - eye).Magnitude <= range
		if near then
			play(entry)
		else
			stop(entry)
		end
	end
end

function ItemLoopController.GetStats(): { Tracked: number, Playing: number }
	local tracked, playing = 0, 0
	for _, entry in entries do
		tracked += 1
		if entry.track ~= nil then
			playing += 1
		end
	end
	return { Tracked = tracked, Playing = playing }
end

function ItemLoopController.Start()
	if ItemIdle.LoopEnabled ~= true then
		return
	end
	for _, tag in TAGS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(track)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
		for _, inst in CollectionService:GetTagged(tag) do
			track(inst)
		end
	end
	local interval: number = ItemIdle.LoopCheckInterval
	task.spawn(function()
		while true do
			refresh()
			task.wait(interval)
		end
	end)
end

return ItemLoopController
