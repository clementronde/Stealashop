--!strict
-- EventBannerController (client ; vague 51, a167, MAJ 0) : la bannière d'événement live UI_EventBanner de Clément
-- (facultative au contrat, Contract/UI ; noms proposés : Title, Timer, Effect). L'état vient des attributs du
-- Workspace posés par EventService (Config/LiveEvents : LiveEvent = Id du format, LiveEventEndsAt = fin, heure du
-- serveur) : rien n'est envoyé au serveur, rien n'est décidé ici.
--
-- Pendant un événement : écran allumé (Enabled), Title = DisplayName du format, Effect = son effet en une ligne,
-- Timer = temps restant (LiveEvents.FormatTimer : « 29:59 », « 1:05:00 »), refait chaque seconde. Hors événement
-- (ou Id inconnu du client) : écran éteint. Seuls Enabled et les trois textes sont touchés : ni taille, ni
-- position, ni style de Clément (la bannière est en bas ou au milieu de l'écran, jamais en haut).
--
-- API (client) :
--   EventBannerController.GetState() -> { Id: string?, Shown: boolean, Timer: string? }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveEvents = require(Shared:WaitForChild("Config"):WaitForChild("LiveEvents"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))

export type BannerState = {
	Id: string?,
	Shown: boolean,
	Timer: string?,
}

local SCREEN_NAME: string = LiveEvents.BannerScreen
local REFRESH = 1 -- s entre deux chronos

local EventBannerController = {}

local shownId: string? = nil
local timerText: string? = nil
local shown = false
local loop: thread? = nil

local function screen(): ScreenGui?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild(SCREEN_NAME) else nil
	return if gui and gui:IsA("ScreenGui") then gui else nil
end

local function setText(gui: Instance, path: string, text: string)
	local found = Find.path(gui, path)
	if found and found:IsA("TextLabel") then
		found.Text = text
	end
end

local function currentFormat(): LiveEvents.Format?
	local id = Workspace:GetAttribute(LiveEvents.IdAttribute)
	return if type(id) == "string" then LiveEvents.ById[id] else nil
end

local function remaining(): number
	local endsAt = Workspace:GetAttribute(LiveEvents.EndsAtAttribute)
	return if type(endsAt) == "number" then endsAt - Workspace:GetServerTimeNow() else 0
end

-- Écran à jour (allumé, textes) ; renvoie vrai tant qu'un événement tourne.
local function refresh(): boolean
	local format = currentFormat()
	local gui = screen()
	if format == nil then
		shownId, timerText, shown = nil, nil, false
		if gui then
			gui.Enabled = false
		end
		return false
	end
	shownId = format.Id
	timerText = LiveEvents.FormatTimer(remaining())
	shown = gui ~= nil
	if gui then
		setText(gui, "Title", format.DisplayName)
		setText(gui, "Effect", format.Effect)
		setText(gui, "Timer", timerText :: string)
		gui.Enabled = true
	end
	return true
end

local function onChanged()
	if not refresh() or loop ~= nil then
		return
	end
	loop = task.spawn(function()
		while refresh() do
			task.wait(REFRESH)
		end
		loop = nil
	end)
end

function EventBannerController.GetState(): BannerState
	return { Id = shownId, Shown = shown, Timer = timerText }
end

function EventBannerController.Start()
	Workspace:GetAttributeChangedSignal(LiveEvents.IdAttribute):Connect(onChanged)
	Workspace:GetAttributeChangedSignal(LiveEvents.EndsAtAttribute):Connect(onChanged)
	onChanged()
end

return EventBannerController
