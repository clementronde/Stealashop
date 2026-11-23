--!strict
-- CodeService (MAJ 0, docs/claude/notes/feuille-de-route-maj.md ; agent a162, vague 50) : codes cadeaux.
-- Le client envoie RedeemCode(code) (texte court, débit limité par Net) ; le serveur compare le code à
-- Config/Codes (insensible à la casse), vérifie la date de fin (os.time() UTC) et qu'il n'est pas déjà pris
-- par ce profil (Data.Codes, champ facultatif sans changement de version), donne la récompense et note le
-- code dans la même exécution, sans yield (un double envoi trouve le code déjà noté). Réponse : remote
-- CodeResult(status, message) au seul joueur (status = Redeemed, Invalid, AlreadyUsed, Expired, Unavailable),
-- plus un Notify. Refus propre du don (inventaire plein, potions au plafond…) : rien n'est noté.
--
-- Tester dans Studio : workspace:SetAttribute("CodeTest", "reset <joueur>") oublie ses codes pris.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Codes = require(Shared.Config.Codes)
local Items = require(Shared.Config.Items)
local Zones = require(Shared.Config.Zones)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local PotionService = require(script.Parent.PotionService)
local UnboxService = require(script.Parent.UnboxService)

type Data = ProfileTypes.Data
type CodeReward = Codes.CodeReward
export type Status = "Redeemed" | "Invalid" | "AlreadyUsed" | "Expired" | "Unavailable"

local MESSAGES: { [string]: string } = Codes.Messages :: any
local TEST_ATTRIBUTE = "CodeTest"

local CodeService = {}
-- Après MonetizationService (150) : rien ne dépend de l'ordre (appels en jeu seulement), V0.
CodeService.Priority = 225

local byCode: { [string]: Codes.GiftCode } = {}
for _, entry in Codes.List do
	byCode[Codes.Normalize(entry.Code)] = entry
end

-- Zone la plus haute des objets du joueur (comme RewardService) : zone 1 sans objet.
local function bestZone(data: Data): number
	local best = 1
	local items = (data :: any).Items
	if type(items) ~= "table" then
		return best
	end
	for _, entry in items do
		local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
		local zone = if def then def.Zone or entry.Zone else nil
		if type(zone) == "number" and Zones[zone] ~= nil and zone > best then
			best = zone
		end
	end
	return best
end

-- Donne la récompense ; true si c'est donné. Sans yield.
local function give(player: Player, data: Data, reward: CodeReward): boolean
	local kind = reward.Kind
	if kind == "Boost" then
		return MonetizationService.AddCashBoost(player, (reward.Minutes or 0) * 60)
	elseif kind == "Cash" then
		return DataService.AddCash(player, reward.Amount or 0) ~= nil
	elseif kind == "Potion" then
		return PotionService.AddStock(player, reward.PotionId or "", reward.Count or 1)
	elseif kind == "Item" then
		local zone = math.max(bestZone(data), reward.MinZone or 1)
		local itemUid = UnboxService.GiveItem(player, reward.Tier or "Standard", zone, reward.MinRarity)
		return itemUid ~= nil
	end
	return false
end

local function reply(player: Player, status: Status)
	local message = MESSAGES[status]
	pcall(function()
		Net.Server.CodeResult:Fire(player, status, message)
		Net.Server.Notify:Fire(player, message, if status == "Redeemed" then "Success" else "Warning")
	end)
end

-- Cœur de RedeemCode, renvoie le statut (pour les bancs).
function CodeService.Redeem(player: Player, text: string): Status
	local data = DataService.Get(player)
	if data == nil then
		return "Unavailable"
	end
	if type(text) ~= "string" or #text > Codes.MaxLength then
		return "Invalid"
	end
	local key = Codes.Normalize(text)
	local entry = byCode[key]
	if entry == nil then
		return "Invalid"
	end
	local used = data.Codes
	if used ~= nil and used[key] ~= nil then
		return "AlreadyUsed"
	end
	local endsAt = entry.EndsAt
	if endsAt ~= nil and os.time() >= endsAt then
		return "Expired"
	end
	local ok, given = pcall(give, player, data, entry.Reward)
	if not ok then
		warn(`[CodeService] {player.Name} : erreur pendant le don du code {key} ({given}) : noté quand même`)
	elseif not given then
		return "Unavailable"
	end
	-- a414 (vague GC7, Features.Analytics) : argent d'un code compté (genre Code, SKU = le code), juste après le don.
	local features = require(Shared.Config.Features) :: any
	if ok and features.Analytics == true and entry.Reward.Kind == "Cash" then
		local okRequire, telemetry = pcall(require, script.Parent:FindFirstChild("TelemetryService") :: any)
		if okRequire and type(telemetry) == "table" then
			pcall((telemetry :: any).LogEconomy, player, "Code", entry.Reward.Amount or 0, key)
		end
	end
	local list = data.Codes or {}
	list[key] = os.time()
	data.Codes = list
	return "Redeemed"
end

local function onRedeem(player: Player, text: string)
	reply(player, CodeService.Redeem(player, text))
end

local function onTestAttribute()
	local value = Workspace:GetAttribute(TEST_ATTRIBUTE)
	if value == nil then
		return
	end
	Workspace:SetAttribute(TEST_ATTRIBUTE, nil)
	local who = string.match(tostring(value), "^reset%s+(%S+)$")
	local player = if who then Players:FindFirstChild(who) else nil
	local data = if player and player:IsA("Player") then DataService.Get(player) else nil
	if data then
		data.Codes = nil
		print(`[CodeService] test : codes de {who} oubliés`)
	else
		warn(`[CodeService] test : « {tostring(value)} » : attendu « reset <joueur> » avec un joueur présent`)
	end
end

function CodeService.Init()
	Net.Server.RedeemCode:Connect(onRedeem)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(onTestAttribute)
	end
end

return CodeService
