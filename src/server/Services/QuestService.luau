--!strict
-- QuestService (DEV-132 ; vague 80, a266) : quêtes quotidiennes. Valeurs et règles : Config/Quests (V0 proposés,
-- Cantin, 20/11). Client : QuestController (écran UI_Quests de Clément, bouton QuestsButton du HUD). Coupé par
-- Features.Quests : coupé, aucun attribut, rien n'est compté, ClaimQuest est ignoré.
--
-- Serveur autoritaire : le jour est celui du serveur (os.time() // 86400, remise à zéro à minuit UTC, comme
-- RewardService) ; les quêtes du jour sont tirées ici ; la progression n'est comptée qu'ici, à partir des événements
-- des autres services (voir Config/Quests) : aucun remote ne fait avancer une quête. Le client ne fait que demander
-- la récompense d'une quête finie : ClaimQuest(place) (place entière 1 à PerDay, forme et débit contrôlés par Net).
--
-- Profil (champ facultatif Quests, sans nouvelle version, créé et réparé ici) :
--   Quests = { Day = jour UTC du tirage, List = { { Id, Progress, Goal, Claimed = os.time() de la réclamation ou 0 } } }
-- Un autre jour UTC (au chargement, ou en jeu à minuit UTC) tire de nouvelles quêtes : les anciennes, finies ou pas,
-- sont perdues.
--
-- Réclamation : la vérification, le don (Prize/Grant) et la note (Claimed) se font dans la même exécution, sans
-- yield : un double clic trouve la quête déjà réclamée. Un refus propre (inventaire d'objets plein, stock de potions
-- plein) ne note rien : la quête reste à réclamer (Notify avec la raison). Un don qui lève une erreur est noté quand
-- même (avertissement) : jamais deux fois le même don.
--
-- Télémétrie : argent d'une récompense en économie (genre QuestReward, SKU Quest_<Id>) ; chaque réclamation en
-- événement QuestClaimed (champs Quest, Gift).
--
-- Attributs du Player (Config/Quests.Attributes, lus par QuestController) : Quest<i> (Id), Quest<i>Progress,
-- Quest<i>Goal, Quest<i>Claimed, QuestsEndsAt (heure serveur du prochain minuit UTC).
--
-- Quêtes qui ne peuvent pas être comptées sans toucher StoreHeistService (a265 y travaille) : l'ouverture exacte d'un
-- colis (comptée ici à la prise en main de l'objet sorti, CarryService.OnCarryStarted), l'entrée dans un magasin, un
-- braquage raté, « défendre sa boutique » (PvPService ne dit pas qui a repris l'objet).
--
-- API (côté serveur) :
--   QuestService.GetState(player) -> State?     { Day, List = { { Id, Progress, Goal, Claimed } } } ; nil sans profil
--                                                ou quêtes coupées. Pour les bancs et la barre de commande.
--   QuestService.Add(player, event, amount)     fait avancer les quêtes `event` du joueur (Config/Quests.Event) ;
--                                                pour un service qui voudrait compter un nouvel événement.
--
-- Tester dans Studio (barre de commande serveur ; hors de Studio, l'attribut n'est pas écouté) :
--   workspace:SetAttribute("QuestTest", "days 1")                    avance l'horloge des quêtes d'un jour
--   workspace:SetAttribute("QuestTest", "add <joueur> Heist 2")      ajoute 2 braquages
--   workspace:SetAttribute("QuestTest", "done <joueur>")             finit ses quêtes du jour
--   workspace:SetAttribute("QuestTest", "reroll <joueur>")           retire ses quêtes : nouveau tirage

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local ItemRain = require(Shared.Config.ItemRain)
local Quests = require(Shared.Config.Quests)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local BotService = require(script.Parent.BotService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local PvPService = require(script.Parent.PvPService)
local TelemetryService = require(script.Parent.TelemetryService)
local TrainingService = require(script.Parent.TrainingService)
local UnboxService = require(script.Parent.UnboxService)
local WindowService = require(script.Parent.WindowService)
local Grant = require(script.Parent.Prize.Grant)

type QuestsData = ProfileTypes.Quests
type QuestEntry = ProfileTypes.QuestEntry
type Quest = Quests.Quest

export type State = {
	Day: number,
	List: { { Id: string, Progress: number, Goal: number, Claimed: boolean } },
}

local DAY = Quests.DayLength
local ATTRIBUTES = Quests.Attributes
local MESSAGES = Quests.Messages
local IS_STUDIO = RunService:IsStudio()
-- V0 proposé (Cantin, 20/11), comme RewardService : écart (s) au-delà duquel QuestsEndsAt est réécrit.
local DRIFT = 1.5

local QuestService = {}
-- Après TelemetryService (210) et RewardService (220) ; rien ne dépend de l'ordre (appels en jeu seulement).
QuestService.Priority = 230

local present: { [Player]: boolean } = {}
local lastCash: { [Player]: number } = {}
local carriedFrom: { [Player]: string } = {} -- StoreId du dernier objet NPCItem pris en main
local seenPayloads: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local clockOffset = 0 -- secondes ajoutées à os.time() (test Studio « days »)
local warned: { [string]: boolean } = {}
local rng = Random.new()

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[QuestService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[QuestService] {message}`)
	end
end

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[QuestService] Notify vers {player.Name} : {err}`)
	end
end

local function on(): boolean
	return Features.Quests == true
end

local function now(): number
	return os.time() + clockOffset
end

local function today(): number
	return now() // DAY
end

local function finite(value: any): number
	return if type(value) == "number" and value == value and math.abs(value) < math.huge then value else 0
end

local function setAttribute(player: Player, name: string, value: any)
	if player.Parent == Players and player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

------------------------------------------------------------------------------
-- Profil
------------------------------------------------------------------------------

-- Objectif d'une quête au tirage (EarnCash : minutes de revenus du joueur à ce moment-là).
local function goalFor(player: Player, quest: Quest): number
	if quest.GoalMinutes then
		return math.max(1, Grant.CashAmount(player, quest.GoalMinutes))
	end
	return math.max(1, math.floor(quest.Goal or 1))
end

-- Tire PerDay quêtes différentes (poids Weight).
local function roll(player: Player): { QuestEntry }
	local pool: { Quest } = table.clone(Quests.List)
	local list: { QuestEntry } = {}
	while #list < Quests.PerDay and #pool > 0 do
		local total = 0
		for _, quest in pool do
			total += math.max(0, quest.Weight)
		end
		local pick = rng:NextNumber() * total
		local index = #pool
		for i, quest in pool do
			pick -= math.max(0, quest.Weight)
			if pick < 0 then
				index = i
				break
			end
		end
		local quest = table.remove(pool, index) :: Quest
		table.insert(list, { Id = quest.Id, Progress = 0, Goal = goalFor(player, quest), Claimed = 0 })
	end
	return list
end

-- Quests du profil, créé, réparé et tiré à nouveau un autre jour UTC. nil sans profil. Sans yield.
local function questsOf(player: Player): QuestsData?
	local data = DataService.Get(player)
	if data == nil then
		return nil
	end
	local quests: any = (data :: any).Quests
	if type(quests) ~= "table" or type(quests.List) ~= "table" then
		if quests ~= nil then
			warnOnce(`quests:{player.UserId}`, `{player.Name} : Quests illisible dans le profil, nouveau tirage`)
		end
		quests = { Day = 0, List = {} }
		data.Quests = quests
	end
	local day = today()
	if quests.Day ~= day then
		quests.Day = day
		quests.List = roll(player)
		log(`{player.Name} : quêtes du jour {day} tirées`)
		return quests :: QuestsData
	end
	-- Réparation : une entrée inconnue (quête retirée de Config) ou abîmée est retirée.
	for index = #quests.List, 1, -1 do
		local entry = quests.List[index]
		if type(entry) ~= "table" or Quests.ById[entry.Id] == nil then
			table.remove(quests.List, index)
		else
			entry.Progress = math.max(0, finite(entry.Progress))
			entry.Goal = math.max(1, finite(entry.Goal))
			entry.Claimed = finite(entry.Claimed)
		end
	end
	return quests :: QuestsData
end

-- Remet les attributs du joueur d'accord avec son profil (rien si les quêtes sont coupées).
local function publish(player: Player)
	if not on() then
		return
	end
	local quests = questsOf(player)
	if quests == nil then
		return
	end
	for slot = 1, Quests.PerDay do
		local entry = quests.List[slot]
		setAttribute(player, string.format(ATTRIBUTES.Id, slot), if entry then entry.Id else nil)
		setAttribute(player, string.format(ATTRIBUTES.Progress, slot), if entry then math.floor(math.min(entry.Progress, entry.Goal)) else nil)
		setAttribute(player, string.format(ATTRIBUTES.Goal, slot), if entry then math.floor(entry.Goal) else nil)
		setAttribute(player, string.format(ATTRIBUTES.Claimed, slot), if entry then entry.Claimed > 0 else nil)
	end
	local endsAt = Workspace:GetServerTimeNow() + (DAY - now() % DAY)
	local current = player:GetAttribute(ATTRIBUTES.EndsAt)
	if type(current) ~= "number" or math.abs(current - endsAt) > DRIFT then
		setAttribute(player, ATTRIBUTES.EndsAt, endsAt)
	end
end

------------------------------------------------------------------------------
-- Progression
------------------------------------------------------------------------------

local function add(player: Player, event: Quests.Event, amount: number)
	if not on() or not present[player] or not (amount > 0) then
		return
	end
	local quests = questsOf(player)
	if quests == nil then
		return
	end
	local changed = false
	for _, entry in quests.List do
		local quest = Quests.ById[entry.Id]
		if quest and quest.Event == event and entry.Claimed == 0 and entry.Progress < entry.Goal then
			entry.Progress = math.min(entry.Goal, entry.Progress + amount)
			changed = true
			if entry.Progress >= entry.Goal then
				log(`{player.Name} : quête {entry.Id} finie`)
				notify(player, MESSAGES.Complete, "Success")
			end
		end
	end
	if changed then
		publish(player)
	end
end

local function onItemStowed(player: Player, _itemUid: string, _itemId: string)
	-- Un objet de la pluie d'objets n'est pas un braquage.
	if carriedFrom[player] == ItemRain.StoreId then
		return
	end
	add(player, "Heist", 1)
end

local function onCarryStarted(player: Player, payload: any)
	if type(payload) ~= "table" or payload.Kind ~= "NPCItem" then
		return
	end
	carriedFrom[player] = payload.StoreId
	-- CarryService repasse la même table quand l'objet est repris au sol ou par un autre joueur : compté une fois.
	if seenPayloads[payload] or payload.StoreId == ItemRain.StoreId then
		return
	end
	seenPayloads[payload] = true
	add(player, "OpenBox", 1)
end

local function onCashChanged(player: Player, cash: number)
	local before = lastCash[player]
	lastCash[player] = cash
	if before == nil or Grant.IsGranting(player) then
		return
	end
	local delta = cash - before
	if delta > 0 then
		add(player, "EarnCash", delta)
	end
end

------------------------------------------------------------------------------
-- Réclamation
------------------------------------------------------------------------------

local function onClaimQuest(player: Player, slot: number)
	if not on() or not present[player] then
		return
	end
	local quests = questsOf(player)
	local entry = if quests then quests.List[slot] else nil
	local quest = if entry then Quests.ById[entry.Id] else nil
	if entry == nil or quest == nil then
		publish(player)
		return
	end
	if entry.Claimed > 0 then
		publish(player) -- double clic : déjà donné
		return
	end
	if entry.Progress < entry.Goal then
		notify(player, MESSAGES.NotDone, "Warning")
		publish(player)
		return
	end
	local sku = `Quest_{quest.Id}`
	local ok, given, message, amount = pcall(Grant.Give :: any, player, quest.Reward)
	if not ok then
		warn(`[QuestService] {player.Name} : erreur pendant le don de {sku} ({given}) : quête notée réclamée quand même, à compenser à la main si rien n'est arrivé`)
		entry.Claimed = os.time()
		publish(player)
		return
	end
	if not given then
		log(`{player.Name} : {sku} refusé ({message})`)
		notify(player, message, "Warning")
		publish(player)
		return
	end
	entry.Claimed = os.time()
	if amount > 0 then
		TelemetryService.LogEconomy(player, "QuestReward", amount, sku)
	end
	TelemetryService.LogEvent(player, "QuestClaim", { `Quest - {quest.Id}`, `Gift - {quest.Reward.Kind}` })
	log(`{player.Name} : {sku} réclamé ({message})`)
	notify(player, message, "Info")
	publish(player)
end

------------------------------------------------------------------------------
-- Joueurs, horloge
------------------------------------------------------------------------------

local function onProfileLoaded(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	present[player] = true
	lastCash[player] = finite(data.Cash)
	publish(player)
end

local function forget(player: Player)
	present[player] = nil
	lastCash[player] = nil
	carriedFrom[player] = nil
end

local function tick(dt: number)
	if not on() then
		return
	end
	for player in present do
		if DataService.Get(player) == nil then
			forget(player)
			continue
		end
		local ok, training = pcall(TrainingService.IsTraining, player)
		if ok and training == true then
			add(player, "Treadmill", dt)
		end
		publish(player) -- minuit UTC : nouveau tirage ; QuestsEndsAt
	end
end

------------------------------------------------------------------------------
-- Crochet de test (Studio seulement)
------------------------------------------------------------------------------

local function findPlayer(who: string): Player?
	local userId = tonumber(who)
	for _, player in Players:GetPlayers() do
		if player.Name == who or (userId ~= nil and player.UserId == userId) then
			return player
		end
	end
	return nil
end

local function onTestAttribute()
	local value = Workspace:GetAttribute(Quests.TestAttribute)
	if value == nil then
		return
	end
	Workspace:SetAttribute(Quests.TestAttribute, nil)
	local words: { string } = {}
	for word in string.gmatch(tostring(value), "%S+") do
		table.insert(words, word)
	end
	local command = words[1]
	if command == "days" and tonumber(words[2]) and (tonumber(words[2]) :: number) >= 1 then
		clockOffset += math.floor(tonumber(words[2]) :: number) * DAY
		print(`[QuestService] test : horloge des quêtes avancée (jour UTC {today()})`)
		for player in present do
			publish(player)
		end
		return
	end
	local player = if words[2] then findPlayer(words[2]) else nil
	local quests = if player then questsOf(player) else nil
	if player and quests then
		if command == "add" and words[3] and tonumber(words[4]) then
			add(player, words[3] :: any, tonumber(words[4]) :: number)
			print(`[QuestService] test : {player.Name} +{words[4]} {words[3]}`)
			return
		elseif command == "done" then
			for _, entry in quests.List do
				entry.Progress = entry.Goal
			end
			print(`[QuestService] test : quêtes de {player.Name} finies`)
			publish(player)
			return
		elseif command == "reroll" then
			quests.Day = 0
			print(`[QuestService] test : quêtes de {player.Name} tirées à nouveau`)
			publish(player)
			return
		end
	end
	warn(`[QuestService] test : « {tostring(value)} » : attendu « days <n> », « add <joueur> <Event> <n> », « done <joueur> » ou « reroll <joueur> » avec un joueur présent`)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function QuestService.GetState(player: Player): State?
	if not on() then
		return nil
	end
	local quests = questsOf(player)
	if quests == nil then
		return nil
	end
	local list = {}
	for _, entry in quests.List do
		table.insert(list, { Id = entry.Id, Progress = entry.Progress, Goal = entry.Goal, Claimed = entry.Claimed > 0 })
	end
	return { Day = quests.Day, List = list }
end

function QuestService.Add(player: Player, event: Quests.Event, amount: number)
	add(player, event, amount)
end

function QuestService.Init()
	Net.Server.ClaimQuest:Connect(onClaimQuest)
	DataService.OnProfileLoaded(onProfileLoaded)
	DataService.OnProfileReleasing(forget)
	DataService.OnCashChanged(onCashChanged)
	UnboxService.OnItemStowed(onItemStowed)
	CarryService.OnCarryStarted(onCarryStarted)
	PvPService.OnTheftEnded(function(thief: Player, _victim: Player, _itemId: string, result: string, _reason: string)
		if result == "Stolen" then
			add(thief, "StealPlayer", 1)
		end
	end)
	BotService.OnTheft(function(thief: Player, _itemId: string, stage: string)
		if stage == "Stolen" then
			add(thief, "StealPlayer", 1)
		end
	end)
	WindowService.OnBroken(function(info)
		local breaker: Instance? = info.Breaker
		if info.Kind == "NPC" and breaker and breaker:IsA("Player") then
			add(breaker :: Player, "BreakWindow", 1)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(forget, player)
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < Quests.Tick then
			return
		end
		local step = elapsed
		elapsed = 0
		local ok, err = pcall(tick :: any, step) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			warn(`[QuestService] horloge : {err}`)
		end
	end)
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(Quests.TestAttribute):Connect(onTestAttribute)
	end
	log(`{Quests.PerDay} quêtes par jour parmi {#Quests.List}, remise à zéro à minuit UTC ({if on() then "allumées" else "coupées"})`)
end

return QuestService
