--!strict
-- RewardService (DEV-101 ; Partie 2, section 3.3 et « Proposition V0 d'Ironix » juste dessous ; liaison
-- L-057) : récompenses quotidiennes (calendrier de 7 jours) et de temps de jeu, réclamées dans l'écran
-- UI_Rewards de Clément (RewardsController). Valeurs dans Config/Rewards.
--
-- Serveur autoritaire : l'heure est celle du serveur (os.time(), jour UTC = os.time() // 86400, remise à
-- zéro à minuit UTC), le temps de jeu est compté ici, la récompense et son montant sont décidés ici. Le
-- client ne fait que demander : ClaimDaily() et ClaimPlaytime(minutes) (forme et débit contrôlés par Net).
--
-- Calendrier (profil v8, Rewards.Daily : Streak = dernier jour réclamé, LastDay = jour UTC de cette
-- réclamation) : une réclamation par jour UTC. Le jour à réclamer aujourd'hui :
--   - rien de réclamé, ou cycle fini (J7 réclamé un jour d'avant) : J1 ;
--   - réclamé hier : le jour suivant ;
--   - n jours manqués entre-temps : on recule de n × BackPerMissedDay jours (3.3 : « on recule d'un
--     jour au lieu de repartir à J1 » ; V0 : un jour par jour manqué), jamais avant J1. Ex. : J4
--     réclamé lundi, rien mardi, retour mercredi → J4 à nouveau ;
--   - déjà réclamé aujourd'hui (ou un LastDay dans le futur, horloge qui recule) : rien jusqu'à minuit UTC.
-- Temps de jeu (Rewards.Playtime : Day, Seconds, Claimed) : chaque seconde de présence (profil chargé)
-- compte pour la journée UTC en cours ; à minuit UTC, Seconds et Claimed repartent à zéro (V0 3.3 :
-- « dans la journée », pas par session : se reconnecter ne refait pas les paliers). Un palier se réclame
-- une fois par jour, quand Seconds atteint ses minutes. Le temps passé AFK compte aussi (V0).
--
-- Récompenses (Config/Rewards) :
--   Cash   minutes × 60 × revenu par seconde au moment de la réclamation (DisplayService.GetIncome ×
--          GetGlobalMultiplier : bonus compris, comme le HUD et les packs d'argent), au moins
--          MinCashPerMinute $ par minute ; DataService.AddCash ;
--   Box    UnboxService.GiveItem (vague 43, Cantin du 2026-11-14 : un objet au lieu d'un colis à ouvrir) :
--          l'objet tiré comme le contenu de ce colis (même tirage que GiveBox) entre tout de suite dans
--          l'inventaire ; zone = la plus haute parmi les objets du joueur (zone 1 sans objet), au moins
--          MinZone ; Notify « Rare Item: <nom> » ; inventaire d'objets plein (DisplayService.HasInventoryRoom) :
--          rien n'est donné ni noté, la récompense reste à réclamer (Notify ItemsFull). Ce service ne retire
--          ni ne convertit aucun colis déjà dans un profil (DataService, convertBoxes, le fait au chargement,
--          sans condition) ; vague 80 (a267) : avec BoxRarity, UnboxService.GiveBoxRarityItem (colis de rayon
--          de cette rareté, vague 76), mêmes règles ;
--   Boost  MonetizationService.AddCashBoost (×2 argent, compté seulement en jeu, un 2e prolonge le 1er ;
--          marche aussi boutique Robux coupée).
-- Idempotence : la vérification, le don et la note de la réclamation (Streak et LastDay, ou
-- Claimed[minutes]) se font dans la même exécution, sans yield : un double clic trouve la réclamation
-- déjà notée. ProfileStore n'ouvre un profil que sur un seul serveur à la fois (verrou de session) : un
-- 2e serveur ne lit le profil qu'après la fin de session du 1er, réclamation comprise. Un don qui lève
-- une erreur est noté quand même (avertissement dans la sortie) : jamais deux fois le même don.
--
-- Coffre hebdomadaire (agent a166, MAJ 1 ; 3.3), coupé par Features.WeeklyChest (en Studio, l'attribut
-- WeeklyChestTest = true du Workspace l'allume) ; coupé, rien ne change : aucun jour compté, aucun attribut,
-- ClaimWeekly ignoré. Allumé : chaque jour UTC où le joueur est présent (profil chargé) compte une fois pour
-- la semaine (lundi 00:00 UTC à dimanche, Config/Rewards.Weekly ; Rewards.Weekly du profil, facultatif) ;
-- une autre semaine remet le compte à zéro. À Weekly.DaysNeeded jours (5), ClaimWeekly() donne une fois par
-- semaine l'objet Weekly.Reward (vague 80 : comme un colis Épique de rayon, refusé sans rien noter si l'inventaire est plein) puis
-- l'aura ou le trail exclusif de la semaine (Weekly.Exclusives[date du lundi], vide en V0 : rien) ;
-- télémétrie : RewardClaim, Source Weekly, Sku Week<numéro>.
--
-- Télémétrie (Partie 1, 14.2) : chaque gain d'argent part en économie (TelemetryService.LogEconomy,
-- genres DailyReward et PlaytimeReward, SKU Day1 à Day7, Playtime5 à Playtime60) ; chaque réclamation,
-- argent, colis ou boost, part en événement RewardClaimed (champs Source, Sku, Gift).
--
-- Attributs du Player (Config/Rewards.Attributes, lus par RewardsController ; le serveur ne les lit
-- jamais) : RewardDay (1 à 7), RewardDailyClaimed, RewardDayEndsAt (heure serveur du prochain minuit
-- UTC), RewardPlayStart (heure serveur où le temps de jeu du jour vaudrait 0 : le client compte
-- GetServerTimeNow() − RewardPlayStart), RewardPlayClaimed (« 5,15 ») ; coffre allumé seulement :
-- RewardWeeklyDays, RewardWeeklyClaimed, RewardWeekEndsAt (prochain lundi 00:00 UTC). Remis à jour à chaque réclamation
-- et chaque seconde s'ils changent.
-- a286 (L-224 point 3, Rewards.DailyAfterTutorial) : RewardDailyLocked = true tant que le tuto n'est pas fini (profil
-- Tutorial.Done) ; ClaimDaily est alors refusé (Notify Messages.TutorialFirst), rien n'est versé.
--
-- API (côté serveur) :
--   RewardService.GetDay() -> number
--       Jour UTC du serveur (os.time() // 86400, plus le décalage du test Studio).
--   RewardService.GetState(player) -> State?
--       { Day, DailyClaimed, PlaySeconds, PlayClaimed = { minutes… }, WeeklyOn, WeeklyDays, WeeklyClaimed } ;
--       nil si le profil n'est pas chargé.
--       Pour les bancs d'essai et la barre de commande.
--
-- Tester dans Studio (barre de commande serveur ; hors de Studio, l'attribut n'est pas écouté) :
--   workspace:SetAttribute("RewardTest", "days 1")            avance l'horloge des récompenses d'un jour
--                                                             (tout le serveur ; « days 2 » : un jour manqué)
--   workspace:SetAttribute("RewardTest", "play <joueur> 900") ajoute 15 min de jeu à sa journée
--   workspace:SetAttribute("RewardTest", "reset <joueur>")    remet ses récompenses à zéro
--   workspace:SetAttribute("RewardTest", "weekly <joueur> 4") pose 4 jours comptés cette semaine (coffre allumé)
--   workspace:SetAttribute("WeeklyChestTest", true)           allume le coffre hebdomadaire

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Features = require(Shared.Config.Features)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Rewards = require(Shared.Config.Rewards)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)
local DisplayService = require(script.Parent.DisplayService)
local MonetizationService = require(script.Parent.MonetizationService)
local TelemetryService = require(script.Parent.TelemetryService)
local UnboxService = require(script.Parent.UnboxService)

type Data = ProfileTypes.Data
type RewardsData = ProfileTypes.Rewards
type Reward = Rewards.Reward
type WeeklyData = ProfileTypes.WeeklyRewards
type Source = "Daily" | "Playtime" | "Weekly"

export type State = {
	Day: number, -- jour du calendrier d'aujourd'hui (1 à 7)
	DailyClaimed: boolean,
	DailyLocked: boolean, -- a286 : tuto pas fini, le jour ne se réclame pas (Rewards.DailyAfterTutorial)
	PlaySeconds: number,
	PlayClaimed: { number }, -- minutes des paliers réclamés aujourd'hui, dans l'ordre de Config/Rewards
	WeeklyOn: boolean, -- coffre hebdomadaire allumé
	WeeklyDays: number, -- jours comptés cette semaine (0 si coupé)
	WeeklyClaimed: boolean,
}

-- Ce que ce service garde d'un joueur présent.
type Session = {
	lastClock: number, -- os.clock() du dernier compte du temps de jeu
}

local DAY = Rewards.DayLength
local ATTRIBUTES = Rewards.Attributes
local WEEKLY = Rewards.Weekly
local MESSAGES = Rewards.Messages
local IS_STUDIO = RunService:IsStudio()
-- V0 proposé, absent du doc : écart (s) au-delà duquel RewardDayEndsAt et RewardPlayStart sont réécrits
-- (ils dérivent d'une fraction de seconde à chaque compte, sans que le client ait besoin de le savoir).
local DRIFT = 1.5

local RewardService = {}
-- Après MonetizationService (150), dont il appelle AddCashBoost, et TelemetryService (210) : rien ne
-- dépend de l'ordre (appels en jeu seulement), V0.
RewardService.Priority = 220

local sessions: { [Player]: Session } = {}
local clockOffset = 0 -- secondes ajoutées à os.time() (test Studio « days »)
local warned: { [string]: boolean } = {}

------------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------------

local function log(message: string)
	if IS_STUDIO then
		print(`[RewardService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[RewardService] {message}`)
	end
end

local function notify(player: Player, message: string, kind: string)
	local ok, err = pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
	if not ok then
		warn(`[RewardService] Notify vers {player.Name} : {err}`)
	end
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

-- Tables v8 du profil ; nil (avertissement une fois) si elles sont abîmées (la migration v8 les répare).
local function rewardsOf(player: Player, data: Data?): RewardsData?
	local rewards = if data then (data :: any).Rewards else nil
	if type(rewards) ~= "table" or type(rewards.Daily) ~= "table" or type(rewards.Playtime) ~= "table" or type(rewards.Playtime.Claimed) ~= "table" then
		if data ~= nil then
			warnOnce(`rewards:{player.UserId}`, `{player.Name} : Rewards illisible dans le profil, récompenses coupées pour lui`)
		end
		return nil
	end
	return rewards
end

-- Jour du calendrier à réclamer le jour UTC `day` (1 à 7), et s'il est déjà réclamé (voir l'en-tête).
local function dailyStatus(daily: ProfileTypes.DailyRewards, day: number): (number, boolean)
	local count = #Rewards.Daily
	local streak = math.clamp(math.floor(finite(daily.Streak)), 0, count)
	local last = math.floor(finite(daily.LastDay))
	if streak >= 1 and last > 0 and last >= day then
		return streak, true
	end
	local base = 0
	if last > 0 and streak < count then
		local missed = math.max(0, day - last - 1)
		base = math.max(0, streak - missed * Rewards.BackPerMissedDay)
	end
	return base + 1, false
end

-- Un autre jour UTC : le temps de jeu et ses paliers repartent à zéro. true si c'est fait.
local function rollover(playtime: ProfileTypes.PlaytimeRewards, day: number): boolean
	if playtime.Day == day then
		return false
	end
	playtime.Day = day
	playtime.Seconds = 0
	playtime.Claimed = {}
	return true
end

-- Compte le temps de jeu écoulé depuis le dernier compte (jour UTC en cours). Sans yield.
local function accrue(player: Player)
	local session = sessions[player]
	local rewards = rewardsOf(player, DataService.Get(player))
	if session == nil or rewards == nil then
		return
	end
	local clock = os.clock()
	local elapsed = math.max(0, clock - session.lastClock)
	session.lastClock = clock
	local playtime = rewards.Playtime
	rollover(playtime, today())
	playtime.Seconds = finite(playtime.Seconds) + elapsed
end

local function claimedList(playtime: ProfileTypes.PlaytimeRewards): { number }
	local list: { number } = {}
	for _, tier in Rewards.Playtime do
		if playtime.Claimed[tostring(tier.Minutes)] ~= nil then
			table.insert(list, tier.Minutes)
		end
	end
	return list
end

-- Coffre hebdomadaire allumé : Features.WeeklyChest, ou en Studio l'attribut de test du Workspace.
local function weeklyOn(): boolean
	return Features.WeeklyChest or (IS_STUDIO and Workspace:GetAttribute(WEEKLY.TestAttribute) == true)
end

local function weekOf(day: number): number
	return (day + WEEKLY.MondayOffset) // 7
end

-- Rewards.Weekly du profil, créé ou réparé s'il manque ou s'il est abîmé (champ facultatif).
local function weeklyOf(rewards: RewardsData): WeeklyData
	local weekly: any = (rewards :: any).Weekly
	if type(weekly) ~= "table" then
		weekly = {}
		rewards.Weekly = weekly
	end
	for _, field in { "Week", "Days", "LastDay", "ClaimedWeek" } do
		weekly[field] = math.floor(finite(weekly[field]))
	end
	return weekly :: WeeklyData
end

-- Compte le jour UTC `day` pour sa semaine (une fois par jour ; une autre semaine repart de zéro). Renvoie
-- (semaine, jours comptés, réclamé cette semaine). Sans yield.
local function touchWeek(rewards: RewardsData, day: number): (number, number, boolean)
	local weekly = weeklyOf(rewards)
	local week = weekOf(day)
	if weekly.Week ~= week then
		weekly.Week = week
		weekly.Days = 0
		weekly.LastDay = 0
	end
	if day > weekly.LastDay then -- horloge qui recule : rien de compté deux fois
		weekly.Days = math.min(weekly.Days + 1, 7)
		weekly.LastDay = day
	end
	return week, weekly.Days, weekly.ClaimedWeek == week
end

local function setAttribute(player: Player, name: string, value: any)
	if player.Parent == Players and player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

-- Heure serveur, réécrite seulement si elle s'écarte de plus de DRIFT s de celle déjà posée.
local function setTime(player: Player, name: string, value: number)
	local current = player:GetAttribute(name)
	if type(current) ~= "number" or math.abs(current - value) > DRIFT then
		setAttribute(player, name, value)
	end
end

-- a286 (L-224 point 3, Rewards.DailyAfterTutorial) : récompense du jour bloquée tant que le tuto n'est pas fini. Profil
-- sans tuto (ancien format) : pas bloqué.
local function dailyLocked(data: Data?): boolean
	if Rewards.DailyAfterTutorial ~= true or data == nil then
		return false
	end
	local tutorial = data.Tutorial
	return type(tutorial) == "table" and tutorial.Done ~= true
end

-- Remet les attributs du joueur d'accord avec son profil.
local function publish(player: Player)
	local rewards = rewardsOf(player, DataService.Get(player))
	if rewards == nil then
		return
	end
	local day = today()
	rollover(rewards.Playtime, day)
	local calendarDay, claimed = dailyStatus(rewards.Daily, day)
	local serverNow = Workspace:GetServerTimeNow()
	setAttribute(player, ATTRIBUTES.Day, calendarDay)
	setAttribute(player, ATTRIBUTES.DailyClaimed, claimed)
	setAttribute(player, ATTRIBUTES.DailyLocked, if dailyLocked(DataService.Get(player)) then true else nil) -- a286
	setTime(player, ATTRIBUTES.DayEndsAt, serverNow + (DAY - now() % DAY))
	setTime(player, ATTRIBUTES.PlayStart, serverNow - finite(rewards.Playtime.Seconds))
	local list: { string } = {}
	for _, minutes in claimedList(rewards.Playtime) do
		table.insert(list, tostring(minutes))
	end
	setAttribute(player, ATTRIBUTES.PlayClaimed, table.concat(list, ","))
	if weeklyOn() then
		local week, weekDays, weekClaimed = touchWeek(rewards, day)
		setAttribute(player, ATTRIBUTES.WeeklyDays, weekDays)
		setAttribute(player, ATTRIBUTES.WeeklyClaimed, weekClaimed)
		setTime(player, ATTRIBUTES.WeekEndsAt, serverNow + ((week + 1) * 7 - WEEKLY.MondayOffset) * DAY - now())
	else
		setAttribute(player, ATTRIBUTES.WeeklyDays, nil)
		setAttribute(player, ATTRIBUTES.WeeklyClaimed, nil)
		setAttribute(player, ATTRIBUTES.WeekEndsAt, nil)
	end
end

-- Zone des colis offerts : la plus haute parmi les objets du joueur (zone du catalogue, sinon celle de
-- l'objet : le Secret), zone 1 sans objet (V0 3.3).
local function bestZone(data: Data): number
	local best = 1
	local items = (data :: any).Items
	if type(items) ~= "table" then
		return best
	end
	for _, entry in items do
		local def = if type(entry) == "table" then Items.ById[entry.Id] else nil
		if def then
			local zone = def.Zone or entry.Zone
			if type(zone) == "number" and Zones[zone] ~= nil and zone > best then
				best = zone
			end
		end
	end
	return best
end

-- « X min de revenus » (V0 3.3) : revenu actuel bonus compris, au moins MinCashPerMinute $ par minute.
local function cashAmount(player: Player, minutes: number): number
	local income = finite(DisplayService.GetIncome(player)) * finite(DisplayService.GetGlobalMultiplier(player))
	return math.floor(math.max(math.max(income, 0) * 60 * minutes, Rewards.MinCashPerMinute * minutes))
end

------------------------------------------------------------------------------
-- Réclamations
------------------------------------------------------------------------------

-- Donne `reward`. Renvoie (true, message, somme d'argent ou 0) si c'est donné, (false, raison) si rien
-- n'est donné (la réclamation n'est alors pas notée). Sans yield.
local function give(player: Player, data: Data, reward: Reward): (boolean, string, number)
	local kind = reward.Kind
	if kind == "Cash" then
		local amount = cashAmount(player, reward.Minutes or 0)
		if DataService.AddCash(player, amount) == nil then
			return false, MESSAGES.Unavailable, 0
		end
		return true, string.format(MESSAGES.Cash, Format.money(amount)), amount
	elseif kind == "Box" then
		local tier = reward.Tier or "Standard"
		local zone = math.max(bestZone(data), reward.MinZone or 1)
		local boxRarity = reward.BoxRarity
		local itemUid: string?, reason: string?, itemId: string? = nil, nil, nil
		if boxRarity then
			itemUid, reason, itemId = UnboxService.GiveBoxRarityItem(player, boxRarity, zone) -- vague 80 (a267)
		else
			itemUid, reason, itemId = UnboxService.GiveItem(player, tier, zone, reward.MinRarity)
		end
		if itemUid == nil then
			return false, if reason == "InventoryFull" then MESSAGES.ItemsFull else MESSAGES.Unavailable, 0
		end
		local entry = (data :: any).Items[itemUid]
		local def = if itemId then Items.ById[itemId] else nil
		local rarity = if def then Rarities.ById[def.Rarity] else nil
		local name = if def then Mutations.ItemName(def.DisplayName, if entry then entry.Mutation else nil) else tostring(itemId)
		return true, string.format(MESSAGES.Item, if rarity then rarity.DisplayName else "", name), 0
	elseif kind == "Boost" then
		local minutes = reward.Minutes or 0
		if not MonetizationService.AddCashBoost(player, minutes * 60) then
			return false, MESSAGES.Unavailable, 0
		end
		return true, string.format(MESSAGES.Boost, minutes), 0
	end
	return false, MESSAGES.Unavailable, 0
end

-- Donne `reward`, puis appelle mark() (note la réclamation dans le profil), dans la même exécution.
-- Refus propre (inventaire plein…) : rien n'est noté, le joueur reçoit la raison. Erreur pendant le don :
-- noté quand même (jamais deux fois le même don), avertissement. Sans yield.
local function claim(player: Player, data: Data, reward: Reward, source: Source, sku: string, mark: () -> ()): boolean
	local ok, given, message, amount = pcall(give, player, data, reward)
	if not ok then
		warn(`[RewardService] {player.Name} : erreur pendant le don de {sku} ({given}) : réclamation notée quand même, à compenser à la main si rien n'est arrivé`)
		mark()
		publish(player)
		return true
	end
	if not given then
		log(`{player.Name} : {sku} refusé ({message})`)
		notify(player, message, "Warning")
		publish(player)
		return false
	end
	mark()
	-- Télémétrie juste après AddCash, sans yield (le solde est lu à l'appel).
	if amount > 0 then
		TelemetryService.LogEconomy(player, if source == "Daily" then "DailyReward" elseif source == "Weekly" then "WeeklyReward" else "PlaytimeReward", amount, sku)
	end
	TelemetryService.LogEvent(player, "RewardClaim", { `Source - {source}`, `Sku - {sku}`, `Gift - {reward.Kind}` })
	log(`{player.Name} : {sku} réclamé ({message})`)
	notify(player, message, "Info")
	publish(player)
	return true
end

local function onClaimDaily(player: Player)
	local data = DataService.Get(player)
	local rewards = rewardsOf(player, data)
	if data == nil or rewards == nil then
		return
	end
	local day = today()
	local calendarDay, claimed = dailyStatus(rewards.Daily, day)
	if claimed then
		notify(player, MESSAGES.AlreadyClaimed, "Warning")
		publish(player)
		return
	end
	if dailyLocked(data) then
		notify(player, MESSAGES.TutorialFirst, "Warning") -- a286 (L-224 point 3) : tuto pas fini
		publish(player)
		return
	end
	local reward = Rewards.Daily[calendarDay]
	claim(player, data, reward, "Daily", `Day{calendarDay}`, function()
		rewards.Daily.Streak = calendarDay
		rewards.Daily.LastDay = day
	end)
end

local function onClaimPlaytime(player: Player, minutes: number)
	local data = DataService.Get(player)
	local rewards = rewardsOf(player, data)
	if data == nil or rewards == nil then
		return
	end
	local tier: Rewards.PlaytimeTier? = nil
	for _, candidate in Rewards.Playtime do
		if candidate.Minutes == minutes then
			tier = candidate
		end
	end
	if tier == nil then
		log(`{player.Name} : palier de {minutes} min inconnu, ignoré`)
		return
	end
	accrue(player)
	local playtime = rewards.Playtime
	rollover(playtime, today())
	local key = tostring(minutes)
	if playtime.Claimed[key] ~= nil then
		publish(player) -- double clic : déjà donné
		return
	end
	if finite(playtime.Seconds) < minutes * 60 then
		notify(player, MESSAGES.NotYet, "Warning")
		publish(player)
		return
	end
	claim(player, data, tier.Reward, "Playtime", `Playtime{minutes}`, function()
		playtime.Claimed[key] = os.time()
	end)
end

-- Aura ou trail exclusif de la semaine `week` (Weekly.Exclusives[date du lundi]), s'il y en a un. CosmeticService
-- n'est requis qu'ici (liste vide en V0). Une erreur est écrite ; l'objet du coffre reste donné.
local function grantExclusive(player: Player, week: number)
	local monday = os.date("!%Y-%m-%d", (week * 7 - WEEKLY.MondayOffset) * DAY)
	local cosmeticId = WEEKLY.Exclusives[monday]
	if cosmeticId == nil then
		return
	end
	local def = Cosmetics.ById[cosmeticId]
	local ok, granted = pcall(function(): boolean
		-- require dynamique : CosmeticService n'est chargé que si un exclusif existe (aucun en V0)
		return (require :: any)(script.Parent:FindFirstChild("CosmeticService")).Grant(player, cosmeticId)
	end)
	if not ok or granted ~= true or def == nil then
		warn(`[RewardService] {player.Name} : exclusif {cosmeticId} de la semaine du {monday} pas donné ({tostring(granted)})`)
		return
	end
	notify(player, string.format(MESSAGES.WeeklyExclusive, def.DisplayName), "Info")
end

local function onClaimWeekly(player: Player)
	if not weeklyOn() then
		return -- coupé : rien ne change en jeu
	end
	local data = DataService.Get(player)
	local rewards = rewardsOf(player, data)
	if data == nil or rewards == nil then
		return
	end
	local week, weekDays, weekClaimed = touchWeek(rewards, today())
	if weekClaimed then
		notify(player, MESSAGES.WeeklyAlreadyClaimed, "Warning")
		publish(player)
		return
	end
	if weekDays < WEEKLY.DaysNeeded then
		notify(player, string.format(MESSAGES.WeeklyNotYet, WEEKLY.DaysNeeded), "Warning")
		publish(player)
		return
	end
	claim(player, data, WEEKLY.Reward, "Weekly", `Week{week}`, function()
		weeklyOf(rewards).ClaimedWeek = week
		grantExclusive(player, week)
	end)
end

------------------------------------------------------------------------------
-- Joueurs, horloge
------------------------------------------------------------------------------

local function onProfileLoaded(player: Player)
	if DataService.Get(player) == nil then
		return
	end
	sessions[player] = { lastClock = os.clock() }
	publish(player)
end

-- Départ : dernier compte du temps de jeu (DataService écrit le profil juste après).
local function onProfileReleasing(player: Player)
	accrue(player)
	sessions[player] = nil
end

local function tick()
	for player in sessions do
		if DataService.Get(player) == nil then
			sessions[player] = nil
			continue
		end
		accrue(player)
		publish(player)
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
	local value = Workspace:GetAttribute(Rewards.TestAttribute)
	if value == nil then
		return
	end
	Workspace:SetAttribute(Rewards.TestAttribute, nil)
	local words: { string } = {}
	for word in string.gmatch(tostring(value), "%S+") do
		table.insert(words, word)
	end
	local command = words[1]
	if command == "days" and tonumber(words[2]) and (tonumber(words[2]) :: number) >= 1 then
		local days = math.floor(tonumber(words[2]) :: number)
		for player in sessions do
			accrue(player) -- le temps déjà joué reste au jour d'avant
		end
		clockOffset += days * DAY
		print(`[RewardService] test : horloge des récompenses avancée de {days} jour(s) (jour UTC {today()})`)
		tick()
		return
	end
	local player = if words[2] then findPlayer(words[2]) else nil
	local rewards = if player then rewardsOf(player, DataService.Get(player)) else nil
	if command == "play" and player and rewards and tonumber(words[3]) and (tonumber(words[3]) :: number) > 0 then
		accrue(player)
		rewards.Playtime.Seconds = finite(rewards.Playtime.Seconds) + (tonumber(words[3]) :: number)
		print(`[RewardService] test : {player.Name} a joué {math.floor(rewards.Playtime.Seconds)} s aujourd'hui`)
		publish(player)
		return
	end
	if command == "reset" and player and rewards then
		rewards.Daily = { Streak = 0, LastDay = 0 }
		rewards.Playtime = { Day = today(), Seconds = 0, Claimed = {} }
		rewards.Weekly = { Week = 0, Days = 0, LastDay = 0, ClaimedWeek = 0 }
		local session = sessions[player]
		if session then
			session.lastClock = os.clock()
		end
		print(`[RewardService] test : récompenses de {player.Name} remises à zéro`)
		publish(player)
		return
	end
	if command == "weekly" and player and rewards and tonumber(words[3]) and weeklyOn() then
		touchWeek(rewards, today())
		local weekly = weeklyOf(rewards)
		weekly.Days = math.clamp(math.floor(tonumber(words[3]) :: number), 0, 7)
		print(`[RewardService] test : {player.Name} a {weekly.Days} jour(s) de connexion cette semaine`)
		publish(player)
		return
	end
	warn(`[RewardService] test : « {tostring(value)} » : attendu « days <n> », « play <joueur> <secondes> », « reset <joueur> » ou « weekly <joueur> <jours> » (coffre allumé) avec un joueur présent`)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function RewardService.GetDay(): number
	return today()
end

function RewardService.GetState(player: Player): State?
	local rewards = rewardsOf(player, DataService.Get(player))
	if rewards == nil then
		return nil
	end
	accrue(player)
	local day = today()
	rollover(rewards.Playtime, day)
	local calendarDay, claimed = dailyStatus(rewards.Daily, day)
	local on = weeklyOn()
	local weekDays, weekClaimed = 0, false
	if on then
		local _, days, done = touchWeek(rewards, day)
		weekDays, weekClaimed = days, done
	end
	return {
		Day = calendarDay,
		DailyClaimed = claimed,
		DailyLocked = dailyLocked(DataService.Get(player)),
		PlaySeconds = finite(rewards.Playtime.Seconds),
		PlayClaimed = claimedList(rewards.Playtime),
		WeeklyOn = on,
		WeeklyDays = weekDays,
		WeeklyClaimed = weekClaimed,
	}
end

function RewardService.Init()
	Net.Server.ClaimDaily:Connect(onClaimDaily)
	Net.Server.ClaimPlaytime:Connect(onClaimPlaytime)
	Net.Server.ClaimWeekly:Connect(onClaimWeekly)
	DataService.OnProfileLoaded(onProfileLoaded)
	DataService.OnProfileReleasing(onProfileReleasing)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(function()
			sessions[player] = nil
		end)
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < Rewards.Tick then
			return
		end
		elapsed = 0
		local ok, err = pcall(tick :: any) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
		if not ok then
			warn(`[RewardService] compte du temps de jeu : {err}`)
		end
	end)
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(Rewards.TestAttribute):Connect(onTestAttribute)
	end
	log(`calendrier de {#Rewards.Daily} jours et {#Rewards.Playtime} paliers de temps de jeu, remise à zéro à minuit UTC`)
end

return RewardService
