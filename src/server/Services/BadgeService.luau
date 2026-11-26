--!strict
-- BadgeService (vague GC7, a413, 23/11) : donne les badges du jeu (Config/Badges) au bon moment, une seule fois.
-- Interrupteur : Features.Badges (false : rien n'est relevé ni demandé à Roblox).
--
-- Relevé : à l'arrivée du profil (DataService.OnProfileLoaded) puis toutes les Badges.CheckInterval s, pour chaque
-- joueur présent, chaque badge dont l'Id de ce jeu n'est pas 0 est comparé à son profil (BadgeService.Earned). Le
-- profil est la vérité : un badge manqué (Roblox en panne, badge créé plus tard) est rattrapé au relevé suivant ou à
-- la session suivante, et un joueur qui avait gagné la condition avant la création du badge le reçoit à son retour.
--
-- Don : condition vraie → UserHasBadgeAsync (déjà possédé : noté, plus rien), sinon AwardBadge. Réponse gardée en
-- cache pour la session (un badge noté n'est plus jamais demandé à Roblox). Un appel à la fois par joueur et par
-- badge, dans sa propre tâche (le relevé n'attend jamais). Erreur de Roblox (réseau, limite de requêtes, Studio) :
-- rattrapée par pcall, nouvel essai après Badges.RetryDelay s, abandon pour la session après Badges.MaxTries essais
-- ratés (un avertissement). AwardBadge qui répond false (badge désactivé, ou pas de ce jeu) : un avertissement,
-- plus d'essai dans la session. Jamais d'erreur, rien d'autre n'attend ce service.
--
-- API (serveur) :
--   BadgeService.Earned(data, badge) -> boolean     la condition du badge est-elle vraie dans ce profil ? (pur)
--   BadgeService.IdOf(badge) -> number              Id du badge dans ce jeu (DevId en DEV, Id ailleurs), 0 = sauté
--   BadgeService.Check(player)                      relève ce joueur tout de suite (sans yield)
--   BadgeService.HasNoted(player, key) -> boolean   badge vu possédé ou donné pendant cette session

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RobloxBadges = game:GetService("BadgeService")

local Shared = ReplicatedStorage.Shared
local Badges = require(Shared.Config.Badges)
local Features = require(Shared.Config.Features)
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local ProfileTypes = require(Shared.Types.Profile)

local DataService = require(script.Parent.DataService)

type Data = ProfileTypes.Data
type Badge = Badges.Badge

-- Config/ProductIds chargé s'il est là (comme TrapService) ; sans lui, jeu PROD.
local ProductIds: { IsDev: boolean?, IsTest: boolean? } = (function(): any
	local module = Shared.Config:FindFirstChild("ProductIds")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end)()

type State = {
	noted: { [string]: boolean }, -- badge possédé ou donné : plus rien à faire dans la session
	busy: { [string]: boolean }, -- appel à Roblox en cours
	tries: { [string]: number }, -- essais ratés
	retryAt: { [string]: number }, -- os.clock() avant lequel on ne réessaie pas
}

local IS_STUDIO = RunService:IsStudio()

local BadgeService = {}
BadgeService.Priority = 320 -- V0 : après les services qui écrivent le profil (RebirthService 300)

local enabled = false
local states: { [Player]: State } = {}
local exclusive: { [string]: boolean } = {}
for _, item in Items.Exclusives do
	exclusive[item.Id] = true
end

local function log(message: string)
	if IS_STUDIO then
		print(`[BadgeService] {message}`)
	end
end

local function number(value: any): number
	if type(value) == "number" and value == value then
		return value
	end
	return 0
end

-- L'Index du profil a-t-il un objet (hors exclusifs) qui vérifie `test` ?
local function indexHas(data: Data, test: (item: any) -> boolean): boolean
	local index: any = (data :: any).Index
	if type(index) ~= "table" then
		return false
	end
	for itemId in index do
		if type(itemId) == "string" and not exclusive[itemId] then
			local item = Items.ById[itemId]
			if item and test(item) then
				return true
			end
		end
	end
	return false
end

function BadgeService.Earned(data: Data, badge: Badge): boolean
	local raw: any = data
	local lifetime: any = if type(raw.Lifetime) == "table" then raw.Lifetime else {}
	local min = badge.Min or 1
	local rule = badge.Rule
	if rule == "Join" then
		return true
	elseif rule == "Heists" then
		return number(lifetime.Heists) >= min
	elseif rule == "Steals" then
		return number(lifetime.Steals) >= min
	elseif rule == "Rebirths" then
		return number(raw.Rebirths) >= min
	elseif rule == "BestIncome" then
		return number(lifetime.BestIncome) >= min
	elseif rule == "Rarity" then
		local wanted = Rarities.ById[badge.Rarity or ""]
		if wanted == nil then
			return false
		end
		return indexHas(data, function(item: any): boolean
			local rarity = Rarities.ById[item.Rarity]
			return rarity ~= nil and rarity.Order >= wanted.Order
		end)
	elseif rule == "ZoneItem" then
		local zone = badge.Zone
		return zone ~= nil and indexHas(data, function(item: any): boolean
			return item.Zone == zone
		end)
	end
	return false
end

function BadgeService.IdOf(badge: Badge): number
	if ProductIds.IsTest == true then
		return 0 -- a500 : jeu TEST, aucun badge (ni Id DEV ni Id PROD n'y existe) : aucun appel d'attribution
	end
	local id = if ProductIds.IsDev == true then badge.DevId else badge.Id
	return if type(id) == "number" and id > 0 then id else 0
end

local function stateOf(player: Player): State
	local state = states[player]
	if state == nil then
		state = { noted = {}, busy = {}, tries = {}, retryAt = {} }
		states[player] = state
	end
	return state
end

local function failed(player: Player, state: State, badge: Badge, err: any)
	local tries = (state.tries[badge.Key] or 0) + 1
	state.tries[badge.Key] = tries
	state.retryAt[badge.Key] = os.clock() + Badges.RetryDelay
	if tries >= Badges.MaxTries then
		warn(`[BadgeService] {badge.Key} pour {player.Name} : abandon pour la session après {tries} essais ({tostring(err)})`)
	else
		log(`{badge.Key} pour {player.Name} : essai {tries} raté ({tostring(err)}), nouvel essai dans {Badges.RetryDelay} s`)
	end
end

-- Dans sa propre tâche : peut attendre Roblox.
local function award(player: Player, state: State, badge: Badge, id: number)
	local ok, has = pcall(function(): boolean
		return RobloxBadges:UserHasBadgeAsync(player.UserId, id)
	end)
	if not ok then
		failed(player, state, badge, has)
	elseif has then
		state.noted[badge.Key] = true
		log(`{badge.Key} : déjà possédé par {player.Name}`)
	elseif player.Parent == Players then
		local done, awarded = pcall(function(): boolean
			return RobloxBadges:AwardBadge(player.UserId, id)
		end)
		if not done then
			failed(player, state, badge, awarded)
		elseif awarded then
			state.noted[badge.Key] = true
			log(`{badge.Key} donné à {player.Name}`)
		else
			state.noted[badge.Key] = true -- refus net de Roblox : plus d'essai dans la session
			warn(`[BadgeService] {badge.Key} (Id {id}) refusé par Roblox pour {player.Name} : badge désactivé ou d'un autre jeu ?`)
		end
	end
	state.busy[badge.Key] = nil
end

function BadgeService.Check(player: Player)
	if not enabled or states[player] == nil then
		return
	end
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local state = stateOf(player)
	local now = os.clock()
	for _, badge in Badges.List do
		local key = badge.Key
		local id = BadgeService.IdOf(badge)
		if
			id > 0
			and not state.noted[key]
			and not state.busy[key]
			and (state.tries[key] or 0) < Badges.MaxTries
			and now >= (state.retryAt[key] or 0)
			and BadgeService.Earned(data, badge)
		then
			state.busy[key] = true
			task.spawn(award, player, state, badge, id)
		end
	end
end

function BadgeService.HasNoted(player: Player, key: string): boolean
	local state = states[player]
	return state ~= nil and state.noted[key] == true
end

function BadgeService.Start()
	enabled = Features.Badges == true
	if not enabled then
		log("Features.Badges coupé : aucun badge")
		return
	end
	local active = 0
	for _, badge in Badges.List do
		if BadgeService.IdOf(badge) > 0 then
			active += 1
		end
	end
	log(`{active} badge(s) sur {#Badges.List} avec un Id dans ce jeu`)
	if active == 0 then
		return -- tous à 0 : rien à relever (les Id se lisent au démarrage du serveur)
	end

	DataService.OnProfileLoaded(function(player: Player)
		stateOf(player)
		BadgeService.Check(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if DataService.Get(player) ~= nil then
			stateOf(player)
		end
	end
	task.spawn(function()
		while true do
			task.wait(Badges.CheckInterval)
			for player in states do
				BadgeService.Check(player)
			end
		end
	end)
end

return BadgeService
