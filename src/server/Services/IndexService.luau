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
--     multiplient).
--   - récompense en plus (Clément, 2026-11-10, liaison L-083 point 7, à la place de l'aura
--     « Collectionneur » de l'index complet) : chaque zone complète donne aussi
--       * une prime unique Index.ZoneCash(zone) (DataService.AddCash), une seule fois par zone et par
--         joueur, QUAND IL LA RÉCLAME (L-127 point 2, vague 34 : avant, elle était versée toute seule) :
--         remote ClaimIndexReward(zone) depuis Rewards.ClaimButton de UI_Index_v3 (la zone visible), ou
--         ClaimIndexReward() sans zone depuis UnlockedBar.ClaimAllButton (toutes les zones complètes pas
--         encore réclamées, en une demande). Le serveur revérifie tout d'après le profil (index ouvert,
--         zone complète, pas déjà réclamée) ; profil IndexRewards[« zone »] = os.time() de la
--         réclamation, noté avant le don (jamais deux fois, même pour deux demandes d'affilée : sans
--         yield) ; télémétrie LogEconomy « IndexReward », SKU IndexZone<n>. Les primes versées avant
--         (entrées déjà dans IndexRewards) restent versées. Rien à réclamer : rien ne change (l'attribut
--         est reposé pour remettre le client d'accord). Attribut Index.ClaimedAttribute
--         (« IndexClaimed ») du Player : les zones réclamées, « 1,3 » (Index.EncodeZones), posé au
--         chargement et à chaque réclamation ; le client en tire les pastilles « ! » ;
--       * +Index.ZoneSpeedBonus (+3 %) de WalkSpeed permanent par zone complète : modificateur
--         « Index » de StatsService (Index.SpeedMultiplier), donc connu de l'anti-triche, qui lit
--         Humanoid.WalkSpeed ; posé au chargement et à la complétion, gardé à la réapparition. Il ne
--         se réclame pas (comme les +5 % de revenus).
--     Notify (MESSAGES.ZoneComplete, « Info ») et vitesse au moment où la zone se complète ; pour un
--     colis, quand l'objet se révèle chez lui (le revealDelay d'OnBoxOpened), pas avant. Un joueur parti
--     pendant ce délai retrouve sa vitesse au chargement suivant, et sa prime attend d'être réclamée.
-- Features.Index à false (MAJ 2 pas ouverte) : les découvertes sont notées et l'attribut posé quand
-- même (rien n'est perdu à l'ouverture), mais ni bonus de revenus, ni prime (réclamation refusée), ni
-- vitesse, ni message.
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
--   IndexService.GetSpeedMultiplier(player) -> number
--       Multiplicateur de WalkSpeed de l'index appliqué (1,03 par zone complète, 1 sans) ; 1 si
--       Features.Index est coupé ou si le profil n'est pas chargé.
--   IndexService.GetClaimableZones(player) -> { number }   zones complètes dont la prime attend
--   IndexService.Claim(player, zone?) -> number
--       Ce que fait le remote ClaimIndexReward : réclame la prime de `zone` (nil = toutes les zones
--       complètes pas encore réclamées) ; renvoie le nombre de primes versées (0 : refus). Sans yield.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local Format = require(Shared.Format)
local Index = require(Shared.Config.Index)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local PvPService = require(script.Parent.PvPService)
local StatsService = require(script.Parent.StatsService)
local TelemetryService = require(script.Parent.TelemetryService)
local UnboxService = require(script.Parent.UnboxService)

type Data = ProfileTypes.Data

local IS_STUDIO = RunService:IsStudio()

-- Messages lus par le joueur (Notify), en anglais (L-036). V0 proposé, absent du doc : %d = numéro de
-- la zone (celui des arches, « ZONE 3 »), vitesse et revenus en pour cent, puis la prime à réclamer
-- (Format.money ; L-127 point 2 : elle n'est plus versée toute seule).
local MESSAGES = {
	ZoneComplete = "Index: Zone %d complete! +%d%% speed and +%d%% income forever. Claim your %s in the Index!",
}
-- Clé du modificateur de vitesse de l'index dans StatsService.
local SPEED_KEY = "Index"
-- Genre de télémétrie de la prime (Config/Telemetry) ; SKU = SKU_PREFIX .. zone.
local TELEMETRY_KIND = "IndexReward"
local SKU_PREFIX = "IndexZone"
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

-- Vitesse de l'index (modificateur « Index » de StatsService), d'après les zones complètes. Retiré
-- quand il vaut 1 (aucune zone) ou que l'index est fermé.
local function applySpeed(player: Player, index: { [string]: number })
	local multiplier = if enabled then Index.SpeedMultiplier(index) else 1
	StatsService.SetSpeedModifier(player, SPEED_KEY, if multiplier > 1 then multiplier else nil)
end

-- Primes réclamées du profil (IndexRewards) : la table (nil = aucune encore), et false si le champ est
-- illisible (profil abîmé : on ne sait plus lesquelles sont versées ; repartir vide paierait deux fois).
local function claimedOf(player: Player, data: Data): ({ [string]: number }?, boolean)
	local paid: any = data.IndexRewards
	if paid ~= nil and type(paid) ~= "table" then
		warn(`[IndexService] {player.Name} : IndexRewards illisible ({typeof(paid)}), aucune prime versée`)
		return nil, false
	end
	return paid, true
end

-- Attribut IndexClaimed : les zones réclamées. Champ illisible : toutes les zones complètes comptent
-- comme réclamées (rien n'est montré à réclamer, puisque rien ne serait versé).
local function publishClaimed(player: Player, data: Data)
	local paid, readable = claimedOf(player, data)
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

-- Zone `zone` complétée : message (la prime attend d'être réclamée) et vitesse. Sans yield.
local function announce(player: Player, zone: number)
	local data = DataService.Get(player)
	if data == nil or not enabled then
		return
	end
	applySpeed(player, indexOf(player, data))
	notify(
		player,
		string.format(
			MESSAGES.ZoneComplete,
			zone,
			math.round(Index.ZoneSpeedBonus * 100),
			math.round(Index.ZoneBonus * 100),
			Format.money(Index.ZoneCash(zone))
		)
	)
end

-- Réclamation (remote ClaimIndexReward) : la prime de `wanted`, ou de toutes les zones complètes pas
-- encore réclamées si `wanted` est nil ; chacune notée avant le don, une seule fois. Renvoie le nombre de
-- primes versées. Sans yield. Rien si l'index est fermé ou le profil pas chargé.
local function claim(player: Player, wanted: number?): number
	local data = DataService.Get(player)
	if data == nil or not enabled then
		return 0
	end
	local paid, readable = claimedOf(player, data)
	if not readable then
		publishClaimed(player, data)
		return 0
	end
	local count = 0
	for _, zone in Index.CompletedZones(indexOf(player, data)) do
		local key = tostring(zone)
		if (wanted == nil or wanted == zone) and (paid == nil or paid[key] == nil) then
			local book: { [string]: number } = paid or {}
			if paid == nil then
				paid = book
				data.IndexRewards = book
			end
			-- Noté avant le don : jamais deux fois, même si la suite échoue.
			book[key] = os.time()
			count += 1
			local cash = Index.ZoneCash(zone)
			if cash > 0 and DataService.AddCash(player, cash) ~= nil then
				-- Télémétrie juste après AddCash, sans yield (le solde est lu à l'appel).
				TelemetryService.LogEconomy(player, TELEMETRY_KIND, cash, `{SKU_PREFIX}{zone}`)
			end
			log(`{player.Name} : prime de la zone {zone} réclamée, {cash} $ versés`)
		end
	end
	if count == 0 then
		log(`{player.Name} : rien à réclamer ({if wanted then `zone {wanted}` else "toutes"})`)
	end
	publishClaimed(player, data)
	return count
end

local function onClaimIndexReward(player: Player, zone: number?)
	if zone ~= nil and (type(zone) ~= "number" or zone ~= math.floor(zone) or zone < 1 or zone > Index.ZoneCount) then
		return -- zone hors de l'index (Net borne déjà le type)
	end
	claim(player, zone)
end

-- Note `itemId` comme découvert ; vitesse et message de zone complète `delay` s plus tard (pour un
-- colis : à la révélation). La prime attend d'être réclamée.
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
			-- Parti avant : rien de perdu, la vitesse revient au chargement suivant et la prime attend.
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
	-- Zones réclamées (pastilles du client) et vitesse ; les primes dues attendent d'être réclamées.
	publishClaimed(player, data)
	if enabled then
		applySpeed(player, index)
	end
	-- La vitesse encore une fois au tour suivant : StatsService n'accepte un modificateur qu'une fois
	-- le joueur suivi (son PlayerAdded), qui peut passer après un profil chargé sans attente.
	task.defer(function()
		local loaded = DataService.Get(player)
		if loaded ~= nil and player.Parent == Players then
			applySpeed(player, indexOf(player, loaded))
		end
	end)
end

local function onBoxOpened(player: Player, _boxUid: string, _itemUid: string, itemId: string, revealDelay: number?)
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

function IndexService.GetSpeedMultiplier(player: Player): number
	local data = DataService.Get(player)
	local index: any = if data then (data :: any).Index else nil
	if not enabled or type(index) ~= "table" then
		return 1
	end
	return Index.SpeedMultiplier(index)
end

function IndexService.GetClaimableZones(player: Player): { number }
	local data = DataService.Get(player)
	if data == nil or not enabled then
		return {}
	end
	local paid, readable = claimedOf(player, data)
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
	if enabled then
		-- Les bonus en pour cent s'additionnent (DisplayService : M global = (1 + bonus) × multiplicateurs).
		local baseBonus = DisplayService.GetIncomeBonus
		DisplayService.GetIncomeBonus = function(player: Player): number
			return baseBonus(player) + IndexService.GetIncomeBonus(player)
		end
	else
		print("[IndexService] Features.Index = false : découvertes notées, sans bonus de revenus, prime, vitesse ni message")
	end
	DataService.OnProfileLoaded(onProfileLoaded)
	UnboxService.OnBoxOpened(onBoxOpened)
	PvPService.OnTheftEnded(onTheftEnded)
	Players.PlayerRemoving:Connect(function(player: Player)
		bonusOf[player] = nil
	end)
end

return IndexService
