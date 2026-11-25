--!strict
-- NotificationService (MAJ 7, vague GC6, a410) : notifications Roblox hors du jeu (Experience Notifications).
-- Réglages, textes à créer dans le Creator Hub et limites de Roblox : Config/Notifications. Client (consentement,
-- fenêtre au premier plan) : NotificationController. Coupé par Features.ExperienceNotifications.
--
-- Trois moments (V0, Cantin 23/11) ; un moment dont MessageId est vide est coupé :
--   - OfflineFull : au départ du joueur, si sa boutique rapporte (Offline.Income du profil > 0), planifié à
--     départ + Offline.MaxHours h (gains hors ligne au plafond) ; {amount} = ce qui attendra (Format.money) ;
--   - SaturdayEvent : au départ, planifié LeadSeconds avant le prochain rendez-vous de LiveEvents.Weekly ;
--     {event} = nom du format (« ADMIN ABUSE ») ;
--   - ShopStolen : tout de suite, quand un objet est volé dans la boutique d'un joueur dont la fenêtre du jeu n'est
--     pas au premier plan (remote ReportFocus du client), au plus une fois par StolenCooldown s ; {item} = son nom.
-- Le retour du joueur (PlayerAdded, n'importe quel serveur) retire ses notifications planifiées.
--
-- File partagée (MemoryStoreService, carte triée MapName) : clé « <moment>:<userId> », valeur { u, m, p } (UserId,
-- moment, paramètres), sortKey = heure d'envoi. Chaque serveur relit toutes les PollInterval s les lignes dues ;
-- une ligne est prise par UpdateAsync (champ c = JobId, sortée hors de la plage, expire après ClaimSeconds) :
-- un seul serveur l'envoie. Une erreur de MemoryStore ou de HTTP n'arrête rien : avertissement, notification perdue.
--
-- Sécurité : le seul remote, ReportFocus(focused), ne fait que choisir si le vol d'un objet de ce joueur lui est
-- signalé hors du jeu ; aucune valeur venue du client n'entre dans un envoi. La clé d'API vit dans les secrets du
-- jeu (HttpService:GetSecret), jamais dans le code.
--
-- API (côté serveur) :
--   NotificationService.Send(userId, momentId, parameters) -> boolean   envoi immédiat (Studio : écrit si StudioDryRun)
--   NotificationService.Schedule(userId, momentId, at, parameters) -> boolean   planifié (Unix), remplace le précédent
--   NotificationService.Cancel(userId)                                  retire les moments planifiés du joueur

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Config.Features)
local Items = require(Shared.Config.Items)
local LiveEvents = require(Shared.Config.LiveEvents)
local Notifications = require(Shared.Config.Notifications)
local Offline = require(Shared.Config.Offline)
local Format = require(Shared.Format)
local Net = require(Shared.Net.Net)

local DataService = require(script.Parent.DataService)
local PvPService = require(script.Parent.PvPService)

local IS_STUDIO = RunService:IsStudio()
local STOLEN = "Stolen" -- PvPService.TheftResult : objet déposé chez le voleur
local SCHEDULED = { "OfflineFull", "SaturdayEvent" } -- moments planifiés au départ, retirés au retour
local MAX_EXPIRATION = 45 * 24 * 3600 -- MemoryStore : 45 jours au plus

type Parameters = { [string]: string }

local NotificationService = {}

local enabled = false
local map: any = nil -- MemoryStoreSortedMap
local secret: any = nil -- Secret, lu une fois
local unfocused: { [Player]: boolean } = {}
local lastStolen: { [number]: number } = {} -- [UserId] = os.clock() du dernier envoi ShopStolen
local warned: { [string]: boolean } = {}

local function log(message: string)
	if IS_STUDIO then
		print(`[NotificationService] {message}`)
	end
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[NotificationService] {message}`)
	end
end

-- Le moment, s'il est branché (MessageId posé) ; en Studio avec StudioDryRun, un moment sans MessageId est
-- quand même joué (écrit dans la sortie) pour pouvoir le tester.
local function momentOf(id: string): Notifications.Moment?
	local moment = Notifications.Moments[id]
	if moment == nil then
		return nil
	end
	if moment.MessageId == "" and not (IS_STUDIO and Notifications.StudioDryRun) then
		return nil
	end
	return moment
end

local function getSecret(): any
	if secret ~= nil then
		return secret
	end
	local ok, result = pcall(function(): any
		return HttpService:GetSecret(Notifications.SecretName)
	end)
	if not ok then
		warnOnce("secret", `secret « {Notifications.SecretName} » introuvable (Creator Hub > Secrets) : rien n'est envoyé ({result})`)
		return nil
	end
	secret = result
	return secret
end

local function send(userId: number, momentId: string, parameters: Parameters): boolean
	local moment = momentOf(momentId)
	if moment == nil or not enabled then
		return false
	end
	if IS_STUDIO and Notifications.StudioDryRun then
		local list: { string } = {}
		for key, value in parameters do
			table.insert(list, `{key}={value}`)
		end
		table.sort(list)
		print(`[NotificationService] (Studio, pas envoyé) {momentId} → {userId} : {table.concat(list, ", ")}`)
		return true
	end
	local key = getSecret()
	if key == nil then
		return false
	end
	local params: { [string]: any } = {}
	for name, value in parameters do
		params[name] = { stringValue = value }
	end
	local body = HttpService:JSONEncode({
		source = { universe = `universes/{game.GameId}` },
		payload = {
			type = "MOMENT",
			messageId = moment.MessageId,
			parameters = params,
			joinExperience = { launchData = `notification:{momentId}` },
			analyticsData = { category = momentId },
		},
	})
	local ok, response = pcall(function(): any
		return HttpService:RequestAsync({
			Url = string.format(Notifications.Url, userId),
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = key } :: any,
			Body = body,
		})
	end)
	if not ok then
		warnOnce(`http:{momentId}`, `{momentId} vers {userId} : {response}`)
		return false
	end
	if not response.Success then
		warnOnce(`status:{momentId}:{response.StatusCode}`, `{momentId} vers {userId} : HTTP {response.StatusCode} {string.sub(tostring(response.Body), 1, 200)}`)
		return false
	end
	log(`{momentId} envoyé à {userId}`)
	return true
end

local function keyOf(momentId: string, userId: number): string
	return `{momentId}:{userId}`
end

local function schedule(userId: number, momentId: string, at: number, parameters: Parameters): boolean
	if not enabled or map == nil or momentOf(momentId) == nil then
		return false
	end
	local now = os.time()
	local expiration = math.clamp(math.ceil(at - now) + Notifications.ClaimSeconds * 2, 60, MAX_EXPIRATION)
	local ok, err = pcall(function()
		map:SetAsync(keyOf(momentId, userId), { u = userId, m = momentId, p = parameters }, expiration, math.floor(at))
	end)
	if not ok then
		warnOnce(`set:{momentId}`, `planification de {momentId} : {err}`)
		return false
	end
	log(`{momentId} planifié pour {userId} dans {math.floor(at - now)} s`)
	return true
end

local function cancel(userId: number)
	if map == nil then
		return
	end
	for _, momentId in SCHEDULED do
		local ok, err = pcall(function()
			map:RemoveAsync(keyOf(momentId, userId))
		end)
		if not ok then
			warnOnce("remove", `retrait des notifications de {userId} : {err}`)
		end
	end
end

-- Prend la ligne `key` pour ce serveur ; renvoie sa valeur, ou nil si un autre serveur l'a déjà prise.
local function claim(key: string, now: number): any
	local taken: any = nil
	local ok, err = pcall(function()
		map:UpdateAsync(key, function(old: any, _sortKey: any): (any, any)
			if type(old) ~= "table" or old.c ~= nil then
				return nil, nil
			end
			local copy = table.clone(old)
			copy.c = game.JobId
			taken = copy
			return copy, now + MAX_EXPIRATION
		end, Notifications.ClaimSeconds)
	end)
	if not ok then
		warnOnce("claim", `prise d'une notification : {err}`)
		return nil
	end
	return taken
end

local function poll()
	local now = os.time()
	local ok, entries = pcall(function(): any
		return map:GetRangeAsync(Enum.SortDirection.Ascending, Notifications.PollBatch, nil, { sortKey = now + 1 })
	end)
	if not ok then
		warnOnce("range", `lecture de la file : {entries}`)
		return
	end
	for _, entry in entries :: { any } do
		local value = claim(entry.key, now)
		if value == nil then
			continue
		end
		local userId = tonumber(value.u)
		local parameters = if type(value.p) == "table" then value.p else {}
		if userId ~= nil and type(value.m) == "string" and Players:GetPlayerByUserId(userId) == nil then
			send(userId, value.m, parameters)
		end
	end
end

-- Départ du joueur : moments planifiés d'après son profil (encore lisible pendant la libération).
local function onProfileReleasing(player: Player)
	if not enabled then
		return
	end
	local data = DataService.Get(player)
	local userId = player.UserId
	local now = os.time()
	local income = 0
	local offline: any = if data then (data :: any).Offline else nil
	if type(offline) == "table" and type(offline.Income) == "number" and offline.Income == offline.Income then
		income = math.max(0, offline.Income)
	end
	-- a481 : plafond du joueur (nœuds OfflineTime de son arbre, Config/Offline.CapHours), 4 h sans eux.
	local seconds = Offline.CapHours(if data then (data :: any).SkillTree else nil) * 3600
	local amount = income * seconds * Offline.Rate
	local nextEvent = LiveEvents.NextWeeklyStart(now)
	local eventName: string? = nil
	local rule = LiveEvents.Weekly[1]
	local format = if rule then LiveEvents.ById[rule.Event] else nil
	if format then
		eventName = format.DisplayName
	end
	task.spawn(function()
		if amount >= 1 then
			schedule(userId, "OfflineFull", now + seconds, { amount = Format.money(amount) })
		end
		if nextEvent ~= nil and eventName ~= nil and nextEvent - Notifications.LeadSeconds > now then
			schedule(userId, "SaturdayEvent", nextEvent - Notifications.LeadSeconds, { event = eventName })
		end
	end)
end

local function onTheftEnded(_thief: Player, victim: Player, itemId: string, result: string, _reason: string)
	if not enabled or result ~= STOLEN or not unfocused[victim] then
		return
	end
	local userId = victim.UserId
	local last = lastStolen[userId]
	if last ~= nil and os.clock() - last < Notifications.StolenCooldown then
		return
	end
	local item = Items.ById[itemId]
	if item == nil or momentOf("ShopStolen") == nil then
		return
	end
	lastStolen[userId] = os.clock()
	task.spawn(send, userId, "ShopStolen", { item = item.DisplayName })
end

local function onReportFocus(player: Player, focused: boolean)
	if type(focused) ~= "boolean" then
		return
	end
	if focused then
		unfocused[player] = nil
	else
		unfocused[player] = true
	end
end

-- Studio : workspace:SetAttribute(TestAttribute, "<moment> <joueur>") envoie le moment tout de suite.
local function onTestAttribute()
	local text = Workspace:GetAttribute(Notifications.TestAttribute)
	if type(text) ~= "string" or text == "" then
		return
	end
	local momentId, who = string.match(text, "^(%S+)%s+(%S+)$")
	local target: Player? = nil
	for _, player in Players:GetPlayers() do
		if player.Name == who or tostring(player.UserId) == who then
			target = player
		end
	end
	if momentId == nil or target == nil then
		warn(`[NotificationService] {Notifications.TestAttribute} = « {text} » : « <moment> <joueur> » attendu`)
		return
	end
	local parameters: Parameters = { amount = "$1.2M", event = "ADMIN ABUSE", item = "Soda Can" }
	send((target :: Player).UserId, momentId, parameters)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function NotificationService.Send(userId: number, momentId: string, parameters: Parameters): boolean
	return send(userId, momentId, parameters)
end

function NotificationService.Schedule(userId: number, momentId: string, at: number, parameters: Parameters): boolean
	return schedule(userId, momentId, at, parameters)
end

function NotificationService.Cancel(userId: number)
	cancel(userId)
end

function NotificationService.Init()
	enabled = Features.ExperienceNotifications == true
	Net.Server.ReportFocus:Connect(onReportFocus)
	if not enabled then
		print("[NotificationService] Features.ExperienceNotifications = false : aucune notification")
		return
	end
	local ok, result = pcall(function(): any
		return MemoryStoreService:GetSortedMap(Notifications.MapName)
	end)
	if ok then
		map = result
	else
		warn(`[NotificationService] MemoryStore indisponible ({result}) : seuls les envois immédiats partent`)
	end
	DataService.OnProfileReleasing(onProfileReleasing)
	PvPService.OnTheftEnded(onTheftEnded)
	Players.PlayerAdded:Connect(function(player: Player)
		local userId = player.UserId
		task.spawn(cancel, userId)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		unfocused[player] = nil
	end)
	if IS_STUDIO then
		Workspace:GetAttributeChangedSignal(Notifications.TestAttribute):Connect(onTestAttribute)
	end
end

function NotificationService.Start()
	if not enabled or map == nil then
		return
	end
	for _, player in Players:GetPlayers() do
		task.spawn(cancel, player.UserId)
	end
	task.spawn(function()
		while true do
			task.wait(Notifications.PollInterval)
			local ok, err = pcall(poll :: any) -- :: any : sans lui, l'ancien solveur croit que pcall ne renvoie qu'une valeur
			if not ok then
				warnOnce("poll", `relecture de la file : {err}`)
			end
		end
	end)
end

return NotificationService
