--!strict
-- IndexService (DEV-111) : l'index des objets (Partie 2, section 3.4 ; avancé avant la MAJ 2, liaison
-- L-071 point 1). Règles communes au serveur et au client : Config/Index. Écran : IndexController.
--
-- Rôle :
--   - découverte : un objet du catalogue (Config/Items) est découvert la première fois que le joueur
--     le possède. Profil v4 (DataService, Types/Profile) : Index[ItemId] = os.time() de la
--     découverte, écrit une seule fois (une 2e copie ne change rien) et jamais retiré (objet volé,
--     remis à une renaissance : il reste découvert). Les points d'entrée d'un objet dans Items :
--       * l'ouverture d'un colis PNJ (UnboxService.OnBoxOpened) : tous les colis passent par un
--         établi, ceux des magasins, le colis garanti du tuto (le Pot de nouilles), ceux du camion
--         et ceux ramassés au sol ;
--       * le vol à un autre joueur, au dépôt (PvPService.OnTheftEnded, résultat « Stolen ») ;
--       * filet, au chargement du profil : un objet possédé (Items : l'inventaire, les présentoirs et
--         le coffre-fort) qui manque à l'Index y est ajouté, sans message, à sa date d'obtention. La
--         migration v3 → v4 (DataService) fait déjà ce compte pour les profils existants ; le filet
--         rattrape un objet entré par un chemin qui n'appelle pas Discover.
--     Tout autre code qui ajoute un objet à Items (récompense, échange…) appelle IndexService.Discover.
--   - envoi au client : attribut Index.Attribute (« IndexDiscovered ») du Player, posé au chargement
--     puis à chaque découverte : les ItemId découverts, dans l'ordre du catalogue, séparés par des
--     virgules (Index.Encode). Rien n'est lu du client : aucun remote.
--   - récompense (doc 3.4) : chaque zone complète (tous ses objets ; les Secrets n'appartiennent à
--     aucune zone) donne Index.ZoneBonus (+5 %) de revenus permanents, compté d'après l'Index
--     sauvegardé. Bonus en pour cent : il s'additionne aux autres (Roblox Premium…) par l'accroche
--     DisplayService.GetIncomeBonus (Partie 2, section 4 : les % s'additionnent, les ×2 se
--     multiplient). La zone qui se complète envoie un Notify au joueur (MESSAGES.ZoneComplete,
--     « Info ») ; pour un colis, au moment où l'objet se révèle chez lui (le revealDelay
--     d'OnBoxOpened), pas avant. Index complet = aura « Collectionneur » (doc 3.4) : elle n'existe pas
--     encore (liaison, pour Clément), rien n'est donné.
-- Features.Index à false (MAJ 2 pas ouverte) : les découvertes sont notées et l'attribut posé quand
-- même (rien n'est perdu à l'ouverture), mais ni bonus de revenus ni message.
--
-- API (côté serveur) :
--   IndexService.Discover(player, itemId) -> boolean
--       Note l'objet comme découvert ; true s'il ne l'était pas. false : déjà découvert, ItemId inconnu
--       du catalogue ou profil pas chargé. Sans yield.
--   IndexService.IsDiscovered(player, itemId) -> boolean
--   IndexService.GetCompletedZones(player) -> { number }   zones complètes, dans l'ordre
--   IndexService.GetIncomeBonus(player) -> number
--       Bonus de revenus de l'index appliqué, en fraction (0,05 par zone complète) ; 0 si
--       Features.Index est coupé ou si le profil n'est pas chargé.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local Index = require(Shared.Config.Index)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local PvPService = require(script.Parent.PvPService)
local UnboxService = require(script.Parent.UnboxService)

type Data = ProfileTypes.Data

local IS_STUDIO = RunService:IsStudio()

-- Messages lus par le joueur (Notify), en anglais (L-036). V0 proposé, absent du doc : %d = numéro de
-- la zone (celui des arches, « ZONE 3 »), puis le bonus en pour cent.
local MESSAGES = {
	ZoneComplete = "Index: Zone %d complete! +%d%% income forever.",
}
-- Catégorie de ce Notify : une bonne nouvelle, rien n'est refusé.
local NOTIFY_KIND = "Info"
-- Résultat d'OnTheftEnded quand l'objet est déposé chez le voleur (PvPService.TheftResult).
local STOLEN = "Stolen"

local IndexService = {}

local enabled = false
-- Bonus de revenus de l'index de chaque joueur présent (fraction), recalculé à chaque changement.
local bonusOf: { [Player]: number } = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[IndexService] {message}`)
	end
end

local function notify(player: Player, message: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, NOTIFY_KIND)
	end)
	if not ok then
		warn(`[IndexService] Notify vers {player.Name} : {err}`)
	end
end

-- Index du profil (v4). Un Index illisible (profil abîmé) repart vide, avec un avertissement.
local function indexOf(player: Player, data: Data): { [string]: number }
	local index: any = (data :: any).Index
	if type(index) ~= "table" then
		warn(`[IndexService] {player.Name} : Index du profil illisible ({typeof(index)}), repart vide`)
		index = {}
		data.Index = index
	end
	return index
end

-- Bonus et attribut du joueur, d'après son Index.
local function publish(player: Player, index: { [string]: number })
	bonusOf[player] = Index.IncomeBonus(index)
	player:SetAttribute(Index.Attribute, Index.Encode(index))
end

local function zonesText(index: { [string]: number }): string
	local zones: { string } = {}
	for _, zone in Index.CompletedZones(index) do
		table.insert(zones, tostring(zone))
	end
	return if #zones > 0 then table.concat(zones, ", ") else "aucune"
end

-- Date de découverte d'un objet déjà possédé : sa date d'obtention si elle est lisible, sinon `now`.
local function obtainedAt(entry: any, now: number): number
	local at = if type(entry) == "table" then entry.At else nil
	if type(at) == "number" and at == at and at > 0 then
		return at
	end
	return now
end

-- Note `itemId` comme découvert ; message de zone complète `delay` s plus tard (pour un colis : à la
-- révélation).
local function discover(player: Player, itemId: string, delay: number?): boolean
	local data = DataService.Get(player)
	local item = Items.ById[itemId]
	if data == nil or item == nil then
		return false
	end
	local index = indexOf(player, data)
	if index[itemId] ~= nil then
		return false
	end
	index[itemId] = os.time()
	publish(player, index)
	local zone = item.Zone
	local completed = zone ~= nil and Index.IsZoneComplete(index, zone)
	log(`{player.Name} : {itemId} découvert ({Index.CountAll(index)} / {Index.Total}){if completed then `, zone {zone} complète` else ""}`)
	if completed and enabled then
		local message = string.format(MESSAGES.ZoneComplete, zone :: number, math.round(Index.ZoneBonus * 100))
		local wait = if type(delay) == "number" and delay == delay and delay > 0 then delay else 0
		if wait > 0 then
			task.delay(wait, function()
				if player.Parent == Players then
					notify(player, message)
				end
			end)
		else
			notify(player, message)
		end
	end
	return true
end

-- Chargement du profil : filet (objets possédés absents de l'Index), puis bonus et attribut.
local function onProfileLoaded(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local index = indexOf(player, data)
	local now = os.time()
	local added = 0
	for _, entry in data.Items :: { [string]: any } do
		local itemId = if type(entry) == "table" then entry.Id else nil
		if type(itemId) == "string" and Items.ById[itemId] ~= nil and index[itemId] == nil then
			index[itemId] = obtainedAt(entry, now)
			added += 1
		end
	end
	publish(player, index)
	local extra = if added > 0 then `, dont {added} objet(s) possédé(s) ajouté(s) au chargement` else ""
	log(`{player.Name} : {Index.CountAll(index)} / {Index.Total} objet(s) découvert(s){extra} ; zone(s) complète(s) : {zonesText(index)}`)
end

local function onBoxOpened(player: Player, _benchIndex: number, _itemUid: string, itemId: string, revealDelay: number?)
	discover(player, itemId, revealDelay)
end

local function onTheftEnded(thief: Player, _victim: Player, itemId: string, result: string, _reason: string)
	if result == STOLEN then
		discover(thief, itemId, nil)
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function IndexService.Discover(player: Player, itemId: string): boolean
	if type(itemId) ~= "string" then
		return false
	end
	return discover(player, itemId, nil)
end

function IndexService.IsDiscovered(player: Player, itemId: string): boolean
	local data = DataService.Get(player)
	local index: any = if data then (data :: any).Index else nil
	return type(index) == "table" and index[itemId] ~= nil
end

function IndexService.GetCompletedZones(player: Player): { number }
	local data = DataService.Get(player)
	local index: any = if data then (data :: any).Index else nil
	if type(index) ~= "table" then
		return {}
	end
	return Index.CompletedZones(index)
end

function IndexService.GetIncomeBonus(player: Player): number
	if not enabled or DataService.Get(player) == nil then
		return 0
	end
	return bonusOf[player] or 0
end

function IndexService.Init()
	enabled = Features.Index == true
	if enabled then
		-- Les bonus en pour cent s'additionnent (DisplayService : M global = (1 + bonus) × multiplicateurs).
		local baseBonus = DisplayService.GetIncomeBonus
		DisplayService.GetIncomeBonus = function(player: Player): number
			return baseBonus(player) + IndexService.GetIncomeBonus(player)
		end
	else
		print("[IndexService] Features.Index = false : découvertes notées, sans bonus de revenus ni message")
	end
	DataService.OnProfileLoaded(onProfileLoaded)
	UnboxService.OnBoxOpened(onBoxOpened)
	PvPService.OnTheftEnded(onTheftEnded)
	Players.PlayerRemoving:Connect(function(player: Player)
		bonusOf[player] = nil
	end)
end

return IndexService
