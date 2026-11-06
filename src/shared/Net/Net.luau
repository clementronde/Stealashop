--!strict
-- Module Net : tous les remotes du jeu (DEV-002, sections 9.1 et 9.4 du doc).
-- ReplicatedStorage/Shared/Net/Net, commun au serveur et au client.
--
-- La liste des remotes (nom, sens, fiable ou non, types des arguments, débit)
-- est dans Definitions.luau, à côté. Ce module crée les instances et transporte
-- les appels.
--
-- Serveur
--   local Net = require(ReplicatedStorage.Shared.Net.Net)
--   -- Client → serveur : les arguments arrivent déjà contrôlés (nombre, types,
--   -- bornes, débit). Les règles de jeu restent au service.
--   local connection = Net.Server.HitWindow:Connect(function(player: Player, windowId: string) end)
--   connection:Disconnect()
--   -- Serveur → client :
--   Net.Server.Notify:Fire(player, "Rattrapé !", "Warning")
--   Net.Server.WindowHP:FireAll(windowId, hp, maxHp)
--   -- Rappel des appels refusés, à remplacer par AntiCheatService (un seul rappel) :
--   Net.OnViolation = function(player, remoteName, reason, detail) end
--
-- Client
--   local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Net"))
--   Net.Client.HitWindow:Fire(windowId)
--   Net.Client.WindowHP:Connect(function(windowId: string, hp: number, maxHp: number) end)
--
-- Fonctionnement
--   - Serveur : au premier require, crée ReplicatedStorage/Remotes avec un
--     RemoteEvent (ou UnreliableRemoteEvent) par remote. Jamais dans
--     ReplicatedStorage/Shared, qui est relié au disque par Script Sync. Un
--     dossier Remotes déjà présent est remplacé (il ne se crée pas à la main).
--     En mode édition de Studio (pas de partie lancée), rien n'est créé ni
--     attendu : les remotes sont inactifs.
--   - Client : le premier require attend ce dossier (CLIENT_WAIT_SECONDS au
--     plus), puis est prêt. Si le serveur n'a pas chargé Net, avertit et les
--     remotes du client ne font rien.
--   - Chaque appel reçu par le serveur passe dans l'ordre : débit par joueur
--     (Definitions.RatePerSecond), puis forme des arguments (Validate). Un appel
--     refusé est ignoré sans erreur, signalé à Net.OnViolation et, en Studio,
--     écrit dans la sortie. Les refus de débit sont signalés au plus une fois
--     par seconde par joueur et par remote, avec le nombre d'appels ignorés.
--   - Un client qui appelle un remote serveur → client est signalé en
--     « WrongDirection », avec la même limite de signalement.
--   - En Studio, un envoi dont les arguments ne respectent pas Definitions
--     déclenche un avertissement (l'envoi part quand même).
--   - Mauvais usage dans le code (remote inconnu, :Fire sur un remote client →
--     serveur côté serveur, Net.Server côté client…) : erreur immédiate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Definitions = require(script.Parent.Definitions)
local RateLimiter = require(script.Parent.RateLimiter)
local Validate = require(script.Parent.Validate)

type RemoteDef = Definitions.RemoteDef
type Window = RateLimiter.Window

export type ViolationReason = "RateLimit" | "ArgCount" | "ArgType" | "ArgValue" | "WrongDirection"

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type ServerRemote = {
	Name: string,
	Connect: (self: ServerRemote, handler: (player: Player, ...any) -> ()) -> Connection,
	Fire: (self: ServerRemote, player: Player, ...any) -> (),
	FireAll: (self: ServerRemote, ...any) -> (),
}

export type ClientRemote = {
	Name: string,
	Fire: (self: ClientRemote, ...any) -> (),
	Connect: (self: ClientRemote, handler: (...any) -> ()) -> Connection,
}

type Handler = (player: Player, ...any) -> ()

local FOLDER_NAME = "Remotes"
local CLIENT_WAIT_SECONDS = 15 -- V0 proposé, absent du doc : attente max des remotes par le client
local REPORT_INTERVAL = 1 -- V0 proposé, absent du doc : au plus 1 signalement de débit par seconde, joueur et remote

local IS_STUDIO = RunService:IsStudio()

local Net = {}

-- Appelé pour chaque appel refusé. AntiCheatService remplace cette fonction.
function Net.OnViolation(_player: Player, _remoteName: string, _reason: ViolationReason, _detail: string) end

-- Contrôle de la liste au chargement : une erreur ici est une faute dans Definitions.
local function checkDefinitions()
	local seen: { [string]: boolean } = {}
	for _, def in Definitions.List do
		assert(not seen[def.Name], `Net : remote {def.Name} déclaré deux fois`)
		seen[def.Name] = true
		if def.Direction == "ClientToServer" then
			local rate = def.RatePerSecond
			assert(
				rate ~= nil and rate >= 1 and math.floor(rate) == rate,
				`Net : {def.Name} doit avoir un RatePerSecond entier ≥ 1`
			)
		end
		for _, spec in def.Args do
			assert(spec.Kind ~= "string" or spec.Max ~= nil, `Net : {def.Name}.{spec.Name} : chaîne sans Max`)
		end
	end
end

local function report(player: Player, remoteName: string, reason: ViolationReason, detail: string)
	if IS_STUDIO then
		warn(`[Net] {player.Name} → {remoteName} refusé : {reason} ({detail})`)
	end
	local ok, err = pcall(Net.OnViolation, player, remoteName, reason, detail)
	if not ok then
		warn(`[Net] erreur dans Net.OnViolation : {err}`)
	end
end

-- Pour les refus qu'un client peut répéter sans limite : signalement espacé.
local function reportFlood(player: Player, remoteName: string, window: Window, now: number, reason: ViolationReason)
	window.dropped += 1
	if now - window.lastReport < REPORT_INTERVAL then
		return
	end
	local dropped = window.dropped
	window.dropped = 0
	window.lastReport = now
	report(player, remoteName, reason, `{dropped} appel(s) ignoré(s) depuis le dernier signalement`)
end

-- Avertissement Studio quand le code envoie des arguments hors Definitions.
local function checkOutgoing(def: RemoteDef, ...: any)
	local reason, detail = Validate.check(def.Args, ...)
	if reason then
		warn(debug.traceback(`[Net] envoi de {def.Name} mal formé : {detail}`, 3))
	end
end

-- Table nom → remote qui lève une erreur claire sur un nom inconnu.
local function strictMap<T>(map: { [string]: T }, label: string): { [string]: T }
	return setmetatable(map, {
		__index = function(_, key)
			error(`Net : remote inconnu « {tostring(key)} » dans {label}`, 2)
		end,
	}) :: any
end

-- Remplace Net.Server côté client et Net.Client côté serveur.
local function wrongSide(message: string): any
	return setmetatable({}, {
		__index = function()
			error(message, 2)
		end,
	})
end

-- Serveur ---------------------------------------------------------------------

local windows: { [Player]: { [string]: Window } } = {}

local function getWindow(player: Player, def: RemoteDef): Window
	local perPlayer = windows[player]
	if perPlayer == nil then
		perPlayer = {}
		windows[player] = perPlayer
	end
	local window = perPlayer[def.Name]
	if window == nil then
		-- Remote serveur → client : limite 0, tout appel du client est refusé.
		window = RateLimiter.new(def.RatePerSecond or 0)
		perPlayer[def.Name] = window
	end
	return window
end

local function makeServerRemote(def: RemoteDef, instance: any): ServerRemote
	local name = def.Name
	local fromClient = def.Direction == "ClientToServer"
	-- Copie à l'écriture : une connexion ou déconnexion pendant un envoi ne
	-- modifie pas la liste en cours de parcours.
	local handlers: { Handler } = {}

	instance.OnServerEvent:Connect(function(player: Player, ...: any)
		if player.Parent ~= Players then
			return -- joueur déjà parti
		end
		local now = os.clock()
		local window = getWindow(player, def)
		if not fromClient then
			reportFlood(player, name, window, now, "WrongDirection")
			return
		end
		if not RateLimiter.allow(window, now) then
			reportFlood(player, name, window, now, "RateLimit")
			return
		end
		local reason, detail = Validate.check(def.Args, ...)
		if reason then
			report(player, name, reason, detail or "")
			return
		end
		for _, handler in handlers do
			task.spawn(handler, player, ...)
		end
	end)

	local remote: ServerRemote = {
		Name = name,
		Connect = function(_self: ServerRemote, handler: Handler): Connection
			if not fromClient then
				error(`Net : {name} va du serveur au client, le serveur l'envoie avec :Fire ou :FireAll`, 2)
			end
			local list = table.clone(handlers)
			table.insert(list, handler)
			handlers = list
			local connected = true
			return {
				Disconnect = function(_conn: Connection)
					if not connected then
						return
					end
					connected = false
					local copy = table.clone(handlers)
					local position = table.find(copy, handler)
					if position then
						table.remove(copy, position)
					end
					handlers = copy
				end,
			}
		end,
		Fire = function(_self: ServerRemote, player: Player, ...: any)
			if fromClient then
				error(`Net : {name} va du client au serveur, le serveur s'y abonne avec :Connect`, 2)
			end
			if IS_STUDIO then
				checkOutgoing(def, ...)
			end
			instance:FireClient(player, ...)
		end,
		FireAll = function(_self: ServerRemote, ...: any)
			if fromClient then
				error(`Net : {name} va du client au serveur, le serveur s'y abonne avec :Connect`, 2)
			end
			if IS_STUDIO then
				checkOutgoing(def, ...)
			end
			instance:FireAllClients(...)
		end,
	}
	return remote
end

local function buildServer(): { [string]: ServerRemote }
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local map: { [string]: ServerRemote } = {}
	for _, def in Definitions.List do
		local instance: any = Instance.new(if def.Reliable then "RemoteEvent" else "UnreliableRemoteEvent")
		instance.Name = def.Name
		instance.Parent = folder
		map[def.Name] = makeServerRemote(def, instance)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		windows[player] = nil
	end)

	-- Hors partie lancée (mode édition de Studio), on ne touche pas à la place.
	if RunService:IsRunning() then
		local old = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if old then
			warn(`[Net] ReplicatedStorage/{FOLDER_NAME} existait déjà, remplacé : ce dossier est créé par le code`)
			old:Destroy()
		end
		-- Parenté en dernier : le client reçoit le dossier complet d'un coup.
		folder.Parent = ReplicatedStorage
	end
	return strictMap(map, "Net.Server")
end

-- Client ----------------------------------------------------------------------

local function makeClientRemote(def: RemoteDef, instance: any?): ClientRemote
	local name = def.Name
	local toServer = def.Direction == "ClientToServer"
	local remote: ClientRemote = {
		Name = name,
		Fire = function(_self: ClientRemote, ...: any)
			if not toServer then
				error(`Net : {name} va du serveur au client, le client s'y abonne avec :Connect`, 2)
			end
			if instance == nil then
				return
			end
			if IS_STUDIO then
				checkOutgoing(def, ...)
			end
			instance:FireServer(...)
		end,
		Connect = function(_self: ClientRemote, handler: (...any) -> ()): Connection
			if toServer then
				error(`Net : {name} va du client au serveur, le client l'envoie avec :Fire`, 2)
			end
			if instance == nil then
				return { Disconnect = function(_conn: Connection) end }
			end
			local connection = instance.OnClientEvent:Connect(handler)
			return {
				Disconnect = function(_conn: Connection)
					connection:Disconnect()
				end,
			}
		end,
	}
	return remote
end

local function buildClient(): { [string]: ClientRemote }
	local deadline = os.clock() + CLIENT_WAIT_SECONDS
	local folder: Instance? = nil
	-- Hors partie lancée (édition en Team Create), pas d'attente : remotes inactifs.
	if RunService:IsRunning() then
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT_SECONDS)
		if folder == nil then
			warn(
				`[Net] ReplicatedStorage/{FOLDER_NAME} introuvable après {CLIENT_WAIT_SECONDS} s : le serveur n'a pas chargé Net, les remotes du client sont inactifs`
			)
		end
	end
	local map: { [string]: ClientRemote } = {}
	for _, def in Definitions.List do
		local instance: Instance? = nil
		if folder then
			instance = folder:FindFirstChild(def.Name)
				or folder:WaitForChild(def.Name, math.max(deadline - os.clock(), 0.1))
			if instance == nil then
				warn(`[Net] remote {def.Name} introuvable dans ReplicatedStorage/{FOLDER_NAME}, inactif`)
			end
		end
		map[def.Name] = makeClientRemote(def, instance)
	end
	return strictMap(map, "Net.Client")
end

-- Démarrage -------------------------------------------------------------------

checkDefinitions()

if RunService:IsServer() then
	Net.Server = buildServer()
	Net.Client = wrongSide("Net.Client n'existe que sur le client") :: { [string]: ClientRemote }
else
	Net.Server = wrongSide("Net.Server n'existe que sur le serveur") :: { [string]: ServerRemote }
	Net.Client = buildClient()
end

return Net
