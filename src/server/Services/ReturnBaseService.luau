--!strict
-- ReturnBaseService (DEV-045) : le bouton Retour base (Partie 1, sections 6.2 et 9.4 ;
-- Balance.ReturnToBase ; interrupteur : Config/Features.ReturnToBase).
--
-- Remote ReturnToBase (client → serveur, sans argument ; débit limité par Net). Le serveur vérifie,
-- dans cet ordre, et refuse avec un Notify en anglais (L-036) :
--   - la fonction est active (Features.ReturnToBase), sinon refus muet ;
--   - un seul retour à la fois par joueur (TeleportHome attend le chargement de la zone chez le
--     client, 2 s au plus) ;
--   - mains vides (6.2 : « interdit en portant quelque chose ») : refus si CarryService.IsCarrying,
--     sauf si Balance.ReturnToBase.AllowedWhileCarrying ;
--   - recharge : Balance.ReturnToBase.Cooldown (90 s) depuis le dernier retour réussi, Notify avec le
--     temps restant ;
--   - le joueur a une parcelle (plus de joueurs que de parcelles : il n'en a pas).
-- Puis PlotService.TeleportHome(player, canMove) : les mains vides sont revérifiées juste avant le
-- déplacement (un colis pris pendant l'attente annule le retour, sans recharge). Le retour est
-- gratuit (6.2). La recharge ne démarre qu'après un retour réussi. Elle suit le compte (UserId) :
-- quitter et revenir sur le même serveur ne la remet pas à zéro.
--
-- Posé par ce service, lu par HudController (aucun autre remote) : attribut du Player
-- ReturnBaseReadyAt = heure serveur (workspace:GetServerTimeNow()) à laquelle le bouton est de
-- nouveau prêt ; absent ou passé = prêt.
--
-- API (serveur) :
--   ReturnBaseService.GetCooldownLeft(player) -> number   secondes avant le prochain retour (0 = prêt)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Features = require(Shared.Config.Features)
local Net = require(Shared.Net.Net)

local PlotService = require(script.Parent.PlotService)

-- Ce que ce service utilise de CarryService (DEV-017).
type CarryApi = {
	IsCarrying: (player: Player) -> boolean,
}
local CarryService: CarryApi = require(script.Parent.CarryService) :: any

-- Posé ici, lu par HudController (même nom là-bas).
local READY_AT_ATTRIBUTE = "ReturnBaseReadyAt"

-- Messages lus par le joueur (Notify), en anglais (L-036).
local MESSAGES = {
	Carrying = "You can't return to base while carrying something.",
	Cooldown = "Return to base is ready in %ds.",
	NoShop = "You don't have a shop yet: wait for one to free up.",
}

local IS_STUDIO = RunService:IsStudio()

local ReturnBaseService = {}

local readyAt: { [number]: number } = {} -- UserId → os.clock() de la fin de la recharge
local busy: { [Player]: boolean } = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[ReturnBaseService] {message}`)
	end
end

local function notify(player: Player, message: string)
	if player.Parent ~= Players then
		return
	end
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, "Warning")
	end)
	if not ok then
		warn(`[ReturnBaseService] Notify vers {player.Name} : {err}`)
	end
end

local function isCarrying(player: Player): boolean
	local ok, carrying = pcall(CarryService.IsCarrying, player)
	return ok and carrying == true
end

local function handsAllowed(player: Player): boolean
	return Balance.ReturnToBase.AllowedWhileCarrying or not isCarrying(player)
end

function ReturnBaseService.GetCooldownLeft(player: Player): number
	local at = readyAt[player.UserId]
	return if at then math.max(at - os.clock(), 0) else 0
end

local function onReturnToBase(player: Player)
	if not Features.ReturnToBase then
		log(`ReturnToBase de {player.Name} ignoré : Features.ReturnToBase = false`)
		return
	end
	if busy[player] then
		return
	end
	if not handsAllowed(player) then
		notify(player, MESSAGES.Carrying)
		return
	end
	local left = ReturnBaseService.GetCooldownLeft(player)
	if left > 0 then
		notify(player, string.format(MESSAGES.Cooldown, math.ceil(left)))
		return
	end
	if PlotService.GetPlot(player) == nil then
		notify(player, MESSAGES.NoShop)
		return
	end

	busy[player] = true
	local ok, moved = pcall(PlotService.TeleportHome, player, function(): boolean
		return handsAllowed(player)
	end)
	busy[player] = nil
	if not ok then
		warn(`[ReturnBaseService] TeleportHome({player.Name}) : {moved}`)
		return
	end
	if not moved then
		if not handsAllowed(player) then
			notify(player, MESSAGES.Carrying) -- colis pris pendant l'attente
		end
		log(`retour base de {player.Name} annulé (personnage, parcelle ou colis)`)
		return
	end
	local cooldown = Balance.ReturnToBase.Cooldown
	readyAt[player.UserId] = os.clock() + cooldown
	if player.Parent == Players then
		player:SetAttribute(READY_AT_ATTRIBUTE, Workspace:GetServerTimeNow() + cooldown)
	end
	log(`{player.Name} rentré à sa base ; prochain retour dans {cooldown} s`)
end

function ReturnBaseService.Init()
	Net.Server.ReturnToBase:Connect(onReturnToBase)
	-- Revenu sur ce serveur pendant sa recharge : le bouton la montre de nouveau.
	Players.PlayerAdded:Connect(function(player: Player)
		local left = ReturnBaseService.GetCooldownLeft(player)
		if left > 0 then
			player:SetAttribute(READY_AT_ATTRIBUTE, Workspace:GetServerTimeNow() + left)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		busy[player] = nil
	end)
end

return ReturnBaseService
