--!strict
-- LiveFeaturesService (a442, 25/11 ; check-up a417 P5, condition de la décision C2 de Cantin du 24/11) : la commande
-- d'admin des interrupteurs à chaud, et une ligne d'état dans la sortie au démarrage. Logique et règles :
-- Shared/LiveFeatures (en-tête) ; réglages : Config/LiveFeatures. La source normale reste ConfigService (Creator Hub
-- > Configs) ; cette commande est le repli de secours, sur UN serveur, jusqu'à sa fermeture.
--
-- Commande de chat (TextChatCommand, alias Config/LiveFeatures.ChatAlias, « /feature ») :
--   /feature                     état : ConfigService, surcharges en vigueur, interrupteurs à chaud (Hot)
--   /feature <Nom> on|off        surcharge d'admin sur ce serveur (interrupteurs de Config/LiveFeatures.Hot seulement)
--   /feature <Nom> reset         retire la surcharge d'admin (retour à ConfigService, ou au fichier)
-- Qui : LiveFeatures.IsAdmin (Studio : tout le monde ; en ligne : Config/LiveFeatures.AdminUserIds). L'auteur est lu
-- par le serveur dans TextSource.UserId, jamais dans le texte ; un non-admin est refusé (une ligne dans la sortie,
-- aucun effet). Hors Studio, sans aucun UserId dans AdminUserIds, la commande n'est pas créée. Réponse au seul
-- admin par le remote Notify existant (aucun remote neuf). Aucun client ne peut changer un interrupteur autrement.
--
-- API (bancs) : LiveFeaturesService.Handle(player, text) -> (boolean, string)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared.Config.Features)
local Settings = require(Shared.Config.LiveFeatures)
local LiveFeatures = require(Shared.LiveFeatures)
local Net = require(Shared.Net.Net)

local COMMAND_NAME = "LiveFeaturesCommand"
local MAX_REPLY = 200 -- caractères montrés dans la notification (Notify)

local LiveFeaturesService = {}

local function statusText(): string
	local status = LiveFeatures.Status()
	if status == nil then
		return Settings.Messages.Off
	end
	local overrides = if #status.overrides > 0 then table.concat(status.overrides, ", ") else "none"
	return `Config: {status.config}. Overrides: {overrides}. Live: {table.concat(status.hot, ", ")}`
end

-- Nom d'interrupteur tel qu'écrit dans Config/Features (casse ignorée), ou nil.
local function flagNamed(word: string): string?
	if type(LiveFeatures.Get(word)) == "boolean" then
		return word
	end
	local wanted = string.lower(word)
	for name, value in Features :: any do
		if type(value) == "boolean" and string.lower(name) == wanted then
			return name
		end
	end
	return nil
end

local VALUES: { [string]: boolean } = { on = true, ["true"] = true, ["1"] = true, off = false, ["false"] = false, ["0"] = false }
local CLEAR: { [string]: boolean } = { reset = true, clear = true }

-- Une ligne de commande d'un joueur : refus d'un non-admin d'abord, puis l'état ou la surcharge.
function LiveFeaturesService.Handle(player: Player, text: string): (boolean, string)
	if not LiveFeatures.IsAdmin(player) then
		warn(`[LiveFeaturesService] refusé : {player.Name} ({player.UserId}) n'est pas admin des interrupteurs`)
		return false, Settings.Messages.NotAdmin
	end
	local words: { string } = {}
	for word in string.gmatch(if type(text) == "string" then string.sub(text, 1, 200) else "", "%S+") do
		table.insert(words, word)
	end
	local word = words[2]
	if word == nil then
		return true, statusText()
	end
	local name = flagNamed(word) or word
	local action = string.lower(words[3] or "")
	if CLEAR[action] then
		return LiveFeatures.SetAdmin(player, name, nil)
	end
	local value = VALUES[action]
	if value == nil then
		return false, Settings.Messages.BadValue
	end
	return LiveFeatures.SetAdmin(player, name, value)
end

local function reply(player: Player, ok: boolean, message: string)
	if player.Parent ~= Players then
		return
	end
	pcall(function()
		Net.Server.Notify:Fire(player, string.sub(message, 1, MAX_REPLY), if ok then "Info" else "Warning")
	end)
end

local function createCommand()
	local studio = RunService:IsStudio()
	if not (studio and Settings.StudioEveryone == true) and #Settings.AdminUserIds == 0 then
		print("[LiveFeaturesService] aucun admin des interrupteurs en ligne (Config/LiveFeatures.AdminUserIds vide) : commande pas créée")
		return
	end
	local ok, err = pcall(function()
		local TextChatService = game:GetService("TextChatService")
		local old = TextChatService:FindFirstChild(COMMAND_NAME)
		if old then
			old:Destroy()
		end
		local command = Instance.new("TextChatCommand")
		command.Name = COMMAND_NAME
		command.PrimaryAlias = Settings.ChatAlias
		pcall(function()
			(command :: any).AutocompleteVisible = false
		end)
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player == nil then
				return
			end
			local okRun, okResult, message = pcall(LiveFeaturesService.Handle, player, text)
			if not okRun then
				warn(`[LiveFeaturesService] erreur de la commande : {okResult}`)
				reply(player, false, "Server error.")
				return
			end
			reply(player, okResult == true, if type(message) == "string" then message else "")
		end)
		command.Parent = TextChatService
	end)
	if not ok then
		warn(`[LiveFeaturesService] commande {Settings.ChatAlias} pas créée : {err}`)
	end
end

function LiveFeaturesService.Init()
	if Settings.Enabled ~= true then
		return
	end
	createCommand()
end

function LiveFeaturesService.Start()
	if Settings.Enabled ~= true then
		print("[LiveFeaturesService] Config/LiveFeatures.Enabled = false : le fichier Config/Features seul")
		return
	end
	print(`[LiveFeaturesService] {statusText()}`)
end

return LiveFeaturesService
