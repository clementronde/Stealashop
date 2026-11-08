--!strict
-- TelemetryService (DEV-054) : télémétrie du jeu envoyée à AnalyticsService (Partie 1, sections 9.3,
-- 14.1 et 14.2 ; noms et réglages : Config/Telemetry). Le funnel d'onboarding reste dans
-- TutorialService (DEV-046), qui l'envoie lui-même et suit l'interrupteur de Config/Telemetry.
--
-- Interrupteur : Telemetry.Enabled = false → rien n'est branché ni envoyé (une ligne dans la sortie).
--
-- Économie : AnalyticsService:LogEconomyEvent(joueur, sens, Telemetry.Currency (« Cash »), montant,
-- solde après l'opération, type de transaction, SKU, champs). Sens (Enum.AnalyticsEconomyFlowType) et
-- type (Enum.AnalyticsEconomyTransactionType, ou un type à nous) : Telemetry.Economy[genre]. Le solde
-- est le Cash du profil lu juste après l'opération (DataService.Get), dans la même exécution. Champ 1
-- = « Kind - <genre> » pour tous les envois ; champ 2 = « Level - <n> » pour une amélioration.
--   Gain (Source) :
--     Income   revenus encaissés : DisplayService.OnCashOut (tapis de caisse, départ du joueur,
--              DisplayService.CashOut). Gameplay, SKU « Income ». Regroupés par joueur (plus bas).
--     Offline  part d'un encaissement qui vient des gains hors ligne (DEV-102) : OfflineService la
--              donne par l'accroche ClaimOfflineShare (plus bas) ; le reste part en Income. TimedReward,
--              SKU « Offline », regroupés comme Income.
--   Dépenses (Sink), ShopService.OnPurchase (achat payé et donné ; un achat refusé, ou rendu parce
--   que l'octroi a échoué, ne part pas), type Shop, SKU = Id du catalogue :
--     Tool     outil (« Wrench ») ;
--     Upgrade  amélioration (« Treadmill »), champ 2 = niveau atteint ;
--     Aura, Trail (« Spark », « Dust »).
--   Robux (argent acheté en Robux, MAJ 1) : appelé par MonetizationService (DEV-100, LogEconomy plus
--   bas ; packs d'argent et pack de départ, SKU = clé du produit), seulement quand Features.RobuxShop
--   est vrai.
--   Pas encore codés, genres déjà dans la config (points d'accroche : LogEconomy, plus bas) : Fence
--   (receleur, DEV-034), DailyReward et PlaytimeReward (récompenses, MAJ 1, L-057), Code (codes
--   cadeaux), Defense (défenses, MAJ 2). Une défense achetée par ShopService (OnPurchase avec kind
--   « Defense ») partirait aussi en DefenseBought.
--
-- Regroupement des revenus (limite de Roblox : 120 + 20 × joueurs requêtes par minute et par
-- serveur, 240 à 6 joueurs) : un joueur qui fait des allers-retours sur son tapis de caisse
-- encaisserait jusqu'à 10 fois par seconde (DisplayService le contrôle 10 fois par seconde). Les genres
-- Aggregate (Income) s'additionnent donc par joueur et par SKU : un envoi au plus toutes les
-- Telemetry.FlushInterval s (60), avec la somme des encaissements et le solde après le dernier. Le
-- cumul part plus tôt avant tout autre envoi d'économie du même joueur (l'ordre des soldes reste
-- juste), à l'encaissement automatique du départ, et au départ (DataService.OnProfileReleasing). Un
-- cumul ne porte pas de champ 2 ni 3. Les achats partent un par un : BuyItem est limité à 4 par
-- seconde et un profil ne peut faire que 76 achats (6 outils, 59 niveaux, 11 auras et trails).
--
-- Événements custom : AnalyticsService:LogCustomEvent(joueur, nom, 1, champs), noms dans
-- Telemetry.Events (clé → nom envoyé) :
--   TheftSuccess (PvPTheftSuccess)  le voleur dépose l'objet volé chez lui (PvPService.OnTheftEnded,
--       « Stolen ») ; joueur = le voleur ; champs : Rarity, Zone de l'objet (absent pour un Secret).
--   TheftFail (PvPTheftFail)  vol raté (« Returned » : l'objet revient à son présentoir) ; joueur = le
--       voleur ; champs : Reason (raison du portage : Bat, Died, Left, CharacterRemoved, VictimLeft,
--       NoRoom, Anomaly, Caught…), Rarity, Zone de l'objet.
--   BatBoxKnock (BatBoxKnockdown)  un coup de batte fait tomber le colis PNJ d'un porteur, hors zone
--       safe (BatService.OnHit, usage « Box ») ; joueur = le frappeur ; champs : Zone du colis,
--       Rarity, Source (Store : colis d'un magasin ; Truck : colis du camion, StoreId « Truck_<n> »).
--   GuardCatch  un vigile rattrape le porteur d'un colis PNJ (CarryService.OnCarryEnded, « Failed »
--       et raison « Caught », que GuardService donne de jour comme de nuit ; colis PNJ seulement : un
--       voleur d'objet attrapé la nuit part en TheftFail « Caught ») ; joueur = le porteur ; champs :
--       Zone du colis, Phase (Day, Warning ou Night : NightCycleService.GetPhase), Rarity. Un joueur
--       attrapé la nuit sans rien porter ne passe pas par CarryService : il est compté par
--       GuardService.OnCatch, avec la Zone du vigile, Phase Night et Rarity None.
--   DefenseBought  pas encore codé (défenses, MAJ 2) : point d'accroche LogEvent.
--
-- Noms et champs : texte sans virgule, guillemet ni apostrophe, droits ou typographiques (Roblox refuse
-- l'événement sinon, « Event field … is invalid », vu en Studio le 2026-11-07 pour le funnel). Au
-- démarrage, les noms de Config/Telemetry, les Id du catalogue (SKU) et les étapes du funnel
-- (Config/Tutorial) sont vérifiés : un avertissement par nom fautif. À l'envoi, ces caractères sont
-- retirés de tout ce que ce service envoie (noms, monnaie, types, SKU, champs) ; le funnel, envoyé
-- par TutorialService, ne l'est pas : seul l'avertissement du démarrage le protège.
--
-- Refus de Roblox : chaque appel à AnalyticsService est dans un pcall. En Studio (Roblox n'envoie rien
-- depuis Studio et peut y refuser un appel), chaque envoi écrit une ligne dans la sortie, avec la
-- raison du refus s'il y en a une ; hors de Studio, un refus avertit une fois par nom. Jamais
-- d'erreur, rien n'attend : le jeu ne dépend d'aucun envoi.
--
-- API (serveur), points d'accroche des gains, dépenses et événements à venir :
--   TelemetryService.LogEconomy(player, kind, amount, sku?, fields?) -> boolean
--       kind = clé de Telemetry.Economy ; amount > 0 ; sku : Id lisible (sinon le Sku du genre,
--       sinon kind) ; fields : jusqu'à 2 textes de plus (champs 2 et 3). À appeler juste après
--       DataService.AddCash ou SpendCash, sans yield entre les deux : le solde est lu à l'appel.
--       false si coupé, genre inconnu, montant invalide ou profil pas chargé. Un service que
--       TelemetryService écoute (ShopService, DisplayService…) ne l'appelle pas (require en boucle) :
--       il ajoute un événement On…, branché ici.
--   TelemetryService.LogEvent(player, key, fields?, value?) -> boolean
--       key = clé de Telemetry.Events ; fields : jusqu'à 3 textes ; value : nombre (1 par défaut).
-- Point d'accroche (OfflineService le remplace en gardant celui d'avant) :
--   TelemetryService.ClaimOfflineShare(player, amount) -> number
--       Appelé à chaque encaissement (amount $) : la part qui vient des gains hors ligne, retirée de ce
--       qu'il reste à compter (0 par défaut). Une erreur ou une valeur invalide compte pour 0. Sans yield.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Items = require(Shared.Config.Items)
local Telemetry = require(Shared.Config.Telemetry)
local Tools = require(Shared.Config.Tools)
local Tutorial = require(Shared.Config.Tutorial)
local Upgrades = require(Shared.Config.Upgrades)
local CarryTypes = require(Shared.Types.Carry)

local BatService = require(script.Parent.BatService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local GuardService = require(script.Parent.GuardService)
local NightCycleService = require(script.Parent.NightCycleService)
local PvPService = require(script.Parent.PvPService)
local ShopService = require(script.Parent.ShopService)

type Payload = CarryTypes.Payload
type EconomyKind = Telemetry.EconomyKind

-- Cumul d'un gain regroupé (Aggregate), par joueur et par genre + SKU.
type Pending = {
	kind: string,
	sku: string,
	amount: number,
	balance: number, -- solde après le dernier ajout
	count: number, -- nombre d'opérations additionnées
}

local IS_STUDIO = RunService:IsStudio()

-- Caractères que Roblox refuse dans un nom ou un champ (voir l'en-tête), cherchés en texte simple :
-- les guillemets et l'apostrophe typographiques font plusieurs octets.
local FORBIDDEN = { ",", '"', "'", "`", "’", "‘", "“", "”", "«", "»" }

-- Clés des champs custom de Roblox, dans l'ordre.
local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

-- StoreId des colis du camion (TruckEventService : « Truck_<n> »).
local TRUCK_PREFIX = "Truck_"

local TelemetryService = {}
-- V0 proposé, absent du doc : après les services qu'il écoute (au départ, DisplayService encaisse la
-- caisse avant que ce service vide les cumuls) et après TutorialService (200).
TelemetryService.Priority = 210

local enabled = false -- Telemetry.Enabled, lu au démarrage
local pending: { [Player]: { [string]: Pending } } = {}
local warned: { [string]: boolean } = {}
-- Membres de Enum.AnalyticsEconomyTransactionType : nom → Name du membre (rempli au démarrage).
local standardTransactions: { [string]: string } = {}

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[TelemetryService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[TelemetryService] {message}`)
end

-- Nom accepté par Roblox : du texte, pas vide, sans caractère interdit.
local function isSafe(text: any): boolean
	if type(text) ~= "string" or text == "" then
		return false
	end
	for _, token in FORBIDDEN do
		if string.find(text, token, 1, true) then
			return false
		end
	end
	return true
end

-- Le texte sans ses caractères interdits ; nil s'il n'en reste rien.
local function clean(value: any): string?
	if value == nil then
		return nil
	end
	local text = tostring(value)
	for _, token in FORBIDDEN do
		text = table.concat(string.split(text, token))
	end
	return if text == "" then nil else text
end

-- Valeur d'un champ custom, nom de la dimension compris (« Zone - 3 ») ; nil sans valeur.
local function field(label: string, value: any): string?
	if value == nil then
		return nil
	end
	return `{label} - {tostring(value)}`
end

-- Champs custom de Roblox : CustomField01 à 03, dans l'ordre (un nil laisse sa place vide).
local function fieldsOf(a: string?, b: string?, c: string?): ({ [string]: string }?, string)
	local out: { [string]: string } = {}
	local shown: { string } = {}
	local function put(index: number, value: string?)
		local text = clean(value)
		if text then
			out[FIELD_KEYS[index]] = text
			table.insert(shown, text)
		end
	end
	put(1, a)
	put(2, b)
	put(3, c)
	if #shown == 0 then
		return nil, ""
	end
	return out, ` ({table.concat(shown, ", ")})`
end

local function amountText(value: number): string
	return if value == math.floor(value) then string.format("%.0f", value) else tostring(value)
end

local function isValidAmount(value: any): boolean
	return type(value) == "number" and value == value and value > 0 and value < math.huge
end

-- Appelle AnalyticsService dans un pcall (voir l'en-tête). `name` sert aux avertissements.
local function send(name: string, describe: string, call: () -> ()): boolean
	local ok, err = pcall(call :: any) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
	if IS_STUDIO then
		local refused = if ok then "" else ` (refusé par Roblox en Studio : {err})`
		print(`[TelemetryService] {describe}{refused}`)
	elseif not ok then
		warnOnce(`refused:{name}`, `{name} refusé par AnalyticsService : {err}`)
	end
	return ok
end

------------------------------------------------------------------------------
-- Économie
------------------------------------------------------------------------------

local function sendEconomy(player: Player, kindName: string, kind: EconomyKind, amount: number, balance: number, sku: string, second: string?, third: string?, note: string?)
	local flow = if kind.Flow == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
	local transaction = standardTransactions[kind.Transaction] or clean(kind.Transaction) or kindName
	local fields, shown = fieldsOf(field("Kind", kindName), second, third)
	local sign = if kind.Flow == "Source" then "+" else "-"
	local currency = clean(Telemetry.Currency) or "Cash"
	local describe = `{player.Name} : {kind.Flow} {transaction} {sku} {sign}{amountText(amount)} {currency}, solde {amountText(balance)}{shown}{note or ""}`
	send(kindName, describe, function()
		AnalyticsService:LogEconomyEvent(player, flow, currency, amount, balance, transaction, sku, fields)
	end)
end

local function flushEntry(player: Player, key: string)
	local entries = pending[player]
	local entry = if entries then entries[key] else nil
	if entries == nil or entry == nil then
		return
	end
	entries[key] = nil
	local kind: EconomyKind? = Telemetry.Economy[entry.kind]
	if kind then
		local note = if entry.count > 1 then `, {entry.count} opérations regroupées` else nil
		sendEconomy(player, entry.kind, kind, entry.amount, entry.balance, entry.sku, nil, nil, note)
	end
end

-- Envoie tout de suite les cumuls du joueur (voir l'en-tête).
local function flushPlayer(player: Player)
	local entries = pending[player]
	if entries == nil then
		return
	end
	local keys: { string } = {}
	for key in entries do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		flushEntry(player, key)
	end
end

-- Gain ou dépense (voir l'en-tête et LogEconomy). Sans yield.
local function logEconomy(player: Player, kindName: string, amount: number, sku: string?, second: string?, third: string?): boolean
	if not enabled then
		return false
	end
	local kind: EconomyKind? = Telemetry.Economy[kindName]
	if kind == nil then
		warnOnce(`kind:{kindName}`, `genre « {tostring(kindName)} » absent de Config/Telemetry.Economy : rien envoyé`)
		return false
	end
	if not isValidAmount(amount) then
		warnOnce(`amount:{kindName}`, `{kindName} : montant invalide ({tostring(amount)}), rien envoyé`)
		return false
	end
	local data = DataService.Get(player)
	if data == nil then
		log(`{player.Name} : {kindName} pas envoyé, profil pas chargé`)
		return false
	end
	local balance = data.Cash
	local name = clean(sku) or clean(kind.Sku) or kindName
	if kind.Aggregate then
		local entries: { [string]: Pending } = pending[player] or {}
		pending[player] = entries
		local key = `{kindName}/{name}`
		local entry: Pending
		local existing = entries[key]
		if existing then
			entry = existing
		else
			entry = { kind = kindName, sku = name, amount = 0, balance = balance, count = 0 }
			entries[key] = entry
			local created = entry
			task.delay(Telemetry.FlushInterval, function()
				local current = pending[player]
				if current and current[key] == created then
					flushEntry(player, key)
				end
			end)
		end
		entry.amount += amount
		entry.balance = balance
		entry.count += 1
		return true
	end
	flushPlayer(player) -- les cumuls d'abord : l'ordre des soldes reste juste
	sendEconomy(player, kindName, kind, amount, balance, name, second, third, nil)
	return true
end

------------------------------------------------------------------------------
-- Événements custom
------------------------------------------------------------------------------

local function logEvent(player: Player, key: string, a: string?, b: string?, c: string?, value: number?): boolean
	if not enabled then
		return false
	end
	local configured: string? = Telemetry.Events[key]
	if configured == nil then
		warnOnce(`event:{key}`, `événement « {tostring(key)} » absent de Config/Telemetry.Events : rien envoyé`)
		return false
	end
	local name = clean(configured) or key
	local number = if type(value) == "number" and value == value and math.abs(value) < math.huge then value else 1
	local fields, shown = fieldsOf(a, b, c)
	local valueText = if number == 1 then "" else ` = {amountText(number)}`
	send(name, `{player.Name} : {name}{valueText}{shown}`, function()
		AnalyticsService:LogCustomEvent(player, name, number, fields)
	end)
	return true
end

------------------------------------------------------------------------------
-- Événements des services
------------------------------------------------------------------------------

-- Part hors ligne d'un encaissement (accroche ClaimOfflineShare), bornée à [0, amount].
local function offlineShare(player: Player, amount: number): number
	local ok, value = pcall(TelemetryService.ClaimOfflineShare, player, amount)
	if not ok or type(value) ~= "number" or value ~= value then
		warnOnce("hook:ClaimOfflineShare", `ClaimOfflineShare : erreur ou valeur invalide ({tostring(value)}), compté en Income`)
		return 0
	end
	return math.clamp(value, 0, amount)
end

local function onCashOut(player: Player, amount: number, source: DisplayService.CashOutSource)
	local offline = offlineShare(player, amount)
	if amount - offline > 0 then
		logEconomy(player, "Income", amount - offline, nil, nil, nil)
	end
	if offline > 0 then
		logEconomy(player, "Offline", offline, nil, nil, nil)
	end
	if source == "Leave" then
		flushPlayer(player) -- encaissement automatique du départ : le cumul part tout de suite
	end
end

local function onPurchase(player: Player, kind: string, id: string, price: number, level: number?)
	logEconomy(player, kind, price, id, field("Level", level), nil)
	if kind == "Defense" then
		logEvent(player, "DefenseBought", field("Defense", id), field("Level", level), nil, nil)
	end
end

local function onTheftEnded(thief: Player, _victim: Player, itemId: string, result: PvPService.TheftResult, reason: string)
	local item = Items.ById[itemId]
	local rarity = field("Rarity", if item then item.Rarity else nil)
	local zone = field("Zone", if item then item.Zone else nil)
	if result == "Stolen" then
		logEvent(thief, "TheftSuccess", rarity, zone, nil, nil)
	else
		logEvent(thief, "TheftFail", field("Reason", reason), rarity, zone, nil)
	end
end

local function onBatHit(hitter: Player, _target: Player, usage: BatService.Usage, payload: Payload)
	if usage ~= "Box" then
		return
	end
	if payload.Kind == "NPCBox" then
		local source = if string.sub(payload.StoreId, 1, #TRUCK_PREFIX) == TRUCK_PREFIX then "Truck" else "Store"
		logEvent(hitter, "BatBoxKnock", field("Zone", payload.Zone), field("Rarity", payload.Rarity), field("Source", source), nil)
	end
end

local function onCarryEnded(player: Player, payload: Payload, result: CarryTypes.EndResult, reason: string)
	if result ~= "Failed" or reason ~= "Caught" then
		return
	end
	if payload.Kind == "NPCBox" then
		local ok, phase = pcall(NightCycleService.GetPhase)
		logEvent(player, "GuardCatch", field("Zone", payload.Zone), field("Phase", if ok then phase else nil), field("Rarity", payload.Rarity), nil)
	end
end

-- Attrapé la nuit sans rien porter (5.12) : pas de portage, onCarryEnded ne le voit pas.
local function onGuardCatch(player: Player, zone: number, night: boolean, carrying: boolean)
	if night and not carrying then
		logEvent(player, "GuardCatch", field("Zone", zone), field("Phase", "Night"), field("Rarity", "None"), nil)
	end
end

------------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------------

-- Vérifie les noms envoyés à Roblox (voir l'en-tête) : renvoie le nombre de noms fautifs, et les
-- types de transaction à nous (pas des membres de Enum.AnalyticsEconomyTransactionType), triés.
local function checkNames(): (number, { string })
	local bad = 0
	local function check(what: string, text: any, fix: string?)
		if not isSafe(text) then
			bad += 1
			warn(`[TelemetryService] {what} « {tostring(text)} » vide, ou avec une virgule, un guillemet ou une apostrophe : Roblox le refuserait ({fix or "caractères retirés à l'envoi"})`)
		end
	end
	check("monnaie", Telemetry.Currency)
	for key, name in Telemetry.Events do
		check(`nom de l'événement {key}`, name)
	end
	local custom: { string } = {}
	for key, kind in Telemetry.Economy do
		check("genre d'économie", key)
		check(`type de transaction de {key}`, kind.Transaction)
		if kind.Sku ~= nil then
			check(`SKU de {key}`, kind.Sku)
		end
		if not standardTransactions[kind.Transaction] and not table.find(custom, kind.Transaction) then
			table.insert(custom, kind.Transaction)
		end
	end
	table.sort(custom)
	for _, tool in Tools.List do
		check("SKU d'outil", tool.Id)
	end
	for _, upgrade in Upgrades.List do
		check("SKU d'amélioration", upgrade.Id)
	end
	for id in Cosmetics.ById do
		check("SKU d'aura ou de trail", id)
	end
	for index, step in Tutorial.FunnelSteps do
		check(`étape {index} du funnel`, step, "TutorialService l'envoie tel quel : à corriger dans Config/Tutorial")
	end
	return bad, custom
end

function TelemetryService.LogEconomy(player: Player, kind: string, amount: number, sku: string?, fields: { string }?): boolean
	local extra = fields or {}
	return logEconomy(player, kind, amount, sku, extra[1], extra[2])
end

-- Accroche (voir l'en-tête) : sans gains hors ligne, tout encaissement est un revenu (Income).
function TelemetryService.ClaimOfflineShare(_player: Player, _amount: number): number
	return 0
end

function TelemetryService.LogEvent(player: Player, key: string, fields: { string }?, value: number?): boolean
	local extra = fields or {}
	return logEvent(player, key, extra[1], extra[2], extra[3], value)
end

function TelemetryService.Init()
	enabled = Telemetry.Enabled == true
	if not enabled then
		print("[TelemetryService] Config.Telemetry.Enabled = false : rien n'est envoyé à AnalyticsService (économie, événements custom, funnel)")
		return
	end
	for _, item in Enum.AnalyticsEconomyTransactionType:GetEnumItems() do
		standardTransactions[item.Name] = item.Name
	end
	local bad, custom = checkNames()

	DisplayService.OnCashOut(onCashOut)
	ShopService.OnPurchase(onPurchase)
	PvPService.OnTheftEnded(onTheftEnded)
	BatService.OnHit(onBatHit)
	CarryService.OnCarryEnded(onCarryEnded)
	GuardService.OnCatch(onGuardCatch)
	-- Départ : DisplayService a déjà encaissé la caisse (il s'abonne avant ce service).
	DataService.OnProfileReleasing(flushPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(function()
			flushPlayer(player)
			pending[player] = nil
		end)
	end)

	local names = if bad == 0 then "noms vérifiés" else `{bad} nom(s) fautif(s), voir plus haut`
	local types = if #custom == 0 then "" else ` ; types de transaction à nous : {table.concat(custom, ", ")}`
	log(`économie et événements custom branchés, {names} ; revenus regroupés toutes les {Telemetry.FlushInterval} s au plus{types}`)
end

return TelemetryService
