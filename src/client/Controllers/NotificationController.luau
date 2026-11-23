--!strict
-- NotificationController (MAJ 7, vague GC6, a410, client) : le côté joueur des notifications Roblox hors du jeu
-- (Config/Notifications ; envoi : NotificationService). Coupé par Features.ExperienceNotifications.
--   - consentement : après Notifications.PromptDelay s de jeu, une fois par session, si Roblox le permet
--     (ExperienceNotificationService:CanPromptOptInAsync), la fenêtre de Roblox s'ouvre (PromptOptIn ; texte fixe de
--     Roblox, aucune UI de Clément). Refuser ne change rien au jeu ;
--   - premier plan : la fenêtre du jeu quitte ou retrouve le premier plan (UserInputService.WindowFocusReleased,
--     WindowFocused) : remote ReportFocus(false / true), pour que le vol d'un objet de sa boutique lui soit signalé
--     hors du jeu.
-- API (client) : aucune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Notifications = require(Config:WaitForChild("Notifications"))

local IS_STUDIO = RunService:IsStudio()

local NotificationController = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[Notifications] {message}`)
	end
end

local function prompt()
	local ok, service = pcall(function(): any
		return game:GetService("ExperienceNotificationService" :: any)
	end)
	if not ok or service == nil then
		log("ExperienceNotificationService indisponible : pas de demande de consentement")
		return
	end
	local checked, can = pcall(function(): any
		return (service :: any):CanPromptOptInAsync()
	end)
	if not checked then
		log(`CanPromptOptInAsync : {can}`)
		return
	end
	if can ~= true then
		log("demande de consentement pas permise (déjà inscrit, moins de 13 ans ou déjà vue)")
		return
	end
	local shown, err = pcall(function()
		(service :: any):PromptOptIn()
	end)
	if not shown then
		log(`PromptOptIn : {err}`)
	end
end

function NotificationController.Start()
	if Features.ExperienceNotifications ~= true then
		return
	end
	task.spawn(function()
		local ok, net = pcall(function(): any
			return require(Shared:WaitForChild("Net"):WaitForChild("Net")) :: any
		end)
		if not ok then
			log(`Net introuvable : premier plan pas signalé ({net})`)
			return
		end
		local function report(focused: boolean)
			pcall(function()
				net.Client.ReportFocus:Fire(focused)
			end)
		end
		UserInputService.WindowFocusReleased:Connect(function()
			report(false)
		end)
		UserInputService.WindowFocused:Connect(function()
			report(true)
		end)
	end)
	task.delay(Notifications.PromptDelay, function()
		if Players.LocalPlayer.Parent == Players then
			prompt()
		end
	end)
end

return NotificationController
