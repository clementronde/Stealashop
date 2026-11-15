--!strict
-- LeaderboardService (vague 50, a161 ; L-165 point 4) : les deux grands panneaux du hub, « Most money/s »
-- (meilleur revenu par seconde de tous les temps) et « Fastest » (Vitesse entraînée, Stats.Speed).
-- Valeurs : Config/Leaderboard (V0). Aucun remote : tout est écrit par le serveur dans les SurfaceGui des
-- panneaux, répliqués à tous les clients.
--
--   - Meilleur revenu : Lifetime.BestIncome du profil (champ nouveau, 0 par défaut ; absent = 0), monté à
--     chaque changement de l'attribut Income du Player (revenu par seconde affiché, posé par DisplayService :
--     revenu exposé × multiplicateurs du moment).
--   - Écriture : toutes les WriteInterval s, pour chaque joueur du serveur et chaque stat, SetAsync(UserId,
--     valeur codée) dans l'OrderedDataStore de la stat (Config/Leaderboard.StoreName, suffixe DEV dans le
--     jeu DEV comme les profils) si la valeur a changé depuis la dernière écriture réussie ; aussi au départ.
--   - Lecture : toutes les ReadInterval s, GetSortedAsync(false, Rows) par stat.
--   - Affichage : les lignes lues, fusionnées avec les joueurs présents (leur valeur du moment, pour qu'un
--     record se voie avant la prochaine lecture), triées, Rows au plus. Chaque panneau (tag Leaderboard,
--     attribut Stat = Income ou Speed) : Board.Title = titre de la stat, une copie visible de List.Template
--     par ligne (Row_01…) avec Rank (« #1 »), Avatar (GetUserThumbnailAsync, HeadShot ; repli rbxthumb://),
--     PlayerName (nom du joueur, GetNameFromUserIdAsync pour un absent, en cache), Value ($/s ou Speed).
--   - Protégé : chaque appel DataStore ou web dans un pcall ; budget de requêtes vérifié avant (MinBudget) ;
--     Studio sans accès aux API : écritures et lectures ratées (une ligne en Studio), le panneau montre les
--     joueurs présents. Panneau sans Board, List ou Template, ou Stat inconnue : ignoré (une ligne).
--
-- API (serveur) :
--   LeaderboardService.ValueOf(player, stat) -> number   valeur du joueur (0 sans profil)
--   LeaderboardService.TrackBest(player)                  monte Lifetime.BestIncome au revenu du moment
--   LeaderboardService.Rows(stat) -> { Row }              lignes affichées (banc, barre de commande)
--   LeaderboardService.Step(now)                          écrit, lit et affiche ce qui est dû (boucle, bancs)

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Leaderboard = require(ReplicatedStorage.Shared.Config.Leaderboard)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)

export type Row = { UserId: number, Value: number, Rank: number }

type Entry = { UserId: number, Value: number }

local INCOME_ATTRIBUTE = "Income" -- attribut du Player posé par DisplayService
local ROW_ATTRIBUTE = "LeaderboardRow" -- V0 : marque les copies de Template posées ici

local LeaderboardService = {}

local stores: { [string]: any } = {} -- [stat] = OrderedDataStore, ou absent
local written: { [number]: { [string]: number } } = {} -- [UserId][stat] = dernière valeur codée écrite
local stored: { [string]: { Entry } } = {} -- [stat] = lignes lues
local names: { [number]: string } = {}
local thumbs: { [number]: string } = {}
local said: { [string]: boolean } = {}
local nextWrite = 0 -- Start les repousse à FirstReadDelay
local nextRead = 0

local function sayOnce(key: string, message: string)
	if not said[key] then
		said[key] = true
		if RunService:IsStudio() then
			print(`[LeaderboardService] {message}`)
		else
			warn(`[LeaderboardService] {message}`)
		end
	end
end

local function finite(value: any): number
	return if type(value) == "number" and value == value and value > -math.huge and value < math.huge and value > 0 then value else 0
end

function LeaderboardService.TrackBest(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local lifetime: any = data.Lifetime
	if type(lifetime) ~= "table" then
		return
	end
	local income = finite(player:GetAttribute(INCOME_ATTRIBUTE))
	local best = finite(lifetime.BestIncome)
	if income > best then
		lifetime.BestIncome = income
	elseif lifetime.BestIncome ~= nil and lifetime.BestIncome ~= best then
		lifetime.BestIncome = best -- illisible : repart de 0
	end
end

function LeaderboardService.ValueOf(player: Player, stat: string): number
	local data = DataService.Get(player)
	if data == nil then
		return 0
	end
	if stat == "Income" then
		local lifetime: any = data.Lifetime
		local best = if type(lifetime) == "table" then finite(lifetime.BestIncome) else 0
		return math.max(best, finite(player:GetAttribute(INCOME_ATTRIBUTE)))
	elseif stat == "Speed" then
		local stats: any = data.Stats
		return if type(stats) == "table" then finite(stats.Speed) else 0
	end
	return 0
end

local function isDev(): boolean
	local ok, name = pcall(DataService.GetStoreName)
	return ok and name ~= Balance.Profiles.StoreName
end

local function storeOf(stat: string): any
	local existing = stores[stat]
	if existing ~= nil then
		return existing
	end
	local name = Leaderboard.StoreName(stat, isDev())
	if name == nil then
		return nil
	end
	local ok, result = pcall(function(): any
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if not ok or result == nil then
		sayOnce(`open:{stat}`, `OrderedDataStore « {name} » indisponible ({tostring(result)}) : panneau des joueurs présents seulement`)
		return nil
	end
	stores[stat] = result
	return result
end

local function budgetOk(kind: Enum.DataStoreRequestType): boolean
	local ok, budget = pcall(function(): number
		return DataStoreService:GetRequestBudgetForRequestType(kind)
	end)
	return not ok or budget >= Leaderboard.MinBudget
end

local function writePlayer(userId: number, values: { [string]: number })
	for stat, encoded in values do
		local mine = written[userId]
		if encoded <= 0 or (mine and mine[stat] == encoded) then
			continue
		end
		local store = storeOf(stat)
		if store == nil then
			continue
		end
		if not budgetOk(Enum.DataStoreRequestType.SetIncrementSortedAsync) then
			sayOnce("budget:write", "budget DataStore trop bas : écriture du classement repoussée")
			continue
		end
		local ok, problem = pcall(function()
			store:SetAsync(tostring(userId), encoded)
		end)
		if ok then
			local entry = written[userId] or {}
			entry[stat] = encoded
			written[userId] = entry
		else
			sayOnce(`write:{stat}`, `écriture du classement {stat} ratée ({tostring(problem)})`)
		end
	end
end

local function valuesOf(player: Player): { [string]: number }
	local values: { [string]: number } = {}
	for stat in Leaderboard.Stats do
		values[stat] = Leaderboard.Encode(stat, LeaderboardService.ValueOf(player, stat))
	end
	return values
end

local function writeAll()
	for _, player in Players:GetPlayers() do
		if DataService.Get(player) ~= nil then
			LeaderboardService.TrackBest(player)
			writePlayer(player.UserId, valuesOf(player))
		end
	end
end

local function readAll()
	for stat in Leaderboard.Stats do
		local store = storeOf(stat)
		if store == nil then
			continue
		end
		if not budgetOk(Enum.DataStoreRequestType.GetSortedAsync) then
			sayOnce("budget:read", "budget DataStore trop bas : lecture du classement repoussée")
			continue
		end
		local ok, result = pcall(function(): any
			local pages = store:GetSortedAsync(false, Leaderboard.Rows)
			return pages:GetCurrentPage()
		end)
		if not ok or type(result) ~= "table" then
			sayOnce(`read:{stat}`, `lecture du classement {stat} ratée ({tostring(result)})`)
			continue
		end
		local list: { Entry } = {}
		for _, item in result do
			local userId = tonumber(item.key)
			local value = Leaderboard.Decode(stat, item.value)
			if userId and userId > 0 and value > 0 then
				table.insert(list, { UserId = userId, Value = value })
			end
		end
		stored[stat] = list
	end
end

function LeaderboardService.Rows(stat: string): { Row }
	local best: { [number]: number } = {}
	local list: { Entry } = stored[stat] or {}
	for _, entry in list do
		best[entry.UserId] = math.max(best[entry.UserId] or 0, entry.Value)
	end
	for _, player in Players:GetPlayers() do
		local value = LeaderboardService.ValueOf(player, stat)
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
	while #rows > Leaderboard.Rows do
		table.remove(rows)
	end
	for index, row in rows do
		row.Rank = index
	end
	return rows
end

local function nameOf(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.Name
		return player.Name
	end
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, result = pcall(function(): string
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok and type(result) == "string" then result else "?"
	if ok then
		names[userId] = name
	end
	return name
end

local function thumbOf(userId: number): string
	local cached = thumbs[userId]
	if cached then
		return cached
	end
	local ok, result = pcall(function(): string
		local size = (Enum.ThumbnailSize :: any)[Leaderboard.ThumbnailSize]
		local image = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, size)
		return image
	end)
	if ok and type(result) == "string" and result ~= "" then
		thumbs[userId] = result
		return result
	end
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

local function valueText(stat: string, value: number): string
	if stat == "Income" then
		return Format.money(value) .. "/s"
	end
	return Format.short(value)
end

local function setText(row: Instance, name: string, text: string)
	local label = row:FindFirstChild(name, true)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
		(label :: any).Text = text
	end
end

local function renderBoard(board: Instance)
	local stat = board:GetAttribute(Leaderboard.StatAttribute)
	local spec = if type(stat) == "string" then Leaderboard.Stats[stat] else nil
	if spec == nil then
		sayOnce(`stat:{board:GetFullName()}`, `{board:GetFullName()} : attribut {Leaderboard.StatAttribute} absent ou inconnu ({tostring(stat)}), panneau ignoré`)
		return
	end
	local gui = board:FindFirstChild(Leaderboard.Gui, true)
	local list = if gui then gui:FindFirstChild(Leaderboard.List, true) else nil
	local template = if list then list:FindFirstChild(Leaderboard.Template) else nil
	if gui == nil or list == nil or template == nil or not template:IsA("GuiObject") then
		sayOnce(`parts:{board:GetFullName()}`, `{board:GetFullName()} : {Leaderboard.Gui}, {Leaderboard.List} ou {Leaderboard.List}.{Leaderboard.Template} introuvable, panneau ignoré`)
		return
	end
	setText(gui, Leaderboard.TitleLabel, spec.Title)
	local base = template :: GuiObject
	base.Visible = false
	for _, child in list:GetChildren() do
		if child:GetAttribute(ROW_ATTRIBUTE) == true then
			child:Destroy()
		end
	end
	for _, row in LeaderboardService.Rows(stat :: string) do
		local copy = base:Clone()
		copy.Name = string.format(Leaderboard.RowName, row.Rank)
		copy.LayoutOrder = row.Rank
		copy:SetAttribute(ROW_ATTRIBUTE, true)
		setText(copy, "Rank", `#{row.Rank}`)
		setText(copy, "PlayerName", nameOf(row.UserId))
		setText(copy, "Value", valueText(stat :: string, row.Value))
		local avatar = copy:FindFirstChild("Avatar", true)
		if avatar and (avatar:IsA("ImageLabel") or avatar:IsA("ImageButton")) then
			(avatar :: any).Image = thumbOf(row.UserId)
		end
		copy.Visible = true
		copy.Parent = list
	end
end

local function renderAll()
	for _, board in CollectionService:GetTagged(Leaderboard.Tag) do
		local ok, problem = pcall(function()
			renderBoard(board)
		end)
		if not ok then
			sayOnce(`render:{board:GetFullName()}`, `{board:GetFullName()} : {tostring(problem)}`)
		end
	end
end

function LeaderboardService.Step(now: number)
	if now >= nextWrite then
		nextWrite = now + Leaderboard.WriteInterval
		writeAll()
	end
	if now >= nextRead then
		nextRead = now + Leaderboard.ReadInterval
		readAll()
		renderAll()
	end
end

function LeaderboardService.Init()
	DataService.OnProfileLoaded(function(player: Player)
		LeaderboardService.TrackBest(player)
		player:GetAttributeChangedSignal(INCOME_ATTRIBUTE):Connect(function()
			LeaderboardService.TrackBest(player)
		end)
	end)
	DataService.OnProfileReleasing(function(player: Player)
		-- Pas de yield ici : valeurs lues maintenant, écrites en tâche de fond.
		LeaderboardService.TrackBest(player)
		local userId = player.UserId
		local values = valuesOf(player)
		task.spawn(function()
			writePlayer(userId, values)
			written[userId] = nil
		end)
	end)
	CollectionService:GetInstanceAddedSignal(Leaderboard.Tag):Connect(function(board: Instance)
		task.spawn(renderBoard, board)
	end)
end

function LeaderboardService.Start()
	local start = os.clock()
	nextWrite = start + Leaderboard.FirstReadDelay
	nextRead = start + Leaderboard.FirstReadDelay
	while true do
		local ok, problem = pcall(function()
			LeaderboardService.Step(os.clock())
		end)
		if not ok then
			sayOnce(`step:{tostring(problem)}`, tostring(problem))
		end
		task.wait(1)
	end
end

return LeaderboardService
