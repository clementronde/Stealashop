--!strict
-- WeeklyLeaderboardService (GC6, a409, MAJ 6, DEV-140 ; Partie 2 « classements hebdomadaires récompensés ») : top 100
-- de la semaine en $/s et en vols. Valeurs : Config/WeeklyLeaderboard ; interrupteur Features.WeeklyLeaderboards.
-- S'appuie sur LeaderboardService (record de revenu sans les boosts du moment, panneaux du hub). Aucun remote.
--
--   - Compteurs de la semaine dans le profil (WeeklyBoard, Types/Profile ; dans le gabarit de DataService depuis a430,
--     réparé ici) : à la première lecture d'une nouvelle semaine (lundi 00:00 UTC), la semaine finie va dans Pending si
--     le joueur y a joué, BestIncome repart de 0 et StealsAt prend Lifetime.Steals. Revenu = meilleur revenu par
--     seconde de la semaine (LeaderboardService.RecordIncome, suivi à chaque changement de l'attribut Income et à
--     chaque écriture) ; vols = Steals − StealsAt : seulement les vols chez un autre joueur (a430, L-325 réponse (1) de
--     Clément : les braquages de magasins, Lifetime.Heists, ne comptent plus ; HeistsAt n'est plus lu).
--   - Écriture : toutes les WriteInterval s et au départ du joueur, SetAsync(UserId, valeur codée) dans
--     l'OrderedDataStore de la semaine (WeeklyLeaderboard.StoreName : nouveau nom chaque semaine = remise à zéro), si
--     la valeur a changé.
--   - Lecture : toutes les ReadInterval s, le top 100 de la semaine (GetSortedAsync), fusionné avec les joueurs présents
--     (leur valeur du moment) ; attributs du Player WeeklyIncomeRank / WeeklyStealsRank (0 = hors du top 100) et
--     WeeklyBoardEndsAt (os.time de la remise à zéro). Panneaux du hub dont Stat = WeeklyIncome ou WeeklySteals :
--     remplis par LeaderboardService (AddBoard), facultatifs.
--   - Récompense (a430, L-325 réponse (3) de Clément : elle attend le joueur, jamais perdue) : chaque semaine finie où
--     le joueur a joué reste dans WeeklyBoard.Pending jusqu'à ce qu'elle soit réglée, même s'il revient des semaines
--     plus tard. Le top 100 de chaque semaine attendue (et toujours de la semaine précédente) est lu une fois par
--     serveur, relu tant que la lecture rate. Les semaines sont réglées de la plus ancienne à la plus récente ; pour
--     chacune, chaque classement dont WeeklyBoard.Rewarded[classement] est plus ancien donne le colis du rang
--     (WeeklyLeaderboard.Rewards, UnboxService.GiveZoneBoxItem, zone de référence = sa meilleure zone, comme les
--     paliers de temps de jeu) ; hors du top : rien, réglé aussi. Inventaire plein : rien n'est noté, un Notify par
--     session, nouvel essai à la lecture suivante ou à la prochaine connexion (la semaine reste dans Pending).
--   - Statues du n° 1 (a430, L-331) : à chaque lecture, le n° 1 de chaque classement est donné à
--     LeaderboardStatueService (avatar sur la statue, seulement quand il change).
--   - Protégé : chaque appel DataStore dans un pcall, budget vérifié ; Studio sans accès aux API : rien n'est lu ni
--     écrit (une ligne), le classement de la semaine montre les joueurs présents.
--
-- Crochet de test, STUDIO SEULEMENT, barre de commande serveur :
--   workspace:SetAttribute("WeeklyBoardTest", "Rollover")  -- avance l'horloge du service d'une semaine : la semaine en
--                                                          -- cours devient la précédente, récompenses tout de suite
--
-- API (serveur) :
--   WeeklyLeaderboardService.ValueOf(player, stat) -> number   valeur de la semaine (0 sans profil)
--   WeeklyLeaderboardService.Rows(stat) -> { Row }            lignes de la semaine (classement fusionné)
--   WeeklyLeaderboardService.Step(now)                        écrit, lit et récompense ce qui est dû (boucle, bancs)
--   WeeklyLeaderboardService.Now() -> number                  heure UTC du service (os.time + décalage du test)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Features = require(Shared.Config.Features)
local Items = require(Shared.Config.Items)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Weekly = require(Shared.Config.WeeklyLeaderboard)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)

local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local LeaderboardStatueService = require(script.Parent.LeaderboardStatueService)
local UnboxService = require(script.Parent.UnboxService)

type Row = LeaderboardService.Row
type Data = any

local INCOME_ATTRIBUTE = "Income" -- attribut du Player posé par DisplayService (comme LeaderboardService)
local TEST_ATTRIBUTE = "WeeklyBoardTest" -- Studio seulement
local IS_STUDIO = RunService:IsStudio()
local ENABLED: boolean = (Features :: any).WeeklyLeaderboards == true

local WeeklyLeaderboardService = {}
WeeklyLeaderboardService.Priority = 240 -- V0 : après LeaderboardService (100) et UnboxService

local stores: { [string]: any } = {} -- [nom] = OrderedDataStore
local written: { [number]: { [string]: string } } = {} -- [UserId][stat] = « semaine:valeur codée » écrite
local current: { [string]: { Week: number, Rows: { Row } } } = {} -- top lu de la semaine en cours
local ended: { [string]: { [number]: { [number]: number } } } = {} -- a430 : [classement][semaine finie] = { [UserId] = rang }, lu une fois
local fullSaid: { [Player]: boolean } = {}
local said: { [string]: boolean } = {}
local offset = 0 -- décalage de l'horloge (crochet de test, Studio)
local nextWrite = 0
local nextRead = 0

local function sayOnce(key: string, message: string)
	if not said[key] then
		said[key] = true
		if IS_STUDIO then
			print(`[WeeklyLeaderboardService] {message}`)
		else
			warn(`[WeeklyLeaderboardService] {message}`)
		end
	end
end

local function count(value: any): number
	return if type(value) == "number" and value == value and value > 0 and value < math.huge then value else 0
end

function WeeklyLeaderboardService.Now(): number
	return os.time() + offset
end

local function weekNow(): number
	return Weekly.WeekOf(WeeklyLeaderboardService.Now())
end

-- Compteurs de la semaine `week` du profil, créés, réparés et remis à zéro au changement de semaine. a430 (L-325 (3)) :
-- la semaine qui se ferme va dans Pending si le joueur y a un revenu ou un vol (elle attend sa récompense).
local function boardOf(data: Data, week: number): any
	local lifetime: any = if type(data.Lifetime) == "table" then data.Lifetime else {}
	local steals = count(lifetime.Steals)
	local board: any = data.WeeklyBoard
	if type(board) ~= "table" then
		board = { Week = 0, BestIncome = 0, StealsAt = steals, Rewarded = {}, Pending = {} }
		data.WeeklyBoard = board
	end
	if type(board.Rewarded) ~= "table" then
		board.Rewarded = {}
	end
	if type(board.Pending) ~= "table" then
		board.Pending = {}
	end
	board.BestIncome = count(board.BestIncome)
	board.StealsAt = math.min(count(board.StealsAt), steals)
	if board.Week ~= week then
		local old = board.Week
		local played = board.BestIncome > 0 or steals > board.StealsAt
		if type(old) == "number" and old >= 1 and old < week and played and table.find(board.Pending, old) == nil then
			table.insert(board.Pending, old)
		end
		board.Week = week
		board.BestIncome = 0
		board.StealsAt = steals
	end
	return board
end

function WeeklyLeaderboardService.ValueOf(player: Player, stat: string): number
	local data = DataService.Get(player)
	if data == nil then
		return 0
	end
	local board = boardOf(data, weekNow())
	if stat == "WeeklyIncome" then
		local ok, income = pcall(LeaderboardService.RecordIncome, player)
		if ok and type(income) == "number" and income > board.BestIncome and income < math.huge then
			board.BestIncome = income
		end
		return board.BestIncome
	elseif stat == "WeeklySteals" then
		local lifetime: any = if type((data :: any).Lifetime) == "table" then (data :: any).Lifetime else {}
		return count(lifetime.Steals) - board.StealsAt -- a430 (L-325 (1)) : vols chez un autre joueur seulement
	end
	return 0
end

local function isDev(): boolean
	local ok, name = pcall(DataService.GetStoreName)
	return ok and name ~= Balance.Profiles.StoreName
end

local function storeOf(stat: string, week: number): any
	local name = Weekly.StoreName(stat, isDev(), week)
	if name == nil then
		return nil
	end
	local existing = stores[name]
	if existing ~= nil then
		return existing
	end
	local ok, result = pcall(function(): any
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if not ok or result == nil then
		sayOnce(`open:{stat}`, `OrderedDataStore « {name} » indisponible ({tostring(result)}) : classement de la semaine des joueurs présents seulement`)
		return nil
	end
	stores[name] = result
	return result
end

local function budgetOk(kind: Enum.DataStoreRequestType): boolean
	local ok, budget = pcall(function(): number
		return DataStoreService:GetRequestBudgetForRequestType(kind)
	end)
	return not ok or budget >= Weekly.MinBudget
end

local function valuesOf(player: Player): { [string]: number }
	local values: { [string]: number } = {}
	for _, stat in Weekly.Order do
		values[stat] = Weekly.Encode(stat, WeeklyLeaderboardService.ValueOf(player, stat))
	end
	return values
end

local function writePlayer(userId: number, week: number, values: { [string]: number })
	for stat, encoded in values do
		local key = `{week}:{encoded}`
		local mine = written[userId]
		if encoded <= 0 or (mine and mine[stat] == key) then
			continue
		end
		local store = storeOf(stat, week)
		if store == nil then
			continue
		end
		if not budgetOk(Enum.DataStoreRequestType.SetIncrementSortedAsync) then
			sayOnce("budget:write", "budget DataStore trop bas : écriture du classement de la semaine repoussée")
			continue
		end
		local ok, problem = pcall(function()
			store:SetAsync(tostring(userId), encoded)
		end)
		if ok then
			local entry = written[userId] or {}
			entry[stat] = key
			written[userId] = entry
		else
			sayOnce(`write:{stat}`, `écriture du classement {stat} ratée ({tostring(problem)})`)
		end
	end
end

-- Top lu d'une semaine (liste triée, valeurs décodées), ou nil si la lecture rate.
local function readTop(stat: string, week: number): { { UserId: number, Value: number } }?
	local store = storeOf(stat, week)
	if store == nil then
		return nil
	end
	if not budgetOk(Enum.DataStoreRequestType.GetSortedAsync) then
		sayOnce("budget:read", "budget DataStore trop bas : lecture du classement de la semaine repoussée")
		return nil
	end
	local ok, result = pcall(function(): any
		return store:GetSortedAsync(false, Weekly.Top):GetCurrentPage()
	end)
	if not ok or type(result) ~= "table" then
		sayOnce(`read:{stat}`, `lecture du classement {stat} (semaine {week}) ratée ({tostring(result)})`)
		return nil
	end
	local list: { { UserId: number, Value: number } } = {}
	for _, item in result do
		local userId = tonumber(item.key)
		local value = Weekly.Decode(stat, item.value)
		if userId and userId > 0 and value > 0 then
			table.insert(list, { UserId = userId, Value = value })
		end
	end
	table.sort(list, function(a: { UserId: number, Value: number }, b: { UserId: number, Value: number }): boolean
		if a.Value ~= b.Value then
			return a.Value > b.Value
		end
		return a.UserId < b.UserId
	end)
	return list
end

function WeeklyLeaderboardService.Rows(stat: string): { Row }
	local week = weekNow()
	local best: { [number]: number } = {}
	local read = current[stat]
	if read and read.Week == week then
		for _, row in read.Rows do
			best[row.UserId] = math.max(best[row.UserId] or 0, row.Value)
		end
	end
	for _, player in Players:GetPlayers() do
		local value = WeeklyLeaderboardService.ValueOf(player, stat)
		if value > 0 then
			best[player.UserId] = math.max(best[player.UserId] or 0, value)
		end
	end
	local rows: { Row } = {}
	for userId, value in best do
		table.insert(rows, { UserId = userId, Value = value, Rank = 0 })
	end
	table.sort(rows, function(a: Row, b: Row): boolean
		if a.Value ~= b.Value then
			return a.Value > b.Value
		end
		return a.UserId < b.UserId
	end)
	while #rows > Weekly.Top do
		table.remove(rows)
	end
	for index, row in rows do
		row.Rank = index
	end
	return rows
end

-- Meilleure zone parmi les objets du joueur (zone 1 sans objet) : la même règle que RewardService (paliers de temps de jeu).
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

local function notify(player: Player, message: string, kind: string)
	pcall(function()
		Net.Server.Notify:Fire(player, message, kind)
	end)
end

local function grantAura(player: Player, rank: number)
	local auraId = Weekly.AuraId
	if auraId == nil or rank > Weekly.AuraMaxRank then
		return
	end
	local ok, problem = pcall(function()
		local Cosmetic = require(script.Parent.CosmeticService) :: any
		Cosmetic.Grant(player, auraId)
	end)
	if not ok then
		sayOnce("aura", `aura du classement {auraId} pas donnée ({tostring(problem)})`)
	end
end

-- Règle le classement `stat` de la semaine finie `w` pour `player` (voir l'en-tête). Renvoie true si c'est réglé
-- (colis donné, hors du top, ou déjà fait), false s'il faut réessayer (top pas encore lu, inventaire plein). Sans yield.
local function settle(player: Player, data: Data, board: any, stat: string, w: number): boolean
	local before = board.Rewarded[stat]
	local done = if type(before) == "number" then before else 0
	if done >= w then
		return true
	end
	local byWeek = ended[stat]
	local ranks = if byWeek then byWeek[w] else nil
	if ranks == nil then
		return false -- top de cette semaine pas encore lu : à la prochaine lecture
	end
	local rank = ranks[player.UserId]
	local tier = if rank then Weekly.RewardFor(rank) else nil
	board.Rewarded[stat] = w -- noté avant le don : jamais deux fois (une erreur pendant le don le perd)
	if tier == nil or rank == nil then
		return true
	end
	local ok, itemUid, reason, itemId = pcall(function(): (string?, string?, string?)
		local uid, why, id = UnboxService.GiveZoneBoxItem(player, tier.Rule, bestZone(data))
		return uid, why, id
	end)
	if ok and itemUid == nil and reason == "InventoryFull" then
		board.Rewarded[stat] = before -- rien de donné : nouvel essai à la prochaine lecture ou connexion
		if not fullSaid[player] then
			fullSaid[player] = true
			notify(player, Weekly.Messages.Full, "Warning")
		end
		return false
	end
	if not ok or itemUid == nil or itemId == nil then
		sayOnce(`give:{stat}:{tostring(reason)}`, `récompense {stat} de {player.Name} (#{rank}) pas donnée ({tostring(if ok then reason else itemUid)})`)
		return true
	end
	local def = Items.ById[itemId]
	local entry = (data :: any).Items[itemUid]
	local rarity = if def then Rarities.ById[def.Rarity] else nil
	local name = if def then Mutations.ItemName(def.DisplayName, if entry then entry.Mutation else nil) else tostring(itemId)
	local boardName = (Weekly.BoardNames :: any)[stat] or stat
	notify(player, string.format(Weekly.Messages.Reward, boardName, rank, tier.Label, if rarity then rarity.DisplayName else "", name), "Success")
	grantAura(player, rank)
	print(`[WeeklyLeaderboardService] {player.Name} : #{rank} {stat} semaine {w} : {tier.Label}, {itemId}`)
	return true
end

-- Récompenses des semaines finies qui attendent `player` (WeeklyBoard.Pending), de la plus ancienne à la plus récente ;
-- une semaine sort de Pending quand ses deux classements sont réglés (a430, L-325 (3) : jamais perdue). Sans yield.
local function rewardPlayer(player: Player)
	local data = DataService.Get(player)
	if data == nil or type((data :: any).Items) ~= "table" then
		return
	end
	local board = boardOf(data, weekNow())
	local pending: { any } = board.Pending
	for index = #pending, 1, -1 do
		if type(pending[index]) ~= "number" then
			table.remove(pending, index) -- réparé : une entrée illisible
		end
	end
	table.sort(pending)
	while #pending > 0 do
		local w: number = pending[1]
		local settled = true
		for _, stat in Weekly.Order do
			if not settle(player, data, board, stat, w) then
				settled = false
			end
		end
		if not settled then
			break -- l'ordre des semaines est gardé : les suivantes attendent celle-ci
		end
		table.remove(pending, 1)
	end
end

local function writeAll(week: number)
	for _, player in Players:GetPlayers() do
		if DataService.Get(player) ~= nil then
			writePlayer(player.UserId, week, valuesOf(player))
		end
	end
end

-- Top d'une semaine finie, lu une fois par serveur (relu tant que la lecture rate).
local function readEnded(stat: string, w: number)
	local byWeek = ended[stat]
	if byWeek == nil then
		byWeek = {}
		ended[stat] = byWeek
	end
	if byWeek[w] ~= nil then
		return
	end
	local list = readTop(stat, w)
	if list then
		local ranks: { [number]: number } = {}
		for index, item in list do
			ranks[item.UserId] = index
		end
		byWeek[w] = ranks
	end
end

local function readAll(week: number)
	-- Semaines finies à lire : la précédente (pour qui arrive), et chaque semaine qui attend un joueur présent.
	local wanted: { [number]: boolean } = { [week - 1] = true }
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data ~= nil then
			for _, w in boardOf(data, week).Pending do
				if type(w) == "number" and w < week then
					wanted[w] = true
				end
			end
		end
	end
	for _, stat in Weekly.Order do
		local list = readTop(stat, week)
		if list then
			local rows: { Row } = {}
			for index, item in list do
				table.insert(rows, { UserId = item.UserId, Value = item.Value, Rank = index })
			end
			current[stat] = { Week = week, Rows = rows }
		end
		for w in wanted do
			readEnded(stat, w)
		end
	end
	local endsAt = Weekly.WeekStart(week + 1)
	local ranks: { [string]: { [number]: number } } = {}
	for _, stat in Weekly.Order do
		local map: { [number]: number } = {}
		local rows = WeeklyLeaderboardService.Rows(stat)
		for _, row in rows do
			map[row.UserId] = row.Rank
		end
		ranks[stat] = map
		local first = rows[1]
		local shown, problem = pcall(function() -- a430 (L-331) : statue du n° 1
			LeaderboardStatueService.Show(stat, if first then first.UserId else 0)
		end)
		if not shown then
			sayOnce(`statue:{stat}`, `statue du n° 1 {stat} : {tostring(problem)}`)
		end
	end
	for _, player in Players:GetPlayers() do
		if DataService.Get(player) ~= nil then
			player:SetAttribute(Weekly.WeekEndsAttribute, endsAt)
			for _, stat in Weekly.Order do
				player:SetAttribute(Weekly.Stats[stat].RankAttribute, ranks[stat][player.UserId] or 0)
			end
			rewardPlayer(player)
		end
	end
end

function WeeklyLeaderboardService.Step(now: number)
	if not ENABLED then
		return
	end
	local week = weekNow()
	if now >= nextWrite then
		nextWrite = now + Weekly.WriteInterval
		writeAll(week)
	end
	if now >= nextRead then
		nextRead = now + Weekly.ReadInterval
		readAll(week)
	end
end

local function valueText(stat: string): (number) -> string
	return function(value: number): string
		if stat == "WeeklyIncome" then
			return Format.money(value) .. "/s"
		end
		return Format.short(value)
	end
end

function WeeklyLeaderboardService.Init()
	if not ENABLED then
		return
	end
	for _, stat in Weekly.Order do
		LeaderboardService.AddBoard(stat, {
			Title = Weekly.Stats[stat].Title,
			Rows = function(): { Row }
				return WeeklyLeaderboardService.Rows(stat)
			end,
			Text = valueText(stat),
			MaxRows = Weekly.Top,
		})
	end
	DataService.OnProfileLoaded(function(player: Player)
		WeeklyLeaderboardService.ValueOf(player, "WeeklyIncome")
		player:GetAttributeChangedSignal(INCOME_ATTRIBUTE):Connect(function()
			WeeklyLeaderboardService.ValueOf(player, "WeeklyIncome")
		end)
		player:SetAttribute(Weekly.WeekEndsAttribute, Weekly.WeekStart(weekNow() + 1))
		rewardPlayer(player) -- top de la semaine finie déjà lu : tout de suite ; sinon à la prochaine lecture
	end)
	DataService.OnProfileReleasing(function(player: Player)
		-- Pas de yield ici : valeurs lues maintenant, écrites en tâche de fond.
		local userId, week, values = player.UserId, weekNow(), valuesOf(player)
		fullSaid[player] = nil
		task.spawn(function()
			writePlayer(userId, week, values)
			written[userId] = nil
		end)
	end)
end

function WeeklyLeaderboardService.Start()
	if not ENABLED then
		print("[WeeklyLeaderboardService] classements hebdomadaires coupés (Features.WeeklyLeaderboards = false)")
		return
	end
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(TEST_ATTRIBUTE):Connect(function()
			local value = Workspace:GetAttribute(TEST_ATTRIBUTE)
			if value == nil then
				return
			end
			Workspace:SetAttribute(TEST_ATTRIBUTE, nil)
			if value == "Rollover" then
				offset += 7 * Weekly.DayLength
				nextWrite, nextRead = 0, 0
				print(`[WeeklyLeaderboardService] test : horloge avancée d'une semaine (semaine {weekNow()})`)
			end
		end)
	end
	local start = os.clock()
	nextWrite = start + Weekly.FirstReadDelay
	nextRead = start + Weekly.FirstReadDelay + 2 -- après la première écriture
	print(`[WeeklyLeaderboardService] classements de la semaine {weekNow()} : top {Weekly.Top} en $/s et en vols, remise à zéro le lundi 00:00 UTC`)
	while true do
		local ok, problem = pcall(function()
			WeeklyLeaderboardService.Step(os.clock())
		end)
		if not ok then
			sayOnce(`step:{tostring(problem)}`, tostring(problem))
		end
		task.wait(1)
	end
end

return WeeklyLeaderboardService
