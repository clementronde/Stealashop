--!strict
-- AnnounceController (client ; vague 73, a254, L-240 point 3) : les annonces à tout le serveur (remote Announce,
-- envoyé par Shared/Announce) dans l'écran UI_Announce de Clément (facultatif au contrat : Banner, Icon, Message en
-- RichText, Detail). Une annonce à la fois : écran allumé (Banner entre par son Appear de Clément, UiMotionController),
-- Config/Announce.Hold s, puis Motion.Close, puis Gap s avant la suivante. En attente : Config/Announce.MaxQueue au
-- plus (la plus ancienne part). Rien n'est envoyé au serveur.
--
-- Touché : Enabled de l'écran, Text de Message et de Detail, Image d'Icon (première icône livrée parmi celles de
-- l'annonce, sinon l'image de Clément). Message sans RichText chez Clément : le texte sans balises.
-- Écran absent (ou sans Banner.Message) : le texte sans balises part dans NotifyController.Show (catégorie
-- Config/Announce.NotifyKind), tout de suite.
--
-- API (client) :
--   AnnounceController.GetState() -> { Shown: string?, Queue: number, Fallbacks: number }   (bancs, tests en Play)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Settings = require(Shared:WaitForChild("Config"):WaitForChild("Announce"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Icons = require(Shared:WaitForChild("Contract"):WaitForChild("Icons"))

type Entry = { Message: string, Detail: string, Icon: string, Plain: string }

local AnnounceController = {}

local queue: { Entry } = {}
local shown: string? = nil
local running = false
local fallbacks = 0
local defaultImages: { [Instance]: string } = {} -- image de Clément de chaque Icon vu

-- Module frère chargé seulement s'il est là (bancs réduits).
local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok: boolean, result: any = pcall(require, module)
	return if ok then result else nil
end

local function screen(): ScreenGui?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild(Settings.Screen) else nil
	return if gui and gui:IsA("ScreenGui") then gui else nil
end

-- Texture du premier Decal livré parmi `names` (« A|B »), nil sinon.
local function iconTexture(names: string): string?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	for name in string.gmatch(names, "[^|]+") do
		local prefix = Icons.Prefix
		if string.sub(name, 1, #prefix) == prefix then
			local texture = Icons.get(string.sub(name, #prefix + 1))
			if texture then
				return texture
			end
		elseif assets then
			for _, descendant in assets:GetDescendants() do
				if descendant.Name == name and descendant:IsA("Decal") and descendant.Texture ~= "" then
					return descendant.Texture
				end
			end
		end
	end
	return nil
end

local function fallback(entry: Entry)
	fallbacks += 1
	local notify: any = sibling("NotifyController")
	local show: any = if notify then notify.Show else nil
	if show ~= nil then
		(show :: any)(entry.Plain, Settings.NotifyKind)
	end
end

-- Remplit l'écran ; faux s'il manque (repli).
local function fill(gui: ScreenGui, entry: Entry): boolean
	local message = Find.path(gui, "Banner.Message")
	if Find.path(gui, "Banner") == nil or message == nil or not message:IsA("TextLabel") then
		return false
	end
	message.Text = if message.RichText then entry.Message else entry.Plain
	local detail = Find.path(gui, "Banner.Detail")
	if detail and detail:IsA("TextLabel") then
		detail.Text = entry.Detail
	end
	local icon = Find.path(gui, "Banner.Icon")
	if icon and icon:IsA("ImageLabel") then
		if defaultImages[icon] == nil then
			defaultImages[icon] = icon.Image
		end
		icon.Image = (if entry.Icon ~= "" then iconTexture(entry.Icon) else nil) or defaultImages[icon]
	end
	return true
end

local function motion(): any
	local folder = script.Parent:FindFirstChild("UI")
	local module = if folder then folder:FindFirstChild("Motion") else nil
	if module and module:IsA("ModuleScript") then
		local ok: boolean, result: any = pcall(require, module)
		return if ok then result else nil
	end
	return nil
end

-- Motion.Open et Motion.Close (Banner entre et sort par son Appear) ; sans Motion : Enabled d'un coup.
local function setShown(gui: ScreenGui, on: boolean)
	local api = motion()
	local fn = if api then (if on then api.Open else api.Close) else nil
	if type(fn) == "function" then
		fn(gui)
	else
		gui.Enabled = on
	end
end

local function pump()
	if running then
		return
	end
	running = true
	while #queue > 0 do
		local entry = table.remove(queue, 1) :: Entry
		local gui = screen()
		if gui == nil or not fill(gui, entry) then
			fallback(entry)
		else
			shown = entry.Plain
			setShown(gui, true)
			task.wait(math.max(Settings.Hold, 0))
			shown = nil
			if gui.Parent ~= nil then
				setShown(gui, false)
			end
			task.wait(math.max(Settings.Gap, 0))
		end
	end
	running = false
end

function AnnounceController.Push(message: string, detail: string?, icon: string?, plain: string?)
	if type(message) ~= "string" or message == "" then
		return
	end
	table.insert(queue, {
		Message = message,
		Detail = if type(detail) == "string" then detail else "",
		Icon = if type(icon) == "string" then icon else "",
		Plain = if type(plain) == "string" and plain ~= "" then plain else (string.gsub(message, "<[^>]*>", "")),
	})
	while #queue > math.max(Settings.MaxQueue, 1) do
		table.remove(queue, 1)
	end
	task.spawn(pump)
end

function AnnounceController.GetState(): { Shown: string?, Queue: number, Fallbacks: number }
	return { Shown = shown, Queue = #queue, Fallbacks = fallbacks }
end

function AnnounceController.Start()
	local Net = require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
	Net.Client.Announce:Connect(AnnounceController.Push)
end

return AnnounceController
