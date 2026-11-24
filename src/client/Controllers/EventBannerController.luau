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
-- a285 (21/11, L-240 point 3) : la chance du serveur en cours (attributs ServerLuck et ServerLuckEndsAt du Workspace,
-- MonetizationService) se montre dans la même bannière quand aucun événement live n'y est (l'événement passe
-- devant), seulement avec Monetization.ServerLuck.Enabled (SERVER_LUCK) : Title = « SERVER LUCK ×2 », Effect =
-- « Rarer boxes for everyone » (ServerLuck.Banner), Timer = temps restant. Un élément absent : son texte n'est pas
-- écrit, sans erreur ; écran absent : rien.
-- a425 (24/11, L-318 Q2) : le fourgon blindé de la casse du siècle (attributs du Workspace de Config/ArmoredVan,
-- StateAttribute « Soon » ou « Road » et EndsAtAttribute, posés par ArmoredVanService) passe après l'événement live et
-- avant la chance du serveur : Title et Effect de ArmoredVan.Banner[état], Timer = temps jusqu'au départ (Soon) ou
-- jusqu'à sa fuite (Road). Config/ArmoredVan absente (bancs) : rien de plus.
--
-- API (client) :
--   EventBannerController.GetState() -> { Id: string?, Shown: boolean, Timer: string? }
--       Id = Id du format live, ou « ServerLuck » pour la chance du serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveEvents = require(Shared:WaitForChild("Config"):WaitForChild("LiveEvents"))
local Monetization = require(Shared:WaitForChild("Config"):WaitForChild("Monetization"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))

export type BannerState = {
	Id: string?,
	Shown: boolean,
	Timer: string?,
}

type Content = { Id: string, Title: string, Effect: string, Remaining: number }

local SCREEN_NAME: string = LiveEvents.BannerScreen
local REFRESH = 1 -- s entre deux chronos
local LUCK = Monetization.ServerLuck
local LUCK_ID = "ServerLuck"
local VAN_ID = "ArmoredVan" -- a425

-- a425 : Config/ArmoredVan, protégée (absente d'un faux arbre de banc : pas de fourgon dans la bannière).
type VanBanner = { StateAttribute: string, EndsAtAttribute: string, Banner: { [string]: { Title: string, Effect: string } } }
local function loadVan(): VanBanner?
	local ok, value = pcall(function(): any
		local config = Shared:FindFirstChild("Config")
		if config == nil or config:FindFirstChild("ArmoredVan") == nil then
			return nil
		end
		return require(Shared:WaitForChild("Config"):WaitForChild("ArmoredVan")) :: any
	end)
	if ok and type(value) == "table" and type(value.Banner) == "table" and type(value.StateAttribute) == "string" then
		return value
	end
	return nil
end
local VAN: VanBanner? = loadVan()

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

local function untilAttribute(name: string): number
	local endsAt = Workspace:GetAttribute(name)
	return if type(endsAt) == "number" then endsAt - Workspace:GetServerTimeNow() else 0
end

-- « ×2 », « ×1.5 ».
local function factorLabel(factor: number): string
	return if factor == math.floor(factor) then string.format("×%d", factor) else string.format("×%.1f", factor)
end

-- Ce que la bannière montre : l'événement live, sinon la chance du serveur ; nil = rien.
local function currentContent(): Content?
	local id = Workspace:GetAttribute(LiveEvents.IdAttribute)
	local format = if type(id) == "string" then LiveEvents.ById[id] else nil
	if format then
		return { Id = format.Id, Title = format.DisplayName, Effect = format.Effect, Remaining = untilAttribute(LiveEvents.EndsAtAttribute) }
	end
	local van = VAN -- a425 : le fourgon blindé, annoncé ou en route
	if van then
		local state = Workspace:GetAttribute(van.StateAttribute)
		local text = if type(state) == "string" then van.Banner[state] else nil
		local left = untilAttribute(van.EndsAtAttribute)
		if text and left > 0 then
			return { Id = VAN_ID, Title = text.Title, Effect = text.Effect, Remaining = left }
		end
	end
	if not LUCK.Enabled then
		return nil
	end
	local factor = Workspace:GetAttribute(LUCK.Attribute)
	local left = untilAttribute(LUCK.EndsAtAttribute)
	if type(factor) ~= "number" or factor ~= factor or factor <= 1 or left <= 0 then
		return nil
	end
	return {
		Id = LUCK_ID,
		Title = string.format(LUCK.Banner.Title, factorLabel(factor)),
		Effect = LUCK.Banner.Effect,
		Remaining = left,
	}
end

-- Écran à jour (allumé, textes) ; renvoie vrai tant qu'il y a quelque chose à montrer.
local function refresh(): boolean
	local content = currentContent()
	local gui = screen()
	if content == nil then
		shownId, timerText, shown = nil, nil, false
		if gui then
			gui.Enabled = false
		end
		return false
	end
	shownId = content.Id
	timerText = LiveEvents.FormatTimer(content.Remaining)
	shown = gui ~= nil
	if gui then
		setText(gui, "Title", content.Title)
		setText(gui, "Effect", content.Effect)
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
	if VAN then
		Workspace:GetAttributeChangedSignal((VAN :: VanBanner).StateAttribute):Connect(onChanged)
		Workspace:GetAttributeChangedSignal((VAN :: VanBanner).EndsAtAttribute):Connect(onChanged)
	end
	if LUCK.Enabled then
		Workspace:GetAttributeChangedSignal(LUCK.Attribute):Connect(onChanged)
		Workspace:GetAttributeChangedSignal(LUCK.EndsAtAttribute):Connect(onChanged)
	end
	onChanged()
end

return EventBannerController
