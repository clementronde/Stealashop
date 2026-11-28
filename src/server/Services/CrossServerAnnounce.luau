--!strict
-- CrossServerAnnounce (a521, 28/11 ; liaison L-405, Clément 25/11 : « oui les plus grosses ») : les plus grosses
-- annonces d'objets ramenés partent aussi sur les autres serveurs du jeu (MessagingService). Derrière
-- Features.CrossServerAnnounce (ou CrossServerAnnounceDev dans le jeu DEV et TEST) ; réglages Config/SecuredCard.Cross.
--
--   Envoi : un objet ramené en zone safe (CarryService.OnCarryEnded, « Consumed », comme CelebrationService ; pas un
--   objet volé à un vrai joueur, qui a déjà l'annonce du vol) d'au moins Cross.MinIncome $/s (sinon
--   Config/Announce.ValueMinIncome ; valeur = CelebrationService.ValueOf, mutation et poids compris), ou un Secret
--   (Cross.Secret) : PublishAsync(Cross.Topic, { JobId, Player, ItemId, Mutation, Value, Weight }), au plus un envoi
--   toutes les Cross.Gap s. Le serveur d'origine garde ses annonces d'avant (CelebrationService).
--   Réception (SubscribeAsync) : un message d'un AUTRE serveur (JobId différent), revérifié (objet du catalogue, nombres
--   finis, nom coupé à MaxNameLength et sans balises) : bannière UI_Announce (Shared/Announce.send) à tous les joueurs,
--   Cross.Text et Cross.Detail ; au plus une toutes les Cross.ShowGap s (les autres sautent). La variante BigAnnounce
--   (objet en 3D) attend Clément : la bannière d'aujourd'hui sert.
-- MessagingService absent ou en erreur (Studio sans accès, bancs) : une ligne dans la sortie, rien d'autre.
--
-- API (serveur, bancs) :
--   CrossServerAnnounce.Message(data) -> (string?, string?)   texte en couleur et texte simple d'un message reçu (nil :
--                                                              refusé)
--   CrossServerAnnounce.Receive(data) -> boolean              montré à tous ?
--   CrossServerAnnounce.GetState() -> { Sent, Received, Shown }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Mutations = require(Config:WaitForChild("Mutations"))
local AnnounceSettings = require(Config:WaitForChild("Announce")) :: any
local Settings = require(Config:WaitForChild("SecuredCard")) :: any
local Announce = require(Shared:WaitForChild("Announce"))
local Format = require(Shared:WaitForChild("Format"))
local ItemWeight = require(Shared:WaitForChild("ItemWeight"))
local SecuredTier = require(Shared:WaitForChild("SecuredTier"))

local CarryService = require(script.Parent:WaitForChild("CarryService")) :: any
local CelebrationService = require(script.Parent:WaitForChild("CelebrationService")) :: any

local CONSUMED = "Consumed"
local BOT_VICTIM = 0 -- VictimUserId d'un objet volé au bot (PvPService)
local CROSS = Settings.Cross

local CrossServerAnnounce = {}

-- MessagingService, cherché à la demande (bancs dont le faux jeu ne l'a pas : une ligne, rien d'autre).
local function messaging(): any
	return game:GetService("MessagingService")
end

local counts = { Sent = 0, Received = 0, Shown = 0 }
local lastSentAt: number? = nil
local lastShownAt: number? = nil

local function finite(value: any): number?
	return if type(value) == "number" and value == value and value >= 0 and value < math.huge then value else nil
end

local function minIncome(): number
	return finite(CROSS.MinIncome) or finite(AnnounceSettings.ValueMinIncome) or math.huge
end

local function fill(template: string, values: { [string]: string }): string
	return (string.gsub(template, "{(%w+)}", function(key: string): string
		return values[key] or `\{{key}\}`
	end))
end

-- Nom d'un joueur d'un autre serveur : sans balises (le message est en RichText), coupé à MaxNameLength.
local function cleanName(value: any): string?
	if type(value) ~= "string" or value == "" or not utf8.len(value) then
		return nil
	end
	local text = string.gsub(value, "[<>&]", "")
	local length = utf8.len(text) or 0
	if length > CROSS.MaxNameLength then
		text = string.sub(text, 1, utf8.offset(text, CROSS.MaxNameLength + 1) :: number - 1)
	end
	return if text ~= "" then text else nil
end

function CrossServerAnnounce.Message(data: any): (string?, string?)
	if type(data) ~= "table" then
		return nil, nil
	end
	local item = if type(data.ItemId) == "string" then Items.ById[data.ItemId] else nil
	local rarity = if item then Rarities.ById[item.Rarity] else nil
	local name = cleanName(data.Player)
	local value = finite(data.Value)
	if item == nil or rarity == nil or name == nil or value == nil then
		return nil, nil
	end
	local mutation = if type(data.Mutation) == "string" then Mutations.Sanitize(data.Mutation) else nil
	local okName, named = pcall(function(): string
		return Mutations.ItemName(item.DisplayName, mutation)
	end)
	local weight = finite(data.Weight)
	local template = CROSS.Text
	if weight == nil then
		template = string.gsub(template, " %({weight}%)", "")
	end
	local values = {
		player = name,
		item = if okName and type(named) == "string" then named else item.DisplayName,
		a = if string.find(rarity.DisplayNameUpper, "^[AEIOU]") then "an" else "a",
		rarity = rarity.DisplayNameUpper,
		value = Format.money(value) .. "/s",
		weight = if weight then ItemWeight.Format(weight) else "",
	}
	local plain = fill(template, values)
	values.rarity = Announce.rarityText(rarity)
	return fill(template, values), plain
end

function CrossServerAnnounce.Receive(data: any): boolean
	counts.Received += 1
	if not SecuredTier.On("CrossServerAnnounce") then
		return false
	end
	local message, plain = CrossServerAnnounce.Message(data)
	if message == nil then
		return false
	end
	local now = os.clock()
	if lastShownAt ~= nil and now - (lastShownAt :: number) < CROSS.ShowGap then
		return false
	end
	lastShownAt = now
	Announce.send(message, CROSS.Detail, AnnounceSettings.ItemIconPrefix .. data.ItemId, plain)
	counts.Shown += 1
	return true
end

local function onEnded(player: Player, payload: any, result: string)
	if result ~= CONSUMED or type(payload) ~= "table" or not SecuredTier.On("CrossServerAnnounce") then
		return
	end
	if payload.Kind == "PlayerItem" and payload.VictimUserId ~= BOT_VICTIM then
		return -- objet volé à un vrai joueur : l'annonce du vol suffit
	end
	local item = if type(payload.ItemId) == "string" then Items.ById[payload.ItemId] else nil
	local value = finite(CelebrationService.ValueOf(payload))
	if item == nil or value == nil then
		return
	end
	if value < minIncome() and not (CROSS.Secret == true and item.Rarity == "Secret") then
		return
	end
	local now = os.clock()
	if lastSentAt ~= nil and now - (lastSentAt :: number) < CROSS.Gap then
		return
	end
	lastSentAt = now
	local data = {
		JobId = game.JobId,
		Player = player.DisplayName,
		ItemId = item.Id,
		Mutation = if type(payload.Mutation) == "string" then payload.Mutation else nil,
		Value = value,
		Weight = finite(payload.Weight),
	}
	task.spawn(function()
		local ok, err = pcall(function()
			messaging():PublishAsync(CROSS.Topic, data)
		end)
		if ok then
			counts.Sent += 1
		else
			warn(`[CrossServerAnnounce] envoi : {err}`)
		end
	end)
end

function CrossServerAnnounce.GetState(): { Sent: number, Received: number, Shown: number }
	return { Sent = counts.Sent, Received = counts.Received, Shown = counts.Shown }
end

function CrossServerAnnounce.Start()
	CarryService.OnCarryEnded(function(player: Player, payload: any, result: string)
		local ok, err = pcall(onEnded :: any, player, payload, result)
		if not ok then
			warn(`[CrossServerAnnounce] objet ramené : {err}`)
		end
	end)
	local ok, err = pcall(function()
		messaging():SubscribeAsync(CROSS.Topic, function(message: any)
			local data = if type(message) == "table" then message.Data else nil
			if type(data) ~= "table" or data.JobId == game.JobId then
				return -- son propre envoi : déjà annoncé ici
			end
			local shown, receiveErr = pcall(CrossServerAnnounce.Receive, data)
			if not shown then
				warn(`[CrossServerAnnounce] réception : {receiveErr}`)
			end
		end)
	end)
	if not ok then
		print(`[CrossServerAnnounce] MessagingService indisponible : pas d'annonce entre serveurs ({err})`)
	end
end

return CrossServerAnnounce
