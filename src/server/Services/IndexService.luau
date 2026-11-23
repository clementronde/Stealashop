--!strict
-- IndexService (DEV-111) : l'index des objets (Partie 2, section 3.4 ; avancé avant la MAJ 2, liaison
-- L-071 point 1). Règles communes au serveur et au client : Config/Index. Écran : IndexController.
--
-- Rôle :
--   - découverte : un objet du catalogue (Config/Items) est découvert la première fois que le joueur
--     le possède. Profil v4 (DataService, Types/Profile) : Index[ItemId] = os.time() de la
--     découverte, écrit une seule fois (une 2e copie ne change rien) et jamais retiré (objet volé,
--     remis à une renaissance : il reste découvert). Les points d'entrée d'un objet dans Items :
--       * l'objet sorti d'un colis sur place (rayon, camion, coffre) et ramené en zone safe, et l'objet
--         donné (UnboxService : stowItem et GiveItem appellent IndexService.Discover) ; vague 52 (a170) :
--         l'accroche UnboxService.OnBoxOpened (ouverture en base, retirée par a158) est retirée ;
--       * le vol à un autre joueur, au dépôt (PvPService.OnTheftEnded, résultat « Stolen ») ;
--       * filet, au chargement du profil : un objet possédé (Items : l'inventaire, les présentoirs et
--         le coffre-fort) qui manque à l'Index y est ajouté, sans message, à sa date d'obtention. La
--         migration v3 → v4 (DataService) fait déjà ce compte pour les profils existants ; le filet
--         rattrape un objet entré par un chemin qui n'appelle pas Discover.
--     Tout autre code qui ajoute un objet à Items (récompense, échange…) appelle IndexService.Discover.
--   - envoi au client : attribut Index.Attribute (« IndexDiscovered ») du Player, posé au chargement
--     puis à chaque découverte : les ItemId découverts, dans l'ordre du catalogue, séparés par des
--     virgules (Index.Encode). Rien n'est lu du client, sauf la réclamation (plus bas).
--   - récompense d'une zone complète (tous ses objets ; les Secrets n'appartiennent à aucune zone).
--     Vague 61 (a201, décision de Clément du 2026-11-15, L-192, qui remplace celle de la vague 59, L-183) :
--     UN OBJET SEULEMENT, Index.ZoneRewards[zone].Item, une seule fois par zone et par joueur, QUAND IL LA
--     RÉCLAME (L-127 point 2) : une arme (ToolService.Grant) ou une aura ou un trail (CosmeticService.Grant),
--     ajouté aux possédés sans être équipé ; déjà possédé : rien de plus. Ni argent, ni Vitesse, ni diamants
--     (la prime et la Vitesse d'a191 sont retirées). Les anciens bonus en pour cent (+5 % de revenus et +3 %
--     de vitesse par zone complète) n'existent plus non plus. Choix le plus sûr : rien n'est versé deux fois
--     et rien de ce qui est dans le profil n'est repris (argent ou Vitesse déjà versés par a191 : gardés).
--     Une zone déjà réclamée avant (entrée dans IndexRewards, rien dans IndexGifts) reçoit au chargement
--     suivant l'objet seulement, une fois.
--     Remote ClaimIndexReward(zone) depuis le bouton de réclamation de l'écran (la zone affichée), ou
--     ClaimIndexReward() sans zone (UnlockedBar.ClaimAllButton de la v3 : toutes les zones complètes pas
--     encore réclamées, en une demande). Le serveur revérifie tout d'après le profil (index ouvert, zone
--     complète, pas déjà réclamée). Profil : IndexRewards[« zone »] = os.time() de la réclamation et
--     IndexGifts[« zone »] = os.time() du don de l'objet, notés avant le don
--     (jamais deux fois, même pour deux demandes d'affilée : sans yield). Rien à réclamer : rien ne change
--     (l'attribut est reposé pour remettre le client d'accord). Attribut Index.ClaimedAttribute
--     (« IndexClaimed ») du Player : les zones réclamées, « 1,3 » (Index.EncodeZones), posé au chargement et
--     à chaque réclamation ; le client en tire les pastilles « ! ».
--     Notify (MESSAGES.ZoneComplete, « Info ») au moment où la zone se complète : la récompense attend
--     d'être réclamée.
-- Features.Index à false (MAJ 2 pas ouverte) : les découvertes sont notées et l'attribut posé quand
-- même (rien n'est perdu à l'ouverture), mais ni récompense (réclamation refusée, rien donné au
-- chargement), ni message.
--
-- API (côté serveur) :
--   IndexService.Discover(player, itemId) -> boolean
--       Note l'objet comme découvert ; true s'il ne l'était pas. false : déjà découvert, ItemId inconnu
--       du catalogue ou profil pas chargé. Sans yield.
--   IndexService.IsDiscovered(player, itemId) -> boolean
--   IndexService.GetCompletedZones(player) -> { number }   zones complètes, dans l'ordre
--   IndexService.GetClaimableZones(player) -> { number }   zones complètes dont la récompense attend
--   IndexService.Claim(player, zone?) -> number
--       Ce que fait le remote ClaimIndexReward : réclame la récompense de `zone` (nil = toutes les zones
--       complètes pas encore réclamées) ; renvoie le nombre de récompenses versées (0 : refus). Sans yield.

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
local PvPService = require(script.Parent.PvPService)

type Data = ProfileTypes.Data

local IS_STUDIO = RunService:IsStudio()

-- Messages lus par le joueur (Notify), en anglais (L-036). V0 proposé, absent du doc : %d = numéro de
-- la zone (celui des arches, « ZONE 3 »), %s = la récompense à réclamer (Index.ZoneRewardText).
local MESSAGES = {
	ZoneComplete = "Zone %d complete! Claim %s in the Index!",
}
-- Catégorie de ce Notify : une bonne nouvelle, rien n'est refusé.
local NOTIFY_KIND = "Info"
-- Résultat d'OnTheftEnded quand l'objet est déposé chez le voleur (PvPService.TheftResult).
local STOLEN = "Stolen"

local IndexService = {}

local enabled = false

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

-- Attribut du joueur, d'après son Index.
local function publish(player: Player, index: { [string]: number })
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

-- Un carnet du profil (IndexRewards, IndexGifts) : la table (nil = aucune entrée encore), et false si le
-- champ est illisible (profil abîmé : on ne sait plus ce qui est versé ; repartir vide paierait deux fois).
local function bookOf(player: Player, data: Data, field: string): ({ [string]: number }?, boolean)
	local book: any = (data :: any)[field]
	if book ~= nil and type(book) ~= "table" then
		warn(`[IndexService] {player.Name} : {field} illisible ({typeof(book)}), rien n'est versé`)
		return nil, false
	end
	return book, true
end

-- Le carnet `field`, créé vide s'il manque (à n'appeler qu'après bookOf lisible).
local function ensureBook(data: Data, field: string): { [string]: number }
	local book: any = (data :: any)[field]
	if type(book) ~= "table" then
		book = {}
		;(data :: any)[field] = book
	end
	return book
end

-- Attribut IndexClaimed : les zones réclamées. Champ illisible : toutes les zones complètes comptent
-- comme réclamées (rien n'est montré à réclamer, puisque rien ne serait versé).
local function publishClaimed(player: Player, data: Data)
	local paid, readable = bookOf(player, data, "IndexRewards")
	local text: string
	if readable then
		text = Index.EncodeZones(paid or {})
	else
		local all: { [number]: boolean } = {}
		for _, zone in Index.CompletedZones(indexOf(player, data)) do
			all[zone] = true
		end
		text = Index.EncodeZones(all)
	end
	player:SetAttribute(Index.ClaimedAttribute, text)
end

-- L'objet de la récompense : arme (ToolService) ou aura et trail (CosmeticService), requis ici seulement
-- (ils ne servent qu'au don). Une erreur n'arrête pas la réclamation : avertissement, objet pas donné.
local function grantItem(player: Player, kind: string, id: string): boolean
	local ok, result = pcall(function(): any
		if kind == "Weapon" then
			return (require(script.Parent.ToolService) :: any).Grant(player, id)
		end
		return (require(script.Parent.CosmeticService) :: any).Grant(player, id)
	end)
	if not ok or result ~= true then
		warn(`[IndexService] {player.Name} : {kind} {id} pas donné ({if ok then tostring(result) else result})`)
		return false
	end
	return true
end

-- L'objet de la zone `zone`, noté dans IndexGifts avant le don. Sans yield.
local function giveGifts(player: Player, data: Data, zone: number)
	local reward = Index.ZoneReward(zone)
	if reward == nil then
		return
	end
	ensureBook(data, "IndexGifts")[tostring(zone)] = os.time()
	grantItem(player, reward.Item.Kind, reward.Item.Id)
	log(`{player.Name} : zone {zone}, {reward.Item.Kind} {reward.Item.Id} donné`)
end

-- Zone `zone` complétée : message (la récompense attend d'être réclamée). Sans yield.
local function announce(player: Player, zone: number)
	if DataService.Get(player) == nil or not enabled then
		return
	end
	notify(player, string.format(MESSAGES.ZoneComplete, zone, Index.ZoneRewardText(zone)))
end

-- Réclamation (remote ClaimIndexReward) : la récompense de `wanted`, ou de toutes les zones complètes pas
-- encore réclamées si `wanted` est nil ; chacune notée avant le don, une seule fois. Renvoie le nombre de
-- récompenses versées. Sans yield. Rien si l'index est fermé ou le profil pas chargé.
local function claim(player: Player, wanted: number?): number
	local data = DataService.Get(player)
	if data == nil or not enabled then
		return 0
	end
	local paid, readable = bookOf(player, data, "IndexRewards")
	local gifts, giftsReadable = bookOf(player, data, "IndexGifts")
	if not readable or not giftsReadable then
		publishClaimed(player, data)
		return 0
	end
	local count = 0
	for _, zone in Index.CompletedZones(indexOf(player, data)) do
		local key = tostring(zone)
		if (wanted == nil or wanted == zone) and (paid == nil or paid[key] == nil) then
			-- Noté avant le don : jamais deux fois, même si la suite échoue.
			ensureBook(data, "IndexRewards")[key] = os.time()
			paid = data.IndexRewards
			count += 1
			if gifts == nil or gifts[key] == nil then
				giveGifts(player, data, zone)
				gifts = data.IndexGifts
			end
			log(`{player.Name} : récompense de la zone {zone} réclamée`)
		end
	end
	if count == 0 then
		log(`{player.Name} : rien à réclamer ({if wanted then `zone {wanted}` else "toutes"})`)
	end
	publishClaimed(player, data)
	return count
end

-- Chargement : une zone réclamée avant (entrée dans IndexRewards, rien dans IndexGifts) reçoit l'objet de
-- la récompense, une fois, rien d'autre.
local function catchUpGifts(player: Player, data: Data)
	local paid, readable = bookOf(player, data, "IndexRewards")
	local gifts, giftsReadable = bookOf(player, data, "IndexGifts")
	if not readable or not giftsReadable or paid == nil then
		return
	end
	for zone = 1, Index.ZoneCount do
		local key = tostring(zone)
		if paid[key] ~= nil and (gifts == nil or gifts[key] == nil) then
			giveGifts(player, data, zone)
			gifts = data.IndexGifts
		end
	end
end

local function onClaimIndexReward(player: Player, zone: number?)
	if zone ~= nil and (type(zone) ~= "number" or zone ~= math.floor(zone) or zone < 1 or zone > Index.ZoneCount) then
		return -- zone hors de l'index (Net borne déjà le type)
	end
	claim(player, zone)
end

-- Note `itemId` comme découvert ; message de zone complète `delay` s plus tard (pour un colis : à la
-- révélation). La récompense attend d'être réclamée.
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
		local completedZone = zone :: number
		local wait = if type(delay) == "number" and delay == delay and delay > 0 then delay else 0
		if wait > 0 then
			-- Parti avant : rien de perdu, la récompense attend d'être réclamée.
			task.delay(wait, function()
				if player.Parent == Players then
					announce(player, completedZone)
				end
			end)
		else
			announce(player, completedZone)
		end
	end
	return true
end

-- Chargement du profil : filet (objets possédés absents de l'Index), puis attribut et zones réclamées.
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
	-- Zones réclamées (pastilles du client) ; les récompenses dues attendent d'être réclamées.
	publishClaimed(player, data)
	if enabled then
		-- Au tour suivant : le don attend que les services suivent le joueur (son PlayerAdded),
		-- qui peut passer après un profil chargé sans attente.
		task.defer(function()
			local loaded = DataService.Get(player)
			if loaded ~= nil and player.Parent == Players then
				catchUpGifts(player, loaded)
			end
		end)
	end
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

function IndexService.GetClaimableZones(player: Player): { number }
	local data = DataService.Get(player)
	if data == nil or not enabled then
		return {}
	end
	local paid, readable = bookOf(player, data, "IndexRewards")
	if not readable then
		return {}
	end
	return Index.ClaimableZones(indexOf(player, data), Index.DecodeZones(Index.EncodeZones(paid or {})))
end

function IndexService.Claim(player: Player, zone: number?): number
	return claim(player, zone)
end

function IndexService.Init()
	enabled = Features.Index == true
	Net.Server.ClaimIndexReward:Connect(onClaimIndexReward)
	if not enabled then
		print("[IndexService] Features.Index = false : découvertes notées, sans récompense ni message")
	end
	DataService.OnProfileLoaded(onProfileLoaded)
	PvPService.OnTheftEnded(onTheftEnded)
end

return IndexService
